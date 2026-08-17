/**
  professional-matrix.js -- the properties a professional sets, each posted and checked.
  `findings.md` §5 `PV-5` is the row; the personas are `Assessment/01-personas.md` --
  P3/P4 homed and squared with a Z probe and several tools, P7 setting their own work
  offsets. The through-line is "First WCS / Part" crossed with the machine frame, the tool
  change and the firmware, because that property decides what the preamble is ALLOWED to
  do before it and every other group's behaviour changes underneath it.

  THE BOUND THIS MATRIX CANNOT CROSS. Every shipped .cnc file uses ONE work offset -- the
  census settled that, `findings.md` §4 -- so "Each New WCS / Part" is unreachable here and
  so is writeWCS()'s traverse arm. P7's own control is therefore NOT exercised below; what
  is exercised is the first-part half, which is the half a single-offset job reaches.

  Each case states what the file MUST contain and MUST NOT before it is posted, and three
  channels are checked rather than one:
    must / mustNot        the emitted g-code
    mustLog / mustNotLog  the post-time channel -- warning(), which reaches the dialog
    refuse                error(), where the right answer is no file at all
  The two-channel cases are the point of the second pair: `HB-5`'s rule is that a property
  which fails one way fails in BOTH channels, and a matrix that reads only the file cannot
  see half of what the post promises.

  Node spawns post.exe with an argument ARRAY, so the JS-literal quoting a property value
  needs is handled by Node's own CRT quoting rather than by a shell -- see design.md.

  Run:
    node tools/professional-matrix.js <post.exe> <post.cps> "<CNC files dir>" <output dir>
  VERBOSE=1 prints the checks that passed as well as the ones that did not.
*/
const { spawnSync } = require('child_process');
const fs = require('fs'), path = require('path');

const POST = process.argv[2];
const CPS  = process.argv[3];
const CNCR = process.argv[4];
const OUT  = process.argv[5];
fs.mkdirSync(OUT, { recursive: true });

// property helpers -- the literal is built from the declared type, as the harness does
const S = v => `"${v}"`;              // string / enum
const N = v => String(v);             // number
const B = v => (v ? 'true' : 'false');

// The job files. `face` is one section and one tool; `change` is two sections and two tools,
// which is the shipped shape that reaches a tool change. `full program.cnc` would have been
// the richer one -- four sections, two tools -- but it carries an operation compensated IN
// THE CONTROL, which this post refuses on all three firmwares; PRO31 is that refusal.
const face   = 'Milling/2D/face.cnc';
const change = 'Milling/2D/toolchange.cnc';
const full   = 'Milling/2D/full program.cnc';

// THE PROFESSIONAL BASELINE: a machine that homes all three axes, a declared travel height
// in the machine's own frame, homing at job start, and a park at the homing corner. Every
// case below is this plus or minus one decision, so a failure names the decision.
const PRO = { machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'),
              machineHomeAtStart:S('Home'), machineParkAtEnd:S('Machine') };
const pro = (extra) => Object.assign({}, PRO, extra);

// Index of a pattern in the text, or -1 -- for the ordering checks, which are most of what
// distinguishes a correct preamble from a dangerous one.
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

const cases = [
// === A. the six "First WCS / Part" modes, each on the professional frame ==============
{ id:'PRO1', desc:'Use WCS X0 Y0 Z0 - the fixture workflow: nothing is measured, nothing is asked',
  cnc:face, props:pro({ probeOnStart:S('Skip') }),
  must:[[/^\$H$/m,'homes at job start'],
        [/^G54$/m,'selects the work offset the Setup names'],
        [/^G53 G0 Z-5 F\d/m,'establishes the fixed Z reference in the machine frame'],
        [/^G53 G0 X0 Y0 F\d/m,'parks at the homing corner']],
  mustNot:[[/^G38\.2/m,'no probe - the stored Z0 is the whole premise'],
           [/^G10 L20/m,'no origin write of any kind'],
           [/Attach ZProbe/,'no probe prompt']],
  mustNotLog:[[/does not include X\/Y/,'a homed machine earns no stored-offset warning']],
  // The move to the stored X0 Y0 carries no G0 word: the Safe-Z rapid above it left G0 modal,
  // and rapidMovementsXY() writes through gMotionModal, which suppresses a word already active.
  custom:(t)=>ordered(t,[['$H',/^\$H$/m],['G54',/^G54$/m],['G53 establish',/^G53 G0 Z-5 F/m],
                         ['Safe Z',/^G0 Z\d/m],['move to X0 Y0',/^X0 Y0 F\d/m]]) },

{ id:'PRO2', desc:'Use WCS X0 Y0, Probe Z0 - stored XY, Z measured per job, frame present',
  cnc:face, props:pro({ probeOnStart:S('Probe Z') }),
  must:[[/^G10 L20 P1 Z0$/m,'provisional Z0 so G38 Target is a distance (CR-12)'],
        [/^G38\.2 F30 Z-10$/m,'probes at the shipped target and speed'],
        [/^G10 L20 P1 Z0\.8$/m,'plate thickness becomes Z0']],
  mustNot:[[/^G10 L20 P1 X0 Y0/m,'the stored X0 Y0 is never rewritten'],
           [/no Z reference is established/,'the frame removes the unknown-height warning']],
  mustNotLog:[[/rapids to the stored/,'and removes its post-time half too']] },

{ id:'PRO3', desc:'the same mode with the frame taken away - both channels must say so',
  cnc:face, props:{ machineHomedAxes:S('XYZ'), machineHomeAtStart:S('Home'), probeOnStart:S('Probe Z') },
  must:[[/no Z reference is established/,'the file warns the traverse runs at an unknown height'],
        [/^G38\.2 /m,'still probes']],
  mustLog:[[/rapids to the stored/,'and the dialog warns as well - HB-5']] },

{ id:'PRO4', desc:'Set X0 Y0 to Current Pos on a homing machine - PV-4, and the origin leads the G53',
  cnc:face, props:pro({ probeOnStart:S('Current XY & Probe Z') }),
  must:[[/>>> WARNING: the homing below runs BEFORE/,'the file says the pre-jog is destroyed']],
  mustLog:[[/moves the tool onto the endstops/,'and so does the dialog']],
  custom:(t)=>ordered(t,[['warning',/the homing below runs BEFORE/],['$H',/^\$H$/m],
                         ['origin write',/^G10 L20 P1 X0 Y0 Z0$/m],['G53 establish',/^G53 G0 Z-5 F/m]]) },

{ id:'PRO5', desc:'Set X0 Y0 Z0 to Current Pos - the G53 establish is DEFERRED below the origin (CR-15)',
  cnc:face, props:pro({ probeOnStart:S('Current XYZ'), machineHomeAtStart:S('Off'), machineParkAtEnd:S('Work') }),
  must:[[/^G10 L20 P1 X0 Y0 Z0$/m,'all three axes from where the operator left the tool'],
        [/^G53 G0 Z-5 F\d/m,'the frame is still established, just later']],
  mustNot:[[/^G38\.2/m,'no probe'],[/^\$H$/m,'no homing to destroy the pre-jog']],
  custom:(t)=>ordered(t,[['origin write',/^G10 L20 P1 X0 Y0 Z0$/m],['G53 establish',/^G53 G0 Z-5 F/m]]) },

{ id:'PRO6', desc:'Jog to X0 Y0, Probe Z0 - the ordinary order: establish, prompt, record, probe',
  cnc:face, props:pro({ probeOnStart:S('Jog XY & Probe Z') }),
  must:[[/M0 \(MSG,Jog to X0 Y0 above Z0, probe\)/,'prompts the operator to jog']],
  mustLog:[[/A "Jog to \.\.\." origin mode is selected/,'the sender condition is named at post time']],
  custom:(t)=>ordered(t,[['G53 establish',/^G53 G0 Z-5 F/m],['jog prompt',/Jog to X0 Y0 above Z0/],
                         ['origin write',/^G10 L20 P1 X0 Y0 Z0$/m],['probe',/^G38\.2 /m]]) },

{ id:'PRO7', desc:'Jog to X0 Y0 Z0 - prompt, then record all three, and measure nothing',
  cnc:face, props:pro({ probeOnStart:S('Jog XYZ') }),
  must:[[/M0 \(MSG,Jog to X0 Y0 Z0, then continue\)/,'prompts'],
        [/^G10 L20 P1 X0 Y0 Z0$/m,'records all three']],
  mustNot:[[/^G38\.2/m,'no probe']],
  custom:(t)=>ordered(t,[['G53 establish',/^G53 G0 Z-5 F/m],['jog prompt',/Jog to X0 Y0 Z0, then continue/],
                         ['origin write',/^G10 L20 P1 X0 Y0 Z0$/m]]) },

// === B. "First WCS / Part" crossed with the tool change ==============================
{ id:'PRO8', desc:'Use WCS X0 Y0 Z0 + manual change: the ONLY probe in the job is the change re-probe',
  cnc:change, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Pause') }),
  must:[[/M0 \(MSG,Change to Tool #2[^)]*\)/,'stops for the change'],
        [/^M0 \(MSG,Turn OFF spindle\)$/m,'the spindle is stopped before the operator reaches in'],
        [/^G53 G0 Z-5 F\d/m,'retracts in the machine frame to hand over']],
  mustNot:[[/^M6/m,'no M6 - GRBL answers error:20'],[/^T\d/m,'no bare T word on the manual flow']],
  custom:(t)=>{ const n=countOf(t,/^G38\.2 /gm);
    if (n!==1) return [false,`${n} probes, expected exactly 1 (the change re-probe)`];
    return ordered(t,[['tool change',/Change to Tool #2/],['re-probe',/^G38\.2 /m]]); } },

{ id:'PRO9', desc:'the same job corrected by hand at the pause - no probe at all, and the file says why',
  cnc:change, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Pause'), toolChangeZ0Correction:S('Manual') }),
  must:[[/work Z0 was NOT re-established after this tool change/,'names the tool-length error it leaves']],
  mustNot:[[/^G38\.2/m,'nothing measures anything in this job']] },

{ id:'PRO10', desc:'Use WCS X0 Y0, Probe Z0 + manual change - two probes, one per tool',
  cnc:change, props:pro({ probeOnStart:S('Probe Z'), toolChangeMode:S('Pause') }),
  must:[[/^G38\.2 /m,'probes']],
  custom:(t)=>{ const n=countOf(t,/^G38\.2 /gm);
    return n===2? [true,'two probes: the part at start, then again with the new tool']
                : [false,`${n} probes, expected 2`]; } },

{ id:'PRO11', desc:'Flow 2 on gSender - T2 M6, then the post re-asserts everything the macro may have moved',
  cnc:change, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Macro'), toolChangeSender:S('gSender') }),
  must:[[/^T2 M6$/m,'the token the sender intercepts'],
        [/^G90$/m,'absolute re-asserted'],[/^G21$/m,'units re-asserted'],
        [/^G94$/m,'feed mode re-asserted - GRBL only'],[/^G17$/m,'plane re-asserted - GRBL only']],
  mustLog:[[/hands each change over with M6/,'the post cannot verify the sender is configured'],
           [/overwrites whatever the macro measured/,'re-probe on top of a macro is called out']],
  custom:(t)=>{ const i=t.search(/^T2 M6$/m);
    const after=t.slice(i);
    return ordered(after,[['re-assert G90',/^G90$/m],['re-select G54',/^G54$/m],
                          ['return to travel Z',/^G53 G0 Z-5 F/m]]); } },

{ id:'PRO12', desc:'Flow 2 on RepRapFirmware - a bare T word IS the change, and no GRBL modals come back',
  cnc:change, props:pro({ jobSelectedFirmware:S('RepRap'), probeOnStart:S('Skip'),
                        toolChangeMode:S('Macro'), toolChangeSender:S('RepRap') }),
  must:[[/^T2$/m,'the T word alone - tfree/tpre/tpost do the work'],
        [/^G53 G0 Z-5 F\d/m,'the post still returns the tool to a known height'],
        // PV-6: tool.comment is empty on most of Autodesk's own tools, so this line read
        // ";   , declared with M563 in config.g" -- a sentence with no subject. The number is what
        // makes it one, and asserting the bare tail is what let the defect pass unread.
        [/Tool #2[^\n]*, declared with M563 in config\.g/,'the line names the tool it is about']],
  mustNot:[[/M6/,'an M6 would be a second token for a change already made'],
           [/^;\s*, declared with M563/m,'and never the subjectless form - PV-6'],
           [/^G94$/m,'G94 is not re-asserted off GRBL'],[/^G17$/m,'nor G17']],
  mustLog:[[/errors unless every tool number it uses is declared with M563/,'and the dialog says it too']] },

{ id:'PRO13', desc:'Flow 2 on Marlin is refused - there is no offset register for a macro to correct',
  cnc:change, props:pro({ jobSelectedFirmware:S('Marlin'), machineParkAtEnd:S('Work'),
                        toolChangeMode:S('Macro'), toolChangeSender:S('Other'), toolChangeMacroFile:S('change.nc') }),
  refuse:[/no tool-length offset register/,'refused, and names why'] },

{ id:'PRO14', desc:'Flow 2 with no macro file named is refused rather than posting a change that never happens',
  cnc:change, props:pro({ toolChangeMode:S('Macro'), toolChangeSender:S('Other') }),
  refuse:[/there is nothing to hand over to/,'refused'] },

{ id:'PRO15', desc:'a GRBL sender chosen for a RepRap job is refused',
  cnc:change, props:pro({ jobSelectedFirmware:S('RepRap'), toolChangeMode:S('Macro'), toolChangeSender:S('gSender') }),
  refuse:[/which is a GRBL sender/,'refused'] },

{ id:'PRO16', desc:'the shipped default refuses a two-tool job outright',
  cnc:change, props:pro({}),
  // ON THE REMEDIES AND NOT ON THE MODE'S OWN NAME. The title is display text and has now moved twice;
  // what this row is for is that the refusal tells the operator the two ways out, and those are the
  // other two modes by name. A pattern on "Refuse ..." asserts only that the error quotes its own
  // setting back, which is the least informative half of the line.
  refuse:[/"Manual change at a pause".*"Sender or firmware macro changes it"/s,
          'refused, naming both remedies'] },

// === C. the tool change position -- F3's machine-frame excursion =====================
{ id:'PRO17', desc:'a change position: X/Y crosses at the travel height, THEN Z descends, then it returns',
  cnc:change, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Pause'),
                        toolChangePositionX:S('-10'), toolChangePositionY:S('-400'), toolChangePositionZ:S('-20') }),
  must:[[/^G53 G0 X-10 Y-400 F\d/m,'crosses in the machine frame'],
        [/^G53 G0 Z-20 F\d/m,'descends to the change height only after arriving']],
  mustLog:[[/below the "Machine Travel Z"/,'a change height under the travel height is called out']],
  custom:(t)=>ordered(t,[['retract to travel Z',/^G53 G0 Z-5 F/m],['cross to X-10 Y-400',/^G53 G0 X-10 Y-400 F/m],
                         ['descend to Z-20',/^G53 G0 Z-20 F/m],['prompt',/Change to Tool #2/]]) },

{ id:'PRO18', desc:'half a change position is refused - X and Y are read as one point',
  cnc:change, props:pro({ toolChangeMode:S('Pause'), toolChangePositionX:S('-10') }),
  refuse:[/read as one point/,'refused'] },

{ id:'PRO19', desc:'a change position with no machine frame is refused - there is no height to cross at',
  cnc:change, props:{ machineHomedAxes:S('XYZ'), toolChangeMode:S('Pause'),
                    toolChangePositionX:S('-10'), toolChangePositionY:S('-400') },
  refuse:[/no machine frame to move in/,'refused'] },

{ id:'PRO20', desc:'a change position on Flow 2 is warned and NOT emitted - the macro owns where it goes',
  cnc:change, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Macro'), toolChangeSender:S('CNCjs'),
                        toolChangePositionX:S('-10'), toolChangePositionY:S('-400') }),
  mustNot:[[/^G53 G0 X-10 Y-400/m,'the excursion is Flow 1\'s alone']],
  mustLog:[[/so the post does not use it/,'and the dialog says the fields are inert here']] },

// === D. the machine frame and the end park ===========================================
{ id:'PRO21', desc:'park at machine X0 Y0 with no frame - it still parks, and both channels say it cannot retract',
  cnc:face, props:{ machineHomedAxes:S('XY'), machineHomeAtStart:S('Home'), machineParkAtEnd:S('Machine'),
                    probeOnStart:S('Current XYZ') },
  must:[[/no retract before parking at machine X0 Y0/,'the file names the unretracted crossing'],
        [/^G53 G0 X0 Y0 F\d/m,'and still parks']],
  mustLog:[[/crosses the bed to the homing corner/,'and so does the dialog']] },

{ id:'PRO22', desc:'park at machine X0 Y0 without X/Y homed is refused',
  cnc:face, props:{ machineHomedAxes:S('Z'), machineParkAtEnd:S('Machine') },
  refuse:[/requires "Axes Homed and Trusted" to include X\/Y/,'refused'] },

{ id:'PRO23', desc:'park at machine X0 Y0 on GRBL without homing this job is refused',
  cnc:face, props:{ machineHomedAxes:S('XYZ'), machineParkAtEnd:S('Machine'), machineHomeAtStart:S('Off') },
  refuse:[/not one a previous power cycle left behind/,'refused'] },

{ id:'PRO24', desc:'a travel height without Z declared homed is refused',
  cnc:face, props:{ machineHomedAxes:S('XY'), machineTravelZ:S('-5') },
  refuse:[/requires "Axes Homed and Trusted" to include Z/,'refused'] },

{ id:'PRO25', desc:'a travel height at or above machine zero warns in BOTH channels (PR-17)',
  cnc:face, props:pro({ machineTravelZ:S('2'), probeOnStart:S('Skip') }),
  must:[[/machine Z 2 is at or above machine zero/,'the file carries it']],
  mustLog:[[/which is at or above machine zero/,'and so does the dialog']] },

{ id:'PRO26', desc:'the whole professional shape on Marlin - G28 per axis, the build-option warning, the park cost',
  cnc:face, props:pro({ jobSelectedFirmware:S('Marlin'), probeOnStart:S('Skip') }),
  must:[[/^G28 X$/m,'homes X'],[/^G28 Y$/m,'homes Y'],[/^G28 Z$/m,'homes Z'],
        [/CNC_COORDINATE_SYSTEMS/,'every G53 below depends on a build option, and the file says so'],
        [/zero Marlin's position_shift/,'the park costs this file\'s origin, and the file says so']],
  mustNot:[[/^\$H$/m,'no GRBL homing']],
  // TWICE, and the second time is the park: G28 X / G28 Y is how Marlin reaches machine X0 Y0,
  // which is a homing cycle rather than a rapid and is what costs this file its origin.
  custom:(t)=>{ const n=countOf(t,/^G28 X$/gm);
    if (n!==2) return [false,`${n} "G28 X" blocks, expected 2 -- homing at start and the park`];
    const tail = t.slice(t.search(/zero Marlin's position_shift/));
    return ordered(t,[['G28 X home',/^G28 X$/m],['G53 establish',/^G53 G0 Z-5 F/m],
                      ['park warning',/zero Marlin's position_shift/]])[0]
      && /^G28 X$/m.test(tail)
        ? [true,'homes, establishes, warns, then parks by re-homing X/Y']
        : [false,'the park does not follow the warning it depends on']; } },

// === E. stored offsets and the homing declaration ====================================
{ id:'PRO27', desc:'trusting a stored offset on a machine that does not home X/Y is warned',
  cnc:face, props:{ probeOnStart:S('Skip') },
  mustLog:[[/trust the origin already stored in a work offset register/,'the register moves at every reset']] },

{ id:'PRO28', desc:'... and the professional configuration is exactly what silences it',
  cnc:face, props:pro({ probeOnStart:S('Skip') }),
  mustNotLog:[[/trust the origin already stored/,'a homed X/Y makes the stored offset repeatable']] },

// === F. what a professional sender needs out of the file =============================
{ id:'PRO29', desc:'line numbers on: every block is numbered and $H still is not - it takes no N word',
  cnc:face, props:pro({ probeOnStart:S('Skip'), jobSequenceNumbers:B(true), jobCommentLevel:S('Important') }),
  must:[[/^N\d+ G54$/m,'the WCS select is numbered'],
        [/^N\d+ G53 G0 Z-5 F\d/m,'so is the machine-frame move'],
        [/^\$H$/m,'but $H is bare - GRBL reads $ only as the first character of a line']],
  mustNot:[[/^N\d+ \$H/m,'no N word on the homing command']] },

{ id:'PRO30', desc:'an unreadable Safe Z is warned and falls back rather than emitting a wrong height',
  cnc:face, props:pro({ probeOnStart:S('Probe Z'), probeSafeZ:S('15mm') }),
  mustLog:[[/is not a Safe Z expression the post can read/,'named, with the accepted forms']] },

{ id:'PRO31', desc:'compensation IN THE CONTROL is refused - the professional habit these firmwares cannot serve',
  cnc:full, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Pause') }),
  refuse:[/Cutter radius compensation in the control is not supported/,'refused, naming the Fusion setting that fixes it'] },

// === G. the re-probe's touch-point, and whether the job has already cut it (PV-7) =====
// PRO8's configuration exactly, so the pair below adds one property to a case already
// passing: the ONLY probe in the file is the change re-probe, which is what makes the
// warning's presence and absence attributable to nothing else.
{ id:'PRO32', desc:'the change re-probe touches off on a datum section 1 machined - both channels, above the probe',
  cnc:change, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Pause') }),
  // The operation and the depth are named, not just the shape: "2D-Face" runs X-92.662..80
  // by Y-24.375..0.95 down to Z-1, so the box contains X0 Y0 and the touch-point is a
  // machined floor 1 mm below the datum every later depth was computed against.
  must:[[/>>> WARNING: this probe touches off at this part's X0 Y0, "Probe X\/Y Offset" being 0/,
         'the file names the point and the field that moves it'],
        [/ALREADY CUT, down to Z-1 in "2D-Face"/,'and names the operation that cut it, and how deep']],
  mustLog:[[/This job re-probes work Z0 at a point it has already machined/,'and the dialog says it too - HB-5'],
           [/At 1 later boundary the post re-probes Z0 there/,'one boundary, counted rather than hedged']],
  // ABOVE THE MOTION IT WARNS ABOUT, PV-4a's rule: a line below the G38.2 would describe a
  // datum already written. The traverse to the touch-point is between them.
  //
  // READ FROM THE CHANGE PROMPT DOWN, not from line 1: section 1 travels to X0 Y0 itself and
  // ordered() searches for the FIRST match, so a whole-file order proves nothing here. It is
  // the trap `PV-8` names, met a second time.
  custom:(t)=>{ const after = t.slice(t.search(/Change to Tool #2/));
    return ordered(after,[['warning',/ALREADY CUT/],
                          ['traverse to the point',/Move to part origin X0 Y0, then probe Z/],
                          ['re-probe',/^G38\.2 /m]]); } },

{ id:'PRO33', desc:'... and the remedy the warning names is what silences it - the offset moves the point off the cut',
  cnc:change, props:pro({ probeOnStart:S('Skip'), toolChangeMode:S('Pause'), probeOffsetY:N(10) }),
  // Y10 clears "2D-Face"'s Y maximum of 0.95, so the touch-point stands on uncut stock. The
  // OTHER branch of the same condition: the probe is unchanged and only the warning leaves.
  must:[[/^(G0 )?X0 Y10 F\d/m,'the traverse goes to the origin plus the offset']],
  mustNot:[[/ALREADY CUT/,'nothing in the file claims a machined datum any more']],
  mustNotLog:[[/already machined/,'and the dialog is silent as well']],
  custom:(t)=>{ const n=countOf(t,/^G38\.2 /gm);
    return n===1? [true,'the probe itself is untouched - one re-probe, as PRO8 has']
                : [false,`${n} probes, expected 1 -- the offset must move the point, not the probe`]; } },
];

// ---- run ------------------------------------------------------------------------------
const results = [];

for (const c of cases) {
  const gcode = path.join(OUT, `${c.id}.gcode`);
  const log   = path.join(OUT, `${c.id}.log`);
  if (fs.existsSync(gcode)) fs.unlinkSync(gcode);
  if (fs.existsSync(log)) fs.unlinkSync(log);

  const args  = ['--noeditor','--nointeraction','--nobackup','--noprogress','--log',log];
  for (const [k,v] of Object.entries(c.props)) args.push('--property', k, v);
  args.push(CPS, path.join(CNCR, c.cnc), gcode);

  const r = spawnSync(POST, args, { encoding:'utf8' });
  const posted = r.status === 0 && fs.existsSync(gcode);
  const text = posted ? fs.readFileSync(gcode,'utf8') : '';
  // The post-time channel: warning() and error() both land in the log, and a refusal also
  // reaches stdout -- so a case that asserts on either reads all of them as one stream.
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
