# HReview — hobbyist-perspective review of `MPCNC_v4.0_Beta2.cps`

The review of the post from the hobbyist's chair, and the verification record for what it changed.
**Reviewed:** the whole post against the README's documented hobbyist use cases, every Fusion entry
point, and every property branch a hobbyist can reach. **Findings:** 19 (`HR-1`…`HR-19`); ten fixed
on branch `v4.0-hreview-fixes`; six reclassified as professional and moved to `docs/PReview.md`.

**Every landed fix is now closed with posted evidence** — HR-1, HR-2, HR-3, HR-4, HR-5, HR-6, HR-11,
HR-14, HR-15, HR-17. **No unrun row needs new CAM.** What remains carries no fix yet: **HR-12** (the
manual spindle is never told about an RPM change — moved back from `PReview.md`), **HR-18**
(`loadFile()` newline, a real corruption path), **HR-16** and **HR-19** (recorded, cosmetic or no fix
proposed), plus the `HW` rows in §6.

**Every test and its state is in [§0 Test register](#0-test-register--every-test-and-its-state)** —
one table, 59 rows, and the only place a pass or fail is recorded.

> **Standing rule — a code change is not done until this file is updated.** Every change to
> `MPCNC_v4.0_Beta2.cps` that touches hobbyist behaviour updates this file **in the same commit**:
> add the Do→Get row that verifies it (exact dialog settings, exact expected g-code, and the
> *discriminator* — the one token whose presence or absence proves the change, often an absence), and
> flag any row whose saved `.gcode` the change invalidates. A stale PASS is worse than an unrun test.
> Cover **both** branches of a new condition: a test that only proves output appears cannot catch a
> guard that never fires. Professional-side changes go in `docs/PReview.md` under the same rule.

**How verification works here:** post the job from Fusion and **read the g-code** — by eye and with
AI review. Machine dry-runs and physical measurement are out of scope, so every row's Pass criteria
must stand on the posted file alone. Posted files go to Fusion's NC output folder
(`C:\Users\don_m\Documents\Fusion 360\NC Programs\`), named after the row; they are not in the repo.

**Conventions.** Comments are `( … )` on GRBL and `; …` on Marlin/RRF — otherwise the tokens are
identical. `G10 L20 P<n>` is GRBL/RepRap; Marlin uses `G92`. Default probe target / speed / thickness
= `Z-10` / `F30` / `Z0.8`. Do everything on **GRBL** first (the default firmware).

---

## 0. Test register — every test and its state

**This table is the authoritative state of every hobbyist test.** Nothing else in this file records
pass/fail; the sections below carry the *reasoning*, the expected tokens and the Do→Get instructions
for whatever is still owed. If the two ever disagree, this table is wrong and must be fixed — a row
whose state lives in two places will rot in one of them.

**65 tests — ✅ 49 PASS · ❌ 0 FAIL · ⬜ 9 UNRUN · ➖ 7 n/a or moved to `PReview.md`.**

**Method** is how the row was settled, and it is not decoration: `posted` is a real file from the real
post and is the only method that proves what a hobbyist receives. `harness` is a node run against
functions extracted from the `.cps`, or a post from `Personal.cps` (§8) — it proves *logic*, not
output. `source` is a reading of firmware source. A ⬜ row's Method column names what it is waiting
for.

| Test | What it proves | Method | Evidence / blocker | State |
|---|---|---|---|---|
| **H1** | `Jog to X0 Y0, Probe Z0` origin mode | posted | `H1.gcode` | ✅ |
| **H2** | `Set X0 Y0 to Current Pos, Probe Z0` — the default path | posted | `H2.gcode` | ✅ |
| **H3** | `Jog to X0 Y0 Z0` — no `G38.2` | posted | `H3.gcode` | ✅ |
| **H4** | `Set X0 Y0 Z0 to Current Pos` — no prompt, no probe | posted | `H4.gcode` | ✅ |
| **H5** | `Use Active WCS X0 Y0 Z0` — no origin write | posted | `H5.gcode` | ✅ |
| **H6** | Marlin + RRF variants of H1 | posted | `H6 - Marlin.gcode`, `H6 - RRF.gcode` | ✅ |
| **H7** | `Use Active WCS X0 Y0, Probe Z0` — absence of the XY origin write | posted | `H7.gcode`, `H7a.gcode` | ✅ |
| **HR-1 (A)** | Provisional `Z0` on the default probe mode | posted | `H2.gcode` | ✅ |
| **HR-1 (B)** | Same on the jog mode | posted | `HR1b.gcode` | ✅ |
| **HR-1 (C)** | **Absent** on `Use Active WCS` — the scope claim | posted | `HR1c.gcode` vs `H7c-a.gcode` | ✅ |
| **HR-1 (D)** | Jet / tool-0 absence | — | → `PReview.md` **J1** | ➖ |
| **HR-1 (E)** | Present on both firmwares, both origin modes | posted | `H11a`, `H11b - RRF`, both `H6` | ✅ |
| **HR-2 (A)** | A drill posts at all — no `ReferenceError` abort, no `G8x` | posted | `Drill_Tap.gcode` | ✅ |
| **HR-2 (A2)** | Tapping warning emitted per occurrence | posted | `Drill_Tap.gcode` | ✅ |
| **HR-2 (B)** | Probing cycles still refused | — | licence cannot create one | ➖ |
| **HR-2 (U)** | `isProbeOperation()` over 8 strategy/cycle inputs | harness | node | ✅ |
| **HR-3 (A)** | GRBL prompts spindle OFF; no `M5`, no `M300` | posted | `H2.gcode` | ✅ |
| **HR-3 (B)** | Automatic branch untouched | posted | `HR3b.gcode`, re-baselined `Face1 (auto).gcode` | ✅ |
| **HR-3 (C)** | Tool-change half | — | → `PReview.md` §3.4 | ➖ |
| **HR-3 (D)** | Marlin/RRF unchanged; only GRBL moved | posted | six session-1 files | ✅ |
| **HR-4 (A)** | Inch: bare-number probe Safe Z converts | posted | `H4a - GRBL Inch.gcode` | ✅ |
| **HR-4 (B)** | mm: identity, no saved reference invalidated | posted | `H4b - GRBL.gcode`, `H7c-a.gcode` | ✅ |
| **HR-4 (C1)** | Inch: the mapper's threshold converts | posted | `H4c - GRBL Inch.gcode` | ✅ |
| **HR-4 (C2)** | The mapper then actually converts moves | harness | `Link-5-GRBL`, `Link-15-GRBL` | ✅ |
| **HR-4 (D)** | Header never mixes mm and inch | posted | `H4base - GRBL Inch.gcode` | ✅ |
| **HR-4 (U)** | Five expression forms across both units | harness | node | ✅ |
| **HR-5 (A)** | Arcs capped at the plane's axis limits | posted | `HR5a.gcode` | ✅ |
| **HR-5 (B)** | Unscaled baseline — arcs at Fusion's raw feed | posted | `HR5b.gcode` | ✅ |
| **HR-5 (C)** | `Max Toolpath Speed` caps arcs too | posted | `HR5c.gcode` | ✅ |
| **HR-5 (D)** | Non-XY (`G18`) arc limited by the slower axis | posted | `HR5a.gcode`, `H11c - GRBL.gcode` | ✅ |
| **HR-5 (E)** | Marlin: linearized segments limited like any `G1` | posted | `H5d - Marlin.gcode` vs `H11a.gcode` | ✅ |
| **HR-6 (A)** | Orientation guard is live, not failing open | posted | `H2 - Debug.gcode` | ✅ |
| **HR-6 (B)** | An off-axis section is actually rejected | — | needs a rotated Setup; optional | ⬜ |
| **HR-11 (A)** | Marlin: `M84 S60`, no `M2` | posted | `H11a.gcode` | ✅ |
| **HR-11 (B)** | RepRap: `M2` after `M84 S60` | posted | `H11b - RRF.gcode` | ✅ |
| **HR-11 (C)** | GRBL tail untouched | posted | `H11c - GRBL.gcode` | ✅ |
| **HR-11 (D)** | Stop file bypasses the whole stop block | posted | `H11d - Marlin.gcode` | ✅ |
| **HR-11 (S)** | Whether Marlin / RRF honour `M2` | source | `gcode.cpp`, `GCodes2.cpp`, RRF changelog | ✅ |
| **HR-12 (A)** | Manual spindle prompts on an RPM change between operations | — | needs the fix; defect witnessed by `Link.gcode` vs `Speed Change.gcode` | ⬜ |
| **HR-12 (A2)** | Two operations at the *same* RPM still give one prompt | — | needs the fix | ⬜ |
| **HR-12 (A3)** | A tapping reversal adds **no** prompt — the 7 direction-only calls stay silent | — | needs the fix; re-post `Drill_Tap.gcode` | ⬜ |
| **HR-14 (A)** | `Flood and Mist` matches a channel | posted | `Drill Flood Mist.gcode` | ✅ |
| **HR-14 (B)** | Warning names the mode the operator saw | posted | `Drill Flood Mist (No).gcode` | ✅ |
| **HR-14 (C)** | Ordinary `Flood` unchanged | posted | `Drill Flood.gcode` | ✅ |
| **HR-14 (D)** | Channel B path, and selection is per-channel | posted | `Drill Mist.gcode`, `Drill Mist (no Mist).gcode` | ✅ |
| **HR-14 (U)** | All 9 indices, before and after — 7/9 → 9/9 | harness | node | ✅ |
| **HR-15 (A)** | Mapping-on post changes nothing but one comment | posted | `H15a - GRBL.gcode` | ✅ |
| **HR-15 (B)** | The level branch is taken, not the fallback | posted | `H15a - GRBL.gcode` | ✅ |
| **HR-16** | `onClose` traverse ordering — recorded, no fix | — | no test proposed | ➖ |
| **HR-17 (A)** | Property heading no longer double-spaced | posted | six session-1 files vs `H2.gcode` | ✅ |
| **HR-17 (B)** | Spindle prompt reads `… RPM` | posted | same | ✅ |
| **HR-17 (C)** | Tapping warning single-spaced | posted | `Drill_Tap.gcode` | ✅ |
| **HR-17 (D)** | The two inert tidy-ups changed nothing | posted | `H11c - GRBL.gcode` vs `H2.gcode` | ✅ |
| **HR-17 (U)** | Sanitizer before/after over 4 input shapes | harness | node | ✅ |
| **HR-18 (A)** | `loadFile()` newline — diagnostic, fix undecided | — | needs a stop file with no trailing newline | ⬜ |
| **HR-19** | `M291` doubled space, and `()` vs `( )` — cosmetic, no fix | — | no test proposed | ➖ |
| **HR-20** | Tapping needs a spindle reversal the post never commands | — | → `PReview.md` (professional, by decision) | ➖ |
| **HW-1** | `isSafeToRapid()`'s three conversion branches | harness | `Link-5-GRBL`, `Link-15-GRBL` | ✅ |
| **HW-2 (A)** | HP-5 boundary: WCS suppression, rapid lifecycle, position tracking | posted | `Link.gcode` | ✅ |
| **HW-2 (B)** | HP-5 boundary: a spindle-speed change between operations | posted | `Speed Change.gcode` | ✅ |
| **HW-3** | `Probe Pause = No` — neither prompt | — | cheap; folds into any GRBL session | ⬜ |
| **HW-4** | `Probe Pause = Before` — attach only | — | cheap; folds into any GRBL session | ⬜ |
| **HW-5** | The documented HP-1 baseline in one file | — | no file has ever had all of it at once | ⬜ |
| **HW-6** | Full regression sweep before release | — | last, after everything above | ⬜ |
| **HW-7** | Dialog audit — labels, defaults, preset survival | — | → `PReview.md` §3.3 (**D1**, **D3**) | ➖ |

**What the 9 ⬜ rows are waiting on — three things, not nine.** **Three cheap posts on CAM that
already exists** (HW-3, HW-4, HW-5); **three one-offs** (HR-6 (B) a rotated Setup, HR-18 (A) a stop
file, HW-6 the final sweep); and **one fix, whose three rows all verify the same change**
(HR-12 (A)(A2)(A3) — the code is the work, the posts are cheap and use CAM that exists).
**No unrun row needs new CAM.** Ranked in [§3](#3-status).

**The one honest gap inside a ✅.** HR-4 (C2) and HW-1 are the only rows carried by `harness` alone.
They prove `isSafeToRapid()`'s logic is right; they do **not** prove a real post ever reaches it,
because on a paid Fusion licence it cannot — see §6. That premise is documented in the code and is not
in doubt, but it is untested and probably untestable here.

---

## 1. Scope — what "correct" means for this review

The README makes a specific promise: *a hobby job — one operation, one part — needs almost no setup.
Jog to your zero, accept the defaults (the post records XY there and probes Z for you), post, run.*

So the bar is: **with the dialog at its defaults plus the handful of changes the README tells a
hobbyist to make, the emitted file must be well-formed for the selected firmware, structurally
complete, and never command a move whose height or frame the post cannot justify.** Anything
requiring the operator to know an undocumented precondition is a finding. Severity throughout is
*hobbyist* severity: how likely this persona is to hit it, times what it costs when they do.

| ID | Perspective | Config (delta from dialog defaults) |
|---|---|---|
| **HP-1** | *The documented baseline.* One Setup, one Operation, one tool, pre-jogged XY, touch plate. | Defaults + firmware set + real travel/max speeds + **Scale Feedrate on** + all four **`03 - Map G1s to Rapids`** on |
| **HP-2** | *No probe.* Same, but Z touched off by hand. | HP-1 + First WCS / Part = `Set X0 Y0 Z0 to Current Pos` |
| **HP-3** | *Guided jog.* Prefers the post to prompt rather than pre-jogging. | HP-1 + First WCS / Part = `Jog to X0 Y0, Probe Z0` (or `Jog to X0 Y0 Z0`) |
| **HP-4** | *Marlin / RepRap hobbyist.* Same job, different controller. | HP-1 + CNC Firmware = Marlin (or RepRap) |
| **HP-5** | *Several operations, one tool, one part, one WCS.* | HP-1 + more than one milling operation |

> **HP-5 was corrected on 2026-07-31.** It previously read *"several operations, maybe several
> tools … optionally group 07 enabled"*. Fusion's Personal licence does not support tool changes, and
> Manual NC is treated the same way, so **group 07 and Manual NC are out of scope here** — the five
> findings that were keyed to the old HP-5 (HR-7, HR-8, HR-9, HR-10, HR-12) plus HR-13 moved to
> `docs/PReview.md`. **HR-12 came back on 2026-07-31** — that sweep was right for the other five and
> wrong for it, because its mechanism involves no tool change: two operations on one tool at different
> RPMs is HP-5 exactly. See §4.3. HP-5 as redefined still matters: it is the only hobbyist persona with a
> **section boundary**, and no posted file has ever exercised one (see §6).

**What a hobbyist does not change, and why it matters.** Group `04` = `None`, group `05` = `None`,
group `06` = defaults except possibly the origin mode, group `07` = off, groups `08`–`11` untouched.
That prunes the flow graph sharply, and it is why a defect on the **default first-part probe path**
outranks anything in the base/traverse machinery: for this persona the default path is the *only*
path. Everything the README puts outside the hobbyist's reach — multi-WCS, the reserved spoilboard
base, `Retract Across Parts`, `Subsequent WCS / Part`, the `Use Active WCS …` modes — is
`PReview.md`'s ground and is touched here only where a hobbyist default can wander into it.

---

## 2. What was read

**Every entry point the post defines was walked** for the hobbyist paths. Sound as built, nothing to
get wrong: `onOpen` (guards run before any output, so a rejected job writes no file), `onSectionEnd`,
`onComment`, `onPassThrough` (deliberately unsanitised, documented), `onRadiusCompensation`
(actionable "In computer" error), `onRapid5D`/`onLinear5D` (multi-axis backstop), `onDwell` (GRBL
`G4 P`, Marlin/RRF `G4 S`, clamped), `onParameter`, `onMovement`. `onPower` is jet-only (deferred
workstream). Findings landed on `onClose` (HR-11, HR-16), `onSection` (HR-6), `onCircular` (HR-5),
`onCyclePoint` (HR-2), `onCommand` (HR-3), and the Safe-Z / feed helpers (HR-4, HR-15).

**Callbacks deliberately not defined**, kernel default correct in each case: `onManualNC` (routes to
`onDwell`/`onPassThrough`/`onCommand`), `onCycle`/`onCycleEnd` (`onCyclePoint` expands every point),
`onMessage`, `onOpenFile`/`onTerminate`/`onMachine`. No `writeRetract`/`setRotation` machinery —
consistent with the deliberate work-relative stance, except for the orientation gap that became HR-6.

**The call sequence for HP-1**, as the spine the findings hang off:

```
onOpen        → firmware resolve · validateJob() (guards A/B/C — a single-WCS hobby job trips none)
                · GRBL "%" · motion/feed formats · currentWorkOffset = undefined · Safe-Z parse
onParameter ×N  header comments
onSection [1] → multi-axis guard · orientation guard (HR-6) · forceSectionToStartWithRapid = true
                writeFirstSection():
                  writeInformation()   ranges · tools · ALL properties · resolved values
                  writeMachineHoming() HP-1: None → nothing
                  writeWCS()           offset 0 → 1 → "G54"      (before any origin write)
                  Start()              G90 · G21/G20 · GRBL: G94 G17 · Marlin/RRF: M84 S0
                  writeBaseEstablish() HP-1: base None → nothing
                  writeWcsOnStart()    ← the whole hobbyist origin story (table below)
                safeZforSection() (HR-15) · toolChange() (returns, group 07 off) · spindle · coolant
              → the toolpath body: onLinear/onRapid/onCircular/onCyclePoint
onClose       → flushMotions · coolant off · G0 X0 Y0 (HR-16) · spindle off (HR-3)
                · GRBL: M30 · Marlin/RRF: M117 + M84 S60 + M2 (HR-11) · GRBL "%"
```

Two structural notes, both deliberate and correct as built. **WCS selection is split** — section 1
selects inside `writeFirstSection()` because it must precede the origin write; later sections select
in `onSection()`'s body. And **`currentWorkOffset` is post state, not machine state**: starting
`undefined` is what forces section 1 to emit its select unconditionally, which is what lets the post
*assert* the frame rather than inherit whatever the sender left modal.

**`A_Probe_OnStart` — the hobbyist's one real decision.** All six branches of `writeWcsOnStart()`:

| Mode | Persona | Emitted |
|---|---|---|
| `Set X0 Y0 to Current Pos, Probe Z0` **(default)** | HP-1 | `G10 L20 P1 X0 Y0 Z0` (provisional Z0 — HR-1) → probe → `G10 L20 P1 Z0.8` → `G0 Z<probeSafeZ>` |
| `Set X0 Y0 Z0 to Current Pos` | HP-2 | `G10 L20 P1 X0 Y0 Z0`, no probe |
| `Jog to X0 Y0, Probe Z0` | HP-3 | `M0` jog prompt → as the default |
| `Jog to X0 Y0 Z0` | HP-3 | `M0` jog prompt → `G10 L20 P1 X0 Y0 Z0` |
| `Use Active WCS X0 Y0, Probe Z0` | pro | `G0 X0 Y0` at an unknown height → probe (carries the "unknown Z" Info line) |
| `Use Active WCS X0 Y0 Z0` | pro | `G0 Z<probeSafeZ>` → `G0 X0 Y0`, no origin write |

For HP-1/2/3 the two `Current …` and two `Jog …` modes are the whole story, and their structure is
right: XY (and optionally Z) recorded at a position the operator physically chose, with
`G10 L20 P<n>` scoping so no origin can leak across WCS.

---

## 3. Status

Ten fixes landed, one commit each, subject-prefixed so `git log --oneline --grep='^HR-'` lists the
series. Each commit message carries the full reasoning; the code carries the *why* at every call
site. **Read the code and the commit, not a restated diff** — that is why the diffs and as-built
notes that used to live in this file are gone.

This table is about the **fixes** — what landed, where, and how far the blast radius reaches. Per-test
state is [§0](#0-test-register--every-test-and-its-state)'s job and is deliberately not repeated here;
the last column says only whether the fix's rows are all in.

| | Fix | Commit | Blast radius | Rows |
|---|---|---|---|---|
| **HR-5** | `Scale Feedrate` reaches G2/G3 arcs | `b95c954` | Only when scaling is on (defaults off) | all in |
| **HR-6** | Rejects a 3-axis section oriented off machine Z | `684f28a` `e2b2424` | None if correct — blocks everything if wrong | (B) optional, owed |
| **HR-1** | Provisional `Z0` bounds the `G38 Target` on the two just-positioned probe modes | `8d61790` | **Default path.** Breaks the old byte anchor | all in |
| **HR-3** | Manual spindle prompts to switch OFF on GRBL too | `43d09aa` | **Every GRBL job's tail** | all in |
| **HR-2** | `isProbeOperation()` defined locally so canned cycles can post at all | `9c87fb0` | Drilling path only | (A)(A2) owed |
| **HR-4** | Safe-Z literal fallbacks convert mm→output unit | `439ce2d` | **Inch jobs only** — identity in mm | all in |
| **HR-11** | Marlin/RRF `M84 S60` timeout restore; program end (`M2`) on RRF only | `7a35f7f` + `8054b6e` | **Every Marlin/RRF job's tail.** GRBL untouched | all in |
| **HR-14** | `coolantLevels` derived from `eCoolant` so both compound modes match | `7e38777` | Coolant-channel jobs only; defaults `Off` | all in |
| **HR-15** | `safeZforSection()` asks the passed section | `88c7817` | None — latent trap closed, no output change | all in |
| **HR-17** | Four tidy-ups: sanitizer double spaces, group rename, vestigial arg, empty GRBL block | `924d1f6` | **Every saved `.gcode`** — property heading and manual-spindle prompt text; no motion | (C) owed with the tap |

Open with no code change: **HR-16** (recorded, no fix proposed), **HR-18** (`loadFile()` newline — has
a Do→Get row, deliberately unfixed), **HR-19** (cosmetic, fold into the next sweep). Moved to
`docs/PReview.md`: **HR-7**, **HR-8**, **HR-9**, **HR-10**, **HR-13** — and **HR-20**, opened there by
decision. **HR-12 was moved back here** (§4.3).

### Verification owed — sessions 1 and 2 are done; one session remains

**Session 1 ran on 2026-07-31** and closed **HR-1**, **HR-3**, **HR-5**, **HR-11** and **HR-15**,
and evidenced **HR-17 (A)(B)(D)**. Eight files:

| File | Config | Serves |
|---|---|---|
| `H11a.gcode` | Marlin, default origin | HR-11 (A), HR-1, HR-3 (D), HR-5 before-half |
| `H6 - Marlin.gcode` | Marlin, jog origin | H6 re-baseline |
| `H11b - RRF.gcode` | RRF, default origin | HR-11 (B), HR-1 |
| `H6 - RRF.gcode` | RRF, jog origin | H6 re-baseline |
| `H11d - Marlin.gcode` | Marlin + Stop File | HR-11 (D) |
| `H11c - GRBL.gcode` | GRBL, all defaults | HR-11 (C), HR-17 (D) — **the current GRBL/mm reference** |
| `H15a - GRBL.gcode` | GRBL + group 03 on | HR-15 (A)(B) — **the mapping-on reference** |
| `H5d - Marlin.gcode` | Marlin + `Scale Feedrate` on | HR-5 limiting half |

> **Two configuration facts worth carrying.** Every file above except the last two was posted at
> **factory defaults on every property** — so the documented **HP-1** baseline (scaling on, mapping
> on, machine-real speeds) still has no single file of its own; `H15a` and `H5d` cover one half each.
> And enabling the mapping group changed **no motion** on this job, so `isSafeToRapid()`'s conversion
> branches are still untested — see §6.

**Session 2 — the inch session — ran on 2026-07-31** and closed **HR-4 (A)(B)(D)**. Four files, the
project's first inch output of any kind:

| File | Config (delta from defaults) | Serves |
|---|---|---|
| `H4base - GRBL Inch.gcode` | inch, **all defaults** | HR-4 (D) — **the inch reference** |
| `H4a - GRBL Inch.gcode` | inch, `06` Safe Z = `20` | HR-4 (A) |
| `H4b - GRBL.gcode` | mm, `06` Safe Z = `20` | HR-4 (B) — the mm regression |
| `H4c - GRBL Inch.gcode` | inch, group 03 all on, Map: Safe Z to Rapid = `20` | HR-4 (C), half only |

> **The inch files are worth more than the row that motivated them.** No inch job had ever been
> posted, so every other `propertyMmToUnit()` call site on the probe path was equally unevidenced;
> `H4a` shows all of them at once. And `H4c` re-confirmed, in a second unit, that this CAM cannot
> exercise `isSafeToRapid()` — see §6.

**Session 3 — the mapper session — ran on 2026-07-31** and closed **HR-4 (C2)** and **HW-1**. Two
files from `Personal.cps`, the harness post described in §8, on a two-operation adaptive job:

| File | Config (delta from defaults) | Serves |
|---|---|---|
| `Link.gcode` | mm, all defaults — the unmodified post | baseline; **HW-2** candidate |
| `Link-5-GRBL.gcode` | `Personal.cps`, group 03 all on, Map Safe Z = `Retract:15` → 5.08 | HW-1, HR-4 (C2) |
| `Link-15-GRBL.gcode` | `Personal.cps`, group 03 all on, Map Safe Z = `15` | HW-1 — the threshold discriminator |

**Session 4 — the drill + tap session — ran on 2026-07-31** and closed **HR-2 (A)(A2)** and
**HR-17 (C)** from one file:

| File | Config (delta from defaults) | Serves |
|---|---|---|
| `Drill_Tap.gcode` | GRBL/mm, **all defaults**; CAM = Peck Drill + 9/16-12 Tap, two tools | HR-2 (A)(A2), HR-17 (C) |

> **It also opened two findings and settled a scope question.** `spindleOn()`'s manual branch drops
> *both* the RPM change between the two operations and the direction reversal each tap withdrawal
> asks for. The RPM half is **HR-12**, moved back here (§4.3); the direction half is **HR-20** in
> `PReview.md`, professional by decision: **drilling must work, tapping may error or warn, and a
> fuller tapping implementation belongs to the professional review.** Neither blocks the three rows
> above, which assert cycle expansion and warning text only.

**Session 5 — the coolant session — ran on 2026-07-31** and closed **HR-14**, the last landed fix
owing a post. Five files on the drill CAM, differing only in group 10 and the operation's coolant:

| File | Tool coolant | Channel A / B Mode | Serves |
|---|---|---|---|
| `Drill Flood.gcode` | Flood | Flood / Off | HR-14 (C) |
| `Drill Mist (no Mist).gcode` | Mist | Flood / **Off** | HR-14 (D) |
| `Drill Mist.gcode` | Mist | Flood / **Mist** | HR-14 (D) |
| `Drill Flood Mist.gcode` | **Flood and mist** | **Flood and Mist** / Mist | HR-14 (A) |
| `Drill Flood Mist (No).gcode` | **Flood and mist** | **Off** / Mist | HR-14 (B) |

> **The last two are the pair that matters** — one property apart, presence against absence from the
> same build. Neither would mean much alone: (A) alone cannot rule out a build that never warns, and
> (B) alone cannot rule out one that never matches.

Remaining, ranked by value — **none of it needs new CAM**:

1. **Three cheap posts on CAM that already exists** — **HW-3** and **HW-4** (`Probe Pause` = `No`, then
   `Before`) on the face-mill job, and **HW-5** (the HP-1 baseline in one file) on the same.
2. **Three one-offs, in no particular order** — **HR-6 (B)** a rotated Setup, **HR-18 (A)** a stop file
   with no trailing newline, and **HW-6** the regression sweep, which goes last by definition.
3. **Two decisions, not posts** — **HR-12** (write the fix, then its Do (A) row verifies it) and
   **HR-18** (decide the `loadFile()` guard). Both are in §4.3 with diffs or diagnostics ready.

Three results worth carrying forward rather than re-deriving:

- **HR-6's guard is live, not failing open.** The Debug trace reads `forward X0 Y0 Z1, tilt from
  machine Z 0 deg -> upright, section allowed`, so Fusion does populate `Section.workPlane.forward`
  with real numbers and the predicate evaluates a real vector on every section. This was the branch's
  worst risk — a false positive blocks all posting, a fail-open read makes the guard dead code — and
  both halves are now excluded.
- **HR-1 did not leak.** `HR1c.gcode` diffs **motion-byte-identical** against its pre-HR-1 reference
  `H7c-a.gcode`. The provisional `Z0` is confined to the two modes where the operator just placed the
  tool, which is the whole design claim.
- **HR-5 (D) needed no special job.** A face mill's helical lead-in/lead-out *are* `G18` ZX-plane
  arcs, and they carry `F180` — the slower of the XY and Z limits — exactly as predicted.

---

## 4. Findings

### 4.1 Closed

**HR-5 — `Scale Feedrate` did not apply to arcs.** *(Medium-High; HP-1 exactly — `Use Arcs` defaults
on and the README tells the hobbyist to enable scaling.)* Every `G1` ran through
`limitFeedByXYZComponents()`; `circular()` emitted Fusion's raw feed on both firmware branches. So a
job with `Max XY Cut Speed = 900` and a tool feed of 1800 scaled every straight cut and emitted every
arc at `F1800` — the feature defeated on exactly the curved geometry a slow machine struggles with,
and invisible unless you watch `F` across a `G1`→`G2` boundary. `limitArcFeed()` now caps an arc at
the axis limits of the **plane it lies in** (deliberately not the chord projection, which
under-protects by up to 1/cos 45° because an arc's instantaneous axis speed reaches the full feed at
each quadrant).

*Verified (A)(B)(C)(D) — all four halves, from the Mounting Plate face-mill job on GRBL:* `HR5b.gcode` (scaling
off) is the unscaled baseline, arcs at Fusion's raw `F2667`/`F1016`; `HR5a.gcode` (XY 900 / Z 180 /
toolpath 1000) drops every `G17` arc to **`F900`**, matching the `G1` blocks either side, no cut feed
above 900 surviving anywhere; `HR5c.gcode` (`Max Toolpath Speed` = 500) reads **`F500`** on the same
arcs and lines; and the ZX-plane half came free from the face mill's helical lead-in —
`G18 G3 X205.286 Z-4.826 I-4.997 F180`, the slower of the two axes it sweeps. Only the `G19` (YZ)
variant is unexercised, and the row accepts either plane. *(The `F2500`/`F300` still present are XY
and Z **travel** feeds on rapids, which the cut limiter does not and should not touch.)*

> **Not a defect — arcs can post slower than the lines either side of them.** A diagonal `G1` may
> exceed 900 (a 45° move at `F1270` puts ~900 on each axis), so a fillet at `F900` between two
> diagonals at `F1270` is correct. Deliberately conservative for short arcs that never reach a
> quadrant point; the reason is recorded at the call site too, since a posted file will look wrong to
> whoever reads it next. **The Marlin/RRF note is now closed, both halves.** *Linearization* —
> `H11c - GRBL.gcode` carries three `G18` ZX-plane arcs (`G18 G3 X205.286 Z-4.826 I-4.997 F1016`) and
> the same geometry in `H11a.gcode` posts as runs of `G1 X… Z…`, linearized by `circular()`'s
> `default:`; Marlin keeps its six XY `G2`/`G3` arcs and the file grows 205 → 314 lines. *Limiting* —
> `H5d - Marlin.gcode` (the same job, `Scale Feedrate` **on**, limits 900 / 180 / 1000) against
> `H11a.gcode` (same job, scaling **off**) is the before/after: **all 122 cut moves in `H11a` exceed
> an axis limit** — worst XY 2667, worst Z 1016 — and in `H5d` **none does**, worst XY 900.8, worst Z
> 180.7, worst toolpath feed 918. The linearized segments are limited exactly like any other `G1`, so
> the inference is now evidence. *(Checked by computing each move's per-axis speed from its own
> deltas, not by reading feeds off the page.)*
>
> **The ≤1 mm/min overshoot is formatting, not a limiter failure.** Feeds are emitted as integers, so
> a segment scaled to 917.2 posts as `F918` and its X axis reads 900.8 against a 900 limit — 0.09%,
> rounding to nearest rather than down. Recorded so the next person who runs a per-axis check does not
> read it as a defect.

**HR-6 — no tool-orientation guard: a rotated 3-axis Setup posted silently wrong g-code.**
*(Medium; any hobbyist who builds a Setup off a model face rather than the stock top — a routine
accident in Fusion, whose symptom is a part cut in the wrong plane rather than an error.)* Multi-axis
was rejected, but a 3-axis section whose tool axis was not machine +Z passed every check: the post
never inspected `workPlane`, never called `isSameDirection()` or `setRotation()`. Now isolated in
`isSectionOrientationSupported()`, which **compares `forward`'s components rather than calling
`isSameDirection()`** (one fewer unverified kernel dependency) and **fails open** — a missing
`workPlane`, missing `forward`, non-numeric or `NaN` components all post exactly as before. Tolerance
is ~0.006° of tilt. `setRotation()` deliberely omitted: the check errors on anything non-upright, so
it could only ever be called with an identity plane, and its effect on the kernel's coordinate
delivery cannot be verified without posting.

**Verified (A).** `H2.gcode` posts complete with no `Tool orientation` message — nothing is blocked, which
was the regression that mattered. `H2 - Debug.gcode` line 359 reads
`( onSection orientation: forward X0 Y0 Z1, tilt from machine Z 0 deg -> upright, section allowed)`.
Making that trace **unconditional rather than rejection-only** is what made one ordinary post decisive
(see §8). The other two trace shapes are `-> OFF-AXIS, section REJECTED` and
`-> UNREADABLE, check skipped, section allowed`; **seeing UNREADABLE on a normal Setup would mean the
guard is a no-op.**

> **(B) — remaining, benign and optional:** the rejection half. Duplicate the hobby Setup with its Z along
> the model's X and post — expect the error naming the fix, and a **truncated `.gcode` on disk**
> (this guard fires in `onSection()`, after the header is written, unlike Guards A/B/C which write
> nothing at all). Nothing here evidences what Fusion reports for a *re-oriented* Setup — it could in
> principle re-express the frame rather than tilt `forward` — so a failure means a missed rejection,
> not a blocked job. **Follow-up worth doing separately:** promote both geometry guards into
> `validateJob()` so neither can leave a partial file. Not done here because it changes the
> long-standing multi-axis guard's behaviour too, which deserves its own decision.

### 4.2 Landed — verification state per finding

---

#### HR-1 — `G38 Target` was an absolute Z in a frame whose Z0 is stale, on the default probe path — **High**

**Reached by:** HP-1 and HP-3 (the two probing defaults), any firmware, any run after the first on a
controller that persists work offsets.

`G_Probe_G38Target` is emitted verbatim as a `Z` word, so `Z-10` meant "descend to the point 10 mm
below G54's *stored* Z zero", not "descend at most 10 mm". Those coincide only when G54's Z0 already
sits near the tool. The failure is a second-run failure, which is why a first-run test survives it:
run 1 probes and writes `G10 L20 P1 Z0.8`, GRBL persists it to EEPROM; the operator powers down, and
with `Home Before Start = None` (the hobbyist default) machine Z comes up wherever it comes up. If run
1's probe happened 35 mm down the Z travel, the tool now reads ~`Z+35.8` at the touch plate and
`G38.2 F30 Z-10` is a **~46 mm probing descent at F30** — it still stops on contact if the plate is
under the tool, but drives ~46 mm into the work if the operator mis-parked or the plate is
thinner/absent. The mirror case is as bad: a stored offset making work Z read `−20` turns `Z-10` into
an *upward* target, so the probe never contacts and the controller alarms.

**As built:** a provisional `Z0` is written alongside the XY zero on the two paths where the operator
has *just* positioned the tool, making the target a true relative travel limit; the probe overwrites
it two lines later, so it never survives into the cut. **Gated on `canProbe`** — with a jet tool or
tool 0 there is no `G38.2` to bound, and writing `Z0` there would silently convert
`Set X0 Y0 to Current Pos, Probe Z0` into `Set X0 Y0 Z0 to Current Pos`.

**Deliberately not extended** to the `Use Active WCS …` modes or the added-part paths: there the tool
arrives at a safe height that may be far above the stock, so pinning `Z0` to the current height would
make `Z-10` *too tight* and turn a working probe into a "did not contact" alarm.

**Consequence on the record:** this is the first change to alter an **emitted command on a default
job**, so it breaks the byte-identical guarantee rather than sidestepping it. The trade was accepted —
an unbounded probing descent on the path every hobbyist uses is the worse failure. See `plan.md`
→ *Graceful degradation* for the amended principle.

**Verified (A)(B)(C) — scope proven.** (A) `H2.gcode`, token for token:
`(   Set current X,Y position to 0,0)` → `(   Provisional Z0 at the current height so the probe
target is a relative limit)` → `G10 L20 P1 X0 Y0 Z0` → `M0 (MSG Attach ZProbe)` → `G38.2 F30 Z-10` →
`G10 L20 P1 Z0.8` → `G0 Z5.08 F300`. (B) `HR1b.gcode`: identical with `M0 (MSG Jog to X0 Y0 above Z0,
probe)` ahead of it — the shared code path carries the provisional `Z0` onto the jog mode too.
(C) `HR1c.gcode` is the discriminator and it holds: on `Use Active WCS X0 Y0, Probe Z0` there is **no
provisional `Z0` and no comment**, the only `G10 L20 P1` being the probe's own `Z0.8`, and the motion
is byte-identical to `H7c-a.gcode`.

**Verified (E) — the firmware half; HR-1 closes.** Session 1, all four probe-mode files, comments in `; …`
form throughout. **Marlin** (`H11a.gcode` default, `H6 - Marlin.gcode` jog):
`;   Set current X,Y position to 0,0` → `;   Provisional Z0 at the current height so the probe target
is a relative limit` → **`G92 X0 Y0 Z0`** → `M0 Attach ZProbe` → `G38.2 F30 Z-10` → `G92 Z0.8` →
`G0 Z5.08 F300`. **RRF** (`H11b - RRF.gcode`, `H6 - RRF.gcode`): `; WCS changed: none -> 1` → `G54` →
same two comments → **`G10 L20 P1 X0 Y0 Z0`** → `M291  P"Attach ZProbe" R"Probe" S3` →
`G38.2 F30 Z-10` → `G10 L20 P1 Z0.8` → `G0 Z5.08 F300`. The `Z0` word is present on the pre-probe
origin write on **both** firmwares and in **both** origin modes, so the shared code path carries the
provisional zero everywhere the design claims it does. The jog files add
`M0 Jog to X0 Y0 above Z0, probe` / `M291  P"Jog to X0 Y0 above Z0, probe" R"Set origin" S3 X1 Y1 Z1`
ahead of it — note RRF alone gets the `X1 Y1 Z1` jog-enable words.
*(**(D)** — the jet/tool-0 absence — is folded into **J1** in `PReview.md`.)*

> **Open decision.** The added-part `Jog to X0 Y0, Probe Z0` branch of `writeWCS()` has the same shape
> and arguably the same argument. Left unchanged deliberately: it is a professional multi-part path
> whose verification rows are unrun, and the tool arrives there from a *retracted* clearance where its
> Z is materially less predictable. If the answer is "yes, symmetric" it is the same three lines —
> settle it on the PA1/M4 run (`PReview.md` → M4).

---

#### HR-2 — `isProbeOperation()` had no definition in this file; any drilling operation could abort the post — **High**

**Reached by:** HP-1/HP-5 with any drill, peck, bore or tap operation — i.e. any hobbyist who drills a
hole.

`onCyclePoint()` calls `isProbeOperation()`, which is conventionally a **post-local** helper in the
Autodesk reference posts, not a kernel global — and it was defined nowhere in this file. If the kernel
at `minimumRevision = 45917` does not supply one, `onCyclePoint` throws a `ReferenceError` on the
first drilled hole and the post aborts with no useful message; the whole canned-cycle path would be
unusable and nothing else in the post would show a symptom. Not settleable by reading — it depends on
the kernel's global table — but the asymmetry of cost made the decision easy: a local definition is
three lines and is harmless if the kernel also provides one.

**As built — two signals, not one.** The reference form tests `operation-strategy == "probe"` alone;
as built it also returns true when `cycleType` is prefixed `probing`. The strategy names the
*operation*, `cycleType` names the *individual cycle at each point*, and either can miss alone — if
the strategy string ever differs from `"probe"`, the strategy-only form falls through to
`expandCyclePoint()` and emits **plain `G0`/`G1` motion where a probe was intended**, which is exactly
the silent-wrong outcome the guard exists to prevent. **This makes the guard broader, which is a
behaviour change worth naming:** a job containing a probing cycle whose strategy was not `"probe"`
previously posted (silently, as non-probing motion) and now errors. *Open, low-stakes: whether to keep
the extra breadth or trim to the strict reference form (a two-line edit).*

**Verified (U) — unit-checked at the JS level.** The helper run against stubbed
`hasParameter`/`getParameter`/`cycleType`: strategy `probe` → true; `probing-x` /
`probing-xy-outer-corner` / `probing-z` → true; `drilling` / `tapping` / `boring` → false; no strategy
parameter → false; `cycleType` absent → false. Eight cases, all passing.

**Verified (A)(A2) — HR-2 closes. `Drill_Tap.gcode`, 2026-07-31**, GRBL/mm at factory defaults: a
`Peck Drill` (tool 6) and a `9/16-12 Tap` (tool 8).

**(A)** Each hole expands into ordinary moves and **no `G81`/`G82`/`G83`/`G73` appears anywhere** — the
peck pattern is emitted as alternating cut and retract:

```
Z-12.7 F300
G1 Z-21.054 F737
G0 Z-20.792 F300
G1 Z-24.328 F737
```

and the file runs through to `( *** STOP end ***)` then `%`. **The discriminator is that a file exists
and reaches STOP end** — an abort with no `.gcode` was the failure mode, and it did not happen.
`onCyclePoint` had never been exercised by any row before this: every other file in the record is
contour, pocket or face milling.

**(A2)** The tapping warning appears on **every** activate and deactivate occurrence — eight for four
holes — without disturbing the surrounding blocks, and it is **single-spaced**, which is
**HR-17 (C)**: no match anywhere for `synchronization  rigid`, `tapping  is` or `WARNING:  `.

```
( >>> WARNING: Speed-feed synchronization rigid tapping is not supported; a floating/tension tap holder is required)
```

*(This row previously pinned **doubled** spaces there and told the reader not to "fix" them — that was
HR-17's parenthesis-stripping defect, since swept.)*

> **What this file also exposed, and the scope decision taken on it (2026-07-31).** Each hole's
> withdrawal emits `( COMMAND_SPINDLE_COUNTERCLOCKWISE)` → `Z-12.7 F1058` →
> `( COMMAND_SPINDLE_CLOCKWISE)`: Fusion asks for a reversal, the post comments it and emits no
> command, so a right-hand tap is driven back out still turning forward. **Decision: drilling must
> work; tapping is allowed to error or warn, and a fuller tapping implementation belongs to the
> professional review.** Filed as **HR-20** in `PReview.md` — it is not a bar to closing (A2), which
> only ever asserted the warning text. *The RPM half of the same `spindleOn()` weakness is a separate
> and hobbyist-reachable defect — see **HR-12** in §4.3.*

**(B) — probing must still be refused: not applicable on this licence.** Fusion's probing /
Inspection strategies need the Machining Extension, so a Personal-licence hobbyist cannot create one —
which is also why the drilling path was never exercised while the probing guard sat unreachable. The
unit check above is the substitute evidence. Recorded as *not applicable*, not blank, so nobody later
reads it as unrun.

> **What (A) cannot answer.** Whether the kernel supplies `isProbeOperation()` is now moot — a local
> definition shadows it either way — so (A) does not distinguish "the fix was necessary" from "the fix
> was redundant"; a passing drill post is consistent with both. To settle it, post a drill from a
> stashed pre-fix copy first. Only worth the trouble for the record.

---

#### HR-3 — GRBL + Manual Spindle On/Off never prompted the operator to switch the router *off* — **High**

**Reached by:** HP-1 exactly as documented. GRBL is the default firmware, `Manual Spindle On/Off`
defaults **true**, and the README tells the hobbyist to leave it on.

`spindleOn()` honoured the manual setting on every firmware — it prompts `M0 (MSG Turn ON 18000 RPM)`
(the space arrived with HR-17; the saved files predating it read `18000RPM`).
`spindleOff()` branched on **firmware first** and emitted a bare `M5` on GRBL regardless, which does
nothing to a hand-switched router: the file asked the operator to switch the router on and never asked
them to switch it off, so the job finished with the router still spinning. Marlin and RepRap users got
the prompt; GRBL users, the majority, did not. The same asymmetry bit harder at a tool change, where
the operator was invited to reach into the machine with no instruction to switch off first.

**As built:** `spindleOff()` now branches on the property first, firmware only inside it. Two removals
worth stating because a later reader will question both: **no `M5` on the manual path, on any
firmware** — mirroring `spindleOn()`, which emits no `M3` under manual control, and matching what the
Marlin/RepRap manual path already did (jet tools never reach here, so GRBL laser mode is unaffected);
and **the `M300` beep stays Marlin/RRF-only**, since GRBL has no beep command and emitting one would
be HR-10's defect in a new place.

**Blast radius — the widest on the branch.** Every GRBL job with the default setting now ends with a
prompt instead of `M5`, and gains one at each tool change. That is *every* saved GRBL `.gcode`
predating 2026-07-31. No row's assertions move — none assert on the stop block or on `M5`, and no
motion changed — but a tail diff will show a difference that is not a regression.

**Verified (A)(B).** (A) `H2.gcode`: `( *** STOP begin ***)` → `( COMMAND_COOLANT_OFF)` →
`X0 Y0 F2500` → `( COMMAND_STOP_SPINDLE)` → `M0 (MSG Turn OFF spindle)` → `M30`, with **no `M5` and
no `M300` anywhere** — the discriminating pair of absences. *(The `G0` is suppressed as modal: the
last motion word before the stop block is the section's own `G0 Z` retract. Assert the coordinates and
their position in the block, not the literal `G0`.)* (B) `HR3b.gcode` (manual off):
`( >>> Spindle Speed 7000)` → `M3 S7000` at the start, `M5` in the stop block, **no prompts
anywhere** — and diffed against `H2.gcode` those two spindle lines are the only functional
differences in the whole file, so the automatic branch is exactly where it was.

**Verified (D) — HR-3 closes.** Session 1. The Marlin/RRF stop block is unchanged from the saved `H6`
behaviour: `; COMMAND_STOP_SPINDLE` → `M300 S300 P3000` → `M0 Turn OFF spindle` (Marlin) /
`M291  P"Turn OFF spindle" R"Spindle" S3` (RRF). **No bare `M5` in any of the six files**, GRBL
included, which is the fix's whole claim; the beep stayed Marlin/RRF-only, so HR-10's defect was not
recreated on GRBL. Only GRBL moved.

*(The two-tool tool-change half — the case where the operator is told to switch off before reaching
into the machine — is professional; it is in `PReview.md` §3.4.)*

---

#### HR-4 — Safe-Z fallback constants were never converted from mm to output units — **Medium-High**

**Reached by:** HP-1 on an **inch** Setup — a large share of the V1E audience — whenever a Safe-Z
expression falls back to its literal. **That is more often than it looks:** not just a bare number,
but whenever the named F360 level is *relative* (`..._absolute != 1`) or absent, and whenever the
expression is malformed. So `Retract:15` on an inch job with a relative retract height hits it.

The README's contract is that the post outputs in the Setup's units but **all properties are entered
in millimetres**, and every other dimensional property honours it via `propertyMmToUnit()`. The two
Safe-Z properties did not, producing two distinct wrong behaviours: `I_Probe_SafeZ` emitted `G0 Z15` =
**381 mm** on an inch job (a full-travel Z retract, most likely a hard stop against the limit); and
`C_MapRapids_SafeZ` compared inches against a threshold of `15`, never true, so the G1→G0 mapper
**silently converted nothing** — the hobbyist enables the group the README tells them to enable and
gets none of it, with no diagnostic.

**As built — four call sites, not the two first proposed**, all found by reading again rather than
trusting the earlier pass: `resolveSafeZHeight()` has **two** `return dflt` sites (the second is the
fall-through reached when the level is relative or absent — the *more* common path);
`safeZforSection()` has **eight** fallback assignments (one each for `CONST`/`ERROR`, two each for
`FEED`/`RETRACT`/`CLEARANCE`); and `describeSafeZ()` needed converting too, or an inch job's header
would read `fallback 15.000, resolves to 0.2000` — mm and inch on one line, worse than the original
error because it looks authoritative. Resolved F360 levels are **not** converted: Fusion already
reports those in output units.

**mm jobs are bit-for-bit unchanged** (`propertyMmToUnit()` is the identity in mm), which is why this
is the one fix on the branch with no blast radius — every saved reference is a mm job.

**Verified (U) — harness, across both units** before landing: `Retract:15` with an absolute level → `5` /
`0.2` (level passes through untouched); relative level → `15` / `0.5906`; absent → `15` / `0.5906`;
bare `20` → `20` / `0.7874`; malformed `Retract:` → `15` / `0.5906`.

**Verified (A)(B)(D) — session 2, 2026-07-31.** **(A)** `H4a - GRBL Inch.gcode`, `Safe Z` = `20`:
`(   Probe SafeZ = Const = 0.7874 -- a fixed height, no F360 level consulted)` →
`(   Retract the tool to 0.7874015748031497)` → `G0 Z0.7874 F11.81`. `Z0.7874`, **not** `Z20`.
*(The unformatted number in the comment is pre-existing — `probeTool()` prints `retractZ` raw rather
than through `zFormat`. Cosmetic; don't chase it.)* **(B)** `H4b - GRBL.gcode` is the same property
value in **mm** and differs from `H11c - GRBL.gcode` in **five lines only**: timestamp, the
`I_Probe_SafeZ` value, the Resolved Values line, the retract comment, and `G0 Z5.08 F300` →
`G0 Z20 F300`. No motion, feed or ordering moved. **(D)** `H4base - GRBL Inch.gcode`, both Safe-Z
properties at their `Retract:15` default, reads `fallback 0.5906, resolves to 0.2` on **both** lines
with `Inter Part Safe Z in output units = 1.5748` beside them — no line in the block mixes units.

**The 2×2 is what makes it decisive** — the same property value resolving by unit, and the identity
in mm that leaves every saved reference intact:

| `Safe Z` property | mm | inch |
|---|---|---|
| `Retract:15` (default) | `Z5.08` | `Z0.2` |
| `20` | `Z20` | `Z0.7874` |

**The pre-fix half came free.** `H7c.gcode` / `H7c-a.gcode` were posted 2026-07-30 14:59, before
`439ce2d` landed at 16:51, and read `(   Retract the tool to 5.08)` — identical to `H11c`'s, so the mm
path demonstrably did not move. **(B)'s original pass criterion was wrong and is corrected here:** it
asked for a *byte-identical* pre-fix post, which HR-4 itself made impossible by rewriting
`describeSafeZ()` — `H7c-a` reads `(   Map SafeZ mode = Retract : default = 15)` where the current
build reads `(   Map SafeZ = Retract level, fallback 15, resolves to 5.08)`. The criterion is
**motion-identical with the same resolved retract**.

**Every other conversion on the probe path is evidenced too**, for the first time — no inch job had
ever been posted, so none of these call sites had any posted evidence either:
`(   Set Z to probe thickness: Z0.0315)` (0.8 mm), `G38.2 F1.18 Z-0.3937` (G38 Speed 30, Target -10),
`F11.81` / `F98.43` (Travel Z 300, Travel XY 2500). Fusion's own cut feeds map 1:1 onto `H11c`'s —
`F105`/`F52.5`/`F40`/`F13.33` against `F2667`/`F1334`/`F1016`/`F339` — so it is the same geometry and
nothing is converted twice.

**Verified (C1) — the threshold converts.** `H4c - GRBL Inch.gcode` (inch, all three group-03 booleans
on, `Map: Safe Z to Rapid` = `20`) carries the decisive comment
`( SafeZ using const: 0.7874015748031497)`; pre-fix that line read `( SafeZ using const: 20)`, a
threshold of twenty **inches** that no toolpath can reach, which is the whole defect. **No conversion
fired in that file** — a 20 mm / 0.7874 in threshold sits *above* the 5.08 mm that already defeated
`H15a - GRBL.gcode` in mm, while the job's highest Z is `Z0.6` (15.24 mm). Not a failure of the fix;
the job cannot reach any threshold, in either unit.

**Verified (C2) — the mapper then converts, via the `Personal.cps` harness.** Splitting (C) in two is
the honest bookkeeping: (C1) is the part HR-4 changed, and it is posted; (C2) is "does the mapper do
anything once the threshold is right", which is `isSafeToRapid()`'s own coverage and is **HW-1**. It
closed on `Link-5-GRBL.gcode` / `Link-15-GRBL.gcode` — see §6.

> **What (C1)+(C2) do not amount to.** No **inch** file has ever shown an actual conversion: (C1) is
> inch and (C2) is mm. Nothing in `isSafeToRapid()` is unit-specific once the threshold is converted —
> it compares two numbers already in output units — so a third post was judged not worth it. Recorded
> so the seam is visible rather than glossed.

---

#### HR-11 — Marlin / RepRap jobs never ended, and left every stepper energised — **Medium**

**Reached by:** HP-4, on every job.

Two halves in the same place. **No program end:** `onClose()` emitted `M30` on GRBL and, for
everything else, only `M117 Job end` — no `M2` or `M30` at all. **Steppers stayed on:** `Start()`
emits `M84 S0` on Marlin/RRF to *disable* the idle timeout deliberately, so the machine cannot lose
position mid-job, and nothing ever restored it — so after the job the machine sat with all axes
energised indefinitely, motors and drivers heating, for a job that had finished. The GRBL path has
neither problem, which is why this reads as a gap in the Marlin branch rather than a design choice.

**As built:** `M84 S60` on both, then `M2` **on RepRap only**. `S60` rather than a bare `M84` because a
bare one releases the motors the instant it runs and an unbalanced LowRider gantry with no brake sinks
in Z; a 60-second timeout holds the axes while the operator retrieves the part, then releases without
anyone remembering to. **The `Stop File` branch is deliberately untouched** — `onClose()` bypasses the
whole stop block when `B_Include_StopFile` is set, and `M30` was already inside the bypassed region, so
a custom stop file owns the entire stop sequence, program end included.

> ### (S) `M2` — settled from firmware source, not from a controller (2026-07-31)
> This was the branch's only open correctness question, and the only fix that could not be settled by
> reading the posted file. It was closed by reading the **firmware** instead — no Marlin or Duet
> hardware was needed, and none is needed to verify the rows below.
>
> **Marlin has never implemented `M2`.** `gcode.h`'s supported-code list jumps **M1 → M3** in both
> `2.0.x` and `bugfix-2.1.x`, and `gcode.cpp`'s M-code switch has **no `case 2:`** (0, 1, 3, 4, 5, 7,
> 8, 9, 10), so `M2` falls to `default:` → `parser.unknown_command_warning()` → `echo:Unknown command:
> "M2"`. Harmless — motion is flushed and the spindle is off — but a spurious error line in the
> console of *every* Marlin job. Corroborated in the wild: LightBurn emitted `M2` at end of job and
> Marlin users saw exactly that echo; it was removed for cleanliness.
>
> **RRF gained `M2` in 3.5.1** — changelog: *"M2 (end job) command is now supported. It behaves the
> same as M0."* Source agrees: `3.5-dev/src/GCodes/GCodes2.cpp` has `case 0:` / `case 1:` / `case 2:`
> sharing one block that calls `StopPrint(&gb, StopPrintReason::normalCompletion)` for a file channel.
> `3.4-dev` has no `case 2:` — it tries a `/sys/M2.g` macro, then reports `Bad command: M2` and
> continues. That bounded cost is why the emit is **not** gated on a firmware version.
>
> So the original finding was half right: the missing program end was a real gap on RRF and a
> non-thing on Marlin, where **end of file *is* the program end**. The branch now splits on firmware.
>
> **Carried consequence, unique to RRF:** `M2` is not inert — being the `M0` path, it runs the
> operator's `stop.g`, *after* the `M84 S60` above. A `stop.g` containing a bare `M84`/`M18` releases
> the steppers immediately and defeats the timeout. Not a reason to drop `M2`; a reason the two lines
> must stay in this order, and worth a README note if RRF users appear.

**Verified (A)(B)(C)(D) — HR-11 closes.** Session 1, four files, and the pair (A)/(B) is what makes it
decisive rather than either row alone.

**(A) Marlin** (`H11a.gcode`): tail reads `M0 Turn OFF spindle` → `M400` → `M117 Job end` →
`;   Restore stepper timeout` → `M84 S60` → `; *** STOP end ***`. The `S` value is **`60`, not `0`**,
and there is **no `M2` anywhere in the file**. `M84 S0` still appears once, at the top, where `Start()`
disables the timeout for the job — so the pair reads as intended: disabled at the start, restored at
the end.

**(B) RepRap** (`H11b - RRF.gcode`): identical tail plus **`M2`** after `M84 S60`. `M2` present here
and absent in (A) is the discriminator — a build that emitted `M2` on both firmwares, or on neither,
fails one of the two.

**(C) GRBL regression** (`H11c - GRBL.gcode`): ends `M0 (MSG Turn OFF spindle)` → `M30` →
`( *** STOP end ***)` → `%`, with **no `M84` at all** (not even `S0`, since `Start()`'s disable is
Marlin/RRF-only) and no `M2`. Diffed against `H2.gcode` the whole file differs in **four lines**: the
timestamp, HR-17's two text changes, and one dialog-setting difference (`B_Probe_OnChange` reads
`Probe Z` where `H2` read `Jog XY & Probe Z` — a *Subsequent WCS / Part* value with no effect on a
single-section job). **No motion, feed or comment ordering differs.** The fix stayed inside the
non-GRBL branch.

**(D) Stop-file bypass** (`H11d - Marlin.gcode`): the included file's four lines appear between the
`--- Start/End custom gcode` comments, and **`M117 Job end`, `M84 S60`, `M2` and `M30` are all
absent**, as is `; *** STOP end ***` — the whole stop block is bypassed, exactly the treatment `M30`
already had. *(This row is only meaningful because (A) and (B) proved the blocks appear when the
bypass is off; on its own an absence row would pass against a build that emitted nothing anywhere —
which is exactly what the first, stale-build attempt at this session did. See §8.)*

> **Precondition worth knowing before re-running (D):** configuring any group-08 include file makes
> the post read a file from disk, and Fusion answers that with **"This post processor might be
> unsafe … continue without any restrictions?"** — a provenance prompt for an unsigned `.cps`, not a
> detected problem. Answer **Yes**; answering No blocks the read, so `loadFile()` takes its
> `Can't open file` branch and `error()` aborts the post. A declined prompt **invalidates** the row
> rather than failing it.

> **`H6 - Marlin.gcode` and `H6 - RRF.gcode` were re-baselined by session 1** and now carry the
> current tail and origin write. They were stale twice over — no program end, no provisional `Z0`.

---

#### HR-14 — two coolant modes could never match a channel — **Low**

**Reached by:** any hobbyist whose tool requests *Flood and Mist* or *Flood and ThroughTool* with a
matching channel configured — niche, but the failure is total and the diagnostic misleading.

`coolantLevels[]` (indexed by Fusion's numeric `tool.coolant`) and `eCoolant` (whose values are the
channel-mode property's stored ids) were independent literals and had drifted apart at indices 7 and
8: `"FloodMist"` vs `"Flood and Mist"`. `setCoolant()` compares the two, so those modes could never
match a channel the operator *had* configured for exactly them, and the fall-through warning named
`FloodMist` — a string that appears nowhere in the dialog.

**As built:** `eCoolant` now precedes `coolantLevels`, and the array is built from it — deriving one
table from the other removes the class of defect rather than the instance. The declaration order is
load-bearing (the `const` initialises at load time and reads `eCoolant`) and the comment says so; the
comment also records that the **index is Fusion's `tool.coolant` constant**, so the array must never
be re-ordered for tidiness. That is the property the original literal depended on silently, and the
one an unwary edit would break.

**Verified (U) — harness, before *and* after**, which is what makes it more than a plausible fix: every
index `0`–`8` compared against the id the channel-mode property stores for the same coolant —
**7 of 9 matching before, 9 of 9 after**. Also checked that `coolantLevels.indexOf()` finds every
entry (so the warning names the mode rather than printing `unknown`) and that an out-of-range
`tool.coolant` still falls back to `Off`. No saved reference file is affected: coolant defaults to
`Off`, indices 0–6 are unchanged, and the two changed modes could not previously match on any file.

**Verified (A)(B)(C)(D) — HR-14 closes. Five files, 2026-07-31**, all GRBL/mm on one Peck Drill, all
at factory defaults but the group-10 rows named. **(A) and (B) are one property apart**, which is what
makes the absence in (A) mean anything.

**(A) `Drill Flood Mist.gcode`** — tool coolant **Flood and mist**, Channel A Mode
**Flood and Mist**: `( >>> Coolant Channel A: Flood and Mist)` → `M7`, and
`( >>> Coolant Channel A: Off)` → `M9` in the stop block, with **no warning anywhere in the file**.
Index 7 is one of the two the old literal got wrong, so on a pre-fix build this exact dialog could not
match — it would have warned and emitted no `M7`.

**(B) `Drill Flood Mist (No).gcode`** — the same file with **Channel A Mode = `Off`**, nothing else
touched. `( >>> WARNING: No matching Coolant channel : Flood and Mist requested)`. It reads
**`Flood and Mist`**, not `FloodMist` and not `unknown` — the discriminator, and the proof the fix
reached the *diagnostic* and not only the comparison. The two expressions are different
(`getProperty(...) == coolant` versus `coolantLevels.indexOf(coolant)`), so (A) passing does not imply
(B).

**(C) `Drill Flood.gcode`** — tool coolant **Flood**, Channel A Mode **Flood**:
`( >>> Coolant Channel A: Flood)` → `M7`, `M9` at the end, no warning. Indices 0–6 behave exactly as
they always did; diffed against `Drill_Tap.gcode` (same CAM, channel `Off`) the warning line is
replaced by the match plus its code, and nothing else moves.

**(D) Channel B, and channel selection is per-channel — new coverage, not part of the original
finding.** `Drill Mist.gcode` / `Drill Mist (no Mist).gcode`, tool coolant **Mist**: with Channel B
Mode = `Mist` the file emits `( >>> Coolant Channel B: Mist)` → `M8` → `M9`; with it `Off`, the
warning. **No posted file had ever exercised Channel B at all** — `CoolantB()` and the `E_`/`F_`
properties were unevidenced. And in both files Channel A is set to `Flood` while the tool asks for
something else: **A stays silent, no `M7`**, so each `if` really is testing its own channel's mode.
*(Index 2 matched before the fix too, so (D) discriminates nothing about HR-14 itself — it is
coverage, not evidence for the fix.)*

> **How to run a compound mode on two channels — the sentence that would have saved a detour.**
> `setCoolant()` compares each channel's mode against the tool's request with **exact string
> equality**, so a `Flood and Mist` request does **not** light up a `Flood` channel plus a `Mist`
> channel: `Drill Flood Mist.gcode` has Channel B on `Mist` and it correctly stays off. To run both
> outputs on a compound request, set **both** channels to `Flood and Mist`. The property means *"enable
> this channel when the tool asks for this coolant"*, not *"this channel is the flood channel"* — its
> tooltip says so, but the other reading is the natural one and was tried first.

---

#### HR-15 — `safeZforSection()` mixed global `hasParameter()` with `_section.getParameter()` — **Low**

The exact defect already found and fixed in `resolveSafeZHeight()` — where it was live, not latent,
and made `writeResolvedValues()` print the fallback for every operation — survived in
`safeZforSection()`: each of the three F360-level branches tested the **global** `hasParameter()` then
read the value from the **passed** `_section`. Harmless today, since the sole caller passes
`currentSection` from inside `onSection()`. It is a latent trap: the function takes a `_section`
argument, which is an invitation to call it with a different one, and the moment anyone does the guard
reports on the wrong section and hands back the fallback.

**As built:** all three guards read `_section.hasParameter(...)`, plus one comment above the `switch`
stating the rule once and pointing at `resolveSafeZHeight()`. The point is that the next reader adding
a fourth `eSafeZ` mode copies the `_section.` form — a silent convention would not survive that, which
is how the original three came to disagree with their own `getParameter()` calls. No value, unit or
branch outcome changes.

**Two rows, not one — a "nothing changed" fix cannot be verified by reading the file for something.**

> ⚠ **Session 1 did not exercise this finding.** All six files were posted with the four
> `03 - Map G1s to Rapids` properties `false`, so `safeZforSection()` never ran: no
> `SafeZ using const:` / `SafeZ retract level:` comment appears in any of them. *(The
> `Map SafeZ = Retract level, fallback 15, resolves to 5.08` line in those files comes from
> `writeResolvedValues()` via `resolveSafeZHeight()` — the function where this defect was already
> fixed — so it is **not** evidence for this row.)* Both rows stand unrun; turn the group on.

**Verified (A)(B) — HR-15 closes.** `H15a - GRBL.gcode` (2026-07-31): the default hobby job on
GRBL/mm with the `03 - Map G1s to Rapids` group **on** and nothing else changed.

**(A)** Diffed against `H11c - GRBL.gcode` the whole file differs in **five lines**: the timestamp, the
three group-03 property values flipping to `true`, and **one added line**. No motion, no feed, no
reordering, no change to the origin or probe blocks.

**(B)** That one added line is the discriminator: `( SafeZ retract level: 5.08)` — the **resolved**
level, not ` SafeZ: retract level not defined`. The level branch is taken, so the three guards are
reading the section they were handed. *(A) alone would not have shown this: a fix that broke all three
guards to `false` posts byte-identically on a `Const:` job, which consults no level at all — the same
fail-open lesson HR-6 taught.*

> **The row as originally written was unexecutable** — it said to diff a mapping-**on** post against
> `H2.gcode` and expect "only the timestamp", but no file in the record had ever had the group on, so
> there was no same-config reference and enabling the group emits a new comment by design.
>
> **What this post does *not* establish:** enabling all three mapping booleans changed **no motion at
> all** on this job. Not one `First G1 --> G0` or `Safe G1 --> G0` conversion fired, because the
> sections already begin with real `G0` rapids and every cut move sits below the 5.08 safe height. The
> conversion logic remains entirely untested — see §6.

---

#### HR-17 — four tidy-ups, swept in one commit — **Cosmetic**, but two of them change emitted text

Three were pure reader-facing cleanups; the fourth (`sanitizeMessageText`) and the group rename that
rode with it **do** change bytes in every file, which is why this is here rather than in §4.3.

**As built.**

| Item | Resolution |
|---|---|
| `sanitizeMessageText` left doubled spaces | A stripped character standing beside a space it did not consume contributed a second blank — `synchronization (rigid tapping) is` → `synchronization  rigid tapping  is`. A second pass squeezes **interior** runs only (`(\S) {2,}(?=\S)`), so the leading/trailing whitespace the function's contract promises callers is untouched |
| Group name `"03 - Map G1s to Rapids (disable when using full license)"` | Renamed to `"03 - Map G1s to Rapids - disable when using full license"` — parens removed at the source rather than laundered by the sanitizer. **This alters a visible dialog label** (decision taken 2026-07-31). The `03 - ` prefix is kept, so the lexicographic sort that reproduces dialog order is unaffected |
| `linearMovements(x, y, z, feed, true)` — 5 args to a 4-parameter function | Vestigial `true` dropped. No behaviour change: the parameter never existed |
| `flushMotions()`'s empty `if (fw == eFirmware.GRBL) {}` | Early `return` carrying the reason — GRBL has no wait-for-moves code and `M400` would be an unknown command there |
| `"Turn ON " + …format(rpm) + "RPM"` | Now `" RPM"` — the prompt reads `Turn ON 18000 RPM` |

**Verified (U) — harness, before *and* after**, both implementations against the same inputs: the tapping
warning, the old and new group names, a `();`-bearing operation name with an embedded newline, and
indented text. Every interior double gap present in the old output is gone in the new one; leading and
trailing whitespace is byte-identical on every case that carries any. The three inputs whose leading
or trailing space *does* move are those that begin or end with an unsafe character — the old code
turned that character into a space too, so the behaviour is unchanged there.

**Blast radius — two of these reach every saved `.gcode`.** No row's assertions move, but a diff will
show differences that are not regressions:

- the property dump's heading for group 03 now reads
  `03 - Map G1s to Rapids - disable when using full license` where it read
  `03 - Map G1s to Rapids  disable when using full license ` (parens stripped to doubled blanks, note
  the trailing one). **Every** saved file carries the property dump;
- every manual-spindle job's start prompt gains a space: `M0 (MSG Turn ON 18000 RPM)`. HR-3's verified
  (A)(B) assert the *OFF* prompt and are unaffected; HR-12's expected tokens (§4.3) were updated with
  this commit;
- the dialog label change gives **`PReview.md` D3 a real change to test** rather than a hypothetical —
  a saved preset now has a renamed `group:` string to survive.

**Verified (A)(B)(D) — session 1.** The pre-fix files make this a genuine before/after rather than an
assertion about the "after" alone.

**(A) the header.** All six files read
`Properties -- 03 - Map G1s to Rapids - disable when using full license:`. The pre-fix `H2.gcode` reads
`( Properties -- 03 - Map G1s to Rapids  disable when using full license :)` — doubled blank before
`disable`, and a stray blank before the colon where the closing paren was. Both are gone.

**(B) the prompt.** `M0 (MSG Turn ON 7000 RPM)` on GRBL, `M0 Turn ON 7000 RPM` on Marlin,
`M291  P"Turn ON 7000 RPM" R"Spindle" S3` on RRF, against `H2.gcode`'s `Turn ON 7000RPM`. *(This job
runs 7000 RPM, not the 18000 the row was drafted around; the space is the assertion, not the number.)*

**(D) the regression.** `H11c - GRBL.gcode` against `H2.gcode` differs in four lines only: timestamp,
(A), (B), and one dialog-setting value (`B_Probe_OnChange`) that differs because the two posts were
made with different *Subsequent WCS / Part* settings — inert on a single-section job. **No motion, no
feed, no comment reordering**, which is what shows the vestigial-argument and `flushMotions()` items
changed nothing.

**Verified (C) — HR-17 closes.** `Drill_Tap.gcode` (2026-07-31) carries the tapping warning eight
times, single-spaced throughout:
`( >>> WARNING: Speed-feed synchronization rigid tapping is not supported; a floating/tension tap
holder is required)`. Evidence and the surrounding scope decision are under **HR-2 (A2)**, which this
row rode along on.

### 4.3 Open — no code change

**HR-16 — `onClose` traverses to `X0 Y0` before stopping the spindle, with no guaranteed safe Z.**
*(Low.)* The order is coolant off → `G0 X0 Y0` → spindle off. The `At End Go to 0,0` tooltip is honest
(*"Z remains unchanged"*), and after a milling operation Fusion's own final retract leaves Z at the
operation's clearance, so the traverse is normally safe. Two residual notes: the move happens with the
spindle still running — not dangerous (a spinning cutter traversing in air is the safer of the two)
but it inverts the conventional order; and on a jet/laser job, or any last operation that does not
retract, the traverse runs at cut height. **No fix proposed**, recorded so the ordering is a choice on
the record rather than an accident. Revisit with the jet/laser workstream (`PReview.md` §5), which is
where this same line of code actually bites.

*(HR-17's tidy-ups are no longer open — they landed as one sweep; see §4.2.)*

**HR-18 — `loadFile()` does not guarantee a line break after an included file, so the next block can
be appended to its last line.** *(Medium; group 08, so outside HP-1…HP-5's defaults, but it is a
silent corruption when it fires.)* `loadFile()` emits the file's text with `write()`, which adds no
newline. `H11d - Marlin.gcode` shows the consequence directly:

```
Stop file last line; --- End custom gcode C:\…\Stop File.gcode
```

The closing `--- End custom gcode` comment landed **on** the include file's last line, because
`Stop File.gcode` has no trailing newline. Benign as posted — a trailing comment is legal on all three
firmwares — **but that comment is `Info` level.** At Comment Level `Important` or `Off` it is
suppressed, and the next thing written is `flushMotions()`'s `M400`, which would then merge into
`Stop file last lineM400`. A real stop file ending `M5` with no trailing newline yields `M5M400`: one
invalid block, silently. The same applies to the Start and Tool include files, and to the g-code
*before* the include if that path ever writes without a newline.

*Not fixed here.* The fix is a one-line guard — emit a newline after the loaded text when it does not
end in one — but it touches the shared `loadFile()` used by **every** include branch, and those
branches have no test rows at all yet. **Do:** set a Stop File whose last line is `M5` with no
trailing newline, post at Comment Level `Important`, and read the last block. **Pass:** `M5` and
`M400` are on separate lines.

**HR-19 — `M291` blocks carry a doubled space.** *(Cosmetic.)* `askUser()` builds its RRF parameter
string starting with a space (`" P\"" + …`) and then hands it to `writeBlock()`, which inserts the word
separator too: `M291  P"Attach ZProbe" R"Probe" S3`. Legal — RRF tolerates the whitespace, and all four
RRF prompts in session 1 are well formed — but it is the same class of defect HR-17 swept, in the one
place HR-17 did not look. Fold into the next tidy-up pass; do not fix it alone, since every RRF file
would need re-baselining for one blank.

> **A second item for the same sweep**, found in `Drill_Tap.gcode`: empty comments emit as `()` on the
> two `onSectionEnd()` lines and as `( )` on the other sixteen, because one call site passes `""` and
> the rest pass `" "`. Pick one and use it everywhere.

**HR-12 — a manual spindle is never told about an RPM change between operations.** *(Medium; **moved
back from `PReview.md` on 2026-07-31** — see the box below.)*

`spindleOn()` guards its prompt on `!spindleEnabled`, and `spindleEnabled` is cleared only in
`spindleOff()`, which within a job runs at a tool change or at close. `setSpindeSpeed()` correctly
detects the change — its condition tests both speed and direction — and then `spindleOn()`'s manual
branch throws the answer away. So section 2 asking for 12000 RPM after section 1 ran at 18000 reaches
the guard, the prompt is blocked, and **nothing in the file mentions the change** — while
`currentSpindleSpeed` is updated regardless, so the post believes it happened. For a hand-set router
that is the gap between the operator's dial and the speed Fusion computed the feeds against: a burnt
cutter or a poor finish, silently. The automatic branch re-emits `M3 S<speed>` every time, so this is
manual-only — and manual is the default the README tells a hobbyist to leave on.

> **⚠ The diff first filed here was wrong, and `Drill_Tap.gcode` is what caught it.** It added a bare
> `else` on the reasoning that *"the caller only reaches here when the requested RPM actually
> changed"*. It does not. `setSpindeSpeed()` fires on **speed OR direction** —
> `(currentSpindleSpeed != _spindleSpeed) || (_spindleSpeed > 0 && currentSpindleClockwise != _clockwise)`
> — and a tapping reversal changes direction at the *same* speed, twice per hole. Replaying that
> condition over `Drill_Tap.gcode` gives **seven direction-only calls** in the tap section (lines 253,
> 256, 267, 270, 281, 284, 295). The bare `else` would turn every one into
> `M0 (MSG Set spindle to 1200 RPM)`: seven job-stopping pauses, each naming a speed that is not
> changing and none mentioning the reversal that is. **It would make the tap job materially worse.**
> The diff was written before HR-20 existed; gating on the speed itself keeps the two apart.

**As proposed — gate on the speed, not on the `else`.**

```diff
 var spindleEnabled = false;
+// Manual path only: the RPM the operator was last ASKED for, as the formatted string that
+// reached the file. Compared as text because two speeds that format identically are the same
+// speed to the operator -- the same reasoning isSafeToRapid() uses for positions.
+var lastPromptedSpeed = "";
 
 function spindleOn(_spindleSpeed, _clockwise) {
   if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
+    var rpm = speedFormat.format(_spindleSpeed);
     // For manual any positive input speed assumed as enabled. so it's just a flag
     if (!spindleEnabled) {
       writeComment(eComment.Important, " >>> Spindle Speed: Manual");
-      askUser("Turn ON " + speedFormat.format(_spindleSpeed) + " RPM", "Spindle", false);
+      askUser("Turn ON " + rpm + " RPM", "Spindle", false);
+      lastPromptedSpeed = rpm;
     }
+    // setSpindeSpeed() also reaches us when only the DIRECTION changed at the same speed -- a
+    // tapping reversal does it twice per hole, seven times in Drill_Tap.gcode. Prompting
+    // "Set spindle to <the same number>" there would be a spurious stop naming the wrong thing,
+    // so gate on the speed itself. Direction under manual control is unsolved and deliberately
+    // still silent -- see PReview.md HR-20.
+    else if (rpm != lastPromptedSpeed) {
+      writeComment(eComment.Important, " >>> Spindle Speed: Manual change");
+      askUser("Set spindle to " + rpm + " RPM", "Spindle", false);
+      lastPromptedSpeed = rpm;
+    }
   } else {
```

Two choices worth naming. **The comparison is on formatted text, not raw numbers** — two speeds that
print the same are the same speed to the operator, and prompting for an invisible change is worse than
not prompting; that is the precedent `isSafeToRapid()` set for positions. And **`spindleOff()` is left
alone**: it clears `spindleEnabled`, so the next `spindleOn()` takes the first branch and overwrites
`lastPromptedSpeed` anyway — a reset there would be dead code.

**Do (A) — the fix does something.** Re-post `Link.gcode`'s CAM (two operations, one tool, 12000 then
10000), `Manual Spindle On/Off` on. **Get (A):** `M0 (MSG Turn ON 12000 RPM)` before section 1 and
`( >>> Spindle Speed: Manual change)` → **`M0 (MSG Set spindle to 10000 RPM)`** before section 2.
**Pass:** two prompts, and the second names 10000.

**Do (A2) — the common case gains no stop.** Two operations at the **same** RPM. **Get (A2):** one
prompt. **Pass:** exactly one — `setSpindeSpeed()` short-circuits before `spindleOn()` is reached, and
if it ever stopped doing so this row would catch it.

**Do (A3) — the regression the refinement exists for.** Re-post `Drill_Tap.gcode` unchanged.
**Get (A3):** the tap section gains **zero** prompts; the only spindle prompt in the file is still the
drill's `M0 (MSG Turn ON 2220 RPM)`. **Pass:** zero. Seven would mean the bare-`else` form shipped.
*(`Speed Change.gcode` is the automatic-branch control: nothing outside the manual branch is touched,
so a re-post must differ from it by its timestamp alone.)*

**Witnessed on a posted pair, 2026-07-31 — one tool, one WCS, no tool change.** The two files are the
**same CAM one property apart**, and the diff is the finding:

| | `Link.gcode` (manual, the default) | `Speed Change.gcode` (automatic) |
|---|---|---|
| section 1 | `M0 (MSG Turn ON 12000 RPM)` | `M3 S12000` |
| section 2 | *— nothing —* | `M3 S10000` |
| tail | `M0 (MSG Turn OFF spindle)` | `M5` |

`diff` reports section 2's pair as a pure **addition** (`2315a2316,2317`): the manual file has no
counterpart at all. **The operations genuinely differ, 12000 → 10000**, so a hobbyist running
`Link.gcode` cuts the second adaptive operation at 12000 with feeds Fusion computed for 10000 — 20%
over, silently, on a two-operation job with **one tool and no tool change**. That is HP-5 exactly.

> **Why it came back.** HR-12 was one of the six findings swept into `PReview.md` when HP-5 was
> redefined, on the reasoning that Fusion Personal has no tool changes. That was right for the other
> five and **wrong for this one: the mechanism involves no tool change at all.** `Drill_Tap.gcode` was
> the first sighting, but it used two tools and someone could fairly have answered *"you turned tool
> changes off"*. The `Link` / `Speed Change` pair removes that objection: one tool, no tool change, two
> ordinary adaptive operations. Found by reading, now witnessed twice. Leaving it in a file labelled
> *parking lot, professional, not started* would have kept a hobbyist-reachable defect out of the
> pre-release set. **The direction half of the same weakness stays professional** — `PReview.md`
> **HR-20**.
>
> **Severity is unchanged at Medium** — the cost is a burnt cutter or a poor finish, not a crash — but
> its *reachability* is no longer an argument. Re-rate if that changes the release calculus.

---

## 5. Origin-mode coverage

The six `First WCS / Part` modes on a single milling operation, GRBL, real tool (≠ 0, not a jet). A
single-op job has no WCS change, so this is the only origin control exercised. These rows predate the
review and are kept as the coverage record; the HR rows above carry the current tokens where a fix
moved them. **State and evidence files are in [§0](#0-test-register--every-test-and-its-state)** — what
follows is what each row *means*.

| Row | Mode | Notes |
|---|---|---|
| **H1** | `Jog to X0 Y0, Probe Z0` — jog prompt, XY zeroed at the jogged position, Z probed into `P1` | ⚠ tokens now per **HR-1 (B)** |
| **H2** | `Set X0 Y0 to Current Pos, Probe Z0` (**default**) — no jog prompt, XY zeroed at the parked position | re-posted 2026-07-31; ⚠ tokens now per **HR-1 (A)** |
| **H3** | `Jog to X0 Y0 Z0` — jog all three axes, `G10 L20 P1 X0 Y0 Z0`, **no `G38.2`** | |
| **H4** | `Set X0 Y0 Z0 to Current Pos` — fully manual, no prompt, no probe | jet/tool-0 half → **J1** |
| **H5** | `Use Active WCS X0 Y0 Z0` — trust the stored origin: `G0 Z<probeSafeZ>` then `G0 X0 Y0`, no origin write, no probe | |
| **H6** | Firmware variant of H1 on **Marlin** and **RRF** — comments switch to `; …`, Marlin emits `G92`, RRF emits `G54` + `G10 L20 P1 …` with `M291 … S3` dialogs; no spurious multi-WCS warning on a single-op Marlin job | **re-baselined 2026-07-31.** The only warning in either file is `No matching Coolant channel : Flood requested` — the tool asking for Flood with no channel configured, **not** a WCS warning |
| **H7** | `Use Active WCS X0 Y0, Probe Z0` — stored XY, re-probe Z. Discriminator is the **absence** of `G10 L20 P1 X0 Y0` | `H7a` nonzero-offset also passed; `H7b` → **J1**; `H7e` firmware → `PReview.md` |

The base-reserved sub-checks that ran on the H7 path — **H7c** (base probes and retracts in its own
frame), **H7d** (Guard A fires, no file written), **H7f** (the "unknown Z" warning appears only when Z
really is unknown) — all **PASS**, and are recorded in `PReview.md` §4 with their evidence files,
since the spoilboard base is a professional feature.

> **H-REG — the old byte-for-byte anchor — is OMITTED, and must not be revived as written.** There was
> never a practical way to produce a pre-rework reference, and both halves of the claim have since
> been broken deliberately: the property dump adds ~98 header comment lines to every file, and HR-1
> appends ` Z0` to the default path's origin write, so a *motion-only* diff against a pre-rework
> reference now fails too. Structural coverage of the default path is **H2 + HR-1**. If a byte anchor
> is ever wanted again it must be re-baselined against a current post.

---

## 6. Hobbyist work owed before a public release — the `HW` rows

The tests that belong to no single finding. **State is in
[§0](#0-test-register--every-test-and-its-state)**; this section is what each row is *for* and how to
run it.

**HW-1 — `isSafeToRapid()`'s three conversion branches. ✅ closed 2026-07-31, and the reason it took
three attempts is the durable lesson.** The branches had never run. Three files failed to reach them
before anyone questioned the premise: `2D Contour1.gcode` (a full-licence run that stayed at Z ≤ 1 mm),
then `H15a - GRBL.gcode` with the mapping group deliberately on, then `H4c - GRBL Inch.gcode` in a
second unit. Each failure was written off as the wrong CAM.

> **It was never CAM.** `isSafeToRapid()` is called from **one place**, `onLinear()`, and
> `onRapid()` never consults it. On a **paid** Fusion licence every link, lift and traverse arrives as
> a rapid, so the whole `03 - Map G1s to Rapids` group is **structurally unreachable no matter what the
> toolpath or the dialog does**. The group exists to recover rapids that Fusion **Personal** downgrades
> to feed moves — the comment above the call site says exactly that, and three posted files were spent
> before anyone read it. *The earlier claim in this section and in `plan.md` that this "needs CAM, not
> a dialog change" was wrong.*
>
> `Link.gcode` is what made it visible: it **has** the geometry — 35 flat traverses at the 5.08 mm
> retract level and 3 at the 15.24 mm clearance — and every one of them is a `G0`.

Closed with `Personal.cps` (§8), which reroutes `onRapid()` into `onLinear()` so the real function
sees the real geometry. Two posts, differing only in the threshold:

| File | `Map: Safe Z to Rapid` | `First G1 --> G0` | `Safe G1 --> G0` | case 1 / 2 / 3 |
|---|---|---|---|---|
| `Link-5-GRBL.gcode` | `Retract:15` → **5.08** | 2 | **74** | 35 / 37 / 2 |
| `Link-15-GRBL.gcode` | `15` | 2 | **2** | 0 / 2 / 0 |

Every conversion in both files satisfies one of the three documented cases, and **no move that
qualified was refused** — checked by replaying all 17,955 blocks against the function's own rules, not
by counting comments. All three branches fire at 5.08. The canonical shape appears verbatim:

```
( Safe G1 --> G0)
G0 Z5.08 F300          <- case 2: lift, XY constant
( Safe G1 --> G0)
X-7.297 Y87.309 F2500  <- case 1: traverse at retract height, G0 suppressed as modal
G1 Z-52.705 F2500      <- refused: plunge below safe Z
```

**Three things stop this from being over-claimed.** *The guard half is the stronger result:* all
17,779 genuine cut moves stayed `G1`, the lowest converted Z is 5.08 — exactly the threshold — and the
one diagonal move (XY *and* Z changing, so no case applies) was never converted. *The threshold gates:*
74 → 2 on identical geometry. *And the limit:* this is harness evidence about the **logic**. It does
not show a real post reaching the code, because on this licence none can. That premise is documented
and not in doubt, but it is untested and probably untestable here. **Two counting traps** for whoever
re-checks: `grep -c '^G0'` under-counts badly (modal suppression), and refused *vertical* moves carry
the XY travel feed, a `Personal.cps` artifact — see its banner.

**HW-2 — two operations, one tool, one WCS, no base.** Every H row is a **single-section** job, so
every section-boundary behaviour was unverified for HP-5. The professional rows would cover some of it
but change the WCS at the same boundary, confounding the variables. `Link.gcode` — two adaptive
operations, one tool `T1`, one WCS, no base, no tool change, GRBL/mm at factory defaults — supplied it
without a new post.

**(A) ✅ closed by reading `Link.gcode`, three behaviours.**

- **WCS re-selection suppression.** `( WCS changed: none -> 1)` → `G54` at section 1;
  `( WCS unchanged: 1, not re-selecting)` at section 2. **One `G54` in 19,339 lines**, and the
  suppression names itself rather than leaving a silent absence.
- **`forceSectionToStartWithRapid` lifecycle.** Section 2's first move is `Z15.24 F300` with **no `G0`
  word**, which reads wrong until you check what precedes it: section 1 ends with Fusion's own
  `G0 Z15.24 F300`, so `gMotionModal` carries G0 across the boundary and the arrival really is a rapid.
  No `G1` is left as the modal state entering a new section. With the mapping group off the flag itself
  is inert, so this is the baseline behaviour.
- **Position tracking across the boundary.** `onSectionEnd()` → `resetAll()` resets
  `xOutput`/`yOutput`/`zOutput`/`fOutput`, so section 2 re-emits `Z15.24` and full `X…Y…` instead of
  relying on modal suppression — the section is self-describing even though the tool is already there.
  *Weak form:* nothing is **injected** at this boundary (no WCS change, no base retract, no tool
  change), so there is no post-generated motion for the tracking to lose. The strong version is
  **HR-8**, professional, and needs exactly the injected motion this job lacks.

**(B) ⬜ — and it cannot be verified in this configuration, which is HR-12's signature.** Section 1
prompts `M0 (MSG Turn ON 12000 RPM)`; section 2 emits `( COMMAND_START_SPINDLE)` and
`( COMMAND_SPINDLE_CLOCKWISE)` and no prompt. **That output is identical whether the behaviour is
correct or defective** — same RPM means `setSpindeSpeed()` short-circuits and one prompt is right;
different RPM means `spindleOn()`'s manual branch swallowed it, which is HR-12. The header cannot
settle it either: the Tools Table records geometry only (`T1 D=9.525 CR=0.508 - ZMIN=-55.88`), and the
second operation's RPM appears nowhere in the file.

**(B) ✅ closed by `Speed Change.gcode` — the same job, `Manual Spindle On/Off` = false.** The
automatic branch re-emits at the boundary: `( >>> Spindle Speed 12000)` → `M3 S12000` at section 1 and
`( >>> Spindle Speed 10000)` → `M3 S10000` at section 2. **Two `M3`s, different speeds** —
`setSpindeSpeed()` detects the change and the automatic path acts on it. HR-3 (B)'s "automatic branch
untouched" now also holds across a section boundary, not just a single-section job.

**And it settled the other question, badly.** The two operations *do* run at different RPMs, so
`Link.gcode` is a **genuine HR-12 witness** rather than merely consistent with one. See §4.3.

> **`Face1 (auto).gcode` (2026-07-31) does not serve (B)** — it is `Manual Spindle On/Off` = false on
> the **single-section** face-mill job, and one section cannot show a change *between* sections. What
> it does give: `( >>> Spindle Speed 7000)` → `M3 S7000` → `M5`, a current-build re-baseline of
> **HR-3 (B)**, whose evidence `HR3b.gcode` predates the HR-17 sweep. Diffed against it, only the
> timestamp and the group-03 heading differ.

**HW-3 / HW-4 — `Probe Pause` = `No`, then `Before`.** Only the default `Before & After` is verified,
on every H row. *Get:* `No` → the `G38.2` block with **neither** `Attach ZProbe` nor `Detach ZProbe`;
`Before` → attach only. **Pass:** the prompt count changes and **nothing else does** — diff each
against `H2.gcode` and expect only the `M0` lines to differ.

**HW-5 — the documented HP-1 baseline in one file.** Scaling on, all four group-03 booleans on,
machine-real travel and max speeds. No file has ever carried all of it at once: `H15a` and `H5d` cover
one half each, and every other session-1 file was posted at factory defaults.

**HW-6 — full regression sweep.** Last, by definition. Re-run the sample jobs and confirm no output
differences beyond the intended Beta-2 changes — in particular that single-WCS, no-base jobs are
unaffected, diffed against a current-post reference rather than a pre-rework one.

**HW-7 — dialog audit.** **D1** (labels/defaults) and **D3**'s dialog half (does a saved preset survive
the group reorder?) are release-relevant but cover all eleven groups, so they live in `PReview.md`
§3.3. Neither needs a post; both need the dialog.

> ⚠ **`README.md` still carries the old group-03 label**
> (`03 - Map G1s to Rapids (disable when using full license)`) — left alone per the standing "no README
> edits during code changes" rule. Fold it into the next doc-sync pass.

**Confidence statement.** For HP-1 through HP-5 the *structure* of the emitted file is established by
reading: preamble ordering, WCS selection before any origin write, units and absolute mode before any
probe, comment syntax per firmware, arc and cycle handling, guard placement, and the origin/probe
dispatch for all six First WCS / Part modes. What reading could not establish — HR-2's kernel
dependency and HR-6's `workPlane` behaviour — HR-6 has since settled by posting; HR-2's drilling half
is still owed. **To claim "high confidence that the post outputs correctly formatted, structurally
sound g-code for a hobbyist from every F360 entry point"**, the **13 ⬜ rows** in
[§0](#0-test-register--every-test-and-its-state) are what stand between here and that claim — and they
reduce to four pieces of work, listed under §3.

---

## 7. Checked and found sound

Recording the negative results, because "we looked" is part of the confidence claim.

| Area | Why it is correct |
|---|---|
| **Guards on hobbyist jobs** | A single-WCS job trips none of A/B/C. Guard B correctly exempts one distinct offset; Guard C's `collectDistinctOffsets()` aliases `0`→`1` the same way `writeWCS()` does, so a default Marlin Setup cannot false-positive. All three run before any output, so a rejected job writes no file (H7d) |
| **Feedrate leakage from rapids into cuts** | `rapidMovementsXY`/`Z` emit `F<travel>` on their `G0` lines, which on Marlin *is* honoured and on GRBL sets the modal feed. Safe regardless of `Enforce Feedrate`, because `fOutput` is the **same** modal variable the cut emitter uses — a differing cut feed always re-emits `F` |
| **Split rapids** | Emitting Z and XY as separate `G0`s, each at its own axis travel speed, is what makes travel speeds meaningful on Marlin (where `G0` honours `F`). The *ordering input* is the problem (HR-8, now professional), not the split |
| **`G1 → G0` conversion rules** | `isSafeToRapid()`'s three cases (Z constant in the safe zone; Z up with XY constant; Z down with XY constant and both ends safe) are conservative and correctly gated. Rounding both sides to output precision before comparing is the right fix for representation noise — two positions that format identically *are* the same point |
| **`G10 L20 P<n>` origin scoping** | Writing into a named register rather than `G92` means an origin cannot leak across WCS. `writeWcsOrigin()`'s per-axis `undefined` handling is exactly what the XY-only and Z-only writes need |
| **WCS assertion, not inheritance** | `currentWorkOffset = undefined` in `onOpen()` forces section 1 to emit its select unconditionally, so a stale selection in the sender cannot be inherited |
| **Comment safety** | `writeComment()` sanitises `()` before wrapping in GRBL's `(…)`, and `askUser`/`display_text` sanitise `();` — so a tool comment or operation name containing a paren, semicolon or newline cannot break out into an active block |
| **Multi-axis rejection** | `onSection` fails at the start of the offending operation, with `onLinear5D`/`onRapid5D` as a backstop. Good layering. (The *orientation* gap was HR-6 — a different check) |
| **Radius compensation** | Rejected in `onRadiusCompensation` with an actionable message, and re-checked in `onCircular` and both rapid emitters |
| **Arc handling** | `maximumCircularSweep = toRad(180)` splits full circles into two arcs, avoiding the start==end quirk; `allowHelicalMoves = false` linearizes helices; Marlin's XY-only restriction is enforced in `circular()`'s `default: linearize()`. The `gPlaneModal` `onchange` → `gMotionModal.reset()` correctly re-emits G2/G3 after a plane switch, and survives `gMotionModal` being *reassigned* in `onOpen()` because the closure resolves the variable at call time |
| **Canned cycles** | Expanding to `G0`/`G1` is the right call for all three firmwares. Rejecting probing cycles rather than expanding them into non-probing motion is correct (subject to HR-2) |
| **`Include Whitespace = false`** | `G0X10Y5F2500`, `G10L20P1X0Y0`, `M84Z` are all legal — these parsers are word-based. The prompt helpers re-insert a leading space where the message needs separating |
| **Property dump** | Iterating `properties` rather than listing keys means it cannot drift; the zero-padded group strings make a lexicographic sort reproduce dialog order; enum values print as stored `id`s so relabelling does not break a saved review. **The single most valuable thing in the file for reviewability** — every finding above was easier to reason about because of it |
| **Probe pause threading** | `probePauseBefore`/`probePauseAfter` set by the caller and reset by `probeTool()` is fragile-looking but correct: every caller sets both immediately before invoking, and the reset keeps the tool-change re-probe prompting |
| **`M0` prompts on Marlin** | Marlin compiles `M0`/`M1` only under `HAS_RESUME_CONTINUE` — an LCD controller **or** `EMERGENCY_PARSER` (`M0_M1.cpp` is wrapped in that guard; `gcode.h` says *"Only if ULTRA_LCD is enabled"*). On a headless build with neither, every `M0 (MSG …)` this post emits would echo as unknown and **not pause**, including the probe-attach prompt on the default path. **Scope decision (2026-07-31): out of scope — no machine used with this post is headless, and `M0` is assumed to work.** Recorded because the failure would be silent and the fix (`M0` is unconditional in the post) is not local |

---

## 8. Method notes worth reusing

- **A guard written to fail open produces a byte-identical file whether it read the value correctly or
  read nothing at all.** HR-6 (A) alone was therefore *not* decisive. Making its diagnostic
  **unconditional** — rather than only on the rejection path — turned one ordinary post into proof the
  guard was wired up. Apply the same test to any future fail-open check before trusting a passing post.
- **Fusion posts with its own copy of the `.cps`, and a session that forgets to refresh it produces
  confident, worthless evidence.** Session 1 was posted twice. The first attempt used the copy in
  `%APPDATA%\Autodesk\Fusion 360 CAM\Posts\`, which was ~3 hours behind the working tree: it predated
  HR-11 and HR-17 entirely. Those six files looked *plausible* — correct comment syntax, correct
  origin writes, a clean tail — and **HR-11 (C) and (D) would have been recorded as PASS**, because
  both rows assert an *absence* (`no M84`, `no M2`) and a build that never emits those blocks
  satisfies them trivially. The same trap as the fail-open guard below, arriving by a different road.
  **Before trusting any posting session, confirm the build:** the cheapest check is a token the newest
  commit changed — here, the group-03 heading and the ` RPM` space, either of which dated a file in
  one grep. *(A version or commit marker in the header would make this self-evident and is worth
  adding; the header currently names only the post's filename.)*
- **Absence-based rows need a presence-based sibling posted from the same build.** HR-11 (A)/(B) are
  the model: `M2` present on RepRap, absent on Marlin. Neither alone can distinguish "the split
  works" from "the feature is missing".
- **Read the whole dialog state out of the file's own property dump before believing a row ran.**
  Session 1's six files all carry `A/B/D_MapRapids_* = false`, which is why HR-15 came back unrun
  rather than passed — the dump said so, and nothing else in the file would have.
- **Diff a variant against the nearest saved reference** instead of reading it in isolation. Cheaper,
  and it paid off repeatedly: it is what made HR-1's scope and HR-3's untouched automatic branch
  provable in one line each.
- **Run a harness against `HEAD` as well as the working tree.** A harness that only passes on the fixed
  file cannot tell you it would have caught anything. HR-14's showed **7 of 9 before, 9 of 9 after** —
  that contrast is the evidence, not the "after" alone. Same lesson as the fail-open trace, applied to
  harnesses. *(Mechanics — extracting functions from the `.cps` and `eval`ing them against stubbed
  kernel globals — are in `plan.md` → Workflow notes.)*
- **A defect that suppresses output makes its own containing behaviour unverifiable — switch to the
  branch that emits.** HW-2 (B) asks what happens to the spindle speed at a section boundary, and on
  the **manual** path the correct answer (same RPM, one prompt, `setSpindeSpeed()` short-circuits) and
  the defective one (different RPM, prompt swallowed — HR-12) produce **byte-identical output**. No
  amount of reading `Link.gcode` can separate them. The **automatic** branch emits `M3 S<speed>`
  unconditionally, so one property change turns an unanswerable question into a countable one. When a
  row will not resolve, check whether the thing you are testing is the same thing that would hide the
  answer.
- **When a code path cannot be reached, question the premise before blaming the CAM.** HW-1 cost three
  posted files to a diagnosis nobody had checked — "the toolpath is wrong" — when the call graph said
  the path was unreachable on this licence at all. `isSafeToRapid()` has **one** caller; two minutes in
  the source would have saved all three. **Before specifying a job to exercise a branch, find every
  caller of that branch and confirm one of them can fire under the conditions you are about to set up.**
- **A one-file scratch copy of the post is a legitimate harness, and cheaper than the job you cannot
  build.** `Personal.cps` (repo root, excluded via `.git/info/exclude`, never committed) is the real
  post with `onRapid()` rerouted into `onLinear()` — four marked edits — so the real function sees real
  Fusion geometry and real dialog values. It closed HW-1 and HR-4 (C2) in two posts after three
  ordinary files had failed. Rules that keep it honest: **banner it** as not-a-post, **change
  `description`** so it cannot be picked by accident in Fusion, **re-create it** from the current
  `.cps` rather than maintaining it, and **never verify a row against its output** that is really a
  claim about what the post emits — its evidence is about *logic*, and the register's Method column
  says so.
- **When a question is "does the controller honour this?", read the controller's source, not a
  posted file.** HR-11's `M2` was written off as unanswerable without Marlin and Duet hardware, and it
  was answered in one sitting from `gcode.h` / `gcode.cpp` / `GCodes2.cpp` plus the RRF changelog —
  with a sharper result than a dry-run would have given, because it also dated the RRF support
  (3.5.1) and turned up the `stop.g` interaction. Firmware sources are public and searchable; check
  them **before** filing a row as needing a machine. The same read settled Marlin's `M0` guard (§7).
- **Every one of the nine fixes deviated from its proposed diff**, always in the same direction: the
  proposal understated the number of call sites (HR-4's "two" was four; its "five" assignments were
  eight). Count the call sites in the code before believing a diff is complete.
