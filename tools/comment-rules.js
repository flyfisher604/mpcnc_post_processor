// Report comment blocks that break the four stated rules.
//   R1  a block immediately before an `if` / `} else if` may not exceed 3 lines
//   R2  a block inside the leading var-declaration run of a function should not be there at all
//   R3  a function's header block may not exceed 50% of the function's own length
//   R4  a block immediately before a warning/error emission may not exceed 3 lines
var fs = require('fs');
var L = fs.readFileSync(process.argv[2], 'latin1').split('\n');
var isC = function (i) { return /^\s*\/\//.test(L[i]); };
var out = [];

// block starts: index -> length
var blocks = [];
for (var i = 0; i < L.length; i++) {
  if (isC(i) && (i === 0 || !isC(i - 1))) {
    var n = 0;
    while (i + n < L.length && isC(i + n)) { n++; }
    blocks.push({ start: i, len: n, next: i + n });
  }
}

// function extents, brace-counted from the header line
var funcs = [];
for (var i = 0; i < L.length; i++) {
  if (/^function\s+[A-Za-z_]/.test(L[i])) {
    if (/\}\s*$/.test(L[i])) { funcs.push({ line: i, end: i }); continue; }
    var depth = 0, j = i, started = false;
    for (; j < L.length; j++) {
      var code = L[j].replace(/\/\/.*$/, '');
      for (var k = 0; k < code.length; k++) {
        if (code.charAt(k) === '{') { depth++; started = true; }
        else if (code.charAt(k) === '}') { depth--; }
      }
      if (started && depth === 0) { break; }
    }
    funcs.push({ line: i, end: j });
  }
}

for (var b = 0; b < blocks.length; b++) {
  var blk = blocks[b], nx = L[blk.next] === undefined ? '' : L[blk.next];
  if (/^\s*(\}\s*else\s+)?if\s*\(/.test(nx) && blk.len > 3) {
    out.push('R1 ' + (blk.start + 1) + '-' + (blk.start + blk.len) + ' (' + blk.len + ') before: ' + nx.trim().slice(0, 60));
  }
  if (/^\s*(writeWarning|warning|error)\s*\(/.test(nx) && blk.len > 3) {
    out.push('R4 ' + (blk.start + 1) + '-' + (blk.start + blk.len) + ' (' + blk.len + ') before: ' + nx.trim().slice(0, 60));
  }
  if (/^function\s+[A-Za-z_]/.test(nx)) {
    for (var f = 0; f < funcs.length; f++) {
      if (funcs[f].line === blk.next) {
        var flen = funcs[f].end - funcs[f].line + 1;
        var allow = Math.max(3, Math.floor(flen / 2));
        if (blk.len > allow) {
          out.push('R3 ' + (blk.start + 1) + '-' + (blk.start + blk.len) + ' (' + blk.len +
                   ' header, ' + allow + ' allowed for ' + flen + ' body) ' + nx.trim().slice(0, 50));
        }
      }
    }
  }
}

// R2: comments inside the leading var run of a function body
for (var f = 0; f < funcs.length; f++) {
  var i = funcs[f].line + 1, sawVar = false;
  for (; i <= funcs[f].end; i++) {
    var t = L[i].trim();
    if (t === '') { continue; }
    if (isC(i)) {
      if (!sawVar) { continue; }
      var n = 0; while (isC(i + n)) { n++; }
      var after = L[i + n] === undefined ? '' : L[i + n].trim();
      if (/^(var|let)\s/.test(after)) {
        out.push('R2 ' + (i + 1) + '-' + (i + n) + ' (' + n + ') in var block of ' + L[funcs[f].line].trim().slice(0, 40));
      }
      i += n - 1;
      continue;
    }
    if (/^(var|let)\s/.test(t)) { sawVar = true; continue; }
    break;
  }
}

console.log(out.join('\n'));
console.log('\n' + out.length + ' violations');
