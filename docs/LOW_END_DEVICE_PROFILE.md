# Low-budget device performance profile

## Current engineering defaults

The prototype is configured around Godot's Compatibility renderer and a conservative mobile baseline:

- Compatibility renderer on desktop and mobile.
- 3D MSAA and screen-space AA disabled in project defaults.
- Dynamic directional-light shadows disabled on mobile.
- Third-person camera far plane capped at 180 metres.
- Repeated windows, road markings, streetlights, market stall parts, compound walls, rooftop tanks and utility props are batched with MultiMesh.
- Shared materials are cached instead of creating a new StandardMaterial3D for every repeated colour.
- Static blockout geometry is simple and does not use expensive physics simulation.
- Ambient traffic is capped at eight visual-only vehicles and rendered through three shared MultiMesh batches (body, cabin and wheels); traffic cars have no individual physics bodies or navigation agents.

These are design choices to reduce GPU state changes, draw calls, memory duplication and shader cost. They are not yet proof of a target frame rate.

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
2. Add distance-based visibility ranges and lower-detail building meshes.
3. Add texture atlases and compressed mobile texture formats once production art is integrated.
4. Keep traffic and pedestrian counts capped and use shared MultiMesh batches or object pools before increasing their counts.
5. Use simple collision proxies; do not use detailed render meshes as physics colliders.
6. Stream neighbourhood chunks and release distant district resources.
7. Provide Low / Balanced / High presets only after profiling proves the settings improve actual devices.
8. Test app resume, thermal throttling, low storage and low-memory background termination.

## Test matrix

Record the exact device model, OS version, renderer, resolution, average FPS, 1% low FPS, memory use, load time, temperature and crash logs. At minimum test one entry-level Android phone, one mid-range Android phone, one smaller supported iPhone and one larger supported iPhone.

Do not advertise low-end compatibility until the minimum device passes the measured release gates.
