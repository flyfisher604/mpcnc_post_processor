Hobbyist review — findings and tests
====

## Scope

A blind, from-scratch walk of `MPCNC_v4.0_Beta2.cps` from the **hobby operator's** point of view: one
part, one Fusion Setup, one tool, several operations, zeroed by hand or off a touch plate, on an MPCNC /
LowRider running GRBL, Marlin or RepRap. **Groups 1, 2, 3, 4, 5, 6, 8, 10** — 55 of the 69 dialog
properties — each read for its default, then walked through every path it reaches from every Fusion
entry point that can call it.

**Deliberately excluded:** group 7 (tool changes), group 9 (laser), group 11 (Duet), and every
multi-WCS / multi-fixture / Manual NC path — those belong to the professional register. This pass did
not read the earlier `HR-` / `CR-` register, so a finding may restate one closed there; `HB-` ids cannot
collide with ids cited in commit messages. **No controller was available**, so no row is proved by
running one and every firmware claim is settled from firmware source.

---

## Findings — HB-1 … HB-20 — 20 findings

| ID | Finding | Sev | Resolution | Status |
|---|---|---|---|---|
| **HB-1** | **Marlin `M0` is conditionally compiled, so a build without a panel would skip every operator stop.** `askUser()` emits `M0 <text>` on Marlin; `Marlin/src/gcode/gcode.cpp` 2.1.x gates `case 0:` behind `HAS_RESUME_CONTINUE`, which `inc/Conditionals_adv.h` defines as `ANY(EXTENSIBLE_UI, IS_NEWPANEL, EMERGENCY_PARSER, HAS_ADC_BUTTONS, HAS_DWIN_E3V2)`. A build satisfying none of those reaches `unknown_command_warning()` and the job runs on, losing the probe-attach, *Turn ON RPM* and spindle-off stops at once | — | **Closed by design — not a defect on the machines this post targets.** Every Marlin build in the target audience has a panel, so `M0` is always compiled in, and a warning would fire on every Marlin job to describe a build that does not exist here. Recorded so the `gcode.cpp` gate is not re-derived and re-raised | ➖ |
| **HB-2** | Every GRBL file opened and closed with a `%` line stock Grbl 1.1 rejects — `error:1`, or `error:9` from the opening one while still in Alarm before `$H`. Masked only because UGS / bCNC / Candle strip `%` before streaming | Med | `5a6a4e0` — dropped from both branches rather than gated behind a property, with the `grbl/protocol.c` citation at `onOpen()` because an absence cannot explain itself | ✅ |
| **HB-3** | `Home at Job Start` = `Home` with `Axes Homed and Trusted` = `None` homes nothing and said so only inside the file: `writeMachineHoming()` warned and returned, and `validateJob()` carried six `warning()` calls but none for this one. The likeliest group-4 mistake — the operator sets *the action* and never reads the declaration above it as something they must change too | Med | `ec5af37` — a `validateJob()` warning on `homesAtJobStart() && !homedXY && !homedZ`, the exact complement of the existing homing-destroys-the-pre-jog test | ✅ |
| **HB-4** | A non-zero `Probe X/Y Offset` traversed to the probe point at the operator's own jogged Z, with no lift and no warning. On the default `First WCS / Part` the mode's own premise is a bit parked a millimetre over the stock, so a 25 mm offset dragged it 25 mm across the work or into a clamp. The sibling `Use Active WCS X0 Y0, Probe Z0` path prints `Unknown Z for XY move.` for exactly this hazard; this one passed no `zUnknown`, so it said and lifted nothing | Med | `cb1c9f2` — `rapidMovementsZ(probeSafeZ())` between the provisional origin write and `partProbe(true)`, where the `Z0` one line above makes the absolute retract measure from the operator's own height, gated on a new `probeOffsetIsSet()` so a zero-offset job stays byte-identical | ✅ |
| **HB-5** | **A malformed group-6 `Safe Z` fell back to 15 mm with only a `Debug` trace, where its group-3 twin warned.** Both share `parseSafeZExpr()`, which errors on anything that is not a bare number or `Feed:` / `Retract:` / `Clearance:<n>` — a leading minus, a unit suffix (`15mm`), an emptied field. The only other trace was `Probe SafeZ = Error = 15.000` in the `Info`-level Resolved Values block. 15 mm is a plausible retract height, so the mistake looked like it worked | Low | `e5db625` — `parseProbeSafeZProperty()` answers `eSafeZ.ERROR` with the map side's own wording, so neither can drift. **The `validateJob()` half covers BOTH properties:** a dialog warning on the probe side alone would have moved the asymmetry rather than removed it, and the row's argument is that two properties documenting each other as *same syntax* must fail the same way. Neither had ever reached Fusion's dialog. `parseSafeZExpr()` is pure, so parsing again there cannot disagree with `onOpen()`; a job whose fields parse stays byte-identical | ✅ |
| **HB-6** | **`G17` and `G94` are emitted only on the GRBL branch, so RepRap inherits whatever plane and feed mode the last job left.** Both are live per-input-channel modal state in RRF (`Duet3D/RepRapFirmware` `src/GCodes/GCodes2.cpp`, `case 17:` and `case 94:`) and are not reset at job start, so a controller left in `G18` reads every arc's `I`/`J` in the wrong plane and one left in `G93` reads every `F` as inverse time | — | **Closed by design — the proposed fix was worse than the defect.** The fix was "emit both on the non-GRBL branch, they are no-ops there anyway". **They are not codes the other two firmwares have:** `G94` is absent from Marlin in *every* configuration and from RRF until 3.5.1, and `G17` compiles on Marlin only under `CNC_WORKSPACE_PLANES`, shipped commented out — so the two lines cost an `Unknown command` echo on every Marlin job and an unsupported command on every RRF below 3.5.1. **And the exposure is not reachable from this post:** `circular()`'s non-GRBL branch linearizes every non-XY arc, so nothing it emits can leave a controller in `G18`/`G19`, and RRF 3.6.3 fixed inverse time mode not being reset at job start. A plane set by something outside the post is a group-8 Start file's job. Citations in `design.md` → *Firmware capabilities* | ➖ |
| **HB-7** | A group-8 include file that does not exist aborted the post *after* part of the file was written: `loadFile()`'s `error()` fires at step 4 of `writeFirstSection()`, past the header block, the property dump, the homing and the `G54` select. The operator got a truncated `.gcode` that looks like it starts a job, and the Stop include failed later still | Low | `b61c005` — pre-flight loop at the head of `validateJob()`'s Guards block, sharing a new `includeFolder()` with `loadFile()` so the two cannot disagree about where they looked. **Scope deliberately partial:** the tool-change pair only when group 7 is on, the four `coolant…Custom` files not at all, and `HR-27`'s geometry half still open | ✅ |
| **HB-8** | `fOutput` and the word separator were set one way in `onOpen()` and covered by neither branch nor `resetPostState()` — which exists precisely because the post does not rely on a fresh JavaScript context per file. Post with `Enforce Feedrate` on, then a second file with it off, and the second still carried a forced `F` on every move; same for whitespace. Quiet because the output is a superset rather than wrong g-code | Low | `b84f602` — both assignments unconditional, `{ force: false }` being the declaration's own value rather than a guess; `resetPostState()`'s header records that these two and `gMotionModal` are rebuilt from properties in `onOpen()` rather than reset there | ✅ |
| **HB-9** | `Comment Level` = `Off` suppressed every `>>> WARNING:` the post writes, because `writeComment()` gates on level and every in-file warning is `Important`. Most have a `validateJob()` sibling and survive there; three do not — the jet-tool / tool-0 `Z0 was NOT established`, `No matching Coolant channel : <mode> requested`, and HB-3's `nothing was homed`. A tool carrying a coolant mode no channel is configured for is the ordinary group-10 case: the post correctly emits no coolant code, and at `Off` it also said nothing about having ignored the request | Low | `1c5fcce` — all **thirteen** `>>> WARNING:` sites go through a new `writeWarning()` that bypasses the level gate, with `writeComment()`'s emit half factored out as `writeCommentLine()` so the prefix cannot drift. The row named three warnings; the code had thirteen. The `>>>` lines that are *not* warnings stay level-gated | ✅ |
| **HB-10** | **`Tool Change Probe` (`includeProbeFile`) is a dialog field that does nothing.** Declared in group 8 with a title and tooltip; nothing in the post calls `loadFile()` with it, so a filename entered here is silently ignored. The tooltip does say `NOT IMPLEMENTED YET`. *Pre-seeded — named in the checkpoint before this pass began, not an independent find* | Low | **Deferred to the professional review** (2026-08-08) — open, but not hobbyist work. Wiring it means deciding *when* in a tool change the probe file is loaded, which is professional ordering design, and deleting it is a dialog decision for the pass that owns group 7; either answer taken here would be taken blind. So it lands with the Tool Change branch, alongside `HR-21` / `CR-15`, which are the same property. Kept in this register rather than moved, because `PReview.md` is absent from this branch's working tree and a row split across two files is how the seven professional ids went stale | ⬜ |
| **HB-11** | **The two blank separator comments disagreed by one character.** `onSectionEnd()` wrote `writeComment(eComment.Important, "")` where its sibling at the end of `Start()` wrote `" "`, so a GRBL file carried `( )` after the START block and `()` after every section — `HB-2 (A).gcode` 141 vs 196. **Nothing operational turns on it**: both are well-formed empty comments in every dialect, and both go through `writeComment()`, so neither can reach Marlin/RepRap as a stray `(`. Recorded because a one-character difference between two adjacent call sites reads as significant to the next person diffing two files | Low | `18ec9aa` — `" "` in `onSectionEnd()`, the form `Start()` ends with, so every separator in a file is one form; a comment at the site records why the character is deliberate, since the alternative to explaining it is someone tidying it back. `HR-19`'s doubled space is the same class and still open | ✅ |
| **HB-12** | **A job whose last arc was a Z lead-out ended with the plane left at `G18`, and the post never restored `G17`.** `Start()` emits it once and `circular()` only when an arc needs it. Beyond `M30` this is contained — grbl 1.1 `grbl/gcode.c` resets `plane_select` to XY on `PROGRAM_FLOW_COMPLETED` — and unreachable on the other two firmwares, whose `circular()` branch linearizes every non-XY arc (HB-6). **But the window between the last lead-out and `M30` is exactly where a group-8 Stop file is injected**, so an operator footer containing `G2`/`G3 X… Y… I… J…` runs in the ZX plane. *Settled with it:* that branch also resets `modal.motion` to `G1`, so a wordless first move after any `M30` would be a feed plunge — it cannot arise, because `gMotionModal` is rebuilt on both branches of `onOpen()` and no `writeBlock` writes an axis word without a motion word, which all nine posted files confirm | Low | `ae0e013` — `gPlaneModal.format(17)` immediately before `loadFile()` in `onClose()`, GRBL branch only, off GRBL every non-XY arc being linearized. In that branch and **not** at the head of `onClose()`: the built-in stop block emits no arc, so a `G17` there protects nothing and would change every GRBL job's output — `gPlaneModal.onchange` resets `gMotionModal` and would put a `G0` on the park move. Through the modal, so an all-XY job stays byte-identical | ✅ |
| **HB-13** | **On `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0` the post holds no Z reference, and it neither creates one nor bounds what it does without one.** Two consequences, both in `HB-3 (B).gcode`. **(a)** `Ensuring that Z is safe. Unknown Z for XY move.` is followed by **no Z motion whatsoever** — the traverse to the part origin runs at whatever height the operator left the tool, crossing the bed through anything standing in the way, and with `Axes Homed and Trusted` = `XY` the post cannot know that height. It is a plain comment and not a `>>> WARNING:`, so at `Comment Level` = `Off` even the notice was gone. **(b)** `G38.2 F30 Z-10` runs with **no provisional `Z0`**, where the sibling `Current XY & Probe Z` path writes `G10 L20 P1 X0 Y0 Z0` for exactly that purpose — so `Probe Z Target` meant a bounded 10 mm on one path and an unknown descent on the other, measured against an offset the mode's own name says is not trusted for Z. **And `validateJob()` recommends this exact mode by name** when the operator trips CR-2, so the post steered a homed machine out of one hazard into an unguarded traverse | Med | `556a378` — **a warning in both channels; the lift this row proposed is rejected.** A **refusal** on the mode was rejected: it would delete the one first-part mode that establishes a *trusted* Z on a machine whose stored XY is worth trusting, and would have refused `HB-3 (B)`'s legitimate configuration. The **relative `G91 G0 Z<n>` lift** is rejected on its own merits — it would be the only motion this post emits in no frame at all, its extent is unknowable on a machine whose Z travel the post cannot see, and it leaves **(b)** as unbounded as it found it. What is left is to **state the precondition**, the start height being a promise only the operator can make, and one act — parking the tool clear before starting — covers both halves: `partProbe()` writes a `writeWarning()` in place of the `Info` comment, and `validateJob()` says the same before the post. The old *Ensuring that Z is safe* is dropped as well as promoted, having read as reassurance while ensuring nothing. **(b) is named, not removed** — a provisional `G10 L20 P<wcs> Z0` at the start height would bound it on the same promise but redefines that field's meaning on a path that posts today; the decision not to is recorded at the code and in *Owed* | ✅ |
| **HB-14** | **The in-file `format error` warning ran the property title into its group with no separator, and the obvious separator is the one it must not use.** `HB-5 (A).gcode` line 1 read `( >>> WARNING: Safe Z 6 - On WCS / Part / Fixture Changes format error: 15)`, which a reader parses as a property called "Safe Z 6". HB-5 (A)'s own Expect predicted the parenthesised form and **that would be a defect, not a fix**: grbl 1.1 buffers a `(`…`)` comment with no nesting and ends it at the first `)`, so the inner bracket would close the comment and leave ` format error: 15)` to be parsed as g-code. **The brackets ARE written and the sanitizer eats them:** the call site wrapped the group in `" (" … ") "`, and every warning goes through `sanitizeMessageText(text, "()")`, which replaces runs of brackets with a space and collapses the doubled space — so the run-together line is that protection's own footprint, not a forgotten separator | Low | `eea70d1` — one `writeSafeZFormatWarning()` that both sites call, so HB-5's *two properties documenting each other as same syntax must fail the same way* is enforced by construction rather than by two call sites agreeing. Quoted title, `in`, quoted group, then ` -- format error, falling back to <n>`: quotes and `--` survive the sanitizer. **Two further asymmetries are fixed with it:** the map side named **no group at all**, though `Safe Z` alone identifies neither property, and printed the fallback as a bare JavaScript number where the probe side went through `xyzFormat`, so on an inch job the two disagreed about the same 15 mm | ✅ |
| **HB-15** | **The include-file refusal explained the post's own history to the operator.** The `error()` ended "*Refused before any output, rather than part way through the file it would otherwise have truncated*" — `HB-7 (A).log` 23, the text Fusion puts in front of the operator. The first sentence is actionable; the second describes a counterfactual about behaviour this operator never saw. **It can actively mislead:** it reads as a claim that *this* attempt truncated something, and a refused post does leave a `.gcode.failed` on disk, so the sentence and a leftover file point the same wrong way together | Low | `18ec9aa` — the `error()` string ends at `or clear the field.` The removed sentence's content moved into the comment above the loop, where a counterfactual about the post's own former behaviour belongs; the dialog gets only what the operator can act on. `HR-19` is the same class and still open | ✅ |
| **HB-16** | **`gPlaneModal` outlived the file it was created for.** Created once at file scope, it was neither rebuilt in `onOpen()` like `gMotionModal` nor reset in `resetPostState()`, so a second file sharing one JavaScript context opened believing the plane it last emitted was still in force — suppressing `Start()`'s `gPlaneModal.format(17)` and shipping a GRBL file with **no `G17` anywhere**, the stale-plane hazard that line exists to prevent. **Latent, not observed** — every posted file carries exactly one `G90`, `G21` and `G94`, so the context does appear fresh per file — but HB-12's fix pins a stop-file job's end-of-file plane at 17, which would make the suppression systematic. **Second half — the include leak is real but this row named the wrong file for it.** A `Start GCode File` containing `G18` cannot suppress the post's `G17`, because the property that injects it also **replaces `Start()`**, the only place `G17` is emitted at all. The exposure is the **tool-change** files, read mid-job with `Start()`'s `G17` already in the modal — group 7, so no row here can run it | Low | `ae0e013` + `eea70d1` — `gPlaneModal.reset()` in `resetPostState()` for the cross-file half, restoring the created-fresh state rather than rebuilding the modal so the `onchange` closure stays in one place; and `gPlaneModal.reset()` / `gMotionModal.reset()` / `resetAll()` at the end of `loadFile()`'s content branch for the include half. Widened because all of it is state the post re-asserts **lazily**, so a stale belief is a *missing* word rather than a wrong one — a move that does not happen at all. `gAbsIncModal` / `gUnitModal` / `gFeedModeModal` are deliberately **not** included: formatted once in `Start()`, so a reset would emit nothing later — `HR-22`'s question, not this one. **No output change on any group-8 path without tool changes** | ✅ |
| **HB-17** | **`fixedZEstablishedAtStart()` answered a question about the dialog and was read as an answer about the file, which silenced HB-13's warning on the configuration that needed it most.** It returns `usesMachineZDatum() \|\| getReservedBaseWcs() != 0` and tests no firmware, while its own header claimed "neither is available on Marlin" — a gap admitted in prose and not in code. On **Marlin + `Fixed Z Reference` = Spoilboard + a `Reserved WCS` + `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`**, single-WCS, it read true and suppressed the unknown-Z notice — while `writeBaseEstablish()` had already warned and returned for want of per-WCS registers, establishing nothing and moving nothing. The job still posts: the spoilboard/reserve pair agree so neither consistency guard fires, and Guard C returns without error on a single-offset job. The result is HB-13 (a) with even the notice removed. **Every other consumer already asked the firmware itself**, inline — so the one call site that did not was the one that was wrong, and the duplication is what hid it | Low | `556a378` — the question is split in two: `fixedZEstablishedAtStart()` keeps the dialog answer and says outright that it is only that, and a new `fixedZEstablishedInFile()` adds the firmware test. Every consumer that reasons about *the height the tool holds* asks the second — the warning, `validateJob()`'s complementary test — identical by construction, so it cannot drift again — and `parkCanRetract()`, now a one-line alias keeping its name because its callers ask about the park | ✅ |
| **HB-18** | **HB-14's defect had a third call site, and HB-14's fix did not reach it because the finding was written about two properties instead of about the pattern.** `writeBaseEstablish()` wrote `"reserved base " + gname + " ignored on Marlin (no per-WCS registers; single global frame)"`, and `HB-17 (A).gcode` 122 emitted `; >>> WARNING: reserved base G59 ignored on Marlin no per-WCS registers; single global frame ` — brackets replaced by spaces, doubled space collapsed, and a **trailing space** where the `)` was, so a sentence explaining a declined answer arrives as a fragment grafted onto the firmware's name. Not HB-14's severity — nothing here parses as a property name and the `;` inside is inert on Marlin. **What it shows is a scoping error in HB-14:** `sanitizeMessageText(_, "()")` eats parentheses from *every* warning, so the question was never whether those two Safe-Z sites separate their fields but which warnings carry parentheses at all | Low | `2b5dfd5` — **fixed as a pattern rather than as a site.** `--` and a comma in place of the brackets; the twin rigid-tapping string hoisted into `writeSpeedFeedSyncWarning()` so its two call sites share one text; and **the rule written down at `writeWarning()` itself**, where HB-14 should have left it — no parentheses in a warning's text, because the sanitizer turns them into spaces, the collapse rule joins the clauses, and a trailing `)` leaves a trailing space that rule cannot reach. A source sweep now finds **zero** of thirteen sites carrying literal parentheses | ✅ |
| **HB-19** | **HB-13's dialog warning closed by recommending `"Fixed Z Reference"` on the one firmware where neither answer can deliver it — and the job that proves it is the job that already set it.** It ends "*`Fixed Z Reference` removes both, by establishing a Z the post can move in itself*" and fires whenever `startMode == "Probe Z" && !fixedZEstablishedInFile()`. That predicate is false on **all** of Marlin by construction, so on Marlin the warning always fires and its last sentence is always unactionable: the spoilboard answer is declined for want of per-WCS registers and the machine-Z answer is refused outright. `HB-17 (A)` sets the reference, gets the warning anyway, and the file says why two lines above. **The in-file half is unaffected**, naming the precondition and recommending nothing, which is the shape the dialog half should have had. **This is HB-17 one layer up:** that fix corrected the *suppression* reading the dialog's answer instead of the file's; the *advice* still read the dialog's | Low | `2b5dfd5` — the closing sentence is conditional on `fw == eFirmware.MARLIN`, exactly the gap between the two predicates and so exactly where the remedy cannot be taken. Off Marlin it is unchanged and right, the warning firing only when the reference is unset; on Marlin it is replaced by what is true there — this firmware has no fixed Z reference the post can establish, so the start height is the operator's. **Dialog only; no `.gcode` byte moves on any firmware** | ✅ |
| **HB-20** | **Group 3 asked three enabling questions to express one decision, and the three booleans were not peers** — which is what made it misleading rather than merely long. `groupDefinitions.mapRapids` is titled `3 - Map G1s to Rapids - disable when using full license` and held four properties, three of them booleans defaulting `false`. `mapRapidsRestoreRapids` is the master — `isSafeToRapid()` returns false without it and `safeZforSection()` does not even resolve the height, so the `Safe Z` field is inert while it is off (`HB-5 (B)` is that configuration). `mapRapidsAllowRapidZ` was a **sub-condition inside** that predicate and could do nothing on its own, yet the dialog presented it at the master's level. `mapRapidsRestoreFirstRapids` was the reverse: `onLinear()` tested it **alone**, *above* `isSafeToRapid()`, so it was live with the master off — and the heading did not describe it, since it maps one G1 per section rather than G1s in general. **Three of the four titles carried a `Map: ` prefix that only repeated the heading, and the fourth did not.** *Raised by the operator as a dialog-legibility ask* | Low | `bf0c2bd` — **one enabling control and one field, `Map G1s -> G0 Rapids` and `Safe Z to Rapid`, each fold recorded at the code it changed.** **No `.gcode` byte moves for the rename**, because the property dump echoes property **keys** beneath the group *title* (`HB-12 (A).gcode` 34-38), so a title reaches a file only through the two Safe-Z warnings — and the in-file one prints the group too, where the heading still says `Map G1s`, so HB-14's argument holds on the shorter title. **Keys are untouched**, which is load-bearing: a key is what Fusion stores a setting under, so renaming one would silently reset it. `probeSafeZ`'s tooltip and `design.md`'s *Traverse clearance is not the G1→G0 plane* quoted the old title **verbatim** and are carried with it. **What each fold costs:** `mapRapidsAllowRapidZ`'s two branches are now unconditional, so the **default pairing** — master on, that boolean off — converts Cases 2 and 3 where it converted only Case 1. Safe on the tests those branches already carry: both sit inside `if (zSafe)`, both require XY constant, and the descent additionally requires the *start* height to be safe. `mapRapidsRestoreFirstRapids` is folded onto the master rather than made unconditional, because unconditional would convert the first move of every operation on a **full-licence** job and make a group headed *disable when using full license* undisableable. So it costs exactly one configuration, master off with first-rapid on, named before the edit rather than discovered after | ✅ |

---

## Test register — 26 rows

Every finding resolves to a row. Every artifact is named `HB-<id> (<half>).gcode` in
`Documents\Fusion 360\NC Programs\`, all posted 2026-08-08 in one Fusion session **from a build proved
identical to `e5db625` — see *Owed***, so no row dates itself. Personas are `conventions.md` → *How to
run a test*; defaults are GRBL/mm, `Comment Level` `Info`, unless the Setup delta says otherwise.

**✅ 23 PASS · ❌ 0 FAIL · ⬜ 0 UNRUN · ➖ 3 n/a — 26 rows. Every live row is run — 22 by artifact, `HB-20 (A)` by code walk.**

| Test | Proves | Setup | Method | State |
|---|---|---|---|---|
| **HB-1 (A)** | Retired with HB-1 — no warning is being added, so there is nothing to post | — | — | ➖ |
| **HB-1 (B)** | Retired with HB-1 | — | — | ➖ |
| **HB-2 (A)** | No GRBL file carries a `%` line | HP-1, unchanged defaults | posted | ✅ |
| **HB-2 (B)** | Presence sibling for (A): the file's own first and last lines are intact, so (A) is not passing on an empty or truncated file | same post as (A) | posted | ✅ |
| **HB-3 (A)** | The unsatisfiable group-4 combination is refused at the dialog, not only in the file | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` left at `None` | posted | ✅ |
| **HB-3 (B)** | The warning does not fire on the legitimate configuration | HP-1 + `Home at Job Start` = `Home`, `Axes Homed and Trusted` = `XY Only`, **and `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`** — at HP-1's default this configuration trips CR-2 instead, correctly | posted | ✅ |
| **HB-4 (A)** | The offset probe traverse happens at a known height | HP-1 + `Probe X Offset` = `25` | posted | ✅ |
| **HB-4 (B)** | Absence sibling: a zero-offset job emits no extra lift, so (A)'s new block is attributable to the offset | HP-1, unchanged defaults | posted | ✅ |
| **HB-5 (A)** | A malformed probe `Safe Z` is loud in the file and at the dialog | HP-1 + group-6 `Safe Z` = `15mm` | posted | ✅ |
| **HB-5 (B)** | The dialog half covers the map-side field too, and it alone — the in-file warning is the probe side's | HP-1 + group-3 Safe Z = `15mm`, the mapper left **off**, its default | posted | ✅ |
| **HB-5 (C)** | Absence sibling for (A) and (B): a job whose Safe-Z fields parse says nothing about either | HP-1, unchanged defaults (both fields `Retract:15`) | posted | ✅ |
| **HB-6 (A)** | Retired with HB-6 — no code change, so there is nothing to post | — | — | ➖ |
| **HB-7 (A)** | A mistyped include filename refuses before any output | HP-1 + `Start GCode File` = `nofilename` | posted | ✅ |
| **HB-8 (A)** | The two one-way settings survive a second post in the same Fusion session | HP-1 posted twice without restarting Fusion: first with `Enforce Feedrate` on and `Include Whitespace` off, then both flipped | posted | ✅ |
| **HB-9 (A)** | A `>>> WARNING:` reaches the file at `Comment Level` = `Off`, and nothing else does | HP-1 + `Comment Level` = `Off` + `HB-3 (A)`'s group-4 combination | posted | ✅ |
| **HB-11 (A)** | Both blank separators read the same | HP-1, unchanged defaults — re-post of `HB-2 (A)`'s job after the fix | posted | ✅ |
| **HB-12 (A)** | A Stop file's XY arcs are not read in the plane the last lead-out left | HP-1 + `Stop GCode File` = `Arc Stop.txt`, a **complete** footer — it replaces the phase, so it owns the spindle prompt, the park and `M30` — whose motion includes `G2 X40 Y20 I10 J0` / `G3 X20 Y20 I-10 J0`, on a job whose final operation has a **Z lead-out** | posted | ✅ |
| **HB-13 (A)** | The operator is told, in the file and at the dialog, that the traverse and the probe target both depend on where they left the tool | `HB-3 (B)`'s configuration exactly, **posted twice, `Comment Level` `Info` then `Off`** — the level is the discriminator for half of what the row claims | posted | ✅ |
| **HB-14 (A)** | The warning reads as one property name plus one group, and still parses as a single GRBL comment | `HB-5 (A)`'s configuration | posted | ✅ |
| **HB-14 (B)** | The map-side twin emits the same shape, from the call site no artifact had ever reached | HP-1 + the mapper **on** + group-3 Safe Z = `15mm`, and — unplanned, decisive — group-6 `Safe Z` back to `Retract:15`, which makes this (A) with the two properties swapped | posted | ✅ |
| **HB-15 (A)** | The refusal tells the operator what to fix and claims nothing about a file | `HB-7 (A)`'s configuration exactly | posted | ✅ |
| **HB-16 (A)** | A `Start GCode File` cannot suppress the post's `G17`, because it replaced the block that writes it — the reading that redirected HB-16's second half. **And the post re-emitted the include's own `G18`**, so a word in a loaded file populates no modal | HP-1 + `Start GCode File` = `G18 Start.txt`, whose only g-code is `G18`, on `HB-2 (A)`'s job. Not a pre/post-fix pair: the fix is a no-op on this path, and the row exists to show *why* | posted | ✅ |
| **HB-17 (A)** | A job that *names* a fixed Z reference it cannot establish still gets HB-13's warning | HP-1 + **`CNC Firmware` = `Marlin`** + `Fixed Z Reference` = spoilboard + `Reserved WCS` = `G59` + `Inter Part Travel Z` = `40`, which that answer refuses to be unset + `First WCS / Part` = `Use Active WCS X0 Y0, Probe Z0`, single Setup. Marlin, so `HB-13 (A)`'s artifact cannot cover it — the suppression is the firmware's | posted | ✅ |
| **HB-18 (A)** | The Marlin base-establish warning keeps its parenthetical — the third call site of HB-14's defect | `HB-17 (A)`'s configuration exactly, posted **twice**, once pre-fix as a control and once after, so the read is a one-line diff. The re-post overwrote the control, so the pre-fix line survives only as this register's quotation of it | posted | ✅ |
| **HB-19 (A)** | HB-13's dialog warning stops recommending a remedy the firmware cannot deliver | `HB-17 (A)`'s configuration exactly. **Dialog only** — no artifact holds it, and the pre-fix reading is the operator's report on the `HB-18 (A)` post | posted | ✅ |
| **HB-20 (A)** | The one surviving control executes what all three executed when all three were on | The compared pair is *pre-fix, all three booleans `true`* against *post-fix, the one boolean `true`*. **No artifact, and the reason is a licence, not a shortcut:** exercising the mapper needs the F360 **Personal** edition, since that is what emits a travel as a `G1`, and the operator has no Personal licence now. Stubbing the `G0` input was offered and **declined** — it would prove the harness, not the post | **code walk** | ✅ |

### Expects

Every row here has passed, so every entry is a **result**: the artifact, the discriminator actually
checked, and **any trap a re-run would walk back into** — the only reason a passed entry keeps prose at
all. `check-docs.js` matches this heading by name and FAILs on a `✅` id whose entry is not a result.

- **HB-2 (A)/(B) — PASS, `HB-2 (A).gcode`**, the post-fix baseline every other row diffs against.
  `grep -c '%'` = 0; line 1 is `(Fusion CAM 2704.1.36)`. **Trap: `M30` is the last g-code *block*, with
  `( *** STOP end ***)` as the last *line* — the block is the criterion, never the line.**
- **HB-3 (A)/(B) — PASS.** `HB-3 (A).gcode` 114 carries the nothing-was-homed warning with no `$H`, `G28`
  or `G53` anywhere; `HB-3 (B).gcode` has `$H` at 114 in its place, a six-line diff. **Trap: (B)'s
  criterion is the absence of HB-3's own text, not a clean dialog** — at its configuration CR-2 warns by
  design and HB-13's warning fires on the mode `validateJob()` recommends by name, so "no dialog
  warning" reads as a false FAIL.
- **HB-4 (A) — PASS, `HB-4 (A).gcode`; (B) — PASS**, `HB-2 (A).gcode` as the absence half. 127-131 are the
  provisional `Z0`, the retract and `X25 Y0 F2500` — the lift **absolute, from the operator's own height**
  — and the two files differ **only** in that property, its Resolved-Values line and those four lines.
- **HB-5 (A)/(B)/(C) — PASS, all three, both channels.** (A) the `format error` warning at line **1** of
  `HB-5 (A).gcode`, with the probe retract the only motion that moves. (B) `HB-5 (B).gcode` holds **no**
  `format error` at all while the dialog warns — the two channels independent, and *it warns although the
  property is inert with the mapper off, which is the dialog loop covering both fields unconditionally
  rather than a false positive.* (C) `HB-2 (A).gcode`, neither.
- **HB-7 (A) — PASS.** No `.gcode` exists; the run left `HB-7(A).gcode.failed`, 51 bytes, holding only
  `!Error: Failed to post data. See log for details.` **The log locates the abort, which the absence alone
  cannot:** `Failed while processing onOpen().` — the pre-flight loop, where the pre-fix path reached
  `error()` from `loadFile()` at step 4 of `writeFirstSection()`.
- **HB-8 (A) — PASS both halves, `HB-8 (A)-1.gcode` / `-2.gcode`**, each a mechanically single-property
  delta from `HB-2 (A).gcode`. **The direction is the point:** both leaks were sticky one-way, so post 1
  setting the separator empty and `fOutput` forced is what post 2 had to shake off, and did. *All 26 `F`
  words in (2) were checked against the modal feed sequence, so `{ force: false }` is proved rather than
  merely un-leaked.*
- **HB-9 (A) — PASS, `HB-9 (A).gcode`.** `grep -c '^('` = **2**, the two warnings, with the whole of the
  header, property dump and commentary absent, and the 39 code lines byte-identical to `HB-2 (A).gcode`'s.
  `>>> Spindle Speed: Manual` goes while both `>>> WARNING:` lines stay — the bypass and the gate
  discriminating the same prefix inside one file. **Trap: the `^(` anchor is the criterion, not "the
  file's only `(` line"** — four `M0 (MSG …)` prompts correctly survive at `Off`, so six lines contain a
  `(` and the looser reading is a false FAIL.
- **HB-11 (A) — PASS**, `HB-2 (A).gcode` re-posted: `grep -c '^()$'` = 0, `^( )$` = **17**, the pre-fix
  count for the two forms combined, so the form changed and the number did not.
- **HB-12 (A) — PASS, `HB-12 (A).gcode`, and the discriminator was order.** 192 is the lead-out `G18 G2
  X182.797 Z-0.083 K4.997`, 197 `( *** STOP begin ***)`, **198 a bare `G17`**, 199 the include marker,
  204-205 the footer's two XY arcs, `M30` at 207 — the plane asserted after the last `G18` and before the
  loaded footer's first line. The diff against `HB-2 (A).gcode` is the property echo and the replaced stop
  phase, nothing else, so "a job whose arcs were all XY emits nothing" needs no absence half. **Two traps
  a re-run must not read as FAIL:** there is no `( *** STOP end ***)`, written inside the built-in branch
  only; and the footer's `G0 Z15.24` duplicates the section retract, a raw include bypassing the modals.
- **HB-13 (A) — PASS on both posts and the dialog.** `HB-13 (A)-off.gcode` is 42 lines, the warning at 7
  immediately above `G0 X0 Y0 F2500`, its **40 g-code lines byte-identical** to the `Info` file's —
  pre-fix that file said nothing at all about the height the traverse runs at. *(b) stays bounded by the operator's `G38 Target` and not by the post, deliberately:
  the only `G10 L20` is after the probe.*
- **HB-14 (A)/(B) — PASS at both call sites, and the two posts are exact complements** — `15mm` on the
  probe field then on the map field, so file *and* dialog each name the malformed property and stay silent
  about the valid one, in **both** directions. **Placement rather than wording attributes (B)** to the
  shared writer: `HB-14 (B).gcode` 146 sits inside `*** SECTION begin ***` where (A)'s is at line 1 above
  the header. *The per-section count is undiscriminated by a one-operation job; `onSection()` calls
  `safeZforSection()` unconditionally with no once-flag, settling it from source.*
- **HB-15 (A) — PASS at the dialog.** The text ends at `or clear the field.` and claims nothing about
  truncation — which the 51-byte `.failed` on disk would have contradicted. **`HB-7 (A)` stays ✅**: its
  discriminators were never the wording.
- **HB-16 (A) — PASS.** 159 is the first XY arc after the loaded header and carries its own `G17`; the file
  holds exactly two, so none precedes it — `Start()` was replaced, the modal was empty, the arc emitted its
  plane word unaided, and the include's own `G18` (118) is re-emitted at 154. The dialog is correctly empty,
  no `warning()` site being reachable here. **Trap: `G90`, `G21` and `G94` each count 0 — the include
  contract, not a defect**, since naming a Start file replaces the block that writes all four.
- **HB-17 (A) — PASS, `HB-17 (A).gcode`, and the discriminator held two lines apart.** 122 is
  `reserved base G59 ignored on Marlin …` from the establish that did not happen and 124 is HB-13's
  unknown-Z warning on the traverse that did: pre-fix the first appeared while the second was suppressed
  *by* the answer the first had just declared void. `grep -c G53` = **0**, the spoilboard answer's hole and
  not the machine-Z answer's; `grep -c '( >>> WARNING'` = 0 against three `;` forms, the dialect switch
  rather than a miss.
- **HB-18 (A) — PASS.** 122 is `; >>> WARNING: reserved base G59 ignored on Marlin -- no per-WCS registers,
  single global frame`, `cat -A` ending it `frame$`. Both Marlin posts came back **318 lines, the pre-fix
  control's own count**, with 124, 153 and the two `grep` zeros unchanged, so nothing but 122's text moved.
- **HB-19 (A) — PASS at the dialog, on both posts.** The second warning ends `… from that start height.
  Marlin has no fixed Z reference this post can establish, so that start height is yours to set.` and
  opens word for word as before. **Trap: CR-2's warning is beside it, byte-identical to the pre-fix
  report** — `Axes Homed and Trusted` is `None`, so it fires on its own merits and a flat "one warning"
  criterion reads this PASS as a FAIL.
- **HB-20 (A) — PASS by code walk, the one ✅ here with no artifact behind it.** Four reachable sites,
  walked with all three booleans `true` on the left and the one boolean `true` on the right.
  `safeZforSection()` and `isSafeToRapid()`'s own gate test the surviving property and are untouched, so
  `safeZHeight` resolves identically and both `zSafe` comparisons use the same threshold. **The branch
  chain is value-identical, not merely equivalent:** `&&` returns its right operand when the left is
  truthy, so pre-fix `getProperty(allowZ) && zUp && xyConstant` *evaluated to* `zUp && xyConstant`.
  **Short-circuiting cannot hide a difference, which is the load-bearing half:** `zConstant`, `zUp`,
  `xyConstant` and `curZSafe` are `let`-bound **above** the chain from pure `roundTo()` reads,
  `getCurrentPosition()` is called once, and the last `Debug` comment precedes it — so dropping a conjunct
  skips no computation, no call and no output. `onLinear()` reduces on both sides to
  `if (forceSectionToStartWithRapid == true)`, so the `else if (isSafeToRapid(…))` arm is reached in
  exactly the same cases. Outside the motion: the group-3 dump loses two lines — keeping `master` before
  `safeZ`, since the dump sorts by `order:` and 10 preceded 20 pre-fix too — and a malformed Safe Z quotes
  the shorter title. **Trap: this does not claim that no configuration changed.** Two did, both named in
  the finding before the edit — master on with `Allow Rapid Z` off now converts Cases 2 and 3, and master
  off with first-rapid on has no successor. It is an identity proof for *one* pairing.

---

## Checked and found correct

`posted` readings of `HB-2 (A).gcode` that no row claims, kept only where re-raising them is the risk.
Each retires when a row asserts it or when the artifact it names is superseded.

- **Motion words are omitted on seven lines (153, 154, 155, 162, 175, 182, 201) and every one is a correct
  rapid or feed.** The file's most alarming-looking feature, and it is right: `gMotionModal` is
  `createModal({})` **only** on the GRBL branch and `createModal({force: true})` on Marlin/RepRap, so a
  bare axis line can never reach a firmware that lacks modal motion — Marlin's `GCODE_MOTION_MODES` is off
  in stock `Configuration_adv.h`. **Recorded so it is not re-raised**, as HB-1 and HB-6 were.
- **`G38.2` is not left modal.** `G0 Z5.08` after the probe is **explicit**, which it must be: `G38.2` is
  modal group 1, so a bare `Z5.08` there would have been a second probe.
- **`Scale Feedrate` clamps per axis.** The XZ lead-in/out arcs take `F180` (`Max Cut Speed Z`), the XY
  cuts `F900`, travels `F2500`/`F300`. The arcs are the discriminator: a 45° XZ arc at the `F1000` XYZ
  limit would drive Z at ~636 mm/min, 3.5× its limit, so clamping the whole path to the Z figure is the
  conservative answer and it is what the file does.

---

## Owed

- **It owes no post. Sixteen artifacts across two sessions ran twenty-two of the twenty-three live rows,
  and every one passed on first read** — no row was ever marked ❌. **One finding is still open, HB-10**,
  deferred to the professional pass by its own row because the dead property it names is group-7 work
  either way. *`HB-18 (A)` and `HB-19 (A)` were the only rows whose fix shipped ahead of them, and one
  re-post of `HB-17 (A)`'s job cleared both.*
- **`HB-20 (A)` is the one ✅ with no artifact behind it, and the distinction is kept rather than blurred.**
  Its Method cell reads `code walk` so the two kinds of pass stay greppable. The mapper only has work to do
  on an F360 **Personal** job, and **stubbing the `G0` input was offered and declined**, on the ground that
  it would prove the harness rather than the post — the same objection that kept HB-13's relative lift out
  of the code. **Its dialog and dump halves need no Personal seat**, so the next post of any job
  corroborates them for free; noted as available, not as owed.
- **The build under test is `e5db625` exactly, by file identity rather than by inference.** The `.cps`
  Fusion posts from is byte-identical to this repo's working copy (MD5 `974EA5A1…`) and the working tree's
  only modified file was this register, so that copy *is* `e5db625`, the newest commit to touch the post.
  Every surviving session log reports one `Checksum of configuration`, `e3195f88…`, and one
  `Configuration modification date` stamped before the first post and unchanged through the last. *Both the
  logs and the `Gcode generated:` headers run +7 h from the filesystem: the 10:21–11:42 and 17:21–18:42
  spans quoted in these documents are the same six posts.*
- **`.cps` line numbers are gone from this register on purpose.** Every source citation is by function or
  property name, which is what a reader can still find: the numbers drifted under every commit, two passes
  paid to renumber thirteen and then nineteen of them, and a set of older ones was confirmed wrong before
  either pass. `.gcode` and `.log` line numbers stay — those are evidence in saved files and do not move.
- **HB-13 (b) has an answer, and the baseline artifact shows it working.** `HB-2 (A).gcode` 125-127 is the
  sibling mode doing exactly this — `G10 L20 P1 X0 Y0 Z0` under "Provisional Z0 at the current height so
  the probe target is a relative limit" — and the `Z`-only form is separable here precisely because this
  mode exists to keep the stored `X0 Y0`. **So (b) is an asymmetry between two adjacent modes rather than
  an open question**, trading an unbounded descent for one that fails by *alarming*; withheld because the
  decision is recorded at the code and group 6 belongs to another pass.
- **Five of the twenty findings were discovered by posting rather than by reading — HB-13, HB-14, HB-15,
  HB-18 and HB-19 — and every one of the five is operator-facing text.** HB-13 (a) sits on a configuration
  the post's own dialog recommends by name and four reading passes went past it; HB-14 was invisible for
  the opposite reason, the criterion that should have caught it asking for the broken form; HB-15 is the
  string HB-7's own fix wrote; and HB-18 and HB-19 came out of a post aimed at HB-17. **Nothing in a source
  review reads a warning as prose**, and these five are what that costs.
- **The geometry guards' half of "a rejected job leaves no file" is still owed.** HB-7's include check now
  refuses before any output, but the multi-axis and orientation guards still fire in `onSection()` and
  still leave a truncated `.gcode` — `HR-27`, unstarted, and the general fix is moving them rather than
  duplicating the check. `HB-7 (A)` needs no re-post to pair with that row: the identical-build proof above
  lets a later artifact stand beside it.
- **HB-16's include half is fixed where no row here can watch it** — the tool-change files, group 7, which
  already carries HB-10 / `HR-21` / `CR-15`. **And groups 7, 9 and 11 were not walked at all:** a hobbyist
  doing a manual tool change or running a diode laser is an ordinary case covered by no row here.
