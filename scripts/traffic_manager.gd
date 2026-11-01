extends Node3D
class_name TrafficManager

## Small ambient traffic pool driven by real OSM road centre-lines.
## Vehicle meshes are shared tapered 3D lofts; each moving car has one cheap collider.

const MAX_TRAFFIC_VEHICLES := 8
const MAX_SOURCE_ROADS := 4
const VEHICLES_PER_ROUTE := 2
const WORLD_COLLISION_LAYER: int = 1
const VEHICLE_COLLISION_LAYER: int = 2
const PLAYER_COLLISION_LAYER: int = 4
const NPC_COLLISION_LAYER: int = 8

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

var _routes: Array[Dictionary] = []
var _traffic: Array[Dictionary] = []
var _body_batch: MultiMeshInstance3D
var _cabin_batch: MultiMeshInstance3D
var _wheel_batch: MultiMeshInstance3D
var _window_batch: MultiMeshInstance3D
var _light_batch: MultiMeshInstance3D
var _collision_bodies: Array[AnimatableBody3D] = []
var _last_directions: Array[Vector3] = []

static func advance_distance(distance: float, speed: float, delta: float, loop_length: float = 120.0) -> float:
	if loop_length <= 0.0:
		return 0.0
	return fposmod(distance + maxf(speed, 0.0) * maxf(delta, 0.0), loop_length)

func configure_from_roads(roads: Array[Dictionary]) -> void:
	_routes = _build_routes(roads)

func _ready() -> void:
	_create_render_batches()
	if _routes.is_empty():
		push_warning("Ambient traffic is disabled because no usable OSM road routes were supplied.")
		return
	_spawn_traffic()
	_create_collision_proxies()
	_update_render_batches()

func _process(delta: float) -> void:
	for traffic_item in _traffic:
		var route: Dictionary = _routes[int(traffic_item["route_index"])]
		traffic_item["distance"] = advance_distance(
			float(traffic_item["distance"]),
			float(traffic_item["speed"]),
			delta,
			float(route["length"])
		)
	_update_render_batches()

func _build_routes(roads: Array[Dictionary]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for road in roads:
		if str(road.get("highway", "")) in ["footway", "path", "pedestrian"]:
			continue
		var points: Array[Vector2] = []
		for coordinate in road.get("coordinates", []):
			var point := Vector2(float(coordinate[0]), float(coordinate[1]))
			if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.1:
				points.append(point)
		if points.size() < 2:
			continue
		var total_length := _polyline_length(points)
		if total_length < 45.0:
			continue
		var nearest := INF
		for point in points:
			nearest = minf(nearest, point.length())
		candidates.append({
			"points": points,
			"length": total_length,
			"nearest": nearest,
			"width": clampf(float(road.get("width_m", 6.0)), 3.5, 18.0),
			"oneway": str(road.get("oneway", "no")) in ["yes", "1", "true"],
			"name": str(road.get("name", ""))
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["nearest"]) < float(b["nearest"])
	)
	var routes: Array[Dictionary] = []
	for index in range(mini(candidates.size(), MAX_SOURCE_ROADS)):
		var candidate: Dictionary = candidates[index]
		var points: Array[Vector2] = candidate["points"]
		var lane_offset := minf(float(candidate["width"]) * 0.22, 1.65)
		var forward_points := _offset_polyline(points, lane_offset)
		var forward_length := _polyline_length(forward_points)
		if forward_length >= 40.0:
			routes.append({"points": forward_points, "length": forward_length, "name": candidate["name"]})
		if not bool(candidate["oneway"]):
			var reverse_points: Array[Vector2] = []
			for point_index in range(points.size() - 1, -1, -1):
				reverse_points.append(points[point_index])
			reverse_points = _offset_polyline(reverse_points, lane_offset)
			var reverse_length := _polyline_length(reverse_points)
			if reverse_length >= 40.0:
				routes.append({"points": reverse_points, "length": reverse_length, "name": candidate["name"]})
		if routes.size() >= 8:
			break
	return routes

func _offset_polyline(points: Array[Vector2], offset: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(points.size()):
		var previous := Vector2.ZERO
		var next := Vector2.ZERO
		if index > 0:
			previous = (points[index] - points[index - 1]).normalized()
		if index < points.size() - 1:
			next = (points[index + 1] - points[index]).normalized()
		var direction := next if index == 0 else previous if index == points.size() - 1 else (previous + next).normalized()
		var side := Vector2(-direction.y, direction.x)
		if index > 0 and index < points.size() - 1:
			var next_side := Vector2(-next.y, next.x)
			var miter := (side + next_side).normalized()
			var denominator := maxf(absf(miter.dot(next_side)), 0.35)
			side = miter / denominator
		result.append(points[index] + side * offset)
	return result

func _polyline_length(points: Array[Vector2]) -> float:
	var result := 0.0
	for index in range(points.size() - 1):
		result += points[index].distance_to(points[index + 1])
	return result

func _spawn_traffic() -> void:
	for route_index in range(_routes.size()):
		var route: Dictionary = _routes[route_index]
		for vehicle_index in range(VEHICLES_PER_ROUTE):
			if _traffic.size() >= MAX_TRAFFIC_VEHICLES:
				return
			_traffic.append({
				"route_index": route_index,
				"distance": float(vehicle_index) * float(route["length"]) / float(VEHICLES_PER_ROUTE) + 8.0,
				"speed": TRAFFIC_SPEEDS[_traffic.size() % TRAFFIC_SPEEDS.size()]
			})

func _create_render_batches() -> void:
	_body_batch = _create_batch(_create_loft_mesh([
		{"z": -1.95, "width": 0.72, "bottom": -0.38, "top": 0.18},
		{"z": -1.55, "width": 0.92, "bottom": -0.42, "top": 0.48},
		{"z": 1.45, "width": 0.92, "bottom": -0.42, "top": 0.48},
		{"z": 1.95, "width": 0.72, "bottom": -0.38, "top": 0.18}
	]), _material(true))
	_cabin_batch = _create_batch(_create_loft_mesh([
		{"z": -1.28, "width": 0.70, "bottom": 0.0, "top": 0.46},
		{"z": -0.88, "width": 0.78, "bottom": 0.0, "top": 0.78},
		{"z": 0.95, "width": 0.78, "bottom": 0.0, "top": 0.78},
		{"z": 1.28, "width": 0.70, "bottom": 0.0, "top": 0.46}
	]), _material(false))
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.34
	wheel_mesh.bottom_radius = 0.34
	wheel_mesh.height = 0.18
	wheel_mesh.radial_segments = 12
	_wheel_batch = _create_batch(wheel_mesh, _wheel_material(), BODY_COLORS.size() * 4)

	var window_mesh := PlaneMesh.new()
	window_mesh.size = Vector2(0.58, 0.42)
	_window_batch = _create_batch(window_mesh, _window_material(), MAX_TRAFFIC_VEHICLES * 6)

	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(0.18, 0.12, 0.055)
	_light_batch = _create_batch(light_mesh, _light_material(), MAX_TRAFFIC_VEHICLES * 4)

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

func _create_batch(mesh: Mesh, material: StandardMaterial3D, instance_count: int = BODY_COLORS.size()) -> MultiMeshInstance3D:
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = instance_count
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multi_mesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return batch

func _create_collision_proxies() -> void:
	for index in range(_traffic.size()):
		var body := AnimatableBody3D.new()
		body.name = "TrafficCollision_%02d" % index
		body.collision_layer = VEHICLE_COLLISION_LAYER
		body.collision_mask = WORLD_COLLISION_LAYER | PLAYER_COLLISION_LAYER | NPC_COLLISION_LAYER
		body.sync_to_physics = true
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.95, 1.8, 3.85)
		collision.shape = shape
		collision.position.y = 1.0
		body.add_child(collision)
		add_child(body)
		_collision_bodies.append(body)

func _update_render_batches() -> void:
	_last_directions.clear()
	for index in range(_traffic.size()):
		var item: Dictionary = _traffic[index]
		var route: Dictionary = _routes[int(item["route_index"])]
		var sample := _sample_route(route, float(item["distance"]))
		var position: Vector2 = sample["position"]
		var direction: Vector2 = sample["direction"]
		var direction_3d := Vector3(direction.x, 0.0, direction.y)
		_last_directions.append(direction_3d)
		var vehicle_basis := Basis.looking_at(direction_3d, Vector3.UP)
		var vehicle_transform := Transform3D(vehicle_basis, Vector3(position.x, 0.0, position.y))
		if index < _collision_bodies.size():
			_collision_bodies[index].global_transform = global_transform * vehicle_transform
		var tint: Color = BODY_COLORS[index % BODY_COLORS.size()]
		_body_batch.multimesh.set_instance_transform(index, vehicle_transform * Transform3D(Basis(), Vector3(0.0, 0.82, 0.0)))
		_body_batch.multimesh.set_instance_color(index, tint)
		_cabin_batch.multimesh.set_instance_transform(index, vehicle_transform * Transform3D(Basis(), Vector3(0.0, 1.35, 0.0)))
		_cabin_batch.multimesh.set_instance_color(index, Color(0.08, 0.16, 0.19))
		for wheel_index in range(4):
			var x_side := -1.0 if wheel_index < 2 else 1.0
			var z_side := -1.0 if wheel_index % 2 == 0 else 1.0
			var wheel_local := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x_side * 0.94, 0.42, z_side * 1.15))
			var instance_index := index * 4 + wheel_index
			_wheel_batch.multimesh.set_instance_transform(instance_index, vehicle_transform * wheel_local)
			_wheel_batch.multimesh.set_instance_color(instance_index, Color(0.035, 0.035, 0.035))

		var window_base := index * 6
		var window_instance := 0
		for side in [-1.0, 1.0]:
			for window_z in [-0.48, 0.42]:
				var window_basis := Basis(Vector3.UP, PI * 0.5 * side)
				var window_local := Transform3D(window_basis, Vector3(side * 0.79, 1.48, window_z))
				_window_batch.multimesh.set_instance_transform(window_base + window_instance, vehicle_transform * window_local)
				_window_batch.multimesh.set_instance_color(window_base + window_instance, Color(0.045, 0.12, 0.15))
				window_instance += 1
		var front_glass := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.48, -1.30))
		var rear_glass := Transform3D(Basis(), Vector3(0.0, 1.48, 1.30))
		_window_batch.multimesh.set_instance_transform(window_base + 4, vehicle_transform * front_glass)
		_window_batch.multimesh.set_instance_transform(window_base + 5, vehicle_transform * rear_glass)
		_window_batch.multimesh.set_instance_color(window_base + 4, Color(0.045, 0.12, 0.15))
		_window_batch.multimesh.set_instance_color(window_base + 5, Color(0.045, 0.12, 0.15))

		var light_base := index * 4
		var light_positions: Array[Vector3] = [
			Vector3(-0.57, 0.82, -1.91), Vector3(0.57, 0.82, -1.91),
			Vector3(-0.57, 0.82, 1.91), Vector3(0.57, 0.82, 1.91)
		]
		for light_index in range(4):
			_light_batch.multimesh.set_instance_transform(light_base + light_index, vehicle_transform * Transform3D(Basis(), light_positions[light_index]))
			var light_color := Color(1.0, 0.9, 0.66) if light_index < 2 else Color(0.72, 0.035, 0.025)
			_light_batch.multimesh.set_instance_color(light_base + light_index, light_color)

func _sample_route(route: Dictionary, distance: float) -> Dictionary:
	var points: Array[Vector2] = route["points"]
	var remaining := fposmod(distance, float(route["length"]))
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var segment_length := start.distance_to(finish)
		if segment_length <= 0.001:
			continue
		if remaining <= segment_length:
			var direction := (finish - start).normalized()
			return {"position": start.lerp(finish, remaining / segment_length), "direction": direction}
		remaining -= segment_length
	var last_direction := (points[points.size() - 1] - points[points.size() - 2]).normalized()
	return {"position": points[points.size() - 1], "direction": last_direction}

func _material(use_vertex_color: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE if use_vertex_color else Color(0.08, 0.16, 0.19)
	material.vertex_color_use_as_albedo = use_vertex_color
	material.roughness = 0.82
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _window_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.18
	material.metallic = 0.12
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _light_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = Color.WHITE
	return material

func _wheel_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	return material

func get_traffic_count() -> int:
	return _traffic.size()

func get_traffic_collision_count() -> int:
	return _collision_bodies.size()

func get_route_count() -> int:
	return _routes.size()

func get_traffic_distance(index: int) -> float:
	if index < 0 or index >= _traffic.size():
		return -1.0
	return float(_traffic[index]["distance"])

func get_traffic_position(index: int) -> Vector3:
	if index < 0 or index >= _traffic.size():
		return Vector3.ZERO
	return _body_batch.multimesh.get_instance_transform(index).origin

func get_traffic_direction(index: int) -> Vector3:
	if index < 0 or index >= _last_directions.size():
		return Vector3.ZERO
	return _last_directions[index]
