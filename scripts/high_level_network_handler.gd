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

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_server_disconnected() -> void:
	GameManager.disconnect_reason = "Connection to host lost"
	leave_session()
	
func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
		
	expected_peers.erase(id)
	ready_peers.erase(id)
	spawned_peers.erase(id)
	
	if scene_spawner == null:
		return
	
	scene_spawner.despawn_player(id)

func leave_session() -> void:
	var multiplayer_peer := multiplayer.multiplayer_peer
	
	if multiplayer_peer != null:
		multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	expected_peers.clear()
	ready_peers.clear()
	spawned_peers.clear()
	
	is_solo = false
	scene_spawner = null
	current_scene = NetworkScene.LOBBY
	GameManager.local_pause_menu_open = false
	GameManager.game_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu_world.tscn")

func start_game() -> void :
	if not multiplayer.is_server():
		return

	expected_peers.clear()
	expected_peers.append(1)

	for id in multiplayer.get_peers():
		expected_peers.append(id)

	change_network_scene.rpc(NetworkScene.GAME)

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
	is_solo = false

	await multiplayer.connected_to_server
	
	GameManager.request_server_time()

	get_tree().change_scene_to_file(lobby_scene)
