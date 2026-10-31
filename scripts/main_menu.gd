extends Control

const lobby_scene = preload("res://scenes/ui/menus/lobby.tscn")

func _ready() -> void:
	pass 


func _process(delta: float) -> void:
	pass


func _on_multiplayer_button_pressed() -> void:
	get_tree().change_scene_to_packed(lobby_scene)


func _on_play_solo_button_pressed() -> void:
	HighLevelNetworkHandler.start_solo()


func _on_settings_button_pressed() -> void:
	pass


func _on_quit_button_pressed() -> void:
	get_tree().quit()
