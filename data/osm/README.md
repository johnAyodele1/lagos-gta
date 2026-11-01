# Yaba geographic source data

The playable Yaba district is being rebuilt from OpenStreetMap road centre-lines and
building-footprint ways rather than a hand-invented crossroad.

- Extraction query: `yaba.overpassql`
- Geographic bounds: 6.505–6.520° N, 3.360–3.382° E
- Local origin: Yaba OSM place node near Tejuosho Market (6.51147° N, 3.37000° E)
- Runtime data: `assets/data/yaba_osm.json`
- Fetch/normalization: `tools/fetch_yaba_osm.py`
- License: Open Data Commons Open Database License (ODbL) 1.0
- Required attribution: © OpenStreetMap contributors

The generated file preserves OSM way IDs, names and selected tags. Missing building
heights and road widths are estimated from OSM tags and documented defaults; those
estimates are not survey measurements. OSM completeness varies by street, so the
extract must be reviewed against current local imagery before release.

Do not remove the attribution or the ODbL notice when distributing derived map data.
