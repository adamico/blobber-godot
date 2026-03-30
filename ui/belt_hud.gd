extends Control
## Always-visible 3-slot utility belt at the bottom of the screen.
## Shows item name and slot key (1/2/3).

@onready var _slot_1_label: Label = $HBox/Slot1/Label
@onready var _slot_2_label: Label = $HBox/Slot2/Label
@onready var _slot_3_label: Label = $HBox/Slot3/Label
@onready var _slot_1_key: Label = $HBox/Slot1/Key
@onready var _slot_2_key: Label = $HBox/Slot2/Key
@onready var _slot_3_key: Label = $HBox/Slot3/Key
@onready var _slot_1_panel: PanelContainer = $HBox/Slot1
@onready var _slot_2_panel: PanelContainer = $HBox/Slot2
@onready var _slot_3_panel: PanelContainer = $HBox/Slot3

var _player: Player


func configure(player: Player) -> void:
	_player = player
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _player == null or _player.inventory == null:
		_set_slot(_slot_1_label, _slot_1_key, _slot_1_panel, null, "1")
		_set_slot(_slot_2_label, _slot_2_key, _slot_2_panel, null, "2")
		_set_slot(_slot_3_label, _slot_3_key, _slot_3_panel, null, "3")
		return

	var items = _player.inventory.get_items() as Array[ItemData]

	_set_slot(
		_slot_1_label,
		_slot_1_key,
		_slot_1_panel,
		items[0] if items.size() > 0 else null,
		"1",
	)
	_set_slot(
		_slot_2_label,
		_slot_2_key,
		_slot_2_panel,
		items[1] if items.size() > 1 else null,
		"2",
	)
	_set_slot(
		_slot_3_label,
		_slot_3_key,
		_slot_3_panel,
		items[2] if items.size() > 2 else null,
		"3",
	)


func _set_slot(
		label: Label,
		key_label: Label,
		panel: PanelContainer,
		item: ItemData,
		key: String,
) -> void:
	if key_label != null:
		key_label.text = "[%s]" % key

	if label != null:
		if item != null:
			var tag := ""
			if item.item_type == ItemData.ItemType.TOOL:
				tag = " (%s)" % RpsSystem.ToolClass.keys()[item.tool_class].capitalize()
			elif item.item_type == ItemData.ItemType.DEBRIS:
				tag = " [DEBRIS]"
			label.text = item.item_name + tag
		else:
			label.text = "- Empty -"

	if panel != null:
		panel.modulate.a = 0.4 if item == null else 1.0
		if item != null:
			match item.tool_class:
				RpsSystem.ToolClass.SOAKED:
					panel.self_modulate = Color(0.2, 0.5, 1.0) # Blue
				RpsSystem.ToolClass.INERT:
					panel.self_modulate = Color(0.6, 0.6, 0.6) # Gray
				RpsSystem.ToolClass.CLEANSED:
					panel.self_modulate = Color(1.0, 0.9, 0.2) # Yellow
				_:
					panel.self_modulate = Color.WHITE
		else:
			panel.self_modulate = Color.WHITE
