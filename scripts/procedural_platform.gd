@tool
extends StaticBody3D

enum PlatformType {
	STRAIGHT,
	TURN_90,
	TURN_90_SHARP,
	S_CURVE,
	S_CURVE_ALTERNATING,
	HELIX,
	FLAT_SPIRAL
}

@export_group("Platform Shape")

@export var platform_type: PlatformType = PlatformType.STRAIGHT:
	set(value):
		platform_type = value
		regenerate()

@export_range(0.5, 100.0, 0.1) var length: float = 5.0:
	set(value):
		length = value
		regenerate()

@export_range(0.5, 20.0, 0.1) var width: float = 2.0:
	set(value):
		width = value
		regenerate()

@export_range(0.1, 5.0, 0.1) var thickness: float = 0.5:
	set(value):
		thickness = value
		regenerate()

@export_range(4, 512, 1) var segments: int = 64:
	set(value):
		segments = value
		regenerate()

@export_group("Curvature")

@export_range(0.5, 30.0, 0.1) var turn_radius: float = 4.0:
	set(value):
		turn_radius = value
		regenerate()

@export_range(0.0, 10.0, 0.1) var curve_strength: float = 3.0:
	set(value):
		curve_strength = value
		regenerate()

@export_range(0.5,  50.0, 0.1) var corner_distance: float = 4.0:
	set(value):
		corner_distance = value
		regenerate()

@export var reverse_turn: bool = false:
	set(value):
		reverse_turn = value
		regenerate()

@export_group("Spiral")

@export_range(1.0, 50.0, 0.1) var spiral_radius: float = 5.0:
	set(value):
		spiral_radius = value
		regenerate()

@export_range(0.25, 10.0, 0.25) var spiral_turns: float = 1.0:
	set(value):
		spiral_turns = value
		regenerate()

@export_range(-50.0, 50.0, 0.1) var spiral_height: float = 5.0:
	set(value):
		spiral_height = value
		regenerate()

@export_range(0.5, 50.0, 0.1) var spiral_end_radius: float = 2.0:
	set(value):
		spiral_end_radius = value
		regenerate()

@export_group("Elevation and Banking")

@export_range(-50.0, 50.0, 0.1) var start_elevation: float = 0.0:
	set(value):
		start_elevation = value
		regenerate()

@export_range(-50.0, 50.0, 0.1) var end_elevation: float = 0.0:
	set(value):
		end_elevation = value
		regenerate()

@export var smooth_elevation: bool = true:
	set(value):
		smooth_elevation = value
		regenerate()

@export_range(-80.0, 80.0, 1.0) var start_bank_degrees: float = 0.0:
	set(value):
		start_bank_degrees = value
		regenerate()

@export_range(-80.0, 80.0, 1.0) var end_bank_degrees: float = 0.0:
	set(value):
		end_bank_degrees = value
		regenerate()

@export var smooth_banking: bool = true:
	set(value):
		smooth_banking = value
		regenerate()

@export_group("Physics")

@export_range(0.0, 1.0, 0.05) var friction: float = 0.5:
	set(value):
		friction = value
		update_physics_material()

@export_range(0.0, 1.0, 0.05) var bounce: float = 0.0:
	set(value):
		bounce = value
		update_physics_material()

@export_group("Snapping")

@export var previous_platform: Node3D
@export_tool_button("Snap to Previous") var snap_button = snap_to_previous


func _ready() -> void:
	regenerate()
	update_physics_material()


func update_physics_material() -> void:
	if not is_node_ready():
		return

	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
	else:
		# Give each platform its own material instead of editing shared resources.
		physics_material_override = physics_material_override.duplicate()

	physics_material_override.friction = friction
	physics_material_override.bounce = bounce


func get_interpolation(t: float, smooth: bool) -> float:
	if smooth:
		return t * t * (3.0 - 2.0 * t)
	return t


func get_path_position(t: float) -> Vector3:
	var direction := -1.0 if reverse_turn else 1.0
	var result := Vector3.ZERO

	match platform_type:
		PlatformType.STRAIGHT:
			result = Vector3(t * length, 0.0, 0.0)

		PlatformType.TURN_90:
			var angle := t * PI * 0.5
			result = Vector3(
				sin(angle) * turn_radius,
				0.0,
				direction * turn_radius * (1.0 - cos(angle))
			)

		PlatformType.TURN_90_SHARP:
			if t <= 0.5:
				result = Vector3(t * 2.0 * corner_distance, 0.0, 0.0)
			else:
				result = Vector3(
					corner_distance,
					0.0,
					direction * (t - 0.5) * 2.0 * corner_distance
				)

		PlatformType.S_CURVE:
			result = Vector3(
				t * length,
				0.0,
				direction * curve_strength * (t - sin(TAU * t) / TAU)
			)

		PlatformType.S_CURVE_ALTERNATING:
			result = Vector3(
				t * length,
				0.0,
				direction * curve_strength * pow(sin(PI * t), 2.0) * sin(TAU * t)
			)

		PlatformType.HELIX:
			var angle := t * TAU * spiral_turns * direction
			result = Vector3(
				spiral_radius * sin(angle),
				t * spiral_height,
				spiral_radius * (1.0 - cos(angle))
			)

		PlatformType.FLAT_SPIRAL:
			var angle := t * TAU * spiral_turns * direction
			var radius := lerpf(spiral_radius, spiral_end_radius, t)
			result = Vector3(
				radius * cos(angle) - spiral_radius,
				0.0,
				radius * sin(angle)
			)

	# Elevation is additive, so it also works on a helix.
	var elevation_t := get_interpolation(t, smooth_elevation)
	result.y += lerpf(start_elevation, end_elevation, elevation_t)
	return result


func get_path_tangent(t: float) -> Vector3:
	# At a sharp corner there is no unique tangent. Use the outgoing
	# tangent at the corner, and one-sided samples at the ends.
	if platform_type == PlatformType.TURN_90_SHARP:
		var delta := 0.0001
		var direction := -1.0 if reverse_turn else 1.0
		var t0 := maxf(0.0, t - delta)
		var t1 := minf(1.0, t + delta)
		if t < 0.5:
			t1 = minf(t1, 0.5)
		else:
			t0 = maxf(t0, 0.5)
		var sharp_delta := get_path_position(t1) - get_path_position(t0)
		if sharp_delta.length_squared() > 0.00000001:
			return sharp_delta.normalized()
		return Vector3.RIGHT if t < 0.5 else Vector3(0.0, 0.0, direction)

	var delta := 0.0001
	var before := get_path_position(maxf(t - delta, 0.0))
	var after := get_path_position(minf(t + delta, 1.0))
	return (after - before).normalized()


func get_bank(t: float) -> float:
	return deg_to_rad(lerpf(start_bank_degrees, end_bank_degrees, get_interpolation(t, smooth_banking)))


func get_section_basis(t: float) -> Basis:
	var forward := get_path_tangent(t)
	# Horizontal sideways vector: no unwanted banking on ordinary slopes.
	var side := Vector3(-forward.z, 0.0, forward.x).normalized()
	if side.length_squared() < 0.000001:
		side = Vector3.BACK
	var up := side.cross(forward).normalized()

	# Rotate the cross-section around the path's forward direction.
	var bank_rotation := Basis(forward, get_bank(t))
	side = bank_rotation * side
	up = bank_rotation * up
	return Basis(forward, up, side).orthonormalized()


func regenerate() -> void:
	if not is_node_ready():
		return

	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var collision_shape: CollisionShape3D = $CollisionShape3D
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if platform_type == PlatformType.TURN_90_SHARP:
		generate_sharp_turn(st)
	else:
		generate_smooth_platform(st)

	st.generate_normals()
	var mesh := st.commit()
	mesh_instance.mesh = mesh
	collision_shape.shape = mesh.create_trimesh_shape()
	update_connectors()

	if Engine.is_editor_hint() and previous_platform != null:
		snap_to_previous()


func get_section_edges(t: float) -> Array[Vector3]:
	var center := get_path_position(t)
	var side := get_section_basis(t).z
	var half_width := width * 0.5
	return [center - side * half_width, center + side * half_width]


func generate_smooth_platform(st: SurfaceTool) -> void:
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var edges0 := get_section_edges(t0)
		var edges1 := get_section_edges(t1)
		add_platform_section(
			st,
			edges0[0], edges0[1], edges1[0], edges1[1],
			i == 0, i == segments - 1
		)


func generate_sharp_turn(st: SurfaceTool) -> void:
	# Mitered corner, with banking and elevation at each section.
	var half_width := width * 0.5
	var p0 := get_path_position(0.0)
	var p1 := get_path_position(0.5)
	var p2 := get_path_position(1.0)

	var side0 := get_section_basis(0.0).z
	var side1 := get_section_basis(1.0).z
	var corner_bank := get_bank(0.5)

	# Use the corner's bank angle on both incoming and outgoing sides.
	var incoming := (p1 - p0).normalized()
	var outgoing := (p2 - p1).normalized()
	var incoming_side := Vector3(-incoming.z, 0.0, incoming.x).normalized()
	var outgoing_side := Vector3(-outgoing.z, 0.0, outgoing.x).normalized()
	incoming_side = Basis(incoming, corner_bank) * incoming_side
	outgoing_side = Basis(outgoing, corner_bank) * outgoing_side

	var miter := (incoming_side + outgoing_side).normalized()
	var denominator := miter.dot(incoming_side)
	if absf(denominator) < 0.01:
		push_warning("Sharp turn miter is degenerate. Check turn dimensions.")
		return
	var miter_offset := miter * (half_width / denominator)

	var a := p0 - side0 * half_width
	var b := p0 + side0 * half_width
	var c := p1 - miter_offset
	var d := p1 + miter_offset
	var e := p2 - side1 * half_width
	var f := p2 + side1 * half_width

	add_platform_section(st, a, b, c, d, true, false)
	add_platform_section(st, c, d, e, f, false, true)



func add_platform_section(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	is_start: bool,
	is_end: bool
) -> void:
	var down := Vector3.DOWN * thickness
	var a_bottom := a + down
	var b_bottom := b + down
	var c_bottom := c + down
	var d_bottom := d + down

	# Top
	add_triangle(st, a, c, b)
	add_triangle(st, c, d, b)

	# Bottom
	add_triangle(st, a_bottom, b_bottom, c_bottom)
	add_triangle(st, c_bottom, b_bottom, d_bottom)

	# Left wall
	add_triangle(st, a, a_bottom, c)
	add_triangle(st, c, a_bottom, c_bottom)

	# Right wall
	add_triangle(st, b, d, b_bottom)
	add_triangle(st, d, d_bottom, b_bottom)

	# Start cap
	if is_start:
		add_triangle(st, a, b, a_bottom)
		add_triangle(st, b, b_bottom, a_bottom)

	# End cap
	if is_end:
		add_triangle(st, c, c_bottom, d)
		add_triangle(st, d, c_bottom, d_bottom)



func update_connectors() -> void:
	var start_connector: Marker3D = $StartConnector
	var end_connector: Marker3D = $EndConnector
	start_connector.position = get_path_position(0.0)
	end_connector.position = get_path_position(1.0)
	start_connector.basis = get_section_basis(0.0)
	end_connector.basis = get_section_basis(1.0)


func add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func snap_to_previous() -> void:
	if previous_platform == null:
		push_warning("Assign a previous platform first.")
		return
	if previous_platform == self:
		push_warning("A platform cannot snap to itself.")
		return

	var previous_end: Marker3D = previous_platform.get_node_or_null("EndConnector")
	var current_start: Marker3D = get_node_or_null("StartConnector")
	if previous_end == null or current_start == null:
		push_warning("Missing StartConnector or EndConnector.")
		return

	# Work in global space so platforms can have different parents.
	var target_basis := previous_end.global_transform.basis.orthonormalized()
	var start_basis := current_start.transform.basis.orthonormalized()
	var new_basis := target_basis * start_basis.inverse()
	var target_position := previous_end.global_position - new_basis * current_start.position
	global_transform = Transform3D(new_basis, target_position)
