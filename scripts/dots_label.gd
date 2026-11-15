extends Label

@export var dot_interval: float = 0.4

var elapsed: float = 0.0
var dot_count: int = 0

func _process(delta: float) -> void:
	elapsed += delta

	if elapsed >= dot_interval:
		elapsed -= dot_interval
		dot_count = (dot_count + 1) % 4
		text = " .".repeat(dot_count)
