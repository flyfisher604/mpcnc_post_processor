# PReview — professional-workflow review of `MPCNC_v4.0_Beta2.cps`

> **The professional review has not been done.** This file is a **parking lot**, not a review.
> Everything in it arrived incidentally: findings the hobbyist review (`docs/HReview.md`) turned up
> while walking code it then judged out of its own scope, and the professional half of the Beta-2
> test plan, which this file absorbed. A real professional pass — the same method HReview used, from
> the professional's chair, walking every multi-WCS / multi-fixture / tool-change path — is still
> owed, and will add findings this file does not have.
>
> **Nothing here is committed code.** Every finding below is unimplemented; the diffs are proposals,
> not records.

**Standing rule.** A change to `MPCNC_v4.0_Beta2.cps` that touches professional behaviour updates
this file **in the same commit**: add the Do→Get row that verifies it (exact settings, exact
expected g-code, and the *discriminator* — the one token whose presence or absence proves it), and
flag any row whose saved `.gcode` it invalidates. A stale PASS is worse than an unrun test.

**How rows are verified:** post the job from Fusion and read the g-code. Machine dry-runs and
physical measurement are out of scope, so every row must stand on the posted file alone.

---

## 1. What "professional" means here

The professional persona has the full Fusion licence and a real fixture setup. In post terms that is
everything the README puts outside the hobbyist's reach:

| Area | Controls |
|---|---|
| Multiple WCS / multiple parts | `Subsequent WCS / Part`, Replicate jobs, the `Jog to …` per-part modes |
| Reserved spoilboard base | group `05 - Establish Spoilboard Reference` (all four properties) |
| Cross-part clearance | `Retract Across Parts`, `Inter Part Safe Z` |
| Pre-set fixture offsets | both `Use Active WCS …` origin modes |
| Tool changes | group `07 - Tool Changes` (all eight properties) |
| Manual NC | *Optional stop*, *Display message*, *Orientate spindle* |
| Machining Extension | probing / Inspection strategies |

> **Scope decision (2026-07-31) — tool changes are a professional feature.** Fusion's Personal
> licence does not support tool changes, and Manual NC is treated the same way, so neither belongs
> in a review written from the hobbyist's chair. This is why six findings below carry `HR-` ids: they
> were found by the hobbyist pass and reclassified, and the ids are **kept deliberately** so the
> commit history, `HReview.md` and this file all still refer to the same defect by the same name.

---

## 2. Findings deferred from the hobbyist review

All six land **as one unit** with *Phase 4 — tool-change ordering + base-relative park*
(`docs/plan.md`), rather than patching the same section-boundary code twice. **HR-10** and **HR-13**
are independent of the reorder and have complete diffs, so they can go in first as warm-up commits.

---

### HR-7 — `toolChange()` clobbers `forceSectionToStartWithRapid`, defeating "First G1 → G0" on every tool-change section — **Medium** · `READ`

**Reaches it:** several tools with group 07 enabled *and* group 03 on.

`onSection()` sets `forceSectionToStartWithRapid = true` so the section's first `G1` — which on a
Personal licence *is* the lost positioning rapid — gets converted back. But `toolChange()` reaches
the change position through the post's **own** `onRapid()`, whose first statement clears that flag.
`toolChange()` runs *before* the body's motion, so the conversion never happens — on precisely the
boundary where it matters most, the move from the park position back to the work. The result is a
`G1` at cut feed (and, with `Scale Feedrate` on, at a feed derived from a stale position — HR-8).

Every other post-injected move already avoids this by calling the low-level emitters
(`rapidMovementsXY` / `rapidMovementsZ` / `rapidMovements`) rather than the callback. `toolChange()`
is the only place that routes through `onRapid()`, and the fix is to match:

```diff
@@ function toolChange() {
     flushMotions();
-    onRapid(propertyMmToUnit(getProperty(properties.C_ToolChange_X)), ...);
+    // rapidMovements(), not onRapid(): onRapid() clears forceSectionToStartWithRapid, and this runs
+    // BEFORE the section's body -- so routing through the callback silently disables the
+    // "First G1 -> G0 Rapid" conversion for every section that changes tools.
+    rapidMovements(propertyMmToUnit(getProperty(properties.C_ToolChange_X)), ...);
     flushMotions();
```

**Verify (Do → Get).** *Do:* two operations, two tools, group 07 on with Include Relocation Code,
`First G1 → G0 Rapid` on. *Get:* the `( First G1 --> G0)` comment and a `G0` at the start of section
2's body, after the `Tool Change End` comment. **Pass:** section 2's first motion block is `G0`, not
`G1` — today it is `G1`.

---

### HR-8 — post-injected motion never updates Fusion's tracked position — **Medium** · `READ`

**Reaches it:** every persona, at every section boundary that follows a post-emitted move (probe
retract, tool-change park, WCS-change retract, base clearance).

`setCurrentPosition()` / `setCurrentPositionZ()` appear **nowhere** in the file. The kernel tracks
position from the callbacks it drives; when the post emits its own `G0` through `rapidMovementsZ()`
or `rapidMovementsXY()`, the kernel's model does not move. Three consumers read that model:

1. **`rapidMovements()`** picks Z-then-XY vs XY-then-Z from `_z < getCurrentPosition().z` — the
   ordering the README sells as the reason the G1→G0 conversions are safe (*"retracts before
   travelling and travels before descending"*). When the tracked Z is higher than the physical Z the
   post concludes it is descending and travels **first, at the lower physical height**. Reachable at
   a tool-change boundary: the section ends at a clearance of 40, the park move and re-probe retract
   bring the tool physically to ~5 without the kernel noticing, and the next section's first rapid to
   15 is then ordered XY-first — a full traverse at 5 mm above the stock top.
2. **`isSafeToRapid()`** reads `getCurrentPosition()` for its `zConstant` / `zUp` / `curZSafe` tests,
   so a section's first conversion decision can be made against a stale Z.
3. **`limitFeedByXYZComponents()`** builds its direction vector from `getCurrentPosition()`, so the
   first cut move after injected motion can be scaled along the wrong vector.

Within a section the tracked position is accurate, which is why no single-section job has ever shown
this. It is a boundary defect.

**Recommended fix** — tell the kernel about the post's own moves: `setCurrentPosition(new Vector(_x,
_y, cur.z))` after `rapidMovementsXY()`'s `writeBlock`, and `setCurrentPositionZ(_z)` after
`rapidMovementsZ()`'s.

**Caveat — this one wants a posted file before it lands.** `setCurrentPosition()` inside a section
could interact with the kernel's own bookkeeping for the following section. Safe sequencing: apply
it, re-post the passing single-section references and diff **motion only**. If any move, prefer the
narrow variant — track a post-local `lastEmittedZ` and have `rapidMovements()` consult
`max(getCurrentPosition().z, lastEmittedZ)` for its ordering decision, which fixes the
collision-relevant half with no kernel interaction at all.

**Verify (Do → Get).** *Do:* two ops, two tools, group 07 with Include Relocation Code and
`Tool Change Z = 40`, second operation's clearance 15. *Get:* section 2's opening rapid pair is
`G0 Z15` **then** `G0 X… Y…`. **Pass:** the Z block precedes the XY block — today the order inverts.

---

### HR-9 — `Do First Change` with `Probe After Tool Change` off zeroes Z against the wrong tool — **Medium** · `READ`

**Reaches it:** group 07 enabled with `Do First Change` on — the natural choice for "the spindle is
empty, load tool 1 for me" — while `Probe After Tool Change` is left at its default **off**.

The order inside `onSection()` is fixed: `writeFirstSection()` runs before the tool-change block. So
for the first section: `writeWcsOnStart()` probes and writes `G10 L20 P1 Z0.8` **with whatever tool
is in the spindle** — which by the premise of `Do First Change` is not the job's tool; then
`toolChange()` parks, prompts, and the operator installs tool 1, a different length; and with
`Probe After Tool Change` **off** nothing re-references Z. Every cut runs at
`(actual tool length − probe tool length)` off nominal, with nothing in the file saying so.

With `Probe After Tool Change` **on** the second probe corrects it, so that combination is merely
wasteful (two attach/detach prompt pairs).

**Recommended fix.** The ordering change is the real answer but touches the Phase-4 tool-change
rework. Pending that, `warning()` at post time from `validateJob()` when
`A_ToolChange_Enabled && G_ToolChange_DoFirstChange && !H_ToolChange_ProbeAfterChange`, naming both
controls by their exact dialog titles and offering the two fixes (enable the re-probe, or set the
origin manually).

**Verify (Do → Get).** *Do:* group 07 on, `Do First Change` on, `Probe After Tool Change` off.
*Get:* Fusion shows the warning and the file still posts. **Pass:** the warning names both controls
by their exact dialog titles. Second post with the re-probe **on**: no warning, two `G38.2` blocks.

---

### HR-10 — `Disable Z Stepper` emits Marlin-only `M84 Z` on GRBL — **Medium** · `READ`

**Reaches it:** GRBL, group 07 enabled with `Disable Z Stepper` on — a reasonable choice on a
machine whose Z drifts under a heavy spindle.

```js
if (getProperty(properties.F_ToolChange_DisableZStepper)) {
  askUser("Z stepper will disable; wait for full stop", "Tool change", false);
  writeBlock(mFormat.format(84), 'Z');
}
```

No firmware guard. `M84` does not exist in GRBL — the controller answers `error:20` and most senders
**halt the program mid-tool-change**. `Start()` already puts its own `M84 S0` inside the non-GRBL
branch, so the command is already known to be Marlin-family-only elsewhere in this file.

```diff
     if (getProperty(properties.F_ToolChange_DisableZStepper)) {
-      askUser("Z stepper will disable; wait for full stop", "Tool change", false);
-      writeBlock(mFormat.format(84), 'Z');
+      // M84 is Marlin-family only -- GRBL answers error:20 and most senders halt the program
+      // mid-tool-change. Start() already scopes its own M84 S0 the same way.
+      if (fw == eFirmware.GRBL) {
+        writeComment(eComment.Important, " >>> WARNING: \"Disable Z Stepper\" ignored on GRBL -- M84 is not a GRBL command");
+      } else {
+        askUser("Z stepper will disable; wait for full stop", "Tool change", false);
+        writeBlock(mFormat.format(84), 'Z');
+      }
     }
```

**Verify (Do → Get).** *Do:* GRBL, group 07 on, `Disable Z Stepper` on. *Get:* the warning comment
and **no `M84`** anywhere. **Pass:** absence of `M84`. Second post on Marlin: `M0` prompt + `M84 Z`
present, no warning — proving the Marlin path is untouched.

---

### HR-12 — a manual spindle is never told about an RPM change between operations — **Medium** · `READ`

**Reaches it:** several operations at different spindle speeds with `Manual Spindle On/Off` on (the
default).

`spindleOn()` guards its prompt on `!spindleEnabled`, and `spindleEnabled` is only cleared in
`spindleOff()`, which within a job runs only at a tool change or at close. So section 2 asking for
12000 RPM after section 1 ran at 18000 reaches the guard, the prompt is blocked, and nothing in the
file mentions the change — while `currentSpindleSpeed` is updated regardless, so the post believes it
happened. For a hand-set router that is the difference between the operator's dial and the speed
Fusion computed the feeds against: a burnt cutter or a poor finish, silently.

```diff
   if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
     if (!spindleEnabled) {
       writeComment(eComment.Important, " >>> Spindle Speed: Manual");
       askUser("Turn ON " + speedFormat.format(_spindleSpeed) + " RPM", "Spindle", false);
+    } else {
+      // The caller only reaches here when the requested RPM actually changed.
+      writeComment(eComment.Important, " >>> Spindle Speed: Manual change");
+      askUser("Set spindle to " + speedFormat.format(_spindleSpeed) + " RPM", "Spindle", false);
     }
   } else {
```

**Verify (Do → Get).** *Do:* two operations, same tool, spindle speeds 18000 and 12000, `Manual
Spindle On/Off` on. *Get:* `M0 (MSG Turn ON 18000 RPM)` before section 1 and `M0 (MSG Set spindle to
12000 RPM)` before section 2. **Pass:** two prompts. Third check: two operations at the *same* RPM →
one prompt only (`setSpindeSpeed` short-circuits, so no new stop on the common case).

> The space before `RPM` arrived with **HR-17** (`HReview.md` §4.2) after this diff was written; the
> context line and both new prompts above were updated to match, so the proposal still applies
> cleanly. Files posted before that sweep read `18000RPM`.

---

### HR-13 — `onCommand` silently discards every command it does not name — **Low-Medium** · `READ`

**Reaches it:** Manual NC *Optional stop*, *Display message*, or *Orientate spindle*.

`onCommand()` opens with an `Info` comment naming the command, then a `switch` with no `default:`.
`COMMAND_STOP` → `M0`; `COMMAND_OPTIONAL_STOP` → nothing at all. So Manual NC *Optional stop*
produces no `M1`, and at Comment Level `Important` or `Off` not even the naming comment survives —
the instruction vanishes without trace. `M1` is supported by all three targets, so there is no
reason to drop it; and an explicit `default:` turns every future gap into a visible warning.

```diff
     case COMMAND_STOP:
       writeBlock(mFormat.format(0));
       return;
+    case COMMAND_OPTIONAL_STOP:
+      writeBlock(mFormat.format(1));
+      return;
   }
+
+  // Anything not named above reaches here. The Info comment at the top of this function is the only
+  // trace otherwise, and it disappears entirely at Comment Level Important/Off.
+  writeComment(eComment.Important, " >>> WARNING: command " + getCommandStringId(command)
+    + " is not supported by this post and was not emitted");
 }
```

**Verify (Do → Get).** *Do:* add Manual NC *Optional stop* to an operation and post. *Get:* `M1` at
the Manual NC's position. **Pass:** `M1` present. Second check: Manual NC *Orientate spindle* → a
`>>> WARNING: command COMMAND_ORIENTATE_SPINDLE …` comment appears instead of silence.

---

## 3. Verification owed

Absorbed from the Beta-2 test plan. Conventions: comments are `( … )` on GRBL and `; …` on
Marlin/RRF, otherwise the tokens are identical; `G10 L20 P<n>` is GRBL/RepRap, Marlin uses `G92` and
rejects >1 WCS (Guard C). Default probe target / speed / thickness = `Z-10` / `F30` / `Z0.8`.
Default origin modes are First = `Set X0 Y0 to Current Pos, Probe Z0`, Subsequent = `Use Active WCS
X0 Y0, Probe Z0` — both no-prompt; the `Jog to …` modes are opt-in.

> **⚠ Every saved GRBL `.gcode` predating 2026-07-31 differs at the tail** (HR-3: the manual-spindle
> stop now prompts on GRBL, so a default job ends `M0 (MSG Turn OFF spindle)` where it once ended
> `M5`, and each tool change gains the same prompt). No row's assertions are affected. Don't read a
> tail diff as a regression.

### 3.1 Multi-part / multi-fixture — needs a job nobody has posted yet

Every row below needs either a 2-copy Replicate job or a two-Setup job; none can be reached from the
single-section jobs on disk. **This is the largest untested area in the post.**

**Professional B — one WCS per copy (Replicate).** 2-copy job, Setup 1 → WCS `1` (G54), Setup 2 → WCS
`2` (G55), reserved base **`G59`**, **Retract Across Parts = On**, real tool.

- [ ] **PB1 — re-probe per copy** (Subsequent = `Use Active WCS X0 Y0, Probe Z0`, the default).
      *Get at job start:* `( Establish spoilboard base G59)` → `(   Select base G59 …)` → `G59` →
      `G38.2` → `G10 L20 P6 Z0.8` → `G0 Z40` (Inter Part Safe Z, base frame) →
      `(   Restore operating WCS G54 …)` → `G54`. *Get at the `P1→P2` boundary:*
      ```
      ... transit through base: G59 → G0 Z40 ...
      G55
      (   Move to part origin X0 Y0, then probe Z)
      G0 X0 Y0 F<travelXY>
      G38.2 F30 Z-10
      G10 L20 P2 Z0.8
      ```
      **Pass:** the base probes once at start with no XY reposition; each copy re-probes Z at its
      stored XY; the traverse retracts base-relative to `Z40` *before* switching WCS.
      *(Satisfies M2, P2.)*
- [ ] **PB2 — trust the stored Z** (Subsequent = `Use Active WCS X0 Y0 Z0`). Same job. *Get at
      `P1→P2`:* `G59` → `G0 Z40` → `G55` → `(   Move to this part's stored origin X0 Y0)` →
      `G0 X0 Y0` → straight into the cut. **Pass:** no `G38.2` on the added copy, and the tool still
      arrives safely at `X0 Y0` after the retract. *(Satisfies M1.)*

**Professional B-variant — set the fixtures on run 1, reuse them later.** Two distinct jobs against
the same 2-fixture bed; reserved base `G59`, Retract Across Parts on, real tool. This is the workflow
the Jog origin modes exist for.

- [ ] **PBV1 — setup run, record each fixture origin.** First = `Set X0 Y0 Z0 to Current Pos`,
      Subsequent = `Jog to X0 Y0, Probe Z0`; jog to fixture 1 before posting. *Get:* first part
      `G10 L20 P1 X0 Y0 Z0` (no prompt, no probe); at `P1→P2` retract → `G55` → jog prompt
      (`M0 (MSG Jog to X0 Y0 above Z0, probe)`) → `G10 L20 P2 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8`.
      **Pass:** every fixture's origin is written to its own register from an operator jog. Then
      confirm at the controller that `G54`/`G55` report the set origins (GRBL persists `G10 L20` to
      EEPROM). *(Satisfies M3, M4.)*
- [ ] **PBV2 — production run, reuse fixtures, re-probe Z.** First = `Use Active WCS X0 Y0 Z0`,
      Subsequent = `Use Active WCS X0 Y0, Probe Z0`; **do not re-jog**. *Get:* first part
      `(   Use stored work origin; move to X0 Y0 at Safe Z)` → `G0 Z<probeSafeZ>` → `G0 X0 Y0`, no
      origin write; at `P1→P2` retract → `G55` → `G0 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8`.
      **Pass:** no prompts anywhere; XY from the stored fixtures; Z re-probed per copy.
      *(Satisfies M6, M2.)*
- [ ] **PBV3 — production run, trust stored Z too.** As PBV2 with Subsequent = `Use Active WCS X0 Y0
      Z0`. **Pass:** no probe anywhere on added copies; each just retracts and arrives at its stored
      `X0 Y0`. Only sound when every copy's stock is the setup run's thickness.

**Professional A — a second WCS on the same part, same fixture.** The part stays clamped in one
fixture (no flip, no re-clamp): after the face and outside are machined in WCS `1`, a second Setup
uses WCS `2` whose origin is referenced from a **machined face**, so its Z must be re-probed there.
Mechanically an ordinary inter-WCS traverse plus a re-probe — supported today. The tool never leaves
the part, so the outgoing-frame Safe Z is a valid clearance and no base is required. *(The flip /
re-clamp variant remains future work.)*

> **Settings note (Guard B).** For a single-part two-WCS job use **Retract Across Parts = Off** with
> no base: the inter-WCS traverse still retracts to the probe Safe Z in the *outgoing* frame, which
> clears the part. Leaving Retract Across Parts **on** without a base trips Guard B — it cannot tell
> one part's two WCS from two fixtures.

- [ ] **PA1 — new WCS from a machined face, operator jogs the new datum.** Setup 1 → WCS `1`; Setup 2
      → WCS `2` on a machined face. Subsequent = `Jog to X0 Y0, Probe Z0`; Retract Across Parts off,
      no base. *Get at the `G54→G55` boundary:*
      ```
      (   Retract to Safe Z before WCS change)
      G0 Z<probeSafeZ>            ; in the outgoing G54 frame
      G55
      ... M0 jog prompt: "Jog to X0 Y0 above Z0, probe" ...
      (   Set current X,Y position to 0,0)
      G10 L20 P2 X0 Y0
      (   Move to part origin X0 Y0, then probe Z)
      G38.2 F30 Z-10
      G10 L20 P2 Z0.8
      ```
      **Pass:** the traverse retracts to a clear Z in the outgoing frame *before* selecting `G55`; the
      re-probe writes Z into `P2`, not `P1`. *(Satisfies M4.)*
- [ ] **PA1b — variant: WCS 2's XY already known, only Z re-references.** Same job, Subsequent =
      `Use Active WCS X0 Y0, Probe Z0`. *Get:* retract → `G55` → `(   Move to part origin X0 Y0,
      then probe Z)` → `G0 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8` — **no jog prompt**.
      *(Satisfies M2.)*

**Probe XY offset — added-part halves.** The offset makes the touch-point `origin + (offsetX,
offsetY)` at the first part and each added part, and is **never** applied to the base probe. The
first-part paths (offset 0 and nonzero) and the base-ignores-offset half are already verified (§4);
only the added-part halves remain.

- [ ] **P2 — nonzero offset, Replicate + reserved base.** 2-part job, base `G59`, Subsequent =
      `Use Active WCS X0 Y0, Probe Z0`, offsets `10`/`5`. **Pass:** the **added part (`P2`)** shows
      `(   Move to probe point = origin + offset X10 Y5, then probe Z)` → `G0 X10 Y5` → `G38.2` →
      `G10 L20 P2 Z<thk>`. *(The base and first-part halves are already evidenced by `H7c.gcode`.)*
- [ ] **P3 — zero-offset added-part regression.** Same 2-part job, offsets `0`. **Pass:** each added
      part emits the bare-origin form — comment reads `part origin X0 Y0`, **not** `probe point =
      origin + offset …` — and the first/only part still shows no reposition at all.

**Subsequent WCS / Part — the four modes.** Use a 2-part Replicate job (`P1` + `P2`), reserved base
`G59` + Retract Across Parts on, tool ≠ 0. On each added part every mode must **retract to a safe Z
first, then act** — confirm that retract precedes any XY move. Marlin is out of scope (Guard C).

- [ ] **M1 — `Use Active WCS X0 Y0 Z0`.** base-relative retract (`G59` → `Z<SafeZ>`) → `G55` →
      **`G0 X0 Y0`** → straight into cutting, no probe. That `G0 X0 Y0` is the "do nothing but arrive
      safely" move added by the redesign; it supersedes the older verified `Skip` behaviour, which
      went straight into cutting.
- [ ] **M2 — `Use Active WCS X0 Y0, Probe Z0`.** retract → `G55` → rapid to `X0 Y0` (+ offset) →
      `G38.2` → `G10 L20 P2 Z`. XY comes from `P2`'s stored offset, not re-zeroed.
- [ ] **M3 — `Jog to X0 Y0 Z0`.** retract → `G55` → jog prompt (`M0 (MSG Jog to X0 Y0 Z0, then
      continue)`; RepRap `M291 … S3 X1 Y1 Z1`) → `G10 L20 P2 X0 Y0 Z0` → cutting. No probe, no auto
      XY move.
- [ ] **M4 — `Jog to X0 Y0, Probe Z0`.** retract → `G55` → jog prompt → `G10 L20 P2 X0 Y0` →
      `G38.2` → `G10 L20 P2 Z`, with attach/detach prompts following `Probe Pause`. With a nonzero
      offset the probe repositions after the jog.
      > **Open decision to settle on this run:** whether the added-part jog mode should get HR-1's
      > provisional `Z0` for symmetry with the first-part jog mode. Deferred here deliberately — the
      > tool arrives from a retracted clearance, so its Z is less predictable than on the first part.
      > See `HReview.md` HR-1.
- [ ] **M5 — single-WCS regression.** A single-WCS job is byte-for-byte unchanged — `writeWCS()`
      returns at "WCS unchanged", so none of the new dispatch runs. (Compares two *current* posts to
      each other, so the HR-3 tail note does not affect it.)
- [ ] **M6 — first-part `Use Active WCS X0 Y0 Z0` reaches X0 Y0.** Milling tool: the first section
      emits `G0 Z<probeSafeZ>` then `G0 X0 Y0` instead of nothing. A jet/tool-0 first part emits the
      `X0 Y0` move but **no** Z retract (→ J1).

### 3.2 Origin-mode coverage — firmware variant

- [ ] **H7e — first-part `Use Active WCS X0 Y0, Probe Z0` on Marlin and RRF.** **Pass:** Marlin emits
      `G92 Z0.8` only (no XY word, no `G54`); RRF emits `G54` + `G10 L20 P1 Z0.8` with `M291 … S3`
      probe prompts. No jog buttons (`X1 Y1 Z1`) — this mode has no jog prompt. *(Cheap to fold into
      any Marlin/RRF session; the GRBL half of this mode is verified.)*

### 3.3 Dialog & defaults audit — needs the dialog, not a posted file

- [ ] **D1 — labels, groups and field types.** Confirm group **`06 - On WCS / Part / Fixture
      Changes`** exists (no lingering `Probe / Work Origin`); titles read **First WCS / Part**,
      **Subsequent WCS / Part**, **Probe Pause**, **Probe with G38.2**; the base-establish option
      reads **Pause, Probe Z, Pause**; **First WCS / Part** lists all six modes in order and defaults
      to the first (`Set X0 Y0 to Current Pos, Probe Z0`); **Subsequent WCS / Part** lists its four
      modes in order and defaults to the first (`Use Active WCS X0 Y0, Probe Z0`) with no
      `Set … to Current Pos` modes; **Probe X/Y Offset**, group-05 **Inter Part Safe Z** and group-06
      **Safe Z** accept only whole numbers (reject `2.5`) and read as whole mm. Confirm no group shows
      two fields both titled "Safe Z".
- [ ] **D3 — a saved preset survives the group reorder *and* the group-03 rename.** Open the dialog
      with a **previously customised preset** loaded. *Get:* groups read `01 - Job`,
      `02 - Feeds and Speeds`,
      `03 - Map G1s to Rapids - disable when using full license` (**renamed** by `HReview.md` HR-17 —
      the parenthesised form is gone, so this row now tests a real string change on that group rather
      than a hypothetical one), `04 - Establish Machine Coordinates`,
      `05 - Establish Spoilboard Reference`, `06 - On WCS / Part / Fixture Changes`,
      `07 - Tool Changes`, `08 - External Include Files`, `09 - Laser`, `10 - Coolant`, `11 - Duet`,
      with **9 / 7 / 4 / 2 / 4 / 10 / 8 / 5 / 7 / 10 / 2** properties (68 total).
      **Pass — the discriminator is that nothing reset.** Only `group:` strings changed, so every
      customised value must survive: spot-check Home Before Start, both origin dropdowns, and any
      nonzero Probe X/Y Offset. A field back at its default means a key changed and the move was done
      wrong. *(The header half is verified — §4. A posted file cannot distinguish "the preset
      survived" from "the values were re-entered", which is the whole point of this check.)*
- [ ] **D2 (remainder) — the property dump is suppressed at Comment Level `Important` and `Off`.**
      The dump's structure and the resolved Safe-Z lines are verified (§4); only the suppression half
      is unrun.

### 3.4 Other outstanding professional checks

- [ ] **HR-3 (C) — the tool-change half of a landed hobbyist fix.** `spindleOff()` now prompts a
      hand-switched spindle to stop on GRBL as well as Marlin/RRF (`HReview.md` HR-3, committed
      `43d09aa`, verified at job end). The tool-change half is unverified and is the case that matters
      most: *Do:* GRBL, two operations, two tools, group 07 → Tool Changes are Included on, Include
      Relocation Code on, Manual Spindle On/Off on. *Get:* at the boundary —
      ```
      ( Tool Change Start)
      ... the park rapid to Tool Change X/Y/Z -- order not asserted here, see HR-8 ...
      ( COMMAND_COOLANT_OFF)
      ( COMMAND_STOP_SPINDLE)
      M0 (MSG Turn OFF spindle)
      M0 (MSG Insert Tool #2 ...)
      ```
      **Pass:** the operator is never invited to reach into the machine without first being told to
      switch the spindle off — those two `M0`s in that order, with no `M5` between them. Before the
      fix this emitted `M5` there and nothing else.
- [ ] **`Home Before Start` — the `XY` and `XYZ` branches have never been posted.** Group `04`'s enum
      replaced an earlier per-axis design, and only its **default carries over verified**: `None` →
      no homing, no motion. *Do:* post with `XY`, then `XYZ`, on GRBL and on Marlin/RRF. *Get:* one
      `$H` on GRBL/FluidNC for **both** modes (`$H` is all-or-nothing, so the mode only documents
      intent); on Marlin/RRF `G28 X` / `G28 Y` for `XY`, plus `G28 Z` for `XYZ`. Then repeat with
      `Prompt Before Home` on: **exactly one** pause before any homing motion, on every firmware and
      axis set. **Pass:** the axis commands match the table in `plan.md` → *Machine frame*, and the
      prompt appears once, not per axis.
- [ ] **`Probe to Set Base = Probe Z` — the no-prompt base variant.** `None` (Info comment, no probe)
      and `Pause, Probe Z, Pause` (attach → probe → detach) are verified (§4); the middle option is
      not. *Do:* reserve `G59`, set `Probe to Set Base = Probe Z`. *Get:* the base `G38.2` and
      `G10 L20 P6 Z<thk>` with **no attach/detach `M0`** either side, and the base-frame select /
      restore / `G0 Z<Inter Part Safe Z>` unchanged from the verified shape. **Pass:** probe present,
      prompts absent.
- [ ] **`writeWCS()` debug/info logging.** At Comment Level `Debug` and `Info`, confirm the WCS
      comments appear, are correctly formatted (no literal `undefined`), and are fully suppressed at
      `Off`/`Important`. Include a job whose **first section uses a non-default WCS** (or that follows
      a job leaving a different WCS active) to confirm the origin/probe lands under the correct
      selection — the `writeWCS()`-first ordering in `writeFirstSection()`.
- [ ] **`wcsDefinitions` offset-0 decision.** Work offset `0` displays unresolved (`#0`) in the
      Operations panel (`useZeroOffset: false`) and silently aliases to WCS 1. Decide whether to leave
      it unresolved, set `useZeroOffset: true`, suppress WCS output, or reset to machine coordinates —
      then verify the choice. Related: the mixed `0`/`1` design warning in `plan.md`'s backlog.
- [ ] **Tool-change ordering + base-relative park matrix** *(after the Phase-4 rework lands)*:
      tool-change-only, WCS-change-only, and a combined boundary, each with and without a reserved
      base. Confirm the re-probe lands in the **new** WCS, repositions to the new part's `X0 Y0`
      first, a combined boundary retracts and probes **once**, and the park is base-relative when a
      base is reserved (else current-WCS).
- [ ] **Spoilboard surfacing on the base (R1).** A multi-WCS job with a section cutting *on* the base
      confirms the following sections' WCS is restored. (A same-WCS two-section job emitting no base
      round-trip is already spot-checked — §4.)

---

## 4. Already verified — do not re-run

Carried over so a later professional pass can tell "looked at, fine" from "never looked at". Every
`.gcode` named here is in Fusion's NC output folder, not the repo.

**Base, guards and frames**

| What | Evidence |
|---|---|
| Base establish probes and retracts **in the base's own frame** (`G59` select → `G38.2` → `G10 L20 P6 Z<thk>` → `G0 Z40` → `G54` restore), and the base probe emits **no XY reposition** | `H7c.gcode` (offsets X10 Y5, so it also evidences P2's base-ignores-offset half) |
| Base `None` (default) is byte-for-byte identical to the pre-base baseline | Phase 3 |
| Base establish `None` → no probe, Info comment `assuming base G59 is already established …`; `Pause, Probe Z, Pause` → attach/probe/detach | Phase 3 |
| **Guard A** — an origin-establishing operation assigned to the reserved base aborts in `onOpen()`, **no `.gcode` written at all**, error names the offending control by its exact dialog title | `H7d.log` (no `H7d.gcode` on disk) |
| **Guard B** (1a–1e) — safe-Z on + 2 WCS + no base → error; toggle off → posts; base reserved → posts; single-WCS exempt; Marlin hits Guard C first | Phase 4 |
| **Guard C** — Marlin with 2+ distinct offsets aborts; single-WCS Marlin posts unchanged | Phase 3 |
| RepRap-only base on GRBL aborts (`Reserved base G59.1 requires RepRap …`); accepted on RepRap. Base reserved on Marlin → base probe skipped with a warning. Guards silent on a valid job | Phase 3 |

**Traverses and added parts**

| What | Evidence |
|---|---|
| Added-part re-probe **repositions to the new part's `X0 Y0`** before probing (was probing the previous part's end point) | `Test2.gcode` |
| Base-relative retract, re-probe path: `G59` → `Z40` → `G55` → `X0 Y0` → `G38.2` → `G10 L20 P2 Z` | `Setup1 Multi.gcode` |
| **Single retract per boundary** — a re-probe boundary transits once, then repositions and probes; no second Safe-Z retract | Test D |
| **Same-WCS boundary** — `WCS unchanged`, no `G59` round-trip (R2) | Test C |
| Probe XY offset: offset `0` first part emits no reposition rapid; nonzero first part repositions to `X10 Y5` on **both** first-part probing modes | `Setup1-Face1.gcode`, `Face1.gcode`, `H7a.gcode` (diffed against `H7.gcode`) |
| The "unknown Z" warning appears only when Z really is unknown — present with no base, **suppressed** with an established base, back again when the base is only assumed pre-set | `H7c-a/-b/-c.gcode` (all three) |

**Header and dialog**

| What | Evidence |
|---|---|
| Full property dump: one `( Properties -- <group>:)` block per group in dialog order, all 68 properties, enums as stored ids, `<empty>` for unset strings | `H7c.gcode` |
| `( Resolved Values:)` Safe-Z lines genuinely **resolve** rather than restate — `Probe SafeZ = Retract level, fallback 15, resolves to 5.08`, matching the `G0 Z5.08` the file emits | `H7c-c.gcode` |
| Property-group reorder reached the header dump in the new order, counts still summing to 68 | `H7c-a/-b/-c.gcode` |
| Beta 1 → Beta 2 baseline: Z-probe default `G38.2` (was `G28`) on Marlin/RepRap, `No` still emits `G28`, GRBL always `G38.2`; Map-G1s group rename displays correctly; `wcsDefinitions` resolves the Operations-panel Work Offset column with single- and multi-WCS output unchanged; the Beta 2 post installs/selects cleanly over the Beta 1 entry | Beta-2 baseline pass |

> **⚠ Stale files, assertions intact.** `Setup1 Multi.gcode`, `Test2.gcode`, `Face1.gcode`,
> `Setup1-Face1.gcode` and the Test A–D files all predate the HR-1 provisional `Z0`, the property
> dump and/or HR-3's stop-block prompt. Their *assertions* stand — HR-1 adds a `Z` word to an
> existing block and emits no motion — but none matches byte-for-byte. Prefer the 2026-07-31 GRBL/mm
> files (`H2`, `H2 - Debug`, `HR1b`, `HR1c`, `HR3b`, `HR5a/b/c`) as a diff baseline.
>
> **Superseded, needs re-verifying under M1:** the old base-relative **non**-re-probe (`Skip`) path
> (Test B) went `G59` → `Z40` → `G55` → straight into cutting. `Skip` now appends `G0 X0 Y0` after
> the switch. Likewise the group-06 relabels verified in the dialog at the time (Test 3 / Test A)
> predate the Current-Pos/Jog taxonomy — re-check via **D1**.

---

## 5. Deferred workstream — jet tools & laser (J1–J5)

**Scope decision (user).** Jet-tool / tool-0 behaviour and laser operations are a **separate
workstream**, reviewed and tested on their own rather than as sub-checks bolted onto milling rows.
Nothing here blocks the WCS/probe work; all of it blocks a release that claims laser/jet support.

The shared mechanic: `tool.number != 0 && !tool.isJetTool()` is the post's "can this tool probe?"
test, and it gates the probe **and** the Z retract on every origin path. So a jet tool or tool 0 takes
a *different branch* in `writeWcsOnStart()`, `writeWCS()`, `partProbe()` and `writeBaseEstablish()` —
and those branches are essentially unexercised.

- [ ] **J1 — first-part origin modes, all six, with a jet tool and with tool 0.** Each must record
      the origin with no probe and no probe prompts; note which also skip the Z retract. Collects the
      deferred sub-checks: `Set X0 Y0 Z0 to Current Pos` (the documented jet/laser path);
      `Use Active WCS X0 Y0 Z0` (emits the `X0 Y0` move but **no** Z retract — M6);
      `Use Active WCS X0 Y0, Probe Z0` (expect Debug `writeWcsOnStart: probe skipped (tool 0 or jet
      tool) -- moving to stored X0 Y0`, a bare `G0 X0 Y0`, no `G38.2`); and **HR-1 (D)** — a jet/tool-0
      job on the default mode must emit `G10 L20 P1 X0 Y0` with **no `Z0`** and no provisional-Z0
      comment, since no probe means no target to bound.
- [ ] **J2 — Subsequent WCS / Part with a jet tool.** The `canProbe` false branches in `writeWCS()`:
      `Probe Z` → move to the stored `X0 Y0` instead of probing; `Jog XY & Probe Z` → jog, write XY,
      no probe.
- [ ] **J3 — spoilboard base with a jet tool.** `writeBaseEstablish()` skips the probe entirely
      (Debug `probe skipped (tool 0 or jet tool)`), so the base is **never established** on a laser
      job even when reserved. Decide whether that should warn rather than pass silently.
- [ ] **J4 — the laser property group** (`09 - Laser`, 7 properties): On Vaporize / On Through / On
      Etch, Marlin mode + pin, GRBL mode, laser coolant — none covered by any row, none appearing in
      the header dump. Plus `11 - Duet` → `B_Duet_LaserMode`.
- [ ] **J5 — laser/jet × the Phase-4 features.** Whether a reserved base, Retract Across Parts and
      the safe-Z retracts are coherent at all for a jet job (no Z probing; Z often fixed by focus).
      **A design review before it is a test** — the answer may be "not applicable, and the dialog
      should say so".

Also on this list: **HR-16** (`onClose` traverses to `X0 Y0` before stopping the spindle, with no
guaranteed safe Z) is recorded in `HReview.md` with no fix proposed, and its jet/laser half — a last
operation that does not retract, so the traverse runs at cut height — is the same line of code.

---

## 6. Design work already scoped elsewhere

Not repeated here; read these before starting the corresponding findings.

- **Tool-change ordering + base-relative park** — `plan.md` → *Remaining work* → *Phase 4 —
  tool-change ordering + base-relative park*. Root cause (`toolChange()` runs before
  `writeWCS()` for non-first sections, so a combined boundary re-probes into the wrong WCS and parks
  in the wrong frame), the four-step fix, and the park-position decision. **HR-7/8/9/10/12/13 land
  with it.**
- **"Copy first part's Z" mode on `Subsequent WCS / Part`** — `plan.md` backlog. A register write for
  same-thickness co-planar fixtures; no motion, no probe.
- **A machine-coordinate base probe point (`G53`)** — `plan.md` → *Future work*. Would replace the
  park-where-you-are precondition on the base probe; carries the "homing makes the WCS trustworthy,
  it doesn't change it" analysis and the standing `Never G53` conflict that must be reconciled across
  all three candidate uses at once.
- **Flip / re-clamp multi-datum work** — future; PA1 covers only the same-fixture re-reference case.
- **Open decision — first-part `Use Active WCS X0 Y0 Z0` with a base reserved.** It retracts to the
  group-06 probe Safe Z *in the part's frame*, so with a base reserved the tool arrives at spoilboard
  + Inter Part Safe Z and then **descends** to a part-relative hop that may not clear a taller clamp
  elsewhere on the bed. Whether `Skip` (both stages) should instead hold the base clearance is
  undecided; it is a verified path, so any change is deliberate. Full write-up in `plan.md`.
