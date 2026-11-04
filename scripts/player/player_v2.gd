
extends RigidBody3D

@export_group("Movement")
@export var max_move_speed: float = 15.0
@export var forward_acceleration: float = 15.0
@export var steering_acceleration: float = 15.0
@export var braking_acceleration: float = 25.0
@export var lateral_grip: float = 1.0
@export var air_braking_enabled: bool = false
@export var turn_speed: float = 8.0
@export var turn_speed_retention: float = 0.60

@export_group("Air Physics")
@export var fall_gravity_multiplier: float = 1.5

@export_group("Jump")
@export var jump_speed: float = 3.5

@export_group("Gnome")
@export var gnome_turn_speed: float = 8.0
@export var lean_degrees: float = 10.0
@export var lean_speed: float = 5.0
@export var target_pitch: float = 0.0
@export var target_roll: float = 0.0
@export var target_yaw: float = 0.0
@export var is_walking: bool = false

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var ground_ray: RayCast3D = $RayCast3D
@onready var gnome_pivot: Node3D = $GnomePivot
@onready var gnome_facing: Node3D = $GnomePivot/GnomeFacing
@onready var animation_player: AnimationPlayer = $GnomePivot/GnomeFacing/Gnome_smooth/AnimationPlayer
@onready var speed_label: Label = $CanvasLayer/SpeedLabel

var tilt_input: Vector2 = Vector2.ZERO
var takeoff_speed: float = 0.0
var was_grounded: bool = false

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	camera_rig.top_level = true
	if is_multiplayer_authority():
		camera.make_current()
	else:
		camera.set_process(false)
		speed_label.hide()
		
	was_grounded = ground_ray.is_colliding()
	takeoff_speed = Vector2(linear_velocity.x, linear_velocity.z).length()

func calculate_local_gnome_rotation() -> void:
	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if horizontal_velocity.length() > 0.2:
		target_yaw = atan2(-horizontal_velocity.x, -horizontal_velocity.z)

	var camera_forward := -camera_rig.global_basis.z
	var camera_right := camera_rig.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	var world_input_direction := camera_right * tilt_input.x - camera_forward * tilt_input.y
	var yaw_basis := Basis(Vector3.UP, gnome_facing.rotation.y)
	var local_input := yaw_basis.inverse() * world_input_direction
	target_pitch = deg_to_rad(local_input.z * lean_degrees)
	target_roll = deg_to_rad(-local_input.x * lean_degrees)

func apply_gnome_rotation(delta: float) -> void:
	var lean_weight := 1.0 - exp(-lean_speed * delta)
	var turn_weight := 1.0 - exp(-gnome_turn_speed * delta)
	gnome_facing.rotation.x = lerp_angle(gnome_facing.rotation.x, -target_pitch, lean_weight)
	gnome_facing.rotation.y = lerp_angle(gnome_facing.rotation.y, target_yaw, turn_weight)
	gnome_facing.rotation.z = lerp_angle(gnome_facing.rotation.z, -target_roll, lean_weight)

func update_animation() -> void:
	if is_multiplayer_authority():
		var speed := Vector2(linear_velocity.x, linear_velocity.z).length()
		is_walking = speed > 0.2
	if is_walking:
		if animation_player.current_animation != "WalkAction":
			animation_player.play("WalkAction", 0.2)
	else:
		if animation_player.current_animation != "IdleAction":
			animation_player.play("IdleAction", 0.2)

func _process(delta: float) -> void:
	gnome_pivot.global_position = global_position + Vector3(0.0, -0.47, 0.0)
	gnome_pivot.global_rotation = Vector3.ZERO
	apply_gnome_rotation(delta)
	
	if is_multiplayer_authority():
		#var speed_kmh := linear_velocity.length() * 3.6
		#speed_label.text = "%.0f km/h" % speed_kmh
		var speed_mph := linear_velocity.length() * 2.23694
		speed_label.text = "%.0f mph" % speed_mph

func _physics_process(delta: float) -> void:
	ground_ray.global_rotation = Vector3.ZERO
	update_animation()
	if not is_multiplayer_authority():
		return

	var grounded := ground_ray.is_colliding()
	if Input.is_action_just_pressed("Jump") and grounded:
		apply_central_impulse(Vector3.UP * mass * jump_speed)
		
	if not grounded and linear_velocity.y < 0.0:
		var gravity := ProjectSettings.get_setting(
		    "physics/3d/default_gravity"
		) as float

		var extra_gravity := (
			gravity * (fall_gravity_multiplier - 1.0)
		)

		apply_central_force(Vector3.DOWN * extra_gravity * mass)

	tilt_input = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	var camera_forward := -camera_rig.global_basis.z
	var camera_right := camera_rig.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()

	calculate_local_gnome_rotation()

	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var input_acceleration := camera_right * tilt_input.x * steering_acceleration - camera_forward * tilt_input.y * forward_acceleration
	var world_acceleration := input_acceleration

	# Split existing momentum into along-input and sideways components.
	# Reverse braking acts along input; lateral grip damps sideways sliding.
	if (grounded or air_braking_enabled) and input_acceleration.length() > 0.1:
		var desired_direction := input_acceleration.normalized()
		var forward_speed := horizontal_velocity.dot(desired_direction)
		var forward_velocity := desired_direction * forward_speed
		var lateral_velocity := horizontal_velocity - forward_velocity
		if forward_speed < 0.0:
			world_acceleration += desired_direction * braking_acceleration
		world_acceleration -= lateral_velocity * lateral_grip

	if was_grounded and not grounded:
		takeoff_speed = horizontal_speed

	# Prevent input from increasing speed further along the current velocity
	# once at the cap, but still allow braking and redirection.
	if horizontal_speed >= max_move_speed and horizontal_speed > 0.0:
		var velocity_direction := horizontal_velocity.normalized()
		var acceleration_along_velocity := world_acceleration.dot(velocity_direction)
		if acceleration_along_velocity > 0.0:
			world_acceleration -= velocity_direction * acceleration_along_velocity

	apply_central_force(world_acceleration * mass)

	# Retain the previous airborne horizontal takeoff-speed cap.
	if not grounded and takeoff_speed > 0.0 and horizontal_speed > takeoff_speed:
		var limited_velocity := horizontal_velocity.normalized() * takeoff_speed
		linear_velocity.x = limited_velocity.x
		linear_velocity.z = limited_velocity.z

	was_grounded = grounded
