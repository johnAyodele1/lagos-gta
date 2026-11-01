extends RefCounted
class_name CharacterMeshFactory

## Shared low-poly human body meshes. The torso is a tapered organic loft,
## not a box or a single capsule; limb animation remains inexpensive.

static func create_torso_mesh(segments: int = 12) -> ArrayMesh:
	var sections: Array[Dictionary] = [
		{"y": -0.42, "rx": 0.22, "rz": 0.13},
		{"y": -0.27, "rx": 0.24, "rz": 0.145},
		{"y": 0.08, "rx": 0.29, "rz": 0.16},
		{"y": 0.30, "rx": 0.32, "rz": 0.16},
		{"y": 0.42, "rx": 0.25, "rz": 0.13}
	]
	var rings: Array[PackedVector3Array] = []
	for section in sections:
		var ring := PackedVector3Array()
		for index in range(segments):
			var angle := TAU * float(index) / float(segments)
			ring.append(Vector3(
				cos(angle) * float(section["rx"]),
				float(section["y"]),
				sin(angle) * float(section["rz"])
			))
		rings.append(ring)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(rings.size() - 1):
		for index in range(segments):
			var next_index := (index + 1) % segments
			var a := rings[ring_index][index]
			var b := rings[ring_index + 1][index]
			var c := rings[ring_index][next_index]
			var d := rings[ring_index + 1][next_index]
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(d)
	for cap_index in [0, rings.size() - 1]:
		var ring: PackedVector3Array = rings[cap_index]
		var center := Vector3.ZERO
		for point in ring:
			center += point
		center /= float(ring.size())
		for index in range(segments):
			var next_index := (index + 1) % segments
			surface.add_vertex(center)
			if cap_index == 0:
				surface.add_vertex(ring[index])
				surface.add_vertex(ring[next_index])
			else:
				surface.add_vertex(ring[next_index])
				surface.add_vertex(ring[index])
	surface.generate_normals()
	return surface.commit()
