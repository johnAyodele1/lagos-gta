# Lagos character asset pipeline

## Source

The project uses [Ara 3D Gen](https://github.com/olatunde85/3d-gen), pinned to commit `2e5724de1b12444bf0c2454555fedfc976a4274c`, as a build-time character generator. Its body data is based on the CC0 MakeHuman dataset; it exports rigged GLB characters and includes photo-based skin textures, hair, clothing and motion-captured animation clips. The tool documents a low-detail tier of roughly 5–10k triangles, which is the selected starting point for Android profiling.

## Initial character set

- `lagos_male_civilian.glb`: African male streetwear preset, adapted from The Gangster.
- `lagos_female_civilian.glb`: custom adult African female civilian with cornrows, casual tee/jeans and sneakers.
- `lagos_frsc_officer.glb`: Nigerian Federal Road Safety Corps officer preset.
- `lagos_police_officer.glb`: Nigerian Police officer preset.

These are fictional game characters, not scans or likenesses of real people. The generator's MakeHuman body data is CC0. Its code is MIT. The bundled motion-capture clips derive from the CMU Graphics Lab Motion Capture Database; retain its stated use restrictions and do not redistribute the source recordings on their own.

## Build

Run **Import realistic Lagos characters** from GitHub Actions on this feature branch. The workflow checks out the pinned generator, builds its CC0 MakeHuman data, exports low-detail GLBs and commits only the resulting character models. It does not add the 420 MB source dataset or the generator checkout to the game repository.

The imported GLBs are not wired into gameplay automatically by this pipeline. Before replacing the existing player or pedestrian assets, validate skeleton compatibility, animation clip names, forward axis, scale, draw calls and texture memory in Godot. Keep the current character assets as fallbacks until the new models pass those checks on the Compatibility renderer and a physical Android device.
