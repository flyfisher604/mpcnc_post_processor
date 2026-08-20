**v4.1 Beta 3 of the Fusion 360 post processor for MPCNC, LowRider and similar GRBL / Marlin / RepRap machines is available**

**[Download MPCNC_v4.1_Beta3.cps](https://github.com/flyfisher604/mpcnc_post_processor/releases/download/v4.1_Beta3/MPCNC_v4.1_Beta3.cps)** · [Release page](https://github.com/flyfisher604/mpcnc_post_processor/releases/tag/v4.1_Beta3) · [Release notes](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/docs/release-notes-v4.1-beta3.md)

[Overview and install](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/README.md) · [Hobby Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/docs/guide-hobbyist.md) · [Pro Guide](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1_Beta3/docs/guide-pro.md)

One thing changed, and it answers [issue 16](https://github.com/flyfisher604/mpcnc_post_processor/issues/16): **the router, the laser and each coolant channel can now name the fan or pin output they switch.** Before this, the router could only be prompted for by hand or commanded with \`M3\`, the laser could only use fan 0, and coolant could only use one of two pin numbers someone chose in 2018.

### Two things before your first job

**1. Delete your old copy of the post first.** The file is now \`MPCNC_v4.1_Beta3.cps\`. Fusion identifies a post by its filename, so this installs **beside** v4.0 Beta 3 rather than replacing it.

**2. Three settings will fall back to their defaults.** Fusion stores a setting by its internal key, and three keys had to move — a checkbox's stored on/off is not one of four choices, and a pin number carried into a fan slot points at a fan nobody has. **What they fall back to is what you already had:** the router defaults to asking you to switch it on, and all four coolant codes still default to GRBL's \`M7\` / \`M8\` / \`M9\`. A job posts the same file it did in v4.0 Beta 3 unless you choose otherwise — with one exception, below.

### Turning the router on and off

**Manual Spindle On/Off** is now **Spindle Control**, with four choices:

- **Prompt the operator (M0)** — the default, and what the checkbox did. The post sends no spindle code and stops to ask you.

- **Spindle - M3 S{RPM}/M5** — what the checkbox did when you switched it off.

- **Fan - M106 P{n} S255/S0** — for a relay wired to a fan header.

- **Pin - M42 P{pin} S255/S0** — for a relay on a spare output pin.

The last two are the point of this release. **A stock Marlin build has no \`M3\` at all** — it is behind the \`SPINDLE_FEATURE\` / \`LASER_FEATURE\` build options and a stock build has neither, so it answers \`M3\` with an unknown-command warning and runs the whole job with the router never started. Switching a fan output is something that same build *can* do.

Both are on-or-off only: no speed, no direction. The RPM your job asks for goes into a comment, and the file says it was requested rather than commanded — including at every mid-job speed change, so nothing is silently ignored.

### The laser fix, and it may have bitten you

**The Marlin/RepRap fan mode was firing the wrong fan.** It sent \`M106\` with no fan number, and Marlin reads a missing fan number as fan 0. So if your laser was on any fan but 0, **it was never fired, and fan 0 was driven at laser power instead.** The off code was \`M107\`, which on RepRapFirmware turns off the current tool's fans rather than the one you named.

It now sends \`M106 P{n} S{power}\` and \`M106 P{n} S0\`, with the fan number from the new **Laser: Pin/Fan #**. \`M107\` is gone from the post entirely.

**This is the one change that alters an existing job's output** — a Marlin or RepRap laser job in fan mode gains \` P0\`. If your laser is not on fan 0, set the new field.

### Coolant is no longer wired for one board

Group 9's Marlin choices were \`M42 P6 S255\` and \`M42 P11 S255\`, with the pin number frozen into the choice. **Those two numbers are RAMPS numbers** — the servo header, which is a sensible place for a relay signal. On a **Rambo**, the board V1 shipped for the MPCNC, pin 6 is \`HEATER_2\` and pin 11 is \`Y_MIN\`, and Marlin refuses \`M42\` on both as protected pins — so the coolant never switched, and nothing in the file said so.

Each channel now names its own output, through **Channel A Pin/Fan #** and **Channel B Pin/Fan #**, and the fan form is offered beside the pin form. The GRBL defaults did not move.

### One field, four meanings

**Pin/Fan #** appears in all three groups now, and what the number *is* depends on the mode and your firmware: a fan index or a board pin on Marlin, a fan number or a GpOut port on RepRapFirmware. **Re-check it whenever you change either.** A wrong number is not equally visible on the two — RepRapFirmware says *\*"Fan number not found"\**, while **Marlin just returns and says nothing**, so the router never starts and the job cuts with a dead spindle.

Two conditions on the pin mode specifically, both Marlin: \`M42\` is only compiled in where \`DIRECT_PIN_CONTROL\` is enabled, which stock Marlin ships commented out; and Marlin refuses \`M42\` on a protected pin, which every fan pin is. **So use the fan mode for a fan header and the pin mode for a spare output** — the pin mode cannot reach a fan header at all.

### Three new refusals

The post now stops before writing a file if:

- **A fan or pin output is chosen for the router or the laser on a GRBL job.** GRBL has neither command and answers \`error:20\`, which stops the job with the tool still in the cut. The coolant channels warn instead of refusing, on purpose — their labels say which firmware the code shipped for, not that no other firmware takes it.

- **The pin mode is chosen and Pin/Fan # is still 0.** Pin 0 is nobody's router. Fan 0 is a real fan, and is allowed.

- **A coolant channel is switched on with one form and off with the other**, which would leave the output running for the rest of the job.

### What stands behind this

The regression suite is now at **207** cases across six property matrices, all passing, with **17** added for this change. Both branches of every new refusal are tested, not just the refusal — a default GRBL job still has to post.

Worth knowing: three of the suite's structural checks had gone quiet. *Is the spindle running before the first cut*, *is it stopped before the program ends* and *is the coolant turned off again* only knew about \`M3\`/\`M5\` and \`M7\`/\`M8\`/\`M9\`. A job switching a fan output matched none of them, so all three quietly reported *\*skipped\** — and a skip counted as a pass. This release opened that hole and closes it: all three now read the new forms, and there is a case that exercises them.

The two limits from Beta 3 still hold:
- Differences in firmware behaviour were resolved by reading each firmware's source code and change log, citing file and version, rather than by running g-code through different controllers. **No relay has been switched by this post** — I have no controller here.
- The suite drives Autodesk's own headless post engine over their intermediate files. The dialog itself is never exercised, so how these new fields read in Fusion's property panel is unchecked.

So it is still a beta, and this release touches what turns your router on: **review your g-code before you cut, and check the new field before you trust it.** If something looks off, post it here with the file and your settings — that is the fastest route to a fix.
