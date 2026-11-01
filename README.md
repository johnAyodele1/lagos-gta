# Lagos GTA

An original open-world 3D game project rooted in Lagos, Nigeria.

## Current status

**Playable prototype in development.** The current branch contains a Godot 4 third-person blockout with a procedurally generated Lagos-inspired starter district. It is a greybox foundation, not a finished GTA-scale game.

Mobile touch controls are now implemented in the prototype: left virtual joystick, right-side drag camera, sprint and jump buttons. Android/iOS export packaging and real-device performance QA are separate release tasks; this branch is not yet a signed mobile release.

## Run locally

1. Install Godot 4.3 or a compatible Godot 4.x release.
2. Clone this repository.
3. Open the repository folder in Godot.
4. Run the project (F6/F5, or the Play button).

No third-party asset packs are required to launch the initial scene.

## Controls

### Desktop
| Input | Action |
|---|---|
| WASD | Move |
| Shift | Sprint |
| Space | Jump (press once per jump) |
| Mouse | Look around |
| Escape | Release / capture mouse |

### Touchscreen
| Control | Action |
|---|---|
| Left virtual joystick | Move |
| Drag on the right side | Look around |
| RUN button | Sprint while held |
| JUMP button | Jump once per tap |

## Technology

- Godot 4 / GDScript
- Compatibility renderer, including mobile renderer setting
- Procedural blockout geometry for the first district
- Headless gameplay input tests in GitHub Actions

## Roadmap

1. Stabilise the third-person vertical slice on desktop and touch devices.
2. Add a drivable vehicle and enter/exit interaction.
3. Add Lagos street life: danfos, traffic, pedestrians, markets and audio.
4. Add Android/iOS export presets, signing setup, device profiling and store-ready release builds.
5. Build mission, interaction and save systems.
6. Expand the world using researched district layouts and properly licensed geographic data.

See [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) for scope and engineering constraints.

## Project principles

- Build and test playable systems, not just screenshots.
- Profile on actual target devices; editor/headless success is not mobile performance proof.
- Keep draw calls, physics bodies, memory and texture sizes under control for phones.
- Do not use copyrighted GTA assets, maps, branding or audio.
- Credit and comply with the licences of any external geographic data and assets.
