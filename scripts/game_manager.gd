extends Node

enum GameState{
	LOBBY, 
	STARTING, 
	PLAYING, 
	FINISHED
}

var game_state: GameState = GameState.LOBBY
var game_active: bool = false
signal game_started

@rpc("authority", "call_local", "reliable")
func start_game() -> void :
	if game_active:
		return

	game_active = true
	game_state = GameState.PLAYING
	game_started.emit()

	print("Game started!")
