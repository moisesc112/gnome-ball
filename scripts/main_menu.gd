extends Control

const lobby_scene = preload("res://scenes/ui/menus/lobby.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_multiplayer_button_pressed() -> void:
	get_tree().change_scene_to_packed(lobby_scene)


func _on_play_solo_button_pressed() -> void:
	pass # Replace with function body.


func _on_settings_button_pressed() -> void:
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	pass # Replace with function body.
