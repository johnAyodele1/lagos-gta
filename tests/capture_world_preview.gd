extends SceneTree

## CI-only visual smoke capture. The first-run legal overlay is hidden for this
## screenshot; the shipped game still presents it normally on first launch.

func _initialize() -> void:
	call_deferred("_capture_world")

func _capture_world() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Unable to load main scene for visual capture.")
		quit(1)
		return

	var main_scene := packed_scene.instantiate()
	root.add_child(main_scene)
	await process_frame
	var legal_layer := main_scene.get_node_or_null("LegalConsent") as CanvasLayer
	if legal_layer != null:
		legal_layer.visible = false

	var player := main_scene.get_node_or_null("Player") as PlayerController
	var world := main_scene.get_node_or_null("YabaOpenStreetMapDistrict") as OSMWorldGenerator
	if player != null:
		print("PREVIEW_PLAYER_POSITION=", player.global_position)
		print("PREVIEW_CAMERA_POSITION=", player.camera.global_position)
		print("PREVIEW_CAMERA_FORWARD=", -player.camera.global_basis.z)
		print("PREVIEW_BODY_VISIBLE=", player.body_mesh.visible)
		print("PREVIEW_CAMERA_CURRENT=", player.camera.current)
		print("PREVIEW_SPRING_LENGTH=", player.camera_pivot.spring_length)
	if world != null:
		print("PREVIEW_ROAD_COUNT=", world.get_road_count())
		print("PREVIEW_BUILDING_COUNT=", world.get_building_count())

	# Let the first rendered frames settle after the OSM geometry and camera spawn.
	await create_timer(3.0).timeout
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("World preview capture returned an empty image.")
		quit(1)
		return
	var save_error := image.save_png("user://yaba-world-preview.png")
	if save_error != OK:
		push_error("Unable to save world preview: %s" % error_string(save_error))
		quit(1)
		return
	quit()
