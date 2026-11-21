
@tool
extends StaticBody3D

@export_group("Ramp Geometry")

@export_range(0.1, 100.0, 0.1) var ramp_length: float = 4.0:
	set(value):
		ramp_length = value
		regenerate()

@export_range(0.0, 50.0, 0.1) var ramp_height: float = 2.15:
	set(value):
		ramp_height = value
		regenerate()

@export_range(0.1, 50.0, 0.1) var ramp_width: float = 3.0:
	set(value):
		ramp_width = value
		regenerate()

@export_range(2, 128, 1) var segments: int = 32:
	set(value):
		segments = value
		regenerate()

@export_range(0.1, 10.0, 0.1) var thickness: float = 0.5:
	set(value):
		thickness = value
		regenerate()


@export_group("Ramp Curvature")

@export var height_curve: Curve:
	set(value):
		if height_curve != null:
			if height_curve.changed.is_connected(regenerate):
				height_curve.changed.disconnect(regenerate)

		height_curve = value

		if height_curve != null:
			height_curve.changed.connect(regenerate)

		regenerate()


@export_range(0.2, 5.0, 0.1) var curvature_strength: float = 1.0:
	set(value):
		curvature_strength = value
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


func _ready() -> void:
	if height_curve == null:
		height_curve = Curve.new()
		height_curve.add_point(Vector2(0.0, 0.0))
		height_curve.add_point(Vector2(1.0, 1.0))

	regenerate()
	update_physics_material()


func update_physics_material() -> void:
	if not is_node_ready():
		return

	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()

	physics_material_override.friction = friction
	physics_material_override.bounce = bounce


func regenerate() -> void:
	if not is_node_ready():
		return

	if height_curve == null:
		return

	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var collision_shape: CollisionShape3D = $CollisionShape3D

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_width := ramp_width * 0.5
	var bottom_y := -thickness

	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments

		var x0 := t0 * ramp_length
		var x1 := t1 * ramp_length

		var y0 := get_ramp_height(t0)
		var y1 := get_ramp_height(t1)

		var a := Vector3(x0, y0, -half_width)
		var b := Vector3(x0, y0, half_width)
		var c := Vector3(x1, y1, -half_width)
		var d := Vector3(x1, y1, half_width)

		# Top surface
		add_triangle(st, a, c, b)
		add_triangle(st, c, d, b)

		# Left side (-Z)
		add_triangle(st,
			Vector3(x0, y0, -half_width),
			Vector3(x0, bottom_y, -half_width),
			Vector3(x1, bottom_y, -half_width)
		)
		add_triangle(st,
			Vector3(x0, y0, -half_width),
			Vector3(x1, bottom_y, -half_width),
			Vector3(x1, y1, -half_width)
		)

		# Right side (+Z)
		add_triangle(st,
			Vector3(x0, y0, half_width),
			Vector3(x1, bottom_y, half_width),
			Vector3(x0, bottom_y, half_width)
		)
		add_triangle(st,
			Vector3(x0, y0, half_width),
			Vector3(x1, y1, half_width),
			Vector3(x1, bottom_y, half_width)
		)

		# Bottom (-Y)
		add_triangle(st,
			Vector3(x0, bottom_y, -half_width),
			Vector3(x0, bottom_y, half_width),
			Vector3(x1, bottom_y, -half_width)
		)
		add_triangle(st,
			Vector3(x1, bottom_y, -half_width),
			Vector3(x0, bottom_y, half_width),
			Vector3(x1, bottom_y, half_width)
		)

	# Front cap (-X)
	var front_y := get_ramp_height(0.0)

	add_triangle(st,
		Vector3(0, front_y, -half_width),
		Vector3(0, front_y, half_width),
		Vector3(0, bottom_y, -half_width)
	)
	add_triangle(st,
		Vector3(0, front_y, half_width),
		Vector3(0, bottom_y, half_width),
		Vector3(0, bottom_y, -half_width)
	)

	# Back cap (+X)
	var back_y := get_ramp_height(1.0)

	add_triangle(st,
		Vector3(ramp_length, back_y, -half_width),
		Vector3(ramp_length, bottom_y, -half_width),
		Vector3(ramp_length, back_y, half_width)
	)
	add_triangle(st,
		Vector3(ramp_length, back_y, half_width),
		Vector3(ramp_length, bottom_y, -half_width),
		Vector3(ramp_length, bottom_y, half_width)
	)

	st.generate_normals()

	var mesh := st.commit()

	mesh_instance.mesh = mesh
	collision_shape.shape = mesh.create_trimesh_shape()

func get_ramp_height(t: float) -> float:
	if height_curve == null:
		return 0.0

	var curved_t := pow(t, curvature_strength)
	return ramp_height * height_curve.sample_baked(curved_t)

func add_triangle(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
