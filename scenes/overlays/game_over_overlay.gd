extends Control

signal restart_requested
signal return_to_title_requested

@export var result_title := "Victory"
@export var result_subtitle := "Run complete."
@export var restart_button_text := "Play Again"
@export var menu_button_text := "Return To Title"
@export var stats_heading_text := "Run Summary"
@export var rating_label_text := "Job Rating"
@export var progress_label_text := "Cleaned"
@export var remaining_label_text := "Remaining"
@export var enter_anim_duration := 0.2
@export var exit_anim_duration := 0.16

@onready var _dimmer: ColorRect = get_node_or_null("Dimmer")
@onready var _panel: PanelContainer = get_node_or_null("Center/Panel")
@onready var _title_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Title")
@onready var _subtitle_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Subtitle")
@onready var _stats_heading_label: Label = get_node_or_null("Center/Panel/Margin/VBox/StatsHeading")
@onready var _rating_label: Label = get_node_or_null(
	"Center/Panel/Margin/VBox/StatsGrid/RatingLabel"
)
@onready var _rating_value_label: Label = get_node_or_null(
	"Center/Panel/Margin/VBox/StatsGrid/RatingValue"
)
@onready var _progress_label: Label = get_node_or_null(
	"Center/Panel/Margin/VBox/StatsGrid/ProgressLabel"
)
@onready var _progress_value_label: Label = get_node_or_null(
	"Center/Panel/Margin/VBox/StatsGrid/ProgressValue"
)
@onready var _remaining_label: Label = get_node_or_null(
	"Center/Panel/Margin/VBox/StatsGrid/RemainingLabel"
)
@onready var _remaining_value_label: Label = get_node_or_null(
	"Center/Panel/Margin/VBox/StatsGrid/RemainingValue"
)
@onready var _restart_button: Button = get_node_or_null("Center/Panel/Margin/VBox/RestartButton")
@onready var _menu_button: Button = get_node_or_null("Center/Panel/Margin/VBox/MenuButton")

var _transition := OverlayTransitionController.new()


func _ready() -> void:
	if _title_label != null:
		_title_label.text = result_title
	if _subtitle_label != null:
		_subtitle_label.text = result_subtitle
	if _stats_heading_label != null:
		_stats_heading_label.text = stats_heading_text
	if _rating_label != null:
		_rating_label.text = rating_label_text
	if _progress_label != null:
		_progress_label.text = progress_label_text
	if _remaining_label != null:
		_remaining_label.text = remaining_label_text
	if _restart_button != null:
		_restart_button.text = restart_button_text
		_restart_button.pressed.connect(_on_restart_pressed)
		_restart_button.call_deferred("grab_focus")
	if _menu_button != null:
		_menu_button.text = menu_button_text
		_menu_button.pressed.connect(_on_menu_pressed)

	# Provide deterministic defaults before run data is injected.
	configure_summary(0, 0, 0)

	# Wait one frame so container-driven layout is finalized before capturing base panel position.
	call_deferred("_start_enter_transition")


func configure_summary(clean_percent: int, cleaned: int, total: int) -> void:
	var grade := JobRating.grade_label(JobRating.grade_for_percent(clean_percent))
	if _rating_value_label != null:
		_rating_value_label.text = "%s (%d%%)" % [grade, clean_percent]

	if _progress_value_label != null:
		_progress_value_label.text = "%d / %d" % [cleaned, total]

	if _remaining_value_label != null:
		var remaining := maxi(total - cleaned, 0)
		_remaining_value_label.text = str(remaining)


func request_overlay_focus() -> void:
	if _restart_button != null:
		_restart_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if _transition.is_closing():
		return

	if not event.is_pressed():
		return

	if event.is_action_pressed("ui_accept"):
		_request_restart()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_request_return_to_title()
		get_viewport().set_input_as_handled()


func _on_restart_pressed() -> void:
	_request_restart()


func _on_menu_pressed() -> void:
	_request_return_to_title()


func _request_restart() -> void:
	if _transition.is_closing():
		return
	_transition.request_close(_emit_restart_requested, exit_anim_duration)


func _request_return_to_title() -> void:
	if _transition.is_closing():
		return
	_transition.request_close(_emit_return_to_title_requested, exit_anim_duration)


func _emit_restart_requested() -> void:
	restart_requested.emit()


func _emit_return_to_title_requested() -> void:
	return_to_title_requested.emit()


func _start_enter_transition() -> void:
	_transition.configure(self, _dimmer, _panel)
	_transition.play_enter(enter_anim_duration)
