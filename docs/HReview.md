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

## Findings — HB-1 … HB-20 — 20 findings

| ID | Finding | Sev | Resolution | Status |
|---|---|---|---|---|
| **HB-1** | **Marlin `M0` is conditionally compiled, so a build without a panel would skip every operator stop.** `askUser()` (4010-4013) emits `M0 <text>` on Marlin. Marlin gates `M0` on `HAS_RESUME_CONTINUE` — `Marlin/src/gcode/gcode.cpp` 2.1.x: `#if HAS_RESUME_CONTINUE` / `case 0: case 1: M0_M1(); break;` / `#endif` — which `Marlin/src/inc/Conditionals_adv.h` defines as `#if ANY(EXTENSIBLE_UI, IS_NEWPANEL, EMERGENCY_PARSER, HAS_ADC_BUTTONS, HAS_DWIN_E3V2)`. On a build satisfying none of those, `M0` reaches `default: parser.unknown_command_warning(); break;` and the job runs on, losing the probe-attach stop, the *Turn ON RPM* stop and the spindle-off stop at once | — | **Closed by design — not a defect on the machines this post targets.** Every Marlin build in the target audience has a panel, so `IS_NEWPANEL` is satisfied and `M0` is always compiled in. The post is therefore right to emit `M0` unconditionally on Marlin, and no warning is wanted: it would fire on every Marlin job to describe a build that does not exist here. Recorded so the `gcode.cpp` gate is not re-derived and re-raised by a later pass | ➖ |
| **HB-2** | Every GRBL file opened and closed with a `%` line stock Grbl 1.1 rejects — `error:1`, or `error:9` from the opening one while still in Alarm before `$H`. Masked only because UGS / bCNC / Candle strip `%` before streaming | Med | `5a6a4e0` — dropped from both branches rather than gated behind a property, and `onOpen()` carries the `grbl/protocol.c` citation because an absence cannot explain itself | ✅ fixed |
| **HB-3** | `Home at Job Start` = `Home` with `Axes Homed and Trusted` = `None` homes nothing and said so only inside the file — `writeMachineHoming()` warned and returned, and `validateJob()` carried six `warning()` calls but none for this one, so Fusion's dialog was silent. The likeliest group-4 mistake: the operator sets *the action* and never reads the declaration above it as something they must change too | Med | `ec5af37` — a `validateJob()` warning on `homesAtJobStart() && !homedXY && !homedZ`, the exact complement of the existing homing-destroys-the-pre-jog test; the `Axises` → `Axes` sweep rides in the same commit | ✅ fixed |
| **HB-4** | A non-zero `Probe X/Y Offset` traversed to the probe point at the operator's own jogged Z, with no lift and no warning. On the default `First WCS / Part` the mode's own premise is a bit parked a millimetre over the stock, so a 25 mm offset dragged it 25 mm across the work or into a clamp before the probe. The sibling `Use Active WCS X0 Y0, Probe Z0` path prints `Unknown Z for XY move.` for exactly this hazard; this one passed no `zUnknown`, so it said and lifted nothing | Med | `cb1c9f2` — `rapidMovementsZ(probeSafeZ())` between the provisional origin write and `partProbe(true)`, where the `Z0` one line above makes the absolute retract measure from the operator's own height, gated on a new `probeOffsetIsSet()` so a zero-offset job stays byte-identical | ✅ fixed |
| **HB-5** | **A malformed group-6 `Safe Z` falls back to 15 mm with only a `Debug` trace, where its group-3 twin warns.** Both properties share `parseSafeZExpr()`, which returns `eSafeZ.ERROR` for anything that is not a bare number or `Feed:`/`Retract:`/`Clearance:<n>` — including a leading minus, a unit suffix (`15mm`) or an emptied field. `safeZforSection()` 1119-1122 answers that with an `Important` `>>> WARNING: … format error`; `parseProbeSafeZProperty()` 1214-1221 answers it with a `Debug` comment nobody posts at. The only other trace is `Probe SafeZ = Error = 15.000` in the `Info`-level Resolved Values block. 15 mm is a plausible retract height, so the mistake looks like it worked | Low | `parseProbeSafeZProperty()` now answers `eSafeZ.ERROR` with a `writeWarning()` naming the field, its group and the fallback — the map-side's wording, so neither can drift. **The `validateJob()` half covers BOTH properties, not just the probe one:** a dialog warning on the probe side alone would have moved the asymmetry rather than removed it, and the row's own argument is that two properties documenting each other as "same syntax" must fail the same way. Neither had ever reached Fusion's dialog. `parseSafeZExpr()` is pure, so parsing a second time there cannot disagree with `onOpen()`. A job whose Safe-Z fields parse stays byte-identical | ✅ fixed |
| **HB-6** | **`G17` and `G94` are emitted only on the GRBL branch, so RepRap inherits whatever plane and feed mode the last job left.** `Start()` 3892-3900 puts both inside `if (fw == eFirmware.GRBL)`; the Marlin/RepRap branch emits `G90`, `G21`/`G20` and `M84 S0` only. `circular()`'s non-GRBL branch 4060-4069 then writes `G2`/`G3` with `I`/`J` and **no `G17`**. Both codes are live modal state in RRF — `Duet3D/RepRapFirmware` `src/GCodes/GCodes2.cpp` `HandleGcode()` has `case 17:`/`case 18:`/`case 19:` setting `selectedPlane`, and `case 93:`/`case 94:` setting `inverseTimeMode`, per input channel, copied to every channel by `CheckFinishedRunningConfigFile()` and not reset at job start — so a controller left in `G18` reads every arc's `I`/`J` in the wrong plane, and one left in `G93` reads every `F` as inverse time | — | **Closed by design — the proposed fix was worse than the defect.** That fix was "emit both on the non-GRBL branch, they are no-ops on a controller already in that mode". **They are not codes the other two firmwares have.** `G94` is absent from Marlin in *every* configuration (`gcode.h` 2.1.x lists no `G93`/`G94`) and absent from RRF until **3.5.1**, which added both "experimentally" — before that `case 93:`/`case 94:` are not in `HandleGcode()`'s switch at all and it falls to `default:`, an unsupported command. `G17` compiles on Marlin only under `CNC_WORKSPACE_PLANES`, shipped commented out in `Configuration_adv.h`; otherwise it reaches `default: parser.unknown_command_warning()`. So the "two lines" cost an `Unknown command` echo on every Marlin job and an unsupported-command error on every RRF below 3.5.1. Marlin silences that class where it wants to — `case 21: NOOP; break; // No error on unknown G21` — and chose not to here. **And the RepRap-only `G17` that would be safe is not reachable from this post:** `circular()`'s non-GRBL branch linearizes every non-XY arc, so nothing the post emits can leave a controller in `G18`/`G19`, and `G94` became redundant at RRF **3.6.3**, which fixed issue 1129, "inverse time mode was not reset when starting a job". A plane set by something outside the post is a group-8 Start file's job to correct. Recorded so the GRBL-only guard is not re-derived and re-raised; the settlement is in `design.md` → *Firmware capabilities* | ➖ |
| **HB-7** | A group-8 include file that does not exist aborted the post *after* part of the file was written: `loadFile()`'s `error()` fires at step 4 of `writeFirstSection()`, by which point the header block, the property dump, the homing and the `G54` select are already in the stream. The operator got a truncated `.gcode` that looks like it starts a job, and the Stop include failed later still | Low | `b61c005` — pre-flight loop at the head of `validateJob()`'s Guards block, sharing a new `includeFolder()` with `loadFile()` so the two cannot disagree about where they looked. **Scope deliberately partial:** the tool-change pair only when group 7 is on, the four `coolant…Custom` files not at all (`PReview.md` §6), and HR-27's geometry half still open | ✅ fixed |
| **HB-8** | `fOutput` and the word separator were set one way in `onOpen()` and covered by neither branch nor `resetPostState()` — which exists precisely because the post does not rely on a fresh JavaScript context per file. Post with `Enforce Feedrate` on, then a second file with it off, and the second still carried a forced `F` on every move; same for whitespace. Quiet because the output is a superset rather than wrong g-code. `gMotionModal`'s conditional assigns on both branches and so never leaked | Low | `b84f602` — both assignments unconditional, `{ force: false }` being the declaration's own value rather than a guess; `resetPostState()`'s header records that these two and `gMotionModal` are rebuilt from properties in `onOpen()` rather than reset there | ✅ fixed |
| **HB-9** | `Comment Level` = `Off` suppressed every `>>> WARNING:` the post writes, because `writeComment()` gates on level and every in-file warning is `Important`. Most have a `validateJob()` sibling and survive there; three do not — the jet-tool / tool-0 `Z0 was NOT established`, `No matching Coolant channel : <mode> requested`, and HB-3's `nothing was homed`. A tool carrying a coolant mode no channel is configured for is the ordinary group-10 case: the post correctly emits no coolant code, and at `Off` it also said nothing about having ignored the request | Low | `1c5fcce` — all **thirteen** `>>> WARNING:` sites go through a new `writeWarning()` that bypasses the level gate, with `writeComment()`'s emit half factored out as `writeCommentLine()` so the prefix cannot drift. The row named three warnings; the code had thirteen. The `>>>` lines that are *not* warnings stay level-gated | ✅ fixed |
| **HB-10** | **`Tool Change Probe` (`includeProbeFile`) is a dialog field that does nothing.** Declared at 654-662 with a title and tooltip; nothing in the post calls `loadFile()` with it, so a filename entered here is silently ignored. The tooltip does say `NOT IMPLEMENTED YET`. *Pre-seeded — named in the checkpoint before this pass began, not an independent find; recorded so the fresh register is not missing a known group-8 defect* | Low | **Deferred to the professional review** (2026-08-08) — open, but not hobbyist work. Wiring it means deciding *when* in a tool change the probe file is loaded, which is `PReview.md` §2's ordering design, and deleting it is a dialog decision for the pass that owns group 7; either answer taken here would be taken blind. So it lands with the Tool Change branch, alongside `HR-21` / `CR-15`, which are the same property. Kept in this register rather than moved, because `PReview.md` is absent from this branch's working tree and a row split across two files is how the seven professional ids went stale | ⬜ |
| **HB-11** | **The two blank separator comments disagree by one character.** `onSectionEnd()` 2671 writes `writeComment(eComment.Important, "")` where its sibling at the end of `Start()` 3345 writes `writeComment(eComment.Important, " ")`, so a GRBL file carries `( )` after the START block and `()` after every section — `HB-2 (A).gcode` 141 vs 196. **Nothing operational turns on it**: both are well-formed empty comments in every dialect the post emits, and because both go through `writeComment()` both are dialect-switched, so neither can reach Marlin/RepRap as a stray `(`. Recorded only because a one-character difference between two adjacent call sites reads as significant to the next person diffing two files | Low | **Fixed** — `" "` in `onSectionEnd()`, the same blank separator `Start()` ends with, so every separator in a file is one form. A comment at the site records why the character is deliberate, since the alternative to explaining it is someone tidying it back. `HR-19`'s doubled space is the same class and still open | ✅ fixed |
| **HB-12** | **A job whose last arc was a Z lead-out ends with the plane left at `G18`, and the post never restores `G17`.** In `HB-2 (A).gcode` the last plane-setting code is `G18 G2 X182.797 Z-0.083 K4.997` (192); the retract, the end park and `M30` all follow with no `G17`. `Start()` emits `G17` once, at job start, and `circular()` emits it only when an arc needs it. Beyond `M30` this is contained — grbl 1.1 `grbl/gcode.c`, `gc_execute_line()`'s `PROGRAM_FLOW_COMPLETED` branch, resets `gc_state.modal.plane_select = PLANE_SELECT_XY` ("*only a subset of g-codes reset to certain defaults, according to LinuxCNC's program end descriptions*") — and unreachable on the other two firmwares, whose `circular()` branch linearizes every non-XY arc (HB-6). **But the window between the last lead-out and `M30` is exactly where a group-8 Stop file is injected**, so an operator footer containing `G2`/`G3 X… Y… I… J…` runs in the ZX plane: the silent wrong-plane arc HB-6 was written about, this time caused by the post rather than by a stale controller. **The same boundary raised a second question, now settled:** that `PROGRAM_FLOW_COMPLETED` branch also resets `modal.motion` to `MOTION_MODE_LINEAR`, so after any `M30` the controller sits in **`G1`** and a wordless first move would be a feed plunge rather than a rapid. It cannot arise. `gMotionModal` is rebuilt on both branches of `onOpen()` (1937-1942), so it is empty at every file's start and its first `format()` always emits, and no `writeBlock` in the post writes an axis word without a motion word. All nine posted files agree — every first motion is an explicit `G38.2` or `G0`, across five configurations including HB-3 (B)'s and HB-4 (A)'s. So no `First WCS / Part` answer can plunge, and the contingent `gMotionModal.format(0)` this row reserved is not wanted | Low | **Fixed** — `gPlaneModal.format(17)` immediately before `loadFile()` in `onClose()`, GRBL branch only: off GRBL `circular()` linearizes every non-XY arc so the line would buy nothing, and Marlin lacks `G17` without `CNC_WORKSPACE_PLANES` anyway (HB-6). In that branch and **not** at the head of `onClose()`, because the built-in stop block emits no arc — a `G17` there protects nothing and would change every GRBL job's output, `gPlaneModal.onchange` resetting `gMotionModal` and putting a `G0` on the park move. Through the modal, so an all-XY job stays byte-identical. Pinning the end-of-file plane is what made HB-16 worth fixing beside it | ✅ fixed |
| **HB-13** | **On `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0` the post holds no Z reference, and it neither creates one nor bounds what it does without one.** Two consequences, both visible in `HB-3 (B).gcode`. **(a)** `(   Ensuring that Z is safe. Unknown Z for XY move.)` (127) is followed by **no Z motion whatsoever** — `G0 X0 Y0 F2500` (129) traverses from the `$H` corner to the part origin at whatever height the tool already holds. With `Axes Homed and Trusted` = `XY` the Z axis is not homed, so that height is wherever the operator left it and the traverse crosses the bed through anything standing in the way. It is a plain comment and not a `>>> WARNING:`, so HB-9's bypass does not cover it: at `Comment Level` = `Off` even the notice is gone. **(b)** `G38.2 F30 Z-10` (138) runs with **no provisional `Z0`**. The sibling `Current XY & Probe Z` path writes `G10 L20 P1 X0 Y0 Z0` for exactly that purpose — "*Provisional Z0 at the current height so the probe target is a relative limit*", its own comment — so `Probe Z Target` means a bounded 10 mm on one path and an unknown distance on the other, measured against a stored offset the mode's own name says is not trusted for Z. Too shallow and `G38.2` alarms without cutting; too deep and it descends further than the field claims. **What gives this weight is that `validateJob()` 1587-1593 recommends this exact mode by name** when the operator trips CR-2, so the post steers a homed machine out of one hazard and into an unguarded traverse. *Two caveats. The `HR-`/`CR-` register is not on this branch, so this may restate something closed there — the caveat HB-10 carries. And HB-4's row cited this path approvingly, "prints `Unknown Z for XY move.` for exactly this hazard", reading the comment as sufficient; the posted file shows it lifts no more than the path HB-4 fixed, it merely says more.* | Med | **Fixed as a warning in both channels, and the lift this row proposed is rejected.** Two answers were designed and put up before either was written. A **refusal** — `error()` on the mode with no fixed Z reference — was rejected by the operator's call and rightly: it would delete the one first-part mode that establishes a *trusted* Z on a machine whose stored XY is worth trusting, so the cure destroys what the probe is for, and it would have refused `HB-3 (B)`'s configuration, which this register calls legitimate. The **relative `G91 G0 Z<n>` lift** is rejected on its own merits, not just by preference: it would be the only motion this post emits in no frame at all, its extent is unknowable on a machine whose Z travel the post cannot see, and it leaves **(b)** exactly as unbounded as it found it — a blind move offered in place of having a frame. What is left is the only thing the post honestly can do: **state the precondition it is relying on**, since the start height is a promise only the operator can make. So (a) and (b) travel in one message, because one act — parking the tool clear before starting — satisfies both: `partProbe()` 3644 now writes a `writeWarning()` in place of the `Info` comment, which is HB-9's class on the one line in the file that *asks* for something (at `Comment Level` = `Off` the old notice was simply gone), and a `validateJob()` warning says the same before the post, where the operator can still change something. The old text is dropped as well as promoted: "*Ensuring that Z is safe*" read as reassurance while ensuring nothing. **(b) is named, not removed** — the warning tells the operator that `G38 Target` is measured from the stored Z0 this mode re-probes and must cover the distance from wherever they parked. Making the post guarantee that bound means writing a provisional `G10 L20 P<wcs> Z0` at the start height, which is sound on the same promise but redefines that field's meaning on a path that posts today, and 3745-3749 records the deliberate decision not to; it is in *Owed* as an option, not carried here as an open half | ✅ fixed |
| **HB-14** | **The in-file `format error` warning runs the property title into its group with no separator, and the obvious separator is the one it must not use.** `HB-5 (A).gcode` line 1 reads `( >>> WARNING: Safe Z 6 - On WCS / Part / Fixture Changes format error: 15)`, which a reader parses as a property called "Safe Z 6". HB-5 (A)'s Expect predicted `Safe Z (6 - On WCS / Part / Fixture Changes)` and **that form would be a defect, not a fix**: grbl 1.1 buffers a `(`…`)` comment with no nesting and ends it at the first `)` it meets, so the inner bracket would close the comment and leave ` format error: 15)` to be parsed as g-code — `error:` on the one line written to explain a mistake. The emitted form is therefore right to have no parentheses and wrong to have nothing. **Sharper than "no separator" once the source is read: the brackets ARE written and the sanitizer eats them.** The call site wrapped the group in `" (" … ") "`, and `writeCommentLine()` passes every warning through `sanitizeMessageText(text, "()")`, which replaces runs of `(`/`)` with a space and then collapses the doubled space — so the post already protects itself from the hazard above and the run-together line is that protection's own footprint, not a forgotten separator. *Open question, same line, now settled:* it is emitted **above the generated-by header** where HB-3's lands after the property dump, and the two are right to differ — each is written at the point the post learns of the problem, this one in `onOpen()` and that one in `writeMachineHoming()`, so agreeing on a region would mean buffering warnings to emit them elsewhere. A parse failure above the header is if anything the better place for one. HB-2 (B)'s criterion is unaffected: it reads the first g-code **block**, never the first line | Low | **Fixed** — one `writeSafeZFormatWarning()` (1058) that both sites call, so HB-5's "two properties documenting each other as *same syntax* must fail the same way" is enforced by construction instead of by two call sites agreeing. Quoted title, `in`, quoted group, then ` -- format error, falling back to <n>`: quotes and `--` survive the sanitizer, and quoting a property title is how `validateJob()`'s warnings already name one. **Two further asymmetries surfaced on reading the twin** and are fixed with it: the map side named **no group at all**, though `Safe Z` alone identifies neither property, and it printed the fallback as a bare JavaScript number where the probe side went through `xyzFormat` — so on an inch job the two warnings disagreed about the same 15 mm. Line length is not a new hazard: both firmwares discard comment characters as they read rather than buffering them (grbl 1.1 `grbl/protocol.c`, `protocol_main_loop()`, "*Throw away all (except EOL) comment characters and overflow characters*"), and the property dump already emits far longer lines | ✅ fixed |
| **HB-15** | **The include-file refusal explains the post's own history to the operator.** The `error()` at 1806 ends "*Refused before any output, rather than part way through the file it would otherwise have truncated*" — `HB-7 (A).log` 23, which is the text Fusion puts in front of the operator. The first sentence is actionable and complete; the second describes a counterfactual about behaviour this operator never saw, and is already written out at length in the comment eight lines above the call (1710-1730), where it belongs. **It can actively mislead:** "part way through the file it would otherwise have truncated" reads as a claim that *this* attempt truncated something, and a refused post does leave a `.gcode.failed` on disk, so the sentence and a leftover file point the same wrong way together. Found by reading the operator-facing string in a posted log rather than in the source | Low | **Fixed** — the `error()` string ends at `or clear the field.` The removed sentence's content moved into the comment above the loop, which is where a counterfactual about the post's own former behaviour belongs; the dialog gets only what the operator can act on. HB-19 is the same class — an operator-facing string saying something the operator cannot use — and still open | ✅ fixed |
| **HB-16** | **`gPlaneModal` outlives the file it was created for.** Created once at file scope (949), it is neither rebuilt in `onOpen()` like `gMotionModal` nor reset in `resetPostState()`, so a second file sharing one JavaScript context opens believing the plane it last emitted is still in force — and `Start()`'s `gPlaneModal.format(17)` is then suppressed, shipping a GRBL file with **no `G17` anywhere**, which is the stale-plane hazard that line exists to prevent (HB-6). HB-8's shape on a third global; the comment above `resetPostState()` names only `fOutput` and `gMotionModal` as deliberate exclusions, so this is not a considered one. **Latent, not observed:** every posted file carries exactly one `G90`, `G21` and `G94` from `Start()`, and `gAbsIncModal` / `gUnitModal` / `gFeedModeModal` are never reset either, so this context does appear to be fresh per file. What removes the "appear" as a defence is HB-12's fix, which pins a stop-file job's end-of-file plane at 17 and would make the suppression systematic rather than occasional. **Second half — the include-file leak is real but this row named the wrong file for it.** A `Start GCode File` containing `G18` cannot suppress the post's `G17`, because the property that injects the `G18` also **replaces `Start()`** (`writeFirstSection()`), which is the only place the post emits `G17` at all — so `gPlaneModal` holds no value when that file is read and the first arc emits its own plane word unaided. The exposure is the **tool-change** include files, read mid-job by `toolChange()` with `Start()`'s `G17` already in the modal: a `G18` there does make the next XY arc cut in ZX. Group 7, so no row in this register can run it | Low | **Fixed, and wider than the plane** — `gPlaneModal.reset()` in `resetPostState()` for the cross-file half, restoring the created-fresh state rather than rebuilding the modal so the `onchange` closure stays in one place; and `gPlaneModal.reset()` / `gMotionModal.reset()` / `resetAll()` at the end of `loadFile()`'s content branch for the include half (4058). Widened because the site and the reasoning are identical: every one of those is state the post re-asserts **lazily**, so a stale belief is a *missing* word rather than a wrong one — a file that moves the tool makes the next block omit the axis word that would have brought it back, a move that does not happen at all, which is at least as bad as the plane. `gAbsIncModal` / `gUnitModal` / `gFeedModeModal` are deliberately **not** included: they are formatted once, in `Start()`, so a reset would emit nothing later and a file leaving `G91` or `G20` in force stays undetected — HR-22's question about an include replacing the preamble, not this one. **No output change on any group-8 path without tool changes**: the Start include is read before anything has set a plane, a motion mode or a coordinate, and after the Stop include nothing further is written | ✅ fixed |
| **HB-17** | **`fixedZEstablishedAtStart()` answered a question about the dialog and was read as an answer about the file, which silenced HB-13's warning on the configuration that needed it most.** It returns `usesMachineZDatum() \|\| getReservedBaseWcs() != 0` and tests no firmware, while its own header claimed "neither is available on Marlin" — a gap admitted in prose and not in code. On **Marlin + `Fixed Z Reference` = Spoilboard + a `Reserved WCS` + `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`**, single-WCS, the predicate reads true, so `partProbe()` suppressed the unknown-Z notice — while `writeBaseEstablish()` had already warned and returned for want of per-WCS registers (3521-3527), establishing nothing and moving nothing. The job posts: the spoilboard/reserve pair agree so neither consistency guard fires, the height parses, the park guard does not apply, and Guard C returns without error on a single-offset job. The result is HB-13 (a) with even the notice removed. **Latent in HB-12's sense turned inside out:** every other consumer of the predicate already asked the firmware itself — `parkCanRetract()` carried `fw != eFirmware.MARLIN &&` inline, and `validateJob()` 1654 repeated the same conjunction — so the one call site that did not was the one that was wrong, and the duplication is what hid it. Found while choosing the predicate for HB-13's warning, not by reading Marlin paths | Low | **Fixed** — the question is split in two: `fixedZEstablishedAtStart()` keeps the dialog answer and says outright that it is only that, and a new `fixedZEstablishedInFile()` adds the firmware test. Every consumer that reasons about *the height the tool holds* now asks the second one — the warning, `validateJob()`'s complementary test (identical by construction, so it changes nothing but cannot drift again), and `parkCanRetract()`, which becomes a one-line alias and keeps its name because its callers ask about the park | ✅ fixed |
| **HB-18** | **HB-14's defect has a third call site, and HB-14's fix did not reach it because the finding was written about two properties instead of about the pattern.** `writeBaseEstablish()` 3499 writes `"reserved base " + gname + " ignored on Marlin (no per-WCS registers; single global frame)"`; `HB-17 (A).gcode` 122 emits `; >>> WARNING: reserved base G59 ignored on Marlin no per-WCS registers; single global frame ` — the parenthetical's brackets replaced by spaces and the doubled space collapsed, exactly as HB-14 diagnosed, leaving `Marlin no per-WCS registers` run together and a **trailing space** where the `)` was. So the operator is told the reserved base is ignored and the reason arrives as a fragment grafted onto the firmware's name. Not the same severity as HB-14's, because nothing here parses as a property name and the `;` inside is inert on Marlin — the harm is only that a sentence explaining a declined answer is unreadable. **What this actually shows is a scoping error in HB-14**, not a new mechanism: `sanitizeMessageText(text, "()")` eats parentheses from *every* `writeWarning()`, so the question was never "do these two Safe-Z sites separate their fields" but "which warnings are written with parentheses at all". Found by posting HB-17 (A), a row aimed at something else entirely | Low | **Fixed as a pattern rather than as a site** — `--` and a comma in place of 3525's brackets; the twin rigid-tapping string hoisted into `writeSpeedFeedSyncWarning()` so its two call sites share one text, on the `writeSafeZFormatWarning()` precedent that a string duplicated at two sites is a string that will come to differ at one; and **the rule written down at `writeWarning()` itself**, which is where HB-14 should have left it — no parentheses in the text, because `sanitizeMessageText(_, "()")` turns them into spaces, the collapse rule then joins the clauses, and a trailing `)` leaves a trailing space that rule cannot reach (it needs a non-space to its right). A source sweep now finds **zero** of thirteen call sites carrying literal parentheses, so the scope is closed rather than sampled. Nothing else moves: only these three sites held brackets | ✅ fixed |
| **HB-19** | **HB-13's dialog warning closes by recommending `"Fixed Z Reference"` on the one firmware where neither answer can deliver it — and the job that proves it is the job that already set it.** The warning at 1710-1716 ends "*`Fixed Z Reference` removes both, by establishing a Z the post can move in itself*", and it fires whenever `startMode == "Probe Z" && !fixedZEstablishedInFile()`. That predicate is false on **all** of Marlin by construction (`fw != eFirmware.MARLIN && …`), so on Marlin the warning always fires and its own last sentence is always unactionable: the spoilboard answer is declined by `writeBaseEstablish()` for want of per-WCS registers and the machine-Z answer is refused outright. `HB-17 (A)` sets `Fixed Z Reference` = Spoilboard, gets the warning anyway, and the file says why two lines above the one the warning is about — 122 declares the reserved base ignored, 124 is the warning's in-file half. **The in-file half is not affected**: it names the precondition and recommends nothing, which is the shape the dialog half should have had on this firmware. **This is HB-17 one layer up.** HB-17 fixed the *suppression* reading the dialog's answer instead of the file's; the *advice* still reads the dialog's, and the same two-predicate split is the tool for it — the recommendation is sound exactly when `fixedZEstablishedAtStart()` could become true, which on Marlin it cannot | Low | **Fixed with the split HB-17 introduced** — the closing sentence is now conditional on `fw == eFirmware.MARLIN`, which is exactly the gap between the two predicates at 2412-2413 and so exactly where the remedy cannot be taken. Off Marlin it is unchanged and right, the warning firing only when the reference is unset, so setting it does remove both halves. On Marlin it is replaced by what is true there — this firmware has no fixed Z reference the post can establish, so the start height is the operator's — which is the shape the in-file half already had. **Dialog only; no `.gcode` byte moves on any firmware** | ✅ fixed |
| **HB-20** | **Group 3 asks the hobbyist for three enabling answers to express one decision, and only one of the three is an answer they can usefully give.** `groupDefinitions.mapRapids` (119) is titled `3 - Map G1s to Rapids - disable when using full license` and holds four properties, three of them booleans defaulting `false`: `First G1 -> G0 Rapid` (281), `Map: G1s -> G0 Rapids` (290), `Map: Safe Z to Rapid` (299), `Map: Allow Rapid Z` (308). **The three booleans are not peers, which is what makes the group misleading rather than merely long.** `mapRapidsRestoreRapids` is the master — `isSafeToRapid()` 1292 returns false without it and `safeZforSection()` 1065 does not even resolve the height, so the `Safe Z` field is inert while it is off (`HB-5 (B)` is that configuration). `mapRapidsAllowRapidZ` is a **sub-condition inside** that predicate (1331, 1336) and can do nothing on its own, yet the dialog presents it at the same level as the master. `mapRapidsRestoreFirstRapids` is the reverse: `onLinear()` 2840 tests it **alone**, in the branch *above* `isSafeToRapid()`, so it is a live feature with the master off — and the group heading's own words do not describe it, since it maps one G1 per section rather than G1s in general. **Three of the four titles also carry a `Map: ` prefix that only repeats the heading, and the fourth does not**, so the prefix is neither informative nor consistently applied. *Raised by the operator as a dialog-legibility ask rather than found by reading: reduce group 3 to one enabling control, `Map G1s -> G0 Rapids`, and drop the prefix from the field, leaving `Safe Z to Rapid`* | Low | **Open — the rename is settled and safe, the consolidation is a behaviour change, so they are not one edit.** *Rename:* **no `.gcode` byte moves**, because the property dump echoes property **keys** beneath the group *title* — `HB-12 (A).gcode` 34-38 is `mapRapidsSafeZ = Retract:15` under the heading verbatim — so a field title reaches a file only through the two Safe-Z warnings, and those are HB-5's and HB-14's own lines. 1146 prints title **and** group, where the heading still says `Map G1s` and the shorter title loses nothing, which is HB-14's argument holding; but 1767's dialog warning quotes the **title alone** and its twin is already the bare `Safe Z` (521), leaving the pair separated by suffix only on the one channel HB-5 added to keep them symmetric. And `probeSafeZ`'s tooltip quotes `"Map: Safe Z to Rapid"` **verbatim** (522), so the rename must carry that line or group 6 documents a field that no longer exists — the cross-reference HB-5's "same syntax" argument rests on. The reverse reference (301) names *group 6* and not a title, so it does not move. *Consolidation:* deleting `mapRapidsAllowRapidZ` makes both its branches unconditional, so vertical retracts and safe descents map on **every** job that turns the master on, which is a real change from today's default pairing; deleting `mapRapidsRestoreFirstRapids` **removes a configuration that works today** — master off, first-rapid on — with no successor. Whether that one is folded in, kept as the group's second control, or refused is the question this row is opened to answer, and it is the operator's call rather than a reading. The *Scope* line's 55-of-69 count moves with whichever answer lands | ⬜ |

---

## Test register — 26 rows

Every finding resolves to a row. An unrun row states what must be **present** and what must be
**absent**; a passed one collapses to its artifact and what that file actually showed, so **the state
column is the count — this preamble deliberately names no totals.** Every artifact so far is named
`HB-<id> (<half>).gcode` in `Documents\Fusion 360\NC Programs\`, all posted 2026-08-08 in one Fusion
session **from a build proved identical to `e5db625` — see *Owed***, so no row needs to date itself.
Personas are `conventions.md` → *How to run a test*; defaults are GRBL/mm, `Comment Level` `Info`,
unless the Setup delta says otherwise.

**✅ 22 PASS · ❌ 0 FAIL · ⬜ 1 UNRUN · ➖ 3 n/a — 26 rows. Every row filed against a defect is run.**

| Test | Proves | Setup | Method | State |
|---|---|---|---|---|
| **HB-1 (A)** | Retired with HB-1 — no warning is being added, so there is nothing to post | — | — | ➖ |
| **HB-1 (B)** | Retired with HB-1 | — | — | ➖ |
| **HB-2 (A)** | No GRBL file carries a `%` line | HP-1, unchanged defaults | posted | ✅ |
| **HB-2 (B)** | Presence sibling for (A): the file's own first and last lines are intact, so (A) is not passing on an empty or truncated file | HP-1, unchanged defaults — same post as (A) | posted | ✅ |
| **HB-3 (A)** | The unsatisfiable group-4 combination is refused at the dialog, not only in the file | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` left at `None` | posted | ✅ |
| **HB-3 (B)** | The warning does not fire on the legitimate configuration | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` = `XY Only`, **and `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`** — see the Expect: left at HP-1's default this configuration trips CR-2's warning instead, correctly | posted | ✅ |
| **HB-4 (A)** | The offset probe traverse happens at a known height | HP-1 + `Probe X Offset` = `25` | posted | ✅ |
| **HB-4 (B)** | Absence sibling: a zero-offset job emits no extra lift, so (A)'s new block is attributable to the offset | HP-1, unchanged defaults | posted | ✅ |
| **HB-5 (A)** | A malformed probe `Safe Z` is loud in the file and at the dialog | HP-1 + group-6 `Safe Z` = `15mm` | posted | ✅ |
| **HB-5 (B)** | The dialog half covers the map-side field too, and it alone — the in-file warning is the probe side's | HP-1 + group-3 `Map: Safe Z to Rapid` = `15mm` (`Map: G1s -> G0 Rapids` left **off**, its default) | posted | ✅ |
| **HB-5 (C)** | Absence sibling for (A) and (B): a job whose Safe-Z fields parse says nothing about either, so the warnings are attributable to the malformed value | HP-1, unchanged defaults (both fields `Retract:15`) | posted | ✅ |
| **HB-6 (A)** | Retired with HB-6 — no code change, so there is nothing to post | — | — | ➖ |
| **HB-7 (A)** | A mistyped include filename refuses before any output | HP-1 + `Start GCode File` = `nofilename` | posted | ✅ |
| **HB-8 (A)** | The two one-way settings survive a second post in the same Fusion session | HP-1 posted twice without restarting Fusion: first with `Enforce Feedrate` on and `Include Whitespace` off, then with `Enforce Feedrate` off and `Include Whitespace` on | posted | ✅ |
| **HB-9 (A)** | A `>>> WARNING:` reaches the file at `Comment Level` = `Off`, and nothing else does | HP-1 + `Comment Level` = `Off` + `Home at Job Start` = `Home` + `Axes Homed and Trusted` = `None` (HB-3 (A)'s combination) | posted | ✅ |
| **HB-11 (A)** | Both blank separators read the same | HP-1, unchanged defaults — re-post of `HB-2 (A)`'s job after the fix | posted | ✅ |
| **HB-14 (A)** | The warning reads as one property name plus one group, and still parses as a single GRBL comment | HP-1 + group-6 `Safe Z` = `15mm` — `HB-5 (A)`'s configuration, so today's file is the pre-fix reading | posted | ✅ |
| **HB-14 (B)** | The map-side twin emits the same shape, from the call site no artifact had ever reached | HP-1 + `Map: G1s -> G0 Rapids` **on** + `Map: Safe Z to Rapid` = `15mm`, and — unplanned, decisive — `Safe Z` back to `Retract:15`, which makes this post (A) with the two properties swapped | posted | ✅ |
| **HB-13 (A)** | The operator is told, in the file and at the dialog, that the traverse and the probe target both depend on where they left the tool | `HB-3 (B)`'s configuration exactly — HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` = `XY`, `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`. Today's file is the pre-fix reading. **Post it twice, `Comment Level` `Info` then `Off`** — the level is the discriminator for half of what the row claims | posted | ✅ |
| **HB-12 (A)** | A Stop file's XY arcs are not read in the plane the last lead-out left | HP-1 + `Stop GCode File` = `Arc Stop.txt`, a **complete** footer — the Stop file replaces the phase, so it owns the spindle prompt, the park and `M30` — whose motion includes `G2 X40 Y20 I10 J0` / `G3 X20 Y20 I-10 J0`, on a job whose final operation has a **Z lead-out** (`HB-2 (A)`'s does: its last arc is `G18 G2`) | posted | ✅ |
| **HB-15 (A)** | The refusal tells the operator what to fix and claims nothing about a file | `HB-7 (A)`'s configuration exactly — HP-1 + `Start GCode File` = `nofilename`. Today's log is the pre-fix reading | posted | ✅ |
| **HB-16 (A)** | A `Start GCode File` cannot suppress the post's `G17`, because it replaced the block that writes it — the reading that redirected HB-16's second half. **And the post re-emitted the include's own `G18`**, so a word in a loaded file populates no modal | HP-1 + `Start GCode File` = `G18 Start.txt`, whose only g-code is `G18`, on `HB-2 (A)`'s job. Not a pre/post-fix pair: the fix is a no-op on this path, and the row exists to show *why* | posted | ✅ |
| **HB-17 (A)** | A job that *names* a fixed Z reference it cannot establish still gets HB-13's warning | HP-1 + **`CNC Firmware` = `Marlin`** + `Fixed Z Reference` = the spoilboard answer + `Reserved WCS` = `G59` + `Inter Part Travel Z` = `40` (the spoilboard answer refuses an unset or non-positive height, so the row cannot post without it) + `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, single Setup. Marlin, so **`HB-13 (A)`'s artifact cannot cover this** — the suppression is the firmware's | posted | ✅ |
| **HB-18 (A)** | The Marlin base-establish warning keeps its parenthetical — the third call site of HB-14's defect | `HB-17 (A)`'s configuration exactly, posted **twice** — once pre-fix as a control, once after — so the read is a one-line diff. Read the **whole** of 122: `Marlin` and the reason separated *and* the trailing space gone, both being the same collapsed `)`. The re-post overwrote the control, so the pre-fix line survives only as this register's quotation of it | posted | ✅ |
| **HB-19 (A)** | HB-13's dialog warning stops recommending a remedy the firmware cannot deliver | `HB-17 (A)`'s configuration exactly. **Dialog only** — no artifact holds it, and the pre-fix reading is the operator's report on the `HB-18 (A)` post, quoted there in full: two warnings, the second closing with `"Fixed Z Reference" removes both` on a job that already sets it. Expect that clause replaced, and CR-2's warning still beside it — its co-occurrence here is correct and is not what this row is about | posted | ✅ |
| **HB-20 (A)** | Group 3 states its one decision with one control, and the fold widened the behaviour without changing anything else | HP-1 + `Map: G1s -> G0 Rapids` **on** + `Map: Allow Rapid Z` **on**, posted **before the code is touched** — that file is the control, and the properties that produce it stop existing — then HP-1 + the single surviving toggle on, after | **post the control first** | ⬜ |

### Expects

Where the discriminator needs more than a table cell. **Write every motion token modal-aware:** on
GRBL `gMotionModal` omits a G-word that is already in effect, so name the axis words and the *mode
established above them*, never `G0 X…`. Two Expects here were written the other way and mis-stated a
passing file (HB-2 (B), HB-4 (A)).

- **HB-2 (A)/(B) — PASS, `HB-2 (A).gcode`**, the post-fix baseline every other row diffs against.
  `grep -c '%'` = 0; line 1 is `(Fusion CAM 2704.1.36)`; **`M30` is the last g-code *block*, with
  `( *** STOP end ***)` as the last *line* — the block is the criterion, never the line.**
- **HB-3 (A) — PASS, `HB-3 (A).gcode`**: 114 carries the nothing-was-homed warning, and no `$H`, `G28` or
  `G53` appears anywhere. **(B) — PASS, `HB-3 (B).gcode`**, `$H` at 114 in its place, six-line diff.
  **Keep (B)'s setup, and do not use "dialog clean" as its criterion:** at HP-1's default `First WCS /
  Part` CR-2 satisfies all three clauses of 1580-1581 and warns by design, and HB-13's warning fires on
  the mode 1587-1593 recommends by name — so what (B) proves is the absence of **HB-3's own text**. A flat
  "no dialog warning" reads as a false FAIL.
- **HB-4 (A) — PASS, `HB-4 (A).gcode`; (B) — PASS**, `HB-2 (A).gcode` as the absence half. 127-131 are the
  provisional `Z0`, the retract and `X25 Y0 F2500` — the lift **absolute, from the operator's own height**
  — and the two files differ **only** in that property, its Resolved-Values line and those four lines,
  which is "a zero-offset job stays byte-identical" shown outright.
- **HB-5 (A)/(B)/(C) — PASS, all three, both channels.** (A) the `format error` warning at line **1** of
  `HB-5 (A).gcode`, with the probe retract and its comment the only motion that moves. (B) `HB-5
  (B).gcode` holds **no** `format error` at all while the dialog warns — the two channels independent, and
  *it warns although the property is inert with the mapper off, which is 1765 looping both fields
  unconditionally rather than a false positive.* (C) `HB-2 (A).gcode`, neither.
- **HB-7 (A) — PASS.** No `.gcode` exists; the run left `HB-7(A).gcode.failed`, 51 bytes, holding only
  `!Error: Failed to post data. See log for details.` **The log locates the abort, which the absence alone
  cannot:** `Failed while processing onOpen().` / `Error at line: 1730` — the pre-flight loop, where the
  pre-fix path reached `error()` from `loadFile()` at step 4 of `writeFirstSection()`.
- **HB-8 (A) — PASS both halves, `HB-8 (A)-1.gcode` / `-2.gcode`.** The pair flips **both** properties in
  opposite directions, and **the direction is the point**: both leaks were sticky one-way, so post 1
  setting the separator empty and `fOutput` forced is what post 2 had to shake off, and did. Each file is
  a mechanically single-property delta from `HB-2 (A).gcode`. *All 26 `F` words in (2) were checked against
  the modal feed sequence, so `{ force: false }` is proved rather than merely un-leaked.*
- **HB-9 (A) — PASS, `HB-9 (A).gcode`.** `grep -c '^('` = **2**, the two warnings, with the whole of the
  header, property dump, `MOVEMENT_`/`SECTION`/`COMMAND_` commentary absent. **The `^(` anchor is the
  criterion, not "the file's only `(` line":** four `M0 (MSG …)` prompts correctly survive at `Off`, so six
  lines contain a `(` and the looser reading is a false FAIL. `>>> Spindle Speed: Manual` goes while both
  `>>> WARNING:` lines stay — the bypass and the gate discriminating the same prefix inside one file — and
  the 39 code lines are byte-identical to `HB-2 (A).gcode`'s.
- **HB-11 (A) — PASS**, `HB-2 (A).gcode` re-posted: `grep -c '^()$'` = 0, `^( )$` = **17**, the pre-fix
  count for the two forms combined, so the form changed and the number did not. *Every line number cited
  anywhere in this register still holds — a same-line substitution moved nothing.*
- **HB-14 — PASS at both call sites, and the two posts are exact complements** — `15mm` on the probe field
  then on the map field, so file *and* dialog each name the malformed property and stay silent about the
  valid one, in **both** directions, which reads 1765's loop over both off artifacts. **Placement rather
  than wording attributes (B)** to 1146: `HB-14 (B).gcode` 146 sits inside `*** SECTION begin ***` where
  (A)'s is at line 1 above the header. *The per-section count is undiscriminated by a one-operation job;
  `onSection()` 2690 calls `safeZforSection()` unconditionally with no once-flag, settling it from source.*
- **HB-13 (A) — PASS on both posts and the dialog.** `HB-13 (A)-off.gcode` is 42 lines, the warning at 7
  immediately above `G0 X0 Y0 F2500`, its **40 g-code lines byte-identical** to the `Info` file's — the
  finding and its fix on one page, since pre-fix that file said nothing at all about the height the
  traverse runs at. *(b) stays bounded by the operator's `G38 Target` and not by the post, deliberately:
  the only `G10 L20` is after the probe.*
- **HB-15 (A) — PASS at the dialog.** The text ends at `or clear the field.`, matching 1806-1808 word for
  word, and claims nothing about truncation — which the 51-byte `.failed` on disk would have contradicted.
  **`HB-7 (A)` stays ✅**: its discriminators were never the wording.
- **HB-12 (A) — PASS, `HB-12 (A).gcode`, and the discriminator was order.** 192 is the lead-out `G18 G2
  X182.797 Z-0.083 K4.997`, 197 `( *** STOP begin ***)`, **198 a bare `G17`**, 199 the include marker,
  204-205 the footer's two XY arcs — the plane asserted after the last `G18` and before the loaded footer's
  first line. **The diff against `HB-2 (A).gcode` is the whole read** — line 75's property echo
  and the replaced stop phase, nothing else, so the body is untouched and "a job whose arcs were all XY
  emits nothing" needs no separate absence half. **Two non-defects a re-run must not read as FAIL:** there
  is no `( *** STOP end ***)`, written inside the built-in branch only; and the footer's `G0 Z15.24`
  duplicates the section retract, a raw include bypassing the modals. `M30` arrives, at 207.
- **HB-16 (A) — PASS.** 159 is the first XY arc after the loaded header and carries its own `G17`; the file
  holds exactly two, so none precedes it — `Start()` was replaced, the modal was empty, the arc emitted its
  plane word unaided. **`G90`, `G21` and `G94` each count 0: the include contract, not a defect**, since
  naming a Start file replaces the block that writes all four, and a re-run must not read it as FAIL.
  *The include's own `G18` (118) is re-emitted at 154 — a word in a loaded file populates no modal — and
  the dialog is correctly empty, no `warning()` site being reachable on this configuration.*
- **HB-17 (A) — PASS, `HB-17 (A).gcode`, and the discriminator held two lines apart.** 122 is
  `reserved base G59 ignored on Marlin …` from the establish that did not happen and 124 is HB-13's
  unknown-Z warning on the traverse that did: pre-fix the first appeared while the second was suppressed
  *by* the answer the first had just declared void. `grep -c G53` = **0**, the spoilboard answer's hole and
  not the machine-Z answer's; `grep -c '( >>> WARNING'` = 0 against three `;` forms, the dialect switch
  rather than a miss. **It found HB-18 and HB-19, in the warnings themselves.**
- **HB-18 (A) — PASS.** 122 is `; >>> WARNING: reserved base G59 ignored on Marlin -- no per-WCS registers,
  single global frame`, `cat -A` ending it `frame$`. Both Marlin posts came back **318 lines, the pre-fix
  control's own count**, with 124, 153 and the two `grep` zeros unchanged — so nothing but 122's text moved.
  *The re-post overwrote the control, so that rests on the quoted pre-fix line rather than on a live diff.*
- **HB-19 (A) — PASS at the dialog, on both posts.** The second warning ends `… from that start height.
  Marlin has no fixed Z reference this post can establish, so that start height is yours to set.` and
  opens word for word as before. **CR-2's is beside it, byte-identical to the pre-fix report — the trap:**
  `Axes Homed and Trusted` is `None`, so it fires on its own merits and a flat "one warning" criterion
  reads this PASS as a FAIL. *Off Marlin the `else` string is character-identical to the pre-fix one and
  `HB-13 (A)`'s dialog has read it, so only an inverted ternary could hide there — one post would settle
  it, and nothing here depends on the answer.*
- **HB-20 (A)** — two artifacts and one dialog reading. **Present:** the group-3 dump block down to the
  surviving keys under a **character-identical heading**, since the heading is echoed and field titles are
  not, so the rename must move no line of it; and the after file **byte-identical to the control outside
  that block**, which is the whole of what "the fold kept the wider behaviour" claims. **Absent:** with the
  toggle off, any delta from `HB-2 (A).gcode` beyond the dump — the mapper inert is group 3's default and
  *Checked and found correct* already asserts it. **Order is a criterion here, not a convenience:** the
  control cannot be posted after the edit, because the two properties that configure it are gone; `HB-18
  (A)` is this register's worked example of a control consumed by its own re-post, and the point of naming
  it here is that this one is not recoverable at all. **Trap:** `HB-5 (B)` and `HB-14 (B)` both posted with
  `Map: Safe Z to Rapid` = `15mm` and read a warning that quotes that title, so a re-post of either after
  the rename differs from its artifact by design — check the row's quoted text before calling it a FAIL.

---

## Checked and found correct

`posted` readings of `HB-2 (A).gcode` that no row claims. **What empties this:** each entry retires
when a row is written that asserts it, or when the artifact it names is superseded — not on the
`read`-strength condition in Rule 4, since these are posted-strength.

- **Motion words are omitted on seven lines (153, 154, 155, 162, 175, 182, 201) and every one of them is
  a correct rapid or feed.** This is the file's most alarming-looking feature and it is right:
  `gMotionModal` is `createModal({})` **only** on the GRBL branch (1933) and `createModal({force: true})`
  on Marlin/RepRap (1936), so a bare axis line can never reach a firmware that lacks modal motion —
  Marlin's `GCODE_MOTION_MODES` is off in stock `Configuration_adv.h`. Each inherits its mode from an
  explicit `G0`/`G1` earlier in the same file. **Recorded so it is not re-raised**, as HB-1 and HB-6
  were; the first section's boundary looked like the exception and is not — `gMotionModal` is rebuilt
  per file, so the post's first motion always carries its own word (HB-12).
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
- **The two group-4 warnings really are complements, and the guard emits no motion.** `HB-3 (A).gcode`
  differs from `HB-2 (A).gcode` by exactly three lines — the timestamp, `machineHomeAtStart = Off` →
  `Home`, and the warning added at 114. **Nothing else, and no motion at all.** That is the whole of
  HB-3's claim shown rather than read: `writeMachineHoming()` warns and returns, so a `Home` action
  against a `None` declaration costs one comment and changes no g-code. It also demonstrates the
  mutual exclusion asserted at 1566 — with `None` declared, the `!homedXY && !homedZ` test (1568)
  fires and CR-2's `(homedXY || homedZ)` test (1580) cannot, which is correct: nothing was homed, so
  the pre-jog the CR-2 warning exists to protect is intact and warning about it would be false. A
  single artifact covering two guards this way is worth more than either row claims alone.
- **The warning emits no nested parentheses, which is load-bearing.** grbl 1.1 ends a `(`…`)` comment
  at the first `)` and does not nest, so any bracketed clause the post writes inside a comment would
  close it early and hand the remainder to the g-code parser. `HB-5 (A).gcode` line 1 stays a single
  well-formed comment. Recorded because HB-5 (A)'s own Expect asked for the broken form, so the next
  reader may too — HB-14 is the legibility half of the same line.
- **The inert features stay silent.** `Fixed Z Reference` = `None` with `Probe to Set Base` left at
  `Pause & Probe Z` and `Safe Z Across WCS` on emits nothing at all, and the Resolved Values block
  says `Fixed Z reference = None` rather than resolving a height — graceful degradation holding on the
  group-5 controls a single-part job must be able to ignore. Same for group 3 (mapper off), group 7
  (`toolChangeEnabled = false`, so no `T`/`M6` on a controller with no changer) and group 10.

---

## Owed

What this register owes, and what its posting pass proved about how it was written.

- **It owes one post, and that post has to come first. Sixteen artifacts across two sessions ran every row
  filed against a defect, and every one passed on first read** — no row was ever marked ❌, and none needed
  a second attempt to interpret. What is owed is `HB-20 (A)`'s **control, which has to be posted before the
  code is touched**: the file the fold must be diffed against is produced by the two properties the fold
  deletes. **Two findings are open. HB-10** is deferred to the professional pass by its own row, the dead
  property it names being group-7 work either way; **HB-20** is a dialog-shape ask whose rename half is
  settled and whose consolidation half carries one question only the operator can answer. *`HB-18 (A)` and
  `HB-19 (A)` were the only rows whose fix shipped ahead of them, and one re-post of `HB-17 (A)`'s job
  cleared both — what a register earns by naming, before the post, the exact string it expects to read
  afterwards.*
- **HB-16's include half is fixed where no row here can watch it.** Its payoff is on the tool-change files
  — group 7, excluded from this register and already carrying HB-10 / `HR-21` / `CR-15`.
- **The line numbers cited here had already drifted, and this pass fixed only the ones it moved itself.**
  The HB-18 / HB-19 commit inserted 33 lines; its thirteen displaced citations were renumbered with it and
  each one re-read against the file. **Spot-checking then found an older drift underneath** — CR-2's
  `(homedXY || homedZ)` test is at 1612 where three rows say 1580, its `!homedXY && !homedZ` complement is
  at 1600 where one says 1568, and `parseProbeSafeZProperty()` (1239), `onSectionEnd()` (2779), `Start()`
  (4080), `circular()` (4223) and `askUser()` (4296) are each cited short by tens to hundreds of lines.
  All of them sit in closed rows, so nothing live is read through them, but **until one sweep re-anchors
  the register a cited number is a hint and not evidence** — and a row that cannot be re-found is a row
  that cannot be re-checked.
- **HB-13 (b) has an answer, and the baseline artifact shows it working.** `HB-2 (A).gcode` 125-127 is the
  sibling mode doing exactly this — `G10 L20 P1 X0 Y0 Z0` under the comment "Provisional Z0 at the
  current height so the probe target is a relative limit" — and the `Z`-only form is separable here
  precisely because this mode exists to keep the stored `X0 Y0`. **So (b) is an asymmetry between two
  adjacent modes rather than an open question**, trading an unbounded descent for one that fails by
  *alarming*; withheld because 3745-3749 records the decision and group 6 belongs to another pass.
- **Five of the nineteen findings were discovered by posting rather than by reading — HB-13, HB-14, HB-15,
  HB-18 and HB-19 — and every one of the five is operator-facing text.** That is the argument for the rows
  still unrun, and it has stopped being an argument about coverage. HB-13 (a) sits on a configuration the
  post's own dialog recommends by name and four reading passes went past it; HB-14 was invisible for the
  opposite reason, the Expect that should have caught it asking for the broken form; HB-15 is the string
  HB-7's own fix wrote; and **HB-18 and HB-19 came out of a post aimed at HB-17**, one of them a defect in
  the fix HB-14 had just shipped and the other in the fix HB-13 had. **Nothing in a source review reads a
  warning as prose**, and these five are what that costs — the register's own Expects predicted the broken
  form twice.
- **What empties the Expects section: a row passing.** Once a row is ✅ its pre-run criteria have done their
  work, so the entry collapses to the artifact, the discriminator actually checked, and **any trap a re-run
  would otherwise walk back into** — which is the only reason a passed entry keeps prose at all. Four of
  them did at first: HB-2's *block, not line*; HB-3 (B)'s CR-2 paragraph; HB-9's `^(` anchor; HB-16's
  `G90`/`G21`/`G94` count of 0. The last three rows to pass added three more — HB-19 (A)'s CR-2
  co-occurrence, and HB-12 (A)'s missing `( *** STOP end ***)` and duplicated retract — so **seven traps
  are the whole of what this section now holds**, every one of them a reading that would call a passing
  file broken. Applied across all thirteen passed rows on 2026-08-09, taking the file from its 373
  budget to **301** — the reserve the earlier passes were looking for, since a finding costs one physical
  line however long its cells and only wrapped prose is spendable. **Rule 4's other half is applied too:**
  the Resolution on HB-2, HB-3, HB-4, HB-7, HB-8 and HB-9 is its commit ref plus one clause. *Untouched
  and no longer needed: Checked and found correct retires by its own rule as rows come to assert it.*
- **The build under test is `e5db625` exactly, by file identity rather than by inference.** The `.cps`
  Fusion posts from — `AppData\Roaming\Autodesk\Fusion 360 CAM\Posts\MPCNC_v4.0_Beta2.cps` — is
  byte-identical to this repo's working copy (MD5 `974EA5A1…`), and the working tree's only modified
  file is `docs/HReview.md`, so that copy *is* `e5db625`, the newest commit to touch the post. Every
  surviving session log (`HB-3 (A)`, `HB-5 (A)`, `HB-5 (B)`, `HB-7 (A)`) reports one
  `Checksum of configuration`, `e3195f88…`, and one `Configuration modification date` stamped before
  the first post and unchanged through the last — so nothing in the range was posted from a different
  file, including the two whose logs Fusion has since cleaned up. **This retires the grep-token chain**
  (`5a6a4e0` / `ec5af37` / `cb1c9f2`), which could only infer a lower bound from emitted strings; the
  per-row dating clauses went with it. *Both the logs and the `Gcode generated:` headers run +7 h from
  the filesystem: the 10:21–11:42 file span and the 17:21–18:42 span quoted in these documents are the
  same six posts.*
- **The `Off` file answered a question wider than HB-9:** every plain comment goes, `>>> WARNING:` lines
  stay, the g-code is untouched. **It is the evidence behind HB-13's remedy and it did not survive being
  right about the general case** — the reading retired HB-13's `Off` sibling and argued (a) needed a Z
  *move*; the fix instead made the notice one `Off` cannot remove, so that sibling was owed after all —
  and `HB-13 (A)-off.gcode` came back the most economical artifact here, a whole finding in 42 lines.
- **The geometry guards' half of "a rejected job leaves no file" is still owed.** HB-7's include check
  is now proved to refuse before any output, but the multi-axis and orientation guards still fire in
  `onSection()` and still leave a truncated `.gcode` — `HR-27`, unstarted, and the general fix is moving
  them rather than duplicating the check. `HB-7 (A)` needs no re-post to pair with that row: the
  identical-build proof above lets a later artifact stand beside it, and together they are the claim
  that *no* rejected job leaves a file.
- **Groups 7, 9 and 11 were not walked.** A hobbyist doing a manual tool change on an MPCNC or
  running a diode laser is an ordinary case, and neither is covered by any row here.
