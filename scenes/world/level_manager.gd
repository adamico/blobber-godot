class_name WorldLevelManager
extends Node

var current_floor := 1
var max_floor := 5


func start_run() -> void:
	current_floor = 1
	_load_current_floor()


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
	var err = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to load floor at path: " + path)
		# Fallback to main.tscn for debugging if level is missing
		get_tree().change_scene_to_file("res://scenes/world/main.tscn")
