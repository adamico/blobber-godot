extends Control

signal hidden_overlay

@export var title_text := "Message"
@export var body_text := "..."
@export var button_text := "Let's Clean"

@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var body_label: Label = $Center/Panel/Margin/VBox/Body
@onready var action_button: Button = $Center/Panel/Margin/VBox/ActionButton

func _ready() -> void:
    if title_label != null: title_label.text = title_text
    if body_label != null: body_label.text = body_text
    if action_button != null:
        action_button.text = button_text
        action_button.pressed.connect(_on_action_button_pressed)

func set_dialog(title: String, body: String, btn_text: String = "Let's Clean") -> void:
    title_text = title
    body_text = body
    button_text = btn_text
    if is_inside_tree():
        title_label.text = title_text
        body_label.text = body_text
        action_button.text = button_text

func display() -> void:
    show()
    if action_button != null:
        action_button.call_deferred("grab_focus")

func hide_overlay() -> void:
    hide()
    hidden_overlay.emit()

func _on_action_button_pressed() -> void:
    hide_overlay()
