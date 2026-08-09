# Coverage fixes — `MPCNC_v4.0_Beta2.cps`

The proposed fix for each coverage finding, and the test that would show it worked. One entry per CR
number, added when the fix is worked out — not every finding in
[`CoverageFindings.md`](CoverageFindings.md) has an entry here, and the absence of one means only that
nobody has designed the fix yet.

This file is where the thinking about a fix happens, so it is meant to change. The findings file is not:
it is the review's frozen record of what the source said, carrying only a status box per finding. When a
fix here is applied, tick the finding's status box over there and name the commit — that box, not this
file, is what says whether the work is done.

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
| FIX | `**Status:** ` | `[ ] applied` while it is still a proposal; `[x] applied — <sha>` once a commit carries it |
| TEST | `**Status:** ` | `open` — not run, or not yet written; `pass`; `fail — <what was seen>` |

A `fail` is not a reason to edit the FIX in place. Say what failed in the test status, then revise the
FIX above it — the point of the two lines is that the disagreement between them stays visible.

---

## CR-11 — the spoilboard base is probed to a target measured in the frame the probe is establishing

**Finding:** [`CoverageFindings.md` → CR-11](CoverageFindings.md) — Professional, Machine damage, Certain.

### FIX

**Status:** `[ ] applied`

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

**The reach has to change with it, and no finding says so.** Making the target relative is only half the
job: it decides *where the search starts*, and `G38 Target` then decides *how far it goes*. No CR asks
whether the shipped `-10` is far enough to find the spoilboard — CR-11 and CR-12 are about the frame the
number is measured in, never its size, and the "never reaches the stock" in CR-15 is a different mechanism
on the part probe. The question only becomes answerable once this fix lands, because until then the target
is an arbitrary absolute and no reach can be reasoned about at all.

Answered, it fails. `G38 Target` is one property shared by every probe in the post, and its description
sets it for the part probe — "deep enough to reach the plate and no deeper", where the tool starts a few
millimetres above the stock top. The base probe starts nowhere near there: it probes wherever the tool
already sits, and that spot has to clear the stock and the clamps. On a job with 18 mm stock in clamps the
tool is easily 30–50 mm above the spoilboard, so a 10 mm search never touches, and a `G38.2` that travels
its full distance without touching is a failed probe — GRBL alarms and the job stops. So the fix as
described would turn an unbounded plunge into a job that reliably refuses to start at the shipped default.
Better, and still wrong.

The two probes need two numbers, because they genuinely start at different heights and no single value
can be both "no deeper than the plate" for one and "deep enough to reach the spoilboard from above the
clamps" for the other. The recommendation is to give the base establish its own travel allowance rather
than borrow `G38 Target`. Note that the safety argument that keeps `G38 Target` short does not apply to
the base: the part probe is short so a mis-set origin cannot drive the tool through the workpiece, whereas
the base probe is over bare spoilboard by its own precondition, with nothing beneath it but the surface it
is looking for. A deep base reach is the safe answer, not the risky one.

If a new control is unwanted, the alternative is to keep the shared property and make the shortfall
visible instead: state the resulting search depth in the Info comment the fix already adds, and have
`validateJob()` say plainly that the base probe searches only `G38 Target` below wherever the tool is
parked. That leaves the operator to set a number that serves both probes, which is a real constraint on
them, but it is at least a stated one. **This choice is open and should be settled before the fix is
written** — it decides whether the change touches the dialog.

This fixes the base establish only. CR-12 is the same mechanism on the part probes, where the operator has
alternatives in the dialog and the answer may be a different one; fixing this does not fix that. The reach
question above, however, applies to CR-12's paths too once they are made relative.

### TEST

**Status:** `open`

_Not yet written._
