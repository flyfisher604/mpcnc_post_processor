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
