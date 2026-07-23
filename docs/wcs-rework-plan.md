# WCS / Origin Rework — design record & remaining work

This is the design record for the coordinate/probe/tool-change rework in
`MPCNC_v4.0_Beta2.cps`. Phases 1–3 are implemented and verified; their mechanics now live
in the code, so only the enduring decisions are kept here. The actionable backlog to
finish the post is in **[Remaining work](#remaining-work-pick-up-here)**.

User-facing usage (hobby vs. Replicate flows, per-machine setup) lives in `README.md`;
this document is the developer/design record.

---

## Context and stance

The post targets the V1 Engineering **MPCNC / LowRider** family and similar
GRBL / Marlin / RepRap hobby-class machines. The aim is **production-quality CNC workflows**
(multi-fixture, multi-tool, probing, safe cross-part traverses) that **also degrade simply**
for a hobby user on the Fusion Personal license cutting a single operation. Both the full
license and the hobbyist are first-class.

**Development role.** This code is developed by an agent acting in two expert capacities at
once, and decisions should be made from both lenses together:

- an **expert software developer** — Fusion 360 post-processor engineering in JavaScript:
  clean, maintainable code, faithful to this post's existing idioms (e.g. the combined-inline
  `properties` form), with careful regression discipline (default output stays byte-identical);
- an **expert in best-practice CNC operations** — understanding how these machines actually
  behave and designing appropriate, *safe* workflows for both the **V1E hobbyist** (Fusion
  Personal, single operation, manual zeroing) and the **professional** (multi-fixture,
  multi-tool, probing, multiple WCS).

The habit is: settle the CNC-correct workflow first (what a seasoned operator would want to
happen at the machine), then design the software that delivers it.

Two principles drive every decision:

- **Work-relative.** Most target machines have no reliable machine-Z (no tool setter, often
  no Z endstop). The everyday reference is the active **WCS** (the work zero), never the
  machine frame. Tool length is folded into a **Z re-probe after each tool change** (there
  is no TLO). Homing, where present, gives **X/Y** repeatability only; Z homing (where it
  exists) is for its own sake and never becomes the everyday Z reference.
- **Graceful degradation.** Defaults keep the simple single-operation job **byte-for-byte
  unchanged**; every advanced feature (reserved base, cross-part safe-Z, per-part probing)
  is opt-in and emits nothing until enabled.

---

## References — Fusion 360 post-processor documentation

Captured so they don't have to be rediscovered:

- **PostProcessor API class reference** — authoritative list of hooks and helpers
  (`onSection`, `onLinear`/`onRapid`, `writeBlock`, `getProperty`, formatting/motion helpers,
  etc.): <https://cam.autodesk.com/posts/reference/classPostProcessor.html>
- **Post Processor Training Guide (PDF)** — Autodesk's narrative guide to writing posts:
  <https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf>
- **Dumper post** — emits every property / parameter / section value Fusion exposes for a CAM
  job; run it to discover what's actually available before relying on it:
  <https://cam.autodesk.com/hsmposts?p=dump>
- **Library of existing posts** — reference implementations to compare against:
  <https://cam.autodesk.com/hsmposts>
- **HSM post-processor forum** — Autodesk's Q&A for post authors:
  <https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218>

Firmware g-code references (target controllers):

- Marlin: <https://marlinfw.org/meta/gcode/>
- GRBL 1.1 wiki: <https://github.com/gnea/grbl/wiki>
- FluidNC wiki: <http://wiki.fluidnc.com/>

---

## Coordinate model

Production controls keep three references separate: **MCS** (`G53`, from homing), **WCS**
(`G54`–`G59`, `G59.1`–`G59.3` on RepRap), and **TLO** (`G43`, from a tool setter). Most V1E
machines have none fully, hence the work-relative stance above.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to
  that WCS's own register, no cross-contamination. `P` maps 1:1 to Fusion's `workOffset`
  (P1–P6 = G54–G59; P7–P9 = G59.1–G59.3, RepRap only; GRBL is P1–P6).
- **Marlin is single-frame:** no per-WCS registers, so it uses one global `G92` origin. A
  Marlin job that uses more than one distinct work offset is a hard error (Guard C).
- **`workOffset 0`** (Fusion's "default / unset") aliases to WCS 1 / `G54`.

Helper `writeWcsOrigin(wcsNumber, x, y, z)` persists a position into a WCS's own origin
(any axis `undefined` = leave alone); `G10 L20` on GRBL/RepRap, `G92` on Marlin.

## Reserved spoilboard base

For multi-fixture jobs one WCS can be reserved as a **spoilboard base** — a *fixed-surface*
zero (the spoilboard, independent of stock thickness). It is the one frame in which a safe
height is meaningful across parts of differing thickness, which is why the cross-part
safe-Z feature requires it (Guard B).

- **`A_Spoilboard_BaseReserve`** (`None` default | `G54`–`G59` | `G59.1`–`G59.3 (RepRap)`).
  Default `None` keeps the default job byte-identical. When reserved, `G59` is the natural
  choice (highest GRBL slot, keeps `G54` free for parts). Ignored on Marlin (warned).
- **`B_Spoilboard_BaseEstablish`** (bool, default on): probe the spoilboard into the base at job
  start; off = assume pre-set (probe-once/run-many), emitting an Info comment.
  *(See the review note under [Property / dialog conventions](#property--dialog-conventions)
  to convert this to an enum.)*

**Base is transited, not parked** — see the design note below; it governs the retract and
tool-change work.

## Machine frame (homing / MCS)

Group `02 - Establish Machine Coordinates`, per axis (`X`/`Y`/`Z`): **Power-On** (default —
accept current position, incl. an axis already homed at the controller; no motion) or
**Home** (run to endstop). Homing commands:

| Firmware | Command |
|---|---|
| Marlin / RRF (Duet) | `G28 X` / `G28 Y` / `G28 Z` — independent per axis |
| GRBL / FluidNC | `$H` only — one command homes all configured axes |

On GRBL/FluidNC `$H` is all-or-nothing: any axis set to Home emits one `$H`; the per-axis
dropdowns are then documentation of which axes are wired to home. `D_Machine_PromptBeforeHome`
pauses before a **Marlin `G28 Z`** only (movable-plate homing) — never X/Y, never GRBL/RRF.
The post does not control homing order. Default all `Power-On` → no homing emitted.

## Probing & tool changes

- **Work-Z probing only** (`G38.2`, thickness-compensated, attach/remove pauses). No
  tool-length system; X/Y is never probed.
- **Re-probe after each tool change** is the tool-length substitute
  (`H_ToolChange_ProbeAfterChange`).
- **Manual tool change:** retract → move to change position → pause → re-probe Z → resume.
  See remaining work for the ordering fix and the base-relative park.

## Validation guards

Post-time only (the post can't read the live controller):

- **Guard A — no base redefine.** *Using* the reserved base is fine; an operation that would
  **re-establish its origin** (via `A_Probe_OnStart` / `B_Probe_OnChange` /
  `H_ToolChange_ProbeAfterChange`) errors.
- **Guard B — safe-Z across parts needs a base.** `C_Spoilboard_SafeZAcrossWcs` on + >1 distinct
  offset on GRBL/RRF + no base reserved → error. Single-WCS jobs are exempt.
- **Guard C — Marlin single-frame.** A Marlin job using >1 distinct work offset → hard error.

## Property / dialog conventions

Needed when adding new properties:

- **Group order** = the `group:` string, zero-padded to two digits (`01 - Job` …
  `11 - Duet`). Padding is required so `11 - Duet` sorts last, not next to `01 - Job`.
  The current order: `01 - Job`, `02 - Establish Machine Coordinates`, `03 - Spoilboard
  Base`, `04 - Feeds and Speeds`, `05 - Map G1s to Rapids...`, `06 - Probe / Work Origin`,
  `07 - Tool Changes`, `08 - External Include Files`, `09 - Laser`, `10 - Coolant`,
  `11 - Duet`.
  > **Resolved (was: reorder WCS/Probe after Map G1s).** The old combined
  > `03 - Work Coordinate System - WCS / Probe` group was split into two: **`03 - Spoilboard
  > Base`** (`A_Spoilboard_BaseReserve`, `B_Spoilboard_BaseEstablish`,
  > `C_Spoilboard_SafeZAcrossWcs`, `D_Spoilboard_SafeZClearance`) placed right after machine
  > homing so it reads as a setup thought-walk, and **`06 - Probe / Work Origin`** (the part
  > origins, probe XY offset, and G38/Safe-Z/thickness mechanics) placed after Map G1s.
  > This re-lettered the moved keys and changed four keys' group segment from `Probe` to
  > `Spoilboard`; because the key is the stored identifier, the eight renamed keys reset any
  > saved preset to default — a release-notes item.
- **Within-group order** = a single-letter item prefix on the key,
  `<Letter>_<Group>_<Name>` (`A`, `B`, … restarting per group), e.g. `A_Machine_HomeX`.
  New properties take the next free letter (re-letter following ones if inserting mid-group).
- This post uses the **combined-inline** `properties = {}` form (title/description/type/value
  inline). The split `properties` + `propertyDefinitions` form is the *old broken* approach —
  do not reintroduce it.

**Two probe-timing properties, kept separate and relabelled for the Replicate workflow**
(consolidating them was rejected — it would apply job-start XY-zeroing to a mid-job WCS
change, a positioning bug):

- `A_Probe_OnStart` = **"First Part: Set Work Origin"** — `Skip` / `Zero XYZ (no probe)` /
  `Zero XY, probe Z` (default). First/only part origin, set at the current position.
  > **⚠ TODO — shorten the middle option label.** `Zero XYZ (no probe)` still truncates in
  > the Fusion dropdown; find a shorter label (enum id `Zero XYZ` must stay). Cosmetic.
- `B_Probe_OnChange` = **"On Each Added Part"** — `Skip` / `Probe Z` (default). Fires on a
  genuine WCS change after the first section; re-probes each added copy's Z. XY always comes
  from the fixture's pre-set offset (the post never sets XY for added parts).

> **⚠ MARKED FOR REVIEW — make `B_Spoilboard_BaseEstablish` an enum, not a toggle.** Relabel to
> **"Spoilboard WCS is"** with two options: **"Zero XY, Probe Z"** (establish the base now,
> and also set its XY — today's `on`) and **"Use Existing WCS Machine Value"** (trust the
> offset already stored on the controller — today's `off`). Open questions before coding:
> 1. **"Zero XY" gives the base an XY origin it doesn't have today** (the base is currently a
>    Z-only spoilboard reference; the cross-part retract only uses its Z). This is
>    *zero-at-current-position*, parallel to `A_Probe_OnStart`, **not** machine homing (group
>    02 still owns X/Y homing). Decide whether the base's XY is actually consumed or is just
>    harmless bookkeeping.
> 2. **Default** maps today's establish-on to *Zero XY, Probe Z*.
> 3. **Preset migration** — boolean→enum drops stored preset values (reset to the enum
>    default); release-notes item.

---

## Design notes that constrain the remaining work

### Traverse clearance is not the G1→G0 plane

`C_MapRapids_SafeZ` / `safeZHeight` answers a narrower question — "within *this* operation,
is Z high enough to re-emit a cut G1 as a G0?" It is operation-scoped and only populated when
the hobby "Map G1s to Rapids" group is on, so it is the wrong source for an inter-op/inter-WCS
retract (wrong height, and unset for full-license jobs). The cross-part retract instead uses
a **job-level clearance measured above the spoilboard base** (`D_Spoilboard_SafeZClearance` =
"Cross Part Clearance"), the one frame meaningful across all the job's parts. Single-WCS jobs
need none of this — their shared frame makes each operation's own clearance a safe reference,
so they stay byte-identical.

### Base WCS is transited, not parked (R1/R2)

The base-relative retract must *select* the base to move in its frame (the numeric relation
between two WCS is only known after runtime probing). Two rules:

- **R1 — always restore the operating WCS.** After a base transit, advance to the next
  operations' WCS before any cutting; never cut with the base left active. Also restore after
  a section that legitimately cut on the base.
- **R2 — never round-trip the base empty.** Enter the base only when a real move (the
  retract) is emitted there; skip it entirely when in/out WCS match or no traverse is needed.

Mechanism (implemented in `retractThroughBaseClearance()`): transit-select the base with a
low-level `writeBlock` (**not** `writeWCS()` — no re-probe, no origin write), emit the `G0 Z`
clearance, leave the base active; the caller then selects the destination WCS. No base transit
at `onClose`.

---

## Phase status

- **Phase 1 — done & shipped.** WCS origin/probe rework to `G10 L20` (replaces the old `G92`
  single-global-origin hazard); the two probe-timing properties; `writeWcsOrigin()`;
  tool-change re-probe now G10-scoped.
- **Phase 2 — done & verified.** Establish MCS (per-axis homing), in isolation; default
  `Power-On` output byte-identical to the Phase-1 baseline.
- **Phase 3 — done & verified.** Reserved base + establish + Guards A/C (and B's placeholder);
  default `None` byte-identical.
- **Phase 4 — in progress.** Consume the base for safe-Z / traverses / tool-change. Landed &
  verified: Guard B; `Cross Part Clearance` + `Safe Z Retract Across Parts`; the
  base-relative traverse retract on **every** inter-part WCS change (transit-through-base),
  verified on both the re-probe and non-re-probe (Skip) boundaries; added-part re-probe
  repositions to the new part's `X0 Y0` before probing; the WCS/Probe relabels + default flip.
  Landed, verification pending: **probe XY offset** (`C_Probe_OffsetX` / `D_Probe_OffsetY`).
  Remaining items below.
- **Phase 5 — not started** (likely no-op).

---

## Remaining work (pick up here)

### Phase 4 — tool-change ordering + base-relative park *(one unit; design settled)*

Root cause: in `onSection()`, `toolChange()` runs **before** `writeWCS(currentSection)` for
non-first sections, so a boundary that is both a tool change and a WCS change:
- **re-probes into the wrong WCS** — `toolChange()`'s re-probe writes `G10 L20` into
  `currentWorkOffset`, still the *previous* part's WCS; and
- **parks in the wrong frame** — the change-position `onRapid` runs in the previous WCS.

Fix (reorder so the WCS is resolved before the tool-change re-probe, and coordinate the two
so a combined boundary does each thing once):
1. Run `writeWCS()` first — it owns the base retract + frame switch. When a tool change on the
   same section will re-probe, have `writeWCS()` **skip its own `B_Probe_OnChange` probe** and
   let the tool-change flow own the single re-probe (now into the correct WCS).
2. The tool-change re-probe **repositions to the new part's `X0 Y0`** before measuring (same
   fix already applied to the added-part probe), so it reads the stock top, not the park point.
3. **Park position, two branches (decision):**
   - **Base reserved** → park relative to the base (a fixed physical spot for the whole job);
     reuse the transit-select machinery (`retractThroughBaseClearance()`-style low-level emit).
   - **No base** → plain `G0` in the current WCS, as today.
   Never `G53`.

Net at a both-boundary: retract through base → switch WCS → park → swap → rapid to `X0 Y0` →
probe once into the correct WCS. Test matrix: tool-change-only, WCS-change-only, and combined,
each with and without a base.

### Phase 4 — probe XY offset *(implemented — verification pending)*

`C_Probe_OffsetX` / `D_Probe_OffsetY` (`06 - Probe / Work Origin` group). The probe touch-point becomes
origin + (offsetX, offsetY), so the origin can sit at a corner / off the material while Z
probes the stock top. Job-wide, not per-fixture; default `0,0` reproduces prior output.
Applied at **every part probe** — first part (`writeWcsOnStart`, "Zero XY & Probe Z") and
each added part (`writeWCS` `probeNewPart` branch) — and **never** the spoilboard base probe
(`writeBaseEstablish`, always at the origin) nor the tool-change re-probe (that reposition is
part of the ordering item above). Default byte-identical: first-part emits the reposition
rapid only when the offset is nonzero; added-part keeps the exact `X0 Y0` comment/output at
offset 0. Tooltips (`C`/`D` offsets + `B_Spoilboard_BaseEstablish`) and README state the base
probes at 0,0.

*Verification pending:* regression (single-WCS no-offset byte-identical); hands-on (nonzero
offset repositions before the first-part probe and each added-part probe; base probe stays at
0,0).

### Phase 4 — backlog: "Copy first part's Z" option on `B_Probe_OnChange`

A third enum value alongside `Skip` / `Probe Z`: write the first part's probed Z into each
added copy's own register (`G10 L20 P<n> Z<firstPartZ>`) — a register write, **no motion, no
probe** — for same-thickness co-planar fixtures. Requires caching the first part's probed Z at
`A_Probe_OnStart` time. Marlin no-op. The neutral "On Each Added Part" title already
accommodates it. *Deferred until the retract/tool-change work is done.*

### Phase 4 — closeout tests
- Regression: single-WCS, no-base jobs byte-for-byte unaffected.
- Hands-on: multi-WCS via base retract/travel; Guard B fires when safe-Z + multi-WCS + no
  base; a spoilboard-surfacing section on the base restores the following sections' WCS (R1).
- Update `docs/beta2-test-plan.md`.

### Phase 5 — G0/G1 rapid-mapping review
Confirm the "Map G1s to Rapids" optimization needs no change under the new model: does it ever
run across a section/WCS boundary (where Phase 4 injects safe-Z/base logic), or strictly within
one section/WCS? If strictly single-section: document "no change needed" and close as a no-op.
If a cross-boundary case exists: file it as a new item (a collision-risk case Phase 4 didn't
anticipate).

---

## Decisions (resolved)

- **`D_Machine_PromptBeforeHome`** fires only before a plate-homed **Z** home (Marlin), never
  for X/Y or globally.
- **Homing order** is not post-controlled (firmware concern).
- **`B_Spoilboard_BaseEstablish`** defaults **on** (probe the spoilboard into the base); off emits
  an "assumed pre-set" Info comment. *(Under review to become an enum — see above.)*
- **No machine-profile presets** — the per-axis properties stand alone.
- **Marlin multi-WCS is a hard post error** (Guard C).
- **No real TLO** — per-tool re-probe is the substitute.
- **Multi-WCS is Replicate-only** — the per-copy Z re-probe (`B_Probe_OnChange`) and the
  reserved base target milling multiple *copies*, one WCS per copy. One part from multiple
  datums, or a flip, is out of scope for a single run (separate jobs). No capability removed —
  framing only.
- **Tool-change position:** base-relative when a base is reserved (fixed spot across fixtures),
  else current-WCS. Never `G53`. *(Remaining work — current code does only the no-base branch.)*

---

## Reference — per-machine settings

Each row says how each axis gets its reference so the operator knows what to do at job start.
(Candidate for migration into `README.md` if a per-machine section is added there.)

| Machine / firmware | X | Y | Z | Reserved base | Operator does |
|---|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | Home | Home | Home if fitted, else Probe | `G59` if multi-fixture, else `None` | homes X/Y; Z endstops optional (beam squaring); work-Z touched off with the plate either way |
| MPCNC + FluidNC, X/Y switches | Home | Home | Probe | `G59` if multi-fixture | homes X/Y; machine Z n/a (probe pin can't home), Z set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | Home | Home | Home + prompt | `G59` if multi-fixture | homes X/Y; places movable plate at the pause, Z homes to it |
| MPCNC, no switches | Power-On | Power-On | Probe | `G59` if multi-fixture | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | per row above | `None` | one WCS zeroed to the part; no base |
