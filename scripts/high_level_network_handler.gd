extends Node

const IP_ADDRESS: String = "192.168.0.10"
const PORT: int = 42069

const base_level_scene = "res://scenes/levels/base_level.tscn"
const lobby_scene = "res://scenes/ui/menus/lobby.tscn"

var peer: ENetMultiplayerPeer

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

var transitioning_to_game: bool = false
var cleanup_ready_peers: Dictionary = {}
var cleanup_prepared_peers: Dictionary = {}

var lobby_removal_started: bool = false

var transition_id: int = 0

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

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
	
	if scene_spawner != null and spawned_peers.has(id):
		scene_spawner.despawn_player(id)
		
	spawned_peers.erase(id)

	if transitioning_to_game:
		if not lobby_removal_started:
			transition_id += 1
			cancel_lobby_transition.rpc(transition_id)
		else:
			check_cleanup_complete()
		return
		
	if current_scene == NetworkScene.GAME:
		check_all_ready()

func leave_session() -> void:
	var multiplayer_peer := multiplayer.multiplayer_peer
	
	if multiplayer_peer != null:
		multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	expected_peers.clear()
	ready_peers.clear()
	spawned_peers.clear()
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()
	
	transition_id = 0
	lobby_removal_started = false
	transitioning_to_game = false
	is_solo = false
	scene_spawner = null
	current_scene = NetworkScene.LOBBY
	GameManager.local_pause_menu_open = false
	GameManager.game_active = false
	GameManager.reset_clock()
	GameManager.reset_level()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu_world.tscn")

func start_game() -> void :
	if not multiplayer.is_server():
		return

	if transitioning_to_game:
		return
	
	if current_scene != NetworkScene.LOBBY:
		return
	
	if scene_spawner == null:
		return
	
	transition_id += 1
	lobby_removal_started = false
	transitioning_to_game = true

	expected_peers.clear()
	expected_peers.append(1)

	for id in multiplayer.get_peers():
		expected_peers.append(id)

	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()
	
	prepare_lobby_cleanup.rpc(transition_id, expected_peers.duplicate())
	
	monitor_lobby_transition(transition_id)
	

func monitor_lobby_transition(request_id: int) -> void:
	await get_tree().create_timer(12.0).timeout

	if not multiplayer.has_multiplayer_peer():
		return

	if not multiplayer.is_server():
		return

	if transition_id != request_id:
		return

	if not transitioning_to_game:
		return

	if lobby_removal_started:
		push_warning("Lobby removal timed out. Ending session.")
		GameManager.disconnect_reason = "Lobby transition failed"
		leave_session()
		return

	push_warning("Lobby preparation timed out. Cancelling transition.")

	transition_id += 1
	cancel_lobby_transition.rpc(transition_id)

@rpc("authority", "call_local", "reliable")
func prepare_lobby_cleanup(request_id: int, player_ids:Array[int]) -> void:
	if request_id <= transition_id and not multiplayer.is_server():
		return
	
	if not multiplayer.is_server():
		transition_id = request_id
	
	var prepared := await wait_for_lobby_players_present(player_ids, request_id)
	
	if not prepared:
		return
	
	if not multiplayer.has_multiplayer_peer():
		return
	
	if transition_id != request_id:
		return
	
	if current_scene != NetworkScene.LOBBY:
		return
	
	if multiplayer.is_server():
		cleanup_prepared_peers[1] = true
		check_cleanup_prepared()
	else:
		notify_lobby_cleanup_prepared.rpc_id(1, request_id)

func wait_for_lobby_players_present(player_ids: Array[int], request_id: int) -> bool:
	var start_time := Time.get_ticks_msec()

	while true:
		if not multiplayer.has_multiplayer_peer():
			return false
		
		if transition_id != request_id:
			return false
		
		if current_scene != NetworkScene.LOBBY:
			return false

		if Time.get_ticks_msec() - start_time > 5000:
			push_warning("Lobby preparation timed out")
			return false

		var lobby := get_tree().root.get_node_or_null("Lobby")

		if lobby == null:
			return false

		var all_present := true

		for id in player_ids:
			if not lobby.has_node(str(id)):
				all_present = false
				break

		if all_present:
			return true

		await get_tree().process_frame

	return false

@rpc("any_peer", "call_remote", "reliable")
func notify_lobby_cleanup_prepared(request_id: int) -> void:
	if not multiplayer.is_server():
		return

	if not transitioning_to_game:
		return
	
	if lobby_removal_started:
		return
	
	if transition_id != request_id:
		return
	
	if current_scene != NetworkScene.LOBBY:
		return

	var sender := multiplayer.get_remote_sender_id()

	if sender not in expected_peers:
		return

	cleanup_prepared_peers[sender] = true

	check_cleanup_prepared()
	
func check_cleanup_prepared() -> void:
	if not multiplayer.is_server():
		return

	if not transitioning_to_game:
		return

	if lobby_removal_started:
		return

	for id in expected_peers:
		if not cleanup_prepared_peers.has(id):
			return

	cleanup_prepared_peers.clear()
	
	lobby_removal_started = true
	
	# Begin removal monitoring on all peers.
	begin_lobby_removal.rpc(transition_id, expected_peers.duplicate())

	# Server-authoritative despawning.
	for id in spawned_peers.keys():
		scene_spawner.despawn_player(id)

@rpc("authority", "call_local", "reliable")
func begin_lobby_removal(request_id: int, player_ids: Array[int]) -> void:
	if transition_id != request_id:
		return
	
	var cleanup_successful := await wait_for_lobby_players_removed(player_ids, request_id)

	if not cleanup_successful:
		return

	if not multiplayer.has_multiplayer_peer():
		return

	if transition_id != request_id:
		return

	if current_scene != NetworkScene.LOBBY:
		return

	if multiplayer.is_server():
		cleanup_ready_peers[1] = true
		check_cleanup_complete()
	else:
		notify_lobby_cleanup_complete.rpc_id(1, request_id)

func wait_for_lobby_players_removed(player_ids: Array[int], request_id: int) -> bool:
	var start_time := Time.get_ticks_msec()
	
	while true:
		if not multiplayer.has_multiplayer_peer():
			return false
		
		if transition_id != request_id:
			return false
		
		if current_scene != NetworkScene.LOBBY:
			return false 

		if Time.get_ticks_msec() - start_time > 5000:
			push_warning("Lobby cleanup timed out")
			return false

		var lobby := get_tree().root.get_node_or_null("Lobby")
	
		if lobby == null:
			return false

		var all_removed := true

		for id in player_ids:
			if lobby.has_node(str(id)):
				all_removed = false
				break

		if all_removed:
			return true

		await get_tree().process_frame
		
	return false

@rpc("any_peer", "call_remote", "reliable")
func notify_lobby_cleanup_complete(request_id: int) -> void:
	if not multiplayer.is_server():
		return

	if not transitioning_to_game:
		return
	
	if not lobby_removal_started:
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

	if not transitioning_to_game:
		return
	
	if not lobby_removal_started:
		return
	
	for id in expected_peers:
		if not cleanup_ready_peers.has(id):
			return

	transitioning_to_game = false
	lobby_removal_started = false
	
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()

	change_network_scene.rpc(NetworkScene.GAME)

@rpc("authority", "call_local", "reliable")
func cancel_lobby_transition(request_id: int) -> void:
	if request_id < transition_id:
		return

	transition_id = request_id

	transitioning_to_game = false
	lobby_removal_started = false

	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()

	print("Lobby transition cancelled")

@rpc("authority", "call_local", "reliable")
func change_network_scene(scene_type: NetworkScene) -> void :
	current_scene = scene_type
	scene_spawner = null
	ready_peers.clear()
	spawned_peers.clear()
	
	GameManager.reset_level()

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

	if transitioning_to_game:
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
		
	if GameManager.start_scheduled or GameManager.game_active:
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
	
	transition_id = 0
	lobby_removal_started = false
	transitioning_to_game = false
	scene_spawner = null
	is_solo = true

	expected_peers.append(1)

	#GameManager.game_state = GameManager.GameState.STARTING
	#GameManager.game_state = GameManager.GameState.PLAYING
	#GameManager.game_active = false
	
	GameManager.reset_clock()
	GameManager.reset_level()
	
	get_tree().change_scene_to_file(base_level_scene)

func start_server() -> void :
	GameManager.reset_clock()
	GameManager.reset_level()
	
	peer = ENetMultiplayerPeer.new()
	var error: = peer.create_server(PORT)

	if error != OK:
		push_error("Failed to start server!")
		return

	multiplayer.multiplayer_peer = peer

	current_scene = NetworkScene.LOBBY
	ready_peers.clear()
	expected_peers.clear()
	spawned_peers.clear()
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()
	
	transition_id = 0
	lobby_removal_started = false
	transitioning_to_game = false
	scene_spawner = null
	is_solo = false

	get_tree().change_scene_to_file(lobby_scene)

func start_client() -> void :
	GameManager.reset_clock()
	GameManager.reset_level()
	
	peer = ENetMultiplayerPeer.new()
	var error: = peer.create_client(IP_ADDRESS, PORT)

	if error != OK:
		push_error("Failed to create client!")
		return

	multiplayer.multiplayer_peer = peer
	
	current_scene = NetworkScene.LOBBY
	ready_peers.clear()
	expected_peers.clear()
	spawned_peers.clear()
	cleanup_prepared_peers.clear()
	cleanup_ready_peers.clear()
	
	transition_id = 0
	lobby_removal_started = false
	transitioning_to_game = false
	scene_spawner = null
	is_solo = false

	await multiplayer.connected_to_server
	
	GameManager.request_server_time()

	get_tree().change_scene_to_file(lobby_scene)
