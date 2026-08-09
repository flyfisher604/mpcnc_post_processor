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
| FIX | `**Status:** ` | `[ ] applied` while it is still a proposal; `[x] applied` plus the commit **subject** once a commit carries it — a subject survives an amend or a rebase, and the CR id in it makes `git log --grep` find the commit; a sha written here does not survive, because this line ships inside the very commit it names |
| TEST | `**Status:** ` | `open` — not run, or not yet written; `pass`; `fail — <what was seen>` |

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
