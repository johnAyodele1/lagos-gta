extends Node3D

const PlayerScript = preload("res://scripts/player_controller.gd")
const WorldScript = preload("res://scripts/world_generator.gd")

func _ready() -> void:
	_build_environment()
	var world = WorldScript.new()
	world.name = "StarterDistrict"
	add_child(world)
	world.generate()
	_spawn_player()
	_add_hud()

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
	sun.shadow_enabled = true
	add_child(sun)

func _spawn_player() -> void:
	var player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.5, 5.0)
	add_child(player)

func _add_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(24.0, 20.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text = "LAGOS GTA  |  STARTER DISTRICT\nWASD: Move   SHIFT: Sprint   SPACE: Jump\nMouse: Look   ESC: Release / capture mouse"
	layer.add_child(label)
