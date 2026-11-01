extends Node3D
class_name OSMWorldGenerator

## Builds a mobile-conscious Yaba district from a normalized OpenStreetMap extract.
## Roads, building footprints and mapped barriers remain data-driven; facade details
## are batched into MultiMeshes and building collision uses one static concave proxy.

const WORLD_RADIUS_METRES := 450.0
const MAX_BUILDINGS := 2200
const MAX_ROADS := 450
const MAX_FACADE_WINDOWS := 14000
const ROAD_COLOR := Color(0.105, 0.115, 0.12)
const SIDEWALK_COLOR := Color(0.43, 0.42, 0.38)
const DRAIN_COLOR := Color(0.075, 0.08, 0.075)
const WINDOW_COLOR := Color(0.07, 0.16, 0.19)
const BUILDING_COLORS: Array[Color] = [
	Color(0.72, 0.59, 0.44),
	Color(0.76, 0.70, 0.58),
	Color(0.64, 0.52, 0.40),
	Color(0.72, 0.72, 0.65),
	Color(0.58, 0.59, 0.54),
	Color(0.78, 0.73, 0.65)
]

var _roads: Array[Dictionary] = []
var _buildings: Array[Dictionary] = []
var _barriers: Array[Dictionary] = []
var _material_cache: Dictionary = {}
var _generated := false

func generate_from_file(path: String = "res://assets/data/yaba_osm.json") -> bool:
	if not FileAccess.file_exists(path):
		push_error("Missing Yaba OSM data at %s. Run the Yaba OSM import workflow before launching the game." % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open Yaba OSM data at %s." % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Yaba OSM data is not a valid JSON object.")
		return false
	return generate_from_data(parsed)

func generate_from_data(data: Dictionary) -> bool:
	if int(data.get("schema_version", 0)) != 1:
		push_error("Unsupported Yaba OSM schema version.")
		return false
	var source_roads: Array = data.get("roads", [])
	var source_buildings: Array = data.get("buildings", [])
	var source_barriers: Array = data.get("barriers", [])
	if source_roads.is_empty() or source_buildings.is_empty():
		push_error("Yaba OSM data must include both road ways and building footprints.")
		return false

	_roads = _select_roads(source_roads)
	_buildings = _select_buildings(source_buildings)
	_barriers = _select_barriers(source_barriers)
	if _roads.is_empty() or _buildings.is_empty():
		push_error("No Yaba roads or building footprints intersect the playable district radius.")
		return false

	_add_ground()
	_add_road_network()
	_add_building_network()
	_add_facade_batches()
	_add_barrier_network()
	_add_utility_network()
	_add_road_labels()
	_generated = true
	return true

func _select_roads(source: Array) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for item in source:
		var coordinates: Array = item.get("coordinates", [])
		if coordinates.size() < 2:
			continue
		var closest := INF
		for coordinate in coordinates:
			var point := Vector2(float(coordinate[0]), float(coordinate[1]))
			closest = minf(closest, point.length())
		if closest <= WORLD_RADIUS_METRES + 80.0:
			selected.append(item)
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _road_distance(a) < _road_distance(b)
	)
	if selected.size() > MAX_ROADS:
		selected.resize(MAX_ROADS)
	return selected

func _select_buildings(source: Array) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for item in source:
		var outline: Array = item.get("outline", [])
		if outline.size() < 4:
			continue
		var centroid := _outline_centroid(outline)
		if centroid.length() <= WORLD_RADIUS_METRES:
			ranked.append({"distance": centroid.length(), "building": item})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var selected: Array[Dictionary] = []
	for index in range(mini(ranked.size(), MAX_BUILDINGS)):
		selected.append(ranked[index]["building"])
	return selected

func _select_barriers(source: Array) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for item in source:
		var coordinates: Array = item.get("coordinates", [])
		if coordinates.size() < 2:
			continue
		for coordinate in coordinates:
			if Vector2(float(coordinate[0]), float(coordinate[1])).length() <= WORLD_RADIUS_METRES + 30.0:
				selected.append(item)
				break
	return selected

func _road_distance(road: Dictionary) -> float:
	var result := INF
	for coordinate in road.get("coordinates", []):
		result = minf(result, Vector2(float(coordinate[0]), float(coordinate[1])).length())
	return result

func _outline_centroid(outline: Array) -> Vector2:
	var result := Vector2.ZERO
	var count := outline.size()
	if count > 1 and outline[0] == outline[count - 1]:
		count -= 1
	for index in range(count):
		result += Vector2(float(outline[index][0]), float(outline[index][1]))
	return result / float(maxi(count, 1))

func _material(key: String, color: Color, roughness: float = 0.9, vertex_color: bool = false) -> StandardMaterial3D:
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.vertex_color_use_as_albedo = vertex_color
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[key] = result
	return result

func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WORLD_RADIUS_METRES * 2.2, WORLD_RADIUS_METRES * 2.2)
	ground.mesh = mesh
	ground.position.y = -0.16
	ground.material_override = _material("ground", Color(0.24, 0.29, 0.22))
	ground.name = "YabaDistrictGround"
	add_child(ground)
	var body := StaticBody3D.new()
	body.name = "YabaGroundCollision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WORLD_RADIUS_METRES * 2.2, 0.3, WORLD_RADIUS_METRES * 2.2)
	collision.shape = shape
	collision.position.y = -0.16
	body.add_child(collision)
	add_child(body)

func _points_from_coordinates(coordinates: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for coordinate in coordinates:
		var point := Vector2(float(coordinate[0]), float(coordinate[1]))
		if point.length() <= WORLD_RADIUS_METRES + 80.0:
			if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.05:
				points.append(point)
	return points

func _append_ribbon(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	points: Array[Vector2],
	width: float,
	offset: float,
	height: float
) -> void:
	if points.size() < 2:
		return
	var side_vectors: Array[Vector2] = []
	for index in range(points.size()):
		var previous_direction := Vector2.ZERO
		var next_direction := Vector2.ZERO
		if index > 0:
			previous_direction = (points[index] - points[index - 1]).normalized()
		if index < points.size() - 1:
			next_direction = (points[index + 1] - points[index]).normalized()
		var direction := next_direction if index == 0 else previous_direction if index == points.size() - 1 else (previous_direction + next_direction).normalized()
		var side := Vector2(-direction.y, direction.x).normalized()
		if index > 0 and index < points.size() - 1:
			var next_side := Vector2(-next_direction.y, next_direction.x).normalized()
			var miter := (side + next_side).normalized()
			var denominator := maxf(absf(miter.dot(next_side)), 0.35)
			side = miter / denominator
		side_vectors.append(side)
	var base := vertices.size()
	for index in range(points.size()):
		var side := side_vectors[index]
		var center := points[index] + side * offset
		var half_width := side * (width * 0.5)
		vertices.append(Vector3(center.x + half_width.x, height, center.y + half_width.y))
		vertices.append(Vector3(center.x - half_width.x, height, center.y - half_width.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for index in range(points.size() - 1):
		var start := base + index * 2
		indices.append_array(PackedInt32Array([start, start + 2, start + 1, start + 1, start + 2, start + 3]))

func _create_surface_mesh(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	material: Material,
	mesh_name: String
) -> void:
	if vertices.is_empty() or indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_road_network() -> void:
	var road_vertices := PackedVector3Array()
	var road_normals := PackedVector3Array()
	var road_indices := PackedInt32Array()
	var sidewalk_vertices := PackedVector3Array()
	var sidewalk_normals := PackedVector3Array()
	var sidewalk_indices := PackedInt32Array()
	var drain_vertices := PackedVector3Array()
	var drain_normals := PackedVector3Array()
	var drain_indices := PackedInt32Array()
	for road in _roads:
		var points := _points_from_coordinates(road.get("coordinates", []))
		if points.size() < 2:
			continue
		var width := clampf(float(road.get("width_m", 6.0)), 2.0, 24.0)
		_append_ribbon(road_vertices, road_normals, road_indices, points, width, 0.0, 0.015)
		_append_ribbon(sidewalk_vertices, sidewalk_normals, sidewalk_indices, points, 1.4, width * 0.5 + 0.85, 0.035)
		_append_ribbon(sidewalk_vertices, sidewalk_normals, sidewalk_indices, points, 1.4, -(width * 0.5 + 0.85), 0.035)
		_append_ribbon(drain_vertices, drain_normals, drain_indices, points, 0.22, width * 0.5 + 0.12, 0.025)
		_append_ribbon(drain_vertices, drain_normals, drain_indices, points, 0.22, -(width * 0.5 + 0.12), 0.025)
	_create_surface_mesh(road_vertices, road_normals, road_indices, _material("asphalt", ROAD_COLOR), "OSMRoadSurfaces")
	_create_surface_mesh(sidewalk_vertices, sidewalk_normals, sidewalk_indices, _material("sidewalk", SIDEWALK_COLOR), "OSMSidewalks")
	_create_surface_mesh(drain_vertices, drain_normals, drain_indices, _material("drainage", DRAIN_COLOR), "OSMRoadsideDrainage")

func _add_building_network() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	var windows: Array[Transform3D] = []
	var doors: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	var awnings: Array[Transform3D] = []
	var balcony_slabs: Array[Transform3D] = []
	var balcony_rails: Array[Transform3D] = []
	var parapets: Array[Transform3D] = []
	var water_tanks: Array[Transform3D] = []

	for building_index in range(_buildings.size()):
		var building: Dictionary = _buildings[building_index]
		var outline: Array[Vector2] = []
		var raw_outline: Array = building.get("outline", [])
		for coordinate in raw_outline:
			outline.append(Vector2(float(coordinate[0]), float(coordinate[1])))
		if outline.size() > 1 and outline[0].is_equal_approx(outline[outline.size() - 1]):
			outline.pop_back()
		if outline.size() < 3:
			continue
		var height := clampf(float(building.get("height_m", 4.2)), 2.8, 45.0)
		var area := _polygon_signed_area(outline)
		var winding := 1.0 if area >= 0.0 else -1.0
		var base_color: Color = BUILDING_COLORS[building_index % BUILDING_COLORS.size()]
		var longest_edge := -1
		var longest_length := 0.0
		for edge_index in range(outline.size()):
			var p0 := outline[edge_index]
			var p1 := outline[(edge_index + 1) % outline.size()]
			var edge := p1 - p0
			var length := edge.length()
			if length > longest_length:
				longest_length = length
				longest_edge = edge_index
			if length < 0.25:
				continue
			var direction := edge / length
			var outward := Vector2(direction.y, -direction.x) * winding
			var normal := Vector3(outward.x, 0.0, outward.y)
			var base := vertices.size()
			vertices.append(Vector3(p0.x, 0.0, p0.y))
			vertices.append(Vector3(p1.x, 0.0, p1.y))
			vertices.append(Vector3(p1.x, height, p1.y))
			vertices.append(Vector3(p0.x, height, p0.y))
			for _vertex in range(4):
				normals.append(normal)
				colors.append(base_color)
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
			collision_faces.append_array(PackedVector3Array([
				vertices[base], vertices[base + 2], vertices[base + 1],
				vertices[base], vertices[base + 3], vertices[base + 2]
			]))
			if windows.size() < MAX_FACADE_WINDOWS:
				_append_facade_windows(windows, p0, p1, outward, height)
			var angle := atan2(-direction.y, direction.x)
			var mid := (p0 + p1) * 0.5
			parapets.append(Transform3D(
				Basis(Vector3.UP, angle).scaled(Vector3(length, 0.22, 0.16)),
				Vector3(mid.x + outward.x * 0.04, height + 0.11, mid.y + outward.y * 0.04)
			))

		var roof_triangles := Geometry2D.triangulate_polygon(PackedVector2Array(outline))
		for triangle_index in range(0, roof_triangles.size(), 3):
			var roof_base := vertices.size()
			for corner in range(3):
				var point := outline[roof_triangles[triangle_index + corner]]
				vertices.append(Vector3(point.x, height, point.y))
				normals.append(Vector3.UP)
				colors.append(base_color.darkened(0.22))
			indices.append_array(PackedInt32Array([roof_base, roof_base + 1, roof_base + 2]))
			collision_faces.append_array(PackedVector3Array([
				vertices[roof_base], vertices[roof_base + 1], vertices[roof_base + 2]
			]))

		if longest_edge >= 0:
			var p0 := outline[longest_edge]
			var p1 := outline[(longest_edge + 1) % outline.size()]
			var edge := p1 - p0
			var direction := edge.normalized()
			var outward := Vector2(direction.y, -direction.x) * winding
			var angle := atan2(-direction.y, direction.x)
			var midpoint := (p0 + p1) * 0.5
			var building_type := str(building.get("building", "yes"))
			var commercial := not str(building.get("shop", "")).is_empty() or not str(building.get("amenity", "")).is_empty() or building_type in ["commercial", "retail", "office"]
			doors.append(Transform3D(Basis(Vector3.UP, angle), Vector3(midpoint.x + outward.x * 0.08, 1.12, midpoint.y + outward.y * 0.08)))
			if commercial:
				signs.append(Transform3D(Basis(Vector3.UP, angle), Vector3(midpoint.x + outward.x * 0.12, 2.75, midpoint.y + outward.y * 0.12)))
				awnings.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(minf(edge.length() * 0.7, 4.0), 1.0, 1.0)), Vector3(midpoint.x + outward.x * 0.62, 3.0, midpoint.y + outward.y * 0.62)))
			elif height >= 6.0 and building_type in ["residential", "apartments", "house", "yes"]:
				balcony_slabs.append(Transform3D(Basis(Vector3.UP, angle), Vector3(midpoint.x + outward.x * 0.48, 3.35, midpoint.y + outward.y * 0.48)))
				balcony_rails.append(Transform3D(Basis(Vector3.UP, angle), Vector3(midpoint.x + outward.x * 0.92, 3.92, midpoint.y + outward.y * 0.92)))
		if height >= 6.0 and building_index % 9 == 0:
			var centroid := _outline_centroid_from_vectors(outline)
			water_tanks.append(Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.0)), Vector3(centroid.x, height + 0.85, centroid.y)))

	var building_arrays: Array = []
	building_arrays.resize(Mesh.ARRAY_MAX)
	building_arrays[Mesh.ARRAY_VERTEX] = vertices
	building_arrays[Mesh.ARRAY_NORMAL] = normals
	building_arrays[Mesh.ARRAY_COLOR] = colors
	building_arrays[Mesh.ARRAY_INDEX] = indices
	var building_mesh := ArrayMesh.new()
	if not vertices.is_empty() and not indices.is_empty():
		building_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, building_arrays)
		building_mesh.surface_set_material(0, _material("building_vertex", Color.WHITE, 0.92, true))
		var building_instance := MeshInstance3D.new()
		building_instance.name = "OSMBuildingFootprintsAndFacades"
		building_instance.mesh = building_mesh
		building_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(building_instance)

	if not collision_faces.is_empty():
		var static_body := StaticBody3D.new()
		static_body.name = "OSMBuildingCollision"
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(collision_faces)
		collision.shape = concave
		static_body.add_child(collision)
		add_child(static_body)

	_add_box_batch("OSMWindows", Vector3(1.0, 1.05, 0.08), windows, WINDOW_COLOR)
	_add_box_batch("OSMShopDoors", Vector3(1.25, 2.25, 0.12), doors, Color(0.18, 0.14, 0.11))
	_add_box_batch("OSMShopSignboards", Vector3(2.6, 0.62, 0.12), signs, Color(0.10, 0.20, 0.22))
	_add_box_batch("OSMShopAwnings", Vector3(1.0, 0.14, 1.0), awnings, Color(0.72, 0.26, 0.12))
	_add_box_batch("OSMBalconySlabs", Vector3(2.5, 0.16, 0.85), balcony_slabs, Color(0.50, 0.48, 0.43))
	_add_box_batch("OSMBalconyRails", Vector3(2.5, 0.9, 0.08), balcony_rails, Color(0.18, 0.19, 0.18))
	_add_box_batch("OSMRoofParapets", Vector3.ONE, parapets, Color(0.50, 0.47, 0.42))
	_add_cylinder_batch("OSMRooftopWaterTanks", 0.68, 1.5, water_tanks, Color(0.10, 0.24, 0.38))

func _append_facade_windows(windows: Array[Transform3D], p0: Vector2, p1: Vector2, outward: Vector2, height: float) -> void:
	var edge := p1 - p0
	var length := edge.length()
	if length < 3.0:
		return
	var direction := edge / length
	var angle := atan2(-direction.y, direction.x)
	var columns := mini(4, maxi(1, int(floor(length / 3.2))))
	var rows := mini(10, maxi(1, int(floor(height / 3.1))))
	for row in range(rows):
		for column in range(columns):
			if windows.size() >= MAX_FACADE_WINDOWS:
				return
			var along := float(column + 1) / float(columns + 1)
			var center := p0.lerp(p1, along) + outward * 0.055
			var y := 1.65 + float(row) * 2.8
			if y + 0.55 < height:
				windows.append(Transform3D(Basis(Vector3.UP, angle), Vector3(center.x, y, center.y)))

func _polygon_signed_area(outline: Array[Vector2]) -> float:
	var area := 0.0
	for index in range(outline.size()):
		var current := outline[index]
		var next := outline[(index + 1) % outline.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5

func _outline_centroid_from_vectors(outline: Array[Vector2]) -> Vector2:
	var result := Vector2.ZERO
	for point in outline:
		result += point
	return result / float(maxi(outline.size(), 1))

func _add_box_batch(batch_name: String, box_size: Vector3, transforms: Array[Transform3D], color: Color) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = box_size
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = multimesh
	instance.material_override = _material(batch_name, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_cylinder_batch(batch_name: String, radius: float, height: float, transforms: Array[Transform3D], color: Color) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 10
	multimesh.mesh = cylinder
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = multimesh
	instance.material_override = _material(batch_name, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_barrier_network() -> void:
	var wall_transforms: Array[Transform3D] = []
	var fence_transforms: Array[Transform3D] = []
	var collision_faces := PackedVector3Array()
	for barrier in _barriers:
		var points := _points_from_coordinates(barrier.get("coordinates", []))
		var barrier_type := str(barrier.get("barrier", "fence"))
		var wall_height := 1.55 if barrier_type in ["wall", "city_wall", "retaining_wall"] else 1.1
		for index in range(points.size() - 1):
			var p0 := points[index]
			var p1 := points[index + 1]
			var edge := p1 - p0
			var length := edge.length()
			if length < 0.5:
				continue
			var direction := edge / length
			var normal := Vector2(-direction.y, direction.x) * 0.06
			var angle := atan2(-edge.y, edge.x)
			var midpoint := (p0 + p1) * 0.5
			var transform := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(length, wall_height, 0.12)), Vector3(midpoint.x, wall_height * 0.5, midpoint.y))
			if barrier_type in ["wall", "city_wall", "retaining_wall"]:
				wall_transforms.append(transform)
			else:
				fence_transforms.append(transform)
			var a := Vector3(p0.x + normal.x, 0.0, p0.y + normal.y)
			var b := Vector3(p1.x + normal.x, 0.0, p1.y + normal.y)
			var c := Vector3(p1.x - normal.x, 0.0, p1.y - normal.y)
			var d := Vector3(p0.x - normal.x, 0.0, p0.y - normal.y)
			var at := a + Vector3.UP * wall_height
			var bt := b + Vector3.UP * wall_height
			var ct := c + Vector3.UP * wall_height
			var dt := d + Vector3.UP * wall_height
			collision_faces.append_array(PackedVector3Array([
				a, at, bt, a, bt, b,
				b, bt, ct, b, ct, c,
				c, ct, dt, c, dt, d,
				d, dt, at, d, at, a
			]))
	_add_box_batch("OSMCompoundWalls", Vector3.ONE, wall_transforms, Color(0.60, 0.55, 0.46))
	_add_box_batch("OSMCompoundFences", Vector3.ONE, fence_transforms, Color(0.22, 0.23, 0.21))
	if not collision_faces.is_empty():
		var barrier_body := StaticBody3D.new()
		barrier_body.name = "OSMBarrierCollision"
		var barrier_collision := CollisionShape3D.new()
		var barrier_shape := ConcavePolygonShape3D.new()
		barrier_shape.set_faces(collision_faces)
		barrier_collision.shape = barrier_shape
		barrier_body.add_child(barrier_collision)
		add_child(barrier_body)

func _add_utility_network() -> void:
	var pole_transforms: Array[Transform3D] = []
	var wire_transforms: Array[Transform3D] = []
	var placed_poles := 0
	for road in _roads:
		if str(road.get("highway", "")) in ["footway", "path", "pedestrian"]:
			continue
		var points := _points_from_coordinates(road.get("coordinates", []))
		var width := clampf(float(road.get("width_m", 6.0)), 2.0, 24.0)
		for index in range(points.size() - 1):
			if placed_poles >= 120:
				break
			var edge := points[index + 1] - points[index]
			var length := edge.length()
			if length < 35.0:
				continue
			var direction := edge.normalized()
			var outward := Vector2(direction.y, -direction.x)
			var midpoint := (points[index] + points[index + 1]) * 0.5 + outward * (width * 0.5 + 2.0)
			pole_transforms.append(Transform3D(Basis(), Vector3(midpoint.x, 3.0, midpoint.y)))
			placed_poles += 1
			var wire_start := Vector3(points[index].x + outward.x * (width * 0.5 + 2.0), 6.0, points[index].y + outward.y * (width * 0.5 + 2.0))
			var wire_end := Vector3(points[index + 1].x + outward.x * (width * 0.5 + 2.0), 6.0, points[index + 1].y + outward.y * (width * 0.5 + 2.0))
			var wire_direction := wire_end - wire_start
			var wire_length := wire_direction.length()
			if wire_length > 1.0:
				var basis := Basis().looking_at(wire_direction.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
				wire_transforms.append(Transform3D(basis.scaled(Vector3(0.025, wire_length, 0.025)), (wire_start + wire_end) * 0.5))
	_add_cylinder_batch("OSMUtilityPoles", 0.09, 6.0, pole_transforms, Color(0.20, 0.18, 0.15))
	_add_cylinder_batch("OSMOverheadWires", 0.025, 1.0, wire_transforms, Color(0.06, 0.06, 0.055))

func _add_road_labels() -> void:
	var count := 0
	for road in _roads:
		if count >= 18:
			return
		var name := str(road.get("name", "")).strip_edges()
		if name.is_empty() or str(road.get("highway", "")) in ["footway", "path"]:
			continue
		var points := _points_from_coordinates(road.get("coordinates", []))
		if points.size() < 2:
			continue
		var midpoint := points[points.size() / 2]
		var label := Label3D.new()
		label.name = "StreetName_%02d" % count
		label.text = name.to_upper()
		label.font_size = 30
		label.outline_size = 6
		label.modulate = Color(1.0, 0.9, 0.67)
		label.position = Vector3(midpoint.x, 4.2, midpoint.y)
		label.rotation.y = PI
		add_child(label)
		count += 1

func get_road_data() -> Array[Dictionary]:
	return _roads

func get_building_count() -> int:
	return _buildings.size()

func get_road_count() -> int:
	return _roads.size()

func get_barrier_count() -> int:
	return _barriers.size()

func is_generated() -> bool:
	return _generated
