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

# Which guide is for you

| | Read this |
|---|---|
| **One part, one tool, zeroed by hand.** You jog to your corner, post, and cut. | **[Hobbyist guide](docs/guide-hobbyist.md)** — six settings matter; the rest can stay as they ship |
| **Several operations, several tools, or several parts on their own fixtures.** | **[Pro guide](docs/guide-pro.md)** — work coordinate systems, fixed Z references, tool changes, the validation guards |
| **Looking up one setting.** | **[Property reference](docs/property-reference.md)** — all 69, in dialog order |

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

- A **one-part job** needs almost no setup. Jog to your zero, accept the defaults, post, run.
- A **larger job** — many operations, multiple tools, or several copies on separate fixtures —
  has the extra structure available and validated, without complicating the simple case.

Other capabilities: 3-axis milling and jet (laser / plasma / waterjet) operations;
canned drilling cycles expanded into plain moves; arcs; 3 laser power levels; two
configurable coolant channels; adjustable comment verbosity; optional line numbers;
external include files for custom g-code. Only 3-axis toolpaths are supported —
multi-axis operations are rejected with a clear error.

> **Units:** the post outputs in whatever units the Setup uses (mm or inch), **but all
> post properties must be entered in millimetres.**

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
7. Review and set the properties as needed — start with the guide for your kind of job, above.

![screenshot](/installation.jpg "install")

---

# Release history

## v4.0 Beta 2 — current

Beta 1 knew one zero: wherever the tool happened to be when the job started. Beta 2 can keep
track of several — the machine, the spoilboard, and each part — and move safely between them.

1. **More than one work zero.** Beta 1 set a single origin for the whole program. Beta 2 can
   store a separate zero for each part, in the controller's own memory, and switch between
   them as the job runs. (Marlin can still only hold one.)
   → [What a WCS is](docs/guide-pro.md#what-a-wcs-is-and-what-this-post-does-with-it)
2. **You choose how the zero gets set.** Beta 1 had two checkboxes. Beta 2 asks you to pick:
   use where the tool is now, use a zero the controller already has stored, or stop and let
   you jog to it — each with or without probing Z off a touch plate.
   → [Origin modes](docs/guide-pro.md#origin-modes-in-full)
3. **Several parts in one job.** Cut copies of a part on separate fixtures in a single run,
   re-probing each one so stock thickness can vary.
   → [Several copies on separate fixtures](docs/guide-pro.md#several-copies-on-separate-fixtures)
4. **Homing at job start**, if your machine has endstops — group **4**, which now separates
   *what your machine can home* from *what this job should do*.
   → [The machine frame](docs/guide-pro.md#the-machine-frame-homing)
5. **A fixed Z reference** — group **5**. Zero to the spoilboard, or to the machine's own homed
   Z, rather than to the stock, so the tool can lift to a height that clears everything on the
   bed before it travels to another part. → [A fixed Z reference](docs/guide-pro.md#a-fixed-z-reference)
6. **Unsafe jobs are refused before any file is written**, with a message saying what to
   change, and several common mistakes now warn you.
   → [Validation guards](docs/guide-pro.md#validation-guards)
7. **Better probing.** Prompts to attach and remove the probe, and the option to touch off
   away from the corner so the origin can sit off the material.
   → [Probing](docs/guide-pro.md#probing)
8. **The dialog was rebuilt** — 11 groups instead of 9, numbered in the order you work through
   them, and every setting is now listed at the top of the posted file.
   → [Property reference](docs/property-reference.md)
9. **Safer endings and clearer prompts.** The spindle stops *before* the tool parks; a hand-set
   router is prompted whenever the speed or direction changes, not just at the start; and each
   firmware now gets the right end-of-program code.
10. **Your saved settings carry over from Beta 1 only in part** — the dialog's internal keys were
    rebuilt, so expect to re-enter a customised preset once. **Check group 6 before your first
    job**: the origin choice is new and its default is not what Beta 1 did. Two defaults also
    moved during the Beta 2 series — **Scale Feedrate** is now on, and the coolant channel codes
    now default to the GRBL dialect rather than Marlin's.

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
- Arcs are on the XY plane (Marlin/RepRap) or all planes (GRBL); full circles are two
  arcs.
- Canned cycles (drill/peck/bore/tap) are expanded into plain G0/G1 moves.
- Manual NC **Pass through** commands are emitted verbatim.
- **End of program differs by firmware.** GRBL ends with `M30`. Marlin and RepRap get
  `M84 S60` first, restoring the 60-second idle timeout the post disables for the duration of
  the job (a bare `M84` would drop an unbalanced gantry in Z). RepRap then gets `M2`, which it
  has supported since RRF 3.5.1 and which runs your `stop.g` — if that macro disables the
  steppers, it overrides the timeout just set. Marlin gets no program-end code because it has
  never implemented one: `M2` is unknown there and `M30` means "delete SD file", so on Marlin
  the end of the file *is* the end of the program.
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
