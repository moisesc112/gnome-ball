
extends AnimatableBody3D

enum MoveDirection {
	UP,
	DOWN
}

@export var move_distance: float = 5.0
@export var move_speed: float = 2.0
@export var move_direction: MoveDirection = MoveDirection.UP

var start_position: Vector3
var initial_direction: float = 1.0
var elapsed_time: float = 0.0


func _ready() -> void:
	start_position = position

	if move_direction == MoveDirection.UP:
		initial_direction = 1.0
	else:
		initial_direction = -1.0


func _physics_process(_delta: float) -> void:
	if not GameManager.game_active:
		return

	if move_distance <= 0.0 or move_speed <= 0.0:
		return

	elapsed_time = GameManager.get_physics_level_time()

	var angular_frequency := move_speed / move_distance

	var offset := move_distance * sin(
		elapsed_time * angular_frequency
	)

	position.y = start_position.y + offset * initial_direction
