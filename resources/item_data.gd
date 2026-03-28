class_name ItemData
extends Resource

@export var item_name: String = "Unknown Item"
@export var texture: Texture2D
@export var properties: Array[StringName] = []
@export var is_potion: bool = false

func has_property(prop: StringName) -> bool:
	return properties.has(prop)
