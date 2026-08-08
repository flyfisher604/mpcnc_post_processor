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
| **HB-3** | `Home at Job Start` = `Home` with `Axes Homed and Trusted` = `None` homes nothing and said so only inside the file — `writeMachineHoming()` warned and returned, and `validateJob()` carried six `warning()` calls but none for this one, so Fusion's dialog was silent. The likeliest group-4 mistake: the operator sets *the action* and never reads the declaration above it as something they must change too | Med | `validateJob()` warning on `homesAtJobStart() && !homedXY && !homedZ` — the exact complement of the existing homing-destroys-the-pre-jog test, reusing locals it already computes. **The `Axises` → `Axes` sweep rides in the same commit:** HR-29 renamed the title and left ten stale spellings, five of them in dialog text and one in the emitted warning, so the dialog quoted two names for one control | ✅ fixed |
| **HB-4** | A non-zero `Probe X/Y Offset` traversed to the probe point at the operator's own jogged Z, with no lift and no warning. On the default `First WCS / Part` the mode's own premise is a bit parked a millimetre over the stock, so a 25 mm offset dragged it 25 mm across the work or into a clamp before the probe. The sibling `Use Active WCS X0 Y0, Probe Z0` path prints `Unknown Z for XY move.` for exactly this hazard; this one passed no `zUnknown`, so it said and lifted nothing | Med | `rapidMovementsZ(probeSafeZ())` between the provisional origin write and `partProbe(true)` — meaningful only here, because the `Z0` one line above makes the absolute retract measure from the height the operator chose. **Gated on `probeOffsetIsSet()`**, a new one-line helper `partProbe()` also adopts, so a zero-offset job stays byte-identical. The `zUnknown`-comment alternative was rejected: it describes the hazard instead of removing it | ✅ fixed |
| **HB-5** | **A malformed group-6 `Safe Z` falls back to 15 mm with only a `Debug` trace, where its group-3 twin warns.** Both properties share `parseSafeZExpr()`, which returns `eSafeZ.ERROR` for anything that is not a bare number or `Feed:`/`Retract:`/`Clearance:<n>` — including a leading minus, a unit suffix (`15mm`) or an emptied field. `safeZforSection()` 1119-1122 answers that with an `Important` `>>> WARNING: … format error`; `parseProbeSafeZProperty()` 1214-1221 answers it with a `Debug` comment nobody posts at. The only other trace is `Probe SafeZ = Error = 15.000` in the `Info`-level Resolved Values block. 15 mm is a plausible retract height, so the mistake looks like it worked | Low | Open — raise the probe-side parse failure to `Important` and to a `warning()`, matching the map-side. The two Safe-Z properties should fail the same way, since they document each other as "same syntax" | ⬜ |
| **HB-6** | **`G17` and `G94` are emitted only on the GRBL branch, so RepRap inherits whatever plane and feed mode the last job left.** `Start()` 3794-3803 puts both inside `if (fw == eFirmware.GRBL)`; the Marlin/RepRap branch emits `G90`, `G21`/`G20` and `M84 S0` only. `circular()`'s non-GRBL branch 3966-3968 then writes `G2`/`G3` with `I`/`J` and **no `G17`**. Both codes are live modal state in RRF — `Duet3D/RepRapFirmware` `src/GCodes/GCodes2.cpp` `HandleGcode()` has `case 17:`/`case 18:`/`case 19:` setting `selectedPlane`, and `case 93:`/`case 94:` setting `inverseTimeMode` — so a controller left in `G18` reads every arc's `I`/`J` in the wrong plane, and one left in `G93` reads every `F` as inverse time. Marlin is unaffected: without `CNC_WORKSPACE_PLANES` it has no `G17` to be wrong about and is always XY, and it has no `G93` | Low | Open — emit `G17` (and `G94`) on the non-GRBL branch too. Both are no-ops on a controller already in that mode, so the cost is two lines per Marlin/RepRap file | ⬜ |
| **HB-7** | A group-8 include file that does not exist aborted the post *after* part of the file was written: `loadFile()`'s `error()` fires at step 4 of `writeFirstSection()`, by which point the header block, the property dump, the homing and the `G54` select are already in the stream. The operator got a truncated `.gcode` that looks like it starts a job, and the Stop include failed later still | Low | Pre-flight loop at the head of `validateJob()`'s Guards block, above everything firmware- or frame-dependent, using a new `includeFolder()` that `loadFile()` also adopts so the two cannot disagree about where they looked. The **tool-change pair is checked only when group 7 is on**, since a name in a field their descriptions call ignored must not refuse the job. **The four `coolant…Custom` files are not covered** — same class through the same `loadFile()`, but reaching them needs a coolant-mode match and they belong with the coolant-dialect work in `PReview.md` §6. HR-27's geometry half is still open and wants moving, not duplicating | ✅ fixed |
| **HB-8** | `fOutput` and the word separator were set one way in `onOpen()` and covered by neither branch nor `resetPostState()` — which exists precisely because the post does not rely on a fresh JavaScript context per file. Post with `Enforce Feedrate` on, then a second file with it off, and the second still carried a forced `F` on every move; same for whitespace. Quiet because the output is a superset rather than wrong g-code. `gMotionModal`'s conditional assigns on both branches and so never leaked | Low | Both assignments unconditional, `{ force: false }` being the declaration's own value rather than a guess. `resetPostState()`'s header now records that these two and `gMotionModal` are rebuilt from properties in `onOpen()` rather than reset there, so the next reader does not count them as missed a second time | ✅ fixed |
| **HB-9** | `Comment Level` = `Off` suppressed every `>>> WARNING:` the post writes, because `writeComment()` gates on level and every in-file warning is `Important`. Most have a `validateJob()` sibling and survive there; three do not — the jet-tool / tool-0 `Z0 was NOT established`, `No matching Coolant channel : <mode> requested`, and HB-3's `nothing was homed`. A tool carrying a coolant mode no channel is configured for is the ordinary group-10 case: the post correctly emits no coolant code, and at `Off` it also said nothing about having ignored the request | Low | All **thirteen** `>>> WARNING:` sites now go through `writeWarning()`, which bypasses the level gate — `Off` means less commentary, not fewer warnings. Made structural rather than a string match: `writeComment()`'s emit half became `writeCommentLine()`, shared by both, and the prefix lives in one place so it cannot drift. The row named three warnings and the code had thirteen. The `>>>` lines that are *not* warnings (coolant channel, laser power, dwell, spindle speed) stay level-gated | ✅ fixed |
| **HB-10** | **`Tool Change Probe` (`includeProbeFile`) is a dialog field that does nothing.** Declared at 654-662 with a title and tooltip; nothing in the post calls `loadFile()` with it, so a filename entered here is silently ignored. The tooltip does say `NOT IMPLEMENTED YET`. *Pre-seeded — named in the checkpoint before this pass began, not an independent find; recorded so the fresh register is not missing a known group-8 defect* | Low | Open — wire it into `probeTool()` or delete the property. It belongs to the tool-change branch's ordering work either way | ⬜ |

---

## Test register — 13 rows

Every finding resolves to a row. All rows are **unrun**: they are written to be posted from Fusion
after the fix lands, and each states what must be **present** and what must be **absent** in the
file. Personas are `conventions.md` → *How to run a test*; defaults are GRBL/mm, `Comment Level`
`Info`, unless the Setup delta says otherwise.

**✅ 0 PASS · ❌ 0 FAIL · ⬜ 11 UNRUN · ➖ 2 n/a — 13 rows.**

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
| **HB-9 (A)** | A `>>> WARNING:` reaches the file at `Comment Level` = `Off`, and nothing else does | HP-1 + `Comment Level` = `Off` + `Home at Job Start` = `Home` + `Axes Homed and Trusted` = `None` (HB-3 (A)'s combination) | posted | ⬜ |

### Expects

Where the discriminator needs more than a table cell.

- **HB-2 (A)** — the file's first character is `(`, not `%`, and `%` appears **nowhere** in it
  (`grep -c '%'` = 0). `M30` is still the last g-code block. **(B)** — the first line is the
  `generated-by` header comment and the last is `M30`, proving (A)'s absence is not an empty file.
- **HB-3 (A)** — Fusion's post dialog carries the warning. The file still holds
  `>>> WARNING: "Home at Job Start" is on but "Axes Homed and Trusted" is None`, and **no** `$H`.
  Note the spelling: the same commit corrected ten stale `Axises`, so a file still saying `Axises`
  was posted from a pre-fix build. **(B)** — no dialog warning, and `$H` present.
- **HB-4 (A)** — between `G10 L20 P1 X0 Y0 Z0` and `G0 X25 Y0 F2500` there is an absolute
  `G0 Z<probeSafeZ> F300`, preceded by `( Retract to Safe Z before the offset traverse )`, in that
  order. **(B)** — no `G0 Z…` between the origin write and `G38.2`, no `Retract to Safe Z before the
  offset traverse` comment, and no `X`/`Y` rapid at all (a zero-offset job emits none of the three).
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
- **HB-9 (A)** — the file's **only** `(` line is
  `( >>> WARNING: "Home at Job Start" is on but "Axes Homed and Trusted" is None -- nothing was homed )`.
  Presence and absence in one row, so it needs no sibling: the warning is the presence half, and no
  `*** START begin ***`, no property dump, no `Resolved Values` block and no `Probe SafeZ` line is the
  absence half proving `Comment Level` really was `Off`. Also **no `$H`**, as in HB-3 (A).

---

## Owed

What this register still owes, and why each artifact is worth a post.

- **Every live row above is unrun.** Nothing here is proved by a posted file yet; the findings are
  proved by reading the post, and the firmware claims by firmware source, cited in each row.
- **The geometry guards' half of "a rejected job leaves no file" is still owed.** HB-7's include
  check now refuses before any output, but the multi-axis and orientation guards still fire in
  `onSection()` and still leave a truncated `.gcode` — `HR-27`, unstarted, and the general fix is
  moving them rather than duplicating the check. HB-7 (A) is worth re-posting alongside whatever row
  covers those, from the same build: together they are the claim that *no* rejected job leaves a file.
- **Groups 7, 9 and 11 were not walked.** A hobbyist doing a manual tool change on an MPCNC or
  running a diode laser is an ordinary case, and neither is covered by any row here.
- **The `Comment Level` = `Off` file has never been posted.** HB-9 was found by reading
  `writeComment()`'s gate and is now `HB-9 (A)`, which is that post. Worth running for more than the
  fix: it is the only artifact that would settle whether anything else this review assumed was visible
  actually disappears at that level.
