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
	_add_hud()
	_add_legal_consent()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.67, 0.72)
	environment.ambient_light_energy = 0.65
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.15
	_graphics_profile = GraphicsProfileScript.apply(sun, _load_graphics_quality())
	environment.ambient_light_energy = 0.72 if _graphics_profile["name"] == "low" else 0.62
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
	player.position = world.get_player_spawn_position()
	player.rotation.y = world.get_spawn_rotation_y()
	add_child(player)
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
		label.text = "LAGOS GTA  |  YABA DISTRICT\nWASD: Move   SHIFT: Sprint   SPACE: Jump   E: Enter / exit Danfo\nMouse: Look   ESC: Release / capture mouse"
	layer.add_child(label)

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
