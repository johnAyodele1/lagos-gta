# Lagos GTA — Project Plan

## Product direction

Build an original open-world 3D game rooted in Lagos, Nigeria. The project should earn its Lagos identity through researched street geometry, architecture, transport, street life, dialogue, sound and missions—not just by using a Lagos title.

## Current playable Yaba vertical slice

- Godot 4 project using the Compatibility renderer.
- The main scene now loads a versioned OpenStreetMap extract for Yaba instead of the invented crossroad blockout. The extract currently contains 587 road ways, 7,470 building footprints and mapped barrier ways, with ODbL attribution preserved.
- The runtime builds a 450m playable radius, selecting up to 450 road ways and 2,200 nearby building footprints. Missing OSM widths/heights use documented estimates, not survey measurements.
- Actual road centre-lines are converted into 3D asphalt surfaces. The world generator adds sidewalks, roadside drainage, extruded building footprints, windows, shop doors/signboards/awnings, balconies, roof parapets, water tanks, mapped compound walls/fences, utility poles and overhead wires. Repeated facade and street details use MultiMesh batches.
- Building footprints and mapped barriers receive static collision geometry. Player physics tests verify the character cannot walk through OSM-derived walls or mapped compound barriers.
- The third-person camera uses a collision-aware SpringArm3D so it retracts instead of clipping through buildings.
- The drivable danfo is now a custom tapered 3D mesh with a shaped body/cabin, glazing, sliding-door details, side stripe, bumpers, lights, wheels and a Yaba/Tejuosho route board. It is still an authored procedural model, not a final licensed production asset.
- Ambient traffic is capped at eight custom tapered 3D cars and follows real OSM road polylines rather than hard-coded north/south/east/west lanes. Each car has a low-cost collision proxy.
- Four pedestrians follow sidewalk offsets derived from OSM road geometry. They use a custom torso mesh, head/hair/limbs and simple walk animation, with capsule collision proxies. They are still low-poly placeholder characters, not final rigged human assets.
- Player avatar now has a custom tapered torso, layered clothing, face/hair details, articulated limbs and a procedural walk cycle.
- Balanced mobile lighting uses two directional-shadow splits, a 1,024px atlas and a 90m shadow distance. Low and High graphics profiles are available through `user://settings.cfg`.
- Desktop keyboard/mouse and touchscreen joystick/look/sprint/jump controls remain supported.
- First-run Terms & Conditions and Privacy Notice include explicit consent, versioning, local storage and a persistent legal-access button.

This is a functional early vertical slice, not a finished GTA-scale game. The world is geographically grounded, but its art is still low-poly/procedural. It must not be described as photorealistic or release-ready. Android/iOS performance and the actual in-device visual result still require physical-device QA.

## Remaining visual and gameplay blockers

- Replace procedural danfo/traffic/player/pedestrian meshes with optimized, properly licensed production 3D assets and rigged animations. The current meshes are a visual step forward, not the final art standard.
- Improve PBR materials, road wear, concrete, corrugated roofing, shop signs, decals, vegetation, drainage covers and street clutter using a documented asset/texture pipeline.
- OSM currently provides mapped road and building geometry; building height/width defaults are estimates, and mapped fence/barrier coverage is sparse. Validate the playable area against current local imagery and add surveyed/appropriately licensed compound boundaries where available.
- Split the district into streamable chunks with LODs and distance culling. The current 450m radius and 2,200-building cap are an initial bounded slice, not an open-world streaming system.
- Add traffic signals, intersection priority, pedestrian crossings, vehicle damage, passenger systems and collision-aware NPC navigation.
- Profile GPU frame time, CPU frame time, draw calls, physics cost, memory and thermal behaviour on representative low-end Android, Samsung S21-class, and iOS devices.
- Missions, save system, audio and broader district expansion.
- Android/iOS release packages, signing, store compliance, final publisher legal review and public policy hosting.

## Milestones

1. **Yaba world foundation:** real OSM road/building geometry, static collision, street surfaces, first-pass Lagos facade details and mobile-safe rendering.
2. **Movement and camera:** collision-safe player, spring-arm camera, danfo enter/exit and physical-device controls.
3. **Street life:** OSM-routed traffic and pedestrians; next add traffic rules, crossings, richer NPC behaviour and additional vehicle types.
4. **Production art:** replace procedural placeholder meshes with optimized, licensed 3D vehicle and character assets, PBR textures, LODs and authored animations.
5. **Mobile release foundation:** Android/iOS export templates and presets, signing configuration, safe-area checks, device profiling and store compliance.
6. **Mission loop:** objectives, interactions, money and save/load.
7. **World expansion:** researched district layouts, chunk streaming and additional Lagos neighbourhoods.
8. **Polish:** performance profiling, accessibility, audio, QA and release builds.

## Engineering constraints

- Keep the game playable on integrated graphics and target mobile devices where practical.
- Geographic source data must be versioned, reproducible and attributed. Preserve each source's licence and distinguish measured tags from estimates.
- Keep gameplay systems separate from world-generation and input presentation code.
- Avoid per-frame allocations in hot gameplay paths.
- Batch repeated geometry, keep physics colliders simpler than render meshes and cap moving bodies.
- Profile draw calls, physics cost, memory and frame time on representative iOS and Android hardware.
- Do not use copyrighted GTA assets, maps, branding or audio.
- Every milestone must be run and tested; a successful source commit is not proof of a working game build.

## Controls

### Desktop
- WASD: move
- Shift: sprint
- Space: jump
- E: enter/exit danfo
- Mouse: look
- Escape: release/capture mouse

### Touchscreen
- Left virtual joystick: move
- Drag on right side: look
- RUN: sprint while held
- JUMP: jump once per tap; enter/exit when near the danfo
