extends Control

signal close_requested
signal return_to_title_requested
signal quit_game_requested

const ACTION_PAUSE_MENU := &"pause_menu"
const PENDING_RETURN_TO_TITLE := &"return_to_title"
const PENDING_QUIT_GAME := &"quit_game"

@onready var _resume_button := get_node_or_null("Center/Panel/Margin/VBox/ResumeButton") as Button
@onready var _back_to_title_button := get_node_or_null(
	"Center/Panel/Margin/VBox/BackToTitleButton",
) as Button
@onready var _quit_game_button := get_node_or_null(
	"Center/Panel/Margin/VBox/QuitGameButton",
) as Button
@onready var _confirm_panel := get_node_or_null(
	"Center/Panel/Margin/VBox/ConfirmPanel",
) as PanelContainer
@onready var _confirm_title_label := get_node_or_null(
	"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmTitleLabel",
) as Label
@onready var _confirm_body_label := get_node_or_null(
	"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmBodyLabel",
) as Label
@onready var _confirm_button := get_node_or_null(
	"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtons/ConfirmButton",
) as Button
@onready var _cancel_button := get_node_or_null(
	"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtons/CancelButton",
) as Button

var _pending_action: StringName = StringName()


func _ready() -> void:
	if not _has_required_nodes():
		push_error("Pause menu overlay is missing one or more required child nodes.")
		return

	_resume_button.pressed.connect(_on_resume_pressed)
	_back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	_quit_game_button.pressed.connect(_on_quit_game_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)

	_hide_confirmation()
	call_deferred("request_overlay_focus")


func request_overlay_focus() -> void:
	if not _has_required_nodes():
		return
	if _confirm_panel.visible:
		_cancel_button.grab_focus()
		return
	_resume_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return
	if not event.is_action_pressed(ACTION_PAUSE_MENU) and not event.is_action_pressed(&"ui_cancel"):
		return

	if _confirm_panel.visible:
		_hide_confirmation()
	else:
		close_requested.emit()

	get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	close_requested.emit()


func _on_back_to_title_pressed() -> void:
	_show_confirmation(
		PENDING_RETURN_TO_TITLE,
		"Back to title?",
		"Leave the current run and return to the title screen?",
		"Back to Title",
	)


func _on_quit_game_pressed() -> void:
	_show_confirmation(
		PENDING_QUIT_GAME,
		"Quit game?",
		"Close the game application now?",
		"Quit Game",
	)


func _on_confirm_pressed() -> void:
	match _pending_action:
		PENDING_RETURN_TO_TITLE:
			return_to_title_requested.emit()
		PENDING_QUIT_GAME:
			quit_game_requested.emit()


func _on_cancel_pressed() -> void:
	_hide_confirmation()


func _show_confirmation(
		pending_action: StringName,
		title_text: String,
		body_text: String,
		confirm_text: String,
) -> void:
	if not _has_required_nodes():
		return
	_pending_action = pending_action
	_confirm_title_label.text = title_text
	_confirm_body_label.text = body_text
	_confirm_button.text = confirm_text
	_confirm_panel.visible = true
	_set_menu_buttons_disabled(true)
	_cancel_button.grab_focus()


func _hide_confirmation() -> void:
	if not _has_required_nodes():
		return
	_pending_action = StringName()
	_confirm_panel.visible = false
	_set_menu_buttons_disabled(false)

	if is_node_ready():
		_resume_button.grab_focus()


func _set_menu_buttons_disabled(disabled: bool) -> void:
	if not _has_required_nodes():
		return
	_resume_button.disabled = disabled
	_back_to_title_button.disabled = disabled
	_quit_game_button.disabled = disabled


func _has_required_nodes() -> bool:
	return (
		_resume_button != null
		and _back_to_title_button != null
		and _quit_game_button != null
		and _confirm_panel != null
		and _confirm_title_label != null
		and _confirm_body_label != null
		and _confirm_button != null
		and _cancel_button != null
	)
