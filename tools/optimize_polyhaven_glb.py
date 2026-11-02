"""Blender background optimizer for a single imported GLB."""
import bpy
import sys
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:]
if len(args) != 2:
    raise SystemExit("Expected source.gltf|source.glb output.glb")
source, output = map(str, args)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=source)

meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if not meshes:
    raise SystemExit("Imported GLB contains no mesh objects")

# Keep the hero building below a mobile-friendly triangle budget. Apply a
# conservative decimation modifier to each mesh, retaining material slots.
for obj in meshes:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new(name="MobileTriangleBudget", type="DECIMATE")
    modifier.ratio = 0.16
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)

triangles = 0
for obj in meshes:
    for polygon in obj.data.polygons:
        triangles += max(1, len(polygon.vertices) - 2)
if triangles > 65000:
    raise SystemExit(f"Optimized facade still exceeds 65k triangles: {triangles}")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=output,
    export_format="GLB",
    export_apply=True,
    export_yup=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
)
print(f"Optimized {len(meshes)} mesh objects to {triangles} triangles")
