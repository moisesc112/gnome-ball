extends CanvasLayer

@export var ball: RigidBody3D
@onready var speed_label: Label = $SpeedLabel

func _process(_delta: float) -> void:
	if ball == null:
		return

	speed_label.text = "%.1f mph" % (ball.get_ball_speed() * 2.23694)
