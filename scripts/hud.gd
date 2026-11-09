extends CanvasLayer

@export var ball: RigidBody3D
@onready var speed_label: Label = $SpeedLabel
@onready var fps_label: Label = $FPSLabel

func _process(_delta: float) -> void:
	if ball == null:
		return

	speed_label.text = "%.1f mph" % (ball.get_ball_speed() * 2.23694)
	fps_label.text ="%.1f FPS" % Engine.get_frames_per_second()
	
