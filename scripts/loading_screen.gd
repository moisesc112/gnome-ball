extends CanvasLayer

@onready var content: Control = $Content

var fade_tween: Tween

#func _ready() -> void:
	#hide()

func show_loading() -> void:
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()

	content.modulate.a = 1.0
	show()

func fade_out() -> void:
	if not visible:
		return

	if fade_tween and fade_tween.is_running():
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(content, "modulate:a", 0.0, 0.4)

	await fade_tween.finished
	hide()
