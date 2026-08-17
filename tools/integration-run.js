/**
  integration-run.js -- run every matrix, once, and fail if any case does.

  IT SEQUENCES THE MATRICES; IT DOES NOT UNIFY THEM. Each matrix keeps its own baseline, because
  the personas disagree about what the factory defaults should do and a shared baseline would have
  to pick one -- integration.md 6.4. What this adds is that no matrix can be forgotten: group 3 was
  reachable for a long time before anything reached it, and a suite you have to remember to run in
  four parts is a suite that gets run in three.

  Exit status is 0 only when every case in every matrix passes, so it is usable as a gate.

  Run:
    node tools/integration-run.js <post.exe> <post.cps> "<CNC files dir>" <output dir>
  VERBOSE=1 is passed through to each matrix.
*/
const { spawnSync } = require('child_process');
const path = require('path');

const [, , POST, CPS, CNCR, OUT] = process.argv;
if (!POST || !CPS || !CNCR || !OUT) {
  console.error('usage: node tools/integration-run.js <post.exe> <post.cps> "<CNC files dir>" <output dir>');
  process.exit(2);
}

const here = __dirname;
// The last two take the CNC root like the first two, and reach `wcs-jobs` themselves for the handful
// of cases that need a second part -- they are categories rather than personas, so a case in them is
// chosen by the question it asks and not by whose job file it runs on.
const MATRICES = [
  { name:'hobbyist',     script:'hobbyist-matrix.js',     jobs:CNCR },
  { name:'professional', script:'professional-matrix.js', jobs:CNCR },
  { name:'wcs',          script:'wcs-matrix.js',          jobs:path.join(here, 'wcs-jobs') },
  { name:'personal',     script:'personal-matrix.js',     jobs:CNCR },
  { name:'correct-gcode',   script:'correct-gcode-matrix.js',   jobs:CNCR },
  { name:'gcode-structure', script:'gcode-structure-matrix.js', jobs:CNCR },
];

let pass = 0, total = 0, failed = [];

for (const m of MATRICES) {
  console.log(`\n=== ${m.name} ===`);
  const r = spawnSync(process.execPath,
    [path.join(here, m.script), POST, CPS, m.jobs, path.join(OUT, m.name)],
    { encoding:'utf8' });
  const out = (r.stdout || '') + (r.stderr || '');
  process.stdout.write(out);

  // The tally line each matrix ends on. A matrix that DIED rather than failing prints no tally, and
  // that must not read as zero cases quietly passing.
  const tally = out.match(/^(\d+) \/ (\d+) cases pass$/m);
  if (!tally) { failed.push(`${m.name} produced no tally (exit ${r.status}) -- it did not finish`); continue; }
  pass += Number(tally[1]);
  total += Number(tally[2]);
  if (tally[1] !== tally[2]) failed.push(`${m.name}: ${tally[2] - tally[1]} case(s) failed`);
}

console.log('\n' + '='.repeat(60));
console.log(`${pass} / ${total} cases pass across ${MATRICES.length} matrices`);
for (const f of failed) console.log(`  FAILED  ${f}`);
process.exit(failed.length ? 1 : 0);
