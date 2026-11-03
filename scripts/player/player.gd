extends RigidBody3D

@export var tilt_strength: float = 15.0

# not going to use tilt since not tilting camera anymore, maybe can use for debuff from fairy
@export var tilt_gravity: float = 36.0
@export var max_tilt_degrees: float = 12.0

@export var max_move_speed: float = 15.0
@export var movement_acceleration: float = 20.0
@export var forward_acceleration: float = 7.5
@export var steering_acceleration: float = 7.5

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

@onready var ground_ray: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $GnomePivot/GnomeFacing/Gnome_smooth/AnimationPlayer
@onready var gnome_pivot: Node3D = $GnomePivot
@export var gnome_turn_speed: float = 8.0

@export var target_pitch: float = 0.0
@export var target_roll: float = 0.0
@export var target_yaw: float = 0.0
@export var control_yaw: float = 0.0
@export var is_walking: bool = false
@export var jump_speed: float = 3.5 # og was 3.5

@onready var gnome_facing: Node3D = $GnomePivot/GnomeFacing

@export var turn_speed: float = 6.0
@export var lean_degrees: float = 10.0
@export var lean_speed: float = 5.0
@export var air_turn_speed: float = 2.0

var takeoff_speed: float = 0.0
var was_grounded: bool = false


var tilt_input: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	#gnome_pivot.top_level = true
	camera_rig.top_level = true
	#self.position = Vector3(0.0, 1.0, 27.0)
	
	if is_multiplayer_authority():
		camera.make_current()
	else:
		camera.set_process(false)

func calculate_local_gnome_rotation() -> void:
	var velocity := linear_velocity
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if horizontal_velocity.length() > 0.2:
		# Face the direction the ball is moving.
		target_yaw = atan2(horizontal_velocity.x, horizontal_velocity.z)
	
	var camera_forward := -camera_rig.global_basis.z
	var camera_right := camera_rig.global_basis.x
	
	camera_forward.y = 0.0
	camera_right.y = 0.0

	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	var world_input_direction := (
		camera_right * tilt_input.x
		- camera_forward * tilt_input.y
	)
	
	# Convert world-space input into gnome-local coordinates.
	# Use only yaw so existing lean doesn't affect the conversion.
	var yaw_basis := Basis(Vector3.UP, gnome_facing.rotation.y)
	var local_input := yaw_basis.inverse() * world_input_direction
	
	# Lean relative to the direction the gnome is facing.
	# Assumes gnome faces +Z in its default pose.
	target_pitch = deg_to_rad(local_input.z * lean_degrees)
	target_roll = deg_to_rad(-local_input.x * lean_degrees)

func apply_gnome_rotation(delta: float) -> void:
	gnome_facing.rotation.x = lerp_angle(gnome_facing.rotation.x, -target_pitch, clampf(lean_speed * delta, 0.0, 1.0))
	gnome_facing.rotation.y = lerp_angle(gnome_facing.rotation.y, target_yaw, clampf(gnome_turn_speed * delta, 0.0, 1.0))
	#gnome_facing.rotation.y = control_yaw
	gnome_facing.rotation.z = lerp_angle(gnome_facing.rotation.z, -target_roll, clampf(lean_speed * delta, 0.0, 1.0))

func _process(delta: float) -> void:
	gnome_pivot.global_position = global_position + Vector3(0, -0.47, 0)
	gnome_pivot.global_rotation = Vector3.ZERO
	
	#if is_multiplayer_authority():
		#calculate_local_gnome_rotation()
	
	apply_gnome_rotation(delta)

func update_animation() -> void:
	if is_multiplayer_authority():
		var speed:= Vector2(linear_velocity.x, linear_velocity.z).length()
		is_walking = speed > 0.2
	
	if is_walking:
		if animation_player.current_animation != "WalkAction":
			animation_player.play("WalkAction", 0.2)
	else:
		if animation_player.current_animation != "IdleAction":
			animation_player.play("IdleAction", 0.2)

func _physics_process(delta: float) -> void:
	ground_ray.global_rotation = Vector3.ZERO
	update_animation()
	
	if !is_multiplayer_authority(): 
		return
	
	if (Input.is_action_just_pressed("Jump") and ground_ray.is_colliding()):
		apply_central_impulse(Vector3.UP * mass * jump_speed)
	
	tilt_input = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	
	var camera_forward := -camera_rig.global_basis.z
	var camera_right := camera_rig.global_basis.x

	camera_forward.y = 0.0
	camera_right.y = 0.0

	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()

	var move_direction := (
		camera_right * tilt_input.x
		- camera_forward * tilt_input.y
	)
	
	target_pitch = deg_to_rad(-tilt_input.y * max_tilt_degrees)
	target_roll = deg_to_rad(tilt_input.x * max_tilt_degrees)
	
	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	
	if horizontal_velocity.length() > 0.5:
		var desired_yaw := atan2(-linear_velocity.x, -linear_velocity.z)
		control_yaw = lerp_angle(control_yaw, desired_yaw, clampf(turn_speed * delta, 0.0, 1.0))
		#control_yaw = desired_yaw
		target_yaw = desired_yaw;
	
	#if not ground_ray.is_colliding():
	#	return
	
	var local_direction := Vector3(tilt_input.x, 0.0, tilt_input.y)
	#var acceleration_strength := sin(deg_to_rad(max_tilt_degrees)) * tilt_gravity
	#var local_acceleration := local_direction * acceleration_strength
	#var local_acceleration := local_direction * movement_acceleration
	var local_acceleration := Vector3(tilt_input.x * steering_acceleration, 0.0, tilt_input.y * forward_acceleration)
	
	#var local_acceleration := move_direction * acceleration_strength
	
	#var local_acceleration = Vector3(sin(target_roll), 0.0, -sin(target_pitch)) * tilt_gravity;
	var stage_basis := Basis(Vector3.UP, control_yaw)
	#var stage_basis := Basis(Vector3.UP, camera_rig.global_rot)
	var world_acceleration = stage_basis * local_acceleration
	
	var grounded := ground_ray.is_colliding()
	
	if was_grounded and not grounded:
		takeoff_speed = Vector2(linear_velocity.x, linear_velocity.z).length()
	
	print("Horizontal Speed: ", horizontal_velocity.length())
	if horizontal_velocity.length() >= max_move_speed:
		var velocity_direction := horizontal_velocity.normalized()

		# Remove acceleration that would increase speed further.
		var forward_acceleration := world_acceleration.dot(velocity_direction)

		if forward_acceleration > 0.0:
			world_acceleration -= velocity_direction * forward_acceleration
	
	apply_central_force(world_acceleration * mass)
	
	if not grounded:
		if horizontal_velocity.length() > takeoff_speed:
			horizontal_velocity = horizontal_velocity.normalized() * takeoff_speed
			
			linear_velocity.x = horizontal_velocity.x
			linear_velocity.z = horizontal_velocity.z
			
	was_grounded = grounded
