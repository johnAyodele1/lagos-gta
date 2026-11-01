extends Node3D
class_name TrafficManager

## Lightweight ambient traffic for the Yaba starter district.
## Vehicles are visual-only: no per-car physics bodies or navigation agents.
## This keeps background traffic cheap on entry-level Android devices.

const ROAD_HALF_LENGTH := 60.0
const LOOP_LENGTH := ROAD_HALF_LENGTH * 2.0
const LANE_OFFSET := 3.1
const VEHICLE_COUNT_PER_LANE := 2
const VEHICLE_SPACING := LOOP_LENGTH / float(VEHICLE_COUNT_PER_LANE)

const BODY_COLORS: Array[Color] = [
	Color(0.88, 0.72, 0.10), # danfo yellow
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

static func advance_distance(distance: float, speed: float, delta: float, loop_length: float = LOOP_LENGTH) -> float:
	if loop_length <= 0.0:
		return 0.0
	return fposmod(distance + maxf(speed, 0.0) * maxf(delta, 0.0), loop_length)

func _ready() -> void:
	_spawn_lane(Vector3.LEFT, -LANE_OFFSET)
	_spawn_lane(Vector3.RIGHT, LANE_OFFSET)
	_spawn_lane(Vector3.FORWARD, -LANE_OFFSET)
	_spawn_lane(Vector3.BACK, LANE_OFFSET)

func _process(delta: float) -> void:
	for traffic_item in _traffic:
		var distance := advance_distance(
			float(traffic_item["distance"]),
			float(traffic_item["speed"]),
			delta
		)
		traffic_item["distance"] = distance
		var vehicle := traffic_item["node"] as Node3D
		var direction: Vector3 = traffic_item["direction"]
		var lane_offset: float = traffic_item["lane_offset"]
		if direction.x != 0.0:
			vehicle.position = Vector3(-ROAD_HALF_LENGTH + distance, 0.0, lane_offset)
		else:
			vehicle.position = Vector3(lane_offset, 0.0, -ROAD_HALF_LENGTH + distance)
		vehicle.look_at(vehicle.position + direction, Vector3.UP)

func _spawn_lane(direction: Vector3, lane_offset: float) -> void:
	for index in range(VEHICLE_COUNT_PER_LANE):
		var traffic_index := _traffic.size()
		var vehicle := _build_vehicle(BODY_COLORS[traffic_index % BODY_COLORS.size()])
		vehicle.name = "AmbientTraffic_%02d" % traffic_index
		add_child(vehicle)
		var distance := float(index) * VEHICLE_SPACING + float(traffic_index % 3) * 2.5
		_traffic.append({
			"node": vehicle,
			"direction": direction,
			"lane_offset": lane_offset,
			"distance": distance,
			"speed": TRAFFIC_SPEEDS[traffic_index % TRAFFIC_SPEEDS.size()]
		})

func _build_vehicle(body_color: Color) -> Node3D:
	var vehicle := Node3D.new()
	var body_material := _material(body_color)
	var glass_material := _material(Color(0.08, 0.16, 0.19))
	var tyre_material := _material(Color(0.035, 0.035, 0.035))
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.85, 0.85, 3.7)
	body.mesh = body_mesh
	body.position.y = 0.82
	body.material_override = body_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vehicle.add_child(body)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.55, 0.68, 1.9)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 1.53, 0.05)
	cabin.material_override = glass_material
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vehicle.add_child(cabin)

	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.34
			wheel_mesh.bottom_radius = 0.34
			wheel_mesh.height = 0.18
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(x_side * 0.94, 0.42, z_side * 1.15)
			wheel.rotation.z = PI * 0.5
			wheel.material_override = tyre_material
			wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vehicle.add_child(wheel)

	return vehicle

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

func get_traffic_count() -> int:
	return _traffic.size()

func get_traffic_distance(index: int) -> float:
	if index < 0 or index >= _traffic.size():
		return -1.0
	return float(_traffic[index]["distance"])
