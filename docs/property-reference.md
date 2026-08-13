Property reference — every setting in the dialog
====

All **69 properties**, in the order the Fusion dialog shows them. **This is the only copy** —
the [hobbyist guide](guide-hobbyist.md) and the [pro guide](guide-pro.md) link here rather than
repeat it, so there is one place for a default to be right or wrong.

> **Every dimension in this dialog is entered in millimetres**, whatever units your Setup posts
> in. The post converts. The one exception to watch is **Inter Part Travel Z** under the
> *Machine Z* answer, which is an absolute machine coordinate — see group 5.

Groups **4** and **5** apply only to jobs with more than one part; a single-part job can leave
both alone. Group **3** applies only to the Fusion Personal licence. Everything else applies to
every job.

---

## 1 - Job

| Title | What it does | Default |
|---|---|---|
| CNC Firmware | Which g-code dialect to write: Marlin, Grbl or RepRap. Several other settings change meaning with this, so set it first. | **Grbl** |
| Manual Spindle On/Off | On: the post **prompts** you to start, change and stop the router by hand and emits no `M3`/`M5`. Off: it **commands** the spindle. | **true** |
| Comment Level | How much commentary the file carries: Off, Important, Info, Debug. | **Info** |
| Use Arcs | Emit `G2`/`G3` for circular moves instead of many short lines. | **true** |
| Enable Line #s | Put a sequence number on every line. | **false** |
| First Line # | The first sequence number. | **10** |
| Line # Increment | How much each sequence number rises. | **1** |
| Include Whitespace | Spaces between words. Off produces `G0X0Y0`, which every supported firmware accepts. | **true** |

## 2 - Feeds and Speeds

| Title | What it does | Default |
|---|---|---|
| Travel Speed X/Y | Rapid (`G0`) speed in X and Y, mm/min. | **2500** |
| Travel Speed Z | Rapid (`G0`) speed in Z, mm/min. | **300** |
| Enforce Feedrate | Put an `F` word on every move, even when it has not changed. | **true** |
| Scale Feedrate | Scale cut feeds down so no axis exceeds its limit below. **Off makes the three limits below do nothing.** | **true** |
| Max XY Cut Speed | The fastest your machine may cut in X or Y, mm/min. Only applied when *Scale Feedrate* is on. | **900** |
| Max Z Cut Speed | The fastest your machine may cut in Z, mm/min. Only applied when *Scale Feedrate* is on. | **180** |
| Max Toolpath Speed | Cap on the speed along the path itself, after per-axis scaling. Only applied when *Scale Feedrate* is on. | **1000** |

> The three limits ship as generic MPCNC figures. **Set them to your own machine before you rely
> on the scaling** — left below what your machine can really do, they quietly slow every cut.

## 3 - Map G1s to Rapids - disable when using full license

Only relevant on a **Fusion Personal licence**, which emits every rapid as a cutting move. See
[the hobbyist guide](guide-hobbyist.md#if-you-are-on-a-personal-licence). **All four ship off**;
turning them on is your call.

| Title | What it does | Default |
|---|---|---|
| First G1 → G0 Rapid | Convert the first `G1` of a toolpath back to a rapid — the "tool dragged across the work" move. | **false** |
| Map: G1s → G0 Rapids | Convert horizontal `G1` moves at or above the threshold below back to rapids. | **false** |
| Map: Safe Z to Rapid | The threshold. A plain number in mm, or `Feed:`/`Retract:`/`Clearance:<fallback>` to use that operation's own Fusion height when it defines one. | **Retract:15** |
| Map: Allow Rapid Z | Also convert safe vertical moves. | **false** |

## 4 - Machine Frame - homing and end park

Skip this group unless your machine has endstops, or you want the tool to park somewhere
specific at the end. See [the pro guide](guide-pro.md#the-machine-frame-homing).

| Title | What it does | Default |
|---|---|---|
| Axes Homed and Trusted | **A declaration, not an action** — which axes your machine homes to endstops: `None`, `XY Only`, `Z Only`, `XYZ`. Set once for the machine. | **None** |
| Home at Job Start | **The action** — whether *this job* homes: `Off`, `Home`, `Pause, then Home`. The pause is one stop before any homing motion, so you can place a movable Z plate or clear the bed. | **Off** |
| At End Park At | Where the tool goes when the job ends: `Off` (stay put), `Work X0 Y0` (the last operation's WCS origin), `Machine X0 Y0` (the homing corner — needs X/Y declared, and on GRBL/RepRap also needs homing on). | **Work X0 Y0** |

## 5 - Fixed Z Reference - multi-part jobs only

A **single-part job needs none of this** — leave *Fixed Z Reference* at `None` and skip the
group. See [the pro guide](guide-pro.md#a-fixed-z-reference).

| Title | What it does | Default |
|---|---|---|
| Fixed Z Reference | The frame whose Z0 does not move with stock thickness — the only one in which a single clearance height works across parts of different thickness. `None`, `Spoilboard` (probe it into a reserved WCS), `Machine Z` (use the homed machine frame). | **None** |
| Reserved WCS | Which WCS to reserve for the spoilboard base. `G59` recommended; `G59.1`–`G59.3` are RepRap only. Sub-question of the `Spoilboard` answer. | **None** |
| Probe to Set Base | How the base's Z is established: `Probe Z`, or `Pause, Probe Z, Pause` for the manual touch-off. Sub-question of the `Spoilboard` answer. | **Pause, Probe Z, Pause** |
| Retract Across Parts | Lift to the clearance below before traversing between parts on different WCS. | **true** |
| Inter Part Travel Z | The travel height, mm. **Which frame it is measured in is decided by *Fixed Z Reference* above**, so re-read it whenever that changes. **Ships empty on purpose** — a height carried over from the other frame is a valid-looking number in the wrong frame, so the post refuses to post rather than guess. | **empty** |

## 6 - On WCS / Part / Fixture Changes

The group every job uses. See [origin modes](guide-hobbyist.md#how-the-post-learns-where-your-part-is).

| Title | What it does | Default |
|---|---|---|
| First WCS / Part | How the origin for the first (or only) part is established — six modes. **The default assumes a wired, working touch plate**; without one choose `Set X0 Y0 Z0 to Current Pos`. **The two `Jog to …` modes do not work on GRBL.** | **Set X0 Y0 to Current Pos, Probe Z0** |
| Subsequent WCS / Part | Multi-part only — what happens at each added part's WCS. Four modes; not supported on Marlin. | **Use Active WCS X0 Y0, Probe Z0** |
| Probe Pause | Prompts around each part probe: `No`, `Before`, `Before & After` (attach, then detach). | **Before & After** |
| Probe X Offset | Shift the Z touch-point away from the part origin in X, whole mm — so the origin can sit at a corner or off the material. Never applies to the spoilboard base probe. | **0** |
| Probe Y Offset | The same in Y. | **0** |
| Probe with G38.2 | Probe with `G38.2` (on) or `G28` (off). Read on Marlin and RepRap only — GRBL always uses `G38.2`. On RepRap up to 3.1.1, **off is safer**. | **true** |
| G38 Target | How far the probe may travel before giving up — a **Z position** in the part's frame, not a distance. A probe that reaches it without touching is a failed probe, and GRBL alarms. | **-10** |
| G38 Speed | Probe feedrate, mm/min. | **30** |
| Safe Z | The height the tool retracts to after probing. Same syntax as *Map: Safe Z to Rapid*. | **Retract:15** |
| Plate Thickness | Your touch plate's thickness in mm, subtracted so Z0 lands on the stock top. **Measure your own.** | **0.8** |

## 7 - Tool Changes

Off by default. With more than one tool in the job and this group off, the post warns and marks
each suppressed change in the file. See [the pro guide](guide-pro.md#tool-changes).

| Title | What it does | Default |
|---|---|---|
| Tool Changes are Included | Emit tool-change code at all. Nothing else in this group does anything while it is off. | **false** |
| Include Relocation Code | Move to the change position below; off emits a plain change. | **false** |
| Tool Change X | Change position X, in the **active WCS** (plain `G0`, not machine coordinates). | **0** |
| Tool Change Y | Change position Y, same frame. | **0** |
| Tool Change Z | Change position Z, same frame. | **40** |
| Disable Z Stepper | Release the Z stepper once at the change position. | **false** |
| Do First Change | Do a change before the first operation, to load the first tool. | **false** |
| Probe After Tool Change | Re-probe Z after each change. **This is the tool-length substitute** — there is no TLO. | **false** |

## 8 - External Include Files

Each names a file **in the NC output folder**. **Naming any file here makes Fusion ask *"This
post processor might be unsafe…"* — answer Yes; answering No aborts the post.**

| Title | What it does | Default |
|---|---|---|
| Start GCode File | **Replaces** the whole start phase, modal preamble and all — your file owns `G90`, `G21`/`G20`, `G94`/`G17` (GRBL) or `M84 S0` (Marlin/RepRap). | **empty** |
| Stop GCode File | **Replaces** the whole stop phase — coolant off, the spindle prompt, the end park, `M84 S60`, `M30`/`M2`. | **empty** |
| Tool Change Start | **Added** to the start of each tool change, not a replacement. | **empty** |
| Tool Change End | **Added** to the end of each tool change. | **empty** |
| Tool Change Probe | **NOT IMPLEMENTED.** Reserved; anything entered is ignored. | **empty** |

## 9 - Laser

Fusion's four Through levels all map to *On - Through*. **CNC Firmware** decides whether the
GRBL or the Marlin/RepRap mode is used.

| Title | What it does | Default |
|---|---|---|
| Laser: On - Vaporize / Through / Etch | Power percentage per cutting mode. | **100 / 80 / 40** |
| Laser: Marlin/Reprap Mode | Fan (`M106`/`M107`), Spindle (`M3`/`M5`) or Pin (`M42`). | **Fan** |
| Laser: Marlin M42 Pin | The pin number for Pin mode. | **4** |
| Laser: GRBL Mode | `M4` dynamic power or `M3` static. | **M4 dynamic** |
| Laser: Coolant | Force a coolant for laser operations, e.g. air assist. | **Off** |

## 10 - Coolant

Two independent channels. Each maps a Fusion coolant mode to the g-code that switches it. If a
tool asks for a coolant no channel is configured for, the post warns.

**The On/Off codes must match your CNC Firmware.** The `Grbl:` options (`M7` mist, `M8` flood,
`M9` off) and the `Mrln:` options (`M42` pin writes) are not interchangeable, and the post emits
whichever you choose **verbatim, without checking**. The defaults are the Grbl codes, matching
the default firmware.

For anything the built-in options do not cover, set the On (or Off) field to **`Use custom`** and
put the **name of a file** in the matching *… Custom* field — a filename, as in group 8, not a
block of g-code.

| Title | What it does | Default |
|---|---|---|
| Channel A Mode / Channel B Mode | Which Fusion coolant mode switches this channel on. Both off means the group does nothing. | **Off** |
| Turn Channel A On / Off | The g-code for channel A. | **M8** / **M9** |
| Turn Channel B On / Off | The g-code for channel B. | **M7** / **M9** |
| Channel A/B On/Off Custom | Filename used when the matching field is `Use custom`. | **empty** |

## 11 - Duet

| Title | What it does | Default |
|---|---|---|
| Milling Mode | The command that puts a Duet3D into milling mode. | **M453 P2 I0 R30000 F200** |
| Laser Mode | The command that puts a Duet3D into laser mode. | **M452 P2 I0 R255 F200** |

---

← [Hobbyist guide](guide-hobbyist.md) · [Pro guide](guide-pro.md) · [README](../README.md)
