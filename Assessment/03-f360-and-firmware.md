# Step 3 — What F360 supplies, and what the firmwares actually support

The best evidence available without a full licence turned out to be very good:
**Autodesk's own 490 bundled posts are on this machine**, including `grbl.cps`
(83 KB) and `reprap.cps` (61 KB), at
`AppData/Local/Autodesk/Autodesk Fusion 360/CAM/cache/posts/`. A post is a
complete record of what arrives at the callbacks, so most of what I needed to
observe I could instead read. All citations below are `[SDK]` unless marked.

**Revised 2026-08-13.** Three new evidence sources arrived after the first pass and
two of them overturned claims on this page:

- **24 posted files at `Documents/Fusion 360/NC Programs/HB-Tests/`** — real output
  from this post, including five failures. Tagged `[POSTED]` below. This is the
  first direct observation of emitted G-code in the review.
- **`OneDrive/…/GCode/Andrew.gcode`** — carries F360's own licence banner. `C2` is
  now closed, from F360's mouth.
- **211 cached F360 machine definitions** at `CAM/cache/machines/`, which settle
  what `machineConfiguration` actually holds. **This reversed §1's corollary.**

---

## 1. F360 emits its own clearance moves. The post does not have to.

This is the single most important finding in the review.

Autodesk's stock posts carry a property `safePositionMethod`, titled **"Safe
Retracts"**, described as:

> *"Select your desired retract option. 'Clearance Height' retracts to the
> operation clearance height."* — `reprap.cps:102`

And here is what the code does when that option is chosen (`grbl.cps:1039-1050`):

```javascript
function getRetractParameters() {
  ...
  var method = getProperty("safePositionMethod", "undefined");
  if (method == "clearanceHeight") {
    if (!is3D()) {
      error(localize("Safe retract option 'Clearance Height' is only supported when all operations are along the setup Z-axis."));
    }
    return undefined;
  }
```

**It returns `undefined` — the post emits nothing at all.** The retract still
happens, because the retract to clearance height is *already in the toolpath F360
handed over*. The post's own retract logic exists only to add a **machine-frame**
move on top of that, and the only methods offered are `G28`, `G30` and `G53`
(`grbl.cps:1960-1974`) — every one of which requires a homed machine.

So the answer to "does F360 already provide safe clearance and retract heights?"
is **yes, in the toolpath, unconditionally**, and a post is entitled to add
nothing. Question `A1` in `00-facts-needed.md` is **RESOLVED**.

Two corollaries:

- Where the machine-frame retract *is* used, its numbers come from
  `machineConfiguration` — see **§1a**, which is a correction to what this page
  first said.
- `settings.retract.homeXY` (`reprap.cps:173`) shows the stock policy on when to
  home XY: `{onIndexing:false, onToolChange:false, onProgramEnd:{axes:[X, Y]}}`.
  Home XY at program end; not at tool changes; not between operations.

## 1a. `machineConfiguration`, and a correction — the field F360 "already has" is empty

**What this page said first, and what was wrong with it.** I wrote that the
retract numbers *"come from the F360 machine configuration… The operator supplies
them once, in the machine definition. A post inventing its own clearance figures
is duplicating a field F360 already has."* **The first sentence is right. The
second and third are wrong.**

### What these three calls are

`getRetractParameters()` builds a park/retract destination from exactly three
values (`grbl.cps:1069-1071`):

```javascript
var _xHome = machineConfiguration.hasHomePositionX() && !useZeroValues ? machineConfiguration.getHomePositionX() : toPreciseUnit(0, MM);
var _yHome = machineConfiguration.hasHomePositionY() && !useZeroValues ? machineConfiguration.getHomePositionY() : toPreciseUnit(0, MM);
var _zHome = machineConfiguration.getRetractPlane() != 0 && !useZeroValues ? machineConfiguration.getRetractPlane() : toPreciseUnit(0, MM);
```

**Answering the question directly: yes, `getRetractPlane()` is a machine safe Z.**
Specifically:

- It is a **Z in the machine frame**, not the work frame. The canonical emission
  is visible in a stock post that spells it out —
  `writeBlock(gFormat.format(53), gMotionModal.format(0), homeX, homeY, zOutput.format(machineConfiguration.getRetractPlane()))`
  (`prototrak turning.cps:1735`). `G53 G0 X.. Y.. Z<retractPlane>`.
- It is **the Z counterpart of `getHomePositionX/Y()`**. There is no
  `getHomePositionZ()` in the API at all — `getRetractPlane()` is the Z member of
  that trio. It is *"where the tool parks in Z"*, one value per machine, not per
  setup or per operation.
- **243 of the 490 bundled posts use it**, always in this same trio. It is
  mainstream, not obscure.

### Why the post is not duplicating it

Three findings, each independently fatal to my original claim:

1. **There is no machine-definition field that populates it.** The `.machine`
   files are XML, and across all **211** cached definitions the string
   `retractPlane` appears **zero times**. What the XML does have is one
   `homePosition` per axis:
   `<axis actuator="linear" coordinate="Z" homePosition="0mm" range="-76mm 0mm" …/>`
   (`HAAS_machine_default/DESKTOP MILL.machine:42`).
2. **The only way it is ever set is by a post author, in code — and Autodesk ships
   that line commented out.** `setRetractPlane` appears in **159** bundled posts,
   and in every one of them it is inside the sample `defineMachine()` block as
   `// machineConfiguration.setRetractPlane(toPreciseUnit(0, IN));`. It is a
   **hook for the post author**, not a question put to the operator.
3. **Hence it returns 0 on effectively every machine**, which is why stock posts
   test `getRetractPlane() != 0` rather than a `hasRetractPlane()` — there is no
   such guard, so **`0` doubles as "nobody set this"**, and a machine legitimately
   parking at Z0 is indistinguishable from an unconfigured one. `[COMMUNITY]`
   Autodesk forum reports of it *"always returning zero regardless of what was set
   in the setup"* are describing the design, not a bug.

Every Z `homePosition` in all 211 cached machines is `0mm`, so even the axis field
that does exist carries no information.

**So the corrected finding is the opposite of the original.** F360 has a
machine-frame safe-Z *slot* and no way for an operator to fill it. A post that
asks the operator for a machine-frame travel height is **filling a hole, not
duplicating a field** — which makes the post's `Inter Part Travel Z` property
legitimate, and it is the only place in the whole toolchain where that number can
come from a human.

One small opportunity survives: the post could **default** that property from
`getRetractPlane()` when it is non-zero, so a post author or machine vendor who
did set it is honoured. That is a nicety, not a simplification, and it is not on
the critical path.

**Bearing on `design.md`.** This is the second independent line of evidence for
that document's central claim — that F360 has no job-level "above the table"
height. It is stronger evidence than the one I first leaned on, because it comes
from Autodesk's data files rather than from prose. See the note at the head of
`05-history.md` about not using `design.md` as proof.

## 2. Autodesk's own answer to Z uncertainty is a warning, not a computation

When `safePositionMethod` is `clearanceHeight` — i.e. when the post is *not*
emitting machine-frame retracts and therefore cannot know the machine is safe —
here is Autodesk's entire handling (`grbl.cps:735-741`, `reprap.cps:512-514`):

```javascript
if (getProperty("safePositionMethod") == "clearanceHeight") {
  var msg = "-Attention- Property 'Safe Retracts' is set to 'Clearance Height'." + EOL +
    "Ensure the clearance height will clear the part and or fixtures." + EOL +
    "Raise the Z-axis to a safe height before starting the program.";
  warning(msg);
  writeComment(msg);
}
```

A warning at post time, and the same text as a comment in the file. **That is
all.** No computed safe height, no fallback, no configurability. The instruction
to the human is *"raise the Z-axis to a safe height before starting the
program"* — the operator's job, stated plainly.

I reached the same verdict independently in `02-z-trust.md` before reading this.
That Autodesk, with full knowledge of what F360 supplies, chose a warning over a
computation is the strongest available evidence that the computation is not the
post's job.

## 3. Multi-WCS support in a stock post is about fourteen lines

The whole of it. First, a declaration (`grbl.cps:121-127`):

```javascript
// wcs definiton
wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"Standard", format:"G", range:[54, 59]}
  ]
};
```

Then the emission (`grbl.cps:1523-1537`):

```javascript
function writeWCS(section, wcsIsRequired) {
  if (section.workOffset != currentWorkOffset) {
    ...
    writeStartBlocks(wcsIsRequired, function () {
      writeBlock(section.wcs);
    });
    currentWorkOffset = section.workOffset;
  }
}
```

**`section.wcs` is a string F360 hands the post.** The post does not compute
`G54`; it writes what it is given, when the offset changes. Plus exactly one
validation, and it is worth quoting in full because its condition answers a
question the author raised (`grbl.cps:709-717`):

```javascript
function validateCommonParameters() {
  validateToolData();
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    if (getSection(0).workOffset == 0 && section.workOffset > 0) {
      if (!(typeof wcsDefinitions != "undefined" && wcsDefinitions.useZeroOffset)) {
        error(localize("Using multiple work offsets is not possible if the initial work offset is 0."));
      }
    }
```

**Yes — that is exactly what it means.** The error fires when **the *first*
section's offset is 0 and *any* later section names a real offset.** Not on 0
alone, and not on a real offset alone. The reasoning is that F360's default WCS is
`0`, which does not mean "G54" — it means **"whatever frame the machine happens to
be in"**, so the post emits no WCS word for it. Mixing that with a named `G55`
gives a program whose first operation runs in an unstated frame and whose second
runs in a stated one, and the two cannot be reconciled by anything the post can
see. So Autodesk refuses the mix rather than guess.

`wcsDefinitions.useZeroOffset` is the documented opt-out: setting it `true`
declares *"0 has a defined meaning on this machine"* and the guard stands down.
`grbl.cps` sets it **`false`**.

**This is a design decision the post already gets right, and it deserves credit.**
The post aliases `workOffset 0` to WCS 1 / `G54`. That gives 0 a defined meaning,
which is precisely the condition `useZeroOffset` exists to express — so the
degenerate case Autodesk refuses cannot arise, because there is no unstated frame.
The stock post's answer is an error; the post's answer is to remove the ambiguity.
The post's answer is better, and it should be preserved and documented as such.

That is the complete multi-WCS story in Autodesk's own GRBL post: declare the
range, write what F360 supplies, guard one degenerate case. Questions `B1` and a
large part of `B2` are **RESOLVED in principle** — the WCS code appears per
setup, driven by F360.

### 3a. How F360 generates a multi-fixture job, and what it does *not* guarantee

`[AUTHOR]` The mechanism is the **Setup dialog's Post Process tab → "Multiple WCS
Offsets"** checkbox, which then asks for **"Number of Instances"** and **"WCS
Offset Increment"**.

Read what that interface is: **two integers.** A count, and a stride. F360 is not
being told where the second fixture is, what shape it is, how tall it is, or
whether anything stands between it and the first. It is being told *"repeat this
toolpath, and label the copies G54, G55, G56."*

So the answer to *"how does F360 ensure there is no collision between parts?"* is:

> **It does not, and it cannot.** The offsets live in the controller. F360 never
> learns their values, so it cannot compute a path between them, cannot check one
> for interference, and does not claim to. Every retract in the emitted file is a
> Z in whichever WCS is active at the time.

**Is there an operator↔F360 agreement, as hypothesised?** There is a real
convention, and the hypothesis is close but slightly wider than the truth. The
requirement is **not** that the fixtures be identical. It is narrower:

> **Every work offset used in one job must have its Z0 at the same physical
> height, and the clearance height must clear everything along the traverse.**

If both hold, then "Z = clearance in G54" and "Z = clearance in G55" are the same
physical plane, and a retract expressed in one frame is valid in the other. X and
Y offsets can be anything at all. Identical fixtures are the usual *way* people
satisfy the Z0 condition, not the condition itself.

**But this convention is not how production shops actually solve it**, and that
matters more than the convention. On a real machine tool the traverse between work
offsets does not happen in the work frame at all — it happens in the **machine**
frame, via `G53`, `G28` or `G30`. That is the entire purpose of the trio in §1a,
and it is why three of `safePositionMethod`'s four options are machine-frame. The
industrial answer to "clear the fixtures between parts" is *"go to machine Z
home"*, which is correct regardless of what any WCS's Z0 is, and needs no
agreement with anyone.

**Which yields the load-bearing conclusion for this review:** a machine-frame
retract requires a homed machine. So does moving between stored work offsets at
all — the post says so itself, at
[MPCNC_v4.0_Beta2.cps:1669](MPCNC_v4.0_Beta2.cps#L1669). **Multi-fixture work
presupposes a homed machine.** See `07-code-map.md` on Group 5, where this
retires a whole subsystem.

### What a probed WCS offset actually is

Since this needs saying plainly: a work coordinate system is a stored *offset*
inside the controller — six of them on GRBL, numbered G54 to G59. Each holds an
XYZ distance from the machine's own origin to some point the operator cares about,
usually a corner of the workpiece. "Probing a WCS offset" means driving the bit
until it touches a known feature, then telling the controller *"the offset for
G55 is right here"*. From then on, `G55` followed by `X0 Y0` means that corner,
and the controller does the arithmetic. Downstream, nothing else needs to know:
the G-code is written in work coordinates and stays valid even if the fixture
moves, provided the offset is re-probed.

The point for this review: **the offsets live in the controller, and F360 decides
which one each setup uses.** Neither of those is the post's property.

## 4. Firmware parity on WCS — **REWRITTEN.** All three have registers, and RepRap has nine

Two claims here were wrong, and the author challenged both. Both challenges were
right. Corrected table, all of it now traced to firmware source or vendor docs:

| | Select a WCS | How many | Write an offset | Persists? | Machine coords |
|---|---|---|---|---|---|
| **GRBL 1.1 / FluidNC** | `G54`–`G59` | **6** | `G10 L2 P<n>` (absolute) or `G10 L20 P<n>` (here) | **Yes** — EEPROM, always | `G53` |
| **Marlin** + `CNC_COORDINATE_SYSTEMS` | `G54`–`G59`, `G59.1`–`G59.3` | **9** | **`G5x` then `G92`** — the active one only | **Yes** — with EEPROM | `G53`, same gate |
| **RepRap / Duet** | `G54`–`G59`, `G59.1`–`G59.3` | **9** | `G10 L2 P1`–`P9` / `G10 L20` | **Yes** | `G53` |

### 4a. Correction 1 — RepRap has nine, not one

> *"Are you sure RepRap doesn't also have extended WCSs?"*

**It has nine, and this page conflated a post's limitation with the firmware's.**
RepRapFirmware supports nine workplace coordinate systems: `G54`–`G59` for 1–6 and
`G59.1`/`G59.2`/`G59.3` for 7/8/9, set with `G10 L2 P1`–`P9`. `[DOC]` Duet3D
GCode dictionary.

What has `range:[1, 1]` is **Autodesk's stock `reprap.cps`** (`:115-118`) — one
post author's choice to expose a single offset, which tells us nothing about the
firmware. My original text let that declaration stand in for a firmware fact. It
does not.

**And the post under review already had this right.** Its own error text reads
*"GRBL supports G54-G59, RepRap G54-G59.3"*
([MPCNC_v4.0_Beta2.cps:1887](MPCNC_v4.0_Beta2.cps#L1887)) and it gates slots 7–9
on RepRap at [:1709](MPCNC_v4.0_Beta2.cps#L1709). So on this point the post is
**more accurate than Autodesk's own RepRap post**, and more accurate than the
first draft of this page. Nothing to change in the code; the correction is mine.

### 4b. Correction 2 — Marlin has nine WCS registers, they persist, and the write idiom is `G5x` + `G92`

> *"Reconsider the answer to 1.3 / E1… If that is a true statement then they should
> be utilized."*

**Accepted, and it is a true statement.** Marlin's own source, verbatim
(`Marlin/src/gcode/geometry/G53-G59.cpp`, 2.1.x) `[DOC]`:

```cpp
/**
 * G54-G59.3: Select a new workspace
 *
 * A workspace is an XYZ offset to the machine native space.
 * All workspaces default to 0,0,0 at start, or with EEPROM
 * support they may be restored from a previous session.
 *
 * G92 is used to set the current workspace's offset.
 */
void G54_59(uint8_t subcode=0) {
  const int8_t _space = parser.codenum - 54 + subcode;
```

`MAX_COORDINATE_SYSTEMS` is **9** (`Marlin/src/gcode/gcode.h`), declaring
`static xyz_pos_t coordinate_system[MAX_COORDINATE_SYSTEMS];` — and `G59` passes
`parser.subcode`, so `G59.1`–`G59.3` reach indices 6–8. **Marlin has the same nine
slots as RepRap.**

And `G92` writes into the register, not merely into live position
(`Marlin/src/gcode/geometry/G92.cpp`) `[DOC]`:

```cpp
#if ENABLED(CNC_COORDINATE_SYSTEMS)
  if (WITHIN(active_coordinate_system, 0, MAX_COORDINATE_SYSTEMS - 1))
    coordinate_system[active_coordinate_system] = position_shift;
#endif
```

So each of the four sub-claims resolves:

| Claim | Verdict |
|---|---|
| Marlin has per-WCS registers | **True** — nine of them |
| They are addressable individually | **True** — `G54`…`G59.3` |
| They survive a power cycle | **True with EEPROM** — *"with EEPROM support they may be restored from a previous session"* |
| They can be written | **True, but only the active one, and only positionally** |

**The `[INFERRED]` "RAM-only" reconciliation I offered last round was wrong.** I
proposed that Marlin's array had no addressable per-slot write and no persistence.
The source says the opposite on both counts. Withdrawn.

### 4c. The one real difference that remains, and it is narrower than "single frame"

GRBL and RepRap can write **any** register from **anywhere**: `G10 L2 P2 X.. Y.. Z..`
sets G55 while the tool sits in G54, without moving. Marlin cannot. On Marlin the
only write is `G92`, which means *"call where the tool is standing **this**"* — so
to set a register you must **be in that frame, at the point you are naming.**

Two consequences, and they point in opposite directions:

1. **For *selecting* offsets — which is all a multi-WCS job needs — Marlin is at
   full parity.** A post emitting `G54` … `G55` … `G56` works identically on all
   three firmwares, because the operator set those registers beforehand and the
   controller does the arithmetic. **This is what stock posts do and all they do**
   (§3). So the post's Guard C, which refuses to post a multi-WCS job on Marlin at
   all, is **refusing something Marlin can do.**
2. **For *writing* origins the difference is real but the post already handles it.**
   The post writes an origin at the moment it has just probed or arrived at that
   point — so it is *in* the frame, standing at the spot, which is exactly `G92`'s
   precondition. `G10 L20 P<n>` on GRBL is the same "here" semantic. The dialect
   table (`G10 L20` vs `G92`) is all the branching this needs.

### 4d. A hazard to carry forward: Marlin `G92` and machine space

`[DOC]` MarlinFirmware/Marlin issue **#14743** reports that `G92 X0 Y0` inside
`G54` also shifted the `G53` machine origin, while the same command inside `G55`
did not. The issue is **closed**, and the resolution is not legible from the page.

I could not establish which version fixed it, and that cannot be settled without
reading a specific Marlin tag's source against a specific V1 build. It is exactly
the interaction the post would depend on if it ever combined a machine-Z reference
with `G92`-written origins on Marlin.

**This is the technical reason behind the author's instruction that the user docs
must state a minimum firmware version** — the feature is a build option *and* has
had a machine-frame-corruption bug in it. `00-facts-needed.md` carries this as the
one open Marlin question; `09-plan.md` Phase 2 makes pinning the version a
prerequisite rather than a documentation afterthought.

### 4e. Conclusion on branching, revised

Firmware-specific WCS handling is justified in exactly **three** narrow places:

1. the `wcsDefinitions` declaration;
2. the command used to *write* an offset — `G10 L20 P<n>` vs `G5x` + `G92`;
3. the **slot count**: 6 on GRBL, **9 on both Marlin and RepRap** — so the
   RepRap-only gate at [:1709](MPCNC_v4.0_Beta2.cps#L1709) should become
   "not GRBL", not "RepRap only".

It is **not** justified by any difference in whether work coordinate systems
exist, how many are addressable, or whether they persist. **All three firmwares
have real, persistent, individually selectable work offsets.** Every remaining
branch needs its own evidence, and Guard C no longer has any.

## 5. Tool changes — what F360 drives, and what a stock post does

The whole of `writeToolCall` (`grbl.cps:1539-1574`) is 35 lines. The relevant
part:

```javascript
if (tool.manualToolChange) {
  onCommand(COMMAND_STOP);
  writeComment("MANUAL TOOL CHANGE TO T" + toolFormat.format(tool.number));
} else {
  if (!isFirstSection() && getProperty("optionalStop") && insertToolCall) {
    onCommand(COMMAND_OPTIONAL_STOP);
  }
  onCommand(COMMAND_LOAD_TOOL);
}
```

Around it: retract Z, optionally home XY (`false` by default on tool change),
coolant off, cancel length compensation.

The important facts:

- **`tool.manualToolChange` is a flag F360 supplies.** The operator sets it in
  F360, per tool. The post does not decide, detect, or infer that a change is
  manual — it is told. Question `B6` is **largely RESOLVED**: the mechanism is
  F360's, not the firmware's, and nothing in the stock post branches it by
  dialect.
- The manual path is **`M0` plus a comment**. That is the entire hobby-relevant
  tool change in Autodesk's own post.
- `insertToolCall` — whether this section needs a tool change at all — is derived
  from F360's section data, not computed by the post.

What remains genuinely open is what F360 emits *around* the change in a real
full-licence program: whether it retracts on its own first, and whether it
re-approaches afterwards (`B5`, `B3`). The stock post retracting Z itself
(`grbl.cps:1543-1547`) suggests F360 does **not** guarantee it, which is a point
in favour of a post doing that much.

### 5a. Tool length offsets — the author is right, and the difference decides who can do a tool change

> *"while it is true there is rarely an auto tool changer, the firmwares, except
> Marlin, do provide a method of establishing a TLO."*

**Correct.** `design.md`'s bare *"no TLO"* is too strong. But the three firmwares
differ so sharply that they give three different answers to S13, not one:

| | TLO mechanism | Tool table | Can the machine compute one? |
|---|---|---|---|
| **GRBL 1.1 / FluidNC** | **`G43.1 Z<offset>`** dynamic TLO, `G49` cancels | **No** — by design | **No** |
| **RepRapFirmware** | **`G10 L1 P<tool> Z<offset>`**, real tool offsets | **Yes** | **Yes** |
| **Marlin** | **None** | No | No |

- **GRBL has `G43.1`.** *"Grbl supports the G43.1 dynamic TLO and G49 TLO cancel
  commands… G43.1 requires an additional axis word with the offset value
  attached… so that Grbl does not have to track and maintain a tool offset
  database in its memory."* `[DOC]` gnea/grbl wiki. The offset must arrive **as a
  literal number in the G-code**.
- **RepRap has a real tool table.** `G10 L1 P2 X.. Y.. Z..` sets tool 2's offset,
  and *"tool offsets established by probing are saved automatically to
  `override-config.g` using `M500 P10`"*. `[DOC]` Duet3D GCode dictionary.
- **Marlin has no CNC TLO at all.** `M851` is a Z-probe offset and `M218` is a
  hotend offset; neither is a tool length register.

**The consequence that matters, and it is the missing half of the Group 7b
answer.** A measured tool change needs three things: a probe, a *subtraction*, and
somewhere to put the answer. The firmwares split on the middle one:

- **RepRap can do the whole thing itself.** It has `G38.2`, real variables and
  conditional G-code (`var` / `set` / `if`, RRF 3.x), and `G10 L1` to store the
  result. A `tpre`/`tpost` macro set can execute a complete measured manual tool
  change with no help from the post and no help from the sender.
- **GRBL and FluidNC cannot.** `G43.1` needs the number, and **GRBL has no
  variables, no expressions and no arithmetic** — it is an RS-274 subset without
  `#` parameters. The subtraction must happen off-board: in the **sender's**
  tool-change macro (bCNC, cncjs, gSender, UGS all provide one) or in the
  operator's head.
- **Marlin cannot, and has nowhere to put the result even if it could.**

So there is no single "the post emits a tool change" answer. On one firmware the
work belongs to a machine macro; on two others it belongs to the sender or the
human. **What the post can do is identical in all three cases: stop in a known
place, and let the operator inject their own routine** — which Group 8's include
files already make possible. `09-plan.md` Phase 2 builds the answer on that.

### 5b. F360 WCS probing operations — the post refuses them, and that is right

> *"For a professional user, does the post support WCS probe operations?"*

**No. It refuses them explicitly, by design**, at
[MPCNC_v4.0_Beta2.cps:2470-2478](MPCNC_v4.0_Beta2.cps#L2470):

```javascript
function onCyclePoint(x, y, z) {
  if (isProbeOperation()) {
    cycleNotSupported();
    return;
  }
  expandCyclePoint(x, y, z);
}
```

`isProbeOperation()` is defined locally at [:2460](MPCNC_v4.0_Beta2.cps#L2460) on
two independent signals — `operation-strategy == "probe"` and a `cycleType`
prefixed `"probing"` — and the comment gives the reason for the refusal: probing
*"cannot be faked by expansion, which would emit plain G0/G1 moves with no G38 at
all."* That is the correct call: a silent expansion of a probing cycle drives the
tool into the work at feed rate.

**And it should stay a refusal, for the same reason as §5a.** An F360 WCS probing
operation asks the control to probe several points, **compute** a midpoint, corner
or bore centre, and store the result in a work offset. The computation is the
whole operation. GRBL and Marlin have no arithmetic, so the operation is not
merely unimplemented on them — it is **unimplementable**. Only RepRapFirmware
could host it, via meta G-code, and only by generating machine-side macros rather
than G-code.

The one improvement available is the **message**. `cycleNotSupported()` emits
Autodesk's generic text. Naming the reason — *"WCS probing needs arithmetic in the
controller, which GRBL and Marlin do not have; use the post's own Z touch-off, or
set the work offset by hand"* — turns a dead end into an instruction. That is a
one-line change, and it is on the Phase 0 list in `09-plan.md`.

## 6. `C2` is closed — F360 says it in the file

The previous version of this section said Group 3's premise *"stays `[INFERRED]`
until someone posts Job C"*. **It is now `[SDK]`-grade**, from F360's own emitted
header (`OneDrive/Documents/Hobbies/Coding/GCode/Andrew.gcode:1-10`, posted
2023-12-27 by an earlier version of this post):

```
;Fusion 360 CAM 2.0.17954
; Posts processor: MPCNC.cps
;When using Fusion 360 for Personal Use, the feedrate of
;rapid moves is reduced to match the feedrate of cutting
;moves, which can increase machining time. Unrestricted rapid
;moves are available with a Fusion 360 Subscription.
```

**F360 states the behaviour itself, in the output.** `C2` is **RESOLVED**, and
Group 3's premise is confirmed by the vendor rather than by community belief.

Note the exact wording, because it names the mechanism precisely: *"the **feedrate**
of rapid moves is reduced to match the feedrate of cutting moves."* The move is
still a rapid as far as F360's own bookkeeping goes — what changes is the feedrate
it arrives with. That is why the post can recover them at all: the movement type
still reads `MOVEMENT_RAPID`, and the same file's property dump shows the two
switches that act on it — `Map: First G1 -> G0 Rapid = true`, `Map: G1s -> G0
Rapids = true`. The recovery is **reading a flag F360 still sets**, not guessing
from geometry. Group 3 is not a heuristic.

The `[POSTED]` files confirm the same signal survives today: `HB-12(A).gcode`
shows `( MOVEMENT_RAPID)` immediately above `G0 Z15.24 F300`.

## 7. What is still open

| Question | State |
|---|---|
| `C2` — rapid conversion | **CLOSED** — F360's own header, above |
| `A2`, `A3`, `A4` — absolute vs `G53`, how many heights appear, `G0` vs `G1` between operations | **Partly closed** by the 24 `[POSTED]` files — but every one is a *single-operation* job, so the between-operations half is untouched |
| `B2`, `B3` — what F360 emits at a *setup* boundary and whether it re-approaches | **Open.** Needs a multi-setup job, which is Phase 1 |
| `B5` — does F360 retract before a tool change unprompted | **Open**, and full-licence-only |
| `C1`, `C3` — personal-licence one-operation limit, licence tell in the header | `C3` **closed** — the banner above *is* the tell. `C1` still open |
| **Marlin minimum version for `CNC_COORDINATE_SYSTEMS` + issue #14743** | **NEW, open** — §4d. Blocks the Marlin multi-WCS claim |
| `D1`–`D4` — operator practice | Not a software question. See `04-user-stories.md` N2 |

### What the 24 posted files did settle

They are the review's first direct look at emitted output, and four things stand
out:

1. **The `>>> WARNING:` channel works and is doing real duty.** `HB-9(A).gcode`
   opens with *"`Home at Job Start` is on but `Axes Homed and Trusted` is None --
   nothing was homed"*; `HB-13(A)-off.gcode` carries the full no-Z-reference
   warning into the file. The warn-don't-compute principle is **already
   implemented and observable**, not merely recommended.
2. **`G10 L20 P1` is emitted as designed** — `G54` … `G10 L20 P1 X0 Y0 Z0`, then a
   probe sequence writing `G10 L20 P1 Z0.8` (the probe thickness). The Z touch-off
   path is verified output, not theory.
3. **Five failures are visible in the directory.** Three (`HB-7`, `HB-15`,
   `HB-17`) died before emitting a line — a 51-byte
   `!Error: Failed to post data.` Two got most of the way: `HB-12(A)` stopped at an
   empty include file, `HB-16(A)` stopped just after the coolant warning. Each has
   a passing sibling, so these are a **record of a debug loop**, not open bugs —
   but they show `error()` aborts land where intended.
4. **Every one of the 24 is a single-operation, single-tool, single-WCS job.**
   `T171` only, one `SECTION`. This is a precise measure of the test gap: the
   hobbyist path has 24 posted files behind it, and **the multi-WCS path still has
   zero.** It corroborates `PReview.md` §3.1 exactly.
