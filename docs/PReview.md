# PReview — professional-workflow review of `MPCNC_v4.0_Beta2.cps`

> **The professional review has not been done.** This file is a **parking lot**, not a review.
> Everything in it arrived incidentally: findings the hobbyist review (`docs/HReview.md`) turned up
> while walking code it then judged out of its own scope, and the professional half of the Beta-2
> test plan, which this file absorbed. A real professional pass — the same method HReview used, from
> the professional's chair, walking every multi-WCS / multi-fixture / tool-change path — is still
> owed, and will add findings this file does not have.
>
> **Almost nothing here is committed code.** Every finding below is unimplemented and its diffs are
> proposals rather than records — with one exception, **HR-20**, whose manual-spindle half was
> part-fixed on 2026-07-31 alongside `HReview.md` HR-12.

**Standing rule** for updating this register — add the Do→Get row in the same commit, retire the long
form on close — is `CLAUDE.md` → *Registers ship with the code*, and `/close-finding` runs it.
**How rows are verified** is `conventions.md` → *How to run a test*, which also fixes the defaults every
row below is a delta from.

---

## 1. Scope — what "professional" means here

The professional persona has the full Fusion licence and a real fixture setup. In post terms that is
everything the README puts outside the hobbyist's reach:

| Area | Controls |
|---|---|
| Multiple WCS / multiple parts | `Subsequent WCS / Part`, Replicate jobs, the `Jog to …` per-part modes |
| The machine frame | group `4 - Machine Frame` (all four properties) — declarations plus the homing action |
| The fixed Z reference | group `5 - Fixed Z Reference` (all six properties) — the spoilboard base and the machine-Z datum |
| Cross-part clearance | `Retract Across Parts`, `Inter Part Travel Z` |
| Pre-set fixture offsets | both `Use Active WCS …` origin modes |
| Tool changes | group `7 - Tool Changes` (all eight properties) |
| Manual NC | *Optional stop*, *Display message*, *Orientate spindle* |
| Machining Extension | probing / Inspection strategies |

> **Scope decision (2026-07-31) — tool changes are a professional feature.** Fusion's Personal
> licence does not support tool changes, and Manual NC is treated the same way, so neither belongs
> in a review written from the hobbyist's chair. This is why the findings below carry `HR-` ids: they
> were found by the hobbyist pass and reclassified, and the ids are **kept deliberately** so the
> commit history, `HReview.md` and this file all still refer to the same defect by the same name.
> **Tapping was added to this scope on the same day** — drilling must work, tapping may error or warn,
> and a fuller tapping implementation is professional-review work (HR-20). Refusing tapping outright
> was rejected: someone will make that path work.

---

## 2. Findings

**✅ 10 fixed · ◑ 1 part-fixed · ⬜ 6 open — 17 findings.** The `HR-` ids were found by the hobbyist pass
and reclassified as professional, and are **kept deliberately** so commit history, `HReview.md` and this
file all name the same defect the same way; `PR-` ids were found by this file's own machine-frame review.
Only the ten `PR-` fixes are committed code — every `HR-` diff below is a proposal, not a record.
**PR-8 … PR-11 are defects in PR-2 / PR-6's own landed code**, found by a review of the branch before it
was ever posted, and they are separate ids rather than clauses on PR-6 because commit messages cite ids
and a `✅ fixed` row must not quietly cover a second fix.

| ID | Finding | Sev | Resolution | Status |
|---|---|---|---|---|
| **PR-1** | Group 4 collected an **action** (`Home Before Start` = None/XY/XYZ) where every consumer needs a **capability**. The post emitted `G28 Z` for `XYZ` and discarded the fact that the machine *has* a homed Z — then asked that same operator to reserve a WCS register and probe a spoilboard to reconstruct the datum homing had already given them | Med-High | Split into `X/Y Home` · `Machine Z Home` (declarations) + `Home at Job Start` (the action), which also expresses a state the enum could not: *homed at the controller, do not home here*. Two new warnings read the declarations — stored-offset-without-homed-XY, and CR-2 reworded as advice. **Key replaced, so the old setting resets** — a release-notes item. **The two booleans were themselves consolidated into one enum by PR-5**; the capability/action split this finding is about is unchanged | ✅ fixed |
| **PR-2** | A reserved spoilboard base and a homed machine Z are **two implementations of one frame**, but only the first was exposed — so Guard B *rejected* multi-WCS jobs on machines whose homed Z would have served, and charged the rest one of GRBL's six WCS registers | Med-High | `Fixed Z Reference` = `None` / `Spoilboard` / `Machine Z`, with `Travel Machine Z` (one absolute machine height, no touch-off, no arithmetic) emitted as `G53 G0 Z<n>`. Guard B relaxed to *a* datum of either kind. Resolves the standing **"Never `G53`"** decision — §6. Also lifts a hard limit: the first section's arrival now emits a real absolute Z instead of `Unknown Z for XY move.` where a machine Z is declared. **`Travel Machine Z` was merged into `Inter Part Travel Z` by PR-5**; the two-implementations model is unchanged | ✅ fixed |
| **PR-3** | `Probe to Set Base = None` stated a precondition it did not have — *"assume a prior job set it"*, where a controller reset or power cycle on a machine with no Z home invalidated that base Z0 **silently** and the tool then descended to a clearance wrong by however far machine zero drifted | Medium | **Option eliminated** (E1). Its one durable use — a machine that homes Z — has a strictly better answer under PR-2: no register consumed, no probe, and it cannot go stale the same way because the job homes. **Removing an enum id resets the property** — a release-notes item | ✅ fixed |
| **PR-4** | `Tool Change Z` is measured in *whichever WCS happens to be active*, so the physical park point silently drifts per workpiece — flagged in the post's own source as *"likely a bug, not intended behavior"* | Medium | **Deliberately not landed here.** The `G53` branch it needs is now sanctioned by PR-2's decision, but it shares code with §2's Phase 4 reorder and must compose with that design rather than pre-empt it. The code comment now records the settled decision instead of asking for one | ⬜ open |
| **PR-5** | The machine-frame rework left the dialog asking **two questions per concept**: group 4 posed one machine's homing as two independent booleans, and group 5 carried two clearance fields that `Fixed Z Reference` made **mutually exclusive** — never both read, read at the same two moments, and naming the same physical plane | Medium | Group 4 → `Axises Homed and Trusted` (`None`/`XY Only`/`Z Only`/`XYZ`), information-identical to the booleans, read only through `machineHomesXY()`/`machineHomesZ()`. Group 5 → one `Inter Part Travel Z` whose frame follows `Fixed Z Reference`. **The merge forces the empty default**: with a live default, flipping the enum would emit a valid-looking height in the wrong frame under no guard. Two new spoilboard guards (unset, and `<= 0` — the detectable direction of the flip) and a frame-naming header echo carry the residual risk. 71 → 70 properties. **Three keys replaced, so all three settings reset** — a release-notes item | ✅ fixed |
| **PR-6** | `At End Go to 0,0` never said **which** X0 Y0, and it is the **last section's WCS** — so on a multi-part job the tool parks at whichever fixture Fusion happened to order last, and re-ordering operations silently moves the park point. Same species as PR-4's `Tool Change Z` | Medium | Enum `Off` / `Work X0 Y0` / `Machine X0 Y0`, default `Work` (today's behaviour, now named). The machine answer is **firmware-split, not firmware-excluded**: `G53 G0 X0 Y0` on GRBL/RepRap, `G28 X Y` on Marlin — which re-establishes the frame instead of addressing it, so it needs neither `CNC_COORDINATE_SYSTEMS` nor `Home at Job Start`. Guard requires X/Y declared on every firmware, and `Home at Job Start` on GRBL/RepRap only. Retracts before parking when a fixed Z reference exists, closing **HR-16**'s Z half for this path. **boolean→enum resets the setting, and asymmetrically — anyone who had it OFF gets the move back ON**. Relocated to group 4 and rekeyed by **PR-7** | ✅ fixed |
| **PR-7** | Group 4 still asked **two questions about one homing decision** — `Home at Job Start` plus `Prompt Before Home`, the second **inert whenever the first was off** and saying so in its own tooltip: four dialog settings, three distinct behaviours. And PR-6's new park sat in group 1 while being guarded by group 4 | Medium | One enum, `Home at Job Start` = `Off` / `Home` / `Pause, then Home`, read only through `homesAtJobStart()` / `promptsBeforeHome()`. **Unlike PR-5's axis merge this is not information-preserving — it deletes the meaningless state**, which is the stronger reason to merge and the one PR-5 could not claim. `At End Park At` moved to group 4 and its key renamed `machineParkAtEnd` so the prefix matches the group, per this file's own key convention. Group 4 is now declaration / action / park; group 1 loses a control. **Both key changes reset those settings**, and the homing one resets to `Off` — the inert direction, deliberately: the reverse would add unexpected motion to a job that never asked for it | ✅ fixed |
| **PR-8** | PR-6's park asked *is a base reserved?* where it needed *was a fixed Z reference **established**?*, and the two differ on Marlin. A Marlin job with `Fixed Z Reference = Spoilboard` + `At End Park At = Machine` passes every guard — the park's own guard sits **above** Guard C's Marlin return, the base's RepRap-slot check **below** it — and then transits a base `writeBaseEstablish()` refused to write, emitting `G55` / `G0 Z40` / `G54` on a firmware where `G54`–`G59` is itself a build option, and `Gundefined` for a `G59.1`–`G59.3` base. The same test also let the **no-fixed-reference** job park in silence: a full-diagonal bed crossing at the last operation's finishing Z, while `onClose()`'s comment asserted the opposite | Med-High | One predicate, `parkCanRetract()` = *not Marlin* **and** `fixedZEstablishedAtStart()`, read by the emission and by a new post-time `warning()` so the two cannot drift. When it is false the park now says so in the file rather than retracting into a frame that does not exist — the honest statement of `HReview.md` **HR-16** reached down a second path, not a fix for it. `onClose()`'s comment corrected | ✅ fixed |
| **PR-9** | PR-6's `G53 G0 X0 Y0` park block carries **no `F` word**, alone among the post's rapids — `rapidMovementsXY`/`Z` and its own sibling `writeMachineTravelZ()` all emit one. On firmware that honours the modal feedrate for `G0`, the longest move in the job crosses the bed at whatever feed the last **cut** commanded | Medium | `fFormat` (not `fOutput` — `resetAll()` has just cleared the tracked `F`) at `Travel Speed XY`, matching `writeMachineTravelZ()` exactly | ✅ fixed |
| **PR-10** | PR-2 made the preamble **move the tool** — step 5 establishes the fixed Z reference, step 6 records the first part's origin — so under **both** implementations the "current position" step 6 reads is bed clearance. `Set X0 Y0 to Current Pos, Probe Z0` (the **default**) then writes HR-1's provisional `Z0` there, turning `G38 Target -10` into a 10 mm descent from bed clearance: the probe never reaches the stock and the controller alarms. `Set X0 Y0 Z0 to Current Pos` fails quieter and worse — clearance *becomes* the part's `Z0`. The spoilboard half predates PR-2; the machine-Z answer is a second route to it, and none of PR-2's six guards covers either | Med-High | Post-time `warning()` naming the establish as the cause and the two sound modes as the answer. **Not a code fix, and cannot be one:** the distance from clearance to the stock top is exactly what the probe exists to discover. The `Jog to …` modes are deliberately exempt — there the operator positions the tool *after* the establish, which is the condition HR-1's provisional `Z0` was sound under all along | ✅ fixed |
| **PR-11** | HR-28's post-time GRBL jog warning tests `Subsequent WCS / Part` unconditionally, but that control is consulted only on a genuine WCS change (`writeWCS()`'s `isTraverse`) — so a **single-WCS** job warns about a pause its file will not contain. Its neighbour, the stored-offset warning, already carried the gate | Low-Med | `multiWcs` hoisted to one local and applied to the subsequent-part half only. The first-part half stays ungated: that mode runs on every job | ✅ fixed |
| **HR-7** | `toolChange()` clobbers `forceSectionToStartWithRapid`, defeating "First G1 → G0" on every tool-change section | Medium | Lands with the Phase 4 reorder below | ⬜ open |
| **HR-8** | Post-injected motion never updates Fusion's tracked position | Medium | Lands with Phase 4. Confirmed unreachable on any hobbyist path (2026-08-01) | ⬜ open |
| **HR-9** | `Do First Change` with `Probe After Tool Change` off zeroes Z against the wrong tool | Medium | Lands with Phase 4 | ⬜ open |
| **HR-10** | `Disable Z Stepper` emits Marlin-only `M84 Z` on GRBL | Medium | **Complete diff, independent of the reorder** — can go first as a warm-up commit | ⬜ open |
| **HR-13** | `onCommand` silently discards every command it does not name | Low-Med | **Complete diff, independent of the reorder** — can go first as a warm-up commit | ⬜ open |
| **HR-20** | Tapping is not really implemented | Medium | Manual path prompts (via HR-12); the automatic path always emitted `M4`. **Not tool-change work and does not wait for Phase 4** — it is here only because tapping was *decided* to be professional | ◑ part-fixed |

The five tool-change findings — HR-7, HR-8, HR-9, HR-10, HR-13 — land **as one unit** with the ordering
rework below, rather than patching the same section-boundary code twice. HR-10 and HR-13 are the
exception that can go first, being independent of the reorder.

#### Phase 4 — tool-change ordering + base-relative park *(design settled; not built)*

**This is the Tool Change branch's work.** Tool changes are a professional feature — the Fusion Personal
licence does not support them — so this rework and the five findings below land together on a separate
branch.

Root cause: in `onSection()`, `toolChange()` runs **before** `writeWCS(currentSection)` for non-first
sections, so a boundary that is both a tool change and a WCS change **re-probes into the wrong WCS**
(`toolChange()`'s re-probe writes `G10 L20` into `currentWorkOffset`, still the *previous* part's WCS) and
**parks in the wrong frame**.

Fix — reorder so the WCS is resolved before the tool-change re-probe, and coordinate the two so a combined
boundary does each thing once:

1. Run `writeWCS()` first — it owns the base retract and the frame switch. When a tool change on the same
   section will re-probe, have `writeWCS()` **skip its own `probeOnChange` probe** and let the
   tool-change flow own the single re-probe, now into the correct WCS.
2. The tool-change re-probe **repositions to the new part's `X0 Y0`** before measuring (the same fix
   already applied to the added-part probe), so it reads the stock top and not the park point.
3. **Park position — two branches decided, and a third now sanctioned:** base reserved → park relative to
   the base (a fixed physical spot for the whole job), reusing the transit-select machinery; no base →
   plain `G0` in the current WCS, as today. Current code implements only the no-base branch. **The blanket
   "Never `G53`" that used to close this list is superseded** — see PR-4: with `Axises Homed and
   Trusted` = `XYZ` there is a third branch, `G53 G0 Z<n>` then `G53 G0 X<n> Y<n>`, two blocks and
   retract-first because `G53` is not modal and a three-axis `G53` would be the diagonal this post splits
   its rapids to avoid. The two existing branches stand unchanged for machines that declare nothing, and
   **the third lands with this rework rather than before it** — it is the same code. *(The code comment at
   the park now records exactly this instead of arguing for a decision that has been made.)*

Net at a both-boundary: retract through base → switch WCS → park → swap → rapid to `X0 Y0` → probe once
into the correct WCS. Test matrix in §3.4.

> **HR-12 left this file on 2026-07-31** and is now in `HReview.md`, where it has since been fixed. It was swept in here with the
> other five when HP-5 was redefined, on the reasoning that Personal has no tool changes — true of
> them, false of it: two operations on **one** tool at different RPMs needs no tool change and is HP-5
> exactly. `Drill_Tap.gcode` then observed it firing, and the `Link.gcode` / `Speed Change.gcode` pair
> witnessed it on a one-tool job. Do not re-file it here.

---

### HR-7 — `toolChange()` clobbers `forceSectionToStartWithRapid`, defeating "First G1 → G0" on every tool-change section — **Medium** · `READ`

**Reaches it:** several tools with group 07 enabled *and* group 03 on.

`onSection()` sets `forceSectionToStartWithRapid = true` so the section's first `G1` — which on a
Personal licence *is* the lost positioning rapid — gets converted back. But `toolChange()` reaches
the change position through the post's **own** `onRapid()`, whose first statement clears that flag.
`toolChange()` runs *before* the body's motion, so the conversion never happens — on precisely the
boundary where it matters most, the move from the park position back to the work. The result is a
`G1` at cut feed (and, with `Scale Feedrate` on, at a feed derived from a stale position — HR-8).

Every other post-injected move already avoids this by calling the low-level emitters
(`rapidMovementsXY` / `rapidMovementsZ` / `rapidMovements`) rather than the callback. `toolChange()`
is the only place that routes through `onRapid()`, and the fix is to match:

```diff
@@ function toolChange() {
     flushMotions();
-    onRapid(propertyMmToUnit(getProperty(properties.toolChangeX)), ...);
+    // rapidMovements(), not onRapid(): onRapid() clears forceSectionToStartWithRapid, and this runs
+    // BEFORE the section's body -- so routing through the callback silently disables the
+    // "First G1 -> G0 Rapid" conversion for every section that changes tools.
+    rapidMovements(propertyMmToUnit(getProperty(properties.toolChangeX)), ...);
     flushMotions();
```

**Verify (Do → Get).** *Do:* two operations, two tools, group 07 on with Include Relocation Code,
`First G1 → G0 Rapid` on. *Get:* the `( First G1 --> G0)` comment and a `G0` at the start of section
2's body, after the `Tool Change End` comment. **Pass:** section 2's first motion block is `G0`, not
`G1` — today it is `G1`.

---

### HR-8 — post-injected motion never updates Fusion's tracked position — **Medium** · `READ`

**Reaches it:** every persona, at every section boundary that follows a post-emitted move (probe
retract, tool-change park, WCS-change retract, base clearance).

`setCurrentPosition()` / `setCurrentPositionZ()` appear **nowhere** in the file. The kernel tracks
position from the callbacks it drives; when the post emits its own `G0` through `rapidMovementsZ()`
or `rapidMovementsXY()`, the kernel's model does not move. Three consumers read that model:

1. **`rapidMovements()`** picks Z-then-XY vs XY-then-Z from `_z < getCurrentPosition().z` — the
   ordering the README sells as the reason the G1→G0 conversions are safe (*"retracts before
   travelling and travels before descending"*). When the tracked Z is higher than the physical Z the
   post concludes it is descending and travels **first, at the lower physical height**. Reachable at
   a tool-change boundary: the section ends at a clearance of 40, the park move and re-probe retract
   bring the tool physically to ~5 without the kernel noticing, and the next section's first rapid to
   15 is then ordered XY-first — a full traverse at 5 mm above the stock top.
2. **`isSafeToRapid()`** reads `getCurrentPosition()` for its `zConstant` / `zUp` / `curZSafe` tests,
   so a section's first conversion decision can be made against a stale Z.
3. **`limitFeedByXYZComponents()`** builds its direction vector from `getCurrentPosition()`, so the
   first cut move after injected motion can be scaled along the wrong vector.

Within a section the tracked position is accurate, which is why no single-section job has ever shown
this. It is a boundary defect.

**Re-derived independently and confirmed professional-only (2026-08-01, the `CR-` pass).** The full
hobbyist code review reached this finding from scratch — `setCurrentPosition()` and
`setCurrentPositionZ()` still appear **nowhere** in the file — and then established *why the hobbyist
never sees it*, which is the part this entry was missing and which is what keeps it here rather than
in hobbyist scope:

> On a single-tool, single-WCS job the only post-injected motion before the first section's body is
> the probe retract, and it leaves the tool **higher** than the kernel believes it is. `rapidMovements()`
> chooses its order from `_z < getCurrentPosition().z`, so an under-reported current Z biases the
> decision toward **Z-first** — retract before travel, the safe order. The error is therefore
> self-correcting in the only direction that matters, and only on that path. It stops being
> self-correcting the moment a post move takes the tool *down* without telling the kernel, which is
> exactly the tool-change park in consumer 1 above.

So the diagnosis stands unchanged and so does the recommended fix; what is now settled is that no
hobbyist configuration can reach it, and that the narrow variant (a post-local `lastEmittedZ` feeding
`rapidMovements()`'s ordering decision) would cover every reachable case. **Do not re-file this as a
hobbyist finding** — `HReview.md`'s *Checked and found correct* table records the reasoning above so
a future pass does not re-derive it a third time.

**Recommended fix** — tell the kernel about the post's own moves: `setCurrentPosition(new Vector(_x,
_y, cur.z))` after `rapidMovementsXY()`'s `writeBlock`, and `setCurrentPositionZ(_z)` after
`rapidMovementsZ()`'s.

**Caveat — this one wants a posted file before it lands.** `setCurrentPosition()` inside a section
could interact with the kernel's own bookkeeping for the following section. Safe sequencing: apply
it, re-post the passing single-section references and diff **motion only**. If any move, prefer the
narrow variant — track a post-local `lastEmittedZ` and have `rapidMovements()` consult
`max(getCurrentPosition().z, lastEmittedZ)` for its ordering decision, which fixes the
collision-relevant half with no kernel interaction at all.

**Verify (Do → Get).** *Do:* two ops, two tools, group 07 with Include Relocation Code and
`Tool Change Z = 40`, second operation's clearance 15. *Get:* section 2's opening rapid pair is
`G0 Z15` **then** `G0 X… Y…`. **Pass:** the Z block precedes the XY block — today the order inverts.

---

### HR-9 — `Do First Change` with `Probe After Tool Change` off zeroes Z against the wrong tool — **Medium** · `READ`

**Reaches it:** group 07 enabled with `Do First Change` on — the natural choice for "the spindle is
empty, load tool 1 for me" — while `Probe After Tool Change` is left at its default **off**.

The order inside `onSection()` is fixed: `writeFirstSection()` runs before the tool-change block. So
for the first section: `writeWcsOnStart()` probes and writes `G10 L20 P1 Z0.8` **with whatever tool
is in the spindle** — which by the premise of `Do First Change` is not the job's tool; then
`toolChange()` parks, prompts, and the operator installs tool 1, a different length; and with
`Probe After Tool Change` **off** nothing re-references Z. Every cut runs at
`(actual tool length − probe tool length)` off nominal, with nothing in the file saying so.

With `Probe After Tool Change` **on** the second probe corrects it, so that combination is merely
wasteful (two attach/detach prompt pairs).

**Recommended fix.** The ordering change is the real answer but touches the Phase-4 tool-change
rework. Pending that, `warning()` at post time from `validateJob()` when
`toolChangeEnabled && toolChangeDoFirstChange && !toolChangeProbeAfterChange`, naming both
controls by their exact dialog titles and offering the two fixes (enable the re-probe, or set the
origin manually).

**Verify (Do → Get).** *Do:* group 07 on, `Do First Change` on, `Probe After Tool Change` off.
*Get:* Fusion shows the warning and the file still posts. **Pass:** the warning names both controls
by their exact dialog titles. Second post with the re-probe **on**: no warning, two `G38.2` blocks.

---

### HR-10 — `Disable Z Stepper` emits Marlin-only `M84 Z` on GRBL — **Medium** · `READ`

**Reaches it:** GRBL, group 07 enabled with `Disable Z Stepper` on — a reasonable choice on a
machine whose Z drifts under a heavy spindle.

```js
if (getProperty(properties.toolChangeDisableZStepper)) {
  askUser("Z stepper will disable; wait for full stop", "Tool change", false);
  writeBlock(mFormat.format(84), 'Z');
}
```

No firmware guard. `M84` does not exist in GRBL — the controller answers `error:20` and most senders
**halt the program mid-tool-change**. `Start()` already puts its own `M84 S0` inside the non-GRBL
branch, so the command is already known to be Marlin-family-only elsewhere in this file.

```diff
     if (getProperty(properties.toolChangeDisableZStepper)) {
-      askUser("Z stepper will disable; wait for full stop", "Tool change", false);
-      writeBlock(mFormat.format(84), 'Z');
+      // M84 is Marlin-family only -- GRBL answers error:20 and most senders halt the program
+      // mid-tool-change. Start() already scopes its own M84 S0 the same way.
+      if (fw == eFirmware.GRBL) {
+        writeComment(eComment.Important, " >>> WARNING: \"Disable Z Stepper\" ignored on GRBL -- M84 is not a GRBL command");
+      } else {
+        askUser("Z stepper will disable; wait for full stop", "Tool change", false);
+        writeBlock(mFormat.format(84), 'Z');
+      }
     }
```

**Verify (Do → Get).** *Do:* GRBL, group 07 on, `Disable Z Stepper` on. *Get:* the warning comment
and **no `M84`** anywhere. **Pass:** absence of `M84`. Second post on Marlin: `M0` prompt + `M84 Z`
present, no warning — proving the Marlin path is untouched.

---

### HR-13 — `onCommand` silently discards every command it does not name — **Low-Medium** · `READ`

**Reaches it:** Manual NC *Optional stop*, *Display message*, or *Orientate spindle*.

`onCommand()` opens with an `Info` comment naming the command, then a `switch` with no `default:`.
`COMMAND_STOP` → `M0`; `COMMAND_OPTIONAL_STOP` → nothing at all. So Manual NC *Optional stop*
produces no `M1`, and at Comment Level `Important` or `Off` not even the naming comment survives —
the instruction vanishes without trace. `M1` is supported by all three targets, so there is no
reason to drop it; and an explicit `default:` turns every future gap into a visible warning.

```diff
     case COMMAND_STOP:
       writeBlock(mFormat.format(0));
       return;
+    case COMMAND_OPTIONAL_STOP:
+      writeBlock(mFormat.format(1));
+      return;
   }
+
+  // Anything not named above reaches here. The Info comment at the top of this function is the only
+  // trace otherwise, and it disappears entirely at Comment Level Important/Off.
+  writeComment(eComment.Important, " >>> WARNING: command " + getCommandStringId(command)
+    + " is not supported by this post and was not emitted");
 }
```

**Verify (Do → Get).** *Do:* add Manual NC *Optional stop* to an operation and post. *Get:* `M1` at
the Manual NC's position. **Pass:** `M1` present. Second check: Manual NC *Orientate spindle* → a
`>>> WARNING: command COMMAND_ORIENTATE_SPINDLE …` comment appears instead of silence.

---

### HR-20 — tapping is not really implemented; the manual path now warns, nothing more — **Medium** · `PART-FIXED`

**Reaches it:** any **Tapping** operation. Not a tool-change path and **not gated on Phase 4** — it sits
here by the scope decision below, not because it shares the others' code.

**Observed** in `Drill_Tap.gcode` (2026-07-31, GRBL/mm, factory defaults). Each of the four holes emits:

```
( COMMAND_SPINDLE_COUNTERCLOCKWISE)
( MOVEMENT_LEAD_OUT)
Z-12.7 F1058
( COMMAND_SPINDLE_CLOCKWISE)
```

Fusion is saying *reverse, back the tap out, resume forward*. As posted, the post commented all three
and emitted **no command for any of them**, so a right-hand tap was driven out of the hole still
turning forward — stripping the thread or snapping.

**What the original write-up got wrong.** It read as though the post never commands a reversal at all.
It does: the **automatic** branch has always emitted `M3`/`M4` correctly —
`mFormat.format(_clockwise ? 3 : 4)`. The gap was **manual-path only**, and it was the same weakness as
`HReview.md` **HR-12**: `setSpindeSpeed()` detected the direction change and `spindleOn()`'s manual
branch discarded it.

**Part-fixed 2026-07-31 with HR-12.** The manual branch now prompts on a direction change as well as a
speed change — `M0 (MSG Set spindle to 1200 RPM counterclockwise)` — which is option (b) from this
finding's own list, *warn that tapping needs an automatic spindle*, and is what the scope decision
allowed. Prompting cannot make a hand-switched router reverse, but it **stops the machine** and states
what the job requires, which is strictly better than silence. Nine pauses in a four-hole tap job is the
honest cost, and it makes tapping-on-a-router visibly impractical rather than quietly wrong.
Verification is `HReview.md` HR-12 **(A3)**.

> **Refusing tapping under manual control was considered and rejected (2026-07-31).** It was option (a)
> here. **Someone will make this path work** — a spindle with a VFD and a reversing input is an ordinary
> upgrade on these machines — and the post should not stand in their way. The automatic branch already
> serves that operator correctly today.

**What is still owed — the fuller implementation, and it is professional-review work.** The prompt is a
warning, not tapping support. Open questions, none of them settled:

- **Feed synchronisation.** `COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION` still only warns. Real tapping
  wants the feed locked to the spindle, which none of these firmwares does (no `G33`), so a
  floating/tension holder stays a precondition rather than a nicety. Note the existing warning covers
  **feed sync only** and says nothing about direction — do not read it as covering the whole hazard.
- **Whether the reversal prompts should be suppressible** for an operator whose spindle *can* reverse
  but who is running the manual branch for other reasons. Probably a property, probably in group 07.
- **Rigid vs. floating behaviour on the automatic branch**, which has never been posted at all: no file
  in the record exercises `M4` from a real tapping operation.

**Verify (Do → Get), for the fuller implementation when it is built.** *Do:* one Tapping operation on
each spindle mode. *Get:* manual → the alternating reversal prompts per `HReview.md` HR-12 (A3);
automatic → `M4` before the lead-out and `M3` after, with no prompts. **Pass:** both, and in neither
case a bare `( COMMAND_SPINDLE_COUNTERCLOCKWISE)` comment as the only trace. Second check: a **Drill**
operation in the same post is unaffected and still expands to plain `G0`/`G1`.

---

## 3. Test register

**✅ 0 PASS · ❌ 0 FAIL · ⬜ 58 UNRUN · ➖ 7 n/a or moved — 65 rows.** Nothing professional has been
verified yet; this is the whole of what the professional side owes. Absorbed from the Beta-2 test plan.

Every row is a delta from the defaults fixed in `conventions.md` → *How to run a test*; the one
convention worth restating here, because half these rows turn on it, is that Marlin uses `G92` and
**rejects >1 WCS** (Guard C), where GRBL/RepRap write `G10 L20 P<n>`.

This is the **index**. Rows whose expected output is a multi-line g-code block — most of §3.1 — carry
that block in their expansion below, in the subsection named in the Expansion column; a cell cannot
hold it, and the *Expect* must exist in exactly one place.

| Test | Proves | Setup (delta from defaults) | Method | Expansion | State |
|---|---|---|---|---|---|
| **PB1** | Re-probe per copy | Replicate 2-copy, base `G59`, Retract Across Parts on, Subsequent = `Use Active WCS X0 Y0, Probe Z0` | posted | §3.1 | ⬜ |
| **PB2** | Trust the stored Z | as PB1, Subsequent = `Use Active WCS X0 Y0 Z0` | posted | §3.1 | ⬜ |
| **PBV1** | Setup run — record each fixture origin | 2-fixture, First = `Set X0 Y0 Z0 to Current Pos`, Subsequent = `Jog to X0 Y0, Probe Z0` | posted | §3.1 | ⬜ |
| **PBV2** | Production run — reuse fixtures, re-probe Z | First = `Use Active WCS X0 Y0 Z0`, Subsequent = `Use Active WCS X0 Y0, Probe Z0` | posted | §3.1 | ⬜ |
| **PBV3** | Production run — trust the stored Z too | as PBV2, Subsequent = `Use Active WCS X0 Y0 Z0` | posted | §3.1 | ⬜ |
| **PA1** | New WCS from a machined face, operator jogs the new datum | two Setups on one clamped part, Subsequent = `Jog to X0 Y0 Z0` | posted | §3.1 | ⬜ |
| **PA1b** | Variant — WCS 2's XY already known, only Z re-references | same job, Subsequent = `Use Active WCS X0 Y0, Probe Z0` | posted | §3.1 | ⬜ |
| **P2** | Nonzero offset, Replicate + reserved base | 2-part job, base `G59` | posted | §3.1 | ⬜ |
| **P3** | Zero-offset added-part regression | same 2-part job, offsets `0` | posted | §3.1 | ⬜ |
| **M1** | Boundary dispatch — `Use Active WCS X0 Y0 Z0` | multi-WCS + base | posted | §3.1 | ⬜ |
| **M2** | Boundary dispatch — `Use Active WCS X0 Y0, Probe Z0` | multi-WCS + base | posted | §3.1 | ⬜ |
| **M3** | Boundary dispatch — `Jog to X0 Y0 Z0` | multi-WCS + base | posted | §3.1 | ⬜ |
| **M4** | Boundary dispatch — `Jog to X0 Y0, Probe Z0` | multi-WCS + base | posted | §3.1 | ⬜ |
| **M5** | Single-WCS regression — byte-for-byte unchanged | single WCS | posted | §3.1 | ⬜ |
| **M6** | First-part `Use Active WCS X0 Y0 Z0` actually reaches `X0 Y0` | milling tool, first section | posted | §3.1 | ⬜ |
| **H7e** | First-part `Use Active WCS X0 Y0, Probe Z0` on Marlin and RRF | firmware Marlin, then RepRap | posted | §3.2 | ⬜ |
| **D1** | Labels, groups and field types | the dialog | dialog | §3.3 | ⬜ |
| **D3** | The key rename resets every saved preset **once**, and the new keys then hold | a preset saved before the rename | dialog | §3.3 | ⬜ |
| **D2** | The property dump is suppressed at Comment Level `Important` and `Off` | Comment Level `Important`, then `Off` | posted | §3.3 | ⬜ |
| **D4** | The groups are still identifiable in the **legacy** Post Process dialog | the legacy dialog, not an NC Program | dialog | §3.3 | ⬜ |
| **D5** | The header property dump after the `groupDefinitions` move **and** the key rename | GRBL/mm defaults, Comment Level `Info`, diffed against the pre-change commit | posted | §3.3 | ⬜ |
| **HR-26** | The base-clearance retract has no tool-0 / jet guard though the base *establish* does | jet tool + multi-WCS + base | posted | §3.4 | ⬜ |
| **HR-18 (T)** | Tool-change half of the `loadFile()` newline guard | tool-change include whose last byte is not a newline | posted | §3.4 | ⬜ |
| **HR-3 (C)** | Tool-change half of the GRBL spindle-off prompt | GRBL, manual spindle, a tool change | posted | §3.4 | ⬜ |
| **P4** | Group 04's branches, never posted | — superseded by **PR-1a**: the enum it tested no longer exists | — | §3.6 | ➖ |
| **P5** | `Probe to Set Base = Probe Z` — the no-prompt base variant | group `05` B = `Probe Z` | posted | §3.4 | ⬜ |
| **P6** | `writeWCS()` debug/info logging | Comment Level `Debug`, then `Info` | posted | §3.4 | ⬜ |
| **P7** | `wcsDefinitions` offset-0 decision | work offset `0` | dialog | §3.4 | ⬜ |
| **P8** | Tool-change ordering + base-relative park matrix | **after the Phase-4 rework lands** | posted | §3.4 | ⬜ |
| **P9** | Spoilboard surfacing on the base (R1) | multi-WCS job with a section cutting *on* the base | posted | §3.4 | ⬜ |
| **CR-3** | A suppressed tool change now says so | multi-tool job, group 07 off | posted | §3.5 | ⬜ |
| **CR-4** | Coolant `Use custom` now loads a file | a `… Custom` coolant property naming a real file | posted | §3.5 | ⬜ |
| **CR-5** | A jet / tool-0 first part warns that Z0 was never set | jet job, default First mode | posted | §3.5 | ⬜ |
| **CR-13** | `resetPostState()` | two posts in one Fusion session | posted | §3.5 | ⬜ |
| **J1** | First-part origin modes — all six, with a jet tool and with tool 0 | jet tool / tool 0 | posted | §5 | ⬜ |
| **J2** | Subsequent WCS / Part with a jet tool — the `canProbe` false branches | jet tool, multi-WCS | posted | §5 | ⬜ |
| **J3** | Spoilboard base with a jet tool — `writeBaseEstablish()` skips the probe | jet tool, base reserved | posted | §5 | ⬜ |
| **J4** | The laser property group (`9 - Laser`, 7 properties) — **never posted at all** | group 09 on, GRBL, a laser operation | posted | §5 | ⬜ |
| **J5** | Laser/jet × the Phase-4 features | jet + base + Retract Across Parts | posted | §5 | ⬜ |
| **HR-7** | First-rapid flag survives a tool change | — verified by **P8**'s matrix once Phase 4 lands | — | §2 | ➖ |
| **HR-8** | Tracked position after post-injected motion | — verified by **P8**'s matrix | — | §2 | ➖ |
| **HR-9** | `Do First Change` zeroes Z against the right tool | — verified by **P8**'s matrix | — | §2 | ➖ |
| **HR-10** | `Disable Z Stepper` is not Marlin-only | — has a complete diff; folds into **P8** | — | §2 | ➖ |
| **HR-13** | `onCommand` no longer discards silently | — has a complete diff; folds into **P8** | — | §2 | ➖ |
| **HR-20** | Tapping beyond a warning on the manual path | a drill + tap job, automatic spindle | posted | §2 | ⬜ |
| **PR-1a** | The capability/action split emits what the old enum did, and nothing when the action is off | group 04 declarations × `Home at Job Start`, GRBL then Marlin | posted | §3.6 | ⬜ |
| **PR-1b** | The stored-offset warning fires on the trusting modes and **never** on the `Jog …` modes | 2-WCS job, `Axises Homed and Trusted` = `None` off, each origin mode in turn | posted | §3.6 | ⬜ |
| **PR-2a** | A multi-WCS job on a homed-Z machine posts with **no** reserved base, one `G53` per traverse | 2 WCS, `Fixed Z Reference = Machine Z`, `Inter Part Travel Z = -12` | posted | §3.6 | ⬜ |
| **PR-2b** | The first section's arrival emits a real absolute Z instead of the `Unknown Z` comment | as PR-2a, First = `Use Active WCS X0 Y0, Probe Z0` | posted | §3.6 | ⬜ |
| **PR-2c** | Every new guard refuses, and leaves **no file** | each of the nine new `error()` conditions | posted | §3.6 | ⬜ |
| **PR-2d** | `Inter Part Travel Z` converts mm → inch in both the block and the header echo | as PR-2a, output units **inch** | posted | §3.6 | ⬜ |
| **PR-3** | `Probe to Set Base` no longer offers `None`, and the base always probes | base reserved, dialog + a post | dialog | §3.6 | ⬜ |
| **PR-4** | The `G53` tool-change park lands at one physical spot under two WCS | — verified by **P8**'s matrix once Phase 4 lands | — | §2 | ➖ |
| **PR-6a** | The machine park emits `G53 G0 X0 Y0` as its own block, X/Y only | GRBL, declaration `XY Only` + `Home at Job Start` = `Home`, `At End Park At = Machine X0 Y0` | posted | §3.7 | ⬜ |
| **PR-6b** | The **Marlin** route is `G28 X` / `G28 Y`, and needs no prior homing | Marlin, declaration `XY Only`, `Home at Job Start` = **`Off`**, park `Machine X0 Y0` | posted | §3.7 | ⬜ |
| **PR-6c** | The machine park retracts first where a fixed Z reference exists, and restores the WCS | PR-6a + `Fixed Z Reference = Spoilboard`, and again with `Machine Z` | posted | §3.7 | ⬜ |
| **PR-6d** | `Work` (default) is byte-identical to the old boolean-on behaviour | GRBL/mm defaults, diffed against the pre-change build | posted | §3.7 | ⬜ |
| **PR-7a** | `Pause, then Home` emits one pause then the homing, and `Home` emits homing with none | GRBL and Marlin, declaration `XYZ`, both non-`Off` answers | posted | §3.7 | ⬜ |
| **PR-7b** | Group 4 reads declaration / action / park, and group 1 no longer carries the park | dialog | dialog | §3.7 | ⬜ |
| **PR-8a** | A Marlin park with a reserved base emits **no** base transit — the register was never written | Marlin, `Fixed Z Reference = Spoilboard` (`G55`, then `G59.1`), park `Machine X0 Y0` | posted | §3.7 | ⬜ |
| **PR-8b** | A park with **no** fixed Z reference says in the file that it cannot retract | PR-6a exactly — `Fixed Z Reference = None`, park `Machine X0 Y0` | posted | §3.7 | ⬜ |
| **PR-9** | The `G53` park block carries the XY travel feedrate | PR-6a, `Travel Speed XY` moved off its default | posted | §3.7 | ⬜ |
| **PR-10** | The fixed-Z establish warns off the two `… to Current Pos` first-part modes | `Fixed Z Reference` = `Machine Z`, then `Spoilboard`, First = each `Current` mode then each `Jog` mode | posted | §3.6 | ⬜ |
| **PR-11** | The GRBL jog warning is silent on a single-WCS job whose *subsequent* mode is a `Jog` mode | GRBL, one WCS, Subsequent = `Jog to X0 Y0, Probe Z0` | posted | §3.7 | ⬜ |
| **REG-MF** | A factory-default job is unchanged **apart from the property dump** | GRBL/mm, all defaults, diffed against the pre-change build | posted | §3.6 | ⬜ |

`dialog` is a fifth method alongside the four in `conventions.md` → *How to run a test*: it is settled by
opening the Fusion dialog, and no posted file can show it.

### 3.1 Multi-part / multi-fixture — needs a job nobody has posted yet

Every row below needs either a 2-copy Replicate job or a two-Setup job; none can be reached from the
single-section jobs on disk. **This is the largest untested area in the post.**

**Professional B — one WCS per copy (Replicate).** 2-copy job, Setup 1 → WCS `1` (G54), Setup 2 → WCS
`2` (G55), reserved base **`G59`**, **Retract Across Parts = On**, real tool.

- [ ] **PB1 — re-probe per copy** (Subsequent = `Use Active WCS X0 Y0, Probe Z0`, the default).
      *Get at job start:* `( Establish spoilboard base G59)` → `(   Select base G59 …)` → `G59` →
      `G38.2` → `G10 L20 P6 Z0.8` → `G0 Z40` (Inter Part Travel Z, base frame) →
      `(   Restore operating WCS G54 …)` → `G54`. *Get at the `P1→P2` boundary:*
      ```
      ... transit through base: G59 → G0 Z40 ...
      G55
      (   Move to part origin X0 Y0, then probe Z)
      G0 X0 Y0 F<travelXY>
      G38.2 F30 Z-10
      G10 L20 P2 Z0.8
      ```
      **Pass:** the base probes once at start with no XY reposition; each copy re-probes Z at its
      stored XY; the traverse retracts base-relative to `Z40` *before* switching WCS.
      *(Satisfies M2, P2.)*
- [ ] **PB2 — trust the stored Z** (Subsequent = `Use Active WCS X0 Y0 Z0`). Same job. *Get at
      `P1→P2`:* `G59` → `G0 Z40` → `G55` → `(   Move to this part's stored origin X0 Y0)` →
      `G0 X0 Y0` → straight into the cut. **Pass:** no `G38.2` on the added copy, and the tool still
      arrives safely at `X0 Y0` after the retract. *(Satisfies M1.)*

**Professional B-variant — set the fixtures on run 1, reuse them later.** Two distinct jobs against
the same 2-fixture bed; reserved base `G59`, Retract Across Parts on, real tool. This is the workflow
the Jog origin modes exist for.

- [ ] **PBV1 — setup run, record each fixture origin.** First = `Set X0 Y0 Z0 to Current Pos`,
      Subsequent = `Jog to X0 Y0, Probe Z0`; jog to fixture 1 before posting. *Get:* first part
      `G10 L20 P1 X0 Y0 Z0` (no prompt, no probe); at `P1→P2` retract → `G55` → jog prompt
      (`M0 (MSG Jog to X0 Y0 above Z0, probe)`) → `G10 L20 P2 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8`.
      **Pass:** every fixture's origin is written to its own register from an operator jog. Then
      confirm at the controller that `G54`/`G55` report the set origins (GRBL persists `G10 L20` to
      EEPROM). *(Satisfies M3, M4.)*
- [ ] **PBV2 — production run, reuse fixtures, re-probe Z.** First = `Use Active WCS X0 Y0 Z0`,
      Subsequent = `Use Active WCS X0 Y0, Probe Z0`; **do not re-jog**. *Get:* first part
      `(   Use stored work origin; move to X0 Y0 at Safe Z)` → `G0 Z<probeSafeZ>` → `G0 X0 Y0`, no
      origin write; at `P1→P2` retract → `G55` → `G0 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8`.
      **Pass:** no prompts anywhere; XY from the stored fixtures; Z re-probed per copy.
      *(Satisfies M6, M2.)*
- [ ] **PBV3 — production run, trust stored Z too.** As PBV2 with Subsequent = `Use Active WCS X0 Y0
      Z0`. **Pass:** no probe anywhere on added copies; each just retracts and arrives at its stored
      `X0 Y0`. Only sound when every copy's stock is the setup run's thickness.

**Professional A — a second WCS on the same part, same fixture.** The part stays clamped in one
fixture (no flip, no re-clamp): after the face and outside are machined in WCS `1`, a second Setup
uses WCS `2` whose origin is referenced from a **machined face**, so its Z must be re-probed there.
Mechanically an ordinary inter-WCS traverse plus a re-probe — supported today. The tool never leaves
the part, so the outgoing-frame Safe Z is a valid clearance and no base is required. *(The flip /
re-clamp variant remains future work.)*

> **Settings note (Guard B).** For a single-part two-WCS job use **Retract Across Parts = Off** with
> no base: the inter-WCS traverse still retracts to the probe Safe Z in the *outgoing* frame, which
> clears the part. Leaving Retract Across Parts **on** without a base trips Guard B — it cannot tell
> one part's two WCS from two fixtures.

- [ ] **PA1 — new WCS from a machined face, operator jogs the new datum.** Setup 1 → WCS `1`; Setup 2
      → WCS `2` on a machined face. Subsequent = `Jog to X0 Y0, Probe Z0`; Retract Across Parts off,
      no base. *Get at the `G54→G55` boundary:*
      ```
      (   Retract to Safe Z before WCS change)
      G0 Z<probeSafeZ>            ; in the outgoing G54 frame
      G55
      ... M0 jog prompt: "Jog to X0 Y0 above Z0, probe" ...
      (   Set current X,Y position to 0,0)
      G10 L20 P2 X0 Y0
      (   Move to part origin X0 Y0, then probe Z)
      G38.2 F30 Z-10
      G10 L20 P2 Z0.8
      ```
      **Pass:** the traverse retracts to a clear Z in the outgoing frame *before* selecting `G55`; the
      re-probe writes Z into `P2`, not `P1`. *(Satisfies M4.)*
- [ ] **PA1b — variant: WCS 2's XY already known, only Z re-references.** Same job, Subsequent =
      `Use Active WCS X0 Y0, Probe Z0`. *Get:* retract → `G55` → `(   Move to part origin X0 Y0,
      then probe Z)` → `G0 X0 Y0` → `G38.2` → `G10 L20 P2 Z0.8` — **no jog prompt**.
      *(Satisfies M2.)*

**Probe XY offset — added-part halves.** The offset makes the touch-point `origin + (offsetX,
offsetY)` at the first part and each added part, and is **never** applied to the base probe. The
first-part paths (offset 0 and nonzero) and the base-ignores-offset half are already verified (§4);
only the added-part halves remain.

- [ ] **P2 — nonzero offset, Replicate + reserved base.** 2-part job, base `G59`, Subsequent =
      `Use Active WCS X0 Y0, Probe Z0`, offsets `10`/`5`. **Pass:** the **added part (`P2`)** shows
      `(   Move to probe point = origin + offset X10 Y5, then probe Z)` → `G0 X10 Y5` → `G38.2` →
      `G10 L20 P2 Z<thk>`. *(The base and first-part halves are already evidenced by `H7c.gcode`.)*
- [ ] **P3 — zero-offset added-part regression.** Same 2-part job, offsets `0`. **Pass:** each added
      part emits the bare-origin form — comment reads `part origin X0 Y0`, **not** `probe point =
      origin + offset …` — and the first/only part still shows no reposition at all.

**Subsequent WCS / Part — the four modes.** Use a 2-part Replicate job (`P1` + `P2`), reserved base
`G59` + Retract Across Parts on, tool ≠ 0. On each added part every mode must **retract to a safe Z
first, then act** — confirm that retract precedes any XY move. Marlin is out of scope (Guard C).

- [ ] **M1 — `Use Active WCS X0 Y0 Z0`.** base-relative retract (`G59` → `Z<SafeZ>`) → `G55` →
      **`G0 X0 Y0`** → straight into cutting, no probe. That `G0 X0 Y0` is the "do nothing but arrive
      safely" move added by the redesign; it supersedes the older verified `Skip` behaviour, which
      went straight into cutting.
- [ ] **M2 — `Use Active WCS X0 Y0, Probe Z0`.** retract → `G55` → rapid to `X0 Y0` (+ offset) →
      `G38.2` → `G10 L20 P2 Z`. XY comes from `P2`'s stored offset, not re-zeroed.
- [ ] **M3 — `Jog to X0 Y0 Z0`.** retract → `G55` → jog prompt (`M0 (MSG Jog to X0 Y0 Z0, then
      continue)`; RepRap `M291 … S3 X1 Y1 Z1`) → `G10 L20 P2 X0 Y0 Z0` → cutting. No probe, no auto
      XY move.
- [ ] **M4 — `Jog to X0 Y0, Probe Z0`.** retract → `G55` → jog prompt → `G10 L20 P2 X0 Y0` →
      `G38.2` → `G10 L20 P2 Z`, with attach/detach prompts following `Probe Pause`. With a nonzero
      offset the probe repositions after the jog.
      > **Open decision to settle on this run:** whether the added-part jog mode should get HR-1's
      > provisional `Z0` for symmetry with the first-part jog mode. Deferred here deliberately — the
      > tool arrives from a retracted clearance, so its Z is less predictable than on the first part.
      > See `HReview.md` HR-1.
- [ ] **M5 — single-WCS regression.** A single-WCS job is byte-for-byte unchanged — `writeWCS()`
      returns at "WCS unchanged", so none of the new dispatch runs. (Compares two *current* posts to
      each other, so the HR-3 tail note does not affect it.)
- [ ] **M6 — first-part `Use Active WCS X0 Y0 Z0` reaches X0 Y0.** Milling tool: the first section
      emits `G0 Z<probeSafeZ>` then `G0 X0 Y0` instead of nothing. A jet/tool-0 first part emits the
      `X0 Y0` move but **no** Z retract (→ J1).

### 3.2 Origin-mode coverage — firmware variant

- [ ] **H7e — first-part `Use Active WCS X0 Y0, Probe Z0` on Marlin and RRF.** **Pass:** Marlin emits
      `G92 Z0.8` only (no XY word, no `G54`); RRF emits `G54` + `G10 L20 P1 Z0.8` with `M291 … S3`
      probe prompts. No jog buttons (`X1 Y1 Z1`) — this mode has no jog prompt. *(Cheap to fold into
      any Marlin/RRF session; the GRBL half of this mode is verified.)*

### 3.3 Dialog & defaults audit — needs the dialog, not a posted file

- [ ] **D1 — labels, groups and field types.** Confirm group **`6 - On WCS / Part / Fixture
      Changes`** exists (no lingering `Probe / Work Origin`); titles read **First WCS / Part**,
      **Subsequent WCS / Part**, **Probe Pause**, **Probe with G38.2**; the base-establish option
      reads **Pause, Probe Z, Pause**; **First WCS / Part** lists all six modes in order and defaults
      to the first (`Set X0 Y0 to Current Pos, Probe Z0`); **Subsequent WCS / Part** lists its four
      modes in order and defaults to the first (`Use Active WCS X0 Y0, Probe Z0`) with no
      `Set … to Current Pos` modes; **Probe X/Y Offset**, group-05 **Inter Part Travel Z** and group-06
      **Safe Z** accept only whole numbers (reject `2.5`) and read as whole mm. Confirm no group shows
      two fields both titled "Safe Z".
- [ ] **D3 — the key rename resets every saved preset, once, and the new keys then hold.** Open the dialog
      with a **previously customised preset** loaded. *Get:* groups read `1 - Job`, `2 - Feeds and Speeds`,
      `3 - Map G1s to Rapids - disable when using full license` (**renamed** by `HReview.md` HR-17),
      `4 - Establish Machine Coordinates`, `5 - Establish Spoilboard Reference`,
      `6 - On WCS / Part / Fixture Changes`, `7 - Tool Changes`, `8 - External Include Files`,
      `9 - Laser`, `10 - Coolant`, `11 - Duet` — **in that order, none collapsed** — with
      **9 / 7 / 4 / 2 / 4 / 10 / 8 / 5 / 7 / 10 / 2** properties (68 total), placed by `order:` (100…200 in
      tens) rather than by a text sort of the title.
      **Pass — every property is back at its default, exactly once.** The key is the stored identifier and
      all 68 were renamed, so a customised Beta-1/Beta-2 preset **must** come up empty: a value that
      *survived* means the rename missed a key. Then save a fresh preset, close, reopen — **it must reload
      intact**, which is what proves the new keys are stable identifiers rather than merely different ones.
      Spot-check Home Before Start, both origin dropdowns and any nonzero Probe X/Y Offset in both halves.
      *(Header half is **D5**; §4's dump evidence predates both changes — §7. A posted file cannot tell
      "the preset survived" from "the values were re-entered", which is the point of checking here.)*
      > **The discriminator inverted on 2026-08-04, and CR-14's question retired with it.** This row once
      > proved a preset *survives* a `group:`-only change; now a survivor is the failure. The reset was
      > accepted knowingly in beta — the scheme it replaced put the order in the key, so every mid-group
      > insert would have reset presets *silently*, one property at a time, for the life of the post. And
      > CR-14's *is Fusion sorting by `group:` at all?* is moot rather than answered: `order:` places groups
      > explicitly (Guide § 5.1.5). What D1/D3 must show instead is that `order:` **is** honoured — groups
      > appearing as 1, 10, 11, 2, 3 … would mean it is not, and the fallback is to pad the titles again.
- [ ] **D2 (remainder) — the property dump is suppressed at Comment Level `Important` and `Off`.**
      The dump's structure and the resolved Safe-Z lines are verified (§4); only the suppression half
      is unrun.
- [ ] **D4 — the groups are still identifiable in the legacy Post Process dialog.** The Guide states the
      group `title:` **is not displayed** there, and before the `groupDefinitions` move the label *was* the
      `group:` string — so that dialog showed `01 - Job` regardless; now the string is an opaque key.
      *Do:* post through the legacy Post Process dialog rather than an NC Program. **Pass:** all 69
      properties still reachable and grouped intelligibly — headings reading `job`, `feeds` … is
      acceptable; **no headings, or 69 properties in one flat list, is a fail.** *(Fix if it fails: carry
      the number in the key, `g01_job`, which sorts and reads in both dialogs.)*
- [ ] **D5 — the header property dump after the `groupDefinitions` move and the key rename.** Re-baselines
      what §4 verified against `H7c.gcode`, which predates both (§7). *Do:* one GRBL/mm factory-default job
      at Comment Level `Info`, diffed against the same job from the pre-change commit. *Get:* eleven
      `( Properties -- <title>:)` blocks, `1 - Job` … `11 - Duet` in that order, each listing its
      properties by their new keys in the sequence they had before, 68 lines, enums as stored ids.
      **Pass — the diff touches only the eleven headings and the 68 property *names*; every *value* is
      identical and no line moves.** A moved line means an `order:` is wrong; a changed value means a key
      is read somewhere the rename missed; a motion-line diff means the pass was not mechanical. *(Order
      and the counts are already proven by harness against the file's own `group:`/`order:` fields; only a
      post shows that Fusion's `getProperty()` resolves all 68 renamed keys.)*

### 3.4 Other outstanding professional checks

- [ ] **HR-26 — the base-clearance retract has no tool-0 / jet guard, but the base *establish* does.**
      *(Found 2026-08-01 by the full code inspection; `READ`, no fix.)* `writeBaseEstablish()` probes only
      `if (tool.number != 0 && !tool.isJetTool())` — so on a **jet/laser job the reserved base's Z0 is
      never established**, and the function returns having emitted nothing but a Debug line.
      `retractThroughBaseClearance()` carries **no such guard**: it fires whenever
      `spoilboardSafeZAcrossWcs` is on, a base is reserved, and the WCS changes. It then transit-selects
      the base and emits an **absolute `G0 Z<Inter Part Travel Z>` in a frame whose Z0 was never set** —
      whatever a prior job left in that register, which on GRBL persists in EEPROM. `rapidMovementsZ()` has
      no jet guard either, so the move is emitted. **This is the one place the "never move absolutely in an
      unestablished frame" rule is broken**, and it is broken by a combination the rest of the file guards
      everywhere else: every probe site (`onCommand(COMMAND_TOOL_MEASURE)`, `partProbe()`'s callers,
      `writeBaseEstablish()`) checks `isJetTool()`. *Do:* a 2-part jet job, base reserved `G59`,
      `Probe to Set Base` = `Pause, Probe Z, Pause`, `Retract Across Parts` on. *Get:* the base select and
      `G0 Z<clearance>` at the WCS change, with **no** base `G38.2` anywhere above it. **Pass:** currently
      fails by design — the row exists to force the decision. *Candidates:* skip the base-relative retract
      when the base was not established (needs a module-level `baseEstablished` flag, since the property
      alone cannot tell you the probe ran); or refuse the combination in `validateJob()`; or fall back to
      the outgoing frame's probe Safe Z as the no-base branch already does. **Belongs to §5's workstream**,
      but it is a Guard-B-shaped hole rather than a jet feature gap.
- [ ] **HR-18 (T) — the tool-change half of the `loadFile()` newline guard.** `loadFile()` now repairs a
      missing line terminator after an included file (`HReview.md` HR-18, landed 2026-08-01, harness-
      verified over six file endings × three comment levels). The guard lives in the **one shared
      function all four include branches call**, so the two tool-change includes are fixed by
      construction — but "by construction" is a reading, not a posted file, and the tool-change branch is
      the only one where the include is followed by post-injected motion rather than by `flushMotions()`.
      *Do:* GRBL, two tools, group 07 on, and set **`includeToolFile1`** (then `includeToolFile2`)
      to a file whose last line is `M5` with **no trailing newline**; post at Comment Level
      **`Important`** — the default `Info` hides the defect behind the `--- End custom gcode` comment.
      *Get:* the include's last block and the next emitted block on separate lines. **Pass:** no merged
      block. *Discriminator: the absence of a merge at `Important`; a post at `Info` proves nothing.*
      **Also worth capturing while the include files are set up:** whether `ToolFile2`'s include lands
      before or after the re-probe, which HR-9's ordering work will move.
- [ ] **HR-3 (C) — the tool-change half of a landed hobbyist fix.** `spindleOff()` now prompts a
      hand-switched spindle to stop on GRBL as well as Marlin/RRF (`HReview.md` HR-3, committed
      `43d09aa`, verified at job end). The tool-change half is unverified and is the case that matters
      most: *Do:* GRBL, two operations, two tools, group 07 → Tool Changes are Included on, Include
      Relocation Code on, Manual Spindle On/Off on. *Get:* at the boundary —
      ```
      ( Tool Change Start)
      ... the park rapid to Tool Change X/Y/Z -- order not asserted here, see HR-8 ...
      ( COMMAND_COOLANT_OFF)
      ( COMMAND_STOP_SPINDLE)
      M0 (MSG Turn OFF spindle)
      M0 (MSG Insert Tool #2 ...)
      ```
      **Pass:** the operator is never invited to reach into the machine without first being told to
      switch the spindle off — those two `M0`s in that order, with no `M5` between them. Before the
      fix this emitted `M5` there and nothing else.
- [ ] **`Probe to Set Base = Probe Z` — the no-prompt base variant.** `Pause, Probe Z, Pause`
      (attach → probe → detach) is verified (§4); the other surviving option is
      not. *Do:* reserve `G59`, set `Probe to Set Base = Probe Z`. *Get:* the base `G38.2` and
      `G10 L20 P6 Z<thk>` with **no attach/detach `M0`** either side, and the base-frame select /
      restore / `G0 Z<Inter Part Travel Z>` unchanged from the verified shape. **Pass:** probe present,
      prompts absent.
- [ ] **`writeWCS()` debug/info logging.** At Comment Level `Debug` and `Info`, confirm the WCS
      comments appear, are correctly formatted (no literal `undefined`), and are fully suppressed at
      `Off`/`Important`. Include a job whose **first section uses a non-default WCS** (or that follows
      a job leaving a different WCS active) to confirm the origin/probe lands under the correct
      selection — the `writeWCS()`-first ordering in `writeFirstSection()`.
- [ ] **`wcsDefinitions` offset-0 decision.** Work offset `0` displays unresolved (`#0`) in the
      Operations panel (`useZeroOffset: false`) and silently aliases to WCS 1. Decide whether to leave
      it unresolved, set `useZeroOffset: true`, suppress WCS output, or reset to machine coordinates —
      then verify the choice. Related: the mixed `0`/`1` design warning in §6.
- [ ] **Tool-change ordering + base-relative park matrix** *(after the Phase-4 rework lands)*:
      tool-change-only, WCS-change-only, and a combined boundary, each with and without a reserved
      base. Confirm the re-probe lands in the **new** WCS, repositions to the new part's `X0 Y0`
      first, a combined boundary retracts and probes **once**, and the park is base-relative when a
      base is reserved (else current-WCS).
- [ ] **Spoilboard surfacing on the base (R1).** A multi-WCS job with a section cutting *on* the base
      confirms the following sections' WCS is restored. (A same-WCS two-section job emitting no base
      round-trip is already spot-checked — §4.)

### 3.5 Landed by the full code review, professional halves unverified

Added 2026-08-01. The `CR-` pass (now in `HReview.md`) was hobbyist-scoped, but four of the changes it landed
touch controls this file owns. Each needs the Do→Get row below before it counts as verified.

- [ ] **CR-3 — a suppressed tool change now says so.** `toolChange()` used to return in silence when
      `Tool Changes are Included` was off, so a multi-tool job posted a file that cut every operation
      with whichever tool was in the spindle. It now writes an `Important` comment at the boundary,
      and `validateJob()` raises a post-time `warning()` (via a new `countDistinctTools()`, counted
      over **sections**, not `getToolTable()`). *Do:* two operations, two tools, group 07 **off**.
      *Get:* Fusion shows the warning naming `"Tool Changes are Included"` by its exact dialog title,
      the file still posts, and at the boundary —
      `( >>> WARNING: change to T2 <comment> suppressed -- "Tool Changes are Included" is off; the previous tool stays in the spindle)`.
      **Pass:** both halves present. *Discriminator: the comment survives at Comment Level
      `Important`.* Second post with group 07 **on**: no warning, no comment, the tool-change block
      unchanged from today. Third post, **one** tool, group 07 off: **no warning at all** — this is
      the regression that matters, since every default hobbyist job takes that path.
- [ ] **CR-4 — coolant `Use custom` now loads a file.** The four `... Custom` properties are
      documented in their own tooltips and in the README's group-10 table as **files in the nc
      folder**; `CoolantA()`/`CoolantB()` were writing the property value into the g-code stream as a
      block. They now call `loadFile()` through a shared `writeCustomCoolantFile()`, and warn when the
      mode is `Use custom` with the field left empty. *Do:* Channel A Mode = the tool's coolant, Turn
      Channel A On/Off = `Use custom`, and a real `air_on.g` / `air_off.g` in the nc folder. *Get:*
      the file's contents inline between `--- Start custom gcode` / `--- End custom gcode` markers,
      **not** the literal filename. **Pass:** the filename appears nowhere as a block. Second post
      with the field empty: the `no custom file is named` warning and nothing else — previously a
      stray blank line. **This is a behaviour change for anyone who entered raw g-code in those
      fields**; they now get a missing-file `error()` and no output at all, which is the loud failure
      the old form lacked.
- [ ] **CR-5 — a jet/tool-0 first part now warns that Z0 was never set.** Belongs to §5's workstream
      and sharpens **J1** / **HR-1 (D)**. `writeWcsOnStart()`'s `canProbe == false` branch still
      writes XY only — correct, since a provisional `Z0` would silently convert the mode into
      `Set X0 Y0 Z0 to Current Pos` — but it no longer does so quietly. *Do:* a jet tool (then tool 0)
      on the **default** `Set X0 Y0 to Current Pos, Probe Z0`. *Get:* `G10 L20 P1 X0 Y0` with **no
      `Z` word**, immediately followed by
      `( >>> WARNING: a jet tool / tool 0 cannot probe, so Z0 was NOT established ...)`.
      **Pass:** the origin write is unchanged from HR-1 (D)'s expectation *and* the warning is
      present at Comment Level `Important`.
- [ ] **CR-13 — `resetPostState()`.** `onOpen()` reset only `currentWorkOffset` and `sequenceNumber`;
      it now returns all eighteen mutable module globals to their declared values through one
      function. Inert if Fusion gives every output file a fresh JavaScript context. *Do:* re-post any
      verified reference job. **Pass: byte-for-byte identical output.** *This row is a pure
      regression check — if anything at all differs, `resetPostState()` has the wrong initial value
      for something.* Worth running against a job with **two setups posted to separate files** if
      Fusion will do that in one invocation, which is the only case the change can affect.
### 3.6 Machine frame and the fixed Z reference (PR-1 … PR-5)

Landed unposted — **every row here is owed against real output**, and the two harnesses that stand in for
them (29 guard cases, 12 emission cases; `node`, against the working tree, aborting against `HEAD` where
the functions do not exist) prove *logic and block shape*, never what a machine receives.

- [ ] **PR-1a — the declaration emits what the old enum did.** *Do:* `Axises Homed and Trusted` through
      all four answers with `Home at Job Start` = `Home`, then one at `Off`; GRBL and Marlin/RRF; then one at `Pause, then Home`.
      *Get:* GRBL one `$H` whenever either axis is declared, **identical for every declaration set**
      (compile-time there); Marlin/RRF exactly the declared axes, `G28 X`/`G28 Y`/`G28 Z`. **Pass:** the
      action off emits no homing block on any firmware; the action on with the declaration `None` emits
      `( >>> WARNING: "Home at Job Start" is on but "Axises Homed and Trusted" is None …)` and no motion; the prompt appears once,
      not per axis. *Discriminator: that warning — the one state the old enum could not reach.*
      *(Supersedes P4.)*
- [ ] **PR-1b — the stored-offset warning, and what must not trip it.** *Do:* 2 WCS, declaration **`None`**,
      cycling First/Subsequent through `Use Active WCS …`, `Jog to …` and `Set … to Current Pos`. *Get:*
      the warning naming whichever control is on a trusting mode. **Pass: it never fires on a `Jog …`
      mode** — a false positive there rejects the legitimate no-endstop multi-part job the post exists
      for, which is the whole reason the rule is mode-sensitive. **Run `Z Only` too — it must still warn**,
      which is the row that proves the enum did not collapse the two axis facts. `XY Only`/`XYZ` → silence.
- [ ] **PR-2a — multi-WCS on a homed machine Z, no base.** *Do:* 2 WCS, `Fixed Z Reference = Machine Z`,
      declaration `XYZ` + `Home at Job Start` = `Home`, `Inter Part Travel Z = -12`, Retract Across Parts on, First =
      `Use Active WCS X0 Y0, Probe Z0`. *Get:* `$H` → `( Establish fixed Z reference -- homed machine Z)`
      → `G53 G0 Z-12 F<travelZ>`; and at the `P1→P2` boundary:
      ```
      (   Retract to the travel height in the machine frame before traverse -- machine Z -12)
      G53 G0 Z-12 F<travelZ>
      G55
      ```
      **Pass:** the job posts at all — Guard B refused it before — with **no base select anywhere** and no
      WCS register consumed. *Discriminator: `G53` and `G0` on one block with `G0` written literally, even
      though `G0` was already the active motion mode — the modal must not swallow it.* Header echo reads
      `Inter Part Travel Z in output units = -12 -- absolute machine Z`.
- [ ] **PR-2b — the first section's arrival stops being a comment.** Same job. **Pass:** the `G53 G0 Z-12`
      above and **no `(   Ensuring that Z is safe. Unknown Z for XY move.)` anywhere.** *Absence-based;
      the presence-based sibling is the same job at `Fixed Z Reference = None`, single WCS, where the
      comment must return.*
- [ ] **PR-2c — the new guards refuse, and leave no file.** *Do, one post each:* `Machine Z` with
      declaration `XY Only` (no Z) · `Z Only` (no X/Y) · `Home at Job Start` = `Off` · `Inter Part Travel Z`
      empty · on **Marlin**; plus the spoilboard answer with no `Reserved WCS`, a `Reserved WCS` named
      while the reference is `None`, and **the spoilboard answer with `Inter Part Travel Z` empty and
      with it negative** (PR-5's two new guards). **Pass: no `.gcode` on disk for any of them**, each error naming its control by
      its exact dialog title — they are `onOpen()` guards, so the discriminator is the *absence of the
      output file*. **The Marlin one matters most:** it must fire on a **single-WCS** Marlin job, which
      passes Guard C's own test — proving the machine-frame exclusion runs *above* Guard C's early return
      and not below it, where it would be unreachable on exactly the firmware it excludes.
- [ ] **PR-2d — units.** PR-2a in **inch**. **Pass:** `G53 G0 Z-0.4724`, and the header echo reading the
      same number. An unconverted number here is a 25.4× error in the one move that cannot be sanity-
      checked against a work zero.
- [ ] **PR-3 — `Probe to Set Base = None` is gone.** *Do:* open the dialog with a preset that had it set,
      then post with a base reserved. **Pass:** two options, not three; the saved value has reset to
      `Pause, Probe Z, Pause`; a base `G38.2` is present and the old
      `(   assuming base G59 is already established …)` comment is not.
- [ ] **PR-5a — the enum flip is loud, not silent.** *Do:* post a working `Spoilboard` job with
      `Inter Part Travel Z = 40`, then change **only** `Fixed Z Reference` to `Machine Z` and post again;
      then the reverse, starting from a working machine-Z job at `-12`. **Pass: neither posts.** The first
      errors for want of a machine coordinate — *the field does not carry `40` into the machine frame* —
      and the second is caught by the `<= 0` guard naming the leftover. *This is the hazard the two
      separate fields made structurally impossible and one field can only guard; it is the row PR-5 lives
      or dies on.* Third leg: **a bed-zeroed machine's `40` under the machine-Z answer posts and is
      wrong**, which no guard can catch — confirm the header echo reads `-- absolute machine Z` so that it
      is at least visible before the machine moves.
- [ ] **PR-5b — the spoilboard route lost its free default.** *Do:* `Spoilboard` + `Reserved WCS = G59`,
      `Inter Part Travel Z` left empty, on GRBL and again on **Marlin**. **Pass: neither posts**, both
      naming the field. **The Marlin leg is a deliberate behaviour change** — that job posted before,
      inheriting `40` — and it follows the existing precedent that the Spoilboard answer must be
      configured on every firmware (the no-`Reserved WCS` guard already errored there, above Guard C's
      early return).
- [ ] **PR-10 — the establish moves the tool, so `… to Current Pos` no longer means what it says.**
      *Do:* four legs, each posted. (1) `Fixed Z Reference = Machine Z` (declaration `XYZ`, `Home at Job
      Start = Home`, `Inter Part Travel Z = -12`) + First = `Set X0 Y0 to Current Pos, Probe Z0`;
      (2) the same with First = `Set X0 Y0 Z0 to Current Pos`; (3) `Fixed Z Reference = Spoilboard`
      (`G59`, `40`) + First = `Set X0 Y0 to Current Pos, Probe Z0`; (4) leg 1 with First =
      `Jog to X0 Y0, Probe Z0`. **Pass: legs 1–3 raise the post-time warning naming `Inter Part Travel Z`
      as the reason the origin lands at bed clearance, and leg 4 raises none** — the jog prompt comes
      *after* the establish, which is the condition HR-1's provisional `Z0` was always sound under.
      *Discriminator, in the file:* legs 1 and 3 still contain
      `(   Provisional Z0 at the current height …)` immediately after a `G53 G0 Z-12` (leg 1) or a
      `G0 Z40` in the base frame (leg 3) — **the two blocks being adjacent is the defect made visible**,
      and the warning is the whole of the fix, because no arithmetic in the post can know how far the
      stock top is below that clearance. *Fifth leg, the regression:* `Fixed Z Reference = None` on
      factory defaults must raise **no** warning — this fires on the post's default first-part mode, so
      a false positive there would reach every hobbyist.
- [ ] **REG-MF — the default job's blast radius, and the row to run first.** *Do:* GRBL/mm factory
      defaults, single operation, `Info`, diffed against the pre-change build. **Pass: the diff touches
      only the header property dump and the Resolved-Values block** — net **two** properties added and
      **three** removed across PR-1/2/3/5, two group headings retitled, `Reserved base WCS = None` →
      `Fixed Z reference = None`, and the `Inter Part Safe Z in output units = 40` line **gone** — PR-5
      emits it only under a non-`None` answer, and with the field now empty the old unconditional line
      would have formatted `NaN`. **No motion,
      no command, no other comment may move.** *(Byte-identical output stopped being the guarantee when
      the property dump shipped — `conventions.md` → *Context and stance*.)*

---

### 3.7 The end-of-job park and the group-4 consolidation (PR-6, PR-7)

Landed unposted. The `Work` answer is the old boolean's behaviour under a new name, so **PR-6d is the
regression row and should run first**; the rest exercise a path that has never existed.

- [ ] **PR-6a — the GRBL/RepRap route.** *Do:* GRBL, declaration `XY Only` + `Home at Job Start` = `Home`,
      `At End Park At = Machine X0 Y0`, `Fixed Z Reference = None`, single operation. *Get:* after the
      spindle stop, `(   Park at machine X0 Y0)` then `G53 G0 X0 Y0`, then `M30`. **Pass: `G53` and `G0`
      are both written on that block even though `G0` was already the active motion mode** — the modal
      must not swallow it — and the block carries **X and Y only, no Z**: `G53` is not modal, so a
      Z-and-XY park is two blocks, never a three-axis diagonal. *Discriminator: no `G28` anywhere.*
- [ ] **PR-6b — the Marlin route, and the guard asymmetry that justifies it.** *Do:* Marlin, declaration
      `XY Only`, **`Home at Job Start` = `Off`**, park `Machine X0 Y0`. **Pass: it posts** — this is the case
      the firmware split exists for, and the same configuration on GRBL must *refuse* (PR-2c). *Get:*
      `(   Park at machine X0 Y0 -- re-homing X/Y; G53 is a Marlin build option)` then `G28 X` and
      `G28 Y` as separate blocks, and **no `G53` anywhere in the file**.
- [ ] **PR-6c — retract first, and do not leave the base selected.** *Do:* PR-6a plus
      `Fixed Z Reference = Spoilboard` (`G59` reserved, `Inter Part Travel Z = 40`); then again with
      `Machine Z`. *Get, spoilboard:* `G59` → `G0 Z40` → **the operating WCS reselected** → `G53 G0 X0 Y0`.
      *Machine Z:* one `G53 G0 Z<n>` then `G53 G0 X0 Y0`, no frame switch at all. **Pass: the spoilboard
      leg ends with the operating WCS active, not `G59`** — R1 has no job-end exemption, because the
      selection is modal state the sender keeps and the operator's next manual move would run in it.
- [ ] **PR-6d — the default answer changed name only.** *Do:* GRBL/mm factory defaults, single
      operation, diffed against the pre-change build. **Pass: the only motion difference is none** —
      `G0 X0 Y0` still, at the same point in `onClose()`, with no retract added. The diff may touch the
      property dump line for this control and nothing else. *This is the row that says the rename did
      not quietly become a behaviour change for everyone who never opens group 1.*

- [ ] **PR-7a — the pause is an answer, not a second control.** *Do:* declaration `XYZ`, post at
      `Home at Job Start` = `Home` and again at `Pause, then Home`; GRBL and Marlin. *Get:* `Home` → the
      homing block(s) with **no `M0` and no prompt**; `Pause, then Home` → exactly **one**
      `M0 (MSG Prepare machine for homing)` before them. **Pass: one pause however many axes home** —
      three `G28` blocks on Marlin still get one stop, which is why the pause never needed to be its own
      question. *Discriminator: `Off` emits neither, and the combination that used to be expressible —
      prompt on, homing off — is no longer reachable from the dialog at all.*
- [ ] **PR-8a — Marlin never transits a base it never wrote.** *Do:* Marlin, declaration `XY Only`,
      `Fixed Z Reference = Spoilboard`, `Reserved WCS = G55`, `Inter Part Travel Z = 40`, park
      `Machine X0 Y0`; then again with the base at `G59.1`. *Get:* the establish's existing
      `>>> WARNING: reserved base G55 ignored on Marlin`, and at job end
      `>>> WARNING: no retract before parking at machine X0 Y0 -- the reserved spoilboard base was not
      established on Marlin …` followed straight by `G28 X` / `G28 Y`. **Pass: no `G55`, no `G0 Z40` and
      no `G54` anywhere after the last operation** — and in the `G59.1` leg, **no `Gundefined`**, the
      token `wcsGcode()` returns off-firmware. *Discriminator: the file contains exactly one WCS-select
      block, the one the preamble wrote.*
- [ ] **PR-8b — a park that cannot retract says so.** *Do:* PR-6a unchanged (`Fixed Z Reference = None`).
      *Get:* `>>> WARNING: no retract before parking at machine X0 Y0 -- this job establishes no fixed Z
      reference …` immediately before `(   Park at machine X0 Y0)`. **Pass: the warning is present and no
      `G0 Z` precedes the park** — it is HR-16's state named, not fixed, and the file must not imply a
      retract it did not make. *Also check Fusion's dialog raised the matching post-time warning.*
- [ ] **PR-9 — the park block carries a feedrate.** *Do:* PR-6a with `Travel Speed XY` set to a value
      distinguishable from the defaults and from `Travel Speed Z`. *Get:* `G53 G0 X0 Y0 F<that value>` on
      one block. **Pass: the `F` is the XY travel speed, not the Z one and not the last cut's feed** — and
      under `Fixed Z Reference = Machine Z` the two `G53` blocks carry *different* `F` words, Z's then
      XY's, which is the discriminator that the park is not reusing the retract's.
- [ ] **PR-11 — the jog warning is scoped to the control that runs.** *Do:* GRBL, one WCS, First =
      `Set X0 Y0 to Current Pos, Probe Z0` (default), Subsequent = `Jog to X0 Y0, Probe Z0`. **Pass:
      Fusion raises no jog warning at all**, and the posted file contains no `M0` from a jog prompt.
      *Presence-based sibling, same build:* set First to a `Jog` mode and the warning must return —
      an absence-based row alone cannot tell a fixed gate from a deleted warning (`conventions.md`).
- [ ] **PR-7b — the dialog reads in the right order.** *Method `dialog`.* **Pass:** group 4 shows
      `Axises Homed and Trusted`, `Home at Job Start`, `At End Park At` in that order and nothing else;
      **group 1 no longer carries the end park**; and a preset saved before this change comes back with
      the homing action at `Off` and the park at `Work X0 Y0` — both keys were replaced, and `Off` is the
      inert direction for the one that moves the machine.

---

## 4. Checked and found correct — do not re-run

Carried over so a later professional pass can tell "looked at, fine" from "never looked at". Every
`.gcode` named here is in Fusion's NC output folder, not the repo.

**Base, guards and frames**

| What | Evidence |
|---|---|
| Base establish probes and retracts **in the base's own frame** (`G59` select → `G38.2` → `G10 L20 P6 Z<thk>` → `G0 Z40` → `G54` restore), and the base probe emits **no XY reposition** | `H7c.gcode` (offsets X10 Y5, so it also evidences P2's base-ignores-offset half) |
| Base `None` (default) is byte-for-byte identical to the pre-base baseline | Phase 3 |
| Base establish `None` → no probe, Info comment `assuming base G59 is already established …`; `Pause, Probe Z, Pause` → attach/probe/detach | Phase 3 |
| **Guard A** — an origin-establishing operation assigned to the reserved base aborts in `onOpen()`, **no `.gcode` written at all**, error names the offending control by its exact dialog title | `H7d.log` (no `H7d.gcode` on disk) |
| **Guard B** (1a–1e) — safe-Z on + 2 WCS + no base → error; toggle off → posts; base reserved → posts; single-WCS exempt; Marlin hits Guard C first | Phase 4 |
| **Guard C** — Marlin with 2+ distinct offsets aborts; single-WCS Marlin posts unchanged | Phase 3 |
| RepRap-only base on GRBL aborts (`Reserved base G59.1 requires RepRap …`); accepted on RepRap. Base reserved on Marlin → base probe skipped with a warning. Guards silent on a valid job | Phase 3 |

**Traverses and added parts**

| What | Evidence |
|---|---|
| Added-part re-probe **repositions to the new part's `X0 Y0`** before probing (was probing the previous part's end point) | `Test2.gcode` |
| Base-relative retract, re-probe path: `G59` → `Z40` → `G55` → `X0 Y0` → `G38.2` → `G10 L20 P2 Z` | `Setup1 Multi.gcode` |
| **Single retract per boundary** — a re-probe boundary transits once, then repositions and probes; no second Safe-Z retract | Test D |
| **Same-WCS boundary** — `WCS unchanged`, no `G59` round-trip (R2) | Test C |
| Probe XY offset: offset `0` first part emits no reposition rapid; nonzero first part repositions to `X10 Y5` on **both** first-part probing modes | `Setup1-Face1.gcode`, `Face1.gcode`, `H7a.gcode` (diffed against `H7.gcode`) |
| The "unknown Z" warning appears only when Z really is unknown — present with no base, **suppressed** with an established base, back again when the base is only assumed pre-set | `H7c-a/-b/-c.gcode` (all three) |

**Header and dialog**

| What | Evidence |
|---|---|
| Full property dump: one `( Properties -- <group>:)` block per group in dialog order, all 68 properties, enums as stored ids, `<empty>` for unset strings | `H7c.gcode` |
| `( Resolved Values:)` Safe-Z lines genuinely **resolve** rather than restate — `Probe SafeZ = Retract level, fallback 15, resolves to 5.08`, matching the `G0 Z5.08` the file emits | `H7c-c.gcode` |
| Property-group reorder reached the header dump in the new order, counts still summing to 68 | `H7c-a/-b/-c.gcode` |
| Beta 1 → Beta 2 baseline: Z-probe default `G38.2` (was `G28`) on Marlin/RepRap, `No` still emits `G28`, GRBL always `G38.2`; Map-G1s group rename displays correctly; `wcsDefinitions` resolves the Operations-panel Work Offset column with single- and multi-WCS output unchanged; the Beta 2 post installs/selects cleanly over the Beta 1 entry | Beta-2 baseline pass |

> **⚠ Stale files, assertions intact.** `Setup1 Multi.gcode`, `Test2.gcode`, `Face1.gcode`,
> `Setup1-Face1.gcode` and the Test A–D files all predate the HR-1 provisional `Z0`, the property
> dump and/or HR-3's stop-block prompt. Their *assertions* stand — HR-1 adds a `Z` word to an
> existing block and emits no motion — but none matches byte-for-byte. Prefer the 2026-07-31 GRBL/mm
> files (`H2`, `H2 - Debug`, `HR1b`, `HR1c`, `HR3b`, `HR5a/b/c`) as a diff baseline.
>
> **Superseded, needs re-verifying under M1:** the old base-relative **non**-re-probe (`Skip`) path
> (Test B) went `G59` → `Z40` → `G55` → straight into cutting. `Skip` now appends `G0 X0 Y0` after
> the switch. Likewise the group-06 relabels verified in the dialog at the time (Test 3 / Test A)
> predate the Current-Pos/Jog taxonomy — re-check via **D1**.

---

## 5. Deferred workstream — jet tools & laser (J1–J5)

**Scope decision (user).** Jet-tool / tool-0 behaviour and laser operations are a **separate
workstream**, reviewed and tested on their own rather than as sub-checks bolted onto milling rows.
Nothing here blocks the WCS/probe work; all of it blocks a release that claims laser/jet support.

The shared mechanic: `tool.number != 0 && !tool.isJetTool()` is the post's "can this tool probe?"
test, and it gates the probe **and** the Z retract on every origin path. So a jet tool or tool 0 takes
a *different branch* in `writeWcsOnStart()`, `writeWCS()`, `partProbe()` and `writeBaseEstablish()` —
and those branches are essentially unexercised.

- [ ] **J1 — first-part origin modes, all six, with a jet tool and with tool 0.** Each must record
      the origin with no probe and no probe prompts; note which also skip the Z retract. Collects the
      deferred sub-checks: `Set X0 Y0 Z0 to Current Pos` (the documented jet/laser path);
      `Use Active WCS X0 Y0 Z0` (emits the `X0 Y0` move but **no** Z retract — M6);
      `Use Active WCS X0 Y0, Probe Z0` (expect Debug `writeWcsOnStart: probe skipped (tool 0 or jet
      tool) -- moving to stored X0 Y0`, a bare `G0 X0 Y0`, no `G38.2`); and **HR-1 (D)** — a jet/tool-0
      job on the default mode must emit `G10 L20 P1 X0 Y0` with **no `Z0`** and no provisional-Z0
      comment, since no probe means no target to bound.
- [ ] **J2 — Subsequent WCS / Part with a jet tool.** The `canProbe` false branches in `writeWCS()`:
      `Probe Z` → move to the stored `X0 Y0` instead of probing; `Jog XY & Probe Z` → jog, write XY,
      no probe.
- [ ] **J3 — spoilboard base with a jet tool.** `writeBaseEstablish()` skips the probe entirely
      (Debug `probe skipped (tool 0 or jet tool)`), so the base is **never established** on a laser
      job even when reserved. Decide whether that should warn rather than pass silently.
- [ ] **J4 — the laser property group** (`9 - Laser`, 7 properties): On Vaporize / On Through / On
      Etch, Marlin mode + pin, GRBL mode, laser coolant — none covered by any row, none appearing in
      the header dump. Plus `11 - Duet` → `duetLaserMode`.
- [ ] **J5 — laser/jet × the Phase-4 features.** Whether a reserved base, Retract Across Parts and
      the safe-Z retracts are coherent at all for a jet job (no Z probing; Z often fixed by focus).
      **A design review before it is a test** — the answer may be "not applicable, and the dialog
      should say so".

Also on this list, **for its jet half only now that PR-6 has landed the machine-park retract**: **HR-16** (`onClose` traverses to `X0 Y0` before stopping the spindle, with no
guaranteed safe Z). **Half of it landed on 2026-08-01** as CR-6 (`HReview.md`): `onClose()` now
emits `COMMAND_STOP_SPINDLE` **before** the return move, so the tool no longer crosses the work with a
hand-switched router still turning. **The Z half is deliberately unfixed and is still owed here** —
no retract precedes the `X0 Y0` move, the property promises "Z remains unchanged", and for milling
the last operation's own end-of-toolpath retract covers it. **A jet/laser section that ends at cutting
height is not covered**, and that is the same line of code: the traverse runs at cut height. Decide it
with J5.

---

## 6. Design backlog — unbuilt work and open questions

Unbuilt design, and the questions that must be answered before it can be built. **Nothing here is
scheduled** — this is a backlog, not an order of work. The checkpoint holds the ordered list.

**Tool-change ordering + base-relative park** is **§2**, with the five findings that land alongside it.

### Standing decision this section is bounded by

**Multi-WCS supports two coexisting per-part workflows** — one WCS per part or copy. (1) *Pre-set fixture
offsets (Replicate):* `Skip` or `Probe Z`. (2) *Manual per-part:* the two `Jog …` modes. One part from
**multiple datums on the same fixture** is supported (PA1); a **flip or re-clamp** is out of scope for a
single run — those are separate jobs, and remain future work.

### A machine-coordinate base probe point (`G53`) *(not started; design sketch)*

> **The `G53` reconciliation this item used to demand is settled and is no longer a question.** It asked
> whether the post ever addresses the machine frame at all, and required all three candidate uses — base
> probe point, tool-change park (§2), cross-part retract — be decided together. **They were, with PR-1 /
> PR-2:** the post addresses the machine frame on **exactly the axes the operator declares** and nowhere
> else. The cross-part retract is built; the park is PR-4, waiting on §2; only this item is still a
> sketch. `conventions.md` → *Frames* holds the durable half.

The base probes wherever the tool is parked, defended only by an operator precondition. The durable fix is
an explicit **probe point in machine coordinates** — `G53 G0 X<n> Y<n>` before the `G38.2` — so the
touch-off lands on the same bare-spoilboard spot every run.

**Rejected: `G53 G0 X0 Y0` (machine zero itself).** It is the homing corner — the extreme of travel,
routinely off the spoilboard entirely; it is machine-config dependent; and Z is unsolved. Today the base
establish emits *no motion at all*, so the unknown Z is inert; adding a traverse makes it a full-bed
diagonal at an unknown height.

**Sketch, if built.** A group-05 property pair (base probe point X/Y, machine coordinates, whole mm),
emitted as `G53 G0 X<n> Y<n>` immediately before the base `G38.2`, plus:

- **Requires a declaration including X/Y** — machine zero is arbitrary otherwise. The guard and the emitter both exist now
  (`writeMachineTravelZ()`, the group-4 declarations), so this is no longer new machinery.
- **An answer for Z**, and it is now available: `Inter Part Travel Z` is exactly the height such a traverse
  needs, on a machine that declares one. Where none is declared, an `M0` *"jog clear in Z, then continue"*
  — which works on the no-Z-endstop machines that are the majority.
- **Default off** (empty = today's probe-where-parked behaviour).

### Open question — first-part `Use Active WCS X0 Y0 Z0` with a base reserved

It retracts to the group-06 probe Safe Z *in the part's frame*, so with a base reserved the tool arrives
at spoilboard + Inter Part Travel Z and then **descends** to a part-relative hop that may not clear a taller
clamp elsewhere on the bed. **Should `Skip` (both stages) instead hold the base clearance?** Undecided. It
is a verified path, so any change is deliberate.

### Unscheduled ideas

Professional or nice-to-have; none is scheduled, and none is a defect.

- **"Copy first part's Z" mode on `probeOnChange`.** Write the first part's probed Z into each added
  copy's own register (`G10 L20 P<n> Z<firstPartZ>`) — a register write, **no motion, no probe** — for
  same-thickness co-planar fixtures. Requires caching the first part's probed Z. Marlin no-op.
- **WCS `0`/`1` mixed-design warning (human factors).** A job using work offset `0` in one section and `1`
  in another resolves both to `G54`, but reads as two deliberate fixtures in Fusion's Operations panel.
  Emit a `>>> WARNING` when a job mixes `0` with a *different* explicit offset. The correct rule is
  any-section-vs-any-other-section, broader than Fanuc's order-dependent check.
- **`useZeroOffset` enforcement — open question.** `wcsDefinitions.useZeroOffset: false` is declared but
  likely inert: the enforcing `validateCommonParameters()` lives in a shared post library this post does
  not import, so `writeWCS()` still silently aliases `0`→`1`. **Should the post enforce it itself?**
  Natural companion to the item above; test row in §3.4.
- **`permittedCommentChars` global.** A comparable community GRBL post declares it; research whether it
  adds real kernel-side filtering on top of `sanitizeMessageText()` before adding — may be informational.
- **Global-metadata gaps.** Optionally `model`. Cosmetic.

---

## 7. Invalidated by landed fixes

Rows whose saved `.gcode` a change has broken. **Delete a row when its test is re-posted, and delete
this section when it empties** — Rule 4.

| Rows | What moved | Effect |
|---|---|---|
| **every saved GRBL `.gcode` predating 2026-07-31** | HR-3 — the manual-spindle stop now prompts on GRBL | A default job ends `M0 (MSG Turn OFF spindle)` where it once ended `M5`, and each tool change gains the same prompt. **No row's assertions are affected** — do not read a tail diff as a regression |
| **§4's two header-dump rows** (`H7c.gcode`, `H7c-a/-b/-c.gcode`) | the `groupDefinitions` move retitled the dump headings; the key rename renamed every dumped property; the machine-frame work then changed the counts | `( Properties -- 03 - Map G1s …)` now reads `3 - Map G1s …`, and `A_Job_SelectedFirmware = Grbl` reads `jobSelectedFirmware = Grbl`. **The assertions stand** — one block per group, in dialog order — but the numbers are now **72 summing 9/7/4/4/6/10/8/5/7/10/2**, groups 4 and 5 read `4 - Machine Frame` / `5 - Fixed Z Reference`, and `machineHomeBeforeStart` is gone. Delete this row when **D5** re-posts |
| **§4's "base establish `None`" row** and **§4's third "unknown Z" file** (`H7c-c.gcode`) | PR-3 removed the `None` option, so *"no probe, Info comment `assuming base G59 is already established …`"* is now an unreachable configuration; and *"back again when the base is only assumed pre-set"* was that same configuration | Both halves retire rather than re-baseline — **there is no longer a way to reserve a base and not probe it.** The other two `H7c` files' assertions (warning present with no base, suppressed with an established base) stand unchanged. Delete when **PR-3** runs |
| **§4's "Guard B (1a–1e)" row** | PR-2 relaxed Guard B from *requires a reserved base* to *requires a fixed Z reference of either kind* | 1a–1d stand as written. **1e is now incomplete**: "base reserved → posts" needs a sibling proving `Fixed Z Reference = Machine Z` also posts with **no** base. Delete when **PR-2a** runs |

## 8. Owed

What this register owes, not the order to do it in — that is the checkpoint's job.

1. **Every one of the 37 rows.** Nothing professional has been posted. §3.1 is the largest untested area
   in the post and needs a job nobody has built: a 2-copy Replicate or a two-Setup job.
2. **J4 first among the jet rows** — group `09` has never appeared in *any* posted file, and CR-10
   landed a fix there sight-unseen. `HReview.md`'s `CR-10 (A)` is that post and serves both registers.
3. **P8 waits on Phase 4.** It is the matrix that proves the tool-change reorder, so it cannot run until
   §2's five findings land.
