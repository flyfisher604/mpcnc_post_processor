# Findings — `MPCNC_v4.0_Beta2.cps`

Every logged issue and the tests that confirm it. **71 findings — 51 fixed ·
4 closed by design · 1 withdrawn · 15 open.** Test registers in §4 and §5.

> **`HR-22` has no row in any register but this one.** It was carried in checkpoint prose and
> in `conventions.md`, as `HR-19`, `HR-24` and `HR-27` were until they closed.

> **Thirteen tool-change findings and nine tool-change test rows were deleted 2026-08-13**,
> with the design that made them defects. `design.md` → *Tool changes* is the replacement
> design; `PR-15` carried them until the rebuild landed, and the **`TC-` rows in §4 are the
> register they left owing**. Recover any deleted row with `git log -p -- docs/findings.md`.

## 1. Scope & id key

Four review passes filed into this one register. The prefixes are kept as origin markers
because commit messages cite them and must still resolve.

| Prefix | Pass | Range |
|---|---|---|
| `HB-` | Hobbyist dialog walk, 2026-08-08 — one part, one WCS, one tool, GRBL/Marlin/RepRap | `HB-1` … `HB-20` |
| `PR-` | Professional / machine-frame review | `PR-1` … `PR-16` |
| `HR-` | Found by the hobbyist pass, reclassified as professional — Manual NC, tapping | two ids |
| `CR-` | Pre-Beta coverage review, 2026-08-09 | `CR-01` … `CR-24` |
| `FCR-` | 2026-08-01 whole-file review. **All findings closed**; three unrun test rows survive, renamed here | `FCR-4` … `FCR-13` |

> **The `CR-` prefix once meant two things.** The 2026-08-01 whole-file review filed
> `CR-1 … CR-17`, dissolved into the hobbyist register at `c73726c` / `a68dd11` / `1232929`
> and all closed. Its numbers collide with the coverage review's. Its four surviving **test
> rows** are renamed `FCR-` here — do not use zero-padding as the discriminator. Commit
> messages and code comments dated before `c73726c` that say `CR-n` mean the older series.

> **Nine `HR-` ids resolve to git only, and this predates the consolidation.** `HR-1`,
> `HR-2`, `HR-4`, `HR-5`, `HR-11`, `HR-14`, `HR-15`, `HR-17` and `HR-23` lead commit
> subjects but had already been dissolved out of the hobbyist register before this file was
> built — verified against `HReview.md` at its last commit, which held none of them. They
> are the 2026-07-31 pass, all fixed; recover any of them with `git log --grep=HR-<n>`.
> Rows are **not** reconstructed here: the fixes are landed and the argument is in the
> commits. Recorded so the gap is not re-discovered as a loss.

**Professional** is multi-WCS, the machine Z frame, tool changes, Manual NC and the dialog
audit. **Hobbyist** is a Personal-licence user, one part, one WCS, one tool, several
operations. The distinction no longer routes a finding to a different file; it survives
only as scope on the `HB-` and `PR-` passes.

**No controller is available**, so every firmware claim is settled from firmware source and
no row is proved by running one.

---

## 2. Open findings

**15 open, one of them deferred.**

### PR-25 — whether RepRapFirmware applies a tool-length offset to a `G53` move is unsettled — Low-Med

**Problem.** Every machine-frame block the post emits is `G53 G0 Z<Machine Travel Z>`, and the
height it names is a **carriage** position only if RRF drops the tool offset for that line. If RRF
keeps applying it, the height is a **tool-tip** position and the carriage goes to
`Machine Travel Z` minus the tool length — which for a long tool is above the axis limit, so the
retract errors instead of retracting. **`Tool Change Handled By` = RepRapFirmware tool table is the
first setting that makes this reachable**: before it the post told RRF nothing about tools, so the
active offset was whatever `config.g` left and was normally zero. Now `tpost<n>.g` sets a real one,
at every change, mid-file.

**Reproduce.** Read RRF's own source — `src/GCodes/GCodes.cpp`, the `G53` / machine-coordinates
handling — and the GCode dictionary entry for `G53`. **A source read, not a controller test.**

**Fix.** None yet, and possibly none needed. The post-time warning already shipped is worded to
hold under **either** answer: it tells the operator to leave headroom for the longest tool. Settle
the source question first; only if offsets are applied does the post owe anything more, and the
candidate is subtracting nothing and saying so rather than computing a length it cannot know.

### PR-23 — a boundary that is both a WCS change and a tool change probes the part twice — Low-Med

**Problem.** `onSection()` now calls `writeWCS()` before `toolChange()`, which is what puts the
post-change probe in the right register. But `writeWCS()` does two things in one call: it
selects the new offset **and** runs `probeOnChange`'s origin work. So on the default
`Use Active WCS X0 Y0, Probe Z0` the new part is probed with the **outgoing** tool, and the
tool-change re-probe immediately overwrites that Z0 with the incoming one. The register ends
correct and the second result is the one that cuts — this is waste and operator friction, not
a wrong part: two probe cycles, and four attach/detach prompts where two would do.

**Reproduce.** Two parts and two tools, arranged so one section boundary changes both — GRBL,
`Machine Travel Z` filled, `At a Tool Change` = `Pause for a manual change`,
`Subsequent WCS / Part` at its default.

**Fix.** Split `writeWCS()` into a select and an origin-establish, so `onSection()` can order
select → change → establish and the part is probed once, with the tool that cuts it. That is
the ordering `design.md` describes and the one-call shape is what prevents it.
**Not urgent, and deliberately not taken with the rebuild** — the correctness half landed
there, and the split touches code the multi-WCS work has only just settled.

### PR-13 — group 11's Duet mode strings are RRF 2.x g-code — Low-Med

**Problem.** `duetMillingMode` = `M453 P2 I0 R30000 F200` and `duetLaserMode` =
`M452 P2 I0 R255 F200`, written verbatim by `onSection()`'s RepRap branch on every
section-type change. **RRF 3.x reads `M453` for `S` alone**, so `P2 I0 R30000 F200` sets no
pin, no maximum RPM and no PWM frequency — silently. `M452` keeps `R` and `F`/`Q` but drops
`P2 I0`, so the laser pin is never assigned. Both are valid on RRF 2.05, which is what they
were written for.

**Reproduce.** `CNC Firmware` = a RepRap/Duet answer, any milling job — the milling string
is written on every Duet post. Never yet posted.

**Fix.** Defaults that work on RRF 3, and a tooltip naming the version each form belongs to.
**The fields stay editable** — the post cannot know a board's pins or its RRF major version.
Take the relocation of both properties beside the firmware selector *with* the default
rewrite: both re-head the property dump, so together they cost one baseline instead of two.

### HR-22 — should `gAbsIncModal` / `gUnitModal` / `gFeedModeModal` be reset? — Low

**Problem.** They are formatted once in `Start()`, so a reset would emit nothing later.
Deliberately excluded from `HB-16`'s fix. `CR-21` answers this: the second file in a reused
context loses its whole preamble.

**Fix.** Settle with `CR-21`.

### CR-03 — group 3 is not gated to the licence it exists for, and nothing warns — Machine damage · deferred

**Problem.** `Map G1s -> G0 Rapids` is documented as a recovery for the Personal edition's
habit of emitting rapids as cuts. Nothing enforces it. With a Full licence the property is
still read on every `onLinear`, so genuine cutting moves are offered to `isSafeToRapid()`
and any whose destination Z is at or above the resolved Safe Z is re-emitted as `G0` at
travel speed — adding rapids Fusion deliberately did not make.

**Reproduce.** Fusion **Full** licence, `Map G1s -> G0 Rapids` on, any milling job.

**Fix.** **Deferred — the finding stands, the instrument is in doubt.** A licence latch read
from the first genuine `onRapid()` is designed and unapplied (`6304c28`, `45c612e`,
`95349d6`). Testing the header text Fusion writes for the hobby version would close the
one-move window the latch leaves open and need no latch at all. **The question that settles
it: does that banner reach the post, or does Fusion write it downstream?**

### CR-05 — a start include file leaves `G90`, `G21`/`G20`, `G94` and `G17` unwritten — Machine damage

**Problem.** `writeFirstSection()` calls `Start()` only when `includeStartFile` is empty, and
`Start()` is the only place that emits `G90`, `G20`/`G21` and (on GRBL) `G94` and `G17`.
Nothing re-asserts them later. Everything after assumes absolute positioning and the job's
units, so a start file that omits `G90` or sets the wrong unit silently misinterprets the
whole job — and unlike a missing file, there is no detectable failure at post time.

**Reproduce.** `Start GCode File` naming any file. Any firmware, any job.

**Fix.** A one-line `writeWarning()` at the replacement site, putting the precondition in
the file where the operator reads it.

### CR-09 — commanded spindle control emits `M3`/`M4`/`M5`, a build option on Marlin — Wrong output

**Problem.** On Marlin those codes exist only under `SPINDLE_FEATURE` or `LASER_FEATURE` in
`Configuration_adv.h`, and both ship disabled. On a stock Marlin CNC build they reach
`unknown_command_warning()` — Marlin warns and continues, so the job runs to completion with
the spindle never commanded on.

**Reproduce.** `CNC Firmware` = Marlin, `Manual Spindle On/Off` **off**.

**Fix.** Say so in the property description, beside the same class of fact the post already
documents for `G38.2`, `G53` and `G17`.

### CR-10 — parking at machine `X0 Y0` drives back onto the homing switches — Wrong output

**Problem.** `writeMachineParkXY()` emits `G53 G0 X0 Y0 F<travel>` as the job's last motion.
On a stock GRBL build `HOMING_FORCE_SET_ORIGIN` is disabled, so machine zero sits **at the
switch trigger point** and the machine rests `$27` away after `$H`. The park drives X and Y
back into the switches — with `$21=1` that is a hard-limit alarm and the program ends in
`Alarm` rather than parked. The Marlin route re-homes rather than rapids and is unaffected.

**Reproduce.** GRBL or RepRap, X/Y declared homed, `Home at Job Start` ≠ Off,
`At End Park At` = `Machine X0 Y0`.

**Fix.** Park at the pull-off distance or a small documented inset.

### CR-15 — the shipped default `First WCS / Part` is incompatible with a filled `Machine Travel Z` — Wrong part

**Problem.** Establishing the fixed Z reference is step 5 of `writeFirstSection()` and it
*moves the tool*; `writeWcsOnStart()` is step 6, and the two `Set … to Current Pos` modes
record wherever the tool now is. So the first part's origin is recorded at bed clearance and
the `G38.2` that follows never reaches the stock. `validateJob()` warns — but on the
**default** value, for every job that has a frame at all.

**Reproduce.** `First WCS / Part` left at its default `Set X0 Y0 to Current Pos, Probe Z0`,
with `Machine Travel Z` filled and `Axes Homed and Trusted` including Z — at every other
default. **A multi-part job cannot avoid it**, Guard B requiring the frame; a single-part job
reaches it the moment the field is filled, which is a route that did not exist before.

**Fix.** A defaults problem rather than a logic one — fix it in the defaults, or in
`Machine Travel Z`'s description. `PR-10` is the warning half of the same ground.

### CR-16 — one part machined from several WCS is accepted and traverses to an unset register — Machine damage

**Problem.** Both origin controls say in their descriptions that one part from multiple
datums must be run as separate jobs. Nothing checks it, and the post cannot tell that shape
from two fixtures. So the job posts, and the first traverse rapids to the *stored* `X0 Y0`
of a register the operator never set, or probes there. `validateJob()`'s stored-offset
warning fires only when X/Y is **not** declared homed — so declaring endstops removes the
only signal.

**Reproduce.** A single physical part whose operations are assigned to different work
offsets. GRBL or RepRap, X/Y declared homed.

### CR-17 — a revisited WCS is re-probed on a surface the job has already cut — Wrong part

**Problem.** `writeWCS()` suppresses only a *repeat* of the currently active offset, so a
return to an earlier one takes the full `probeOnChange` dispatch — a second `G38.2` into a
register that already holds a good Z0. After the roughing pass the touch point may be a
machined pocket floor, a cut-away region, or air, so the re-probe overwrites the correct Z0
and every finishing cut is displaced by the roughing depth.

**Reproduce.** A job that returns to a work offset it has already used — rough every part,
then finish every part: G54 → G55 → G54 — with `Subsequent WCS / Part` = `Use Active WCS
X0 Y0, Probe Z0` (the default).

**Fix.** `currentWorkOffset` history is exactly the information needed: a WCS this job has
already probed does not need probing again.

### CR-21 — `resetPostState()` does not reset the modal formatters — Machine damage

**Problem.** `gAbsIncModal`, `gUnitModal`, `gFeedModeModal` and the six coordinate variables
are left out. In the second file `Start()`'s `G90`, `G21`/`G20` and `G94` find the modal
already holding those values and emit **nothing** — so file two has no preamble, and every
absolute coordinate, `G53` move and probe target depends on the controller still being in
the mode file one left it in. **`gPlaneModal` was singled out for reset with a comment
explaining exactly this failure mode** — the tell that the other three were an oversight.

**Reproduce.** Two or more NC files posted from one Fusion invocation where the JavaScript
context is reused.

**Fix.** Reset all three formatters and the six coordinate variables. Answers `HR-22`.

### CR-22 — the four coolant "custom file" properties are not in the include pre-flight — Wrong output

**Problem.** `validateJob()`'s pre-flight checks the start, stop and two tool-change files
and refuses before any output when one is missing. The four `coolantChannel*Custom`
properties are read through the same `loadFile()` and are absent from the list, so they get
exactly the late failure the pre-flight exists to prevent — and the coolant-*off* files fail
at `onClose()`, after the whole job has been written.

**Reproduce.** Any `Turn Channel A/B On/Off` set to `Use custom`, naming a file not in the
NC output folder.

**Fix.** Add them under the condition that makes them reachable. `HB-7` deliberately scoped
them out.

### CR-23 — a Safe-Z expression of `0` is accepted, making every non-negative Z "safe air" — Machine damage

**Problem.** `parseSafeZExpr()`'s CONST regex `/^\d+\.?\d*$/` matches `0`, so
`isSafeToRapid()`'s `zr >= safeZHeight` is true for every Z at or above the stock top —
a cut at exactly Z0, a skim pass, the whole of a 2D engraving at zero depth — and those
moves are re-emitted as `G0` at travel speed. `validateJob()`'s Safe-Z warning fires only on
the ERROR arm, so `0` posts silently. **`0` is a plausible thing to type meaning "no
restriction", and it produces exactly that with the sign reversed.** Same for `probeSafeZ`.

**Reproduce.** `Map G1s -> G0 Rapids` on with `Safe Z to Rapid` = `0` (or `Feed:0`,
`Retract:0`, `Clearance:0` on an operation with no absolute level).

**Fix.** A lower bound on the accepted value, or a warning at zero. The parser already
rejects negatives.

### CR-24 — the default channel-B coolant code is behind a default-off GRBL build option — Wrong output

**Problem.** `M7` is compiled into GRBL 1.1 only when `ENABLE_M7` is uncommented in
`grbl/config.h`, and it ships commented out. On a stock build `M7` returns `error:20` and
halts the job mid-section with the tool in the cut. The property's title advertises it as
the GRBL code — true of the dialect, not of the default build. `M8`/`M9` are unconditional
and fine.

**Reproduce.** `CNC Firmware` = Grbl, `Channel B Mode` set to a coolant a tool requests,
`Turn Channel B On` at its default `Grbl: M7 (mist)`.

---

## 3. Closed findings

**51 fixed · 4 closed by design · 1 withdrawn — 56 rows.** Permanent: commit messages and
code comments cite these ids and they must still resolve. `git show <ref>` holds the
diagnosis, the diff and the argument.

| ID | Finding | Sev | Resolution | Status |
|---|---|---|---|---|
| **HB-1** | Marlin `M0` is conditionally compiled, so a build without a panel would skip every operator stop | — | Not a defect on the machines this post targets — every Marlin build in the audience has a panel | ➖ |
| **HB-2** | GRBL files wrapped in `%`, which stock Grbl 1.1 rejects | Med | `5a6a4e0` | ✅ |
| **HB-3** | `Home at Job Start` = `Home` with nothing declared homed homed nothing, and said so only in the file | Med | `ec5af37` | ✅ |
| **HB-4** | A non-zero `Probe X/Y Offset` traversed to the probe point at the operator's own jogged Z, with no lift and no warning | Med | `cb1c9f2` — retract before the traverse, gated on the offset | ✅ |
| **HB-5** | A malformed group-6 `Safe Z` fell back to 15 mm with only a `Debug` trace, where its group-3 twin warned | Low | `e5db625` — both properties fail the same way, in both channels | ✅ |
| **HB-6** | `G17` and `G94` are emitted only on the GRBL branch, so RepRap inherits whatever plane and feed mode the last job left | — | Closed by design — the fix was worse than the defect: neither code exists on Marlin, nor on RRF below 3.5.1, and `circular()` linearizes every non-XY arc off GRBL so the exposure is unreachable | ➖ |
| **HB-7** | A missing group-8 include file aborted the post *after* part of the file was written | Low | `b61c005` — pre-flight in `validateJob()`. Coolant custom files deliberately out of scope — `CR-22` | ✅ |
| **HB-8** | `Enforce Feedrate` and the word separator leaked into the next post in the same session | Low | `b84f602` | ✅ |
| **HB-9** | `Comment Level` = `Off` suppressed every `>>> WARNING:` the post writes | Low | `1c5fcce` — all thirteen sites go through `writeWarning()`, which bypasses the level gate | ✅ |
| **HB-11** | The two blank separator comments disagreed by one character | Low | `18ec9aa` | ✅ |
| **HB-12** | A job whose last arc was a Z lead-out left the plane at `G18`, and a group-8 Stop file's arcs then ran in ZX | Low | `ae0e013` — `G17` before `loadFile()` in `onClose()`, GRBL branch only | ✅ |
| **HB-13** | `Use Active WCS X0 Y0, Probe Z0` holds no Z reference, and neither creates one nor bounds what it does without one | Med | `556a378` — a warning in both channels. The proposed relative lift was rejected: it would be the only motion in no frame at all | ✅ |
| **HB-14** | The in-file `format error` warning ran the property title into its group with no separator | Low | `eea70d1` — one shared writer; the sanitizer eats parentheses, so quotes and `--` are used | ✅ |
| **HB-15** | The include-file refusal explained the post's own history to the operator | Low | `18ec9aa` | ✅ |
| **HB-16** | `gPlaneModal` outlived the file it was created for | Low | `ae0e013` + `eea70d1` — reset in `resetPostState()` and after an include. `gAbsIncModal`/`gUnitModal`/`gFeedModeModal` deliberately excluded — `HR-22`, `CR-21` | ✅ |
| **HB-17** | `fixedZEstablishedAtStart()` answered a question about the dialog and was read as one about the file, silencing HB-13's warning where it was needed most | Low | `556a378` — split into a dialog answer and `fixedZEstablishedInFile()`, which tests the firmware | ✅ |
| **HB-18** | HB-14's defect had a third call site the fix did not reach | Low | `2b5dfd5` — fixed as a pattern: the no-parentheses rule now lives at `writeWarning()` itself | ✅ |
| **HB-19** | HB-13's dialog warning closed by recommending `Fixed Z Reference` on Marlin, where neither answer can deliver it | Low | `2b5dfd5` — the closing sentence is conditional on Marlin | ✅ |
| **HB-20** | Group 3 asked three enabling questions to express one decision, and the three booleans were not peers | Low | `bf0c2bd` — one enabling control and one field. Costs exactly one configuration, named before the edit | ✅ |
| **PR-1** | Group 4 collected an **action** where every consumer needs a **capability** | Med-High | `2e51509` — declaration split from action. **Key replaced, so the old setting resets** | ✅ |
| **PR-2** | A reserved spoilboard base and a homed machine Z are two implementations of one frame, but only the first was exposed | Med-High | `2e51509` — `Fixed Z Reference` = `None`/`Spoilboard`/`Machine Z`; Guard B relaxed to *a* datum of either kind. Resolves the standing "Never `G53`" decision | ✅ |
| **PR-3** | `Probe to Set Base = None` stated a precondition it did not have | Med | `2e51509` — option eliminated; PR-2 gives its one durable use a better answer. **Removing an enum id resets the property** | ✅ |
| **PR-5** | The dialog asked two questions per concept — homing as two booleans, and two mutually exclusive clearance fields | Med | `9a7e360` — `Axes Homed and Trusted`, and one `Inter Part Travel Z` whose frame follows `Fixed Z Reference`. **Three keys replaced** | ✅ |
| **PR-6** | `At End Go to 0,0` never said **which** X0 Y0, and it is the last section's WCS | Med | `36109c2` — `Off`/`Work X0 Y0`/`Machine X0 Y0`, firmware-split. **boolean→enum resets the setting** | ✅ |
| **PR-7** | Group 4 still asked two questions about one homing decision, the second inert whenever the first was off | Med | `0df79d9` — one enum. Unlike PR-5 this **deletes the meaningless state**. **Both key changes reset** | ✅ |
| **PR-8** | PR-6's park asked *is a base reserved?* where it needed *was a fixed Z reference established?* — they differ on Marlin | Med-High | `1eb8141` — one predicate read by the emission and by a post-time warning, so the two cannot drift | ✅ |
| **PR-9** | PR-6's `G53 G0 X0 Y0` park block carried no `F` word, alone among the post's rapids | Med | `fFormat` at `Travel Speed XY`, matching `writeMachineTravelZ()` | ✅ |
| **PR-10** | PR-2 made the preamble move the tool, so the two `… to Current Pos` first-part modes record bed clearance as the origin | Med-High | Post-time `warning()`. **Not a code fix and cannot be one** — the distance from clearance to stock is what the probe exists to discover. `CR-15` is the defaults half | ✅ |
| **PR-11** | HR-28's GRBL jog warning tested `Subsequent WCS / Part` on single-WCS jobs, which never consult it | Low-Med | `multiWcs` applied to the subsequent-part half only | ✅ |
| **PR-12** | An F360 probing operation refused with Autodesk's generic cycle text, so the one dialog the operator sees said nothing actionable | Low | `f54beb0` — the post's own `error()`, naming the reason and the two things that do work. The refusal itself is correct: GRBL and Marlin cannot compute an offset | ✅ |
| **PR-14** | The multi-WCS refusal named its cure in prose, and the cure it recommended refused again for a field it never mentioned | Low-Med | `c0ceb86` — the first refusal is gone entirely: a homed machine's Z frame is now derived, so Guard B is reachable only on a machine declared as not homing. The second cannot be removed and now names `Inter Part Travel Z` and its group | ✅ |
| **CR-04** | The first-move conversion applies no test of any kind to the destination | — | **Withdrawn — not a defect.** Fusion Personal emits no rapids, so every section's opening callback is a would-be rapid and the conversion never reaches a cut. Under a full licence that is `CR-03`'s ground. Designed fix unapplied, in git | ➖ |
| **CR-11** | The spoilboard base is probed to a target measured in the frame the probe is establishing | Machine damage | `c319e69` — a provisional Z0 makes the target relative, and the base probe gets its own reach | ✅ |
| **CR-12** | Both `Use Active WCS …, Probe Z0` modes measure the probe target from the Z0 they distrust | Machine damage | `979297d` — `partProbe()` writes a provisional Z0, on a third path this finding does not name | ✅ |
| **CR-13** | With `Retract Across Parts` off, the inter-part traverse height is resolved in one frame and emitted in another | Machine damage | `fbd1591` — the control is removed and Guard B is unconditional, so the arm is unreachable | ✅ |
| **CR-14** | The base-establish tool-0 skip leaves the job believing a base was established | Machine damage | `348e35a` — the predicate now answers for the tool that must probe, plus a second guard | ✅ |
| **PR-16** | `Home at Job Start` moves the tool off the parked spot the spoilboard base probe depends on, unwarned | High | **Closed by deletion** — the base establish, its probe and its operator precondition were removed rather than repaired. No repair exists and none is owed | ✅ |
| **PR-17** | A `Machine Travel Z` at or above machine zero on GRBL is unreachable, or lands on the homing switch, unwarned | Med-High | A `>= 0` warning in both channels. **`>= 0` and not `> 0`**: homing ends one pull-off *below* the trigger, which fixes the trigger at machine Z `0`, and `system_check_travel_limits()` rejects only `> 0`. Names `HOMING_FORCE_SET_ORIGIN` and the pull-off, never a number — `$27` cannot be read | ✅ |
| **HR-26** | The base-clearance retract had no tool-0 / jet guard though the base establish did | Med | **Closed by deletion** — the transit went with the base. The machine-frame retract that replaced it emits `G53 G0 Z`, which establishes nothing and needs no tool, so the hole closed with the code | ✅ |
| **PR-18** | Two warnings recommend a "Jog to ..." mode in the same dialog that refuses it | Low | Closed with `PR-19` — the refusal became a condition, so the recommendations no longer contradict it. **Nothing was deleted**: the clauses that name a jog mode are the correct remedy and stand as written | ✅ |
| **PR-20** | Under gSender, the **first operator stop in the file is deleted rather than obeyed** whenever `Comment Level` is below `Info` | High | Post-time `warning()` naming the stops this job puts at risk. **Not a code fix and cannot be one** — `GrblController.js` (master, 2026-08-14) comments an `M0` out unconditionally but holds the stream only past `if (sent > 10)`, a Carbide workaround, and `Sender.js`'s `load()` filters blank lines only, so the threshold is a line count of the emitted file. **It is not a jog-mode defect, which is how it was first filed:** at `Off` the default job loses `Attach ZProbe` at line 7 and probes with no plate attached, and `Pause, then Home` loses its stop at **line 1** and homes into an uncleared bed. **Padding the preamble was rejected** — filler to satisfy another program's constant. `PR-10` is the precedent for closing on a warning | ✅ |
| **PR-15** | The tool-change code implemented neither flow of the tool-change design | High | Rebuilt as Flow 1 and nothing else: eight properties to three, `M6` / `M84 Z` / the WCS-relative `Tool Change X/Y/Z` / the Marlin beep / `tFormat` all deleted, and `includeProbeFile` with them. The hand-over retracts in the **machine frame** through `writeMachineTravelZ()`, stops coolant and spindle on the one route there now is, prompts, and re-probes through `partProbe()` into the **active** offset — `onSection()` selects the WCS first. A first tool load moved into `writeFirstSection()`, ahead of the origin work. Flow 2 followed as `PR-24` | ✅ |
| **PR-21** | On Marlin the machine end park is a homing cycle, and homing zeroes the work origin the file established | Med-High | A warning in both channels. `set_axis_is_at_home()` zeroes `position_shift` under `HAS_POSITION_SHIFT` and never touches `coordinate_system[]` (`src/module/motion.cpp`, 2.1.2.5) — so the register survives but an ordinary single-offset job never re-selects one, and the two-file answer to a tool change is exactly the job that resumes on it. **Warned, not refused**: a job with no successor is entitled to park at the homing corner | ✅ |
| **PR-22** | The tool-change spindle stop read the **incoming** tool's jet guard | High | `onCommand(COMMAND_STOP_SPINDLE)` guards on `!tool.isJetTool()`, and at the boundary `tool` is already the tool being fitted — so a change from a router into a laser skipped the stop and handed over a **turning cutter**. Replaced by `if (spindleEnabled) spindleOff()`, which answers for what is running rather than for what is about to be fitted | ✅ |
| **PR-24** | Flow 2 was unbuilt because the design left the macro token unsettled, and no firmware source can settle a sender's behaviour | High | **The token stopped being one question by becoming a property.** `Tool Change Handled By` names the handler and the post emits what that handler reads: `T<n> M6` for gSender and CNCjs, whose Grbl `dataFilter` removes the `M6` before the controller answers `error:20` (`src/server/controllers/Grbl/GrblController.js` — the same function `PR-19`/`PR-20` cite); `T<n>` alone for RepRapFirmware, where the T word **is** the change and runs `tfree`/`tpre`/`tpost`; and for `Other`, the operator's own file through `loadFile()` and no token at all. `At a Tool Change` gained a third value and the flows **share** the arrive-and-stop half — one retract, one coolant stop, one spindle stop, so no route can be given a hand-over the others do not get. The resume is `toolChangeMacroResume()`: `G90`, the unit code, `G94`/`G17` on GRBL only, an **unconditional** re-select of `currentWorkOffset`'s own `G5x`, and a return to `Machine Travel Z` before anything reads a coordinate. **Marlin is refused**, having no tool-length register for a macro to write; so are a handler and a firmware that do not match, and `Other` with no file. **The contract is stated where it can be read** — the dropdown's own description — because it is the operator's to satisfy and the post can verify none of it | ✅ |
| **PR-26** | A manual change happened directly above the cut, and the `Tool Change X/Y/Z` that once moved it had been deleted as unsound rather than replaced | Med | **The frame was the defect, not the feature.** The old fields were bare `G0` words read in whichever WCS was active, so a change position measured against one part's origin was somewhere else for the next; `Tool Change Position X`/`Y`/`Z` are **absolute machine coordinates** through the same `writeMachineFrameBlock()` as every other `G53` move, and mean the same thing on every part of every job. X/Y crosses **after** the retract to `Machine Travel Z` and in its own block, Z follows in a second — `G53` is not modal and no firmware here guarantees a machine-frame diagonal. **There is no X/Y retrace, and that is the finding's substance**: nothing after a change is measured from where the tool stood before it, and where a change coincides with a change of work offset the two registers' true relationship is not known to the post at all, both being probed at runtime. What *is* owed is the ordering of the next rapid — `rapidMovements()` reads `getCurrentPosition().z`, which after an excursion is not where the tool is, and its rising-Z branch would have crossed the bed at the **section's clearance height** instead of the travel height the tool was already holding. `forceRapidXYBeforeZ` forces cross-then-descend for that one move and is cleared by the first commanded work-frame Z. Refused: a half-specified X/Y, any position without a fixed Z reference, and X/Y without X/Y homed. Flow 2 is untouched — the changer position is the macro's own, in a frame the post cannot see — and the fields draw a warning there rather than being dropped in silence | ✅ |
| **PR-27** | On GRBL nothing keeps the steppers energised through the tool-change pause | Med | Marlin and RepRap get `Start()`'s `M84 S0` and are covered for the whole job. GRBL's equivalent is `$1`, the step idle delay — a **setting**, not g-code, and accepted only in `Idle`, so the post can never emit it. `st_go_idle()` runs whenever the segment buffer drains, which an `M0` pause causes, and disables the drivers after `$1` ms unless `$1` is `255` (`stepper.c`; the stock default is `25`, `defaults.h`, Grbl 1.1). The position **counter** survives — what does not is the axis holding against a hand on the collet or an unbraked Z on a leadscrew that back-drives. A post-time warning naming `$1=255`, **gated on the tool change** rather than on every `M0`: the same setting protects the spindle and probe prompts, but this is the pause that runs to minutes with a spanner in it, and a warning on every job containing a prompt would be read by nobody | ✅ |
| **PR-28** | `rapidMovements()` ordered itself against a Z the tool is not at, after any post-injected move | Low-Med | **The kernel is told, rather than the post keeping a second copy of the truth.** `getCurrentPosition()` reports the **toolpath's** position — the kernel advances it from the movements it feeds `onRapid`/`onLinear` and never saw the nine moves the post injects on its own account: the probe traverses, the safe-Z retracts, the returns to X0 Y0. Four readers were stale after one of them — the X/Y-against-Z ordering, `isSafeToRapid()`'s G1→G0 restore, and the feedrate projection in both `linearMovements()` and the arc handler — so the flag `PR-26` left fixed the ordering of one move and none of the rest. `noteCurrentPosition()` reports each work-frame move through the kernel's own `setCurrentPosition()`, called from inside `rapidMovementsXY()` / `rapidMovementsZ()` so all nine injection sites are covered without one of them being edited, with `undefined` meaning **unchanged** so an X/Y move claims no Z. **What it cannot reach is the machine frame**, and that is the finding's limit: `setCurrentPosition()` takes a *frame* position, and the work-frame value of a `G53` height needs the WCS offset a runtime probe establishes. Autodesk's own posts leave the kernel stale across a machine-frame retract for the same reason, reporting that move only to the machine simulator on a channel tagged `coordinates: MACHINE` (`haas.cps`, `writeRetract()`, `G53` case). So `forceRapidXYBeforeZ` stays, now as the named residue rather than a point fix — feeding a made-up number in its place would order that one move correctly and silently corrupt the other three readers | ✅ |
| **PR-19** | The post claimed GRBL cannot jog at an `M0` pause, and said nothing at all about Marlin | Med | The claim was false and shipped in five places. Jogging at the pause is a condition on **what holds the pause**, stated once in `jogAtPauseCondition()` and written by both channels. GRBL: the sender decides — gSender rewrites the line to `(M0)` and holds its own stream (`src/server/controllers/Grbl/GrblController.js`, master, 2026-08-14). Marlin: **a real gap the walk found** — `M0` blocks in `wait_for_user_response()`, whose `idle()` reaches `queue.get_available_commands()` but never `queue.advance()` (`MarlinCore.cpp`, 2.1.2.5), so a serial jog queues and runs **after** the pause. RepRap alone needs no condition | ✅ |
| **CR-01** | GRBL ignores `F` on `G0`, so the group-2 travel speeds do nothing there | Wrong output | **The post cannot set that rate, so it names the parameter that does — in the file, on every GRBL job, as the first line.** GRBL takes a rapid's rate off the axis limits and never out of the block: `block->programmed_rate = block->rapid_rate`, `rapid_rate = limit_value_by_axis_maximum(settings.max_rate, unit_vec)` (`grbl/planner.c`, `plan_buffer_line()`, gnea/grbl 1.1), and FluidNC is the same planner renamed (`FluidNC/src/Planner.cpp`, `block->motion.rapidMotion`, `limit_rate_by_axis_maximum()`, 3.x). Nothing a posted file may contain reaches it: `$110`–`$112` are settings, refused outside `Idle`/`Alarm` (`system_execute_line()` → `STATUS_IDLE_ERROR`; FluidNC's `Setting::check_state()` → `Error::IdleError`), and the rapid override is the real-time bytes `0x95`/`0x96`/`0x97`, not stream content. **The warning names both dialects because the post cannot tell them apart** — one `Grbl` answer covers FluidNC, which kept the g-code and dropped the numbered settings: no `$110` there, the limit being `max_rate_mm_per_min` per axis (`FluidNC/src/Machine/Axis.cpp`). `PR-27`'s `$1` warning is the precedent — a setting the post can never emit, so it says so — and this one is **ungated**, being true of every job on the default firmware. The tooltip half landed with it: both travel-speed descriptions now name the firmwares that read them. **The `F` word stays on the `G0`**: it is still stored (`gc_state.feed_rate = gc_block.values.f; // Always copy this value`, `grbl/gcode.c`), so it sets the modal feed the next cut inherits — which is why `PR-9` put one on the park block. **Mapping travels to `G1` so the `F` would be obeyed was built and rejected** — `travelMotionGcode()`, one switch over both rapid writers and `writeMachineFrameBlock()`, dropped by the author's ruling before it landed: a rapid is a rapid, and the machine's own limit is the operator's setting to make. Expect it to be re-proposed; the answer is here | ✅ |
| **CR-02** | `(MSG …)` prompts omitted the conventional comma | Cosmetic | `askUser()`'s GRBL arm writes `(MSG,<text>)`. **The comma is load-bearing on grblHAL** — `strncasecmp(comment, "MSG,", 4)` in `gc_normalize_block()` (`grblHAL/core`, `gcode.c`, read 2026-08-14), which surfaces nothing without it, so the prompt was an unexplained pause there. The other two dialects pay nothing: FluidNC matches `strstr(comment, "MSG")` and skips a fixed four characters (`gcode_comment_msg()`, `FluidNC/src/GCode.cpp`), and stock grbl 1.1 discards comments entirely. No space after the comma — grblHAL trims one, FluidNC would keep it. **Every `M0 (MSG …)` line in every GRBL file changes**; `validateJob()`'s `PR-20` comment was re-quoted to match, and the two line numbers `CR-01` left stale in the same sentences were corrected with it | ✅ |
| **HR-13** | `onCommand` silently discarded every command it did not name | Low-Med | Two halves, and both are landed. The **silence** went with `f54beb0` — every unnamed command reaches a `writeWarning()` below the `switch`, so it outlives Comment Level `Off`, which matters because Manual NC is invisible to `validateJob()` and there is no post-time twin to carry it. **`COMMAND_OPTIONAL_STOP` now emits `M0`**, by the author's ruling: no supported firmware has a working *stop only if asked*, so the choice was a stop that cannot be skipped or a command that vanishes. **`M1` is refused**, and the registered diff that proposed it was right about the parser and wrong about the behaviour — grbl 1.1 accepts and ignores it (`gcode.c`, *"case 1: break; // Optional stop not supported. Ignore."*), RRF handles `M0`/`M1`/`M2` in one block and so **ends the job** mid-file (`src/GCodes/GCodes2.cpp`), and only Marlin waits (`src/gcode/lcd/M0_M1.cpp`, under `HB-1`'s `HAS_RESUME_CONTINUE`). The file says at each occurrence that the *optional* half is what could not be kept | ✅ |
| **HR-19** | `M291` carried a doubled space | Low | The RepRap arm of `askUser()` built its parameter string with a leading space, on top of the separator `writeBlock()` already supplies — so `M291  P"…"` at **both** `Include Whitespace` settings, the manual prefix covering the other one. The space is gone; the GRBL and default arms never had it, and `X1 Y1 Z1`'s leading space stays, joining inside one word | ✅ |
| **HR-24** | `writeWCS()` read the global `tool`, not the section it was handed | Low | `section.getTool()`, held in a local and read by the `canProbe` test. **Emits exactly what it did**: both callers pass `currentSection`, whose tool *is* the global at that moment, so the change makes the agreement structural rather than coincidental. `writeWCS()` is the only function in the post that takes a section and could be called with one that is not current | ✅ |
| **HR-20** | Tapping is not really implemented | Med | **Closed by design — tapping is not supported**, by the author's ruling, and no code changed. Both registered halves were already answered: the automatic path no longer always emits `M4` — `spindleOn()` writes `M3` or `M4` off the commanded direction, and prompts a manual spindle for a reversal at an unchanged speed — and the manual path prompts. What is left is **rigid** tapping, which no supported firmware can do at all, there being no `G33`/`G84` on any of them, and `writeSpeedFeedSyncWarning()` says so on **every** speed-feed-synchronization command so every affected move is flagged. An ordinary tapping cycle still expands into `G0`/`G1` through `onCyclePoint()`, which wants a floating/tension holder — the warning's own words | ➖ |
| **HR-27** | A geometry guard leaves a truncated `.gcode` | Med | **Closed by design**, by the author's ruling: `currentSection.isMultiAxis()` and `isSectionOrientationSupported()` stay in `onSection()`. Moving them into `validateJob()`'s section loop would strand the orientation guard's `Debug` trace, which is emitted on **every** path by design and is the only thing that distinguishes a guard that read nothing from one that read `+Z` and allowed it — at post-validation time there is no output stream to write it to. `PR-2c` carries the falsifier: what a refused job leaves must not be a runnable `.gcode` | ➖ |

---

## 4. Open tests

**⬜ 60 UNRUN · ❌ 0 FAIL · ➖ 5 n/a — 65 rows.** **§4.1 is closed and gone**, and the `S2`/`S3`
debt with it: `PB1`, `PB2`, `PBV1`, `PBV2`, `PBV3`, `M1`, `M2` and `M4` passed on posted files
2026-08-14, and the twenty-six rows that turn on Steps 1.3, 2 and 3 closed **by code walk**
2026-08-14 — §5 holds each one's argument. **The nine tool-change rows deleted with the old design
are replaced by the twenty-two `TC-`/`PR-21a`/`PR-22a` rows below**, ten written as Step 5 landed,
six more with Flow 2 and four with the change position, 2026-08-14. All but `TC-2` and `PR-21a`
need a **full licence**: a Personal
licence emits no tool change, so there is no boundary in its files to post against. **`TC-16` is
the only row in this register that can fail without the post being wrong** — it asserts what
another program does with a correct file.

**What is left here cannot be settled from the source.** The four `D` rows and `P7` are the
dialog's own behaviour; `PR-2d` is the only inch output the post has ever been asked for, and
nothing in the walk can say what `createFormat` resolved its decimals to; `REG-MF`, `REG-S0` and
`FCR-13` are whole-file diffs; `PR-2c` sweeps guards outside those three steps; and the jet and
tool-change rows wait on workstreams that have not been built.

**Standing configuration.** GRBL, mm, `Comment Level` `Info`, probe target `Z-10`, probe
speed `F30`, probe thickness `Z0.8`. **A row names only what it changes from that line.**
Output goes to `Documents\Fusion 360\NC Programs\`, is not in the repo, and a reused
filename destroys evidence.

**Four methods.** `posted` — the job is run from Fusion and the g-code read. `dialog` — settled by
opening the Fusion dialog, and no posted file can show it. `walk` — settled by reading the code that
would emit it. **A walk is admissible only where the emission is fully determined by the post**: it
proves what the post writes given a configuration, and never what Fusion feeds it, what the dialog
renders, or what a controller does with the result. Where a row's every emitted line is separately
witnessed in an existing artifact, say which one. `sender` — **new with `PR-20`, and one row uses
it**: the file is correct and identical either way, so the assertion is about what a sender does with
it. It needs gSender and a machine that need not cut; it does not need a controller this project
lacks.

| Test | Proves | Setup (delta) | Method | Expansion | State |
|---|---|---|---|---|---|
| **D1** | Labels, groups and field types | the dialog | dialog | — | ⬜ |
| **D2** | The property dump is suppressed at Comment Level `Important` and `Off` | Comment Level `Important`, then `Off` | posted | — | ⬜ |
| **D3** | A key rename resets that setting **once**, and the new key then holds — now `spoilboardTravelZ` → `machineTravelZ` | a preset saved before the rename | dialog | — | ⬜ |
| **D4** | The groups are still identifiable in the **legacy** Post Process dialog | the legacy dialog | dialog | — | ⬜ |
| **P6** | `writeWCS()` debug/info logging | Comment Level `Debug`, then `Info` | posted | — | ⬜ |
| **P7** | `wcsDefinitions` offset-0 decision | work offset `0` | dialog | — | ⬜ |
| **PR-1a** | The capability/action split emits what the old enum did, and nothing when the action is off | group 4 declarations × `Home at Job Start`, GRBL then Marlin | posted | — | ⬜ |
| **PR-1b** | The stored-offset warning fires on the trusting modes and **never** on the `Jog …` modes | 2-WCS job, each origin mode in turn | posted | — | ⬜ |
| **PR-2c** | Every guard refuses and leaves **nothing runnable** — including the two **geometry** guards, which fire in `onSection()` after output has begun, so what they leave must not be a usable `.gcode` (`HR-27`) | each `error()` condition in `validateJob()`; then a multi-axis toolpath, then a Setup built on a model face rather than the stock top | posted | — | ⬜ |
| **PR-2d** | `Machine Travel Z` converts mm → inch in both the block and the header echo | multi-WCS, `Machine Travel Z = -12`, output units **inch** | posted | — | ⬜ |
| **CR-01a** | The travel-speed warning is the **first line** of a GRBL file at `Comment Level` `Info` **and** at `Off` — `writeWarning()` ignoring the level is the whole of the second half — is **absent on Marlin and RepRap**, and moves no g-code: the rest of the file is the pre-change file shifted by one line | one tool, factory defaults; posted on GRBL at `Info`, again at `Off`, then on Marlin | posted | — | ⬜ |
| **PR-19a** | The in-file jog condition, all three firmwares: **GRBL names the sender, Marlin names the panel and the queued-not-executed pause, RepRap emits nothing at all** — the absence is that branch's whole assertion, and the `M291` beside it must carry `X1 Y1 Z1` | one part, First = `Jog to X0 Y0 Z0`, posted on each firmware in turn | posted | — | ⬜ |
| **PR-19b** | The post-time half fires on the same answers, in the same words, and **no warning in the dialog says a jog mode does not work** — the two clauses that recommend one now stand beside it uncontradicted | GRBL, `XYZ` + `Home`, `Machine Travel Z` filled, 2 WCS, First = `Set X0 Y0 to Current Pos, Probe Z0`, Subsequent = `Jog to X0 Y0, Probe Z0`; then Marlin, then RepRap | posted | — | ⬜ |
| **PR-18** | — proved by **PR-19b**: the contradiction is gone when all three warnings read together name no impossibility | — | — | — | ➖ |
| **PR-20a** | The warning names **exactly the stops this job puts inside the ten lines** and is silent when there are none — `Pause, then Home` with nothing declared homeable, `Probe Pause` `No`, and both `Use Active WCS X0 Y0 Z0` / `Set X0 Y0 Z0 to Current Pos` are the silent cases, and Marlin and RepRap are silent at every setting | GRBL at `Comment Level` `Off`: defaults; then `Pause, then Home` + `XYZ`; then each first-part mode in turn; then `Probe Pause` = `No`; then the same at `Info` | posted | — | ⬜ |
| **PR-20b** | gSender itself: **the same file, posted once, stops at the prompt when streamed after ten lines and runs past it when not** | one file at `Comment Level` `Off` and one at `Info`, defaults otherwise, each streamed from gSender with the spindle off and the tool clear | sender | — | ⬜ |
| **TC-1** | A multi-tool job at the default `Refuse to post` **writes no file at all**, and the dialog names both remedies | 2 tools, group 6 untouched | posted | — | ⬜ |
| **TC-2** | Group 6's rebuild moves **no g-code** on a single-tool job: the whole diff is the property dump — group 6's heading, its 8 keys replaced by `toolChangeMode` / `toolChangeSender` / `toolChangeMacroFile` / `toolChangeFirstLoad` / `toolChangeProbeAfterChange`, and group 7 losing `includeProbeFile` | all defaults, diffed against the pre-Step-5 build. **Runs with `REG-MF`, one post** | posted | — | ⬜ |
| **TC-3** | The hand-over block, in order and complete: `G53 G0 Z<travel>`, coolant off, the spindle stop, `M0 (MSG Change to Tool #n …)`, then the re-probe — and cutting resumes with the spindle prompted back on | 2 tools 1 WCS, `Machine Travel Z = -12`, `XYZ` + `Home`, `At a Tool Change` = `Pause for a manual change` | posted | — | ⬜ |
| **TC-4** | **PR-15's core, and the one row that proves the ordering.** At a boundary that is both a WCS change and a tool change, the `G10 L20 P<n>` after the change names the **new** section's register — `P2`, not `P1` | `TC-3` plus a second WCS, `Subsequent WCS / Part` at its default | posted | — | ⬜ |
| **TC-5** | An absence, and the whole point of the manual flow: **`grep -E 'M6\|M84 Z\|^T[0-9]'` over a two-tool file returns nothing**. `M84 Z` must be absent from a **Macro** file too — the token is the only thing that mode adds | `TC-3`'s file; then `TC-11`'s | posted | — | ⬜ |
| **TC-6** | `Prompt for the First Tool` stops **before** the first origin write — the `M0` precedes `G10 L20 P1` / `G92` — and `PR-20`'s post-time warning names it among the stops at risk at `Comment Level` `Off` | 1 tool, `Prompt for the First Tool` on; then again at `Comment Level` `Off` | posted | — | ⬜ |
| **TC-7** | Both silent-Z0 branches warn: `Re-probe Z0 After a Change` **off**, and a change into a jet tool / tool 0, which cannot probe | `TC-3` with the re-probe off; then `TC-3` with a jet second tool | posted | — | ⬜ |
| **TC-8** | With `Machine Travel Z` empty the hand-over emits **no `G53`** and warns in both channels — the post-time twin and the in-file `>>> WARNING:` | `TC-3` with `Machine Travel Z` cleared | posted | — | ⬜ |
| **TC-9** | Marlin's dialect through the change: `M400`, `G92` and not `G10 L20`, and **no `G28` anywhere in the sequence** | `TC-3` on Marlin | posted | — | ⬜ |
| **TC-10** | RepRap's pause is `M291 … S3` **with no `X1 Y1 Z1`** — the absence is the assertion, jogging being refused at this pause by design | `TC-3` on RepRap | posted | — | ⬜ |
| **TC-11** | **Flow 2's hand-over, in order and complete.** The arrive half is byte-for-byte `TC-3`'s down to the spindle stop; then `T2 M6` on **one line**, then the resume — `G90`, `G21`, `G94`, `G17`, `G54`, `G53 G0 Z-12` — and **no `M0` anywhere in the sequence** | `TC-3` plus `At a Tool Change` = `Hand over to the sender/firmware macro`, `Tool Change Handled By` = gSender, `Re-probe Z0 After a Change` **off** | posted | — | ⬜ |
| **TC-12** | `Other` emits **no token of its own**: the macro file's contents stand between the spindle stop and the resume, inside `--- Start/End custom gcode`, and `grep -E 'M6\|^T[0-9]'` matches only what the file itself contains | `TC-11` with handler `Other` and a two-line `toolchange.nc` in the NC folder | posted | — | ⬜ |
| **TC-13** | **The four Macro refusals leave no file**: Marlin at any handler; RepRapFirmware handler posted for GRBL; a GRBL sender posted for RepRap; `Other` with `Sender Macro File` empty. Each names the setting to change | `TC-11`, one guard condition at a time. **Extends `PR-2c`** | posted | — | ⬜ |
| **TC-14** | RepRap's route is the T word **alone** — `T2` with no `M6` beside it — and the resume omits `G94`/`G17`, which that firmware does not have below 3.5.1 | `TC-11` on RepRap, handler = RepRapFirmware tool table | posted | — | ⬜ |
| **TC-15** | Flow 2's post-time warnings fire on their own conditions and only those: the sender-must-intercept one on gSender/CNCjs, the `M563`/`tpost` one **and** `PR-25`'s travel-Z headroom one on RepRap, and the re-probe-overlap one whenever `Re-probe Z0 After a Change` is left on. A single-tool job in Macro mode is silent at every setting | `TC-11`, `TC-14`, then each with the re-probe on; then a 1-tool job in Macro mode | posted | — | ⬜ |
| **TC-16** | **gSender itself**: streaming `TC-11`'s file, the sender takes the `M6` out and runs its configured tool-change routine, and the controller never reports `error:20`. With gSender's tool-change setting at `Ignore` the change is **dropped silently** — the failure the post-time warning describes. Also watch whether the routine begins before the preceding `G53` retract has finished executing, GRBL having no sync code for the post to emit | `TC-11`'s file streamed from gSender, spindle off, tool clear, at two gSender tool-change settings | sender | — | ⬜ |
| **TC-17** | A manual change with `Tool Change Position X`/`Y` set emits, in order: the `G53` retract to `Machine Travel Z`, **then** `G53 G0 X.. Y..` at the XY travel feed, then the stops and the `M0`. Afterwards the section's **first rapid crosses before it descends** — `G0 X.. Y..` then `G0 Z..`, never the reverse. With the re-probe on, the probe's own `G0 X0 Y0` is the crossing and it runs at the travel height. **Both machine-frame blocks carry `G53 G0` and an `F`, and neither carries a third axis** | 2 tools, `Pause`, `Machine Travel Z` set, XYZ homed, position X/Y set well away from the part; posted twice, re-probe on and off | posted | — | ⬜ |
| **TC-18** | `Tool Change Position Z` **alone**: the change block is retract, `G53 G0 Z<change>`, stops, `M0`, `G53 G0 Z<travel>` — and **no** cross-before-descend comment, because X/Y never moved and the rapid that follows is ordered exactly as it would be with no position set. A change Z below `Machine Travel Z` draws the post-time warning; one above it draws none | `TC-17`'s job with X/Y cleared and Z set below, then above, `Machine Travel Z` | posted | — | ⬜ |
| **TC-19** | The position refusals leave **no file**: X without Y, a value that is not a signed decimal, any position with `Machine Travel Z` empty, and X/Y with `Axes Homed and Trusted` not including XY. Setting a position in **Macro** mode posts normally, uses none of it, and says so once. A single-tool job with every position field filled posts unchanged and emits no change at all | each condition posted on its own | posted | — | ⬜ |
| **TC-20** | The `$1=255` warning fires on GRBL for a multi-tool job in either hand-over mode, and is **absent** on Marlin and RepRap, on `Refuse`, and on a single-tool job | four posts, one per condition | posted | — | ⬜ |
| **PR-23** | — proved by **TC-4**: that file carries two probes into the same register, the first with the outgoing tool. The row records the cost; nothing about it fails | — | — | — | ➖ |
| **PR-21a** | Marlin + `At End Park At` = `Machine X0 Y0` warns in both channels that the park homes and zeroes the work origin; GRBL and RepRap are silent | Marlin, `XY` + `Home`, park `Machine X0 Y0`; then the same on GRBL | posted | — | ⬜ |
| **PR-28a** | The first rapid after a post-injected move is ordered against where the tool **actually** is. Diffed against the pre-fix build the only change in the file is that pair of `G0`s — X/Y before Z wherever the section's clearance sits below `Safe Z` — and **nothing else moves at all**, the note being what the kernel already believed for every toolpath rapid | 1 tool, `Probe on Start` = `Current XY & Probe Z`; then a 2-section job with `Re-probe Z0 After a Change` on | posted | — | ⬜ |
| **PR-22a** | A change from a milling tool into a **jet** tool still stops the spindle — `M5` or the `Turn OFF spindle` prompt is present before the change `M0` | `TC-3` with a jet second tool, `Manual Spindle On/Off` on then off | posted | — | ⬜ |
| **PR-6a** | The machine park emits `G53 G0 X0 Y0` as its own block, X/Y only | GRBL, `XY Only` + `Home`, park `Machine X0 Y0` | posted | — | ⬜ |
| **PR-6b** | The **Marlin** route is `G28 X` / `G28 Y`, and needs no prior homing | Marlin, `XY Only`, `Home at Job Start` = **`Off`**, park `Machine` | posted | — | ⬜ |
| **PR-6d** | `Work` (default) is byte-identical to the old boolean-on behaviour | defaults, diffed against the pre-change build | posted | — | ⬜ |
| **PR-7a** | `Pause, then Home` emits one pause then the homing, and `Home` emits homing with none | GRBL and Marlin, `XYZ`, both non-`Off` answers | posted | — | ⬜ |
| **PR-7b** | Group 4 reads declaration / action / park, and group 1 no longer carries the park | the dialog | dialog | — | ⬜ |
| **PR-9** | The `G53` park block carries the XY travel feedrate | PR-6a, `Travel Speed XY` off its default | posted | — | ⬜ |
| **PR-11** | The GRBL jog warning is silent on a single-WCS job whose *subsequent* mode is a `Jog` mode | one WCS, Subsequent = `Jog to X0 Y0, Probe Z0` | posted | — | ⬜ |
| **PR-13** | The Duet mode string is written once per section-type change, verbatim | `CNC Firmware` = RepRap, a milling job, then milling + laser | posted | — | ⬜ |
| **CR-02** | Every operator prompt on GRBL reads `M0 (MSG,<text>)` — `grep -c '(MSG '` = **0** and `grep -c '(MSG,'` = the prompt count — and **nothing else in the file moves**: the diff against the pre-change build is one comma per prompt line | defaults, diffed against the pre-change build. **Licence-free** | posted | — | ⬜ |
| **HR-19** | Every RepRap prompt reads `M291 P"…" R"…" S3` with **one** space after `M291` at both `Include Whitespace` settings, and a jog prompt still has exactly one before its `X1 Y1 Z1` | RepRap, First = `Jog to X0 Y0 Z0`, posted at `Include Whitespace` on and again off. **Rides with `PR-19a`'s RepRap post** | posted | — | ⬜ |
| **HR-24** | `writeWCS()`'s probe test reads the section's own tool, and **no byte of the file moves**: a re-post of a verified job is identical to the pre-change build, which is the whole assertion | any verified reference job, diffed against the pre-change build. **Rides with `REG-MF`, one post** | posted | — | ⬜ |
| **HR-13** | Both halves: an unnamed command warns instead of vanishing, and Manual NC *Optional stop* emits `M0` with its own warning beside it — **on all three firmwares, and no `M1` anywhere in the file** | Manual NC *Orientate spindle*, then Manual NC *Optional stop*, each again at Comment Level `Off` | posted | — | ⬜ |
| **HR-20** | — retired with `HR-20`: closed as unsupported with no code change, so there is nothing to post | — | — | — | ➖ |
| **HR-27** | — proved by **PR-2c**, which now covers the two `onSection()` geometry guards: a refused job leaves nothing that will run | — | — | — | ➖ |
| **HR-28 (A)** | The stored-offset warning on a multi-WCS job | 2 WCS, `Axes Homed and Trusted` = `None` | posted | — | ⬜ |
| **FCR-4** | Coolant `Use custom` loads a file rather than writing its name | Channel A Mode = the tool's coolant, On/Off = `Use custom`, a real `air_on.g`/`air_off.g` in the nc folder; then again with the field empty | posted | — | ⬜ |
| **FCR-5** | A jet / tool-0 first part warns that Z0 was never set | a jet tool, then tool 0, on the default first-part mode | posted | — | ⬜ |
| **FCR-13** | `resetPostState()` — byte-for-byte identical output on a re-post | any verified reference job, re-posted; ideally two setups to separate files in one invocation | posted | — | ⬜ |
| **J1** | First-part origin modes — all six, with a jet tool and with tool 0 | jet tool / tool 0 | posted | §6 | ⬜ |
| **J2** | Subsequent WCS / Part with a jet tool — the `canProbe` false branches | jet tool, multi-WCS | posted | §6 | ⬜ |
| **J4** | The laser property group (`8 - Laser`, 7 properties) — **never posted at all** | group 8 on, a laser operation | posted | §6 | ⬜ |
| **J5** | Laser/jet × the multi-WCS frame features | jet + cross-part clearance in the machine frame | posted | §6 | ⬜ |
| **REG-MF** | A factory-default job is unchanged **apart from the property dump** | all defaults, diffed against the pre-change build | posted | — | ⬜ |
| **REG-S0** | Step 0.3 / 0.4 / 0.6 move no byte of an ordinary job | defaults, no Manual NC, no probing operation | posted | — | ⬜ |
| **P4** | Group 04's branches | — superseded by **PR-1a**: the enum it tested no longer exists | — | — | ➖ |

---

## 5. Passed tests

**✅ 64 PASS · ❌ 0 FAIL · ➖ 3 n/a — 67 tests in 60 rows** (an `(A)`/`(B)` pair shares a
row). Nineteen rows are hobbyist, posted 2026-08-08 from a build proved identical to
`e5db625`; `PR-2a` was posted 2026-08-13 from the build Step 1.1 ran on; `PR-2e`, `PR-2f`,
`PR-2g`, `PR-2h`, `PR-14a`, `PR-14b`, `PB1`, `PB2`, `M2`, `PBV1`, `PBV2`, `PBV3`, `M1` and `M4`
were posted 2026-08-14 from `c0ceb86`. Every one passed on first read; none was ever marked ❌.

**Twenty-six rows closed by code walk 2026-08-14 against `e11d0c9`** — the Step 1.3 remainder and
the whole of Steps 2 and 3. §4 states what a walk may settle; each row below names the artifact
its emissions are witnessed in, or says plainly that it stands on the source alone. **Two rows
were corrected by the walk rather than confirmed** — `PR-6c`'s setup could not produce what it
asked for, and `S3f`'s byte-identity claim is false in one respect it now states.

| Test | Result |
|---|---|
| **HB-1 (A)/(B)** | ➖ Retired with HB-1 — no warning was added, so there was nothing to post |
| **HB-2 (A)/(B)** | `HB-2 (A).gcode`, the baseline every other row diffs against. `grep -c '%'` = 0. **Trap: `M30` is the last g-code *block*; `( *** STOP end ***)` is the last *line*** |
| **HB-3 (A)/(B)** | `HB-3 (A).gcode`:114 carries the nothing-was-homed warning with no `$H`/`G28`/`G53`; (B) has `$H` in its place. **Trap: (B)'s criterion is the absence of HB-3's own text, not a clean dialog** |
| **HB-4 (A)/(B)** | `HB-4 (A).gcode`:127-131 — provisional `Z0`, retract, `X25 Y0 F2500`, the lift absolute from the operator's own height. The two files differ only in that property and those four lines |
| **HB-5 (A)/(B)/(C)** | Both channels, in both directions. (B) holds **no** `format error` while the dialog warns — *it warns although the property is inert with the mapper off*, which is the loop covering both fields |
| **HB-6 (A)** | ➖ Retired with HB-6 — no code change |
| **HB-7 (A)** | No `.gcode` exists; the run left a 51-byte `.failed`. **The log locates the abort, which the absence alone cannot:** `Failed while processing onOpen().` |
| **HB-8 (A)** | `-1.gcode`/`-2.gcode`, each a single-property delta. **The direction is the point:** both leaks were sticky one-way. All 26 `F` words in (2) checked against the modal feed sequence |
| **HB-9 (A)** | `grep -c '^('` = **2**, the two warnings; 39 code lines byte-identical to the baseline. **Trap: the `^(` anchor is the criterion** — four `M0 (MSG …)` prompts correctly survive at `Off` |
| **HB-11 (A)** | `grep -c '^()$'` = 0, `^( )$` = **17**, the pre-fix count for both forms combined — the form changed and the number did not |
| **HB-12 (A)** | The discriminator was order: :192 the `G18` lead-out, :198 a bare `G17`, :204-205 the footer's arcs. **Traps: no `( *** STOP end ***)`, and the footer's `G0 Z15.24` duplicates the section retract** |
| **HB-13 (A)** | Both posts and the dialog. The `Off` file is 42 lines with the warning at :7, its **40 g-code lines byte-identical** to the `Info` file's |
| **HB-14 (A)/(B)** | Both call sites, exact complements — `15mm` on the probe field then the map field. **Placement attributes (B) to the shared writer:** (B)'s warning sits inside `*** SECTION begin ***` where (A)'s is at line 1 |
| **HB-15 (A)** | At the dialog. The text ends at `or clear the field.` and claims nothing about truncation |
| **HB-16 (A)** | :159 is the first XY arc after the loaded header and carries its own `G17`; the file holds exactly two. **Trap: `G90`, `G21`, `G94` each count 0 — the include contract, not a defect** |
| **HB-17 (A)** | The discriminator held two lines apart: :122 the ignored-base warning, :124 the unknown-Z warning. `grep -c G53` = 0; `grep -c '( >>> WARNING'` = 0 against three `;` forms — the dialect switch, not a miss |
| **HB-18 (A)** | :122 ends `frame$` under `cat -A`. Both Marlin posts came back **318 lines, the pre-fix control's own count** — nothing but :122's text moved |
| **HB-19 (A)** | At the dialog, on both posts. **Trap: CR-2's warning is beside it, byte-identical to the pre-fix report** — a flat "one warning" criterion reads this PASS as a FAIL |
| **HB-20 (A)** | By **code walk** — the one ✅ with no artifact, and the reason is a licence: exercising the mapper needs the Personal edition. The branch chain is value-identical, not merely equivalent (`&&` returns its right operand), and every operand is `let`-bound above the chain from pure reads, so dropping a conjunct skips no computation, call or output. **Trap: this is an identity proof for one pairing, not a claim that no configuration changed** |
| **PR-2a** | `Multi_WCS (b).gcode`, ticked by the author 2026-08-13: `spoilboardFixedZRef = Machine Z` with `spoilboardBaseReserve = None` — **the machine-Z route posts with no reserved base** — and **one `G53 G0 Z-10 F300` per traverse**, :880, :1267, :1654, each two lines above its `G55`/`G56`/`G57`, plus :485 for the job-start establish. **Two deltas from the row as written**, neither material: four distinct offsets rather than two, and `Inter Part Travel Z = -10` rather than `-12`. **Trap: `probeOnStart` and `probeOnChange` are both `Skip`**, so the file proves the frame and the traverse and says nothing about origin-mode dispatch — that is `M1`–`M4`. This artifact is also `PR-2e`'s baseline |
| **PR-2e** | `Multi_WCS (pr-2e).gcode` against `Multi_WCS (b).gcode`: **three lines differ, two of them the assertion** — `spoilboardFixedZRef = Machine Z` → `None`, and `Fixed Z reference = Machine Z` gaining `-- from the homed machine declaration, not set in the dialog`. The third is the generated-on timestamp. All four `G53 G0 Z-10 F300` and all four offsets `G54`–`G57` intact; **no g-code moved**. **Trap: Fusion prints `Warning: Multiple work offsets used in program.` on any multi-WCS post** — Autodesk's, not the post's; the string is nowhere in the `.cps` |
| **PR-2f** | `Multi_WCS (pr-2f).gcode` against `(pr-2e)`: `machineHomeAtStart = Home` → `Off`, `$H` replaced by `( writeMachineHoming: Home at Job Start off -- current position accepted as zero, no motion)`, and **nothing else**. It **posted**, where the build before `c0ceb86` refused it, and the four `G53` are untouched — the author's ruling entire, in one file |
| **PR-14a** | The chain's **first** stop, from the PR-2e job with `Axes Homed and Trusted` = `None`. Guard B's replacement text emitted verbatim — one sentence naming the homed machine, `"Axes Homed and Trusted"` to `XYZ`, `group 4 - Machine Frame`, and `Inter Part Travel Z` in group 5 — and **no `.gcode` was written**, only a 51-byte `Multi_WCS (pr-14).gcode.failed`. **Trap: `HR-28`'s stored-offset warning fires in the same dialog** and is correct there — `None` is exactly its trigger — but the refusal means no file exists, so this run is **not** evidence for `HR-28 (A)`, which wants the in-file channel |
| **PR-14b** | The **second** stop, from the same job with `Axes Homed and Trusted` back to `XYZ` and `Inter Part Travel Z` cleared. `Multi_WCS (pr-14b).log`: `:1682` verbatim — `"Inter Part Travel Z" (group 5 - Fixed Z Reference)`, `ABSOLUTE machine coordinate`, and the jog-and-read-the-DRO instruction — aborted in `onOpen()`, with only a 51-byte `.failed` on disk. **The discriminator is what is missing:** `Total number of warnings: 1` (Fusion's own) and no stored-offset warning, so X/Y *was* declared — the job reached the machine-Z guard through the **derived** frame with `Fixed Z Reference` at `None`, which is `PR-2e`'s derivation proved a second time, on the refusal path |
| **PR-2g** | `PR-2g.gcode` at factory defaults: one offset (`G54`), `grep -c G53` = **0**, `Fixed Z reference = None` with no derived clause. **Trap: it does not isolate the gate** — at defaults `machineHomedAxes = None`, so three of the derivation's four conditions are false together and the file cannot say which one held. **PR-2h** is the row that does |
| **PR-2h** | `PR-2h.gcode`, the gate isolated: `machineHomedAxes = XYZ`, `machineHomeAtStart = Home`, `machineParkAtEnd = Work`, `spoilboardFixedZRef = None` — three of the four conditions true, **only the offset count false**. One offset (`G54`), `grep -c G53` = **0**, `(   Fixed Z reference = None)` with no derived clause, and `$H` present. The derivation is gated on the offset count and nothing else, so an ordinary one-part job on a fully homed machine is untouched. **Trap: it posted at `Comment Level` `Info`, not the `Debug` the row asked for, and that is sufficient** — the property dump and the Resolved Values block both emit at `Info`, so every criterion is still read from the file. **Trap: it carries the `Home at Job Start` / first-part warning**, which predates the change (`1eb8141`) and is `probeOnStart = Current XY & Probe Z` meeting `$H`, not the frame |
| **PB1** | `Multi_WCS (PB1).gcode` — **the origin-mode dispatch, which is all this row adds**: `PR-2a` proved the frame and the traverse with both probe modes at `Skip`, and here both are `Probe Z`. **Two `G53 G0 Z0 F300` and no others** — :126 the job-start establish, :206 the one boundary — each a **bare Z block**, and :206 sits two lines *above* its `G55` at :208. Each part probes at its own stored XY: `G0 X0 Y0 F2500` → provisional `G10 L20 P<n> Z0` → `G38.2 F30 Z-10` → `G10 L20 P<n> Z0.8`, into `P1` at :129-141 and `P2` at :210-222. `spoilboardFixedZRef = None` :44 beside a resolved `Machine Z -- from the homed machine declaration, not set in the dialog` :108 — **the derivation, a third time** (`PR-2e`, `PR-14b`). **Trap: two work offsets, not the four its source job had** — one boundary carries the assertion and every added copy repeats the same one. **Trap: the file's two `>>> WARNING:` lines are coolant** — `Flood` requested against two `Off` channels — not the frame. **Reposted 2026-08-14, and the line numbers above are the repost's**: the first post's are gone with the artifact, the filename having been reused against §4's own warning. **Trap: the repost moved three things, not the one it was aimed at** — `Inter Part Travel Z` `1` → `0`, `Comment Level` `Debug` → `Info`, and a shorter operation list (280 lines against the batch's ~959), so **no diff against the first post is possible and none should be claimed**; what it establishes is that the assertion re-passes at a second height, not that the height is the only thing that moved. **The `Info` level is sufficient** — the property dump and the Resolved Values block both emit at `Info`, so every criterion above is still read from the file (`PR-2h` carries the same trap). **That the height reaches nothing but its own block is checked across files instead**: this boundary against `PBV2`'s :879-898, same `probeOnChange`, differs in the `G53` Z word and its one comment and in nothing else but `PBV2`'s `Debug` lines. **Trap: `0` is wrong too** — `PR-17` puts the ceiling at the pull-off `-$27`, not at zero, so this row still stands on a value no machine should run |
| **PB2** | `Multi_WCS (PB2).gcode` — the added copy trusts the stored Z: :896 `G53 G0 Z1 F300` → :898 `G55` → :899-900 `(   Move to this part's stored origin X0 Y0)` → `G0 X0 Y0 F2500` → cutting. **The file holds exactly one `G38.2`, at :501, and it is the *first* part's** — `probeOnStart = Probe Z`, `probeOnChange = Skip` — so the absence the row asks for is the added copy's alone, and the first-part probe beside it is what makes that reading meaningful. Arrival at `X0 Y0` is from the machine-frame retract, not from wherever the cut ended |
| **PBV1** | `Multi_WCS (PBV1).gcode` — **the two dispatches `PB1` does not reach**. First part `Current XYZ`: :489 `G10 L20 P1 X0 Y0 Z0`, with no prompt and no probe before it. Added part `Jog XY & Probe Z`: :880 `G53 G0 Z1 F300` (bare Z, two lines above its `G55` at :882) → :884 `M0 (MSG Jog to X0 Y0 above Z0, probe)` → :888 `G10 L20 P2 X0 Y0 Z0` → :897 `G38.2 F30 Z-10` → :899 `G10 L20 P2 Z0.8`. **It settles §4.1's open decision by evidence** — the added-part jog mode *does* get a provisional `Z0`, folded into the XY write rather than emitted as its own block, :886 saying why; the row's expected `G10 L20 P2 X0 Y0` was the stale half, and `M4` carries the correction. **Trap: the file's `>>> WARNING:` at :883 is the GRBL jog refusal and is correctly placed**, one line above the `M0` it describes — it is the post-time set beside it that is `PR-18`. **Trap: the row's closing clause is unmeetable** — confirming `G54`/`G55` at the controller needs a controller; the emitted origin writes are the whole of what is proved |
| **PBV2** | `Multi_WCS (PBV2).gcode` — **the first-part `Skip` dispatch is all this adds**: its boundary :879-898 is `PB1`'s (now :205-224 after that row's repost) block for block, `probeOnChange` being `Probe Z` in both — differing only in the travel height and in `PBV2`'s `Debug` comments. :487-489 `(   Use stored work origin; move Z to Safe Z, then to X0 Y0)` → `G0 Z5.08 F300` → `X0 Y0 F2500`, and **no origin write anywhere on the first part**. **Trap: `Skip` is the id of "Use Active WCS X0 Y0 Z0"** (:407, :422), not a do-nothing — the mode moves the tool. **Trap: the `X0 Y0` line carries no `G0` word**, modal from the block above, which is safe on GRBL only — see *Checked and found correct*. **Trap: the row's "no prompts anywhere" is not what the file shows** — `M0 (MSG Attach ZProbe)`/`Detach` at :895/:900 are `probePause = Before & After`, standing configuration, and stand in `PB1`'s expected block too; the criterion means no *jog* prompt, and there is none |
| **PBV3** | `Multi_WCS (PBV3).gcode` — the assertion is an absence: `grep -c G38` = **0** across the whole file. Boundary :880-884 `G53 G0 Z1 F300` → `G55` → `(   Move to this part's stored origin X0 Y0)` → `G0 X0 Y0 F2500` → straight into the cut at :892. First part identical to `PBV2`'s. **Trap: it is sound only where every copy's stock is the setup run's thickness** — the file cannot show that and no warning states it |
| **M1** | Proved by `PBV3`'s artifact: :880-884 **is** M1's block — retract → `G55` → `G0 X0 Y0` → cutting, no probe. **The substitution is `M2`'s** — *Multiple WCS Offsets* rather than *Replicate*, two distinct work offsets being what the dispatch turns on |
| **M4** | Proved by `PBV1`'s artifact: :880-899 **is** M4's block — retract → `G55` → jog prompt → `G10 L20 P2 X0 Y0 Z0` → `G38.2` → `G10 L20 P2 Z0.8`, tool 171. **Trap: the row was written `G10 L20 P2 X0 Y0`** and the emitted block carries the provisional `Z0`; the row is corrected. `M3` is the fourth boundary dispatch and the only one never posted — it closed on this artifact by walk |
| **M2** | Proved by `PB1`'s artifact — :896-914 of the first post, :206-222 of the repost that replaced it, the block being the same either way **is** M2's block — retract → `G55` → `G0 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8`, tool 171, no origin write of X/Y. **Trap: the job is *Multiple WCS Offsets*, not *Replicate*,** which the row was written around; two distinct work offsets is what the dispatch turns on, so the substitution holds. **The `+offset` half is `P2`'s** — `Probe XY offset` is `X0 Y0` here |
| **PA1** | **Walk — it collapses onto `M3`.** The post cannot see the difference between two Setups and a Replicate: `collectDistinctOffsets()` reads `getSection(i).getWorkOffset()` and nothing else, and nothing downstream reads a Setup's identity. Two Setups on one part is therefore two distinct work offsets and `M3`'s block below. **Trap: "a new WCS on a machined face" is invisible to the post** — the hazard is real and belongs to the operator, and no emitted line addresses it. `CR-17` is the register's entry for it |
| **PA1b** | Proved by **`PB1`'s artifact**: `Subsequent WCS / Part` = `Use Active WCS X0 Y0, Probe Z0` is what PB1 posted at :206-222, and `PA1`'s two-Setup shape is not a distinction the post makes. **No jog prompt**, that arm of the `else if` chain not being entered |
| **M3** | **Walk of `writeWCS()`'s `Jog XYZ` arm — the last of the four, and the other three are artifacts** (`M1` `PBV3`, `M2` `PB1`, `M4` `PBV1`). Emits `G53 G0 Z<travel> F<Travel Speed Z>` → `G5x` → the GRBL jog warning → `M0 (MSG Jog to X0 Y0 Z0, then continue)` → `(   Set current position to 0,0,0)` → `G10 L20 P2 X0 Y0 Z0` → cutting, **no `G38.2`**. Every one of those emissions is separately witnessed at `PBV1`:880-888, which has the retract, the select, the warning, the prompt and an identical `G10 L20 P2 X0 Y0 Z0`; the arm is a flat `else if` holding no state of its own, so the walk composes witnessed parts rather than predicting new output. **Trap: `M3`'s `Z0` is the real origin, not `M4`'s provisional** — nothing overwrites it |
| **P2** | **Walk of `partProbe()`, with `HB-4 (A)` for the emitted form.** Offsets `10`/`5` take the one `if (offsetSet)` branch — `(   Move to probe point = origin + offset X10 Y5, then probe Z)` → `G0 X10 Y5 F2500` — and `HB-4 (A)`:127-131 shows that comment and an `X25 Y0 F2500` out of the same function on the first-part path. **One function serves both parts**; the added-part call differs only in `atOrigin`. **The row's second clause is void: there is no base probe left to exempt from the offset** — it went with the spoilboard |
| **P3** | Added part proved by **`PB1`'s artifact** — offsets `0` were PB1's own setting, and :210 is the bare `(   Move to part origin X0 Y0, then probe Z)` form. First part by walk: on the default `Set X0 Y0 to Current Pos, Probe Z0` the call is `partProbe(true)` with no offset, which fails `if (!atOrigin \|\| offsetSet)` and emits **no reposition at all** |
| **M5** | **Walk, and subsumed by `S2a`.** One distinct offset means `writeWCS()` never sees `previousWorkOffset` defined, so `isTraverse` is false, no retract is emitted and the function returns before `probeOnChange` is read. At defaults there is no frame to retract into either. `PR-2g`/`PR-2h` already carry `grep -c G53` = 0 on such a job |
| **M6** | **Walk of `writeWcsOnStart()`'s `Skip` arm.** `canProbe` = `tool.number != 0 && !tool.isJetTool()`, and false suppresses `rapidMovementsZ(probeSafeZ())` **alone** — `rapidMovementsXY(0, 0)` sits outside the guard. So the block is the `X0 Y0` move with no Z retract, against `PBV2`:487-489's milling half which has both. **Trap: this proves the origin block and nothing else** — what a jet section then emits is `J1`/`J5`, and that workstream is deferred by design |
| **H7e** | **Walk on both firmwares.** RepRap writes `G10 L20 P1 …`; Marlin writes `G92 …`, and `writeWcsOrigin()`'s Marlin assertion passes because the single-offset suppression sets `currentWorkOffset` **before** returning — the one place it could have false-fired. **Trap: the warning text moved with Step 3.** With no frame this mode still warns, but its closing clause now names `Machine Travel Z` on every firmware; the old Marlin-only *"Marlin has no fixed Z reference this post can establish"* clause was deleted, having become false |
| **D5** | **Walk — the dump is fully determined.** `writeAllProperties()` buckets on each property's `group` and sorts on `groupDefinitions[g].order`, both literals in the source, so the file's dump is a pure function of the properties block. The delta against `069cc36` is exactly: the `5 - Fixed Z Reference` heading and its four keys gone; `machineTravelZ = <empty>` added to group 4 between `machineHomedAxes` and `machineHomeAtStart`; that group's heading gaining `, travel Z`; and the six headings `6`–`11` renumbered `5`–`10`. **63 grouped properties, from 66.** Every other key, order and value is untouched |
| **PR-2b** | Proved by **`PB1`'s artifact**: it ran this exact configuration — the frame filled, First = `Use Active WCS X0 Y0, Probe Z0` — and :126 is the establish `G53 G0 Z0 F300` with the arrival at `G0 X0 Y0 F2500` below it and **no unknown-Z warning**. **Trap: the real absolute Z is the establish, not the arrival** — the arrival is X/Y only and inherits the height, which is the design |
| **PR-17** | **Walk of a numeric predicate, both channels.** `parseMachineTravelZ() >= 0` gates `validateJob()`'s post-time `warning()` and `writeFixedZReference()`'s in-file `writeWarning()`, both `fw == eFirmware.GRBL`. Fires at `1` and at `0`, silent at `-10`; silent at every value on Marlin and RepRap; silent at any value when the field does not parse, `undefined >= 0` never being reached. **`0` is the discriminator and a `> 0` repair fails it** |
| **PR-5b** | **Walk of `writeResolvedValues()`.** Filled: `   Fixed Z reference = machine Z -- the machine's own homed Z, addressed with G53` and a second line `   Machine Travel Z in output units = <n> -- absolute machine Z`. Cleared: `   Fixed Z reference = None` and **the second line is not emitted at all**, the whole `if` being `fixedZEstablishedInFile()`. The absence is the assertion |
| **PR-6c** | **Walk, and the row's setup was wrong.** `PR-6a` declares `XY Only`, so `machineHomesZ()` is false and there is no frame however the height is filled — the row as written would have produced `PR-8b`'s no-retract warning and been read as a failure of this one. With the setup corrected to `XYZ` + a filled height, `writeMachineParkXY()` takes its `else` and emits `G53 G0 Z<travel> F<Z travel>` then `(   Park at machine X0 Y0)` then `G53 G0 X0 Y0 F<XY travel>` — **two blocks, never one diagonal**, which is `writeMachineFrameBlock()`'s one-block rule |
| **PR-8b** | **Walk.** `XY Only` + `Home` + park `Machine` passes both park guards and fails `fixedZEstablishedInFile()`, so `writeMachineParkXY()` takes its `if` and writes the *"no retract before parking at machine X0 Y0"* warning into the file, above an unretracted `G53 G0 X0 Y0`. The post-time half fires from the same predicate in `validateJob()`, which is what keeps the two from drifting |
| **PR-10** | **Walk.** The establish warning is gated on `fixedZEstablishedInFile() && (startMode == "Current XY & Probe Z" \|\| startMode == "Current XYZ")` — so it fires on both `… to Current Pos` modes and is silent on both `Jog` modes and both `Use Active WCS` modes. **Its closing clause forks on the offset count**: a single-part job is offered *"or clear \"Machine Travel Z\""*, a multi-part job is told that clearing it is not an option, Guard B requiring the frame |
| **S2a** | **Walk of the build diff `069cc36..e11d0c9`, and the strongest row here.** Every changed `Info`/`Important` emission in the post is one of: a string that only moved (` WCS unchanged`, the `-- machine Z` reason, ` Establish fixed Z reference`), a frame-gated line, or a spoilboard-only line now deleted. `writeResolvedValues()` is **byte-identical at factory defaults** — the old `getFixedZReference()` returned `None` with no derived clause and no reserved base, and the travel-Z echo was gated `!= "None"` where it is now gated on the same predicate. `probeTool()` lost three parameters whose surviving callers all passed `undefined`, so its output cannot move. No `G53` is reachable: no frame, no traverse, and `At End Park At` = `Work`. **The whole delta is the property dump, exactly as `D5` enumerates it.** **Trap: this is the GRBL claim only** — on Marlin the same job is *not* byte-identical, which is `S3f` |
| **S2b** | **Walk.** With one offset and the field filled, `fixedZEstablishedInFile()` is true — the offset-count gate that used to deny a single-part job the frame is gone — so `writeFixedZReference()` emits the establish, and `partProbe()`'s `zUntrusted && !fixedZEstablishedInFile()` is false, which is `HB-13`'s unknown-Z warning **not** firing. `validateJob()`'s twin at `startMode == "Probe Z" && !fixedZEstablishedInFile()` is silent for the same reason. **The assertion is a presence and an absence together** |
| **S2c** | **Walk.** Two offsets and `None` declared: `parseMachineTravelZ()` is `undefined`, so the field's own guards are skipped entirely, and Guard B's first arm fires — `!fixedZEstablishedInFile()` — with the message naming `"Axes Homed and Trusted"`, `group 4 - Machine Frame` and `"Machine Travel Z"`. `error()` and `return` inside `validateJob()`, called from `onOpen()` before any output; **`PR-14a` and `PR-14b` have both shown what Fusion then leaves on disk** — a 51-byte `.failed` and no `.gcode`. **Trap: the stored-offset warning fires in the same dialog** and is correct there, `None` being its trigger |
| **S2d** | **Walk — the two Guard B arms are distinguishable and this is the second.** `Z Only` + `-10` + two offsets: `machineHomesZ()` is true so the frame exists and the first arm passes, then `!homedXY` fires the second — *"traverses between STORED work offsets"*, which names the workflow and not the frame. **The order is load-bearing**: the frame complaint is the more basic and must be asked first |
| **S2e** | **Walk — the frame is Z-only.** One offset, so Guard B is never entered; `machineHomesZ()` is true on `Z Only`; the height parses. The job posts **with** the establish, which is what `S2d` refuses only for being multi-part. **Trap: the default `First WCS / Part` fires the establish warning here** (`CR-15`, `PR-10`) with its single-part clause offering to clear the field |
| **S3a** | **Walk.** `fixedZEstablishedInFile()` no longer excludes Marlin, so `validateJob()` warns rather than refusing — `CNC_COORDINATE_SYSTEMS` is assumed, not required — and `writeFixedZReference()` writes the same assumption into the file above the establish. `PR-17` stays silent, being GRBL-gated. **Trap: the unhomed-frame warning fires too** at the row's defaults, `Home at Job Start` being `Off` and the gate `fw != GRBL`; that is `S3d`'s assertion appearing here, not a second defect |
| **S3b** | **Walk of `writeMachineFrameBlock()`, and it found two things the row did not say.** The re-select is `wcsGcode(currentWorkOffset)`, so it is that job's own register and never a hard-coded `G54`. **(1) The job-start establish is itself a re-select site**: `writeWCS()` runs at step 3 of `writeFirstSection()` and the establish at step 5, so `currentWorkOffset` is already set and a Marlin **single-part** job with the frame emits `G54` right after its `G53` — the single-offset suppression is bypassed by the restore, correctly, the whole file already depending on the build option. **(2) At a boundary the restore names the *previous* offset**, the select not having happened yet, so the sequence reads `G53 G0 Z<n>` → `G54` → `G55`. Redundant and correct: native space is left, then the new register is chosen. The end park is where a `G55` restore is visible on its own — `G53 G0 Z<n>` → `G55` → `G28 X` → `G28 Y` |
| **S3c** | **Walk, and already visible in every GRBL artifact.** The re-select is inside `fw == eFirmware.MARLIN`, so GRBL emits the bare `G53` block and nothing after it — `PB1`:126 and :206, `PBV1`:880, `PBV3`:880 are four such blocks. The restore is Marlin-only because the reason is Marlin-only: GRBL's `G53` is not modal and leaves nothing to restore |
| **S3d** | **Walk.** The gate is `fw != eFirmware.GRBL && fixedZEstablishedInFile() && !homesAtJobStart()`, so Marlin and RepRap warn and GRBL does not — GRBL alone comes up in `Alarm` and refuses motion until homed, which makes a stale declared frame unexecutable there. **Trap: post-time only.** There is no in-file half, so the row is read in the Fusion dialog and a `.gcode` cannot show it |
| **S3e** | **Walk — the Marlin two-WCS job, and Guard C's deletion is the whole of it.** Two offsets on a Marlin job now reach Guard B on the same terms as any other firmware and pass it. `writeWCS()` emits `G54` for the first section (the single-offset suppression requires a count of one, and this job has two), then at the boundary `G53 G0 Z<n>` → `G54` → `G55`, then the `probeOnChange` dispatch. The origin writes are `G92`, which under `CNC_COORDINATE_SYSTEMS` writes `coordinate_system[active_coordinate_system]` — the register the `G55` just made active — and `writeWcsOrigin()`'s assertion holds at every call because `currentWorkOffset` is assigned before the dispatch runs. **Trap: what a walk cannot reach is the controller.** That Marlin honours this needs a Marlin, and there is none; the row is emitted output, which is what the register has always accepted here |
| **S3f** | **Walk — and the row as written is FALSE, corrected here.** The `G54` half holds: a single-WCS Marlin file on work offset 1 emits **no select at all**, so no stock-Marlin hobby file gains an unknown command. **But byte-identity does not hold.** The old Marlin branch returned before the `workOffset == currentWorkOffset` test; the new one returns after it, so **every section past the first now emits `( WCS unchanged: 1, not re-selecting)` at `Comment Level` `Info`, which is the default** — a multi-operation Marlin file gains one comment line per added section. **No g-code moves**, and the line is true and matches what GRBL has always said. The corrected assertion: *no `G54`, no g-code change, and one new comment per section after the first.* **A Marlin single-WCS job assigned to work offset 2 or above is a separate case** — it now emits `G55`, where it used to emit a warning and nothing, and that is deliberate: `G92` writes whichever workspace is active |

### Checked and found correct — do not re-run

Readings no row claims, kept only where re-raising them is the risk. Each retires when a row
asserts it or its artifact is superseded.

- **Motion words are omitted on seven lines of `HB-2 (A).gcode` and every one is correct.**
  `gMotionModal` is `createModal({})` **only** on the GRBL branch and `{force: true}` on
  Marlin/RepRap, so a bare axis line can never reach a firmware lacking modal motion.
- **`G38.2` is not left modal.** The `G0 Z5.08` after the probe is explicit, which it must
  be: `G38.2` is modal group 1, so a bare `Z5.08` would have been a second probe.
- **`Scale Feedrate` clamps per axis.** The XZ arcs take `F180`, the XY cuts `F900`. The arcs
  are the discriminator: a 45° XZ arc at the `F1000` XYZ limit would drive Z at ~636 mm/min.
- **Added-part re-probe repositions to the new part's `X0 Y0`** before probing — `Test2.gcode`.
  **Single retract per boundary**; **a same-WCS boundary emits no retract at all.**

> ⚠ **Stale files, assertions intact.** `Setup1 Multi.gcode`, `Test2.gcode`, `Face1.gcode`,
> `Setup1-Face1.gcode` and the Test A–D files predate the provisional `Z0`, the property dump
> and/or the GRBL stop-block prompt. Their *assertions* stand; none matches byte-for-byte.

### Invalidated by landed fixes

Delete a row when its test is re-posted, and delete this section when it empties.

| Rows | What moved | Effect |
|---|---|---|
| every saved GRBL `.gcode` carrying an operator prompt | the `(MSG,` comma | Every `M0 (MSG …)` line gains a comma and nothing else moves. **No row's assertion is affected** — `HB-9`'s criterion anchors on `^(`, and the prompts' text, order and count are unchanged. Delete when **`CR-02`** runs |
| every saved GRBL `.gcode` predating 2026-07-31 | the manual-spindle stop now prompts on GRBL | A default job ends `M0 (MSG Turn OFF spindle)` where it once ended `M5`. **No row's assertions are affected** — do not read a tail diff as a regression |
| the two header-dump rows above | the `groupDefinitions` move, the key rename, then the machine-frame work | The assertions stand — one block per group, in dialog order — but the counts and titles moved. **`D5` closed by walk, so no post refreshes these**; delete when **`REG-MF`** runs |
| every saved `.gcode` posted at `Comment Level` `Info` or `Debug`, and `S2a`/`D5`'s enumerated dump delta | group 5's dialog title, which `writeAllProperties()` prints as its heading | **One line moves in every such file** — ` Properties -- 5 - On WCS / Part / Fixture Changes:` becomes ` Properties -- 5 - Part Origins - how each part's X0 Y0 Z0 is established:`. No g-code, no key, no value. **`S2a`'s claim survives as written and its enumeration does not** — the whole delta is still the property dump; the dump now has one more changed line than `D5` lists. **Byte-identity is not available as a criterion for any re-post at `Info` or `Debug`**; the criterion is *this heading and nothing else* |
| **every saved GRBL `.gcode`, at every comment level** | `CR-01` put a `>>> WARNING:` line at the top of every GRBL file | **Every line number in every GRBL artifact moves by one**, and unlike the row above this one does not depend on `Comment Level` — `writeWarning()` ignores it. No g-code and no value changes, so every assertion stands; what does not survive is any claim of the form *"line N"* or *"the first line"*. `PR-20`'s argument counts lines against gSender's ten and is unaffected — a stop at line 1 is now at line 2, still inside it — but `validateJob()`'s clause was reworded with the fix rather than left to rot |
| `PR-2e`'s artifact | the fixed Z reference stopped being derived — the field itself is now the opt-in | **Stale, not wrong.** The header echo loses its *from the homed machine declaration, not set in the dialog* clause, there being no dialog answer left to distinguish it from. **`PR-5b` closed by walk and no row now schedules this job**; the artifact stands as evidence for `PR-2e`'s own assertion and for nothing about the current echo |

---

## 6. Design backlog

Unbuilt design and the questions that must be answered before it can be built. **Nothing
here is scheduled** — `plan.md` holds the order of work.

### Jet tools & laser — a deferred workstream

Reviewed and tested on their own rather than as sub-checks bolted onto milling rows. Nothing
here blocks the WCS/probe work; all of it blocks a release claiming laser/jet support.

The shared mechanic: `tool.number != 0 && !tool.isJetTool()` is the post's *can this tool
probe?* test, and it gates the probe **and** the Z retract on every origin path — so a jet
tool takes a different branch in `writeWcsOnStart()`, `writeWCS()`, `partProbe()` and
`writeBaseEstablish()`, and those branches are essentially unexercised. Rows **J1**–**J5**.

**`HR-16`'s Z half is still owed here.** `onClose()` traverses to `X0 Y0` before stopping the
spindle with no guaranteed safe Z; the spindle half landed 2026-08-01. For milling the last
operation's own retract covers it; **a jet/laser section that ends at cutting height is not
covered**, and it is the same line of code. Decide it with **J5**.

### Standing decision this section is bounded by

Multi-WCS supports two coexisting per-part workflows: pre-set fixture offsets (Replicate),
and manual per-part via the two `Jog …` modes. One part from **multiple datums on the same
fixture** is supported (`PA1`); a **flip or re-clamp** is out of scope for a single run —
those are separate jobs, and remain future work.

### Unscheduled ideas

None is a defect; none is scheduled.

- **"Copy first part's Z" mode.** Write the first part's probed Z into each added copy's own
  register — a register write, no motion, no probe — for same-thickness co-planar fixtures.
  Requires caching the first part's probed Z. Marlin no-op.
- **WCS `0`/`1` mixed-design warning.** A job using work offset `0` in one section and `1` in
  another resolves both to `G54` but reads as two deliberate fixtures in Fusion's Operations
  panel. The correct rule is any-section-vs-any-other-section.
- **`useZeroOffset` enforcement — open question.** Declared but likely inert: the enforcing
  `validateCommonParameters()` lives in a shared library this post does not import, so
  `writeWCS()` still silently aliases `0`→`1`. **Should the post enforce it itself?**
- **A post-time coolant dialect warning.** `CoolantA()`/`CoolantB()` pass the chosen enum id
  to `writeBlock()` with no firmware check, so a `Mrln:` code posts into a GRBL file. The
  durable fix is a `validateJob()` warning when dialect and firmware disagree — the dialect is
  already in each option's title. `Use custom` is exempt: the post cannot know the dialect.
- **`permittedCommentChars` global.** A comparable community GRBL post declares it; research
  whether it adds real kernel-side filtering on top of `sanitizeMessageText()`.
- **A fourth entry in `Tool Change Handled By`.** UGS is the obvious candidate and is
  **deliberately unlisted**: the post may name a handler only where its interception is sourced,
  and UGS's is not. `Other` covers it meanwhile, at the cost of a one-line file. Adding one is a
  source read, not a design decision.

---

## 7. Owed

1. **Thirteen open findings have no test row** — the twelve open `CR-` ids, filed from
   source walks and never posted against, plus `HR-22`, which never had a row at all.
   Every one owes a row in §4 before it can be closed — the largest
   single gap in this register, and the one place the *every finding resolves to a test row*
   rule is currently unmet. **Two deliberate exceptions**, each stating why in its own row:
   `PR-16` and `HR-26`, which **closed by deletion** and owe no row at all.
2. **Every one of the 34 unrun rows**, and **a posted file behind the twenty-six walked ones.**
   A walk settles what the post writes; it cannot settle what Fusion feeds it or what a
   controller does with the result, and every walked row above names its own residue. **Two
   posts would retire most of that residue at once** — a factory-default job against `S2a`'s
   enumerated dump delta, and a Marlin multi-operation job against `S3f`'s corrected comment
   count, which is the one place a walk found the register's claim wrong.
3. **`J4` first among the jet rows** — group 09 has never appeared in *any* posted file, and
   `CR-10` landed a fix there sight-unseen.
4. **A posted two-tool file.** The tool-change register is written — `TC-1` … `TC-20`, `PR-21a`,
   `PR-22a` — and **not one of them has been run**, because all but two need a full licence. Until
   one is posted, both flows stand on a code walk alone. **`TC-4` first**: it is the only row that
   proves the ordering fix, and the register it names is the difference between a correct part and
   a plunge at the tool-length difference. **`TC-16` is the one row a walk can never reach** — it
   asserts what gSender does with a file the post has already got right.
5. **The one live risk that could still hide a real defect: `HR-6 (B)`.** The orientation
   guard may be a no-op on exactly the case it exists to catch, and the failure mode is a part
   cut in the wrong plane, silently. It needs a rotated Setup.

---

## How to write in this file

**Three rules. If a change to this file broke one of them, the change is wrong.**

1. **Completion shrinks the document.** A finding or test row that closes must end up
   *shorter* than it was while open. If closing it made this file longer, it was written
   wrong.
2. **An open item carries no history.** State the problem, how to reproduce it, and the
   action to take. Not how the project arrived at it, not what an earlier version said, not
   which round found it, not what was rejected on the way.
3. **A closed item is one line** — id, subject, commit ref, plus one clause only where the
   resolution is not obvious. `git show <ref>` holds the diagnosis, the diff and the argument.

**Three mechanical rules.** The state marker is the **last** column of every table. Every
table states its tally above itself. Every finding id resolves to a test row, with a `➖`
pointer row where another row's matrix proves it.

**Running a test.** Post the job from Fusion and read the g-code. **Write the pass criterion
in simple words** — what must be in the file, and what must be absent.

**Closing a finding.**

1. **Read the row before the code.** It states what the fix has to be true of.
2. **Show the diff before applying it** — every time, including one-liners. Count the call
   sites in the code before believing the diff is complete.
3. **Add the test row** to §4: the setup as a delta from §4's standing configuration, what to
   do, and a pass criterion naming the one thing whose presence or absence proves it — often
   an *absence*. Cover **both branches** of any new condition.
4. **Flag what the change invalidates.** Any passed row whose saved `.gcode` no longer matches
   goes in *Invalidated by landed fixes*, deleted row by row as those tests are re-posted.
5. **Move the row from §2 to §3** and collapse it to one line.
6. **Commit** with a message describing the code change and why — never the doc bookkeeping —
   and lead the subject with the id. Check the tallies in the diff; nothing counts them.
