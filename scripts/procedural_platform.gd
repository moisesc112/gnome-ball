
@tool
extends StaticBody3D

enum PlatformType {
	STRAIGHT,
	TURN_90,
	TURN_90_SHARP,
	S_CURVE,
	S_CURVE_ALTERNATING
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

@export_range(4, 128, 1) var segments: int = 32:
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

@export_range(0.5, 30.0, 0.1) var corner_distance: float = 4.0:
	set(value):
		corner_distance = value
		regenerate()

@export var reverse_turn: bool = false:
	set(value):
		reverse_turn = value
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
		# Avoid modifying a material shared by multiple instances.
		if not physics_material_override.resource_local_to_scene:
			physics_material_override = physics_material_override.duplicate()

	physics_material_override.friction = friction
	physics_material_override.bounce = bounce


func get_path_position(t: float) -> Vector3:
	var direction := -1.0 if reverse_turn else 1.0

	match platform_type:
		PlatformType.STRAIGHT:
			return Vector3(t * length, 0.0, 0.0)

		PlatformType.TURN_90:
			var angle := t * PI * 0.5
			return Vector3(
				sin(angle) * turn_radius,
				0.0,
				direction * turn_radius * (1.0 - cos(angle))
			)

		PlatformType.TURN_90_SHARP:
			if t <= 0.5:
				return Vector3(
					t * 2.0 * corner_distance,
					0.0,
					0.0
				)
			return Vector3(
				corner_distance,
				0.0,
				direction * (t - 0.5) * 2.0 * corner_distance
			)

		PlatformType.S_CURVE:
			var x := t * length
			var z := direction * curve_strength * (
				t - sin(TAU * t) / TAU
			)
			return Vector3(x, 0.0, z)

		PlatformType.S_CURVE_ALTERNATING:
			var x := t * length

			# Two opposite bends with flat entry and exit tangents.
			var z := direction * curve_strength * pow(
				sin(PI * t), 2.0
			) * sin(TAU * t)

			return Vector3(x, 0.0, z)

	return Vector3.ZERO


func get_path_tangent(t: float) -> Vector3:
	if platform_type == PlatformType.TURN_90_SHARP:
		if t < 0.5:
			return Vector3.RIGHT

		var direction := -1.0 if reverse_turn else 1.0
		return Vector3(0.0, 0.0, direction)

	var delta := 0.001
	var before := get_path_position(maxf(t - delta, 0.0))
	var after := get_path_position(minf(t + delta, 1.0))

	return (after - before).normalized()


func get_path_side(t: float) -> Vector3:
	var tangent := get_path_tangent(t)
	return Vector3(-tangent.z, 0.0, tangent.x)


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


func generate_smooth_platform(st: SurfaceTool) -> void:
	var half_width := width * 0.5

	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments

		var p0 := get_path_position(t0)
		var p1 := get_path_position(t1)

		var side0 := get_path_side(t0)
		var side1 := get_path_side(t1)

		var a := p0 - side0 * half_width
		var b := p0 + side0 * half_width
		var c := p1 - side1 * half_width
		var d := p1 + side1 * half_width

		var a_bottom := a + Vector3.DOWN * thickness
		var b_bottom := b + Vector3.DOWN * thickness
		var c_bottom := c + Vector3.DOWN * thickness
		var d_bottom := d + Vector3.DOWN * thickness

		add_platform_section(
			st,
			a, b, c, d,
			a_bottom, b_bottom, c_bottom, d_bottom,
			i == 0,
			i == segments - 1
		)


func generate_sharp_turn(st: SurfaceTool) -> void:
	# Three cross-sections form a continuous mitered corner.
	var half_width := width * 0.5
	var direction := -1.0 if reverse_turn else 1.0

	var p0 := Vector3.ZERO
	var p1 := Vector3(corner_distance, 0.0, 0.0)
	var p2 := Vector3(
		corner_distance,
		0.0,
		direction * corner_distance
	)

	var tangent0 := Vector3.RIGHT
	var tangent1 := Vector3(0.0, 0.0, direction)

	var side0 := Vector3(
		-tangent0.z, 0.0, tangent0.x
	)
	var side1 := Vector3(
		-tangent1.z, 0.0, tangent1.x
	)

	# Miter at the corner.
	var miter := (side0 + side1).normalized()
	var denominator := miter.dot(side0)

	var miter_offset := miter * (
		half_width / denominator
	)

	var a := p0 - side0 * half_width
	var b := p0 + side0 * half_width

	var c := p1 - miter_offset
	var d := p1 + miter_offset

	var e := p2 - side1 * half_width
	var f := p2 + side1 * half_width

	var a_bottom := a + Vector3.DOWN * thickness
	var b_bottom := b + Vector3.DOWN * thickness
	var c_bottom := c + Vector3.DOWN * thickness
	var d_bottom := d + Vector3.DOWN * thickness
	var e_bottom := e + Vector3.DOWN * thickness
	var f_bottom := f + Vector3.DOWN * thickness

	add_platform_section(
		st,
		a, b, c, d,
		a_bottom, b_bottom, c_bottom, d_bottom,
		true, false
	)

	add_platform_section(
		st,
		c, d, e, f,
		c_bottom, d_bottom, e_bottom, f_bottom,
		false, true
	)


func add_platform_section(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	a_bottom: Vector3,
	b_bottom: Vector3,
	c_bottom: Vector3,
	d_bottom: Vector3,
	is_start: bool,
	is_end: bool
) -> void:
	# Top (+Y)
	add_triangle(st, a, c, b)
	add_triangle(st, c, d, b)

	# Bottom (-Y)
	add_triangle(st, a_bottom, b_bottom, c_bottom)
	add_triangle(st, c_bottom, b_bottom, d_bottom)

	# Left side
	add_triangle(st, a, a_bottom, c)
	add_triangle(st, c, a_bottom, c_bottom)

	# Right side
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

	var start_tangent := get_path_tangent(0.0)
	var end_tangent := get_path_tangent(1.0)

	start_connector.rotation.y = atan2(
		-start_tangent.z,
		start_tangent.x
	)

	end_connector.rotation.y = atan2(
		-end_tangent.z,
		end_tangent.x
	)


func add_triangle(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	
	
func snap_to_previous() -> void:
	if previous_platform == null:
		push_warning("Assign a previous platform first.")
		return

	var previous_end: Marker3D = previous_platform.get_node_or_null(
		"EndConnector"
	)

	var current_start: Marker3D = get_node_or_null(
		"StartConnector"
	)

	if previous_end == null or current_start == null:
		push_warning("Missing StartConnector or EndConnector.")
		return

	# Match the direction of both connectors.
	# The connectors use local +X as their forward direction.
	var target_basis := previous_end.global_transform.basis
	var start_basis := current_start.transform.basis

	var new_basis := target_basis * start_basis.inverse()

	# Move this platform so its start connector
	# lands exactly on the previous platform's end connector.
	var target_position := (
		previous_end.global_position
		- new_basis * current_start.position
	)

	global_transform = Transform3D(
		new_basis,
		target_position
	)
