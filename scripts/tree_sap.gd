extends Area3D

@export var sap_strength: float = 8.0
@export var angular_sap_strength: float = 5.0

var affected_bodies: Array[RigidBody3D] = []

func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		affected_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		affected_bodies.erase(body)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return

	for body in affected_bodies:
		if not is_instance_valid(body):
			continue

		var velocity := body.linear_velocity

		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

		var resistance := -horizontal_velocity * sap_strength * body.mass

		body.apply_central_force(resistance)
		body.apply_torque(-body.angular_velocity * angular_sap_strength * body.mass)
