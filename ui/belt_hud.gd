extends Control
## Always-visible 3-slot utility belt at the bottom of the screen.
## Shows slot key and icon (1/2/3).

@onready var _slot_1_key: Label = %Key1
@onready var _slot_2_key: Label = %Key2
@onready var _slot_3_key: Label = %Key3
@onready var _slot_1_panel: PanelContainer = %Slot1
@onready var _slot_2_panel: PanelContainer = %Slot2
@onready var _slot_3_panel: PanelContainer = %Slot3
@onready var _slot_1_icon: TextureRect = %Icon1
@onready var _slot_2_icon: TextureRect = %Icon2
@onready var _slot_3_icon: TextureRect = %Icon3
@onready var _slot_popup: PanelContainer = %SlotPopup
@onready var _slot_popup_name_label: Label = %SlotPopupNameLabel
@onready var _slot_popup_meta_label: Label = %SlotPopupMetaLabel
@onready var _slot_popup_body_label: Label = %SlotPopupBodyLabel

var _player: Player
var _turn_manager: WorldTurnManager
var _tool_property = RpsSystem.ToolProperty
var _hovered_slot_index := -1


func _ready() -> void:
	_bind_slot_hover(_slot_1_panel, 0)
	_bind_slot_hover(_slot_2_panel, 1)
	_bind_slot_hover(_slot_3_panel, 2)
	_hide_slot_popup()


func configure(player: Player, turn_manager: WorldTurnManager = null) -> void:
	_player = player
	_turn_manager = turn_manager
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _player == null or _player.inventory == null:
		_set_slot(
			_slot_1_key,
			_slot_1_panel,
			_slot_1_icon,
			null,
			"1",
		)
		_set_slot(
			_slot_2_key,
			_slot_2_panel,
			_slot_2_icon,
			null,
			"2",
		)
		_set_slot(
			_slot_3_key,
			_slot_3_panel,
			_slot_3_icon,
			null,
			"3",
		)
		return

	var items = _player.inventory.get_items() as Array[ItemData]

	_set_slot(
		_slot_1_key,
		_slot_1_panel,
		_slot_1_icon,
		items[0] if items.size() > 0 else null,
		"1",
	)
	_set_slot(
		_slot_2_key,
		_slot_2_panel,
		_slot_2_icon,
		items[1] if items.size() > 1 else null,
		"2",
	)
	_set_slot(
		_slot_3_key,
		_slot_3_panel,
		_slot_3_icon,
		items[2] if items.size() > 2 else null,
		"3",
	)

	_update_slot_popup()


func _set_slot(
		key_label: Label,
		panel: PanelContainer,
		icon: TextureRect,
		item: ItemData,
		key: String,
) -> void:
	if key_label != null:
		key_label.text = "[%s]" % key

	if icon != null:
		if item != null and item.pickup_texture != null:
			icon.texture = item.pickup_texture
			icon.self_modulate.a = 1.0
		else:
			icon.texture = null
			# Keep the control visible so VBox layout does not collapse in empty slots.
			icon.self_modulate.a = 0.0

	if panel != null:
		panel.modulate.a = 0.4 if item == null else 1.0
		if item != null:
			match item.tool_property:
				_tool_property.SOAKED:
					panel.self_modulate = Color(0.2, 0.5, 1.0) # Blue
				_tool_property.INERT:
					panel.self_modulate = Color(0.6, 0.6, 0.6) # Gray
				_tool_property.CLEANSED:
					panel.self_modulate = Color(1.0, 0.9, 0.2) # Yellow
				_:
					panel.self_modulate = Color.WHITE
		else:
			panel.self_modulate = Color.WHITE


func _bind_slot_hover(panel: Control, slot_index: int) -> void:
	if panel == null:
		return
	panel.mouse_entered.connect(
		func() -> void:
			_on_slot_mouse_entered(slot_index)
	)
	panel.mouse_exited.connect(
		func() -> void:
			_on_slot_mouse_exited(slot_index)
	)


func _on_slot_mouse_entered(slot_index: int) -> void:
	_hovered_slot_index = slot_index
	_update_slot_popup()


func _on_slot_mouse_exited(slot_index: int) -> void:
	if _hovered_slot_index != slot_index:
		return
	_hovered_slot_index = -1
	_hide_slot_popup()


func _update_slot_popup() -> void:
	if _slot_popup == null:
		return
	if _hovered_slot_index < 0:
		_hide_slot_popup()
		return

	var item := _get_item_for_slot(_hovered_slot_index)
	if item == null:
		_hide_slot_popup()
		return

	var knowledge := _get_item_knowledge(item)
	var tier_1_known := bool(knowledge.get(WorldTurnManager.KNOWLEDGE_TIER_1, false))
	var tier_2_known := bool(knowledge.get(WorldTurnManager.KNOWLEDGE_TIER_2, false))

	if _slot_popup_name_label != null:
		_slot_popup_name_label.text = item.item_name

	if _slot_popup_meta_label != null:
		if tier_2_known and item.tool_property != _tool_property.OTHER:
			_slot_popup_meta_label.text = (
				_tool_property.keys()[item.tool_property].capitalize()
			)
		else:
			_slot_popup_meta_label.text = ""

	if _slot_popup_body_label != null:
		if tier_2_known:
			_slot_popup_body_label.text = (
				item.description
				if not item.description.is_empty()
				else "No further details recorded."
			)
		elif tier_1_known:
			_slot_popup_body_label.text = _first_line(item.description)
		else:
			_slot_popup_body_label.text = "No field notes yet. Analyze this item to learn more."

	_slot_popup.reset_size()
	_position_slot_popup(_hovered_slot_index)
	_slot_popup.visible = true


func _hide_slot_popup() -> void:
	if _slot_popup != null:
		_slot_popup.visible = false


func _position_slot_popup(slot_index: int) -> void:
	if _slot_popup == null:
		return
	var panel := _get_panel_for_slot(slot_index)
	if panel == null:
		return

	var popup_size := _slot_popup.size
	var slot_pos := panel.global_position - global_position
	var x := slot_pos.x + (panel.size.x - popup_size.x) * 0.5
	x = clamp(x, 0.0, max(0.0, size.x - popup_size.x))
	_slot_popup.position.x = x


func _get_item_knowledge(item: ItemData) -> Dictionary:
	if _turn_manager == null or item == null:
		return { }
	var type_key := item.resource_path if item.resource_path != "" else item.item_name
	return _turn_manager.get_knowledge_snapshot(StringName("pickup:%s" % type_key))


func _first_line(text: String) -> String:
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	return ""


func _get_item_for_slot(slot_index: int) -> ItemData:
	if _player == null or _player.inventory == null:
		return null
	var items = _player.inventory.get_items() as Array[ItemData]
	if slot_index < 0 or slot_index >= items.size():
		return null
	return items[slot_index]


func _get_panel_for_slot(slot_index: int) -> PanelContainer:
	match slot_index:
		0:
			return _slot_1_panel
		1:
			return _slot_2_panel
		2:
			return _slot_3_panel
		_:
			return null
