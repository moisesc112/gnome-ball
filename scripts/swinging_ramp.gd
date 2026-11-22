extends AnimatableBody3D

###
### Reducing friction scales difficulty of swinging ramp
### Maybe start with 0.3-0.5, next diffculity 0.1-0.3, next 0.0
###

@export_range(0.0, 90.0, 1.0) var max_angle: float = 30.0
@export_range(0.1, 10.0, 0.1) var swing_speed: float = 2.0

@export var phase_offset: float = 0.0
@export var reverse_direction: bool = false

var time: float = 0.0
var initial_rotation: Vector3


func _ready() -> void:
	initial_rotation = rotation


func _physics_process(delta: float) -> void:
	time += delta

	var direction := -1.0 if reverse_direction else 1.0

	var angle := sin(
		time * swing_speed + phase_offset
	) * deg_to_rad(max_angle) * direction

	rotation.z = initial_rotation.z + angle
