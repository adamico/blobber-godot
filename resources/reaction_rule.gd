class_name ReactionRule
extends Resource

@export var required_property_a: StringName
@export var required_property_b: StringName
@export var result_item: ItemData


func matches(prop_a: StringName, prop_b: StringName) -> bool:
	return (
		prop_a == required_property_a
		and prop_b == required_property_b
	) or (
		prop_a == required_property_b
		and prop_b == required_property_a
	)
