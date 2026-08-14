# Findings — `MPCNC_v4.0_Beta2.cps`

Every logged issue and the tests that confirm it. **61 findings — 36 fixed · 2 part-fixed ·
2 closed by design · 1 withdrawn · 20 open.** Test registers in §4 and §5.

> Four ids — `HR-19`, `HR-22`, `HR-24`, `HR-27` — had **no row in any register** when this
> file was built. They were carried in checkpoint prose and in `conventions.md`, and are
> given rows here for the first time.

> **Thirteen tool-change findings and nine tool-change test rows were deleted 2026-08-13**,
> with the design that made them defects. `design.md` → *Tool changes* is the replacement
> design; `PR-15` is the one finding that survives them. Recover any deleted row with
> `git log -p -- docs/findings.md`.

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

**20 open (one of them deferred) · 2 part-fixed — 22 entries.**

### PR-15 — the tool-change code does not comply with the tool-change design — High

**Problem.** `design.md` → *Tool changes* settles two flows — a manual change at the **end of
a file** that leaves the work origin untouched, and a mid-program **call into the sender's or
the machine's macro** — and the post implements neither. What is there instead performs the
change itself: it parks on WCS-relative fields the dialog presents as absolute, emits `M6` on
a route that works on no supported firmware, emits Marlin-only `M84 Z`, orders the change
ahead of the WCS resolution so a re-probe lands in the previous section's register, and
establishes the first part's Z0 with the tool the first change exists to replace.

**Reproduce.** Not needed and not useful — the non-compliance is structural and reads off the
source. The individual defects were reproducible and are recorded in the deleted rows.

**Fix.** `plan.md` Step 5 — rebuild group 7 as the two flows. **The obligations any
implementation must meet are listed at the foot of `design.md`'s section**; they are what the
deleted rows contained.

**Test.** **None, deliberately.** No row can be written against code that is being replaced;
the rows belong to the rebuild and are written as it lands.

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

### PR-18 — two warnings recommend a "Jog to ..." mode in the same dialog that refuses it — Low

**Problem.** :1482 (`Home at Job Start` meeting a `... to Current Pos` first-part mode) closes with
*"a \"Jog to ...\" mode also works"*, and :1526 (the fixed-Z establish moving the tool before the
origin is recorded) offers *"Use \"Use Active WCS X0 Y0, Probe Z0\" or a \"Jog to ...\" mode"*.
Neither clause is gated on firmware. :1511 **is** — on GRBL it states that a jog mode stalls the job
at an `M0` the operator cannot jog out of. All three fire together on a GRBL job, so **the dialog
tells the operator both to choose a jog mode and that jog modes do not work.** The correct remedy is
already in both messages beside the wrong one.

**Reproduce.** `Multi_WCS (PBV1).gcode`, 2026-08-14 — GRBL, `Axes Homed and Trusted` = `XYZ`,
`Home at Job Start` = `Home`, two work offsets, First = `Set X0 Y0 Z0 to Current Pos`, Subsequent =
`Jog to X0 Y0, Probe Z0`.

**Fix.** **Take it with `plan.md` Step 4**, which deletes both Jog modes from `probeOnStart` and
`probeOnChange` entire — the clauses go with the modes they name and no separate repair is written.
If Step 4 changes shape or is deferred, gate both clauses on `fw != eFirmware.GRBL` instead: the
false statement ships until one or the other lands.

**Test.** `PR-18` in §4 — both branches, GRBL and RepRap.

### HR-13 — `onCommand` silently discards every command it does not name — Low-Med · ◑ part-fixed

**Problem.** **The silence is fixed** — `f54beb0`, 2026-08-13. Every unnamed command now
reaches a `writeWarning()` below the `switch`, so it survives Comment Level `Off`.
**`COMMAND_OPTIONAL_STOP` is still not honoured**: the registered diff proposed `M1`, whose
premise *"`M1` is supported by all three targets"* is true of the parser and false of the
behaviour — GRBL ignores it, RRF ends the job. So *Optional stop* warns instead of
vanishing, and still does nothing.

**Fix.** A dialog decision, not a defect — see §6.

### HR-20 — tapping is not really implemented — Medium · ◑ part-fixed

**Problem.** The manual path prompts (via HR-12); the automatic path always emitted `M4`.

**Fix.** A fuller tapping implementation. **Not tool-change work and waits for none of it** —
it is professional only because tapping was *decided* to be.

### HR-27 — a geometry guard leaves a truncated `.gcode` — Medium

**Problem.** The two *geometry* guards — `currentSection.isMultiAxis()` and
`isSectionOrientationSupported()` — fire in `onSection()`, so a rejected job leaves a
**truncated `.gcode`** rather than a clean refusal. A guard in `onOpen()` writes no file at
all.

**Reproduce.** A multi-axis toolpath, or a Setup built on a model face rather than the stock
top. Post it; a partial `.gcode` is written.

**Fix.** Move both into `validateJob()`'s section loop, which already runs from `onOpen()`
before any output and already walks `getSection(i)`; both guards read only `isMultiAxis()`
and `workPlane`. **Open question:** the orientation guard emits a `Debug` trace on every
path by design, and at `validateJob()` time there is no output stream to write it to.

### HR-19 — `M291` carries a doubled space — Low

**Problem.** A one-liner; changes no output that matters.

### HR-22 — should `gAbsIncModal` / `gUnitModal` / `gFeedModeModal` be reset? — Low

**Problem.** They are formatted once in `Start()`, so a reset would emit nothing later.
Deliberately excluded from `HB-16`'s fix. `CR-21` answers this: the second file in a reused
context loses its whole preamble.

**Fix.** Settle with `CR-21`.

### HR-24 — `writeWCS()` reads the global `tool`, not `section.getTool()` — Low

A one-liner; changes no output.

### CR-01 — GRBL ignores `F` on `G0`, so the group-2 travel speeds do nothing there — Wrong output

**Problem.** `rapidMovementsXY()` / `rapidMovementsZ()` emit `G0 … F<travel speed>`. On
GRBL 1.1 a `G0` runs at `$110`/`$111`/`$112` and the `F` word does not affect it. On the
post's **default** firmware both travel-speed properties change nothing, while the dialog
presents them as *"High speed for Rapid movements"*. Honoured on Marlin and RepRap.

**Reproduce.** `CNC Firmware` = Grbl (the default), any job, travel speeds at any value.

**Fix.** Say which firmware they apply to, in the tooltips or the file.

### CR-02 — `(MSG …)` prompts omit the conventional comma — Cosmetic

**Problem.** `askUser()`'s GRBL arm emits `M0 (MSG Attach ZProbe)`. Senders match on
`(MSG,<text>)` with a comma. GRBL ignores the comment either way, so nothing breaks at the
controller — but a sender that keys on `(MSG,` will not surface the prompt and the operator
sees an unexplained pause.

**Reproduce.** `CNC Firmware` = Grbl, any prompt.

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

**36 fixed · 2 closed by design · 1 withdrawn — 39 rows.** Permanent: commit messages and
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

---

## 4. Open tests

**⬜ 57 UNRUN · ❌ 0 FAIL · ➖ 1 n/a — 58 rows.** **§4.1 is nearly closed** — `PB1`, `PB2`, `PBV1`,
`PBV2`, `PBV3`, `M1`, `M2` and `M4` passed 2026-08-14 and are in §5. **Three of the four boundary
dispatches are proved**; what is left is `PA1`/`PA1b`, the offset variants `P2`/`P3`, and `M3`.
**No row exercises a tool change** — the nine that did were deleted with the design they tested,
and their replacements are written as `plan.md` Step 5 lands.

**The `S2` and `S3` rows are this step's debt** — five for the base's retirement, six for
Marlin gaining the frame and its registers. `S2a` is the one that protects every hobbyist job: with the field
empty nothing changed, and only a posted file can say so.

**Eight rows went with the spoilboard base**, deleted rather than run: `P5`, `P9`, `PR-3`,
`PR-8a`, `PR-16`, `HR-26`, `J3` and `PR-5a` — the last being the enum flip, and there is no
longer an enum to flip.

**Standing configuration.** GRBL, mm, `Comment Level` `Info`, probe target `Z-10`, probe
speed `F30`, probe thickness `Z0.8`. **A row names only what it changes from that line.**
Output goes to `Documents\Fusion 360\NC Programs\`, is not in the repo, and a reused
filename destroys evidence.

`dialog` is a method alongside `posted`: it is settled by opening the Fusion dialog, and no
posted file can show it.

| Test | Proves | Setup (delta) | Method | Expansion | State |
|---|---|---|---|---|---|
| **PA1** | New WCS from a machined face, operator jogs the new datum | two Setups on one clamped part, Subsequent = `Jog to X0 Y0 Z0` | posted | §4.1 | ⬜ |
| **PA1b** | Variant — WCS 2's XY already known, only Z re-references | same job, Subsequent = `Use Active WCS X0 Y0, Probe Z0` | posted | §4.1 | ⬜ |
| **P2** | Nonzero offset, Replicate | 2-part job, probe offsets `10`/`5` | posted | §4.1 | ⬜ |
| **P3** | Zero-offset added-part regression | same 2-part job, offsets `0` | posted | §4.1 | ⬜ |
| **M3** | Boundary dispatch — `Jog to X0 Y0 Z0` | multi-WCS, `Machine Travel Z` filled | posted | §4.1 | ⬜ |
| **M5** | Single-WCS regression — byte-for-byte unchanged | single WCS | posted | §4.1 | ⬜ |
| **M6** | First-part `Use Active WCS X0 Y0 Z0` on a **jet / tool-0** first part — the `X0 Y0` move with **no** Z retract. *The milling half is proved — `PBV2`/`PBV3` §5* | jet tool, then tool 0, first section | posted | §4.1 | ⬜ |
| **H7e** | First-part `Use Active WCS X0 Y0, Probe Z0` on Marlin and RRF | firmware Marlin, then RepRap | posted | — | ⬜ |
| **D1** | Labels, groups and field types | the dialog | dialog | — | ⬜ |
| **D2** | The property dump is suppressed at Comment Level `Important` and `Off` | Comment Level `Important`, then `Off` | posted | — | ⬜ |
| **D3** | A key rename resets that setting **once**, and the new key then holds — now `spoilboardTravelZ` → `machineTravelZ` | a preset saved before the rename | dialog | — | ⬜ |
| **D4** | The groups are still identifiable in the **legacy** Post Process dialog | the legacy dialog | dialog | — | ⬜ |
| **D5** | The header property dump after the group-5 deletion and the 6–11 → 5–10 renumber | defaults, diffed against the pre-change commit | posted | — | ⬜ |
| **P6** | `writeWCS()` debug/info logging | Comment Level `Debug`, then `Info` | posted | — | ⬜ |
| **P7** | `wcsDefinitions` offset-0 decision | work offset `0` | dialog | — | ⬜ |
| **PR-1a** | The capability/action split emits what the old enum did, and nothing when the action is off | group 4 declarations × `Home at Job Start`, GRBL then Marlin | posted | — | ⬜ |
| **PR-1b** | The stored-offset warning fires on the trusting modes and **never** on the `Jog …` modes | 2-WCS job, each origin mode in turn | posted | — | ⬜ |
| **PR-2b** | The first section's arrival emits a real absolute Z instead of the `Unknown Z` comment | multi-WCS, `Machine Travel Z = -12`, First = `Use Active WCS X0 Y0, Probe Z0` | posted | — | ⬜ |
| **PR-2c** | Every guard refuses, and leaves **no file** | each `error()` condition in `validateJob()` | posted | — | ⬜ |
| **PR-2d** | `Machine Travel Z` converts mm → inch in both the block and the header echo | multi-WCS, `Machine Travel Z = -12`, output units **inch** | posted | — | ⬜ |
| **PR-17** | The GRBL machine-Z warning fires at `1` **and at `0`**, and is **silent** at `-10`. **`0` is the row's discriminator** — a `> 0` repair passes it and is wrong | GRBL, 2 WCS, `Machine Travel Z` `1`, then `0`, then `-10` | posted | — | ⬜ |
| **PR-18** | Neither warning offers a "Jog to ..." mode on GRBL, and the jog refusal is the only mention of one; on RepRap the offer survives | GRBL then RepRap, `XYZ` + `Home`, 2 WCS, First = `Set X0 Y0 Z0 to Current Pos` | posted | — | ⬜ |
| **PR-5b** | The header echo names the frame and its height, and says `None` when there is none | `Machine Travel Z` `-12`, then cleared | posted | — | ⬜ |
| **S2a** | **The field is the opt-in, empty branch** — a factory-default single-part job has **no frame**: `grep -c G53` = `0`, `Fixed Z reference = None` in Resolved Values, and no establish block. **The whole file is identical to the pre-Step-2 build apart from the property dump** | all defaults, diffed against `069cc36` | posted | — | ⬜ |
| **S2b** | **The field is the opt-in, filled branch** — a **single-part** job gains the frame, which the offset-count gate used to deny it: an establish `G53 G0 Z<n>` at job start, and a real absolute Z at the first section's arrival where `HB-13`'s *unknown Z* warning used to stand | one WCS, `Axes Homed and Trusted` = `XYZ`, `Machine Travel Z` = `-10`, First = `Use Active WCS X0 Y0, Probe Z0` | posted | — | ⬜ |
| **S2c** | **Guard B refuses a multi-part job on a machine declared not homed**, where reserving a base used to post it — aborts in `onOpen()` with **no file**, naming `Machine Travel Z` and group 4 | 2 WCS, `Axes Homed and Trusted` = `None` | posted | — | ⬜ |
| **S2d** | **Guard B's X/Y half is its own refusal** — a `Z Only` machine with the height filled is refused for the *stored offsets*, not for the frame, and the two messages are distinguishable | 2 WCS, `Axes Homed and Trusted` = `Z Only`, `Machine Travel Z` = `-10` | posted | — | ⬜ |
| **S2e** | **The frame is Z-only** — a **single-part** job on a `Z Only` machine posts *with* the frame, which `S2d` refuses only because it is multi-part | one WCS, `Axes Homed and Trusted` = `Z Only`, `Machine Travel Z` = `-10` | posted | — | ⬜ |
| **S3a** | **Marlin gets the frame, warned in both channels** — a `G53 G0 Z<n>` establish, the `CNC_COORDINATE_SYSTEMS` warning in the Fusion dialog **and** as a `>>> WARNING:` in the file, and the job posts rather than being refused | Marlin, one WCS, `Axes Homed and Trusted` = `XYZ`, `Machine Travel Z` = `-10` | posted | — | ⬜ |
| **S3b** | **Every `G53` on Marlin is followed by a `G5x` re-select**, and it is `currentWorkOffset`'s own — the discriminator is that it is **not** hard-coded `G54` on a job whose active offset is `G55` | as S3a plus a Setup on work offset 2, then the end park with `At End Park At` = `Machine X0 Y0` | posted | — | ⬜ |
| **S3c** | **GRBL emits no re-select** — the same job on GRBL has a bare `G53` block and nothing after it, so the restore is Marlin-only | S3a's job, firmware GRBL | posted | — | ⬜ |
| **S3d** | The unhomed-frame warning now fires on **Marlin as well as RepRap**, and stays **silent on GRBL** | `Machine Travel Z` filled, `Home at Job Start` = `Off`, each firmware in turn | posted | — | ⬜ |
| **S3e** | **A Marlin two-WCS job posts** — `G55` selected at the boundary, a `G53 G0 Z<n>` retract *above* it, and the added part's origin written with `G92` **after** the select, into the register the select made active. **Never posted on Marlin in any form** | Marlin, 2 WCS, `Axes Homed and Trusted` = `XYZ`, `Machine Travel Z` = `-10` | posted | §4.1 | ⬜ |
| **S3f** | **The ordinary Marlin job did not move** — a single-WCS Marlin file emits **no** `G54` at all, so the 24 `HB-Tests/` files re-post byte-identically. The discriminator is the *absence*: a naive select would have added an unknown command to every stock-Marlin hobby file | Marlin, defaults, diffed against the pre-Step-3 build | posted | — | ⬜ |
| **PR-6a** | The machine park emits `G53 G0 X0 Y0` as its own block, X/Y only | GRBL, `XY Only` + `Home`, park `Machine X0 Y0` | posted | — | ⬜ |
| **PR-6b** | The **Marlin** route is `G28 X` / `G28 Y`, and needs no prior homing | Marlin, `XY Only`, `Home at Job Start` = **`Off`**, park `Machine` | posted | — | ⬜ |
| **PR-6c** | The machine park retracts first where a fixed Z reference exists | PR-6a + `Machine Travel Z` filled | posted | — | ⬜ |
| **PR-6d** | `Work` (default) is byte-identical to the old boolean-on behaviour | defaults, diffed against the pre-change build | posted | — | ⬜ |
| **PR-7a** | `Pause, then Home` emits one pause then the homing, and `Home` emits homing with none | GRBL and Marlin, `XYZ`, both non-`Off` answers | posted | — | ⬜ |
| **PR-7b** | Group 4 reads declaration / action / park, and group 1 no longer carries the park | the dialog | dialog | — | ⬜ |
| **PR-8b** | A park with **no** fixed Z reference says in the file that it cannot retract | PR-6a with `Machine Travel Z` left empty | posted | — | ⬜ |
| **PR-9** | The `G53` park block carries the XY travel feedrate | PR-6a, `Travel Speed XY` off its default | posted | — | ⬜ |
| **PR-10** | The fixed-Z establish warns off the two `… to Current Pos` first-part modes | `Machine Travel Z` filled, First = each `Current` mode then each `Jog` mode | posted | — | ⬜ |
| **PR-11** | The GRBL jog warning is silent on a single-WCS job whose *subsequent* mode is a `Jog` mode | one WCS, Subsequent = `Jog to X0 Y0, Probe Z0` | posted | — | ⬜ |
| **PR-13** | The Duet mode string is written once per section-type change, verbatim | `CNC Firmware` = RepRap, a milling job, then milling + laser | posted | — | ⬜ |
| **HR-13** | `onCommand` no longer discards silently, and says so at Comment Level `Off` | Manual NC *Orientate spindle*, then again at Comment Level `Off` | posted | — | ⬜ |
| **HR-20** | Tapping beyond a warning on the manual path | a drill + tap job, automatic spindle | posted | — | ⬜ |
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

### 4.1 Multi-part / multi-fixture — the expected g-code

Every row here needs a 2-copy Replicate job or a two-Setup job; none can be reached from
the single-section jobs on disk. **The largest untested area in the post.**

> **Frame settings note — one frame, and no row varies it.** Two group-4 fields are the whole
> of it: `Axes Homed and Trusted` = `XYZ`, and `Machine Travel Z` as an **absolute machine Z**
> that clears every fixture. Guard B is unconditional (`CR-13`), so **no row here can be posted
> without both** — a multi-part job with the field empty is refused, and that refusal is `S2c`'s
> assertion rather than a row's setup mistake. `Home at Job Start` is free: the declaration is
> the trust assertion (`PR-2f`). **Marlin is no longer excluded** — Guard C is gone, and `S3e` is
> the Marlin row; every other row here stays GRBL unless it says otherwise.

**PB1 is the reference file — it has run** (§5, `Multi_WCS (PB1).gcode`, 2026-08-14), and the
blocks below are transcribed from it rather than predicted. **Every remaining row here diffs
against that artifact**, which is why they are cheap: the frame, the establish and the boundary
retract are identical in all of them, and only the dispatch after the `G55` differs.

**PB1's job.** The one that posted `Multi_WCS.gcode` (2026-08-13 11:59): document
`2.5D Milling - Mounting Plate`, `Setup1`, one `Face1` operation replicated across work
offsets 1–4, tool 171, stock 63.5 mm thick. It already runs `Subsequent WCS / Part` =
`Use Active WCS X0 Y0, Probe Z0` at `Comment Level` `Debug`. **Four copies satisfy a row asking
for two** — three boundaries of the one shape. Two fields change:

| Property (group) | in `Multi_WCS.gcode` | for PB1 |
|---|---|---|
| `Machine Travel Z` (4) | `0` | **an absolute machine Z clearing every fixture** — `-10` on the machine `PR-2a` ran |
| `First WCS / Part` (5) | `Set X0 Y0 to Current Pos, Probe Z0` | **`Use Active WCS X0 Y0, Probe Z0`** — the shipped default records the first origin at bed clearance here (`CR-15`) |

`Axes Homed and Trusted` is already `XYZ` in that job; `Home at Job Start` may be left at
`Home`. **No dialog warning is expected about the probe reach** — the post cannot compute it,
the distance from an absolute travel height down to the stock top not being a number it has.
**That hazard is unchanged, only unwarned:** `G38 Target` must still reach the stock from the
travel height, and it is the operator's to size.

**Job start**, after `G54` and the `START` preamble — no probe, no prompt, no WCS change:

```
( Establish fixed Z reference -- homed machine Z)
(   Move to the travel height in the machine frame -- machine Z -10)
G53 G0 Z-10 F300           (F is "Travel Speed Z"; G53 is its own block, Z only)
```

At the `P1→P2` boundary:

```
(   Retract to the travel height in the machine frame before traverse -- machine Z -10)
G53 G0 Z-10 F300
G55
(   Move to part origin X0 Y0, then probe Z)
G0 X0 Y0 F2500
G10 L20 P2 Z0              (provisional)
M0 (MSG Attach ZProbe)
G38.2 F30 Z-10
G10 L20 P2 Z0.8
```

**Pass:** one `G53 G0 Z` at job start and exactly one per boundary — four in a 4-copy job;
every one is a **bare Z block**, no X/Y word appended; each `G53` precedes its `G55`/`G56`/`G57`
rather than following it; each copy re-probes Z at its stored XY. **Trap: `PR-2a` already
proves the frame and the traverse** on this same job — what PB1 adds, and all it adds, is the
origin-mode dispatch, because `PR-2a` ran with both probe modes at `Skip`.

**PA1** — two Setups is two work offsets, so this job takes the frame like every other row
here. At the `G54→G55` boundary: `G53 G0 Z<travel>` → `G55` → `M0` jog prompt →
`G10 L20 P2 X0 Y0` → `G38.2 F30 Z-10` → `G10 L20 P2 Z0.8`. **Pass:** the retract is the
machine-frame block and it precedes the `G55`; the re-probe writes Z into `P2`, not `P1`.
**PA1b** — `G53 G0 Z<travel>` → `G55` → `G0 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8`, **no jog
prompt**.

**P2** — the **added part** shows `(   Move to probe point = origin + offset X10 Y5, then
probe Z)` → `G0 X10 Y5` → `G38.2` → `G10 L20 P2 Z<thk>`. The offset is **never** applied to
the base probe.
**P3** — each added part emits the bare-origin form (`part origin X0 Y0`), and the first
part still shows no reposition at all.

**M1–M6 — the four subsequent modes.** 2-part Replicate, derived machine frame, tool ≠ 0. On
each added part every mode must **retract to the travel height first, then act** — the retract
is `G53 G0 Z<travel>` in every case, and it is the *same* block in all four, which is what
makes the four rows a dispatch test rather than four frame tests. **Marlin is in scope now** —
Guard C is gone — but is `S3e`'s row rather than a fifth variant here. **M1** retract→`G55`→`G0 X0 Y0`→cutting, no probe.
**M2** retract→`G55`→rapid to `X0 Y0` (+offset)→`G38.2`→`G10 L20 P2 Z`. **M3** retract→`G55`→
jog prompt→`G10 L20 P2 X0 Y0 Z0`→cutting. **M4** retract→`G55`→jog prompt→
`G10 L20 P2 X0 Y0`→`G38.2`→`G10 L20 P2 Z`. **M5** a single-WCS job is byte-for-byte unchanged
— **and it is the row that proves the derivation stays off a one-part job** (`PR-2h`).
**M6** a jet/tool-0 first part emits the `X0 Y0` move but **no** Z retract — the milling half is
`PBV2`/`PBV3`'s artifact.

> **The added-part jog mode writes a provisional `Z0`** — `PBV1` settled it: `G10 L20 P<n> X0 Y0 Z0`
> in one block, not a separate write. **`M4` above is written `X0 Y0` and should read `X0 Y0 Z0`.**
> `M3`'s `Z0` is a different thing — `Jog XYZ` writes all three as the real origin.

---

## 5. Passed tests

**✅ 38 PASS · ❌ 0 FAIL · ➖ 3 n/a — 41 tests in 34 rows** (an `(A)`/`(B)` pair shares a
row). Nineteen rows are hobbyist, posted 2026-08-08 from a build proved identical to
`e5db625`; `PR-2a` was posted 2026-08-13 from the build Step 1.1 ran on; `PR-2e`, `PR-2f`,
`PR-2g`, `PR-2h`, `PR-14a`, `PR-14b`, `PB1`, `PB2`, `M2`, `PBV1`, `PBV2`, `PBV3`, `M1` and `M4`
were posted 2026-08-14 from `c0ceb86`. Every one passed on first read; none was ever marked ❌.

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
| **PBV1** | `Multi_WCS (PBV1).gcode` — **the two dispatches `PB1` does not reach**. First part `Current XYZ`: :489 `G10 L20 P1 X0 Y0 Z0`, with no prompt and no probe before it. Added part `Jog XY & Probe Z`: :880 `G53 G0 Z1 F300` (bare Z, two lines above its `G55` at :882) → :884 `M0 (MSG Jog to X0 Y0 above Z0, probe)` → :888 `G10 L20 P2 X0 Y0 Z0` → :897 `G38.2 F30 Z-10` → :899 `G10 L20 P2 Z0.8`. **It settles §4.1's open decision by evidence** — the added-part jog mode *does* get a provisional `Z0`, folded into the XY write rather than emitted as its own block, :886 saying why; the row's expected `G10 L20 P2 X0 Y0` was the stale half. **Trap: the file's `>>> WARNING:` at :883 is the GRBL jog refusal and is correctly placed**, one line above the `M0` it describes — it is the post-time set beside it that is `PR-18`. **Trap: the row's closing clause is unmeetable** — confirming `G54`/`G55` at the controller needs a controller; the emitted origin writes are the whole of what is proved |
| **PBV2** | `Multi_WCS (PBV2).gcode` — **the first-part `Skip` dispatch is all this adds**: its boundary :879-898 is `PB1`'s (now :205-224 after that row's repost) block for block, `probeOnChange` being `Probe Z` in both — differing only in the travel height and in `PBV2`'s `Debug` comments. :487-489 `(   Use stored work origin; move Z to Safe Z, then to X0 Y0)` → `G0 Z5.08 F300` → `X0 Y0 F2500`, and **no origin write anywhere on the first part**. **Trap: `Skip` is the id of "Use Active WCS X0 Y0 Z0"** (:407, :422), not a do-nothing — the mode moves the tool. **Trap: the `X0 Y0` line carries no `G0` word**, modal from the block above, which is safe on GRBL only — see *Checked and found correct*. **Trap: the row's "no prompts anywhere" is not what the file shows** — `M0 (MSG Attach ZProbe)`/`Detach` at :895/:900 are `probePause = Before & After`, standing configuration, and stand in `PB1`'s expected block too; the criterion means no *jog* prompt, and there is none |
| **PBV3** | `Multi_WCS (PBV3).gcode` — the assertion is an absence: `grep -c G38` = **0** across the whole file. Boundary :880-884 `G53 G0 Z1 F300` → `G55` → `(   Move to this part's stored origin X0 Y0)` → `G0 X0 Y0 F2500` → straight into the cut at :892. First part identical to `PBV2`'s. **Trap: it is sound only where every copy's stock is the setup run's thickness** — the file cannot show that and no warning states it |
| **M1** | Proved by `PBV3`'s artifact: :880-884 **is** M1's block — retract → `G55` → `G0 X0 Y0` → cutting, no probe. **The substitution is `M2`'s** — *Multiple WCS Offsets* rather than *Replicate*, two distinct work offsets being what the dispatch turns on |
| **M4** | Proved by `PBV1`'s artifact: :880-899 **is** M4's block — retract → `G55` → jog prompt → `G10 L20 P2 X0 Y0 Z0` → `G38.2` → `G10 L20 P2 Z0.8`, tool 171. **Trap: the row was written `G10 L20 P2 X0 Y0`** and the emitted block carries the provisional `Z0`; §4.1 is corrected. `M3` is now the one boundary dispatch of the four still unposted |
| **M2** | Proved by `PB1`'s artifact — :896-914 of the first post, :206-222 of the repost that replaced it, the block being the same either way **is** M2's block — retract → `G55` → `G0 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8`, tool 171, no origin write of X/Y. **Trap: the job is *Multiple WCS Offsets*, not *Replicate*,** which the row was written around; two distinct work offsets is what the dispatch turns on, so the substitution holds. **The `+offset` half is `P2`'s** — `Probe XY offset` is `X0 Y0` here |

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
| every saved GRBL `.gcode` predating 2026-07-31 | the manual-spindle stop now prompts on GRBL | A default job ends `M0 (MSG Turn OFF spindle)` where it once ended `M5`. **No row's assertions are affected** — do not read a tail diff as a regression |
| the two header-dump rows above | the `groupDefinitions` move, the key rename, then the machine-frame work | The assertions stand — one block per group, in dialog order — but the counts and titles moved. Delete when **D5** re-posts |
| `PR-2e`'s artifact | the fixed Z reference stopped being derived — the field itself is now the opt-in | **Stale, not wrong.** The header echo loses its *from the homed machine declaration, not set in the dialog* clause, there being no dialog answer left to distinguish it from. Delete when **PR-5b** re-posts |

---

## 6. Design backlog

Unbuilt design and the questions that must be answered before it can be built. **Nothing
here is scheduled** — `plan.md` holds the order of work.

### Tool changes — the questions the design leaves open

**The design is settled and lives in `design.md` → *Tool changes*.** What is unsettled, and
must be answered before Flow 2 can be built:

- **Which token calls the macro.** `M6` is the natural candidate and is a real call on RRF,
  but on GRBL it is `error:20` at the controller, so the route exists only if the *sender*
  intercepts it first. **No firmware source can settle this** — it is a sender-side fact, and
  the first question in this project that firmware reading cannot close.
- **Which senders are in scope**, and whether the contract can be one contract or must be one
  per sender.
- **What the macro is entitled to change**, expressed tightly enough that the post's resume
  step is derivable from it rather than guessed.
- **Whether the park position is one field or two** — Flow 1's end-of-file park and Flow 2's
  pre-macro clearance are the same physical need in two different frames, and the shipped
  single field is what makes them ambiguous today.
- **`includeProbeFile`** (`Tool Change Probe`, group 8) is declared, tooltipped
  `NOT IMPLEMENTED YET`, and never passed to `loadFile()`. Under Flow 2 it is either the hook
  the contract names or it is deleted; it cannot stay as it is.

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
- **Manual NC *Optional stop* — promote it to `M0`, or leave it refused?** `HR-13`'s landed
  half warns that the command was dropped; this is the decision about honouring it. `M1` is
  not available — ignored by GRBL, ends the job on RRF. `M0` pauses on all three, but it makes
  an *optional* stop unconditional. **A dialog question, not a defect.**
- **`permittedCommentChars` global.** A comparable community GRBL post declares it; research
  whether it adds real kernel-side filtering on top of `sanitizeMessageText()`.

---

## 7. Owed

1. **Seventeen open findings have no test row** — the thirteen open `CR-` ids, filed from
   source walks and never posted against, plus `HR-19`, `HR-22`, `HR-24` and `HR-27`, which
   never had rows at all. Every one owes a row in §4 before it can be closed — the largest
   single gap in this register, and the one place the *every finding resolves to a test row*
   rule is currently unmet. **Three deliberate exceptions**, each stating why in its own row:
   `PR-15`, whose code is being replaced, and `PR-16` and `HR-26`, which **closed by deletion**
   and owe no row at all.
2. **Every one of the 57 unrun rows.** §4.1 is the largest untested area in the post and
   needed a job nobody had built. **That blocker is down** — a multi-WCS job was built on
   2026-08-13 from **Multiple WCS Offsets** (one Setup, a checkbox and an instance count) and
   posted three times. Whether it substitutes for rows written around *Replicate*
   specifically is a judgement at the keyboard; what it certainly gives is two distinct work
   offsets, which is what Guard B and most of §4.1 turn on.
3. **`J4` first among the jet rows** — group 09 has never appeared in *any* posted file, and
   `CR-10` landed a fix there sight-unseen.
4. **The whole tool-change test register.** Nine rows went with the old design and none has
   been replaced, so a two-tool job currently has **no** pass criterion of any kind. The rows
   are written as `plan.md` Step 5 lands, not before.
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
