# Lagos GTA

An original open-world 3D game project rooted in Lagos, Nigeria.

## Current status

**Playable Yaba vertical slice in development.** The main scene now builds from a versioned OpenStreetMap extract for Yaba rather than an invented four-way junction. The extract currently contains 587 mapped road ways and 7,470 building footprints; runtime generation is bounded to a 450m radius, up to 450 roads and 2,200 nearby buildings.

The district includes extruded building footprints, textured asphalt and concrete, road markings, sidewalks, roadside drainage, shopfronts, mapped shop names, balconies, exterior AC units, rooftop water tanks, parapets, utility poles, crossarms, overhead wiring and streetlights. Mapped barriers have collision. Up to 24 additional low residential compound walls are art-directed around selected isolated residential footprints; these are not surveyed property boundaries.

The player has a custom low-poly avatar and collision-aware third-person camera. The danfo is a custom tapered 3D minibus mesh. Ambient cars and pedestrians follow road/sidewalk routes derived from the OSM geometry. Player, building, barrier, compound-wall, vehicle and NPC collision tests are included.

A licensed architecture import pipeline brings a CC0 Poly Haven modular apartment facade into the project at build time (no runtime download). The world generator uses it on one selected residential frontage; all other OSM buildings retain data-driven procedural facades. The model is generic modern architecture, not a surveyed Yaba building. See [the architecture asset pipeline](docs/ARCHITECTURE_ASSET_PIPELINE.md).

This is still an early vertical slice, not a finished GTA-scale game or photorealistic world. The current in-game vehicles and characters are procedural low-poly models; production-quality licensed vehicle assets and properly rigged human models remain outstanding. The 450m district is not a streaming open world. Physical Android/iOS profiling and signed store builds have not been completed.

## Run locally

1. Install Godot 4.3 or a compatible Godot 4.x release.
2. Clone this repository.
3. Open the repository folder in Godot.
4. Run the project (F6/F5, or the Play button).

The OSM data extract is included in `assets/data/yaba_osm.json`. Attribution is shown in the game HUD. See `data/osm/README.md` for source and licence details.

## Controls

### Desktop

| Input | Action |
|---|---|
| WASD | Move |
| Shift | Sprint |
| Space | Jump |
| E | Enter / exit danfo when close |
| Mouse | Look around |
| Escape | Release / capture mouse |

### Touchscreen

| Control | Action |
|---|---|
| Left virtual joystick | Move |
| Drag on the right side | Look around |
| RUN button | Sprint while held |
| JUMP button | Jump once per tap; enter/exit danfo when close |
| QUALITY button | Cycle Low / Balanced / High graphics profiles |

## Technology

- Godot 4.3 / GDScript
- Compatibility renderer for desktop and mobile
- Versioned OpenStreetMap extract (ODbL attribution)
- Custom procedural 3D meshes and MultiMesh batching
- Collision-aware player, vehicle, traffic and pedestrian systems
- GitHub Actions: Godot import, gameplay tests and main-scene smoke test

## Verification

The latest verified branch run passed **118 gameplay tests** and the main-scene smoke check. This verifies engine/script behaviour; it does not establish a frame-rate target or replace physical-device testing.

## Roadmap and release gates

1. Optimize the newly imported rigged player/pedestrian models with LODs and animation/texture budgets; expand the architecture library with locally appropriate building variants and replace remaining procedural facades.
2. Add LODs and chunk streaming beyond the current 450m district.
3. Profile GPU/CPU frame time, memory, draw calls, physics and thermals on representative low-end Android, Samsung S21-class and iOS devices.
4. Add more Lagos districts, traffic rules, pedestrian crossings, missions, audio and save/load.
5. Complete Android/iOS export templates, signing, store compliance, publisher legal review and release QA.

See [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md), [docs/LOW_END_DEVICE_PROFILE.md](docs/LOW_END_DEVICE_PROFILE.md), [docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md), [docs/TERMS_OF_SERVICE.md](docs/TERMS_OF_SERVICE.md), [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) and [docs/STORE_SUBMISSION_CHECKLIST.md](docs/STORE_SUBMISSION_CHECKLIST.md).

## Project principles

- Build and test playable systems, not just screenshots.
- Never describe a greybox or low-poly prototype as photorealistic or release-ready.
- Profile on actual target devices; editor/headless success is not mobile performance proof.
- Keep draw calls, physics bodies, memory and texture sizes under control.
- Do not use copyrighted GTA assets, maps, branding or audio.
- Preserve source-data attribution and licences.


A second build-time pipeline imports rigged Lagos civilian, female, FRSC and Nigerian Police characters from the pinned Ara 3D Gen / MakeHuman CC0 source. The player and sidewalk pedestrians now load these textured models with the existing character as a fallback; see [the character asset pipeline](docs/CHARACTER_ASSET_PIPELINE.md). The Yaba OSM extract is enriched with OpenBuildingMap heights and occupancy (7,417 OSM matches, 285 height enrichments and 5,008 occupancy classifications), while OSM footprints remain authoritative; see [asset and data credits](assets/models/ASSET_CREDITS.md).
