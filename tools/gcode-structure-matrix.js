/**
  gcode-structure-matrix.js -- GCodeStructure: does the whole file read, top to bottom, like a
  program a CNC operator would put on a machine.

  HOW THIS CATEGORY DIFFERS IN SHAPE FROM THE OTHER FIVE, and the difference is deliberate. Every
  other matrix is a list of CASES, each asserting one thing about one configuration. This one is a
  list of INVARIANTS crossed with a list of PROGRAMS: each invariant is a rule that must hold of any
  file this post produces, and each program is a configuration it must hold in. A case there names a
  decision; a failure here names a rule and the program that broke it.

  It is written that way because that is how the questions arrive. Nobody asks "does face.cnc under
  Marlin retract before it traverses" -- they ask "does this post ever traverse without retracting",
  and the only honest answer is a rule applied to every file the suite can produce. The four original
  matrices between them post 115 files and not one of them looks at a file as a whole.

  WHAT AN INVARIANT MAY ASSERT. Only what an operator reading the file could object to without
  knowing this post: preamble before motion, origin before coordinates, spindle before cutting, a
  retract before a traverse, an end after everything, a program that stops the spindle before it
  parks. A rule that is really about this post's own design belongs in one of the other matrices --
  those are decisions, and a decision is not an invariant.

  APPLICABILITY IS PART OF THE RULE, not a way to duck one. `Comment Level Off` removes the section
  banners, so the banner rule has nothing to read; a jet program has no spindle to stop. Each
  invariant states what it needs and is reported as skipped where it is not there -- and a program
  that skips more than half of them fails outright, so applicability cannot quietly empty this file.

  Run:
    node tools/gcode-structure-matrix.js <post.exe> <post.cps> "<CNC files dir>" <output dir>
  VERBOSE=1 prints every invariant, including the ones that were skipped.
*/
const { spawnSync } = require('child_process');
const fs = require('fs'), path = require('path');
const M = require('./gcode-model.js');

const POST = process.argv[2];
const CPS  = process.argv[3];
const CNCR = process.argv[4];
const OUT  = process.argv[5];
if (!POST || !CPS || !CNCR || !OUT) {
  console.error('usage: node tools/gcode-structure-matrix.js <post.exe> <post.cps> "<CNC files dir>" <output dir>');
  process.exit(2);
}
fs.mkdirSync(OUT, { recursive: true });

const TRACE = path.join(__dirname, 'trace.cps');
const WCSJOBS = path.join(__dirname, 'wcs-jobs');

const S = v => `"${v}"`;
const B = v => (v ? 'true' : 'false');

// ---------------------------------------------------------------------------------------------
// Reading helpers -- what a rule below is allowed to ask the file.
// ---------------------------------------------------------------------------------------------

const isCut     = m => m.kind === 'move' && (m.g === 1 || m.g === 2 || m.g === 3);
const isRapid   = m => m.kind === 'move' && m.g === 0;
const movesXY   = m => (m.xWord !== undefined || m.yWord !== undefined) &&
                       (!M.near(m.from && m.from.x, m.to && m.to.x, 0.0011) ||
                        !M.near(m.from && m.from.y, m.to && m.to.y, 0.0011) ||
                        m.from === undefined);
// A comment's line number, or -1. Comments are where the post states what it is doing, and three of
// the rules below are about a block standing in the right place relative to one.
const commentAt = (ctx, needle) => {
  for (const l of ctx.lines) if ((l.comment || '').indexOf(needle) >= 0) return l.i;
  return -1;
};
const commentsAt = (ctx, needle) => ctx.lines.filter(l => (l.comment || '').indexOf(needle) >= 0).map(l => l.i);

// WHAT THE OPERATOR IS TOLD, WHEREVER THE DIALECT PUTS IT. GRBL carries a prompt inside a comment --
// `M0 (MSG,Turn OFF spindle)` -- and the other two carry it as the message of the block itself:
// `M0 Turn OFF spindle`, `M291 P"Turn OFF spindle" ...`. A rule about a prompt that read only
// comments passed on GRBL and failed on Marlin for a post that is right, which is what it did.
const promptsAt = (ctx, needle) => ctx.lines
  .filter(l => (l.comment || '').indexOf(needle) >= 0 || (l.message || '').indexOf(needle) >= 0)
  .map(l => l.i);
// The first block whose text matches, by line number.
const blockAt = (ctx, re) => { for (const b of M.blocks(ctx.lines)) if (re.test(b.raw)) return b.i; return -1; };
const blocksAt = (ctx, re) => M.blocks(ctx.lines).filter(b => re.test(b.raw)).map(b => b.i);

const ok   = msg => [true, msg];
const fail = msg => [false, msg];
const SKIP = null;

// ---------------------------------------------------------------------------------------------
// The invariants.
// ---------------------------------------------------------------------------------------------

const INVARIANTS = [

{ name:'preamble-before-motion',
  why:'a controller that has not been told absolute-vs-relative and its units will move somewhere else',
  run: ctx => {
    const first = ctx.motions.filter(m => m.kind === 'move' || m.kind === 'machine' || m.kind === 'probe')[0];
    if (!first) return SKIP;
    const need = [[/^(N\d+ )?G90\b/, 'G90'], [/^(N\d+ )?G2[01]\b/, 'the unit code']];
    if (ctx.fw === 'Grbl') need.push([/^(N\d+ )?G94\b/, 'G94'], [/^(N\d+ )?G17\b/, 'G17']);
    for (const [re, what] of need) {
      const at = blockAt(ctx, re);
      if (at < 0) return fail(`${what} is never emitted, and line ${first.line} already moves the machine`);
      if (at > first.line) return fail(`${what} is at line ${at}, below the first motion at line ${first.line}`);
    }
    return ok(`${need.length} modal declarations all stand above the first motion at line ${first.line}`); } },

{ name:'units-and-distance-never-change',
  why:'a file that switches units or to relative mid-program is a file nobody can read a coordinate out of',
  run: ctx => {
    const units = blocksAt(ctx, /^(N\d+ )?G2[01]\b/);
    const inch = blocksAt(ctx, /^(N\d+ )?G20\b/).length, mm = blocksAt(ctx, /^(N\d+ )?G21\b/).length;
    if (inch && mm) return fail('the file declares both G20 and G21');
    const rel = blocksAt(ctx, /^(N\d+ )?G91\b/);
    if (rel.length) return fail(`G91 at line ${rel[0]} -- every coordinate this post writes is absolute`);
    return ok(`${units.length} unit declaration(s), all the same, and no G91 anywhere`); } },

{ name:'origin-established-before-coordinates',
  why:'a coordinate means nothing until the file has said which origin it is measured from',
  run: ctx => {
    const firstWork = ctx.motions.filter(m => m.kind === 'move')[0];
    if (!firstWork) return SKIP;
    const est = [blockAt(ctx, /^(N\d+ )?G5[4-9](\.\d)?\b/), blockAt(ctx, /^(N\d+ )?G10 L20\b/),
                 blockAt(ctx, /^(N\d+ )?G92\b/)].filter(x => x >= 0);
    if (!est.length) return fail(`line ${firstWork.line} moves in the work frame and nothing has established an origin`);
    const at = Math.min.apply(null, est);
    return at < firstWork.line
      ? ok(`the origin is established at line ${at}, above the first work-frame move at line ${firstWork.line}`)
      : fail(`the first work-frame move is at line ${firstWork.line}, above the origin at line ${at}`); } },

{ name:'first-motion-is-not-a-cut',
  why:'a program whose first move is a feed move is cutting its way to the start of the job',
  run: ctx => {
    const first = ctx.motions.filter(m => m.kind === 'move' || m.kind === 'machine')[0];
    if (!first) return SKIP;
    return isCut(first) ? fail(`line ${first.line} is a G${first.g} and it is the first motion in the file`)
                        : ok(`the file opens with a G${first.g === undefined ? '53' : first.g}`); } },

{ name:'feed-in-force-at-every-cut',
  why:'a G1 with no feedrate ever set runs at whatever the last program left behind',
  run: ctx => {
    const cuts = ctx.motions.filter(isCut);
    if (!cuts.length) return SKIP;
    const bare = cuts.filter(m => m.f === undefined);
    return bare.length ? fail(`${bare.length} cutting move(s) with no feedrate in force, the first at line ${bare[0].line}`)
                       : ok(`all ${cuts.length} cutting moves run at a feedrate the file has set`); } },

{ name:'spindle-running-before-the-first-cut',
  why:'a router that is not turning does not cut, it breaks',
  needs:'a milling program',
  run: ctx => {
    if (!ctx.hasMilling || ctx.hasJet) return SKIP;
    const cut = ctx.motions.filter(isCut)[0];
    if (!cut) return SKIP;
    const on = [blockAt(ctx, /^(N\d+ )?M[34]\b/)].concat(promptsAt(ctx, 'Turn ON')).filter(x => x >= 0);
    if (!on.length) return fail(`line ${cut.line} cuts and nothing in the file starts a spindle`);
    const at = Math.min.apply(null, on);
    return at < cut.line ? ok(`the spindle is started at line ${at}, above the first cut at line ${cut.line}`)
                         : fail(`the first cut is at line ${cut.line} and the spindle starts at line ${at}`); } },

{ name:'spindle-stopped-before-the-program-ends',
  why:'a file that ends with the tool turning hands the operator a live machine',
  needs:'a milling program',
  run: ctx => {
    if (!ctx.hasMilling || ctx.hasJet) return SKIP;
    const cuts = ctx.motions.filter(isCut);
    if (!cuts.length) return SKIP;
    const last = cuts[cuts.length - 1].line;
    const off = blocksAt(ctx, /^(N\d+ )?M5\b/).concat(promptsAt(ctx, 'Turn OFF spindle')).filter(x => x > last);
    return off.length ? ok(`the spindle is stopped at line ${Math.min.apply(null, off)}, after the last cut at line ${last}`)
                      : fail(`the last cut is at line ${last} and nothing stops the spindle after it`); } },

{ name:'nothing-crosses-the-part-before-the-cutter-stops',
  why:'the return traverse runs at travel speed across the work, and a cutter still turning over it is a cut nobody asked for',
  needs:'a program that parks, and a cutter this file can see stop',
  // WRITTEN BECAUSE THE SUITE MISSED IT. A mutant that parks BEFORE onClose() stops the spindle --
  // which is the defect onClose()'s own comment says the ordering exists to prevent -- passed every
  // rule in this file: the park was still the last motion and the spindle was still stopped
  // eventually, so both of the rules that look at those passed. The missing claim was the ORDER.
  run: ctx => {
    if (ctx.park === 'Off') return SKIP;
    const cuts = ctx.motions.filter(isCut);
    if (!cuts.length) return SKIP;
    const lastCut = cuts[cuts.length - 1].line;
    const stops = blocksAt(ctx, /^(N\d+ )?M5\b/).concat(promptsAt(ctx, 'Turn OFF spindle')).filter(x => x > lastCut);
    if (!stops.length) return SKIP;      // reported by the spindle rule above; not this rule's claim
    const stop = Math.min.apply(null, stops);
    // A Z RETRACT IS NOT A CROSSING and is exactly what should happen there. What must not happen is
    // the tool travelling in X/Y over the part while the cutter is still running.
    const crossed = ctx.motions.filter(m =>
      (m.kind === 'move' || m.kind === 'machine' || m.kind === 'home') &&
      m.line > lastCut && m.line < stop &&
      (m.kind === 'home' || m.xWord !== undefined || m.yWord !== undefined));
    return crossed.length
      ? fail(`line ${crossed[0].line} crosses in X/Y after the last cut at line ${lastCut} and before the cutter stops at line ${stop}`)
      : ok(`nothing moves in X/Y between the last cut (line ${lastCut}) and the stop at line ${stop}`); } },

{ name:'jet-power-is-paired',
  why:'a beam left on at the end of a file is a fire',
  needs:'a jet program',
  run: ctx => {
    if (!ctx.hasJet) return SKIP;
    const on = blocksAt(ctx, /^(N\d+ )?M[34] S\d+$/), off = blocksAt(ctx, /^(N\d+ )?M5$/);
    if (!on.length) return fail('a jet program that never fires');
    if (on.length !== off.length) return fail(`${on.length} firings and ${off.length} stops`);
    for (let i = 0; i < on.length; i++) if (off[i] < on[i]) return fail(`a stop at line ${off[i]} precedes the firing at line ${on[i]}`);
    return ok(`${on.length} firings, each closed by a stop, the last at line ${off[off.length - 1]}`); } },

{ name:'retracted-before-every-rapid-crossing',
  why:'a rapid across the bed at cutting depth is the one mistake that destroys a part and a cutter at once',
  needs:'a milling program -- a jet links with the beam off, at the cutting height, by design',
  run: ctx => {
    if (!ctx.hasMilling || ctx.hasJet) return SKIP;
    let retracted = true, lastCut = 0, crossings = 0;
    for (const m of ctx.motions) {
      if (m.kind === 'machine' && m.zWord !== undefined) { retracted = true; continue; }
      if (m.kind === 'probe' || m.kind === 'home') { retracted = false; continue; }
      if (m.kind === 'setOrigin') continue;
      if (m.kind !== 'move') continue;
      if (isCut(m)) { retracted = false; lastCut = m.line; continue; }
      // A rapid that RAISES Z is the retract itself.
      if (m.zWord !== undefined && m.from && m.to &&
          (m.from.z === undefined || m.to.z === undefined || m.to.z > m.from.z)) retracted = true;
      if (movesXY(m)) {
        if (!retracted) return fail(`line ${m.line} crosses in X/Y with no retract since the cut at line ${lastCut}`);
        crossings++;
      }
    }
    return ok(`${crossings} rapid crossings, every one of them above a retract`); } },

{ name:'nobody-reaches-into-a-turning-tool',
  why:'a prompt that asks for a tool change while the spindle is running is the injury this post exists to avoid',
  run: ctx => {
    const prompts = promptsAt(ctx, 'Change to Tool').concat(promptsAt(ctx, 'Load Tool')).sort((a,b) => a-b);
    if (!prompts.length) return SKIP;
    const stops = blocksAt(ctx, /^(N\d+ )?M5\b/).concat(promptsAt(ctx, 'Turn OFF spindle'));
    for (const at of prompts) {
      const cuts = ctx.motions.filter(isCut).filter(m => m.line < at);
      if (!cuts.length) continue;                    // nothing has run yet -- the first tool load
      const lastCut = cuts[cuts.length - 1].line;
      if (!stops.some(s => s > lastCut && s < at)) {
        return fail(`the prompt at line ${at} follows the cut at line ${lastCut} with no spindle stop between them`);
      }
    }
    return ok(`${prompts.length} tool prompt(s), each below a spindle stop`); } },

{ name:'probe-is-a-complete-sequence',
  why:'a probe that is not written into a register measured nothing, and one not retracted from drags the plate',
  run: ctx => {
    const probes = ctx.motions.filter(m => m.kind === 'probe');
    if (!probes.length) return SKIP;
    for (const p of probes) {
      if (p.zTarget === undefined) return fail(`the probe at line ${p.line} names no Z to search along`);
      if (p.zTarget >= 0) return fail(`the probe at line ${p.line} searches to Z${p.zTarget}, which is not downward`);
      const after = ctx.motions.filter(m => m.line > p.line);
      const wrote = after.filter(m => m.kind === 'setOrigin' && m.z !== undefined)[0];
      const crossed = after.filter(m => m.kind === 'move' && movesXY(m))[0];
      if (!wrote) return fail(`the probe at line ${p.line} is never written into a register`);
      if (crossed && crossed.line < wrote.line) {
        return fail(`the probe at line ${p.line} is followed by a crossing at line ${crossed.line} before its result is stored`);
      }
      const lifted = after.filter(m => (m.kind === 'move' && m.zWord !== undefined) || (m.kind === 'machine' && m.zWord !== undefined))[0];
      if (crossed && (!lifted || lifted.line > crossed.line)) {
        return fail(`the probe at line ${p.line} crosses at line ${crossed.line} before it lifts off the plate`);
      }
    }
    return ok(`${probes.length} probe(s), each stored and lifted before anything moves in X/Y`); } },

{ name:'sections-are-banners-in-the-job-order',
  why:'the file has to be readable against the Setup it came from, operation by operation',
  needs:'Comment Level at Important or above',
  run: ctx => {
    const begins = commentsAt(ctx, '*** SECTION begin ***'), ends = commentsAt(ctx, '*** SECTION end ***');
    if (!begins.length) return SKIP;
    if (begins.length !== ctx.trace.sectionCount) {
      return fail(`${begins.length} section banners for a job of ${ctx.trace.sectionCount} operations`);
    }
    if (begins.length !== ends.length) return fail(`${begins.length} section begins and ${ends.length} ends`);
    for (let i = 0; i < begins.length; i++) {
      if (ends[i] < begins[i]) return fail(`the section ending at line ${ends[i]} was never begun`);
      if (i + 1 < begins.length && begins[i + 1] < ends[i]) return fail(`the section at line ${begins[i + 1]} opens inside the one before it`);
    }
    const stop = commentAt(ctx, '*** STOP begin ***');
    if (stop >= 0 && stop < ends[ends.length - 1]) return fail(`the footer at line ${stop} opens before the last section closes`);
    return ok(`${begins.length} sections, each opened and closed, all above the footer`); } },

{ name:'operations-appear-in-the-order-the-job-asked-for',
  why:'a post that reorders operations cuts the part in an order the CAM never simulated',
  needs:'Comment Level at Info or above',
  run: ctx => {
    if (!ctx.trace.sections.length) return SKIP;
    if (!ctx.trace.sections.every(s => s.op && ctx.text.indexOf(s.op) >= 0)) return SKIP;
    let at = 0;
    for (const s of ctx.trace.sections) {
      const i = ctx.text.indexOf(s.op, at);
      if (i < 0) return fail(`operation "${s.op}" is named out of the job's order`);
      at = i + 1;
    }
    return ok(`${ctx.trace.sections.length} operations named in the kernel's own order`); } },

{ name:'the-program-ends-once-and-nothing-follows',
  why:'a block after the end code is a block the controller may or may not run',
  run: ctx => {
    const bs = M.blocks(ctx.lines);
    if (!bs.length) return SKIP;
    const last = bs[bs.length - 1];
    if (ctx.fw === 'Grbl') {
      const ends = blocksAt(ctx, /^(N\d+ )?M30\b/);
      if (ends.length !== 1) return fail(`${ends.length} M30 blocks in one file`);
      if (ends[0] !== last.i) return fail(`M30 is at line ${ends[0]} and the last block is at line ${last.i}: ${last.raw.trim()}`);
      return ok(`one M30, and it is the last block in the file (line ${last.i})`);
    }
    if (ctx.fw === 'RepRap') {
      const ends = blocksAt(ctx, /^(N\d+ )?M2$/);
      if (ends.length !== 1) return fail(`${ends.length} M2 blocks in one file`);
      if (ends[0] !== last.i) return fail(`M2 is at line ${ends[0]} and the last block is at line ${last.i}`);
      return ok(`one M2, and it is the last block in the file (line ${last.i})`);
    }
    // Marlin has neither M2 nor M30 implemented, so end of file IS the program end -- and what must
    // be last is the stepper-timeout restore, which is the only thing onClose() owes it.
    if (blocksAt(ctx, /^(N\d+ )?M(30|2)$/).length) return fail('an M2 or M30 on Marlin, which implements neither');
    return /^(N\d+ )?M84 S60$/.test(last.raw.trim())
      ? ok(`the file ends on the stepper-timeout restore (line ${last.i})`)
      : fail(`the last block on Marlin is "${last.raw.trim()}", not the M84 S60 restore`); } },

{ name:'the-last-motion-is-the-park',
  why:'the tool has to finish somewhere the operator chose, not where the last cut left it',
  needs:'At End Park At other than Off',
  run: ctx => {
    if (ctx.park === 'Off') return SKIP;
    const moves = ctx.motions.filter(m => m.kind === 'move' || m.kind === 'machine' || m.kind === 'home');
    if (!moves.length) return SKIP;
    const last = moves[moves.length - 1];
    if (ctx.park === 'Machine') {
      const okLast = (last.kind === 'machine' && M.near(last.xWord, 0) && M.near(last.yWord, 0)) ||
                     last.kind === 'home';   // Marlin reaches machine X0 Y0 by homing -- PR-21
      return okLast ? ok(`the file ends at machine X0 Y0 (line ${last.line})`)
                    : fail(`the last motion is line ${last.line}, not a park at machine X0 Y0`);
    }
    return (last.kind === 'move' && last.g === 0 && M.near(last.to.x, 0) && M.near(last.to.y, 0))
      ? ok(`the file ends with a rapid to the work origin (line ${last.line})`)
      : fail(`the last motion is line ${last.line}, not a rapid to work X0 Y0`); } },

{ name:'coolant-is-turned-off-again',
  why:'a channel left running floods the machine for as long as it is powered',
  needs:'a program that switches a coolant channel',
  run: ctx => {
    const on = blocksAt(ctx, /^(N\d+ )?M[78]\b/), off = blocksAt(ctx, /^(N\d+ )?M9\b/);
    if (!on.length) return SKIP;
    if (!off.length) return fail(`${on.length} coolant channel(s) switched on and nothing switches one off`);
    return off[off.length - 1] > on[on.length - 1]
      ? ok(`${on.length} on, ${off.length} off, and the last block of the pair is an off`)
      : fail(`the last coolant block is an on, at line ${on[on.length - 1]}`); } },

{ name:'line-numbers-only-ever-increase',
  why:'a sender that reports a line number has to be able to find it',
  needs:'Enable Line #s',
  run: ctx => {
    const numbered = M.blocks(ctx.lines).filter(b => b.n !== undefined);
    if (numbered.length < 2) return SKIP;
    for (let i = 1; i < numbered.length; i++) {
      if (numbered[i].n <= numbered[i - 1].n) {
        return fail(`line ${numbered[i].i} is N${numbered[i].n} under N${numbered[i - 1].n}`);
      }
    }
    return ok(`${numbered.length} numbered blocks, strictly increasing`); } },

{ name:'every-arc-has-a-plane-in-force',
  why:'an arc read in the wrong plane cuts a circle in the wrong two axes',
  run: ctx => {
    const arcs = ctx.motions.filter(m => m.kind === 'move' && (m.g === 2 || m.g === 3));
    if (!arcs.length) return SKIP;
    if (ctx.fw !== 'Grbl') {
      const nonXY = blocksAt(ctx, /^(N\d+ )?G1[89]\b/);
      if (nonXY.length) return fail(`G17/18/19 at line ${nonXY[0]} on a dialect where only XY arcs survive`);
      const bad = arcs.filter(a => a.k !== undefined);
      if (bad.length) return fail(`an arc with a K offset at line ${bad[0].line} off GRBL, where only XY arcs are emitted`);
      return ok(`${arcs.length} arcs, all in XY, on a dialect that has no plane code`);
    }
    const undeclared = arcs.filter(a => a.plane === undefined);
    return undeclared.length ? fail(`${undeclared.length} arcs with no plane declared, the first at line ${undeclared[0].line}`)
                             : ok(`${arcs.length} arcs, each under a declared plane`); } },

{ name:'homing-leads-the-file-when-the-job-homes',
  why:'homing after the file has established an origin throws that origin away',
  needs:'Home at Job Start on',
  run: ctx => {
    if (!ctx.homesAtStart) return SKIP;
    const homes = ctx.motions.filter(m => m.kind === 'home');
    if (!homes.length) return fail('the job is configured to home at start and nothing homes');
    const motions = ctx.motions.filter(m => m.kind === 'move' || m.kind === 'machine' || m.kind === 'home' ||
                                            m.kind === 'probe');
    return motions[0].kind === 'home'
      ? ok(`the file's first motion is the homing cycle (line ${motions[0].line})`)
      : fail(`line ${motions[0].line} moves before the homing at line ${homes[0].line}`); } },
];

// ---------------------------------------------------------------------------------------------
// The programs -- one configuration each, and every invariant that applies is run against it.
// ---------------------------------------------------------------------------------------------

const face   = 'Milling/2D/face.cnc';
const bore   = 'Milling/2D/bore.cnc';
const change = 'Milling/2D/toolchange.cnc';

const PRO = { machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'),
              machineHomeAtStart:S('Home'), machineParkAtEnd:S('Machine') };
const pro = extra => Object.assign({}, PRO, extra);
const MP  = { machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'), machineHomeAtStart:S('Home') };

const programs = [
{ id:'GS1', desc:'the shipped hobbyist file: hand-zeroed, one operation, GRBL', cnc:face, props:{} },

{ id:'GS2', desc:'the same job in the Marlin dialect, which ends without an end code', cnc:face,
  props:{ jobSelectedFirmware:S('Marlin') } },

{ id:'GS3', desc:'the professional shape: homed, a machine frame, parked at the corner', cnc:face,
  props:pro({ probeOnStart:S('Probe Z') }) },

{ id:'GS4', desc:'two tools and a manual change -- the boundary an operator puts a hand into',
  cnc:change, props:pro({ probeOnStart:S('Probe Z'), toolChangeMode:S('Pause') }) },

{ id:'GS5', desc:'... and the same boundary handed to a sender macro', cnc:change,
  props:pro({ probeOnStart:S('Probe Z'), toolChangeMode:S('Macro'), toolChangeSender:S('gSender') }) },

{ id:'GS6', desc:'... and on RepRapFirmware, where the T word IS the change', cnc:change,
  props:pro({ jobSelectedFirmware:S('RepRap'), probeOnStart:S('Probe Z'),
              toolChangeMode:S('Macro'), toolChangeSender:S('RepRap') }) },

{ id:'GS7', desc:'a thousand cutting moves with line numbers and Debug commentary', cnc:bore,
  props:{ jobSequenceNumbers:B(true), jobCommentLevel:S('Debug') } },

{ id:'GS8', desc:'two parts in one job: a traverse between fixtures in the machine frame',
  job:'two-parts.cnc', props:Object.assign({}, MP, { probeOnStart:S('Probe Z'), probeOnChange:S('Probe Z') }) },

{ id:'GS9', desc:'a laser job: seven operations, a beam instead of a spindle',
  cnc:'Cutting/Laser/center.cnc', props:{} },

{ id:'GS10', desc:'a drilled job: sixty plunges and retracts from an expanded cycle',
  cnc:'Milling/Drilling/deep drilling.cnc', props:{} },

{ id:'GS11', desc:'a Personal-licence job with the rapids restored -- group 3 rewrites the motion',
  cnc:bore, props:{ mapRapidsTestPersonalLicence:B(true), mapRapidsRestoreRapids:B(true) } },

{ id:'GS12', desc:'Comment Level Off: the structure has to survive with the commentary gone',
  cnc:face, props:pro({ jobCommentLevel:S('Off'), probeOnStart:S('Probe Z') }) },

{ id:'GS13', desc:'the professional shape on RepRapFirmware', cnc:face,
  props:pro({ jobSelectedFirmware:S('RepRap'), probeOnStart:S('Probe Z') }) },

{ id:'GS14', desc:'a mill that hands over to a laser: a spindle stops and a beam takes over',
  job:'mill-then-jet.cnc', props:Object.assign({}, MP, { probeOnStart:S('Skip'), toolChangeMode:S('Pause') }) },

{ id:'GS15', desc:'coolant on a milling job, from the channel the operator configured',
  cnc:'Milling/Coolant Codes/flood.cnc', props:{ coolantChannelAMode:S('Flood') } },

{ id:'GS16', desc:'the hobbyist file with a commanded spindle instead of an operator prompt', cnc:face,
  props:{ jobManualSpindlePowerControl:B(false), machineParkAtEnd:S('Off') } },
];

// ---- run ------------------------------------------------------------------------------
const traceCache = {};
function traceOf(jobPath) {
  if (traceCache[jobPath]) return traceCache[jobPath];
  const out = path.join(OUT, '_trace_' + path.basename(jobPath).replace(/[^\w.-]/g, '_') + '.trace');
  const r = spawnSync(POST, ['--noeditor','--nointeraction','--noheader','--noprogress', TRACE, jobPath, out],
                      { encoding:'utf8' });
  const t = fs.existsSync(out) ? M.parseTrace(fs.readFileSync(out, 'utf8'))
                               : { unit:'mm', sectionCount:0, sections:[], events:[], failed:true, status:r.status };
  traceCache[jobPath] = t;
  return t;
}

const results = [];

for (const p of programs) {
  const jobPath = p.job ? path.join(WCSJOBS, p.job) : path.join(CNCR, p.cnc);
  const gcode = path.join(OUT, `${p.id}.gcode`);
  const log   = path.join(OUT, `${p.id}.log`);
  if (fs.existsSync(gcode)) fs.unlinkSync(gcode);
  if (fs.existsSync(log)) fs.unlinkSync(log);

  const args = ['--noeditor','--nointeraction','--nobackup','--noprogress','--log',log];
  for (const [k,v] of Object.entries(p.props)) args.push('--property', k, v);
  args.push(CPS, jobPath, gcode);

  const r = spawnSync(POST, args, { encoding:'utf8' });
  const posted = r.status === 0 && fs.existsSync(gcode);
  const logText = (fs.existsSync(log) ? fs.readFileSync(log,'utf8') : '') + (r.stdout || '') + (r.stderr || '');

  const checks = [];
  if (!posted) {
    checks.push(['post', false, `post refused (exit ${r.status}) -- ${(logText.match(/Error: .*/) || ['no error line'])[0]}`]);
    results.push({ id:p.id, desc:p.desc, pass:false, checks });
    continue;
  }

  const text = fs.readFileSync(gcode, 'utf8');
  const fw = (p.props.jobSelectedFirmware || '"Grbl"').replace(/"/g, '');
  const trace = traceOf(jobPath);
  const lines = M.parseGcode(text, fw);
  const ctx = {
    id:p.id, text, log:logText, fw, lines, motions:M.simulate(lines), trace, props:p.props,
    park: (p.props.machineParkAtEnd || '"Work"').replace(/"/g, ''),
    homesAtStart: /Home/.test(p.props.machineHomeAtStart || ''),
    hasJet: trace.sections.some(s => s.jet),
    hasMilling: trace.sections.some(s => !s.jet),
  };

  // The spelling of the file is CorrectGcode's question, but a structural claim read out of a file
  // that does not parse would be read out of the wrong blocks -- so the parse is checked here too.
  const bad = M.lint(lines, fw);
  checks.push(['parses', bad.length === 0,
               bad.length ? `${bad.length} malformed block(s): ${bad.slice(0, 3).join(' ;; ')}`
                          : `${M.blocks(lines).length} blocks parse as ${fw} g-code`]);

  let applied = 0;
  for (const inv of INVARIANTS) {
    let out;
    try { out = inv.run(ctx); }
    catch (e) { out = fail(`the invariant threw: ${e.message}`); }
    if (out === SKIP) { checks.push([inv.name, true, `skipped -- needs ${inv.needs || 'something this program does not have'}`, true]); continue; }
    applied++;
    checks.push([inv.name, out[0], out[1]]);
  }

  // APPLICABILITY CANNOT EMPTY THIS FILE. A program that reaches fewer than half the invariants is
  // reporting on nothing, and that is a failure of the program rather than a pass of the post.
  const floor = Math.ceil(INVARIANTS.length / 2);
  checks.push(['coverage', applied >= floor, `${applied} of ${INVARIANTS.length} invariants apply (at least ${floor} must)`]);

  results.push({ id:p.id, desc:p.desc, pass:checks.every(c => c[1]), checks });
}

for (const r of results) {
  console.log(`${r.pass?'PASS':'FAIL'}  ${r.id}  ${r.desc}`);
  for (const c of r.checks) {
    if (!c[1] || (process.env.VERBOSE && !c[3]) || (process.env.VERBOSE === '2')) {
      console.log(`        ${c[1]?'ok ':'>> '} ${c[0]}: ${c[2]}`);
    }
  }
}
console.log(`\n${results.filter(r=>r.pass).length} / ${results.length} cases pass`);
