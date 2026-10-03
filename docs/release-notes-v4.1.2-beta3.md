# Release notes — v4.1.2 Beta 3

v4.1.2 Beta 3 is a correction release. It fixes one bug that wrote wrong g-code: after a tool
change, the spindle could stay stopped for the next tool. It also corrects a coolant warning that
told Marlin and RepRap operators the wrong thing, and makes *Safe Z* refuse a value it cannot read
instead of quietly replacing it. No capability was added or removed, and **no property key moved,
so your saved settings carry over.**

Everything here changed since **v4.1.1 Beta 3**. `git log v4.1.1_Beta3..v4.1.2_Beta3` is the
changelog. The register rows this release closes are `RV-01` to `RV-18` and `MR-1`, `MR-2` in
`docs/findings.md`, and they carry the reasoning and the firmware citations.

**Coming from an earlier release?** Read the [changelog](../CHANGELOG.md) entry for each release
you skipped. v4.1.1 Beta 3 reset four settings, and its notes are kept at
[its tag](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/release-notes-v4.1.1-beta3.md).

- [The spindle restarts after every tool change](#the-spindle-restarts-after-every-tool-change)
- [M7 and M8 coolant on Marlin and RepRap](#m7-and-m8-coolant-on-marlin-and-reprap)
- [Safe Z](#safe-z)
- [Smaller corrections](#smaller-corrections)
- [Before your first v4.1.2 job](#before-your-first-v412-job)
- [What stands behind this](#what-stands-behind-this)
- [What is not verified](#what-is-not-verified)

---

## The spindle restarts after every tool change

**This is the one change that alters the g-code a job emits, and it matters if group 6 is set to
anything but *Refuse a multi-tool job*.** The shipped default refuses multi-tool jobs, so a job
posted on the defaults was never affected.

**What went wrong.** At a tool change the post stops the spindle, so you can change the tool. But
it kept a record of the speed and direction it had last commanded. If the next tool asked for the
same speed and direction, the post thought the spindle was already running and started nothing:

- with *Spindle Control* at `Spindle - M3 S{RPM}/M5`, no `M3` — the new tool went into the cut on
  a stopped spindle;
- with *Prompt the operator (M0)*, no *Turn ON* prompt — nothing reminded you to switch the router
  back on;
- with the `Fan` or `Pin` modes, no `M106` or `M42` — the relay stayed off.

It happened on both tool-change routes (*Manual change at a pause* and *Sender or firmware macro
changes it*), and also where a laser operation sits between two milling operations at one speed.

**What changed.** Every stop is now seen by the next start, whichever part of the post made the
stop. After any tool change the spindle is started again — or you are prompted to start it — before
the next cut.

---

## M7 and M8 coolant on Marlin and RepRap

The coolant values `M7` and `M8` were labelled `Grbl: M7 (mist)` and `Grbl: M8 (flood)`. So a
Marlin or RepRapFirmware job using them was warned that its codes belonged to another firmware and
would stop the job mid-cut. **That was wrong:** all three firmwares take them.

- **Marlin** runs `M7` under `COOLANT_MIST` and `M8` under `COOLANT_FLOOD`
  (`Marlin/src/gcode/control/M7-M9.cpp`, `bugfix-2.1.x`). A build without them answers
  *Unknown command* and carries on — it does not stop.
- **RepRapFirmware** runs `/sys/M7.g`, `/sys/M8.g` and `/sys/M9.g` where you have written them
  (`src/GCodes/GCodes2.cpp`, 3.5-dev).

The values now read **`M7 on, M9 off`** and **`M8 on, M9 off`**, with no firmware label. Each
firmware is warned about **its own** condition instead — the post cannot read any of them:

| Firmware | What has to be true | Otherwise |
|---|---|---|
| Grbl | `M7` needs `ENABLE_M7`, which ships off; `M8` is always there | `M7` answers `error:20` and stops the job |
| FluidNC | a `mist_pin` or `flood_pin` declared in `config.yaml` | the job cuts dry |
| Marlin | `COOLANT_MIST` / `COOLANT_FLOOD` and a pin your board defines | the job cuts dry |
| RepRapFirmware | the `/sys/M7.g`–`M9.g` macros on the board | the job cuts dry |

The value ids did not change, so a channel set to `M7` or `M8` keeps its setting.

---

## Safe Z

*Safe Z* now reads what an operator types:

| You type | Before | Now |
|---|---|---|
| ` 15` (a leading space) | replaced by 15 mm | 15 mm |
| `.5` | replaced by 15 mm | 0.5 mm |
| `Retract: 5` (a space after the colon) | replaced by 15 mm | the retract level, or 5 mm |

**A value the post still cannot read is now refused**, with a message saying what it accepts. That
covers a sign (`-5`), a unit suffix (`15mm`) and a level with no number (`Retract:`). Earlier
releases used a fixed 15 mm instead and warned. But *Safe Z* is both the retract after a probe and
group 3's rapid threshold, and no fixed height is right both over tall stock and under a short Z
travel. So a guess is no longer made for you.

---

## Smaller corrections

- **Messages quote the dialog exactly.** 143 places where a message named a dialog field now read
  the field's title from the post itself. Four messages quoted value titles that had changed, and
  seven said "group *n*" without naming it; all eleven now match what the dialog shows.
- **Shorter tooltips.** The ten longest tooltips, up to 1,484 characters, now say what the field
  does and the one thing that matters, in about 300. The detail moved into the
  [property reference](property-reference.md), so nothing was lost.
- **Smaller files at the default Comment Level.** At `Info` the post wrote a comment for every
  internal movement and command id Fusion raised — about 7% of a small file, and read by nothing.
  That trace now appears only at `Debug`. The g-code itself is unchanged.
- **One warning stopped overstating.** Where a job has no Z reference, the first part's warning
  said homing had set the tool's height — even when a *Start GCode File* ran after homing and could
  have moved it. It now says so only when neither a *Start GCode File* nor a tool-change macro has
  run since homing.
- **Two internal guards.** Switching a laser on or off through an output the post does not
  recognise now stops the post with an error, where before it emitted nothing. And the feed limiter
  checks for a zero-length move before scaling it.
- **The source reads better.** Every comment in the post was checked against the code; 38 that
  described something the code does not do were corrected, and the rest were made shorter and
  plainer. The file opens with a key to its comment markers. None of this changes the g-code.

---

## Before your first v4.1.2 job

**1. Delete your old copy of the post first.** The file is `MPCNC_v4.1.2_Beta3.cps`, so it installs
beside v4.1.1 Beta 3 rather than replacing it.

**2. Your settings carry over.** No property key or value id changed. Two coolant values have new
titles (`M7 on, M9 off`, `M8 on, M9 off`), and keep their meaning.

**3. If you changed *Safe Z*, post once and read the dialog.** A value earlier releases replaced
with 15 mm now refuses the post. The message says what to type.

**4. If you hand over tool changes, read your next file.** After every change there should be a
spindle start — or a *Turn ON* prompt — before the first cut.

---

## What stands behind this

The regression suite is at **228 cases across six matrices, all passing**, up from 222. The new
cases are the ones that would have caught these bugs:

- **GS18** runs a two-tool job at one speed under `M3`, and **GS19** a laser between two milling
  operations at one speed. A new check asks for a spindle start between every stop and the next
  milling cut. Both fail against v4.1.1.
- **H42** and **H43**, with **H33** and **H34** re-asserted, cover `M7`/`M8` on each firmware,
  with its own warning and no dialect warning.
- **PRO53** runs a *Start GCode File* between homing and the probe, and checks the first part's
  warning no longer says homing set the height.
- **PRO30** now expects a bad *Safe Z* to be refused, and **PRO30a** posts `" Retract: .5 "` and reads
  it correctly.

Property coverage: 47 of 57 properties are varied by at least one case, and 70 of 91 enum values
are reached.

## What is not verified

- **No controller was used.** Firmware behaviour is settled by reading each firmware's own source
  and changelog, citing file and version — grbl 1.1h, FluidNC 3.9, Marlin `bugfix-2.1.x`,
  RepRapFirmware 3.5. This project has no CNC controller, no sender console and no machine time.
- **The Fusion dialog itself is never exercised.** The suite drives Autodesk's own post engine over
  their job files and sets properties on the command line. How the new tooltips and value titles
  read in the property panel is not checked by any run.
- **No file has been posted from Fusion itself.** None of the suite's job files is an operator's
  own Setup.

`docs/findings.md` §7 is the standing list of what is owed.

## Where to read more

| | |
|---|---|
| Setting up your first job | [Hobbyist guide](guide-hobbyist.md) |
| The guards, tool changes, work offsets | [Pro guide](guide-pro.md) |
| Every setting, in dialog order | [Property reference](property-reference.md) |
| Every release | [Changelog](../CHANGELOG.md) |
| Why the post behaves as it does | `docs/design.md` |
| What was found, and what is owed | `docs/findings.md` |
| How the post is run, and what a run may claim | `docs/integration.md` |
