extends MultiplayerSpawner

@export var network_player: PackedScene
@export var spawn_point: Marker3D
@export var ball: RigidBody3D

func spawn_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	var spawn_parent := get_node(spawn_path) as Node3D
	
	player.position = spawn_parent.to_local(spawn_point.global_position)
	spawn_parent.add_child(player)

func despawn_player(id: int) -> void:
	var spawn_parent := get_node(spawn_path) as Node3D
	var player := spawn_parent.get_node_or_null(str(id))
	
	if player != null:
		player.queue_free()
