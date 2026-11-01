extends Node3D
class_name WorldGenerator

const ROAD_COLOR := Color(0.12, 0.13, 0.14)
const SIDEWALK_COLOR := Color(0.48, 0.46, 0.40)
const WINDOW_COLOR := Color(0.12, 0.23, 0.28)
const MARKET_CANOPY_COLORS: Array[Color] = [
	Color(0.72, 0.18, 0.12),
	Color(0.82, 0.68, 0.24),
	Color(0.12, 0.38, 0.28)
]
const BUILDING_COLORS: Array[Color] = [
	Color(0.76, 0.64, 0.48),
	Color(0.72, 0.72, 0.66),
	Color(0.68, 0.49, 0.36),
	Color(0.80, 0.76, 0.64),
	Color(0.56, 0.60, 0.56)
]

var _material_cache: Dictionary = {}

func generate() -> void:
	_add_ground()
	_add_road_network()
	_add_buildings()
	_add_street_lights()
	_add_landmarks()
	_add_market_stalls()
	_add_compound_details()

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(true), roughness]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	_material_cache[key] = result
	return result

func _add_box(parent: Node3D, box_size: Vector3, position: Vector3, color: Color, solid: bool = false) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.position = position
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)

	if solid:
		var body := StaticBody3D.new()
		body.position = position
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)

func _add_box_batch(parent: Node3D, box_size: Vector3, transforms: Array[Transform3D], color: Color) -> void:
	if transforms.is_empty():
		return
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = box_size
	multi_mesh.mesh = box
	multi_mesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi_mesh.set_instance_transform(index, transforms[index])
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multi_mesh
	batch.material_override = _material(color)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)

func _add_ground() -> void:
	_add_box(self, Vector3(150.0, 0.5, 150.0), Vector3(0.0, -0.35, 0.0), Color(0.28, 0.38, 0.24), true)

func _add_road_network() -> void:
	_add_box(self, Vector3(18.0, 0.08, 130.0), Vector3(0.0, -0.055, 0.0), ROAD_COLOR)
	_add_box(self, Vector3(130.0, 0.08, 18.0), Vector3(0.0, -0.05, 0.0), ROAD_COLOR)
	for side in [-1.0, 1.0]:
		_add_box(self, Vector3(3.0, 0.16, 130.0), Vector3(side * 10.5, 0.0, 0.0), SIDEWALK_COLOR)
		_add_box(self, Vector3(130.0, 0.16, 3.0), Vector3(0.0, 0.0, side * 10.5), SIDEWALK_COLOR)
	var vertical_markings: Array[Transform3D] = []
	var horizontal_markings: Array[Transform3D] = []
	for z in range(-58, 60, 8):
		vertical_markings.append(Transform3D(Basis(), Vector3(0.0, 0.0, float(z))))
	for x in range(-58, 60, 8):
		horizontal_markings.append(Transform3D(Basis(), Vector3(float(x), 0.005, 0.0)))
	_add_box_batch(self, Vector3(0.18, 0.025, 3.4), vertical_markings, Color(0.88, 0.82, 0.60))
	_add_box_batch(self, Vector3(3.4, 0.025, 0.18), horizontal_markings, Color(0.88, 0.82, 0.60))

func _add_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	var plots: Array[Vector2] = []
	for x in [-1, 1]:
		for z in range(-2, 3):
			plots.append(Vector2(float(x) * 25.0, float(z) * 23.0))
	for z in [-1, 1]:
		for x in range(-2, 3):
			plots.append(Vector2(float(x) * 23.0, float(z) * 25.0))
	var index := 0
	var balcony_slabs: Array[Transform3D] = []
	var balcony_rails: Array[Transform3D] = []
	var air_conditioners: Array[Transform3D] = []
	var shop_signs: Array[Transform3D] = []
	var shop_doors: Array[Transform3D] = []
	var roof_parapets: Array[Transform3D] = []
	var red_awnings: Array[Transform3D] = []
	var yellow_awnings: Array[Transform3D] = []
	var green_awnings: Array[Transform3D] = []
	for plot in plots:
		var width := rng.randf_range(10.0, 15.0)
		var depth := rng.randf_range(10.0, 15.0)
		var height := rng.randf_range(5.0, 16.0)
		var color: Color = BUILDING_COLORS[index % BUILDING_COLORS.size()]
		_add_box(self, Vector3(width, height, depth), Vector3(plot.x, height * 0.5, plot.y), color, true)
		_add_roof_detail(plot, width, depth, height, rng)
		_add_windows(plot, width, depth, height)
		_add_facade_details(plot, width, depth, height, index, balcony_slabs, balcony_rails, air_conditioners, shop_signs, shop_doors, roof_parapets, red_awnings, yellow_awnings, green_awnings)
		index += 1
	_add_box_batch(self, Vector3(2.6, 0.16, 1.15), balcony_slabs, Color(0.58, 0.56, 0.50))
	_add_box_batch(self, Vector3(2.6, 0.10, 0.10), balcony_rails, Color(0.18, 0.19, 0.18))
	_add_box_batch(self, Vector3(0.75, 0.55, 0.32), air_conditioners, Color(0.78, 0.78, 0.72))
	_add_box_batch(self, Vector3(3.0, 0.65, 0.16), shop_signs, Color(0.12, 0.24, 0.28))
	_add_box_batch(self, Vector3(1.25, 2.25, 0.12), shop_doors, Color(0.20, 0.16, 0.12))
	_add_box_batch(self, Vector3.ONE, roof_parapets, Color(0.48, 0.46, 0.41))
	_add_box_batch(self, Vector3.ONE, red_awnings, MARKET_CANOPY_COLORS[0])
	_add_box_batch(self, Vector3.ONE, yellow_awnings, MARKET_CANOPY_COLORS[1])
	_add_box_batch(self, Vector3.ONE, green_awnings, MARKET_CANOPY_COLORS[2])


func _add_facade_details(
	plot: Vector2,
	width: float,
	depth: float,
	height: float,
	building_index: int,
	balcony_slabs: Array[Transform3D],
	balcony_rails: Array[Transform3D],
	air_conditioners: Array[Transform3D],
	shop_signs: Array[Transform3D],
	shop_doors: Array[Transform3D],
	roof_parapets: Array[Transform3D],
	red_awnings: Array[Transform3D],
	yellow_awnings: Array[Transform3D],
	green_awnings: Array[Transform3D]
) -> void:
	# Street-facing commercial frontage: recessed-looking entrance, sign band,
	# projecting balcony slabs and visible outdoor AC units break up flat masses.
	var front_z := plot.y - depth * 0.5 - 0.10
	shop_doors.append(Transform3D(Basis(), Vector3(plot.x - width * 0.24, 1.15, front_z)))
	shop_signs.append(Transform3D(Basis(), Vector3(plot.x, 2.75, front_z - 0.06)))
	var floor_count := int(floor(height / 3.2))
	for floor_index in range(1, floor_count):
		var floor_y := float(floor_index) * 3.2 + 0.35
		balcony_slabs.append(Transform3D(Basis(), Vector3(plot.x, floor_y, front_z - 0.48)))
		balcony_rails.append(Transform3D(Basis(), Vector3(plot.x, floor_y + 0.62, front_z - 0.98)))
		var ac_x := plot.x + width * 0.32
		air_conditioners.append(Transform3D(Basis(), Vector3(ac_x, floor_y + 0.65, front_z - 0.12)))
	# Scaled unit-cube transforms keep parapets and awnings in shared batches.
	roof_parapets.append(Transform3D(Basis().scaled(Vector3(width + 0.35, 0.22, 0.18)), Vector3(plot.x, height + 0.11, plot.y - depth * 0.5)))
	roof_parapets.append(Transform3D(Basis().scaled(Vector3(width + 0.35, 0.22, 0.18)), Vector3(plot.x, height + 0.11, plot.y + depth * 0.5)))
	roof_parapets.append(Transform3D(Basis().scaled(Vector3(0.18, 0.22, depth)), Vector3(plot.x - width * 0.5, height + 0.11, plot.y)))
	roof_parapets.append(Transform3D(Basis().scaled(Vector3(0.18, 0.22, depth)), Vector3(plot.x + width * 0.5, height + 0.11, plot.y)))
	var awning := Transform3D(Basis().scaled(Vector3(width * 0.82, 0.16, 1.0)), Vector3(plot.x, 3.05, front_z - 0.58))
	match building_index % MARKET_CANOPY_COLORS.size():
		0: red_awnings.append(awning)
		1: yellow_awnings.append(awning)
		2: green_awnings.append(awning)

func _add_roof_detail(plot: Vector2, width: float, depth: float, height: float, rng: RandomNumberGenerator) -> void:
	var roof_height := rng.randf_range(0.5, 1.2)
	_add_box(self, Vector3(width * 0.35, roof_height, depth * 0.35), Vector3(plot.x, height + roof_height * 0.5, plot.y), Color(0.36, 0.37, 0.35))

func _add_windows(plot: Vector2, width: float, depth: float, height: float) -> void:
	var rows := int(max(1.0, floor(height / 2.8)))
	var columns := int(max(2.0, floor(width / 2.5)))
	var front_transforms: Array[Transform3D] = []
	var rear_transforms: Array[Transform3D] = []
	var left_transforms: Array[Transform3D] = []
	var right_transforms: Array[Transform3D] = []

	for row in range(rows):
		for column in range(columns):
			var wx: float = plot.x - width * 0.5 + 1.5 + float(column) * (width - 3.0) / float(max(1, columns - 1))
			var wz: float = plot.y - depth * 0.5 + 1.5 + float(column) * (depth - 3.0) / float(max(1, columns - 1))
			var wy := 1.5 + float(row) * 2.6
			front_transforms.append(Transform3D(Basis(), Vector3(wx, wy, plot.y - depth * 0.5 - 0.035)))
			rear_transforms.append(Transform3D(Basis(), Vector3(wx, wy, plot.y + depth * 0.5 + 0.035)))
			left_transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(plot.x - width * 0.5 - 0.035, wy, wz)))
			right_transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(plot.x + width * 0.5 + 0.035, wy, wz)))

	_add_window_batch(front_transforms, false)
	_add_window_batch(rear_transforms, false)
	_add_window_batch(left_transforms, true)
	_add_window_batch(right_transforms, true)

func _add_window_batch(transforms: Array[Transform3D], side_facing: bool) -> void:
	if transforms.is_empty():
		return
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.85, 1.0, 0.06) if not side_facing else Vector3(0.06, 1.0, 0.85)
	multi_mesh.mesh = window_mesh
	multi_mesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi_mesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi_mesh
	instance.material_override = _material(WINDOW_COLOR)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_street_lights() -> void:
	var poles: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	for z in range(-48, 50, 24):
		for side in [-1.0, 1.0]:
			var pole_x: float = float(side) * 12.8
			poles.append(Transform3D(Basis(), Vector3(pole_x, 2.75, float(z))))
			arms.append(Transform3D(Basis(), Vector3(pole_x + side * 0.4, 5.35, float(z))))
	_add_box_batch(self, Vector3(0.16, 5.5, 0.16), poles, Color(0.18, 0.19, 0.18))
	_add_box_batch(self, Vector3(1.0, 0.16, 0.16), arms, Color(0.18, 0.19, 0.18))

func _add_cylinder(parent: Node3D, radius: float, height: float, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.rotation.z = PI * 0.5
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _add_keke_tricycle() -> void:
	var keke := Node3D.new()
	keke.name = "ParkedKekeTricycle"
	keke.position = Vector3(-4.0, 0.0, -17.0)
	add_child(keke)
	_add_box(keke, Vector3(2.2, 0.85, 1.25), Vector3(0.0, 1.0, 0.0), Color(0.12, 0.38, 0.24))
	_add_box(keke, Vector3(1.5, 0.12, 1.3), Vector3(-0.12, 2.08, 0.0), Color(0.90, 0.70, 0.08))
	_add_box(keke, Vector3(0.06, 0.58, 0.92), Vector3(1.05, 1.65, 0.0), Color(0.10, 0.20, 0.24))
	for side in [-1.0, 1.0]:
		_add_box(keke, Vector3(1.1, 0.52, 0.045), Vector3(-0.18, 1.68, side * 0.63), Color(0.10, 0.20, 0.24))
		_add_cylinder(keke, 0.30, 0.18, Vector3(-0.72, 0.32, side * 0.65), Color(0.07, 0.07, 0.07))
	_add_cylinder(keke, 0.30, 0.18, Vector3(0.78, 0.32, 0.0), Color(0.07, 0.07, 0.07))
	var route_label := Label3D.new()
	route_label.font = ThemeDB.fallback_font
	route_label.text = "KEKE"
	route_label.font_size = 20
	route_label.outline_size = 4
	route_label.position = Vector3(0.0, 1.55, -0.66)
	route_label.rotation.y = PI
	keke.add_child(route_label)

func _add_landmarks() -> void:
	# A compact neighbourhood sign gives this first blockout a recognisable district identity.
	var district_sign := Label3D.new()
	district_sign.font = ThemeDB.fallback_font
	district_sign.text = "YABA  |  LAGOS"
	district_sign.font_size = 72
	district_sign.outline_size = 10
	district_sign.modulate = Color(1.0, 0.88, 0.58)
	district_sign.position = Vector3(0.0, 5.2, -34.0)
	district_sign.rotation.y = PI
	add_child(district_sign)

	# Bus stop shelter inspired by Lagos roadside transport stops.
	_add_box(self, Vector3(7.0, 0.18, 4.0), Vector3(16.0, 2.8, 17.0), Color(0.12, 0.42, 0.30))
	for offset in [-2.8, 2.8]:
		_add_box(self, Vector3(0.14, 2.7, 0.14), Vector3(16.0 + offset, 1.35, 15.5), Color(0.24, 0.22, 0.18))
		_add_box(self, Vector3(0.14, 2.7, 0.14), Vector3(16.0 + offset, 1.35, 18.5), Color(0.24, 0.22, 0.18))
	var stop_label := Label3D.new()
	stop_label.font = ThemeDB.fallback_font
	stop_label.text = "DANFO  |  YABA"
	stop_label.font_size = 32
	stop_label.outline_size = 6
	stop_label.position = Vector3(16.0, 2.1, 14.8)
	stop_label.rotation.y = PI
	add_child(stop_label)
	_add_keke_tricycle()

func _add_market_stalls() -> void:
	var stall_positions: Array[Vector3] = [
		Vector3(-15.0, 0.0, -16.0),
		Vector3(-23.0, 0.0, -16.0),
		Vector3(15.0, 0.0, -16.0),
		Vector3(23.0, 0.0, -16.0)
	]
	var counters: Array[Transform3D] = []
	var supports: Array[Transform3D] = []
	var red_canopies: Array[Transform3D] = []
	var yellow_canopies: Array[Transform3D] = []
	var green_canopies: Array[Transform3D] = []
	var green_crates: Array[Transform3D] = []
	var orange_crates: Array[Transform3D] = []
	var red_crates: Array[Transform3D] = []
	for index in range(stall_positions.size()):
		var origin: Vector3 = stall_positions[index]
		counters.append(Transform3D(Basis(), origin + Vector3(0.0, 0.5, 0.0)))
		for side in [-1.0, 1.0]:
			supports.append(Transform3D(Basis(), origin + Vector3(side * 1.65, 1.1, -0.9)))
		var canopy_transform := Transform3D(Basis(), origin + Vector3(0.0, 2.25, 0.0))
		match index % 3:
			0: red_canopies.append(canopy_transform)
			1: yellow_canopies.append(canopy_transform)
			2: green_canopies.append(canopy_transform)
		green_crates.append(Transform3D(Basis(), origin + Vector3(-0.85, 1.28, 0.0)))
		orange_crates.append(Transform3D(Basis(), origin + Vector3(0.0, 1.28, 0.0)))
		red_crates.append(Transform3D(Basis(), origin + Vector3(0.85, 1.28, 0.0)))
	# Batch repeated stall parts to keep draw calls down on entry-level phones.
	_add_box_batch(self, Vector3(3.2, 1.0, 1.4), counters, Color(0.42, 0.25, 0.14))
	_add_box_batch(self, Vector3(0.10, 2.2, 0.10), supports, Color(0.22, 0.22, 0.20))
	_add_box_batch(self, Vector3(3.8, 0.12, 2.2), red_canopies, MARKET_CANOPY_COLORS[0])
	_add_box_batch(self, Vector3(3.8, 0.12, 2.2), yellow_canopies, MARKET_CANOPY_COLORS[1])
	_add_box_batch(self, Vector3(3.8, 0.12, 2.2), green_canopies, MARKET_CANOPY_COLORS[2])
	_add_box_batch(self, Vector3(0.75, 0.55, 0.65), green_crates, Color(0.32, 0.38, 0.16))
	_add_box_batch(self, Vector3(0.75, 0.55, 0.65), orange_crates, Color(0.68, 0.38, 0.12))
	_add_box_batch(self, Vector3(0.75, 0.55, 0.65), red_crates, Color(0.48, 0.18, 0.14))

func _add_compound_details() -> void:
	# Low compound walls, rooftop water tanks and utility poles are common visual cues
	# in many Lagos neighbourhoods. Keep these as simple static meshes for mobile.
	var compound_walls: Array[Transform3D] = []
	for plot_x in [-25.0, 25.0]:
		for plot_z in [-46.0, -23.0, 0.0, 23.0, 46.0]:
			compound_walls.append(Transform3D(Basis(), Vector3(plot_x - 7.8, 0.625, plot_z)))
			compound_walls.append(Transform3D(Basis(), Vector3(plot_x + 7.8, 0.625, plot_z)))
	_add_box_batch(self, Vector3(0.18, 1.25, 12.0), compound_walls, Color(0.62, 0.57, 0.47))
	# Elevated rooftop tanks: recognisable silhouettes without expensive simulation.
	var tanks: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(-25.0, 16.8, -23.0)),
		Transform3D(Basis(), Vector3(25.0, 13.2, 23.0))
	]
	_add_box_batch(self, Vector3(2.2, 2.6, 2.2), tanks, Color(0.12, 0.25, 0.38))
	# Utility poles and a few overhead cable runs frame the street.
	var utility_poles: Array[Transform3D] = []
	var cable_runs: Array[Transform3D] = []
	for z in [-38.0, 0.0, 38.0]:
		utility_poles.append(Transform3D(Basis(), Vector3(-13.6, 3.5, z)))
		utility_poles.append(Transform3D(Basis(), Vector3(13.6, 3.5, z)))
		cable_runs.append(Transform3D(Basis(), Vector3(0.0, 6.6, z)))
	_add_box_batch(self, Vector3(0.18, 7.0, 0.18), utility_poles, Color(0.20, 0.18, 0.15))
	_add_box_batch(self, Vector3(0.12, 0.12, 27.2), cable_runs, Color(0.08, 0.08, 0.07))
