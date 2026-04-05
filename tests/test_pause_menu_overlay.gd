extends GutTest

const PAUSE_MENU_SCENE := preload("res://scenes/overlays/pause_menu_overlay.tscn")


func test_pause_menu_has_expected_primary_buttons() -> void:
	var pause_menu := PAUSE_MENU_SCENE.instantiate() as Control
	add_child_autofree(pause_menu)
	await get_tree().process_frame

	var resume_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/ResumeButton"
	) as Button
	var back_to_title_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/BackToTitleButton"
	) as Button
	var quit_game_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/QuitGameButton"
	) as Button
	var confirm_panel := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/ConfirmPanel"
	) as PanelContainer

	assert_not_null(resume_button)
	assert_not_null(back_to_title_button)
	assert_not_null(quit_game_button)
	assert_not_null(confirm_panel)
	assert_false(confirm_panel.visible)


func test_back_to_title_requires_confirmation() -> void:
	var pause_menu := PAUSE_MENU_SCENE.instantiate() as Control
	add_child_autofree(pause_menu)
	await get_tree().process_frame

	var back_to_title_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/BackToTitleButton"
	) as Button
	var confirm_panel := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/ConfirmPanel"
	) as PanelContainer
	var confirm_title := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmTitleLabel"
	) as Label
	var confirm_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/"
		+ "ConfirmButtons/ConfirmButton"
	) as Button

	back_to_title_button.pressed.emit()

	assert_true(confirm_panel.visible)
	assert_eq(confirm_title.text, "Back to title?")
	assert_eq(confirm_button.text, "Back to Title")


func test_confirming_back_to_title_emits_signal() -> void:
	var pause_menu := PAUSE_MENU_SCENE.instantiate() as Control
	add_child_autofree(pause_menu)
	await get_tree().process_frame

	var emitted := {"value": false}
	pause_menu.return_to_title_requested.connect(func() -> void:
		emitted["value"] = true
	)

	var back_to_title_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/BackToTitleButton"
	) as Button
	var confirm_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/"
		+ "ConfirmButtons/ConfirmButton"
	) as Button

	back_to_title_button.pressed.emit()
	confirm_button.pressed.emit()

	assert_true(emitted["value"])


func test_confirming_quit_game_emits_signal() -> void:
	var pause_menu := PAUSE_MENU_SCENE.instantiate() as Control
	add_child_autofree(pause_menu)
	await get_tree().process_frame

	var emitted := {"value": false}
	pause_menu.quit_game_requested.connect(func() -> void:
		emitted["value"] = true
	)

	var quit_game_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/QuitGameButton"
	) as Button
	var confirm_button := pause_menu.get_node_or_null(
		"Center/Panel/Margin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/"
		+ "ConfirmButtons/ConfirmButton"
	) as Button

	quit_game_button.pressed.emit()
	confirm_button.pressed.emit()

	assert_true(emitted["value"])