extends SceneTree

const PlayerScript = preload("res://scripts/player_controller.gd")
const MobileControlsScript = preload("res://scripts/mobile_controls.gd")
const LegalConsentScript = preload("res://scripts/legal_consent.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const OSMWorldGeneratorScript = preload("res://scripts/osm_world_generator.gd")
const GraphicsProfileScript = preload("res://scripts/graphics_profile.gd")
const VehicleScript = preload("res://scripts/vehicle_controller.gd")
const TrafficManagerScript = preload("res://scripts/traffic_manager.gd")
const PedestrianManagerScript = preload("res://scripts/pedestrian_manager.gd")

var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_normalize_move_input()
	_test_camera_pitch_clamp()
	_test_mobile_joystick()
	_test_mobile_safe_area()
	_test_mobile_button_state()
	_test_mobile_touch_routing()
	_test_legal_consent_versioning()
	_test_world_generation_batching()
	_test_graphics_profiles()
	await _test_osm_world_generator()
	_test_vehicle_speed_limits()
	_test_ambient_traffic()
	_test_pedestrians()
	await _test_player_building_collision()
	await _test_traffic_collision()
	await _test_pedestrian_collision()
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


func _test_mobile_safe_area() -> void:
	var insets := MobileControlsScript.calculate_safe_insets(
		Vector2(800.0, 400.0),
		Vector2(1600.0, 800.0),
		Rect2i(80, 40, 1440, 720)
	)
	_check(insets.is_equal_approx(Vector4(40.0, 20.0, 40.0, 20.0)), "mobile controls scale iOS notch and home-indicator safe insets into viewport coordinates")
	_check(MobileControlsScript.calculate_safe_insets(Vector2(800.0, 400.0), Vector2.ZERO, Rect2i()).is_equal_approx(Vector4.ZERO), "safe-area calculation handles unavailable display dimensions")
	_check(MobileControlsScript.calculate_safe_insets(Vector2(800.0, 400.0), Vector2(1600.0, 800.0), Rect2i(0, 0, 1600, 800)).is_equal_approx(Vector4.ZERO), "full-screen Android displays retain zero safe-area inset")

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
	_check(world.get_node_or_null("ParkedDanfoMinibus") == null, "the district does not create a duplicate static danfo when the drivable vehicle is managed by the game scene")
	_check(world.get_node_or_null("ParkedKekeTricycle") != null, "Yaba market includes a parked keke tricycle landmark")
	_check(world._material_cache.size() < 40, "generated geometry reuses a bounded shared material set")
	world.queue_free()

func _test_graphics_profiles() -> void:
	var low := GraphicsProfileScript.get_profile("low")
	var balanced := GraphicsProfileScript.get_profile("balanced")
	var high := GraphicsProfileScript.get_profile("high")
	_check(not bool(low["shadows"]) and int(low["shadow_atlas_size"]) == 512, "low graphics profile protects older mobile GPUs")
	_check(bool(balanced["shadows"]) and int(balanced["shadow_splits"]) == 2, "balanced mobile profile keeps short-range directional shadows")
	_check(int(high["shadow_atlas_size"]) == 2048 and float(high["far_clip"]) == 300.0, "high profile reserves longer view distance for desktop hardware")

func _test_osm_world_generator() -> void:
	var sample := {
		"schema_version": 1,
		"roads": [
			{"id": "100", "name": "Hughes Avenue", "highway": "residential", "width_m": 6.0, "coordinates": [[-20.0, 0.0], [20.0, 0.0]]}
		],
		"buildings": [
			{"id": "200", "building": "residential", "height_m": 6.2, "outline": [[5.0, -5.0], [10.0, -5.0], [10.0, 5.0], [5.0, 5.0], [5.0, -5.0]]}
		],
		"barriers": [
			{"id": "300", "barrier": "wall", "coordinates": [[-5.0, -5.0], [-5.0, 5.0]]}
		]
	}
	var world = OSMWorldGeneratorScript.new()
	root.add_child(world)
	_check(world.generate_from_data(sample), "OSM world generator accepts the versioned Yaba data contract")
	_check(world.get_road_count() == 1, "OSM world generator retains the mapped street centre-line")
	_check(world.get_building_count() == 1, "OSM world generator retains the real building footprint")
	_check(world.get_barrier_count() == 1, "OSM world generator retains mapped compound barriers")
	_check(world.get_node_or_null("OSMRoadSurfaces") != null, "OSM roads are generated as continuous 3D road surfaces")
	_check(world.get_node_or_null("OSMBuildingFootprintsAndFacades") != null, "OSM building footprints become extruded 3D building geometry")
	_check(world.get_node_or_null("OSMBuildingCollision") != null, "OSM building geometry receives a static collision mesh")
	_check(world.get_node_or_null("OSMBarrierCollision") != null, "mapped walls and fences receive static collision geometry")
	var player = PlayerScript.new()
	root.add_child(player)
	player.global_position = Vector3(0.0, 0.5, 0.0)
	await physics_frame
	var collision = player.move_and_collide(Vector3(10.0, 0.0, 0.0))
	_check(collision != null, "player capsule collides with an OSM-derived building footprint")
	_check(player.global_position.x < 5.0, "player cannot walk through an OSM-derived building wall")
	player.queue_free()
	world.queue_free()
	await physics_frame

func _test_vehicle_speed_limits() -> void:
	_check(is_equal_approx(VehicleScript.target_speed(1.0), VehicleScript.MAX_FORWARD_SPEED), "danfo forward throttle respects maximum speed")
	_check(is_equal_approx(VehicleScript.target_speed(-1.0), -VehicleScript.MAX_REVERSE_SPEED), "danfo reverse throttle respects reverse speed limit")
	_check(is_equal_approx(VehicleScript.target_speed(0.5), VehicleScript.MAX_FORWARD_SPEED * 0.5), "partial throttle scales target speed")
	_check(is_equal_approx(VehicleScript.target_speed(1.0, true), VehicleScript.MAX_FORWARD_SPEED * 1.15), "sprint control applies a capped danfo boost")
	_check(is_equal_approx(VehicleScript.target_speed(2.0), VehicleScript.MAX_FORWARD_SPEED), "vehicle throttle clamps invalid input")
	_check(is_equal_approx(VehicleScript.acceleration_for(0.0, 10.0), VehicleScript.ACCELERATION), "danfo accelerates from rest")
	_check(is_equal_approx(VehicleScript.acceleration_for(10.0, 0.0), VehicleScript.COAST_DECELERATION), "danfo coasts down when throttle is released")
	_check(is_equal_approx(VehicleScript.acceleration_for(10.0, -5.0), VehicleScript.BRAKE_ACCELERATION), "danfo brakes before changing direction")
	_check(is_equal_approx(VehicleScript.acceleration_for(-5.0, 10.0), VehicleScript.BRAKE_ACCELERATION), "danfo brakes before switching from reverse to forward")

	var vehicle = VehicleScript.new()
	root.add_child(vehicle)
	var player = PlayerScript.new()
	root.add_child(player)
	_check(player.body_mesh.get_child_count() >= 5, "player spawns with a low-poly 3D head and articulated limbs")
	_check(player.camera_pivot != null and player.camera != null, "player character rig includes a working follow camera")
	player.velocity = Vector3(0.0, 0.0, 2.0)
	player._update_character_animation(0.1)
	_check(not is_zero_approx(player._left_leg_pivot.rotation.x), "player leg animation responds to movement")
	_check(not is_zero_approx(player._right_arm_pivot.rotation.x), "player arms counter-swing during movement")
	vehicle.position = Vector3(0.0, 0.0, 5.0)
	player.position = Vector3.ZERO
	_check(player._get_nearest_vehicle() == vehicle, "player detects a danfo within interaction range")
	vehicle.position = Vector3(0.0, 0.0, 20.0)
	_check(player._get_nearest_vehicle() == null, "player cannot enter a vehicle outside interaction range")
	vehicle.position = Vector3(0.0, 0.0, 5.0)
	vehicle.enter_vehicle(player)
	_check(vehicle.driver == player, "player becomes the active danfo driver")
	_check(not player.body_mesh.visible, "player body is hidden while seated")
	_check(not player.is_physics_processing(), "on-foot movement is disabled while driving")
	_check(player.camera_pivot.get_parent() == vehicle, "third-person camera follows the danfo")
	vehicle.exit_vehicle()
	_check(vehicle.driver == null, "danfo releases the driver on exit")
	_check(player.body_mesh.visible, "player body is restored after exiting")
	_check(player.is_physics_processing(), "on-foot movement is restored after exiting")
	_check(player.camera_pivot.get_parent() == player, "camera returns to the player after exiting")
	player.queue_free()
	vehicle.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _test_ambient_traffic() -> void:
	_check(is_equal_approx(TrafficManagerScript.advance_distance(119.0, 5.0, 1.0), 4.0), "ambient traffic wraps cleanly at the end of a road segment")
	_check(is_equal_approx(TrafficManagerScript.advance_distance(10.0, -5.0, 1.0), 10.0), "negative traffic speed cannot move a vehicle backwards")
	_check(is_equal_approx(TrafficManagerScript.advance_distance(10.0, 5.0, -1.0), 10.0), "negative frame delta cannot rewind traffic")
	_check(is_equal_approx(TrafficManagerScript.advance_distance(10.0, 5.0, 1.0, 0.0), 0.0), "invalid zero-length traffic route is handled safely")

	var traffic = TrafficManagerScript.new()
	traffic.configure_from_roads(_sample_osm_roads())
	root.add_child(traffic)
	_check(traffic.get_route_count() == 4, "ambient traffic derives two-way lanes from mapped OSM road centre-lines")
	_check(traffic.get_traffic_count() == 8, "Yaba district spawns a bounded eight-car ambient traffic pool")
	var starting_distance := traffic.get_traffic_distance(0)
	var starting_position := traffic.get_traffic_position(0)
	traffic._process(1.0)
	_check(traffic.get_traffic_distance(0) > starting_distance, "ambient traffic advances along its mapped road polyline")
	_check(traffic.get_traffic_position(0) != starting_position, "ambient traffic transforms follow the road geometry")
	_check(traffic.get_child_count() == 11, "traffic uses three shared render batches plus eight lightweight collision proxies")
	_check(traffic.get_traffic_collision_count() == 8, "every ambient traffic vehicle has a physics collision proxy")
	traffic.queue_free()


func _test_pedestrians() -> void:
	_check(is_equal_approx(PedestrianManagerScript.advance_distance(109.0, 2.0, 1.0), 1.0), "pedestrian sidewalk routes wrap without leaving their route")
	_check(is_equal_approx(PedestrianManagerScript.advance_distance(12.0, -2.0, 1.0), 12.0), "pedestrian speed is clamped to a non-negative value")
	_check(is_equal_approx(PedestrianManagerScript.advance_distance(12.0, 2.0, -1.0), 12.0), "negative frame delta cannot rewind pedestrians")

	var pedestrians = PedestrianManagerScript.new()
	pedestrians.configure_from_roads(_sample_osm_roads())
	root.add_child(pedestrians)
	_check(pedestrians.get_route_count() == 4, "pedestrian paths are offset from mapped OSM roads to follow their sidewalks")
	_check(pedestrians.get_pedestrian_count() == 4, "Yaba sidewalks spawn a bounded four-person pedestrian population")
	_check(pedestrians.get_pedestrian_collision_count() == 4, "each pedestrian has a low-cost capsule collision proxy")
	var starting_distance := pedestrians.get_pedestrian_distance(0)
	var starting_position := pedestrians.get_pedestrian_position(0)
	pedestrians._process(1.0)
	_check(pedestrians.get_pedestrian_distance(0) > starting_distance, "pedestrians walk along their mapped sidewalk routes")
	_check(pedestrians.get_pedestrian_position(0) != starting_position, "pedestrian render transforms update as they walk")
	_check(pedestrians.get_child_count() == 9, "pedestrian bodies use five shared mesh batches plus four collision proxies")
	pedestrians.queue_free()

func _sample_osm_roads() -> Array[Dictionary]:
	return [
		{"id": "sample-east-west", "name": "Hughes Avenue", "highway": "residential", "width_m": 6.0, "oneway": "no", "coordinates": [[-80.0, 0.0], [80.0, 0.0]]},
		{"id": "sample-north-south", "name": "Herbert Macaulay Way", "highway": "secondary", "width_m": 8.0, "oneway": "no", "coordinates": [[0.0, -80.0], [0.0, 80.0]]}
	]

func _test_player_building_collision() -> void:
	var world = WorldGeneratorScript.new()
	root.add_child(world)
	world.generate()
	var player = PlayerScript.new()
	root.add_child(player)
	player.global_position = Vector3(13.0, 0.5, 0.0)
	await physics_frame
	var collision = player.move_and_collide(Vector3(15.0, 0.0, 0.0))
	_check(collision != null, "player capsule collides with generated building walls")
	_check(player.global_position.x < 20.5, "player cannot move through a generated building footprint")
	player.queue_free()
	await physics_frame
	var fence_player = PlayerScript.new()
	root.add_child(fence_player)
	fence_player.global_position = Vector3(0.0, 0.5, 0.0)
	await physics_frame
	var fence_collision = fence_player.move_and_collide(Vector3(-10.0, 0.0, 0.0))
	_check(fence_collision != null, "player capsule collides with an OSM-mapped compound wall")
	fence_player.queue_free()
	world.queue_free()
	await physics_frame

func _test_traffic_collision() -> void:
	var traffic = TrafficManagerScript.new()
	traffic.configure_from_roads(_sample_osm_roads())
	root.add_child(traffic)
	var player = PlayerScript.new()
	root.add_child(player)
	var vehicle_position := traffic.get_traffic_position(0)
	var vehicle_direction := traffic.get_traffic_direction(0)
	player.global_position = Vector3(vehicle_position.x, 0.5, vehicle_position.z) - vehicle_direction * 5.0
	await physics_frame
	var collision = player.move_and_collide(vehicle_direction * 10.0)
	_check(collision != null, "player capsule collides with an ambient traffic vehicle")
	_check(player.global_position.z < 1.5, "player cannot walk through an ambient traffic vehicle")
	player.queue_free()
	traffic.queue_free()
	await physics_frame

func _test_pedestrian_collision() -> void:
	var pedestrians = PedestrianManagerScript.new()
	pedestrians.configure_from_roads(_sample_osm_roads())
	root.add_child(pedestrians)
	var player = PlayerScript.new()
	root.add_child(player)
	var pedestrian_position := pedestrians.get_pedestrian_position(0)
	var pedestrian_direction := pedestrians.get_pedestrian_direction(0)
	player.global_position = Vector3(pedestrian_position.x, 0.5, pedestrian_position.z) - pedestrian_direction * 3.0
	await physics_frame
	var collision = player.move_and_collide(pedestrian_direction * 6.0)
	_check(collision != null, "player capsule collides with a moving pedestrian")
	player.queue_free()
	pedestrians.queue_free()
	await physics_frame

func _test_project_scripts_load() -> void:
	var world_script = ResourceLoader.load("res://scripts/world_generator.gd")
	_check(world_script is GDScript, "legacy blockout world generator script loads without parse errors")
	var osm_world_script = ResourceLoader.load("res://scripts/osm_world_generator.gd")
	_check(osm_world_script is GDScript, "OSM world generator script loads without parse errors")
	var vehicle_script = ResourceLoader.load("res://scripts/vehicle_controller.gd")
	_check(vehicle_script is GDScript, "vehicle controller script loads without parse errors")
	var traffic_script = ResourceLoader.load("res://scripts/traffic_manager.gd")
	_check(traffic_script is GDScript, "ambient traffic manager script loads without parse errors")
	var pedestrian_script = ResourceLoader.load("res://scripts/pedestrian_manager.gd")
	_check(pedestrian_script is GDScript, "pedestrian manager script loads without parse errors")
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
