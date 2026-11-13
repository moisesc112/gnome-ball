extends CanvasLayer

@export var ball: RigidBody3D
@onready var speed_label: Label = $SpeedLabel
@onready var fps_label: Label = $FPSLabel
@onready var collision_button: Button = $CollisionButton

@onready var pause_menu: Control = $PauseMenu

func _process(_delta: float) -> void:
	if ball == null:
		return

	speed_label.text = "%.1f mph" % (ball.get_ball_speed() * 2.23694)
	fps_label.text ="%.1f FPS" % Engine.get_frames_per_second()

func _on_collision_button_toggled(toggled_on: bool) -> void:
	for child in get_tree().current_scene.get_children():
		if child is CharacterBody3D:
			child.set_gnome_collisions(toggled_on)
