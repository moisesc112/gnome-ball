
extends Node3D
class_name GnomeCustomization

@export var face_meshes: Array[MeshInstance3D]
@export var face_textures: Array[Texture2D]

@export var hat_meshes: Array[MeshInstance3D]
@export var outfit_meshes: Array[MeshInstance3D]
@export var beard_meshes: Array[MeshInstance3D]

var materials: Dictionary = {}


func _ready() -> void:
	materials["face"] = _make_unique_materials(face_meshes)
	materials["hat"] = _make_unique_materials(hat_meshes)
	materials["outfit"] = _make_unique_materials(outfit_meshes)
	materials["beard"] = _make_unique_materials(beard_meshes)


func _make_unique_materials(meshes: Array[MeshInstance3D]) -> Array[Material]:
	var unique_materials: Array[Material] = []

	for mesh in meshes:
		if mesh == null:
			continue

		var original: Material = mesh.material_override

		if original == null:
			original = mesh.get_active_material(0)

		if original == null:
			continue

		var unique_material := original.duplicate()

		# Apply to the same override level being used.
		if mesh.material_override != null:
			mesh.material_override = unique_material
		else:
			mesh.set_surface_override_material(0, unique_material)

		unique_materials.append(unique_material)

	return unique_materials


func set_color(category: String, color: Color) -> void:
	if not materials.has(category):
		return

	for material in materials[category]:
		if material is StandardMaterial3D:
			material.albedo_color = color

		elif material is ShaderMaterial:
			material.set_shader_parameter("albedo_color", color)

func set_face(index: int) -> void:
	if index < 0 or index >= face_textures.size():
		return

	var texture := face_textures[index]

	for mesh in face_meshes:
		if mesh == null:
			continue

		var material := mesh.get_active_material(0) as StandardMaterial3D

		if material == null:
			print("No StandardMaterial3D found on: ", mesh.name)
			continue

		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
