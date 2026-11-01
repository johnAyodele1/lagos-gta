extends RefCounted
class_name GraphicsProfile

## Explicit graphics budgets. Balanced keeps a short directional shadow on phones;
## Low removes dynamic shadows for older GPUs; High is intended for desktop hardware.

static func get_profile(quality: String) -> Dictionary:
	match quality.to_lower():
		"low":
			return {
				"name": "low",
				"shadows": false,
				"shadow_splits": 1,
				"shadow_distance": 55.0,
				"shadow_atlas_size": 512,
				"far_clip": 120.0
			}
		"high":
			return {
				"name": "high",
				"shadows": true,
				"shadow_splits": 4,
				"shadow_distance": 160.0,
				"shadow_atlas_size": 2048,
				"far_clip": 300.0
			}
		_:
			return {
				"name": "balanced",
				"shadows": true,
				"shadow_splits": 2,
				"shadow_distance": 90.0,
				"shadow_atlas_size": 1024,
				"far_clip": 220.0
			}

static func apply(sun: DirectionalLight3D, quality: String) -> Dictionary:
	var profile := get_profile(quality)
	sun.shadow_enabled = bool(profile["shadows"])
	sun.directional_shadow_max_distance = float(profile["shadow_distance"])
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.0
	match int(profile["shadow_splits"]):
		1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		2:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size(int(profile["shadow_atlas_size"]), true)
	return profile
