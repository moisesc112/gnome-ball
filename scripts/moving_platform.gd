extends AnimatableBody3D


enum MoveDirection {
	UP,
	DOWN
}

@export var move_distance: float = 5.0
@export var move_speed: float = 2.0
@export var move_direction: MoveDirection = MoveDirection.UP

var start_position: Vector3
var direction: float = 1.0

func _ready() -> void:
	start_position = position
	
	if move_direction == MoveDirection.UP:
		direction = 1.0
	elif move_direction == MoveDirection.DOWN:
		direction = -1.0

func _physics_process(delta: float) -> void:
	pass
	if not GameManager.game_active:
		return
		
	position.y += direction * move_speed * delta

	if position.y >= start_position.y + move_distance:
		direction = -1.0

	elif position.y <= start_position.y - move_distance:
		direction = 1.0
