# Machine frame, fixed Z reference, and the operational flow — design review

> **Status: this is not a contracted document.** It is deliberately outside the system described in
> `docs/conventions.md` → *Document contracts*: it is **not size-gated, not tally-checked, not parsed
> by `docs/check-docs.js`, and referenced by no other document.** Nothing points at it and nothing
> will notice if it goes stale — which is the real cost of working outside the contract system, and
> the reason the contracted files exist. Treat every claim here as true as of **2026-08-05** and
> verify against the post before acting on it.
>
> It records a **design and a decision**. No code has been written against it.

---

## 1. What this reviews, and the question behind it

Four dialog groups each ask the operator a question in isolation:

| Group | Asks |
|---|---|
| `4 - Establish Machine Coordinates` | which homing command to emit |
| `5 - Establish Spoilboard Reference` | whether to reserve a WCS, and whether to probe it |
| `6 - On WCS / Part / Fixture Changes` | how to establish each part's origin |
| `7 - Tool Changes` | where to park, and whether to re-probe |

The answers do not compose. The question behind the review is whether group 4 is collecting the right
information at all — it asks **what operation to perform**, where every consumer needs to know **what
is trustworthy in the machine frame**. Everything else follows from that one substitution.

---

## 2. The three defects

### 2.1 Group 4 collects an action; every consumer needs a capability

`machineHomeBeforeStart` (`None` / `XY` / `XYZ`) has exactly **two** functional read sites:
`writeMachineHoming()` at `MPCNC_v4.0_Beta2.cps:2675`, which picks the command, and the CR-2 warning
at `:1517`. Nothing else in the post consults it.

And `writeMachineHoming()`'s own header comment says what the consequence is:

> Z homing (mode XYZ), where wired, is included for its own reason (a real endstop, or the Marlin
> plate-homing trick) — **it is never in service of MCS and never becomes the everyday Z reference**,
> which stays the work-Z touch-off (probeOnStart / probeOnChange) regardless.

So an operator who declares that their machine homes Z has told the post something true and
load-bearing. The post emits `G28 Z`, and discards the fact. It then asks that same operator to
reserve a WCS register and probe a spoilboard in order to reconstruct the datum homing already gave
them.

`conventions.md` → *Machine frame (homing / MCS)* records the design intent honestly — *"the modes
document operator intent, not an axis mask"* — but operator intent is not what any downstream feature
needs. It needs a capability declaration.

### 2.2 The reserved base and a trusted machine Z are two implementations of one concept

The concept is **the job's fixed Z reference**: a frame whose Z0 does not move with stock thickness,
which is the only frame in which a clearance height is meaningful across parts of differing
thickness. `conventions.md` → *Reserved spoilboard base* states exactly that, and it is why Guard B
requires a base for the cross-part retract.

There are two ways a machine can have such a frame:

1. **A probed spoilboard in a reserved WCS** — what the post supports today.
2. **A homed machine Z** — what the post ignores.

Because only the first is exposed, Guard B at `:1554` **rejects** a multi-WCS job on a machine whose
homed Z would serve perfectly:

```
error("Safe-Z across parts requires a base: reserve a spoilboard base (\"Reserved WCS\"),
       or turn off \"Retract Across Parts\".")
```

The cost is not only the rejection. A reserved base **consumes a WCS register**, and GRBL has six. A
six-fixture job plus a reserved base does not fit.

### 2.3 Four "safe Z" numbers, four frames, and the dialog names the frame of none

| Property | Group | Measured in |
|---|---|---|
| `Map: Safe Z to Rapid` | 3 | the operation's own Z (per-operation, F360 levels) |
| `Safe Z` | 6 | the part's WCS |
| `Inter Part Safe Z` | 5 | the reserved base's WCS |
| `Tool Change Z` | 7 | whichever WCS happens to be active |

The last is flagged in the post's own source at `:3486` as *"likely a bug, not intended behavior"* —
the physical park point silently drifts to wherever this job's WCS is zeroed.

Under a single named datum, two of the four collapse onto it, and the remaining two have a statable
rule rather than an accident: `Safe Z` is part-relative because a post-probe retract is measured from
the surface just probed, and `Map: Safe Z to Rapid` is operation-scoped because it answers a
narrower, per-operation question (`conventions.md` → *Traverse clearance is not the G1→G0 plane*).

---

## 3. The sign problem — and why "name the Z arrangement" is the wrong fix

The first draft of this design proposed an enum: `Z Home` = `None` / `Top of travel` / `Plate or
switch at the bed`, on the reasoning that a LowRider homing Z at the top puts machine Z0 above
everything (clearances negative) while an MPCNC homing down onto touch paint puts Z0 near the bed
(clearances positive).

**That enum cannot pin the sign, and is rejected.** Two facts are independent:

- **Where the switch is** — top of travel, or at the bed.
- **What machine-coordinate value the controller assigns at that switch.** This is a configuration
  choice, not a consequence of the switch position: GRBL's homing-direction mask `$23` with max
  travel `$130`–`$132`; Marlin's `Z_HOME_DIR` with `Z_MIN_POS` / `Z_MAX_POS`.

So a machine that homes at the top can end up with Z0 *at the top* and a negative work space, or with
Z0 *at the bed* and home reported as a large positive number. An enum naming the switch position
would ship a control whose entire purpose was to pin the sign, and fail at it.

> **This is the plausible wrong answer, recorded on purpose.** It looks like it captures the datum. It
> captures the mechanism and leaves the datum unknown.

### 3.1 The fix — one signed number

In G-code machine coordinates **`+Z` is away from the work by definition**, on all three firmwares.
The direction is therefore never in question. The only unknown is *where Z0 sits*, and a single
measurement pins it:

| Property | Type | Meaning |
|---|---|---|
| **`Spoilboard Machine Z`** | signed number, mm; empty = unset | The machine-Z reading at the spoilboard surface. Read once off the sender's DRO after homing, by touching off on bare spoilboard. It is a property of the machine, not of the job, and never changes. |

Everything derives from it, with no sign reasoning by anyone:

```
datum          = spoilboardMachineZ                     (machine coordinates)
clearance      = spoilboardMachineZ + interPartSafeZ    (+Z is up, always)
emitted        = G53 G0 Z<clearance>
```

`Inter Part Safe Z` keeps precisely the meaning it has today: whole mm above the spoilboard.

Three properties of this design worth stating:

- **Fewer fields than the enum**, and it replaces a rule the operator must reason about with a number
  they measure once.
- **Immune to the firmware convention question.** Whatever GRBL, Marlin or RRF assigns at the switch,
  a reading taken from the controller is already expressed in the controller's own frame. The design
  does not wait on §8's source reads.
- **Checkable before the machine moves.** `writeResolvedValues()` already prints resolved heights into
  the header block, so the computed absolute machine Z can be echoed and read back.

### 3.2 The residual hazard, stated plainly

A mistyped `Spoilboard Machine Z` sends the tool to a wrong absolute height at travel speed. This is
the same *class* of hazard as the base probe's existing park-over-bare-spoilboard precondition
(`conventions.md` → *Reserved spoilboard base*: *"whatever is under the tool becomes the base's Z0"*),
but it differs in one way that matters: it is a **typed value rather than a physical act**, so it is
easier to get wrong without noticing. The header echo mitigates it; nothing eliminates it.

### 3.3 The touch-paint machine is not made safer, only cheaper

An MPCNC with the touch plate wired to both the home and probe inputs homes Z onto **whatever the
plate is resting on**. If the plate was on the stock rather than bare spoilboard, machine Z0 is the
stock top — the identical trap the base probe already has, arrived at by a different route. The
machine-Z datum removes a WCS register and a probe cycle from that machine's workflow. It does not
remove the precondition, and this document does not claim it does.

---

## 4. Decisions recorded

1. **The post will address the machine frame directly (`G53`), per axis, gated by an operator
   declaration.** This resolves the standing *"Never `G53`"* decision. `PReview.md` §6 requires that
   decision be settled across all three of its candidate uses at once — base probe point,
   tool-change park, cross-part retract — because they share one question: *does this post ever
   address the machine frame, or is everything work-relative?* The answer is now: **it addresses
   exactly the axes the operator declares, and nothing else.** `G53` appears nowhere in the post
   today; the only mention is the comment at `:3486` arguing that it should.

2. **The machine-frame unlock requires declared homed XY.** See §4.1 — the reasoning is sharper than
   "moving between WCS needs it," and the exception matters.

3. **A machine that declares nothing homed posts byte-identical output to today.** Non-negotiable;
   §7 is the requirement list.

### 4.1 Why homed XY is required, and the one case where it is not

A `G54`–`G59` register holds an offset **from machine zero**. Unhomed, machine zero is arbitrary but
still *fixed for that power cycle* — GRBL and RRF track machine position by step-counting from the
last reset, which the post's own comment at `:3491` already notes. So offsets **created during this
run** stay consistent with each other and with the bed, and a multi-part job built that way works.

What breaks is **trusting a stored offset**. After a power cycle machine zero has moved; the register
has not. Every offset a previous job wrote now points somewhere else. `conventions.md` → *Coordinate
model* records this for the first part only — *"`Home Before Start = None` + `Use Active WCS X0 Y0`
after a power cycle is quietly unsound"* — and it generalises to every mode:

| Origin mode (first or subsequent) | Needs declared homed XY? | Why |
|---|---|---|
| `Jog to X0 Y0 …` / `Jog to X0 Y0 Z0` | **No** | every origin is created this run |
| `Use Active WCS …` / `Skip` / `Probe Z` | **Yes** | a stored offset is repeatable only against a homed machine zero |
| `Set … to Current Pos` | No | but incompatible with homing for a different reason — CR-2 |

Two consequences:

- **The new guard is *stored-offset multi-WCS without declared homed XY*, and it must not fire on the
  `Jog to …` modes.** A false positive there would reject a legitimate no-endstop multi-part job —
  the machine the post exists for.
- **`probeOnChange` defaults to `Probe Z`**, which uses the stored XY. That is the
  unsound-without-homing case, it is the default, and **nothing warns today.**

One coupling deliberately **not** adopted: a pure `G53 G0 Z<n>` clearance move needs only machine Z
to be trustworthy — homed XY is irrelevant to a Z-only move. The declared-homed-XY requirement sits on
the *multi-part workflow the clearance serves*, not on the move, so the code must not carry a
dependency it does not have.

---

## 5. Proposed schema

Fusion post properties have no conditional visibility, so dependent fields follow the post's existing
convention: *"ignored when …"* stated in the tooltip.

### 5.1 Group 4 → `4 - Machine Frame`

Capability and action separated. This expresses a state today's enum cannot: *Z endstops exist and
were homed at the controller, but do not home them in this job.*

| Property | Type | Default | Replaces |
|---|---|---|---|
| `X/Y Home` | bool | off | the XY half of `Home Before Start` |
| `Machine Z Home` | bool | off | the Z half |
| `Home at Job Start` | bool — homes whatever is declared | off | the action half |
| `Prompt Before Home` | bool | off | unchanged |

Emission is unchanged in shape: GRBL/FluidNC one `$H` via `writeln()` — never `writeBlock()`, per
`HReview.md` CR-1 — and Marlin/RRF `G28 X` / `G28 Y` / `G28 Z` per declared axis.

**Declaring the machine frame is a trust assertion**, the same species as `Use Active WCS`: the post
commands the frame and can never read back where it is. The existing model already carries that
vocabulary — *"selection is deterministic, origin is trusted"* — so the declaration needs no new
justification machinery, only the same honesty about what it is.

### 5.2 Group 5 → `5 - Fixed Z Reference`

| Property | Change |
|---|---|
| `Fixed Z Reference` **(new)** | enum `None` / `Spoilboard (probed into a reserved WCS)` / `Machine Z (homed)`; default `None` |
| `Spoilboard Machine Z` **(new)** | signed mm, empty by default; read only under the `Machine Z` answer |
| `Reserved WCS` | unchanged; now explicitly a sub-question of the spoilboard answer |
| `Probe to Set Base` | see **E1** |
| `Retract Across Parts` | unchanged control, **relaxed guard** — satisfied by either datum |
| `Inter Part Safe Z` | unchanged whole-mm integer; tooltip names which datum it is measured in |

### 5.3 What group 7 inherits

The tool-change park gains the branch that is obviously right — a fixed physical spot, `G53 G0 X Y Z`,
available when `X/Y Home` and `Machine Z Home` are declared — and the *"likely a bug"* comment at
`:3486` resolves rather than being deleted unanswered.

**This must compose with `PReview.md` §2's settled Phase 4 park design, not replace it.** That design
decided two branches (base reserved → park relative to the base; no base → plain `G0` in the current
WCS) and explicitly said *"Never `G53`."* Decision 1 above reopens only the third branch; the two
existing branches stand for machines that declare nothing. Phase 4 should land first or land together
— not be re-litigated by this document.

---

## 6. Expert-operator review: what to eliminate or gate

### E1 — `Probe to Set Base = None` states a precondition it does not have

The option means *"a previous job set the base's Z0; trust it."* That Z0 is an offset from machine
zero, so **a power cycle on a machine with no Z home invalidates it silently** — machine zero moved,
the register did not. The tool then descends to a clearance that is wrong by however far machine zero
drifted, and the file says nothing.

The current tooltip says only *"assume the base was set in a previous job (probe-once / run-many)"*.
Two cases are actually sound:

- **A machine that homes Z** — where `Fixed Z Reference = Machine Z` is strictly better: no register
  consumed, no probe, no stale value.
- **A machine never reset or powered off between jobs** — real, but not what the tooltip says.

**Recommended: eliminate the option.** Its only durable use has a better answer under the reframing.
The alternative — keep it and state the precondition (*"invalid after a controller reset or power
cycle unless the machine homes Z"*) — is acceptable but leaves a footgun in the dialog.

Either way **this is a defect in the current dialog, independent of the reframing.** Removing an enum
`id` resets that property to its default (`conventions.md` → *Property / dialog conventions*) — a
release-notes item.

### E2 — the four `Jog to …` modes cannot work on GRBL, the default firmware

**The post's own code is the evidence.** `askUser(text, title, allowJog)` at `:3437`–`:3455` consumes
`allowJog` in the **RepRap branch only**, where it appends `X1 Y1 Z1` to `M291` — RRF's genuine
jog-during-message flag. The GRBL branch emits a bare `M0` with a `(MSG …)` comment and **discards the
parameter entirely.** The Marlin/default branch discards it too.

On GRBL 1.1, `M0` puts the controller into a hold state, and `$J=` jog commands are accepted only from
Idle/Jog — so the operator cannot jog at the pause without resetting the program. *(Confirm from the
GRBL wiki's jogging page before writing the warning text — see §8. No controller is needed.)*

`conventions.md` already half-knows this — *"both defaults are no-prompt modes because jogging at a
pause isn't universally supported"* — but **four dialog options** across `probeOnStart` and
`probeOnChange` still advertise the capability by name, and GRBL is both the post's default firmware
and the hobbyist's usual controller.

**Recommended: gate, do not delete.** The modes are correct on RepRap, where `M291 … X1 Y1 Z1` is a
real jog-at-pause; deleting them would remove a working professional workflow. Add a post-time
`warning()` in `validateJob()` plus an Important comment in the file when a `Jog …` mode is selected on
GRBL, naming what the operator will actually get.

This is the highest-value item in this document **for the hobbyist**, and it is independent of
everything else here.

### E3 — the `Z Home` arrangement enum

Rejected in §3 before it shipped. Recorded because it is the plausible wrong answer.

### Observations — not recommendations

- **`Reserved WCS` offers nine slots** where one is recommended and one (`G54`) is nearly always an
  immediate Guard A error, since parts default to `G54` too. Worth revisiting once the control is a
  sub-question rather than a headline; not proposed here.
- **`Probe with G38.2` is effectively Marlin-only.** GRBL ignores it, and RRF should be left on. Its
  own tooltip says so. Dialog noise for two of three firmwares, but harmless.
- **`Prompt Before Home` is inert when homing is off.** Already documented; no change.
- **`Tool Change Probe` (`includeProbeFile`) is still declared and never read** — `HReview.md` HR-21 /
  CR-15, already tracked. Named here only so this review is not read as having missed it.

---

## 7. Does this make operational use easier?

**Net yes.** Where it does not, it says so.

### Easier

- **The single largest gain: machine facts and job decisions become separate questions.** `X/Y Home`,
  `Machine Z Home` and `Spoilboard Machine Z` are properties of the machine — set once, never touched
  again. `Home at Job Start` is a property of the job. Today `Home Before Start` mixes both into one
  enum, so its answer changes per job for no reason, and the capability half is re-declared every time.
- **One datum question** replaces *reserve a WCS?* + *probe it?* + the unstated knowledge that those
  were the only route to a cross-part clearance.
- **Guard B stops rejecting valid jobs**, and a multi-WCS job on a homed-Z machine consumes **no** WCS
  register.
- **The tool-change park gets a fixed physical spot**, and a known bug resolves with it.
- **CR-2's advice becomes constructive.** Today it says *don't use `Set … to Current Pos` with
  homing*. With XY declared homed, a stored fixture offset is meaningful, so `Use Active WCS X0 Y0` is
  the natural first-part mode — advice rather than prohibition.
- **The four safe-Z numbers acquire a rule.** Two collapse onto the datum; the other two are
  part-relative and operation-scoped *for reasons that can be stated*.
- **E2's warning tells a hobbyist why something didn't work** instead of leaving them to guess.

### Harder — named, not glossed

- **Four more fields.** Group 4 goes 2 → 4, group 5 goes 4 → 6; 68 properties become 72. Justified
  only because the old enum conflated capability with action and the datum genuinely needs a number,
  but it is real dialog growth in a dialog that is already large.
- **A new manual measurement.** `Spoilboard Machine Z` must be read off the DRO. Once per machine, not
  per job — but it is a step that did not exist, and it is the first time the post asks the operator
  for a number they cannot get from Fusion.
- **A typed number that can crash the machine.** §3.2. Mitigated by the header echo, not eliminated.
- **Key renames reset saved presets.** Replacing `machineHomeBeforeStart` resets it, per
  `conventions.md`. A release-notes item, and the second such reset in the beta.

---

## 8. Hobbyist protection — requirements on the build

The hobbyist persona is HP-1: one Setup, one operation, one tool, GRBL/mm, pre-jogged XY, touch plate,
no endstops. Every item below is a requirement, not an aspiration.

1. **Every new field defaults to off or empty** — `X/Y Home` off, `Machine Z Home` off, `Home at Job
   Start` off, `Fixed Z Reference = None`, `Spoilboard Machine Z` empty — so the factory-default job
   emits **byte-identical output**. Verified by posting, diffed against the pre-change build.
2. **No new field is required to post, and no new guard can error a default job.** Every guard in §9
   fires only after a deliberate declaration.
3. **The dangerous number is three deliberate acts away.** `Spoilboard Machine Z` is inert unless
   `Fixed Z Reference = Machine Z`, which is itself guarded on `Machine Z Home`.
4. **All new fields sit in groups the README already tells the hobbyist to leave alone.** The hobbyist
   flow — pre-jog, post, touch off — is untouched.
5. **The hobbyist gains something.** E2's GRBL warning explains why *"Jog to X0 Y0"* did not let them
   jog; today they get a bare `M0` and no explanation. That item does not depend on the reframing and
   could ship on its own.
6. **Graceful degradation is preserved in shape**, per `conventions.md` → *Context and stance*: every
   advanced feature stays opt-in and emits nothing until enabled.

---

## 9. Guards and warnings the build must implement

| | Rule | Status |
|---|---|---|
| **Guard B** | multi-WCS + `Retract Across Parts` requires **a** fixed Z datum — either kind | relaxed |
| new | `Fixed Z Reference = Machine Z` with `Machine Z Home` off, or `Spoilboard Machine Z` empty → `error()` | new |
| new | machine-frame features (`G53` park, machine-Z datum) require `X/Y Home` → `error()` | new |
| new | multi-WCS trusting **stored** offsets with `X/Y Home` off → `warning()`. **Must not fire on the `Jog …` modes** (§4.1) | new |
| new | a `Jog …` mode selected on GRBL → `warning()` + Important comment (**E2**) | new |
| **CR-2** | homing + a `Set … to Current Pos` origin mode | unchanged; advice reworded |
| **Guard A** | no redefine of the reserved base | unchanged |
| **Guard C** | Marlin is single-frame, so machine-frame features are GRBL/RRF only — same shape as today's base features | unchanged |

Placement matters: `conventions.md` → *Validation guards* records that a guard in `onOpen()` refuses
before any output and leaves **no file**, while a guard in `onSection()` leaves a **truncated
`.gcode`**. All of the above are configuration guards and belong in `validateJob()`, i.e. `onOpen()`.

---

## 10. Firmware questions, to be settled from source

No controller is available, so each is a source read with file and version cited, per `CLAUDE.md`.
**None blocks the design** — the signed-number datum of §3.1 is convention-independent — but each must
be answered before the corresponding code is written.

| Question | Source | Drives |
|---|---|---|
| GRBL `M0` hold state vs `$J=` jogging | GRBL 1.1 wiki, jogging page | E2's warning text |
| `G53` on Marlin 2.x — unconditional, or build-gated? | `MarlinFirmware/Marlin`: `Marlin/src/gcode/gcode.cpp`, `Configuration_adv.h` | whether Marlin needs an explicit exclusion beyond Guard C |
| `G53` on RepRapFirmware | `Duet3D/RepRapFirmware`: `src/GCodes/GCodes2.cpp`, plus the wiki changelog | RRF support for the park and the datum |
| GRBL `$H` with a partial axis config — does a machine with only X/Y endstops home cleanly? | GRBL wiki / FluidNC wiki | whether `X/Y Home` alone is emittable |
| **GRBL `G53` — already answered** | `conventions.md` → *Firmware capabilities* records `G53` in GRBL 1.1's supported set | no work |

Marlin is already excluded from multi-WCS work by Guard C, so the Marlin read most likely confirms an
existing exclusion — but per `conventions.md` it must be **read, not assumed**.

---

## 11. If this is built

Sequencing notes, not a schedule — the ordered list of work lives in `docs/plan.md`.

- **E2's GRBL jog warning is independent** of everything else and is the cheapest hobbyist-visible win
  here. It could ship alone.
- **E1** is likewise independent — a dialog defect on its own terms.
- **The `G53` park branch shares code with `PReview.md` §2's settled Phase 4 tool-change reorder**, so
  the reframing should not land before it. §5.3.
- **The durable half migrates on build, not before.** When code lands, `conventions.md` gains the
  fixed-Z-datum concept (two implementations of one frame) and the machine-frame trust assertion, under
  *Coordinate model* / *Machine frame*. Until then it stays here: that file's contract forbids unbuilt
  design.
- **Test rows a build would need**, in the shape `PReview.md` §3 uses: a default job proving
  byte-identical output (§8.1); a homed-XYZ multi-WCS job with no reserved base, proving Guard B's
  relaxation and one `G53 G0 Z` per traverse with the arithmetic of §3.1 visible; each new guard's
  refusal; a `Jog …` mode on GRBL proving E2's warning; and a `G53` park proving it lands at the same
  physical spot under two different WCS.
