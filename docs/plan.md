# plan.md — live state: what is done, what is next, what is open

**The volatile file.** Read it at the start of every session, and nowhere else for status. It holds three
things and no others: the **checkpoint** (including what is left, in order), **phase status**, and pointers
to the **completed reviews**. Design write-ups, findings, test rows, resolved decisions and open questions
all belong in a register — `conventions.md` → *Document contracts* says which file owns what, and is the
thing to change first if you think something new belongs here.

---

## Checkpoint — restart here

*Written so a fresh session can resume with no other context. Update it when the situation moves.*

**Baseline.** Branch **`Goto-0,0`**, cut from `machine-frame-design` (itself cut from `PropertyUpdate`).
`PReview.md` **PR-6** has landed there — `At End Go to 0,0` never said *which* X0 Y0, and it was the
last section's WCS; it is now `At End Park At` = `Off` / `Work X0 Y0` / `Machine X0 Y0`, the machine
answer being `G53 G0 X0 Y0` on GRBL/RepRap and `G28 X Y` on Marlin. **Also unposted.** The branch
name is `Goto-0,0`, not `Goto 0,0`: git refs cannot contain a space.

On the parent branch, **the machine-frame / fixed-Z-reference rework has landed, and its dialog has since
been consolidated** — `PReview.md` **PR-1 · PR-2 · PR-3 · PR-5** and `HReview.md` **HR-28**. Together with
PR-6 these are **the first changes since `c73726c` to alter what the post emits.** Nothing is half-done;
**nothing is posted.** Untracked and deliberate: both `MPCNC_v4.0_Beta*.zip`, and `Personal.cps` (a test
harness, excluded via `.git/info/exclude` — see `conventions.md`).

**What that rework did, in one line each.** Group 4 became a machine declaration + `Home at Job Start`
(the action), replacing the `None`/`XY`/`XYZ` enum that conflated the two. Group 5 became
`Fixed Z Reference` — `None` / `Spoilboard` / `Machine Z` — so a homed machine Z is a second
implementation of the frame the reserved base used to be the only route to; the machine-Z answer emits
`G53 G0 Z<Inter Part Travel Z>`, consumes no WCS register and needs no probe. **PR-5 then collapsed the
two new booleans into one `Axises Homed and Trusted` enum (`None`/`XY Only`/`Z Only`/`XYZ`) and the two
mutually-exclusive clearance fields into one `Inter Part Travel Z` whose frame follows `Fixed Z
Reference`** — which forces that field empty by default, since a live default would let an enum flip emit
a valid-looking height in the wrong frame. Guard B relaxed to *a* datum of
either kind; four guards and two warnings added; `Probe to Set Base = None` removed. **This resolves the
standing "Never `G53`" decision** (`PReview.md` §6): the post addresses the machine frame on exactly the
axes the operator declares.

**Two things it deliberately did not do.** The **`G53` tool-change park** is `PReview.md` **PR-4** — it
shares code with §2's Phase 4 reorder and must compose with that design, not pre-empt it. And **both
review files now exceed their size budgets** (`conventions.md` 559/480, `PReview.md` 1035/920, both `WARN`
not `FAIL`): a Rule-2 pass found nothing *live* had leaked in — the growth is new model, external firmware
fact and five landed findings — so the open question is whether to raise those two budgets in the
contracts table or move content out (the `Reference — per-machine settings` table is the one section that
fails `conventions.md`'s own admission test, and reads as README material).

**Where the record lives.** The hobbyist review (`HR-1`…`HR-27`) and the 2026-08-01 whole-file review
(`CR-1`…`CR-17`) are one register in `HReview.md`: 44 findings, all fixed, closed by design or moved to
`PReview.md`, except three one-liners and **HR-27**, unstarted. **Neither pass found the factory-default
single-operation job broken** — every High/Medium finding needed one dialog field moved off its default.
Test rows are in `HReview.md`'s test register (hobbyist) and `PReview.md` §3 (professional); nothing else
records a pass, and the Method column matters as much as the state (`conventions.md` → *How to run a test*).

**What is left, in order.**

| | Item | Note |
|---|---|---|
| 0 | **Post-verify the machine-frame rework and the end park** | It is unposted, and it changed the dialog and the emitted file. **`PReview.md` REG-MF first** — the GRBL/mm factory-default diff, which must touch only the property dump and the Resolved-Values block. Then **PR-5a** (the enum flip — the one hazard consolidation created, and the row PR-5 lives or dies on), **PR-2a** (the feature actually working), **PR-2c** (nine refusals, each leaving no file — the Marlin one proves the guard sits *above* Guard C's early return), **PR-5b**, and `HReview.md` **HR-28 (A)**. Rows in `PReview.md` §3.6. Then **PR-6d** (the end park's default answer must be a rename, not a behaviour change) and **PR-6a–c**, rows in `PReview.md` §3.7. A node guard harness stands in meanwhile — 32 guard cases + 18 unit checks, green on the working tree and **aborting** against `HEAD` — and it proves logic only, never output |
| 1 | **Post-verify the 14 `CR-` fixes** | The four `⬜` rows in `HReview.md`'s test register, **`CR-REG` first** — the GRBL/mm factory-default regression matters most, and it now folds into REG-MF above. `CR-1 (A)` needs `Enable Line #s` on + `Axises Homed and Trusted` off `None` and `Home at Job Start` on, a combination no configuration in the record has used. Two further posts serve `PReview.md` §3.5 |
| 2 | **Tidy-up sweep** | `HR-19`'s `M291` doubled space; **HR-21 / CR-15** (wire the dead `Tool Change Probe` property into `probeTool()` — Tool Change branch work — or delete it); **HR-24** (`writeWCS()` should read `section.getTool()`, not the global `tool`). All one-liners, none changing output |
| 3 | **Dialog-only checks** | **D1** and **D3**'s dialog half (`PReview.md` §3.3). The properties literal is now declared in display order, so if the dialog *still* shows groups out of numeric order, Fusion is not sorting and the zero-padding convention is wrong |
| 4 | **Open the Tool Change branch** | `PReview.md` §2 — the ordering design and **HR-7/8/9/10/13**, as one unit, **now plus PR-4**: the `G53` park branch is sanctioned and lands here, with the two decided branches unchanged. Design settled for the ordering half; HR-10 and HR-13 have complete diffs and can go first as warm-up commits |
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
  reserved base + establish + Guards A/B/C. **Two of these were reworked on `machine-frame-design` and are
  verified only up to that point** — MCS homing (the enum is gone) and Guard B (relaxed).
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
