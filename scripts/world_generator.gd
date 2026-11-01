extends Node3D
class_name WorldGenerator

const ROAD_COLOR := Color(0.12, 0.13, 0.14)
const SIDEWALK_COLOR := Color(0.48, 0.46, 0.40)
const BUILDING_COLORS: Array[Color] = [
	Color(0.76, 0.64, 0.48),
	Color(0.72, 0.72, 0.66),
	Color(0.68, 0.49, 0.36),
	Color(0.80, 0.76, 0.64),
	Color(0.56, 0.60, 0.56)
]

func generate() -> void:
	_add_ground()
	_add_road_network()
	_add_buildings()
	_add_street_lights()
	_add_landmarks()

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
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
	for row in range(rows):
		for column in range(columns):
			var wx := plot.x - width * 0.5 + 1.5 + float(column) * (width - 3.0) / max(1, columns - 1)
			var wy := 1.5 + float(row) * 2.6
			_add_box(self, Vector3(0.85, 1.0, 0.06), Vector3(wx, wy, plot.y - depth * 0.5 - 0.035), Color(0.16, 0.27, 0.32))
			_add_box(self, Vector3(0.06, 1.0, 0.85), Vector3(plot.x + width * 0.5 + 0.035, wy, plot.y - depth * 0.5 + 1.5 + float(column) * 1.8), Color(0.16, 0.27, 0.32))

func _add_street_lights() -> void:
	for z in range(-48, 50, 24):
		for side in [-1.0, 1.0]:
			var pole_x := side * 12.8
			_add_box(self, Vector3(0.16, 5.5, 0.16), Vector3(pole_x, 2.75, float(z)), Color(0.18, 0.19, 0.18))
			_add_box(self, Vector3(1.0, 0.16, 0.16), Vector3(pole_x + side * 0.4, 5.35, float(z)), Color(0.18, 0.19, 0.18))

func _add_landmarks() -> void:
	_add_box(self, Vector3(7.0, 0.18, 4.0), Vector3(16.0, 2.8, 17.0), Color(0.12, 0.42, 0.30))
	for offset in [-2.8, 2.8]:
		_add_box(self, Vector3(0.14, 2.7, 0.14), Vector3(16.0 + offset, 1.35, 15.5), Color(0.24, 0.22, 0.18))
		_add_box(self, Vector3(0.14, 2.7, 0.14), Vector3(16.0 + offset, 1.35, 18.5), Color(0.24, 0.22, 0.18))
