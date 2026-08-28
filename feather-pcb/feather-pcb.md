# Adafruit Feather house style — actionable spec for the AT32F435 Feather

Synthesised 2026-08-26 from **measured** board files, not from memory or the web.
Sources, both with full numbers and per-board tables:

- `style-local.md` — Feather STM32F405, Feather RP2040 (Original / rev B / RFM),
  Metro RP2350, Fruit Jam, Metro ESP32-S2 (8 board files, all Eagle)
- `style-rp2350.md` — Feather RP2350 (`adafruit/Adafruit-Feather-RP2350-PCB`)

Primary reference for THIS board is the **Feather STM32F405** (same LQFP-64 MCU
class). Where F405 and the RP2040/RP2350 generation differ, F405 wins and the
difference is flagged.

> **Coordinate note.** Eagle's frame is origin bottom-left, +Y up — the SAME as
> `build_pcb.py`'s design frame. So Eagle numbers in this doc drop straight into
> the script. They are NOT the same as KiCad-frame numbers read out of
> `.kicad_pcb` (+Y down); those need `y_design = 22.86 - y_kicad`.

---

## 1. Stackup and rules

| Parameter | Adafruit | ours now | action |
|---|---|---|---|
| Layers | **2**, on every board measured | 2 | ✅ |
| Thickness | 1.57 mm (1.6 nominal), 1 oz | 1.6 | ✅ |
| Trace/clearance | RP2350 DRU is literally `adafruit 7-7` = **7 mil (0.1778)**; F405 routes at **8 mil (0.2032)** | 0.2 | ✅ effectively F405 |
| Copper to edge | **0.254 mm** (10 mil) | 0.3 | ✅ (ours is safer) |
| Vias | through only, **no microvias/blind/buried**, all tented | 0.3/0.6 | ✅ |
| Via drills | 0.30 signal, 0.35 general, **0.40 GND/VBUS** | 0.3 | tighten: use 0.40 for GND stitching |
| Mask expansion | 2 mil/side; paste 1:1 (0 expansion) | default | set explicitly |

## 2. Trace widths — only two, plus a power step

- **Signals: 0.20 mm** — F405's dominant width is 0.2032 mm (8 mil, 78.2 % of its
  routed length), and we deliberately use **0.20** instead. Reason: the router's
  grid is 0.05 mm, and 0.2032 forces two parallel lanes to 0.4032 mm centre-to-
  centre, rounding lane pitch up from 8 cells to 9 — a 12.5 % loss of lane density
  exactly where the board is tightest, at the LQFP escape. The 1.6 % width
  difference is invisible; the lane density is not. The house-style point is the
  two-width *vocabulary*, not the third decimal place.
  (RP2040/RP2350 use 0.1778; we follow F405.)
- **Power and GND: 0.3048 mm**, stepping to **0.4064 mm** for the heaviest runs
  (LDO output to the header, VBUS).

That is the whole vocabulary. No per-net bespoke widths.

## 3. Routing geometry

- **Strictly 45°. Zero curved segments on any board.** Off-45 segments exist only
  as sub-1 mm stubs into pads (0 of 815 on F405; 11 of 645 on RP2040).
- No teardrops.
- **Route on BOTH layers, split roughly evenly.** Measured top/bottom routed
  length: 57/43 (F405), 63/37 (RP2040), 57/43 (Metro RP2350), 54/46 (Fruit Jam).
  A one-sided board is *not* house style — this directly contradicts how our
  current board came out and is the single biggest visual tell.
- **GND poured on BOTH layers**, one simple rectangular polygon per side covering
  the whole board, Eagle defaults (thermals ON, orphans OFF).
- USB pair: routed **mostly on the bottom layer**, no length matching,
  D+/D- doubled at the Type-C.

  > **CORRECTION — no series resistors on this part.** style.md originally
  > carried "27 Ω series resistors" generalised from the RP2350. That is an
  > **RP2040/RP2350-specific requirement** (their datasheet mandates 27 Ω) and is
  > WRONG for an STM32F4/AT32-class OTG FS PHY.
  >
  > Measured on the Feather STM32F405 (our direct reference, same PHY class):
  > `D+` runs `U$3 pad 45 -> X6 A6/B6` and `D-` runs `U$3 pad 44 -> X6 A7/B7`,
  > with only a test point on each net. **No series resistors exist on that board.**
  > The AT32F435 datasheet Table 58 likewise gives an internal D+ pull-up
  > (RPU 0.97-1.58 kΩ) and specifies rise/fall and crossover with no external
  > series element.
  >
  > F405's actual USB routing, to copy: **D+ 21.06 mm top / 32.59 mm bottom,
  > D- 16.78 mm top / 33.12 mm bottom, 2 vias each, width 0.2032 mm** — i.e. the
  > same width as every other signal, no special pair geometry. Bottom-heavy at
  > roughly 60/40.

## 4. Ground vias and decoupling — the counter-intuitive part

Measured on every power pin of every board:

- **All decoupling caps are on the TOP layer.** Not one backside cap under the
  MCU on any board.
- **No cap has a dedicated via at its ground pad.** Median cap-GND-pad to nearest
  GND via: **1.69 mm (F405)**, 1.53 (RP2040), 2.08 (Metro RP2350). Caps with a via
  within 1 mm: **zero, on all boards.**
- GND vias are scattered where return current needs them, ~2.5-3.5 per cm²,
  2.4-3.3 mm nearest-neighbour. **No edge ring of stitching vias.**

So: do not "via-stitch every cap". Pour top and bottom, scatter stitching vias at
that density, and let the top pour be the return path.

## 5. Silkscreen — the strongest visual signature

- **No reference designators.** Pin labels only. (R1/C3/U2 never appear.)
- Labels are **1.016 mm cap height, ~0.2 mm stroke, all upright** (never rotated
  with the header), placed **1.524 mm inboard of the pad centres**.
- Adafruit rasterises labels with the **`pinguin` ULP** into filled rectangles, and
  keeps editable vector text on layers 172/173 as
  `font="vector" ratio="12" size="1.016"`. **In KiCad, reproduce the look
  directly: stroke font, text height 1.016 mm, thickness ~0.15-0.20 mm.**
- Labels on **both top and bottom** silk.
- Abbreviate aggressively: `MO`, `MI`, `Rst`, `Bat`, bare GPIO numbers.
- Footprint outline silk: 0.1524 mm (JST_SH4), 0.2032 mm (TQFP64, SOT23-5),
  0.3048 mm (0603/0805 polarity marks).
- Board name + revision + logo live in a **bitmap**; the bottom art covers nearly
  the whole board (F405 bottom art spans x 5.09..50.49, y 0.31..22.57) and carries
  the long product name, Adafruit logo, CC/OSHW marks and date.

## 6. Feather mechanicals — CONFIRMED identical to ours

Both Feathers and all three RP2040 revisions agree exactly:

- Outline **50.800 × 22.860 mm**, 4 straights + 4 arcs, **2.54 mm corner radius**
- Header rows: bottom **y = 1.27**, top **y = 21.59** (21.6535 on some), 2.54 mm pitch
- Header pads: **1.0 mm drill / 1.6764 mm pad**
- Mounting holes 2.54 mm in from each corner. RP2350 note: left pair plated
  2.5/3.2 mm, right pair bare 2.54 mm drill.
- **Two +3V3 pins side by side** on the 16-pin row is house style.

✅ Our board already matches all of this.

## 7. STEMMA QT — placement is prescriptive

**`JST_SH4` VERTICAL is the standard part.** (`JST_SH4_RA` right-angle appears only
on the RP2040-RFM and RP2350 variants.) Present on all six distinct designs.

```
signal pads 1..4 : 1.55 x 0.60 mm, 1.000 mm pitch, local x = -1.5,-0.5,+0.5,+1.5
mount tabs MT1/MT2 : 1.80 x 1.20 mm at local x = +/-2.800, BOTH TIED TO GND
pinout: 1 = GND, 2 = +3V3, 3 = SDA, 4 = SCL
```

Placement on the Feathers — **mouth faces the right-hand short edge (x = 50.8),
the end OPPOSITE USB**, rotated **R90**:

| | F405 | RP2040 |
|---|---|---|
| origin | **(48.006, 8.382) R90** | (47.752, 8.255) R90 |
| tab outer edge to board edge | **0.508 mm** | 0.254 mm |
| silk bbox | x 45.79..50.09, y 5.38..11.48 | x 46.05..50.35, y 5.26..11.36 |

**It is deliberately NOT vertically centred** — it sits low at y ≈ 8.3 (board
centre is 11.43), leaving the upper-right free. F405 puts its SPI flash there.

### Consequence for our board
Adopt **J4 at design (48.00, 8.38) R90**. Verified against real geometry: signal
pads land at x 48.55..50.10 (0.40 mm inside the copper-to-edge limit), mount tabs
at x 45.90..47.70, y 4.98..6.18 and 10.58..11.78 — reproducing F405's silk bbox
of 45.79..50.09 almost exactly.

Two knock-on moves, both measured rather than estimated:

- **C5** (10 µF 3V3 bulk) at design (45.50, 6.00) has pads reaching x 46.5,
  y 5.3..6.7 — **directly under J4's south mount tab**. C5 must move. C2 (43.30,
  7.80) and C3 (43.30, 9.60) clear J4 by 1.07 mm and stay put.
- **J2** moves to **design (48.20, 15.85)**, not 15.00. J4's courtyard tops out at
  y 12.305 and J2 at y=15.00 would start at 11.58 — still overlapping. 15.85
  clears it. That is tight against the north mounting hole (J2's north tab ~1.59 mm
  from the hole centre against a 1.57 mm keep-out), so a nudge is needed;
  DRC decided, and the answer is **SOUTH by 0.10 mm to y = 15.75**.

  > **NOT west.** This guide originally guessed west and west is worse. The
  > binding distance is diagonal, from the hole centre (48.26, 20.32) to the
  > tab's near corner, so moving west shortens the x leg faster than it
  > lengthens the diagonal: measured, -0.2 mm west gives **0.30 mm** against
  > the 0.40 mm rule, while 0.10 mm south gives **0.417 mm**. J2's south tab
  > still clears J4's courtyard by 0.33 mm. A guide that hands the next
  > person a guess that has already been disproved is worse than one that
  > says nothing.

That mirrors F405's own use of the upper-right pocket (it puts its SPI flash there).

## 8. Power section

- LDO on the top layer with its input/output caps adjacent.
- VDDA gets its own filtering; the RP2350 boards give `ADC_AVDD` / `VREG_AVDD`
  dedicated 2.2 µF 0603 caps at 1.80 mm and 1.95 mm from the pin.

## 9. Delta list for the AT32F435 Feather

Ordered by visual impact:

1. **Route both layers ~55/45** instead of top-heavy. Biggest tell.
2. **GND pour on BOTH layers**, full-board rectangles, thermals on.
3. **Silk: drop all reference designators**; pin labels at 1.016 mm height,
   ~0.2 mm stroke, upright, 1.524 mm inboard of pad centres, top AND bottom.
4. **Two widths only**: **0.20** signal / 0.3048 power (0.4064 for LDO-out,
   VBUS).  NOT 0.2032 — see §2, which gives the reason: the router's grid is
   0.05 mm, and 0.2032 rounds two parallel lanes from 8 cells of pitch to 9,
   losing 12.5 % of lane density exactly where the board is tightest.  This
   checklist said 0.2032 while §2 said 0.20, and the board has never carried a
   single 0.2032 segment: the shipped census is 0.3048 x 232, 0.20 x 682, and
   one documented 0.30 escape neck.  Reports quoting "0.2032" were reading
   this line rather than the board.
5. **J4 STEMMA QT vertical at (48.0, 8.38) R90**, mouth to the east edge; move J2
   to ~(48.20, 15.0).
6. **GND vias scattered ~3/cm²**, not ringed, and *not* one per cap.
7. Add **27 Ω series resistors** on USB D+/D- and route the pair mostly on B.Cu.
8. Via drills: 0.30 signal / 0.40 GND.
9. Mask expansion 2 mil, paste 1:1.
10. Optional but characteristic: silk outline box under the MCU; bottom-side art
    block with product name and marks.


---

## 10. Tension between "both layers" and "unbroken plane" — resolved

Items 3 and 2 pull against each other: routing B.Cu evenly is what slits the
bottom ground plane. **Adafruit resolves this by pouring both sides and accepting
a fragmented bottom** — the evenly-routed split is the house style; an unbroken
bottom plane is not sacred. Follow the pour-both rule and use island tie-down
vias to bridge any ground groups that get separated.

## 11. Router performance notes (measured)

Builds reached ~50 minutes. Findings from profiling the live router:

- **Almost nothing survives a placement change.** The chain is pad positions ->
  obstacle boxes -> per-net blocked bitmaps -> everything. Caching across a
  placement change is not worth it.
- **Worth caching at the SAME placement** (keyed on a hash of the placement table
  plus rule constants): the per-net `BLK`/`VBLK` bitmaps (2 × 931 KB × 25 nets)
  and the rasterised hand-laid copper. Building these is a large slice of the
  ~40 s startup, and a style-tuning pass re-runs at one placement many times.
- **The real win is not caching.** A failed A* costs a full 3,000,000-expansion
  sweep (10-20 s) and the rip-up can retry the same hopeless net repeatedly. Two
  fixes: cap `MAX_EXPAND` at 1.5 M once a net has failed once, and cache the
  failure keyed on the obstacle-map hash. Expected to more than halve build time
  with no change to the routing result.
- **Per-net A* inside one negotiation iteration does not parallelise** — each net
  sees the previous net's stamp, so it is sequential by construction. The startup
  bitmap build does parallelise cleanly across processes.

### 11a. Perf work actually done, and what was declined

Implemented:
- `MAX_EXPAND` 3,000,000 -> 1,200,000, and 400,000 for any net already known to
  have failed this run. A route that exists is found well under a million
  expansions; the cap only bites on unroutable nets, which previously burned the
  full budget before reporting failure.
- Negative cache keyed on (net, target, blocked-map hash, via-map hash, seed-set
  fingerprint), tagged so searches with differing cost maps do not collide. The
  negotiation passes its iteration number so a stale negative is never reused.
- An A* line in the build report (searches / cache hits / seconds in A*), which is
  configuration-independent and so measures the fix regardless of other changes.

**Declined, with measurement:** parallelising the startup bitmap build and
disk-caching BLK/VBLK. The 18 negotiation iterations x 25 nets are the entire
build; startup is ~40 s of a ~50 min run, **1.3 %**. Perfect parallelism saves 30
seconds, and a disk cache keyed on a hash that misses one input would silently
route against the wrong obstacles. Amdahl beats the idea — the complexity budget
is better spent elsewhere. (This overrode an explicit instruction from me; the
measurement was right.)
