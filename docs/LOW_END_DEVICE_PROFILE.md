# Low-budget device performance profile

## Current engineering defaults

The prototype is configured around Godot's Compatibility renderer and a conservative mobile baseline:

- Compatibility renderer on desktop and mobile.
- 3D MSAA and screen-space AA disabled in project defaults.
- Balanced mobile profile uses two directional-shadow splits, a 1,024px shadow atlas and a 90m shadow distance; Low disables dynamic shadows and uses a 512px atlas.
- Camera far plane is 120m (Low), 220m (Balanced) or 300m (High); a collision-aware SpringArm3D keeps the camera out of mapped walls.
- Repeated windows, road markings, shopfront details, compound walls, rooftop tanks and utility props are batched with MultiMesh.
- Shared materials are cached instead of creating a new StandardMaterial3D for every repeated colour.
- Mapped static buildings are combined into shared render geometry; static collision is simpler than the visible meshes.
- Ambient traffic is capped at eight vehicles and follows OSM road polylines. Five shared MultiMesh batches render custom tapered 3D vehicle meshes, windows, lights and wheels; each vehicle uses one simple AnimatableBody3D collision proxy.
- Sidewalk pedestrians are capped at four, follow OSM-derived sidewalk offsets and use five shared MultiMesh batches (custom torso, head, hair, arms and legs), plus four capsule collision proxies.

The OSM importer currently supplies 587 mapped road ways and 7,470 building footprints; the runtime generator caps the initial playable radius to 450m and selects up to 2,200 buildings and 450 roads. These are engineering budgets, not proof of a target frame rate. The in-game QUALITY button cycles Low / Balanced / High and persists the selection to `user://settings.cfg` (`[graphics] quality`).

## Proposed performance acceptance targets

Treat these as release gates to measure, not as current benchmark results:

| Metric | Initial target |
|---|---:|
| Frame rate on minimum supported device | 30 FPS sustained |
| Frame time | 33.3 ms budget |
| Severe frame-time spikes | No recurring spikes above 100 ms during normal walking |
| Resolution baseline | 1280 × 720 project viewport, scaled by device |
| Gameplay input | No touch latency or stuck inputs during normal play |
| Thermal behaviour | No sustained thermal throttling during a 20-minute session |
| Startup | No avoidable network dependency before first playable scene |

The final minimum supported Android/iOS devices must be selected only after real-device profiling.

## Next optimization work

1. Profile draw calls, primitives, physics bodies, memory and frame time on real devices.
2. Split the 450m playable district into streaming chunks and add distance-based visibility/LOD for OSM buildings.
3. Add texture atlases and compressed mobile texture formats once production art is integrated.
4. Keep traffic and pedestrian counts capped and use shared MultiMesh batches or object pools before increasing their counts.
5. Use simple collision proxies for traffic and player interaction; do not use detailed render meshes as physics colliders. Keep moving collider count capped and measure physics time on target devices.
6. Stream neighbourhood chunks and release distant district resources.
7. Profile Low / Balanced / High presets on physical devices and tune atlas size, shadow distance, view distance and object counts.
8. Test app resume, thermal throttling, low storage and low-memory background termination.

## Test matrix

Record the exact device model, OS version, renderer, resolution, average FPS, 1% low FPS, memory use, load time, temperature and crash logs. At minimum test one entry-level Android phone, one mid-range Android phone, one smaller supported iPhone and one larger supported iPhone.

Do not advertise low-end compatibility until the minimum device passes the measured release gates.
