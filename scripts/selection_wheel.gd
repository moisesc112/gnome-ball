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

func _draw() -> void:
	draw_circle(Vector2.ZERO, outer_radius, bkg_color)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 128, line_color, line_width, true)
	
	if len(options) >= 3:
		if selection == 0:
			draw_circle(Vector2.ZERO, inner_radius, highlight_color)
		
		for i in range(len(options) - 1):
			var rads = TAU * i / ((len(options) - 1))
			var point = Vector2.from_angle(rads)
			draw_line(point * inner_radius, point * outer_radius, line_color, line_width, true)
				
		for i in range(1, len(options)):
			var start_rads = (TAU * (i - 1)) / (len(options) - 1)
			var end_rads = (TAU * i) / (len(options) - 1)
			var mid_rads = (start_rads + end_rads) / 2.0 * -1
			var radius_mid = (inner_radius + outer_radius) / 2
			
			if selection == i:
				var points_per_arc = 32
				var points_inner = PackedVector2Array()
				var points_outer = PackedVector2Array()
				
				for j in range(points_per_arc + 1):
					var angle = start_rads + j * (end_rads - start_rads) / points_per_arc
					points_inner.append(inner_radius * Vector2.from_angle(TAU - angle))
					points_outer.append(outer_radius * Vector2.from_angle(TAU - angle))
					
				points_outer.reverse()
				draw_polygon(points_inner + points_outer, PackedColorArray([highlight_color]))

func _process(_delta: float) -> void:
	if not visible or options.is_empty():
		return
	
	var mouse_pos = get_local_mouse_position()
	var mouse_radius = mouse_pos.length()
	
	var new_selection: int
	
	if mouse_radius < inner_radius:
		selection = 0
	else:
		var mouse_rads = fposmod(mouse_pos.angle() * -1, TAU)
		new_selection = ceil((mouse_rads / TAU) * (len(options) - 1))
		
	if new_selection != selection:
		selection = new_selection
		queue_redraw()
