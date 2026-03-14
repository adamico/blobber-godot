extends Node
class_name WorldRunOutcomeModule

signal success_reached
signal failure_reached

var _enable_cell_end_conditions := true
var _success_goal_cell := Vector2i(2, -2)
var _failure_goal_cell := Vector2i(-2, 2)

var _run_is_resolved := false


func configure(enable_cell_end_conditions: bool, success_goal_cell: Vector2i, failure_goal_cell: Vector2i) -> void:
	_enable_cell_end_conditions = enable_cell_end_conditions
	_success_goal_cell = success_goal_cell
	_failure_goal_cell = failure_goal_cell


func reset_run() -> void:
	_run_is_resolved = false


func is_resolved() -> bool:
	return _run_is_resolved


func evaluate(cell: Vector2i) -> void:
	if not _enable_cell_end_conditions or _run_is_resolved:
		return

	if cell == _success_goal_cell:
		_run_is_resolved = true
		success_reached.emit()
		return

	if cell == _failure_goal_cell:
		_run_is_resolved = true
		failure_reached.emit()
