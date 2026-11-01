# Lagos GTA — Project Plan

## Product direction

Build an original open-world 3D game rooted in Lagos, Nigeria. The project should earn its Lagos identity through recognisable urban layout, street life, transport, architecture, dialogue, sound and missions—not just by using a Lagos title.

## Current playable blockout

- Godot 4 project using the Compatibility renderer.
- Third-person character movement, sprinting and edge-triggered jumping.
- Desktop mouse-look and keyboard movement.
- Touchscreen virtual joystick, drag-to-look, sprint and jump controls.
- Procedurally generated road junction, sidewalks, buildings, windows, street lights and a market canopy.
- Automated headless tests for movement normalization, camera pitch limits and joystick deadzone/clamping.

This remains a greybox. It is not a complete GTA-scale game, and mobile touch controls still require physical-device QA.

## Not included yet

- Real-world 1:1 Lagos map data.
- Vehicles or enter/exit mechanics.
- Traffic simulation, pedestrians, missions, save system or audio.
- Production-quality art, animation or mobile store release packages.
- Device-specific profiling, safe-area validation and accessibility testing.

## Milestones

1. **Vertical slice:** stable player movement, camera, collision and a compact neighbourhood on desktop and touchscreens.
2. **Driving:** one controllable vehicle, enter/exit interaction and basic vehicle physics.
3. **Street life:** traffic, pedestrians, market activity and Lagos-specific props.
4. **Mobile release foundation:** Android/iOS export templates and presets, signing configuration, safe-area checks, device profiling and store compliance.
5. **Mission loop:** objectives, interaction prompts, money and save/load.
6. **World expansion:** researched district layouts and a scalable streaming strategy.
7. **Polish:** performance profiling, accessibility, audio, QA and release builds.

## Engineering constraints

- Keep the game playable on integrated graphics and target mobile devices where practical.
- Prefer deterministic procedural generation for blockout geometry.
- Keep gameplay systems separate from world-generation and input presentation code.
- Avoid per-frame allocations in hot gameplay paths.
- Profile draw calls, physics cost, memory and frame time on representative iOS and Android hardware.
- Do not use copyrighted GTA assets, maps, branding or audio.
- Treat OpenStreetMap and other external geographic data according to their licences and attribution requirements.
- Every milestone must be run and tested; a successful source commit is not proof of a working game build.

## Controls

### Desktop
- WASD: move
- Shift: sprint
- Space: jump
- Mouse: look
- Escape: release/capture mouse

### Touchscreen
- Left virtual joystick: move
- Drag on right side: look
- RUN: sprint while held
- JUMP: jump once per tap
