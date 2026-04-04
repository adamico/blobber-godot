extends Node

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/world/main.tscn"
@export var enable_timing_logs := false

var _game_start_time := 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		return
	if what == NOTIFICATION_ENTER_TREE:
		_game_start_time = Time.get_ticks_msec()
		if enable_timing_logs:
			print("[BootSequence] engine_start | ticks_ms=0")


func _ready() -> void:
	var elapsed := Time.get_ticks_msec() - _game_start_time
	if enable_timing_logs:
		print("[BootSequence] GameBoot._ready() | ticks_ms=%d" % [elapsed])
	_prime_gameplay_scene()
	elapsed = Time.get_ticks_msec() - _game_start_time
	if enable_timing_logs:
		print("[BootSequence] GameBoot prime_requested | ticks_ms=%d" % [elapsed])


func _prime_gameplay_scene() -> void:
	if gameplay_scene_path.is_empty():
		return

	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition != null and scene_transition.has_method("prime_scene_load"):
		scene_transition.call("prime_scene_load", gameplay_scene_path)


func get_start_time() -> int:
	return Time.get_ticks_msec() - _game_start_time

