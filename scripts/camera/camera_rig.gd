extends Node3D

@onready var player: RigidBody3D = get_parent() as RigidBody3D
@onready var spring_arm: SpringArm3D = $SpringArm3D

@export var follow_speed: float = 16.0
@export var max_tilt_degrees: float = 12.0
@export var orbit_speed: float = 16.0
@export var tilt_speed: float = 12.0
@export var mouse_sensitivity: float = 0.0025

var camera_pitch: float = deg_to_rad(-25.0)
var is_free_looking: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spring_arm.rotation.x = camera_pitch

	#if player.is_multiplayer_authority():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	#if not player.is_multiplayer_authority():
	#return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_free_looking = event.pressed
			if is_free_looking:
				camera_pitch = spring_arm.rotation.x
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				
	if event is InputEventMouseMotion and is_free_looking:
		rotation.y -= event.relative.x * mouse_sensitivity

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clampf(
			camera_pitch,
			deg_to_rad(-60.0),
			deg_to_rad(30.0)
		)

		spring_arm.rotation.x = camera_pitch

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	if not is_free_looking:
		rotation.y = lerp_angle(rotation.y, player.control_yaw, clampf(orbit_speed * delta, 0.0, 1.0))
		spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x, deg_to_rad(-25.0), clampf(orbit_speed * delta, 0.0, 1.0))
	#rotation.y = player.control_yaw
	
	#
	# Playtest if camera updates pitch and roll. maybe reduce from physics value. maybe only pitch no roll visual 
	#
	
	#rotation.x = lerp_angle(rotation.x, player.target_pitch, clampf(tilt_speed * delta, 0.0, 1.0))
	#rotation.z = lerp_angle(rotation.z, player.target_roll, clampf(tilt_speed * delta, 0.0, 1.0))
