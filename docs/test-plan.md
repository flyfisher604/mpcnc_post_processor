# Beta 2 Test Plan

Verification tracking for `MPCNC_v4.0_Beta1.cps` → `MPCNC_v4.0_Beta2.cps`. **Outstanding**
tests are listed first; **verified** items are summarized below so they aren't re-run.
Design/behavior detail lives in `docs/plan.md`.

---

## Execution runbook — hobbyist & professional flows

End-to-end, persona-driven scenarios covering the current changes (four-mode **Subsequent
Origin**, safe-Z arrival on every WCS change, the first-part **Skip** behavior change, the
group-06 rename, the **First Origin / Subsequent Origin / Probe Pause / Probe with G38.2**
relabels, and the whole-mm integer offsets / Safe Z). **You run these; record the outcome in
each `Result:` line** (`PASS` / `FAIL` + a note, and paste the relevant g-code snippet). The
granular token-level checks (M1–M6, P1–P3) below still apply; each scenario tags which ones it
also satisfies so nothing is double-run.

**Conventions.** Comments are `( ... )` on GRBL and `; ...` on Marlin/RRF — otherwise the tokens
are identical. `G10 L20 P<n>` is GRBL/RepRap; Marlin uses `G92` and rejects >1 WCS (Guard C).
Feed placeholders (`F<travelXY>`) are whatever the job's travel feed resolves to. Default probe
target/speed/thickness = `Z-10` / `F30` / `Z0.8` unless you changed them. Do every scenario on
**GRBL** first (the default firmware); the firmware-variant rows note what changes elsewhere.

### Results summary (fill as you go)

| ID | Scenario | Result |
|----|----------|--------|
| H1 | Hobbyist — single op, default, touch plate | |
| H2 | Hobbyist — single op, no probe (manual Z) | |
| H3 | Hobbyist — firmware variant (Marlin/RRF) | |
| H-REG | Hobbyist — default job byte-for-byte regression | |
| PB1 | Pro B — 2 copies, base, default re-probe | |
| PB2 | Pro B — 2 copies, base, Skip (trust stored) | |
| PBV1 | Pro B-variant — setup run (record fixtures) | |
| PBV2 | Pro B-variant — production run (re-probe Z) | |
| PBV3 | Pro B-variant — production run (trust stored Z) | |
| PA1 | Pro A — multi-datum/flip is refused/steered out | |
| D1 | Dialog & defaults audit (renames, integer fields) | |

---

### Hobbyist — Fusion Personal, a single milling operation

The design goal: **the default dialog posts a correct job with the fewest possible changes.**

- [ ] **H1 — Single op, defaults, with a Z touch plate (the zero-/one-change path).**
      *Setup:* one 3-axis milling op, real tool (tool ≠ 0, not a jet tool), GRBL. Leave **every**
      property at its default (First Origin = `Set Manual X0 Y0, Probe Z0`, Probe Pause =
      `Before & After`). Jog the tool to the part origin before posting.
      *Expected, in order:*
      ```
      G54
      (   Set current X,Y position to 0,0)
      G10 L20 P1 X0 Y0
      ... M0 attach-probe prompt ...
      G38.2 F30 Z-10
      G10 L20 P1 Z0.8
      ... M0 detach-probe prompt ...
      ... retract to probe Safe Z, then the cut ...
      ```
      **Pass:** the only setting a GRBL hobbyist with a plate must touch to post a correct job is
      *none*. XY zeroes at the jogged position, Z probes the stock top, both land in `P1`.
      *Result:* ____

- [ ] **H2 — Single op, no touch plate (manual Z).** Same as H1 but the operator has no probe:
      set **First Origin = `Set Manual X0 Y0 Z0`**. Jog to the part origin (all three axes) first.
      *Expected:*
      ```
      G54
      (   Set current position to 0,0,0)
      G10 L20 P1 X0 Y0 Z0
      ... straight into the cut, no G38.2, no probe prompts ...
      ```
      **Pass:** exactly **one** dialog change (First Origin) converts the flow to a no-probe
      manual touch-off; no `G38.2` is emitted. *Result:* ____

- [ ] **H3 — Firmware variant (Marlin or RRF).** Repeat H1 with Firmware = Marlin (and again RRF
      if you use it). **Pass:** comments switch to `; ...`; Marlin emits `G92` instead of
      `G10 L20`; the single-op flow is otherwise identical. Confirm no spurious multi-WCS warning
      on a single-op Marlin job. *Result:* ____

- [ ] **H-REG — Default-job regression (the key guarantee).** Post the current default single-op
      job and diff it against the pre-rework output for the same job (prior tagged `.cps` or a
      saved reference `.gcode`). **Pass:** **byte-for-byte identical** — the rework must not alter
      the default hobbyist output. *Result:* ____

---

### Professional B — one WCS per copy, milling multiple copies (Replicate)

Use a **2-copy job**: Setup 1 → WCS `1` (G54), Setup 2 → WCS `2` (G55), reserved base **`G59`**,
**Retract Across Parts = On**, real tool. Satisfies P2 and M-series checks as tagged.

- [ ] **PB1 — Default re-probe per copy** (Subsequent Origin = `Use Existing X0 Y0, Probe Z0`,
      the default). *Expected at job start:* base establish `( Establish spoilboard base G59)` →
      `G38.2` → `G10 L20 P6 Z0.8`; then first copy as H1 into `P1`. *Expected at the `P1→P2`
      boundary:*
      ```
      ... transit through base: G59 → G0 Z40 ...
      G55
      (   Move to part origin X0 Y0, then probe Z)
      G0 X0 Y0 F<travelXY>
      G38.2 F30 Z-10
      G10 L20 P2 Z0.8
      ```
      **Pass:** base probes once at start (no XY reposition); each copy re-probes Z at its stored
      XY; the traverse retracts base-relative to `Z40` before switching WCS. *(Satisfies M2, P2.)*
      *Result:* ____

- [ ] **PB2 — Trust the stored Z** (Subsequent Origin = `Skip/Use Existing X0 Y0 Z0`). Same job.
      *Expected at `P1→P2`:*
      ```
      ... G59 → G0 Z40 ...
      G55
      (   Move to this part's stored origin X0 Y0)
      G0 X0 Y0
      ... straight into the cut, no probe ...
      ```
      **Pass:** no `G38.2` on the added copy; the tool still arrives safely at `X0 Y0` after the
      retract (this is the behavior change — `Skip` no longer emits nothing). *(Satisfies M1.)*
      *Result:* ____

---

### Professional B-variant — set the fixtures on run 1, reuse them on later runs

Two distinct jobs against the **same 2-fixture bed**. Reserved base `G59`, Retract Across Parts
On, real tool. This is the workflow the four new manual modes exist for.

- [ ] **PBV1 — Setup run: record each fixture origin.** First Origin = `Set Manual X0 Y0 Z0`,
      Subsequent Origin = `Set Manual X0 Y0, Probe Z0`. Jog to fixture 1 before posting.
      *Expected:* first part records `G10 L20 P1 X0 Y0 Z0` (no probe); at `P1→P2`: retract →
      `G55` → **jog prompt** (`M0 (MSG Jog to this part's X0 Y0 ...)`) → `G10 L20 P2 X0 Y0` →
      `G38.2` → `G10 L20 P2 Z0.8`. **Pass:** every fixture's origin is written to its own register
      (`P1`, `P2`) from an operator jog; the writes persist to the controller (GRBL stores
      `G10 L20` to EEPROM). After the run, confirm on the controller that `G54`/`G55` report the
      set origins. *(Satisfies M3, M4.)* *Result:* ____

- [ ] **PBV2 — Production run: reuse fixtures, re-probe Z.** First Origin =
      `Skip/Use Existing X0 Y0 Z0`, Subsequent Origin = `Use Existing X0 Y0, Probe Z0`. **Do not
      re-jog** — the origins from PBV1 are already stored. *Expected:* first part —
      `(   Use stored work origin; move to X0 Y0 at Safe Z)` → `G0 Z<probeSafeZ>` → `G0 X0 Y0`
      (no origin write, no jog prompt); at `P1→P2` — retract → `G55` → `G0 X0 Y0` → `G38.2` →
      `G10 L20 P2 Z0.8`. **Pass:** no manual/jog prompts anywhere; XY comes from the stored
      fixtures; Z is re-probed per copy for the new stock. *(Satisfies M6, M2.)* *Result:* ____

- [ ] **PBV3 — Production run: trust stored Z too.** Same as PBV2 but Subsequent Origin =
      `Skip/Use Existing X0 Y0 Z0`. **Pass:** no probe anywhere on the added copies; each copy
      just retracts and arrives at its stored `X0 Y0`. Use only when every copy's stock is the
      same thickness as the setup run. *Result:* ____

---

### Professional A — multiple WCS to mill ONE part (multi-datum / flip)

This is **not a supported workflow yet** (see plan.md / memory: it needs the safe-Z model
extended to a re-clamp of the same stock). The test confirms the post *steers the user away*
rather than silently mis-machining.

- [ ] **PA1 — Confirm the out-of-scope guidance and current behavior.** (a) In the dialog,
      confirm both **First Origin** and **Subsequent Origin** tooltips end with *"to mill one part
      from multiple datums/references or a flip, run separate jobs."* (b) Build a deliberate
      flip-style job (one part, Setup 1 top face WCS `1`, Setup 2 bottom face WCS `2`) and post it.
      Record what actually happens — the post currently treats the WCS change like a Replicate
      copy (retract + Subsequent Origin dispatch), which is **not** correct for a re-clamp. **Pass
      (for now):** the tooltip guidance is present and correct; capture the emitted g-code as the
      baseline for the future feature. Do **not** treat a plausible-looking post as "supported."
      *Result:* ____

---

### Dialog & defaults audit

- [ ] **D1 — Labels, groups, and field types.** Open the dialog and confirm: group **`06 - On
      WCS/Part/Fixture Change`** exists (no lingering `Probe / Work Origin`); titles read **First
      Origin**, **Subsequent Origin**, **Probe Pause**, **Probe with G38.2**; the base-establish
      option reads **Pause, Probe Z, Pause**; the Subsequent Origin dropdown lists all four modes
      (`Skip/Use Existing X0 Y0 Z0`, `Use Existing X0 Y0, Probe Z0`, `Set Manual X0 Y0 Z0`,
      `Set Manual X0 Y0, Probe Z0`); **Probe X/Y Offset** and both **Safe Z** fields accept only
      whole numbers (reject a decimal like `2.5`) and are labeled/understood as **whole mm**.
      Cross-check against the fuller **Beta-2 dialog & behavior rework — re-verify** list below.
      *Result:* ____

---

## Outstanding — to run before release

- [ ] **Tapping warning.** Run a tapping operation and confirm the
      `>>> WARNING: Speed-feed synchronization...` comment appears on every
      activate/deactivate occurrence without corrupting the surrounding g-code.
- [ ] **`writeWCS()` debug/info logging.** With Comment Level = Debug and = Info, confirm the
      WCS comments appear, are correctly formatted (no literal `undefined`), and are fully
      suppressed at Off/Important. Include a job whose **first section uses a non-default WCS**
      (or that follows a job leaving a different WCS active) to confirm the origin/probe lands
      under the correct selection (the `writeWCS()`-first ordering in `writeFirstSection()`).
- [ ] **`wcsDefinitions` offset-0 decision.** Work offset `0` currently displays unresolved
      (`#0`) in the Operations panel (`useZeroOffset: false`) and silently aliases to WCS 1.
      Decide whether to leave it unresolved, set `useZeroOffset: true`, suppress WCS output, or
      reset to machine coordinates — then verify the chosen behavior.
- [ ] **Full regression pass.** Re-run the sample jobs (`Test/*.gcode`) and confirm no output
      differences beyond the intended Beta-2 changes. In particular confirm single-WCS,
      no-base jobs are byte-for-byte unaffected.
- [ ] **`isSafeToRapid` true-branch (Map G1s → Rapids).** The prior full-F360 run
      (`2D Contour1.gcode`) stayed at Z ≤ 1mm, below the 5mm safe height, so every
      `isSafeToRapid` call returned `false` and the `zConstant` / `zUp` /
      `zDown-with-curZSafe` conversion branches were **never exercised** — only the conservative
      refusal was. Generate a toolpath with a horizontal link/transition move at or above safe-Z
      (e.g. multiple contours with a linking move at retract height) to actually validate the
      G1→G0 conversion. Ties to the Phase 5 rapid-mapping review in the plan.

## To test when built — Phase 4 remaining (see plan)

- **Tool-change ordering + base-relative park.** Matrix: tool-change-only, WCS-change-only,
  and a combined boundary — each with and without a reserved base. Confirm the re-probe lands
  in the *new* WCS, repositions to the new part's `X0 Y0` first, a combined boundary retracts
  and probes **once**, and the park is base-relative when a base is reserved (else current-WCS).
- **Spoilboard-surfacing on the base (R1).** A multi-WCS job with a section cutting on the base
  confirms following sections' WCS is restored; a same-WCS two-section job emits no base
  round-trip (already spot-checked in Test C).

## Beta-2 dialog & behavior rework — re-verify

This session reworked the dialog and several probe/homing behaviors; defaults are intended
byte-identical. Re-verify:

- **Group split & renumber.** `03 - Spoilboard Base` (4 items) right after machine homing;
  `06 - On WCS/Part/Fixture Change` (10 items) after Map G1s; downstream groups renumber through
  `11 - Duet`. Items order by letter prefix within each group. Renamed / re-lettered keys reset
  saved presets to default (release-notes item).
- **Label renames** display correctly: Reserved WCS, Probe to Set Base, Retract Across Parts,
  Safe Z (Spoilboard group), First Origin. Later renames: group `06` → **On WCS/Part/Fixture
  Change**; `A_Probe_OnStart` → **First Origin**; `B_Probe_OnChange` → **Subsequent
  Origin**; `C_Probe_Pause` → **Probe Pause**; base-establish option → **Pause, Probe Z, Pause**;
  origin-mode options → `Skip/Use Existing X0 Y0 Z0` / `Use Existing X0 Y0, Probe Z0` (added-part
  only) / `Set Manual X0 Y0 Z0` / `Set Manual X0 Y0, Probe Z0`. Ids unchanged (labels only), except
  the two new added-part options reset a saved `B_Probe_OnChange` preset.
- **Group 02 — Home Before Start** (None / XY / XYZ). `None` (default) → no homing,
  byte-identical. `XY` → one `$H` (GRBL/FluidNC) or `G28 X` / `G28 Y` (Marlin/RRF). `XYZ` → also
  `G28 Z` (Marlin/RRF; GRBL `$H` already homes all configured axes). `Prompt Before Home`
  (default off) pauses once before any homing, on every firmware and axis set.
- **Probe to Set Base** enum: `None` → Info "assumed pre-set", no probe; `Probe Z` → probe with
  no attach/detach prompt; `Pause, Probe Z, Pause` (default) → attach → probe → detach
  (byte-identical to the old On). Still writes `G10 L20 P<base> Z<thk>` at the origin.
- **Probe Pause** (No / Before / Before & After). Gates the `Attach ZProbe` (before) /
  `Detach ZProbe` (after) prompts on the first + added part probes: `No` = neither, `Before` =
  attach only, `Before & After` (default) = both (byte-identical). The tool-change re-probe
  still prompts (out of scope).
- **Probe XY offset** (`D_Probe_OffsetX` / `E_Probe_OffsetY`) — see the dedicated
  **[Probe XY offset — verification steps](#probe-xy-offset--verification-steps)** section below.
  The offset-`0` first-part path and the base probe are already NC-confirmed (see Verified);
  the nonzero and added-part paths need a hands-on run.
- **Regression:** a single-WCS, no-base, default-settings job is byte-for-byte unchanged after
  all the above.

---

## Probe XY offset — verification steps

Purpose: confirm the part Z-probe touch-point moves to *origin + (offsetX, offsetY)* at the
**first part and each added part**, while the **spoilboard base probe stays at the origin** and a
**zero offset stays byte-identical**. Firmware note: comments are `(...)` on GRBL and `;...` on
Marlin/RRF — the tokens below are otherwise identical. Coordinates are in the job's output units
(the emitted `G0 X/Y` values should equal the offsets you entered; check this in an inch job too).

Already confirmed by NC inspection — **do not re-run** (see Verified → Phase 4):
- Offset `0,0`, first/only part: no reposition, straight from `G10 L20 P1 X0 Y0` into `G38.2`.
- Spoilboard base probe: always touches off at the origin, no `G0 X/Y` before its `G38.2`.

Run these:

- [x] **P1 — Nonzero offset, first/only part.** ✅ **Verified** via `Face1.gcode` (single part,
      offset X10 Y5, base `G59` reserved — GRBL/inch-doc-in-mm-out): `G10 L20 P1 X0 Y0` →
      `X10 Y5 F2500` (G0 modal reposition) → `G38.2 F30 Z-10` → `G10 L20 P1 Z0.8`; the reserved
      base probed with **no** reposition (`G10 L20 P6 Z0.8`), confirming the base ignores the
      offset. (Original procedure below, for reference.) Single-WCS, **no base**. Set
      `Probe X Offset = 10`, `Probe Y Offset = 5`; `First Origin = Set Manual X0 Y0, Probe Z0`;
      one real milling op (tool ≠ 0, not a jet tool). Post and confirm the first-part probe reads:
      ```
      (   Set current X,Y position to 0,0)
      G10 L20 P1 X0 Y0
      (   Move to probe point = origin + offset X10 Y5, then probe Z)
      G0 X10 Y5 F<travelXY>
      G38.2 F30 Z-10
      G10 L20 P1 Z<thickness>
      ```
      **Pass:** the `Move to probe point = origin + offset X10 Y5` comment and the `G0 X10 Y5`
      reposition appear *before* `G38.2`; the emitted `X`/`Y` equal the entered offsets; the Z
      result is still written to `P1`. *(Note: the earlier `Face1.gcode` post that verified the
      reposition predates the comment-wording fix, so it showed the old parenthesised form — the
      motion is unchanged; only the comment text changed.)*

- [ ] **P2 — Nonzero offset, multi-part Replicate + reserved base.** 2-part Replicate job (WCS
      `P1` + `P2`), **reserved base `G59`**, `Subsequent Origin = Use Existing X0 Y0, Probe Z0`, same `10/5` offsets.
      Post and confirm all three probes:
      - **Base (`G59`)** — `( Establish spoilboard base G59)` → `G38.2` → `G10 L20 P6 Z<thk>` with
        **no `G0 X/Y` reposition** (base ignores the offset).
      - **First part (`P1`)** — reposition to `X10 Y5` before `G38.2`, exactly as P1 above.
      - **Added part (`P2`)** — with `Subsequent Origin = Use Existing X0 Y0, Probe Z0` (Replicate auto-position):
        ```
        (   Move to probe point = origin + offset X10 Y5, then probe Z)
        G0 X10 Y5 F<travelXY>
        G38.2 F30 Z-10
        G10 L20 P2 Z<thickness>
        ```
      **Pass:** both part probes reposition to `(10, 5)`; the base probe does **not**.

- [ ] **P3 — Zero-offset added-part regression** (the one offset-`0` path not yet on disk). Same
      2-part job as P2 but `Probe X/Y Offset = 0`. Confirm each **added** part emits the bare-origin
      form (no offset wording):
      ```
      (   Move to part origin X0 Y0, then probe Z)
      G0 X0 Y0 F<travelXY>
      G38.2 F30 Z-10
      G10 L20 P2 Z<thickness>
      ```
      **Pass:** comment says `part origin X0 Y0` (not `probe point = origin + offset ...`), and the
      first/only part still shows **no** reposition at all (byte-identical to prior output).

---

## Subsequent Origin — new modes (verification steps)

`B_Probe_OnChange` now has four modes across two coexisting workflows. Use a **2-part Replicate
job** (WCS `P1` + `P2`), a reserved base `G59` + Retract Across Parts on, tool ≠ 0. On each added
part, every mode first **retracts to a safe Z, then acts** — confirm that retract precedes any XY
move. Marlin is out of scope (single frame; Guard C blocks multi-WCS).

- [ ] **M1 — `Skip` reaches X0 Y0 safely (behavior change).** `Subsequent Origin = Skip/Use Existing X0 Y0 Z0`. On the
      `P1→P2` boundary confirm: base-relative retract (`G59` → `Z<SafeZ>`) → `G55` → **`G0 X0 Y0`**
      → straight into cutting, **no probe**. The `G0 X0 Y0` after the WCS switch is the new
      "do-nothing-but-arrive-safely" move (previously `Skip` went straight into cutting with no
      X0 Y0 rapid — this supersedes the old Verified "Test B" behavior).
- [ ] **M2 — `Probe Z` (Replicate auto-position).** `Subsequent Origin = Use Existing X0 Y0, Probe Z0`. Confirm the
      existing behavior is unchanged: retract → `G55` → rapid to `X0 Y0` (+ offset) → `G38.2` →
      `G10 L20 P2 Z`. XY comes from `P2`'s stored offset (not re-zeroed).
- [ ] **M3 — `Set Manual X0 Y0 Z0` (manual, no probe).** `Subsequent Origin = Set Manual X0 Y0 Z0`. Confirm:
      retract → `G55` → **jog prompt** (`M0 (MSG Jog to this part's X0 Y0 and touch off Z...)` on
      GRBL/Marlin; RepRap `M291 ... S3 X1 Y1 Z1`) → `G10 L20 P2 X0 Y0 Z0` (Marlin: `G92`) → cutting.
      **No probe, no auto XY move.**
- [ ] **M4 — `Set Manual X0 Y0, Probe Z0` (manual).** `Subsequent Origin = Set Manual X0 Y0, Probe Z0`. Confirm:
      retract → `G55` → **jog prompt** → `G10 L20 P2 X0 Y0` → probe (`G38.2` → `G10 L20 P2 Z`),
      with the attach/detach prompts following the separate **Probe Pause** dropdown. With a nonzero
      probe offset, the probe repositions to `(offsetX, offsetY)` after the jog.
- [ ] **M5 — Single-WCS regression.** A single-WCS job (no added parts) is **byte-for-byte
      unchanged** — `writeWCS()` returns at "WCS unchanged", so none of the new dispatch runs.
- [ ] **M6 — First-part `Skip` now reaches X0 Y0 (behavior change).** `First Origin = Skip`,
      milling tool. Confirm the first section now emits `G0 Z<probeSafeZ>` then
      `G0 X0 Y0` (retract, then move to the stored origin) instead of nothing. A jet/tool-0
      first-part `Skip` emits the `X0 Y0` move but **no** Z retract. Default (`Zero XY, Probe Z`)
      first-part output is unchanged.

---

## Verified

### Beta 1 → Beta 2 baseline
- Z-probe default now `G38.2` (was `G28`) on Marlin/RepRap; `No` still emits `G28`; GRBL always
  `G38.2`.
- "Map G1s to Rapids" group rename displays correctly; 4 properties unchanged in behavior.
- `wcsDefinitions` resolves the Operations-panel Work Offset column (`G54` etc.); single- and
  multi-WCS output unchanged. *(Offset-0 display is the open decision above.)*
- `MPCNC_v4.0_Beta2.cps` installs/selects cleanly, replacing the Beta 1 entry.

### Phase 2 — establish MCS (homing)
- Verified against the original **per-axis** design, now **superseded** by the Group-02 rework
  (per-axis X/Y/Z → one `Home Before Start` enum; the prompt is now firmware/axis-independent).
  Only the default carries over unchanged: default → no homing, byte-identical. The new
  behavior is in *Beta-2 dialog & behavior rework — re-verify* above.

### Phase 3 — reserved base + guards
- Base `None` (default): byte-for-byte identical to the Phase-2 baseline.
- Base establish (now `Pause & Probe Z`, was On): spoilboard probe → `G10 L20 P6 Z<thk>`
  **before** the first section's own origin/probe; `G54` work still probes separately.
- Base establish `None` (was Off): no probe; Info comment
  `assuming base G59 is already established -- from a prior job or set manually`.
  *(The new `Probe Z` variant — probe with no attach/detach prompt — is in the re-verify list.)*
- **Guard A:** assigning an origin-establishing op to the reserved base aborts in `onOpen()`
  (`G59 is reserved as the spoilboard base -- assign this operation to another WCS ...`), naming
  the triggering feature; no g-code emitted.
- **Guard C:** Marlin job with 2+ distinct offsets aborts
  (`Marlin has a single coordinate frame ...`); single-WCS Marlin posts unchanged.
- RepRap-only base on GRBL aborts (`Reserved base G59.1 requires RepRap ...`); accepted on RepRap.
- Base reserved on Marlin: base probe skipped, warning that the base is ignored.
- Guards silent on a valid job (incl. base reserved + section on a different WCS).

### Phase 4 — consume the base (landed portion)
- **Guard B** (1a–1e): safe-Z on + 2-WCS + no base → error; toggle off → posts; base reserved →
  posts; single-WCS exempt; Marlin hits Guard C first.
- **Added-part re-probe repositions** (`Test2.gcode`): `Z<SafeZ>` → `G55` → `X0 Y0` → `G38.2` →
  `G10 L20 P2 Z` (was probing the previous part's end point).
- **First-part probe unchanged:** `G10 L20 P1 X0 Y0` + probe at the parked position, no `X0 Y0`
  rapid.
- **WCS/Probe relabels + default flip** verified in the dialog (Test 3) at the time; the group
  has since been split and keys renamed/re-lettered (see re-verify above), so the dialog needs
  another pass. First-part middle option shows `Zero XYZ (no probe)` (Test A).
- **Base-relative retract, re-probe path** (`Setup1 Multi.gcode`): `baseRelative: true base: 6`
  → `G59` → `Z40` → `G55` → `X0 Y0` → `G38.2` → `G10 L20 P2 Z`.
- **Base-relative retract, non-re-probe (Skip) path** (Test B): `baseRelative: true …` → `G59` →
  `Z40` → `G55`, straight into cutting, no probe. **⚠ Superseded** by the added-part redesign —
  `Skip` now appends `G0 X0 Y0` after the switch (safe arrival at the stored origin); re-verify
  under *Subsequent Origin — new modes* → M1.
- **Single retract per boundary** (Test D): re-probe boundary transits once (`G59`/`Z40`), then
  `X0 Y0`/probe — no second Safe-Z retract.
- **Same-WCS boundary** (Test C): `WCS unchanged`, no `G59` round-trip.
- **Probe XY offset — offset `0` first part + base probe** (NC inspection of `Setup1-Face1.gcode`,
  current-post `G10 L20`/`G38.2` output): the first/only part goes `G10 L20 P1 X0 Y0` →
  `( COMMAND_TOOL_MEASURE)` → `G38.2` with **no reposition rapid** (byte-identical); the reserved
  `G59` base probes with **no `G0 X/Y`** before its `G38.2` → `G10 L20 P6 Z0.8` (offset never
  applies to the base). Nonzero and added-part paths remain in *Probe XY offset — verification
  steps* (P1–P3) — no on-disk NC file exercises them yet.
