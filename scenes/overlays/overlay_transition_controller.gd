class_name OverlayTransitionController
extends RefCounted

var _root: Control
var _dimmer: ColorRect
var _panel: Control
var _base_dimmer_alpha := 0.72
var _base_panel_position := Vector2.ZERO
var _base_panel_scale := Vector2.ONE
var _is_closing := false


func configure(root: Control, dimmer: ColorRect, panel: Control) -> void:
	_root = root
	_dimmer = dimmer
	_panel = panel

	if _dimmer != null:
		_base_dimmer_alpha = _dimmer.color.a
	if _panel != null:
		_base_panel_position = _panel.position
		_base_panel_scale = _panel.scale


func play_enter(duration := 0.2) -> void:
	if _root == null:
		return

	_is_closing = false
	if _root.has_method("set_process_unhandled_input"):
		_root.set_process_unhandled_input(false)

	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _dimmer != null:
		var dimmer_color := _dimmer.color
		dimmer_color.a = 0.0
		_dimmer.color = dimmer_color
	if _panel != null:
		_panel.position = _base_panel_position + Vector2(0.0, 20.0)
		_panel.scale = _base_panel_scale * 0.97

	var tween := _root.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate:a", 1.0, duration)
	if _dimmer != null:
		tween.tween_property(_dimmer, "color:a", _base_dimmer_alpha, duration)
	if _panel != null:
		tween.tween_property(_panel, "position", _base_panel_position, duration)
		tween.tween_property(_panel, "scale", _base_panel_scale, duration)
	tween.finished.connect(_on_enter_finished)


func request_close(on_closed: Callable, duration := 0.16) -> void:
	if _root == null:
		if on_closed.is_valid():
			on_closed.call_deferred()
		return
	if _is_closing:
		return

	_is_closing = true
	if _root.has_method("set_process_unhandled_input"):
		_root.set_process_unhandled_input(false)

	var tween := _root.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_root, "modulate:a", 0.0, duration)
	if _dimmer != null:
		tween.tween_property(_dimmer, "color:a", 0.0, duration)
	if _panel != null:
		tween.tween_property(
			_panel,
			"position",
			_base_panel_position + Vector2(0.0, 14.0),
			duration,
		)
		tween.tween_property(_panel, "scale", _base_panel_scale * 0.985, duration)

	if on_closed.is_valid():
		tween.finished.connect(on_closed)


func is_closing() -> bool:
	return _is_closing


func _on_enter_finished() -> void:
	if _root != null and _root.has_method("set_process_unhandled_input"):
		_root.set_process_unhandled_input(true)
