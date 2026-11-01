extends Node3D
class_name TrafficManager

## Lightweight ambient traffic for the Yaba starter district.
## Three MultiMeshes draw all background vehicles; no per-car physics bodies,
## navigation agents or individual render nodes are created.

const ROAD_HALF_LENGTH := 60.0
const LOOP_LENGTH := ROAD_HALF_LENGTH * 2.0
const LANE_OFFSET := 3.1
const VEHICLE_COUNT_PER_LANE := 2
const VEHICLE_SPACING := LOOP_LENGTH / float(VEHICLE_COUNT_PER_LANE)

const BODY_COLORS: Array[Color] = [
	Color(0.88, 0.72, 0.10),
	Color(0.12, 0.30, 0.52),
	Color(0.72, 0.72, 0.68),
	Color(0.18, 0.20, 0.19),
	Color(0.58, 0.18, 0.12),
	Color(0.12, 0.42, 0.28),
	Color(0.82, 0.80, 0.72),
	Color(0.16, 0.18, 0.24)
]
const TRAFFIC_SPEEDS: Array[float] = [8.0, 9.5, 7.0, 10.0, 8.5, 7.5, 9.0, 8.0]

var _traffic: Array[Dictionary] = []
var _body_batch: MultiMeshInstance3D
var _cabin_batch: MultiMeshInstance3D
var _wheel_batch: MultiMeshInstance3D

static func advance_distance(distance: float, speed: float, delta: float, loop_length: float = LOOP_LENGTH) -> float:
	if loop_length <= 0.0:
		return 0.0
	return fposmod(distance + maxf(speed, 0.0) * maxf(delta, 0.0), loop_length)

func _ready() -> void:
	_create_render_batches()
	_spawn_lane(Vector3.BACK, -LANE_OFFSET)
	_spawn_lane(Vector3.FORWARD, LANE_OFFSET)
	_spawn_lane(Vector3.RIGHT, -LANE_OFFSET)
	_spawn_lane(Vector3.LEFT, LANE_OFFSET)
	_update_render_batches()

func _process(delta: float) -> void:
	for traffic_item in _traffic:
		traffic_item["distance"] = advance_distance(
			float(traffic_item["distance"]),
			float(traffic_item["speed"]),
			delta
		)
	_update_render_batches()

func _create_render_batches() -> void:
	_body_batch = _create_batch(Vector3(1.85, 0.85, 3.7), _material())
	_cabin_batch = _create_batch(Vector3(1.55, 0.68, 1.9), _material())
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.34
	wheel_mesh.bottom_radius = 0.34
	wheel_mesh.height = 0.18
	_wheel_batch = _create_batch_from_mesh(wheel_mesh, _material())

func _create_batch(box_size: Vector3, material: StandardMaterial3D) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = box_size
	return _create_batch_from_mesh(box, material)

func _create_batch_from_mesh(mesh: Mesh, material: StandardMaterial3D) -> MultiMeshInstance3D:
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = BODY_COLORS.size()
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multi_mesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return batch

func _spawn_lane(direction: Vector3, lane_offset: float) -> void:
	for index in range(VEHICLE_COUNT_PER_LANE):
		var traffic_index := _traffic.size()
		_traffic.append({
			"direction": direction,
			"lane_offset": lane_offset,
			"distance": float(index) * VEHICLE_SPACING + float(traffic_index % 3) * 2.5,
			"speed": TRAFFIC_SPEEDS[traffic_index % TRAFFIC_SPEEDS.size()]
		})

func _update_render_batches() -> void:
	for index in range(_traffic.size()):
		var item: Dictionary = _traffic[index]
		var direction: Vector3 = item["direction"]
		var lane_offset: float = float(item["lane_offset"])
		var distance: float = float(item["distance"])
		var position := Vector3.ZERO
		if direction.x != 0.0:
			position = Vector3(-ROAD_HALF_LENGTH + distance if direction.x > 0.0 else ROAD_HALF_LENGTH - distance, 0.0, lane_offset)
		else:
			position = Vector3(lane_offset, 0.0, -ROAD_HALF_LENGTH + distance if direction.z > 0.0 else ROAD_HALF_LENGTH - distance)
		var vehicle_basis := Basis.looking_at(direction, Vector3.UP)
		var vehicle_transform := Transform3D(vehicle_basis, position)
		var tint: Color = BODY_COLORS[index % BODY_COLORS.size()]
		_body_batch.multimesh.set_instance_transform(index, vehicle_transform * Transform3D(Basis(), Vector3(0.0, 0.82, 0.0)))
		_body_batch.multimesh.set_instance_color(index, tint)
		_cabin_batch.multimesh.set_instance_transform(index, vehicle_transform * Transform3D(Basis(), Vector3(0.0, 1.53, 0.05)))
		_cabin_batch.multimesh.set_instance_color(index, Color(0.08, 0.16, 0.19))
		for wheel_index in range(4):
			var x_side := -1.0 if wheel_index < 2 else 1.0
			var z_side := -1.0 if wheel_index % 2 == 0 else 1.0
			var wheel_local := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x_side * 0.94, 0.42, z_side * 1.15))
			var instance_index := index * 4 + wheel_index
			_wheel_batch.multimesh.set_instance_transform(instance_index, vehicle_transform * wheel_local)
			_wheel_batch.multimesh.set_instance_color(instance_index, Color(0.035, 0.035, 0.035))

func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.82
	return material

func get_traffic_count() -> int:
	return _traffic.size()

func get_traffic_distance(index: int) -> float:
	if index < 0 or index >= _traffic.size():
		return -1.0
	return float(_traffic[index]["distance"])

func get_traffic_position(index: int) -> Vector3:
	if index < 0 or index >= _traffic.size():
		return Vector3.ZERO
	return _body_batch.multimesh.get_instance_transform(index).origin
