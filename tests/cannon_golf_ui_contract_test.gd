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
	_assert(hud.get_node_or_null("Root/BottomRail") is Control, "Normal play needs one transparent bottom rail.")
	_assert(hud.get_node_or_null("Root/BottomRail/AimPanel") is HBoxContainer, "The rail must own horizontal and elevation groups.")
	_assert(hud.get_node_or_null("Root/BottomRail/ShotPanel") is HBoxContainer, "The rail must own power and Fire.")
	_assert(hud.get_node_or_null("Root/TopActions") is Control, "Normal play needs one surface-free top action row.")
	_assert(hud.get_node_or_null("Root/GoalProgress") is Control, "Normal play needs one surface-free goal tally.")
	_assert(hud.get_node_or_null("Root/LauncherSource") is Control, "Normal play needs one surface-free cannon-source selector.")
	for path in ["Root/BottomRail", "Root/TopActions", "Root/GoalProgress", "Root/LauncherSource"]:
		_assert(not (hud.get_node(path) is PanelContainer), "Persistent normal-play chrome must not use a panel surface: %s." % path)
	_assert((hud.get_node("Root/LauncherSource") as Control).visible, "Every level must show the cannon-position selector.")
	var launcher_source_rect := (hud.get_node("Root/LauncherSource") as Control).get_global_rect()
	_assert(launcher_source_rect.end.y <= 72.0 and absf(launcher_source_rect.get_center().x - 640.0) <= 1.0,
			"The cannon-position selector must remain centered in the top band.")
	_assert((hud.get_node("%LauncherSourcePrevious") as Button).disabled \
			and (hud.get_node("%LauncherSourceNext") as Button).disabled,
		"A level with only Start must show two disabled source arrows."
	)
	_assert(_find_named(hud, "SeparatorOne") == null and _find_named(hud, "SeparatorTwo") == null, "Aim groups must use spacing instead of divider lines.")
	_assert(hud.get_node_or_null("Root/ShortcutPanel") is PanelContainer, "Normal play needs on-demand shortcut help.")
	_assert(not hud.is_shortcut_panel_visible(), "Shortcut help must be collapsed by default.")
	for retired_node in [
		"CoursePanel", "CourseNavigation", "FeedbackPanel", "TopLeftSpacer",
		"TopRightSpacer", "BottomLeftSpacer", "BottomRightSpacer",
		"ViewPanel", "ResetButton", "ResultBody",
	]:
		_assert(_find_named(hud, retired_node) == null, "Retired HUD owner must be absent: %s." % retired_node)

	var normal_controls: Array[Control] = [
		hud.get_node("%LauncherSourcePrevious"),
		hud.get_node("%LauncherSourceNext"),
		hud.get_node("%ObliqueButton"),
		hud.get_node("%CannonButton"),
		hud.get_node("%RetryButton"),
		hud.get_node("%ShortcutButton"),
		hud.get_node("%PauseButton"),
		hud.get_node("%HorizontalDecrease"),
		hud.get_node("%HorizontalSlider"),
		hud.get_node("%HorizontalIncrease"),
		hud.get_node("%ElevationDecrease"),
		hud.get_node("%ElevationSlider"),
		hud.get_node("%ElevationIncrease"),
		hud.get_node("%PowerDecrease"),
		hud.get_node("%PowerSlider"),
		hud.get_node("%PowerIncrease"),
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
		"HorizontalDecrease", "HorizontalIncrease", "ElevationDecrease",
		"ElevationIncrease", "PowerDecrease", "PowerIncrease", "ZoomInButton",
		"CameraResetButton", "ZoomOutButton", "ShortcutButton", "ObliqueButton",
		"CannonButton", "FollowButton", "RetryButton", "PauseButton",
		"LauncherSourcePrevious", "LauncherSourceNext",
	]:
		var button := hud.get_node("%%%s" % button_name) as Button
		_assert(not button.tooltip_text.is_empty(), "Icon action needs a tooltip: %s." % button_name)
		_assert(not String(button.get("accessibility_name")).is_empty(), "Icon action needs an accessible name: %s." % button_name)

	var center_seventy := Rect2(Vector2(192.0, 108.0), Vector2(896.0, 504.0))
	_assert(not (hud.get_node("Root/BottomRail") as Control).get_global_rect().intersects(center_seventy), "The bottom rail must not occupy the center 70%.")
	_assert(not (hud.get_node("Root/TopActions") as Control).get_global_rect().intersects(center_seventy), "Top action strip must not occupy the center 70%.")
	for control_name in [
		"HorizontalValue", "HorizontalDecrease", "HorizontalSlider", "HorizontalIncrease",
		"ElevationValue", "ElevationDecrease", "ElevationSlider", "ElevationIncrease",
	]:
		_assert(
			(hud.get_node("Root/BottomRail/AimPanel") as Control).get_global_rect().encloses(
				(hud.get_node("%%%s" % control_name) as Control).get_global_rect()
			),
			"Aim panel must enclose the complete control: %s." % control_name
		)
	for control_name in ["PowerValue", "PowerDecrease", "PowerSlider", "PowerIncrease", "FireButton"]:
		_assert(
			(hud.get_node("Root/BottomRail/ShotPanel") as Control).get_global_rect().encloses(
				(hud.get_node("%%%s" % control_name) as Control).get_global_rect()
			),
			"Power/fire dock must enclose the complete control: %s." % control_name
		)
	var normal_primary_count := 0
	for node in _all_descendants(hud):
		if node is Button and node.is_visible_in_tree() \
				and (node as Button).theme_type_variation in [&"AmberCircleButton", &"HudFireButton"]:
			normal_primary_count += 1
	_assert(normal_primary_count == 1, "Fire must be the only normal-play primary action.")
	hud.set_view(&"cannon")
	hud.set_launch_availability(1, false)
	await process_frame
	var fire_button := hud.get_node("%FireButton") as Button
	var action_dock := hud.get_node("Root/BottomRail/ShotPanel") as Control
	_assert(
		fire_button.size.x >= 120.0 and fire_button.size.y >= 44.0 \
				and fire_button.size.x > fire_button.size.y \
				and action_dock.get_global_rect().encloses(fire_button.get_global_rect()),
		"Selected cannon view must not squeeze or clip Fire; fire %s, dock %s." % [
			fire_button.get_global_rect(), action_dock.get_global_rect(),
		]
	)
	_assert(not String(fire_button.get("accessibility_name")).is_empty(), "Fire needs an accessible name.")
	_assert(not fire_button.disabled, "Shot two must remain available while one ball is live.")
	_assert(not (hud.get_node("%FollowButton") as Button).disabled, "A live ball must enable the follow action.")
	for slider_name in ["HorizontalSlider", "ElevationSlider", "PowerSlider"]:
		var slider := hud.get_node("%%%s" % slider_name) as Slider
		_assert(slider.editable, "Live flight must keep %s editable." % slider_name)
		_assert(slider.tick_count == 0, "%s must use one uninterrupted track without ticks." % slider_name)
	var top_actions := hud.get_node("Root/TopActions/Margin/Actions") as HBoxContainer
	_assert(top_actions.alignment == BoxContainer.ALIGNMENT_CENTER, "Top actions must center their complete icon group.")
	var top_action_center_y := top_actions.get_global_rect().get_center().y
	for button_name in ["ObliqueButton", "CannonButton", "RetryButton", "ShortcutButton", "PauseButton"]:
		var top_button := hud.get_node("%%%s" % button_name) as Button
		_assert(top_button.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s must center its icon." % button_name)
		_assert(absf(top_button.get_global_rect().get_center().y - top_action_center_y) < 0.5, "%s must share the top action row centerline." % button_name)
	var oblique_button := hud.get_node("%ObliqueButton") as Button
	var top_icon_hover := oblique_button.get_theme_stylebox(&"hover") as StyleBoxFlat
	var top_icon_pressed := oblique_button.get_theme_stylebox(&"pressed") as StyleBoxFlat
	_assert(top_icon_hover.bg_color.a == 0.0, "Top icon hover must not add a surrounding fill.")
	_assert(top_icon_pressed.bg_color.a == 0.0 and top_icon_pressed.border_width_bottom == 2, "Selected top icons need only a restrained baseline.")
	_assert(fire_button.theme_type_variation == &"HudFireButton", "Fire interaction styling must stay scoped to the gameplay HUD.")
	var fire_normal := fire_button.get_theme_stylebox(&"normal") as StyleBoxFlat
	var fire_hover := fire_button.get_theme_stylebox(&"hover") as StyleBoxFlat
	_assert(fire_normal.bg_color.a == 1.0 and fire_hover.bg_color.a == 1.0,
			"Fire must retain its filled primary-action surface in normal and hover states.")
	_assert(fire_normal.corner_radius_top_left <= 16,
			"Fire must use a compact rounded rectangle instead of a circular action shape.")
	hud.set_camera_mode(&"follow")
	_assert((hud.get_node("%FollowButton") as Button).button_pressed, "Follow mode needs a selected state beyond color.")
	_assert(
		(hud.get_node("%FollowButton") as Button).tooltip_text.contains("돌아가기"),
		"Follow mode must describe the action that returns to planning."
	)
	hud.set_camera_mode(&"planning")
	_assert(
		not (hud.get_node("%FollowButton") as Button).tooltip_text.contains("Tab"),
		"Planning mode must not claim that Tab enters Shot Follow."
	)
	hud.set_launch_availability(20, false)
	_assert(not fire_button.disabled, "Live-ball count must never disable Fire.")

	hud.set_goal_progress(1, 2)
	hud.set_launcher_sources([1], -1)
	var source_previous := hud.get_node("%LauncherSourcePrevious") as Button
	var source_next := hud.get_node("%LauncherSourceNext") as Button
	_assert(source_previous.disabled and not source_next.disabled,
		"Start must disable Previous and enable Next when one completed goal is available."
	)
	_assert((hud.get_node("%LauncherSourceName") as Label).text == "시작점" \
			and (hud.get_node("%LauncherSourcePosition") as Label).text == "1 / 2",
		"The arrow selector must identify Start and its available-source position."
	)
	var requested_sources: Array[int] = []
	hud.launcher_source_requested.connect(
		func(goal_index: int) -> void: requested_sources.append(goal_index)
	)
	source_next.pressed.emit()
	_assert(
		requested_sources == [1],
		"Choosing a completed goal must emit its stable source identity."
	)
	var korean_copy := _visible_copy(hud)
	for required in ["좌우", "상하", "파워", "발사", "골 1 / 2", "시작점", "1 / 2"]:
		_assert(korean_copy.contains(required), "Normal Korean HUD must expose %s." % required)
	hud.set_shortcut_panel_visible(true)
	await process_frame
	var korean_shortcut_copy := _visible_copy(hud.get_node("%ShortcutPanel"))
	for required in [
		"Q / E", "Space", "Tab", "조준으로 복귀", "Shift + R", "좌 드래그",
		"우 / Shift+좌", "화면 이동", "화면 회전", "휠", "방향키", "Esc",
	]:
		_assert(korean_shortcut_copy.contains(required), "Korean shortcut help must expose %s." % required)
	hud.set_shortcut_panel_visible(false)
	hud.apply_language("en")
	await process_frame
	var english_copy := _visible_copy(hud)
	for required in ["H", "V", "PWR", "FIRE", "GOALS 1 / 2", "START", "1 / 2"]:
		_assert(english_copy.contains(required), "Normal English HUD must expose %s." % required)
	for label_name in ["HorizontalLabel", "ElevationLabel", "PowerLabel", "HorizontalValue", "ElevationValue", "PowerValue"]:
		var label := hud.get_node("%%%s" % label_name) as Label
		_assert(label.get_minimum_size().x <= label.size.x + 0.5, "HUD label must fit without clipping: %s." % label_name)
	_assert_hud_edge_fit(hud, Vector2(1280.0, 720.0), "1280x720")
	hud.set_shortcut_panel_visible(true)
	await process_frame
	_assert(hud.is_shortcut_panel_visible(), "Shortcut help must open on request.")
	_assert((hud.get_node("%ShortcutCloseButton") as Button).has_focus(), "Shortcut help must move focus to its close action.")
	var shortcut_copy := _visible_copy(hud.get_node("%ShortcutPanel"))
	for required in [
		"Q / E", "Space", "Tab", "Return to aim", "Shift + R", "L Drag",
		"R / Shift+L", "Move view", "Orbit view", "Wheel", "Arrows", "Esc",
	]:
		_assert(shortcut_copy.contains(required), "English shortcut help must expose %s." % required)
	_assert_hud_edge_fit(hud, Vector2(1280.0, 720.0), "1280x720 shortcut-open")
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	_assert_hud_edge_fit(hud, Vector2(1600.0, 900.0), "1600x900")
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	_assert_hud_edge_fit(hud, Vector2(1920.0, 1080.0), "1920x1080")

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
	var brand_panel := main_menu.get_node("BrandPanel") as PanelContainer
	var menu_title := main_menu.get_node("BrandPanel/Margin/Content/Title") as Label
	_assert(is_equal_approx(brand_panel.size.x, 356.0), "Main-menu panel must retain its compact width.")
	_assert(menu_title.text == "CANNON\nGOLF", "Main-menu title must use the compact two-line lockup.")
	_assert(menu_title.get_theme_font_size(&"font_size") == 60, "Main-menu title must retain the compact type size.")
	_assert(is_equal_approx((main_menu.get_node("%Play") as Button).size.x, 288.0), "Main-menu actions must retain their compact width.")
	for required in ["Back", "Start"]:
		_assert(_find_named(course_select, required) is Button, "Course select must retain %s." % required)
	var course_start := course_select.get_node("%Start") as Button
	_assert(course_start.theme_type_variation == &"CourseStartButton" \
			and course_start.custom_minimum_size.y >= 44.0 \
			and not is_equal_approx(course_start.custom_minimum_size.x, course_start.custom_minimum_size.y),
			"Course Start must retain its approved directional action shape.")
	_assert(
		course_select.course_buttons().size() == 15,
		"Course select must create fifteen reusable catalog rows."
	)
	_assert(course_select.get_node_or_null("CardsPanel") == null, "The course list must not be wrapped in a card panel.")
	_assert(course_select.get_node_or_null("Scroll/CourseList") is VBoxContainer, "Course rows need one direct scroll owner.")
	var course_scroll := course_select.get_node("Scroll") as ScrollContainer
	_assert(
		course_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER \
				and course_select.get_node_or_null("ListGuide") is ColorRect,
		"The course list must use the approved left guide without a right-edge scrollbar."
	)
	for index in range(course_select.course_buttons().size()):
		var course_button := course_select.course_buttons()[index]
		_assert(course_button.custom_minimum_size.y >= 44.0, "Course buttons need a stable keyboard target.")
		_assert(
			course_button.get_theme_color(&"font_color").a >= 0.9 \
					and course_button.get_theme_font_size(&"font_size") >= 16,
			"Course-row text must remain visibly sized and opaque."
		)
		_assert(not String(course_button.get("accessibility_name")).is_empty(), "Course buttons need accessible names.")
		_assert(
			not course_button.text.contains("난이도") \
					and not course_button.text.contains("DIFFICULTY"),
			"Course rows must not repeat the level number as difficulty."
		)
		var expected_next: Control = course_select.get_node("%Start") \
				if index == course_select.course_buttons().size() - 1 \
				else course_select.course_buttons()[index + 1]
		_assert(
			course_button.focus_next == expected_next.get_path(),
			"Catalog buttons must retain explicit forward focus order."
		)
	_assert(course_select.select_course(1), "A non-default course row must be selectable.")
	await process_frame
	var pressed_rows := 0
	for course_button in course_select.course_buttons():
		if course_button.button_pressed:
			pressed_rows += 1
	_assert(pressed_rows == 1, "Only one course row may appear selected.")
	_assert(course_select.course_buttons()[1].has_focus(), "Selected course row must own keyboard focus.")
	var normal_style := course_select.course_buttons()[1].get_theme_stylebox(&"normal")
	var selected_style := course_select.course_buttons()[1].get_theme_stylebox(&"pressed") as StyleBoxFlat
	var focus_style := course_select.course_buttons()[1].get_theme_stylebox(&"focus") as StyleBoxFlat
	_assert(normal_style is StyleBoxEmpty, "Unselected course rows must remain flat without card surfaces.")
	_assert(selected_style != null and selected_style.border_width_left >= 4,
		"Selected course rows must retain a visible amber edge state without a filled card.")
	_assert(focus_style != null and focus_style.border_width_left >= 2,
		"Course-row keyboard focus must remain visible.")
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
	var paths := [
		"Root/GoalProgress", "Root/LauncherSource", "Root/BottomRail", "Root/TopActions",
	]
	if hud.is_shortcut_panel_visible():
		paths.append("Root/ShortcutPanel")
	for path in paths:
		var control := hud.get_node(path) as Control
		_assert(
			viewport_rect.encloses(control.get_global_rect()),
			"HUD edge control must remain inside %s: %s at %s." % [label, path, control.get_global_rect()]
		)
	_assert(
		not (hud.get_node("Root/BottomRail/AimPanel") as Control).get_global_rect().intersects(
			(hud.get_node("Root/BottomRail/ShotPanel") as Control).get_global_rect()
		),
		"Aim and shot groups must not overlap inside the bottom rail at %s." % label
	)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
