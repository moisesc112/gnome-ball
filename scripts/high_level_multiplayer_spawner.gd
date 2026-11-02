extends MultiplayerSpawner

@export var network_player: PackedScene
@export var spawn_point: Marker3D

func _ready() -> void:
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(spawn_player)
		spawn_player(1)
	
func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	player.position = spawn_point.global_position
	
	get_node(spawn_path).call_deferred("add_child", player)
