extends RefCounted
class_name DistrictPBRMaterials

## Loads pre-imported Poly Haven textures. No runtime network requests.
const ROOT := "res://assets/materials/polyhaven/"
const MAPS := {
    "asphalt_02": ["asphalt_02_diff.jpg", "asphalt_02_nor_gl.png", "asphalt_02_rough.jpg"],
    "concrete_floor": ["concrete_floor_diff.jpg", "concrete_floor_nor_gl.png", "concrete_floor_rough.jpg"],
    "corrugated_iron": ["corrugated_iron_diff.jpg", "corrugated_iron_nor_gl.png", "corrugated_iron_rough.jpg"]
}
static var _texture_cache: Dictionary = {}

static func apply(material: StandardMaterial3D, asset_id: String, tile_scale: Vector3, tint: Color = Color.WHITE) -> bool:
    if material == null or not MAPS.has(asset_id):
        return false
    var paths: Array = MAPS[asset_id]
    var albedo := _load_texture(str(paths[0]))
    var normal := _load_texture(str(paths[1]))
    var roughness := _load_texture(str(paths[2]))
    if albedo == null or normal == null or roughness == null:
        push_warning("District PBR set '%s' is not imported yet; keeping its procedural fallback." % asset_id)
        return false
    material.albedo_color = tint
    material.albedo_texture = albedo
    material.normal_enabled = true
    material.normal_texture = normal
    material.normal_scale = 0.55
    material.roughness_texture = roughness
    material.roughness = 0.94
    material.uv1_scale = tile_scale
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return true

static func _load_texture(filename: String) -> Texture2D:
    var path := ROOT + filename
    if _texture_cache.has(path):
        return _texture_cache[path] as Texture2D
    if not ResourceLoader.exists(path):
        return null
    var texture := load(path) as Texture2D
    if texture != null:
        _texture_cache[path] = texture
    return texture
