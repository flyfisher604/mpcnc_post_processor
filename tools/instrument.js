// Build a coverage-instrumented copy of the post: every top-level function reports its
// first entry as a post-time warning, which reaches the log at any comment level and
// survives a refusal. Never run against the repo file -- it writes a copy.
const fs = require('fs');
const src = fs.readFileSync(process.argv[2], 'utf8');
const out = process.argv[3];

const lines = src.split(/\r?\n/);
const declared = [];      // every top-level function declaration
const hooked = [];        // the ones we could instrument
// The brace must be on the declaration line; a one-liner body follows it there, so the
// marker is spliced in at the brace rather than appended to the line.
const withBrace = /^(function\s+([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*\{)/;
const anyDecl   = /^function\s+([A-Za-z_$][\w$]*)\s*\(/;

for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(anyDecl);
  if (!m) continue;
  declared.push(m[1]);
  const b = lines[i].match(withBrace);
  if (b) {
    lines[i] = b[1] + ` __cov(${JSON.stringify(b[2])});` + lines[i].slice(b[1].length);
    hooked.push(b[2]);
  } else if (/^\s*\{/.test(lines[i + 1] || '')) {
    // One function in the file puts its brace on the next line.
    lines[i + 1] = lines[i + 1].replace('{', `{ __cov(${JSON.stringify(m[1])});`);
    hooked.push(m[1]);
  }
}

const prologue = [
  'var __covSeen = {};',
  'function __cov(n) { if (!__covSeen[n]) { __covSeen[n] = 1; warning("COV:" + n); } }',
  ''
].join('\n');

fs.writeFileSync(out, prologue + lines.join('\n'));
console.log(JSON.stringify({
  declared: declared.length,
  hooked: hooked.length,
  missed: declared.filter(n => !hooked.includes(n))
}, null, 1));
