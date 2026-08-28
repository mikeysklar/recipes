# KiCad PCB → FreeCAD Enclosure, Parallelized

Make KiCad the source of geometric truth, make a single `params.json` the source of
design truth, split the enclosure into independent feature modules that agents can
write in parallel, and gate everything behind an automated interference check.
FreeCAD holds a Spreadsheet so you can still turn knobs in the GUI.

## 1. Extract ground truth from KiCad (never let an LLM guess a dimension)

```bash
kicad-cli pcb export step board.kicad_pcb -o build/board.step \
  --subst-models --include-tracks --include-pads
kicad-cli pcb export dxf board.kicad_pcb -o build/outline.dxf --layers Edge.Cuts
```

`extract_board.py` in this directory dumps the rest into `build/board.json`:

```bash
# pcbnew is not pip-installable - use KiCad's bundled Python
/Applications/KiCad/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3 \
  extract_board.py board.kicad_pcb -o build/board.json
```

It emits the Edge.Cuts polygon (with cutouts) and board thickness, mounting holes with
stable ids, and every enclosure-relevant footprint with position, rotation, courtyard
extents, board side, and which wall it faces. It also prints the `kicad-cli` command
carrying the matching `--user-origin`, so the STEP and the JSON land in the same
coordinate frame. Skip that and every clearance check downstream is quietly wrong.

Three things worth knowing about its output:

- **Coordinates appear twice.** `kicad_mm` is raw Y-down board coordinates; `cad_mm`
  is Y-up with the origin at the outline corner, so all values are positive and match
  the STEP. Feature rotations are flipped to match too.
- **Holes are split.** `mount_holes` is MountingHole footprints plus anything drilled
  >= 2 mm (tunable) - these get standoffs. `other_holes` is switch pegs and connector
  shell tabs - they need clearance, nothing screws into them. Mounting holes get ids
  (`MH1`...) because MountingHole footprints are nearly always `REF**` and refdes alone
  cannot address them.
- **Heights are a lower bound.** pcbnew knows the 3D model filename but not its
  bounding box. Supply real numbers via `--heights map.json` or an `Enclosure_Height`
  footprint field; the script lists the refdes it could not resolve.

Annotate intent in the schematic with footprint fields, and the enclosure generator
picks it up without you re-describing the board in prose each iteration:

| Field | Values | Effect |
|---|---|---|
| `Enclosure` | window, lightpipe, button, connector, vent, antenna, ignore | what opening this part needs |
| `Enclosure_Edge` | left, right, front, back, none | which wall it breaks out of |
| `Enclosure_Height` | mm | height above the board surface |

Untagged parts fall back to heuristics on footprint id and refdes prefix. Set
`Enclosure_Edge` explicitly on anything in a corner - the nearest-edge guess is a coin
flip there.

## 2. Two-file design contract

`params.json` — wall thickness, PCB-to-wall air gap, standoff height, fastener type
(M3 heat-set, boss OD/ID), lid style, draft angle, tolerance class (FDM vs resin),
vent pattern.

`build/board.json` — machine-extracted, never hand-edited.

Everything downstream is a pure function of those two.

## 3. Parallel split: by feature module, not by file region

Agents that edit the same file serialize and conflict. Give each one its own module
with a fixed signature:

```
enclosure/
  params.json
  extract_board.py     # KiCad -> board.json
  assemble.py          # you own these two, agents never touch them
  check.py
  features/
    base_shell.py        # walls and cavity
    standoffs.py         # from b["mount_holes"], gusseted into nearby walls
    lid.py               # plate and locating lip
    connector_cutouts.py # wall and lid openings from b["features"]
    vents.py             # hex/round/slot patterns in lid, floor or walls
    fasteners.py         # lid screws: corner lugs, or through the PCB
```

`add` and `cut` may each be a dict keyed by group instead of a list, for a module that
has to contribute to both parts at once. A lid screw lug has to exist in the base *and*
the lid, or the screw hole gets drilled through open air:

```python
return {"add": {"base": posts, "lid": pads}, "cut": holes}
```

Openings are tuned per refdes in `params.json`, not by editing the module:

```json
"cutouts": {
  "J13": {"w": 12.0, "h": 6.5, "dz": 0.0, "margin": 0.4},
  "J20": {"skip": true},
  "U5":  {"lid": true}
}
```

`skip` leaves the wall solid for a part you do not populate; `lid` sends the opening
up through the lid instead of out through a wall.

Each exposes:

```python
ORDER = 20                 # reporting order only
GROUP = "base"             # which printed part - base or lid
PHASE = "fixture"          # shell | fixture | opening
CUT_PHASE = "opening"
CUT_SCOPE = ("base",)      # which groups this module's cuts apply to (default: all)

def make(params, board, ctx):
    return {"add": [...], "cut": [...]}
```

`assemble.py` bins every returned solid by group and phase, then evaluates three
rounds. Within a round, adds are all unioned and cuts are all unioned before either is
applied, so no module's result depends on which other module ran first. Six agents run
fully concurrently because the only shared state is the two read-only JSON files.

The phases exist because ordering genuinely matters in exactly one place:

| Phase | What goes here |
|---|---|
| `shell` | outer walls, and the cavity that hollows them |
| `fixture` | everything growing inward afterwards - standoffs, bosses, ribs, lid lips |
| `opening` | cuts that pierce the finished part - connectors, vents, insert bores |

Skip this and the cavity swallows every standoff. That is not hypothetical - it is
what the first working build of this pipeline did, and the geometry looked entirely
plausible until the check flagged six mounting holes with nothing under them.

`ctx` carries the derived geometry so modules never recompute it: `ctx.cavity_face`,
`ctx.outer_face`, `ctx.offset_face(d)`, `ctx.prism(face, z0, z1)`, `ctx.cyl(...)`,
`ctx.mounts()`, `ctx.features_of("connector")`, and the Z datum ladder
(`ctx.z_floor`, `ctx.z_pcb_bottom`, `ctx.z_pcb_top`, `ctx.z_lid`, `ctx.height`).
Z = 0 is the outer bottom face, so the part sits on the build plate at zero.

Spawn a 7th as an adversary: a DFM checker that reads all modules and flags min wall
violations, unsupported overhangs, bosses thinner than 2x nozzle, sink marks, and
screws that land on a trace.

## 4. Parametric and GUI-editable

Have `assemble.py` build the FreeCAD document with a `Spreadsheet` object first, one
aliased cell per key in `params.json`, and make every feature reference
`params.wall_thickness` rather than a literal. Then you open the FCStd, change a cell,
recompute, and it's live — but the LLM regenerates from script when the design changes
structurally.

Run it headless:

```bash
./install.sh                                     # once - see below
/Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd assemble.py -- --check
```

**The install step is required, and the failure is silent.** FreeCAD 1.1 refuses to
import a module during document restore unless it resolves inside
`FreeCAD.__ModDirs__`. Without the symlink the FCStd still opens and still shows
correct geometry - the shape is saved in the file - but the scripted object is gone,
so editing a Spreadsheet cell updates the cell and changes nothing else. It looks like
a parameter that does not work rather than an import that was blocked. A symlink into
the Mod dir is enough; the repo stays where it is.

Verified round trip: reopen the FCStd, set `wall_thickness` 2.4 -> 4.0 in the sheet,
recompute, base volume goes 18519 -> 23763 mm3.

**Critical gotcha:** do *not* build features by referencing named faces/edges (`Face6`,
`Edge12`). FreeCAD's toponaming will silently attach your cutout to the wrong face when
a parameter changes. Build from primitives positioned by coordinates from `board.json`
and boolean them. This is also why LLM-generated FreeCAD scripts break on the second
parameter change.

If you don't actually need GUI editing, **build123d** or **CadQuery** is a much better
LLM target — cleaner code, real constraints, no toponaming — and it exports STEP that
FreeCAD opens fine. The FreeCAD-native path is only worth it for in-GUI adjustment.

## 5. The verification loop is what makes this work

Without this, parallel agents produce confident garbage. `assemble.py --check` runs
the two gates that must never be skipped. `check.py` runs the wider suite:

```bash
freecadcmd check.py -- --svg          # add --strict to fail on warnings
freecadcmd check.py -- --json         # machine-readable, for a workflow to consume
```

| Check | Catches |
|---|---|
| `solid` | self-intersections, open shells, parts floating free of the body |
| `pcb-clash` | anything inside the PCB envelope |
| `boss-wall`, `standoffs`, `insert-bores` | fastener geometry that will split or has nothing to screw into |
| `lid-fit` | base and lid overlapping in the assembled position |
| `cutouts` | edge connectors and buttons with no opening |
| `min-wall` | ray-sampled wall thickness |
| `overhang` | unsupported area, in each part's declared print orientation |
| `build-volume` | parts that do not fit the plate |

It rebuilds from the JSONs rather than reading `build/*.step`, so it cannot pass
against a stale export. `--svg` writes six orthographic line drawings per part, which
open in a browser and diff usefully between runs.

Five things that took a wrong turn first and are worth stealing:

- **The envelope is per component, not the whole board.** A whole-outline keepout is
  sufficient but outlaws every standoff, since standoffs legitimately occupy the space
  under the board. So it is the PCB slab plus one box per tagged component with a known
  height. Standoffs stop exactly at `z_pcb_bottom` and register as tangent. The
  tradeoff: untagged or unmeasured parts are absent, so a clean result does not prove
  the lid clears the tallest capacitor.
- **Probe the boss footprint, not its axis.** The first standoff check sampled a
  hairline on the boss centreline, which is exactly where the heat-set bore is. Every
  correctly built standoff failed.
- **`nearestFacetOnRay` returns the facet you launched from.** Used naively it reports
  the epsilon offset as the thickness of every wall in the model, which reads as total
  DFM collapse rather than as a broken measurement. Use `foraminate`, drop the self
  hit, and validate against a box of known wall thickness before trusting a number.
- **Filter for opposing faces.** A ray crossing the concave crease where two merged
  bosses meet measures the notch, not a wall. Requiring the far facet to face back at
  the ray removes most of that noise. Some survives - the residual shows up as a WARN
  on this board, and it is an artifact, not a thin wall.
- **An interior part is not a lid opening.** Treating "no edge tag" as "cut down
  through the lid" punched a hole for all 13 interior parts on this board and took 29%
  of the lid with it. Only an explicit window goes through the lid; the rest are
  reported for a human to place.
- **Openings that nearly touch are worse than openings that overlap.** Two overlapping
  cuts union cleanly. A near miss does not: an LED hole ending 0.125 mm past the edge
  of the connector opening beside it left material tapering to a 0.03 mm knife edge
  where the circle crossed the rectangle. `connector_cutouts.py` runs a merge pass
  fusing anything closer than `min_wall`, in both the along-wall and vertical
  directions. It found three such pairs on this board, two of which were invisible
  until the first was fixed.
- **Nothing can stand inside the cavity.** The cavity is the board outline plus
  `air_gap`, so a screw post placed in it collides with the PCB envelope no matter
  which corner it is in. `corner_lugs` pushes each post outward along the diagonal
  until it measures clear, rather than assuming a rectangular board leaves room -
  a rounded or notched outline puts the bbox corner *inside* the cavity.
- **A post outside the outer wall has no floor under it.** Starting the lug at
  `z_floor` looks right and prints as a column hanging in mid air, because the floor
  only spans the outer profile. Run it from Z=0. The overhang check catches it.
- **Drop cells, do not clip them.** A vent pattern clipped to its region boundary
  leaves crescent slivers that look fine in a render and print as loose flakes. Test
  the whole cell footprint and discard it if any corner falls outside.
- **A lid lip is a ring, not a prism of the cavity.** Extruding the cavity face gives
  a solid plug filling the entire enclosure interior, crushing every component under
  it. It passes the clash check for exactly as long as no part has a known height - so
  it survives until the board data gets good enough to catch it. Found by the overhang
  check instead, when vents cut 0.5 mm blind pockets into the plug's top face.
- **Never cut flush to the parting line.** An opening clamped to `z_lid` removes the
  wall's top rim, and several along one wall sever the shell into disconnected pieces.
  Cap at `z_lid - min_wall` so a rim survives. `solid` catches it as a disconnected
  solid count, which is why that check exists.
- **Parts are modelled in assembly position and printed one at a time.** Checking
  overhangs without applying each part's print orientation makes the lid's entire
  underside read as unsupported. Declare it in `params.json` under
  `print_orientation`; the lid defaults to `flip`.

Every measurement here is approximate in a documented way. A ray-sampled thickness is
not a proof of minimum wall and a facet-normal count is not a slicer. They are triage,
sized to catch what an agent will actually produce: a boss thinner than the nozzle, a
ceiling with nothing under it, a connector with no hole.

## 6. Also worth knowing

The **KiCad StepUp** FreeCAD workbench already does board↔enclosure sync and collision
checking interactively, and can push the enclosure outline back to Edge.Cuts. Use it as
the human review step even if your generation path is scripted.
