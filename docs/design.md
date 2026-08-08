# Design — why the shipped behaviour is what it is

The **why** behind `MPCNC_v4.0_Beta2.cps`, for the parts of it the code cannot state: the frame model the
rest of the record reads against, the external firmware facts each decision rests on, and the arguments
behind orderings that look arbitrary in the source.

Unlike `conventions.md`, this file **grows with the post** — a change to what the post emits may earn a
paragraph here. Two tests gate the entry and both are in `conventions.md` → *Document contracts*: the fact
must be one the code cannot state, and it must be either **the model** or **a trap**. A design choice that
is merely true stays in the code, and several hundred of them do.

---

## Frames — *the model; every other section reads against this one*

Production controls keep three references separate: **MCS** (`G53`), **WCS** (`G54`–`G59`, `G59.1`–`G59.3`
on RepRap), and **TLO** (`G43`). Most V1E machines have none fully, hence the work-relative stance. **There
is no tool-length system at all** — no TLO, no tool setter — so a work-Z re-probe after each tool change is
the substitute, and **X/Y is never probed**.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to that WCS's own
  register. `P` maps 1:1 to Fusion's `workOffset` (P1–P6 = G54–G59; P7–P9 = G59.1–G59.3, RepRap only).
- **Marlin is single-frame:** no per-WCS registers, so one global `G92` origin. A Marlin job using more
  than one distinct work offset is a hard error (Guard C).
- **`workOffset 0`** is Fusion's "default / unset", **not** a request for `G53`; it aliases to WCS 1 /
  `G54`, and must alias identically everywhere, or two paths disagree about which frame a section is in.
- Undefendable by any post: an operator typing `G55` into the console *mid-run*. Out of scope.

### Selection is deterministic, origin is trusted

**The post commands a frame and can never read back where it is** — register contents are controller-side
runtime state and there is no query. So it always knows *which* frame is active, and never *where*.

**It asserts the WCS selection and never inherits it**, which justifies `writeFirstSection()`'s ordering:
Fusion always supplies a work offset per section, so there is always a design-time answer, and
`currentWorkOffset` is **not** machine state — `onOpen()` sets it `undefined`, so the suppression cannot
match on the first section, section 1 **unconditionally emits its select** over whatever the sender left
modal, and thereafter the post alone changes the selection. Hence `writeWCS()` before `Start()`, the
fixed-Z establish and `writeWcsOnStart()`.

Everything unreadable is therefore a **trust assertion**, and there are two: **a stored WCS origin** (every
`Use Active WCS` mode — which is why the *defaults* establish an origin rather than rely on one) and **a
declared machine frame** (the group-4 declarations, the same species).

**Homing does not change a WCS — it makes one trustworthy.** `G54`–`G59` hold offsets from machine zero and
`$H` never touches those registers. Unhomed, machine zero is wherever the controller was last reset — still
fixed for *that* power cycle, so origins **created** during a run stay mutually consistent and a no-endstop
multi-part job is sound. Only a **stored** offset goes bad, which is the whole of why that guard is
mode-sensitive rather than blanket.

**The one place a trust assertion is not enough:** when a declared frame becomes the **datum for an
absolute move**, the job must *establish* it — so `Fixed Z Reference = Machine Z` requires `Home at Job
Start`, not merely the declaration. Firmware forces it: with homing enabled **GRBL comes up in Alarm and
refuses all motion until homed**, so a stale declared frame cannot execute there, while Marlin and RRF have
no such lock and run the move against a machine zero that has moved.

### The machine frame — capability, then action

`Axes Homed and Trusted` — `None` / `XY Only` / `Z Only` / `XYZ` — is a **fact about the machine**;
`Home at Job Start` is **a decision about this job**. Separating them expresses a state the old
`Home Before Start` enum could not: *homed at the controller, do not home here*.

**One enum, two predicates.** The declaration is one dialog control because the operator declares a
machine, and its four answers are exactly the four combinations of two independent axis facts. The code
never reads it directly: `machineHomesXY()` and `machineHomesZ()` are the only accessors, because the
machine-Z datum needs Z and the stored-offset warning needs X/Y, and **neither implies the other** — an
`== "XYZ"` test anywhere would silently exclude `XY Only` and `Z Only`.

> **Superseded, kept because both are plausible wrong answers.** (1) The old `None`/`XY`/`XYZ`
> `Home Before Start` enum conflated the capability with the action, had no way to say *Z only*, and its
> `XYZ` answer emitted `G28 Z` and then threw away the fact that the machine *has* a homed Z. (2) The two
> booleans that replaced it — `X/Y Home` + `Machine Z Home` — carried the right information but asked the
> operator two questions about one machine and let the dialog express the pair as unrelated. The current
> enum is information-identical to the booleans and is **not** a return to the first form: it declares
> capability only, and the action stays separate.

| Firmware | What the post can emit |
|---|---|
| Marlin / RRF | `G28 X` / `G28 Y` / `G28 Z` — genuinely independent per axis |
| GRBL | one `$H`. Which axes it homes is **compile-time** (`HOMING_CYCLE_0/1/2`, default Z then X\|Y) and `$HX`/`$HY`/`$HZ` sit behind `HOMING_SINGLE_AXIS_COMMANDS`, **off by default** |
| FluidNC | single-axis homing is a **configuration** option, so `$HX`/`$HZ` need no rebuild |

So **on GRBL the split is bookkeeping, not emission** — the post can neither emit per-axis homing nor
corroborate the declaration. FluidNC could, and this post treats FluidNC as GRBL throughout: the one place
that conflation costs something real. **The action is one enum, `Home at Job Start` = `Off` / `Home` /
`Pause, then Home`**, and its pause is **one stop before any homing motion**, whatever the firmware and
axes; the post does not control homing order. That pause was a second boolean until it was folded in —
unlike the axis declaration, **this merge deleted a state rather than renaming one**: "prompt" was inert
whenever homing was off, so two booleans offered four settings of which only three did anything. **`$H` uses `writeln()`, not
`writeBlock()`** — GRBL recognises `$` only as the line's first character (CR-1).

### The fixed Z reference — one concept, two implementations

A frame whose Z0 does not move with stock thickness — the only frame in which one clearance height is
meaningful across parts of differing thickness, which is why the cross-part safe-Z feature requires one
(Guard B). A machine can have one two ways, and they are one dialog question:

| Answer | The frame | `Inter Part Travel Z` is then… | Costs |
|---|---|---|---|
| **Spoilboard** | a probed surface in a reserved WCS | a height **above that surface** — positive | one WCS register — GRBL has six — plus a probe cycle |
| **Machine Z** | the machine's own homed Z | an **absolute machine coordinate** — signed | a per-machine number read off a DRO |

**One clearance field, not two.** The two answers are never both live, they are read at the same two
moments (the establish in the preamble, and each cross-WCS traverse), and on a correct setup they name the
*same physical plane* — so they are one control, `Inter Part Travel Z`, and this enum says which frame it
is measured in. What that costs is a hazard the two separate fields made impossible: **the enum flip**. A
height valid in the other frame is still a valid-looking height, and only one direction is detectable —
a spoilboard clearance is measured *up* from the probed surface, so `<= 0` cannot be one and is guarded,
while a spoilboard `40` left in a machine-Z job is indistinguishable from a real height on a bed-zeroed
machine. Three things carry that risk: the field **ships empty and is guarded under both answers**, so an
untouched dialog cannot post; the header echo **names the frame** beside the number; and both tooltips say
the frame is decided elsewhere.

**Why it is a parsed string and not a number.** Under the spoilboard answer a number would do — `0` is
meaningless there, so it could have served as *unset*, which is what the old whole-mm integer relied on.
The machine-Z answer has no such spare value: every signed number is a real reachable height, `0` very
much included (on a stock GRBL build the machine zeroes into negative space, so `Z0` is the *top of
travel*). Fusion's schema gives a numeric property no unset state, so *empty* is only expressible on a
string — and once the field is shared, the stricter of the two requirements wins.

> **Rejected: exposing only the spoilboard** — the shipped design, which *rejected* multi-WCS jobs on
> machines whose homed Z would have served, Guard B refusing for want of a base while the operator had
> already declared the machine homes Z and the post had discarded the fact.
> **Rejected: giving the base an XY origin.** The base stays a Z-only reference.

**Spoilboard — the base probe emits no XY move, so the park position is an operator precondition**, and
that is why the probe XY offset never applies to it: the establish runs before any origin exists, so no XY
target could be trusted. The consequence is real and silent — **whatever is under the tool becomes the
base's Z0**, so parking over the stock records the stock top as "the spoilboard" and every clearance from
it is short by the stock thickness. **Mitigation is documentation, not code**; the durable fix is unbuilt,
in `PReview.md` §6. Ignored on Marlin (warned), which has no registers to reserve.

**Machine Z — one absolute height, collected, never derived.** A height read off the DRO *after* homing is
already in the controller's own frame, which is what makes it immune to everything below. Units are not: a
`G53` move is read in the active `G20`/`G21` and GRBL's `$13` can report position in inches — hence the mm
contract and the header echo. And **transplant, not typing, is its hazard with no precedent here**: every
other dangerous height in the dialog is WCS-relative and self-correcting, still measured from whatever
machine it lands on, while this is the post's only absolute machine coordinate and therefore the first
number a copied Setup or a shared design makes **wrong** rather than merely different.

> **Rejected: an enum naming where the Z switch sits** (top of travel / at the bed). It cannot pin the sign
> it exists to pin: switch position and the machine value assigned there are independent, and on GRBL the
> second is not even a runtime choice — `HOMING_FORCE_SET_ORIGIN` (`grbl/config.h`) exists to *"force Grbl
> to always set the machine origin at the homed location despite switch orientation"*, and at its default
> Grbl zeroes into negative space whatever the switch orientation. Compile-time, so no `$` query exposes
> it. (Marlin: `Z_HOME_DIR` + `Z_MIN_POS`/`Z_MAX_POS`.)
> **Rejected: any reference + delta pair** (`Spoilboard Machine Z`, or `Machine Z at Home`, plus a signed
> offset) — a sum the operator computes and trusts, where one field is a height they jogged to and *saw*
> clear. The second also shows the delta cannot hold one meaning: on a top-of-travel machine its best value
> is zero, on a plate-at-the-bed machine it *is* the spoilboard clearance.

## Firmware capabilities

Settled by reading each firmware's own source and changelog rather than by testing on a machine. Cite the
file and version when adding here.

- Marlin — `MarlinFirmware/Marlin`, `Marlin/src/gcode/gcode.h` + `gcode.cpp`
- RepRapFirmware — `Duet3D/RepRapFirmware`, `src/GCodes/GCodes2.cpp`, plus the RRF wiki changelog
- GRBL — `gnea/grbl` wiki; FluidNC — `wiki.fluidnc.com`

**No supported firmware has canned drilling cycles**, so `onCyclePoint()` expanding drill/peck/bore/tap
into plain `G0`/`G1`/`G4` is correct and needs no revisiting.

| Firmware | Canned drilling cycles? |
|---|---|
| **GRBL 1.1 / FluidNC** | **No** — deliberately omitted. The supported set is G0–G3, G4, G10 L2/L20, G17–G19, G20/G21, G28/G30(.1), G38.2–G38.5, G40, G43.1, G49, G53, G54–G59, G61, G80, G90/G91(.1), G92(.1), G93/G94. **`G80` is "cancel motion mode", not "cancel canned cycle"** — there is no cycle to cancel. Only the third-party *GRBL-Advanced* fork adds G73/G76/G81–G83 |
| **Marlin 2.x** | **Only in an opt-in build.** G81/G82/G83 exist but are gated behind `CNC_DRILLING_CYCLE`, off by default and added by community PRs. A post cannot know whether the operator compiled it in |
| **RepRapFirmware / Duet** | **No — and worse than absent.** RRF's "GCodes not implemented" list carries G80 and G81–G89, while the wider RepRap dialect assigns those numbers to *other* functions: `G80` mesh-based Z probe, `G81` mesh bed levelling status, `G82` single Z probe, `G83` babystep Z and store. The post's decision is safe under either reading — either the command is unknown, or it triggers a bed-probing routine instead of drilling |

Two more settled the same way: **Marlin has never implemented `M2`** (RRF gained it in 3.5.1, with a
`stop.g` interaction), and **GRBL, Marlin and RRF all accept a bare `\r`** as a block terminator.

Four more settled while designing the machine frame. Each **refutes** something believed at the time, and
each is a place a one-dialect assumption would have shipped a wrong motion:

| Question | Answer |
|---|---|
| `G53` per firmware | GRBL 1.1 supports it (above). **Marlin gates `case 53:` behind `CNC_COORDINATE_SYSTEMS`, off by default** (`gcode.cpp` 2.1.x) — so a *single-WCS* Marlin job passes Guard C and still cannot execute the move: that exclusion is separate, not inherited. It is also **not modal — program it on every line**, and an error without `G0`/`G1` active (LinuxCNC; RRF the same), so a split Z-then-XY move carries `G53` twice |
| Reaching machine X0 Y0 **without** `G53` | **`G28 X` / `G28 Y` does it on Marlin** — it does not *address* the machine frame, it **re-establishes** it, so it needs no build option and no prior homing. The costs are that it is a homing cycle rather than a rapid, and that the same trick is **unsafe on GRBL**: one `$H` homes whatever that build was compiled to home (per-axis `$HX`/`$HY` sit behind `HOMING_SINGLE_AXIS_COMMANDS`, off by default), so it can drive **Z**. Hence `G53` on GRBL/RRF and `G28 X Y` on Marlin |
| Is Marlin's one frame the machine frame? | **Only until the post writes an origin.** `writeWcsOrigin()` uses `G92` on Marlin, issued *at the current position*, so from the first section on, work X0 Y0 and machine X0 Y0 differ by an offset the post never knew — and cannot read back. Undoing it arithmetically is therefore not a route to the machine frame there |
| `G30` to store a park height | **Dead on all three.** GRBL/LinuxCNC: bare `G30` moves **X and Y too**, and `G30 Z<n>` rapids first to that Z *in the current WCS, offsets included*. Marlin and RRF: `G30` is a **single Z probe** — a plunge. Same trap `G80`–`G83` sets above |
| Jogging at an `M0` pause | **Not possible on GRBL** — *"a jog command will only be accepted when Grbl is in either the 'Idle' or 'Jog' states"* (Grbl v1.1 Jogging), and `M0` is neither. Only RRF has a real jog-at-pause (`M291 … X1 Y1 Z1`) |
| `G17` / `G94` off GRBL | **Neither is a free no-op.** Marlin compiles `G17` only under `CNC_WORKSPACE_PLANES` (shipped commented out in `Configuration_adv.h`) and has **no `G93`/`G94` at all** (`gcode.h` 2.1.x) — both reach `parser.unknown_command_warning()`. RRF has `G17` from 2.03 (`G18`/`G19` from 3.3) but gained `G93`/`G94` only in **3.5.1**, "experimentally", and **3.6.3** fixed inverse time mode not being reset at job start. So both stay GRBL-only, and the plane and feed mode a RepRap job inherits are a Start file's problem — `HReview.md` HB-6 |
| `G38.2` target frame | **Version-bound on RRF.** `G38.x` on Duet 2+ / RRF 3+, and **up to RRF 3.1.1 the target is machine coordinates**, user coordinates after. This post emits a work-frame target, so leaving it On below 3.1.2 probes to the wrong physical Z |

> **The lesson, twice over — and it is why *do the source read before filing a question as needing
> hardware* is a rule here.** (`M2` was filed as needing a controller, then closed from source.) All four
> above were answerable from sources already cited, and filing them as open cost a design decision
> (`G30`) that had no business surviving. And **both errors were outside GRBL**: a FluidNC conflation and
> the RRF version bound, the second of which would have produced a wrong physical motion. GRBL is not the
> coverage that is short.

---

## Design notes behind the shipped behaviour

### Traverse clearance is not the G1→G0 plane

**"Map: Safe Z to Rapid"** answers a narrower question — "within *this* operation, is Z high enough to
re-emit a cut G1 as a G0?" It is operation-scoped and only populated when the hobby group is on, so it is
the wrong source for an inter-op/inter-WCS retract. The cross-part retract uses a **job-level clearance
measured in the job's fixed Z reference** ("Inter Part Travel Z").

**The Inter Part Travel Z cannot be an F360 expression (asked and answered).** `Clearance:40` would parse
today and is still the wrong source: every F360 height parameter is **per-operation and expressed in that
operation's own WCS**, while this must be expressed in the
**base's** frame — feeding a part-frame number into a base-frame `G0 Z` under-clears by the stock
thickness, silently. F360 has no job-level "above the machine table" height at all; the base frame is a
post-invented concept. So it stays a plain whole-mm `integer`. The only sound use of an expression here
would be as a **floor** (`max(constant, resolved)`), never a substitute.

### Base WCS is transited, not parked (R1/R2)

The base-relative retract must *select* the base to move in its frame (the numeric relation between two
WCS is only known after runtime probing). Two rules:

- **R1 — always restore the operating WCS.** After a base transit, advance to the next operation's WCS
  before any cutting; never cut with the base left active.
- **R2 — never round-trip the base empty.** Enter the base only when a real move is emitted there.

A transit selects the base with a low-level `writeBlock`, **not** `writeWCS()` — going through `writeWCS()`
would re-probe and rewrite the origin, which is the opposite of passing through a frame. The same rules
govern the **base establish**: it transit-selects the base *before* probing so that both the `G38.2`
target and the post-probe retract are measured against the base, then restores the operating WCS.

> **Superseded, kept because it is the plausible wrong answer.** An earlier note argued the base establish
> needed no `G59` select, since `G10 L20` does not change the active WCS — correct as far as it goes, but
> it missed that the base's own probe and its post-probe retract would then execute in the *part's* frame,
> whose Z may be stale. **The missing select was the defect.**

### Why the first section's arrival is asymmetric

In `writeWCS()`, `isTraverse = (previousWorkOffset != undefined)` is false on the first section, so the
first section skips **both** the safe-Z retract and the origin/probe dispatch that every later WCS change
gets. Un-suppressing it where it sits does **not** work:

- **Ordering.** `writeWCS()` is step 3 of `writeFirstSection()`; `writeBaseEstablish()` is step 5. At step
  3 *neither* the part WCS's Z nor the base's Z has been established, so both retract paths would emit an
  absolute `G0 Z` into a stale frame — the same defect relocated.
- **Direction.** An absolute Z against a stale zero can move the tool *down*.
- **Blast radius.** With `isTraverse` true on the first section, the fallback fires on *every* job.

The resolution keeps the intent and fixes the placement: the first section's safe arrival happens **after**
the fixed Z reference is established, in that reference's frame. That exposed a hard limit — **with no
fixed reference there is no established frame at job start at all**, so no retract can be made safe there.
That case gets a `>>> WARNING:` instead, on the one path that deliberately emits no absolute Z move — a
precondition the operator must satisfy, not commentary, so it bypasses `Comment Level` and the same
sentence is raised in the post dialog where there is still something to change. The post does **not**
substitute a relative `G91` lift: it would be the only motion emitted in no frame at all, its extent is
unknowable on a machine whose Z travel the post cannot see, and it would leave the `G38.2` target — an
absolute Z in the same stale frame — exactly as unbounded as it found it.

**The machine-Z answer lifts the limit rather than working around it.** A declared, homed machine Z *is* an
established frame at job start, so on such a machine the arrival emits a real `G53 G0 Z<Inter Part Travel Z>`
and the warning is suppressed exactly as an established base suppresses it. The limit stands only where it
is still true: a job that establishes no fixed reference at all — and *declaring* one is not establishing it
on Marlin, where neither implementation runs, so the suppression asks `fixedZEstablishedInFile()` and not the
dialog's own answer.
