# plan.md — live state: what is done, what is next, what is open

**The volatile file.** Read it at the start of every session, and nowhere else for status. It holds three
things and no others: the **checkpoint** (including what is left, in order), **phase status**, and pointers
to the **completed reviews**. Design write-ups, findings, test rows, resolved decisions and open questions
all belong in a register — `conventions.md` → *Document contracts* says which file owns what, and is the
thing to change first if you think something new belongs here.

---

## Checkpoint — restart here

*Written so a fresh session can resume with no other context. Update it when the situation moves.*

**Baseline.** Branch **`v4.0-doc-streamline`**. The last commit to change what the post *emits* is
**`c73726c`**; everything since is documentation plus one comment-only pass over the `.cps`. **Nothing is
half-done and nothing is known-broken.** Untracked and deliberate: both `MPCNC_v4.0_Beta*.zip`, and
`Personal.cps` (a test harness, excluded via `.git/info/exclude` — see `conventions.md`).

**Where the record lives.** The hobbyist review (`HR-1`…`HR-27`) and the 2026-08-01 whole-file review
(`CR-1`…`CR-17`) are one register in `HReview.md`: 44 findings, all fixed, closed by design or moved to
`PReview.md`, except three one-liners and **HR-27**, unstarted. **Neither pass found the factory-default
single-operation job broken** — every High/Medium finding needed one dialog field moved off its default.
Test rows are in `HReview.md`'s test register (hobbyist) and `PReview.md` §3 (professional); nothing else
records a pass, and the Method column matters as much as the state (`conventions.md` → *How to run a test*).

**What is left, in order.**

| | Item | Note |
|---|---|---|
| 1 | **Post-verify the 14 `CR-` fixes** | The four `⬜` rows in `HReview.md`'s test register, **`CR-REG` first** — the GRBL/mm factory-default regression matters most. `CR-1 (A)` needs `Enable Line #s` on + `Home Before Start = XY`, a combination no configuration in the record has used. Two further posts serve `PReview.md` §3.5 |
| 2 | **Tidy-up sweep** | `HR-19`'s `M291` doubled space; **HR-21 / CR-15** (wire the dead `Tool Change Probe` property into `probeTool()` — Tool Change branch work — or delete it); **HR-24** (`writeWCS()` should read `section.getTool()`, not the global `tool`). All one-liners, none changing output |
| 3 | **Dialog-only checks** | **D1** and **D3**'s dialog half (`PReview.md` §3.3). The properties literal is now declared in display order, so if the dialog *still* shows groups out of numeric order, Fusion is not sorting and the zero-padding convention is wrong |
| 4 | **Open the Tool Change branch** | `PReview.md` §2 — the ordering design and **HR-7/8/9/10/13**, as one unit. Design settled for the ordering half; HR-10 and HR-13 have complete diffs and can go first as warm-up commits |
| 5 | **The professional review proper** | The pass that produces `PReview.md`'s real content. Needs a multi-part / multi-fixture job to post against |
| 6 | **Jet / laser workstream** | `PReview.md` §5. **J4 is the priority** — group 09 has never appeared in *any* posted file, and CR-10 landed a fix there sight-unseen. The `CR-10 (A)` row is that post. J5 is a design question before it is a test |

**The one live risk that could still hide a real defect: `HR-6 (B)`** — the orientation guard may be a
no-op on exactly the case it exists to catch, and the failure mode is a part cut in the wrong plane,
silently. It needs a rotated Setup. Written up in `HReview.md` → *Owed*.

**No controller access**, so firmware questions are settled from source — `conventions.md` →
*How to run a test* and *Firmware capabilities*.

---

## Phase status

- **Phases 1–3 — done & verified.** WCS origin/probe rework to `G10 L20`; `writeWcsOrigin()`; MCS homing;
  reserved base + establish + Guards A/B/C.
- **Phase 4 — in progress.** All of it has landed except tool-change ordering + base-relative park — design
  settled, written up in `PReview.md` §2. Verification is still owed on the probe XY offset's added-part
  halves and on the multi-part rows generally.
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
