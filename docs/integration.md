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

**90 cases — 28 hobbyist, 31 professional, 31 WCS — over 19 job files, and all 90 pass as of
2026-08-17.** The whole run is about ninety seconds. There is no runner above the three; they are
independent by design, because the personas they encode disagree about what the factory defaults
should do and a shared baseline would have to pick one.

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

**Nineteen cases across the three matrices failed on their first run, and every one was the
harness's error, not the post's.** A wrong regex; a warning asserted in the channel it does not use;
a job file that refuses for a reason unrelated to the case; an ordering helper that cannot see a
second occurrence of a block because it searches for the first. Two of the hobbyist failures were
wrong because a registered finding had already changed the answer — `CR-12`'s provisional Z0, and
`CR-15` dropping the first-tool prompt on a mode that implies a tool is already fitted.

The last two are the cleanest examples, and they fail in opposite directions.

The **eighteenth** asserted the trace `probe skipped (tool 0 or jet tool)` exactly as
`writeWcsEstablish()` writes it — and the file says `probe skipped tool 0 or jet tool`, parentheses
stripped, because a nested `(` would terminate a GRBL comment early. Write the expectation from the
**emitted** text, never from the source that emits it.

The **nineteenth** asserted that a job whose returning tool cannot probe emits no `G38.2` *"after the
laser is fitted"* — with a regex that read the whole file, where section 1 legitimately probes with a
**milling** tool. It failed a correct post. **Scope the claim to the boundary it is about**, which is
what `between()` and the after-the-token slices exist for.

A matrix written *after* reading the output would have encoded the behaviour instead of testing it,
and all seventeen would have been green on the first run while asserting nothing.

---

## 4. The job files

### 4.1 Autodesk's library

The shipped `.cnc` files come with the **Autodesk HSM Post Processor** VS Code extension, under
`res\CNC files`. They are real CAM output — Autodesk's own regression corpus for post authors — which
is what makes them worth using: nothing in them was authored to make this post look correct.

The ones the matrices run on:

| File | Shape (censused) | Reaches |
|---|---|---|
| `Milling/2D/face.cnc` | 1 section, tool 1 | the preamble, the origin modes, the frame, the park |
| `Milling/2D/bore.cnc` | 1 section, arcs and many feed changes | arcs, feed scaling, the feedrate-enforcement count |
| `Milling/2D/toolchange.cnc` | 2 sections, **tools 1 and 2**, offset 1 | both tool-change flows, the change position |
| `Milling/2D/full program.cnc` | 4 sections, 2 tools, **compensation in the control** | the compensation refusal |
| `Cutting/Laser/center.cnc` | **7 sections**, tool 2, a laser, offset 0 | `canProbe` false — a tool that cannot probe |

**And the bound they all share: every one uses a single work offset.** The census settled that
2026-08-16 across the whole library. So `Each New WCS / Part`, `writeWCS()`'s traverse arm and
`writeWcsOnReturn()` — a third of the multi-part design — were unreachable from Autodesk's library by
any harness at all.

**Read the census, not the filename.** Two of the rows above were wrong in this project's own
register until they were measured. `center.cnc` was recorded as *"one operation"* and is seven; its
`tools=2` reads as *two tools* and is one tool **numbered** 2. And its seventh operation is called
`Vaporize_Center` while its `jetMode` is `Through` — the name is the CAM author's, the mode is the
data's.

### 4.2 `tools/wcs-jobs/` — job files built for the paths the library cannot reach

`tools/wcs-jobs/make-wcs-jobs.js` builds **fourteen** job files. **It does not author a job.**
Nothing here synthesises toolpath data, and that is deliberate: a fixture you cannot reason about
from its source is not evidence.

*(The directory is named for the work that created it. Eleven of the fourteen are about work
offsets; `mill-then-jet.cnc` is about a tool change and `one-part.cnc` is the control that proves a
suppression. Renaming it would move every path in the register for no gain.)*

**The format.** A `.cnc` is CIMCO's `compact-nc`: a length-prefixed format string, a seven-byte
preamble, then a flat stream of `[uint32 opcode][payload]` records. Only what is needed is decoded —
the parameter opcodes (`10` ascii, `11` utf-16, `12` int32, `14` stock box, `15` float64) and the
context record (`1034`, 188 bytes), which carries the **work offset as a `uint32` at byte 108 of its
payload**. An operation runs from its `.../nc/marker` parameter record to the next one or to EOF;
everything past the context is copied as opaque bytes and never parsed. Opcode `13` is deliberately
unmapped — it never occurs in the sources, its payload length is unknown, and guessing would walk off
a record boundary silently.

**So each job is a byte copy** of one source's prologue and operation blocks, with **at most one
32-bit word changed per block**. The generator asserts exactly that: it re-splits the file it just
wrote, confirms the `T<n>@<offset>` plan it intended, and byte-compares every block against its
source — zero differing bytes where the offset already matched, one to four where it changed.

That assertion is what the fixtures' value rests on. Two blocks in different work offsets are *the
same operation with one variable moved*, so any difference in the emitted g-code is attributable to
the WCS logic and not to the fixture.

**"Unchanged" is per source, and that detail is load-bearing.** The milling blocks ship at offset 1
and the laser blocks at 0. A check hard-coded to 1 would have passed every jet job for the wrong
reason — the exact failure mode §5 is about — so the generator reads each source's own shipped
offset and holds it to that.

**Two sources, and mixing them is safe — measured, not assumed.** `mill-then-jet.cnc` puts a milling
block and a laser block in one job, which raised the question of whose prologue survives. Both
variants were built and posted: **the emitted g-code is identical apart from the header's own
metadata** — Fusion version, date, document and Setup names — because the prologue carries job
identity while the section data the post reads travels in the blocks.

```
node tools/wcs-jobs/make-wcs-jobs.js "<CNC files>" tools/wcs-jobs
```

The argument is the **root** of `res/CNC files`, not one file. Regeneration is byte-identical.

**The XML serialisation cannot be used for this.** `post.exe` also reads an XML form of the same data
and `--format XML` will accept it on any extension — but **its reader silently drops `work-offset`**,
so every section arrives as offset 0. Verified by editing that attribute in Autodesk's own
`Milling/2D/bore.xml` and posting it. The binary was not the convenient route; it was the only one.

### 4.3 Every `.cnc` file the suite uses

**19 files, 90 cases.** Five are Autodesk's; fourteen are generated. `A` = 2D-Face tool 1 (which cuts
**across** the part origin, so it is the block that puts a machined surface under a later probe);
`B` = 2D-Contour tool 2; `J` = a Through-medium laser operation, tool 2; `K` = an Etch laser
operation, tool 2.

**Autodesk's library** — `<CNC files>` in the HSM VS Code extension:

| File | Blocks | Cases | What it covers |
|---|---|---|---|
| `Milling/2D/face.cnc` | 1 section, T1 | **37** | the workhorse: preamble, all six `First WCS / Part` modes, probe geometry, comment levels, sequence numbers, feeds, the frame, homing, the park, and every refusal that needs only a plain job |
| `Milling/2D/toolchange.cnc` | 2 sections, T1→T2 | **17** | both tool-change flows, the sender tokens, the change position and its three refusals, the re-probe and its absence |
| `Milling/2D/bore.cnc` | 1 section, arcs | 3 | arcs on and off, the cut-speed ceiling, the feedrate-enforcement count |
| `Cutting/Laser/center.cnc` | 7 sections, T2 laser | 1 | a jet tool withholding the provisional Z0 a milling tool receives |
| `Milling/2D/full program.cnc` | 4 sections, 2 tools | 1 | compensation **in the control**, which all three firmwares refuse |

**Generated** — `tools/wcs-jobs/`, all fourteen from the two sources above:

| File | Blocks (`tool@offset`) | Cases | What it covers |
|---|---|---|---|
| `two-parts.cnc` | T1@1, T1@2 | **7** | a part this job has never seen — the whole of `Subsequent WCS / Part`, the traverse retract, Guard B's refusal, and Marlin's multi-offset dialect |
| `tools-across-parts.cnc` | T1@1, T1@2, T2@1, T2@2 | 3 | one change then two returns, both stale — `PV-9` and `PV-10`'s job |
| `change-then-return.cnc` | T1@1, T1@2, T2@1 | 3 | a return whose Z0 a tool change invalidated, and the same with re-probing off |
| `high-offsets.cnc` | T1@7, T1@9 | 3 | past `G59`: refused on GRBL, `G59.1`/`G59.3` on Marlin and RepRap |
| `part-then-tools.cnc` | T1@1, T2@1, T1@2, T2@2 | 2 | a boundary that is **both** a new part and a new tool, on each flow |
| `return-to-part.cnc` | T1@1, T1@2, T1@1 | 2 | a return with no change since — `CR-17`, which must set up nothing and re-prompt nothing |
| `one-part.cnc` | T1@1 | 2 | the single-offset control: what must *not* be emitted when there is one part, framed and frameless |
| `mid-offsets.cnc` | T1@2, T1@3, T1@5, T1@8 | 2 | the four registers nothing else selects, and the only job that **starts** anywhere but WCS 1 |
| `jet-two-parts.cnc` | T2@1, T2@2 | 2 | the multi-part half met by a tool that **cannot probe** — `J2`, `J5` |
| `jet-return.cnc` | T1@1, T2@2, T2@1 | 1 | a **return** the returning tool cannot re-measure — the one arm of `writeWcsOnReturn()` that can only warn, and `PV-9` on the tool side |
| `spread-offsets.cnc` | T1@1, T1@4, T1@6 | 1 | non-adjacent offsets: the code is computed, not counted |
| `default-offset.cnc` | T1@0, T1@2 | 1 | the untouched Work Offset field aliased to `G54`, beside a real second offset |
| `offset-out-of-range.cnc` | T1@10 | 1 | past `G59.3`, which no supported firmware has |
| `mill-then-jet.cnc` | T1@1, T2@1 | 1 | a change **into** a tool that cannot probe — `PR-22`'s falsifier |

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

## 7. What full coverage would take, and how much of it is a job file

The 27 properties no case varies (§6.3) look like one debt and are five different ones. **The
job-file half of it is built** — §7.5 — and what remains is cases, fixture files, rulings and two
stated bounds. Everything below was run rather than reasoned, except where it says otherwise.

### 7.1 Needs a case, not a file — the jobs already exist

Six residues, all reachable today with `Milling/2D/face.cnc`, `bore.cnc` or `toolchange.cnc`.

| Residue | Needs | What a case would assert |
|---|---|---|
| `jobManualSpindlePowerControl` = `false` | any job | `M3 S5000` and `M5` **replace** the two operator prompts. Verified: eight lines of `face.cnc` change, `M0 (MSG,Turn ON 5000 RPM)` → `M3 S5000` and `M0 (MSG,Turn OFF spindle)` → `M5` |
| `probeG382orG28` = `false` | any probing job, **Marlin or RepRap** | `G28 Z` in place of `G38.2`. **A GRBL case would assert nothing** — the GRBL arm emits `G38.2` unconditionally and the description says so, which is why the first probe of this property showed no change at all |
| `duetMillingMode`, `duetLaserMode` | any job, RepRap | the mode token reaches the file. Verified: `T0` |
| `machineHomeAtStart` = `Pause & Home` | any job | the stop that precedes the homing cycle — one of only two unreached values outside coolant and laser |
| `probePause` = `Before` | any probing job | the fit prompt without the removal prompt. `H15` covers `No`, the default covers `Before & After` |
| `feedsScaleFeedrate` = `false` | `bore.cnc` | feeds pass through **unscaled**. `H9` asserts the ceiling holds when it is on; nothing asserts what happens when it is off, so the property's effect is only half witnessed |

### 7.2 Needs fixture files, not job files

Eight properties name **a file, not a value**, and this is worth stating plainly because half of them
do not read that way:

`includeStartFile`, `includeStopFile`, `includeToolFile1`, `includeToolFile2`, and the four
`coolantChannel{A,B}{On,Off}Custom`.

**The custom-coolant fields are include files.** Setting `coolantChannelAOnCustom` to `M42 P4 S255` —
which looks exactly like the g-code it is meant to produce — **refuses the whole job at `onOpen()`**:

```
Error: "Channel A On Custom" names "M42 P4 S255", which is not a file in the NC output
folder <dir> -- check the spelling and the extension, or clear the field.
```

Put that same text in a file called `coolA-on.nc` in the output folder and it posts, emitting the
line verbatim. All eight were verified this way with one-line fixtures, including the start file's
`>>> WARNING` that it **replaces** the post's header and with it the only `G90`/`G21`/`G94`/`G17` the
job sets — `CR-05`, witnessed here for the first time.

So what is owed is a `tools/include-fixtures/` directory and a matrix that copies it into the output
folder before the run. **No new `.cnc` file, and no new technique.**

### 7.3 Needs no new file — the library already has ten of them

**Coolant is 10 properties and 30 of the 43 unreached enum values, and every one is reachable now.**
`Milling/Coolant Codes/` ships ten job files — `flood`, `mist`, `air`, `suction`, `through tool`,
`flood and mist`, `flood and through`, `air through`, `air through tool`, `off` — which is one job per
coolant request the post can be asked to serve.

Verified: `flood.cnc` with `coolantChannelAMode` = `Flood` emits `M8` … `M9`; `flood and mist.cnc`
with a channel set to `Flood and Mist` emits `M8`. And a mismatch is **named, not silent** — channel A
`Flood` plus channel B `Mist` against a job asking `Flood and Mist` gives
`>>> WARNING: No matching Coolant channel : Flood and Mist requested`. So the post matches a request
against a channel **whole** and does not compose two channels to meet it, which is a design question
rather than a coverage one.

`plan.md` blocks group 9 on **a coolant persona**. That block is correct and this does not lift it:
what is missing is a ruling on which of the ten a hobby machine should serve, not an artifact.

### 7.4 Needs no new file — but is a deferred workstream

**Laser is 7 properties and 11 unreached values**, and `Cutting/Laser/` ships three jobs. The library
is richer than the register assumes: `center.cnc` censuses as **7 sections** on one tool, not one
operation.

Verified: `laserOnThrough` = 11 and `laserOnEtch` = 22 produce `S110` and `S220` — percent scaled ten
times into GRBL's `S` range. **`laserOnVaporize` is the exception and it is not a coverage gap but a
bound** — §7.6.

Group 8 is blocked on laser detail in `findings.md` §6, and `J1` has already run and failed here
(`PV-3`). Again: a ruling, not an artifact.

### 7.5 The new-file debt — **built, 2026-08-17**

Four files closed it, and the suite went from 84 cases to 90.

**`jet-two-parts.cnc` — the multi-part half met by a tool that cannot probe.** `J2` and `J5` were the
only two rows `findings.md` §4 said a `utility` run could not reach, blocked on *"a jet block to
splice, `make-wcs-jobs.js` sourcing from a milling file; `Cutting/Laser/center.cnc` is one operation"*.
**Both halves of that were wrong**, and the correction made the job cheaper: `center.cnc` is seven
operations, so no cross-source splice was needed at all. `W25` posts it and reads the traverse
retract, the `WCS changed: 1 -> 2`, the `G55`, the move to the stored origin — **and the arm that
runs when nothing can probe**, reached here for the first time.

**`mill-then-jet.cnc` — `PR-22`'s falsifier.** The spindle stop once read the **incoming** tool's jet
guard, so a change into a laser handed the operator a still-turning cutter. It was fixed on a walk
and nothing witnessed it. The prologue question §7.5 flagged as unproven was settled by building
both variants (§4.2): it is cosmetic. `W26` now reads the whole boundary in order — machine-frame
retract, `M0 (MSG,Turn OFF spindle)`, the hand-over, the warning that the arriving tool cannot
correct Z0, and the laser firing.

**`mid-offsets.cnc` — the four registers nothing else selected.** `W23` and `W24` take offsets 2, 3,
5 and 8. Two things fell out that the arithmetic alone would not have shown: **offset 8 is refused on
GRBL** and the refusal names the offset rather than the count, and this is the only job that
**starts** on a register other than WCS 1 — every other file, shipped or generated, opens on `G54`.

**`jet-return.cnc` — the one arm of `writeWcsOnReturn()` nothing else reaches.** A milling tool sets
part 1 up; section 2 is a change **into** the laser and a new part at once; section 3 returns to part
1 with Z0 stale and no way to re-measure it. Every other return either can probe or has nothing
stale. `W27` reads what is left: the move to the stored origin, and a warning that every depth below
is out by a tool length.

**Two of these files record findings rather than passes.**

`W25b` — at the shipped comment level the second part says nothing about the Z0 nobody established:
no probe, correctly, but no warning in the file and none in the dialog. That is `PV-3` at two further
sites, both `canProbe`-false arms of `writeWcsEstablish()`, which write `eComment.Debug` while the
function's own closing comment says *"the tool-0 arms, which have already warned that nothing
established it."* They have not.

`W27` — the return **does** warn, and in the file alone. That answers the first of `PV-9`'s two open
questions with an artifact instead of an argument: **yes, the `canProbe`-false arm carries the same
one-channel silence** as the mode-side arm. Different reason, identical consequence — so a fix scoped
to the mode would leave this one behind.

Both cases assert the gap, so closing `PV-3` or `PV-9` turns them red and brings the reader here.

**The remaining residue is cases, not files.** `findings.md` §7 *Owed* item 6 listed five gaps; the
jet block and the four offsets are now built, and the other three need no artifact — a jog mode on a
stale return, Flow 2 on RepRapFirmware across a WCS change, and the change position crossed with a
WCS traverse are all property sets over `change-then-return.cnc` and `part-then-tools.cnc`.

**And the live risk needs no file at all.** `plan.md` calls `HR-6 (B)` the live risk — the orientation
guard may be a no-op on exactly the case it exists to catch — and says *"It needs a rotated Setup."*
The library ships five: `Milling/3+2/a30.cnc`, `a-30.cnc`, `b30.cnc`, `b-30.cnc`, `c-45b22.cnc`.

### 7.6 One more thing no job file has, and no splice can add

**`laserOnVaporize` is unreachable from the entire shipped library.** The post reads
`currentSection.jetMode` and maps `Vaporize` to that property. Every jet file in `Cutting/` was
posted and **none produces `jetMode: Vaporize`** — only `Through` and `Etching`. `center.cnc`'s
seventh operation is *named* `Vaporize_Center` and its jetMode is `Through`.

A splice cannot add it. `jetMode` is a **section property the kernel computes**, not a parameter
sitting in the block, so there is no word to change — unlike the work offset, which is exactly why
that one is editable. Reaching it needs a Fusion job authored in vaporize mode.

Group 8 is blocked on laser detail in any case, so this is recorded as a bound rather than pursued.

### 7.7 Out of reach, and not a gap to close

**Group 3 — `mapRapidsRestoreRapids` and `mapRapidsSafeZ` — cannot be exercised by any `.cnc` file,
shipped or built.**

The feature restores a `G1` to a `G0`, from two places in `onLinear()`: a section's first cut move,
and any move `isSafeToRapid()` clears. `onRapid()` clears `forceSectionToStartWithRapid`, and
`isSafeToRapid()` is reached from `onLinear()` alone. **Autodesk's library is full-licence output**,
where every rapid arrives as `onRapid` — so there is nothing to restore, and setting `mapRapidsSafeZ`
on `face.cnc` changes **nothing but the property-dump line**. Verified: zero differing g-code lines.

A spliced job cannot fix it either. The generator copies motion records as **opaque bytes** and never
authors them, which is the property that makes its fixtures trustworthy (§4.2) and the same property
that puts this out of reach.

The feature exists for a **personal-licence** toolpath, where Fusion emits rapids as feed moves. So it
is reachable only from a personal-licence job posted from Fusion, or from `Personal.cps` — and
`design.md` is explicit that `Personal.cps`'s evidence is about *logic*, never about what the post
emits. **This is a bound to state, not a gap to close**, and it should not be counted against the
coverage number.

### 7.8 The answer, by persona

| | Hobbyist | Professional |
|---|---|---|
| **New job files** | ✅ none were needed | ✅ **built** — `jet-two-parts`, `mill-then-jet`, `mid-offsets` |
| **Needs a case only** | manual spindle control, `probePause` = `Before`, unscaled feeds | `G28` probing on Marlin/RRF, the Duet modes, `Pause & Home`, and item 6's last three residues |
| **Needs fixtures** | — | the four include files, the four custom coolant files |
| **Needs a ruling, not an artifact** | coolant (a persona), laser (group 8 detail) | the same |
| **Unreachable** | group 3 — personal-licence rapids | group 3 · `laserOnVaporize` |

**The job-file debt is closed.** Every path the post has that a `.cnc` file can reach now has one,
and the two that no file can reach — group 3's restored rapids and the vaporize power level — are
stated as bounds with the reason, so neither is mistaken for a gap someone forgot.

What is left is cheaper than what was built: **six cases, eight fixture files, and two rulings the
author owns.** None of it needs a new job file, and none of it needs Fusion.

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
