@tool
extends Node3D

@export var terrain: Terrain3D

@export_group("Mesh IDs")
@export var pine_1_id: int = 0
@export var pine_2_id: int = 1
@export var pine_3_id: int = 2

@export var grass_low_1_id: int = 3
@export var grass_low_2_id: int = 4
@export var grass_high_1_id: int = 5
@export var grass_high_2_id: int = 6

@export_group("Generation Area")
@export var area_size: Vector2 = Vector2(1024, 1024)
@export var village_center: Vector3 = Vector3.ZERO
@export var village_clear_radius: float = 100.0
@export var forest_transition_distance: float = 50.0

@export_group("Tree Elevation")
@export var min_elevation: float = -5.0
@export var dense_forest_elevation: float = 40.0
@export var tree_line_elevation: float = 140.0
@export var max_slope_degrees: float = 40.0

@export_group("Tree Density")
@export_range(1.0, 50.0) var tree_spacing: float = 8.0
@export_range(0.0, 1.0) var density: float = 0.85
@export var noise_frequency: float = 0.015
@export var forest_seed: int = 12345

@export_group("Tree Appearance")
@export var min_tree_scale: float = 0.7
@export var max_tree_scale: float = 1.3
@export var alpine_tree_scale: float = 0.4

@export_group("Grass Area")
@export var grass_area_size: Vector2 = Vector2(400, 400)
@export var grass_clear_radius: float = 0.0

@export_group("Grass Elevation")
@export var grass_min_elevation: float = -5.0
@export var grass_fade_elevation: float = 35.0
@export var grass_max_elevation: float = 70.0
@export var grass_max_slope: float = 30.0

@export_group("Grass Density")
@export_range(0.25, 10.0) var grass_spacing: float = 2.0
@export_range(0.0, 1.0) var grass_density: float = 0.85
@export var grass_noise_frequency: float = 0.04
@export var tall_grass_noise_frequency: float = 0.06
@export_range(0.0, 1.0) var tall_grass_chance: float = 0.35

@export_group("Grass Appearance")
@export var min_grass_scale: float = 0.7
@export var max_grass_scale: float = 1.4

@export_tool_button("Generate All")
var generate_button = generate_all

@export_tool_button("Generate Trees")
var tree_button = generate_forest

@export_tool_button("Generate Grass")
var grass_button = generate_grass

@export_tool_button("Clear Trees")
var clear_tree_button = clear_forest

@export_tool_button("Clear Grass")
var clear_grass_button = clear_grass


func is_terrain_valid() -> bool:
	return (
		Engine.is_editor_hint()
		and terrain != null
		and terrain.data != null
		and terrain.instancer != null
	)


func create_noise(
	seed_value: int,
	frequency: float
) -> FastNoiseLite:

	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 3

	return noise


func generate_all() -> void:
	generate_forest()
	generate_grass()


func generate_forest() -> void:
	if not is_terrain_valid():
		return

	if tree_line_elevation <= dense_forest_elevation:
		push_warning("Invalid tree elevation settings.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed

	var noise := create_noise(
		forest_seed,
		noise_frequency
	)

	var pine_1: Array[Transform3D] = []
	var pine_2: Array[Transform3D] = []
	var pine_3: Array[Transform3D] = []

	var half_size := area_size * 0.5
	var spacing := maxf(tree_spacing, 1.0)

	var columns := int(ceil(area_size.x / spacing))
	var rows := int(ceil(area_size.y / spacing))

	for ix in range(columns):
		for iz in range(rows):

			var x := global_position.x - half_size.x \
				+ (ix + rng.randf()) * spacing

			var z := global_position.z - half_size.y \
				+ (iz + rng.randf()) * spacing

			if x >= global_position.x + half_size.x \
					or z >= global_position.z + half_size.y:
				continue

			var pos := Vector3(x, 0.0, z)

			var distance_from_village := Vector2(
				x - village_center.x,
				z - village_center.z
			).length()

			if distance_from_village < village_clear_radius:
				continue

			var height := terrain.data.get_height(pos)

			if not is_finite(height):
				continue

			pos.y = height

			var elevation := height - village_center.y

			if elevation < min_elevation \
					or elevation >= tree_line_elevation:
				continue

			var normal := terrain.data.get_normal(pos)

			if not normal.is_finite() \
					or normal.length_squared() < 0.001:
				continue

			var slope := rad_to_deg(
				normal.normalized().angle_to(Vector3.UP)
			)

			if slope > max_slope_degrees:
				continue

			var elevation_factor := 1.0 - smoothstep(
				dense_forest_elevation,
				tree_line_elevation,
				elevation
			)

			var distance_factor := 1.0

			if forest_transition_distance > 0.0:
				distance_factor = smoothstep(
					village_clear_radius,
					village_clear_radius
						+ forest_transition_distance,
					distance_from_village
				)

			var noise_value := noise.get_noise_2d(x, z)

			var noise_factor := smoothstep(
				-0.45,
				0.35,
				noise_value
			)

			var spawn_chance := (
				density
				* elevation_factor
				* distance_factor
				* noise_factor
			)

			if rng.randf() > spawn_chance:
				continue

			var elevation_scale := lerpf(
				alpine_tree_scale,
				1.0,
				elevation_factor
			)

			var tree_scale := rng.randf_range(
				min_tree_scale,
				max_tree_scale
			) * elevation_scale

			var tree_transform := create_transform(
				pos,
				tree_scale,
				rng
			)

			# Mature trees dominate dense forest interiors.
			# Younger trees dominate edges and alpine areas.

			var maturity := (
				elevation_factor
				* distance_factor
				* noise_factor
			)

			var pine_1_weight := lerpf(
				0.65, 0.20, maturity
			)

			var pine_3_weight := lerpf(
				0.05, 0.45, maturity
			)

			var roll := rng.randf()

			if roll < pine_1_weight:
				pine_1.append(tree_transform)

			elif roll > 1.0 - pine_3_weight:
				pine_3.append(tree_transform)

			else:
				pine_2.append(tree_transform)

	replace_instances(pine_1_id, pine_1)
	replace_instances(pine_2_id, pine_2)
	replace_instances(pine_3_id, pine_3)

	print(
		"Generated trees: ",
		pine_1.size() + pine_2.size() + pine_3.size()
	)


func generate_grass() -> void:
	if not is_terrain_valid():
		return

	if grass_max_elevation <= grass_fade_elevation:
		push_warning("Invalid grass elevation settings.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed + 1000

	var noise := create_noise(
		forest_seed + 1000,
		grass_noise_frequency
	)

	var tall_noise := create_noise(
		forest_seed + 2000,
		tall_grass_noise_frequency
	)

	var low_1: Array[Transform3D] = []
	var low_2: Array[Transform3D] = []
	var high_1: Array[Transform3D] = []
	var high_2: Array[Transform3D] = []

	var half_size := grass_area_size * 0.5
	var spacing := maxf(grass_spacing, 0.25)

	var columns := int(ceil(grass_area_size.x / spacing))
	var rows := int(ceil(grass_area_size.y / spacing))

	for ix in range(columns):
		for iz in range(rows):

			var x := village_center.x - half_size.x \
				+ (ix + rng.randf()) * spacing

			var z := village_center.z - half_size.y \
				+ (iz + rng.randf()) * spacing

			if x >= village_center.x + half_size.x \
					or z >= village_center.z + half_size.y:
				continue

			var pos := Vector3(x, 0.0, z)

			var distance_from_village := Vector2(
				x - village_center.x,
				z - village_center.z
			).length()

			if distance_from_village < grass_clear_radius:
				continue

			var height := terrain.data.get_height(pos)

			if not is_finite(height):
				continue

			pos.y = height

			var elevation := height - village_center.y

			if elevation < grass_min_elevation \
					or elevation >= grass_max_elevation:
				continue

			var normal := terrain.data.get_normal(pos)

			if not normal.is_finite() \
					or normal.length_squared() < 0.001:
				continue

			var slope := rad_to_deg(
				normal.normalized().angle_to(Vector3.UP)
			)

			if slope > grass_max_slope:
				continue

			var elevation_factor := 1.0 - smoothstep(
				grass_fade_elevation,
				grass_max_elevation,
				elevation
			)

			var noise_factor := smoothstep(
				-0.55,
				0.25,
				noise.get_noise_2d(x, z)
			)

			var spawn_chance := (
				grass_density
				* elevation_factor
				* noise_factor
			)

			if rng.randf() > spawn_chance:
				continue

			var grass_scale := rng.randf_range(
				min_grass_scale,
				max_grass_scale
			)

			var grass_transform := create_transform(
				pos,
				grass_scale,
				rng
			)

			# Create irregular clusters of tall grass.

			var tall_factor := smoothstep(
				-0.1,
				0.45,
				tall_noise.get_noise_2d(x, z)
			)

			var high_chance := (
				tall_grass_chance
				* tall_factor
				* elevation_factor
			)

			if rng.randf() < high_chance:

				if rng.randf() < 0.5:
					high_1.append(grass_transform)
				else:
					high_2.append(grass_transform)

			else:

				if rng.randf() < 0.5:
					low_1.append(grass_transform)
				else:
					low_2.append(grass_transform)

	replace_instances(grass_low_1_id, low_1)
	replace_instances(grass_low_2_id, low_2)
	replace_instances(grass_high_1_id, high_1)
	replace_instances(grass_high_2_id, high_2)

	print(
		"Generated grass: ",
		low_1.size() + low_2.size()
		+ high_1.size() + high_2.size()
	)


func create_transform(
	pos: Vector3,
	instance_scale: float,
	rng: RandomNumberGenerator
) -> Transform3D:

	var yaw := rng.randf_range(0.0, TAU)

	var basis := Basis(Vector3.UP, yaw)
	basis = basis.scaled(Vector3.ONE * instance_scale)

	return Transform3D(basis, pos)


func replace_instances(
	mesh_id: int,
	transforms: Array[Transform3D]
) -> void:

	terrain.instancer.clear_by_mesh(mesh_id)

	if not transforms.is_empty():
		terrain.instancer.add_transforms(
			mesh_id,
			transforms
		)


func clear_forest() -> void:
	if not is_terrain_valid():
		return

	terrain.instancer.clear_by_mesh(pine_1_id)
	terrain.instancer.clear_by_mesh(pine_2_id)
	terrain.instancer.clear_by_mesh(pine_3_id)

	print("Forest cleared.")


func clear_grass() -> void:
	if not is_terrain_valid():
		return

	terrain.instancer.clear_by_mesh(grass_low_1_id)
	terrain.instancer.clear_by_mesh(grass_low_2_id)
	terrain.instancer.clear_by_mesh(grass_high_1_id)
	terrain.instancer.clear_by_mesh(grass_high_2_id)

	print("Grass cleared.")
