extends Node3D
class_name PedestrianManager

## Bounded sidewalk crowd whose paths are derived from OSM road centre-lines.
## Render geometry is shared; capsule proxies keep the player from walking through NPCs.

const WALKER_COUNT := 4
const MAX_SIDEWALK_ROUTES := 4
const WORLD_COLLISION_LAYER: int = 1
const PLAYER_COLLISION_LAYER: int = 4
const NPC_COLLISION_LAYER: int = 8
const CharacterMeshFactoryScript = preload("res://scripts/character_mesh_factory.gd")

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

var _routes: Array[Dictionary] = []
var _walkers: Array[Dictionary] = []
var _torso_batch: MultiMeshInstance3D
var _head_batch: MultiMeshInstance3D
var _hair_batch: MultiMeshInstance3D
var _arm_batch: MultiMeshInstance3D
var _leg_batch: MultiMeshInstance3D
var _collision_bodies: Array[AnimatableBody3D] = []
var _last_directions: Array[Vector3] = []
var _elapsed := 0.0

static func advance_distance(distance: float, speed: float, delta: float, route_length: float = 110.0) -> float:
	if route_length <= 0.0:
		return 0.0
	return fposmod(distance + maxf(speed, 0.0) * maxf(delta, 0.0), route_length)

func configure_from_roads(roads: Array[Dictionary]) -> void:
	_routes = _build_sidewalk_routes(roads)

func _ready() -> void:
	_create_batches()
	if _routes.is_empty():
		push_warning("Pedestrians are disabled because no usable OSM sidewalk routes were supplied.")
		return
	_spawn_walkers()
	_create_collision_proxies()
	_update_batches()

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	for walker in _walkers:
		var route: Dictionary = _routes[int(walker["route_index"])]
		walker["distance"] = advance_distance(
			float(walker["distance"]),
			float(walker["speed"]),
			delta,
			float(route["length"])
		)
	_update_batches()

func _build_sidewalk_routes(roads: Array[Dictionary]) -> Array[Dictionary]:
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
		var length := _polyline_length(points)
		if length < 45.0:
			continue
		var nearest := INF
		for point in points:
			nearest = minf(nearest, point.length())
		var offset := clampf(float(road.get("width_m", 6.0)) * 0.5 + 1.7, 3.0, 10.0)
		candidates.append({"points": points, "length": length, "nearest": nearest, "offset": offset})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["nearest"]) < float(b["nearest"])
	)
	var routes: Array[Dictionary] = []
	for candidate in candidates:
		var points: Array[Vector2] = candidate["points"]
		for side in [-1.0, 1.0]:
			var sidewalk := _offset_polyline(points, float(candidate["offset"]) * side)
			var route_length := _polyline_length(sidewalk)
			if route_length >= 40.0:
				routes.append({"points": sidewalk, "length": route_length})
			if routes.size() >= MAX_SIDEWALK_ROUTES:
				return routes
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

func _spawn_walkers() -> void:
	for index in range(mini(WALKER_COUNT, _routes.size() * 2)):
		var route_index := index % _routes.size()
		var route: Dictionary = _routes[route_index]
		_walkers.append({
			"route_index": route_index,
			"distance": float(index / _routes.size()) * float(route["length"]) * 0.48 + float(index) * 2.0,
			"speed": 0.85 + float(index % 4) * 0.12,
			"phase": float(index) * 1.4
		})

func _create_batches() -> void:
	var torso := CharacterMeshFactoryScript.create_torso_mesh()
	_torso_batch = _create_batch(torso, _material(), WALKER_COUNT)

	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	head.radial_segments = 10
	head.rings = 6
	_head_batch = _create_batch(head, _material(), WALKER_COUNT)

	var hair := SphereMesh.new()
	hair.radius = 0.225
	hair.height = 0.24
	hair.radial_segments = 10
	hair.rings = 5
	_hair_batch = _create_batch(hair, _material(), WALKER_COUNT)

	var limb := CapsuleMesh.new()
	limb.radius = 0.085
	limb.height = 0.72
	limb.radial_segments = 6
	limb.rings = 3
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

func _create_collision_proxies() -> void:
	for index in range(_walkers.size()):
		var body := AnimatableBody3D.new()
		body.name = "PedestrianCollision_%02d" % index
		body.collision_layer = NPC_COLLISION_LAYER
		body.collision_mask = WORLD_COLLISION_LAYER | PLAYER_COLLISION_LAYER
		body.sync_to_physics = true
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.28
		capsule.height = 1.7
		collision.shape = capsule
		collision.position.y = 0.88
		body.add_child(collision)
		add_child(body)
		_collision_bodies.append(body)

func _update_batches() -> void:
	_last_directions.clear()
	for index in range(_walkers.size()):
		var walker: Dictionary = _walkers[index]
		var route: Dictionary = _routes[int(walker["route_index"])]
		var sample := _sample_route(route, float(walker["distance"]))
		var position: Vector2 = sample["position"]
		var direction: Vector2 = sample["direction"]
		var direction_3d := Vector3(direction.x, 0.0, direction.y)
		_last_directions.append(direction_3d)
		var basis := Basis.looking_at(direction_3d, Vector3.UP)
		var phase := float(walker["phase"])
		var stride := sin(_elapsed * 6.0 + phase) * 0.24
		var world_position := Vector3(position.x, 0.0, position.y)
		var torso_transform := Transform3D(basis, world_position + Vector3.UP * 1.0)
		var head_transform := Transform3D(basis, world_position + Vector3.UP * 1.72)
		_torso_batch.multimesh.set_instance_transform(index, torso_transform)
		_torso_batch.multimesh.set_instance_color(index, CLOTHING_COLORS[index % CLOTHING_COLORS.size()])
		_head_batch.multimesh.set_instance_transform(index, head_transform)
		_head_batch.multimesh.set_instance_color(index, SKIN_COLORS[index % SKIN_COLORS.size()])
		var hair_basis := basis.scaled(Vector3(1.0, 0.72, 0.94))
		_hair_batch.multimesh.set_instance_transform(index, Transform3D(hair_basis, world_position + Vector3.UP * 1.88))
		_hair_batch.multimesh.set_instance_color(index, Color(0.035, 0.028, 0.022))
		for side_index in range(2):
			var side := -1.0 if side_index == 0 else 1.0
			var limb_index := index * 2 + side_index
			var arm_angle := stride * side
			var leg_angle := -stride * side
			var arm_basis := basis * Basis(Vector3.RIGHT, arm_angle)
			var leg_basis := basis * Basis(Vector3.RIGHT, leg_angle)
			var arm_origin := world_position + basis * Vector3(side * 0.37, 1.12, 0.0)
			var leg_origin := world_position + basis * Vector3(side * 0.15, 0.43, 0.0)
			_arm_batch.multimesh.set_instance_transform(limb_index, Transform3D(arm_basis, arm_origin))
			_arm_batch.multimesh.set_instance_color(limb_index, CLOTHING_COLORS[index % CLOTHING_COLORS.size()])
			_leg_batch.multimesh.set_instance_transform(limb_index, Transform3D(leg_basis, leg_origin))
			_leg_batch.multimesh.set_instance_color(limb_index, Color(0.12, 0.12, 0.13))
		if index < _collision_bodies.size():
			_collision_bodies[index].global_transform = global_transform * Transform3D(basis, world_position)

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
			return {"position": start.lerp(finish, remaining / segment_length), "direction": (finish - start).normalized()}
		remaining -= segment_length
	return {"position": points[points.size() - 1], "direction": (points[points.size() - 1] - points[points.size() - 2]).normalized()}

func get_pedestrian_count() -> int:
	return _walkers.size()

func get_pedestrian_collision_count() -> int:
	return _collision_bodies.size()

func get_route_count() -> int:
	return _routes.size()

func get_pedestrian_distance(index: int) -> float:
	if index < 0 or index >= _walkers.size():
		return -1.0
	return float(_walkers[index]["distance"])

func get_pedestrian_position(index: int) -> Vector3:
	if index < 0 or index >= _walkers.size():
		return Vector3.ZERO
	return _torso_batch.multimesh.get_instance_transform(index).origin

func get_pedestrian_direction(index: int) -> Vector3:
	if index < 0 or index >= _last_directions.size():
		return Vector3.ZERO
	return _last_directions[index]
