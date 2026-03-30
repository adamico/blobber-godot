extends Control

signal restart_requested
signal return_to_title_requested

@onready var _grade_label: Label = get_node_or_null("Center/Panel/Margin/VBox/GradeLabel")
@onready var _percent_label: Label = get_node_or_null("Center/Panel/Margin/VBox/PercentLabel")
@onready var _flavor_label: Label = get_node_or_null("Center/Panel/Margin/VBox/FlavorLabel")
@onready var _restart_button: Button = get_node_or_null("Center/Panel/Margin/VBox/RestartButton")
@onready var _menu_button: Button = get_node_or_null("Center/Panel/Margin/VBox/MenuButton")

const GRADE_COLORS := {
	"A": Color(0.2, 1.0, 0.4),
	"B": Color(0.6, 0.9, 0.2),
	"C": Color(1.0, 0.8, 0.2),
	"D": Color(1.0, 0.4, 0.3),
}


func _ready() -> void:
	if _restart_button != null:
		_restart_button.pressed.connect(_on_restart_pressed)
		_restart_button.call_deferred("grab_focus")
	if _menu_button != null:
		_menu_button.pressed.connect(_on_menu_pressed)


## Call this after opening the overlay to populate it with floor results.
func configure_result(clean_percent: int) -> void:
	var grade := JobRating.grade_for_percent(clean_percent)
	var label := JobRating.grade_label(grade)
	var flavor := JobRating.flavor_text(grade)

	if _grade_label != null:
		_grade_label.text = label
		var col: Color = GRADE_COLORS.get(label, Color.WHITE)
		_grade_label.add_theme_color_override("font_color", col)

	if _percent_label != null:
		_percent_label.text = "%d%% CLEAN" % clean_percent

	if _flavor_label != null:
		_flavor_label.text = flavor


func request_overlay_focus() -> void:
	if _restart_button != null:
		_restart_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return
	if event.is_action_pressed("ui_accept"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_menu_pressed() -> void:
	return_to_title_requested.emit()
