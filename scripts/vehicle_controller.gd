extends CharacterBody3D
class_name VehicleController
const LABEL_FONT = preload("res://assets/fonts/Roboto.ttf")

const MAX_FORWARD_SPEED: float = 22.0
const MAX_REVERSE_SPEED: float = 8.0
const ACCELERATION: float = 10.0
const BRAKE_ACCELERATION: float = 20.0
const COAST_DECELERATION: float = 5.0
const STEERING_RATE: float = 1.25
const GRAVITY: float = 18.0
const WORLD_COLLISION_LAYER: int = 1
const VEHICLE_COLLISION_LAYER: int = 2
const PLAYER_COLLISION_LAYER: int = 4
const NPC_COLLISION_LAYER: int = 8
const ModelBoundsScript = preload("res://scripts/model_bounds.gd")

var driver: Node
var current_speed: float = 0.0
var _driver_collision_layer: int = 1
var _driver_collision_mask: int = 1
var _wheels: Array[Node3D] = []

static func target_speed(throttle: float, boost: bool = false) -> float:
	var forward_limit := MAX_FORWARD_SPEED * (1.15 if boost else 1.0)
	var safe_throttle := clampf(throttle, -1.0, 1.0)
	return safe_throttle * (MAX_REVERSE_SPEED if safe_throttle < 0.0 else forward_limit)

static func acceleration_for(current: float, target: float) -> float:
	if absf(current) > 0.5 and current * target < 0.0:
		return BRAKE_ACCELERATION
	if absf(target) > absf(current):
		return ACCELERATION
	return COAST_DECELERATION

func _ready() -> void:
	collision_layer = VEHICLE_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_LAYER | PLAYER_COLLISION_LAYER | NPC_COLLISION_LAYER
	floor_snap_length = 0.35
	safe_margin = 0.04
	max_slides = 8
	add_to_group("drivable_vehicle")
	_build_vehicle()

func _build_vehicle() -> void:
	# Physics footprint matches the imported minibus model (about 4.75m long).
	var body_collision := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(2.05, 2.35, 4.7)
	body_collision.shape = body_shape
	body_collision.position.y = 1.175
	add_child(body_collision)

	var danfo_mesh := load("res://assets/models/vehicles/danfo/car-minibus-citrus.obj") as Mesh
	if danfo_mesh == null:
		push_error("Licensed Danfo base mesh failed to import.")
		return
	var model := MeshInstance3D.new()
	model.name = "DanfoModel"
	model.mesh = danfo_mesh
	var danfo_surface_colors: Array[Color] = [
		Color(0.92, 0.72, 0.055), Color(0.055, 0.14, 0.18), Color(0.95, 0.90, 0.68),
		Color(0.8, 0.24, 0.02), Color(0.72, 0.035, 0.025), Color(0.36, 0.36, 0.34), Color(0.025, 0.025, 0.025)
	]
	if DisplayServer.get_name() != "headless":
		for surface_index in range(danfo_mesh.get_surface_count()):
			if danfo_mesh.surface_get_material(surface_index) == null:
				var fallback := StandardMaterial3D.new()
				fallback.albedo_color = danfo_surface_colors[mini(surface_index, danfo_surface_colors.size() - 1)]
				fallback.roughness = 0.82
				model.set_surface_override_material(surface_index, fallback)
	# Source mesh faces +Z; this controller drives forward along local -Z.
	model.rotation.y = PI
	if DisplayServer.get_name() == "headless":
		# The OBJ source bounds were measured once: 0.954 x 0.945 x 2.163m.
		# Use the equivalent fit in dummy-renderer tests, which cannot query mesh AABBs.
		model.scale = Vector3(2.096, 2.381, 2.150)
		model.position = Vector3(0.0, 0.0, 0.175)
	elif not ModelBoundsScript.fit_dimensions(model, Vector3(2.0, 2.25, 4.65)):
		push_error("Danfo mesh has invalid bounds and cannot be fitted to real vehicle dimensions.")
		return
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(model)

	# Lagos Danfo route board and waist stripes are authored separately so the
	# imported vehicle mesh keeps its original materials, glass and wheel detail.
	for side in [-1.0, 1.0]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.035, 0.11, 3.35)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(side * 0.995, 1.02, 0.0)
		stripe.material_override = _vehicle_material(Color(0.045, 0.045, 0.04), 0.78)
		add_child(stripe)

	var route_label := Label3D.new()
	route_label.font = LABEL_FONT
	route_label.material_override = _vehicle_material(Color(1.0, 0.94, 0.68), 0.0)
	route_label.name = "DanfoDestinationBoard"
	route_label.text = "YABA  /  TEJUOSHO"
	route_label.font_size = 26
	route_label.outline_size = 5
	route_label.position = Vector3(0.0, 2.16, -2.34)
	route_label.modulate = Color(1.0, 0.94, 0.68)
	add_child(route_label)

func _create_loft_mesh(sections: Array[Dictionary]) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	for section in sections:
		var width := float(section["width"])
		var bottom := float(section["bottom"])
		var top := float(section["top"])
		var z := float(section["z"])
		var bevel := minf(0.16, (top - bottom) * 0.22)
		rings.append(PackedVector3Array([
			Vector3(-width + bevel, bottom, z),
			Vector3(width - bevel, bottom, z),
			Vector3(width, bottom + bevel, z),
			Vector3(width, top - bevel, z),
			Vector3(width - bevel, top, z),
			Vector3(-width + bevel, top, z),
			Vector3(-width, top - bevel, z),
			Vector3(-width, bottom + bevel, z)
		]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(rings.size() - 1):
		for corner in range(8):
			var next_corner := (corner + 1) % 8
			var a := rings[ring_index][corner]
			var b := rings[ring_index + 1][corner]
			var c := rings[ring_index][next_corner]
			var d := rings[ring_index + 1][next_corner]
			surface.add_vertex(a)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(d)
			surface.add_vertex(b)
	for cap_index in [0, rings.size() - 1]:
		var ring: PackedVector3Array = rings[cap_index]
		var center := Vector3.ZERO
		for point in ring:
			center += point
		center /= float(ring.size())
		for corner in range(8):
			var next_corner := (corner + 1) % 8
			surface.add_vertex(center)
			if cap_index == 0:
				surface.add_vertex(ring[next_corner])
				surface.add_vertex(ring[corner])
			else:
				surface.add_vertex(ring[corner])
				surface.add_vertex(ring[next_corner])
	surface.generate_normals()
	return surface.commit()

func _add_plane(size: Vector2, plane_position: Vector3, plane_rotation: Vector3, material: Material, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = plane_position
	instance.rotation = plane_rotation
	instance.material_override = material
	instance.name = node_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _vehicle_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.08
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _add_box(box_size: Vector3, box_position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = box_position
	instance.material_override = _vehicle_material(color, 0.82)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_wheel(wheel_position: Vector3, radius: float, width: float, color: Color) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 16
	wheel.mesh = mesh
	wheel.position = wheel_position
	wheel.rotation.z = PI * 0.5
	wheel.material_override = _vehicle_material(color, 0.94)
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wheel)
	_wheels.append(wheel)

func enter_vehicle(player: Node) -> void:
	if driver != null:
		return
	if not is_instance_valid(player) or player.camera_pivot == null or player.camera == null or player.body_mesh == null:
		push_error("Cannot enter the danfo: player camera or visual rig is not ready.")
		return
	driver = player
	_driver_collision_layer = int(player.collision_layer)
	_driver_collision_mask = int(player.collision_mask)
	player.set_physics_process(false)
	player.collision_layer = 0
	player.collision_mask = 0
	player.body_mesh.visible = false
	player.camera_yaw_pivot.reparent(self, false)
	player.camera_yaw_pivot.position = Vector3(0.0, 2.4, 0.0)
	player.camera_yaw_pivot.rotation = Vector3.ZERO
	player.camera_pivot.position = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera_pivot.spring_length = 8.0
	player.camera.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
	player.camera_pivot.collision_mask = WORLD_COLLISION_LAYER
	player.camera.position = Vector3.ZERO
	player.camera.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)

func _find_safe_exit_position(player: Node) -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.78
	var space := get_world_3d().direct_space_state
	var candidate_offsets: Array[Vector3] = [
		global_basis.x * 3.2,
		-global_basis.x * 3.2,
		-global_basis.z * 4.0,
		global_basis.z * 4.0
	]
	for offset in candidate_offsets:
		var candidate := global_position + offset + Vector3.UP * 0.5
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis(), candidate + Vector3.UP * 0.9)
		query.collision_mask = _driver_collision_mask
		query.exclude = [get_rid()]
		query.margin = 0.04
		if space.intersect_shape(query, 1).is_empty():
			return candidate
	return Vector3.INF

func exit_vehicle() -> void:
	if driver == null:
		return
	var player = driver
	var safe_position := _find_safe_exit_position(player)
	if not safe_position.is_finite():
		push_warning("Cannot exit the danfo: all nearby exit positions are blocked.")
		return
	driver = null
	player.camera_yaw_pivot.reparent(player, false)
	player.camera_yaw_pivot.position = Vector3(0.0, 1.72, 0.0)
	player.camera_yaw_pivot.rotation = Vector3.ZERO
	player.camera_pivot.position = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera_pivot.spring_length = 7.2
	player.camera.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	player.camera_pivot.collision_mask = WORLD_COLLISION_LAYER
	player.camera.position = Vector3.ZERO
	player.camera.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	player.global_position = safe_position
	player.velocity = Vector3.ZERO
	player.collision_layer = _driver_collision_layer
	player.collision_mask = _driver_collision_mask
	player.body_mesh.visible = true
	player.set_physics_process(true)

func _physics_process(delta: float) -> void:
	if driver == null:
		return

	var exit_requested := bool(driver.interact_requested)
	driver.interact_requested = false
	var mobile_controls = driver.mobile_controls
	var input_vector := Vector2.ZERO
	input_vector.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input_vector.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	if mobile_controls != null:
		input_vector += mobile_controls.get_move_vector()
		exit_requested = exit_requested or mobile_controls.consume_jump_request()
		driver._apply_look_delta(mobile_controls.consume_look_delta())
	input_vector = input_vector.limit_length(1.0)

	if exit_requested:
		exit_vehicle()
		return

	var throttle := -input_vector.y
	var boost := Input.is_physical_key_pressed(KEY_SHIFT)
	if mobile_controls != null:
		boost = boost or mobile_controls.is_sprint_pressed()
	var target := target_speed(throttle, boost)
	var acceleration := acceleration_for(current_speed, target)
	current_speed = move_toward(current_speed, target, acceleration * delta)

	var steering := input_vector.x
	var speed_factor := clampf(absf(current_speed) / MAX_FORWARD_SPEED, 0.0, 1.0)
	rotation.y -= steering * STEERING_RATE * speed_factor * signf(current_speed) * delta
	velocity.x = -global_basis.z.x * current_speed
	velocity.z = -global_basis.z.z * current_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	move_and_slide()

	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.RIGHT, current_speed * delta / 0.48)
