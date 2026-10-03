# Comment review — proposed rewrites

The working list behind `RV-14`, `RV-15` and `RV-16` in `findings.md`. **Delete this file in the
commit that closes `RV-15`**; until then an entry is deleted as it is applied, so what remains is
what is owed.

**Line numbers are `MPCNC_v4.1.1_Beta3.cps` at `776a0e5`.** Any edit to the post moves them — apply
from the bottom of the file up, or re-find each block by its text.

## The rule each proposal was held to

- **No comment grows.** Every proposal is no longer than the comment text it replaces, indentation
  and `//` excluded, counted by script over all 230 entries.
- **Firmware source citations** (file and version) are kept word for word — except L1036's, which
  names the wrong file and is corrected.
- **`// TWIN #n` markers and the `// TWIN: ` prefix** are kept word for word; the reason after
  `TWIN: none --` may be shorter.
- **The why stays; the story goes.** History that is what stops a removed bug coming back is restated
  as a present-tense constraint — *not X, because …* — rather than deleted.
- **`tools/comment-rules.js`'s four rules** hold for every proposal, including the 15 blocks that
  break them at `776a0e5`.

## Codes

`W` wrong or stale against the code · `H` narrates history · `J` private jargon a cold reader cannot
decode · `D` dense, needs a second read · `C` capitals for emphasis · `L` long for what it says ·
`R` restates the code · `I` bare finding ids · `N` double negative · `T` typo or grammar

**Totals:** 458 blocks read, 230 flagged — `J` 80, `C` 79, `D` 78, `H` 66, `I` 41, `W` 38, `L` 36,
`R` 15, `T` 9, `N` 2. Flagged text 71,195 → 52,385 characters, 26% shorter.

**Three entries are not ready to apply as written**: L1761-1763 carries an unverified firmware claim,
named in its entry; L5052-5053 is no change, its comment true once `RV-01` lands; and L3120, L3398 and
L3624 are `RV-08`'s typos, listed here so one pass takes them.

---

## Region 1-930
Blocks reviewed: 43 · fine: 19 · flagged: 24 · chars before → after (flagged only): 10463 → 7350

### L32 (trailing) · L D · 111 → 97
Problem: parenthesised aside carries the reason; the reason can be the sentence.
Proposed:
// split arcs >180 deg: a full circle posts as two arcs, since some firmware mishandles start == end

### L36-41 · D L · 543 → 367
Problem: "That refusal is theirs to need, their 0 emitting no G5x at all" needs a second read; the first sentence buries what the object is for.
Proposed:
// Fusion's UI shows each section's work offset as its G-code, not a bare index. useZeroOffset is inert:
// only Autodesk's validateCommonParameters() (include_files/commonFunctions.cpi) reads it, to refuse a job
// mixing offset 0 with a higher one, as their 0 emits no G5x. This post's 0 is G54, so only 0 beside 1 is
// ambiguous, and mixedDefaultAndExplicitWcs() warns about it.

### L60 · T D · 46 → 37
Problem: "indexof" is not the method name, and the phrasing is backwards (the array's order is the priority).
Proposed:
// Priority order; compared by indexOf()

### L81-85 · C L · 403 → 295
Problem: "IS" for emphasis; the load-order sentence is wordier than its rule.
Proposed:
// Fusion's numeric tool.coolant -> coolant name; the index is the F360 constant (0 COOLANT_DISABLED, 1
// FLOOD, 2 MIST, 3 THROUGH_TOOL, 4 AIR, 5 AIR_THROUGH_TOOL, 6 SUCTION, 7 FLOOD_MIST, 8 FLOOD_THROUGH_TOOL),
// so never sort it. Built from eCoolant at load time, so eCoolant must be declared above it.

### L90-92 · J C · 276 → 239
Problem: "Guard then augment key by key" is shorthand for "keep any existing object, add keys"; KEY in capitals. Block precedes an `if`, so it stays at 3 lines.
Proposed:
// Dialog groups (Post Processor Guide 5.1.5). A property's `group:` is a key here: `order` places the
// group, `title` is what the operator reads. Keep any existing object and add keys one at a time --
// assigning a whole literal would discard it.

### L125-126 · H · 198 → 152
Problem: opens with what the field "was"; the live point is why the key differs from the old one.
Proposed:
// A new key, not the old boolean's: a stored true/false is not an enum id. A saved setting falls back
// to the default, which behaves as the boolean shipped.

### L142 · W · 97 → 91
Problem: stale -- group 1's orders are 10, 20, 25, 30, 40, 50, 80, so 60 and 70 are free; the real reason for 25 is to sit under Spindle Control (20), the field that reads it (as L783 says of 45/65).
Proposed:
// 25: it sits under Spindle Control, which reads it, without renumbering the rest of group 1.

### L176-182 · H C I · 488 → 331
Problem: narrates the replaced boolean-plus-companions design, "ONE" in capitals, and "HB-20's shape" means nothing to a cold reader.
Proposed:
// One field over three answers, not a boolean with two companion fields that did nothing while it was
// off -- the default -- so the dialog asked for numbers no file would carry.
//
// A new key, because a stored true/false is not an enum id: a saved setting falls back to Off, what the
// boolean shipped. See the note at the head of this object.

### L271-275 · H C I · 395 → 291
Problem: "since PC-6" and "has always claimed" are history; ONE/NO in capitals.
Proposed:
// One enabling control and no field of its own. Group 3 answers one question -- is the Personal edition
// turning this job's rapids into cuts, and may the post turn them back? Its height is group 5's Safe Z,
// one property read by both groups; the note above probeSafeZ says why that is one meaning.

### L286-293 · J D · 658 → 570
Problem: "which onRapid() reproduces" and "both channels" are opaque; the last sentence is inverted ("Out of the dump it would cost...").
Proposed:
// The one test hook in this file: group 3 is otherwise unreachable by an automated run, since a paid
// licence delivers every rapid to onRapid() and isSafeToRapid() is never consulted. On, it makes
// onRapid() forward rapids as feed moves, as the Personal edition delivers them.
//
// No "group" key, deliberately: writeAllProperties() skips it, so a normal job's dump is unchanged, and
// "visible: false" keeps it out of the dialog -- Autodesk's idiom (Data/Posts/tormach.cps, post kernel
// 5.388.0). Being absent from the dump, validateJob() announces it in the file and in Fusion instead.

### L318-322 · J C D · 468 → 386
Problem: "the frame" used as a term of art; AND / STRING / NO FRAME in capitals; the placement sentence is roundabout.
Proposed:
// Filling this is the opt-in, with no enum or boolean beside it: the machine Z reference exists when Z
// is declared homed and this parses (fixedZEstablishedInFile()). It is in this group because it means
// nothing without that homing declaration. A string, not a number: empty means no Z reference, and a
// numeric property has no unset state -- every sentinel, 0 included, is a reachable height.

### L408-416 · H C · 689 → 491
Problem: "was never two answers", "never had one key between them" are history; ONE/STRING/NOT in capitals.
Proposed:
// One field, not two: the offset is one displacement. A string, so it takes the same "X, Y" syntax as
// Manual Position X Y, through the same parseXYPair(). Unlike that field, empty has no meaning here:
// "0, 0" does, an unreadable value falls back to it, and validateJob() warns rather than refuses.
//
// A new key, not probeOffsetX/Y: a stored integer there is not this field's string. A saved setting
// falls back to the default 0, 0, what both old fields shipped. See the note at the head of this object.

### L453-463 · L C D · 913 → 649
Problem: long, capitals for emphasis (ONE, TWO, SAME, NO PARENTHESES IN THE TITLE), and "and now serves both" is history.
Proposed:
// One property with two readers, not two meanings on one field (design.md): both groups read a height
// that clears the work, in the part's work coordinates from the touch-off Z0. Group 3 asks "is the tool
// at or above it, so this G1 may become a G0"; group 5 retracts to it after the probe. Two different
// heights would mean rapiding through the height just called clear.
//
// The key keeps its "probe" name: every stored value still means the same height, and a rename would
// reset it. No parentheses in the title: writeSafeZFormatWarning() prints it and its group's title in an
// in-file warning, which strips them (sanitizeMessageText(_, "()"), via writeWarning()).

### L483-486 · J · 305 → 290
Problem: "hand over" is a term of art the comment never defines.
Proposed:
// The post performs no tool change on any firmware; this group says what it does instead. A measured
// change needs a probe, a subtraction and a register for the result, and the post has none. It arrives,
// hands control to the operator or a macro, and resumes correctly. design.md -> Tool changes.

### L493-496 · W L · 344 → 260
Problem: stale -- five tools pass toolChangeMode (correct-gcode, gcode-structure, hobbyist, professional, wcs matrices), not four; and "Nothing an operator sees says Pause" is untrue as written, since the title reads "Manual change at a pause".
Proposed:
// Titles say who acts and what happens; ids are stored values, not display text. Fusion saves the id and
// the tools/ matrices pass it on the command line, so changing one resets saved settings, alters every
// saved property dump and rewrites every case that names it.

### L531-543 · H C L · 1035 → 626
Problem: most of the block narrates the replaced Tool Change X/Y/Z fields; the live rule (machine coordinates, so the spot does not move with the part origin) is the last sentence of the first paragraph.
Proposed:
// Where the manual change happens, in machine coordinates (G53) rather than work coordinates, so the
// spot does not move with each part origin. X and Y are one "X, Y" field because they are one point; Z
// is its own because it is set alone. Strings, because empty means "do not move" -- as Machine Travel
// Z's empty means no Z reference -- and every numeric sentinel would be a reachable coordinate.
//
// A new key, not toolChangePositionX: a stored "-10" there was one axis, which this parser rejects as a
// pair. A saved setting falls back to the shipped empty -- the change happens above the last cut. See
// the note at the head of this object.

### L562-566 · H D · 487 → 312
Problem: "the old shipped behaviour", "under the old key" -- history; the second sentence needs a second read.
Proposed:
// A declaration, not a prompt: the operator knows whether the fitted tool is the job's first; who fits
// it otherwise is At a Tool Change's answer. A new key because the sense inverted -- a saved `true`
// meant "prompt me" and here would mean "no action" -- so it resets to the default: no prompt, nothing
// emitted. PV-13.

### L576-580 · H J I · 479 → 276
Problem: "The boolean this replaced..." and "So it treated..." narrate the old bug; "frame correction" / "register one" are jargon; PV-10 sits mid-sentence.
Proposed:
// Three answers, because they differ for a multi-part job: a tool-length offset shifts Z for every
// part, so every stored Z0 stays valid, while a re-probe or a hand-zero corrects only the active part.
// design.md -> Tool changes. A new key: a stored boolean is not an enum id. PV-10.

### L595-596 · H C · 189 → 133
Problem: "Keys are unchanged, so no saved setting resets" is history; ADD/REPLACE in capitals.
Proposed:
// These add to the tool-change sequence, where group 7's two files replace the header and footer, so
// they sit here and not beside those.

### L662-671 · H C L · 802 → 396
Problem: narrates the two replaced fields and the old Marlin default; ONE in capitals.
Proposed:
// One field, not one per firmware: CNC Firmware reads only one dialect. Each value's title carries its
// dialect, as group 9's do, and outputCodeFirmware() reads it off the title so no second list can drift.
//
// A new key: the old fields' ids clash ("M3" was Marlin's spindle form, "3" is GRBL's static power), so
// a stored value would be misread. The default is a GRBL value because CNC Firmware ships Grbl.

### L758-766 · H I C · 702 → 384
Problem: "unlike PC-1's and PC-2's" is a bare-id history comparison; "What changed is..." narrates; ONE/FILE/NOT in capitals.
Proposed:
// One field per channel: the on code fixes the off code. M106 and M42 close with S0 on the same output,
// a custom on closes from the channel's own Off Custom file, and on GRBL M9 is the only off code.
// coolantOffCode() is the derivation, stated once.
//
// Keep the key: every stored id is still legal and means the same output, now in both directions, so a
// saved configuration carries over intact.

### L855-859 · D · 479 → 352
Problem: the first sentence's "because the field is the operator's to set and the two generations take different forms" is packed; reorder around the rule.
Proposed:
// Both RRF 3.x and 2.05 forms are described: 3.x moved spindle setup from M453 into M950/M563, and
// M452's pin from P/I to C"pin". The defaults are the 3.x forms and name no pin -- a missing pin means
// the laser never fires, a wrong one drives an output the operator did not choose. One command per
// field: the string goes through a single writeBlock(). PR-13.

### L903-906 · C · 330 → 301
Problem: ONE / OTHER / IS in capitals. Content verified: tFormat's only uses are the three writeBlock() calls inside toolChangeMacroCall().
Proposed:
// One consumer, toolChangeMacroCall(), and it is not a tool change: the T word is emitted only where
// something other than this post acts on it -- a sender intercepting the M6, FluidNC executing that M6
// itself, or RRF, whose T word is the change. Elsewhere the tool is named in a prompt the operator reads.

### L910 (trailing) · W · 26 → 24
Problem: stale -- onDwell() clamps to 0.001-99999.999, not 1000.
Proposed:
// seconds, 0.001-99999.999

## Region 931-1557
Blocks reviewed: 55 (49 full-line blocks incl. 5 banners, 6 trailing) · fine: 32 · flagged: 23 · chars before → after (flagged only): 7212 → 4626

### L931-934 · J D H L (R3 breach) · 335 → 187
Problem: "The fold", "neither carries an enum id" and "what is left is the two conventions" are history and jargon; 4 lines where R3 allows 3.
Proposed:
// Line numbering, read off one property so writeBlock() and resetPostState() cannot disagree. Both on
// values start at N10 and differ only in step: 1, or 10 to leave room for inserted blocks.

### L987-988 · H I · 181 → 111
Problem: "One property feeds it since PC-6, and the syntax outlived the pair" is history.
Proposed:
// Parse a Safe-Z expression -- a bare number, or Feed:/Retract:/Clearance:<fallback> -- into
// { mode, dflt }. Pure.

### L993-993 · R · 74 → 72
Problem: Lists the regexes the table already holds; the useful fact is how the loop ends.
Proposed:
// The first regex that matches picks the mode; none matching leaves ERROR.

### L1000-1000 · R · 43 → 0
Problem: Restates the if.
Proposed:
(delete)

### L1016-1017 · L · 180 → 130
Problem: "The one parse, for the one property" carries no information.
Proposed:
// Parsed once per file. Group 5's retract after a probe and group 3's G1-to-G0 threshold both take
// their mode and fallback from here.

### L1023-1024 · H C · 177 → 104
Problem: "which is where the map side used to raise it" is history; ONCE PER FILE is shouted.
Proposed:
// Warned once per file, here where the parse fails, not once per section. validateJob() warns at post
// time.

### L1034-1036 · W H · 239 → 155
Problem: There is one Safe-Z property and one caller (line 1026); "both Safe-Z parse failures" and "two properties that document each other" are stale. The citation is wrong and is corrected: grbl 1.1h strips comments in protocol.c, protocol_main_loop(), and gc_execute_line() never sees them.
Proposed:
// The in-file Safe-Z format warning. No brackets in the text: grbl 1.1 does not nest comments and ends
// one at the first ")" (grbl/protocol.c, protocol_main_loop(), v1.1h).

### L1043-1048 · H I L D · 536 → 196
Problem: Four of six lines narrate the removed seventy-line switch and PC-6.
Proposed:
// Group 3's per-section Safe Z, cached in safeZHeight because isSafeToRapid() is asked once per move
// and must not re-resolve. A missing level and a relative one both report "not usable": same remedy.

### L1069-1076 · L · 654 → 501
Problem: Sound content, wordier than needed; the second paragraph takes two lines to say one thing.
Proposed:
// Resolve a parsed Safe-Z expression against one section's F360 levels, returning {height, fromLevel}:
// the height in the OUTPUT unit, and whether it came from the operation's own level. Feed/Retract/
// Clearance use that level when it is defined and absolute, else the fallback. Units differ: an F360
// level is already in the output unit, the dialog fallback is mm and is converted here. Pure.
//
// safeZforSection() reports fromLevel, so a job cutting to a fallback where the operator meant their
// own level says so.

### L1148-1149 · H · 179 → 140
Problem: "so a Z of 1e-7 built ... and the whole expression came back NaN" narrates the bug; restate as the constraint.
Proposed:
// Plain arithmetic, not the string-exponent trick: JavaScript writes magnitudes below 1e-6
// exponentially, so "1e-7" + "e+3" would parse as NaN.

### L1204-1209 · J D (R3 breach) · 406 → 294
Problem: 6 lines where R3 allows 3; "on every arm" is jargon.
Proposed:
// Shared by spindle, laser and both coolant channels. S always, off included: a bare M106 P{n} only
// reports on RepRapFirmware (Fan::Configure, src/Fans/Fan.cpp 3.5-dev) and M42 needs S. Never M107: RRF
// ignores its P and zeroes the tool's fans (GCodes2.cpp case 107); S0 is what M107 does on Marlin.

### L1229-1240 · W H C L (R3 breach) · 848 → 401
Problem: Says writeFanOrPinOutput() builds the S from `on`; it takes a ready pwm, and writeCoolantChannel() picks 255/0 (line 1265). "There was never a second decision" is history. 12 lines where R3 allows 5.
Proposed:
// The off code a channel's on code implies, stated only here. M106/M42: the same command and output
// with S0 (writeCoolantChannel() picks the S). M7/M8: M9, GRBL's only off code; it stops every coolant
// output, harmless because setCoolant() turns both channels off before turning either on. Use custom:
// the channel's own Off Custom file. Total over the dropdown's values, so a new one gets an off code. Pure.

### L1252-1255 · H D · 387 → 289
Problem: "the third branch below would otherwise have been written twice" is history; the last two sentences need a second read.
Proposed:
// One body for both channels and both directions. Three kinds of value: "Use custom" names a file,
// "M106"/"M42" name an output numbered by the channel's own field, and any other id is the g-code
// itself, which is why the GRBL ids stay literal. The direction picks the code off the one property.

### L1284-1285 · W T · 166 → 126
Problem: "is being using" is a typo; "SetCoolant" is setCoolant(); it is passed eCoolant.Off ("Off"), not 0.
Proposed:
// Two coolant channels, each tracking the level it is running (Off = idle). setCoolant() takes the
// level wanted, or eCoolant.Off.

### L1287-1287 · W · 33 → 25
Problem: Trailing comment. curCoolant is the level actually switched on: setCoolant() sets it Off first and leaves it Off when no channel Mode matches the request.
Proposed:
var curCoolant = eCoolant.Off;        // The level now switched on

### L1291-1293 · I C · 290 → 193
Problem: HB-5 and PV-12 mid-sentence; JET shouted.
Proposed:
// What a tool asks for, in one place, so onCommand(COMMAND_COOLANT_ON) and validateJob()'s pre-flight
// cannot disagree. F360 gives a jet tool no coolant, so it takes the laser group's forced level.

### L1356-1359 · H J W (R3 breach) · 403 → 226
Problem: "where the firmware used to be", "no longer says which arm" are history; "the Marlin fan and pin values take a byte" omits the M3 value, which the code also scales to 255. 4 lines where R3 allows 3.
Proposed:
// The PWM scale follows the chosen output, not the job: GRBL's two values drive S against $30, scaled
// 0..1000 by this post; the Marlin/RepRapFirmware values take a 0..255 byte. validateJob() checks the
// output against the firmware.

### L1368-1369 · W C · 158 → 100
Problem: Line 1211 hands mFormat.format() a computed number (`mode == "M42" ? 42 : 106`), not a literal; STRINGS shouted.
Proposed:
// Number(): the GRBL ids are strings ("4" / "3"), and mFormat.format() takes a number everywhere else.

### L1392-1392 · J · 76 → 68
Problem: "arm" is jargon, and the M3 value serves RepRapFirmware as well as Marlin.
Proposed:
// M5 stops all three spindle-style values: GRBL's two and the Mrln M3.

### L1421-1427 · J D L · 620 → 500
Problem: "no establish runs" and "multiWcs goes false" (a local of validateJob()) are undefined here; the last sentence needs a second read.
Proposed:
// True where one section uses work offset 0 and another 1 -- two labels on one register. Fusion reports
// 0 for a Setup on the default, chosen or not, so both alias to G54 as in writeWCS(). The result is not
// a wrong code: the post sees one part, never sets up a second origin, and the second Setup cuts on the
// first one's. Every pair is compared; Autodesk's validateCommonParameters() tests only the first
// section against the rest (grbl.cps, Rev 45769), missing a job whose first section is the explicit one.

### L1456-1459 · H D · 396 → 241
Problem: "with two laser fields a GRBL job could never ..." is history; the sentence needs a second read.
Proposed:
// True where any section cuts with a jet tool -- laser, plasma or waterjet. It gates group 8's checks:
// a milling job emits no laser code, so its laser field cannot be wrong. Counted over sections, as
// countDistinctTools() is, for the same reason.

### L1470-1476 · W H L · 656 → 401
Problem: Example title "Mrln: M42 P6 S255" matches no value (the dropdowns say "Mrln: M42 P{pin} S255"); "since PC-4 ... never were coolant-specific" is history.
Proposed:
// The one place a dialect label means a firmware. Every built-in value of group 9's coolant codes and
// group 8's laser output carries its dialect in its title -- "Grbl: M7 (mist)", "Mrln: M42 P{pin} S255"
// -- so the checks read the operator's own choice rather than a second list of codes that would drift.
// Used both ways: a chosen code to its firmware, and a firmware to the prefix it should be picked from.

### L1512-1513 · H I W · 175 → 166
Problem: "Since GH-16d" is history, and the reason is partial: the Marlin ids are "M106"/"M42", and the laser GRBL ids "4"/"3" (line 2081 quotes the laser title) are where quoting the id says least.
Proposed:
// The display text of a code property's current value. Messages quote it, not the id, which for the
// laser's GRBL values is a bare "4" or "3" and never names the dialect.

## Region 1558-2460
Blocks reviewed: 67 · fine: 20 · flagged: 47 · chars before → after (flagged only): 13853 → 9694

### L1565-1566 · J H · 175 → 104
Problem: "the model the whole walk was marked against" and "written as one block from the start" are history; bare "R2" is ambiguous (comment-rules.js also has an R2).
Proposed:
```
    // TWIN: here -- both channels in one block; personal-matrix.js R2 asserts both, so neither can go quietly.
```

### L1574-1575 · R J C · 189 → 0
Problem: Duplicates the TWIN #8 block at 1593; "step 2 ... step 6" is a private numbering, and it sits over the var run, far from the check it explains.
Proposed:
```
(delete)
```

### L1584-1585 · J · 142 → 139
Problem: "the action set and the declaration above it never touched" makes the reader decode which settings are meant.
Proposed:
```
  // The likeliest group-4 slip: "Home at Job Start" on, "Axes Homed and Trusted" still None.
  // TWIN #7 -- the file half is writeMachineHoming()'s.
```

### L1593-1595 · J I · 271 → 244
Problem: "step 2 of writeFirstSection()" is an unlabelled count; "PV-4 is this pair's precedent" adds nothing here.
Proposed:
```
  // Either axis qualifies: X/Y homing destroys the pre-jogged XY, Z homing the height recorded as Z0. Homing
  // precedes the origin write in writeFirstSection() and cannot be reordered after it. CR-15.
  // TWIN #8 -- the file half is writeMachineHoming()'s.
```

### L1608-1609 · C D · 195 → 189
Problem: Capitals for emphasis; "hence the mode split" needs a second read, and the Current Pos modes are excluded too, not only "Jog".
Proposed:
```
  // A G54-G59 offset is measured from machine zero, which moves at every reset unless X/Y homes. Only modes
  // that trust a stored offset break; the "Jog" and "Current Pos" modes write a fresh one.
```

### L1628-1630 · J · 260 → 246
Problem: "The silence is the complaint" is a riddle; the id sits mid-sentence.
Proposed:
```
  // Warned for the silent overwrite -- the "Jog to ..." modes write the register too, but ask first. Not
  // refused: loose stock beside fixtured parts is a real workflow. CR-16.
  // TWIN #13 -- the file half is writeWcsOnStart()'s, on the same two predicates.
```

### L1642-1644 · I L · 248 → 182
Problem: Two ids mid-sentence; "the answer does not depend on where in the file it is noticed" is a long way to say job-wide.
Proposed:
```
  // Not refused: two Setups that share one fixture may be labelled this way. No file twin: the condition is
  // job-wide, and writeWCS() already writes the 0 -> 1 alias at Info. CR-16, PV-12.
```

### L1676-1677 · R · 187 → 93
Problem: Second clause repeats the Sender.js citation eight lines up.
Proposed:
```
      // "at the very top", not "the first line": on GRBL the travel-speed warning stands ahead of it.
```

### L1680-1681 · J · 188 → 173
Problem: "the hand-over" is a term of art; say the macro flow.
Proposed:
```
    // Not on a pre-jogged origin nor on the macro flow: toolChangeFirstLoad() writes no prompt on either, and
    // naming a line the file lacks sends the operator looking for it. PV-13.
```

### L1704-1705 · R · 184 → 86
Problem: First line says what the TWIN line under it says.
Proposed:
```
  // TWIN #15 -- the file half is toolChangeFirstLoad()'s, on the same originIsPreJogged().
```

### L1717-1719 · D J · 247 → 245
Problem: "must not be told to do something homing undoes" and "that arm moving the tool itself" both need decoding.
Proposed:
```
  // Two texts: where homing parks Z at its endstop the operator cannot set probe height; a macro
  // loading the first tool moves it after homing, so gets the second. PR-16.
  // TWIN #12 -- the file half is partProbe()'s, covering all four of its callers.
```

### L1722-1722 · J T · 77 → 65
Problem: Possessive riddle; indented 8 where the code it sits over is at 6.
Proposed:
```
      // Probe X/Y is the register's; only its start height is the tool's.
```

### L1761-1763 · J · 297 → 238
Problem: "the group-4 declaration is the trust assertion" and "decides in the operator's favour" are oblique. **Unverified:** stock grbl locks at boot only with homing enabled ($22=1, HOMING_INIT_LOCK) -- settle against grbl/config.h before taking this text.
Proposed:
```
  // "Home at Job Start" is not required for G53: declaring axes homed vouches for the frame, and the firmware
  // decides if that is enough. Only GRBL refuses, booting in Alarm until homed; Marlin's lock is the build
  // option NO_MOTION_BEFORE_HOMING.
```

### L1772-1774 · J · 204 → 202
Problem: "Both hand-over modes" -- the gate is Pause and Macro, and Pause hands nothing over.
Proposed:
```
  // Pause or macro, and a macro-loaded first tool, as on a one-tool job. PV-13.
  // TWIN #16 -- the file half is toolChange()'s, at the hand-over.
  // TWIN #18 -- and toolChangeMacroResume()'s, at the return.
```

### L1788-1790 · J C I · 277 → 267
Problem: "PV-7's post-time half" and "the same containment predicate" do not name the shared function; CAN/IS capitals.
Proposed:
```
  // Shares probePointMachinedBefore() with the file half but counts every boundary a probe can happen at,
  // not only those written: it over-reports, the safe side for a datum. PV-7.
  // TWIN #11 -- the file half is partProbe()'s, two hand-built predicates over the same sections.
```

### L1844-1844 · W J · 92 → 87
Problem: The block holds four warnings (intercept, FluidNC, RepRap, re-probe), not three; "Flow 2" is undefined here.
Proposed:
```
  // Macro-flow warnings: the post emits a token and cannot see whether anything acts on it.
```

### L1861-1863 · J I D · 274 → 225
Problem: "FR-1's other half", "CR-24's shape" -- ids used as nouns the reader must look up.
Proposed:
```
    // Unlike the intercept warning above, FluidNC never errors: it acts on M6 only where config.yaml says to,
    // so the failure is silence. The 3.9.0 bound is the changer's -- src/ToolChangers/ exists at v3.9.0 and
    // 404s at v3.8.0. FR-1.
```

### L1881-1883 · C I T · 268 → 229
Problem: "PR-25 is why" leads; TOOL in capitals; block indented 8 inside a 6-deep if body.
Proposed:
```
      // No machine-frame warning: RRF's G53 drops the tool offset as well as the workplace offset, so "Machine
      // Travel Z" is a carriage height there as on GRBL. DoStraightMove()/DoArcMove(), src/GCodes/GCodes.cpp,
      // 2.05 through 3.6.0. PR-25.
```

### L1897-1898 · W I · 144 → 56
Problem: "neither a twin of anything the file writes" is false: the second warning carries TWIN #17 (toolChange()'s Manual arm, line 5036).
Proposed:
```
  // Two job-wide warnings, each knowable at onOpen(). PV-10.
```

### L1923-1924 · C · 194 → 151
Problem: Shouted heading.
Proposed:
```
  // The manual change position's warned half: a valid file that may not do what the operator meant. The
  // half no machine can run is refused among the guards.
```

### L1941-1942 · H · 183 → 148
Problem: The reason is told as history; restate it as the constraint it protects.
Proposed:
```
    // Warned, not dropped: an ignored coordinate gets trusted unseen, as the removed Tool Change X/Y/Z was for
    // years while it moved with every part origin.
```

### L1952-1958 · R1 D C L · 686 → 500
Problem: Seven lines before an if; SENTINEL caps; the 0xff mechanics need two reads. Split: gate reason above the if, firmware facts above the warning() (each <= 3 lines).
Proposed:
```
  // No g-code sets the stepper idle timer, and one warning covers Grbl, grblHAL and FluidNC: the post's one
  // "Grbl" answer cannot tell them apart. Both change modes -- a macro hand-over idles the machine too. FR-2.
(inside the if, immediately above warning()
  // Grbl/grblHAL: st_go_idle() disables the drivers $1 ms after the buffer drains, default 25 (stepper.c,
  // defaults.h, Grbl 1.1). FluidNC: idle_ms under stepping:, default 255 (Stepping.cpp, v3.9.6). 255 means
  // never on both (Protocol.cpp:764), so stock FluidNC holds the axes and stock Grbl lets go.
```

### L1981-1987 · R1 I D C · 661 → 422
Problem: Seven lines before an if; three ids; "Neither the pull-off nor the build can be read" and the remedy restate the warning. Split as above.
Proposed:
```
  // GRBL only: Marlin re-homes here instead of rapiding, and an RRF machine homed to its minima already
  // rests on the coordinate this asks for. CR-10.
  // TWIN #6 -- the file half is writeMachineParkXY()'s, same firmware and same property.
(inside the if, immediately above warning()
  // One warning for both "Grbl" firmwares: FluidNC also rests one pull-off inside machine zero, set_mpos()
  // writing _mpos at the trigger point (FluidNC/src/Machine/Homing.h, Homing.cpp, v3.9.6). FR-2.
```

### L2002-2004 · J · 285 → 278
Problem: "the next file starts on nothing" -- starts on what?
Proposed:
```
  // set_axis_is_at_home() zeroes position_shift, never coordinate_system[] (Marlin motion.cpp,
  // 2.1.2.5) -- and a single-offset job never re-selects a register, so the next file starts zeroed.
  // TWIN #5 -- the file half is writeMachineParkXY()'s, gated on the same firmware and property.
```

### L2013-2014 · H C · 169 → 93
Problem: First line is pure history.
Proposed:
```
  // TWIN #1 -- the file half is writeSafeZFormatWarning()'s, which names the same 15 mm fallback.
```

### L2024-2027 · C L · 376 → 300
Problem: "IS", "NO FRAME" capitals; "here and not below because" is roundabout.
Proposed:
```
  // The same check on single-coordinate fields: parseMachineCoordinate() answers undefined for a typo as for
  // an empty field, and undefined means "not set" -- so "-12mm" in "Machine Travel Z" silently drops the
  // frame. "Manual Position Z" may be set alone, so it is here; the X Y pair has its own loop below.
```

### L2039-2042 · C L · 394 → 226
Problem: PAIR/IS capitals; the refusal clause is packed.
Proposed:
```
  // Again on the X Y pair fields, each naming its own fallback. Warned, not refused: the manual position's
  // bad pair is refused below only on the multi-tool manual flow that reads it, and 0, 0 -- the shipped
  // probe offset -- is legal.
```

### L2060-2071 · R1 H I C · 900 → 497
Problem: Twelve lines before an if; PC-4 history; WARNED/NOT capitals. Split: gate above the if, mismatch rule above `var laserId` inside it.
Proposed:
```
  // Group 8's dialect check: one laser field holds both dialects' values, so a mismatch is expressible.
  // Warned, as group 9's is below. Jet tools only -- a milling job emits no laser code whatever it holds.
(inside the if, immediately above var laserId)
  // Mismatch iff exactly one side is GRBL: the "Mrln:" values serve RepRapFirmware too (M106, M42 and M3
  // are emitted on both), so the coolant check's unlabelled-means-skip scoping would let a GRBL value pass on
  // RRF. Silent where the guard below refuses anyway, so one field draws one complaint, not two.
```

### L2088-2092 · L D I · 506 → 302
Problem: Line 2089 runs to ~170 columns; "CR-24's gate" as a noun; SHIPPED caps.
Proposed:
```
  // writeCoolantChannel() emits the chosen code with no firmware test. Only configured channels (Mode not
  // Off, the shipped value) are checked. Warned, not refused: the label says which firmware the code was
  // shipped for, not that no other takes it. RRF is skipped -- no value is labelled for it. CR-24, PV-12.
```

### L2106-2106 · H · 81 → 66
Problem: "since GH-16d" is history.
Proposed:
```
        // The title, not the id: a Marlin id is a mode name, not the g-code.
```

### L2111-2114 · R1 H · 347 → 109
Problem: Four lines before an if; the last two narrate an old wording ("It used to say ...").
Proposed:
```
    // One warning, not one per channel: both channels are set for one firmware, fail together, and share one
    // remedy.
```

### L2127-2129 · D W · 300 → 290
Problem: Says only M7, but the gate and the warning cover M8 too (FluidNC cuts dry on an undeclared flood_pin); the FluidNC clause is packed.
Proposed:
```
  // Neither "Grbl" firmware guarantees M7/M8. Stock grbl 1.1 compiles M7 only under ENABLE_M7, shipped
  // commented out, so M7 answers error:20 mid-section (grbl/gcode.c, v1.1h); FluidNC never errors, acting
  // only where a pin is declared (hasMist(), FluidNC/src/GCode.cpp 3.9.1), and cuts dry. CR-24.
```

### L2150-2154 · J D · 457 → 328
Problem: "CR-24's outcome by the other route" is an id as noun; "the channels carry codes for a coolant this job never asks for" states the condition from the wrong side.
Proposed:
```
  // The same dry cut by a route the post can see: the job asks for a coolant level neither channel Mode
  // carries. One warning per level, the remedy being per level. PV-12.
  // TWIN #3 -- the file half is setCoolant()'s, per occurrence. One deliberate difference: this pre-flight
  // is silent where both channel Modes are Off, that line is not.
```

### L2167-2168 · W · 194 → 153
Problem: "Every guard below applies on every firmware" is false: the M106/M42 refusal is GRBL-only, the macro refusal Marlin-only, and the RepRap-handler and GRBL-dialect refusals fire on a firmware mismatch.
Proposed:
```
  // --- Guards -----------------------------------------------------------------------------------
  // Refusals, most basic first; each returns after its error().
```

### L2170-2181 · H L I · 940 → 388
Problem: Half the block narrates removed fields (skipOnGrbl, the `off:` column, "went with the field").
Proposed:
```
  // The fan and pin output modes, in one table because groups 1, 8 and 9 own the same mistakes.
  // jetOnly: the laser field is read only by a section that fires a beam, so a milling job posts whatever it
  // holds. refuseOnGrbl: false on group 9, which warns instead -- the dialect warning above (PV-16).
  // No off code here: coolantOffCode() derives it from this row, so an on/off mismatch cannot be set.
```

### L2195-2195 · I · 97 → 84
Problem: "CR-24's gate" leads; "ships Off" means defaults to Off.
Proposed:
```
    // A channel whose Mode is Off is unconfigured, and its codes were never chosen. CR-24.
```

### L2246-2248 · W J · 226 → 179
Problem: There are four refusals in this block (Marlin; RepRap handler off RRF; GRBL-dialect handler off GRBL; empty "Other" file), not three; "Flow 2" undefined.
Proposed:
```
  // The macro flow's refusals: each is a hand-over to something that is not there. A first-tool hand-over
  // sends the same token to the same handler, so it owes the same refusals. PV-13.
```

### L2272-2275 · R1 H D · 302 → 203
Problem: Four lines before an if; "no longer all senders" is history; the dash-wrapped remedy needs a second read.
Proposed:
```
      // Two texts: FluidNC needs the GRBL dialect but no sender, so the sender text would name a party it lacks
      // and offer the wrong remedy, "Other". Only RepRap reaches here; the Marlin guard returns first. FR-1.
```

### L2306-2308 · W H · 279 → 130
Problem: "draws the same complaint as one left blank" is wrong: a blank field draws no complaint (the test is raw != ""); the rest narrates the removed half-filled case.
Proposed:
```
    // The raw field is tested because a typo parses to undefined, as a blank does, and would silently drop
    // the position the operator set.
```

### L2319-2320 · C · 186 → 177
Problem: Shouted first sentence.
Proposed:
```
      // The predicate the file reads: toolChangeMovesToPosition() answers false with no fixed Z reference, so
      // without this guard the fields would be accepted and then quietly not happen.
```

### L2349-2352 · W · 364 → 279
Problem: "the two OFF files are read at onClose()" -- setCoolant() takes both channels off at every coolant change, so an OFF file is read mid-job too; onClose() is only the latest it can first be read.
Proposed:
```
  // The four coolant files reach the same late error() through loadFile(), an OFF file possibly not until
  // onClose(). Gated on the enum beside each; an empty field warns in both channels. HB-7, CR-22, PV-12.
  // TWIN #2 -- the file half is writeCustomCoolantFile()'s, on the same enum gate.
```

### L2363-2365 · H · 292 → 114
Problem: "TWO entries where there were four" and "used to allow" narrate the old selectors.
Proposed:
```
    // One selector reaches both of a channel's files, so an unnamed OFF file is reported even where the ON
    // file is named.
```

### L2405-2407 · I C · 281 → 273
Problem: Leading id; BELOW caps.
Proposed:
```
    // ">= 0" because zero is the switch, not the ceiling: limits_go_home() ends one pull-off below the
    // trigger and system_check_travel_limits() rejects only target > 0 (grbl 1.1f). PR-17.
    // TWIN #9 -- the file half is writeFixedZReference()'s, on the same firmware and parsed height.
```

### L2423-2424 · C D · 197 → 154
Problem: "The homing half" is unnamed; RE-ESTABLISHES caps.
Proposed:
```
  // The Home-at-start test skips Marlin: its park (G28 X Y) re-homes instead of addressing the frame, so
  // needs no earlier homing -- unlike the Z retract above.
```

### L2436-2439 · H · 356 → 237
Problem: "Guard C is gone" -- restate the history as the constraint it protects.
Proposed:
```
  // No guard tells Marlin it has a single coordinate frame: gcode.cpp (2.1.2.5) puts G54-G59 in the same
  // #if ENABLED(CNC_COORDINATE_SYSTEMS) as G53, with G59.1-G59.3 -- nine selectable workspaces. Guard B
  // alone refuses a Marlin multi-part job.
```

### L2441-2443 · H J C · 298 → 271
Problem: "Unconditional since CR-13" is history; MUST caps; "on the frame" is jargon.
Proposed:
```
  // Guard B -- a multi-part job must have the fixed Z frame: no single clearance height is meaningful across
  // WCS whose origins are known only after probing at runtime. The X/Y test is here, not with the Z frame,
  // because the multi-part workflow is what needs a homed X/Y. CR-13.
```

### L2456-2459 · W H · 383 → 272
Problem: "onOpen() already did this for currentWorkOffset and sequenceNumber" is stale: onOpen() now calls resetPostState() and resets neither itself.
Proposed:
```
// Return every mutable module global to its declared initial value; onOpen() calls this because a post
// may run again in the same JavaScript context. fOutput and gMotionModal are absent: onOpen() rebuilds
// both from properties on every branch, so that assignment is their reset.
```

## Region 2461-3255
Blocks reviewed: 96 · fine: 49 · flagged: 47 · chars before → after (flagged only): 13467 → 10492

### L2467-2468 · C J D
Problem: "NEXT" shouts, and "a debt, not a live defect" is private vocabulary.
Proposed:
// If left true, the next file's first rapid would cross before retracting -- unsafe on a rising Z.
// Every path within one file clears it, so this is a precaution. CR-21.

### L2487-2489 · D C J
Problem: "Not values, but the same leak in its worst shape" opens on a riddle; "the mode file one left behind" needs a second read.
Proposed:
// Modals too: one that believes the controller already holds its state emits nothing, so a second file
// in the same JavaScript context would lose Start()'s G90, G20/G21 and G94 and inherit file one's. CR-21.

### L2495-2498 · H D C
Problem: "threw out of onOpen() on every post" narrates the PV-1 failure; restate it as the constraint it protects.
Proposed:
// The same, per axis word. Not the circular pair: createReferenceVariable gives it no reset() (engine
// 5.388.0, typeof iOutput.reset === "undefined"), so calling one throws, and being non-modal it needs
// none. sOutput is created force:true and fOutput is rebuilt in onOpen(); that is their reset. PV-1, CR-21.

### L2512-2513 · C
Problem: "NO" is emphasis by capitals; the citation stays.
Proposed:
// No "%" wrapper on any firmware: stock Grbl 1.1 has no "%" feature -- the branch in grbl/protocol.c's
// line reader is commented out -- so it reaches the parser and answers error:1.

### L2522-2523 · C J
Problem: "BOTH answers" and "a one-way assignment" are opaque -- the point is only that it is rebuilt on every run.
Proposed:
// Rebuilt on every run, like gMotionModal: onOpen() may run again in the same JavaScript context, and a
// forced F must not leak into the next file.

### L2526 · J R
Problem: "on both answers, the same leak" leans on the jargon above; the first half restates the call.
Proposed:
// Set either way, for the same reason as fOutput.

### L2541-2542 · H D
Problem: "crossed the part" narrates the old bug; "the prompt mode" and "the return traverse" are undefined names for manual spindle control and the park move.
Proposed:
// Before the park move: under manual spindle control this is an M0 prompt, and after the move the
// router would cross the part at travel speed still turning.

### L2593-2597 · H D C
Problem: "ran the full origin dispatch again and drove a G38.2" narrates the CR-17 bug; the two-records reason is packed into one sentence.
Proposed:
// What this job has already set up. currentWorkOffset only suppresses re-selecting the active offset;
// without these a return to an earlier part would re-run its origin setup and probe a surface already
// cut. Two records because only Z goes stale: X0 Y0 never moves once set, but a work Z0 is relative to
// the tool that measured it, so a tool change leaves every part but the re-measured one wrong. CR-17, PV-10.

### L2598-2599 · J
Problem: "established ... under the tool" is the file's term of art; "set" and "measured with" say it plainly.
Proposed:
var wcsVisited = {};     // work offset -> this job has entered it and set its origin
var wcsZ0Trusted = {};   // work offset -> its stored Z0 was measured with the tool now loaded

### L2601-2602 · W
Problem: "five sites act on the answer" -- there are six (validateJob() at 1792, 1886, 1902, 1913; wcsOriginEstablishesZ0() 2709; toolChange() 4983), counting changeReprobesZ0() callers. Drop the count, which will drift again.
Proposed:
// Who corrects the work Z0 for the new tool -- "Probe", "Offset" or "Manual". The one reader of the
// property, so the sites acting on the answer cannot disagree about it.

### L2613-2615 · I D
Problem: "what PV-7 asks" makes the reader look up the id to learn the reason; reorder so the id trails.
Proposed:
// How many sections have finished cutting -- a count, not a section id, because the question is which
// toolpaths have already removed material. Written only by onSectionEnd() and resetPostState(), read
// only through probePointMachinedBefore(). PV-7.

### L2618-2625 · H J
Problem: "One call did both, which forced ..." is history; "owes" and "establishing" are private terms.
Proposed:
// Select the work coordinate system for a section, retracting in the machine frame first. Returns the
// origin setup still to do -- {workOffset, mode, canProbe} -- or undefined where there is none: WCS
// unchanged, offset out of range, or the first section, whose origin writeFirstSection() writes.
//
// Selection only. writeWcsEstablish() sets the origin, called by onSection() AFTER any tool change at the
// same boundary, so a boundary that changes both WCS and tool probes the part once. PR-23.

### L2637-2639 · H
Problem: "It used to return with a warning ..." is history; the live fact is that Marlin selection is supported.
Proposed:
// Marlin takes this path too: gcode.cpp (2.1.2.5) gives its offset selection full parity; only the
// origin write differs.

### L2645-2647 · J C D
Problem: "must not move" means "must not emit a select"; "IS"/"ACTIVE" shout.
Proposed:
// A single-offset Marlin job on WCS 1 emits no select: offset 1 is Marlin's default workspace, and a
// stock build rejects "G54" as unknown. That case only -- G92 writes whichever workspace is active, so a
// job with a second offset needs the select.

### L2659-2660 · D J
Problem: "the two halves must answer one question once" and "probeOnStart's" need a second read.
Proposed:
// Read once here and passed to writeWcsEstablish(), so selection and setup cannot disagree. The first
// part's origin follows probeOnStart instead, in writeFirstSection().

### L2662-2664 · D I
Problem: Bare "HR-24 true by construction" mid-sentence; "could be one that is not current" is hypothetical (both callers pass currentSection) and adds nothing a reader needs.
Proposed:
// The section's own tool, not the global: it is the INCOMING tool at a boundary that also changes tools,
// so canProbe answers for the tool that will cut the part. HR-24, PR-23.

### L2671-2673 · J
Problem: "no frame" is undefined shorthand for "no fixed Z reference"; "enters no WCS at all" restates G53.
Proposed:
// Retract before selecting the new WCS: its Z origin may be unknown, so an absolute Z there is unsafe.
// G53 addresses the machine frame without selecting a WCS. Guard B has already refused a multi-WCS
// job with no fixed Z reference.

### L2681-2683 · H
Problem: "safeZ() stood here once" is history; keep it as a "not X, because" constraint.
Proposed:
// Unreachable behind Guard B; an error, not a move: with no fixed reference no height means the same
// on both sides of the traverse. Not safeZ(): the entering section's level, read in the old part's frame.

### L2692-2693 · R J
Problem: "added-part origin/probe action ... (added parts)" says one thing twice.
Proposed:
// Origin setup follows only a real WCS change; the first section's is writeWcsOnStart()'s.

### L2701-2703 · J D
Problem: "hands its own re-probe over" is jargon; the "Offset"/"Manual" sentence does not say it is about returns.
Proposed:
// Will this plan's origin setup set Z0 itself, with whichever tool is fitted when it runs? toolChange()
// skips its own re-probe exactly where this is true. On a return only "Probe" makes it true: "Offset"
// and "Manual" leave the offset trusted. PV-10, PR-23.

### L2712-2714 · J D
Problem: "both channels", "four arms", "the two dispatches" all undefined; the first sentence lacks a subject.
Proposed:
// Z0 was not set: warn in both the dialog and the file. One writer for the four places a probing origin
// mode meets a tool that cannot probe, so their wording cannot drift. The caller names the mode to
// recommend, as the two dispatches differ. PV-3, PV-9.

### L2716 · H I
Problem: The reason clause narrates which finding raised and ruled it.
Proposed:
// TWIN: here -- both channels, per PV-9. W25b and W28.

### L2721-2725 · H J D
Problem: "no longer overwrites" is history; "establish", "the state the change left" need a second read.
Proposed:
// Set the origin of the part writeWCS() just selected, from the plan it returned. onSection() calls this
// AFTER any tool change at the same boundary, so the tool that cuts the part sets it up: no Z0 measured by
// the outgoing tool survives, and where this probes, the change skips its own re-probe. A change may have
// emptied wcsZ0Trusted before this runs. PR-23, CR-17.

### L2731 · C
Problem: A whole sentence in capitals.
Proposed:
// A return to a part this job has already set up skips the dispatch below. CR-17.

### L2737-2739 · W J
Problem: "The Replicate moves below" names a mode that no longer exists -- the arms are "Skip" ("Use WCS X0 Y0 Z0") and the tool-0 fallback of "Probe Z"; "Replicate" appears nowhere else in the file.
Proposed:
// Z is at Machine Travel Z by either route -- the traverse retract, or that and a tool change, every arm
// of which returns the tool to that height. The X/Y-only moves below keep it; the jog modes hand
// control to the operator.

### L2746-2748 · D C
Problem: "travels there first" points at the wrong part on first read; "PREVIOUS"/"DOWN" shout.
Proposed:
// The tool is still over the previous part, so partProbe() first travels to this one, X/Y only.
// zUntrusted, because this mode exists to re-probe Z0: the probe writes a provisional Z0 at the travel
// height and searches down from it. CR-12.

### L2778-2779 · J
Problem: "the same silence as the arm above" -- the arm is not silent, it warns; the point is the shared case.
Proposed:
// The jog set X0 Y0 and nothing set Z0, so the register keeps its old Z -- the same case as the "Probe
// Z" arm above.

### L2830-2835 · D C
Problem: Two blocks state the same two reasons twice; "BOTH ARMS REACH IT" shouts.
Proposed:
// "Use WCS X0 Y0 Z0" re-sets nothing by design, and a tool 0 / jet tool cannot measure: skipping the
// correction is right, silence is not. wcsZ0Trusted stays false, so a later return warns again.
// TWIN: here -- PV-9's own site, reached by both arms for different reasons, one statement. W11b, W27.

### L2841-2846 · D C
Problem: One long sentence carries two dialects, a source quote and a precondition; "ACTIVE" shouts. Citation kept.
Proposed:
// Persist the current position as WCS wcsNumber's origin; an undefined x/y/z leaves that axis alone. The
// dialects differ in addressing, not capability: "G10 L20 P<n>" names its register, while Marlin's "G92"
// under CNC_COORDINATE_SYSTEMS is a real per-WCS write -- "coordinate_system[active_coordinate_system] =
// position_shift" behind a WITHIN() check, G92.cpp 2.0.9.7 and 2.1.2.5 -- but only of the active
// workspace. So on Marlin the target must be the active WCS, and every caller ensures it.

### L2868-2870 · C J
Problem: "THE job's" shouts; "The field is the opt-in" does not name the field.
Proposed:
// Does the job have its fixed Z reference: the machine's homed Z, addressed with G53, whose Z0 does not
// move with stock thickness? Z only; homed X/Y is Guard B's. "Machine Travel Z" opts in, and ships empty.

### L2875-2877 · J
Problem: "The group-4 declaration" makes the reader map a group number to a property.
Proposed:
// "Axes Homed and Trusted", split into the two questions its consumers ask: the machine-Z reference
// needs Z, the stored-offset guard needs X/Y, and neither implies the other. Read the property only
// through these -- an "== XYZ" test would miss the single-axis answers.

### L2887-2889 · H C J
Problem: "the two booleans it replaced" narrates a property migration nothing in the code needs.
Proposed:
// "Home at Job Start", split into the two questions its consumers ask: does the job home, and does it
// pause first.

### L2907-2909 · C J
Problem: "MILLIMETRES", "IS", "STRING" shout; "no frame" is shorthand.
Proposed:
// "Machine Travel Z" in mm, or undefined where the field is empty or does not parse -- undefined meaning
// no fixed Z reference. A string because Fusion gives a numeric field no unset state, and every sentinel
// would be a reachable height, 0 included.

### L2914-2916 · W C
Problem: "the three tool-change position fields" is stale -- X and Y are now one pair field ("Manual Position X Y", via parseXYPair()); the direct callers are Machine Travel Z and "Manual Position Z", plus each half of the two pair fields. "UNDEFINED IS" shouts.
Proposed:
// The one parser of a machine coordinate held as a string -- Machine Travel Z, "Manual Position Z" and
// each half of an X Y pair -- so no field rejects what another accepts. Undefined means not set ("" too).

### L2924-2930 · L D (R3 breach)
Problem: Seven lines for a nine-line function (rule allows 4); the parseMachineCoordinate() sentence is one long chain.
Proposed:
// The one parser of an X Y pair held as a string -- "Manual Position X Y" and "Probe X Y Offset". Returns
// {x, y} in mm, or undefined for anything else, the empty field included. Each half goes through
// parseMachineCoordinate() and its trim, so "0, 0" and "0,0" are one value, and "10" or "1,2,3" is
// rejected rather than half-read. Pure.

### L2941-2944 · H L (R3 breach)
Problem: "the paired-fill refusal that stood in validateJob() is gone" is history; four lines over a one-line function (rule allows 3).
Proposed:
// The manual change position, in mm. X and Y share one field, so both are set or neither is; Z has its
// own field and may be set alone, a rule validateJob() enforces against these answers.

### L2965-2966 · W
Problem: Says "the G59.x slots are RepRap-only", but the code returns them for every firmware except GRBL -- Marlin gets G59.1-G59.3 too (line 2971, and the error at 2656 says so).
Proposed:
// Numeric G-code for a work offset: 1-6 -> 54-59, 7-9 -> 59.1-59.3. Undefined if out of range for the
// firmware (GRBL stops at G59); callers report the error.

### L2975-2981 · D
Problem: "One block always." then "are two blocks" reads as a contradiction until the second pass. Citation kept.
Proposed:
// Every machine-frame move goes through here, so the travel-Z retract and the X/Y park emit G53 alike.
// Pass the axis words formatted; this adds G53 G0 and the feed.
//
// G53 always shares its move's block: it "is not modal and must be programmed on each line", so the G0
// goes through gFormat, not gMotionModal. And Marlin's G53() restores the saved coordinate system INSIDE
// "if (parser.chain())" (Marlin/src/gcode/geometry/G53-G59.cpp, 2.0.9.7 and 2.1.2.5), so a bare G53 on
// its own line leaves native space active for the rest of the job.

### L3007-3013 · D C J
Problem: "KIND", "ADDRESSING", "RE-ESTABLISHES" shout; "Arithmetic is not a third route" is cryptic.
Proposed:
// Park at the machine's own X0 Y0 -- the homing corner -- as the job's last motion. The two firmware
// routes differ in kind, hence the firmware-dependent guard. GRBL/RepRap emit "G53 G0 X0 Y0", a rapid
// to a machine frame homing must already have set; Marlin emits "G28 X / G28 Y", which re-homes
// instead, needing no prior homing or build option but costing a homing cycle. The post cannot
// compute the point instead: the G92 work frame differs from the machine frame by an unknown offset.

### L3038-3039 · D
Problem: "this route being the only one that rapids at a switch" does not say why RepRap, which also emits G53 G0, is excluded; validateJob()'s twin gives the real reason.
Proposed:
// The file half of validateJob()'s CR-10 warning. GRBL only: Marlin re-homes rather than rapids, and an
// RRF machine homed to its minima already rests at this point.

### L3057-3062 · D C W
Problem: "a false positive aborting every job" reads backwards; "every branch concatenates rather than computes" is not true (offAxis and tilt are computed) -- what holds is that the types are checked before any arithmetic.
Proposed:
// A 3-axis section can still be oriented off machine +Z -- a Setup built on a model face, not the stock
// top. isMultiAxis() misses it, Fusion emitting ordinary X/Y/Z words, so unguarded the part is cut in the
// wrong plane and nothing in the file says so. Fails open: it errors only where the orientation is
// readable and clearly not +Z, as a false positive would abort good jobs. Nothing here may throw, so the
// vector's types are checked before any arithmetic.

### L3110-3111 · R
Problem: The first clause repeats the function's own header.
Proposed:
// isSectionOrientationSupported() has already raised the error when it returns false.

### L3116-3117 · T
Problem: "a onLinear ... a Rapid" -- article and name mismatch.
Proposed:
// The Personal edition sends a section's first move as onLinear, not onRapid, with the current position
// already at the destination -- a zero-length vector with no direction to read.

### L3120 · T W
Problem: "documment" typo; "after the onParameters" is not why this runs here -- it writes the job header and the first part's setup. Also RV-08.
Proposed:
// First section: write the job header and set up the first part.

### L3143-3147 · H J
Problem: "changing first put a fresh Z0 into ..." narrates the bug; "establish" is jargon.
Proposed:
// Order matters: select the WCS, change tools, then set the origin. Select first because the change's
// re-probe writes the ACTIVE offset -- changing first would put the new Z0 in the previous section's
// register. Origin last, so the tool that cuts the part sets it up. Section 1 was selected in
// writeFirstSection(), so wcsOrigin stays undefined for it. PR-23.

### L3153-3155 · J D
Problem: "the establish below re-establishes Z0", "hands the job to it" need decoding.
Proposed:
// Section 1's tool was loaded in writeFirstSection(), before its origin work. The argument says whether
// the origin setup below sets Z0 itself; if so, the change skips its own re-probe. PR-23.

### L3189-3190 · H
Problem: "falling through made laserOn() compute" narrates the old bug; keep it as the constraint.
Proposed:
// Keep the power defined: unset, laserOn() would compute "undefined * 10" and emit S NaN, or reuse an
// earlier section's power. Through is the conservative setting.

## Region 3256-3861
Blocks reviewed: 51 · fine: 26 · flagged: 25 · chars before → after (flagged only): 5490 → 4050

### L3266-3268 · W C L · 262 → 175
Problem: says EVERY post rapid calls emitRapid(), but only onRapid()/onLinear() do. Post-made moves (return to origin, safe-Z retracts, tool-change moves) call rapidMovementsXY/Z() directly (e.g. L2551, 4168, 5199), and G53 moves go through writeMachineFrameBlock().
Proposed:
// Emit one of Fusion's rapids. Moves the post makes itself call rapidMovements*() directly, never
// onRapid(), so the test hook below can turn only Fusion's rapids into feed moves.

### L3277-3279 · D J · 286 → 189
Problem: "the only condition group 3 runs under" and "so a refused move has something to print" need a second read.
Proposed:
// Test hook: a Personal licence delivers these moves to onLinear() as feeds, so forward them there and
// let onLinear() decide which convert back. Travel Speed X/Y is the feed if one stays a G1.

### L3290-3291 · D J · 187 → 180
Problem: "unrecovered, with scaling on" is packed; "the master property" is never named; a full-licence job leaves the property off (its default is false), it does not turn it off.
Proposed:
// A section's first move arrives as a cut; turn it back into a rapid, as a G1 under Scale Feedrate runs
// at the slowest cut feed. Only with Map G1s -> G0 on, off in a full-licence job.

### L3332-3334 · C D · 290 → 197
Problem: PROBING in capitals; "either alone able to miss one" is inverted; "would abort on the first drilled hole" is detail the reason does not need.
Proposed:
// Is this a WCS/inspection probing operation, not a drill or tap cycle? Defined here: Autodesk keep
// isProbeOperation() post-local, so there is no kernel global to call. Either test alone can miss one.

### L3346-3348 · D · 293 → 157
Problem: "which goes in the text, no file surviving" is packed. The reason is simply that only error() can carry the alternative.
Proposed:
// Probing cannot be expanded: that would emit G0/G1 with no G38 at all. error(), not
// cycleNotSupported(): both abort, but only error() can name the alternative.

### L3387 · R · 16 → 0
Problem: restates `fw == eFirmware.GRBL`, and is mis-indented.
Proposed:
(delete)

### L3392 · R · 7 → 0
Problem: "Default" restates the else.
Proposed:
(delete)

### L3398 · T · 52 → 51
Problem: "documment". Also RV-08.
Proposed:
// Called with every parameter in the document/section

### L3517-3518 · L · 176 → 114
Problem: the two sentences say the same thing twice.
Proposed:
// TWIN: none -- the kernel raises it from the operation, and validateJob() cannot see toolpath or
// Manual NC commands.

### L3546-3548 · J C D · 283 → 200
Problem: "arms" used as a term of art, RUNNING in capitals, and "the answer Off" / "that call being what" are packed.
Proposed:
// Kept apart: a milling tool calls setCoolant() even for Off, which stops a running channel; a jet tool
// must not -- F360 gives it no coolant, so Off says nothing. Merged, this would kill laser air. PV-12

### L3563 · R · 16 → 0
Problem: trailing `//COOLANT_DISABLED` names a kernel constant the code does not use and adds nothing.
Proposed:
(delete)

### L3588-3589 · I H · 178 → 111
Problem: "stops reporting" narrates a change; bare PV-2 id.
Proposed:
// onPower() emits the laser control for these. Listed so the fall-through below does not warn them as
// unsupported.

### L3594-3600 · C I L · 642 → 486
Problem: ENDS THE JOB in capitals, the "HB-1's" id, and a last sentence that repeats the TWIN line under it.
Proposed:
// An optional stop is always taken: no supported firmware can stop "only if the operator asked". All
// three parse M1, each differently -- grbl 1.1 "case 1: break; // Optional stop not supported. Ignore."
// does not pause; RepRapFirmware handles "case 0", "case 1: // Sleep" and "case 2" in one block, so
// mid-file it ends the job (src/GCodes/GCodes2.cpp); only Marlin waits for the LCD (M0_M1.cpp,
// HAS_RESUME_CONTINUE). So the post emits M0 and warns, per occurrence, that "optional" was dropped.

### L3602 · R L · 96 → 54
Problem: "and the comment above says so" points at the block above instead of giving the reason.
Proposed:
// TWIN: none -- Manual NC is invisible to validateJob().

### L3609-3611 · I J · 273 → 237
Problem: "HB-9's rule" and "HR-13" are bare ids; "outlives the level gate" is jargon for "ignores Comment Level" (writeWarning(), L4250).
Proposed:
// Below the switch, not a default: case, so a future case that breaks is caught too. writeWarning(),
// not an Important comment, so Comment Level cannot hide it.
// TWIN: none -- Manual NC, and the command is known only when the kernel raises it.

### L3624 · T · 48 → 48
Problem: "Calcualte". Also RV-08.
Proposed:
// Calculate the min/max ranges across all sections

### L3769-3770 · W H · 179 → 107
Problem: stale reason. sanitizeMessageText() (L4618-4621) now collapses runs of spaces between words, so parentheses do not leave a double space. writeCommentLine() (L4241) just replaces them with spaces. "fixed once in partProbe()" is history.
Proposed:
// No parentheses in any label below: writeCommentLine() turns them into spaces, as a grbl comment
// cannot nest.

### L3773-3774 · C · 190 → 170
Problem: NONE in capitals; "the absence" leaves unsaid what is absent.
Proposed:
// Stated even when None: whether there is a fixed Z reference decides whether the tool can retract at
// all, and a reviewer should read that, not infer it from a missing line.

### L3778-3779 · C · 194 → 132
Problem: IN OUTPUT UNITS and INCHES in capitals for emphasis.
Proposed:
// In output units: G53 reads the active G20/G21, so "G53 G0 Z-12" in an inch file is -12 inches, not
// the mm the property is entered in.

### L3786-3790 · J C L · 471 → 295
Problem: "Establish the machine frame" is jargon; CUTTING in capitals; the capability/action split takes three clauses.
Proposed:
// Home the machine at job start, once, before anything work-relative. Only the action property is read
// here: "Axes Homed and Trusted" declares what can home, "Home at Job Start" asks for it. Homing gives
// X/Y a repeatable origin and Z a travel datum; the cutting reference stays the work-Z touch-off.

### L3805-3806 · N D · 197 → 159
Problem: "is not a no-op worth passing over" is inverted.
Proposed:
// Homing asked for with no axis declared homeable cannot be done, and the operator believes the job
// homes, so warn. Not an error(): it costs no safety on its own.

### L3814-3816 · J D · 287 → 238
Problem: "The pre-jog destroyer" and "in the channel the operator running the file has" are jargon, and the reader is never told what gets destroyed.
Proposed:
// Homing would move the tool off the jogged position about to be recorded as origin. Warned in the file,
// as validateJob() has no output stream, and above the homing the operator reads next. Advice only:
// a fixture at machine zero is rare. PV-4

### L3834-3835 · C J · 186 → 184
Problem: BOOKKEEPING, NOT EMISSION and COMPILE in capitals; "the capability split" is jargon for the declared axes.
Proposed:
// On stock GRBL the declared axes are bookkeeping, not emission: which axes $H homes is fixed at
// compile time by HOMING_CYCLE_0/1/2, and $HX/$HY/$HZ sit behind a default-off build option.

### L3838-3839 · C R · 188 → 161
Problem: NOT in capitals; "It takes no line number" repeats the sentence before it.
Proposed:
// writeln(), not writeBlock(): with "Enable Line #s" on, writeBlock() prefixes an N word, and GRBL
// recognises a $ command only when $ is the line's first character.

### L3856-3861 · W J D · 493 → 405
Problem: claims one "fixed phase order" ending with the fixed Z reference and then the origin, but writeFirstSection() has two orders. Ordinary: writeFixedZReference(), toolChangeFirstLoad(), writeWcsOnStart(). Pre-jogged (originIsPreJogged()): toolChangeFirstLoad(), writeWcsOnStart(), writeFixedZReference(). It also leaves out the first tool load, and uses "the machine frame" as jargon for homing.
Proposed:
// Job preamble, emitted once before any section's cutting: the header block, homing, the first
// section's WCS, Start() or the start file, then the fixed Z reference, the first tool load and the
// part origin -- except that a pre-jogged origin moves the fixed Z reference to last. WCS selection
// lives here, not in onSection(), because the steps after it may write an origin on top of the active
// WCS.

## Region 3862-4503
Blocks reviewed: 72 · fine: 45 · flagged: 27 · chars before → after (flagged only): 8405 → 6677

### L3867-3869 · J D C · 261 → 186
Problem: "where the pairs above have to be read" names nothing a cold reader can find; EVERY is emphasis.
Proposed:
    // TWIN: none -- true of every GRBL job, so a dialog line would fire on every post and train the
    // operator to dismiss the dialog. The remedy is a controller setting changed once, not per job.

### L3893-3895 · C I · 279 → 272
Problem: REPLACES is emphasis; the bare CR-05 inside the TWIN reason adds nothing here.
Proposed:
    // The include replaces Start(), the only place this post sets positioning, units and -- on GRBL --
    // feed mode and plane. A missing file is refused at post time; one that merely omits G90 is not.
    // TWIN: none -- a precondition stated in the file, not a defect the post can detect.

### L3908-3910 · J W D · 286 → 276
Problem: "establish" is undefined jargon, and "Pre-jog: origin first" is wrong -- that branch runs toolChangeFirstLoad(), then writeWcsOnStart(), then writeFixedZReference().
Proposed:
  // originIsPreJogged() picks the order. Normally: G53 Z move, load, origin -- the G53 sets the height
  // the trip to X0 Y0 starts from, and Z0 is set with the cutting tool. Pre-jogged: load, origin, then
  // G53, which would otherwise move the tool off the position being recorded. CR-15.

### L3915-3917 · J · 254 → 252
Problem: "without a frame" uses frame as a term of art; "same case ... same remedy" sends the reader off to find the remedy.
Proposed:
    // The tool now stands at a machine height with no work-coordinate Z, and writeMachineTravelZ()
    // tells the kernel nothing -- as after writeToolChangeReturn(), so the same flag. Guarded, because
    // writeFixedZReference() emits nothing without "Machine Travel Z".

### L3927-3929 · J C · 267 → 258
Problem: "re-establishing" and "seeding" are jargon; RETURN is emphasis.
Proposed:
  // The first part is set up, so a later return to its offset reuses the stored origin rather than
  // setting it again. Trusted whatever the mode did: keying it on "did the post probe?" would send a
  // "Use WCS X0 Y0 Z0" job to probe a surface it had already cut. CR-17.

### L3937-3941 · J W · 459 → 348
Problem: "Establish" and "frame" undefined; "partProbe() warns instead of moving" is wrong -- partProbe() warns and still makes the XY rapid and the G38.2 from the held height.
Proposed:
// Set the job's fixed Z reference: a G53 move to "Machine Travel Z", a machine height that clears the
// bed and does not move with stock thickness. Runs before the first part's origin, because the travel
// to its X0 Y0 starts from here. With the field empty this moves nothing, and partProbe() warns that
// its moves start from whatever height the tool holds.

### L3948-3949 · I J · 195 → 164
Problem: "The in-file half of PR-17's post-time warning" and "the establish" need decoding.
Proposed:
  // The file's copy of validateJob()'s warning, which holds the reasoning and the source read. Once
  // here rather than at every G53: the height is the same on all of them.

### L3960-3961 · J · 172 → 153
Problem: "at the establish" is a coined noun.
Proposed:
  // The file's copy of validateJob()'s Marlin warning, so the file read alone states the assumption
  // its motion depends on. Once here rather than at every G53.

### L3972-3979 · H W L · 623 → 276
Problem: Breaches R3 (8 lines, 3 allowed); "what the post did before the field existed" is history; "in output units" is wrong for probeOffsetMm(), which returns mm -- only probeOffsetX()/Y() convert.
Proposed:
// "Probe X Y Offset", in mm here and output units from X()/Y(): a part's Z touch-point is its origin
// plus this, so the origin can sit off the stock while Z is read on its top. Unreadable is 0, 0 --
// validateJob() warns; probeOffsetIsSet() says whether the operator moved the point.

### L3992-3995 · D C · 375 → 300
Problem: Packed; WORK is emphasis; "a range being measured from its own part's origin" needs a second read.
Proposed:
// Has this job already cut the point a part probe touches? getGlobalRange()/getGlobalZRange() give the
// toolpath's extents in work coordinates, so this is a comparison, not an estimate. Per work offset, as
// each range is measured from its own part's origin. A bounding box: over-reports, never under. PV-7.

### L4042-4043 · D J · 192 → 137
Problem: "How the two channels name ... which of the two things" stacks two unexplained pairs.
Proposed:
// The touch-point as both the file and the dialog name it: the origin itself, or the origin plus an
// offset that has not moved it far enough.

### L4059-4061 · W · 275 → 222
Problem: "the true/true default, which is what the tool-change re-probe uses" is wrong: the re-probe calls partProbe() (L5007), which sets both flags from "Probe Pause" before probing; the default reaches only a probeTool() entered without partProbe().
Proposed:
// Prompt flags for the next probeTool(): attach the probe before, detach it after. partProbe() sets
// them from "Probe Pause"; probeTool() then resets them to true/true, the default for any probe not
// reached through partProbe().

### L4065-4074 · D C I · 819 → 791
Problem: The startsWhereHomingLeftIt entry is packed ("Caller knowledge ... can be true of it", "asserts a height the operator chose"); HEIGHT is emphasis.
Proposed:
// Probe Z into the active WCS at the part's touch-point -- its origin plus "Probe X Y Offset" --
// travelling there first where the tool is not already on it. Callers guard tool 0 and jet tools.
//
//   atOrigin              the tool already sits on the origin, so the reposition is emitted only where
//                         the offset is non-zero.
//   zUntrusted            this WCS's stored Z0 is not believed, so the probe writes its own provisional
//                         Z0 below. Whether the traverse height is unknown is a separate question.
//   startsWhereHomingLeftIt   the tool has not moved since writeMachineHoming(); only writeWcsOnStart()
//                         can pass true. Selects the no-Z-reference warning that says homing, not the
//                         operator, chose the height. PR-16.

### L4081-4083 · I J C · 285 → 233
Problem: "PV-7's in-file half" opens on an id; BEFORE is emphasis.
Proposed:
  // The file's half of the PV-7 warning, above the traverse and G38.2 because the datum must be fixed
  // before the probe runs. Warned, not suppressed: an origin off the material is common, and "Probe X Y
  // Offset" is the remedy the text names.

### L4134-4135 · H · 173 → 113
Problem: "byte-identical to the historical always-prompt behavior" is history; "per probePause" names the variable, not the property the operator sees.
Proposed:
  // Attach/detach prompts from "Probe Pause": No = neither, Before = attach only, Before & After = both
  // (the default).

### L4149-4151 · J D I · 292 → 247
Problem: "above both arms", "where the MODE is read", "a register ... not being one that changed behind them" each need a second read.
Proposed:
  // Here, where the mode is read, because the two modes write the origin at different sites. Jog modes
  // are excluded: there the operator sets the register at the pause, knowingly. validateJob() carries
  // the dialog copy (PV-4) -- by the G10 it is too late.

### L4162-4165 · H J I · 379 → 288
Problem: "it once gated" narrates the removed bug; "arms" is jargon. Restated as the constraint that keeps it from coming back.
Proposed:
    // No canProbe guard: this clearance move must lift every tool, laser included -- guarding it would
    // let a jet job cross the bed at whatever height it held. Z0's trust is the mode's premise whatever
    // the tool. The branches below keep their guards: each bounds a G38.2 or a provisional Z0. HR-26.

### L4178-4183 · J D I · 464 → 339
Problem: "the frame", "four arms", "the hand-over", "carrying both suppressions so it says what was EMITTED" -- a cold reader cannot follow it.
Proposed:
      // The one caller that can still stand where homing left the tool: before here, only
      // writeFixedZReference() and toolChangeFirstLoad() can move it. The first moves nothing when there
      // is no Z reference -- the case the warning covers -- and the second only on a macro hand-over,
      // which firstToolChangeIsHandedOver() reports as emitted. PR-16, PV-13.

### L4257-4259 · D I · 257 → 208
Problem: "Neither channel is earlier" is cryptic; "channels" is never defined.
Proposed:
// One text to both the file and the dialog, so the two cannot drift -- pairing them by hand needs a
// second predicate and a second string. Not a pre-flight: that warns once per job, this once per
// occurrence. PV-9.

### L4272-4275 · W C D · 396 → 293
Problem: "Set by a tool change" is incomplete: writeFirstSection() also sets it on the pre-jog path (L3919), which is not a tool change. Caps throughout; "what is LEFT OVER once ..." needs a second read.
Proposed:
// Set where the post moved the tool in machine coordinates (G53) -- a tool-change return or the
// pre-jog first section -- and read only in rapidMovements(). That height has no work-coordinate Z,
// so getCurrentPosition().z is wrong and cannot be corrected; the flag stops the next rapid relying
// on it.

### L4278-4281 · D · 365 → 289
Problem: One sentence carries three claims; "covers what follows a G53" is vague.
Proposed:
// Tell the kernel where the tool is: getCurrentPosition() tracks the toolpath, blind to moves the post
// emits itself. Undefined means unchanged, not zero. Work coordinates only, so a G53 move sets
// forceRapidXYBeforeZ instead -- Autodesk's posts do the same (haas.cps, writeRetract(), G53 case).

### L4329-4330 · J · 193 → 145
Problem: "ends the debt" is a private metaphor.
Proposed:
  // A work-coordinate Z clears the flag: it was set because the tool's height had no work-coordinate
  // value, and the block above has just given it one.

### L4365-4365 · R · 39 → 0
Problem: Trailing comment restates Vector.diff().
Proposed:
(delete)

### L4377-4378 · H C · 179 → 158
Problem: "Returned outright it turned an F100 move into F180" narrates the removed bug; RAISE is emphasis. Restated as the constraint.
Proposed:
    // Never raise a feed: the axis limit only caps what was asked for. F is modal, so returning the
    // limit outright would turn an F100 move into F180 on the defaults.

### L4408-4413 · C D L · 569 → 381
Problem: NOT and CHORD are emphasis; "which is the right side to err on and keeps the rule predictable" is long for what it says.
Proposed:
// The arc counterpart of limitFeedByXYZComponents(): cap a G2/G3 feed so no axis exceeds its
// configured maximum. Not that function's chord projection: an arc's axis velocity is tangential and
// reaches the full feed wherever the tangent lines up with an axis, so a chord under-protects by up to
// 1/cos(45deg). Conservative for a short arc that misses every quadrant point -- the safe side.

### L4481-4482 · C D · 176 → 172
Problem: LAZILY and MISSING are emphasis, and "re-asserts them lazily" is the thing that needs saying plainly.
Proposed:
      // Modal state does not survive a file the post did not write. A modal writes a word only on change,
      // so a stale one drops it: a G18 left behind makes the next XY arc cut in ZX.

### L4487-4488 · H · 181 → 176
Problem: "an empty one used to be silent" is history.
Proposed:
      // A missing file aborts the post; an empty one is noted rather than skipped silently. It matters
      // most on the Start include, which replaces Start() and so leaves G90/G21 unwritten.

## Region 4504-5208
Blocks reviewed: 74 · fine: 38 · flagged: 36 · chars before → after (flagged only): 12078 → 9302

### L4530-4533 · C L · 380 → 314
Problem: "ASKED" capitalised for emphasis; the reasoning runs long.
Proposed:
```
// Manual path only: what the operator was last asked for. The speed is kept as the formatted string, because
// two speeds that format alike are one speed to the operator, and asking them to turn a dial to the number
// it already reads is worse than silence. Direction is kept too, so a reversal at an unchanged speed asks.
```

### L4548-4549 · C · 175 → 165
Problem: "ONLY" capitalised for emphasis.
Proposed:
```
// Direction is named only when counterclockwise: clockwise is the default for every tool these machines
// hold, so naming it would add a word to every job's start prompt.
```

### L4553-4554 · H D · 194 → 134
Problem: Narrates a fixed bug ("used to be dropped", "was silent"); the rule is just that either change prompts.
Proposed:
```
// Either change prompts: setSpindeSpeed() calls here for a later operation's new speed, and for a tapping
// reversal at an unchanged speed.
```

### L4557-4558 · C L · 179 → 122
Problem: "IS" capitalised; the "alter the machine" clause adds little.
Proposed:
```
// Here direction is always named, even when only the speed moved: a change prompt states the whole
// target state, not a delta.
```

### L4597-4598 · H C · 196 → 162
Problem: "GRBL used to emit a bare M5" is history; "MACHINE" capitalised. Restate as the constraint.
Proposed:
```
// Tested before the firmware: manual describes the machine -- a hand-switched router -- not the dialect, and
// a bare M5 does nothing to such a router on any firmware.
```

### L4600-4601 · L · 150 → 89
Problem: Says twice that the post does not command the spindle.
Proposed:
```
// No M5 here, as spindleOn() emits no M3: the operator owns this spindle, so the post asks.
```

### L4667-4667 · W · 37 → 36
Problem: This else covers Marlin AND RepRap, and Marlin does have G18/G19 under CNC_WORKSPACE_PLANES (as Start() says at 4520); what is true is that the code emits XY arcs only, off GRBL.
Proposed:
```
// Off GRBL: XY only, others linearized
```

### L4713-4715 · H I · 230 → 168
Problem: "A third carried here put two spaces" narrates the old bug; HR-19 adds nothing.
Proposed:
```
// No leading space in v1: writeBlock() supplies one with "Include Whitespace" on and the prefix below
// supplies one with it off, so a third would put two spaces after M291.
```

### L4721-4725 · D L (shape) · 428 → 300
Problem: Five lines immediately before an `else if` -- breaches the 3-line rule, which comment-rules.js misses because its R1 regex only matches `} else if`; packs three firmwares' parsing into one block.
Proposed:
```
// The comma in "MSG," is required: grblHAL matches strncasecmp(comment, "MSG,", 4) in gc_normalize_block()
// (grblHAL/core gcode.c, read 2026-08-14). No space after it: grblHAL trims one, but FluidNC's
// gcode_comment_msg() skips four characters after "MSG" (FluidNC/src/GCode.cpp). grbl 1.1 drops it. CR-02.
```

### L4736-4741 · J D C · 561 → 413
Problem: "LOADED"/"CHANGE" caps; "arrive-and-resume work", "the ordering rule", "the hand-over" undefined here; the Refuse/Pause aside needs a second read.
Proposed:
```
// The first tool is loaded, not changed: nothing is running, no Z0 exists yet, and the tool stands where the
// operator left it -- so none of toolChange()'s retract, stop and re-probe is owed. Called unconditionally,
// so the load-before-origin order lives in one place. "At a Tool Change" decides who loads it: an M0 prompt
// on Refuse and on Pause (they differ only at a later change), the macro hand-over on Macro. PV-13.
```

### L4747-4749 · J D · 294 → 239
Problem: "the macro arm", "inert, not unsafe" -- jargon and a compressed pair of antitheses.
Proposed:
```
// Pre-jogged origin: the jog was made with a tool fitted, so "First Tool is Correct" Off contradicts the
// mode, and a macro change would move the tool off the position about to be recorded. Warned, not refused:
// nothing unsafe is emitted. PV-13.
```

### L4763-4765 · J D · 240 → 198
Problem: "The M0 arms" is jargon; the last sentence's participle phrasing needs a second read.
Proposed:
```
// A changer can act on neither: "T0 M6" names no tool, and a laser is not in a changer. The M0 prompt is
// unaffected -- a person can fit a laser. Both channels, so it can be fixed before posting. PV-13.
```

### L4777-4780 · J D C · 303 → 265
Problem: "Both are meaningful here rather than mid-job leftovers" -- "both" has no referent until you read the calls below; "NOT" caps.
Proposed:
```
// The resume is not a mid-job leftover here: writeWCS() has selected the offset, Start() set the modals,
// and the tool returns to the height writeWcsOnStart() expects. The include files are not loaded:
// "Tool Change Start" runs at cutting height, and nothing has cut yet.
```

### L4793-4796 · D · 356 → 265
Problem: "It answers the outcome and not the intent, carrying both suppressions" needs a second read.
Proposed:
```
// True where the first tool is loaded by the macro hand-over, not by a prompt or not at all. One definition,
// read by three validateJob() guards and the emitter alike. It carries both suppressions above, so no guard
// complains about a hand-over that never happens. PV-13.
```

### L4814-4821 · H D (R3) · 697 → 313
Problem: Narrates how one predicate became two; 8 lines on a 4-line function (R3 allows 3). The case 6 / STEP 4 mechanism repeats toolChangeMacroCall()'s header; this keeps the citation and the maintenance hazard.
Proposed:
```
// True only where a sender must strip the M6. FluidNC takes the same "T<n> M6" but runs it itself, via the
// "atc:" or "m6_macro:" in config.yaml (FluidNC/src/GCode.cpp, FluidNC/src/Spindles/Spindle.cpp, v3.9.6).
// A new handler must go in this and toolChangeNeedsGrblDialect() deliberately, or the guards disagree. FR-1.
```

### L4847-4853 · H J C · 546 → 445
Problem: "the deleted Tool Change X/Y/Z were bare G0 words" is history -- restated as the constraint; "Flow 1"/"arm" jargon; "FIRST" caps.
Proposed:
```
// The manual change's optional excursion to where the operator can reach the tool. Only when
// toolChangeMovesToPosition() is true, which validateJob() also checks.
//
// Every block is G53 through writeMachineFrameBlock(), like the retract and end park -- never a bare G0,
// which the active WCS would read. X/Y and Z are separate blocks, G53 not being modal, and X/Y goes first:
// the tool starts at Machine Travel Z, the height declared to clear every fixture.
```

### L4873-4874 · C · 166 → 135
Problem: "LAST" caps; "not the retract's" is an inverted lead.
Proposed:
```
// Sync after the last motion: writeMachineTravelZ() flushed before these blocks, and the machine must stand
// still before anything prompts.
```

### L4878-4883 · J D C · 549 → 461
Problem: "Flow 1", "HEIGHT"/"ORDER" caps, "the ORDER of the next rapid" undefined; long single sentences.
Proposed:
```
// The manual change's return, not a retrace. Two things are owed: the height, since the change height may be
// below the travel height later moves assume; and XY-before-Z for the next rapid, the tool now standing over
// a point the work offset has no number for. No X/Y return: resetAll() discarded the tracked position so
// the next move is absolute, and where the work offset also changes here the post cannot relate the two
// frames, their origins being probed at runtime.
```

### L4889-4891 · L · 270 → 114
Problem: Three lines for one fact.
Proposed:
```
// Only an X/Y excursion owes the ordering: a Z-only change position returns the tool to the point and
// height it left.
```

### L4899-4912 · W H I · 1076 → 922
Problem: "spindleOff() already beeps where the firmware has one" is wrong: spindleOff() emits M300 only under manual spindle control, off GRBL, and toolChange() calls it only when spindleEnabled -- an M3/M5 or M106/M42 spindle gets no beep at all. The onRapid() clause narrates a past bug ("cleared ... defeated"); restated conditionally.
Proposed:
```
// The post changes no tool on either flow: a measured change needs a probe, a subtraction and a register to
// hold the result, and the post can never read a register back. Its role is to arrive, hand over and resume
// correctly -- the three steps below. design.md -> Tool changes.
//
// Nothing is emitted that nothing will act on. No M84 Z: Marlin-only, so GRBL halts on it, and on Marlin
// released steppers sink an unbalanced gantry in Z. No M300 here: spindleOff() beeps for a hand-switched
// spindle off GRBL. No M6 except in toolChangeMacroCall(), where something named acts on it. No onRapid() of
// the post's own: a machine-frame move through it would clear forceSectionToStartWithRapid and defeat
// "First G1 --> G0" after a change.
//
// partOriginEstablishesZ0 -- true where the origin work after this call sets Z0 itself, with the tool fitted
// here. Then the re-probe below is dropped as a duplicate; where false, nothing else corrects Z0. PR-23.
```

### L4922-4924 · H · 292 → 181
Problem: "Tool Change X/Y/Z were plain G0 words" is history, and repeats writeToolChangePosition()'s header.
Proposed:
```
// Retract in the machine frame, unconditionally even where that repeats a G53 block: the post tracks no
// machine-frame position, so "already there" would be a belief to maintain. PR-23.
```

### L4938-4939 · H · 159 → 133
Problem: "emitted M400 twice" narrates the old bug; state it as the reason. (The block is also indented one level too deep.)
Proposed:
```
// Only this arm owes the sync: the retract above ends with its own flushMotions(), and a second would
// emit M400 twice on Marlin and RRF.
```

### L4943-4944 · H J · 187 → 93
Problem: "gating it on the excursion left the other arm handing over with coolant running" narrates the old bug.
Proposed:
```
// On every route, not only the one that moves the tool: coolant stops for the hand-over itself.
```

### L4947-4949 · H C · 293 → 201
Problem: "INCOMING" caps; "left the router turning" narrates the bug -- restated conditionally.
Proposed:
```
// Not onCommand(COMMAND_STOP_SPINDLE): its !tool.isJetTool() guard reads `tool`, already the incoming tool,
// so a router-to-laser change would leave the router turning. spindleEnabled says what is running.
```

### L4964-4965 · R · 135 → 63
Problem: Second sentence restates the `if` below.
Proposed:
```
// The manual change's resume, owed only where the tool was moved.
```

### L4973-4982 · J D C I · 798 → 641
Problem: "strands", "arms", "hoisted", "correction ANSWER" are private terms; caps; ids mid-sentence; "That ordering is the root fix" is history.
Proposed:
```
// The new tool is a different length, so the stored work Z0 belongs to the old one unless something corrects
// it. The re-probe goes through partProbe(), so it honours "Probe X/Y Offset" and "Probe Pause", writes a
// provisional Z0 first, and lands in the active offset -- onSection() selects it before calling here, which
// is why a change that is also a WCS change owes no extra correction. PR-23.
//
// Which other parts' Z0 goes stale depends on "Tool Length Correction By", so it is settled here for every
// route: Probe and Manual each fix the active offset only and mark the rest stale; Offset shifts the whole
// Z frame, so nothing goes stale. CR-17, PV-10.
```

### L4987-4988 · H I · 177 → 134
Problem: "the ordering PR-23 established" is history plus an id mid-sentence.
Proposed:
```
// currentWorkOffset, not the section's: onSection() selects the WCS before calling here, so the register
// active at the pause is this one.
```

### L4995-4996 · C N · 114 → 92
Problem: "deliberately NOT set" caps; inverted "being what did the work".
Proposed:
```
// Not set here: writeWcsEstablish() does the work, so it sets wcsZ0Trusted[currentWorkOffset].
```

### L5013-5015 · W I · 181 → 168
Problem: "Same sentence" is false: writeWcsOnReturn()'s warning (2835-2837) reads "this part's stored Z0 was measured with a tool that has since been changed..." -- the same condition, different words. Also indented one level too deep.
Proposed:
```
// TWIN: here -- the change-side twin of writeWcsOnReturn()'s warning, one boundary earlier: Z0
// measures from a tool no longer fitted, and this post cannot correct it. W26.
```

### L5031-5034 · J D I · 337 → 261
Problem: "the scope clause is the whole of PV-10" is opaque to a cold reader; long sentence chain.
Proposed:
```
// "Manual": a re-zero at the pause reaches only the register active then, so an operator who did as told
// would cut the next part a tool length deep unless told. Not alarmist: the clearing above makes every
// other part re-measured, or warned about, at its own return.
```

### L5052-5053 · W · 146 → 140
Problem: Claims onSection() restarts the spindle. It only calls onCommand(COMMAND_START_SPINDLE) -> setSpindeSpeed(), which skips when speed and direction are unchanged; spindleOff() above leaves currentSpindleSpeed standing, so after a same-speed change the spindle stays off (the registered defect). When that is fixed the original wording is right again -- consider leaving it and fixing the code instead.
Proposed:
(no change -- the comment is true once RV-01 lands, and the fix belongs in the code)

### L5057-5076 · D L (R3) · 1537 → 1408
Problem: 20-line header on a 35-line function (R3 allows 17); wordy in places. Citations kept verbatim.
Proposed:
```
// Flow 2's hand-over: emit the handler's token once, and nothing around it the handler will redo. The token
// differs by target, which is why the handler is a dropdown:
//   gSender / CNCjs / UGS -- "T<n> M6", which GRBL and grblHAL do not execute: they answer error:20 with
//   the tool in the cut. It works only because the sender strips the M6 first -- in its Grbl controller's
//   dataFilter for gSender and CNCjs (src/server/controllers/Grbl/GrblController.js), and in UGS's
//   ToolChangeInterceptor, which matches "(?i)(?<![A-Z])M0?6(?![0-9])" and sends the T to the controller
//   (ugs-core/src/com/willwinder/universalgcodesender/services/interceptor/, master, 2026-08-17). All three
//   are off until the operator turns them on, and the post can verify none of it.
//
//   FluidNC -- the same "T<n> M6", not intercepted: case 6 sets ToolChange::Enable and STEP 4 calls
//   spindle->tool_change(), which runs the "atc:" changer or the "m6_macro:" in config.yaml -- and with
//   neither returns true having done nothing, so the job cuts on with the tool already fitted
//   (FluidNC/src/GCode.cpp, FluidNC/src/Spindles/Spindle.cpp, v3.9.6; src/ToolChangers/ exists at 3.9.0 and
//   404s at 3.8.0). A sender set to strip the M6 here removes the token the firmware acts on. FR-1.
//
//   RepRapFirmware -- "T<n>" and no M6: the T word is the change, running tfree/tpre/tpost.
//   Other -- no token; the operator's file is the hand-over, through loadFile().
```

### L5090-5091 · H · 122 → 81
Problem: "which left the line with no subject at all" narrates the old output.
Proposed:
```
// Tool number first: most of Autodesk's own tools have an empty tool.comment. PV-6.
```

### L5100-5100 · J I · 98 → 87
Problem: "PV-6's lesson" means nothing without the register.
Proposed:
```
// Tool number first, and the comment only where there is one, as in the RepRap arm above.
```

### L5113-5117 · L D · 429 → 315
Problem: "re-asserts" twice; "rather than deciding what was probably safe" adds nothing.
Proposed:
```
// Flow 2's resume: restore the frame and modal state the handler may have disturbed, and return the tool to
// a known height. Unconditional on the handler: the post cannot read a macro it did not write. Modals are
// written only on change, so a G91 or G20 left behind would be inherited silently; the resets force each out.
```

### L5204-5205 · W · 106 → 87
Problem: "e.g. the tool-change re-probe" is wrong for the same reason as L4059-4061: the re-probe goes through partProbe(), which sets both flags from "Probe Pause" first.
Proposed:
```
  // Restore the default for a probe not reached through partProbe(), which sets its own.
```

### L5186-5186 · T · 46 → 44
Problem: "refer http://..." is missing "to".
Proposed:
```
// See http://marlinfw.org/docs/gcode/G038.html
```

