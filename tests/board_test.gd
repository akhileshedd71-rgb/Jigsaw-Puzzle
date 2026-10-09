extends SceneTree

const Board = preload("res://scripts/puzzle_board.gd")
const Geometry = preload("res://scripts/puzzle_geometry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func mouse(board: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	board._gui_input(event)

func motion(board: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	board._gui_input(event)

func drag(board: Control, from: Vector2, to: Vector2) -> void:
	mouse(board, from, true)
	motion(board, from + Vector2(0, -25))
	motion(board, to)
	mouse(board, to, false)

func touch(board: Control, position: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = index
	event.pressed = pressed
	board._gui_input(event)

func touch_motion(board: Control, position: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.index = index
	board._gui_input(event)

func make_board(texture: Texture2D, grid: int, saved: Dictionary = {}) -> Control:
	var board := Board.new()
	board.size = Vector2(480, 642)
	root.add_child(board)
	board.setup(texture, grid, 42, saved)
	return board

func run() -> void:
	var image := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORNFLOWER_BLUE)
	var texture := ImageTexture.create_from_image(image)
	var edges := Geometry.make_edges(6, 42)
	for y in range(6):
		for x in range(6):
			var polygon := Geometry.piece_polygon(x, y, 6, edges)
			check(not Geometry2D.triangulate_polygon(polygon).is_empty(), "Piece %s,%s must triangulate" % [x, y])
	var board := make_board(texture, 6)
	await process_frame
	check(board.pieces.size() == 36, "Easy has 36 pieces")
	check(board.placed_count == 0, "Fresh board starts empty")
	check(board.tray_rect.end.y <= board.size.y, "Tray fits mobile game allocation")
	check(board.board_rect.end.y < board.tray_rect.position.y, "Board and tray do not overlap")
	var targets: Array[Dictionary] = board.debug_visible_tray_targets()
	check(not targets.is_empty(), "Tray has usable targets")
	var id := int(targets[0].id)
	drag(board, targets[0].position, board.debug_piece_target(id))
	check(board.placed_count == 1, "Mouse drag snaps correct piece to board")
	check(board.get_save_state().placed == [id], "State exposes placed IDs to economy")
	var saved: Dictionary = board.get_save_state()
	var restored := make_board(texture, 6, saved)
	check(restored.placed_count == 1, "Saved progress restores")
	check(restored.tray_order == board.tray_order, "Tray shuffle remains deterministic")
	board.set_edges_only(true)
	for target in board.debug_visible_tray_targets():
		check(board._is_edge(target.id), "Edges filter shows edge pieces")
	board.set_edges_only(false)
	check(board.use_hint(), "Hint places a piece")
	check(board.placed_count == 2, "Hint updates progress")
	var completions := [0]
	board.puzzle_completed.connect(func() -> void: completions[0] += 1)
	while board.placed_count < 36:
		board.use_hint()
	check(completions[0] == 1, "Completion is emitted once")
	check(not board.use_hint(), "Completed puzzles consume no more hints")
	var edges_done := make_board(texture, 6)
	edges_done.set_edges_only(true)
	for edge_id in range(36):
		if edges_done._is_edge(edge_id):
			var single_edge: Array[int] = [edge_id]
			edges_done._place_group(single_edge)
	check(edges_done.placed_count == 20, "6×6 puzzle has 20 border pieces")
	check(edges_done.debug_visible_tray_targets().is_empty(), "Finished border safely leaves an empty edge tray")
	check(edges_done.use_hint(), "Hints still work after every border piece is placed")
	check(edges_done.placed_count == 21, "Hint chooses an interior piece when edge tray is empty")
	edges_done.set_edges_only(false)
	check(not edges_done.debug_visible_tray_targets().is_empty(), "Turning off Edges reveals remaining interior pieces")
	var hard := make_board(texture, 20)
	check(hard.pieces.size() == 400, "Hard has 400 pieces")
	var hard_target: Dictionary = hard.debug_visible_tray_targets()[0]
	drag(hard, hard_target.position, hard.debug_piece_target(int(hard_target.id)))
	check(hard.placed_count == 1, "400-piece board supports actual drag snapping")
	hard.change_zoom(2.0)
	check(is_equal_approx(hard.zoom, 3.0), "Zoom reaches detailed mobile view")
	var next_hard: Dictionary = hard.debug_visible_tray_targets()[0]
	var next_id := int(next_hard.id)
	hard.reset_view()
	hard._set_zoom(3.0, hard.debug_piece_target(next_id))
	var zoom_target: Vector2 = hard.debug_piece_target(next_id)
	check(hard.board_rect.has_point(zoom_target), "Zoom preserves a visible piece target")
	var wrong_target := zoom_target + Vector2(-hard._cell_size() if zoom_target.x > hard.board_rect.get_center().x else hard._cell_size(), 0)
	drag(hard, next_hard.position, wrong_target)
	check(hard.placed_count == 1, "Drop on neighbouring cell does not falsely snap")
	check(hard.pieces[next_id].location == 1, "Wrong drop remains movable on board")
	drag(hard, wrong_target, zoom_target + Vector2(7, -3))
	check(hard.placed_count == 2, "Zoomed drag snaps within touch-friendly tolerance")
	hard.reset_view()
	check(is_equal_approx(hard.zoom, 1.0), "Reset fits entire board")
	hard._scroll_tray(99999)
	check(not hard.debug_visible_tray_targets().is_empty(), "Last tray page stays accessible")
	hard.setup(texture, 6, 42, {}, true)
	hard.set_reference_visible(true)
	check(not hard.reference_visible, "Mystery mode never exposes reference")
	var mobile := make_board(texture, 6)
	var mobile_target: Dictionary = mobile.debug_visible_tray_targets()[0]
	var mobile_end: Vector2 = mobile.debug_piece_target(int(mobile_target.id))
	touch(mobile, mobile_target.position, 0, true)
	touch_motion(mobile, mobile_target.position + Vector2(0, -25), 0)
	touch_motion(mobile, mobile_end, 0)
	touch(mobile, mobile_end, 0, false)
	check(mobile.placed_count == 1, "Native mobile touch drag snaps the piece")
	touch(mobile, Vector2(150, 210), 0, true)
	touch(mobile, Vector2(250, 210), 1, true)
	touch_motion(mobile, Vector2(350, 210), 1)
	check(mobile.zoom > 1.9, "Two-finger pinch zooms the board")
	touch(mobile, Vector2(150, 210), 0, false)
	touch(mobile, Vector2(350, 210), 1, false)
	check(mobile._touches.is_empty(), "All touch state releases cleanly")
	# Place a loose piece off-target, then join its adjacent neighbour and move
	# the resulting group to its board position through the real input handlers.
	var grouped := make_board(texture, 6)
	var a := 7
	var b := 8
	grouped.pieces[a].location = 1
	grouped.pieces[a].position = Vector2(2, 3)
	grouped.pieces[b].location = 1
	grouped.pieces[b].position = Vector2(3.7, 3)
	var start: Vector2 = grouped._board_to_screen(Vector2(4.2, 3.5))
	var end: Vector2 = grouped._board_to_screen(Vector2(3.5, 3.5))
	drag(grouped, start, end)
	check(grouped.pieces[a].group == grouped.pieces[b].group, "Adjacent loose pieces join")
	var serialized_group: Dictionary = JSON.parse_string(JSON.stringify(grouped.get_save_state()))
	var restored_group := make_board(texture, 6, serialized_group)
	check(restored_group.pieces[a].group == restored_group.pieces[b].group, "Adjacent group survives JSON save and restore")
	check(restored_group.pieces[a].position.is_equal_approx(grouped.pieces[a].position), "Restored loose group keeps board position")
	drag(restored_group, restored_group._board_to_screen(Vector2(2.5, 3.5)), restored_group.debug_piece_target(a))
	check(restored_group.placed_count == 2, "Restored group can be moved and snapped as one")
	drag(grouped, grouped._board_to_screen(Vector2(2.5, 3.5)), grouped.debug_piece_target(a))
	check(grouped.placed_count == 2, "Joined group snaps together")
	await process_frame
	print("Board tests: %d checks, %d failures" % [checks, failures])
	board.free()
	edges_done.free()
	restored.free()
	hard.free()
	mobile.free()
	grouped.free()
	restored_group.free()
	quit(1 if failures > 0 else 0)
