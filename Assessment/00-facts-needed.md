# Facts I need confirmed

These are the observations that would settle the questions this review turns on.
I cannot get them myself: no full-license Fusion 360, no hardware, no sender.

**How to read this file.** Each item says what to build, what to post, and which
lines to copy back. Anything marked **RESOLVED** was answered from local
`[SDK]` evidence (Autodesk's own bundled posts on this machine) after this file
was first written — the answer is in `03-f360-and-firmware.md` and no longer
needs a human. Anything still **OPEN** is a real gap, and every conclusion
downstream that depends on it says so.

The single most valuable thing: **a full-license user posting two jobs and
pasting the raw output.** Job A and Job B below would together close most of
this list.

---

## ANSWERED BY THE AUTHOR — 2026-08-12

Four blocking questions closed. These are `[AUTHOR]` facts: asserted by the
project owner from his own knowledge, not observed by me.

| Q | Answer | What it settles |
|---|---|---|
| **1.1 / S12** | **Multi-part / multi-fixture IS in scope**, for the hobbyist **full-licence** user — **refined 2026-08-13**: the *workflow* is in scope, the *orchestration* is *"a user problem not a post issue"* | Groups 4 and 6 serve a real persona. **Group 5 does not** — it was built for a machine that cannot home, and this workflow requires homing. Serving S12 needs less code than has been written for it. `04-user-stories.md` carries the split |
| **`C2` / 1.2** | **Confirmed: the personal licence converts all rapids to `G1`** — and **upgraded to `[SDK]` 2026-08-13** by F360's own emitted banner in `Andrew.gcode` | Group 3's premise holds, now on the vendor's word rather than the author's. Its ~244 lines are justified. **Job C is no longer needed** |
| **`E1` / 1.3** | ~~**Marlin has no WCS registers**~~ → **SUPERSEDED 2026-08-13: assume Marlin HAS WCS registers; the user docs must state a minimum firmware version** | **Guard C is deleted.** `design.md` line 23 is rewritten. See below — this is now settled from source, not asserted |
| **1.4** | **There is a laser persona** | Group 9's 7 properties are justified in kind. Detail still unenumerated |
| **2.1** | Personal edition never emits tool changes; the hobbyist still needs the machine left in a state where a manual change does not lose the known position. Reading `tool.manualToolChange` is a **professional** operation | **Corrects my Group 7 finding** — see `07-code-map.md`. The two paths need separate code, not one unified one |
| **2.2** | Keep the personal-licence end-of-file tool change untouched | Confirmed |

### `E1` — **CLOSED 2026-08-13 from Marlin source. My previous note was wrong.**

The author directed a reconsideration: *"you found that v1e's Marlin has WCS
registers. If that is a true statement then they should be utilized."* **It is a true
statement.** Full evidence in `03-f360-and-firmware.md` §4b; consequences in
`05-history.md`.

| Sub-question | Answer | Source `[DOC]` |
|---|---|---|
| **E1a** — per-system storage, or one global? | **Per-system. Nine.** `static xyz_pos_t coordinate_system[MAX_COORDINATE_SYSTEMS];`, `MAX_COORDINATE_SYSTEMS` = 9 | `Marlin/src/gcode/gcode.h`, 2.1.x |
| **E1b** — persisted to EEPROM? | **Yes** — *"All workspaces default to 0,0,0 at start, or with EEPROM support they may be restored from a previous session"* | `G53-G59.cpp` |
| **How is one written?** | `G5x` to select, then **`G92`** — which writes the register: `coordinate_system[active_coordinate_system] = position_shift;` | `G92.cpp` |
| **How many are addressable?** | Nine — `G59` passes `parser.subcode`, so `G59.1`–`G59.3` reach indices 6–8 | `G53-G59.cpp` |

**Withdrawing my earlier reconciliation in full.** I wrote that Marlin's array *"is
RAM-only"* and that *"nothing survives a power cycle and nothing can be written to a
named slot."* **All three claims are false.** It persists, and every slot is reachable by
selecting it. I offered that as an `[INFERRED]` bridge between the author's answer and
my own source read, and it was the wrong instinct — the correct move was to go back to
the source, which is what the author's push produced.

**The one real limitation**, and it is narrow: Marlin can only write the **active**
register, and only **positionally** — `G92` means *"call where the tool is standing
this"*. GRBL and RepRap can write **any** register from **anywhere** with
`G10 L2 P<n> X.. Y.. Z..`. But for *selecting* offsets — all a multi-WCS job needs, and
all a stock post does — there is full parity across the three firmwares.

**Still open, and now a prerequisite rather than a curiosity:**

- **Which Marlin release fixed issue #14743** (`G92` inside `G54` also shifting the
  `G53` machine origin; closed, resolution not legible from the page). Needed for the
  minimum-version statement `[AUTHOR]`, and `CLAUDE.md` requires it settled from the
  firmware's own source and changelog with file and version. **`09-plan.md` Step 3 is
  blocked on this.**
- **A related hazard, already established:** homing runs `position_shift[axis] = 0`
  (`motion.cpp`, `set_axis_is_at_home()`), and re-sending `G54` does not restore the
  offset because `select_coordinate_system()` early-returns. **On Marlin, homing
  silently detaches the program from its own work origin.** Not open — recorded, and
  owed to `design.md`.

### Still open

`A2`–`A4`, `B2`, `B3`, `B5` (what F360 emits at a setup boundary and around a tool
change) and `D1`–`D4` (operator practice). **With S12 in scope these matter more,
not less** — they are exactly what the six test jobs in `PReview.md` §3.1 would
answer, and posting those jobs is now Phase 1 of the plan.

## Job A — two operations, one setup, one tool

Build: a rectangular block. One setup. Two operations on the same tool (e.g. a
2D adaptive clear then a 2D contour). Default clearance / retract / feed heights
— do not customise them. Post with a **stock Autodesk `grbl` post**, not the
MPCNC post, so the output shows what F360 supplies rather than what this project
adds.

Copy back: the **whole file**. It is small.

What it settles:

| # | Question | State |
|---|---|---|
| A1 | Does F360 itself emit a retract to clearance height between two operations, or does the post have to synthesise it? | OPEN |
| A2 | Are those Z moves absolute work-coordinate moves, machine-coordinate (`G53`) moves, or a mix? | OPEN |
| A3 | How many distinct heights actually appear in output — clearance, retract, feed — and in what order on entry and exit? | OPEN |
| A4 | Is the move between operations a rapid (`G0`) or a feed (`G1`)? | OPEN |

## Job B — two setups, two tools, different WCS

Build: the same block. **Two setups**, each with one operation, and set the
second setup's WCS to a different work offset number (e.g. setup 1 → G54,
setup 2 → G55) in the setup's Post Process tab. Give the second operation a
**different tool** so a tool change is forced. Post as one program with the
stock `grbl` post.

Copy back: the whole file, plus a screenshot or description of **where in the
F360 UI you set the WCS number**.

What it settles:

| # | Question | State |
|---|---|---|
| B1 | Does `G54`/`G55` actually appear in the output, and once per setup or once per operation? | OPEN |
| B2 | What does F360 emit at the setup boundary — retract, spindle stop, a move to a change position, nothing? | OPEN |
| B3 | Does F360 re-approach the next setup's start point itself, or does it hand the post a first move from an unknown position? | OPEN |
| B4 | At the tool change: what appears? A `T` word, `M6`, a comment, a pause, an operator message? | OPEN |
| B5 | Does F360 retract before the tool change on its own, and to what height? | OPEN |
| B6 | Is there any sign the tool-change behaviour is post-dependent rather than F360-dependent? | OPEN |

## Job C — personal-licence confirmation (only if you still have a free seat)

Build: any setup with **two** operations. Try to post it with the free/personal
licence.

| # | Question | State |
|---|---|---|
| C1 | What exactly happens — refusal, silent truncation to one operation, a warning dialog? Quote the message. | OPEN |
| C2 | With a single operation, do rapids come out as `G0` or are they converted to `G1` at feedrate? | **CLOSED 2026-08-13** — F360 says so itself in the file header: *"When using Fusion 360 for Personal Use, the feedrate of rapid moves is reduced to match the feedrate of cutting moves."* (`OneDrive/…/GCode/Andrew.gcode:6-9`). `[SDK]` Note the precise mechanism: the **feedrate** is reduced, the movement type still reads `MOVEMENT_RAPID`, which is exactly the signal Group 3 reads — so it recovers rapids from a flag F360 still sets, not from geometry. **Group 3 is not a heuristic** |
| C3 | Is there any watermark, comment, or header line in the output that identifies the licence tier? | OPEN |

This one matters for a specific reason: the post carries a whole property group
(Group 3, "Map G1s to Rapids") built on the premise in C2, and a licence-latch
mechanism (finding CR-03) built on the premise in C3. Both are worth confirming
directly rather than by inference.

## Operator-practice questions — no posting required

These need an experienced multi-setup operator rather than a posted file. A
paragraph each is enough.

| # | Question | State |
|---|---|---|
| D1 | When you run a job with two setups on a hobby machine, do you actually use two different work offsets, or do you re-zero to the same G54 between setups? | OPEN |
| D2 | If you probe a part's corner, where does the number end up — do you write it into G54 with `G10`, or jog-and-zero by hand in the sender? | OPEN |
| D3 | For a manual tool change mid-job, what do you physically do, and what do you need the G-code to have done before it pauses? | OPEN |
| D4 | Do you trust your machine's Z position after a manual tool change? What do you re-establish, and how? | OPEN |

---

## Added in step 5 — one firmware question, answerable without hardware

**E1 — Does Marlin keep separate stored offsets per work coordinate system, and
do they survive a power cycle?** State: ~~OPEN, and decisive~~ → **CLOSED
2026-08-13 — YES to both.** It was decisive. See the answer table at the top of this
page for the resolution; the framing below is kept because it correctly predicted
which two sub-questions mattered.

`docs/design.md` asserts *"Marlin is single-frame: no per-WCS registers, so one
global `G92` origin"*, and Guard C rejects any Marlin job using more than one
work offset on that basis. But:

- V1 Engineering's Marlin builds enable the feature —
  `opt_enable \ CNC_COORDINATE_SYSTEMS` `[DOC]`
  `V1EngineeringInc/MarlinBuilder`, `src/configs/common/cnc-config`.
- Marlin's implementation indexes an array bounded by `MAX_COORDINATE_SYSTEMS`,
  with `G54`–`G59` selecting an entry and `G92` setting the current one `[DOC]`
  `Marlin/src/gcode/geometry/G53-G59.cpp`, 2.1.x.

That reads like per-WCS registers **do** exist on the firmware the anchor
community runs, which would mean Guard C rejects jobs the firmware would execute.
Two sub-questions, both answerable by reading source rather than by testing:

- **E1a** — is `coordinate_system[]` genuinely per-system storage, or a single
  active offset with a selector? (Read `G53-G59.cpp` in full plus the array's
  declaration.)
  → **ANSWERED: genuine per-system storage.** `static xyz_pos_t
  coordinate_system[MAX_COORDINATE_SYSTEMS];` with `MAX_COORDINATE_SYSTEMS` = **9**
  (`gcode.h`); `G92` writes `coordinate_system[active_coordinate_system]`
  (`G92.cpp`). `[DOC]`
- **E1b** — is that array **persisted to EEPROM**? GRBL persists `G10 L2` offsets;
  if Marlin does not, then the "set the fixtures on run 1, reuse them next week"
  workflow really is impossible on Marlin even with the feature compiled in — and
  `design.md`'s conclusion is right for the wrong reason. This distinction decides
  whether the Marlin branch in Group 6 is justified or over-broad.
  → **ANSWERED: it is persisted.** *"All workspaces default to 0,0,0 at start, or
  with EEPROM support they may be restored from a previous session."* `[DOC]`
  `G53-G59.cpp`. **So `design.md`'s conclusion is not right for the wrong reason —
  it is wrong.** The set-once-reuse-later workflow is available on Marlin.

**This section correctly identified the one place where re-reading firmware source
could change a Group 6 decision. It did.** Guard C is deleted, `design.md` line 23 is
rewritten, and the Marlin user joins the multi-part persona
(`05-history.md`, `09-plan.md` Step 3).

**One question opened by the answer**, and it is now a prerequisite rather than a
curiosity: **which Marlin release fixed issue #14743**, where `G92` inside `G54` also
shifted the `G53` machine origin. Needed for the minimum-version statement, and
`CLAUDE.md` requires it settled from the firmware's own source and changelog with file
and version.

## Why these and not others

Everything else this review needs can be answered from evidence I do have:
Autodesk's 490 bundled posts on this machine (including `grbl.cps` and
`reprap.cps`) show what arrives at a post's callbacks, and the firmware sources
settle what Marlin, GRBL/FluidNC and RepRap accept. The list above is
specifically the part where **only observation of a running full licence will
do**, and where guessing would be indistinguishable from knowing.
