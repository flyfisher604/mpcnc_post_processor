# Step 8 — What the finished post should be

**Revised 2026-08-12 after the author's answers.** The earlier version offered two
targets because the scope question was open. It is now closed: **S12 — multi-part /
multi-fixture — is in scope for the hobbyist full-licence user.** So there is one
target, and it is the former Target B.

Not a list of removals. This describes the deliverable.

---

## The one-sentence version

**A three-firmware translator for hobby CNC that covers the full range from a
hand-zeroed single-operation personal-licence job to a multi-fixture full-licence
batch — where every capability is *verified by a posted file*, and the post warns
rather than computes wherever the machine frame is unknown.**

The change from today is **not** a reduction in scope. It is that the untested 21%
becomes tested, the duplicated concepts collapse, and the seven open findings close.

## Size, honestly — **revised 2026-08-13**

| | Now | Target 08-12 | **Target 08-13** |
|---|---|---|---|
| Lines | 3,758 | ~3,650–3,800 | **~3,300–3,450** |
| Properties | 72 | ~66 | **~60** |
| Property groups | 11 | 10 | **9** |
| `validateJob()` | 288 lines | ~260 | **~200** |
| Enum options that don't work on GRBL | **4** | 4 | **0** |
| Open findings | **7** | 0 | **0** |
| Posted multi-part jobs | **0** | 6 | **6** |
| Posted tool-change jobs | **0** | — | **≥1** |
| Distinct "is there a frame?" predicates | **4** | 2 | **1** |

**The reduction is a consequence, not the goal.** It comes from three specific
decisions, not from a general campaign to make the file smaller:

1. **The spoilboard base retires** (~250–300 lines) — because a machine that cannot
   home cannot do multi-part work anyway, so the subsystem has no user.
2. **The orchestration goes to the operator** (~100 lines) — `probeOnChange` and the
   four modes that answer it.
3. **Four non-functional enum options go** — Jog modes on firmwares without
   jog-at-pause.

Everything else is a fix, a rename or a test. **If the file ended up the same size but
the six §3.1 jobs were posted and the seven findings closed, that would still be a
success.** Size is the least interesting row in this table; the two "posted jobs" rows
are the ones that matter.

## The gate this project is missing

Not a code target, and the cheapest item here `[AUTHOR]`: professional testing was
**deliberately deferred** to get a Beta3 that is stable for hobby users. That is a
sound plan which nothing in the repository states. So the target includes:

- **The hobby path is verified** — 24 posted files today, and it is the path Beta3 is
  for.
- **The professional path says what it is.** Whatever its state at Beta3, `guide-pro.md`
  and the property descriptions must not describe unverified behaviour in the same
  voice as verified behaviour. **A feature that has never been posted must not read as
  finished.**

## The capabilities it has

| Capability | Story |
|---|---|
| Marlin, GRBL/FluidNC and RepRap dialects from one source | S4 — **Autodesk ships no Marlin post at all** |
| Correct output from a hand-set zero, no homing assumed | S1 |
| Non-cutting moves at travel speed on a personal licence | S2 — **premise confirmed**: the free seat converts all rapids to `G1` |
| A file that ends ready for a manual tool change **without losing the work origin** | **S13** |
| The work offset F360 selected, emitted when it changes | S5 |
| Work origins in the firmware's dialect — `G10 L20`, or `G92` on Marlin | S6 |
| Z zero by probe (`G38.2`) or by declaration | S1, S6 |
| Optional homing at job start, per-axis where the firmware allows | S7 |
| Machine-frame retract where this program established the frame | S7 |
| **Post an F360 "Multiple WCS Offsets" job at all** — which it currently cannot | **S12** |
| **Traverse between parts in the machine frame, on a homed machine** | **S12** |
| **Multi-WCS on Marlin, above a stated firmware version** | **S12** — Guard C deleted |
| Professional tool changes driven by F360's own flag | S9 |
| Laser power and enable in the firmware's dialect | **S14** |
| Spindle, feeds, coolant in dialect | S10 |
| A loud warning, in file and dialog, wherever the frame is unknown | S8 |
| Refusal to post rather than plausible-looking bad output | S11 |
| Operator-supplied preamble/postamble via include files | escape hatch |

## What it deliberately does not do, and who owns each

- **Compute an absolute safe Z from unknowns** → the **operator**. Autodesk's own post
  in this exact case emits *"Raise the Z-axis to a safe height before starting the
  program"* and nothing more.
- **Synthesise retracts between operations within one setup** → **F360**. Its toolpath
  already contains them.
- ~~**Hold clearance or home positions that F360's machine configuration already
  holds** → **F360**.~~ **WITHDRAWN 2026-08-13.** F360 has the slot and no way to fill
  it: `retractPlane` appears in **0** of 211 machine definitions and `setRetractPlane`
  is commented out in all 159 posts that mention it. A post property is the **only**
  place a machine-frame travel height can come from. `03-f360-and-firmware.md` §1a.
- **Orchestrate multi-fixture work** → the **operator** `[AUTHOR]`. Setting each work
  offset, choosing a clearance that clears every fixture, and deciding whether the
  fixtures are mutually compatible. The post emits the offsets F360 names and traverses
  in the machine frame; it does not manage the bed.
- **Establish a tool length** → the **machine** on RepRap (`G10 L1` via macro), the
  **sender** on GRBL (`G43.1` needs a computed literal), the **operator** on Marlin
  (no TLO exists). The post supplies a stop and an include-file hook, never a
  computation.
- **Host F360 WCS probing operations** → **nobody, on two of three firmwares.** GRBL
  and Marlin have no arithmetic, so the operation cannot exist there. The post refuses
  it and names the reason.
- **Decide whether a *professional* tool change is manual** → **F360**, via
  `tool.manualToolChange`. *(Not applicable on a personal seat, where F360 emits no
  tool change at all — there the post owns it outright.)*
- **Vary by machine brand** → nobody. Same firmware, same output.
- **Branch per firmware beyond an enumerable dialect table** → the real differences are
  few and known: `G10 L20 P<n>` vs `G5x`+`G92`, six slots vs nine, `$H` vs per-axis
  `G28`, `G17`/`G94` availability, `G53` build gating, and TLO. **No longer on that
  list: whether per-WCS registers exist. All three have them** —
  `03-f360-and-firmware.md` §4.

## The property groups that survive, and their shape

| Group | Now | Target | Change |
|---|---|---|---|
| 1 — Job | 8 | 8 | — |
| 2 — Feeds and Speeds | 7 | 7 | — |
| 3 — Map G1s to Rapids | 2 | 2 | — premise `[SDK]`-confirmed, keep as is |
| 4 — Machine Frame | 3 | **4** | **+ `machineTravelZ`**, inherited from Group 5. Homing becomes the precondition for multi-part work |
| 5 — Fixed Z Reference | **5** | **0** | **GROUP DELETED.** The spoilboard base has no user; one property moves to Group 4 |
| 6 — Work Origin | 10 | **9** | **retitled**; `probeOnChange` deleted, `probeOnStart` 6 modes → 3, predicates consolidated |
| 7 — Tool Changes | 8 | ~6 | **split into two paths**; `toolChangeDisableZStepper` deleted (HR-10); 7b rebuilt on include files |
| 8 — External Include Files | 5 | **6** | **+ the tool-change hook.** This group gains the job Group 7 could not do |
| 9 — Laser | 7 | 7 | keep; persona confirmed, **size still unaudited, and unexercised by any test** |
| 10 — Coolant | 10 | ~4 | **reduce** — still no persona |
| 11 — Duet | 2 | 0 | **folded** into the firmware selector |

**Nine groups, ~60 properties.** The two structural moves are Group 5 disappearing and
Group 8 acquiring the tool-change hook — the second is what makes the first affordable,
because the operator gets a real place to put the behaviour the post stops inventing.

**Group 6's title is the one that misleads today.** *"On WCS / Part / Fixture
Changes"* describes when it fires, not what it does. It should say what the operator
is deciding — work origin, per part.

**Group 7 must read as two features, because it is two features.** One is
*"when this file ends, leave the machine tool-changeable"* (personal, F360-less,
answers S13). The other is *"when F360 asks for a tool change mid-program, do this"*
(professional, driven by `tool.manualToolChange`). Sharing one 65-line function is
the defect; five open findings live in the overlap.

## What stays exactly as it is

Named deliberately, so this does not read as though everything is in play:

- **The firmware fact tables in `design.md`** and every sourced claim in them. The
  project's most valuable asset and the hardest thing to rebuild.
- **`writeMachineHoming()`** and the per-axis homing split.
- **Group 2** — feed limiting by axis component, arc feed limiting.
- **Group 3** — entirely. Premise confirmed; no action.
- **Group 8** — external include files.
- **The `workOffset 0` → WCS 1 alias** — and it deserves more credit than "stays". It
  is a better answer than Autodesk's: giving 0 a defined meaning removes the ambiguity
  the stock post can only refuse (`03-f360-and-firmware.md` §3).
- ~~**The Marlin single-frame handling and Guard C.**~~ **REVERSED 2026-08-13.** Marlin
  has nine WCS registers, persistent with EEPROM `[DOC]`. **Guard C is deleted**, its
  message is a false statement to the user, and `design.md` line 23 is rewritten. See
  `05-history.md`.
- **`writeBlock`/format infrastructure**, modal handling, `flushMotions()`.
- **The `>>> WARNING:` channel** that bypasses Comment Level. This is the model for the
  Z-trust problem and should be extended, not replaced.
- **The personal-licence tool-change path** (answer 2.2).
- **Every Tier 1 and Tier 2 item in `06-retention.md`** — nine verified fixes and the
  firmware knowledge.

## What the operator gains, in their own terms

- A multi-fixture batch job they can **trust**, because someone posted it and checked
  the output — rather than one that has never been run.
- A tool change that stops in the right place, probes into the right work offset, and
  does not emit Marlin commands to a GRBL controller.
- On a personal seat: a file that ends without stealing their zero.
- A dialog with one question per concept instead of four predicates' worth of
  distinctions leaking into the property list.

## The unresolved edge, recorded rather than hidden

**Corrected 2026-08-13 from Marlin source, and it turns a vague warning into one
concrete rule.** The claim was that a Marlin `G92` origin *"survives neither a power
cycle nor a homing cycle."* What the source says `[DOC]`:

- **Power cycle: it survives.** `G92` writes `coordinate_system[active_coordinate_system]`
  (`G92.cpp`), and workspaces *"may be restored from a previous session"* with EEPROM.
- **Homing: it is lost from live position.** `set_axis_is_at_home()` runs
  `position_shift[axis] = 0` (`motion.cpp`) — and **re-sending `G54` does not restore
  it**, because `select_coordinate_system()` returns early when that system is already
  active. Recovery requires selecting a different workspace and selecting back.

So the origin is **durable in storage and fragile in application**, and the hazard is
not the power switch — it is **homing**. The target is therefore not a general warning
about volatility but a specific rule the post can be held to:

> **On Marlin, the post must not home after establishing a work origin** — not at
> end-of-file, not at a tool change, not on a park. And where an operator might home
> between files, the file says what that costs and how to undo it.

**The personal-licence Marlin user still has the weakest hold on their own zero of any
persona here**, and this is now a rule testable in a diff rather than a caution.
Same warn-don't-compute principle as the Z-trust case, with a sharper object.

This fact belongs in `design.md`'s firmware table. It is Tier 2 knowledge by
`06-retention.md`'s own definition, and the table does not have it.
