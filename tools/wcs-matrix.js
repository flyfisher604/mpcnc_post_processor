/**
  wcs-matrix.js -- the multi-part half of the post, on job files built for it.

  `professional-matrix.js` states the bound it cannot cross: every .cnc Autodesk ships uses one
  work offset, so "Each New WCS / Part", writeWCS()'s traverse arm and writeWcsOnReturn() are
  unreachable from their library. `tools/wcs-jobs/` closes that gap and this matrix is what reads
  the result. Its through-line is the pair "First WCS / Part" x "Subsequent WCS / Part", crossed
  with the tool change on both flows -- manual (Pause) and automated (Macro) -- because a boundary
  that changes BOTH the part and the tool is where the post has to decide which of the two owns
  the origin work, and no shipped job has ever put it to that question.

  Three channels, as in `professional-matrix.js`:
    must / mustNot        the emitted g-code
    mustLog / mustNotLog  the post-time channel -- warning(), which reaches the dialog
    refuse                error(), where the right answer is no file at all

  WHAT MOST OF THESE CASES ASSERT IS ORDER AND COUNT, not presence. The two defects this area has
  actually had were an ordering (CR-15) and a duplicated probe (CR-17, PR-23): a preamble with
  every block present but in the wrong sequence, and a G38.2 driven into a surface the previous
  pass had cut. A presence check sees neither.

  Run:
    node tools/wcs-matrix.js <post.exe> <post.cps> tools/wcs-jobs <output dir>
  VERBOSE=1 prints the checks that passed as well as the ones that did not.
*/
const { spawnSync } = require('child_process');
const fs = require('fs'), path = require('path');

const POST = process.argv[2];
const CPS  = process.argv[3];
const JOBS = process.argv[4];
const OUT  = process.argv[5];
fs.mkdirSync(OUT, { recursive: true });

const S = v => `"${v}"`;
const B = v => (v ? 'true' : 'false');

// THE MULTI-PART BASELINE. Guard B refuses any job with more than one work offset unless the
// machine declares X/Y homed -- a stored offset is measured from machine zero, which moves at
// every reset when nothing homes -- and the traverse retract needs the Z frame. So this is not a
// preference: it is the minimum configuration in which these job files post at all.
const MP = { machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'), machineHomeAtStart:S('Home') };
const mp = (extra) => Object.assign({}, MP, extra);

const at = (t, re) => t.search(re);
const ordered = (t, steps) => {
  const idx = steps.map(s => [s[0], at(t, s[1])]);
  const missing = idx.filter(p => p[1] < 0);
  if (missing.length) return [false, `never emitted: ${missing.map(p => p[0]).join(', ')}`];
  for (let i = 1; i < idx.length; i++) {
    if (idx[i][1] < idx[i-1][1]) {
      return [false, `${idx[i][0]} (@${idx[i][1]}) precedes ${idx[i-1][0]} (@${idx[i-1][1]})`];
    }
  }
  return [true, `ordered: ${idx.map(p => p[0]).join(' -> ')}`];
};
const countOf = (t, re) => (t.match(re) || []).length;
const counts = (t, re, n, what) => {
  const got = countOf(t, re);
  return [got === n, `${got === n ? '' : `${got} not ${n}: `}${what}`];
};
// The text between two anchors -- how a claim is confined to one section boundary rather than
// being satisfied by something the file happens to contain somewhere else entirely.
const between = (t, a, b) => {
  const i = t.search(a); if (i < 0) return '';
  const rest = t.slice(i);
  const j = rest.slice(1).search(b);
  return j < 0 ? rest : rest.slice(0, j + 1);
};

const cases = [
// === A. the first part, then a part this job has never seen ===========================
{ id:'W1', desc:'Use WCS X0 Y0 Z0 on both: two registers selected, nothing measured, nothing asked',
  job:'two-parts.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  must:[[/^G54$/m,'the first part selects its register'],
        [/^G55$/m,'the second selects its own'],
        [/Move to this part's stored origin X0 Y0/,'the added part is reached, not established']],
  mustNot:[[/G38\.2/,'no probe anywhere - neither mode measures'],
           [/G10 L20 P2/,"nothing is written into the second part's register"],
           [/MSG,Jog/,'no operator prompt']],
  custom:t => ordered(t, [['G54',/^G54$/m], ['travel-height retract',/^G53 G0 Z-5 F\d/m], ['G55',/^G55$/m]]) },

{ id:'W2', desc:'Probe Z0 Once per Part: the added part is probed, into ITS OWN register',
  job:'two-parts.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Probe Z') }),
  must:[[/^G10 L20 P2 Z0$/m,'the provisional Z0 names P2 - CR-12'],
        [/^G38\.2 F\d+ Z-\d/m,'and searches down from it'],
        [/^G10 L20 P2 Z0\.8$/m,'and the result lands in P2, not the active-register accident']],
  mustNot:[[/^G10 L20 P1 Z/m,"the first part's register is never rewritten"]],
  custom:t => counts(t, /G38\.2/g, 1, 'exactly one probe: the first part is skipped, the second measured') },

{ id:'W3', desc:'Jog to X0 Y0 Z0 on the added part: the hand sets all three, no probe',
  job:'two-parts.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Jog XYZ') }),
  must:[[/MSG,Jog to X0 Y0 Z0/,'the operator is asked, at the part'],
        [/^G10 L20 P2 X0 Y0 Z0$/m,'and where they stopped becomes the origin']],
  mustNot:[[/G38\.2/,'nothing is probed']] },

{ id:'W4', desc:'Jog to X0 Y0, Probe Z0: the provisional Z0 goes in before the probe, not after',
  job:'two-parts.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Jog XY & Probe Z') }),
  custom:t => ordered(t, [['G55',/^G55$/m],
                          ['jog prompt',/MSG,Jog to X0 Y0 above Z0/],
                          ['provisional Z0',/^G10 L20 P2 X0 Y0 Z0$/m],
                          ['probe',/^G38\.2 F\d+ Z-\d/m],
                          ['result',/^G10 L20 P2 Z0\.8$/m]]) },

{ id:'W5', desc:'the traverse retracts in the machine frame BEFORE selecting the new register',
  job:'two-parts.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Probe Z') }),
  must:[[/Retract to the travel height in the machine frame before traverse/,'and says why']],
  custom:t => {
    // ANCHORED ON THE RETRACT'S OWN ANNOUNCEMENT, and the ordering read from there forward. A
    // check that only asks whether a G53 appears before the boundary is satisfied by the FIRST
    // section's clearance move, which is a different block entirely and proves nothing.
    const i = t.search(/Retract to the travel height in the machine frame before traverse/);
    if (i < 0) return [false, 'the traverse retract is never announced'];
    return ordered(t.slice(i), [['announced',/Retract to the travel height in the machine frame/],
                                ['G53 retract',/^G53 G0 Z-5 F\d/m],
                                ['WCS change',/WCS changed: 1 -> 2/],
                                ['G55 select',/^G55$/m]]);
  } },

{ id:'W6', desc:'... and with no machine frame the whole job is refused, not posted unsafely',
  job:'two-parts.cnc', props:{ machineHomedAxes:S('XYZ'), probeOnChange:S('Probe Z') },
  refuse:[/multiple work offsets|fixed Z reference|Machine Travel Z/i,'Guard B names what is missing'] },

// === B. a return to a part this job has already set up (CR-17) ========================
{ id:'W7', desc:'a return with no tool change since sets NOTHING up - it selects and travels',
  job:'return-to-part.cnc', props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z') }),
  must:[[/Return to a part already set up -- move to its stored origin X0 Y0/,'and says so'],
        [/WCS changed: 2 -> 1/,'the register is re-selected']],
  mustNot:[[/a tool change since means Z0 is re-probed/,'nothing has invalidated Z0']],
  custom:t => counts(t, /G38\.2/g, 2, 'two probes for three sections: the return adds none - CR-17') },

{ id:'W8', desc:'... and it re-prompts nothing either, under a jog mode',
  job:'return-to-part.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Jog XYZ') }),
  custom:t => counts(t, /MSG,Jog to X0 Y0 Z0/g, 1,
    'one jog prompt for two visits to two parts: the return does not re-ask for a part already cut') },

// === C. a return whose Z0 a tool change has invalidated ===============================
{ id:'W9', desc:'a return AFTER a tool change re-probes Z0 - and only Z0',
  job:'change-then-return.cnc',
  props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z'), toolChangeMode:S('Pause') }),
  must:[[/Return to a part already set up; a tool change since means Z0 is re-probed/,'named at the boundary'],
        [/^G10 L20 P1 Z0\.8$/m,"the re-probe lands in the returned-to part's register"]],
  mustNot:[[/^G10 L20 P1 X0 Y0/m,'X0 Y0 is never re-established on a return - it is what nothing moves']] },

{ id:'W10', desc:'... and corrected by hand at the pause the return is silent about nothing',
  job:'change-then-return.cnc',
  props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z'),
             toolChangeMode:S('Pause'), toolChangeZ0Correction:S('Manual') }),
  // THE RETURNING OFFSET IS THE ONE THE CHANGE STOOD ON -- the plan is [A@1, A@2, B@1], so the hand-zero
  // at the pause reaches the very register section 3 goes on to cut. It keeps its trust and the return
  // must not re-measure it. PV-10 is the OTHER shape, where the change stands somewhere else (W22).
  must:[[/work Z0 was NOT re-established/,'the change says what it did not do']],
  mustNot:[[/a tool change since means Z0 is re-probed/,'and the return does not claim otherwise']] },

{ id:'W11', desc:'Use WCS X0 Y0 Z0 across a change: the change keeps the re-probe the establish will not make',
  job:'change-then-return.cnc',
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip'), toolChangeMode:S('Pause') }),
  must:[[/^G10 L20 P1 Z0\.8$/m,"the change corrects Z0 itself, in the part's own register"]],
  mustNot:[[/Work Z0 for this part is established below/,'the hand-over is NOT taken: under this mode the establish measures nothing'],
           [/stored Z0 was measured with a tool that has since been changed/,
            'and so the return has nothing to warn about - the correction was already made']],
  custom:t => counts(t, /G38\.2/g, 1, 'one probe in the whole job, and it belongs to the change') },

{ id:'W11b', desc:'... and a part LEFT BEHIND by that change is stale, in BOTH channels - PV-9',
  job:'tools-across-parts.cnc',
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip'), toolChangeMode:S('Pause') }),
  must:[[/stored Z0 was measured with a tool that has since been changed/,'the depth error is named in the file']],
  // THE MODE-SIDE ARM: "Use WCS X0 Y0 Z0" re-establishes nothing by design. This row asserted the GAP
  // until PV-9 closed it, and the assertion is inverted rather than deleted -- the same regex, the
  // other channel, so a warnBothChannels() reverted to writeWarning() turns this case red again.
  mustLog:[[/stored Z0 was measured with a tool that has since been changed/,
            'and the dialog says it too -- PV-9']],
  custom:t => counts(t, /G38\.2/g, 1,
    'the change re-probes the part it is standing on and no other: there is no tool-length system to correct the rest') },

// === D. a boundary that is BOTH a new part and a new tool (PR-23, CR-21, CR-22) =======
{ id:'W12', desc:'select, THEN change, THEN establish - the part is set up once, by the tool that cuts it',
  job:'part-then-tools.cnc',
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Probe Z'), toolChangeMode:S('Pause') }),
  custom:t => {
    const seg = between(t, /WCS changed: 1 -> 2/, /2D-Face - Milling - Tool: 1/);
    const n = countOf(seg, /G38\.2/g);
    if (n !== 1) return [false, `${n} probes at the new-part-and-new-tool boundary, expected exactly 1`];
    return ordered(seg, [['G55',/^G55$/m], ['tool change',/Tool Change Start/],
                         ['hand over',/MSG,Change to Tool #1/], ['change ends',/Tool Change End/],
                         ['establish',/^G10 L20 P2 Z0$/m], ['probe',/^G38\.2/m]]);
  } },

{ id:'W13', desc:'the automated hand-over reaches the same boundary and re-selects the register after it',
  job:'part-then-tools.cnc',
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Probe Z'),
             toolChangeMode:S('Macro'), toolChangeSender:S('gSender') }),
  must:[[/^T1 M6$/m,'the sender token, not an M6 the post invents'],
        [/^G55$/m,'the added part is selected']],
  custom:t => {
    const seg = between(t, /WCS changed: 1 -> 2/, /2D-Face - Milling - Tool: 1/);
    const first = ordered(seg, [['G55',/^G55$/m], ['hand over',/^T1 M6$/m], ['modal re-assert',/^G90$/m]]);
    if (!first[0]) return first;
    // The re-select is a SECOND G55 after the token, which an index-of-first search cannot see:
    // a macro the post did not write may have left any register active, so this one is unconditional.
    const afterToken = seg.slice(seg.search(/^T1 M6$/m));
    return ordered(afterToken, [['modal re-assert',/^G90$/m], ['WCS re-select',/^G55$/m],
                                ['travel height',/^G53 G0 Z-5 F\d/m], ['establish',/^G10 L20 P2 Z0$/m]]);
  } },

{ id:'W14', desc:'tools sorted across parts: two returns, both with Z0 invalidated, both re-probed',
  job:'tools-across-parts.cnc',
  props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z'), toolChangeMode:S('Pause') }),
  must:[[/^G10 L20 P1 Z0\.8$/m,'part 1 is re-measured for the second tool'],
        [/^G10 L20 P2 Z0\.8$/m,'and so is part 2']],
  custom:t => counts(t, /a tool change since means Z0 is re-probed/g, 2,
    'both returns say why they are re-probing') },

// === E. which g-code a work offset becomes ============================================
{ id:'W15', desc:'non-adjacent offsets: the code is computed, not counted',
  job:'spread-offsets.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  custom:t => ordered(t, [['G54',/^G54$/m], ['G57',/^G57$/m], ['G59',/^G59$/m]]) },

{ id:'W16', desc:'above G59 on GRBL: refused, naming the offset and what each firmware has',
  job:'high-offsets.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  refuse:[/Work offset 7 is out of range for Grbl \(GRBL supports G54-G59/,'the offset and the range'] },

{ id:'W17', desc:'... and on RepRapFirmware the same job is G59.1 and G59.3',
  job:'high-offsets.cnc',
  props:mp({ jobSelectedFirmware:S('RepRap'), probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  must:[[/^G59\.1$/m,'offset 7'], [/^G59\.3$/m,'offset 9']] },

{ id:'W18', desc:'past G59.3 there is nothing on any firmware, and the post says which',
  job:'offset-out-of-range.cnc',
  props:mp({ jobSelectedFirmware:S('RepRap'), probeOnStart:S('Skip') }),
  refuse:[/Work offset 10 is out of range/,'refused on the firmware with the most registers'] },

{ id:'W19', desc:'the untouched Work Offset field aliases to G54 even beside a real second offset',
  job:'default-offset.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  must:[[/writeWCS: workOffset defaulted to: 1/,'the alias is stated in the file'],
        [/^G54$/m,'and it is G54'], [/^G55$/m,'while the declared second offset is its own']] },

// === F. Marlin, where the dialects differ and one build option carries the job ========
{ id:'W20', desc:'Marlin multi-part: the single-offset suppression must NOT fire, and G92 is the dialect',
  job:'two-parts.cnc',
  props:mp({ jobSelectedFirmware:S('Marlin'), probeOnStart:S('Skip'), probeOnChange:S('Probe Z') }),
  must:[[/^G54$/m,'the first register is selected, because a second one exists'],
        [/^G55$/m,'and so is the second'],
        [/^G92 Z0$/m,'the provisional origin is written positionally']],
  mustNot:[[/G10 L20/,'Marlin has no G10 L20 register write']],
  mustLog:[[/CNC_COORDINATE_SYSTEMS/,'and the one build option the whole job rests on is named']] },

{ id:'W21', desc:'... and the control that proves the gate: the plain Marlin hobby file selects nothing at all',
  job:'one-part.cnc',
  // NO MACHINE FRAME, deliberately -- that is the job the suppression exists for. The frame is what
  // W21c covers, and conflating the two is what made the first version of this case wrong.
  props:{ jobSelectedFirmware:S('Marlin'), machineHomedAxes:S('XYZ'), probeOnStart:S('Skip') },
  mustNot:[[/^G5[4-9]/m,'no select where W20 shows one is required - the pair is the test'],
           [/^G53/m,'and no machine-frame move to pull one in']],
  must:[[/^G0 /m,'and the job is otherwise a job']] },

{ id:'W21c', desc:'... but the frame re-selects G54 on Marlin regardless, and that is not the gate failing',
  job:'one-part.cnc',
  // Debug level, because what is under test is which of two functions decided what -- and that is
  // stated in the file only at Debug. The G54 itself is asserted as g-code, at any level.
  props:mp({ jobSelectedFirmware:S('Marlin'), probeOnStart:S('Skip'), jobCommentLevel:S('Debug') }),
  must:[[/writeWCS: Marlin single-offset job on WCS 1 -- default workspace, no select emitted/,
         'the select really is suppressed'],
        [/re-selecting G54 -- Marlin restores a CHAINED G53 itself/,'and a different function emits one anyway, saying why'],
        [/^G54$/m,'so a G54 does reach the file']],
  // Coherent rather than contradictory, and the reason is worth pinning: the frame needs
  // CNC_COORDINATE_SYSTEMS, and a build that has it has G54 too. The suppression's guarantee is
  // therefore about the FRAMELESS job only, which reading writeWCS() alone would not tell you.
  mustLog:[[/CNC_COORDINATE_SYSTEMS/,'the build option both codes depend on is named']] },

{ id:'W21b', desc:'Marlin reaches G59.1 to G59.3 for the same reason RepRap does, and no further',
  job:'high-offsets.cnc',
  props:mp({ jobSelectedFirmware:S('Marlin'), probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  must:[[/^G59\.1$/m,'offset 7'], [/^G59\.3$/m,'offset 9']] },

// === G. what the operator is told to do about it =====================================
{ id:'W22', desc:'PV-10 - the hand-zero corrects one part, and the parts it strands are re-measured on return',
  job:'tools-across-parts.cnc',
  props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z'),
             toolChangeMode:S('Pause'), toolChangeZ0Correction:S('Manual') }),
  // THE CASE THAT CARRIES THE RULING. The plan is [A@1, A@2, B@1, B@2]: the change at section 3 stands
  // on offset 1, so the hand-zero at its pause reaches THAT register and offset 2 is left measured by
  // the tool being removed. Before PV-10 nothing marked it stale, so section 4 cut it on the old tool's
  // Z0 in silence. The remedy's SCOPE is the finding, which is why the sentence is asserted and not
  // just the instruction.
  must:[[/Re-zero Z by hand at the pause above, which corrects THIS part and no other/,
         'the change states the scope of the remedy it offers'],
        [/the remaining 1 part is marked stale here/,'and how many parts that remedy does not reach'],
        [/a tool change since means Z0 is re-probed/,
         'and the stranded part IS re-measured when the job returns to it']],
  mustNot:[[/since been changed/,
            'and so nothing is left to warn about - the mode could re-measure, so it did']],
  // THE REGIME REACHES THE DIALOG, which is what keeps this change from widening PV-9. It is NOT a twin
  // of the per-return writeWarning() -- that one-channel question is PV-9's, and W11b, W25b and W27
  // still assert it. This says the operator was told BEFORE posting that a hand-zero at one pause does
  // not cover a multi-part job.
  mustLog:[[/corrects the ONE part whose work offset is active there/,
            'and the dialog says so before a block is emitted']],
  custom:t => counts(t, /^G38\.2/gm, 3,
    'three probes: two first visits, then the return to the part the change stranded - PV-10') },

{ id:'W22b', desc:'PV-10 - a tool-length offset corrects the FRAME, so no part is stranded and none is re-probed',
  job:'tools-across-parts.cnc',
  props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z'),
             toolChangeMode:S('Macro'), toolChangeSender:S('gSender'),
             toolChangeZ0Correction:S('Offset') }),
  // THE OTHER HALF OF THE BOOLEAN THAT PV-10 SPLIT, and the whole difference from W22 is reach: G43
  // shifts the Z frame once, so every stored Z0 stays valid at the same instant. Nothing is cleared,
  // nothing is re-measured, and the file states the condition rather than asserting a defect it cannot
  // see. Run on the MACRO flow because that is where the assertion has a party who can satisfy it.
  must:[[/An offset shifts the whole Z frame, so every part in this job stays measured correctly/,
         'the file names why no correction is owed'],
        [/that is right only because a tool-length offset was applied by "gSender/,
         'and whose offset it is trusting']],
  mustNot:[[/since been changed/,'no part is stale, so no return warns'],
           [/a tool change since means Z0 is re-probed/,'and no return re-measures']],
  custom:t => counts(t, /^G38\.2/gm, 2,
    'two probes, both first visits: the change strands nothing, so no return re-measures') },

{ id:'W22c', desc:'PV-10 - "the tool change applies an offset" on a manual pause names a party that does not exist',
  job:'tools-across-parts.cnc',
  props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z'),
             toolChangeMode:S('Pause'), toolChangeZ0Correction:S('Offset') }),
  // NOT REFUSED, and the reason is the one the post cannot see: the operator may apply G43.1 through
  // their sender by hand while the job waits at the M0. So the pre-flight states the condition instead
  // of forbidding the configuration - the rule every Flow 2 assurance already follows.
  mustLog:[[/A manual pause hands over to nothing/,'the dialog says the assertion has no party on this flow']],
  must:[[/An offset shifts the whole Z frame/,'and the file still states what it is trusting']],
  mustNot:[[/applied by "/,'the file names no handler, there being none on this flow']],
  // TWO, AND BOTH ARE FIRST VISITS. The count is not "no probes anywhere" -- Each New WCS / Part is a
  // probing mode here, so sections 1 and 2 measure their own parts. What this answer suppresses is the
  // CHANGE's probe, and the third one W22 produces.
  custom:t => counts(t, /^G38\.2/gm, 2,
    'two probes, both first visits - the change measures nothing and strands nothing') },

// === H. the registers no other job selects ===========================================
{ id:'W23', desc:'offset 8 is past what GRBL has, and a job whose FIRST offset is not 1 is still refused for it',
  job:'mid-offsets.cnc', props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  refuse:[/Work offset 8 is out of range for Grbl/,'names the offset, not just the count'] },

{ id:'W24', desc:'... and on RepRapFirmware all four resolve, including the one that crosses into the G59.x run',
  job:'mid-offsets.cnc',
  props:mp({ jobSelectedFirmware:S('RepRap'), probeOnStart:S('Skip'), probeOnChange:S('Skip') }),
  // 2, 3 and 5 are 53+n; 8 is 59+(8-6)/10 = G59.2. The pair is the point: one arithmetic, two ranges.
  must:[[/^G55$/m,'offset 2'],[/^G56$/m,'offset 3'],[/^G58$/m,'offset 5'],[/^G59\.2$/m,'offset 8']],
  mustNot:[[/^G54$/m,'and G54 never appears - no job here has ever STARTED anywhere but WCS 1']],
  custom:t => ordered(t, [['G55',/^G55$/m],['G56',/^G56$/m],['G58',/^G58$/m],['G59.2',/^G59\.2$/m]]) },

// === I. a tool that cannot probe, on a part this job has never seen (J2, J5) ==========
{ id:'W25', desc:'a jet tool meets a second part: it travels to the stored origin and measures nothing',
  job:'jet-two-parts.cnc',
  // Debug, because what this case is about is which arm ran -- and on a tool that cannot probe the
  // post says so only at Debug. That silence at Info is W25b.
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Probe Z'), jobCommentLevel:S('Debug') }),
  must:[[/^G54$/m,'the first part selects its register'],
        [/^G55$/m,'and the second selects its own'],
        // NO PARENTHESES: the source writes "(tool 0 or jet tool)" and writeComment() strips them,
        // a nested "(" being what would terminate a GRBL comment early. Asserting the source's own
        // text rather than the emitted text is what made this case red on its first run.
        [/writeWcsEstablish: probe skipped tool 0 or jet tool -- moving to stored X0 Y0/,
         'the canProbe-false arm of Subsequent WCS / Part, reached for the first time']],
  mustNot:[[/G38\.2/,'nothing probes: a jet tool cannot, and the arm knows it']],
  custom:t => ordered(t, [['G54',/^G54$/m],
                          ['travel-height retract',/^G53 G0 Z-5 F\d/m],
                          ['WCS change',/WCS changed: 1 -> 2/],
                          ['G55',/^G55$/m],
                          ['probe skipped',/writeWcsEstablish: probe skipped/]]) },

{ id:'W25b', desc:'PV-3 - and at the shipped level the second part SAYS that nothing established its Z0',
  job:'jet-two-parts.cnc',
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Probe Z') }),
  // This case asserted the GAP until PV-3 closed it: writeWcsEstablish()'s closing comment granted
  // trust to "the tool-0 arms, which have already warned that nothing established it", and both of
  // them wrote eComment.Debug, so at the shipped Info nothing said it in either channel.
  must:[[/^G55$/m,'the second part is selected and cut'],
        [/>>> WARNING[^)]*Z0 was NOT established/,'and the file says nothing established its Z0'],
        [/Use "Jog to X0 Y0 Z0"/,'naming the SUBSEQUENT-part mode that sets Z0 with no probe']],
  mustNot:[[/^G38\.2/m,'still nothing probes - a jet tool cannot']],
  // BOTH CHANNELS, on PV-9's ruling. PV-3 raised this warning and left its channel open on purpose,
  // and this row pinned the absence so the ruling could not land unnoticed -- which is exactly what
  // happened: it went red on the twin and was inverted here rather than deleted.
  mustLog:[[/Z0 was NOT established/,"and the dialog says nothing established it - PV-9 closed PV-3's question"]] },

{ id:'W28', desc:'PV-3/J2 - the Jog XY & Probe Z arm met by a tool that cannot probe',
  job:'jet-two-parts.cnc',
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Jog XY & Probe Z') }),
  // The third of PV-3's three sites and the last thing J2 owed. The jog establishes X0 Y0 and
  // nothing establishes Z0, so the register keeps whatever Z it held -- the same silence as W25b,
  // one mode over, and reached by a property set rather than by a new job file.
  must:[[/^G10 L20 P2 X0 Y0$/m,"the jog sets X0 Y0 into the second part's own register"],
        [/>>> WARNING[^)]*Z0 was NOT established/,'and the file says the Z half was not set']],
  mustNot:[[/^G10 L20 P2 X0 Y0 Z0$/m,'no provisional Z0 - nothing would overwrite it, CR-12'],
           [/^G38\.2/m,'and no probe: the tool cannot']],
  // THE THIRD OF PV-3's ARMS, and it reaches the same one writer -- so the twin covers it without a
  // second edit, which is the whole argument for warnZ0NotEstablished() having one caller-supplied
  // clause and one text. Asserted here because "covered by construction" is a claim, not a witness.
  mustLog:[[/Z0 was NOT established/,'the Jog XY & Probe Z arm reaches the dialog too -- PV-9']],
  custom:t => ordered(t, [['jog prompt',/MSG,Jog to X0 Y0 above Z0/],
                          ['X0 Y0 only',/^G10 L20 P2 X0 Y0$/m],
                          ['warning',/Z0 was NOT established/]]) },

// === J. a change INTO a tool that cannot probe (PR-22) ===============================
{ id:'W26', desc:'a mill hands over to a laser: the OUTGOING tool is what decides the spindle stop',
  job:'mill-then-jet.cnc', props:mp({ probeOnStart:S('Skip'), toolChangeMode:S('Pause') }),
  // PR-22 was this exact boundary read the wrong way round: the guard consulted the INCOMING tool,
  // saw a jet tool, and skipped the spindle stop -- handing the operator a still-turning cutter.
  // The fix was walked and never witnessed, and this is the only job that can witness it.
  must:[[/^M0 \(MSG,Turn OFF spindle\)$/m,'the milling spindle is stopped before the operator reaches in'],
        [/M0 \(MSG,Change to Tool #2[^)]*\)/,'and then the change is handed over'],
        [/cannot probe, so work Z0 still measures from the tool just removed/,
         'and the file names what the incoming tool cannot correct']],
  mustNot:[[/G38\.2/,'no re-probe after the change: the tool that arrived cannot probe']],
  // THE CHANGE-SIDE MEMBER of PV-9's class, which Step W's walk found: the same "Z0 measures from a
  // tool no longer fitted" that W11b and W27 assert on the RETURN, one boundary earlier. Nothing
  // pinned its channel before the audit, which is how it would have been left behind.
  mustLog:[[/cannot probe, so work Z0 still measures from the tool just removed/,
            'and the dialog carries the change-side statement as well -- PV-9']],
  custom:t => ordered(t, [['retract',/Retract to the travel height in the machine frame before the tool change/],
                          ['spindle stop',/^M0 \(MSG,Turn OFF spindle\)$/m],
                          ['hand over',/MSG,Change to Tool #2/],
                          ['jet warning',/cannot probe, so work Z0 still measures/],
                          ['laser fires',/^M4 S\d+$/m]]) },

{ id:'W27', desc:'a return the returning tool cannot re-measure: the one arm of writeWcsOnReturn() that can only warn',
  job:'jet-return.cnc',
  props:mp({ probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z'), toolChangeMode:S('Pause') }),
  must:[[/Return to a part already set up -- move to its stored origin X0 Y0/,'it reaches the part'],
        [/stored Z0 was measured with a tool that has since been changed/,
         'and says the depths below it are wrong by a tool length']],
  mustNot:[[/a tool change since means Z0 is re-probed/,'it cannot re-probe, so it must not claim to']],
  // SCOPED TO AFTER THE CHANGE. Section 1 is a MILLING tool and probes correctly; an unscoped
  // "no G38.2" reads that legitimate probe as the defect and fails a passing post, which is what
  // it did on this case's first run.
  custom:t => {
    const all = countOf(t, /^G38\.2/gm);
    if (all !== 1) return [false, `${all} probes in the job, expected 1 -- the first part, with the milling tool`];
    const after = t.slice(t.search(/MSG,Change to Tool #2/));
    const n = countOf(after, /^G38\.2/gm);
    return [n === 0, n === 0 ? 'one probe before the laser is fitted and none after'
                             : `${n} probes after a change into a tool that cannot probe`];
  },
  // THE canProbe-FALSE ARM of the same statement, and the reason PV-9 could not be fixed at the mode:
  // different cause, identical consequence, one writeWcsOnReturn() call. W11b covers the mode side, so
  // the pair of them proves warnBothChannels() reaches the dialog from both.
  mustLog:[[/stored Z0 was measured with a tool that has since been changed/,
            'and the dialog hears it on the tool side too -- PV-9']] },

// === PV-13 -- the first tool a changer cannot fit ====================================
// jet-two-parts.cnc opens on a jet tool, which is the one shape that reaches this arm from a job
// file: no handler in the list acts on "T0 M6" and a laser is not in a changer. The M0 routes are
// deliberately unaffected -- asking a person to fit a laser is a sensible thing to do -- so the
// suppression is the hand-over's alone.
{ id:'W29', desc:'PV-13 - a first tool no changer can fit is not handed over, and both channels say so',
  job:'jet-two-parts.cnc',
  props:mp({ probeOnStart:S('Skip'), probeOnChange:S('Skip'), toolChangeMode:S('Macro'),
             toolChangeSender:S('gSender'), toolChangeFirstToolCorrect:B(false) }),
  must:[[/a jet tool or tool 0, which no tool changer can fit/,'the file names why nothing was emitted']],
  mustNot:[[/^T\d+ M6$/m,'no token: the handler could not act on this one'],
           [/MSG,Load Tool #/,'and the M0 is NOT the fallback -- this mode was chosen to avoid one']],
  mustLog:[[/no tool changer can fit and no supported handler can act on/,
            'and the operator hears it before posting, not only in the file']] },
];

// ---- run ------------------------------------------------------------------------------
const results = [];

for (const c of cases) {
  const gcode = path.join(OUT, `${c.id}.gcode`);
  const log   = path.join(OUT, `${c.id}.log`);
  if (fs.existsSync(gcode)) fs.unlinkSync(gcode);
  if (fs.existsSync(log)) fs.unlinkSync(log);

  const args = ['--noeditor','--nointeraction','--nobackup','--noprogress','--log',log];
  for (const [k,v] of Object.entries(c.props)) args.push('--property', k, v);
  args.push(CPS, path.join(JOBS, c.job), gcode);

  const r = spawnSync(POST, args, { encoding:'utf8' });
  const posted = r.status === 0 && fs.existsSync(gcode);
  const text = posted ? fs.readFileSync(gcode,'utf8') : '';
  const logText = (fs.existsSync(log) ? fs.readFileSync(log,'utf8') : '')
                + (r.stdout || '') + (r.stderr || '');

  const checks = [];
  if (c.refuse) {
    checks.push([!posted, `refuse: no file is produced (exit ${r.status})`]);
    checks.push([c.refuse[0].test(logText), `refuse: ${c.refuse[1]}`]);
  } else if (!posted) {
    checks.push([false, `post refused (exit ${r.status}) -- ${(logText.match(/Error: .*/) || ['no error line'])[0]}`]);
  } else {
    for (const [re,what] of (c.must||[]))       checks.push([re.test(text),      `must: ${what}`]);
    for (const [re,what] of (c.mustNot||[]))    checks.push([!re.test(text),     `must not: ${what}`]);
    for (const [re,what] of (c.mustLog||[]))    checks.push([re.test(logText),   `must warn: ${what}`]);
    for (const [re,what] of (c.mustNotLog||[])) checks.push([!re.test(logText),  `must not warn: ${what}`]);
    if (c.custom) checks.push(c.custom(text));
  }
  const pass = checks.every(x=>x[0]);
  results.push({ id:c.id, desc:c.desc, pass, checks });
}

for (const r of results) {
  console.log(`${r.pass?'PASS':'FAIL'}  ${r.id}  ${r.desc}`);
  for (const [ok,what] of r.checks) if (!ok || process.env.VERBOSE) console.log(`        ${ok?'ok ':'>> '} ${what}`);
}
console.log(`\n${results.filter(r=>r.pass).length} / ${results.length} cases pass`);
