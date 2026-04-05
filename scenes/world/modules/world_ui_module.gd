class_name WorldUIModule
extends Node

var _player
var _debug_panel: Control
var _grid_coords_label: Label
var _minimap_overlay: Control
var _hp_bar: ProgressBar
var _show_minimap := false
var _analysis_hud: Control
# Marker discovery caching: cells we've seen via LOS
var _discovered_exit_cells: Dictionary = {}
var _discovered_chute_cells: Dictionary = {}
var _discovered_pickup_cells: Dictionary = {}
var _discovered_chest_cells: Dictionary = {}
# Hostile tracking: instance ID -> last known position
var _hostile_last_seen_positions: Dictionary = {}


func configure(
		player,
		debug_panel: Control,
		grid_coords_label: Label,
		minimap_overlay: Control,
) -> void:
	_player = player
	_debug_panel = debug_panel
	_grid_coords_label = grid_coords_label
	_minimap_overlay = minimap_overlay


func setup_hp_bar(overlay_layer: CanvasLayer) -> void:
	if _player == null or _player.stats == null or overlay_layer == null:
		return

	var panel := PanelContainer.new()
	panel.name = "HPBarPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(8.0, -8.0)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	var label := Label.new()
	label.text = "HP"
	hbox.add_child(label)

	var bar := ProgressBar.new()
	bar.name = "HPBar"
	bar.custom_minimum_size = Vector2(120.0, 16.0)
	bar.min_value = 0.0
	bar.max_value = float(_player.stats.max_health)
	bar.value = float(_player.stats.health)
	bar.show_percentage = false
	hbox.add_child(bar)
	_hp_bar = bar

	overlay_layer.add_child(panel)
	_player.stats.damaged.connect(_on_player_damaged)
	_player.stats.healed.connect(_on_player_healed)


func assign_analysis_hud(hud: Control, turn_manager: WorldTurnManager) -> void:
	if hud == null or turn_manager == null:
		return
	_analysis_hud = hud
	if _analysis_hud.has_method("configure"):
		_analysis_hud.call("configure", turn_manager)


func apply_debug_panel_visibility(show: bool) -> void:
	if _debug_panel != null:
		_debug_panel.visible = show


func apply_grid_coords_visibility(show: bool) -> void:
	if _grid_coords_label != null:
		_grid_coords_label.visible = show


func apply_minimap_visibility(show: bool) -> void:
	_show_minimap = show
	if _minimap_overlay != null:
		_minimap_overlay.visible = show


func toggle_minimap() -> bool:
	_show_minimap = not _show_minimap
	if _minimap_overlay != null:
		_minimap_overlay.visible = _show_minimap
	return _show_minimap


func refresh_coords(cell_hint: Vector2i = Vector2i.ZERO) -> void:
	if _grid_coords_label == null:
		return

	var coords := cell_hint
	if _player != null and _player.grid_state != null:
		coords = _player.grid_state.cell

	_grid_coords_label.text = "X: %d  Y: %d" % [coords.x, coords.y]


func refresh_minimap(cell_hint: Vector2i, occupancy: GridOccupancyMap) -> void:
	if _minimap_overlay == null:
		return

	var coords := cell_hint
	var facing := GridDefinitions.Facing.NORTH
	if _player != null and _player.grid_state != null:
		coords = _player.grid_state.cell
		facing = _player.grid_state.facing

	if _minimap_overlay.has_method("set_occupancy"):
		_minimap_overlay.call("set_occupancy", occupancy)
	if _minimap_overlay.has_method("set_player_state"):
		_minimap_overlay.call("set_player_state", coords, facing)

	var hostile_cells := _collect_last_known_enemy_cells(coords, occupancy)

	if _minimap_overlay.has_method("set_marker_cells"):
		_minimap_overlay.call(
			"set_marker_cells",
			_collect_group_cells_with_los(
				&"world_exit_cells",
				coords,
				occupancy,
				_discovered_exit_cells,
			),
			_collect_group_cells_with_los(
				&"disposal_chutes",
				coords,
				occupancy,
				_discovered_chute_cells,
			),
			_collect_group_cells_with_los(
				&"world_pickups",
				coords,
				occupancy,
				_discovered_pickup_cells,
			),
			_collect_group_cells_with_los(
				&"world_chests",
				coords,
				occupancy,
				_discovered_chest_cells,
			),
			hostile_cells,
		)


func _collect_group_cells_with_los(
		group_name: StringName,
		player_cell: Vector2i,
		occupancy: GridOccupancyMap,
		discovery_cache: Dictionary,
	) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _player == null or _player.get_tree() == null or occupancy == null:
		return cells

	for node in _player.get_tree().get_nodes_in_group(group_name):
		if node == null or not is_instance_valid(node):
			continue
		if not ("grid_cell" in node):
			continue

		var marker_cell := node.grid_cell as Vector2i
		# Check if currently visible via LOS
		if occupancy.is_line_of_sight_clear(player_cell, marker_cell):
			cells.append(marker_cell)
			discovery_cache[marker_cell] = true
		# Include discovered cells (persist on minimap)
		elif marker_cell in discovery_cache:
			cells.append(marker_cell)

	return cells


func _collect_last_known_enemy_cells(
		player_cell: Vector2i,
		occupancy: GridOccupancyMap,
	) -> Array[Vector2i]:
	if _player == null or _player.get_tree() == null:
		return []

	var active_hostile_ids: Dictionary = {}
	var visible_or_cached_cells: Dictionary = {}

	for node in _player.get_tree().get_nodes_in_group(&"grid_hostiles"):
		if node == null or not is_instance_valid(node):
			continue

		var stats: Variant = node.get("stats")
		if stats != null and stats.has_method("is_dead") and bool(stats.call("is_dead")):
			continue

		if not ("grid_state" in node):
			continue
		var grid_state = node.grid_state
		if grid_state == null:
			continue

		var hostile_id: int = node.get_instance_id()
		active_hostile_ids[hostile_id] = true
		var cell := grid_state.cell as Vector2i

		# Only update cache if we have LOS to this hostile
		if occupancy != null and occupancy.is_line_of_sight_clear(player_cell, cell):
			_hostile_last_seen_positions[hostile_id] = cell

	for hostile_id in _hostile_last_seen_positions.keys():
		if not active_hostile_ids.has(hostile_id):
			_hostile_last_seen_positions.erase(hostile_id)

	for cached_cell in _hostile_last_seen_positions.values():
		visible_or_cached_cells[cached_cell] = true

	var hostile_cells: Array[Vector2i] = []
	for hostile_cell in visible_or_cached_cells.keys():
		hostile_cells.append(hostile_cell as Vector2i)

	return hostile_cells


func refresh_debug_buttons(_overlay_open: bool) -> void:
	pass


func _on_player_damaged(_amount: int, _old_health: int, new_health: int) -> void:
	if _hp_bar == null:
		return
	_hp_bar.value = float(new_health)


func _on_player_healed(_amount: int, _old_health: int, new_health: int) -> void:
	if _hp_bar == null:
		return
	_hp_bar.value = float(new_health)
