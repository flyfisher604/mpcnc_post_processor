# plan.md — live state: what is done, what is next, what is open

**The volatile file.** Read it at the start of every session and nowhere else for status. It holds only
what moves: the checkpoint, the ordered backlog, phase status, and open decisions as a pointer apiece.
Anything here that has stopped changing belongs in `conventions.md`.

| File | Owns |
|---|---|
| `docs/conventions.md` | **The durable half** — stance, coordinate model, base/frame/probing, guards, firmware capabilities, property & dialog conventions, how to run a test, harness method |
| `docs/HReview.md` | The hobbyist findings register (`HR-`, `CR-`) + the 87-row test register |
| `docs/PReview.md` | The professional side — findings, every multi-WCS / base / tool-change / dialog row, the jet/laser workstream. **The professional review itself has not been done** |
| `README.md` | User-facing usage. Not touched during code changes; its own `doc-sync` marker records what it last synced to |
| this file | Checkpoint, remaining work, backlog, open decisions |

---

## Checkpoint — restart here

*Written so a fresh session can resume with no other context. Update it when the situation moves.*

**Baseline.** Branch **`v4.0-doc-streamline`**. The last commit to change what the post *emits* is
**`c73726c`**; everything since is documentation plus one comment-only pass over the `.cps`. **Nothing is
half-done and nothing is known-broken.** Untracked and deliberate: both `MPCNC_v4.0_Beta*.zip`, and
`Personal.cps` (a test harness, excluded via `.git/info/exclude` — see `conventions.md`).

**Two review passes are finished, and they are now one register.** The hobbyist review (`HR-1`…`HR-26`)
and the 2026-08-01 whole-file review driven by the dialog and the F360 API (`CR-1`…`CR-17`) both live in
`HReview.md`. 43 findings: all fixed, closed by design, or moved to `PReview.md`, except three one-liners
awaiting a tidy-up sweep. **Neither pass found the factory-default single-operation job broken** — every
High/Medium finding needed one dialog field moved off its default.

**What the `CR-` pass changed that a reader will notice.** `$H` no longer breaks under line numbering;
`validateJob()` warns on homing-plus-`Current Pos` origin and on a suppressed multi-tool change;
`onClose()` stops the spindle **before** the return traverse; the coolant `Use custom` fields load a file
as documented; a jet job warns that Z0 was never established; and the `properties` literal is now declared
in dialog order (a pure move — checksum-verified, no preset resets).

**Status lives in two registers.** `HReview.md`'s test register for hobbyist rows; `PReview.md` §3 for
professional ones. Nothing else records a pass. **Read the Method column, not just the state** —
`posted` is a real file from the real post and the only method that proves what a hobbyist receives;
`read` is a reading of control flow and is **weaker than the rest**. The preconditions that make a post
trustworthy at all are in `conventions.md` → *How to run a test*; a session that skips them has produced
false PASSes before.

**What is left, in order.**

| | Item | Note |
|---|---|---|
| 1 | **Post-verify the 14 `CR-` fixes** | The four `⬜` rows in `HReview.md`'s test register, **`CR-REG` first** — the GRBL/mm factory-default regression is the one that matters most. `CR-1 (A)` needs `Enable Line #s` on + `Home Before Start = XY`, a combination no configuration in the record has ever used. Two further posts serve `PReview.md` §3.5 |
| 2 | **Tidy-up sweep** | `HR-19`'s `M291` doubled space, **HR-21 / CR-15** (wire the dead `Tool Change Probe` property into `probeTool()` — Tool Change branch work — or delete it), **HR-24** (`writeWCS()` should read `section.getTool()`, not the global `tool`). All one-liners, none changing output |
| 3 | **Dialog-only checks** | **D1** and **D3**'s dialog half (`PReview.md` §3.3). CR-14 sharpened D1: the literal is now declared in display order, so if the dialog *still* shows groups out of numeric order, Fusion is not sorting and the zero-padding convention is wrong |
| 4 | **Open the Tool Change branch** | *Phase 4* below, folded with **HR-7/8/9/10/13** (`PReview.md` §2). Design settled for the ordering half; HR-10 and HR-13 have complete diffs and can go first as warm-up commits |
| 5 | **The professional review proper** | The pass that produces `PReview.md`'s real content. Needs a multi-part / multi-fixture job to post against |
| 6 | **Jet / laser workstream** | `PReview.md` §5. **J4 is the priority** — group 09 has never appeared in *any* posted file, and CR-10 landed a fix there sight-unseen. The `CR-10 (A)` row is that post. J5 is a design question before it is a test |

**The one residual that could still hide a real defect: `HR-6 (B)`.** The orientation guard rejects a
tilted `workPlane.forward` — proven over 13 vectors by harness — but **nothing evidences what Fusion
actually puts in `forward` for a re-oriented Setup.** If Fusion re-expresses the frame so `forward` stays
`X0 Y0 Z1`, the guard is a no-op on exactly the case it exists to catch. No code reading can settle it; it
needs a rotated Setup. The failure mode is a **missed** rejection — a part cut in the wrong plane,
silently.

**No controller access.** Settle firmware questions from Marlin/RRF source and changelogs; never file a
row that needs a non-GRBL machine. Three have been answered that way and the answers are in
`conventions.md` → *Firmware capabilities*.

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
- **Full code review — complete.** 14 fixes at `c73726c`, post-verification owed (item 1 above).
- **Professional review — not started.** `PReview.md` is a parking lot until it runs.

## Completed reviews (archived)

Every finding is fixed in `MPCNC_v4.0_Beta2.cps` or carried in a register, and the reasoning is preserved
in git. Recover it with `git log --follow -- <path>`:

- **Code-quality review** — 26 findings, all fixed. `docs/known-issues-v4.md`
- **Autodesk / F360 compliance review** — F1–F11, all resolved. `docs/f360-compliance-issues.md`
- **Floating-point comparison review** — FP1 fixed. `docs/float-comparison-review.md`
- **Beta-2 test plan** — dissolved into the review files. `docs/test-plan.md`
- **Full code review** — 17 `CR-` findings, dissolved into `HReview.md`'s registers. `docs/review.md`

---

## Remaining work (pick up here)

### Doc-set and memory streamline *(in progress on this branch)*

Splitting the docs by volatility, dissolving `review.md`, moving the project's working rules out of
per-user memory into `CLAUDE.md` and `conventions.md`, and adding `.claude/settings.json`. Strike this
entry when the migration commits are in.

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
- **Promote the two geometry guards into `validateJob()`.** Multi-axis and HR-6's orientation check fire in
  `onSection()`, so they can leave a truncated file on disk where A/B/C cannot.

---

## Decisions (resolved) — do not relitigate

Only what would otherwise be re-argued. Anything the code plainly states is not repeated here.

- **Multi-WCS supports two coexisting per-part workflows** — one WCS per part/copy. (1) *Pre-set fixture
  offsets (Replicate):* `Skip` or `Probe Z`. (2) *Manual per-part:* the two `Jog …` modes. One part from
  **multiple datums on the same fixture** is supported (`PReview.md` PA1); a **flip or re-clamp** is out of
  scope for a single run — separate jobs.
- **Tool-change position:** base-relative when a base is reserved, else current-WCS. **Never `G53`.**
  *(Current code does only the no-base branch.)*
- **Tool changes and Manual NC are professional features** — their findings live in `PReview.md`, and the
  work lands on a separate Tool Change branch.
- **`HR-11`'s `M84 S60`, not a bare `M84`** — restore a 60-second timeout rather than dropping Z on an
  unbalanced LowRider gantry.
- **An include file substitutes for the phase it names** (HR-23 / HR-22 (B) / CR-7), modal preamble
  included, and a named-but-*empty* one is the degenerate case of the same rule. Both were filed as defects
  and both resolved as correct. **The reusable lesson: before calling a bypass a defect, ask whether the
  bypass is the feature.**
- **`wcsGcode()` carries no frame policy** (HR-25 / CR-17 (d)), and the `()` empty-comment separator is
  comment-level-gated on purpose (HR-19 / CR-17 (b)).
- **Group 03 is part of the HP-1 *persona*, not of the config a verification post must carry.** It cannot
  execute on a paid licence — `isSafeToRapid()` has one caller, `onLinear()`, and full Fusion emits real
  `G0`s. **Don't re-add it to HP-1's definition.**
- **The byte-identical guarantee is gone, deliberately.** Advanced features still emit nothing until
  enabled — that shape survives — but a future default-output change is a decision to be argued, not a line
  that cannot be crossed.

**Open decisions carried forward.** One line each; each is written up where it lives.

| Question | Written up in |
|---|---|
| Should first-part `Use Active WCS X0 Y0 Z0` hold the base clearance instead of descending to probe Safe Z when a base is reserved? | `PReview.md` §6 |
| `wcsDefinitions` offset-`0` handling | Backlog above; test row in `PReview.md` §3.4 |
| Should the spoilboard base gain an explicit probe-point XY? | *Future work — `G53`*, above |
| Should the **added-part** `Jog to X0 Y0, Probe Z0` get HR-1's provisional `Z0` for symmetry? | Settle on the PA1/M4 run |
| Does **HR-2**'s two-signal probe guard keep its breadth, or trim to the strict reference form? | `HReview.md` HR-2 |
| How is **HR-26** closed? `retractThroughBaseClearance()` has no jet guard, so it can emit an absolute `G0 Z` in a frame whose Z0 was never set — **the one place the "never move absolutely in an unestablished frame" rule is broken** | `PReview.md` §3.4 |
| Should `onClose()`'s return-to-origin retract Z first? Declined for milling, still owed for jet | `HReview.md` CR-6; `PReview.md` §5 |
| **HR-21 / CR-15** — wire `Tool Change Probe` into `probeTool()`, or delete the property? | `HReview.md` HR-21 |

*The frame-dependence of the `G38.2` probe target is closed on the first-part probe modes (HR-1). It
remains open for the `Use Active WCS`, added-part and base probes, which descend from a retracted clearance
and would be made **worse** by the same fix.*
