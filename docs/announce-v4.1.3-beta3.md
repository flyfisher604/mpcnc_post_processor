>**v4.1.3 Beta 3 of the Fusion 360 post processor for MPCNC, LowRider and similar GRBL / Marlin / RepRap / FluidNC machines is available**
>
>**[Download MPCNC_v4.1.3_Beta3.cps](https://github.com/flyfisher604/mpcnc_post_processor/releases/download/v4.1.3_Beta3/MPCNC_v4.1.3_Beta3.cps)** · [Release page](https://github.com/flyfisher604/mpcnc_post_processor/releases/tag/v4.1.3_Beta3) · [Release notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.3_Beta3/docs/release-notes-v4.1.3-beta3.md)
>
>[Overview and install](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.3_Beta3/README.md) · [Hobby Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.3_Beta3/docs/guide-hobbyist.md) · [Pro Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.3_Beta3/docs/guide-pro.md) · [Changelog](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.3_Beta3/CHANGELOG.md)

v4.1.3 Beta 3 is a correction release. **If you run FluidNC, please update.** Your saved settings carry over.

### FluidNC runs the file

Thank you to the users here who reported this. FluidNC refused files from this post with *error 14, line too long*, and the only workaround was deleting the comments by hand.

The cause was the post's warnings. Some ran to over 600 characters on a single comment line, and every GRBL file begins with one. Classic Grbl ignores comment text when it checks a line's length, but FluidNC counts it and stops at 255 characters.

Long comments and warnings are now split over several lines, none longer than about 100 characters. Only the comments changed: every move and command is the same as before.

### Before your first job

1. **Delete your old copy of the post first.** The file is `MPCNC_v4.1.3_Beta3.cps`, so it installs beside v4.1.2 Beta 3 rather than replacing it.
2. **Your settings carry over.** Nothing was reset.
3. **Stop deleting comments by hand.** Post the job again instead. The warnings describe things the file does, such as replacing a stored origin, and they are worth reading before you cut.

### What stands behind this

The regression suite now checks that no line in any file is longer than FluidNC accepts. That check fails against v4.1.2 and passes on this release, and all 228 cases pass. As before, firmware behaviour is settled from each firmware's own source rather than on a machine.

>This is still a beta: **review your g-code before you cut.** If something reads wrong, post it here with your settings. That is the fastest route to a fix.
