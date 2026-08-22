# Release notes — v4.1.1 Beta 3

Everything that changed since **v4.1 Beta 3**, which shipped two days ago. Two things did, and neither
adds a capability: **the dialog asks 57 questions where it asked 65**, and **FluidNC is named correctly
throughout** where three warnings and a tool-change value had been telling its operators about a
firmware they are not running.

`git log v4.1_Beta3..` is the changelog. `PC-1` through `PC-6` and `FR-1`/`FR-2` in
`docs/findings.md` are the eight register rows this closes, and they carry the reasoning and the
firmware citations.

**Coming from v4.0 Beta 3?** Read [the v4.1 Beta 3 notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/docs/release-notes-v4.1-beta3.md)
as well — the router, laser and coolant outputs landed there, and this release does not restate them.

---

## Three things to know before your first v4.1.1 job

### 1. The post is a new file, again

The deliverable is **`MPCNC_v4.1.1_Beta3.cps`**. Fusion identifies a post by its filename, so **remove
`MPCNC_v4.1_Beta3.cps` from the Post Library** rather than leaving it beside this one.

One version bump carries all six folds, so **your settings reset once rather than six times.**

### 2. Four settings fall back to their defaults

Fusion stores a property by its key, and four of the folds had to move a key — a stored `true` is not
one of three enum ids, a single coordinate is not a pair, and `"M3"` was Marlin's spindle form where it
is now GRBL's static-power one. So a saved preset loses these four and **keeps the other 53**:

| Resets | Falls back to | Which is |
|---|---|---|
| **Line #s** | `Off` | what the *Enable Line #s* checkbox shipped |
| **Probe X Y Offset** | `0, 0` | probing at the origin, as two zeroed fields did |
| **Manual Position X Y** | empty | the change happening above the last cut, as two empty fields did |
| **Laser Output** | `Grbl: M4 S{PWM}/M5 dynamic power` | **not** what you had, if you run Marlin or RepRap — see below |

The coolant channel outputs and *Safe Z* **keep whatever you had set**: their keys did not move,
because every value they stored is still legal and still means the same thing.

### 3. The laser default is now a GRBL value

*Laser Output* is one field over five values where it was two fields, one per dialect, and
`CNC Firmware` ships `Grbl` — so the merged field has to ship a GRBL default. **A Marlin or
RepRapFirmware laser job that does not answer it emits `M4 S…`**, which those firmwares either do not
implement at all or implement with `S` read as a 0–255 byte rather than GRBL's 0–1000, so the power
comes out wrong as well. The post **warns and names both wrongnesses**; set the field once and it goes
away. **Milling jobs are unaffected** — the check is gated on a jet tool being in the job.

---

## The six folds

Nothing was removed from the post. Six places where two or three fields held one decision are now one
field each.

| Now one field | Was | What it takes |
|---|---|---|
| **Line #s** (group 1) | *Enable Line #s*, *First Line #*, *Line # Increment* | `Off`, `N10 N11 N12 … step 1`, `N10 N20 N30 … step 10` |
| **Probe X Y Offset** (group 5) | *Probe X Offset*, *Probe Y Offset* | two numbers and a comma — `30, -15` |
| **Safe Z** (group 5) | *Safe Z*, and group 3's *Safe Z to Rapid* | one height, read by both groups |
| **Manual Position X Y** (group 6) | *Manual Position X*, *Manual Position Y* | two numbers and a comma — `-10, -400` |
| **Laser Output** (group 8) | *Laser: Marlin/Reprap Mode*, *Laser: GRBL Mode* | five values, each labelled `Grbl:` or `Mrln:` |
| **Channel A / B Output** (group 9) | *Turn Channel A/B On* **and** *Turn Channel A/B Off* | one answer, both directions |

### Line #s

Three answers in one field. The two on-values differ only in the step — `N10 N11 N12` for a sender that
counts blocks one by one, `N10 N20 N30` for one that leaves room to insert between them. **Numbering
always starts at `N10`**, and restarts in every file.

The two companion fields did nothing whenever the checkbox was off, which is the shipped default, and
the dialog gave no hint that it was asking twice for numbers no file would carry. **What this costs is
an arbitrary first number and an arbitrary increment** — if you were matching a sender convention that
is neither 10/1 nor 10/10, it is gone.

### Probe X Y Offset

The same displacement, in one field instead of two, and neither half could ever be read without the
other. Whitespace around the comma is ignored, either number may be signed, and **decimals now work
where the old integer spinners took whole mm** — which is what you lose the spinner for.

`0, 0` is a meaning here and empty is not, so **a value the post cannot read falls back to the
origin** — the behaviour the post had before the field existed — and says so rather than refusing.

### Safe Z

Group 3's *Safe Z to Rapid* and group 5's *Safe Z* were two properties holding one number, with two
parsers and a seventy-line `switch` that re-implemented the shared resolver branch for branch.

**Both are heights in the same frame** — the part's work coordinates, measured from the touch-off Z0 —
and both mean *a height that clears the work*. Group 3 asks whether the tool is at or above it; group 5
takes the tool to it after a probe. **One meaning, two readers**, and a machine on which the two differ
is one where the post rapids through the height it has just called clear. Group 3 keeps its switch and
has no height field of its own, which is what its title always claimed.

Two side effects worth knowing: an unreadable *Safe Z* is now reported **once per file**, at the parse,
rather than once per section; and where an operation's own retract level could not be used, the file
said *level not abs* or *level not defined* and now says in one sentence that the level was not
usable — the remedy being the same either way.

### Manual Position X Y

One point, asked as one question. The dialog could previously express two states that are not positions
at all — X without Y, and Y without X — and the post spent a refusal putting the halves back together.
**That half-filled point is now not rejected but inexpressible**, which is what deletes the guard
rather than moving it. A typo is still refused, rather than read as empty and the change made quietly
over the last cut.

**`Manual Position Z` stays its own field.** Its description says *may be filled without X and Y*, so
folding it in would add a state rather than remove one.

### Laser Output

`CNC Firmware` chose one of the two old fields and **the other was dead on every job** — which is why
the post carried a flag whose only purpose was to keep a guard off the field nobody was reading. Both
are gone. The chosen output is now the dispatch where the firmware used to be, and the PWM scale goes
with the dialect rather than with the job:

| Value | `S` scale |
|---|---|
| `Grbl: M4 S{PWM}/M5 dynamic power` — the default | 0–1000 against `$30` |
| `Grbl: M3 S{PWM}/M5 static power` | 0–1000 against `$30` |
| `Mrln: M106 P{n} S{PWM}/S0` | a 0–255 byte, output number from *Laser: Pin/Fan #* |
| `Mrln: M3 O{PWM}/M5` | a 0–255 byte, no output number |
| `Mrln: M42 P{pin} S{PWM}` | a 0–255 byte, output number from *Laser: Pin/Fan #* |

One field made two mistakes expressible, and each is answered. **A GRBL laser job holding a `Mrln:` fan
or pin value is refused** — GRBL has neither command and answers `error:20` with the head over the
work — where it used to be silently ignored. **A GRBL *milling* job holding one is not**, because it
emits no laser code at all; without that gate the refusal would have fired on every milling job whose
operator once chose a Marlin value. Any other dialect mismatch **warns**, on the same ruling as group
9's: a label says which firmware the post shipped a value for, not that no other firmware takes it.

### Channel A / B Output

*Turn Channel A Off* and *Turn Channel B Off* asked for a code that every value of the on-field already
determines, and **the only thing the second dropdown made possible was a pair the post spent a refusal
rejecting.** Both are deleted, and the off code is derived: `M106` and `M42` close on the same command
and the same output with `S0`; `M7` and `M8` close with `M9`, the only off code GRBL has and already
what the field's own description said; *Use custom* closes from the channel's own Off Custom file.

The on-fields are retitled **Channel A Output** / **Channel B Output** and **their keys do not move.**
All four custom-file properties survive unchanged — what changed is that one answer now reaches both of
a channel's files, so an unnamed *off* file is reported on a channel whose *on* file is named, which
two independent selectors could not say.

**One real bug went with the merge, and it is the reason to take this release if you use coolant.** The
guard on the two dropdowns tested only whether the *off* code was `M106` or `M42`. So a channel
switched on with `M106` or `M42` while its off field was left at the shipped `M9` **passed that guard
untouched** — the channel was opened with a pin write and closed with a command naming no pin, and
**nothing the post emitted ever returned that output to 0.** The off code cannot now be anything but
the on code's own.

Three configurations do go, all of them refused, warned about or meaningless on the machine already:
`M7`/`M8` on with a custom off file; a custom on with an `M9` off; and a custom on with a literal off,
or the reverse — under one selector, custom is custom at both ends.

---

## FluidNC

**The post was telling FluidNC operators that their firmware rejects `M6`. It executes it.** `case 6`
sets `ToolChange::Enable` and STEP 4 dispatches to the changer named by `atc:` under the spindle, or
runs the macro named by `m6_macro:` (`FluidNC/src/GCode.cpp`, `src/Spindles/Spindle.cpp`, v3.9.6).
Three places said otherwise; all three now name **stock Grbl and grblHAL**, which do reject it.

*Tool Change Handled By* gains a fifth value, **`FluidNC -- T + M6`**, with its own warning: nothing
needs to intercept the token, and **a sender set to strip the `M6` takes away the thing FluidNC acts
on.** Where neither `atc:` nor `m6_macro:` is declared in `config.yaml` — which the post cannot read —
the firmware accepts the line, changes nothing and reports nothing, and no line in the file says so. A
changer needs FluidNC 3.9.0 or later. Paired with *GCode reprobes Z0 after change* it **warns rather
than refuses**: with only an `m6_macro:` that prompts, the post's re-probe is the job's only correction.

**Three warnings named settings FluidNC does not have** — `$1`, `$27` and Marlin's
`HOMING_FORCE_SET_ORIGIN` — on the one `Grbl` answer that covers both dialects. Each now names both,
and each stays **one** warning: the post cannot tell the two apart, so a per-dialect gate would be a
guess.

| Was | Is also |
|---|---|
| `$1` idle timer | `idle_ms` under `stepping:` — and **255 means *stay energised* on both**, not a 255 ms delay. It is already FluidNC's default |
| `$27` homing pull-off | `pulloff_mm`, which is **per motor** rather than per axis — and there is no `$27` to set: FluidNC declares `$10`, `$20`–`$23`, `$30`, `$32` and the per-axis `$100`/`$110`/`$120`/`$130` and nothing else |
| `HOMING_FORCE_SET_ORIGIN` | `mpos_mm`, the switch location, written at the trigger point |

The hazard each describes is the same on both. Only the remedy differs — a rebuild on Grbl, against a
config line on FluidNC.

---

## How this was checked

**222 cases across six matrices, all passing**, driving Autodesk's own `post.exe` over their `.cnc` job
files and reading the emitted g-code back. Up 15 from v4.1 Beta 3's 207.

Every fold had to be witnessed twice: that the new field does what the old ones did, and that the state
it deleted is really gone. **Two of those are worth naming.** `H33` asserts the deleted title *"Turn
Channel A Off"* is **absent from the dialog**, and its own artifact is where the coolant bug shows — it
went from `M42 P6 S255` … `M9` to `M42 P6 S255` … `M42 P6 S0`. And a case that had asserted a GRBL job
posts *untouched* by a Marlin laser value now asserts the **refusal**, because with one field that
value is what GRBL is handed.

Three cases now cover values nothing had ever posted: GRBL's static-power laser `M3`, a shipped
default emitting not one numbered block, and the `M7`→`M9` derivation, which is the one arm of the
off-code rule that returns something other than what it was handed.

**Property coverage is re-measured rather than adjusted**: 46 of 57 properties varied by a case, and 70
of 91 enum values, against 53/65 and 69/96 before. The numerator falls because seven of the eight
deleted properties were set by a case; **nothing stopped being tested.**

## What is not verified

- **No controller was used.** Every firmware claim above is settled from that firmware's own source and
  changelog with the file and version cited — FluidNC 3.9.6 for the `M6` dispatch, `idle_ms`,
  `pulloff_mm` and `mpos_mm`, grbl 1.1h for `$1` and `error:20`, Marlin `bugfix-2.1.x` and
  RepRapFirmware 3.5 for the laser and coolant forms. This project has no CNC controller, no sender
  console and no machine time.
- **The dialog is never exercised.** The suite sets property *values* on the command line, so how the
  six folded fields read in Fusion's own property panel — their titles, order and descriptions — is
  unchecked. **That is a larger gap in this release than in the last one**, because this release is
  almost entirely a change to the dialog.
- **No file has been posted from Fusion itself.** The suite drives Autodesk's intermediate files, so
  the one thing it never exercises is an operator's own Setup.

`docs/findings.md` §7 is the standing list of what is owed.

## Where to read more

| | |
|---|---|
| Setting up your first job | `docs/guide-hobbyist.md` |
| The guards, tool changes, work offsets | `docs/guide-pro.md` |
| Every setting, in dialog order | `docs/property-reference.md` |
| Why the post behaves as it does | `docs/design.md` |
| What was found, and what is owed | `docs/findings.md` |
| How the post is run, and what a run may claim | `docs/integration.md` |
| The previous release | the `v4.1_Beta3` tag, and `git log v4.1_Beta3..` |
