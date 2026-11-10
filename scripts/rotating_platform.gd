extends AnimatableBody3D

enum RotationDirection {
	CLOCKWISE,
	COUNTERCLOCKWISE
}

enum AxisDirection {
	X,
	Y,
	Z
}

@export var rotation_speed: float = 120.0
@export var rotation_direction: RotationDirection = RotationDirection.CLOCKWISE
@export var axis_direction: AxisDirection = AxisDirection.Y

func rotate_x_axis(delta: float) -> void:
	if rotation_direction == RotationDirection.CLOCKWISE:
		rotate_x(deg_to_rad(rotation_speed) * delta)
	else:
		rotate_x(deg_to_rad(-rotation_speed) * delta)

func rotate_y_axis(delta: float) -> void:
	if rotation_direction == RotationDirection.CLOCKWISE:
		rotate_y(deg_to_rad(rotation_speed) * delta)
	else:
		rotate_y(deg_to_rad(-rotation_speed) * delta)

func rotate_z_axis(delta: float) -> void:
	if rotation_direction == RotationDirection.CLOCKWISE:
		rotate_z(deg_to_rad(rotation_speed) * delta)
	else:
		rotate_z(deg_to_rad(-rotation_speed) * delta)

func _physics_process(delta: float) -> void:
	if not GameManager.game_active:
		return
	
	match axis_direction:
		AxisDirection.X:
			rotate_x_axis(delta)
		AxisDirection.Y:
			rotate_y_axis(delta)
		AxisDirection.Z:
			rotate_z_axis(delta)
