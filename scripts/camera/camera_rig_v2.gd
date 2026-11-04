
extends Node3D

@onready var player: RigidBody3D = get_parent() as RigidBody3D
@onready var spring_arm: SpringArm3D = $SpringArm3D

@export_group("Manual Camera")
@export var mouse_sensitivity: float = 0.0025
@export var default_pitch: float = -25.0
@export var min_pitch: float = -60.0
@export var max_pitch: float = 30.0

@export_group("Auto Rotation")
@export var horizontal_auto_rotate: bool = true
@export var vertical_auto_rotate: bool = false
@export var auto_rotate_delay: float = 2.0
@export var horizontal_follow_speed: float = 1.5
@export var vertical_follow_speed: float = 1.0

@export_group("Active Steering")
@export var active_steering_follow: bool = true
@export var steering_follow_speed: float = 1.0
@export var minimum_follow_speed: float = 2.0

var camera_pitch: float = 0.0
var time_since_mouse_input: float = 999.0


func _ready() -> void:
	camera_pitch = deg_to_rad(default_pitch)
	spring_arm.rotation.x = camera_pitch
	
	rotation.y = player.get_node("GnomePivot/GnomeFacing").global_rotation.y

	if player.is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not player.is_multiplayer_authority():
		return

	# ESC releases the mouse.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# Left click recaptures the mouse.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return

	# Mouse look is always active while captured.
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return

		# Immediate horizontal rotation.
		rotation.y -= event.relative.x * mouse_sensitivity

		# Immediate vertical rotation.
		camera_pitch -= event.relative.y * mouse_sensitivity

		camera_pitch = clampf(
			camera_pitch,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

		spring_arm.rotation.x = camera_pitch

		time_since_mouse_input = 0.0


func _physics_process(delta: float) -> void:
	if not player.is_multiplayer_authority():
		return

	# Follow player position immediately.
	global_position = player.global_position

	time_since_mouse_input += delta

	# Allow manual camera direction to persist for 2 seconds.
	if time_since_mouse_input < auto_rotate_delay:
		return

	var velocity := player.linear_velocity

	var horizontal_velocity := Vector3(
		velocity.x,
		0.0,
		velocity.z
	)

	var horizontal_speed := horizontal_velocity.length()
	var grounded = player.ground_ray.is_colliding()
	var has_movement_input = player.tilt_input.length() > 0.1

	# ----------------------------------------------------
	# HORIZONTAL AUTO ROTATION
	# ----------------------------------------------------

	if horizontal_auto_rotate:
		if horizontal_speed > minimum_follow_speed:

			var should_follow := false
			var follow_speed_value := horizontal_follow_speed

			if has_movement_input and active_steering_follow:
				# Follow velocity during active movement,
				# including while airborne.
				should_follow = true
				follow_speed_value = steering_follow_speed

			elif grounded and not has_movement_input:
				# Passive recentering only when grounded.
				should_follow = true
				follow_speed_value = horizontal_follow_speed

			if should_follow:
				var desired_yaw := atan2(
					-horizontal_velocity.x,
					-horizontal_velocity.z
				)

				var weight := (
					1.0 - exp(-follow_speed_value * delta)
				)

				rotation.y = lerp_angle(
					rotation.y,
					desired_yaw,
					weight
				)

	# ----------------------------------------------------
	# VERTICAL AUTO ROTATION
	# ----------------------------------------------------

	if vertical_auto_rotate and grounded:
		var target_pitch := deg_to_rad(default_pitch)

		var weight := (
			1.0 - exp(-vertical_follow_speed * delta)
		)

		camera_pitch = lerp_angle(
			camera_pitch,
			target_pitch,
			weight
		)

		spring_arm.rotation.x = camera_pitch
