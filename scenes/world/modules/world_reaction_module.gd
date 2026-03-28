class_name WorldReactionModule
extends Node

@export var reaction_table: ReactionTable


func react(item_a: ItemData, item_b: ItemData) -> ItemData:
	if reaction_table == null:
		return null
	return reaction_table.get_reaction_result(item_a, item_b)
