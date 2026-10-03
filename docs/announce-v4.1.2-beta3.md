>**v4.1.2 Beta 3 of the Fusion 360 post processor for MPCNC, LowRider and similar GRBL / Marlin / RepRap / FluidNC machines is available**
>
>**[Download MPCNC_v4.1.2_Beta3.cps](https://github.com/flyfisher604/mpcnc_post_processor/releases/download/v4.1.2_Beta3/MPCNC_v4.1.2_Beta3.cps)** · [Release page](https://github.com/flyfisher604/mpcnc_post_processor/releases/tag/v4.1.2_Beta3) · [Release notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.2_Beta3/docs/release-notes-v4.1.2-beta3.md)
>
>[Overview and install](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.2_Beta3/README.md) · [Hobby Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.2_Beta3/docs/guide-hobbyist.md) · [Pro Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.2_Beta3/docs/guide-pro.md) · [Changelog](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.2_Beta3/CHANGELOG.md)

v4.1.2 Beta 3 is a correction release. **If you change tools inside one file, please update** — it fixes a bug that could leave the spindle stopped after a tool change. Your saved settings carry over.

### The spindle restarts after every tool change

After a tool change, if the next tool ran at the same speed and direction as the last one, the post did not start the spindle again. With `M3` the new tool went into the cut on a stopped spindle; with the default *Prompt the operator* there was no *Turn ON* prompt; with a fan or pin relay the relay stayed off. The same happened where a laser operation sat between two milling operations at one speed.

This only affected jobs with group 6 set to *Manual change at a pause* or *Sender or firmware macro changes it*. The shipped default refuses multi-tool jobs, so a job posted on the defaults was never affected.

Every stop is now seen by the next start, and after any tool change the spindle is started — or you are prompted to start it — before the next cut.

### M7 and M8 coolant on Marlin and RepRap

`M7` and `M8` were labelled as GRBL codes, so Marlin and RepRap jobs using them were warned that the job would stop mid-cut. That was wrong: Marlin runs them under `COOLANT_MIST` / `COOLANT_FLOOD`, and RepRapFirmware runs your `/sys/M7.g`–`M9.g` macros. The values now read **M7 on, M9 off** and **M8 on, M9 off**, and each firmware is warned about what *it* needs instead.

### Safe Z

*Safe Z* now accepts a space before the value or after the colon, and a leading decimal point: ` 15`, `.5` and `Retract: 5` all work. A value it still cannot read — `-5`, `15mm`, `Retract:` — now refuses the post with a message, where it used to be replaced by 15 mm without you knowing.

### Also

- Warnings quote dialog titles and group names exactly as the dialog shows them.
- Tooltips are shorter; the detail moved to the property reference.
- Files at the default comment level are about 7% smaller — an internal trace now appears only at `Debug`.
- The README and guides were reorganised and brought up to date, and the release history moved to a changelog.

### Before your first job

1. **Delete your old copy of the post first.** The file is `MPCNC_v4.1.2_Beta3.cps`, so it installs beside v4.1.1 Beta 3 rather than replacing it.
2. **Your settings carry over** — nothing reset this time.
3. **If you changed *Safe Z*, post once and read the dialog.**

### What stands behind this

The regression suite is at 228 cases, all passing, up from 222; the new spindle cases fail against v4.1.1. As before, firmware behaviour is settled from each firmware's own source rather than on a machine, and the Fusion dialog itself is not exercised by the suite.

>This is still a beta: **review your g-code before you cut.** If something reads wrong, post it here with your settings — that is the fastest route to a fix.
