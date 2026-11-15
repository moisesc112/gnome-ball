extends OmniLight3D

@export var base_energy: float = 1.0
@export var pulse_speed: float = 2.0
@export var pulse_amount: float = 0.35

func _process(_delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * pulse_speed)

	light_energy = base_energy * lerp(1.0 - pulse_amount, 1.0, pulse)
