extends Node3D
class_name TrafficManager

## Small ambient traffic pool driven by real OSM road centre-lines.
## Vehicle meshes are shared tapered 3D lofts; each moving car has one cheap collider.

const MAX_TRAFFIC_VEHICLES := 6
const MAX_SOURCE_ROADS := 4
const VEHICLES_PER_ROUTE := 2
const TRAFFIC_MODEL_PATHS: Array[String] = [
	"res://assets/models/vehicles/quaternius/NormalCar1.obj",
	"res://assets/models/vehicles/quaternius/NormalCar2.obj",
	"res://assets/models/vehicles/quaternius/SUV.obj",
	"res://assets/models/vehicles/quaternius/Taxi.obj"
]
const WORLD_COLLISION_LAYER: int = 1
const VEHICLE_COLLISION_LAYER: int = 2
const PLAYER_COLLISION_LAYER: int = 4
const NPC_COLLISION_LAYER: int = 8
const ModelBoundsScript = preload("res://scripts/model_bounds.gd")

const TRAFFIC_SPEEDS: Array[float] = [8.0, 9.5, 7.0, 10.0, 8.5, 7.5, 9.0, 8.0]
const TRAFFIC_MODEL_DIMENSIONS: Array[Vector3] = [
	Vector3(1.80736, 1.45, 4.220717),
	Vector3(1.638448, 1.45, 3.309623),
	Vector3(2.111102, 1.45, 4.209349),
	Vector3(1.80736, 1.45, 4.220717)
]
const TRAFFIC_SOURCE_HEIGHTS: Array[float] = [1.176579, 1.145616, 1.527851, 1.310465]
const TRAFFIC_SOURCE_MIN_Y: Array[float] = [0.00603, -0.028343, -0.01809, -0.010888]

var _routes: Array[Dictionary] = []
var _traffic: Array[Dictionary] = []
var _traffic_visuals: Array[MeshInstance3D] = []
var _traffic_visual_local_transforms: Array[Transform3D] = []
var _collision_bodies: Array[AnimatableBody3D] = []
var _last_directions: Array[Vector3] = []

static func advance_distance(distance: float, speed: float, delta: float, loop_length: float = 120.0) -> float:
	if loop_length <= 0.0:
		return 0.0
	return fposmod(distance + maxf(speed, 0.0) * maxf(delta, 0.0), loop_length)

func configure_from_roads(roads: Array[Dictionary]) -> void:
	_routes = _build_routes(roads)

func _ready() -> void:
	if _routes.is_empty():
		push_warning("Ambient traffic is disabled because no usable OSM road routes were supplied.")
		return
	_spawn_traffic()
	_create_vehicle_visuals()
	_create_collision_proxies()
	_update_vehicle_transforms()

func _process(delta: float) -> void:
	for traffic_item in _traffic:
		var route: Dictionary = _routes[int(traffic_item["route_index"])]
		traffic_item["distance"] = advance_distance(
			float(traffic_item["distance"]),
			float(traffic_item["speed"]),
			delta,
			float(route["length"])
		)
	_update_vehicle_transforms()

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

func _create_vehicle_visuals() -> void:
	var model_meshes: Array[Mesh] = []
	for model_path in TRAFFIC_MODEL_PATHS:
		var model_mesh := load(model_path) as Mesh
		if model_mesh == null:
			push_error("Traffic vehicle model failed to import: %s" % model_path)
			return
		model_meshes.append(model_mesh)
	for index in range(_traffic.size()):
		var visual := MeshInstance3D.new()
		visual.name = "TrafficVehicleVisual_%02d" % index
		visual.mesh = model_meshes[index % model_meshes.size()]
		if DisplayServer.get_name() != "headless":
			for surface_index in range(visual.mesh.get_surface_count()):
				if visual.mesh.surface_get_material(surface_index) == null:
					var fallback := StandardMaterial3D.new()
					fallback.albedo_color = [Color(0.12, 0.32, 0.62), Color(0.45, 0.55, 0.64), Color(0.72, 0.72, 0.68), Color(0.92, 0.72, 0.055)][index % 4]
					fallback.roughness = 0.84
					visual.set_surface_override_material(surface_index, fallback)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(visual)
		if DisplayServer.get_name() == "headless":
			var model_index := index % TRAFFIC_SOURCE_HEIGHTS.size()
			visual.scale.y = 1.45 / TRAFFIC_SOURCE_HEIGHTS[model_index]
			visual.position.y = -TRAFFIC_SOURCE_MIN_Y[model_index] * visual.scale.y
		elif not ModelBoundsScript.fit_height_preserve_footprint(visual, 1.45):
			push_error("Traffic vehicle %02d has invalid mesh bounds." % index)
			return
		_traffic_visuals.append(visual)
		_traffic_visual_local_transforms.append(visual.transform)


func _create_collision_proxies() -> void:
	for index in range(_traffic.size()):
		var body := AnimatableBody3D.new()
		body.name = "TrafficCollision_%02d" % index
		body.collision_layer = VEHICLE_COLLISION_LAYER
		body.collision_mask = WORLD_COLLISION_LAYER | PLAYER_COLLISION_LAYER | NPC_COLLISION_LAYER
		body.sync_to_physics = true
		var dimensions := TRAFFIC_MODEL_DIMENSIONS[index % TRAFFIC_MODEL_DIMENSIONS.size()]
		if DisplayServer.get_name() != "headless":
			dimensions = ModelBoundsScript.get_scaled_dimensions(_traffic_visuals[index])
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(dimensions.x * 1.04, dimensions.y * 1.03, dimensions.z * 1.04)
		collision.shape = shape
		collision.position.y = dimensions.y * 0.5
		body.add_child(collision)
		add_child(body)
		_collision_bodies.append(body)

func _update_vehicle_transforms() -> void:
	_last_directions.clear()
	for index in range(_traffic.size()):
		var item: Dictionary = _traffic[index]
		var route: Dictionary = _routes[int(item["route_index"])]
		var sample := _sample_route(route, float(item["distance"]))
		var position: Vector2 = sample["position"]
		var direction: Vector2 = sample["direction"]
		var direction_3d := Vector3(direction.x, 0.0, direction.y)
		_last_directions.append(direction_3d)
		# Quaternius car meshes face +Z; road travel direction is their +Z axis.
		var vehicle_basis := Basis.looking_at(-direction_3d, Vector3.UP)
		var vehicle_transform := global_transform * Transform3D(vehicle_basis, Vector3(position.x, 0.0, position.y))
		if index < _traffic_visuals.size():
			_traffic_visuals[index].global_transform = vehicle_transform * _traffic_visual_local_transforms[index]
		if index < _collision_bodies.size():
			_collision_bodies[index].global_transform = vehicle_transform


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
	return _traffic_visuals[index].global_position if index < _traffic_visuals.size() else Vector3.ZERO

func get_traffic_model_surface_count(index: int) -> int:
	if index < 0 or index >= _traffic_visuals.size() or _traffic_visuals[index].mesh == null:
		return 0
	return _traffic_visuals[index].mesh.get_surface_count()

func get_traffic_direction(index: int) -> Vector3:
	if index < 0 or index >= _last_directions.size():
		return Vector3.ZERO
	return _last_directions[index]
