extends Node3D
class_name PedestrianManager

## Small visual-only pedestrian population for the starter district.
## Four shared MultiMeshes animate a capped crowd without per-person physics.

const HALF_ROUTE_LENGTH := 55.0
const ROUTE_LENGTH := HALF_ROUTE_LENGTH * 2.0
const WALKER_COUNT := 4

const CLOTHING_COLORS: Array[Color] = [
	Color(0.16, 0.30, 0.62),
	Color(0.62, 0.22, 0.14),
	Color(0.16, 0.42, 0.28),
	Color(0.68, 0.48, 0.16)
]
const SKIN_COLORS: Array[Color] = [
	Color(0.48, 0.29, 0.19),
	Color(0.68, 0.43, 0.30),
	Color(0.34, 0.20, 0.14),
	Color(0.76, 0.54, 0.39)
]

var _walkers: Array[Dictionary] = []
var _torso_batch: MultiMeshInstance3D
var _head_batch: MultiMeshInstance3D
var _arm_batch: MultiMeshInstance3D
var _leg_batch: MultiMeshInstance3D
var _elapsed := 0.0

static func advance_distance(distance: float, speed: float, delta: float, route_length: float = ROUTE_LENGTH) -> float:
	if route_length <= 0.0:
		return 0.0
	return fposmod(distance + maxf(speed, 0.0) * maxf(delta, 0.0), route_length)

func _ready() -> void:
	_create_batches()
	_walkers = [
		{"direction": Vector3.BACK, "lane_offset": -10.5, "distance": 8.0, "speed": 1.15, "phase": 0.0},
		{"direction": Vector3.FORWARD, "lane_offset": 10.5, "distance": 35.0, "speed": 0.95, "phase": 1.4},
		{"direction": Vector3.RIGHT, "lane_offset": -10.5, "distance": 62.0, "speed": 1.05, "phase": 2.8},
		{"direction": Vector3.LEFT, "lane_offset": 10.5, "distance": 88.0, "speed": 1.2, "phase": 4.2}
	]
	_update_batches()

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	for walker in _walkers:
		walker["distance"] = advance_distance(
			float(walker["distance"]),
			float(walker["speed"]),
			delta
		)
	_update_batches()

func _create_batches() -> void:
	var torso := BoxMesh.new()
	torso.size = Vector3(0.52, 0.9, 0.32)
	_torso_batch = _create_batch(torso, _material(), WALKER_COUNT)

	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	head.radial_segments = 8
	head.rings = 4
	_head_batch = _create_batch(head, _material(), WALKER_COUNT)

	var limb := BoxMesh.new()
	limb.size = Vector3(0.15, 0.62, 0.16)
	_arm_batch = _create_batch(limb, _material(), WALKER_COUNT * 2)
	_leg_batch = _create_batch(limb, _material(), WALKER_COUNT * 2)

func _create_batch(mesh: Mesh, material: StandardMaterial3D, count: int) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = instances
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return batch

func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	return material

func _update_batches() -> void:
	for index in range(_walkers.size()):
		var walker: Dictionary = _walkers[index]
		var direction: Vector3 = walker["direction"]
		var lane_offset := float(walker["lane_offset"])
		var distance := float(walker["distance"])
		var position := Vector3.ZERO
		if direction.x != 0.0:
			position = Vector3(-HALF_ROUTE_LENGTH + distance if direction.x > 0.0 else HALF_ROUTE_LENGTH - distance, 0.0, lane_offset)
		else:
			position = Vector3(lane_offset, 0.0, -HALF_ROUTE_LENGTH + distance if direction.z > 0.0 else HALF_ROUTE_LENGTH - distance)

		var basis := Basis.looking_at(direction, Vector3.UP)
		var phase := float(walker["phase"])
		var stride := sin(_elapsed * 6.0 + phase) * 0.24
		var torso_transform := Transform3D(basis, position + Vector3.UP * 1.0)
		var head_transform := Transform3D(basis, position + Vector3.UP * 1.72)
		_torso_batch.multimesh.set_instance_transform(index, torso_transform)
		_torso_batch.multimesh.set_instance_color(index, CLOTHING_COLORS[index % CLOTHING_COLORS.size()])
		_head_batch.multimesh.set_instance_transform(index, head_transform)
		_head_batch.multimesh.set_instance_color(index, SKIN_COLORS[index % SKIN_COLORS.size()])

		for side_index in range(2):
			var side := -1.0 if side_index == 0 else 1.0
			var limb_index := index * 2 + side_index
			var arm_angle := stride * side
			var leg_angle := -stride * side
			var arm_basis := basis * Basis(Vector3.RIGHT, arm_angle)
			var leg_basis := basis * Basis(Vector3.RIGHT, leg_angle)
			var arm_origin := position + basis * Vector3(side * 0.37, 1.12, 0.0)
			var leg_origin := position + basis * Vector3(side * 0.15, 0.43, 0.0)
			_arm_batch.multimesh.set_instance_transform(limb_index, Transform3D(arm_basis, arm_origin))
			_arm_batch.multimesh.set_instance_color(limb_index, CLOTHING_COLORS[index % CLOTHING_COLORS.size()])
			_leg_batch.multimesh.set_instance_transform(limb_index, Transform3D(leg_basis, leg_origin))
			_leg_batch.multimesh.set_instance_color(limb_index, Color(0.12, 0.12, 0.13))

func get_pedestrian_count() -> int:
	return _walkers.size()

func get_pedestrian_distance(index: int) -> float:
	if index < 0 or index >= _walkers.size():
		return -1.0
	return float(_walkers[index]["distance"])

func get_pedestrian_position(index: int) -> Vector3:
	if index < 0 or index >= _walkers.size():
		return Vector3.ZERO
	return _torso_batch.multimesh.get_instance_transform(index).origin
