extends SceneTree
## Expanded artwork, daily rotation, difficulty support, and version-1 saves.

const State = preload("res://scripts/game_state.gd")
const Board = preload("res://scripts/puzzle_board.gd")
const NEW_IDS: Array[String] = [
	"sakura_stroll", "rainbow_harbor", "starlight_castle", "foxglove_forest",
	"penguin_party", "balloon_valley", "cactus_carnival", "waterfall_wonder",
	"sunflower_fields", "autumn_river", "lighthouse_bay", "lavender_hills",
	"panda_picnic", "otter_oasis", "butterfly_garden", "jellyfish_jubilee",
	"sweet_shop", "cosmic_carnival",
]
const ORIGINAL: Dictionary = {
	"alpine_escape": [0, "png"], "coral_cove": [0, "svg"],
	"citrus_sunshine": [0, "svg"], "moonlight_meadow": [0, "svg"],
	"toucan_tropics": [120, "svg"], "candy_coast": [180, "svg"],
}

var checks: int = 0
var failures: int = 0
var temporary_dir: String


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	temporary_dir = "/tmp/piecepop-catalog-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(temporary_dir)
	var state: Node = State.new(temporary_dir.path_join("catalog.json"))
	_check(state.get_catalog().size() == 24, "The collection contains 24 puzzles.")
	_check(state.get_free_catalog().size() == 15, "The collection contains 15 free puzzles.")
	_check(state.get_categories() == ["Nature", "Art", "Animals", "Places", "Fantasy"], "All categories are derived in first-seen order.")
	var ids: Dictionary = {}
	var asset_paths: Dictionary = {}
	var paid_count: int = 0
	for puzzle: Dictionary in state.get_catalog():
		_check(not ids.has(puzzle.id), "Puzzle id is unique: " + puzzle.id)
		_check(not asset_paths.has(puzzle.asset), "Artwork is distinct: " + puzzle.asset)
		ids[puzzle.id] = true
		asset_paths[puzzle.asset] = true
		_check(not puzzle.title.is_empty() and not puzzle.tagline.is_empty(), "Puzzle has display copy: " + puzzle.id)
		_check(Color.html_is_valid(puzzle.accent), "Puzzle has a valid accent: " + puzzle.id)
		if int(puzzle.price) > 0:
			paid_count += 1
		_check(FileAccess.file_exists(puzzle.asset), "Artwork source exists: " + puzzle.asset)
		if not FileAccess.file_exists(puzzle.asset):
			continue
		var texture: Texture2D = load(puzzle.asset) as Texture2D
		_check(texture != null, "Godot imports artwork: " + puzzle.id)
		if texture != null:
			_check(texture.get_width() >= 1024 and texture.get_height() >= 1024, "Artwork is large enough for 400 pieces: " + puzzle.id)
	_check(paid_count == 9, "Nine collections can be unlocked with earned coins.")
	for puzzle_id: String in ORIGINAL:
		var original: Dictionary = state.puzzle_by_id(puzzle_id)
		_check(not original.is_empty(), "Original puzzle is retained: " + puzzle_id)
		_check(int(original.price) == int(ORIGINAL[puzzle_id][0]), "Original price is unchanged: " + puzzle_id)
		_check(original.asset == "res://assets/puzzles/%s.%s" % [puzzle_id, ORIGINAL[puzzle_id][1]], "Original artwork path is unchanged: " + puzzle_id)
		_check(not original.get("is_new", false), "Original artwork is not mislabeled as new: " + puzzle_id)
	for puzzle_id: String in NEW_IDS:
		_check(state.puzzle_by_id(puzzle_id).get("is_new", false), "Added artwork is marked new: " + puzzle_id)
	var copied_free: Array = state.get_free_catalog()
	copied_free[0].price = 999
	_check(state.get_free_catalog()[0].price == 0, "Free catalog entries cannot mutate catalog ownership.")
	_test_daily_rotation(state)
	_test_new_difficulties(state)
	state.free()
	_test_original_save_compatibility()
	for file_name: String in DirAccess.get_files_at(temporary_dir):
		DirAccess.remove_absolute(temporary_dir.path_join(file_name))
	DirAccess.remove_absolute(temporary_dir)
	print("Piecepop expanded catalog: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_daily_rotation(state: Node) -> void:
	var seen: Dictionary = {}
	var free_puzzles: Array = state.get_free_catalog()
	# Cross a leap day as well as a month boundary.
	var start: int = int(Time.get_unix_time_from_datetime_string("2028-02-24T00:00:00"))
	for day: int in range(free_puzzles.size()):
		var date: String = Time.get_date_string_from_unix_time(start + day * 86400)
		var chosen: Dictionary = state.daily_puzzle(date)
		_check(int(chosen.price) == 0, "Daily puzzle is free on " + date)
		_check(not seen.has(chosen.id), "Each free puzzle appears once per daily cycle: " + chosen.id)
		_check(state.daily_puzzle(date).id == chosen.id, "Daily choice is stable on " + date)
		seen[chosen.id] = true
	_check(seen.size() == free_puzzles.size(), "Daily rotation reaches the whole free collection.")
	for puzzle: Dictionary in free_puzzles:
		_check(seen.has(puzzle.id), "Daily rotation includes " + puzzle.id)
	var next_cycle: String = Time.get_date_string_from_unix_time(start + free_puzzles.size() * 86400)
	_check(state.daily_puzzle("2028-02-24").id == state.daily_puzzle(next_cycle).id, "Daily cycle repeats deterministically after all free puzzles.")
	state.coins = 10000
	for puzzle: Dictionary in state.get_catalog():
		state.unlock_puzzle(puzzle.id)
	_check(state.daily_puzzle("2028-02-24").id == state.daily_puzzle(next_cycle).id, "Purchases do not change the shared free daily rotation.")


func _test_new_difficulties(state: Node) -> void:
	var board: Control = Board.new()
	board.size = Vector2(480, 642)
	root.add_child(board)
	for puzzle_id: String in NEW_IDS:
		var puzzle: Dictionary = state.puzzle_by_id(puzzle_id)
		var texture: Texture2D = null
		if FileAccess.file_exists(puzzle.asset):
			texture = load(puzzle.asset) as Texture2D
		for grid: int in State.GRIDS:
			var session: Dictionary = state.begin_session(puzzle_id, grid)
			_check(not session.is_empty() and int(session.grid) == grid, "%s supports %d pieces." % [puzzle_id, grid * grid])
			if texture != null:
				board.setup(texture, grid, int(puzzle_id.hash()))
				_check(board.pieces.size() == grid * grid, "%s builds all %d piece cutouts." % [puzzle_id, grid * grid])
				_check(board.puzzle_texture == texture, "%s uses its own artwork at %d pieces." % [puzzle_id, grid * grid])
			state.save_session(puzzle_id, grid, false, {"placed": [0, grid * grid - 1], "catalog_test": puzzle_id})
	board.free()
	var restored: Node = State.new(state.storage_path)
	_check(not restored.recovered_corrupt_save, "Expanded collection saves do not trigger legacy session-count limits.")
	_check(restored.get_sessions().size() == NEW_IDS.size() * State.GRIDS.size(), "All 90 new puzzle and difficulty combinations persist.")
	for puzzle_id: String in NEW_IDS:
		for grid: int in State.GRIDS:
			var session: Dictionary = restored.get_session(puzzle_id, grid)
			_check(not session.is_empty() and session.state.placed == [0, grid * grid - 1], "%s restores its %d-piece session." % [puzzle_id, grid * grid])
	restored.free()


func _test_original_save_compatibility() -> void:
	var path: String = temporary_dir.path_join("original-version-1.json")
	var original_session: Dictionary = {
		"id": "alpine_escape", "grid": 6, "mystery": false,
		"state": {"placed": [0, 1], "pieces": [{"id": 0, "location": 2, "x": 0, "y": 0, "group": 0}], "zoom": 1.5},
		"completed": false, "awarded": false, "progress": 2.0 / 36.0,
		"run_id": 3, "updated_at": 1780000000,
	}
	var payload: Dictionary = {
		"version": 1, "coins": 345, "unlocked": ["toucan_tropics", "candy_coast"],
		"preferences": {"background_index": 2, "sound_enabled": false, "haptics_enabled": true},
		"sessions": {"alpine_escape:6:classic": original_session},
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var before: String = FileAccess.get_file_as_string(path)
	var state: Node = State.new(path)
	_check(not state.recovered_corrupt_save, "A save from the original six-puzzle collection remains valid.")
	_check(state.coins == 345, "Expansion preserves the original coin balance.")
	_check(state.is_unlocked("toucan_tropics") and state.is_unlocked("candy_coast"), "Expansion preserves purchased original puzzles.")
	_check(state.background_index == 2 and not state.sound_enabled and state.haptics_enabled, "Expansion preserves original preferences.")
	var restored: Dictionary = state.get_session("alpine_escape", 6)
	_check(restored.run_id == 3 and restored.state.placed == [0, 1] and is_equal_approx(restored.state.zoom, 1.5), "Expansion preserves original session progress and replay identity.")
	_check(FileAccess.get_file_as_string(path) == before, "Reading an original save does not rewrite it.")
	state.begin_session("sakura_stroll", 20)
	state.save_session("sakura_stroll", 20, false, {"placed": [3, 399]})
	state.free()
	state = State.new(path)
	_check(state.coins == 345, "Starting a free new puzzle leaves original coins unchanged.")
	_check(state.is_unlocked("toucan_tropics") and state.is_unlocked("candy_coast"), "New progress does not remove original purchases.")
	_check(state.get_session("alpine_escape", 6) == restored, "New progress leaves the original session untouched.")
	_check(state.get_session("sakura_stroll", 20).state.placed == [3, 399], "New and original sessions can coexist in version 1.")
	_check(int(JSON.parse_string(FileAccess.get_file_as_string(path)).version) == 1, "No save version migration is needed.")
	state.free()
