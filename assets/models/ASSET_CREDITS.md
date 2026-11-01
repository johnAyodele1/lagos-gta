# 3D asset provenance

All bundled source models in this directory are free to use under the licences below.
Original creators and source locations are retained for attribution and auditability.

## Player character

- Asset: `characters/lagos_player.glb`
- Creator: Quaternius
- Source mirror: https://github.com/kendrekaran/striker-3d/tree/main/assets
- Licence: CC0 1.0 Universal
- Licence evidence: `characters/LICENSE-quaternius.txt`

## Traffic vehicles

- Assets: `vehicles/quaternius/{NormalCar1,NormalCar2,SUV,Taxi}.{obj,mtl}`
- Creator: Quaternius
- Pack: Realistic Car Pack – Nov 2018
- Licence: CC0 1.0 Universal
- Official source and licence: https://quaternius.itch.io/lowpoly-cars
- Source mirror: https://github.com/SteveSmith16384/splitscreenfps_libgdx/tree/master/core/assets/carpark/models/quaternius

## Danfo base vehicle

- Assets: `vehicles/danfo/car-minibus-citrus.{obj,mtl}`
- Creator: eracoon (Jim van Hazendonk)
- Pack: Vehicles Assets pt1
- Licence: CC0
- Source: https://opengameart.org/content/vehicles-assets-pt1
- Source mirror: https://github.com/jackbauertv24-droid/3d-bus-viewer/tree/main/models/vehicle-assets

The minibus is a generic CC0 base mesh, not a scanned or exact Lagos Danfo vehicle. The game applies Lagos yellow paint, destination signage and route-specific details.

## 3D signage font

- Asset: `fonts/Roboto.ttf`
- Creator: Google Fonts / Roboto contributors
- Licence: SIL Open Font Licence 1.1
- Licence text: `fonts/OFL.txt`
- Source: https://github.com/google/fonts/tree/main/ofl/roboto

## Architecture hero facade

- Asset: `architecture/modular_urban_apartments_facade.glb`
- Creator: James Ray Cock
- Source: https://polyhaven.com/a/modular_urban_apartments_facade
- Licence: CC0 1.0 Universal
- Asset distribution: official Poly Haven files API; imported at build time and bundled locally. The game does not make runtime API requests.
- Runtime integration: one selected mapped Yaba residential frontage, scaled against the OSM footprint and resolved building height. The measured GLB is 270,045 triangles and 41.3 MB; do not instance it district-wide. The source asset is not repeated across the district.

## Character generation pipeline

- Generator: [Ara 3D Gen](https://github.com/olatunde85/3d-gen), pinned to commit `2e5724de1b12444bf0c2454555fedfc976a4274c`
- Generator code: MIT
- Body and base character data: MakeHuman CC0 data as documented by Ara 3D Gen
- Animation source: CMU Graphics Lab Motion Capture Database; retain its stated restrictions and do not redistribute source recordings separately
- Output: low-detail rigged GLB characters generated for Lagos civilian, female civilian, FRSC officer and Nigerian Police roles
- These are generated fictional characters, not scans or likenesses of real people

## Building data enrichment

- Geometry and original OSM tags: OpenStreetMap contributors, ODbL-1.0
- Height and occupancy enrichment: OpenBuildingMap, GFZ Data Services, ODbL-1.0, DOI https://doi.org/10.5880/GFZ.LKUT.2025.002
- Join key: matching OSM way ID only; OpenBuildingMap Google/Microsoft-only footprints are not added to the existing OSM scene
- Height estimates remain estimates; explicit OSM height values take precedence
