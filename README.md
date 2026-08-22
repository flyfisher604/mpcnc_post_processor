Fusion 360 CAM Post Processor for GRBL, Marlin, RepRap & FluidNC
====

A Fusion 360 CAM post processor for hobby-class CNC machines running GRBL, Marlin, RepRap (Duet3D), or FluidNC firmware — including the V1 Engineering MPCNC and LowRider, and similar 3-axis builds.

This is a modified fork of
[guffy1234/mpcnc_posts_processor](https://github.com/guffy1234/mpcnc_posts_processor),
originally forked from
[martindb/mpcnc_posts_processor](https://github.com/martindb/mpcnc_posts_processor).

This is the **v4.1.1 (Beta 3)** post processor, distributed as the single file
`MPCNC_v4.1.1_Beta3.cps`.

Supported firmware (set by the **Job → CNC Firmware** property):

- **Grbl** — GRBL 1.1, and FluidNC, which this post treats as GRBL throughout
- **Marlin** — Marlin 2.x. Read from source at 2.0.9.7 and 2.1.2.5; nothing below that was
  read, so **2.0.9.7 is the floor** every Marlin claim here rests on
- **RepRap** — RepRapFirmware (Duet3D)
- Repetier 1.0.3 is untested; its g-code is Marlin's, so choose **Marlin**

---

# Which guide is for you

| | Read this |
|---|---|
| **One part, one tool, zeroed by hand.** You jog to your corner, post, and cut. | **[Hobbyist guide](docs/guide-hobbyist.md)** — eight settings matter; the rest can stay as they ship |
| **Several operations, more than one tool, or several parts on their own fixtures.** | **[Pro guide](docs/guide-pro.md)** — work offsets, the machine travel height, tool-change hand-over, the validation guards |
| **Looking up one setting.** | **[Property reference](docs/property-reference.md)** — all 57, in dialog order |

---

# What this post does

At its core the post turns a Fusion CAM program into g-code for a hobby-class CNC
(MPCNC, LowRider, and similar GRBL/Marlin/RepRap machines). Beyond the usual
translation it is built around one central idea that shapes every other feature:

**These machines are *work-relative*.** Most of them have no reliable machine-Z
reference — no tool setter, no tool-length offset register, often no Z endstop, sometimes no
endstops at all. So the post does not lean on the machine frame. Instead you establish a
**work zero** (by jogging to it, or by probing a touch plate), and everything the post emits —
cutting, retracts, traverses between parts — is measured relative to that zero. Where a machine
*can* home, homing buys repeatability and one job-level travel height, never the everyday Z
cutting reference.

Two consequences run through the whole post, and knowing them explains most of the dialog:

- **The post commands a work offset and can never read one back.** It always knows *which*
  register is active, because it selects it itself at job start over whatever your sender left
  modal. It never knows *where* that register points — register contents are runtime state in the
  controller and there is no round trip. So every mode that uses a stored origin **trusts** it,
  and the shipped defaults establish an origin rather than trust one.
- **The post changes no tool, on any firmware.** A measured tool change needs a probe, a
  subtraction and a register to hold the result, and the post has none of the three. Its whole
  role at a change is to arrive correctly, hand over, and resume correctly.

The post is designed to **degrade gracefully**:

- A **one-part, one-tool job** needs almost no setup. Jog to your zero, accept the defaults, post, run.
- A **larger job** — many operations, more than one tool, or several parts on separate fixtures —
  has the extra structure available and validated, without complicating the simple case.

Other capabilities: 3-axis milling and jet (laser / plasma / waterjet) operations; canned
drilling cycles expanded into plain moves; arcs; 3 laser power levels; two configurable coolant
channels; four comment levels with a full property dump at the head of every file; optional line
numbers; external include files for custom g-code. Only 3-axis toolpaths are supported —
multi-axis operations are rejected with a clear error.

> **Units:** the post outputs in whatever units the Setup uses (mm or inch), **but every
> dimension in the dialog is entered in millimetres.** The head of each posted file echoes the
> values the post *resolved* — in output units — so you can check them before the machine moves.

---

# Installation

The post is a single file, `MPCNC_v4.1.1_Beta3.cps`.

1. In Fusion, choose **Manage → Post Library**.
2. Select My posts/Local in the sidebar.
3. If an older copy is installed, select it and use the trash-can icon to remove it
   first. **Every release so far has had a different filename**, so an old copy will sit
   alongside the new one rather than being replaced, and the two are hard to tell apart
   in the picker.
4. Use the Import icon to import `MPCNC_v4.1.1_Beta3.cps` (or the latest version available).
5. Close the dialog.
6. When posting, select **Choose from library...** and select this post.
7. Review and set the properties as needed — start with the guide for your kind of job, above.

![screenshot](/installation.jpg "install")

---

# Release history

## v4.1.1 — current

**The dialog asks 57 questions where it asked 65.** Nothing was removed from the post: six places
where two or three fields held one decision are now one field each.

| Now one field | Was | What to do |
|---|---|---|
| **Line #s** (group 1) | *Enable Line #s*, *First Line #*, *Line # Increment* | Three answers: `Off`, `N10 N11 N12 … step 1`, `N10 N20 N30 … step 10`. Numbering starts at `N10` |
| **Probe X Y Offset** (group 5) | *Probe X Offset*, *Probe Y Offset* | Two numbers separated by a comma — `30, -15`. Signed, and decimals now allowed where the old fields took whole mm |
| **Safe Z** (group 5) | *Safe Z* and group 3's *Safe Z to Rapid* | One height, read by both groups. Group 3 keeps its switch and has no height field of its own |
| **Manual Position X Y** (group 6) | *Manual Position X*, *Manual Position Y* | Two numbers separated by a comma — `-10, -400`. *Manual Position Z* is unchanged and still fills on its own |
| **Laser Output** (group 8) | *Laser: Marlin/Reprap Mode*, *Laser: GRBL Mode* | Five values, each labelled `Grbl:` or `Mrln:`. Pick the one your firmware speaks |
| **Channel A / B Output** (group 9) | *Turn Channel A/B On* and *Turn Channel A/B Off* | One answer sets both directions — the off code follows from the on code |

Three things to know before your first v4.1.1 job:

1. **Four settings reset to their defaults**, because their shape changed: *Line #s*,
   *Probe X Y Offset*, *Manual Position X Y* and *Laser Output*. The coolant channel outputs and
   *Safe Z* keep whatever you had set.
2. **The laser default is now a GRBL value.** A Marlin or RepRapFirmware laser job that does not
   answer *Laser Output* emits `M4 S…` — a command those firmwares either do not implement, or
   implement with `S` read as a 0–255 byte rather than GRBL's 0–1000, so the power comes out wrong.
   The post warns and names both. Set the field once and it goes away; milling jobs are unaffected.
3. **One coolant bug went with the merge.** A channel switched on with `M106` or `M42` while its
   off field was left at the shipped `M9` was opened with a pin write and closed with a command
   naming no pin, so nothing the post emitted ever switched that output back off. The off code is
   now the on code's own.

**FluidNC is also corrected throughout.** *Tool Change Handled By* gains a **FluidNC — T + M6**
value: FluidNC executes the `M6` itself rather than needing a sender to intercept it, dispatching
to the `atc:` changer or `m6_macro:` in `config.yaml`, and accepting the line silently when neither
is declared. The idle-timer and homing-pull-off warnings now name FluidNC's `idle_ms` and
`pulloff_mm` alongside Grbl's `$1` and `$27`, instead of naming settings FluidNC does not have.

**The post has a new filename again.** Remove `MPCNC_v4.1_Beta3.cps` from the Post Library rather
than leaving it beside this one.

**[→ Full release notes for v4.1.1 Beta 3](docs/release-notes-v4.1.1-beta3.md)** — every fold, what
resets, and what is *not* verified.

## v4.1 Beta 3

v4.0 Beta 3 could ask you to switch the router on by hand, or command it with `M3`. On a stock
Marlin build neither is much use — `M3` is behind a build option that is off — while the fan and
pin outputs that build *can* switch were reachable only for a laser, and then only on fan 0.
v4.1 Beta 3 lets the router, the laser and both coolant channels each name the output they switch.

Two things to know before your first v4.1 job:

1. **Three settings changed name or shape**, so those three fall back to their defaults: the old
   *Manual Spindle On/Off* checkbox is now a four-way **Spindle Control**, and the laser and
   coolant pin fields were replaced by ones you can set per output. The default is the same
   behaviour the checkbox shipped — the post asks you to switch the router by hand — so a job
   posts the same way it did unless you choose otherwise.
2. **The post has a new filename again.** Remove `MPCNC_v4.0_Beta3.cps` from the Post Library
   rather than leaving it beside this one.

**[→ Full release notes for v4.1 Beta 3](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/docs/release-notes-v4.1-beta3.md)**
— kept at the tag it describes, not in the working tree.

## v4.0 Beta 3

Beta 2 gave each part its own zero. Beta 3 corrected **where those zeros come from**, rebuilt tool
changes around what the post can actually do, and — for the first time — *ran* the post against
Autodesk's own engine instead of reasoning about it.

Two things to do before your first Beta 3 job, neither of them optional:

1. **Your saved settings will not carry over.** Every property key in the dialog was renamed, so a
   Beta 2 preset falls back to its shipped default on every setting. Walk the dialog once, and
   look hardest at groups **4**, **5** and **6** — those changed most in meaning as well as in name.
2. **The post has a new filename**, and Fusion identifies a post by filename. Remove
   `MPCNC_v4.0_Beta2.cps` from the Post Library rather than leaving it beside Beta 3.

**[→ Full release notes for v4.0 Beta 3](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.0_Beta3/docs/release-notes-v4.0-beta3.md)**
— kept at the tag it describes, not in the working tree.

## v4.0 Beta 2

Beta 1 knew one zero: wherever the tool happened to be when the job started. Beta 2 keeps track
of one per part, plus one job-level height in the machine's own frame to cross the bed at.

1. **More than one work zero.** Beta 1 set a single origin for the whole program. Beta 2 stores a
   separate zero for each part, in the controller's own registers, and switches between them as
   the job runs. All three firmwares have those registers; on Marlin they arrive with one build
   option (`CNC_COORDINATE_SYSTEMS`), which the post assumes and warns about rather than refusing.
   → [What a work offset is](docs/guide-pro.md#what-a-work-offset-is-and-what-this-post-does-with-it)
2. **You choose how each zero gets set.** Beta 1 had two checkboxes. Beta 2 asks you to pick:
   use where the tool is now, use a zero the controller already has stored, or stop and let
   you jog to it — each with or without probing Z off a touch plate.
   → [Origin modes in full](docs/guide-pro.md#origin-modes-in-full)
3. **Several parts in one job.** Parts on separate fixtures cut in a single run, re-probing each
   one so stock thickness can vary — and one part from several datums on one fixture, each datum
   being a work offset like a part.
   → [Several parts in one job](docs/guide-pro.md#several-parts-in-one-job)
4. **The machine frame, split in two.** Group **4** separates *what your machine can home* from
   *what this job should do about it*, so "homed at the controller, do not home here" is now
   sayable. → [The machine frame](docs/guide-pro.md#the-machine-frame-and-the-travel-height)
5. **One travel height in the machine's own frame.** **Machine Travel Z** is an absolute machine
   coordinate, read off your sender once and typed in. The machine's homed Z is the only frame
   whose Z0 does not move with stock thickness, so it is the only height that can clear every
   fixture on a job whose parts differ in thickness — and a multi-part job is refused without it.
   → [The travel height](docs/guide-pro.md#the-machine-frame-and-the-travel-height)
6. **Tool changes rebuilt around what the post can actually do**, which is arrive, hand over and
   resume. Group **6** asks who performs the change — nobody (refuse the job), you at a pause, or
   your sender's or firmware's own macro — and, separately, **who corrects Z0** for the new tool's
   length. **A multi-tool job is now refused by default** rather than posted with its changes
   silently dropped. → [Tool changes](docs/guide-pro.md#tool-changes)
7. **Unsafe jobs are refused before any file is written**, with a message saying what to change;
   many more conditions warn you — in Fusion's post dialog, in the file, or in both.
   → [Validation guards](docs/guide-pro.md#validation-guards)
8. **Better probing.** Prompts to attach and remove the probe, and the option to touch off
   away from the part origin so that origin can sit off the material.
   → [Probing](docs/guide-pro.md#probing)
9. **The dialog was rebuilt** — 10 numbered groups in the order you work through them, and every
   setting is dumped at the head of the posted file, together with the values the post resolved
   from them. → [Property reference](docs/property-reference.md)
10. **Safer endings and clearer prompts.** The spindle stops *before* the tool parks; a hand-set
    router is prompted whenever the speed or direction changes, not only at the start; and each
    firmware gets the right end-of-program code.
11. **Saved settings do not carry over from Beta 1**, and several were rebuilt during the Beta 2
    series itself — the dialog's internal keys changed, so expect to re-enter a customised preset
    once. **Check groups 4, 5 and 6 before your first job:** the origin choice is new and its
    default is not what Beta 1 did, **Machine Travel Z** ships empty on purpose, and **At a Tool
    Change** ships at *Refuse a multi-tool job*. **Scale Feedrate** is now on, and the coolant
    channel codes default to the GRBL dialect rather than Marlin's.

## v4.0 Beta 1

Beta 1 was v3.0 Beta 3 renamed — the post itself was unchanged. Its work was tidying and
correctness rather than new machine features:

- A **grouped, named property dialog** in place of a flat list of settings.
- **Drilling operations post at all** — canned cycles are expanded into ordinary moves.
- **Manual NC pass-through** commands are emitted as written.
- **Rapid moves are ordered** so the tool lifts before it travels and travels before it
  descends, instead of dragging or plunging.
- **Jobs the post can't handle are refused with a useful message** — 4/5-axis toolpaths, and
  cutter compensation set to anything but *In computer*.
- A long list of smaller corrections.

---

# Notes and limitations

- Only 3-axis toolpaths — 4/5-axis operations error out.
- Cutter/radius compensation must be **In computer**; control-side G41/G42 is a posting
  error.
- **A Setup built on a tilted face is refused**, with the tilt named — the tool only moves
  straight down, so a Setup whose Z is not the machine's Z would cut in the wrong plane.
- **CAM probing operations are refused.** The post's own Z touch-off is not one of them; a Fusion
  WCS-probing operation asks the controller to measure and store an offset, which none of these
  controllers can do.
- Arcs are on the XY plane (Marlin/RepRap) or all planes (GRBL); full circles post as two
  arcs; helical moves are linearised.
- Canned cycles (drill/peck/bore/tap) are expanded into plain G0/G1/G4 moves. **No supported
  firmware has them** — and on RepRap those g-code numbers mean bed probing instead, which is
  worse than absent.
- Manual NC **Pass through** commands are emitted verbatim.
- **`M1` (optional stop) is emitted as `M0`.** No supported firmware gives the *optional* half a
  usable meaning: GRBL parses `M1` and does nothing, RepRap treats it as end-of-job, and only
  Marlin waits for the LCD. The file says so where it happens.
- **Travel Speed X/Y and Travel Speed Z do nothing on GRBL or FluidNC.** Their planner takes a
  rapid's rate from the axis maximums held in the controller, not from the `F` word in the block,
  and no line a posted file may contain changes that. Marlin and RepRap obey both.
- **End of program differs by firmware.** GRBL ends with `M30`. Marlin and RepRap get
  `M84 S60` first, restoring the 60-second idle timeout the post disables for the duration of
  the job (a bare `M84` would drop an unbalanced gantry in Z). RepRap then gets `M2`, which it
  has supported since RRF 3.5.1 and which runs your `stop.g` — if that macro disables the
  steppers, it overrides the timeout just set. Marlin gets no program-end code because it has
  never implemented one: `M2` is unknown there and `M30` means "delete SD file", so on Marlin
  the end of the file *is* the end of the program.
- **No `%` wrapper is written, on any firmware** — stock Grbl 1.1 has no `%` feature, so the line
  reaches the parser and answers `error:1`.
- GRBL laser jobs likely need laser mode enabled
  ([`$32=1`](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Laser-Mode)).
- **Firmware claims in these documents are settled from each firmware's own source and
  changelog, with the file and version cited.** This project has no controller to test against,
  so nothing here is proved by having been run on a machine — see
  [what is verified](docs/guide-pro.md#what-is-verified-and-what-is-not).

---

# Resources

- [Marlin G-codes](https://marlinfw.org/meta/gcode/)
- [GRBL 1.1 wiki](https://github.com/gnea/grbl/wiki)
- [FluidNC wiki](http://wiki.fluidnc.com/)
- [Duet / RepRapFirmware G-code reference](https://docs.duet3d.com/User_manual/Reference/Gcodes)
- [PostProcessor Class Reference](https://cam.autodesk.com/posts/reference/classPostProcessor.html)
- [Post Processor Training Guide (PDF)](https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf)
- [Dumper PostProcessor](https://cam.autodesk.com/hsmposts?p=dump)
- [Library of existing post processors](https://cam.autodesk.com/hsmposts)
- [Post processors forum](https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218)
