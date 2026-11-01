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
var _player: CharacterBody3D
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
	_world_environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.15
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
	player.position = world.get_player_spawn_position()
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

func _cycle_graphics_quality() -> void:
	var options := ["low", "balanced", "high"]
	var current := str(_graphics_profile.get("name", "balanced"))
	var next_index := (options.find(current) + 1) % options.size()
	var next_quality := options[next_index]
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
