**v4.1.1 Beta 3 of the Fusion 360 post processor for MPCNC, LowRider and similar GRBL / Marlin / RepRap / FluidNC machines is available**

**[Download MPCNC_v4.1.1_Beta3.cps](https://github.com/flyfisher604/mpcnc_post_processor/releases/download/v4.1.1_Beta3/MPCNC_v4.1.1_Beta3.cps)** · [Release page](https://github.com/flyfisher604/mpcnc_post_processor/releases/tag/v4.1.1_Beta3) · [Release notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/release-notes-v4.1.1-beta3.md)

[Overview and install](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/README.md) · [Hobby Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/guide-hobbyist.md) · [Pro Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/guide-pro.md)

This one follows v4.1 Beta 3 closely and adds no new capability. **The dialog asks 57 questions where it asked 65**, and **FluidNC is finally described as the firmware it is** rather than as a Grbl that rejects `M6`.

### The dialog

Six places asked two or three questions to settle one thing. Each is now one field:

| Now one field | Was |
|---|---|
| **Line #s** | *Enable Line #s*, *First Line #*, *Line # Increment* |
| **Probe X Y Offset** | *Probe X Offset*, *Probe Y Offset* |
| **Safe Z** | *Safe Z*, and group 3's *Safe Z to Rapid* |
| **Manual Position X Y** | *Manual Position X*, *Manual Position Y* |
| **Laser Output** | *Laser: Marlin/Reprap Mode*, *Laser: GRBL Mode* |
| **Channel A / B Output** | *Turn Channel A/B On* **and** *Turn Channel A/B Off* |

Nothing was removed from the post. What went are states the dialog could express and no machine could use — X without Y, an increment for numbers no file would carry, a laser field the firmware you picked never reads, and an off-code that could name a different output than the on-code did.

The two X/Y fields now take two numbers and a comma — `-10, -400` — and the probe offset gained signed decimals where it took whole mm.

### Three things before your first v4.1.1 job

**1. Delete your old copy of the post first.** The file is `MPCNC_v4.1.1_Beta3.cps`, so it installs **beside** v4.1 Beta 3 rather than replacing it.

**2. Four settings reset to their defaults** — *Line #s*, *Probe X Y Offset*, *Manual Position X Y* and *Laser Output*. Fusion stores a setting by its internal key, and those four keys had to move. The coolant channel outputs and *Safe Z* keep whatever you had set.

**3. If you cut with a laser, set *Laser Output* before you post.** It is one field now, and *CNC Firmware* ships `Grbl`, so the merged field ships a GRBL default. **A Marlin or RepRapFirmware laser job that does not answer it emits `M4 S…`** — a command those firmwares either do not implement, or implement with `S` read as a 0–255 byte instead of GRBL's 0–1000, so the power comes out wrong. The post warns and names both. Milling jobs are unaffected.

### One coolant bug went with the merge

**If you switch a coolant channel through a fan or a pin, this is the reason to take the release.** The old pair of dropdowns let you set the on-code to `M106` or `M42` while the off-code stayed at its shipped `M9`, and the guard against a mismatched pair only ever looked at the *off* code — so that combination passed. The channel was opened with a pin write and closed with a command naming no pin, and **nothing the post emitted ever switched that output back off.**

The off code is now derived from the on code and has no field of its own: `M106` and `M42` close on the same output with `S0`, `M7` and `M8` close with `M9`, and *Use custom* closes from the channel's own Off file.

### FluidNC

**The post was telling FluidNC operators that their firmware rejects `M6`. It executes it** — dispatching to the tool changer declared as `atc:` under the spindle, or running the macro named by `m6_macro:` in `config.yaml`. Three separate texts said otherwise; all three now name **stock Grbl and grblHAL**, which are the ones that reject it.

*Tool Change Handled By* gains a **FluidNC — T + M6** value, and it warns about the thing that actually bites: **a sender set to strip the `M6` takes away the token FluidNC acts on.** And where neither `atc:` nor `m6_macro:` is declared, the firmware accepts the line, changes nothing and reports nothing — the post cannot read your `config.yaml`, so it says so rather than assuming. A changer needs FluidNC 3.9.0 or later.

Three warnings also named settings FluidNC does not have. Each now names both dialects:

- the idle timer is `$1` **or** `idle_ms` under `stepping:` — and **255 means *stay energised* on both**, not a 255 ms delay. It is already FluidNC's default.
- the homing pull-off is `$27` **or** `pulloff_mm`, which is **per motor** rather than per axis. There is no `$27` to set on FluidNC at all.
- where Grbl needs a rebuild with `HOMING_FORCE_SET_ORIGIN`, FluidNC needs an `mpos_mm` that accounts for the pull-off.

The hazard is the same on both firmwares. Only the remedy differs, and now the warning says which is yours.

### What stands behind this

The regression suite is at **222** cases across six matrices, all passing, up from 207. Every fold had to be witnessed twice — that the new field does what the old ones did, and that the state it deleted is really gone, which for the coolant off-field means a case asserting the deleted title is absent from the dialog.

The two standing limits have not moved, and one of them matters more this time:

- Firmware behaviour is settled by reading each firmware's own source and change log, citing file and version — FluidNC 3.9.6, grbl 1.1h, Marlin `bugfix-2.1.x`, RepRapFirmware 3.5 — not by running g-code through controllers. **I have no controller here.**
- The suite drives Autodesk's headless post engine over their intermediate files and sets properties on the command line. **The Fusion dialog itself is never exercised** — and this release is almost entirely a change to the dialog. How these six fields read in the property panel is the one thing I cannot check.

So it is still a beta: **review your g-code before you cut.** If a setting reads wrong, or a folded field does not take what you expect, post it here with your settings — that is the fastest route to a fix.
