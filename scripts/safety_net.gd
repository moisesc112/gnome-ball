
extends Node3D

enum NetPattern {
	GRID,
	SPIDERWEB,
	CIRCULAR_GRID
}

@export_group("Pattern")
@export var net_pattern: NetPattern = NetPattern.GRID
@export var center_hole: bool = false
@export var inner_radius: float = 26.0
@export var outer_radius: float = 50.0

@export_group("Grid")
@export var net_width: float = 12.0
@export var net_depth: float = 12.0
@export_range(4, 64) var resolution: int = 20

@export_group("Spiderweb")
@export_range(8, 64) var radial_segments: int = 32
@export_range(2, 32) var ring_segments: int = 12

@export_group("Net Physics")
@export var spring_strength: float = 25.0
@export var neighbor_strength: float = 35.0
@export var damping: float = 6.0
@export var max_sag: float = 2.0
@export var contact_tolerance: float = 0.25
@export var max_support_acceleration: float = 200.0

@export_group("Ball Interaction")
@export var support_strength: float = 200.0
@export var support_damping: float = 20.0
@export var impact_transfer: float = 1.0
@export var ball_radius: float = 2.0

@export_group("Detection")
@export var detection_height: float = 10.0
@export var detection_padding: float = 1.0

@onready var detection_collision: CollisionShape3D = $Area3D/CollisionShape3D

@onready var net_mesh: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $Area3D

var heights := PackedFloat32Array()
var velocities := PackedFloat32Array()
var vertices_rest := PackedVector3Array()
var line_indices := PackedInt32Array()

var neighbors: Array[PackedInt32Array] = []
var anchored := PackedByteArray()

var bodies: Array[RigidBody3D] = []


func _ready() -> void:
	_build_pattern()
	_update_detection_shape()

	detection_area.monitoring = true

	# Connect only if not already connected in the editor.
	if not detection_area.body_entered.is_connected(_on_body_entered):
		detection_area.body_entered.connect(_on_body_entered)

	if not detection_area.body_exited.is_connected(_on_body_exited):
		detection_area.body_exited.connect(_on_body_exited)

	_update_mesh()


func _physics_process(delta: float) -> void:
	_apply_ball_forces(delta)
	_simulate_net(delta)
	_update_mesh()

func _update_detection_shape() -> void:
	var shape: Shape3D

	match net_pattern:
		NetPattern.GRID:
			var box := BoxShape3D.new()

			box.size = Vector3(
				net_width + detection_padding * 2.0,
				detection_height,
				net_depth + detection_padding * 2.0
			)

			shape = box

		NetPattern.SPIDERWEB, NetPattern.CIRCULAR_GRID:
			var cylinder := CylinderShape3D.new()

			cylinder.radius = outer_radius + detection_padding
			cylinder.height = detection_height

			shape = cylinder

	detection_collision.shape = shape

func _build_pattern() -> void:
	vertices_rest.clear()
	line_indices.clear()
	neighbors.clear()
	anchored.clear()

	match net_pattern:
		NetPattern.GRID:
			_build_grid()

		NetPattern.SPIDERWEB:
			_build_spiderweb()

		NetPattern.CIRCULAR_GRID:
			_build_circular_grid()


	heights.resize(vertices_rest.size())
	velocities.resize(vertices_rest.size())

	heights.fill(0.0)
	velocities.fill(0.0)


func _add_vertex(_position: Vector3, fixed: bool) -> int:
	var index := vertices_rest.size()

	vertices_rest.append(_position)
	neighbors.append(PackedInt32Array())
	anchored.append(1 if fixed else 0)

	return index


func _connect_vertices(a: int, b: int) -> void:
	line_indices.append(a)
	line_indices.append(b)

	neighbors[a].append(b)
	neighbors[b].append(a)


# --------------------------------------------------
# GRID PATTERN
# --------------------------------------------------

func _grid_index(x: int, z: int) -> int:
	return z * (resolution + 1) + x


func _build_grid() -> void:
	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var u := float(x) / resolution
			var v := float(z) / resolution

			var px := (u - 0.5) * net_width
			var pz := (v - 0.5) * net_depth

			var fixed := (
				x == 0 or
				z == 0 or
				x == resolution or
				z == resolution
			)

			_add_vertex(Vector3(px, 0.0, pz), fixed)

	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var a := _grid_index(x, z)

			if x < resolution:
				_connect_vertices(a, _grid_index(x + 1, z))

			if z < resolution:
				_connect_vertices(a, _grid_index(x, z + 1))


# --------------------------------------------------
# SPIDERWEB PATTERN
# --------------------------------------------------

func _web_index(ring: int, segment: int) -> int:
	return 1 + ring * radial_segments + posmod(segment, radial_segments)


func _build_spiderweb() -> void:
	var center_index := -1

	if not center_hole:
		center_index = _add_vertex(Vector3.ZERO, false)

	for ring in range(ring_segments):
		var t := float(ring + 1) / ring_segments

		var start_radius := 0.0
		if center_hole:
			start_radius = inner_radius

		var radius := lerpf(
			start_radius,
			outer_radius,
			t
		)

		for segment in range(radial_segments):
			var angle := TAU * float(segment) / radial_segments

			var x := cos(angle) * radius
			var z := sin(angle) * radius

			var fixed := ring == ring_segments - 1

			if center_hole and ring == 0:
				fixed = true

			_add_vertex(Vector3(x, 0.0, z), fixed)

	var offset := 0 if center_hole else 1

	for ring in range(ring_segments):
		for segment in range(radial_segments):
			var a := offset + ring * radial_segments + segment

			var next_segment := (
				offset
				+ ring * radial_segments
				+ (segment + 1) % radial_segments
			)

			# Circular strands.
			_connect_vertices(a, next_segment)

			# Radial strands.
			if ring == 0:
				if not center_hole:
					_connect_vertices(center_index, a)
			else:
				var previous := (
					offset
					+ (ring - 1) * radial_segments
					+ segment
				)

				_connect_vertices(previous, a)

func _build_circular_grid() -> void:
	var spacing := (outer_radius * 2.0) / resolution

	# Horizontal grid strands.
	for row in range(resolution + 1):
		var z := -outer_radius + row * spacing

		_add_clipped_grid_line(true, z)

	# Vertical grid strands.
	for column in range(resolution + 1):
		var x := -outer_radius + column * spacing

		_add_clipped_grid_line(false, x)


func _add_clipped_grid_line(
	horizontal: bool,
	fixed_coordinate: float
) -> void:
	var distance := absf(fixed_coordinate)

	if distance >= outer_radius:
		return

	# Outer circle intersection.
	var outer_extent := sqrt(
		outer_radius * outer_radius
		- distance * distance
	)

	var intervals: Array[Vector2] = []

	if center_hole and distance < inner_radius:
		# Inner circle intersection.
		var inner_extent := sqrt(
			inner_radius * inner_radius
			- distance * distance
		)

		intervals.append(
			Vector2(-outer_extent, -inner_extent)
		)

		intervals.append(
			Vector2(inner_extent, outer_extent)
		)
	else:
		intervals.append(
			Vector2(-outer_extent, outer_extent)
		)

	for interval in intervals:
		var length := interval.y - interval.x

		var spacing := outer_radius * 2.0 / resolution

		var segments := maxi(
			1,
			ceili(length / spacing)
		)

		var previous_index := -1

		for step in range(segments + 1):
			var t := float(step) / segments
			var coordinate := lerpf(
				interval.x,
				interval.y,
				t
			)

			var _position: Vector3

			if horizontal:
				_position = Vector3(
					coordinate,
					0.0,
					fixed_coordinate
				)
			else:
				_position = Vector3(
					fixed_coordinate,
					0.0,
					coordinate
				)

			# Anchor endpoints at the boundaries.
			var fixed := (
				step == 0 or
				step == segments
			)

			var index := _add_vertex(position, fixed)

			if previous_index != -1:
				_connect_vertices(
					previous_index,
					index
				)

			previous_index = index

# --------------------------------------------------
# SPRING SIMULATION
# --------------------------------------------------

func _simulate_net(delta: float) -> void:
	var new_velocities := velocities.duplicate()

	for i in range(vertices_rest.size()):
		if anchored[i] == 1:
			new_velocities[i] = 0.0
			continue

		var h := heights[i]
		var v := velocities[i]

		var neighbor_sum := 0.0

		for neighbor in neighbors[i]:
			neighbor_sum += heights[neighbor] - h

		var acceleration := (
			-spring_strength * h
			+ neighbor_strength * neighbor_sum
			- damping * v
		)

		new_velocities[i] = v + acceleration * delta

	velocities = new_velocities

	for i in range(vertices_rest.size()):
		if anchored[i] == 1:
			heights[i] = 0.0
			continue

		heights[i] += velocities[i] * delta

		if heights[i] < -max_sag:
			heights[i] = -max_sag
			velocities[i] = maxf(velocities[i], 0.0)

		if heights[i] > 0.0:
			heights[i] = 0.0
			velocities[i] = minf(velocities[i], 0.0)


# --------------------------------------------------
# PLAYER INTERACTION
# --------------------------------------------------

func _find_nearest_vertex(local_pos: Vector3) -> int:
	var closest := -1
	var closest_distance := INF

	for i in range(vertices_rest.size()):
		var p := vertices_rest[i]

		var distance := Vector2(
			p.x - local_pos.x,
			p.z - local_pos.z
		).length_squared()

		if distance < closest_distance:
			closest_distance = distance
			closest = i

	return closest


func _is_inside_net(local_pos: Vector3) -> bool:
	var distance := Vector2(
		local_pos.x,
		local_pos.z
	).length()

	if center_hole and distance < inner_radius:
		return false

	match net_pattern:
		NetPattern.GRID:
			return (
				absf(local_pos.x) <= net_width * 0.5
				and absf(local_pos.z) <= net_depth * 0.5
			)

		NetPattern.SPIDERWEB, NetPattern.CIRCULAR_GRID:
			return distance <= outer_radius

	return false


func _apply_ball_forces(delta: float) -> void:
	for body in bodies:
		if not is_instance_valid(body):
			continue

		if not body.is_multiplayer_authority():
			continue

		var local_pos := to_local(body.global_position)

		if not _is_inside_net(local_pos):
			continue

		var i := _find_nearest_vertex(local_pos)

		if i == -1:
			continue

		var net_height := vertices_rest[i].y + heights[i]
		var ball_bottom := local_pos.y - ball_radius

		# Prevent the net from catching a ball coming from underneath.
		if local_pos.y < net_height - ball_radius:
			continue

		var penetration := net_height - ball_bottom

		if penetration <= 0.0:
			continue

		var net_velocity := velocities[i]
		var relative_velocity := body.linear_velocity.y - net_velocity

		var force := (
			support_strength * penetration
			- support_damping * relative_velocity
		)

		force = clampf(
			force,
			0.0,
			max_support_acceleration
		)

		body.apply_central_force(
			Vector3.UP * force * body.mass
		)

		# Deform the contacted vertex.
		if anchored[i] == 0:
			velocities[i] -= force * delta * impact_transfer
		else:
			for neighbor in neighbors[i]:
				if anchored[neighbor] == 0:
					velocities[neighbor] -= (
						force * delta * impact_transfer * 0.5
					)


# --------------------------------------------------
# MESH GENERATION
# --------------------------------------------------

func _update_mesh() -> void:
	var vertices := PackedVector3Array()

	for i in range(vertices_rest.size()):
		var _position := vertices_rest[i]
		_position.y += heights[i]

		vertices.append(position)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = line_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_LINES,
		arrays
	)

	net_mesh.mesh = mesh


# --------------------------------------------------
# BODY DETECTION
# --------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and not bodies.has(body):
		bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		bodies.erase(body)
