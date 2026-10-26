extends RigidBody3D

@export var tilt_strength: float = 15.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("Move_Left", "Move_Right", "Move_Backward", "Move_Forward")
	var gravity := Vector3(-input_dir.x * tilt_strength, -9.8, input_dir.y * tilt_strength)	
	apply_central_force(gravity * mass)

	
