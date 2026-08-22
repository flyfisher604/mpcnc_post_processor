# Design — the target, and why the shipped behaviour is what it is

The **why** behind `MPCNC_v4.1.1_Beta3.cps`, for the parts of it the code cannot state: the frame model the
rest of the record reads against, the external firmware facts each decision rests on, and the arguments
behind orderings that look arbitrary in the source.

**A section headed ▶ *Target* states the design the code is being changed to, and names the `plan.md` step
that lands it.** Everything else describes what the post emits today. A target section is written as the
finished design, in the present tense, because **it is what the diff is checked against** — so read it
*with* its step, never as a description of the current file. When the step lands, the ▶ comes off and
nothing else about the section changes; if something else has to change, the design was wrong and the code
is not the place to discover it.

This file **grows with the post** — a change to what the post emits may earn a paragraph here. Two tests
gate the entry: the fact must be one **the code cannot state**, and it must be either **the model** — the
shared vocabulary the rest is unreadable without — or **a trap**, where someone reached the wrong answer or
the wrong answer fails silently. A design choice that is merely true stays in the code, and several hundred
of them do.

---

## Frames — *the model; every other section reads against this one*

Production controls keep three references separate: **MCS** (`G53`), **WCS** (`G54`–`G59`, `G59.1`–`G59.3`
on RepRap), and **TLO** (`G43`). Most V1E machines have none fully, hence the work-relative stance. **There
is no tool-length system at all** — no TLO, no tool setter — so a work-Z re-probe after each tool change is
the substitute, and **X/Y is never probed**.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to that WCS's own
  register, so the write names its target and cannot leak. `P` maps 1:1 to Fusion's `workOffset`
  (P1–P6 = G54–G59; P7–P9 = G59.1–G59.3, not on GRBL).
- **Marlin has nine registers too, behind one build option.** `CNC_COORDINATE_SYSTEMS` gates `G53`
  *and* `G54`–`G59` in a single `#if`, so the machine frame and the work offsets arrive together. What
  differs is **addressing, not capability**: `G92` writes the **active** workspace and only
  positionally, where `G10 L20 P<n>` names its target. That makes *the origin write targets the active
  WCS* a precondition on Marlin, enforced as an internal error rather than left to hold by luck.
  **Guard C is gone** — its message, *"Marlin has a single coordinate frame"*, was false. Verified at
  **2.0.9.7 and 2.1.2.5**; nothing read below that, so that is the floor.
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
fixed-Z establish and `writeWcsOnStart()` — and it is before both **whichever order those two run in**,
which is the one thing about the preamble that does not vary.

Everything unreadable is therefore a **trust assertion**, and there are two: **a stored WCS origin** (every
`Use WCS …` mode — which is why the *defaults* establish an origin rather than rely on one) and **a
declared machine frame** (the group-4 declarations, the same species).

**Homing does not change a WCS — it makes one trustworthy.** `G54`–`G59` hold offsets from machine zero and
`$H` never touches those registers. Unhomed, machine zero is wherever the controller was last reset — still
fixed for *that* power cycle, so origins **created** during a run stay mutually consistent and a no-endstop
multi-part job is sound. Only a **stored** offset goes bad, which is the whole of why that guard is
mode-sensitive rather than blanket.

**Where a trust assertion carries an absolute move, the firmware decides whether it is enough.** A declared
machine Z becomes the datum for an absolute `G53` rapid, and the assertion that carries it is
`Axes Homed and Trusted` alone — **not** `Home at Job Start`, whose entire purpose is to express *homed at
the controller, do not home here*. Requiring the action as well would cancel the state the split exists to
express. The firmwares differ, and only one of them is exposed: with homing enabled **GRBL comes up in
Alarm and refuses all motion until homed**, so a stale declared frame cannot execute there at all; **Marlin
never reaches the question**, `G53` being behind `CNC_COORDINATE_SYSTEMS` and the machine-Z frame refused on
it; **RRF has no such lock** and will run the move against a machine zero that has moved. RRF therefore
takes a post-time warning when this frame is in use with `Home at Job Start = Off`, and it is the only
target that needs one.

**`Home at Job Start` is read for one other kind of question, and it is not about trust.** *Is this frame
trustworthy?* is answered by the declaration alone, for the reason just given. *Where is the tool standing
now?* can only be answered by the action, because homing is a **motion** — and the two must not be confused
into a rule that the frame needs the action after all. Every reader of the action asks the second question:
the pre-jog warnings, and the height a probe with no frame searches down from (`PR-16`).

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
corroborate the declaration. FluidNC could, and here the post does not use it: the dialect is one `Grbl`
answer and this is where that conflation costs something it cannot recover. **It is no longer *throughout*
— the tool change is where the two part company**, `Tool Change Handled By` having a FluidNC value of its
own because that firmware executes the `M6` the senders' route needs stripped (`findings.md` `FR-1`, and
*Flow 2* below is the table). Homing is the conflation that stands; the change is the one that did not.

**Bookkeeping is not the whole cost, and this is the trap: on GRBL the declaration does not bound what
MOVED.** The table above reads as a limit on what the post can *emit*; it is also a limit on what the post
may *conclude*. A consumer asking *did Z move at job start?* must not read `machineHomesZ()` there, because
one `$H` runs the whole cycle whatever the dialog says — **a GRBL job declaring `XY Only` still homes Z**,
while `G28 Z` is exact. So `homingMovesZ()` is a **third** predicate; it composes the other two with the
firmware and the action rather than reading the property, so the *only two accessors* rule above stands. A
single `homesAtJobStart()` gate would have made a Marlin `XY Only` job blame homing for a Z it never
touched — `findings.md` `PR-16`, where `PRO40`/`PRO43` are that pair. **The action is one enum, `Home at Job Start` = `Off` / `Home` /
`Pause, then Home`**, and its pause is **one stop before any homing motion**, whatever the firmware and
axes; the post does not control homing order. That pause was a second boolean until it was folded in —
unlike the axis declaration, **this merge deleted a state rather than renaming one**: "prompt" was inert
whenever homing was off, so two booleans offered four settings of which only three did anything. **`$H` uses `writeln()`, not
`writeBlock()`** — GRBL recognises `$` only as the line's first character (CR-1).

### The fixed Z reference is the machine's own homed Z

A frame whose Z0 does not move with stock thickness — the only frame in which one clearance height is
meaningful across parts of differing thickness, which is why the cross-part safe-Z feature requires one
(Guard B). **There is exactly one: the machine's own homed Z, addressed with `G53`.** The height is
`Machine Travel Z`, an absolute machine coordinate, signed, read off the DRO; the machine is declared homed
in group 4, beside it.

**The field is the opt-in — there is no enum and no boolean.** The frame exists when the machine declares Z
homed **and** `Machine Travel Z` parses, and it does not otherwise. The field **ships empty**, so an
untouched dialog has no frame and a factory-default job emits exactly what it emits today; filling it is
the whole act of choosing one, **at any offset count**. It lives in **group 4**, beside the declaration,
because a height in the machine frame is meaningless without one. **Two controls that must agree is the
failure mode this retired**, so the design does not add another; the header echo names the frame and its
height, which is all a second control would have said.

**Multi-part is where the frame stops being optional.** A job using more than one work offset must have it
or be refused (Guard B): the tool has to clear the fixtures on its way between parts, and no single
clearance height is meaningful across origins that are only known after probing at runtime. A **single-part
job is never refused for want of one** — it simply gains what the frame is for, when the field is filled: a
real absolute Z at the first section's arrival instead of a warning, and a retract before the end-of-job
park crosses the bed.

**The frame itself is Z-only; the X/Y requirement belongs to the workflow.** A `G53` Z move needs machine
Z trustworthy and nothing else, so a single-part job on a `Z Only` machine may use it. What needs a homed
X/Y zero is *traversing between stored work offsets*, which is multi-part work — so that requirement sits
on Guard B as a **second, separately worded refusal**, and the frame predicate carries no trace of it.

**Marlin has the frame too, and it costs one build option.** `Marlin/src/gcode/gcode.cpp` (2.1.2.5) puts
`case 53:` through `case 59:` inside a **single** `#if ENABLED(CNC_COORDINATE_SYSTEMS)`, so a Marlin build
has the machine frame **and** the nine WCS registers together, or neither. That is one question, not two,
and **the post assumes the answer is yes and warns rather than refusing** — in the dialog and again in the
file. Refusing would deny the frame to every correctly configured CNC Marlin, and the post cannot read a
build; a warning beside a working file is the honest trade. Without the option, `G53` is an unknown command
and the travel moves are skipped — which is what the warning says, in those words.

> **This corrects the record twice.** An origin write on Marlin is **not** merely a global frame shift:
> under the same option `G92` runs `coordinate_system[active_coordinate_system] = position_shift` behind a
> `WITHIN()` bounds check (`src/gcode/geometry/G92.cpp`, in **2.0.9.7 and 2.1.2.5** alike), so `G5x` then
> `G92` is a real per-WCS register write into the *active* slot. And `G53` reaches native space
> **regardless of any `G92`**, because it selects `-1` for its own line. So the old claim that *the machine
> frame survives only until the job sets its first Z origin* was wrong, and with it the conclusion that
> Marlin multi-part work was a dead end. **`G92.1` also exists** there, under
> `ENABLED(CNC_COORDINATE_SYSTEMS) && !IS_SCARA` — the open question this record carried is closed.

**One `G53`, one block, and on Marlin a `G5x` after it.** `G53()` saves `active_coordinate_system`, calls
`select_coordinate_system(-1)`, and restores it **inside `if (parser.chain())`** — byte-identical at
2.0.9.7 and 2.1.2.5. So a `G53` chained with its motion on one line restores itself, and **a bare `G53` on
its own line leaves native space active for the rest of the job**. The post never emits the bare form, for
this reason and for GRBL's separate one (`G53` is not modal, and is an error without `G0`/`G1` active) —
**one rule, two firmware justifications, and neither may be dropped without the other being checked**.

The re-select the post adds on top is **belt-and-braces against reports that were never closed**. Marlin
issues **13843** and **14743** both describe `G53` failing to reach native space, and both were closed
**without a fix commit** — 13843 by a stale-bot for inactivity, its reporter running *an MPCNC Marlin
fork*, which is this post's own audience. The current source is correct by inspection, but "correct by
inspection with two unclosed reports against it" is not the same as fixed. So the post re-selects
`currentWorkOffset`'s **own** `G5x` — never a fixed `G54`, which would be the wrong register on any job
whose active offset is not the first.

> **Retired: the spoilboard base** — a surface probed into a reserved WCS, with the clearance read as a
> positive height above it. It was the **non-homing** machine's route to a frame, and it goes because
> multi-part work is the operator running stored fixture offsets, whose machine homes. It cost one of
> GRBL's six registers, a probe cycle at job start, five properties that were only correct together, and
> its defence was not code at all: **the base was probed wherever the tool already sat** — no XY move, and
> none possible, since the establish runs before any origin exists — so parking over the stock recorded the
> stock top as "the spoilboard" and every clearance from it was short by the stock thickness, silently
> (`findings.md` `PR-16`). **Do not re-propose it without an answer to that.**
> **And the answer is owed to a live warning, not to a deleted feature.** `PR-16` was closed *by deletion*
> and reopened 2026-08-17 when the same defect turned up on `Use WCS X0 Y0, Probe Z0`, which also probes from
> a height nothing in the file wrote — see *Why the first section's arrival is asymmetric*. So the hazard the
> base died of is a documented, tested property of this post's one remaining probe-from-an-unknown-height
> path, and any revival has to be better than that, not merely aware of it.
> **Retired with it: the enum flip.** Two frames sharing one clearance field made a height valid in the
> other frame a valid-*looking* height, and only one direction was detectable. One frame, one meaning, no
> flip — and the guard that caught the detectable direction goes too, having nothing left to catch.
> **Rejected: giving the base an XY origin.** It stayed a Z-only reference to the end.

**Why it is a parsed string and not a number** — and it matters more here than it did, because **empty is
what says *no frame*.** There is no spare value to mean *unset*: every signed number is a real reachable
height, `0` very much included, since on a stock GRBL build the machine zeroes into negative space and `Z0`
is the *top of travel*. Fusion's schema gives a numeric property no unset state, so *empty* is expressible
only on a string — and the property carrying the opt-in is precisely the one that must be able to be unset.

**The height is collected, never computed.** A height read off the DRO *after* homing is
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

**None of it can be re-derived from Fusion.** F360 knows nothing about GRBL's axis-limit rapids, Marlin's
build options or RRF's `G53`, and this project has no controller to ask instead — so every row here cost a
source read and a row deleted costs another one to replace. **These tables are load-bearing, not
informative**, and a claim about firmware that cites nothing is the one to distrust.

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

More settled the same way, most of them while designing the machine frame. Each **refutes** something
believed at the time, and each is a place a one-dialect assumption would have shipped a wrong motion:

| Question | Answer |
|---|---|
| `G53` per firmware | GRBL 1.1 supports it (above). **Marlin gates `case 53:` behind `CNC_COORDINATE_SYSTEMS`, off by default** (`gcode.cpp` 2.1.2.5) — but so are `case 54:` … `case 59:`, in the **same** `#if`, so the frame and the registers are one decision and the post assumes and warns rather than refusing. It is also **not modal — program it on every line**, and an error without `G0`/`G1` active (LinuxCNC; RRF the same), so a split Z-then-XY move carries `G53` twice |
| Reaching machine X0 Y0 **without** `G53` | **`G28 X` / `G28 Y` does it on Marlin** — it does not *address* the machine frame, it **re-establishes** it, so it needs no build option and no prior homing. The costs are that it is a homing cycle rather than a rapid, and that the same trick is **unsafe on GRBL**: one `$H` homes whatever that build was compiled to home (per-axis `$HX`/`$HY` sit behind `HOMING_SINGLE_AXIS_COMMANDS`, off by default), so it can drive **Z**. Hence `G53` on GRBL/RRF and `G28 X Y` on Marlin |
| Is Marlin's one frame the machine frame? | **Wrong question, and the earlier answer here was wrong.** With `CNC_COORDINATE_SYSTEMS` Marlin has nine workspaces and `G53` reaches native space on any line, whatever `G92` did — `G53()` selects `-1` for the duration of its own chained command. Work X0 Y0 and machine X0 Y0 still differ by an offset the post cannot read back, so *arithmetic* is still not a route; `G53` is, and it is the one the post takes. Read 2026-08-14, `src/gcode/geometry/G53-G59.cpp` + `gcode.cpp`, 2.1.2.5 |
| Does Marlin's `G53` restore the workspace after its line? | **Only when chained.** `G53()` saves `active_coordinate_system`, calls `select_coordinate_system(-1)`, and restores **inside `if (parser.chain())`** — so `G53 G0 Z-10` restores itself and a **bare `G53` never does**, leaving native space active for the rest of the job. Byte-identical at **2.0.9.7 and 2.1.2.5**. Issues **13843** and **14743** report it failing even chained; both were closed **with no fix commit** (13843 by a stale-bot, its reporter on an MPCNC Marlin fork), so the post re-selects the active `G5x` itself. `src/gcode/geometry/G53-G59.cpp` |
| Can Marlin write a *per-WCS* origin? | **Yes, under the same option.** `G92` runs `coordinate_system[active_coordinate_system] = position_shift` behind a `WITHIN()` bounds check, so `G5x` then `G92` writes the selected register, positionally, and persistently. **Corrects the standing "Marlin has one global origin" claim.** `G92.1` exists too, under `ENABLED(CNC_COORDINATE_SYSTEMS) && !IS_SCARA`. `src/gcode/geometry/G92.cpp`, **2.0.9.7 and 2.1.2.5** |
| Does homing detach a Marlin job from its work origin? | **Not irrecoverably, on a CNC build.** `set_axis_is_at_home()` zeroes `position_shift[axis]` under `HAS_POSITION_SHIFT` but **never touches `coordinate_system[]`**, so re-sending `G5x` re-applies the stored origin. Without the build option there is no register and the shift is simply lost. **This narrows an earlier flat claim that re-sending `G54` does not restore it.** `src/module/motion.cpp`, 2.1.2.5 |
| `G30` to store a park height | **Dead on all three.** GRBL/LinuxCNC: bare `G30` moves **X and Y too**, and `G30 Z<n>` rapids first to that Z *in the current WCS, offsets included*. Marlin and RRF: `G30` is a **single Z probe** — a plunge. Same trap `G80`–`G83` sets above |
| Jogging at an `M0` pause | **A sender property on GRBL, not a firmware one — and the earlier answer here was wrong.** *"A jog command will only be accepted when Grbl is in either the 'Idle' or 'Jog' states"* (Grbl v1.1 Jogging) describes a controller that **received** the `M0`, and a streaming sender decides whether it ever does: gSender rewrites the line to `(M0)` in its sender `dataFilter` and holds its own stream instead — `line = line.replace(/M0+(?!\d)/i, "(M0)")` above `this.workflow.pause(…)`, `src/server/controllers/Grbl/GrblController.js`, master, read 2026-08-14 — so the controller stays `Idle` and jogs. A sender that forwards `M0` produces the hold. **The same file guards that pause with `if (sent > 10)`** while commenting the line out unconditionally, so an `M0` in the first ten streamed lines is swallowed silently. RRF needs none of this: `M291 … X1 Y1 Z1` is a real firmware jog-at-pause |
| `G17` / `G94` off GRBL | **Neither is a free no-op.** Marlin compiles `G17` only under `CNC_WORKSPACE_PLANES` (shipped commented out in `Configuration_adv.h`) and has **no `G93`/`G94` at all** (`gcode.h` 2.1.x) — both reach `parser.unknown_command_warning()`. RRF has `G17` from 2.03 (`G18`/`G19` from 3.3) but gained `G93`/`G94` only in **3.5.1**, "experimentally", and **3.6.3** fixed inverse time mode not being reset at job start. So both stay GRBL-only, and the plane and feed mode a RepRap job inherits are a Start file's problem — `findings.md` HB-6 |
| Does the `F` word on a `G0` set the travel speed? | **No on GRBL or FluidNC, and no line a posted file may contain sets it there.** Their planner takes a rapid's rate off the axis limits and never out of the block — `if (block->condition & PL_COND_FLAG_RAPID_MOTION) { block->programmed_rate = block->rapid_rate; }`, `rapid_rate = limit_value_by_axis_maximum(settings.max_rate, unit_vec)` (`grbl/planner.c`, `plan_buffer_line()`, gnea/grbl 1.1); FluidNC is the same planner renamed, `block->motion.rapidMotion` and `limit_rate_by_axis_maximum()` (`FluidNC/src/Planner.cpp`, 3.x). The `F` **is** stored — `gc_state.feed_rate = gc_block.values.f; // Always copy this value` (`grbl/gcode.c`) — so it governs the next *cut*, not the rapid it rode in on, and the post is right to keep emitting it. All three ways out are shut: `$110`–`$112` are settings, blocked outside `Idle`/`Alarm` (`system_execute_line()` → `STATUS_IDLE_ERROR`; FluidNC `Setting::check_state()` → `Error::IdleError`), written to EEPROM, and applied where the line is *parsed* rather than where it is *reached*; and the rapid override is the real-time bytes `0x95`/`0x96`/`0x97`, not stream content, quantised to 100/50/25 %. **And the two dialects diverge here**, which the post's one `Grbl` answer cannot express: FluidNC did not emulate Grbl's numbered machine-setup settings, so `$110` does not exist there and the limit is `max_rate_mm_per_min` per axis (`FluidNC/src/Machine/Axis.cpp`). The post therefore **names the parameter rather than trying to command the speed** — `findings.md` `CR-01`; mapping travels to `G1` was built and rejected. Marlin and RRF honour `F` on a `G0` and need none of this |
| Does `M1`, the optional stop, stop anything? | **No usable answer on any of the three, and each fails differently** — so the post emits `M0` for Fusion's `COMMAND_OPTIONAL_STOP` and states in the file that the *optional* half is what it could not keep. GRBL 1.1 parses it and does nothing: `case 1: break; // Optional stop not supported. Ignore.` (`grbl/gcode.c`) — accepted, no error, no pause. RepRapFirmware handles `M0`, `M1` and `M2` in **one block** (`src/GCodes/GCodes2.cpp`, *"case 0: // Stop"*, *"case 1: // Sleep"*, *"case 2: // Stop"*), so mid-file it **ends the job**. Only Marlin does what Fusion means, waiting for the LCD in `src/gcode/lcd/M0_M1.cpp` — and only under the same `HAS_RESUME_CONTINUE` that `findings.md` `HB-1` turns on. **The refuted claim was *"`M1` is supported by all three targets"***, which is true of the parser and false of the behaviour: the trap of reading a command table rather than the handler |
| Does a `(MSG …)` comment need its comma? | **One dialect requires it and the others cannot see it, so the post always writes it.** grblHAL matches `strncasecmp(comment, "MSG,", 4)` in `gc_normalize_block()` (`grblHAL/core`, `gcode.c`, read 2026-08-14) and surfaces **nothing** without the comma — the prompt is an unexplained pause. FluidNC is indifferent: `strstr(comment, "MSG")` then a fixed four-character skip, `offset = strlen("MSG_")`, in `gcode_comment_msg()` (`FluidNC/src/GCode.cpp`, main), so `MSG,` and `MSG ` both reach the log. Stock grbl 1.1 discards comments entirely and never sees either. No space after the comma: grblHAL trims one, FluidNC would keep it. `findings.md` `CR-02` |
| Does RRF's `G53` apply the **tool** offset? | **No — it drops the tool offset as well as the workplace offset**, so a `G53` height is a carriage position and `Machine Travel Z` means on RRF what it means on GRBL however long the tool is. `currentUserPosition[axis] = moveArg + GetCurrentToolOffset(axis)` in the `g53Active` arm, whose own comment reads *"g53 ignores tool offsets as well as workplace coordinates"* — and that pre-added offset is exactly what `ToolOffsetTransform()` subtracts again on the way to machine coordinates (`totalOffset = babyStep − currentTool->GetOffset(axis)`). `src/GCodes/GCodes.cpp`, `DoStraightMove()` and `DoArcMove()`, **the same at 2.05, 3.0, 3.5.4 and 3.6.0**, the expression gaining `/axisScaleFactors[axis]` in 3.5 and nothing else; read 2026-08-16. **The one setting that makes the offset non-zero mid-file is `Tool Change Handled By` = RepRapFirmware tool table**, where `tpost<n>.g` applies one at every change — and it costs the post nothing. `findings.md` `PR-25` |
| `G38.2` target frame | **Version-bound on RRF.** `G38.x` on Duet 2+ / RRF 3+, and **up to RRF 3.1.1 the target is machine coordinates**, user coordinates after. This post emits a work-frame target, so leaving it On below 3.1.2 probes to the wrong physical Z |

> **The lesson, twice over — and it is why *do the source read before filing a question as needing
> hardware* is a rule here.** (`M2` was filed as needing a controller, then closed from source.) All four
> above were answerable from sources already cited, and filing them as open cost a design decision
> (`G30`) that had no business surviving. And **both errors were outside GRBL**: a FluidNC conflation and
> the RRF version bound, the second of which would have produced a wrong physical motion. GRBL is not the
> coverage that is short.

---

## Tool changes — two flows, and the code implements both

**The shipped tool-change code was a bad design and was replaced rather than repaired.** Flow 1 landed
first (`findings.md` `PR-15`) and Flow 2 followed (`PR-24`), both 2026-08-14, so this section now
describes the code rather than aiming at it. The per-defect rows filed against the old design were
deleted with the design that made them defects; their durable content — the firmware facts and the
orderings any implementation must respect — is below.

**The premise both flows follow from.** A measured tool change needs a probe, a **subtraction**, and a
register to hold the result. **The post can supply none of the three.** It cannot compute an offset it will
not learn until the operator swaps the tool, hours after posting, and it can never read a register back
(*Selection is deterministic, origin is trusted*). So the post's role is to **arrive correctly, hand over,
and resume correctly** — never to perform the change. Everything the old design did beyond that was the
error.

### A re-probe corrects one register; a tool-length offset corrects the frame

**That difference decides what a change leaves behind**, and it is why the dialog asks *who* corrects
rather than *whether to probe*. A work Z0 lives in a WCS register as a machine-Z coordinate, so
measuring it writes **one** register and leaves every other part still measured by the tool just
removed. `G43`/`G43.1` writes no register at all — it shifts the **Z frame** — so every part's stored
Z0 becomes correct at the same instant, none of them touched. Read against *Frames*: **there is no
tool-length system here**, which is exactly why the substitute the post reaches for corrects less than
the thing it substitutes for.

**Three answers, and only one of them leaves the other parts alone.** `Tool Length Correction By`:

| Answer | Reach | What the post does |
|---|---|---|
| **This post** | one register | re-probes the active offset, and marks **every other** part stale so its own return re-measures it |
| **The tool change** | the frame | nothing — no probe, nothing marked stale, and the file states the condition it is trusting |
| **Me, by hand** | one register | nothing measured; every part **but the one active at the pause** is marked stale |

**It was a boolean until `findings.md` `PV-10`**, whose Off carried *"the handler applied an offset"*
and *"I will re-zero at the pause"* as one answer. Those reach different numbers of parts, so a
hand-zero was booked as though it had corrected the whole job: the operator did exactly as the file
told them and the next part was cut deep by a tool length. **The post can verify none of the three** —
same standing as every other clause of the Flow 2 contract — so each is an operator assertion, and the
two whose stated party may not exist are warned about at `onOpen()`.

### The first tool is loaded, not changed — and by whichever flow the job selected

**The first tool is a special case of neither flow and of both.** Nothing is running, no Z0 exists yet to
invalidate, and the tool stands where the last preamble step left it — so **none of a change's arrive-and-
resume work is owed**: no retract to repeat, no spindle or coolant to stop, no `Manual Position`
excursion, and no re-probe, because the origin write a few blocks below establishes Z0 with the tool just
fitted. That last point is the ordering the whole thing exists for: **load before the origin work**, or Z0
is measured with the tool the load was there to replace.

**What is NOT special is who does it.** `First Tool is Correct` is a declaration — the tool in the spindle
either is the one this job starts with or is not — and where it is not, **`At a Tool Change` decides who
fits it**, exactly as at every other boundary. A job that hands every change to a sender or a changer must
not stop and ask a human for the one tool the changer already holds; that was the defect (`findings.md`
`PV-13`), and it followed from the setting being *a prompt* rather than *a fact about the spindle*.

**Refuse and Manual emit the same bytes here, and that is correct rather than an omission.** The two modes
differ at a *change*, and this is not one. Refuse means one tool per file, so on such a file there is no
second boundary for them to differ at.

**Three conditions suppress the load, and each says so in the file:**

- **A pre-jogged origin.** The two `Set … to Current Pos` modes take the origin from a jog made before
  line 1, with a tool already fitted — so declaring that tool incorrect contradicts the mode, and on the
  hand-over route the macro would move the tool **off the position about to be recorded**.
- **A first tool no changer can fit** — tool 0 or a jet tool. `T0 M6` names no tool to any handler in the
  list and a laser is not in a changer. The `M0` routes are unaffected: asking a *person* to fit a laser
  is a sensible thing to do.
- **The declaration itself**, which is the default and emits nothing at all.

**Every Flow 2 guard had to widen with this.** They were keyed on more than one tool in the job, because
until this existed a one-tool job could not reach a hand-over at all. It now can, and it owes the same
refusals — Marlin has no tool-length register whether the hand-over is the first tool's or the fourth's.

### Flow 1 — the manual change, at the end of a file

**The hobbyist answer, and for a Personal licence the only one:** Fusion Personal does not emit tool changes
at all, so a two-tool job is two posted files. The post's whole responsibility is to **end the first file so
the second can start where the first left off**.

- **XY is not lost.** The file ends with the work origin exactly as the job established it — **no
  `G10 L20`, no `G92`, and no homing**. On Marlin homing is not merely unnecessary but destructive:
  `set_axis_is_at_home()` zeroes `position_shift`, and re-sending `G54` does not restore it, so the next
  file would cut against an origin the operator never set. That makes *never home at end of file* a rule,
  not a preference.
- **The park is in one stated frame.** The park height and position must say which frame they are measured
  in and emit that frame — `G53`, which requires a declaration including the parked axes, or the work
  frame, which drifts per WCS. **Not both meanings on one field**, which is what the deleted
  `Tool Change X/Y/Z` did: plain `G0` words the dialog presented as absolute.

  **The rule is about frames, not about readers, and `Safe Z` is where the difference shows.** One
  property is read by group 3 and by group 5, which looks like the same violation and is not: both are
  heights in the **same** frame — the part's work coordinates, measured from the touch-off Z0 — and both
  mean *a height that clears the work*. Group 3 asks whether the tool is already at or above it; group 5
  takes the tool to it. **One meaning, two readers**, and a machine on which those two heights differ is
  one where the post is rapiding through the height it just called clear. What the rule forbids is one
  field whose number is measured from **two different zeros** depending on who reads it, which is exactly
  what `Tool Change X/Y/Z` was and what a `Safe Z` shared with `Machine Travel Z` would be — see
  *Traverse clearance is not the G1→G0 plane*, which is the case where the frames really do differ.
- **Z is the operator's to re-establish**, by re-probing at the start of the next file — the shipped default
  first-part mode already does exactly this, so Flow 1 adds no mechanism to reach it.
- **It is an option, not a policy.** A single-tool job must not pay for it.

### Flow 2 — the sender's macro, mid-program

**The work is deferred to whatever owns a tool table, and that is never the post.** The three firmwares
split on who can do the subtraction:

| Firmware | Who can measure and apply a tool offset |
|---|---|
| **RepRapFirmware** | **The machine.** Meta-g-code arithmetic and a real tool table — `G10 L1 P<t> Z`, persisted with `M500 P10` — so a `tpost` macro does it, and `M6` is a genuine call into `tfree`/`tpre`/`tpost` |
| **GRBL** | **The sender.** No arithmetic, and `G43.1` takes a literal, so the offset must be computed off-controller. On **stock Grbl and grblHAL** `M6` reaches the controller as `error:20 Unsupported command` — the route only exists if the sender intercepts the token before the controller sees it |
| **FluidNC** | **The machine, where its own config says so** — and this is the row that broke *treats FluidNC as GRBL throughout*. `M6` is executed: `case 6` sets `ToolChange::Enable` and STEP 4 calls `Spindle::tool_change()`, which dispatches to the changer declared as `atc:` or runs the `m6_macro:`, and a `Manual_ATC` with a tool setter probes the new tool and applies the length as a **frame** offset — `G43.1`, computed on the controller from `#5063`. **With neither key declared it returns `true` having done nothing**, which is `findings.md` `CR-24`'s shape and why that value warns. `FluidNC/src/GCode.cpp`, `src/Spindles/Spindle.cpp`, `src/ToolChangers/atc_manual.cpp`, v3.9.6; the changer directory arrived at 3.9.0, so the claim carries a minimum version |
| **Marlin** | **The operator.** No TLO register at all, so the only correction is re-probing and re-zeroing work Z by hand. *(This corrects an earlier bare "no TLO" claim.)* |

**So the post's responsibilities are exactly three, and nothing else is in scope:**

1. **Pre-change setup** — leave the machine in the state the macro is entitled to assume: coolant off,
   spindle stopped or the operator prompted to stop it, tool clear of the work at a known height in a
   stated frame.
2. **Call the macro** — emit the agreed token, once, and nothing around it that the macro will redo.
3. **Post-change resume** — restore the frame and the modal state the macro may have disturbed, and put
   the tool back over the work before cutting resumes.

**This is a contract, and the contract is the deliverable.** What the macro may change and what it must
restore has to be written down, because the post cannot verify any of it. Without that written contract the
call is a trapdoor. **It is written in the dialog, not here** — `Tool Change Handled By`'s own description,
because the party who has to satisfy it is the operator and that is the only document they read.

**The token stopped being one question by becoming a property.** `M6` is real on RRF and is `error:20` on
GRBL, so whether the route exists at all depends on the *sender* — a sender-side fact no firmware source
can settle. The post therefore names the handler and emits what that handler reads: `T<n> M6` for gSender
and CNCjs, whose Grbl `dataFilter` removes the `M6` before the controller sees it, and for UGS, whose
`ToolChangeInterceptor` strips the `M6` and issues the `T` word to the controller on its own
(`ugs-core/.../services/interceptor/`, master, read 2026-08-17); `T<n>` alone for RRF, where the T word
**is** the change; the operator's own file for anything else. **A handler is listed only where its
interception is sourced** — which is why `Other` exists, and why UGS took a source read rather than a
design decision to add. **What the three GRBL senders share is one predicate and not three disjuncts**:
`toolChangeSenderIsGrblSender()`, because a fourth value added to the Flow 2 warning and not to the
firmware guard would be a hand-over that is warned about and never refused.

**Where the manual change happens is Flow 1's question alone, and the frame is its whole substance.** The
deleted `Tool Change X/Y/Z` were bare `G0` words the dialog called absolute while the machine read them in
whichever WCS was active, so a change position measured against one part's origin was somewhere else for
the next. Replaced in the **machine frame**, through the same `G53` block as every other machine-frame
move, where a coordinate means the same thing on every part of every job. Flow 2 has no such fields:
driving the tool to a changer or a length sensor is the macro's own business, in a frame the post cannot
see, and a post that guessed would be putting the tool where the macro did not ask for it.

**The return is not a retrace, and the reason is the same one that makes multi-part probing necessary.**
Nothing after a change is measured from where the tool stood before it — the tracked position is discarded,
the next move is absolute, and the re-probe re-establishes Z0 from the part origin. The point to return to
is known only in the *work* frame, and where a change coincides with a change of work offset, the true
relationship between the two registers is not known until both have been probed. So the post owes the
**height** and the **order of the next rapid**, and nothing else: cross at the height the change left,
then descend.

### What any implementation must get right

Carried from the register the old design filled, because each is a defect the rework can reproduce:

- **Select the WCS before the change, establish the part's origin after it.** Both halves of that order are
  a defect if reversed, and they are not the same defect. Selecting late puts a post-change re-probe into
  the *previous* section's register — the root defect of the shipped code, and a wrong part. Establishing
  early sets the part up with the tool that is about to be removed, which the change then corrects — right
  register, right depth, and **two probe cycles and four operator prompts where one and two would do**. So
  the WCS select and the origin work are separate calls with the change between them, and the change may
  hand its own re-probe to the establish **only where that establish sets Z0 itself** — not under
  `Use WCS X0 Y0 Z0`, not with a tool that cannot probe, and not on a return whose Z0 nothing has staled.
- **Stop coolant and the spindle on *every* route**, not only the one that relocates the tool. That stop is
  not a property of relocating.
- **A first change happens before the first part's origin work**, or the part's Z0 is established with the
  tool the change exists to replace. That is the same rule as the one above, in the one place where the
  origin work is `writeFirstSection()`'s rather than a boundary's.
- **No `M84 Z`.** It is Marlin-only, so GRBL halts on it mid-change with the operator holding a tool — and
  on Marlin a release with no brake sinks an unbalanced gantry in Z. It is a hazard under both readings and
  goes with the rework.
- **Post-injected motion goes through `rapidMovements()`**, as every other post-injected move does. Routing
  it through the post's own `onRapid()` clears `forceSectionToStartWithRapid` and defeats *First G1 → G0* on
  exactly the sections that use it.
- **A suppressed change is announced at the dialog as well as in the file.** An operator who reads only the
  dialog must not learn at the machine that the change was dropped.

---

## Design notes behind the shipped behaviour

### Which channel a warning belongs in, and the one question that decides it

The post writes to two channels and they reach different people. `writeWarning()` puts a `>>> WARNING:`
line in the g-code — ungated by `Comment Level`, because a warning is not commentary — and it reaches
whoever opens the file. `warning()` raises a line in Fusion's post dialog, and it reaches whoever posts.
**Those are often the same person on different days, and the operator who posts, reads the dialog and
sends the file without opening it is the one every one-channel warning was written past.**

**The question is not "is this important". It is: could a person who never opens the file act on this?**

- A condition **the properties and the job's shape fix** is answerable before the job runs and belongs in
  both channels. A stranded work Z0, a mode that establishes nothing, a coolant channel with no file —
  the operator would have posted differently had they known.
- A condition **the emitting block discovers** belongs in the file. An unsupported Manual NC command, a
  clamped dwell, a rigid-tapping request: the post learns of it from the kernel, mid-stream, and there
  was no earlier moment at which to say it.
- A condition **true of every job on a firmware** belongs in the file even though it is knowable, and the
  GRBL rapid-`F` warning is the case. A dialog line on every post is one the operator learns to dismiss,
  and that costs the pairs above the attention they depend on.

**Both channels should leave from one statement.** `warnBothChannels()` writes the file line and raises
the dialog line from one call, so the condition is evaluated once and the text exists once. The
alternative — a `validateJob()` pre-flight beside the emitter's own warning — needs a **second
predicate**, computed at `onOpen()` to predict what the emitter will decide later, and the two can come
to disagree; `PV-7` has such a pair by necessity (only the emission point knows a probe is actually
happening) and each half says in its own text that it must not drift from the other. Prefer the paired
form only where the pre-flight can say something the emitter cannot.

**And the drift a pair risks is not only in the predicate — it is in the TEXT, which is the half that gets
corrected.** `PR-16` was found by taking one such comment at its word: it claimed the two halves covered the
condition *"word for word"*, and reading them together showed both giving advice the configuration made
impossible. So a correction to either half is owed to both, and a pair whose texts have drifted is worse
than an unpaired warning — it reads as two confirmations of the same wrong thing.

**A pre-flight is not earlier in any sense that helps.** The post dialog is read *after* the post has
run, so both channels arrive at the same moment. What a pre-flight buys is one statement about the whole
job; what the emission point buys is one per occurrence — which for three stranded parts is the honest
count. `PV-9`, and `grep -n "// TWIN"` in the post is the verdict for every site.

### The kernel's position is the toolpath's, and only the work frame can correct it

`getCurrentPosition()` is not where the tool is. It is where the **toolpath** is: the kernel advances it
from the movements it feeds `onRapid` / `onLinear`, and every move the post emits on its own account —
the probe traverses, the safe-Z retracts, the returns to X0 Y0, the machine-frame retracts — is invisible
to it. Four things read it, and each is wrong by exactly that gap: the X/Y-against-Z ordering of a rapid,
the G1→G0 restore, and the feedrate projection for a line and for an arc.

So **the post reports its own moves back**, through `noteCurrentPosition()` and the kernel's
`setCurrentPosition()`, from inside the two rapid writers rather than at each injection site. The rule
that follows is the one worth carrying: **only a work-frame move can be reported.** `setCurrentPosition()`
takes a frame position, and the work-frame value of a `G53` height requires the WCS offset — which on this
machine is established at runtime by a probe, and is the same unknown that makes an X/Y retrace after a
tool change unsound and multi-part probing necessary. A machine-frame move therefore leaves the kernel
knowingly stale, and the one place that matters — the first rapid after a relocated tool change — refuses
to read the stale value instead of being handed a plausible one. Autodesk's own posts draw the line in the
same place, reporting a `G53` retract only to the machine simulator, on a channel that accepts machine
coordinates.

### Traverse clearance is not the G1→G0 plane

**`Safe Z`** answers a narrower question than a traverse does — "within *this* operation, is Z high enough
to re-emit a cut G1 as a G0?", and "how far up after a probe". It is operation-scoped and expressed in the
**part's** work coordinates, so it is the wrong source for an inter-op/inter-WCS retract however many
groups read it. The cross-part retract uses a **job-level clearance in the machine frame**
(`Machine Travel Z`).

It was group 3's own `Safe Z to Rapid` until `PC-6`, which left one property serving group 3 and group 5
alike — and **that fold makes this section's argument sharper rather than weaker**: the two readers it
merged are in the same frame, and this one is not. A field is shared where the frame is shared and nowhere
else.

**It cannot be an F360 expression (asked and answered).** `Clearance:40` would parse today and is still the
wrong source: every F360 height parameter is **per-operation and expressed in that operation's own WCS**,
while this one is an absolute machine coordinate — feeding a part-frame number into a `G53 G0 Z` measures
it from the wrong zero entirely, and how wrong is unknowable to the post. F360 has no job-level "above the
machine table" height at all. The only sound use of an expression here would be as a **floor**
(`max(constant, resolved)`), never a substitute.

### The cross-part retract enters no WCS at all

Every traverse between work offsets retracts with a single `G53 G0 Z<Machine Travel Z>` **before** the
destination WCS is selected, so no height is ever computed in a frame whose Z origin the job has not
established. `G53` is not modal and is an error without `G0`/`G1` active, so it is **its own block, with a
Z word and nothing else** — a future X/Y park is a second block, never a three-axis diagonal. Nothing is
selected, so nothing has to be restored, and the active WCS after a retract is whatever the next section
asks for.

> **Retired with the base: R1/R2, the transit rules.** A probed base had to be *selected* to move in its
> frame — the numeric relation between two WCS is knowable only after runtime probing — which bought two
> standing rules (*always restore the operating WCS*; *never round-trip the base empty*), a transit that had
> to bypass `writeWCS()` to avoid re-probing on the way through, and one defect on the way: an earlier note
> argued the establish needed no `G59` select, since `G10 L20` does not change the active WCS — true, and it
> missed that the base's own probe and post-probe retract would then execute in the *part's* frame, whose Z
> may be stale. **`G53` needs none of it.** It addresses the machine frame without selecting anything, which
> is the whole reason one absolute frame beats one probed register.

### Why the first section's arrival is asymmetric

In `writeWCS()`, `isTraverse = (previousWorkOffset != undefined)` is false on the first section, so the
first section skips **both** the safe-Z retract and the origin/probe dispatch that every later WCS change
gets. Un-suppressing it where it sits does **not** work:

- **Ordering.** `writeWCS()` runs before the fixed-Z establish in `writeFirstSection()`, and where it runs
  the part WCS's Z has not been established and the job has emitted nothing in the machine frame either, so
  a retract there would be an absolute `G0 Z` into a stale frame — the same defect relocated.
- **Direction.** An absolute Z against a stale zero can move the tool *down*.
- **Blast radius.** With `isTraverse` true on the first section, the fallback fires on *every* job.

The resolution keeps the intent and fixes the placement: the first section's safe arrival happens **after**
the fixed Z reference is established, in that reference's frame. That exposed a hard limit — **with no
fixed reference there is no established frame at job start at all**, so no retract can be made safe there.
That case gets a `>>> WARNING:` instead, on the one path that deliberately emits no absolute Z move — a
precondition the operator must satisfy, not commentary, so it bypasses `Comment Level` and is paired with a
post-dialog line where there is still something to change. The post does **not**
substitute a relative `G91` lift: it would be the only motion emitted in no frame at all, its extent is
unknowable on a machine whose Z travel the post cannot see, and it would leave the `G38.2` target — an
absolute Z in the same stale frame — exactly as unbounded as it found it.

**One height carries both halves of that warning, and it is the tool's height and not its position.** On
`Use WCS X0 Y0, Probe Z0` the rapid to the stored X0 Y0 is an **X/Y move**, made at whatever height the
tool is holding, and the `G38.2` is **at the stored X0 Y0** and searches `G38 Target` down from that same
height. So the probe's *position* is the register's and only its *start height* is the tool's — a warning
that says the probe starts "where the tool stands" reads as the position and is wrong.

**And the precondition is only the operator's to satisfy where nothing else moves the tool — which homing
does.** `Home at Job Start` runs two steps earlier and leaves the tool at an endstop, so *position it clear
before starting* and *set the target deep enough to reach from where you leave the tool* are both
unfollowable on a homing job: the height is the switch's, and no jog before line 1 of the file reaches it.
**Advice a configuration prevents is worse than none**, so the warning carries two texts on one condition,
differing only in who chose the height, and the homing text names the endstop instead of asking for a jog.
It is excluded where the first tool is **handed over**, that arm moving the tool after homing, so the height
is the macro's — `firstToolChangeIsHandedOver()`, read by both halves rather than re-derived. This is
`PR-16`, and the *class* of the retired spoilboard base: a probe that ran wherever the tool already sat.

**The machine frame lifts the limit rather than working around it.** A declared, homed machine Z *is* an
established frame at job start, so on such a machine the arrival emits a real `G53 G0 Z<Machine Travel Z>`
and the warning is suppressed. The limit stands only where it is still true: a job with no frame at all —
and on Marlin *declaring* one is not establishing it, the one implementation being refused there, so the
suppression asks whether the frame is established **in this file** and not what the dialog was set to.

**A clearance move is never a probe question.** `Use WCS X0 Y0 Z0` arrives by lifting to the probe Safe Z
and then crossing to the stored X0 Y0 — an absolute work-frame Z, meaningful because trusting that origin is
the mode's whole premise. That lift was gated on the tool being able to probe, on **the one mode that probes
nothing**, so a laser or tool-0 job crossed the bed at whatever height it was holding while a milling tool
on identical settings was lifted first. The premise is the **mode's** and holds for every tool; the rule is
that clearance and measurement are separate questions and only the second may read the tool. The guards that
stay are the ones bounding a `G38.2` or a provisional Z0 that only a probe overwrites — there the tool
really is the condition (`HR-26`, and `CR-12`/`PV-3` for the arms that keep theirs).

**Two modes make no arrival at all, and they take the order in reverse.** Everything above is about the
first section *travelling* to its origin. The two `Set … to Current Pos` modes do not travel: the origin
**is** where the operator left the tool, so there is nothing to arrive at and nothing for the frame to be
the starting height of. What the establish would be instead is the one thing that destroys the answer —
`G53 G0 Z<Machine Travel Z>` carries a single axis word, so it left the pre-jogged X and Y standing and
overwrote the Z the mode exists to record. So `writeFirstSection()` holds **two orders**, chosen by
`originIsPreJogged()`: establish → load → origin where the origin travels, and origin → establish where it
does not. The frame is still established once, in the same file, before the first cut; only its place in
the preamble moves. **The load prompt does not move with it, it goes** — a pre-jog can only have been made
with a tool already fitted, so `Prompt for the First Tool` has nothing left to ask on those modes and is
suppressed with a warning naming the `Jog to …` modes, which prompt first and position after. `CR-15`.

### Computing a safe height is not the post's job

**And Autodesk agrees in code.** *Z untrusted* means the controller was never told where its own frame is,
so an absolute machine height is not approximately right — it is **arbitrary**. A relative lift is always
*exact*; only its **sufficiency** is unknown. That is why a warning is the correct response and an error is
not: erroring would refuse the hand-zeroed hobbyist, who is 24 of the 24 posted files. When Autodesk's own
post is in this situation it emits *"Ensure the clearance height will clear the part and or fixtures"* — a
warning and a comment, nothing else.

**Asking for a travel height fills a hole rather than duplicating a field.** F360 has a machine-frame safe-Z
slot, `getRetractPlane()`, and **no way for an operator to fill it** — zero occurrences across 211 cached
machine definitions, and `setRetractPlane` commented out in all 159 posts that mention it.

**The legitimate exception:** where the program **itself** homed, the frame is known for the rest of that
program and an absolute retract is honest — a condition the post can verify, because it emitted the homing.

### The post does not reach into F360's job

F360 **never learns where the fixtures are**, so it cannot compute a path between work offsets and does not
claim to. This is read from Autodesk's own machine-definition files, not from this project's documents. The
consequence is that inter-part traverse logic has to live in the post or nowhere — which is why the post
carries it, and why the *orchestration* above it belongs to the operator instead.

---

## Working on the post

**Guards should attempt to be executed when `onOpen` runs.** Where a guard runs decides what a rejected job
leaves on disk: `onOpen()` refuses before any output, so the job writes **no file at all**, while a guard in
`onSection()` leaves a **truncated `.gcode`** an operator may not notice. `validateJob()` runs from
`onOpen()` and already walks `getSection(i)`, so a guard needing section data can still live there.

**Properties** use the combined-inline `properties = {}` form, read with `getProperty(properties.key)`.

**One test hook lives in the post, and it is `mapRapidsTestPersonalLicence`.** It reroutes `onRapid()`
into `onLinear()`, which is the only way to reach the group-3 code: a paid licence emits real `G0`s, so
`isSafeToRapid()` is never consulted. It is `visible: false` and has **no `group`**, so no dialog offers
it and the property dump ignores it — and because the dump is how a file records what produced it,
`validateJob()` announces the hook in both channels instead. **The design rule it carries:** every rapid
the post makes on its own behalf goes through `emitRapid()`, never `onRapid()`, so the hook can capture
only what Fusion delivered. `integration.md` §6.5 is the mechanism and the guards.

*(It replaces `Personal.cps`, a git-excluded copy of the post carrying the same edits by hand. That copy
went stale unnoticed — a harness that is a duplicate does not fail loudly, it answers questions about a
post that no longer exists — and its evidence could only ever be about *logic*, never about what the post
emits. The hook tests the deliverable, so that limit is gone. Any `Personal.cps` still on disk is dead.)*

**The post runs without Fusion, and `integration.md` is how.** `post.exe` over the intermediate `.cnc`
files, driven by `tools/post-run.ps1` for one job or by the four matrices in `tools/` for many — that
file owns the machinery, the property-coverage measure and the bounds. What a row settled that way may
claim is `findings.md` §4's `utility` method. Three facts about it are design's rather than the
harness's, and only these are stated here:

**It is the only check that answers *does the post run at all*.** `PV-1` was a crash in the first
statement of `onOpen()` that `node --check` passes and a code walk had no way to see, and it stood for
four commits. A walk proves what the post writes given a configuration; it cannot prove the post
executes.

**Every `.cnc` Autodesk ships uses one work offset**, censused 2026-08-16 across the whole library. So
`Each New WCS / Part`, `writeWCS()`'s traverse arm and `writeWcsOnReturn()` — a third of the multi-part
design — were unreachable from that library by any harness, and Fusion can produce such a job only by
hand and only with a licence. `tools/wcs-jobs/` closes it by **splicing rather than authoring**: each
job is a byte copy of one Autodesk file's blocks with at most one 32-bit word changed per block, so
two blocks in different offsets are the same operation with one variable moved and any difference in
the output is attributable to the WCS logic rather than to a fixture. **The same splice reaches the
jet tool and the change into one**, drawing blocks from a milling source and a laser source, which is
how `PR-22` and the `canProbe`-false arms came to be posted at all. **The XML serialisation cannot
substitute** — its reader silently drops `work-offset` and every section arrives as offset 0, verified
by editing that attribute in Autodesk's own `Milling/2D/bore.xml` and posting it.

**A green matrix is not a verified post.** All three findings these matrices have returned came from
**reading the passing output**, and two of the cases themselves were passing while asserting nothing
useful. A green run means the questions asked were answered, not that the right questions were asked.

**`git commit -m` with a PowerShell here-string mangles messages containing double quotes.** Write the
message to a file and use `git commit -F`, or pipe it in.

---

## References

- **PostProcessor API class reference** — <https://cam.autodesk.com/posts/reference/classPostProcessor.html>
- **Post Processor Training Guide (PDF)** — <https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf>
- **Dumper post** — emits every property/parameter/section value Fusion exposes; run it before relying on
  anything: <https://cam.autodesk.com/hsmposts?p=dump>
- **Library of existing posts** — <https://cam.autodesk.com/hsmposts> · **Forum** —
  <https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218>

Firmware: Marlin <https://marlinfw.org/meta/gcode/> · GRBL 1.1 <https://github.com/gnea/grbl/wiki> ·
FluidNC <http://wiki.fluidnc.com/> · Duet/RRF <https://docs.duet3d.com/User_manual/Reference/Gcodes>
