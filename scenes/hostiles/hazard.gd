class_name Hazard
extends Hostile

signal hostile_cleared(hostile: Hazard)

@export var hazard_property: RpsSystem.HazardProperty = RpsSystem.HazardProperty.BURNING
@export var display_name_override: String = ""
@export var sprite_texture: Texture2D
@export var contact_damage: int = 1
@export var hazard_hp: int = 3 ## Hits needed with non-matching tools
@export var revert_turns_base: int = 5 ## Default turns until debris reverts to this hazard
@export var cleanup_value: int = 1

@onready var label: Label3D = %Label3D
@onready var sprite: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

var _current_hp: int = 1


func _ready() -> void:
	super()
	_current_hp = hazard_hp
	if display_name_override != "":
		label.text = display_name_override
	else:
		label.text = RpsSystem.HazardProperty.keys()[hazard_property].capitalize()

	if sprite != null and sprite_texture != null:
		sprite.texture = sprite_texture
		var sprite_mat := sprite.material_override as ShaderMaterial
		if sprite_mat != null:
			sprite_mat = sprite_mat.duplicate() as ShaderMaterial
			sprite.material_override = sprite_mat
			sprite_mat.set_shader_parameter("sprite_texture", sprite_texture)
		if mesh != null:
			mesh.visible = false


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
	hostile_cleared.emit(self)
	# Mark stats as dead so encounter module filters it out
	if stats != null:
		stats.take_damage(stats.max_health + 1)
	visible = false
	ai_enabled = false
