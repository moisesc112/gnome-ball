extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("Idle")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
		
	if not body is RigidBody3D:
		return
		
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return
	
	GameManager.finish_game()
