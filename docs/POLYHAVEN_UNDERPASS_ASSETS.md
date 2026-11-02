# Poly Haven underpass asset set

Poly Haven is the primary source for reusable environment geometry and PBR assets. The first curated set is intentionally limited:

- [Modular Factory Facade](https://polyhaven.com/a/modular_factory_facade): mechanic/workshop frontage.
- [Concrete Road Barrier](https://polyhaven.com/a/concrete_road_barrier): weathered roadside protection.
- [Portable Generator](https://polyhaven.com/a/portable_generator): roadside generator.
- [Modular Industrial Pipes 01](https://polyhaven.com/a/modular_industrial_pipes_01): workshop utility details.

The importer prefers 1K glTF packages, verifies source MD5 when supplied, creates local GLBs and has no runtime network dependency. Individual packages are capped at 90 MiB.

## Abandoned Workshop 02

[Abandoned Workshop 02](https://polyhaven.com/a/abandoned_workshop_02) is a 16K HDRI panorama, not a physical 3D workshop. It is an art-direction/lighting reference. It must not replace the outdoor Yaba sky or be stretched onto a flat wall. The in-game underpass uses physical models and locally authored geometry.

## Lagos treatment

The underpass structure is generated only for OSM roads tagged as bridges. Its supports follow mapped bridge geometry; one mechanic bay, a yellow AUTO ELECTRICAL / YABA sign, generator, barrier and industrial pipework provide local identity. The shop is an art-directed scene element, not a surveyed real business.

## Mobile constraints

Keep the large facade to one bay; do not repeat it district-wide. Profile triangle count, texture memory, draw calls and frame time on Galaxy S21 and a lower-end Android device. Do not use the workshop HDRI as the global outdoor sky. Run Godot import, gameplay tests and Compatibility-renderer screenshot capture before treating this as visually accepted.
