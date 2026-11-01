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

func _add_ground() -> void:
	_add_box(self, Vector3(150.0, 0.5, 150.0), Vector3(0.0, -0.35, 0.0), Color(0.28, 0.38, 0.24), true)

func _add_road_network() -> void:
	_add_box(self, Vector3(18.0, 0.08, 130.0), Vector3(0.0, -0.055, 0.0), ROAD_COLOR)
	_add_box(self, Vector3(130.0, 0.08, 18.0), Vector3(0.0, -0.05, 0.0), ROAD_COLOR)
	for side in [-1.0, 1.0]:
		_add_box(self, Vector3(3.0, 0.16, 130.0), Vector3(side * 10.5, 0.0, 0.0), SIDEWALK_COLOR)
		_add_box(self, Vector3(130.0, 0.16, 3.0), Vector3(0.0, 0.0, side * 10.5), SIDEWALK_COLOR)
	for z in range(-58, 60, 8):
		_add_box(self, Vector3(0.18, 0.025, 3.4), Vector3(0.0, 0.0, float(z)), Color(0.88, 0.82, 0.60))
	for x in range(-58, 60, 8):
		_add_box(self, Vector3(3.4, 0.025, 0.18), Vector3(float(x), 0.005, 0.0), Color(0.88, 0.82, 0.60))

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
	for plot in plots:
		var width := rng.randf_range(10.0, 15.0)
		var depth := rng.randf_range(10.0, 15.0)
		var height := rng.randf_range(5.0, 16.0)
		var color: Color = BUILDING_COLORS[index % BUILDING_COLORS.size()]
		_add_box(self, Vector3(width, height, depth), Vector3(plot.x, height * 0.5, plot.y), color, true)
		_add_roof_detail(plot, width, depth, height, rng)
		_add_windows(plot, width, depth, height)
		index += 1

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
	for z in range(-48, 50, 24):
		for side in [-1.0, 1.0]:
			var pole_x: float = float(side) * 12.8
			_add_box(self, Vector3(0.16, 5.5, 0.16), Vector3(pole_x, 2.75, float(z)), Color(0.18, 0.19, 0.18))
			_add_box(self, Vector3(1.0, 0.16, 0.16), Vector3(pole_x + side * 0.4, 5.35, float(z)), Color(0.18, 0.19, 0.18))

func _add_landmarks() -> void:
	# A compact neighbourhood sign gives this first blockout a recognisable district identity.
	var district_sign := Label3D.new()
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
	stop_label.text = "DANFO  |  YABA"
	stop_label.font_size = 32
	stop_label.outline_size = 6
	stop_label.position = Vector3(16.0, 2.1, 14.8)
	stop_label.rotation.y = PI
	add_child(stop_label)

func _add_market_stalls() -> void:
	var stall_positions: Array[Vector3] = [
		Vector3(-15.0, 0.0, -16.0),
		Vector3(-23.0, 0.0, -16.0),
		Vector3(15.0, 0.0, -16.0),
		Vector3(23.0, 0.0, -16.0)
	]
	for index in range(stall_positions.size()):
		var origin: Vector3 = stall_positions[index]
		var canopy_color: Color = MARKET_CANOPY_COLORS[index % MARKET_CANOPY_COLORS.size()]
		# Stall counter and a lightweight coloured canopy are separate visual pieces.
		_add_box(self, Vector3(3.2, 1.0, 1.4), origin + Vector3(0.0, 0.5, 0.0), Color(0.42, 0.25, 0.14))
		_add_box(self, Vector3(3.8, 0.12, 2.2), origin + Vector3(0.0, 2.25, 0.0), canopy_color)
		for side in [-1.0, 1.0]:
			_add_box(self, Vector3(0.10, 2.2, 0.10), origin + Vector3(side * 1.65, 1.1, -0.9), Color(0.22, 0.22, 0.20))
		# Produce crates make the stalls read as market spaces, not generic cubes.
		_add_box(self, Vector3(0.75, 0.55, 0.65), origin + Vector3(-0.85, 1.28, 0.0), Color(0.32, 0.38, 0.16))
		_add_box(self, Vector3(0.75, 0.55, 0.65), origin + Vector3(0.0, 1.28, 0.0), Color(0.68, 0.38, 0.12))
		_add_box(self, Vector3(0.75, 0.55, 0.65), origin + Vector3(0.85, 1.28, 0.0), Color(0.48, 0.18, 0.14))

func _add_compound_details() -> void:
	# Low compound walls, rooftop water tanks and utility poles are common visual cues
	# in many Lagos neighbourhoods. Keep these as simple static meshes for mobile.
	for plot_x in [-25.0, 25.0]:
		for plot_z in [-46.0, -23.0, 0.0, 23.0, 46.0]:
			_add_box(self, Vector3(0.18, 1.25, 12.0), Vector3(plot_x - 7.8, 0.625, plot_z), Color(0.62, 0.57, 0.47))
			_add_box(self, Vector3(0.18, 1.25, 12.0), Vector3(plot_x + 7.8, 0.625, plot_z), Color(0.62, 0.57, 0.47))
	# Elevated rooftop tanks: recognisable silhouettes without expensive simulation.
	for tank_position in [Vector3(-25.0, 16.8, -23.0), Vector3(25.0, 13.2, 23.0)]:
		_add_box(self, Vector3(2.2, 2.6, 2.2), tank_position, Color(0.12, 0.25, 0.38))
	# Utility poles and a few overhead cable runs frame the street.
	for z in [-38.0, 0.0, 38.0]:
		_add_box(self, Vector3(0.18, 7.0, 0.18), Vector3(-13.6, 3.5, z), Color(0.20, 0.18, 0.15))
		_add_box(self, Vector3(0.18, 7.0, 0.18), Vector3(13.6, 3.5, z), Color(0.20, 0.18, 0.15))
		_add_box(self, Vector3(0.12, 0.12, 27.2), Vector3(0.0, 6.6, z), Color(0.08, 0.08, 0.07))
