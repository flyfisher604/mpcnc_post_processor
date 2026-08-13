# Step 6 — What the recent work bought, and what must survive

**35 commits changed the post since the published tag `v4.0_Beta2`** (31 up to
`origin/master`, 4 since). Sorted by what happens to each if the surrounding
design changes.

## Tier 1 — Real bugs, real evidence. These must survive any pruning.

Each fixed output that was wrong, and none of them depends on the multi-part
workflow being in scope.

| Commit | What it fixed | Why it is verified |
|---|---|---|
| `5a6a4e0` | Stopped wrapping GRBL files in a `%` that stock GRBL rejects | Firmware refuses the file outright |
| `b84f602` | `Enforce Feedrate` and the word separator leaked into the *next* post | Cross-post state leak — observable in posted files |
| `b61c005` | A missing include file is refused before any output is written | Silently produced a truncated program |
| `cb1c9f2` | Retract before the offset-probe traverse instead of dragging the bit | A real bad motion across the work |
| `ec5af37` | Refuses to be silent when `Home at Job Start` can home nothing | Emitted a homing intent that did nothing |
| `ae0e013` | Hands a Stop file a known plane; stops the plane modal outliving its file | Modal state escaping an include boundary |
| `eea70d1` | Restored a separator in the Safe-Z warning; resets what an include file moved | Two output defects |
| `1c5fcce` | Lets `>>> WARNING:` through at Comment Level Off | A safety warning was being suppressed by a cosmetic setting |
| `e5db625` | Warns when a Safe Z expression will not parse | Silent fallback on a malformed height |

## Tier 2 — Firmware knowledge. The most valuable thing in the project.

This is what a post processor is *for* — facts that cannot be derived from F360 and
must not be guessed. **Losing these would be the single worst outcome of any
restart.**

| Commit / location | The knowledge |
|---|---|
| `174c4df` | Why `G17` and `G94` stay off the Marlin/RepRap branch — Marlin compiles `G17` only under `CNC_WORKSPACE_PLANES` (shipped commented out) and has no `G93`/`G94` at all; RRF gained them only in 3.5.1 |
| `2b5dfd5` | Stopped a warning recommending Marlin a remedy Marlin refuses |
| `docs/design.md` firmware tables | `G30` is dead on all three firmwares (a plunge on Marlin/RRF, an XY move on GRBL); `G53` is not modal and errors without `G0`/`G1` active; RRF's `G38.2` target frame changed at 3.1.2; no supported firmware has canned drilling cycles; Marlin has never implemented `M2`; GRBL parses `$` only as the line's first character (CR-1) |

`design.md` also records the process lesson, which is worth keeping verbatim:

> *"All four above were answerable from sources already cited, and filing them as
> open cost a design decision (`G30`) that had no business surviving."*

## Tier 3 — Sound fixes to the machinery whose need is unestablished

These are competent fixes. Whether they survive depends entirely on whether story
**S12** (multi-part / multi-fixture) is in scope. **If S12 is dropped, these are
deleted along with the code they repair — that is not lost work, it is work that
stops being needed.**

| Commit | Fix |
|---|---|
| `c319e69` | CR-11 — spoilboard base probe given a relative target and its own reach |
| `fbd1591` | CR-13 — **removed** `Retract Across Parts`, made Guard B unconditional |
| `348e35a` | CR-14 — the fixed-Z predicate answers for the tool that must probe |
| `979297d` | CR-12 — both stored-Z0 part probes get a provisional zero of their own |
| `1eb8141` | PR-8 — asks whether the fixed Z reference was *established*, not whether a base was *named* |
| `556a378` | Says out loud what the unknown-Z traverse depends on, in both channels |

`fbd1591` is worth singling out: it **deleted a control**. The project has already
started pruning this area on its own judgement, which is evidence the instinct
behind this review is sound.

## Tier 4 — Dialog and structural work. Survives as intent even if code moves.

Roughly 17 commits, and this is where the bulk of the tag→`origin/master` effort
went. It is the *opposite* of over-engineering — it is simplification:

- `2e404dd`, `8468b86` — split the property-group string into `groupDefinitions`
  with explicit `order:`, renamed 68 keys to `<groupKey><Name>`
- `9a7e360`, `0df79d9`, `f42d04e`, `36109c2` — PR-5/PR-6/PR-7: collapsed two
  dialog questions per concept into one control, three times, one of which
  **deleted a meaningless state** rather than renaming it
- `64fc9bf`, `9c27f86` — rewrote a dialog title and eighteen property descriptions
  at the altitude an operator reads
- `bf0c2bd` — folded group 3 to one enabling control and one field
- `96ac08a` — group titles now say which groups a single-part job can skip
- `b7d12fb` — trimmed the post's commentary to what the code cannot say itself
- `20392c5`, `8148df4`, `17a20f2`, `18ec9aa` — defaults and operator-facing strings

**These commits reduced the dialog while this review was worrying about its size.**
Any plan that discards them re-inflates a surface the author has already spent
significant effort shrinking.

## Confirming the reset measurement

Verified directly against the tag. Every suspected subsystem is **already present
at `v4.0_Beta2`**:

| Symbol | Occurrences at tag | At HEAD |
|---|---|---|
| `writeWCS` | 17 | 14 |
| `partProbe` | 10 | 10 |
| `probeTool` | 9 | 11 |
| `writeBaseEstablish` | 8 | 7 |
| `wcsDefinitions` | 1 | 1 |
| `toolChange` | 6 | 34 |
| `fixedZEstablishedAtStart` | **0** | 2 |

**The reset question is closed.** A reset to `v4.0_Beta2` would remove none of the
architecture under suspicion — the WCS, part-probe, spoilboard-base and tool-change
machinery all predate the published tag. It would discard Tiers 1, 2 and 4 in full:
nine verified bug fixes, the firmware knowledge, and seventeen commits of dialog
simplification. It would also revert the numbered property-group scheme, which does
not exist at the tag at all.

Pruning HEAD reaches every outcome a reset could, and keeps all of that. **No
further effort should go to the reset option.**

The one measurement that deserves follow-up: `toolChange` went from 6 occurrences
to 34. Occurrence counts include comments and strings, so this is a signal rather
than a measurement — but it is consistent with `07-code-map.md` finding Group 7 to
be both grown and defective.

## Property-by-property verdict on Group 6 — *"do all the options survive?"*

Asked for directly on 2026-08-13, including the **First WCS** and **Subsequent WCS**
controls. Group 6 has ten properties; the two named ones are enums, so the real
question is **fourteen decisions, not ten** — and reading their option lists turned up
the sharpest finding in this round.

### The finding first: four of ten enum options do not work on the default firmware

The post says so itself, in `probeOnStart`'s own description
([MPCNC_v4.0_Beta2.cps:399](MPCNC_v4.0_Beta2.cps#L399)):

> *"**THE TWO JOG MODES DO NOT WORK ON GRBL, the default firmware** -- only RepRap has
> a genuine jog-at-pause, and the post warns and says so in the file when a Jog mode
> is chosen on GRBL."*

`probeOnStart` offers six modes, two of them Jog. `probeOnChange` offers four, two of
them Jog. **So four of the fourteen decisions in this group are options that are
offered, defaulted around, documented at length — and non-functional for most users**,
whose only protection is a warning. That is not a bug; the post is honest about it.
It is the definition of over-engineering: **cost paid in the dialog, in the
description, in the code and in the warning machinery, for a capability two of three
firmwares cannot perform.**

### The verdicts

| # | Property | Verdict | Reasoning |
|---|---|---|---|
| 1 | **`probeOnStart`** — *First WCS / Part* | **KEEP the control, cut 6 modes → 3** | This is S1, the founding story, and the `[POSTED]` files exercise it. But see below |
| 1a | ↳ `Current XY & Probe Z` (default) | **KEEP** | The hand-zeroed hobbyist. 24 of 24 posted files use it |
| 1b | ↳ `Current XYZ` | **KEEP** | No probe plate, or a laser/jet. Cheap and distinct |
| 1c | ↳ `Probe Z` (use stored XY) | **KEEP** | The fixture user. Needed by S12 |
| 1d | ↳ `Skip` (use stored XYZ) | **MERGE into 1c** | Differs only in whether Z is probed — that is one boolean, not a fourth enum member |
| 1e | ↳ `Jog XY & Probe Z` | **DELETE** | Does not work on GRBL or Marlin |
| 1f | ↳ `Jog XYZ` | **DELETE** | Same |
| 2 | **`probeOnChange`** — *Subsequent WCS / Part* | **DELETE the control entirely** | See below — this is the one real casualty |
| 3 | `probePause` | **KEEP** | Attach/detach the probe. Directly observable in the posted files as `M0 (MSG Attach ZProbe)` |
| 4 | `probeOffsetX` | **KEEP** | A probe plate not at the origin is a physical fact only the operator knows |
| 5 | `probeOffsetY` | **KEEP** | Same |
| 6 | `probeG382orG28` | **KEEP** | `G38.2` vs `G28 Z` is a firmware dialect choice — exactly what a post is for |
| 7 | `probeG38Target` | **KEEP** | Verified in output: `G38.2 F30 Z-10` |
| 8 | `probeG38Speed` | **KEEP** | Verified: the `F30` above |
| 9 | `probeSafeZ` | **KEEP** | The retract after probing. `Retract:15` in the posted files |
| 10 | `probeThickness` | **KEEP** | Verified: `G10 L20 P1 Z0.8` |

**Net: 10 properties → 9, and 14 decisions → 9.** Items 3–10 are the Z touch-off
mechanics, they answer to S1, and **every one of them is confirmed by emitted
output**. This is the best-evidenced block in the post and none of it is in question.

### Why `probeOnChange` goes, and why that is not the same as dropping S12

Three independent reasons, any one sufficient:

1. **It is the orchestration, and the author has assigned orchestration to the
   operator.** *"Make it a user problem not a post issue."* Deciding how each
   subsequent part's origin gets re-established, per part, at run time, is precisely
   the orchestration half of the S12 split in `04-user-stories.md`.
2. **Half its options do not work on the default firmware**, and its description
   contains a statement now known to be false — *"Not supported on Marlin at all,
   which has one global origin"*
   ([:416](MPCNC_v4.0_Beta2.cps#L416)). Marlin has nine registers
   (`05-history.md`).
3. **Under the corrected design the question does not arise.** If the traverse is a
   `G53` machine-frame move on a homed machine, and the offsets were set by the
   operator before the job, then arriving at part 2 needs no mode: select `G55`, and
   the registers are already right. **The control exists to solve a problem that
   homing solves.**

What replaces it is at most **one boolean** — *"re-probe Z at each WCS change"* — for
the operator whose parts differ in height. Default off. That is the residue of a
four-option enum with a 1,400-character description.

**S12 still holds.** The multi-part *user* keeps their workflow; what they lose is
being asked four questions the machine can answer for them.

### One thing to fix that is not a deletion

`probeOnStart`'s description is **~1,900 characters in a single string**, and
`probeOnChange`'s is not much shorter. A description that long is not read, which
means the warnings buried in it — including the GRBL one quoted above — are not read
either. **If a mode needs 300 words to be safe, the mode is the problem, not the
prose.** Cutting to three modes is what makes the description short enough to work.

## Where the professional user stands on WCS probing

Also asked on 2026-08-13: *"For a professional user does the post support WCS probe
operations?"*

**No — it refuses them, deliberately, and the refusal should stand.**
`onCyclePoint()` calls `cycleNotSupported()` for any probing cycle
([:2470](MPCNC_v4.0_Beta2.cps#L2470)). The reasoning is in
`03-f360-and-firmware.md` §5b: an F360 WCS probing operation requires the *control*
to compute a midpoint or centre from several probe hits, and **GRBL and Marlin have
no arithmetic at all** — so the operation is unimplementable there, not merely
unimplemented. Only RepRapFirmware could host it, via machine-side meta G-code.

Nothing to retain or delete. The one improvement is the **message**, which currently
uses Autodesk's generic text where it could name the reason and point at the post's
own Z touch-off. One line, Phase 0.

## Pre-tag history — evidence on the firmware-branching question

Read, not proposed as a baseline. At tag `1.0` (2021-01-30) **this project was
three separate posts, one per firmware**: `DIYCNC_Grbl11.cps`,
`DIYCNC_Marlin20.cps`, `DIYCNC_RepRapFW.cps`. They were unified into a single
`MPCNC.cps` by `v1.beta5` (2021-02-15).

So today's firmware branching is the price of that unification, and the question
"is the branching invented?" has a historical answer: **it started as three
genuinely separate implementations.** Combined with step 3's finding — that all
three firmwares support G54–G59, and the real differences are narrow (`G10 L2` vs
`G92`, `$H` vs per-axis `G28`, `G17`/`G94` availability) — the conclusion is that
the branching is **justified in kind but should be narrower in extent**: a dialect
table, not scattered conditionals.
