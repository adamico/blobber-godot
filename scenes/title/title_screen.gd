extends Control

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/world/main.tscn"
@export var audio_wiring_profile: Resource

const KEY_MUSIC_MENU := &"music.menu"
const KEY_DIALOG_CONTINUE := &"ui.dialog_continue"

@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton
@onready var _reset_progress_button: Button = %ResetProgressButton

var _music_player: AudioStreamPlayer
var _ui_sfx_player: AudioStreamPlayer


func _ready() -> void:
	var scene_init_started_at := Time.get_ticks_msec()
	if _start_button != null:
		_start_button.pressed.connect(_on_start_pressed)
		_start_button.call_deferred("grab_focus")
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit_pressed)
	if _reset_progress_button != null:
		_reset_progress_button.pressed.connect(_on_reset_progress_pressed)

	_play_menu_music()
	_ensure_ui_sfx_player()
	_log_scene_init_time(scene_init_started_at)


func _exit_tree() -> void:
	if _music_player != null:
		_music_player.stop()


func _log_scene_init_time(started_at_ms: int) -> void:
	var elapsed_ms := Time.get_ticks_msec() - started_at_ms
	var boot_node := get_node_or_null("/root/GameBoot")
	var total_ms := 0
	if boot_node != null and boot_node.has_method("get_start_time"):
		total_ms = boot_node.call("get_start_time")
	var log_msg := "[BootSequence] title_screen._ready() | ticks_ms=%d | method_ms=%d"
	print(log_msg % [total_ms, elapsed_ms])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not event.is_pressed():
		return

	if event.is_action_pressed("ui_accept"):
		_start_game()


func _on_start_pressed() -> void:
	_start_game()


func _on_reset_progress_pressed() -> void:
	_play_ui_signal_key(KEY_DIALOG_CONTINUE)
	var game_boot := get_node_or_null("/root/GameBoot")
	if game_boot != null and game_boot.has_method("clear_dialog_persistence"):
		game_boot.clear_dialog_persistence()
	if _reset_progress_button != null:
		_reset_progress_button.text = "Progress Reset!"


func _on_quit_pressed() -> void:
	_play_ui_signal_key(KEY_DIALOG_CONTINUE)
	call_deferred("_quit_game")


func _start_game() -> void:
	if gameplay_scene_path.is_empty():
		return
	_play_ui_signal_key(KEY_DIALOG_CONTINUE)
	call_deferred("_change_to_gameplay_scene")


func _play_menu_music() -> void:
	if audio_wiring_profile == null:
		return
	if not audio_wiring_profile.has_method("find_by_signal_key"):
		return

	var entry: Variant = audio_wiring_profile.call("find_by_signal_key", KEY_MUSIC_MENU)
	if entry == null:
		return

	var stream := load(String(entry.stream_path)) as AudioStream
	if stream == null:
		return

	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MenuMusicPlayer"
		add_child(_music_player)

	_music_player.stop()
	_music_player.stream = stream
	_music_player.bus = String(entry.bus)
	_music_player.volume_db = float(entry.volume_db)
	_music_player.pitch_scale = 1.0
	_music_player.play()


func _ensure_ui_sfx_player() -> void:
	if _ui_sfx_player != null:
		return
	_ui_sfx_player = AudioStreamPlayer.new()
	_ui_sfx_player.name = "MenuUiSfxPlayer"
	add_child(_ui_sfx_player)


func _play_ui_signal_key(signal_key: StringName) -> void:
	if audio_wiring_profile == null:
		return
	if not audio_wiring_profile.has_method("find_by_signal_key"):
		return
	_ensure_ui_sfx_player()

	var entry: Variant = audio_wiring_profile.call("find_by_signal_key", signal_key)
	if entry == null:
		return

	var stream := load(String(entry.stream_path)) as AudioStream
	if stream == null:
		return

	_ui_sfx_player.stop()
	_ui_sfx_player.stream = stream
	_ui_sfx_player.bus = String(entry.bus)
	_ui_sfx_player.volume_db = float(entry.volume_db)
	_ui_sfx_player.pitch_scale = 1.0
	_ui_sfx_player.play()


func _change_to_gameplay_scene() -> void:
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition != null and scene_transition.has_method("change_scene_to_file"):
		scene_transition.call("change_scene_to_file", gameplay_scene_path)
		return
	get_tree().change_scene_to_file(gameplay_scene_path)


func _quit_game() -> void:
	get_tree().quit()
