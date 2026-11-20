extends Area3D

enum WindMode {
	CONSTANT,
	INTERMITTENT,
	REVERSING,
	INTERMITTENT_REVERSING
}

@export var wind_mode: WindMode = WindMode.CONSTANT

@export var active_duration: float = 3.0
@export var inactive_duration: float = 1.0

@onready var wind_particles: GPUParticles3D = $WindParticles
@onready var leaf_particles: GPUParticles3D = $LeafParticles

@export var wind_strength: float = 0.5

var affected_bodies: Array[RigidBody3D] = []

var elapsed_time: float = 0.0
var wind_active: bool = true
var wind_sign: float = 1.0

func _ready() -> void:
	update_particles()

func _physics_process(delta: float) -> void:
	update_wind_state(delta)
	
	if not multiplayer.is_server():
		return

	if not wind_active:
		return

	var wind_direction := -global_basis.z * wind_sign

	for body in affected_bodies:
		if is_instance_valid(body):
			body.apply_central_force(wind_direction * wind_strength * body.mass)


func update_wind_state(delta: float) -> void:
	if wind_mode == WindMode.CONSTANT:
		return

	elapsed_time += delta

	var duration := active_duration if wind_active else inactive_duration
	duration = maxf(duration, 0.01)

	if elapsed_time < duration:
		return

	elapsed_time -= duration

	match wind_mode:
		WindMode.INTERMITTENT:
			wind_active = not wind_active

		WindMode.REVERSING:
			wind_sign *= -1.0

		WindMode.INTERMITTENT_REVERSING:
			if wind_active:
				wind_active = false
			else:
				wind_active = true
				wind_sign *= -1.0

	update_particles()

func update_particles() -> void:
	wind_particles.emitting = wind_active
	wind_particles.rotation.y = 0.0 if wind_sign > 0.0 else PI
	
	leaf_particles.emitting = wind_active
	leaf_particles.rotation.y = 0.0 if wind_sign > 0.0 else PI


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	
	if body is RigidBody3D:
		if not affected_bodies.has(body):
			print("player entered wind zone")
			affected_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	
	if body is RigidBody3D:
		print("player left wind zone")
		affected_bodies.erase(body)
