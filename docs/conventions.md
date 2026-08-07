# Conventions — the models, the rules, and the method

The **durable** half of the project record for `MPCNC_v4.0_Beta2.cps`: the models the code assumes, the
conventions a change must follow, and the method by which anything is verified. It changes a few times a
year, not every session — if you are editing it often, something live has leaked in.

Which file owns what is the *Document contracts* table below. It is the only copy.

---

## Document contracts

Each file has a fixed job.

| File | May contain | Must **not** contain | Size guide |
|---|---|---|---|
| `CLAUDE.md` | Imperatives that change how a session works: read order, show-a-diff, `node --check`, the register rule, commit convention, what to leave alone | Rationale, history, design, anything that fires only once you are deep in one function | **≤ 60 lines** — it loads in full every session |
| `plan.md` | The checkpoint (baseline, what is true now, **what is left in order**, live risks), phase status, pointers to completed reviews | Design write-ups, findings, test rows, resolved decisions, open questions, backlog detail | **≤ 120 lines** |
| `conventions.md` | Three things — **the model** (frames, stance), **the conventions** (property & dialog rules), **the method** (how to run a test, harness, tooling) — plus external firmware facts and these contracts | Status of anything, what is next, unbuilt design | **≤ 480 lines** — an overrun means something live has leaked in. It is also the file the volatile ones drain *into*, so it absorbs before it trims. Do not raise it for content that is merely longer |
| `HReview.md` | Hobbyist findings register (`HR-`, `CR-`) + the test register. Open **questions** ride in the row of the finding they belong to | Professional findings or rows, design write-ups, durable conventions | **≤ 300 lines** — a register grows one line per row |
| `PReview.md` | Professional findings, professional test rows, **unbuilt design and its open questions** (§6), the jet/laser workstream | Hobbyist-only findings, durable conventions | **≤ 920 lines, and falling.** §2's long form and §3's expansions are unbuilt design and unrun rows; both retire on build. The §3 index table is permanent, everything under it is not |
| `README.md` | User-facing usage only. Its `doc-sync` marker records the ref it last synced to | Anything developer-facing | — |
| per-user **memory** (outside the repo) | Constraints about the user that hold across projects and cannot be derived from this repo — e.g. no controller hardware is available | **Anything about this post**: its code, conventions, status, findings or history | One short file per fact. Nothing here is reviewed in a diff, which is why so little belongs |

`docs/check-docs.js` enforces the numbers above — see *Tooling that ships with the repo*.

### What earns a place in this file

**First test: can the code state it?** If yes, the code owns it — a property enum, a function signature, a
step summary is one edit away from being a lie, and deleting it loses nothing because the `.cps` says it.
What belongs here is what reading the post **cannot** answer:

- an **external fact** — what Marlin, GRBL, RRF or Fusion does;
- a **rejected alternative** — the code cannot contain what was decided against;
- a **silent consequence** — an *absence* of output never explains itself;
- the **why** behind an ordering that looks arbitrary in code.

**The exception that matters:** a derivable fact stays when it is a **premise the surrounding argument
needs**. That `onOpen()` sets `currentWorkOffset = undefined` is readable from the code, but the
*selection is deterministic, origin is trusted* argument collapses without it. Cut conclusions the code
already states; keep the steps that make a non-derivable argument stand up.

**Second test, for design content only.** The code can never state *why*, so every design rationale passes
the first test, and the post holds several hundred of them. A design fact needs a second warrant — it is
either **the model** or **a trap**:

- **The model** — the shared vocabulary the rest of this file is unreadable without: what a WCS, the fixed
  Z reference and a transit *are*. ***Frames*** is that section, and it grows only when the post gains a
  frame — which has happened once, when a homed machine Z became a second implementation of the fixed Z
  reference. It absorbed *Coordinate model*, *Reserved spoilboard base* and *Machine frame*, which were
  three sections stating one trust rule three times.
- **A trap** — someone reached the wrong answer, or the wrong answer would fail **silently**. Every trap
  names its evidence: a finding id, a *Rejected*, or a *Superseded*. A section that cannot name one has
  stopped earning its place.

A design choice that is merely *true* is neither, and stays in the code. **This is a gate, not a home:
there is deliberately nowhere to put the other several hundred.** **Nothing mechanical defends this** —
no checker reads the post to see whether a name here still resolves, let alone whether a claim still
holds. These two tests, applied by whoever is editing, are the only defence.

### Four rules that keep it that way

1. **A new top-level section in *any* of these files requires changing its contract here first.** If the
   content does not fit a section the file already has, the question is *which file owns this*, not *can
   this one hold it*. A review document's sections are fixed — see *The shape of a review document*. This
   file has no fixed list, because it is heterogeneous by design; the gate is the admission test above.
2. **Over the size guide means something has stopped being live.** Check what has quietly become durable
   (→ here) or register-shaped (→ a register) rather than trimming prose.
3. **Never point two ways.** If file A says "written up in B", B must hold the write-up and must not point
   back. A pointer is valid in one direction only: from status toward the register that owns the work.
   (`plan.md` and `PReview.md` §6 once pointed at each other for four items, and neither held the content.)
4. **Every accumulating section states what empties it.** Three exist today, and these are their clauses:
   - `HReview.md` → *Invalidated by the … code-review fixes* — delete a row when its test is re-posted,
     and the **section** when it empties. It expires with the `⬜` rows it was written for.
   - *Checked and found correct* in either register — delete a row when a `posted` row supersedes it.
     Both are `read`-strength, and `posted` is strictly stronger.
   - Findings tables — the **row** stays, always, because commit messages and code comments cite the id
     and it must still resolve. What goes is the prose: on closure the Resolution collapses to the commit
     ref plus one clause.

### The shape of a review document

`HReview.md` and `PReview.md` are the two that exist; a third review pass gets the same shape. It is fixed
because the two once diverged — the same content type under a different heading in each — and
`check-docs.js`, matching HReview's headings only, left the larger register ungated.

| § | Section | Holds | Required? |
|---|---|---|---|
| 1 | **Scope** | Which persona and which controls this review covers, and what it deliberately excludes | yes |
| 2 | **Findings** | The register **table**: `ID · Finding · Sev · Resolution · Status`. One row per finding, forever — commit messages cite the ids | yes |
| 3 | **Test register** | The register **index table**: `Test · Proves · Setup · Method · State`, one row per id | yes |
| 4 | **Invalidated by …** | Rows whose saved `.gcode` a change broke. Retires per Rule 4 | when non-empty |
| 5 | **Checked and found correct** | `read`-strength readings. Retires per Rule 4 when a `posted` row supersedes | when non-empty |
| 6 | **Owed** | What the register itself owes: which artifacts, and why each is worth a post. **Not** the order of work — that is the checkpoint's | yes |
| 7 | **Design backlog** | Unbuilt design and its open questions. **Only** where the file's contract admits unbuilt design — `PReview.md` does, `HReview.md` does not | optional |

**The fields are canonical; the rendering is not.** A test row must carry an id, a state marker, a setup
delta, a method, and an *Expect* naming its discriminator. Put the *Expect* in the index table where it
fits one line, as HReview does; where it needs a multi-line g-code block a markdown cell cannot hold, the
block goes in an expansion directly beneath **in the same section**. That is an index, not a
cross-reference — what Rule 3 forbids is the *Expect* existing in two places.

Three mechanical rules the checker depends on:

- **The state marker is the *last* column** of every register table. Put an Expansion reference before
  it, never after.
- **Every register states its tally above its table** — `✅ n · ❌ n · ⬜ n · ➖ n — n rows`, and for a
  findings table `— n findings`.
- **Every findings id resolves to a test row.** If a finding is verified by another row's matrix, leave
  a `➖` pointer row saying so, exactly as a moved finding does.

Sections are matched **by name, not by number**: `PReview.md` numbers its sections and `HReview.md` does
not, and renumbering either to force the order above would break some thirty cross-references for
cosmetic gain.

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

## Frames — *the model; every other section reads against this one*

Production controls keep three references separate: **MCS** (`G53`), **WCS** (`G54`–`G59`, `G59.1`–`G59.3`
on RepRap), and **TLO** (`G43`). Most V1E machines have none fully, hence the work-relative stance. **There
is no tool-length system at all** — no TLO, no tool setter — so a work-Z re-probe after each tool change is
the substitute, and **X/Y is never probed**.

- **Persistence:** WCS origins are written with `G10 L20 P<n>` on GRBL/RepRap — scoped to that WCS's own
  register. `P` maps 1:1 to Fusion's `workOffset` (P1–P6 = G54–G59; P7–P9 = G59.1–G59.3, RepRap only).
- **Marlin is single-frame:** no per-WCS registers, so one global `G92` origin. A Marlin job using more
  than one distinct work offset is a hard error (Guard C).
- **`workOffset 0`** is Fusion's "default / unset", **not** a request for `G53`; it aliases to WCS 1 /
  `G54`, and must alias identically everywhere, or two paths disagree about which frame a section is in.
- Undefendable by any post: an operator typing `G55` into the console *mid-run*. Out of scope.

### Selection is deterministic, origin is trusted

**The post commands a frame and can never read back where it is** — register contents are controller-side
runtime state and there is no query. So it always knows *which* frame is active, and never *where*.

**It asserts the WCS selection and never inherits it**, which justifies `writeFirstSection()`'s ordering:
Fusion always supplies a work offset per section, so there is always a design-time answer, and
`currentWorkOffset` is **not** machine state — `onOpen()` sets it `undefined`, so the suppression cannot
match on the first section, section 1 **unconditionally emits its select** over whatever the sender left
modal, and thereafter the post alone changes the selection. Hence `writeWCS()` before `Start()`, the
fixed-Z establish and `writeWcsOnStart()`.

Everything unreadable is therefore a **trust assertion**, and there are two: **a stored WCS origin** (every
`Use Active WCS` mode — which is why the *defaults* establish an origin rather than rely on one) and **a
declared machine frame** (the group-4 declarations, the same species).

**Homing does not change a WCS — it makes one trustworthy.** `G54`–`G59` hold offsets from machine zero and
`$H` never touches those registers. Unhomed, machine zero is wherever the controller was last reset — still
fixed for *that* power cycle, so origins **created** during a run stay mutually consistent and a no-endstop
multi-part job is sound. Only a **stored** offset goes bad, which is the whole of why that guard is
mode-sensitive rather than blanket.

**The one place a trust assertion is not enough:** when a declared frame becomes the **datum for an
absolute move**, the job must *establish* it — so `Fixed Z Reference = Machine Z` requires `Home at Job
Start`, not merely the declaration. Firmware forces it: with homing enabled **GRBL comes up in Alarm and
refuses all motion until homed**, so a stale declared frame cannot execute there, while Marlin and RRF have
no such lock and run the move against a machine zero that has moved.

### The machine frame — capability, then action

`Axises Homed and Trusted` — `None` / `XY Only` / `Z Only` / `XYZ` — is a **fact about the machine**;
`Home at Job Start` is **a decision about this job**. Separating them expresses a state the old
`Home Before Start` enum could not: *homed at the controller, do not home here*.

**One enum, two predicates.** The declaration is one dialog control because the operator declares a
machine, and its four answers are exactly the four combinations of two independent axis facts. The code
never reads it directly: `machineHomesXY()` and `machineHomesZ()` are the only accessors, because the
machine-Z datum needs Z and the stored-offset warning needs X/Y, and **neither implies the other** — an
`== "XYZ"` test anywhere would silently exclude `XY Only` and `Z Only`.

> **Superseded, kept because both are plausible wrong answers.** (1) The old `None`/`XY`/`XYZ`
> `Home Before Start` enum conflated the capability with the action, had no way to say *Z only*, and its
> `XYZ` answer emitted `G28 Z` and then threw away the fact that the machine *has* a homed Z. (2) The two
> booleans that replaced it — `X/Y Home` + `Machine Z Home` — carried the right information but asked the
> operator two questions about one machine and let the dialog express the pair as unrelated. The current
> enum is information-identical to the booleans and is **not** a return to the first form: it declares
> capability only, and the action stays separate.

| Firmware | What the post can emit |
|---|---|
| Marlin / RRF | `G28 X` / `G28 Y` / `G28 Z` — genuinely independent per axis |
| GRBL | one `$H`. Which axes it homes is **compile-time** (`HOMING_CYCLE_0/1/2`, default Z then X\|Y) and `$HX`/`$HY`/`$HZ` sit behind `HOMING_SINGLE_AXIS_COMMANDS`, **off by default** |
| FluidNC | single-axis homing is a **configuration** option, so `$HX`/`$HZ` need no rebuild |

So **on GRBL the split is bookkeeping, not emission** — the post can neither emit per-axis homing nor
corroborate the declaration. FluidNC could, and this post treats FluidNC as GRBL throughout: the one place
that conflation costs something real. **"Prompt Before Home"** pauses **once before any homing motion**,
whatever the firmware and axes; the post does not control homing order. **`$H` uses `writeln()`, not
`writeBlock()`** — GRBL recognises `$` only as the line's first character (CR-1).

### The fixed Z reference — one concept, two implementations

A frame whose Z0 does not move with stock thickness — the only frame in which one clearance height is
meaningful across parts of differing thickness, which is why the cross-part safe-Z feature requires one
(Guard B). A machine can have one two ways, and they are one dialog question:

| Answer | The frame | `Inter Part Travel Z` is then… | Costs |
|---|---|---|---|
| **Spoilboard** | a probed surface in a reserved WCS | a height **above that surface** — positive | one WCS register — GRBL has six — plus a probe cycle |
| **Machine Z** | the machine's own homed Z | an **absolute machine coordinate** — signed | a per-machine number read off a DRO |

**One clearance field, not two.** The two answers are never both live, they are read at the same two
moments (the establish in the preamble, and each cross-WCS traverse), and on a correct setup they name the
*same physical plane* — so they are one control, `Inter Part Travel Z`, and this enum says which frame it
is measured in. What that costs is a hazard the two separate fields made impossible: **the enum flip**. A
height valid in the other frame is still a valid-looking height, and only one direction is detectable —
a spoilboard clearance is measured *up* from the probed surface, so `<= 0` cannot be one and is guarded,
while a spoilboard `40` left in a machine-Z job is indistinguishable from a real height on a bed-zeroed
machine. Three things carry that risk: the field **ships empty and is guarded under both answers**, so an
untouched dialog cannot post; the header echo **names the frame** beside the number; and both tooltips say
the frame is decided elsewhere.

**Why it is a parsed string and not a number.** Under the spoilboard answer a number would do — `0` is
meaningless there, so it could have served as *unset*, which is what the old whole-mm integer relied on.
The machine-Z answer has no such spare value: every signed number is a real reachable height, `0` very
much included (on a stock GRBL build the machine zeroes into negative space, so `Z0` is the *top of
travel*). Fusion's schema gives a numeric property no unset state, so *empty* is only expressible on a
string — and once the field is shared, the stricter of the two requirements wins.

> **Rejected: exposing only the spoilboard** — the shipped design, which *rejected* multi-WCS jobs on
> machines whose homed Z would have served, Guard B refusing for want of a base while the operator had
> already declared the machine homes Z and the post had discarded the fact.
> **Rejected: giving the base an XY origin.** The base stays a Z-only reference.

**Spoilboard — the base probe emits no XY move, so the park position is an operator precondition**, and
that is why the probe XY offset never applies to it: the establish runs before any origin exists, so no XY
target could be trusted. The consequence is real and silent — **whatever is under the tool becomes the
base's Z0**, so parking over the stock records the stock top as "the spoilboard" and every clearance from
it is short by the stock thickness. **Mitigation is documentation, not code**; the durable fix is unbuilt,
in `PReview.md` §6. Ignored on Marlin (warned), which has no registers to reserve.

**Machine Z — one absolute height, collected, never derived.** A height read off the DRO *after* homing is
already in the controller's own frame, which is what makes it immune to everything below. Units are not: a
`G53` move is read in the active `G20`/`G21` and GRBL's `$13` can report position in inches — hence the mm
contract and the header echo. And **transplant, not typing, is its hazard with no precedent here**: every
other dangerous height in the dialog is WCS-relative and self-correcting, still measured from whatever
machine it lands on, while this is the post's only absolute machine coordinate and therefore the first
number a copied Setup or a shared design makes **wrong** rather than merely different.

> **Rejected: an enum naming where the Z switch sits** (top of travel / at the bed). It cannot pin the sign
> it exists to pin: switch position and the machine value assigned there are independent, and on GRBL the
> second is not even a runtime choice — `HOMING_FORCE_SET_ORIGIN` (`grbl/config.h`) exists to *"force Grbl
> to always set the machine origin at the homed location despite switch orientation"*, and at its default
> Grbl zeroes into negative space whatever the switch orientation. Compile-time, so no `$` query exposes
> it. (Marlin: `Z_HOME_DIR` + `Z_MIN_POS`/`Z_MAX_POS`.)
> **Rejected: any reference + delta pair** (`Spoilboard Machine Z`, or `Machine Z at Home`, plus a signed
> offset) — a sum the operator computes and trusts, where one field is a height they jogged to and *saw*
> clear. The second also shows the delta cannot hold one meaning: on a top-of-travel machine its best value
> is zero, on a plate-at-the-bed machine it *is* the spoilboard clearance.

## Firmware capabilities

Settled by reading each firmware's own source and changelog rather than by testing on a machine. Cite the
file and version when adding here.

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

Four more settled while designing the machine frame. Each **refutes** something believed at the time, and
each is a place a one-dialect assumption would have shipped a wrong motion:

| Question | Answer |
|---|---|
| `G53` per firmware | GRBL 1.1 supports it (above). **Marlin gates `case 53:` behind `CNC_COORDINATE_SYSTEMS`, off by default** (`gcode.cpp` 2.1.x) — so a *single-WCS* Marlin job passes Guard C and still cannot execute the move: that exclusion is separate, not inherited. It is also **not modal — program it on every line**, and an error without `G0`/`G1` active (LinuxCNC; RRF the same), so a split Z-then-XY move carries `G53` twice |
| `G30` to store a park height | **Dead on all three.** GRBL/LinuxCNC: bare `G30` moves **X and Y too**, and `G30 Z<n>` rapids first to that Z *in the current WCS, offsets included*. Marlin and RRF: `G30` is a **single Z probe** — a plunge. Same trap `G80`–`G83` sets above |
| Jogging at an `M0` pause | **Not possible on GRBL** — *"a jog command will only be accepted when Grbl is in either the 'Idle' or 'Jog' states"* (Grbl v1.1 Jogging), and `M0` is neither. Only RRF has a real jog-at-pause (`M291 … X1 Y1 Z1`) |
| `G38.2` target frame | **Version-bound on RRF.** `G38.x` on Duet 2+ / RRF 3+, and **up to RRF 3.1.1 the target is machine coordinates**, user coordinates after. This post emits a work-frame target, so leaving it On below 3.1.2 probes to the wrong physical Z |

> **The lesson, twice over — and it is why *do the source read before filing a question as needing
> hardware* is a rule here.** (`M2` was filed as needing a controller, then closed from source.) All four
> above were answerable from sources already cited, and filing them as open cost a design decision
> (`G30`) that had no business surviving. And **both errors were outside GRBL**: a FluidNC conflation and
> the RRF version bound, the second of which would have produced a wrong physical motion. GRBL is not the
> coverage that is short.

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
**"Travel Machine Z"** as well — see *The fixed Z reference* above.

---

## Design notes behind the shipped behaviour

### Traverse clearance is not the G1→G0 plane

**"Map: Safe Z to Rapid"** answers a narrower question — "within *this* operation, is Z high enough to
re-emit a cut G1 as a G0?" It is operation-scoped and only populated when the hobby group is on, so it is
the wrong source for an inter-op/inter-WCS retract. The cross-part retract uses a **job-level clearance
measured in the job's fixed Z reference** ("Inter Part Travel Z").

**The Inter Part Travel Z cannot be an F360 expression (asked and answered).** `Clearance:40` would parse
today and is still the wrong source: every F360 height parameter is **per-operation and expressed in that
operation's own WCS**, while this must be expressed in the
**base's** frame — feeding a part-frame number into a base-frame `G0 Z` under-clears by the stock
thickness, silently. F360 has no job-level "above the machine table" height at all; the base frame is a
post-invented concept. So it stays a plain whole-mm `integer`. The only sound use of an expression here
would be as a **floor** (`max(constant, resolved)`), never a substitute.

### Base WCS is transited, not parked (R1/R2)

The base-relative retract must *select* the base to move in its frame (the numeric relation between two
WCS is only known after runtime probing). Two rules:

- **R1 — always restore the operating WCS.** After a base transit, advance to the next operation's WCS
  before any cutting; never cut with the base left active.
- **R2 — never round-trip the base empty.** Enter the base only when a real move is emitted there.

A transit selects the base with a low-level `writeBlock`, **not** `writeWCS()` — going through `writeWCS()`
would re-probe and rewrite the origin, which is the opposite of passing through a frame. The same rules
govern the **base establish**: it transit-selects the base *before* probing so that both the `G38.2`
target and the post-probe retract are measured against the base, then restores the operating WCS.

> **Superseded, kept because it is the plausible wrong answer.** An earlier note argued the base establish
> needed no `G59` select, since `G10 L20` does not change the active WCS — correct as far as it goes, but
> it missed that the base's own probe and its post-probe retract would then execute in the *part's* frame,
> whose Z may be stale. **The missing select was the defect.**

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
the fixed Z reference is established, in that reference's frame. That exposed a hard limit — **with no
fixed reference there is no established frame at job start at all**, so no retract can be made safe there.
That case gets an Info comment instead (`Ensuring that Z is safe. Unknown Z for XY move.`), on the one path
that deliberately emits no absolute Z move.

**The machine-Z answer lifts the limit rather than working around it.** A declared, homed machine Z *is* an
established frame at job start, so on such a machine the arrival emits a real `G53 G0 Z<Inter Part Travel Z>`
and the comment is suppressed exactly as an established base suppresses it. The limit stands only where it
is still true: a job that declares no fixed reference at all.

## Reference — per-machine settings

Group 4 is `Axises Homed and Trusted` (the declaration) + `Home at Job Start` (the action); group 5 is
`Fixed Z Reference` and the one clearance it gives a frame to.

| Machine / firmware | Axises Homed and Trusted | Home at start | Prompt | Fixed Z Reference (multi-fixture) | Operator does |
|---|---|---|---|---|---|
| LowRider (Marlin or FluidNC) | `XYZ` if Z endstops fitted, else `XY Only` | on | Off | `Machine Z` where Z is declared, else `Spoilboard` `G59` | homes X/Y; work-Z touched off with the plate either way |
| MPCNC + FluidNC, X/Y switches | `XY Only` | on | Off | `Spoilboard` `G59` | homes X/Y; machine Z n/a, Z set by the work plate |
| MPCNC + Marlin, plate as Z-endstop | `XYZ` | on | On | `Spoilboard` `G59` — `G53` is a Marlin build option | homes X/Y; at the pause places the movable plate, then Z homes to it |
| MPCNC, no switches | `None` | off | Off | `Spoilboard` `G59` | parks X/Y by hand as zero; Z set by the work plate |
| Single-part job (any machine) | per row above | per row above | per row above | `None` | one WCS zeroed to the part; no fixed reference needed |

> **Two interactions the rows do not show.** (1) `HReview.md` CR-2 — any row with `Home at Job Start` on
> must **not** use a `Set … to Current Pos` origin mode: homing moves the tool and the origin would be
> recorded at the endstop corner. On a homed machine `Use Active WCS X0 Y0, Probe Z0` is the natural
> answer instead, which is what the warning now says. (2) A stored work offset is repeatable only against
> a homed machine zero, so the two `Use Active WCS …` modes warn when the declaration does not include X/Y — and
> deliberately do **not** warn on the `Jog to …` modes, where every origin is created during that run.

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

| Artifact | Fired by | Checks | Travels? |
|---|---|---|---|
| `docs/check-docs.js` | the pre-commit hook, or by hand | The contracts above: size budgets (warn), tallies vs their tables, findings-vs-register id completeness, heading ranges and row counts, Rule 3's pointer direction, the README `doc-sync` ref. Prints which registers it actually parsed — a checker silent about what it skipped reads as a clean bill of health. **Documents only:** it never reads the `.cps`, and two checks that did have been removed for it | ✅ tracked |
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
  posted files: `isSafeToRapid()` has one caller and is unreachable on a paid licence.
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
  spoilboard before starting*) belong in code comments, here, and the README — never as a test step.
