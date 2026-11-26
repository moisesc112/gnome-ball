@tool
extends Node3D

@export var trunk: MeshInstance3D
@export var leaves: MeshInstance3D

@export var save_path: String = "res://pine_combined.res"

@export var merge_now: bool = false:
	set(value):
		merge_now = false

		if value and Engine.is_editor_hint():
			print("Merge requested")
			merge_meshes.call_deferred()


func merge_meshes() -> void:
	print("Starting mesh merge")

	if trunk == null or leaves == null:
		push_error("Assign both trunk and leaves.")
		return

	var combined := ArrayMesh.new()

	for mesh_instance: MeshInstance3D in [trunk, leaves]:
		var source: Mesh = mesh_instance.mesh

		if source == null:
			push_error("Missing source mesh.")
			return

		var relative_transform := (
			global_transform.affine_inverse()
			* mesh_instance.global_transform
		)

		for i in range(source.get_surface_count()):
			var st := SurfaceTool.new()

			st.append_from(source, i, relative_transform)
			st.set_material(
				mesh_instance.get_active_material(i)
			)
			st.commit(combined)

	print("Combined surfaces: ", combined.get_surface_count())

	var error := ResourceSaver.save(combined, save_path)

	if error == OK:
		print("Successfully saved: ", save_path)
		print("Absolute path: ",
			ProjectSettings.globalize_path(save_path))
	else:
		push_error("Save failed: " + error_string(error))
