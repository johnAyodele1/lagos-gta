extends SceneTree

const PlayerScript = preload("res://scripts/player_controller.gd")
const MobileControlsScript = preload("res://scripts/mobile_controls.gd")
const LegalConsentScript = preload("res://scripts/legal_consent.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_normalize_move_input()
	_test_camera_pitch_clamp()
	_test_mobile_joystick()
	_test_mobile_button_state()
	_test_mobile_touch_routing()
	_test_legal_consent_versioning()
	_test_world_generation_batching()
	_test_project_scripts_load()
	if failures > 0:
		push_error("%d of %d gameplay input tests failed." % [failures, assertions])
		quit(1)
	else:
		print("All %d gameplay input tests passed." % assertions)
		quit(0)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _test_normalize_move_input() -> void:
	_check(PlayerScript.normalize_move_input(Vector2.ZERO) == Vector2.ZERO, "zero input remains zero")
	var diagonal := PlayerScript.normalize_move_input(Vector2(1.0, 1.0))
	_check(is_equal_approx(diagonal.length(), 1.0), "diagonal keyboard input is capped at unit speed")
	_check(PlayerScript.normalize_move_input(Vector2(0.0, -0.5)) == Vector2(0.0, -0.5), "partial analogue input preserves magnitude")

func _test_camera_pitch_clamp() -> void:
	_check(is_equal_approx(PlayerScript.clamp_camera_pitch(-10.0), deg_to_rad(-55.0)), "camera pitch clamps at the lower limit")
	_check(is_equal_approx(PlayerScript.clamp_camera_pitch(10.0), deg_to_rad(35.0)), "camera pitch clamps at the upper limit")
	_check(is_equal_approx(PlayerScript.clamp_camera_pitch(0.2), 0.2), "camera pitch remains unchanged inside limits")

func _test_mobile_button_state() -> void:
	var controls = MobileControlsScript.new()
	controls.jump_requested = true
	_check(controls.consume_jump_request(), "jump tap is consumed once")
	_check(not controls.consume_jump_request(), "held jump state does not repeat after consumption")
	controls.sprint_touch_index = 7
	_check(controls.is_sprint_pressed(), "sprint remains active while its touch is held")
	controls.sprint_touch_index = -1
	_check(not controls.is_sprint_pressed(), "sprint stops when its touch is released")
	controls.look_delta = Vector2(12.0, -4.0)
	_check(controls.consume_look_delta().is_equal_approx(Vector2(12.0, -4.0)), "camera consumes accumulated touch look delta")
	_check(controls.consume_look_delta() == Vector2.ZERO, "touch look delta is cleared after consumption")
	controls.free()

func _test_mobile_touch_routing() -> void:
	var controls = MobileControlsScript.new()
	root.add_child(controls)
	controls._mobile_enabled = true
	var size := controls.get_viewport_rect().size

	var joystick_center: Vector2 = controls._joystick_center()
	controls._begin_touch(11, joystick_center + Vector2.UP * controls._joystick_radius())
	_check(controls.get_move_vector().is_equal_approx(Vector2.UP), "left-side touch routes to the virtual joystick")
	controls._end_touch(11)
	_check(controls.get_move_vector() == Vector2.ZERO, "releasing joystick touch stops movement")

	controls._begin_touch(12, controls._sprint_center(size))
	_check(controls.is_sprint_pressed(), "touch at RUN button activates sprint")
	controls._end_touch(12)
	_check(not controls.is_sprint_pressed(), "releasing RUN touch stops sprint")

	controls._begin_touch(13, controls._jump_center(size))
	_check(controls.consume_jump_request(), "touch at JUMP button requests one jump")
	controls._end_touch(13)

	controls._begin_touch(14, Vector2(size.x * 0.7, size.y * 0.5))
	_check(controls.look_touch_index == 14, "right-side touch is reserved for camera look")
	controls._end_touch(14)

	controls.joystick_touch_index = 15
	controls.look_touch_index = 16
	controls.sprint_touch_index = 17
	controls.jump_touch_index = 18
	controls.look_delta = Vector2(5.0, 3.0)
	controls.jump_requested = true
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(controls.get_move_vector() == Vector2.ZERO, "app focus loss clears active joystick movement")
	_check(not controls.is_sprint_pressed(), "app focus loss releases sprint")
	_check(controls.consume_look_delta() == Vector2.ZERO, "app focus loss clears camera drag")
	_check(not controls.consume_jump_request(), "app focus loss clears pending jump")
	controls.free()

func _test_legal_consent_versioning() -> void:
	_check(not LegalConsentScript.is_current_consent(0), "first launch requires explicit legal consent")
	_check(LegalConsentScript.is_current_consent(LegalConsentScript.LEGAL_VERSION), "current legal version remains accepted")
	_check(not LegalConsentScript.is_current_consent(LegalConsentScript.LEGAL_VERSION - 1), "updated terms require renewed acceptance")
	_check(not LegalConsentScript.is_current_consent(LegalConsentScript.LEGAL_VERSION + 1), "unknown future consent versions are not silently accepted")

func _test_world_generation_batching() -> void:
	var world = WorldGeneratorScript.new()
	root.add_child(world)
	world.generate()
	var multimesh_count := 0
	var district_sign_count := 0
	for child in world.get_children():
		if child is MultiMeshInstance3D:
			multimesh_count += 1
		if child is Label3D:
			district_sign_count += 1
	_check(multimesh_count >= 4, "building windows are batched into multimesh instances")
	_check(district_sign_count >= 2, "district and danfo stop signs are generated")
	_check(world.get_node_or_null("ParkedDanfoMinibus") != null, "Yaba street includes a parked danfo minibus landmark")
	_check(world._material_cache.size() < 40, "generated geometry reuses a bounded shared material set")
	world.queue_free()

func _test_project_scripts_load() -> void:
	var world_script = ResourceLoader.load("res://scripts/world_generator.gd")
	_check(world_script is GDScript, "world generator script loads without parse errors")
	var main_script = ResourceLoader.load("res://scripts/main.gd")
	_check(main_script is GDScript, "main scene script and dependencies load without parse errors")

func _test_mobile_joystick() -> void:
	var center := Vector2(100.0, 100.0)
	_check(MobileControlsScript.joystick_vector(center, center, 60.0) == Vector2.ZERO, "joystick center produces no movement")
	_check(MobileControlsScript.joystick_vector(center, Vector2(103.0, 100.0), 60.0) == Vector2.ZERO, "joystick deadzone filters touch jitter")
	var right := MobileControlsScript.joystick_vector(center, Vector2(160.0, 100.0), 60.0)
	_check(right.is_equal_approx(Vector2.RIGHT), "full right joystick deflection produces full right input")
	var beyond_radius := MobileControlsScript.joystick_vector(center, Vector2(300.0, 100.0), 60.0)
	_check(is_equal_approx(beyond_radius.length(), 1.0), "joystick input is clamped outside its radius")
