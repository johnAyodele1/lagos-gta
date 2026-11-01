extends Node3D

const PlayerScript = preload("res://scripts/player_controller.gd")
const OSMWorldScript = preload("res://scripts/osm_world_generator.gd")
const GraphicsProfileScript = preload("res://scripts/graphics_profile.gd")
const MobileControlsScript = preload("res://scripts/mobile_controls.gd")
const LegalConsentScript = preload("res://scripts/legal_consent.gd")
const VehicleScript = preload("res://scripts/vehicle_controller.gd")
const TrafficManagerScript = preload("res://scripts/traffic_manager.gd")
const PedestrianManagerScript = preload("res://scripts/pedestrian_manager.gd")

var _graphics_profile: Dictionary = {}
var _sun_light: DirectionalLight3D
var _world_environment: Environment
var _player: PlayerController
var _quality_button: Button

func _ready() -> void:
	_build_environment()
	var world = OSMWorldScript.new()
	world.name = "YabaOpenStreetMapDistrict"
	add_child(world)
	if not world.generate_from_file("res://assets/data/yaba_osm.json"):
		push_error("The playable Yaba district could not be built from its OpenStreetMap extract.")
		return
	_spawn_traffic(world.get_road_data())
	_spawn_pedestrians(world.get_road_data())
	_spawn_vehicle(world)
	_spawn_player(world)
	_ensure_scene_materials()
	_add_hud()
	_add_legal_consent()

func _ensure_scene_materials() -> void:
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.42, 0.42, 0.40)
	fallback.roughness = 0.9
	var missing_surfaces := 0
	var empty_mesh_nodes := 0
	var affected_nodes: Array[String] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			empty_mesh_nodes += 1
			if mesh_instance.get_child_count() == 0:
				mesh_instance.queue_free()
			else:
				var invisible_placeholder := BoxMesh.new()
				invisible_placeholder.size = Vector3.ONE * 0.001
				var invisible_material := StandardMaterial3D.new()
				invisible_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				invisible_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
				invisible_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh_instance.mesh = invisible_placeholder
				mesh_instance.material_override = invisible_material
			continue
		# Instance overrides are not a substitute for a valid source surface
		# material on every renderer/backend. Repair a duplicate mesh resource
		# so imported shared resources are never mutated globally.
		var mesh_copy := mesh_instance.mesh.duplicate() as Mesh
		if mesh_copy == null:
			mesh_instance.material_override = fallback
			continue
		var changed := false
		for surface_index in range(mesh_copy.get_surface_count()):
			if mesh_copy.surface_get_material(surface_index) != null:
				continue
			mesh_copy.surface_set_material(surface_index, fallback)
			missing_surfaces += 1
			changed = true
			if affected_nodes.size() < 12:
				affected_nodes.append("%s[%d]" % [str(mesh_instance.get_path()), surface_index])
		if changed:
			mesh_instance.mesh = mesh_copy
		if mesh_instance.material_override == null and mesh_instance.mesh.get_surface_count() == 0:
			mesh_instance.material_override = fallback
	for node in find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			batch.queue_free()
			continue
		var batch_mesh_copy := batch.multimesh.mesh.duplicate() as Mesh
		if batch_mesh_copy == null:
			batch.material_override = fallback
			continue
		var batch_changed := false
		for surface_index in range(batch_mesh_copy.get_surface_count()):
			if batch_mesh_copy.surface_get_material(surface_index) != null:
				continue
			batch_mesh_copy.surface_set_material(surface_index, fallback)
			missing_surfaces += 1
			batch_changed = true
			if affected_nodes.size() < 12:
				affected_nodes.append(str(batch.get_path()))
		if batch_changed:
			batch.multimesh.mesh = batch_mesh_copy
		if batch.material_override == null and batch_mesh_copy.get_surface_count() == 0:
			batch.material_override = fallback
	if missing_surfaces > 0:
		push_warning("Assigned fallback base materials to %d render surfaces: %s" % [missing_surfaces, ", ".join(affected_nodes)])
	if empty_mesh_nodes > 0:
		push_warning("Repaired or removed %d empty MeshInstance3D nodes before rendering." % empty_mesh_nodes)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.13, 0.29, 0.49)
	sky_material.sky_horizon_color = Color(0.68, 0.77, 0.82)
	sky_material.ground_bottom_color = Color(0.24, 0.22, 0.19)
	sky_material.ground_horizon_color = Color(0.57, 0.60, 0.56)
	sky_material.sun_angle_max = 8.0
	sky_material.sun_curve = 0.15
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.ambient_light_sky_contribution = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.04
	environment.adjustment_saturation = 1.03
	world_environment.environment = environment
	_world_environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.93, 0.82)
	_graphics_profile = GraphicsProfileScript.apply(sun, _load_graphics_quality())
	environment.ambient_light_energy = 0.72 if _graphics_profile["name"] == "low" else 0.62
	_sun_light = sun
	add_child(sun)

func _load_graphics_quality() -> String:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var configured := str(config.get_value("graphics", "quality", ""))
		if configured in ["low", "balanced", "high"]:
			return configured
	return "balanced" if OS.has_feature("mobile") else "high"

func _spawn_vehicle(world: OSMWorldGenerator) -> void:
	var vehicle = VehicleScript.new()
	vehicle.name = "YabaDanfo"
	vehicle.position = world.get_vehicle_spawn_position()
	vehicle.rotation.y = world.get_spawn_rotation_y()
	add_child(vehicle)

func _spawn_player(world: OSMWorldGenerator) -> void:
	var player = PlayerScript.new()
	player.name = "Player"
	var spawn_position: Vector3 = world.get_player_spawn_position()
	if not spawn_position.is_finite() or not world.is_spawn_position_clear(spawn_position):
		push_error("Player spawn is blocked by mapped Yaba geometry; refusing unsafe spawn.")
		return
	player.position = spawn_position
	player.rotation.y = world.get_spawn_rotation_y()
	add_child(player)
	_player = player
	player.camera.far = float(_graphics_profile.get("far_clip", 220.0))

	var controls_layer := CanvasLayer.new()
	controls_layer.name = "MobileControlsLayer"
	controls_layer.layer = 10
	add_child(controls_layer)
	var controls = MobileControlsScript.new()
	controls.name = "MobileControls"
	controls_layer.add_child(controls)
	player.mobile_controls = controls

func _add_legal_consent() -> void:
	var legal_layer := LegalConsentScript.new()
	legal_layer.name = "LegalConsent"
	legal_layer.layer = 20
	add_child(legal_layer)

func _add_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(24.0, 20.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	if OS.has_feature("mobile"):
		label.text = "LAGOS GTA  |  YABA, LAGOS  |  TAP JUMP NEAR DANFO TO ENTER / EXIT"
	else:
		label.text = "LAGOS GTA  |  YABA, LAGOS\nWASD: Move   SHIFT: Sprint   SPACE: Jump   E: Enter / exit Danfo\nMouse: Look   ESC: Release / capture mouse"
	layer.add_child(label)

	_quality_button = Button.new()
	_quality_button.name = "GraphicsQualityButton"
	_quality_button.text = "QUALITY: " + str(_graphics_profile.get("name", "balanced")).to_upper()
	_quality_button.anchor_left = 1.0
	_quality_button.anchor_right = 1.0
	_quality_button.anchor_top = 0.0
	_quality_button.anchor_bottom = 0.0
	_quality_button.offset_left = -184.0
	_quality_button.offset_right = -16.0
	_quality_button.offset_top = 14.0
	_quality_button.offset_bottom = 58.0
	_quality_button.add_theme_font_size_override("font_size", 14)
	_quality_button.pressed.connect(_cycle_graphics_quality)
	layer.add_child(_quality_button)

	var map_attribution := Label.new()
	map_attribution.name = "OpenStreetMapAttribution"
	map_attribution.text = "Map data © OpenStreetMap contributors · ODbL 1.0"
	map_attribution.anchor_left = 1.0
	map_attribution.anchor_right = 1.0
	map_attribution.anchor_top = 0.0
	map_attribution.anchor_bottom = 0.0
	map_attribution.offset_left = -300.0
	map_attribution.offset_right = -16.0
	map_attribution.offset_top = 62.0
	map_attribution.offset_bottom = 82.0
	map_attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_attribution.add_theme_font_size_override("font_size", 10)
	map_attribution.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	layer.add_child(map_attribution)

func _cycle_graphics_quality() -> void:
	var options := ["low", "balanced", "high"]
	var current := str(_graphics_profile.get("name", "balanced"))
	var next_index: int = (options.find(current) + 1) % options.size()
	var next_quality: String = options[next_index]
	_graphics_profile = GraphicsProfileScript.apply(_sun_light, next_quality)
	_world_environment.ambient_light_energy = 0.72 if next_quality == "low" else 0.62
	if _player != null and is_instance_valid(_player):
		_player.camera.far = float(_graphics_profile["far_clip"])
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", next_quality)
	var save_error := config.save("user://settings.cfg")
	if save_error != OK:
		push_warning("Unable to save graphics quality preference: %s" % error_string(save_error))
	_quality_button.text = "QUALITY: " + next_quality.to_upper()

func _spawn_traffic(roads: Array[Dictionary]) -> void:
	var traffic = TrafficManagerScript.new()
	traffic.name = "AmbientLagosTraffic"
	traffic.configure_from_roads(roads)
	add_child(traffic)

func _spawn_pedestrians(roads: Array[Dictionary]) -> void:
	var pedestrians = PedestrianManagerScript.new()
	pedestrians.name = "YabaSidewalkPedestrians"
	pedestrians.configure_from_roads(roads)
	add_child(pedestrians)
