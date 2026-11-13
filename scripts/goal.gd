extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
		
	if not body is RigidBody3D:
		return
		
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return
	
	GameManager.finish_game()
