# HReview — hobbyist review of `MPCNC_v4.0_Beta2.cps`

The hobbyist-side findings register and test register. **44 findings** — 27 `HR-` from the hobbyist
review, 17 `CR-` from the 2026-08-01 whole-file review. All are fixed, closed by design, or moved to
`docs/PReview.md`, except three one-liners awaiting a tidy-up sweep and one unstarted robustness fix
(HR-27). Nothing is failing.

Reasoning, diffs and session narratives were trimmed 2026-08-01 — read the code and the commit messages
for *why*. What is kept is what a later reader needs: every issue with its status, and every test with
enough to set it up and run it again.

**How to run a test, the personas, and the method notes now live in `conventions.md`** — they govern this
register and `PReview.md` alike, so they sit in one place rather than in whichever file happened to hold
them.

> **Standing rule.** A change to the `.cps` touching hobbyist behaviour updates this file **in the same
> commit**: add the Do→Get row, name the discriminator, and flag any row whose saved `.gcode` it
> invalidates. Professional behaviour → `PReview.md`. A stale PASS is worse than an unrun test.
>
> **And the other half — compress on close.** When a finding reaches FIXED or closed-by-design, the same
> commit deletes its long form and leaves the register row. The buggy code, the diagnosis and the diff
> are all in `git show <commit>`. Long form is a promissory note, justified only while work is unbuilt.

---

## Findings — HR-1 … HR-27 · CR-1 … CR-17

`HR-` came from the hobbyist review; `CR-` from the 2026-08-01 whole-file review driven by the dialog and
the F360 API. Both registers merged here on the same terms — ids kept, so every commit message and code
comment that names one still resolves.

| ID | Finding | Sev | Resolution | Status |
|---|---|---|---|---|
| **HR-1** | `G38 Target` was an absolute Z in a frame whose Z0 is stale, on the default probe path | High | Provisional `Z0` on the two just-positioned modes only; gated on `canProbe`. **Scope is deliberate:** the frame-dependence remains open for the `Use Active WCS`, added-part and base probes, which descend from a retracted clearance and would be made **worse** by the same fix. Added-part symmetry is an open question — `PReview.md` **M4** | ✅ fixed `8d61790` |
| **HR-2** | `isProbeOperation()` undefined — any drilling operation could abort the post | High | Defined locally, two signals (strategy + `cycleType` prefix). ⬜ **Open question:** keep the extra breadth, or trim to the strict reference form? Two signals catch more than the reference post does, at the cost of possibly refusing an operation it would accept | ✅ fixed `9c87fb0` |
| **HR-3** | GRBL + Manual Spindle never prompted to switch the router **off** | High | `spindleOff()` branches on the property first, firmware inside | ✅ fixed `43d09aa` |
| **HR-4** | Safe-Z fallback constants never converted mm → output unit | Med-High | Four call sites converted; inch only, identity in mm | ✅ fixed `439ce2d` |
| **HR-5** | `Scale Feedrate` did not apply to G2/G3 arcs | Med-High | `limitArcFeed()` caps at the arc's **plane's** axis limits | ✅ fixed `b95c954` |
| **HR-6** | No tool-orientation guard — a rotated 3-axis Setup posted silently wrong g-code | Medium | `isSectionOrientationSupported()`, component-wise, **fails open**, ~0.006° | ✅ fixed `684f28a` `e2b2424` |
| **HR-7** | `toolChange()` clobbers `forceSectionToStartWithRapid` | Medium | → `PReview.md` §2 — Tool Change branch | ➖ moved |
| **HR-8** | Post-injected motion never updates Fusion's tracked position | Medium | → `PReview.md` §2. Confirmed unreachable on any hobbyist path (2026-08-01) | ➖ moved |
| **HR-9** | `Do First Change` + probe-after off zeroes Z against the wrong tool | Medium | → `PReview.md` §2 | ➖ moved |
| **HR-10** | `Disable Z Stepper` emits Marlin-only `M84 Z` on GRBL | Medium | → `PReview.md` §2 — has a complete diff | ➖ moved |
| **HR-11** | Marlin/RRF jobs never ended and left every stepper energised | Medium | `M84 S60` both; `M2` on RepRap only (Marlin has never implemented it). **`S60`, not a bare `M84`, deliberately** — a 60-second idle timeout rather than releasing the steppers at once, which would drop Z on an unbalanced LowRider gantry | ✅ fixed `7a35f7f` `8054b6e` |
| **HR-12** | A manual spindle is never told about an RPM change between operations | Medium | Prompt on formatted-speed **or** direction change | ✅ fixed `dd8e11d` |
| **HR-13** | `onCommand` silently discards every command it does not name | Low-Med | → `PReview.md` §2 — has a complete diff | ➖ moved |
| **HR-14** | Two coolant modes could never match a channel | Low | `coolantLevels` derived from `eCoolant` | ✅ fixed `7e38777` |
| **HR-15** | `safeZforSection()` mixed global `hasParameter()` with `_section.getParameter()` | Low | All three guards read `_section.` | ✅ fixed `88c7817` |
| **HR-16** | `onClose` traverses to X0 Y0 before stopping the spindle, no guaranteed safe Z | Low | **Spindle-order half fixed** 2026-08-01 (CR-6). **Z half still open** → `PReview.md` §5 | ◑ part-fixed |
| **HR-17** | Four tidy-ups; two change emitted text | Cosmetic | Sanitizer double-spaces, group-03 rename, vestigial arg, empty GRBL block | ✅ fixed `924d1f6` |
| **HR-18** | `loadFile()` left no line break after an include — the next block merges | Medium | Repair in `loadFile()`; `\r` counts as a terminator | ✅ fixed `5b0b94a` |
| **HR-19** | `M291` doubled space; `()` vs `( )` on empty comments | Cosmetic | `()` **closed as by design** (CR-17b). The `M291` space remains — next sweep | ⬜ open |
| **HR-20** | Tapping is not really implemented | Medium | → `PReview.md` — manual path now prompts (HR-12); automatic path always emitted `M4` | ➖ moved |
| **HR-21** | `E_Include_ProbeFile` declared but never read — dead property | Low | Tooltip now says `NOT IMPLEMENTED YET`. Wire into `probeTool()` or delete — undecided | ⬜ open |
| **HR-22** | An include file that exists but is **empty** contributes nothing, silently | Medium | **(A)** empty include now announces itself ✅. **(B)** empty Start include leaves no preamble — **closed as by design** 2026-08-01 (CR-7): the include owns the phase | ✅ closed |
| **HR-23** | A Start/Stop include *replaces* the whole preamble/footer | — | **Designed behaviour.** Filed as a defect and resolved as correct the same day. Lesson: before calling a bypass a defect, ask whether the bypass is the feature | ✅ closed |
| **HR-24** | `writeWCS(section)` takes a section then consults the global `tool` | Low | Latent (both callers pass `currentSection`). One line: `section.getTool()` — next sweep | ⬜ open |
| **HR-25** | `wcsGcode(0)` / `wcsName(0)` yield `G53` | Low | **Closed as by design** 2026-08-01 (CR-17d): a pure conversion should not carry frame policy; no caller can pass 0 | ✅ closed |
| **HR-26** | Base-clearance retract has no jet guard though the base *establish* does | Medium | → `PReview.md` §3.4 — jet + multi-WCS + base | ➖ moved |
| **CR-1** | `$H` went through `writeBlock()`, so `Enable Line #s` emitted `N10 $H` and GRBL rejects it | High | `writeln()` — `$` must be the line's first character | ✅ fixed `c73726c` |
| **CR-2** | Homing moves the tool, then a `Current Pos` origin mode records the **homing corner** as the part origin | High | Post-time `warning()` in `validateJob()` | ✅ fixed `c73726c` |
| **CR-3** | A required tool change dropped in complete silence when group 07 is off (the default) | Med-High | `>>> WARNING` per boundary + `validateJob()` warning via `countDistinctTools()`, counted over **sections** | ✅ fixed `c73726c` |
| **CR-4** | Coolant `Use custom` wrote the property text as g-code; tooltip and README call it a **file** | Medium | `writeCustomCoolantFile()` → `loadFile()`; warns when named but empty | ✅ fixed `c73726c` |
| **CR-5** | A jet/laser job on the default First-WCS mode never established **Z0** at all | Medium | `Important` warning; the XY-only origin write is unchanged | ✅ fixed `c73726c` |
| **CR-6** | `onClose()` traversed to X0 Y0 **before** stopping the spindle | Medium | Spindle stops first. **Z retract deliberately not added** — that half stays open as HR-16 → `PReview.md` §5 | ◑ part-fixed |
| **CR-7** | A Start include substitutes for `G90`/`G21`/`G94`/`G17`, so the job inherits unknown modal state | Medium | **By design** — an include owns the phase it names. Same rule as HR-23 / HR-22 (B) | ✅ closed |
| **CR-8** | Feed scaling could **raise** a feedrate on a zero-length move, against its documented contract | Low-Med | Clamped; harness-verified against both the working tree and `HEAD` | ✅ fixed `c73726c` |
| **CR-9** | An unrecognised jet mode left the laser power `undefined` → `S NaN` | Low | Explicit branch | ✅ fixed `c73726c` |
| **CR-10** | GRBL laser mode passed the enum's **string** id into `mFormat.format()` | Low | Explicit `Number()`. Group 09 still has no posted evidence — `PReview.md` J4 | ✅ fixed `c73726c` |
| **CR-11** | `roundTo()` returned `NaN` for any value JS renders in exponential notation | Low | Plain arithmetic replaces the string-exponent trick; harness-verified | ✅ fixed `c73726c` |
| **CR-12** | `probeTool()` wrote `F`/`Z` through the raw formats, desynchronising `fOutput`/`zOutput` | Low | No behaviour change — `resetAll()` documented as **load-bearing** | ✅ fixed `c73726c` |
| **CR-13** | `onOpen()` reset 2 of ~14 mutable module globals | Low | `resetPostState()` — all 18, one function | ✅ fixed `c73726c` |
| **CR-14** | The `properties` literal was declared out of the dialog order it promises | Low | Pure move, proved by sorted-line checksum. Keep new properties in dialog order | ✅ fixed `c73726c` |
| **CR-15** | `Tool Change Probe` is a dialog field wired to nothing | Low | The same defect as **HR-21** — wire into `probeTool()` or delete, undecided | ⬜ open |
| **CR-16** | `Use Active WCS X0 Y0 Z0` called a move a "retract" when it can descend | Low | Comment + tooltip corrected | ✅ fixed `c73726c` |
| **CR-17 (a)** | `Retract the tool to 5.080000000000001` — a raw JS number in a comment | Cosmetic | Formatted | ✅ fixed `c73726c` |
| **CR-17 (b)** | Section separator is an empty comment `()`, not a blank line | Cosmetic | **By design** — the separator is comment-level-gated on purpose. Closes HR-19's `()` half | ✅ closed |
| **CR-17 (c)** | `feedFormat` declared and never used | Cosmetic | Deleted | ✅ fixed `c73726c` |
| **CR-17 (d)** | `wcsGcode(0)` returns `G53` against the standing "never `G53`" rule | Cosmetic | **By design** — a pure conversion carries no frame policy, and no caller can pass 0. Same as HR-25 | ✅ closed |
| **CR-17 (e)** | `sectionComment` printed `undefined`, or inherited the previous operation's name | Cosmetic | Fixed in `onSection()`/`onSectionEnd()` | ✅ fixed `c73726c` |
| **HR-27** | The two **geometry** guards fire in `onSection()`, not `onOpen()`, so a rejected job can leave a **truncated `.gcode` on disk** | Medium | Guards A/B/C run before any output, so they write no file; multi-axis and HR-6's orientation check do not. A hobbyist who builds a Setup on a model face gets a partial file rather than a clean refusal. Fix: promote both into `validateJob()`. Not started | ⬜ open |

**Open, no fix:** HR-19 (`M291` space), HR-21 / CR-15 (one decision, two ids), HR-24 — a tidy-up sweep of
one-liners, none changing output today. Plus **HR-27**, which is not a one-liner and is not in that sweep.
Everything else is fixed, closed by design, or moved.

**Open questions carried in the rows above:** HR-1 (added-part provisional `Z0` — settle on `PReview.md`
M4), HR-2 (guard breadth), HR-16 / CR-6 (jet Z retract — `PReview.md` §5), HR-21 / CR-15 (wire or delete).
Professional ones live in `PReview.md` §6.

**Nothing found by either pass breaks the factory-default single-operation job.** Every High/Medium
finding needed the operator to move one dialog field off its default — but each of those is a field the
README tells a hobbyist to consider.

---

## Test register — 88 rows

**✅ 67 PASS · ❌ 0 FAIL · ⬜ 5 UNRUN · ➖ 16 n/a or moved — 88 rows.** Complete by construction: every `H`/`HR`/`HW`
id has a row, including the ones that belong to another file. **If you move a finding out, leave the
pointer row behind.** `CR-` ids are exempt — most are cosmetic or by-design closures that were never
separate tests. `docs/check-docs.js` enforces the tally, the completeness and the exemption.

| Test | Proves | Setup (delta from defaults) | Expect — *discriminator in bold* | Method | Evidence | State |
|---|---|---|---|---|---|---|
| **H1** | `Jog to X0 Y0, Probe Z0` | First = `Jog to X0 Y0, Probe Z0` | `M0 (MSG Jog to X0 Y0 above Z0, probe)` → `G10 L20 P1 X0 Y0 Z0` → `G38.2 F30 Z-10` → `G10 L20 P1 Z0.8` → `G0 Z5.08` | posted | `H1.gcode` | ✅ |
| **H2** | Default mode, the whole hobbyist path | all defaults | no jog prompt; origin write → probe → `G10 L20 P1 Z0.8` | posted | `H2.gcode` — **retired as a baseline** (pre-HR-17); use `H11c` | ✅ |
| **H3** | `Jog to X0 Y0 Z0` | First = `Jog to X0 Y0 Z0` | jog `M0` → `G10 L20 P1 X0 Y0 Z0`; **no `G38.2`** | posted | `H3.gcode` | ✅ |
| **H4** | `Set X0 Y0 Z0 to Current Pos` | First = that | `G10 L20 P1 X0 Y0 Z0`; **no prompt, no probe** | posted | `H4.gcode` | ✅ |
| **H5** | `Use Active WCS X0 Y0 Z0` | First = that | `G0 Z5.08` → `G0 X0 Y0`; **no origin write** | posted | `H5.gcode` | ✅ |
| **H6** | Marlin + RRF variants of H1 | H1 + firmware Marlin, then RepRap | `; …` comments; Marlin `G92`; RRF `G54` + `G10 L20 P1` + `M291 … S3 X1 Y1 Z1`. **No multi-WCS warning** on a single-op Marlin job | posted | `H6 - Marlin.gcode`, `H6 - RRF.gcode` | ✅ |
| **H7** | `Use Active WCS X0 Y0, Probe Z0` | First = that | **absence of `G10 L20 P1 X0 Y0`** — the only `P1` write is the probe's `Z0.8` | posted | `H7.gcode`, `H7a.gcode` | ✅ |
| **HR-1 (A)** | Provisional `Z0` on the default mode | all defaults | `( Provisional Z0 at the current height …)` → `G10 L20 P1 X0 Y0 **Z0**` before `G38.2` | posted | `H2.gcode` | ✅ |
| **HR-1 (B)** | Same on the jog mode | H1 config | identical, after the jog `M0` | posted | `HR1b.gcode` | ✅ |
| **HR-1 (C)** | **Absent** on `Use Active WCS` — the scope claim | H7 config | no provisional `Z0`, no comment; **motion byte-identical** to the pre-HR-1 reference | posted | `HR1c.gcode` vs `H7c-a.gcode` | ✅ |
| **HR-1 (D)** | Jet / tool-0 absence | — | → `PReview.md` **J1** | — | — | ➖ |
| **HR-1 (E)** | Both firmwares, both origin modes | Marlin + RRF, default and jog | the `Z0` word present on the pre-probe origin write in **all four** files | posted | `H11a`, `H11b - RRF`, both `H6` | ✅ |
| **HR-2 (A)** | A drill posts at all | CAM = peck drill | **a file exists and reaches `( *** STOP end ***)`**; no `G81`/`G82`/`G83`/`G73` anywhere | posted | `Drill_Tap.gcode` | ✅ |
| **HR-2 (A2)** | Tapping warning per occurrence | CAM = drill + tap, 4 holes | **8** warnings, single-spaced | posted | `Drill_Tap.gcode` | ✅ |
| **HR-2 (B)** | Probing cycles still refused | — | not creatable — needs the Machining Extension | — | licence | ➖ |
| **HR-2 (U)** | `isProbeOperation()` over 8 inputs | node | `probe`, `probing-*` → true; `drilling`/`tapping`/`boring`/absent → false | harness | node | ✅ |
| **HR-3 (A)** | GRBL prompts spindle OFF | all defaults | `M0 (MSG Turn OFF spindle)` present; **no `M5`, no `M300` anywhere** | posted | `H2.gcode` — ⚠ order restated by CR-6 | ✅ |
| **HR-3 (B)** | Automatic branch untouched | `Manual Spindle On/Off` = **false** | `M3 S<n>` at start, `M5` in the stop block, **no prompts anywhere** | posted | `HR3b.gcode`, `Face1 (auto).gcode` | ✅ |
| **HR-3 (C)** | Tool-change half | — | → `PReview.md` §3.4 | — | — | ➖ |
| **HR-3 (D)** | Marlin/RRF unchanged; only GRBL moved | Marlin + RRF | `M300 S300 P3000` then the prompt; **no bare `M5` in any of the six files** | posted | six session-1 files | ✅ |
| **HR-4 (A)** | Inch: bare-number probe Safe Z converts | **inch**, `06` Safe Z = `20` | `G0 **Z0.7874**`, not `Z20` | posted | `H4a - GRBL Inch.gcode` — ⚠ comment reformatted by CR-17a | ✅ |
| **HR-4 (B)** | mm: identity, no reference invalidated | mm, `06` Safe Z = `20` | differs from `H11c` in **5 lines only**; `G0 Z20` | posted | `H4b - GRBL.gcode` | ✅ |
| **HR-4 (C1)** | Inch: the mapper's threshold converts | inch, group 03 all on, Map Safe Z = `20` | `( SafeZ using const: 0.7874…)` — pre-fix it read `20` | posted | `H4c - GRBL Inch.gcode` | ✅ |
| **HR-4 (C2)** | The mapper then actually converts | `Personal.cps`, group 03 on | conversions fire at the 5.08 threshold | harness | `Link-5-GRBL`, `Link-15-GRBL` | ✅ |
| **HR-4 (D)** | Header never mixes mm and inch | inch, all defaults | both Safe-Z lines read `fallback 0.5906, resolves to 0.2`, beside `Inter Part Safe Z … = 1.5748` | posted | `H4base - GRBL Inch.gcode` | ✅ |
| **HR-4 (U)** | 5 expression forms × 2 units | node | `Retract:15` abs → `5`/`0.2`; relative or absent → `15`/`0.5906`; `20` → `20`/`0.7874`; malformed → `15`/`0.5906` | harness | node | ✅ |
| **HR-5 (A)** | Arcs capped at the plane's axis limits | face-mill CAM, `Scale Feedrate` on, 900/180/1000 | every `G17` arc **`F900`**, matching the `G1`s either side | posted | `HR5a.gcode` | ✅ |
| **HR-5 (B)** | Unscaled baseline | same, scaling **off** | arcs at Fusion's raw `F2667`/`F1016` | posted | `HR5b.gcode` | ✅ |
| **HR-5 (C)** | `Max Toolpath Speed` caps arcs too | + Max Toolpath Speed = `500` | the same arcs and lines read **`F500`** | posted | `HR5c.gcode` | ✅ |
| **HR-5 (D)** | Non-XY (`G18`) arc limited by the slower axis | same job — a face mill's helical lead-in *is* a ZX arc | `G18 G3 X… Z… I… **F180**` | posted | `HR5a.gcode`, `H11c - GRBL.gcode` | ✅ |
| **HR-5 (E)** | Marlin: linearized segments limited like any `G1` | Marlin, `Scale Feedrate` on | **no** cut move exceeds an axis limit; 122 do in the scaling-off file | posted | `H5d - Marlin.gcode` vs `H11a.gcode` | ✅ |
| **HR-6 (A)** | The guard is live, not failing open | Comment Level **Debug** | `( onSection orientation: forward X0 Y0 Z1, tilt … 0 deg -> upright, section allowed)`. **`UNREADABLE` would mean the guard is dead code** | posted | `H2 - Debug.gcode` | ✅ |
| **HR-6 (B)** | An off-axis section is actually rejected | node, 13 forward vectors | ≤0.001° allowed; 0.01°/1°/45°/90°/180° **REJECTED**; missing/`NaN`/string components allowed; **nothing throws** | harness + read | node. ⚠ **residual: needs a rotated Setup** — Fusion may re-express `forward` as `Z1` anyway, making the guard a no-op on the case it exists to catch | ✅ |
| **HR-7** | `toolChange()` clobbers the first-rapid flag | — | → `PReview.md` §2 | — | — | ➖ |
| **HR-8** | Post-injected motion never updates tracked position | — | → `PReview.md` §2 | — | — | ➖ |
| **HR-9** | `Do First Change` zeroes Z on the wrong tool | — | → `PReview.md` §2 | — | — | ➖ |
| **HR-10** | `Disable Z Stepper` emits `M84 Z` on GRBL | — | → `PReview.md` §2 | — | — | ➖ |
| **HR-11 (A)** | Marlin: `M84 S60`, no `M2` | Marlin, defaults | tail `M400` → `M117 Job end` → `M84 **S60**`; **no `M2` anywhere**. `M84 S0` still once, at the top | posted | `H11a.gcode` | ✅ |
| **HR-11 (B)** | RepRap: `M2` after `M84 S60` | RepRap, defaults | identical tail **plus `M2`**. Present here / absent in (A) is the discriminator | posted | `H11b - RRF.gcode` | ✅ |
| **HR-11 (C)** | GRBL tail untouched | defaults | `M0 (MSG Turn OFF spindle)` … `M30` → `%`; **no `M84` at all**, no `M2` | posted | `H11c - GRBL.gcode` — ⚠ order restated by CR-6 | ✅ |
| **HR-11 (D)** | Stop file bypasses the whole stop block | Marlin + `B_Include_StopFile` = `Stop File.gcode` | `M117 Job end`, `M84 S60`, `M2`, `M30` and `*** STOP end ***` **all absent** | posted | `H11d - Marlin.gcode` | ✅ |
| **HR-11 (S)** | Whether Marlin / RRF honour `M2` | firmware source | Marlin: never implemented (`gcode.cpp` has no `case 2`). RRF: since 3.5.1, runs `stop.g` | source | `gcode.cpp`, `GCodes2.cpp`, RRF changelog | ✅ |
| **HR-12 (A)** | Prompt on an RPM change between operations | 2-op 1-tool CAM, 12000 → 10000 | `Turn ON 12000 RPM` then `( >>> Spindle Speed: Manual change)` → **`M0 (MSG Set spindle to 10000 RPM clockwise)`** | posted | `Speed Change.gcode` vs `Link.gcode` | ✅ |
| **HR-12 (A2)** | Two operations at the *same* RPM → one prompt | same CAM, op 2 also 12000 | **one** prompt, no `Manual change` line. Only meaningful posted beside (A) | posted | `Speed Change (No Change).gcode` | ✅ |
| **HR-12 (A3)** | Every tapping reversal announced | drill + tap CAM, defaults | **9 prompts total**, 8 in the tap section, strictly alternating from `clockwise`. **12 direction commands but only 8 prompts** — the post prompts on *changes*, not commands | posted | `Drill_Tap.gcode` | ✅ |
| **HR-12 (A4)** | A counterclockwise start names the direction | needs a left-hand tap / CCW tool | `M0 (MSG Turn ON <n> RPM counterclockwise)` | read | 4-hop chain, no branch drops it. ⚠ **artifact does not exist** | ✅ |
| **HR-12 (A5)** | A clockwise start is unchanged | any single-op manual job | `Turn ON <n> RPM` with **no direction word**, byte-identical across the fix | posted | `Speed Change.gcode` | ✅ |
| **HR-13** | `onCommand` discards unnamed commands | — | → `PReview.md` §2 | — | — | ➖ |
| **HR-14 (A)** | `Flood and Mist` matches a channel | drill CAM; tool coolant *Flood and mist*, Ch A Mode = **Flood and Mist** | `( >>> Coolant Channel A: Flood and Mist)` → `M7`, `M9` at the end, **no warning** | posted | `Drill Flood Mist.gcode` | ✅ |
| **HR-14 (B)** | The warning names the mode the operator saw | same, Ch A Mode = **Off** | `( >>> WARNING: No matching Coolant channel : **Flood and Mist** requested)` — not `FloodMist`, not `unknown` | posted | `Drill Flood Mist (No).gcode` | ✅ |
| **HR-14 (C)** | Ordinary `Flood` unchanged | tool Flood, Ch A Flood | `Channel A: Flood` → `M7` → `M9`, no warning | posted | `Drill Flood.gcode` | ✅ |
| **HR-14 (D)** | Channel B, and selection is per-channel | tool Mist; Ch A Flood + Ch B Mist, then Ch B Off | B lights (`M8`) or warns; **A stays silent both times — no `M7`** | posted | `Drill Mist.gcode`, `Drill Mist (no Mist).gcode` | ✅ |
| **HR-14 (U)** | All 9 coolant indices, before and after | node | **7/9 → 9/9** matching | harness | node | ✅ |
| **HR-15 (A)** | Mapping-on changes nothing but one comment | group 03 all **on** | vs `H11c`: **5 lines** differ — timestamp, 3 property values, 1 added comment. No motion | posted | `H15a - GRBL.gcode` | ✅ |
| **HR-15 (B)** | The level branch is taken, not the fallback | same | that added line is **`( SafeZ retract level: 5.08)`**, not `not defined` | posted | `H15a - GRBL.gcode` | ✅ |
| **HR-16** | `onClose` traverse ordering | — | spindle-order half fixed (CR-6); Z half → `PReview.md` §5 | — | — | ➖ |
| **HR-17 (A)** | Property heading no longer double-spaced | any post | `Properties -- 03 - Map G1s to Rapids - disable when using full license:` | posted | six session-1 files vs `H2.gcode` | ✅ |
| **HR-17 (B)** | Spindle prompt reads `… RPM` | any manual-spindle post | `Turn ON 7000 RPM` — the **space** is the assertion | posted | same | ✅ |
| **HR-17 (C)** | Tapping warning single-spaced | tap CAM | no match for `synchronization  rigid`, `tapping  is` or `WARNING:  ` | posted | `Drill_Tap.gcode` | ✅ |
| **HR-17 (D)** | The two inert tidy-ups changed nothing | defaults | `H11c` vs `H2` differs in **4 lines**; no motion, feed or ordering | posted | `H11c - GRBL.gcode` vs `H2.gcode` | ✅ |
| **HR-17 (U)** | Sanitizer before/after over 4 input shapes | node | interior doubles gone; leading/trailing whitespace byte-identical | harness | node | ✅ |
| **HR-18 (A)** | Stop include: the next block is not merged | Marlin + a stop include whose **last byte is not a newline**, Comment Level **`Important`** | last block and `M400` on **separate lines**. On GRBL the merge is `M5%`, not `M5M400` — `flushMotions()` returns early there | read | ⚠ needs a post; `Stop File.gcode` already qualifies | ✅ |
| **HR-18 (B)** | Start include: the origin write is not merged | Start include, Comment Level **`Important`** | the include's last block and `G10 L20 P1 X0 Y0 Z0` on **separate lines**. Worse than (A) — it destroys the origin write | read | ⚠ needs a post | ✅ |
| **HR-18 (T)** | Tool-change includes | — | → `PReview.md` §3.4 | — | — | ➖ |
| **HR-18 (U)** | The guard over 6 file endings × 3 comment levels | node | **4 merged blocks → 0**. Terminated files byte-identical. The two `Info` "ok"s pre-fix are the finding in miniature | harness | node | ✅ |
| **HR-19** | `M291` doubled space; `()` vs `( )` | — | `()` closed by design; `M291` space open, next sweep | — | — | ➖ |
| **HR-20** | A fuller tapping implementation | — | → `PReview.md` | — | — | ➖ |
| **HR-21** | `E_Include_ProbeFile` is dead | — | tooltip declares it; wiring undecided | — | — | ➖ |
| **HR-26** | Base-clearance retract has no jet guard | — | → `PReview.md` §3.4 | — | — | ➖ |
| **HR-22 (A)** | An empty include announces itself | a zero-byte include file, Comment Level `Info` | `( --- Custom gcode file is empty, nothing included <path>)`; **absent above `Info`** | harness | node | ✅ |
| **HR-22 (B)** | An empty Start include leaves no preamble | — | **closed as by design** — the include owns the phase (CR-7) | read | — | ✅ |
| **HW-1** | `isSafeToRapid()`'s three conversion branches | `Personal.cps`, group 03 all on, Map Safe Z = `Retract:15` then `15` | **74 conversions → 2** on identical geometry; all three cases fire at 5.08; **all 17,779 genuine cut moves stay `G1`**. Traps: `grep -c '^G0'` under-counts (modal suppression) | harness | `Link-5-GRBL`, `Link-15-GRBL` | ✅ |
| **HW-2 (A)** | HP-5 section boundary: WCS suppression, rapid lifecycle, tracking | 2 ops, 1 tool, 1 WCS, no base | **one `G54` in the whole file**; `( WCS unchanged: 1, not re-selecting)` at section 2; `resetAll()` makes section 2 re-emit full coordinates | posted | `Link.gcode` | ✅ |
| **HW-2 (B)** | HP-5 boundary: a spindle-speed change | same CAM, `Manual Spindle On/Off` = **false** | `M3 S12000` then `M3 S10000` — two `M3`s, different speeds | posted | ⚠ **file overwritten** — re-post as `HR12-auto - GRBL.gcode` | ✅ |
| **HW-3** | `Probe Pause = No` | `C_Probe_Pause` = `No` | **neither** prompt. vs `HW4` the diff is exactly **2 lines** | posted | `HW3 - GRBL.gcode` vs `H11c` | ✅ |
| **HW-4** | `Probe Pause = Before` | `C_Probe_Pause` = `Before` | attach only. The three-rung ladder `H11c`→`HW4`→`HW3` is the result, not any one file | posted | `HW4 - GRBL.gcode` | ✅ |
| **HW-5** | The HP-1 baseline in one file | `Scale Feedrate` = **true** | vs `HW4`: timestamp, that property, and **feedrates only** — XY cuts/arcs → `F900`, plunges and `G18` arcs → `F180`. No motion, no block added | posted | `HW5 - GRBL.gcode` | ✅ |
| **HW-6 (A)** | Static regression sweep | `git diff dd8e11d..HEAD` + 3 harnesses + property structure | surface = `loadFile()` + one dialog-only title; 68 properties, no duplicate keys, all 67 `getProperty()` refs resolve | harness + read | node, git | ✅ |
| **HW-6 (B)** | Posted regression sweep | the six posts below | byte-identical modulo timestamp except posts 5–6 | read | ⚠ **the release sweep rests on no posted file** | ✅ |
| **HR-23** | An include replaces the phase it names | Marlin + stop include, vs the same job without | coolant off, `G0 X0 Y0`, the spindle prompt, `M84 S60` and the program end **all absent** — **as designed** | posted | `H11d - Marlin.gcode` vs `H11a.gcode` | ✅ |
| **HR-24** | `writeWCS()` consults the global `tool` | — | latent — both callers pass `currentSection`; next sweep | read | — | ➖ |
| **HR-25** | `wcsGcode(0)` yields `G53` | — | **closed as by design** (CR-17d) | read | — | ✅ |
| **HW-7** | Dialog audit — labels, defaults, preset survival | — | → `PReview.md` §3.3 (**D1**, **D3**) | — | — | ➖ |
| **CR-REG** | The 14 fixes leave a factory-default job **otherwise unchanged** | GRBL/mm, Comment Level `Info`, all defaults, single operation | `M0 (MSG Turn OFF spindle)` **precedes** `G0 X0 Y0`; the probe comment reads **`Retract the tool to 5.08`**, not `5.080000000000001`; **the header property dump is unchanged** — it was always post-sorted, so CR-14's reorder must not show there | posted | — **owed** | ⬜ |
| **CR-1 (A)** | `$H` survives line numbering | GRBL, `Home Before Start = XY`, `Enable Line #s` **on** | **`$H` on its own line with no `N` prefix**, while every surrounding block carries one. No configuration in the record has ever combined homing with line numbers — which is why it shipped broken | posted | — **owed** | ⬜ |
| **CR-2 (A)** | The homing / `Current Pos` warning fires, and the job still posts | homing on + a `Set … to Current Pos` origin mode | the warning names the control by its exact dialog title; **the file still posts**. Negative half: a default job with homing **off** produces no warning | posted | — **owed** | ⬜ |
| **CR-10 (A)** | GRBL laser mode formats its M-code as a number | group 09 on, GRBL, a laser operation | a real M-code number, **never `M NaN`**. Group 09 has never appeared in any posted file — see `PReview.md` **J4**, which this post also serves | posted | — **owed** | ⬜ |
| **HR-27** | A geometry-rejected job writes **no file at all** | **(a)** a Setup built on a tilted model face, GRBL/mm defaults; **(b)** the same job on an upright Setup | **(a)** the post `error()`s and **no `.gcode` exists on disk** — the discriminator is the *absence of the output file*, not its contents. Today the guard fires in `onSection()` and leaves a **truncated** file ending mid-toolpath, which is the pre-fix discriminator and must stop appearing. **(b)** posts normally and completely, proving the promotion into `validateJob()` did not reject a job it should accept. Shares HR-6 (B)'s dependency — it needs the same rotated Setup, and if Fusion re-expresses `forward` as `Z1` then branch (a) is unreachable and that is itself the HR-6 (B) answer | posted | — **owed** | ⬜ |

---

## Invalidated by the 2026-08-01 code-review fixes

The `CR-` pass landed 14 fixes at `c73726c`. Assertions below still hold; **the quoted token
*sequences* do not.** Re-baseline when the affected rows are next posted.

| Row | What moved | Was | Now |
|---|---|---|---|
| **HR-3 (A)**, **HR-11 (C)** | CR-6 reordered `onClose()` | coolant off → `X0 Y0` → spindle off | coolant off → **spindle off** → `X0 Y0`. The `M5`/`M300` absences and `M30` are unaffected |
| **HR-11 (A)(B)**, **HR-23** | same | `X0 Y0 F2500` before the prompt | after it. `M400`/`M117`/`M84 S60`/`M2` order unchanged |
| **HR-4 (A)** | CR-17a formatted the retract comment | `Retract the tool to 0.7874015748031497` | `Retract the tool to 0.7874` |
| **HR-15 (A)**, **HR-17 (D)**, **HR-4 (B)**, **HW-3/4/5** | the "differs in N lines" diffs are between two files from the *same* build | — | still valid as historical evidence; a **re-post** shifts the `X0 Y0` line |
| **all rows** | CR-13 (`resetPostState()`), CR-14 (properties reorder) | — | **no output change expected** — the property dump is sorted by the post, so the reorder is dialog-only. Any diff here is a defect in the fix |

---

## Checked and found correct

Recorded so a later pass can tell *"looked at, fine"* from *"never looked at"*. All of it by reading
control flow against the API — **no posted file was consulted**, which makes every line here weaker than
a `posted` row and stronger than nothing.

| Area | Verdict |
|---|---|
| **The default single-op job, all three firmwares** | Phase order is right where it matters: `writeWCS()` emits `G54` **before** any origin write, so the origin cannot land on a WCS a previous job left active; `Start()` sets `G90`/`G21` before the base establish and the probe; the provisional `Z0` precedes the `G38.2`; probe and prompts run with the spindle **off** |
| **Multi-op, single WCS** (the common Personal-licence job) | Section 2+ short-circuits on `workOffset == currentWorkOffset` — no spurious retract, re-probe or re-select. Two Setups both left at Fusion's default offset `0` alias to `1` consistently in both `collectDistinctOffsets()` and `writeWCS()` |
| **Guard reachability from hobbyist settings** | Guard B exempts the single-WCS job, so default `Retract Across Parts = on` with no base does **not** fire; Guard C's Marlin check runs before the base logic; Guard A is unreachable with no base. All three run in `onOpen()`, so a rejected job writes no file |
| **Units** | Every dialog dimension is converted by `propertyMmToUnit()` before being emitted or compared; F360 level values arrive in the output unit already and are correctly **not** converted |
| **Safe-Z expression parsing** | `parseSafeZExpr()` handles a bare number and all three `Feed:`/`Retract:`/`Clearance:` forms and falls to `ERROR` (15 mm fallback + warning) for anything else; every level path asks the **passed** section, not the global |
| **The G1→G0 mapper's move ordering** | Safe despite the untracked position: the only post-injected motion before the first section body is the probe retract, which leaves the tool *higher* than the kernel believes, so `rapidMovements()` errs toward Z-first. The general defect is real and professional-scoped (HR-8) |
| **Feed handling** | `G0` blocks carry their travel `F` through the same `fOutput` the cut moves use (the one exception is CR-12); `limitArcFeed()` caps against the axes the arc actually sweeps; both limiters return the feed untouched when `Scale Feedrate` is off |
| **Canned cycles** | Expansion is the only correct choice on all three firmwares — derivation in `conventions.md` → *Firmware capabilities*. `isProbeOperation()` is defined locally rather than depending on the kernel supplying one |
| **Early rejections** | Multi-axis (`onSection`, with `onRapid5D`/`onLinear5D` as a backstop) and `onRadiusCompensation` both `error()` with actionable text; the off-axis Setup guard fails **open**, the right bias for a check whose false positive would abort every job |
| **Comment levels** | Behaviourally inert — no control flow depends on a comment being emitted. `loadFile()`'s trailing-newline repair is independent of the surrounding `Info` markers, which is why it works at `Important` and `Off` |
| **`Include Whitespace = off`** | Valid blocks everywhere — `askUser()` and `display_text()` prepend their own separator, and the concatenated forms (`G10L20P1X0Y0Z0`, `G38.2F30Z-10`) are accepted by all three parsers |
| **Coolant channel bookkeeping** | `setCoolant()` turns both channels off before switching, warns when a tool requests a coolant no channel is configured for, and derives `coolantLevels` from `eCoolant` so the numeric index and the enum ids cannot drift apart |
| **Property structure** | 68 properties across 11 groups — 9/7/4/2/4/10/8/5/7/10/2 — no gaps or duplicates in the per-group letter prefixes, every one carrying `scope: "post"`. `writeAllProperties()` iterates the object rather than a hand-kept list, so the header dump cannot drift |

---

## Owed

0. **Post-verify the 14 `CR-` fixes** — the four `⬜` rows in the register above, **`CR-REG` first**: it is
   the regression that matters most, and everything else rests on a default job still posting cleanly.
   Two further posts serve `PReview.md` §3.5's CR-3 / CR-4 / CR-5 / CR-13 rows, and the laser post
   (`CR-10 (A)`) is also **J4** — group 09 has never appeared in any posted file, so a fix and its
   first-ever exercise coincide there.
1. **Tidy-up sweep** — HR-19's `M291` space, HR-21 / CR-15 (decide: wire or delete), HR-24. One-liners,
   none changing output; one posted file confirms exactly that.
2. **Six `read` rows want a post.** **One post settles three**: `Stop File.gcode` (last byte `e`, no
   terminator) as the **Stop include** on the Marlin job at Comment Level **`Important`** → HR-18 (A),
   HW-6 (B), and re-baselines `H11d`. Also owed: `HR12-auto - GRBL.gcode` (Link's CAM, `Manual Spindle
   On/Off` = false) to restore HW-2 (B)'s overwritten file.
3. **HR-6 (B) is the one residual that could still hide a real defect** — nothing evidences what Fusion
   puts in `workPlane.forward` for a re-oriented Setup. Needs a rotated Setup; the failure mode is a
   **missed** rejection, i.e. a part cut in the wrong plane, silently.
4. **The posted regression sweep**, if run: 1 `HW6a - GRBL` (defaults) ≡ `H11c` · 2 `HW6b - Marlin` ≡
   `H11a` · 3 `HW6c - RRF` ≡ `H11b` · 4 `HW6d - GRBL Inch` ≡ `H4base` · 5 `HW6e - Marlin` + stop include
   → one difference, `--- End custom gcode` on its own line · 6 `HW6f - Marlin` as 5 but as the **Start**
   include at Comment Level `Important`. **Post 1 is the one to run if only one is run.** Posts 5–6
   upgrade HR-18 (A)(B) from `read` to `posted`. *(All six now also carry CR-6's reordered tail.)*
5. **Nine reference files predate HR-17** and would differ in two text respects if re-posted. No
   assertion is invalidated — tidiness, not risk.
6. **Owed to the next README doc-sync: nothing.** The six items this list used to carry — the group-03
   label, group 08's *"post processor might be unsafe"* prompt, HR-23's substitution contract, the
   `Tool Change Probe` field, CR-4's coolant file loading and CR-16's descending Safe Z move — all
   landed in `cd57a48`, whose `doc-sync` marker reads `7b80b44`. The only `.cps` commit since is
   comment-only. Refresh from `git diff 7b80b44..HEAD -- MPCNC_v4.0_Beta2.cps` and re-bump the marker
   when the post next changes what it emits. **The README is not touched during code changes.**

