# HReview — hobbyist-perspective review of `MPCNC_v4.0_Beta2.cps`

The review of the post from the hobbyist's chair, and the verification record for what it changed.
**Reviewed:** the whole post against the README's documented hobbyist use cases, every Fusion entry
point, and every property branch a hobbyist can reach. **Findings:** 17 (`HR-1`…`HR-17`); nine fixed
on branch `v4.0-hreview-fixes`; six reclassified as professional and moved to `docs/PReview.md`.

**There is no hobbyist code work left on this branch.** What remains is posting — see
[§3 Status](#3-status).

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
> `docs/PReview.md`. HP-5 as redefined still matters: it is the only hobbyist persona with a
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

Nine fixes landed, one commit each, subject-prefixed so `git log --oneline --grep='^HR-'` lists the
series. Each commit message carries the full reasoning; the code carries the *why* at every call
site. **Read the code and the commit, not a restated diff** — that is why the diffs and as-built
notes that used to live in this file are gone.

| | Fix | Commit | Blast radius | State |
|---|---|---|---|---|
| **HR-5** | `Scale Feedrate` reaches G2/G3 arcs | `b95c954` | Only when scaling is on (defaults off) | ✅ **closed** |
| **HR-6** | Rejects a 3-axis section oriented off machine Z | `684f28a` `e2b2424` | None if correct — blocks everything if wrong | ✅ **closed**, guard confirmed live |
| **HR-1** | Provisional `Z0` bounds the `G38 Target` on the two just-positioned probe modes | `8d61790` | **Default path.** Breaks the old byte anchor | scope proven; firmware half owed |
| **HR-3** | Manual spindle prompts to switch OFF on GRBL too | `43d09aa` | **Every GRBL job's tail** | (A)(B) pass; (D) owed |
| **HR-2** | `isProbeOperation()` defined locally so canned cycles can post at all | `9c87fb0` | Drilling path only | harness only — **unposted** |
| **HR-4** | Safe-Z literal fallbacks convert mm→output unit | `439ce2d` | **Inch jobs only** — identity in mm | harness only — **unposted** |
| **HR-11** | Marlin/RRF program end (`M2`) + `M84 S60` timeout restore | `7a35f7f` | **Every Marlin/RRF job's tail.** GRBL untouched | **unposted**, and `M2` support unconfirmed |
| **HR-14** | `coolantLevels` derived from `eCoolant` so both compound modes match | `7e38777` | Coolant-channel jobs only; defaults `Off` | harness before/after — **unposted** |
| **HR-15** | `safeZforSection()` asks the passed section | `88c7817` | None — latent trap closed, no output change | **unposted** |

Open with no code change: **HR-16** (recorded, no fix proposed), **HR-17** (tidy-ups). Moved to
`docs/PReview.md`: **HR-7**, **HR-8**, **HR-9**, **HR-10**, **HR-12**, **HR-13**.

### Verification owed — three posting sessions clear all of it

Eight posts of one GRBL/mm job cleared two fixes outright, but they were dialog variants of a single
CAM job; everything below needs **new CAM, a different firmware, or a different unit**. Ranked by
value:

1. **Marlin + RRF — do this first.** Clears **HR-11 (A)(B)** (the tail on both firmwares), **HR-1's
   firmware half**, **HR-3 (D)**, HR-5's linearization note, and re-baselines the stale
   `H6 - Marlin.gcode` / `H6 - RRF.gcode`. One firmware switch on an existing job, five-plus rows.
   ⚠ **HR-11 carries the only open correctness question on the branch, and it cannot be settled by
   reading the file** — see HR-11 below.
2. **GRBL / mm, new CAM: a drill + tap job.** Clears **HR-2 (A)(A2)** and is the first file ever able
   to evidence **HR-17**'s parenthesis stripping. **HR-14** rides along on any GRBL job (set the tool
   coolant to *Flood and Mist* and Channel A Mode to match).
3. **GRBL / inch.** Clears **HR-4 (A)(C)(D)**. There is still **no inch reference file anywhere**, so
   this is a first in its own right.

**HR-15 needs no session of its own** — fold it into whichever GRBL session runs first.

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

*Verified — all four halves, from the Mounting Plate face-mill job on GRBL:* `HR5b.gcode` (scaling
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
> whoever reads it next. *Remaining, optional:* the Marlin/RRF note that non-XY arcs linearize and are
> then limited the ordinary way — confirm once during session 1.

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

*Verified:* `H2.gcode` posts complete with no `Tool orientation` message — nothing is blocked, which
was the regression that mattered. `H2 - Debug.gcode` line 359 reads
`( onSection orientation: forward X0 Y0 Z1, tilt from machine Z 0 deg -> upright, section allowed)`.
Making that trace **unconditional rather than rejection-only** is what made one ordinary post decisive
(see §8). The other two trace shapes are `-> OFF-AXIS, section REJECTED` and
`-> UNREADABLE, check skipped, section allowed`; **seeing UNREADABLE on a normal Setup would mean the
guard is a no-op.**

> **Remaining, benign and optional:** the rejection half. Duplicate the hobby Setup with its Z along
> the model's X and post — expect the error naming the fix, and a **truncated `.gcode` on disk**
> (this guard fires in `onSection()`, after the header is written, unlike Guards A/B/C which write
> nothing at all). Nothing here evidences what Fusion reports for a *re-oriented* Setup — it could in
> principle re-express the frame rather than tilt `forward` — so a failure means a missed rejection,
> not a blocked job. **Follow-up worth doing separately:** promote both geometry guards into
> `validateJob()` so neither can leave a partial file. Not done here because it changes the
> long-standing multi-axis guard's behaviour too, which deserves its own decision.

### 4.2 Landed — verification owed

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

**Do (firmware half) — owed.** Repeat (A) on Marlin → `G92 X0 Y0 Z0`; on RRF → `G54` +
`G10 L20 P1 X0 Y0 Z0` with `M291 … S3` prompts. **Pass:** the `Z0` word is present on the pre-probe
origin write on both. Supersedes the saved `H6 - Marlin.gcode` / `H6 - RRF.gcode`.
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

**Unit-checked at the JS level** — the helper run against stubbed
`hasParameter`/`getParameter`/`cycleType`: strategy `probe` → true; `probing-x` /
`probing-xy-outer-corner` / `probing-z` → true; `drilling` / `tapping` / `boring` → false; no strategy
parameter → false; `cycleType` absent → false. Eight cases, all passing.

**Do (A) — a plain drill.** GRBL, hobby defaults, one **Drill** operation (several holes, any depth).
**Get (A):** each hole expands into ordinary moves — no `G81`/`G82`/`G83` anywhere:
```
( MOVEMENT_RAPID)
G0 X<hole> Y<hole> F<travelXY>
( MOVEMENT_PLUNGE)
G1 Z<depth> F<plunge>
( MOVEMENT_RAPID)
G0 Z<retract> F<travelZ>
```
and the file runs through to `( *** STOP end ***)`. **Pass — the discriminator is that a file exists
and reaches STOP end.** An abort with no `.gcode` written is the failure. *No existing row exercises
`onCyclePoint` at all — every other row is contour/pocket/face milling, so until this posts, drilling
is untested.*

**Do (A2) — a tap, same post if convenient.** Add a **Tapping** operation. **Get (A2):** the cycle
expands the same way and each affected move carries
`( >>> WARNING: Speed-feed synchronization  rigid tapping  is not supported; a floating/tension tap holder is required)`.
**Pass:** the warning is present on every activate/deactivate occurrence without corrupting the
surrounding g-code. Note the **double spaces** where `(rigid tapping)` was — that is HR-17's
parenthesis-stripping defect, and this is the first file able to evidence it. Do not "fix" the
expectation.

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

`spindleOn()` honoured the manual setting on every firmware — it prompts `M0 (MSG Turn ON 18000RPM)`.
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

**Do (D) — firmware regression, owed.** Repeat (A) on Marlin and RRF. **Get (D):** unchanged from the
saved `H6` behaviour — `M300 S300 P3000` beep then the turn-off prompt (`M0 …` on Marlin, `M291 … S3`
on RRF). **Pass:** the Marlin/RRF path is byte-identical to before; only GRBL moved.

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

**Harness-verified across both units** before landing: `Retract:15` with an absolute level → `5` /
`0.2` (level passes through untouched); relative level → `15` / `0.5906`; absent → `15` / `0.5906`;
bare `20` → `20` / `0.7874`; malformed `Retract:` → `15` / `0.5906`.

**Do (A) — inch job, bare-number probe Safe Z.** An **inch** Setup, one milling op with a probe,
group-06 `Safe Z` = `20`. **Get (A):** `(   Retract the tool to 0.7874015748031497)` →
`G0 Z0.7874 F<travelZ>`, and Resolved Values reads `Probe SafeZ = Const = 0.7874`. **Pass:**
`Z0.7874`, **not** `Z20`. *(The unformatted number in the comment is pre-existing — `probeTool()`
prints `retractZ` raw rather than through `zFormat`. Cosmetic; don't chase it here.)*

**Do (B) — mm regression.** Same job in **mm**, `Safe Z` = `20`. **Get (B):** `G0 Z20` and
`Probe SafeZ = Const = 20.000`, exactly as before. **Pass:** byte-identical to a pre-fix post. This is
the row that proves no existing mm PASS row is invalidated.

**Do (C) — the mapper, inch job.** Inch Setup, all four `03 - Map G1s to Rapids` on,
`Map: Safe Z to Rapid` = `20`. **Get (C):** the per-section comment reads
`( SafeZ using const: 0.7874015748031497)` — it was `( SafeZ using const: 20)` — and at least one
`( Safe G1 --> G0)` conversion appears where a pre-fix post of the same job had none. **Pass:** both.
*(That comment is `Important` level, so it survives at Comment Level `Important`.)*

**Do (D) — header coherence.** Any inch job with `Retract:15` on both Safe-Z properties. **Get (D):**
`Map SafeZ = Retract level, fallback 0.5906, resolves to <n>` — fallback and resolved value in the
**same** unit. **Pass:** no line mixes mm and inch.

---

#### HR-11 — Marlin / RepRap jobs never ended, and left every stepper energised — **Medium**

**Reached by:** HP-4, on every job.

Two halves in the same place. **No program end:** `onClose()` emitted `M30` on GRBL and, for
everything else, only `M117 Job end` — no `M2` or `M30` at all. **Steppers stayed on:** `Start()`
emits `M84 S0` on Marlin/RRF to *disable* the idle timeout deliberately, so the machine cannot lose
position mid-job, and nothing ever restored it — so after the job the machine sat with all axes
energised indefinitely, motors and drivers heating, for a job that had finished. The GRBL path has
neither problem, which is why this reads as a gap in the Marlin branch rather than a design choice.

**As built:** `M84 S60` then `M2` in the non-GRBL branch. `S60` rather than a bare `M84` because a
bare one releases the motors the instant it runs and an unbalanced LowRider gantry with no brake sinks
in Z; a 60-second timeout holds the axes while the operator retrieves the part, then releases without
anyone remembering to. **The `Stop File` branch is deliberately untouched** — `onClose()` bypasses the
whole stop block when `B_Include_StopFile` is set, and `M30` was already inside the bypassed region, so
a custom stop file owns the entire stop sequence, program end included.

> ### ⚠ `M2` support is unconfirmed — the only open correctness question on the branch
> This post confines `M30` to GRBL **because Marlin reads `M30` as "delete SD file"**, so it is
> already established that this firmware family's M-code semantics diverge, and `M2` may be
> unrecognised too. That also means the existing absence of a program end may have been an informed
> choice rather than the oversight this finding assumed. It is emitted anyway because the cost of
> being wrong is bounded: motion is flushed and the spindle is off before this point, so an
> unsupported `M2` produces an unknown-command echo and nothing else.
>
> **This is the first fix on the branch that cannot be settled by reading the file** — the block
> appears whether or not the firmware honours it. **Watch the sender's console:**
> `echo:Unknown command: "M2"` (Marlin) or an RRF error means the "no program end" half is still
> open. If unsupported, drop `M2` and record that end-of-file *is* the program end on Marlin/RRF; the
> `M84 S60` half stands either way.

**Do (A) — Marlin.** HP-4, one op, `CNC Firmware = Marlin`. **Get (A):** the file's last three blocks
are `M117 Job end`, `M84 S60`, `M2`. **Pass:** an explicit program end is present *and* the `S` value
is `60`, not `0` — an `M84 S0` at the tail would re-disable the timeout and be worse than emitting
nothing. Plus the console check above.

**Do (B) — RepRap/Duet.** Same job, `CNC Firmware = RepRap`. **Get (B):** identical tail; RRF's
`M84 S<seconds>` is the same idle-timeout form.

**Do (C) — the GRBL regression.** Re-post the default hobby job unchanged. **Get (C):** still ends
`M30` then `%`, with **no `M84` and no `M2` anywhere**. **Pass:** the GRBL tail is byte-identical to
`H2.gcode` apart from the timestamp. The fix is inside the non-GRBL branch; this proves it stayed
there.

**Do (D) — the stop-file bypass.** Set `08 - External Include Files` → `Stop File` to any file and
post on Marlin. **Get (D):** the included file's contents and **no `M84 S60`/`M2`**. **Pass:** the new
blocks are absent — the same treatment `M30` already gets.

> **⚠ `H6 - Marlin.gcode` and `H6 - RRF.gcode` end `M117 Job end` with nothing after**, so both are
> stale at the tail (and at the origin write, from HR-1). Their assertions stand; the files no longer
> match. Session 1 re-baselines them.

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

**Harness-verified before *and* after**, which is what makes it more than a plausible fix: every
index `0`–`8` compared against the id the channel-mode property stores for the same coolant —
**7 of 9 matching before, 9 of 9 after**. Also checked that `coolantLevels.indexOf()` finds every
entry (so the warning names the mode rather than printing `unknown`) and that an out-of-range
`tool.coolant` still falls back to `Off`. No saved reference file is affected: coolant defaults to
`Off`, indices 0–6 are unchanged, and the two changed modes could not previously match on any file.

**Do (A).** Tool coolant = **Flood and Mist**; `10 - Coolant` → Channel A Mode = **Flood and Mist**,
Channel A On = `M8`, Off = `M9`. **Get (A):** `( >>> Coolant Channel A: Flood and Mist)` and `M8` at
the operation, `M9` at the end. **Pass:** **no** `No matching Coolant channel` warning anywhere.

**Do (B) — the warning still fires, and now names what the operator saw.** Same tool coolant, Channel
A Mode back to **Off**. **Get (B):**
`( >>> WARNING: No matching Coolant channel : Flood and Mist requested)`. **Pass:** it reads
`Flood and Mist`, **not** `FloodMist` and not `unknown`. This is the row that proves the fix reached
the diagnostic and not only the comparison.

**Do (C) — the ordinary mode is untouched.** Tool coolant **Flood**, Channel A Mode **Flood**.
**Get (C):** `( >>> Coolant Channel A: Flood)` and `M8`, unchanged. **Pass:** indices 0–6 behave
exactly as they always did.

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

**Do (A).** Re-post the default hobby job unchanged (GRBL / mm) with `Restore Rapids` **on** so
`safeZforSection()` actually runs, and diff against `H2.gcode` (2026-07-31, the freshest GRBL/mm
reference). **Get (A):** the only difference is the timestamp line. **Pass:** no `SafeZ …` comment
changes its wording or number, and no motion differs.

**Do (B) — the branch that would expose a wrong-section read.** Post any job whose Safe-Z property
names an F360 level (`Retract:15`) at Comment Level `Info`. **Get (B):** ` SafeZ retract level: <n>` —
the *resolved* level, **not** ` SafeZ: retract level not defined`. **Pass:** the level branch is
taken. *(A) alone is insufficient: a fix that broke all three guards to `false` would also post
byte-identically on a `Const:` job, which consults no level at all — the same fail-open lesson HR-6
taught.*

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

**HR-17 — tidy-ups, no behavioural effect.** Cheap; do them as one sweep. The tapping-warning instance
needs the drill+tap post to *evidence*, but not to fix.

| Item | Where | Note |
|---|---|---|
| `sanitizeMessageText` strips parentheses, leaving double spaces | the tapping warning; the group name `"03 - Map G1s to Rapids (disable when using full license)"` | The group name reaches the file through `writeAllProperties()`'s `Properties -- <group>:` heading. Fixing the group name alters a visible dialog label — decide, don't assume |
| `linearMovements(x, y, z, feed, true)` passes 5 args to a 4-parameter function | `onLinear`'s converted-rapid path | Vestigial `true`; harmless, misleading to a reader |
| `"Turn ON " + …format(rpm) + "RPM"` → `Turn ON 18000RPM` | `spindleOn()` | Missing space |
| `flushMotions()` has an empty `if (fw == eFirmware.GRBL) {}` block | `flushMotions()` | Intentional (GRBL has no `M400`); an early `return` with the reason in a comment reads better |

---

## 5. Origin-mode coverage

The six `First WCS / Part` modes on a single milling operation, GRBL, real tool (≠ 0, not a jet). A
single-op job has no WCS change, so this is the only origin control exercised. These rows predate the
review and are kept as the coverage record; the HR rows above carry the current tokens where a fix
moved them.

| Row | Mode | Result |
|---|---|---|
| **H1** | `Jog to X0 Y0, Probe Z0` — jog prompt, XY zeroed at the jogged position, Z probed into `P1` | PASS (`H1.gcode`) ⚠ tokens now per **HR-1** (B) |
| **H2** | `Set X0 Y0 to Current Pos, Probe Z0` (**default**) — no jog prompt, XY zeroed at the parked position | PASS (`H2.gcode`, re-posted 2026-07-31 — current) ⚠ tokens now per **HR-1** (A) |
| **H3** | `Jog to X0 Y0 Z0` — jog all three axes, `G10 L20 P1 X0 Y0 Z0`, **no `G38.2`** | PASS (`H3.gcode`) |
| **H4** | `Set X0 Y0 Z0 to Current Pos` — fully manual, no prompt, no probe | PASS (`H4.gcode`); jet/tool-0 half → **J1** |
| **H5** | `Use Active WCS X0 Y0 Z0` — trust the stored origin: `G0 Z<probeSafeZ>` then `G0 X0 Y0`, no origin write, no probe | PASS (`H5.gcode`) |
| **H6** | Firmware variant of H1 on **Marlin** and **RRF** — comments switch to `; …`, Marlin emits `G92`, RRF emits `G54` + `G10 L20 P1 …` with `M291 … S3` dialogs; no spurious multi-WCS warning on a single-op Marlin job | PASS both (`H6 - Marlin.gcode`, `H6 - RRF.gcode`) ⚠ **both files stale twice over** — HR-1 (origin write) and HR-11 (tail). Assertions stand; session 1 re-baselines |
| **H7** | `Use Active WCS X0 Y0, Probe Z0` — stored XY, re-probe Z. Discriminator is the **absence** of `G10 L20 P1 X0 Y0` | PASS (`H7.gcode`); `H7a` nonzero-offset PASS; `H7b` → **J1**; `H7e` firmware → `PReview.md` |

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

## 6. Other hobbyist work owed before a public release

- [ ] **HR-17 sweep** — four cosmetic items, one commit, no decisions.
- [ ] **`isSafeToRapid()`'s true branches have never been exercised.** The prior full-licence run
      (`2D Contour1.gcode`) stayed at Z ≤ 1 mm, below the 5 mm safe height, so every call returned
      `false` and only the conservative refusal ran — the `zConstant` / `zUp` /
      `zDown-with-curZSafe` conversion branches are **untested**. Generate a toolpath with a
      horizontal link move at or above safe Z (e.g. multiple contours linking at retract height).
      This is the group the README tells the hobbyist to enable, so it matters for HP-1.
      *(Ties to `plan.md` → Phase 5 — G0/G1 rapid-mapping review.)*
- [ ] **An HP-5 row: two operations, one tool, one WCS, no base.** Every PASS row above is a
      **single-section** job, so every section-boundary behaviour — the
      `forceSectionToStartWithRapid` lifecycle, position tracking across injected motion, spindle-speed
      changes, WCS re-selection suppression — is unverified for this persona. The professional rows
      would cover some of it but change the WCS at the same boundary, which confounds the variables. A
      plain two-op single-WCS post isolates them and is cheap.
- [ ] **`Probe Pause` — the `No` and `Before` branches have never been posted.** Only the default
      `Before & After` (both prompts) is verified, on every H row above. *Do:* the default hobby job
      with `Probe Pause = No`, then `= Before`. *Get:* `No` → the `G38.2` block with **neither**
      `Attach ZProbe` nor `Detach ZProbe` prompt; `Before` → attach only, no detach. **Pass:** the
      prompt count changes and **nothing else does** — same origin write, same probe, same retract, so
      diff each against `H2.gcode` and expect only the `M0` lines to differ. *(Cheap; folds into any
      GRBL session.)*
- [ ] **Full regression pass.** Re-run the sample jobs and confirm no output differences beyond the
      intended Beta-2 changes — in particular that single-WCS, no-base jobs are byte-for-byte
      unaffected (comment lines stripped, or diffed against a current-post reference).
- [ ] **Dialog audit** — **D1** (labels/defaults) and **D3**'s dialog half (does a saved preset
      survive the group reorder?) are release-relevant but cover all eleven groups, so they live in
      `PReview.md` §3.3. Neither needs a post; both need the dialog.

**Confidence statement.** For HP-1 through HP-5 the *structure* of the emitted file is established by
reading: preamble ordering, WCS selection before any origin write, units and absolute mode before any
probe, comment syntax per firmware, arc and cycle handling, guard placement, and the origin/probe
dispatch for all six First WCS / Part modes. What reading could not establish — HR-2's kernel
dependency and HR-6's `workPlane` behaviour — HR-6 has since settled by posting; HR-2's drilling half
is session 2. **To claim "high confidence that the post outputs correctly formatted, structurally
sound g-code for a hobbyist from every F360 entry point"**, the three posting sessions in §3 plus the
HP-5 row above are what stand between here and that claim.

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

---

## 8. Method notes worth reusing

- **A guard written to fail open produces a byte-identical file whether it read the value correctly or
  read nothing at all.** HR-6 (A) alone was therefore *not* decisive. Making its diagnostic
  **unconditional** — rather than only on the rejection path — turned one ordinary post into proof the
  guard was wired up. Apply the same test to any future fail-open check before trusting a passing post.
- **Diff a variant against the nearest saved reference** instead of reading it in isolation. Cheaper,
  and it paid off repeatedly: it is what made HR-1's scope and HR-3's untouched automatic branch
  provable in one line each.
- **Run a harness against `HEAD` as well as the working tree.** A harness that only passes on the fixed
  file cannot tell you it would have caught anything. HR-14's showed **7 of 9 before, 9 of 9 after** —
  that contrast is the evidence, not the "after" alone. Same lesson as the fail-open trace, applied to
  harnesses. *(Mechanics — extracting functions from the `.cps` and `eval`ing them against stubbed
  kernel globals — are in `plan.md` → Workflow notes.)*
- **Every one of the nine fixes deviated from its proposed diff**, always in the same direction: the
  proposal understated the number of call sites (HR-4's "two" was four; its "five" assignments were
  eight). Count the call sites in the code before believing a diff is complete.
