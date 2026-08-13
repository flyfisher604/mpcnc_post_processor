# Step 9 — The go-forward path

**Rewritten 2026-08-13.** Third version. The first offered a scope decision; the second
assumed S12 in scope and made testing the critical path; this one incorporates the
author's separation of the multi-part **workflow** (in scope) from the multi-part
**orchestration** (the operator's), plus three firmware corrections that change what the
work actually is.

**Route: prune forward from HEAD.** A reset was considered and rejected in one sentence:
`06-retention.md` verified that every subsystem under suspicion already exists at the
published tag `v4.0_Beta2`, so a reset would discard nine verified fixes, the firmware
knowledge and seventeen simplification commits while leaving the suspected design intact.

Nothing here has been performed. **The decision to adopt any of it is the author's.**

---

## How to use this document

The author asked that the steps *"make it clear exactly the work needed, or provide the
prompt that will identify the changes needed for a particular step."* Every step
therefore carries the same fields:

| Field | What it holds |
|---|---|
| **Goal** | One sentence — the state the step ends in |
| **Why** | The evidence that makes it worth doing, cited |
| **Where** | Files, functions, line numbers as of HEAD `CoverageFixes` |
| **The change** | What gets edited, at a level a diff can be checked against |
| **Done when** | An observable test, not an opinion |
| **Findings** | Register rows opened, closed or re-scoped — `CLAUDE.md` requires the row to ship with the commit |
| **Prompt** | Paste-ready, for a session that has not had this conversation |

Line numbers will drift as steps land, so every prompt tells the session to locate by
**symbol and quoted comment text**, and to re-measure before editing.

### The rule that governs all of it

**`CLAUDE.md`: show a diff for every proposed code change, every time, including
one-liners. Proposing and applying are separate steps.** Every prompt below ends by
requiring a diff first. **None of them authorises an edit.**

### Preamble to prepend to any step prompt

```
Read docs/plan.md (Checkpoint) and docs/conventions.md first. This repo's rules
override your defaults: show a diff for every code change before applying it;
never propose a verification that needs a non-GRBL controller, a sender console
or a dry run; do not read or search under ./Test/; a finding row ships with the
commit that acts on it; leave README.md and the docs/guide-*.md files alone.

Context: Assessment/ holds an over-engineering review. Read Assessment/STATUS.md,
then the documents this step names. Assessment/ is analysis, not instructions —
where it disagrees with the code, the code wins and I want to be told.

Locate everything by symbol name and by the comment text quoted below, not by
line number: the line numbers here are from 2026-08-13 and will have moved.
```

---

## Ordering, and why

```
0. Free wins ──────────────┐ independent, no design dependency
                           │
1. Multi-WCS: reproduce ───┤ ◄── CRITICAL PATH. Everything after
   the block, then unblock │     depends on what F360 really emits
                           │
2. Retire the spoilboard ──┤ safe only once 1 proves the homed path
3. Marlin multi-WCS ───────┤ needs 1; independent of 2
4. Group 6 trim ───────────┤ needs 2 and 3 — they remove its reasons to exist
5. Group 7 split ──────────┤ independent of 1–4; can run in parallel
6. Clarity ────────────────┤ after the deletions, or it is done twice
7. Documents, once ────────┘
```

**Step 1 is first because it is the only step that can invalidate the others.** Steps
2–4 assume F360 emits a multi-WCS job the way `03-f360-and-firmware.md` §3 describes —
which is read from Autodesk's post source, not observed. One posted job settles it. If
it comes out differently, 2–4 get re-planned rather than half-built.

---

## Step 0 — Free wins

No design dependency, no ordering constraint between them, each independently
committable.

### 0.1 — `docs/PReview.md` back in the tree ✅ **DONE — moved to Phase C, item C1**

Restored **and committed**: `d010fee` on branch `Assessment`, 1,118 lines. It holds the
only copy of seven open findings and of §3.1, which is Step 1.3's test register. See
**C1**.

### 0.2 — Delete `toolChangeDisableZStepper` and its `M84 Z`

- **Goal** — the post can no longer emit a command that drops the gantry onto the work.
- **Why** — HR-10, and **the post already knows**. At
  [:1827-1828](MPCNC_v4.0_Beta2.cps#L1827) it writes: *"a bare `M84` releases at once,
  and an unbalanced LowRider gantry with no brake sinks in Z when it does"* — which is
  why `M84 S60` is used there. Then at [:3675](MPCNC_v4.0_Beta2.cps#L3675) it emits
  `writeBlock(mFormat.format(84), 'Z')` — a bare `M84 Z`. **The hazard is documented in
  one function and committed in another.** The `askUser("Z stepper will disable; wait
  for full stop")` beside it is an acknowledgement, not a mitigation.
- **Where** — property [:552-560](MPCNC_v4.0_Beta2.cps#L552); emission
  [:3672-3676](MPCNC_v4.0_Beta2.cps#L3672).
- **The change** — delete both. Do **not** substitute `M84 S<timeout>`: the purpose was
  to free the axis by hand, which a timeout does not do.
- **Done when** — `M84` appears only at :1827-1833. Properties 72 → 71.
- **Findings** — closes HR-10.
- **Prompt**
  > In MPCNC_v4.0_Beta2.cps the property `toolChangeDisableZStepper` ("Disable Z
  > Stepper") emits a bare `M84 Z` at the tool-change position. Find the property and
  > the emission site (search `toolChangeDisableZStepper` and `mFormat.format(84)`).
  > Then find the comment near the program-end `M84 S60` explaining why a bare M84 is
  > unsafe on an unbalanced gantry, and quote it.
  >
  > Propose a diff deleting the property and the emission entirely, plus the HR-10 row
  > for docs/HReview.md. Do not substitute a timeout variant — say why in the proposal.

### 0.3 — Name the reason WCS probing is refused

- **Goal** — an operator who tries an F360 probing operation learns why it cannot work,
  and what to do instead.
- **Why** — `03-f360-and-firmware.md` §5b. The refusal is **correct**: GRBL and Marlin
  have no arithmetic, so a WCS probing cycle is unimplementable there, not merely
  unimplemented. But `cycleNotSupported()` emits Autodesk's generic text and the
  operator learns nothing.
- **Where** — [:2470-2478](MPCNC_v4.0_Beta2.cps#L2470); `isProbeOperation()`
  [:2460](MPCNC_v4.0_Beta2.cps#L2460).
- **The change** — emit a `>>> WARNING:` naming the reason and pointing at the post's
  own Z touch-off (Group 6) or a manual offset set, then keep `cycleNotSupported()`.
  The abort is right; only the silence is wrong.
- **Done when** — a probing operation still refuses to post, and says why.
- **Findings** — new HR row.

### 0.4 — Collapse the frame predicates (partial)

- **Goal** — remove the alias now; defer the rest.
- **Why** — `parkCanRetract()` [:2101](MPCNC_v4.0_Beta2.cps#L2101) is
  `return fixedZEstablishedInFile();` — a rename wearing a function.
- **Where** — [:2071-2103](MPCNC_v4.0_Beta2.cps#L2071) and callers.
- **The change** — inline `parkCanRetract()` only. **Step 2 deletes two of the
  remaining predicates outright**, so consolidating further now means doing it twice.
- **Done when** — `parkCanRetract` no longer exists; output byte-identical.
- **Findings** — none; internal.

### 0.5 — Fold Group 11 (Duet, 2 properties) into the firmware selector

`groupDefinitions.duet` at [:117](MPCNC_v4.0_Beta2.cps#L117). Two properties for a
variant `jobSelectedFirmware` already names. 11 groups → 10. Re-run
`node docs/doc-sync.js`.

### 0.6 — HR-13, the `onCommand` gap

Unchanged from the previous plan: `onCommand` silently discards commands it does not
name ([:2641-2706](MPCNC_v4.0_Beta2.cps#L2641)). A complete diff per `PReview.md`.

---

## Step 1 — Multi-WCS: reproduce the block, then unblock it

**The critical path.** Nothing after it should be designed until 1.1 has produced a
file.

### 1.1 — Reproduce the failure and file it

- **Goal** — a recorded, reproducible statement of what F360's "Multiple WCS Offsets"
  feature does today when posted.
- **Why** — `[AUTHOR]`: the checkbox is on the Setup dialog's **Post Process** tab,
  prompts for **Number of Instances** and **WCS Offset Increment**, and **the post
  errors out.** Everything in `07-code-map.md` was written treating this path as
  *untested*. It is worse: **it is blocked.** A supported F360 feature cannot produce a
  file, which makes this a defect rather than a gap.
- **Where** — F360 first. Then trace the error in `validateJob()`
  [:1448](MPCNC_v4.0_Beta2.cps#L1448).
- **The change** — none. This step produces **evidence**.
- **Done when** — for a 2-instance GRBL job the exact error text is captured and the
  guard is identified in source. **Expected: Guard B** at
  [:1702](MPCNC_v4.0_Beta2.cps#L1702), because `Fixed Z Reference` defaults to `None`
  so `usesMachineZDatum()` is false. **Confirm rather than assume** — it could instead
  be the range check at [:1887](MPCNC_v4.0_Beta2.cps#L1887), Guard B′ at
  [:1719](MPCNC_v4.0_Beta2.cps#L1719), or the `workOffset == 0` alias.
- **Findings** — **open a row before fixing anything.** A default-configuration refusal
  of a supported F360 feature belongs in the register.
- **Prompt**
  > `[AUTHOR]` reports that an F360 Setup with "Multiple WCS Offsets" ticked (Post
  > Process tab → Number of Instances, WCS Offset Increment) fails to post with this
  > post. I will paste the error text and the failed output.
  >
  > Trace which `error()` produced it. Read `validateJob()` and each guard: Guard B
  > ("A multi-WCS job requires a fixed Z reference"), Guard B′ ("but the first
  > operation's tool cannot probe it"), Guard C ("Marlin has a single coordinate
  > frame"), the work-offset range check, and the `workOffset == 0` → WCS 1 alias. For
  > each, say whether it fires for this job and why.
  >
  > Then: what is the minimum property configuration under which this job posts
  > **today, with no code change**? List the dialog settings. Do not propose code yet —
  > I need to know whether this is reachable before deciding it is a bug.

### 1.2 — Make the homed machine the answer to Guard B

- **Goal** — a homed machine posts a multi-WCS job from a configuration the operator can
  reach without learning the spoilboard subsystem.
- **Why** — three strands meeting:
  1. Guard B's **reasoning is correct** — a multi-WCS traverse needs a frame that
     outlives one WCS.
  2. Its **route is wrong** — satisfying it means finding Group 5, understanding a
     reserved WCS and a probed base, and clearing four more guards. So the default
     configuration of a supported feature is a refusal, and the error names two
     subsystems the operator has never heard of.
  3. **Multi-part work already requires homing**, by the post's own statement at
     [:1669](MPCNC_v4.0_Beta2.cps#L1669): *"repeatable only on a machine with a homed
     X/Y zero."* A homed machine already has a machine frame. This is also how every
     commercial control does it — three of Autodesk's four `safePositionMethod` options
     are machine-frame (`03-f360-and-firmware.md` §3a).
- **Where** — Guard B [:1698-1705](MPCNC_v4.0_Beta2.cps#L1698); `usesMachineZDatum()`
  [:2012](MPCNC_v4.0_Beta2.cps#L2012); `machineHomesXY/Z()`
  [:2019-2026](MPCNC_v4.0_Beta2.cps#L2019); `parseInterPartTravelZ()`
  [:2054](MPCNC_v4.0_Beta2.cps#L2054); the machine-Z branch
  [:1645-1672](MPCNC_v4.0_Beta2.cps#L1645).
- **The change** —
  1. Multi-WCS ⇒ require homed X/Y/Z, `Home at Job Start`, and a travel height. **All
     four properties already exist.**
  2. Traverse emits `G53 G0 Z<travel>` — correct regardless of any WCS's Z0.
  3. Machine does not home ⇒ refuse in **one** sentence naming the real reason:
     *"multi-part work needs a homed machine; post one job per part."*
  4. **Do not delete the spoilboard path here.** Step 2 does that, after this is proven.
- **Done when** — the 1.1 job posts on GRBL with only Group 4 properties set, and the
  traverse is `G53`-framed. **Read the emitted file; do not infer it.**
- **Findings** — closes 1.1's row; re-scopes CR-13, which made Guard B unconditional.

### 1.3 — Post the six `PReview.md` §3.1 jobs

- **Goal** — the 21% stops being unverified.
- **Why** — §3.1: *"needs a job nobody has posted yet… This is the largest untested area
  in the post."* The expected output is **already written** for PB1, PB2, PBV1, PBV2,
  PBV3 and PA1, so this is checking, not designing. `[AUTHOR]` confirms the gap is
  deliberate deferral — professional testing postponed to get Beta3 stable for hobby
  users — which makes this **the step that discharges the deferral**.
- **Where** — `docs/PReview.md` §3.1, now in the tree (0.1).
- **The change** — none to the post unless a row fails. Keep the files beside the
  existing 24 in `Documents/Fusion 360/NC Programs/HB-Tests/`, where the hobby-path
  evidence already lives.
- **Done when** — six posted files exist; every §3.1 row ticked or carrying a finding.
- **Note** — PA1 and PB2 reference `Retract Across Parts`, **deleted by CR-13**. Those
  rows need re-scoping before they can be run; that is itself a §3.1 finding.
- **Prompt**
  > docs/PReview.md §3.1 has six unchecked rows (PB1, PB2, PBV1, PBV2, PBV3, PA1) with
  > expected output already written. I will paste posted output one row at a time.
  >
  > For each: compare emitted output against the row's expectation. Report **only**
  > differences, and for each say whether it is (a) the post being wrong, (b) the
  > expectation being wrong, or (c) an F360 behaviour neither anticipated. Quote the
  > emitted lines.
  >
  > Note that PA1 and PB2 mention `Retract Across Parts`, which CR-13 deleted — flag
  > any row whose expectation predates a change that has already landed.
  >
  > Propose the register rows. Do not propose code until every row is read: several may
  > share one cause.

---

## Step 2 — Retire the spoilboard base

- **Goal** — Group 5 ceases to exist; one property survives, in Group 4.
- **Why** — **the subsystem's premise defeats itself.** It exists to give a
  **non-homing** machine a common Z frame for multi-part traverses. But multi-part
  traverses require homing, by the post's own guard at
  [:1669](MPCNC_v4.0_Beta2.cps#L1669). **No machine both needs it and can use it.**
  Three further reasons: its principal hazard is *"mitigation is documentation, not
  code"* by `design.md`'s own admission; it consumes one of GRBL's six registers; and
  four of the seven open findings live in it.
- **Where**
  | What | Where | ~Lines |
  |---|---|---|
  | `writeBaseEstablish()` | [:2998](MPCNC_v4.0_Beta2.cps#L2998) | ~79 |
  | Reserved-base agreement guards | [:1622-1643](MPCNC_v4.0_Beta2.cps#L1622) | ~22 |
  | Slot check, Guard B′, Guard A | [:1708-1729](MPCNC_v4.0_Beta2.cps#L1708) | ~22 |
  | `baseOriginWriteReason()` | [:1406-1431](MPCNC_v4.0_Beta2.cps#L1406) | ~26 |
  | `getReservedBaseWcs()` | [:2042](MPCNC_v4.0_Beta2.cps#L2042) | ~12 |
  | `fixedZEstablishedAtStart/InFile()` | [:2071-2099](MPCNC_v4.0_Beta2.cps#L2071) | ~28 |
  | 4 of 5 Group 5 properties + descriptions | group at [:117](MPCNC_v4.0_Beta2.cps#L117) | ~90 |
- **The change** — delete the above. **Keep `spoilboardTravelZ`**, rename to
  `machineTravelZ`, move to `groupDefinitions.machine`. `getFixedZReference()`
  [:2005](MPCNC_v4.0_Beta2.cps#L2005) reduces to one branch, so the enum becomes a
  boolean or disappears into *"is there a travel height and is the machine homed?"*.
- **Done when** — ~250–300 lines gone; 10 groups → 9; the Step 1.3 files still post.
  **Re-post at least two of the six** — a deletion under a verified baseline is the only
  kind that can be checked.
- **Findings** — CR-11, CR-12, CR-14 and PR-8 close **by deletion**. Each row must say
  the code was removed rather than repaired. `06-retention.md` already frames this
  correctly: *"that is not lost work, it is work that stops being needed."*
- **Prompt**
  > Assessment/07-code-map.md argues the spoilboard-base subsystem should be deleted:
  > multi-part traverses require a homed machine (see the post's own error text at the
  > `homedXY` check in `validateJob`), while the spoilboard base exists to serve
  > machines that do not home — so no machine both needs it and can use it.
  >
  > **First, try to refute that.** Find any configuration where the spoilboard base is
  > the only workable answer — including single-WCS jobs, jet/laser tools, and any path
  > where `Fixed Z Reference = Spoilboard` changes output without a WCS change. Search
  > every reader of `getFixedZReference`, `usesMachineZDatum`, `getReservedBaseWcs`,
  > `fixedZEstablishedInFile` and `fixedZEstablishedAtStart`. Report before proposing.
  >
  > If it survives, propose the deletion as diffs in reviewable pieces. For each piece
  > list the findings it closes and any behaviour change for a **single-WCS** job —
  > which must be none.

---

## Step 3 — Marlin multi-WCS: delete Guard C, add a version floor

- **Goal** — Marlin users can run multi-WCS jobs, above a stated firmware version.
- **Why** — `05-history.md`. Marlin with `CNC_COORDINATE_SYSTEMS` has **nine** WCS
  registers, individually selectable, **persistent with EEPROM** `[DOC]`. Guard C's
  message — *"Marlin has a single coordinate frame"* — is **a false statement emitted to
  the user**, and `design.md` line 23 is its source. The post already cited the same
  build flag correctly for `G53` forty lines above
  ([:1646-1649](MPCNC_v4.0_Beta2.cps#L1646)); the two facts never met on one page.
- **Where** — Guard C [:1689-1694](MPCNC_v4.0_Beta2.cps#L1689); RepRap-only slot gate
  [:1709-1712](MPCNC_v4.0_Beta2.cps#L1709); write dialect in `writeWCS()`
  [:1860](MPCNC_v4.0_Beta2.cps#L1860); and `probeOnChange`'s description at
  [:416](MPCNC_v4.0_Beta2.cps#L416), which **asserts the false claim to the operator**.
- **The change** —
  1. **Delete Guard C.**
  2. Slot gate becomes "not GRBL" — Marlin has `G59.1`–`G59.3` via `parser.subcode`.
  3. **Keep the write dialect**: `G10 L20 P<n>` on GRBL/RepRap, `G5x` then `G92` on
     Marlin. This is the one real difference — Marlin can only write the **active**
     register, and only positionally. For *selection* there is full parity, and
     selection is all a multi-WCS job needs.
  4. **State a minimum firmware version** `[AUTHOR]`. Two reasons, both needed:
     `CNC_COORDINATE_SYSTEMS` is a **build option**, so a stock Marlin lacks it; and
     `[DOC]` Marlin issue **#14743** reported `G92` inside `G54` corrupting the `G53`
     machine origin — closed, fix version not established from the issue page.
  5. **Record the homing hazard.** `set_axis_is_at_home()` runs
     `position_shift[axis] = 0` (`motion.cpp`), and re-sending `G54` does **not**
     restore it because `select_coordinate_system()` early-returns when that system is
     already active. **On Marlin, homing silently detaches the program from its own work
     origin.** Tier 2 firmware knowledge; `design.md` does not have it.
- **Blocked on** — the version floor. `CLAUDE.md` requires firmware questions settled
  from the firmware's own source and changelog, citing file and version. **Establishing
  which Marlin release fixed #14743 is a prerequisite, not a documentation
  afterthought** — and it is the one question this review could not close.
- **Done when** — a two-WCS Marlin job posts; `design.md` line 23 **rewritten, not
  annotated**; the version floor appears in the property description and
  `guide-hobbyist.md`; the homing hazard is in `design.md`'s firmware table.
- **Findings** — new row for Guard C; new row for the false property description.
- **Prompt**
  > Marlin 2.1.x with `CNC_COORDINATE_SYSTEMS` enabled has nine work coordinate systems:
  > `MAX_COORDINATE_SYSTEMS` = 9 in `Marlin/src/gcode/gcode.h`; `G54`–`G59.3` select
  > them in `G53-G59.cpp`; `G92` writes `coordinate_system[active_coordinate_system]` in
  > `G92.cpp`; the header comment says *"with EEPROM support they may be restored from a
  > previous session"*. V1's MarlinBuilder enables the flag.
  >
  > **Verify all of that against the source yourself before acting on it**, citing file
  > and version per CLAUDE.md.
  >
  > Then: (a) find every place in the post that assumes Marlin is single-frame — Guard
  > C, the RepRap-only WCS slot gate, and any property description asserting it to the
  > operator; (b) determine from Marlin's changelog which release fixed issue #14743
  > (`G92` in `G54` altering the `G53` origin), so a minimum version can be stated;
  > (c) confirm whether `set_axis_is_at_home()` still zeroes `position_shift`, and
  > whether re-selecting the same workspace restores the offset.
  >
  > Report findings first. Then propose diffs for the code and for docs/design.md line
  > 23 — which is the origin of the wrong premise and must be rewritten, not footnoted.

---

## Step 4 — Group 6: keep the touch-off, delete the orchestration

- **Goal** — 10 properties → 9, **14 enum decisions → 9**, and nothing offered that the
  firmware cannot do.
- **Why** — `06-retention.md` carries the property-by-property verdict. Two drivers:
  1. **Four of ten enum options do not work on the default firmware.** The post says so
     itself at [:399](MPCNC_v4.0_Beta2.cps#L399): *"THE TWO JOG MODES DO NOT WORK ON
     GRBL, the default firmware."* Two on `probeOnStart`, two on `probeOnChange`,
     protected only by a warning.
  2. **`probeOnChange` is the orchestration**, which `[AUTHOR]` assigns to the operator
     — and after Steps 2 and 3 the question it asks does not arise: select `G55`, and
     the register the operator already set is right.
- **Where** — `probeOnStart` [:397-413](MPCNC_v4.0_Beta2.cps#L397); `probeOnChange`
  [:414+](MPCNC_v4.0_Beta2.cps#L414); `writeWcsOnStart()`
  [:3145](MPCNC_v4.0_Beta2.cps#L3145); `partProbe()`
  [:3100](MPCNC_v4.0_Beta2.cps#L3100); `writeWCS()`
  [:1860](MPCNC_v4.0_Beta2.cps#L1860).
- **The change** —
  1. `probeOnStart`: **six modes → three.** Keep `Current XY & Probe Z` (default),
     `Current XYZ`, `Probe Z`. **Merge** `Skip` into `Probe Z` as a boolean — they
     differ only in whether Z is probed. **Delete both Jog modes.**
  2. **Delete `probeOnChange`.** Replace with at most one boolean — *"re-probe Z at each
     WCS change"*, default off — for the operator whose parts differ in height.
  3. **Retitle the group.** *"On WCS / Part / Fixture Changes"* says when it fires; it
     should say what the operator is deciding — the work origin. *(A title change does
     not reset settings; a key change does.)*
  4. **Shorten the descriptions.** `probeOnStart`'s is ~1,900 characters, so the GRBL
     warning buried inside it is not read. Three modes is what makes it short enough to
     work.
- **Keep untouched** — `probePause`, `probeOffsetX/Y`, `probeG382orG28`,
  `probeG38Target`, `probeG38Speed`, `probeSafeZ`, `probeThickness`. These are the Z
  touch-off mechanics, they answer to S1, and **every one is confirmed by emitted
  output** (`G38.2 F30 Z-10`, `G10 L20 P1 Z0.8`, `M0 (MSG Attach ZProbe)`). Best-evidenced
  block in the post.
- **Done when** — no offered option is non-functional on any supported firmware, and the
  24 hobby files in `HB-Tests/` re-post **byte-identically** for the surviving modes.
- **Findings** — new row for the non-functional options; PR-11 re-scoped.
- **Prompt**
  > In MPCNC_v4.0_Beta2.cps, `probeOnStart` ("First WCS / Part") offers six enum modes
  > and `probeOnChange` ("Subsequent WCS / Part") offers four. `probeOnStart`'s own
  > description says the two Jog modes do not work on GRBL, the default firmware.
  >
  > Establish the facts first: for each of the ten options, which firmwares can actually
  > execute it, and what does the post emit? Quote the emitting code. Settle whether a
  > genuine jog-at-pause exists on GRBL and on Marlin **from firmware source**, not from
  > the post's own comments.
  >
  > Then propose, as separate diffs: (a) `probeOnStart` reduced to three modes, merging
  > the stored-XY-with/without-probe pair into one mode plus a boolean; (b) deleting
  > `probeOnChange`, since Assessment/04-user-stories.md assigns multi-part orchestration
  > to the operator; (c) a group retitle without a key change.
  >
  > For each, list which files in `Documents/Fusion 360/NC Programs/HB-Tests/` would
  > change output. The answer should be none — tell me if it isn't.

---

## Step 5 — Group 7: split it, and build 7b on include files

Independent of Steps 1–4; can run in parallel. **`[AUTHOR]`: this group has not been
reviewed or tested.** Eight properties, ~65 lines, five open findings, and **zero posted
files exercising a tool change** — none of the 24 has more than one tool.

### 5.1 — 7a: *"end this file so a manual tool change costs nothing"*

Personal licence, answering **S3** and **S13**. Five rules, four of them removals:

1. **It is an option, not a policy** — S3 as corrected: *"the **option** for a posted
   file to end…"*. The last file of a sequence carries no tool-change scaffolding.
2. **Never home at end-of-file on Marlin.** Homing zeroes `position_shift` and
   re-selecting `G54` does not restore it, so **homing detaches the next file from the
   origin this one established.** The single concrete safety rule to come out of S13.
3. **`toolChangeDisableZStepper` already gone** — Step 0.2.
4. **Fix the frame of the park position.** `toolChangeX/Y/Z` emit plain `G0` words and
   are therefore WCS-relative; the post's own comment at
   [:3657-3658](MPCNC_v4.0_Beta2.cps#L3657) says *"the spot drifts"*. Either emit `G53`
   and require homing, or rename the fields to say they are work-frame. **Not both
   meanings on one field** — PR-4, open.
5. **Leave the work origin untouched.** No `G10 L20`, no `G92`, at end of file. That is
   the whole point of 7a.

### 5.2 — 7b: mid-program tool change, driven by F360

**`[AUTHOR]`, and this was the gap in my previous answer:** *"someone is making the
actual tool change happen and remeasuring the tool length… on these firmwares there is
no such support, or at a minimum there must be the inclusion of gcode files that do that
operation."*

**Completing it.** A measured tool change needs a probe, a **subtraction**, and a
register to hold the result. The firmwares split on the subtraction
(`03-f360-and-firmware.md` §5a):

| | Probe | Arithmetic | TLO register | So who does it |
|---|---|---|---|---|
| **RepRapFirmware** | `G38.2` | **Yes** — meta G-code | `G10 L1 P<t> Z`, persisted by `M500 P10` | **The machine**, via a `tpost` macro |
| **GRBL / FluidNC** | `G38.2` | **No** — no variables, no expressions | `G43.1 Z<offset>` needs a literal | **The sender's** tool-change macro |
| **Marlin** | `G38.2`\* | **No** | **none exists** | **The operator** — re-probe, re-zero work Z |

So `design.md`'s bare *"no TLO"* is too strong — GRBL has `G43.1`, RepRap has a real
tool table — **and none of the three answers is the post.** The post cannot compute an
offset it will not learn until the operator swaps the tool, hours after posting.

**Therefore 7b's deliverable is a contract, not a routine:**

1. **A stop in a known place, in a stated frame** — `M0`, at a position the operator
   chose, frame documented per 5.1 rule 4.
2. **A named include-file hook at exactly that point.** Group 8 already implements
   include files, is 36 lines, and is verified in the posted files —
   `HB-12(A).gcode.failed` even shows the empty-file abort working. **The mechanism
   exists.** The operator drops in their RRF macro call, sender trigger, or
   probe-and-rezero sequence. One feature, correct on all three firmwares, because the
   part only the operator can know is supplied by the operator.
3. **A written contract for that file** — which frame is active, where the tool is, what
   the file may change, what it must restore. Without this the hook is a trapdoor.
4. **Fix the WCS bug first, on its own.** `probeTool()` *"writes into the PREVIOUS
   section's WCS"* — the post's own comment at
   [:3691-3692](MPCNC_v4.0_Beta2.cps#L3691). A probe result in the wrong register is a
   crash on the next plunge. A bug, not a design question.

\* Marlin's `G38.2` needs its own build flag — same minimum-version statement as Step 3.

### 5.3 — Close the five findings against the split

PR-4, HR-7 (`toolChange()` clobbers `forceSectionToStartWithRapid`), HR-8 (post-injected
motion never updates F360's tracked position), HR-9 (`Do First Change` with
probe-after-change off zeroes Z against the wrong tool), HR-13. With 7a and 7b
separated each becomes a small change in **one** path rather than a change to shared
code — which is why the split comes first.

- **Done when** — a **posted two-tool job** exists. The acceptance test is emitted
  output, not a code review.
- **Prompt**
  > Group 7 of MPCNC_v4.0_Beta2.cps is two features sharing one 65-line `toolChange()`:
  > (a) end-of-file, leave the machine tool-changeable — personal licence, where F360
  > emits no tool change at all; (b) mid-program, driven by F360's
  > `tool.manualToolChange` — professional. Five open findings live in the overlap
  > (PR-4, HR-7, HR-8, HR-9, HR-13).
  >
  > Map it first: for each of the 8 `toolChange*` properties and each branch of
  > `toolChange()` and `probeTool()`, say which feature it serves, or both. Quote the
  > code. Identify every place the two share state.
  >
  > Then propose the split as a sequence of diffs. Constraints:
  > – (a) must be optional; must not home on Marlin (homing zeroes `position_shift`, and
  >   re-selecting the same workspace does not restore it); must not write the work
  >   origin.
  > – (b) must not attempt to compute a tool length — GRBL and Marlin have no
  >   arithmetic. It emits a stop plus a named include-file hook reusing Group 8, with a
  >   written contract for what that file may assume and must restore.
  > – `probeTool()` writing into the previous section's WCS is a bug: fix it as its own
  >   commit, **first**, before any restructuring.
  >
  > For each diff, name the finding rows it closes.

---

## Step 6 — Clarity

Only after 1–5, because they delete much of what would otherwise be tidied.

- `validateJob()` is **288 lines** at [:1448](MPCNC_v4.0_Beta2.cps#L1448). Step 2
  removes ~44 and Step 3 ~6. **Re-measure before restructuring** — it may not need it.
- The property block is **795 lines, 21% of the file.** Steps 2 and 4 remove ~150 of
  description alone. Re-measure.
- **634 comment-only lines: leave them.** `b7d12fb` already trimmed the commentary, and
  this review depended on those comments repeatedly — the Guard C / `G53` contradiction,
  *"the spot drifts"*, *"writes into the PREVIOUS section's WCS"*, the `M84` hazard note,
  *"THE TWO JOG MODES DO NOT WORK ON GRBL"*. **Every one of the sharpest findings here
  came out of a comment the post wrote about itself.** That is an argument for keeping
  them.

---

## Step 7 — Documents, once

`CLAUDE.md` puts the guides off-limits during code changes. Do it all here — per-step
means rewriting `guide-pro.md` three times.

| Document | What falls due |
|---|---|
| `docs/design.md` | **Line 23 rewritten** — Marlin has nine registers. **Add** the Marlin homing/`position_shift` hazard, the minimum firmware version, the corrected TLO table, and what Step 1.3 emitted. **Remove** the spoilboard-base sections. The only document where a wrong row is expensive: it is the project's most valuable asset and it is where Guard C came from |
| `docs/property-reference.md` | Regenerate. 72 → ~60 properties; Groups 5 and 11 gone; Group 6 retitled. Marker reads `@ 17a20f2` and is **19 commits stale before this plan starts** |
| `docs/guide-pro.md` | State the **operator's** obligations explicitly — every work offset set before the job, one clearance clearing every fixture, machine homed. `04-user-stories.md` shows this is the assumption the G-code depends on and that F360 nowhere states it. And say plainly what is verified and what is not |
| `docs/guide-hobbyist.md` | Group 7a's end-of-file behaviour in its own right; the Marlin do-not-home rule; the minimum Marlin version |
| `README.md` | Feature list and the hobbyist/professional split |
| `docs/PReview.md` | §3.1 ticked; findings resolved. Then consider the register consolidation in `10-project-cleanup.md` — **after** this step |

---

## Preserve list — must survive whatever else happens

- **Nine verified bug fixes:** `5a6a4e0` (GRBL `%` wrapper), `b84f602` (feedrate leak),
  `b61c005` (missing include refused), `cb1c9f2` (drag before offset probe), `ec5af37`
  (homing that homes nothing), `ae0e013` (plane modal escaping an include), `eea70d1`
  (Safe-Z separator), `1c5fcce` (`>>> WARNING:` at Comment Level Off), `e5db625`
  (unparseable Safe Z).
- **The firmware knowledge in full** — `174c4df`, `2b5dfd5`, and every sourced fact in
  `design.md`'s tables **except line 23**. Cannot be re-derived from F360.
- **`writeMachineHoming()`**, the `workOffset 0` → WCS 1 alias, the `>>> WARNING:`
  channel, the seventeen dialog-simplification commits, Group 8 entire.
- **Group 6's touch-off mechanics** — the best-evidenced block in the post.
- **Tier 3 revised:** CR-11, CR-12, CR-14 and PR-8 are **superseded by Step 2's
  deletion**, not preserved. `06-retention.md`'s framing holds — *"not lost work, work
  that stops being needed."* CR-13 and `556a378` survive.

## Delete list

| What | ~Lines | Risk |
|---|---|---|
| Spoilboard base subsystem (Step 2) | ~250–300 | Medium — gated on Step 1 |
| `probeOnChange` + 4 Jog modes (Step 4) | ~100 | Low |
| `toolChangeDisableZStepper` + `M84 Z` | ~12 | None — it is a hazard |
| Guard C | ~6 | Low — it blocks supported behaviour |
| Group 11 folded | ~20 | Very low |
| Group 10 coolant surplus | ~50 | Low — pending persona |
| `parkCanRetract()` alias | ~4 | Very low |

**~450–500 lines.** Four times the previous version's figure, and it comes from three
decisions rather than a campaign to shrink the file.

## Blocked list

| Blocked | Waiting on | What it changes |
|---|---|---|
| **Steps 2 and 4** | **Step 1.1 + 1.2** | Whether the homed path actually posts |
| **Step 3's version floor** | Marlin changelog for #14743 | Whether Marlin multi-WCS can be claimed at all |
| Step 5's verification | a full-licence posted two-tool file | 7b cannot be checked without one |
| §3.1 rows PA1, PB2 | re-scoping against CR-13 | Their expectations predate a landed change |
| Group 10 reduction | a coolant persona | ~50 lines |
| Group 9 audit | laser detail — power scaling, `M3`/`M4` dynamic power, enable sequencing, air assist | Whether 7 properties is right. **Persona confirmed but unexercised by any test** |

---

## The three questions, answered plainly

### Group 6 — was the instinct right?

**Yes, and more specifically than either of my first two answers.**

My first reading was that the post reaches into F360's job. **Wrong** — F360 never
learns where the fixtures are, so it cannot compute a path between work offsets and does
not claim to. *(I originally reached this by quoting `design.md`, which was the wrong
method — it is under audit. The conclusion survives on Autodesk's machine-definition
files instead: `03-f360-and-firmware.md` §1a.)*

My second reading was that the machinery serves a user who does not exist. **Wrong** —
the author confirms the user, and F360 has a feature for them.

**What is actually true is narrower and worse:** the machinery serves a real user by a
route that user cannot take. F360's "Multiple WCS Offsets" job **does not post at all**
in the default configuration, and the subsystem built to make it safe — the spoilboard
base — exists for machines that cannot home, while the workflow requires homing. So:

> **Not over-built in general. Over-built in one place, for a machine that cannot use
> the feature — and under-verified everywhere else, by a deliberate deferral nothing
> in the repository states.**

The remedy is Step 1 (unblock), Step 2 (delete the part with no user), and Step 1.3
(post the six jobs). Roughly 300 lines out and the seven findings closed.

### Group 7b — how does a full-licence tool change actually work, end to end?

The operator assigns a tool per operation in F360. Where consecutive operations differ,
the CAM engine flags the boundary and, for tools marked manual, sets
**`tool.manualToolChange`** on the tool object handed to the post. **The post is told;
it detects nothing.** Autodesk's whole response is three lines — stop, comment naming
the tool, resume — wrapped in a Z retract, coolant off, cancel length compensation.

This post never reads the flag; on the professional path it asks the same question again
through `toolChangeInsertCode`, and its own comments admit the result parks in a frame
that drifts and probes *"into the PREVIOUS section's WCS."*

**Two corrections to my own earlier answers.**

*First:* I recommended reading the flag and deleting the duplicate control. On a personal
seat **F360 never emits a tool change at all**, so there is no flag — that change would
have broken the hobby path. Two features sharing a function, not one feature with a
switch. **Split them.**

*Second, and this was the incomplete half:* **somebody has to physically change the tool
and re-establish its length, and on these firmwares nothing does that for free.** The
complete answer is the table in 5.2 — the machine can do it on RepRap, the sender must
on GRBL, and only the operator can on Marlin, because Marlin has no TLO register at all
and neither GRBL nor Marlin can do arithmetic. **So the post's deliverable is a stop, a
named include-file hook, and a written contract** — one mechanism that is correct on all
three, because the piece only the operator knows is supplied by the operator. Group 8
already provides the machinery.

### Clearance and Z-trust — is computing a safe height the post's job?

**No, and Autodesk agrees in code.** Unchanged by anything in this round, and now with
better evidence behind it.

"Z untrusted" means the controller was never told where its own frame is, so an absolute
machine height is not approximately right — it is arbitrary. A relative lift is always
**exact**; only its *sufficiency* is unknown. That is the sharper form of S8, and it is
why a warning is the correct response and an error is not: erroring would refuse the
project's founding user, the hand-zeroed hobbyist, who is 24 of the 24 posted files.

When Autodesk's own post is in this situation it emits *"Ensure the clearance height will
clear the part and or fixtures. Raise the Z-axis to a safe height before starting the
program."* A warning and a comment. Nothing else.

**And the new evidence strengthens it.** F360 has a machine-frame safe-Z slot —
`getRetractPlane()` — and **no way for an operator to fill it**: zero occurrences in 211
machine definitions, `setRetractPlane` commented out in all 159 posts that mention it.
So the post asking for a travel height is **filling a hole, not duplicating a field**,
and non-goal N3 is withdrawn.

**The mechanism already exists** — the `>>> WARNING:` channel that bypasses Comment
Level, visible working in `HB-9(A).gcode` and `HB-13(A)-off.gcode`. Extend it; do not
replace it with arithmetic. The legitimate exception stays: where the program **itself**
homed, the frame is known for the rest of that program and an absolute retract is honest
— a condition the post can verify, because it emitted the homing command.
