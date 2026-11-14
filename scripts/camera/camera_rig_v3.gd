extends Node3D

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

@export_group("Manual Camera")
@export var mouse_sensitivity: float = 0.0025
@export var default_pitch: float = -25.0
@export var min_pitch: float = -60.0
@export var max_pitch: float = 30.0

@export_group("Auto Rotation")
@export var camera_follow_speed: float = 5.0
@export var horizontal_auto_rotate: bool = true
@export var vertical_auto_rotate: bool = false
@export var auto_rotate_delay: float = 2.0
@export var horizontal_follow_speed: float = 1.5
@export var vertical_follow_speed: float = 1.0

@export_group("Active Steering")
@export var active_steering_follow: bool = true
@export var steering_follow_speed: float = 1.0
@export var minimum_follow_speed: float = 2.0

@export_group("Camera Zoom")
@export var zoom_step: float = 0.5
@export var min_zoom: float = 2.0
@export var zoom_smoothness: float = 10.0
@export var zoom_out_height: float = 1.0
@export var zoom_in_height: float = -0.5

var target_zoom: float
var max_zoom: float

var ball: RigidBody3D
var camera_pitch: float = 0.0
var time_since_mouse_input: float = 999.0


func _ready() -> void:
	process_priority = 10
	top_level = true

	if not player.is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return

	GameManager.game_started.connect(update_camera)
	GameManager.game_finished.connect(_on_game_finished)

	update_camera()
	
	if player.is_multiplayer_authority() and GameManager.game_state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	camera_pitch = deg_to_rad(default_pitch)
	spring_arm.rotation.x = camera_pitch
	max_zoom = spring_arm.spring_length
	target_zoom = max_zoom

	ball = player.get_node_or_null("../PlayerLargeBall") as RigidBody3D

	if ball != null:
		global_position = ball.global_position

	# Start facing the same direction as the gnome.
	global_rotation.y = player.global_rotation.y

func _on_game_finished(_final_time: float) -> void:
	update_camera()

func update_camera() -> void:
	if not player.is_multiplayer_authority():
		return
	
	if GameManager.game_state == GameManager.GameState.LOBBY:
		camera.current = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif GameManager.game_state == GameManager.GameState.PLAYING:
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif GameManager.game_state == GameManager.GameState.FINISHED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not player.is_multiplayer_authority():
		return
		
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return
		
	if GameManager.local_pause_menu_open:
		return

	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return

		rotation.y -= event.relative.x * mouse_sensitivity

		camera_pitch -= event.relative.y * mouse_sensitivity

		camera_pitch = clampf(
			camera_pitch,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

		spring_arm.rotation.x = camera_pitch
		time_since_mouse_input = 0.0
	
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				target_zoom -= zoom_step
			MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom += zoom_step

		target_zoom = clampf(target_zoom, min_zoom, max_zoom)

func _process(delta: float) -> void:
	if not player.is_multiplayer_authority():
		return

	if ball == null:
		ball = player.ball

	if ball == null:
		return

	# Camera position: follow the visual ball.
	global_position = ball.get_global_transform_interpolated().origin
	
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_zoom, 1.0 - exp(-zoom_smoothness * delta))
	
	# Adjust spring arm height based on zoom.
	var zoom_ratio := inverse_lerp(max_zoom, min_zoom, spring_arm.spring_length)

	spring_arm.position.y = lerpf(zoom_out_height, zoom_in_height, zoom_ratio)
	
	# Camera rotation.
	time_since_mouse_input += delta

	if time_since_mouse_input < auto_rotate_delay:
		return

	var velocity: Vector3 = ball.linear_velocity
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()

	var grounded = player.is_ball_grounded()
	var has_movement_input = player.movement_input.length() > 0.1

	if horizontal_auto_rotate and horizontal_speed > minimum_follow_speed:
		var should_follow := false
		var follow_speed_value := horizontal_follow_speed

		if has_movement_input and active_steering_follow:
			should_follow = true
			follow_speed_value = steering_follow_speed
		elif grounded and not has_movement_input:
			should_follow = true

		if should_follow:
			var desired_yaw := atan2(
				-horizontal_velocity.x,
				-horizontal_velocity.z
			)

			var weight := 1.0 - exp(-follow_speed_value * delta)

			rotation.y = lerp_angle(
				rotation.y,
				desired_yaw,
				weight
			)

	if vertical_auto_rotate and grounded:
		var target_pitch := deg_to_rad(default_pitch)
		var weight := 1.0 - exp(-vertical_follow_speed * delta)

		camera_pitch = lerp_angle(
			camera_pitch,
			target_pitch,
			weight
		)

		spring_arm.rotation.x = camera_pitch
