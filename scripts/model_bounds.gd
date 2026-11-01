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

static func _combined_local_bounds(root: Node3D) -> AABB:
	var has_bounds := false
	var combined := AABB()
	for node in root.find_children("*", "MeshInstance3D", true, false):
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
			var point := root.to_local(mesh_instance.to_global(corner))
			if not has_bounds:
				combined = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				combined = combined.expand(point)
	return combined
