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
