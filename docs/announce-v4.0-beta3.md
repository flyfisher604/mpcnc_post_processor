# Beta 3 forum announcement

The V1 Engineering forum post announcing v4.0 Beta 3, kept as posted. **Point-in-time, not
maintained** — `release-notes-v4.0-beta3.md` is the document that stays current.

---

## Fusion 360 post for MPCNC / LowRider — v4.0 Beta 3 is available

Beta 3 of the Fusion 360 post processor for MPCNC, LowRider and similar GRBL / Marlin / RepRap
machines is up.

**[Download `MPCNC_v4.0_Beta3.cps`](https://github.com/flyfisher604/mpcnc_post_processor/blob/master/MPCNC_v4.0_Beta3.cps)**
· [Full release notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/master/docs/release-notes-v4.0-beta3.md)
· [First-job guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/master/docs/guide-hobbyist.md)

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

### Please read this part

It is a beta, and I would rather be straight about what stands behind it. **I have no CNC controller
to test against**, so every firmware claim in this release is settled by reading that firmware's own
source, not by running it. No file has yet been posted from Fusion itself either — the automated
testing drives Autodesk's own intermediate files.

So: **review your g-code before you cut**, and if something looks wrong, please post it here along
with the file and your settings. That is by far the most useful thing anyone can do for this project
right now.
