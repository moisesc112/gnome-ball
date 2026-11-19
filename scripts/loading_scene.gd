extends Node3D

@export var ball_rotation_speed: float = 1.5

@onready var ball_pivot: Node3D = $player_ball_smooth
@onready var gnomes: Array[Node3D] = [
	$gnome1_v8,
	$gnome2_v8,
	$gnome3_v8,
	$gnome4_v8
]

func _ready() -> void:
	for i in range(gnomes.size()):
		var anim_player: AnimationPlayer = gnomes[i].get_node("AnimationPlayer")

		anim_player.play("Gnome_Rig|Skip")
		anim_player.seek(fmod(i * 0.15, anim_player.current_animation_length), true)

func _process(delta: float) -> void:
	ball_pivot.rotate_x(ball_rotation_speed * delta)
