#!/usr/bin/env node
'use strict';

// post-edit.js — Claude Code PostToolUse hook, matcher Edit|Write.
//
// One job, and it must be silent when it has nothing to say: it fires on every single edit, so any
// routine output would cost conversation context on each one.
//
//   Syntax-gate the post. `node --check` after every edit is a standing rule in CLAUDE.md; here it stops
//   being something to remember. Syntax is meaningful at every edit, which is why it is checked here and
//   not at commit time -- otherwise five more edits can stack on a broken file.
//
// It once also nagged that the pre-commit document gate was not armed in a clone. That gate is retired
// (46bcf2a), so this is now the only hook the repo installs -- and the only automatic check there is.
// Nothing gates the documents: every rule in them is enforced in the diff, by a person.
//
// Exit 0 = silent success. Exit 2 = Claude Code feeds stderr back into the same turn.
//
// Node 10 / CommonJS / no dependencies.

var execFileSync = require('child_process').execFileSync;
var path = require('path');

var CPS = 'MPCNC_v4.1_Beta3.cps';

var input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', function (d) { input += d; });
process.stdin.on('end', function () { main(input); });

function main(raw) {
  var filePath;
  try {
    filePath = JSON.parse(raw).tool_input.file_path;
  } catch (e) {
    process.exit(0);                        // not shaped as expected — never block on our own parsing
  }
  if (!filePath) process.exit(0);

  var problems = [];
  var base = path.basename(filePath);

  if (base === CPS) {
    try {
      execFileSync('node', ['--check', filePath], { encoding: 'utf8', stdio: 'pipe' });
    } catch (e) {
      problems.push('node --check failed on ' + base + ':\n' + (e.stderr || e.message).trim());
    }
  }

  if (!problems.length) process.exit(0);
  process.stderr.write(problems.join('\n\n') + '\n');
  process.exit(2);
}
