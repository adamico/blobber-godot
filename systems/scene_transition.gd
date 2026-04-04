extends CanvasLayer

signal transition_finished(scene_path: String)

@export var default_fade_out_duration := 0.2
@export var default_fade_in_duration := 0.2
@export var fade_color := Color(0, 0, 0, 1)
@export var loading_overlay_delay := 0.5
@export var enable_timing_logs := false
@export var wait_for_first_frame_before_fade_in := false
@export var wait_for_controls_ready_before_fade_in := true
@export var controls_ready_wait_timeout_ms := 500
@export var instant_reveal_after_controls_ready := true

var _is_transitioning := false
var _fade_rect: ColorRect
var _loading_label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_fade_rect()
	_ensure_loading_label()
	_set_overlay_alpha(0.0)
	_hide_loading_overlay()
	visible = false


func prime_scene_load(scene_path: String) -> void:
	var started_at := Time.get_ticks_msec()
	_request_scene_load(scene_path)
	_log_timing("prime.requested", scene_path, started_at)


func change_scene_to_file(
		scene_path: String,
		fade_out_duration: float = -1.0,
		fade_in_duration: float = -1.0,
) -> void:
	if scene_path.is_empty() or _is_transitioning:
		return
	if get_tree() == null:
		return

	var out_duration := fade_out_duration if fade_out_duration >= 0.0 else default_fade_out_duration
	var in_duration := fade_in_duration if fade_in_duration >= 0.0 else default_fade_in_duration
	var transition_started_at := Time.get_ticks_msec()

	_is_transitioning = true
	visible = true
	_ensure_fade_rect()
	_ensure_loading_label()
	_log_timing("begin", scene_path, transition_started_at)
	_request_scene_load(scene_path)
	_log_timing("load.requested", scene_path, transition_started_at)

	await _fade_to_alpha(1.0, out_duration)
	_log_timing("fade_out.done", scene_path, transition_started_at)
	await _change_scene_with_loading(scene_path)
	_log_timing("scene_swap.done", scene_path, transition_started_at)
	if wait_for_first_frame_before_fade_in:
		await get_tree().process_frame
	var waited_for_controls_ready := false
	if wait_for_controls_ready_before_fade_in:
		waited_for_controls_ready = true
		await _wait_for_controls_ready(scene_path, transition_started_at)
	var reveal_duration := in_duration
	if waited_for_controls_ready and instant_reveal_after_controls_ready:
		reveal_duration = 0.0
	await _fade_to_alpha(0.0, reveal_duration)
	_log_timing("fade_in.done", scene_path, transition_started_at)

	_hide_loading_overlay()
	visible = false
	_is_transitioning = false
	_log_timing("complete", scene_path, transition_started_at)
	transition_finished.emit(scene_path)


func is_transitioning() -> bool:
	return _is_transitioning


func _ensure_fade_rect() -> void:
	if _fade_rect != null:
		return

	_fade_rect = ColorRect.new()
	_fade_rect.name = "SceneFadeRect"
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.anchor_left = 0.0
	_fade_rect.anchor_top = 0.0
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.offset_left = 0.0
	_fade_rect.offset_top = 0.0
	_fade_rect.offset_right = 0.0
	_fade_rect.offset_bottom = 0.0
	_fade_rect.color = fade_color
	add_child(_fade_rect)


func _ensure_loading_label() -> void:
	if _loading_label != null:
		return

	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.anchor_left = 0.5
	_loading_label.anchor_top = 0.5
	_loading_label.anchor_right = 0.5
	_loading_label.anchor_bottom = 0.5
	_loading_label.offset_left = -140.0
	_loading_label.offset_top = -20.0
	_loading_label.offset_right = 140.0
	_loading_label.offset_bottom = 20.0
	_loading_label.modulate = Color(1, 1, 1, 0.95)
	_loading_label.text = "Loading..."
	_loading_label.visible = false
	add_child(_loading_label)


func _request_scene_load(scene_path: String) -> void:
	if scene_path.is_empty():
		return

	var request_result := ResourceLoader.load_threaded_request(scene_path)
	if request_result == OK or request_result == ERR_BUSY:
		return

	push_warning("Threaded load request failed for scene: %s" % scene_path)


func _change_scene_with_loading(scene_path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var started_at := Time.get_ticks_msec()
	var loading_overlay_logged := false
	var progress: Array = []

	while true:
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
			if packed_scene != null:
				_log_timing("threaded_load.ready", scene_path, started_at)
				tree.change_scene_to_packed(packed_scene)
				return
			break

		if status == ResourceLoader.THREAD_LOAD_FAILED:
			break
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			break

		var elapsed_s := float(Time.get_ticks_msec() - started_at) / 1000.0
		if elapsed_s >= loading_overlay_delay:
			if not loading_overlay_logged:
				_log_timing("loading_overlay.shown", scene_path, started_at)
				loading_overlay_logged = true
			_show_loading_overlay(progress)

		await tree.process_frame

	_log_timing("threaded_load.fallback", scene_path, started_at)
	tree.change_scene_to_file(scene_path)


func _wait_for_controls_ready(scene_path: String, started_at_ms: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	# change_scene_to_packed only queues the swap; wait one frame for it to commit.
	await tree.process_frame

	var current_scene := tree.current_scene
	if current_scene == null:
		return

	if not current_scene.has_signal("controls_ready"):
		_log_timing("controls_ready.unavailable", scene_path, started_at_ms)
		return
	if current_scene.has_method("is_controls_ready") and bool(
		current_scene.call("is_controls_ready"),
	):
		_log_timing("controls_ready.already", scene_path, started_at_ms)
		return

	var readiness := { "done": false }
	var on_controls_ready := func() -> void:
		readiness["done"] = true

	current_scene.connect("controls_ready", on_controls_ready, CONNECT_ONE_SHOT)

	var wait_started := Time.get_ticks_msec()
	while true:
		if bool(readiness["done"]):
			_log_timing("controls_ready.received", scene_path, started_at_ms)
			return

		if controls_ready_wait_timeout_ms > 0:
			var waited_ms := Time.get_ticks_msec() - wait_started
			if waited_ms >= controls_ready_wait_timeout_ms:
				_log_timing("controls_ready.timeout", scene_path, started_at_ms)
				return

		await tree.process_frame


func _show_loading_overlay(progress: Array) -> void:
	if _loading_label == null:
		return

	var dots_count := int(fposmod(float(Time.get_ticks_msec()) / 300.0, 4.0))
	var dots := ".".repeat(dots_count)
	if progress.size() > 0:
		var pct := int(clampf(float(progress[0]), 0.0, 1.0) * 100.0)
		_loading_label.text = "Loading%s %d%%" % [dots, pct]
	else:
		_loading_label.text = "Loading%s" % dots
	_loading_label.visible = true


func _hide_loading_overlay() -> void:
	if _loading_label == null:
		return
	_loading_label.visible = false


func _fade_to_alpha(target_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return

	var clamped_duration := maxf(duration, 0.0)
	if clamped_duration <= 0.0:
		_set_overlay_alpha(target_alpha)
		return

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_method(_set_overlay_alpha, _fade_rect.color.a, target_alpha, clamped_duration)
	await tween.finished


func _set_overlay_alpha(alpha: float) -> void:
	if _fade_rect == null:
		return
	var next_color := fade_color
	next_color.a = clampf(alpha, 0.0, 1.0)
	_fade_rect.color = next_color


func _log_timing(event_name: String, scene_path: String, started_at_ms: int) -> void:
	if not enable_timing_logs:
		return
	var elapsed_ms := Time.get_ticks_msec() - started_at_ms
	var boot_node := get_node_or_null("/root/GameBoot")
	var ticks_since_engine_start := 0
	if boot_node != null and boot_node.has_method("get_start_time"):
		ticks_since_engine_start = boot_node.call("get_start_time")
	print(
		"[SceneTransitionTiming] %s | scene=%s | elapsed_ms=%d | total_ms=%d" % [
			event_name,
			scene_path,
			elapsed_ms,
			ticks_since_engine_start,
		],
	)
