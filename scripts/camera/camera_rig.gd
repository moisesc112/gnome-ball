extends Node3D

@export var player: RigidBody3D = null
@export var follow_speed: float = 8.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player == null:
		return
		
	global_position = global_position.lerp(player.global_position, follow_speed * delta)
