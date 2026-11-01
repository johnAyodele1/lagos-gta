extends Node3D
class_name OSMWorldGenerator

## Builds a mobile-conscious Yaba district from a normalized OpenStreetMap extract.
## Roads, building footprints and mapped barriers remain data-driven; facade details
## are batched into MultiMeshes and building collision uses one static concave proxy.

const WORLD_RADIUS_METRES := 450.0
const MAX_BUILDINGS := 2200
const MAX_ROADS := 450
const MAX_PROCEDURAL_COMPOUNDS := 24
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
	_add_barrier_network()
	_add_residential_compounds()
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
	var ground_material := _material("ground", Color(0.32, 0.29, 0.24))
	ground_material.albedo_texture = _make_noise_texture(61, 0.22)
	ground_material.roughness = 0.98
	ground.material_override = ground_material
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
	height: float,
	uvs: PackedVector2Array
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
	var distance_along := 0.0
	for index in range(points.size()):
		if index > 0:
			distance_along += points[index].distance_to(points[index - 1])
		var side := side_vectors[index]
		var center := points[index] + side * offset
		var half_width := side * (width * 0.5)
		vertices.append(Vector3(center.x + half_width.x, height, center.y + half_width.y))
		vertices.append(Vector3(center.x - half_width.x, height, center.y - half_width.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(distance_along / 6.0, 0.0))
		uvs.append(Vector2(distance_along / 6.0, 1.0))
	for index in range(points.size() - 1):
		var start := base + index * 2
		indices.append_array(PackedInt32Array([start, start + 2, start + 1, start + 1, start + 2, start + 3]))

func _create_surface_mesh(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	material: Material,
	mesh_name: String
) -> void:
	if vertices.is_empty() or indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
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
	var road_uvs := PackedVector2Array()
	var sidewalk_vertices := PackedVector3Array()
	var sidewalk_normals := PackedVector3Array()
	var sidewalk_indices := PackedInt32Array()
	var sidewalk_uvs := PackedVector2Array()
	var drain_vertices := PackedVector3Array()
	var drain_normals := PackedVector3Array()
	var drain_indices := PackedInt32Array()
	var drain_uvs := PackedVector2Array()
	var marking_vertices := PackedVector3Array()
	var marking_normals := PackedVector3Array()
	var marking_indices := PackedInt32Array()
	var marking_uvs := PackedVector2Array()
	for road in _roads:
		var points := _points_from_coordinates(road.get("coordinates", []))
		if points.size() < 2:
			continue
		var width := clampf(float(road.get("width_m", 6.0)), 2.0, 24.0)
		var highway := str(road.get("highway", ""))
		_append_ribbon(road_vertices, road_normals, road_indices, points, width, 0.0, 0.015, road_uvs)
		if highway in ["footway", "path", "pedestrian"]:
			continue
		_append_ribbon(sidewalk_vertices, sidewalk_normals, sidewalk_indices, points, 1.4, width * 0.5 + 0.85, 0.035, sidewalk_uvs)
		_append_ribbon(sidewalk_vertices, sidewalk_normals, sidewalk_indices, points, 1.4, -(width * 0.5 + 0.85), 0.035, sidewalk_uvs)
		_append_ribbon(drain_vertices, drain_normals, drain_indices, points, 0.22, width * 0.5 + 0.12, 0.025, drain_uvs)
		_append_ribbon(drain_vertices, drain_normals, drain_indices, points, 0.22, -(width * 0.5 + 0.12), 0.025, drain_uvs)
		if width >= 7.0 and str(road.get("highway", "")) in ["primary", "secondary", "tertiary"]:
			_append_road_markings(points, marking_vertices, marking_normals, marking_indices, marking_uvs)
	var asphalt_material := _material("asphalt", ROAD_COLOR)
	asphalt_material.albedo_texture = _make_noise_texture(17, 0.20)
	asphalt_material.roughness = 0.98
	var concrete_material := _material("sidewalk", SIDEWALK_COLOR)
	concrete_material.albedo_texture = _make_noise_texture(29, 0.12)
	concrete_material.roughness = 0.96
	_create_surface_mesh(road_vertices, road_normals, road_indices, road_uvs, asphalt_material, "OSMRoadSurfaces")
	_create_surface_mesh(sidewalk_vertices, sidewalk_normals, sidewalk_indices, sidewalk_uvs, concrete_material, "OSMSidewalks")
	_create_surface_mesh(drain_vertices, drain_normals, drain_indices, drain_uvs, _material("drainage", DRAIN_COLOR), "OSMRoadsideDrainage")
	_create_surface_mesh(marking_vertices, marking_normals, marking_indices, marking_uvs, _material("road_markings", Color(0.88, 0.84, 0.67)), "OSMRoadMarkings")

func _make_noise_texture(seed_value: int, variation: float) -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var value := 1.0 - absf(noise.get_noise_2d(float(x), float(y))) * variation
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _append_road_markings(
	points: Array[Vector2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array
) -> void:
	var distance_along := 0.0
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var edge := finish - start
		var length := edge.length()
		if length < 5.0:
			distance_along += length
			continue
		var direction := edge / length
		var side := Vector2(-direction.y, direction.x) * 0.075
		var cursor := 3.0
		while cursor + 4.0 < length:
			var dash_start := start + direction * cursor
			var dash_end := start + direction * (cursor + 4.0)
			var base := vertices.size()
			vertices.append(Vector3(dash_start.x + side.x, 0.028, dash_start.y + side.y))
			vertices.append(Vector3(dash_start.x - side.x, 0.028, dash_start.y - side.y))
			vertices.append(Vector3(dash_end.x + side.x, 0.028, dash_end.y + side.y))
			vertices.append(Vector3(dash_end.x - side.x, 0.028, dash_end.y - side.y))
			for _vertex in range(4):
				normals.append(Vector3.UP)
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
			uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]))
			cursor += 11.0
		distance_along += length

func _add_building_network() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var collision_faces := PackedVector3Array()
	var windows: Array[Transform3D] = []
	var doors: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	var awnings: Array[Transform3D] = []
	var balcony_slabs: Array[Transform3D] = []
	var balcony_rails: Array[Transform3D] = []
	var parapets: Array[Transform3D] = []
	var ac_units: Array[Transform3D] = []
	var water_tanks: Array[Transform3D] = []
	var shop_label_count := 0

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
			uvs.append_array(PackedVector2Array([
				Vector2(0.0, 0.0),
				Vector2(length / 4.0, 0.0),
				Vector2(length / 4.0, height / 4.0),
				Vector2(0.0, height / 4.0)
			]))
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
			if building_index % 3 == 0 and height >= 3.5 and edge_index % 2 == 0:
				ac_units.append(Transform3D(
					Basis(Vector3.UP, angle).scaled(Vector3(0.62, 0.38, 0.30)),
					Vector3(mid.x + outward.x * 0.18, minf(height * 0.58, 3.2), mid.y + outward.y * 0.18)
				))

		var roof_triangles := Geometry2D.triangulate_polygon(PackedVector2Array(outline))
		for triangle_index in range(0, roof_triangles.size(), 3):
			var roof_base := vertices.size()
			var triangle_points: Array[Vector2] = []
			for corner in range(3):
				var point := outline[roof_triangles[triangle_index + corner]]
				triangle_points.append(point)
				vertices.append(Vector3(point.x, height, point.y))
				normals.append(Vector3.UP)
				colors.append(base_color.darkened(0.22))
				uvs.append(Vector2(point.x / 8.0, point.y / 8.0))
			indices.append_array(PackedInt32Array([roof_base, roof_base + 1, roof_base + 2]))
			collision_faces.append_array(PackedVector3Array([
				vertices[roof_base], vertices[roof_base + 1], vertices[roof_base + 2],
				Vector3(triangle_points[0].x, 0.0, triangle_points[0].y),
				Vector3(triangle_points[2].x, 0.0, triangle_points[2].y),
				Vector3(triangle_points[1].x, 0.0, triangle_points[1].y)
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
				if shop_label_count < 32:
					var shop_name := str(building.get("name", ""))
					if shop_name.is_empty():
						shop_name = str(building.get("shop", building.get("amenity", "SHOP"))).replace("_", " ").to_upper()
					shop_name = shop_name.substr(0, 18).to_upper()
					var shop_label := Label3D.new()
					shop_label.name = "YabaShopSign_%02d" % shop_label_count
					shop_label.text = shop_name
					shop_label.position = Vector3(midpoint.x + outward.x * 0.18, 2.77, midpoint.y + outward.y * 0.18)
					shop_label.rotation.y = angle
					shop_label.font_size = 24
					shop_label.outline_size = 5
					shop_label.modulate = Color(1.0, 0.91, 0.68)
					shop_label.outline_modulate = Color(0.025, 0.03, 0.03)
					add_child(shop_label)
					shop_label_count += 1
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
	building_arrays[Mesh.ARRAY_TEX_UV] = uvs
	building_arrays[Mesh.ARRAY_INDEX] = indices
	var building_mesh := ArrayMesh.new()
	if not vertices.is_empty() and not indices.is_empty():
		building_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, building_arrays)
		var facade_material := _material("building_vertex", Color.WHITE, 0.94, true)
		facade_material.albedo_texture = _make_noise_texture(43, 0.14)
		building_mesh.surface_set_material(0, facade_material)
		var building_instance := MeshInstance3D.new()
		building_instance.name = "OSMBuildingFootprintsAndFacades"
		building_instance.mesh = building_mesh
		building_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(building_instance)

	if not collision_faces.is_empty():
		var static_body := StaticBody3D.new()
		static_body.name = "OSMBuildingCollision"
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
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
	_add_box_batch("OSMAirConditioningUnits", Vector3.ONE, ac_units, Color(0.68, 0.68, 0.62))
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
	var collision_root := Node3D.new()
	collision_root.name = "OSMBarrierCollision"
	var collider_count := 0
	for barrier in _barriers:
		var points := _points_from_coordinates(barrier.get("coordinates", []))
		var barrier_type := str(barrier.get("barrier", "fence"))
		var is_wall := barrier_type in ["wall", "city_wall", "retaining_wall"]
		var wall_height := 1.55 if is_wall else 1.1
		for index in range(points.size() - 1):
			var edge := points[index + 1] - points[index]
			var length := edge.length()
			if length < 0.5:
				continue
			var angle := atan2(-edge.y, edge.x)
			var midpoint := (points[index] + points[index + 1]) * 0.5
			var transform := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(length, wall_height, 0.12)), Vector3(midpoint.x, wall_height * 0.5, midpoint.y))
			if is_wall:
				wall_transforms.append(transform)
			else:
				fence_transforms.append(transform)

			# Keep each mapped segment as its own static box collider for predictable contacts.
			var segment_body := StaticBody3D.new()
			segment_body.name = "BarrierSegment_%d_%d" % [collider_count, index]
			segment_body.collision_layer = 1
			segment_body.collision_mask = 0
			segment_body.position = Vector3(midpoint.x, wall_height * 0.5, midpoint.y)
			segment_body.rotation.y = angle
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(length, wall_height, 0.18)
			collision.shape = shape
			segment_body.add_child(collision)
			collision_root.add_child(segment_body)
			collider_count += 1

	_add_box_batch("OSMCompoundWalls", Vector3.ONE, wall_transforms, Color(0.60, 0.55, 0.46))
	_add_box_batch("OSMCompoundFences", Vector3.ONE, fence_transforms, Color(0.22, 0.23, 0.21))
	if collider_count > 0:
		add_child(collision_root)

func _nearest_road_distance(point: Vector2) -> float:
	var nearest := INF
	for road in _roads:
		var points := _points_from_coordinates(road.get("coordinates", []))
		for index in range(points.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])
			nearest = minf(nearest, point.distance_to(closest))
	return nearest

func _add_residential_compounds() -> void:
	# OSM rarely maps individual compound boundaries consistently. These are
	# clearly art-directed low walls around isolated residential footprints,
	# not claims that the OSM building outline is a surveyed property boundary.
	var wall_transforms: Array[Transform3D] = []
	var collision_root := Node3D.new()
	collision_root.name = "ProceduralCompoundWallCollision"
	var compound_count := 0
	for building in _buildings:
		if compound_count >= MAX_PROCEDURAL_COMPOUNDS:
			break
		var building_type := str(building.get("building", "yes"))
		if building_type not in ["house", "detached", "semidetached_house", "residential"]:
			continue
		var outline: Array[Vector2] = []
		for coordinate in building.get("outline", []):
			outline.append(Vector2(float(coordinate[0]), float(coordinate[1])))
		if outline.size() > 1 and outline[0].is_equal_approx(outline[outline.size() - 1]):
			outline.pop_back()
		if outline.size() < 4:
			continue
		if absf(_polygon_signed_area(outline)) > 180.0:
			continue
		var centroid := _outline_centroid_from_vectors(outline)
		if _nearest_road_distance(centroid) > 22.0:
			continue
		var isolated := true
		for other in _buildings:
			if other.get("id", "") == building.get("id", ""):
				continue
			var other_centroid := _outline_centroid(other.get("outline", []))
			if other_centroid.distance_to(centroid) < 8.0:
				isolated = false
				break
		if not isolated:
			continue

		var expanded: Array[Vector2] = []
		for point in outline:
			expanded.append(point + (point - centroid).normalized() * 1.35)
		var gate_edge := 0
		var gate_distance := INF
		for edge_index in range(expanded.size()):
			var midpoint := (expanded[edge_index] + expanded[(edge_index + 1) % expanded.size()]) * 0.5
			var road_distance := _nearest_road_distance(midpoint)
			if road_distance < gate_distance:
				gate_distance = road_distance
				gate_edge = edge_index

		for edge_index in range(expanded.size()):
			var p0 := expanded[edge_index]
			var p1 := expanded[(edge_index + 1) % expanded.size()]
			var edge := p1 - p0
			var length := edge.length()
			if length < 0.8:
				continue
			var direction := edge / length
			var angle := atan2(-direction.y, direction.x)
			if edge_index == gate_edge and length > 3.2:
				var gate_center := (p0 + p1) * 0.5
				var left_end := gate_center - direction * 1.1
				var right_start := gate_center + direction * 1.1
				_append_compound_wall_segment(p0, left_end, angle, wall_transforms, collision_root)
				_append_compound_wall_segment(right_start, p1, angle, wall_transforms, collision_root)
			else:
				_append_compound_wall_segment(p0, p1, angle, wall_transforms, collision_root)
		compound_count += 1

	_add_box_batch("ArtDirectedResidentialCompoundWalls", Vector3.ONE, wall_transforms, Color(0.57, 0.51, 0.43))
	if collision_root.get_child_count() > 0:
		add_child(collision_root)

func _append_compound_wall_segment(
	p0: Vector2,
	p1: Vector2,
	angle: float,
	wall_transforms: Array[Transform3D],
	collision_root: Node3D
) -> void:
	var length := p0.distance_to(p1)
	if length < 0.35:
		return
	var midpoint := (p0 + p1) * 0.5
	wall_transforms.append(Transform3D(
		Basis(Vector3.UP, angle).scaled(Vector3(length, 1.45, 0.16)),
		Vector3(midpoint.x, 0.725, midpoint.y)
	))
	var body := StaticBody3D.new()
	body.name = "CompoundWallSegment_%d" % collision_root.get_child_count()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(midpoint.x, 0.725, midpoint.y)
	body.rotation.y = angle
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 1.45, 0.18)
	collision.shape = shape
	body.add_child(collision)
	collision_root.add_child(body)

func _add_utility_network() -> void:
	var pole_transforms: Array[Transform3D] = []
	var wire_transforms: Array[Transform3D] = []
	var crossarm_transforms: Array[Transform3D] = []
	var insulator_transforms: Array[Transform3D] = []
	var streetlight_arm_transforms: Array[Transform3D] = []
	var streetlight_lamp_transforms: Array[Transform3D] = []
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

			var road_angle := atan2(-direction.y, direction.x)
			var crossarm_angle := road_angle + PI * 0.5
			crossarm_transforms.append(Transform3D(
				Basis(Vector3.UP, crossarm_angle).scaled(Vector3(1.55, 0.13, 0.13)),
				Vector3(midpoint.x, 5.55, midpoint.y)
			))
			var cross_direction := Vector2(cos(crossarm_angle), -sin(crossarm_angle))
			for cross_side in [-0.55, 0.55]:
				var insulator_point: Vector2 = midpoint + cross_direction * float(cross_side)
				insulator_transforms.append(Transform3D(Basis(), Vector3(insulator_point.x, 5.70, insulator_point.y)))

			var toward_road := -outward
			var lamp_angle := atan2(-toward_road.y, toward_road.x)
			streetlight_arm_transforms.append(Transform3D(
				Basis(Vector3.UP, lamp_angle).scaled(Vector3(1.0, 0.075, 0.075)),
				Vector3(midpoint.x + toward_road.x * 0.48, 5.15, midpoint.y + toward_road.y * 0.48)
			))
			streetlight_lamp_transforms.append(Transform3D(
				Basis(Vector3.UP, lamp_angle).scaled(Vector3(0.34, 0.12, 0.22)),
				Vector3(midpoint.x + toward_road.x * 0.98, 5.12, midpoint.y + toward_road.y * 0.98)
			))

			var wire_start := Vector3(points[index].x + outward.x * (width * 0.5 + 2.0), 6.0, points[index].y + outward.y * (width * 0.5 + 2.0))
			var wire_end := Vector3(points[index + 1].x + outward.x * (width * 0.5 + 2.0), 6.0, points[index + 1].y + outward.y * (width * 0.5 + 2.0))
			var wire_direction := wire_end - wire_start
			var wire_length := wire_direction.length()
			if wire_length > 1.0:
				var basis := Basis().looking_at(wire_direction.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
				wire_transforms.append(Transform3D(basis.scaled(Vector3(0.025, wire_length, 0.025)), (wire_start + wire_end) * 0.5))
	_add_cylinder_batch("OSMUtilityPoles", 0.09, 6.0, pole_transforms, Color(0.20, 0.18, 0.15))
	_add_cylinder_batch("OSMUtilityInsulators", 0.045, 0.18, insulator_transforms, Color(0.25, 0.24, 0.20))
	_add_cylinder_batch("OSMOverheadWires", 0.025, 1.0, wire_transforms, Color(0.06, 0.06, 0.055))
	_add_box_batch("OSMUtilityCrossarms", Vector3.ONE, crossarm_transforms, Color(0.28, 0.23, 0.16))
	_add_box_batch("OSMStreetlightArms", Vector3.ONE, streetlight_arm_transforms, Color(0.16, 0.17, 0.16))
	_add_box_batch("OSMStreetlightHeads", Vector3.ONE, streetlight_lamp_transforms, Color(0.76, 0.73, 0.62))

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

func _nearest_road_sample() -> Dictionary:
	var best_distance := INF
	var best_position := Vector2.ZERO
	var best_direction := Vector2.RIGHT
	var best_width := 6.0
	for road in _roads:
		if str(road.get("highway", "")) in ["footway", "path", "pedestrian"]:
			continue
		var points := _points_from_coordinates(road.get("coordinates", []))
		for index in range(points.size() - 1):
			var start := points[index]
			var finish := points[index + 1]
			var candidate := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, start, finish)
			var distance := candidate.length()
			if distance < best_distance:
				best_distance = distance
				best_position = candidate
				best_direction = (finish - start).normalized()
				best_width = float(road.get("width_m", 6.0))
	return {"position": best_position, "direction": best_direction, "width": best_width}

func get_vehicle_spawn_position() -> Vector3:
	var sample := _nearest_road_sample()
	var position: Vector2 = sample["position"] + sample["direction"] * 8.0
	return Vector3(position.x, 0.0, position.y)

func get_player_spawn_position() -> Vector3:
	var sample := _nearest_road_sample()
	var road_position: Vector2 = sample["position"]
	var direction: Vector2 = sample["direction"]
	var side := Vector2(-direction.y, direction.x)
	# The sidewalk ribbon is 1.4m wide and centred 0.85m beyond the road edge.
	var sidewalk_offset := float(sample["width"]) * 0.5 + 0.85
	var longitudinal_offsets: Array[float] = [8.0, -8.0, 16.0, -16.0, 24.0, -24.0, 32.0, -32.0]
	var best_position := Vector2(INF, INF)
	var best_clearance := -INF
	for longitudinal_offset in longitudinal_offsets:
		var road_candidate := road_position + direction * longitudinal_offset
		for side_sign in [1.0, -1.0]:
			var candidate: Vector2 = road_candidate + side * sidewalk_offset * side_sign
			var clearance := _spawn_clearance(candidate)
			if clearance > best_clearance:
				best_clearance = clearance
				best_position = candidate
			if clearance >= 0.85:
				return Vector3(candidate.x, 0.5, candidate.y)
	if best_position.is_finite() and best_clearance >= 0.85:
		return Vector3(best_position.x, 0.5, best_position.y)
	push_error("No collision-free Yaba sidewalk spawn was found; refusing unsafe player spawn.")
	return Vector3.INF

func is_spawn_position_clear(position: Vector3, minimum_clearance: float = 0.85) -> bool:
	return position.is_finite() and _spawn_clearance(Vector2(position.x, position.z)) >= minimum_clearance

func _spawn_clearance(point: Vector2) -> float:
	var nearest := INF
	for building in _buildings:
		var outline: Array[Vector2] = []
		for coordinate in building.get("outline", []):
			outline.append(Vector2(float(coordinate[0]), float(coordinate[1])))
		if outline.size() > 1 and outline[0].is_equal_approx(outline[outline.size() - 1]):
			outline.pop_back()
		if outline.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(point, PackedVector2Array(outline)):
			return 0.0
		for index in range(outline.size()):
			var closest := Geometry2D.get_closest_point_to_segment(point, outline[index], outline[(index + 1) % outline.size()])
			nearest = minf(nearest, point.distance_to(closest))
	for barrier in _barriers:
		var points := _points_from_coordinates(barrier.get("coordinates", []))
		for index in range(points.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])
			nearest = minf(nearest, maxf(0.0, point.distance_to(closest) - 0.12))
	return nearest

func get_spawn_rotation_y() -> float:
	var direction: Vector2 = _nearest_road_sample()["direction"]
	return atan2(-direction.x, -direction.y)

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
