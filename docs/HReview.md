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

## Findings — HB-1 … HB-12 — 12 findings

| ID | Finding | Sev | Resolution | Status |
|---|---|---|---|---|
| **HB-1** | **Marlin `M0` is conditionally compiled, so a build without a panel would skip every operator stop.** `askUser()` (4010-4013) emits `M0 <text>` on Marlin. Marlin gates `M0` on `HAS_RESUME_CONTINUE` — `Marlin/src/gcode/gcode.cpp` 2.1.x: `#if HAS_RESUME_CONTINUE` / `case 0: case 1: M0_M1(); break;` / `#endif` — which `Marlin/src/inc/Conditionals_adv.h` defines as `#if ANY(EXTENSIBLE_UI, IS_NEWPANEL, EMERGENCY_PARSER, HAS_ADC_BUTTONS, HAS_DWIN_E3V2)`. On a build satisfying none of those, `M0` reaches `default: parser.unknown_command_warning(); break;` and the job runs on, losing the probe-attach stop, the *Turn ON RPM* stop and the spindle-off stop at once | — | **Closed by design — not a defect on the machines this post targets.** Every Marlin build in the target audience has a panel, so `IS_NEWPANEL` is satisfied and `M0` is always compiled in. The post is therefore right to emit `M0` unconditionally on Marlin, and no warning is wanted: it would fire on every Marlin job to describe a build that does not exist here. Recorded so the `gcode.cpp` gate is not re-derived and re-raised by a later pass | ➖ |
| **HB-2** | Every GRBL file opened and closed with a `%` line stock Grbl 1.1 rejects — `error:1`, or `error:9` from the opening one while still in Alarm before `$H`. Masked only because UGS / bCNC / Candle strip `%` before streaming | Med | **Dropped from both branches**, not gated behind a property: the wrapper is correct for no supported firmware, and a dialog field to disable something nothing wants is worse than its absence. `onOpen()` carries the `grbl/protocol.c` citation, because an absence cannot explain itself and the character is familiar from Fanuc/LinuxCNC posts | ✅ fixed |
| **HB-3** | `Home at Job Start` = `Home` with `Axes Homed and Trusted` = `None` homes nothing and said so only inside the file — `writeMachineHoming()` warned and returned, and `validateJob()` carried six `warning()` calls but none for this one, so Fusion's dialog was silent. The likeliest group-4 mistake: the operator sets *the action* and never reads the declaration above it as something they must change too | Med | `validateJob()` warning on `homesAtJobStart() && !homedXY && !homedZ` — the exact complement of the existing homing-destroys-the-pre-jog test, reusing locals it already computes. **The `Axises` → `Axes` sweep rides in the same commit:** HR-29 renamed the title and left ten stale spellings, five of them in dialog text and one in the emitted warning, so the dialog quoted two names for one control | ✅ fixed |
| **HB-4** | A non-zero `Probe X/Y Offset` traversed to the probe point at the operator's own jogged Z, with no lift and no warning. On the default `First WCS / Part` the mode's own premise is a bit parked a millimetre over the stock, so a 25 mm offset dragged it 25 mm across the work or into a clamp before the probe. The sibling `Use Active WCS X0 Y0, Probe Z0` path prints `Unknown Z for XY move.` for exactly this hazard; this one passed no `zUnknown`, so it said and lifted nothing | Med | `rapidMovementsZ(probeSafeZ())` between the provisional origin write and `partProbe(true)` — meaningful only here, because the `Z0` one line above makes the absolute retract measure from the height the operator chose. **Gated on `probeOffsetIsSet()`**, a new one-line helper `partProbe()` also adopts, so a zero-offset job stays byte-identical. The `zUnknown`-comment alternative was rejected: it describes the hazard instead of removing it | ✅ fixed |
| **HB-5** | **A malformed group-6 `Safe Z` falls back to 15 mm with only a `Debug` trace, where its group-3 twin warns.** Both properties share `parseSafeZExpr()`, which returns `eSafeZ.ERROR` for anything that is not a bare number or `Feed:`/`Retract:`/`Clearance:<n>` — including a leading minus, a unit suffix (`15mm`) or an emptied field. `safeZforSection()` 1119-1122 answers that with an `Important` `>>> WARNING: … format error`; `parseProbeSafeZProperty()` 1214-1221 answers it with a `Debug` comment nobody posts at. The only other trace is `Probe SafeZ = Error = 15.000` in the `Info`-level Resolved Values block. 15 mm is a plausible retract height, so the mistake looks like it worked | Low | `parseProbeSafeZProperty()` now answers `eSafeZ.ERROR` with a `writeWarning()` naming the field, its group and the fallback — the map-side's wording, so neither can drift. **The `validateJob()` half covers BOTH properties, not just the probe one:** a dialog warning on the probe side alone would have moved the asymmetry rather than removed it, and the row's own argument is that two properties documenting each other as "same syntax" must fail the same way. Neither had ever reached Fusion's dialog. `parseSafeZExpr()` is pure, so parsing a second time there cannot disagree with `onOpen()`. A job whose Safe-Z fields parse stays byte-identical | ✅ fixed |
| **HB-6** | **`G17` and `G94` are emitted only on the GRBL branch, so RepRap inherits whatever plane and feed mode the last job left.** `Start()` 3892-3900 puts both inside `if (fw == eFirmware.GRBL)`; the Marlin/RepRap branch emits `G90`, `G21`/`G20` and `M84 S0` only. `circular()`'s non-GRBL branch 4060-4069 then writes `G2`/`G3` with `I`/`J` and **no `G17`**. Both codes are live modal state in RRF — `Duet3D/RepRapFirmware` `src/GCodes/GCodes2.cpp` `HandleGcode()` has `case 17:`/`case 18:`/`case 19:` setting `selectedPlane`, and `case 93:`/`case 94:` setting `inverseTimeMode`, per input channel, copied to every channel by `CheckFinishedRunningConfigFile()` and not reset at job start — so a controller left in `G18` reads every arc's `I`/`J` in the wrong plane, and one left in `G93` reads every `F` as inverse time | — | **Closed by design — the proposed fix was worse than the defect.** That fix was "emit both on the non-GRBL branch, they are no-ops on a controller already in that mode". **They are not codes the other two firmwares have.** `G94` is absent from Marlin in *every* configuration (`gcode.h` 2.1.x lists no `G93`/`G94`) and absent from RRF until **3.5.1**, which added both "experimentally" — before that `case 93:`/`case 94:` are not in `HandleGcode()`'s switch at all and it falls to `default:`, an unsupported command. `G17` compiles on Marlin only under `CNC_WORKSPACE_PLANES`, shipped commented out in `Configuration_adv.h`; otherwise it reaches `default: parser.unknown_command_warning()`. So the "two lines" cost an `Unknown command` echo on every Marlin job and an unsupported-command error on every RRF below 3.5.1. Marlin silences that class where it wants to — `case 21: NOOP; break; // No error on unknown G21` — and chose not to here. **And the RepRap-only `G17` that would be safe is not reachable from this post:** `circular()`'s non-GRBL branch linearizes every non-XY arc, so nothing the post emits can leave a controller in `G18`/`G19`, and `G94` became redundant at RRF **3.6.3**, which fixed issue 1129, "inverse time mode was not reset when starting a job". A plane set by something outside the post is a group-8 Start file's job to correct. Recorded so the GRBL-only guard is not re-derived and re-raised; the settlement is in `design.md` → *Firmware capabilities* | ➖ |
| **HB-7** | A group-8 include file that does not exist aborted the post *after* part of the file was written: `loadFile()`'s `error()` fires at step 4 of `writeFirstSection()`, by which point the header block, the property dump, the homing and the `G54` select are already in the stream. The operator got a truncated `.gcode` that looks like it starts a job, and the Stop include failed later still | Low | Pre-flight loop at the head of `validateJob()`'s Guards block, above everything firmware- or frame-dependent, using a new `includeFolder()` that `loadFile()` also adopts so the two cannot disagree about where they looked. The **tool-change pair is checked only when group 7 is on**, since a name in a field their descriptions call ignored must not refuse the job. **The four `coolant…Custom` files are not covered** — same class through the same `loadFile()`, but reaching them needs a coolant-mode match and they belong with the coolant-dialect work in `PReview.md` §6. HR-27's geometry half is still open and wants moving, not duplicating | ✅ fixed |
| **HB-8** | `fOutput` and the word separator were set one way in `onOpen()` and covered by neither branch nor `resetPostState()` — which exists precisely because the post does not rely on a fresh JavaScript context per file. Post with `Enforce Feedrate` on, then a second file with it off, and the second still carried a forced `F` on every move; same for whitespace. Quiet because the output is a superset rather than wrong g-code. `gMotionModal`'s conditional assigns on both branches and so never leaked | Low | Both assignments unconditional, `{ force: false }` being the declaration's own value rather than a guess. `resetPostState()`'s header now records that these two and `gMotionModal` are rebuilt from properties in `onOpen()` rather than reset there, so the next reader does not count them as missed a second time | ✅ fixed |
| **HB-9** | `Comment Level` = `Off` suppressed every `>>> WARNING:` the post writes, because `writeComment()` gates on level and every in-file warning is `Important`. Most have a `validateJob()` sibling and survive there; three do not — the jet-tool / tool-0 `Z0 was NOT established`, `No matching Coolant channel : <mode> requested`, and HB-3's `nothing was homed`. A tool carrying a coolant mode no channel is configured for is the ordinary group-10 case: the post correctly emits no coolant code, and at `Off` it also said nothing about having ignored the request | Low | All **thirteen** `>>> WARNING:` sites now go through `writeWarning()`, which bypasses the level gate — `Off` means less commentary, not fewer warnings. Made structural rather than a string match: `writeComment()`'s emit half became `writeCommentLine()`, shared by both, and the prefix lives in one place so it cannot drift. The row named three warnings and the code had thirteen. The `>>>` lines that are *not* warnings (coolant channel, laser power, dwell, spindle speed) stay level-gated | ✅ fixed |
| **HB-10** | **`Tool Change Probe` (`includeProbeFile`) is a dialog field that does nothing.** Declared at 654-662 with a title and tooltip; nothing in the post calls `loadFile()` with it, so a filename entered here is silently ignored. The tooltip does say `NOT IMPLEMENTED YET`. *Pre-seeded — named in the checkpoint before this pass began, not an independent find; recorded so the fresh register is not missing a known group-8 defect* | Low | **Deferred to the professional review** (2026-08-08) — open, but not hobbyist work. Wiring it means deciding *when* in a tool change the probe file is loaded, which is `PReview.md` §2's ordering design, and deleting it is a dialog decision for the pass that owns group 7; either answer taken here would be taken blind. So it lands with the Tool Change branch, alongside `HR-21` / `CR-15`, which are the same property. Kept in this register rather than moved, because `PReview.md` is absent from this branch's working tree and a row split across two files is how the seven professional ids went stale | ⬜ |
| **HB-11** | **The two blank separator comments disagree by one character.** `onSectionEnd()` 2671 writes `writeComment(eComment.Important, "")` where its sibling at the end of `Start()` 3345 writes `writeComment(eComment.Important, " ")`, so a GRBL file carries `( )` after the START block and `()` after every section — `HB-2 (A).gcode` 141 vs 196. **Nothing operational turns on it**: both are well-formed empty comments in every dialect the post emits, and because both go through `writeComment()` both are dialect-switched, so neither can reach Marlin/RepRap as a stray `(`. Recorded only because a one-character difference between two adjacent call sites reads as significant to the next person diffing two files | Low | **Open.** Pass `" "` at 2671. Not fixed here: the read that found it was scoped to the register, and this is the tidy-up class — it belongs with `HR-19`'s doubled space. Filed as a finding rather than as a note on `HB-2 (A)` so it does not go stale inside a row about the `%` wrapper | ⬜ |
| **HB-12** | **A job whose last arc was a Z lead-out ends with the plane left at `G18`, and the post never restores `G17`.** In `HB-2 (A).gcode` the last plane-setting code is `G18 G2 X182.797 Z-0.083 K4.997` (192); the retract, the end park and `M30` all follow with no `G17`. `Start()` emits `G17` once, at job start, and `circular()` emits it only when an arc needs it. Beyond `M30` this is contained — grbl 1.1 `grbl/gcode.c`, `gc_execute_line()`'s `PROGRAM_FLOW_COMPLETED` branch, resets `gc_state.modal.plane_select = PLANE_SELECT_XY` ("*only a subset of g-codes reset to certain defaults, according to LinuxCNC's program end descriptions*") — and unreachable on the other two firmwares, whose `circular()` branch linearizes every non-XY arc (HB-6). **But the window between the last lead-out and `M30` is exactly where a group-8 Stop file is injected**, so an operator footer containing `G2`/`G3 X… Y… I… J…` runs in the ZX plane: the silent wrong-plane arc HB-6 was written about, this time caused by the post rather than by a stale controller. **Open question, same boundary:** that `PROGRAM_FLOW_COMPLETED` branch also resets `modal.motion` to `MOTION_MODE_LINEAR`, so after any `M30` the controller is in **`G1`**, and the first motion of the first section carries no G-word (`Z15.24 F300`, 153) — it is a rapid here only because the default `First WCS / Part` mode emitted `G0 Z5.08` at 138 first. Whether every answer to that property emits a motion word before the first section is unread | Low | **Open.** `gPlaneModal.format(17)` before the Stop phase, on the GRBL branch only — not for HB-6's Marlin reason but because the non-GRBL branch cannot leave the plane off XY, so the line would buy nothing there and Marlin lacks `G17` without `CNC_WORKSPACE_PLANES` anyway. Settle the open question in the same pass; if any `First WCS / Part` answer emits no motion, the same fix wants a `gMotionModal.format(0)` on the first section's retract | ⬜ |

---

## Test register — 17 rows

Every finding resolves to a row. **One artifact exists so far — `HB-2 (A).gcode`, 2026-08-08 —
closing the two rows it was posted for; every other live row is unrun.** Each is written to be
posted from Fusion after the fix lands, and states what must be **present** and what must be **absent** in the
file. Personas are `conventions.md` → *How to run a test*; defaults are GRBL/mm, `Comment Level`
`Info`, unless the Setup delta says otherwise.

**✅ 2 PASS · ❌ 0 FAIL · ⬜ 12 UNRUN · ➖ 3 n/a — 17 rows.**

| Test | Proves | Setup | Method | State |
|---|---|---|---|---|
| **HB-1 (A)** | Retired with HB-1 — no warning is being added, so there is nothing to post | — | — | ➖ |
| **HB-1 (B)** | Retired with HB-1 | — | — | ➖ |
| **HB-2 (A)** | No GRBL file carries a `%` line | HP-1, unchanged defaults | posted | ✅ |
| **HB-2 (B)** | Presence sibling for (A): the file's own first and last lines are intact, so (A) is not passing on an empty or truncated file | HP-1, unchanged defaults — same post as (A) | posted | ✅ |
| **HB-3 (A)** | The unsatisfiable group-4 combination is refused at the dialog, not only in the file | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` left at `None` | posted | ⬜ |
| **HB-3 (B)** | The warning does not fire on the legitimate configuration | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` = `XY Only` | posted | ⬜ |
| **HB-4 (A)** | The offset probe traverse happens at a known height | HP-1 + `Probe X Offset` = `25` | posted | ⬜ |
| **HB-4 (B)** | Absence sibling: a zero-offset job emits no extra lift, so (A)'s new block is attributable to the offset | HP-1, unchanged defaults | posted | ⬜ |
| **HB-5 (A)** | A malformed probe `Safe Z` is loud in the file and at the dialog | HP-1 + group-6 `Safe Z` = `15mm` | posted | ⬜ |
| **HB-5 (B)** | The dialog half covers the map-side field too, and it alone — the in-file warning is the probe side's | HP-1 + group-3 `Map: Safe Z to Rapid` = `15mm` (`Map: G1s -> G0 Rapids` left **off**, its default) | posted | ⬜ |
| **HB-5 (C)** | Absence sibling for (A) and (B): a job whose Safe-Z fields parse says nothing about either, so the warnings are attributable to the malformed value | HP-1, unchanged defaults (both fields `Retract:15`) | posted | ⬜ |
| **HB-6 (A)** | Retired with HB-6 — no code change, so there is nothing to post | — | — | ➖ |
| **HB-7 (A)** | A mistyped include filename refuses before any output | HP-1 + `Start GCode File` = `no_such_file.g` | posted | ⬜ |
| **HB-8 (A)** | The two one-way settings survive a second post in the same Fusion session | HP-1 posted twice without restarting Fusion: first with `Enforce Feedrate` on and `Include Whitespace` off, then with `Enforce Feedrate` off and `Include Whitespace` on | posted | ⬜ |
| **HB-9 (A)** | A `>>> WARNING:` reaches the file at `Comment Level` = `Off`, and nothing else does | HP-1 + `Comment Level` = `Off` + `Home at Job Start` = `Home` + `Axes Homed and Trusted` = `None` (HB-3 (A)'s combination) | posted | ⬜ |
| **HB-11 (A)** | Both blank separators read the same | HP-1, unchanged defaults — re-post of `HB-2 (A)`'s job after the fix | posted | ⬜ |
| **HB-12 (A)** | A Stop file's XY arcs are not read in the plane the last lead-out left | HP-1 + `Stop GCode File` = a footer whose only motion is one `G2 X… Y… I… J…`, on a job whose final operation has a **Z lead-out** (`HB-2 (A)`'s job qualifies — its last arc is `G18 G2`) | posted | ⬜ |

### Expects

Where the discriminator needs more than a table cell.

- **HB-2 (A)** — the file's first character is `(`, not `%`, and `%` appears **nowhere** in it
  (`grep -c '%'` = 0). `M30` is still the last g-code block. **(B)** — the first line is the
  `generated-by` header comment and `M30` is the last **g-code block**, proving (A)'s absence is not
  an empty file. *Corrected 2026-08-08: this read "and the last is `M30`". At `Comment Level` =
  `Info` the last **line** is `( *** STOP end ***)`, `writeStop()`'s own trailer, which always
  follows `M30`. The block is the criterion, never the line.*
  **PASS — both halves, `HB-2 (A).gcode`, 2026-08-08, one post.** `grep -c '%'` = 0; line 1 is
  `(Fusion CAM 2704.1.36)`; the last three lines are `X0 Y0 F2500` / `M30` / `( *** STOP end ***)`.
  The property dump confirms HP-1 at unchanged defaults — `Grbl`, `Info`, `Scale Feedrate` on,
  `Enforce Feedrate` on and `Probe Pause` = `Before & After` both being the declared defaults
  (235-241, 461-463), both Safe-Z fields `Retract:15`, both coolant channels `Off`, group 4 `None`
  / `Off` / `Work`, every group-8 field empty. **The absence is self-dating**, which is why (A) needs
  no freshness token: every GRBL file before `5a6a4e0` opened and closed with `%`, so no build
  lacking the fix could have produced this one, and per the checkpoint no commit since it changes
  what a factory-default GRBL job emits. That last clause is also why the two absence rows below
  cannot borrow this artifact.
- **HB-3 (A)** — Fusion's post dialog carries the warning. The file still holds
  `>>> WARNING: "Home at Job Start" is on but "Axes Homed and Trusted" is None`, and **no** `$H`.
  Note the spelling: the same commit corrected ten stale `Axises`, so a file still saying `Axises`
  was posted from a pre-fix build. **(B)** — no dialog warning, and `$H` present.
- **HB-4 (A)** — between `G10 L20 P1 X0 Y0 Z0` and `G0 X25 Y0 F2500` there is an absolute
  `G0 Z<probeSafeZ> F300`, preceded by `( Retract to Safe Z before the offset traverse )`, in that
  order. **(B)** — no `G0 Z…` between the origin write and `G38.2`, no `Retract to Safe Z before the
  offset traverse` comment, and no `X`/`Y` rapid at all (a zero-offset job emits none of the three).
  *`HB-2 (A).gcode` matches (B)'s setup and satisfies all three clauses — `G10 L20 P1 X0 Y0 Z0`
  (127) is followed only by comments and `M0 (MSG Attach ZProbe)` before `G38.2 F30 Z-10` (136), and
  the dump reads `probeOffsetX/Y = 0`. It does **not** close the row.* HB-4's own resolution is that
  a zero-offset job stays byte-identical, so (B) reads the same on every build the post has ever
  had: alone it discriminates nothing, and its whole value is as the control for (A). It closes when
  (A) is posted **from the same build**, which is `conventions.md`'s rule for an absence row and the
  reason HR-11 needed a sibling.
- **HB-5 (A)** — the file holds
  `( >>> WARNING: Safe Z (6 - On WCS / Part / Fixture Changes) format error: 15.000 )`, and the
  Resolved Values line still reads `Probe SafeZ = Error = 15.000 …`. Fusion's post dialog carries a
  warning quoting `"Safe Z"` and `"15mm"`. The group name in the warning is the discriminator that
  it is the probe field and not the map one — both properties are titled from a bare `Safe Z…`.
  **(B)** — the dialog warning quotes `"Map: Safe Z to Rapid"` and `"15mm"`, and the **file** holds
  no `format error` line at all: the probe field parsed, and `safeZforSection()`'s own map-side
  warning is unreachable with the mapper off. That absence is the discriminator — it proves the
  dialog half is not the in-file half leaking. **(C)** — **no** `format error` anywhere in the file
  and **no** dialog warning of either wording; the Resolved Values block reads
  `Probe SafeZ = Retract level, fallback 15, resolves to …` and `Map SafeZ = Retract level, …`,
  neither saying `Error`, which proves both fields really were left at their defaults.
  *Corrected 2026-08-08: this said `fallback 15.000`. `HB-2 (A).gcode` 109-110 render it without
  decimals — `Map SafeZ = Retract level, fallback 15, resolves to 5.08`, and the same for
  `Probe SafeZ`. **Check (A)'s `Error = 15.000` against the real render when (A) runs**: it was
  written from the same assumption and is probably `Error = 15`.* And as with HB-4 (B),
  `HB-2 (A).gcode` satisfies (C)'s file half — both fields `Retract:15` in the dump, no
  `format error` anywhere — but **does not close it**. HB-5 touches the emitted file only when a
  field fails to parse, so (C) reads identically on a build predating `e5db625`, and its dialog half
  cannot be read from a `.gcode` at all. It closes with (A) or (B) from the same build.
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
  *Corrected 2026-08-08 from `HB-2 (A).gcode`: "**only**" holds only for an operation that requests
  no coolant, and the document that artifact came from is not one.* `2.5D Milling - Mounting Plate`
  / `Setup1` / `Face1` asks for **Flood** with both channels `Off`, so even at `Info` it already
  emits `( >>> WARNING: No matching Coolant channel : Flood requested)` (152) — the **second** of
  HB-9's three sibling-less warnings, and the row's finding text predicted its wording exactly.
  Posted from that document, HB-9 (A) must expect **two** `(` lines and no others; posted from a
  coolant-`None` operation, one. Either run is valid — **say which in the result** — and the
  two-warning version is the better artifact, since one post then exercises two of the three
  warnings that have no `validateJob()` sibling to fall back on.
- **HB-11 (A)** — every blank separator in the file is the same string. `grep -c '^()$'` = 0 and the
  count of `^( )$` equals what `HB-2 (A).gcode` shows for the two forms combined (17), so the fix
  changed the form and not the number of separators. Today's file is the pre-fix reading: `( )` at
  141, `()` at 196.
- **HB-12 (A)** — the Stop file's arc is preceded by `G17`. The discriminator is **order**: `G17`
  after the last `G18` line and before the first line of the loaded footer. Today's file is the
  pre-fix reading — `G18 G2 X182.797 Z-0.083 K4.997` (192) is the last plane code, and `G0 Z15.24`,
  `X0 Y0 F2500` and `M30` follow it with no `G17`, so a footer arc would have run in ZX. Note the
  Stop file **replaces** the Stop phase (group 8's own description), so check whether `M30` still
  arrives at all before reading the plane.

---

## Checked and found correct

`posted` readings of `HB-2 (A).gcode` that no row claims. **What empties this:** each entry retires
when a row is written that asserts it, or when the artifact it names is superseded — not on the
`read`-strength condition in Rule 4, since these are posted-strength.

- **Motion words are omitted on seven lines and every one of them is a correct rapid or feed** —
  `Z15.24 F300` (153), `X210.283 Y18.039 F2500` (154), `Z5.08 F300` (155), `X0 F900` (162),
  `X-32.483 Y108.961 F2500` (175), `X177.8 F900` (182), `X0 Y0 F2500` (201). This is the file's most
  alarming-looking feature and it is right: `gMotionModal` is `createModal({})` **only** on the GRBL
  branch (1933) and `createModal({ force: true })` on Marlin/RepRap (1936), so a bare axis line can
  never reach a firmware that lacks modal motion — Marlin's `GCODE_MOTION_MODES` is off in stock
  `Configuration_adv.h`. Every one of the seven inherits its mode from an explicit `G0`/`G1` earlier
  in the same file. **Recorded so it is not re-raised**, as HB-1 and HB-6 were. The one boundary this
  does *not* cover is the first section's, which is HB-12's open question.
- **Every arc closes.** All eight `G2`/`G3` blocks were checked by computing the centre from `I`/`J`
  or `I`/`K` and comparing its distance to the start and to the end: 159, 164, 168, 172 (pass 1) and
  179, 184, 188, 192 (the finish pass) all agree to within the 3-decimal output format. The four ZX
  arcs carry `G18` and the four XY arcs `G17`, and each is followed by an **explicit** `G1` or `G0`
  rather than a modal one — `gPlaneModal`'s `onchange` calls `gMotionModal.reset()` (949), which is
  what forces that and is why a plane switch cannot silently extend an arc.
- **The probe block is ordered correctly and `G38.2` is not left modal.** `G10 L20 P1 X0 Y0 Z0` (127)
  makes the operator's jogged height a provisional Z0 so `G38.2 F30 Z-10` (136) is a 10 mm *relative*
  limit; `G10 L20 P1 Z0.8` (137) then sets the plate thickness at the trigger point; `G0 Z5.08` (138)
  is **explicit**, which it must be — `G38.2` is modal group 1, so a bare `Z5.08` there would have
  been a second probe. `G38.2` rather than `G38.3` means a probe that never triggers alarms instead
  of continuing.
- **`Scale Feedrate` is clamping per axis, on a second document.** The XZ lead-in/out arcs take
  `F180` (`Max Cut Speed Z`), the XY cuts `F900` (`Max Cut Speed XY`), travels `F2500`/`F300`. The
  arcs are the discriminator: a 45° XZ arc at the `F1000` XYZ limit would drive Z at ~636 mm/min,
  3.5× its limit, so clamping the whole path to the Z figure is the conservative answer and it is
  what the file does. Independent of `HR-33 (A).gcode`, which showed the same on another job.
- **The ranges table matches the motion.** Header `X -32.483…210.283`, `Y 18.039…108.961`,
  `Z -5.08…15.24` against the extremes actually emitted, arcs included — the XY link transitions bulge
  to X-21.279 and X199.079, both inside. A header that disagreed with the moves would mean the post
  computed its extents from something other than what it emitted.
- **The inert features stay silent.** `Fixed Z Reference` = `None` with `Probe to Set Base` left at
  `Pause & Probe Z` and `Safe Z Across WCS` on emits nothing at all, and the Resolved Values block
  says `Fixed Z reference = None` rather than resolving a height — graceful degradation holding on the
  group-5 controls a single-part job must be able to ignore. Same for group 3 (mapper off), group 7
  (`toolChangeEnabled = false`, so no `T`/`M6` on a controller with no changer) and group 10.

---

## Owed

What this register still owes, and why each artifact is worth a post.

- **Every live row above except HB-2's two is unrun.** `HB-2 (A).gcode` (2026-08-08) is the only
  artifact; every other finding is still proved by reading the post, and the firmware claims by
  firmware source, cited in each row.
- **One post would close three more rows: re-post HB-4 (A) from the current build.** `HB-2 (A).gcode`
  already satisfies HB-4 (B) and HB-5 (C) clause for clause, and both are held open only for want of
  a presence sibling from the same build. HB-4 (A) is that sibling for (B); HB-5 (A) or (B) for (C).
  Until then this register has **no** row whose pass depends on a commit later than `5a6a4e0` — a
  factory-default GRBL job cannot see HB-3, HB-4, HB-7, HB-8, HB-9 or HB-5, so the seven fixes from
  `ec5af37` to `e5db625` are entirely unverified in output, and the artifact that exists cannot be
  dated past the first of them.
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
