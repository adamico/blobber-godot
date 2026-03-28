class_name WorldUIModule
extends Node

var _player
var _debug_panel: Control
var _grid_coords_label: Label
var _minimap_overlay: Control
var _btn_close_overlay: Button
var _stamina_bar: ProgressBar
var _slot_container: HBoxContainer
var _cleanup_label: Label
var _show_minimap := false
var _inventory: Inventory


func configure(
		player,
		debug_panel: Control,
		grid_coords_label: Label,
		minimap_overlay: Control,
		btn_close: Button,
) -> void:
	_player = player
	_debug_panel = debug_panel
	_grid_coords_label = grid_coords_label
	_minimap_overlay = minimap_overlay
	_btn_close_overlay = btn_close


func setup_stamina_and_inventory(overlay_layer: CanvasLayer) -> void:
	if _player == null or _player.stats == null or overlay_layer == null:
		return

	_inventory = _player.inventory

	var panel := PanelContainer.new()
	panel.name = "HUDPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(8.0, -8.0)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hbox_stam := HBoxContainer.new()
	hbox_stam.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox_stam)

	var label := Label.new()
	label.text = "STA"
	hbox_stam.add_child(label)

	var bar := ProgressBar.new()
	bar.name = "StaminaBar"
	bar.custom_minimum_size = Vector2(120.0, 16.0)
	bar.min_value = 0.0
	bar.max_value = float(_player.stats.max_stamina)
	bar.value = float(_player.stats.stamina)
	bar.show_percentage = false
	hbox_stam.add_child(bar)
	_stamina_bar = bar

	var hbox_inv := HBoxContainer.new()
	hbox_inv.name = "InventorySlots"
	hbox_inv.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox_inv)
	_slot_container = hbox_inv

	var lbl_clean := Label.new()
	lbl_clean.name = "CleanupLabel"
	lbl_clean.text = "Clean: 0%"
	vbox.add_child(lbl_clean)
	_cleanup_label = lbl_clean

	overlay_layer.add_child(panel)

	_player.stats.stamina_changed.connect(_on_stamina_changed)
	if _inventory != null:
		_inventory.capacity_changed.connect(_on_capacity_changed)
		_inventory.item_added.connect(_on_inventory_changed)
		_inventory.item_removed.connect(_on_inventory_changed)
		_inventory.item_used.connect(_on_inventory_changed)
		_rebuild_inventory_ui()


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

	_grid_coords_label.text = "Grid X: %d  Y: %d" % [coords.x, coords.y]


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


func refresh_debug_buttons(overlay_open: bool) -> void:
	if _btn_close_overlay != null:
		_btn_close_overlay.disabled = not overlay_open


func refresh_cleanup_score(score: float, max_score: float) -> void:
	if _cleanup_label == null:
		return
	var pct := (score / max_score) * 100.0
	_cleanup_label.text = "Clean: %d%%" % int(pct)


func _on_stamina_changed(_old_stamina: int, new_stamina: int) -> void:
	if _stamina_bar == null:
		return
	_stamina_bar.value = float(new_stamina)


func _on_capacity_changed(_new_cap) -> void:
	_rebuild_inventory_ui()


func _on_inventory_changed(_item) -> void:
	_rebuild_inventory_ui()


func _rebuild_inventory_ui() -> void:
	if _slot_container == null or _inventory == null:
		return

	for child in _slot_container.get_children():
		child.queue_free()

	var items = _inventory.get_items()
	for i in range(_inventory.max_capacity):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(32, 32)
		if i < items.size():
			var item: ItemData = items[i]
			if item.texture != null:
				var tex_rect := TextureRect.new()
				tex_rect.texture = item.texture
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				slot.add_child(tex_rect)
			else:
				var lbl := Label.new()
				lbl.text = "?"
				lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slot.add_child(lbl)
		_slot_container.add_child(slot)
