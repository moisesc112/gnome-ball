extends CharacterBody3D

#@onready var camera_rig: Node3D = $CameraRig
#@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var camera_rig: Node3D = $CameraRig
#@onready var animation_player: AnimationPlayer = $Gnome_smooth/AnimationPlayer
@onready var animation_player: AnimationPlayer = $gnome_low_poly_smooth/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree

@export var camera_follow_speed: float = 3.0
@export var target_yaw: float = PI
var target_pitch = 0.0
var target_roll = 0.0

@export var gnome_turn_speed: float = 8.0
@export var lean_speed: float = 5.0
@export var lean_degrees: float = 10.0

@export var network_direction: Vector3 = Vector3.ZERO
@export var relative_position: Vector3 = Vector3.ZERO
#@onready var gnome_mesh: Node3D = $Gnome_smooth
@onready var gnome_mesh: Node3D = $gnome_low_poly_smooth
@export var is_walking: bool = false
@export var is_idle: bool = false
@export var is_falling: bool = false
@export var is_rising: bool = false
@export var is_lying_down: bool = false
@export var is_standing_up: bool = false
@export var just_jumped: bool = false
@export var just_emoted: bool = false
@export var just_waved: bool = false
@export var just_slapped: bool = false

@onready var ball: RigidBody3D = get_node_or_null("../PlayerLargeBall") as RigidBody3D
@export var interior_radius: float = 1.0
@export var push_strength: float = 20.0
@export var character_half_height: float = 0.5
@export var movement_acceleration: float = 25.0
@export var ground_friction: float = 2.0

@export var visual_follow_speed: float = 15.0
var smoothed_relative_position: Vector3 = Vector3.ZERO

@export var tumble_speed: float = 5.0
@export var tumble_min_ball_speed: float = 2.0
var idle_ball_rotation: Quaternion
var idle_offset: Vector3
var idle_gnome_rotation: Quaternion
var is_tumbling := false

var tumble_rotation: float = 0.0

@export var is_grounded: bool = false
var previous_ball_position: Vector3
var movement_input: Vector2 = Vector2.ZERO
var is_touching_ball: bool = false
var initial_gnome_offset: Vector3
var idle_gnome_scale: Vector3

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	camera_rig.top_level = true
	animation_tree.active = true
	
	if ball == null:
		ball = get_node_or_null("../PlayerLargeBall") as RigidBody3D

	if ball == null:
		push_error("PlayerLargeBall not found!")
		return
	#initial_gnome_offset = gnome_mesh.position
	#gnome_mesh.position = initial_gnome_offset
	
	#gnome_mesh.position = Vector3.ZERO
	gnome_mesh.rotation.y = target_yaw

	if not is_multiplayer_authority():
		relative_position = global_position - ball.global_position

	smoothed_relative_position = relative_position
	previous_ball_position = get_ball_physics_position()

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func setup(shared_ball: RigidBody3D) -> void:
	ball = shared_ball

func update_animation() -> void:
	if is_multiplayer_authority():
		var vertical_speed = velocity.y
		var speed := movement_input.length_squared()
		
		if speed <= 0.0099:
			is_idle = true
			is_walking = false
		else:
			is_idle = false
			is_walking = true
		
		is_falling = not is_grounded and vertical_speed <= 0.1
		is_rising = not is_grounded and vertical_speed > 0.1
		
		if movement_input.length() > 0.1 or Input.is_action_just_pressed("Jump"):
			is_lying_down = false
			is_standing_up = true
		
		if (Input.is_action_just_pressed("Wave") or Input.is_action_just_pressed("Lay_Down") or Input.is_action_just_pressed("Slap")) and is_grounded:
			just_emoted = true
			
			if Input.is_action_just_pressed("Wave") and is_grounded:
				just_waved = true
			else:
				just_waved = false

			if Input.is_action_just_pressed("Lay_Down") and is_grounded:
				is_lying_down = true
				is_standing_up = false

			if Input.is_action_just_pressed("Slap") and is_grounded:
				just_slapped = true
			else:
				just_slapped = false

		else:
			just_emoted = false
			
	animation_tree.set("parameters/conditions/is_idle", is_idle)
	animation_tree.set("parameters/conditions/is_walking", is_walking)
	animation_tree.set("parameters/conditions/jumped", just_jumped)
	animation_tree.set("parameters/conditions/is_falling", is_falling)
	animation_tree.set("parameters/conditions/is_rising", is_rising)
	animation_tree.set("parameters/conditions/is_grounded", is_grounded)
	animation_tree.set("parameters/conditions/emoted", just_emoted)
	animation_tree.set("parameters/Emotes/conditions/waved", just_waved)
	animation_tree.set("parameters/Emotes/conditions/layed_down", is_lying_down)
	animation_tree.set("parameters/Emotes/conditions/stand_up", is_standing_up)
	animation_tree.set("parameters/Emotes/conditions/slapped", just_slapped)

func is_ball_grounded() -> bool:
	var ground_cast := ball.get_node("GroundCast") as ShapeCast3D
	return ground_cast.is_colliding()

func calculate_local_gnome_rotation(direction: Vector3) -> void:
	# Face the direction the player wants to move.
	if direction.length_squared() > 0.01:
		target_yaw = atan2(direction.x, direction.z)

	# Convert movement direction into gnome-local space.
	var yaw_basis := Basis(Vector3.UP, target_yaw)
	var local_direction := yaw_basis.inverse() * direction

	# Lean relative to the gnome's facing direction.
	target_pitch = deg_to_rad(local_direction.z * lean_degrees)
	target_roll = deg_to_rad(-local_direction.x * lean_degrees)

func apply_gnome_rotation(delta: float) -> void:
	var lean_weight := 1.0 - exp(-lean_speed * delta)
	var turn_weight := 1.0 - exp(-gnome_turn_speed * delta)
	gnome_mesh.rotation.x = lerp_angle(gnome_mesh.rotation.x, target_pitch, lean_weight)
	gnome_mesh.rotation.y = lerp_angle(gnome_mesh.rotation.y, target_yaw, turn_weight)
	gnome_mesh.rotation.z = lerp_angle(gnome_mesh.rotation.z, target_roll, lean_weight)

func start_tumbling(ball_visual: Node3D) -> void:
	is_tumbling = true

	idle_ball_rotation = ball_visual.global_basis.get_rotation_quaternion()

	idle_offset = gnome_mesh.global_position - ball_visual.global_position

	idle_gnome_rotation = gnome_mesh.global_basis.get_rotation_quaternion()
	
	idle_gnome_scale = gnome_mesh.global_basis.get_scale()

func update_tumbling(ball_visual: Node3D) -> void:
	var current_rotation := ball_visual.global_basis.get_rotation_quaternion()

	var rotation_delta := current_rotation * idle_ball_rotation.inverse()

	gnome_mesh.global_position = (
		ball_visual.global_position
		+ rotation_delta * idle_offset
	)
	
	var new_rotation := rotation_delta * idle_gnome_rotation

	gnome_mesh.global_basis = Basis(new_rotation).scaled(idle_gnome_scale)
	
func get_ball_physics_position() -> Vector3:
	return ball.global_position

func _process(_delta: float) -> void:
	if ball == null:
		return
	
	#var visual_ball_position: Vector3 = ball.get_global_transform_interpolated().origin
	#var should_tumble := not is_walking and GameManager.game_state == GameManager.GameState.PLAYING
	#var should_tumble = false
	
	#if should_tumble:
		#if not is_tumbling:
			#gnome_mesh.global_position = (visual_ball_position + relative_position + global_basis * initial_gnome_offset)
			#start_tumbling(ball.get_node("BallVisual"))
		#update_tumbling(ball.get_node("BallVisual"))
	#else:
		#if is_tumbling:
			#is_tumbling = false
			#gnome_mesh.rotation = Vector3(0.0, target_yaw, 0.0)
		#gnome_mesh.global_position = (get_global_transform_interpolated().origin + global_basis * initial_gnome_offset)

func _physics_process(delta: float) -> void:
	if ball == null:
		return
	
	var ball_position = get_ball_physics_position()
	
	if is_multiplayer_authority():
		#update_animation()

		# Calculate position relative to the ball
		var offset = global_position - ball_position
		var distance := offset.length()

		# Detect contact with the interior surface
		is_grounded = distance >= interior_radius - 0.05 and offset.y < 0.0
		
		# Apply gravity
		#if not is_grounded:
		velocity += get_gravity() * delta

		# Jump
		if Input.is_action_just_pressed("Jump") and is_grounded:
			velocity.y = JUMP_VELOCITY
			is_grounded = false
			just_jumped = true
		else:
			just_jumped = false
			
			
		### MAYBE BRING BACK JUMP BUT DISABLE FOR NOW
		###
		#if Input.is_action_just_pressed("Jump"):x
		#	if not multiplayer.is_server():
		#		ball.apply_jump_impulse()
		#	ball.request_jump.rpc_id(1)
		###
		###
		
		if GameManager.local_pause_menu_open: 
			movement_input = Vector2.ZERO
		else:
			movement_input = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
		
		var camera_forward := -camera.global_basis.z
		var camera_right := camera.global_basis.x

		camera_forward.y = 0.0
		camera_right.y = 0.0

		camera_forward = camera_forward.normalized()
		camera_right = camera_right.normalized()
		
		var direction := (camera_right * movement_input.x - camera_forward * movement_input.y).normalized()
		network_direction = direction
		
		if direction.length_squared() > 0.01:
			velocity.x = move_toward(velocity.x, direction.x * SPEED, movement_acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * SPEED, movement_acceleration * delta)
		else:
			# Gentle damping rather than instantly stopping
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)

		var ball_displacement = ball_position - previous_ball_position

		global_position += ball_displacement
		previous_ball_position = ball_position

		# Move the gnome
		global_position += velocity * delta

		# Keep the gnome inside the sphere
		offset = global_position - ball_position
		distance = offset.length()
		var max_distance := interior_radius #- character_half_height
		is_touching_ball = distance >= max_distance - 0.05

		if distance > max_distance:
			var normal := offset.normalized()

			global_position = ball_position + normal * interior_radius

			# Remove velocity pointing through the sphere
			var outward_speed := velocity.dot(normal)

			if outward_speed > 0.0:
				velocity -= normal * outward_speed
				
		if is_touching_ball and direction.length_squared() > 0.01:
			var contact_offset = global_position - ball_position
			
			ball.apply_push(direction, contact_offset)
			
			if not multiplayer.is_server():
				ball.request_push.rpc_id(1, direction, contact_offset)
			
		relative_position = global_position - ball_position
	else :
		#smoothed_relative_position = smoothed_relative_position.lerp(relative_position, 1.0 - exp(-15.0 * delta))
		#global_position = ball_position + smoothed_relative_position
		# add smoothing if gnome mesh jumps around between frames
		global_position = ball_position + relative_position
	
	if not is_tumbling:
		calculate_local_gnome_rotation(network_direction)
		apply_gnome_rotation(delta)
	update_animation()
