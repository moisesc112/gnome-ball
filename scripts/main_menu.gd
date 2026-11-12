extends Control

const lobby_scene = preload("res://scenes/ui/menus/lobby.tscn")

@onready var disconnect_popup: AcceptDialog = $CenterContainer/DisconnectPopup

func _ready() -> void:
	if GameManager.disconnect_reason != "":
		disconnect_popup.dialog_text = GameManager.disconnect_reason
		disconnect_popup.popup_centered()
		GameManager.disconnect_reason = "" 


func _process(_delta: float) -> void:
	pass


func _on_host_game_button_pressed() -> void:
	HighLevelNetworkHandler.start_server()

func _on_join_game_button_pressed() -> void:
	HighLevelNetworkHandler.start_client()


func _on_play_offline_button_pressed() -> void:
	HighLevelNetworkHandler.start_solo()


func _on_settings_button_pressed() -> void:
	pass


func _on_quit_button_pressed() -> void:
	get_tree().quit()
