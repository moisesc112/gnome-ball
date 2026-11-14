extends Control

@export var bkg_color: Color
@export var line_color: Color
@export var highlight_color: Color

@export var outer_radius: int = 256
@export var inner_radius: int = 64
@export var line_width: int = 4

@export var options: Array[String] = []

var selection: int = 0

func reset_selection() -> void:
	selection = 0
	queue_redraw()

func get_selected_emote() -> String:
	if selection == 0:
		return ""
		
	if selection >= options.size():
		return ""
		
	return options[selection]

func _draw() -> void:
	if options.size() < 2:
		return

	var segment_count = options.size() - 1
	var half_gap = line_width / 2.0
	var points_per_arc = 32

	for i in range(segment_count):
		var start_angle = TAU * i / segment_count
		var end_angle = TAU * (i + 1) / segment_count

		var points = PackedVector2Array()

		# Outer arc
		for j in range(points_per_arc + 1):
			var t = float(j) / points_per_arc
			var angle = lerp(start_angle, end_angle, t)

			var offset = asin(half_gap / outer_radius)
			var adjusted_angle = clampf(angle, start_angle + offset, end_angle - offset)

			points.append(outer_radius * Vector2.from_angle(-adjusted_angle))

		# Inner arc
		for j in range(points_per_arc, -1, -1):
			var t = float(j) / points_per_arc
			var angle = lerp(start_angle, end_angle, t)

			var offset = asin(half_gap / inner_radius)
			var adjusted_angle = clampf(angle, start_angle + offset, end_angle - offset)

			points.append(inner_radius * Vector2.from_angle(-adjusted_angle))
		
		var color = bkg_color
		
		if selection == i + 1:
			color = highlight_color

		draw_colored_polygon(points, color)


func _process(_delta: float) -> void:
	if not visible or options.is_empty():
		return
	
	var mouse_pos = get_local_mouse_position()
	var mouse_radius = mouse_pos.length()
	
	var new_selection: int = 0
	
	if mouse_radius < inner_radius:
		new_selection = 0
	else:
		var mouse_rads = fposmod(mouse_pos.angle() * -1, TAU)
		new_selection = ceil((mouse_rads / TAU) * (len(options) - 1))
		
	if new_selection != selection:
		selection = new_selection
		queue_redraw()
