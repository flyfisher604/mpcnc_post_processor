Changelog
====

What changed in each release of the post, newest first, and what to do before your first job on
it. Each release has full notes; the current release's notes are in this tree, and earlier ones are
kept at the tag they describe.

**Every release has a new filename.** Fusion identifies a post by its filename, so a new release
installs *beside* the old one rather than replacing it. Remove the old copy from the Post Library
first — see [Installation](README.md#installation).

- [v4.1.2 Beta 3](#v412-beta-3--current) — current
- [v4.1.1 Beta 3](#v411-beta-3)
- [v4.1 Beta 3](#v41-beta-3)
- [v4.0 Beta 3](#v40-beta-3)
- [v4.0 Beta 2](#v40-beta-2)
- [v4.0 Beta 1](#v40-beta-1)
- [Earlier releases](#earlier-releases)

---

## v4.1.2 Beta 3 — current

A correction release. **One fix changes the g-code a job emits:** a tool change to a tool that runs
at the same speed and direction as the one before left the spindle stopped, so the new tool cut
without it. The rest corrects what the post *says* — warnings, labels and tooltips.

- **The spindle restarts after every tool change.** Before this release, when the next tool asked
  for the same speed and direction, the post emitted no `M3`, no *Turn ON* prompt and no fan or pin
  command, and the second tool cut with the spindle stopped. It affected both tool-change routes,
  every *Spindle Control* mode, and a milling operation that follows a laser one.
- **`M7` and `M8` coolant are no longer called GRBL-only.** The values read **`M7 on, M9 off`** and
  **`M8 on, M9 off`**. Marlin and RepRapFirmware run both, and their operators are now warned about
  their own firmware's condition rather than told the job would stop.
- **Safe Z reads what you type, and refuses what it cannot read.** `" 15"`, `".5"` and
  `"Retract: 5"` now parse. A value that does not parse, such as `-5`, `15mm` or `Retract:`, refuses the
  post with a message. Earlier releases quietly used 15 mm instead.
- **Messages quote the dialog exactly**, so the titles and group names a warning mentions are the
  ones you see in the dialog.
- **Shorter tooltips.** Each field's hover text says what it does in a few lines; the detail moved
  to the [property reference](docs/property-reference.md).
- **Smaller files at the default Comment Level.** The trace of Fusion's internal movement and
  command ids now appears only at `Debug`.

**Before your first v4.1.2 job:** remove `MPCNC_v4.1.1_Beta3.cps` from the Post Library. **Your
saved settings carry over** — no property key or value id moved. If you have Safe Z set to
something unusual, post once and read the dialog: a value earlier releases replaced with 15 mm is
now refused.

**[→ Full release notes for v4.1.2 Beta 3](docs/release-notes-v4.1.2-beta3.md)**

---

## v4.1.1 Beta 3

**The dialog asks 57 questions where it asked 65**, and FluidNC is described correctly. Nothing
was removed from the post: six places where two or three fields held one decision are now one
field each.

| Now one field | Was | What to do |
|---|---|---|
| **Line #s** (group 1) | *Enable Line #s*, *First Line #*, *Line # Increment* | Three answers: `Off`, `N10 N11 N12 … step 1`, `N10 N20 N30 … step 10`. Numbering starts at `N10` |
| **Probe X Y Offset** (group 5) | *Probe X Offset*, *Probe Y Offset* | Two numbers separated by a comma — `30, -15`. Signed, and decimals now allowed |
| **Safe Z** (group 5) | *Safe Z* and group 3's *Safe Z to Rapid* | One height, read by both groups |
| **Manual Position X Y** (group 6) | *Manual Position X*, *Manual Position Y* | Two numbers separated by a comma — `-10, -400`. *Manual Position Z* is unchanged |
| **Laser Output** (group 8) | *Laser: Marlin/Reprap Mode*, *Laser: GRBL Mode* | Five values, each labelled `Grbl:` or `Mrln:`. Pick the one your firmware speaks |
| **Channel A / B Output** (group 9) | *Turn Channel A/B On* and *Turn Channel A/B Off* | One answer sets both directions — the off code follows from the on code |

- **FluidNC executes `M6` itself.** *Tool Change Handled By* gained a **FluidNC — T + M6** value,
  which dispatches to the `atc:` changer or `m6_macro:` in `config.yaml`. The idle-timer and
  homing-pull-off warnings name FluidNC's `idle_ms` and `pulloff_mm` beside Grbl's `$1` and `$27`.
- **One coolant bug went with the merge.** A channel switched on with `M106` or `M42` while its off
  field was left at `M9` was never switched back off. The off code is now the on code's own.

**Before your first v4.1.1 job:** four settings reset to their defaults — *Line #s*, *Probe X Y
Offset*, *Manual Position X Y* and *Laser Output*. **The laser default is a GRBL value**, so a Marlin
or RepRapFirmware laser job must set *Laser Output* once.

**[→ Full release notes for v4.1.1 Beta 3](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/release-notes-v4.1.1-beta3.md)**

---

## v4.1 Beta 3

v4.0 Beta 3 could ask you to switch the router on by hand, or command it with `M3`. On a stock
Marlin build neither is much use — `M3` is behind a build option that is off — while the fan and
pin outputs that build *can* switch were reachable only for a laser, and then only on fan 0.
v4.1 Beta 3 lets the router, the laser and both coolant channels each name the output they switch.

**Before your first v4.1 job:** three settings changed name or shape, so they fall back to their
defaults. The old *Manual Spindle On/Off* checkbox is now a four-way **Spindle Control**, and the
laser and coolant pin fields were replaced by ones you set per output. The default is what the
checkbox shipped — the post asks you to switch the router by hand.

**[→ Full release notes for v4.1 Beta 3](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/docs/release-notes-v4.1-beta3.md)**

---

## v4.0 Beta 3

Beta 2 gave each part its own zero. Beta 3 corrected **where those zeros come from**, rebuilt tool
changes around what the post can actually do, and — for the first time — *ran* the post against
Autodesk's own engine instead of reasoning about it.

**Before your first Beta 3 job:** your saved settings do not carry over. Every property key was
renamed, so a Beta 2 preset falls back to its defaults. Walk the dialog once, and look hardest at
groups **4**, **5** and **6**.

**[→ Full release notes for v4.0 Beta 3](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.0_Beta3/docs/release-notes-v4.0-beta3.md)**

---

## v4.0 Beta 2

Beta 1 knew one zero: wherever the tool happened to be when the job started. Beta 2 keeps track
of one per part, plus one job-level height in the machine's own frame to cross the bed at.

1. **More than one work zero.** A separate zero for each part, held in the controller's own
   registers, switched between as the job runs. On Marlin those registers need
   `CNC_COORDINATE_SYSTEMS`, which the post assumes and warns about.
   → [What a work offset is](docs/guide-pro.md#what-a-work-offset-is-and-what-this-post-does-with-it)
2. **You choose how each zero gets set** — use where the tool is now, use a stored zero, or stop
   and let you jog to it, each with or without probing Z.
   → [Origin modes in full](docs/guide-pro.md#origin-modes-in-full)
3. **Several parts in one job**, on separate fixtures or from several datums on one fixture,
   re-probing each so stock thickness can vary.
   → [Several parts in one job](docs/guide-pro.md#several-parts-in-one-job)
4. **The machine frame, split in two.** Group 4 separates *what your machine can home* from *what
   this job should do about it*. → [The machine frame](docs/guide-pro.md#the-machine-frame-and-the-travel-height)
5. **One travel height in the machine's own frame** — *Machine Travel Z*, an absolute machine
   coordinate read off your sender once. A multi-part job is refused without it.
6. **Tool changes rebuilt** around arrive, hand over and resume. A multi-tool job is refused by
   default rather than posted with its changes silently dropped. → [Tool changes](docs/guide-pro.md#tool-changes)
7. **Unsafe jobs are refused before any file is written**, with a message saying what to change.
   → [Validation guards](docs/guide-pro.md#validation-guards)
8. **Better probing** — attach and remove prompts, and touching off away from the part origin.
   → [Probing](docs/guide-pro.md#probing)
9. **The dialog rebuilt** into 10 numbered groups, with every setting and the values the post
   resolved from them dumped at the head of the file. → [Property reference](docs/property-reference.md)
10. **Safer endings and clearer prompts.** The spindle stops before the tool parks; a hand-set
    router is prompted whenever its speed or direction changes; each firmware gets its own
    end-of-program code.

**Before your first Beta 2 job:** saved settings do not carry over from Beta 1. *Machine Travel Z*
ships empty on purpose, *At a Tool Change* ships at *Refuse a multi-tool job*, *Scale Feedrate* is
on, and the coolant codes default to the GRBL dialect.

---

## v4.0 Beta 1

v3.0 Beta 3 renamed; the post itself was unchanged. Its work was tidying and correctness:

- A **grouped, named property dialog** in place of a flat list.
- **Drilling operations post at all** — canned cycles are expanded into ordinary moves.
- **Manual NC pass-through** commands are emitted as written.
- **Rapid moves are ordered** so the tool lifts before it travels and travels before it descends.
- **Jobs the post cannot handle are refused with a useful message** — 4/5-axis toolpaths, and
  cutter compensation set to anything but *In computer*.

---

## Earlier releases

v1 through v3.0 Beta 3 predate this changelog. Their tags are in the repository, and the
[releases page](https://github.com/flyfisher604/mpcnc_post_processor/releases) carries what was
published with them.
