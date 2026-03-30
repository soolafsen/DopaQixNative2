extends Control

const AudioSynth = preload("res://scripts/audio_synth.gd")

const PROJECT_TITLE := "DopaQiX Native 2"
const SAVE_PATH := "user://progress.cfg"

const TILE_EMPTY := 0
const TILE_SAFE := 1
const TILE_TRAIL := 2

const CELL := 15
const COLS := 80
const ROWS := 60
const BOARD_RECT := Rect2(Vector2.ZERO, Vector2(COLS * CELL, ROWS * CELL))
const CARDINALS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SIDEBAR_GAP := 10.0
const SIDEBAR_WIDTH := 620.0
const BACKGROUND_MANIFEST_PATH := "res://backgrounds/manifest.json"
const MUSIC_ASSET_PATH := "res://assets/audio/zenostar_loop.ogg"
const SLICE_ASSET_PATH := "res://assets/audio/cut_tick.ogg"
const TITLE_LETTERS := [
	{"char": "D", "color": "ff6b8a", "rotation": -7.0, "size": 46},
	{"char": "o", "color": "ffb347", "rotation": 4.0, "size": 44},
	{"char": "p", "color": "ffe066", "rotation": -3.0, "size": 45},
	{"char": "a", "color": "72f1b8", "rotation": 6.0, "size": 43},
	{"char": "Q", "color": "74c0fc", "rotation": -6.0, "size": 47},
	{"char": "i", "color": "c77dff", "rotation": 5.0, "size": 43},
	{"char": "X", "color": "ff8fab", "rotation": -4.0, "size": 46}
]
const TRAIL_RAINBOW := [
	Color("ff5f86"),
	Color("ff9f45"),
	Color("ffe066"),
	Color("72f1b8"),
	Color("74c0fc"),
	Color("c77dff")
]

const MOVE_INTERVAL := 0.07
const SPARK_SPEED := 9.0
const ENEMY_SPEED_MIN := 124.0
const ENEMY_SPEED_MAX := 205.0
const ENEMY_ARM_MIN := 30.0
const ENEMY_ARM_MAX := 72.0
const ENEMY_HISTORY_LENGTH := 7
const SPARK_HISTORY_LENGTH := 6
const ENEMY_RESIDUE_DROP_INTERVAL := 0.055
const ENEMY_RESIDUE_MAX := 180
const ENEMY_RESIDUE_LIFE := 2.4
const START_LIVES := 3
const MAX_LIVES := 5
const START_GOAL := 50
const GOAL_STEP := 3
const GOAL_MAX := 80
const LEVEL_TIME_LIMIT := 180.0
const QIX_TWIN_LEVEL := 10
const SETTING_POOLS := ["random", "aww", "funny", "pinup"]
const DEFAULT_REVEAL_POOL := "aww"

const PICKUP_META := {
	"cookie": {"title": "MUFFIN", "color": "ffd75e", "zone": "field", "duration": 10.0, "good": true},
	"shield": {"title": "SHIELD", "color": "66f5ff", "zone": "field", "duration": 10.0, "good": true},
	"bomb": {"title": "BOMB", "color": "ff537e", "zone": "rail", "duration": 10.0, "good": false},
	"heart": {"title": "HEART", "color": "ffffff", "zone": "rail", "duration": 0.0, "good": true}
}

const THEME_DATA := [
	{
		"name": "Mainline",
		"bg_a": "091019",
		"bg_b": "0d1620",
		"bg_c": "162532",
		"rail": "49ff62",
		"claim_fill": "ffffff00",
		"trail_a": "ff5f86",
		"trail_b": "74c0fc",
		"enemy_core": "fdfdfd"
	}
]

var rng := RandomNumberGenerator.new()

var grid := []
var player := {}
var enemies := []
var sparks := []
var pickups := []
var particles := []
var floaters := []
var enemy_residue := []

var background_paths := []
var background_pools := {"random": [], "aww": [], "funny": [], "pinup": []}
var current_background: Texture2D
var current_background_gray: Texture2D
var current_theme := {}
var grain_texture: Texture2D

var active_effects := {"cookie": 0.0, "shield": 0.0, "bomb": 0.0}
var carry_score := 0
var score := 0
var high_score := 0
var lives := START_LIVES
var level := 1
var capture_percent := 0.0
var capture_goal := START_GOAL
var elapsed_seconds := 0.0
var next_burst_threshold := 10.0
var run_won := false

var state_name := "title"
var state_timer := 0.0
var banner_text := ""
var banner_timer := 0.0
var status_message := ""
var title_phase := 0.0
var danger_level := 0.0
var flash_strength := 0.0
var flash_color := Color.WHITE
var shake_strength := 0.0
var camera_offset := Vector2.ZERO
var rail_pickup_timer := 5.0
var field_pickup_timer := 6.0
var slice_sound_cooldown := 0.0
var shield_block_cooldown := 0.0

var music_enabled := true
var music_volume := 0.7
var speed_setting := 2
var magic_mode := "more"
var reveal_pool := DEFAULT_REVEAL_POOL
var cheat_enabled := false
var music_player: AudioStreamPlayer
var danger_player: AudioStreamPlayer
var sfx_players := []
var sfx_index := 0
var audio_streams := {}
var music_asset_stream: AudioStream
var slice_asset_stream: AudioStream
var pause_button: Button
var resume_button: Button
var exit_button: Button


func _ready() -> void:
	rng.randomize()
	DisplayServer.window_set_title(PROJECT_TITLE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_backgrounds()
	_build_grain_texture()
	_ensure_input_actions()
	_build_audio()
	_build_ui()
	_load_progress()
	_reset_run_state()
	queue_redraw()


func _process(delta: float) -> void:
	title_phase += delta
	state_timer += delta
	banner_timer = max(0.0, banner_timer - delta)
	slice_sound_cooldown = max(0.0, slice_sound_cooldown - delta)
	shield_block_cooldown = max(0.0, shield_block_cooldown - delta)
	if state_name != "level_clear":
		flash_strength = move_toward(flash_strength, 0.0, delta * 1.9)
		shake_strength = move_toward(shake_strength, 0.0, delta * 18.0)
	camera_offset = Vector2.ZERO
	if shake_strength > 0.01:
		camera_offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_strength

	if state_name != "level_clear":
		_update_effects(delta)
	if state_name != "paused":
		_update_particles(delta)
		_update_floaters(delta)
	_update_audio_mix()
	_layout_ui()
	_refresh_ui()

	match state_name:
		"title":
			if Input.is_action_just_pressed("accept"):
				_start_game()
		"paused":
			pass
		"death":
			if state_timer >= 1.0:
				if lives > 0:
					_respawn_after_death()
				else:
					_enter_game_over(false)
		"level_clear":
			pass
		"game_over":
			if Input.is_action_just_pressed("accept"):
				_start_game()
		_:
			var danger := 0.0
			if state_name == "playing":
				elapsed_seconds = min(LEVEL_TIME_LIMIT, elapsed_seconds + delta)
				if elapsed_seconds >= LEVEL_TIME_LIMIT:
					_recompute_score()
					_lose_life("Time ran out.")
					queue_redraw()
					return
			_update_player(delta)
			if state_name == "playing":
				danger = max(danger, _update_enemies(delta))
			if state_name == "playing":
				danger = max(danger, _update_sparks(delta))
			if state_name == "playing":
				_update_pickups(delta)
			_update_enemy_residue(delta)
			if state_name == "playing":
				_recompute_score()
			var blend_speed := 8.0 if danger > danger_level else 4.0
			danger_level = lerpf(danger_level, danger, min(1.0, delta * blend_speed))

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _options_visible() and _handle_option_click(event.position):
			return
		if state_name == "title" and _board_rect().has_point(event.position):
			_start_game()
			return
		if state_name == "level_clear":
			_advance_after_level_clear()
			return
	if state_name == "level_clear" and _is_level_clear_continue_event(event):
		_advance_after_level_clear()
		return
	if event.is_action_pressed("pause"):
		if state_name in ["playing", "paused"]:
			_toggle_pause()
	elif event.is_action_pressed("exit_game"):
		_on_exit_button_pressed()
	elif event.is_action_pressed("toggle_music"):
		music_enabled = not music_enabled
		_save_progress()
		_update_audio_mix()


func _toggle_pause() -> void:
	if state_name == "playing":
		state_name = "paused"
		status_message = ""
		_play_sfx("spark")
	elif state_name == "paused":
		state_name = "playing"
		status_message = ""
		_play_sfx("start")
	state_timer = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_ui()


func _exit_tree() -> void:
	_release_audio_resources()


func _release_audio_resources() -> void:
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	if danger_player != null:
		danger_player.stop()
		danger_player.stream = null
	for player_node in sfx_players:
		if player_node != null:
			player_node.stop()
			player_node.stream = null
	audio_streams.clear()
	music_asset_stream = null
	slice_asset_stream = null


func _current_level_score_slice() -> int:
	return maxi(0, level * 100 + int(floor(capture_percent * 100.0)) - int(floor(elapsed_seconds)))


func _recompute_score() -> void:
	score = carry_score + _current_level_score_slice()
	high_score = maxi(high_score, score)


func _reset_burst_threshold() -> void:
	next_burst_threshold = maxi(10.0, ceil(capture_percent / 10.0) * 10.0)


func _trigger_burst_thresholds(_previous_percent: float, current_percent: float) -> void:
	if current_percent < next_burst_threshold:
		return
	while current_percent >= next_burst_threshold:
		next_burst_threshold += 10.0
	var refreshed := []
	for index in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		_spawn_particles(Vector2(enemy["x"], enemy["y"]), Color.from_hsv(enemy["hue"], 0.65, 1.0), 12, 170.0, 0.45, 2.6)
		refreshed.append(_create_enemy(_enemy_spawn_position(index, enemies.size())))
	enemies = refreshed


func _start_game() -> void:
	carry_score = 0
	score = 0
	lives = START_LIVES
	run_won = false
	elapsed_seconds = 0.0
	level = 0
	_start_level(1)
	_play_sfx("start")


func _reset_run_state() -> void:
	carry_score = 0
	score = 0
	lives = START_LIVES
	level = 1
	run_won = false
	elapsed_seconds = 0.0
	status_message = ""
	state_name = "title"
	state_timer = 0.0
	banner_text = "Hold the rail. Cut in. Claim hard."
	banner_timer = 999.0
	_start_level_data(1)


func _start_level(level_number: int) -> void:
	level = level_number
	state_name = "playing"
	_start_level_data(level)
	state_timer = 0.0
	banner_text = "LEVEL %02d  |  GOAL %d%%" % [level, capture_goal]
	banner_timer = 1.7
	status_message = ""
	_flash(Color("8fefff"), 0.18)
	_shake(3.0)


func _start_level_data(level_number: int) -> void:
	capture_goal = min(START_GOAL + (level_number - 1) * GOAL_STEP, GOAL_MAX)
	current_theme = _theme_for_level(level_number)
	_assign_background_texture(_pick_background_texture())
	_refresh_music_streams()
	active_effects = {"cookie": 0.0, "shield": 0.0, "bomb": 0.0}
	rail_pickup_timer = _roll_pickup_timer(1.75, 3.25)
	field_pickup_timer = _roll_pickup_timer(2.8, 6.0)
	_init_grid()
	_spawn_player()
	_spawn_enemies()
	_spawn_sparks()
	pickups.clear()
	particles.clear()
	floaters.clear()
	enemy_residue.clear()
	capture_percent = _compute_capture_percent()
	_reset_burst_threshold()
	_recompute_score()
	danger_level = 0.0


func _respawn_after_death() -> void:
	_spawn_player()
	_spawn_enemies()
	_spawn_sparks()
	pickups.clear()
	enemy_residue.clear()
	state_name = "playing"
	state_timer = 0.0
	status_message = ""
	banner_text = "READY"
	banner_timer = 1.0


func _enter_game_over(won: bool) -> void:
	run_won = won
	state_name = "game_over"
	state_timer = 0.0
	if won:
		banner_text = "BOARD DOMINATED"
		banner_timer = 2.6
		_play_sfx("level_clear")
	else:
		_play_sfx("game_over")
	_recompute_score()
	_save_progress()


func _init_grid() -> void:
	grid.clear()
	for row in range(ROWS):
		var line := []
		for col in range(COLS):
			if row == 0 or row == ROWS - 1 or col == 0 or col == COLS - 1:
				line.append(TILE_SAFE)
			else:
				line.append(TILE_EMPTY)
		grid.append(line)


func _spawn_player() -> void:
	var start_row := ROWS / 2
	player = {
		"col": 0,
		"row": start_row,
		"dir": Vector2i.RIGHT,
		"desired_dir": Vector2i.RIGHT,
		"drawing": false,
		"trail": [],
		"trail_keys": {},
		"move_clock": 0.0,
		"history": []
	}
	_record_player_history()


func _spawn_enemies() -> void:
	enemies.clear()
	var count := 2 if level >= QIX_TWIN_LEVEL else 1
	for index in range(count):
		enemies.append(_create_enemy(_enemy_spawn_position(index, count)))


func _spawn_sparks() -> void:
	sparks.clear()
	var positions := [
		{"col": 0, "row": 0, "dir": Vector2i.RIGHT, "turn_bias": 1},
		{"col": COLS - 1, "row": 0, "dir": Vector2i.LEFT, "turn_bias": -1}
	]
	for index in range(positions.size()):
		var seed = positions[index]
		sparks.append(
			{
				"col": seed["col"],
				"row": seed["row"],
				"dir": seed["dir"],
				"turn_bias": seed["turn_bias"],
				"progress": 0.0,
				"effect_kind": "",
				"effect_time": 0.0,
				"history": [{"col": seed["col"], "row": seed["row"]}]
			}
		)


func _enemy_spawn_position(index: int, total: int) -> Vector2:
	if total <= 1 or index == 0:
		return _empty_spawn_position(_cell_center(COLS - 2, 1))
	return _empty_spawn_position(_cell_center(1, ROWS - 2))


func _create_enemy(spawn: Vector2) -> Dictionary:
	var angle := rng.randf_range(0.0, TAU)
	var speed := rng.randf_range(ENEMY_SPEED_MIN, ENEMY_SPEED_MAX)
	return {
		"x": spawn.x,
		"y": spawn.y,
		"vx": cos(angle) * speed,
		"vy": sin(angle) * speed,
		"angle": rng.randf_range(0.0, TAU),
		"spin": rng.randf_range(1.6, 2.8) * (-1.0 if rng.randf() < 0.5 else 1.0),
		"arm_a": rng.randf_range(ENEMY_ARM_MIN, ENEMY_ARM_MAX),
		"arm_b": rng.randf_range(ENEMY_ARM_MIN, ENEMY_ARM_MAX),
		"hue": rng.randf(),
		"history": [{"x": spawn.x, "y": spawn.y, "angle": rng.randf_range(0.0, TAU)}],
		"residue_clock": 0.0
	}


func _empty_spawn_position(preferred: Vector2) -> Vector2:
	var preferred_cell := _nearest_empty_cell(preferred)
	if not preferred_cell.is_empty():
		return _cell_center(preferred_cell["col"], preferred_cell["row"])
	var empty_cells := []
	for row in range(1, ROWS - 1):
		for col in range(1, COLS - 1):
			if grid[row][col] == TILE_EMPTY:
				empty_cells.append({"col": col, "row": row})
	if empty_cells.is_empty():
		return preferred
	var choice = empty_cells[rng.randi_range(0, empty_cells.size() - 1)]
	return _cell_center(choice["col"], choice["row"])


func _update_player(delta: float) -> void:
	if state_name != "playing":
		return

	player["desired_dir"] = _read_input_direction(player["desired_dir"])
	player["move_clock"] += delta
	var scale := _player_speed_scale()
	if _effect_active("cookie"):
		scale *= 1.75
	if _effect_active("bomb"):
		scale *= 0.5
	if player["drawing"] and Input.is_action_pressed("boost_cut"):
		scale *= 1.85
	var interval := MOVE_INTERVAL / scale

	while player["move_clock"] >= interval and state_name == "playing":
		player["move_clock"] -= interval
		if not _step_player():
			break


func _read_input_direction(fallback: Vector2i) -> Vector2i:
	if Input.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	if Input.is_action_pressed("move_up"):
		return Vector2i.UP
	if Input.is_action_pressed("move_down"):
		return Vector2i.DOWN
	return fallback


func _step_player() -> bool:
	var desired: Vector2i = player["desired_dir"]
	var current: Vector2i = player["dir"]
	if desired != Vector2i.ZERO and _can_move(desired):
		current = desired
	elif not _can_move(current):
		return false

	var next_col: int = int(player["col"]) + current.x
	var next_row: int = int(player["row"]) + current.y
	var next_tile: int = int(grid[next_row][next_col])
	var next_key := _tile_key(next_col, next_row)
	player["dir"] = current

	if player["drawing"]:
		if next_key in player["trail_keys"]:
			_lose_life("You crossed your own cut.")
			return false
		if next_tile == TILE_SAFE:
			player["col"] = next_col
			player["row"] = next_row
			_record_player_history()
			_finish_trail()
			return true
		if next_tile == TILE_EMPTY:
			player["col"] = next_col
			player["row"] = next_row
			grid[next_row][next_col] = TILE_TRAIL
			player["trail"].append({"col": next_col, "row": next_row})
			player["trail_keys"][next_key] = true
			_record_player_history()
			_on_player_slice()
			return true
		return false

	if next_tile == TILE_SAFE:
		if not _is_rail_tile(next_col, next_row):
			return false
		player["col"] = next_col
		player["row"] = next_row
		_record_player_history()
		return true
	if next_tile == TILE_EMPTY:
		if not _is_rail_tile(int(player["col"]), int(player["row"])):
			return false
		player["drawing"] = true
		player["col"] = next_col
		player["row"] = next_row
		grid[next_row][next_col] = TILE_TRAIL
		player["trail"] = [{"col": next_col, "row": next_row}]
		player["trail_keys"] = {next_key: true}
		_record_player_history()
		_on_player_slice()
		return true
	return false


func _can_move(direction: Vector2i) -> bool:
	var next_col: int = int(player["col"]) + direction.x
	var next_row: int = int(player["row"]) + direction.y
	if not _inside(next_col, next_row):
		return false
	var next_tile: int = int(grid[next_row][next_col])
	if player["drawing"]:
		return next_tile == TILE_EMPTY or next_tile == TILE_SAFE
	if next_tile == TILE_SAFE:
		return _is_rail_tile(next_col, next_row)
	if next_tile == TILE_EMPTY:
		return _is_rail_tile(int(player["col"]), int(player["row"]))
	return false


func _is_rail_tile(col: int, row: int) -> bool:
	if not _inside(col, row) or grid[row][col] != TILE_SAFE:
		return false
	for row_offset in range(-1, 2):
		for col_offset in range(-1, 2):
			if row_offset == 0 and col_offset == 0:
				continue
			var neighbor_col := col + col_offset
			var neighbor_row := row + row_offset
			if not _inside(neighbor_col, neighbor_row):
				return true
			if grid[neighbor_row][neighbor_col] != TILE_SAFE:
				return true
	return false


func _on_player_slice() -> void:
	if slice_sound_cooldown <= 0.0:
		_play_sfx("slice")
		slice_sound_cooldown = 0.06
	var pos := _player_position()
	_spawn_particles(pos, _trail_color(), 4, 90.0, 0.24, 2.4)


func _finish_trail() -> void:
	for point in player["trail"]:
		grid[point["row"]][point["col"]] = TILE_SAFE
	var previous_percent := capture_percent
	var claimed := _claim_enclosed_area()
	_reset_trapped_sparks()
	player["drawing"] = false
	player["trail"].clear()
	player["trail_keys"].clear()
	capture_percent = _compute_capture_percent()
	_trigger_burst_thresholds(previous_percent, capture_percent)
	_recompute_score()
	if claimed > 0:
		_flash(_theme_color("trail_b"), 0.24)
		_shake(min(12.0, 4.0 + claimed / 18.0))
		_spawn_capture_fx(claimed)
		_float_text(_player_position(), "%d%% CLAIMED" % int(capture_percent), _theme_color("trail_a"))
		_play_sfx("capture")

	if capture_percent >= capture_goal:
		lives = min(MAX_LIVES, lives + 1)
		state_name = "level_clear"
		state_timer = 0.0
		active_effects = {"cookie": 0.0, "shield": 0.0, "bomb": 0.0}
		flash_strength = 0.0
		shake_strength = 0.0
		camera_offset = Vector2.ZERO
		banner_text = "LEVEL %02d DETONATED" % level
		banner_timer = 999.0
		_play_sfx("level_clear")


func _claim_enclosed_area() -> int:
	var reachable := []
	for row in range(ROWS):
		var line := []
		for _col in range(COLS):
			line.append(false)
		reachable.append(line)

	var queue := []
	for enemy in enemies:
		for sample in _enemy_sample_cells(enemy):
			if _inside(sample["col"], sample["row"]) and grid[sample["row"]][sample["col"]] == TILE_EMPTY and not reachable[sample["row"]][sample["col"]]:
				reachable[sample["row"]][sample["col"]] = true
				queue.append(sample)

	var cursor := 0
	while cursor < queue.size():
		var current = queue[cursor]
		cursor += 1
		for dir in CARDINALS:
			var nc: int = int(current["col"]) + dir.x
			var nr: int = int(current["row"]) + dir.y
			if _inside(nc, nr) and not reachable[nr][nc] and grid[nr][nc] == TILE_EMPTY:
				reachable[nr][nc] = true
				queue.append({"col": nc, "row": nr})

	var claimed := 0
	var trapped_indices := []
	for index in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		var trapped := true
		for sample in _enemy_occupied_cells(enemy):
			if reachable[sample["row"]][sample["col"]]:
				trapped = false
				break
		if trapped:
			trapped_indices.append(index)
	for row in range(1, ROWS - 1):
		for col in range(1, COLS - 1):
			if grid[row][col] == TILE_EMPTY and not reachable[row][col]:
				grid[row][col] = TILE_SAFE
				claimed += 1
	for index in trapped_indices:
		var enemy: Dictionary = enemies[index]
		enemies[index] = _create_enemy(_empty_spawn_position(Vector2(enemy["x"], enemy["y"])))
	return claimed


func _enemy_sample_cells(enemy: Dictionary) -> Array:
	var samples := []
	for cell in _enemy_occupied_cells(enemy):
		var nearest := _nearest_empty_cell(_cell_center(cell["col"], cell["row"]))
		if not nearest.is_empty():
			samples.append(nearest)
	return samples


func _enemy_occupied_cells(enemy: Dictionary) -> Array:
	var cells := []
	var seen := {}
	var segments := _qix_segments(enemy)
	var points := [
		Vector2(enemy["x"], enemy["y"]),
		segments[0]["a"],
		segments[0]["b"],
		segments[1]["a"],
		segments[1]["b"]
	]
	for point in points:
		var cell := _point_to_cell(point)
		var key := _tile_key(cell["col"], cell["row"])
		if key in seen:
			continue
		seen[key] = true
		cells.append(cell)
	return cells


func _nearest_empty_cell(point: Vector2) -> Dictionary:
	var board := _board_rect()
	var col: int = clamp(int((point.x - board.position.x) / CELL), 1, COLS - 2)
	var row: int = clamp(int((point.y - board.position.y) / CELL), 1, ROWS - 2)
	if grid[row][col] == TILE_EMPTY:
		return {"col": col, "row": row}
	for radius in range(1, 4):
		for y in range(row - radius, row + radius + 1):
			for x in range(col - radius, col + radius + 1):
				if _inside(x, y) and grid[y][x] == TILE_EMPTY:
					return {"col": x, "row": y}
	return {}


func _update_enemies(delta: float) -> float:
	var max_danger := 0.0
	for enemy in enemies:
		var speed_mult: float = (1.0 + capture_percent * 0.006) * (1.0 + maxi(0, level - 1) * 0.08) * _player_speed_scale() * _enemy_speed_scale()

		var next_x: float = float(enemy["x"]) + float(enemy["vx"]) * speed_mult * delta
		var next_y: float = float(enemy["y"]) + float(enemy["vy"]) * speed_mult * delta
		enemy["angle"] += enemy["spin"] * delta
		enemy["hue"] = fmod(enemy["hue"] + delta * 0.1, 1.0)
		enemy["residue_clock"] += delta

		if _position_hits_barrier(Vector2(next_x, enemy["y"])):
			enemy["vx"] *= -1.0
			next_x = enemy["x"] + enemy["vx"] * speed_mult * delta
		if _position_hits_barrier(Vector2(enemy["x"], next_y)):
			enemy["vy"] *= -1.0
			next_y = enemy["y"] + enemy["vy"] * speed_mult * delta

		enemy["x"] = next_x
		enemy["y"] = next_y
		enemy["history"].push_front({"x": next_x, "y": next_y, "angle": enemy["angle"]})
		while enemy["history"].size() > ENEMY_HISTORY_LENGTH:
			enemy["history"].pop_back()
		while enemy["residue_clock"] >= ENEMY_RESIDUE_DROP_INTERVAL:
			enemy["residue_clock"] -= ENEMY_RESIDUE_DROP_INTERVAL
			_drop_enemy_residue(enemy)

		var enemy_cell := _point_to_cell(Vector2(enemy["x"], enemy["y"]))
		if player["drawing"] and (grid[enemy_cell["row"]][enemy_cell["col"]] == TILE_TRAIL or _enemy_hits_trail(enemy)):
			_lose_life("A QiX tore through your cut.")
			return 1.0

		var distance: float = _player_position().distance_to(Vector2(enemy["x"], enemy["y"]))
		var enemy_danger: float = clamp((280.0 - distance) / 220.0, 0.0, 1.0)
		max_danger = max(max_danger, enemy_danger * (1.14 if player["drawing"] else 1.0))
		if distance < CELL * 0.7 and player["drawing"]:
			_lose_life("The QiX core caught you.")
			return 1.0
	if player["drawing"] and _enemy_residue_at(int(player["col"]), int(player["row"])):
		_lose_life("The QiX residue burned through you.")
		return 1.0
	if _residue_hits_trail():
		_lose_life("A QiX residue cloud ate your cut.")
		return 1.0
	return max_danger


func _position_hits_barrier(point: Vector2) -> bool:
	var board := _board_rect()
	if not board.has_point(point):
		return true
	var col: int = clamp(int((point.x - board.position.x) / CELL), 0, COLS - 1)
	var row: int = clamp(int((point.y - board.position.y) / CELL), 0, ROWS - 1)
	return grid[row][col] != TILE_EMPTY


func _enemy_hits_trail(enemy: Dictionary) -> bool:
	if player["trail"].is_empty():
		return false
	var segments := _qix_segments(enemy)
	for point in player["trail"]:
		var pos := _cell_center(point["col"], point["row"])
		for segment in segments:
			if _distance_to_segment(pos, segment["a"], segment["b"]) <= CELL * 0.46:
				return true
	return false


func _qix_segments(enemy: Dictionary) -> Array:
	var angle: float = float(enemy["angle"])
	var a_dir := Vector2(cos(angle), sin(angle))
	var b_dir := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5))
	var center := Vector2(enemy["x"], enemy["y"])
	return [
		{"a": center - a_dir * enemy["arm_a"], "b": center + a_dir * enemy["arm_a"]},
		{"a": center - b_dir * enemy["arm_b"], "b": center + b_dir * enemy["arm_b"]}
	]


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	var denom := ab.length_squared()
	if denom > 0.001:
		t = clamp((point - a).dot(ab) / denom, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _update_sparks(delta: float) -> float:
	var max_danger := 0.0
	var distances := _build_spark_distance_map(_spark_targets())
	var sim_delta: float = min(delta, 0.05)
	for spark in sparks:
		var spark_effect := str(spark.get("effect_kind", ""))
		var speed := SPARK_SPEED * _player_speed_scale() * _enemy_speed_scale()
		if spark_effect == "cookie":
			speed *= 1.75
		elif spark_effect == "bomb":
			speed *= 0.5
		spark["progress"] += sim_delta * speed
		while spark["progress"] >= 1.0:
			spark["progress"] -= 1.0
			var next = _choose_spark_step(spark, distances)
			var next_dir := Vector2i(next["col"] - spark["col"], next["row"] - spark["row"])
			if next_dir != Vector2i.ZERO:
				spark["dir"] = next_dir
			spark["col"] = next["col"]
			spark["row"] = next["row"]
			spark["history"].push_front({"col": spark["col"], "row": spark["row"]})
			while spark["history"].size() > 6:
				spark["history"].pop_back()

		var distance: int = abs(int(spark["col"]) - int(player["col"])) + abs(int(spark["row"]) - int(player["row"]))
		max_danger = max(max_danger, clamp((15.0 - distance) / 11.0, 0.0, 1.0))
	return max_danger


func _spark_targets() -> Array:
	var targets := []
	if player["drawing"] and _is_spark_tile(player["col"], player["row"]):
		targets.append({"col": player["col"], "row": player["row"]})
		return targets
	var nearby_rail := [
		{"col": player["col"], "row": player["row"]},
		{"col": int(player["col"]) + 1, "row": player["row"]},
		{"col": int(player["col"]) - 1, "row": player["row"]},
		{"col": player["col"], "row": int(player["row"]) + 1},
		{"col": player["col"], "row": int(player["row"]) - 1}
	]
	for cell in nearby_rail:
		if _is_spark_tile(cell["col"], cell["row"]):
			targets.append(cell)
	if not targets.is_empty():
		return targets
	if not player["trail"].is_empty():
		var head = player["trail"][0]
		for dir in CARDINALS:
			var nc: int = int(head["col"]) + dir.x
			var nr: int = int(head["row"]) + dir.y
			if _is_spark_tile(nc, nr):
				targets.append({"col": nc, "row": nr})
	if targets.is_empty():
		for spark in sparks:
			targets.append({"col": spark["col"], "row": spark["row"]})
	return targets


func _build_spark_distance_map(targets: Array) -> Array:
	var distances := []
	for row in range(ROWS):
		var line := []
		for _col in range(COLS):
			line.append(999999)
		distances.append(line)

	var queue := []
	for target in targets:
		if _is_spark_tile(target["col"], target["row"]):
			distances[target["row"]][target["col"]] = 0
			queue.append(target)

	var cursor := 0
	while cursor < queue.size():
		var current = queue[cursor]
		cursor += 1
		var base: int = int(distances[current["row"]][current["col"]]) + 1
		for neighbor in _spark_neighbors(current["col"], current["row"]):
			if base < distances[neighbor["row"]][neighbor["col"]]:
				distances[neighbor["row"]][neighbor["col"]] = base
				queue.append(neighbor)
	return distances


func _spark_neighbors(col: int, row: int) -> Array:
	var neighbors := []
	for dir in CARDINALS:
		var nc: int = col + dir.x
		var nr: int = row + dir.y
		if _is_spark_tile(nc, nr):
			neighbors.append({"col": nc, "row": nr})
	return neighbors


func _choose_spark_step(spark: Dictionary, distances: Array) -> Dictionary:
	var neighbors := _spark_neighbors(spark["col"], spark["row"])
	if not neighbors.is_empty():
		var best_distance := 999999
		for neighbor in neighbors:
			best_distance = min(best_distance, int(distances[neighbor["row"]][neighbor["col"]]))
		if best_distance < 999999:
			var best_neighbors := []
			for neighbor in neighbors:
				if int(distances[neighbor["row"]][neighbor["col"]]) == best_distance:
					best_neighbors.append(neighbor)
			for neighbor in best_neighbors:
				var dir := Vector2i(neighbor["col"] - spark["col"], neighbor["row"] - spark["row"])
				if dir == spark["dir"]:
					return neighbor
			return best_neighbors[0]

	var forward := {"col": spark["col"] + spark["dir"].x, "row": spark["row"] + spark["dir"].y}
	var turn_primary_dir := _rotate_direction(spark["dir"], int(spark.get("turn_bias", 1)))
	var primary := {"col": spark["col"] + turn_primary_dir.x, "row": spark["row"] + turn_primary_dir.y}
	var turn_secondary_dir := _rotate_direction(spark["dir"], -int(spark.get("turn_bias", 1)))
	var secondary := {"col": spark["col"] + turn_secondary_dir.x, "row": spark["row"] + turn_secondary_dir.y}
	var back := {"col": spark["col"] - spark["dir"].x, "row": spark["row"] - spark["dir"].y}
	for option in [forward, primary, secondary, back]:
		if _is_spark_tile(option["col"], option["row"]):
			return option

	var escape := {}
	var best_degree := -1
	for neighbor in neighbors:
		var degree := _spark_neighbors(neighbor["col"], neighbor["row"]).size()
		if degree > best_degree:
			best_degree = degree
			escape = neighbor
	if not escape.is_empty():
		return escape
	return {"col": spark["col"], "row": spark["row"]}


func _rotate_direction(dir: Vector2i, turn_bias: int) -> Vector2i:
	if turn_bias > 0:
		return Vector2i(-dir.y, dir.x)
	return Vector2i(dir.y, -dir.x)


func _is_spark_tile(col: int, row: int) -> bool:
	if not _inside(col, row):
		return false
	return grid[row][col] == TILE_TRAIL or _is_rail_tile(col, row)


func _build_corner_rail_reachable() -> Array:
	var reachable := []
	for row in range(ROWS):
		var line := []
		for _col in range(COLS):
			line.append(false)
		reachable.append(line)

	var seeds := []
	for cell in [{"col": 0, "row": 0}, {"col": COLS - 1, "row": 0}]:
		if _is_rail_tile(cell["col"], cell["row"]):
			reachable[cell["row"]][cell["col"]] = true
			seeds.append(cell)

	var cursor := 0
	while cursor < seeds.size():
		var current = seeds[cursor]
		cursor += 1
		for neighbor in _spark_neighbors(current["col"], current["row"]):
			if reachable[neighbor["row"]][neighbor["col"]]:
				continue
			if not _is_rail_tile(neighbor["col"], neighbor["row"]):
				continue
			reachable[neighbor["row"]][neighbor["col"]] = true
			seeds.append(neighbor)
	return reachable


func _reset_trapped_sparks() -> void:
	var corner_reachable := _build_corner_rail_reachable()
	for spark in sparks:
		if not _is_spark_tile(spark["col"], spark["row"]):
			_spawn_sparks()
			return
		if not corner_reachable[spark["row"]][spark["col"]]:
			_spawn_sparks()
			return


func _player_hits_pickup(pickup: Dictionary) -> bool:
	var dx: int = abs(int(pickup["col"]) - int(player["col"]))
	var dy: int = abs(int(pickup["row"]) - int(player["row"]))
	if pickup["kind"] == "cookie" or pickup["kind"] == "shield":
		return dx <= 1 and dy <= 1
	return dx == 0 and dy == 0


func _update_pickups(delta: float) -> void:
	rail_pickup_timer -= delta
	field_pickup_timer -= delta
	if rail_pickup_timer <= 0.0:
		_spawn_rail_pickup()
	if field_pickup_timer <= 0.0:
		_spawn_field_pickup()

	var survivors := []
	for pickup in pickups:
		pickup["life"] -= delta
		pickup["wobble"] += delta * 4.0
		if pickup["life"] <= 0.0:
			continue
		if pickup["zone"] == "rail" and not _is_rail_tile(pickup["col"], pickup["row"]):
			continue
		if pickup["zone"] == "field" and grid[pickup["row"]][pickup["col"]] != TILE_EMPTY and grid[pickup["row"]][pickup["col"]] != TILE_TRAIL:
			continue
		if _player_hits_pickup(pickup):
			_collect_pickup(pickup)
			continue
		if pickup["zone"] == "rail" and pickup["kind"] != "heart":
			var spark_hit := false
			for spark in sparks:
				if spark["col"] == pickup["col"] and spark["row"] == pickup["row"]:
					spark["effect_kind"] = pickup["kind"]
					spark["effect_time"] = PICKUP_META[pickup["kind"]]["duration"]
					spark_hit = true
			if spark_hit:
				continue
		survivors.append(pickup)
	pickups = survivors


func _spawn_rail_pickup() -> void:
	rail_pickup_timer = _roll_pickup_timer(1.75, 3.25)
	if _count_pickups_for_zone("rail") >= 2:
		return
	var cell = _random_safe_pickup_cell()
	if cell.is_empty():
		return
	var kind := "bomb"
	if lives < MAX_LIVES and (int(level + pickups.size()) % 3 == 0 or rng.randf() < 0.2):
		kind = "heart"
	var meta = PICKUP_META[kind]
	pickups.append(
		{
			"kind": kind,
			"col": cell["col"],
			"row": cell["row"],
			"life": 15.0,
			"wobble": rng.randf_range(0.0, TAU),
			"zone": meta["zone"]
		}
	)


func _spawn_field_pickup() -> void:
	field_pickup_timer = _roll_pickup_timer(2.8, 6.0)
	var field_cookies := 0
	var field_shields := 0
	for pickup in pickups:
		if pickup["zone"] != "field":
			continue
		if pickup["kind"] == "cookie":
			field_cookies += 1
		elif pickup["kind"] == "shield":
			field_shields += 1
	if field_cookies >= 2 and field_shields >= 1:
		return
	var cell = _random_empty_field_cell()
	if cell.is_empty():
		return
	var kind := "cookie"
	if field_shields < 1 and rng.randf() < 0.33:
		kind = "shield"
	elif field_cookies >= 2:
		kind = "shield"
	var meta = PICKUP_META[kind]
	pickups.append(
		{
			"kind": kind,
			"col": cell["col"],
			"row": cell["row"],
			"life": 19.0 if kind == "cookie" else 15.0,
			"wobble": rng.randf_range(0.0, TAU),
			"zone": meta["zone"]
		}
	)


func _count_pickups_for_zone(zone: String) -> int:
	var count := 0
	for pickup in pickups:
		if pickup["zone"] == zone:
			count += 1
	return count


func _random_safe_pickup_cell() -> Dictionary:
	for _attempt in range(48):
		var col := rng.randi_range(0, COLS - 1)
		var row := rng.randi_range(0, ROWS - 1)
		if not _is_rail_tile(col, row):
			continue
		if abs(col - player["col"]) + abs(row - player["row"]) < 8:
			continue
		var blocked := false
		for pickup in pickups:
			if pickup["col"] == col and pickup["row"] == row:
				blocked = true
				break
		if blocked:
			continue
		var occupied := false
		for spark in sparks:
			if spark["col"] == col and spark["row"] == row:
				occupied = true
				break
		if occupied:
			continue
		return {"col": col, "row": row}
	return {}


func _random_empty_field_cell() -> Dictionary:
	for _attempt in range(64):
		var col := rng.randi_range(1, COLS - 2)
		var row := rng.randi_range(1, ROWS - 2)
		if grid[row][col] != TILE_EMPTY:
			continue
		if abs(col - player["col"]) + abs(row - player["row"]) < 4:
			continue
		var blocked := false
		for pickup in pickups:
			if pickup["col"] == col and pickup["row"] == row:
				blocked = true
				break
		if blocked:
			continue
		return {"col": col, "row": row}
	return {}


func _collect_pickup(pickup: Dictionary) -> void:
	var kind: String = pickup["kind"]
	var meta = PICKUP_META[kind]
	var color := Color(meta["color"])
	_spawn_particles(_cell_center(pickup["col"], pickup["row"]), color, 20, 190.0, 0.55, 4.0)
	_float_text(_cell_center(pickup["col"], pickup["row"]), meta["title"], color)
	_flash(color, 0.18)
	_shake(5.0 if meta["good"] else 7.0)
	if kind == "heart":
		lives = min(MAX_LIVES, lives + 1)
		_play_sfx("pickup_good")
		return
	if kind == "shield":
		active_effects["shield"] = meta["duration"]
		_play_sfx("shield")
		return
	active_effects[kind] = meta["duration"]
	_play_sfx("pickup_good" if meta["good"] else "pickup_bad")


func _update_effects(delta: float) -> void:
	for key in active_effects.keys():
		active_effects[key] = max(0.0, active_effects[key] - delta)
	for spark in sparks:
		spark["effect_time"] = max(0.0, float(spark.get("effect_time", 0.0)) - delta)
		if spark["effect_time"] <= 0.0:
			spark["effect_kind"] = ""


func _effect_active(kind: String) -> bool:
	return active_effects.get(kind, 0.0) > 0.0


func _lose_life(reason: String) -> void:
	if state_name != "playing":
		return
	if _effect_active("shield"):
		if shield_block_cooldown <= 0.0:
			_float_text(_player_position(), "SHIELDED", Color("8fefff"))
			_spawn_particles(_player_position(), Color("8fefff"), 24, 220.0, 0.5, 3.6)
			_flash(Color("8fefff"), 0.16)
			_shake(6.0)
			_play_sfx("shield")
			shield_block_cooldown = 0.2
		return

	_clear_trail()
	active_effects = {"cookie": 0.0, "shield": 0.0, "bomb": 0.0}
	lives -= 1
	state_name = "death"
	state_timer = 0.0
	status_message = reason
	_flash(Color("ff5252"), 0.32)
	_shake(10.0)
	_spawn_particles(_player_position(), Color("ff8b8b"), 28, 240.0, 0.62, 3.8)
	_float_text(_player_position(), "CRASH", Color("fff4c3"))
	_play_sfx("hit")


func _clear_trail() -> void:
	var reset_sparks := false
	for spark in sparks:
		if _inside(spark["col"], spark["row"]) and grid[spark["row"]][spark["col"]] == TILE_TRAIL:
			reset_sparks = true
			break
	for point in player["trail"]:
		if grid[point["row"]][point["col"]] == TILE_TRAIL:
			grid[point["row"]][point["col"]] = TILE_EMPTY
	player["drawing"] = false
	player["trail"].clear()
	player["trail_keys"].clear()
	if reset_sparks:
		_spawn_sparks()


func _spawn_capture_fx(claimed: int) -> void:
	var bursts: int = min(42, 10 + claimed / 9)
	for _index in range(bursts):
		var col := rng.randi_range(1, COLS - 2)
		var row := rng.randi_range(1, ROWS - 2)
		if grid[row][col] != TILE_SAFE:
			continue
		var point := _cell_center(col, row)
		_spawn_particles(point, _theme_color("trail_b"), 4, 130.0, 0.42, 3.0)
		_spawn_particles(point, Color.WHITE, 2, 90.0, 0.3, 2.0)


func _spawn_particles(position: Vector2, color: Color, amount: int, speed: float, life: float, size: float) -> void:
	for _index in range(amount):
		var direction := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		var burst := speed * rng.randf_range(0.2, 1.0)
		particles.append(
			{
				"pos": position,
				"vel": direction * burst,
				"life": life * rng.randf_range(0.7, 1.2),
				"max_life": life,
				"color": color,
				"size": size * rng.randf_range(0.7, 1.3)
			}
		)


func _float_text(position: Vector2, text: String, color: Color) -> void:
	floaters.append(
		{
			"pos": position,
			"text": text,
			"color": color,
			"life": 1.0,
			"max_life": 1.0
		}
	)


func _update_particles(delta: float) -> void:
	var survivors := []
	for particle in particles:
		particle["life"] -= delta
		if particle["life"] <= 0.0:
			continue
		particle["pos"] += particle["vel"] * delta
		particle["vel"] *= max(0.0, 1.0 - delta * 2.8)
		survivors.append(particle)
	particles = survivors


func _update_floaters(delta: float) -> void:
	var survivors := []
	for floater in floaters:
		floater["life"] -= delta
		if floater["life"] <= 0.0:
			continue
		floater["pos"] += Vector2(0.0, -34.0) * delta
		survivors.append(floater)
	floaters = survivors


func _drop_enemy_residue(enemy: Dictionary) -> void:
	var points := [{"point": Vector2(enemy["x"], enemy["y"]), "intensity": 0.74}]
	var segments := _qix_segments(enemy)
	var board := _board_rect()
	for segment in segments:
		points.append({"point": segment["a"], "intensity": 0.52})
		points.append({"point": segment["b"], "intensity": 0.52})
	var seen := {}
	for sample in points:
		var point: Vector2 = sample["point"]
		var col: int = clamp(int((point.x - board.position.x) / CELL), 1, COLS - 2)
		var row: int = clamp(int((point.y - board.position.y) / CELL), 1, ROWS - 2)
		var key := _tile_key(col, row)
		if seen.has(key):
			continue
		seen[key] = true
		if grid[row][col] != TILE_EMPTY:
			continue
		var existing := _enemy_residue_at(col, row)
		if existing.is_empty():
			enemy_residue.append(
				{
					"col": col,
					"row": row,
					"pos": _cell_center(col, row),
					"hue": enemy["hue"],
					"intensity": sample["intensity"],
					"life": ENEMY_RESIDUE_LIFE,
					"max_life": ENEMY_RESIDUE_LIFE
				}
			)
			continue
		existing["hue"] = enemy["hue"]
		existing["intensity"] = clamp(max(float(existing.get("intensity", 0.4)), float(sample["intensity"])) + 0.08, 0.4, 1.0)
		existing["life"] = ENEMY_RESIDUE_LIFE
		existing["max_life"] = ENEMY_RESIDUE_LIFE
	while enemy_residue.size() > ENEMY_RESIDUE_MAX:
		enemy_residue.pop_front()


func _enemy_residue_at(col: int, row: int) -> Dictionary:
	for residue in enemy_residue:
		if residue["col"] == col and residue["row"] == row:
			return residue
	return {}


func _residue_hits_trail() -> bool:
	for point in player["trail"]:
		if not _enemy_residue_at(point["col"], point["row"]).is_empty():
			return true
	return false


func _update_enemy_residue(delta: float) -> void:
	var survivors := []
	for residue in enemy_residue:
		residue["life"] -= delta
		if residue["life"] <= 0.0:
			continue
		survivors.append(residue)
	enemy_residue = survivors


func _compute_capture_percent() -> float:
	var total := float(COLS * ROWS)
	var claimed := 0.0
	for row in range(ROWS):
		for col in range(COLS):
			if grid[row][col] == TILE_SAFE:
				claimed += 1.0
	return claimed / max(1.0, total) * 100.0


func _player_position() -> Vector2:
	return _cell_center(player["col"], player["row"])


func _board_rect() -> Rect2:
	if state_name == "title":
		return Rect2(Vector2(44.0, 92.0), BOARD_RECT.size)
	return Rect2(Vector2(52.0, 148.0), BOARD_RECT.size)


func _cell_center(col: int, row: int) -> Vector2:
	var board := _board_rect()
	return board.position + Vector2(col * CELL + CELL * 0.5, row * CELL + CELL * 0.5)


func _point_to_cell(point: Vector2) -> Dictionary:
	var board := _board_rect()
	return {
		"col": clamp(int((point.x - board.position.x) / CELL), 0, COLS - 1),
		"row": clamp(int((point.y - board.position.y) / CELL), 0, ROWS - 1)
	}


func _cell_rect(col: int, row: int) -> Rect2:
	var board := _board_rect()
	return Rect2(board.position + Vector2(col * CELL, row * CELL), Vector2(CELL, CELL))


func _inside(col: int, row: int) -> bool:
	return col >= 0 and row >= 0 and col < COLS and row < ROWS


func _tile_key(col: int, row: int) -> String:
	return "%d:%d" % [col, row]


func _flash(color: Color, strength: float) -> void:
	flash_color = color
	flash_strength = max(flash_strength, strength)


func _shake(strength: float) -> void:
	shake_strength = max(shake_strength, strength)


func _with_alpha(color: Color, alpha: float) -> Color:
	var tinted := color
	tinted.a = alpha
	return tinted


func _shift_rect(rect: Rect2, offset: Vector2) -> Rect2:
	return Rect2(rect.position + offset, rect.size)


func _theme_for_level(level_number: int) -> Dictionary:
	var raw = THEME_DATA[(level_number - 1) % THEME_DATA.size()]
	return {
		"name": raw["name"],
		"bg_a": Color(raw["bg_a"]),
		"bg_b": Color(raw["bg_b"]),
		"bg_c": Color(raw["bg_c"]),
		"rail": Color(raw["rail"]),
		"claim_fill": Color(raw["claim_fill"]),
		"trail_a": Color(raw["trail_a"]),
		"trail_b": Color(raw["trail_b"]),
		"enemy_core": Color(raw["enemy_core"])
	}


func _theme_color(key: String) -> Color:
	return current_theme.get(key, Color.WHITE)


func _trail_color() -> Color:
	return _rainbow_color(int(floor(title_phase * 8.0)))


func _rainbow_color(index: int) -> Color:
	var color: Color = TRAIL_RAINBOW[posmod(index, TRAIL_RAINBOW.size())]
	var pulse := 0.08 + (sin(title_phase * 7.0 + float(index) * 0.65) * 0.5 + 0.5) * 0.12
	return color.lerp(Color.WHITE, pulse)


func _load_backgrounds() -> void:
	background_paths.clear()
	for key in background_pools.keys():
		background_pools[key].clear()
	if FileAccess.file_exists(BACKGROUND_MANIFEST_PATH):
		var manifest_text := FileAccess.get_file_as_string(BACKGROUND_MANIFEST_PATH)
		var parsed = JSON.parse_string(manifest_text)
		if parsed is Array:
			for entry in parsed:
				if entry is String:
					_register_background_path("res://backgrounds/%s" % entry)
	if not background_paths.is_empty():
		return
	var dir := DirAccess.open("res://backgrounds")
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file := dir.get_next()
		if file == "":
			break
		if dir.current_is_dir():
			continue
		var extension := file.get_extension().to_lower()
		if extension in ["jpg", "jpeg", "png", "webp"]:
			_register_background_path("res://backgrounds/%s" % file)
	dir.list_dir_end()


func _register_background_path(path: String) -> void:
	if path == "" or background_paths.has(path):
		return
	background_paths.append(path)
	background_pools["random"].append(path)
	var lower := path.get_file().to_lower()
	if lower.begins_with("pup"):
		background_pools["aww"].append(path)
	elif lower.begins_with("funny"):
		background_pools["funny"].append(path)
	elif lower.begins_with("pinup"):
		background_pools["pinup"].append(path)


func _pick_background_texture() -> Texture2D:
	var pool: Array = background_pools.get(reveal_pool, [])
	if pool.is_empty():
		pool = background_paths
	if pool.is_empty():
		return null
	var path: String = pool[rng.randi_range(0, pool.size() - 1)]
	return _load_texture_from_path(path)


func _load_texture_from_path(path: String) -> Texture2D:
	if path == "":
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


func _load_audio_stream(path: String, loop: bool = false) -> AudioStream:
	if path == "":
		return null
	if not ResourceLoader.exists(path, "AudioStream"):
		return null
	var resource := ResourceLoader.load(path)
	if resource is AudioStream:
		var stream: AudioStream = resource.duplicate()
		if loop:
			stream.set("loop", true)
		return stream
	return null


func _assign_background_texture(texture: Texture2D) -> void:
	current_background = texture
	current_background_gray = _make_grayscale_texture(texture)


func _make_grayscale_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	var grayscale: Image = image.duplicate()
	grayscale.convert(Image.FORMAT_RGBA8)
	for y in range(grayscale.get_height()):
		for x in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(x, y)
			var luminance: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			grayscale.set_pixel(x, y, Color(luminance, luminance, luminance, color.a))
	return ImageTexture.create_from_image(grayscale)


func _build_grain_texture() -> void:
	var image := Image.create(160, 120, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var shade := rng.randf_range(0.28, 0.72)
			var alpha := rng.randf_range(0.04, 0.18)
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	grain_texture = ImageTexture.create_from_image(image)


func _background_draw_rect(texture_size: Vector2, target_rect: Rect2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return target_rect
	var board_aspect := target_rect.size.x / target_rect.size.y
	var texture_aspect := texture_size.x / texture_size.y
	if texture_aspect > board_aspect:
		var draw_height := target_rect.size.x / texture_aspect
		return Rect2(
			Vector2(target_rect.position.x, target_rect.position.y + (target_rect.size.y - draw_height) * 0.5),
			Vector2(target_rect.size.x, draw_height)
		)
	var draw_width := target_rect.size.y * texture_aspect
	return Rect2(
		Vector2(target_rect.position.x + (target_rect.size.x - draw_width) * 0.5, target_rect.position.y),
		Vector2(draw_width, target_rect.size.y)
	)


func _draw_claimed_reveal_tile(tile_rect: Rect2, col: int, row: int) -> void:
	if current_background_gray == null:
		return
	var texture_size := current_background_gray.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var board_rect := _shift_rect(_board_rect(), camera_offset * 0.24)
	var draw_rect := _background_draw_rect(texture_size, board_rect)
	var clipped := draw_rect.intersection(tile_rect)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	var uv_pos := Vector2(
		(clipped.position.x - draw_rect.position.x) / draw_rect.size.x * texture_size.x,
		(clipped.position.y - draw_rect.position.y) / draw_rect.size.y * texture_size.y
	)
	var uv_size := Vector2(
		clipped.size.x / draw_rect.size.x * texture_size.x,
		clipped.size.y / draw_rect.size.y * texture_size.y
	)
	draw_texture_rect_region(current_background_gray, clipped, Rect2(uv_pos, uv_size), Color(1, 1, 1, 1.0))
	if grain_texture != null:
		draw_texture_rect(grain_texture, clipped, true, Color(1, 1, 1, 0.035))


func _build_audio() -> void:
	audio_streams = AudioSynth.create_sfx_library()
	music_asset_stream = _load_audio_stream(MUSIC_ASSET_PATH, true)
	slice_asset_stream = _load_audio_stream(SLICE_ASSET_PATH)
	if slice_asset_stream != null:
		audio_streams["slice"] = slice_asset_stream

	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	danger_player = AudioStreamPlayer.new()
	add_child(danger_player)

	for _index in range(8):
		var player_node := AudioStreamPlayer.new()
		add_child(player_node)
		sfx_players.append(player_node)

	_refresh_music_streams()
	music_player.play()
	danger_player.play()
	_update_audio_mix()


func _refresh_music_streams() -> void:
	audio_streams["music_calm"] = music_asset_stream if music_asset_stream != null else AudioSynth.create_music_stream(reveal_pool, false)
	audio_streams["music_danger"] = AudioSynth.create_music_stream(reveal_pool, true)
	if music_player != null:
		music_player.stream = audio_streams["music_calm"]
		if not music_player.playing:
			music_player.play()
	if danger_player != null:
		danger_player.stream = audio_streams["music_danger"]
		if not danger_player.playing:
			danger_player.play()


func _update_audio_mix() -> void:
	if music_player == null or danger_player == null:
		return
	if not music_enabled or music_volume <= 0.01:
		music_player.volume_db = -50.0
		danger_player.volume_db = -50.0
		return
	var volume_db := linear_to_db(max(0.001, music_volume))
	music_player.volume_db = lerpf(-19.0, -11.0, clamp(1.0 - danger_level * 0.75, 0.0, 1.0)) + volume_db
	danger_player.volume_db = lerpf(-48.0, -27.0, danger_level) + volume_db


func _play_sfx(name: String) -> void:
	if not audio_streams.has(name) or sfx_players.is_empty():
		return
	var player_node: AudioStreamPlayer = sfx_players[sfx_index % sfx_players.size()]
	sfx_index += 1
	player_node.stream = audio_streams[name]
	player_node.volume_db = -13.0 if name == "slice" else 0.0
	player_node.play()


func _ensure_input_actions() -> void:
	_bind_key_action("move_left", KEY_A)
	_bind_key_action("move_left", KEY_LEFT)
	_bind_key_action("move_right", KEY_D)
	_bind_key_action("move_right", KEY_RIGHT)
	_bind_key_action("move_up", KEY_W)
	_bind_key_action("move_up", KEY_UP)
	_bind_key_action("move_down", KEY_S)
	_bind_key_action("move_down", KEY_DOWN)
	_bind_key_action("accept", KEY_SPACE)
	_bind_key_action("accept", KEY_ENTER)
	_bind_key_action("pause", KEY_ESCAPE)
	_bind_key_action("pause", KEY_P)
	_bind_key_action("exit_game", KEY_Q)
	_bind_key_action("toggle_music", KEY_M)
	_bind_key_action("boost_cut", KEY_SHIFT)


func _bind_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		high_score = 0
		music_enabled = true
		music_volume = 0.7
		speed_setting = 2
		magic_mode = "more"
		reveal_pool = DEFAULT_REVEAL_POOL
		cheat_enabled = false
		return
	high_score = int(config.get_value("scores", "high_score", 0))
	music_enabled = bool(config.get_value("settings", "music", true))
	music_volume = clamp(float(config.get_value("settings", "volume", 0.7)), 0.0, 1.0)
	speed_setting = clamp(int(config.get_value("settings", "speed", 2)), 1, 10)
	magic_mode = str(config.get_value("settings", "magic", "more"))
	if magic_mode not in ["more", "normal"]:
		magic_mode = "more"
	reveal_pool = str(config.get_value("settings", "reveal_pool", DEFAULT_REVEAL_POOL))
	if reveal_pool not in SETTING_POOLS:
		reveal_pool = DEFAULT_REVEAL_POOL
	cheat_enabled = bool(config.get_value("settings", "cheat", false))


func _save_progress() -> void:
	high_score = max(high_score, score)
	var config := ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.set_value("settings", "music", music_enabled)
	config.set_value("settings", "volume", music_volume)
	config.set_value("settings", "speed", speed_setting)
	config.set_value("settings", "magic", magic_mode)
	config.set_value("settings", "reveal_pool", reveal_pool)
	config.set_value("settings", "cheat", cheat_enabled)
	config.save(SAVE_PATH)


func _roll_pickup_timer(minimum: float, maximum: float) -> float:
	var interval := rng.randf_range(minimum, maximum)
	if magic_mode == "normal":
		interval *= 2.0
	return interval


func _player_speed_scale() -> float:
	return 0.45 + speed_setting * 0.15


func _enemy_speed_scale() -> float:
	return 0.28 if cheat_enabled else 1.0


func _record_player_history() -> void:
	if player.is_empty():
		return
	var history: Array = player.get("history", [])
	history.push_front({"pos": _player_position(), "drawing": player.get("drawing", false)})
	while history.size() > 12:
		history.pop_back()
	player["history"] = history


func _advance_after_level_clear() -> void:
	if state_name != "level_clear":
		return
	banner_timer = 0.0
	carry_score += _current_level_score_slice()
	elapsed_seconds = 0.0
	_start_level(level + 1)


func _pool_label(pool: String) -> String:
	match pool:
		"aww":
			return "Aww"
		"funny":
			return "Funny"
		"pinup":
			return "Pinup"
		_:
			return "Random"


func _is_level_clear_continue_event(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE


func _options_visible() -> bool:
	return true


func _options_panel_rect() -> Rect2:
	var board := _board_rect()
	var top: float = 20.0 if state_name == "title" else board.position.y - 18.0
	var x: float = board.end.x + SIDEBAR_GAP
	var height: float = size.y - top - 24.0 if state_name == "title" else board.size.y + 44.0
	return Rect2(Vector2(x, top), Vector2(SIDEBAR_WIDTH, height))


func _options_settings_rect() -> Rect2:
	var panel := _options_panel_rect()
	return Rect2(panel.position + Vector2(20.0, 118.0), Vector2(panel.size.x - 40.0, 360.0))


func _options_controls_rect() -> Rect2:
	var settings := _options_settings_rect()
	return Rect2(Vector2(settings.position.x, settings.end.y + 16.0), Vector2(settings.size.x, 182.0))


func _options_footer_rect() -> Rect2:
	var panel := _options_panel_rect()
	return Rect2(Vector2(panel.position.x + 20.0, panel.end.y - 84.0), Vector2(panel.size.x - 40.0, 58.0))


func _options_pickups_rect() -> Rect2:
	var controls := _options_controls_rect()
	var footer := _options_footer_rect()
	return Rect2(
		Vector2(controls.position.x, controls.end.y + 12.0),
		Vector2(controls.size.x, maxf(176.0, footer.position.y - controls.end.y - 16.0))
	)


func _options_control_rect(index: int) -> Rect2:
	var settings := _options_settings_rect()
	return Rect2(Vector2(settings.end.x - 194.0, settings.position.y + 18.0 + index * 56.0), Vector2(176.0, 38.0))


func _options_exit_rect() -> Rect2:
	return _options_footer_rect()


func _control_step_rect(base: Rect2, side: String) -> Rect2:
	if side == "left":
		return Rect2(base.position, Vector2(32.0, base.size.y))
	return Rect2(Vector2(base.end.x - 32.0, base.position.y), Vector2(32.0, base.size.y))


func _cycle_reveal_pool(step: int) -> void:
	var index := SETTING_POOLS.find(reveal_pool)
	if index == -1:
		index = 0
	reveal_pool = SETTING_POOLS[posmod(index + step, SETTING_POOLS.size())]
	_save_progress()
	_refresh_music_streams()
	if state_name != "playing":
		_assign_background_texture(_pick_background_texture())


func _handle_option_click(point: Vector2) -> bool:
	if not _options_visible() or not _options_panel_rect().has_point(point):
		return false
	var speed_rect := _options_control_rect(0)
	var magic_rect := _options_control_rect(1)
	var pool_rect := _options_control_rect(2)
	var cheat_rect := _options_control_rect(3)
	var music_rect := _options_control_rect(4)
	var volume_rect := _options_control_rect(5)
	if _control_step_rect(speed_rect, "left").has_point(point):
		speed_setting = max(1, speed_setting - 1)
	elif _control_step_rect(speed_rect, "right").has_point(point):
		speed_setting = min(10, speed_setting + 1)
	elif magic_rect.has_point(point):
		magic_mode = "normal" if magic_mode == "more" else "more"
	elif _control_step_rect(pool_rect, "left").has_point(point):
		_cycle_reveal_pool(-1)
	elif _control_step_rect(pool_rect, "right").has_point(point):
		_cycle_reveal_pool(1)
	elif cheat_rect.has_point(point):
		cheat_enabled = not cheat_enabled
	elif music_rect.has_point(point):
		music_enabled = not music_enabled
	elif _control_step_rect(volume_rect, "left").has_point(point):
		music_volume = max(0.0, music_volume - 0.1)
	elif _control_step_rect(volume_rect, "right").has_point(point):
		music_volume = min(1.0, music_volume + 0.1)
	elif _options_exit_rect().has_point(point):
		_on_exit_button_pressed()
	else:
		return true
	music_volume = snappedf(music_volume, 0.1)
	_update_audio_mix()
	_save_progress()
	return true


func _build_ui() -> void:
	pause_button = _make_ui_button("Pause", Color("ffd86b"), Color("5c1b3a"))
	pause_button.pressed.connect(_on_pause_button_pressed)
	add_child(pause_button)

	resume_button = _make_ui_button("Resume", Color("83fff1"), Color("11344d"))
	resume_button.pressed.connect(_on_resume_button_pressed)
	add_child(resume_button)

	exit_button = _make_ui_button("Exit Game", Color("ff7ca8"), Color("4d102c"))
	exit_button.pressed.connect(_on_exit_button_pressed)
	add_child(exit_button)


func _make_ui_button(label: String, fill: Color, font_color: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(170.0, 46.0)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", _with_alpha(font_color, 0.5))

	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = _with_alpha(Color.WHITE, 0.28)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.shadow_color = _with_alpha(Color("18091b"), 0.4)
	normal.shadow_size = 8
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0

	var hover := normal.duplicate()
	hover.bg_color = fill.lightened(0.11)

	var pressed := normal.duplicate()
	pressed.bg_color = fill.darkened(0.08)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	return button


func _layout_ui() -> void:
	pass


func _refresh_ui() -> void:
	if pause_button != null:
		pause_button.visible = false
	if resume_button != null:
		resume_button.visible = false
	if exit_button != null:
		exit_button.visible = false


func _on_pause_button_pressed() -> void:
	if state_name == "playing":
		_toggle_pause()


func _on_resume_button_pressed() -> void:
	if state_name == "paused":
		_toggle_pause()


func _on_exit_button_pressed() -> void:
	_save_progress()
	get_tree().quit()


func _draw() -> void:
	_draw_backdrop()
	if _options_visible():
		_draw_cabinet_shell()
	_draw_board()
	if state_name != "level_clear":
		_draw_enemy_residue()
	_draw_particles()
	if state_name != "level_clear":
		_draw_enemies()
		_draw_sparks()
		_draw_pickups()
		_draw_player()
	_draw_floaters()
	if state_name != "title":
		_draw_hud()
	_draw_overlay()
	if _options_visible():
		_draw_options_panel()
	if flash_strength > 0.0:
		var overlay := flash_color
		overlay.a = min(0.42, flash_strength)
		draw_rect(Rect2(Vector2.ZERO, size), overlay, true)


func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _theme_color("bg_a"), true)
	var title_mode := state_name == "title"
	for band in range(14):
		var t := float(band) / 13.0
		var y := lerpf(0.0, size.y, t)
		var color := _theme_color("bg_a").lerp(_theme_color("bg_b"), t).lerp(_theme_color("bg_c"), 0.28 if title_mode else 0.18)
		color.a = 0.96
		draw_rect(Rect2(Vector2(0.0, y), Vector2(size.x, size.y / 13.0 + 5.0)), color, true)

	for blob in range(7):
		var wobble := title_phase * (0.11 + blob * 0.024)
		var center := Vector2(
			140.0 + blob * 235.0 + sin(wobble * 1.4 + blob) * 74.0,
			72.0 + fmod(blob * 118.0 + title_phase * 24.0, size.y + 220.0)
		)
		var glow := _theme_color("bg_c")
		glow.a = 0.08 if title_mode else 0.05
		draw_circle(center, 96.0 + sin(wobble) * 28.0, glow)
		draw_circle(center + Vector2(26.0, -18.0), 28.0 + cos(wobble * 1.6) * 7.0, _with_alpha(Color.WHITE, 0.045))

	for stripe in range(18):
		var offset := fmod(title_phase * 94.0 + stripe * 118.0, size.x + 320.0) - 160.0
		var stripe_color := _theme_color("rail")
		stripe_color.a = 0.05 + danger_level * 0.04
		var board := _board_rect()
		draw_line(
			Vector2(offset, board.position.y - 150.0),
			Vector2(offset + 250.0, board.end.y + 128.0),
			stripe_color,
			1.8
		)
	if title_mode:
		for candy in range(12):
			var x := 64.0 + candy * 134.0 + sin(title_phase * 0.9 + candy * 0.7) * 24.0
			var y := 64.0 + fmod(94.0 * candy + title_phase * 22.0, size.y - 96.0)
			var candy_palette: Array = [
				Color("ff75c8"),
				Color("6ff7ff"),
				Color("ffe066"),
				Color("ff9f68")
			]
			var candy_color: Color = candy_palette[candy % 4]
			draw_circle(Vector2(x, y), 22.0 + (candy % 3) * 4.0, _with_alpha(candy_color, 0.12))
			draw_circle(Vector2(x + 3.0, y - 2.0), 10.0 + (candy % 2) * 2.0, _with_alpha(Color.WHITE, 0.17))
		draw_rect(Rect2(Vector2(0.0, size.y - 180.0), Vector2(size.x, 180.0)), _with_alpha(Color("05070f"), 0.28), true)
		draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(size.x, 96.0)), _with_alpha(Color.WHITE, 0.025), true)


func _draw_board() -> void:
	var board := _board_rect()
	var frame := board.grow(18.0)
	var outer := frame.grow(12.0)
	var reveal_complete := state_name == "level_clear"
	draw_rect(_shift_rect(outer, camera_offset * 0.38), _with_alpha(Color("121720"), 0.94), true)
	draw_rect(_shift_rect(frame, camera_offset * 0.3), _with_alpha(Color("0c1118"), 0.98), true)
	draw_rect(_shift_rect(board, camera_offset * 0.2), _with_alpha(Color.BLACK, 1.0), true)
	var board_rect := _shift_rect(board, camera_offset * 0.12)
	if reveal_complete:
		if current_background != null:
			draw_texture_rect(current_background, _background_draw_rect(current_background.get_size(), board_rect), false, Color(1, 1, 1, 1.0))
	elif grain_texture != null:
		draw_texture_rect(grain_texture, board_rect, true, Color(1, 1, 1, 0.05 if state_name == "title" else 0.11))

	for scan in range(18):
		var scan_y := board.position.y + 12.0 + scan * ((board.size.y - 24.0) / 17.0)
		draw_rect(Rect2(Vector2(board.position.x + 8.0, scan_y), Vector2(board.size.x - 16.0, 2.0)), _with_alpha(Color.WHITE, 0.0 if reveal_complete else 0.012), true)

	if not reveal_complete:
		for row in range(ROWS):
			for col in range(COLS):
				var rect: Rect2 = _shift_rect(_cell_rect(col, row), camera_offset * 0.24)
				match grid[row][col]:
					TILE_EMPTY:
						var empty_color := Color("000000")
						empty_color.a = 1.0
						draw_rect(rect, empty_color, true)
						if (col + row) % 2 == 0:
							draw_rect(rect.grow(-3.0), Color(1, 1, 1, 0.004), true)
					TILE_SAFE:
						_draw_claimed_reveal_tile(rect, col, row)
						var claim_color := _theme_color("claim_fill")
						claim_color.a = 0.0
						draw_rect(rect, claim_color, true)
						draw_rect(rect.grow(-1.0), _with_alpha(_theme_color("rail"), 0.1), false, 1.0)
						draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(rect.size.x - 4.0, 2.0)), _with_alpha(Color.WHITE, 0.02), true)
					TILE_TRAIL:
						var pulse := _rainbow_color(col + row)
						pulse.a = 0.94
						draw_rect(rect.grow(-2.0), pulse, true)
						draw_rect(rect.grow(-0.75), Color.WHITE, false, 1.0)

	draw_rect(_shift_rect(board, camera_offset * 0.18), _with_alpha(_theme_color("rail"), 0.5), false, 2.0)
	draw_rect(_shift_rect(board.grow(-6.0), camera_offset * 0.08), _with_alpha(Color("ffffff"), 0.08), false, 1.0)
	_draw_candy_frame(board)
	if state_name == "title":
		draw_rect(board, Color(0, 0, 0, 0.16), true)


func _draw_cabinet_shell() -> void:
	var board := _board_rect()
	var panel := _options_panel_rect()
	var shell := Rect2(
		Vector2(board.position.x - 24.0, minf(board.position.y - 20.0, panel.position.y - 14.0)),
		Vector2(panel.end.x - board.position.x + 48.0, maxf(board.end.y + 20.0, panel.end.y + 14.0) - minf(board.position.y - 20.0, panel.position.y - 14.0))
	)
	draw_rect(shell, _with_alpha(Color("09111a"), 0.9), true)
	draw_rect(Rect2(Vector2(board.end.x - 8.0, shell.position.y + 10.0), Vector2(panel.position.x - board.end.x + 16.0, shell.size.y - 20.0)), _with_alpha(Color("0c141d"), 0.98), true)
	draw_rect(shell, _with_alpha(Color("233342"), 0.52), false, 3.0)
	draw_rect(shell.grow(-10.0), _with_alpha(Color("0f1822"), 0.42), false, 1.0)
	if state_name != "title":
		var frame_top: float = board.position.y - 24.0
		var frame_bottom: float = board.end.y + 24.0
		var bridge_x: float = board.end.x - 2.0
		var bridge_w: float = panel.position.x - bridge_x + 2.0
		draw_rect(Rect2(Vector2(bridge_x, frame_top), Vector2(bridge_w, 5.0)), _with_alpha(Color("ffe476"), 0.42), true)
		draw_rect(Rect2(Vector2(bridge_x, frame_bottom - 5.0), Vector2(bridge_w, 5.0)), _with_alpha(Color("ffe476"), 0.42), true)
		draw_rect(Rect2(Vector2(bridge_x + 8.0, frame_top + 9.0), Vector2(maxf(0.0, bridge_w - 16.0), 3.0)), _with_alpha(Color("ff7cb8"), 0.3), true)
		draw_rect(Rect2(Vector2(bridge_x + 8.0, frame_bottom - 12.0), Vector2(maxf(0.0, bridge_w - 16.0), 3.0)), _with_alpha(Color("ff7cb8"), 0.3), true)


func _draw_player() -> void:
	if state_name == "game_over":
		return
	var pos := _player_position() + camera_offset
	var dir: Vector2 = Vector2(player["dir"].x, player["dir"].y)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var core := Color("fffdf2")
	var shell := Color("ffe066") if player["drawing"] else Color("66f5ff")
	var accent := Color("ff6fa2")
	if _effect_active("cookie"):
		shell = Color("ffe561")
	if _effect_active("bomb"):
		shell = Color("ff6185")
	var history: Array = player.get("history", [])
	for index in range(history.size() - 1):
		var current: Vector2 = history[index]["pos"] + camera_offset * 0.68
		var next: Vector2 = history[index + 1]["pos"] + camera_offset * 0.68
		var tail_alpha := 1.0 - float(index) / float(max(1, history.size() - 1))
		var tail_width := 11.0 * tail_alpha + 1.6
		var rainbow := _rainbow_color(index + int(floor(title_phase * 8.0)))
		draw_line(current, next, _with_alpha(rainbow, tail_alpha * 0.42), tail_width)
		draw_line(current, next, _with_alpha(Color.WHITE, tail_alpha * 0.12), max(1.0, tail_width * 0.25))
	var tail_color := accent
	var nose := pos + dir * 16.0
	var left := pos + perp * 8.4 - dir * 1.8
	var right := pos - perp * 8.4 - dir * 1.8
	var tail := pos - dir * 14.0
	var body := PackedVector2Array([nose, left, tail, right])
	var fin := PackedVector2Array([
		tail - dir * 12.0,
		pos - perp * 4.4 - dir * 8.5,
		pos + perp * 4.4 - dir * 8.5
	])
	draw_colored_polygon(fin, _with_alpha(tail_color, 0.86))
	draw_colored_polygon(body, shell)
	draw_colored_polygon(PackedVector2Array([pos + dir * 6.0, pos + perp * 3.6, pos - dir * 8.8, pos - perp * 3.6]), tail_color)
	draw_colored_polygon(PackedVector2Array([nose - dir * 3.4 + perp * 3.0, nose - dir * 7.0, nose - dir * 3.4 - perp * 3.0]), core)
	draw_line(pos - perp * 4.6 - dir * 2.1, pos + perp * 4.6 - dir * 2.1, _with_alpha(Color.WHITE, 0.38), 1.5)
	draw_circle(pos - dir * 0.8, 2.2, Color("07101a"))
	draw_circle(pos + dir * 4.6, 1.8, _with_alpha(Color.WHITE, 0.56))
	if _effect_active("shield"):
		var shield := _with_alpha(Color("85f6ff"), 0.32 + sin(title_phase * 9.0) * 0.08)
		draw_arc(pos, 18.0, 0.0, TAU, 40, shield, 2.5, true)


func _draw_enemies() -> void:
	for enemy in enemies:
		var history: Array = enemy["history"]
		if history.is_empty():
			history = [{"x": enemy["x"], "y": enemy["y"], "angle": enemy["angle"]}]
		var trail_a := Color.from_hsv(enemy["hue"], 0.74, 1.0, 1.0)
		var trail_b := Color.from_hsv(fmod(enemy["hue"] + 0.33, 1.0), 0.66, 1.0, 1.0)
		for index in range(history.size() - 1, -1, -1):
			var ghost = history[index]
			var alpha: float = 0.18 + (float(history.size() - index) / float(max(1, history.size()))) * 0.72
			var a_dir := Vector2(cos(ghost["angle"]), sin(ghost["angle"]))
			var b_dir := Vector2(cos(ghost["angle"] + PI * 0.5), sin(ghost["angle"] + PI * 0.5))
			var center := Vector2(ghost["x"], ghost["y"]) + camera_offset * 0.7
			draw_line(center - a_dir * enemy["arm_a"], center + a_dir * enemy["arm_a"], _with_alpha(trail_a, alpha), 3.0 if index == 0 else 2.0)
			draw_line(center - b_dir * enemy["arm_b"], center + b_dir * enemy["arm_b"], _with_alpha(trail_b, alpha), 3.0 if index == 0 else 2.0)

		for index in range(history.size() - 1):
			var current := Vector2(history[index]["x"], history[index]["y"]) + camera_offset * 0.6
			var next := Vector2(history[index + 1]["x"], history[index + 1]["y"]) + camera_offset * 0.6
			var alpha_tail := 1.0 - float(index) / float(max(1, history.size() - 1))
			var tail_color := trail_a.lerp(trail_b, float(index % 5) / 4.0)
			draw_line(current, next, _with_alpha(tail_color, alpha_tail * 0.42), 14.0 * alpha_tail + 1.8)
			draw_line(current, next, _with_alpha(Color.WHITE, alpha_tail * 0.12), 3.6 * alpha_tail + 0.8)

		var center_now := Vector2(enemy["x"], enemy["y"]) + camera_offset
		var segments := _qix_segments(enemy)
		var line_a := Color.from_hsv(enemy["hue"], 0.58, 1.0, 0.95)
		var line_b := Color.from_hsv(fmod(enemy["hue"] + 0.18, 1.0), 0.55, 1.0, 0.9)
		draw_line(segments[0]["a"] + camera_offset, segments[0]["b"] + camera_offset, _with_alpha(line_a, 0.26), 7.8)
		draw_line(segments[1]["a"] + camera_offset, segments[1]["b"] + camera_offset, _with_alpha(line_b, 0.22), 6.2)
		draw_line(segments[0]["a"] + camera_offset, segments[0]["b"] + camera_offset, line_a, 3.6)
		draw_line(segments[1]["a"] + camera_offset, segments[1]["b"] + camera_offset, line_b, 2.8)
		for ray in range(4):
			var ray_angle: float = enemy["angle"] + ray * PI * 0.5 + sin(title_phase * 2.4 + ray) * 0.08
			var ray_dir := Vector2(cos(ray_angle), sin(ray_angle))
			draw_line(center_now + ray_dir * 3.0, center_now + ray_dir * 12.0, _with_alpha(line_b, 0.34), 1.5)
		draw_circle(center_now, 7.6, _theme_color("enemy_core"))
		draw_circle(center_now, 2.8, Color("120816"))
		draw_circle(center_now, 1.1, Color.WHITE)


func _draw_sparks() -> void:
	for spark in sparks:
		var menace: float = clamp((18.0 - (abs(int(spark["col"]) - int(player["col"])) + abs(int(spark["row"]) - int(player["row"])))) / 12.0, 0.0, 1.0)
		var phase: float = title_phase * 14.0 + float(spark["row"]) * 0.4 + float(spark["col"]) * 0.25
		var body_pos := _cell_center(spark["col"], spark["row"]) + camera_offset + Vector2(0.0, cos(phase * 1.2) * 0.8)
		var scale: float = 1.45 + menace * 0.22
		var history: Array = spark["history"]
		if history.is_empty():
			history = [{"col": spark["col"], "row": spark["row"]}]
		for index in range(0, history.size() - 1):
			var current = history[index]
			var next = history[index + 1]
			var tail_weight := float(history.size() - index) / float(max(1, history.size()))
			var alpha: float = 0.18 + tail_weight * (0.28 + menace * 0.3)
			var current_pos := _cell_center(current["col"], current["row"]) + camera_offset * 0.82
			var next_pos := _cell_center(next["col"], next["row"]) + camera_offset * 0.82
			draw_line(
				current_pos,
				next_pos,
				_with_alpha(Color("ffb884"), alpha),
				1.1 + menace * 0.4
			)
			draw_line(current_pos, next_pos, _with_alpha(Color("fff2c7"), alpha * 0.34), 0.65 + menace * 0.2)
			draw_circle(current_pos, (1.8 + menace * 0.8) * tail_weight, _with_alpha(Color("ffd9b8"), alpha * 0.28))
		draw_circle(body_pos, 9.0 * scale, _with_alpha(Color("ff7050"), 0.26 + menace * 0.18))
		var leg_swing: float = sin(phase) * 2.0
		var body_dark := Color("2b0e0a")
		var head_color := Color("b31f1f") if str(spark.get("effect_kind", "")) != "bomb" else Color("ff5844")
		var eye_color := Color("fff3b0")
		draw_circle(body_pos + Vector2(0.0, 2.1 * scale), 4.6 * scale, body_dark)
		draw_circle(body_pos + Vector2(0.0, -2.2 * scale), 3.2 * scale, head_color)
		draw_circle(body_pos + Vector2(-1.2 * scale, -2.5 * scale), 0.95 * scale, eye_color)
		draw_circle(body_pos + Vector2(1.2 * scale, -2.5 * scale), 0.95 * scale, eye_color)
		draw_circle(body_pos + Vector2(0.0, -0.2 * scale), 0.9 * scale, Color.WHITE)
		var leg_color := _with_alpha(Color("ffd9b8"), 0.92)
		var left_legs := [
			[Vector2(-2.0, -1.0), Vector2(-6.0, -5.0 - leg_swing)],
			[Vector2(-2.0, 1.0), Vector2(-7.0, -1.0)],
			[Vector2(-2.0, 2.5), Vector2(-6.0, 4.0 + leg_swing)],
			[Vector2(-1.0, 3.5), Vector2(-4.5, 7.0)]
		]
		var right_legs := [
			[Vector2(2.0, -1.0), Vector2(6.0, -5.0 + leg_swing)],
			[Vector2(2.0, 1.0), Vector2(7.0, -1.0)],
			[Vector2(2.0, 2.5), Vector2(6.0, 4.0 - leg_swing)],
			[Vector2(1.0, 3.5), Vector2(4.5, 7.0)]
		]
		for leg in left_legs:
			draw_line(body_pos + leg[0] * scale, body_pos + leg[1] * scale, leg_color, 1.4)
		for leg in right_legs:
			draw_line(body_pos + leg[0] * scale, body_pos + leg[1] * scale, leg_color, 1.4)
		for ray in range(3):
			var ray_angle: float = phase + ray * TAU / 3.0
			var ray_dir := Vector2(cos(ray_angle), sin(ray_angle))
			draw_line(body_pos, body_pos + ray_dir * (4.5 + menace * 2.5) * scale, _with_alpha(Color("ffe8b4"), 0.55 + menace * 0.35), 1.0)


func _draw_pickups() -> void:
	for pickup in pickups:
		var meta = PICKUP_META[pickup["kind"]]
		var pos := _cell_center(pickup["col"], pickup["row"]) + camera_offset * 0.6
		var pulse := 0.84 + sin(title_phase * 7.0 + pickup["wobble"] * 3.0) * 0.18
		var color := Color(meta["color"])
		draw_circle(pos, 18.0 * pulse, _with_alpha(color, 0.12))
		match pickup["kind"]:
			"heart":
				_draw_heart_icon(pos, pulse)
			"shield":
				_draw_shield_icon(pos, pulse)
			"cookie":
				_draw_cookie_icon(pos, pulse)
			"bomb":
				_draw_bomb_icon(pos, pulse)


func _draw_enemy_residue() -> void:
	for residue in enemy_residue:
		var intensity: float = float(residue.get("intensity", 0.64))
		var alpha: float = intensity * float(residue["life"]) / float(residue["max_life"])
		var hue: float = residue["hue"]
		var center: Vector2 = residue["pos"] + camera_offset * 0.36
		var glow := Color.from_hsv(fmod(hue + 0.08, 1.0), 0.7, 1.0, alpha * 0.55)
		var glow_mid := Color.from_hsv(fmod(hue + 0.14, 1.0), 0.78, 1.0, alpha * 0.32)
		var cross := Color.from_hsv(fmod(hue + 0.26, 1.0), 0.55, 1.0, alpha * 0.7)
		draw_circle(center, 6.0 + intensity * 4.0, glow)
		draw_circle(center, 2.4 + intensity * 1.8, glow_mid)
		draw_line(center + Vector2(-3.4, 0.0), center + Vector2(3.4, 0.0), cross, 1.2 + intensity * 0.3)
		draw_line(center + Vector2(0.0, -3.4), center + Vector2(0.0, 3.4), cross, 1.2 + intensity * 0.3)


func _draw_particles() -> void:
	for particle in particles:
		var alpha: float = float(particle["life"]) / float(particle["max_life"])
		var color: Color = particle["color"]
		color.a *= alpha
		draw_circle(particle["pos"] + camera_offset * 0.42, particle["size"] * alpha, color)


func _draw_floaters() -> void:
	for floater in floaters:
		var alpha: float = float(floater["life"]) / float(floater["max_life"])
		var color: Color = floater["color"]
		color.a = alpha
		draw_string(ThemeDB.fallback_font, floater["pos"] + camera_offset * 0.18, floater["text"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, color)


func _draw_hud() -> void:
	var board := _board_rect()
	var header_x := board.position.x
	var card_y := 28.0
	var card_height := 72.0
	var gap := 10.0
	var card_width: float = floor((board.size.x - gap * 6.0) / 7.0)
	var cards := [
		{"label": "Score", "value": "%06d" % score, "accent": Color("ffd86a"), "size": 22},
		{"label": "High", "value": "%06d" % high_score, "accent": Color("f5fbff"), "size": 22},
		{"label": "Level", "value": "%02d" % level, "accent": Color("77ecff"), "size": 22},
		{"label": "Lives", "value": str(lives), "accent": Color("fff0d1"), "size": 22},
		{"label": "Claimed", "value": "%d%%" % int(capture_percent), "accent": Color("fff4db"), "size": 22},
		{"label": "Goal", "value": "%d%%" % capture_goal, "accent": Color("c8fff6"), "size": 22},
		{"label": "Burst", "value": "%d%%" % int(next_burst_threshold), "accent": Color("ffcce8"), "size": 22}
	]
	for index in range(cards.size()):
		var card = cards[index]
		var rect := Rect2(Vector2(header_x + index * (card_width + gap), card_y), Vector2(card_width, card_height))
		_draw_metric_card(rect, card["label"], card["value"], card["accent"], card["size"])

	var power_rect := Rect2(Vector2(board.position.x, 114.0), Vector2(board.size.x, 12.0))
	draw_rect(power_rect, Color("10151f", 0.95), true)
	var remaining: float = clamp(1.0 - elapsed_seconds / LEVEL_TIME_LIMIT, 0.0, 1.0)
	var fill_color := Color("43ff60").lerp(Color("ff9d59"), 1.0 - remaining)
	draw_rect(Rect2(power_rect.position + Vector2(4.0, 3.0), Vector2((power_rect.size.x - 8.0) * remaining, 6.0)), fill_color, true)
	draw_rect(power_rect, _with_alpha(Color("ecffef"), 0.1), false, 1.0)

	var effects := []
	for key in ["bomb", "shield", "cookie"]:
		if _effect_active(key):
			effects.append("%s %.0fs" % [PICKUP_META[key]["title"], ceil(active_effects[key])])
	if not effects.is_empty():
		var effect_text := "  ".join(effects)
		_draw_label(Vector2(board.position.x, board.end.y + 28.0), effect_text, 16, Color("e8f8ff"))
	if status_message != "" and state_name not in ["paused", "death", "game_over"]:
		_draw_label(Vector2(board.end.x - 220.0, board.end.y + 28.0), status_message, 16, Color("ffd9bc"))


func _draw_overlay() -> void:
	var board := _board_rect()
	if state_name == "title":
		var modal := Rect2(Vector2(board.position.x + board.size.x * 0.5 - 74.0, board.position.y + board.size.y * 0.5 - 78.0), Vector2(148.0, 156.0))
		_draw_panel(modal, Color("101623", 0.88), _with_alpha(Color("2d344a"), 0.5))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 34.0), "DOPAQIX", 14, Color("8f99b1"))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 70.0), "Press Start", 22, Color("dde7ff"))
		var button_rect := Rect2(Vector2(modal.position.x + 24.0, modal.end.y - 48.0), Vector2(modal.size.x - 48.0, 34.0))
		_draw_panel(button_rect, Color("ffe27d"), _with_alpha(Color("fff5be"), 0.38))
		_draw_centered_label(Vector2(button_rect.get_center().x, button_rect.position.y + 23.0), "Start Run", 18, Color("18120a"))
	elif state_name == "paused":
		var modal := Rect2(Vector2(board.position.x + board.size.x * 0.5 - 110.0, board.position.y + board.size.y * 0.5 - 46.0), Vector2(220.0, 92.0))
		_draw_panel(modal, Color("101623", 0.88), _with_alpha(Color("2d344a"), 0.5))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 34.0), "Paused", 28, Color("fff7dd"))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 64.0), "Press P", 18, Color("dff7ff"))
	elif state_name == "level_clear":
		var modal := Rect2(Vector2(board.position.x + board.size.x * 0.5 - 210.0, board.end.y - 84.0), Vector2(420.0, 72.0))
		_draw_panel(modal, Color("101623", 0.82), _with_alpha(Color("ffe27d"), 0.24))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 30.0), "LEVEL %02d DETONATED" % level, 26, Color("fff7d8"))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 54.0), "Press Space or click to reveal the next board", 16, Color("dffcff"))
	elif state_name == "death":
		var modal := Rect2(Vector2(board.position.x + board.size.x * 0.5 - 126.0, board.position.y + board.size.y * 0.5 - 46.0), Vector2(252.0, 92.0))
		_draw_panel(modal, Color("220d13", 0.86), _with_alpha(Color("ff8c73"), 0.28))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 34.0), "CRASH", 30, Color("fff0dc"))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 64.0), status_message, 16, Color("ffd0c0"))
	elif state_name == "game_over":
		var modal := Rect2(Vector2(board.position.x + board.size.x * 0.5 - 160.0, board.position.y + board.size.y * 0.5 - 74.0), Vector2(320.0, 148.0))
		_draw_panel(modal, Color("101623", 0.9), _with_alpha(Color("2d344a"), 0.5))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 44.0), "Game Over", 34, Color("fff7d8"))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 76.0), status_message if status_message != "" else "The board bit back.", 18, Color("ffd4c4"))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 106.0), "Press Space or Enter to run it again", 18, Color("ffe46a"))
		_draw_centered_label(Vector2(modal.get_center().x, modal.position.y + 130.0), "High score %06d" % high_score, 16, Color("d4faff"))


func _draw_options_panel() -> void:
	var panel := _options_panel_rect()
	var settings := _options_settings_rect()
	var controls := _options_controls_rect()
	var pickups_rect := _options_pickups_rect()
	var footer_rect := _options_footer_rect()
	_draw_panel(panel, Color("0a1017", 0.97), _with_alpha(Color("31414f"), 0.52))
	_draw_candy_title(panel.position + Vector2(22.0, 54.0))
	_draw_label(panel.position + Vector2(22.0, 112.0), "BETA CONTROLS", 13, Color("a0adc3"))
	_draw_panel(settings, Color("08111a", 0.98), _with_alpha(Color("2f4a5d"), 0.42))
	_draw_panel(controls, Color("08111a", 0.98), _with_alpha(Color("544031"), 0.34))
	_draw_panel(pickups_rect, Color("08111a", 0.98), _with_alpha(Color("36505f"), 0.34))
	_draw_panel(footer_rect, Color("08111a", 0.98), _with_alpha(Color("4b5a69"), 0.34))
	_draw_label(settings.position + Vector2(16.0, 26.0), "SETTINGS", 13, Color("8ea3b4"))
	var labels := ["Speed", "Magic", "Reveal Pool", "Cheat Mode", "Music", "Volume"]
	var settings_label_start := 50.0
	var settings_label_step := 56.0
	for index in range(labels.size()):
		var y := settings.position.y + settings_label_start + index * settings_label_step
		_draw_label(Vector2(settings.position.x + 18.0, y), labels[index], 18, Color("eef8ff"))
	var speed_rect := _options_control_rect(0)
	var magic_rect := _options_control_rect(1)
	var pool_rect := _options_control_rect(2)
	var cheat_rect := _options_control_rect(3)
	var music_rect := _options_control_rect(4)
	var volume_rect := _options_control_rect(5)
	_draw_stepper(speed_rect, str(speed_setting))
	_draw_toggle_pill(magic_rect, "More Magic" if magic_mode == "more" else "Magic", magic_mode == "more")
	_draw_cycle_pill(pool_rect, _pool_label(reveal_pool))
	_draw_toggle_pill(cheat_rect, "On" if cheat_enabled else "Off", cheat_enabled)
	_draw_toggle_pill(music_rect, "On" if music_enabled else "Off", music_enabled)
	_draw_stepper(volume_rect, "%d%%" % int(round(music_volume * 100.0)))
	_draw_label(controls.position + Vector2(16.0, 26.0), "CONTROLS", 13, Color("8ea3b4"))
	var control_lines := [
		"WASD or arrows: Move",
		"Space: Start cut / continue",
		"Shift: Fast risky carve",
		"P / Esc: Pause",
		"Q: Quit"
	]
	for index in range(control_lines.size()):
		_draw_label(Vector2(controls.position.x + 18.0, controls.position.y + 54.0 + index * 28.0), control_lines[index], 18, Color("eef8ff"))
	_draw_label(pickups_rect.position + Vector2(16.0, 26.0), "PICKUPS", 13, Color("8ea3b4"))
	var legend_y := pickups_rect.position.y + 62.0
	for legend in [
		{"text": "Bomb", "desc": "Slow 10s", "fill": Color("5b2f2b")},
		{"text": "Heart", "desc": "+1 life", "fill": Color("5b2943")},
		{"text": "Muffin", "desc": "Speed boost", "fill": Color("58523a")},
		{"text": "Shield", "desc": "Immune 10s", "fill": Color("223d4f")}
	]:
		var badge := Rect2(Vector2(pickups_rect.position.x + 18.0, legend_y - 18.0), Vector2(122.0, 28.0))
		_draw_panel(badge, legend["fill"], _with_alpha(Color.WHITE, 0.1))
		_draw_centered_label(Vector2(badge.get_center().x, badge.position.y + 20.0), legend["text"], 15, Color("fff6ea"))
		_draw_label(Vector2(pickups_rect.position.x + 156.0, legend_y), legend["desc"], 18, Color("eef8ff"))
		legend_y += 34.0
	_draw_action_pill(footer_rect.grow_individual(-14.0, -10.0, -14.0, -10.0), "Exit Game")


func _draw_label(position: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered_label(position: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(ThemeDB.fallback_font, position - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_shadowed_label(position: Vector2, text: String, font_size: int, shadow: Color, fill: Color) -> void:
	_draw_label(position + Vector2(5.0, 5.0), text, font_size, shadow)
	_draw_label(position, text, font_size, fill)


func _draw_candy_title(position: Vector2) -> void:
	var advance_x := position.x
	for index in range(TITLE_LETTERS.size()):
		var letter = TITLE_LETTERS[index]
		var font_size: int = letter["size"]
		var wobble := sin(title_phase * 1.8 + index * 0.7) * 2.0
		var baseline := Vector2(advance_x, position.y + wobble)
		draw_set_transform(baseline, deg_to_rad(letter["rotation"]), Vector2.ONE)
		_draw_shadowed_label(Vector2.ZERO, letter["char"], font_size, _with_alpha(Color("08101b"), 0.78), Color(letter["color"]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		advance_x += ThemeDB.fallback_font.get_string_size(letter["char"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x - 4.0


func _draw_metric_card(rect: Rect2, label: String, value: String, accent: Color, value_size: int) -> void:
	_draw_panel(rect, Color("0c1321", 0.7), _with_alpha(_theme_color("rail"), 0.18))
	_draw_label(rect.position + Vector2(16.0, 22.0), label.to_upper(), 13, Color("a8bac7"))
	_draw_label(rect.position + Vector2(16.0, 54.0), value, value_size, accent)


func _draw_heart_icon(pos: Vector2, pulse: float) -> void:
	var scale := 0.95 + pulse * 0.18
	var red := Color("ff6f97")
	draw_circle(pos + Vector2(-4.0, -3.0) * scale, 5.8 * scale, red)
	draw_circle(pos + Vector2(4.0, -3.0) * scale, 5.8 * scale, red)
	draw_colored_polygon(
		PackedVector2Array([
			pos + Vector2(-9.0, -0.5) * scale,
			pos + Vector2(0.0, 10.5) * scale,
			pos + Vector2(9.0, -0.5) * scale
		]),
		red
	)
	draw_circle(pos + Vector2(-2.0, -5.0) * scale, 1.8 * scale, _with_alpha(Color.WHITE, 0.46))


func _draw_shield_icon(pos: Vector2, pulse: float) -> void:
	var scale := 0.92 + pulse * 0.16
	var outer := PackedVector2Array([
		pos + Vector2(0.0, -10.0) * scale,
		pos + Vector2(8.0, -6.0) * scale,
		pos + Vector2(7.0, 4.0) * scale,
		pos + Vector2(0.0, 11.0) * scale,
		pos + Vector2(-7.0, 4.0) * scale,
		pos + Vector2(-8.0, -6.0) * scale
	])
	draw_colored_polygon(outer, Color("78ecff"))
	draw_colored_polygon(outer, _with_alpha(Color("142d58"), 0.18))
	var inner := PackedVector2Array([
		pos + Vector2(0.0, -6.0) * scale,
		pos + Vector2(4.8, -3.0) * scale,
		pos + Vector2(4.2, 2.5) * scale,
		pos + Vector2(0.0, 7.0) * scale,
		pos + Vector2(-4.2, 2.5) * scale,
		pos + Vector2(-4.8, -3.0) * scale
	])
	draw_colored_polygon(inner, Color("dfffff"))
	draw_line(pos + Vector2(0.0, -4.5) * scale, pos + Vector2(0.0, 5.5) * scale, _with_alpha(Color("1d567b"), 0.55), 1.4)


func _draw_bomb_icon(pos: Vector2, pulse: float) -> void:
	var scale := 0.94 + pulse * 0.18
	var body := Color("2b2231")
	var rim := Color("ffb060")
	draw_circle(pos + Vector2(0.0, 1.0) * scale, 8.2 * scale, body)
	draw_circle(pos + Vector2(0.0, 1.0) * scale, 8.2 * scale, _with_alpha(rim, 0.18))
	draw_circle(pos + Vector2(-2.6, -2.4) * scale, 2.0 * scale, _with_alpha(Color.WHITE, 0.25))
	draw_line(pos + Vector2(2.0, -5.0) * scale, pos + Vector2(6.5, -10.0) * scale, Color("ffd27a"), 1.8)
	draw_line(pos + Vector2(6.5, -10.0) * scale, pos + Vector2(9.0, -8.6) * scale, Color("ff8f54"), 1.6)
	for ray in range(4):
		var angle := title_phase * 5.0 + ray * PI * 0.5
		var ray_dir := Vector2(cos(angle), sin(angle))
		draw_line(pos + Vector2(9.0, -8.6) * scale, pos + Vector2(9.0, -8.6) * scale + ray_dir * 3.0 * scale, _with_alpha(Color("ffe68c"), 0.8), 1.0)


func _draw_cookie_icon(pos: Vector2, pulse: float) -> void:
	var scale := 0.94 + pulse * 0.18
	var dough := Color("d99146")
	draw_circle(pos, 8.2 * scale, dough)
	draw_circle(pos + Vector2(-2.5, -2.0) * scale, 2.1 * scale, Color("7d4722"))
	draw_circle(pos + Vector2(3.2, -1.0) * scale, 1.8 * scale, Color("8a4e27"))
	draw_circle(pos + Vector2(1.6, 3.3) * scale, 2.0 * scale, Color("6f3d1a"))
	draw_circle(pos + Vector2(-4.0, 2.6) * scale, 1.5 * scale, Color("7a4520"))
	draw_circle(pos + Vector2(-1.2, -3.2) * scale, 1.6 * scale, _with_alpha(Color.WHITE, 0.18))


func _draw_toggle_pill(rect: Rect2, text: String, active: bool) -> void:
	var fill := Color("153545", 0.92) if active else Color("111720", 0.96)
	var stroke := _with_alpha(Color("7cf5ff"), 0.46) if active else _with_alpha(Color("ffe27d"), 0.16)
	_draw_panel(rect, fill, stroke)
	_draw_centered_label(Vector2(rect.get_center().x, rect.position.y + 23.0), text, 15, Color("f6fdff"))


func _draw_action_pill(rect: Rect2, text: String) -> void:
	_draw_panel(rect, Color("ffe27d"), _with_alpha(Color("fff5bf"), 0.42))
	_draw_centered_label(Vector2(rect.get_center().x, rect.position.y + 23.0), text, 17, Color("171008"))


func _draw_stepper(rect: Rect2, value: String) -> void:
	var left := _control_step_rect(rect, "left")
	var right := _control_step_rect(rect, "right")
	var center := Rect2(rect.position + Vector2(34.0, 0.0), Vector2(rect.size.x - 68.0, rect.size.y))
	_draw_toggle_pill(left, "-", false)
	_draw_toggle_pill(center, value, true)
	_draw_toggle_pill(right, "+", false)


func _draw_cycle_pill(rect: Rect2, value: String) -> void:
	var left := _control_step_rect(rect, "left")
	var right := _control_step_rect(rect, "right")
	var center := Rect2(rect.position + Vector2(34.0, 0.0), Vector2(rect.size.x - 68.0, rect.size.y))
	_draw_toggle_pill(left, "<", false)
	_draw_toggle_pill(center, value, true)
	_draw_toggle_pill(right, ">", false)


func _draw_panel(rect: Rect2, fill: Color, stroke: Color) -> void:
	draw_rect(rect.grow(12.0), _with_alpha(Color.BLACK, 0.08), true)
	draw_rect(rect, fill, true)
	var gloss_height: float = max(16.0, rect.size.y * 0.22)
	draw_rect(Rect2(rect.position + Vector2(10.0, 10.0), Vector2(rect.size.x - 20.0, gloss_height)), _with_alpha(Color.WHITE, min(0.12, fill.a * 0.22)), true)
	draw_rect(rect, stroke, false, 2.0)
	draw_rect(rect.grow(-8.0), _with_alpha(stroke, stroke.a * 0.28), false, 1.0)


func _draw_progress_bar(rect: Rect2, ratio: float, start_color: Color, end_color: Color) -> void:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	draw_rect(rect, _with_alpha(Color.BLACK, 0.34), true)
	var fill_width: float = max(8.0, rect.size.x * clamped_ratio)
	draw_rect(Rect2(rect.position, Vector2(fill_width, rect.size.y)), start_color.lerp(end_color, 0.5), true)
	draw_rect(Rect2(rect.position + Vector2(3.0, 2.0), Vector2(max(0.0, fill_width - 6.0), max(0.0, rect.size.y * 0.45))), _with_alpha(Color.WHITE, 0.16), true)
	draw_rect(rect, _with_alpha(Color.WHITE, 0.12), false, 1.0)


func _draw_candy_frame(board: Rect2) -> void:
	var frame := board.grow(24.0)
	draw_rect(frame, _with_alpha(Color("ff5fa2"), 0.18), true)
	draw_rect(frame.grow(-8.0), _with_alpha(Color("6df8ff"), 0.14), true)
	draw_rect(frame, _with_alpha(Color("ffe476"), 0.42), false, 4.0)
	draw_rect(frame.grow(-10.0), _with_alpha(Color("ff7cb8"), 0.34), false, 3.0)
	for index in range(22):
		var px := frame.position.x + 18.0 + index * ((frame.size.x - 36.0) / 21.0)
		var top_color := Color("ffe66d") if index % 2 == 0 else Color("76faff")
		var bottom_color := Color("ff8ec6") if index % 2 == 0 else Color("fff4cf")
		draw_circle(Vector2(px, frame.position.y + 12.0), 4.5, top_color)
		draw_circle(Vector2(px, frame.end.y - 12.0), 4.5, bottom_color)
	for index in range(12):
		var py := frame.position.y + 26.0 + index * ((frame.size.y - 52.0) / 11.0)
		var left_color := Color("ff82cb") if index % 2 == 0 else Color("fff0a9")
		var right_color := Color("77fbff") if index % 2 == 0 else Color("ffd879")
		draw_circle(Vector2(frame.position.x + 12.0, py), 4.0, left_color)
		draw_circle(Vector2(frame.end.x - 12.0, py), 4.0, right_color)
