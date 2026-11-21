extends RigidBody3D

@onready var ground_cast: ShapeCast3D = $GroundCast
@onready var ball_visual: Node3D = $BallVisual
@onready var contact_shadow: MeshInstance3D = $ContactShadow
@onready var shadow_ray: RayCast3D = $ShadowRay

@export var jump_force: float = 7.0
@export var lobby_push_force: float = 1.5
@export var push_force: float = 25.0
### Initial testing done with max speed 15.0 m/s
@export var max_input_speed: float = 25.0
@export var downhill_assist: float = 6.0
@export var air_gravity_multiplier: float = 3.0
@export var air_steer_multiplier: float = 0.4

var is_anti_gravity: bool = false

@onready var rolling_audio: AudioStreamPlayer3D = $RollingAudio
@export var rolling_audio_grace_period: float = 0.5
@export var max_rolling_pitch_speed: float = 30.0

@onready var air_audio: AudioStreamPlayer3D = $AirAudio
@export var air_audio_delay: float = 0.3
var airborne_time: float = 0.0

@onready var surface_audio: AudioStreamPlayer3D = $SurfaceAudio
var grass_sound: AudioStream = preload("res://assets/audio/Ball/833458__darceyprodanovic__rustling-in-leaves.wav")
var wood_sound: AudioStream = preload("res://assets/audio/Ball/535369__nagwense__glass-ball-rolling-on-wood_trimmed.wav")

@onready var impact_audio: AudioStreamPlayer3D = $ImpactAudio
var was_grounded: bool = false
var previous_vertical_velocity: float = 0.0
@export var min_impact_speed: float = 0.75
@export var max_impact_speed: float = 10.0
var impact_suppression_time: float = 0.0

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
	
	surface_audio.stream = grass_sound
	rolling_audio.play()

func suppress_impact_audio(duration: float = 0.2) -> void:
	impact_suppression_time = maxf(impact_suppression_time, duration)

func update_impact_audio(delta: float) -> void:
	var grounded := ground_cast.is_colliding()

	if GameManager.game_state != GameManager.GameState.PLAYING:
		was_grounded = grounded
		previous_vertical_velocity = linear_velocity.y
		return
	
	impact_suppression_time = maxf(impact_suppression_time - delta, 0.0)
	
	if grounded and not was_grounded:
		var impact_speed := maxf(0.0, -previous_vertical_velocity)

		if impact_speed > 0.75 and impact_suppression_time <= 0.0:
			var impact_ratio := clampf((impact_speed - 0.75) / 10.0, 0.0, 1.0)

			impact_audio.volume_db = lerpf(-35.0, -15.0, impact_ratio)
			impact_audio.pitch_scale = randf_range(0.95, 1.05)
			impact_audio.play()

	was_grounded = grounded
	previous_vertical_velocity = linear_velocity.y

func update_ball_audio(delta: float) -> void:
	if GameManager.game_state != GameManager.GameState.PLAYING:
		airborne_time = 0.0
		rolling_audio.stop()
		air_audio.stop()
		surface_audio.stop()
		return

	if not rolling_audio.playing:
		rolling_audio.volume_db = 0.0
		rolling_audio.play()
	
	if not surface_audio.playing:
		surface_audio.volume_db = -60.0
		#surface_audio.play()
	
	if not air_audio.playing:
		air_audio.volume_db = -60.0
		air_audio.play()

	var grounded := ground_cast.is_colliding()

	if grounded:
		airborne_time = 0.0
	else:
		airborne_time += delta

	var horizontal_speed := Vector2(
		linear_velocity.x,
		linear_velocity.z
	).length()

	var total_speed := linear_velocity.length()

	var rolling_ratio := clampf(horizontal_speed / max_input_speed, 0.0, 1.0)
	var air_ratio := clampf(total_speed / max_input_speed, 0.0, 1.0)

	var rolling_target := -60.0
	var air_target := -60.0

	if airborne_time < rolling_audio_grace_period and horizontal_speed > 0.5:
		rolling_target = lerpf(-10.0, -3.0, rolling_ratio)

	if not grounded and airborne_time >= air_audio_delay and total_speed > 1.0:
		air_target = lerpf(-35.0, -12.0, air_ratio)

	var fade := clampf(delta * 8.0, 0.0, 1.0)

	rolling_audio.volume_db = lerpf(rolling_audio.volume_db, rolling_target, fade)

	air_audio.volume_db = lerpf(air_audio.volume_db, air_target, fade)
	
	var pitch_ratio := clampf(horizontal_speed / max_rolling_pitch_speed, 0.0, 1.0)
	
	rolling_audio.pitch_scale = lerpf(0.95, 1.25, pitch_ratio)
	air_audio.pitch_scale = lerpf(0.9, 1.15, air_ratio)
	
	surface_audio.volume_db = rolling_audio.volume_db - 10.0
	surface_audio.pitch_scale = rolling_audio.pitch_scale

func set_anti_gravity(enabled: bool) -> void:
	is_anti_gravity = enabled
	gravity_scale = -1.0 if enabled else 1.0
	
	if enabled:
		ground_cast.target_position.y = absf(ground_cast.target_position.y)
	else:
		ground_cast.target_position.y = -absf(ground_cast.target_position.y)

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
func receive_ball_state(frame: int, ball_transform: Transform3D, ball_linear_velocity: Vector3, ball_angular_velocity: Vector3, anti_gravity: bool) -> void:
	if multiplayer.is_server():
		return

	# Ignore packets that arrive out of order
	if frame <= last_received_frame:
		return

	last_received_frame = frame
	
	set_anti_gravity(anti_gravity)
	
	server_transform = ball_transform
	server_linear_velocity = ball_linear_velocity
	server_angular_velocity = ball_angular_velocity

	correction_frames_remaining = 2

func _process(_delta: float) -> void:
	pass

func apply_gravity_assist() -> void:
	if GameManager.game_state == GameManager.GameState.LOBBY:
		return
	
	var gravity_direction := Vector3.DOWN
	air_gravity_multiplier = 3.0
	air_steer_multiplier = 0.4
	
	if is_anti_gravity:
		gravity_direction = Vector3.UP
		air_gravity_multiplier = 1.0
		air_steer_multiplier = 1.0
		
	var gravity := gravity_direction * 9.8
	
	if ground_cast.is_colliding():
		print ("ball is on ground")
		var normal := ground_cast.get_collision_normal(0)
		
		if normal.dot(-gravity_direction) <= 0.0:
				print("ball contact is not the floor")
				return

		# Gravity projected onto the slope.
		var downhill := gravity.slide(normal)
		
		if downhill.length_squared() < 0.001:
			return

		# Check whether the ball is moving downhill.
		var downhill_direction := downhill.normalized()
		var downhill_speed := linear_velocity.dot(downhill_direction)
		
		if downhill_speed > 0.0:
			apply_central_force(downhill * downhill_assist * mass)
	else:
		print ("ball is not on ground")
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

func _physics_process(delta: float) -> void:
	ground_cast.global_position = global_position
	ground_cast.global_rotation = Vector3.ZERO
	
	shadow_ray.global_position = global_position
	shadow_ray.global_rotation = Vector3.ZERO

	apply_gravity_assist()
	
	if multiplayer.is_server():
		process_pending_pushes()
		
		server_frame += 1
		
		receive_ball_state.rpc(server_frame, global_transform, linear_velocity, angular_velocity, is_anti_gravity)
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
	update_ball_audio(delta)
	#update_impact_audio(delta)
