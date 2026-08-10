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
- **TEST** — how to tell the fix worked: the emitted block stream, what to look for in it, and what would
  count as a failure. Empty until written. Nothing here may need a controller, a sender console or a
  dry run.

### How a walk is run

The method is the review's own, narrowed: **hand-execution of the callback sequence against the source**,
tracking module state as it changes — the same method that produced these findings in the first place, and
described in full in [`CoverageReviewPlan.md` → Method](CoverageReviewPlan.md). Nothing is executed, and a
walk here is not a re-review: it fixes a property set and follows **only the paths the fix touched**,
writing the block stream those paths emit.

1. Fix the property set, the firmware, the units and the job shape.
2. Enter at the callback the change sits under, and hand-execute forward, resolving every helper by
   reading it — no path is assumed, including the ones the fix did not mean to reach.
3. Write the emitted blocks in order, with the value of each formatted word computed.
4. Check the stream against the invariants the fix claims: **I1 frame**, **I5 guard fidelity**,
   **I6 units** — and, for a removed branch, that it is unreachable from the dialog rather than merely
   unvisited.

**What a walk settles, and what it does not.** It settles what the source emits and which paths are
reachable, which is *stronger* than one posted file for absence claims: a token missing from a posted file
is missing from that configuration, while a token missing from the source is missing from all of them. It
does not settle host behaviour — how Fusion's `createFormat` renders a value, or how it treats a property
a stored Setup remembers but the post no longer declares. Where a walk rests on one of those, the row says
so, and no pass depends on it.

Each section carries its own status line, and the two say different things — a fix can be in the code
while its test has never been run, and a test can fail on a fix that was applied:

| Section | Status line | Values |
|---|---|---|
| FIX | `**Status:** ` | `[ ] applied` while it is still a proposal; `[x] applied` plus the commit **subject** once a commit carries it — a subject survives an amend or a rebase, and the CR id in it makes `git log --grep` find the commit; a sha written here does not survive, because this line ships inside the very commit it names; `deferred — <why, and what would settle it>` when the design is finished but deliberately not being applied; `withdrawn — <the premise that settled it>` when the finding it answers turned out not to be a defect |
| TEST | `**Status:** ` | `open` — not run, or not yet written; `pass`; `fail — <what was seen>`; `n/a — <why>` where the FIX is withdrawn |

A **deferred** FIX is not a stalled one. It says the design is done and the decision to apply it is being
withheld on a stated question — most often whether the finding's premise holds — and it keeps the design
whole so that answering the question is all a return to it needs. Its TEST stays `open`: walking a fix
nobody has decided to apply proves only that the walk works. The finding's own box in
`CoverageFindings.md` carries the same word and the same reason, since a reader of the ledger has to see
that the entry exists and is not being acted on.

A **withdrawn** FIX is the deferral's other ending: the stated question was answered, and the answer was
that the finding is not a defect. The entry is not deleted and the design is not deleted with it — the
premise that settled it is written at the top, and the design stays below the line, because a withdrawal
is only as good as the premise it rests on and a premise can be contradicted later. Its TEST goes to
`n/a`, and the finding's box in `CoverageFindings.md` carries the same word and the same premise.

Each row names its **method**: `walk` — hand-executed against the source, per the procedure above; or
`posted` — a real file from the real post. A `walk` row is complete when the block stream has been written
out and checked; it does not become "more passed" if a post is taken later, and where the two would answer
the same question the walk answers it for every configuration rather than one.

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

**Status:** `pass` — all four rows walked against the post at `c319e69`.

| Test | Method | Proves | Property set | State |
|---|---|---|---|---|
| W11a | walk | the base probe searches a distance from where the tool stands, not a position in a stale register | GRBL/mm, Comment Level `Info`, `Fixed Z Reference` = Spoilboard, `Reserved WCS` = G59, `Probe to Set Base` = `Probe Z`, `Inter Part Travel Z` = 40, one part on G54, tool 1 | ✅ |
| W11b | walk | the part probe is unchanged — the third argument defaults | the other `probeTool()` call site, same job | ✅ |
| W11c | walk | the reach converts with the output units | W11a in inches | ✅ |
| W11d | walk | the RepRap branch carries the same reach, and the `G28` arm did not grow one | W11a on RepRap, `Probe with G38.2` on, then off | ✅ |

**W11a — walked.** Entered at `writeFirstSection()`. `writeWCS()` emits `G54` and leaves
`currentWorkOffset = 1`; `writeFixedZReference()` reads `Spoilboard` and calls `writeBaseEstablish()`,
where `base = 6`, `gname = G59`, `mode = "Probe Z"` and the tool-0 guard passes. `operatingWcs = 1`, so
`switched` is true. The stream:

```
( Establish spoilboard base G59)
(   Select base G59 to probe and retract in its own frame)
G59                                        wcsGcode(6) = 59; currentWorkOffset = 6; resetAll()
(   Provisional Z0 at the current height so the probe target is a relative limit)
G10 L20 P6 Z0                              writeWcsOrigin(6, undefined, undefined, 0)
(   Search down to Z-100 from the current height)
( Probe to Zero Z)                         probePauseBefore/After = false under "Probe Z"
(   Do Probing)
(   Set Z to probe thickness: Z0.8)
(   Retract the tool to 40)
G38.2 F30 Z-100                            searchZ = -propertyMmToUnit(100) = -100
G10 L20 P6 Z0.8                            the real Z0
G0 Z40 F<travel Z>                         retract, base frame, after resetAll()
(   Restore operating WCS G54 after base probe)
G54                                        currentWorkOffset = 1
```

**I1 frame** — every absolute Z in the block is written after the `G59` transit-select, and the `G0 Z40`
retract follows the `G10 L20 P6 Z0.8` that establishes the frame it is measured in. **I6 units** —
`propertyMmToUnit` is applied once to `BASE_PROBE_REACH_MM` at [:2995](../MPCNC_v4.0_Beta2.cps#L2995) and
the result is passed through as `searchZ`; `probeTool()` does not re-wrap it.

Both absences the posted version of this row was going to check are settled more strongly here. The
provisional origin write passes `undefined` for x and y **at the call site**, and `writeWcsOrigin()` maps
`undefined` to an omitted word, so no X or Y word can be emitted — not "was not in this file" but "cannot
be". And `G38.2 … Z-10` cannot appear in this block because `searchZ` is bound before the default arm is
reached, so `probeG38Target` is never read on this path.

**W11b — walked.** `probeTool` has exactly two call sites: [:2999](../MPCNC_v4.0_Beta2.cps#L2999) passes
three arguments, [:2644](../MPCNC_v4.0_Beta2.cps#L2644) passes none. On the second, `searchZ == undefined`
selects `propertyMmToUnit(getProperty(properties.probeG38Target))` = `-10`, giving `G38.2 F30 Z-10`, and
`retractZ == undefined` selects `probeSafeZ()` exactly as before. Nothing on that path reads
`BASE_PROBE_REACH_MM`, so the part probes and the tool-change re-probe emit what they always did. This is
the presence-based sibling W11a's absences need, and it is the dangerous direction: had the default arm
broken, every part probe would have gained a 100 mm reach.

**W11c — walked.** With `unit == IN`, `propertyMmToUnit(100)` = `100 / 25.4` = `3.937007…`, negated.
`zFormat` carries 4 decimals in inches, so the `G38.2` word is `Z-3.937`, and `xyzFormat` (also 4) puts
`Z-3.937` in the comment. **The expectation this row replaced was wrong about the feed**: it read
`F1.181`, but `fFormat` is `decimals: 2` in inches, so `propertyMmToUnit(30)` = `1.181102…` is emitted as
**`F1.18`**. The claim that matters is the magnitude — 3.937 inches is 100 mm, and a `Z-100` here would be
a 2.5 m plunge — and the walk confirms the conversion happens once.

**W11d — walked.** On RepRap with `Probe with G38.2` on (the default), the non-GRBL branch at
[:3663](../MPCNC_v4.0_Beta2.cps#L3663) formats the same `searchZ`, so the block is W11a's with the same
`Z-100`. With it off, the branch emits `G28 Z` and no target of any kind: `searchZ` is computed but never
formatted, so the reach cannot leak onto that path.

**One observation the walk turned up, recorded rather than fixed.** On the `G28` arm the provisional
`G10 L20 P6 Z0` is still emitted, and there it does nothing — `G28 Z` takes no target, and the real
`G10 L20 P6 Z0.8` overwrites the provisional value a few blocks later with nothing reading it in between.
Harmless, and one redundant line on a path most operators never select.

**And one that is not harmless, though CR-11 did not create it.** `Probe with G38.2`'s own description
records that RRF up to and including 3.1.1 interprets the `G38.2` target as **machine** coordinates while
this post emits a work-frame target. That was already wrong before this fix; what changed is the size of
the consequence, since the base probe's word went from `Z-10` to `Z-100`. The mitigation is the one the
dialog already states — set `Probe with G38.2` **off** on RRF ≤ 3.1.1 — and on that setting this fix emits
no target at all. It belongs to the professional register when `PReview.md` returns; it is noted here so it
is not rediscovered.

**What a fail would have looked like.** `Z-10` in W11a: the third argument not arriving. `Z-100` in W11b:
the default arm broken. `Z-100` in W11c: the conversion missed. An X or Y word on the provisional `G10`:
the Z-only write wrong. None of these occurred.

---

## CR-13 — with `Retract Across Parts` off, the inter-part traverse height is resolved in one frame and emitted in another

**Finding:** [`CoverageFindings.md` → CR-13](CoverageFindings.md) — Professional, Machine damage, Certain.

### FIX

**Status:** `[x] applied` — commit `CR-13: Remove Retract Across Parts and make Guard B unconditional`.
Named by subject, not by sha, for the reason in the layout table above. `git log --grep "CR-13"`.

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

**Status:** `pass` — all five rows walked against the post at `fbd1591`.

| Test | Method | Proves | Property set | State |
|---|---|---|---|---|
| W13a | walk | the base route is taken on every traverse and the wrong-frame arm is gone | GRBL/mm, Comment Level `Info`, two parts on G54/G55, `Fixed Z Reference` = Spoilboard, `Reserved WCS` = G59, `Inter Part Travel Z` = 40 | ✅ |
| W13b | walk | the escape hatch is closed — Guard B refuses whatever a stored Setup remembers | W13a with `Fixed Z Reference` = None | ✅ |
| W13c | walk | the machine-Z route is untouched by the `crossPart` collapse | W13a with `Fixed Z Reference` = Machine Z, `Axes Homed and Trusted` = XYZ, `Home at Job Start` = Home | ✅ |
| W13d | walk | a part assigned to the base WCS takes the base route, not the bare arm | W13a plus a third part on **G59**, `First WCS / Part` and `Subsequent WCS / Part` both = `Use Active WCS X0 Y0 Z0`, `Probe After Tool Change` off | ✅ |
| W13e | walk | the surviving arm is unreachable, and the new `error()` cannot fire on a job that should post | all four above, plus the first-section entry | ✅ |

**W13a — walked.** At the second section, `writeWCS()` has `workOffset = 2`, `currentWorkOffset = 1`, so
`previousWorkOffset = 1` and `isTraverse` is true. `base = 6`; `machineFrame` is false (the reference is
Spoilboard, not Machine Z); `baseRelative = isTraverse && base != 0` is **true**, taking
`retractThroughBaseClearance()`:

```
(   Retract to spoilboard-base clearance G59 before traverse)
G59                                        currentWorkOffset was 1, so the select is emitted
G0 Z40 F<travel Z>                         rapidMovementsZ(interPartTravelZ()) after resetAll()
( WCS changed: 1 -> 2)
G55
```

**I1 frame** — the retract is emitted after the base is selected, so `Z40` is read in the frame
`writeBaseEstablish()` established, not in the part's. **I2** — the traverse height is reached before the
WCS changes, so nothing crosses the bed at a height belonging to the previous part.

The absence this row exists for is settled by the source rather than by one file: the string
`Retract to Safe Z before WCS change` no longer occurs in the post, so no configuration can emit it. Same
for the property dump — `writeAllProperties()` enumerates `for (key in properties)`
([:2763](../MPCNC_v4.0_Beta2.cps#L2763)), and the key is gone from the object, so it cannot be printed.

**W13b — walked.** `validateJob()` reaches Guard B with `base = 0` (the reference is None, so
`getReservedBaseWcs()` returns 0 before consulting `Reserved WCS`), `!usesMachineZDatum()` true and
`collectDistinctOffsets().length = 2`. The `error()` fires, before any output. **I5** — the condition now
reads only the job's own shape and the reference; no property gates it, so there is no setting that
suppresses it.

That also disposes of the stored-Setup question a posted row would have had to raise. It does not matter
whether Fusion still remembers `spoilboardSafeZAcrossWcs = false` from an earlier Setup, because no code
reads that key any more — the value is unreachable, not merely overridden. This is one of the questions a
walk answers and a post cannot: a post would only show that *this* Setup behaved.

**W13c — walked.** `machineFrame = isTraverse && usesMachineZDatum()` is true, so the chain takes
`writeMachineTravelZ()` and emits `G53 G0 Z<travel> F<travel Z>` with its comment, unchanged from before
the fix — the collapse of `crossPart` into `isTraverse` removed a conjunct that was always true whenever
this route ran. Guard B does not fire here: its condition is `!usesMachineZDatum()`.

**W13d — walked.** Guard A first, since this job would be refused before it could be walked otherwise:
`baseOriginWriteReason(6)` computes `onStart = (probeOnStart != "Skip")` = false, `onChange` = false and
`reprobe` = false, so no trigger can return and the job passes. At the third section, `workOffset = 6`,
`previousWorkOffset = 2`, `base = 6`. Under the old test `base != workOffset` this was false and the
section fell into the bare arm; under `base != 0` it is **true**:

```
(   Retract to spoilboard-base clearance G59 before traverse)
G59                                        currentWorkOffset 2 != 6, so selected here
G0 Z40 F<travel Z>
( WCS changed: 2 -> 6)
G59                                        writeWCS's own select -- the predicted duplicate
(   Move to this part's stored origin X0 Y0)
G0 X0 Y0 F<travel XY>                      onChangeMode "Skip", Z held at 40
```

The duplicate `G59` is confirmed, is idempotent, and is the stated cost of the widening. The XY move that
follows happens at the travel height, in the base frame — which is this part's own frame here, so **I1**
holds for it too.

**W13e — walked.** The surviving `else if (isTraverse)` arm needs `isTraverse && !usesMachineZDatum() &&
base == 0`. Guard B refuses exactly that conjunction at `onOpen()`, before output, so no job that produces
a file can reach it: the `error()` is unreachable, which is what it is for. The other direction matters as
much — it must not fire on a job that *should* post. It cannot: on a first section `previousWorkOffset` is
`undefined`, so `isTraverse` is false and the whole chain is skipped, which is the path W11a walked through
on the way to the base establish. A single-WCS job never reaches the chain at all, returning earlier at
`workOffset == currentWorkOffset`.

**What a fail would have looked like.** The bare arm still emitting on any of a/c/d; Guard B silent in
W13b, or its message still offering "turn off"; the property surviving in the dump; the internal error
firing anywhere in a/c/d, which would have meant the `baseRelative` widening was wrong rather than the
guard. None occurred.

---

## CR-14 — the base-establish tool-0 skip leaves the job believing a base was established

**Finding:** [`CoverageFindings.md` → CR-14](CoverageFindings.md) — Professional, Machine damage, Certain.

### FIX

**Status:** `[x] applied` — commit `CR-14: Make the fixed-Z predicate answer for the tool that must probe`

The finding names its own fix — *the skip itself is right; its silence is not, and the predicate should
reflect what was actually emitted* — and that is the shape of this. But making the predicate honest fixes
five of the six consumers and leaves the sixth, which is the one that moves the machine. So four parts.

**One predicate, asked from both places.** The condition `writeBaseEstablish()` skips on is
`tool.number != 0 && !tool.isJetTool()`, and `validateJob()` needs the same answer before any section is
current. Give it a name and let both sites read it:

```js
function baseProbeCanRun() { ... getSection(0).getTool() ... }
```

The **first** section's tool is the right one to ask about, and not an approximation: the establish runs
once, from `writeFirstSection()`, which `onSection` calls under `isFirstSection()`. A job whose second
operation carries a real tool still never writes the base. Inside `writeBaseEstablish()` the new call is
exactly equivalent to what is there now — `tool` *is* section 0's tool at that point — so this part changes
no output at all. It exists so the two sites cannot drift, which is the same reason `parkCanRetract()` and
`machineHomesXY()` exist.

**The predicate stops asking the dialog.** `fixedZEstablishedInFile()` currently reads "not Marlin, and the
dialog names a reference". It should read "…and the reference will actually be established": the spoilboard
arm is the only one that probes, so it is the only one an unprobeable tool defeats. The machine-Z arm needs
no change — it emits `G53` and touches no probe — and keeping the test confined to the spoilboard arm is
what stops this fix leaking into a feature it has nothing to do with.

That one edit corrects five consumers at once, which is the argument for fixing the predicate rather than
each caller: `partProbe()`'s "no Z reference is established" warning starts firing
([:3047](../MPCNC_v4.0_Beta2.cps#L3047)); `parkCanRetract()` starts answering no, so
`writeMachineParkXY()` warns instead of retracting into an unwritten register
([:2092](../MPCNC_v4.0_Beta2.cps#L2092)); and two `validateJob()` warnings start reaching Fusion's dialog
([:1531](../MPCNC_v4.0_Beta2.cps#L1531), [:1547](../MPCNC_v4.0_Beta2.cps#L1547)).

A sixth consumer moves the *other* way, and it is worth stating because it looks like a regression and is
not. The warning at [:1520](../MPCNC_v4.0_Beta2.cps#L1520) — *establishing the fixed Z reference moves the
tool before "First WCS / Part" records the current position* — currently fires in the tool-0 case, where
nothing moves the tool at all, because the establish was skipped. It stops firing. That is a false positive
removed, not a warning lost.

**The silence itself.** The skip's `else` writes a Debug comment, which is invisible at every level an
operator runs. It should `writeWarning()`, in the same form as the Marlin skip four lines above it — that
one already got this right, and the two skips should not report differently. A matching `validateJob()`
warning puts it in Fusion's dialog as well as the file, which is the pattern the tool-change suppression
warning already uses at [:1554](../MPCNC_v4.0_Beta2.cps#L1554).

**And the consumer the predicate does not reach — Guard B′.** `writeWCS()` takes the base route on
`baseRelative = isTraverse && base != 0`, and `base` comes from `getReservedBaseWcs()`, which answers which
register is *reserved*. It has to: Guard A needs that answer whether or not the probe ran. So on a
multi-WCS job with an unprobeable first tool, every traverse still emits `G59` and `G0 Z<Inter Part Travel
Z>` into a register nothing has written — a rapid to an absolute height in an unestablished frame, which is
the machine-damage move this finding is about, and the predicate fix does not touch it.

Routing `baseRelative` through the honest predicate would drop those traverses into the arm CR-13 turned
into an internal error, which is the wrong answer twice over: the message would say "internal" about an
ordinary misconfiguration, and it would abort mid-output instead of before it. The right answer is to refuse
the job at validate time, beside Guard B and for the same reason — a multi-WCS job with no fixed Z reference
*in fact* is what Guard B exists to refuse, and CR-13 made that guard unconditional precisely so nothing
could post around it.

So a second site, phrased on the honest predicate and placed where a base is known to be reserved:

- **Guard B** (unchanged): no fixed Z reference is named at all.
- **Guard B′** (new): one is named, and this job will not establish it — name the tool, since that is the
  thing the operator has to change, and the remedy is different from Guard B's.

Two sites rather than one message with a conditional clause, because each names exactly one remedy and the
post's guards are meant to read that way.

**What this does not do.** It does not make a tool-0 job establish a base — nothing can; a tool that cannot
touch a plate cannot probe one. A single-WCS spoilboard job with tool 0 still posts, now with two warnings
and no absolute Z moves into the unwritten register. That is the honest outcome, and it is what the finding
asks for.

**Two corrections the walk made to this design before it was applied.** Both are recorded rather than
silently edited above, because each is a thing the proposal asserted and the source refuted.

*The placement rationale was false, and the placement with it.* This entry said Guard B′ had to be hoisted
above the `base == 0` early return, "which would otherwise skip this case entirely". It would not: that
return fires only when **no** base is reserved, and Guard B′'s whole subject is a job where one is. Reaching
the code below the return is exactly the condition Guard B′ was testing for separately. So the hoist bought
nothing and cost something — above the RepRap-slot check, a `G59.1` base on GRBL with tool 0 would report
the tool, and fixing the tool would then surface the slot error the operator could have been told about
first. Applied **below** the slot check, and the redundant `getReservedBaseWcs() != 0` clause dropped with
the local `base` used instead.

*The warning text broke `writeWarning()`'s one documented rule.* The proposed string carried
`(tool number 0 or a jet tool)`, and `writeWarning()` says in as many words that its text may contain no
parentheses: `writeCommentLine()` hands it to `sanitizeMessageText(_, "()")`, which blanks every run of them
because a GRBL comment cannot nest and ends at the first `)`. The clause is set off with commas instead.
The `error()` texts are unaffected — those go to Fusion's dialog, not into a comment, which is why Guard A's
own message may keep its parentheses.

**Diffs, as applied.**

```diff
+// The tool the base probe would use is the FIRST section's: writeBaseEstablish() runs once, from
+// writeFirstSection(), which onSection calls under isFirstSection(). Tool 0 and jet tools cannot touch
+// off a plate, so the probe is skipped for them -- rightly, but the reserved base is then never written.
+// Named so validateJob(), which has no current section, and the establish itself cannot disagree. CR-14.
+function baseProbeCanRun() {
+  if (getNumberOfSections() == 0) return false;
+  var t = getSection(0).getTool();
+  return t.number != 0 && !t.isJetTool();
+}
```

```diff
 function fixedZEstablishedInFile() {
-  return fw != eFirmware.MARLIN && fixedZEstablishedAtStart();
+  if (fw == eFirmware.MARLIN) return false;
+  if (!fixedZEstablishedAtStart()) return false;
+  // The spoilboard arm is the only one that PROBES, so it is the only one a tool that cannot probe
+  // silently defeats; the machine-Z arm emits G53 and needs no tool at all. CR-14.
+  return usesMachineZDatum() || baseProbeCanRun();
 }
```

```diff
+  // Equivalent to the "tool.number != 0 && !tool.isJetTool()" this replaced -- `tool` IS section 0's
+  // tool here -- but asked through the shared predicate so validateJob() cannot answer differently. CR-14.
-  if (tool.number != 0 && !tool.isJetTool()) {
+  if (baseProbeCanRun()) {
     ...
   } else {
-    writeComment(eComment.Debug, " writeBaseEstablish: probe skipped (tool 0 or jet tool)");
+    // A warning and not a Debug comment: this is the same class of skip as the Marlin one above, which
+    // already warns, and Debug is invisible at every level an operator runs. CR-14.
+    writeWarning("reserved base " + gname + " NOT established -- the first operation's tool cannot probe,"
+      + " being tool number 0 or a jet tool, so no absolute Z move is made in that frame anywhere in this job");
   }
```

```diff
   // RepRap-only slots: G59.1-G59.3 (7-9) don't exist on GRBL.
   if (base > 6 && fw != eFirmware.REPRAP) {
     error("Reserved base " + wcsName(base) + " requires RepRap (GRBL supports G54-G59 only).");
     return;
   }

+  // Guard B' -- a fixed Z reference NAMED but not established is the same hazard as none named, and the
+  // dialog cannot tell them apart, so Guard B's own condition (base == 0) reads this job as safe. Below
+  // the slot check deliberately: a base this firmware does not have is the more basic complaint, and
+  // fixing the tool would only surface it next. Its own site rather than a clause on Guard B, because
+  // the remedy is a different one -- the tool, not the dialog. CR-14.
+  if (!fixedZEstablishedInFile() && collectDistinctOffsets().length > 1) {
+    error("\"Fixed Z Reference\" = Spoilboard reserves " + wcsName(base) + ", but the first operation's tool cannot probe it (tool number 0 or a jet tool), so the base is never written and every traverse between parts would move to an absolute height in an unestablished frame. Give the first operation a numbered milling tool, or post one job per part.");
+    return;
+  }
+
   // Guard A -- no redefine of the base.
```

### TEST

**Status:** `pass` — six walks, all against the source at the FIX commit. W14a's stated expectation was
wrong in two places and is corrected below with the reasoning; the row passes on the corrected one. W14f is
new: the row it was split out of could not have shown what it claimed.

| Test | Method | Proves | Property set | State |
|---|---|---|---|---|
| W14a | walk | the skip is visible, and no absolute Z is emitted in the unwritten frame | GRBL/mm, Comment Level `Info`, **one** part on G54, `Fixed Z Reference` = Spoilboard, `Reserved WCS` = G59, `Inter Part Travel Z` = 40, `At End Park At` = machine X0 Y0, `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, first operation's tool number **0** | ✅ |
| W14b | walk | Guard B′ refuses the multi-WCS form rather than traversing into the unwritten base | W14a with a second part on G55 | ✅ |
| W14c | walk | a numbered tool is unaffected — the predicate change is confined to the skip | W14a with tool 1 | ✅ |
| W14d | walk | the machine-Z answer does not consult the tool at all | W14a with `Fixed Z Reference` = Machine Z, `Axes Homed and Trusted` = XYZ, `Home at Job Start` = Home | ✅ |
| W14e | walk | the Marlin exclusion still answers first | W14a on Marlin, tool 1 | ✅ |
| W14f | walk | the false positive at `:1520` stops firing | W14a with `First WCS / Part` = `Set X0 Y0 to Current Pos, Probe Z0` | ✅ |

**W14a — the two corrections first.** The expectation written when this fix was designed said `partProbe()`
would emit its "no Z reference is established" warning. It cannot, and the reason matters: `writeWcsOnStart()`
computes its own `canProbe = (tool.number != 0 && !tool.isJetTool())` and, in the `Probe Z` arm, calls
`partProbe(false, true)` only under it — so with tool 0 the part probe is skipped too, and the warning at
[:3074](../MPCNC_v4.0_Beta2.cps#L3074) is unreachable in this configuration. It is a real consumer of the
honest predicate, but not one this row can exercise; the tool that defeats the base probe defeats the part
probe first. The second correction: the same row claimed `:1520` must **not** fire while also claiming
`:1531` fires, and those two conditions are mutually exclusive start modes. `:1531` is the one this
property set reaches, so the row now names `Probe Z` explicitly, and the `:1520` claim moved to **W14f**
where a start mode that can trigger it is set.

`writeWcsOnStart()`'s local `canProbe` is deliberately left duplicating the predicate rather than folded
into `baseProbeCanRun()`: it asks about the **part** probe of the current section, which happens to be
section 0 here only because this is the first section. Folding them would tie two questions that agree by
coincidence.

**W14a — what the walk found.** `validateJob()`: `fixedZEstablishedInFile()` is now false — not Marlin,
`fixedZEstablishedAtStart()` true on the reserved base, then `usesMachineZDatum() || baseProbeCanRun()`
resolves `false || false`. So [:1531](../MPCNC_v4.0_Beta2.cps#L1531) fires and
[:1547](../MPCNC_v4.0_Beta2.cps#L1547) fires, neither of which did before. Guard B′ is reached — `base` = 6
survives the `base == 0` return and the slot check — and does **not** fire, `collectDistinctOffsets().length`
being 1. The job posts, which is the intent: a single-WCS job with an unprobeable tool is legal, just noisy.

The emitted stream, at Comment Level `Info`, where the establish and the park would have been:

```
( >>> WARNING: reserved base G59 NOT established -- the first operation's tool cannot probe, being tool number 0 or a jet tool, so no absolute Z move is made in that frame anywhere in this job)
(   Use stored work origin X0 Y0; probe Z)
G0 X0 Y0 F<travel XY>
...
( >>> WARNING: no retract before parking at machine X0 Y0 -- this job establishes no fixed Z reference; the tool crosses the bed at whatever Z the last operation left it at)
(   Park at machine X0 Y0)
G53 G0 X0 Y0 F<travel XY>
```

The absence that carries the finding holds: **no `G10 L20 P6` of any kind, and no absolute Z move made while
G59 is selected, anywhere in the file.**

**What this row establishes that the finding did not say.** Before the FIX, this configuration — a **single
part**, one WCS, nothing multi about it — emitted at its park:

```
(   Retract to spoilboard-base clearance G59 before traverse)
G59
G0 Z40 F<travel Z>
G54
(   Park at machine X0 Y0)
G53 G0 X0 Y0 F<travel XY>
```

A rapid to an absolute Z40 in a register no line of the file ever wrote, reached through `parkCanRetract()`.
CR-14 is filed on the job *believing* a base was established; this is that belief moving the machine, and it
does not need the multi-WCS traverse Guard B′ addresses. The single-part case was the more likely one to
meet in practice and had no guard proposed for it — it is fixed by the predicate alone.

One pre-existing infelicity noted and not touched: the Info line `Use stored work origin X0 Y0; probe Z` is
written above the `canProbe` test, so it promises a probe that the tool-0 arm then skips. It predates CR-14
and belongs to `writeWcsOnStart()`, not to this fix.

**W14b.** **No output.** `validateJob()` reaches Guard B′ with `!fixedZEstablishedInFile()` true and
`collectDistinctOffsets().length` = 2, and errors before any block, naming `G59` and the tool. Guard B
itself does not fire — its condition is `base == 0` and a base is reserved — so the two guards are not
crossed. The traverse this refuses would have been `writeWCS()`'s `baseRelative` route: `G59` then
`G0 Z40` on every part change, into the unwritten register.

**W14c.** Byte-identical to CR-11's W11a: `baseProbeCanRun()` returns true, the establish arm is entered
unchanged, and the full block stream — `G59`, `G10 L20 P6 Z0`, `G38.2 F30 Z-100`, `G10 L20 P6 Z0.8`,
`G0 Z40`, `G54` — is emitted as before. `fixedZEstablishedInFile()` is true throughout, so no new warning
appears at `:1520`, `:1531`, `:1547`, in `writeMachineParkXY()` or in the establish. This is the row that
catches the dangerous direction: a predicate reading false too widely would have silently disabled the base
clearance on every job that works today.

**W14d.** `fixedZEstablishedInFile()` is true despite tool 0 — `usesMachineZDatum()` is the left operand of
the `||`, so `baseProbeCanRun()` is never evaluated. Guard B′ is not reached at all: `getReservedBaseWcs()`
returns 0 under the machine-Z answer, so `validateJob()` takes the `base == 0` return above it. The park
retracts with `G53 G0 Z<travel>` as it does today and no new warning appears. The tool test did not leak out
of the spoilboard arm.

**W14e.** Unchanged from today. `fixedZEstablishedInFile()` returns false on the firmware test alone, before
either later line runs. `writeBaseEstablish()` takes its Marlin arm and warns about per-WCS registers, never
reaching `baseProbeCanRun()`. Guard B′ is not reached: Guard C returns from `validateJob()` above it. The
new guard sits below the Marlin exclusion, which is where it has to be — on Marlin the complaint is the
firmware, not the tool.

**W14f.** The warning at [:1520](../MPCNC_v4.0_Beta2.cps#L1520) — *establishing the fixed Z reference moves
the tool before "First WCS / Part" records the current position* — no longer fires. `startMode` is
`Current XY & Probe Z`, which satisfies its second clause, so only the predicate turning false suppresses
it. That is correct and not a lost warning: with tool 0 the establish is skipped, so nothing moves the tool
before the origin is recorded and there is nothing to warn about. Its survival here would have meant the
predicate was still reading the dialog rather than the job.

**What a fail looks like.** A `G10 L20 P6` or an absolute Z under G59 in W14a: the skip is still silent to
its consumers. Output of any kind from W14b: Guard B′ is not reached, or its condition still tests something
the dialog answers. Any new warning in W14c: the predicate reads false too widely. A park warning in W14d:
the tool test escaped the spoilboard arm. `:1520` still firing in W14f: the predicate reads the dialog.
Record it in the status line above and revise the FIX; do not edit the expectation to match what was seen.

---

## CR-04 — the first-move conversion applies no test of any kind to the destination

**Finding:** [`CoverageFindings.md` → CR-04](CoverageFindings.md) — Hobbyist, Machine damage, Certain.

### FIX

**Status:** `withdrawn` — the premise is settled, and against the finding: under Fusion Personal the
opening motion callback of **every** section is a rapid rendered as a feed move, so the conversion this
finding objects to is never applied to a cut. The design below is kept, unapplied.

**Why it is withdrawn.** The deferral asked one question — *under a full licence, is the first motion of
every section a `G0`?* — and it is now answered from the other side, as a property of the Personal edition
rather than of any one job: Fusion Personal **emits no rapids at all**, and a section's first move is the
positioning move Fusion would have made a rapid, arriving at `onLinear()` because that is the only motion
callback Personal uses. The posted file says so in its own header — *"When using Fusion 360 for Personal
Use, the feedrate of rapid moves is reduced to match the feedrate of cutting moves"* — which is the same
fact the post has always assumed at [`:2232`](../MPCNC_v4.0_Beta2.cps#L2232), now stated by the producer.

So the first-move conversion is always converting the move it was written for. The dangerous case the
finding imagines — a section whose opening callback carries a genuine cut — does not occur on the licence
group 3 exists for. It could occur under a **full** licence, where `onLinear()` really does carry cuts;
that is CR-03's ground, and CR-03's latch stops group 3 converting anything at the job's first genuine
`G0`. Two findings do not need one fix between them.

**What is left, and why it is not a defect either.** The converted move is emitted through
[`rapidMovements()`](../MPCNC_v4.0_Beta2.cps#L3245), which picks Z-before-XY from
`_z < getCurrentPosition().z` — a value that knows nothing about the motion the post itself emitted in the
preamble, since the kernel tracks only its own callbacks. At a section's first move current *equals*
destination, so that test compares a number with itself, takes the `else` arm and retracts Z before
traversing XY. That is the safe arm, reached without reasoning. It is nonetheless the right answer in every
case reachable here, on two grounds:

- Every path that moves Z before the first cut leaves it at a height the post **chose and recorded through
  `zOutput`**, so the Z word the conversion emits is measured from a height the file itself established:
  [`probeTool()` :3704](../MPCNC_v4.0_Beta2.cps#L3704) retracts to `probeSafeZ()` after its load-bearing
  `resetAll()`; [`writeMachineTravelZ()` :2095](../MPCNC_v4.0_Beta2.cps#L2095) brackets its `G53` with
  `resetAll()` on both sides; [`retractThroughBaseClearance()` :2168](../MPCNC_v4.0_Beta2.cps#L2168)
  retracts to `interPartTravelZ()` in the base frame; `writeWcsOnStart()`'s `Skip` arm moves to
  `probeSafeZ()`; [`toolChange()` :3615](../MPCNC_v4.0_Beta2.cps#L3615) leaves the tool at `Tool Change Z`.
- The paths that emit **no** motion — `writeWcsOnStart()`'s `Current XYZ`, `Jog XYZ` and tool-0/jet arms —
  leave the tool where the operator put it, and the operator positions the machine safely in Z before the
  program starts. `partProbe()` already warns in the file when its XY traverse runs at an unestablished
  height ([:3076](../MPCNC_v4.0_Beta2.cps#L3076)).

Where the destination Z differs from the recorded height — which is every ordinary case, the first move
being a clearance move above a preamble height — the Z word is emitted first and the XY traverse happens at
the destination clearance. Where it does not differ, no Z word is emitted and the traverse happens at a
height the post just wrote. Neither is a rapid into the part.

**The design is kept below the line.** A withdrawal is only as good as its premise. If a Personal job is
ever seen whose section opens with a genuine cut, this is the fix to reach for, and it needs no
re-derivation — only a decision.

The finding names its own fix — *a destination Z test costs nothing here* — and names the function to use
for it: `isSafeToRapid()`, which already exists. The test is right. The function is the wrong one to ask,
and for the same reason the flag it would be guarding exists at all.

**Why not `isSafeToRapid()`.** Three of its four tests read `getCurrentPosition()`, and a section's first
move is precisely the place where the post has already written down that it does not trust that value.
`onSection()` at [:2232](../MPCNC_v4.0_Beta2.cps#L2232) sets the flag because *"the Personal edition emits a
section's first move as an onLinear rather than a Rapid, leaving current position equal to destination — a
zero-length vector with no direction to read"*, and `limitFeedByXYZComponents()` at
[:3269](../MPCNC_v4.0_Beta2.cps#L3269) carries a special case for the same condition. Both readings of that
claim are bad for `isSafeToRapid()`:

- **Where it holds** — current equals destination — `zConstant` is true, so `isSafeToRapid()` collapses to
  exactly `zr >= safeZHeight`: the destination test, reached through three comparisons that read one number
  against itself. The right answer, arrived at by pretending to ask something.
- **Where it does not** — the Full-licence case the finding names, a section whose first *emitted* move is a
  cut, so the current position is wherever the last section ended — the `xyConstant` clauses reject any move
  that changes X and Y. That rejects the **intended** case: a positioning move to the next start point
  changes X and Y by definition. The group's whole reason for existing would stop working.

Which of the two is true at a given callback is host behaviour, and a walk cannot settle it. A fix that is
correct either way is available, so take it: split the destination test out and ask only that.

**One test, two callers.** `destinationZIsSafe(z)` is the `zr >= safeZHeight` line lifted out of
`isSafeToRapid()` with its rounding, and `isSafeToRapid()` then calls it instead of computing it inline.
Not a tidy-up: a `>=` decided in the third decimal is exactly where two separately-written copies of a test
drift apart, and the first-move site and the ordinary site have to agree about the boundary or the same
destination Z converts on one path and not the other. It keeps the comparison exactly as it is today —
a **rounded destination against an unrounded threshold** — because changing that is a different question
from this one, and silently changing it inside a machine-damage fix is how a fix acquires a second effect
nobody reviewed.

**The declined move.** It goes to `linearMovements()`, the arm it would have reached had the flag never been
set, and gets an `Important` comment saying the conversion was declined. Not a `writeWarning()`: nothing
hazardous happened. The hazard was the *conversion*; declining it is the post doing its job. A warning would
fire once per section on any strategy that legitimately opens at depth, and would be warning about a correct
outcome — which is how operators learn to ignore warnings.

**The flag is spent on the first move either way.** It is cleared before the test, not inside the converting
arm. The flag means *no rapid has opened this section yet*, and once a motion callback has consumed it that
is no longer true however the move was emitted. Leaving it set so a later move could pick it up would take
the defect from "the first move is converted untested" to "an arbitrary later move is converted untested",
which is worse: a mid-section cut has no claim to be a positioning move at all.

**One line of documentation.** The group-3 property description says the conversion *"covers … the first
move of every operation"*, without qualification — the description is the only place the unconditional
behaviour is written down, and after this it is no longer true. It becomes "when it ends at or above the
Safe Z", matching how the same sentence already qualifies the other two moves it lists. This de-syncs
`property-reference.md`, which `node docs/doc-sync.js` already reports as behind; the guide is refreshed on
its own occasion, not here.

**What this does not do.** It tests the destination and nothing else, so a first move that *ends* at or
above Safe Z while *starting* in material would still convert. Fusion retracts at section end, so the tool
is in air when a section opens; and this is the same blind spot every other conversion in the group has —
`isSafeToRapid()`'s `zUp && xyConstant` arm makes exactly the same bet. Widening it is CR-03's and CR-23's
ground, not this finding's. It also inherits CR-23 whole: with a Safe Z expression of `0`, every
non-negative Z reads as safe air, and this test will read it that way too.

An undefined `safeZHeight` compares `false` and declines the conversion — the safe direction, and belt and
braces rather than a live path: `safeZforSection()` assigns on every arm, but only under the same property
this arm is gated on.

**Diffs, not yet applied.**

*The shared test, between `roundTo()` and `isSafeToRapid()` ([:1183](../MPCNC_v4.0_Beta2.cps#L1183)):*

```js
// Is this destination Z in the safe zone? The destination half of isSafeToRapid()'s test, split out so the
// first-move conversion can ask it WITHOUT the current-position half -- at a Section's first move there is
// no current position worth asking about, which is the very reason forceSectionToStartWithRapid exists.
// Both callers round the same way, so they cannot disagree about the boundary. CR-04.
function destinationZIsSafe(z) {
  return roundTo(z, (unit == MM ? 3 : 4)) >= safeZHeight;
}
```

*`isSafeToRapid()` ([:1194](../MPCNC_v4.0_Beta2.cps#L1194)) — the same test, now shared. `zr` stays: the
constant-axis tests below still need it:*

```diff
-    let zSafe = (zr >= safeZHeight);
+    let zSafe = destinationZIsSafe(z);
```

*`onLinear()` ([:2386](../MPCNC_v4.0_Beta2.cps#L2386)):*

```diff
   if (getProperty(properties.mapRapidsRestoreRapids) && (forceSectionToStartWithRapid == true)) {
-    writeComment(eComment.Important, " First G1 --> G0");
-
-    forceSectionToStartWithRapid = false;
-    onRapid(x, y, z);
+    // Spent on this move however it is emitted -- a later move is not the one the flag was set for, and
+    // converting THAT one untested would be worse than not converting this one. CR-04.
+    forceSectionToStartWithRapid = false;
+
+    // The flag says only that no Rapid has opened this Section, not that this move is a positioning move.
+    // A section whose first motion is a cut arrives here too, and G0 runs it at $110-$112 with no
+    // feedrate at all. So ask the one test the current position cannot spoil. CR-04.
+    if (destinationZIsSafe(z)) {
+      writeComment(eComment.Important, " First G1 --> G0");
+      onRapid(x, y, z);
+    }
+    else {
+      writeComment(eComment.Important, " First G1 kept: destination below Safe Z");
+      linearMovements(x, y, z, feed);
+    }
   }
   else if (isSafeToRapid(x, y, z)) {
```

*The property description ([:276](../MPCNC_v4.0_Beta2.cps#L276)):*

```diff
-    description: "... vertical retracts and descents that stay above it, and the first move of every operation.",
+    description: "... vertical retracts and descents that stay above it, and the first move of every operation when it ends at or above the Safe Z.",
```

### TEST

**Status:** `n/a` — the FIX is withdrawn, so there is nothing to walk. The rows are kept with the design:
they are the expectations that would have to be met if the premise above were ever contradicted.

Walks, not posted files. The claim is an absence — *no `G0` is emitted for a first move below Safe Z* — and
absence from the source is absence from every configuration, where absence from one posted file is not. All
rows are GRBL, `Map G1s -> G0 Rapids` **on** except where the row says otherwise, `Comment Level` `Info`,
and enter at `onLinear` with `onSection()` already run, so `safeZHeight` is resolved.

| Test | Method | Proves | Property set | State |
|---|---|---|---|---|
| W04a | walk | a first move that cuts is no longer re-emitted as a rapid | mm, `Safe Z to Rapid` = `Retract:15` on an operation with no Fusion retract level, so `safeZHeight` = 15; first `onLinear` to Z −1.0 with XY moving | open |
| W04b | walk | the intended case is untouched, at the boundary | W04a, first `onLinear` to Z 15.0 | open |
| W04c | walk | the property off is byte-identical, and never reaches the new test | W04a with `Map G1s -> G0 Rapids` **off** | open |
| W04d | walk | the boundary is decided the same way in the other unit | W04a in inches, `Safe Z to Rapid` = `15`; first `onLinear` to Z 0.5906 and, separately, 0.5905 | open |
| W04e | walk | first-ness is spent by a declined move | W04a, then a second `onLinear` in the same section to Z 20.0 with XY moving | open |
| W04f | walk | the ordinary conversion path is unchanged by the shared test | W04a, flag already clear, a horizontal `onLinear` at Z 20.0 with Z constant | open |

**What each row must show.** W04a: no ` First G1 --> G0`, no `G0` of any kind, and the move emitted as
`G1 X… Y… Z-1 F<feed>` under ` First G1 kept: destination below Safe Z` — with `rapidMovements()` never
entered, so its Z-ordering never gets the chance the finding says it would fail. W04b: the stream is what
the post emits today, `( First G1 --> G0)` then a `G0`, since `15 >= 15`. W04c: neither
`destinationZIsSafe()` nor `isSafeToRapid()` is reached past its property gate, and `safeZHeight` being
`undefined` never matters. W04d: 0.5906 converts and 0.5905 does not, against
`safeZHeight = propertyMmToUnit(15) = 0.5905511…` — which is the comparison the post makes today, a rounded
destination against an unrounded threshold, and it must still make it. W04e: the second move carries no
first-move comment; it reaches `isSafeToRapid()`, which returns false on `xyConstant`, and stays a `G1`.
W04f: `isSafeToRapid()` returns true through `zConstant` exactly as before the split.

**What a fail looks like.** A `G0` in W04a: the conversion is still untested. Any change to W04b's or
W04f's stream: the test reads false too widely and the recovery this group exists for has been disabled —
the dangerous direction, since the operator who turned the property on gets slow cuts instead of rapids and
nothing says why. A first-move comment in W04e: the flag outlived the move it was set for. A `G0` at Z
0.5905 in W04d: the two callers do not round alike. Record it in the status line above and revise the FIX;
do not edit the expectation to match what was seen.

---

## CR-03 — group 3 is not gated to the licence it exists for, and nothing warns

**Finding:** [`CoverageFindings.md` → CR-03](CoverageFindings.md) — Hobbyist, Machine damage, Certain.

### FIX

**Status:** `deferred` — testing the header text for the hobby version may be the better solution. What is
in doubt is the **instrument**, not the finding: the finding stands and the design below is complete, but
the licence may be readable at post time rather than inferred from the first rapid.

**Why it is deferred, and what would settle it.** Fusion states the licence in the file it posts — *"When
using Fusion 360 for Personal Use, the feedrate of rapid moves is reduced to match the feedrate of cutting
moves"* — and the design below cites that banner as evidence the premise is a guarantee while still reading
the licence indirectly, from the first `onRapid()`. If the same text is readable *by the post*, the test
belongs in `validateJob()` or `onOpen()` and this whole design collapses to a condition asked once, before
any motion. That would be better on three counts: it closes the one-move window this fix leaves open (a
full-licence job whose opening callback is an `onLinear` still converts that move untested); it needs no
latch, no `rapidRecoveryEnabled()` and no substitution at three call sites; and it can warn in the dialog
rather than partway down the file, where the operator can still act on it.

The question is **does the banner reach the post, or does Fusion write it into the output outside the
post's sight?** Nothing in `MPCNC_v4.0_Beta2.cps` emits that text, so it is one or the other. It is
answerable without a licence the operator no longer holds ([`HReview.md` → HB-20](../docs/HReview.md)) and
without a machine: `onParameter()` at [:2489](../MPCNC_v4.0_Beta2.cps#L2489) already has a catch-all arm
that writes ` param: <name> = <value>` at Debug for every parameter it does not recognise, so a Personal
post taken at `Comment Level` = `Debug` shows the banner among those lines if it arrives as a parameter at
all. Failing a Debug post, an existing Personal file answers it weakly but usefully: a banner sitting in a
block the post never wrote is Fusion injecting it downstream, and there is nothing for the post to read.

If the answer is *no*, this design is the only instrument available and is applied as written. If it is
*yes*, the finding is refixed at post time and what survives from below is the documentation edits and,
possibly, nothing else.

Everything below is the design as it stood when it was written, kept whole so that answering the question
is the only work a return to this finding needs.

The finding offers two remedies — *either the group should be inert when real rapids are seen, or the
combination should warn*. Take both, from one observation, because each alone is half a fix: inert and
silent removes the hazard and leaves the operator wondering why the recovery they turned on did nothing,
and warning without going inert tells the operator about a machine-damage path while still emitting it.

**The post already knows the licence, and knows it from evidence rather than from the dialog.** Fusion
Personal emits **no rapids at all**: every rapid is reduced to a feed move, so `onRapid` is never called and
those moves arrive at `onLinear` — including the move that opens each section. Fusion states it in the
header of every file it posts under that licence — *"When using Fusion 360 for Personal Use, the feedrate of
rapid moves is reduced to match the feedrate of cutting moves"* — and it is the review's own recorded fact
([`CoverageReview.md` → The licence dimension](CoverageReview.md),
[`CoverageReviewPlan.md`](CoverageReviewPlan.md)) and the fact the post cites in `onSection()` at
[:2232](../MPCNC_v4.0_Beta2.cps#L2232) when it sets `forceSectionToStartWithRapid`.

So this is a guarantee and not an inference: **one genuine `onRapid` says the licence is Full**, and on a
Full licence group 3's premise is false for the whole job — there are no rapids to restore, and every
conversion it makes can only *add* a rapid Fusion deliberately did not make. Nothing needs to be asked of
the host, and nothing needs to be added to the dialog. The tell arrives on its own, in a callback the post
already implements.

**`onRapid()` cannot be that tell as the code stands, and the reason is not only `onLinear()`.** The
callback has **three** callers inside the post, and every one of them would poison the latch:

| Caller | What it is | What a latch there would do |
|---|---|---|
| [`onLinear()` :2390](../MPCNC_v4.0_Beta2.cps#L2390) | the first-move conversion | trips on the group's own first conversion |
| [`onLinear()` :2395](../MPCNC_v4.0_Beta2.cps#L2395) | the `isSafeToRapid()` conversion | trips on the group's own first conversion |
| [`toolChange()` :3615](../MPCNC_v4.0_Beta2.cps#L3615) | the relocation move to `Tool Change X/Y/Z` | trips **before any motion callback at all** on a `Do First Change` job |

The third is the worst of them and is easy to miss, because it does not look like motion: `onSection()`
calls `toolChange()` at [:2263](../MPCNC_v4.0_Beta2.cps#L2263), so on a Personal job with
`Tool Changes are Included` + `Include Relocation Code` + `Do First Change`, the post calls the kernel's own
rapid callback before Fusion has sent a single move. A latch placed naively in `onRapid()` would therefore
turn group 3 off for the entire file, and print a warning telling a Personal operator they are running a
full licence — strictly worse than the finding it was meant to fix.

So the rule comes first, and it is one line: **`onRapid()` is the kernel's entry point and nothing else's;
every rapid the post originates goes to `rapidMovements()`.** `onRapid()`'s entire body is
`forceSectionToStartWithRapid = false;` followed by `rapidMovements(x, y, z)`, so all three callers can say
what they mean directly. After the substitution the callback carries exactly one meaning: *Fusion asked for
a rapid.*

That substitution is behaviour-preserving in `onLinear()` by inspection, not by intention: arm 1 already
cleared the flag itself, and arm 2 can only run with the flag already false — if the flag were true with the
property on, arm 1 took the move, and with the property off `isSafeToRapid()` returns false at its own gate.
The assignment is written into arm 2 anyway rather than argued away, so the substitution is literal and no
walk has to carry the argument. In `toolChange()` it is **not** behaviour-preserving, which is the next
section.

**A side effect that is the point.** `onRapid()` also clears `forceSectionToStartWithRapid`, and that is the
whole reason the first-move conversion silently never runs on a tool-change section — recorded in
[`CoverageReview.md` → A4](CoverageReview.md) as *"one interaction worth recording because it silently
disables a group-3 feature"*: the property is on, and for that section it does nothing. Routing the
relocation through `rapidMovements()` removes the clearing, so the conversion starts working there. That is
a real behaviour change and it is named here rather than left to be discovered, because it arrives as a
by-product of a fix aimed at something else.

It is the right change, and it is safe. The section's first move is converted from a height the post itself
established and wrote through `zOutput` a few blocks earlier — `Tool Change Z` after a bare relocation, or
`probeSafeZ()` after the re-probe, since [`probeTool()` :3704](../MPCNC_v4.0_Beta2.cps#L3704) retracts
before it returns. The destination differs from that height in the ordinary case, so `rapidMovements()`
emits its `Z` word first and the XY traverse happens at the destination clearance; where it does not differ,
the traverse happens at the height just written. Neither crosses the work low. What the operator gets back
is the recovery they turned on, on the sections that currently lose it.

**One gate, two conversion sites.** `rapidRecoveryEnabled()` is `the property AND no genuine rapid seen`,
and it replaces the bare property read in `onLinear()`'s first arm and the one at the top of
`isSafeToRapid()`. Same reason as CR-04's shared destination test: two sites that must agree about whether
this job is still being converted should not each hold their own copy of the answer. It is one-directional
— evidence can turn the group off for the rest of a file and nothing turns it back on, because nothing
later in the file can un-see a `G0`.

**The warning fires where the evidence appears.** In `onRapid()`, once, on the transition, and only when
the property is on: a job that left group 3 off is correctly configured and gets nothing. It cannot go in
`validateJob()` — that runs from `onOpen()`, before any motion callback, so the evidence does not exist
yet, and this is the one guard in the post whose condition genuinely cannot be known at post time. It is
not an `error()` either: a Full-licence job with the property on is legal output, merely output the
operator did not mean to ask for, and the post's job is to stop converting and say so, not to refuse.

The text names what was already emitted rather than claiming nothing was. Under a Full licence the first
motion of a job is normally the opening rapid, so the latch trips before any conversion — but *normally* is
an assumption about the CAM, and the post cannot make it on the operator's behalf in a warning. So the
warning points at the conversion comments above it instead of promising there are none.

**A title acquires a constraint.** `properties.mapRapidsRestoreRapids.title` is now printed into a
`writeWarning()`, so it inherits the no-parentheses rule that `mapRapidsSafeZ` already carries at
[:283](../MPCNC_v4.0_Beta2.cps#L283) — `writeCommentLine()` hands the text to `sanitizeMessageText(_, "()")`,
which blanks every parenthesis run because a grbl comment cannot nest. The note goes on the property, where
the next person to edit the title will read it, not on the call site.

**Two lines of documentation.** The group title already says *disable when using full license* and the
description already says *the F360 Personal edition* — the behaviour was documented and simply not
enforced. Both now say the post enforces it, which is a different promise from asking the operator to.

**What this does not do.** It does not protect the moves *before* the first genuine rapid. A Full-licence
job whose opening motion callback is an `onLinear` has that one move converted with no evidence yet in hand.
The window is one move wide and it takes an unusual job to reach — Fusion has to link into the first section
without a rapid, from a position it did not itself put the tool at — and no test the post can run
distinguishes that move from the Personal move it is written for. Nor does the fix help a Full-licence job
containing no rapid at all; there is no evidence in that job to read, and no walk can distinguish it from a
Personal one. It does not change the dialog: the property stays where the operator set it, and the next post
of a genuinely Personal job converts again.

**Which direction it fails in.** The latch can only be wrong by going inert on a job that wanted the
recovery, which needs Fusion Personal to call `onRapid` — against Fusion's own statement of what the
Personal licence does, against the review's finding, and against the comment at `:2232`. Even then the cost
is the un-recovered Personal stream: slow, and safe. The failure the fix removes is a genuine cut re-emitted
as `G0` at `$110`–`$112`. The two directions are not comparable, and the latch is placed so the cheap one is
the one that can happen.

**Diffs, not yet applied.**

*The latch, beside the flag it complements ([:1832](../MPCNC_v4.0_Beta2.cps#L1832)):*

```diff
 var forceSectionToStartWithRapid = false;
+
+// Set by the one caller of onRapid() that is not this post: Fusion. The Personal edition emits NO rapids --
+// every one is reduced to a feed move and arrives at onLinear, which is the whole premise of group 3 -- so a
+// single genuine onRapid says the licence is Full and that premise is false for this job. This is why every
+// rapid the post ORIGINATES calls rapidMovements() and not onRapid(). One-directional: nothing later in a
+// file can un-see a G0. CR-03.
+var sawGenuineRapid = false;
 var sectionComment;
```

*`resetPostState()` ([:1718](../MPCNC_v4.0_Beta2.cps#L1718)) — a second output file sharing one JavaScript
context must not inherit the previous file's licence evidence:*

```diff
   forceSectionToStartWithRapid = false;
+  sawGenuineRapid = false;
```

*The shared gate, above `isSafeToRapid()` ([:1184](../MPCNC_v4.0_Beta2.cps#L1184)):*

```js
// May the post still convert a G1 to a G0 in this job? The property says the operator asked for the
// recovery; the latch says the job has not since proved it does not need it. Both conversion sites ask
// HERE, so they cannot disagree about a job the post has already stopped converting. CR-03.
function rapidRecoveryEnabled() {
  return getProperty(properties.mapRapidsRestoreRapids) && !sawGenuineRapid;
}
```

*`isSafeToRapid()`'s gate ([:1186](../MPCNC_v4.0_Beta2.cps#L1186)):*

```diff
 function isSafeToRapid(x, y, z) {
-  if (getProperty(properties.mapRapidsRestoreRapids)) {
+  if (rapidRecoveryEnabled()) {
```

*`onRapid()` ([:2376](../MPCNC_v4.0_Beta2.cps#L2376)) — the tell, and the one warning:*

```diff
 function onRapid(x, y, z) {
+  // Fusion called this, not the post: onLinear's conversions go straight to rapidMovements(). A real rapid
+  // means a full licence, where group 3 can only ADD rapids Fusion deliberately did not make. Say so once
+  // and stop converting for the rest of the file. CR-03.
+  if (!sawGenuineRapid) {
+    sawGenuineRapid = true;
+
+    if (getProperty(properties.mapRapidsRestoreRapids)) {
+      writeWarning("this job emits real rapids, so it is not a Fusion Personal job -- \""
+        + properties.mapRapidsRestoreRapids.title + "\" is a Personal-edition recovery and is now OFF for the"
+        + " rest of this file. Turn it off in the post dialog and re-post. Any G1 --> G0 comment ABOVE this"
+        + " line converted a move Fusion meant to cut.");
+    }
+  }
+
   forceSectionToStartWithRapid = false;
 
   rapidMovements(x, y, z);
 }
```

*`onLinear()` ([:2386](../MPCNC_v4.0_Beta2.cps#L2386)) — the gate, and the substitution that keeps
`onRapid()` the kernel's alone:*

```diff
-  if (getProperty(properties.mapRapidsRestoreRapids) && (forceSectionToStartWithRapid == true)) {
+  if (rapidRecoveryEnabled() && (forceSectionToStartWithRapid == true)) {
     writeComment(eComment.Important, " First G1 --> G0");
 
     forceSectionToStartWithRapid = false;
-    onRapid(x, y, z);
+    // NOT onRapid(): that callback is the licence tell now, and a conversion arriving there would latch on
+    // the post's own traffic and disable the group on the licence it exists for. CR-03.
+    rapidMovements(x, y, z);
   }
   else if (isSafeToRapid(x, y, z)) {
     writeComment(eComment.Important, " Safe G1 --> G0");
 
-    onRapid(x, y, z);
+    // Already false whenever this arm is reached -- written out anyway so the substitution above is
+    // literal rather than argued. CR-03.
+    forceSectionToStartWithRapid = false;
+    rapidMovements(x, y, z);
   }
```

*`toolChange()` ([:3615](../MPCNC_v4.0_Beta2.cps#L3615)) — the third caller, and the one that would trip the
latch before Fusion has sent a move:*

```diff
     flushMotions();
-    onRapid(propertyMmToUnit(getProperty(properties.toolChangeX)), propertyMmToUnit(getProperty(properties.toolChangeY)), propertyMmToUnit(getProperty(properties.toolChangeZ)));
+    // NOT onRapid(): that callback is the licence tell now, and this is the post's OWN relocation move. On a
+    // "Do First Change" job it runs from onSection() BEFORE any motion callback, so routing it through the
+    // kernel's entry would disable group 3 on a Personal job at move zero. Dropping the callback also stops
+    // this move clearing forceSectionToStartWithRapid, which is what silently disabled the first-move
+    // conversion on every tool-change section. CR-03.
+    rapidMovements(propertyMmToUnit(getProperty(properties.toolChangeX)), propertyMmToUnit(getProperty(properties.toolChangeY)), propertyMmToUnit(getProperty(properties.toolChangeZ)));
     flushMotions();
```

*The group title ([:110](../MPCNC_v4.0_Beta2.cps#L110)) — it asked the operator to do what the post now does:*

```diff
-groupDefinitions.mapRapids  = {title: "3 - Map G1s to Rapids - disable when using full license", order: 120};
+groupDefinitions.mapRapids  = {title: "3 - Map G1s to Rapids - Fusion Personal only, ignored on a full license", order: 120};
```

*The property ([:274](../MPCNC_v4.0_Beta2.cps#L274)) — the new comment, and one sentence on the description:*

```diff
+  // NO PARENTHESES IN THIS TITLE. onRapid() prints it into an in-file warning, whose text goes through
+  // sanitizeMessageText(_, "()") -- see writeWarning(). Same constraint mapRapidsSafeZ carries below.
   mapRapidsRestoreRapids: {
     title      : "Map G1s -> G0 Rapids",
-    description: "... and the first move of every operation.",
+    description: "... and the first move of every operation. Ignored on a full license: the first real G0 in the job switches the mapping off for the rest of the file and writes a warning there, since a full license has no cuts-that-were-rapids to restore.",
```

**Where this meets CR-04.** **CR-04 is withdrawn**, and by the same premise that makes this fix a
guarantee: under Personal every section's opening callback is a would-be rapid, so the first-move conversion
never meets a cut, and under Full the latch above stops group 3 at the first genuine `G0`. The two findings
therefore do not compose and this one lands alone — its `onLinear()` arm is the plain substitution shown
above, and the property description carries only CR-03's sentence. Should CR-04 ever be revived, its design
is intact under its own heading and the only collision is that arm and that description.

The description edit de-syncs `property-reference.md`, which `node docs/doc-sync.js` already reports as
behind; the guide is refreshed on its own occasion, not here.

### TEST

**Status:** `open` — written, and not run: the FIX is deferred, and walking a fix nobody has decided to
apply would prove only that the walk works. W03g is the row to run first if it is applied — it is the one
the design failed before the third caller of `onRapid()` was found.

Walks, not posted files — and here there is no alternative: exercising either licence needs a seat the
operator does not have, and the Personal rows could not be posted at all
([`HReview.md` → HB-20](../docs/HReview.md) records the same refusal, and the offer to stub the `G0` input
being declined). A walk answers for both licences from one source, by fixing which callback Fusion calls.
All rows are GRBL/mm, `Comment Level` `Info`, `Safe Z to Rapid` = `Retract:15` on an operation with no
Fusion retract level, so `safeZHeight` = 15.

| Test | Method | Proves | Callback sequence | State |
|---|---|---|---|---|
| W03a | walk | a full-licence job goes inert and says so | `Map G1s -> G0 Rapids` **on**; section 1: `onRapid` to X10 Y10 Z20, `onRapid` to Z2, then `onLinear` to X50 Y10 Z20 with Z constant | open |
| W03b | walk | the Personal job is untouched — no warning, every conversion as today | on; no `onRapid` ever: first `onLinear` to X10 Y10 Z20, then `onLinear` to X50 Y10 Z20 | open |
| W03c | walk | a correctly configured full-licence job is not nagged | W03a with `Map G1s -> G0 Rapids` **off** | open |
| W03d | walk | the warning fires once per file, not once per rapid | W03a continued: a second `onRapid`, then a second section with its own `onRapid` | open |
| W03e | walk | a converted move does not latch — the group cannot disable itself | W03b, at the `Safe G1 --> G0` move: follow the call into `rapidMovements()` and check `sawGenuineRapid` | open |
| W03f | walk | the latch does not outlive the file | `resetPostState()` from `onOpen()` with `sawGenuineRapid` true on entry | open |
| W03g | walk | the post's own relocation rapid does not read as Fusion's — the row this fix failed before the third caller was found | W03b plus `Tool Changes are Included` **on**, `Include Relocation Code` **on**, `Do First Change` **on**, `Probe After Tool Change` off, tool 1: enter at `onSection()` and follow `toolChange()` to the relocation, then the section's first `onLinear` | open |

**What each row must show.** W03a: the first `onRapid` writes exactly one
`( >>> WARNING: this job emits real rapids ...)` line, with no parenthesis inside it after
`sanitizeMessageText`, and sets the latch; the `onLinear` that follows reaches `isSafeToRapid()`, which now
returns false at `rapidRecoveryEnabled()` before reading `safeZHeight` at all, so the move is emitted as
`G1 X50 Y10 F<feed>` — no ` Safe G1 --> G0` comment and no `G0`. W03b: byte-identical to story A2 in
[`CoverageReview.md`](CoverageReview.md) — ` First G1 --> G0` then ` Safe G1 --> G0`, both `G0`, and no
warning line anywhere. W03c: the latch sets but the property gate suppresses the warning, and no output of
any kind differs from today. W03d: exactly one warning in the file; the second and third `onRapid` take the
`sawGenuineRapid` short-circuit, and the second section's `onSection()` does not clear it. W03e: the
conversion reaches `rapidMovements()` without passing through `onRapid()`, so `sawGenuineRapid` is still
false afterwards and the *next* `onLinear` still converts. W03f: `sawGenuineRapid` is false on return, so a
Personal job posted after a full-licence one in the same context converts normally. W03g: the relocation
emits the same `G0` blocks it does today at the same travel feeds, `sawGenuineRapid` is still false when
`toolChange()` returns, no warning is written — and `forceSectionToStartWithRapid` is still **true**, so the
section's first `onLinear` is converted under ` First G1 --> G0`, which the post does **not** do today.

That last clause is a deliberate difference from the shipped post, not a walk failure. The row is
`CoverageReview.md`'s A4 interaction fixed as a by-product; see *A side effect that is the point* above.

**What a fail looks like.** Any difference in W03b's or W03e's stream — the recovery has been disabled for
the licence it exists for, which is the dangerous direction here: the hobbyist gets the slow un-recovered
stream with a warning that blames a licence they do not hold. A `G0` in W03a: the latch is not reaching one
of the two conversion sites. Two warnings in W03d: the transition test is not a transition test. A warning
in W03c: the post is nagging a job that is set up correctly. `sawGenuineRapid` true after W03e or W03g: the
substitution was not made at that site, and the group turns itself off on the post's own traffic — in W03g's
case before Fusion has sent a single move. Record it in the status line above and revise the FIX; do not
edit the expectation to match what was seen.

---

## CR-12 — both `Use Active WCS …, Probe Z0` modes measure the probe target from the Z0 they distrust

**Finding:** [`CoverageFindings.md` → CR-12](CoverageFindings.md) — Professional, Machine damage, Certain.

### FIX

**Status:** `[x] applied` — commit `CR-12: Give both stored-Z0 part probes a provisional zero of their own`.
Named by subject rather than sha, for the reason CR-11's entry gives. Designed one commit earlier, and the
design was a reconsideration of the finding after CR-11 shipped, which changed what this entry has to say in
three ways: it supplies the mechanism, it inverts the answer to the reach question, and its method turns up a
third path with the same defect that no finding names.

**CR-11 already built the mechanism, so this fix invents nothing.** `probeTool()` takes a `searchZ` third
argument that defaults to `G38 Target` ([:3663](../MPCNC_v4.0_Beta2.cps#L3663)), and a Z-only provisional
origin write immediately before a probe is now the post's settled idiom, in
[`writeBaseEstablish()` :3017](../MPCNC_v4.0_Beta2.cps#L3017) and in
[`writeWcsOnStart()`'s `Current XY & Probe Z` arm :3155](../MPCNC_v4.0_Beta2.cps#L3155). CR-12 needs no new
signature, no new constant and no new control — only the same write, on the paths that still lack it, and
`G38 Target` then means on those paths exactly what its description already claims it means everywhere.

**One write, in `partProbe()`, keyed on the flag that is already there.** Both modes reach the probe through
`partProbe()`, which already takes a second argument saying that the active frame's Z0 is stale — passed
`true` by the first-part path and, wrongly, not by the subsequent-part path, which is the same mode on a
later part. Renaming it `zUntrusted` and letting it carry the write puts the fix in one place, and the
rename is the substantive half: the flag was read as *"the traverse height is unknown"*, which is a
different question and stays asked separately, one clause further down, against
`fixedZEstablishedInFile()`.

```diff
 // A part probe: position to the part's Z-probe touch-point (its WCS origin plus the probe XY offset)
 // and probe Z into the active WCS. `atOrigin` means the tool already sits on the origin, so the
 // reposition is emitted only when the offset is non-zero; added parts pass false, being over the
-// previous part. `zUnknown` means the caller emitted no absolute Z before this probe because the active
-// frame's Z0 is stale, so the traverse runs at whatever height the tool already holds -- only the
-// first-part "Probe Z" mode passes it. Callers guard tool 0 / jet tools, and the base probe does not
-// use this at all: it always touches off at the origin, with its own pause setting.
-function partProbe(atOrigin, zUnknown) {
+// previous part. `zUntrusted` means this WCS's stored Z0 is not believed -- the two "Use Active WCS
+// X0 Y0, Probe Z0" modes, which exist for exactly that reason -- so the probe writes its own
+// provisional Z0 below and no absolute Z was emitted in this frame before it. Whether the traverse
+// HEIGHT is also unknown is a SECOND question, asked separately: on the subsequent-part path the tool
+// holds a height this post just wrote. Callers guard tool 0 / jet tools, and the base probe does not
+// use this at all: it always touches off at the origin, with its own pause setting.
+function partProbe(atOrigin, zUntrusted) {
```

```diff
     // The rapid below is at an unknown height, so the file must say so. A WARNING and not an Info
     // comment: it reports a precondition the operator must satisfy, and Info is gone at Level = Off.
-    if (zUnknown && !fixedZEstablishedInFile()) {
+    if (zUntrusted && !fixedZEstablishedInFile()) {
       writeWarning("no Z reference is established, so the XY move below runs at whatever height the"
         + " tool is holding -- it must be clear of the stock, clamps and fixtures before the program"
-        + " starts. The G38.2 target that follows is measured from the Z0 already stored in this WCS,"
-        + " which is the value this mode re-probes because it is not trusted.");
+        + " starts -- and the G38.2 that follows searches G38 Target DOWN FROM THAT HEIGHT, so the"
+        + " target has to be deep enough to reach the stock from wherever you leave the tool.");
     }
```

```diff
     rapidMovementsXY(ox, oy);
     flushMotions();
   }
+
+  // Z0 written PROVISIONALLY, overwritten by the probe below, so "G38 Target" is a DISTANCE to search
+  // and not a position measured from the very Z0 this mode was chosen BECAUSE it distrusts. Z ONLY --
+  // the stored X0 Y0 is the other half of what these modes are for and is not this probe's to touch.
+  // After the traverse rather than before it: the traverse is X/Y only, so the height is identical
+  // either way, and here the write sits against the probe it bounds. Nothing reads the tracked Z
+  // between this frame shift and probeTool()'s load-bearing resetAll(), so no reset is needed here --
+  // the same reason writeBaseEstablish() needs none. CR-12.
+  if (zUntrusted) {
+    writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
+    writeWcsOrigin(currentWorkOffset, undefined, undefined, 0);
+  }
+
   // Attach(before)/detach(after) prompts per probePause: No=neither, Before=attach only,
```

```diff
   } else if (onChangeMode == "Probe Z") {
     // Replicate: auto-position to the stored X0 Y0 (plus probe XY offset) and probe Z. The tool is
     // still over the PREVIOUS part, so partProbe() travels there first -- X/Y only, Z stays safe.
+    // zUntrusted: this part's stored Z0 is the value this mode exists to re-probe, so the probe writes
+    // a provisional Z0 at the travel height and searches DOWN from there. CR-12.
     if (canProbe) {
-      partProbe(false);
+      partProbe(false, true);
     } else {
```

**A third path with the same defect, and no finding names it.** CR-12 says "both `Use Active WCS …, Probe
Z0` modes". Enumerating every part probe the way CR-03's fix had to enumerate every caller of `onRapid()`
turns up a fourth probe with the identical defect:
[`writeWCS()`'s `Jog XY & Probe Z` arm :1944](../MPCNC_v4.0_Beta2.cps#L1944) writes
`writeWcsOrigin(currentWorkOffset, 0, 0, undefined)` — X0 Y0 at the jogged position, **and no Z** — and then
probes. Its first-part twin at [:3155](../MPCNC_v4.0_Beta2.cps#L3155) writes `0, 0, 0`, the Z of which is
that arm's provisional value, with the comment saying so. The two arms are the same mode on a different
part, and one of them has always written the provisional Z0 and the other never has. Nothing about the
subsequent-part case justifies the difference; the operator has just jogged the tool to the origin, which
is the strongest possible ground for a provisional write, and it is exactly the ground the first-part twin
cites. This is a plain omission, and the fix is a one-word change with a guard around it:

```diff
     writeComment(eComment.Info, "   Set current X,Y position to 0,0");
-    writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
     if (canProbe) {
+      // Z0 PROVISIONAL and overwritten by the probe below, exactly as the first-part twin in
+      // writeWcsOnStart() has always written it. This arm wrote no Z at all, so "G38 Target" was
+      // measured from the stored Z0 -- CR-12's defect on a path CR-12 does not name. INSIDE the
+      // canProbe guard, because on a tool that cannot probe nothing would overwrite the provisional
+      // value and the mode would silently become "Jog to X0 Y0 Z0". CR-12.
+      writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
+      writeWcsOrigin(currentWorkOffset, 0, 0, 0);
       partProbe(true);
     } else {
+      writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
       writeComment(eComment.Debug, " writeWCS: probe skipped (tool 0 or jet tool)");
     }
```

The `undefined` write moves into the `else` arm rather than disappearing: that arm still has to record the
jogged X0 Y0, and it is the Z it must leave alone. *(An earlier draft of this entry claimed the Debug trace
on that line named the wrong function. It does not — it reads `writeWCS:`, as the sibling arm above it does.
The claim was a misreading and no diff carries it.)*

**CR-11's other lesson applies here, and its answer comes out the other way.** CR-11 recorded that making a
target relative decides *where the search starts* and leaves *how far it goes* unanswered, and that
answering only the first turns an unbounded plunge into a job that reliably refuses to start. That is
exactly what would happen here, and CR-11's own entry predicted it: *"the reach question applies to CR-12's
paths too once they are made relative — and there the answer is likely different again, because a part
probe that overshoots is over the workpiece, not over bare board."*

It is different, and it inverts. The base probe got a long fixed reach because the only thing under the
tool was the surface being hunted for. Under a part probe is the part: a search that runs its full distance
without touching — an unplugged plate, a dirty clamp lead — descends that distance through the stock. So
**the reach stays `G38 Target`**, the operator's number, whose description already states the doctrine
("deep enough to reach the plate and no deeper"). No constant, no new field, and `probeTool()`'s default arm
is already correct for these callers, which is why not one of the diffs above passes a third argument.

**What that costs has to be stated, not discovered.** The reach staying short is right and it is not free,
because on these two modes the *post*, not the operator, decides where the probe starts:

| Path | Where the tool stands when the probe begins | Set by |
|---|---|---|
| first part, `Probe Z`, spoilboard base | `Inter Part Travel Z` above the probed spoilboard | `writeBaseEstablish()`'s retract, [:3025](../MPCNC_v4.0_Beta2.cps#L3025) |
| first part, `Probe Z`, machine-Z datum | `Inter Part Travel Z` as an absolute machine coordinate | [`writeMachineTravelZ()` :2095](../MPCNC_v4.0_Beta2.cps#L2095) |
| first part, `Probe Z`, no fixed reference | wherever the operator left it | the operator — and both `validateJob()` and the file already warn |
| subsequent part, `Probe Z` | the retract at the head of the traverse, in whichever frame | [`writeWCS()` :1890-1893](../MPCNC_v4.0_Beta2.cps#L1890) |
| subsequent part, `Jog XY & Probe Z` | wherever the operator jogged it, a few mm over the stock | the operator, at an `M0` |

Only the last is the case `G38 Target`'s `-10` was sized for. On the four above it, the tool is at a
clearance chosen to clear *the tallest clamp in the job* — "typically 30-60" by the `Inter Part Travel Z`
description's own words — so a 10 mm search from there reaches nothing at all on any ordinary job. Shipping
the provisional write alone would replace a probe measured from an unreadable register with a probe that
reliably alarms without touching, on the configuration `guide-pro.md` calls the best-practice path and the
dialog ships as the `Subsequent WCS / Part` default. That is CR-11's mistake, repeated on the other side of
the machine, and it is the reason this entry carries a `validateJob()` warning as part of the fix rather
than as a nicety:

```diff
+  // CR-12's other half. Once the target is relative it is finally a number the operator CAN size -- but
+  // on these two modes the post picks the start height, and it picks the one that clears the tallest
+  // clamp. Spoilboard only: under the machine-Z answer "Inter Part Travel Z" is a machine coordinate and
+  // the distance from it down to the stock top is not a number this post has.
+  if ((startMode == "Probe Z" || (multiWcs && changeMode == "Probe Z")) &&
+      getReservedBaseWcs() != 0 && parseInterPartTravelZ() != undefined) {
+    var clearance = parseInterPartTravelZ();
+    var reach = -getProperty(properties.probeG38Target);
+    if (reach >= clearance) {
+      warning(localize("\"G38 Target\" searches " + reach + " mm below the tool, and a \"Use Active WCS "
+        + "X0 Y0, Probe Z0\" probe starts at \"Inter Part Travel Z\" = " + clearance + " mm above the "
+        + "spoilboard -- so a probe that never touches its plate drives to or through the spoilboard "
+        + "surface at probing speed. Shorten the target."));
+    } else {
+      warning(localize("A \"Use Active WCS X0 Y0, Probe Z0\" probe starts at \"Inter Part Travel Z\" = "
+        + clearance + " mm above the spoilboard, and \"G38 Target\" searches " + reach + " mm down from "
+        + "there -- so it touches the plate only on stock thicker than " + (clearance - reach) + " mm. "
+        + "Deepen the target or lower the travel height if this job's stock is thinner than that; the "
+        + "post cannot check, the stock top being the value this probe exists to find."));
+    }
+  }
```

The `else` arm warns on a correctly configured job too, and that is deliberate rather than overlooked: the
post holds one of the two numbers and the operator holds the other, so the arithmetic can be *stated* and
never *decided*. A warning that appears on every job of this shape is the price of the operator being the
only party who can size the number, and it is a smaller price than a probe that alarms after the traverse.

**The alternative considered, and why not.** The gap the post is missing is `clearance - stockThickness`,
and stock thickness looks computable: a Z extent is a difference of two Zs in one frame, so it survives not
knowing where that frame's zero is, and Fusion exposes the stock box. The post could then search the gap
plus the operator's target, all at probe feed, stopping on contact — the default would keep working and no
warning would be needed. It is rejected on three counts. It rests on `getWorkpiece()`, which this post has
never called, so the shape and units of what comes back are unverified here and a walk cannot settle them.
It assumes the stock sits directly on the spoilboard, which is the base workflow's premise but not a fact —
parallels, a fixture plate and a vice all break it, and breaking it makes the computed gap *longer* than the
real one, which is the plunging direction. And it takes a number the operator can see and check out of their
hands. If `getWorkpiece()` is ever proven against a posted file, it belongs here as a way to *suppress* the
warning above when the stock is demonstrably thick enough — not as a way to compute the reach.

**Two pieces of prose the fix deletes rather than writes.** Both existing warnings about these modes are
partly descriptions of the defect. `partProbe()`'s in-file warning ends *"The G38.2 target that follows is
measured from the Z0 already stored in this WCS, which is the value this mode re-probes because it is not
trusted"* — that sentence is untrue after the fix and is replaced above. And `validateJob()`'s
[:1531](../MPCNC_v4.0_Beta2.cps#L1531) warning ends with two clauses that do not presently agree with each
other — the target is measured from the stored Z0, *and* the operator should "set the target deep enough to
reach the stock from that start height", which are two different reference points. The fix makes the second
clause the true one, so the first goes:

```diff
       + "Z0 already stored in the active WCS, which is the value this mode re-probes because it is not "
-      + "trusted, so set the target deep enough to reach the stock from that start height."
+      + "trusted."
```

*(shown against the sentence as it will stand once the paragraph above it is rewritten; the whole warning is
re-read when the fix is applied, since its subject changes from what the target measures against to what the
operator must clear.)*

**And the property description, which becomes true on every mode for the first time.** `G38 Target` is the
one control this finding is about, and CR-11 has already narrowed it once. It stops being a position:

```diff
-    description: "How far the probe move is allowed to travel before giving up -- a Z POSITION in the part's frame, not a distance. This bounds the PART probes only: the spoilboard base probe has a fixed reach of its own, being the one probe that starts above the stock AND the clamps. On the two Set ... to Current Pos modes the post writes a provisional Z0 first, so -10 (the default) searches to 10 mm below wherever the tool is now. On the two Use Active WCS modes it is measured from that WCS's STORED Z zero instead, which may be anywhere. Deep enough to reach the plate and no deeper: a probe that travels this far without touching is a failed probe, and GRBL raises an alarm and stops the job.",
+    description: "How far DOWN FROM THE TOOL a probe may search before giving up -- a DISTANCE, not a position. This bounds the PART probes only: the spoilboard base probe has a fixed reach of its own, being the one probe that starts above the stock AND the clamps. Every part probe now writes a provisional Z0 at the current height first, so -10 (the default) means \"search 10 mm below wherever the tool is standing when the probe begins\". WHERE IT IS STANDING DEPENDS ON THE MODE. On the Set ... to Current Pos and Jog to ... modes you put it there yourself, a few mm above the stock, and -10 is the right size. On the two Use Active WCS X0 Y0, Probe Z0 modes the POST puts it there, at Inter Part Travel Z -- the height that clears the tallest clamp in the job -- so the target has to be deeper than that height minus your stock thickness or the probe never touches the plate. The post states that arithmetic before it posts. Deep enough to reach the plate and no deeper: a probe that travels this far without touching is a failed probe, and GRBL raises an alarm and stops the job.",
```

**Nothing is emitted to state the reach, and that is the difference from CR-11.** The base probe got an Info
comment naming its search depth because 100 mm is a constant no operator can read in the dialog. Here the
number is `G38 Target`, it is in the dialog, and it is the `Z` word of the `G38.2` block itself — which,
after this fix, finally means the distance it appears to mean. A comment restating it would be one more line
in every probe block saying what the next line says.

**What this fix does not reach.** The tool-change re-probe through
[`onCommand(COMMAND_TOOL_MEASURE)` :2668](../MPCNC_v4.0_Beta2.cps#L2668) gets no provisional write and
should not: by then this job has established that WCS's Z0 itself, so the stored value is the post's own and
`G38 Target` is measured from a zero it wrote — which is CR-07's ground, about *which* register it writes,
not about what the target measures against. The base probe is CR-11's and already fixed. `Use Active WCS X0
Y0 Z0` (`Skip`) probes nothing at all. And on Marlin `writeWcsOrigin()` falls back to a global `G92`, which
is what the shipped `Current XY & Probe Z` path already emits there, so the provisional write behaves on
Marlin exactly as an existing path does — and Guard C keeps every subsequent-part path off Marlin entirely.

**One asymmetry found and left alone.** `writeWCS()`'s `Jog XY & Probe Z` arm says nothing at all when the
tool cannot probe: it writes X0 Y0, skips the probe, and emits only a Debug trace, where
[`writeWcsOnStart()`'s twin :3171](../MPCNC_v4.0_Beta2.cps#L3171) writes a `>>> WARNING` that Z0 was not
established and the job will run against whatever the register holds. The same silence, on a later part.
It is a warning, not a frame error, and it is not the mechanism this finding is about, so it is recorded
here rather than folded into the diff.

### TEST

**Status:** `open` — written, not run: the FIX is a proposal. W12f is the row to walk first if it is applied,
being the only one that tests the half of the fix that is not a provisional origin write.

| Test | Method | Proves | Property set | State |
|---|---|---|---|---|
| W12a | walk | the first-part `Use Active WCS X0 Y0, Probe Z0` probe searches from where the tool stands | GRBL/mm, Comment Level `Info`, `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, `Fixed Z Reference` = Spoilboard, `Reserved WCS` = G59, `Inter Part Travel Z` = 40, `G38 Target` = -35, probe XY offset unset, one part on G54, tool 1 | open |
| W12b | walk | the subsequent-part twin does the same, and the unknown-height warning does **not** follow it there | W12a with two parts (G54, G55) and `Subsequent WCS / Part` = `Use Active WCS X0 Y0, Probe Z0` | open |
| W12c | walk | the third path — subsequent `Jog to X0 Y0, Probe Z0` — writes the provisional Z0 its first-part twin always wrote | W12b on RepRap with `Subsequent WCS / Part` = `Jog to X0 Y0, Probe Z0` | open |
| W12d | walk | a tool that cannot probe leaves Z0 alone on that path, so the mode does not become `Jog to X0 Y0 Z0` | W12c with a jet tool | open |
| W12e | walk | the paths that already write a provisional Z0 gain no second one, and the tool-change re-probe gains none at all | `First WCS / Part` = `Set X0 Y0 to Current Pos, Probe Z0` with the probe XY offset set; then a `Do First Change` job with `Probe After Tool Change` on | open |
| W12f | walk | the reach warning fires on both sides with the right arithmetic, and stays silent where it has no numbers | W12a at `G38 Target` = -10, then -45; then `Fixed Z Reference` = Machine Z; then = None | open |

**W12a** must show the traverse to the stored X0 Y0 emitted first at whatever height the base establish
left the tool, then `( Provisional Z0 at the current height so the probe target is a relative limit)` and
`G10 L20 P1 Z0` — **P1, the part's register, not the base's** — and only then `G38.2 F30 Z-35`. The `Z-35`
must be the property untouched: no `propertyMmToUnit` applied twice, and no `BASE_PROBE_REACH_MM` anywhere
on this path. `G10 L20 P1 Z0.8` overwrites the provisional value four blocks later. **I1 frame** — every Z
in the block is written after the `G54` select, and the provisional origin is written into the register the
probe then searches in.

**W12b** must show the same three blocks after the traverse retract and the `G55` select, and must **not**
show the `>>> WARNING: no Z reference is established` line: `zUntrusted` is now true on this path, so the
warning's second condition is what keeps it away, and Guards B and B' guarantee `fixedZEstablishedInFile()`
on any job that reaches it. A warning here would mean the two questions the renamed flag separates have been
run back together.

**W12c** must show `G10 L20 P2 X0 Y0 Z0` after the `M0`, where the post today emits `G10 L20 P2 X0 Y0` and
no Z word at all. **W12d** must show that same block back to `X0 Y0` with no Z, reached through the `else`
arm, and the Debug trace naming `writeWCS`.

**W12e** is the presence-based sibling W12a's absences need, and it is the dangerous direction. On `Set X0
Y0 to Current Pos, Probe Z0` the caller writes `G10 L20 P1 X0 Y0 Z0` and then calls `partProbe(true)` with
no second argument, so exactly one origin write may appear before the `G38.2`; a second would mean the
provisional write has been made unconditional and the `Current XY` modes are writing it twice. On the
tool-change re-probe, `probeTool()` is reached through `onCommand()` and never through `partProbe()`, so no
provisional write can appear at all — that path's Z0 is one this job established.

**W12f** must show, at `-10`, the second warning naming 40, 10 and 30; at `-45`, the first warning naming 45
and 40; under Machine Z and under None, neither, `getReservedBaseWcs()` being 0 on both. The point of the
last two is that the warning claims a distance above the spoilboard, and neither of those answers has one.

**What a fail looks like.** A `G38.2` before the provisional write in W12a or W12b: the write is on the
wrong side of the traverse. `P6` on the provisional block in W12a: the base's register, meaning
`currentWorkOffset` was read before the part's select rather than after. A warning in W12b: the flag rename
has merged two conditions that must stay apart. Two origin writes in W12e, or any origin write on the
tool-change re-probe: the write has escaped its guard, and on the tool-change path it would overwrite a real
Z0 with a provisional one — the one direction in this fix that damages a job that is set up correctly. A `Z`
word on W12d's block: the provisional write is outside `canProbe` and the jet job is silently running to a
Z0 it never established. Record it in the status line above and revise the FIX; do not edit the expectation
to match what was seen.
