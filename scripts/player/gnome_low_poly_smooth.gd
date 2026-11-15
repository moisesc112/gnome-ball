extends Node3D

@export var footstep_audio: AudioStreamPlayer3D
@export var footstep_sounds: Array[AudioStream]

func play_footstep() -> void:
	if GameManager.game_state != GameManager.GameState.PLAYING or GameManager.game_state != GameManager.GameState.LOBBY:
		return

	if footstep_sounds.is_empty():
		return

	footstep_audio.stream = footstep_sounds.pick_random()
	footstep_audio.pitch_scale = randf_range(1.1, 1.25)
	footstep_audio.volume_db = -10.0
	footstep_audio.play()
