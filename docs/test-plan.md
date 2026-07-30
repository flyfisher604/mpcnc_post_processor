# Beta 2 Test Plan

Verification tracking for `MPCNC_v4.0_Beta1.cps` → `MPCNC_v4.0_Beta2.cps`. **Outstanding**
tests are listed first; **verified** items are summarized below so they aren't re-run.
Design/behavior detail lives in `docs/plan.md`.

---

## Execution runbook — hobbyist & professional flows

End-to-end, persona-driven scenarios covering the current changes (the reworked **First /
Subsequent WCS / Part** origin modes — an explicit *Set … to Current Pos* (no prompt) vs *Jog to …*
(M0 jog prompt) taxonomy, with the **no-prompt modes as the defaults** — First = `Set X0 Y0 to
Current Pos, Probe Z0`, Subsequent = `Use Active WCS X0 Y0, Probe Z0` (the `Jog to …` modes are opt-in
because jogging at the pause isn't supported on every firmware/sender); the new first-part
`Use Active WCS X0 Y0, Probe Z0` mode (**H7**); safe-Z arrival
on every WCS change; the first-part **Skip** behavior change; the group-06 rename; and the whole-mm
integer offsets / Safe Z). **You run these; record the outcome in each `Result:` line** (`PASS` /
`FAIL` + a note, and paste the relevant g-code snippet). The granular token-level checks (M1–M6,
P1–P3) below still apply; each scenario tags which ones it also satisfies so nothing is double-run.

**Where the g-code goes.** Posted files referenced by name below (`H7.gcode`, `H7a.gcode`,
`H6 - RRF.gcode`, `Face1.gcode`, …) are written to Fusion's NC output folder —
`C:\Users\don_m\Documents\Fusion 360\NC Programs\` — not into the repo. Name each post after its
test row so a later review can find it. Diffing two of them is often the fastest check (that is how
H7a was verified: `Compare-Object` showed only the two intended lines changed).

**Conventions.** Comments are `( ... )` on GRBL and `; ...` on Marlin/RRF — otherwise the tokens
are identical. `G10 L20 P<n>` is GRBL/RepRap; Marlin uses `G92` and rejects >1 WCS (Guard C).
Feed placeholders (`F<travelXY>`) are whatever the job's travel feed resolves to. Default probe
target/speed/thickness = `Z-10` / `F30` / `Z0.8` unless you changed them. The default First WCS /
Part mode is `Set X0 Y0 to Current Pos, Probe Z0` and Subsequent is `Use Active WCS X0 Y0, Probe Z0`
— both no-prompt; the `Jog to …` modes (which emit an `M0` jog prompt) are opt-in. Do every scenario
on **GRBL** first (the default firmware); the
firmware-variant rows note what changes elsewhere.

### Results summary (fill as you go)

| ID | Scenario | Result |
|----|----------|--------|
| H1 | Hobbyist — single op, `Jog to X0 Y0, Probe Z0` (opt-in jog mode) | PASS |
| H2 | Hobbyist — single op, **default** `Set X0 Y0 to Current Pos, Probe Z0` (no-prompt) | PASS |
| H3 | Hobbyist — single op, `Jog to X0 Y0 Z0` (manual Z, jog) | PASS |
| H4 | Hobbyist — single op, `Set X0 Y0 Z0 to Current Pos` (manual Z, no prompt) | PASS *(jet/tool-0 → J1)* |
| H5 | Hobbyist — single op, `Use Active WCS X0 Y0 Z0` (trust stored) | PASS |
| H6 | Hobbyist — firmware variant (Marlin/RRF), `Jog to X0 Y0, Probe Z0` | PASS (Marlin + RRF) |
| H7 | Hobbyist — single op, `Use Active WCS X0 Y0, Probe Z0` (new mode) | PASS — incl. H7a *(H7b–H7e unrun)* |
| H-REG | Hobbyist — byte-for-byte regression via the H2 path | OMITTED (see row) |
| PB1 | Pro B — 2 copies, base, re-probe per copy (`Use Active WCS X0 Y0, Probe Z0`) | |
| PB2 | Pro B — 2 copies, base, `Skip` (trust stored) | |
| PBV1 | Pro B-variant — setup run (record fixtures) | |
| PBV2 | Pro B-variant — production run (re-probe Z) | |
| PBV3 | Pro B-variant — production run (trust stored Z) | |
| PA1 | Pro A — 2nd WCS same part/fixture, `Jog to X0 Y0, Probe Z0` | |
| PA1b | Pro A — 2nd WCS same part, Z-only re-probe (`Use Active WCS X0 Y0, Probe Z0`) | |
| D1 | Dialog & defaults audit (modes, renames, integer fields) | |
| D2 | Header property dump — all 68 properties + resolved values | |

---

### Hobbyist — Fusion Personal, a single milling operation

The design goal: **the default dialog posts a correct job with the fewest possible changes.** A
single op has no WCS change, so only **First WCS / Part** is exercised — these rows walk all six of
its modes. The default is now **H2** (`Set X0 Y0 to Current Pos, Probe Z0`, no prompt); H1 is the
opt-in guided-jog path. Do them on **GRBL**, one 3-axis milling op, real tool (tool ≠ 0, not a jet
tool) unless a row says otherwise.

> **Retest determination (reviewed against commits `5d89838` → `01c69a3`).** **No H row needs a
> functional retest.** The only change to any already-verified H path is **operator-prompt text**:
> four `askUser()` strings were shortened and the RepRap dialog title `"Set part origin"` became
> `"Set origin"`. Motion, origin writes, probe commands, and comment structure are untouched, so
> H1–H6 stand as verified. Consequences to be aware of when re-reading the saved g-code:
> - **H1 / H3** — their `.gcode` files predate the wording change (each row already notes it), so
>   their `M0 (MSG …)` text differs from the expected blocks below, which carry the **current**
>   wording. Cosmetic — do not re-post for this.
> - **H2 / H4 / H5** — no operator prompt on these paths at all; wholly unaffected.
> - **H6** was re-posted after the spurious-Marlin-warning removal, and that removal shipped in the
>   *same* commit (`01c69a3`) as the wording change — so `H6 - Marlin.gcode` / `H6 - RRF.gcode`
>   should already show the current message text (and RRF the current `R"Set origin"` title, since
>   RRF is the only firmware that emits the `askUser` title). Spot-check if in doubt; no re-post.
>
> What the recent commits *did* leave untested is a **whole new sixth mode**, `Use Active WCS X0
> Y0, Probe Z0` on First WCS / Part — a new branch in `writeWcsOnStart()`. That is **H7** below.

- [x] **H1 — `Jog to X0 Y0, Probe Z0` (opt-in guided-jog path).** Set First WCS / Part = `Jog to X0
      Y0, Probe Z0` (**no longer the default**); Probe Pause = `Before & After`.
      *Expected, in order:*
      ```
      G54
      M0 (MSG Jog to X0 Y0 above Z0, probe)
      (   Set current X,Y position to 0,0)
      G10 L20 P1 X0 Y0
      ... M0 attach-probe prompt ...
      G38.2 F30 Z-10
      G10 L20 P1 Z0.8
      ... M0 detach-probe prompt ...
      ... retract to probe Safe Z, then the cut ...
      ```
      **Pass:** with the jog mode selected the job pauses (`M0`) for the operator to jog to the part
      origin, then zeroes XY there and probes Z — both into `P1`. *Result:* **PASS** — verified against
      `H1.gcode`: `G54` → `M0` jog prompt → `G10 L20 P1 X0 Y0` → `G38.2 F30 Z-10` → `G10 L20 P1 Z0.8`,
      both writes into `P1`. G-code independently checked as valid/collision-safe (modal G0 across the
      section boundary, all arcs close, safe retract ordering). *(Jog `M0` message wording was
      operator-edited; unscaled CAM feeds/DOC pass through as designed — not H1 concerns.)*

- [x] **H2 — Default `Set X0 Y0 to Current Pos, Probe Z0` (pre-jog, no prompt — the zero-change
      path).** Leave **every** property at its default (First WCS / Part = `Set X0 Y0 to Current Pos,
      Probe Z0`, Probe Pause = `Before & After`). Jog to the part origin (XY) **before** posting.
      *Expected:* identical to H1 **but with no `M0` jog prompt** — straight `G54` →
      `(   Set current X,Y position to 0,0)` → `G10 L20 P1 X0 Y0` → probe. **Pass:** with zero
      settings touched this reproduces the **pre-rework default output** (no jog prompt; XY zeroes at
      the parked position) and is the H-REG regression anchor below. *(Matches P1's offset-0
      first-part shape.)* *Result:* **PASS** —
      verified against `H2.gcode`: `G54` steps straight into `START begin` with **no jog `M0`** →
      `(   Set current X,Y position to 0,0)` → `G10 L20 P1 X0 Y0` → `M0 (MSG Attach ZProbe)` →
      `G38.2 F30 Z-10` → `G10 L20 P1 Z0.8` → `M0 (MSG Detach ZProbe)`, both writes into `P1`. Real
      tool (T171), GRBL comments. Confirms the pre-rework default shape; ready as the H-REG anchor.

- [x] **H3 — `Jog to X0 Y0 Z0` (manual Z, jog prompt, no probe).** One change: First WCS / Part =
      `Jog to X0 Y0 Z0` (operator with no probe). *Expected:*
      ```
      G54
      M0 (MSG Jog to X0 Y0 Z0, then continue)
      (   Set current position to 0,0,0)
      G10 L20 P1 X0 Y0 Z0
      ... straight into the cut, no G38.2, no probe prompts ...
      ```
      **Pass:** the job pauses to jog all three axes to the origin, records `X0 Y0 Z0`, and cuts — no
      `G38.2`. *Result:* **PASS** — verified against `H3.gcode`: `G54` → jog `M0` prompt →
      `(   Set current position to 0,0,0)` → `G10 L20 P1 X0 Y0 Z0` (all three axes, `Z0` present) →
      straight into the cut. **No `G38.2`** and **no probe attach/detach `M0`** anywhere. Real tool
      (T171), GRBL. *(Jog `M0` wording was operator-edited since — now `Jog to X0 Y0 Z0, then
      continue` — a non-functional change, per the H1 note.)*

- [x] **H4 — `Set X0 Y0 Z0 to Current Pos` (manual Z, no prompt).** Same as H3 but First WCS / Part =
      `Set X0 Y0 Z0 to Current Pos`; jog to the part origin (all three axes) **before** posting.
      *Expected:* `G54` → `(   Set current position to 0,0,0)` → `G10 L20 P1 X0 Y0 Z0` → cut, with
      **no `M0` jog prompt and no probe**. **Pass:** one dialog change gives a fully manual no-prompt
      touch-off (the old H2 behavior). This is also the jet/laser path — a jet tool or tool 0 records
      the origin with no probe regardless. *Result:* **PASS** — verified against `H4.gcode`: `G54`
      steps straight into `START begin` with **no jog `M0`** → `(   Set current position to 0,0,0)` →
      `G10 L20 P1 X0 Y0 Z0` (all three axes) → straight into the cut. **No `G38.2`** and **no probe
      attach/detach `M0`** anywhere (the sole `M0` is the spindle manual-on prompt). Real tool (T171),
      GRBL. Confirms the pre-rework fully-manual touch-off shape. *(Jet/tool-0 sub-check **deferred to
      J1** — see [Jet tools & laser operations](#jet-tools--laser-operations--deferred).)*

- [x] **H5 — `Use Active WCS X0 Y0 Z0` (trust the stored origin).** First WCS / Part =
      `Use Active WCS X0 Y0 Z0`; the WCS already holds an origin (prior job / set manually).
      *Expected:*
      ```
      G54
      (   Use stored work origin; move to X0 Y0 at Safe Z)
      G0 Z<probeSafeZ>            ; milling tool only
      G0 X0 Y0 F<travelXY>
      ... straight into the cut, no origin write, no probe ...
      ```
      **Pass:** no `G10`/`G92` origin write and no probe; a milling tool retracts to the probe Safe Z
      first, then rapids to the stored `X0 Y0` (behavior change — first-part `Skip` no longer emits
      nothing). A jet/tool-0 `Skip` emits the `X0 Y0` move but **no** Z retract. *(Satisfies M6.)*
      *Result:* **PASS** — verified against `H5.gcode`.

- [x] **H6 — Firmware variant (Marlin or RRF).** Repeat H1 (`Jog to X0 Y0, Probe Z0`) with Firmware = Marlin
      (and again RRF if you use it). **Pass:** comments switch to `; ...`; Marlin emits `G92` instead
      of `G10 L20`; the jog prompt and single-op flow are otherwise identical. Confirm no spurious
      multi-WCS warning on a single-op Marlin job. *Result:* **Marlin: PASS** — verified against
      `H6 - Marlin.gcode`: `; ...` comments, `M84 S0` startup (no `G94`/`G17` — Marlin is units/min
      and XY-plane-arc only), **no `G54`**, `G92 X0 Y0` → `G38.2 F30 Z-10` → `G92 Z0.8` (G92 not
      `G10 L20`), plain-text `M0` jog/probe prompts, GRBL helical lead-in linearized to `G1`. First
      post emitted a **spurious** `Subsequent WCS / Part` multi-WCS warning on this single-op job;
      fixed by removing the unreachable warning block in `writeWCS()` (Guard C already blocks real
      multi-WCS Marlin jobs), re-posted clean. **RRF: PASS** — verified against `H6 - RRF.gcode`:
      `; ...` comments and `M84 S0` startup (no `G94`/`G17`) like Marlin, but `G54` **is** emitted and
      origin writes are `G10 L20 P1 …` (not `G92`); every operator pause is an `M291 … S3` dialog, with
      `X1 Y1 Z1` jog buttons on the jog prompt only. Single `G38.2`, no spurious warning, helical
      lead-in linearized to `G1`.

- [ ] **H7 — `Use Active WCS X0 Y0, Probe Z0` (new mode: stored XY, re-probe Z).** The sixth
      First WCS / Part mode, added in `01c69a3` — the no-prompt first-part path for a pre-set
      fixture: trust the WCS's stored X0 Y0, re-probe Z for the new stock. First WCS / Part =
      `Use Active WCS X0 Y0, Probe Z0`; `G54` already holds a valid X0 Y0 (prior job or set at
      the controller); Probe Pause = `Before & After`; Probe X/Y Offset = `0`; **no base**; real
      tool. Park the tool clear in Z before starting (see the Z note below). *Expected:*
      ```
      G54
      (   Use stored work origin X0 Y0; probe Z)
      (   Move to part origin X0 Y0, then probe Z)
      G0 X0 Y0 F<travelXY>
      ... M0 attach-probe prompt ...
      G38.2 F30 Z-10
      G10 L20 P1 Z0.8
      G0 Z<probeSafeZ>
      ... M0 detach-probe prompt ...
      ... into the cut ...
      ```
      **Pass — the discriminator is what is ABSENT:** **no `G10 L20 P1 X0 Y0`** (XY is not
      re-zeroed — this is the only difference from H2), no jog `M0`, and **no `G0 Z` before the
      `G0 X0 Y0`**. Both Info comments appear, in that order. Z is written to `P1` by the probe.
      **Z note (by design, worth confirming):** with no base reserved this mode emits *no* Z move
      before the XY traverse — Z is stale pending the probe, so the post refuses to make an
      absolute Z move in that frame and instead traverses at whatever height the tool physically
      sits at from job start. Record that height. *Result:* **PASS** — verified against `H7.gcode`
      (GRBL, single op, T171, no base, offsets 0): `G54` → `(   Use stored work origin X0 Y0; probe
      Z)` → `(   Move to part origin X0 Y0, then probe Z)` → `G0 X0 Y0 F2500` as the **first motion
      in the program** → `M0 (MSG Attach ZProbe)` → `G38.2 F30 Z-10` → `G10 L20 P1 Z0.8` → `G0
      Z5.08` → `M0 (MSG Detach ZProbe)`. **No `G10 L20 P1 X0 Y0`** (the discriminator vs H2), no jog
      `M0`, and no `G0 Z` before the traverse. Arcs/plane restores and section rapids independently
      checked sound. **Follow-up filed:** the file gives the operator no cue that the first rapid's Z
      is unknown — plan.md calls for an Info comment (`Ensuring that Z is safe. Unknown Z for XY
      move.`) on this branch. **H7a PASS** (see below); **H7b deferred to J1**; **H7c/H7d/H7e remain
      unrun** (this job had no base and was GRBL only).

  Sub-checks:

  - [x] **H7a — nonzero offset.** Same job with Probe X/Y Offset = `10` / `5`. Confirm the comment
        becomes `(   Move to probe point = origin + offset X10 Y5, then probe Z)` and the rapid is
        `G0 X10 Y5`, still with **no** `G10 L20 P1 X0 Y0`. (Closes the first-part `Probe Z` ×
        offset gap: P1 covers the offset only on the `Set X0 Y0 to Current Pos` path.)
        *Result:* **PASS** — verified against `H7a.gcode`, diffed against `H7.gcode`: apart from the
        timestamp the **only** two differing lines are the expected ones — the comment
        `(   Move to probe point = origin + offset X10 Y5, then probe Z)` replacing
        `(   Move to part origin X0 Y0, then probe Z)`, and `G0 X10 Y5 F2500` replacing
        `G0 X0 Y0 F2500`. Still **no** `G10 L20 P1 X0 Y0` (the only `G10` is `G10 L20 P1 Z0.8`), and
        the emitted X/Y equal the entered whole-mm offsets in an mm-output job. The offset is fully
        localised to the probe-point reposition — Z retract, section body, and STOP block are
        byte-identical to H7, so a nonzero offset perturbs nothing downstream.

  - **H7b — jet tool / tool 0. → DEFERRED** to
    **[Jet tools & laser operations](#jet-tools--laser-operations--deferred)** (J-series). The
    milling assertions above don't depend on it, so H7 is complete without it.

  - [ ] **H7c — Base probe runs in the base's frame; traverse clears the stock.** Verifies the
        base-frame probe/retract fix. *(Mechanism and history: plan.md, "first-part `Probe Z` mode's
        traverse height when a base is reserved".)*

        **Settings.** GRBL, real tool, one milling op. Reserved WCS = `G59`; Probe to Set Base =
        `Pause, Probe Z, Pause`; Inter Part Safe Z = `40`; First WCS / Part = `Use Active WCS X0 Y0,
        Probe Z0`; Probe X/Y Offset = `0`.

        **Bed setup** (makes the stale datum as bad as it realistically gets):
        1. At the controller, set `G54`'s origin on the **bare spoilboard** — jog to the intended
           part X0 Y0, touch off on the spoilboard, zero X/Y/Z.
        2. Clamp stock **≥19 mm** thick, positioned so the path from the base probe point to
           `X0 Y0` crosses it.

        **Expected g-code:**
        ```
        ( Establish spoilboard base G59)
        (   Select base G59 to probe and retract in its own frame)
        G59
        ... M0 attach-probe prompt ...
        G38.2 F30 Z-10
        G10 L20 P6 Z0.8
        G0 Z40                       ( Inter Part Safe Z, in the BASE frame )
        ... M0 detach-probe prompt ...
        (   Restore operating WCS G54 after base probe)
        G54
        (   Use stored work origin X0 Y0; probe Z)
        G0 X0 Y0 F<travelXY>
        ```

        **Pass — static:** `G59` appears *before* the `G38.2`; the retract is `G0 Z40` (matching
        `(   Retract the tool to 40)`) and **not** the group-06 probe Safe Z; the `G54` restore
        appears before the `Use stored work origin` line; the base probe has **no `G0 X/Y`**
        reposition.

        **Pass — physical** (dry-run: spindle off, E-stop in hand, single-block through the `G0 Z40`
        and `G54`, measure *before* letting `G0 X0 Y0` run): the tool sits **40 mm above the
        spoilboard**, ~21 mm clear of the stock, and the `G54` reselect moves nothing.
        *Result:* ____

  - [ ] **H7d — Guard A still fires for this mode.** Assign the first section to the reserved base
        WCS (e.g. base `G59`, Setup WCS = `6`) with First WCS / Part = `Use Active WCS X0 Y0,
        Probe Z0`. **Pass:** the post aborts in `onOpen()` naming `Probe at Job Start`, with no
        g-code emitted — the new mode writes a Z origin, so it must count as origin-establishing
        (`baseOriginWriteReason()` classifies every mode except `Skip` that way). *Result:* ____

  - [ ] **H7e — firmware variant (low priority).** Repeat H7 on Marlin and RRF. **Pass:** Marlin
        emits `G92 Z0.8` only (no XY word, no `G54`); RRF emits `G54` + `G10 L20 P1 Z0.8` with
        `M291 … S3` probe prompts. No jog buttons (`X1 Y1 Z1`) — this mode has no jog prompt.
        *Result:* ____

- [ ] **H-REG — Byte-for-byte regression (the key guarantee).** With the default reverted to
      `Set X0 Y0 to Current Pos, Probe Z0`, the **default** single-op output is again the pre-rework
      Current-Pos+Probe path (no jog `M0`) — so the byte-identical anchor is back on the default
      (**H2**). Post the H2 single-op job and diff it against the pre-rework default output (prior
      tagged `.cps` or a saved reference `.gcode`). **Pass:** **byte-for-byte identical** — the
      Current-Pos+Probe path preserves the old default exactly. *Result:* **OMITTED** — not run (no
      practical way to produce and diff the pre-rework reference here). The structural equivalence of
      the Current-Pos+Probe path is already covered by **H2**, which is once again the default.
      **⚠ Re-baseline required.** The header property dump (D2) adds ~98 Info comment lines to
      **every** posted file, so any byte-for-byte comparison against a pre-dump reference now fails on
      the header alone. If this anchor is ever revived, diff **motion only** (strip comment lines
      first), or capture a fresh reference from the current post. No motion changed.

---

### Professional B — one WCS per copy, milling multiple copies (Replicate)

Use a **2-copy job**: Setup 1 → WCS `1` (G54), Setup 2 → WCS `2` (G55), reserved base **`G59`**,
**Retract Across Parts = On**, real tool. Satisfies P2 and M-series checks as tagged.

- [ ] **PB1 — Re-probe per copy** (Subsequent WCS / Part = `Use Active WCS X0 Y0, Probe Z0` — now the
      default). *Expected at job start:* base establish `( Establish spoilboard
      base G59)` → `(   Select base G59 …)` → `G59` → `G38.2` → `G10 L20 P6 Z0.8` → `G0 Z40`
      (Inter Part Safe Z, base frame) → `(   Restore operating WCS G54 …)` → `G54`; then first copy
      per First WCS / Part into `P1`.
      *Expected at the `P1→P2` boundary:*
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

- [ ] **PB2 — Trust the stored Z** (Subsequent WCS / Part = `Use Active WCS X0 Y0 Z0`). Same job.
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
On, real tool. This is the workflow the Jog origin modes exist for.

- [ ] **PBV1 — Setup run: record each fixture origin.** First WCS / Part = `Set X0 Y0 Z0 to Current
      Pos`, Subsequent WCS / Part = `Jog to X0 Y0, Probe Z0`. Jog to fixture 1 before posting.
      *Expected:* first part records `G10 L20 P1 X0 Y0 Z0` (no prompt, no probe); at `P1→P2`: retract →
      `G55` → **jog prompt** (`M0 (MSG Jog to X0 Y0 above Z0, probe)`) → `G10 L20 P2 X0 Y0` →
      `G38.2` → `G10 L20 P2 Z0.8`. **Pass:** every fixture's origin is written to its own register
      (`P1`, `P2`) from an operator jog; the writes persist to the controller (GRBL stores
      `G10 L20` to EEPROM). After the run, confirm on the controller that `G54`/`G55` report the
      set origins. *(Satisfies M3, M4.)* *Result:* ____

- [ ] **PBV2 — Production run: reuse fixtures, re-probe Z.** First WCS / Part =
      `Use Active WCS X0 Y0 Z0`, Subsequent WCS / Part = `Use Active WCS X0 Y0, Probe Z0`. **Do not
      re-jog** — the origins from PBV1 are already stored. *Expected:* first part —
      `(   Use stored work origin; move to X0 Y0 at Safe Z)` → `G0 Z<probeSafeZ>` → `G0 X0 Y0`
      (no origin write, no jog prompt); at `P1→P2` — retract → `G55` → `G0 X0 Y0` → `G38.2` →
      `G10 L20 P2 Z0.8`. **Pass:** no manual/jog prompts anywhere; XY comes from the stored
      fixtures; Z is re-probed per copy for the new stock. *(Satisfies M6, M2.)* *Result:* ____

- [ ] **PBV3 — Production run: trust stored Z too.** Same as PBV2 but Subsequent WCS / Part =
      `Use Active WCS X0 Y0 Z0`. **Pass:** no probe anywhere on the added copies; each copy
      just retracts and arrives at its stored `X0 Y0`. Use only when every copy's stock is the
      same thickness as the setup run. *Result:* ____

---

### Professional A — a second WCS on the same part, same fixture (re-reference off a machined face)

**In scope.** The part stays clamped in **one fixture** (no flip, no re-clamp). After the face
and outside are machined in WCS `1` (G54), a second setup uses a new WCS `2` (G55) whose origin
is **referenced from a machined face**, so its Z must be **re-probed** on that fresh surface.
Mechanically this is an ordinary inter-WCS traverse plus a re-probe — the post handles it today.
The tool never leaves the part, so the outgoing-frame Safe Z is a valid clearance and no
spoilboard base is required. *(The flip / re-clamp variant — where the same stock is turned over
or re-fixtured — remains future work; see plan.md / memory.)*

**Settings note (Guard B).** For a single-part, two-WCS job the simplest safe setup is **Retract
Across Parts = Off** with **no base**: an inter-WCS traverse still retracts to the probe Safe Z in
the *outgoing* (G54) frame before the switch, which clears the part. Leaving Retract Across Parts
**On** without a reserved base trips Guard B (it can't tell one part's two WCS from two different
fixtures) — so either turn it off or reserve a base for this workflow.

- [ ] **PA1 — New WCS from a machined face, re-probe Z (operator jogs the new datum).** One part,
      one fixture. Setup 1 → WCS `1` (face + outside). Setup 2 → WCS `2`, origin on a machined face.
      **Subsequent WCS / Part = `Jog to X0 Y0, Probe Z0`** (opt-in jog mode — set it); Retract Across Parts = Off, no base;
      real tool. *Expected at the `G54→G55` boundary:*
      ```
      (   Retract to Safe Z before WCS change)
      G0 Z<probeSafeZ>            ; in the outgoing G54 frame
      G55
      ... M0 jog prompt: "Jog to X0 Y0 above Z0, probe" ...
      (   Set current X,Y position to 0,0)
      G10 L20 P2 X0 Y0
      (   Move to part origin X0 Y0, then probe Z)   ; probe XY offset 0
      ... attach-probe prompt per Probe Pause ...
      G38.2 F30 Z-10
      G10 L20 P2 Z0.8
      ... into the WCS-2 cut ...
      ```
      **Pass:** the traverse retracts to a clear Z in the outgoing frame *before* selecting G55;
      the operator jogs to the new datum on the **same** part; the re-probe reads the **machined
      face** and writes Z into `P2` (not P1); no flip/re-clamp is implied. *(Satisfies M4.)*
      *Result:* ____

- [ ] **PA1b — Variant: new WCS XY already known, only Z re-references.** Same job, but WCS `2`'s
      X0 Y0 was already established (or equals G54's) so no jog is needed:
      **Subsequent WCS / Part = `Use Active WCS X0 Y0, Probe Z0`**. *Expected at `G54→G55`:* retract →
      `G55` → `(   Move to part origin X0 Y0, then probe Z)` → `G0 X0 Y0` → `G38.2 F30 Z-10` →
      `G10 L20 P2 Z0.8` — **no jog prompt**. **Pass:** rapids to the stored X0 Y0 and re-probes Z on
      the machined face into `P2`. *(Satisfies M2.)* *Result:* ____

> **Tooltip follow-up (not a test):** the First/Subsequent WCS / Part tooltips currently say *"to
> mill one part from multiple datums/references or a flip, run separate jobs"* — now too broad,
> since this same-fixture re-reference case **is** supported. Only the flip / re-clamp needs the
> "separate jobs" caveat. Flagged for a wording tweak.

---

### Dialog & defaults audit

- [ ] **D1 — Labels, groups, and field types.** Open the dialog and confirm: group **`06 - On
      WCS / Part / Fixture Changes`** exists (no lingering `Probe / Work Origin`); titles read
      **First WCS / Part**, **Subsequent WCS / Part**, **Probe Pause**, **Probe with G38.2**; the
      base-establish option reads **Pause, Probe Z, Pause**; the **First WCS / Part** dropdown lists
      all six modes in order (`Set X0 Y0 to Current Pos, Probe Z0`, `Set X0 Y0 Z0 to Current Pos`,
      `Use Active WCS X0 Y0, Probe Z0`, `Use Active WCS X0 Y0 Z0`, `Jog to X0 Y0, Probe Z0`,
      `Jog to X0 Y0 Z0`) and **defaults to the first, `Set X0 Y0 to Current Pos, Probe Z0`**; the
      **Subsequent WCS / Part** dropdown lists its four modes in order (`Use Active WCS X0 Y0, Probe
      Z0`, `Use Active WCS X0 Y0 Z0`, `Jog to X0 Y0, Probe Z0`, `Jog to X0 Y0 Z0`) and **defaults to
      the first, `Use Active WCS X0 Y0, Probe Z0`** (no `Set … to Current Pos` modes here); **Probe
      X/Y Offset**, group-05 **Inter Part Safe Z** (renamed from "Safe Z" — confirm no group still
      shows two fields both titled "Safe Z"), and group-06 **Safe Z** accept only
      whole numbers (reject a decimal like `2.5`) and are labeled/understood as **whole mm**.
      Cross-check against the fuller **Beta-2 dialog & behavior rework — re-verify** list below.
      *Result:* ____

---

- [ ] **D2 — Header property dump.** Post any job and inspect the header. **Pass:** after the Ranges
      and Tools tables there is one `( Properties -- <group>:)` block for **each of the 11 groups**, in
      dialog order (`01 - Job` → `11 - Duet`), listing **all 68 properties** as `   <Key> = <value>`
      with keys in letter order within each group; enums show their stored **id** (e.g.
      `A_Probe_OnStart = Current XY & Probe Z`, not the display title); unset strings show `<empty>`
      while numeric zeros show `0`. Then a `( Resolved Values:)` block with output unit, resolved
      firmware, both Safe-Z modes + defaults, reserved base as `G59 (P6)` or `None`, and the probe XY
      offset / Inter Part Safe Z in output units. Cross-check two or three values against what you
      actually set in the dialog, and confirm the two old blocks (`Feedrate and Scaling Properties`,
      `G1->G0 Mapping Properties`) are gone — their values now appear under groups `03` and `04`.
      Also confirm the dump is **suppressed** at Comment Level `Important` and `Off`. *Result:* ____
      *(Note: this block is new default output — see the H-REG re-baseline note.)*

## Jet tools & laser operations — deferred

**Scope decision (user).** Jet-tool / tool-0 behavior and laser operations are a **separate
workstream**, to be reviewed and tested on their own rather than as sub-checks bolted onto the
milling rows. Every milling row above stands on its own without them. Nothing here blocks the
WCS/probe work; all of it blocks a release that claims laser/jet support.

The shared mechanic behind most of these: `tool.number != 0 && !tool.isJetTool()` is the post's
"can this tool probe?" test, and it gates the probe **and** the Z retract on every origin path. So a
jet tool or tool 0 takes a *different branch* in `writeWcsOnStart()`, `writeWCS()`, `partProbe()`,
and `writeBaseEstablish()` — those branches are essentially unexercised.

- [ ] **J1 — First WCS / Part, all six modes with a jet tool and with tool 0.** Confirm each mode
      records the origin with **no probe** and no probe prompts, and note which ones also skip the Z
      retract. Collects the deferred sub-checks: **H4** (`Set X0 Y0 Z0 to Current Pos` — the
      documented jet/laser path), **H5 / M6** (`Use Active WCS X0 Y0 Z0` — emits the `X0 Y0` move
      but **no** Z retract), and **H7b** (`Use Active WCS X0 Y0, Probe Z0` — expect the Debug
      comment `writeWcsOnStart: probe skipped (tool 0 or jet tool) -- moving to stored X0 Y0`, a bare
      `G0 X0 Y0`, no `G38.2`). *Result:* ____
- [ ] **J2 — Subsequent WCS / Part with a jet tool.** The `canProbe` false branches in `writeWCS()`
      (`Probe Z` → move to stored `X0 Y0` instead of probing; `Jog XY & Probe Z` → jog, write XY, no
      probe). *Result:* ____
- [ ] **J3 — Spoilboard base with a jet tool.** `writeBaseEstablish()` skips the probe entirely
      (Debug `probe skipped (tool 0 or jet tool)`) — so the base is **never established** on a laser
      job even when reserved. Decide whether that should warn rather than pass silently. *Result:* ____
- [ ] **J4 — Laser property group (`09 - Laser`, 7 properties).** On Vaporize / On Through / On Etch,
      Marlin mode + pin, GRBL mode, laser coolant — none are covered by any current row, and none
      appear in the header property dump. Plus `11 - Duet` `B_Duet_LaserMode`. *Result:* ____
- [ ] **J5 — Laser/jet + the Phase-4 features.** Whether reserved base, Retract Across Parts, and
      the safe-Z retracts are coherent at all for a jet job (no Z probing, Z often fixed by focus).
      This is a **design review before a test** — the answer may be "not applicable, and the dialog
      should say so". *Result:* ____

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

This session reworked the dialog and several probe/homing behaviors. Defaults remain effectively
byte-identical to the pre-rework post: the **First / Subsequent WCS / Part** origin modes default to
the **no-prompt** modes (First = `Set X0 Y0 to Current Pos, Probe Z0`, Subsequent = `Use Active WCS
X0 Y0, Probe Z0`) — the `Jog to …` modes that add a jog `M0` are opt-in, since jogging at the pause
isn't universally supported. Re-verify:

- **Group split & renumber.** `05 - Establish Spoilboard Reference` (4 items) sits between Map-G1s
  and `06 - On WCS / Part / Fixture Changes` (10 items); `03 - Feeds and Speeds` and `04 - Map G1s to
  Rapids` precede it; downstream groups run through `11 - Duet`. Items order by letter prefix
  within each group. (The spoilboard-group move to `05` changed only `group:` strings, not keys,
  so it does **not** reset presets; earlier renamed / re-lettered keys still do.)
- **Label renames** display correctly: Reserved WCS, Probe to Set Base, Retract Across Parts,
  **Inter Part Safe Z** (Spoilboard group — renamed from "Safe Z", which collided with the group-06
  field of the same name; key unchanged, so presets don't reset). Current labels: group `06` →
  **On WCS / Part / Fixture Changes**;
  `A_Probe_OnStart` → **First WCS / Part**; `B_Probe_OnChange` → **Subsequent WCS / Part**;
  `C_Probe_Pause` → **Probe Pause**; `F_Probe_G382orG28` → **Probe with G38.2**; base-establish
  option → **Pause, Probe Z, Pause**. Origin-mode options were reworked into an explicit *Current
  Pos* (no prompt) vs *Use Active WCS* (no prompt) vs *Jog* (M0 prompt) taxonomy, ordered
  default-first: **First WCS / Part** → `Set X0 Y0 to Current Pos, Probe Z0` / `Set X0 Y0 Z0 to
  Current Pos` / `Use Active WCS X0 Y0, Probe Z0` / `Use Active WCS X0 Y0 Z0` / `Jog to X0 Y0,
  Probe Z0` / `Jog to X0 Y0 Z0`; **Subsequent WCS / Part** → `Use Active WCS X0 Y0, Probe Z0` /
  `Use Active WCS X0 Y0 Z0` / `Jog to X0 Y0, Probe Z0` / `Jog to X0 Y0 Z0`. **Defaults are the
  first item of each** (First = `Set X0 Y0 to Current Pos, Probe Z0`, Subsequent = `Use Active WCS
  X0 Y0, Probe Z0`). The renamed/added ids reset any saved `A_Probe_OnStart` / `B_Probe_OnChange`
  preset.
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
- **Regression:** with the default reverted to `Set X0 Y0 to Current Pos, Probe Z0`, the *default*
  single-op job is once again byte-for-byte the pre-rework output (no jog `M0`) — the anchor is back
  on the default path (see H2 / H-REG).

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

> The **first-part `Use Active WCS X0 Y0, Probe Z0`** mode × nonzero offset is a separate path
> (`writeWcsOnStart()` → `partProbe(false)`, no XY origin write) and is covered by **H7a** — not
> repeated here. P1 below covers the offset on the `Set X0 Y0 to Current Pos, Probe Z0` path.

- [x] **P1 — Nonzero offset, first/only part.** ✅ **Verified** via `Face1.gcode` (single part,
      offset X10 Y5, base `G59` reserved — GRBL/inch-doc-in-mm-out): `G10 L20 P1 X0 Y0` →
      `X10 Y5 F2500` (G0 modal reposition) → `G38.2 F30 Z-10` → `G10 L20 P1 Z0.8`; the reserved
      base probed with **no** reposition (`G10 L20 P6 Z0.8`), confirming the base ignores the
      offset. (Original procedure below, for reference.) Single-WCS, **no base**. Set
      `Probe X Offset = 10`, `Probe Y Offset = 5`; `First WCS / Part = Set X0 Y0 to Current Pos, Probe Z0`;
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
      `P1` + `P2`), **reserved base `G59`**, `Subsequent WCS / Part = Use Active WCS X0 Y0, Probe Z0`, same `10/5` offsets.
      Post and confirm all three probes:
      - **Base (`G59`)** — `( Establish spoilboard base G59)` → `G59` select → `G38.2` →
        `G10 L20 P6 Z<thk>` → `G0 Z<Inter Part Safe Z>` → `G54` restore, with **no `G0 X/Y`
        reposition** (base ignores the offset).
      - **First part (`P1`)** — reposition to `X10 Y5` before `G38.2`, exactly as P1 above.
      - **Added part (`P2`)** — with `Subsequent WCS / Part = Use Active WCS X0 Y0, Probe Z0` (Replicate auto-position):
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

## Subsequent WCS / Part — new modes (verification steps)

`B_Probe_OnChange` now has four modes across two coexisting workflows. Use a **2-part Replicate
job** (WCS `P1` + `P2`), a reserved base `G59` + Retract Across Parts on, tool ≠ 0. On each added
part, every mode first **retracts to a safe Z, then acts** — confirm that retract precedes any XY
move. Marlin is out of scope (single frame; Guard C blocks multi-WCS).

- [ ] **M1 — `Skip` reaches X0 Y0 safely (behavior change).** `Subsequent WCS / Part = Use Active WCS X0 Y0 Z0`. On the
      `P1→P2` boundary confirm: base-relative retract (`G59` → `Z<SafeZ>`) → `G55` → **`G0 X0 Y0`**
      → straight into cutting, **no probe**. The `G0 X0 Y0` after the WCS switch is the new
      "do-nothing-but-arrive-safely" move (previously `Skip` went straight into cutting with no
      X0 Y0 rapid — this supersedes the old Verified "Test B" behavior).
- [ ] **M2 — `Probe Z` (Replicate auto-position).** `Subsequent WCS / Part = Use Active WCS X0 Y0, Probe Z0`. Confirm the
      existing behavior is unchanged: retract → `G55` → rapid to `X0 Y0` (+ offset) → `G38.2` →
      `G10 L20 P2 Z`. XY comes from `P2`'s stored offset (not re-zeroed).
- [ ] **M3 — `Jog to X0 Y0 Z0` (jog, no probe).** `Subsequent WCS / Part = Jog to X0 Y0 Z0`. Confirm:
      retract → `G55` → **jog prompt** (`M0 (MSG Jog to X0 Y0 Z0, then continue)` on
      GRBL/Marlin; RepRap `M291 ... S3 X1 Y1 Z1`) → `G10 L20 P2 X0 Y0 Z0` (Marlin: `G92`) → cutting.
      **No probe, no auto XY move.**
- [ ] **M4 — `Jog to X0 Y0, Probe Z0` (jog, opt-in).** `Subsequent WCS / Part = Jog to X0 Y0, Probe Z0`. Confirm:
      retract → `G55` → **jog prompt** → `G10 L20 P2 X0 Y0` → probe (`G38.2` → `G10 L20 P2 Z`),
      with the attach/detach prompts following the separate **Probe Pause** dropdown. With a nonzero
      probe offset, the probe repositions to `(offsetX, offsetY)` after the jog.
- [ ] **M5 — Single-WCS regression.** A single-WCS job (no added parts) is **byte-for-byte
      unchanged** — `writeWCS()` returns at "WCS unchanged", so none of the new dispatch runs.
- [ ] **M6 — First-part `Skip` now reaches X0 Y0 (behavior change).** `First WCS / Part = Skip`,
      milling tool. Confirm the first section now emits `G0 Z<probeSafeZ>` then
      `G0 X0 Y0` (retract, then move to the stored origin) instead of nothing. A jet/tool-0
      first-part `Skip` emits the `X0 Y0` move but **no** Z retract. (See H5 for the hobbyist
      single-op form of this path.)

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
- **⚠ Superseded by the base-frame probe change** — the base establish now wraps its probe in a
  `G59` select / `G54` restore and retracts to the Inter Part Safe Z in the base frame. The
  register write is unchanged; the surrounding blocks are not. Re-verify via H7c / PB1.
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
  another pass. First-part middle option showed `Zero XYZ (no probe)` (Test A) — since superseded by
  the Current-Pos / Jog taxonomy (verify current labels via D1).
- **Base-relative retract, re-probe path** (`Setup1 Multi.gcode`): `baseRelative: true base: 6`
  → `G59` → `Z40` → `G55` → `X0 Y0` → `G38.2` → `G10 L20 P2 Z`.
- **Base-relative retract, non-re-probe (Skip) path** (Test B): `baseRelative: true …` → `G59` →
  `Z40` → `G55`, straight into cutting, no probe. **⚠ Superseded** by the added-part redesign —
  `Skip` now appends `G0 X0 Y0` after the switch (safe arrival at the stored origin); re-verify
  under *Subsequent WCS / Part — new modes* → M1.
- **Single retract per boundary** (Test D): re-probe boundary transits once (`G59`/`Z40`), then
  `X0 Y0`/probe — no second Safe-Z retract.
- **Same-WCS boundary** (Test C): `WCS unchanged`, no `G59` round-trip.
- **Probe XY offset — offset `0` first part + base probe** (NC inspection of `Setup1-Face1.gcode`,
  current-post `G10 L20`/`G38.2` output): the first/only part goes `G10 L20 P1 X0 Y0` →
  `( COMMAND_TOOL_MEASURE)` → `G38.2` with **no reposition rapid** (byte-identical); the reserved
  `G59` base probes with **no `G0 X/Y`** before its `G38.2` → `G10 L20 P6 Z0.8` (offset never
  applies to the base). Nonzero and added-part paths remain in *Probe XY offset — verification
  steps* (P1–P3) — no on-disk NC file exercises them yet.
