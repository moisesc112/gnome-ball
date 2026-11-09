extends Node3D

@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
	Engine.max_fps = 60
	
	GameManager.game_state = GameManager.GameState.PLAYING
	
	await get_tree().process_frame
	
	HighLevelNetworkHandler.register_scene_spawner(multiplayer_spawner, HighLevelNetworkHandler.NetworkScene.GAME)
