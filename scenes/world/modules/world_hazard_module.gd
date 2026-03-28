class_name WorldHazardModule
extends Node

@export var hazardous_cells: Dictionary = { } # Vector2i -> StringName (type)


func interact(player: Player, cell: Vector2i) -> bool:
	if not hazardous_cells.has(cell):
		return false

	var hazard_type = hazardous_cells[cell]
	var required_prop = _get_counter_property(hazard_type)

	var has_counter = false
	if player.inventory != null:
		for item in player.inventory.get_items():
			if item.has_property(required_prop):
				has_counter = true
				break

	if has_counter:
		# Hazard defused
		hazardous_cells.erase(cell)
		print("[Hazard] Defused %s at %s" % [hazard_type, cell])
		_play_defusal_feedback()
		return true
	
	print("[Hazard] Cannot defuse %s without property: %s" % [hazard_type, required_prop])
	return false


func evaluate_hazard(player: Player, cell: Vector2i) -> bool:
	if not hazardous_cells.has(cell):
		return true

	var hazard_type = hazardous_cells[cell]
	
	# Hazard triggered because it wasn't defused actively
	print("[Hazard] Triggered %s at %s" % [hazard_type, cell])
	if player.stats != null:
		player.stats.drain_stamina(1)

	return false


func _get_counter_property(hazard_type: StringName) -> StringName:
	match hazard_type:
		&"volatile":
			return &"wet"
		&"corrosive":
			return &"neutralizer"
		_:
			return &"none"


func _play_defusal_feedback() -> void:
	# Placeholder for future visual/audio feedback
	print("[Hazard] Interaction successful: Hazard neutralized.")
