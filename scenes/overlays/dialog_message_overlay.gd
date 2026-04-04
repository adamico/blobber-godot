extends Control

signal close_requested

@export var title_text := "Operational Briefing"
@export var body_text := ""
@export var continue_button_text := "Acknowledge"

@onready var _title_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Title")
@onready var _body_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Body")
@onready var _continue_button: Button = get_node_or_null("Center/Panel/Margin/VBox/ContinueButton")


func _ready() -> void:
	_apply_content()
	if _continue_button != null:
		_continue_button.text = continue_button_text
		_continue_button.pressed.connect(_on_continue_pressed)
		_continue_button.call_deferred("grab_focus")


func request_overlay_focus() -> void:
	if _continue_button != null:
		_continue_button.grab_focus()


func set_dialog(title: String, body: String, button_text: String = "") -> void:
	title_text = title
	body_text = body
	if not button_text.is_empty():
		continue_button_text = button_text
	_apply_content()


func _apply_content() -> void:
	if _title_label != null:
		_title_label.text = title_text
	if _body_label != null:
		_body_label.text = body_text
	if _continue_button != null:
		_continue_button.text = continue_button_text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return
	if event.is_action_pressed("ui_accept"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	close_requested.emit()
