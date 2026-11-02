extends RefCounted
class_name DistrictPBRMaterials

## Loads pre-imported Poly Haven textures. No runtime network requests.
const ROOT := "res://assets/materials/polyhaven/"
static var _texture_cache: Dictionary = {}
static var _manifest: Dictionary = {}

static func _get_manifest() -> Dictionary:
    if not _manifest.is_empty():
        return _manifest
    var path := ROOT + "manifest.json"
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) == TYPE_DICTIONARY:
        _manifest = parsed.get("assets", {})
    return _manifest

static func apply(material: StandardMaterial3D, asset_id: String, tile_scale: Vector3, tint: Color = Color.WHITE) -> bool:
    if material == null:
        return false
    var manifest := _get_manifest()
    if not manifest.has(asset_id):
        return false
    var maps: Dictionary = manifest[asset_id].get("maps", {})
    var albedo := _load_texture(str(maps.get("diff", {}).get("file", "")))
    var normal := _load_texture(str(maps.get("nor_gl", {}).get("file", "")))
    var roughness := _load_texture(str(maps.get("rough", {}).get("file", "")))
    if albedo == null or normal == null or roughness == null:
        push_warning("District PBR texture set is incomplete; retaining procedural fallback.")
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
    if filename.is_empty():
        return null
    var path := ROOT + filename
    if _texture_cache.has(path):
        return _texture_cache[path] as Texture2D
    if not ResourceLoader.exists(path):
        return null
    var texture := load(path) as Texture2D
    if texture != null:
        _texture_cache[path] = texture
    return texture
