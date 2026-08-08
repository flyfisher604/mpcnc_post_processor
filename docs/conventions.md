# Conventions — the rules a change must follow

The **durable** half of the project record for `MPCNC_v4.0_Beta2.cps`: the conventions a change must
follow, and the method by which anything is verified. It changes a few times a year, not every session —
if you are editing it often, something live has leaked in, or design rationale has. That belongs in
`design.md`.

Which file owns what is the *Document contracts* table below. It is the only copy.

---

## Document contracts

Each file has a fixed job. `docs/check-docs.js` enforces the numbers and the tallies — see *Tooling that
ships with the repo*.

| File | May contain | Must **not** contain | Size guide |
|---|---|---|---|
| `CLAUDE.md` | Imperatives that change how a session works: read order, show-a-diff, `node --check`, the register rule, commit convention, what to leave alone | Rationale, history, design, anything that fires only once you are deep in one function | **≤ 60 lines** — it loads in full every session |
| `plan.md` | The checkpoint (baseline, what is true now, **what is left in order**, live risks), phase status, pointers to completed reviews | Design write-ups, findings, test rows, resolved decisions, open questions, backlog detail | **≤ 120 lines** |
| `conventions.md` | The rules a change must follow — property & dialog conventions, guards, how to run a test, tooling, the harness method — plus these contracts | **Design rationale** (→ `design.md`), status of anything, what is next, unbuilt design | **≤ 300 lines** — an overrun means something live has leaked in, or design has. Do not raise it |
| `design.md` | Why the shipped behaviour is what it is: the frame model, external firmware facts, the arguments behind orderings that look arbitrary in the source | Rules a session must follow, status of anything, unbuilt design (→ `PReview.md` §6) | **≤ 300 lines** — the one file that **grows with the post**, so this is the one budget expected to move. It moves by argument, in a commit of its own |
| `HReview.md` | Hobbyist findings register (`HR-`, `CR-`) + the test register. Open **questions** ride in the row of the finding they belong to | Professional findings or rows, design write-ups, durable conventions | **≤ 110 lines + 2 per finding + 9 per register row** — **derived, not fixed:** a register is meant to grow as findings are filed and rows are posted, so the allowance grows with them. What the per-item terms still catch is prose |
| `PReview.md` | Professional findings, professional test rows, **unbuilt design and its open questions** (§6), the jet/laser workstream | Hobbyist-only findings, durable conventions | **≤ 920 lines, and falling.** §2's long form and §3's expansions are unbuilt design and unrun rows; both retire on build. The §3 index table is permanent, everything under it is not |
| **the user-facing guides** — `README.md`, `docs/guide-hobbyist.md`, `docs/guide-pro.md`, `docs/property-reference.md` | Usage only, split by **reading path**: README is the landing page and the fork between guides; each guide is one path end to end; the reference holds the property tables and carries the `doc-sync` marker recording the ref it last synced to | Anything developer-facing. And **a second copy of the property tables** — one copy, linked from both guides, is the whole point of the split | — |
| per-user **memory** (outside the repo) | Constraints about the user that hold across projects and cannot be derived from this repo — e.g. no controller hardware is available | **Anything about this post**: its code, conventions, status, findings or history | One short file per fact. Nothing here is reviewed in a diff, which is why so little belongs |

### What earns a place

**First test, for every file here: can the code state it?** If yes, the code owns it — a property enum, a
function signature, a step summary is one edit away from being a lie. What belongs is what reading the post
**cannot** answer: an **external fact** (what Marlin, GRBL, RRF or Fusion does), a **rejected
alternative**, a **silent consequence** — an *absence* of output never explains itself — or the **why**
behind an ordering that looks arbitrary in code. A derivable fact stays only where it is a **premise some
non-derivable argument needs**.

**Second test, for `design.md`.** The code can never state *why*, so every design rationale passes the
first test and the post holds several hundred. A design fact needs a second warrant — it is either **the
model** (the shared vocabulary the rest is unreadable without: what a WCS, the fixed Z reference and a
transit *are*) or **a trap** (someone reached the wrong answer, or the wrong answer fails **silently**, and
the section names its evidence: a finding id, a *Rejected*, a *Superseded*). A choice that is merely *true*
is neither. **This is a gate, not a home: there is deliberately nowhere to put the other several hundred**,
and **nothing mechanical defends it** — no checker reads the post to see whether a claim here still holds.

### Four rules that keep it that way

1. **A new top-level section in *any* of these files requires changing its contract here first.** If the
   content does not fit a section the file already has, the question is *which file owns this*, not *can
   this one hold it*. A review document's sections are fixed — see *The shape of a review document*.
2. **Over the size guide means something has stopped being live.** Check what has quietly become durable
   (→ `conventions.md` or `design.md`) or register-shaped (→ a register) rather than trimming prose.
   **A register's guide is derived, so this still holds there.** Filing a finding or passing a row raises
   the allowance by its own cost; going over anyway means the *prose* grew, not the register. A fixed
   ceiling on `HReview.md` was hit three times in one session and every time the trigger was a test
   passing — which is the document working, so the number moved instead of the content.
3. **Never point two ways.** If file A says "written up in B", B must hold the write-up and must not point
   back. A pointer is valid in one direction only: from status toward the register that owns the work.
   (`plan.md` and `PReview.md` §6 once pointed at each other for four items, and neither held the content.)
4. **Every accumulating section states what empties it** — *Invalidated by …* empties as its rows are
   re-posted, *Checked and found correct* as `posted` rows supersede its `read`-strength ones. The
   exception is a findings **row**, which is permanent: commit messages and code comments cite the id and
   it must still resolve. What retires on closure is the prose — the Resolution collapses to the commit ref
   plus one clause.

### The shape of a review document

`HReview.md` and `PReview.md` are the two that exist; a third review pass gets the same shape. It is fixed
because the two once diverged, and `check-docs.js`, matching HReview's headings only, left the larger
register ungated. Sections are matched **by name, not by number** — `PReview.md` numbers its sections and
`HReview.md` does not.

| § | Section | Holds | Required? |
|---|---|---|---|
| 1 | **Scope** | Which persona and which controls this review covers, and what it deliberately excludes | yes |
| 2 | **Findings** | The register **table**: `ID · Finding · Sev · Resolution · Status`. One row per finding, forever — commit messages cite the ids | yes |
| 3 | **Test register** | The register **index table**: `Test · Proves · Setup · Method · State`, one row per id | yes |
| 4 | **Invalidated by …** | Rows whose saved `.gcode` a change broke. Retires per Rule 4 | when non-empty |
| 5 | **Checked and found correct** | `read`-strength readings. Retires per Rule 4 when a `posted` row supersedes | when non-empty |
| 6 | **Owed** | What the register itself owes: which artifacts, and why each is worth a post. **Not** the order of work — that is the checkpoint's | yes |
| 7 | **Design backlog** | Unbuilt design and its open questions. **Only** where the file's contract admits unbuilt design — `PReview.md` does, `HReview.md` does not | optional |

**An *Expect* is pre-run only. A passed row carries a result.** The *Expect* says what to look for; the
moment every row under that id is `✅` it has done its job and **must collapse to what the artifact showed**
— `— PASS`, the file, the discriminator actually checked, and any trap a re-run would otherwise walk back
into. Nothing else: not the prediction, not the reasoning that produced it, not the build it dates once the
register dates the build once. `check-docs.js` **FAILs** on a `✅` id whose *Expect* has no `— PASS`, and on
a result recorded against rows that are not all `✅`. It is a FAIL and not a WARN because a stale *Expect*
is wrong in the worst direction — it reads as a criterion still to be met. Four in `HReview.md` predicted
tokens their own passing file did not contain, and one would have read as a **false FAIL** on a re-run.

**The fields are canonical; the rendering is not.** A test row carries an id, a state marker, a setup
delta, a method, and an *Expect* naming its discriminator; where the *Expect* needs a g-code block a
markdown cell cannot hold, that block goes in an expansion directly beneath **in the same section**. What
Rule 3 forbids is the *Expect* existing in two places. Three mechanical rules the checker depends on:
**the state marker is the *last* column** of every register table; **every register states its tally above
its table** (`✅ n · ❌ n · ⬜ n · ➖ n — n rows`, and `— n findings` for a findings table); and **every
findings id resolves to a test row**, with a `➖` pointer row where another row's matrix proves it.

**Which register?** Hobbyist is *a Personal-licence user, one part, one WCS, one tool, several operations*.
Professional is multi-WCS, spoilboard base, tool changes, Manual NC, and the dialog audit. An unscheduled
idea goes to `PReview.md` §6 **unless a hobbyist needs it for correct operation** — a nice-to-have is not
a hobbyist item just because a hobbyist could use it.

---

## Context and stance

The post targets the V1 Engineering **MPCNC / LowRider** family and similar GRBL / Marlin / RepRap
hobby-class machines. The aim is **production-quality CNC workflows** (multi-fixture, multi-tool, probing,
safe cross-part traverses) that **also degrade simply** for a hobby user on the Fusion Personal licence
cutting a single operation. Both are first-class.

**Settle the CNC-correct workflow first, then design the software that delivers it.** Two principles drive
every decision:

- **Work-relative.** Most target machines have no reliable machine-Z (no tool setter, often no Z endstop).
  The everyday reference is the active **WCS**, never the machine frame. Tool length is folded into a **Z
  re-probe after each tool change** (there is no TLO). Homing, where present, gives **X/Y** repeatability
  only.
- **Graceful degradation.** Every advanced feature (reserved base, cross-part safe-Z, per-part probing,
  jog prompts) is opt-in and emits nothing until enabled. The *shape* is the guarantee; the older
  byte-identical-default-output guarantee is gone (broken by the property dump, **HR-1** and CR-6), so
  **treat a future default-output change as a decision to be argued, not a line that cannot be crossed.**

---

## References — Fusion 360 post-processor documentation

- **PostProcessor API class reference** — <https://cam.autodesk.com/posts/reference/classPostProcessor.html>
- **Post Processor Training Guide (PDF)** — <https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf>
- **Dumper post** — emits every property/parameter/section value Fusion exposes; run it before relying on
  anything: <https://cam.autodesk.com/hsmposts?p=dump>
- **Library of existing posts** — <https://cam.autodesk.com/hsmposts> · **Forum** —
  <https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218>

Firmware: Marlin <https://marlinfw.org/meta/gcode/> · GRBL 1.1 <https://github.com/gnea/grbl/wiki> ·
FluidNC <http://wiki.fluidnc.com/> · Duet/RRF <https://docs.duet3d.com/User_manual/Reference/Gcodes>

---

## Validation guards — a rejected job can still leave a file

**The trap:** *where* a guard runs decides what a rejected job leaves on disk. A guard in `onOpen()`
refuses before any output, so the job writes **no file at all**. The two *geometry* guards — multi-axis,
and HR-6's orientation check — fire later, in `onSection()`, so a rejected job leaves a **truncated
`.gcode`**: a partial file an operator may not notice, rather than a clean refusal. That is a defect and
it is open — `HReview.md` **HR-27**.

Guards are **post-time only**; the post cannot read the live controller, so none of them protects against
machine state. Each is named and explained at its own site in `validateJob()`, so the code is the list —
deliberately not copied here, where it would go wrong the first time a guard is added.

## Property / dialog conventions

- This post uses the **combined-inline** `properties = {}` form, read with `getProperty(properties.key)`
  (an object reference, correct for this form). The split `properties` + `propertyDefinitions` form is the
  *old broken* approach — do not reintroduce it.
  > **Why this keeps coming up.** The split form is what the predecessor `MPCNC.cps` used until a Fusion
  > change broke it — the reason v3 exists. Forum threads calling `propertyDefinitions` a "May 2021
  > enhancement" describe that **old** approach, not a newer target, and 403 to automated fetching.
  > Closed as-designed already, as compliance finding F10.
- **What resets a saved preset:** the **key** is the stored identifier, so renaming a key resets that
  property to its default, as does changing an enum **`id`** or a boolean→enum conversion. Changing only a
  `group:` string, a title, an option title, `order:`, or the declaration *order* does **not**. Every reset
  is a release-notes item.

**Origin/probe controls.** Three separate controls, not one: **First WCS / Part**; **Subsequent WCS /
Part**, which fires on a genuine WCS change after the first section and offers the same modes minus the
two *Current Pos* ones; and **Probe Pause**, which gates the attach/detach prompts for the **part** probes
only and adds no new stops.

- Merging the two origin controls was **rejected**: it would apply job-start XY-zeroing to a mid-job WCS
  change.
- Both dropdowns are ordered default-first, and both defaults are **no-prompt** modes because jogging at a
  pause isn't universally supported.
- The *Current Pos* modes assume a pre-jog; the *Use Active WCS* modes trust the stored fixture offset;
  the *Jog* modes pause (M0).
  > **"Use Active WCS", not "Use Existing WCS".** "Existing" read as a *temporal* claim — the WCS active
  > before the job — which is wrong: the register is the one this Setup designates, and the post *selects*
  > it at job start.

**Two controls were both titled "Safe Z".** The cross-part one is now **"Inter Part Travel Z"** (signed
mm, frame set by `Fixed Z Reference`); the post-probe retract keeps **"Safe Z"**. It absorbed the former
**"Travel Machine Z"** as well — see `design.md` → *The fixed Z reference*.

---

## Reference — per-machine settings

Group 4 is `Axes Homed and Trusted` (the declaration) + `Home at Job Start` (the action, including its
optional pause) + `At End Park At`; group 5 is `Fixed Z Reference` and the one clearance it gives a frame
to. The park sits in group 4 rather than group 1 because what it *addresses* is the machine frame and it
is guarded on the declaration — the same reason the action lives there, and the reason its key is
`machineParkAtEnd`.

| Machine / firmware | Axes Homed and Trusted | Home at Job Start | Fixed Z Reference (multi-fixture) | Operator does |
|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | `XYZ` if Z endstops fitted, else `XY Only` | `Home` | `Machine Z` where Z is declared, else `Spoilboard` `G59` | homes X/Y; work-Z touched off with the plate either way |
| MPCNC + FluidNC, X/Y switches | `XY Only` | `Home` | `Spoilboard` `G59` | homes X/Y; machine Z n/a, Z set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | `XYZ` | `Pause, then Home` | `Spoilboard` `G59` — `G53` is a Marlin build option | homes X/Y; at the pause places the movable plate, then Z homes to it |
| MPCNC, no switches | `None` | `Off` | `Spoilboard` `G59` | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | `None` | one WCS zeroed to the part; no fixed reference needed |

> **Two interactions the rows do not show.** (1) `HReview.md` CR-2 — any row whose `Home at Job Start` is not `Off`
> must **not** use a `Set … to Current Pos` origin mode: homing moves the tool and the origin would be
> recorded at the endstop corner. On a homed machine `Use Active WCS X0 Y0, Probe Z0` is the natural
> answer instead, which is what the warning now says. (2) A stored work offset is repeatable only against
> a homed machine zero, so the two `Use Active WCS …` modes warn when the declaration does not include X/Y — and
> deliberately do **not** warn on the `Jog to …` modes, where every origin is created during that run.

---

## How to run a test

- **Post the job from Fusion and read the g-code.** Machine dry-runs and physical measurement are out of
  scope — every row must stand on the posted file alone.
- **Read the posted file's own property dump.** It records the whole dialog
  state.
- Output goes to `C:\Users\don_m\Documents\Fusion 360\NC Programs\`, **is not in the repo**, and a reused
  filename destroys evidence. **Name a post for the row it serves** (`HR12a`), not for what the job does.
- Defaults unless stated: GRBL/mm, Comment Level `Info`, probe target/speed/thickness `Z-10`/`F30`/`Z0.8`.

**Method**, strongest first: **`posted`** a real file from the real post — the only method that proves what is generated.


---

## Tooling that ships with the repo

| Artifact | Fired by | Checks | Travels? |
|---|---|---|---|
| `docs/check-docs.js` | the pre-commit hook, or by hand | The contracts above: size budgets (warn, **derived where the guide says so**), tallies vs their tables, findings-vs-register id completeness, heading ranges and row counts, **that every `✅` id's *Expect* is a result and no unrun id's is** (fail), Rule 3's pointer direction, the `doc-sync` ref on `property-reference.md`. Prints which registers it actually parsed — a checker silent about what it skipped reads as a clean bill of health. **Documents only:** it never reads the `.cps`, and two checks that did have been removed for it | ✅ tracked |
| `.githooks/pre-commit` | `git commit` — **anyone's**, not just a session's | runs `check-docs.js --staged`; non-zero aborts the commit | ✅ tracked, ❌ **not armed** — see below |
| `.claude/hooks/post-edit.js` | Claude Code, after every `Edit`/`Write` | `node --check` when the file is the `.cps`; silent for everything else | ✅ tracked |

Run the doc check by hand with `node docs/check-docs.js` (working tree) or `--staged` (what a commit
would record). It is deliberately quiet: `WARN` never fails a commit, only `FAIL` does.

**Once per commit, not once per edit.** Every check here grades a *finished* document. Mid-edit the
answers are noise or actively wrong: a size WARN reports prose still being written, and the tally and
*Expect* checks fire on a table whose row lands in one edit and its count in the next. Nor does a
working-tree run predict the gate — that reads the **index**, so only `--staged`, after staging, answers
the question that matters. `/checkpoint` runs it once at session start; otherwise a run that is not
about to become a commit is spending the session's context to grade an unfinished file.

**A fresh clone must run this once — nothing else installs it:**

```
git config core.hooksPath .githooks
```

`core.hooksPath` lives in `.git/config`, which is **never cloned**, so the tracked `.githooks/pre-commit`
arrives present but inert. `post-edit.js` — which *does* self-arm, through the tracked
`.claude/settings.json` — checks for the setting when the `.cps` is edited and prints the command if it
is missing. That is the only reason the omission cannot go unnoticed. Claude Code asking for approval the
first time a project's `settings.json` hooks block is seen or changes is by design, not a fault.

**Why the split.** Syntax is meaningful at *every* edit, so `node --check` runs then; deferring it to
commit lets further edits stack on a broken file. Document contracts are meaningful only once a change is
settled — the register is updated before the commit lands, not after every intermediate edit — so
checking them per-edit would fight that rule.

## Working method — harness and tooling

- **`node --check MPCNC_v4.0_Beta2.cps` is a valid syntax gate** — run it after every edit.
- **Individual functions can be brace-matched out of the `.cps` and `eval`'d in node against stubbed kernel
  globals.** `propertyMmToUnit`, `getProperty`, `getCircularPlane`, `hasParameter`, `cycleType`, `unit`,
  `Vector` and a fake section are all easy to fake. Not a substitute for posting, but it settles
  arithmetic cheaply.
- **Bind extracted functions as *expressions*** — `eval('(' + src + ')')`. A bare declaration (or a
  `const`/`let`) inside `eval()` does not leak to the caller's scope under `'use strict'`.
- **Run every harness against `HEAD` as well as the working tree** (`git show HEAD:MPCNC_v4.0_Beta2.cps` to
  a temp file, taking the path as `argv[2]`). A harness that only passes on the fixed file cannot tell you
  it would have caught anything — HR-14 went 7/9 → 9/9 that way.
- **Make a harness abort rather than report when its extraction yields nothing.** The 2026-08-01 sweep
  harness over-ran its terminator, left the properties object **empty**, and reported eight vacuous passes.
- **A pure reorder can be proved safe by matching sorted-line checksums** against `HEAD` — how CR-14's
  properties move was shown to change no character of any key, title or default.
- **`git commit -m` with a PowerShell here-string mangles messages containing double quotes** — write the
  message to a file and use `git commit -F`.

## Working method — lessons that keep paying off

- **A guard written to fail open produces a byte-identical file whether it read the value correctly or
  read nothing at all.** Make its diagnostic **unconditional**, not rejection-only (HR-6).
- **Absence-based rows need a presence-based sibling posted from the same build** (HR-11 (A)/(B)).
- **When a code path cannot be reached, question the premise before blaming the CAM.** HW-1 cost three
  posted files. But state the conclusion exactly: `isSafeToRapid()` **is called** on a paid licence — what
  a paid licence does not reach is a *conversion*, and only while the threshold is left at its default.
  "Unreachable" was the loose paraphrase, and two user-facing claims were built on it (HR-39).
- **When a defect suppresses output it makes its own behaviour unverifiable — switch to the branch that
  emits.** HW-2 (B) was unanswerable on the manual path and trivial on the automatic one.
- **`Personal.cps`** (repo root, git-excluded) is the post with `onRapid()` rerouted into `onLinear()` —
  the only way to reach the group-03 code, since a paid licence emits real `G0`s. Re-create it from the
  current `.cps`; its evidence is about *logic*, never about what the post emits.
- **Every fix so far deviated from its proposed diff the same way: the proposal understated the number of
  call sites.** Count them in the code before believing a diff is complete, and cover every branch — a
  missing `flushMotions()` before job end was once patched only in the no-custom-file branch, leaving the
  `else { loadFile(...) }` branch, which injects motion from a user's footer file, still broken.
- **Write every Pass criterion as something visible in the file** — exact tokens, their order, and what
  must be **absent**. When a row passes, mark it `PASS` outright: no "static PASS" hedging and no note
  explaining what was skipped. Operator-safety facts a file cannot show (*park the tool over bare
  spoilboard before starting*) belong in code comments, here, and the user guides — never as a test step.
