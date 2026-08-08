Hobbyist guide — cutting one part
====

**This guide is for you if** you are cutting one part, in one Fusion Setup, with one tool, and
you zero the machine by hand before you send the job. That is the job this post is easiest at,
and most of the dialog does not apply to it.

Milling several parts on separate fixtures, changing tools mid-job, or using more than one work
zero? Read the [pro guide](guide-pro.md) instead.

- [The short version](#the-short-version)
- [Working through the dialog](#working-through-the-dialog)
- [How the post learns where your part is](#how-the-post-learns-where-your-part-is)
- [Turning the router on and off](#turning-the-router-on-and-off)
- [Feeds, and keeping them inside your machine](#feeds-and-keeping-them-inside-your-machine)
- [If you are on a Personal licence](#if-you-are-on-a-personal-licence)
- [Jogging while the job is paused](#jogging-while-the-job-is-paused)
- [When the post refuses to run](#when-the-post-refuses-to-run)

---

## The short version

Out of 69 settings, **six** decide whether your first job comes out right:

| Setting | Group | Why it matters |
|---|---|---|
| **CNC Firmware** | 1 | Everything else is written in this dialect. Set it first. |
| **Manual Spindle On/Off** | 1 | Whether the post asks you to switch the router on, or tries to do it itself. |
| **Travel Speed X/Y**, **Travel Speed Z** | 2 | How fast the machine moves when it is not cutting. |
| **Max XY / Max Z Cut Speed** | 2 | Your machine's real limits. Cut feeds are scaled to stay inside them. |
| **First WCS / Part** | 6 | How the post learns where your part is. |
| **Plate Thickness** | 6 | Only if you probe — measure your own plate. |

Everything else can stay as it ships. Groups **4**, **5**, **7**, **8**, **9**, **10** and **11**
are for machines and jobs you do not have yet.

Then: **jog the tool to your part's corner, and post.**

---

## Working through the dialog

The groups are numbered in the order it makes sense to read them.

**1 - Job.** Set **CNC Firmware** to your controller. Leave **Manual Spindle On/Off** on if you
switch your router on by hand — most people do. Everything else can stay.

**2 - Feeds and Speeds.** Set **Travel Speed X/Y** and **Travel Speed Z** to what your machine
can actually do when it is not cutting, and **Max XY Cut Speed** / **Max Z Cut Speed** to what it
can do while cutting. **Scale Feedrate** is on, so the post holds every cut feed inside those two
numbers — which is only useful if the numbers are yours. The values it ships with are generic
MPCNC figures; if your machine is faster, leaving them will quietly slow every cut.

**3 - Map G1s to Rapids.** Leave it alone unless you are on a Fusion Personal licence —
see [below](#if-you-are-on-a-personal-licence).

**4 - Machine Frame.** Skip it. If your machine has no endstops there is nothing to declare, and
the tool parking at your work zero when the job ends is what you want anyway.

**5 - Fixed Z Reference.** Skip it. It exists so a job can lift to a height that clears several
parts of different thickness, which a one-part job never needs.

**6 - On WCS / Part / Fixture Changes.** The one group to read properly — see
[the next section](#how-the-post-learns-where-your-part-is). If you probe, set **Plate
Thickness** to your own plate's thickness; an error here shifts every cut in the job by the same
amount.

**7 - Tool Changes.** Skip it for a one-tool job. If your job does use two tools and you leave
this off, the post warns you and marks each skipped change in the file — it will not quietly cut
with the wrong bit.

**8 - External Include Files.** Skip it. Be aware that a **Start** or **Stop** file *replaces*
that part of the program rather than adding to it, so it is not a place to drop in one extra
line.

**9 - Laser**, **10 - Coolant**, **11 - Duet.** Skip unless you have that hardware.

---

## How the post learns where your part is

Your machine has no idea where your stock is. **First WCS / Part** is how you tell it.

Two of the six modes cover almost every hobby job:

**`Set X0 Y0 to Current Pos, Probe Z0`** — the default, and the one to use **if you have a touch
plate wired up**. Before you post, jog the tool to your part's X0 Y0 corner in your sender. The
post records that spot as the origin, then probes down onto your plate to find the top of the
stock. Keep **Probe Pause** at `Before & After` and it will stop and ask you to clip the probe on
first and take it off afterwards.

> **If you have no probe, do not use the default.** It will drive the tool down looking for a
> plate that is not there, and stop with an alarm when it does not find one.

**`Set X0 Y0 Z0 to Current Pos`** — use this **if you have no touch plate**. Jog to the corner
*and* touch the tool down onto the top of the stock yourself (a slip of paper under the bit is
the usual trick), then post. The post takes the tool's current position as X0 Y0 Z0 and does not
probe at all.

The other four modes matter once you have more than one part or pre-set fixtures — they are
covered in the [pro guide](guide-pro.md#origin-modes-in-full). Two of them pause the job so you
can jog to the origin mid-run, and **those two do not work on GRBL** — see
[below](#jogging-while-the-job-is-paused).

**Probing away from the corner.** If your part origin sits off the material — a corner in fresh
air, say — **Probe X Offset** and **Probe Y Offset** move the touch-down point somewhere solid
while the origin stays where you put it.

---

## Turning the router on and off

Most MPCNC builds use a trim router with a physical switch, so **Manual Spindle On/Off** is on by
default and the post never sends `M3` or `M5`. Instead it stops the machine and asks:

- at the start — *"Turn ON 12000 RPM"*;
- whenever the job wants a different speed or direction — *"Set spindle to 10000 RPM
  clockwise"*, always stating the whole target so there is nothing to remember;
- at the end, and at any tool change — a prompt to switch **off**. At the end this comes *before*
  the tool travels back to X0 Y0, so you switch off, resume, and it parks.

If your spindle is switched by the controller, turn the property off and you get real `M3 S…` and
`M5` with no prompts.

---

## Feeds, and keeping them inside your machine

Rapids always use **Travel Speed X/Y** and **Travel Speed Z**.

Cut feeds come from your CAM, but with **Scale Feedrate** on the post scales them down so no axis
is asked to move faster than **Max XY Cut Speed** or **Max Z Cut Speed**, then caps the result at
**Max Toolpath Speed**. Scaling only ever *reduces* a feed — it will never speed a cut up.

Arcs are scaled too, against the limits of the plane the arc lies in. An arc can come out slower
than the straight moves either side of it and still be right: a diagonal move splits its speed
across two axes, while an arc reaches full speed on one axis at a time.

---

## If you are on a Personal licence

The Fusion Personal licence does not emit rapid moves. Every `G0` comes out as a `G1` cut move at
cutting speed, which means the trip from one cut to the next is slow, and the move to the start
of a toolpath can drag the bit across your work.

Group **3 - Map G1s to Rapids** can convert those moves back into rapids where it is safe to —
moves at or above a height you nominate, which the post treats as air. **It ships off, and
turning it on is your decision, not the post's.** It is a workaround for a limitation of your
licence, and whether to use it is yours to weigh.

If you do enable it: the post already emits every rapid as two separate moves, Z then XY, ordered
so the tool lifts before it travels and travels before it descends. A real cutting move is never
converted.

On a full licence this group does nothing at all, whatever you set — Fusion emits real rapids and
the conversion never runs.

---

## Jogging while the job is paused

Two of the origin modes, and the *Pause, then Home* option, stop the program and expect you to
move the machine by hand before resuming. **Whether you actually can depends on your firmware:**

- **GRBL / FluidNC** — **no.** GRBL only accepts a jog command when it is idle, and a paused
  program is not idle. The post warns you if you pick a Jog mode on GRBL, and says so in the file
  too. Use a pre-jog mode instead.
- **RepRap / Duet** — yes, properly. You get an on-screen dialog with jog buttons.
- **Marlin** — jog from the machine's own LCD while it is paused. Jog commands sent from your
  computer just queue up behind the pause.

---

## When the post refuses to run

The post checks your job before it writes anything, and refuses rather than producing g-code it
knows is wrong. The message says what to change. The ones a one-part job can hit:

- **A 4- or 5-axis toolpath.** Not supported; only 3-axis.
- **Cutter compensation set to anything but *In computer*.** Change it in the operation.
- **A Setup built on a tilted face of the model.** The tool only moves straight down, so a Setup
  whose Z is not the machine's Z would cut in the wrong plane. Re-orient the Setup so its Z points
  up. *(This one is caught after the file has started being written, so discard the partial file
  it leaves.)*

It also **warns** without stopping — the message shows in Fusion's post dialog — when your job
uses more than one tool with group 7 switched off, and in a few other cases where the setup is
unusual rather than wrong.

---

## Where next

- **[Property reference](property-reference.md)** — every one of the 69 settings.
- **[Pro guide](guide-pro.md)** — several parts, several tools, several work zeros.
- **[README](../README.md)**
