class_name WorldLevelManager
extends Node

var current_floor := 1
var max_floor := 5
var cleanup_score := 0.0
var max_cleanup_score := 100.0


func start_run() -> void:
	current_floor = 1
	cleanup_score = 0.0
	_load_current_floor()


func add_cleanup_points(points: float) -> void:
	cleanup_score = clampf(cleanup_score + points, 0.0, max_cleanup_score)


func advance_floor() -> void:
	current_floor += 1
	if current_floor > max_floor:
		# User has cleaned all floors, show the final victory
		var main = get_tree().current_scene
		if main != null and main.has_method("finish_with_success"):
			main.finish_with_success()
	else:
		_load_current_floor()


func _load_current_floor() -> void:
	var path := "res://scenes/levels/floor_%d.tscn" % current_floor
	if not FileAccess.file_exists(path):
		printerr("[LevelManager] Floor scene missing: " + path)
		return

	var err = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to load floor at path: " + path)
