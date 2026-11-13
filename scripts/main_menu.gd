extends Control

const lobby_scene = preload("res://scenes/ui/menus/lobby.tscn")

@onready var disconnect_popup: AcceptDialog = $CenterContainer/DisconnectPopup
@onready var steam_lobby_input: LineEdit = $CenterContainer/VBoxContainer/SteamLobbyIDInput

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


func _on_host_steam_button_pressed() -> void:
	HighLevelNetworkHandler.start_steam_server()


func _on_join_steam_button_pressed() -> void:
	var lobby_id_text := steam_lobby_input.text.strip_edges()
	
	if not lobby_id_text.is_valid_int():
		push_warning("Invalid Steam lobby ID!")
		return
		
	var lobby_id := int(lobby_id_text)
	
	if lobby_id <= 0:
		push_warning("Steam lobby ID must be positive!")
		return
	
	HighLevelNetworkHandler.join_steam_lobby(lobby_id)
