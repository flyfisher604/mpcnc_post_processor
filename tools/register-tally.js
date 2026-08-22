/*
  register-tally.js -- count the findings.md registers so no tally in that file is
  written by hand.

  property-coverage.js did this for integration.md's coverage table, for the same
  reason: the counts in findings.md were maintained by a person over a 240KB file,
  and 5's went wrong -- "171 PASS / 18 n/a / 181 rows" written against 172/17/189
  actual -- with nothing in the process able to catch it.

    node tools/register-tally.js            print the tallies
    node tools/register-tally.js --check     exit 1 if the file disagrees

  A row is a table line opening with a bold id. Its state is n/a where the row
  carries the skip marker and a pass/fix otherwise: 3 puts the marker in its last
  column, 5 opens its Result cell with it, and 138 of 5's rows carry no marker at
  all because the section they sit under is what says they passed.
*/

var fs = require('fs');
var path = require('path');

var FILE = path.join(__dirname, '..', 'docs', 'findings.md');
var SKIP = '➖';
var PASS = '✅';

var REGISTERS = {'3': 'Closed findings', '5': 'Passed tests'};

var lines = fs.readFileSync(FILE, 'utf8').split(/\r?\n/);
var tally = {};
var section = null;

lines.forEach(function (line) {
  var heading = line.match(/^## (\d)\./);
  if (heading) section = heading[1];
  if (!REGISTERS[section] || !/^\| \*\*/.test(line)) return;
  if (!tally[section]) tally[section] = {rows: 0, skip: 0};
  tally[section].rows++;
  // Skip over the id cell: an id may itself mention the marker.
  if (line.split('|').slice(2).join('|').indexOf(SKIP) !== -1) tally[section].skip++;
});

var report = Object.keys(REGISTERS).map(function (s) {
  var t = tally[s] || {rows: 0, skip: 0};
  return {
    section: s,
    rows: t.rows,
    skip: t.skip,
    line: '**' + PASS + ' ' + (t.rows - t.skip) + ' · ' + SKIP + ' ' + t.skip +
          ' — ' + t.rows + ' rows.**'
  };
});

report.forEach(function (r) {
  console.log('§' + r.section + ' ' + REGISTERS[r.section] + '  ' + r.line);
});

if (process.argv.indexOf('--check') === -1) return;

/* The written tally is the first line under the section heading opening with the
   pass marker. It must read exactly as printed above, so a disagreement is a diff
   rather than a judgement. */
var failed = false;
report.forEach(function (r) {
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (new RegExp('^## ' + r.section + '\.').test(lines[i])) { start = i; break; }
  }
  var written = null;
  lines.slice(start, start + 12).forEach(function (l) {
    if (written === null && l.indexOf('**' + PASS + ' ') === 0) written = l;
  });
  if (written !== r.line) {
    console.error('\n§' + r.section + ': the written tally does not match the rows');
    console.error('  written: ' + (written === null ? '(none in the 12 lines under the heading)' : written));
    console.error('  rows:    ' + r.line);
    failed = true;
  }
});

if (failed) {
  console.error('\nSet findings.md to the "rows:" line above, verbatim.');
  process.exit(1);
}
console.log('\nBoth tallies match their rows.');
