extends SceneTree

const ModelBoundsScript = preload("res://scripts/model_bounds.gd")

## CI-only visual smoke capture. The first-run legal overlay is hidden for this
## screenshot; the shipped game still presents it normally on first launch.

func _initialize() -> void:
	call_deferred("_capture_world")

func _validate_render_materials(scene: Node) -> bool:
	var missing_materials := 0
	var empty_meshes := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		# MeshInstance3D is also used as a transform/visibility container for
		# imported character scenes. A null mesh on such a parent is not renderable
		# geometry and must not be reported as an empty render node.
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.get_active_material(surface_index) == null:
				missing_materials += 1
				print("PREVIEW_NULL_MATERIAL_PATH=", mesh_instance.get_path(), " surface=", surface_index)
	for node in scene.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			empty_meshes += 1
			continue
		for surface_index in range(batch.multimesh.mesh.get_surface_count()):
			if batch.get_active_material(surface_index) == null:
				missing_materials += 1
				print("PREVIEW_NULL_MULTIMESH_MATERIAL_PATH=", batch.get_path(), " surface=", surface_index)
	for node in scene.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if label.material_override == null:
			missing_materials += 1
			print("PREVIEW_NULL_LABEL_MATERIAL_PATH=", label.get_path())
	print("PREVIEW_EMPTY_RENDER_NODES=", empty_meshes)
	print("PREVIEW_MISSING_BASE_MATERIALS=", missing_materials)
	if empty_meshes > 0 or missing_materials > 0:
		push_error("Rendered scene contains empty mesh nodes or missing base materials.")
		return false
	return true

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
	if not _validate_render_materials(main_scene):
		quit(1)
		return
	if player != null:
		var player_model := player.body_mesh.get_node_or_null("RiggedLagosPlayer") as Node3D if player.body_mesh != null else null
		if player_model == null:
			push_error("Rendered player rig is missing from the scene.")
			quit(1)
			return
		var player_bounds: AABB = ModelBoundsScript._combined_local_bounds(player_model)
		var player_height := player_bounds.size.y * player_model.scale.y
		print("PREVIEW_PLAYER_HEIGHT_METRES=", player_height)
		if absf(player_height - 1.76) > 0.03:
			push_error("Player visual height is outside the 1.76m scale target.")
			quit(1)
			return
	var danfo_model := main_scene.get_node_or_null("YabaDanfo/DanfoModel") as MeshInstance3D
	if danfo_model == null:
		push_error("Rendered danfo model is missing from the scene.")
		quit(1)
		return
	var danfo_dimensions: Vector3 = ModelBoundsScript.get_scaled_dimensions(danfo_model)
	print("PREVIEW_DANFO_DIMENSIONS_METRES=", danfo_dimensions)
	if not danfo_dimensions.is_equal_approx(Vector3(2.0, 2.25, 4.65)):
		push_error("Danfo visual dimensions do not match the 2.25m by 4.65m target.")
		quit(1)
		return
	if player != null:
		player.mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.camera_yaw_pivot.rotation = Vector3.ZERO
		player.camera_pivot.rotation = Vector3.ZERO
		player.camera.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
		print("PREVIEW_PLAYER_POSITION=", player.global_position)
		print("PREVIEW_PLAYER_ROTATION=", player.global_rotation)
		print("PREVIEW_YAW_PIVOT_ROTATION=", player.camera_yaw_pivot.global_rotation)
		print("PREVIEW_SPRING_ROTATION=", player.camera_pivot.global_rotation)
		print("PREVIEW_SPRING_HIT_LENGTH=", player.camera_pivot.get_hit_length())
		print("PREVIEW_CAMERA_ROTATION=", player.camera.global_rotation)
		print("PREVIEW_CAMERA_POSITION=", player.camera.global_position)
		print("PREVIEW_CAMERA_FORWARD=", -player.camera.global_basis.z)
		var player_target := player.global_position + Vector3.UP * 1.0
		var direction_to_player := (player_target - player.camera.global_position).normalized()
		print("PREVIEW_PLAYER_IN_FRONT_DOT=", direction_to_player.dot(-player.camera.global_basis.z))
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
