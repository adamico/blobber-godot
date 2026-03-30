class_name Hazard
extends Enemy

signal hazard_cleared(hazard: Hazard)

@export var hazard_property: RpsSystem.HazardProperty = RpsSystem.HazardProperty.BURNING
@export var contact_damage: int = 1
@export var hazard_hp: int = 3 ## Hits needed with non-matching tools
@export var revert_turns_base: int = 5 ## Default turns until debris reverts to this hazard

var _current_hp: int = 1


func _ready() -> void:
	super()
	_current_hp = hazard_hp
	add_to_group("hazards")

	var lbl := Label3D.new()
	lbl.text = RpsSystem.HazardProperty.keys()[hazard_property].capitalize()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.005
	lbl.position = Vector3(0, 0.6, 0)
	add_child(lbl)


func receive_tool_hit(
		tool_property: RpsSystem.ToolProperty,
		target_stats: CharacterStats = null,
) -> bool:
	var damage := RpsSystem.compute_damage(tool_property, hazard_property)
	_current_hp -= damage
	if _current_hp <= 0:
		_clear()
		return true

	# Immediate retaliation if player is present
	if target_stats != null:
		deal_contact_damage(target_stats)

	return false


func deal_contact_damage(target_stats: CharacterStats) -> void:
	if target_stats == null:
		return
	if is_cleared():
		return
	target_stats.take_damage(contact_damage)


func is_cleared() -> bool:
	return _current_hp <= 0


func _clear() -> void:
	hazard_cleared.emit(self)
	# Mark stats as dead so encounter module filters it out
	if stats != null:
		stats.take_damage(stats.max_health + 1)
	visible = false
	ai_enabled = false
