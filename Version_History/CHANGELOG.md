# Changelog

All releases of the EPA national sewershed dataset. Each version's data and
full release notes are in `Version_History/V_<version>/`; the current release
is also in `Current_Release.zip`.

## [1.3] — October 2026

Focus: complete and correct the **sourced** sewersheds, and remove all overlaps.
Full notes: [`Version_History/V_1_3/readme.md`](Version_History/V_1_3/readme.md).

### Added
- 56 plants that were modeled in v1.2 now have a sourced boundary; 270
  sewersheds in total have a boundary added or replaced in v1.3
  (`Version_Added = 1.3`).
- New sources: 34 plants from 23 utility, county and regional datasets found
  online (CO, FL, IN, ME, MS, MT, OH, TX, VA), including sewer lines buffered by
  150 m; boundaries digitized or split by EPA for Lorain County OH, Opelika AL,
  Cary NC, North Shore Sanitary District IL, San Antonio TX and Woodsville NH.
- `sources.csv` documents the source of every sourced sewershed (3,293
  plants; previously only recent additions).
- New sewershed fields: `Flag`, `Source_Dataset`, `Source`, `Geometry_From`.
- Census crosswalks: `Population_Multiplier`, `Building_Multiplier` and
  `Weight_Method`.

### Changed
- **Massachusetts** sewersheds replaced with MassDEP *Estimated Sewer System
  Service Area Boundaries* (MassGIS PubV2025_10): collection areas joined to
  the plant they drain to.
- **New Hampshire** sewersheds replaced with NH DES sewer service areas
  (sewer and combined water/sewer areas merged; shared areas split by town);
  Woodsville digitized from local maps.
- **Sonoma County, CA:** 10 sewersheds corrected for a ~130 m positional
  offset in v1.2.
- **San Antonio, TX:** SAWS territory split between Steven M. Clouse (formerly
  Dos Rios) and Leon Creek (approximate); Martinez I/II/IV and Salitrillo from
  a new source; ten surrounding cities refreshed.
- **Overlaps removed:** sourced boundaries take priority over modeled ones;
  overlapping sourced boundaries are merged, nested, trimmed of slivers or
  split halfway between plants; overlapping modeled sewersheds are split
  halfway between plants. About 7,270 km² of overlap in v1.2; none in v1.3.
- **Census crosswalks:** `Crosswalk_Multiplier` replaced by two multipliers;
  blocks with population but no building footprints use area weighting
  instead of being dropped; sewersheds crossing a state line are counted in
  every state; buildings in non-residential blocks are counted.
- `Pop_2020` and `Buildings` recomputed for every sewershed from the v1.3
  crosswalk.

### Removed
- 31 boundaries are no longer treated as sourced (29 in South Carolina, North
  Port FL, Snyderville Basin UT). Their v1.2 polygon is kept with
  `Method = Modeled` and `Flag = needs_v2_model`.
- 68 small modeled sewersheds that lay entirely inside a sourced sewershed,
  and Hopkinton, MA (no MassDEP service area), no longer have a polygon.

## [1.2] — May 21, 2026

- Census crosswalk files (blocks, block groups, tracts) using building-weighted
  census populations.
- 35 new utility-sourced sewersheds.
- Corrections to Rhode Island sewersheds.
- `sources.csv` with source metadata for new sourced sewersheds.
- 3,253 sourced and 13,826 modeled sewersheds (19% sourced).

## [1.1] — January 26, 2026

- 25 new utility-sourced sewersheds.
- Endpoint (treatment plant) locations added to the release.
- `CWNS_NPDES_Crosswalk.csv` and `Discharge_Links.csv` (facilities discharging
  to other facilities, 2022 CWNS).

## [1.0] — September 5, 2025

- First release: sewersheds for 2022 CWNS treatment plants, sourced from
  state, utility and other public data where available and modeled by EPA
  elsewhere (H3 hexagons, ~0.11 km²).
