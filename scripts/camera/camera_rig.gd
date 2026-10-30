extends Node3D

@onready var player: RigidBody3D = get_parent() as RigidBody3D
@export var follow_speed: float = 16.0
@export var max_tilt_degrees: float = 12.0
@export var orbit_speed: float = 16.0
@export var tilt_speed: float = 12.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player == null:
		return
		
	if not player.is_multiplayer_authority():
		return;
	
	# Don't need lerping on camera rig position right now, decide through play testing
	#global_position = global_position.lerp(player.global_position, clampf(follow_speed * delta, 0.0, 1.0))
	global_position = player.global_position
	
	# same reasoning with y rotation, might not be needed
	#rotation.y = lerp_angle(rotation.y, player.control_yaw, clampf(orbit_speed * delta, 0.0, 1.0))
	rotation.y = player.control_yaw
	rotation.x = lerp_angle(rotation.x, player.target_pitch, clampf(tilt_speed * delta, 0.0, 1.0))
	rotation.z = lerp_angle(rotation.z, player.target_roll, clampf(tilt_speed * delta, 0.0, 1.0))
