extends Node

class_name WorldRunOutcomeModule

signal success_reached
signal failure_reached

const EXIT_GROUP := &"world_exit_cells"

var _enable_cell_end_conditions := true
var _failure_goal_cell := Vector2i(-2, 2)
var _world_root: Node
var _run_is_resolved := false


func configure(
		enable_cell_end_conditions: bool,
		failure_goal_cell: Vector2i,
		world_root: Node,
) -> void:
	_enable_cell_end_conditions = enable_cell_end_conditions
	_failure_goal_cell = failure_goal_cell
	_world_root = world_root


func reset_run() -> void:
	_run_is_resolved = false


func is_resolved() -> bool:
	return _run_is_resolved


func evaluate(cell: Vector2i) -> void:
	if not _enable_cell_end_conditions or _run_is_resolved:
		return

	if _is_exit_reached(cell):
		_run_is_resolved = true
		success_reached.emit()
		return

	if cell == _failure_goal_cell:
		_run_is_resolved = true
		failure_reached.emit()


func _is_exit_reached(cell: Vector2i) -> bool:
	if _world_root == null or _world_root.get_tree() == null:
		return false

	for node in _world_root.get_tree().get_nodes_in_group(EXIT_GROUP):
		if node == null:
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		if node.has_method("matches_cell") and not bool(node.call("matches_cell", cell)):
			continue
		if node.has_method("can_trigger") and not bool(node.call("can_trigger")):
			continue
		return true

	return false
