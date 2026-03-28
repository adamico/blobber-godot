extends Node

class_name WorldInputOrchestrator

var _btn_toggle_minimap: Button
var _btn_close_overlay: Button

var _toggle_minimap_fn: Callable
var _close_overlay_fn: Callable


func configure(
		btn_toggle_minimap: Button,
		btn_close_overlay: Button,
		toggle_minimap_fn: Callable,
		close_overlay_fn: Callable,
) -> void:
	_btn_toggle_minimap = btn_toggle_minimap
	_btn_close_overlay = btn_close_overlay
	_toggle_minimap_fn = toggle_minimap_fn
	_close_overlay_fn = close_overlay_fn


func wire_overlay_controls() -> void:
	var connected_minimap := _btn_toggle_minimap.pressed.is_connected(_toggle_minimap_fn)
	if _btn_toggle_minimap != null and not connected_minimap:
		_btn_toggle_minimap.pressed.connect(_toggle_minimap_fn)

	var connected_close := _btn_close_overlay.pressed.is_connected(_close_overlay_fn)
	if _btn_close_overlay != null and not connected_close:
		_btn_close_overlay.pressed.connect(_close_overlay_fn)


func handle_unhandled_input(event: InputEvent, gameplay_active: bool) -> bool:
	if event is InputEventKey and event.echo:
		return false

	if not gameplay_active:
		return false

	if event.is_action_pressed("close_overlay") or event.is_action_pressed("ui_cancel"):
		_close_overlay_fn.call()
		return true

	return false
