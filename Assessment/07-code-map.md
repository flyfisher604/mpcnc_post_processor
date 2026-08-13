# Step 7 — Code map: load-bearing vs. over-engineered

100 functions, 72 properties, 3,758 lines. Line spans computed from function
boundaries, so the totals are real; attribution of shared code to a group is my
judgement and marked where it is arguable.

## The shape of the file

| Region | Lines | Share |
|---|---|---|
| **The property block** (`MPCNC_v4.0_Beta2.cps:123-918`) | **795** | **21.2%** |
| `validateJob()` — the guards (`:1448-1736`) | 288 | 7.7% |
| Comment-only lines, whole file | 634 | 16.9% |
| Everything else — 98 functions | ~2,040 | 54% |

Two things stand out before any group verdict. **A fifth of the post is property
definitions** — 795 lines for 72 controls, 66 of which carry a written
description. And **`validateJob()` is the largest function in the post by more
than double**, at 288 lines of guards. A post that needs 288 lines to check
whether its own settings are coherent is telling you something about how many
settings it has.

## Line share by property group

**Verdicts revised twice.** The 2026-08-12 column reflects the four blocking answers;
the **2026-08-13** column reflects the author's separation of the multi-part *workflow*
(in scope) from the multi-part *orchestration* (the operator's), plus three firmware
corrections. Measurements and defects are unchanged throughout — what moves is whether
the code is justified. Both prior verdicts are kept so the trajectory is visible.

| Group | Props | ~Lines | Share | **Verdict (2026-08-13)** | 08-12 | Original |
|---|---|---|---|---|---|---|
| 1 — Job | 8 | ~180 | 5% | **Keep** — infrastructure | same | same |
| 2 — Feeds and Speeds | 7 | ~150 | 4% | **Keep** — load-bearing | same | same |
| 3 — Map G1s to Rapids | 2 | ~244 | 6.5% | **Keep — premise now `[SDK]`-confirmed** | premise confirmed | cost questioned |
| 4 — Machine Frame | 3 | ~120 | 3% | **Keep, and promote** — homing becomes the *precondition* for multi-part | keep | split |
| 5 — Fixed Z Reference | **5** | ~250 | 6.7% | **REDUCE HARD** — the spoilboard base retires; machine-Z survives | keep, untested | over-engineered |
| 6 — On WCS / Part / Fixture | 10 | ~410 | 11% | **Keep the touch-off, fix the bug, delete the orchestration** | keep, untested | split 40/60 |
| 7 — Tool Changes | 8 | ~65 | 1.7% | **Split into two paths; build 7b on include files** | two paths | code defective |
| 8 — External Include Files | 5 | ~36 | 1% | **Keep, and it gains a job** — the tool-change hook | keep | same |
| 9 — Laser | 7 | ~74 | 2% | **Keep — persona confirmed, unexercised** | keep | defer |
| 10 — Coolant | 10 | ~97 | 2.6% | **Reduce** — still no persona | reduce | cut candidate |
| 11 — Duet | 2 | ~20 | 0.5% | **Keep the fields** — relocating them is optional (PR-13, author 2026-08-13) | keep or fold | same |

### What changed on 2026-08-13, and why the arithmetic moved back

On 2026-08-12 the S12 answer moved groups 4, 5 and 6 — **~780 lines, 21% of the
post** — from "delete" to "verify". The 08-13 reading moves a substantial part of
them back out, and it is important to be clear that **this is not the scope decision
being reversed.** S12 stands. What changed is the recognition that *serving* S12
requires far less than has been built for it:

| | 08-12 reading | 08-13 reading |
|---|---|---|
| The multi-part **user** | In scope | **In scope — unchanged** |
| Traversing between parts | Post computes a common frame | **`G53` on a homed machine** |
| Re-establishing each origin | Post orchestrates, per part, six modes | **Operator, before the job** |
| Machines that cannot home | Served by a probed spoilboard base | **Cannot do multi-part at all** — the post says so itself at [:1669](MPCNC_v4.0_Beta2.cps#L1669) |
| Marlin | Refused outright (Guard C) | **Supported**, with a version floor |

The load-bearing observation is the fourth row, and it comes from the post's own
validation code rather than from this review: **moving between stored work offsets is
only repeatable on a machine with a homed X/Y zero.** The spoilboard base exists to
give a *non-homing* machine a common Z frame. So the machine the subsystem was built
for is excluded from the workflow the subsystem was built for. See Group 5 below.

**And no multi-part job has still ever been posted.** `docs/PReview.md` §3.1 is
unaffected by any of this. The author has confirmed why `[AUTHOR]` — professional
testing was deliberately deferred to stabilise the hobby path for Beta3
(`05-history.md`) — which makes the sequencing sound and leaves the **gate** missing:
nothing in the repository or the guides tells a user this path is unverified.

---

## Group 6 — `On WCS / Part / Fixture Changes`. The heart of the matter.

`writeWCS()` is **126 lines** (`:1860-1985`). Autodesk's equivalent is **14**
(`grbl.cps:1523-1537`). The difference is not padding — it is four distinct jobs
the stock post does not attempt. Taking them separately:

**Load-bearing, ~25 lines.** Three things here are right and should survive any
prune:

- **`workOffset 0` aliasing** (`:1866-1869`). *"Fusion reports workOffset 0 both
  when the Setup's Work Offset field was left at its default and when the default
  was chosen explicitly, so 0 always means 'use WCS 1'."* This is a real F360
  ambiguity and handling it is exactly a post's job. Autodesk handles the same
  case with an error; aliasing is friendlier and no less correct.
- **Range check with a real error** (`:1886-1889`) — serves S11.
- **Select only on change** (`:1880-1883`, `:1925-1926`) — identical in shape to
  Autodesk's `if (section.workOffset != currentWorkOffset)`.

**The retract decision tree, ~25 lines** (`:1898-1922`). Three arms —
`machineFrame`, `baseRelative`, and an `error()` for the third case annotated
*"Unreachable behind Guard B"*. This is the cross-part clearance machinery. Per
`05-history.md` it is **not** usurping F360 (F360 genuinely cannot express a
height in another frame) — it serves **S12**, and nothing else. One arm is
deliberately dead code.

**Four `probeOnChange` modes, ~50 lines** (`:1936-1980`): `Skip`, `Probe Z`,
`Jog XYZ`, `Jog XY & Probe Z`. Every one of them fires only on
`isTraverse` — a genuine inter-part WCS change. **All four exist for S12 alone.**
On a single-setup job, this entire block is unreachable.

**Debug tracing, ~20 lines.** Five multi-line `writeComment(eComment.Debug, …)`
calls inside one function. Legitimate while the feature is unverified; it is also
a cost the feature imposes.

**The Marlin early return** (`:1871-1877`) warns and ignores any work offset above
1. This is Guard C, and per `00-facts-needed.md` **E1** it may be over-broad —
V1's own Marlin builds enable `CNC_COORDINATE_SYSTEMS`. Settle E1 before touching
it either way.

The probing functions attach to the same split. `writeWcsOnStart()` (80 lines) and
`partProbe()` (45) and `probeTool()` (56) implement first-part origin
establishment — which is **real** and matches what V1 documents (`G38.2` to a
plate, `G10 L20`/`G92` to store). The *per-added-part re-probe* paths are S12.

> **Verdict on Group 6 (revised).** With S12 in scope, the ~60% serving inter-part
> traverses is **load-bearing, not surplus**. Two things survive the scope answer
> unchanged. The **four "is there a frame?" predicates** should collapse to one or
> two whatever the scope — that is a clarity problem, not a scope problem. And this
> entire block remains **unverified**: all four `probeOnChange` modes and all three
> retract arms are reachable only on a job type nobody has posted. Keeping the
> feature means owning the test debt, and the test debt is now the finding.

## Group 5 — `Fixed Z Reference`. Justified, unverified, one permanent hazard.

~250 lines for **4 properties**, and its own group title says *"multi-part jobs
only"* — self-declared as serving S12, which is now in scope. **So it stays.** Three
things about it still want attention, and the scope answer resolves none of them.

The symptom worth naming is **four predicates that all answer "is there a
frame?"** (`:2071-2103`):

- `fixedZEstablishedAtStart()` — the dialog names one
- `fixedZEstablishedInFile()` — the job also emits it (differs on Marlin)
- `baseProbeCanRun()` — the first section's tool can touch off
- `parkCanRetract()` — literally `return fixedZEstablishedInFile();`

That last one is a one-line alias, justified in its own comment as *"Its own name
because the park's callers ask about the park."* Each distinction is individually
defensible. Four of them for one question is what over-engineering looks like from
the inside — nobody added a bad predicate; the concept underneath was just too
complicated to hold in one.

And the feature's principal hazard is unfixable by design. `design.md`:

> *"whatever is under the tool becomes the base's Z0, so parking over the stock
> records the stock top as 'the spoilboard' and every clearance from it is short by
> the stock thickness. **Mitigation is documentation, not code**."*

With S12 in scope this hazard is **permanent**, which raises its importance rather
than lowering it. If the mitigation is documentation, then the documentation has to
exist and be findable — that is now a deliverable, not an excuse. A general guard is
genuinely impossible (the distance from clearance to the stock top is exactly what the
probe exists to discover), but **PR-10's post-time warning is the precedent**: the base
establish should carry a warning naming this failure in the same way.

**One part of Group 4 must survive regardless**: `writeMachineHoming()` (58 lines)
and the `machineHomesZ()` / `homesAtJobStart()` predicates serve **S7** and
**S8** — real stories. The per-firmware homing split is genuinely justified and
sourced: GRBL's `$H` homes whatever the build was compiled to home, with
`$HX`/`$HY`/`$HZ` behind `HOMING_SINGLE_AXIS_COMMANDS` (off by default), while
Marlin does `G28 X`/`G28 Y`/`G28 Z` per axis. That is a real dialect difference,
settled from source, and exactly what a post should encode.

## Group 7 — Tool changes. The need is real; this code is not serving it well.

`toolChange()` is 65 lines (`:3637-3698`) and **carries two defects documented in
its own comments and left in place**:

```javascript
// A dedicated tool-change spot only makes sense as a fixed MACHINE location, but toolChangeX/Y/Z
// are plain G0 words -- WCS-relative -- so the spot drifts to wherever this job's WCS is zeroed.
```
(`:3657-3658` — this is PR-4, still open)

```javascript
  // Run Z probe gcode. Same WCS caveat as the rapid above: this runs before the new section's WCS
  // is selected, so probeTool() writes into the PREVIOUS section's WCS.
```
(`:3691-3692`)

Plus `writeBlock(mFormat.format(84), 'Z')` at `:3675` — `M84` is Marlin-only and is
emitted on every firmware. That is HR-10, open, and the register itself calls its
fix a *"complete diff, independent of the reorder — can go first as a warm-up
commit."*

**On the two use cases — including a correction to what I first wrote here.**
Answer 2.1 sharpens both and overturns part of my original reading.

**(a) The personal-licence path is real, and it is not what I first called it.**
On a personal seat **F360 never emits a tool change at all** `[AUTHOR]`. So there is
no flag to read and nothing is being duplicated — the post's own controls are the only
mechanism that *could* exist. And the requirement is narrower and more precise than
"emit a tool change at the end": the file must end with the machine in a state where a
manual swap **does not lose the known position** (story S13). X/Y work origin must
survive untouched, because it is never re-probed; Z is expected to be re-established
by probe. Legitimately post-invented, and it should be left alone.

**(b) The professional path — the mechanism, plainly.** In F360 the operator assigns a
tool per operation. Where consecutive operations use different tools, the CAM engine
flags the boundary and sets **`tool.manualToolChange`** on tools the operator marked
manual. The post is *told* — it detects nothing. Autodesk's whole response is three
lines (`grbl.cps:1561-1563`): stop, write a comment naming the tool, resume — wrapped
in a Z retract, coolant off, and cancel length compensation.

**This post never reads that flag**, and on the professional path that *is* a
duplicated question: F360 has been told already, and the dialog asks again through
`toolChangeInsertCode`. Non-goal **N4** applies here, and here only.

> **Verdict on Group 7 (revised).** Two genuinely separate features share one 65-line
> function and one property group, and *that* is the actual defect. The personal path
> (a) is justified, necessarily F360-less, and should be left alone. The professional
> path (b) re-asks a question F360 answered, parks in a frame its own comment says
> *"drifts to wherever this job's WCS is zeroed"*, probes *"into the PREVIOUS
> section's WCS"*, and emits Marlin-only `M84 Z` on GRBL — with five findings (HR-7,
> HR-8, HR-9, HR-10, HR-13) blocked behind a rework `PReview.md` records as *"design
> settled; not built."*
>
> **The fix is to split them, not to unify them.** My earlier recommendation — read
> the flag, delete the duplicate control — would have **broken (a)**, because on a
> personal seat there is no flag to read. Splitting gives (a) its own small
> end-of-file behaviour answering to S13, and rebuilds (b) around
> `tool.manualToolChange`.

## Group 3 — real need, disproportionate cost

~244 lines for **2 properties**: `safeZforSection()` (84), `isSafeToRapid()` (52),
`resolveSafeZHeight()` (32), `describeSafeZ()` (31), plus expression parsing. The
need (S2 — air moves that do not crawl) is real if the licence premise holds.

**The premise is confirmed** `[AUTHOR]` — the personal licence converts *all* rapids
to `G1`. So the need is real for the most common persona in this review, and the
~244 lines buy a genuine capability rather than hedging against a rumour.

And this is *operation-scoped* Z reasoning, which is the legitimate kind: F360 supplies
the per-operation heights, so the post is only deciding whether a given move clears
within a frame F360 defined. That is nothing like the cross-part case. **Keep as is;
no action.**

## The groups given a light pass

- **Group 10 — Coolant, 10 properties, ~97 lines.** As many controls as the WCS
  group, for a feature hobby routers largely do not have. **Cut candidate**, but
  it needs the persona answer first — `04-user-stories.md` records that I could not
  derive what a hobbyist wants from `M7`/`M8`. Note `8148df4` defaulted the codes
  to the default firmware's dialect, which suggests someone used it.
- **Group 9 — Laser, 7 properties, ~74 lines.** **Keep.** The author confirms a laser
  persona exists `[AUTHOR]`, so the group is justified in kind. I still cannot say
  whether *seven* is the right number — I never enumerated what a diode-laser user
  needs from a post — so this is a keep, not an endorsement of its size.
- **Group 8 — External Include Files, 5 properties, ~36 lines.** **Keep.** Cheap,
  and lets an operator supply a preamble the post does not have to model. This is
  the *opposite* of over-engineering: an escape hatch instead of a feature.
- **Group 1 — Job, 8 properties.** **Keep.** Infrastructure and comment level.
- **Group 11 — Duet, 2 properties.** **Keep or fold** into the firmware selector;
  two controls is not a problem worth solving. **Settled 2026-08-13 — keep the
  fields.** `09-plan.md` 0.5 had hardened this row's *"keep or fold"* into *"fold"*
  and then written an acceptance count assuming the two properties were deleted;
  the author refused it. The reason turned out to be stronger than dialog economy:
  **both defaults are RRF 2.x g-code**, and on RRF 3.x `M453` is parsed for `S`
  alone, so most of `duetMillingMode` reaches nothing and says nothing about it.
  An editable string is the only thing that lets an operator correct that.
  `PReview.md` **PR-13** carries the firmware citations.

## Gaps — real need with no code

Few, which is itself informative: this post's problem is surplus, not shortfall.

1. **`tool.manualToolChange` is never read on the professional path.** F360 answers
   there exactly what the dialog asks again. Reading it closes a real gap — but for
   path (b) only. On a personal seat the flag never appears, so it cannot replace (a).
2. **No pass-through of F360's own retract intent.** Autodesk exposes
   `safePositionMethod` with a `clearanceHeight` option meaning "emit nothing,
   trust the toolpath". This post has no equivalent — the simplest correct
   behaviour for a single-setup job is not offered as a choice.
3. **The `>>> WARNING:` path is right and should be extended, not replaced.** Where
   no fixed reference exists, the post warns instead of moving. That matches
   Autodesk's own precedent exactly and is the model for how the Z-trust problem
   should be handled everywhere.

---

# Reconsidered 2026-08-13 — groups 6, 5 and 7

Three specific reconsiderations the author asked for. Each supersedes the
corresponding section above where they disagree.

## Group 6 revisited — there is a **bug** here, and it is the most important single item in this review

> `[AUTHOR]` *"F360 allows multi fixture part generation. The F360 Setup dialog's Post
> Processor tab has a checkbox `Multiple WCS Offsets`. Enabling it prompts for `Number
> of Instances` and `WCS Offset Increment`. Current post has a validation error that is
> preventing this from posting."*

This changes the character of the finding completely. Everything above treats the
multi-part path as **untested**. It is worse than untested: **it is blocked.** The
supported F360 feature that drives the entire 21% cannot produce a file.

### Which guard fires, and why

Tick the box with two instances and F360 hands the post sections whose work offsets
differ. With `Fixed Z Reference` at its default of `None`,
`usesMachineZDatum()` is false, so **Guard B** fires
([MPCNC_v4.0_Beta2.cps:1702](MPCNC_v4.0_Beta2.cps#L1702)):

> *"A multi-WCS job requires a fixed Z reference: the tool must clear the fixtures on
> its way between parts… Set `Fixed Z Reference` to the spoilboard answer (and reserve
> a WCS) or to the machine-Z answer -- or post one job per part."*

On Marlin the job dies earlier still, at **Guard C**
([:1691](MPCNC_v4.0_Beta2.cps#L1691)) — which `05-history.md` now shows to be
founded on a false premise.

**Guard B's reasoning is sound and its default is not.** It is correct that a
multi-WCS traverse needs a frame that outlives one WCS. The failure is that reaching
that frame requires the operator to find Group 5, understand a spoilboard base and a
reserved WCS, and satisfy four further guards — so **the default configuration of a
supported F360 feature is a refusal.** A hobbyist who ticks the box gets an error
naming two subsystems they have never heard of.

### What to do

**Make the homed-machine path the answer, and make it reachable.** For a machine
declaring homed X/Y/Z with `Home at Job Start`, the traverse is `G53 G0 Z<travel>` and
Guard B is satisfied by facts the operator has already declared in Group 4. The
sequence becomes:

1. Multi-WCS job detected → require homed X/Y/Z and a travel height. Both already
   exist as properties.
2. Traverse in the machine frame. Correct regardless of any WCS's Z0, and it is what
   every commercial control does (`03-f360-and-firmware.md` §3a).
3. If the machine does not home → **refuse, and say the real reason**: *"multi-part
   work needs a homed machine; post one job per part."* One sentence, no subsystems.
4. Delete Guard C. Marlin can do this.

**This is also the first of the six `PReview.md` §3.1 jobs**, so it is not extra
work — it is the work that was already the critical path, now with a known starting
defect. It should be reproduced and filed as a finding before anything is designed.

## Group 5 revisited — the spoilboard base should go

> `[AUTHOR]` *"Maybe Group 5 should simplify to using only a homed Z. The reserved WCS
> for spoilboard probe seems awkward and not supported. A professional user doing
> multi-part WCS requires a homed Z."*

**Agreed, and the post's own code is the strongest argument for it.** I had this as
*"justified, unverified, one permanent hazard"*. That was too generous, and the reason
is a contradiction I noted without following through:

- The machine-Z answer **requires homed X/Y**, because *"the multi-part traverses it
  serves move between stored work offsets, which are repeatable only on a machine with
  a homed X/Y zero"* ([:1669](MPCNC_v4.0_Beta2.cps#L1669)).
- That reasoning is about **multi-part work**, not about the machine-Z answer. It
  applies just as forcefully to the spoilboard answer.
- But the spoilboard answer exists **precisely to serve machines that do not home.**

**So the subsystem's premise defeats itself.** Either multi-part work needs homing — in
which case a homed machine already has a machine frame and needs no probed substitute —
or it does not, in which case the guard at :1669 is wrong. It cannot be both. The
author's instinct is right: **there is no machine that both needs the spoilboard base
and can use it.**

Three further reasons, each independent:

1. **Its principal hazard is unfixable by design.** `design.md`: *"whatever is under
   the tool becomes the base's Z0, so parking over the stock records the stock top as
   'the spoilboard' and every clearance from it is short by the stock thickness.
   **Mitigation is documentation, not code.**"* A safety feature whose failure mode is
   silent, plausible, and documented-not-prevented.
2. **It consumes a WCS register** the operator may want. On GRBL there are six.
3. **It carries most of the open findings** — CR-11, CR-12, CR-14, PR-8 all live in
   the base-probe path.

### What Group 5 becomes

| Property | Verdict |
|---|---|
| `spoilboardFixedZRef` | **Delete.** With the spoilboard answer gone the enum is a boolean, and the boolean is implied by "is there a travel height and is the machine homed?" |
| `spoilboardBaseReserve` | **Delete** — no reserved WCS |
| `spoilboardBaseEstablish` | **Delete** — nothing to establish |
| `spoilboardSafeZAcrossWcs` | **Delete** — a multi-WCS traverse always uses the machine frame now |
| `spoilboardTravelZ` | **KEEP**, rename to `machineTravelZ`, **move to Group 4** |

**Group 5 ceases to exist as a group**; its one surviving property joins Machine
Frame, where a machine-frame height belongs. And that property is legitimate — F360
has nowhere to put such a number (`03-f360-and-firmware.md` §1a), so this is the only
place it can come from.

**What is deleted with it:** `writeBaseEstablish()` (~79 lines), the reserved-base
guards at [:1622-1643](MPCNC_v4.0_Beta2.cps#L1622) and
[:1696-1729](MPCNC_v4.0_Beta2.cps#L1696) (~56 lines), the base predicates
(`getReservedBaseWcs`, `baseOriginWriteReason`, `fixedZEstablishedInFile`,
`fixedZEstablishedAtStart`, `parkCanRetract`), and four property definitions with
their descriptions. **Order 250–300 lines, and four of the seven open findings close
by deletion rather than by fixing.**

Tier 3 of `06-retention.md` is where those four fixes are recorded, and it says the
right thing about this outcome already: *"that is not lost work, it is work that stops
being needed."*

## Group 7 revisited — recommendations, since none were made

> `[AUTHOR]` *"Group 7 has not been reviewed or tested. We should be making
> recommendations on improving it."*

Fair. Above I diagnosed it as two features sharing one function and stopped. The
recommendations, split by path.

### 7a — *"end this file so a manual tool change costs nothing"* (personal licence, S3/S13)

Five rules, four of which are removals:

1. **It is an option, not a policy.** Per S3 as corrected — *"the **option** for a
   posted file to end…"*. The last file of a sequence should not carry tool-change
   scaffolding.
2. **Never home at end-of-file on Marlin.** Homing runs
   `position_shift[axis] = 0`, and re-sending `G54` will not restore it because
   `select_coordinate_system()` early-returns. **Homing silently detaches the next file
   from the origin this one established** (`05-history.md`). This is the single
   concrete safety rule to come out of S13.
3. **Delete `toolChangeDisableZStepper`** — HR-10. `M84 Z` releases the Z stepper and
   an unbraked gantry descends. On a machine whose Z is a leadscrew it may hold; on one
   with a belt it will not. There is no configuration in which dropping the tool onto
   the work is the desired end state.
4. **Fix the frame of the park position.** `toolChangeX/Y/Z` are emitted as plain `G0`
   words and are therefore WCS-relative, which the post's own comment at
   [:3657-3658](MPCNC_v4.0_Beta2.cps#L3657) already calls out: *"the spot drifts"*.
   Either emit `G53` and require homing, or rename them to say they are work-frame
   coordinates. **Not both meanings on one field** — that is PR-4, still open.
5. **Leave the work origin untouched.** No `G10 L20`, no `G92`, at end of file. The
   whole point of 7a is that the next file cuts from the same zero.

### 7b — *"F360 asked for a tool change mid-program"* (professional)

The author is right that my previous answer was incomplete. Restating the problem
properly:

> **Someone must physically change the tool and re-establish the tool length. On
> these firmwares there is no built-in support for that, so either a machine-side
> macro or an included G-code file must do it.**

**Completing the answer.** A measured tool change needs a probe, a **subtraction**, and
a register to hold the result. The firmwares split on the subtraction
(`03-f360-and-firmware.md` §5a):

| | Probe | Arithmetic | TLO register | So who does it |
|---|---|---|---|---|
| **RepRapFirmware** | `G38.2` | **Yes** — meta G-code | `G10 L1 P<t> Z`, persisted by `M500 P10` | **The machine**, via a `tpost` macro |
| **GRBL / FluidNC** | `G38.2` | **No** | `G43.1 Z<offset>` — needs a literal | **The sender's** tool-change macro |
| **Marlin** | `G38.2`\* | **No** | **none** | **The operator** — re-probe and re-zero work Z |

So there is no single mechanism, and — this is the point — **none of the three is the
post.** The post cannot compute an offset it will not learn until the operator has
swapped the tool, hours after posting.

**Therefore 7b's deliverable is a contract, not a routine.** Four parts:

1. **A stop in a known place, in a stated frame.** `M0`, at a position the operator
   chose, with the frame documented — see 7a rule 4.
2. **A named include-file hook at exactly that point.** Group 8 already implements
   include files, is 36 lines, and is verified in the posted files (`HB-12(A)` even
   shows the empty-file abort working). **This is the mechanism, and it already
   exists** — the operator drops in their own RRF macro call, sender macro trigger, or
   probe-and-rezero sequence. One feature, correct on all three firmwares, because the
   part only the operator can know is supplied by the operator.
3. **A written contract for that file**: which frame is active, where the tool is, what
   the file may change, and what it must restore. Without this the hook is a trapdoor.
4. **Fix the WCS bug first.** `probeTool()` *"writes into the PREVIOUS section's
   WCS"* — the post's own comment at
   [:3691-3692](MPCNC_v4.0_Beta2.cps#L3691). A probe result written to the wrong
   register is a crash on the next plunge. This is a bug, not a design question, and it
   should be fixed independently of any restructuring.

\* Marlin's `G38.2` needs its own build flag; that goes in the same minimum-version
statement as `CNC_COORDINATE_SYSTEMS`.

**What this buys.** Group 7 stops trying to be a tool-change implementation for three
firmwares that cannot host one, and becomes a **stop plus a hook plus a contract**.
That is smaller than what is there now, works on all three, and closes the five open
findings — three by fixing, two by deletion.

**And it must be tested.** Group 7 has 8 properties, ~65 lines, five open findings and
**zero posted files exercising a tool change** — none of the 24 in `HB-Tests/` has more
than one tool. Whatever is built here, the acceptance test is a posted two-tool job,
not a code review.

---

## What stays exactly as it is

Named so the target does not read as though everything is in play: the firmware
dialect tables and the seven sourced firmware facts; `writeMachineHoming()`;
Group 2's feed limiting; Group 8's include files; `writeBlock`/format
infrastructure; the `workOffset 0` alias; `validateJob()`'s refusals (though the
function should shrink as the settings it guards shrink); and every fix in
`06-retention.md`.
