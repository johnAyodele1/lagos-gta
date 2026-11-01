extends CharacterBody3D
class_name VehicleController

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
	collision_mask = WORLD_COLLISION_LAYER | PLAYER_COLLISION_LAYER
	floor_snap_length = 0.35
	safe_margin = 0.04
	max_slides = 8
	add_to_group("drivable_vehicle")
	_build_vehicle()

func _build_vehicle() -> void:
	var body_collision := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(5.2, 2.8, 2.4)
	body_collision.shape = body_shape
	body_collision.position.y = 1.4
	add_child(body_collision)

	_add_box(Vector3(5.0, 1.35, 2.15), Vector3(0.0, 1.25, 0.0), Color(0.92, 0.68, 0.08))
	_add_box(Vector3(3.45, 1.15, 2.05), Vector3(-0.15, 2.35, 0.0), Color(0.90, 0.65, 0.06))
	_add_box(Vector3(3.65, 0.10, 2.18), Vector3(-0.15, 2.98, 0.0), Color(0.16, 0.17, 0.16))
	for side in [-1.0, 1.0]:
		_add_box(Vector3(2.8, 0.72, 0.045), Vector3(-0.18, 2.42, side * 1.045), Color(0.10, 0.20, 0.25))
		_add_box(Vector3(0.10, 0.72, 0.045), Vector3(-1.75, 2.42, side * 1.045), Color(0.10, 0.20, 0.25))
		_add_box(Vector3(0.10, 0.72, 0.045), Vector3(1.35, 2.42, side * 1.045), Color(0.10, 0.20, 0.25))
	_add_box(Vector3(0.06, 0.78, 1.75), Vector3(2.52, 2.38, 0.0), Color(0.10, 0.20, 0.25))
	_add_box(Vector3(0.18, 0.20, 2.25), Vector3(2.55, 0.72, 0.0), Color(0.12, 0.12, 0.12))
	_add_box(Vector3(0.18, 0.20, 2.25), Vector3(-2.55, 0.72, 0.0), Color(0.12, 0.12, 0.12))
	for x in [-1.65, 1.65]:
		for side in [-1.0, 1.0]:
			_add_wheel(Vector3(x, 0.48, side * 1.05), 0.48, 0.24, Color(0.07, 0.07, 0.07))
			_add_wheel(Vector3(x, 0.48, side * 1.05), 0.22, 0.25, Color(0.55, 0.56, 0.54))
	var route_label := Label3D.new()
	route_label.text = "LAGOS  |  DANFO"
	route_label.font_size = 24
	route_label.outline_size = 5
	route_label.position = Vector3(0.0, 1.8, -1.11)
	route_label.rotation.y = PI
	add_child(route_label)

func _add_box(box_size: Vector3, box_position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = box_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_wheel(wheel_position: Vector3, radius: float, width: float, color: Color) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	wheel.mesh = mesh
	wheel.position = wheel_position
	wheel.rotation.z = PI * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	wheel.material_override = material
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
	player.camera_pivot.reparent(self, false)
	player.camera_pivot.position = Vector3(0.0, 3.2, 6.8)
	player.camera_pivot.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	player.camera.position = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO

func _find_safe_exit_position(player: Node) -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
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
	player.camera_pivot.reparent(player, false)
	player.camera_pivot.position = Vector3(0.0, 1.72, 0.0)
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera.position = Vector3(0.0, 2.15, 7.2)
	player.camera.rotation.x = deg_to_rad(-14.0)
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
