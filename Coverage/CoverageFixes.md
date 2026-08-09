# Coverage fixes — `MPCNC_v4.0_Beta2.cps`

The proposed fix for each coverage finding, and the test that would show it worked. One entry per CR
number, added when the fix is worked out — not every finding in
[`CoverageFindings.md`](CoverageFindings.md) has an entry here, and the absence of one means only that
nobody has designed the fix yet.

This file is where the thinking about a fix happens, so it is meant to change. The findings file is not:
it is the review's frozen record of what the source said, carrying only a status box per finding.

The three statuses say three different things and are ticked at three different moments. **FIX applied**
means the code carries it. **TEST pass** means a posted file showed it working. Only when both hold does
the **finding** get ticked in `CoverageFindings.md` with the commit named — applied-but-untested is not
fixed, and that is the whole reason the statuses are separate rather than one flag.

## How an entry is laid out

Each entry is the CR number and the finding's own title, then two sections:

- **FIX** — what to change and why it works, in plain English. Enough that someone who has not read the
  finding can act on it, and enough that a reviewer can disagree with it before any code is written.
  It names the functions it touches, but the code itself belongs in the diff, not here.
- **TEST** — how to tell the fix worked: what to post, what to look for in the output, and what would
  count as a failure. Empty until written. Nothing here may need a controller, a sender console or a
  dry run — everything is settled from posted output and from the firmware's own source.

Each section carries its own status line, and the two say different things — a fix can be in the code
while its test has never been run, and a test can fail on a fix that was applied:

| Section | Status line | Values |
|---|---|---|
| FIX | `**Status:** ` | `[ ] applied` while it is still a proposal; `[x] applied` plus the commit **subject** once a commit carries it — a subject survives an amend or a rebase, and the CR id in it makes `git log --grep` find the commit; a sha written here does not survive, because this line ships inside the very commit it names |
| TEST | `**Status:** ` | `open` — not run, or not yet written; `pass`; `fail — <what was seen>` |

A `fail` is not a reason to edit the FIX in place. Say what failed in the test status, then revise the
FIX above it — the point of the two lines is that the disagreement between them stays visible.

---

## CR-11 — the spoilboard base is probed to a target measured in the frame the probe is establishing

**Finding:** [`CoverageFindings.md` → CR-11](CoverageFindings.md) — Professional, Machine damage, Certain.

### FIX

**Status:** `[x] applied` — commit `CR-11: Give the spoilboard base probe a relative target and its own
reach`. Named by subject, not by sha: this line is written in the same commit it describes, so a sha here
is wrong the moment that commit is amended or rebased — as it already was once. `git log --grep "CR-11"`.

Write a provisional Z0 into the base WCS at the tool's current height immediately before the probe,
exactly as the `Current XY & Probe Z` start mode already does. In `writeBaseEstablish()`, after the base
has been transit-selected and before the `probeTool()` call, emit a Z-only origin write into the base
register — X and Y are left alone, so nothing the operator stored for the base is disturbed.

That single block re-bases the frame on where the tool is standing, which turns `G38 Target` from an
absolute position measured against a stale register into a distance to search: a target of `-10` becomes
"probe down at most 10 mm from here" on every run, whatever the register happened to hold. It closes both
failure directions at once — there is no longer a stored value that can read high and turn the target into
a plunge, nor one that can read low and put the target above the tool so the probe moves up and alarms.
`probeTool()` overwrites the provisional value with the real one a few blocks later, so it outlives
nothing, and the retract that follows is then measured from a Z0 that is known.

It is sound here for the same reason it is sound in that start mode: the base probe emits no XY move, so
the tool is standing where the operator parked it, and the finding's own operator precondition already
requires that spot to be over bare spoilboard. The write sits inside the existing tool-0 / jet-tool guard,
so the skip path is untouched, and Marlin returns before any of this, so the `G92` fallback never comes
into it. It belongs with an Info comment in the same words the start mode uses, so a reader of the G-code
can see why the extra origin write is there.

**The reach had to change with it, and no finding said so.** Making the target relative is only half the
job: it decides *where the search starts*, and the target then decides *how far it goes*. No CR asks
whether the shipped `-10` is far enough to find the spoilboard — CR-11 and CR-12 are about the frame the
number is measured in, never its size, and the "never reaches the stock" in CR-15 is a different mechanism
on the part probe. The question only becomes answerable once this fix lands, because until then the target
is an arbitrary absolute and no reach can be reasoned about at all.

Answered, it fails. `G38 Target` is one property shared by every probe in the post, and its description
sets it for the part probe — "deep enough to reach the plate and no deeper", where the tool starts a few
millimetres above the stock top. The base probe starts nowhere near there: it probes wherever the tool
already sits, and that spot has to clear the stock and the clamps. On a job with 18 mm stock in clamps the
tool is easily 30–50 mm above the spoilboard, so a 10 mm search never touches, and a `G38.2` that travels
its full distance without touching is a failed probe — GRBL alarms and the job stops. The provisional Z0
alone would therefore have turned an unbounded plunge into a job that reliably refuses to start at the
shipped default. Better, and still wrong.

So the base probe gets its own reach: **`BASE_PROBE_REACH_MM`, a constant of 100 mm defined at the top of
the post**, emitted as a negative distance in output units. A constant and not a dialog control, for two
reasons. There is nothing here the operator knows that the post does not — the number only has to exceed
the tool's height above the spoilboard, and 100 mm covers any stock-and-clamps stack these machines hold.
And the safety argument that keeps `G38 Target` short does not apply at the base at all: the part probe is
short so a mis-set origin cannot drive the tool through the workpiece, whereas the base probe is over bare
spoilboard by its own precondition, with nothing beneath it but the surface it is hunting for. A long base
reach is the safe answer, not the risky one. Group 5 gains no field, which is worth something on its own.

Two consequences to state rather than discover. A search that runs its full 100 mm at the probe feed
(`F30` by default) takes about three minutes before the controller gives up — slow, but it only happens on
a probe that was going to fail anyway. And the reach is not in the dialog, so the file has to say it: the
fix emits an Info comment naming the depth it is about to search, which is the only place an operator can
read the number without opening the post.

`probeTool()` takes the distance as a third argument, defaulting to the `G38 Target` property when absent,
so the part probes and the tool-change re-probe are untouched — there are exactly two call sites, and the
other passes nothing. The property's own description said it bounds "the probe move", which is no longer
true of every probe, so it now says it bounds the part probes only.

This fixes the base establish only. CR-12 is the same mechanism on the part probes, where the operator has
alternatives in the dialog and the answer may be a different one; fixing this does not fix that. The reach
question, however, applies to CR-12's paths too once they are made relative — and there the answer is
likely different again, because a part probe that overshoots is over the workpiece, not over bare board.

### TEST

**Status:** `open`

Four rows, all `posted` — a real file from the real post, read for exact tokens. Two of them come from one
posted file, because the thing that must be shown is that two probes in the same job now emit *different*
targets. Nothing here needs a controller: every criterion is a token present or absent in the g-code.

| Test | Proves | Setup delta from defaults | State |
|---|---|---|---|
| CR11a | the base probe searches a distance from where the tool stands, not a position in a stale register | GRBL/mm, Comment Level `Info`, `Fixed Z Reference` = Spoilboard, `Reserved WCS` = G59, `Probe to Set Base` = `Probe Z`, one milling tool, tool number ≠ 0 | ⬜ |
| CR11b | the part probe is unchanged — the third argument defaults | same posted file as CR11a, `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0` | ⬜ |
| CR11c | the reach converts with the output units | CR11a with the job in inches | ⬜ |
| CR11d | the RepRap branch carries the same reach | CR11a with firmware = RepRap | ⬜ |

**Expect — CR11a.** Inside the `Establish spoilboard base G59` block, in this order:

```
G59                                       (only when the operating WCS is not already G59)
(   Provisional Z0 at the current height so the probe target is a relative limit)
G10 L20 P6 Z0
(   Search down to Z-100 from the current height)
G38.2 F30 Z-100
G10 L20 P6 Z0.8                           (the real Z0, probe thickness)
```

The discriminator is **`Z-100` on the `G38.2`, not `Z-10`** — that one token is the whole fix, since the
old file emitted the property's value here. Two absences carry as much as the presences: the provisional
`G10 L20 P6 Z0` must carry **no X and no Y word**, or the fix has silently zeroed the base's stored XY;
and no `G38.2 … Z-10` may appear anywhere inside this block.

**Expect — CR11b.** In the *same file*, below the base block, the first part's probe emits
`G38.2 F30 Z-10` — the property's value, unchanged. A file where both probes read `Z-100` means the
default was not honoured and every part probe just got a 100 mm reach, which is the dangerous direction.
The CR-12 warning about probing from a stored Z0 is expected on this path and is not a failure of this
row. This is the presence-based sibling the absence in CR11a needs.

**Expect — CR11c.** `G38.2 F1.181 Z-3.937` and the comment reading `Search down to Z-3.937` — 100 mm
converted, not 100 inches. A file showing `Z-100` in an inch job means the constant was emitted raw, which
would command a 2.5 m plunge.

**Expect — CR11d.** Same block shape as CR11a with `Z-100` on the `G38.2`, proving the reach reaches the
non-GRBL branch too. Posting it again with `Probe with G38.2` off must emit `G28 Z` and **no `G38.2` and
no target of any kind** — that path takes no reach and must not have grown one.

**What a fail looks like.** `Z-10` in CR11a: the third argument is not arriving. `Z-100` in CR11b: the
default is broken. `Z-100` in CR11c: the units conversion was missed. X or Y on the provisional `G10`: the
Z-only write is wrong. Record it in the status line above and revise the FIX; do not edit the expectation
to match what was seen.

---

## CR-13 — with `Retract Across Parts` off, the inter-part traverse height is resolved in one frame and emitted in another

**Finding:** [`CoverageFindings.md` → CR-13](CoverageFindings.md) — Professional, Machine damage, Certain.

### FIX

**Status:** `[ ] applied`

**Delete `Retract Across Parts` from the dialog.** Not repair the height it selects — remove the control
that selects it, because the control has no answer worth giving.

The case for that is not merely that nobody would want to turn it off. It is that **off does not do what
its name says.** Read `writeWCS()`: when `crossPart` is false the traverse retract is not suppressed, it is
*diverted*. The bare `isTraverse` arm still emits `resetAll()`, `rapidMovementsZ(probeSafeZ())`,
`flushMotions()` — a retract on every traverse, just not the right one. So the checkbox does not read
"cross-part safety on / off". It reads "retract to the height that clears the fixtures / retract to a
height belonging to neither part", and the dialog says none of that. An operator who turns it off to save
a lift does not save the lift; they only stop it being correct.

**And the height in that arm cannot be fixed in place.** This matters, because the obvious narrow fix is to
resolve `probeSafeZ()` against the *previous* section and emit it *after* the WCS select, closing both
halves of the finding. That fails. The arm is reached precisely when the job has no fixed Z reference, and
Guard B already states the reason no height works there: across WCS whose offsets are only known after
probing at runtime, no single clearance is meaningful. Both frames are unknown to the post; there is no
number to compute in either. The arm has no correct contents, so the only repair is to make it unreachable.

Removal does exactly that, in three moves.

**Guard B stops being optional.** Today the property gates the guard, so turning it off is the *only* way
to post a multi-WCS job with `Fixed Z Reference` = None — the configuration the guard exists to refuse.
Dropping the property from the condition leaves `!usesMachineZDatum() && collectDistinctOffsets().length > 1`,
which refuses that job outright. The message has to be rewritten anyway, since it currently offers "or turn
off Retract Across Parts" as a third way out; it should name the two fixed-reference answers and, for the
operator who can supply neither, posting one job per part.

**`crossPart` collapses into `isTraverse`.** With the property gone, `machineFrame` and `baseRelative` gate
on the traverse alone. The Debug line that echoed `C_SafeZAcrossWcs` goes with it.

**`baseRelative` widens, and this is the half the finding does not mention.** The test is
`base != 0 && base != workOffset`. That second clause sends one legitimate job into the broken arm *even
with the toggle on*: a job that assigns a part to the reserved base WCS itself. Guard A permits this —
cutting *in* the base is fine, only re-establishing its origin is the error — so with both origin modes on
`Skip` the job posts and every traverse into that part takes the bare arm. The exclusion is unjustified:
the base frame *is* the fixed reference, so `Inter Part Travel Z` measured in it is exactly the right height
whether the part being entered lives in that register or another, and `retractThroughBaseClearance()`
already suppresses the redundant select for the case where it is the same one. Dropping the clause to
`base != 0` costs at most one duplicate WCS line and closes the case. Without this, removing the property
would leave the defect alive on a narrower path — which is why the fix is not one hunk.

**What is left of the arm becomes an error.** After those three, `isTraverse && !machineFrame &&
!baseRelative` requires `base == 0` and no machine-Z datum on a multi-WCS job, which Guard B has already
refused. It is unreachable. Deleting it outright would mean a traverse with *no* retract at all if a future
guard change ever reopened the path — worse than the bug being fixed. So it keeps its shape and raises an
internal error naming Guard B, which never fires on a valid job and fails loudly if the premise ever breaks.

**Two costs, stated rather than discovered.**

An operator with neither a touch plate nor a homed Z can no longer post a multi-WCS job at all. Today they
can, by turning the toggle off — and what they get is the traverse this finding says can pass below the next
part's clamp. A refusal is the honest answer and the guard message must carry the alternative, but this is a
capability removed, not merely a checkbox tidied.

A stored Setup carrying `false` becomes inert: Fusion ignores a property the post no longer defines, so the
behaviour reverts to on. That is the safe direction, but a job that posted last week may refuse to post now
— at Guard B, with the new message, which is the correct outcome arriving as a surprise.

Two descriptions name the deleted control and must move with it: `Fixed Z Reference` says the None answer
makes `Retract Across Parts` unavailable on a multi-WCS job, which becomes "single-part jobs only, the post
refuses the other"; and `Subsequent WCS / Part` points at it for the traverse retract, which becomes
"separate, automatic, and measured in whatever frame Fixed Z Reference names". The user guides and
`property-reference.md` also carry it (`guide-pro.md` twice, including a step reading "Leave Retract Across
Parts on") — leave-alone files, so they are flagged here and not touched by the code commit. Removing a
property is the clearest case there is for re-syncing `property-reference.md`, which `doc-sync` already
reports behind.

Group 5 loses a field, which is worth something on its own and follows the same argument as the group-3
fold: a control whose every answer but one is wrong is not a choice, it is a hazard with a label.

### TEST

**Status:** `open`

Four rows, all `posted`. The dialog change is testable from a posted file without opening Fusion's dialog,
because the file's own property dump records the whole dialog state — a property that has been removed is
absent from it. One row expects **no file at all**: a guard that refuses is proved by the refusal.

| Test | Proves | Setup delta from defaults | State |
|---|---|---|---|
| CR13a | the base route is taken on every traverse and the wrong-frame arm is gone | GRBL/mm, Comment Level `Info`, two parts on G54/G55, `Fixed Z Reference` = Spoilboard, `Reserved WCS` = G59, `Inter Part Travel Z` = 40 | ⬜ |
| CR13b | the escape hatch is closed — the guard refuses instead of posting | CR13a with `Fixed Z Reference` = None, posted from a Setup that previously had `Retract Across Parts` off | ⬜ |
| CR13c | the machine-Z route is untouched | CR13a with `Fixed Z Reference` = Machine Z, `Axes Homed and Trusted` = XYZ, `Home at Job Start` = Home, `Inter Part Travel Z` = an absolute machine Z | ⬜ |
| CR13d | a part assigned to the base WCS takes the base route, not the bare arm | CR13a plus a third part on **G59**, `First WCS / Part` and `Subsequent WCS / Part` both = `Use Active WCS X0 Y0 Z0`, `Probe After Tool Change` off | ⬜ |

**Expect — CR13a.** At the G54 → G55 traverse, in this order:

```
G59                                       (transit-select the base)
(   Retract to spoilboard-base clearance G59 before traverse)
G0 Z40
G55
```

The discriminator is an absence with a presence beside it, which is the pairing an absence-based row needs.
The absence: **`Retract to Safe Z before WCS change` appears nowhere in the file** — that comment is the
bare arm's own, and it is the token the old build emitted here. The presence: the base-clearance comment
and its `G0 Z40` in the same block, proving the traverse still retracts and retracts higher. Second absence:
the property dump lists no `Retract Across Parts` and no `spoilboardSafeZAcrossWcs`.

**Expect — CR13b.** **No output file.** Fusion reports the Guard B error, and the text must name the
spoilboard answer, the machine-Z answer, and posting one job per part. It must **not** contain the words
"turn off" — that clause is the removed escape hatch, and its survival would mean the old message shipped.
This is also the stored-value row: the Setup's remembered `off` must not resurrect the old path, and a file
appearing at all is the failure.

**Expect — CR13c.** At the traverse, `G53 G0 Z<travel> F<travel speed>` under the machine-frame comment, and
again no `Retract to Safe Z before WCS change` anywhere. Proves the collapse of `crossPart` into
`isTraverse` did not disturb the route that was already correct.

**Expect — CR13d.** At the G55 → G59 traverse, the same base-clearance block as CR13a, then the `G59`
select. A duplicate `G59` line either side of the retract is expected and is not a failure — it is the
stated cost of dropping `base != workOffset`. Seeing `Retract to Safe Z before WCS change` here is the
failure this row exists for: it means the widening was omitted and removing the property alone left the
defect reachable.

**What a fail looks like.** `Retract to Safe Z before WCS change` in any of a/c/d: the arm is still live on
that path. A file produced by CR13b: Guard B is still gated, or still offers the toggle. The property still
in any dump: the deletion did not land. An internal-error abort on a/c/d: a guard premise is wrong and the
`baseRelative` widening should be re-read before anything else. Record it in the status line above and
revise the FIX; do not edit the expectation to match what was seen.
