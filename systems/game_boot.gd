extends Node

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/world/main.tscn"
@export var enable_timing_logs := false

var _game_start_time := 0
var current_floor_number := 1
var persisted_health: int = 0


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


func clear_dialog_persistence() -> void:
	var file_path := "user://dialog_seen.cfg"
	var dir := DirAccess.open("user://")
	if dir != null:
		if dir.file_exists(file_path.get_file()):
			var err := dir.remove(file_path.get_file())
			if err != OK and enable_timing_logs:
				print("[BootSequence] Failed to clear dialog persistence: error %d" % err)


func _prime_gameplay_scene() -> void:
	if gameplay_scene_path.is_empty():
		return

	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition != null and scene_transition.has_method("prime_scene_load"):
		scene_transition.call("prime_scene_load", gameplay_scene_path)


func get_start_time() -> int:
	return Time.get_ticks_msec() - _game_start_time
