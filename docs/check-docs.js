#!/usr/bin/env node
'use strict';

// check-docs.js — mechanical gate for the document contracts in docs/conventions.md.
//
// Every check here is a rule already written in prose in conventions.md. The point is that a rule
// nobody measures drifts: three of these checks exist because the hand-maintained tallies in
// HReview.md had already gone wrong.
//
// SCOPE: documents only. It opens nothing but docs/*.md, CLAUDE.md and README.md -- the .cps is named
// once, to ask git whether it has commits newer than README's doc-sync ref, and is never read. The post
// is gated by .claude/hooks/post-edit.js, on every edit. Two checks that inspected the post's own
// contents have been removed from here for crossing that line; do not add a third.
//
//   node docs/check-docs.js            check the working tree
//   node docs/check-docs.js --staged   check what `git commit` is about to record (the pre-commit hook)
//
// Exits non-zero if any FAIL. WARN never fails the commit.
//
// Node 10 / CommonJS / zero dependencies — no .flat(), no matchAll(), no optional chaining.

var execFileSync = require('child_process').execFileSync;
var fs = require('fs');
var path = require('path');

var STAGED = process.argv.indexOf('--staged') !== -1;

var ROOT = git(['rev-parse', '--show-toplevel']).trim();

// Files under contract. `doc` is the name as it appears in the contracts table.
var DOCS = {
  'CLAUDE.md': 'CLAUDE.md',
  'plan.md': 'docs/plan.md',
  'conventions.md': 'docs/conventions.md',
  'design.md': 'docs/design.md',
  'HReview.md': 'docs/HReview.md',
  'PReview.md': 'docs/PReview.md',
  'README.md': 'README.md'
};

var REGISTERS = ['docs/HReview.md', 'docs/PReview.md'];
var CPS = 'MPCNC_v4.0_Beta2.cps';

var problems = [];
function fail(where, msg) { problems.push({ level: 'FAIL', where: where, msg: msg }); }
function warn(where, msg) { problems.push({ level: 'WARN', where: where, msg: msg }); }

function git(args) {
  return execFileSync('git', args, { cwd: ROOT || process.cwd(), encoding: 'utf8', maxBuffer: 1 << 26 });
}

// Read the content that matters: the index under --staged (which is exactly what the commit will
// record, and equals HEAD for a file nobody touched), the working tree otherwise.
function read(rel) {
  try {
    if (STAGED) return git(['show', ':' + rel]);
    return fs.readFileSync(path.join(ROOT, rel), 'utf8');
  } catch (e) {
    return null;
  }
}

function lineCount(text) {
  var n = text.split('\n').length;
  return text.charAt(text.length - 1) === '\n' ? n - 1 : n;
}

// ---------------------------------------------------------------- markdown table extraction

// Returns the first markdown table starting at or after `from`, as an array of {line, cells}.
// A table is a header row, a |---|---| separator, then body rows.
function tableAfter(lines, from) {
  for (var i = from; i < lines.length - 1; i++) {
    if (lines[i].charAt(0) !== '|') continue;
    if (!/^\|[\s:|-]+\|\s*$/.test(lines[i + 1])) continue;
    var rows = [];
    for (var j = i + 2; j < lines.length && lines[j].charAt(0) === '|'; j++) {
      rows.push({ line: j + 1, cells: splitRow(lines[j]) });
    }
    return { headerLine: i + 1, rows: rows };
  }
  return null;
}

function splitRow(line) {
  var cells = line.split('|');
  cells.shift();                                  // text before the leading pipe
  if (/\|\s*$/.test(line)) cells.pop();           // text after the trailing pipe
  return cells.map(function (c) { return c.trim(); });
}

// The trap from conventions.md: a harness whose extraction yields nothing reported eight vacuous
// passes. An empty table is never a pass here — it is an extraction bug.
function requireRows(table, where, what) {
  if (table && table.rows.length) return true;
  fail(where, 'extracted 0 rows for ' + what + ' — the parser is broken, not the document');
  return false;
}

// Base id of a register row or finding: **HR-12 (A5)** -> HR-12, **CR-17 (b)** -> CR-17.
function baseId(cell) {
  var m = /^\*\*([A-Z]+-?[A-Z0-9]+)/.exec(cell.replace(/^\|\s*/, ''));
  return m ? m[1] : null;
}

function idsIn(rows) {
  var out = [];
  rows.forEach(function (r) {
    var id = baseId(r.cells[0]);
    if (id && out.indexOf(id) === -1) out.push(id);
  });
  return out;
}

// ---------------------------------------------------------------- 1. size budgets (WARN)

function checkSizes(budgets) {
  Object.keys(budgets).forEach(function (doc) {
    var rel = DOCS[doc];
    if (!rel) return;
    var text = read(rel);
    if (text === null) return;
    var n = lineCount(text);
    if (n > budgets[doc]) {
      warn(rel, n + ' lines, budget ' + budgets[doc] +
        ' — check what has stopped being live rather than trimming prose');
    }
  });
}

// Budgets come out of the contracts table itself, so there is one place to change them.
function readBudgets() {
  var text = read('docs/conventions.md');
  if (text === null) return {};
  var lines = text.split('\n');
  var start = lines.findIndex(function (l) { return /^##\s+Document contracts/.test(l); });
  if (start === -1) {
    fail('docs/conventions.md', 'no "## Document contracts" section — budgets cannot be read');
    return {};
  }
  var table = tableAfter(lines, start);
  if (!requireRows(table, 'docs/conventions.md', 'the Document contracts table')) return {};

  var budgets = {};
  table.rows.forEach(function (r) {
    var name = /`([^`]+)`/.exec(r.cells[0]);
    var guide = r.cells[3] || '';
    var num = /≤\s*(\d+)\s*lines/.exec(guide);
    if (name && num) budgets[name[1]] = parseInt(num[1], 10);
  });
  return budgets;
}

// ---------------------------------------------------------------- 2. tallies match their tables

var STATES = ['✅', '❌', '⬜', '➖'];

function checkTallies(rel) {
  var text = read(rel);
  if (text === null) return;
  var lines = text.split('\n');

  lines.forEach(function (line, i) {
    // "**✅ 66 PASS · ❌ 0 FAIL · ⬜ 4 UNRUN · ➖ 17 n/a or moved — 87 rows.**"
    var m = /✅\s*(\d+)\s*PASS.*?❌\s*(\d+)\s*FAIL.*?⬜\s*(\d+)\s*UNRUN.*?➖\s*(\d+).*?(\d+)\s*rows/.exec(line);
    if (!m) return;

    var table = tableAfter(lines, i);
    if (!requireRows(table, rel + ':' + (i + 1), 'the table under the tally')) return;

    var actual = { '✅': 0, '❌': 0, '⬜': 0, '➖': 0 };
    table.rows.forEach(function (r) {
      var last = r.cells[r.cells.length - 1];
      STATES.forEach(function (s) { if (last.indexOf(s) !== -1) actual[s]++; });
    });

    var claimed = { '✅': +m[1], '❌': +m[2], '⬜': +m[3], '➖': +m[4] };
    STATES.forEach(function (s) {
      if (claimed[s] !== actual[s]) {
        fail(rel + ':' + (i + 1), 'tally says ' + claimed[s] + ' ' + s + ', table has ' + actual[s]);
      }
    });
    if (+m[5] !== table.rows.length) {
      fail(rel + ':' + (i + 1), 'tally says ' + m[5] + ' rows, table has ' + table.rows.length);
    }
  });
}

// "## Test register — 88 rows" — a count in a heading must match the table beneath it.
function checkHeadingRowCounts(rel) {
  var text = read(rel);
  if (text === null) return;
  var lines = text.split('\n');

  lines.forEach(function (line, i) {
    if (line.charAt(0) !== '#') return;
    var m = /—\s*(\d+)\s+rows/.exec(line);
    if (!m) return;
    var table = tableAfter(lines, i);
    if (!requireRows(table, rel + ':' + (i + 1), 'the table under the heading')) return;
    if (+m[1] !== table.rows.length) {
      fail(rel + ':' + (i + 1), 'heading says ' + m[1] + ' rows, table has ' + table.rows.length);
    }
  });
}

// "**44 findings** — 27 `HR-` from the hobbyist review, 17 `CR-` ..."
function checkFindingCount(rel) {
  var text = read(rel);
  if (text === null) return;
  var lines = text.split('\n');
  var joined = text.replace(/\n/g, ' ');

  var m = /\*\*(\d+) findings\*\*\s*—\s*(\d+)\s*`([A-Z]+)-`.*?(\d+)\s*`([A-Z]+)-`/.exec(joined);
  if (!m) return;

  var t = findingsTable(lines, rel);
  if (!t) return;
  var ids = idsIn(t.rows);
  var byPrefix = {};
  ids.forEach(function (id) {
    var p = id.split('-')[0];
    byPrefix[p] = (byPrefix[p] || 0) + 1;
  });

  var where = rel + ':' + lineOf(lines, /\*\*\d+ findings\*\*/);
  if (+m[1] !== ids.length) fail(where, 'says ' + m[1] + ' findings, table has ' + ids.length);
  if (+m[2] !== (byPrefix[m[3]] || 0)) fail(where, 'says ' + m[2] + ' ' + m[3] + '-, table has ' + (byPrefix[m[3]] || 0));
  if (+m[4] !== (byPrefix[m[5]] || 0)) fail(where, 'says ' + m[4] + ' ' + m[5] + '-, table has ' + (byPrefix[m[5]] || 0));
}

// "— 6 findings." anywhere above the findings table. HReview phrases its count one way and PReview
// another, so this covers the bare form and checkFindingCount() covers HReview's per-prefix breakdown.
function checkFindingTotal(rel) {
  var text = read(rel);
  if (text === null) return;
  var lines = text.split('\n');
  var t = findingsTable(lines, rel);
  if (!t) return;
  var n = idsIn(t.rows).length;

  for (var i = 0; i < lines.length; i++) {
    var m = /—\s*(\d+)\s+findings\b/.exec(lines[i]);
    if (!m) continue;
    if (+m[1] !== n) {
      fail(rel + ':' + (i + 1), 'claims ' + m[1] + ' findings, the findings table has ' + n);
    }
    return;                                  // the first such claim is the register's own
  }
}

function lineOf(lines, re) {
  for (var i = 0; i < lines.length; i++) if (re.test(lines[i])) return i + 1;
  return 0;
}

// ---------------------------------------------------------------- 3. id completeness

// "Complete by construction: every H/HR/HW id has a row." CR- ids are deliberately exempt — 19 of
// them are cosmetic or by-design closures that were never separate tests.
function checkIdCompleteness(rel) {
  var text = read(rel);
  if (text === null) return;
  var lines = text.split('\n');

  var findings = findingsTable(lines, rel);
  var register = testRegisterTable(lines, rel);
  if (!findings || !register) return;

  var rowed = idsIn(register.rows);
  idsIn(findings.rows).forEach(function (id) {
    if (!/^HR-\d+$/.test(id)) return;              // CR- exempt; HW- ids are born in the register
    if (rowed.indexOf(id) === -1) {
      fail(rel + ':' + register.headerLine,
        id + ' is in the findings table but has no test-register row (completeness is claimed)');
    }
  });
}

// ---------------------------------------------------------------- 4. heading id ranges

// "## Findings — HR-1 … HR-26 · CR-1 … CR-17" must agree with the table beneath it.
function checkHeadingRanges(rel) {
  var text = read(rel);
  if (text === null) return;
  var lines = text.split('\n');

  lines.forEach(function (line, i) {
    if (line.charAt(0) !== '#') return;
    var re = /([A-Z]+)-(\d+)\s*…\s*\1-(\d+)/g;
    var m, found = [];
    while ((m = re.exec(line)) !== null) found.push(m);
    if (!found.length) return;

    var table = tableAfter(lines, i);
    if (!requireRows(table, rel + ':' + (i + 1), 'the table under the heading')) return;
    var ids = idsIn(table.rows);

    found.forEach(function (g) {
      var prefix = g[1];
      var nums = ids
        .filter(function (id) { return id.indexOf(prefix + '-') === 0; })
        .map(function (id) { return parseInt(id.slice(prefix.length + 1), 10); })
        .filter(function (n) { return !isNaN(n); });
      if (!nums.length) return;
      var lo = Math.min.apply(null, nums), hi = Math.max.apply(null, nums);
      if (+g[2] !== lo || +g[3] !== hi) {
        fail(rel + ':' + (i + 1), 'heading says ' + prefix + '-' + g[2] + ' … ' + prefix + '-' + g[3] +
          ', table runs ' + prefix + '-' + lo + ' … ' + prefix + '-' + hi);
      }
    });
  });
}

// Canonical sections are identified by NAME, not by number -- PReview numbers its sections and
// HReview does not, and renumbering PReview would break ~30 cross-references for cosmetic gain.
// See conventions.md -> The shape of a review document.
function sectionTable(lines, rel, name, label) {
  var re = new RegExp('^##\\s+(\\d+\\.\\s+)?' + name + '\\b', 'i');
  var i = lines.findIndex(function (l) { return re.test(l); });
  if (i === -1) return null;
  var t = tableAfter(lines, i);
  return requireRows(t, rel, label) ? t : null;
}

function findingsTable(lines, rel) {
  return sectionTable(lines, rel, 'Findings', 'the findings table');
}

function testRegisterTable(lines, rel) {
  return sectionTable(lines, rel, 'Test register', 'the test register');
}

// ---------------------------------------------------------------- 5. pointer direction

// conventions.md Rule 3: "A pointer is only valid in one direction: from status toward the register
// that owns the work." plan.md may point at a register; a register may never point back.
function checkPointerDirection() {
  REGISTERS.forEach(function (rel) {
    var text = read(rel);
    if (text === null) return;
    text.split('\n').forEach(function (line, i) {
      if (line.indexOf('plan.md') !== -1) {
        fail(rel + ':' + (i + 1), 'a register points back at plan.md — pointers run status → register only');
      }
    });
  });
}

// ---------------------------------------------------------------- 6. README doc-sync (WARN)

function checkDocSync() {
  var text = read('README.md');
  if (text === null) return;
  var m = /<!--\s*doc-sync:\s*\S+\s*@\s*([0-9a-f]{7,40})/.exec(text);
  if (!m) {
    warn('README.md', 'no doc-sync marker found');
    return;
  }
  var ref = m[1];
  try {
    git(['merge-base', '--is-ancestor', ref, 'HEAD']);
  } catch (e) {
    fail('README.md', 'doc-sync ref ' + ref + ' is not an ancestor of HEAD');
    return;
  }
  var since = git(['log', '--oneline', ref + '..HEAD', '--', CPS]).trim();
  if (since) {
    var n = since.split('\n').length;
    warn('README.md', CPS + ' has ' + n + ' commit(s) since doc-sync ref ' + ref +
      ' — review `git diff ' + ref + '..HEAD -- ' + CPS + '` and re-bump if any changed what it emits');
  }
}

// ---------------------------------------------------------------- run

// What the run actually inspected. A checker that says nothing about the sections it could not parse
// reads as a clean bill of health -- which is exactly how PReview went ungated while this reported
// "clean": both its section matchers returned -1 and every id check silently skipped.
var coverage = [];

checkSizes(readBudgets());
REGISTERS.forEach(function (rel) {
  var text = read(rel);
  if (text === null) { coverage.push(short(rel) + ': unreadable'); return; }
  var lines = text.split('\n');
  var seen = [];
  var f = findingsTable(lines, rel);
  var t = testRegisterTable(lines, rel);
  if (f) seen.push('findings ' + idsIn(f.rows).length);
  if (t) seen.push('rows ' + t.rows.length);
  if (!f) seen.push('NO findings table');
  if (!t) seen.push('NO test register');
  coverage.push(short(rel) + ': ' + seen.join(', '));

  checkTallies(rel);
  checkHeadingRowCounts(rel);
  checkFindingCount(rel);
  checkFindingTotal(rel);
  checkIdCompleteness(rel);
  checkHeadingRanges(rel);
});
checkPointerDirection();
checkDocSync();

function short(rel) { return rel.replace(/^docs\//, '').replace(/\.md$/, ''); }

var fails = problems.filter(function (p) { return p.level === 'FAIL'; });
problems.forEach(function (p) {
  process.stderr.write(p.level + ' ' + p.where + '  ' + p.msg + '\n');
});
process.stderr.write('checked  ' + coverage.join('  |  ') + '\n');

if (fails.length) {
  process.stderr.write('\n' + fails.length + ' document-contract violation(s). See docs/conventions.md → Document contracts.\n');
  process.exit(1);
}
process.exit(0);
