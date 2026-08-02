# plan.md — live state: what is done, what is next, what is open

**The volatile file.** Read it at the start of every session and nowhere else for status. It holds only
what moves: the checkpoint, the ordered backlog, phase status, and open decisions as a pointer apiece.
Anything here that has stopped changing belongs in `conventions.md`.

| File | Owns |
|---|---|
| `docs/conventions.md` | **The durable half** — stance, coordinate model, base/frame/probing, guards, property & dialog conventions, how to run a test, harness method |
| `docs/HReview.md` | The hobbyist findings register + the test register |
| `docs/PReview.md` | The professional side — findings, every multi-WCS / base / tool-change / dialog row, the jet/laser workstream. **The professional review itself has not been done** |
| `README.md` | User-facing usage. Not touched during code changes |
| this file | Checkpoint, remaining work, backlog, open decisions |

---

## Checkpoint — restart here

*Written so a fresh session can resume with no other context. Update it when the situation moves.*

**Baseline.** Branch **`v4.0-hreview-fixes`** at **`c73726c`**. **Nothing is half-done and nothing is
known-broken.** Untracked and deliberate: `MPCNC_v4.0_Beta1.zip`, and `Personal.cps` (a test harness,
excluded via `.git/info/exclude` — see `conventions.md` → *Working method*).

**Two reviews are finished.** The **hobbyist review** (`HReview.md`) — 26 findings, 13 fixed and verified,
6 moved to `PReview.md`, 83 test rows, nothing failing or unrun. And the **full code review**
(`review.md`, 2026-08-01) — a fresh pass driven by the dialog and the F360 API, 17 findings, **14 fixed at
`c73726c`**, 3 closed as by-design. Nothing in either found the factory-default single-operation job
broken; every High/Medium finding needed one dialog field moved off its default.

**What the code review changed that a reader will notice.** `$H` no longer breaks under line numbering;
`validateJob()` warns on homing-plus-`Current Pos` origin and on a suppressed multi-tool change;
`onClose()` stops the spindle **before** the return traverse; the coolant `Use custom` fields load a file
as documented; a jet job warns that Z0 was never established; and the `properties` literal is now declared
in dialog order (a pure move — checksum-verified, no preset resets).

**Status lives in two registers.** `HReview.md`'s test register for hobbyist rows; `PReview.md` §3 for
professional ones. Nothing else records a pass. **Read the Method column, not just the state** —
`posted` is a real file from the real post and the only method that proves what a hobbyist receives;
`read` is a reading of control flow and is **weaker than the rest**.

**What is left, in order.**

| | Item | Note |
|---|---|---|
| 1 | **Post-verify the 14 fixes** | `review.md` → *Verification*. Five posts; **post 1 (GRBL/mm defaults) is the regression that matters most**. CR-1 additionally needs `Enable Line #s` on + `Home Before Start = XY`, a combination no configuration in the record has ever used |
| 2 | **Tidy-up sweep** | `HR-19`'s `M291` doubled space, **HR-21** (wire the dead `Tool Change Probe` property into `probeTool()` — Tool Change branch work — or delete it), **HR-24** (`writeWCS()` should read `section.getTool()`, not the global `tool`). All one-liners, none changing output |
| 3 | **Dialog-only checks** | **D1** and **D3**'s dialog half (`PReview.md` §3.3). CR-14 sharpened D1: the literal is now declared in display order, so if the dialog *still* shows groups out of numeric order, Fusion is not sorting and the zero-padding convention is wrong |
| 4 | **Open the Tool Change branch** | *Phase 4* below, folded with **HR-7/8/9/10/13** (`PReview.md` §2). Design settled for the ordering half; HR-10 and HR-13 have complete diffs and can go first as warm-up commits |
| 5 | **The professional review proper** | The pass that produces `PReview.md`'s real content. Needs a multi-part / multi-fixture job to post against |
| 6 | **Jet / laser workstream** | `PReview.md` §5. **J4 is now the priority** — group 09 has never appeared in *any* posted file, and `review.md` CR-10 landed a fix there sight-unseen. J5 is a design question before it is a test |

**The one residual that could still hide a real defect: `HR-6 (B)`.** The orientation guard rejects a
tilted `workPlane.forward` — proven over 13 vectors by harness — but **nothing evidences what Fusion
actually puts in `forward` for a re-oriented Setup.** If Fusion re-expresses the frame so `forward` stays
`X0 Y0 Z1`, the guard is a no-op on exactly the case it exists to catch. No code reading can settle it; it
needs a rotated Setup. The failure mode is a **missed** rejection — a part cut in the wrong plane,
silently.

**Closed decisions — do not relitigate.**

- **HP-1's group-03 clause** was amended: group 03 is part of the HP-1 *persona*, not of the config a
  verification post must carry. It cannot execute on a paid licence (`isSafeToRapid()` has one caller,
  `onLinear()`, and full Fusion emits real `G0`s). **Don't re-add it.**
- **`HR-23` / `HR-22 (B)` — an include file substitutes for the phase it names**, modal preamble included.
  A Stop include therefore drops coolant-off, the spindle-off prompt, `M84 S60` and `M30`/`M2`; a Start
  include owns `G90`/`G21`/`G94`/`G17`, and a named-but-*empty* one is the degenerate case of the same
  rule. Both were filed as defects and both resolved as correct. **The reusable lesson: before calling a
  bypass a defect, ask whether the bypass is the feature.** What it needs is a README line.
- **`HR-25` (`wcsGcode(0)` → `G53`) and the `()` empty-comment form** are correct as built — a pure
  conversion should not carry frame policy, and the separator is deliberately comment-level-gated.

**Three things a fresh session will otherwise get wrong.**

1. **Fusion posts with its own copy** of the `.cps` at `%APPDATA%\Autodesk\Fusion 360 CAM\Posts\`. A
   session was once posted twice because the first run used a copy three hours stale, and two rows
   asserting an *absence* would have been recorded as false PASSes. Copy the post, then **date the output**
   against a token the newest commit changed.
2. **Read the posted file's own property dump before believing a row ran.** Six files were once posted
   with the whole `03` group `false`, which left a row unrun rather than passed.
3. **Posted `.gcode` is not in the repo**, so a reused filename destroys evidence with no way back. **Name
   a post for the row it serves** (`HR12a`), not for what the job does, and grep the review files for the
   filename before re-posting.

**No controller access.** Settle firmware questions from Marlin/RRF source and changelogs; never file a
row that needs a non-GRBL machine. Two answered that way: Marlin has never implemented `M2` (RRF gained it
in 3.5.1), and GRBL/Marlin/RRF all accept a bare `\r` as a block terminator. A third: **no supported
firmware has canned drilling cycles** — GRBL omits them deliberately, Marlin's `G81`–`G83` need an opt-in
`CNC_DRILLING_CYCLE` build, and on the RepRap dialect `G80`–`G83` mean mesh-probe/babystep, so emitting
one would be worse than useless. `expandCyclePoint()` is correct and needs no revisiting.

---

## Phase status

- **Phase 1–3 — done & verified.** WCS origin/probe rework to `G10 L20`; `writeWcsOrigin()`; MCS homing;
  reserved base + establish + Guards A/B/C.
- **Phase 4 — in progress.** Landed and verified: Guard B; Inter Part Safe Z + Retract Across Parts; the
  base-relative transit-through-base retract; added-part re-probe repositioning; the base-frame base
  establish; the six-mode first-part origin model; the full property dump; the group/label rework. Landed
  with verification pending: the probe XY offset's added-part halves and the multi-part rows generally.
  **Remaining to build:** tool-change ordering + base-relative park (below).
- **Phase 5 — answered, no work needed.** `isSafeToRapid()` is called only from `onLinear()` and is scoped
  to a single section, so the G1→G0 mapper cannot run across the boundaries Phase 4 injects logic at.
  Close it as a no-op when Phase 4 lands.
- **Hobbyist review — complete.** `HReview.md`.
- **Full code review — complete.** `review.md`; 14 fixes at `c73726c`, post-verification owed.
- **Professional review — not started.** `PReview.md` is a parking lot until it runs.

## Completed reviews (archived)

Every finding is fixed in `MPCNC_v4.0_Beta2.cps` and preserved in git. Recover the rationale if needed:

- **Code-quality review** — 26 findings, all fixed. `git log --follow -- docs/known-issues-v4.md`
- **Autodesk / F360 compliance review** — F1–F11, all resolved. `git log --follow -- docs/f360-compliance-issues.md`
- **Floating-point comparison review** — FP1 fixed. `git log --follow -- docs/float-comparison-review.md`
- **Beta-2 test plan** — dissolved into the review files. `git log --follow -- docs/test-plan.md`

---

## Remaining work (pick up here)

### Phase 4 — tool-change ordering + base-relative park *(one unit; design settled)*

> **This is the Tool Change branch's work.** Tool changes are a professional feature, so this item and the
> five deferred findings — **HR-7**, **HR-8**, **HR-9**, **HR-10**, **HR-13** — land together on a separate
> branch. Read each one's entry in `PReview.md` §2 first; **HR-10 and HR-13 have complete diffs and are
> independent of the reorder**, so they can go in first as warm-up commits.

Root cause: in `onSection()`, `toolChange()` runs **before** `writeWCS(currentSection)` for non-first
sections, so a boundary that is both a tool change and a WCS change **re-probes into the wrong WCS**
(`toolChange()`'s re-probe writes `G10 L20` into `currentWorkOffset`, still the *previous* part's WCS) and
**parks in the wrong frame**.

Fix — reorder so the WCS is resolved before the tool-change re-probe, and coordinate the two so a combined
boundary does each thing once:

1. Run `writeWCS()` first — it owns the base retract and the frame switch. When a tool change on the same
   section will re-probe, have `writeWCS()` **skip its own `B_Probe_OnChange` probe** and let the
   tool-change flow own the single re-probe, now into the correct WCS.
2. The tool-change re-probe **repositions to the new part's `X0 Y0`** before measuring (the same fix
   already applied to the added-part probe), so it reads the stock top and not the park point.
3. **Park position, two branches (decision):** base reserved → park relative to the base (a fixed physical
   spot for the whole job), reusing the transit-select machinery; no base → plain `G0` in the current WCS,
   as today. **Never `G53`.** *(The stale code comment at the tool-change position still argues for `G53`;
   remove it with this work.)*

Net at a both-boundary: retract through base → switch WCS → park → swap → rapid to `X0 Y0` → probe once
into the correct WCS. Test matrix in `PReview.md` §3.4.

### Future work — a machine-coordinate base probe point (`G53`) *(not started; design sketch)*

The base probes wherever the tool is parked, defended only by an operator precondition. The durable fix is
to give the base an explicit **probe point in machine coordinates** — `G53 G0 X<n> Y<n>` before the
`G38.2` — so the touch-off lands on the same bare-spoilboard spot every run.

**Rejected: `G53 G0 X0 Y0` (machine zero itself).** It is the homing corner — the extreme of travel,
routinely off the spoilboard entirely; it is machine-config dependent (`$23`/`$27`/`$130`–`$132`); and Z is
unsolved. Today the base establish emits *no motion at all*, so the unknown Z is inert; adding a traverse
converts that into a full-bed diagonal at an unknown height.

**Sketch, if built.** A group-05 property pair (base probe point X/Y, machine coordinates, whole mm),
emitted as `G53 G0 X<n> Y<n>` immediately before the base `G38.2`, plus:

- **Guard: requires homing.** Refuse (or warn) when `A_Machine_HomeBeforeStart = None` — machine zero is
  arbitrary there. This is the first place groups `04` and `05` interact, and why they sit adjacent.
- **An answer for Z:** require `XYZ` homing, or precede the move with an `M0` *"jog clear in Z, then
  continue"*. The prompt is preferred — it works on the no-Z-endstop machines that are the majority.
- **Default off** (empty = today's probe-where-parked behaviour).

**Reconcile `G53` across all three uses before building any of it.** This file carries a standing **"Never
`G53`"** decision. The three candidate uses — base probe point, tool-change park, cross-part retract —
should be decided **together**, since they share one question: *does this post ever address the machine
frame directly, or is everything work-relative?* The current answer is "everything work-relative"; this
item is the strongest case for revisiting it, because a spoilboard is the one thing in the job that
genuinely is fixed to the machine.

### Backlog

- **"Copy first part's Z" mode on `B_Probe_OnChange`.** Write the first part's probed Z into each added
  copy's own register (`G10 L20 P<n> Z<firstPartZ>`) — a register write, **no motion, no probe** — for
  same-thickness co-planar fixtures. Requires caching the first part's probed Z. Marlin no-op.
- **WCS `0`/`1` mixed-design warning (human factors).** A job using work offset `0` in one section and `1`
  in another resolves both to `G54`, but reads as two deliberate fixtures in Fusion's Operations panel.
  Emit a `>>> WARNING` when a job mixes `0` with a *different* explicit offset. The correct rule is
  any-section-vs-any-other-section, broader than Fanuc's order-dependent check.
- **`useZeroOffset` enforcement.** `wcsDefinitions.useZeroOffset: false` is declared but likely inert — the
  enforcing `validateCommonParameters()` lives in a shared post library this post doesn't import, so
  `writeWCS()` still silently aliases `0`→`1`. Natural companion to the item above.
- **`permittedCommentChars` global.** A comparable community GRBL post declares it; research whether it
  adds real kernel-side filtering on top of `sanitizeMessageText()` before adding — may be informational.
- **Global-metadata gaps.** Optionally `model`. Cosmetic.

---

## Decisions (resolved)

- **`B_Machine_PromptBeforeHome`** pauses once before any homing motion, on any firmware and for any axes.
- **Homing is one enum (None / XY / XYZ)**; homing order is not post-controlled.
- **`B_Spoilboard_BaseEstablish`** defaults **Pause & Probe Z**; `None` emits an "assumed pre-set" comment.
- **Marlin multi-WCS is a hard post error** (Guard C).
- **No real TLO** — per-tool re-probe is the substitute.
- **Multi-WCS supports two coexisting per-part workflows** — one WCS per part/copy. (1) *Pre-set fixture
  offsets (Replicate):* `Skip` or `Probe Z`. (2) *Manual per-part:* the two `Jog …` modes. One part from
  **multiple datums on the same fixture** is supported (`PReview.md` PA1); a **flip or re-clamp** is out of
  scope for a single run — separate jobs.
- **Tool-change position:** base-relative when a base is reserved, else current-WCS. Never `G53`.
  *(Current code does only the no-base branch.)*
- **HR-11's `M84 S60`, not a bare `M84`** — restore a 60-second timeout rather than dropping Z on an
  unbalanced LowRider gantry.
- **Tool changes and Manual NC are professional features** — their findings live in `PReview.md`.
- **An include file substitutes for the phase it names** (HR-23 / HR-22 (B)); `wcsGcode()` carries no frame
  policy (HR-25); the `()` empty-comment separator is comment-level-gated on purpose.

**Open decisions carried forward.** Each is written up where it lives:

- whether first-part `Use Active WCS X0 Y0 Z0` should hold the base clearance instead of descending to the
  probe Safe Z when a base is reserved *(`PReview.md` §6)*;
- `wcsDefinitions` offset-`0` handling *(backlog above; test row in `PReview.md` §3.4)*;
- whether the spoilboard base should gain an explicit probe-point XY *(Future work — `G53`, above)*;
- whether the **added-part** `Jog to X0 Y0, Probe Z0` should get HR-1's provisional `Z0` for symmetry
  *(settle on the PA1/M4 run)*;
- whether **HR-2's** two-signal probe guard keeps its extra breadth or trims to the strict reference form;
- how **HR-26** should be closed — `writeBaseEstablish()` skips the probe for a jet/tool-0 job, but
  `retractThroughBaseClearance()` has no matching guard and will still emit an absolute `G0 Z` in a frame
  whose Z0 was never set. **The one place the "never move absolutely in an unestablished frame" rule is
  broken.** Candidates: a module-level `baseEstablished` flag, a `validateJob()` refusal, or falling back
  to the outgoing frame's probe Safe Z *(`PReview.md` §3.4)*;
- whether `onClose()`'s return-to-origin should retract Z first — declined for milling, still owed for jet
  *(`review.md` CR-6, `PReview.md` §5)*.

*The frame-dependence of the `G38.2` probe target is closed on the first-part probe modes (HR-1). It
remains open for the `Use Active WCS`, added-part and base probes, which descend from a retracted clearance
and would be made **worse** by the same fix.*

**README.** Doc-sync marker points at `924d1f6`. Standing preference: **the README is not touched during
code changes unless asked.** Owed to the next sync, list kept in `HReview.md` → *Owed* item 6: the stale
group-03 label, the group-08 "post processor might be unsafe" prompt, HR-23's substitution contract, and
the `Tool Change Probe` field that does nothing. **Add from `review.md`:** the coolant `... Custom` fields
now load a file (CR-4), and the `Use Active WCS X0 Y0 Z0` Safe Z move can descend (CR-16).

