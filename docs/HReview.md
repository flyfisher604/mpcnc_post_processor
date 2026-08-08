Hobbyist review — findings and tests
====

## Scope

A blind, from-scratch walk of `MPCNC_v4.0_Beta2.cps` from the **hobby operator's** point of view:
one part, one Fusion Setup, one tool, several operations, zeroed by hand or off a touch plate, on
an MPCNC / LowRider running GRBL, Marlin or RepRap.

**Controls covered — groups 1, 2, 3, 4, 5, 6, 8, 10** (55 of the 69 dialog properties). Each was
read for its default, then walked through every code path it reaches from every Fusion entry point
that can call it, and the emitted g-code checked against the dialect the **CNC Firmware** answer
names and against what `README.md`, `guide-hobbyist.md` and `property-reference.md` promise.

**Deliberately excluded:** group 7 (tool changes), group 9 (laser) and group 11 (Duet), and every
multi-WCS / multi-fixture / Manual NC path — those belong to the professional register. Findings
that a hobbyist can only reach through one of those are not recorded here.

**Method note.** This pass did not read the previous `HR-`/`CR-` register, so a finding below may
restate one already closed there; ids are `HB-` precisely so they cannot collide with ids cited in
commit messages. Two items were pre-seeded from the checkpoint before the pass began and are
labelled as such rather than claimed as independent finds. Firmware behaviour is settled from
firmware source, cited in the row — **no controller was available**, so no row is proved by running
one.

---

## Findings — HB-1 … HB-10 — 10 findings

| ID | Finding | Sev | Resolution | Status |
|---|---|---|---|---|
| **HB-1** | **Marlin `M0` is conditionally compiled, so a build without a panel would skip every operator stop.** `askUser()` (4010-4013) emits `M0 <text>` on Marlin. Marlin gates `M0` on `HAS_RESUME_CONTINUE` — `Marlin/src/gcode/gcode.cpp` 2.1.x: `#if HAS_RESUME_CONTINUE` / `case 0: case 1: M0_M1(); break;` / `#endif` — which `Marlin/src/inc/Conditionals_adv.h` defines as `#if ANY(EXTENSIBLE_UI, IS_NEWPANEL, EMERGENCY_PARSER, HAS_ADC_BUTTONS, HAS_DWIN_E3V2)`. On a build satisfying none of those, `M0` reaches `default: parser.unknown_command_warning(); break;` and the job runs on, losing the probe-attach stop, the *Turn ON RPM* stop and the spindle-off stop at once | — | **Closed by design — not a defect on the machines this post targets.** Every Marlin build in the target audience has a panel, so `IS_NEWPANEL` is satisfied and `M0` is always compiled in. The post is therefore right to emit `M0` unconditionally on Marlin, and no warning is wanted: it would fire on every Marlin job to describe a build that does not exist here. Recorded so the `gcode.cpp` gate is not re-derived and re-raised by a later pass | ➖ |
| **HB-2** | Every GRBL file opened and closed with a `%` line stock Grbl 1.1 rejects — `error:1`, or `error:9` from the opening one while still in Alarm before `$H`. Masked only because UGS / bCNC / Candle strip `%` before streaming | Med | **Dropped from both branches**, not gated behind a property: the wrapper is correct for no supported firmware, and a dialog field to disable something nothing wants is worse than its absence. `onOpen()` carries the `grbl/protocol.c` citation, because an absence cannot explain itself and the character is familiar from Fanuc/LinuxCNC posts | ✅ fixed |
| **HB-3** | **`Home at Job Start` = `Home` with `Axes Homed and Trusted` = `None` homes nothing and says so only inside the file.** `writeMachineHoming()` 3168-3172 warns at `Important` level and returns. `validateJob()` carries six `warning()` calls for advisory cases but **none for this one**, so Fusion's post dialog is silent — and at `Comment Level` = `Off` the file is silent too, leaving no trace anywhere. This is the likeliest group-4 mistake a hobbyist makes: the operator wants homing, reads *the action*, sets it, and never reads the declaration above it as something they must also change. The job then starts from an unhomed machine believing it homed | Med | Open — add a `warning()` in `validateJob()` mirroring the in-file text. `machineHomesXY()`/`machineHomesZ()`/`homesAtJobStart()` already give it the exact predicate | ⬜ |
| **HB-4** | **A non-zero `Probe X/Y Offset` traverses to the probe point at the operator's own jogged Z, with no lift and no warning.** On the default `First WCS / Part` = `Set X0 Y0 to Current Pos, Probe Z0`, `writeWcsOnStart()` 3523-3527 writes the provisional `G10 L20 P1 X0 Y0 Z0` and calls `partProbe(true)`; with an offset set, `partProbe()` 3408-3427 emits `G0 X<ox> Y<oy> F2500` **at whatever Z the operator left the tool at**. The sibling path (`Use Active WCS X0 Y0, Probe Z0`, which passes `zUnknown = true`) prints `Ensuring that Z is safe. Unknown Z for XY move.` for exactly this hazard; this path passes no `zUnknown`, so it prints nothing and lifts nothing. The offsets are a documented hobbyist feature — `guide-hobbyist.md` → *Probing away from the corner* recommends them for an origin in fresh air — and the mode's own premise is that the operator has just jogged the bit down to the corner. Failure: offset 25 mm, tool parked a millimetre over the stock, and the bit is dragged 25 mm across the work or into a clamp before the probe | Med | Open — the provisional `Z0` is written *before* the offset move, so an absolute retract is meaningful here: emit `rapidMovementsZ(probeSafeZ())` between 3524 and 3527. Cheaper alternative is to pass `zUnknown` so at least the comment appears | ⬜ |
| **HB-5** | **A malformed group-6 `Safe Z` falls back to 15 mm with only a `Debug` trace, where its group-3 twin warns.** Both properties share `parseSafeZExpr()`, which returns `eSafeZ.ERROR` for anything that is not a bare number or `Feed:`/`Retract:`/`Clearance:<n>` — including a leading minus, a unit suffix (`15mm`) or an emptied field. `safeZforSection()` 1119-1122 answers that with an `Important` `>>> WARNING: … format error`; `parseProbeSafeZProperty()` 1214-1221 answers it with a `Debug` comment nobody posts at. The only other trace is `Probe SafeZ = Error = 15.000` in the `Info`-level Resolved Values block. 15 mm is a plausible retract height, so the mistake looks like it worked | Low | Open — raise the probe-side parse failure to `Important` and to a `warning()`, matching the map-side. The two Safe-Z properties should fail the same way, since they document each other as "same syntax" | ⬜ |
| **HB-6** | **`G17` and `G94` are emitted only on the GRBL branch, so RepRap inherits whatever plane and feed mode the last job left.** `Start()` 3794-3803 puts both inside `if (fw == eFirmware.GRBL)`; the Marlin/RepRap branch emits `G90`, `G21`/`G20` and `M84 S0` only. `circular()`'s non-GRBL branch 3966-3968 then writes `G2`/`G3` with `I`/`J` and **no `G17`**. Both codes are live modal state in RRF — `Duet3D/RepRapFirmware` `src/GCodes/GCodes2.cpp` `HandleGcode()` has `case 17:`/`case 18:`/`case 19:` setting `selectedPlane`, and `case 93:`/`case 94:` setting `inverseTimeMode` — so a controller left in `G18` reads every arc's `I`/`J` in the wrong plane, and one left in `G93` reads every `F` as inverse time. Marlin is unaffected: without `CNC_WORKSPACE_PLANES` it has no `G17` to be wrong about and is always XY, and it has no `G93` | Low | Open — emit `G17` (and `G94`) on the non-GRBL branch too. Both are no-ops on a controller already in that mode, so the cost is two lines per Marlin/RepRap file | ⬜ |
| **HB-7** | **A group-8 include file that does not exist aborts the post after part of the file is already written.** `loadFile()` 3774-3777 calls `error()` when `FileSystem.isFile()` fails. The Start include is loaded at step 4 of `writeFirstSection()`, by which point the header block, the property dump, the homing and the `G54` select are all in the stream — so a mistyped filename leaves a **truncated `.gcode`** rather than a clean refusal, the same class as the geometry guards that fire in `onSection()`. The Stop include fails later still. The operator sees a file that looks like it starts a job | Low | Open — check the four include filenames in `validateJob()` with `FileSystem.isFile(FileSystem.getFolderPath(getOutputPath()) + PATH_SEPARATOR + name)` so a typo refuses before any output. `getOutputPath()` is available in `onOpen()` | ⬜ |
| **HB-8** | **`fOutput` and the word separator are set one way in `onOpen()` and are not covered by `resetPostState()`.** 1854-1856 rebuilds `fOutput` as `{force:true}` when `Enforce Feedrate` is on but has **no else branch** restoring `{force:false}`; 1862-1864 calls `setWordSeparator("")` when `Include Whitespace` is off and never restores `" "`. `resetPostState()` 1810-1830 exists precisely because the post does not want to rely on a fresh JavaScript context per output file, and it resets fourteen globals — these two were missed. Consequence within one Fusion session: post a file with `Enforce Feedrate` on, then a second with it off, and the second still carries a forced `F` on every move; same for whitespace. Output is a superset rather than wrong g-code, which is why it is quiet. Contrast `gMotionModal`, whose `onOpen()` conditional assigns on **both** branches and so does not leak | Low | Open — make both unconditional: `fOutput = createVariable({force: getProperty(properties.feedsEnforceFeedrate)}, fFormat)` and `setWordSeparator(getProperty(properties.jobSeparateWordsWithSpace) ? " " : "")` | ⬜ |
| **HB-9** | **`Comment Level` = `Off` suppresses every `>>> WARNING:` the post writes, including those with no Fusion-dialog twin.** `writeComment()` 3548-3559 gates on level, and every in-file warning is `Important`. Several have a `validateJob()` sibling and survive; these do not: the jet-tool / tool-0 `Z0 was NOT established` warning (3540), `No matching Coolant channel : <mode> requested` (1400), and HB-3's `nothing was homed`. A tool carrying a Fusion coolant mode no channel is configured for is the ordinary group-10 case — the post correctly emits no coolant code, but at `Off` it also says nothing about having ignored the request | Low | Open — either give the warnings without a dialog twin a `warning()` call, or emit `>>> WARNING:` lines unconditionally regardless of level. The second is the smaller change and matches what an operator expects `Off` to mean (less commentary, not fewer warnings) | ⬜ |
| **HB-10** | **`Tool Change Probe` (`includeProbeFile`) is a dialog field that does nothing.** Declared at 654-662 with a title and tooltip; nothing in the post calls `loadFile()` with it, so a filename entered here is silently ignored. The tooltip does say `NOT IMPLEMENTED YET`. *Pre-seeded — named in the checkpoint before this pass began, not an independent find; recorded so the fresh register is not missing a known group-8 defect* | Low | Open — wire it into `probeTool()` or delete the property. It belongs to the tool-change branch's ordering work either way | ⬜ |

---

## Test register — 12 rows

Every finding resolves to a row. All rows are **unrun**: they are written to be posted from Fusion
after the fix lands, and each states what must be **present** and what must be **absent** in the
file. Personas are `conventions.md` → *How to run a test*; defaults are GRBL/mm, `Comment Level`
`Info`, unless the Setup delta says otherwise.

**✅ 0 PASS · ❌ 0 FAIL · ⬜ 10 UNRUN · ➖ 2 n/a — 12 rows.**

| Test | Proves | Setup | Method | State |
|---|---|---|---|---|
| **HB-1 (A)** | Retired with HB-1 — no warning is being added, so there is nothing to post | — | — | ➖ |
| **HB-1 (B)** | Retired with HB-1 | — | — | ➖ |
| **HB-2 (A)** | No GRBL file carries a `%` line | HP-1, unchanged defaults | posted | ⬜ |
| **HB-2 (B)** | Presence sibling for (A): the file's own first and last lines are intact, so (A) is not passing on an empty or truncated file | HP-1, unchanged defaults — same post as (A) | posted | ⬜ |
| **HB-3 (A)** | The unsatisfiable group-4 combination is refused at the dialog, not only in the file | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` left at `None` | posted | ⬜ |
| **HB-3 (B)** | The warning does not fire on the legitimate configuration | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` = `XY Only` | posted | ⬜ |
| **HB-4 (A)** | The offset probe traverse happens at a known height | HP-1 + `Probe X Offset` = `25` | posted | ⬜ |
| **HB-4 (B)** | Absence sibling: a zero-offset job emits no extra lift, so (A)'s new block is attributable to the offset | HP-1, unchanged defaults | posted | ⬜ |
| **HB-5 (A)** | A malformed probe `Safe Z` is loud | HP-1 + group-6 `Safe Z` = `15mm` | posted | ⬜ |
| **HB-6 (A)** | RepRap files set the plane and the feed mode | HP-1 on RepRap, `Use Arcs` on, a Setup containing at least one XY fillet | posted | ⬜ |
| **HB-7 (A)** | A mistyped include filename refuses before any output | HP-1 + `Start GCode File` = `no_such_file.g` | posted | ⬜ |
| **HB-8 (A)** | The two one-way settings survive a second post in the same Fusion session | HP-1 posted twice without restarting Fusion: first with `Enforce Feedrate` on and `Include Whitespace` off, then with `Enforce Feedrate` off and `Include Whitespace` on | posted | ⬜ |

### Expects

Where the discriminator needs more than a table cell.

- **HB-2 (A)** — the file's first character is `(`, not `%`, and `%` appears **nowhere** in it
  (`grep -c '%'` = 0). `M30` is still the last g-code block. **(B)** — the first line is the
  `generated-by` header comment and the last is `M30`, proving (A)'s absence is not an empty file.
- **HB-3 (A)** — Fusion's post dialog carries the warning. The file still holds
  `>>> WARNING: "Home at Job Start" is on but "Axises Homed and Trusted" is None`, and **no** `$H`.
  **(B)** — no dialog warning, and `$H` present.
- **HB-4 (A)** — between `G10 L20 P1 X0 Y0 Z0` and `G0 X25 Y0 F2500` there is an absolute
  `G0 Z<probeSafeZ> F300`, in that order. **(B)** — no `G0 Z…` between the origin write and
  `G38.2`, and no `X`/`Y` rapid at all (a zero-offset job emits neither).
- **HB-5 (A)** — an `Important` `>>> WARNING:` naming the `Safe Z` title and the 15 mm fallback,
  and the Resolved Values line reads `Probe SafeZ = Error = 15.000 …`. A dialog `warning()` too if
  that route is taken.
- **HB-6 (A)** — `G17` appears in the `*** START begin ***` block, before the first `G2`/`G3`;
  `G94` likewise. Neither appears more than once (both are modal).
- **HB-7 (A)** — Fusion reports the error and **no `.gcode` file is written at all**. This is the
  discriminator: today's behaviour is a file containing the header, the property dump and `G54`.
- **HB-8 (A)** — the second file has **no** `F` word on moves whose feed did not change, and
  spaces between words. Read the property dump in each file first to confirm the dialog state
  actually differed — the row is worthless if the second post reused the first's settings.

---

## Owed

What this register still owes, and why each artifact is worth a post.

- **Every live row above is unrun.** Nothing here is proved by a posted file yet; the findings are
  proved by reading the post, and the firmware claims by firmware source, cited in each row.
- **Two guard-placement rows are missing on purpose.** HB-7 is one instance of "an `error()` after
  output has begun leaves a truncated file"; the geometry guards are another, and the general fix
  is one piece of work rather than two. When it is scheduled, HB-7 (A) should be re-posted
  alongside whatever row covers the geometry guards, from the same build.
- **Groups 7, 9 and 11 were not walked.** A hobbyist doing a manual tool change on an MPCNC or
  running a diode laser is an ordinary case, and neither is covered by any row here.
- **The `Comment Level` = `Off` file has never been posted.** HB-9 was found by reading
  `writeComment()`'s gate; a posted `Off` file would also settle whether anything else the review
  assumed was visible actually disappears at that level.
