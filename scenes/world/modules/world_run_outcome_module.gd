extends Node
class_name WorldRunOutcomeModule

signal success_reached
signal failure_reached

@export var enable_cell_end_conditions := true
@export var success_goal_cell := Vector2i(2, -2)
@export var failure_goal_cell := Vector2i(-2, 2)

var _run_is_resolved := false


func reset_run() -> void:
	_run_is_resolved = false


func evaluate(_cell: Vector2i) -> void:
	if not enable_cell_end_conditions or _run_is_resolved:
		return

	if _cell == success_goal_cell:
		_run_is_resolved = true
		success_reached.emit()
		return

	if _cell == failure_goal_cell:
		_run_is_resolved = true
		failure_reached.emit()
