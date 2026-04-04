class_name ScreenFlashPlayer
extends CanvasLayer

var _flash_rect: ColorRect
var _active_tween: Tween


func _ready() -> void:
	layer = 10
	_flash_rect = ColorRect.new()
	_flash_rect.name = "FlashRect"
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.visible = false
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)


func play(entry) -> void:
	if entry == null or _flash_rect == null:
		return

	if is_instance_valid(_active_tween):
		_active_tween.kill()

	var peak_alpha := clampf(entry.flash_peak_alpha * maxf(entry.intensity, 1.0), 0.0, 1.0)
	var flash_color: Color = entry.color
	flash_color.a = 0.0
	_flash_rect.color = flash_color
	_flash_rect.visible = true

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(
		_flash_rect,
		"color:a",
		peak_alpha,
		maxf(entry.duration * 0.35, 0.02),
	)
	_active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(_flash_rect, "color:a", 0.0, maxf(entry.duration * 0.65, 0.02))
	_active_tween.finished.connect(_on_flash_finished, CONNECT_ONE_SHOT)


func _on_flash_finished() -> void:
	_active_tween = null
	if _flash_rect == null:
		return
	_flash_rect.visible = false
