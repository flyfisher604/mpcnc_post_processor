# plan.md — live state: what is done, what is next, what is open

**The volatile file.** Read it at the start of every session, and nowhere else for status. It holds three
things and no others: the **checkpoint** (including what is left, in order), **phase status**, and pointers
to the **completed reviews**. Design write-ups, findings, test rows, resolved decisions and open questions
all belong in a register — `conventions.md` → *Document contracts* says which file owns what, and is the
thing to change first if you think something new belongs here.

---

## Checkpoint — restart here

*Written so a fresh session can resume with no other context. Update it when the situation moves.*

**Baseline.** **`master`**, now carrying the `design.md` split. Four working branches have closed the same
way — `PropertyUpdate` → `machine-frame-design` → `Goto-0,0` for the machine-frame rework, then
`control-review` for the doc split: each a linear chain, so `master` fast-forwarded onto the tip and the
label was deleted; every commit is retained and no merge commit was made. **`master` is 16 commits ahead
of `origin/master` and nothing has been pushed.** Work continues on **`hobby-dialog-review`**.

**What the machine-frame range landed.** The property rework (`groupDefinitions`, explicit `order:`, the
`<groupKey><Name>` key rename), then the machine frame and the fixed Z reference — `PReview.md`
**PR-1 · PR-2 · PR-3 · PR-5** and `HReview.md` **HR-28** — then **PR-6 · PR-7**: `At End Go to 0,0`
never said *which* X0 Y0 and it was the last section's WCS, so it is now `At End Park At` = `Off` /
`Work X0 Y0` / `Machine X0 Y0`, the machine answer being `G53 G0 X0 Y0` on GRBL/RepRap and `G28 X Y`
on Marlin; and `Prompt Before Home` folded into `Home at Job Start` = `Off` / `Home` / `Pause, then
Home` — **the first merge that deletes a state rather than renaming one**, the prompt having been
inert whenever homing was off — with the park moved to group 4 as `machineParkAtEnd`. Group 4 now
reads declaration / action / park. A pre-post review of the whole range then found four defects in
PR-2 / PR-6's own code and fixed them: **PR-8 … PR-11**.

Together these are **the first changes since `c73726c` to alter what the post emits.** Nothing is
half-done; **nothing is posted.** Untracked and deliberate: both `MPCNC_v4.0_Beta*.zip`, and
`Personal.cps` (a test harness, excluded via `.git/info/exclude` — see `conventions.md`).

**What that rework did** is `design.md` → *The machine frame* and *The fixed Z reference*, which hold the
model, the rejected alternatives and the enum-flip hazard in full. The one status fact: it **resolves the
standing "Never `G53`" decision** — the post now addresses the machine frame on exactly the axes the
operator declares.

**Two things it deliberately did not do.** The **`G53` tool-change park** is `PReview.md` **PR-4** — it
shares code with §2's Phase 4 reorder and must compose with that design, not pre-empt it. And it left
`PReview.md` over its size budget, where a Rule-2 pass found nothing *live* had leaked in: the growth is
unbuilt design and unrun rows, which retire on build. `check-docs.js` prints every current doc-size
number, so none is repeated here.

**What `hobby-dialog-review` landed (2026-08-07).** A hobbyist-perspective walk of all **69** dialog
properties — `HReview.md` **HR-29 … HR-38**. Seven output-neutral: the `Axises` title, seven description
typos, eleven descriptions rewritten to lead with *what to set and can I skip this* (the seven essays were
re-deriving `design.md`; four stubs said nothing), group titles 4 and 5 now naming who needs them, and
group 8 finally stating that a Start/Stop file **replaces** its phase while the tool files **add**.
**Two defaults moved, and only two:** `Scale Feedrate` → on, because the three axis limits it gates were
silently inert; and the coolant codes → the GRBL dialect, matching the default firmware, where Marlin
`M42` writes had been posting into GRBL files unchecked. **Group 3's defaults stay off deliberately** — a
licence workaround is the operator's choice, not the post's — as do the touch-plate-assuming probe default
and the tool-change default; all three are argued rows rather than silent non-decisions. The 737-line
README split into a landing page plus `docs/guide-hobbyist.md` / `guide-pro.md` / `property-reference.md`,
the last carrying the `doc-sync` marker, now re-bumped to `17a20f2`. **The property count was wrong in
three places and is 69 = 8/7/4/3/5/10/8/5/7/10/2**, which two unrun rows (D3, D5) had been asserting
wrongly. `conventions.md` traded its README contract row for one covering all four guides, still 298/300.

**What the HB- pass landed (2026-08-08).** Six of `HReview.md`'s ten `HB-` findings, one commit each and
each row closed with its code — **HB-2** (the GRBL `%` wrapper dropped), **HB-3** (a `validateJob()`
warning when `Home at Job Start` can home nothing, plus the ten stale `Axises` HR-29's rename left),
**HB-4** (retract before the offset probe traverse, gated on the offset), **HB-7** (include filenames
checked before any output; `HR-27`'s geometry half stays open), **HB-8** (`fOutput` and the word
separator assigned on both branches) and **HB-9** (all thirteen `>>> WARNING:` sites bypass
`Comment Level`). **Three change the emitted file** — the `%` lines, HB-4's lift, warnings at `Off` — so
all eleven live `HB-` rows are still `⬜`, `HB-9 (A)` being the register's first `Off` post. **Open
deliberately: HB-5 · HB-6** (outside the request) and **HB-10** (item 4). **`PReview.md` and the
`HR-`/`CR-` register are absent from this branch's working tree**, which is why plan.md is over budget:
the two paragraphs above are the only surviving summary of what those registers hold.

**Where the record lives.** The hobbyist review (`HR-1`…`HR-39`) and the 2026-08-01 whole-file review
(`CR-1`…`CR-17`) are one register in `HReview.md`: **49 findings**, all fixed or closed by design, except
three one-liners and **HR-27**, unstarted. **The seven professional ids — `HR-7`…`HR-10`, `HR-13`,
`HR-20`, `HR-26` — are in `PReview.md` and nowhere else** (2026-08-07: `HReview.md` had been carrying stub
rows for all seven, a second place for the same finding to go stale). **Neither pass found the factory-default
single-operation job broken** — every High/Medium finding needed one dialog field moved off its default.
Test rows are in `HReview.md`'s test register (hobbyist) and `PReview.md` §3 (professional); nothing else
records a pass, and the Method column matters as much as the state (`conventions.md` → *How to run a test*).

**What is left, in order.**

| | Item | Note |
|---|---|---|
| 0 | **Post-verify the machine-frame rework and the end park** | It is unposted, and it changed the dialog and the emitted file. **`PReview.md` REG-MF first** — the GRBL/mm factory-default diff. **`hobby-dialog-review` re-baselined it:** “factory default” now means `Scale Feedrate` on, so the expected diff is the property dump, the Resolved-Values block **and every `F` word**, and nothing else. **The hobbyist half of that post is already run** (2026-08-08, `HR-33 (A).gcode`): `HReview.md` **HR-33 (A)**, **HR-34 (B)** and **HR-36** are ✅ — feedrates land on `F900`/`F180` by default, matching `HW5` line for line, and no coolant code is reached. **REG-MF itself is still owed**, because that post was diffed against `HW5` rather than a re-post of the pre-change build, and `HW5` is neither factory-default (it carries `Probe Pause` = `Before`) nor pre-machine-frame. The same file already shows REG-MF's Resolved-Values half and **PR-6d**'s motion half holding — `X0 Y0 F2500` still, under the new `machineParkAtEnd = Work` name — but neither can be marked without the right baseline. Then **PR-5a** (the enum flip — the one hazard consolidation created, and the row PR-5 lives or dies on), **PR-2a** (the feature actually working), **PR-2c** (nine refusals, each leaving no file — the Marlin one proves the guard sits *above* Guard C's early return), **PR-5b**, and `HReview.md` **HR-28 (A)**. Rows in `PReview.md` §3.6. Then **PR-6d** (the end park's default answer must be a rename, not a behaviour change), **PR-6a–c** and **PR-7a–b**, rows in `PReview.md` §3.7. A node guard harness stands in meanwhile — 38 guard cases + 24 unit checks, green on the working tree and **aborting** against `HEAD` — and it proves logic only, never output. **A pre-post review of the branch then found four defects in PR-2 / PR-6's own landed code — `PReview.md` PR-8 … PR-11, all fixed** — so **PR-10 runs with the §3.6 block** (it fires on the *default* first-part mode) and **PR-8a/b · PR-9 · PR-11 with §3.7** |
| 1 | **Post-verify the 14 `CR-` fixes** | The four `⬜` rows in `HReview.md`'s test register, **`CR-REG` first** — the GRBL/mm factory-default regression matters most, and it now folds into REG-MF above. `CR-1 (A)` needs `Enable Line #s` on + `Axes Homed and Trusted` off `None` and `Home at Job Start` on, a combination no configuration in the record has used. Two further posts serve `PReview.md` §3.5 |
| 2 | **Tidy-up sweep** | `HR-19`'s `M291` doubled space; **HR-21 / CR-15** (wire the dead `Tool Change Probe` property into `probeTool()` — Tool Change branch work — or delete it); **HR-24** (`writeWCS()` should read `section.getTool()`, not the global `tool`). All one-liners, none changing output |
| 3 | **Dialog-only checks** | **D1** and **D3**'s dialog half (`PReview.md` §3.3). The properties literal is now declared in display order, so if the dialog *still* shows groups out of numeric order, Fusion is not sorting and the zero-padding convention is wrong |
| 4 | **Open the Tool Change branch** | `PReview.md` §2 — the ordering design and **HR-7/8/9/10/13**, as one unit, **now plus PR-4**: the `G53` park branch is sanctioned and lands here, with the two decided branches unchanged. Design settled for the ordering half; HR-10 and HR-13 have complete diffs and can go first as warm-up commits |
| 5 | **The professional review proper** | The pass that produces `PReview.md`'s real content. Needs a multi-part / multi-fixture job to post against |
| 6 | **Jet / laser workstream** | `PReview.md` §5. **J4 is the priority** — group 09 has never appeared in *any* posted file, and CR-10 landed a fix there sight-unseen. The `CR-10 (A)` row is that post. J5 is a design question before it is a test |

**The one live risk that could still hide a real defect: `HR-6 (B)`** — the orientation guard may be a
no-op on exactly the case it exists to catch, and the failure mode is a part cut in the wrong plane,
silently. It needs a rotated Setup. Written up in `HReview.md` → *Owed*.

**No controller access**, so firmware questions are settled from source — `conventions.md` →
*How to run a test*, and `design.md` → *Firmware capabilities*.

---

## Phase status

- **Phases 1–3 — done & verified.** WCS origin/probe rework to `G10 L20`; `writeWcsOrigin()`; MCS homing;
  reserved base + establish + Guards A/B/C. **Two of these were reworked by the machine-frame range and
  are verified only up to `c73726c`** — MCS homing (the enum is gone) and Guard B (relaxed).
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
