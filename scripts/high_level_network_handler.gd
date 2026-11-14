extends Node

const IP_ADDRESS: String = "192.168.0.10"
const PORT: int = 42069

const base_level_scene = "res://scenes/levels/base_level.tscn"
const lobby_scene = "res://scenes/ui/menus/lobby.tscn"

enum NetworkTransport {
	ENET,
	STEAM
}

var network_transport: NetworkTransport = NetworkTransport.ENET

var peer: MultiplayerPeer

var steam_lobby_id: int = 0

enum NetworkScene{
	LOBBY, 
	GAME
}

var ready_peers: Dictionary = {}
var expected_peers: Array[int] = []
var scene_spawner: MultiplayerSpawner
var current_scene: NetworkScene = NetworkScene.LOBBY
var spawned_peers: Dictionary = {}

var is_solo: bool = false

var transitioning: bool = false
var cleanup_ready_peers: Dictionary = {}
var cleanup_prepared_peers: Dictionary = {}

var removal_started: bool = false
var target_scene: NetworkScene = NetworkScene.LOBBY

var transition_id: int = 0
var steam_available: bool = false
var session_player_count: int = 1

var player_names: Dictionary = {}
var local_player_name: String = ""

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	steam_available = Steam.steamInit(480, true)
	print("Steam initialization: ", steam_available)
	
	Steam.initRelayNetworkAccess()
	
	print("SteamMultiplayerPeer available: ", ClassDB.class_exists("SteamMultiplayerPeer"))
	
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	Steam.join_requested.connect(_on_steam_join_requested)
	

@rpc("any_peer", "call_remote", "reliable")
func submit_player_name(display_name: String) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	
	var clean_name := display_name.strip_edges().substr(0, 24)
	
	if clean_name.is_empty():
		clean_name = "Gnome"
	
	player_names[sender] = clean_name

	sync_player_names.rpc(player_names)

@rpc("authority", "call_local", "reliable")
func sync_player_names(names: Dictionary) -> void:
	player_names = names.duplicate()
	update_player_name_labels()

func update_player_name_labels() -> void:
	var scene_root := get_tree().current_scene

	if scene_root == null:
		return

	for peer_id in player_names:
		var player := scene_root.get_node_or_null(str(peer_id))

		if player != null:
			player.set_player_name(player_names[peer_id])

func get_session_player_name() -> String:
	if network_transport == NetworkTransport.STEAM and steam_available:
		var steam_name := Steam.getPersonaName().strip_edges()
		if not steam_name.is_empty():
			return steam_name.substr(0, 24)

	var custom_name := local_player_name.strip_edges()
	if custom_name.is_empty():
		return "Gnome"

	return custom_name.substr(0, 24)

func start_steam_server() -> void:
	network_transport = NetworkTransport.STEAM
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 4)


func _on_steam_lobby_created(result: int, lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		push_error("Failed to create Steam lobby!")
		return

	if network_transport != NetworkTransport.STEAM:
		Steam.leaveLobby(lobby_id)
		return

	steam_lobby_id = lobby_id

	var steam_peer := SteamMultiplayerPeer.new()
	steam_peer.server_relay = true

	var error := steam_peer.create_host(0)

	if error != OK:
		push_error("Failed to create Steam multiplayer host!")
		Steam.leaveLobby(steam_lobby_id)
		steam_lobby_id = 0
		return

	print("Steam lobby created: ", steam_lobby_id)

	finish_host_connection(steam_peer)

func join_steam_lobby(lobby_id: int) -> void:
	network_transport = NetworkTransport.STEAM
	Steam.joinLobby(lobby_id)


func _on_steam_join_requested(lobby_id: int, _friend_id: int) -> void:
	if not steam_available:
		return
		
	if multiplayer.has_multiplayer_peer():
		push_warning("Already in a multiplayer session")
		return
		
	join_steam_lobby(lobby_id)


### Steam friend invite won't work until I register game with Steam
### and get own App ID
func invite_steam_friends() -> void:
	if network_transport != NetworkTransport.STEAM:
		return
		
	if steam_lobby_id == 0:
		return
	
	Steam.activateGameOverlayInviteDialog(steam_lobby_id)

func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Failed to join Steam lobby!")
		return

	# The host may receive this callback too.
	if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
		return

	network_transport = NetworkTransport.STEAM
	steam_lobby_id = lobby_id

	var host_id: int = Steam.getLobbyOwner(lobby_id)

	var steam_peer := SteamMultiplayerPeer.new()
	steam_peer.server_relay = true

	var error := steam_peer.create_client(host_id, 0)

	if error != OK:
		push_error("Failed to create Steam client!")
		Steam.leaveLobby(steam_lobby_id)
		steam_lobby_id = 0
		return

	finish_client_connection(steam_peer)

func _on_server_disconnected() -> void:
	GameManager.disconnect_reason = "Connection to host lost"
	leave_session()
	
func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	
	if not multiplayer.is_server():
		return
			
	expected_peers.erase(id)
	ready_peers.erase(id)
	cleanup_prepared_peers.erase(id)
	cleanup_ready_peers.erase(id)
	player_names.erase(id)
	sync_player_names.rpc(player_names)
	
	if scene_spawner != null and spawned_peers.has(id):
		scene_spawner.despawn_player(id)
		
	spawned_peers.erase(id)

	if transitioning:
		if not removal_started:
			if target_scene == NetworkScene.GAME:
				transition_id += 1
				cancel_scene_transition.rpc(transition_id)
			else:
				check_cleanup_prepared()
		else:
			check_cleanup_complete()

		return
		
	if current_scene == NetworkScene.GAME:
		check_all_ready()

func _on_connection_failed() -> void:
	push_error("Multiplayer connection failed!")
	GameManager.disconnect_reason = "Failed to connect to host"
	leave_session()

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)

func leave_session() -> void:
	if steam_lobby_id != 0:
		Steam.leaveLobby(steam_lobby_id)
		steam_lobby_id = 0
	
	var multiplayer_peer := multiplayer.multiplayer_peer
	
	if multiplayer_peer != null:
		multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	expected_peers.clear()
	ready_peers.clear()
	spawned_peers.clear()
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()
	player_names.clear()
	
	peer = null
	network_transport = NetworkTransport.ENET
	
	session_player_count = 1
	transition_id = 0
	removal_started = false
	transitioning = false
	is_solo = false
	scene_spawner = null
	current_scene = NetworkScene.LOBBY
	target_scene = NetworkScene.LOBBY
	GameManager.local_pause_menu_open = false
	GameManager.game_active = false
	GameManager.reset_clock()
	GameManager.reset_level()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu_world.tscn")

func start_game() -> void :
	begin_scene_transition(NetworkScene.GAME)

func begin_scene_transition(destination: NetworkScene) -> void:
	if not multiplayer.is_server():
		return

	if transitioning:
		return

	if current_scene == destination:
		return

	if scene_spawner == null:
		return

	transition_id += 1
	transitioning = true
	removal_started = false
	target_scene = destination

	expected_peers.clear()
	expected_peers.append(1)

	for id in multiplayer.get_peers():
		expected_peers.append(id)

	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()

	prepare_scene_cleanup.rpc(transition_id, current_scene, expected_peers.duplicate())

	monitor_scene_transition(transition_id)

func monitor_scene_transition(request_id: int) -> void:
	await get_tree().create_timer(12.0).timeout

	if not multiplayer.has_multiplayer_peer():
		return

	if not multiplayer.is_server():
		return

	if transition_id != request_id:
		return

	if not transitioning:
		return

	if removal_started:
		push_warning("Scene removal timed out. Ending session.")
		GameManager.disconnect_reason = "Scene transition failed"
		leave_session()
		return

	push_warning("Scene preparation timed out. Cancelling transition.")

	transition_id += 1
	cancel_scene_transition.rpc(transition_id)

@rpc("authority", "call_local", "reliable")
func prepare_scene_cleanup(request_id: int, source_scene: NetworkScene, player_ids:Array[int]) -> void:
	if not multiplayer.is_server():
		if request_id <= transition_id:
			return

		transition_id = request_id
		transitioning = true
		removal_started = false
	
	var prepared := await wait_for_players(player_ids, request_id, source_scene, true)
	
	if not prepared:
		return
	
	if not multiplayer.has_multiplayer_peer():
		return
	
	if transition_id != request_id:
		return
	
	if current_scene != source_scene:
		return
	
	if multiplayer.is_server():
		cleanup_prepared_peers[1] = true
		check_cleanup_prepared()
	else:
		notify_cleanup_prepared.rpc_id(1, request_id)

func wait_for_players(player_ids: Array[int], request_id: int, source_scene: NetworkScene, should_exist: bool) -> bool:
	var start_time := Time.get_ticks_msec()

	while true:
		if not multiplayer.has_multiplayer_peer():
			return false
		
		if transition_id != request_id:
			return false
		
		if current_scene != source_scene:
			return false

		if Time.get_ticks_msec() - start_time > 5000:
			push_warning("Scene preparation timed out")
			return false

		var scene_root := get_tree().current_scene

		if scene_root == null:
			return false

		var all_present := true

		for id in player_ids:
			var exists := scene_root.has_node(str(id))
			
			if exists != should_exist:
				all_present = false
				break

		if all_present:
			return true

		await get_tree().process_frame

	return false

@rpc("any_peer", "call_remote", "reliable")
func notify_cleanup_prepared(request_id: int) -> void:
	if not multiplayer.is_server():
		return

	if not transitioning:
		return
	
	if removal_started:
		return
	
	if transition_id != request_id:
		return

	var sender := multiplayer.get_remote_sender_id()

	if sender not in expected_peers:
		return

	cleanup_prepared_peers[sender] = true

	check_cleanup_prepared()
	
func check_cleanup_prepared() -> void:
	if not multiplayer.is_server():
		return

	if not transitioning:
		return

	if removal_started:
		return

	for id in expected_peers:
		if not cleanup_prepared_peers.has(id):
			return

	cleanup_prepared_peers.clear()
	
	removal_started = true
	
	# Begin removal monitoring on all peers.
	begin_scene_removal.rpc(transition_id, current_scene, expected_peers.duplicate())

	# Server-authoritative despawning.
	for id in spawned_peers.keys():
		scene_spawner.despawn_player(id)

@rpc("authority", "call_local", "reliable")
func begin_scene_removal(request_id: int, source_scene: NetworkScene, player_ids: Array[int]) -> void:
	if transition_id != request_id:
		return
		
	removal_started = true
	
	var cleanup_successful := await wait_for_players(player_ids, request_id, source_scene, false)

	if not cleanup_successful:
		return

	if not multiplayer.has_multiplayer_peer():
		return

	if transition_id != request_id:
		return

	if current_scene != source_scene:
		return

	if multiplayer.is_server():
		cleanup_ready_peers[1] = true
		check_cleanup_complete()
	else:
		notify_cleanup_complete.rpc_id(1, request_id)


@rpc("any_peer", "call_remote", "reliable")
func notify_cleanup_complete(request_id: int) -> void:
	if not multiplayer.is_server():
		return

	if not transitioning:
		return
	
	if not removal_started:
		return
	
	if transition_id != request_id:
		return
	
	var sender := multiplayer.get_remote_sender_id()

	if sender not in expected_peers:
		return

	cleanup_ready_peers[sender] = true
	check_cleanup_complete()
	
func check_cleanup_complete() -> void:
	if not multiplayer.is_server():
		return

	if not transitioning:
		return
	
	if not removal_started:
		return
	
	for id in expected_peers:
		if not cleanup_ready_peers.has(id):
			return

	transitioning= false
	removal_started = false
	
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()

	change_network_scene.rpc(target_scene, expected_peers.size())

@rpc("authority", "call_local", "reliable")
func cancel_scene_transition(request_id: int) -> void:
	if request_id < transition_id:
		return

	transition_id = request_id

	transitioning = false
	removal_started = false

	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()

	print("Scene transition cancelled")

func return_to_lobby() -> void:
	begin_scene_transition(NetworkScene.LOBBY)

@rpc("authority", "call_local", "reliable")
func change_network_scene(scene_type: NetworkScene, player_count: int) -> void :
	transitioning = false
	removal_started = false
	
	session_player_count = player_count
	
	current_scene = scene_type
	scene_spawner = null
	ready_peers.clear()
	spawned_peers.clear()
	
	GameManager.reset_level()
	GameManager.local_pause_menu_open = false
	
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	match scene_type:
		NetworkScene.LOBBY:
			#GameManager.game_active = false
			GameManager.game_state = GameManager.GameState.LOBBY
			get_tree().change_scene_to_file(lobby_scene)
		NetworkScene.GAME:
			#GameManager.game_active = false
			#GameManager.game_state = GameManager.GameState.STARTING
			#GameManager.game_state = GameManager.GameState.PLAYING
			get_tree().change_scene_to_file(base_level_scene)

func register_scene_spawner(
	spawner: MultiplayerSpawner,
	scene_type: NetworkScene
) -> void:
	scene_spawner = spawner

	if multiplayer.is_server():
		ready_peers[1] = true

		if scene_type == NetworkScene.LOBBY:
			spawn_peer(1)
		else:
			check_all_ready()
	else:
		if scene_type == NetworkScene.GAME:
			while not GameManager.clock_synchronized:
				await GameManager.clock_sync_completed

				if not multiplayer.has_multiplayer_peer():
					return

			# Scene may have changed while awaiting sync.
			if current_scene != scene_type:
				return

			if scene_spawner != spawner:
				return

		notify_scene_ready.rpc_id(1, scene_type)

@rpc("any_peer", "reliable")
func notify_scene_ready(scene_type: NetworkScene) -> void :
	if not multiplayer.is_server():
		return

	if scene_type != current_scene:
		return

	var id: = multiplayer.get_remote_sender_id()

	if current_scene == NetworkScene.GAME:
		if id not in expected_peers:
			return

	ready_peers[id] = true
	print("Player ", id, " finished loading!")

	if current_scene == NetworkScene.LOBBY:
		spawn_peer(id)
	else:
		check_all_ready()

func spawn_peer(id: int) -> void :
	if not multiplayer.is_server():
		return

	if transitioning:
		return

	if scene_spawner == null:
		return

	if spawned_peers.has(id):
		return

	spawned_peers[id] = true
	scene_spawner.spawn_player(id)


func check_all_ready() -> void :
	if not multiplayer.is_server():
		return

	if scene_spawner == null:
		return

	if transitioning:
		return 
	
	if GameManager.start_scheduled or GameManager.game_active:
		return
	
	if GameManager.game_state == GameManager.GameState.FINISHED:
		return

	for id in expected_peers:
		if not ready_peers.has(id):
			return

	print("All Players loaded. Spawning gnomes!")

	for id in expected_peers:
		spawn_peer(id)

	#GameManager.start_game.rpc()
	GameManager.begin_game()

func start_solo() -> void :
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	current_scene = NetworkScene.GAME

	ready_peers.clear()
	expected_peers.clear()
	spawned_peers.clear()
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()
	player_names.clear()
	
	player_names[1] = local_player_name
	session_player_count = 1
	transition_id = 0
	removal_started = false
	transitioning = false
	scene_spawner = null
	is_solo = true
	target_scene = NetworkScene.LOBBY

	expected_peers.append(1)

	#GameManager.game_state = GameManager.GameState.STARTING
	#GameManager.game_state = GameManager.GameState.PLAYING
	#GameManager.game_active = false
	
	GameManager.reset_clock()
	GameManager.reset_level()
	
	get_tree().change_scene_to_file(base_level_scene)


func initialize_lobby_session() -> void:
	GameManager.reset_clock()
	GameManager.reset_level()
	
	current_scene = NetworkScene.LOBBY
	
	ready_peers.clear()
	expected_peers.clear()
	spawned_peers.clear()
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()
	player_names.clear()
	
	session_player_count = 1
	transition_id = 0
	removal_started = false
	transitioning = false
	target_scene = NetworkScene.LOBBY
	
	scene_spawner = null
	is_solo = false

func start_server() -> void :
	network_transport = NetworkTransport.ENET
	
	var enet_peer = ENetMultiplayerPeer.new()
	var error := enet_peer.create_server(PORT, 4)
	
	if error != OK:
		push_error("Failed to start ENet server!")
		return
	
	finish_host_connection(enet_peer)

func start_client() -> void :
	network_transport = NetworkTransport.ENET
	
	var enet_peer = ENetMultiplayerPeer.new()
	var error := enet_peer.create_client(IP_ADDRESS, PORT)

	if error != OK:
		push_error("Failed to create client!")
		return

	finish_client_connection(enet_peer)
	
func finish_host_connection(new_peer: MultiplayerPeer) -> void:
	peer = new_peer
	multiplayer.multiplayer_peer = peer

	initialize_lobby_session()
	
	player_names[1] = get_session_player_name()

	get_tree().change_scene_to_file(lobby_scene)


func finish_client_connection(new_peer: MultiplayerPeer) -> void:
	peer = new_peer
	multiplayer.multiplayer_peer = peer

	initialize_lobby_session()

	await multiplayer.connected_to_server

	if multiplayer.multiplayer_peer != new_peer:
		return
	
	submit_player_name.rpc_id(1, get_session_player_name())
	
	GameManager.request_server_time()
	get_tree().change_scene_to_file(lobby_scene)
