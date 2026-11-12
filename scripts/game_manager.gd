extends Node

enum GameState{
	LOBBY, 
	STARTING, 
	PLAYING, 
	FINISHED
}

var game_state: GameState = GameState.LOBBY
var game_active: bool = false

var local_pause_menu_open: bool = false
var disconnect_reason: String = ""

signal game_started
signal clock_sync_completed

# Clock synchronization
var server_clock_offset: float = 0.0
var clock_synchronized: bool = false

var best_rtt: float = INF
var sync_timer: float = 0.0

const INITIAL_SYNC_INTERVAL: float = 0.25
const NORMAL_SYNC_INTERVAL: float = 2.0
const CLOCK_SMOOTHING: float = 0.1
const MAX_RTT_MARGIN: float = 0.05

# Level timing
var level_start_time: float = 0.0
var start_scheduled: bool = false

const START_DELAY: float = 1.0

func _process(delta: float) -> void:
	# Client clock synchronization
	if not multiplayer.is_server():
		if multiplayer.has_multiplayer_peer():
			sync_timer += delta

			var interval := NORMAL_SYNC_INTERVAL

			if not clock_synchronized:
				interval = INITIAL_SYNC_INTERVAL

			if sync_timer >= interval:
				sync_timer = 0.0
				request_server_time()

func _physics_process(_delta: float) -> void:
	# Activate gameplay at the scheduled server time
	if start_scheduled and not game_active:
		if get_server_time() >= level_start_time:
			activate_game()

func local_time() -> float:
	return Time.get_ticks_usec() / 1000000.0


func get_server_time() -> float:
	if multiplayer.is_server():
		return local_time()

	return local_time() + server_clock_offset


func get_level_time() -> float:
	if not game_active:
		return 0.0

	return maxf(
		0.0,
		get_server_time() - level_start_time
	)


func reset_clock() -> void:
	server_clock_offset = 0.0
	clock_synchronized = false
	best_rtt = INF
	sync_timer = 0.0


func reset_level() -> void:
	game_active = false
	start_scheduled = false
	level_start_time = 0.0
	game_state = GameState.STARTING


# CLIENT -> SERVER
func request_server_time() -> void:
	if multiplayer.is_server():
		return

	if not multiplayer.has_multiplayer_peer():
		return

	receive_time_request.rpc_id(1, local_time())


@rpc("any_peer", "call_remote", "unreliable")
func receive_time_request(client_sent_at: float) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()

	receive_time_response.rpc_id(
		sender,
		client_sent_at,
		local_time()
	)


# SERVER -> CLIENT
@rpc("authority", "call_remote", "unreliable")
func receive_time_response(
	client_sent_at: float,
	server_timestamp: float
) -> void:
	if multiplayer.is_server():
		return

	var received_at := local_time()
	var rtt := received_at - client_sent_at

	if rtt < 0.0:
		return

	# Track the lowest observed round-trip time
	best_rtt = minf(best_rtt, rtt)

	# Ignore unusually delayed samples
	if rtt > best_rtt + MAX_RTT_MARGIN:
		return

	# Estimate server time at response arrival
	var estimated_server_time := server_timestamp + rtt * 0.5
	var measured_offset := estimated_server_time - received_at

	if not clock_synchronized:
		server_clock_offset = measured_offset
		clock_synchronized = true

		clock_sync_completed.emit()

		print(
			"Clock synchronized! RTT: ",
			rtt * 1000.0,
            " ms"
		)
	else:
		server_clock_offset = lerpf(
			server_clock_offset,
			measured_offset,
			CLOCK_SMOOTHING
		)


# SERVER schedules gameplay
func begin_game() -> void:
	if not multiplayer.is_server():
		return

	if start_scheduled or game_active:
		return

	var timestamp := get_server_time() + START_DELAY

	start_game.rpc(timestamp)

@rpc("authority", "call_local", "reliable")
func start_game(start_timestamp: float) -> void :
	if start_scheduled or game_active:
		return
	
	level_start_time = start_timestamp
	start_scheduled = true
	game_active = false
	game_state = GameState.STARTING

	print("Game scheduled for: ", level_start_time)
	
func activate_game() -> void:
	if game_active:
		return

	if not start_scheduled:
		return

	game_active = true
	start_scheduled = false
	game_state = GameState.PLAYING

	game_started.emit()

	print("Game started! Level time: ", get_level_time())
