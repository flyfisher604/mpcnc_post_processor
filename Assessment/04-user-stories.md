# Step 4 — User stories

**FROZEN**, with two exceptions the author directed on 2026-08-13. Written before
reading the post; nothing below may be revised to fit code found later, and a
"gaps discovered later" section is appended at the end.

The freeze is lifted only where instructed, and each lift is marked **`[EDITED
2026-08-13]`** in place so it stays visible in a diff:

1. **S3's wording** — *"I need the **option** for a posted file to end…"*. This is a
   correction of the story, not a fit to the code.
2. **N2's correction is merged into N2 itself** rather than left at the foot of the
   page. A non-goal that is wrong where it is read is worse than a broken freeze.

Derived from `01-personas.md`, `02-z-trust.md` and `03-f360-and-firmware.md`.
Evidence tags as before, plus `[AUTHOR]` for constraints the project owner stated
as given (the licence-tier limits), which I cannot verify myself.

---

## Load-bearing stories

**S1 — Cut correctly from a hand-set zero.**
As a hand-zeroed hobbyist on any licence and any firmware, I need the program to
cut correctly when the only reference is where the bit is sitting right now, so
that I can jog, touch off, zero and run without homing. `[DOC]`
docs.v1e.com/electronics/dual-endstops documents this as one of the two normal
ways to use the machine.

**S2 — Air moves that do not crawl.**
As a personal-licence user, I need non-cutting moves to travel at a fast feedrate
rather than the cutting feed, so that a job does not take hours moving through
air. `[AUTHOR]` for the licence restriction; the *mechanism* — that F360 emits
rapids as `G1` on a free seat — is `[INFERRED]` pending `C2` in
`00-facts-needed.md`.

**S3 — One tool per posted file, changed between runs.** **`[EDITED 2026-08-13]`**
As a personal-licence user restricted to one operation per post, I need **the
option for** a posted file to end in a state where I can change the tool by hand
and run the next file, so that a multi-tool job is possible as a sequence of files.
`[AUTHOR]`

*Why the word matters:* "each posted file must end tool-changeable" is a mandate,
and mandates get implemented as unconditional emission. **"The option" makes it a
property** — the operator asks for it when the next file needs it, and an ordinary
last-operation-of-the-job file is not obliged to carry tool-change scaffolding it
will never use. This is the difference between Group 7's end-of-file behaviour
being a switch and being a policy, and S13 inherits the correction.

**S4 — Marlin dialect at all.**
As any hobbyist on Marlin, I need a post that speaks Marlin, because **Autodesk
ships none** — of 490 bundled posts there is `grbl.cps`, `reprap.cps` and no
Marlin equivalent. `[SDK]` This is the project's strongest reason to exist.

**S5 — The WCS F360 asked for.**
As a full-licence user running more than one setup, I need each section's work
offset emitted as F360 specifies it, so that the program addresses the offset I
selected. `[SDK]` `section.wcs` is supplied by F360; the post writes it
(`grbl.cps:1533`).

**S6 — Offsets written in my firmware's dialect.**
As a Marlin user, I need a work offset written with `G92`, not `G10 L2 P<n>`,
because Marlin has no `G10 L2` — `G10` is firmware retract there. `[DOC]`
Marlin `G53-G59.cpp` ("G92 is used to set the current workspace's offset"),
issue #14734, and docs.v1e.com/lowrider showing exactly this split.

**S7 — Machine-frame retract when, and only when, the frame is known.**
As a user whose machine has been homed in this program, I need the option of a
retract to a known machine height, so that lifts clear fixtures reliably. `[SDK]`
`G28`/`G30`/`G53` are the only methods Autodesk offers, all requiring a homed
machine (`grbl.cps:1960-1974`).

**S8 — Told, not guessed, when the frame is unknown.**
As a user who has not homed, I need the post to warn me and emit a relative
retract, rather than emit an absolute machine height it cannot know. `[SDK]`
Autodesk's own handling in this exact case is a post-time warning plus a comment
saying *"Raise the Z-axis to a safe height before starting the program"*
(`grbl.cps:735-741`) — a warning, not a computation.

> **Reconsidered 2026-08-13 — *"Is a relative retract the best option, maybe it is
> simply best to error if there is no machine Z?"*** The answer splits by what the
> file is trying to do, and the split is the useful part:
>
> - **Single-WCS job (the hobbyist path): warn, do not error.** S1 is the project's
>   founding story — a hand-zeroed machine with no machine Z is *the normal case*,
>   V1 documents it, and it is what 24 of the 24 `[POSTED]` files are. Erroring here
>   would refuse the post's primary user. And the relative retract is not a guess:
>   `G91`/`G0 Z+n`/`G90` moves *up from wherever the tool is*, which is arithmetic
>   the controller can always do correctly. What the post cannot know is whether
>   "up by n" clears the fixture — hence the warning, and hence Autodesk doing
>   exactly the same thing.
> - **Multi-WCS job: error, and it already does.** Here a relative retract is
>   genuinely unsound, because clearing the fixture in one frame says nothing about
>   the next. That is Guard B at
>   [MPCNC_v4.0_Beta2.cps:1702](MPCNC_v4.0_Beta2.cps#L1702), and it is correct.
>
> So the current design is right, and **S8 stands as written** — but the reason is
> sharper than the story states. *A relative retract is exact; only its sufficiency
> is unknown.* The single place worth changing is the **default**: a relative
> retract distance the operator never chose is the one number in this area that is
> a guess. See `06-retention.md`.
>
> There is a real hazard in erroring too eagerly, and the `[POSTED]` files show it:
> three of the five failures produced a **51-byte file containing only
> `!Error: Failed to post data. See log for details.`** A hobbyist who gets that
> instead of a warning has been told nothing at all. **An error is only better than
> a warning when it names the fix** — which the post's own guard texts do, at
> length, and which F360's generic abort does not.

**S9 — A manual tool change that stops safely and says which tool.**
As a full-licence user who set a tool to manual change in F360, I need the program
to stop, tell me the tool number, and leave the machine in a safe state. `[SDK]`
`tool.manualToolChange` is an F360-supplied flag; the stock response is `M0` plus
a comment (`grbl.cps:1561-1563`).

**S10 — Spindle and feed basics in my dialect.**
As any user, I need spindle on/off/speed and feedrates emitted in commands my
firmware accepts. `[SDK]`/`[DOC]`

**S11 — Refusal over bad output.**
As a hobbyist who cannot read G-code fluently, I need the post to refuse to
produce a file when its inputs are inconsistent, rather than emit something that
looks plausible. `[SDK]` Autodesk's posts do exactly this — e.g. *"Using multiple
work offsets is not possible if the initial work offset is 0"* (`grbl.cps:715`).

## Deliberate non-goals

Each of these is something the post could do, that a persona does **not** need,
with the party who should own it:

- **N1 — Computing an absolute safe Z from unknowns.** Owner: **the operator**,
  who knows whether the machine is homed and how tall the fixture is. Autodesk's
  precedent is a warning. See `02-z-trust.md`.
- **N2 — Synthesising clearance/retract moves between operations.** **`[EDITED
  2026-08-13]`** — the correction that was at the foot of this page is merged here,
  because a non-goal is read where it sits. **N2 as first written was too broad**
  and splits in two:
  - **N2a (stands)** — synthesising retracts *within one setup* is **F360's** job.
    Proven by `getRetractParameters()` returning `undefined` for the
    `clearanceHeight` method and the output still being safe
    (`grbl.cps:1045-1050`).
  - **N2b (WITHDRAWN)** — synthesising a clearance for a traverse *between two work
    offsets* is **not** something F360 can do. F360 never learns the offsets'
    values, so it cannot compute or check such a path; see `03-f360-and-firmware.md`
    §3a. A post-invented common frame is a legitimate answer to a real gap — so the
    cross-part machinery **cannot be criticised as usurping F360's job.** It has to
    be judged on scope instead, which is **S12**, and on *which* common frame, which
    is Group 5.
  - *How this was found, and a caution:* I first reached the withdrawal by reading
    `docs/design.md`. **That was the wrong way to reach it** — `design.md` is under
    audit in this review and cannot be its own evidence. The withdrawal now rests
    on the F360 machine-definition files instead (§1a and §3a of
    `03-f360-and-firmware.md`), which is independent of anything the project wrote
    about itself. The conclusion survived; the method did not. See the head of
    `05-history.md`.
- **N3 — Supplying clearance and home figures as post properties.**
  **WITHDRAWN 2026-08-13.** This was wrong, and by a wide margin. I claimed the
  owner was F360's machine configuration, on the strength of
  `getHomePositionX/Y()` and `getRetractPlane()` existing. They exist and are
  **empty**: `retractPlane` appears in **0** of the 211 cached `.machine`
  definitions, `setRetractPlane` appears in 159 bundled posts and is **commented out
  in every one**, and there is no `getHomePositionZ()` at all. `[SDK]` A
  machine-frame travel height therefore has **no home in F360**, and a post property
  is the only place a human can supply one. See `03-f360-and-firmware.md` §1a.
- **N4 — Deciding whether a tool change is manual.** Owner: **F360**, via
  `tool.manualToolChange`. *Narrowed* `[AUTHOR]` — professional path only; the flag
  never appears on a personal seat.
- **N5 — Per-machine-brand configuration.** No persona is brand-shaped; a
  Shapeoko and a LowRider on the same firmware want the same output.
- **N6 — Per-firmware WCS logic beyond two points.** Justified only at the
  `wcsDefinitions` declaration and the offset-write command. All three firmwares
  have G54–G59. `[SDK]`/`[DOC]` **Now three points, and strengthened** — see
  `03-f360-and-firmware.md` §4e: the slot count is 6 / 9 / 9, and **Marlin's nine
  registers persist**, so the firmware asymmetry N6 was hedging against is smaller
  than assumed, not larger.

  > **The author's reading of N6, confirmed 2026-08-13:** *"So 04 N6 is essentially
  > saying the WCS First and WCS Subsequent properties is over engineered."*
  >
  > **Yes — that is what it says, and the evidence since has only made it firmer.**
  > Those two properties ask the operator to choose, separately, what the post does
  > at the *first* work offset and at *each subsequent* one. N6's claim is that the
  > distinction is the post's own, not the firmware's and not F360's: F360 hands over
  > `section.wcs` and nothing else, and the stock post's entire response is *"if the
  > offset changed, write it"* (`grbl.cps:1523-1537`) with no first/subsequent
  > concept anywhere. The first offset is only special because **the post** chose to
  > treat arriving at it differently from moving between offsets.
  >
  > There is one genuine asymmetry underneath: at the first offset the tool's
  > position is unknown, and between offsets the post knows it is at a retract
  > height it just commanded. But that is **one** fact about one moment, and it does
  > not need two operator-facing enums to express — it is a condition the post can
  > test for itself. `06-retention.md` carries the per-property verdict the author
  > asked for.

## Stories I could not derive, and why

- **Laser / diode work (Group 9).** V1 machines commonly carry diode lasers
  `[COMMUNITY]`, but I did not research what a laser user needs and have no
  persona detail. Any verdict on Group 9 must state that it rests on this gap.
- **Multi-fixture / multi-part WCS orchestration (the P7 persona).** I found no
  evidence that this user exists in the anchor community. The honest position is
  that **no story supports it**, not that it is forbidden — if the author knows of
  real users doing this, the list is wrong and should be corrected before step 7's
  verdicts are trusted.
  → **Resolved, in two parts that must be read together: see S12 below.** The
  *user* is confirmed and in scope; the *orchestration* is not the post's to build.
- **Coolant on a router (Group 10).** Hobby routers rarely have flood coolant;
  what a hobbyist wants from `M7`/`M8` is unclear to me. Flagged, not judged.
- **Duet-specific behaviour (Group 11).** P5 exists but is a minority, and I have
  no evidence about what Duet needs beyond RepRap dialect.

## Test to apply in step 7

Every block of code should answer to a story above. If it answers to N1–N6
instead, it is over-engineering and the owner is named. If it answers to nothing
at all, it is dead weight. If a story has no code, it is a gap.

---

# Gaps discovered later

*Append-only. The stories and non-goals above are unchanged — this section records
where later evidence corrected them, so the correction is visible rather than
silent.*

## Correction to N2, found in step 5

**N2 as written was too broad.** `docs/design.md` argues, correctly, that every
F360 height parameter is per-operation and expressed in *that operation's own
WCS*, so it cannot serve as a clearance height in a *different* frame. F360 has
no job-level "above the machine table" height at all.

N2 therefore splits:

- **N2a (stands)** — synthesising retracts *within one setup* is F360's job. Proven
  by Autodesk's own post emitting nothing and the output still being safe.
- **N2b (withdrawn)** — synthesising a clearance for a traverse *between two work
  offsets* is **not** something F360 can do. A post-invented common frame is a
  legitimate answer to a real gap.

The consequence is that the cross-part machinery cannot be criticised as usurping
F360's job. It has to be judged on whether the workflow it serves is in scope —
which is story **S12** below, and the answer decides Group 5 and much of Group 6.

## S12 — the story that would justify the cross-part machinery, and its status

**S12 — Machine several parts or fixtures in one program.**
As a full-licence hobbyist with more than one workpiece or fixture on the bed, I
need one program to traverse safely between work offsets and re-establish each
part's zero, so that I can run a batch unattended.

**Status: UNSUPPORTED BY EVIDENCE.** `docs/PReview.md` §3.1 is titled *"Multi-part
/ multi-fixture — needs a job nobody has posted yet"* and states *"This is the
largest untested area in the post."* Every test row in it is unchecked. No
persona in `01-personas.md` demonstrates this user, and V1's own documentation
describes zeroing per job rather than managing G54–G59.

This story is **not** disproved — it is unevidenced. It is the single question the
author most needs to answer, because a great deal of code depends on it and
nothing else does. Recorded here rather than in the frozen list above precisely
because it was derived after the fact.

### S12 — RESOLVED 2026-08-12: **IN SCOPE**

The author confirms this persona and workflow are in scope, for the hobbyist with a
**full Fusion licence** `[AUTHOR]`. S12 is therefore a load-bearing story, and
groups 4, 5 and 6 answer to it.

Unchanged by that answer: nobody has posted such a job yet. **In scope ≠ verified.**
The six jobs in `PReview.md` §3.1 remain the outstanding work.

## S13 — End a file so a manual tool change costs nothing *(from answer 2.1)*

As a **personal-licence** hobbyist running one operation per posted file, I need the
program to end with the machine in a state where I can change the tool by hand
**without losing the established work origin**, so that the next file cuts from the
same zero. `[AUTHOR]`

This is a sharper statement of what Group 7's hobby path is actually for, and it is
not the same as "emit a tool change". F360 supplies nothing here — on a personal seat
it never emits a tool change at all — so the whole behaviour is legitimately
post-invented.

**What the requirement implies, mechanically.**

- **X/Y work origin must survive the change untouched** — it is never re-probed, so
  if it is lost it is lost for good.
- **Z is expected to be re-established by probe** after the swap. Losing Z is normal
  and recoverable; losing X/Y is not.

> **Corrected 2026-08-13 — `design.md`'s *"no TLO"* is too strong, and the author is
> right.** I had taken *"no TLO, no tool setter"* from `design.md` at face value.
> Two faults: it is a document under audit, and on the facts it is wrong for two of
> the three firmwares. What the firmwares actually offer
> (`03-f360-and-firmware.md` §5a):
>
> | | TLO mechanism | Can the machine compute the offset itself? |
> |---|---|---|
> | **GRBL / FluidNC** | `G43.1 Z<offset>`, `G49` cancels | **No** — no variables, no arithmetic |
> | **RepRapFirmware** | `G10 L1 P<t> Z<offset>`, persisted by `M500 P10` | **Yes** — meta G-code |
> | **Marlin** | **none** | No |
>
> **So the author's suggestion is sound, and firmware-dependent.** *"This and a probe
> could maybe be used to allow manual tool changes and continued operation"* is
> achievable — fully on RepRap, where a machine-side macro can probe, subtract and
> store; partly on GRBL, where `G43.1` will accept an offset but something off-board
> must compute it; not at all on Marlin.
>
> **What this does to S13.** It stops being one story and becomes a ladder, and the
> post's obligation is different on each rung:
>
> 1. **Marlin** — re-probe and re-zero is the *only* mechanism. S13 as written.
> 2. **GRBL/FluidNC** — re-probe and re-zero by default; `G43.1` is available to an
>    operator whose sender computes the delta. The post's job is **not to get in the
>    way** of that, which mainly means not clobbering the origin.
> 3. **RepRap** — the machine can do it properly. The post's job shrinks to emitting
>    a stop and letting a macro run.
>
> That is a strong argument for the **include-file hook** as the answer to Group 7b
> rather than post-generated tool-change code: one mechanism that is correct on all
> three, because the operator supplies the part only they can know. `09-plan.md`
> Phase 2 is built on it.
>
> **This does not soften the fragility finding below** — it sharpens it. The
> firmware with no TLO is the same firmware whose origin is the most volatile.

**And this story is firmware-sensitive, which makes one case the most fragile in the
post.** On GRBL/FluidNC the origin lives in a persistent register — `G10 L20` survives
both a power cycle and a homing cycle, since *"`$H` never touches those registers"*.

> **Corrected 2026-08-13, from Marlin source.** I wrote that a Marlin `G92` origin
> *"survives neither a power cycle nor a homing cycle."* **Half right, and right for
> the wrong reason.** What the source says `[DOC]` (Marlin 2.1.x):
>
> | Event | What happens to a Marlin `G92` origin |
> |---|---|
> | **Power cycle** | **Survives** — `G92` writes `coordinate_system[active_coordinate_system]` (`G92.cpp`), and *"with EEPROM support they may be restored from a previous session"* (`G53-G59.cpp`). Needs the build to have EEPROM and the value to have been saved |
> | **Homing** | **Lost from live position.** `set_axis_is_at_home()` executes `position_shift[axis] = 0; update_workspace_offset(axis);` (`motion.cpp`) |
>
> And there is a sting in the second row that matters more than the row itself.
> Homing clears the **applied** offset but leaves the **stored register** intact — so
> the obvious repair, re-sending `G54`, **does not work**:
> `select_coordinate_system()` opens with `if (active_coordinate_system == _new) return false;`
> (`G53-G59.cpp`), and G54 is still the active system. **The operator must select a
> different workspace and select back** to reapply their own offset.
>
> So the corrected claim: on Marlin the origin is **durable in storage and fragile in
> application.** The hazard is not the power switch — it is **homing**, and the
> recovery from it is non-obvious enough that an operator would reasonably conclude
> the zero was gone.
>
> **The conclusion stands and is now better founded:** the personal-licence Marlin
> user still has the weakest hold on their own zero of any persona here, and the
> specific thing the post must not do at end-of-file on Marlin is **home**. That is a
> concrete rule, testable in a diff, where the previous version was a mood. It is
> also a firmware fact of exactly the species `06-retention.md` calls the project's
> most valuable asset, and `design.md` does not currently record it.

## S14 — Laser and diode work *(from answer 1.4)*

As a hobbyist with a diode laser fitted, I need laser power and enable emitted in my
firmware's dialect, so that engraving and cutting jobs run correctly. `[AUTHOR]`

Group 9 is justified in kind. **The detail is still unenumerated** — I do not know
which of power scaling, `M3`/`M4` dynamic power modes, enable sequencing or air assist
this user needs, so I can say the group should stay but not whether seven properties
is the right number. Recorded as a known limit of this review, not as a verdict.

## Premise confirmations

- **S2's mechanism is confirmed** `[AUTHOR]`: the personal licence converts *all*
  rapids to `G1`. Group 3 rests on a true premise and its cost is justified.
- **N4 is narrowed** `[AUTHOR]`: reading `tool.manualToolChange` is the right thing to
  do on a **professional** job, and is unavailable on a personal one — the flag never
  appears there. So N4 applies to the professional path only, and the personal path's
  own controls are not a duplicate of anything.
- **S14's persona is confirmed but unexercised** `[AUTHOR]`: the laser persona is
  real and *"was used in v3 beta3 by users"* — so it has field history — but it is
  **not exercised by any test in this project**. None of the 24 `[POSTED]` files is a
  laser job. Group 9 therefore has the same shape of debt as Group 6, at smaller
  scale: a confirmed user, working code, zero current verification.

## S12 — the scope reconciliation, and it is the most important reading in this round

The author gave two instructions that appear to conflict:

> *"So 04 'Multi-fixture / multi-part WCS orchestration' is an outcast case and not
> worth the coding to support. Make it a user problem not a post issue."*

> *"Step 9, 1.1, Yes S12 is in scope."*

**They do not conflict, and taken together they are a sharper design than either
alone.** They separate two things this review had been treating as one:

| | In scope? | Owner |
|---|---|---|
| **The workflow** — a hobbyist with several parts on the bed, using F360's "Multiple WCS Offsets", wants a program that runs them | **Yes** — S12 stands | The **post** must not block it |
| **The orchestration** — the post computing safe traverses between offsets, inventing a common frame, probing a spoilboard base, managing provisional zeros, sequencing per-part re-establishment | **No** | The **operator** |

So the post's obligation under S12 is much smaller than the code currently written
for it:

1. **Emit the work offsets F360 supplies.** `section.wcs`, when it changes. This is
   the stock behaviour and about fourteen lines (`03-f360-and-firmware.md` §3).
2. **Require a homed machine, and retract in the machine frame.** `G53` to an
   operator-supplied travel height. This is how production machines do it
   (§3a) and it is correct regardless of any WCS's Z0.
3. **Refuse clearly when those conditions are not met** — which the post already
   does, at length.
4. **Stop there.** The operator sets the registers, chooses the clearance, and owns
   whether their fixtures are compatible. That is not a shortcoming; it is the same
   division of labour every commercial control uses.

**What this changes versus the last round.** Last round S12-in-scope moved ~780
lines from "delete" to "verify". This reading moves a large part of them back — not
because the user disappeared, but because **serving that user does not require the
machinery.** The specific casualty is the spoilboard-base subsystem
(`07-code-map.md`, Group 5): it exists to synthesise a common frame for machines
that cannot home, and multi-part work requires homing, so **the machine it was built
for cannot use the feature it was built for.** The post says so itself at
[MPCNC_v4.0_Beta2.cps:1669](MPCNC_v4.0_Beta2.cps#L1669).

**S12's status is therefore: IN SCOPE, SERVED BY LESS CODE THAN IS WRITTEN FOR IT.**
And the one thing that must happen first is unchanged from the last round — the
`PReview.md` §3.1 jobs, because *"post what F360 asks for"* cannot be confirmed
without posting one. The author's Group 6 report — that the post currently
**errors out** on a Multiple-WCS-Offsets job — is the proof that step 1 is not yet
true.

## N2b's real question — what do operators actually do today?

> *"For 04 N2b (withdrawn) the real question is what do operators do today? What
> assumption is being made? How is this handled in the real world?"*

**This is the right question and I cannot answer it from evidence.** It is `D1`–`D4`
in `00-facts-needed.md` and it stayed open through the whole review. What I can do is
separate what is established from what is assumed, so the gap is visible rather than
papered over:

**Established** `[SDK]`:

- F360 is told only a **count and a stride** (§3a). It never learns where any
  fixture is.
- Every retract F360 puts in a toolpath is a Z **in the active WCS**.
- Autodesk's stock posts offer four safe-retract methods and **three are
  machine-frame** — `G28`, `G30`, `G53`. The fourth, `clearanceHeight`, emits
  nothing and carries a warning telling the human to sort it out.

**The assumption the emitted G-code depends on**, stated precisely:

> Either every work offset in the job has its Z0 at the same physical height and the
> clearance clears everything on the path — **or** the traverse happens in the machine
> frame, in which case no agreement is needed at all.

**What I believe happens in the real world**, marked as belief: production shops take
the second branch. Work offsets on a pallet or tombstone are referenced to a common
plane *and* the retract goes to machine Z home, so the two mechanisms back each other
up. `[INFERRED]` from the stock posts' method list, not from observed practice.

**What I do not know, and what would settle it** — three questions, none answerable
from a repository:

1. Does a hobbyist running two fixtures set both Z0s to the same plane, or set each
   to its own part top and rely on a generous clearance?
2. When they traverse, do they trust the post, or jog the tool up by hand first?
3. Has anyone in the anchor community done this at all, or is the practice imported
   from industrial machining where the machine always homes?

**Why this is not a blocker.** Under the scope reconciliation above, the post no
longer needs the answer: it emits a machine-frame retract on a homed machine and the
assumption becomes the operator's, explicitly and in writing. **The question moves
from the code to `guide-pro.md`** — which must state the requirement rather than
leave the operator to infer it. That is a documentation obligation, tracked in
`10-project-cleanup.md`, and it is the honest resolution of a question this review
cannot close.
