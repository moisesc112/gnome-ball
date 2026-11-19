extends Area3D

@export var enable_anti_gravity: bool = true



func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return

	if body is RigidBody3D and body.has_method("set_anti_gravity"):
		body.set_anti_gravity(enable_anti_gravity)


func _on_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server():
		return

	if body is RigidBody3D and body.has_method("set_anti_gravity"):
		body.set_anti_gravity(false)
		
		enable_anti_gravity = not enable_anti_gravity
		
		
