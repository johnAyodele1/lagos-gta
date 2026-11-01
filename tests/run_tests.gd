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
const ModelBoundsScript = preload("res://scripts/model_bounds.gd")

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
	await _test_visual_meshes()
	await _test_osm_world_generator()
	await _test_vehicle_speed_limits()
	_test_ambient_traffic()
	_test_pedestrians()
	await _test_player_building_collision()
	await _test_traffic_collision()
	await _test_player_danfo_collision()
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

func _test_visual_meshes() -> void:
	if DisplayServer.get_name() != "headless":
		var bounds_probe := Node3D.new()
		var bounds_mesh := MeshInstance3D.new()
		var bounds_box := BoxMesh.new()
		bounds_box.size = Vector3(1.0, 4.0, 1.0)
		bounds_mesh.mesh = bounds_box
		bounds_probe.add_child(bounds_mesh)
		root.add_child(bounds_probe)
		await process_frame
		_check(ModelBoundsScript.fit_height(bounds_probe, 2.0), "model bounds utility accepts imported mesh geometry")
		_check(is_equal_approx(bounds_probe.scale.y, 0.5) and is_equal_approx(bounds_probe.position.y, 1.0), "model bounds utility fits a four-metre mesh to a two-metre standing height")
		bounds_probe.queue_free()
		await process_frame
	
	var player = PlayerScript.new()
	root.add_child(player)
	if DisplayServer.get_name() != "headless":
		_check(player.body_mesh.mesh != null and not player.body_mesh.visible and player.get_node_or_null("RiggedLagosPlayer") != null, "player avatar is a rigged imported 3D character with a valid hidden fallback mesh")
	_check(player.camera_pivot is SpringArm3D, "player uses a collision-aware third-person spring arm")
	_check(player.camera_yaw_pivot is Node3D and player.camera_yaw_pivot.get_parent() == player, "camera has a dedicated yaw pivot under the player")
	_check(player.camera_pivot.get_parent() == player.camera_yaw_pivot and is_zero_approx(player.camera_pivot.rotation.x), "spring-arm remains level and camera stays a direct spring-arm child")
	_check(is_equal_approx(player.camera.rotation.x, deg_to_rad(-14.0)), "third-person camera pitches down toward the street instead of looking at the sky")
	_check(player.camera.rotation.is_equal_approx(Vector3(deg_to_rad(-14.0), 0.0, 0.0)), "camera keeps its downward street-facing pitch")
	var rigged_player: Node3D
	var player_meshes: Array[Node] = []
	if player.body_mesh != null:
		rigged_player = player.get_node_or_null("RiggedLagosPlayer") as Node3D
	await process_frame
	if DisplayServer.get_name() != "headless":
		_check(rigged_player != null, "player uses the imported rigged Lagos character model")
		if rigged_player != null:
			var player_forward: Vector3 = -player.global_basis.z.normalized()
			var model_forward: Vector3 = rigged_player.global_basis.z.normalized()
			_check(model_forward.dot(player_forward) > 0.95, "imported player mesh faces the same direction as movement instead of looking back at the camera")
			var player_local_bounds: AABB = ModelBoundsScript._combined_local_bounds(rigged_player)
			_check(is_equal_approx(player_local_bounds.size.y * rigged_player.scale.y, 1.76), "player visual is normalized to 1.76m rather than scaling larger than the danfo")
			var player_animation := rigged_player.find_child("AnimationPlayer", true, false) as AnimationPlayer
			_check(player_animation != null and player_animation.has_animation("HumanArmature|Man_Walk"), "player model includes real walk animation clips")
			player_meshes = rigged_player.find_children("*", "MeshInstance3D", true, false)
			var player_materials_valid := not player_meshes.is_empty()
			for mesh_node in player_meshes:
				var mesh_instance := mesh_node as MeshInstance3D
				if mesh_instance.mesh == null:
					continue
				for surface_index in range(mesh_instance.mesh.get_surface_count()):
					if mesh_instance.get_active_material(surface_index) == null:
						player_materials_valid = false
			_check(player_materials_valid, "every imported player mesh surface has an assigned material")
	if DisplayServer.get_name() != "headless":
		var player_skin_surface_found := false
		var player_instance_override_clear := true
		for mesh_node in player_meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.material_override != null:
				player_instance_override_clear = false
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var surface_material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
				if surface_material != null and surface_material.albedo_color.is_equal_approx(Color(0.40, 0.25, 0.17)):
					player_skin_surface_found = true
		_check(player_skin_surface_found, "player rig keeps a separate skin material instead of colouring the entire character as a shirt")
		_check(player_instance_override_clear, "player does not mask its per-surface clothing and skin palette with an instance override")
	player.global_position = Vector3(10000.0, 100.0, 10000.0)
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	_check(player.camera_pivot.get_hit_length() > 6.5, "third-person spring arm reaches full distance in open space")
	player.queue_free()

	var vehicle = VehicleScript.new()
	root.add_child(vehicle)
	var danfo_model := vehicle.get_node_or_null("DanfoModel") as MeshInstance3D
	if DisplayServer.get_name() != "headless":
		_check(danfo_model != null and danfo_model.mesh != null, "danfo uses the imported detailed minibus 3D model")
	if danfo_model != null and DisplayServer.get_name() != "headless":
		_check(ModelBoundsScript.get_scaled_dimensions(danfo_model).is_equal_approx(Vector3(2.0, 2.25, 4.65)), "danfo visual is fitted to a 2.25m roof height and 4.65m body length")
	if DisplayServer.get_name() != "headless":
		_check(danfo_model.mesh.get_surface_count() >= 5, "danfo model retains separate body, window, wheel and light materials")
		var danfo_materials_valid := true
		for surface_index in range(danfo_model.mesh.get_surface_count()):
			if danfo_model.mesh.surface_get_material(surface_index) == null or danfo_model.get_active_material(surface_index) == null:
				danfo_materials_valid = false
		_check(danfo_materials_valid, "every danfo mesh surface has a material assigned")
	var danfo_collision := vehicle.get_child(0) as CollisionShape3D
	var danfo_box := danfo_collision.shape as BoxShape3D if danfo_collision != null else null
	_check(danfo_box != null and danfo_box.size.is_equal_approx(Vector3(2.05, 2.35, 4.7)), "danfo collision proxy uses a realistic 2.05m by 2.35m by 4.7m vehicle envelope")
	if DisplayServer.get_name() != "headless":
		_check(vehicle.get_node_or_null("DanfoDestinationBoard") != null, "danfo includes its Yaba/Tejuosho route board")
	vehicle.queue_free()
	await physics_frame


func _test_osm_world_generator() -> void:
	_check(is_equal_approx(OSMWorldGeneratorScript._resolve_building_height({"height_source": "osm:height", "height_m": 9.5}, 40.0), 9.5), "explicit OSM building heights take precedence over visual fallback estimates")
	_check(is_equal_approx(OSMWorldGeneratorScript._resolve_building_height({"height_source": "estimated:yes-default", "building": "yes"}, 25.0), 3.8), "small unmapped Yaba footprints receive a low-rise kiosk or bungalow height estimate")
	_check(is_equal_approx(OSMWorldGeneratorScript._resolve_building_height({"height_source": "estimated:yes-default", "building": "yes"}, 400.0), 11.5), "larger unmapped Yaba footprints receive varied multi-storey massing")
	_check(is_equal_approx(OSMWorldGeneratorScript._resolve_building_height({"building": "industrial"}, 500.0), 5.5), "industrial building height estimates do not use residential footprint tiers")
	var spawn_world = OSMWorldGeneratorScript.new()
	var spawn_roads: Array[Dictionary] = [
		{"name": "", "highway": "service", "surface": "unpaved", "width_m": 4.0, "coordinates": [[-5.0, 0.0], [5.0, 0.0]]},
		{"name": "Olajuwon Street", "highway": "residential", "surface": "unpaved", "width_m": 6.0, "coordinates": [[20.0, -50.0], [20.0, 50.0]]}
	]
	spawn_world._roads = spawn_roads
	var spawn_buildings: Array[Dictionary] = [
		{"outline": [[10.0, -5.0], [15.0, -5.0], [15.0, 5.0], [10.0, 5.0], [10.0, -5.0]]},
		{"outline": [[25.0, -5.0], [30.0, -5.0], [30.0, 5.0], [25.0, 5.0], [25.0, -5.0]]}
	]
	spawn_world._buildings = spawn_buildings
	var spawn_road := spawn_world._nearest_road_sample()
	_check(str(spawn_road["name"]) == "Olajuwon Street", "player and danfo spawn on a named public Yaba street instead of an unnamed service lane")
	_check(int(spawn_road["frontage_count"]) >= 2, "spawn selector prefers a street with mapped building frontage on both sides")
	spawn_world.free()
	var sample := {
		"schema_version": 1,
		"roads": [
			{"id": "100", "name": "Hughes Avenue", "highway": "residential", "surface": "unpaved", "width_m": 6.0, "coordinates": [[-20.0, 0.0], [20.0, 0.0]]},
			{"id": "101", "name": "Herbert Macaulay Way", "highway": "secondary", "surface": "paved", "width_m": 8.0, "coordinates": [[0.0, -20.0], [0.0, 20.0]]}
		],
		"buildings": [
			{"id": "200", "building": "residential", "height_m": 6.2, "outline": [[5.0, -5.0], [10.0, -5.0], [10.0, 5.0], [5.0, 5.0], [5.0, -5.0]]},
			{"id": "201", "building": "commercial", "shop": "convenience", "name": "Yaba Kiosk", "height_m": 4.0, "outline": [[15.0, 7.0], [20.0, 7.0], [20.0, 17.0], [15.0, 17.0], [15.0, 7.0]]}
		],
		"barriers": [
			{"id": "300", "barrier": "wall", "coordinates": [[-5.0, -5.0], [-5.0, 5.0]]}
		]
	}
	var world = OSMWorldGeneratorScript.new()
	root.add_child(world)
	_check(world.generate_from_data(sample), "OSM world generator accepts the versioned Yaba data contract")
	_check(world.get_road_count() == 2, "OSM world generator retains mapped street centre-lines")
	_check(world.get_building_count() == 2, "OSM world generator retains real building footprints")
	_check(world.get_barrier_count() == 1, "OSM world generator retains mapped compound barriers")
	var frontage_world = OSMWorldGeneratorScript.new()
	var frontage_roads: Array[Dictionary] = [
		{"name": "Hughes Avenue", "highway": "residential", "surface": "paved", "width_m": 6.0, "coordinates": [[-50.0, 0.0], [50.0, 0.0]]}
	]
	frontage_world._roads = frontage_roads
	var commercial_outline: Array[Vector2] = [Vector2(15.0, -5.0), Vector2(20.0, -5.0), Vector2(20.0, 5.0), Vector2(15.0, 5.0)]
	_check(frontage_world._closest_frontage_edge(commercial_outline) in [0, 2], "commercial shopfront orientation follows the closest mapped street edge")
	frontage_world.free()
	_check(world.get_node_or_null("OSMPavedRoadSurfaces") != null and world.get_node_or_null("OSMUnpavedLateriteRoadSurfaces") != null, "OSM paved and unpaved streets generate distinct 3D road surfaces")
	_check(world.get_node_or_null("OSMRoadsideDrainage") != null, "mapped streets include roadside drainage channels")
	_check(world.get_node_or_null("OSMRoadsideCurbs") != null and world.get_node_or_null("OSMDrainageGrates") != null, "mapped streets include raised concrete kerbs and periodic drain grates")
	_check(world.get_node_or_null("YabaMarketUmbrellasRed") != null and world.get_node_or_null("YabaMarketTables") != null, "mapped commercial frontages receive recognizable roadside market stalls")
	var parked_keke := world.get_node_or_null("YabaParkedKeke") as Node3D
	_check(parked_keke != null and parked_keke.get_node_or_null("KekeCollision") != null, "Yaba street scene includes a correctly scaled parked keke with collision")
	_check(world.get_node_or_null("YabaMarketStallCollision") != null, "roadside market tables have collision so the player cannot walk through them")
	var stall_collision_root := world.get_node_or_null("YabaMarketStallCollision") as Node3D
	if stall_collision_root != null and not stall_collision_root.get_children().is_empty():
		var stall_body := stall_collision_root.get_child(0) as StaticBody3D
		var stall_direction := stall_body.global_basis.z.normalized()
		var stall_player = PlayerScript.new()
		root.add_child(stall_player)
		stall_player.global_position = stall_body.global_position - stall_direction * 3.0
		await physics_frame
		var stall_hit = stall_player.move_and_collide(stall_direction * 6.0)
		_check(stall_hit != null, "player capsule collides with a Yaba roadside market stall")
		stall_player.queue_free()
		await physics_frame
	var road_visual := world.get_node_or_null("OSMPavedRoadSurfaces") as MeshInstance3D
	var laterite_visual := world.get_node_or_null("OSMUnpavedLateriteRoadSurfaces") as MeshInstance3D
	_check(laterite_visual != null, "OSM unpaved streets use a separate laterite material batch")
	_check(world.get_node_or_null("OSMRoadMarkings") != null, "mapped secondary roads receive lane markings")
	_check(world.get_node_or_null("OSMBuildingFootprintsAndFacades") != null, "OSM building footprints become extruded 3D building geometry")
	_check(world.get_node_or_null("OSMWindowFrameHorizontal") != null and world.get_node_or_null("OSMWindowFrameVertical") != null, "Yaba building windows receive batched facade frames")
	_check(world.get_node_or_null("OSMWindowSecurityGrilles") != null, "ground-floor windows receive batched Lagos-style security grilles")
	var building_visual := world.get_node_or_null("OSMBuildingFootprintsAndFacades") as MeshInstance3D
	_check(building_visual != null and building_visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "mapped buildings cast shadows for street depth")
	if DisplayServer.get_name() != "headless":
		var ground_visual := world.get_node_or_null("YabaDistrictGround") as MeshInstance3D
		var ground_material := ground_visual.material_override as StandardMaterial3D if ground_visual != null else null
		_check(ground_material != null and ground_material.uv1_scale.x >= 100.0 and ground_material.normal_scale <= 0.1, "district soil texture tiles at real-world scale without exaggerated ground ripples")
		var road_material: StandardMaterial3D
		if road_visual != null:
			road_material = road_visual.mesh.surface_get_material(0) as StandardMaterial3D
		_check(road_material != null and road_material.albedo_texture != null, "road surfaces use layered asphalt aggregate and weathering texture")
		_check(road_material != null and road_material.normal_enabled and road_material.normal_texture != null and road_material.roughness_texture != null, "asphalt uses mobile-sized normal and roughness maps for surface depth")
		if building_visual != null and building_visual.mesh != null:
			var facade_material := building_visual.mesh.surface_get_material(0) as StandardMaterial3D
			_check(facade_material != null and facade_material.normal_enabled and facade_material.roughness_texture != null, "building facades use plaster normal and roughness maps")
	var shop_sign := world.get_node_or_null("YabaShopSign_00") as Label3D
	_check(shop_sign != null and shop_sign.font != null and shop_sign.material_override != null, "3D shop signage uses a bundled font and explicit text material")
	_check(world.get_node_or_null("OSMBuildingCollision") != null, "OSM building geometry receives a static collision mesh")
	_check(world.get_node_or_null("OSMBarrierCollision") != null, "mapped walls and fences receive static collision geometry")
	_check(world.get_node_or_null("ProceduralCompoundWallCollision") != null, "residential building footprints receive art-directed Lagos compound walls")
	var world_materials_valid := true
	for mesh_node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.get_active_material(surface_index) == null:
				world_materials_valid = false
	for batch_node in world.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := batch_node as MultiMeshInstance3D
		if batch.multimesh != null and batch.material_override == null:
			world_materials_valid = false
	_check(world_materials_valid, "every generated Yaba world mesh and batch has an assigned material")
	var spawn_position: Vector3 = world.get_player_spawn_position()
	_check(spawn_position.is_finite(), "Yaba player spawn refuses invalid or blocked coordinates")
	_check(world.is_spawn_position_clear(spawn_position), "Yaba player spawns outside building footprints and mapped barriers")
	var player = PlayerScript.new()
	root.add_child(player)
	player.global_position = Vector3(0.0, 0.5, 0.0)
	await physics_frame
	var collision = player.move_and_collide(Vector3(10.0, 0.0, 0.0))
	_check(collision != null, "player capsule collides with an OSM-derived building footprint")
	_check(player.global_position.x < 5.0, "player cannot walk through an OSM-derived building wall")
	player.queue_free()
	await physics_frame
	var fence_player = PlayerScript.new()
	root.add_child(fence_player)
	fence_player.global_position = Vector3(0.0, 0.5, 0.0)
	await physics_frame
	var fence_collision = fence_player.move_and_collide(Vector3(-10.0, 0.0, 0.0))
	_check(fence_collision != null, "player capsule collides with an OSM-mapped compound wall")
	fence_player.queue_free()
	await physics_frame
	world.visible = false
	var compound_player = PlayerScript.new()
	root.add_child(compound_player)
	compound_player.global_position = Vector3(3.0, 0.5, -6.2)
	# Diagnostic: isolate the wall/camera rendering path from the character mesh.
	if compound_player.body_mesh != null:
		compound_player.body_mesh.visible = false
	if compound_player._rigged_character != null:
		compound_player._rigged_character.visible = false
	await physics_frame
	var compound_collision = compound_player.move_and_collide(Vector3(6.0, 0.0, 0.0))
	_check(compound_collision != null, "player cannot walk through art-directed residential compound walls")
	compound_player.queue_free()
	await physics_frame
	var test_vehicle = VehicleScript.new()
	root.add_child(test_vehicle)
	test_vehicle.global_position = Vector3(0.0, 0.2, 0.0)
	await physics_frame
	var vehicle_collision = test_vehicle.move_and_collide(Vector3(10.0, 0.0, 0.0))
	_check(vehicle_collision != null, "drivable danfo collides with an OSM-derived building footprint")
	test_vehicle.queue_free()
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
	for visual_child in vehicle.get_children():
		if visual_child is MeshInstance3D or visual_child is Label3D:
			visual_child.visible = false
	if player._rigged_character != null:
		player._rigged_character.visible = false
	await physics_frame
	if DisplayServer.get_name() != "headless":
		_check(player._rigged_animation_player != null and player._rigged_animation_player.has_animation("HumanArmature|Man_Walk"), "player spawns with a rigged character and authored animation clips")
	_check(player.camera_pivot != null and player.camera != null, "player character rig includes a working follow camera")
	player.velocity = Vector3(0.0, 0.0, 2.0)
	player._update_character_animation(0.1)
	if DisplayServer.get_name() != "headless" and is_instance_valid(player._rigged_animation_player):
		_check(player._rigged_animation_player.current_animation == "HumanArmature|Man_Walk", "player switches to the authored walk cycle when moving")
	vehicle.position = Vector3(0.0, 0.0, 5.0)
	player.position = Vector3.ZERO
	_check(player._get_nearest_vehicle() == vehicle, "player detects a danfo within interaction range")
	vehicle.position = Vector3(0.0, 0.0, 20.0)
	_check(player._get_nearest_vehicle() == null, "player cannot enter a vehicle outside interaction range")
	vehicle.position = Vector3(0.0, 0.0, 5.0)
	vehicle.enter_vehicle(player)
	_check(vehicle.driver == player, "player becomes the active danfo driver")
	if DisplayServer.get_name() != "headless":
		_check(not player.body_mesh.visible, "player body is hidden while seated")
	_check(not player.is_physics_processing(), "on-foot movement is disabled while driving")
	_check(player.camera_yaw_pivot.get_parent() == vehicle, "third-person camera follows the danfo")
	_check(is_equal_approx(player.camera.rotation.x, deg_to_rad(-12.0)), "danfo camera keeps a downward street-facing pitch")
	vehicle.exit_vehicle()
	_check(vehicle.driver == null, "danfo releases the driver on exit")
	if DisplayServer.get_name() != "headless":
		_check(player.body_mesh.visible, "player body is restored after exiting")
	_check(player.is_physics_processing(), "on-foot movement is restored after exiting")
	_check(player.camera_yaw_pivot.get_parent() == player, "camera returns to the player after exiting")
	_check(is_equal_approx(player.camera.rotation.x, deg_to_rad(-14.0)), "camera restores the street-facing pitch after exiting the danfo")
	_check(is_zero_approx(player.camera_pivot.rotation.y), "camera yaw is consistent after exiting the danfo")
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
	_check(traffic.get_traffic_count() == 6, "Yaba district spawns a bounded six-car model-based ambient traffic pool")
	if DisplayServer.get_name() != "headless":
		_check(traffic.get_traffic_model_surface_count(0) >= 5, "ambient traffic uses detailed imported multi-material vehicle meshes")
		var traffic_materials_valid := true
		for surface_index in range(traffic._traffic_visuals[0].mesh.get_surface_count()):
			if traffic._traffic_visuals[0].mesh.surface_get_material(surface_index) == null or traffic._traffic_visuals[0].get_active_material(surface_index) == null:
				traffic_materials_valid = false
		_check(traffic_materials_valid, "every ambient traffic mesh surface has an assigned material")
	var first_traffic_shape := traffic._collision_bodies[0].get_child(0) as CollisionShape3D
	var first_traffic_box := first_traffic_shape.shape as BoxShape3D if first_traffic_shape != null else null
	var first_traffic_dimensions: Vector3 = TrafficManagerScript.TRAFFIC_MODEL_DIMENSIONS[0]
	_check(first_traffic_box != null and first_traffic_box.size.is_equal_approx(first_traffic_dimensions * Vector3(1.04, 1.03, 1.04)), "traffic collision proxy is derived from each imported car's actual dimensions")
	var starting_distance := traffic.get_traffic_distance(0)
	var starting_position := traffic.get_traffic_position(0)
	var fitted_car_scale: Vector3 = traffic._traffic_visuals[0].scale if not traffic._traffic_visuals.is_empty() else Vector3.ONE
	traffic._process(1.0)
	_check(traffic.get_traffic_distance(0) > starting_distance, "ambient traffic advances along its mapped road polyline")
	if not traffic._traffic_visuals.is_empty():
		_check(traffic._traffic_visuals[0].scale.is_equal_approx(fitted_car_scale), "traffic route updates preserve the fitted real-world car dimensions")
	_check(traffic.get_traffic_position(0) != starting_position, "ambient traffic transforms follow the road geometry")
	var expected_traffic_children := 6 if DisplayServer.get_name() == "headless" else 12
	_check(traffic.get_child_count() == expected_traffic_children, "traffic keeps six model visuals and six collision proxies in rendered builds")
	_check(traffic.get_traffic_collision_count() == 6, "every ambient traffic vehicle has a physics collision proxy")
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
	if DisplayServer.get_name() != "headless":
		_check(pedestrians._visuals.size() == 4 and pedestrians._animation_players.size() == 4, "each pedestrian uses an independent rigged character instance")
		_check(pedestrians._animation_players[0] != null and pedestrians._animation_players[0].has_animation("HumanArmature|Man_Walk"), "pedestrian characters have real walk animation clips")
	if DisplayServer.get_name() != "headless":
		var pedestrian_meshes: Array[Node] = pedestrians._visuals[0].find_children("*", "MeshInstance3D", true, false)
		var pedestrian_materials_valid: bool = not pedestrian_meshes.is_empty()
		for mesh_node in pedestrian_meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				if mesh_instance.get_active_material(surface_index) == null:
					pedestrian_materials_valid = false
		_check(pedestrian_materials_valid, "every pedestrian mesh surface has an assigned material")
		var pedestrian_skin_found := false
		var pedestrian_override_clear := true
		for mesh_node in pedestrian_meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.material_override != null:
				pedestrian_override_clear = false
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var surface_material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
				if surface_material != null and surface_material.albedo_color.is_equal_approx(Color(0.48, 0.29, 0.19)):
					pedestrian_skin_found = true
		_check(pedestrian_skin_found and pedestrian_override_clear, "pedestrians preserve their individual skin and clothing palette")
		_check(is_equal_approx(absf(pedestrians._visuals[0].rotation.y), PI), "pedestrian rigs face along their sidewalk routes")
	_check(pedestrians.get_pedestrian_collision_count() == 4, "each pedestrian has a low-cost capsule collision proxy")
	var starting_distance := pedestrians.get_pedestrian_distance(0)
	var starting_position := pedestrians.get_pedestrian_position(0)
	var fitted_pedestrian_scale: Vector3 = pedestrians._visuals[0].scale if not pedestrians._visuals.is_empty() else Vector3.ONE
	pedestrians._process(1.0)
	_check(pedestrians.get_pedestrian_distance(0) > starting_distance, "pedestrians walk along their mapped sidewalk routes")
	if not pedestrians._visuals.is_empty():
		_check(pedestrians._visuals[0].scale.is_equal_approx(fitted_pedestrian_scale), "pedestrian route updates preserve the fitted human dimensions")
	_check(pedestrians.get_pedestrian_position(0) != starting_position, "pedestrian render transforms update as they walk")
	if DisplayServer.get_name() != "headless":
		_check(pedestrians.get_child_count() == 8, "pedestrians use four rigged 3D models plus four collision proxies")
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

func _test_player_danfo_collision() -> void:
	var vehicle = VehicleScript.new()
	root.add_child(vehicle)
	var player = PlayerScript.new()
	root.add_child(player)
	vehicle.global_position = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.5, -5.0)
	await physics_frame
	var collision = player.move_and_collide(Vector3(0.0, 0.0, 10.0))
	_check(collision != null, "player capsule collides with the drivable Lagos danfo")
	_check(player.global_position.z < -2.0, "player cannot walk through the drivable danfo body")
	player.queue_free()
	vehicle.queue_free()
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
