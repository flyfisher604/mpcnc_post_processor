Fusion 360 CAM Post Processor for MPCNC / LowRider
====

CAM post processor for [Fusion 360](https://www.autodesk.com/products/fusion-360)
and the [V1 Engineering](https://www.v1engineering.com) MPCNC / LowRider family of
machines. This is a modified fork of
[guffy1234/mpcnc_posts_processor](https://github.com/guffy1234/mpcnc_posts_processor),
originally forked from
[martindb/mpcnc_posts_processor](https://github.com/martindb/mpcnc_posts_processor).

This is the **v4.0 (Beta)** post processor, distributed as the single file
`MPCNC_v4.0_Beta2.cps`.

Supported firmware (set by the **Job → CNC Firmware** property):

- GRBL 1.1 / FluidNC
- Marlin 2.x
- RepRap firmware (Duet3D)
- Repetier 1.0.3 (untested; g-code is the same as Marlin)

---

# What this post does

At its core the post turns a Fusion CAM program into g-code for a hobby-class CNC
(MPCNC, LowRider, and similar GRBL/Marlin/RepRap machines). Beyond the usual
translation it is built around one central idea that shapes every other feature:

**These machines are *work-relative*.** Most of them have no reliable machine-Z
reference — no tool setter, often no Z endstop, sometimes no endstops at all. So the
post does not lean on the machine frame. Instead you establish a **work zero** (by
jogging to it, or by probing a touch plate), and everything the post emits — cutting,
retracts, traverses between parts — is measured relative to that zero. Where a machine
*can* home, homing is used for X/Y repeatability, never as the everyday Z reference.

The post is designed to **degrade gracefully**:

- A **hobby** job — one operation, one part, no probe — needs almost no setup. Jog to
  your zero, post, run.
- A **full** job — many operations, multiple tools, or multiple fixtures making several
  copies — has the extra structure (WCS handling, a reserved spoilboard base, per-part
  probing, safe cross-part traverses) available and validated, without complicating the
  simple case.

Other capabilities: 3-axis milling and jet (laser / plasma / waterjet) operations;
canned drilling cycles expanded into plain moves; arcs; 3 laser power levels; two
configurable coolant channels; adjustable comment verbosity; optional line numbers;
external include files for custom g-code. Only 3-axis toolpaths are supported —
multi-axis operations are rejected with a clear error.

> **Units:** the post outputs in whatever units the Setup uses (mm or inch), **but all
> post properties must be entered in millimeters.**

---

# Installation

The post is a single file, `MPCNC_v4.0_Beta2.cps`.

1. In Fusion, choose **Manage → Post Library**.
2. If an older copy is installed, select it and use the trash-can icon to remove it
   first.
3. Import `MPCNC_v4.0_Beta2.cps` (or keep it in a folder and select it at post time).
4. When posting, use **Setup → Use Personal Post Library** and select this post.
5. Set **Job → CNC Firmware** to match your controller.

![screenshot](/screenshot.jpg "screenshot")

---

# Quick start by user type

## Hobbyist — posting a single operation

**Who this is:** a Fusion **Personal Use** (hobbyist) licensee, cutting one part in one
Setup, usually with a single tool, and zeroing by hand. No probe or fixturing required.

**The flow:**

1. **Job → CNC Firmware** — pick your controller.
2. **Feeds and Speeds** — this is the license-compliance step. The Fusion Personal
   license requires that no move exceed your machine's maximum cut feedrate, so set
   **Travel Speed X/Y** and **Travel Speed Z** no faster than your cut speeds. (See
   *G1 → G0 rapid mapping* below for why this matters and how the post keeps travels
   safe.)
3. **Map G1s to Rapids** — leave this group **on** for the hobby case. It restores safe,
   properly-ordered rapid moves that the Personal license would otherwise turn into
   dragging cuts. (Full-license users turn it off — see that section.)
4. **First Part: Set Work Origin** (in the WCS / Probe group) — how the single part gets
   its zero:
   - **Zero XYZ (no probe)** — jog the tool to the part origin (the XY corner *and* down
     to touch the stock top), then this records that position as X0 Y0 Z0. The classic
     manual touch-off; also the choice for a laser/pen where Z is set by hand.
   - **Zero XY, probe Z** — jog to the XY corner, and the post probes Z off a touch
     plate for you. (Default.)
   - **Skip** — do nothing (you have zeroed in your sender).
5. Post and run.

Everything else (the spoilboard base, "On Each Added Part", cross-part clearance) stays
at its default and emits nothing. A single-operation job is byte-for-byte what you'd
expect — none of the multi-part machinery runs.

## Full user — WCS, many operations, and multiple fixtures

### First: what is a WCS?

A **Work Coordinate System (WCS)** is a *stored origin* the controller remembers.
On GRBL and RepRap there are several — `G54`, `G55`, `G56`, `G57`, `G58`, `G59` (and
`G59.1`–`G59.3` on RepRap only). Selecting one (e.g. `G54`) tells the controller "from
now on, X0 Y0 Z0 means *this* stored point." Each WCS holds its own offset, so you can
define several independent zeros and switch between them mid-program without disturbing
the others.

Fusion assigns a WCS to each Setup via its **Work Offset** field (1 → `G54`, 2 → `G55`,
…). This post emits the matching selection and writes each origin into that WCS's *own*
register with `G10 L20 P<n>`, so setting one zero never corrupts another.

> **Marlin is the exception.** Marlin has no work-offset table — it has a single global
> origin set with `G92`. So on Marlin only *one* coordinate frame exists; a job that
> uses more than one distinct work offset is rejected at post time (see *Validation
> guards*). Everything below about multiple WCS applies to GRBL and RepRap.

The full-license user meets WCS in one of three situations:

### (a) Many operations / tools, one part, one WCS

The common full-license job: several operations (face, pocket, contour), possibly
several tools, all on one part in one Setup — so one WCS throughout.

- Turn the **Map G1s to Rapids** group **off** — the full license already posts real
  `G0` rapids, so the hobby workaround isn't needed.
- Set **First Part: Set Work Origin** as above (probe Z is the usual full-license
  choice).
- If the job changes tools, enable the **Tool Changes** group. Because there is no
  tool-length system, turn on **Probe After Tool Change** so each new tool re-references
  Z. The tool-change park position (**Tool Change X/Y/Z**) is relative to the current
  work zero.
- One WCS means one shared frame, so each operation's own retract already clears the
  part — no extra cross-part machinery runs.

### (b) Multiple fixtures — several copies of a part (Replicate)

You have jigged up several copies of the same part, one per fixture, each on its own
WCS (`G54`, `G55`, `G56`, …), and want to cut them all in one program.

- **Reserve a spoilboard base** — set **WCS for Spoilboard** (default choice `G59`). This
  is a *fixed-surface* zero (the spoilboard, not any stock top) that gives the post a
  stable reference to retract to when traversing between parts of possibly different
  thickness. Keep **Probe Z to Set Spoilboard WCS** on so it's established at job start.
- Put each copy on its own Fusion Work Offset. Their **XY** comes from each fixture's
  pre-set offset — the post never sets XY for an added part.
- **On Each Added Part** decides Z for each copy after the first:
  - **Probe Z** (default) — at each new copy the post rapids to that copy's origin and
    probes its stock-top Z.
  - **Skip** — the copy uses whatever Z is already stored in its WCS.
- **Safe Z Retract Across Parts** (on by default) makes the tool retract to **Cross Part
  Clearance** — an absolute height above the spoilboard base — *before* it traverses to
  the next fixture, so it clears every clamp and part regardless of their heights.
- Don't assign any cutting operation to the reserved base WCS itself (a guard enforces
  this).

### (c) One part from multiple references, or a flip — *not* a single job

Re-datuming the same part to a second reference, or flipping it, is **out of scope for a
single post run**. On a machine with no homing the post cannot establish the second
reference's XY, and re-probing the same surface buys nothing. Run each reference / each
side as a **separate job**.

---

# Supporting concepts

## The work-relative coordinate model

Production controls keep three references separate: the machine frame (`G53`, from
homing), the work frame (`G54`–`G59`), and tool-length offsets (`G43`, from a tool
setter). Most V1E machines have none of the three fully, so this post takes a deliberate
**work-relative stance**:

- The everyday reference is the **active WCS**, not the machine frame.
- **Tool length is folded into a Z re-probe after each tool change** — there is no TLO.
- Homing establishes the machine frame for **X/Y only** (squaring and a repeatable
  origin), as an optional robustness feature. **Z homing, where it exists, is for its own
  sake** (a real endstop, or the movable-plate trick) and never becomes the everyday Z
  reference — that is always the work-Z touch-off.

This matches the GRBL ecosystem (Shapeoko / OpenBuilds / Onefinity all zero to the work
and probe Z) and works on the lowest-common-denominator machine.

## Establishing the machine frame (homing / MCS)

Group **02 - Establish Machine Coordinates** decides, per axis, how the machine frame is
set. Each of **Home X / Home Y / Home Z** is either:

- **Power-On** (default) — accept the current position as zero; the post emits no motion.
  The fallback for an axis with no endstop.
- **Home** — the post emits the homing command and the axis runs to its endstop.

Homing command by firmware:

| Firmware | Command |
|---|---|
| Marlin / RRF (Duet) | `G28 X` / `G28 Y` / `G28 Z` — independent per axis set to Home |
| GRBL / FluidNC | `$H` only — one command homes all configured axes together |

On GRBL/FluidNC the per-axis pickers can't each trigger their own command (`$H` is
all-or-nothing): any axis set to **Home** causes one `$H`, and the three pickers document
which axes you assert are wired. **Prompt Before Z Home** pauses before a Marlin `G28 Z`
so you can place a movable Z plate — it never fires for X/Y or on GRBL/RRF.

Out of the box every axis is **Power-On**, so the post emits no homing (a wrong home
command is a crash).

## The reserved spoilboard base

For multi-fixture jobs, one WCS can be reserved as a **spoilboard base** (**WCS for
Spoilboard**, default off / `None`). Because it is zeroed to a *fixed surface* (the
spoilboard, independent of stock thickness), it is the one frame in which a safe height
is meaningful across all of a job's parts. It is:

- **Established at job start** by probing the spoilboard (**Probe Z to Set Spoilboard
  WCS** on), or assumed pre-set from a prior job (off — probe once, run many).
- **Transited, not parked**: when the tool must move between parts, the post briefly
  selects the base to retract to **Cross Part Clearance**, then selects the destination
  WCS. It never leaves the base active into a cut, and never selects it without a real
  move.
- Recommended slot **`G59`** (the highest GRBL supports, keeping `G54` free for parts).
  `G59.1`–`G59.3` are RepRap-only; a base is ignored on Marlin.

## Probing and tool changes

- **Work-Z probing only.** `G38.2` down to a touch plate (thickness compensated via
  **Plate Thickness**), with attach/remove pauses. There is no tool-length system, and
  X/Y is never probed (jog manually).
- **Re-probe after every tool change** is the tool-length substitute — enable **Probe
  After Tool Change**.
- **Manual tool changes** (no ATC): retract, move to the work-relative change position,
  pause for the swap, re-probe Z, resume. Every leg is collision-sensitive.

## Validation guards

The post checks the job at post time (it can't read the live controller) and errors
before emitting bad g-code:

- **No base redefine** — using the reserved base is fine; a job that would *re-establish*
  its origin is an error ("assign this operation to another WCS").
- **Safe-Z across parts needs a base** — if **Safe Z Retract Across Parts** is on and the
  job uses more than one WCS on GRBL/RRF with no base reserved, it errors (a clearance
  height is meaningless across un-probed offsets). Single-WCS jobs are exempt.
- **Marlin is single-frame** — a Marlin job that uses more than one distinct work offset
  is a hard error (`G92` can't fake multiple WCS).

## G1 → G0 rapid mapping (hobby-license workaround)

> **Personal Use license note:** to comply with the
> [Fusion Personal Use limitations](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/Fusion-360-Free-License-Changes.html),
> set **Travel Speed X/Y** and **Travel Speed Z** no faster than your machine's maximum
> cut feedrate.

The Personal license restricts all moves to the max cut speed — and Fusion implements
this by turning every `G0` rapid into a `G1` cut. The side effect is dragging cuts and
collisions at the start of jobs and after tool changes. Group **05 - Map G1s to Rapids**
selectively converts those `G1` moves back into `G0` rapids where it's safe:

- **First G1 → G0 Rapid** — restores the lost initial positioning move at the start of a
  toolpath (the "tool dragged across the work" problem).
- **Map: G1s → G0 Rapids** — converts horizontal `G1` moves at or above **Map: Safe Z to
  Rapid** into rapids (assumes anything at that height is a safe air move).
- **Map: Safe Z to Rapid** — a constant (e.g. `10`) or a Fusion height with a fallback
  (`Retract:15`, `Feed:5`, `Clearance:7`).
- **Map: Allow Rapid Z** — also convert safe vertical moves.

The post emits each `G0` as **two moves** — Z and XY separately, ordered so the tool
retracts before travelling and travels before descending — which is what makes these
conversions safe. A cutting move is never converted. **Full-license users disable this
whole group** — their posted rapids are already real `G0` moves.

## Feeds and feedrate scaling

**Travel Speed X/Y** and **Travel Speed Z** are always used for `G0` rapids. If **Scale
Feedrate** is on, `G1` cut feedrates are scaled so no axis exceeds its **Max XY / Max Z
Cut Speed**: the toolpath feed is projected onto each axis, over-limit axes are scaled
down proportionally, and the result is capped at **Max Toolpath Speed**. Scaling only
ever *reduces* a feed. (Because scaling is 3-dimensional, a resulting toolpath feed can
look higher than a single axis limit while each axis is still within its own limit.)

---

# Property reference

Groups appear in the Fusion dialog in the order below.

## 01 - Job
|Title|Description|Default|
|---|---|---|
|CNC Firmware|Dialect of g-code to create (GRBL / Marlin / RepRap).|**GRBL 1.1**|
|Manual Spindle On/Off|Issue pauses to manually turn the spindle on/off.|**true**|
|Comment Level|Verbosity: Off, Important, Info, Debug.|**Info**|
|Use Arcs|Use G2/G3 for circular moves.|**true**|
|Enable Line #s|Emit sequence numbers.|**false**|
|First Line #|First sequence number.|**10**|
|Line # Increment|Sequence-number increment.|**1**|
|Include Whitespace|Whitespace separation between words.|**true**|
|At End Go to 0,0|Go to X0 Y0 at program end; Z unchanged.|**true**|

## 02 - Establish Machine Coordinates
|Title|Description|Default|
|---|---|---|
|Home X / Home Y / Home Z|Per axis: **Power-On** (accept current position, no motion) or **Home** (run to endstop). GRBL homes all axes with one `$H` if any is set to Home.|**Power-On**|
|Prompt Before Z Home|Pause before a Marlin `G28 Z` to place a movable Z plate. Marlin-only.|**false**|

## 03 - Work Coordinate System - WCS / Probe
|Title|Description|Default|
|---|---|---|
|WCS for Spoilboard|Reserve one WCS as a fixed spoilboard base. `None` = off. `G59.1`–`G59.3` are RepRap-only; ignored on Marlin.|**None**|
|Probe Z to Set Spoilboard WCS|Probe the spoilboard into the base at job start (off = assume pre-set).|**true**|
|First Part: Set Work Origin|First/only part origin: **Skip** / **Zero XYZ (no probe)** / **Zero XY, probe Z**.|**Zero XY, probe Z**|
|On Each Added Part|Multi-fixture only: **Skip** or **Probe Z** at each added copy's WCS.|**Probe Z**|
|G38.2 (On) or G28 (Off)|Probe with `G38.2` (On) or `G28` (Off). GRBL always `G38.2`.|**On**|
|G38 Target|Furthest Z the probe move travels to.|**-10**|
|G38 Speed|Probe feedrate (mm/min).|**30**|
|Safe Z|Retract height after probing; also the no-base added-part re-probe retract.|**40**|
|Plate Thickness|Touch-plate thickness (compensated into Z).|**0.8**|
|Safe Z Retract Across Parts|Retract to Cross Part Clearance before traversing between WCS; drives Guard B. GRBL/RepRap only.|**true**|
|Cross Part Clearance (above spoilboard)|Absolute height above the base to retract to between parts — clear the tallest fixture.|**40**|

## 04 - Feeds and Speeds
|Title|Description|Default|
|---|---|---|
|Travel Speed X/Y|`G0` travel speed X & Y (mm/min).|**2500**|
|Travel Speed Z|`G0` travel speed Z (mm/min).|**300**|
|Enforce Feedrate|Always emit `Fxxx` even when unchanged (useful for Marlin).|**true**|
|Scale Feedrate|Scale `G1` feeds to axis maximums.|**false**|
|Max XY Cut Speed|Max X or Y cut speed (mm/min).|**900**|
|Max Z Cut Speed|Max Z cut speed (mm/min).|**180**|
|Max Toolpath Speed|Cap for the scaled toolpath feed (mm/min).|**1000**|

## 05 - Map G1s to Rapids (disable when using full license)
|Title|Description|Default|
|---|---|---|
|First G1 → G0 Rapid|Convert the first `G1` of a toolpath to a rapid.|**false**|
|Map: G1s → G0 Rapids|Convert safe horizontal `G1` moves to rapids.|**false**|
|Map: Safe Z to Rapid|Threshold Z: a number, or a Fusion height with fallback (e.g. `Retract:15`).|**Retract:15**|
|Map: Allow Rapid Z|Also convert safe vertical moves.|**false**|

## 06 - Tool Changes
|Title|Description|Default|
|---|---|---|
|Tool Changes are Included|Emit tool-change code when the tool changes.|**false**|
|Include Relocation Code|Move to the change position (X/Y/Z below); off = plain M6/select.|**false**|
|Tool Change X / Y / Z|Change position, relative to the current WCS (plain `G0`).|**0 / 0 / 40**|
|Disable Z Stepper|Disable the Z stepper after reaching the change position.|**false**|
|Do First Change|Do an initial change to load the first tool.|**false**|
|Probe After Tool Change|Re-probe Z after each change (the tool-length substitute).|**false**|

## 07 - External Include Files
Each names a file in the nc output folder whose contents are inserted verbatim at that
point. Leave empty for built-in code.

|Title|Default|
|---|---|
|Start GCode File / Stop GCode File|empty|
|Tool Change Start / Tool Change End|empty|
|Probe|empty|

## 08 - Laser
Fusion's four Through levels all map to "On - Through". The **CNC Firmware** selection
decides whether the GRBL or Marlin/RepRap laser mode is used.

|Title|Description|Default|
|---|---|---|
|Laser: On - Vaporize / Through / Etch|Power % per cutting mode.|**100 / 80 / 40**|
|Laser: Marlin/Reprap Mode|Fan (M106/M107), Spindle (M3/M5), or Pin (M42).|**Fan - M106 S{PWM}/M107**|
|Laser: Marlin M42 Pin|Custom pin for Pin mode.|**4**|
|Laser: GRBL Mode|Dynamic (M4) or static (M3) power.|**M4 S{PWM}/M5 dynamic**|
|Laser: Coolant|Force a coolant for laser ops (e.g. air).|**Off**|

## 09 - Coolant
Two channels (A, B); each maps a Fusion coolant mode to enable/disable g-code. If a
tool's coolant matches a channel, that channel is enabled; a warning is emitted if a
requested coolant matches no channel. Marlin and GRBL command options are both offered —
pick to match your wiring. Set a channel to **Use custom** to use the custom strings.

|Title|Description|Default|
|---|---|---|
|Channel A / B Mode|Coolant mode that enables the channel.|**off**|
|Turn Channel A / B On/Off|Enable/disable g-code for the channel.|**M42 P6/P11 S255/S0**|
|Channel A / B On/Off Custom|Custom include files when Mode = Use custom.|empty|

## 10 - Duet
|Title|Description|Default|
|---|---|---|
|Milling Mode|Duet3D milling-mode command.|**M453 P2 I0 R30000 F200**|
|Laser Mode|Duet3D laser-mode command.|**M452 P2 I0 R255 F200**|

---

# Notes and limitations

- Only 3-axis toolpaths — 4/5-axis operations error out.
- Cutter/radius compensation must be **In computer**; control-side G41/G42 is a posting
  error.
- Arcs are on the XY plane (Marlin/RepRap) or all planes (GRBL); full circles are two
  arcs.
- Canned cycles (drill/peck/bore/tap) are expanded into plain G0/G1 moves.
- Manual NC **Pass through** commands are emitted verbatim.
- GRBL laser jobs likely need laser mode enabled
  ([`$32=1`](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Laser-Mode)).
- Built-in tool change with LCD/SD: printing from SD and using the LCD to restart is
  required.

---

# Resources

- [Marlin G-codes](https://marlinfw.org/meta/gcode/)
- [PostProcessor Class Reference](https://cam.autodesk.com/posts/reference/classPostProcessor.html)
- [Post Processor Training Guide (PDF)](https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf)
- [Dumper PostProcessor](https://cam.autodesk.com/hsmposts?p=dump)
- [Library of existing post processors](https://cam.autodesk.com/hsmposts)
- [Post processors forum](https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218)
