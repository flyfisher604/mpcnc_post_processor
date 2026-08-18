# Release notes — v4.0 Beta 3

Everything that changed since the `v4.0_Beta2` tag. Ninety-three commits changed the post itself in
that span, so this is a summary of what you will notice, not a changelog — `git log v4.0_Beta2..` is
the changelog, and `docs/findings.md` is the register every fix below resolves to.

**Two things to do before your first Beta 3 job.** Both are consequences of how much of the dialog
moved, and neither is optional.

---

## 1. Your saved settings will not carry over

**Every property key in the dialog was renamed, and not one old name survived.** Beta 2 named its
keys by position within a group — `A_Job_SelectedFirmware`, `B_Feeds_TravelSpeedZ` — which meant
inserting a setting renamed the ones after it. Beta 3 names them by group and meaning
(`jobSelectedFirmware`, `feedsTravelSpeedZ`) and orders the dialog with an explicit `order:` instead
of by an alphabetical prefix.

The consequence is blunt: Beta 2 had 68 keys, Beta 3 has 63, and **they have no names in common**. A
saved preset stores values under the old names, so Beta 3 does not see them and every setting falls
back to its shipped default.

**So walk the dialog once, and pay particular attention to groups 4, 5 and 6** — those are also the
groups whose meaning changed most, below.

## 2. The post is a new file

The deliverable is now **`MPCNC_v4.0_Beta3.cps`**. Fusion identifies a post by its filename, so
**remove `MPCNC_v4.0_Beta2.cps` from the Post Library before importing Beta 3**, or you will have two
posts with near-identical descriptions and no way to tell from the picker which one you chose.

---

## The dialog: eleven groups became ten

| Beta 2 | Beta 3 |
|---|---|
| `01 - Job` | `1 - Job` |
| `02 - Feeds and Speeds` | `2 - Feeds and Speeds` |
| `03 - Map G1s to Rapids …` | `3 - Map G1s to Rapids …` |
| `04 - Establish Machine Coordinates` | **`4 - Machine Frame - homing, travel Z and end park`** |
| `05 - Establish Spoilboard Reference` | **retired — folded into group 4** |
| `06 - On WCS / Part / Fixture Changes` | **`5 - Part Origins - how each part's X0 Y0 Z0 is established`** |
| `07 - Tool Changes` | **`6 - Tool Changes - the post hands over, it changes no tool`** |
| `08 - External Include Files` | `7 - External Include Files` |
| `09 - Laser` | `8 - Laser` |
| `10 - Coolant` | `9 - Coolant` |
| `11 - Duet` | `10 - Duet` |

Two groups became one because the spoilboard reference was retired, and every group after it shifted
down by one. The zero-padding is gone, and the titles now say what the group decides — and, for group
6, what the post refuses to do.

`docs/property-reference.md` is the full list of settings in dialog order.

---

## The machine frame and the Z reference

**The probed spoilboard base is gone.** Beta 2 offered two ways to establish a fixed Z reference: a
probed spoilboard base, or the machine's own homed Z. The spoilboard base was retired (`PR-16`),
leaving the homed machine Z as the one fixed Z reference. It was the one thing the project's own
assessment called over-built, and a machine that cannot home could not use it for multi-part work
anyway.

**Group 4 now separates capability from action** — what your machine *can* home, and what this job
*should do* about it. "Homed at the controller, do not home here" is now sayable, which it was not in
Beta 2.

**The multi-part Z frame is derived from the homed machine** (`PR-14`). The homed Z0 is the only frame
whose zero does not move with stock thickness, so it is the only height that can clear every fixture
in a job whose parts differ in thickness.

Also in this area:

- **A `Machine Travel Z` at or above machine zero now warns on GRBL** (`PR-17`), where machine zero is
  normally the top of travel.
- **A machine coordinate that does not parse says so** (`WR-2`) instead of being silently treated as
  absent.
- **A `Safe Z` expression that will not parse warns**, rather than falling back without comment.
- **Both Safe Z fields now say which frame their height is measured in**, which was the most
  confusable pair of fields in the Beta 2 dialog.
- **The end park says which X0 Y0 it parks at**, and can now use the machine's rather than the part's.
- **`Home at Job Start` refuses to be silent when it can home nothing.**

## Marlin gained the work-offset table

Beta 2 carried a guard asserting that Marlin had no usable work-offset registers, and refused
multi-WCS jobs there on that basis. **That was wrong.** Marlin implements `G54`–`G59` under the
`CNC_COORDINATE_SYSTEMS` build option — the same `#if` that gates `G53`. The guard is deleted, and
Beta 3 writes each part's origin into the selected register on Marlin as it does elsewhere.

Marlin also gains the machine Z frame, and **every `G53` the post emits there re-selects the work
offset afterwards**, because Marlin's `G53` does not behave as the other two firmwares' does.

The post assumes `CNC_COORDINATE_SYSTEMS` and **warns** rather than refusing — it cannot ask the
controller what it was built with. Marlin claims in this project are read from source at 2.0.9.7 and
2.1.2.5; **2.0.9.7 is the floor**, and nothing below it was read.

## Tool changes

**The post changes no tool, on any firmware.** A measured change needs a probe, a subtraction and a
register to hold the result, and the post has none of the three. Beta 3 makes that explicit and
rebuilds the group around what it *can* do: arrive correctly, hand over, and resume correctly.

- **Both flows are now built** (`PR-15`) — the manual change at a pause, placed in the machine frame,
  and the hand-over to your sender's or firmware's own macro.
- **A multi-tool job is refused by default** rather than posted with its changes quietly dropped.
- **Who corrects Z0 for the new tool's length is now a separate question** from whether to probe
  (`PV-10`). The Beta 2 boolean `Re-probe Z0 After a Change` became the enum `Tool Length Correction
  By`, because "off" was undecidable — it could mean *the tool change applies an offset* or *I will
  re-zero by hand*, and those are different jobs.
- **The first tool is loaded by whoever the job says changes tools** (`PV-13`) — Beta 2 could hand the
  first load to a party the job had not selected.
- **A part this job has already set up is not set up again** (`CR-17`, `PR-23`), and a part is set up
  by the tool that cuts it (`HR-24`).
- The tool-change include files moved out of the include-files group and into the tool-change group,
  where they are used.

## GRBL and FluidNC

- **No `%` wrapper is written any more.** Beta 2 wrapped GRBL output in `%`. Stock Grbl 1.1 has no `%`
  feature, so the line reached the parser and answered `error:1`.
- **Every GRBL file now names the parameter that actually sets travel speed** (`CR-01`). GRBL's
  planner takes a rapid's rate from the axis maximums (`$110`–`$112`), not from the `F` word in the
  block, so the post's *Travel Speed X/Y* and *Travel Speed Z* properties do nothing there — and the
  file says so rather than leaving you to wonder why the machine ignored them.
- **The jog-at-pause modes are offered with their condition stated** (`PR-19`) instead of being denied
  outright. Jogging at a pause and resuming works on GRBL **under a sender that honours the pause**;
  that is a property of the sender, not of GRBL, so the post states the condition rather than guessing.
- A GRBL prompt that ran two clauses together now has its comma (`CR-02`).

## RepRapFirmware

- **`G53` on RRF drops tool offsets**, which is settled and stated (`PR-25`) rather than assumed to
  behave as it does elsewhere.
- **`M7` is named as a build option** rather than assumed present (`CR-24`).
- The hand-over prompt names the tool it is about (`PV-6`).
- End of program: RRF gets `M84 S60` and then `M2`, supported since RRF 3.5.1, which runs your
  `stop.g`.

## Refusals and warnings

**Unsafe jobs are refused before any file is written**, with a message saying what to change. Beta 3
adds or corrects a long list of these:

- **A missing include file is refused before any output is written**, not part-way through a file.
- **A CAM probing operation is refused** — it asks the controller to measure and store an offset,
  which none of these controllers can do. The refusal names a property group that exists (`WR-1`); in
  Beta 2 it named one that did not.
- **A Setup on a tilted face is refused, with the tilt named.** All six rotated Setups in Autodesk's
  own job library are refused (`PV-14`).
- **`>>> WARNING:` now reaches the file even at Comment Level Off** — Beta 2 suppressed the warnings
  along with the commentary, which is exactly backwards.
- **Three arms that established no Z0 now say so** (`PV-3`), and a warning names the flow that
  produced it (`PV-20`) so you can tell which of two paths you are on.
- **A register is no longer rewritten in silence** (`PV-21`).
- **You are told when homing destroyed the zero you jogged to** (`PV-4`) — in the file, where the
  operator running it will see it.
- **A re-probe says so when the datum it touches has already been cut** (`PV-7`).
- **A coolant channel that cannot deliver says so before the job posts** (`PV-12`), and a coolant code
  from another firmware's half of the dropdown is caught before it posts (`PV-16`).
- Warnings stopped losing their parentheses, and one stopped recommending Marlin a remedy Marlin
  refuses.
- **A warning the operator can act on before posting reaches both channels** — Fusion's post dialog
  and the file (`PV-9`).

## Feeds, motion, and the rest of the dialog

- **Axis limits are applied by default**, and the dialog says which of them are conditional.
- **Coolant codes default to the GRBL dialect**, which is the default firmware's — Beta 2 defaulted
  them to Marlin's.
- **Group 3 (Map G1s to Rapids) folded to one enabling control and one field.** It exists for Fusion
  **Personal** licences, which post every rapid as a slow cutting move.
- **A laser power change is emitted once and denied never** (`PV-2`).
- **The Start and Stop include files say that they replace the phase they name**, rather than adding
  to it.
- **A Manual NC optional stop is emitted as an unconditional `M0`** (`HR-13`). No supported firmware
  gives `M1`'s *optional* half a usable meaning.
- **The post reports its own injected moves to the kernel** (`PR-28`), so Fusion's own machining time
  and extents account for them.
- **The dialog stopped refusing a job shape the post supports** (`CR-16`).

## Bugs that would have bitten you

- **The post crashed on the second job of a session** (`PV-1`) — a reference variable had no
  `reset()`, in the first statement of `onOpen()`. It passed `node --check`, a code walk had no way to
  see it, and it stood for four commits until the post was actually *run*.
- **The preamble moved the tool before recording where it was** (`CR-15`).
- **The bit was dragged across the work on the way to an offset probe** — Beta 3 retracts first.
- **`Enforce Feedrate` and the word separator leaked from one post into the next** — a second job in
  the same Fusion session inherited the first job's settings.
- **A modal plane, and a flag, outlived the include file that set them.**

---

## How Beta 3 was checked

Beta 2's fixes were reasoned about; **Beta 3's were run.** The post is driven by Autodesk's own
`post.exe` over their intermediate `.cnc` files, with job files built for the multi-part paths that
library cannot reach, and an in-post hook for the one group no job file can reach at all. The emitted
g-code is then read back and checked against the toolpath the kernel actually delivered, rather than
against a pattern.

`docs/integration.md` is that machinery and, more importantly, **the bounds on what a run may claim.**
The findings register closed 89 rows across the Beta 3 series — 78 fixed, 10 closed by design, 1
withdrawn — and its open section is empty.

## What is not verified

An empty findings register is not a claim that the post is correct. Stated plainly, because no other
document will:

- **No controller was used.** Every firmware claim in this project is settled from that firmware's own
  source and changelog, with file and version cited. Nothing here is proved by having been run on a
  machine.
- **No file has been posted from Fusion itself.** The integration suite drives Autodesk's intermediate
  files, so the one thing it never exercises is an operator's own Setup.
- **The dialog is never exercised** — properties are set programmatically, so how the groups read and
  behave in Fusion's own property panel is unverified.
- **Eighteen properties have only ever been posted at their default.** Their default path runs in every
  case, but no run has posted an *alternative* value for any of them. All eighteen are coolant, laser
  or include-file settings.
- **Three property combinations are unreached** even by the job-file suite: a `Jog to …` mode on a
  return whose Z0 a tool change invalidated, Flow 2 on RepRapFirmware across a WCS change, and a
  manual change position crossed with a WCS traverse.

`docs/findings.md` §7 is the standing list, and `docs/guide-pro.md` says the same thing where an
operator will meet it.

## Where to read more

| | |
|---|---|
| Setting up your first job | `docs/guide-hobbyist.md` |
| Work offsets, the travel height, tool changes, the guards | `docs/guide-pro.md` |
| Every setting, in dialog order | `docs/property-reference.md` |
| Why the post behaves as it does | `docs/design.md` |
| What was found, and what is owed | `docs/findings.md` |
| How the post is run, and what a run may claim | `docs/integration.md` |
