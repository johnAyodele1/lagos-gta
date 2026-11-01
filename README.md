# Lagos GTA

An original open-world 3D game project rooted in Lagos, Nigeria.

## Current status

**Playable prototype in development.** The current branch contains a Godot 4 third-person blockout with a procedurally generated Lagos-inspired starter district. It is a greybox foundation, not a finished GTA-scale game.

Mobile touch controls are implemented. The player avatar now uses a lightweight articulated 3D primitive rig with a simple walk cycle; the Yaba market includes a static keke tricycle and a drivable danfo. The starter district is being expanded with Yaba street identity, roadside market stalls, a danfo stop, rooftop water tanks, compound walls and utility lines. Repeated building windows use MultiMesh batching and shared materials. The game now presents an explicit first-run Terms & Conditions / Privacy Notice screen with versioned consent and a persistent LEGAL button. This remains an early greybox; it is not a signed mobile release.

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

1. Stabilise the third-person vertical slice on desktop and touch devices (movement, Yaba blockout and legal gate are in place).
2. Add a drivable danfo with enter/exit interaction (first arcade driving pass implemented); next add traffic AI, vehicle damage and more vehicle types.
3. Add Lagos street life: danfos, traffic, pedestrians, markets and audio.
4. Add Android/iOS export presets, signing setup, device profiling and store-ready release builds.
5. Build mission, interaction and save systems.
6. Expand the world using researched district layouts and properly licensed geographic data.

See [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) for scope and engineering constraints, [docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md) for Android/iOS export and device QA, [docs/TERMS_OF_SERVICE.md](docs/TERMS_OF_SERVICE.md) for the player terms draft, [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) for the privacy-policy draft, and [docs/STORE_SUBMISSION_CHECKLIST.md](docs/STORE_SUBMISSION_CHECKLIST.md) for store submission gates. A static legal-information site is prepared in [site/](site/) with a GitHub Pages deployment workflow.

## Project principles

- Build and test playable systems, not just screenshots.
- Profile on actual target devices; editor/headless success is not mobile performance proof. See [docs/LOW_END_DEVICE_PROFILE.md](docs/LOW_END_DEVICE_PROFILE.md) for measured performance gates.
- Keep draw calls, physics bodies, memory and texture sizes under control for phones.
- Do not use copyrighted GTA assets, maps, branding or audio.
- Credit and comply with the licences of any external geographic data and assets.
