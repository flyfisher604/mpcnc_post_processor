Property reference — every setting in the dialog
====

All **57 properties**, in **10 groups**, in the order the Fusion dialog shows them. **This is the
only copy** — the [hobbyist guide](guide-hobbyist.md) and the [pro guide](guide-pro.md) link here
rather than repeat it, so there is one place for a default to be right or wrong.

> **Every dimension in this dialog is entered in millimetres**, whatever units your Setup posts
> in. The post converts. **Three fields hold an absolute machine coordinate** rather than a
> work-relative one — *Machine Travel Z* in group 4 and the two *Manual Position* fields in
> group 6 — and those are the only numbers here that stop being correct when a Setup is copied to
> another machine.

Which groups apply to you:

| Group | Applies to |
|---|---|
| **1**, **2**, **5** | every job |
| **3** | the Fusion **Personal** licence only |
| **4** | a machine with endstops; **required** for a multi-part or multi-tool job |
| **6** | a job with more than one tool — and it **refuses one by default** |
| **7** | jobs replacing the post's header or footer with your own g-code |
| **8**, **9**, **10** | that hardware only |

Every setting is also dumped into the head of each posted file, under its group heading, followed
by a **Resolved Values** block holding what the post actually computed from them — the resolved
Safe Z height, whether a fixed Z reference exists at all, and *Machine Travel Z* converted into
the file's output units.

---

## 1 - Job

| Title | What it does | Default |
|---|---|---|
| CNC Firmware | Which g-code dialect to write: `Marlin`, `Grbl` or `RepRap`. FluidNC is `Grbl`. Many other settings change meaning with this, so set it first. | **Grbl** |
| Spindle Control | Who switches the router on. `Prompt the operator (M0)`: no spindle code — the post stops and asks. `Spindle - M3 S{RPM}/M5`: commanded, with `S` carrying the RPM. On Marlin this needs `SPINDLE_FEATURE` or `LASER_FEATURE` built in: a stock build answers `M3` with an unknown-command warning and cuts with the spindle stopped, and V1 Engineering's V1CNC builds use `LASER_FEATURE`, which reads `S` as cutter power rather than RPM and has no `M4` reversal. `Fan - M106 P{n}` and `Pin - M42 P{pin}`: a relay on a fan header or spare pin, **on or off only** — the RPM goes to a comment. Neither is GRBL's; a GRBL job using one is refused. | **Prompt the operator (M0)** |
| Spindle: Pin/Fan # | The output number the `Fan` and `Pin` modes use — one of four things, by mode and firmware: a Marlin fan index (`0` to `FAN_COUNT`-1), an RRF fan number (`M950 F<n>`), a Marlin board pin, or an RRF GpOut port (`M950 P<n>`). **The numbering is your board's and the post cannot check it.** A wrong number fails differently on each: Marlin ignores a fan index it does not have, so the router never starts; RRF reports *Fan number not found* or refuses the port. `M42` also needs `DIRECT_PIN_CONTROL`, which stock Marlin ships off, and is refused on any protected pin — every heater, endstop and fan pin — so use `Fan` for a fan header and `Pin` for a spare output. | **0** |
| Comment Level | How much commentary the file carries: `Off`, `Important`, `Info`, `Debug`. `Info` is what puts the property dump in the file. **On GRBL, leave this at `Info` or above** — see the note below. | **Info** |
| Use Arcs | Emit `G2`/`G3` for circular moves instead of many short lines. | **true** |
| Line #s | Put a sequence number on every block: `Off`, `N10 N11 N12 ... step 1`, or `N10 N20 N30 ... step 10`. Numbering always starts at `N10`, and restarts in every file. Pick the step your sender's line-restart convention expects — step 1 to count blocks, step 10 to leave room to insert between them. | **Off** |
| Include Whitespace | Spaces between words. Off produces `G0X0Y0`, which every supported firmware accepts. | **true** |

> **Comment Level is a safety setting on GRBL.** gSender ignores an `M0` in the first ten lines it
> sends — a workaround for CAM that opens its files with a meaningless one — and it comments the
> `M0` out either way, so an early prompt is not postponed, it is **deleted**. At `Info` the
> property dump puts about seventy lines ahead of every prompt in the preamble. The post warns in
> the post dialog when a lower level leaves a real prompt inside that window, and names the
> prompts at risk.

## 2 - Feeds and Speeds

| Title | What it does | Default |
|---|---|---|
| Travel Speed X/Y | Rapid (`G0`) speed in X and Y, mm/min. **Marlin and RepRap obey it; GRBL and FluidNC ignore it** and travel at the axis maximum set in the controller. | **2500** |
| Travel Speed Z | Rapid (`G0`) speed in Z, mm/min. Same firmware split. | **300** |
| Enforce Feedrate | Put an `F` word on every cutting move, even where it has not changed. | **true** |
| Scale Feedrate | Scale cut feeds down to the three limits below. **Off emits Fusion's feeds unchanged and makes those three limits do nothing.** | **true** |
| Max XY Cut Speed | The fastest your machine may cut in X or Y, mm/min. Read only when *Scale Feedrate* is on. | **900** |
| Max Z Cut Speed | The fastest your machine may cut in Z, mm/min — usually much slower than X or Y. Read only when *Scale Feedrate* is on. | **180** |
| Max Toolpath Speed | Cap on speed along the path itself, after per-axis scaling: a diagonal move can stay inside both axis limits and still be too fast. Read only when *Scale Feedrate* is on. | **1000** |

> The three limits ship as generic MPCNC figures. **Set them to your own machine before you rely
> on the scaling** — left below what your machine can really do, they quietly slow every cut.
> Scaling only ever *reduces* a feed.

## 3 - Map G1s to Rapids - disable when using full license

Only relevant on a **Fusion Personal licence**, which emits every rapid as a cutting move. See
[the hobbyist guide](guide-hobbyist.md#if-you-are-on-a-personal-licence). **It ships off**;
turning it on is your call.

| Title | What it does | Default |
|---|---|---|
| Map G1s -> G0 Rapids | Convert `G1`s back to `G0` rapids where it is safe. One switch covering all three moves Personal emits as cuts: horizontal moves at or above *Safe Z*, retracts and descents that stay above it, and each operation's first move. | **false** |

> **The threshold is group 5's *Safe Z*** — this group has no height of its own. Group 5 retracts
> to that height after a probe, so lowering it for one group lowers it for both.

## 4 - Machine Frame - homing, travel Z and end park

Skip this group if your machine has no endstops and your job cuts one part with one tool.
**Anything more needs it:** a multi-part job and most tool-change routes are refused without
*Machine Travel Z*. See [the pro guide](guide-pro.md#the-machine-frame-and-the-travel-height).

| Title | What it does | Default |
|---|---|---|
| Axes Homed and Trusted | **A declaration, not an action** — which axes your machine homes to endstops: `None`, `XY Only`, `Z Only`, `XYZ`. Set once for the machine. Z is required by *Machine Travel Z*; X/Y by a multi-part job and by *At End Park At* = `Machine X0 Y0`. Your cutting Z0 never comes from here. | **None** |
| Machine Travel Z | The height the tool holds while travelling — **an absolute machine coordinate in mm, often negative**. **Empty (default): this job has no fixed Z reference.** Filled: a Z reference that does not move with stock thickness. Needs Z declared homed above. Measure it once — home, jog clear of every clamp, read Z off your sender. | **empty** |
| Home at Job Start | **The action** — whether *this job* homes the axes declared above: `Off`, `Home`, `Pause, then Home`. The pause is one stop before any homing motion, so you can place a movable Z plate or clear the bed. | **Off** |
| At End Park At | Where the tool goes when the job ends: `Off` (stay put), `Work X0 Y0` (the last operation's work origin), `Machine X0 Y0` (the homing corner — needs X/Y declared, and on GRBL/RepRap also needs homing on). | **Work X0 Y0** |

> ***Machine Travel Z* is the whole switch — there is no checkbox beside it.** The job has a fixed
> Z reference when Z is declared homed **and** this field holds a number. It is a text field so
> that *empty* can mean *none*: on a stock GRBL build machine zero is the **top** of travel, so `0`
> is a real height — the one that puts the axis back on its switch. A value the post cannot read
> is treated as empty, and warned about.

## 5 - Part Origins - how each part's X0 Y0 Z0 is established

The group every job uses. See [origin modes in
full](guide-pro.md#origin-modes-in-full), or the
[plain-language version](guide-hobbyist.md#how-the-post-learns-where-your-part-is).

| Title | What it does | Default |
|---|---|---|
| First WCS / Part | How the first (or only) part's origin is set — one of the six modes below. **The default assumes a wired, working touch plate**; without one, choose `Set X0 Y0 Z0 to Current Pos`. | **Set X0 Y0 to Current Pos, Probe Z0** |
| Each New WCS / Part | Multi-part jobs only: how each further part's origin is set **the first time the job reaches it** — one of the four `Use WCS …` and `Jog to …` modes below, after a retract to *Machine Travel Z*. A return to a part already set up sets nothing again: the tool goes to its stored origin and cuts. Only a tool change re-opens that part's Z0. | **Use WCS X0 Y0, Probe Z0 Once per Part** |
| Probe Pause | Prompts to attach and remove the Z probe: `No`, `Before`, `Before & After`. **Applies to every probe in the job**, tool-change re-probes included. | **Before & After** |
| Probe X Y Offset | Distance from the part origin to the probe's touch-point, so the origin can sit at a corner or off the material. **Two numbers in mm separated by a comma** — `30, -15` — either one signed, either one with decimals; whitespace around the comma is ignored. The same for every part. `0, 0` probes at the origin. A value the post cannot read falls back to `0, 0`, and it warns. | **0, 0** |
| Probe with G38.2 | Probe with `G38.2` (on) or `G28` (off). Read on Marlin and RepRap only — GRBL always uses `G38.2`. Turn it **off** for a Marlin build without probe support, and for **RepRapFirmware 3.1.1 and earlier**, where `G38.2` takes a machine-coordinate target and so probes to the wrong height. | **true** |
| G38 Target | **How far down from the tool a probe may search** — a distance, not a height. `-10` searches 10 mm below wherever the tool starts. On the `Use WCS …` modes the probe starts at *Machine Travel Z*, so it must reach the stock from there. A probe that never touches stops the job with an alarm. | **-10** |
| G38 Speed | Probe feedrate, mm/min. Slow is accurate. | **30** |
| Safe Z | A height that clears the work, in the part's work coordinates — measured from the touch-off Z0 at the stock top, never from machine zero. **Read by two groups:** the tool retracts to it after probing, and group 3 treats a Z at or above it as safe air. A plain number in mm, or `Feed:`/`Retract:`/`Clearance:<fallback>` to use that operation's own Fusion level when it defines one. A value the post cannot read falls back to 15 mm, and it warns once for the file. | **Retract:15** |
| Plate Thickness | Your touch plate's thickness in mm, subtracted after the probe touches so Z0 lands on the stock top. **Measure your own** — an error here shifts every cut depth in the job. | **0.8** |

**The origin modes.** *WCS* is the work offset the Setup names, which the post selects — not
whichever offset your sender has active.

| Mode | X0 Y0 from | Z0 from |
|---|---|---|
| `Set X0 Y0 to Current Pos, Probe Z0` — first part only | where the tool stands | a probe of the stock top |
| `Set X0 Y0 Z0 to Current Pos` — first part only | where the tool stands | where the tool stands |
| `Use WCS X0 Y0, Probe Z0` (`… Once per Part` for further parts) | the stored offset | a probe of the stock top |
| `Use WCS X0 Y0 Z0` | the stored offset | the stored offset — nothing is measured |
| `Jog to X0 Y0, Probe Z0` | a jog at a pause | a probe of the stock top |
| `Jog to X0 Y0 Z0` | a jog at a pause | a jog at a pause |

The `Current Pos` modes do not prompt — jog to the origin before starting the file. The `Jog to …`
modes rely on your sender on GRBL and on the machine's panel on Marlin. One part may be set from
several datums on one fixture, each its own work offset; **a flip or a re-clamp is a separate job.**

## 6 - Tool Changes - the post hands over, it changes no tool

**A multi-tool job does not post on the shipped default.** See [the pro
guide](guide-pro.md#tool-changes).

| Title | What it does | Default |
|---|---|---|
| At a Tool Change | What the job does when the tool number changes; the post never changes the tool itself. `Refuse a multi-tool job`: it does not post — split it into one file per tool. `Manual change at a pause`: retract, move to the *Manual Position* if set, stop spindle and coolant, then `M0` for you to swap the tool. **Do not jog at that pause.** `Sender or firmware macro changes it`: the same retract and stops, then the token named below. **Test a macro change in the air first** — the post cannot tell whether anything acts on the token, and an ignored one cuts on with the wrong tool. Both hand-over routes need *Machine Travel Z*; the macro route is not available on Marlin. | **Refuse a multi-tool job** |
| Tool Change Handled By | Who does the change, and so which token is emitted. Read only on the macro route. `gSender`, `CNCjs`, `UGS` — `T` and `M6`, which the sender must be set to intercept, since stock Grbl and grblHAL reject `M6`. CNCjs only pauses, so the change and the re-zero are yours. UGS interception is off until you enable it; then it removes the `M6`, passes the `T` on, moves to a safe height and a change position, waits for you, and can run a tool-length probe. `FluidNC` — `T` and `M6` that **the firmware executes itself**, through the changer declared as `atc:` or the macro named by `m6_macro:` in `config.yaml`. A sender set to strip `M6` removes the token it acts on, a changer needs FluidNC 3.9.0 or later, and with neither key declared the line is accepted and nothing changes. `RepRapFirmware tool table` — `T` alone, with your tools declared by `M563` in `config.g`. `Other` — no token; the file named below is included instead. **Where your sender or changer probes the new tool and applies its length, set *Tool Length Correction By* to `Tool change applies tool offset`.** | **Other — the macro file below** |
| Sender Macro File | A file in the NC output folder emitted in place of a tool-change token. **Required when *Tool Change Handled By* is `Other`.** | **empty** |
| Manual Position X Y | Where the tool goes for a manual change — **absolute machine X and Y in mm, as two numbers separated by a comma**: `-10, -400`. Whitespace around the comma is ignored. Empty: no X/Y move, and the change happens above the last cut. Needs X/Y declared homed and *Machine Travel Z* set. Bringing Y forward is usually what puts the spindle where you can reach it. A value the post cannot read stops the post rather than being taken as empty. | **empty** |
| Manual Position Z | The height the tool holds during a manual change, absolute machine coordinate. Empty: the change happens at *Machine Travel Z*. Fill it only to get a spanner on the collet; below *Machine Travel Z* the post warns. May be filled without X and Y. | **empty** |
| First Tool is Correct | On: the tool in the spindle is the one this job starts with, and nothing is emitted for it. Off: the first tool is loaded **before any origin is recorded or probed**, so Z0 is measured with the tool that will cut — by whatever *At a Tool Change* says. Ignored on the two `Set … to Current Pos` origin modes. | **true** |
| Tool Length Correction By | Who corrects work Z0 for the new tool's length; this machine has no tool-length system, so something must. `GCode reprobes Z0 after change` — the post re-probes at each change, searching down from *Machine Travel Z*, so *G38 Target* must reach the stock from there; no probe is written for tool 0 or a laser. `Tool change applies tool offset` — your sender or macro shifts the whole Z frame, so every stored Z0 stays valid and the post probes nothing. `User re-zeroed Z by hand at pause` — corrects only the part active at that pause. With the first and last, every *other* part's Z0 is marked stale, and re-measured or warned about when the job returns to it. | **GCode reprobes Z0 after change** |
| Tool Change Start | A file of your g-code **added** at the start of each change, before the retract and the stops. It runs where the cut ended, at cutting height, so any move in it is yours to make safe. Ignored unless the job hands over. | **empty** |
| Tool Change End | A file **added** at the end of each change, after the resume and any re-probe. The tool is at *Machine Travel Z* with absolute mode, units and the work offset re-asserted. | **empty** |

## 7 - External Include Files

Each names a file **in the NC output folder**. **Naming any file here makes Fusion ask *"This
post processor might be unsafe…"* — answer Yes; answering No aborts the post.** A file that is
**named but missing** aborts the post; a file that **exists but is empty** replaces its phase with
nothing, and the post says so.

| Title | What it does | Default |
|---|---|---|
| Start GCode File | **Replaces** the whole start phase, modal preamble and all — your file owns `G90`, `G21`/`G20`, and `G94`/`G17` on GRBL or the `M84 S0` stepper-timeout disable on Marlin/RepRap. | **empty** |
| Stop GCode File | **Replaces** the whole stop phase — coolant off, the spindle stop or prompt, the end park, `M84 S60`, `M30`/`M2`. | **empty** |

> The two tool-change include files are **not** here — they live in group 6, because they **add**
> to the hand-over sequence rather than replacing a phase.

## 8 - Laser

Fusion's cutting modes collapse to the three power levels below; a mode the post does not
recognise uses the **Through** power and says so in the file.

**One field names the laser output, and it must match your CNC Firmware.** Each value is labelled
with the dialect it belongs to, and the power scale goes with the label rather than with the job:
the `Grbl:` values drive `S` 0–1000 against `$30`, the `Mrln:` values a 0–255 byte.

| Title | What it does | Default |
|---|---|---|
| Laser: On - Vaporize | Power percentage in vaporize mode. | **100** |
| Laser: On - Through | Power percentage in through mode. | **80** |
| Laser: On - Etch | Power percentage in etch mode. | **40** |
| Laser Output | How the laser or plasma cutter is switched. `Grbl: M4 S{PWM}/M5 dynamic power` scales power with speed so corners are not over-burned; `Grbl: M3 S{PWM}/M5 static power` holds it steady. `Mrln: M106 P{n} S{PWM}/S0`, `Mrln: M3 O{PWM}/M5` and `Mrln: M42 P{pin} S{PWM}` are the Marlin and RepRapFirmware forms. **A `Mrln:` fan or pin value on a GRBL laser job is refused**; any other dialect mismatch warns. **No value emits `M107`** — RepRapFirmware applies that to the current tool's mapped fans rather than to `P`, so the off code is `M106` with `S0`. | **Grbl: M4 S{PWM}/M5 dynamic power** |
| Laser: Pin/Fan # | The output number the `M106` and `M42` values use, for both on and off. Read and checked exactly as *Spindle: Pin/Fan #* in group 1 — a wrong Marlin fan index means the laser never fires. Ignored by the other three values. | **0** |
| Laser: Coolant | Force a coolant for laser operations — an air assist, usually. | **Off** |

> **The default is a GRBL value**, matching the default firmware. On a Marlin or RepRap laser job
> left at the default, the post emits `M4 S…`, which those firmwares either lack or read as a
> 0–255 byte instead of GRBL's 0–1000 — so the power is wrong. The post warns; pick your value once.

## 9 - Coolant

Two independent channels. Each maps a Fusion coolant mode to the g-code that switches it. If a
tool asks for a coolant no channel is configured for, the post warns and names the operations.

**One field per channel names the output, and the off code follows from it**: `M106` and `M42`
close with `S0` on the same output, `M7` and `M8` with `M9`, and `Use custom` with the channel's
*Off Custom* file. `M9` is GRBL's only off code and stops every coolant output at once — harmless,
because the post switches both channels off before switching either on.

**`M106` and `M42` are Marlin and RepRapFirmware codes.** The post emits the code you choose
**without checking** it, so one sent to GRBL stops the job mid-operation with the tool in the cut,
and the post warns.

**`M7` and `M8` work on every firmware — where the firmware has them.** The post warns whenever a
job switches coolant with them:

- **Grbl** — stock Grbl 1.1 has `M7` only when built with `ENABLE_M7`, which ships off, and
  otherwise answers `error:20` and stops the job; `M8` is always there.
- **FluidNC** — never errors, but acts on `M7` or `M8` only where `config.yaml` declares a
  `mist_pin` or `flood_pin`; otherwise the job cuts dry. V1 Engineering's Jackpot 1 configs declare
  both pins; **its Jackpot 2 and Jackpot 3 configs declare neither.**
- **Marlin** — has them only when built with `COOLANT_MIST` (for `M7`) or `COOLANT_FLOOD` (for `M8`)
  and a pin your board defines; otherwise it answers *Unknown command* and the job cuts dry.
- **RepRapFirmware** — runs `/sys/M7.g`, `/sys/M8.g` and `/sys/M9.g` if you have written them, and
  otherwise switches nothing.

For anything else, set the channel's *Output* to **`Use custom`** and put a **filename** — as in
group 7, not g-code — in **both** of that channel's *… Custom* fields. A field left empty emits
nothing for that code, and the post warns.

| Title | What it does | Default |
|---|---|---|
| Channel A Mode | Which Fusion coolant mode switches channel A on. Both channels `Off` means the group does nothing. | **Off** |
| Channel B Mode | The same for channel B — a second, independent output. | **Off** |
| Channel A Output | The code that switches channel A on, and with it the code that switches it off: `Mrln: M106 P{n} S255`, `Mrln: M42 P{pin} S255`, `M7 on, M9 off`, `M8 on, M9 off`, or `Use custom` and the two files below. Which coolant level switches the channel is *Channel A Mode*'s choice, not this field's. The two Marlin forms take their output number from *Channel A Pin/Fan #*. | **M8 on, M9 off** |
| Channel A Pin/Fan # | The output number channel A's two Marlin forms use, for both on and off. Read and checked exactly as *Spindle: Pin/Fan #* in group 1. A number taken from another board's pin map may be protected on yours — 6 and 11 are a servo header on RAMPS but `HEATER_2` and `Y_MIN` on a Rambo — and then the coolant never switches. **The two channels may share one number**: the offs come first, so a shared output is switched off and back on. | **0** |
| Channel B Output | The same for channel B. | **M7 on, M9 off** |
| Channel B Pin/Fan # | The same for channel B. | **0** |
| Channel A On Custom | Filename read when *Channel A Output* is `Use custom`. | **empty** |
| Channel A Off Custom | Filename read when *Channel A Output* is `Use custom`. | **empty** |
| Channel B On Custom | Filename read when *Channel B Output* is `Use custom`. | **empty** |
| Channel B Off Custom | Filename read when *Channel B Output* is `Use custom`. | **empty** |

## 10 - Duet

One command per field — the string is written as a single line. The defaults are the RRF 3.x
forms.

| Title | What it does | Default |
|---|---|---|
| Milling Mode | The command that puts a Duet into CNC mode, written on the first section and again at every section-type change. RRF 3.x: `M453` alone — the spindle is created in `config.g` with `M950`/`M563`. RRF 2.05 takes `M453 P<pin> I<0\|1> R<max rpm> F<freq>`. | **M453** |
| Laser Mode | The command that puts a Duet into laser mode. **RRF 3.x needs the laser pin named here** — `M452 C"<pin>" R<max power> F<freq>` — and assigns no pin at all without it, which means the laser never fires. RRF 2.05 uses `P<pin> I<0\|1>` in place of the `C`. | **M452 R255 F200** |

---

← [Hobbyist guide](guide-hobbyist.md) · [Pro guide](guide-pro.md) · [README](../README.md)
