# Integration — running the post against real jobs, without Fusion

**What this file owns:** how an automated integration run is performed, what it may claim, and what
it still cannot reach. `findings.md` owns the findings and the test rows; `design.md` owns why the
post behaves as it does; `plan.md` owns what is next. This file owns the *machinery*.

A row settled by this machinery is a `utility` row — `findings.md` §4 defines the method and its
bounds, and this file is the how.

---

## 1. What an integration run is

Four layers, and none of them is Fusion.

| Layer | What it is | Where |
|---|---|---|
| **The engine** | `post.exe`, the same executable Fusion drives when it posts | Autodesk's webdeploy tree |
| **The job** | an intermediate `.cnc` file — one CAM job, serialised: sections, tools, work offsets, motion | Autodesk's shipped library, and `tools/wcs-jobs/` |
| **The licence** | how Fusion *delivers* that job's rapids — as rapids, or as feed moves | one invisible post property — §6.5 |
| **The request** | what the kernel *asked the post to emit* — every rapid, cut, arc, cycle point and command, in order | `tools/trace.cps` — §2 |
| **The matrix** | a Node script that posts one job under one property set and asserts what the result must and must not contain | `tools/*-matrix.js` |

The third is the newest and the least obvious. Two of the post's ten property groups exist because a
**Personal** licence emits no rapids at all, and that fact lives in neither the engine nor the job —
it is a property of the Fusion that produced the job, which no `.cnc` file records and no fixture can
splice in. It is varied here instead.

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

**One command runs everything**, and that is the form to use:

```
node tools/integration-run.js  <post.exe>  <post.cps>  "<CNC files dir>"  <output dir>
```

It exits 0 only when every case in every matrix passes, so it is usable as a gate. It **sequences**
the matrices; it does not unify them — each keeps its own baseline, for the reason below. What it
buys is that none can be forgotten, and that is not hypothetical: group 3 was reachable for a long
time before anything reached it, and a suite you have to remember to run in four parts is a suite
that gets run in three.

All six matrices also run alone, and take the same four arguments in the same order:

```
node tools/<name>-matrix.js  <post.exe>  <post.cps>  <job root>  <output dir>
```

- **`<post.exe>`** — under `%LOCALAPPDATA%\Autodesk\webdeploy\production\<hash>\Applications\CAM360\`.
  `post-run.ps1` locates it by search rather than by a pinned path; a matrix is handed it.
- **`<post.cps>`** — `MPCNC_v4.0_Beta3.cps`, the deliverable.
- **`<job root>`** — the `res\CNC files` directory inside the installed **Autodesk HSM Post
  Processor** VS Code extension, except for `wcs-matrix.js`, which takes `tools/wcs-jobs`.
- **`<output dir>`** — anywhere outside the repo. Each case writes `<id>.gcode` and `<id>.log` there,
  so a failure can be read after the run rather than only during it.

`VERBOSE=1` prints the checks that passed as well as the ones that did not. Without it only failures
print, and the last line is the tally.

```
node tools/hobbyist-matrix.js        "$POST" MPCNC_v4.0_Beta3.cps "$CNC" out/hobbyist
node tools/professional-matrix.js    "$POST" MPCNC_v4.0_Beta3.cps "$CNC" out/professional
node tools/wcs-matrix.js             "$POST" MPCNC_v4.0_Beta3.cps tools/wcs-jobs out/wcs
node tools/personal-matrix.js        "$POST" MPCNC_v4.0_Beta3.cps "$CNC" out/personal
node tools/correct-gcode-matrix.js   "$POST" MPCNC_v4.0_Beta3.cps "$CNC" out/correct-gcode
node tools/gcode-structure-matrix.js "$POST" MPCNC_v4.0_Beta3.cps "$CNC" out/gcode-structure
```

**190 cases — 37 hobbyist, 46 professional, 39 WCS, 11 personal, 41 CorrectGcode, 16 GCodeStructure —
over 42 job files, and all 190 pass as of 2026-08-17.** The whole run is under a minute.

**The six are independent by design and stay that way.** The first four encode personas that disagree
about what the factory defaults should do, so a shared baseline would have to pick one; the last two
are **categories rather than personas** — they ask a question about the file itself and choose a
configuration to ask it in. `integration-run.js` unifies none of them, it only refuses to let one be
skipped.

| Matrix | Persona or question | Baseline |
|---|---|---|
| `hobbyist-matrix.js` | P1/P2 — hand-zeroed, one tool | none: the factory defaults **are** the persona |
| `professional-matrix.js` | P3/P4 — homed, probed, several tools | homed XYZ, a machine-frame travel height, home at start, park at the corner |
| `wcs-matrix.js` | P7 — several parts in one job | homed XY and a Z frame, **because Guard B refuses these jobs without them** |
| `personal-matrix.js` | the Fusion **Personal** licence | every rapid delivered as a feed move — §6.5 |
| `correct-gcode-matrix.js` | **is the file the job Fusion asked for, spelled so a controller can parse it** | none: each case picks the firmware and the one property its question needs |
| `gcode-structure-matrix.js` | **does the whole file read like a program an operator would run** | none: a *program* is a configuration, and every invariant that applies is run against it |

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

**What a job ASKS FOR, which is a different question:** `tools/trace.cps` is a second post that emits
no g-code either, and writes one record per kernel callback instead — every `onRapid`, `onLinear`,
`onCircular`, `onCyclePoint`, `onPower`, `onSpindleSpeed` and `onCommand`, in the order the kernel
raises them, with coordinates at six decimals. Post a `.cnc` twice — once through the deliverable and
once through this — and the emitted file can be held against **the toolpath Fusion delivered** rather
than against a pattern somebody wrote after reading the output. That is the whole basis of the
CorrectGcode category, and it is what lets `CG2` say the 1072 cutting moves of `bore.cnc` are the 1072
the kernel asked for, at the coordinates it asked for.

**The twelve kernel-configuration lines at the top of `trace.cps` are copied from the post and must
stay copied.** Arc fitting, chord length, sweep splitting and helical linearization are decisions the
KERNEL makes from those globals before either post sees a callback, so a trace built under a different
`maximumCircularSweep` is handed a different stream and every comparison resting on it is worthless.

```
post.exe --noeditor --nointeraction --noheader --noprogress tools/trace.cps <job.cnc> out.trace
```

**And `tools/gcode-model.js` is what reads the result back as g-code** — the block parser, the modal
simulator and the dialect linter the two new matrices share. It knows g-code and the trace format and
**nothing about this post**: a rule about what this post should emit belongs in a case. The simulator
holds the modal state a controller would hold and reports `undefined` — *unknown*, never zero — for a
position a `G53`, a `G38.2` or a homing cycle has made unknowable in the work frame, which is the same
limit `noteCurrentPosition()` states for itself in the post.

---

## 3. How a case is written, and why in that order

A case is a row of data: the job file, the property overrides, and the assertions. The runner is
forty lines and identical in five of the six matrices, except that `personal-matrix.js` runs each case
TWICE -- once as written and once as its reference -- because every claim it makes is a difference
(§6.3), and `correct-gcode-matrix.js` posts a second time through `trace.cps` for the cases whose
oracle is the request.

**`gcode-structure-matrix.js` is the one that is shaped differently, and deliberately.** It is a list
of INVARIANTS crossed with a list of PROGRAMS rather than a list of cases: each invariant is a rule
that must hold of any file this post produces, each program is a configuration it must hold in, and a
failure names the rule and the program. The reason is the way the question arrives — nobody asks
whether `face.cnc` under Marlin retracts before it traverses, they ask whether the post ever traverses
without retracting, and only a rule applied to every file can answer that. **Applicability is part of
each rule**: `Comment Level Off` leaves no section banners to read and a jet program has no spindle to
stop, so a rule states what it needs and is reported as skipped where it is absent — and a program
that reaches fewer than half the rules fails outright, so skipping cannot quietly empty the file.

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
channels**, and a matrix that reads only the file cannot see half of what the post promises. Three of
the findings this machinery has returned — `PV-9`, `PV-10` and `PV-12` — are exactly that asymmetry:
a condition the post detects and states somewhere the operator will not be. **`PV-9` closed by making
the two channels one statement**, and `mustLog` is what witnesses it: the file half was never in doubt.

**`hobbyist-matrix.js` had only the first pair until 2026-08-17**, which is why the runners were not in
fact identical and why no hobbyist-facing dialog warning had ever been asserted. `PV-12` is what needed
it. Read that as the general case: a channel a matrix does not have is not a channel the post lacks.

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

**Twenty-one cases across the four matrices failed on their first run, and every one was the
harness's error, not the post's.** A wrong regex; a warning asserted in the channel it does not use;
a job file that refuses for a reason unrelated to the case; an ordering helper that cannot see a
second occurrence of a block because it searches for the first. Two of the hobbyist failures were
wrong because a registered finding had already changed the answer — `CR-12`'s provisional Z0, and
`CR-15` dropping the first-tool prompt on a mode that implies a tool is already fitted.

**The twentieth and twenty-first are both about the INSTRUMENT rather than the claim**, and they are
the ones worth copying out, because each was a true claim measured with the wrong tool.

The **twentieth** asserted that switching group 3 on changes nothing but the property-dump line, and
reported **1107 differing lines** where `diff` finds three. Switching the group on *inserts* a
comment — `( SafeZ retract level: 5)` — and a positional line-by-line compare shifts by one at that
point and calls the rest of the file changed. Comments are now stripped before the compare, which
makes the claim both survivable and sharper: not "the files are identical" but **"not one of the
1094 emitted g-code blocks moves."**

The **twenty-first** asserted that turning feed scaling off makes the fastest cut faster, and it
does not: `bore.cnc` asks for `F1000` throughout and `Max Toolpath Speed` ships at `1000`, so the
**maximum is 1000 either way** while scaling still slows 615 moves and drops the plunge from 1000 to
180. A maximum was the wrong instrument for a claim about a distribution. The case now compares
**block for block** — same job, same move count, so the two runs line up one to one — and asserts
the invariant the post states for itself: *never RAISE a feed*.

The two before those are the cleanest examples of the earlier kind, and they fail in opposite
directions.

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

**Five more failed on the first run of the two new matrices, and every one was again the harness's
error.** Four are the same lesson in a new place — *the instrument, not the claim* — and they are worth
copying out because a parser makes that mistake in ways a regex cannot.

- **A prompt is not g-code.** `M0 Attach ZProbe` and `M291 P"Attach ZProbe" R"Probe" S3` failed the
  lower-case rule, on a post that is right: the message is free text and only the block *before* it is
  code. The linter reads a `codePart` now. **The same bug had a second face**: the tokenizer had been
  discarding the whitespace inside that tail, so `Turn ON 5000 RPM` was stored as `TurnON5000RPM` and
  every structural rule that looked for a prompt found nothing on Marlin and everything on GRBL.
- **`G28 X` is a bare axis word**, and the one block in which a letter carrying no number is legal.
  Tokenizing it as a defect failed every RepRap and Marlin program that homes.
- **A count is not the claim.** A case asserted one spindle prompt per *distinct* speed and
  `break through.cnc` alternates between two, so four changes correctly produce four prompts. It
  asserts the property instead: every requested speed is named, none is invented, and no prompt asks
  for the speed the machine already holds.
- **The twenty-sixth is the sharpest, and it was PASSING.** The rapid walk searched forward for the
  block landing on each requested point, and the kernel asks for a rapid to where the tool already
  stands at the top of every peck. One of those matched an identical block sixty blocks downstream and
  swallowed the whole second hole on the way — so the case read 64 of 126 requests as satisfied and
  said all of them were. *Already standing there* is now asked **before** the search, which is the
  entire correctness of that walk.

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

`tools/wcs-jobs/make-wcs-jobs.js` builds **fifteen** job files. **It does not author a job.**
Nothing here synthesises toolpath data, and that is deliberate: a fixture you cannot reason about
from its source is not evidence.

*(The directory is named for the work that created it. Twelve of the fifteen are about work
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

**42 files.** Twenty-seven are Autodesk's; fifteen are generated. The two tables below are the five
the persona matrices run on; §4.4 is the twenty-two the two categories add. `A` = 2D-Face tool 1
(which cuts **across** the part origin, so it is the block that puts a machined surface under a later
probe); `B` = 2D-Contour tool 2; `J` = a Through-medium laser operation, tool 2; `K` = an Etch laser
operation, tool 2.

**Autodesk's library** — `<CNC files>` in the HSM VS Code extension:

| File | Blocks | Cases | What it covers |
|---|---|---|---|
| `Milling/2D/face.cnc` | 1 section, T1 | **44** | the workhorse: preamble, all six `First WCS / Part` modes, probe geometry, comment levels, sequence numbers, travel speeds, the frame, homing, the park, and every refusal that needs only a plain job |
| `Milling/2D/toolchange.cnc` | 2 sections, T1→T2 | **21** | both tool-change flows, the sender tokens, the change position and its three refusals, the re-probe and its absence — and, because `A` cuts across the origin `B`'s re-probe touches off on, `PV-7`'s machined-datum warning in both its branches |
| `Milling/2D/bore.cnc` | 1 section, 1067 cutting moves, arcs | **13** | arcs on and off, and **the whole of groups 2 and 3**: it is the only job with enough motion for a feed *distribution* to be read, and its arcs are what put `limitArcFeed()` under the same ceiling as the linear path |
| `Cutting/Laser/center.cnc` | 7 sections, T2 laser | 2 | a jet tool withholding the provisional Z0 a milling tool receives — and, on `HR-26`, receiving the **clearance lift** a milling tool always got, which is not the probe's to gate |
| `Milling/2D/full program.cnc` | 4 sections, 2 tools | 1 | compensation **in the control**, which all three firmwares refuse |

**Generated** — `tools/wcs-jobs/`, all fifteen from the two sources above:

| File | Blocks (`tool@offset`) | Cases | What it covers |
|---|---|---|---|
| `two-parts.cnc` | T1@1, T1@2 | **9** | a part this job has never seen — the whole of `Subsequent WCS / Part`, the traverse retract, Guard B's refusal, and Marlin's multi-offset dialect |
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
| `default-offset.cnc` | T1@0, T1@2 | **2** | the untouched Work Offset field aliased to `G54`, beside a real second offset — and `PV-17`'s silent case, the pairing that is *not* ambiguous |
| `mixed-default-explicit.cnc` | T1@0, T1@1 | 2 | offset `0` beside offset `1` — one register wearing two numbers, which is the only pairing the alias makes ambiguous. `PV-17` |
| `offset-out-of-range.cnc` | T1@10 | 1 | past `G59.3`, which no supported firmware has |
| `mill-then-jet.cnc` | T1@1, T2@1 | 1 | a change **into** a tool that cannot probe — `PR-22`'s falsifier |

### 4.4 The twenty-two the categories add, and why each one is there

Every one is Autodesk's own and none needed building. **What they are for is the operation families
the five files above never contained**: a drilled hole, a tapped hole, a bored hole, a helix, a torch,
a jet, a rotated Setup, a multi-axis path, a lathe. The census is `trace.cps`, not the filename.

| File(s) | What only this reaches |
|---|---|
| `Milling/Drilling/deep drilling.cnc` | a canned cycle **expanded**: 2 cycle points, 60 cuts, 126 rapids — the largest rapid population in the library |
| `Milling/Drilling/tapping.cnc`, `left tapping.cnc` | `COMMAND_ACTIVATE/DEACTIVATE_SPEED_FEED_SYNCHRONIZATION`, and a spindle asked to run **counterclockwise** |
| `Milling/Drilling/fine boring.cnc` | **`COMMAND_ORIENTATE_SPINDLE`** — a command the post's `onCommand()` switch does not name, so it reaches `HR-13`'s fall-through. §7.6 recorded that as unreachable; it is in four of these files |
| `Milling/Drilling/break through.cnc` | `onSpindleSpeed()` four times **inside one section**, alternating between two speeds |
| `Milling/Drilling/stop boring.cnc` | a spindle stopped and restarted **mid-section**, by the cycle rather than by a tool change |
| `Milling/Drilling/circular mill.cnc` | 35 arcs from a cycle, and the helix the kernel linearizes because `allowHelicalMoves` is false |
| `Milling/2D/optional stop.cnc` | `COMMAND_OPTIONAL_STOP`, which becomes an unconditional `M0` |
| `Milling/2D/compensation.cnc` | radius compensation in the control on a **one-operation** job, so the refusal is not entangled with a tool change |
| `Milling/Coolant Codes/flood.cnc` | a tool that actually **asks** for a coolant level, which no other job in the suite does |
| `Cutting/Plasma/center.cnc`, `Cutting/Waterjet/.../through medium.cnc` | the jet path met by a torch and by a jet, not only by a laser |
| `Milling/3+2/a30`, `a-30`, `b30`, `b-30`, `c-45b22`, `all` | **six rotated Setups** — `HR-6 (B)`, and the forward vector of each is in the trace |
| `Milling/5x Simultaneous/5x contour.cnc` | a genuinely multi-axis section, which `onSection()` must refuse |
| `Probing/WCS/PWCS Rectangle block.cnc` | an F360 **WCS probing** operation, which `onCyclePoint()` must refuse |
| `Turning/face.cnc`, `Additive/additive.cnc` | the two shapes refused by `capabilities` itself, before `onOpen()` runs |

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

### 5.1 Ten deliberate defects, and the one that got through

**The two new matrices were run against ten mutated copies of the post**, one defect each, written
into a scratch directory and never into the tree. It is the only way to answer *would this case have
noticed*, and it is worth the ten minutes it takes.

**Nine were caught, and by the cases that should catch them**: an arc centre moved 0.5 mm (7 cases
red), every cutting feed raised 20% (8), every `Y` word dropped from a cut (4), GRBL comments written
with a semicolon (21), every retract above Z0 silently dropped (14 programs), the end-of-job spindle
stop removed (14), `G17` dropped from the preamble (13), the `M30` removed (13), and the park moved
**above** the spindle stop (7).

**The tenth is the one worth the space.** Forcing `rapidMovements()` to drop Z before crossing in X/Y
on every move — the plunge the whole function exists to order — turned **nothing** red. The reason is
not a weak case: **no `.cnc` file in the library asks for a rapid that moves in X/Y and Z at once**,
measured over thirteen jobs including the two with the most rapids, so that branch cannot be reached
from any job on disk. `CG8` states that as a bound rather than pretending to test it, and asserts what
it can see instead — that every requested rapid is reached in order, and that no emitted rapid block
mixes a crossing with a Z move, which is what makes the ordering decision possible at all.

**And the park mutant is why one rule exists.** It parked *before* the spindle stop and left the
original park in place, so the file still ended at X0 Y0 and the spindle was still stopped — and both
rules that read those passed. The missing claim was the ORDER, and
`nothing-crosses-the-part-before-the-cutter-stops` was written because a mutation found it, not
because anyone thought of it first.

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

All 63 properties are reachable this way, the invisible test hook of §6.5 included. Getting it wrong fails in three ways and **only the first
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
post.exe --interrogate --noheader --nointeraction MPCNC_v4.0_Beta3.cps > schema.json
```

**And a fourth failure, which belongs to the shell rather than to the post.** PowerShell 5.1 will not
quote a native argument that already contains a quote, so `"Probe Z"` reaches the CRT bare, splits at
the space, and shifts every following `--property` by one position — *"Expected property but got
&lt;output path&gt;"*. `post-run.ps1` builds the command line to the CRT's own rules itself. The
matrices sidestep it entirely by spawning `post.exe` from Node with an argument **array**, which makes
the quoting Node's problem; anything else driving `post.exe` has to solve it one way or the other.

### 6.2 What is covered today

Measured against that schema, across all six matrices — by scanning every property literal the six
files pass and comparing it to `--interrogate`, so the measure is reproducible rather than counted by
hand:

| Measure | Reached | Total |
|---|---|---|
| Properties **varied** by at least one case | **44** | 62 |
| Enum **values** reached, counting the factory default as reached | **53** | 90 |
| Boolean **states** reached, both ways | **18** | 18 |

**The denominator is 62 and the schema now reports 63.** The extra one is the test hook of §6.5,
which is not a coverage target: it is part of the harness that reaches the others. Counting it would
inflate the number with the instrument — and the boolean row is why that matters: **every boolean the
operator can reach is now set both ways**, which reads as 18/18 only once the hook is out of it.

**Groups 2 and 3 are at 100%** — all seven feed properties and both rapid-mapping properties are
varied and asserted, which they were not before `personal-matrix.js`. Group 2 was the sharper of the
two gaps: six of its seven were *set* by earlier cases, but only as scenery.

**Every enum that decides behaviour is at 100%:** `probeOnStart` 6/6, `probeOnChange` 4/4,
`toolChangeMode` 3/3, `toolChangeSender` 4/4, `jobSelectedFirmware` 3/3, `machineHomedAxes` 4/4,
`machineParkAtEnd` 3/3, `jobCommentLevel` 4/4. Those eight are the post's decision surface — the
properties that change *what the file is* rather than how it is spelled — and the crossing of the
first two with the tool change is what `wcs-matrix.js` exists for.

The unreached enum values are **not** spread thinly: they are coolant and laser, and nothing else.
The two single values that used to sit outside those two groups — `machineHomeAtStart` =
`Pause & Home` and `probePause` = `Before` — closed 2026-08-17 with `CG33` and `CG34`.

### 6.3 What "covered" does and does not mean

Three distinctions, because the number above is easy to over-read.

**Reached is not the same as varied.** A property left alone still runs — at its factory default, in
every case. So the default path of all 62 is exercised on every run, and the 18 that no case *varies*
are 18 whose **alternative** values have never been posted. That is the real gap, and it is what
§7 lists. **All eighteen are coolant, laser or an include file**, which is the whole of §7.2, §7.3 and
§7.4 and nothing outside them.

**Varied is not the same as asserted, and group 2 is the case that proves it.** `machineHomedAxes`
is set in almost every professional and WCS case as part of the baseline, but only two cases assert
what it decides. Six of the seven feed properties were in the same position: `H9` set three cut
ceilings at once and asserted only that the *result* stayed under one of them, so no case could have
told you which of the three did the work — or whether any of them did. Each now has a case that
varies it **alone** and reads the difference it alone makes. A property is genuinely covered when a
case sets it *as its subject*, which is why the tables in §7 name the assertion, not the property.

**And a difference observed is not a formula reproduced.** No case in `personal-matrix.js` computes
what a feedrate should be. Each one posts the same job twice and reads what moved: a rate that
appears while the shipped one leaves, a maximum that falls, a count that drops while the distinct
values stay put, a block that is slower and none that is faster. A test that re-derived the
projection in `limitFeedByXYZComponents()` would agree with a post that scaled consistently wrongly,
because it would be the same arithmetic checking itself.

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
  licence, so a case that overrides nothing is the shipped experience. **What it does not vary is the
  licence itself**, which is why the group those users depend on needed a matrix of its own.
- **Professional** — a machine that homes all three axes, a declared travel height in the machine's
  own frame, homing at job start, a park at the homing corner.
- **WCS** — `machineHomedAxes` `XYZ`, `machineTravelZ` `-5`, `machineHomeAtStart` `Home`. **This one
  is not a preference:** Guard B refuses any job with more than one work offset unless X/Y are
  declared homed, and the traverse retract needs the Z frame. It is the minimum configuration in
  which those job files post at all.
- **Personal** — the test hook on, and nothing else. **The baseline is a delivery mode, not a machine:**
  it says how Fusion hands the job over, so every other property is at its factory value unless the case
  is about it. **Only four of the eleven cases turn it on** — the six group-2 cases and `R1` run under a
  full licence, because a feed ceiling is not a licence question and the bound must be measured where
  the operator actually is. A case that varied the hook itself would be comparing licences, not
  configurations.

`findings.md` §4 states the same idea for hand-run rows — a standing configuration, and a row names
only what it changes from it.

### 6.5 The one property that exists for this file

**`mapRapidsTestPersonalLicence`.** It makes `onRapid()` forward to `onLinear()`, which is what
Fusion's **Personal** edition does on its own, and it is the only reason group 3 can be tested at
all.

**Why nothing else would do.** Group 3 restores a `G1` to a `G0` from inside `onLinear()`. Under a
paid licence every link, retract and traverse arrives at `onRapid()` instead, so `isSafeToRapid()` is
never consulted and the group cannot run — and Autodesk's library is **full-licence output**. A
spliced fixture cannot supply one either: `make-wcs-jobs.js` copies motion records as **opaque
bytes** and authors none, which is the property that makes its fixtures trustworthy (§4.2) and the
same property that puts this out of reach. The condition is not in the job. It is in the licence that
produced the job, and there is no licence to vary.

**Why it is in the post rather than in a copy of the post.** Until 2026-08-17 this was a hand-held
file, `Personal.cps`, carrying the same edits. It went stale — it still read `A_Feeds_TravelSpeedXY`
and `A_MapRapids_RestoreFirstRapids`, property names deleted in Step 2 — and **a stale harness does
not fail loudly.** It posts. It answers a question about a post that no longer exists. Worse, its own
banner had to say its evidence was about *logic, never about what the post emits*, because what it
emitted was a copy's output. The hook removes both problems at once: the suite runs **the
deliverable**, so what it reads is what the operator would get.

**Four things keep it from being a liability**, and each is asserted by a case rather than promised:

| Guard | How | Asserted by |
|---|---|---|
| No operator can reach it | `visible: false` — Autodesk's own idiom, and their `tormach.cps` uses it for a test-only switch in the same words: *"FOR TESTING PURPOSES ONLY. DO NOT ENABLE."* | — |
| It cannot be on in silence | `validateJob()` announces it **in both channels** — the dialog, and the first line of the file | `R2` |
| It changes nothing when off | it has **no `group`**, so `writeAllProperties()` skips it as *"not a dialog property"* and a normal job's dump is unchanged to the byte | `R1` |
| It captures only Fusion's rapids | every post-injected rapid goes through `emitRapid()`, never `onRapid()`, so a move the post makes **on its own behalf** stays a rapid whatever the hook is set to | the split itself |

That last row is the one that took thought. `onRapid()` is now two functions: the entry point Fusion
calls, and `emitRapid()`, which is what everything inside the post calls when it means *make a rapid
move*. Without the split, enabling the hook would have offered the post's own retracts and park to
`isSafeToRapid()` — and a test hook that alters the moves the post makes for itself is not measuring
the post, it is replacing it.

**The bound this does not lift.** The hook reproduces the *delivery* of rapids as feed moves. It does
not reproduce a Personal-licence toolpath in any other respect, and no claim here rests on it doing
so. `R1` is what holds that line: with the hook off, group 3 alters not one of `bore.cnc`'s 1094
emitted blocks — so the hook is the only thing standing between §7.7's old *"out of reach"* and the
eleven cases that now reach it.

---

## 7. What full coverage would take, and how much of it is a job file

The 18 properties no case varies (§6.3) look like one debt and are three different ones. **The
job-file half is built** (§7.5), **the group-3 half is reached** (§6.5) **and the case half is
closed** (§7.1); what remains is fixture files, rulings and the stated bounds. Everything below was
run rather than reasoned, except where it says otherwise.

### 7.1 Needed a case, not a file — **closed, 2026-08-17**

All five are `CorrectGcode` cases over job files that were already on disk, and one of them was owed a
correction rather than a case.

| Residue | Closed by | What it asserts |
|---|---|---|
| `jobManualSpindlePowerControl` = `false` | `CG32` | `M3 S5000` and `M5` **replace** the two prompts — both halves, because a case that asserted only the `M3` would pass on a post that commanded the spindle *and* still stopped to ask |
| `probeG382orG28` = `false` | `CG35` | `G28 Z` in place of `G38.2`, **on Marlin** — a GRBL case would assert nothing, that arm emitting `G38.2` unconditionally |
| `duetMillingMode`, `duetLaserMode` | `CG36` | both tokens, from one job: they are written at a section-type **change**, so `mill-then-jet.cnc` is the shape that emits the pair. The table's old note said the default was `T0`; it is `M453` |
| `machineHomeAtStart` = `Pause & Home` | `CG33` | the stop **above** the homing cycle — a stop below it prepares the machine for a cycle that has already run |
| `probePause` = `Before` | `CG34` | the fit prompt without the removal prompt. `H15` covers `No`, the default covers `Before & After` |

*(A sixth residue, `feedsScaleFeedrate` = `false`, closed earlier the same day with `F2` — and it did
not close the way this table expected. The claim written here was that unscaled feeds are faster; the
fastest cut is `F1000` either way, and what scaling actually does to this job is slow 615 of 1067
moves and drop the plunge from 1000 to 180. §3's twenty-first failure.)*

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

**Coolant is 10 properties and the largest block of unreached enum values, and every one is reachable
now.**
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

**Both files recorded findings rather than passes, and both of those findings are now fixed.**

`W25b` found that at the shipped comment level the second part said nothing about the Z0 nobody
established — no probe, correctly, but no warning in either channel. That was `PV-3` at two further
sites, both `canProbe`-false arms of `writeWcsEstablish()`. **It closed 2026-08-17**, and the case now
asserts the warning it was written to find missing; `W28` covers the third site on the same file and a
different property set. Its remaining assertion — the **absence of a dialog twin** — was `PV-9`'s
question, and `PV-9` closed on it the same day.

`W27` — the return **does** warn, and it warned in the file alone. That answered the first of `PV-9`'s
two open questions with an artifact instead of an argument: **yes, the `canProbe`-false arm carried the
same one-channel silence** as the mode-side arm. Different reason, identical consequence — which is why
a fix scoped to the mode would have left it behind, and why the fix went to the one
`writeWcsOnReturn()` statement both arms fall to.

**Both cases now assert the presence they were written to find missing**, on the same regexes, in the
other channel. That inversion is deliberate: a `warnBothChannels()` reverted to `writeWarning()` turns
them red again, so the closure is pinned exactly as the gap was.

**The remaining residue is cases, not files.** `findings.md` §7 *Owed* item 2 listed five gaps; the
jet block and the four offsets are now built, and the other three need no artifact — a jog mode on a
stale return, Flow 2 on RepRapFirmware across a WCS change, and the change position crossed with a
WCS traverse are all property sets over `change-then-return.cnc` and `part-then-tools.cnc`.

**And the live risk needed no file at all — it is run, 2026-08-17.** `HR-6 (B)` asked whether the
orientation guard is a no-op on exactly the case it exists to catch. The library ships five rotated
Setups and a sixth file holding all five, and `CG26`–`CG26f` post every one of them: **each is refused
by name, and `trace.cps` records the forward vector each was refused for** — `(0, ±0.5, 0.866)`,
`(∓0.5, 0, 0.866)` and the compound `(0.267, -0.267, 0.926)`, so what is refused is known to be
off-axis rather than assumed to be. The control is the rest of the matrix: thirty upright posts, so
the guard is not simply refusing everything. `all.cnc` adds the half `PR-2c` cares about —
five rotated sections, refused at the **first**, leaving no runnable `.gcode`.

### 7.6 One more thing no job file has, and no splice can add

**`laserOnVaporize` is unreachable from the entire shipped library.** The post reads
`currentSection.jetMode` and maps `Vaporize` to that property. Every jet file in `Cutting/` was
posted and **none produces `jetMode: Vaporize`** — only `Through` and `Etching`. `center.cnc`'s
seventh operation is *named* `Vaporize_Center` and its jetMode is `Through`.

A splice cannot add it. `jetMode` is a **section property the kernel computes**, not a parameter
sitting in the block, so there is no word to change — unlike the work offset, which is exactly why
that one is editable. Reaching it needs a Fusion job authored in vaporize mode.

Group 8 is blocked on laser detail in any case, so this is recorded as a bound rather than pursued.

**Two more things no `.cnc` in this suite reaches, found 2026-08-17 and recorded here for the same
reason.**

**A tool numbered 0.** `canProbe` is `tool.number != 0 && !tool.isJetTool()` — one expression, two
disjuncts — and only the jet one can be posted. No file Autodesk ships carries a tool 0, and the
splice cannot add one: `operation:tool_number` was stamped to `0` and the post reported `Tool: 1`,
then to `7` with the same result, so the kernel does not build `tool.number` from that parameter.
Whatever record it does read is one `make-wcs-jobs.js` decodes by guess or not at all, and its own
header refuses to guess. The generated job was deleted rather than kept — a file named for a tool it
does not carry is worse than no file. Like the vaporize level, this needs a Fusion-authored Setup.

**`onCommand()`'s fall-through — this was recorded here as unreachable and it is not.** The claim was
that with `PV-2` landed nothing in the suite reaches it, so `HR-13`'s warning is witnessed by nothing
and a regression would be silent, and that it needed a Fusion-authored job carrying a Manual NC
instruction. **The instruction did not have to be Manual NC.** `Milling/Drilling/fine boring.cnc` and
`back boring.cnc` raise `COMMAND_ORIENTATE_SPINDLE`, which the switch does not name, so the
fall-through fires twice in the first and four times in the second — from Autodesk's own library, on a
file that has been on disk the whole time. `CG16` posts it and holds the count to the trace's. **Read
that as the general case**: *unreachable* meant *not yet looked for*, and what settled it was censusing
the library's commands rather than reasoning about the post.

**Two bounds that ARE bounds, both measured 2026-08-17.**

**No job asks for a diagonal rapid.** Every `onRapid` the kernel delivers moves in X/Y or in Z, never
both — measured over thirteen jobs including the two with the most rapids. So `rapidMovements()`'s
ordering branch, the cross-then-descend decision that keeps the tool out of the part, **cannot be
exercised by any file on disk**, and a mutant that reverses it turns nothing red (§5.1). `CG8` says so
where it would otherwise be claiming to test it.

**Nothing reaches `onDwell()`.** No shipped `.cnc` produces a dwell, `Milling/Drilling/dwell and rapid
out.cnc` included — its counter-boring cycle expands without one. So the `G4 P<sec>` / `G4 S<sec>`
firmware split stands on the source alone.

### 7.7 Group 3 — **reached, 2026-08-17**

**No `.cnc` file, shipped or built, can exercise group 3**, and that has not changed. What changed is
that the condition it needs is not a property of the job at all, so it stopped being looked for
there. §6.5 is the mechanism; this is what the eleven cases establish.

**The bound, restated as a measurement.** With the hook off, switching `mapRapidsRestoreRapids` on
alters **not one of `bore.cnc`'s 1094 emitted g-code blocks** — it adds a single comment naming the
safe height it resolved, and converts nothing. That is `R1`, and it is a stronger statement than the
one this section used to carry, which was measured on `face.cnc` with a positional line compare that
would have reported any inserted comment as a whole-file change (§3, the twentieth failure).

**What the four group-3 cases settle:**

| Case | Establishes |
|---|---|
| `R1` | the bound above — on full-licence output the group is inert, so nothing below can be an artefact of the hook |
| `R2` | the conversions run: one first-move conversion in a one-section job, and three safe-move conversions — **and the file and the dialog both say the hook is on** |
| `R3` | `mapRapidsRestoreRapids` is the master switch: with the hook on and the group off, nothing converts and the Z travel speed reaches one move instead of four |
| `R4` | `mapRapidsSafeZ` decides **how many** moves convert — five at `0`, none at `100` — read on the safe-move count alone, because the first-move conversion is not gated on safe Z and would have masked it |

**And `R7` is why the group exists**, which none of the above shows on its own. With rapids arriving
as feed moves and the group off, every Z traverse leaves at the **Z cutting ceiling or below** — 180,
not the 321 it was told to travel at. Turn the group on and four of them leave as rapids at 321. That
is the post's own stated reason for the feature, in its own words at `onLinear()`, witnessed for the
first time: *"the first move to the start of a section will be at the slowest cutting feedrate."*

**This is no longer a bound, so it is no longer excluded from the coverage number** — both properties
count as varied, and §6.2's 37 includes them.

### 7.8 The answer, by persona

| | Hobbyist | Professional |
|---|---|---|
| **New job files** | ✅ none were needed | ✅ **built** — `jet-two-parts`, `mill-then-jet`, `mid-offsets` |
| **Groups 2 and 3** | ✅ **reached** — the feeds a slow-Z machine depends on, and the rapids a Personal licence turns into cuts | ✅ the same eleven cases; group 3 is off for this persona and `R1` is what says so |
| **Needs a case only** | ✅ **closed** — `CG32`, `CG34` | ✅ **closed** — `CG33`, `CG35`, `CG36`; item 6's last three residues remain |
| **Needs fixtures** | — | the four include files, the four custom coolant files |
| **Needs a ruling, not an artifact** | coolant (a persona), laser (group 8 detail) | the same |
| **Unreachable** | — | `laserOnVaporize`, a tool numbered 0, a diagonal rapid, a dwell |

**The job-file debt is closed and the licence debt with it.** Every path the post has that a `.cnc`
file can reach now has one; the one path no file could reach is reached by the post's own test hook;
and what is still out of reach is stated as a bound with the reason, so none of it is mistaken for a
gap someone forgot. **`onCommand()`'s fall-through has left that row** — it was never unreachable, and
§7.6 says what that cost.

The hobbyist column is now empty of artifacts and of cases. **Groups 2 and 3 are the two the hobbyist
persona depends on most** — a machine whose Z is far slower than its XY, driven from a licence that
emits no rapids — and both were the least witnessed in the suite until now: one unreachable, the other
set as scenery by cases about something else.

What is left is **eight fixture files, three property sets over job files already built, and two
rulings the author owns.** None of it needs a new job file and none of it needs Fusion.

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
