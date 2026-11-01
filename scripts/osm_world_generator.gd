extends Node3D
class_name OSMWorldGenerator
const LABEL_FONT = preload("res://assets/fonts/Roboto.ttf")

## Builds a mobile-conscious Yaba district from a normalized OpenStreetMap extract.
## Roads, building footprints and mapped barriers remain data-driven; facade details
## are batched into MultiMeshes and building collision uses one static concave proxy.

const WORLD_RADIUS_METRES := 450.0
const MAX_BUILDINGS := 2200
const MAX_ROADS := 450
const MAX_PROCEDURAL_COMPOUNDS := 24
const MAX_FACADE_WINDOWS := 14000
const MAX_FACADE_FRAME_WINDOWS := 5000
const MAX_SECURITY_GRILLE_BARS := 6000
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
	_add_market_stalls()
	_add_parked_keke()
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

func _label_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

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
	var ground_material := _material("ground", Color(0.27, 0.22, 0.16))
	ground_material.albedo_texture = _make_noise_texture(61, 0.16)
	ground_material.roughness_texture = _make_noise_texture(62, 0.12)
	ground_material.normal_enabled = true
	ground_material.normal_texture = _make_normal_texture(63, 0.9)
	ground_material.normal_scale = 0.07
	# PlaneMesh UVs span the entire 990m district by default. Tile the soil
	# texture at a six-metre scale so the ground reads as compacted earth,
	# not enormous repeating swirls visible from the third-person camera.
	var ground_tile_count := WORLD_RADIUS_METRES * 2.2 / 6.0
	ground_material.uv1_scale = Vector3(ground_tile_count, ground_tile_count, 1.0)
	ground_material.roughness = 0.99
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
	var laterite_vertices := PackedVector3Array()
	var laterite_normals := PackedVector3Array()
	var laterite_indices := PackedInt32Array()
	var laterite_uvs := PackedVector2Array()
	var unknown_road_vertices := PackedVector3Array()
	var unknown_road_normals := PackedVector3Array()
	var unknown_road_indices := PackedInt32Array()
	var unknown_road_uvs := PackedVector2Array()
	var sidewalk_vertices := PackedVector3Array()
	var sidewalk_normals := PackedVector3Array()
	var sidewalk_indices := PackedInt32Array()
	var sidewalk_uvs := PackedVector2Array()
	var drain_vertices := PackedVector3Array()
	var drain_normals := PackedVector3Array()
	var drain_indices := PackedInt32Array()
	var drain_uvs := PackedVector2Array()
	var curb_vertices := PackedVector3Array()
	var curb_normals := PackedVector3Array()
	var curb_indices := PackedInt32Array()
	var curb_uvs := PackedVector2Array()
	var drain_grate_transforms: Array[Transform3D] = []
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
		var mapped_surface := str(road.get("surface", "unknown")).to_lower()
		match mapped_surface:
			"unpaved", "ground", "dirt", "earth", "compacted", "fine_gravel", "gravel":
				_append_ribbon(laterite_vertices, laterite_normals, laterite_indices, points, width, 0.0, 0.016, laterite_uvs)
			"paved", "asphalt", "concrete", "concrete:plates", "paving_stones", "sett":
				_append_ribbon(road_vertices, road_normals, road_indices, points, width, 0.0, 0.015, road_uvs)
			_:
				_append_ribbon(unknown_road_vertices, unknown_road_normals, unknown_road_indices, points, width, 0.0, 0.015, unknown_road_uvs)
		if highway in ["footway", "path", "pedestrian"]:
			continue
		_append_ribbon(sidewalk_vertices, sidewalk_normals, sidewalk_indices, points, 1.4, width * 0.5 + 1.25, 0.045, sidewalk_uvs)
		_append_ribbon(sidewalk_vertices, sidewalk_normals, sidewalk_indices, points, 1.4, -(width * 0.5 + 1.25), 0.045, sidewalk_uvs)
		_append_ribbon(drain_vertices, drain_normals, drain_indices, points, 0.30, width * 0.5 + 0.20, 0.025, drain_uvs)
		_append_ribbon(drain_vertices, drain_normals, drain_indices, points, 0.30, -(width * 0.5 + 0.20), 0.025, drain_uvs)
		_append_ribbon(curb_vertices, curb_normals, curb_indices, points, 0.18, width * 0.5 + 0.45, 0.11, curb_uvs)
		_append_ribbon(curb_vertices, curb_normals, curb_indices, points, 0.18, -(width * 0.5 + 0.45), 0.11, curb_uvs)
		for segment_index in range(points.size() - 1):
			var segment_start := points[segment_index]
			var segment := points[segment_index + 1] - segment_start
			var segment_length := segment.length()
			if segment_length < 5.0:
				continue
			var segment_direction := segment / segment_length
			var grate_side := Vector2(-segment_direction.y, segment_direction.x)
			var grate_basis := Basis(Vector3.UP, atan2(segment_direction.x, segment_direction.y))
			var segment_cursor := 5.0
			while segment_cursor < segment_length and drain_grate_transforms.size() < 160:
				var grate_point := segment_start + segment_direction * segment_cursor
				for side_sign in [-1.0, 1.0]:
					var grate_position: Vector2 = grate_point + grate_side * (width * 0.5 + 0.20) * float(side_sign)
					drain_grate_transforms.append(Transform3D(grate_basis.scaled(Vector3(0.30, 0.035, 0.55)), Vector3(grate_position.x, 0.065, grate_position.y)))
				segment_cursor += 9.0
		if width >= 7.0 and str(road.get("highway", "")) in ["primary", "secondary", "tertiary"]:
			_append_road_markings(points, marking_vertices, marking_normals, marking_indices, marking_uvs)
	var asphalt_material := _material("asphalt", ROAD_COLOR)
	asphalt_material.albedo_texture = _make_noise_texture(17, 0.24)
	asphalt_material.roughness_texture = _make_noise_texture(81, 0.18)
	asphalt_material.normal_enabled = true
	asphalt_material.normal_texture = _make_normal_texture(82, 3.0)
	asphalt_material.normal_scale = 0.42
	asphalt_material.roughness = 0.98
	var laterite_material := _material("laterite", Color(0.34, 0.22, 0.14))
	laterite_material.albedo_texture = _make_noise_texture(91, 0.28)
	laterite_material.roughness_texture = _make_noise_texture(92, 0.22)
	laterite_material.normal_enabled = true
	laterite_material.normal_texture = _make_normal_texture(93, 2.4)
	laterite_material.normal_scale = 0.32
	laterite_material.roughness = 1.0
	var unknown_road_material := _material("unknown_road", Color(0.25, 0.24, 0.21))
	unknown_road_material.albedo_texture = _make_noise_texture(94, 0.23)
	unknown_road_material.roughness_texture = _make_noise_texture(95, 0.18)
	unknown_road_material.normal_enabled = true
	unknown_road_material.normal_texture = _make_normal_texture(96, 2.6)
	unknown_road_material.normal_scale = 0.34
	unknown_road_material.roughness = 1.0
	var concrete_material := _material("sidewalk", SIDEWALK_COLOR)
	concrete_material.albedo_texture = _make_noise_texture(29, 0.16)
	concrete_material.roughness_texture = _make_noise_texture(30, 0.12)
	concrete_material.normal_enabled = true
	concrete_material.normal_texture = _make_normal_texture(31, 1.8)
	concrete_material.normal_scale = 0.28
	concrete_material.roughness = 0.96
	_create_surface_mesh(road_vertices, road_normals, road_indices, road_uvs, asphalt_material, "OSMPavedRoadSurfaces")
	_create_surface_mesh(laterite_vertices, laterite_normals, laterite_indices, laterite_uvs, laterite_material, "OSMUnpavedLateriteRoadSurfaces")
	_create_surface_mesh(unknown_road_vertices, unknown_road_normals, unknown_road_indices, unknown_road_uvs, unknown_road_material, "OSMUnclassifiedRoadSurfaces")
	_create_surface_mesh(sidewalk_vertices, sidewalk_normals, sidewalk_indices, sidewalk_uvs, concrete_material, "OSMSidewalks")
	_create_surface_mesh(drain_vertices, drain_normals, drain_indices, drain_uvs, _material("drainage", DRAIN_COLOR), "OSMRoadsideDrainage")
	_create_surface_mesh(curb_vertices, curb_normals, curb_indices, curb_uvs, concrete_material, "OSMRoadsideCurbs")
	_add_box_batch("OSMDrainageGrates", Vector3.ONE, drain_grate_transforms, Color(0.18, 0.19, 0.18))
	_create_surface_mesh(marking_vertices, marking_normals, marking_indices, marking_uvs, _material("road_markings", Color(0.88, 0.84, 0.67)), "OSMRoadMarkings")

func _make_noise_texture(seed_value: int, variation: float) -> Texture2D:
	# Layer broad weathering, compact aggregate and fine surface grain instead of
	# stretching one low-frequency noise field across the entire street.
	var weathering := FastNoiseLite.new()
	weathering.seed = seed_value
	weathering.noise_type = FastNoiseLite.TYPE_SIMPLEX
	weathering.frequency = 0.012
	weathering.fractal_octaves = 3
	var aggregate := FastNoiseLite.new()
	aggregate.seed = seed_value + 17
	aggregate.noise_type = FastNoiseLite.TYPE_SIMPLEX
	aggregate.frequency = 0.085
	aggregate.fractal_octaves = 2
	var grain := FastNoiseLite.new()
	grain.seed = seed_value + 31
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grain.frequency = 0.34
	grain.fractal_octaves = 2
	const TEXTURE_SIZE := 256
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var sample := Vector2(float(x), float(y))
			var broad := weathering.get_noise_2d(sample.x, sample.y)
			var medium := aggregate.get_noise_2d(sample.x, sample.y)
			var fine := grain.get_noise_2d(sample.x, sample.y)
			var value := clampf(0.79 + broad * variation * 0.72 + medium * variation * 0.42 + fine * variation * 0.18, 0.36, 1.0)
			image.set_pixel(x, y, Color(value, value * 0.995, value * 0.985, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _make_normal_texture(seed_value: int, bump_scale: float) -> Texture2D:
	var height_noise := FastNoiseLite.new()
	height_noise.seed = seed_value
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency = 0.075
	height_noise.fractal_octaves = 3
	const TEXTURE_SIZE := 128
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var value := 0.5 + height_noise.get_noise_2d(float(x), float(y)) * 0.18
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	image.bump_map_to_normal_map(bump_scale)
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
	var window_frame_horizontal: Array[Transform3D] = []
	var window_frame_vertical: Array[Transform3D] = []
	var window_security_grilles: Array[Transform3D] = []
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
		var area := _polygon_signed_area(outline)
		var footprint_area := absf(area)
		var height := _resolve_building_height(building, footprint_area)
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
				_append_facade_windows(windows, window_frame_horizontal, window_frame_vertical, window_security_grilles, p0, p1, outward, height)
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
			var building_type := str(building.get("building", "yes"))
			var commercial := not str(building.get("shop", "")).is_empty() or not str(building.get("amenity", "")).is_empty() or building_type in ["commercial", "retail", "office"]
			# OSM's Yaba extract has very sparse shop tags. For untyped street-edge
			# footprints, infer a limited number of ground-floor shops from their
			# proximity to mapped roads; keep this explicitly art-directed, not
			# falsely labelled as verified commercial land use.
			if not commercial and building_type == "yes" and building_index % 5 == 0 and footprint_area >= 45.0:
				var frontage_center := _outline_centroid_from_vectors(outline)
				commercial = _nearest_road_distance(frontage_center) <= 14.0
			var frontage_edge := longest_edge
			if commercial:
				frontage_edge = _closest_frontage_edge(outline)
			var p0 := outline[frontage_edge]
			var p1 := outline[(frontage_edge + 1) % outline.size()]
			var edge := p1 - p0
			var direction := edge.normalized()
			var outward := Vector2(direction.y, -direction.x) * winding
			var angle := atan2(-direction.y, direction.x)
			var midpoint := (p0 + p1) * 0.5
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
					shop_label.font = LABEL_FONT
					shop_label.material_override = _label_material(Color(1.0, 0.91, 0.68))
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
		facade_material.albedo_texture = _make_noise_texture(43, 0.18)
		facade_material.roughness_texture = _make_noise_texture(44, 0.12)
		facade_material.normal_enabled = true
		facade_material.normal_texture = _make_normal_texture(45, 1.4)
		facade_material.normal_scale = 0.22
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

	_add_box_batch("OSMWindows", Vector3(0.90, 0.92, 0.05), windows, WINDOW_COLOR)
	_add_box_batch("OSMWindowFrameHorizontal", Vector3.ONE, window_frame_horizontal, Color(0.66, 0.62, 0.54))
	_add_box_batch("OSMWindowFrameVertical", Vector3.ONE, window_frame_vertical, Color(0.66, 0.62, 0.54))
	_add_box_batch("OSMWindowSecurityGrilles", Vector3.ONE, window_security_grilles, Color(0.13, 0.14, 0.14))
	_add_box_batch("OSMShopDoors", Vector3(1.25, 2.25, 0.12), doors, Color(0.18, 0.14, 0.11))
	_add_box_batch("OSMShopSignboards", Vector3(2.6, 0.62, 0.12), signs, Color(0.10, 0.20, 0.22))
	_add_box_batch("OSMShopAwnings", Vector3(1.0, 0.14, 1.0), awnings, Color(0.72, 0.26, 0.12))
	_add_box_batch("OSMBalconySlabs", Vector3(2.5, 0.16, 0.85), balcony_slabs, Color(0.50, 0.48, 0.43))
	_add_box_batch("OSMBalconyRails", Vector3(2.5, 0.9, 0.08), balcony_rails, Color(0.18, 0.19, 0.18))
	_add_box_batch("OSMRoofParapets", Vector3.ONE, parapets, Color(0.50, 0.47, 0.42))
	_add_box_batch("OSMAirConditioningUnits", Vector3.ONE, ac_units, Color(0.68, 0.68, 0.62))
	_add_cylinder_batch("OSMRooftopWaterTanks", 0.68, 1.5, water_tanks, Color(0.10, 0.24, 0.38))

func _add_market_stalls() -> void:
	# Street trading is part of the Yaba streetscape. Place a bounded set of
	# stalls at mapped commercial frontages, not at arbitrary grid positions.
	const MAX_STALLS := 24
	var red_umbrella_transforms: Array[Transform3D] = []
	var yellow_umbrella_transforms: Array[Transform3D] = []
	var green_umbrella_transforms: Array[Transform3D] = []
	var table_transforms: Array[Transform3D] = []
	var pole_transforms: Array[Transform3D] = []
	var leg_transforms: Array[Transform3D] = []
	var goods_transforms: Array[Transform3D] = []
	var collision_root := Node3D.new()
	collision_root.name = "YabaMarketStallCollision"
	var stall_count := 0
	for building in _buildings:
		if stall_count >= MAX_STALLS:
			break
		var building_type := str(building.get("building", "yes"))
		var commercial := not str(building.get("shop", "")).is_empty() or not str(building.get("amenity", "")).is_empty() or building_type in ["commercial", "retail", "office"]
		if not commercial:
			continue
		var outline: Array[Vector2] = []
		for coordinate in building.get("outline", []):
			outline.append(Vector2(float(coordinate[0]), float(coordinate[1])))
		if outline.size() > 1 and outline[0].is_equal_approx(outline[outline.size() - 1]):
			outline.pop_back()
		if outline.size() < 3:
			continue
		var best_direction := Vector2.ZERO
		var best_position := Vector2.ZERO
		var best_clearance := INF
		var winding := 1.0 if _polygon_signed_area(outline) >= 0.0 else -1.0
		for edge_index in range(outline.size()):
			var p0 := outline[edge_index]
			var p1 := outline[(edge_index + 1) % outline.size()]
			var edge_length := p0.distance_to(p1)
			if edge_length < 4.0:
				continue
			var edge_direction := (p1 - p0).normalized()
			var outward := Vector2(edge_direction.y, -edge_direction.x) * winding
			var midpoint := (p0 + p1) * 0.5
			for side_sign in [-1.0, 1.0]:
				var candidate: Vector2 = midpoint + outward * 2.8 * float(side_sign)
				var candidate_clearance := _nearest_road_distance(candidate)
				if candidate_clearance >= 3.0 and candidate_clearance <= 18.0 and candidate_clearance < best_clearance:
					best_clearance = candidate_clearance
					best_position = candidate
					best_direction = edge_direction
		if best_clearance == INF:
			continue
		var stall_position := best_position
		var direction := best_direction
		var angle := atan2(-direction.y, direction.x)
		var rotation := Basis(Vector3.UP, angle)
		var umbrella_transform := Transform3D(rotation.scaled(Vector3(1.15, 1.0, 1.15)), Vector3(stall_position.x, 2.35, stall_position.y))
		match stall_count % 3:
			0: red_umbrella_transforms.append(umbrella_transform)
			1: yellow_umbrella_transforms.append(umbrella_transform)
			2: green_umbrella_transforms.append(umbrella_transform)
		table_transforms.append(Transform3D(rotation.scaled(Vector3(1.55, 0.12, 0.88)), Vector3(stall_position.x, 0.92, stall_position.y)))
		pole_transforms.append(Transform3D(Basis().scaled(Vector3(0.035, 2.2, 0.035)), Vector3(stall_position.x, 1.1, stall_position.y)))
		for side_x in [-0.65, 0.65]:
			for side_z in [-0.32, 0.32]:
				var leg_offset := rotation * Vector3(side_x, 0.0, side_z)
				leg_transforms.append(Transform3D(Basis(), Vector3(stall_position.x + leg_offset.x, 0.44, stall_position.y + leg_offset.z)))
		for goods_index in range(3):
			var goods_offset := rotation * Vector3(-0.48 + float(goods_index) * 0.48, 0.0, -0.05)
			goods_transforms.append(Transform3D(rotation.scaled(Vector3(0.28, 0.34, 0.28)), Vector3(stall_position.x + goods_offset.x, 1.15, stall_position.y + goods_offset.z)))
		var stall_body := StaticBody3D.new()
		stall_body.name = "MarketStall_%02d" % stall_count
		stall_body.collision_layer = 1
		stall_body.collision_mask = 0
		stall_body.position = Vector3(stall_position.x, 0.45, stall_position.y)
		stall_body.rotation.y = angle
		var stall_shape := CollisionShape3D.new()
		var stall_box := BoxShape3D.new()
		stall_box.size = Vector3(1.6, 0.9, 0.9)
		stall_shape.shape = stall_box
		stall_body.add_child(stall_shape)
		collision_root.add_child(stall_body)
		stall_count += 1
	if stall_count == 0:
		return
	_add_umbrella_batch("YabaMarketUmbrellasRed", red_umbrella_transforms, Color(0.72, 0.16, 0.12))
	_add_umbrella_batch("YabaMarketUmbrellasYellow", yellow_umbrella_transforms, Color(0.84, 0.68, 0.22))
	_add_umbrella_batch("YabaMarketUmbrellasGreen", green_umbrella_transforms, Color(0.10, 0.38, 0.25))
	_add_box_batch("YabaMarketTables", Vector3.ONE, table_transforms, Color(0.30, 0.23, 0.16))
	_add_cylinder_batch("YabaMarketUmbrellaPoles", 0.035, 1.0, pole_transforms, Color(0.18, 0.17, 0.15))
	_add_cylinder_batch("YabaMarketTableLegs", 0.035, 0.85, leg_transforms, Color(0.18, 0.17, 0.15))
	_add_box_batch("YabaMarketGoodsCrates", Vector3.ONE, goods_transforms, Color(0.52, 0.34, 0.16))
	add_child(collision_root)

func _add_parked_keke() -> void:
	if _roads.is_empty():
		return
	var sample := _nearest_road_sample()
	var road_position: Vector2 = sample["position"]
	var direction: Vector2 = sample["direction"]
	var side := Vector2(-direction.y, direction.x)
	var width := float(sample["width"])
	var parked_position := road_position + direction * 28.0 + side * (width * 0.5 + 2.8)
	var keke := Node3D.new()
	keke.name = "YabaParkedKeke"
	keke.position = Vector3(parked_position.x, 0.0, parked_position.y)
	keke.rotation.y = atan2(direction.x, direction.y)
	add_child(keke)
	_add_keke_part(keke, "LowerBody", Vector3(1.32, 0.82, 2.0), Vector3(0.0, 0.98, -0.05), Color(0.12, 0.38, 0.24), 0.78)
	_add_keke_part(keke, "YellowCanopy", Vector3(1.48, 0.13, 1.62), Vector3(0.0, 2.05, -0.12), Color(0.88, 0.68, 0.08), 0.82)
	_add_keke_part(keke, "FrontWindscreen", Vector3(1.02, 0.56, 0.055), Vector3(0.0, 1.60, 0.93), Color(0.055, 0.12, 0.15), 0.24)
	for side_sign in [-1.0, 1.0]:
		var side_x := 0.64 * float(side_sign)
		_add_keke_part(keke, "SideFrame", Vector3(0.055, 0.68, 1.30), Vector3(side_x, 1.55, -0.12), Color(0.10, 0.15, 0.13), 0.78)
		_add_keke_wheel(keke, Vector3(side_x, 0.34, -0.68), "RearWheel")
	_add_keke_wheel(keke, Vector3(0.0, 0.34, 0.82), "FrontWheel")
	_add_keke_part(keke, "FrontBumper", Vector3(1.18, 0.12, 0.10), Vector3(0.0, 0.48, 1.04), Color(0.16, 0.16, 0.15), 0.8)
	_add_keke_part(keke, "FrontLightLeft", Vector3(0.20, 0.14, 0.08), Vector3(-0.45, 1.18, 0.99), Color(0.95, 0.84, 0.48), 0.35)
	_add_keke_part(keke, "FrontLightRight", Vector3(0.20, 0.14, 0.08), Vector3(0.45, 1.18, 0.99), Color(0.95, 0.84, 0.48), 0.35)
	var keke_body := StaticBody3D.new()
	keke_body.name = "KekeCollision"
	keke_body.collision_layer = 1
	keke_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var collision_box := BoxShape3D.new()
	collision_box.size = Vector3(1.5, 1.9, 2.25)
	collision.shape = collision_box
	collision.position.y = 0.95
	keke_body.add_child(collision)
	keke.add_child(keke_body)
	var route_label := Label3D.new()
	route_label.name = "KekeRouteBoard"
	route_label.text = "KEKE"
	route_label.font_size = 42
	route_label.pixel_size = 0.004
	route_label.position = Vector3(0.0, 1.86, 0.98)
	route_label.material_override = _label_material(Color(0.96, 0.84, 0.40))
	keke.add_child(route_label)

func _add_keke_part(parent: Node3D, part_name: String, size: Vector3, position: Vector3, color: Color, roughness: float) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.material_override = _material("keke_" + part_name, color, roughness)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(part)

func _add_keke_wheel(parent: Node3D, position: Vector3, part_name: String) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.height = 0.18
	mesh.radial_segments = 12
	wheel.mesh = mesh
	wheel.position = position
	wheel.rotation.z = PI * 0.5
	wheel.material_override = _material("keke_tyre", Color(0.045, 0.045, 0.042), 0.96)
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(wheel)

func _add_umbrella_batch(batch_name: String, transforms: Array[Transform3D], color: Color) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.10
	canopy.bottom_radius = 1.0
	canopy.height = 0.48
	canopy.radial_segments = 8
	multimesh.mesh = canopy
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = multimesh
	instance.material_override = _material(batch_name, color, 0.92)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

static func _resolve_building_height(building: Dictionary, footprint_area: float) -> float:
	var source := str(building.get("height_source", ""))
	var mapped_height := float(building.get("height_m", 6.2))
	if source in ["osm:height", "estimated:building-levels"]:
		return clampf(mapped_height, 2.8, 45.0)
	var building_type := str(building.get("building", "yes"))
	if building_type in ["industrial", "warehouse"]:
		return 5.5
	if building_type == "roof":
		return 3.2
	if building_type == "grandstand":
		return 5.0
	# Most Yaba footprints have no height or level tags. A documented footprint
	# area fallback gives small kiosks, houses and larger apartment blocks
	# different massing rather than stamping every unknown building at 6.2m.
	if footprint_area < 45.0:
		return 3.8
	if footprint_area < 120.0:
		return 6.2
	if footprint_area < 280.0:
		return 8.8
	if footprint_area < 650.0:
		return 11.5
	return 14.0

func _closest_frontage_edge(outline: Array[Vector2]) -> int:
	var best_edge := 0
	var best_distance := INF
	for edge_index in range(outline.size()):
		var midpoint := (outline[edge_index] + outline[(edge_index + 1) % outline.size()]) * 0.5
		var distance := _nearest_road_distance(midpoint)
		if distance < best_distance:
			best_distance = distance
			best_edge = edge_index
	return best_edge

func _append_facade_windows(
	windows: Array[Transform3D],
	frame_horizontal: Array[Transform3D],
	frame_vertical: Array[Transform3D],
	security_grilles: Array[Transform3D],
	p0: Vector2,
	p1: Vector2,
	outward: Vector2,
	height: float
) -> void:
	var edge := p1 - p0
	var length := edge.length()
	if length < 3.0:
		return
	var direction := edge / length
	var angle := atan2(-direction.y, direction.x)
	var basis := Basis(Vector3.UP, angle)
	var columns := mini(4, maxi(1, int(floor(length / 3.2))))
	var rows := mini(10, maxi(1, int(floor(height / 3.1))))
	for row in range(rows):
		for column in range(columns):
			if windows.size() >= MAX_FACADE_WINDOWS:
				return
			var along := float(column + 1) / float(columns + 1)
			var center := p0.lerp(p1, along) + outward * 0.07
			var y := 1.65 + float(row) * 2.8
			if y + 0.55 >= height:
				continue
			windows.append(Transform3D(basis, Vector3(center.x, y, center.y)))
			if frame_horizontal.size() < MAX_FACADE_FRAME_WINDOWS * 2:
				for vertical_offset in [-0.53, 0.53]:
					frame_horizontal.append(Transform3D(
						basis.scaled(Vector3(1.08, 0.065, 0.07)),
						Vector3(center.x + outward.x * 0.025, y + float(vertical_offset), center.y + outward.y * 0.025)
					))
				for horizontal_offset in [-0.50, 0.50]:
					frame_vertical.append(Transform3D(
						basis.scaled(Vector3(0.065, 1.06, 0.07)),
						Vector3(center.x + outward.x * 0.025, y, center.y + outward.y * 0.025)
					))
			# Metal security bars are common on ground-floor Lagos shop and
			# residential windows. Limit their count for mobile draw/instance cost.
			if row == 0 and column % 2 == 0 and security_grilles.size() <= MAX_SECURITY_GRILLE_BARS - 3:
				for grille_index in range(3):
					var grille_x := (float(grille_index) - 1.0) * 0.25
					security_grilles.append(Transform3D(
						basis.scaled(Vector3(0.035, 0.88, 0.045)),
						Vector3(
							center.x + basis.x.x * grille_x + outward.x * 0.09,
							y,
							center.y + basis.x.z * grille_x + outward.y * 0.09
						)
					))

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
	for building_index in range(_buildings.size()):
		if compound_count >= MAX_PROCEDURAL_COMPOUNDS:
			break
		var building: Dictionary = _buildings[building_index]
		var building_type := str(building.get("building", "yes"))
		var known_residential := building_type in ["house", "detached", "semidetached_house", "residential"]
		var outline: Array[Vector2] = []
		for coordinate in building.get("outline", []):
			outline.append(Vector2(float(coordinate[0]), float(coordinate[1])))
		if outline.size() > 1 and outline[0].is_equal_approx(outline[outline.size() - 1]):
			outline.pop_back()
		if outline.size() < 4:
			continue
		var footprint_area := absf(_polygon_signed_area(outline))
		# Many Yaba residential plots are only tagged building=yes. Infer a
		# small number of likely compound houses from compact footprints, while
		# leaving large unclassified footprints untouched.
		var inferred_residential := building_type == "yes" and footprint_area >= 45.0 and footprint_area <= 180.0 and building_index % 4 == 1
		if not known_residential and not inferred_residential:
			continue
		if footprint_area > 180.0:
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
		label.font = LABEL_FONT
		label.material_override = _label_material(Color(1.0, 0.9, 0.67))
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
	var best_score := INF
	var best_sample: Dictionary = {}
	var building_centroids: Array[Vector2] = []
	for building in _buildings:
		var outline: Array = building.get("outline", [])
		if outline.size() >= 4:
			building_centroids.append(_outline_centroid(outline))

	# First collect inexpensive candidate samples, then evaluate building
	# frontage only for the nearest 120. This keeps startup work bounded on S21-
	# class devices even when the OSM extract contains thousands of buildings.
	var road_samples: Array[Dictionary] = []
	for road in _roads:
		var highway := str(road.get("highway", ""))
		if highway in ["footway", "path", "pedestrian", "cycleway", "steps"]:
			continue
		var road_name := str(road.get("name", "")).strip_edges()
		var road_priority := 0.0
		match highway:
			"residential", "living_street":
				road_priority = 0.0
			"tertiary":
				road_priority = 5.0
			"secondary":
				road_priority = 10.0
			"primary":
				road_priority = 15.0
			"unclassified":
				road_priority = 20.0
			"service":
				road_priority = 80.0
			_:
				road_priority = 30.0
		var name_penalty := 0.0 if not road_name.is_empty() else 25.0
		var surface_penalty := 0.0 if str(road.get("surface", "")) in ["paved", "asphalt", "concrete"] else 4.0
		var points := _points_from_coordinates(road.get("coordinates", []))
		for segment_index in range(points.size() - 1):
			var start := points[segment_index]
			var finish := points[segment_index + 1]
			var segment := finish - start
			var segment_length := segment.length()
			if segment_length < 1.0:
				continue
			var direction := segment / segment_length
			var sample_count := maxi(1, int(ceil(segment_length / 16.0)))
			for sample_index in range(sample_count + 1):
				var candidate := start.lerp(finish, float(sample_index) / float(sample_count))
				var distance := candidate.length()
				if distance > 300.0:
					continue
				road_samples.append({
					"position": candidate,
					"direction": direction,
					"width": float(road.get("width_m", 6.0)),
					"name": road_name,
					"highway": highway,
					"distance": distance,
					"base_score": distance + road_priority + name_penalty + surface_penalty
				})

	road_samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var frontage_candidate_limit := mini(120, road_samples.size())
	for sample_index in range(frontage_candidate_limit):
		var sample: Dictionary = road_samples[sample_index]
		var candidate: Vector2 = sample["position"]
		var direction: Vector2 = sample["direction"]
		var left_frontage := 0
		var right_frontage := 0
		for building_center in building_centroids:
			if building_center.distance_squared_to(candidate) > 324.0:
				continue
			if direction.cross(building_center - candidate) > 0.0:
				left_frontage += 1
			else:
				right_frontage += 1
		var frontage_count := left_frontage + right_frontage
		# A slightly longer segment with buildings on both sides makes a
		# much better starting street than the nearest empty service yard.
		var frontage_bonus := float(frontage_count) * 20.0 + float(mini(left_frontage, right_frontage)) * 10.0
		var score := float(sample["base_score"]) - frontage_bonus
		if score < best_score:
			best_score = score
			best_sample = sample.duplicate()
			best_sample["frontage_count"] = frontage_count
	return best_sample

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
		var road_candidate: Vector2 = road_position + direction * longitudinal_offset
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
