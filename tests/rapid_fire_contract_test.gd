extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.time_scale = 3.0
	var game_state := root.get_node("/root/GameState") as GameState
	game_state.persistence_enabled = false
	game_state.select_stage(&"stage_01")
	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_01")
	_assert(gameplay != null, "rapid-fire contract requires the baked Stage 01 layout")
	if gameplay == null:
		Engine.time_scale = 1.0
		quit(1)
		return
	root.add_child(gameplay)
	await physics_frame
	await physics_frame
	var controller := gameplay.get_node("StageController") as StageController
	var manager := gameplay.get_node("ProjectileManager") as ProjectileManager
	var cannon := gameplay.get_node("Cannon") as CannonController
	var aim_input := gameplay.get_node("AimInputController") as AimInputController
	var agent := gameplay.get_node("GameplayAgentApi") as GameplayAgentApi
	var actions := gameplay.get_node("HUD/HUDRoot/ActionButtons") as ActionButtons
	_assert(controller.begin_aiming(), "rapid-fire contract requires an aiming board")
	var initial_readiness := controller.fire_readiness_snapshot()
	_assert(bool(initial_readiness.get("editable", false)), "beginning aim must refresh editable Fire readiness")
	_assert(
		bool(initial_readiness.get("fireable", false)) \
				and not initial_readiness.has("prediction_status"),
		"legal aim must enable Fire independently of advisory prediction"
	)
	_assert(not actions.get_node("FireButton").disabled, "HUD Fire must follow the authoritative ready snapshot")
	var agent_readiness: Dictionary = agent.get_observation().get("fire_readiness", {})
	_assert(bool(agent_readiness.get("fireable", false)), "agent observation must expose the same ready Fire contract")
	var first_aim := Vector3(
		cannon.yaw_degrees,
		cannon.elevation_degrees,
		cannon.power_percent
	)
	var first := aim_input.request_fire()
	# Slow the live physics family while the next aim is refreshed. This proves
	# that the second root uses a changed tuple instead of steering family one.
	Engine.time_scale = 0.25
	var changed := controller.set_aim(
		first_aim.x + 7.0,
		first_aim.y,
		first_aim.z,
		StageController.ActionOrigin.HUMAN
	)
	_assert(changed, "the next aim must remain editable while family one moves")
	_assert(
		bool(controller.fire_readiness_snapshot().get("fireable", false)) \
				and not actions.get_node("FireButton").disabled,
		"changed legal aim must stay fireable while its preview is pending"
	)
	var second := agent.fire()
	var third := controller.request_fire()
	_assert(first and second, "two fire commands must be accepted without waiting for settlement")
	_assert(controller.current_state == StageController.State.AIMING, "accepted Fire must keep the board in AIMING while families move")
	_assert(not third, "third fire must be rejected only at the two-family capacity")
	var capacity_snapshot := controller.fire_readiness_snapshot()
	_assert(not bool(capacity_snapshot.get("fireable", true)) and capacity_snapshot.get("reason_key", "") == "capacity", "capacity must disable only Fire with the canonical reason")
	_assert(capacity_snapshot.get("reason", "") == "초기 발사 동시 한도 2/2", "capacity copy must name the occupied initial-launch slots")
	_assert(int(capacity_snapshot.get("fire_capacity", -1)) == 0, "readiness capacity must report remaining root slots, not the fixed maximum")
	_assert(controller.shots_remaining == 2, "each accepted family must consume one payload")
	_assert(manager.active_root_count() <= 2, "active root family count must stay bounded")
	var budget := 60 * 30
	while controller.sealed_shot_observations().size() < 2 and budget > 0:
		await physics_frame
		budget -= 1
	var sealed := controller.sealed_shot_observations()
	_assert(budget > 0, "rapid-fire families must finish their first terrain traversal inside the bounded physics window")
	_assert(sealed.size() == 2, "each accepted family must seal after its first-flight bodies finish")
	_assert(controller.current_state == StageController.State.AIMING, "first-flight completion must keep the editable AIMING board")
	_assert(manager.active_count() > 0, "first-flight completion must not delete terrain residents")
	_assert(int(controller.activity_snapshot().get("fire_capacity", -1)) == 2, "all root slots must be available after both first flights finish")
	if sealed.size() == 2:
		_assert(sealed[0].shot_id == 1 and sealed[1].shot_id == 2, "sealed family observations must retain ordered shot IDs")
		_assert(not is_equal_approx(sealed[0].commanded_yaw, sealed[1].commanded_yaw), "the two sealed families must retain distinct aim tuples")
	if not _failed:
		print("rapid_fire_contract_test passed: two immediate families accepted, third rejected at capacity, and both first flights completed while residents remained active.")
	Engine.time_scale = 1.0
	gameplay.queue_free()
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
