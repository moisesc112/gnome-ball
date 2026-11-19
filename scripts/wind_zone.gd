extends Area3D

@export var wind_strength: float = 0.5

var affected_bodies: Array[RigidBody3D] = []

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return

	var wind_direction := -global_basis.z

	for body in affected_bodies:
		if is_instance_valid(body):
			body.apply_central_force(wind_direction * wind_strength * body.mass)


func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		print("player entered wind zone")
		affected_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		print("player left wind zone")
		affected_bodies.erase(body)
