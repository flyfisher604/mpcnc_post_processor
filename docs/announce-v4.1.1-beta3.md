>**v4.1.1 Beta 3 of the Fusion 360 post processor for MPCNC, LowRider and similar GRBL / Marlin / RepRap / FluidNC machines is available**
>
>**[Download MPCNC_v4.1.1_Beta3.cps](https://github.com/flyfisher604/mpcnc_post_processor/releases/download/v4.1.1_Beta3/MPCNC_v4.1.1_Beta3.cps)** · [Release page](https://github.com/flyfisher604/mpcnc_post_processor/releases/tag/v4.1.1_Beta3) · [Release notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/release-notes-v4.1.1-beta3.md)
>
>[Overview and install](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/README.md) · [Hobby Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/guide-hobbyist.md) · [Pro Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.1_Beta3/docs/guide-pro.md)

v4.1.1 Beta 3 is a minor enhancement that adds further support for FluidNC, by no longer rejecting `M6` (toolchanges), and simplifies the properties dialog by reducing the number of fields from 65 to 57.

### FluidNC

**The post was previously telling FluidNC operators that their firmware rejects `M6`, which was not true.** `M6` actually dispatches to the tool changer declared as `atc:` under the spindle or the macro named by `m6_macro:` in `config.yaml`. Three separate texts said otherwise; all three now limit that warning to stock Grbl and grblHAL, which are the ones that reject it.

*Tool Change Handled By* gains a **FluidNC — T + M6** value, and it warns about the thing that actually is a risk: a sender that strips the `M6` takes away the token FluidNC acts on. And where neither `atc:` nor `m6_macro:` is declared, the firmware accepts the line, changes nothing and reports nothing — the post cannot read your `config.yaml`, so it says so rather than assuming. A changer needs FluidNC 3.9.0 or later.

Three warnings also previously named settings FluidNC did not have. Each now names the settings appropriately for FluidNC:

- the idle timer is `$1` or `idle_ms` under FluidNC's `stepping:`. A value of 255 means *stay energised* on both, and it is already FluidNC's default.
- the homing pull-off is `$27` or `pulloff_mm` under FluidNC (which is per motor rather than per axis).
- where Grbl needs a rebuild with `HOMING_FORCE_SET_ORIGIN`, FluidNC needs an `mpos_mm` that accounts for the pull-off.

The hazard is the same on both firmwares. Only the remedy differs, and now the warning says what is required for FluidNC.

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

No functionality was removed from the post. What went were states the dialog could express and no machine could use — X without Y, an increment for numbers no file would carry, a laser field never read for the firmware selected, and off fields that could name a different output than the on fields did.

The two X/Y fields now take two numbers and a comma — `-10, -400`.

### Three things before your first v4.1.1 job

**1. Delete your old copy of the post first.** The file is `MPCNC_v4.1.1_Beta3.cps`, so it installs beside v4.1 Beta 3 rather than replacing it.

**2. Four properties reset to their defaults** — *Line #s*, *Probe X Y Offset*, *Manual Position X Y* and *Laser Output*. The coolant channel outputs and *Safe Z* keep whatever you had set.

**3. If you cut with a laser, set *Laser Output* before you post.** The post warns if the selected Laser mode doesn't match the GCode variant selected. Milling jobs are unaffected.

### Coolant now says what to output

The coolant properties have been simplified — you say what to output based on your GCode and your machine's capabilities, where previously you had to configure both on and off. 
The off code is now derived from the on code and has no field of its own: `M106` and `M42` close on the same output with `S0`, `M7` and `M8` close with `M9`, and *Use custom* closes from the channel's own Off file.

### What stands behind this

The regression suite is at 222 cases across six matrices, all passing, up from 207. Every property change had to be witnessed twice — that the new field does what the old ones did, and that the state it deleted is really gone.

The two standing limits have not moved, and one of them matters more this time:

- Firmware behaviour is settled by reading each firmware's own source and change log, citing file and version — FluidNC 3.9.6, grbl 1.1h, Marlin `bugfix-2.1.x`, RepRapFirmware 3.5.

- The suite drives Autodesk's headless post engine over their intermediate files and sets properties on the command line. The Fusion dialog itself is never exercised — and this release is almost entirely a change to the dialog. How these six fields read in the property panel is the one thing the automated integration test cannot check.

>This is still a beta: **review your g-code before you cut.** If a setting reads wrong, or a folded field does not take what you expect, post it here with your settings — that is the fastest route to a fix.
