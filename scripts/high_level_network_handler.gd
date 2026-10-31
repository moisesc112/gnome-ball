extends Node

const IP_ADDRESS: String = "192.168.0.10"
const PORT: int = 42069

const base_level_scene = "res://scenes/levels/base_level.tscn"

var peer : ENetMultiplayerPeer

enum GameMode {
	SOLO,
	SHARED_BALL,
	RACE
}

var game_mode: GameMode = GameMode.SOLO

func start_solo() -> void:
	game_mode = GameMode.SOLO
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file(base_level_scene)

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file(base_level_scene)

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file(base_level_scene)
