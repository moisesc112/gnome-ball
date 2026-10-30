extends RigidBody3D

@export var tilt_strength: float = 15.0
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

@onready var ground_ray: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $GnomePivot/GnomeFacing/Gnome/AnimationPlayer
@onready var gnome_pivot: Node3D = $GnomePivot

@export var target_pitch: float = 0.0
@export var target_roll: float = 0.0
@export var target_yaw: float = 0.0
@export var is_walking: bool = false

@onready var gnome_facing: Node3D = $GnomePivot/GnomeFacing

@export var turn_speed: float = 20.0
@export var lean_degrees: float = 10.0
@export var lean_speed: float = 5.0

var tilt_input: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#gnome_pivot.top_level = true
	camera_rig.top_level = true
	self.position = Vector3(0.0, 1.0, 27.0)
	
	if is_multiplayer_authority():
		camera.make_current()
	else:
		camera.set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	gnome_pivot.global_position = global_position + Vector3(0, -0.47, 0)
	gnome_pivot.global_rotation = Vector3.ZERO
	
	if is_multiplayer_authority(): 
		var velocity := linear_velocity
		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

		if horizontal_velocity.length() > 0.2:
			# Face the direction the ball is moving.
			target_yaw = atan2(horizontal_velocity.x, horizontal_velocity.z)

	gnome_facing.rotation.y = lerp_angle(
		gnome_facing.rotation.y,
		target_yaw,
		clampf(turn_speed * delta, 0.0, 1.0)
	)
	
	if is_multiplayer_authority(): 
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

	gnome_facing.rotation.x = lerp_angle(
		gnome_facing.rotation.x,
		target_pitch,
		clampf(lean_speed * delta, 0.0, 1.0)
	)

	gnome_facing.rotation.z = lerp_angle(
		gnome_facing.rotation.z,
		target_roll,
		clampf(lean_speed * delta, 0.0, 1.0)
	)

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
	
	if !is_multiplayer_authority(): return	
	
	if not ground_ray.is_colliding():
		return
		
	tilt_input = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	
	var camera_forward := -camera_rig.global_basis.z
	var camera_right := camera_rig.global_basis.x
	
	camera_forward.y = 0.0
	camera_right.y = 0.0
	
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	var move_direction := camera_right * tilt_input.x + camera_forward * -tilt_input.y
	
	var gravity := Vector3(move_direction.x * tilt_strength, 0.0, move_direction.z * tilt_strength)
	
	apply_central_force(gravity * mass)

	
