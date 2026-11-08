extends RigidBody3D

@onready var ground_ray: RayCast3D = $RayCast3D
@onready var ground_cast: ShapeCast3D = $GroundCast
@onready var ball_visual: Node3D = $BallVisual
@export var visual_follow_speed: float = 15.0
@export var correction_speed: float = 8.0

@export var max_input_speed: float = 15.0
@export var downhill_assist: float = 4.0
@export var air_gravity_multiplier: float = 2.5

@export var snapshot_interval: float = 0.033
@export var interpolation_delay: float = 0.15

var replicated_velocity: Vector3 = Vector3.ZERO

var snapshot_timer: float = 0.0
var server_time: float = 0.0
var snapshots: Array[Dictionary] = []
var render_time: float = 0.0
var timeline_initialized: bool = false
var buffer_underruns: int = 0

var previous_snapshot: Transform3D
var latest_snapshot: Transform3D
var interpolation_elapsed: float = 0.0
var last_received_transform: Transform3D

var start_transform: Transform3D
var target_transform: Transform3D
var last_sync_time: int = 0
var smoothed_sync_delta: float = 33.0
var has_snapshot: bool = false

var test_position: Vector3
var test_initialized := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_priority = -10
	
	ground_cast.top_level = true
	
	ball_visual.top_level = true
	ball_visual.global_transform = global_transform
	
	start_transform = global_transform
	target_transform = global_transform

	set_multiplayer_authority(1)
	
	if not multiplayer.is_server():
		freeze = true

@rpc("any_peer", "call_local", "reliable")
func request_jump() -> void:
	if not multiplayer.is_server():
		return
	
	if GameManager.game_state == GameManager.GameState.LOBBY:
		return
	
	# TODO: Validate the requesting player's eligibility.
	if not ground_cast.is_colliding():
		return

	apply_central_impulse(Vector3.UP * 5.0)


@rpc("any_peer", "call_local", "unreliable")
func request_push(
	push_direction: Vector3,
	contact_offset: Vector3
) -> void:
	if not multiplayer.is_server():
		return
	
	# TODO: Validate the sender, direction, contact
	# position, and whether their gnome is touching.
	if push_direction.length_squared() < 0.01:
		return

	match GameManager.game_state:
		GameManager.GameState.LOBBY:
			var push_force := push_direction.normalized() * 1.5
			apply_force(push_force, contact_offset)
		GameManager.GameState.PLAYING:
			if not ground_cast.is_colliding():
				return
			
			var direction := push_direction.normalized()
			
			var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
			
			if horizontal_velocity.length() >= max_input_speed:
				var velocity_direction := horizontal_velocity.normalized()
				
				var forward_component := direction.dot(velocity_direction)
				
				if forward_component > 0.0:
					direction -= velocity_direction * forward_component
			
			var push_force := direction * 25.0
			apply_force(push_force, contact_offset)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_ball_snapshot(ball_transform: Transform3D, ball_velocity: Vector3) -> void:
	if multiplayer.is_server():
		return

	replicated_velocity = ball_velocity

	var now := Time.get_ticks_msec()

	if has_snapshot:
		var current_delta := now - last_sync_time

		if current_delta > 0 and current_delta < 1000:
			smoothed_sync_delta = lerpf(
				smoothed_sync_delta,
				float(current_delta),
				0.2
			)
	else:
		has_snapshot = true
		ball_visual.global_transform = ball_transform

	last_sync_time = now

	start_transform = ball_visual.global_transform
	target_transform = ball_transform


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		ball_visual.global_transform = global_transform
		return

	if not has_snapshot:
		return

	var elapsed := Time.get_ticks_msec() - last_sync_time

	var alpha := clampf(
		float(elapsed) / maxf(smoothed_sync_delta, 1.0),
		0.0,
		1.2
	)

	ball_visual.global_transform = start_transform.interpolate_with(
		target_transform,
		alpha
	)

func apply_gravity_assist() -> void:
	if ground_cast.is_colliding():

		var normal := ground_cast.get_collision_normal(0)
		
		if normal.y < 0.5:
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
	if multiplayer.is_server():
		return linear_velocity.length()
	
	return replicated_velocity.length()

func _physics_process(delta: float) -> void:
	ground_cast.global_position = global_position
	ground_cast.global_rotation = Vector3.ZERO

	if not multiplayer.is_server():
		return
	
	apply_gravity_assist()

	snapshot_timer += delta

	if snapshot_timer >= snapshot_interval:
		snapshot_timer -= snapshot_interval

		receive_ball_snapshot.rpc(global_transform, linear_velocity)
