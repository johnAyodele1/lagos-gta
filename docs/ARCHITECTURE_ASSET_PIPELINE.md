# Licensed architecture asset pipeline

## First imported hero asset

- **Asset:** Modular Urban Apartments Facade
- **Creator:** James Ray Cock
- **Source:** https://polyhaven.com/a/modular_urban_apartments_facade
- **Licence:** CC0 1.0
- **Source dimensions:** 51.53 m wide × 6.665 m deep × 17.00 m high
- **Source geometry:** approximately 118,215 triangles
- **Purpose:** one measured, textured hero frontage on a mapped Yaba building; not a replacement for every building in the district.

The import workflow calls the official Poly Haven files API with a project-specific User-Agent, prefers a 2K or 1K glTF package, verifies the API-provided MD5 when available, converts the source scene into a self-contained GLB and commits the resulting runtime asset to the current feature branch. The game has no runtime download dependency.

The GLB is intentionally imported as a single hero asset first. Do not instance this 118k-triangle source across thousands of OSM footprints. Profile its draw calls, materials, texture memory and GPU cost on Android before expanding the asset set. The mapped OSM footprint and collision remain authoritative; the imported facade is a visual replacement for one selected street-facing wall only.

## Local regeneration

Run the GitHub Actions workflow **Import licensed Yaba architecture asset** from the feature branch, or run:

```bash
python tools/import_polyhaven_architecture.py --output-dir assets/models/architecture
```

If the source archive contains a glTF scene rather than a GLB, convert it with:

```bash
npm install --global @gltf-transform/cli
gltf-transform copy assets/models/architecture/source/source.gltf assets/models/architecture/modular_urban_apartments_facade.glb
```

Poly Haven assets are CC0. The project credits Poly Haven in the in-game asset credits because the project uses the Poly Haven asset distribution API. The game does not query that API at runtime.
