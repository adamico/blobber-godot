class_name EntityFlashPlayer
extends Node

var _active_tweens_by_id: Dictionary = {}
var _base_modulate_by_id: Dictionary = {}


func play_hostile(hostile: Hostile, entry) -> void:
	if hostile == null or entry == null:
		return

	var sprite := hostile.get_node_or_null("Sprite3D") as Sprite3D
	if sprite == null:
		return

	var key := hostile.get_instance_id()
	if is_instance_valid(_active_tweens_by_id.get(key, null)):
		(_active_tweens_by_id[key] as Tween).kill()

	var base_modulate := sprite.modulate
	_base_modulate_by_id[key] = base_modulate

	var flash_color := base_modulate.lerp(entry.color, clampf(entry.intensity, 0.0, 1.0))
	flash_color.a = base_modulate.a
	sprite.modulate = flash_color

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", base_modulate, maxf(entry.duration, 0.03))
	tween.finished.connect(_on_flash_finished.bind(key, sprite), CONNECT_ONE_SHOT)
	_active_tweens_by_id[key] = tween


func _on_flash_finished(key: int, sprite: Sprite3D) -> void:
	var base_modulate := _base_modulate_by_id.get(key, Color(1.0, 1.0, 1.0, 1.0)) as Color
	if sprite != null:
		sprite.modulate = base_modulate
	_active_tweens_by_id.erase(key)
	_base_modulate_by_id.erase(key)
