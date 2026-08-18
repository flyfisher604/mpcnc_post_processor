Property reference — every setting in the dialog
====

All **62 properties**, in **10 groups**, in the order the Fusion dialog shows them. **This is the
only copy** — the [hobbyist guide](guide-hobbyist.md) and the [pro guide](guide-pro.md) link here
rather than repeat it, so there is one place for a default to be right or wrong.

> **Every dimension in this dialog is entered in millimetres**, whatever units your Setup posts
> in. The post converts. **Two fields hold an absolute machine coordinate** rather than a
> work-relative one — *Machine Travel Z* in group 4 and the three *Manual Position* fields in
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
Safe Z heights, whether a fixed Z reference exists at all, and *Machine Travel Z* converted into
the file's output units.

---

## 1 - Job

| Title | What it does | Default |
|---|---|---|
| CNC Firmware | Which g-code dialect to write: `Marlin`, `Grbl` or `RepRap`. FluidNC is `Grbl`. Many other settings change meaning with this, so set it first. | **Grbl** |
| Manual Spindle On/Off | On: the post **prompts** you to start, change and stop the router by hand and emits no `M3`/`M5`. Off: it **commands** the spindle. On Marlin those codes are a build option — a stock build has neither `SPINDLE_FEATURE` nor `LASER_FEATURE`, answers `M3` with an unknown-command warning, and runs the whole job with the spindle never started. | **true** |
| Comment Level | How much commentary the file carries: `Off`, `Important`, `Info`, `Debug`. `Info` is what puts the property dump in the file. **On GRBL, leave this at `Info` or above** — see the note below. | **Info** |
| Use Arcs | Emit `G2`/`G3` for circular moves instead of many short lines. | **true** |
| Enable Line #s | Put a sequence number on every line. | **false** |
| First Line # | The first sequence number. | **10** |
| Line # Increment | How much each sequence number rises. | **1** |
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
| Map G1s -> G0 Rapids | Convert `G1`s back to `G0` rapids where it is safe. One switch covering all three moves Personal emits as cuts: horizontal moves at or above *Safe Z to Rapid*, retracts and descents that stay above it, and each operation's first move. | **false** |
| Safe Z to Rapid | The threshold. Z at or above this is treated as safe air. **In the part's work coordinates** — measured from the touch-off Z0 at the stock top, never from machine zero. A plain number in mm, or `Feed:`/`Retract:`/`Clearance:<fallback>` to use that operation's own Fusion level when it defines one. | **Retract:15** |

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

> ***Machine Travel Z* is the whole opt-in — there is no enum and no checkbox beside it.** The
> frame exists when the machine declares Z homed **and** this field parses, and not otherwise.
> That is why it is a text field: *empty* is what says *no frame*, and no number could mean it —
> on a stock GRBL build machine zero is the **top** of travel and every reachable Z is negative,
> so `0` is a real height (and one that returns the axis onto the switch). A value the post cannot
> read as a signed decimal is read as **empty**, and warned about.

## 5 - Part Origins - how each part's X0 Y0 Z0 is established

The group every job uses. See [origin modes in
full](guide-pro.md#origin-modes-in-full), or the
[plain-language version](guide-hobbyist.md#how-the-post-learns-where-your-part-is).

| Title | What it does | Default |
|---|---|---|
| First WCS / Part | How the origin for the first (or only) part is established — six modes. **The default assumes a wired, working touch plate**; without one choose `Set X0 Y0 Z0 to Current Pos`. **The two `Jog to …` modes depend on your sender on GRBL and on the machine panel on Marlin.** | **Set X0 Y0 to Current Pos, Probe Z0** |
| Each New WCS / Part | Multi-part only: how each part's origin is set **the first time the job reaches it**. Four modes. Every one retracts to *Machine Travel Z* first. A return to a part already set up sets nothing again. | **Use WCS X0 Y0, Probe Z0 Once per Part** |
| Probe Pause | Prompts to attach and remove the Z probe: `No`, `Before`, `Before & After`. **Applies to every probe in the job**, tool-change re-probes included. | **Before & After** |
| Probe X Offset | X distance from the part origin to the probe's touch-point, in whole mm — so the origin can sit at a corner or off the material. The same for every part. `0` probes at the origin. | **0** |
| Probe Y Offset | The same in Y. | **0** |
| Probe with G38.2 | Probe with `G38.2` (on) or `G28` (off). Read on Marlin and RepRap only — GRBL always uses `G38.2`. Turn it **off** for a Marlin build without probe support, and for **RepRapFirmware 3.1.1 and earlier**, where `G38.2` takes a machine-coordinate target and so probes to the wrong height. | **true** |
| G38 Target | **How far down from the tool a probe may search** — a distance, not a height. `-10` searches 10 mm below wherever the tool starts. On the `Use WCS …` modes the probe starts at *Machine Travel Z*, so it must reach the stock from there. A probe that never touches stops the job with an alarm. | **-10** |
| G38 Speed | Probe feedrate, mm/min. Slow is accurate. | **30** |
| Safe Z | The height the tool retracts to after probing, in the part's work coordinates. Same syntax as *Safe Z to Rapid*. | **Retract:15** |
| Plate Thickness | Your touch plate's thickness in mm, subtracted after the probe touches so Z0 lands on the stock top. **Measure your own** — an error here shifts every cut depth in the job. | **0.8** |

## 6 - Tool Changes - the post hands over, it changes no tool

**A multi-tool job does not post on the shipped default.** See [the pro
guide](guide-pro.md#tool-changes).

| Title | What it does | Default |
|---|---|---|
| At a Tool Change | What the job does when the tool number changes. `Refuse a multi-tool job`: it does not post — split it into one file per tool. `Manual change at a pause`: retract, move to the *Manual Position* if set, stop spindle and coolant, then `M0` for you to swap the tool. `Sender or firmware macro changes it`: the same retract and stops, then the token named below. **Both hand-over routes need *Machine Travel Z*, and the macro route is not available on Marlin.** | **Refuse a multi-tool job** |
| Tool Change Handled By | Who does the change, and so which token is emitted. `gSender`, `CNCjs`, `UGS` — `T` and `M6`, which the sender must be configured to intercept, GRBL itself rejecting `M6`. `RepRapFirmware tool table` — `T` alone, needing your tools declared with `M563` in `config.g`. `Other` — no token; the file named below is included instead. Read only on the macro route. | **Other — the macro file below** |
| Sender Macro File | A file in the NC output folder emitted in place of a tool-change token. **Required when *Tool Change Handled By* is `Other`.** | **empty** |
| Manual Position X | Where the tool goes in X for a manual change — **an absolute machine coordinate in mm**. Empty: no X/Y move, and the change happens above the last cut. **Fill both X and Y or neither.** Needs X/Y declared homed and *Machine Travel Z* set. | **empty** |
| Manual Position Y | The same in Y. Bringing Y forward is usually what puts the spindle where you can reach it. | **empty** |
| Manual Position Z | The height the tool holds during a manual change, absolute machine coordinate. Empty: the change happens at *Machine Travel Z*. Fill it only to get a spanner on the collet; below *Machine Travel Z* the post warns. May be filled without X and Y. | **empty** |
| First Tool is Correct | On: the tool in the spindle is the one this job starts with, and nothing is emitted for it. Off: the first tool is loaded **before any origin is recorded or probed**, so Z0 is measured with the tool that will cut — by whatever *At a Tool Change* says. Ignored on the two `Set … to Current Pos` origin modes. | **true** |
| Tool Length Correction By | Who corrects work Z0 for the new tool's length; this machine has no tool-length system, so something must. `GCode reprobes Z0 after change` — this post re-probes, and marks every *other* part's Z0 stale. `Tool change applies tool offset` — your sender or macro shifts the whole Z frame, so every stored Z0 stays valid and the post probes nothing. `User re-zeroed Z by hand at pause` — corrects the part active at that pause and no other. | **GCode reprobes Z0 after change** |
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

**CNC Firmware** decides whether the GRBL or the Marlin/RepRap control mode is used. Fusion's
cutting modes collapse to three power levels below; a mode the post does not recognise uses the
**Through** power and says so in the file.

| Title | What it does | Default |
|---|---|---|
| Laser: On - Vaporize | Power percentage in vaporize mode. | **100** |
| Laser: On - Through | Power percentage in through mode. | **80** |
| Laser: On - Etch | Power percentage in etch mode. | **40** |
| Laser: Marlin/Reprap Mode | `Fan` (`M106`/`M107`), `Spindle` (`M3`/`M5`) or `Pin` (`M42`). | **Fan — M106 S{PWM}/M107** |
| Laser: Marlin M42 Pin | The pin number, read only in `Pin` mode. | **4** |
| Laser: GRBL Mode | `M4` dynamic power, which scales with speed so corners are not over-burned, or `M3` static. | **M4 dynamic** |
| Laser: Coolant | Force a coolant for laser operations — an air assist, usually. | **Off** |

## 9 - Coolant

Two independent channels. Each maps a Fusion coolant mode to the g-code that switches it. If a
tool asks for a coolant no channel is configured for, the post warns and names the operations.

**The On/Off codes must match your CNC Firmware.** The `Grbl:` options (`M7` mist, `M8` flood,
`M9` off) and the `Mrln:` options (`M42` pin writes) are not interchangeable, and the post emits
whichever you choose **verbatim, without checking** — so a Marlin code on GRBL stops the job
mid-operation with the tool in the cut. The post warns when a code you chose is labelled for
another firmware. The defaults are the Grbl codes, matching the default firmware.

> **On GRBL neither code is guaranteed even when it matches.** Stock Grbl 1.1 compiles `M7` only
> when `ENABLE_M7` is uncommented in `grbl/config.h`, which ships commented out — on such a build
> `M7` answers `error:20` and stops the job; `M8` is always compiled in. FluidNC never errors: it
> acts on `M7` only where `config.yaml` declares a `mist_pin` and on `M8` only where it declares a
> `flood_pin`, and otherwise accepts the line and does nothing — so the job cuts dry. V1
> Engineering's Jackpot 1 configs declare both pins; its **Jackpot 2 and Jackpot 3 configs ship
> `NO_PIN` for both.** The post warns whenever a job switches coolant with these codes.

For anything the built-in options do not cover, set the On (or Off) field to **`Use custom`** and
put the **name of a file** in the matching *… Custom* field — a filename, as in group 7, not a
block of g-code. Left empty, nothing is emitted for that code and the post warns.

| Title | What it does | Default |
|---|---|---|
| Channel A Mode | Which Fusion coolant mode switches channel A on. Both channels `Off` means the group does nothing. | **Off** |
| Channel B Mode | The same for channel B — a second, independent output. | **Off** |
| Turn Channel A On | The g-code that switches channel A on. | **Grbl: M8 (flood)** |
| Turn Channel A Off | The g-code that switches channel A off. **On GRBL, `M9` is the only off code and it stops every coolant output at once.** | **Grbl: M9 (off)** |
| Turn Channel B On | The g-code that switches channel B on. | **Grbl: M7 (mist)** |
| Turn Channel B Off | The g-code that switches channel B off. | **Grbl: M9 (off)** |
| Channel A On Custom | Filename read when *Turn Channel A On* is `Use custom`. | **empty** |
| Channel A Off Custom | Filename read when *Turn Channel A Off* is `Use custom`. | **empty** |
| Channel B On Custom | Filename read when *Turn Channel B On* is `Use custom`. | **empty** |
| Channel B Off Custom | Filename read when *Turn Channel B Off* is `Use custom`. | **empty** |

## 10 - Duet

One command per field — the string is written as a single line. The defaults are the RRF 3.x
forms.

| Title | What it does | Default |
|---|---|---|
| Milling Mode | The command that puts a Duet into CNC mode, written on the first section and again at every section-type change. RRF 3.x: `M453` alone — the spindle is created in `config.g` with `M950`/`M563`. RRF 2.05 takes `M453 P<pin> I<0\|1> R<max rpm> F<freq>`. | **M453** |
| Laser Mode | The command that puts a Duet into laser mode. **RRF 3.x needs the laser pin named here** — `M452 C"<pin>" R<max power> F<freq>` — and assigns no pin at all without it, which means the laser never fires. RRF 2.05 uses `P<pin> I<0\|1>` in place of the `C`. | **M452 R255 F200** |

---

← [Hobbyist guide](guide-hobbyist.md) · [Pro guide](guide-pro.md) · [README](../README.md)
