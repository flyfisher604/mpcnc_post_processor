# Release notes — v4.1.1 Beta 3

v4.1.1 Beta 3 is a minor enhancement that adds further support for FluidNC, by no longer rejecting
`M6` (toolchanges), and simplifies the properties dialog by reducing the number of fields from 65 to
57. No capability was added, and none was removed.

Everything here changed since **v4.1 Beta 3**, which shipped two days ago. `git log v4.1_Beta3..` is
the changelog; `FR-1`, `FR-2` and `PC-1` through `PC-6` in `docs/findings.md` are the eight register
rows this closes, and they carry the reasoning and the firmware citations.

**Coming from v4.0 Beta 3?** Read [the v4.1 Beta 3 notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/docs/release-notes-v4.1-beta3.md)
as well. The router, laser and coolant outputs landed there, and this release does not restate them.

---

## FluidNC

**The post was previously telling FluidNC operators that their firmware rejects `M6`, which was not
true.** `M6` sets `ToolChange::Enable` and dispatches to the tool changer declared as `atc:` under the
spindle, or runs the macro named by `m6_macro:` in `config.yaml` (`FluidNC/src/GCode.cpp`,
`src/Spindles/Spindle.cpp`, v3.9.6). Three separate texts said otherwise; all three now limit that
warning to stock Grbl and grblHAL, which are the ones that reject it.

*Tool Change Handled By* gains a **FluidNC — T + M6** value, and it warns about the thing that
actually is a risk: a sender that strips the `M6` takes away the token FluidNC acts on. And where
neither `atc:` nor `m6_macro:` is declared, the firmware accepts the line, changes nothing and reports
nothing — the post cannot read your `config.yaml`, so it says so rather than assuming. A changer needs
FluidNC 3.9.0 or later.

Paired with *GCode reprobes Z0 after change*, the new value warns rather than refusing. With only an
`m6_macro:` that prompts, the post's re-probe is the job's only correction, so refusing it would remove
the correction along with the risk. Selected on the wrong firmware it is still refused: RepRap by the
dialect guard, Marlin by the tool-length guard above it.

Three warnings also previously named settings FluidNC did not have. Each now names the settings
appropriately for FluidNC, and each stays **one** warning — the post cannot tell the two dialects
apart, so a per-dialect gate would be a guess:

| Grbl | FluidNC |
|---|---|
| the idle timer, `$1` | `idle_ms` under `stepping:`. A value of 255 means *stay energised* on both, and it is already FluidNC's default |
| the homing pull-off, `$27` | `pulloff_mm`, which is per motor rather than per axis. There is no `$27` to set on FluidNC at all |
| a rebuild with `HOMING_FORCE_SET_ORIGIN` | an `mpos_mm` that accounts for the pull-off |

The hazard is the same on both firmwares. Only the remedy differs, and now the warning says what is
required for FluidNC.

---

## The dialog

Six places asked two or three questions to settle one thing. Each is now one field:

| Now one field | Was |
|---|---|
| **Line #s** (group 1) | *Enable Line #s*, *First Line #*, *Line # Increment* |
| **Probe X Y Offset** (group 5) | *Probe X Offset*, *Probe Y Offset* |
| **Safe Z** (group 5) | *Safe Z*, and group 3's *Safe Z to Rapid* |
| **Manual Position X Y** (group 6) | *Manual Position X*, *Manual Position Y* |
| **Laser Output** (group 8) | *Laser: Marlin/Reprap Mode*, *Laser: GRBL Mode* |
| **Channel A / B Output** (group 9) | *Turn Channel A/B On* **and** *Turn Channel A/B Off* |

No functionality was removed from the post. What went were states the dialog could express and no
machine could use — X without Y, an increment for numbers no file would carry, a laser field never read
for the firmware selected, and off fields that could name a different output than the on fields did.

The two X/Y fields now take two numbers and a comma — `-10, -400`. Whitespace around the comma is
ignored, and one parser serves both fields, so each half takes exactly the syntax *Machine Travel Z*
takes.

### Line #s

Three answers in one field: `Off`, `N10 N11 N12 ... step 1`, and `N10 N20 N30 ... step 10`. The two
on-values differ only in the step — one for a sender that counts blocks one by one, the other for one
that leaves room to insert between them. Numbering always starts at `N10`, and restarts in every file.

The two companion fields did nothing whenever the checkbox was off, which is the shipped default, and
the dialog gave no hint that it was asking twice for numbers no file would carry. What this costs is an
arbitrary first number and an arbitrary increment: a sender convention that is neither 10/1 nor 10/10
can no longer be matched.

### Probe X Y Offset

The same displacement in one field instead of two, and neither half could ever be read without the
other. Either number may be signed, and decimals now work where the old integer fields took whole mm.
What that costs is Fusion's integer spinner.

`0, 0` is a meaning here and empty is not, so a value the post cannot read falls back to the origin —
the behaviour the post had before the field existed — and the post says so rather than refusing.

### Safe Z

Group 3's *Safe Z to Rapid* and group 5's *Safe Z* were two properties holding one number, with two
parsers and a seventy-line `switch` that re-implemented the shared resolver branch for branch.

Both are heights in the same frame: the part's work coordinates, measured from the touch-off Z0, and
both mean a height that clears the work. Group 3 asks whether the tool is at or above it; group 5 takes
the tool to it after a probe. One meaning with two readers, and a machine on which the two differ is
one where the post rapids through the height it has just called clear. Group 3 keeps its switch and has
no height field of its own, which is what its title always claimed.

Two side effects worth knowing. An unreadable *Safe Z* is now reported once per file, at the parse,
rather than once per section. And where an operation's own retract level could not be used, the file
said *level not abs* or *level not defined* and now says in one sentence that the level was not usable,
the remedy being the same either way.

### Manual Position X Y

One point, asked as one question. The dialog could previously express two states that are not positions
at all — X without Y, and Y without X — and the post spent a refusal putting the halves back together.
That half-filled point is now inexpressible rather than rejected, which deletes the guard instead of
moving it. A typo is still refused, rather than read as empty and the change made quietly over the last
cut.

*Manual Position Z* stays its own field. Its description says it may be filled without X and Y, so
folding it in would add a state rather than remove one.

### Laser Output

*CNC Firmware* chose one of the two old fields, and the other was dead on every job. The chosen output
is now the dispatch where the firmware used to be, and the PWM scale goes with the value rather than
with the job:

| Value | `S` scale |
|---|---|
| `Grbl: M4 S{PWM}/M5 dynamic power` — the default | 0–1000 against `$30` |
| `Grbl: M3 S{PWM}/M5 static power` | 0–1000 against `$30` |
| `Mrln: M106 P{n} S{PWM}/S0` | a 0–255 byte, output number from *Laser: Pin/Fan #* |
| `Mrln: M3 O{PWM}/M5` | a 0–255 byte, no output number |
| `Mrln: M42 P{pin} S{PWM}` | a 0–255 byte, output number from *Laser: Pin/Fan #* |

One field made two mistakes expressible, and each is answered. A GRBL laser job holding the `Mrln:`
fan or pin value is refused, GRBL having neither command and answering `error:20` with the head over
the work, where before it was silently ignored. A GRBL *milling* job holding one is not refused,
because it emits no laser code at all; without that gate the refusal would have fired on every milling
job whose operator once chose a Marlin value. Any other dialect mismatch warns, on the same ruling as
group 9's: a label says which firmware the post shipped a value for, not that no other firmware takes
it.

### Channel A / B Output

Covered under **Coolant** below, the off field being the one fold that also closed a bug.

---

## Three things before your first v4.1.1 job

**1. Delete your old copy of the post first.** The file is `MPCNC_v4.1.1_Beta3.cps`, so it installs
beside v4.1 Beta 3 rather than replacing it. One version bump carries all six folds, so your settings
reset once rather than six times.

**2. Four properties reset to their defaults** — *Line #s*, *Probe X Y Offset*, *Manual Position X Y*
and *Laser Output*. The coolant channel outputs and *Safe Z* keep whatever you had set, their keys not
having moved. What the four fall back to is what you had, with one exception:

| Resets | Falls back to | Which is |
|---|---|---|
| **Line #s** | `Off` | what the *Enable Line #s* checkbox shipped |
| **Probe X Y Offset** | `0, 0` | probing at the origin, as two zeroed fields did |
| **Manual Position X Y** | empty | the change happening above the last cut, as two empty fields did |
| **Laser Output** | `Grbl: M4 S{PWM}/M5 dynamic power` | not what you had, if you run Marlin or RepRap |

**3. If you cut with a laser, set *Laser Output* before you post.** It is one field now and
*CNC Firmware* ships `Grbl`, so the merged field ships a GRBL default. A Marlin or RepRapFirmware laser
job that does not answer it emits `M4 S…`, which those firmwares either do not implement or implement
with `S` read as a 0–255 byte instead of GRBL's 0–1000. The post warns when the value's dialect does
not match *CNC Firmware*, and refuses outright where the mismatch cannot run at all — a GRBL job
carrying `Mrln: M106` or `Mrln: M42`. Milling jobs are unaffected.

---

## Coolant now says what to output

The coolant properties have been simplified — you say what to output based on your GCode and your
machine's capabilities, where previously you had to configure both on and off. The off code is now
derived from the on code and has no field of its own: `M106` and `M42` close on the same output with
`S0`, `M7` and `M8` close with `M9`, and *Use custom* closes from the channel's own Off file.

The on fields are retitled **Channel A Output** and **Channel B Output**, and their keys do not move.
All four custom-file properties survive unchanged. What changed is that one answer now reaches both of
a channel's files, so an unnamed *off* file is reported on a channel whose *on* file is named, which
two independent selectors could not say.

**One bug went with the merge, and it is the only change in this release that alters emitted g-code.**
The guard against a mismatched pair only ever looked at the *off* code. So a channel switched on with
`M106` or `M42` while its off field held the shipped `M9` passed that guard: the channel was opened
with a pin write and closed with a command naming no pin, and nothing the post emitted ever returned
that output to 0. The off code cannot now be anything but the on code's own.

Three configurations do go, all of them already refused, warned about, or meaningless on the machine:
`M7`/`M8` on with a custom off file; a custom on with an `M9` off; and a custom on with a literal off,
or the reverse. Under one selector, custom is custom at both ends.

---

## What stands behind this

The regression suite is at 222 cases across six matrices, all passing, up from 207. Every property
change had to be witnessed twice — that the new field does what the old ones did, and that the state it
deleted is really gone.

Two of those are worth naming. A case asserts the deleted title *"Turn Channel A Off"* is absent from
the dialog, and its own artifact is where the coolant bug shows: it went from `M42 P6 S255` … `M9` to
`M42 P6 S255` … `M42 P6 S0`. And a case that had asserted a GRBL job posts untouched by a Marlin laser
value now asserts the refusal, because with one field that value is what GRBL is handed.

Three cases now cover values nothing had ever posted: GRBL's static-power laser `M3`, a shipped default
emitting not one numbered block, and the `M7`→`M9` derivation, which is the one arm of the off-code
rule that returns something other than what it was handed.

Property coverage is re-measured rather than adjusted: 46 of 57 properties varied by a case, and 70 of
91 enum values, against 53/65 and 69/96 before. The numerator falls because seven of the eight deleted
properties were set by a case. Nothing stopped being tested.

## What is not verified

The two standing limits have not moved, and one of them matters more this time.

- **No controller was used.** Firmware behaviour is settled by reading each firmware's own source and
  change log, citing file and version — FluidNC 3.9.6 for the `M6` dispatch, `idle_ms`, `pulloff_mm`
  and `mpos_mm`, grbl 1.1h for `$1` and `error:20`, Marlin `bugfix-2.1.x` and RepRapFirmware 3.5 for
  the laser and coolant forms. This project has no CNC controller, no sender console and no machine
  time.
- **The Fusion dialog itself is never exercised.** The suite drives Autodesk's headless post engine
  over their intermediate files and sets properties on the command line. This release is almost
  entirely a change to the dialog, so how these six fields read in the property panel — their titles,
  order and descriptions — is the one thing the automated integration test cannot check.
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
