extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		body.global_position = Vector3(0.0, 0.684, 25.68)
		body.linear_velocity = Vector3(0.0, 0.0, 0.0)
