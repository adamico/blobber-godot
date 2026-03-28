class_name ReactionTable
extends Resource

@export var rules: Array[ReactionRule] = []

func get_reaction_result(item_a: ItemData, item_b: ItemData) -> ItemData:
	if item_a == null or item_b == null:
		return null
	
	for rule in rules:
		for prop_a in item_a.properties:
			for prop_b in item_b.properties:
				if rule.matches(prop_a, prop_b):
					return rule.result_item
					
	return null
