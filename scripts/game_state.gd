class_name PuzzleState
extends Node
## Local-first game progress. Every public result is a copy so callers cannot
## accidentally mutate rewards, ownership, or the saved session metadata.

signal changed
signal storage_error(message: String)

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://piecepop_save.json"
const STARTER_COINS: int = 100
const GRIDS: Array[int] = [6, 10, 12, 16, 20]
const REWARDS: Dictionary = {6: 25, 10: 60, 12: 85, 16: 130, 20: 200}
const CATALOG: Array[Dictionary] = [
	{"id": "alpine_escape", "title": "Alpine Escape", "category": "Nature", "tagline": "A little fresh air, piece by piece.", "asset": "res://assets/puzzles/alpine_escape.png", "accent": "#36C6C8", "price": 0},
	{"id": "coral_cove", "title": "Coral Cove", "category": "Nature", "tagline": "Dive into a world of wonder.", "asset": "res://assets/puzzles/coral_cove.svg", "accent": "#4398ED", "price": 0},
	{"id": "citrus_sunshine", "title": "Citrus Sunshine", "category": "Art", "tagline": "Your daily squeeze of happy.", "asset": "res://assets/puzzles/citrus_sunshine.svg", "accent": "#FFB949", "price": 0},
	{"id": "moonlight_meadow", "title": "Moonlight Meadow", "category": "Nature", "tagline": "Let your imagination bloom.", "asset": "res://assets/puzzles/moonlight_meadow.svg", "accent": "#A07DE9", "price": 0},
	{"id": "toucan_tropics", "title": "Toucan Tropics", "category": "Animals", "tagline": "A colorful escape to the canopy.", "asset": "res://assets/puzzles/toucan_tropics.svg", "accent": "#F274A9", "price": 120},
	{"id": "candy_coast", "title": "Candy Coast", "category": "Art", "tagline": "Sweet little pieces of paradise.", "asset": "res://assets/puzzles/candy_coast.svg", "accent": "#B58BF0", "price": 180},
	{"id": "sakura_stroll", "title": "Sakura Stroll", "category": "Places", "tagline": "Follow the petals to somewhere lovely.", "asset": "res://assets/puzzles/sakura_stroll.png", "accent": "#F37CB8", "price": 0, "is_new": true},
	{"id": "rainbow_harbor", "title": "Rainbow Harbor", "category": "Places", "tagline": "Colorful houses, sunny little discoveries.", "asset": "res://assets/puzzles/rainbow_harbor.png", "accent": "#39BDDA", "price": 0, "is_new": true},
	{"id": "starlight_castle", "title": "Starlight Castle", "category": "Fantasy", "tagline": "Build a wish beneath the stars.", "asset": "res://assets/puzzles/starlight_castle.png", "accent": "#AA80F3", "price": 200, "is_new": true},
	{"id": "foxglove_forest", "title": "Foxglove Forest", "category": "Animals", "tagline": "A woodland friend is waiting for you.", "asset": "res://assets/puzzles/foxglove_forest.png", "accent": "#E88C56", "price": 0, "is_new": true},
	{"id": "penguin_party", "title": "Penguin Party", "category": "Animals", "tagline": "Cool little friends. Warm little smiles.", "asset": "res://assets/puzzles/penguin_party.png", "accent": "#49BCE8", "price": 0, "is_new": true},
	{"id": "balloon_valley", "title": "Balloon Valley", "category": "Fantasy", "tagline": "Let your imagination float away.", "asset": "res://assets/puzzles/balloon_valley.png", "accent": "#EF75B2", "price": 0, "is_new": true},
	{"id": "cactus_carnival", "title": "Cactus Carnival", "category": "Nature", "tagline": "A prickly patch of sunshine.", "asset": "res://assets/puzzles/cactus_carnival.svg", "accent": "#35C9B3", "price": 0, "is_new": true},
	{"id": "waterfall_wonder", "title": "Waterfall Wonder", "category": "Nature", "tagline": "Chase a rainbow through the mist.", "asset": "res://assets/puzzles/waterfall_wonder.svg", "accent": "#38BFD6", "price": 0, "is_new": true},
	{"id": "sunflower_fields", "title": "Sunflower Fields", "category": "Nature", "tagline": "A whole field of happy faces.", "asset": "res://assets/puzzles/sunflower_fields.svg", "accent": "#EFB846", "price": 0, "is_new": true},
	{"id": "autumn_river", "title": "Autumn River", "category": "Nature", "tagline": "Follow the golden leaves downstream.", "asset": "res://assets/puzzles/autumn_river.svg", "accent": "#EF9158", "price": 0, "is_new": true},
	{"id": "lighthouse_bay", "title": "Lighthouse Bay", "category": "Places", "tagline": "A bright welcome by the sea.", "asset": "res://assets/puzzles/lighthouse_bay.svg", "accent": "#5FA6E8", "price": 140, "is_new": true},
	{"id": "lavender_hills", "title": "Lavender Hills", "category": "Nature", "tagline": "Rolling ribbons of purple delight.", "asset": "res://assets/puzzles/lavender_hills.svg", "accent": "#AD83EA", "price": 160, "is_new": true},
	{"id": "panda_picnic", "title": "Panda Picnic", "category": "Animals", "tagline": "Bring a friend and a little curiosity.", "asset": "res://assets/puzzles/panda_picnic.svg", "accent": "#45C9AE", "price": 0, "is_new": true},
	{"id": "otter_oasis", "title": "Otter Oasis", "category": "Animals", "tagline": "Float into a playful little escape.", "asset": "res://assets/puzzles/otter_oasis.svg", "accent": "#53BBDB", "price": 180, "is_new": true},
	{"id": "butterfly_garden", "title": "Butterfly Garden", "category": "Animals", "tagline": "Every wing has a story to tell.", "asset": "res://assets/puzzles/butterfly_garden.svg", "accent": "#EB80C0", "price": 0, "is_new": true},
	{"id": "jellyfish_jubilee", "title": "Jellyfish Jubilee", "category": "Animals", "tagline": "A glowing dance beneath the waves.", "asset": "res://assets/puzzles/jellyfish_jubilee.svg", "accent": "#9583F1", "price": 160, "is_new": true},
	{"id": "sweet_shop", "title": "Sweet Shop", "category": "Art", "tagline": "Pick a piece of something delicious.", "asset": "res://assets/puzzles/sweet_shop.svg", "accent": "#EC77AA", "price": 140, "is_new": true},
	{"id": "cosmic_carnival", "title": "Cosmic Carnival", "category": "Fantasy", "tagline": "The whole universe is here to play.", "asset": "res://assets/puzzles/cosmic_carnival.svg", "accent": "#AB79EA", "price": 200, "is_new": true},
]

var coins: int = STARTER_COINS
var background_index: int = 0
var sound_enabled: bool = true
var haptics_enabled: bool = true
var last_save_error: String = ""
var recovered_corrupt_save: bool = false
var storage_path: String

var _unlocked: Array[String] = []
var _sessions: Dictionary = {}


func _init(save_path: String = SAVE_PATH) -> void:
	storage_path = save_path
	_load_save()


func get_catalog() -> Array:
	return CATALOG.duplicate(true)


func get_free_catalog() -> Array:
	var free_puzzles: Array = []
	for puzzle: Dictionary in CATALOG:
		if int(puzzle.price) == 0:
			free_puzzles.append(puzzle.duplicate(true))
	return free_puzzles


func get_categories() -> Array[String]:
	var categories: Array[String] = []
	for puzzle: Dictionary in CATALOG:
		if puzzle.category not in categories:
			categories.append(puzzle.category)
	return categories


func puzzle_by_id(puzzle_id: String) -> Dictionary:
	for puzzle: Dictionary in CATALOG:
		if puzzle.id == puzzle_id:
			return puzzle.duplicate(true)
	return {}


func is_unlocked(puzzle_id: String) -> bool:
	var puzzle: Dictionary = puzzle_by_id(puzzle_id)
	return not puzzle.is_empty() and (int(puzzle.price) == 0 or puzzle_id in _unlocked)


func unlock_puzzle(puzzle_id: String) -> bool:
	if is_unlocked(puzzle_id):
		return true
	var puzzle: Dictionary = puzzle_by_id(puzzle_id)
	if puzzle.is_empty() or coins < int(puzzle.price):
		return false
	coins -= int(puzzle.price)
	_unlocked.append(puzzle_id)
	if not _save():
		coins += int(puzzle.price)
		_unlocked.erase(puzzle_id)
		return false
	changed.emit()
	return true


func daily_key() -> String:
	return Time.get_date_string_from_system(false)


func daily_puzzle(date_override: String = "") -> Dictionary:
	# This offline rotation is deterministic on every device for a local date.
	var free_puzzles: Array = get_free_catalog()
	if free_puzzles.is_empty():
		return {}
	var date: String = date_override if not date_override.is_empty() else daily_key()
	var day_number: int = int(Time.get_unix_time_from_datetime_string(date + "T00:00:00") / 86400.0)
	return free_puzzles[posmod(day_number, free_puzzles.size())]


func reward_for_grid(grid_size: int) -> int:
	return int(REWARDS.get(grid_size, 0))


func get_session(puzzle_id: String, grid_size: int, mystery: bool = false) -> Dictionary:
	return _sessions.get(_session_key(puzzle_id, grid_size, mystery), {}).duplicate(true)


func begin_session(puzzle_id: String, grid_size: int, mystery: bool = false, restart: bool = false) -> Dictionary:
	if not is_unlocked(puzzle_id) or grid_size not in GRIDS:
		return {}
	var key: String = _session_key(puzzle_id, grid_size, mystery)
	var previous: Dictionary = _sessions.get(key, {})
	if not previous.is_empty() and not restart:
		return previous.duplicate(true)
	var session: Dictionary = {
		"id": puzzle_id,
		"grid": grid_size,
		"mystery": mystery,
		"state": {},
		"completed": false,
		"awarded": false,
		"progress": 0.0,
		"run_id": int(previous.get("run_id", 0)) + 1,
		"updated_at": int(Time.get_unix_time_from_system()),
	}
	_sessions[key] = session
	_save()
	changed.emit()
	return session.duplicate(true)


func save_session(puzzle_id: String, grid_size: int, mystery: bool, state: Dictionary) -> void:
	if not is_unlocked(puzzle_id) or grid_size not in GRIDS:
		return
	var key: String = _session_key(puzzle_id, grid_size, mystery)
	if not _sessions.has(key):
		begin_session(puzzle_id, grid_size, mystery)
	var session: Dictionary = _sessions[key]
	# A completed run stays immutable until the player explicitly starts over.
	if bool(session.completed):
		return
	session.state = state.duplicate(true)
	session.progress = float(_placed_count(state, grid_size)) / float(grid_size * grid_size)
	session.updated_at = int(Time.get_unix_time_from_system())
	_save()
	changed.emit()


func complete_puzzle(puzzle_id: String, grid_size: int, mystery: bool = false) -> int:
	var key: String = _session_key(puzzle_id, grid_size, mystery)
	if not _sessions.has(key) or not is_unlocked(puzzle_id) or grid_size not in GRIDS:
		return 0
	var session: Dictionary = _sessions[key]
	if bool(session.completed) or bool(session.awarded):
		return 0
	if _placed_count(session.state, grid_size) != grid_size * grid_size:
		return 0
	var reward: int = reward_for_grid(grid_size)
	session.completed = true
	session.awarded = true
	session.progress = 1.0
	session.updated_at = int(Time.get_unix_time_from_system())
	coins += reward
	if not _save():
		coins -= reward
		session.completed = false
		session.awarded = false
		return 0
	changed.emit()
	return reward


func get_sessions() -> Array:
	var result: Array = _sessions.values().duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.updated_at) > int(b.updated_at))
	return result


func set_preferences(preferences: Dictionary) -> void:
	if preferences.has("background_index"):
		background_index = clampi(int(preferences.background_index), 0, 3)
	if preferences.has("sound_enabled"):
		sound_enabled = bool(preferences.sound_enabled)
	if preferences.has("haptics_enabled"):
		haptics_enabled = bool(preferences.haptics_enabled)
	_save()
	changed.emit()


func _session_key(puzzle_id: String, grid_size: int, mystery: bool) -> String:
	return "%s:%d:%s" % [puzzle_id, grid_size, "mystery" if mystery else "classic"]


func _placed_count(state: Dictionary, grid_size: int) -> int:
	var placed: Variant = state.get("placed", [])
	if not placed is Array:
		return 0
	var unique: Dictionary = {}
	for piece_id: Variant in placed:
		if _is_integer(piece_id, 0, grid_size * grid_size - 1):
			unique[int(piece_id)] = true
	return unique.size()


func _save() -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"coins": coins,
		"unlocked": _unlocked,
		"preferences": {
			"background_index": background_index,
			"sound_enabled": sound_enabled,
			"haptics_enabled": haptics_enabled,
		},
		"sessions": _sessions,
	}
	var absolute: String = ProjectSettings.globalize_path(storage_path)
	var make_error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if make_error != OK:
		return _storage_failure("Cannot create the save folder (error %d)." % make_error)
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _storage_failure("Cannot open the save file (error %d)." % FileAccess.get_open_error())
	file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _storage_failure("Cannot write progress (error %d)." % write_error)
	var rename_error: Error = DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		return _storage_failure("Cannot finish saving progress (error %d)." % rename_error)
	last_save_error = ""
	return true


func _load_save() -> void:
	if not FileAccess.file_exists(storage_path):
		return
	var file: FileAccess = FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		_storage_failure("Cannot read saved progress (error %d)." % FileAccess.get_open_error())
		return
	if file.get_length() > 20 * 1024 * 1024:
		file.close()
		_recover_corrupt_save()
		return
	var raw: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(raw) != OK or not _valid_payload(json.data):
		_recover_corrupt_save()
		return
	var payload: Dictionary = json.data
	coins = int(payload.coins)
	_unlocked.assign(payload.unlocked)
	background_index = int(payload.preferences.background_index)
	sound_enabled = bool(payload.preferences.sound_enabled)
	haptics_enabled = bool(payload.preferences.haptics_enabled)
	_sessions = payload.sessions.duplicate(true)
	for key: String in _sessions:
		var session: Dictionary = _sessions[key]
		session.grid = int(session.grid)
		session.run_id = int(session.run_id)
		session.updated_at = int(session.updated_at)
		if session.state.get("placed") is Array:
			var placed: Array[int] = []
			for piece_id: Variant in session.state.placed:
				if _is_integer(piece_id, 0, session.grid * session.grid - 1) and int(piece_id) not in placed:
					placed.append(int(piece_id))
			session.state.placed = placed
		session.progress = 1.0 if session.completed else float(_placed_count(session.state, session.grid)) / float(session.grid * session.grid)


func _valid_payload(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var payload: Dictionary = value
	if not _is_integer(payload.get("version"), SAVE_VERSION, SAVE_VERSION):
		return false
	if not _is_integer(payload.get("coins"), 0, 1000000000):
		return false
	if not payload.get("unlocked") is Array or not payload.get("preferences") is Dictionary or not payload.get("sessions") is Dictionary:
		return false
	for puzzle_id: Variant in payload.unlocked:
		if not puzzle_id is String or puzzle_by_id(puzzle_id).is_empty():
			return false
	var preferences: Dictionary = payload.preferences
	if not _is_integer(preferences.get("background_index"), 0, 3):
		return false
	if not preferences.get("sound_enabled") is bool or not preferences.get("haptics_enabled") is bool:
		return false
	if payload.sessions.size() > CATALOG.size() * GRIDS.size() * 2:
		return false
	for key: Variant in payload.sessions:
		var entry: Variant = payload.sessions[key]
		if not key is String or not entry is Dictionary:
			return false
		if not entry.get("id") is String or puzzle_by_id(entry.id).is_empty():
			return false
		if not _is_integer(entry.get("grid"), 6, 20) or int(entry.grid) not in GRIDS:
			return false
		if not entry.get("mystery") is bool or not entry.get("state") is Dictionary:
			return false
		if not entry.get("completed") is bool or not entry.get("awarded") is bool:
			return false
		if entry.completed != entry.awarded:
			return false
		if not _is_integer(entry.get("run_id"), 1, 1000000000) or not _is_integer(entry.get("updated_at"), 0, 100000000000):
			return false
		if key != _session_key(entry.id, int(entry.grid), entry.mystery):
			return false
		if entry.completed and _placed_count(entry.state, int(entry.grid)) != int(entry.grid) * int(entry.grid):
			return false
	return true


func _is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	if not is_finite(float(value)):
		return false
	return float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


func _recover_corrupt_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(storage_path)
	var backup: String = absolute + ".corrupt-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var backup_error: Error = DirAccess.rename_absolute(absolute, backup)
	if backup_error != OK:
		_storage_failure("Saved progress is invalid; the original could not be backed up (error %d)." % backup_error)
		return
	recovered_corrupt_save = true
	_save()


func _storage_failure(message: String) -> bool:
	last_save_error = message
	storage_error.emit(message)
	return false
