Fusion 360 CAM Post Processor for GRBL, Marlin, RepRap & FluidNC
====

A Fusion 360 CAM post processor for hobby-class 3-axis CNC machines running GRBL, FluidNC, Marlin
or RepRapFirmware — including the V1 Engineering MPCNC and LowRider, and similar builds.

**Current release: v4.1.2 Beta 3**, distributed as the single file `MPCNC_v4.1.2_Beta3.cps`.

**[Download the post](https://github.com/flyfisher604/mpcnc_post_processor/releases/latest)** ·
[What changed](CHANGELOG.md) ·
[Release notes](docs/release-notes-v4.1.2-beta3.md)

This is a modified fork of
[guffy1234/mpcnc_posts_processor](https://github.com/guffy1234/mpcnc_posts_processor),
originally forked from
[martindb/mpcnc_posts_processor](https://github.com/martindb/mpcnc_posts_processor).

- [Supported firmware](#supported-firmware)
- [Installation](#installation)
- [Which guide is for you](#which-guide-is-for-you)
- [What this post does](#what-this-post-does)
- [Notes and limitations](#notes-and-limitations)
- [Resources](#resources)

---

# Supported firmware

Choose your firmware with **CNC Firmware**, the first setting in group **1 - Job**.

| Your controller runs | Choose | Notes |
|---|---|---|
| GRBL 1.1 | **Grbl** | |
| FluidNC | **Grbl** | The g-code is GRBL's. Warnings that depend on a setting name both GRBL's and FluidNC's, and tool changes have a FluidNC option of their own |
| Marlin 2.x | **Marlin** | Read from source at 2.0.9.7 and 2.1.2.5. **2.0.9.7 is the oldest version these documents cover** |
| RepRapFirmware (Duet3D) | **RepRap** | |
| Repetier 1.0.3 | **Marlin** | Untested; its g-code is Marlin's |

---

# Installation

The post is a single file. Download `MPCNC_v4.1.2_Beta3.cps` from the
[latest release](https://github.com/flyfisher604/mpcnc_post_processor/releases/latest), then:

1. In Fusion, choose **Manage → Post Library**.
2. Select **My posts → Local** in the sidebar.
3. **If an older copy is installed, select it and delete it** with the trash-can icon. Every
   release has a different filename, so an old copy would sit beside the new one rather than being
   replaced, and the two are hard to tell apart in the picker.
4. Use the **Import** icon to import `MPCNC_v4.1.2_Beta3.cps`.
5. Close the dialog.
6. When posting, choose **Choose from library…** and select this post.
7. Review the properties — start with the guide for your kind of job, below.

![screenshot](/installation.jpg "install")

**Upgrading?** Read the [changelog](CHANGELOG.md) entry for each release you are skipping. It
says which settings, if any, reset to their defaults.

---

# Which guide is for you

| Your job | Read this |
|---|---|
| **One part, one tool, zeroed by hand.** You jog to your corner, post, and cut. | **[Hobbyist guide](docs/guide-hobbyist.md)** — eight settings matter; the rest can stay as they ship |
| **Several operations, more than one tool, or several parts on their own fixtures.** | **[Pro guide](docs/guide-pro.md)** — work offsets, the machine travel height, tool-change hand-over, the validation guards |
| **Looking up one setting.** | **[Property reference](docs/property-reference.md)** — all 57, in dialog order |

---

# What this post does

The post turns a Fusion CAM program into g-code for a hobby CNC. One idea shapes every other
feature:

**These machines work relative to the part, not to the machine.** Most have no reliable machine-Z
reference — no tool setter, no tool-length register, often no Z endstop, sometimes no endstops at
all. So you establish a **work zero**, by jogging to it or probing a touch plate, and everything the
post emits — cuts, retracts, traverses between parts — is measured from it. Where a machine *can*
home, homing buys repeatability and one job-wide travel height, never the everyday Z reference.

Two consequences explain most of the dialog:

- **The post selects a work offset but can never read one back.** It always knows *which*
  register is active, because it selects it at job start. It never knows *where* that register
  points, because the contents live in the controller. So any mode that uses a stored origin
  **trusts** it, and the shipped defaults set an origin rather than trust one.
- **The post changes no tool, on any firmware.** A measured tool change needs a probe, a
  subtraction and a register to hold the result, and the post has none of the three. At a change it
  arrives safely, hands over to you or your sender, and resumes safely.

A **one-part, one-tool job** needs almost no setup: jog to your zero, accept the defaults, post,
run. A **larger job** — many operations, several tools, several parts on separate fixtures — has
the extra structure available and checked, without complicating the simple case.

**Also included:** 3-axis milling and jet (laser / plasma / waterjet) operations; drilling cycles
expanded into plain moves; arcs; three laser power levels; two configurable coolant channels; four
comment levels with every setting dumped at the head of the file; optional line numbers; include
files for your own g-code.

> **Units:** the post writes g-code in the units your Setup uses (mm or inch), **but every
> dimension in the dialog is entered in millimetres.** The head of each posted file echoes the
> values the post *resolved*, in output units, so you can check them before the machine moves.

---

# Notes and limitations

**What the post refuses**

- **4- and 5-axis toolpaths.** Only 3-axis is supported.
- **Cutter compensation other than *In computer*.** Control-side `G41`/`G42` is a posting error.
- **A Setup built on a tilted face**, with the tilt named. The tool only moves straight down, so a
  Setup whose Z is not the machine's Z would cut in the wrong plane.
- **CAM probing operations.** Fusion's WCS probing asks the controller to measure and store an
  offset, which none of these controllers can do. The post's own Z touch-off is unaffected.

**How some things come out**

- **Arcs** are on the XY plane on Marlin and RepRap, and on all planes on GRBL. Full circles post
  as two arcs; helical moves are broken into straight lines.
- **Drilling cycles** (drill, peck, bore, tap) are expanded into plain `G0`/`G1`/`G4` moves. No
  supported firmware has canned cycles — and on RepRap those numbers mean bed probing instead.
- **Manual NC pass-through** commands are emitted exactly as written.
- **`M1` (optional stop) is emitted as `M0`.** No supported firmware gives `M1` a usable meaning:
  GRBL ignores it, RepRap treats it as end of job, and only Marlin waits.
- **Travel Speed X/Y and Travel Speed Z do nothing on GRBL or FluidNC.** Those controllers take
  rapid speed from their own axis maximums, not from the g-code. Marlin and RepRap obey both.
- **The end of the program differs by firmware.** GRBL ends with `M30`. Marlin and RepRap first get
  `M84 S60`, restoring the stepper idle timeout the post disables during the job. RepRap then gets
  `M2`, which runs your `stop.g`. Marlin gets no end code: it has none, and its `M30` means
  "delete SD file".
- **No `%` line** is written on any firmware — stock GRBL 1.1 answers it with `error:1`.
- **GRBL laser jobs** usually need laser mode turned on
  ([`$32=1`](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Laser-Mode)).

**How the claims here are checked**

Firmware behaviour in these documents is read from each firmware's own source and changelog, with
the file and version cited. This project has no controller to test against, so nothing here is
proved by running it on a machine. The post itself *is* run, by an automated suite against
Autodesk's own post engine — see
[what is verified, and what is not](docs/guide-pro.md#what-is-verified-and-what-is-not).

**This is a beta. Review your g-code before you cut.**

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
