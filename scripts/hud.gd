extends CanvasLayer

@export var ball: RigidBody3D
@onready var speed_label: Label = $SpeedLabel
@onready var fps_label: Label = $FPSLabel
@onready var force_label: Label = $ForceLabel
@onready var player_count_label : Label = $PlayerCountLabel
@onready var collision_button: Button = $CollisionButton

@onready var pause_menu: Control = $PauseMenu
@onready var victory_screen: Control = $VictoryScreen
@onready var finish_time_label: Label = $VictoryScreen/CenterContainer/VBoxContainer/FinishTimeLabel
@onready var return_lobby_button: Button = $VictoryScreen/CenterContainer/VBoxContainer/ReturnToLobbyButton
@onready var return_menu_button: Button = $VictoryScreen/CenterContainer/VBoxContainer/ReturnToMenuButton
@onready var selection_wheel: Control = $SelectionWheel


func _ready() -> void:
	victory_screen.hide()
	selection_wheel.hide()
	
	if HighLevelNetworkHandler.is_solo:
		return_lobby_button.hide()
	
	GameManager.game_finished.connect(_on_game_finished)
	
	player_count_label.text = "# Players: %d" % HighLevelNetworkHandler.session_player_count
	force_label.text = "Push Force: %.1f N" % (25.0 * sqrt(2.0 / float(HighLevelNetworkHandler.session_player_count)))

func _process(_delta: float) -> void:
	if ball == null:
		return
	
	speed_label.text = "%.1f mph" % (ball.get_ball_speed() * 2.23694)
	fps_label.text ="%.1f FPS" % Engine.get_frames_per_second()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return

	if event.is_action_pressed("Emote_Wheel"):
		selection_wheel.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	elif event.is_action_released("Emote_Wheel"):
		selection_wheel.hide()
		selection_wheel.reset_selection()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 

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
