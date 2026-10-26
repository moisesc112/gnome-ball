extends Node3D

@export var player: RigidBody3D = null
@export var follow_speed: float = 8.0
@export var max_tilt_degrees: float = 12.0
@export var orbit_speed: float = 8.0
@export var tilt_speed: float = 3.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player == null:
		return
		
	global_position = global_position.lerp(player.global_position, follow_speed * delta)
	
	var input_dir: Vector2 = player.tilt_input
	
	var target_pitch := deg_to_rad(-input_dir.y * max_tilt_degrees)
	var target_roll := deg_to_rad(input_dir.x * max_tilt_degrees)
	
	rotation.x = lerp_angle(rotation.x, target_pitch, clampf(tilt_speed * delta, 0.0, 1.0))
	rotation.z = lerp_angle(rotation.z, target_roll, clampf(tilt_speed * delta, 0.0, 1.0))

	var velocity := player.linear_velocity
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	
	#print("Horizontal Velocity: ", horizontal_velocity.x, ", ", horizontal_velocity.z)
	#print("Horizontal Velocity Length: ", horizontal_velocity.length())
	
	var target_yaw := atan2(-horizontal_velocity.x, -horizontal_velocity.z)

	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(orbit_speed * delta, 0.0, 1.0))
