extends Node3D

#@onready var gnome_animation_player: AnimationPlayer = $Gnome_smooth/AnimationPlayer
@onready var gnome_animation_player: AnimationPlayer = $gnome_low_poly_smooth/AnimationPlayer
@onready var fairy_animation_player: AnimationPlayer = $fairy_king_smooth/AnimationPlayer
@onready var player_ball: Node3D = $player_ball_smooth

@export var rotation_speed: float = 1.2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#gnome_animation_player.play("WalkAction")
	gnome_animation_player.play("Gnome_Rig|Skip", -1, 1.5)
	fairy_animation_player.play("Idle")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	player_ball.rotate_x(rotation_speed * delta)
	player_ball.rotate_z(rotation_speed * delta)
