@tool
extends CSGPolygon3D

@export var ramp_length: float = 4.0
@export var ramp_height: float = 2.15
@export var segments: int = 32
@export var thickness: float = 0.5

func _ready() -> void:
	generate_ramp()

func generate_ramp() -> void:
	var points := PackedVector2Array()

	for i in range(segments + 1):
		var t := float(i) / segments
		var x := t * ramp_length
		var y := ramp_height * t * t

		points.append(Vector2(x, y))

	points.append(Vector2(ramp_length, -thickness))
	points.append(Vector2(0.0, -thickness))

	polygon = points
