extends Node3D

#@onready var gnome_animation_player: AnimationPlayer = $Gnome_smooth/AnimationPlayer
@onready var gnome_animation_player: AnimationPlayer = $gnome_low_poly_smooth/AnimationPlayer
@onready var fairy_animation_player: AnimationPlayer = $fairy_king_smooth/AnimationPlayer
@onready var player_ball: Node3D = $player_ball_smooth2
@onready var gnomes: Array[Node3D] = [
	$Gnome1,
	$Gnome2,
	$Gnome3,
	$Gnome4
]

@export var rotation_speed: float = 1.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#gnome_animation_player.play("WalkAction")
	#gnome_animation_player.play("Gnome_Rig|Skip", -1, 1.5)
	for i in range(gnomes.size()):
		var anim_player: AnimationPlayer = gnomes[i].get_node("AnimationPlayer")

		anim_player.play("Gnome_Rig|Skip")
		anim_player.seek(fmod(i * 0.15, anim_player.current_animation_length), true)

	
	fairy_animation_player.play("Idle")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	player_ball.rotate_x(rotation_speed * delta)
	player_ball.rotate_z(rotation_speed * delta)
