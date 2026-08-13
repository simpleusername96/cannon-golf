extends SceneTree

const HUD_SCENE := preload("res://scenes/cannon_golf/cannon_golf_hud.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_main_menu.tscn")
const COURSE_SELECT_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_course_select.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var hud := HUD_SCENE.instantiate() as CannonGolfHUD
	root.add_child(hud)
	await process_frame
	await process_frame
	_assert(hud.get_node_or_null("Root/AimPanel") is PanelContainer, "Normal play needs one compact aim panel.")
	_assert(hud.get_node_or_null("Root/ActionDock") is PanelContainer, "Normal play needs one compact action dock.")
	_assert(hud.get_node_or_null("Root/CameraDock") is PanelContainer, "Normal play needs one compact camera dock.")
	for retired_node in [
		"CoursePanel", "CourseNavigation", "FeedbackPanel", "ShortcutPanel",
		"ViewPanel", "ResetButton", "ResultBody",
	]:
		_assert(_find_named(hud, retired_node) == null, "Retired HUD owner must be absent: %s." % retired_node)

	var normal_controls: Array[Control] = [
		hud.get_node("%HorizontalSlider"),
		hud.get_node("%ElevationSlider"),
		hud.get_node("%PowerSlider"),
		hud.get_node("%ZoomInButton"),
		hud.get_node("%CameraResetButton"),
		hud.get_node("%ZoomOutButton"),
		hud.get_node("%ObliqueButton"),
		hud.get_node("%SideButton"),
		hud.get_node("%FollowButton"),
		hud.get_node("%RetryButton"),
		hud.get_node("%PauseButton"),
		hud.get_node("%FireButton"),
	]
	for control in normal_controls:
		_assert(control.custom_minimum_size.y >= 40.0, "Routine target must be at least 40 pixels high: %s." % control.name)
		_assert(control.focus_mode != Control.FOCUS_NONE, "Normal control must remain keyboard-focusable: %s." % control.name)
	for index in range(normal_controls.size()):
		_assert(
			normal_controls[index].focus_next == normal_controls[(index + 1) % normal_controls.size()].get_path(),
			"Normal controls must expose an explicit task-order focus chain: %s." % normal_controls[index].name
		)
	for button_name in [
		"ZoomInButton", "CameraResetButton", "ZoomOutButton", "ObliqueButton",
		"SideButton", "FollowButton", "RetryButton", "PauseButton",
	]:
		var button := hud.get_node("%%%s" % button_name) as Button
		_assert(not button.tooltip_text.is_empty(), "Icon action needs a tooltip: %s." % button_name)
		_assert(not String(button.get("accessibility_name")).is_empty(), "Icon action needs an accessible name: %s." % button_name)

	var center_seventy := Rect2(Vector2(192.0, 108.0), Vector2(896.0, 504.0))
	_assert(not (hud.get_node("Root/AimPanel") as Control).get_global_rect().intersects(center_seventy), "Aim panel must not occupy the center 70%.")
	_assert(not (hud.get_node("Root/ActionDock") as Control).get_global_rect().intersects(center_seventy), "Action dock must not occupy the center 70%.")
	_assert(not (hud.get_node("Root/CameraDock") as Control).get_global_rect().intersects(center_seventy), "Camera dock must not occupy the center 70%.")
	_assert(
		(hud.get_node("Root/AimPanel") as Control).get_global_rect().encloses(
			(hud.get_node("%PowerValue") as Control).get_global_rect()
		),
		"Aim panel must enclose the complete power value."
	)
	var normal_primary_count := 0
	for node in _all_descendants(hud):
		if node is Button and node.is_visible_in_tree() \
				and (node as Button).theme_type_variation == &"PrimaryButton":
			normal_primary_count += 1
	_assert(normal_primary_count == 1, "Fire must be the only normal-play primary action.")
	hud.set_view(&"side")
	hud.set_launch_availability(1, 2, false)
	await process_frame
	var fire_button := hud.get_node("%FireButton") as Button
	var action_dock := hud.get_node("Root/ActionDock") as Control
	_assert(
		fire_button.size.x >= 112.0 and action_dock.get_global_rect().encloses(fire_button.get_global_rect()),
		"Selected side view must not squeeze or clip Fire; fire %s, dock %s." % [
			fire_button.get_global_rect(), action_dock.get_global_rect(),
		]
	)
	_assert(not String(fire_button.get("accessibility_name")).is_empty(), "Fire needs an accessible name.")
	_assert(not fire_button.disabled, "Shot two must remain available while one ball is live.")
	_assert(not (hud.get_node("%FollowButton") as Button).disabled, "A live ball must enable the follow action.")
	for slider_name in ["HorizontalSlider", "ElevationSlider", "PowerSlider"]:
		_assert((hud.get_node("%%%s" % slider_name) as Slider).editable, "Live flight must keep %s editable." % slider_name)
	hud.set_camera_mode(&"follow")
	_assert((hud.get_node("%FollowButton") as Button).button_pressed, "Follow mode needs a selected state beyond color.")
	_assert(
		(hud.get_node("%FollowButton") as Button).tooltip_text.contains("돌아가기"),
		"Follow mode must describe the action that returns to planning."
	)
	hud.set_launch_availability(2, 2, false)
	_assert(fire_button.disabled, "Two live balls must visibly disable Fire at capacity.")

	var korean_copy := _visible_copy(hud)
	for required in ["좌우", "상하", "파워", "발사"]:
		_assert(korean_copy.contains(required), "Normal Korean HUD must expose %s." % required)
	hud.apply_language("en")
	await process_frame
	var english_copy := _visible_copy(hud)
	for required in ["H", "V", "PWR", "FIRE"]:
		_assert(english_copy.contains(required), "Normal English HUD must expose %s." % required)
	for label_name in ["HorizontalLabel", "ElevationLabel", "PowerLabel", "HorizontalValue", "ElevationValue", "PowerValue"]:
		var label := hud.get_node("%%%s" % label_name) as Label
		_assert(label.get_minimum_size().x <= label.size.x + 0.5, "HUD label must fit without clipping: %s." % label_name)
	_assert_hud_edge_fit(hud, Vector2(1280.0, 720.0), "1280x720")
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	_assert_hud_edge_fit(hud, Vector2(1600.0, 900.0), "1600x900")

	var main_menu := MAIN_MENU_SCENE.instantiate() as CannonGolfMainMenu
	root.add_child(main_menu)
	var course_select := COURSE_SELECT_SCENE.instantiate() as CannonGolfCourseSelect
	root.add_child(course_select)
	await process_frame
	for removed in ["Eyebrow", "Subtitle", "CourseHint"]:
		_assert(_find_named(main_menu, removed) == null, "Main-menu filler must be absent: %s." % removed)
	for removed in ["SelectionHint", "PreviewCaption", "PreviewTitle", "PreviewBrief", "PreviewFacts", "CourseOneHint", "CourseTwoHint"]:
		_assert(_find_named(course_select, removed) == null, "Course-select filler must be absent: %s." % removed)
	for required in ["Play", "CourseSelect", "Settings", "Quit"]:
		_assert(_find_named(main_menu, required) is Button, "Main menu must retain %s." % required)
	for required in ["Back", "CourseOne", "CourseTwo", "Start"]:
		_assert(_find_named(course_select, required) is Button, "Course select must retain %s." % required)
	quit(1 if _failed else 0)


func _visible_copy(parent: Node) -> String:
	var copy := ""
	for node in _all_descendants(parent):
		if node.is_visible_in_tree() and (node is Label or node is Button):
			copy += " " + String(node.text)
	return copy


func _find_named(parent: Node, wanted_name: String) -> Node:
	for node in _all_descendants(parent):
		if node.name == wanted_name:
			return node
	return null


func _all_descendants(parent: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	for child in parent.get_children():
		descendants.append(child)
		descendants.append_array(_all_descendants(child))
	return descendants


func _assert_hud_edge_fit(hud: CannonGolfHUD, viewport_size: Vector2, label: String) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	for path in ["Root/AimPanel", "Root/ActionDock", "Root/CameraDock"]:
		var control := hud.get_node(path) as Control
		_assert(
			viewport_rect.encloses(control.get_global_rect()),
			"HUD edge control must remain inside %s: %s at %s." % [label, path, control.get_global_rect()]
		)
	_assert(
		not (hud.get_node("Root/AimPanel") as Control).get_global_rect().intersects(
			(hud.get_node("Root/ActionDock") as Control).get_global_rect()
		),
		"Aim and action docks must not overlap at %s." % label
	)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
