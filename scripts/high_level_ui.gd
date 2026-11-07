extends Control

@onready var start_button: Button = $VBoxContainer/StartGameButton

const base_level_scene = "res://scenes/levels/base_level.tscn"

func _ready() -> void:
	if multiplayer.is_server():
		start_button.visible = true
	else:
		start_button.visible = false

func _on_start_game_button_pressed() -> void:
	HighLevelNetworkHandler.start_game()
