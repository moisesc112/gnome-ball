@tool
extends Node3D

@export var terrain: Terrain3D
@export var tree_mesh_id: int = 0

@export_group("Generation Area")
@export var area_size: Vector2 = Vector2(1024, 1024)
@export var village_center: Vector3 = Vector3.ZERO
@export var village_clear_radius: float = 100.0
@export var forest_transition_distance: float = 50.0

@export_group("Elevation")
@export var min_elevation: float = -5.0
@export var dense_forest_elevation: float = 40.0
@export var tree_line_elevation: float = 140.0
@export var max_slope_degrees: float = 40.0

@export_group("Density")
@export_range(1.0, 50.0) var tree_spacing: float = 8.0
@export_range(0.0, 1.0) var density: float = 0.85
@export var noise_frequency: float = 0.015
@export var forest_seed: int = 12345

@export_group("Tree Appearance")
@export var min_tree_scale: float = 0.7
@export var max_tree_scale: float = 1.3
@export var alpine_tree_scale: float = 0.4

@export_tool_button("Generate Forest")
var generate_button = generate_forest

@export_tool_button("Clear Forest")
var clear_button = clear_forest


func generate_forest() -> void:
	if not Engine.is_editor_hint():
		return

	if terrain == null or terrain.data == null \
			or terrain.instancer == null:
		push_warning("Assign a valid Terrain3D node.")
		return

	if tree_line_elevation <= dense_forest_elevation:
		push_warning("Tree line must be above dense forest.")
		return

	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed

	var noise := FastNoiseLite.new()
	noise.seed = forest_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = 3

	var transforms: Array[Transform3D] = []

	var half_size := area_size * 0.5
	var spacing := maxf(tree_spacing, 1.0)

	var columns := int(ceil(area_size.x / spacing))
	var rows := int(ceil(area_size.y / spacing))

	for ix in range(columns):
		for iz in range(rows):

			# Randomize placement within each grid cell.
			var x := (
				global_position.x - half_size.x
				+ (ix + rng.randf()) * spacing
			)

			var z := (
				global_position.z - half_size.y
				+ (iz + rng.randf()) * spacing
			)

			if x >= global_position.x + half_size.x \
					or z >= global_position.z + half_size.y:
				continue

			var pos := Vector3(x, 0.0, z)

			# Keep the village clear.
			var distance_from_village := Vector2(
				x - village_center.x,
				z - village_center.z
			).length()

			if distance_from_village < village_clear_radius:
				continue

			# Read terrain height.
			var height := terrain.data.get_height(pos)

			# Skip missing terrain and holes.
			if not is_finite(height):
				continue

			pos.y = height

			var elevation := height - village_center.y

			if elevation < min_elevation:
				continue

			if elevation >= tree_line_elevation:
				continue

			# Reject steep slopes.
			var normal := terrain.data.get_normal(pos)

			if not normal.is_finite():
				continue

			if normal.length_squared() < 0.001:
				continue

			var slope := rad_to_deg(
				normal.normalized().angle_to(Vector3.UP)
			)

			if slope > max_slope_degrees:
				continue

			# Reduce density near the mountain tree line.
			var elevation_factor := 1.0 - smoothstep(
				dense_forest_elevation,
				tree_line_elevation,
				elevation
			)

			# Gradual transition from village to forest.
			var distance_factor := 1.0

			if forest_transition_distance > 0.0:
				distance_factor = smoothstep(
					village_clear_radius,
					village_clear_radius
						+ forest_transition_distance,
					distance_from_village
				)

			# Create irregular forest clusters.
			var noise_value := noise.get_noise_2d(x, z)

			var noise_factor := smoothstep(
				-0.45, 0.35, noise_value
			)

			var spawn_chance := (
				density
				* elevation_factor
				* distance_factor
				* noise_factor
			)

			if rng.randf() > spawn_chance:
				continue

			# Trees get smaller approaching the tree line.
			var elevation_scale := lerpf(
				alpine_tree_scale,
				1.0,
				elevation_factor
			)

			var tree_scale := rng.randf_range(
				min_tree_scale,
				max_tree_scale
			) * elevation_scale

			# Random rotation, keeping trees upright.
			var yaw := rng.randf_range(0.0, TAU)

			var basis := Basis(Vector3.UP, yaw)
			basis = basis.scaled(Vector3.ONE * tree_scale)

			transforms.append(Transform3D(basis, pos))

	# Replace the previous generated forest.
	terrain.instancer.clear_by_mesh(tree_mesh_id)

	if not transforms.is_empty():
		terrain.instancer.add_transforms(
			tree_mesh_id, transforms
		)

	print("Generated ", transforms.size(), " trees.")


func clear_forest() -> void:
	if not Engine.is_editor_hint():
		return

	if terrain == null or terrain.instancer == null:
		return

	terrain.instancer.clear_by_mesh(tree_mesh_id)
	print("Forest cleared.")
