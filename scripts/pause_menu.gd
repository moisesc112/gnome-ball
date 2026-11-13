extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_finished.connect(_on_game_finished)
	hide()

func pause() -> void:
	GameManager.local_pause_menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if HighLevelNetworkHandler.is_solo:
		get_tree().paused = true
	
	show()
	animation_player.play("blur")

func resume() -> void:
	GameManager.local_pause_menu_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if HighLevelNetworkHandler.is_solo:
		get_tree().paused = false
	
	animation_player.play_backwards("blur")
	hide()

func close_pause_menu() -> void:
	if Input.is_action_just_pressed("Escape") and !GameManager.local_pause_menu_open:
		pause()
	elif Input.is_action_just_pressed("Escape") and GameManager.local_pause_menu_open:
		resume()

func _on_resume_button_pressed() -> void:
	resume()


func _on_settings_button_pressed() -> void:
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	GameManager.local_pause_menu_open = false
	GameManager.disconnect_reason = ""
	HighLevelNetworkHandler.leave_session()
	
func _process(_delta: float) -> void:
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return
	
	close_pause_menu()
	
func _on_game_finished(_final_time: float) -> void:
	if GameManager.local_pause_menu_open:
		resume()
