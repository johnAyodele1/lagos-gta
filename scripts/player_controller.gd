extends CharacterBody3D
class_name PlayerController

const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const JUMP_VELOCITY: float = 5.5
const MOUSE_SENSITIVITY: float = 0.0025
const GRAVITY: float = 18.0

var camera_pivot: Node3D
var camera: Camera3D
var mouse_captured: bool = false

func _ready() -> void:
	_build_body()
	_capture_mouse()

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	var body_mesh := MeshInstance3D.new()
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
	camera_pivot.add_child(camera)

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	input_vector.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	input_vector.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	input_vector = input_vector.normalized()

	var move_direction := Vector3.ZERO
	if input_vector.length_squared() > 0.0:
		var basis := camera_pivot.global_transform.basis
		var forward := -basis.z
		var right := basis.x
		move_direction = right * input_vector.x + forward * -input_vector.y
		move_direction.y = 0.0
		move_direction = move_direction.normalized()

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = JUMP_VELOCITY

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-55.0), deg_to_rad(35.0))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_mouse_capture()

func _capture_mouse() -> void:
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _toggle_mouse_capture() -> void:
	mouse_captured = not mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
