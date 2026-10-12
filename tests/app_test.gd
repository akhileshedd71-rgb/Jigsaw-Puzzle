extends SceneTree
## Exercise real scene wiring using a fresh /tmp save, never the player's save.

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/game_state.gd")

var checks: int = 0
var failures: int = 0
var temporary_dir: String
var save_path: String
var app: Control


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _button(parent: Node, caption: String) -> Button:
	if parent == null:
		return null
	if parent is Button and (parent.text == caption or parent.tooltip_text == caption or _has_label(parent, caption)):
		return parent
	for child: Node in parent.get_children():
		var result: Button = _button(child, caption)
		if result != null:
			return result
	return null


func _has_label(parent: Node, caption: String) -> bool:
	if parent == null:
		return false
	if parent is Label and parent.text == caption:
		return true
	for child: Node in parent.get_children():
		if _has_label(child, caption):
			return true
	return false


func _first_image(parent: Node) -> TextureRect:
	if parent is TextureRect:
		return parent
	for child: Node in parent.get_children():
		var result: TextureRect = _first_image(child)
		if result != null:
			return result
	return null


func _gallery_grid(parent: Node) -> GridContainer:
	if parent is GridContainer:
		return parent
	for child: Node in parent.get_children():
		var result: GridContainer = _gallery_grid(child)
		if result != null:
			return result
	return null


func _gallery_titles() -> Array[String]:
	var titles: Array[String] = []
	var grid: GridContainer = _gallery_grid(app.page)
	if grid == null:
		return titles
	for card: Node in grid.get_children():
		if card is Button:
			titles.append(card.tooltip_text)
	return titles


func _settle_layout() -> void:
	# Gallery rebuilding defers scrolling until the new containers lay out.
	for frame: int in range(3):
		await process_frame


func _check_filter_visible(caption: String) -> void:
	var selected: Button = _button(app.page, caption)
	if selected == null:
		_check(false, "Selected gallery filter still exists: " + caption)
		return
	var ancestor: Node = selected.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if not ancestor is ScrollContainer:
		_check(false, "Gallery filters have a horizontal scroll viewport.")
		return
	var viewport: Rect2 = (ancestor as ScrollContainer).get_global_rect()
	var selected_rect: Rect2 = selected.get_global_rect()
	_check(selected_rect.position.x >= viewport.position.x - 1.0 and selected_rect.end.x <= viewport.end.x + 1.0,
		"Selected %s filter remains fully visible after gallery rebuild." % caption)


func _exercise_expanded_gallery() -> void:
	var all_titles: Array[String] = _gallery_titles()
	_check(all_titles.size() == 44 and _has_label(app.page, "44 little escapes"), "All filter displays the complete expanded gallery and its count.")
	_check(all_titles.find("Macaron Morning") == 0 and all_titles.find("Alpine Escape") == 20,
		"New artwork leads the gallery while all twenty-four previous puzzles remain available.")
	_check(app.textures.size() <= 3, "Gallery does not retain all full-resolution puzzle textures.")
	_check(app.thumbnails.size() == 44 and app.thumbnails.values().all(func(texture): return texture.get_width() == 512), "Gallery uses compact previews for the complete collection.")
	var previous_gallery: WeakRef = weakref(app.page)
	_press(app.page, "New")
	await _settle_layout()
	_check(previous_gallery.get_ref() == null, "Rebuilding the expanded gallery frees its previous card nodes.")
	var new_grid: GridContainer = _gallery_grid(app.page)
	_check(_gallery_titles().size() == 20 and _has_label(app.page, "20 little escapes"), "New filter displays exactly the twenty added puzzle cards.")
	_check(new_grid != null and _button(new_grid, "Alpine Escape") == null and _button(new_grid, "Toucan Tropics") == null and _button(new_grid, "Sakura Stroll") == null,
		"New filter excludes original gallery cards without counting the separate Alpine hero.")
	_check(_button(app.page, "Play Alpine Escape") != null, "The original featured puzzle remains playable while filtering new cards.")
	_check(new_grid != null and _has_label(_button(new_grid, "Macaron Morning"), "NEW"), "New artwork has its visible discovery badge.")
	_check_filter_visible("New")
	for category_case: Dictionary in [
		{"filter": "Food", "titles": ["Berry Brunch", "Gelato Parade", "Macaron Morning", "Sushi Symphony"]},
		{"filter": "Space", "titles": ["Comet Express", "Lunar Greenhouse", "Nebula Observatory", "Saturn Picnic"]},
		{"filter": "Dinosaurs", "titles": ["Dino Watering Hole", "Pterosaur Lagoon", "Triceratops Trail"]},
		{"filter": "Festivals", "titles": ["Carnival of Colors", "Lantern River", "Winter Market"]},
		{"filter": "Cozy Rooms", "titles": ["Artist Sunroom", "Baker Workshop", "Storybook Library"]},
		{"filter": "Architecture", "titles": ["Clockwork Square", "Floating Palazzo", "Mosaic Courtyard"]},
		{"filter": "Places", "titles": ["Lighthouse Bay", "Rainbow Harbor", "Sakura Stroll"]},
		{"filter": "Fantasy", "titles": ["Balloon Valley", "Cosmic Carnival", "Starlight Castle"]},
	]:
		_press(app.page, category_case.filter)
		await _settle_layout()
		var titles: Array[String] = _gallery_titles()
		titles.sort()
		_check(titles == category_case.titles and _has_label(app.page, "%d little escapes" % category_case.titles.size()),
			"%s filter displays its matching artwork cards and count." % category_case.filter)
		_check_filter_visible(category_case.filter)
	_press(app.page, "New")
	await _settle_layout()
	_press(_gallery_grid(app.page), "Macaron Morning")
	_check(is_instance_valid(app.overlay) and _button(app.overlay, "Let's play  ·  36 pieces") != null,
		"New free Macaron artwork opens directly in the difficulty chooser.")
	_press(app.overlay, "400")
	_press(app.overlay, "Let's play  ·  400 pieces")
	await process_frame
	_check(is_instance_valid(app.board) and app.grid_size == 20 and app.board.pieces.size() == 400,
		"New Macaron artwork starts a playable four-hundred-piece board.")
	_check(app.current_puzzle.id == "macaron_morning" and is_instance_valid(app.board) and is_instance_valid(app.board.puzzle_texture)
		and app.board.puzzle_texture.resource_path == "res://assets/puzzles/macaron_morning.png",
		"The new board renders Macaron artwork rather than a missing or previous texture.")
	_check(app.board.puzzle_texture.get_width() >= 1024, "Gameplay keeps the original PNG resolution rather than the gallery thumbnail.")
	_press(app.page, "Hint")
	var macaron_session: Dictionary = app.state.get_session("macaron_morning", 20)
	_check(app.board.placed_count == 1 and macaron_session.get("state", {}).get("placed", []).size() == 1,
		"A new four-hundred-piece puzzle saves real progress through the same gameplay flow.")
	_press(app.page, "Save and return to gallery")
	await _settle_layout()
	_press(app.page, "All")
	await _settle_layout()
	_check_filter_visible("All")
	_check(app.state.coins == 100 and app.state.get_session("alpine_escape", 6).is_empty(),
		"Exploring free new artwork preserves the balance and original puzzle's fresh session.")


func _press(parent: Node, caption: String) -> bool:
	var button: Button = _button(parent, caption)
	_check(button != null, "UI contains button: " + caption)
	if button == null:
		return false
	_check(not button.pressed.get_connections().is_empty(), "Button is connected: " + caption)
	button.pressed.emit()
	return true


func _replace_state() -> void:
	var old_state: Node = app.state
	app.remove_child(old_state)
	old_state.free()
	app.state = State.new(save_path)
	app.add_child(app.state)
	app.state.changed.connect(app._refresh_coins)
	app.state.storage_error.connect(func(message: String): app._toast(message))
	app._refresh_coins()


func _run() -> void:
	temporary_dir = "/tmp/piecepop-app-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(temporary_dir)
	save_path = temporary_dir.path_join("progress.json")
	root.size = Vector2i(480, 900)
	app = MainScene.instantiate()
	app.state = State.new(save_path)
	root.add_child(app)
	await process_frame
	await process_frame
	_check(app.state.storage_path == save_path, "The scene keeps the injected isolated save store.")
	_check(app.current_tab == "gallery", "App starts in the gallery.")
	_check(app.state.coins == 100, "Gallery displays a fresh 100-coin balance.")
	_check(app.state.puzzle_by_id("alpine_escape").asset.ends_with(".png"), "Hero catalog uses the generated Alpine Escape artwork.")
	_check(_button(app.page, "Toucan Tropics") != null, "Locked collection appears in gallery.")
	await _exercise_expanded_gallery()
	app._settings()
	_check(_button(app.overlay, "Privacy policy") != null, "Privacy policy is available from settings.")
	_press(app.overlay, "Privacy policy")
	await _settle_layout()
	var policy: Label = app.overlay.find_child("PrivacyText", true, false) as Label
	_check(policy != null and policy.text.contains("Akhilesh Mahto") and policy.text.contains("akhileshedd@gmail.com"), "The offline privacy policy identifies the developer and support contact.")
	_check(policy != null and policy.text.contains("com.akhileshedd.piecepop"), "The privacy policy matches the release application ID.")
	var privacy_scroll: ScrollContainer = app.overlay.find_child("PrivacyScroll", true, false) as ScrollContainer
	_check(privacy_scroll != null and privacy_scroll.get_v_scroll_bar().max_value > privacy_scroll.size.y, "The complete policy can be scrolled on a phone.")
	_press(app.overlay, "Back to settings")
	_check(_button(app.overlay, "Privacy policy") != null, "The privacy page returns to settings.")
	app._close_modal()

	if not _press(app.page, "Play Alpine Escape"):
		await _finish()
		return
	_check(is_instance_valid(app.overlay), "Choosing gallery artwork opens the difficulty sheet.")
	for count: int in [100, 144, 256, 400, 36]:
		_press(app.overlay, str(count))
		_check(_button(app.overlay, "Let's play  ·  %d pieces" % count) != null, "Difficulty button updates the play action for %d pieces." % count)
	_press(app.overlay, "Let's play  ·  36 pieces")
	await process_frame
	_check(is_instance_valid(app.board), "Play action creates a board.")
	if not is_instance_valid(app.board):
		await _finish()
		return
	_check(app.board.pieces.size() == 36 and app.grid_size == 6, "Chosen difficulty reaches the puzzle engine.")
	_check(not is_instance_valid(app.overlay), "Starting a puzzle closes its chooser.")
	_press(app.page, "Hint")
	_check(app.board.placed_count == 1, "Hint button places a piece through the engine.")
	_check(app.progress_label.text == "1 of 36 pieces", "Engine progress updates the game UI.")
	var session: Dictionary = app.state.get_session("alpine_escape", 6)
	_check(session.state.placed.size() == 1, "Hint signal autosaves placed pieces.")
	_check(FileAccess.file_exists(save_path), "Autosave reaches the isolated file.")
	_press(app.page, "Edges")
	_check(app.board.edges_only, "Edges button filters the tray.")
	_press(app.page, "Picture")
	_check(app.board.reference_visible, "Picture button reveals the classic reference.")
	_press(app.page, "Backdrop")
	_press(app.overlay, "Midnight")
	_check(app.state.background_index == 3, "Backdrop chooser persists the selected preference.")
	_check(app.board.board_color == app.BACKGROUNDS[3], "Backdrop chooser updates the actual board.")
	_press(app.page, "Zoom")
	_press(app.overlay, "Zoom in +")
	_check(app.board.zoom > 1.0, "Zoom sheet changes the board view.")
	_press(app.page, "Save and return to gallery")
	await process_frame
	_check(app.current_tab == "gallery" and not is_instance_valid(app.board), "Back button saves and returns to gallery.")
	_replace_state()
	_check(app.state.get_session("alpine_escape", 6).state.placed.size() == 1, "A fresh state instance reloads the hinted piece.")
	_check(app.state.background_index == 3, "Backdrop survives a fresh state instance.")
	_press(app.page, "Play Alpine Escape")
	_check(_button(app.overlay, "Continue  ·  36 pieces") != null, "Chooser offers Continue for the saved session.")
	_press(app.overlay, "Continue  ·  36 pieces")
	await process_frame
	_check(app.board.placed_count == 1, "Continue reconstructs the saved board.")
	_check(app.board.zoom > 1.0 and app.board.edges_only, "Resume restores zoom and edge filtering.")
	_press(app.page, "Edges")
	_check(not app.board.edges_only, "First edge toggle after resume turns the restored filter off.")
	for step: int in range(35):
		_check(app.board.use_hint(), "The remaining piece can be solved: %d." % step)
	await process_frame
	await process_frame
	_check(app.state.coins == 125, "Completion signal grants exactly one difficulty reward.")
	_check(app.state.get_session("alpine_escape", 6).completed, "Completion is stored with the board state.")
	_check(_has_label(app.overlay, "+25 happy little coins"), "Completion sheet shows the earned reward.")
	_check(app.state.complete_puzzle("alpine_escape", 6) == 0 and app.state.coins == 125, "Duplicate completion cannot increase the balance.")
	_press(app.overlay, "Find my next adventure")
	await process_frame
	_press(app.page, "Toucan Tropics")
	_check(_button(app.overlay, "Unlock for 120 coins") != null, "Earned coins enable a collection purchase.")
	_press(app.overlay, "Unlock for 120 coins")
	_check(app.state.is_unlocked("toucan_tropics") and app.state.coins == 5, "Unlock UI deducts the price once and unlocks artwork.")
	_check(_button(app.overlay, "Let's play  ·  36 pieces") != null, "Successful purchase opens the new puzzle chooser.")

	var mystery_toggle: Button = _button(app.overlay, "Mystery mode: hide the reference picture")
	_check(mystery_toggle != null, "Mystery mode toggle is available.")
	if mystery_toggle != null:
		mystery_toggle.button_pressed = true
		var preview: TextureRect = _first_image(app.overlay)
		_check(preview == null or not preview.is_visible_in_tree() or is_zero_approx(preview.modulate.a), "Mystery chooser fully conceals the picture.")
	_press(app.overlay, "Let's play  ·  36 pieces")
	await process_frame
	_check(app.is_mystery and app.board.mystery_mode, "Mystery selection reaches the engine.")
	_press(app.page, "Picture")
	_check(not app.board.reference_visible, "Picture button cannot reveal a mystery reference.")
	app.board.set_reference_visible(true)
	_check(not app.board.reference_visible, "Board also enforces mystery reference suppression.")
	_press(app.page, "Hint")
	_check(app.state.get_session("toucan_tropics", 6, true).state.placed.size() == 1, "Mystery progress is saved under its own session.")
	_press(app.page, "Save and return to gallery")
	await process_frame
	_press(app.page, "My puzzles")
	await process_frame
	_check(app.current_tab == "saved", "My puzzles navigation opens saved progress.")
	_check(_has_label(app.page, "36 pieces · Mystery"), "Saved gallery labels mystery progress.")
	_replace_state()
	_check(app.state.is_unlocked("toucan_tropics") and app.state.coins == 5, "Purchase and balance survive a reload.")
	_check(app.state.complete_puzzle("alpine_escape", 6) == 0, "Reload cannot duplicate a completed reward.")
	_check(app.state.last_save_error.is_empty(), "Integrated flows finish without save errors.")
	await _finish()


func _finish() -> void:
	if is_instance_valid(app):
		# Let the audio mixer retire playback references from the accelerated solve.
		app.sound_player.stop()
		await create_timer(0.2).timeout
		app.queue_free()
	await process_frame
	await process_frame
	for file_name: String in DirAccess.get_files_at(temporary_dir):
		DirAccess.remove_absolute(temporary_dir.path_join(file_name))
	DirAccess.remove_absolute(temporary_dir)
	print("Piecepop app integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
