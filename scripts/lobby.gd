extends Node3D

@onready var suspension_rod: RigidBody3D = $SuspensionRod
@onready var ceiling_joint: PinJoint3D = $CeilingJoint
@onready var ball_joint: PinJoint3D = $BallJoint
@onready var lobby_camera: Camera3D = $LobbyCamera
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
	GameManager.game_state = GameManager.GameState.LOBBY
	lobby_camera.make_current()
	
	if not multiplayer.is_server():
		suspension_rod.freeze = true

		ceiling_joint.set_node_a(NodePath())
		ceiling_joint.set_node_b(NodePath())

		ball_joint.set_node_a(NodePath())
		ball_joint.set_node_b(NodePath())
	
	await get_tree().process_frame
	
	HighLevelNetworkHandler.register_scene_spawner(multiplayer_spawner, HighLevelNetworkHandler.NetworkScene.LOBBY)
