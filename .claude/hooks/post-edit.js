#!/usr/bin/env node
'use strict';

// post-edit.js — Claude Code PostToolUse hook, matcher Edit|Write.
//
// Two jobs, and it must be silent when it has nothing to say: it fires on every single edit, so any
// routine output would cost conversation context on each one.
//
//   1. Syntax-gate the post. `node --check` after every edit is a standing rule in CLAUDE.md; here it
//      stops being something to remember. Syntax is meaningful at every edit, which is why this one is
//      not deferred to the pre-commit hook -- otherwise five more edits can stack on a broken file.
//
//   2. Notice that the pre-commit gate is not installed. `.githooks/pre-commit` is a tracked file and
//      travels with a clone, but `git config core.hooksPath` lives in .git/config and does NOT. This
//      hook does self-activate (it is wired in the tracked .claude/settings.json), so it is the only
//      thing positioned to notice the other one is missing.
//
// Exit 0 = silent success. Exit 2 = Claude Code feeds stderr back into the same turn.
//
// Node 10 / CommonJS / no dependencies.

var execFileSync = require('child_process').execFileSync;
var path = require('path');

var CPS = 'MPCNC_v4.0_Beta2.cps';
var HOOKS_PATH = '.githooks';

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
    problems = problems.concat(checkGateInstalled());
  }

  if (!problems.length) process.exit(0);
  process.stderr.write(problems.join('\n\n') + '\n');
  process.exit(2);
}

// The clone case: script present, activation absent, document gate silently gone.
// Asks git from the project directory (Claude Code runs hooks there), not from the edited file's
// directory -- a file outside the repo would otherwise produce a false alarm.
function checkGateInstalled() {
  var current;
  try {
    current = execFileSync('git', ['config', 'core.hooksPath'],
      { cwd: process.cwd(), encoding: 'utf8', stdio: 'pipe' }).trim();
  } catch (e) {
    current = '';                           // unset: git exits 1 with no output
  }
  if (current === HOOKS_PATH) return [];
  return ['The pre-commit document gate is not installed in this clone. ' +
    '`core.hooksPath` lives in .git/config and does not survive a clone, so the tracked ' +
    '`.githooks/pre-commit` is present but inert. Run:\n\n    git config core.hooksPath ' + HOOKS_PATH];
}
