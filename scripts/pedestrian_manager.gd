extends Node3D
class_name PedestrianManager

## Bounded sidewalk crowd whose paths are derived from OSM road centre-lines.
## Render geometry is shared; capsule proxies keep the player from walking through NPCs.

const WALKER_COUNT := 4
const MAX_SIDEWALK_ROUTES := 4
const WORLD_COLLISION_LAYER: int = 1
const PLAYER_COLLISION_LAYER: int = 4
const VEHICLE_COLLISION_LAYER: int = 2
const NPC_COLLISION_LAYER: int = 8
const RIGGED_CHARACTER_SCENE = preload("res://assets/models/characters/lagos_player.glb")
const ARA_CHARACTER_SCENE_PATHS: Array[String] = [
	"res://assets/models/characters/ara/lagos_male_civilian.glb",
	"res://assets/models/characters/ara/lagos_female_civilian.glb",
	"res://assets/models/characters/ara/lagos_frsc_officer.glb",
	"res://assets/models/characters/ara/lagos_police_officer.glb"
]
const ModelBoundsScript = preload("res://scripts/model_bounds.gd")

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
var _visuals: Array[Node3D] = []
var _visual_local_transforms: Array[Transform3D] = []
var _animation_players: Array[AnimationPlayer] = []
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
	if _routes.is_empty():
		push_warning("Pedestrians are disabled because no usable OSM sidewalk routes were supplied.")
		return
	_spawn_walkers()
	_create_collision_proxies()
	_create_rigged_visuals()
	_update_rigged_visuals()

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
	_update_rigged_visuals()

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

func _create_rigged_visuals() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for index in range(_walkers.size()):
		var model_scene: PackedScene = RIGGED_CHARACTER_SCENE as PackedScene
		var use_ara_character := false
		var model_path := ARA_CHARACTER_SCENE_PATHS[index % ARA_CHARACTER_SCENE_PATHS.size()]
		if ResourceLoader.exists(model_path):
			var imported_scene := load(model_path) as PackedScene
			if imported_scene != null:
				model_scene = imported_scene
				use_ara_character = true
		if model_scene == null:
			push_error("No rigged pedestrian model is available.")
			continue
		var visual := model_scene.instantiate() as Node3D
		if visual == null:
			push_error("Pedestrian model instance has no Node3D root.")
			continue
		visual.name = "PedestrianVisual_%02d" % index
		# Ara's GLB uses glTF's -Z forward axis. Keep the old Quaternius
		# fallback's +Z correction separate from the imported character path.
		visual.rotation.y = 0.0 if use_ara_character else PI
		if not use_ara_character:
			_apply_pedestrian_materials(visual, CLOTHING_COLORS[index % CLOTHING_COLORS.size()], SKIN_COLORS[index % SKIN_COLORS.size()])
		add_child(visual)
		if not ModelBoundsScript.fit_height(visual, 1.68):
			push_warning("Pedestrian %02d could not be normalized to human height." % index)
		_visuals.append(visual)
		_visual_local_transforms.append(visual.transform)
		var animation_player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_animation_players.append(animation_player)
		var walk_animation := _resolve_walk_animation(animation_player)
		if animation_player != null and walk_animation != &"":
			animation_player.play(walk_animation)
			animation_player.speed_scale = float(_walkers[index]["speed"])


func _resolve_walk_animation(animation_player: AnimationPlayer) -> StringName:
	if animation_player == null:
		return &""
	if animation_player.has_animation("HumanArmature|Man_Walk"):
		return &"HumanArmature|Man_Walk"
	for animation_name in animation_player.get_animation_list():
		if str(animation_name).to_lower().contains("walk"):
			return StringName(animation_name)
	return &""

func _apply_pedestrian_materials(model: Node3D, shirt_color: Color, skin_color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var palette: Array[Color] = [
		shirt_color, shirt_color, skin_color, Color(0.08, 0.09, 0.10),
		Color(0.025, 0.025, 0.025), Color(0.28, 0.27, 0.25),
		Color(0.025, 0.022, 0.018), Color(0.025, 0.022, 0.018), Color(0.015, 0.012, 0.01)
	]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := StandardMaterial3D.new()
			material.albedo_color = palette[mini(surface_index, palette.size() - 1)]
			material.roughness = 0.88
			mesh_instance.set_surface_override_material(surface_index, material)
		mesh_instance.material_override = null


func _create_collision_proxies() -> void:
	for index in range(_walkers.size()):
		var body := AnimatableBody3D.new()
		body.name = "PedestrianCollision_%02d" % index
		body.collision_layer = NPC_COLLISION_LAYER
		body.collision_mask = WORLD_COLLISION_LAYER | PLAYER_COLLISION_LAYER | VEHICLE_COLLISION_LAYER
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

func _update_rigged_visuals() -> void:
	_last_directions.clear()
	for index in range(_walkers.size()):
		var walker: Dictionary = _walkers[index]
		var route: Dictionary = _routes[int(walker["route_index"])]
		var sample := _sample_route(route, float(walker["distance"]))
		var position: Vector2 = sample["position"]
		var direction: Vector2 = sample["direction"]
		var direction_3d := Vector3(direction.x, 0.0, direction.y)
		_last_directions.append(direction_3d)
		var world_position := Vector3(position.x, 0.0, position.y)
		var basis := Basis.looking_at(direction_3d, Vector3.UP)
		var world_transform := global_transform * Transform3D(basis, world_position)
		if index < _visuals.size():
			_visuals[index].global_transform = world_transform * _visual_local_transforms[index]
		if index < _collision_bodies.size():
			_collision_bodies[index].global_transform = world_transform

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
	if index < _visuals.size():
		return _visuals[index].global_position
	var walker: Dictionary = _walkers[index]
	var route: Dictionary = _routes[int(walker["route_index"])]
	var sample := _sample_route(route, float(walker["distance"]))
	var position: Vector2 = sample["position"]
	return global_transform * Vector3(position.x, 0.0, position.y)

func get_pedestrian_direction(index: int) -> Vector3:
	if index < 0 or index >= _last_directions.size():
		return Vector3.ZERO
	return _last_directions[index]
