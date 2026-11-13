extends CanvasLayer

@export var ball: RigidBody3D
@onready var speed_label: Label = $SpeedLabel
@onready var fps_label: Label = $FPSLabel
@onready var collision_button: Button = $CollisionButton

@onready var pause_menu: Control = $PauseMenu
@onready var victory_screen: Control = $VictoryScreen
@onready var finish_time_label: Label = $VictoryScreen/CenterContainer/VBoxContainer/FinishTimeLabel
@onready var return_lobby_button: Button = $VictoryScreen/CenterContainer/VBoxContainer/ReturnToLobbyButton
@onready var return_menu_button: Button = $VictoryScreen/CenterContainer/VBoxContainer/ReturnToMenuButton

func _ready() -> void:
	victory_screen.hide()
	
	if HighLevelNetworkHandler.is_solo:
		return_lobby_button.hide()
	
	GameManager.game_finished.connect(_on_game_finished)

func _process(_delta: float) -> void:
	if ball == null:
		return

	speed_label.text = "%.1f mph" % (ball.get_ball_speed() * 2.23694)
	fps_label.text ="%.1f FPS" % Engine.get_frames_per_second()

func _on_collision_button_toggled(toggled_on: bool) -> void:
	for child in get_tree().current_scene.get_children():
		if child is CharacterBody3D:
			child.set_gnome_collisions(toggled_on)

func format_time(seconds: float) -> String:
	var total_seconds := int(seconds)
	var hours := int(total_seconds / 3600.0)
	var minutes := int(total_seconds / 60.0) % 60
	var remaining_seconds := total_seconds % 60

	return "%d:%02d:%02d" % [hours, minutes, remaining_seconds]

func _on_game_finished(final_time: float) -> void:
	finish_time_label.text = format_time(final_time)
	victory_screen.show()
	


func _on_return_to_lobby_button_pressed() -> void:
	HighLevelNetworkHandler.return_to_lobby()


func _on_return_to_menu_button_pressed() -> void:
	HighLevelNetworkHandler.leave_session()
