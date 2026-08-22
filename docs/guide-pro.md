Pro guide — several parts, several tools, the machine frame
====

**This guide is for you if** your job has more than one operation, more than one tool, or more
than one part on its own fixture — the things a full Fusion licence lets you build. It assumes
you are comfortable with CNC terms; the [hobbyist guide](guide-hobbyist.md) covers the one-part
job in plainer language, and everything in it still applies here.

- [What a work offset is, and what this post does with it](#what-a-work-offset-is-and-what-this-post-does-with-it)
- [What the operator owes the job](#what-the-operator-owes-the-job)
- [Many operations, one part](#many-operations-one-part)
- [Several parts in one job](#several-parts-in-one-job)
- [Origin modes in full](#origin-modes-in-full)
- [What a stored origin means](#what-a-stored-origin-means)
- [The machine frame, and the travel height](#the-machine-frame-and-the-travel-height)
- [Probing](#probing)
- [Tool changes](#tool-changes)
- [External include files](#external-include-files)
- [Validation guards](#validation-guards)
- [What is verified, and what is not](#what-is-verified-and-what-is-not)

---

## What a work offset is, and what this post does with it

A **work offset** — a WCS — is an origin the controller remembers. `G54` through `G59` on every
supported firmware, plus `G59.1`–`G59.3` on Marlin and RepRap, each holding its own offset from
machine zero, so you can define several independent zeros and switch between them mid-program.

Fusion assigns one per Setup through its **Work Offset** field (1 → `G54`, 2 → `G55`, …). This
post emits the matching selection whenever it changes. **Work offset 0 is Fusion's "default", not a
request for machine coordinates** — the post resolves it to WCS 1 / `G54`, and warns if one Setup
in a job names 0 while another names 1, since those are the same register under two labels.

Three facts shape everything below:

**The post selects an offset but can never read one back.** It always knows *which* register is
active, because it commands the selection itself at job start over whatever your sender left modal
— you do not need to pre-select anything. It never knows *where* that register points: register
contents are controller-side runtime state and g-code generation is one-way. So every mode that
uses a stored origin **trusts** it.

**Homing does not change a work offset — it makes one trustworthy.** `G54`–`G59` hold offsets from
machine zero, and homing never touches those registers. Unhomed, machine zero is wherever the
controller was last reset — still fixed for *that* power cycle, so origins the job **creates**
during a run stay mutually consistent, and a multi-part job on a machine with no endstops would be
sound in that narrow sense. What goes bad is a **stored** offset, written by an earlier job or an
earlier power cycle. That is why the guard is mode-sensitive rather than blanket.

**Marlin has the registers too, behind one build option.** `CNC_COORDINATE_SYSTEMS` gates `G53`
*and* `G54`–`G59` in a single `#if`, so a Marlin build has the machine frame **and** nine work
offsets together, or neither. The post assumes the option is on and **warns** rather than refusing —
refusing would deny the feature to every correctly configured CNC Marlin, and the post cannot read a
build. Without it, `G53` is an unknown command and every travel-height move is silently skipped.
*(Read from `Marlin/src/gcode/gcode.cpp` and `src/gcode/geometry/G92.cpp` at 2.0.9.7 and 2.1.2.5;
those two versions are the floor for every Marlin claim in these documents.)*

---

## What the operator owes the job

**Fusion states none of this anywhere, and the emitted g-code depends on all of it.** F360 never
learns where your fixtures are, so it cannot compute a path between work offsets and does not
claim to; the post carries that logic, and the *orchestration* above it is yours. These are the
preconditions a posted file assumes. Nothing in the file can check them.

**1. Every work offset the job names is already set, at the machine, before the file is sent.**
On the `Use WCS …` modes the post rapids to a stored X0 Y0 and cuts there. **The post never sets XY
for a part after the first** unless you choose a `Jog to …` mode — so each fixture's offset is
yours to establish and yours to keep unmoved. On a fresh controller every offset is `0`, which makes
`G54` mean machine coordinates — on an unhomed machine, wherever it powered on. Do not point a
`Use WCS …` mode at a register that has never been set.

**2. One height clears everything on the bed, and you measured it.** *Machine Travel Z* is a single
number used for every traverse between parts and every tool-change excursion. It has to clear the
tallest clamp, the tallest part and the tallest fixture in the job at once. Get it the way it is
meant to be got: **home, jog to a height that visibly clears everything, read Z off your sender.**
It is collected, never computed — a height read after homing is already in the controller's own
frame, which is what makes it immune to everything else in the dialog.

**3. The machine is homed — by this job, or by you at the controller before the file runs.** A
stored offset only points at the same physical place across power cycles on a machine that homes
X/Y, and *Machine Travel Z* only means anything against a machine zero that has been established.
`Axes Homed and Trusted` is the declaration that this is true; `Home at Job Start` is the separate
question of whether *this file* does the homing. Declaring without doing is a legitimate answer —
homed once at the controller and left alone all session — and it is entirely on you. On GRBL a stale
declaration cannot execute: with homing enabled GRBL comes up in Alarm and refuses all motion until
homed. **RepRap has no such lock**, so the post warns there when the machine frame is in use with
`Home at Job Start` off, and Marlin never reaches the question.

**4. The tool in the spindle at line 1 is the one the job starts with** — unless you turn
*First Tool is Correct* off, in which case the post arranges for it to be loaded *before* any origin
is recorded or probed, so Z0 is measured with the tool that will cut.

**5. Whoever performs a handed-over tool change is configured to perform it.** `M6` reaches a stock
Grbl or grblHAL controller as `error:20`, so on those the route exists only because your sender
intercepts the token before the controller sees it. **FluidNC is the exception — it executes the
`M6` itself**, dispatching to whatever `config.yaml` declares, and a sender set to strip the token
takes it away. Either way the post emits the token and **cannot see whether anything is listening**,
or whether what listens does anything. An ignored token means the rest of the job is cut with the
wrong tool, silently. **Test one change on air before trusting it.**

**6. Whoever corrects Z0 for the new tool's length actually does it.** *Tool Length Correction By*
is an assertion about your workflow, not a capability the post verifies. Choose the one that
describes what really happens at the change, because the post books the consequences differently —
see [tool changes](#tool-changes).

**7. The probe touch-point is on uncut material at every probe.** A re-probe that lands in a pocket
the job already cut writes the machined depth as Z0, and every cut after it goes that much deeper.
The post detects the common case and warns, naming the operations and the depth; **Probe X Y Offset**
is the remedy.

**8. Your sender's behaviour at an `M0` is yours to know.** Whether you can jog at a pause, and
whether an `M0` early in the file survives at all, are sender properties — not firmware ones. See
[jogging at a pause](guide-hobbyist.md#jogging-to-the-origin-while-the-job-is-paused) and the
*Comment Level* note in the [property reference](property-reference.md#1---job).

---

## Many operations, one part

Several operations — face, pocket, contour — on one part in one Setup, so one work offset
throughout. This is the simplest job that is not the hobbyist's.

- **Leave group 3 off.** Its threshold is group 5's **Safe Z**, and at that field's default
  `Retract:15` it converts nothing on a full licence — a genuine cut always sits below the
  operation's retract level — so it only adds one comment per operation. But it is **not inert by
  construction**: the check runs on every cut move whatever your licence, and lowering Safe Z for
  the probe retract lowers this threshold with it, which makes real cutting moves eligible. Off is
  the only setting that cannot surprise you.
- **First WCS / Part**: if this Setup's offset is a pre-set fixture offset, use **`Use WCS X0 Y0,
  Probe Z0`** — rapid to the stored X0 Y0, re-probe the stock top. Otherwise take the default
  **`Set X0 Y0 to Current Pos, Probe Z0`** and pre-jog XY.
- **Fill in *Machine Travel Z* if your machine homes Z, even here.** A single-part job is never
  refused for want of it, but it is what turns the first section's arrival into a real absolute
  retract instead of a warning, and what lets the end-of-job park cross the bed at a known height.
- **No tool change is needed**, so group 6 stays at `Refuse a multi-tool job` and never fires.

---

## Several parts in one job

Parts on separate fixtures, one work offset each, cut in one program. **One part indexed from
several datums on one fixture is the same case** — each datum is a work offset, like a part. A flip
or a re-clamp is not: run those as separate jobs, because on a machine with no reliable frame the
post cannot establish the second reference's XY, and re-probing the same surface buys nothing.

**1. Declare and fill the machine frame.** Group 4: **Axes Homed and Trusted** = `XYZ`, and
**Machine Travel Z** filled with a height that clears every fixture. A multi-part job is **refused**
without both — no single clearance height is meaningful across offsets whose origins are only known
after runtime probing, and a stored offset is only repeatable on a machine with a homed X/Y zero.

**2. Put each part on its own Fusion Work Offset.** Their XY comes from each fixture's pre-set
offset; the post never sets XY for an added part unless you choose a `Jog to …` mode.

**3. Set the first part's origin.** **First WCS / Part** = **`Use WCS X0 Y0, Probe Z0`**, so the
first part takes its pre-set XY and re-probes Z exactly as the others will.

**4. Set what happens at each part after the first.** **Each New WCS / Part** — this is consulted
only at a genuine change of work offset, and only the *first* time the job reaches each part:

| Mode | What it does | When |
|---|---|---|
| **`Use WCS X0 Y0, Probe Z0 Once per Part`** *(default)* | Retracts to *Machine Travel Z*, rapids to that part's stored X0 Y0, re-probes its stock top | The best-practice path. Handles varying stock thickness |
| `Use WCS X0 Y0 Z0` | Retracts and rapids to the stored X0 Y0; no probe, the stored Z is trusted | Thickness is known-identical and already recorded |
| `Jog to X0 Y0, Probe Z0` / `Jog to X0 Y0 Z0` | Pauses so you jog to each part's origin | A setup run where the fixtures are *not* pre-set — and only where jogging at a pause works for you |

**5. Know what a *return* does, because it is not the same thing.** Coming back to a part the job
has already set up **sets nothing again** — the tool retracts, moves to its stored origin, and cuts.
That is deliberate: by then the probe point is a machined surface or air. **Only a tool change
re-opens a part's Z0**, and then only for the parts the post has marked stale.

**6. Every traverse retracts before it crosses.** The post emits a single `G53 G0 Z<Machine Travel
Z>` **before** the destination offset is selected, so no height is ever computed in a frame whose Z
origin the job has not established. Nothing is selected during the retract, so nothing has to be
restored.

---

## Origin modes in full

Group 5's two origin controls are one taxonomy with three families:

- **`Set … to Current Pos`** — no prompt. The tool is assumed already at the origin, because you
  pre-jogged it there. *(First part only.)*
- **`Use WCS …`** — no prompt. Trust the origin already stored in that register and rapid to it,
  either re-probing Z or trusting the stored Z too. The right path for pre-set fixtures.
- **`Jog to …`** — the post pauses so you jog to the origin during the run, then records it. This is
  the supported way to index the machine mid-job; whether you can move at that pause is a
  [sender and firmware question](guide-hobbyist.md#jogging-to-the-origin-while-the-job-is-paused).

Each family comes in a **probe-Z** variant and a **Z-manual** variant. **The defaults avoid any
run-time pause**, because jogging at one is not universally supported.

> **A jet tool or tool 0 never probes.** Any probe-Z mode degrades to recording the origin with
> no `G38.2`. On a probe-Z mode that means **Z0 is never established**, and the job runs against
> whatever the register already holds — the post warns in the file. For a laser or jet job choose
> **`Set X0 Y0 Z0 to Current Pos`** and set Z by hand.

> **Two modes take the preamble in reverse, and it matters if you are reading the output.** The two
> `Set … to Current Pos` modes do not travel to their origin — the origin *is* where you left the
> tool — so the machine-frame retract cannot come first: a `G53 G0 Z` carries one axis word, and it
> would overwrite the very Z the mode exists to record. On those modes the origin is written first
> and the frame established after. Every other mode establishes the frame, then arrives.

---

## What a stored origin means

**The offset your Fusion Setup designates — not the one your sender happens to have selected.**

- Each Setup carries a Work Offset. That is what the post uses.
- The post **selects** it at job start, before establishing any origin. Leave `G55` active in your
  sender while the Setup says WCS 1 and the file emits `G54` regardless. It overwrites the
  selection; it never inherits it.
- What the post cannot do is **read** that register. Its contents were written by a previous job
  or your own touch-off, and there is no round trip.

So: **which offset is certain; what it contains is trusted.**

| Mode | Safe when | Watch out for |
|---|---|---|
| `Use WCS X0 Y0, Probe Z0` | XY fixtures pre-set and unmoved; thickness may vary | A fixture that shifted — XY is trusted blindly |
| `Use WCS X0 Y0 Z0` | Nothing has changed at all, thickness included | New stock — the stored Z is wrong |

> **`Use WCS X0 Y0, Probe Z0` on a job with no machine frame is the one arrival worth reading
> twice.** The rapid to the stored X0 Y0 is an **X/Y move**, made at whatever height the tool
> happens to be holding, and the `G38.2` that follows searches **down from that same height**. So one
> height decides both whether the crossing clears your work and whether the probe can reach the
> stock. With `Home at Job Start` on, that height is the **endstop's** and no jog before line 1
> reaches it — and neither end of the travel is right: at the top the stock is a whole travel below
> and the probe never touches; at the bed the search starts just above it and runs down into it.
> **Filling *Machine Travel Z* removes both problems**, by giving the post a Z it can move in
> itself. The post warns in both channels, with different text depending on who chose the height.

> **`Use WCS X0 Y0 Z0` opens with a *move* to Safe Z, not a retract.** Safe Z is an absolute height
> in the stored frame, so a tool parked above it starts the job by **descending**, at Z travel
> speed, over ground the post knows nothing about. Park below Safe Z, or raise it.

---

## The machine frame, and the travel height

Group 4 separates two questions the old dialog ran together, and adds the one height that is
measured in the machine's own frame.

**`Axes Homed and Trusted`** is a **declaration** — a fact about your machine, set once: `None`,
`XY Only`, `Z Only`, `XYZ`. It is not an instruction to home anything. Z and X/Y are read
independently and neither implies the other: the travel height needs Z, and the stored-offset
warning and the machine park need X/Y.

**`Home at Job Start`** is **the action** for *this job*: `Off`, `Home`, or `Pause, then Home`.
A machine with endstops can be homed once at the controller and left alone all session, which is
why the two are separate. The pause is one stop before any homing motion, whatever the firmware and
however many axes home — long enough to place a movable Z plate or clear the bed.

What the post can emit differs by firmware, and on GRBL the axis split is bookkeeping rather than
emission:

| Firmware | Homing the post can emit |
|---|---|
| Marlin / RepRap | `G28 X` / `G28 Y` / `G28 Z` — genuinely independent per axis |
| GRBL | one `$H`. **Which axes that homes is compile-time** (`HOMING_CYCLE_0/1/2`, default Z then X\|Y); `$HX`/`$HY`/`$HZ` sit behind `HOMING_SINGLE_AXIS_COMMANDS`, off by default |
| FluidNC | single-axis homing is a configuration option, needing no rebuild — but this post treats FluidNC as GRBL throughout |

**So a GRBL job that declares `XY Only` still homes Z**, because one `$H` runs the whole cycle
whatever the dialog says. The post accounts for that where it matters.

### Machine Travel Z

**The machine's own homed Z is the only frame whose Z0 does not move with stock thickness**, which
makes it the only frame in which one clearance height is meaningful across parts of differing
thickness. **`Machine Travel Z`** is that height: an absolute machine coordinate, signed, usually
negative, read off your sender.

**The field is the whole opt-in.** There is no enum and no checkbox beside it — the frame exists
when the machine declares Z homed **and** `Machine Travel Z` parses, and not otherwise. It ships
empty, so an untouched dialog has no frame and a factory-default job emits exactly what it always
did. Filling it is the entire act of choosing one, at any part count.

**What it buys, at every part count:**

| | Without it | With it |
|---|---|---|
| Multi-part job | **refused** | traverses retract to it before crossing |
| Tool-change hand-over | **refused** for a manual position; warned otherwise | the tool lifts to it before handing over and returns to it after |
| First section's arrival | a warning: the traverse and the probe both happen at whatever height the tool holds | a real `G53 G0 Z` before anything else moves |
| End-of-job park at machine X0 Y0 | a warning: the crossing happens at the last cut's Z | a retract first |

**The number belongs to the machine, not the job.** It is the only absolute machine coordinate this
post emits, so unlike every other height in the dialog it does **not** stay correct when a Setup is
copied or a design is shared. **Transplant, not typing, is its hazard.**

**Sign, and why zero is not the ceiling.** On a stock Grbl build (`HOMING_FORCE_SET_ORIGIN` off)
homing leaves every reachable Z negative, so a positive value is above the top of travel — it alarms
at the first traverse with soft limits on and drives Z into its hard stop with them off. **Zero is
the point at which the endstop tripped**, and homing ends one pull-off *below* it, so a move to zero
returns the axis onto the switch and soft limits do not reject it. Set a height below machine zero
by at least the pull-off (`$27`). A machine built with `HOMING_FORCE_SET_ORIGIN` on zeroes at the
bed and takes a positive value — the post cannot read that setting and will warn every time. On
FluidNC the same hazard has a different name: the pull-off is `pulloff_mm`, set **per motor** rather
than per axis, and there is no `$27` to read or write.

**Units.** A `G53` move is read in the active `G20`/`G21`, so the mm you type here is converted, and
the file's *Resolved Values* block echoes the height **in output units**. Check it there.

**`At End Park At`** decides where the tool finishes: `Off`, `Work X0 Y0` (the **last operation's**
work origin — on a multi-part job, whichever fixture Fusion ordered last), or `Machine X0 Y0` (the
homing corner, one point for every job). The machine answer needs X/Y declared, and on GRBL and
RepRap also needs homing on. **Two firmware traps come with it**, both warned about:

- **On GRBL** it sends the tool to where the switches *tripped*, not to where homing left the
  machine — so with a stock build it drives X and Y back onto the switches, and with hard limits on
  the job ends in Alarm rather than parked.
- **On Marlin** it **homes** X and Y rather than rapiding there, and homing zeroes the work origin
  this file established. The registers survive, but a single-offset job never re-selects one — so a
  second file run afterwards starts against a zeroed origin. This is why **the post never homes at
  the end of a file**: it is a rule, not a preference.

---

## Probing

- **Work-Z only.** `G38.2` down to a touch plate, thickness compensated by **Plate Thickness**.
  There is no tool-length system anywhere in this post, and **X/Y is never probed**.
- **`G38 Target` is a distance, not a height** — "how far below the tool the probe may search".
  `-10` searches 10 mm down from wherever the tool starts. **Where the tool starts differs by
  mode**, and that is the whole subtlety: on the `Set … to Current Pos` modes it starts where you
  jogged; on the `Use WCS …` and added-part modes it starts at *Machine Travel Z*, so the target must
  reach the stock top from there. A probe that runs out of search without touching stops the job with
  an alarm.
- **Probe Pause** governs the attach/detach prompts, and applies to **every** probe in the job,
  tool-change re-probes included.
- **Probe X Y Offset** moves the touch-point away from the origin, job-wide, at every part probe.
  Use it when the origin is a corner in fresh air, or when the origin point is somewhere the job
  will later cut through. It is one field taking two comma-separated millimetre values — `30, -15` —
  and a value it cannot read falls back to `0, 0`, with a warning.
- **On RepRapFirmware 3.1.1 and earlier, turn *Probe with G38.2* off.** Up to that version `G38.x`
  takes a **machine-coordinate** target; this post emits a work-frame target, so leaving it on below
  3.1.2 probes to the wrong physical Z.

---

## Tool changes

**The post performs no tool change, on any firmware.** A measured change needs a probe, a
subtraction and a register to hold the result, and the post can supply none of the three: it cannot
compute an offset it will not learn until you swap the tool, hours after posting, and it can never
read a register back. **Its role is to arrive correctly, hand over, and resume correctly** — and
group 6 is what it does instead of changing a tool.

### Who performs the change

**`At a Tool Change`**, and it ships at the first answer:

| Answer | What happens | Needs |
|---|---|---|
| **`Refuse a multi-tool job`** *(default)* | A job with more than one tool **does not post**. Split it into one file per tool | — |
| **`Manual change at a pause`** | Retract to *Machine Travel Z*, move to the *Manual Position* if set, stop coolant and spindle, `M0` for you to swap the tool, then resume and re-probe | *Machine Travel Z*; X/Y homed if a position is set |
| **`Sender or firmware macro changes it`** | The same retract and stops, then the token named by *Tool Change Handled By*. The post then re-asserts absolute mode, units and the work offset, and returns to *Machine Travel Z* | *Machine Travel Z*; **not available on Marlin** |

**Refusing is not an omission.** The alternative is a file that cuts every operation with whichever
bit is in the collet, at the other tools' feeds and speeds. If you want the two-file workflow, the
[hobbyist guide](guide-hobbyist.md#two-tools-means-two-files) describes what the post does at the
end of the first file to make the hand-off work.

**Do not jog at a manual-change pause.** The post returns the tool to *Machine Travel Z* and then to
the part origin; it does not retrace from where you left it.

### Who the token goes to

**`Tool Change Handled By`** exists because who acts on the token is not something the g-code can
say. `M6` is a genuine call into `tfree`/`tpre`/`tpost` on RepRapFirmware, is executed by FluidNC
itself, and reaches a stock Grbl or grblHAL controller as `error:20`.

| Handler | Token | What it needs |
|---|---|---|
| gSender, CNCjs | `T` + `M6` | The sender's own GRBL filter removes the `M6` before the controller sees it. **CNCjs only pauses** — the change and the re-zero are yours |
| UGS | `T` + `M6` | Its tool-change interception is **off until you switch it on**. Enabled, it strips the `M6`, passes the `T` through, moves to a safe height and a change position, waits for you, and can run a tool-length probe if you configured one — if you use that probe, set *Tool Length Correction By* to `Tool change applies tool offset` |
| FluidNC | `T` + `M6` | **No sender interception at all** — the firmware runs the change, and a sender set to strip the `M6` takes the token away. It dispatches to the changer declared as `atc:` under the spindle, or the macro named by `m6_macro:`, both in `config.yaml`. **With neither declared it accepts the line, changes nothing and reports nothing.** A changer needs FluidNC 3.9.0 or later; if yours probes a tool setter, set *Tool Length Correction By* to `Tool change applies tool offset` |
| RepRapFirmware tool table | `T` alone | Every tool number declared with `M563` in `config.g`, and a `tpost<n>.g` that applies the offset. **Both are on the machine and neither is visible to the post** |
| Other | none — your macro file | A file in the NC output folder, included identically at every change |

**A handler is listed only where what it does with the token was read in its own source.** That is
why `Other` exists. And the post cannot check that yours is configured: an `M6` that reaches a stock
Grbl controller stops the job with the tool in the cut, and one the sender is set to *ignore* — or
that FluidNC accepts with nothing configured behind it — drops the change silently and cuts on with
the wrong bit. **Test one change on air.**

### Who corrects Z0

**This is the question the dialog asks instead of "should I probe".** A work Z0 lives in a work
offset register as a machine-Z coordinate, so **measuring it corrects one register** and leaves every
other part still measured by the tool just removed. A **tool-length offset** writes no register at
all — it shifts the whole Z frame, so every part's stored Z0 becomes correct at the same instant.
Those reach different numbers of parts, and **`Tool Length Correction By`** is where you say which
one happens:

| Answer | Reach | What the post does |
|---|---|---|
| **`GCode reprobes Z0 after change`** *(default)* | one register | Re-probes the active offset, and marks **every other** part stale so a return to it re-measures |
| **`Tool change applies tool offset`** | the whole Z frame | Nothing — no probe, nothing marked stale — and the file states the condition it is trusting |
| **`User re-zeroed Z by hand at pause`** | one register | Nothing measured; every part **but the one active at the pause** is marked stale |

**The post can verify none of the three.** Each is your assertion, and the two whose stated party may
not exist are warned about when you post. Two mismatches in particular:

- `Tool change applies tool offset` with `Manual change at a pause` — a manual pause hands over to
  nothing. Unless **you** apply an offset there, no offset is applied and every part's stored Z0
  still measures from the tool just removed.
- `GCode reprobes Z0 after change` with a handler that already re-zeroes — the post probes again and
  overwrites what the macro measured, asking you to fit the touch plate at every change for a
  measurement already made.

### The first tool

**`First Tool is Correct`** is a declaration about the spindle, not a prompt. On, nothing is emitted.
Off, the first tool is loaded **before any origin is recorded or probed** — so Z0 is measured with
the tool that will cut — by whichever route *At a Tool Change* names. A job that hands every change
to a changer will not stop and ask a human for the one tool the changer already holds.

It is **ignored on the two `Set … to Current Pos` modes**, and the post warns: those take the origin
from a jog you made before line 1, with a tool already fitted, so there is nothing left to ask. Use
`Jog to X0 Y0, Probe Z0` or `Jog to X0 Y0 Z0` if you want the tool loaded during the run — they load
first and position afterwards.

### Where a manual change happens

**`Manual Position X Y` and `Manual Position Z` are absolute machine coordinates**, emitted through
the same `G53` block as every other machine-frame move. That is the whole difference from the
`Tool Change X/Y/Z` they replaced, which were plain `G0` words the dialog presented as absolute
while the machine read them in whichever work offset was active — so a "fixed" change spot moved
with every part origin.

- **X and Y are one field**, two millimetre values separated by a comma: `-10, -400`. There is no
  half-set point to get wrong; what is left to get wrong is the syntax, and a value the post cannot
  read stops the post rather than being taken as empty.
- **X/Y needs X/Y declared homed**, and any position at all needs *Machine Travel Z*. Both refused
  otherwise, rather than accepted and quietly not emitted.
- **Z may be filled alone.** Fill it only to get a spanner on the collet: the post crosses the bed at
  *Machine Travel Z*, descends to this height once it has arrived, and returns to *Machine Travel Z*
  afterwards. Below *Machine Travel Z* the post warns — the tool is then held lower during the change
  than the height you declared clears your fixtures.
- **On the hand-over route these fields are not used**, and the post says so rather than dropping
  them silently. Driving the tool to a changer or a length sensor is the macro's business, in a frame
  the post cannot see.

### One GRBL setting worth changing

On GRBL the steppers de-energise once the machine has been idle for a set interval, and the two
dialects behind the one `Grbl` answer spell it differently: **`$1` on stock Grbl and grblHAL, 25 ms
on a stock build**, and **`idle_ms` under `stepping:` in `config.yaml` on FluidNC**. On both, **255
means *stay energised*** rather than a 255 ms delay — and 255 is already FluidNC's shipped value, so
a stock FluidNC holds the axes here and a stock Grbl drops them.

The controller keeps counting position, so nothing is lost unless an axis actually moves; a gantry
nudged while the collet is loosened, or a Z that back-drives with no holding torque, is enough, and
every cut after the change is then offset by an amount nothing reports. **Set `$1=255` on Grbl or
grblHAL.** The post cannot: `$` settings are not g-code and GRBL accepts them only when Idle, and
the FluidNC value is a file on the controller. The same exposure applies to a handed-over change,
where the idle interval is not the post's to bound.

---

## External include files

Group 7 substitutes your own g-code, read from a file in the NC output folder. Group 6's two
tool-change files are the other kind — they **add** to the hand-over sequence.

> **A Start or Stop file *replaces* the phase it names — it does not add to it.** That is the
> feature, but it means the built-in code for that phase, **including the modal preamble**, is
> not emitted:
>
> - A **Start GCode File** owns `G90` and `G21`/`G20`, plus `G94` and `G17` on GRBL, or the
>   `M84 S0` stepper-timeout disable on Marlin/RepRap.
> - A **Stop GCode File** owns coolant-off, the spindle stop or prompt, the end park, `M84 S60`,
>   and `M30`/`M2`.
> - A file that **exists but is empty** is the same rule taken to its limit: the phase is replaced
>   by nothing. The post says so with an Info comment.
> - A file that is **named but missing** aborts the post.

**Off GRBL, the plane and feed mode a RepRap job inherits are a Start file's problem.** Marlin
compiles `G17` only under `CNC_WORKSPACE_PLANES`, shipped commented out, and has no `G93`/`G94` at
all; RepRap gained `G93`/`G94` only in 3.5.1. So the post emits both on GRBL only, and if you replace
the header on another firmware, whatever plane and feed mode the controller was left in is what your
job runs in.

**The tool-change files, by contrast, are additive.** *Tool Change Start* runs where the cut ended,
at cutting height, so any move in it is yours to make safe. *Tool Change End* runs after the resume
and any re-probe, with the tool at *Machine Travel Z* and absolute mode, units and the work offset
re-asserted — that is the safe end to move in.

**Fusion asks *"This post processor might be unsafe…"* the first time you name any file** — reading
a file is what triggers it. Answer **Yes**; No cancels the post.

---

## Validation guards

Checked at post time — the post cannot read the live controller — and refused before bad g-code
is written. **A refusal from `onOpen()` writes no file at all;** the one exception is noted below.

**Refusals:**

- **More than one tool with `At a Tool Change` = `Refuse a multi-tool job`.** The shipped state.
- **A multi-part job with no fixed Z reference.** More than one work offset requires *Machine Travel
  Z*, because no single clearance height is meaningful across offsets whose origins are only known
  after runtime probing.
- **A multi-part job on a machine that does not declare X/Y homed.** Stored offsets are repeatable
  only against a homed X/Y zero. *(These two replace the old blanket refusal of multi-offset Marlin
  jobs, which rested on the false claim that Marlin has a single coordinate frame.)*
- **`Machine Travel Z` filled without Z declared homed.**
- **A hand-over on Marlin** — no tool-length register exists there for a macro to write into, and no
  supported sender intercepts a change for it. Use `Manual change at a pause`.
- **A handler that does not match the firmware** — the RepRap tool table on a non-RepRap job, or a
  GRBL sender on a non-GRBL job.
- **`Tool Change Handled By` = `Other` with no macro file named.**
- **A manual change position the post cannot read, or set without the frame it needs** — a
  *Manual Position X Y* that is not two comma-separated numbers, any position without
  *Machine Travel Z*, or an X/Y position without X/Y homed.
- **`At End Park At` = `Machine X0 Y0`** without X/Y declared, or (off Marlin) without homing on.
- **An include file named but not present** in the NC output folder.
- **A fan (`M106`) or pin (`M42`) output selected for the spindle on a GRBL job, or for the laser on
  a GRBL job that carries a jet tool.** GRBL has neither command and answers it with `error:20`,
  stopping with the tool in the cut. A GRBL *milling* job is not refused for a `Mrln:` laser value,
  because no laser code is emitted there at all — it warns. The coolant channels also warn rather
  than refuse: the `Mrln:`/`Grbl:` label on a coolant value says which firmware the post shipped it
  for, not that no other firmware takes it.
- **A pin (`M42`) output whose `Pin/Fan #` is still 0**, in any of the three groups that offer one.
  Pin 0 names no output anyone wired deliberately, and Marlin protects it on most boards.
- **Multi-axis toolpaths**, **cutter compensation in the control**, and **CAM probing operations**.
- **A Setup whose Z is not the machine Z**, with the tilt named. *(This one fires after output has
  begun, so it leaves a truncated file — discard it.)*

**Conditions that warn rather than refuse**, because each is legitimate on some setup. There are
around thirty; the ones worth knowing:

- **Homing plus a `Set … to Current Pos` origin mode.** Homing moves the tool first, so the origin
  would be recorded at the endstop corner and your pre-jog discarded.
- **Homing asked for while `Axes Homed and Trusted` is `None`** — no homing motion is emitted at all.
- **A `Use WCS …` mode on a machine with no X/Y homing declared** — the stored offset it trusts is
  measured from a machine zero that moves at every reset, and the post cannot read the register back.
- **A `Set … to Current Pos` first part in a multi-part job** — one part gets cut where you parked
  the tool and the rest at their fixtures, and the offset you set for the first part is overwritten.
- **Two Setups naming work offset 0 and 1**, which are the same register.
- **A `Jog to …` mode**, with the sender or panel condition for your firmware stated.
- **`Comment Level` below `Info` on GRBL** where that leaves a real prompt inside gSender's
  ten-line window, naming the prompts at risk.
- **A re-probe at a point the job has already machined**, naming the operations and the depth.
- **The machine frame in use on RepRap with `Home at Job Start` off** — RRF has no lock on motion
  before homing, so the move runs against whatever machine zero the board holds.
- **`Machine Travel Z` on Marlin**, which needs `CNC_COORDINATE_SYSTEMS`; and **at or above zero on
  GRBL**, which is above the top of travel on a stock build.
- **A coolant code, or a *Laser Output* value, from the wrong firmware's dialect**, and **`M7`/`M8`
  on GRBL at all**, whose build and configuration conditions the post cannot read. The laser warning
  also names the power scale, which goes with the dialect: `0`–`1000` against `$30` on GRBL, a
  `0`–`255` byte on Marlin and RepRapFirmware.
- **A coolant a tool asks for that no channel is configured for** — the job runs those operations
  dry, and the post names them.
- **A Safe Z expression, an X Y pair or a machine coordinate the post cannot parse.** A bad Safe Z
  falls back to 15 mm and is reported once for the file, not once per section; a bad *Probe X Y
  Offset* falls back to `0, 0`; a bad machine coordinate is read as **empty**, which means *not set*,
  so the motion it controls is simply not emitted. The one exception is *Manual Position X Y* on a
  job that actually reaches a manual change, which is refused rather than silently dropped.

Warnings reach two channels and it is worth knowing which: a line in **Fusion's post dialog**, read
by whoever posts, and a `>>> WARNING:` line **in the g-code**, read by whoever opens the file — often
the same person on different days. A condition your properties fix appears in both. A condition the
emitting block discovers appears only in the file, because there was no earlier moment to say it.

---

## What is verified, and what is not

**Worth reading before you trust a claim in these documents**, because the answer differs by kind of
claim.

**Firmware behaviour is settled from source, never from a machine.** This project has no CNC
controller, no sender console and no machine time. Every firmware statement here was read out of that
firmware's own source or changelog, with the file and version cited — Marlin at 2.0.9.7 and 2.1.2.5,
Grbl 1.1, FluidNC 3.x, RepRapFirmware from 2.05 through 3.6.0, and the senders' own repositories for
what they do with an `M0` or an `M6`. **Nothing here is proved by having been run on hardware.** The
practical consequence: statements about *what the post emits* are strong, and statements about *what
your controller then does* are as good as the source read and no better — which is why the guards
warn about build options rather than assuming them.

**The post itself is run, not only read.** There is an automated suite that drives `post.exe` — the
same engine Fusion invokes — over real CAM job files, and asserts what the output must and must not
contain. That reaches something no code review can: whether the post runs at all.

**What the suite does not reach, stated plainly:**

- **The dialog.** Property *values* are set on the command line; the dialog's layout, its titles,
  and which fields grey out under which mode are never exercised. **If a field's behaviour in the
  dialog is what you are relying on, no automated run here has checked it.**
- **Your Setup.** The job files are Autodesk's own regression corpus, plus fixtures built by
  splicing those files a word at a time to reach the multi-part paths — **every `.cnc` file Autodesk
  ships uses a single work offset**, so multi-part behaviour had to be reached that way. None of them
  is an operator's Setup, and a file posted from Fusion is still owed.
- **Some paths no job file on disk can reach at all**, stated as bounds rather than tested: a rapid
  that moves in X/Y and Z at once, a tool numbered 0, a dwell, and the vaporize laser power.
- **Every property runs at its default on every run, but 11 are never *varied*** — the four custom
  coolant filenames, the four include-file names, and the three laser power levels. Their
  alternative values have not been posted.

**And a green run is not a verified post.** Every finding this machinery has returned came from
**reading the passing output**, not from a red case; two of its own checks were passing while
asserting nothing useful. A green run means the questions asked were answered, not that the right
questions were asked.

---

## Where next

- **[Property reference](property-reference.md)** — every one of the 57 settings.
- **[Hobbyist guide](guide-hobbyist.md)** — the one-part job, and the two-file tool change.
- **[README](../README.md)**
