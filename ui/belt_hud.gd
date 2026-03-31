extends Control
## Always-visible 3-slot utility belt at the bottom of the screen.
## Shows item name and slot key (1/2/3).

@onready var _slot_1_label: Label = %Label1
@onready var _slot_2_label: Label = %Label2
@onready var _slot_3_label: Label = %Label3
@onready var _slot_1_key: Label = %Key1
@onready var _slot_2_key: Label = %Key2
@onready var _slot_3_key: Label = %Key3
@onready var _slot_1_panel: PanelContainer = %Slot1
@onready var _slot_2_panel: PanelContainer = %Slot2
@onready var _slot_3_panel: PanelContainer = %Slot3
@onready var _slot_1_property: Label = %Property1
@onready var _slot_2_property: Label = %Property2
@onready var _slot_3_property: Label = %Property3

var _player: Player
var _tool_property = RpsSystem.ToolProperty


func configure(player: Player) -> void:
	_player = player
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _player == null or _player.inventory == null:
		_set_slot(_slot_1_label, _slot_1_key, _slot_1_panel, _slot_1_property, null, "1")
		_set_slot(_slot_2_label, _slot_2_key, _slot_2_panel, _slot_2_property, null, "2")
		_set_slot(_slot_3_label, _slot_3_key, _slot_3_panel, _slot_3_property, null, "3")
		return

	var items = _player.inventory.get_items() as Array[ItemData]

	_set_slot(
		_slot_1_label,
		_slot_1_key,
		_slot_1_panel,
		_slot_1_property,
		items[0] if items.size() > 0 else null,
		"1",
	)
	_set_slot(
		_slot_2_label,
		_slot_2_key,
		_slot_2_panel,
		_slot_2_property,
		items[1] if items.size() > 1 else null,
		"2",
	)
	_set_slot(
		_slot_3_label,
		_slot_3_key,
		_slot_3_panel,
		_slot_3_property,
		items[2] if items.size() > 2 else null,
		"3",
	)


func _set_slot(
		label: Label,
		key_label: Label,
		panel: PanelContainer,
		property_label: Label,
		item: ItemData,
		key: String,
) -> void:
	if key_label != null:
		key_label.text = "[%s]" % key

	if label != null:
		if item != null:
			label.text = item.item_name
		else:
			label.text = ""

	if property_label != null:
		if item != null:
			var property_text: String = _tool_property.keys()[item.tool_property].capitalize()
			property_label.text = "(%s)" % property_text
		else:
			property_label.text = ""

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
