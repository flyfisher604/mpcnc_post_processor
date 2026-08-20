/**
  hobbyist-matrix.js -- the properties a hobbyist actually sets, each posted and checked.
  `findings.md` §5 `PV-1b` is the row; the personas are `Assessment/01-personas.md` --
  P1/P2 hand-zeroed on a personal licence (GRBL, Marlin), P3/P4 homed with a Z probe and
  several tools.

  Three channels, as in the other three matrices -- this was the last one reading only the
  file, so a hobbyist-facing dialog warning had nowhere to be asserted at all:
    must / mustNot        the emitted g-code
    mustLog / mustNotLog  the post-time channel -- warning(), which reaches the dialog

  Each case states what the file MUST contain and MUST NOT, before it is posted. That
  order matters more than it looks: six of these cases failed on the first run and every
  one of them was a wrong expectation of mine, two of them wrong because a registered
  finding had already changed the answer -- CR-12's provisional Z0, and CR-15 dropping the
  first-tool prompt on a mode that implies a tool is already fitted. A matrix written after
  reading the output would have encoded the behaviour instead of testing it.

  Node spawns post.exe with an argument ARRAY, so the JS-literal quoting a property value
  needs is handled by Node's own CRT quoting rather than by a shell -- see design.md.

  Run:
    node tools/hobbyist-matrix.js <post.exe> <post.cps> "<CNC files dir>" <output dir>
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

const cases = [
// --- P1: hand-zeroed beginner, personal licence, GRBL, trim router -------------------
{ id:'H1', desc:'P1 baseline - hand-set zero, trim router, one operation', cnc:'Milling/2D/face.cnc', props:{},
  must:[[/^G54$/m,'selects WCS 1'],[/^G10 L20 P1 X0 Y0 Z0$/m,'records XY plus CR-12 provisional Z0'],
        [/^G38\.2 F30 Z-10$/m,'probes Z at the shipped target and speed'],[/^G10 L20 P1 Z0\.8$/m,'plate thickness becomes Z0'],
        [/^M0 \(MSG,Attach ZProbe\)$/m,'prompts to fit the probe'],[/^M0 \(MSG,Turn ON 5000 RPM\)$/m,'prompts the router on'],
        [/^M30$/m,'ends the program']],
  mustNot:[[/\$H/,'no homing'],[/G53/,'no machine frame'],[/^M3\b/m,'no commanded spindle']] },

// --- P2: same, Marlin ---------------------------------------------------------------
{ id:'H2', desc:'P2 baseline - Marlin dialect', cnc:'Milling/2D/face.cnc', props:{jobSelectedFirmware:S('Marlin')},
  must:[[/^G92 X0 Y0 Z0$/m,'Marlin sets origin with G92'],[/^M0 Attach ZProbe$/m,'Marlin M0 takes a bare message, no (MSG,)'],[/^;/m,'semicolon comments'],[/^G21$/m,'mm units']],
  mustNot:[[/^G10 L2/m,'no G10 L2 - Marlin has no such command'],[/^\(/m,'no parenthesis comments']] },

// --- comment levels -----------------------------------------------------------------
{ id:'H3', desc:'Comment Level Off - smallest file, warnings survive', cnc:'Milling/2D/face.cnc', props:{jobCommentLevel:S('Off')},
  must:[[/>>> WARNING/,'a warning outlives the level gate (HB-9)']],
  mustNot:[[/jobCommentLevel =/,'no property dump'],[/\*\*\* SECTION begin/,'no section banners']] },
{ id:'H4', desc:'Comment Level Debug - traces present', cnc:'Milling/2D/face.cnc', props:{jobCommentLevel:S('Debug')},
  must:[[/writeWcsOnStart:/,'origin dispatch traced'],[/parseSafeZProperty:/,'safe-Z parse traced']], mustNot:[] },

// --- output shape the sender cares about --------------------------------------------
{ id:'H5', desc:'Arcs off - a sender that mishandles G2/G3', cnc:'Milling/2D/bore.cnc', props:{jobUseArcs:B(false)},
  must:[[/^G1 /m,'cuts as straight lines']], mustNot:[[/^G[23] /m,'no arcs emitted']] },
{ id:'H6', desc:'Sequence numbers - line numbers for a sender that reports them', cnc:'Milling/2D/face.cnc',
  props:{jobSequenceNumbers:B(true), jobSequenceNumberStart:N(10), jobSequenceNumberIncrement:N(5)},
  must:[[/^N10 /m,'starts at 10'],[/^N15 /m,'increments by 5']], mustNot:[] },
{ id:'H7', desc:'No word separator - compact blocks', cnc:'Milling/2D/face.cnc', props:{jobSeparateWordsWithSpace:B(false)},
  must:[[/^G10L20P1X0Y0Z0$/m,'words run together']], mustNot:[[/^G10 L20/m,'no spaced form']] },

// --- feeds ---------------------------------------------------------------------------
{ id:'H8', desc:'Travel speeds - the F word on rapids follows the property', cnc:'Milling/2D/face.cnc',
  props:{feedsTravelSpeedXY:N(1800), feedsTravelSpeedZ:N(420)},
  must:[[/F1800/,'XY travel rate'],[/F420/,'Z travel rate']], mustNot:[[/F2500/,'the shipped default is gone']] },
{ id:'H9', desc:'Cut speed ceiling - the MPCNC feed limiter', cnc:'Milling/2D/bore.cnc',
  props:{feedsScaleFeedrate:B(true), feedsMaxCutSpeedXY:N(300), feedsMaxCutSpeedZ:N(90), feedsMaxCutSpeedXYZ:N(320)},
  must:[], mustNot:[], custom:(t)=>{
    const feeds=[]; const re=/^G1 [^\n]*F(\d+(?:\.\d+)?)/gm; let m;
    while ((m=re.exec(t))) feeds.push(parseFloat(m[1]));
    const over=feeds.filter(f=>f>320);
    return over.length? [false,`${over.length} cutting moves exceed the 320 ceiling (max ${Math.max(...over)})`]
                      : [true,`all ${feeds.length} cutting feeds within the ceiling`]; } },
{ id:'H10', desc:'Enforce feedrate off - F only when it changes', cnc:'Milling/2D/bore.cnc', props:{feedsEnforceFeedrate:B(false)},
  must:[], mustNot:[], compare:{cnc:'Milling/2D/bore.cnc', props:{}}, custom:(t,ref)=>{
    const n=(t.match(/F\d/g)||[]).length, r=(ref.match(/F\d/g)||[]).length;
    return n<r? [true,`${n} F words against ${r} with it on`] : [false,`${n} F words, expected fewer than ${r}`]; } },

// --- group 5, the heart of hobby use -------------------------------------------------
{ id:'H11', desc:'Origin: Current XYZ - no probe at all', cnc:'Milling/2D/face.cnc', props:{probeOnStart:S('Current XYZ')},
  must:[[/^G10 L20 P1 X0 Y0 Z0$/m,'all three axes taken from where the tool sits']],
  mustNot:[[/^G38\.2/m,'no probe'],[/Attach ZProbe/,'no probe prompt']] },
{ id:'H12', desc:'Origin: Probe Z only - XY already set in the sender', cnc:'Milling/2D/face.cnc', props:{probeOnStart:S('Probe Z')},
  must:[[/^G38\.2 /m,'probes Z'],[/^G10 L20 P1 Z0\.8$/m,'writes Z0 only']],
  mustNot:[[/^G10 L20 P1 X0 Y0/m,'does not touch XY']] },
{ id:'H13', desc:'Origin: Skip - operator owns everything', cnc:'Milling/2D/face.cnc', props:{probeOnStart:S('Skip')},
  must:[], mustNot:[[/^G38\.2/m,'no probe'],[/^G10 L20/m,'no origin write']] },
{ id:'H14', desc:'Origin: Jog to XY then probe', cnc:'Milling/2D/face.cnc', props:{probeOnStart:S('Jog XY & Probe Z')},
  must:[[/M0 \(MSG,[^)]*[Jj]og[^)]*\)/,'prompts the operator to jog'],[/^G10 L20 P1 X0 Y0 Z0$/m,'then records XY'],[/^G38\.2 /m,'then probes Z']],
  mustNot:[] },
{ id:'H15', desc:'Probe pause: No - unattended, plate left fitted', cnc:'Milling/2D/face.cnc', props:{probePause:S('No')},
  must:[[/^G38\.2 /m,'still probes']], mustNot:[[/Attach ZProbe/,'no fit prompt'],[/Detach ZProbe/,'no removal prompt']] },
{ id:'H16', desc:'Probe geometry - target, speed and plate thickness all follow the dialog', cnc:'Milling/2D/face.cnc',
  props:{probeG38Target:N(-25), probeG38Speed:N(45), probeThickness:'1.5'},
  must:[[/^G38\.2 F45 Z-25$/m,'target and speed as set'],[/^G10 L20 P1 Z1\.5$/m,'thickness as set']], mustNot:[] },
{ id:'H17', desc:'Probe offset - plate cannot sit on the part origin', cnc:'Milling/2D/face.cnc',
  props:{probeOffsetX:N(30), probeOffsetY:N(-15)},
  must:[[/X30 Y-15/,'traverses to the plate position'],[/^G38\.2 /m,'probes there']], mustNot:[] },

// --- group 4, the homed hobbyist (P3) ------------------------------------------------
{ id:'H18', desc:'P3 - homed machine, machine-frame travel, park clear of the work', cnc:'Milling/2D/face.cnc',
  props:{machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'), machineHomeAtStart:S('Home'), machineParkAtEnd:S('Machine')},
  must:[[/^\$H$/m,'homes first'],[/^G53 G0 Z-5 /m,'retracts in the machine frame'],[/^G53 G0 X0 Y0 /m,'parks at machine zero']],
  mustNot:[] },
{ id:'H19', desc:'Park at work zero - the safe default for a hand-zeroed job', cnc:'Milling/2D/face.cnc', props:{machineParkAtEnd:S('Work')},
  must:[[/^X0 Y0 F\d+$/m,'returns to the part origin']], mustNot:[[/G53/,'not the machine frame']] },
{ id:'H20', desc:'Park off - leave the tool where it finished', cnc:'Milling/2D/face.cnc', props:{machineParkAtEnd:S('Off')},
  must:[[/^M30$/m,'still ends cleanly']], mustNot:[[/^X0 Y0 F/m,'no return move']] },

// --- group 6, several tools by hand (P3) ---------------------------------------------
// PV-13 INVERTED THE SENSE AND MOVED THE KEY, so B(true) below became B(false) here. An unknown key is
// not an error to post.exe -- it posts at the default -- so these three would have gone quietly wrong
// rather than red, which is why the sweep for the old name matters more than the edit does.
{ id:'H21', desc:'Two tools, manual change, first tool loaded, Z re-probed after', cnc:'Milling/2D/toolchange.cnc',
  props:{toolChangeMode:S('Pause'), toolChangeFirstToolCorrect:B(false), toolChangeZ0Correction:S('Probe')},
  must:[[/M0 \(MSG,[^)]*Change to Tool #2[^)]*\)/,'prompts at the change'],
        [/^M0 \(MSG,Turn OFF spindle\)$/m,'spindle stopped before the operator reaches in']],
  mustNot:[[/^M6/m,'no M6 - GRBL answers error:20'],[/^T\d/m,'no T word']],
  custom:(t)=>{ const n=(t.match(/^G38\.2 /gm)||[]).length;
    return n===2? [true,'two probes: the part, then again after the change'] : [false,`${n} probes, expected 2`]; } },
{ id:'H22', desc:'Correction by the tool change - the operator asserts a tool-length offset', cnc:'Milling/2D/toolchange.cnc',
  props:{toolChangeMode:S('Pause'), toolChangeZ0Correction:S('Offset')},
  must:[[/M0 \(MSG,[^)]*Change to Tool #2[^)]*\)/,'still stops for the change']],
  custom:(t)=>{ const n=(t.match(/^G38\.2 /gm)||[]).length;
    return n===1? [true,'one probe only - the change does not re-probe'] : [false,`${n} probes, expected 1`]; } },
{ id:'H23', desc:'First tool IS loaded where the mode does not imply one fitted', cnc:'Milling/2D/toolchange.cnc',
  props:{toolChangeMode:S('Pause'), toolChangeFirstToolCorrect:B(false), probeOnStart:S('Probe Z')},
  must:[[/M0 \(MSG,[^)]*Tool #1[^)]*\)/,'prompts for the first tool']], mustNot:[] },
{ id:'H24', desc:'CR-15 - the dropped first-tool load is stated, not silent', cnc:'Milling/2D/toolchange.cnc',
  props:{toolChangeMode:S('Pause'), toolChangeFirstToolCorrect:B(false)},
  must:[[/WARNING[^)]*([Ff]irst [Tt]ool)/,'the file says nothing was emitted to load one']],
  mustLog:[[/"First Tool is Correct" is Off, but "First WCS \/ Part"/,'and PV-13 gave it the dialog half too']] },
{ id:'H25', desc:'A jet tool withholds the provisional Z0 a milling tool gets', cnc:'Cutting/Laser/center.cnc', props:{},
  must:[[/^G10 L20 P1 X0 Y0$/m,'no Z word - a fake Z0 would silently become Set X0 Y0 Z0']],
  mustNot:[[/^G10 L20 P1 X0 Y0 Z0$/m,'the milling form must not appear']] },

// --- HR-26 reopened: a CLEARANCE retract must not read a PROBE's guard --------------------
// H36 AND H37 ARE THE SAME ASSERTION ON PURPOSE, and that is the whole finding: "Use WCS X0 Y0 Z0"
// probes nothing, so the lift before the crossing to the stored X0 Y0 cannot depend on whether the
// tool COULD have probed. It did -- canProbe gated it -- so the laser job below crossed the bed at
// whatever height it was holding while the identical milling job was lifted to Safe Z first. Neither
// case sets "Machine Travel Z": with a frame the G53 establish has already lifted the tool and the
// bug is invisible, which is why every jet case on the books walked past it.
{ id:'H36', desc:'HR-26 - a jet tool on Use WCS X0 Y0 Z0 is lifted to Safe Z before crossing to the origin',
  cnc:'Cutting/Laser/center.cnc', props:{probeOnStart:S('Skip')},
  must:[[/^G0 Z\d+(\.\d+)? F\d/m,'the clearance move a jet tool used to be denied']],
  mustNot:[[/^G38\.2/m,'still nothing probes - the mode measures nothing and the tool could not anyway']],
  // The X/Y move carries no G0: the Safe-Z rapid above it left G0 modal. If the lift were suppressed
  // again the X/Y line would carry the G0 itself, so this ordering fails loudly rather than silently.
  custom:(t)=>{ const z=t.search(/^G0 Z\d/m), xy=t.search(/^X0 Y0 F\d/m);
    return (z>=0 && xy>=0 && z<xy) ? [true,`Safe Z @${z} then X0 Y0 @${xy}`]
                                   : [false,`lift@${z} crossing@${xy} - the crossing must not lead`]; } },
{ id:'H37', desc:'HR-26 - and the milling job it is meant to match, on the same mode and the same absent frame',
  cnc:'Milling/2D/face.cnc', props:{probeOnStart:S('Skip')},
  must:[[/^G0 Z\d+(\.\d+)? F\d/m,'the lift that was always here, now the control rather than the exception']],
  mustNot:[[/^G38\.2/m,'no probe on this mode either']],
  custom:(t)=>{ const z=t.search(/^G0 Z\d/m), xy=t.search(/^X0 Y0 F\d/m);
    return (z>=0 && xy>=0 && z<xy) ? [true,`Safe Z @${z} then X0 Y0 @${xy}`]
                                   : [false,`lift@${z} crossing@${xy} - the crossing must not lead`]; } },

// --- PV-4, both branches of the condition -------------------------------------------
{ id:'H26', desc:'PV-4 - homing before a Current Pos origin warns IN THE FILE', cnc:'Milling/2D/face.cnc',
  props:{machineHomedAxes:S('XYZ'), machineHomeAtStart:S('Home'), probeOnStart:S('Current XY & Probe Z')},
  must:[[/>>> WARNING: the homing below runs BEFORE/,'the file says the pre-jog is destroyed']],
  mustNot:[], custom:(t)=>{
    const w=t.indexOf('the homing below runs BEFORE'), h=t.search(/^\$H$/m), o=t.search(/^G10 L20 P1 X0 Y0 Z0$/m);
    return (w>=0 && w<h && h<o)? [true,'ordered: warning, then homing, then the origin write']
                              : [false,`out of order - warning@${w} homing@${h} origin@${o}`]; } },
{ id:'H27', desc:'PV-4 - and stays silent where the mode records nothing pre-jogged', cnc:'Milling/2D/face.cnc',
  props:{machineHomedAxes:S('XYZ'), machineHomeAtStart:S('Home'), probeOnStart:S('Probe Z')},
  must:[[/^\$H$/m,'still homes']], mustNot:[[/the homing below runs BEFORE/,'no warning - nothing pre-jogged to destroy']] },
{ id:'H28', desc:'PV-4 - and stays silent when the job does not home at all', cnc:'Milling/2D/face.cnc',
  props:{machineHomedAxes:S('XYZ'), machineHomeAtStart:S('Off'), probeOnStart:S('Current XY & Probe Z')},
  must:[[/^G10 L20 P1 X0 Y0 Z0$/m,'records the pre-jogged origin']],
  mustNot:[[/the homing below runs BEFORE/,'no warning - nothing homes'],[/^\$H$/m,'no homing']] },

// --- PV-2, the emission and the callback that denied it -------------------------------
// THE FINDING WAS THE PAIR, not either line alone. The kernel raises COMMAND_POWER_ON/OFF beside
// onPower(), and onPower() is what emits the control -- so onCommand()'s fall-through reported the
// two lines directly above it as a no-op, 60 times in this one file. J4 posted this job five times
// and read the S words; nothing read what the file said about them.
{ id:'H29', desc:'PV-2 - a laser power change is emitted once and denied never', cnc:'Cutting/Laser/center.cnc',
  props:{},
  must:[[/>>> LASER Power ON/,'onPower() announces the control'],[/^M4 S\d+$/m,'and the laser actually fires']],
  // SCOPED TO THE TWO COMMANDS, not to the fall-through text: a Manual NC instruction that genuinely
  // vanishes must still warn, and HR-13's rule is what puts it there. An unscoped "no denial in this
  // file" would go red for exactly the behaviour the post is supposed to keep -- W27's lesson.
  mustNot:[[/command COMMAND_POWER_(ON|OFF) is not supported by this post/,'onCommand() no longer denies it']],
  custom:(t)=>{
    const on   = (t.match(/>>> LASER Power ON/g)||[]).length;
    const off  = (t.match(/>>> LASER Power OFF/g)||[]).length;
    const fire = (t.match(/^M4 S\d+$/gm)||[]).length;
    const den  = (t.match(/command COMMAND_POWER_(?:ON|OFF) is not supported/g)||[]).length;
    return (on===30 && off===30 && fire===30 && den===0)
      ? [true,'30 power changes each way, 30 control blocks, 0 denials - 60 lines left the file']
      : [false,`on=${on} off=${off} M4=${fire} denials=${den}, expected 30/30/30/0`]; } },

// --- PV-12, the coolant a channel cannot deliver --------------------------------------
// ON A LASER JOB, and that is not a detour: "Laser: Coolant" makes the requested level a PROPERTY,
// so both branches of the ruling are reachable over a job file already on disk. A milling job would
// need one whose tool carries the level, and no shipped .cnc carries a chosen one.
{ id:'H30', desc:'PV-12 - a level neither channel carries: the file said so, and now the dialog names it',
  cnc:'Cutting/Laser/center.cnc',
  props:{laserCoolant:S('Mist'), coolantChannelAMode:S('Flood')},
  must:[[/No matching Coolant channel : Mist requested/,'the emitter still says it, unchanged']],
  // NAMED, NOT COUNTED. The second check reads a real operation-comment out of the job file, which is
  // what proves the walk resolved names rather than falling back to "operation N" - the fallback would
  // satisfy a looser pattern and prove nothing about the ruling this row carries.
  mustLog:[[/asks for "Mist" coolant and neither channel is set to it/,'the dialog names the level'],
           [/The operations that ask for it: "Through-Auto_Center[^"]*", "/,
            'and names the operations that asked, from their own comments - the open ruling']],
  mustNot:[[/^M7$/m,'nothing switches: channel A is set to Flood and this job wants Mist']] },

// THE OTHER BRANCH OF THE RULING, and the only case that distinguishes it from warning always. Both
// Modes Off is the operator declaring the machine has no coolant; Fusion's tools carry Flood whether
// or not anyone wanted it, so an ungated pre-flight would fire on nearly every job in this matrix.
{ id:'H31', desc:'PV-12 - ... and with NO channel configured the dialog stays quiet, the file does not',
  cnc:'Cutting/Laser/center.cnc',
  props:{laserCoolant:S('Mist')},
  must:[[/No matching Coolant channel : Mist requested/,'the file is exact and per-occurrence either way']],
  mustNotLog:[[/asks for "Mist" coolant/,'no channel configured is a declaration, not a misconfiguration']] },

{ id:'H32', desc:'PV-12 - Use custom with no file named: emits nothing, and now says so in both channels',
  cnc:'Cutting/Laser/center.cnc',
  props:{laserCoolant:S('Mist'), coolantChannelAMode:S('Mist'), coolantChannelAOn:S('Use custom')},
  must:[[/coolant channel A is set to "Use custom" but no custom file is named -- nothing emitted/,
         'the emitter still says it, unchanged']],
  mustLog:[[/"Turn Channel A On" is "Use custom".*"Channel A On Custom".*is\s+empty/s,
            'the dialog names the channel AND the field to fill']],
  mustNotLog:[[/asks for "Mist" coolant/,'the level IS matched here - only the file behind it is missing']] },

// --- PV-16, a coolant code posted into the wrong dialect -------------------------------
// ON face.cnc AND NOT ON THE LASER JOB, deliberately: this warning reads two properties and no
// toolpath at all, and the cheapest job that proves it is the one that proves nothing else. What the
// laser job is needed for is the LEVEL question above, which needs a tool that asks for a coolant.
{ id:'H33', desc:'PV-16 - one Marlin code on a GRBL job: the dialog names the field and the dialect',
  cnc:'Milling/2D/face.cnc',
  // The pin is set because since GH-16d the M42 value takes its number from the channel field, and a
  // channel left at 0 is refused before it can post -- which would prove nothing about the dialect.
  props:{coolantChannelAMode:S('Flood'), coolantChannelAOn:S('M42'), coolantChannelAPinFan:N(6)},
  // THE FILE IS THE OTHER HALF OF THE CLAIM, and it is here because the first draft of this case
  // asserted the opposite and failed. face.cnc's tool carries Flood -- Fusion's tools carry it whether
  // or not anyone wanted it, which is the fact PV-12's own gate rests on -- so channel A matches, and
  // a Marlin pin-write lands in a GRBL file. The warning is about a configuration; the damage is a line.
  must:[[/^M42 P6 S255$/m,'the wrong-dialect code really is emitted, into a Grbl file']],
  mustLog:[[/posted for Grbl, and a coolant code it will emit belongs to another firmware/,
            'singular - one field is wrong, and the job dialect is named'],
           [/"Turn Channel A On" is "Mrln: M42 P\{pin\} S255", which this post lists as Marlin/,
            'names the field, its value and the dialect the value was shipped for'],
           [/Choose the "Grbl:" values/,'and names the prefix to pick from instead']],
  mustNotLog:[[/"Turn Channel A Off"/,'the off code is M9 and correct - a paired warning would name it too']] },

// THE REAL SHAPE OF THE MISTAKE: the firmware is changed and the coolant group is left alone. All four
// shipped code defaults are GRBL's, so a Marlin job with both channels configured has four wrong fields
// and gets ONE warning naming each -- which is the count assertion, not the presence of the text.
{ id:'H34', desc:'PV-16 - firmware switched to Marlin, coolant defaults left: four fields, one warning',
  cnc:'Milling/2D/face.cnc',
  props:{jobSelectedFirmware:S('Marlin'), coolantChannelAMode:S('Flood'), coolantChannelBMode:S('Mist')},
  mustLog:[[/posted for Marlin, and coolant codes it will emit belong to another firmware/,'plural'],
           [/Choose the "Mrln:" values/,'the remedy follows the job, not the field']],
  // COUNTED PER LINE AND NOT PER LOG. The harness's logText is the log file plus stdout plus stderr and
  // post.exe echoes each warning to both, so a raw occurrence count reads one warning as two -- which
  // is how this check failed on its first run. The claim is about ONE warning carrying four fields, so
  // it is asked of each warning line: four separate warnings would put one field on each.
  custom:(t,ref,log)=>{
    const fields = ['Turn Channel A On','Turn Channel A Off','Turn Channel B On','Turn Channel B Off'];
    const lines = log.split(/\r?\n/).filter(l => l.includes('belong to another firmware'));
    const whole = lines.filter(l => fields.every(f => l.includes(`"${f}" is "`)));
    return (lines.length > 0 && whole.length === lines.length)
      ? [true,`all four fields in one warning, on each of ${lines.length} channel(s) that carried it`]
      : [false,`${lines.length} warning line(s), ${whole.length} naming all four fields`]; } },

// THE NEGATIVE, AND IT CARRIES THE EXEMPTION WITH IT. Channel A is the shipped GRBL pair on a GRBL job
// -- matching, so silent -- and channel B's on code is "Use custom", which has no dialect the post can
// read and must not be guessed at. CR-22's empty-file warning still fires for B and is left alone: it
// is a different question and this case must not assert its absence.
{ id:'H35', desc:'PV-16 - matching codes say nothing, and "Use custom" is exempt rather than wrong',
  cnc:'Milling/2D/face.cnc',
  props:{coolantChannelAMode:S('Flood'), coolantChannelBMode:S('Mist'), coolantChannelBOn:S('Use custom')},
  mustNotLog:[[/belongs? to another firmware/,'nothing to say: one pair matches and the other has no dialect']] },
];

const results = [];
let reference = null;

for (const c of cases) {
  const gcode = path.join(OUT, `${c.id}.gcode`);
  const log   = path.join(OUT, `${c.id}.log`);
  const args  = ['--noeditor','--nointeraction','--nobackup','--noprogress','--log',log];
  for (const [k,v] of Object.entries(c.props)) args.push('--property', k, v);
  args.push(CPS, path.join(CNCR, c.cnc), gcode);

  const r = spawnSync(POST, args, { encoding:'utf8' });
  if (c.compare) {
    const rg = path.join(OUT, c.id + '-ref.gcode');
    const ra = ['--noeditor','--nointeraction','--nobackup','--noprogress'];
    for (const [k,v] of Object.entries(c.compare.props)) ra.push('--property', k, v);
    ra.push(CPS, path.join(CNCR, c.compare.cnc), rg);
    spawnSync(POST, ra, { encoding:'utf8' });
    reference = fs.existsSync(rg) ? fs.readFileSync(rg,'utf8') : '';
  }
  const ok = r.status === 0 && fs.existsSync(gcode);
  const text = ok ? fs.readFileSync(gcode,'utf8') : '';
  // Read the same way wcs-matrix.js reads it, and for the same reason: the post's warning() stream
  // reaches the log, and --log does not capture what the harness itself prints on the way past.
  const logText = (fs.existsSync(log) ? fs.readFileSync(log,'utf8') : '')
                + (r.stdout || '') + (r.stderr || '');
  if (c.id === 'H1') reference = text;

  const checks = [];
  if (!ok) {
    checks.push([false, `post refused (exit ${r.status})`]);
  } else {
    for (const [re,what] of (c.must||[]))       checks.push([re.test(text), `must: ${what}`]);
    for (const [re,what] of (c.mustNot||[]))    checks.push([!re.test(text), `must not: ${what}`]);
    for (const [re,what] of (c.mustLog||[]))    checks.push([re.test(logText),  `must warn: ${what}`]);
    for (const [re,what] of (c.mustNotLog||[])) checks.push([!re.test(logText), `must not warn: ${what}`]);
    // THE LOG IS A THIRD ARGUMENT AND NOT A SECOND CHANNEL OF ITS OWN. mustLog/mustNotLog answer
    // "is this text there"; a custom check that has to COUNT warnings -- one warning naming four
    // fields, not four warnings -- cannot be written as a pattern, and H34 is the first that needs it.
    if (c.custom) checks.push(c.custom(text, reference, logText));
  }
  const pass = checks.every(x=>x[0]);
  results.push({ id:c.id, desc:c.desc, pass, checks });
}

for (const r of results) {
  console.log(`${r.pass?'PASS':'FAIL'}  ${r.id}  ${r.desc}`);
  for (const [ok,what] of r.checks) if (!ok || process.env.VERBOSE) console.log(`        ${ok?'ok ':'>> '} ${what}`);
}
console.log(`\n${results.filter(r=>r.pass).length} / ${results.length} cases pass`);
