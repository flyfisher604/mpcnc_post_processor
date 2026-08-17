# Integration — running the post against real jobs, without Fusion

**What this file owns:** how an automated integration run is performed, what it may claim, and what
it still cannot reach. `findings.md` owns the findings and the test rows; `design.md` owns why the
post behaves as it does; `plan.md` owns what is next. This file owns the *machinery*.

A row settled by this machinery is a `utility` row — `findings.md` §4 defines the method and its
bounds, and this file is the how.

---

## 1. What an integration run is

Three layers, and none of them is Fusion.

| Layer | What it is | Where |
|---|---|---|
| **The engine** | `post.exe`, the same executable Fusion drives when it posts | Autodesk's webdeploy tree |
| **The job** | an intermediate `.cnc` file — one CAM job, serialised: sections, tools, work offsets, motion | Autodesk's shipped library, and `tools/wcs-jobs/` |
| **The matrix** | a Node script that posts one job under one property set and asserts what the result must and must not contain | `tools/*-matrix.js` |

**The engine is not a stand-in.** `post.exe` is what Fusion invokes; the `.cnc` file is the same
intermediate Fusion hands it. So an integration run is the real post, on real toolpath data, through
the real kernel — everything a code walk settles, *and* whether the post runs at all, which is what
`PV-1` cost: a crash in the first statement of `onOpen()` that `node --check` passes, that a walk had
no way to see, and that stood for four commits.

**What it is not** is Fusion. Two bounds fall out of that and they are stated once here because every
claim below inherits them:

- **The dialog is not exercised.** Property *values* are set on the command line; the dialog's
  layout, its titles, which fields grey out under which mode — none of that is reached. A row that
  depends on what the operator sees is a `dialog` row and no run here can close it.
- **The job is Autodesk's, not the operator's.** Its Setup, its work offsets, its tool list are
  fixed in the file. Where a row needs a job shape the library does not contain, the job has to be
  *built* — which is §4.

### Why not Fusion

Because a Fusion post is a person: open the project, open the Setup, right-click, post, read the
file. It is not repeatable, it is not diffable, and it does not run twenty-five configurations in
ninety seconds. The one thing it has that this does not is the dialog and the operator's own Setup —
so it is kept for exactly those, and everything else runs here.

---

## 2. Running one

All three matrices take the same four arguments, in the same order:

```
node tools/<name>-matrix.js  <post.exe>  <post.cps>  <job root>  <output dir>
```

- **`<post.exe>`** — under `%LOCALAPPDATA%\Autodesk\webdeploy\production\<hash>\Applications\CAM360\`.
  `post-run.ps1` locates it by search rather than by a pinned path; a matrix is handed it.
- **`<post.cps>`** — `MPCNC_v4.0_Beta2.cps`, the deliverable.
- **`<job root>`** — for the first two, the `res\CNC files` directory inside the installed
  **Autodesk HSM Post Processor** VS Code extension; for `wcs-matrix.js`, `tools/wcs-jobs`.
- **`<output dir>`** — anywhere outside the repo. Each case writes `<id>.gcode` and `<id>.log` there,
  so a failure can be read after the run rather than only during it.

`VERBOSE=1` prints the checks that passed as well as the ones that did not. Without it only failures
print, and the last line is the tally.

```
node tools/hobbyist-matrix.js     "$POST" MPCNC_v4.0_Beta2.cps "$CNC" out/hobbyist
node tools/professional-matrix.js "$POST" MPCNC_v4.0_Beta2.cps "$CNC" out/professional
node tools/wcs-matrix.js          "$POST" MPCNC_v4.0_Beta2.cps tools/wcs-jobs out/wcs
```

**84 cases — 28 hobbyist, 31 professional, 25 WCS — and all 84 pass as of 2026-08-17.** The whole
run is about ninety seconds. There is no runner above the three; they are independent by design,
because the personas they encode disagree about what the factory defaults should do and a shared
baseline would have to pick one.

**One case at a time, by hand:** `tools/post-run.ps1` posts a single `.cnc` under a named property
set — a profile in `tools/profiles/*.json`, or `-Set @{...}` — and prints the exit code, the line
count and every warning line. It is what a matrix case is written *from*: run it, read the file,
then encode what must be true.

**What a job contains, before posting it:** `tools/census.cps` is a post that emits no motion. Run
it as if it were the real post and it writes one `CENSUS` line per job — section count, distinct work
offsets, distinct tools, and the offset sequence. That is how *"no shipped `.cnc` file uses more than
one work offset"* was settled, and it is the first thing to run against any job file whose shape is
in question, the format being binary.

```
post.exe --noeditor --nointeraction --noheader --noprogress tools/census.cps <job.cnc> out.txt
```

---

## 3. How a case is written, and why in that order

A case is a row of data: the job file, the property overrides, and the assertions. The runner is
forty lines and identical in all three matrices.

```js
{ id:'W2', desc:'Probe Z0 Once per Part: the added part is probed, into ITS OWN register',
  job:'two-parts.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Probe Z') }),
  must:[[/^G10 L20 P2 Z0$/m,'the provisional Z0 names P2 - CR-12'], ...],
  mustNot:[[/^G10 L20 P1 Z/m,"the first part's register is never rewritten"]],
  custom:t => counts(t, /G38\.2/g, 1, 'exactly one probe: the first is skipped, the second measured') }
```

### Five channels, because a file is not the whole output

| Channel | Reads | Asserts |
|---|---|---|
| `must` / `mustNot` | the emitted g-code | what the file contains |
| `mustLog` / `mustNotLog` | the log, plus stdout and stderr | the post-time `warning()` stream, which is what reaches the operator's dialog |
| `refuse` | the same stream, plus the absence of a file | `error()` — where the right answer is **no output at all** |

The second pair is the point. `HB-5`'s rule is that **a property which fails one way fails in both
channels**, and a matrix that reads only the file cannot see half of what the post promises. Two of
the three findings this machinery has returned — `PV-9` and `PV-10` — are exactly that asymmetry:
a condition the post detects and states somewhere the operator will not be.

A refusal is asserted as *two* things, not one: the pattern in the stream **and** that no `.gcode`
was produced. A guard that names the right problem but leaves a truncated file behind is a different
defect, and one check would not tell them apart.

### Order and count, not presence

Most of the assertions are `ordered(...)` and `counts(...)` rather than a bare regex. That is not
style. **The two defects this area has actually had were an ordering and a duplicate**: `CR-15`, a
preamble with every block present and in the wrong sequence, and `CR-17`/`PR-23`, a `G38.2` driven
into a pocket floor the roughing pass had already cut. A presence check sees neither.

`between(t, a, b)` confines a claim to one section boundary, so a check cannot be satisfied by
something the file happens to contain three hundred lines away. Two helpers exist because that
mistake has been made here twice — see §5.

### The expectation is written *before* the file is read

This is the whole discipline and it is worth stating plainly, because the alternative looks
identical afterwards and proves nothing.

**Seventeen cases across the three matrices failed on their first run, and every one was the
harness's error, not the post's.** A wrong regex; a warning asserted in the channel it does not use;
a job file that refuses for a reason unrelated to the case; an ordering helper that cannot see a
second occurrence of a block because it searches for the first. Two of the hobbyist failures were
wrong because a registered finding had already changed the answer — `CR-12`'s provisional Z0, and
`CR-15` dropping the first-tool prompt on a mode that implies a tool is already fitted.

A matrix written *after* reading the output would have encoded the behaviour instead of testing it,
and all seventeen would have been green on the first run while asserting nothing.

---

## 4. The job files

### 4.1 Autodesk's library

The shipped `.cnc` files come with the **Autodesk HSM Post Processor** VS Code extension, under
`res\CNC files`. They are real CAM output — Autodesk's own regression corpus for post authors — which
is what makes them worth using: nothing in them was authored to make this post look correct.

The ones the matrices run on:

| File | Shape | Reaches |
|---|---|---|
| `Milling/2D/face.cnc` | one section, one tool | the preamble, the origin modes, the frame, the park |
| `Milling/2D/bore.cnc` | one section, arcs and many feed changes | arcs, feed scaling, the feedrate-enforcement count |
| `Milling/2D/toolchange.cnc` | two sections, **two tools**, one offset | both tool-change flows, the change position |
| `Milling/2D/full program.cnc` | four sections, two tools, **compensation in the control** | the compensation refusal |
| `Cutting/Laser/center.cnc` | one jet section | `canProbe` false — a tool that cannot probe |

**And the bound they all share: every one uses a single work offset.** The census settled that
2026-08-16 across the whole library. So `Each New WCS / Part`, `writeWCS()`'s traverse arm and
`writeWcsOnReturn()` — a third of the multi-part design — were unreachable from Autodesk's library by
any harness at all.

### 4.2 `tools/wcs-jobs/` — job files built for the paths the library cannot reach

`tools/wcs-jobs/make-wcs-jobs.js` builds ten job files that use several work offsets. **It does not
author a job.** Nothing here synthesises toolpath data, and that is deliberate: a fixture you cannot
reason about from its source is not evidence.

**The format.** A `.cnc` is CIMCO's `compact-nc`: a length-prefixed format string, a seven-byte
preamble, then a flat stream of `[uint32 opcode][payload]` records. Only what is needed is decoded —
the parameter opcodes (`10` ascii, `11` utf-16, `12` int32, `14` stock box, `15` float64) and the
context record (`1034`, 188 bytes), which carries the **work offset as a `uint32` at byte 108 of its
payload**. An operation runs from its `.../nc/marker` parameter record to the next one or to EOF;
everything past the context is copied as opaque bytes and never parsed. Opcode `13` is deliberately
unmapped — it never occurs in the sources, its payload length is unknown, and guessing would walk off
a record boundary silently.

**So each job is a byte copy** of the prologue and the operation blocks of `Milling/2D/toolchange.cnc`
with **one 32-bit word changed per block**. The generator asserts exactly that: it re-splits the file
it just wrote, confirms the `T<n>@<offset>` plan it intended, and byte-compares every block against
its source — zero differing bytes where the offset was already 1, and one to four where it changed.

That assertion is what the fixtures' value rests on. Two blocks in different work offsets are *the
same operation with one variable moved*, so any difference in the emitted g-code is attributable to
the WCS logic and not to the fixture.

```
node tools/wcs-jobs/make-wcs-jobs.js "<CNC files>/Milling/2D/toolchange.cnc" tools/wcs-jobs
```

Regeneration is byte-identical.

| Job | Blocks (`tool@offset`) | Puts to the post |
|---|---|---|
| `one-part.cnc` | T1@1 | the single-offset control — what must *not* happen when there is only one part |
| `two-parts.cnc` | T1@1, T1@2 | a part this job has never seen: the whole of `Subsequent WCS / Part` |
| `return-to-part.cnc` | T1@1, T1@2, T1@1 | a return with no tool change since — `CR-17`, which must set up nothing |
| `change-then-return.cnc` | T1@1, T1@2, T2@1 | a return whose Z0 a tool change has invalidated |
| `part-then-tools.cnc` | T1@1, T2@1, T1@2, T2@2 | a boundary that is **both** a new part and a new tool |
| `tools-across-parts.cnc` | T1@1, T1@2, T2@1, T2@2 | a change that strands every part it is not standing on |
| `spread-offsets.cnc` | T1@1, T1@4, T1@6 | non-adjacent offsets — the code is computed, not counted |
| `high-offsets.cnc` | T1@7, T1@9 | past `G59`: refused on GRBL, `G59.1`/`G59.3` elsewhere |
| `offset-out-of-range.cnc` | T1@10 | past `G59.3`, which no supported firmware has |
| `default-offset.cnc` | T1@0, T1@2 | the untouched Work Offset field, aliased to `G54` beside a real second offset |

**The XML serialisation cannot be used for this.** `post.exe` also reads an XML form of the same data
and `--format XML` will accept it on any extension — but **its reader silently drops `work-offset`**,
so every section arrives as offset 0. Verified by editing that attribute in Autodesk's own
`Milling/2D/bore.xml` and posting it. The binary was not the convenient route; it was the only one.

---

## 5. What a green run does not mean

**All three findings this machinery has returned came from reading the passing output**, not from a
red case. A green run means the questions asked were answered — not that the right questions were
asked.

Two of the matrix's own cases were passing for the wrong reason, and both were found by re-reading
rather than by running:

- A traverse-retract check carried a fallback disjunct that the *first section's* unrelated clearance
  move satisfied. It proved nothing and reported that it had. It is now anchored on the retract's own
  announcement and ordered from there forward.
- A Marlin control case was a *refusal* whose title claimed it exercised the arm the refusal never
  reached. Replacing the job split it in two: a frameless single-offset Marlin job emits no `G54`,
  while a framed one does — `writeWCS()` suppresses the select and `writeMachineFrameBlock()`
  re-selects anyway. Both rest on `CNC_COORDINATE_SYSTEMS`, so the two are coherent; but reading
  `writeWCS()` alone would tell you no `G54` is ever emitted for such a job, which is false.

So: **re-read the assertions, not only the tally.** A case that has never been red is a case whose
failure mode has never been observed.

---

## 6. Property coverage

### 6.1 How a property is reached at all

`post.exe` takes `--property NAME VALUE`, repeated, and there is no property file. **The value is
evaluated as a JavaScript literal**, which is the whole trick and the whole trap:

| Declared type | Argument | Why |
|---|---|---|
| string, enum | `'"Marlin"'` — quotes **inside** the argument | bare `Marlin` is an undefined identifier |
| number | `-5` | bare |
| boolean | `true` / `false` | bare |

All 62 properties are reachable this way. Getting it wrong fails in three ways and **only the first
is loud**:

- `jobSelectedFirmware Marlin` → *"Failed to set property"*. This is the utility reporting an
  undefined identifier, not refusing enums — which is the wrong conclusion this project drew first.
- `mapRapidsSafeZ Retract:15` → set to a non-string; the post dies in `onOpen()` with
  *"str.search is not a function"*.
- `machineTravelZ -2` → set to the **number** `-2`, and `parseMachineCoordinate()` reads the field as
  **empty**. The machine frame silently switches off. Only `WR-2`'s warning shows it at all.

Nothing validates the value either — `'"Klipper"'` is set as readily as `'"Marlin"'`. So the literal
is built from the property's **declared type**, never from how the value looks, and every name and
enum id is checked against `post.exe --interrogate` before a run. `post-run.ps1` does both; the
matrices build the literal with three one-line helpers (`S`, `N`, `B`) for the same reason.

The schema is the authority on what exists:

```
post.exe --interrogate --noheader --nointeraction MPCNC_v4.0_Beta2.cps > schema.json
```

**And a fourth failure, which belongs to the shell rather than to the post.** PowerShell 5.1 will not
quote a native argument that already contains a quote, so `"Probe Z"` reaches the CRT bare, splits at
the space, and shifts every following `--property` by one position — *"Expected property but got
&lt;output path&gt;"*. `post-run.ps1` builds the command line to the CRT's own rules itself. The
matrices sidestep it entirely by spawning `post.exe` from Node with an argument **array**, which makes
the quoting Node's problem; anything else driving `post.exe` has to solve it one way or the other.

### 6.2 What is covered today

Measured against that schema, across all three matrices:

| Measure | Reached | Total |
|---|---|---|
| Properties **varied** by at least one case | **35** | 62 |
| Enum **values** reached, counting the factory default as reached | **44** | 87 |
| Boolean **states** reached, both ways | **16** | 20 |

**Every enum that decides behaviour is at 100%:** `probeOnStart` 6/6, `probeOnChange` 4/4,
`toolChangeMode` 3/3, `toolChangeSender` 4/4, `jobSelectedFirmware` 3/3, `machineHomedAxes` 4/4,
`machineParkAtEnd` 3/3, `jobCommentLevel` 4/4. Those eight are the post's decision surface — the
properties that change *what the file is* rather than how it is spelled — and the crossing of the
first two with the tool change is what `wcs-matrix.js` exists for.

The 43 unreached enum values are **not** spread thinly. Thirty are coolant, eleven are laser, and the
remaining two are single values of otherwise-covered properties: `machineHomeAtStart` = `Pause & Home`
and `probePause` = `Before`.

### 6.3 What "covered" does and does not mean

Three distinctions, because the number above is easy to over-read.

**Reached is not the same as varied.** A property left alone still runs — at its factory default, in
every case. So the default path of all 62 is exercised on every run, and the 27 that no case *varies*
are 27 whose **alternative** values have never been posted. That is the real gap, and it is what
§7 lists.

**Varied is not the same as asserted.** `machineHomedAxes` is set in almost every professional and
WCS case as part of the baseline, but only two cases assert what it decides. A property is genuinely
covered when a case sets it *as its subject* and asserts the difference it makes — which is why the
tables in §7 name the assertion, not just the property.

**Asserted is not the same as correct.** §5 is the standing caveat: two cases were passing while
asserting nothing useful. Coverage counts questions asked.

### 6.4 The baseline-plus-one-decision shape

Each matrix defines one property set and every case is that set **plus or minus one decision**, so a
failure names the decision rather than the configuration.

```js
const PRO = { machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'),
              machineHomeAtStart:S('Home'), machineParkAtEnd:S('Machine') };
const pro = (extra) => Object.assign({}, PRO, extra);
```

- **Hobbyist** — *no* baseline: the factory defaults are the persona. P1/P2 hand-zero on a personal
  licence, so a case that overrides nothing is the shipped experience.
- **Professional** — a machine that homes all three axes, a declared travel height in the machine's
  own frame, homing at job start, a park at the homing corner.
- **WCS** — `machineHomedAxes` `XYZ`, `machineTravelZ` `-5`, `machineHomeAtStart` `Home`. **This one
  is not a preference:** Guard B refuses any job with more than one work offset unless X/Y are
  declared homed, and the traverse retract needs the Z frame. It is the minimum configuration in
  which those job files post at all.

`findings.md` §4 states the same idea for hand-run rows — a standing configuration, and a row names
only what it changes from it.

---

## How to write in this file

**Three rules.**

1. **This file owns the machinery, not the results.** A finding goes to `findings.md`, a test row goes
   to `findings.md` §4 or §5, and what to do next goes to `plan.md`. What belongs here is how a run is
   performed and what it may claim.
2. **A claim about the harness names the artifact that proves it.** A property is reachable because a
   run reached it; a job file has a shape because the census says so. Nothing here is asserted from
   reading the post alone — that is what a `walk` row is for, and it is a different method.
3. **A bound is stated where it bites, not once at the top.** Every section that inherits the dialog
   bound or the Autodesk-job bound says so. A reader arriving at §4 must not have to have read §1.

**Never point two ways.** A pointer is valid in one direction only: from here toward the file that owns
the work. `findings.md` and `plan.md` do not point back into this file's internals.
