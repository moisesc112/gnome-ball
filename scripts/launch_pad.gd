extends Node3D

@export var launch_speed: float = 10.0
@onready var launch_area: Area3D = $Area3D

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		var launch_direction = global_transform.basis.y.normalized()
		
		var current_speed = body.linear_velocity.dot(launch_direction)
		var speed_to_add = maxf(launch_speed - current_speed, 0.0)
		
		body.apply_central_impulse(
			launch_direction * speed_to_add * body.mass
		)
