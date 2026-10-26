extends RigidBody3D

@export var tilt_strength: float = 15.0
@export var camera_rig: Node3D

var tilt_input: Vector2 = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	tilt_input = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	
	var camera_forward := -camera_rig.global_basis.z
	var camera_right := camera_rig.global_basis.x
	
	camera_forward.y = 0.0
	camera_right.y = 0.0
	
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	var move_direction := camera_right * tilt_input.x + camera_forward * -tilt_input.y
	
	var gravity := Vector3(move_direction.x * tilt_strength, -9.8, move_direction.z * tilt_strength)
	
	apply_central_force(gravity * mass)

	
