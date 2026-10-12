extends SceneTree

const State = preload("res://scripts/game_state.gd")
var failures: int = 0
var checks: int = 0
var temporary_dir: String


func _init() -> void:
	temporary_dir = "/tmp/piecepop-state-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(temporary_dir)
	_test_catalog_and_daily()
	_test_progress_and_rewards()
	_test_corruption_recovery()
	_test_invalid_shapes()
	for file_name: String in DirAccess.get_files_at(temporary_dir):
		DirAccess.remove_absolute(temporary_dir.path_join(file_name))
	DirAccess.remove_absolute(temporary_dir)
	print("PuzzleState: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_catalog_and_daily() -> void:
	var state: Node = State.new(temporary_dir.path_join("catalog.json"))
	_check(state.get_catalog().size() == 44, "All 44 puzzles must be available.")
	_check(state.get_free_catalog().size() == 28, "Daily collection includes all 28 free puzzles.")
	_check(state.get_categories() == ["Nature", "Art", "Animals", "Places", "Fantasy", "Food", "Space", "Dinosaurs", "Festivals", "Cozy Rooms", "Architecture"], "Categories are derived in catalog order.")
	_check(state.coins == 100, "Fresh player starts with 100 coins.")
	_check(state.is_unlocked("alpine_escape"), "Starter artwork is free.")
	_check(not state.is_unlocked("unknown"), "Unknown artwork cannot be unlocked.")
	_check(not state.unlock_puzzle("toucan_tropics"), "Insufficient funds must reject a purchase.")
	_check(state.coins == 100, "Failed purchase cannot deduct coins.")
	_check(state.begin_session("toucan_tropics", 6).is_empty(), "Locked puzzles cannot start.")
	_check(state.begin_session("alpine_escape", 7).is_empty(), "Unsupported difficulties cannot start.")
	var copy: Array = state.get_catalog()
	copy[0]["price"] = 900
	_check(state.puzzle_by_id("alpine_escape").price == 0, "Catalog results cannot mutate ownership.")
	_check(state.daily_puzzle("2026-10-09") == state.daily_puzzle("2026-10-09"), "Daily selection is stable.")
	_check(state.daily_puzzle("2026-10-09").id != state.daily_puzzle("2026-10-10").id, "Daily rotation changes on the following day.")
	_check(state.daily_puzzle("2026-10-09").price == 0, "Daily selection is always free.")
	_check(state.daily_key() == Time.get_date_string_from_system(false), "Daily key uses the local calendar date.")
	state.free()


func _test_progress_and_rewards() -> void:
	var path: String = temporary_dir.path_join("progress.json")
	var state: Node = State.new(path)
	var first: Dictionary = state.begin_session("alpine_escape", 6)
	_check(first.run_id == 1, "Initial run has an identity.")
	state.save_session("alpine_escape", 6, false, {"placed": [0, 1], "positions": {"2": [1.5, 2.5]}, "zoom": 1.75})
	_check(is_equal_approx(state.get_session("alpine_escape", 6).progress, 2.0 / 36.0), "Progress counts placed pieces.")
	_check(state.complete_puzzle("alpine_escape", 6) == 0, "Incomplete board cannot claim rewards.")
	state.begin_session("alpine_escape", 10)
	state.begin_session("alpine_escape", 6, true)
	state.save_session("alpine_escape", 6, true, {"placed": [3]})
	state.set_preferences({"background_index": 2, "sound_enabled": false, "haptics_enabled": false})
	state.free()
	state = State.new(path)
	_check(state.get_sessions().size() == 3, "Grid and mystery sessions persist independently.")
	_check(state.get_session("alpine_escape", 6).state.placed == [0, 1], "Placed pieces survive a reload.")
	_check(state.get_session("alpine_escape", 6).state.positions["2"] == [1.5, 2.5], "Loose coordinates survive a reload.")
	_check(state.get_session("alpine_escape", 6, true).state.placed == [3], "Mystery state stays separate.")
	_check(state.background_index == 2 and not state.sound_enabled and not state.haptics_enabled, "Preferences persist.")
	var duplicate_ids: Array = []
	duplicate_ids.resize(36)
	duplicate_ids.fill(0)
	state.save_session("alpine_escape", 6, false, {"placed": duplicate_ids})
	_check(state.complete_puzzle("alpine_escape", 6) == 0, "Duplicate placed ids cannot fake completion.")
	state.save_session("alpine_escape", 6, false, {"placed": range(36)})
	_check(state.complete_puzzle("alpine_escape", 6) == 25, "Completed easy puzzle grants 25 coins.")
	_check(state.complete_puzzle("alpine_escape", 6) == 0, "Repeated completion cannot grant duplicate coins.")
	_check(state.coins == 125, "Only one reward was added.")
	_check(state.unlock_puzzle("toucan_tropics"), "Earned coins can unlock a collection.")
	_check(state.coins == 5, "Purchase subtracts the listed price.")
	_check(state.unlock_puzzle("toucan_tropics") and state.coins == 5, "Owned puzzles cannot charge twice.")
	state.free()
	state = State.new(path)
	_check(state.is_unlocked("toucan_tropics"), "Purchased content persists across launches.")
	_check(state.complete_puzzle("alpine_escape", 6) == 0, "Reload cannot re-award completed sessions.")
	_check(state.begin_session("alpine_escape", 6).completed, "Opening a finished run preserves its result.")
	var replay: Dictionary = state.begin_session("alpine_escape", 6, false, true)
	_check(replay.run_id == 2 and replay.state.is_empty() and not replay.completed, "Explicit replay resets the board with a new run.")
	_check(state.complete_puzzle("alpine_escape", 6) == 0, "Restart alone cannot earn a reward.")
	state.save_session("alpine_escape", 6, false, {"placed": range(36)})
	_check(state.complete_puzzle("alpine_escape", 6) == 25, "A fully solved replay earns one reward.")
	_check(state.reward_for_grid(20) == 200 and state.reward_for_grid(7) == 0, "Difficulty rewards match supported grids.")
	state.free()


func _test_corruption_recovery() -> void:
	var path: String = temporary_dir.path_join("corrupt.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ truncated save")
	file.close()
	var state: Node = State.new(path)
	_check(state.recovered_corrupt_save, "Corrupt JSON is recovered.")
	_check(state.coins == 100 and state.get_sessions().is_empty(), "Recovery restores safe defaults.")
	var backup_exists: bool = false
	for file_name: String in DirAccess.get_files_at(temporary_dir):
		if file_name.begins_with("corrupt.json.corrupt-"):
			backup_exists = FileAccess.get_file_as_string(temporary_dir.path_join(file_name)) == "{ truncated save"
	_check(backup_exists, "Original corrupt bytes are preserved in a backup.")
	state.free()
	state = State.new(path)
	_check(not state.recovered_corrupt_save, "Recovered save loads cleanly on the next launch.")
	state.free()


func _test_invalid_shapes() -> void:
	var path: String = temporary_dir.path_join("invalid.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "coins": -900, "unlocked": [], "preferences": {}, "sessions": []}))
	file.close()
	var state: Node = State.new(path)
	_check(state.recovered_corrupt_save and state.coins == 100, "Invalid save shapes cannot inject bad balances.")
	state.free()
