extends RigidBody3D

@onready var ground_cast: ShapeCast3D = $GroundCast
@onready var ball_visual: Node3D = $BallVisual
@onready var contact_shadow: MeshInstance3D = $ContactShadow
@onready var shadow_ray: RayCast3D = $ShadowRay

@export var jump_force: float = 7.0
@export var lobby_push_force: float = 1.5
@export var push_force: float = 25.0
@export var max_input_speed: float = 15.0
@export var downhill_assist: float = 6.0
@export var air_gravity_multiplier: float = 3.0
@export var air_steer_multiplier: float = 0.4

var session_push_force: float = 25.0

var server_transform: Transform3D
var server_linear_velocity: Vector3 = Vector3.ZERO
var server_angular_velocity: Vector3 = Vector3.ZERO
var last_applied_jump_frame: int = -1
var last_received_frame: int = -1
var server_frame: int = 0
var correction_frames_remaining: int = 0
var pending_jumps: int = 0

var pending_pushes: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_priority = -10
	
	ground_cast.top_level = true
	shadow_ray.top_level = true
	contact_shadow.top_level = true
	
	set_multiplayer_authority(1)
	
	configure_player_force(HighLevelNetworkHandler.session_player_count)

@rpc("any_peer", "call_local", "reliable")
func request_jump() -> void:
	if not multiplayer.is_server():
		return
	
	if GameManager.game_state == GameManager.GameState.LOBBY:
		return
	
	# TODO: Validate the requesting player's eligibility.
	if not ground_cast.is_colliding():
		return
		
	apply_jump_impulse()


func apply_jump_impulse() -> void:
	apply_central_impulse(Vector3.UP * jump_force * mass)

func configure_player_force(player_count: int) -> void:
	var count = max(1, player_count)

	# Two players are the baseline.
	### 1 player 35.4N force
	### 2 player 25.0N per player, combined 50.0N
	### 3 player 20.4N per player, combined 61.2N
	### 4 player 17.07 per player, combined 70.7N
	session_push_force = push_force * sqrt(2.0 / float(count))

@rpc("any_peer", "call_local", "unreliable")
func request_push(push_direction: Vector3, contact_offset: Vector3) -> void:
	if not multiplayer.is_server():
		return
		
	var sender := multiplayer.get_remote_sender_id()
	
	pending_pushes[sender] = {"direction": push_direction, "offset": contact_offset}
		
	#apply_push(push_direction, contact_offset)

func queue_push(peer_id: int, direction: Vector3, contact_offset: Vector3) -> void:
	if not multiplayer.is_server():
		return

	pending_pushes[peer_id] = {"direction": direction, "offset": contact_offset}

func process_pending_pushes() -> void:
	for peer_id in pending_pushes:
		var push = pending_pushes[peer_id]
		apply_push(push["direction"], push["offset"])

	pending_pushes.clear()

func apply_push(push_direction: Vector3, contact_offset: Vector3) -> void:
	# TODO: Validate the sender, direction, contact
	# position, and whether their gnome is touching.
	if push_direction.length_squared() < 0.01:
		return

	match GameManager.game_state:
		GameManager.GameState.LOBBY:
			var current_push_force := push_direction.normalized() * lobby_push_force
			apply_force(current_push_force, contact_offset)
			#apply_central_force(current_push_force)
		GameManager.GameState.PLAYING:
			var direction := push_direction.normalized()
			
			var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
			
			if horizontal_velocity.length() >= max_input_speed:
				var velocity_direction := horizontal_velocity.normalized()
				
				var forward_component := direction.dot(velocity_direction)
				
				if forward_component > 0.0:
					direction -= velocity_direction * forward_component

			#var current_push_force := direction * push_force
			var current_push_force := direction * session_push_force

			if not ground_cast.is_colliding():
				apply_force(current_push_force * air_steer_multiplier)
				return
			
			apply_force(current_push_force, contact_offset)
	

@rpc("authority", "call_remote", "unreliable")
func receive_ball_state(frame: int, ball_transform: Transform3D, ball_linear_velocity: Vector3, ball_angular_velocity: Vector3) -> void:
	if multiplayer.is_server():
		return

	# Ignore packets that arrive out of order
	if frame <= last_received_frame:
		return

	last_received_frame = frame

	server_transform = ball_transform
	server_linear_velocity = ball_linear_velocity
	server_angular_velocity = ball_angular_velocity

	correction_frames_remaining = 2

func _process(_delta: float) -> void:
	pass

func apply_gravity_assist() -> void:
	if GameManager.game_state == GameManager.GameState.LOBBY:
		return
	
	if ground_cast.is_colliding():

		var normal := ground_cast.get_collision_normal(0)
		
		if normal.y < 0.5:
			if GameManager.game_state != GameManager.GameState.LOBBY:
				print("ball contact is not the floor")
				return

		# Gravity projected onto the slope.
		var gravity := Vector3.DOWN * 9.8
		var downhill := gravity.slide(normal)
		
		if downhill.length_squared() < 0.001:
			return

		# Check whether the ball is moving downhill.
		var downhill_direction := downhill.normalized()
		var downhill_speed := linear_velocity.dot(downhill_direction)
		
		if downhill_speed > 0.0:
			apply_central_force(downhill * downhill_assist * mass)
	else:
		var gravity := Vector3.DOWN * 9.8
		var extra_gravity := gravity * (air_gravity_multiplier - 1.0)
		
		apply_central_force(extra_gravity * mass)

func get_ball_speed() -> float:
	return linear_velocity.length()

func update_contact_shadow() -> void:
	if not shadow_ray.is_colliding():
		contact_shadow.visible = false
		return
	
	contact_shadow.visible = true
	
	var point := shadow_ray.get_collision_point()
	var normal := shadow_ray.get_collision_normal()
	
	contact_shadow.global_position = point + normal * 0.02
	contact_shadow.global_basis = Basis(Quaternion(Vector3.UP, normal))

func _physics_process(_delta: float) -> void:
	ground_cast.global_position = global_position
	ground_cast.global_rotation = Vector3.ZERO
	
	shadow_ray.global_position = global_position
	shadow_ray.global_rotation = Vector3.ZERO

	apply_gravity_assist()
	
	if multiplayer.is_server():
		process_pending_pushes()
		
		server_frame += 1
		
		receive_ball_state.rpc(server_frame, global_transform, linear_velocity, angular_velocity)
	else:
		if correction_frames_remaining > 0:
			linear_velocity = linear_velocity.lerp(server_linear_velocity, 0.85)
			angular_velocity = angular_velocity.lerp(server_angular_velocity, 0.85)
			
			var position_error := global_position.distance_to(server_transform.origin)
			if position_error > 2.0:
				global_transform = server_transform
			else:
				global_transform = global_transform.interpolate_with(server_transform, 0.02)
						
			correction_frames_remaining -= 1
	
	update_contact_shadow()
