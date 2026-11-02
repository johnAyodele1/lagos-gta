extends RefCounted
class_name ModelBounds

## Normalizes imported scene geometry to measured world-space dimensions.
## Run after adding the model to the scene tree so nested mesh transforms resolve.

static func fit_height(root: Node3D, target_height: float, center_horizontal: bool = true) -> bool:
	if target_height <= 0.0:
		return false
	var bounds := _combined_local_bounds(root)
	if bounds.size.y <= 0.001:
		push_warning("Cannot normalize model height: no valid mesh bounds were found.")
		return false
	var factor := target_height / bounds.size.y
	root.scale = root.scale * Vector3.ONE * factor
	var offset_x := -bounds.position.x - (bounds.size.x * 0.5 if center_horizontal else 0.0)
	var offset_z := -bounds.position.z - (bounds.size.z * 0.5 if center_horizontal else 0.0)
	root.position += Vector3(offset_x * factor, -bounds.position.y * factor, offset_z * factor)
	return true

static func fit_dimensions(root: Node3D, target_size: Vector3) -> bool:
	if target_size.x <= 0.0 or target_size.y <= 0.0 or target_size.z <= 0.0:
		return false
	var bounds := _combined_local_bounds(root)
	if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
		push_warning("Cannot normalize model dimensions: no valid mesh bounds were found.")
		return false
	var factor := target_size / bounds.size
	root.scale = root.scale * factor
	root.position += Vector3(
		(-bounds.position.x - bounds.size.x * 0.5) * factor.x,
		-bounds.position.y * factor.y,
		(-bounds.position.z - bounds.size.z * 0.5) * factor.z
	)
	return true

static func fit_height_preserve_footprint(root: Node3D, target_height: float, center_horizontal: bool = true) -> bool:
	if target_height <= 0.0:
		return false
	var bounds := _combined_local_bounds(root)
	if bounds.size.y <= 0.001:
		push_warning("Cannot normalize model height: no valid mesh bounds were found.")
		return false
	var factor := target_height / bounds.size.y
	root.scale.y *= factor
	var offset_x := -bounds.position.x - (bounds.size.x * 0.5 if center_horizontal else 0.0)
	var offset_z := -bounds.position.z - (bounds.size.z * 0.5 if center_horizontal else 0.0)
	root.position += Vector3(offset_x, -bounds.position.y * factor, offset_z)
	return true

static func get_scaled_dimensions(root: Node3D) -> Vector3:
	var bounds := _combined_local_bounds(root)
	return Vector3(
		bounds.size.x * absf(root.scale.x),
		bounds.size.y * absf(root.scale.y),
		bounds.size.z * absf(root.scale.z)
	)

static func _combined_local_bounds(root: Node3D) -> AABB:
	# Godot's dummy headless renderer does not expose imported mesh surface bounds.
	# Runtime builds (Android/iOS/desktop) use the measured mesh AABBs below.
	if DisplayServer.get_name() == "headless":
		return AABB()
	var has_bounds := false
	var combined := AABB()
	var mesh_nodes: Array[Node] = []
	if root is MeshInstance3D:
		mesh_nodes.append(root)
	mesh_nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := mesh_bounds.position + Vector3(
				mesh_bounds.size.x if (corner_index & 1) != 0 else 0.0,
				mesh_bounds.size.y if (corner_index & 2) != 0 else 0.0,
				mesh_bounds.size.z if (corner_index & 4) != 0 else 0.0
			)
			var point := _relative_transform(root, mesh_instance) * corner
			if not has_bounds:
				combined = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				combined = combined.expand(point)
	return combined

static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node3D = node
	while current != null and current != root:
		result = current.transform * result
		current = current.get_parent() as Node3D
	if current != root:
		return Transform3D.IDENTITY
	return result
