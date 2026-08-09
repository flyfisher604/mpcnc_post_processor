#!/usr/bin/env node
'use strict';

// doc-sync.js — has the post moved since the property tables were last written against it?
//
// The one document check worth a script. `property-reference.md` carries a marker naming the commit its
// tables were synced to, and the post goes on changing without it; nothing else notices. Every other
// check the retired check-docs.js ran was a document's arithmetic about itself, which the diff shows.
//
// By hand, when touching the guides or before a release — not a commit gate. Whether a given .cps commit
// changed what the dialog says is a judgement, and a gate that cannot fail is just noise on every commit.
//
//   node docs/doc-sync.js
//
// Node 10 / CommonJS / no dependencies.

var execFileSync = require('child_process').execFileSync;
var fs = require('fs');

var CPS = 'MPCNC_v4.0_Beta2.cps';
var DOC = 'docs/property-reference.md';

var m = /<!--\s*doc-sync:\s*\S+\s*@\s*([0-9a-f]{7,40})/.exec(fs.readFileSync(DOC, 'utf8'));
if (!m) {
  console.error(DOC + ': no doc-sync marker — nothing records what the tables were written against');
  process.exit(1);
}

var since = execFileSync('git', ['log', '--oneline', m[1] + '..HEAD', '--', CPS], { encoding: 'utf8' }).trim();
if (!since) process.exit(0);                    // in sync: say nothing

console.error(DOC + ' is ' + since.split('\n').length + ' commit(s) behind ' + CPS + ':\n\n' + since +
  '\n\nRead `git diff ' + m[1] + '..HEAD -- ' + CPS + '`. Re-bump the marker if none of them changed\n' +
  'what the dialog says; update the tables first if any did.\n');
