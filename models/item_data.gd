class_name ItemData
extends Resource

enum ItemType {
	CONSUMABLE,
	TOOL,
	DEBRIS,
}

@export var item_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.TOOL
@export var tool_property: RpsSystem.ToolProperty = RpsSystem.ToolProperty.OTHER
@export var pickup_texture: Texture2D
@export_range(0, 2) var use_range: int = 1 ## 0 = self, 1 = adjacent, 2 = one tile ahead
@export var is_reusable: bool = true
@export var is_aoe: bool = false
# TODO: make this a resource post jam
@export var stat_effect: Dictionary = { } ## e.g. {"heal": 2} for consumables
@export var analysis_profile: Resource

# Runtime tracking for DEBRIS items
var origin_hostile_definition_id: StringName = StringName()
var revert_turns_base: int = 5
var cleanup_value: int = 1
