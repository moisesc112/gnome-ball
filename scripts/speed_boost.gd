extends Node3D

@export var boost_strength: float = 10.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		var boost_direction := -global_basis.z.normalized()
		body.apply_central_impulse(boost_direction * boost_strength * body.mass)
