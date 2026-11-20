extends AnimatableBody3D

@export var max_angle: float = 30.0
@export var swing_speed: float = 2.0

var time: float = 0.0

func _physics_process(delta: float) -> void:
	time += delta
	rotation.z = deg_to_rad(max_angle) * sin(time * swing_speed)
