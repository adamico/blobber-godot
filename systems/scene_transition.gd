extends CanvasLayer

signal transition_finished(scene_path: String)

@export var default_fade_out_duration := 0.2
@export var default_fade_in_duration := 0.2
@export var fade_color := Color(0, 0, 0, 1)

var _is_transitioning := false
var _fade_rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_fade_rect()
	_set_overlay_alpha(0.0)
	visible = false


func change_scene_to_file(
	scene_path: String,
	fade_out_duration: float = -1.0,
	fade_in_duration: float = -1.0,
) -> void:
	if scene_path.is_empty() or _is_transitioning:
		return
	if get_tree() == null:
		return

	var out_duration := fade_out_duration if fade_out_duration >= 0.0 else default_fade_out_duration
	var in_duration := fade_in_duration if fade_in_duration >= 0.0 else default_fade_in_duration

	_is_transitioning = true
	visible = true
	_ensure_fade_rect()

	await _fade_to_alpha(1.0, out_duration)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _fade_to_alpha(0.0, in_duration)

	visible = false
	_is_transitioning = false
	transition_finished.emit(scene_path)


func is_transitioning() -> bool:
	return _is_transitioning


func _ensure_fade_rect() -> void:
	if _fade_rect != null:
		return

	_fade_rect = ColorRect.new()
	_fade_rect.name = "SceneFadeRect"
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.anchor_left = 0.0
	_fade_rect.anchor_top = 0.0
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.offset_left = 0.0
	_fade_rect.offset_top = 0.0
	_fade_rect.offset_right = 0.0
	_fade_rect.offset_bottom = 0.0
	_fade_rect.color = fade_color
	add_child(_fade_rect)


func _fade_to_alpha(target_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return

	var clamped_duration := maxf(duration, 0.0)
	if clamped_duration <= 0.0:
		_set_overlay_alpha(target_alpha)
		return

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_method(_set_overlay_alpha, _fade_rect.color.a, target_alpha, clamped_duration)
	await tween.finished


func _set_overlay_alpha(alpha: float) -> void:
	if _fade_rect == null:
		return
	var next_color := fade_color
	next_color.a = clampf(alpha, 0.0, 1.0)
	_fade_rect.color = next_color
