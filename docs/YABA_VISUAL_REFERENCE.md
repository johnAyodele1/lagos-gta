# Yaba visual reference and quality gates

This document keeps the environment work tied to real Yaba streets rather than a generic African-city theme. The linked photographs are visual references only. They are not bundled game assets and must not be copied into the game without a separate licence check.

## Reference set

- [University Road, Yaba — Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Unilag_University_Road,_Yaba.jpg): two-storey mixed-use frontage, balcony, roadside fence, danfo and keke activity.
- [Old Yaba Road commercial property](https://privateproperty.ng/listings/commercial-property-for-sale-old-yaba-road-yaba-lagos-6PAGGJ): three-storey mixed-use building, ground-floor shops, recessed balconies, metal railings, awnings and overhead power lines.
- [Yaba market street scene](https://medium.com/@damisolasulaiman/soft-launching-december-in-lagos-2933246fd28f): crowded market edge, umbrellas, roadside stalls, parked cars and uneven street frontage.
- [Yaba streets — World Bank environmental assessment](https://documents1.worldbank.org/curated/en/223891517330286708/pdf/SFG3973-V2-EA-P146330-PUBLIC-Disclosed-1-30-2018.pdf): reference photographs and description of streets around Yaba/Akoka.
- [Lagos architectural landscape](https://www.icwa.org/how-long-is-now-lagos-fast-evolving-architectural-landscape/): older bungalows, 1980s tenement blocks, newer stucco apartments, high gates and mixed building upkeep.

## Visual characteristics to model

Yaba is architecturally mixed. Do not stamp one building style across the district.

- Older low-rise bungalows and renovated historic houses appear alongside three- and four-storey tenement/apartment blocks and newer infill.
- Commercial frontages sit at street level, often with security grilles, roller shutters, metal gates, projecting awnings, painted signs and goods displayed close to the pavement.
- Residential floors use recessed or projecting balconies, simple metal balustrades, laundry rails, exterior AC units and satellite dishes.
- Rooflines vary: flat concrete roofs with parapets and water tanks, plus corrugated metal roofing on some smaller structures.
- Compound walls and gates separate many homes from the street. They should follow the plot access and frontage rather than appear as random decorative walls.
- Streets are not uniformly wide or pristine. Model worn asphalt, patch repairs, faded markings, uneven concrete sidewalks, open or covered roadside drains, occasional potholes and puddling.
- Overhead electricity and communications wiring is visually prominent. Poles, crossarms, insulators and sagging cable runs should follow streets.
- Market areas need dense but navigable umbrellas/tarpaulins, stall frames, tables, stacked goods, signs, pedestrians and loading activity.
- Traffic should include yellow danfo minibuses, ordinary sedans/SUVs, keke tricycles and parked vehicles. Vehicle silhouettes and scale matter more than adding many traffic instances.

## Scale and collision gates

All dimensions are metres in Godot world space.

| Object | Target dimensions / range | Requirement |
|---|---:|---|
| Player | 1.65–1.85 m tall | Visual bounds and capsule must agree |
| Sedan | 4.0–4.5 m long, 1.7–1.9 m wide, 1.4–1.55 m tall | Collider derived from the imported mesh bounds |
| SUV | 4.1–4.8 m long, 1.8–2.1 m wide, 1.5–1.8 m tall | Collider derived from the imported mesh bounds |
| Danfo/minibus | 4.5–5.5 m long, 1.8–2.2 m wide, 2.1–2.5 m tall | Player must not pass through it; door/exit clearance required |
| Pedestrian | 1.55–1.9 m tall | Visual bounds and capsule must agree |

A model must be measured after import. Do not apply arbitrary uniform scales to make unrelated vehicle types share one footprint. Collision proxies must be generated from the fitted visual bounds and tested in motion.

## Asset and rendering rules

- Prefer licensed, textured 3D models with authored proportions and separate body, glass, wheel, trim and light materials.
- Keep the current Quaternius car meshes as prototype assets only: their flat, low-poly geometry is not the final realism target.
- Use PBR albedo, normal and roughness maps for asphalt, concrete, plaster, painted metal and roofing. Keep mobile texture sizes bounded and generate mipmaps.
- Use shared materials, mesh batching and LODs for repeated props. Avoid one draw call per small facade detail.
- Keep a low graphics profile for older Android GPUs; use short-range shadows and test the balanced profile on physical Android hardware.
- Do not call the district photorealistic or release-ready until representative street screenshots and on-device profiling support that claim.

## Current known gap

The current district is built from OSM road centre-lines and building footprints, but most architecture is still procedurally extruded geometry. The current car pack is low-poly. Real mapped geometry is necessary, but it is not sufficient for a convincing Lagos street. Higher-quality licensed facade, vehicle, pedestrian, market-stall and surface assets still need to replace the prototype representations.

## Current map-data quality (2026-11-01 extract)

The committed OSM extract contains 587 road ways, 7,470 building footprints and only one mapped barrier way in the current bounds. Its road surface tags are 33 paved, 477 unpaved and 77 unknown. Only one road has an explicit width; the other 586 widths are estimates based on highway class or lane count. Building height coverage is much weaker: only one footprint has an explicit height, while most footprints have a generic fallback height because OSM does not provide levels or height tags.

These figures matter. The map geometry is real OSM geometry, but it is not a survey-grade reconstruction. A street with estimated width or a building with fallback height must not be presented as exact. The renderer should preserve known surface tags and avoid inventing precise dimensions where the source does not provide them. A later mapping pass should add locally verified road widths, building storeys, compound gates and frontage classification from properly licensed field references.

