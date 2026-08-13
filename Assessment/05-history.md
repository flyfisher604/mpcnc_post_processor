# Step 5 — Project history: verified problems vs. speculative additions

Read: `docs/design.md`, `docs/plan.md`, `docs/HReview.md`, the four `Coverage/`
documents, and `docs/PReview.md` recovered from `git show 347ce5d`. Nothing
written into any of them.

**A note on quality before the criticism.** These documents are unusually
rigorous. `design.md` records rejected alternatives alongside chosen ones, cites
firmware sources by file and version, and keeps superseded reasoning *because it
was a plausible wrong answer*. That is better practice than most professional
codebases manage. The over-engineering finding that follows is not a finding about
sloppiness — it is a finding about **rigour applied to a problem that was never
shown to be real**, which is a harder failure to see and much harder to admit.

---

## A method correction that applies to this whole review — **read first**

**`docs/design.md` is under audit. It cannot be used to prove anything.**

The author raised this against a sentence in `STATUS.md`, and it is a fair hit that
lands on more than one place in these documents. I twice reached a conclusion by
quoting `design.md` back as evidence — below, and in `04-user-stories.md` N2. That
is circular: the review exists partly to test whether that document's premises hold,
and one of them (`Marlin is single-frame`) has now turned out to be **false**. A
document with a false premise in it is not a source.

The rule applied from here on:

| `design.md` used as | Allowed? |
|---|---|
| A record of **what the post does and why the author chose it** | **Yes** — it is authoritative about intent |
| A **pointer to a primary source** it cites | **Yes** — then go read that source |
| **Evidence that a claim about F360 or a firmware is true** | **No** |

Where a conclusion in this review rested on `design.md`, it has been re-grounded on
a primary source or marked as unsupported. Two cases:

- **The cross-frame clearance argument** (below) — the conclusion **survives**, on
  independent evidence: F360's own machine-definition files, which have no
  machine-frame Z field at all (`03-f360-and-firmware.md` §1a and §3a). Better
  evidence than the original, because it comes from Autodesk's data rather than the
  project's prose.
- **`Marlin is single-frame`** — **refuted.** See the last section of this page.

One of two rested claims held and one failed, which is roughly what auditing a
document should be expected to produce, and is the reason the rule is now explicit.

## The single most important sentence in the project's own record

`docs/PReview.md` §3.1, heading and first paragraph:

> ### 3.1 Multi-part / multi-fixture — needs a job nobody has posted yet
> *"Every row below needs either a 2-copy Replicate job or a two-Setup job; none
> can be reached from the single-section jobs on disk. **This is the largest
> untested area in the post.**"*

> **Why, confirmed by the author 2026-08-13** `[AUTHOR]`: *"Yes true, because the
> professional level tests have not yet been done. Goal was to get a Beta3 that was
> stable for hobby users."*
>
> **This reframes the finding entirely, and in the project's favour.** The untested
> 21% is not neglect and not an oversight — it is a **deliberate sequencing
> decision**: stabilise the hobby path first, ship Beta3, then test the professional
> path. That is a defensible plan, and the 24 `[POSTED]` files in `HB-Tests/` are the
> evidence it was actually executed — every one of them a single-operation hobby job,
> exactly where the effort was aimed.
>
> What it does **not** do is change the risk, and the distinction is the whole point:
> deferred verification and absent verification look identical from inside the code.
> The professional machinery is in the same file, reachable from the same dialog,
> and on the author's own report it currently **errors out** on the F360 feature that
> drives it (`07-code-map.md`, Group 6). So the sequencing is sound; what is missing
> is the **gate** — nothing in the repository states that the professional path is
> unverified, and `guide-pro.md` describes it as though it were finished.
>
> **Corrected finding:** not *"21% of the post is untested"* but ***"21% of the post
> is deliberately deferred, and nothing says so where a user would see it."*** The
> remedy shifts accordingly — `08-target.md`'s Beta3 line, and a statement of status
> in `guide-pro.md`, both cheaper than code.

Every test row in that section is an unchecked box. PB1, PB2, PBV1, PBV2, PBV3,
PA1 — the multi-part workflow the post's most complex machinery exists to serve
has **never been posted, once, by anyone**, and the project knows it.

And `PReview.md` §1 maps the professional feature set to exactly the groups under
suspicion:

| Area | Controls |
|---|---|
| Multiple WCS / multiple parts | `Subsequent WCS / Part`, Replicate jobs, the `Jog to …` modes |
| The machine frame | group 4 — all three properties |
| The fixed Z reference | group 5 — all five properties |
| Cross-part clearance | `Retract Across Parts`, `Inter Part Travel Z` |
| Tool changes | group 7 — all eight properties |

So the answer to "which parts of this post serve an unverified need?" was already
written down. It is groups 4, 5, 6 and 7 — and the register that says so is the
one that was dropped out of the tree.

## Verified — a real problem, reproduced, worth preserving

These have evidence behind them. Each cites the thing that makes it real.

| Item | Evidence that makes it verified |
|---|---|
| **CR-1** — `$H` must use `writeln()`, not `writeBlock()` | GRBL parses `$` only as the line's first character. Firmware fact; a block number or space breaks it |
| **Stock GRBL rejects a `%` wrapper** | Landed fix `5a6a4e0`. Real emitted output that a real controller refuses |
| **`Enforce Feedrate` and the word separator leaked into the next post** | `b84f602`. Cross-post state leak, observed in posted files |
| **Missing include file was not refused before output** | `b61c005`. Silent bad file |
| **The bit was dragged across the work instead of retracting before an offset-probe traverse** | `cb1c9f2`. A real bad motion |
| **`Home at Job Start` could home nothing, silently** | `ec5af37` |
| **PR-9** — the `G53 G0 X0 Y0` park carried no `F` word | *"the longest move in the job crosses the bed at whatever feed the last cut commanded."* Reproduced by reading emitted output against its siblings |
| **PR-10** — the preamble moves the tool, so the default origin mode writes `Z0` at bed clearance | *"the probe never reaches the stock and the controller alarms."* A real crash path on the **default** setting |
| **PR-8** — Marlin + spoilboard + machine park emits `G55`/`G0 Z40`/`G54`, and `Gundefined` for a `G59.1` base | Guard ordering traced; emits invalid G-code |
| **PR-11** — a single-WCS job warned about a pause its file cannot contain | Traced to `writeWCS()`'s `isTraverse` |
| **The seven firmware questions in `design.md`** | Each settled from named source and version, and **each refuted something the project believed at the time**: `G30` is dead on all three firmwares; `G53` is not modal; RRF's `G38.2` target frame changed at 3.1.2; `G17`/`G94` are not free no-ops off GRBL; Marlin has no `M2` |

The firmware table is the most valuable artefact in the project. It is exactly
the work a post processor *should* contain — knowledge that cannot be derived
from F360 and must not be guessed — and `design.md` even records the lesson:

> *"All four above were answerable from sources already cited, and filing them as
> open cost a design decision (`G30`) that had no business surviving."*

## Speculative — built for a case never observed

| Item | Why speculative |
|---|---|
| **The whole multi-part / multi-fixture apparatus** — base frame, `Inter Part Travel Z`, the `Jog to …` per-part modes, both `Use Active WCS` modes, the spoilboard probe cycle | `PReview.md` §3.1: *"needs a job nobody has posted yet"*. No persona in `01-personas.md` supports it; V1's own documentation describes zeroing per job, not managing G54–G59 |
| **Group 5, `Fixed Z Reference`, all five properties** | Exists only to give cross-part clearance a common frame. Its own group title says *"multi-part jobs only"* — it is self-declared as serving the unverified workflow |
| **`Retract Across Parts`** | Already deleted by CR-13 (`fbd1591`, *"Remove Retract Across Parts and make Guard B unconditional"*). The project reached this conclusion itself, on one control |
| **The spoilboard base's silent failure mode** | `design.md`: *"whatever is under the tool becomes the base's Z0, so parking over the stock records the stock top as 'the spoilboard' and every clearance from it is short by the stock thickness. **Mitigation is documentation, not code**"*. A feature whose principal hazard is unfixable by design, serving an unposted workflow |
| **`Tool Change Z` measured in whichever WCS is active** (PR-4) | Flagged **in the post's own source** as *"likely a bug, not intended behavior"* — and still open, because it must compose with a Phase 4 reorder that is *"design settled; not built"* |
| **The Phase 4 tool-change block: HR-7, HR-8, HR-9, HR-10, HR-13** | Five open findings waiting on an unbuilt rework. HR-8 is annotated *"Confirmed unreachable on any hobbyist path"* — a defect that only exists for the persona with no evidence behind it |

## The distinction that matters — and a correction to my own step 3

`design.md` contains a direct rebuttal to something I concluded in
`03-f360-and-firmware.md`, and **it is right and I was partly wrong**:

> *"every F360 height parameter is **per-operation and expressed in that
> operation's own WCS**, while this must be expressed in the **base's** frame —
> feeding a part-frame number into a base-frame `G0 Z` under-clears by the stock
> thickness, silently. F360 has no job-level 'above the machine table' height at
> all; the base frame is a post-invented concept."*

So my non-goal **N2** was too broad. Split it properly:

- **Within one setup**, F360's clearance-height retracts are already in the
  toolpath, and a post may legitimately add nothing — proven by Autodesk's own
  `getRetractParameters()` returning `undefined`. **N2 stands here.**
- **Across two WCS**, F360 supplies nothing usable, because every height it gives
  is in the *wrong frame*. A post-invented common frame is a genuine answer to a
  genuine gap. **N2 does not apply here.**

This changes the shape of the Group 6 verdict substantially, and for the better:

> **The cross-part machinery is not technically wrong, and it is not F360's job
> being usurped. It is correct engineering, competently reasoned, for a user who
> has never been shown to exist.**

That is a much more defensible criticism than "the post is overreaching", and it
points at a different remedy. You do not fix it by handing the work back to F360
— F360 cannot do it. You fix it by deciding whether the workflow is in scope at
all, and if it is not, deleting the machinery and the seven open findings that
hang off it.

## One premise I could not verify at all — **now verified, and FALSE**

**Resolved 2026-08-13 from Marlin's own source, at the author's direction.** This
section was written as a suspicion. It is now a finding, and the suspicion was
correct.

`design.md` line 23: *"**Marlin is single-frame:** no per-WCS registers, so one
global `G92` origin. A Marlin job using more than one distinct work offset is a
hard error (Guard C)."*

### The verdict

**The premise is false, and the guard built on it is wrong.** Marlin with
`CNC_COORDINATE_SYSTEMS` enabled — which V1's own build system does enable
(`opt_enable \ CNC_COORDINATE_SYSTEMS \`, `[DOC]`
`V1EngineeringInc/MarlinBuilder`, `src/configs/common/cnc-config`) — has **nine**
work coordinate systems, individually selectable, held in a real array, **persistent
with EEPROM**. Full quoted evidence in `03-f360-and-firmware.md` §4b; in summary
`[DOC]` against Marlin 2.1.x:

| `design.md` says | Marlin source says |
|---|---|
| no per-WCS registers | `static xyz_pos_t coordinate_system[MAX_COORDINATE_SYSTEMS];` with `MAX_COORDINATE_SYSTEMS` = **9** (`gcode.h`) |
| one global `G92` origin | `coordinate_system[active_coordinate_system] = position_shift;` — `G92` writes **the selected system's** register (`G92.cpp`) |
| — | *"All workspaces default to 0,0,0 at start, or with EEPROM support they may be restored from a previous session."* (`G53-G59.cpp`) |

**So Guard C** ([MPCNC_v4.0_Beta2.cps:1689-1693](MPCNC_v4.0_Beta2.cps#L1689))
**refuses jobs the firmware would run**, and the message it prints —
*"Marlin has a single coordinate frame -- this multi-WCS job cannot be posted"* — is
a false statement shown to the user.

### The post already contained the evidence against itself

This is worth dwelling on, because it is a lesson rather than a bug. Forty lines
above Guard C, the post writes ([:1646-1649](MPCNC_v4.0_Beta2.cps#L1646)):

> *"Guard C EXTENDED, not inherited: `Marlin/src/gcode/gcode.cpp` (2.1.x) gates
> `case 53: G53();` inside `CNC_COORDINATE_SYSTEMS`, so a single-WCS Marlin job
> passes Guard C and still cannot move."*

**The same flag gates `G53` and `G54`–`G59.3`** — one `#if ENABLED(...)` block, one
file. The author had found the flag, cited it correctly, and reasoned from it
accurately for `G53`, while the conclusion recorded for `G54`–`G59` next door was its
opposite. Nothing here was careless; the two facts were established at different
times and never met on the same page.

**That is what this review is for**, and it is the clearest instance of it in the
whole exercise. The remedy is not more caution — it is keeping related firmware facts
in one table where they are forced to agree, which is what `design.md`'s tables do
everywhere else.

### The consequences, in order of size

1. **Delete Guard C.** It blocks a supported configuration. `09-plan.md` Step 2.1.
2. **`design.md` line 23 must be rewritten, not annotated.** Its Marlin row is wrong
   in the table this review elsewhere calls the project's most valuable asset — which
   is exactly why it cannot be left with a footnote.
3. **A minimum firmware version becomes a requirement, not a nicety** `[AUTHOR]`.
   Two reasons: the feature is a **build option**, so a stock Marlin genuinely lacks
   it; and `[DOC]` Marlin issue **#14743** reported `G92` inside `G54` corrupting the
   `G53` machine origin — closed, fix version not established from the page.
4. **The RepRap-only gate on slots 7–9 is too narrow.**
   [:1709](MPCNC_v4.0_Beta2.cps#L1709) should say "not GRBL": Marlin has
   `G59.1`–`G59.3` as well, via `parser.subcode`.
5. **A new hazard, worth more than the four above together.** Homing on Marlin runs
   `position_shift[axis] = 0` (`motion.cpp`, `set_axis_is_at_home()`), clearing the
   **applied** offset while leaving the **stored** register intact — and re-sending
   `G54` does *not* restore it, because `select_coordinate_system()` early-returns
   when that system is already active. The operator must select away and back.
   **On Marlin, homing silently detaches the program from its own work origin.**
   Tier 2 firmware knowledge; `design.md` does not have it; it is the mechanism
   behind S13's fragility in `04-user-stories.md`.

**Effect on the review's arithmetic.** Marlin moves from *"cannot do multi-WCS"* to
*"can, with a stated version floor and one sharp hazard."* The Marlin user joins
S12's persona rather than being excluded from it, and the change is a deletion — one
guard and one `design.md` row — not new machinery.
