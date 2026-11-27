@tool
extends Node3D

@export var terrain: Terrain3D

@export_group("Painting Area")
@export var area_size := Vector2(512, 512)
@export var village_elevation: float = 0.0

@export_group("Texture IDs")
@export var grass_id: int = 0
@export var rock_id: int = 1
@export var dark_rock_id: int = 2
@export var snow_id: int = 3

@export_group("Elevation")
@export var rock_start: float = 60.0
@export var rock_full: float = 90.0
@export var snow_start: float = 100.0
@export var snow_full: float = 150.0

@export_group("Slope")
@export var snow_flat_angle: float = 25.0
@export var snow_steep_angle: float = 55.0
@export var dark_rock_angle: float = 50.0

@export_group("Terrain Curvature")
@export var curvature_radius: float = 4.0
@export var ridge_strength: float = 0.5

@export_group("Noise")
@export var noise_frequency: float = 0.025
@export var snow_line_variation: float = 20.0
@export var noise_seed: int = 12345

@export_tool_button("Paint Mountain")
var paint_button: Callable = paint_mountain


@export var slope_sample_radius: float = 5.0

func get_smoothed_normal(pos: Vector3) -> Vector3:
	var r := slope_sample_radius

	var left := terrain.data.get_height(
		pos - Vector3(r, 0, 0)
	)
	var right := terrain.data.get_height(
		pos + Vector3(r, 0, 0)
	)
	var back := terrain.data.get_height(
		pos - Vector3(0, 0, r)
	)
	var front := terrain.data.get_height(
		pos + Vector3(0, 0, r)
	)

	if not (
		is_finite(left) and is_finite(right)
		and is_finite(back) and is_finite(front)
	):
		return terrain.data.get_normal(pos)

	return Vector3(
		left - right,
		2.0 * r,
		back - front
	).normalized()

func paint_mountain() -> void:
	if not Engine.is_editor_hint():
		return

	if terrain == null or terrain.data == null:
		push_warning("Assign Terrain3D first.")
		return

	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = 3

	var spacing: float = terrain.vertex_spacing
	var half_size := area_size * 0.5

	var start_x := int(ceil(
		(global_position.x - half_size.x) / spacing
	))
	var end_x := int(floor(
		(global_position.x + half_size.x) / spacing
	))

	var start_z := int(ceil(
		(global_position.z - half_size.y) / spacing
	))
	var end_z := int(floor(
		(global_position.z + half_size.y) / spacing
	))

	var painted := 0

	for ix in range(start_x, end_x + 1):
		for iz in range(start_z, end_z + 1):

			var pos := Vector3(
				ix * spacing,
				0.0,
				iz * spacing
			)

			var height := terrain.data.get_height(pos)

			if not is_finite(height):
				continue

			if terrain.data.get_control_hole(pos):
				continue

			pos.y = height

			var elevation := height - village_elevation
			var normal := terrain.data.get_normal(pos)

			if not normal.is_finite():
				continue

			if normal.length_squared() < 0.001:
				continue

			var slope := rad_to_deg(
				normal.normalized().angle_to(Vector3.UP)
			)

			var variation := noise.get_noise_2d(
				pos.x, pos.z
			)

			# Elevation-based rock coverage.
			var rock_amount := smoothstep(
				rock_start,
				rock_full,
				elevation
			)

			# Expose rock on steep slopes.
			rock_amount = maxf(
				rock_amount,
				smoothstep(30.0, 50.0, slope)
			)

			# Irregular snow line.
			var adjusted_elevation := (
				elevation
				+ variation * snow_line_variation
			)

			var snow_elevation := smoothstep(
				snow_start,
				snow_full,
				adjusted_elevation
			)

			# Snow accumulates on flatter surfaces.
			var snow_slope := 1.0 - smoothstep(
				snow_flat_angle,
				snow_steep_angle,
				slope
			)

			# Expose protruding ridges.
			var curvature := get_curvature(pos, height)

			var ridge_exposure := clampf(
				curvature * ridge_strength,
				0.0,
				1.0
			)

			var snow_amount := (
				snow_elevation
				* snow_slope
				* (1.0 - ridge_exposure)
			)

			# Determine exposed rock color.
			var dark_amount := smoothstep(
				dark_rock_angle - 10.0,
				dark_rock_angle + 10.0,
				slope + variation * 8.0
			)

			var selected_rock := rock_id

			if dark_amount > 0.5:
				selected_rock = dark_rock_id

			var base_id := grass_id
			var overlay_id := selected_rock
			var blend := rock_amount

			if snow_amount > 0.01:
				base_id = selected_rock
				overlay_id = snow_id
				blend = snow_amount
			elif rock_amount >= 0.99:
				base_id = rock_id
				overlay_id = dark_rock_id
				blend = dark_amount

			# Write terrain texture information.
			terrain.data.set_control_base_id(
				pos, base_id
			)

			terrain.data.set_control_overlay_id(
				pos, overlay_id
			)

			terrain.data.set_control_blend(
				pos, blend
			)

			terrain.data.set_control_auto(
				pos, false
			)

			painted += 1

	terrain.data.update_maps(
		Terrain3DRegion.TYPE_CONTROL
	)

	print("Painted terrain samples: ", painted)


func get_curvature(
	pos: Vector3,
	center_height: float
) -> float:

	var r := maxf(
		curvature_radius,
		terrain.vertex_spacing
	)

	var offsets := [
		Vector3(r, 0.0, 0.0),
		Vector3(-r, 0.0, 0.0),
		Vector3(0.0, 0.0, r),
		Vector3(0.0, 0.0, -r)
	]

	var total := 0.0

	for offset: Vector3 in offsets:
		var h := terrain.data.get_height(pos + offset)

		if not is_finite(h):
			return 0.0

		total += h

	var neighbor_average := total / 4.0

	return center_height - neighbor_average
