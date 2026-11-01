extends CharacterBody3D
class_name PlayerController

const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const JUMP_VELOCITY: float = 5.5
const MOUSE_SENSITIVITY: float = 0.0025
const GRAVITY: float = 18.0
const WORLD_COLLISION_LAYER: int = 1
const VEHICLE_COLLISION_LAYER: int = 2
const PLAYER_COLLISION_LAYER: int = 4
const NPC_COLLISION_LAYER: int = 8
const MIN_CAMERA_PITCH: float = deg_to_rad(-55.0)
const MAX_CAMERA_PITCH: float = deg_to_rad(35.0)

var camera_pivot: SpringArm3D
var camera: Camera3D
var body_mesh: MeshInstance3D
var mouse_captured: bool = false
var mobile_controls: Node
var jump_requested: bool = false
var interact_requested: bool = false
var _left_arm_pivot: Node3D
var _right_arm_pivot: Node3D
var _left_leg_pivot: Node3D
var _right_leg_pivot: Node3D
var _animation_clock: float = 0.0

static func normalize_move_input(input_vector: Vector2) -> Vector2:
	return input_vector.limit_length(1.0)

static func clamp_camera_pitch(pitch: float) -> float:
	return clampf(pitch, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)

func _ready() -> void:
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_LAYER | VEHICLE_COLLISION_LAYER | NPC_COLLISION_LAYER
	floor_snap_length = 0.35
	safe_margin = 0.04
	max_slides = 8
	floor_stop_on_slope = true
	_build_body()
	if not OS.has_feature("mobile"):
		_capture_mouse()

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	# A lightweight stylised human rig made from low-poly primitives.
	# The visual root is hidden while the player is seated in a vehicle.
	body_mesh = MeshInstance3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = 0.29
	torso.height = 0.92
	body_mesh.mesh = torso
	body_mesh.position.y = 1.08
	body_mesh.material_override = _character_material(Color(0.12, 0.38, 0.34))
	add_child(body_mesh)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.72, 0.0)
	head.material_override = _character_material(Color(0.38, 0.22, 0.14))
	body_mesh.add_child(head)

	_left_arm_pivot = _create_limb(Vector3(-0.34, 0.28, 0.0), 0.12, 0.76, Color(0.38, 0.22, 0.14))
	_right_arm_pivot = _create_limb(Vector3(0.34, 0.28, 0.0), 0.12, 0.76, Color(0.38, 0.22, 0.14))
	_left_leg_pivot = _create_limb(Vector3(-0.16, -0.32, 0.0), 0.15, 0.82, Color(0.10, 0.12, 0.14))
	_right_leg_pivot = _create_limb(Vector3(0.16, -0.32, 0.0), 0.15, 0.82, Color(0.10, 0.12, 0.14))

	# SpringArm3D keeps the third-person camera outside mapped walls and vehicles.
	camera_pivot = SpringArm3D.new()
	camera_pivot.position.y = 1.72
	camera_pivot.rotation = Vector3(deg_to_rad(-14.0), PI, 0.0)
	camera_pivot.spring_length = 7.2
	camera_pivot.collision_mask = WORLD_COLLISION_LAYER
	camera_pivot.margin = 0.2
	var camera_probe := SphereShape3D.new()
	camera_probe.radius = 0.28
	camera_pivot.shape = camera_probe
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3.ZERO
	camera.rotation = Vector3(0.0, PI, 0.0)
	camera.fov = 76.0
	camera.current = true
	camera.far = 220.0
	camera_pivot.add_child(camera)

func _character_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _create_limb(limb_position: Vector3, radius: float, height: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = limb_position
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh_instance.mesh = capsule
	mesh_instance.position.y = -height * 0.38
	mesh_instance.material_override = _character_material(color)
	pivot.add_child(mesh_instance)
	body_mesh.add_child(pivot)
	return pivot

func _update_character_animation(delta: float) -> void:
	_animation_clock += delta
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var swing := sin(_animation_clock * 9.0) * 0.48 if horizontal_speed > 0.35 else 0.0
	_left_leg_pivot.rotation.x = swing
	_right_leg_pivot.rotation.x = -swing
	_left_arm_pivot.rotation.x = -swing * 0.65
	_right_arm_pivot.rotation.x = swing * 0.65

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	input_vector.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input_vector.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))

	if mobile_controls != null:
		input_vector += mobile_controls.get_move_vector()
	input_vector = normalize_move_input(input_vector)

	var move_direction := Vector3.ZERO
	if input_vector.length_squared() > 0.0:
		var basis := camera_pivot.global_transform.basis
		var forward := -basis.z
		var right := basis.x
		move_direction = right * input_vector.x + forward * -input_vector.y
		move_direction.y = 0.0
		move_direction = move_direction.normalized()

	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	if mobile_controls != null:
		sprinting = sprinting or mobile_controls.is_sprint_pressed()
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed

	var wants_jump := jump_requested
	jump_requested = false
	if mobile_controls != null:
		wants_jump = wants_jump or mobile_controls.consume_jump_request()

	var nearby_vehicle := _get_nearest_vehicle()
	if nearby_vehicle != null and (interact_requested or wants_jump):
		interact_requested = false
		nearby_vehicle.enter_vehicle(self)
		return
	interact_requested = false

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif wants_jump:
		velocity.y = JUMP_VELOCITY

	if mobile_controls != null:
		_apply_look_delta(mobile_controls.consume_look_delta())

	move_and_slide()
	_update_character_animation(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		_apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_mouse_capture()
		elif event.keycode == KEY_SPACE:
			jump_requested = true
		elif event.keycode == KEY_E:
			interact_requested = true

func _get_nearest_vehicle() -> Node3D:
	var nearest: Node3D
	var nearest_distance := 7.0
	for candidate in get_tree().get_nodes_in_group("drivable_vehicle"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance >= nearest_distance:
			continue
		# Interaction is blocked by solid walls and other world geometry.
		var ray_query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP,
			candidate.global_position + Vector3.UP,
			WORLD_COLLISION_LAYER | VEHICLE_COLLISION_LAYER,
			[get_rid()]
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray_query)
		if not hit.is_empty() and hit.get("collider") != candidate:
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest

func _apply_look_delta(look_delta: Vector2) -> void:
	if look_delta.is_zero_approx():
		return
	camera_pivot.rotate_y(-look_delta.x * MOUSE_SENSITIVITY)
	camera_pivot.rotation.x = clamp_camera_pitch(
		camera_pivot.rotation.x - look_delta.y * MOUSE_SENSITIVITY
	)

func _capture_mouse() -> void:
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _toggle_mouse_capture() -> void:
	mouse_captured = not mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
