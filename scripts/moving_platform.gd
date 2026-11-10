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

func _ready() -> void:
	start_position = position
	
	if move_direction == MoveDirection.UP:
		initial_direction = 1.0
	elif move_direction == MoveDirection.DOWN:
		initial_direction = -1.0

func _physics_process(_delta: float) -> void:
	if not GameManager.game_active:
		return
		
	if move_distance <= 0.0 or move_speed <= 0.0:
		return
		
	var t := GameManager.get_level_time()

	# Time required to travel from center to one endpoint
	var half_duration := move_distance / move_speed

	# Full cycle: center -> endpoint -> opposite endpoint -> center
	var cycle_duration := half_duration * 4.0

	# Position within the repeating cycle
	var phase := fposmod(t, cycle_duration)

	var offset: float

	if phase < half_duration:
		offset = phase * move_speed
	elif phase < half_duration * 3.0:
		offset = move_distance - (phase - half_duration) * move_speed
	else:
		offset = -move_distance + (phase - half_duration * 3.0) * move_speed

	position.y = start_position.y + offset * initial_direction
