# Beta 2 Test Plan

Verification tracking for `MPCNC_v4.0_Beta1.cps` → `MPCNC_v4.0_Beta2.cps`. **Outstanding**
tests are listed first; **verified** items are summarized below so they aren't re-run.
Design/behavior detail lives in `docs/plan.md`.

> ## Standing rule — a code change is not done until this file is updated
>
> **Every change to `MPCNC_v4.0_Beta2.cps` updates this file in the same commit.** Not afterwards,
> not "when we get to testing". Three things to do, in this order:
>
> 1. **Add the row(s)** that verify the new behavior, written as **Do this → get that**: the exact
>    dialog settings to set, the exact g-code to expect (a block, not a description), and a **Pass**
>    line naming the *discriminator* — the one token whose presence or absence proves the change
>    (often an absence: "no `G10 L20 P1 X0 Y0`").
> 2. **Mark what the change invalidates.** If an already-`PASS` row's saved `.gcode` no longer
>    matches current output, say so on that row (⚠ + what differs + which new row supersedes it).
>    A stale PASS is worse than an unrun test.
> 3. **Update the Results summary table** so the new rows are visible without reading the file.
>
> Cover **both** branches of any new condition — the path that emits and the path that suppresses.
> A test that only proves output appears cannot catch a guard that never fires.
>
> **How rows are verified:** post the job from Fusion and **read the resulting g-code** — by eye and
> with AI review. Expectations must therefore be written as things visible *in the file*: exact
> tokens, their order, and what must be absent. Machine dry-runs and physical measurements are not
> part of this plan, so a row's Pass criteria must stand on the file alone.

---

## Execution runbook — hobbyist & professional flows

End-to-end, persona-driven scenarios covering the reworked **First / Subsequent WCS / Part** origin
modes, safe-Z arrival on every WCS change, and the whole-mm integer offsets / Safe Z. **You run
these; record `PASS` / `FAIL` in each `Result:` line.** The granular token-level checks (M1–M6,
P1–P3) below still apply; each scenario tags which ones it also satisfies so nothing is double-run.

**Where the g-code goes.** Posted files named below are written to Fusion's NC output folder —
`C:\Users\don_m\Documents\Fusion 360\NC Programs\` — not into the repo. Name each post after its
test row so a later review can find it. Diffing two of them is often the fastest check; strip
comment lines first when the two posts straddle a header change.

**Conventions.** Comments are `( ... )` on GRBL and `; ...` on Marlin/RRF — otherwise the tokens
are identical. `G10 L20 P<n>` is GRBL/RepRap; Marlin uses `G92` and rejects >1 WCS (Guard C).
Feed placeholders (`F<travelXY>`) are whatever the job's travel feed resolves to. Default probe
target/speed/thickness = `Z-10` / `F30` / `Z0.8` unless you changed them. The default First WCS /
Part mode is `Set X0 Y0 to Current Pos, Probe Z0` and Subsequent is `Use Active WCS X0 Y0, Probe Z0`
— both no-prompt; the `Jog to …` modes (which emit an `M0` jog prompt) are opt-in. Do every scenario
on **GRBL** first (the default firmware); the
firmware-variant rows note what changes elsewhere.

> **⚠ Blast radius of HR-3 — every saved GRBL `.gcode` differs at the tail.** The manual-spindle
> stop now prompts on GRBL as it always did on Marlin/RRF, so a default-settings GRBL job ends
> `M0 (MSG Turn OFF spindle)` where it previously ended `M5`, and each tool change gains the same
> prompt before `Insert Tool #n`. **No row's assertions are affected** — nothing below asserts on the
> `*** STOP begin ***` block or on `M5` (checked), and no motion changed. But no saved GRBL file
> matches byte-for-byte at the end any more, so don't read a tail diff as a regression. **HR3**
> carries the new tokens; the only row that claims a byte-for-byte property is **M5**
> (single-WCS regression), which compares two *current* posts to each other and so is unaffected.

### Results summary (fill as you go)

| ID | Scenario | Result |
|----|----------|--------|
| H1 | Hobbyist — single op, `Jog to X0 Y0, Probe Z0` (opt-in jog mode) | PASS ⚠ *(superseded by HR1)* |
| H2 | Hobbyist — single op, **default** `Set X0 Y0 to Current Pos, Probe Z0` (no-prompt) | PASS ⚠ *(superseded by HR1)* |
| H3 | Hobbyist — single op, `Jog to X0 Y0 Z0` (manual Z, jog) | PASS |
| H4 | Hobbyist — single op, `Set X0 Y0 Z0 to Current Pos` (manual Z, no prompt) | PASS *(jet/tool-0 → J1)* |
| H5 | Hobbyist — single op, `Use Active WCS X0 Y0 Z0` (trust stored) | PASS |
| H6 | Hobbyist — firmware variant (Marlin/RRF), `Jog to X0 Y0, Probe Z0` | PASS (Marlin + RRF) ⚠ *(superseded by HR1)* |
| H7 | Hobbyist — single op, `Use Active WCS X0 Y0, Probe Z0` (new mode) | PASS — incl. H7a *(H7e unrun; H7b → J1)* |
| H7f | "Unknown Z" warning — present without a base, suppressed with one | PASS *(all three)* |
| HR1 | Provisional Z0 bounds the `G38 Target` on the two just-positioned probe modes | (A) PASS *(B/C/D + firmware unrun; C proves the scope)* |
| HR2 | Canned cycles: a drill/tap operation posts at all; probing is rejected | |
| HR3 | Manual spindle prompts to switch OFF on GRBL too — job end and tool change | (A) PASS *(B/C/D unrun)* |
| HR4 | Safe-Z literal fallbacks convert mm→output unit; inch jobs stop retracting to 15 in | |
| HR5 | `Scale Feedrate` reaches G2/G3 arcs, not just G1 cuts | |
| HR6 | A rotated 3-axis Setup is rejected — and an upright one still posts | PASS — (A) + (A2); guard confirmed **live** (`forward X0 Y0 Z1`), not failing open. *(B) unrun* |
| H-REG | Hobbyist — byte-for-byte regression via the H2 path | OMITTED (see row) |
| PB1 | Pro B — 2 copies, base, re-probe per copy (`Use Active WCS X0 Y0, Probe Z0`) | |
| PB2 | Pro B — 2 copies, base, `Skip` (trust stored) | |
| PBV1 | Pro B-variant — setup run (record fixtures) | |
| PBV2 | Pro B-variant — production run (re-probe Z) | |
| PBV3 | Pro B-variant — production run (trust stored Z) | |
| PA1 | Pro A — 2nd WCS same part/fixture, `Jog to X0 Y0, Probe Z0` | |
| PA1b | Pro A — 2nd WCS same part, Z-only re-probe (`Use Active WCS X0 Y0, Probe Z0`) | |
| H7c | Base probes/retracts in its own frame | PASS |
| H7d | Guard A fires on the reserved base for this mode | PASS |
| H7e | H7 on Marlin and RRF | |
| D1 | Dialog & defaults audit (modes, renames, integer fields) | |
| D2 | Header property dump — all 68 properties + resolved values | PASS *(suppression check unrun)* |
| D3 | Group order after the homing move — presets must survive | header PASS *(dialog half unrun)* |

---

### Hobbyist — Fusion Personal, a single milling operation

The design goal: **the default dialog posts a correct job with the fewest possible changes.** A
single op has no WCS change, so only **First WCS / Part** is exercised — these rows walk all six of
its modes. The default is now **H2** (`Set X0 Y0 to Current Pos, Probe Z0`, no prompt); H1 is the
opt-in guided-jog path. Do them on **GRBL**, one 3-axis milling op, real tool (tool ≠ 0, not a jet
tool) unless a row says otherwise.

> **No H row needs a functional retest.** Since they were verified, the only change to any H path
> has been operator-prompt wording (`askUser()` strings shortened, RRF title `"Set part origin"` →
> `"Set origin"`). Motion, origin writes, probe commands and comment structure are untouched, so the
> saved `H1.gcode` / `H3.gcode` differ from the expected blocks below only in `M0 (MSG …)` text.

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
      origin, then zeroes XY there and probes Z — both into `P1`. *Result:* **PASS** (`H1.gcode`).

      > **⚠ Superseded by HR1** — this mode now writes a provisional `Z0` with the XY zero, so the
      > expected block above is `G10 L20 P1 X0 Y0 Z0` preceded by one extra Info comment.
      > `H1.gcode` no longer matches current output. The row's own assertion (jog prompt → XY zeroed
      > at the jogged position → Z probed into `P1`) still holds; **HR1** carries the new tokens.

- [x] **H2 — Default `Set X0 Y0 to Current Pos, Probe Z0` (pre-jog, no prompt — the zero-change
      path).** Leave **every** property at its default (First WCS / Part = `Set X0 Y0 to Current Pos,
      Probe Z0`, Probe Pause = `Before & After`). Jog to the part origin (XY) **before** posting.
      *Expected:* identical to H1 **but with no `M0` jog prompt** — straight `G54` →
      `(   Set current X,Y position to 0,0)` → `G10 L20 P1 X0 Y0` → probe. **Pass:** with zero
      settings touched this reproduces the **pre-rework default output** (no jog prompt; XY zeroes at
      the parked position) and is the H-REG regression anchor below. *(Matches P1's offset-0
      first-part shape.)* *Result:* **PASS** (`H2.gcode`).

      > **⚠ Superseded by HR1 — and the byte-identical anchor is now formally broken.** The default
      > path writes `G10 L20 P1 X0 Y0 Z0` (provisional Z0, overwritten by the probe) plus one Info
      > comment, so `H2.gcode` no longer matches current output and this row can no longer claim
      > "reproduces the pre-rework default output". That claim was already only nominal — H-REG is
      > `OMITTED` and the property dump had displaced the header wholesale — but it is now untrue of
      > the **motion-and-commands** half too, which is the guarantee `plan.md` still asserts. The
      > break is deliberate: see docs/HReview.md HR-1 for why an unbounded probe descent was the
      > worse failure. Structural coverage of this mode moves to **HR1**.

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
      `G38.2`. *Result:* **PASS** (`H3.gcode`).

- [x] **H4 — `Set X0 Y0 Z0 to Current Pos` (manual Z, no prompt).** Same as H3 but First WCS / Part =
      `Set X0 Y0 Z0 to Current Pos`; jog to the part origin (all three axes) **before** posting.
      *Expected:* `G54` → `(   Set current position to 0,0,0)` → `G10 L20 P1 X0 Y0 Z0` → cut, with
      **no `M0` jog prompt and no probe**. **Pass:** one dialog change gives a fully manual no-prompt
      touch-off (the old H2 behavior). This is also the jet/laser path — a jet tool or tool 0 records
      the origin with no probe regardless. *Result:* **PASS** (`H4.gcode`). *(Jet/tool-0 sub-check
      **deferred to J1** — see [Jet tools & laser operations](#jet-tools--laser-operations--deferred).)*

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
      multi-WCS warning on a single-op Marlin job. *Result:* **PASS — Marlin and RRF**
      (`H6 - Marlin.gcode`, `H6 - RRF.gcode`). RRF differs from Marlin as expected: `G54` **is**
      emitted and origins are `G10 L20 P1 …` not `G92`, with `M291 … S3` dialogs for every pause.

      > **⚠ Superseded by HR1** on both firmwares — Marlin's origin write becomes `G92 X0 Y0 Z0`
      > and RRF's `G10 L20 P1 X0 Y0 Z0`. Both saved files predate it. **HR1**'s firmware half
      > re-covers this; the row's own assertions (comment style, `G92`-vs-`G10`, no spurious
      > multi-WCS warning) are unaffected.

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
      sits at from job start. Record that height.
      *Result:* **PASS** (`H7.gcode`). Sub-checks: **H7a, H7c, H7d, H7f PASS**; **H7b deferred to
      J1**; **H7e** unrun.

      > **⚠ `H7.gcode` / `H7a.gcode` predate the `Ensuring that Z is safe…` line** added since
      > (verified separately by **H7f**). Comment-only, so both rows stand — but don't diff a fresh
      > post against them blind.

  Sub-checks:

  - [x] **H7a — nonzero offset.** Same job with Probe X/Y Offset = `10` / `5`. Confirm the comment
        becomes `(   Move to probe point = origin + offset X10 Y5, then probe Z)` and the rapid is
        `G0 X10 Y5`, still with **no** `G10 L20 P1 X0 Y0`. (Closes the first-part `Probe Z` ×
        offset gap: P1 covers the offset only on the `Set X0 Y0 to Current Pos` path.)
        *Result:* **PASS** (`H7a.gcode`). Diffed against `H7.gcode`: only the two intended lines
        differ, so the offset is fully localised to the probe-point reposition.

  - **H7b — jet tool / tool 0. → DEFERRED** to
    **[Jet tools & laser operations](#jet-tools--laser-operations--deferred)** (J-series). The
    milling assertions above don't depend on it, so H7 is complete without it.

  - [x] **H7c — Base probe runs in the base's frame.** Verifies the base-frame probe/retract fix.
        *(Mechanism and history: plan.md, "first-part `Probe Z` mode's traverse height when a base
        is reserved".)*

        **Settings.** GRBL, real tool, one milling op. Reserved WCS = `G59`; Probe to Set Base =
        `Pause, Probe Z, Pause`; Inter Part Safe Z = `40`; First WCS / Part = `Use Active WCS X0 Y0,
        Probe Z0`. Probe X/Y Offset = `0` **or** a nonzero pair — either works here; the base probe
        ignores the offset, so it changes only the *part* probe's reposition (a nonzero run also
        evidences P2's base-ignores-offset assertion).

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

        **Pass:** `G59` appears *before* the `G38.2`; the retract is `G0 Z40` (matching
        `(   Retract the tool to 40)`) and **not** the group-06 probe Safe Z; the `G54` restore
        appears before the `Use stored work origin` line; the base probe has **no `G0 X/Y`**
        reposition; and the `Ensuring that Z is safe. Unknown Z for XY move.` line is **absent** —
        the base retract made the height known (this file doubles as **H7f (B)**).

        *Result:* **PASS** (`H7c.gcode`, offsets X10 Y5 — so it also evidences **P2**'s
        base-ignores-offset assertion and doubles as **H7f (B)**).

  - [x] **H7d — Guard A still fires for this mode.** Assign the first section to the reserved base
        WCS (e.g. base `G59`, Setup WCS = `6`) with First WCS / Part = `Use Active WCS X0 Y0,
        Probe Z0`. **Pass:** the post aborts in `onOpen()`, **no `.gcode` file is written at all**,
        and the error names the offending control **using its exact dialog title** — `First WCS /
        Part` — so the operator can go find it. The new mode writes a Z origin, so it must count as
        origin-establishing (`baseOriginWriteReason()` classifies every mode except `Skip` that way).

        *Result:* **PASS** (`H7d.log`; no `H7d.gcode` written, confirmed on disk). The run found the
        error naming the *pre-rework* titles — fixed, so a re-post shows `First WCS / Part`.

  - [ ] **H7e — firmware variant (low priority).** Repeat H7 on Marlin and RRF. **Pass:** Marlin
        emits `G92 Z0.8` only (no XY word, no `G54`); RRF emits `G54` + `G10 L20 P1 Z0.8` with
        `M291 … S3` probe prompts. No jog buttons (`X1 Y1 Z1`) — this mode has no jog prompt.
        *Result:* ____

  - [x] **H7f — The "unknown Z" warning appears only when Z really is unknown.** Verifies the Info
        comment added to `partProbe()`'s `zUnknown` branch. The comment tells the operator (and an
        automated review) that the traverse below runs at whatever height the tool physically sits
        at — true only when nothing has established a height first, which is what the three posts
        below separate. *(Mechanism: plan.md, "warn in the file that the traverse Z is unknown" →
        "As built".)*

        **Common settings for all three:** GRBL, one milling op, real tool, First WCS / Part =
        `Use Active WCS X0 Y0, Probe Z0`, Probe X/Y Offset = `0`, Comment Level = `Info` (default).
        Change **only** the two base fields between posts.

        **Do (A):** post with **Reserved WCS = `None`**.
        **Get (A):** the warning is present, between the mode comment and the traverse:
        ```
        (   Use stored work origin X0 Y0; probe Z)
        (   Ensuring that Z is safe. Unknown Z for XY move.)
        (   Move to part origin X0 Y0, then probe Z)
        G0 X0 Y0 F<travelXY>
        ```

        **Do (B):** same job, **Reserved WCS = `G59`**, Probe to Set Base = `Pause, Probe Z, Pause`.
        **Get (B):** the warning is **gone** — the base establish already retracted to the Inter Part
        Safe Z *in the base's frame*, so the height is known and the warning would be false:
        ```
        (   Restore operating WCS G54 after base probe)
        G54
        (   Use stored work origin X0 Y0; probe Z)
        (   Move to part origin X0 Y0, then probe Z)
        ```
        *(This is the same post as **H7c** — do it once and use the file for both rows.)*

        **Do (C):** same as (B) but **Probe to Set Base = `None`**.
        **Get (C):** the warning is **back**. A base that is only *assumed* pre-set emits no probe
        and no retract, so nothing established a height — reserving a base is not by itself enough.

        **Pass:** the discriminator is the **suppression**, not the appearance — (A) and (C) carry
        the line, (B) does not. Also confirm the blast radius is nil: **(A)'s motion must be
        byte-identical to `H7.gcode`'s** (compare non-comment lines only — `H7.gcode` predates both
        the property dump and the group reorder, so its *header* differs wholesale and a raw diff is
        useless here), the only added body line being the warning itself; and a default-settings post
        (**H2** path) and any added-part probe contain the line **nowhere** — it is gated by the
        `zUnknown` parameter that only this one mode passes.

        *Result:* **PASS — all three.** (A) `H7c-a.gcode`, (B) `H7c-b.gcode` and `H7c.gcode`
        (confirmed at both zero and nonzero offsets), (C) `H7c-c.gcode`. (A)'s motion is
        byte-identical to `H7.gcode`'s — the warning added one comment line and nothing else.

- [ ] **HR1 — A provisional `Z0` bounds the `G38 Target` on the two just-positioned probe modes.**
      Verifies the HR-1 fix (docs/HReview.md). `G_Probe_G38Target` is emitted as an **absolute** `Z`
      word, so before this change its meaning depended on whatever Z0 a previous run had persisted
      into the register — the same `Z-10` could be a 10 mm descent, a 45 mm one, or point upward.
      Writing `Z0` at the current height alongside the XY zero makes it a true travel limit; the
      probe overwrites that Z0 with the plate thickness three blocks later, so it never survives
      into the cut. **Deliberately scoped to the two modes where the operator has just placed the
      tool at the origin themselves** — the (C) and (D) posts below are what prove the scope.

      **Common settings:** GRBL, one 3-axis milling op, real tool (≠ 0, not a jet), Probe Pause =
      `Before & After`, Probe X/Y Offset = `0`, no base, Comment Level = `Info` (default).

      **Do (A):** First WCS / Part = `Set X0 Y0 to Current Pos, Probe Z0` (the default — this is the
      H2 path). **Get (A):**
      ```
      (   Set current X,Y position to 0,0)
      (   Provisional Z0 at the current height so the probe target is a relative limit)
      G10 L20 P1 X0 Y0 Z0
      ... M0 attach-probe prompt ...
      G38.2 F30 Z-10
      G10 L20 P1 Z0.8
      G0 Z<probeSafeZ>
      ```

      **Do (B):** First WCS / Part = `Jog to X0 Y0, Probe Z0`. **Get (B):** identical to (A) but with
      `M0 (MSG Jog to X0 Y0 above Z0, probe)` ahead of the `Set current X,Y position` comment — the
      provisional `Z0` and its comment appear on this mode too (shared code path).

      **Do (C):** First WCS / Part = `Use Active WCS X0 Y0, Probe Z0`. **Get (C):** **no `G10 L20 P1
      Z0`, no provisional-Z0 comment** — output identical to `H7c-a.gcode`. This probe starts from a
      retracted clearance, so a provisional zero there would make `Z-10` too *tight* and turn a
      working probe into a "did not contact" alarm.

      **Do (D):** First WCS / Part = `Set X0 Y0 to Current Pos, Probe Z0` with a **jet tool or tool
      0**. **Get (D):** `G10 L20 P1 X0 Y0` — XY only, **no `Z0`**, no provisional-Z0 comment. No
      probe means no target to bound, and writing Z0 here would silently turn this mode into
      `Set X0 Y0 Z0 to Current Pos`. *(Fold into **J1** if the jet workstream runs first.)*

      **Pass — the discriminator is the pair of absences.** (A) and (B) carry ` Z0` on the origin
      write; (C) and (D) must not. A fix that only proved (A) would not distinguish "bounded where it
      is sound" from "bounded everywhere", which is the failure mode this row exists to catch.
      Confirm too that the blast radius is nil: (A)'s output differs from `H2.gcode` in exactly two
      lines (the added comment, and ` Z0` appended to the `G10 L20`), and **H3/H4/H5** — which
      already write Z0 or write no origin at all — are untouched.

      **Firmware half:** repeat (A) on Marlin → `G92 X0 Y0 Z0`; on RRF → `G54` + `G10 L20 P1 X0 Y0
      Z0` with `M291 … S3` prompts. Supersedes the saved `H6 - Marlin.gcode` / `H6 - RRF.gcode`.
      *Result:* **(A) PASS** — `H2.gcode` (2026-07-31), token for token:
      `(   Set current X,Y position to 0,0)` → `(   Provisional Z0 at the current height so the probe
      target is a relative limit)` → `G10 L20 P1 X0 Y0 Z0` → `M0 (MSG Attach ZProbe)` →
      `G38.2 F30 Z-10` → `G10 L20 P1 Z0.8` → `G0 Z5.08 F300`. The provisional `Z0` is overwritten by
      the probe before the cut, as designed. **(B), (C), (D) and the firmware half unrun** — (C) is
      the one that proves the scope, so the row is not closed.

- [ ] **HR2 — A canned-cycle operation posts at all; probing is still rejected.** Verifies the HR-2
      fix (docs/HReview.md). `onCyclePoint()` calls `isProbeOperation()`, which had **no definition
      anywhere in the post** — it is a post-local helper in the Autodesk reference posts, not a kernel
      global. If this kernel revision does not supply one, the first cycle point in a job throws a
      `ReferenceError` and the post aborts with no file: **the entire drilling path would be
      unusable**, and nothing else in the post would show a symptom. Now defined locally.

      **This row's whole point is that no existing row exercises `onCyclePoint` at all.** Every H, P,
      PB and PA row is contour/pocket/face milling. Until this posts, drilling is untested.

      **Do (A) — a plain drill.** GRBL, hobby defaults, one **Drill** operation (several holes, any
      depth) alongside or instead of the milling op. **Get (A):** each hole expands into ordinary
      moves — no `G81`/`G82`/`G83` anywhere — roughly:
      ```
      ( MOVEMENT_RAPID)
      G0 X<hole> Y<hole> F<travelXY>
      ( MOVEMENT_PLUNGE)
      G1 Z<depth> F<plunge>
      ( MOVEMENT_RAPID)
      G0 Z<retract> F<travelZ>
      ```
      and the file runs through to `( *** STOP end ***)`. **Pass — the discriminator is that a file
      exists and reaches STOP end.** An abort with no `.gcode` written (the H7d shape) is the failure,
      and would prove the local definition was load-bearing rather than merely defensive.

      **Do (A2) — a tap, same post if convenient.** Add a **Tapping** operation. **Get (A2):** the
      cycle expands the same way, and each affected move carries
      `( >>> WARNING: Speed-feed synchronization  rigid tapping  is not supported; a floating/tension tap holder is required)`.
      **Pass:** the warning is present. Note the **double spaces** where `(rigid tapping)` was — that
      is the known `sanitizeMessageText` parenthesis-stripping cosmetic defect (HReview HR-17), and
      this post is the first file to evidence it; do not "fix" it by editing the expectation.

      **Do (B) — probing must still be refused.** A WCS/inspection **probe** operation. **Get (B):**
      the post fails with Fusion's `cycleNotSupported()` error and writes no g-code; in particular
      **no plain `G0`/`G1` motion is emitted in place of the probe**, which is the silent-wrong
      outcome the guard exists to prevent.
      > **(B) may not be runnable on this licence.** Fusion's probing / Inspection strategies need
      > the Machining Extension, so a Personal-licence hobbyist cannot create one — which is also why
      > this half was never reachable in the hobbyist runbook. Where (B) cannot be posted, the
      > available evidence is a **unit check of the helper against stubbed kernel globals** (strategy
      > `probe`, and cycle types `probing-x` / `probing-xy-outer-corner` / `probing-z` → `true`;
      > `drilling` / `tapping` / `boring` → `false`; `cycleType` absent → `false`). That harness was
      > run when the fix landed and passed all eight cases. Record (B) as *not applicable — no
      > extension* rather than blank, so a later reader does not mistake it for unrun.

      *Result:* ____

- [ ] **HR3 — A hand-switched spindle is told to stop, on GRBL too.** Verifies the HR-3 fix
      (docs/HReview.md). `spindleOn()` has always honoured **Manual Spindle On/Off** on every
      firmware; `spindleOff()` branched on firmware first and emitted a bare `M5` on GRBL regardless
      — which does nothing to a router switched by hand. On the **default** hobbyist configuration
      (GRBL, Manual Spindle On/Off **on**) the file therefore asked the operator to switch the router
      on and never asked them to switch it off. `spindleOff()` now branches on the property first.

      **Do (A) — job end, the default config.** GRBL, one milling op, **Manual Spindle On/Off = on**
      (default), Comment Level = `Info`. **Get (A):** in the `*** STOP begin ***` block —
      ```
      ( *** STOP begin ***)
      ( COMMAND_COOLANT_OFF)
      G0 X0 Y0 F<travelXY>
      ( COMMAND_STOP_SPINDLE)
      M0 (MSG Turn OFF spindle)
      M30
      ```
      **and no `M5` anywhere in the file** — that absence is the discriminator. Also confirm no
      `M300` (GRBL has no beep command).

      **Do (B) — the automatic branch.** Same job, **Manual Spindle On/Off = off**. **Get (B):**
      `M3 S<rpm>` at the start and `M5` in the stop block, with **no `Turn ON` / `Turn OFF`
      prompts**. This is the branch that must not have moved.

      **Do (C) — tool change, the case that matters most.** GRBL, two operations, two tools,
      `07 - Tool Changes` → Tool Changes are Included = on, Include Relocation Code = on, Manual
      Spindle On/Off = on. **Get (C):** at the boundary, the turn-off prompt precedes the
      insert-tool prompt —
      ```
      ( Tool Change Start)
      ... the park rapid to Tool Change X/Y/Z -- order not asserted here, see HR-8 ...
      ( COMMAND_COOLANT_OFF)
      ( COMMAND_STOP_SPINDLE)
      M0 (MSG Turn OFF spindle)
      M0 (MSG Insert Tool #2 ...)
      ```
      **Pass:** the operator is never invited to reach into the machine without first being told to
      switch the spindle off — the two `M0`s in that order, with no `M5` between them. Before this
      fix (C) emitted `M5` there and nothing else.

      **Do (D) — firmware regression.** Repeat (A) on Marlin and RRF. **Get (D):** unchanged from
      the saved `H6` behaviour — `M300 S300 P3000` beep then the turn-off prompt (`M0 …` on Marlin,
      `M291 … S3` on RRF). **Pass:** the Marlin/RRF path is byte-identical to before; only GRBL moved.

      > **Expected-block correction for (A): the `G0` is modal.** The block above writes
      > `G0 X0 Y0 F<travelXY>`, but the last motion word before the stop block is the section's final
      > `G0 Z…` retract, so `gMotionModal` suppresses the word and the file emits a bare
      > `X0 Y0 F<travelXY>` — still a rapid, and correct. Assert the coordinates and their position in
      > the stop block, not the literal `G0`.

      *Result:* **(A) PASS** — `H2.gcode` (2026-07-31): `( *** STOP begin ***)` →
      `( COMMAND_COOLANT_OFF)` → `X0 Y0 F2500` (modal `G0`, see above) → `( COMMAND_STOP_SPINDLE)` →
      `M0 (MSG Turn OFF spindle)` → `M30`, with **no `M5` and no `M300` anywhere in the file** — the
      discriminating pair of absences. **(B), (C), (D) unrun**; (C) is the case that matters most.

- [ ] **HR4 — Safe-Z literal fallbacks are in mm, like every other dialog dimension.** Verifies the
      HR-4 fix (docs/HReview.md). Both Safe-Z properties accept `Feed:`/`Retract:`/`Clearance:<n>` or
      a bare number. A **resolved F360 level** arrives from Fusion already in the output unit; the
      **literal fallback** is a dialog value and so is mm by the README's own contract. Only the
      second needed converting, and neither did. Two symptoms followed on an **inch** Setup:
      `I_Probe_SafeZ` retracted to `Z15` meaning 15 **inch** (381 mm — a full-travel move into the Z
      limit), and `C_MapRapids_SafeZ` compared every Z against a threshold of 15 inch, which no
      toolpath reaches, so the G1→G0 mapper silently converted nothing.

      **The fallback is reached more often than it looks** — not just by a bare number, but whenever
      the named F360 level is *relative* (`..._absolute != 1`) or absent, and whenever the expression
      is malformed. So `Retract:15` on an inch job with a relative retract height hits it.

      **Do (A) — inch job, bare-number probe Safe Z.** A Setup in **inches**, one milling op with a
      probe, `Safe Z` (group 06) = `20`. **Get (A):** the post-probe retract is
      ```
      (   Retract the tool to 0.7874015748031497)
      G0 Z0.7874 F<travelZ>
      ```
      and Resolved Values reads `Probe SafeZ = Const = 0.7874`. **Pass:** `Z0.7874`, **not** `Z20`.
      *(The unformatted number in the comment is pre-existing — `probeTool()` prints `retractZ` raw
      rather than through `zFormat`. Cosmetic; don't chase it here.)*

      **Do (B) — mm regression, the half that must not move.** The same job with the Setup in **mm**
      and `Safe Z` = `20`. **Get (B):** `G0 Z20` and `Probe SafeZ = Const = 20.000`, exactly as
      before. **Pass:** byte-identical to a pre-fix post. `propertyMmToUnit()` is the identity in mm,
      so **no existing mm-based PASS row is invalidated by HR-4** — this row is what proves that.

      **Do (C) — the mapper, inch job.** Inch Setup, `03 - Map G1s to Rapids` all on,
      `Map: Safe Z to Rapid` = `20`. **Get (C):** the per-section comment reads
      `( SafeZ using const: 0.7874015748031497)` — it was `( SafeZ using const: 20)` — and
      `( Safe G1 --> G0)` conversions now appear for moves at or above 20 mm. **Pass:** the threshold
      comment shows the converted value, and at least one `Safe G1 --> G0` appears where a pre-fix
      post of the same job had none. That comment is `Important` level, so it survives even at
      Comment Level `Important`.

      **Do (D) — header coherence.** Any inch job with `Retract:15` on both Safe-Z properties.
      **Get (D):** `Map SafeZ = Retract level, fallback 0.5906, resolves to <n>` — fallback and
      resolved value in the **same** unit. **Pass:** no line mixes mm and inch. Before the fix the
      fallback printed `15.000` beside a resolved `0.2000`.

      > **Harness evidence already on record.** The resolution logic was extracted and run in node
      > across both units at the time the fix landed: mm returns `15 / 15 / 15 / 20 / 15` for
      > level-absolute / level-relative / level-absent / bare-20 / malformed, and inch returns
      > `0.2 / 0.5906 / 0.5906 / 0.7874 / 0.5906` — F360 level values passing through untouched, every
      > fallback converted. That covers the arithmetic; the posts above are what confirm the values
      > reach the file.

      *Result:* ____

- [ ] **HR5 — `Scale Feedrate` reaches arcs.** Verifies the HR-5 fix (docs/HReview.md).
      `linearMovements()` has always run each `G1` through `limitFeedByXYZComponents()`; `circular()`
      emitted `fOutput.format(feed)` with Fusion's raw feed on both the GRBL and Marlin branches. So
      with **Use Arcs** on (default) and **Scale Feedrate** on (which the README tells the hobbyist to
      enable), a job whose tool feed exceeds **Max XY Cut Speed** had every straight cut scaled and
      every fillet emitted at full feed — defeating the feature on precisely the curved geometry a
      slow machine struggles with. Invisible unless you watch `F` across a `G1`→`G2` boundary.

      **Common settings:** GRBL, mm Setup, `Use Arcs` = on, `Scale Feedrate` = **on**,
      `Max XY Cut Speed` = `900`, `Max Z Cut Speed` = `180`, `Max Toolpath Speed` = `1000`,
      `Enforce Feedrate` = on (default, so every block carries `F` and no comparison depends on
      modal state). One operation containing **filleted / arc geometry** whose tool feed is `1800`.

      **Do (A) — the fix.** Post the job. **Get (A):** every `G2`/`G3` block carries `F900`, matching
      the `G1` blocks around it:
      ```
      G1 X.. Y.. F900
      G2 X.. Y.. I.. J.. F900
      ```
      **Pass:** no `F` above `900` anywhere in the body. Before the fix the arcs carried `F1800`, so
      the discriminator is a *grep for `F1800`* returning nothing.

      **Do (B) — the off branch.** Same job, `Scale Feedrate` = **off** (the property default).
      **Get (B):** arcs **and** straight cuts both carry `F1800` — the raw tool feed. **Pass:** the
      cap is gated on the property, and a default-settings job is untouched. **This is why no saved
      reference file is invalidated by HR-5:** `Scale Feedrate` defaults off, so every existing PASS
      row was posted on this branch.

      **Do (C) — the Max Toolpath Speed cap.** Same as (A) but `Max Toolpath Speed` = `500`.
      **Get (C):** arcs carry `F500`. **Pass:** the final cap applies to arcs as it does to lines.

      **Do (D) — a ZX/YZ-plane arc, GRBL only.** An operation producing a vertical-plane arc (e.g. a
      radius on a vertical wall). **Get (D):** the `G18`/`G19` arc carries `F180` — the **slower** of
      the XY and Z limits, because such an arc sweeps a linear axis *and* Z. **Pass:** `F180`, not
      `F900`. *(Marlin/RRF linearize non-XY arcs, so there this appears as `G1` moves limited the
      ordinary way — worth confirming once if you run the firmware variant.)*

      > **Not a defect — arcs can post slower than the lines either side of them.** The cap for an
      > arc is the axis limit itself, because an arc's instantaneous axis velocity reaches the full
      > toolpath feed wherever its tangent lines up with an axis. A diagonal `G1` is allowed to exceed
      > `900` (a 45° move at `F1270` puts ~900 on each axis), so a fillet at `F900` between two
      > diagonals at `F1270` is correct, not a regression. Deliberately conservative for short arcs
      > that never reach a quadrant point.

      > **Harness evidence already on record.** `limitArcFeed()` was unit-tested when the fix landed:
      > scaling off → untouched; XY arc `1800`→`900`; feed already under the limit → untouched; feed
      > exactly at the limit → unchanged; `Max Toolpath Speed 500` → `500`; ZX and YZ arcs → `180`;
      > ZX where Z is the faster axis → the XY limit; an inch job → `900 mm/min` converted to
      > `35.433 in/min`; zero feed → zero. Eleven cases, all passing. That covers the arithmetic; the
      > posts above confirm the values reach the file.

      *Result:* ____

- [ ] **HR6 — A rotated 3-axis Setup is rejected; an upright one is untouched.** Verifies the HR-6
      fix (docs/HReview.md). `onSection()` rejected multi-axis toolpaths but never checked a 3-axis
      section's **orientation**. A Setup built on a model face rather than the stock top has its Z
      along some other direction; Fusion emits ordinary X/Y/Z words for it, so the post emitted them
      as though the frame were upright — the part cut in the wrong plane, with nothing in the file to
      say so. This is the accident of picking the wrong face when creating a Setup.

      **Run (A) first, and treat it as the row that matters.** A false positive in this guard aborts
      *every* job, which is far worse than the misconfiguration it catches — so the regression half
      is the real test and the rejection half is the bonus.

      > **The guard is isolated in `isSectionOrientationSupported()`, and it traces on every path.**
      > The check was lifted out of `onSection()` (which now reads
      > `if (!isSectionOrientationSupported()) { return; }`) and its `eComment.Debug` trace moved
      > *outside* the rejection branch. This matters for reading (A): the guard **fails open**, so
      > before the trace was unconditional, "read `+Z` and correctly allowed it" and "read nothing and
      > gave up" produced **byte-identical files** — meaning a passing (A) could not tell a working
      > guard from dead code. (A) is now decisive on its own. Three trace shapes exist:
      > ```
      > ( onSection orientation: forward X0 Y0 Z1, tilt from machine Z 0 deg -> upright, section allowed)
      > ( onSection orientation: forward X1 Y0 Z0, tilt from machine Z 90 deg -> OFF-AXIS, section REJECTED)
      > ( onSection orientation: workPlane missing, forward missing -> UNREADABLE, check skipped, section allowed)
      > ```
      > The UNREADABLE variant also covers "workPlane present, forward missing" and a
      > `types string/string/string` suffix for non-numeric components. **Seeing UNREADABLE on a normal
      > Setup means HR-6 is a no-op** and needs a different predicate — the post would still post
      > everything, but the guard would catch nothing, and (B) would pass for the wrong reason.

      **Do (A) — the regression, i.e. nothing moved.** Re-post **any** previously-passing job
      unchanged — H2's default hobby job is the cheapest. **Get (A):** a complete file, identical to
      current output, with **no error and no `Tool orientation` message**. **Pass:** the job posts.
      A failure here means the guard misreads a normal Setup and must be reverted immediately — it
      would block all posting, so do not proceed to (B) until (A) passes.

      **Do (A2) — the same post at Comment Level = `Debug`.** **Get (A2):** one
      `onSection orientation:` line per section, reading **`forward X0 Y0 Z1, tilt from machine Z
      0 deg -> upright, section allowed`**. **Pass:** the components are real numbers and the verdict
      is `upright` — that is the evidence that Fusion populates `Section.workPlane.forward` and the
      guard is live rather than failing open.

      > **Where the line lands — before the whole header, not near the section.** On the first section
      > it appears immediately after the last `param:` line and **before `( Ranges Table:)`**, because
      > `onSection()` runs the guard ahead of `writeFirstSection()`, and `writeFirstSection()` is what
      > emits the Ranges/Tools/Properties/Resolved-Values header. In `H2 - Debug.gcode` that is line
      > 359, with the header starting at 361 and `G54` not until 474. Don't look for it in the
      > `SECTION begin` block.

      **Do (B) — the rejection.** Duplicate the hobby Setup and re-orient it: in the Setup dialog set
      the Z axis along the model's **X** (or pick a vertical face for the orientation). Keep one
      ordinary 3-axis milling operation in it. Post. **Get (B):** Fusion reports
      ```
      Tool orientation is not supported: this operation's Z axis is not the machine Z.
      Rebuild the Setup with its Z axis along the machine Z -- normally the stock top.
      ```
      **Pass:** the post errors and names the fix. At Comment Level = `Debug` the
      `-> OFF-AXIS, section REJECTED` trace precedes the error and shows the vector actually read —
      which, with (A2) in hand, distinguishes "guard is broken" from "Fusion reported the section as
      upright".

      > **Expect a truncated `.gcode` from (B), unlike Guard A/B/C.** This guard fires in
      > `onSection()`, by which point the header is already written, so Fusion may leave a partial
      > file on disk — whereas Guards A/B/C run in `onOpen()` and write nothing at all (H7d confirmed
      > that). Note whether a file appears and how much of it. Both geometry guards (multi-axis and
      > orientation) could be promoted into `validateJob()` so neither leaves a partial file; that is
      > recorded as a follow-up in docs/HReview.md rather than done here.

      > **Harness evidence already on record.** The guard predicate was extracted and exercised over
      > every shape `workPlane` might take: exact `+Z`, float noise, and a 0.001° tilt all **post**;
      > Z-along-X, Z-along-−Y, a 30° tilt and an inverted Z-down frame are all **rejected**; and a
      > missing `workPlane`, a missing `forward`, non-numeric components and `NaN` components all
      > **post** — the fail-open cases. Eleven cases, all passing. **Re-run unchanged after the
      > extraction into `isSectionOrientationSupported()`** — same eleven verdicts, no throws, and each
      > case now also emits its trace, which is how the three shapes quoted above were captured. What
      > the harness cannot tell you is what Fusion actually puts in `workPlane`, which is exactly what
      > (A2) and (B) settle.

      *Result:* **PASS — (A) and (A2).**
      **(A)** `H2.gcode` (2026-07-31): posts complete, no error, `Tool orientation` absent — nothing
      is blocked. **(A2)** `H2 - Debug.gcode` (2026-07-31), line 359:
      `( onSection orientation: forward X0 Y0 Z1, tilt from machine Z 0 deg -> upright, section
      allowed)` — one line, one section, and the file completes normally (570 lines, `M30`, `%`).
      **This is the finding that matters: the guard is live, not failing open.** Fusion does populate
      `Section.workPlane.forward`, its components are real numbers, and the value on an ordinary
      stock-top Setup is an exact `+Z` — so the predicate is evaluating a real vector on every
      section, and the eleven harness verdicts apply to what Fusion actually supplies.
      **(B) unrun** and still worth running: it is now the only untested link, since nothing here
      evidences what Fusion reports for a *re-oriented* Setup (it could in principle re-express the
      frame rather than tilt `forward`). Its failure mode is benign — a missed rejection, not a
      blocked job.

- [ ] **H-REG — Byte-for-byte regression (the key guarantee).** With the default reverted to
      `Set X0 Y0 to Current Pos, Probe Z0`, the **default** single-op output is again the pre-rework
      Current-Pos+Probe path (no jog `M0`) — so the byte-identical anchor is back on the default
      (**H2**). Post the H2 single-op job and diff it against the pre-rework default output (prior
      tagged `.cps` or a saved reference `.gcode`). **Pass:** **byte-for-byte identical** — the
      Current-Pos+Probe path preserves the old default exactly. *Result:* **OMITTED** — no practical
      way to produce the pre-rework reference; **H2** covers the path structurally. If ever revived,
      diff **motion only** — the property dump adds ~98 header comment lines to every file, so a raw
      diff against any pre-dump reference fails on the header alone. No motion changed.

      > **⚠ Do not revive this row as written.** The HR-1 fix appends ` Z0` to the default path's
      > `G10 L20` origin write, so a motion-only diff against a pre-rework reference now fails too —
      > the last sentence above ("No motion changed") no longer holds. Structural coverage of the
      > default path is **H2** + **HR1**; if a byte anchor is ever wanted again it must be
      > re-baselined against a current post, not against anything pre-rework.

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

- [ ] **D3 — Group order after the homing move.** The setup groups were reordered so everything
      positional is contiguous and the three "Establish" groups run in machine-execution order.

      **Do:** open the dialog with a **saved preset** loaded (any job whose settings you have
      previously customised — that is the part of this test that matters).

      **Get:** the group list reads, top to bottom:
      ```
      01 - Job
      02 - Feeds and Speeds
      03 - Map G1s to Rapids (disable when using full license)
      04 - Establish Machine Coordinates
      05 - Establish Spoilboard Reference
      06 - On WCS / Part / Fixture Changes
      07 - Tool Changes
      08 - External Include Files
      09 - Laser
      10 - Coolant
      11 - Duet
      ```
      with **9 / 7 / 4 / 2 / 4 / 10 / 8 / 5 / 7 / 10 / 2** properties in them respectively (68 total).

      **Pass — the discriminator is that nothing reset.** Only `group:` strings changed; no key, enum
      id, title or default moved. So **every customised value in your preset must survive** — spot-check
      Home Before Start, the two origin-mode dropdowns, and any nonzero Probe X/Y Offset, all of which
      should read exactly what they did before this change. A field back at its default means a key
      changed and the move was done wrong. Also confirm no group appears twice and none is empty.

      **Then post any job** and confirm the header dump reordered to match (it sorts on the same
      strings) — `02 - Feeds and Speeds` now appears before `03 - Map G1s ...`, and
      `04 - Establish Machine Coordinates` between Map-G1s and the spoilboard group.

      *Result:* **header half PASS** (`H7c-a/-b/-c.gcode` — new order, counts still summing to 68).
      **Dialog half outstanding** — a posted file cannot distinguish "the preset survived" from "the
      values were re-entered", which is the whole point of the check, so this one needs the dialog.

---

- [ ] **D2 — Header property dump.** Post any job and inspect the header. **Pass:** after the Ranges
      and Tools tables there is one `( Properties -- <group>:)` block for **each of the 11 groups**, in
      dialog order (`01 - Job` → `11 - Duet`), listing **all 68 properties** as `   <Key> = <value>`
      with keys in letter order within each group; enums show their stored **id** (e.g.
      `A_Probe_OnStart = Current XY & Probe Z`, not the display title); unset strings show `<empty>`
      while numeric zeros show `0`. Then a `( Resolved Values:)` block with output unit, resolved
      firmware, both Safe Zs, reserved base as `G59 / P6` or `None`, and the probe XY
      offset / Inter Part Safe Z in output units.

      **The two Safe-Z lines must report what the expression actually resolved to, not restate the
      property.** For `Retract:15` on a job whose operations retract to 5.08, expect
      `Probe SafeZ = Retract level, fallback 15, resolves to 5.08` — and `5.08` must equal the `G0 Z`
      the probe retract actually emits. A bare number reads
      `Const = 15 -- a fixed height, no F360 level consulted`; operations that resolve differently
      read `varies by operation -- 5.08, 12.7`. **This is the row's sharpest check:** these two lines
      are the only ones in the whole dump that cannot be read off the property list above them, so if
      they merely echo `Retract : default = 15` they are worse than absent — a reviewer trusts the
      block's title and expects `Z15`. Cross-check two or three values against what you
      actually set in the dialog, and confirm the two old blocks (`Feedrate and Scaling Properties`,
      `G1->G0 Mapping Properties`) are gone — their values now appear under the Feeds-and-Speeds and
      Map-G1s groups (`02` and `03` since the homing move; `03`/`04` in files posted before it).
      Also confirm the dump is **suppressed** at Comment Level `Important` and `Off`.
      *Result:* **PASS except the suppression check** — dump structure verified on `H7c.gcode`, the
      resolved Safe-Z lines on the `H7c-c.gcode` re-post (`resolves to 5.08`, matching the `G0 Z5.08`
      the file emits). **Still unrun:** Comment Level `Important` / `Off`.
      *(Known leftover: the group-03 **name** contains parentheses, which `sanitizeMessageText`
      strips, so its heading prints as `03 - Map G1s to Rapids  disable when using full license :`.
      Left alone — fixing it would alter a visible dialog label.)*

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

- **Group split & renumber.** *(Superseded in part by the homing move — see **D3**; the current
  order is `01 Job`, `02 Feeds`, `03 Map-G1s`, `04 Machine Coords`, `05 Spoilboard`, `06 On WCS`.)*
  `05 - Establish Spoilboard Reference` (4 items) sits between Map-G1s
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
- **Group 04 — Home Before Start** (None / XY / XYZ). `None` (default) → no homing,
  byte-identical. `XY` → one `$H` (GRBL/FluidNC) or `G28 X` / `G28 Y` (Marlin/RRF). `XYZ` → also
  `G28 Z` (Marlin/RRF; GRBL `$H` already homes all configured axes). `Prompt Before Home`
  (default off) pauses once before any homing, on every firmware and axis set.
- **Probe to Set Base** enum: `None` → Info "assumed pre-set", no probe; `Probe Z` → probe with
  no attach/detach prompt; `Pause, Probe Z, Pause` (default) → attach → probe → detach
  (byte-identical to the old On). Still writes `G10 L20 P<base> Z<thk>`, probing wherever the tool
  is parked — it emits no XY move.
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
**first part and each added part**, while the **spoilboard base probe ignores the offset entirely**
(it emits no XY move at all) and a
**zero offset stays byte-identical**. Firmware note: comments are `(...)` on GRBL and `;...` on
Marlin/RRF — the tokens below are otherwise identical. Coordinates are in the job's output units
(the emitted `G0 X/Y` values should equal the offsets you entered; check this in an inch job too).

Already confirmed by NC inspection — **do not re-run** (see Verified → Phase 4):
- Offset `0,0`, first/only part: no reposition, straight from the origin write into `G38.2`.
  *(⚠ that origin write is now `G10 L20 P1 X0 Y0 Z0` on the `Set X0 Y0 to Current Pos` /
  `Jog to X0 Y0` modes — HR-1's provisional Z0. The offset assertion is unaffected: the fix adds a
  `Z` word to an existing block and emits no motion.)*
- Spoilboard base probe: no `G0 X/Y` before its `G38.2` — the offset never reaches it.

Run these:

> The **first-part `Use Active WCS X0 Y0, Probe Z0`** mode × nonzero offset is a separate path
> (`writeWcsOnStart()` → `partProbe(false)`, no XY origin write) and is covered by **H7a** — not
> repeated here. P1 below covers the offset on the `Set X0 Y0 to Current Pos, Probe Z0` path.

- [x] **P1 — Nonzero offset, first/only part.** Single-WCS. Set
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
      result is still written to `P1`. *Result:* **PASS** (`Face1.gcode`, which also showed the
      reserved base probing with no reposition).

      > **⚠ `Face1.gcode` predates the HR-1 provisional Z0** — the expected block's origin write is
      > now `G10 L20 P1 X0 Y0 Z0`, preceded by the provisional-Z0 Info comment. **The row still
      > stands:** its assertions are all about the reposition rapid and the offset words, and HR-1
      > adds a `Z` word to a preceding block without emitting motion. Don't diff a fresh post against
      > the saved file blind.

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
      *Partial evidence already on disk:* `H7c.gcode` (base `G59` + offsets X10 Y5, single WCS)
      confirms the **base** and **first part** halves — base probes with no `G0 X/Y`, first part
      repositions to `X10 Y5`. Only the **added part (`P2`)** half remains, which needs the 2-part
      Replicate job.

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
- Base establish now wraps its probe in a `G59` select / `G54` restore and retracts to the Inter
  Part Safe Z in the base frame — **re-verified by H7c**; the multi-part case (**PB1**) is still
  outstanding.
- Base establish (now `Pause & Probe Z`, was On): spoilboard probe → `G10 L20 P6 Z<thk>`
  **before** the first section's own origin/probe; `G54` work still probes separately.
- Base establish `None` (was Off): no probe; Info comment
  `assuming base G59 is already established -- from a prior job or set manually`.
  *(The new `Probe Z` variant — probe with no attach/detach prompt — is in the re-verify list.)*
- **Guard A:** assigning an origin-establishing op to the reserved base aborts in `onOpen()`
  (`G59 is reserved as the spoilboard base -- assign this operation to another WCS ...`), naming
  the triggering feature; no g-code emitted. *(Re-confirmed by **H7d**.)*
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
  rapid. **⚠ Superseded by HR-1** — the origin write is now `G10 L20 P1 X0 Y0 Z0` (provisional Z0,
  overwritten by the probe) on the `Set X0 Y0 to Current Pos` / `Jog to X0 Y0` modes. Still no
  `X0 Y0` rapid at offset 0; re-verify under **HR1**.
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
- **Probe XY offset — offset `0` first part + base probe** (`Setup1-Face1.gcode`): first/only part
  goes `G10 L20 P1 X0 Y0` → `G38.2` with **no reposition rapid**; the reserved `G59` base probes with
  **no `G0 X/Y`**. Nonzero first-part is **P1/H7a** (passed); the added-part paths (**P2**, **P3**)
  remain — no posted file exercises them yet. **⚠ HR-1** appends ` Z0` to that origin write (and a
  comment before it); the offset findings hold, the saved file no longer matches byte-for-byte.
