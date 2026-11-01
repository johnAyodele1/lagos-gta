# Lagos character asset pipeline

## Source

The project uses [Ara 3D Gen](https://github.com/olatunde85/3d-gen), pinned to commit `2e5724de1b12444bf0c2454555fedfc976a4274c`, as a build-time character generator. Its body data is based on the CC0 MakeHuman dataset; it exports rigged GLB characters and includes photo-based skin textures, hair, clothing and motion-captured animation clips. The export uses the tool's low-detail setting, but the measured GLBs are larger than the tool's nominal 5–10k triangle guidance. Actual output measurements are recorded in `assets/models/asset_manifest.json`.

## Initial character set

- `lagos_male_civilian.glb`: African male streetwear preset, adapted from The Gangster.
- `lagos_female_civilian.glb`: custom adult African female civilian with cornrows, casual tee/jeans and sneakers.
- `lagos_frsc_officer.glb`: Nigerian Federal Road Safety Corps officer preset.
- `lagos_police_officer.glb`: Nigerian Police officer preset.

These are fictional game characters, not scans or likenesses of real people. The generator's MakeHuman body data is CC0. Its code is MIT. The bundled motion-capture clips derive from the CMU Graphics Lab Motion Capture Database; retain its stated use restrictions and do not redistribute the source recordings on their own.

## Build

Run **Import realistic Lagos characters** from GitHub Actions on this feature branch. The workflow checks out the pinned generator, builds its CC0 MakeHuman data, exports low-detail GLBs and commits only the resulting character models. It does not add the 420 MB source dataset or the generator checkout to the game repository.

## Runtime integration and measured budget

The runtime now loads `lagos_male_civilian.glb` for the player and cycles the four imported variants through the sidewalk pedestrian manager. It preserves the source PBR materials, discovers `Idle`, `Walk`, `Run` and `Jump` clips by name, and falls back to the existing Quaternius model if an imported GLB is absent or fails to load. Distant pedestrian meshes are culled at 85 metres.

Measured GLB output:

| Model | Triangles | Materials | Images | Joints | Animation clips |
|---|---:|---:|---:|---:|---:|
| Male civilian | 67,068 | 29 | 20 | 69 | 76 |
| Female civilian | 68,076 | 19 | 19 | 66 | 76 |
| FRSC officer | 26,806 | 17 | 19 | 69 | 76 |
| Police officer | 29,856 | 18 | 19 | 69 | 76 |

The four models total approximately 51 MiB on disk and 191,806 triangles before the player duplicates the male civilian visually. The 76 baked clips are currently retained in the imported GLBs even though gameplay uses only locomotion clips. This is acceptable for the current four-person crowd test, not a final low-end Android budget. Animation pruning, mesh LODs and texture-memory profiling on a physical Android device remain required before increasing the crowd size. Keep the old model fallback until those checks pass.
