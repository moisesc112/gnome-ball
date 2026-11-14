extends Control

@onready var start_button: Button = $VBoxContainer/StartGameButton
@onready var lobby_id_button: Button = $VBoxContainer/CopyLobbyIDButton
@onready var steam_lobby_id: Label = $VBoxContainer/SteamLobbyID
@onready var invite_friends_button: Button = $VBoxContainer/InviteFriendsButton

const base_level_scene = "res://scenes/levels/base_level.tscn"

func _ready() -> void:
	if multiplayer.is_server():
		start_button.visible = true
	else:
		start_button.visible = false
		
	if HighLevelNetworkHandler.network_transport == HighLevelNetworkHandler.NetworkTransport.STEAM:
		steam_lobby_id.text = "Lobby ID: " + str(HighLevelNetworkHandler.steam_lobby_id)
		steam_lobby_id.visible = true
		lobby_id_button.visible = true
		invite_friends_button.visible = true
	else:
		steam_lobby_id.visible = false
		lobby_id_button.visible = false
		invite_friends_button.visible = false 

func _on_start_game_button_pressed() -> void:
	HighLevelNetworkHandler.start_game()

func _on_leave_lobby_button_pressed() -> void:
	HighLevelNetworkHandler.leave_session()

func _on_copy_lobby_id_button_pressed() -> void:
	DisplayServer.clipboard_set(str(HighLevelNetworkHandler.steam_lobby_id))

func _on_invite_friends_button_pressed() -> void:
	HighLevelNetworkHandler.invite_steam_friends()
