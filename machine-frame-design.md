# Machine frame, fixed Z reference, and the operational flow — design review

> **Status: this is not a contracted document.** It is deliberately outside the system described in
> `docs/conventions.md` → *Document contracts*: it is **not size-gated, not tally-checked, not parsed
> by `docs/check-docs.js`, and referenced by no other document.** Nothing points at it and nothing
> will notice if it goes stale — which is the real cost of working outside the contract system, and
> the reason the contracted files exist. Treat every claim here as true as of **2026-08-05** and
> verify against the post before acting on it.
>
> **The design has since landed, and the dialog it specifies has since been consolidated.** This file
> is now a *record of the reasoning*, not a description of the shipped dialog. Two of its property
> decisions were superseded by `PReview.md` **PR-5**, and every section below that names them is
> stale in exactly that way:
>
> | This document says | The post now has |
> |---|---|
> | `X/Y Home` + `Machine Z Home` — two booleans (§5.1, §6, §9) | one enum, `Axises Homed and Trusted` = `None` / `XY Only` / `Z Only` / `XYZ` — information-identical, read only via `machineHomesXY()` / `machineHomesZ()` |
> | `Inter Part Safe Z` (whole-mm integer, default 40) **and** `Travel Machine Z` (signed string, empty) as two fields (§3.2, §5.1) | one `Inter Part Travel Z`, signed string, **empty by default**, whose frame follows `Fixed Z Reference` |
> | `Home at Job Start` **and** `Prompt Before Home` — two booleans (§5.1, §6) | one enum, `Home at Job Start` = `Off` / `Home` / `Pause, then Home` (`PReview.md` **PR-7**). §6's *"`Prompt Before Home` is inert when homing is off"* is why: that state is now unreachable rather than merely documented |
>
> The *arguments* below survive both merges intact — §3.2's "collected, never derived", §3.3's
> rejection of every reference-plus-delta pair, and §5.2's proof that the height cannot be a numeric
> property are what the merged field still rests on. What changed is how many dialog rows carry them.
> **`docs/conventions.md` → *Frames* is the current model**; where the two disagree, it wins.

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

## 3. How to collect the clearance — the sign problem, and the number that dissolves it

The first draft of this design proposed an enum: `Z Home` = `None` / `Top of travel` / `Plate or
switch at the bed`, on the reasoning that a LowRider homing Z at the top puts machine Z0 above
everything (clearances negative) while an MPCNC homing down onto touch paint puts Z0 near the bed
(clearances positive).

**That enum cannot pin the sign, and is rejected.** Two facts are independent:

- **Where the switch is** — top of travel, or at the bed.
- **What machine-coordinate value the controller assigns at that switch.** This is a configuration
  choice, not a consequence of the switch position — and on GRBL it is not even a *runtime* choice.
  `grbl/config.h` carries **`HOMING_FORCE_SET_ORIGIN`**, whose whole purpose is to *"force Grbl to
  always set the machine origin at the homed location despite switch orientation"*; with it left at
  the default, Grbl sets the origin in negative space **regardless of where the switch sits**. It is
  compile-time, so no `$` query exposes it and no operator can report it without reading their own
  build. (`$23` sets the homing *direction*; `$130`–`$132` are documented as used only by the
  soft-limit feature. Neither settles the datum — the pair cited in an earlier draft was the weaker
  evidence.) Marlin's equivalent is `Z_HOME_DIR` with `Z_MIN_POS` / `Z_MAX_POS`.

So a machine that homes at the top can end up with Z0 *at the top* and a negative work space, or with
Z0 *at the bed* and home reported as a large positive number. An enum naming the switch position
would ship a control whose entire purpose was to pin the sign, and fail at it.

> **This is the plausible wrong answer, recorded on purpose.** It looks like it captures the datum. It
> captures the mechanism and leaves the datum unknown.

### 3.1 What the clearance is actually for — and why no spoilboard measurement is needed

The height exists to guarantee exactly one thing: **the tool tip is above everything on the bed** —
the tallest fixture, clamp or part in the job. It does not need to be a known distance above the
spoilboard.

The spoilboard was only ever the *means*. `conventions.md` → *Reserved spoilboard base* reaches for it
because it is *"the one frame in which a safe height is meaningful across parts of differing
thickness"* — the property being bought is **independence from stock thickness**, not the spoilboard
itself. **A homed machine Z is another such frame**, and it delivers the same guarantee with the
spoilboard appearing nowhere.

So the answer is yes: the measurement is avoidable. An earlier draft of this document asked for
`Spoilboard Machine Z` — a touch-off on bare spoilboard — and that was the wrong number. It made the
machine-Z route inherit a probe cycle and a park-over-bare-spoilboard precondition that the route does
not actually need.

### 3.2 The fix — one absolute machine Z, no touch-off, no arithmetic

| Property | Type | Meaning |
|---|---|---|
| **`Travel Machine Z`** | signed mm — a **string** property, so that unset is expressible; see §5.2 | The machine Z the tool holds while travelling between parts. Obtained once per machine: home, jog to a height that visibly clears every fixture and part, read Z off the sender's DRO. |

```
emitted = G53 G0 Z<travelMachineZ converted to output units>
```

That is the whole derivation. No datum, no delta, no sign to reason about, and **no touch-off of any
kind** — the operator reads a number off a position they have physically jogged to and looked at.

**Two conditions the emission inherits**, both from the `G53` definition rather than from this design.
`G53` *"is not modal and must be programmed on each line"* (LinuxCNC G-code reference; RepRapFirmware
states the same), so a move split into `Z` then `X Y` needs `G53` on **both** blocks. And *"it is an
error if `G53` is used without `G0` or `G1` being active"* — the motion word may be modal, but the
design should not depend on that.

Five properties worth stating:

- **One field, not two**, and it is the number the move needs — subject only to the mm→output-unit
  conversion every dimension in this dialog already gets. Nothing is *derived* from it: no datum, no
  delta, no sum. The unit conversion is the one arithmetic step, and it is the same one `Inter Part
  Safe Z` and the probe offsets pass through today.
- **Its evidence is better than arithmetic.** With `Spoilboard Machine Z + Inter Part Safe Z` the
  operator computed a height and trusted the sum; here they *jogged to the height and saw it clear.*
- **Immune to the *sign* convention of §3, not to units.** Whatever GRBL, Marlin or RRF assigns at the
  switch, a reading taken off the DRO is already in the controller's own frame — that is the whole
  point, and §3's compile-time trap cannot touch it. Units are a separate question and are **not**
  immune: a `G53` move is interpreted in the active `G20`/`G21` units, so `G53 G0 Z-12` in an inch
  file means −12 **inches**; and GRBL's `$13` switches position *reporting* to inches, so the number
  the operator reads may not be mm either. Hence the conversion above, the mm in the tooltip, and the
  echo below.
- **Stock-thickness independent**, which was the entire point of preferring the spoilboard over the
  stock top. An absolute machine Z has that property natively.
- **Checkable before the machine moves.** `writeResolvedValues()` already prints resolved heights into
  the header block **in output units** — the form it uses for `Inter Part Safe Z` — so the emitted
  absolute machine Z can be echoed and read back in exactly the units the `G53` block will carry.

Under this scheme `Inter Part Safe Z` is **not used at all** when `Fixed Z Reference = Machine Z`; it
remains the height for the spoilboard-WCS answer, where it keeps its current meaning. One height
control per datum, each measured in its own frame, and the tooltip of each says which.

### 3.3 Rejected alternatives, and why

- **`Spoilboard Machine Z` + `Inter Part Safe Z`** *(this document's own first answer)*. Two fields, a
  sum, and a touch-off that must land on bare spoilboard — importing the base probe's precondition into
  a route that had no need of it. Superseded by §3.2.
- **`Machine Z at Home` + a signed delta.** Better than the spoilboard reading: the home value is free
  — home, read the DRO, no touch-off. But it is still two fields and a sum, and it buys nothing that
  §3.2 does not. Worth recording because it is the natural half-step, and because it exposes a fact
  that makes §3.2 obviously right: on a **top-of-travel** machine, home is *already* above everything,
  so the delta's best value is zero; on a **plate-at-the-bed** machine, home ≈ the spoilboard, so the
  delta *is* `Inter Part Safe Z`. Two machines, two unrelated meanings for one field — a field that
  should not exist.
- **`G30` predefined position — "zero fields". Rejected; the source read came back dirty on all three
  firmwares.** The idea was that the operator stores a safe height in the controller once with
  `G30.1`, and the post emits `G30 Z` and holds no number at all. It fails three ways, and any one of
  them is fatal:
  - **GRBL / LinuxCNC dialect.** *"`G30 axes` — makes a rapid move to the position specified by axes
    including any offsets, then will make a rapid move to the absolute position of the values in
    parameters 5181-5189 for all axes specified. Any axis not specified will not move."* (LinuxCNC
    G-code reference; `gnea/grbl`, `grbl/gcode.c`, `NON_MODAL_GO_HOME_0/1`, whose intermediate move is
    `if (axis_words) { mc_line(gc_block.values.xyz, pl_data); }` under the comment *"Move only the
    axes specified in secondary move."*) So a **bare `G30` moves X and Y as well as Z** — not a
    clearance move at all — while **`G30 Z<n>` requires a number**, which is not a zero-field option,
    and rapids *first* to that Z **in the current WCS, including its offsets**. That intermediate move
    is in precisely the frame §3.6 exists to stop trusting.
  - **Marlin 2.x.** `Marlin/src/gcode/gcode.cpp` (2.1.x): `#if HAS_BED_PROBE` → `case 30: G30();
    break;   // G30: Single Z probe`. `G30` is a **probing plunge**, not a park. There is no `G30.1`.
  - **RepRapFirmware.** The RepRap G-code dictionary lists `G30` as **"Single Z-Probe"**, supported in
    RRF — the same collision.

  On top of which it was always controller EEPROM state the post can neither read nor verify, and
  opaque to an operator reading the g-code where `G53 G0 Z-12` is self-describing. **The elegance was
  an artefact of assuming one dialect** — `conventions.md` → *Firmware capabilities* already records
  the same trap for `G80`–`G83`, where the RepRap dialect reassigns the numbers to bed probing. Same
  failure, one section further on.
- **The `Z Home` arrangement enum.** §3, above. It cannot pin the sign it exists to pin.

### 3.4 The residual hazard, stated plainly

A mistyped `Travel Machine Z` sends the tool to a wrong absolute height at travel speed. This is the
same *class* of hazard as the base probe's existing park-over-bare-spoilboard precondition
(`conventions.md` → *Reserved spoilboard base*: *"whatever is under the tool becomes the base's Z0"*),
and it differs in one way that matters: it is a **typed value rather than a physical act**, so it is
easier to get wrong without noticing.

Two things reduce it relative to the two-field scheme, and neither eliminates it: the number is read
from a position the operator jogged to and inspected, and there is no sum in which a sign error can
hide. The header echo is the last line of defence.

**The second hazard is transplant, not typing, and it is the one with no precedent in this dialog.**
`Travel Machine Z` is a fact about *a machine*, held in a dialog whose values travel with the Fusion
document. Copy a Setup, share a design, post someone else's file on your own machine, and the number
arrives with it — correct for a machine that is not this one. Every other dangerous height in this
dialog is WCS-relative and therefore self-correcting: point it at a different machine and it is still
measured from that machine's work zero. This is **the first absolute machine-frame number the post
would ever emit**, so it is also the first that a transplant makes wrong rather than merely different.
The tooltip must say the number belongs to the machine, not to the job.

### 3.5 The touch-paint machine is not made safer, only cheaper

An MPCNC with the touch plate wired to both the home and probe inputs homes Z onto **whatever the
plate is resting on**, so its machine Z0 is only as good as where the plate sat. Under §3.2 that
matters less than it did under the spoilboard scheme — `Travel Machine Z` is read *after* homing, so it
already incorporates whatever Z0 the homing produced — but it does not vanish: if the machine is
re-homed against a differently-placed plate and the stored number is not re-read, the height is wrong.
The machine-Z route removes a WCS register and a probe cycle from that machine's workflow. It does not
make the machine's Z0 trustworthy, and this document does not claim it does.

**And the failure is loud on one firmware only.** With homing enabled, GRBL comes up in **Alarm and
refuses all motion until the machine is homed**, so the worst case — a declared machine Z that belongs
to a previous power cycle — cannot execute there: the job stops before the first move. Marlin and RRF
have no equivalent lock, so the same misconfiguration on those firmwares simply *runs*, at a height
measured from a machine zero that has moved. That asymmetry is why §5.2 requires the homing action and
not merely the declaration.

### 3.6 A hard limit this lifts

`conventions.md` → *Why the first section's arrival is asymmetric* records that **with no base reserved
there is no established frame at job start at all**, so the first section's safe arrival cannot be
made safe and gets an Info comment instead of a move — `Ensuring that Z is safe. Unknown Z for XY
move.`, emitted from `partProbe()`'s `zUnknown` path at `:2881`.

A declared machine Z **is** an established frame at job start. So on such a machine that limit is
lifted: the first section's arrival can emit a real `G53 G0 Z<travelMachineZ>`, and the `zUnknown`
suppression at `:2881` should extend to cover it exactly as it already covers an established base.
This is a safety improvement, not a convenience — it is the one path in the post that deliberately
emits no absolute Z move.

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

3. **A machine that declares nothing homed changes no motion, no command and no non-dump comment.**
   Non-negotiable; §7 is the requirement list.

   > **Corrected on build — this said *byte-identical output*, and that was not achievable.** Adding
   > four properties necessarily changes the header property dump, which lists every one of them;
   > the rule as written could only have been satisfied by not adding the fields. It was also
   > already dead: `conventions.md` → *Context and stance* records that the byte-identical-default
   > guarantee went when the dump shipped (**HR-1**, CR-6), and that a default-output change is a
   > decision to be argued rather than a line that cannot be crossed. **The invariant that survives
   > is the one worth checking** — the dump may change *and nothing else may*.

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

**On stock GRBL the split is bookkeeping, not emission — say so rather than implying otherwise.**
Which axes `$H` homes is fixed at **compile time** by `HOMING_CYCLE_0/1/2` in `grbl/config.h` (default
`Z` first, then `X|Y`), and the per-axis commands `$HX` / `$HY` / `$HZ` sit behind
`HOMING_SINGLE_AXIS_COMMANDS`, which is **disabled by default**. Two consequences: the post can neither
emit per-axis homing there nor *corroborate* the declaration against anything; and a no-Z-endstop
machine running GRBL has already had its homing cycle recompiled, because the stock default would try
Z first. **FluidNC is the exception** — it exposes single-axis homing as a per-axis configuration
option, so `$HX` / `$HZ` are available without a rebuild. The post treats FluidNC as GRBL throughout,
and this is the one place in the design where that conflation costs something real: on FluidNC the
capability/action split could actually emit what it declares.

**Declaring the machine frame is a trust assertion**, the same species as `Use Active WCS`: the post
commands the frame and can never read back where it is. The existing model already carries that
vocabulary — *"selection is deterministic, origin is trusted"* — so the declaration needs no new
justification machinery, only the same honesty about what it is. What §5.2 adds is the one place that
honesty is not enough: when the declared frame becomes a **datum for an absolute move**, the job must
establish it rather than assert it.

### 5.2 Group 5 → `5 - Fixed Z Reference`

| Property | Change |
|---|---|
| `Fixed Z Reference` **(new)** | enum `None` / `Spoilboard (probed into a reserved WCS)` / `Machine Z (homed)`; default `None`. The `Machine Z` answer **requires `Home at Job Start`** — see below |
| `Travel Machine Z` **(new)** | signed mm, empty by default; read only under the `Machine Z` answer. §3.2. **Type `string`, parsed** — see below |
| `Reserved WCS` | unchanged; now explicitly a sub-question of the spoilboard answer |
| `Probe to Set Base` | see **E1** |
| `Retract Across Parts` | unchanged control, **relaxed guard** — satisfied by either datum |
| `Inter Part Safe Z` | unchanged whole-mm integer; tooltip names which datum it is measured in |

**`Machine Z` requires the homing *action*, not just the declaration.** `Machine Z Home` on with `Home
at Job Start` off is the state §5.1 was written to express — and it is exactly the stale-frame case E1
rejects `Probe to Set Base = None` for: after a power cycle the frame moved and the declaration did
not. Here it is worse than E1's case, because the stale frame drives an **absolute rapid** rather than
a clearance, and §3.5 shows two of the three firmwares execute it silently. So when `Fixed Z Reference
= Machine Z`, the job homes: the frame the file trusts is one the file established.

> **Rejected: warn instead of require.** It preserves §5.1's *"declared but not homed this job"* state
> for the datum case, at the price of leaving in the dialog the exact footgun E1 asks to have removed —
> one frame further from the operator, and on Marlin/RRF with nothing to stop it. The state survives
> everywhere else; it simply cannot be the basis of an absolute move.

**`Travel Machine Z` cannot be a numeric property.** Fusion's property-definition schema (`id`,
`title`, `description`, `group`, `type`, `range`, `scope`; types `enum` / `spatial` / `angle` /
`number` / `integer` / `boolean` / `file` / `folder`) has no way for a numeric field to be *unset* —
it always holds a value, so "empty" is not expressible and a sentinel like `0` is a real height. It
follows the `Safe Z` precedent instead: a **string** property, parsed, with empty meaning unset. That
is what §9's *"`Travel Machine Z` empty → `error()`"* guard reads.

*(The same schema is why this section opens with "no conditional visibility": there is no visibility or
enablement field to use. The `"ignored when …"` tooltip convention is not a workaround, it is the
whole mechanism.)*

### 5.3 What group 7 inherits

The tool-change park gains the branch that is obviously right — a fixed physical spot in the machine
frame, available when `X/Y Home` and `Machine Z Home` are declared — and the *"likely a bug"* comment
at `:3486` resolves rather than being deleted unanswered.

**Two blocks, not one, and `G53` on each.** `G53` *"is not modal and must be programmed on each line"*
(LinuxCNC; RepRapFirmware says the same), so a single `G53 G0 X Y Z` would be both a three-axis
diagonal — which this post splits and orders precisely so it never drags through the part — and, once
split, a second block that silently loses its machine frame. The park is `G53 G0 Z<n>` then `G53 G0
X<n> Y<n>`, retract first, each carrying its own `G53` and an active `G0`.

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

On GRBL 1.1, `M0` puts the controller into a hold state, and the jogging documentation is explicit:
*"A jog command will only be accepted when Grbl is in either the 'Idle' or 'Jog' states."* (Grbl v1.1
Jogging, `gnea/grbl` wiki.) So the operator cannot jog at the pause without resetting the program.
**Settled from source — no controller and no further read is needed to write the warning text.**

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
- **`Probe with G38.2` is read on Marlin and RepRap only** — `probeTool()` at `:3565` takes a GRBL
  branch that emits `G38.2` **unconditionally**, without consulting the property. To be exact about
  what is ignored: **GRBL ignores the *setting*, not the command.** `G38.2` is fully supported on GRBL
  1.1 — `conventions.md` → *Firmware capabilities* lists `G38.2–G38.5` in its supported set — and is
  what a GRBL job always gets. The property's `Off` (`G28 Z`) path is defensible on a Marlin build
  **without `G38_PROBE_TARGET` compiled in** — `Marlin/src/gcode/gcode.cpp` gates `case 38:` behind it,
  so `G38.2` is a build option there, not a given — using the Z homing switch as a substitute.
  **The RepRap half of this needs a version bound, and an earlier draft of this observation was wrong
  without one.** Duet's documentation: `G38.x` is supported on **Duet 2 and later** in **RRF 3 and
  later**, and *up to RRF 3.1.1 the `G38.2` target coordinates are expected to be **machine
  coordinates**; after 3.1.1 they are user coordinates.* This post emits a **work-frame** Z target, so
  on RRF ≤ 3.1.1 leaving the property On probes to a machine-frame Z — a wrong physical motion, and a
  worse outcome than the `G28 Z` fallback. Leave it On on RRF **> 3.1.1**; below that the control is
  not the operator's real problem. So: *useful* on one firmware of three, *readable* on two,
  *version-bound* on one — worth a tooltip that says which firmware and which version it is for, not
  the removal an earlier draft of this document implied.
- **`Prompt Before Home` is inert when homing is off.** Already documented; no change.
- **`Tool Change Probe` (`includeProbeFile`) is still declared and never read** — `HReview.md` HR-21 /
  CR-15, already tracked. Named here only so this review is not read as having missed it.

---

## 7. Does this make operational use easier?

**Net yes.** Where it does not, it says so.

### Easier

- **The single largest gain: machine facts and job decisions become separate questions.** `X/Y Home`,
  `Machine Z Home` and `Travel Machine Z` are properties of the machine — set once, never touched
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
- **A new manual reading.** `Travel Machine Z` must be read off the DRO. Once per machine, not per job,
  and it needs no touch-off — jog to a height that clears everything and read Z. But it is a step that
  did not exist, and it is the first time the post asks the operator for a number they cannot get from
  Fusion. *(This cost was materially larger in this document's first draft, which asked for a
  bare-spoilboard touch-off — §3.3.)*
- **A typed number that can crash the machine.** §3.4. Mitigated by the header echo, not eliminated.
- **Key renames reset saved presets.** Replacing `machineHomeBeforeStart` resets it, per
  `conventions.md`. A release-notes item, and the second such reset in the beta.

---

## 8. Hobbyist protection — requirements on the build

The hobbyist persona is HP-1: one Setup, one operation, one tool, GRBL/mm, pre-jogged XY, touch plate,
no endstops. Every item below is a requirement, not an aspiration.

1. **Every new field defaults to off or empty** — `X/Y Home` off, `Machine Z Home` off, `Home at Job
   Start` off, `Fixed Z Reference = None`, `Travel Machine Z` empty — so the factory-default job
   **emits no motion, command or comment it did not emit before**, the header property dump
   excepted. Verified by posting, diffed against the pre-change build: the diff may touch the dump
   (four properties added, one removed, two group headings retitled) and the one Resolved-Values
   line that renames, and **nothing else may move**. See decision 3 in §4 for why the original
   *byte-identical* wording was struck rather than kept as an aspiration.
2. **No new field is required to post, and no new guard can error a default job.** Every guard in §9
   fires only after a deliberate declaration.
3. **The dangerous number is three deliberate acts away.** `Travel Machine Z` is inert unless
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
| new | `Fixed Z Reference = Machine Z` with `Machine Z Home` off, **or `Home at Job Start` off** (§5.2), or `Travel Machine Z` empty → `error()` | new |
| new | machine-frame features (`G53` park, machine-Z datum) require `X/Y Home` → `error()` | new |
| new | multi-WCS trusting **stored** offsets with `X/Y Home` off → `warning()`. **Must not fire on the `Jog …` modes** (§4.1) | new |
| new | a `Jog …` mode selected on GRBL → `warning()` + Important comment (**E2**) | new |
| **CR-2** | homing + a `Set … to Current Pos` origin mode | unchanged; advice reworded |
| **Guard A** | no redefine of the reserved base | unchanged |
| **Guard C** | machine-frame features are GRBL/RRF only — but the *reason* is not the one Guard C already tests | **extended** |

**Why Guard C is extended and not inherited.** Today's Guard C excludes Marlin from *multi-WCS* work,
because Marlin is single-frame. A machine-frame feature needs a different exclusion: `G53` on Marlin is
a **build option, off by default** — `Marlin/src/gcode/gcode.cpp` (2.1.x) gates `case 53: G53();`
inside `#if ENABLED(CNC_COORDINATE_SYSTEMS)`, alongside `G54`–`G59`. A **single-WCS** Marlin job is
single-frame, passes the existing test, and still cannot execute the move. The two exclusions overlap;
neither contains the other.

Placement matters twice over. `conventions.md` → *Validation guards* records that a guard in
`onOpen()` refuses before any output and leaves **no file**, while a guard in `onSection()` leaves a
**truncated `.gcode`**. All of the above are configuration guards and belong in `validateJob()`, i.e.
`onOpen()`. And within `validateJob()`, the machine-frame guards must run where the Marlin path
reaches them — the Marlin branch returns early once its own test is done, so a guard written below it
is unreachable on exactly the firmware it was written to exclude. One exception: E2's *Important
comment in the file* is output, not validation, and cannot be emitted from `onOpen()` at all; only its
`warning()` half belongs here.

---

## 10. Firmware questions, to be settled from source

No controller is available, so each is a source read with file and version cited, per `CLAUDE.md`.
**None blocks the design** — `Travel Machine Z` (§3.2) is convention-independent.

**Five of the six questions this section originally listed have been answered, in one pass of reading
and with no hardware.** They are recorded here as answers rather than deleted, because each one changed
something above.

| Question | Answer, and where it landed |
|---|---|
| GRBL `M0` hold state vs `$J=` jogging | **Answered.** *"A jog command will only be accepted when Grbl is in either the 'Idle' or 'Jog' states"* — Grbl v1.1 Jogging. E2 stands; §6 carries the quote |
| `G53` on Marlin 2.x — unconditional, or build-gated? | **Build-gated.** `#if ENABLED(CNC_COORDINATE_SYSTEMS)` in `Marlin/src/gcode/gcode.cpp` (2.1.x). Guard C is *extended*, not inherited — §9 |
| `G30` / `G30.1` axis-word behaviour on all three | **Answered, and it kills the option.** Bare `G30` moves all axes; `G30 Z<n>` takes a number and rapids through the work frame first; `G30` is a *single Z probe* on Marlin and RRF — §3.3 |
| GRBL `$H` with a partial axis config | **Answered.** `HOMING_CYCLE_0/1/2` is compile-time and `HOMING_SINGLE_AXIS_COMMANDS` is off by default, so `$H` homes what that build was compiled for and the post can neither emit nor verify per-axis; FluidNC can — §5.1 |
| GRBL `G53` | **Already answered** — `conventions.md` → *Firmware capabilities* records `G53` in GRBL 1.1's supported set |
| **`G53` on RepRapFirmware — still open** | RRF documents `G53` as *"not modal and must be programmed on each line"*, which is what §3.2 and §5.3 assume. What remains unread is the **version floor** and the tool-change park's `X`/`Y` behaviour: `Duet3D/RepRapFirmware`, `src/GCodes/GCodes2.cpp`, plus the wiki changelog |

> **Two lessons from answering them, both worth keeping.** First: every one of these was answerable
> from the sources this document already cited — filing them as open questions cost a design decision
> (`G30`) that had no business surviving to §3.3. `conventions.md` says it directly: *do the source
> read **before** filing a question as needing hardware.* Second: **both errors were outside GRBL.**
> The claims in this document were tested hardest against the default firmware, and what failed was a
> FluidNC conflation (§5.1) and an RRF version bound (§6) — the second of which would have produced a
> wrong physical motion. GRBL is not the coverage that is short.

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
- **Test rows a build would need**, in the shape `PReview.md` §3 uses: a default job proving the
  diff is confined to the property dump (§8.1); a homed-XYZ multi-WCS job with no reserved base, proving Guard B's
  relaxation and one `G53 G0 Z<travelMachineZ>` per traverse, echoed in the header; the first section's
  arrival emitting a real absolute Z instead of the `Unknown Z for XY move.` comment (§3.6); each new guard's
  refusal; a `Jog …` mode on GRBL proving E2's warning; and a `G53` park proving it lands at the same
  physical spot under two different WCS.
