extends CharacterBody3D
class_name PlayerController

const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const JUMP_VELOCITY: float = 5.5
const MOUSE_SENSITIVITY: float = 0.0025
const GRAVITY: float = 18.0
const MIN_CAMERA_PITCH: float = deg_to_rad(-55.0)
const MAX_CAMERA_PITCH: float = deg_to_rad(35.0)

var camera_pivot: Node3D
var camera: Camera3D
var body_mesh: MeshInstance3D
var mouse_captured: bool = false
var mobile_controls: Node
var jump_requested: bool = false
var interact_requested: bool = false

static func normalize_move_input(input_vector: Vector2) -> Vector2:
	return input_vector.limit_length(1.0)

static func clamp_camera_pitch(pitch: float) -> float:
	return clampf(pitch, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)

func _ready() -> void:
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

	body_mesh = MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.38
	capsule_mesh.height = 1.8
	body_mesh.mesh = capsule_mesh
	body_mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.32, 0.72)
	material.roughness = 0.85
	body_mesh.material_override = material
	add_child(body_mesh)

	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.55
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.35, 4.8)
	camera.rotation.x = deg_to_rad(-9.0)
	camera.current = true
	camera.far = 180.0
	camera_pivot.add_child(camera)

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
		if distance < nearest_distance:
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
