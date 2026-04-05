class_name MinimapOverlay
extends Control

@export var radius_cells := 5
@export var cell_size_pixels := 10.0
@export var background_color := Color(0.06, 0.08, 0.10, 0.86)
@export var border_color := Color(0.82, 0.87, 0.93, 0.9)
@export var grid_color := Color(0.35, 0.42, 0.50, 0.45)
@export var blocked_color := Color(0.82, 0.26, 0.26, 0.9)
@export var player_color := Color(0.25, 0.92, 0.62, 0.95)
@export var facing_color := Color(1.0, 0.91, 0.44, 1.0)
@export var floor_exit_marker_color := Color(0.33, 0.85, 1.0, 0.95)
@export var disposal_chute_marker_color := Color(1.0, 0.58, 0.18, 0.95)
@export var enemy_last_known_marker_color := Color(1.0, 0.30, 0.30, 1.0)
@export var pickup_marker_color := Color(0.50, 0.95, 0.42, 0.95)
@export var chest_marker_color := Color(1.0, 0.86, 0.28, 0.95)

var _player_cell := Vector2i.ZERO
var _player_facing := GridDefinitions.Facing.NORTH
var _occupancy: GridOccupancyMap
var _exit_cells: Array[Vector2i] = []
var _chute_cells: Array[Vector2i] = []
var _pickup_cells: Array[Vector2i] = []
var _chest_cells: Array[Vector2i] = []
var _last_known_enemy_cell := Vector2i.ZERO
var _has_last_known_enemy_cell := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_occupancy(occupancy: GridOccupancyMap) -> void:
	_occupancy = occupancy
	queue_redraw()


func set_player_state(cell: Vector2i, facing: GridDefinitions.Facing) -> void:
	_player_cell = cell
	_player_facing = facing
	queue_redraw()


func set_marker_cells(
		exit_cells: Array[Vector2i],
		chute_cells: Array[Vector2i],
		pickup_cells: Array[Vector2i],
		chest_cells: Array[Vector2i],
		last_known_enemy_cell: Vector2i,
		has_last_known_enemy_cell: bool,
) -> void:
	_exit_cells = exit_cells.duplicate()
	_chute_cells = chute_cells.duplicate()
	_pickup_cells = pickup_cells.duplicate()
	_chest_cells = chest_cells.duplicate()
	_last_known_enemy_cell = last_known_enemy_cell
	_has_last_known_enemy_cell = has_last_known_enemy_cell
	queue_redraw()


func get_player_cell() -> Vector2i:
	return _player_cell


func get_player_facing() -> GridDefinitions.Facing:
	return _player_facing


func _draw() -> void:
	var draw_rect_area := Rect2(Vector2.ZERO, size)
	draw_rect(draw_rect_area, background_color, true)
	draw_rect(draw_rect_area, border_color, false, 2.0)

	var radius := maxi(radius_cells, 1)
	var cell_px := maxf(cell_size_pixels, 2.0)
	var center := draw_rect_area.size * 0.5
	var half_cell := Vector2.ONE * (cell_px * 0.5)

	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var local_center := center + Vector2(float(dx), float(dz)) * cell_px
			var rect := Rect2(local_center - half_cell, Vector2.ONE * cell_px)
			draw_rect(rect, grid_color, false, 1.0)

			if _occupancy != null:
				var sample_cell := _player_cell + Vector2i(dx, dz)
				if not _occupancy.is_passable(sample_cell):
					draw_rect(rect.grow(-1.0), blocked_color, true)

	for cell in _exit_cells:
		_draw_square_marker(
			cell,
			floor_exit_marker_color,
			cell_px * 0.52,
			radius,
			cell_px,
			center,
		)

	for cell in _chute_cells:
		_draw_diamond_marker(
			cell,
			disposal_chute_marker_color,
			cell_px * 0.56,
			radius,
			cell_px,
			center,
		)

	if _has_last_known_enemy_cell:
		_draw_cross_marker(
			_last_known_enemy_cell,
			enemy_last_known_marker_color,
			cell_px * 0.52,
			radius,
			cell_px,
			center,
		)

	for cell in _pickup_cells:
		_draw_circle_marker(
			cell,
			pickup_marker_color,
			cell_px * 0.24,
			radius,
			cell_px,
			center,
		)

	for cell in _chest_cells:
		_draw_square_marker(
			cell,
			chest_marker_color,
			cell_px * 0.44,
			radius,
			cell_px,
			center,
		)

	var player_rect := Rect2(center - half_cell * 0.9, Vector2.ONE * cell_px * 0.9)
	draw_rect(player_rect, player_color, true)

	var facing := GridDefinitions.facing_to_vec2i(_player_facing)
	var facing_end := center + Vector2(float(facing.x), float(facing.y)) * (cell_px * 0.9)
	draw_line(center, facing_end, facing_color, 2.0)


func _marker_canvas_position(
		cell: Vector2i,
		radius: int,
		cell_px: float,
		center: Vector2,
) -> Variant:
	var dx := cell.x - _player_cell.x
	var dz := cell.y - _player_cell.y
	if absi(dx) > radius or absi(dz) > radius:
		return null
	return center + Vector2(float(dx), float(dz)) * cell_px


func _draw_square_marker(
		cell: Vector2i,
		color: Color,
		size_px: float,
		radius: int,
		cell_px: float,
		center: Vector2,
) -> void:
	var marker_pos: Variant = _marker_canvas_position(cell, radius, cell_px, center)
	if marker_pos == null:
		return
	var pos := marker_pos as Vector2
	var half := Vector2.ONE * (size_px * 0.5)
	draw_rect(Rect2(pos - half, Vector2.ONE * size_px), color, true)


func _draw_circle_marker(
		cell: Vector2i,
		color: Color,
		radius_px: float,
		radius: int,
		cell_px: float,
		center: Vector2,
) -> void:
	var marker_pos: Variant = _marker_canvas_position(cell, radius, cell_px, center)
	if marker_pos == null:
		return
	var pos := marker_pos as Vector2
	draw_circle(pos, radius_px, color)


func _draw_diamond_marker(
		cell: Vector2i,
		color: Color,
		size_px: float,
		radius: int,
		cell_px: float,
		center: Vector2,
) -> void:
	var marker_pos: Variant = _marker_canvas_position(cell, radius, cell_px, center)
	if marker_pos == null:
		return
	var pos := marker_pos as Vector2
	var half := size_px * 0.5
	var points := PackedVector2Array(
		[
			pos + Vector2(0.0, -half),
			pos + Vector2(half, 0.0),
			pos + Vector2(0.0, half),
			pos + Vector2(-half, 0.0),
		],
	)
	draw_colored_polygon(points, color)


func _draw_cross_marker(
		cell: Vector2i,
		color: Color,
		size_px: float,
		radius: int,
		cell_px: float,
		center: Vector2,
) -> void:
	var marker_pos: Variant = _marker_canvas_position(cell, radius, cell_px, center)
	if marker_pos == null:
		return
	var pos := marker_pos as Vector2
	var half := size_px * 0.5
	draw_line(pos + Vector2(-half, -half), pos + Vector2(half, half), color, 2.0)
	draw_line(pos + Vector2(-half, half), pos + Vector2(half, -half), color, 2.0)
