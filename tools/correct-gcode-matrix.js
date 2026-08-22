/**
  correct-gcode-matrix.js -- CorrectGcode: is the emitted file the job Fusion asked for, spelled in
  g-code the target firmware can parse.

  WHAT THIS CATEGORY ASKS THAT THE OTHER FOUR MATRICES DO NOT. `hobbyist`, `professional`, `wcs` and
  `personal` each ask whether one DECISION was taken correctly -- a warning present, a block ordered,
  a probe counted. Every one of them would pass on a post that took all those decisions correctly and
  then wrote the toolpath itself out at the wrong coordinates, in the wrong order, or in a spelling a
  controller answers `error:` to. Nothing in the suite reads the 1067 cutting moves of `bore.cnc`.

  So the claims here are of three kinds and no case makes more than one of them:

    AGREEMENT -- the emitted cuts ARE the cuts the kernel delivered: same count, same order, same
    endpoints to the formatter's own precision, same arc directions and centres, and a feedrate the
    post is allowed to have. The oracle is `trace.cps`, which is handed the same job by the same
    engine and records what it was asked for; `gcode-model.js` is what re-reads the g-code as g-code.

    SPELLING -- every block tokenizes, every number is inside the declared precision, comments are the
    dialect's own, no two codes from one modal group share a block, no arc lacks a centre. A defect
    here is a defect on any firmware under any property set, which is why `lint()` runs on every case
    in this file rather than being one case of its own.

    REACH -- every operation family the post supports is posted at least once, and every family it
    does not support is REFUSED rather than mis-emitted. `capabilities` claims milling and jet; the
    library ships turning, additive, multi-axis, rotated and probing jobs to hold that claim to.

  NOTHING HERE IS RECOMPUTED, in `personal-matrix.js`'s sense: no case re-derives a feedrate, a
  coordinate or an arc centre from the post's own arithmetic. Every number compared comes from the
  KERNEL, through a second post that shares the kernel configuration and nothing else.

  Run:
    node tools/correct-gcode-matrix.js <post.exe> <post.cps> "<CNC files dir>" <output dir>
  VERBOSE=1 prints the checks that passed as well as the ones that did not.
*/
const { spawnSync } = require('child_process');
const fs = require('fs'), path = require('path');
const M = require('./gcode-model.js');

const POST = process.argv[2];
const CPS  = process.argv[3];
const CNCR = process.argv[4];
const OUT  = process.argv[5];
if (!POST || !CPS || !CNCR || !OUT) {
  console.error('usage: node tools/correct-gcode-matrix.js <post.exe> <post.cps> "<CNC files dir>" <output dir>');
  process.exit(2);
}
fs.mkdirSync(OUT, { recursive: true });

const TRACE = path.join(__dirname, 'trace.cps');
const WCSJOBS = path.join(__dirname, 'wcs-jobs');

// property helpers -- the literal is built from the declared type, integration.md 6.1
const S = v => `"${v}"`;
const N = v => String(v);
const B = v => (v ? 'true' : 'false');

// ---------------------------------------------------------------------------------------------
// The three claim shapes, written once.
// ---------------------------------------------------------------------------------------------

/**
  AGREEMENT. Walk the requested cuts and the emitted cuts together.

  A REQUESTED MOVE MAY BE DROPPED, and exactly one kind may: `linearMovements()` writes no block when
  all three axis formatters return "" -- a move to where the tool already stands. That is correct and
  is why this is a walk rather than a length comparison. Any other omission, any extra block, any
  endpoint that does not match and any arc whose direction or centre differs is a failure.

  THE EMITTED SIDE IS THE AUTHORITY ON WHERE THE TOOL IS. `m.from` is the position the simulator held
  before the block, which is what a suppressed move has to equal for the suppression to be legal --
  it accounts for the post's own injected retracts and traverses without the trace having to see them.
*/
function agreeWithRequest(ctx, opts) {
  const o = opts || {};
  const req = M.requestedCuts(ctx.trace);
  const got = M.emittedCuts(ctx.motions);
  const tol = 0.0011;            // half a 3-decimal quantum, plus slack
  let gi = 0, dropped = 0;

  for (const r of req) {
    const g = got[gi];

    // Suppressed? Only where the requested endpoint IS the position the file already holds.
    const here = g ? g.from : (got.length ? undefined : ctx.lastPos);
    if (!g || !endpointMatches(g, r, tol)) {
      if (here && M.near(here.x, r.x, tol) && M.near(here.y, r.y, tol) && M.near(here.z, r.z, tol)
          && r.kind === 'L') {
        dropped++;
        continue;
      }
      return [false, g
        ? `move ${gi + 1} is ${describe(g)}, and the kernel asked for ${describeReq(r)} (line ${g.line})`
        : `the file runs out of cutting moves at request ${gi + 1}: ${describeReq(r)}`];
    }

    if (r.kind === 'C') {
      if (g.g !== r.dir) return [false, `arc at line ${g.line} is G${g.g} where the kernel asked for G${r.dir}`];
      // I/J are the centre RELATIVE TO THE START, and the reference variable omits a zero offset.
      const wantI = r.cx - g.from.x, wantJ = r.cy - g.from.y;
      const gotI = g.i === undefined ? 0 : g.i, gotJ = g.j === undefined ? 0 : g.j;
      if (!M.near(wantI, gotI, tol) || !M.near(wantJ, gotJ, tol)) {
        return [false, `arc at line ${g.line} has I${gotI} J${gotJ}, and the kernel's centre gives I${wantI.toFixed(3)} J${wantJ.toFixed(3)}`];
      }
    } else if (g.g !== 1) {
      return [false, `line ${g.line} is G${g.g} where the kernel asked for a feed move`];
    }

    if (g.f === undefined) return [false, `the cut at line ${g.line} runs with no feedrate in force`];
    if (o.exactFeed) {
      if (!M.near(g.f, r.f, 0.51)) {
        return [false, `line ${g.line} cuts at F${g.f} where the kernel asked for F${r.f} and nothing may scale it`];
      }
    } else if (g.f > r.f + 0.51) {
      return [false, `line ${g.line} cuts at F${g.f}, FASTER than the F${r.f} the kernel asked for`];
    }
    gi++;
  }

  if (gi !== got.length) {
    return [false, `${got.length - gi} cutting move(s) the kernel never asked for, from line ${got[gi].line}`];
  }
  return [true, `${gi} cutting moves match the request one for one${dropped ? `, ${dropped} zero-length move(s) correctly suppressed` : ''}`];
}

const endpointMatches = (g, r, tol) =>
  M.near(g.to.x, r.x, tol) && M.near(g.to.y, r.y, tol) && M.near(g.to.z, r.z, tol);
const describe = g => `G${g.g} to ${f3(g.to.x)},${f3(g.to.y)},${f3(g.to.z)}`;
const describeReq = r => `${r.kind === 'C' ? 'G' + r.dir : 'G1'} to ${f3(r.x)},${f3(r.y)},${f3(r.z)}`;
const f3 = v => (v === undefined ? '?' : v.toFixed(3));

/**
  AGREEMENT, rapid half. A rapid is not required to arrive as ONE block -- rapidMovements() splits
  every one into an X/Y block and a Z block -- so what is asserted is that the post arrives at each
  requested point, in the requested order.

  THE FIRST VERSION OF THIS CLAIMED MORE THAN IT COULD SEE, and the mutation run is what said so. It
  reported "1 of 6 reached as an ordered pair", meaning it believed it had witnessed rapidMovements()
  choosing cross-then-descend over retract-then-cross. It had not: the second block was one the POST
  injected, not the other half of a split. A mutant that forced the wrong order for every descending
  rapid passed all 31 cases -- because no `.cnc` file in Autodesk's library, shipped or generated,
  asks for a rapid that moves in X/Y and Z at once. That branch is unreachable here, and `checkSplit`
  below states the bound rather than pretending to test it.
*/
function rapidsArrive(ctx) {
  const req = ctx.trace.events.filter(e => e.kind === 'R');
  const got = M.emittedRapids(ctx.motions);
  const tol = 0.0011;
  let gi = 0, arrived = 0, standing = 0;

  for (const r of req) {
    // ALREADY STANDING THERE IS ASKED FIRST, and the order of these two tests is the whole
    // correctness of this walk. A rapid to where the tool already is emits nothing at all -- the
    // modal formatters return "" for every axis -- and `deep drilling.cnc` asks for one at the top of
    // every peck. Searching FIRST let one of those match an identical block sixty blocks downstream
    // and consume the whole of the second hole on the way, which is how this read 64 of 126 requests
    // as satisfied while skipping the other 62.
    const here = gi < got.length ? got[gi].from : (got.length ? got[got.length - 1].to : undefined);
    if (here && M.near(here.x, r.x, tol) && M.near(here.y, r.y, tol) && M.near(here.z, r.z, tol)) { standing++; continue; }

    let found = -1;
    for (let k = gi; k < got.length; k++) {
      const g = got[k];
      if (M.near(g.to.x, r.x, tol) && M.near(g.to.y, r.y, tol) && M.near(g.to.z, r.z, tol)) { found = k; break; }
    }
    if (found < 0) {
      return [false, `the rapid to ${f3(r.x)},${f3(r.y)},${f3(r.z)} is never reached, from emitted block ${gi + 1} of ${got.length}`];
    }
    arrived++;
    gi = found + 1;
  }
  // The blocks the walk stepped over are the post's own -- the probe traverse, the safe-Z retract,
  // the park -- plus the first half of each split. The count is reported rather than asserted: the
  // claim this case makes is that every point the kernel asked for is visited, in that order.
  return [true, `all ${req.length} requested rapids are reached in order (${arrived} as blocks, ${standing} already standing there, ${got.length - arrived} emitted blocks the post added or split)`];
}

// The split itself, which IS witnessable: no rapid block may both cross in X/Y and move Z, because
// one block cannot be ordered against itself. And the bound, measured on this job rather than
// assumed: how many diagonal rapids the kernel asked for -- where it asks for none, the ordering
// decision is not exercised and this says so instead of claiming it was.
function rapidSplit(ctx) {
  const out = [];
  const rapids = M.emittedRapids(ctx.motions);
  const mixed = rapids.filter(m => (m.xWord !== undefined || m.yWord !== undefined) && m.zWord !== undefined);
  out.push(mixed.length
    ? [false, `line ${mixed[0].line} crosses in X/Y and moves Z in one rapid block -- nothing can order that`]
    : [true, `${rapids.length} rapid blocks, none mixing an X/Y crossing with a Z move`]);

  let pos = null, diagonal = 0;
  for (const e of ctx.trace.events) {
    if (e.kind !== 'R' && e.kind !== 'L' && e.kind !== 'C') continue;
    if (e.kind === 'R' && pos) {
      const crosses = Math.abs(e.x - pos.x) > 0.001 || Math.abs(e.y - pos.y) > 0.001;
      if (crosses && Math.abs(e.z - pos.z) > 0.001) diagonal++;
    }
    pos = { x:e.x, y:e.y, z:e.z };
  }
  if (!diagonal) {
    out.push([true, 'the kernel asks for no rapid that crosses and changes Z at once, so rapidMovements() never chooses an order here -- a bound, not a pass']);
  } else {
    const bad = rapids.filter((m, i) => i > 0 && m.zWord !== undefined && m.to.z !== undefined &&
      m.from.z !== undefined && m.to.z < m.from.z &&
      rapids[i + 1] && (rapids[i + 1].xWord !== undefined || rapids[i + 1].yWord !== undefined));
    out.push(bad.length ? [false, `line ${bad[0].line} descends before the X/Y crossing that follows it`]
                        : [true, `${diagonal} diagonal rapids, each crossing before it descends`]);
  }
  return out;
}

// SPELLING. Runs on every case that produces a file -- see the header.
function spelling(ctx) {
  const bad = M.lint(ctx.lines, ctx.fw);
  return bad.length ? [false, `${bad.length} malformed block(s): ${bad.slice(0, 4).join(' ;; ')}`]
                    : [true, `all ${M.blocks(ctx.lines).length} blocks are well formed ${ctx.fw} g-code`];
}

// ---------------------------------------------------------------------------------------------
// The cases.
// ---------------------------------------------------------------------------------------------

const face   = 'Milling/2D/face.cnc';
const bore   = 'Milling/2D/bore.cnc';
const change = 'Milling/2D/toolchange.cnc';

const cases = [
// === A. the toolpath Fusion delivered is the toolpath in the file =====================
{ id:'CG1', desc:'the shipped configuration cuts what the kernel asked for, move for move',
  cnc:face, props:{ feedsScaleFeedrate:B(false) }, trace:true,
  // SCALING OFF, because that is the only setting under which the feed is the kernel's OWN number
  // and not a number the post is entitled to change. The scaled case is CG7 and it asks a weaker
  // question deliberately.
  custom:ctx => agreeWithRequest(ctx, { exactFeed:true }) },

{ id:'CG2', desc:'1072 moves and 12 arcs: every endpoint, every direction, every centre',
  cnc:bore, props:{ feedsScaleFeedrate:B(false) }, trace:true,
  // THE ARC CENTRE IS THE HALF NOTHING ELSE READS. I/J are emitted as an offset from the arc's own
  // start point, so a post that got the start point wrong writes a centre that is wrong by the same
  // amount and a file that still parses -- and cuts a different circle.
  custom:ctx => agreeWithRequest(ctx, { exactFeed:true }) },

{ id:'CG3', desc:'Use Arcs off: the same arcs arrive as chords, and every arc endpoint is still hit',
  cnc:bore, props:{ jobUseArcs:B(false), feedsScaleFeedrate:B(false) }, trace:true,
  mustNot:[[/^(N\d+ )?G[23]\b/m,'no arc survives the linearize']],
  custom:ctx => {
    const req = M.requestedCuts(ctx.trace);
    const arcs = req.filter(r => r.kind === 'C');
    const got = M.emittedCuts(ctx.motions);
    if (got.length <= req.length) return [false, `${got.length} emitted cuts for ${req.length} requested -- linearize adds moves, it cannot remove them`];
    // Every arc's ENDPOINT must still be reached: linearize() replaces the sweep, not the destination.
    let missed = 0;
    for (const a of arcs) {
      if (!got.some(g => M.near(g.to.x, a.x) && M.near(g.to.y, a.y) && M.near(g.to.z, a.z))) missed++;
    }
    return missed ? [false, `${missed} of ${arcs.length} arc endpoints are not reached by any chord`]
                  : [true, `${arcs.length} arcs became ${got.length - (req.length - arcs.length)} chords and every endpoint is still cut`]; } },

{ id:'CG4', desc:'Marlin: a different dialect, the same toolpath',
  cnc:face, props:{ jobSelectedFirmware:S('Marlin'), feedsScaleFeedrate:B(false) }, trace:true,
  custom:ctx => agreeWithRequest(ctx, { exactFeed:true }) },

{ id:'CG5', desc:'RepRapFirmware: a different dialect again, the same toolpath',
  cnc:face, props:{ jobSelectedFirmware:S('RepRap'), feedsScaleFeedrate:B(false) }, trace:true,
  custom:ctx => agreeWithRequest(ctx, { exactFeed:true }) },

{ id:'CG6', desc:'across a tool change the two sections\' cuts stay in the kernel\'s order',
  cnc:change, props:{ toolChangeMode:S('Pause'), feedsScaleFeedrate:B(false) }, trace:true,
  // THE POST INJECTS MOTION BETWEEN THE SECTIONS -- a retract, a change position, a re-probe, a
  // return -- and none of it may reach the cutting stream or reorder what follows it.
  custom:ctx => agreeWithRequest(ctx, { exactFeed:true }) },

{ id:'CG7', desc:'with scaling on the path is unmoved and only the feeds fall',
  cnc:bore, props:{ feedsScaleFeedrate:B(true), feedsMaxCutSpeedXY:N(400), feedsMaxCutSpeedZ:N(90),
                    feedsMaxCutSpeedXYZ:N(500) }, trace:true,
  // TWO CLAIMS IN ONE CASE, and they are one claim: scaling is allowed to change a feedrate and
  // nothing else. The geometry is asserted by the same walk as CG2; the feed side asserts only the
  // direction, because reproducing the projection would be the post's arithmetic checking itself.
  custom:ctx => {
    const agree = agreeWithRequest(ctx, { exactFeed:false });
    if (!agree[0]) return agree;
    const cuts = M.emittedCuts(ctx.motions);
    const over = cuts.filter(m => m.f > 500);
    if (over.length) return [false, `${over.length} cuts above the 500 toolpath cap, fastest F${Math.max(...over.map(m => m.f))}`];
    const slowed = cuts.filter((m, i) => m.f < M.requestedCuts(ctx.trace)[i].f).length;
    return slowed ? [true, `${agree[1]}; ${slowed} of ${cuts.length} feeds reduced, none raised, none over the cap`]
                  : [false, 'no feed was reduced at all -- the ceilings did nothing']; } },

{ id:'CG8', desc:'every rapid the kernel asked for is reached, and no block mixes a crossing with a Z move',
  cnc:'Milling/Drilling/deep drilling.cnc', props:{}, trace:true,
  // 125 rapids, which is the largest rapid population in the library -- a drilled job is mostly
  // positioning. bore.cnc has five and this case was written on it first; a claim about rapids wants
  // the job that has them.
  custom:ctx => [rapidsArrive(ctx)].concat(rapidSplit(ctx)) },

// === B. spelling: what a controller has to parse =====================================
// `spelling()` runs on EVERY case in this file. These four exist because each drives the writers a
// plain job never reaches -- the noisiest comment path, the two message dialects, the compact form.
{ id:'CG9', desc:'Comment Level Debug on GRBL: the noisiest path in the post is still legal g-code',
  cnc:bore, props:{ jobCommentLevel:S('Debug') },
  // Debug writes hundreds of traces, several of them built from property TEXT and from computed
  // numbers. A parenthesis or a newline reaching one of them ends the comment early and turns its
  // tail into an active block -- which is what sanitizeMessageText() exists to prevent and what
  // nothing witnessed.
  must:[[/^\(/m,'the traces are there to be checked']] },

{ id:'CG10', desc:'Marlin at Debug: semicolon comments, bare M0 messages, no parentheses anywhere',
  cnc:change, props:{ jobSelectedFirmware:S('Marlin'), jobCommentLevel:S('Debug'), toolChangeMode:S('Pause') },
  must:[[/^M0 [^(\n]+$/m,'a Marlin prompt is the message with no wrapper'],
        [/^M117 /m,'and the panel line is written']],
  mustNot:[[/\(MSG/,'no GRBL prompt form']] },

{ id:'CG11', desc:'RepRapFirmware at Debug: M291 carries a quoted message and the comments stay ";"',
  cnc:change, props:{ jobSelectedFirmware:S('RepRap'), jobCommentLevel:S('Debug'), toolChangeMode:S('Pause'),
                      toolChangeSender:S('RepRap') },
  must:[[/^M291 P"/m,'the RepRap prompt form']] },

{ id:'CG12', desc:'compact blocks and line numbers: the file is still tokenizable word by word',
  cnc:face, props:{ jobSeparateWordsWithSpace:B(false), jobSequenceNumbers:B(true),
                    jobSequenceNumberStart:N(100), jobSequenceNumberIncrement:N(2),
                    machineHomedAxes:S('XYZ'), machineHomeAtStart:S('Home') },
  // THE SPELLING CHECK IS THE POINT: with no separators a block is one run of characters, and the
  // only thing that makes it g-code rather than a string is that every letter is followed by a
  // number. lint() reads it the way a controller does.
  custom:ctx => {
    const numbered = M.blocks(ctx.lines).filter(b => b.n !== undefined);
    if (numbered.length < 10) return [false, `${numbered.length} numbered blocks -- line numbers are not on`];
    let last = null;
    for (const b of numbered) {
      if (last !== null && b.n !== last + 2) return [false, `line ${b.i}: N${b.n} follows N${last}, and the increment is 2`];
      last = b.n;
    }
    if (numbered[0].n !== 100) return [false, `the first numbered block is N${numbered[0].n}, not N100`];
    const dollar = ctx.lines.filter(l => l.dollar);
    if (!dollar.length) return [false, 'this job does not home, so the $H claim below is untested'];
    if (dollar.some(l => l.n !== undefined)) return [false, '$H carries an N word -- GRBL reads $ only as the first character'];
    return [true, `${numbered.length} blocks numbered from N100 by 2, and $H takes none`]; } },

// === C. every operation family the post supports, posted ==============================
{ id:'CG13', desc:'a drilled hole is the cycle EXPANDED, and the expansion is what the kernel gave',
  cnc:'Milling/Drilling/deep drilling.cnc', props:{ feedsScaleFeedrate:B(false) }, trace:true,
  // No supported firmware has canned cycles, so what the post owes is the expansion. The trace runs
  // expandCyclePoint() through the same kernel, so the peck sequence compared here is Fusion's own.
  mustNot:[[/^(N\d+ )?G8[123]\b/m,'no canned cycle reaches a firmware that has none'],
           [/^(N\d+ )?G7[34]\b/m,'nor a peck cycle']],
  custom:ctx => {
    const cyc = ctx.trace.events.filter(e => e.kind === 'CYCLE');
    const agree = agreeWithRequest(ctx, { exactFeed:true });
    if (!agree[0]) return agree;
    return [true, `${cyc.length} drilling cycles expanded; ${agree[1]}`]; } },

{ id:'CG14', desc:'tapping: the sync command is refused per occurrence and no G33/G84 is invented',
  cnc:'Milling/Drilling/tapping.cnc', props:{},
  must:[[/Speed-feed synchronization for rigid tapping is not supported/,'the warning the kernel\'s command earns']],
  mustNot:[[/^(N\d+ )?G33\b/m,'no spindle-synchronized feed'],[/^(N\d+ )?G8[47]\b/m,'no tapping cycle']],
  custom:ctx => {
    // ONE PER OCCURRENCE, because that is what the post promises: every affected move is flagged.
    const cmds = ctx.trace.events.filter(e => e.kind === 'CMD' && /SPEED_FEED_SYNCHRONIZATION/.test(e.id));
    const warned = M.countOf(ctx.text, /Speed-feed synchronization for rigid tapping/g);
    return warned === cmds.length
      ? [true, `${cmds.length} synchronization commands, ${warned} warnings`]
      : [false, `${cmds.length} synchronization commands and ${warned} warnings`]; },
  trace:true },

{ id:'CG15', desc:'a tap reverses the spindle, and a manual spindle is ASKED to reverse',
  cnc:'Milling/Drilling/left tapping.cnc', props:{},
  // Left tapping runs the spindle counterclockwise, which in the prompt mode is the one
  // path that names a direction in a prompt at all.
  must:[[/M0 \(MSG,[^)]*counterclockwise[^)]*\)/,'the operator is told which way to run it']],
  mustNot:[[/^(N\d+ )?M4\b/m,'nothing commands a spindle the operator owns']] },

{ id:'CG16', desc:'a command the switch does not name reaches HR-13\'s warning, once per occurrence',
  cnc:'Milling/Drilling/fine boring.cnc', props:{}, trace:true,
  // COMMAND_ORIENTATE_SPINDLE. integration.md 7.6 records the fall-through as reached by NOTHING in
  // the suite and needing a Fusion-authored job; it is in Autodesk's own library, in four of the
  // drilling files. This is the case that makes a regression there loud instead of silent.
  must:[[/command COMMAND_ORIENTATE_SPINDLE is not supported by this post and was not emitted/,
         'the fall-through names the command it dropped']],
  custom:ctx => {
    const raised = ctx.trace.events.filter(e => e.kind === 'CMD' && e.id === 'COMMAND_ORIENTATE_SPINDLE').length;
    const said = M.countOf(ctx.text, /command COMMAND_ORIENTATE_SPINDLE is not supported/g);
    return said === raised ? [true, `${raised} orientate commands, ${said} warnings -- HR-13's rule, witnessed`]
                           : [false, `${raised} orientate commands and ${said} warnings`]; } },

{ id:'CG17', desc:'a mid-operation speed change reaches the operator, and none is invented',
  cnc:'Milling/Drilling/break through.cnc', props:{}, trace:true,
  // onSpindleSpeed() four times inside one section, alternating between two speeds. THE COUNT IS NOT
  // THE CLAIM and the first version of this case had it wrong: a speed that RETURNS to an earlier
  // value is still a change the operator has to make, so "one prompt per distinct speed" fails a
  // correct post. What is asserted instead is the property -- every requested speed is named, no
  // speed nobody asked for is named, and no prompt asks for the speed the machine is already at.
  custom:ctx => {
    const asked = ctx.trace.events.filter(e => e.kind === 'SPEED').map(e => Math.round(e.rpm));
    if (!asked.length) return [false, 'this job asks for no speed change'];
    const prompts = [];
    const re = /MSG,(?:Turn ON (\d+) RPM|Set spindle to (\d+) RPM)/g;
    let m; while ((m = re.exec(ctx.text))) prompts.push(Number(m[1] || m[2]));

    const missing = asked.filter(s => prompts.indexOf(s) < 0);
    if (missing.length) return [false, `speeds the kernel asked for and nothing prompted: ${missing.join(', ')}`];

    // The opening prompt is the section's own tool speed, which is a request in its own right.
    const allowed = asked.concat(ctx.trace.sections.map(s => Math.round(s.rpm)));
    const invented = prompts.filter(s => allowed.indexOf(s) < 0);
    if (invented.length) return [false, `prompted speeds nobody asked for: ${invented.join(', ')}`];

    for (let i = 1; i < prompts.length; i++) {
      if (prompts[i] === prompts[i - 1]) return [false, `two prompts in a row for ${prompts[i]} RPM`];
    }
    return [true, `${asked.length} speed changes, ${prompts.length} prompts, none missing, none invented, none repeated`]; } },

{ id:'CG18', desc:'a stop-boring cycle stops the spindle mid-section and starts it again',
  cnc:'Milling/Drilling/stop boring.cnc', props:{}, trace:true,
  must:[[/MSG,Turn OFF spindle/,'the stop reaches the operator'],
        [/MSG,Turn ON \d+ RPM/,'and so does the restart']],
  custom:ctx => {
    const stops = ctx.trace.events.filter(e => e.kind === 'CMD' && e.id === 'COMMAND_STOP_SPINDLE').length;
    const emitted = M.countOf(ctx.text, /MSG,Turn OFF spindle/g);
    // The end-of-job stop is one more than the cycle asked for, and it belongs to onClose().
    return emitted === stops + 1
      ? [true, `${stops} in-cycle spindle stops plus the one at the end of the job`]
      : [false, `${stops} in-cycle stops and ${emitted} stop prompts, expected ${stops + 1}`]; } },

{ id:'CG19', desc:'a helical cycle is linearized: no arc in the file changes Z',
  cnc:'Milling/Drilling/circular mill.cnc', props:{ feedsScaleFeedrate:B(false) }, trace:true,
  // allowHelicalMoves = false, so the kernel owes the post planar arcs and linear ramps. An arc
  // block carrying a Z word would be a helix a controller here cannot run.
  custom:ctx => {
    const arcs = M.emittedCuts(ctx.motions).filter(m => m.g === 2 || m.g === 3);
    if (!arcs.length) return [false, 'this job emitted no arcs at all'];
    const helical = arcs.filter(a => a.zWord !== undefined && !M.near(a.from.z, a.to.z));
    return helical.length ? [false, `${helical.length} arcs change Z -- the first at line ${helical[0].line}`]
                          : [true, `${arcs.length} arcs, every one planar`]; } },

{ id:'CG20', desc:'a laser job: the power the mode maps to, on every firing, and nothing else',
  cnc:'Cutting/Laser/center.cnc', props:{}, trace:true,
  // Six Through sections and one Etch, so the two power levels are in one file and each firing must
  // take its own section's. GRBL scales percent by ten.
  must:[[/^M4 S800$/m,'Through fires at 80% -> S800'],[/^M4 S400$/m,'Etch fires at 40% -> S400']],
  custom:ctx => {
    const on = ctx.trace.events.filter(e => e.kind === 'POWER' && e.on).length;
    const off = ctx.trace.events.filter(e => e.kind === 'POWER' && !e.on).length;
    const fired = M.countOf(ctx.text, /^M4 S\d+$/gm), stopped = M.countOf(ctx.text, /^M5$/gm);
    return (fired === on && stopped === off)
      ? [true, `${on} power-on requests and ${fired} firings, ${off} power-off requests and ${stopped} M5`]
      : [false, `on=${on}/fired=${fired}, off=${off}/M5=${stopped}`]; } },

{ id:'CG21', desc:'a plasma job posts on the same jet path',
  cnc:'Cutting/Plasma/center.cnc', props:{},
  must:[[/^M4 S\d+$/m,'the torch fires'],[/^M5$/m,'and stops']],
  mustNot:[[/MSG,Turn ON \d+ RPM/,'no spindle prompt for a tool that has no spindle']] },

{ id:'CG22', desc:'a waterjet job posts on the same jet path',
  cnc:'Cutting/Waterjet/center compensation/through medium.cnc', props:{},
  must:[[/^M4 S\d+$/m,'the jet fires']] },

// GH-16a. The Marlin fan mode addresses a fan INDEX, and until this landed it addressed none: a bare
// M106 is fan `_MIN(motion.extruder, FAN_COUNT-1)` on Marlin, which is fan 0 on a CNC build -- so a
// laser on any other output was driven by nothing and fan 0 was driven by the laser.
{ id:'CG22a', desc:'Marlin fan mode: both power levels reach the fan the operator named, and no M107 is emitted',
  cnc:'Cutting/Laser/center.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), laserMarlinMode:S('M106'), laserMarlinPinFan:N(2) },
  // Six Through sections and one Etch in this one file, so both power levels are proved here for the
  // same reason CG20 uses it: 80% -> 204 and 40% -> 102 on Marlin's 0-255 scale.
  must:[[/^M106 P2 S204$/m,'Through fires on fan 2 at 80% -> S204'],
        [/^M106 P2 S102$/m,'Etch fires on the same fan at 40% -> S102'],
        [/^M106 P2 S0$/m,'and the off code is S0 on that fan, not a bare M107']],
  // M107 is gone from the post, not merely unused here: RRF ignores its P and zeroes the current
  // tool's mapped fans, so an on addressing fan 2 with that off is worse than either alone.
  mustNot:[[/^(N\d+ )?M107\b/m,'no M107 anywhere in the file']],
  // BOTH HALVES, because a P on the on-code and not the off-code would light fan 2 and try to stop
  // fan 0 -- which is the shape of the defect, and asserting only the firing would pass on it.
  custom:ctx => {
    const on = M.countOf(ctx.text, /^M106 P2 S(?!0$)\d+$/gm), off = M.countOf(ctx.text, /^M106 P2 S0$/gm);
    return (on > 0 && on === off) ? [true, `${on} firings on fan 2 and ${off} matching stops`]
                                  : [false, `${on} firings and ${off} stops on fan 2`]; } },

{ id:'CG22b', desc:'... and the index is emitted even at its default of 0, rather than left implicit',
  cnc:'Cutting/Laser/center.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), laserMarlinMode:S('M106') },
  // The control for CG22a: P0 is what a bare M106 already means on a single-extruder Marlin build, so
  // this case is about the post SAYING which output it drives. RRF resolves an absent P differently --
  // a bare M106 P{n} there is a status report and switches nothing -- which is why it is never omitted.
  must:[[/^M106 P0 S204$/m,'the default names fan 0 explicitly']],
  mustNot:[[/^(N\d+ )?M106 S\d+$/m,'and never emits the indexless form']] },

{ id:'CG22c', desc:'Marlin pin mode takes the same field, and pairs its firing with S0 on that pin',
  cnc:'Cutting/Laser/center.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), laserMarlinMode:S('M42'), laserMarlinPinFan:N(7) },
  must:[[/^M42 P7 S204$/m,'Through fires on pin 7'],
        [/^M42 P7 S0$/m,'and is stopped on the same pin']],
  mustNot:[[/^(N\d+ )?M106\b/m,'no fan code in pin mode']] },

// GH-16a. The other side of CG22c, and the reason the merged Pin/Fan # field can default to 0 at all:
// 0 is a legitimate FAN index and no laser's pin, so pin mode must say what it drives or not post.
{ id:'CG22d', desc:'pin mode with the Pin/Fan # left at 0 is refused rather than aimed at pin 0',
  cnc:'Cutting/Laser/center.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), laserMarlinMode:S('M42') },
  refuse:[/is still 0, which names no output this post can believe you chose/,'the field is named, with both remedies'] },

// The control for the guard above, and for the firmware scoping under it: the Marlin/Reprap mode ships
// "106" and GRBL ships as the firmware, so a guard that read the property on the wrong firmware would
// refuse every default job in this file. Thirty-odd GRBL cases here are that control; this one states it.
{ id:'CG22e', desc:'... and a GRBL job posts untouched by it -- the Marlin/Reprap mode is not read there',
  cnc:'Cutting/Laser/center.cnc', props:{ laserMarlinMode:S('M42') },
  must:[[/^M4 S800$/m,'the GRBL mode fires the laser and the Marlin pin mode is ignored']],
  mustNot:[[/^(N\d+ )?M42\b/m,'no M42 on a firmware that has none']] },

{ id:'CG23', desc:'an Optional Stop becomes an unconditional M0, once per request, and says so',
  cnc:'Milling/2D/optional stop.cnc', props:{ toolChangeMode:S('Pause') }, trace:true,
  must:[[/an Optional Stop was requested here and is emitted as an UNCONDITIONAL M0/,'the substitution is stated']],
  mustNot:[[/^(N\d+ )?M1$/m,'no M1 -- all three firmwares parse it and mean three different things']],
  custom:ctx => {
    const asked = ctx.trace.events.filter(e => e.kind === 'CMD' && e.id === 'COMMAND_OPTIONAL_STOP').length;
    const said = M.countOf(ctx.text, /an Optional Stop was requested here/g);
    return said === asked ? [true, `${asked} optional stops, ${said} statements`]
                          : [false, `${asked} optional stops and ${said} statements`]; } },

{ id:'CG24', desc:'a job whose tool asks for flood coolant switches a channel that carries it',
  cnc:'Milling/Coolant Codes/flood.cnc', props:{ coolantChannelAMode:S('Flood') },
  must:[[/^M8$/m,'the channel is switched on'],[/^M9$/m,'and off again']],
  custom:ctx => {
    const on = M.countOf(ctx.text, /^M8$/gm), off = M.countOf(ctx.text, /^M9$/gm);
    return on === off ? [true, `${on} coolant on, ${off} off -- paired`] : [false, `${on} on against ${off} off`]; } },

// GH-16d. The Marlin values name the output now instead of freezing it at pin 6 or 11 -- which were the
// RAMPS servo header, and are HEATER_2 and Y_MIN on a Rambo, both refused there as protected pins.
{ id:'CG24a', desc:'coolant on a fan: the channel switches the fan the operator named, and closes it',
  cnc:'Milling/Coolant Codes/flood.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), coolantChannelAMode:S('Flood'),
          coolantChannelAOn:S('M106'), coolantChannelAPinFan:N(2) },
  must:[[/^M106 P2 S255$/m,'on'],[/^M106 P2 S0$/m,'and off, on the same fan - one field chose both']],
  mustNot:[[/^(N\d+ )?M[789]\b/m,'no GRBL coolant code on a Marlin job']],
  custom:ctx => {
    const on = M.countOf(ctx.text, /^M106 P2 S255$/gm), off = M.countOf(ctx.text, /^M106 P2 S0$/gm);
    return on === off ? [true, `${on} coolant on, ${off} off -- paired`] : [false, `${on} on against ${off} off`]; } },

{ id:'CG24b', desc:'... and on a pin, from the same field',
  cnc:'Milling/Coolant Codes/flood.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), coolantChannelAMode:S('Flood'),
          coolantChannelAOn:S('M42'), coolantChannelAPinFan:N(6) },
  must:[[/^M42 P6 S255$/m,'on'],[/^M42 P6 S0$/m,'and off, on the pin named']],
  mustNot:[[/^(N\d+ )?M106\b/m,'no fan code when the pin form is chosen']] },

{ id:'CG24c', desc:'... and the pin form with the number left at 0 is refused',
  cnc:'Milling/Coolant Codes/flood.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), coolantChannelAMode:S('Flood'),
          coolantChannelAOn:S('M42') },
  refuse:[/is still 0, which names no output this post can believe you chose/,'the guard reaches group 9 too'] },

// PC-3. The refusal that stood here - a channel opened with one form and closed with another - has no
// state left to fire on: one field per channel, and coolantOffCode() derives the off code from it. What
// replaces it is the derivation itself on the one on-value nothing else in the suite posts. M7 must
// close with M9 and NOT with M7: GRBL's mist code is not its own off code, and it is the arm of
// coolantOffCode() that returns something other than what it was handed.
{ id:'CG24d', desc:'... and the off code is derived: M7 closes with M9, which is not the code it opened with',
  cnc:'Milling/Coolant Codes/flood.cnc',
  props:{ coolantChannelAMode:S('Flood'), coolantChannelAOn:S('M7') },
  must:[[/^M7$/m,'the channel opens on the mist code the operator chose']],
  mustNot:[[/^(N\d+ )?M8$/m,'nothing emits the flood code - channel B is Off and A is on M7']],
  custom:ctx => {
    const on = M.countOf(ctx.text, /^M7$/gm), off = M.countOf(ctx.text, /^M9$/gm);
    return on === off && on > 0 ? [true, `${on} M7 on, ${off} M9 off -- paired, from one field`]
                                : [false, `${on} M7 against ${off} M9`]; } },

// Both channels on ONE level, the only way a shipped job reaches the two-channel path. The claim is the
// ORDER: setCoolant() takes both channels off before switching either on, which is what makes GRBL's
// M9 -- one code that stops every output at once -- harmless here.
{ id:'CG24e', desc:'two GRBL channels on one level: every off follows every on, which is what makes M9 safe',
  cnc:'Milling/Coolant Codes/flood.cnc',
  props:{ coolantChannelAMode:S('Flood'), coolantChannelBMode:S('Flood') },
  must:[[/^M8$/m,'channel A switches on'],[/^M7$/m,'and channel B with it']],
  custom:ctx => {
    const at = re => ctx.lines.filter(l => re.test(l.raw)).map(l => l.i);
    const ons = at(/^M[78]$/), offs = at(/^M9$/);
    if (ons.length !== 2) return [false, `${ons.length} ons, expected one per channel`];
    if (!offs.length) return [false, 'nothing switches either channel off'];
    return offs[offs.length - 1] > ons[ons.length - 1]
      ? [true, `${ons.length} on then ${offs.length} off, the last block being an off`]
      : [false, `an on at line ${ons[ons.length - 1]} follows the last off`]; } },

{ id:'CG24f', desc:'... and two channels may share one output, because the offs come first',
  cnc:'Milling/Coolant Codes/flood.cnc',
  props:{ jobSelectedFirmware:S('Marlin'), coolantChannelAMode:S('Flood'), coolantChannelBMode:S('Flood'),
          coolantChannelAOn:S('M42'), coolantChannelAPinFan:N(6),
          coolantChannelBOn:S('M42'), coolantChannelBPinFan:N(6) },
  must:[[/^M42 P6 S255$/m,'the shared output is switched on']],
  custom:ctx => {
    const at = re => ctx.lines.filter(l => re.test(l.raw)).map(l => l.i);
    const ons = at(/^M42 P6 S255$/), offs = at(/^M42 P6 S0$/);
    if (!ons.length || !offs.length) return [false, `${ons.length} on, ${offs.length} off`];
    return offs[offs.length - 1] > ons[ons.length - 1]
      ? [true, `${ons.length} on and ${offs.length} off on one output, ending off`]
      : [false, 'the shared output is left on']; } },

// === D. what the post does not support is REFUSED, not mis-emitted ====================
{ id:'CG25', desc:'a simultaneous 5-axis toolpath is refused at the section, not linearized',
  cnc:'Milling/5x Simultaneous/5x contour.cnc', props:{},
  refuse:[/Multi-axis toolpath is not supported/,'named, with what to use instead'] },

// HR-6 (B) -- THE ONE LIVE RISK IN THE REGISTER, and it takes six cases because one would not settle
// it. `plan.md` calls the orientation guard a possible no-op on exactly the case it exists to catch,
// and the failure mode is a part cut in the wrong plane, silently. The library ships five rotated
// Setups and one file that holds all five; `trace.cps` records each section's forward vector, so what
// is refused below is known to be off-axis rather than assumed to be. THE CONTROL IS EVERY OTHER CASE
// IN THIS FILE: thirty upright posts, so the guard is not simply refusing everything.
{ id:'CG26', desc:'a Setup rotated 30 deg about A is refused -- HR-6 (B), forward (0, 0.5, 0.866)',
  cnc:'Milling/3+2/a30.cnc', props:{},
  refuse:[/Tool orientation is not supported/,'the guard fires on a genuinely rotated Setup'] },

{ id:'CG26b', desc:'... and -30 about A, forward (0, -0.5, 0.866)',
  cnc:'Milling/3+2/a-30.cnc', props:{},
  refuse:[/Tool orientation is not supported/,'the sign of the tilt does not matter to the guard'] },

{ id:'CG26c', desc:'... and 30 about B, forward (-0.5, 0, 0.866) -- the axis the A cases leave untested',
  cnc:'Milling/3+2/b30.cnc', props:{},
  refuse:[/Tool orientation is not supported/,'X is read as well as Y'] },

{ id:'CG26d', desc:'... and -30 about B, forward (0.5, 0, 0.866)',
  cnc:'Milling/3+2/b-30.cnc', props:{},
  refuse:[/Tool orientation is not supported/,'both signs on that axis too'] },

{ id:'CG26e', desc:'... and a compound C-45 B22 Setup, forward (0.267, -0.267, 0.926)',
  cnc:'Milling/3+2/c-45b22.cnc', props:{},
  // THE SHALLOWEST TILT AVAILABLE -- 22 degrees, and both X and Y non-zero at once. If the guard read
  // one axis, or tested a threshold rather than 1e-4, this is the file it would let through.
  refuse:[/Tool orientation is not supported/,'a compound rotation is refused like any other'] },

{ id:'CG26f', desc:'... and a job of five rotated Setups refuses at the FIRST, leaving no .gcode at all',
  cnc:'Milling/3+2/all.cnc', props:{},
  // The refusal has to arrive before anything is written, not part way down a file the operator could
  // still load -- PR-2c's rule, met on the job that has five chances to break it.
  refuse:[/Tool orientation is not supported/,'refused at the first section, and no runnable file survives'] },

{ id:'CG27', desc:'an F360 WCS probing operation is refused, naming the two things that do work',
  cnc:'Probing/WCS/PWCS Rectangle block.cnc', props:{},
  refuse:[/WCS probing is not supported/,'refused rather than expanded into G0/G1 with no G38'] },

{ id:'CG28', desc:'compensation in the control is refused on the operation that asks for it',
  cnc:'Milling/2D/compensation.cnc', props:{},
  refuse:[/Cutter radius compensation in the control is not supported/,'named, with the Fusion setting that fixes it'] },

{ id:'CG29', desc:'a turning job is refused by the capability the post declares',
  cnc:'Turning/face.cnc', props:{},
  // The engine refuses this one, off `capabilities = CAPABILITY_MILLING | CAPABILITY_JET` -- so what
  // this case holds is the DECLARATION, which is the post's own line and the only thing standing
  // between a lathe program and a router.
  refuse:[/Turning toolpath is not supported by the post configuration/,'the declaration is what refuses it'] },

{ id:'CG30', desc:'an additive job is refused the same way',
  cnc:'Additive/additive.cnc', props:{},
  refuse:[/Additive toolpath is not supported by the post configuration/,'the same declaration'] },

// === E. the multi-part half, on the files built for it =================================
{ id:'CG31', desc:'a second part\'s cuts are the kernel\'s too, across a work-offset change',
  job:'two-parts.cnc',
  props:{ machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'), machineHomeAtStart:S('Home'),
          probeOnStart:S('Skip'), probeOnChange:S('Skip'), feedsScaleFeedrate:B(false) }, trace:true,
  // The traverse between parts is machine-frame motion the simulator deliberately cannot value, so
  // this case is the proof that the CUTS either side of it are still matched one for one.
  custom:ctx => agreeWithRequest(ctx, { exactFeed:true }) },

// === F. one property, one file -- the five residues that needed a case and no artifact ===
// `integration.md` 7.1 listed these as reachable with job files already on disk and unwritten. Each
// is a property that changes WHAT THE FILE SAYS rather than what the job is, which is this category's
// own question, so they are cases here rather than a sixth persona somewhere else.
{ id:'CG32', desc:'Spindle Control M3/M5: the commanded codes REPLACE the two operator prompts',
  cnc:face, props:{ jobSpindleControl:S('M3') },
  must:[[/^M3 S5000$/m,'the spindle is commanded, at the speed the tool asks for'],
        [/^M5$/m,'and stopped the same way']],
  mustNot:[[/MSG,Turn ON \d+ RPM/,'no prompt to start it by hand'],
           [/MSG,Turn OFF spindle/,'and none to stop it']],
  // BOTH HALVES, because the property is a swap and not an addition: asserting only the M3 would pass
  // on a post that emitted the command AND still stopped to ask.
  custom:ctx => {
    const on = M.countOf(ctx.text, /^M3 S\d+$/gm), off = M.countOf(ctx.text, /^M5$/gm);
    return (on === 1 && off === 1) ? [true, 'one M3 and one M5 for a one-operation job']
                                   : [false, `${on} M3 and ${off} M5, expected one of each`]; } },

// GH-16b. Issue 16's other half: one switched output carries the router and vac, and until this landed
// the only thing the post could do about it was ask the operator to reach for a switch.
{ id:'CG32a', desc:'Spindle Control Fan: M106 switches the router, once on and once off, with no prompt',
  cnc:face, props:{ jobSelectedFirmware:S('Marlin'), jobSpindleControl:S('M106') },
  must:[[/^M106 P0 S255$/m,'the output is switched on, S255 being the full-on flag'],
        [/^M106 P0 S0$/m,'and off on the same output'],
        [/>>> Spindle ON -- 5000 RPM requested, and this output carries no speed/,
         'and the RPM is stated in a comment rather than commanded']],
  // A switched output has no speed and no direction. The last of these is the one that matters: the
  // tool asks for 5000 RPM and M106 clamps S to 255, so an RPM reaching S would be "full on" wearing
  // a number that means nothing.
  mustNot:[[/MSG,Turn ON \d+ RPM/,'no prompt to start it by hand'],
           [/MSG,Turn OFF spindle/,'and none to stop it'],
           [/^(N\d+ )?M[345]\b/m,'no M3, M4 or M5 -- this mode replaces them'],
           [/^(N\d+ )?M106 P0 S5000$/m,'and the tool RPM never reaches S']],
  // BOTH HALVES, for the reason CG32 states: asserting only the on-code would pass on a post that
  // switched the output and then stopped to ask as well.
  custom:ctx => {
    const on = M.countOf(ctx.text, /^M106 P0 S255$/gm), off = M.countOf(ctx.text, /^M106 P0 S0$/gm);
    return (on === 1 && off === 1) ? [true, 'one on and one off for a one-operation job']
                                   : [false, `${on} on and ${off} off, expected one of each`]; } },

{ id:'CG32b', desc:'... and Pin mode does it with M42 on the pin named, S255 and S0',
  cnc:face, props:{ jobSelectedFirmware:S('Marlin'), jobSpindleControl:S('M42'), jobSpindlePinFan:N(11) },
  must:[[/^M42 P11 S255$/m,'on'],[/^M42 P11 S0$/m,'and off, on the pin the operator named']],
  mustNot:[[/^(N\d+ )?M106\b/m,'no fan code in pin mode'],
           [/^(N\d+ )?M[345]\b/m,'and no spindle code either']] },

{ id:'CG32c', desc:'... and a fan-mode job posted for GRBL is refused, not handed an M106 GRBL cannot answer',
  cnc:face, props:{ jobSpindleControl:S('M106') },
  refuse:[/is set to a fan \(M106\) output and this job is posted for GRBL/,'the mode, the code and the firmware are all named'] },

{ id:'CG32d', desc:'... and pin mode with the Pin/Fan # left at 0 is refused on the spindle side too',
  cnc:face, props:{ jobSelectedFirmware:S('Marlin'), jobSpindleControl:S('M42') },
  refuse:[/is still 0, which names no output this post can believe you chose/,'the same guard, reached through group 1'] },

// The other branch of CG32a's condition, and CG17's job is the one that reaches it: onSpindleSpeed()
// four times inside one section. A switched output cannot answer a speed change, and the failure to
// guard against would be four more M106 P0 S255 lines that change nothing -- or, worse, silence.
{ id:'CG32e', desc:'... and a mid-operation speed change on a switched output is stated, not re-emitted',
  cnc:'Milling/Drilling/break through.cnc', props:{ jobSelectedFirmware:S('Marlin'), jobSpindleControl:S('M106') },
  must:[[/RPM requested and NOT commanded -- this output is on\/off only/,'the file says the change cannot be served']],
  custom:ctx => {
    const on = M.countOf(ctx.text, /^M106 P0 S255$/gm), off = M.countOf(ctx.text, /^M106 P0 S0$/gm);
    const stated = M.countOf(ctx.text, /RPM requested and NOT commanded/gm);
    // The count of statements is not asserted against what the kernel asked for -- a section start
    // reaches the same function -- but ONE on and ONE off is: the output is switched at the ends of
    // the job and nowhere in between, whatever the toolpath asks for in the middle.
    return (on === 1 && off === 1 && stated > 0)
      ? [true, `${on} on, ${off} off, ${stated} speed changes stated and none emitted`]
      : [false, `on=${on} off=${off} stated=${stated}`]; } },

{ id:'CG33', desc:'Pause, then Home: the stop comes BEFORE the homing cycle, not after it',
  cnc:face, props:{ machineHomedAxes:S('XYZ'), machineHomeAtStart:S('Pause & Home'), probeOnStart:S('Skip') },
  must:[[/^\$H$/m,'the job still homes']],
  // ORDER IS THE WHOLE PROPERTY. A stop after the homing cycle prepares the machine for a cycle that
  // has already run, which is the failure this value exists to prevent.
  custom:ctx => {
    const stop = ctx.text.search(/^M0 \(MSG,[^)]*\)$/m), home = ctx.text.search(/^\$H$/m);
    if (stop < 0) return [false, 'no stop at all before the homing cycle'];
    return stop < home ? [true, 'the operator is stopped, and the homing cycle follows']
                       : [false, `the stop is at ${stop} and the homing at ${home}`]; } },

{ id:'CG34', desc:'Probe Pause Before: the plate is fitted and never asked for back',
  cnc:face, props:{ probePause:S('Before') },
  must:[[/MSG,Attach ZProbe/,'the fit prompt survives'],[/^G38\.2 /m,'and the probe runs']],
  mustNot:[[/Detach ZProbe/,'and nothing asks for it to be removed']] },

{ id:'CG35', desc:'Probe with G38.2 off on Marlin: G28 Z takes its place',
  cnc:face, props:{ jobSelectedFirmware:S('Marlin'), probeG382orG28:B(false) },
  // MARLIN AND NOT GRBL, and the property's own description is why: the GRBL arm emits G38.2
  // unconditionally, so a GRBL case would assert that nothing changed and call it coverage.
  must:[[/^G28 Z$/m,'the alternative probe command']],
  mustNot:[[/^G38\.2/m,'and no G38.2 anywhere in the file']] },

{ id:'CG36', desc:'the Duet mode tokens reach the file, and the laser one only at the section that needs it',
  job:'mill-then-jet.cnc',
  props:{ jobSelectedFirmware:S('RepRap'), machineHomedAxes:S('XYZ'), machineTravelZ:S('-5'),
          probeOnStart:S('Skip'), toolChangeMode:S('Pause'),
          duetMillingMode:S('M453 P7'), duetLaserMode:S('M452 R99 F123') },
  // ONE JOB REACHES BOTH, because the tokens are written at a section-type CHANGE: a milling section
  // followed by a jet section is the only shape that emits the pair, and it is on disk already.
  must:[[/^M453 P7$/m,'the milling mode is written verbatim, from the field'],
        [/^M452 R99 F123$/m,'and the laser mode when the section type changes']],
  custom:ctx => {
    const mill = ctx.text.search(/^M453 P7$/m), laser = ctx.text.search(/^M452 R99 F123$/m);
    return mill < laser ? [true, 'milling mode first, laser mode at the change into the jet tool']
                        : [false, `the laser mode at ${laser} precedes the milling mode at ${mill}`]; } },
];

// ---- run ------------------------------------------------------------------------------
// One trace per job file, not per case: the request depends on the job and the kernel configuration,
// and on nothing a property can change.
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

for (const c of cases) {
  const jobPath = c.job ? path.join(WCSJOBS, c.job) : path.join(CNCR, c.cnc);
  const gcode = path.join(OUT, `${c.id}.gcode`);
  const log   = path.join(OUT, `${c.id}.log`);
  if (fs.existsSync(gcode)) fs.unlinkSync(gcode);
  if (fs.existsSync(log)) fs.unlinkSync(log);

  const args = ['--noeditor','--nointeraction','--nobackup','--noprogress','--log',log];
  for (const [k,v] of Object.entries(c.props)) args.push('--property', k, v);
  args.push(CPS, jobPath, gcode);

  const r = spawnSync(POST, args, { encoding:'utf8' });
  const posted = r.status === 0 && fs.existsSync(gcode);
  const text = posted ? fs.readFileSync(gcode,'utf8') : '';
  const logText = (fs.existsSync(log) ? fs.readFileSync(log,'utf8') : '') + (r.stdout || '') + (r.stderr || '');

  const checks = [];
  if (c.refuse) {
    checks.push([!posted, `refuse: no file is produced (exit ${r.status})`]);
    checks.push([c.refuse[0].test(logText), `refuse: ${c.refuse[1]}`]);
  } else if (!posted) {
    checks.push([false, `post refused (exit ${r.status}) -- ${(logText.match(/Error: .*/) || ['no error line'])[0]}`]);
  } else {
    const fw = (c.props.jobSelectedFirmware || '"Grbl"').replace(/"/g, '');
    const lines = M.parseGcode(text, fw);
    const motions = M.simulate(lines);
    const ctx = { id:c.id, text, log:logText, fw, lines, motions, trace:null };

    for (const [re,what] of (c.must||[]))       checks.push([re.test(text),      `must: ${what}`]);
    for (const [re,what] of (c.mustNot||[]))    checks.push([!re.test(text),     `must not: ${what}`]);
    for (const [re,what] of (c.mustLog||[]))    checks.push([re.test(logText),   `must warn: ${what}`]);
    for (const [re,what] of (c.mustNotLog||[])) checks.push([!re.test(logText),  `must not warn: ${what}`]);

    // Spelling is not a case, it is a standing claim about every file this suite produces.
    checks.push(spelling(ctx));

    if (c.custom) {
      if (c.trace) {
        ctx.trace = traceOf(jobPath);
        if (ctx.trace.failed) checks.push([false, `the trace run refused (exit ${ctx.trace.status}) -- no oracle`]);
      }
      const out = c.custom(ctx);
      if (Array.isArray(out) && Array.isArray(out[0])) for (const o of out) checks.push(o);
      else checks.push(out);
    }
  }
  const pass = checks.every(x => x[0]);
  results.push({ id:c.id, desc:c.desc, pass, checks });
}

for (const r of results) {
  console.log(`${r.pass?'PASS':'FAIL'}  ${r.id}  ${r.desc}`);
  for (const [ok,what] of r.checks) if (!ok || process.env.VERBOSE) console.log(`        ${ok?'ok ':'>> '} ${what}`);
}
console.log(`\n${results.filter(r=>r.pass).length} / ${results.length} cases pass`);
