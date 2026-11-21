extends Node3D

@export var warning_duration: float = 2.0
@export var fall_height: float = 12.0
@export var fade_duration: float = 1.0

@onready var pine_cone: RigidBody3D = $PineCone
@onready var mesh: MeshInstance3D = $PineCone/MeshInstance3D
@onready var collision: CollisionShape3D = $PineCone/CollisionShape3D
@onready var shadow: Decal = $WarningShadow
var shadow_tween: Tween

@export var reset_delay: float = 1.0

var has_landed: bool = false
var initial_transform: Transform3D
var material: StandardMaterial3D

func _ready() -> void:
	initial_transform = pine_cone.transform
	
	material = mesh.get_active_material(0).duplicate()
	mesh.material_override = material
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	pine_cone.freeze = true
	pine_cone.set_collision_layer_value(1, false)
	
	start_cycle()

func start_cycle() -> void:
	has_landed = false
	
	pine_cone.visible = false
	pine_cone.freeze = true
	pine_cone.linear_velocity = Vector3.ZERO
	pine_cone.angular_velocity = Vector3.ZERO
	pine_cone.transform = initial_transform

	var color := material.albedo_color
	color.a = 1.0
	material.albedo_color = color
	
	await get_tree().process_frame
	
	pine_cone.visible = true

	start_shadow_warning()

	await get_tree().create_timer(warning_duration).timeout

	
	pine_cone.set_collision_layer_value(1, true)
	collision.set_deferred("disabled", false)
	pine_cone.freeze = false

func _on_acorn_body_entered(_body: Node) -> void:
	if has_landed:
		return
	
	### If want pinecone to squish player and push instead use this check
	#if body is not StaticBody3D and body is not AnimatableBody3D:
	#	return
	
	has_landed = true
	stop_shadow_warning()
	
	### If want to not let player be knocked after pinecone hits ground first time
	#pine_cone.set_collision_layer_value(1, false)
	
	fade_out()

func fade_out() -> void:
	mesh.material_override = material

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, fade_duration)
	
	await tween.finished
	pine_cone.set_collision_layer_value(1, false)
	pine_cone.visible = false
	collision.set_deferred("disabled", true)
	
	await get_tree().create_timer(reset_delay).timeout

	start_cycle()
	
func start_shadow_warning() -> void:
	shadow.visible = true

	var color := shadow.modulate
	color.a = 0.8
	shadow.modulate = color

	shadow_tween = create_tween()
	shadow_tween.set_loops()

	shadow_tween.tween_property(shadow, "modulate:a", 0.3, 0.4)

	shadow_tween.tween_property(shadow, "modulate:a", 0.8, 0.4)


func stop_shadow_warning() -> void:
	if shadow_tween and shadow_tween.is_running():
		shadow_tween.kill()

	shadow.visible = false
