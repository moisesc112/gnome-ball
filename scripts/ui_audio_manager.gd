extends Node

@onready var click_audio: AudioStreamPlayer = $ClickAudio
@onready var hover_audio: AudioStreamPlayer = $HoverAudio
@onready var confirm_audio: AudioStreamPlayer = $ConfirmAudio

func play_click() -> void:
	click_audio.play()

func play_hover() -> void:
	hover_audio.play()

func play_confirm() -> void:
	confirm_audio.play()
