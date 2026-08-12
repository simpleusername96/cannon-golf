extends SceneTree

const HUD_SCENE := preload("res://scenes/cannon_golf/cannon_golf_hud.tscn")


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	var visible_copy := ""
	for node in _all_descendants(hud):
		if node is Label or node is Button:
			visible_copy += " " + String(node.text)
		if node is Button:
			var button := node as Button
			_assert_true(
				button.custom_minimum_size.y == 0.0 or button.custom_minimum_size.y >= 40.0,
				"Routine button targets must be at least 40 pixels high: %s" % button.name
			)
	for retired_term in ["페인트", "커버리지", "% 도달", "남은 공", "남은 샷", "예측"]:
		_assert_true(not visible_copy.contains(retired_term), "HUD must not expose retired term: %s" % retired_term)
	for required_term in ["골", "고도각", "파워", "전체", "측면", "발사", "재발사", "코스 초기화", "일시정지", "설정", "코스 선택", "메인 메뉴"]:
		_assert_true(visible_copy.contains(required_term), "HUD must expose real action: %s" % required_term)
	print("Cannon Golf HUD copy and target-size contract passed.")
	quit(0)


func _all_descendants(parent: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	for child in parent.get_children():
		descendants.append(child)
		descendants.append_array(_all_descendants(child))
	return descendants


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
