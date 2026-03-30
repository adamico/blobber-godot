class_name WorldInputOrchestrator
extends Node
## Stripped-down input orchestrator. All overlay button wiring removed.
## Player handles its own input via _unhandled_input.

var _btn_toggle_minimap: Button
var _toggle_minimap_fn: Callable


func configure(
		btn_toggle_minimap: Button,
		toggle_minimap_fn: Callable,
) -> void:
	_btn_toggle_minimap = btn_toggle_minimap
	_toggle_minimap_fn = toggle_minimap_fn


func wire_overlay_controls() -> void:
	if _btn_toggle_minimap != null and _toggle_minimap_fn.is_valid():
		if not _btn_toggle_minimap.pressed.is_connected(_toggle_minimap_fn):
			_btn_toggle_minimap.pressed.connect(_toggle_minimap_fn)


func handle_unhandled_input(_event: InputEvent, _gameplay_active: bool) -> bool:
	return false
