class_name PuzzleBoard
extends Control

signal progress_changed(placed: int, total: int)
signal puzzle_completed
signal interaction_message(text: String)
signal state_changed

const Geometry = preload("res://scripts/puzzle_geometry.gd")
const TRAY := 0
const LOOSE := 1
const PLACED := 2
const INK := Color("44385e")
const PURPLE := Color("8554dd")
const AQUA := Color("30c9c9")

var puzzle_texture: Texture2D
var grid_size := 6
var puzzle_seed := 1
var mystery_mode := false
var pieces: Array[Dictionary] = []
var tray_order: Array[int] = []
var edges_only := false
var reference_visible := false
var board_color := Color("e9e4f5")
var board_rect := Rect2()
var tray_rect := Rect2()
var zoom := 1.0
var pan := Vector2.ZERO
var tray_scroll := 0.0
var placed_count := 0
var _drag_ids: Array[int] = []
var _drag_positions: Dictionary = {}
var _drag_pointer := Vector2.ZERO
var _drag_start_pointer := Vector2.ZERO
var _drag_anchor := Vector2(0.5, 0.5)
var _drag_from_tray := false
var _drag_active := false
var _tray_gesture := false
var _tray_gesture_start := Vector2.ZERO
var _tray_scroll_start := 0.0
var _pan_active := false
var _pan_start := Vector2.ZERO
var _pan_pointer_start := Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _pinch_zoom := 1.0
var _pinch_mid := Vector2.ZERO
var _pinch_pan := Vector2.ZERO
var _hint_id := -1
var _hint_time := 0.0
var _flash_ids: Array[int] = []
var _flash_time := 0.0
var _complete_fade := 0.0
var _font: Font
var _ready_to_draw := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/Nunito-Regular.ttf"):
		_font = load("res://assets/fonts/Nunito-Regular.ttf")
	resized.connect(_layout)
	_layout()
	set_process(true)

func setup(texture: Texture2D, grid: int, seed_value: int, saved_state: Dictionary = {}, mystery: bool = false) -> void:
	puzzle_texture = texture
	grid_size = clampi(grid, 2, 20)
	puzzle_seed = seed_value
	mystery_mode = mystery
	pieces.clear()
	tray_order.clear()
	_drag_ids.clear()
	_drag_positions.clear()
	_drag_active = false
	_pan_active = false
	_tray_gesture = false
	_touches.clear()
	_pinch_distance = 0.0
	reference_visible = false
	placed_count = 0
	zoom = 1.0
	pan = Vector2.ZERO
	tray_scroll = 0.0
	_hint_id = -1
	_complete_fade = 0.0
	var edge_map := Geometry.make_edges(grid_size, puzzle_seed)
	for row in range(grid_size):
		for column in range(grid_size):
			var id := row * grid_size + column
			var polygon := Geometry.piece_polygon(column, row, grid_size, edge_map)
			var uvs := PackedVector2Array()
			for point in polygon:
				uvs.append((Vector2(column, row) + point) / float(grid_size))
			pieces.append({"id": id, "column": column, "row": row, "polygon": polygon, "uvs": uvs, "location": TRAY, "position": Vector2(column, row), "group": id})
			tray_order.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = puzzle_seed + 7993
	for i in range(tray_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var item := tray_order[i]
		tray_order[i] = tray_order[j]
		tray_order[j] = item
	_restore_state(saved_state)
	_layout()
	_ready_to_draw = true
	progress_changed.emit(placed_count, pieces.size())
	queue_redraw()

func _layout() -> void:
	var side := maxf(120.0, minf(size.x - 36.0, size.y - 156.0))
	board_rect = Rect2(Vector2((size.x - side) * 0.5, 10), Vector2.ONE * side)
	tray_rect = Rect2(Vector2(8, board_rect.end.y + 21), Vector2(size.x - 16, maxf(110, size.y - board_rect.end.y - 25)))
	_clamp_pan()
	queue_redraw()

func get_save_state() -> Dictionary:
	var state_pieces: Array = []
	var placed_ids: Array[int] = []
	for piece in pieces:
		if int(piece.location) == PLACED:
			placed_ids.append(int(piece.id))
		if int(piece.location) != TRAY:
			var position_value: Vector2 = piece.position
			state_pieces.append({"id": piece.id, "location": piece.location, "x": position_value.x, "y": position_value.y, "group": piece.group})
	return {"version": 1, "grid": grid_size, "seed": puzzle_seed, "pieces": state_pieces, "placed": placed_ids, "zoom": zoom, "pan_x": pan.x, "pan_y": pan.y, "tray_scroll": tray_scroll, "edges_only": edges_only}

func _restore_state(state: Dictionary) -> void:
	if int(state.get("grid", grid_size)) != grid_size or int(state.get("seed", puzzle_seed)) != puzzle_seed:
		return
	var seen: Dictionary = {}
	for entry in state.get("pieces", []):
		if not entry is Dictionary:
			continue
		var id := int(entry.get("id", -1))
		if id < 0 or id >= pieces.size() or seen.has(id):
			continue
		seen[id] = true
		var location := int(entry.get("location", TRAY))
		if location != LOOSE and location != PLACED:
			continue
		pieces[id].location = location
		pieces[id].position = Vector2(float(entry.get("x", pieces[id].column)), float(entry.get("y", pieces[id].row)))
		pieces[id].group = clampi(int(entry.get("group", id)), 0, pieces.size() - 1)
		if location == PLACED:
			pieces[id].position = Vector2(pieces[id].column, pieces[id].row)
			placed_count += 1
	zoom = clampf(float(state.get("zoom", 1.0)), 1.0, 4.0)
	pan = Vector2(float(state.get("pan_x", 0.0)), float(state.get("pan_y", 0.0)))
	tray_scroll = maxf(0.0, float(state.get("tray_scroll", 0.0)))
	edges_only = bool(state.get("edges_only", false))
	if placed_count == pieces.size():
		_complete_fade = 1.0

func set_edges_only(enabled: bool) -> void:
	edges_only = enabled
	tray_scroll = 0.0
	queue_redraw()
	state_changed.emit()

func set_reference_visible(enabled: bool) -> void:
	reference_visible = enabled and not mystery_mode
	queue_redraw()

func set_board_color(color: Color) -> void:
	board_color = color
	queue_redraw()

func change_zoom(delta: float) -> void:
	_set_zoom(zoom + delta, board_rect.get_center())
	state_changed.emit()

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()
	state_changed.emit()

func _set_zoom(value: float, focus: Vector2) -> void:
	var previous := zoom
	zoom = clampf(value, 1.0, 4.0)
	pan = (pan - (focus - board_rect.get_center())) * (zoom / previous) + (focus - board_rect.get_center())
	_clamp_pan()
	queue_redraw()

func _clamp_pan() -> void:
	var limit := board_rect.size * (zoom - 1.0) * 0.5
	pan.x = clampf(pan.x, -limit.x, limit.x)
	pan.y = clampf(pan.y, -limit.y, limit.y)

func _cell_size() -> float:
	return board_rect.size.x * zoom / float(grid_size)

func _board_origin() -> Vector2:
	return board_rect.get_center() - board_rect.size * zoom * 0.5 + pan

func _screen_to_board(point: Vector2) -> Vector2:
	return (point - _board_origin()) / _cell_size()

func _board_to_screen(point: Vector2) -> Vector2:
	return _board_origin() + point * _cell_size()

func _visible_tray_ids() -> Array[int]:
	var result: Array[int] = []
	for id in tray_order:
		if int(pieces[id].location) == TRAY and (not edges_only or _is_edge(id)):
			result.append(id)
	return result

func _is_edge(id: int) -> bool:
	return int(pieces[id].column) == 0 or int(pieces[id].column) == grid_size - 1 or int(pieces[id].row) == 0 or int(pieces[id].row) == grid_size - 1

func _tray_cell_size() -> float:
	return minf(62.0, tray_rect.size.y - 69.0)

func _tray_spacing() -> float:
	return _tray_cell_size() * 1.50

func _tray_position(index: int) -> Vector2:
	var top := maxf(39.0, (tray_rect.size.y + 10.0 - _tray_cell_size()) * 0.5)
	return Vector2(tray_rect.position.x + 39 + float(index) * _tray_spacing() - tray_scroll, tray_rect.position.y + top)

func _max_tray_scroll(count: int) -> float:
	return maxf(0.0, float(count) * _tray_spacing() - tray_rect.size.x + 48)

func _round_box(rect: Rect2, fill: Color, radius: int = 18, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.set_border_width_all(border_width)
	draw_style_box(style, rect)

func _draw() -> void:
	if not _ready_to_draw or puzzle_texture == null:
		return
	# Fixed frame and a clipped workspace keep zoomed pieces away from the tray.
	_round_box(Rect2(board_rect.position + Vector2(-6, -2), board_rect.size + Vector2(12, 12)), Color(0.28, 0.19, 0.46, 0.10), 20)
	_round_box(board_rect.grow(6), Color.WHITE, 20)
	_round_box(board_rect, board_color, 15)
	var cell := _cell_size()
	var origin := _board_origin()
	var image_rect := Rect2(origin, board_rect.size * zoom)
	if reference_visible and not mystery_mode:
		_draw_clipped_image(image_rect, Color(1, 1, 1, 0.25))
	# Quiet guide lines make the board readable without exposing mystery art.
	for i in range(grid_size + 1):
		var x := origin.x + i * cell
		var y := origin.y + i * cell
		if x >= board_rect.position.x and x <= board_rect.end.x:
			draw_line(Vector2(x, board_rect.position.y), Vector2(x, board_rect.end.y), Color(0.37, 0.29, 0.52, 0.075), 1.0)
		if y >= board_rect.position.y and y <= board_rect.end.y:
			draw_line(Vector2(board_rect.position.x, y), Vector2(board_rect.end.x, y), Color(0.37, 0.29, 0.52, 0.075), 1.0)
	if placed_count == 0 and pieces.all(func(p: Dictionary) -> bool: return int(p.location) == TRAY):
		_draw_empty_guide()
	if placed_count == pieces.size():
		_draw_clipped_image(image_rect, Color.WHITE)
	for piece in pieces:
		var id := int(piece.id)
		if int(piece.location) == PLACED and not _drag_ids.has(id) and _complete_fade < 1.0:
			_draw_board_piece(id, piece.position, 1.0 - _complete_fade, false)
	for piece in pieces:
		var id := int(piece.id)
		if int(piece.location) == LOOSE and not _drag_ids.has(id):
			_draw_board_piece(id, piece.position, 1.0, true)
	if _hint_id >= 0 and _hint_time > 0:
		var target := _board_to_screen(Vector2(pieces[_hint_id].column, pieces[_hint_id].row))
		var glow := 0.35 + sin(_hint_time * 9.0) * 0.15
		_draw_piece(_hint_id, target, cell, false, Color(1.0, 0.89, 0.38, glow), true)
	# A clean mask provides an inset viewport without separate render textures.
	_mask_board_overflow()
	_draw_tray()
	if _drag_active:
		for id in _drag_ids:
			var position_value: Vector2 = _drag_positions[id]
			_draw_piece(id, _board_to_screen(position_value), cell, true)
	if zoom > 1.02:
		_round_box(Rect2(board_rect.position + Vector2(9, 9), Vector2(58, 24)), Color(1, 1, 1, 0.88), 12)
		draw_string(_font, board_rect.position + Vector2(21, 26), "%.1f×" % zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)

func _draw_empty_guide() -> void:
	var center := board_rect.get_center()
	var guide_poly := Geometry.piece_polygon(1, 1, 3, Geometry.make_edges(3, 11))
	var points := PackedVector2Array()
	for point in guide_poly:
		points.append(center + (point - Vector2(0.5, 0.5)) * 46.0 + Vector2(0, -14))
	points.append(points[0])
	draw_polyline(points, Color(0.47, 0.37, 0.62, 0.27), 2.0, true)
	var label_text := "A little piece of happiness"
	var text_size := _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(_font, center + Vector2(-text_size.x * 0.5, 40), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.43, 0.35, 0.56, 0.58))

func _draw_clipped_image(rect: Rect2, color: Color) -> void:
	var intersection := rect.intersection(board_rect)
	if intersection.size.x <= 0 or intersection.size.y <= 0:
		return
	var texture_size := Vector2(puzzle_texture.get_size())
	var source := Rect2((intersection.position - rect.position) / rect.size * texture_size, intersection.size / rect.size * texture_size)
	draw_texture_rect_region(puzzle_texture, intersection, source, color)

func _draw_board_piece(id: int, position_value: Vector2, outline_alpha: float, shadow: bool) -> void:
	var screen := _board_to_screen(position_value)
	var cell := _cell_size()
	if not Rect2(screen - Vector2.ONE * cell * 0.25, Vector2.ONE * cell * 1.5).intersects(board_rect):
		return
	_draw_piece(id, screen, cell, shadow, Color.WHITE, false, outline_alpha)
	if _flash_ids.has(id) and _flash_time > 0:
		_draw_piece(id, screen, cell, false, Color(1, 1, 1, _flash_time * 0.65), true)

func _draw_piece(id: int, origin: Vector2, scale_value: float, shadow: bool = false, modulate_color: Color = Color.WHITE, solid: bool = false, outline_alpha: float = 1.0) -> void:
	var polygon: PackedVector2Array = pieces[id].polygon
	var points := PackedVector2Array()
	for point in polygon:
		points.append(origin + point * scale_value)
	if shadow:
		var shadow_points := PackedVector2Array()
		for point in points:
			shadow_points.append(point + Vector2(0, 3))
		draw_colored_polygon(shadow_points, Color(0.20, 0.12, 0.35, 0.22))
	if solid:
		draw_colored_polygon(points, modulate_color)
	else:
		draw_polygon(points, PackedColorArray([modulate_color]), pieces[id].uvs, puzzle_texture)
	if outline_alpha > 0.001:
		points.append(points[0])
		draw_polyline(points, Color(1, 1, 1, 0.62 * outline_alpha), 1.25, true)
		draw_polyline(points, Color(0.20, 0.14, 0.30, 0.18 * outline_alpha), 0.55, true)

func _mask_board_overflow() -> void:
	# Parent background is the same soft periwinkle. These narrow masks hide
	# offscreen portions of zoomed shapes while leaving the white frame visible.
	var mask := Color("f8f6ff")
	draw_rect(Rect2(0, 0, size.x, maxf(0, board_rect.position.y)), mask)
	draw_rect(Rect2(0, board_rect.position.y, board_rect.position.x, board_rect.size.y), mask)
	draw_rect(Rect2(board_rect.end.x, board_rect.position.y, size.x - board_rect.end.x, board_rect.size.y), mask)
	draw_rect(Rect2(0, board_rect.end.y, size.x, size.y - board_rect.end.y), mask)
	var border := StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.border_color = Color(1, 1, 1, 0.95)
	border.set_border_width_all(3)
	border.set_corner_radius_all(14)
	draw_style_box(border, board_rect.grow(2))

func _draw_tray() -> void:
	_round_box(Rect2(tray_rect.position + Vector2(0, 3), tray_rect.size), Color(0.34, 0.22, 0.56, 0.09), 19)
	_round_box(tray_rect, Color.WHITE, 19)
	var ids := _visible_tray_ids()
	tray_scroll = clampf(tray_scroll, 0.0, _max_tray_scroll(ids.size()))
	var caption := "YOUR PIECES" if not edges_only else "EDGE PIECES"
	draw_string(_font, tray_rect.position + Vector2(16, 21), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("827098"))
	var count_text := "%d left" % ids.size()
	var count_width := _font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, Vector2(tray_rect.end.x - count_width - 16, tray_rect.position.y + 21), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("827098"))
	var tray_cell := _tray_cell_size()
	for i in range(ids.size()):
		var origin := _tray_position(i)
		if origin.x < tray_rect.position.x - tray_cell or origin.x > tray_rect.end.x + tray_cell:
			continue
		if not _drag_ids.has(ids[i]):
			_draw_piece(ids[i], origin, tray_cell, true)
	if ids.is_empty() and placed_count != pieces.size():
		var text_value := "All edges are on the board!" if edges_only else "Your pieces are on the board"
		var line_y := maxf(65, tray_rect.size.y * 0.5 - 4)
		draw_string(_font, tray_rect.position + Vector2(28, line_y), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
		if edges_only:
			draw_string(_font, tray_rect.position + Vector2(28, line_y + 23), "Tap Edges to show the rest.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, PURPLE)
	elif placed_count == pieces.size():
		draw_string(_font, tray_rect.position + Vector2(28, 72), "Every piece found its happy place.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	if _max_tray_scroll(ids.size()) > 0:
		var track := Rect2(tray_rect.position.x + 45, tray_rect.end.y - 12, tray_rect.size.x - 90, 3)
		_round_box(track, Color("eee9f6"), 2)
		var width := maxf(24, track.size.x * minf(1, tray_rect.size.x / maxf(1, float(ids.size()) * _tray_spacing())))
		_round_box(Rect2(track.position.x + (track.size.x - width) * tray_scroll / _max_tray_scroll(ids.size()), track.position.y, width, 3), Color("baa7dd"), 2)
		var arrow_y := _tray_position(0).y + tray_cell * 0.5
		_draw_arrow(Vector2(tray_rect.position.x + 18, arrow_y), -1, tray_scroll > 0)
		_draw_arrow(Vector2(tray_rect.end.x - 18, arrow_y), 1, tray_scroll < _max_tray_scroll(ids.size()))

func _draw_arrow(center: Vector2, direction: int, enabled: bool) -> void:
	draw_circle(center, 14, Color(1, 1, 1, 0.96))
	var color := PURPLE if enabled else Color("ded5ee")
	draw_polyline(PackedVector2Array([center + Vector2(-3 * direction, -5), center + Vector2(3 * direction, 0), center + Vector2(-3 * direction, 5)]), color, 2.5, true)

func _gui_input(event: InputEvent) -> void:
	if not _ready_to_draw:
		return
	# Godot can synthesize mouse events from native touch; handling both would
	# start and end the same drag twice and disrupt two-finger gestures.
	if event is InputEventMouse and event.device == -1:
		return
	if event is InputEventMagnifyGesture:
		_set_zoom(zoom * event.factor, event.position)
		state_changed.emit()
		accept_event()
	elif event is InputEventPanGesture:
		if tray_rect.has_point(event.position):
			_scroll_tray(event.delta.x * 20 + event.delta.y * 20)
		else:
			pan -= event.delta * 12
			_clamp_pan()
			queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pointer_down(event.position)
			else:
				_pointer_up(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_active = event.pressed
			_pan_start = pan
			_pan_pointer_start = event.position
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var direction := -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
			if tray_rect.has_point(event.position):
				_scroll_tray(direction * _tray_spacing() * 1.7)
			else:
				_set_zoom(zoom - direction * 0.25, event.position)
				state_changed.emit()
			accept_event()
	elif event is InputEventMouseMotion:
		_pointer_move(event.position)
		if _drag_active or _pan_active or _tray_gesture:
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_pointer_down(event.position)
			elif _touches.size() == 2:
				_cancel_drag()
				var values := _touches.values()
				_pinch_distance = values[0].distance_to(values[1])
				_pinch_zoom = zoom
				_pinch_mid = (values[0] + values[1]) * 0.5
				_pinch_pan = pan
		else:
			if _touches.size() == 1:
				_pointer_up(event.position)
			_touches.erase(event.index)
			if _touches.is_empty():
				_pinch_distance = 0.0
				state_changed.emit()
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2 and _pinch_distance > 0:
			var values := _touches.values()
			zoom = _pinch_zoom
			pan = _pinch_pan
			_set_zoom(_pinch_zoom * values[0].distance_to(values[1]) / _pinch_distance, _pinch_mid)
			pan += (values[0] + values[1]) * 0.5 - _pinch_mid
			_clamp_pan()
			queue_redraw()
		elif _touches.size() == 1 and _pinch_distance <= 0:
			_pointer_move(event.position)
		accept_event()

func _pointer_down(point: Vector2) -> void:
	if placed_count == pieces.size():
		return
	_drag_start_pointer = point
	_drag_pointer = point
	if tray_rect.has_point(point):
		if point.x < tray_rect.position.x + 32:
			_scroll_tray(-tray_rect.size.x * 0.72)
			return
		if point.x > tray_rect.end.x - 32:
			_scroll_tray(tray_rect.size.x * 0.72)
			return
		var ids := _visible_tray_ids()
		for i in range(ids.size() - 1, -1, -1):
			var local := (point - _tray_position(i)) / _tray_cell_size()
			if Geometry2D.is_point_in_polygon(local, pieces[ids[i]].polygon):
				_drag_ids.assign([ids[i]])
				_drag_anchor = local
				_drag_from_tray = true
				_drag_active = false
				_tray_gesture = true
				_tray_gesture_start = point
				_tray_scroll_start = tray_scroll
				return
		_tray_gesture = true
		_tray_gesture_start = point
		_tray_scroll_start = tray_scroll
	elif board_rect.has_point(point):
		var board_point := _screen_to_board(point)
		for id in range(pieces.size() - 1, -1, -1):
			if int(pieces[id].location) == LOOSE and Geometry2D.is_point_in_polygon(board_point - Vector2(pieces[id].position), pieces[id].polygon):
				_drag_ids = _group_members(int(pieces[id].group))
				_drag_anchor = board_point - Vector2(pieces[id].position)
				_drag_from_tray = false
				_drag_active = true
				for member in _drag_ids:
					_drag_positions[member] = pieces[member].position
				queue_redraw()
				return
		_pan_active = zoom > 1.0
		_pan_start = pan
		_pan_pointer_start = point

func _pointer_move(point: Vector2) -> void:
	if _tray_gesture:
		var delta := point - _tray_gesture_start
		if not _drag_ids.is_empty() and (delta.y < -12 or (delta.length() > 9 and absf(delta.y) > absf(delta.x) * 0.85)):
			_tray_gesture = false
			_drag_active = true
		elif absf(delta.x) > 10:
			_drag_ids.clear()
			tray_scroll = clampf(_tray_scroll_start - delta.x, 0.0, _max_tray_scroll(_visible_tray_ids().size()))
			queue_redraw()
			return
	if _drag_active:
		if _drag_from_tray:
			_drag_positions[_drag_ids[0]] = _screen_to_board(point) - _drag_anchor
		else:
			var delta := (point - _drag_start_pointer) / _cell_size()
			for id in _drag_ids:
				_drag_positions[id] = Vector2(pieces[id].position) + delta
		_drag_pointer = point
		queue_redraw()
	elif _pan_active:
		pan = _pan_start + point - _pan_pointer_start
		_clamp_pan()
		queue_redraw()

func _pointer_up(point: Vector2) -> void:
	if _drag_active and not _drag_ids.is_empty():
		_pointer_move(point)
		if board_rect.has_point(point):
			for id in _drag_ids:
				pieces[id].location = LOOSE
				pieces[id].position = _drag_positions[id]
			_try_snap(_drag_ids.duplicate())
			state_changed.emit()
		elif not _drag_from_tray and tray_rect.has_point(point):
			for id in _drag_ids:
				pieces[id].location = TRAY
				pieces[id].group = id
			state_changed.emit()
	elif _tray_gesture and not _drag_ids.is_empty():
		interaction_message.emit("Drag a piece up onto the board")
	if _pan_active:
		state_changed.emit()
	_cancel_drag()

func _cancel_drag() -> void:
	_drag_ids.clear()
	_drag_positions.clear()
	_drag_active = false
	_drag_from_tray = false
	_tray_gesture = false
	_pan_active = false
	queue_redraw()

func _group_members(group: int) -> Array[int]:
	var ids: Array[int] = []
	for piece in pieces:
		if int(piece.location) == LOOSE and int(piece.group) == group:
			ids.append(int(piece.id))
	return ids

func _try_snap(ids: Array[int]) -> void:
	var threshold := clampf(18.0 / _cell_size(), 0.23, 0.58)
	for id in ids:
		var target := Vector2(pieces[id].column, pieces[id].row)
		if Vector2(pieces[id].position).distance_to(target) <= threshold:
			_place_group(ids)
			return
	# Matching neighbours can join anywhere on the workspace and move as one.
	for id in ids:
		var column := int(pieces[id].column)
		var row := int(pieces[id].row)
		var neighbours: Array[int] = []
		if column > 0: neighbours.append(id - 1)
		if column < grid_size - 1: neighbours.append(id + 1)
		if row > 0: neighbours.append(id - grid_size)
		if row < grid_size - 1: neighbours.append(id + grid_size)
		for neighbour in neighbours:
			if int(pieces[neighbour].location) != LOOSE or ids.has(neighbour):
				continue
			var relative := Vector2(column - int(pieces[neighbour].column), row - int(pieces[neighbour].row))
			var desired := Vector2(pieces[neighbour].position) + relative
			var correction := desired - Vector2(pieces[id].position)
			if correction.length() <= threshold:
				var group := int(pieces[neighbour].group)
				for member in ids:
					pieces[member].position = Vector2(pieces[member].position) + correction
					pieces[member].group = group
				_flash_ids = _group_members(group)
				_flash_time = 0.55
				interaction_message.emit("A perfect pair! Keep building.")
				queue_redraw()
				return

func _place_group(ids: Array[int]) -> void:
	for id in ids:
		if int(pieces[id].location) == PLACED:
			continue
		pieces[id].location = PLACED
		pieces[id].position = Vector2(pieces[id].column, pieces[id].row)
		placed_count += 1
	_flash_ids = ids.duplicate()
	_flash_time = 0.55
	progress_changed.emit(placed_count, pieces.size())
	if placed_count == pieces.size():
		reset_view()
		puzzle_completed.emit()
	else:
		interaction_message.emit("Lovely fit!")
	queue_redraw()

func use_hint() -> bool:
	if placed_count >= pieces.size() or _drag_active:
		return false
	var id := -1
	var visible := _visible_tray_ids()
	if not visible.is_empty():
		var index := clampi(int(round(tray_scroll / _tray_spacing())), 0, visible.size() - 1)
		id = visible[index]
	else:
		for piece in pieces:
			if int(piece.location) != PLACED:
				id = int(piece.id)
				break
	if id < 0:
		return false
	var ids: Array[int] = [id]
	if int(pieces[id].location) == LOOSE:
		ids = _group_members(int(pieces[id].group))
	_hint_id = id
	_hint_time = 2.0
	# Center the hinted piece if it lies outside the current zoomed viewport.
	var target := _board_to_screen(Vector2(pieces[id].column, pieces[id].row) + Vector2(0.5, 0.5))
	if not board_rect.grow(-_cell_size() * 0.4).has_point(target):
		pan += board_rect.get_center() - target
		_clamp_pan()
	_place_group(ids)
	interaction_message.emit("A little nudge in the right direction")
	state_changed.emit()
	return true

func _scroll_tray(amount: float) -> void:
	tray_scroll = clampf(tray_scroll + amount, 0.0, _max_tray_scroll(_visible_tray_ids().size()))
	queue_redraw()
	state_changed.emit()

func _process(delta: float) -> void:
	var redraw := false
	if _flash_time > 0:
		_flash_time = maxf(0, _flash_time - delta)
		redraw = true
	if _hint_time > 0:
		_hint_time = maxf(0, _hint_time - delta)
		redraw = true
	if not pieces.is_empty() and placed_count == pieces.size() and _complete_fade < 1.0:
		_complete_fade = minf(1.0, _complete_fade + delta * 1.2)
		redraw = true
	if redraw:
		queue_redraw()

## Read-only coordinates expose real interaction targets to smoke tests.
func debug_piece_target(id: int) -> Vector2:
	return _board_to_screen(Vector2(pieces[id].column, pieces[id].row) + Vector2(0.5, 0.5))

func debug_visible_tray_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := _visible_tray_ids()
	for i in range(ids.size()):
		var center := _tray_position(i) + Vector2.ONE * _tray_cell_size() * 0.5
		if center.x > tray_rect.position.x + 35 and center.x < tray_rect.end.x - 35:
			result.append({"id": ids[i], "position": center})
	return result
