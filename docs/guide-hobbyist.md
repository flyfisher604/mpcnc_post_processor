Hobbyist guide — cutting one part
====

**This guide is for you if** you are cutting one part, in one Fusion Setup, with one tool, and
you zero the machine by hand before you send the job. That is the job this post is easiest at,
and most of the dialog does not apply to it.

Milling several parts on separate fixtures, or changing tools mid-job? Read the
[pro guide](guide-pro.md) instead. **A two-tool job is a separate case and it is covered here** —
see [two tools means two files](#two-tools-means-two-files), because on the shipped settings a
multi-tool job does not post at all.

- [The short version](#the-short-version)
- [Working through the dialog](#working-through-the-dialog)
- [How the post learns where your part is](#how-the-post-learns-where-your-part-is)
- [Jogging to the origin while the job is paused](#jogging-to-the-origin-while-the-job-is-paused)
- [Turning the router on and off](#turning-the-router-on-and-off)
- [Feeds, and keeping them inside your machine](#feeds-and-keeping-them-inside-your-machine)
- [Two tools means two files](#two-tools-means-two-files)
- [If you are on a Personal licence](#if-you-are-on-a-personal-licence)
- [When the post refuses to run](#when-the-post-refuses-to-run)

---

## The short version

Out of 57 settings, **eight** decide whether your first job comes out right:

| Setting | Group | Why it matters |
|---|---|---|
| **CNC Firmware** | 1 | Everything else is written in this dialect. Set it first. |
| **Spindle Control** | 1 | Whether the post asks you to switch the router on, or commands it itself. |
| **Max XY / Max Z Cut Speed** | 2 | Your machine's real cutting limits. Cut feeds are scaled to stay inside them. |
| **Travel Speed X/Y**, **Travel Speed Z** | 2 | How fast the machine moves when it is not cutting — **on Marlin and RepRap only.** GRBL and FluidNC ignore both. |
| **Map G1s -> G0 Rapids** | 3 | Only on a Fusion **Personal** licence, which posts every rapid as a slow cutting move — one of which drags the bit across your work. Ships **off**; whether to turn it on is [your call](#if-you-are-on-a-personal-licence). On a full licence, leave it off. |
| **First WCS / Part** | 5 | How the post learns where your part is. |
| **G38 Target** | 5 | Only if you probe — how far down the probe may search before it gives up. |
| **Plate Thickness** | 5 | Only if you probe — measure your own plate. |

Everything else can stay as it ships. Groups **4**, **6**, **7**, **8**, **9** and **10** are for
machines and jobs you do not have yet.

Then: **jog the tool to your part's corner, and post.**

---

## Working through the dialog

The groups are numbered in the order it makes sense to read them.

**1 - Job.** Set **CNC Firmware** to your controller — FluidNC is `Grbl`. Leave **Spindle Control** at
*Prompt the operator* if you switch your router on by hand; most people do. **Leave Comment Level at
`Info`.** On GRBL that is not cosmetic: gSender deletes an `M0` prompt that falls inside the first
ten lines it sends, and at `Info` the property dump puts about seventy lines ahead of every prompt
in the preamble. The post warns you if a lower level puts a real prompt at risk.

**2 - Feeds and Speeds.** Set **Max XY Cut Speed** and **Max Z Cut Speed** to what your machine
can really do while cutting. **Scale Feedrate** is on, so the post holds every cut feed inside
those numbers — which is only useful if the numbers are yours. The values it ships with are generic
MPCNC figures; if your machine is faster, leaving them will quietly slow every cut.

**Travel Speed X/Y** and **Travel Speed Z** are worth setting on Marlin and RepRap, which obey
them. **On GRBL and FluidNC they do nothing at all** — that planner takes a rapid's speed from the
axis maximums held in the controller and ignores the `F` word in the block, and no line a posted
file may contain changes that. If your GRBL machine travels too fast or too slow, the setting to
change is in the controller (`$110`–`$112` on stock GRBL, `max_rate_mm_per_min` per axis on
FluidNC), not here. The post says so in the file on every GRBL job.

**3 - Map G1s to Rapids.** Leave it alone unless you are on a Fusion Personal licence —
see [below](#if-you-are-on-a-personal-licence).

**4 - Machine Frame.** Skip it for a one-part, one-tool job. If your machine has no endstops there
is nothing to declare, and the tool parking at your work zero when the job ends is what you want
anyway. **One exception on Marlin** — see [two tools means two files](#two-tools-means-two-files).

**5 - Part Origins.** The one group to read properly — see
[the next section](#how-the-post-learns-where-your-part-is). If you probe, set **Plate
Thickness** to your own plate's thickness; an error here shifts every cut in the job by the same
amount.

**6 - Tool Changes.** Skip it for a one-tool job. **If your job uses two tools it will not post**
on the shipped setting — the post refuses it and tells you to split the file. That is deliberate;
see [two tools means two files](#two-tools-means-two-files).

**7 - External Include Files.** Skip it. Be aware that a **Start** or **Stop** file *replaces*
that part of the program rather than adding to it, so it is not a place to drop in one extra
line.

**8 - Laser**, **9 - Coolant**, **10 - Duet.** Skip unless you have that hardware.

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

The other four modes matter once you have pre-set fixtures or more than one part — they are
covered in the [pro guide](guide-pro.md#origin-modes-in-full). Two of them pause the job so you
can jog to the origin mid-run, which is a supported workflow with one condition attached — see
[the next section](#jogging-to-the-origin-while-the-job-is-paused).

**About G38 Target.** It is **how far down the probe may search**, not a height: `-10` searches
10 mm below wherever the tool starts. On the two `Set … to Current Pos` modes the tool starts at
the origin you just jogged to, so `-10` really means "at most 10 mm down". Set it deep enough to
reach your plate and no deeper — a probe that reaches the end of its search without touching stops
the job with an alarm.

**Probing away from the corner.** If your part origin sits off the material — a corner in fresh
air, say — **Probe X Y Offset** moves the touch-down point somewhere solid while the origin stays
where you put it. It takes two numbers separated by a comma, in mm: `30, -15` moves the probe 30 mm
in +X and 15 mm in -Y.

---

## Jogging to the origin while the job is paused

Two of the origin modes — **`Jog to X0 Y0, Probe Z0`** and **`Jog to X0 Y0 Z0`** — and the
*Pause, then Home* option stop the program and expect you to move the machine by hand before
resuming. **This is a supported workflow, and it is the one to use when you want to index the
machine during the run** rather than pre-jogging before line 1: the post pauses, you drive the tool
to the origin, resume, and it records where you left it.

**What holds the pause decides whether you can move at all**, and it differs by firmware:

- **GRBL / FluidNC — it depends on your sender, not on GRBL.** GRBL only accepts a jog command
  when the controller is `Idle`, and a controller that *received* an `M0` is in a hold that
  refuses them. But a streaming sender decides whether the `M0` ever reaches the controller:
  **gSender comments it out and pauses its own stream instead**, so the controller stays `Idle` and
  jogs normally. A sender that forwards the `M0` produces the hold. Check yours before you rely on
  it — the post states the condition in the file and in the post dialog.
- **RepRap / Duet — yes, natively.** The post emits `M291 … X1 Y1 Z1`, a real firmware
  jog-at-pause, and you get an on-screen dialog with jog buttons.
- **Marlin — use the machine's own panel.** Marlin's `M0` blocks in a loop that queues serial
  commands without executing them, so a jog sent down the wire from your computer does not move the
  machine until you release the pause, and then runs late. The panel's move-axis menu is not g-code
  and works fine.

If none of that fits your setup, position the tool before starting the file and use a
`Set … to Current Pos` mode instead.

---

## Turning the router on and off

Most MPCNC builds use a trim router with a physical switch, so **Spindle Control** ships at *Prompt
the operator (M0)* and the post sends no spindle code at all. Instead it stops the machine and asks:

- at the start — *"Turn ON 12000 RPM"*;
- whenever the job wants a different speed or direction — *"Set spindle to 10000 RPM
  clockwise"*, always stating the whole target so there is nothing to remember;
- at the end, and at any tool change — a prompt to switch **off**. At the end this comes *before*
  the tool travels back to X0 Y0, so you switch off, resume, and it parks.

If your spindle is switched by the controller, one of the other three modes commands it and the
prompts go away:

- **`Spindle - M3 S{RPM}/M5`** — a real spindle, with speed and direction under the controller's
  control. **On Marlin, check your build first:** `M3`/`M5` are behind build options there, and a
  stock Marlin has neither `SPINDLE_FEATURE` nor `LASER_FEATURE` — it answers `M3` with an
  unknown-command warning and runs the whole job with the spindle never started. V1 Engineering's own
  V1CNC builds enable `LASER_FEATURE`, where `M3` does switch the pin, but `S` is read as cutter
  power rather than RPM.
- **`Fan - M106 P{n} S255/S0`** — a relay wired to a fan header.
- **`Pin - M42 P{pin} S255/S0`** — a relay on a spare output pin. `M42` is compiled only where
  `DIRECT_PIN_CONTROL` is enabled, which stock Marlin ships commented out, and Marlin refuses it on a
  protected pin — which every fan pin is, so a fan header needs the mode above, not this one.

The two switched-output modes are **on or off only**: they carry no speed and no direction, and the
RPM goes to a comment. Both take their output number from **Spindle: Pin/Fan #**, which means
different things on different firmware — a fan index or a board pin on Marlin, a fan or GpOut port
created by `M950` on RepRap. Neither `M106` nor `M42` is a GRBL code, so a GRBL job with either
selected is refused rather than posted.

---

## Feeds, and keeping them inside your machine

Rapids use **Travel Speed X/Y** and **Travel Speed Z** on Marlin and RepRap, and the controller's
own axis maximums on GRBL and FluidNC.

Cut feeds come from your CAM, but with **Scale Feedrate** on the post scales them down so no axis
is asked to move faster than **Max XY Cut Speed** or **Max Z Cut Speed**, then caps the result at
**Max Toolpath Speed**. Scaling only ever *reduces* a feed — it will never speed a cut up.

Arcs are scaled too, against the limits of the plane the arc lies in. An arc can come out slower
than the straight moves either side of it and still be right: a diagonal move splits its speed
across two axes, while an arc reaches full speed on one axis at a time.

---

## Two tools means two files

**A job with more than one tool does not post on the shipped settings.** **At a Tool Change** in
group 6 ships at *Refuse a multi-tool job*, and the post stops with a message telling you to split
the job. That is on purpose: this post changes no tool on any firmware, and the alternative to
refusing is a file that cuts every operation with whichever bit happens to be in the collet, at the
other tools' feeds and speeds.

**And on a Fusion Personal licence, two files is the only answer available** — Personal does not
emit tool changes at all, so Fusion itself gives you one file per tool.

So the hobby workflow for two tools is: post one file per tool, and run them back to back. **The
post is built to make the hand-off between them work**, and what it does at the end of the first
file is the whole of it:

- **Your X0 Y0 survives the file.** The first file ends without rewriting the work origin and
  **without homing**, so the origin you set at the start of file 1 is still the origin when file 2
  starts. You do not re-jog to the corner.
- **Z is yours to re-establish**, because the new bit is a different length. Start file 2 in a mode
  that measures Z — the shipped **`Set X0 Y0 to Current Pos, Probe Z0`** does exactly this — or
  touch the new bit off by hand and use `Set X0 Y0 Z0 to Current Pos`.
- **The router is prompted off before the tool parks**, so you switch off, resume, and the machine
  parks at X0 Y0 with the collet where you can reach it.

> **On Marlin, do not park at machine X0 Y0 between the two files.** Setting **At End Park At** to
> `Machine X0 Y0` **homes** X and Y on Marlin rather than rapiding there, and homing zeroes the work
> origin this file established — so file 2 would cut against an origin you never set. Leave it at
> `Work X0 Y0`. The post warns about this, and the same rule is why the post never homes at the end
> of a file on any firmware. (Marlin behaviour here is read from source at 2.0.9.7 and 2.1.2.5;
> **2.0.9.7 is the oldest Marlin this post's claims cover** — below that, nothing was checked.)

If you have a full licence and want the change to happen inside one file, that is group 6 and it is
the [pro guide's subject](guide-pro.md#tool-changes).

---

## If you are on a Personal licence

The Fusion Personal licence does not emit rapid moves. Every `G0` comes out as a `G1` cut move at
cutting speed, which means the trip from one cut to the next is slow, and the move to the start
of a toolpath can drag the bit across your work.

Group **3 - Map G1s to Rapids** can convert those moves back into rapids where it is safe to —
moves at or above a height you nominate, which the post treats as air. **It ships off, and
turning it on is your decision, not the post's.** It is a workaround for a limitation of your
licence, and whether to use it is yours to weigh.

**One switch covers all three of the moves Personal turns into cuts:** horizontal moves at or above
**Safe Z**, retracts and descents that stay above it, and each operation's first move — the "tool
dragged across the work" one. A real cutting move is never converted, and the post already emits
every rapid as two separate moves, Z then XY, ordered so the tool lifts before it travels and
travels before it descends.

**The height it reads is group 5's Safe Z** — the same number the tool retracts to after probing.
Group 3 has no height field of its own, so lowering Safe Z lowers it for both. It is in your part's
coordinates, measured from the Z0 at the stock top, not from machine zero; `Retract:15` means "the
operation's own Fusion retract level, or 15 mm if it hasn't got one".

On a full licence you do not need it: Fusion already emits real rapids. At the default threshold it
also converts nothing if you leave it on — but the check still runs, so a lowered threshold could
catch a real cutting move. Leave the group off on a full licence.

---

## When the post refuses to run

The post checks your job before it writes anything, and refuses rather than producing g-code it
knows is wrong. The message says what to change. The ones a one-part job can hit:

- **More than one tool**, with group 6 at its shipped setting — see
  [above](#two-tools-means-two-files).
- **A 4- or 5-axis toolpath.** Not supported; only 3-axis.
- **Cutter compensation set to anything but *In computer*.** Change it in the operation.
- **A probing operation in the CAM.** Fusion's WCS probing asks the controller to measure and store
  an offset, which none of these controllers can do. The post's own Z touch-off is unaffected.
- **A named include file that does not exist** in the NC output folder.
- **Spindle Control set to a fan or pin output on a GRBL job.** `M106` and `M42` are Marlin and
  RepRap commands; GRBL answers either with `error:20` and stops with the tool in the cut. Pick a
  mode your controller has, or set **CNC Firmware** to what the machine really runs.
- **Spindle Control set to the pin output with Spindle: Pin/Fan # still 0.** Pin 0 names no output
  anyone wired on purpose, so the post treats it as unset rather than emitting it. The laser and the
  two coolant channels are refused the same way when their own pin number is still 0.
- **Laser Output set to a `Mrln:` fan or pin value on a GRBL laser job**, for the same reason. A
  milling job is not refused for it — no laser code is emitted there at all — but a dialect
  mismatch of any kind warns.
- **A Setup built on a tilted face of the model.** The tool only moves straight down, so a Setup
  whose Z is not the machine's Z would cut in the wrong plane. Re-orient the Setup so its Z points
  up. *(This one is caught after the file has started being written, so discard the partial file
  it leaves.)*

It also **warns** without stopping. Warnings arrive in two places and it is worth knowing which:
a line in **Fusion's post dialog**, which you see when you post, and a `>>> WARNING:` line **in the
g-code**, which you see if you open the file. Conditions you could have posted differently appear
in both. Read the dialog — a job that posts is not necessarily a job that is right.

---

## Where next

- **[Property reference](property-reference.md)** — every one of the 57 settings.
- **[Pro guide](guide-pro.md)** — several parts, tool changes inside one file, the machine frame.
- **[README](../README.md)**
