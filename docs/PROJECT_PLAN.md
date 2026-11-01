# Lagos GTA — Project Plan

## Product direction

Build an original open-world 3D game rooted in Lagos, Nigeria. The project should earn its Lagos identity through recognisable urban layout, street life, transport, architecture, dialogue, sound and missions—not just by using a Lagos title.

## First playable milestone

The first milestone is a small, locally generated Lagos-inspired neighbourhood that can run on modest desktop hardware.

Included in the current prototype:
- Godot 4 project using the Compatibility renderer.
- Third-person character movement, sprinting and jumping.
- Mouse-look camera.
- Procedurally generated road junction, sidewalks, buildings, windows, street lights and a market canopy.
- No external asset downloads required to launch the prototype.

Not included yet:
- Real-world 1:1 Lagos map data.
- Vehicles or enter/exit mechanics.
- Traffic simulation, pedestrians, missions, save system or audio.
- Production-quality art, animation or mobile support.

## Milestones

1. **Vertical slice:** stable player movement, camera, collision and a compact neighbourhood.
2. **Driving:** one controllable vehicle, enter/exit interaction and basic vehicle physics.
3. **Street life:** traffic, pedestrians, market activity and Lagos-specific props.
4. **Mission loop:** objectives, interaction prompts, money and save/load.
5. **World expansion:** researched district layouts and a scalable streaming strategy.
6. **Polish:** performance profiling, accessibility, audio, QA and release builds.

## Engineering constraints

- Keep the game playable on integrated graphics where practical.
- Prefer deterministic procedural generation for blockout geometry.
- Keep gameplay systems separate from world-generation code.
- Do not use copyrighted GTA assets, maps, branding or audio.
- Treat OpenStreetMap and other external geographic data according to their licences and attribution requirements.
- Every milestone must be run and tested; a successful source commit is not proof of a working game build.

## Controls

- WASD: move
- Shift: sprint
- Space: jump
- Mouse: look
- Escape: release/capture mouse
