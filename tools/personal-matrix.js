/**
  personal-matrix.js -- groups 2 and 3, posted and checked: the feedrates, and the rapids a
  Personal licence turns into cuts.

  WHY THESE TWO GROUPS SHARE A MATRIX. Group 3 exists because Fusion's Personal edition delivers
  every link, retract and traverse as a FEED move; group 2 is what then decides how fast those
  moves go. Unrecovered, a traverse runs at the slowest CUTTING limit -- which is the defect group
  3 undoes, and it cannot be seen without varying both. `R7` is that crossing and it is the point
  of the file.

  HOW GROUP 3 IS REACHED AT ALL. It cannot be reached from a job file. Autodesk's library is
  full-licence output, where every rapid arrives at onRapid() and isSafeToRapid() is never
  consulted; and the spliced fixtures copy motion records as opaque bytes, so they cannot author a
  feed move either. The post therefore carries ONE invisible test property,
  `mapRapidsTestPersonalLicence`, which makes onRapid() forward to onLinear() -- see its
  declaration. `R1` is the case that holds the post to that: with the hook off, group 3 changes
  nothing but its own dump line.

  NOTHING HERE IS RECOMPUTED. No case reproduces the post's feed arithmetic; every group-2 claim is
  a DIFFERENCE between two runs -- a feed that appears, a maximum that falls, a count that drops
  while the distinct values stay put. A test that re-derived the scaling would pass on a post that
  scaled consistently wrongly.

  Node spawns post.exe with an argument ARRAY, so the JS-literal quoting a property value needs is
  handled by Node's own CRT quoting rather than by a shell -- see integration.md 6.1.

  Run:
    node tools/personal-matrix.js <post.exe> <post.cps> "<CNC files dir>" <output dir>
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

// The hook, and the baseline that goes with it. A Personal-licence job is exactly a job in which
// every rapid arrives as a feed move; nothing else about the persona differs.
const HOOK = { mapRapidsTestPersonalLicence:B(true) };
const personal = extra => Object.assign({}, HOOK, extra);

const countOf = (t, re) => (t.match(re) || []).length;

// Walk the file tracking the MODAL motion word, because a block that omits G0/G1 belongs to the
// motion still in force -- and the converted moves are exactly those blocks. Reading `^G1 .*F` and
// nothing else would miss `X-27 Y-8.6 F2500`, which is the very line group 3 produces.
// Returns one record per motion block carrying a feedrate.
function motions(t) {
  let g = null;
  const out = [];
  for (let raw of t.split(/\r?\n/)) {
    const line = raw.replace(/\(.*?\)/g, '').replace(/;.*$/, '').trim();
    if (!line) continue;
    const gm = line.match(/^(?:N\d+ )?(?:G53 )?G([0123])\b/);
    if (gm) g = Number(gm[1]);
    else if (!/^(?:N\d+ )?[XYZIJKF]/.test(line)) continue;   // not a motion continuation
    const f = line.match(/\bF([\d.]+)/);
    if (!f) continue;
    const axes = (line.match(/\b([XYZ])-?[\d.]+/g) || []).map(s => s[0]);
    out.push({ g: g, axes: axes, f: parseFloat(f[1]) });
  }
  return out;
}

// Motion and command blocks only, every comment-only line dropped. A comparison that keeps comments
// cannot survive an INSERTED line: one extra line shifts every index after it and a positional
// compare reports the whole file as changed. That is exactly how R1 first failed -- 1107 lines
// reported against the 3 `diff` actually finds.
const codeLines = t => t.split(/\r?\n/).map(l => l.trim()).filter(l => l && l[0] !== '(' && l[0] !== ';');

const cutting  = t => motions(t).filter(m => m.g === 1 || m.g === 2 || m.g === 3);
const zOnly    = ms => ms.filter(m => m.axes.length === 1 && m.axes[0] === 'Z');
const xyOnly   = ms => ms.filter(m => m.axes.length && m.axes.indexOf('Z') < 0);
const maxF     = ms => ms.reduce((a, m) => Math.max(a, m.f), 0);
const distinct = ms => { const s = {}; ms.forEach(m => { s[m.f] = 1; }); return Object.keys(s).sort().join(','); };

const cases = [
// --- group 3: the bound first, so the hook is never the thing being trusted ----------------
{ id:'R1', desc:'The bound: on full-licence output group 3 is INERT -- the hook off, and nothing to restore',
  cnc:'Milling/2D/bore.cnc', props:{ mapRapidsRestoreRapids:B(true) },
  compare:{ props:{ mapRapidsRestoreRapids:B(false) } },
  must:[[/\( SafeZ retract level: /,'the group does resolve a safe height, and says so']],
  mustNot:[[/First G1 --> G0/,'no first-move conversion - every rapid arrived as a rapid'],
           [/Safe G1 --> G0/,'no safe-move conversion - isSafeToRapid is never consulted']],
  custom:(t,ref) => {
    // G-CODE ONLY. Switching the group on ADDS a comment line, so the claim is not "the files are
    // identical" -- it is the stronger and more precise one: not a single emitted BLOCK moves.
    const a = codeLines(t), b = codeLines(ref);
    if (a.length !== b.length) return [false, `${a.length} g-code blocks against ${b.length} - the motion changed`];
    const moved = a.filter((l,i) => l !== b[i]).length;
    return moved === 0
      ? [true, `all ${a.length} g-code blocks identical - the group changes its own commentary and nothing else`]
      : [false, `${moved} of ${a.length} g-code blocks differ`]; } },

{ id:'R2', desc:'The hook reaches the code no job file can, and says so in BOTH channels',
  cnc:'Milling/2D/bore.cnc', props:personal({ mapRapidsRestoreRapids:B(true) }),
  must:[[/^\( >>> WARNING: TEST HOOK IS ON /m,'the file says it is a test artifact'],
        [/\( First G1 --> G0\)/,"the section's first move converts"],
        [/\( Safe G1 --> G0\)/,'a move above safe Z converts']],
  mustLog:[[/TEST ONLY -- deliver rapids as feed moves" is enabled/,'and the dialog says so too']],
  custom:t => {
    const first = countOf(t, /\( First G1 --> G0\)/g), safe = countOf(t, /\( Safe G1 --> G0\)/g);
    // bore.cnc is one section, so exactly one move can be a section's first.
    return (first === 1 && safe >= 1)
      ? [true, `${first} first-move conversion and ${safe} safe-move conversions`]
      : [false, `first=${first} (expected 1), safe=${safe} (expected at least 1)`]; } },

{ id:'R3', desc:'Restore Rapids is the master switch: the hook alone converts nothing',
  cnc:'Milling/2D/bore.cnc', props:personal({ mapRapidsRestoreRapids:B(false), feedsTravelSpeedZ:N(321) }),
  compare:{ props:personal({ mapRapidsRestoreRapids:B(true), feedsTravelSpeedZ:N(321) }) },
  mustNot:[[/First G1 --> G0/,'nothing converts with the group switched off'],
           [/Safe G1 --> G0/,'nothing converts with the group switched off']],
  custom:(t,ref) => {
    const off = countOf(t, /\bF321\b/g), on = countOf(ref, /\bF321\b/g);
    return on > off ? [true, `moves at the Z travel speed: ${off} with the group off, ${on} with it on`]
                    : [false, `F321 appears ${off} times off and ${on} times on - the group changed nothing`]; } },

// PC-6. The height is group 5's "Safe Z" now, one property read by both groups -- so this case posts
// group 3 against a property that is not in group 3, which is the finding. Group 3 keeps its boolean
// and has no field of its own.
{ id:'R4', desc:'Safe Z decides HOW MANY moves convert - and it is group 5s field that group 3 reads',
  cnc:'Milling/2D/bore.cnc', props:personal({ mapRapidsRestoreRapids:B(true), probeSafeZ:S('100') }),
  compare:{ props:personal({ mapRapidsRestoreRapids:B(true), probeSafeZ:S('0') }) },
  must:[[/\( First G1 --> G0\)/,'the first move still converts - it is not gated on safe Z']],
  custom:(t,ref) => {
    const high = countOf(t, /\( Safe G1 --> G0\)/g), low = countOf(ref, /\( Safe G1 --> G0\)/g);
    // Isolated deliberately: the FIRST-move conversion ignores safe Z, so only the safe-move
    // count can attribute a difference to this property.
    return (high === 0 && low > 0)
      ? [true, `safe-move conversions: ${high} with Safe Z at 100, ${low} at 0`]
      : [false, `expected 0 conversions at Safe Z 100 and some at 0, got ${high} and ${low}`]; } },

// --- group 2: every claim is a difference between two runs, never a recomputation -----------
{ id:'F1', desc:'Travel speeds: the new rates appear and the shipped ones leave - both directions',
  cnc:'Milling/2D/face.cnc', props:{ feedsTravelSpeedXY:N(1234), feedsTravelSpeedZ:N(321) },
  compare:{ props:{} },
  must:[[/\bF1234\b/,'travels in X and Y take the set rate'],[/\bF321\b/,'and Z takes its own']],
  mustNot:[[/\bF2500\b/,'the shipped XY default is gone'],[/\bF300\b/,'and the shipped Z default with it']],
  custom:(t,ref) => {
    // Two-sided, so the case cannot pass because the numbers happened to be in the file already.
    const ok = /\bF2500\b/.test(ref) && /\bF300\b/.test(ref) && !/\bF1234\b/.test(ref) && !/\bF321\b/.test(ref);
    return ok ? [true, 'and the reference run carries the defaults and neither new rate']
              : [false, 'the reference run does not hold the defaults - the comparison proves nothing']; } },

{ id:'F2', desc:'Scale Feedrate off: the cutting feeds change, and scaling only ever slows them',
  cnc:'Milling/2D/bore.cnc', props:{ feedsScaleFeedrate:B(false) },
  compare:{ props:{ feedsScaleFeedrate:B(true) } },
  custom:(t,ref) => {
    // BLOCK FOR BLOCK, not maximum against maximum. bore.cnc asks for F1000 throughout and Max
    // Toolpath Speed ships at 1000, so the fastest cut is 1000 either way while scaling still slows
    // the arcs and drops the plunge to the Z limit. Comparing maxima called that "no change".
    // Scaling adds and removes no motion, so the two runs line up one to one -- and the invariant
    // the post states for itself is "never RAISE a feed", which is what this asserts.
    const off = cutting(t).map(m => m.f), on = cutting(ref).map(m => m.f);
    if (!off.length) return [false, 'no cutting moves found'];
    if (off.length !== on.length)
      return [false, `${off.length} cutting moves unscaled against ${on.length} scaled - not comparable block for block`];
    const raised = on.filter((f,i) => f > off[i]).length;
    if (raised) return [false, `${raised} moves are FASTER with scaling on - scaling must only ever reduce`];
    const slowed = on.filter((f,i) => f < off[i]).length;
    return slowed
      ? [true, `${slowed} of ${on.length} cutting moves are slower with scaling on, and none is faster`]
      : [false, 'scaling changed no feedrate at all']; } },

{ id:'F3', desc:'Max Toolpath Speed is a visible cap on the whole path',
  cnc:'Milling/2D/bore.cnc', props:{ feedsScaleFeedrate:B(true), feedsMaxCutSpeedXYZ:N(250) },
  compare:{ props:{ feedsScaleFeedrate:B(true) } },
  custom:(t,ref) => {
    const cut = cutting(t), was = maxF(cutting(ref));
    const over = cut.filter(m => m.f > 250);
    if (over.length) return [false, `${over.length} cutting moves above the 250 cap, fastest ${maxF(over)}`];
    return maxF(cut) < was ? [true, `fastest cut fell from ${was} to ${maxF(cut)} and nothing exceeds the cap`]
                           : [false, `fastest cut ${maxF(cut)} against ${was} before - the cap moved nothing`]; } },

{ id:'F4', desc:'Max Z Cut Speed moves the PLUNGES and is not the same lever as XY',
  cnc:'Milling/2D/bore.cnc', props:{ feedsScaleFeedrate:B(true), feedsMaxCutSpeedZ:N(60) },
  compare:{ props:{ feedsScaleFeedrate:B(true) } },
  custom:(t,ref) => {
    const now = maxF(zOnly(cutting(t))), was = maxF(zOnly(cutting(ref)));
    if (!was) return [false, 'the reference run has no Z-only cutting move to compare against'];
    return (now < was && now <= 60)
      ? [true, `fastest Z-only cut fell from ${was} to ${now}`]
      : [false, `fastest Z-only cut ${now} against ${was} before, ceiling 60`]; } },

{ id:'F5', desc:'Max XY Cut Speed moves the XY moves and the arcs with them',
  cnc:'Milling/2D/bore.cnc', props:{ feedsScaleFeedrate:B(true), feedsMaxCutSpeedXY:N(200) },
  compare:{ props:{ feedsScaleFeedrate:B(true) } },
  custom:(t,ref) => {
    const now = maxF(xyOnly(cutting(t))), was = maxF(xyOnly(cutting(ref)));
    if (!was) return [false, 'the reference run has no XY cutting move to compare against'];
    return (now < was && now <= 200)
      ? [true, `fastest XY cut fell from ${was} to ${now} - limitArcFeed caps G2/G3 on the same limit`]
      : [false, `fastest XY cut ${now} against ${was} before, ceiling 200`]; } },

{ id:'F6', desc:'Enforce Feedrate is about REPETITION, not about the rates themselves',
  cnc:'Milling/2D/bore.cnc', props:{ feedsEnforceFeedrate:B(false) },
  compare:{ props:{ feedsEnforceFeedrate:B(true) } },
  custom:(t,ref) => {
    const off = cutting(t), on = cutting(ref);
    if (off.length >= on.length) return [false, `${off.length} feed words with it off against ${on.length} on - no fewer`];
    // The sharp half: fewer F words, and the SAME set of values. Anything else would mean the
    // property had changed how fast the machine cuts, which is not what it claims to do.
    return distinct(off) === distinct(on)
      ? [true, `${off.length} feed words against ${on.length}, and the same ${distinct(off).split(',').length} distinct rates`]
      : [false, `the rates themselves changed: ${distinct(off)} against ${distinct(on)}`]; } },

// --- where the two groups meet, which is the reason group 3 exists --------------------------
{ id:'R7', desc:'Unrecovered, a Personal-licence traverse runs at the slowest CUTTING limit',
  cnc:'Milling/2D/bore.cnc',
  props:personal({ mapRapidsRestoreRapids:B(false), feedsScaleFeedrate:B(true), feedsTravelSpeedZ:N(321) }),
  compare:{ props:personal({ mapRapidsRestoreRapids:B(true), feedsScaleFeedrate:B(true), feedsTravelSpeedZ:N(321) }) },
  custom:(t,ref) => {
    // The retracts and traverses arrive as feed moves either way. The question is what rate they
    // leave at: the Z CUT ceiling, or the Z TRAVEL speed. This is the post's own stated reason for
    // group 3 -- "the first move to the start of a section will be at the slowest cutting feedrate".
    const stranded = zOnly(cutting(t));
    const recovered = motions(ref).filter(m => m.g === 0 && m.f === 321);
    if (!stranded.length) return [false, 'no Z feed moves in the unrecovered run to strand'];
    if (maxF(stranded) > 180) return [false, `a Z feed move at ${maxF(stranded)}, above the 180 cut ceiling`];
    return recovered.length
      ? [true, `unrecovered, every Z traverse is a cut at ${maxF(stranded)} or less; recovered, ${recovered.length} leave as rapids at 321`]
      : [false, 'the recovered run has no Z rapid at the travel speed - group 3 did not recover the traverse']; } },
];

const results = [];

// One run of post.exe. Both halves of a compare case go through here, so the reference cannot be
// produced by a different code path from the thing it is compared against.
function post(id, cnc, props, wantLog) {
  const gcode = path.join(OUT, `${id}.gcode`);
  const log   = path.join(OUT, `${id}.log`);
  if (fs.existsSync(gcode)) fs.unlinkSync(gcode);
  if (fs.existsSync(log)) fs.unlinkSync(log);

  const args = ['--noeditor','--nointeraction','--nobackup','--noprogress','--log',log];
  for (const [k,v] of Object.entries(props)) args.push('--property', k, v);
  args.push(CPS, path.join(CNCR, cnc), gcode);

  const r = spawnSync(POST, args, { encoding:'utf8' });
  const posted = r.status === 0 && fs.existsSync(gcode);
  return {
    posted: posted, status: r.status,
    text: posted ? fs.readFileSync(gcode,'utf8') : '',
    log: (fs.existsSync(log) ? fs.readFileSync(log,'utf8') : '') + (r.stdout || '') + (r.stderr || '')
  };
}

for (const c of cases) {
  const run = post(c.id, c.cnc, c.props, true);
  const checks = [];

  if (!run.posted) {
    checks.push([false, `post refused (exit ${run.status}) -- ${(run.log.match(/Error: .*/) || ['no error line'])[0]}`]);
  } else {
    let ref = '';
    if (c.compare) {
      // The reference is a full run of its own, not a cached one: a case that varies a property
      // must vary it against the same job through the same executable.
      const rr = post(c.id + '-ref', c.compare.cnc || c.cnc, c.compare.props, false);
      if (!rr.posted) checks.push([false, `the reference run refused (exit ${rr.status})`]);
      ref = rr.text;
    }
    for (const [re,what] of (c.must||[]))       checks.push([re.test(run.text),  `must: ${what}`]);
    for (const [re,what] of (c.mustNot||[]))    checks.push([!re.test(run.text), `must not: ${what}`]);
    for (const [re,what] of (c.mustLog||[]))    checks.push([re.test(run.log),   `must warn: ${what}`]);
    for (const [re,what] of (c.mustNotLog||[])) checks.push([!re.test(run.log),  `must not warn: ${what}`]);
    if (c.custom && checks.every(x => x[0])) checks.push(c.custom(run.text, ref));
  }

  const pass = checks.every(x => x[0]);
  results.push({ id:c.id, desc:c.desc, pass, checks });
}

for (const r of results) {
  console.log(`${r.pass?'PASS':'FAIL'}  ${r.id}  ${r.desc}`);
  for (const [ok,what] of r.checks) if (!ok || process.env.VERBOSE) console.log(`        ${ok?'ok ':'>> '} ${what}`);
}
console.log(`\n${results.filter(r=>r.pass).length} / ${results.length} cases pass`);
