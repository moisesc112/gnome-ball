extends Control


func _on_server_pressed() -> void:
	HighLevelNetworkHandler.start_server()
	#get_tree().change_scene_to_packed(base_level_scene)
	#$VBoxContainer/Server.release_focus()
	#$VBoxContainer.hide()

func _on_client_pressed() -> void:
	HighLevelNetworkHandler.start_client()
	#get_tree().change_scene_to_packed(base_level_scene)
	#$VBoxContainer/Client.release_focus()
	#$VBoxContainer.hide()
