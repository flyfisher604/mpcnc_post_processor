Pro guide — several parts, several tools, several work zeros
====

**This guide is for you if** your job has more than one operation, more than one tool, or more
than one part on its own fixture — the things a full Fusion licence lets you build. It assumes
you are comfortable with CNC terms; the [hobbyist guide](guide-hobbyist.md) covers the one-part
job in plainer language, and everything in it still applies here.

- [What a WCS is, and what this post does with it](#what-a-wcs-is-and-what-this-post-does-with-it)
- [Many operations and tools, one part](#many-operations-and-tools-one-part)
- [Several copies on separate fixtures](#several-copies-on-separate-fixtures)
- [A flip, or one part from two datums](#a-flip-or-one-part-from-two-datums)
- [Origin modes in full](#origin-modes-in-full)
- [What "Active WCS" means](#what-active-wcs-means)
- [The machine frame (homing)](#the-machine-frame-homing)
- [A fixed Z reference](#a-fixed-z-reference)
- [Probing](#probing)
- [Tool changes](#tool-changes)
- [External include files](#external-include-files)
- [Validation guards](#validation-guards)

---

## What a WCS is, and what this post does with it

A **Work Coordinate System** is an origin the controller remembers. GRBL and RepRap have several
— `G54` through `G59`, plus `G59.1`–`G59.3` on RepRap — each holding its own offset, so you can
define several independent zeros and switch between them mid-program.

Fusion assigns one per Setup through its **Work Offset** field (1 → `G54`, 2 → `G55`, …). This
post emits the matching WCS whenever it changes.

Two facts shape everything below:

**The post selects a WCS but can never read one back.** It always knows *which* frame is active,
because it commands the selection itself at job start over whatever your sender left modal. It
never knows *where* that frame is — register contents are runtime state in the controller, and
g-code generation is one-way. So the modes that use a stored origin **trust** it.

**Marlin has no WCS table at all** — one global origin, set with `G92`. A Marlin job that uses
more than one distinct work offset is refused outright. Everything below about multiple WCS is
GRBL and RepRap only.

---

## Many operations and tools, one part

Several operations — face, pocket, contour — on one part in one Setup, so one WCS throughout.

- **Group 3 does nothing on a full licence**, whatever you set it to. Fusion emits real rapids,
  so the conversion code is never reached. Leaving it off is tidier.
- **First WCS / Part**: if this Setup's WCS is a pre-set fixture offset, use **`Use Active WCS
  X0 Y0, Probe Z0`** — rapid to the stored X0 Y0, re-probe the stock top. Otherwise the default
  **`Set X0 Y0 to Current Pos, Probe Z0`** and pre-jog XY. Prefer either to the `Jog to …` modes.
- **If the job changes tools**, enable group 7 and turn on **Probe After Tool Change** — there is
  no tool-length system, so a Z re-probe after each change is the substitute. The change position
  (**Tool Change X/Y/Z**) is in the **active WCS**, not machine coordinates.
- **No fixed Z reference is needed.** One frame means each operation's own retract already clears
  the part, and there are no cross-part traverses.

---

## Several copies on separate fixtures

Copies of a part jigged on separate fixtures, one WCS each, cut in one program.

**1. Give the job a fixed Z reference.** Parts on different fixtures may differ in thickness, so
there is no single height above *the stock* that clears everything. Group 5's **Fixed Z
Reference** gives the job a frame whose Z0 does not move with the stock — see
[below](#a-fixed-z-reference) for the two ways to have one.

**2. Put each copy on its own Fusion Work Offset.** Their XY comes from each fixture's pre-set
offset; the post never sets XY for an added part unless you choose a Jog mode.

**3. Set the first copy's origin.** **First WCS / Part** = **`Use Active WCS X0 Y0, Probe Z0`**,
so the first copy takes its pre-set XY and re-probes Z exactly as the others will.

**4. Set what happens at each copy after the first.** **Subsequent WCS / Part**:

| Mode | What it does | When |
|---|---|---|
| **`Use Active WCS X0 Y0, Probe Z0`** *(default)* | Rapids to that copy's stored X0 Y0, re-probes its stock top | The best-practice path. Handles varying stock thickness |
| `Use Active WCS X0 Y0 Z0` | Rapids to the stored X0 Y0; no probe, the stored Z is trusted | Stock thickness is known-identical and already recorded |
| `Jog to X0 Y0, Probe Z0` / `Jog to X0 Y0 Z0` | Pauses so you jog to each copy's origin | A setup run where the fixtures are *not* pre-set — and only where jogging at a pause works at all |

**5. Leave Retract Across Parts on.** Before each traverse to a different WCS the tool lifts to
**Inter Part Travel Z**, measured in the fixed Z reference, so it clears every clamp and part
whatever their heights.

---

## A flip, or one part from two datums

**Out of scope for a single run.** On a machine with no homing the post cannot establish the
second reference's XY, and re-probing the same surface buys nothing. Run each side or each datum
as a **separate job**.

---

## Origin modes in full

Group 6's two origin controls are one taxonomy with three families:

- **`Set … to Current Pos`** — no prompt. The tool is assumed already at the origin, because you
  pre-jogged, or because homing or the base probe left it there. *(First part only.)*
- **`Use Active WCS …`** — no prompt. Trust the origin already stored in that WCS and rapid to
  it, either re-probing Z or trusting the stored Z too. The right path for pre-set fixtures.
- **`Jog to …`** — the post pauses so you jog to the origin during the run, then records it.

Each family comes in a **probe-Z** variant and a **Z-manual** variant. **The defaults avoid any
run-time pause**, because jogging at one is not universally supported.

> **A jet tool or tool 0 never probes.** Any probe-Z mode degrades to recording the origin with
> no `G38.2`. On a probe-Z mode that means **Z0 is never established**, and the job runs against
> whatever the register already holds — the post warns in the file. For a laser or jet job choose
> **`Set X0 Y0 Z0 to Current Pos`** and set Z by hand.

> **`Use Active WCS X0 Y0 Z0` opens with a *move* to Safe Z, not a retract.** Safe Z is an
> absolute height in the stored frame, so a tool parked above it starts the job by **descending**,
> at Z travel speed, over ground the post knows nothing about. Park below Safe Z, or raise it.

---

## What "Active WCS" means

**The WCS your Fusion Setup designates — not the one your sender happens to have selected.**

- Each Setup carries a Work Offset. That is what the post uses.
- The post **selects** it at job start, before establishing any origin. Leave `G55` active in your
  sender while the Setup says WCS 1 and the file emits `G54` regardless. It overwrites the
  selection; it never inherits it. You do not need to pre-select anything.
- What the post cannot do is **read** that register. Its contents were written by a previous job
  or your own touch-off, and there is no round trip.

So: **which WCS is certain; what it contains is trusted.**

| Mode | Safe when | Watch out for |
|---|---|---|
| `Use Active WCS X0 Y0, Probe Z0` | XY fixtures pre-set and unmoved; thickness may vary | A fixture that shifted — XY is trusted blindly |
| `Use Active WCS X0 Y0 Z0` | Nothing has changed at all, thickness included | New stock — the stored Z is wrong |

On a **fresh controller** every offset is `0`, so `G54` means machine coordinates — on an unhomed
machine, wherever it powered on. Do not use a `Use Active WCS …` mode until that WCS has actually
been set.

---

## The machine frame (homing)

Group 4 separates two questions the old dialog ran together.

**`Axes Homed and Trusted`** is a **declaration** — a fact about your machine, set once: `None`,
`XY Only`, `Z Only`, `XYZ`. It is not an instruction to home anything.

**`Home at Job Start`** is **the action** for *this job*: `Off`, `Home`, or `Pause, then Home`.
A machine with endstops can still be homed once at the controller and left alone all session,
which is why the two are separate. The pause is one stop before any homing motion, whatever the
firmware and however many axes home — long enough to place a movable Z plate or clear the bed.

Homing buys **repeatability**, not a cutting reference. A stored work offset only points at the
same physical place across power cycles if the machine homes X/Y — which is why the post warns
when a job trusts a stored offset without X/Y declared. The everyday Z cutting zero is always the
work-Z touch-off.

**`At End Park At`** decides where the tool finishes: `Off`, `Work X0 Y0` (the **last
operation's** WCS origin — on a multi-part job, whichever fixture Fusion ordered last), or
`Machine X0 Y0` (the homing corner, one point for every job). The machine answer needs X/Y
declared, and on GRBL and RepRap it also needs homing on, because there it addresses a frame the
job must already have established.

---

## A fixed Z reference

A frame whose Z0 does **not** move with stock thickness — the only frame in which one clearance
height is meaningful across parts of differing thickness. A multi-part job needs one; a
single-part job does not. Group 5's **Fixed Z Reference** offers two ways to have one:

| Answer | The frame | *Inter Part Travel Z* is then | It costs |
|---|---|---|---|
| **Spoilboard** | A probed surface, held in a reserved WCS | A height **above that surface** — positive, typically 30–60 | One WCS register (GRBL has six), plus a probe cycle |
| **Machine Z** | The machine's own homed Z | An **absolute machine coordinate** — signed, often negative | Declaring and homing Z; a number read off the DRO |

**Whichever you pick decides which frame `Inter Part Travel Z` is measured in**, and the two
readings are unrelated numbers for the same physical plane. The field therefore **ships empty**:
a height left over from the other answer is a valid-looking number in the wrong frame, so the post
refuses to post rather than guess. The value is echoed **with its frame** in the file's Resolved
Values block — check it there before the machine moves.

**The Machine Z number belongs to the machine, not the job.** It is the only absolute machine
coordinate this post emits, so unlike every other height in the dialog it does not stay correct
when a Setup is copied or a design is shared. Get it once: home, jog to a height that visibly
clears everything, read Z off the DRO.

### The reserved spoilboard base

- **Established at job start** by **Probe to Set Base** — `Pause, Probe Z, Pause` (the manual
  touch-off, default) or `Probe Z` (no prompt, for a fixed point).
  > **⚠ Park over bare spoilboard before you start.** The base probe makes **no XY move** — it
  > touches off whatever is under the tool. Park over the stock and the "spoilboard base" records
  > the *stock top*, and every clearance from it is short by the stock thickness. **Probe X/Y
  > Offset** shifts only *part* probes and cannot move this one.
- **Transited, not parked.** To move between parts the post briefly selects the base, retracts to
  *Inter Part Travel Z*, then selects the destination WCS. It never leaves the base active into a
  cut, and never selects it without a real move.
- **`G59` recommended** — the highest GRBL supports, keeping `G54` free for parts. `G59.1`–`G59.3`
  are RepRap only, and a base is ignored on Marlin.
- **No operation may re-establish the base's origin.** Selecting that WCS for an operation is
  fine; re-zeroing or re-probing it is a posting error.

---

## Probing

- **Work-Z only.** `G38.2` down to a touch plate, thickness compensated by **Plate Thickness**.
  There is no tool-length system, and **X/Y is never probed**.
- **G38 Target is a travel limit only where the post can make it one.** It is emitted as a `Z`
  word, so it means "descend to this height in the current work frame". On the two modes where you
  have *just* placed the tool the post writes a provisional `Z0` first, so `-10` really is
  "descend at most 10 mm". On the **`Use Active WCS …`** and added-part modes it cannot — the tool
  arrives from a retracted clearance, so the target stays relative to the **stored** zero. Size it
  against that stored zero on those modes, or the probe runs long or never contacts.
- **Probe Pause** governs the attach/detach prompts around each **part** probe only — not the base
  probe, and not the tool-change re-probe.
- **Probe X/Y Offset** moves the touch-point away from the origin, job-wide, at every part probe.
  Never at the base probe.

---

## Tool changes

Group 7, off by default. With more than one tool and the group off, the post warns at post time
and marks each suppressed change in the file — but every operation still runs with whatever tool
is in the spindle, at the other tools' feeds and speeds.

- **Probe After Tool Change** is the tool-length substitute. Turn it on.
- **Tool Change X/Y/Z** is in the **active WCS** — a plain `G0`, not machine coordinates — so the
  physical spot moves with your work zero.
- **Tool Change Start / End** include files are **added** to the sequence, unlike the Start and
  Stop files, which replace their phase.
- Manual changes are collision-sensitive on every leg: retract, move, pause, swap, re-probe,
  resume. **Expect this area to change** in a future release.

---

## External include files

Group 8 substitutes your own g-code, read from a file in the NC output folder.

> **A Start or Stop file *replaces* the phase it names — it does not add to it.** That is the
> feature, but it means the built-in code for that phase, **including the modal preamble**, is
> not emitted:
>
> - A **Start GCode File** owns `G90` and `G21`/`G20`, plus `G94` and `G17` on GRBL, or the
>   `M84 S0` stepper-timeout disable on Marlin/RepRap.
> - A **Stop GCode File** owns coolant-off, the spindle-off prompt, the end park, `M84 S60`, and
>   `M30`/`M2`. (On GRBL the closing `%` is still written.)
> - A file that **exists but is empty** is the same rule taken to its limit: the phase is replaced
>   by nothing. The post says so with an Info comment.
> - A file that is **named but missing** aborts the post.

**Fusion asks *"This post processor might be unsafe…"* the first time you name any file here** —
reading a file is what triggers it. Answer **Yes**; No cancels the post.

**Tool Change Probe is not implemented.** The field is reserved and nothing reads it.

---

## Validation guards

Checked at post time — the post cannot read the live controller — and refused before bad g-code
is written:

- **No base redefine.** Using the reserved base is fine; re-establishing its origin is an error.
- **Cross-part retract needs a fixed Z reference.** *Retract Across Parts* on, more than one WCS,
  and no fixed reference is an error: a clearance height is meaningless across offsets whose
  values are only known after runtime probing. Single-WCS jobs are exempt.
- **Marlin is single-frame.** More than one distinct work offset on Marlin is a hard error.
- **Machine Z needs a frame this job established.** *Fixed Z Reference* = `Machine Z` requires Z
  declared *and* homing on.
- **The tool axis must be machine +Z.** An off-axis Setup is rejected with the tilt named. *(This
  one fires after output has begun, so it leaves a truncated file — discard it.)*

Two checks **warn** rather than stop, because each is legitimate on some setup:

- **Homing plus a `Set … to Current Pos` origin mode.** Homing moves the tool first, so the origin
  would be recorded at the endstop corner and your pre-jog discarded.
- **More than one tool with group 7 off**, as above.

A third is written into the file rather than the dialog: **a jet or laser tool cannot probe**, so
on a probe-Z mode Z0 is never established.

---

## Where next

- **[Property reference](property-reference.md)** — every one of the 69 settings.
- **[Hobbyist guide](guide-hobbyist.md)** — the one-part job.
- **[README](../README.md)**
