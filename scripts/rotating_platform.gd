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

var initial_rotation: Quaternion

func _ready() -> void:
	initial_rotation = quaternion

func _physics_process(_delta: float) -> void:
	if not GameManager.game_active:
		return
		
	var t := GameManager.get_level_time()
	
	var direction := 1.0
	if rotation_direction == RotationDirection.COUNTERCLOCKWISE:
		direction = -1.0

	var angle_degrees := fposmod(rotation_speed * direction * t, 360.0)
	var angle := deg_to_rad(angle_degrees)

	var axis := Vector3.UP

	match axis_direction:
		AxisDirection.X:
			axis = Vector3.RIGHT
		AxisDirection.Y:
			axis = Vector3.UP
		AxisDirection.Z:
			axis = Vector3.BACK

	quaternion = initial_rotation * Quaternion(axis, angle)
