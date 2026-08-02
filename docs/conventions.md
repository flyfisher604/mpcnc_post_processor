# Conventions — the models, the rules, and the method

The **durable** half of the project record for `MPCNC_v4.0_Beta2.cps`: the models the code assumes, the
conventions a change must follow, and the method by which anything is verified. It changes a few times a
year, not every session — if you are editing it often, something live has leaked in.

Which file owns what is the *Document contracts* table immediately below — it is the only copy.

---

## Document contracts

Each file has a fixed job. The set has been reorganised twice because content drifted into whichever file
happened to be open — a design write-up in the status file, a working rule in per-user memory, a finding
restated in four places. These contracts are what stop that recurring.

| File | May contain | Must **not** contain | Size guide |
|---|---|---|---|
| `CLAUDE.md` | Imperatives that change how a session works: read order, show-a-diff, `node --check`, the register rule, commit convention, what to leave alone | Rationale, history, design, anything that fires only once you are deep in one function | **≤ 60 lines** — it loads in full every session |
| `plan.md` | The checkpoint (baseline, what is true now, **what is left in order**, live risks), phase status, pointers to completed reviews | Design write-ups, findings, test rows, resolved decisions, open questions, backlog detail | **≤ 120 lines** |
| `conventions.md` | The durable half — despite the name, **conventions are the smallest part of it**. Three things: **the model** (coordinate model, base/frame, stance), **the conventions** (property & dialog rules, the one genuinely prescriptive part), and **the method** (how to run a test, harness, tooling). Plus external firmware facts and these contracts | Status of anything, what is next, unbuilt design | **≤ 520 lines** — it changes a few times a year; an overrun means something live has leaked in. It is also the file the volatile ones drain *into*, so it absorbs before it trims. **This number moved twice on 2026-08-02** (420 → 450 → 520) as the tooling section and the review-document skeleton landed; it should not move again without something genuinely new, not merely longer |
| `HReview.md` | Hobbyist findings register (`HR-`, `CR-`) + the test register. Open **questions** ride in the row of the finding they belong to | Professional findings or rows, design write-ups, durable conventions | **≤ 300 lines** — a register grows one line per row |
| `PReview.md` | Professional findings, professional test rows, **unbuilt design and its open questions** (§6), the jet/laser workstream | Hobbyist-only findings, durable conventions | **≤ 920 lines, and falling** — §2's long form and §3's expansions are unbuilt design and unrun rows, and **both retire on build**. The §3 index table is permanent; everything under it is not. This file must shrink, not grow |
| `README.md` | User-facing usage only. Its `doc-sync` marker records the ref it last synced to | Anything developer-facing | — |
| per-user **memory** (outside the repo) | Constraints about the user that hold across projects and cannot be derived from this repo — e.g. no controller hardware is available | **Anything about this post**: its code, conventions, status, findings or history | One short file per fact. Nothing here is reviewed in a diff, which is why so little belongs |

`docs/check-docs.js` enforces the numbers above — see *Tooling that ships with the repo*.

**What earns a place in this file: can the code state it?** If yes, the code owns it — a property enum,
a function signature, a step summary is one edit away from being a lie, and deleting it loses nothing
because the `.cps` says it. What belongs here is what reading the post **cannot** answer:

- an **external fact** — what Marlin, GRBL, RRF or Fusion does;
- a **rejected alternative** — the code cannot contain what was decided against;
- a **silent consequence** — an *absence* of output never explains itself;
- the **why** behind an ordering that looks arbitrary in code.

**The exception that matters:** a derivable fact stays when it is a **premise the surrounding argument
needs**. That `onOpen()` sets `currentWorkOffset = undefined` is readable from the code, but the
*selection is deterministic, origin is trusted* argument collapses without it. Cut conclusions the code
already states; keep the steps that make a non-derivable argument stand up.

**That test alone is not enough for design content.** The code can never state *why*, so every design
rationale passes it, and the post contains several hundred design choices. A design fact needs a second
warrant — it is either **the model** or **a trap**:

- **The model** — the shared vocabulary the rest of this file is unreadable without: what a WCS, the
  base frame and a transit *are*. *Coordinate model* is that section, and it does not grow.
- **A trap** — someone reached the wrong answer, or the wrong answer would fail **silently**. Every trap
  here names its evidence: a finding id, a *Rejected*, or a *Superseded*. If a section cannot name one,
  that is the signal it has stopped earning its place.

A design choice that is merely *true* is neither, and stays in the code. **This is a gate, not a home:
there is deliberately nowhere to put the other several hundred**, and adding such a place would only
invite filling it.

Together these answer *"why these facts and not the hundreds of others?"* — the rest are undocumented
because reading the code answers them. `check-docs.js` warns when a symbol named here no longer exists,
but nothing can check whether a *claim* is still true; that is what these tests are for.

**Four rules that keep it that way.**

1. **A new top-level section in *any* of these files requires changing its contract here first** —
   `plan.md`, a review document, or **this file**. If the content does not fit a section the file already
   has, the question is *which file owns this*, not *can this one hold it*. For a review document the
   sections are fixed — see *The shape of a review document* below. For this file there is no fixed list,
   because it is heterogeneous by design; the gate is the admission test above.
2. **Over the size guide means something has stopped being live.** Check what has quietly become durable
   (→ here) or register-shaped (→ a register) rather than trimming prose.
3. **Never point two ways.** If file A says "written up in B", B must hold the write-up and must not point
   back. `plan.md` and `PReview.md` §6 pointed at each other for four items, and neither held the content.
   A pointer is only valid in one direction: from status toward the register that owns the work.
4. **Every accumulating section states what empties it.** A section that only ever gains rows will
   outgrow its file, and "we'll tidy it later" has never once been the thing that happened. Three exist
   today and these are their clauses:
   - `HReview.md` → *Invalidated by the … code-review fixes* — delete a row when its test is re-posted;
     delete the **section** when it empties. It expires with the `⬜` rows it was written for.
   - *Checked and found correct* in either register — delete a row
     when a `posted` row supersedes it. Both are `read`-strength, and `posted` is strictly stronger.
   - Findings tables — the **row** stays, always, because commit messages and code comments cite the id
     and it must still resolve. What goes is the prose: on closure the Resolution collapses to the
     commit ref plus one clause. This is the same rule as *retire the long form on close*, applied to
     the row that outlives it.

### The shape of a review document

`HReview.md` and `PReview.md` are the two that exist; a third review pass gets the same shape. Before
this was written the two had already diverged — the same content type carried a different heading and a
different *shape* in each — and the consequence was concrete: `check-docs.js` matched HReview's headings
only, so the larger register went ungated except for its size.

| § | Section | Holds | Required? |
|---|---|---|---|
| 1 | **Scope** | Which persona and which controls this review covers, and what it deliberately excludes | yes |
| 2 | **Findings** | The register **table**: `ID · Finding · Sev · Resolution · Status`. One row per finding, forever — commit messages cite the ids | yes |
| 3 | **Test register** | The register **index table**: `Test · Proves · Setup · Method · State`, one row per id | yes |
| 4 | **Invalidated by …** | Rows whose saved `.gcode` a change broke. Retires per Rule 4 | when non-empty |
| 5 | **Checked and found correct** | `read`-strength readings. Retires per Rule 4 when a `posted` row supersedes | when non-empty |
| 6 | **Owed** | What the register itself owes: which artifacts, and why each is worth a post. **Not** the order of work — that is the checkpoint's | yes |
| 7 | **Design backlog** | Unbuilt design and its open questions. **Only** where the file's contract admits unbuilt design — `PReview.md` does, `HReview.md` does not | optional |

**The fields are canonical; the rendering is not.** A test row must carry an id, a state marker, a
setup delta, a method, and an *Expect* naming its discriminator. Where the expected output fits one
line, put it in the index table as HReview does. Where it needs a multi-line g-code block — which a
markdown cell cannot hold — the index row carries id, proves, setup, method and state, and the block
lives in an expansion directly beneath **in the same section**. That is an index, not a cross-reference,
so Rule 3 does not apply; what Rule 3 forbids is the *Expect* existing in two places.

Three mechanical rules the checker depends on:

- **The state marker is the *last* column** of every register table. Put an Expansion reference before
  it, never after.
- **Every register states its tally above its table** — `✅ n · ❌ n · ⬜ n · ➖ n — n rows`, and for a
  findings table `— n findings`.
- **Every findings id resolves to a test row.** If a finding is verified by another row's matrix, leave
  a `➖` pointer row saying so, exactly as a moved finding does.

Sections are matched **by name, not by number**. `PReview.md` numbers its sections and `HReview.md` does
not; renumbering either to force the order above would break some thirty cross-references for cosmetic
gain, so the names are canonical and the numbering is local. `check-docs.js` prints which registers it
actually parsed on every run — a checker silent about what it skipped reads as a clean bill of health,
which is precisely how `PReview.md` stayed ungated while the check reported success.

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

**Development role.** Decisions are made from two expert lenses together: **post-processor engineering**
(clean JavaScript faithful to this post's idioms, careful regression discipline) and **best-practice CNC
operations** (how these machines behave, and what a safe workflow looks like for both personas). The habit
is: settle the CNC-correct workflow first, then design the software that delivers it.

Two principles drive every decision:

- **Work-relative.** Most target machines have no reliable machine-Z (no tool setter, often no Z endstop).
  The everyday reference is the active **WCS**, never the machine frame. Tool length is folded into a **Z
  re-probe after each tool change** (there is no TLO). Homing, where present, gives **X/Y** repeatability
  only.
- **Graceful degradation.** Every advanced feature (reserved base, cross-part safe-Z, per-part probing,
  jog prompts) is opt-in and emits nothing until enabled.
  > **The byte-identical guarantee is gone, deliberately.** This was originally "the default job's output
  > stays byte-for-byte unchanged". The full property dump broke it for comments, **HR-1** broke it for
  > *emitted commands*, and `HReview.md` CR-6 reordered the tail. What survives is the *shape* — advanced
  > features still emit nothing until enabled. **Treat a future default-output change as a decision to be
  > argued, not a line that cannot be crossed.**

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

## Coordinate model — *the model; every other section reads against this one*

Production controls keep three references separate: **MCS** (`G53`), **WCS** (`G54`–`G59`, `G59.1`–`G59.3`
on RepRap), and **TLO** (`G43`). Most V1E machines have none fully, hence the work-relative stance.

**There is no tool-length system at all** — no TLO, no tool setter — so a work-Z re-probe after each tool
change is the substitute, and **X/Y is never probed**.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to that WCS's own
  register. `P` maps 1:1 to Fusion's `workOffset` (P1–P6 = G54–G59; P7–P9 = G59.1–G59.3, RepRap only).
- **Marlin is single-frame:** no per-WCS registers, so one global `G92` origin. A Marlin job using more
  than one distinct work offset is a hard error (Guard C).
- **`workOffset 0`** is Fusion's "default / unset", **not** a request for `G53`; it aliases to WCS 1 /
  `G54`, and must alias identically everywhere, or two paths disagree about which frame a section is in.

**The post asserts the WCS selection; it never inherits it.** This is the justification for the ordering
in `writeFirstSection()`:

- Fusion **always** supplies a work offset per section, so the post always has a design-time answer.
- `currentWorkOffset` is **not** machine state. `onOpen()` sets it `undefined` — "no work offset emitted
  yet". Because it starts undefined the suppression cannot match on the first section, so section 1
  **unconditionally emits its select**, overwriting whatever the sender left modal. From then on the post
  is the only thing changing the selection. This is exactly why `writeWCS()` runs before `Start()`, the
  base establish and `writeWcsOnStart()`.
- **The distinction that matters:** the post always knows *which* frame is active (it commanded it); it
  never knows *where* that frame is. Register contents are controller-side runtime state and cannot be
  read back. So **selection is deterministic, origin is trusted** — every "Use Active WCS" mode is a trust
  assertion, which is why the *defaults* establish an origin rather than rely on one.
- **Homing does not change a WCS — it makes one trustworthy.** `G54`–`G59` hold offsets from machine zero
  and `$H` never touches those registers. On a homed machine a stored offset points at the same physical
  place across power cycles; with no endstops, machine zero is wherever the controller was last reset. So
  `Home Before Start = None` + `Use Active WCS X0 Y0` after a power cycle is quietly unsound, and worth a
  warning independent of anything else.
- Undefendable by any post: an operator typing `G55` into the console *mid-run*. Out of scope.

## Reserved spoilboard base

For multi-fixture jobs one WCS can be reserved as a **spoilboard base** — a *fixed-surface* zero,
independent of stock thickness. It is the one frame in which a safe height is meaningful across parts of
differing thickness, which is why the cross-part safe-Z feature requires it (Guard B).

Ignored on Marlin (warned) — it has no per-WCS registers to reserve. **The probe XY offset never applies
to the base**, for the reason below.

**The base probe emits no XY move — the park position is an operator precondition.** The base establish
runs before any origin is established, so there is no frame in which an XY target could be trusted. The
consequence is real and silent: **whatever is under the tool becomes the base's Z0**, so parking over the
stock records the stock top as "the spoilboard" and every clearance derived from it is short by the stock
thickness. **Mitigation is documentation, not code** — the durable fix is unbuilt and written up in
`PReview.md` §6.

> **Rejected: giving the base an XY origin.** The base stays a Z-only reference.

## Machine frame (homing / MCS)

**Per-axis granularity was dropped** — the modes (**None** / **XY** / **XYZ**) document operator intent,
not an axis mask, which is why GRBL can collapse two of them onto one command without losing anything.

| Firmware | Command |
|---|---|
| Marlin / RRF | `G28 X` / `G28 Y` (XY) then `G28 Z` (XYZ) — independent per axis |
| GRBL / FluidNC | `$H` only — one command homes all configured axes |

On GRBL `$H` is all-or-nothing, so XY and XYZ both emit one `$H` (the mode documents intent).
`B_Machine_PromptBeforeHome` pauses **once before any homing motion**, independent of firmware and axes.
The post does not control homing order. **`$H` is emitted with `writeln()`, not `writeBlock()`** — GRBL
only recognises `$` as a system command when it is the first character of the line (`HReview.md` CR-1).

## Firmware capabilities

Settled by reading each firmware's own source and changelog rather than by testing on a machine. **Do the
source read *before* filing a question as needing hardware** — the `M2` question was filed as unanswerable
without a controller and closed in one sitting from source, with a better answer than a dry run would have
given. Cite the file and version when adding here.

- Marlin — `MarlinFirmware/Marlin`, `Marlin/src/gcode/gcode.h` + `gcode.cpp`
- RepRapFirmware — `Duet3D/RepRapFirmware`, `src/GCodes/GCodes2.cpp`, plus the RRF wiki changelog
- GRBL — `gnea/grbl` wiki; FluidNC — `wiki.fluidnc.com`

**No supported firmware has canned drilling cycles**, so `onCyclePoint()` expanding drill/peck/bore/tap
into plain `G0`/`G1`/`G4` is correct and needs no revisiting.

| Firmware | Canned drilling cycles? |
|---|---|
| **GRBL 1.1 / FluidNC** | **No** — deliberately omitted. The supported set is G0–G3, G4, G10 L2/L20, G17–G19, G20/G21, G28/G30(.1), G38.2–G38.5, G40, G43.1, G49, G53, G54–G59, G61, G80, G90/G91(.1), G92(.1), G93/G94. **`G80` is "cancel motion mode", not "cancel canned cycle"** — there is no cycle to cancel. Only the third-party *GRBL-Advanced* fork adds G73/G76/G81–G83 |
| **Marlin 2.x** | **Only in an opt-in build.** G81/G82/G83 exist but are gated behind `CNC_DRILLING_CYCLE`, off by default and added by community PRs. A post cannot know whether the operator compiled it in |
| **RepRapFirmware / Duet** | **No — and worse than absent.** RRF's "GCodes not implemented" list carries G80 and G81–G89, while the wider RepRap dialect assigns those numbers to *other* functions: `G80` mesh-based Z probe, `G81` mesh bed levelling status, `G82` single Z probe, `G83` babystep Z and store. The post's decision is safe under either reading — either the command is unknown, or it triggers a bed-probing routine instead of drilling |

Two more settled the same way: **Marlin has never implemented `M2`** (RRF gained it in 3.5.1, with a
`stop.g` interaction), and **GRBL, Marlin and RRF all accept a bare `\r`** as a block terminator.

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

- **Group order** = the `group:` string, zero-padded to two digits, so `11 - Duet` sorts last. Current:
  `01 - Job`, `02 - Feeds and Speeds`, `03 - Map G1s to Rapids…`, `04 - Establish Machine Coordinates`,
  `05 - Establish Spoilboard Reference`, `06 - On WCS / Part / Fixture Changes`, `07 - Tool Changes`,
  `08 - External Include Files`, `09 - Laser`, `10 - Coolant`, `11 - Duet`.
- **Within-group order** = a single-letter key prefix, `<Letter>_<Group>_<Name>`, restarting per group.
  New properties take the next free letter (re-letter following ones if inserting mid-group).
- **The literal is now declared in that same order** (`HReview.md` CR-14), so display order no longer rests
  solely on Fusion sorting. Keep it that way when adding a property.
- This post uses the **combined-inline** `properties = {}` form, read with `getProperty(properties.key)`
  (an object reference, correct for this form). The split `properties` + `propertyDefinitions` form is the
  *old broken* approach — do not reintroduce it.
  > **Why this keeps coming up.** The predecessor `MPCNC.cps` used the split form; a Fusion change **broke**
  > it, and that break is the entire reason v3 exists — *"Updated to new method of handling properties"* in
  > the file header. So the split form is the **old** approach, not a newer target. Autodesk forum threads
  > describing `propertyDefinitions` as a "May 2021 enhancement" are not grounds to migrate (and those
  > pages 403 to automated fetching, so they cannot be verified anyway) — corroborate against this repo's
  > own history instead. Closed as-designed once already, as compliance finding F10.
- **What resets a saved preset:** the **key** is the stored identifier, so renaming or re-lettering a key
  resets that property to its default, as does changing an enum **`id`** or a boolean→enum conversion.
  Changing only a `group:` string, a title, an option title, or the declaration *order* does **not**. Every
  reset is a release-notes item.

**Origin/probe controls (group `06`).** Three separate controls — merging the two origin controls was
rejected, since it would apply job-start XY-zeroing to a mid-job WCS change. Both dropdowns are ordered
default-first, and both defaults are **no-prompt** modes because jogging at a pause isn't universally
supported.

- `A_Probe_OnStart` = **"First WCS / Part"** — `Set X0 Y0 to Current Pos, Probe Z0` (default) /
  `Set X0 Y0 Z0 to Current Pos` / `Use Active WCS X0 Y0, Probe Z0` / `Use Active WCS X0 Y0 Z0` /
  `Jog to X0 Y0, Probe Z0` / `Jog to X0 Y0 Z0`. The *Current Pos* modes assume a pre-jog; the *Use Active
  WCS* modes trust the stored fixture offset; the *Jog* modes pause (M0).
- `B_Probe_OnChange` = **"Subsequent WCS / Part"** — the same four non-Current modes, default
  `Use Active WCS X0 Y0, Probe Z0`. Fires on a genuine WCS change after the first section.
- `C_Probe_Pause` = **"Probe Pause"** — `No` / `Before` / `Before & After` (default). Gates the
  attach/detach prompts for the **part** probes only; adds no new stops.

> **"Use Active WCS", not "Use Existing WCS".** "Existing" read as a *temporal* claim — the WCS active
> before the job — which is wrong: the register is the one this Setup designates, and the post *selects*
> it at job start.

**Two properties were both titled "Safe Z".** Group 05's is now **"Inter Part Safe Z"** (whole mm above
the spoilboard); group 06's `I_Probe_SafeZ` keeps "Safe Z" (the post-probe retract). Keys unchanged.

---

## Design notes behind the shipped behaviour

### Traverse clearance is not the G1→G0 plane

`C_MapRapids_SafeZ` answers a narrower question — "within *this* operation, is Z high enough to re-emit a
cut G1 as a G0?" It is operation-scoped and only populated when the hobby group is on, so it is the wrong
source for an inter-op/inter-WCS retract. The cross-part retract uses a **job-level clearance measured
above the spoilboard base** (`D_Spoilboard_SafeZClearance`).

**Why the Inter Part Safe Z can't be an F360 expression (asked and answered).** `Clearance:40` would parse
today, and it is still the wrong source: every F360 height parameter is **per-operation and expressed in
that operation's own WCS**, while this must be expressed in the **base's** frame — feeding a part-frame
number into a base-frame `G0 Z` under-clears by the stock thickness, silently. F360 has no job-level
"above the machine table" height at all; the base frame is a post-invented concept. So it stays a plain
whole-mm `integer`. If an expression is ever wanted here, the only sound use is as a **floor**
(`max(constant, resolved)`), never a substitute.

### Base WCS is transited, not parked (R1/R2)

The base-relative retract must *select* the base to move in its frame (the numeric relation between two
WCS is only known after runtime probing). Two rules:

- **R1 — always restore the operating WCS.** After a base transit, advance to the next operation's WCS
  before any cutting; never cut with the base left active.
- **R2 — never round-trip the base empty.** Enter the base only when a real move is emitted there.

A transit selects the base with a low-level `writeBlock`, **not** `writeWCS()` — going through `writeWCS()`
would re-probe and rewrite the origin, which is the opposite of passing through a frame.

The same rules govern the **base establish**: it transit-selects the base *before* probing so that both the
`G38.2` target and the post-probe retract are measured against the base, then restores the operating WCS.

> **Superseded reasoning, kept because it is the plausible wrong answer.** An earlier note argued the base
> establish needed no `G59` select, since `G10 L20` does not change the active WCS. Correct as far as it
> goes — but it missed that the base's own probe and its post-probe retract would then execute in the
> *part's* frame, whose Z may be stale. **The missing select was the defect.**

### Why the first section's arrival is asymmetric

In `writeWCS()`, `isTraverse = (previousWorkOffset != undefined)` is false on the first section, so the
first section skips **both** the safe-Z retract and the origin/probe dispatch that every later WCS change
gets. Un-suppressing it where it sits does **not** work:

- **Ordering.** `writeWCS()` is step 3 of `writeFirstSection()`; `writeBaseEstablish()` is step 5. At step
  3 *neither* the part WCS's Z nor the base's Z has been established, so both retract paths would emit an
  absolute `G0 Z` into a stale frame — the same defect relocated.
- **Direction.** An absolute Z against a stale zero can move the tool *down*.
- **Blast radius.** With `isTraverse` true on the first section, the fallback fires on *every* job.

The resolution keeps the intent and fixes the placement: the first section's safe arrival happens **after**
the base establish, in the base's frame. And it exposes a hard limit — **with no base reserved there is no
established frame at job start at all**, so no retract can be made safe there. That case gets an Info
comment instead (`Ensuring that Z is safe. Unknown Z for XY move.`), emitted only on the one path that
deliberately emits no absolute Z move and only when no base is established.


## Reference — per-machine settings

| Machine / firmware | Home Before Start | Prompt Before Home | Reserved base | Operator does |
|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | `XYZ` if Z endstops fitted, else `XY` | Off | `G59` if multi-fixture, else `None` | homes X/Y; work-Z touched off with the plate either way |
| MPCNC + FluidNC, X/Y switches | `XY` | Off | `G59` if multi-fixture | homes X/Y; machine Z n/a, Z set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | `XYZ` | On | `G59` if multi-fixture | homes X/Y; at the pause places the movable plate, then Z homes to it |
| MPCNC, no switches | `None` | Off | `G59` if multi-fixture | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | `None` | one WCS zeroed to the part; no base |

> **Note the interaction** (`HReview.md` CR-2): any row above with homing on must **not** use a
> `Set … to Current Pos` origin mode — homing moves the tool, and the origin would be recorded at the
> endstop corner. `validateJob()` now warns.

---

## How to run a test

- **Post the job from Fusion and read the g-code.** Machine dry-runs and physical measurement are out of
  scope — every row must stand on the posted file alone.
- **Fusion posts with its own copy of the `.cps`** at `%APPDATA%\Autodesk\Fusion 360 CAM\Posts\`. Re-import
  before every session and **date the output** against a token the newest commit changed, or you will
  verify a stale build. Absence-based rows pass trivially on a build lacking the feature.
- **Read the posted file's own property dump before believing a row ran.** It records the whole dialog
  state; a row can silently not have been exercised.
- Output goes to `C:\Users\don_m\Documents\Fusion 360\NC Programs\`, **is not in the repo**, and a reused
  filename destroys evidence. **Name a post for the row it serves** (`HR12a`), not for what the job does,
  and grep this file for the name first.
- Setting any group-08 include makes Fusion ask *"This post processor might be unsafe…"* — answer **Yes**.
  Answering No aborts the post and **invalidates** the row rather than failing it.
- Defaults unless stated: GRBL/mm, Comment Level `Info`, probe target/speed/thickness `Z-10`/`F30`/`Z0.8`,
  probe Safe Z resolves to `5.08`. Comments are `( … )` on GRBL, `; …` on Marlin/RRF. `G10 L20 P<n>` on
  GRBL/RepRap, `G92` on Marlin.

**Method**, strongest first: **`posted`** a real file from the real post — the only method that proves what
a hobbyist receives · **`harness`** node against functions brace-matched out of the `.cps`, or a post from
`Personal.cps` — proves *logic*, not output · **`source`** firmware source · **`read`** a reading of the
post's own control flow — **weaker than the rest**, used only where the artifact a posted row needs does
not exist.

**Personas** (setup shorthand): **HP-1** one Setup / one Operation / one tool, pre-jogged XY, touch plate —
defaults + firmware + travel/max speeds + `Scale Feedrate` on · **HP-2** HP-1 + First WCS/Part =
`Set X0 Y0 Z0 to Current Pos` · **HP-3** HP-1 + a `Jog to …` mode · **HP-4** HP-1 on Marlin or RepRap ·
**HP-5** HP-1 + more than one operation. Group 03 is part of the HP-1 *persona*, not of the config a
verification post must carry — it cannot execute on a paid licence (HW-1).

---

## Tooling that ships with the repo

Two gates. They exist because every rule in this file used to be a prose imperative a session had to
remember, and three counts in `HReview.md` had already drifted by the time anyone counted them.

| Artifact | Fired by | Checks | Travels? |
|---|---|---|---|
| `docs/check-docs.js` | the pre-commit hook, or by hand | The contracts above: size budgets (warn), tallies vs their tables, findings-vs-register id completeness, heading ranges and row counts, Rule 3's pointer direction, the README `doc-sync` ref | ✅ tracked |
| `.githooks/pre-commit` | `git commit` — **anyone's**, not just a session's | runs `check-docs.js --staged`; non-zero aborts the commit | ✅ tracked, ❌ **not armed** — see below |
| `.claude/hooks/post-edit.js` | Claude Code, after every `Edit`/`Write` | `node --check` when the file is the `.cps`; silent for everything else | ✅ tracked |

Run the doc check by hand with `node docs/check-docs.js` (working tree) or `--staged` (what a commit
would record). It is deliberately quiet: `WARN` never fails a commit, only `FAIL` does.

**A fresh clone must run this once — nothing else installs it:**

```
git config core.hooksPath .githooks
```

`core.hooksPath` lives in `.git/config`, which is **never cloned**, so the tracked `.githooks/pre-commit`
arrives present but inert. `post-edit.js` — which *does* self-arm, through the tracked
`.claude/settings.json` — checks for the setting when the `.cps` is edited and prints the command if it
is missing. That is the only reason the omission cannot go unnoticed.

Claude Code asks for approval the first time a project's `settings.json` hooks block is seen or changes.
That is by design — a checked-in hook is executable code arriving from a repository — and is not a fault.

**Why the split.** Syntax is meaningful at *every* edit, so `node --check` runs then; deferring it to
commit lets further edits stack on a broken file. Document contracts are meaningful only once a change
is settled, which is what *Registers ship with the code* already says — the register is updated before
the commit lands, **not** after every intermediate edit — so checking them per-edit would fight that rule.

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
- **A pure reorder can be proved safe by matching sorted-line checksums** against `HEAD` — that is how
  CR-14's properties move was shown to change no character of any key, title or default.
- **`git commit -m` with a PowerShell here-string mangles messages containing double quotes** — write the
  message to a file and use `git commit -F`.

## Working method — lessons that keep paying off

- **A guard written to fail open produces a byte-identical file whether it read the value correctly or
  read nothing at all.** Make its diagnostic **unconditional**, not rejection-only (HR-6).
- **Absence-based rows need a presence-based sibling posted from the same build** (HR-11 (A)/(B)).
- **When a code path cannot be reached, question the premise before blaming the CAM.** HW-1 cost three
  posted files: `isSafeToRapid()` has one caller and is unreachable on a paid licence.
- **When a defect suppresses output it makes its own behaviour unverifiable — switch to the branch that
  emits.** HW-2 (B) was unanswerable on the manual path and trivial on the automatic one.
- **When the question is "does the controller honour this?", read the controller's source.** HR-11's `M2`
  was settled from `gcode.cpp` and the RRF changelog with no hardware.
- **`Personal.cps`** (repo root, git-excluded) is the post with `onRapid()` rerouted into `onLinear()` —
  the only way to reach the group-03 code, since a paid licence emits real `G0`s. Re-create it from the
  current `.cps`; its evidence is about *logic*, never about what the post emits.
- **Every one of the fixes deviated from its proposed diff, always the same way:** the proposal
  understated the number of call sites. Count them in the code before believing a diff is complete.
- **An ordering or synchronisation fix must cover every `loadFile()` branch, not just the default path.**
  A missing `flushMotions()` before job end was once patched only in the no-custom-file branch, leaving
  the `else { loadFile(...) }` branch — which injects motion from a user's footer file — still broken. It
  took a second corrected diff. Search for `loadFile(` and check the parallel branch before proposing.
- **Write every Pass criterion as something visible in the file** — exact tokens, their order, and what
  must be **absent**. When a row passes, mark it `PASS` outright: no "static PASS" hedging and no note
  explaining what was skipped. Splitting rows into static and physical halves once left them permanently
  half-passed and made the summary unreadable. Operator-safety facts a file cannot show (*park the tool
  over bare spoilboard before starting*) belong in code comments, here, and the README — never as a test
  step.
