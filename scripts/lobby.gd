extends Node3D

@onready var suspension_rod: RigidBody3D = $SuspensionRod
@onready var ceiling_joint: PinJoint3D = $CeilingJoint
@onready var ball_joint: PinJoint3D = $BallJoint
@onready var lobby_camera: Camera3D = $LobbyCamera
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

@onready var lobby_ui: Control = $CanvasLayer/LobbyUI
@onready var customization_ui: Control = $CanvasLayer/CustomizationUI

func _ready() -> void:
	GameManager.game_state = GameManager.GameState.LOBBY
	lobby_camera.make_current()
	
	customization_ui.hide()
	customization_ui.customization_finished.connect(_on_customization_finished)
	
	await get_tree().process_frame
	
	HighLevelNetworkHandler.register_scene_spawner(multiplayer_spawner, HighLevelNetworkHandler.NetworkScene.LOBBY)

func _on_customize_button_pressed() -> void:
	lobby_ui.hide()
	customization_ui.show()

func _on_customization_finished() -> void:
	lobby_ui.show()
