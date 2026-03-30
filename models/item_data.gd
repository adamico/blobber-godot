class_name ItemData
extends Resource

enum ItemType {
	CONSUMABLE,
	TOOL,
	DEBRIS,
}

@export var item_name: String = ""
@export var description: String = ""
@export var item_type: ItemType = ItemType.TOOL
@export var tool_class: RpsSystem.ToolClass = RpsSystem.ToolClass.UTILITY
@export var use_range: int = 1  ## 1 = adjacent, 2 = one tile ahead
@export var is_reusable: bool = true  ## false for Synth-Gel Packet
@export var stat_effect: Dictionary = {}  ## e.g. {"heal": 2} for consumables
