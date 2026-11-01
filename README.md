# Lagos GTA

An original open-world 3D game project rooted in Lagos, Nigeria.

## Current status

**First playable blockout in development.** The current branch contains a Godot 4 third-person prototype with a procedurally generated Lagos-inspired starter district. It is a greybox foundation, not a finished GTA-scale game.

## Run locally

1. Install Godot 4.3 or a compatible Godot 4.x release.
2. Clone this repository.
3. Open the repository folder in Godot.
4. Run the project (F6/F5, or the Play button).

No third-party asset packs are required for the initial scene.

## Controls

| Input | Action |
|---|---|
| WASD | Move |
| Shift | Sprint |
| Space | Jump |
| Mouse | Look around |
| Escape | Release / capture mouse |

## Technology

- Godot 4
- GDScript
- Compatibility renderer for modest desktop hardware
- Procedural blockout geometry for the first district

## Roadmap

1. Stabilise the third-person vertical slice.
2. Add a drivable vehicle and enter/exit interaction.
3. Add Lagos street life: danfos, traffic, pedestrians, markets and audio.
4. Build mission, interaction and save systems.
5. Expand the world using researched district layouts and properly licensed geographic data.

See [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) for scope and engineering constraints.

## Project principles

- Build and test playable systems, not just screenshots.
- Keep the prototype performant on integrated graphics where practical.
- Do not use copyrighted GTA assets, maps, branding or audio.
- Credit and comply with the licences of any external geographic data and assets.
