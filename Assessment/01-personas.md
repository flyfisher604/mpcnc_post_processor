# Step 1 — Who actually uses this post

Derived from the machines and firmware that exist, not from what the code
implements. Evidence tags: `[SDK]` Autodesk's own posts on this machine, `[DOC]`
vendor or firmware documentation, `[COMMUNITY]` forum/retail, `[INFERRED]` mine.

## The hardware and firmware landscape

**The anchor community has moved.** The assumption that these machines are
endstop-poor and cannot home is out of date for the current flagship:

- LowRider CNC V4 has endstops on **all three axes** — one on X at the core, two
  on Y (one per YZ plate), two on Z (one per YZ plate). `[DOC]`
  docs.v1e.com/lowrider — *"Full Y axis squaring, Z axis leveling, and Z probing
  are standard for excellent precision and accuracy."*
- The Jackpot controller runs FluidNC, *"fully GRBL compatible with extended
  features"*, and documents `$H` plus `$HX, $HY, $HZ for individual axes`.
  `[DOC]` docs.v1e.com/electronics/jackpot
- Firmware is explicitly plural: *"Marlin, RepRap firmware, GRBL, FluidNC,
  GRBLHal, or others."* `[DOC]` docs.v1e.com/lowrider
- The MPCNC line offers both serial-wired (single endstop per axis) and dual
  endstop Marlin configurations; *"Any of the V1CNC configs that don't have
  `Dual` or `DualLR` in the name are configured for serial wiring."* `[DOC]`
  docs.v1e.com/electronics/marlin-firmware

**Two documented job-start workflows, not one.** This is the single most
important sentence I found, because the post's behaviour has to serve both:

> *"You can now use the machine in two ways. Quick one off jobs, setting the tool
> position by hand, starting with `G92 X0 Y0 Z0`, and just running the job, or by
> starting each job with a `G28` (home and auto square)."*
> `[DOC]` docs.v1e.com/electronics/dual-endstops

So within the anchor community both a **hand-zeroed, never-homed machine** and a
**homed-and-squared machine** are first-class, vendor-documented uses. Neither is
an edge case.

**Work zero is set by offset write or probe, not by homing.** `[DOC]`
docs.v1e.com/lowrider gives, for Z:

- FluidNC: `G10 L2 P0 Z0 ;set Z to zero`, and `G38.2 Z-100 F60 ;probe slow`
- Marlin: `G92 Z0`, and `G38.2 Z0`

Note these are *different mechanisms* — `G10 L2` writes a work-coordinate offset
that survives, `G92` sets a temporary position offset. That difference matters in
step 3 and it is a plausible source of firmware branching that is actually
justified.

**Comparable machines are GRBL-family and ship homing.** Shapeoko, X-Carve and
Onefinity are GRBL-based; current models include homing switches, and touch
probes are a standard accessory across the class. `[COMMUNITY]` cncsourced.com,
shapeokoenthusiasts.gitbook.io, retail probe listings. I have no hard figure for
what fraction have homing enabled in practice — treat "most current machines can
home" as `[COMMUNITY]`, not `[DOC]`.

**Autodesk ships no Marlin post at all.** Of 490 cached posts on this machine
there is `grbl.cps`, `grbl laser.cps`, `grbl turning.cps`, `reprap.cps` and
`reprap fff.cps` — and nothing for Marlin. `[SDK]`
`AppData/Local/Autodesk/Autodesk Fusion 360/CAM/cache/posts/`. This is why a
Marlin-capable post has value that a stock post cannot supply, and it is the
strongest single argument that this project should exist at all.

## The personas

Frequency is my judgement unless tagged. The axes that actually change what the
post must emit are **licence tier**, **firmware dialect**, and **whether machine
position is trusted** — not machine brand.

### P1 — Hand-zeroed beginner, personal licence, GRBL/FluidNC
Most common. `[INFERRED]` from the free tier being the default entry point and
`G92`-style zeroing being the documented quick path. One operation per post, no
homing, no probe, tool changes by re-posting per tool and swapping by hand. Never
sees a second setup. Cares that the file starts cutting at the bit's current
position and never plunges unexpectedly.

### P2 — Hand-zeroed beginner, personal licence, Marlin
Same as P1 with a different dialect. Distinct because Marlin's G-code
availability genuinely differs (step 3), and because no stock Autodesk post
serves them at all.

### P3 — Homed and squared, full licence, GRBL/FluidNC, has a Z probe
The current LowRider V4 owner. Machine position *is* trusted after `$H`. Runs
multiple operations in one setup, may run several tools. `[DOC]` for the
capability; frequency `[INFERRED]` — this is where the community's flagship
machine points.

### P4 — Homed, full licence, Marlin/SKR
As P3 on Marlin. Whether this persona can use work-offset features at all
depends on a Marlin build flag — resolved in step 3, and it is the crux of the
Group 6 branching question.

### P5 — RepRap firmware / Duet owner
Real but a clear minority in this community — listed as a supported firmware
`[DOC]` but not sold or documented as a first path by V1. Either licence tier.
Justifies a dialect, but has to justify *its own property group* separately
(Group 11).

### P6 — Laser / diode user — **CONFIRMED**
The post has a whole property group for laser (Group 9), and V1 machines are
commonly fitted with diode lasers `[COMMUNITY]`. **The author confirms this persona
exists** `[AUTHOR]` (answer 1.4). Group 9 is therefore justified in kind.

What I still do not have is *detail*: which of power scaling, `M3`/`M4` dynamic
power, enable/disable sequencing, or air assist this user actually needs. So I can
say Group 9 should stay, but I cannot say whether **seven** properties is the right
number. That remains unenumerated rather than unjustified.

> **Refined 2026-08-13** `[AUTHOR]`: the persona has **field history but no current
> test coverage** — *"Yes laser is a persona but not exercised yet in any tests. Was
> used in v3 beta3 by users."*
>
> That is a stronger position than "confirmed": real users ran it on a shipped
> version. But **none of the 24 `[POSTED]` files is a laser job**, so Group 9 carries
> the same shape of debt as Group 6, one scale down — a confirmed user, working code,
> and zero verification on the current line. The v3 history is evidence the feature
> works; it is not evidence that *this* post's laser path still works, because v3 and
> v4 are separated by the firmware-branch rewrite and the whole property-group
> renaming.
>
> **So the honest verdict is: keep, and add one posted laser job to the test set.**
> Not a Beta3 blocker — the persona is a minority and the code is inherited rather
> than new — but it should not be described as verified either.

### P7 — Multi-part / multi-fixture, full licence — **CONFIRMED IN SCOPE**
Someone running one program covering several parts or fixtures at different work
offsets. **The author confirms this persona is in scope, specifically the hobbyist
with a full Fusion licence** `[AUTHOR]` (answer 1.1).

This reverses the provisional finding above it. I found no evidence for this user in
V1's public documentation — that material describes zeroing per job — but absence
from a vendor's beginner documentation is not absence from the user base, and the
author knows his own users. **Groups 4, 5 and 6 therefore serve a real persona.**

What does *not* change: `docs/PReview.md` §3.1 still records that no such job has
ever been posted. A persona being in scope makes the machinery justified; it does
not make it verified. Those are separate, and the second is now the priority.

> **Refined 2026-08-13, in two ways that pull in opposite directions.**
>
> **P7 gets bigger.** The Marlin user joins it. Guard C excluded Marlin from multi-WCS
> work on a premise now shown false — Marlin has nine persistent WCS registers
> `[DOC]` (`05-history.md`) — so this persona spans all three firmwares, not two.
>
> **But P7 owns more of the work than the post assumed.** `[AUTHOR]` The multi-part
> *orchestration* is *"a user problem not a post issue."* So P7 is not someone who
> hands the post a bed full of fixtures and expects it to be managed — P7 is someone
> who **sets their own work offsets, homes their machine, and picks a clearance that
> clears everything**, and needs the post to emit the offsets F360 named and traverse
> in the machine frame. See `04-user-stories.md` for the split.
>
> **Groups 4 and 6 serve this persona. Group 5 does not** — it was built for a machine
> that does not home, and this persona's workflow requires homing.
>
> And the thing P7 needs first is not a feature: **`[AUTHOR]` the F360 job that defines
> them currently fails to post.**

## What this means before any code is read

- The **licence tier** axis is real and load-bearing (P1/P2 vs P3/P4).
- The **firmware dialect** axis is real, and the absence of a stock Marlin post
  makes it the project's reason to exist.
- The **trusted-position** axis is real but is *not* the same as "has endstops",
  and both states are vendor-documented for the same machine.
- The **multi-WCS** axis is the one with no persona behind it yet.
- Machine brand is not an axis. Nothing so far suggests a Shapeoko owner needs
  different output from a LowRider owner on the same firmware — which argues
  against any brand-shaped configurability, if any exists.
