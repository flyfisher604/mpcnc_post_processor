# Beta 3 forum announcement

The V1 Engineering forum post announcing v4.0 Beta 3, kept as posted. **Point-in-time, not
maintained** — `release-notes-v4.0-beta3.md` is the document that stays current.

---

## Fusion 360 post for MPCNC / LowRider — v4.0 Beta 3 is available

Beta 3 of the Fusion 360 post processor for MPCNC, LowRider and similar GRBL / Marlin / RepRap
machines is up.

**[Download `MPCNC_v4.0_Beta3.cps`](https://github.com/flyfisher604/mpcnc_post_processor/releases/download/v4.0_Beta3/MPCNC_v4.0_Beta3.cps)**
· [Release page](https://github.com/flyfisher604/mpcnc_post_processor/releases/tag/v4.0_Beta3)

[Overview and install](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.0_Beta3/README.md)
· [One part, one tool, zeroed by hand](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.0_Beta3/docs/guide-hobbyist.md)
· [Several tools, or several parts on their own fixtures](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.0_Beta3/docs/guide-pro.md)
· [Full release notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.0_Beta3/docs/release-notes-v4.0-beta3.md)

### Two things before your first job — neither is optional

**1. Delete your old copy of the post first.** The file is now `MPCNC_v4.0_Beta3.cps`. Fusion
identifies a post by its filename, so Beta 3 installs *beside* Beta 2 rather than replacing it, and
the two are nearly impossible to tell apart in the picker.

**2. Your saved settings will not carry over.** Every property key in the dialog was renamed, so a
Beta 2 preset falls back to its shipped default on every setting — silently, with no warning. Walk
the dialog once before you post, and look hardest at groups **4**, **5** and **6**, which changed in
meaning as well as in name.

### The fixes most likely to have bitten you

- **GRBL: the `%` wrapper is gone.** Beta 2 wrapped GRBL files in `%`, which stock Grbl 1.1 has no
  such feature for — the line reached the parser and came back `error:1`.
- **The post no longer crashes on the second job of a Fusion session.**
- **No more dragging the bit across your work** on the way to an offset probe. It retracts first.
- **Settings no longer leak from one post into the next** — a second job used to inherit the first
  job's feedrate settings.
- **Marlin can do multi-part work offsets now.** Beta 2 refused these, on the belief that Marlin had
  no work-offset registers. It has them, under the `CNC_COORDINATE_SYSTEMS` build option.
- **Tool changes were rebuilt.** A multi-tool job is refused by default rather than posted with its
  tool changes quietly dropped. You choose who performs the change and who corrects Z0 for the new
  tool's length.
- **Travel Speed X/Y and Travel Speed Z do nothing on GRBL.** Its planner takes a rapid's rate from
  `$110`–`$112`, not from the `F` word in the block. The file now tells you so instead of leaving you
  wondering why the machine ignored the setting.

Plus a long list of clearer warnings, and jobs that are now refused *before* a file is written rather
than posted in a state that would crash your machine.

### What stands behind this

Beta 3 is the first release with an automated regression suite behind it: **190 cases across six
matrices, posting 42 job files through Autodesk's own post engine and reading the emitted g-code back
to check it against the toolpath Fusion asked for** — all 190 passing, with every boolean setting in
the dialog exercised both ways.

Two limits are worth knowing. Firmware behaviour is settled by reading each firmware's own source and
changelog, citing file and version, rather than by running it — I have no controller here. And the
suite drives Autodesk's intermediate files, not a Setup you built yourself.

So it is still a beta: **review your g-code before you cut.** If something looks off, please post it
here with the file and your settings — that is the fastest route to a fix.
