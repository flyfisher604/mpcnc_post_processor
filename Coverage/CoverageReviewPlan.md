# Coverage review of `MPCNC_v4.0_Beta2.cps`

> **Resuming a later pass.** This is the in-repo copy, on branch `Coverage_Review`, kept so the method
> survives the session that produced it. It is the plan as written before the first pass, with only the
> deliverable's path updated: it now lives beside this file at `Coverage/CoverageReview.md`. To pick the
> work up in a fresh session: *"Read Coverage/CoverageReviewPlan.md and execute it."* Progress is readable
> from `Coverage/CoverageReview.md` itself — each story row carries a
> `pending` / `walked` status, so a resumed session starts at the first `pending` row and needs no other
> handover. **The first pass walked every row**; a later pass either re-walks a row against changed code or
> extends the story set, and in both cases the statuses are what says where it stands.

## Context

The post is heading for a Beta release. What is missing is not another change but **evidence of
correctness**, in the operational sense: that the emitted G-code

1. **executes** — every code exists on the selected firmware, is not behind a default-off build option,
   is not reassigned to another function there, and does not put the controller into alarm or error; and
2. **is faithful** — what Fusion asked for is reproduced without distortion.

**The toolpath itself is not re-derived.** Fusion's geometry is taken as correct: if the CAM hands the
post a move, it is enough that the move reaches the file as valid G-code with the right coordinates,
the right modal context and a feed the machine can hold. The review does not recompute cut paths,
stepovers, depths or lead-ins, and does not second-guess the CAM.

That splits the correctness test in two, and the two halves are judged differently:

- **CAM-driven motion** (`onRapid` / `onLinear` / `onCircular` / expanded cycle points) — the test is
  **fidelity of translation**: coordinates preserved, rapid-vs-cut classification preserved, arc words
  and plane correct, feed scaled only as the properties direct, nothing dropped and nothing invented.
- **Post-generated motion** (retracts, inter-part traverses, probe positioning, the base establish, the
  end park, tool-change relocation) — Fusion never asked for these; the post invented them. Here the
  test is the full one: right frame, right height, a path that clears the stock, the clamps and the
  other parts.

A file that posts cleanly and then drives the machine into a clamp fails this test as surely as one the
parser rejects.

This is a **review of the current source only** — not of the change history, and not of the `.md` files.
`docs/design.md` is read as secondary context so a deliberate design decision is not filed as a defect,
but where it disagrees with the Autodesk Fusion post-processor API, the API wins and the disagreement is
itself a finding. No `.md` other than `Coverage/CoverageReview.md` is written; `check-docs.js` and the other
repo commands are not run.

**Nothing is executed.** No posting, no harness, no test rig. The method is hand-execution of the
callback sequence against the source, tracking module state as it changes.

**Success:** the coverage ledger shows every reachable function and every property-selected branch was
walked at least once, so a Beta could be cut with confidence once the findings are resolved.

Out of scope by decision: laser / plasma / jet paths (`laserOn`, `laserOff`, `onPower`, the group-9
properties, and the jet arms of `onCommand`/`writeWcsOnStart`/`writeBaseEstablish`). Drilling **is** in
scope. Unwalked code is listed explicitly in the deliverable so the residual risk is visible rather than
implied.

---

## Method

### Two directions, as specified

**Direction 1 — the CAM body.** Fusion drives `onSection` → `onParameter` / `onMovement` →
`onRapid` / `onLinear` / `onCircular` / `onCyclePoint` → `onSectionEnd`. The question is whether the
G-code emitted for the toolpath is what the CAM asked for: correct coordinates, correct feed after
scaling, correct arc words and plane, correct rapid-vs-cut classification, correct expansion of canned
cycles.

**Direction 2 — the wrapper.** `onOpen` → `writeFirstSection` (`writeInformation`, `writeMachineHoming`,
`writeWCS`, `Start`/start-file, `writeFixedZReference`, `writeWcsOnStart`) → per-section `writeWCS` /
`toolChange` → `onClose`. What these emit is almost entirely property-driven, so each story fixes a
property set and the walk asks: **which frame is active at each emission, and is an absolute move
meaningful in it.**

### The licence dimension — Direction 1 is walked twice

Fusion's **Personal** licence emits every rapid as a feed move: `onRapid` is never called, and the moves
that would have been G0 arrive at `onLinear` at a cutting feedrate. Fusion **Full** emits real rapids.
The post carries a whole property group for this (group 3, whose title says *disable when using full
license*), so the two licences are not a footnote — they are two different callback streams into the
same code, and every Direction-1 story is walked under both.

Four combinations, all of which a real operator can produce, and each is walked at least once:

| | `Map G1s -> G0` **off** | `Map G1s -> G0` **on** |
|---|---|---|
| **Personal** | every positioning move is a G1 at cut feed — slow, and with scaling on it runs at the *lowest* limit. Is it at least safe? | the intended hobbyist configuration. Does `isSafeToRapid` restore exactly the moves that were rapids, and nothing else? |
| **Full** | the intended professional configuration — the post must not interfere with real G0s | the misconfiguration the group title warns about: genuine cutting G1s offered to `isSafeToRapid`, and the unconditional first-G1→G0 conversion. What actually happens? |

The two conversion paths are judged separately, because they are gated differently:

- `isSafeToRapid(x,y,z)` — guarded by a Z test against `safeZHeight`. Walk all three true-branches
  (Z constant / Z rising with XY constant / Z descending with XY constant from an already-safe height),
  the false fall-through, and the rounding at output precision that decides "constant".
- `onLinear`'s **first move of every section** — gated only on `forceSectionToStartWithRapid`, with **no
  Z test at all**. Walk what that converts when the first emitted move of a section is not a positioning
  move: a section that begins already at position, a section following one that ended at depth, and a
  drilling cycle's first expanded move.

### Feedrate scaling and limiting — the V1E machine case

A V1E-class machine has a leadscrew Z far slower than its belt-driven X/Y, which is the whole reason
group 2 exists (shipped 900 / 180 / 1000 mm/min). Scaling is not a nicety there: an unscaled Fusion feed
asks the Z axis for a rate it will skip steps trying to reach, and lost Z steps ruin the part and can
break the cutter. So the scaling maths is walked as a first-class correctness question, not as a
property branch:

- **Per-axis projection** in `limitFeedByXYZComponents`: pure-Z plunge, shallow ramp, steep ramp,
  pure-XY, 45° XY diagonal, and a 3-axis diagonal. Confirm each axis's resulting component is at or
  below its limit, that the sequential `multiply()` calls compose correctly (each test reads the
  already-scaled vector), and that the result is never *raised* above what the CAM asked for.
- **The toolpath cap** (`feedsMaxCutSpeedXYZ`) applied after per-axis scaling — the case a diagonal
  satisfies both axis limits and is still too fast.
- **The zero-length vector arm** — reached when a section's opening rapid is missing, i.e. exactly the
  Personal-licence case with mapping off. It returns the *lesser* of the XY and Z limits (180 on the
  defaults). Walk the interaction: which real move gets 180, and for how long, given F is modal.
- **Arcs** via `limitArcFeed`, per plane, including the deliberately conservative ZX/YZ rule.
- **Rapids are not scaled** — `rapidMovementsXY`/`Z` emit the group-2 *travel* speeds. Check against
  firmware: GRBL executes G0 at `$110`–`$112` and **ignores the F word**, while Marlin and RRF honour
  F on G0. Whether the travel-speed properties do anything on GRBL is a dialect question (I4).
- **Interaction with `Enforce Feedrate` off** — `fOutput` non-forced, so an F equal to the tracked value
  is suppressed. Walk a G1 that follows a G0 whose travel F happens to match, and the reset points
  (`resetAll`, `probeTool`'s post-`G38.2` reset, `loadFile`, `writeMachineTravelZ`).

### Per-story walk procedure

1. Fix the property set, the licence, and the job shape (sections, work offsets, tools, operation types).
2. Run `onOpen` on paper: `fw`, `resetPostState()`, `validateJob()` — record which guards and warnings
   fire and which do not, then the format/modal rebuilds.
3. Walk the callback sequence, writing the emitted block stream in order.
4. After each emission, update a **state ledger**: `currentWorkOffset`, `gMotionModal`, `gPlaneModal`,
   `gAbsIncModal`/`gUnitModal`, `xOutput`/`yOutput`/`zOutput`/`fOutput`, `safeZHeight`,
   `curCoolant`/`coolantChannelA`/`B`, `spindleEnabled`/`currentSpindleSpeed`/`lastPromptedSpeed`,
   `probePauseBefore`/`After`, `forceSectionToStartWithRapid`, `sectionComment`.
5. Check the emitted stream against the six invariants below.
6. Record which functions and which property-selected branches were **first** walked there. A story that
   adds no new branch is dropped rather than written up.

### The six invariants each walk is checked against

- **I1 Frame.** Every absolute `X`/`Y`/`Z` word is interpreted in the WCS active at that block. An
  absolute `Z` is only emitted into a frame whose Z0 this job established or the operator declared.
- **I2 Motion safety** — applied to **post-generated** motion, not to Fusion's toolpath. No traverse
  crosses the bed at an unknown Z; a post-invented XY move is emitted at a height the job established;
  Z-down is ordered after XY, Z-up before it. For CAM-driven motion the corresponding test is fidelity:
  a move Fusion classified as a rapid does not become a cut, and one it classified as a cut does not
  become a rapid.
- **I3 Modal truth.** Every belief the post caches (`gMotionModal`, `gPlaneModal`, the coordinate/feed
  variables, `currentWorkOffset`) matches what the controller would hold — in particular across include
  files, `G53` blocks, `G38.2` blocks and WCS switches, all of which are written through raw formats.
- **I4 Dialect.** Every emitted G/M/`$` code exists and means the same thing on the firmware selected.
  Settled from the firmware's own source/changelog, cited by file and version.
- **I5 Guard fidelity.** Each `error()` / `warning()` / `writeWarning()` fires on exactly the condition
  that makes the emitted code wrong — no false negative (the hazard posts silently), no false positive
  (a sound job is refused), and the fire happens before the output it is protecting.
- **I6 Units.** Every dialog dimension is millimetres and passes through `propertyMmToUnit()` exactly
  once before it is emitted or compared against a coordinate.

### Four sweeps that run across all stories

- **S1 Property cross-reference.** For each of the ~60 entries in `properties`, find every read site.
  Flag: declared but never read (`includeProbeFile` is documented as one — confirm no others); read on
  a path the dialog cannot reach; read but never validated; and read on a firmware where it has no
  effect while nothing says so.
- **S2 Guard and warning inventory.** Every `error(...)`, `warning(...)` and `writeWarning(...)` site:
  trigger condition, reachability, timing relative to output, and whether the text names a control the
  operator can change. `validateJob()`'s ordering is load-bearing — Guard C's Marlin branch `return`s —
  so verify nothing below it is unreachable on the firmware it excludes.
- **S3 Emission inventory.** Every G/M/`$` code the post can emit × the three firmwares, checked for
  existence, build-option gating and reassignment.
- **S4 API contract.** Every Fusion API symbol the post calls or depends on: `wcsDefinitions` /
  `getWorkOffset()` semantics with `useZeroOffset: false`, `capabilities`, `tolerance`,
  `maximumCircularSweep` / `allowHelicalMoves` / `allowedCircularPlanes` and what actually reaches
  `onCircular`, `getCurrentPosition()` currency inside `onLinear`, `getNextRecord()`, `expandCyclePoint`,
  `cycleNotSupported`, `section.workPlane.forward`, `is3D()`, `Vector.diff`/`.abs`/`.getNormalized()`/
  `.multiply`, `createModal`/`createVariable` force semantics, `FileSystem`/`getOutputPath()`
  availability in `onOpen`, and whether `onOpen` may re-run in one JavaScript context. No factory post
  library is installed on this machine, so any claim resting on an unverifiable API detail is filed at
  **confidence: API-assumption** rather than asserted.

---

## Dimensions, and how they are sampled

The orthogonal axes: firmware (3) × licence (2) × job shape (6) × homed-axes declaration (4) × home
action (3) × fixed Z reference (3) × first-WCS mode (6) × subsequent-WCS mode (4) × spindle control (2)
× units (2) × tool-change configuration × feed-scaling on/off × arcs on/off × comment level (4).

The full cross product is ~10⁵ and worthless. Stories are selected for **branch coverage** — every enum
`id` and both values of every boolean appear at least once — plus **pairwise coverage of interacting
pairs only**: two properties are paired when one function reads both, or when one's guard names the
other. Those pairs are enumerated from the source in sweep S1 and are what the story set is built to
cover; the rest are left at defaults deliberately, and the ledger says so.

### The job shapes — reviewed for completeness

The brief's four, kept as stated:

- **J1** one part, one operation.
- **J2** one part, several operations, one WCS.
- **J3** one part, several operations, several WCS.
- **J4** several parts across preset WCS.

Two more are added because they are ordinary shop practice and each reaches code the four above cannot:

- **J5 — several parts × several tools, interleaved.** Fusion orders sections by the operation list, so
  a real multi-part multi-tool job produces sections where **the WCS and the tool both change at the
  same `onSection`**. That is the only shape that exercises `toolChange()` and `writeWCS()` in sequence,
  and their ordering is what decides which WCS a post-tool-change re-probe lands in. No combination of
  J1–J4 produces it.
- **J6 — a WCS revisited.** Rough every part, then finish every part: G54 → G55 → G54. This is how a
  multi-part job is normally sequenced to save tool changes. It reaches `writeWCS()`'s suppression logic
  and the *re*-probe of a part whose origin this job already established — a second probe writing over a
  good Z0, at whatever height the traverse left the tool.

Two further variations are folded into existing stories rather than given their own:

- **A non-default Setup work offset** on an otherwise single-WCS job (Setup set to G56, not G54): the
  first section emits a WCS the operator did not think about, and on Marlin trips the unsupported-offset
  warning. Folded into B1 (GRBL) and A4 (Marlin).
- **A 2D-only job** (`is3D()` false), which changes `writeInformation`'s per-tool Z-range table. Folded
  into A3.

Notes on shapes deliberately **not** covered, recorded in the deliverable's exclusions: multi-axis and
off-axis Setups are walked only as *rejection* paths (D6); one part machined from two datums or flipped
is J3, and the dialog says to run it as separate jobs while nothing in the code refuses it — that gap is
what J3 exists to characterise.

### The machine frames — reviewed for completeness

`None` / `XY Only` / `Z Only` / `XYZ` is the complete enumeration of the declaration, and it matches the
real population: a stock MPCNC/Primo has no endstops at all; XY endstops are the common first upgrade
and make a stored G54–G59 offset survive a power cycle; a LowRider v3 with Z switches is the XYZ case;
`Z Only` is rare but reachable and is the case the machine-Z fixed reference guards against.

The declaration is **not** sufficient on its own, so it is always crossed with the orthogonal **action**
(`Home at Job Start` = `Off` / `Home` / `Pause, then Home`). Three combinations carry distinct risk and
each gets a story:

- **declared + homed in this file** — the frame the job establishes itself (B2).
- **declared, action `Off`** — homed at the controller before the job and trusted; the state the design
  notes say the old enum could not express (B1).
- **action set, declaration `None`** — the operator believes the job homes and no motion is emitted (B5).

"Every machine can probe Z" is taken as given, but the no-plate flow is still a supported configuration
(`Set X0 Y0 Z0 to Current Pos`) and is walked in A3, as is the `G28`-as-probe substitute in A4.

---

## The user stories

Each states the branches it exists to reach. Ordered so later stories assume the earlier walk.
**Licence** column: **P** = Fusion Personal (rapids arrive as `onLinear`), **F** = Full.

### A — Hobbyist baselines (the V1E machine: no endstops, hand-switched router)

| ID | Firmware | Homed | Shape | Lic | Property set | First walks |
|---|---|---|---|---|---|---|
| **A1** | GRBL | None | J1 | F | all defaults | `onOpen` default path, `validateJob` no-fire, `writeInformation`/`writeAllProperties`/`writeResolvedValues`, `writeMachineHoming` off-path, `writeWCS` first-section path, `Start()` GRBL arm, `writeWcsOnStart` `Current XY & Probe Z`, `partProbe(true)` no-offset, `probeTool` GRBL `G38.2`, `spindleOn` manual, `onRapid`/`onLinear` clean stream, `onClose` park `Work` + `M30` |
| **A2** | GRBL | None | J2 | **P** | `Map G1s -> G0` **on**, `Safe Z to Rapid` = `Retract:15`, comment level **Debug** | the intended hobbyist configuration: `parseSafeZProperty` RETRACT arm, `safeZforSection` all arms, `isSafeToRapid` all three true-branches + false fall-through + the rounding rule, `onLinear`'s first-G1→G0 arm, `describeSafeZ` "varies by operation", every Debug line |
| **A2′** | GRBL | None | J2 | **P** | same job, `Map G1s -> G0` **off** | the un-recovered Personal stream: `limitFeedByXYZComponents`'s zero-length arm, which moves run at 180, and whether the result is merely slow or actually unsafe |
| **A2″** | GRBL | None | J2 | **F** | same job, `Map G1s -> G0` **on** | the misconfiguration group 3's title warns about: real cutting G1s offered to `isSafeToRapid`, and the unconditional first-move conversion |
| **A3** | GRBL | None | J2 (2D) | F | `Scale Feedrate` **off**, `Use Arcs` **off**, `Enforce Feedrate` **off**, comment level **Off**, line numbers **on**, whitespace **off**, `First WCS / Part` = `Set X0 Y0 Z0 to Current Pos` | scaling early-returns, `circular`→`linearize`, `writeBlock` N-word arm, `setWordSeparator("")` and the manual-space prepends, `writeComment` full suppression with `writeWarning` still emitting, `writeWcsOnStart` `Current XYZ`, `is3D()` false in `writeInformation` |
| **A4** | Marlin | None | J2 | F | `Manual Spindle` **off** (M3/M5), `Probe with G38.2` **off** (G28 Z), tool changes **on** + relocation + `Do First Change` + `Probe After Tool Change`, 2 tools, Setup work offset **G56** | Marlin `gMotionModal` force-arm, `Start()` non-GRBL arm, `writeWCS` Marlin `G92` arm + unsupported-offset warning, `writeWcsOrigin` Marlin arm, `probeTool` `G28 Z` arm, `toolChange` full relocation path (`M300`, `M84 Z`), `askUser` Marlin arm, `display_text` `M117`, `spindleOn`/`spindleOff` commanded arms, `onClose` non-GRBL arm |
| **A5** | RepRap | XY / `Home` | J2 | F | `First WCS / Part` = `Jog to X0 Y0, Probe Z0`, start **and** stop include files named | RepRap `duetMillingMode`, `askUser` `M291` + `X1 Y1 Z1`, `warnJogAtPauseOnGrbl` no-fire, `loadFile` both sites incl. trailing-newline repair and the modal resets, `onClose` include-stop arm, `M2` RepRap arm, `writeMachineHoming` `G28 X`/`G28 Y` arm |

### B — Machine frame and homing

| ID | Firmware | Homed / action | Shape | Lic | Property set | First walks |
|---|---|---|---|---|---|---|
| **B1** | GRBL | XY / **Off** | J1 | F | `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, park **Machine**, Setup offset G56 | the trusted-but-not-homed-here frame; `writeWcsOnStart` `Probe Z` arm, `partProbe(false, true)` and its `zUnknown` warning, the machine-park guard that requires homing on GRBL |
| **B2** | GRBL | XYZ / `Pause, then Home` | J4 | F | `Fixed Z Reference` = **Machine Z**, `Inter Part Travel Z` = `-12`, `Subsequent WCS / Part` = `Probe Z`, park **Machine**, retract-across-parts **on** | `promptsBeforeHome` pause, `writeMachineHoming` GRBL `$H` via `writeln` (with line numbers on), `writeFixedZReference` machine-Z arm, `writeMachineTravelZ` (G53 non-modality, the F word, the double `resetAll`), `writeWCS` `machineFrame` route, `writeMachineParkXY` machine-Z retract arm |
| **B3** | Marlin | XYZ / `Home` | J1 | F | park **Machine**, `Fixed Z Reference` = None | `writeMachineParkXY` Marlin `G28 X`/`G28 Y` arm + its `parkCanRetract` false warning, `writeMachineHoming` `G28 Z` arm |
| **B4** | GRBL | **Z only** | J1 | F | `Fixed Z Reference` = Machine Z | the homed-XY guard; then flip to None and to XY only, confirming each machine-Z guard fires on its own condition and in the documented order |
| **B5** | GRBL | None / `Home` | J1 | F | — | the "asks to home but nothing declared" warning **and** its `writeMachineHoming` in-file twin; confirm the pair cannot disagree |
| **B6** | GRBL | XY / `Home` | J1 | F | `First WCS / Part` = `Set X0 Y0 to Current Pos, Probe Z0` | the "homing destroys the pre-jog" warning; with the action Off, that it does not fire |

### C — Multi-part, multi-WCS, spoilboard base

| ID | Firmware | Homed | Shape | Lic | Property set | First walks |
|---|---|---|---|---|---|---|
| **C1** | GRBL | XY / `Home` | J4, G54–G56 | F | `Fixed Z Reference` = **Spoilboard**, `Reserved WCS` = G59, `Probe to Set Base` = `Pause, Probe Z, Pause`, `Inter Part Travel Z` = 40, `Subsequent WCS / Part` = `Probe Z`, `Probe X/Y Offset` = 10/10, `Probe Pause` = `Before & After` | `writeBaseEstablish` full path (transit-select, `probeTool(base, interPartTravelZ())`, restore), `retractThroughBaseClearance`, `writeWCS` `baseRelative` route, `partProbe(false)` on an added part, the probe-offset traverse in both `partProbe` and `writeWcsOnStart`, R1/R2 |
| **C2** | RepRap | XY / `Home` | J4, G59.1–G59.3 | F | `Subsequent WCS / Part` = `Use Active WCS X0 Y0 Z0` (Replicate / preset fixtures), `Probe Pause` = `No` | `wcsGcode` RepRap arm, `wcsName` >6 arm, the reserved-slot RepRap guard, `writeWCS` `Skip` arm, `probePause` = No |
| **C3** | GRBL | XY | J4 | F | `Fixed Z Reference` = None, retract-across-parts **on** → Guard B; then **off** | Guard B error; then `writeWCS`'s bare `isTraverse` retract to `probeSafeZ()`, and which frame that height is read in |
| **C4** | Marlin | any | J4 | F | — | Guard C error, and that the reserved-base guards below it are correctly skipped |
| **C5** | GRBL | XY | **J5** | F | `Reserved WCS` = a WCS a part is assigned to; tool changes on with `Probe After Tool Change` | Guard A via all three `baseOriginWriteReason` triggers; **and the J5 interleave itself**: `toolChange()` runs before `writeWCS()`, so the re-probe writes into the previous section's WCS while the guard checks the current one |
| **C6** | GRBL | XY | J4 | F | `Subsequent WCS / Part` = `Jog to X0 Y0 Z0` / `Jog to X0 Y0, Probe Z0` | `writeWCS` both jog arms, `warnJogAtPauseOnGrbl` fire path and its `validateJob` twin, `multiWcs` gating of that twin |
| **C7** | GRBL | XY | **J3** | F | defaults otherwise | one part, several operations, several WCS: the shape the dialog says to run as separate jobs while nothing refuses it — characterise what is emitted |
| **C8** | GRBL | XY / `Home` | **J6** | F | `Fixed Z Reference` = Spoilboard as C1, `Subsequent WCS / Part` = `Probe Z` | a revisited WCS (G54 → G55 → G54): `writeWCS` suppression, and the second probe of an already-established part — where the tool is when it happens, and what it overwrites |

### D — Operation mix and Manual NC

| ID | Firmware | Shape | Lic | Covers |
|---|---|---|---|---|
| **D1** | GRBL | J2, drilling | **P** | `onCyclePoint` → `expandCyclePoint` for drill / peck / bore / tap; the resulting `onRapid`/`onLinear`/`onDwell` stream; **the interaction with the first-G1→G0 conversion and with `isSafeToRapid` on an expanded cycle**; feed scaling on a pure-Z plunge; `onDwell` GRBL `P` arm |
| **D2** | Marlin | J2, drilling | F | `onDwell` non-GRBL `S` arm; `rapidMovements`' Z-down ordering across the expanded cycle |
| **D3** | GRBL | J2, a WCS/inspection probing operation | F | `isProbeOperation` both signals, `cycleNotSupported` |
| **D4** | GRBL | J5, 3 tools | F | `toolChangeEnabled` **off** → `toolChange`'s suppression warning + its `validateJob` twin + `countDistinctTools`; then **on** with `Include Relocation Code` off → the bare `M6 T<n>` route, checked against GRBL's parser |
| **D5** | GRBL | J1 + Manual NC | F | `onPassThrough` (multi-line, blank lines), `onComment`, `COMMAND_STOP`, Manual NC dwell, `COMMAND_ACTIVATE/DEACTIVATE_SPEED_FEED_SYNCHRONIZATION` |
| **D6** | GRBL | J1, rejected inputs | F | `onRadiusCompensation` non-off error, `onCircular`'s pending-compensation error, `onSection` multi-axis error, `isSectionOrientationSupported` all four traces, `onRapid5D`/`onLinear5D` |
| **D7** | GRBL | J2, arcs | F | XY / ZX / YZ planes; `gPlaneModal`'s `onchange` reset of `gMotionModal`; `maximumCircularSweep = 180` splitting full circles; `iOutput`/`jOutput`/`kOutput`; `limitArcFeed` per plane; a Marlin cross-check that non-XY linearizes back through `onLinear` |

### E — Units, coolant, parsing, re-entry

| ID | Covers |
|---|---|
| **E1** | **Inch-unit job**, GRBL, `Fixed Z Reference` = Machine Z: every `propertyMmToUnit` site walked for double- and missing conversion; `xyzFormat` 4-decimal and `fFormat` 2-decimal arms; `G20`; `G53 Z` read in inches; `Plate Thickness`, `G38 Target`/`Speed`, probe XY offsets, tool-change X/Y/Z, travel speeds, and the three group-2 limits inside the scaling maths |
| **E2** | **Coolant**: GRBL Flood tool + `Channel A Mode` = Flood (`M8`/`M9`); Marlin `M42` codes; `Use custom` named and empty; a tool coolant no channel matches; `tool.coolant` → `coolantLevels` incl. out-of-range; coolant off at `onClose` and at each tool change; both channels live at once |
| **E3** | **Second file in one JavaScript context**: `resetPostState()` against every mutable module global, and whether `onOpen`'s rebuild of `fOutput`/`gMotionModal`/`gPlaneModal` covers what it deliberately omits |
| **E4** | **Safe-Z expression parsing**: `parseSafeZExpr` against valid, `Feed:`/`Clearance:` variants, malformed, empty, negative, unit-suffixed; the ERROR arm in both properties; `resolveSafeZHeight`'s non-absolute-level fallback; `describeSafeZ` single/multi/no-section arms; `roundTo` at very small magnitudes; `parseInterPartTravelZ` sign and format cases |
| **E5** | **Include files**: missing (pre-flight vs `loadFile`'s own `error`), empty, no trailing newline, a start file that replaces `Start()` and so G90/G21, the tool-change pair, and the conditional inclusion of the tool files in the pre-flight |

---

## Candidates already sighted

Recorded from the first full read so the walk confirms or refutes each rather than rediscovering it.
Every one is **unverified** until its story walks it; any that does not survive is dropped without comment.

- `onSection` runs `writeFirstSection()` — which probes the first part's Z — **before** the
  `Do First Change` tool change. (A4)
- `toolChange()` runs before `writeWCS()` for later sections, so `Probe After Tool Change` writes into
  the previous section's WCS; `baseOriginWriteReason()` checks the *current* section's offset. (C5, D4)
- `onLinear`'s first-G1→G0 conversion has no safe-Z test on the destination. (A2″, D1)
- `limitFeedByXYZComponents`'s zero-length arm returns the lesser axis limit — 180 on the defaults — for
  a move that may be a long positioning move. (A2′)
- `rapidMovements*` emit an F word GRBL ignores on G0, so the group-2 travel speeds may be inert there
  while the dialog presents them as machine settings. (A1)
- `writeBaseEstablish()` skips the probe for tool 0 while `fixedZEstablishedInFile()` still reads true,
  so later retracts address an unestablished base. (C1)
- `M6` on GRBL, and `$H` when line numbers are on. (D4, B2)
- `onClose`'s `G17` assert before an include-stop file is GRBL-only; the built-in footer path does not
  re-assert after a `loadFile` reset. (A5)

---

## Deliverable — `Coverage/CoverageReview.md`, written incrementally

The file is created before the first walk and **appended after each story group**, so progress is
visible as it happens rather than arriving at the end. Write points:

1. **Skeleton** — scope, method, dimensions, the full story table with every row's status `pending`,
   and empty Findings / Unwalked sections.
2. **After group A** — A rows marked walked, findings CR-nn appended, unwalked list updated.
3. **After group B**, **after group C**, **after group D**, **after group E** — same, each append.
4. **After the four sweeps** (S1–S4) — cross-cutting findings appended.
5. **Final pass** — findings renumbered by severity, unwalked-code section closed out, verification
   section filled in.

Findings are numbered in discovery order (`CR-01`, `CR-02`, …) and renumbered only at the final pass, so
a number quoted mid-review stays meaningful until then. Each finding:

```
### CR-07 — <one-line title>

**Audience:** Hobbyist | Professional | Both
**Severity:** Machine damage | Wrong part | Wrong output | Cosmetic
**Confidence:** Certain | Firmware-assumption | API-assumption
**Conditions to repeat:** firmware, licence, homing declaration, job shape, the properties that matter.
**Problem:** what is emitted, and what should be.
```

No history, no editorial, no reference to prior versions or to why the code is as it is.

The **Unwalked code** section lists every function and branch no story reached, with the reason — that
is what turns the review into a release decision rather than a list.

`docs/HReview.md` and `docs/PReview.md` are **not** touched; nothing is committed; `check-docs.js` is
not run.

## Verification

The review produces no code, so verification is of the review itself:

- **Ledger completeness** — enumerate every top-level `function` in the `.cps` (~95) and confirm each is
  either in the ledger or in the unwalked section with a stated reason. Nothing silently absent.
- **Branch completeness** — every enum property's every `id`, and both values of every boolean, appears
  in at least one story or in the unwalked list.
- **Licence completeness** — every Direction-1 finding states which licence produces it, and all four
  cells of the licence × `Map G1s -> G0` table are walked.
- **Finding reproducibility** — re-read each finding's stated conditions against the source
  independently of the story that produced it, and confirm the path is reachable from the dialog. A
  finding that cannot be reproduced this way is cut.
- **No duplicate coverage** — no two stories claim the same first-walk of a branch.
