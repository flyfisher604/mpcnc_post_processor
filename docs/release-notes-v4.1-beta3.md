# Release notes — v4.1 Beta 3

Everything that changed since **v4.0 Beta 3**. One thing did: the post can now switch the router, the
laser and each coolant channel through a **fan or a pin output**, and every one of those outputs is
named by a number you set. `git log v4.0_Beta3..` is the changelog; `GH-16a` through `GH-16d` in
`docs/findings.md` are the four register rows this closes, and they carry the firmware evidence.

It answers [issue 16](https://github.com/flyfisher604/mpcnc_post_processor/issues/16), both halves.

---

## Two things to know before your first v4.1 job

### 1. Three settings changed name or shape, so those three fall back to their defaults

| Was | Is |
|---|---|
| *Manual Spindle On/Off* — a checkbox | **Spindle Control** — four modes |
| *Laser: Marlin M42 Pin* | **Laser: Pin/Fan #** — read by both output modes, not just the pin one |
| the four coolant codes, with `M42 P6` / `M42 P11` frozen into their values | one value per form, plus **Channel A / Channel B Pin/Fan #** |

Fusion stores a property by its key, and each of those keys moved — a checkbox's stored `true` is not
an enum id, and a pin number carried into a fan index addresses a fan nobody has. So a saved preset
loses those three and keeps the other sixty-two.

**What it falls back to is what you had.** *Spindle Control* defaults to *Prompt the operator*, which
is what the checkbox shipped doing; all four coolant codes still default to GRBL's `M7`/`M8`/`M9`. **A
job posts the same file it did in v4.0 Beta 3 unless you choose otherwise** — with one exception,
below.

### 2. The post is a new file

The deliverable is **`MPCNC_v4.1_Beta3.cps`**. Fusion identifies a post by its filename, so **remove
`MPCNC_v4.0_Beta3.cps` from the Post Library** rather than leaving it beside this one.

---

## The router

**Spindle Control** replaces the checkbox with four modes:

| Mode | On | Off |
|---|---|---|
| **`Prompt the operator (M0)`** — the default | `M0 (MSG,Turn ON 12000 RPM)` | `M0 (MSG,Turn OFF spindle)` |
| **`Spindle - M3 S{RPM}/M5`** | `M3 S12000` | `M5` |
| **`Fan - M106 P{n} S255/S0`** | `M106 P{n} S255` | `M106 P{n} S0` |
| **`Pin - M42 P{pin} S255/S0`** | `M42 P{pin} S255` | `M42 P{pin} S0` |

The first two are the checkbox's two states, unchanged. The two new ones are for **a router on a
switched output** — a relay on a fan header or a spare pin — which is what a stock Marlin build can
actually operate, `M3`/`M5` being behind `SPINDLE_FEATURE`/`LASER_FEATURE` and a stock build having
neither.

**`S255` is a flag, not a speed.** Both codes clamp or truncate `S` to a byte, and a relay has no
speed and no direction to set. So the RPM the job asks for goes to a comment, and the file says it was
*requested* and not commanded — at the start and at every mid-operation speed change, where the
alternative was a stream of identical on-codes or silence. `M4` is not emitted at all: a relay cannot
reverse.

---

## The laser

**The Marlin fan mode was firing the wrong fan, and stopping a different one.** It emitted `M106` with
no `P`, and Marlin resolves an absent `P` as `_MIN(motion.extruder, FAN_COUNT-1)` — fan 0 on a CNC
build. So a laser wired to any other fan was never fired, while fan 0 was driven at laser power. The
off code was `M107`, which RepRapFirmware applies to the current tool's mapped fans rather than to `P`
at all.

**Now:** `M106 P{n} S{power}` on, `M106 P{n} S0` off, with `{n}` from the new **Laser: Pin/Fan #**.
**`M107` is gone from the post.** `S` is written on every arm, on and off, because a bare `M106 P{n}`
is a *status report* on RepRapFirmware and switches nothing, and RRF's `M42` requires an `S` outright.

**This is the one change that alters an existing job's output.** A Marlin or RepRap laser job in fan
mode gains ` P0` on the on-code, and its `M107` becomes `M106 P0 S0`. If your laser is not on fan 0,
that job was firing the wrong output before — set **Laser: Pin/Fan #** now.

---

## Coolant

The Marlin values in group 9's four dropdowns were `M42 P6 S255` and `M42 P11 S255` — the pin frozen
into the value, with two choices and no way to name a third. Those two numbers are **one board's**: on
RAMPS they are the servo header, `SERVO1_PIN` 6 and `SERVO0_PIN` 11, which is a reasonable place to
drive a relay's signal. On a **Rambo** — the board V1 Engineering shipped for the MPCNC — pin 6 is
`HEATER_2_PIN` and pin 11 is `Y_MIN_PIN`, and Marlin has both in `sensitive_pins.h`, so it answers
`Error: Protected Pin`, the coolant never switches, and nothing in the file says so.

**Now each channel names its own output.** One generic value per form — `Mrln: M106 P{n}` and
`Mrln: M42 P{pin}` — with **Channel A Pin/Fan #** and **Channel B Pin/Fan #** supplying the number,
and a channel's on-code and off-code reading the same field. The GRBL values and *Use custom* are
unchanged, and all four defaults still ship GRBL codes.

That also removes a configuration that could latch an output on: nothing previously stopped *Turn
Channel A On* being `M42 P6` while *Turn Channel A Off* was `M42 P11`, which opens one pin and closes
another. A mismatched **pin** is now unrepresentable, and a mismatched **form** — `M106` on with `M42`
off — is refused.

---

## Pin/Fan # means four different things

One field per group, and what the number *is* depends on the mode and the firmware. Re-check it
whenever you change either.

| | Marlin | RepRapFirmware |
|---|---|---|
| **Fan mode** | a fan index, `0` to `FAN_COUNT-1`, set by which `FANn_PIN` your board defines | a fan number, created by `M950 F<n>` |
| **Pin mode** | a board pin number | a GpOut port number, created by `M950 P<n>` |

**A wrong number is not equally visible on the two firmwares.** Marlin returns silently for a fan
index it does not have — the router never starts and the job cuts with a dead spindle — while
RepRapFirmware answers *"Fan number not found"* or refuses the port.

**Pin mode carries two conditions of its own on Marlin.** `M42` is compiled only where
`DIRECT_PIN_CONTROL` is enabled, which stock Marlin ships commented out; and Marlin refuses `M42` on a
protected pin, a list that includes every `FANn_PIN`. **So a fan header cannot be reached with `M42`
at all** — use fan mode for a fan header, and pin mode for a spare output.

---

## What the post now refuses

Three new refusals, all before any g-code is written:

- **A fan or pin output selected for the spindle or the laser on a GRBL job.** GRBL has neither
  command and answers it with `error:20`, stopping with the tool in the cut. The **coolant** channels
  are deliberately the exception and warn instead: a coolant value's `Mrln:`/`Grbl:` label says which
  firmware the post shipped it for, not that no other firmware takes it.
- **Pin mode with `Pin/Fan #` still 0**, in any of the three groups. Pin 0 names no output anyone wired
  deliberately, and Marlin protects it on most boards. Fan 0 is a real fan and is allowed.
- **A coolant channel switched on with one form and off with the other.**

The existing warning that a coolant code belongs to another firmware's dialect still fires, and now
quotes the setting's *title* — the stored values are no longer g-code lines.

---

## How this was checked

**Seventeen new cases in the integration suite**, which drives Autodesk's own `post.exe` over their
`.cnc` job files and reads the emitted g-code back: `CG22a`–`CG22e` for the laser, `CG32a`–`CG32e` for
the router, `CG24a`–`CG24f` for coolant, and `GS17`. The suite is at **207 cases, all passing**.

Each of the three new refusals is witnessed rather than assumed, and so is the **other** branch of
each guard — a default GRBL job must still post, and `H33` is the control that the coolant arm still
only warns. Two cases assert the ordering the whole design rests on: `setCoolant()` takes both channels
off before switching either on, which is what makes GRBL's `M9` — one code that stops every coolant
output — harmless, and what lets two channels share one number.

**`GS17` exists because three structural invariants had gone quiet.** The checks for *a channel is
turned off again*, *the spindle is running before the first cut* and *the spindle is stopped before the
program ends* read only `M7`/`M8`/`M9` and `M3`/`M4`/`M5`. A job switching either through a fan or a
pin matched none of them, so all three returned `SKIP` — **and a `SKIP` is reported as a pass.** The
spindle hole is one this release opened. All three now read the new forms, and `GS17` is a program that
exercises them.

## What is not verified

- **No controller was used.** Every firmware claim above is settled from that firmware's own source and
  changelog with the file and version cited — Marlin `bugfix-2.1.x` for `M106`, `M107` and `M42` and
  the board pin maps, RepRapFirmware 3.5 for the fan report and `M950`, grbl 1.1 for `error:20`. This
  project has no CNC controller, no sender console and no machine time. **Nothing here is proved by
  having been run on hardware**, and in particular no relay has been switched by this post.
- **The dialog is never exercised.** The suite sets property *values* on the command line, so the new
  fields' titles, order and how they read in Fusion's own property panel are unchecked.
- **Twelve properties have still only ever been posted at their default** — the four include-file
  fields, four laser settings and the four custom coolant files. That is down from eighteen: the
  coolant code properties are now varied by the cases above.
- **No file has been posted from Fusion itself.** The suite drives Autodesk's intermediate files, so
  the one thing it never exercises is an operator's own Setup.

`docs/findings.md` §7 is the standing list of what is owed.

## Where to read more

| | |
|---|---|
| Setting up your first job, and the router | `docs/guide-hobbyist.md` |
| The guards, tool changes, work offsets | `docs/guide-pro.md` |
| Every setting, in dialog order | `docs/property-reference.md` |
| Why the post behaves as it does | `docs/design.md` |
| What was found, and what is owed | `docs/findings.md` |
| How the post is run, and what a run may claim | `docs/integration.md` |
| The previous release | the `v4.0_Beta3` tag, and `git log v4.0_Beta3..` |
