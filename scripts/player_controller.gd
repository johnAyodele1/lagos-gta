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
const CharacterMeshFactoryScript = preload("res://scripts/character_mesh_factory.gd")
const ModelBoundsScript = preload("res://scripts/model_bounds.gd")
const RIGGED_PLAYER_SCENE = preload("res://assets/models/characters/lagos_player.glb")
const MIN_CAMERA_PITCH: float = deg_to_rad(-55.0)
const MAX_CAMERA_PITCH: float = deg_to_rad(35.0)

var camera_yaw_pivot: Node3D
var camera_pivot: SpringArm3D
var camera: Camera3D
var body_mesh: MeshInstance3D
var _rigged_character: Node3D
var _rigged_animation_player: AnimationPlayer
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
	capsule.radius = 0.32
	capsule.height = 1.78
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	if DisplayServer.get_name() == "headless":
		body_mesh = null
		_build_camera_rig()
		return

	# A custom tapered torso, layered clothing, face, hair and articulated limbs.
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "PlayerCharacterVisual"
	body_mesh.mesh = CharacterMeshFactoryScript.create_torso_mesh()
	body_mesh.position.y = 1.08
	body_mesh.material_override = _character_material(Color(0.10, 0.34, 0.38))
	if body_mesh.mesh != null and body_mesh.mesh.get_surface_count() > 0:
		body_mesh.mesh.surface_set_material(0, body_mesh.material_override)
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body_mesh)
	if _try_attach_rigged_character():
		_build_camera_rig()
		return

	var neck := MeshInstance3D.new()
	var neck_mesh := CapsuleMesh.new()
	neck_mesh.radius = 0.09
	neck_mesh.height = 0.24
	neck.mesh = neck_mesh
	neck.position = Vector3(0.0, 0.43, 0.0)
	neck.material_override = _character_material(Color(0.40, 0.25, 0.17))
	body_mesh.add_child(neck)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.46
	head_mesh.radial_segments = 16
	head_mesh.rings = 10
	head.mesh = head_mesh
	head.scale = Vector3(0.9, 1.0, 0.88)
	head.position = Vector3(0.0, 0.66, 0.0)
	head.material_override = _character_material(Color(0.40, 0.24, 0.16))
	body_mesh.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.225
	hair_mesh.height = 0.24
	hair_mesh.radial_segments = 12
	hair_mesh.rings = 6
	hair.mesh = hair_mesh
	hair.scale = Vector3(1.0, 0.72, 0.94)
	hair.position = Vector3(0.0, 0.80, 0.005)
	hair.material_override = _character_material(Color(0.035, 0.028, 0.022))
	body_mesh.add_child(hair)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.035
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.075, 0.67, -0.185)
		eye.material_override = _character_material(Color(0.025, 0.022, 0.018))
		body_mesh.add_child(eye)
		var ear := MeshInstance3D.new()
		var ear_mesh := SphereMesh.new()
		ear_mesh.radius = 0.055
		ear_mesh.height = 0.09
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.205, 0.63, 0.0)
		ear.material_override = _character_material(Color(0.38, 0.22, 0.15))
		body_mesh.add_child(ear)

	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.045
	nose_mesh.height = 0.085
	nose.mesh = nose_mesh
	nose.scale = Vector3(0.78, 1.0, 0.78)
	nose.position = Vector3(0.0, 0.58, -0.215)
	nose.material_override = _character_material(Color(0.42, 0.25, 0.17))
	body_mesh.add_child(nose)

	var mouth := MeshInstance3D.new()
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(0.075, 0.018, 0.018)
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0.0, 0.50, -0.195)
	mouth.material_override = _character_material(Color(0.10, 0.035, 0.025))
	body_mesh.add_child(mouth)

	var shirt_pocket := MeshInstance3D.new()
	var pocket_mesh := BoxMesh.new()
	pocket_mesh.size = Vector3(0.10, 0.13, 0.025)
	shirt_pocket.mesh = pocket_mesh
	shirt_pocket.position = Vector3(-0.15, 0.16, -0.155)
	shirt_pocket.material_override = _character_material(Color(0.07, 0.25, 0.29))
	body_mesh.add_child(shirt_pocket)

	var belt := MeshInstance3D.new()
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(0.46, 0.075, 0.28)
	belt.mesh = belt_mesh
	belt.position = Vector3(0.0, -0.28, 0.0)
	belt.material_override = _character_material(Color(0.07, 0.055, 0.045))
	body_mesh.add_child(belt)

	_left_arm_pivot = _create_arm(Vector3(-0.34, 0.28, 0.0))
	_right_arm_pivot = _create_arm(Vector3(0.34, 0.28, 0.0))
	_left_leg_pivot = _create_leg(Vector3(-0.16, -0.36, 0.0))
	_right_leg_pivot = _create_leg(Vector3(0.16, -0.36, 0.0))

	_build_camera_rig()

func _try_attach_rigged_character() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var model_scene := RIGGED_PLAYER_SCENE as PackedScene
	if model_scene == null:
		push_warning("Rigged player model could not be loaded; using the lightweight fallback rig.")
		return false
	_rigged_character = model_scene.instantiate() as Node3D
	if _rigged_character == null:
		push_warning("Rigged player scene has no Node3D root; using the lightweight fallback rig.")
		return false
	_rigged_character.name = "RiggedLagosPlayer"
	body_mesh.mesh = null
	body_mesh.position = Vector3.ZERO
	body_mesh.add_child(_rigged_character)
	_rigged_animation_player = _rigged_character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_apply_rigged_character_materials(_rigged_character, Color(0.10, 0.34, 0.38), Color(0.40, 0.25, 0.17), Color(0.085, 0.10, 0.13))
	call_deferred("_fit_rigged_character_dimensions")
	if _rigged_animation_player != null and _rigged_animation_player.has_animation("HumanArmature|Man_Idle"):
		_rigged_animation_player.play("HumanArmature|Man_Idle")
	return true

func _fit_rigged_character_dimensions() -> void:
	if _rigged_character != null and is_instance_valid(_rigged_character):
		if not ModelBoundsScript.fit_height(_rigged_character, 1.76):
			push_warning("Player model could not be fitted to the 1.76m character scale.")

func _apply_rigged_character_materials(model: Node3D, shirt_color: Color, skin_color: Color, pants_color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var palette: Array[Color] = [
		shirt_color, shirt_color, skin_color, pants_color,
		Color(0.025, 0.025, 0.025), Color(0.28, 0.27, 0.25),
		Color(0.025, 0.022, 0.018), Color(0.025, 0.022, 0.018), Color(0.015, 0.012, 0.01)
	]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var first_surface_material: StandardMaterial3D
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := StandardMaterial3D.new()
			material.albedo_color = palette[mini(surface_index, palette.size() - 1)]
			material.roughness = 0.88
			mesh_instance.set_surface_override_material(surface_index, material)
			if surface_index == 0:
				first_surface_material = material
		# Imported GLBs can contain empty source material slots. Keep a valid
		# instance-level fallback as well as the per-surface palette.
		if first_surface_material != null:
			mesh_instance.material_override = first_surface_material


func _build_camera_rig() -> void:
	# SpringArm3D keeps the third-person camera outside mapped walls and vehicles.
	camera_yaw_pivot = Node3D.new()
	camera_yaw_pivot.name = "CameraYawPivot"
	camera_yaw_pivot.position.y = 1.72
	add_child(camera_yaw_pivot)

	camera_pivot = SpringArm3D.new()
	camera_pivot.name = "ThirdPersonSpringArm"
	camera_pivot.position = Vector3.ZERO
	camera_pivot.rotation = Vector3.ZERO
	camera_pivot.spring_length = 7.2
	camera_pivot.collision_mask = WORLD_COLLISION_LAYER
	camera_pivot.margin = 0.2
	var camera_probe := SphereShape3D.new()
	camera_probe.radius = 0.28
	camera_pivot.shape = camera_probe
	camera_yaw_pivot.add_child(camera_pivot)
	camera_pivot.add_excluded_object(get_rid())

	camera = Camera3D.new()
	camera.position = Vector3.ZERO
	camera.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	camera.fov = 76.0
	camera.current = true
	camera.far = 220.0
	camera_pivot.add_child(camera)

func _character_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

func _create_arm(limb_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = limb_position
	var upper := MeshInstance3D.new()
	var upper_mesh := CapsuleMesh.new()
	upper_mesh.radius = 0.12
	upper_mesh.height = 0.56
	upper_mesh.radial_segments = 8
	upper.mesh = upper_mesh
	upper.position.y = -0.22
	upper.material_override = _character_material(Color(0.10, 0.34, 0.38))
	pivot.add_child(upper)

	var forearm := MeshInstance3D.new()
	var forearm_mesh := CapsuleMesh.new()
	forearm_mesh.radius = 0.09
	forearm_mesh.height = 0.42
	forearm_mesh.radial_segments = 8
	forearm.mesh = forearm_mesh
	forearm.position.y = -0.66
	forearm.material_override = _character_material(Color(0.40, 0.24, 0.16))
	pivot.add_child(forearm)

	var hand := MeshInstance3D.new()
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.09
	hand_mesh.height = 0.16
	hand.mesh = hand_mesh
	hand.position.y = -0.91
	hand.material_override = _character_material(Color(0.40, 0.24, 0.16))
	pivot.add_child(hand)
	body_mesh.add_child(pivot)
	return pivot

func _create_leg(limb_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = limb_position
	var trousers := MeshInstance3D.new()
	var trouser_mesh := CapsuleMesh.new()
	trouser_mesh.radius = 0.135
	trouser_mesh.height = 0.78
	trouser_mesh.radial_segments = 8
	trousers.mesh = trouser_mesh
	trousers.position.y = -0.34
	trousers.material_override = _character_material(Color(0.085, 0.10, 0.13))
	pivot.add_child(trousers)

	var shoe := MeshInstance3D.new()
	var shoe_mesh := SphereMesh.new()
	shoe_mesh.radius = 0.16
	shoe_mesh.height = 0.20
	shoe.mesh = shoe_mesh
	shoe.scale = Vector3(1.0, 0.65, 1.45)
	shoe.position = Vector3(0.0, -0.72, -0.055)
	shoe.material_override = _character_material(Color(0.035, 0.035, 0.032))
	pivot.add_child(shoe)
	body_mesh.add_child(pivot)
	return pivot

func set_character_visual_visible(visible: bool) -> void:
	if body_mesh != null:
		body_mesh.visible = visible
	if is_instance_valid(_rigged_character):
		_rigged_character.visible = visible

func _update_character_animation(delta: float) -> void:
	_animation_clock += delta
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_instance_valid(_rigged_animation_player):
		var animation_name := "HumanArmature|Man_Idle"
		if not is_on_floor() and absf(velocity.y) > 0.1:
			animation_name = "HumanArmature|Man_Jump"
		elif horizontal_speed > 0.35:
			animation_name = "HumanArmature|Man_Run" if horizontal_speed > WALK_SPEED * 1.15 else "HumanArmature|Man_Walk"
		if _rigged_animation_player.has_animation(animation_name):
			if _rigged_animation_player.current_animation != animation_name:
				_rigged_animation_player.play(animation_name, 0.16)
			_rigged_animation_player.speed_scale = clampf(horizontal_speed / WALK_SPEED, 0.85, 1.25) if horizontal_speed > 0.35 else 1.0
		return
	if _left_leg_pivot == null or _right_leg_pivot == null or _left_arm_pivot == null or _right_arm_pivot == null:
		return
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
	camera_yaw_pivot.rotate_y(-look_delta.x * MOUSE_SENSITIVITY)
	camera.rotation.x = clamp_camera_pitch(
		camera.rotation.x - look_delta.y * MOUSE_SENSITIVITY
	)

func _capture_mouse() -> void:
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _toggle_mouse_capture() -> void:
	mouse_captured = not mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
