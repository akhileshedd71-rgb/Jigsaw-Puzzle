class_name PuzzleGeometry
extends RefCounted

## A shared, deterministic edge map gives every neighbouring pair exactly
## complementary tabs. Coordinates use one cell as their unit.
static func make_edges(grid: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var horizontal: Array = []
	var vertical: Array = []
	for y in range(grid - 1):
		var row: Array = []
		for x in range(grid):
			row.append(1 if rng.randi() % 2 == 0 else -1)
		horizontal.append(row)
	for y in range(grid):
		var row: Array = []
		for x in range(grid - 1):
			row.append(1 if rng.randi() % 2 == 0 else -1)
		vertical.append(row)
	return {"horizontal": horizontal, "vertical": vertical}

static func piece_polygon(column: int, row: int, grid: int, edges: Dictionary) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var top: int = 0 if row == 0 else -int(edges.horizontal[row - 1][column])
	var right: int = 0 if column == grid - 1 else int(edges.vertical[row][column])
	var bottom: int = 0 if row == grid - 1 else int(edges.horizontal[row][column])
	var left: int = 0 if column == 0 else -int(edges.vertical[row][column - 1])
	_append_edge(polygon, Vector2(0, 0), Vector2(1, 0), Vector2(0, -1), top)
	_append_edge(polygon, Vector2(1, 0), Vector2(1, 1), Vector2(1, 0), right)
	_append_edge(polygon, Vector2(1, 1), Vector2(0, 1), Vector2(0, 1), bottom)
	_append_edge(polygon, Vector2(0, 1), Vector2(0, 0), Vector2(-1, 0), left)
	if polygon.size() > 1 and polygon[polygon.size() - 1].is_equal_approx(polygon[0]):
		polygon.remove_at(polygon.size() - 1)
	return polygon

static func _append_edge(output: PackedVector2Array, start: Vector2, finish: Vector2, outward: Vector2, tab: int) -> void:
	var tangent := finish - start
	if output.is_empty() or not output[output.size() - 1].is_equal_approx(start):
		output.append(start)
	if tab == 0:
		output.append(finish)
		return
	var normal := outward * float(tab)
	# Smooth shoulders and a rounded, narrow-necked tab. This profile is
	# symmetric, so reversing an edge reproduces the neighbouring socket.
	var segments: Array = [
		[Vector2(0.00, 0), Vector2(0.13, 0), Vector2(0.27, 0), Vector2(0.35, 0)],
		[Vector2(0.35, 0), Vector2(0.43, 0), Vector2(0.43, 0.035), Vector2(0.39, 0.085)],
		[Vector2(0.39, 0.085), Vector2(0.31, 0.19), Vector2(0.38, 0.245), Vector2(0.50, 0.245)],
		[Vector2(0.50, 0.245), Vector2(0.62, 0.245), Vector2(0.69, 0.19), Vector2(0.61, 0.085)],
		[Vector2(0.61, 0.085), Vector2(0.57, 0.035), Vector2(0.57, 0), Vector2(0.65, 0)],
		[Vector2(0.65, 0), Vector2(0.73, 0), Vector2(0.87, 0), Vector2(1, 0)]
	]
	for segment in segments:
		for step in range(1, 6):
			var t := float(step) / 5.0
			var u := 1.0 - t
			var point: Vector2 = u * u * u * segment[0] + 3.0 * u * u * t * segment[1] + 3.0 * u * t * t * segment[2] + t * t * t * segment[3]
			output.append(start + tangent * point.x + normal * point.y)
