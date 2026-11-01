# Lagos GTA — Project Plan

## Product direction

Build an original open-world 3D game rooted in Lagos, Nigeria. The project should earn its Lagos identity through recognisable urban layout, street life, transport, architecture, dialogue, sound and missions—not just by using a Lagos title.

## Current playable blockout

- Godot 4 project using the Compatibility renderer.
- Third-person character movement, sprinting and edge-triggered jumping.
- Desktop mouse-look and keyboard movement.
- Touchscreen virtual joystick, drag-to-look, sprint and jump controls.
- Procedurally generated Yaba-inspired road junction, sidewalks, multi-storey buildings, batched windows, rooftop tanks, compound walls, utility poles, market stalls, produce crates, a danfo stop and district signage.
- A controllable yellow danfo minibus with arcade steering, forward/reverse limits, mobile joystick driving, sprint boost, camera follow and enter/exit interaction.
- Eight ambient traffic vehicles moving in four opposing road lanes, with vehicle transforms updated in three shared MultiMesh batches and no per-car physics bodies.
- A lightweight articulated 3D player avatar with a procedural walk cycle, plus a parked keke tricycle landmark.
- Shared material cache and MultiMesh batching for repeated building windows.
- First-run Terms & Conditions and Privacy Notice with explicit consent, versioning, local storage and a persistent legal-access button.
- Automated headless tests for movement normalization, camera pitch limits, joystick deadzone/clamping, vehicle handling and ambient traffic movement/route wrapping.

This remains a greybox. It is not a complete GTA-scale game, and mobile touch controls still require physical-device QA.

## Not included yet

- Real-world 1:1 Lagos map data.
- Pedestrians, traffic lights, collision-aware traffic, vehicle damage, vehicle variety or passenger systems.
- Missions, save system or audio.
- Production-quality art, animation or mobile store release packages.
- Device-specific profiling, safe-area validation and accessibility testing.

## Milestones

1. **Vertical slice:** stable player movement, camera, collision and a compact neighbourhood on desktop and touchscreens.
2. **Driving:** first arcade danfo controller, enter/exit interaction and lightweight ambient traffic implemented; next add traffic lights, pedestrian-aware driving, collision tuning and additional vehicles.
3. **Street life:** traffic, pedestrians, market activity and Lagos-specific props.
4. **Mobile release foundation:** Android/iOS export templates and presets, signing configuration, safe-area checks, device profiling and store compliance. Player-facing legal drafts and a versioned consent gate are now in place; final publisher details, legal review and public policy hosting remain release blockers.
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
