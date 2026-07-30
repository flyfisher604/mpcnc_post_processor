<!-- doc-sync: MPCNC_v4.0_Beta2.cps @ db7644b
     This README documents the post as of the commit above. It is NOT kept in sync
     automatically. To refresh it, review only what changed in the post since that ref:
       git diff db7644b..HEAD -- MPCNC_v4.0_Beta2.cps
     Then bump the ref to the new HEAD. -->
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

- A **hobby** job — one operation, one part — needs almost no setup. Jog to your zero,
  accept the defaults (the post records XY there and probes Z for you), post, run.
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
2. Select My posts/Local in the sidebar.
3. If an older copy is installed, select it and use the trash-can icon to remove it
   first.
4. Use the Import icon to import `MPCNC_v4.0_Beta2.cps` (or the latest version available).
5. Close the dialog.
6. When posting, select **Choose from library...** and select this post.
7. Review and set the properties as needed.

![screenshot](/installation.jpg "install")

---

# Quick Start by User Type

## Hobbyist - Posting a Single Operation

**Who this is:** you're cutting one part in one Setup containing one Operation, with a single tool, and
zeroing by hand before posting the job to your CNC. A single operation has no WCS change, so only the **First WCS / Part**
origin choice applies.

> **Review the property groups in the dialog from top to bottom.**
> 
> Only three groups need any attention for users running the hobbyist limited version of Fusion 360;
> for the rest you may just *Accept the Defaults*.

- **01 - Job**
  - set **CNC Firmware** to your controller.
  - Leave **Manual Spindle On/Off** on if you start your router/spindle by hand.
  - Other fields *Accept Defaults*.
- **02 - Establish Machine Coordinates**
  - *Accept Defaults* (**Home Before Start = None**).
  - Choose **XY** only if your machine has X/Y endstops and you want squaring included in the post.
- **03 - Feeds and Speeds**
  - set **Travel Speed X/Y**, **Travel Speed Z**, and the **Max XY Cut Speed** / **Max Z Cut Speed** limits to your machine's real capability.
  - Enable **Scale Feedrate** so cut moves are scaled to stay within those limits, and keep
  **Enforce Feedrate** on so a feedrate is always included on each gcode statement.
- **04 - Map G1s to Rapids**
  - **Hobbyists should turn all options in this group on.**
  - A Personal-license of Fusion 360 forces all rapid moves to be emitted as cutting moves.
  - Converts some of the cutting movements back to rapids and restores safe, properly-ordered
  travel moves (retract before travelling, travel before descending) and avoids dragging the tool
  across the work. (See *G1 → G0 rapid mapping*.)
- **05 - Establish Spoilboard Reference**
  - *Accept Defaults* (**Reserved WCS = None**).
  - Understanding the true zero height of the spoilboard is only important during multi-part moves, not an option in the hobbyist version.
  - A single-part job requires no base.
- **06 - On WCS / Part / Fixture Changes**
  - *Accept Defaults.*
  - **First WCS / Part** defaults to **`Set X0 Y0 to Current Pos, Probe Z0`**
    - **Before sending your post to the CNC, jog the tool to the part's XY corner** (in your sender).
    - The post records the current XY and then probes Z off a touch plate.
      - Optional: use the X Y probe offset to offset the probing operation.
    - Keep **Probe Pause = Before & After** so you're prompted to attach/remove the probe.
    - If you have **no probe** on your CNC, choose **`Set X0 Y0 Z0 to Current Pos`** instead.
      - Jog your CNC to XY *and* touch Z before posting job to CNC.
  - **Prefer a guided jog prompt?**
    - The **`Jog to …`** modes pause mid-run and ask you to jog to the origin instead of pre-jogging.
    They are not the default because jogging while paused isn't supported on every firmware/sender — see *Jogging at a pause*.
- **07 - Tool Changes**
  - *Accept Defaults.* (**Tool Changes are Included = Off**)
- **08 - External Include Files**
  - *Accept Defaults.* (**All Empty**)
- **09 - Laser**
  - *Accept defaults unless this is a laser job.*
- **10 - Coolant**
  - *Accept Defaults unless CNC has coolant hardware.*
- **11 - Duet**
  - *Accept Defaults unless running Duet firmware.*
- **Built-in**
  - *Consult Fusion 360 documentation before changing.*

**Then select post.**

## Full Fusion License - WCS, Many Operations, or Multiple Fixtures

### First: What is a WCS?

A **Work Coordinate System (WCS)** is a *stored origin* the controller remembers.
On GRBL and RepRap there are several — `G54`, `G55`, `G56`, `G57`, `G58`, `G59` (and
`G59.1`–`G59.3` on RepRap only). Selecting one (e.g. `G54`) tells the controller "from
now on, X0 Y0 Z0 means *this* stored position on the CNC." Each WCS holds its own offset, so you can
define several independent zeros and switch between them mid-program without disturbing
the others.

Only a full-license user has the option of utilizing WCSs.

Multiple WCS are commonly used when multiple parts are being milled at different positions (fixtures) on
the CNC. The 0,0 origin of each fixture is set into sequential WCSs prior to posting the job. 

Fusion assigns a WCS to each Setup via its **Work Offset** field (1 → `G54`, 2 → `G55`,
…). This post emits the matching WCS when it changes in Fusion.

> **Marlin firmware is an exception.** Marlin has no work-offset table — it has a single global
> origin set with `G92`. So on Marlin only *one* coordinate frame exists; a job that
> uses more than one distinct work offset is rejected at the time the post processor is run (see *Validation
> guards*). Everything below about multiple WCS applies to GRBL and RepRap.

### (a) Many operations / tools, one part, one WCS

The common full-license job: several operations (face, pocket, contour), possibly
several tools, all on one part in one Setup — so one WCS throughout.

- Turn the **04 - Map G1s to Rapids** group **off** — the full license already posts real
  `G0` rapids, so the hobby workaround isn't needed.
- Set **First WCS / Part**:
  - If this Setup's WCS is a pre-set fixture, choose **`Use Active
  WCS X0 Y0, Probe Z0`** (rapid to the stored X0 Y0, re-probe Z);
  - Otherwise `Set X0 Y0 to
  Current Pos, Probe Z0` (pre-jog XY).
  - Prefer these methods over the `Jog` modes.
- If the job changes tools, enable the **07 - Tool Changes** group.
  - Because there is no
  tool-length system, turn on **Probe After Tool Change** so each new tool re-references
  Z.
  - The tool-change park position (**Tool Change X/Y/Z**) is relative to the current
  work zero.
  - **EXPECT ENHANCEMENTS TO TOOL CHANGES** in future updates.
- One WCS means one shared frame, so each operation's own retract moves already clear the
  part. Since there are no cross-part / cross-WCS moves, there is no need to establish a Spoilboard Reference.

### (b) Multiple fixtures — several copies of a part (Replicate)

You have jigged up several copies of the same part, one per fixture, each on its own
WCS (`G54`, `G55`, `G56`, …), and want to cut them all in one program.

- **Reserve a spoilboard base**
  - Set **05 - Establish Spoilboard Reference → Reserved WCS** (recommended `G59`).
    - This is a *fixed-surface* zero (the spoilboard, not any stock
  top) that gives the post a stable reference to retract to when traversing between parts
  of possibly different thickness.
    - Keep **Probe to Set Base** at `Pause, Probe Z, Pause`
  (or `Probe Z` if pausing to probe is not required).
    - Probing the spoilboard will occur at the current CNC's position. No XY movement will occur prior to the probe.
    - The Reserved WCS will be utilized to record the Z0 of the spoilboard.
    - Attempts to change the Reserved WCS Z0 with an operation will cause a post error. Keep the reserved base
    as the fixed spoilboard reference. A guard trips only if an operation would *re-establish* the base's origin (re-zero or re-probe it); it doesn't otherwise stop you from selecting that WCS for an operation.
- Put each copy on its own Fusion Work Offset.
  - Their **XY** comes from each fixture's
  pre-set offset
    - The post never sets XY for an added part unless you choose a Jog mode.
- The **first** copy uses **First WCS / Part**
  - Choose **`Use Active WCS X0 Y0, Probe Z0`** so it too takes its pre-set XY and
  re-probes Z (matching the copies below).
- **Subsequent WCS / Part** decides what happens at each copy after the first.
  - **Best-practice paths use the stored fixture offset — not jogging**
  - **Use Active WCS X0 Y0, Probe Z0** *(default)*
    - Rapids to that copy's stored X0 Y0 and re-probes its stock-top Z.
    - Handles varying stock thickness.
  - **Use Active WCS X0 Y0 Z0**
    - The copy uses whatever X0 Y0 Z0 is already stored in the corresponding WCS; the tool just rapids there (no probe).
  - **Jog to X0 Y0, Probe Z0** / **Jog to X0 Y0 Z0**
    - Pause (`M0`) so the operator can jog to each copy's origin.
    - Only for a setup run where the fixtures are *not* pre-set, and only if your firmware/sender supports
    jogging during a pause (see *Jogging at a pause*).
- **Retract Across Parts** (on by default)
  - Makes the tool retract to **Safe Z** — an absolute height above the spoilboard base — *before* it traverses to the next fixture, so it clears every clamp and part regardless of their heights.

### (c) One part from multiple references, or a flip — *not* a single job

Reestablishing the same part for a second reference, or flipping it, is **out of scope for a
single post run**. On a machine with no homing the post cannot establish the second
reference's XY, and re-probing the same surface buys nothing. Run each reference / each
side as a **separate job**. Future enhancements may add additional functionality.

---

# Supporting Concepts

## The work-relative coordinate model

Production controls keep three references separate: the machine frame (`G53`, from
homing), the work frame (`G54`–`G59`), and tool-length offsets (TLO, `G43`, from a tool
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

## Origin modes — First vs Subsequent WCS / Part

Group **06 - On WCS / Part / Fixture Changes** holds the two origin controls. Each is an
explicit **taxonomy** with three families:

- **Set … to Current Pos** — no prompt. The tool is assumed to already be at the origin
  (you pre-jogged before starting, or machine homing / the spoilboard base left it there);
  the post records the current position. *(First WCS / Part only.)*
- **Use Active WCS …** — no prompt. Trust the origin already stored in that WCS (a
  pre-set fixture offset / a prior job): rapid to its stored X0 Y0, and either re-probe Z
  (`… X0 Y0, Probe Z0`) or trust the stored Z too (`… X0 Y0 Z0`, no probe). The
  best-practice path for pre-set fixtures. **See *What "Active WCS" means* below — it is
  not whatever WCS your sender currently has selected.**
- **Jog to …** — the post pauses with an `M0` (or RepRap `M291`) so the operator jogs to
  the origin *during* the run, then records it there.

Each probe family comes in a **Z-manual** variant (`… X0 Y0 Z0`, no probe) and a
**probe-Z** variant (`… X0 Y0, Probe Z0`). On a jet tool or tool 0 the probe is skipped
automatically. **The defaults avoid any run-time jog pause** (which not every
firmware/sender supports — see *Jogging at a pause*): **First WCS / Part** defaults to
**`Set X0 Y0 to Current Pos, Probe Z0`** (pre-jog XY in your sender, then probe Z), and
**Subsequent WCS / Part** to **`Use Active WCS X0 Y0, Probe Z0`** (pre-set fixture XY,
re-probe Z). Pick a `Jog to …` mode only when you want the post to pause and guide you
*and* your setup supports jogging at the pause.

> **A jet tool or tool 0 never probes.** Any probe-Z mode degrades to recording the origin
> with no `G38.2`, on every firmware.

### What "Active WCS" means

**The WCS your Fusion Setup designates — not the one your sender happens to have selected.**
Worth being precise about, because the two are easy to conflate:

- Each Fusion **Setup** carries a Work Offset (its WCS). That is what the post uses:
  `G54` unless you set it to something else, and one WCS per part in a multi-part job.
- The post **selects** that WCS itself, at job start, before it establishes any origin. So if
  you left `G55` active in your sender and this Setup says WCS 1, the file emits `G54` and the
  job runs there regardless. The post overwrites the selection — it never inherits it. You do
  **not** need to pre-select a WCS in your sender.
- What the post cannot do is *read* that WCS's stored origin. Register contents are runtime
  state in the controller (GRBL keeps them through a power cycle), written by a previous job or
  by your own manual touch-off. A post is a one-way g-code generator — there is no round trip.

So the split is: **which WCS is certain; what it contains is trusted.** That is exactly what the
`Use Active WCS …` modes assume, and why they are the right choice only when you know the stored
origin is still good:

| | Safe to use | Watch out for |
|---|---|---|
| `Use Active WCS X0 Y0, Probe Z0` | XY fixtures are pre-set and unchanged; stock thickness may vary (Z is re-probed) | A fixture that moved — XY is trusted blindly |
| `Use Active WCS X0 Y0 Z0` | Nothing has changed since the origin was set, incl. stock thickness | New/different stock — the stored Z will be wrong |

On a **fresh controller** every offset is `0`, so `G54` means machine coordinates — on a machine
with no endstops, wherever it powered on. Don't use a `Use Active WCS …` mode until the WCS has
actually been set (by a prior run, or by hand). The `Set … to Current Pos` and `Jog to …` families
establish the origin instead of relying on one, which is why one of them is the default.

## Jogging at a pause

The **Jog** origin modes (and the pre-homing prompt) pause the program and expect you to
jog the tool by hand, then resume. **Whether you can actually jog while paused depends on
your firmware and sender:**

- **RepRap / Duet** — fully supported by design. The post emits `M291 … S3 X1 Y1 Z1`, a
  blocking dialog with on-screen jog buttons for X/Y/Z.
- **GRBL / FluidNC** — the post emits a plain `M0` pause; whether you can jog then is a
  property of your **sender**, not the firmware. CNCjs, UGS, and bCNC keep GRBL in *Idle*
  at the pause and let you jog, then resume with cycle-start; a bare-bones sender may hold
  GRBL in a state that refuses `$J=` until you resume.
- **Marlin** — jog from the **LCD/controller** (Move-Axis menu) while paused at the `M0`.
  Host-streamed jog moves would just queue behind the pause and not run until you resume.

## Establishing the machine frame (homing / MCS)

Group **02 - Establish Machine Coordinates → Home Before Start** decides whether the
machine homes at job start to establish a repeatable machine frame:

- **None** (default) — emit no homing; accept the current position (already homed at the
  controller, or a power-on `0,0,0`). The safe default — a wrong home command is a crash.
- **XY** — home X and Y (the usual case: XY repeatability and gantry squaring; Z stays on
  the work-Z probe touch-off).
- **XYZ** — also home Z, *only* if the machine is actually wired to home Z (LowRider
  switches, or the Marlin movable-plate trick).

Homing command by firmware:

| Firmware | Command |
|---|---|
| Marlin / RRF (Duet) | `G28 X` / `G28 Y` / `G28 Z` — each axis homed independently |
| GRBL / FluidNC | `$H` only — one command homes all configured axes together |

On GRBL/FluidNC `$H` is all-or-nothing, so **XY** and **XYZ** emit the same `$H` (the
choice just documents intent). **Prompt Before Home** pauses before homing so you can
prepare the machine (place a movable Z plate, clear the bed); it fires whenever homing
runs, so it never needs revisiting when the machine changes.

## The reserved spoilboard base

For multi-fixture jobs, one WCS can be reserved as a **spoilboard base** (**05 - Establish
Spoilboard Reference → Reserved WCS**, default `None`). Because it is zeroed to a *fixed
surface* (the spoilboard, independent of stock thickness), it is the one frame in which a
safe height is meaningful across all of a job's parts. It is:

- **Established at job start** by **Probe to Set Base**: `Pause, Probe Z, Pause` (prompt,
  probe, prompt — the manual touch-off, default), `Probe Z` (probe with no prompt, a
  fixed point), or `None` (assume pre-set from a prior job — probe once, run many). This
  base probe is always taken at the origin (0,0 — the tool's position at job start); the
  **Probe X/Y Offset** shifts only *part* probes, never the spoilboard probe.
- **Transited, not parked**: when the tool must move between parts, the post briefly
  selects the base to retract to **Safe Z** (the group's cross-part clearance), then
  selects the destination WCS. It never leaves the base active into a cut, and never
  selects it without a real move.
- Recommended slot **`G59`** (the highest GRBL supports, keeping `G54` free for parts).
  `G59.1`–`G59.3` are RepRap-only; a base is ignored on Marlin.

## Probing and tool changes

- **Work-Z probing only.** `G38.2` down to a touch plate (thickness compensated via
  **Plate Thickness**), with attach/remove pauses governed by **Probe Pause**. There is no
  tool-length system, and X/Y is never probed (jog manually).
- **Probe Pause** (default `Before & After`) controls the operator prompts around each
  *part* probe — attach before, detach after; set `No` for a fixed/permanent probe. It
  does not affect the spoilboard base probe (see **Probe to Set Base**).
- **Probe X/Y Offset** (default `0,0`) moves the Z-probe touch-point away from the work
  origin by a fixed XY distance, so the origin can sit at a part corner or off the material
  while Z is still read on the stock top. It applies at **every part probe** — the first
  part and each added copy — and is job-wide, not per-fixture. It never applies to the
  spoilboard base probe, which always touches off at the origin (0,0).
- **Re-probe after every tool change** is the tool-length substitute — enable **Probe
  After Tool Change**.
- **Manual tool changes** (no ATC): retract, move to the work-relative change position,
  pause for the swap, re-probe Z, resume. Every leg is collision-sensitive.

## Validation guards

The post checks the job at post time (it can't read the live controller) and errors
before emitting bad g-code:

- **No base redefine** — using the reserved base is fine; a job that would *re-establish*
  its origin is an error ("assign this operation to another WCS").
- **Safe-Z across parts needs a base** — if **Retract Across Parts** is on and the job
  uses more than one WCS on GRBL/RRF with no base reserved, it errors (a clearance height
  is meaningless across un-probed offsets). Single-WCS jobs are exempt.
- **Marlin is single-frame** — a Marlin job that uses more than one distinct work offset
  is a hard error (`G92` can't fake multiple WCS).

## G1 → G0 rapid mapping (hobby-license workaround)

The Personal license restricts all moves to the max cut speed — and Fusion implements
this by turning every `G0` rapid into a `G1` cut. The side effect is dragging cuts and
collisions at the start of jobs and after tool changes. Group **04 - Map G1s to Rapids**
selectively converts those `G1` moves back into `G0` rapids where it's safe:

- **First G1 → G0 Rapid** — restores the lost initial positioning move at the start of a
  toolpath (the "tool dragged across the work" problem).
- **Map: G1s → G0 Rapids** — converts horizontal `G1` moves at or above **Map: Safe Z to
  Rapid** into rapids (assumes anything at that height is a safe air move).
- **Map: Safe Z to Rapid** — the Z height where a cut move will be considered safe to convert 
to a rapid. Defined as a Fusion layer followed by a fallback constant used when the layer is not defined
  (eg `Retract:15`, `Feed:5`, `Clearance:7`).
- **Map: Allow Rapid Z** — also convert safe vertical moves.

The post emits rapid `G0` moves as **two moves** — Z and XY separately, ordered so the tool
retracts before travelling and travels before descending — which is what makes these
conversions safe. A true cutting move is never converted. **Full-license users disable this
whole group** — Fusion 360 will post true rapid `G0` and `G1` cutting moves — **enabling will corrupt
Full-license posts**.

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
|CNC Firmware|Dialect of g-code to create (GRBL / Marlin / RepRap).|**GRBL**|
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
|Home Before Start|Home at job start to establish the machine frame: **None** (no homing), **XY** (home X/Y), **XYZ** (also home Z, only if wired for it). GRBL homes all axes with one `$H` if XY or XYZ.|**None**|
|Prompt Before Home|Pause before homing so you can prepare the machine (place a movable Z plate, clear the bed). Fires whenever homing runs.|**false**|

## 03 - Feeds and Speeds
|Title|Description|Default|
|---|---|---|
|Travel Speed X/Y|`G0` travel speed X & Y (mm/min).|**2500**|
|Travel Speed Z|`G0` travel speed Z (mm/min).|**300**|
|Enforce Feedrate|Always emit `Fxxx` even when unchanged (useful for Marlin).|**true**|
|Scale Feedrate|Scale `G1` feeds to axis maximums.|**false**|
|Max XY Cut Speed|Max X or Y cut speed (mm/min).|**900**|
|Max Z Cut Speed|Max Z cut speed (mm/min).|**180**|
|Max Toolpath Speed|Cap for the scaled toolpath feed (mm/min).|**1000**|

## 04 - Map G1s to Rapids (disable when using full license)
|Title|Description|Default|
|---|---|---|
|First G1 → G0 Rapid|Convert the first `G1` of a toolpath to a rapid.|**false**|
|Map: G1s → G0 Rapids|Convert safe horizontal `G1` moves to rapids.|**false**|
|Map: Safe Z to Rapid|Threshold Z: a number, or a Fusion height with fallback (e.g. `Retract:15`).|**Retract:15**|
|Map: Allow Rapid Z|Also convert safe vertical moves.|**false**|

## 05 - Establish Spoilboard Reference
|Title|Description|Default|
|---|---|---|
|Reserved WCS|Reserve one WCS as a fixed spoilboard base. `None` = off. `G59.1`–`G59.3` are RepRap-only; ignored on Marlin.|**None**|
|Probe to Set Base|Set the base's Z at job start: **None** (assume pre-set), **Probe Z** (probe, no prompt), **Pause, Probe Z, Pause** (manual touch-off). Always at the origin (0,0) — Probe X/Y Offset never applies.|**Pause, Probe Z, Pause**|
|Retract Across Parts|Retract to **Safe Z** (below) before traversing between WCS; drives the safe-Z guard. GRBL/RepRap only.|**true**|
|Safe Z|Absolute height above the base to retract to between parts — clear the tallest fixture.|**40**|

## 06 - On WCS / Part / Fixture Changes
|Title|Description|Default|
|---|---|---|
|First WCS / Part|Origin for the first/only part: **Set X0 Y0 to Current Pos, Probe Z0** / **Set X0 Y0 Z0 to Current Pos** / **Use Active WCS X0 Y0, Probe Z0** / **Use Active WCS X0 Y0 Z0** / **Jog to X0 Y0, Probe Z0** / **Jog to X0 Y0 Z0**.|**Set X0 Y0 to Current Pos, Probe Z0**|
|Subsequent WCS / Part|Multi-part only — what to do at each added part's WCS: **Use Active WCS X0 Y0, Probe Z0** / **Use Active WCS X0 Y0 Z0** / **Jog to X0 Y0, Probe Z0** / **Jog to X0 Y0 Z0**. Not supported on Marlin.|**Use Active WCS X0 Y0, Probe Z0**|
|Probe Pause|Operator prompts around each part probe: **No** / **Before** / **Before & After**.|**Before & After**|
|Probe with G38.2|Probe with `G38.2` (On) or `G28` (Off). GRBL always `G38.2`.|**On**|
|G38 Target|Furthest Z the probe move travels to.|**-10**|
|G38 Speed|Probe feedrate (mm/min).|**30**|
|Safe Z|Retract height after probing; also the no-base added-part re-probe retract. A number or a Fusion height (e.g. `Retract:15`).|**Retract:15**|
|Plate Thickness|Touch-plate thickness (compensated into Z).|**0.8**|
|Probe X Offset|X from a part's origin to its Z-probe touch-point. Applied at every part probe (first + added), never to the spoilboard base probe. `0` = probe at the origin.|**0**|
|Probe Y Offset|Y from a part's origin to its Z-probe touch-point. Applied at every part probe (first + added), never to the spoilboard base probe. `0` = probe at the origin.|**0**|

## 07 - Tool Changes
|Title|Description|Default|
|---|---|---|
|Tool Changes are Included|Emit tool-change code when the tool changes.|**false**|
|Include Relocation Code|Move to the change position (X/Y/Z below); off = plain M6/select.|**false**|
|Tool Change X / Y / Z|Change position, relative to the current WCS (plain `G0`).|**0 / 0 / 40**|
|Disable Z Stepper|Disable the Z stepper after reaching the change position.|**false**|
|Do First Change|Do an initial change to load the first tool.|**false**|
|Probe After Tool Change|Re-probe Z after each change (the tool-length substitute).|**false**|

## 08 - External Include Files
Each names a file in the nc output folder whose contents are inserted verbatim at that
point. Leave empty for built-in code.

|Title|Default|
|---|---|
|Start GCode File / Stop GCode File|empty|
|Tool Change Start / Tool Change End|empty|
|Probe|empty|

## 09 - Laser
Fusion's four Through levels all map to "On - Through". The **CNC Firmware** selection
decides whether the GRBL or Marlin/RepRap laser mode is used.

|Title|Description|Default|
|---|---|---|
|Laser: On - Vaporize / Through / Etch|Power % per cutting mode.|**100 / 80 / 40**|
|Laser: Marlin/Reprap Mode|Fan (M106/M107), Spindle (M3/M5), or Pin (M42).|**Fan - M106 S{PWM}/M107**|
|Laser: Marlin M42 Pin|Custom pin for Pin mode.|**4**|
|Laser: GRBL Mode|Dynamic (M4) or static (M3) power.|**M4 S{PWM}/M5 dynamic**|
|Laser: Coolant|Force a coolant for laser ops (e.g. air).|**Off**|

## 10 - Coolant
Two channels (A, B); each maps a Fusion coolant mode to enable/disable g-code. If a
tool's coolant matches a channel, that channel is enabled; a warning is emitted if a
requested coolant matches no channel. Marlin and GRBL command options are both offered —
pick to match your wiring. Set a channel to **Use custom** to use the custom strings.

|Title|Description|Default|
|---|---|---|
|Channel A / B Mode|Coolant mode that enables the channel.|**off**|
|Turn Channel A / B On/Off|Enable/disable g-code for the channel.|**M42 P6/P11 S255/S0**|
|Channel A / B On/Off Custom|Custom include files when Mode = Use custom.|empty|

## 11 - Duet
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
