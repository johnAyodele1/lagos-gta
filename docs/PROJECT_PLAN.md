# Lagos GTA — Project Plan

## Product direction

Build an original open-world 3D game rooted in Lagos, Nigeria. The project should earn its Lagos identity through recognisable urban layout, street life, transport, architecture, dialogue, sound and missions—not just by using a Lagos title.

## Current playable blockout

- Godot 4 project using the Compatibility renderer.
- Third-person character movement, sprinting and edge-triggered jumping.
- Desktop mouse-look and keyboard movement.
- Touchscreen virtual joystick, drag-to-look, sprint and jump controls, with display safe-area inset handling for notches and home indicators.
- Procedurally generated Yaba-inspired road junction, sidewalks, multi-storey buildings, batched windows, rooftop tanks, compound walls, utility poles, market stalls, produce crates, a danfo stop and district signage.
- A controllable yellow danfo minibus with arcade steering, forward/reverse limits, mobile joystick driving, sprint boost, camera follow and enter/exit interaction.
- Eight ambient traffic vehicles moving in four opposing road lanes, rendered through three shared MultiMesh batches and backed by lightweight AnimatableBody3D collision proxies.
- Four animated placeholder pedestrians walking along the four sidewalk edges using shared MultiMesh batches; replacement with rigged, authored character assets remains an art milestone.
- A lightweight articulated 3D player avatar with a procedural walk cycle, plus a parked keke tricycle landmark.
- Shared material cache and MultiMesh batching for repeated building windows.
- First-run Terms & Conditions and Privacy Notice with explicit consent, versioning, local storage and a persistent legal-access button.
- Automated headless tests for movement normalization, camera pitch limits, joystick deadzone/clamping, vehicle handling, ambient traffic movement/route wrapping and pedestrian sidewalk routes/animation.

This remains a greybox. Player/building and player/traffic collision proxies are now covered by automated physics tests, but the road layout, architecture, vehicles and character art still need replacement before this can be called a convincing Lagos 3D game. It is not a complete GTA-scale game, and mobile touch controls still require physical-device QA.

## Not included yet

- Real-world Yaba road centre-lines and building footprints from a versioned OpenStreetMap extract (not yet integrated).
- Traffic lights, pedestrian crossing/navigation behaviour, vehicle damage, production vehicle models and passenger systems.
- Missions, save system or audio.
- Production-quality art, animation or mobile store release packages.
- Device-specific profiling, physical safe-area validation and accessibility testing.

## Milestones

1. **Vertical slice:** stable player movement, camera, collision and a compact neighbourhood on desktop and touchscreens.
2. **Driving:** first arcade danfo controller, enter/exit interaction, lightweight ambient traffic and animated sidewalk pedestrians implemented; next add traffic lights, pedestrian crossing behaviour, collision tuning and additional vehicles.
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
