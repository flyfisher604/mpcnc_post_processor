# Coverage findings — `MPCNC_v4.0_Beta2.cps`

The 24 findings of the pre-Beta coverage review, split out of [`CoverageReview.md`](CoverageReview.md) so
they can be tracked as work. The review keeps the method, the story ledger, the walks that produced these
and the record of what was left unwalked; this file holds the findings and their state. Nothing was
re-judged in the move — every finding reads exactly as the review recorded it, with a status box added.

The CR numbers are in discovery order and are **not** renumbered. They are referenced from the walks in
`CoverageReview.md` and are worth more as stable identifiers than as a ranking.

## How the status box works

Each finding carries a status box directly under its heading. Unticked is **open**:

```
**Status:** `[ ] fixed`
```

When a finding is resolved, tick it and name the commit that did it, so the file says where the fix lives:

```
**Status:** `[x] fixed` — a1b2c3d, the retract now resolves in the frame it is emitted in
```

A finding judged not-a-defect after all is **not** ticked — say so in the box and why, so the reasoning
survives the next pass:

```
**Status:** `[ ] fixed` — not a defect: `expandCyclePoint` already covers this, see …
```

The status boxes and this ledger are the only things in the file meant to change. The findings themselves
are the review's record of what the source said on 2026-08-09 and stay as written; a re-walk that changes a
judgement belongs in a later pass of `CoverageReview.md`, not in an edit here.

## Ledger

**24 findings — 3 fixed, 20 open, 1 withdrawn.** Ordered by severity; the bodies below are in CR order.
*wdn.* in the status cell means the finding's own premise was settled against it and it is not a defect —
the box says which premise, and the designed fix, where there was one, stays in `CoverageFixes.md` unapplied
in case that premise is ever contradicted. The row is kept rather than deleted so a re-reader of the review
does not file it a second time.

| Status | Finding | Audience | Severity | Summary |
|---|---|---|---|---|
| `[x]` | CR-11 | Professional | Machine damage | the spoilboard base is probed to a target measured in the frame the probe is establishing |
| `[x]` | CR-13 | Professional | Machine damage | with `Retract Across Parts` off, the inter-part traverse height is resolved in one frame and emitted in another |
| `[x]` | CR-14 | Professional | Machine damage | the base-establish tool-0 skip leaves the job believing a base was established |
| `[ ]` | CR-19 | Both | Machine damage | the `M6` tool-change route stops nothing before the change |
| `[ ]` | CR-21 | Both | Machine damage | `resetPostState()` does not reset the modal formatters, so a second file in one context loses its preamble |
| `[ ]` | CR-03 | Hobbyist | Machine damage | group 3 is not gated to the licence it exists for, and nothing warns |
| `[—]` *wdn.* | CR-04 | Hobbyist | Machine damage | the first-move conversion applies no test of any kind to the destination |
| `[ ]` | CR-12 | Professional | Machine damage | both `Use Active WCS …, Probe Z0` modes measure the probe target from the Z0 they distrust |
| `[ ]` | CR-16 | Professional | Machine damage | one part machined from several WCS is accepted and traverses to an unset register |
| `[ ]` | CR-05 | Both | Machine damage | a start include file leaves `G90`, `G21`/`G20`, `G94` and `G17` unwritten, with no warning |
| `[ ]` | CR-23 | Hobbyist | Machine damage | a Safe-Z expression of `0` is accepted, making every non-negative Z "safe air" |
| `[ ]` | CR-06 | Both | Wrong part | the first part's Z0 is probed before the `Do First Change` tool change |
| `[ ]` | CR-07 | Professional | Wrong part | the post-tool-change re-probe writes Z into the previous section's WCS |
| `[ ]` | CR-17 | Professional | Wrong part | a revisited WCS is re-probed on a surface the job has already cut |
| `[ ]` | CR-15 | Professional | Wrong part | the shipped default `First WCS / Part` is incompatible with every `Fixed Z Reference` |
| `[ ]` | CR-18 | Both | Wrong output | `M6` is not a GRBL command, so the no-relocation tool-change route halts the job |
| `[ ]` | CR-08 | Both | Wrong output | `Disable Z Stepper` emits `M84` on GRBL, which has no such command |
| `[ ]` | CR-10 | Both | Wrong output | parking at machine `X0 Y0` drives back onto the homing switches |
| `[ ]` | CR-01 | Both | Wrong output | GRBL ignores `F` on `G0`, so the group-2 travel speeds do nothing there |
| `[ ]` | CR-09 | Both | Wrong output | commanded spindle control emits `M3`/`M4`/`M5`, which are a build option on Marlin |
| `[ ]` | CR-22 | Both | Wrong output | the four coolant "custom file" properties are not in the include pre-flight |
| `[ ]` | CR-24 | Both | Wrong output | the default channel-B coolant code is behind a default-off GRBL build option |
| `[ ]` | CR-02 | Both | Cosmetic | `(MSG …)` prompts omit the conventional comma |
| `[ ]` | CR-20 | Both | Cosmetic | the tool-change suppression warning has no dialog twin for the single-tool case |

Severity alone does not set the order of work: a `Machine damage` finding that needs a non-default
configuration to reach is less urgent than one that does not. `CoverageReview.md` → *Verification* →
*Release read* names the eight that a Beta would have to resolve or document, and says why the rest can
wait.

---

## The findings

### CR-01 — GRBL ignores `F` on `G0`, so the group-2 travel speeds do nothing there

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl (the default). Any job. `Travel Speed X/Y` /
`Travel Speed Z` at any value.
**Problem:** `rapidMovementsXY()` and `rapidMovementsZ()` emit `G0 … F<travel speed>`. On GRBL 1.1 a `G0`
executes at the per-axis rapid rates `$110`/`$111`/`$112` and the `F` word does not affect it; `F` is
accepted and updates the modal feed, but the rapid runs at the machine's configured rate. So on the post's
default firmware the two travel-speed properties change nothing about how fast the machine moves, while the
dialog presents them as "High speed for Rapid movements". They are honoured on Marlin and RepRap, where `G0`
consumes the feedrate word. Nothing in the tooltips or the file says which firmware they apply to. The `F`
word itself is not harmful — the post tracks the value it emitted, so `fOutput` suppression stays truthful —
but an operator tuning those fields on GRBL is tuning nothing.

### CR-02 — `(MSG …)` prompts omit the conventional comma

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Cosmetic
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl, any prompt — probe attach/detach, spindle, tool change,
homing pause.
**Problem:** `askUser()`'s GRBL arm emits `M0 (MSG Attach ZProbe)`. The convention senders match on is
`(MSG,<text>)` with a comma (LinuxCNC's message comment form, which GRBL-facing senders copy). GRBL itself
ignores the comment either way, so nothing breaks at the controller, but a sender that keys on `(MSG,` will
not surface the prompt and the operator sees an unexplained pause.

### CR-03 — group 3 is not gated to the licence it exists for, and nothing warns

**Status:** `[ ] fixed`
**Audience:** Hobbyist
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** Fusion **Full** licence (real `G0`s reach `onRapid`), `Map G1s -> G0 Rapids` on,
any milling job.
**Problem:** `Map G1s -> G0 Rapids` is documented — in the group title and its own description — as a
recovery for the Personal edition's habit of emitting rapids as cuts. Nothing enforces that. With a Full
licence the property is still read on every `onLinear`, so genuine cutting moves are offered to
`isSafeToRapid()` and any of them whose destination Z is at or above the resolved Safe Z, with Z constant
or XY constant, is re-emitted as `G0` at travel speed. Under a Full licence the conversion can only *add*
rapids Fusion deliberately did not make: a `MOVEMENT_HIGH_FEED` link move, a lead-in or lead-out at the feed
height, or any cut on an operation whose retract/feed level sits at or below the stock top, all become
rapids. There is no `validateJob()` warning and no in-file warning for the combination, so the only signal
is the group's title. Either the group should be inert when real rapids are seen, or the combination should
warn.

### CR-04 — the first-move conversion applies no test of any kind to the destination

**Status:** `[—] fixed` — **withdrawn**: not a defect. Fusion Personal emits no rapids at all, so the
opening motion callback of **every** section is a would-be rapid rendered as a feed move and the conversion
is never applied to a cut. Under a full licence `onLinear()` does carry cuts, and that is CR-03's ground:
its latch stops group 3 converting at the job's first genuine `G0`. The designed fix stays unapplied in
[`CoverageFixes.md` → CR-04](CoverageFixes.md), together with the audit showing that every path which moves
Z before the first cut leaves it at a height the post itself established.
**Audience:** Hobbyist
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Map G1s -> G0 Rapids` on; any section whose first motion callback is `onLinear`.
Reached under the Personal licence on every section, and under a Full licence on any section whose first
emitted move is not a rapid.
**Problem:** `onSection()` sets `forceSectionToStartWithRapid = true`, and `onLinear()` converts the first
move that follows to `onRapid()` on the strength of that flag alone — no Safe-Z test, no comparison against
the current position, no check that the destination is in air. It is the only conversion in the post with no
`isSafeToRapid()` guard. The premise is that a section always opens with a positioning move, which is true
of ordinary Fusion output but is an assumption about the CAM rather than a property of the code: any section
that opens with a cut has that cut emitted as `G0`, which on GRBL runs at `$110`–`$112` rather than at a
feedrate, and `rapidMovements()` will order it Z-last only if the destination is below the tracked current
position. A destination Z test costs nothing here — `isSafeToRapid()` already exists — and would leave the
intended case (a positioning move at or above Safe Z) untouched.

### CR-05 — a start include file leaves `G90`, `G21`/`G20`, `G94` and `G17` unwritten, with no warning

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Start GCode File` naming any file. Any firmware, any job.
**Problem:** `writeFirstSection()` calls `Start()` only when `includeStartFile` is empty; otherwise it calls
`loadFile()` instead. `Start()` is the only place in the post that emits `G90`, `G20`/`G21`, and (on GRBL)
`G94` and `G17` — no other path writes any of them, and `gAbsIncModal` / `gUnitModal` / `gFeedModeModal` are
never reset, so nothing re-asserts them later either. Everything the post emits after that point assumes
absolute positioning and the job's own units: `writeFixedZReference()`'s `G53 G0 Z…`, every `G10 L20`, every
probe target, every coordinate. If the operator's start file omits `G90` or sets the wrong unit, the whole
job is silently interpreted in the wrong mode. The property description says the file replaces the modal
preamble, but the post issues no `writeWarning()` and no `validateJob()` warning, and — unlike a missing
file, which the pre-flight catches — there is no detectable failure at post time. A one-line
`writeWarning()` at the replacement site would put the precondition in the file where the operator reads it.

### CR-06 — the first part's Z0 is probed before the `Do First Change` tool change

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** `Tool Changes are Included` on, `Do First Change` on,
`Probe After Tool Change` **off**, any `First WCS / Part` mode that probes (the default included).
**Problem:** In `onSection()`, `writeFirstSection()` runs at the top of the first section and
`toolChange()` for `Do First Change` runs some twenty lines later. `writeFirstSection()` →
`writeWcsOnStart()` → `partProbe()` → `probeTool()` establishes the part's Z0 with whatever tool is in the
spindle at the start of the job — which is precisely the tool `Do First Change` exists to replace. The tool
is then changed, and the new tool's length differs from the old one's by an amount nobody measured. Every
cut in the job is off by that difference. Turning `Probe After Tool Change` on masks it (the re-probe
rewrites the same WCS, which for the first section is the right one), but the two properties are
independent and nothing ties them together. The fix is ordering: the first change belongs before the
first-part origin work, not after it.

### CR-07 — the post-tool-change re-probe writes Z into the previous section's WCS

**Status:** `[ ] fixed`
**Audience:** Professional
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** Multi-WCS job (J5/J6 shapes), `Tool Changes are Included` on,
`Probe After Tool Change` on, any section that changes both tool and work offset at once — which is the
normal shape of a multi-part multi-tool job, since Fusion orders sections by the operation list.
**Problem:** `onSection()` calls `toolChange()` **before** `writeWCS()`. `toolChange()`'s re-probe goes
`onCommand(COMMAND_TOOL_MEASURE)` → `probeTool()` with `targetWcs` undefined, which resolves to
`currentWorkOffset` — still the *previous* section's offset. So the new tool's Z is written into the
previous part's register with `G10 L20 P<previous>`, overwriting a good origin with a measurement taken over
a different part, while the section that actually needs the new Z0 gets none. With `Include Relocation Code`
on it is worse: the relocation rapid moved the tool to `Tool Change X/Y/Z` in the previous part's frame, so
the probe touches off there. `probeTool()`'s post-probe retract uses `probeSafeZ()`, resolved from the
*current* section, emitted in the previous section's frame — a second frame mismatch in the same block
sequence.

The same off-by-one reaches Guard A. `baseOriginWriteReason()` tests `reprobe && toolChanged && wo == base`
using section `i`'s own work offset, but the write lands in section `i-1`'s. The guard therefore misses the
case it exists for (previous section on the base, current section not) and refuses a case that is safe
(current section on the base, previous not). Fixing the ordering fixes the guard; leaving the ordering and
fixing only the guard would encode the defect.

### CR-08 — `Disable Z Stepper` emits `M84` on GRBL, which has no such command

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl, `Tool Changes are Included` on,
`Include Relocation Code` on, `Disable Z Stepper` on.
**Problem:** `toolChange()` emits `M84 Z` with no firmware test, unlike every other `M84` in the post
(`Start()`'s `M84 S0` and `onClose()`'s `M84 S60` are both inside non-GRBL arms). GRBL 1.1's supported
M-codes are `M0`, `M1`, `M2`, `M30`, `M3`, `M4`, `M5`, `M7`, `M8`, `M9`, `M56`; `M84` is not among them and
reaches `error:20 Unsupported command`, which halts the program mid tool change with the spindle stopped and
the operator holding a tool. The property is reachable from the dialog on GRBL with nothing to indicate it
is Marlin/RepRap-only. Either gate the emission on firmware, or say so in the property description.

### CR-09 — commanded spindle control emits `M3`/`M4`/`M5`, which are a build option on Marlin

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Marlin, `Manual Spindle On/Off` **off**.
**Problem:** `spindleOn()`/`spindleOff()` emit `M3 S<n>` / `M4 S<n>` / `M5` on every firmware. On Marlin
those codes exist only when the firmware was compiled with `SPINDLE_FEATURE` (or `LASER_FEATURE`) enabled in
`Configuration_adv.h`, and both ship disabled. On a stock Marlin CNC build the codes reach
`unknown_command_warning()` — Marlin warns and continues rather than halting, so the job runs to completion
with the spindle never commanded on, which is the quiet failure rather than the loud one. This is the same
class of fact the post already documents for `G38.2` (`G38_PROBE_TARGET`), `G53` (`CNC_COORDINATE_SYSTEMS`)
and `G17` (`CNC_WORKSPACE_PLANES`), and it belongs beside them in the property description.

### CR-10 — parking at machine `X0 Y0` drives back onto the homing switches

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl or RepRap, `Axes Homed and Trusted` includes X/Y,
`Home at Job Start` = Home or Pause then Home, `At End Park At` = `Machine X0 Y0`.
**Problem:** `writeMachineParkXY()` emits `G53 G0 X0 Y0 F<travel>` as the last motion of the job. On a stock
GRBL build `HOMING_FORCE_SET_ORIGIN` is disabled (`grbl/config.h`), so machine zero sits **at the homing
switch trigger point** and the machine rests `$27` (homing pull-off) away from it after `$H`. `G53 G0 X0 Y0`
therefore drives X and Y back into the switches. With hard limits enabled (`$21=1`) that raises a hard-limit
alarm, which on GRBL means the controller enters `Alarm` and the program ends in an error state rather than
parked; with them disabled the axes press against the switches until the move ends. The property description
calls machine X0 Y0 "the machine's own homing corner — one park point for every job", which is true of the
coordinate and misleading about what happens when you go there. A park at the pull-off distance, or at a
small documented inset, is the ordinary way this is done. The Marlin route is unaffected: it re-homes rather
than rapids, so it ends at the pull-off position by construction.

### CR-11 — the spoilboard base is probed to a target measured in the frame the probe is establishing

**Status:** `[x] fixed` — c319e69, a provisional Z0 makes the target relative and the base probe gets its
own reach; walked in [`CoverageFixes.md` → CR-11](CoverageFixes.md)
**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Fixed Z Reference` = Spoilboard with any `Reserved WCS`; any firmware that runs
it (Grbl or RepRap); any `Probe to Set Base` mode.
**Problem:** `writeBaseEstablish()` transit-selects the base WCS and calls `probeTool()`, which emits
`G38.2 F<speed> Z<G38 Target>`. `G38 Target` is a **position in the active frame**, and the active frame here
is the base WCS whose Z0 this probe exists to establish — so the target is measured from a register holding
whatever a previous job, a manual touch-off or a power-on left in it. Nothing writes a provisional Z0 first.
Compare `writeWcsOnStart()`'s `Current XY & Probe Z` arm, which writes `G10 L20 P<n> X0 Y0 Z0` immediately
before probing with the comment "so the probe target is a relative limit" — that is the mechanism that turns
`-10` into "search 10 mm down from here", and the base establish is the one probe in the post that does not
have it. The two failure directions are both real: a stale base Z0 that reads high turns `-10` into a plunge
of arbitrary depth at probing speed, and one that reads low puts the target *above* the current position, so
`G38.2` moves up, never touches, and ends in a GRBL alarm. Writing a provisional `G10 L20 P<base> Z0` before
the `G38.2` would make the target a relative limit here as it is everywhere else.

### CR-12 — both `Use Active WCS …, Probe Z0` modes measure the probe target from the Z0 they distrust

**Status:** `[ ] fixed`
**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, or `Subsequent WCS / Part` =
`Use Active WCS X0 Y0, Probe Z0` on a multi-WCS job. Grbl or RepRap.
**Problem:** The same mechanism as CR-11 on the part probes. `partProbe()` → `probeTool()` emits
`G38.2 … Z<G38 Target>` in the part's own WCS, and these two modes exist precisely because that WCS's stored
Z0 is not trusted — the `probeG38Target` description says so outright ("measured from that WCS's STORED Z
zero instead, which may be anywhere"). The consequence is that the one property whose job is to bound the
probe's travel does not bound it on these paths. For the first part `validateJob()` at least warns
(`startMode == "Probe Z" && !fixedZEstablishedInFile()`), and that warning names the problem. For the
**subsequent-part** path there is no warning at all: neither `validateJob()` nor `writeWCS()` says anything,
and the stored-offset warning that does exist is about X/Y and is suppressed as soon as X/Y is declared
homed. This is separated from CR-11 because here the operator has alternatives in the dialog; at the base
establish they have none.

### CR-13 — with `Retract Across Parts` off, the inter-part traverse height is resolved in one frame and emitted in another

**Status:** `[x] fixed` — fbd1591, the control is removed and Guard B is unconditional, so the arm this
finding names is unreachable; walked in [`CoverageFixes.md` → CR-13](CoverageFixes.md)
**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** Multi-WCS job, `Retract Across Parts` **off** (which is also the only way to post a
multi-WCS job with `Fixed Z Reference` = None, Guard B refusing the alternative). Grbl or RepRap.
**Problem:** With `spoilboardSafeZAcrossWcs` off, `crossPart` is false, so `writeWCS()` skips both the
machine-frame and base-relative routes and falls into its bare `isTraverse` arm: `resetAll()`,
`rapidMovementsZ(probeSafeZ())`, `flushMotions()`. Two things are wrong with that height. It is resolved
from `currentSection` — the section being *entered* — through `probeSafeZ()` → `resolveSafeZHeight(…,
currentSection)`, so it is the new operation's retract level; and it is emitted **before** the WCS select,
so it is interpreted in the **previous** part's frame. The tool then traverses to the next part at
`previous part's Z0 + new operation's retract height`, a number that belongs to neither part. On parts of
differing thickness, or with differing retract levels, that height can be below the next part's stock top or
below a clamp. Guard B refuses this configuration when `Retract Across Parts` is on, which is the setting
that *asks* for cross-part safety; turning the safety feature off silently enables the unsafe traverse
rather than suppressing the traverse. Nothing warns.

### CR-14 — the base-establish tool-0 skip leaves the job believing a base was established

**Status:** `[x] fixed` — 348e35a, the predicate now asks whether the probe can run and a second guard
refuses the multi-WCS form; walked in [`CoverageFixes.md` → CR-14](CoverageFixes.md)
**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Fixed Z Reference` = Spoilboard with a `Reserved WCS`, on Grbl or RepRap, where
the first section's tool number is 0 (or a jet tool).
**Problem:** `writeBaseEstablish()` wraps its whole probe sequence in `if (tool.number != 0 &&
!tool.isJetTool())` and takes an `else` branch that writes only a Debug comment — no probe, no
`G10 L20 P<base>`, and no warning at any comment level. Meanwhile `fixedZEstablishedInFile()` asks only the
dialog and the firmware, so it goes on returning true. Every consumer of that predicate is then wrong at
once: `retractThroughBaseClearance()` emits `G0 Z<Inter Part Travel Z>` into a base register nobody set;
`partProbe()` suppresses its "no Z reference is established" warning; `parkCanRetract()` reports that the
end-of-job park can retract, and `validateJob()`'s matching warning stays silent. Every one of those is an
absolute Z move into an unestablished frame — the exact failure I1 exists to catch. The skip itself is
right; its silence is not, and the predicate should reflect what was actually emitted.

### CR-15 — the shipped default `First WCS / Part` is incompatible with every `Fixed Z Reference`

**Status:** `[ ] fixed`
**Audience:** Professional
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** `Fixed Z Reference` = Spoilboard or Machine Z (i.e. any multi-part job — the whole
reason group 5 exists), `First WCS / Part` left at its default `Set X0 Y0 to Current Pos, Probe Z0`.
**Problem:** Establishing the fixed Z reference is step 5 of `writeFirstSection()` and it *moves the tool* —
to `Inter Part Travel Z` above the base, or to the machine travel height. `writeWcsOnStart()` is step 6, and
the two `Set … to Current Pos` modes record wherever the tool now is. So the first part's origin is recorded
at bed clearance and the `G38.2` that follows searches `G38 Target` below bed clearance and never reaches the
stock. `validateJob()` warns about exactly this, so guard fidelity is intact — but the warning fires on the
**default** value of `First WCS / Part` for every job that sets a fixed Z reference at all, which means the
two groups the professional workflow needs cannot both be left in a working state without changing a control
in a third. That is a defaults problem rather than a logic one, and it is worth fixing in the defaults or in
group 5's description, which currently sends the operator to group 6 for nothing.

### CR-16 — one part machined from several WCS is accepted and traverses to an unset register

**Status:** `[ ] fixed`
**Audience:** Professional
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** A single physical part whose operations are assigned to different work offsets
(J3). Grbl or RepRap; X/Y declared homed, so the stored-offset warning is suppressed.
**Problem:** Both `First WCS / Part` and `Subsequent WCS / Part` say in their descriptions that one part from
multiple datums, or a flip, must be run as separate jobs. Nothing in the code checks it, and the post cannot
tell J3 from J4 — a WCS change is a WCS change. So a J3 job posts, and on the first traverse `writeWCS()`
rapids to the *stored* X0 Y0 of a register the operator never set (`Skip`), or probes there (`Probe Z`),
which on a machine whose G55 register holds a leftover or a zero means a rapid to somewhere else on the bed
followed by a probe into whatever is under it. The one partial protection is `validateJob()`'s stored-offset
warning, which fires only when X/Y is **not** declared homed — so declaring the machine's endstops removes
the only signal. This is the gap J3 exists to characterise: the guidance is real, it is in the right place,
and it is entirely advisory.

### CR-17 — a revisited WCS is re-probed on a surface the job has already cut

**Status:** `[ ] fixed`
**Audience:** Professional
**Severity:** Wrong part
**Confidence:** Certain
**Conditions to repeat:** A job that returns to a work offset it has already used — rough every part then
finish every part, G54 → G55 → G54 (J6) — with `Subsequent WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`
(the default). Grbl or RepRap.
**Problem:** `writeWCS()` suppresses only a *repeat* of the currently active offset, so a return to an
earlier one is a full traverse and takes the `probeOnChange` dispatch. With the default mode that means a
second `G38.2` into a register that already holds a good, job-established Z0 — and the touch point is the
part origin plus `Probe X/Y Offset`, which after the roughing pass may be a machined pocket floor, a cut-away
region, or air. The re-probe then overwrites the correct Z0 with a wrong one and every finishing cut is
displaced by the roughing depth at that point. Nothing detects that the WCS was established earlier in this
same file, although `currentWorkOffset` history is exactly the information needed: a WCS this job has already
probed does not need probing again. Sequencing a multi-part job to save tool changes is ordinary shop
practice, so this is not an exotic shape.

### CR-18 — `M6` is not a GRBL command, so the no-relocation tool-change route halts the job

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl (the default), `Tool Changes are Included` on,
`Include Relocation Code` **off**, a job with more than one tool.
**Problem:** `toolChange()`'s else-branch emits `M6 T<n>`. GRBL 1.1's M-code set is `M0`, `M1`, `M2`, `M30`,
`M3`, `M4`, `M5`, `M7`, `M8`, `M9`, `M56` — `M6` is absent and returns `error:20 Unsupported command`, which
stops the program. (`T` alone is parsed and ignored, so the tool word is harmless.) On Marlin `M6` exists
only in builds with tool-change support compiled in and otherwise warns and continues, and on RepRap it is
a real tool change that will try to run `tfree`/`tpre`/`tpost` macros the operator has not written. So this
route works on none of the three firmwares as a manual-tool-change prompt. `Include Relocation Code` off is
the shipped default, which makes this the configuration a first-time operator reaches by simply turning tool
changes on.

### CR-19 — the `M6` tool-change route stops nothing before the change

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Tool Changes are Included` on, `Include Relocation Code` off, any firmware, a job
with more than one tool.
**Problem:** The relocation branch of `toolChange()` moves the tool clear, then calls
`onCommand(COMMAND_COOLANT_OFF)` and `onCommand(COMMAND_STOP_SPINDLE)` before prompting. The else-branch does
none of it: it emits `M6 T<n>` and nothing else. Coolant keeps running, the spindle keeps turning (or, under
`Manual Spindle On/Off`, the operator is never asked to switch the router off), and the tool is wherever the
last cut left it — in the material. Whatever the controller does with the `M6`, the state the post hands the
operator to change a tool in is unsafe. The coolant/spindle stop is not a property of the relocation feature
and belongs on both routes.

### CR-20 — the tool-change suppression warning has no dialog twin for the single-tool case

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Cosmetic
**Confidence:** Certain
**Conditions to repeat:** `Tool Changes are Included` **off**, `Do First Change` on, a job using exactly one
tool.
**Problem:** `onSection()` calls `toolChange()` for the first section whenever `Do First Change` is on,
regardless of `Tool Changes are Included`, so the in-file `writeWarning()` fires. `validateJob()`'s twin is
gated on `countDistinctTools() > 1` and stays silent, so the operator sees nothing at post time and finds
the warning only by reading the file. The two are otherwise a matched pair; this is the one input where they
disagree.

### CR-21 — `resetPostState()` does not reset the modal formatters, so a second file in one context loses its preamble

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Machine damage
**Confidence:** API-assumption
**Conditions to repeat:** Two or more NC files posted from one Fusion invocation where the post's JavaScript
context is reused — the case `resetPostState()`'s own comment says the post does not rely on avoiding.
**Problem:** `resetPostState()` resets every mutable value global and `gPlaneModal`, and `onOpen()` rebuilds
`gMotionModal` and `fOutput` on both branches precisely so neither leaks. Three modal formatters and seven
variables are left out: `gAbsIncModal`, `gUnitModal`, `gFeedModeModal`, and `xOutput`/`yOutput`/`zOutput`/
`sOutput`/`iOutput`/`jOutput`/`kOutput`. The consequence in the second file is that `Start()`'s
`gAbsIncModal.format(90)`, `gUnitModal.format(unit == IN ? 20 : 21)` and `gFeedModeModal.format(94)` all find
the modal already holding those values and emit **nothing** — so file two has no `G90`, no `G21`/`G20` and no
`G94`, and every absolute coordinate, `G53` move and probe target in it depends on the controller still being
in the mode file one left it in. The coordinate variables are the milder half of the same leak: file two's
first move can have an axis word suppressed because file one ended at that value. `sOutput` is
`force: true` so it is immune; `gPlaneModal` was singled out for reset with a comment explaining exactly this
failure mode, which is the tell that the other three were an oversight rather than a decision.
A related consequence, since the formats are built at load time from `unit`: two files with different output
units would share the first one's decimal places. Marked API-assumption only because whether Fusion reuses
the context is not verifiable from the source here; if it never does, the whole of `resetPostState()` is
unnecessary, and the code is written on the opposite assumption.

### CR-22 — the four coolant "custom file" properties are not in the include pre-flight

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong output
**Confidence:** Certain
**Conditions to repeat:** Any `Turn Channel A/B On/Off` set to `Use custom` with a custom-file property
naming a file that is not in the NC output folder.
**Problem:** `validateJob()`'s pre-flight checks `includeStartFile`, `includeStopFile` and — when tool
changes are on — the two tool-change files, and refuses the post before any output when one is missing. The
comment above it states the reason: a missing file otherwise only reaches `error()` inside `loadFile()`, by
which point the header and preamble are already in the stream. `coolantChannelAOnCustom`,
`coolantChannelAOffCustom`, `coolantChannelBOnCustom` and `coolantChannelBOffCustom` are read through the
same `loadFile()` and are absent from the pre-flight list, so exactly that late failure is what they get —
and the coolant-off files fail at `onClose()`, after the whole job has been written. They should be added to
the list under the same condition that makes them reachable (their channel set to `Use custom`).

### CR-23 — a Safe-Z expression of `0` is accepted, making every non-negative Z "safe air"

**Status:** `[ ] fixed`
**Audience:** Hobbyist
**Severity:** Machine damage
**Confidence:** Certain
**Conditions to repeat:** `Map G1s -> G0 Rapids` on with `Safe Z to Rapid` set to `0` (or `Feed:0`,
`Retract:0`, `Clearance:0` on an operation with no absolute level).
**Problem:** `parseSafeZExpr()`'s CONST regex `/^\d+\.?\d*$/` matches `0`, so `safeZHeightDefault` becomes 0
and `isSafeToRapid()`'s `zr >= safeZHeight` is true for every Z at or above the stock top — including a cut
at exactly Z0, a skim pass, and the whole of a 2D engraving at zero depth. Those moves are then re-emitted as
`G0` at travel speed. `validateJob()`'s Safe-Z warning fires only on the ERROR arm, so `0` posts silently.
`0` is a plausible thing for an operator to type meaning "no restriction", and it produces exactly that with
the sign reversed. The same applies to `probeSafeZ` = `0`, where the post-probe retract becomes a move to the
stock top rather than clear of it. A lower bound on the accepted value, or a warning at zero, would close
it — the parser already rejects negatives.

### CR-24 — the default channel-B coolant code is behind a default-off GRBL build option

**Status:** `[ ] fixed`
**Audience:** Both
**Severity:** Wrong output
**Confidence:** Firmware-assumption
**Conditions to repeat:** `CNC Firmware` = Grbl, `Channel B Mode` set to any coolant a tool in the job
requests, `Turn Channel B On` left at its default `Grbl: M7 (mist)`.
**Problem:** `M7` (mist coolant) is compiled into GRBL 1.1 only when `ENABLE_M7` is uncommented in
`grbl/config.h`, and it ships commented out. On a stock build `M7` returns `error:20` and halts the job, in
the middle of a section, with the tool in the cut. The property's own title advertises it as the GRBL code
and the description says "The default is the Grbl code" — which is true of the dialect and not of the
default build. `M8` and `M9`, the channel-A defaults, are unconditional and fine. Channel B is off by default
(`Channel B Mode` = Off) so the code is not emitted until the operator configures the channel, which is why
this is not more severe — but the operator configuring it is following the dialog's own guidance.
