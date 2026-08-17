// make-wcs-jobs.js -- build the intermediate .cnc job files the shipped library cannot supply.
//
//   node tools/wcs-jobs/make-wcs-jobs.js "<CNC files>" tools/wcs-jobs
//
// The argument is the ROOT of the Autodesk HSM extension's `res/CNC files`, not one file: the jobs
// below draw blocks from two of them. `integration.md` lists every job and what it covers.
//
// WHY THESE FILES EXIST
//
// Every .cnc Autodesk ships uses exactly ONE work offset, so `Each New WCS / Part`, writeWCS()'s
// traverse arm and writeWcsOnReturn() cannot be reached from their library at all -- the whole
// multi-part half of the post is unreachable by the harness. Fusion can produce such a job, but
// only with a licence and by hand, one job at a time. These files close that gap, and two of them
// close a second one: no shipped file changes tool INTO a jet tool, or cuts one part with a laser
// and another with the same laser in a different register.
//
// WHAT THEY ARE
//
// Not synthesised. Each job is a byte-for-byte concatenation of one source file's prologue and
// operation blocks, and in every copied block **at most one 32-bit word differs from its source**
// -- the context record's work offset. Nothing else is touched: not a parameter, not a tool, not a
// coordinate. So a job that behaves oddly cannot be blamed on a hand-built fixture, and two blocks
// in different offsets are the same operation with one variable changed, which is what makes the
// emitted difference attributable to the WCS logic.
//
// MIXING SOURCES IS SAFE, AND THAT WAS MEASURED RATHER THAN ASSUMED. `mill-then-jet.cnc` puts a
// milling block and a laser block in one job, which raised the question of whose prologue survives.
// Both variants were built and posted: the emitted g-code is IDENTICAL apart from the header's own
// metadata -- the Fusion version, the date, the document and Setup names -- because the prologue
// carries job identity and the section data the post reads travels in the blocks. So a mixed job
// takes the prologue of whichever source it is mostly made of, and the choice is cosmetic.
//
// THE FORMAT, AS FAR AS IT IS USED HERE
//
// A .cnc is CIMCO's `compact-nc`: a length-prefixed format string, a seven-byte preamble, then a
// flat stream of records, each `[uint32 opcode][payload]`. Only the parameter opcodes and the
// context opcode are decoded; everything else is copied as opaque bytes, which is why no writer is
// needed and why the copies are exact.
//
//   10  ascii string parameter    [u32 nameLen][name][u32 valLen][value]
//   11  utf-16 string parameter   [u32 nameLen][name][u32 charLen][value, 2 bytes per char]
//   12  int32 parameter           [u32 nameLen][name][i32]
//   14  stock box                 [6 x float32]           -- no name, follows the `stock` string
//   15  float64 parameter         [u32 nameLen][name][f64]
//   1034 context                  [u32 unit][u32 compensation][u32][3 x f32 origin]
//                                 [9 x f32 plane][3 x f32 wcs-origin][9 x f32 wcs-plane]
//                                 [u32 WORK OFFSET][...]  -- 188 bytes of payload
//
// 13 is absent from that list on purpose. It does not occur in the sources used here, so its payload
// length is unknown, and an opcode framed by guess walks off the record boundary in silence where an
// unknown one stops with the number in the message.
//
// An operation begins at its `.../nc/marker` parameter record and runs to the next one, or to the
// end of the file. Within a block the records up to the context are all parameters, so the context
// is found by walking rather than by searching for its opcode in what might be float data.
//
// The XML serialisation post.exe also accepts (`--format XML`) is NOT usable for this: its reader
// silently drops `work-offset`, so every section arrives as offset 0. Verified by editing
// work-offset in Autodesk's own `Milling/2D/bore.xml` and posting it -- the post still reports 0.

'use strict';
var fs = require('fs');
var path = require('path');

var NS = 'http://www.cimco-software.com/namespace/nc/';
var MARKER = NS + 'marker';
var OP_CONTEXT = 1034;
var WORK_OFFSET_AT = 108;         // byte offset of the work offset within the context payload
var PARAM_OPS = { 10: 1, 11: 1, 12: 1, 14: 1, 15: 1 };

// ---------------------------------------------------------------- reading

function readRecord(b, o) {
  var op = b.readUInt32LE(o);
  if (!PARAM_OPS[op]) return { op: op, end: null };
  var p = o + 4;
  if (op === 14) return { op: op, name: null, value: null, end: p + 24 };
  var nl = b.readUInt32LE(p); p += 4;
  var name = b.toString('latin1', p, p + nl); p += nl;
  var value;
  if (op === 10) { var n = b.readUInt32LE(p); p += 4; value = b.toString('latin1', p, p + n); p += n; }
  else if (op === 11) { var w = b.readUInt32LE(p); p += 4; value = b.toString('utf16le', p, p + w * 2); p += w * 2; }
  else if (op === 12) { value = b.readInt32LE(p); p += 4; }
  else { value = b.readDoubleLE(p); p += 8; }
  return { op: op, name: name, value: value, end: p };
}

// Every operation-marker record start, in file order.
function markerOffsets(b) {
  var needle = Buffer.from(MARKER, 'latin1');
  var out = [], i = 0;
  while ((i = b.indexOf(needle, i)) !== -1) {
    if (i >= 8 && b.readUInt32LE(i - 4) === needle.length && b.readUInt32LE(i - 8) === 12) out.push(i - 8);
    i++;
  }
  return out;
}

function split(file) {
  var b = fs.readFileSync(file);
  var marks = markerOffsets(b);
  if (!marks.length) throw new Error('no operation markers in ' + file);
  var blocks = marks.map(function (start, i) {
    var end = i + 1 < marks.length ? marks[i + 1] : b.length;
    var buf = Buffer.from(b.slice(start, end));
    var params = {}, o = 0, ctx = null;
    while (o < buf.length) {
      var r = readRecord(buf, o);
      if (r.end === null) { ctx = r; break; }
      if (r.name) params[r.name] = r.value;
      o = r.end;
    }
    if (!ctx) throw new Error(file + ' block ' + i + ': ran off the end without a context record');
    if (ctx.op !== OP_CONTEXT) throw new Error(file + ' block ' + i + ': expected context op ' + OP_CONTEXT + ', found ' + ctx.op);
    return { buf: buf, params: params, contextAt: o };
  });
  return { prologue: b.slice(0, marks[0]), blocks: blocks };
}

function workOffsetOf(blk) { return blk.buf.readUInt32LE(blk.contextAt + 4 + WORK_OFFSET_AT); }

// The one edit this tool makes. Returns a fresh block; the source is never mutated.
function withWorkOffset(blk, n) {
  var buf = Buffer.from(blk.buf);
  buf.writeUInt32LE(n, blk.contextAt + 4 + WORK_OFFSET_AT);
  return { buf: buf, params: blk.params, contextAt: blk.contextAt };
}

// ---------------------------------------------------------------- the sources
//
// Two files, and each one's blocks keep their own source offset so the "one word changed" check
// below knows what unchanged looks like: toolchange.cnc's blocks ship at offset 1, center.cnc's
// at 0 (the Work Offset field left alone, which the post aliases to WCS 1).

var SOURCES = {
  mill: { file: 'Milling/2D/toolchange.cnc', blocks: 2, offset: 1 },
  jet:  { file: 'Cutting/Laser/center.cnc',  blocks: 7, offset: 0 }
};

// The block pool. `source` names the file, `index` the operation within it.
//
// `A` is 2D-Face, tool 1, cutting to Z-1 ACROSS the part origin -- which is what makes it the block
// that puts a machined surface under a later probe. `B` is 2D-Contour, tool 2. `J` and `K` are two
// laser operations on tool 2, kept distinct so a jet job across two parts is two operations rather
// than the same one twice.
//
// A tool change is a block whose tool differs from the one before it, so the ARRANGEMENT is what
// puts a change where it is wanted; whether it is Flow 1 or Flow 2 is a post property, not a
// property of the job. A change into `J` is a change into a tool that cannot probe.

var POOL = {
  A: { source: 'mill', index: 0 },
  B: { source: 'mill', index: 1 },
  J: { source: 'jet',  index: 3 },   // Through-medium quality
  K: { source: 'jet',  index: 5 }    // Etch
};

// ---------------------------------------------------------------- the jobs
//
// Each entry is a list of [block, workOffset], plus the prologue to carry them.

var JOBS = [
  { file: 'one-part.cnc',
    plan: [['A', 1]],
    what: 'The control for every job below it. One operation in one offset is what Autodesk ships ' +
          "and what the Marlin single-offset suppression is gated on, so proving that gate needs " +
          'this file and `two-parts.cnc` together -- one where G54 must be absent, one where it ' +
          'must not be.' },

  { file: 'two-parts.cnc',
    plan: [['A', 1], ['A', 2]],
    what: 'One tool, two parts. The first WCS is established, then a second is met for the first ' +
          'time -- the Subsequent WCS / Part dispatch, which no shipped job reaches.' },

  { file: 'return-to-part.cnc',
    plan: [['A', 1], ['A', 2], ['A', 1]],
    what: 'A return to a part already set up, with no tool change anywhere. writeWcsOnReturn() ' +
          'with Z still trusted: the third section must select and travel and set NOTHING up. ' +
          'This is the path CR-17 fixed -- a second G38.2 into a floor the first pass had cut.' },

  { file: 'change-then-return.cnc',
    plan: [['A', 1], ['A', 2], ['B', 1]],
    what: 'The same return, but the returning section is a different tool. The change clears the ' +
          'Z half for every offset, so Z is stale on arrival and must be re-established by the ' +
          "mode's own answer while X0 Y0 is not." },

  { file: 'part-then-tools.cnc',
    plan: [['A', 1], ['B', 1], ['A', 2], ['B', 2]],
    what: 'Both tools on part 1, then both on part 2. The third section is a boundary that is ' +
          'BOTH a new work offset and a tool change: the part must be set up once, by the tool ' +
          'that cuts it, rather than probed by the change and again by the establish.' },

  { file: 'tools-across-parts.cnc',
    plan: [['A', 1], ['A', 2], ['B', 1], ['B', 2]],
    what: 'The same four operations sorted by tool instead of by part -- what --reorderbytools ' +
          'produces. One change, then two returns, both of them with Z stale.' },

  { file: 'spread-offsets.cnc',
    plan: [['A', 1], ['A', 4], ['A', 6]],
    what: 'Non-adjacent offsets: G54, G57, G59. Proves wcsGcode() computes the code rather than ' +
          'counting sections, and reaches the top of what GRBL has.' },

  { file: 'high-offsets.cnc',
    plan: [['A', 7], ['A', 9]],
    what: 'Above G59. GRBL has no such offset and the post must refuse; Marlin and RepRap have ' +
          'G59.1 to G59.3 and must emit them.' },

  { file: 'offset-out-of-range.cnc',
    plan: [['A', 10]],
    what: 'Past G59.3, which no supported firmware has. Refused on all three.' },

  { file: 'default-offset.cnc',
    plan: [['A', 0], ['A', 2]],
    what: "Fusion reports offset 0 for a Setup whose Work Offset field was left alone. The alias " +
          'to WCS 1 has to survive a job where a real second offset is also present.' },

  { file: 'mid-offsets.cnc',
    plan: [['A', 2], ['A', 3], ['A', 5], ['A', 8]],
    what: 'The four registers no other job selects. wcsGcode() is proved at 1, 4, 6, 7 and 9 and ' +
          'refused at 10, which leaves 2, 3, 5 and 8 computed but never emitted -- and 8 is the ' +
          'one that crosses from the G54-G59 run into the G59.x run on the firmwares that have it. ' +
          'It also starts a job on a register that is NOT WCS 1, which every other job does.' },

  { file: 'jet-two-parts.cnc',
    prologue: 'jet',
    plan: [['J', 1], ['K', 2]],
    what: 'The multi-part half met by a tool that CANNOT PROBE -- J2 and J5, the two rows that ' +
          'were out of reach of every harness. Each canProbe-false arm of the Subsequent WCS / ' +
          'Part dispatch runs here, writeWcsOnReturn() included, and the cross-part clearance ' +
          'happens in the machine frame with a jet tool held over the work.' },

  { file: 'jet-return.cnc',
    plan: [['A', 1], ['J', 2], ['J', 1]],
    what: 'A RETURN, in a job whose returning tool cannot probe. Section 1 sets part 1 up with a ' +
          'milling tool; section 2 is a change INTO the laser and a new part at once; section 3 ' +
          'returns to part 1 with Z0 stale and no way to re-measure it. That is the one arm of ' +
          "writeWcsOnReturn() nothing else reaches -- the arm that can only warn, which is PV-9's " +
          'open question about the canProbe-false path.' },

  { file: 'mill-then-jet.cnc',
    plan: [['A', 1], ['J', 1]],
    what: 'A tool change INTO a tool that cannot probe -- PR-22\'s falsifier, and the only job ' +
          'here that is not about work offsets. The spindle stop once read the INCOMING tool\'s ' +
          'jet guard, so a change into a laser handed the operator a still-turning cutter; the ' +
          'fix was walked and never witnessed. One offset, deliberately: the tool is the variable.' }
];

// ---------------------------------------------------------------- main

function main() {
  var root = process.argv[2];
  var outDir = process.argv[3] || path.join(__dirname);
  if (!root) {
    console.error('usage: node make-wcs-jobs.js "<CNC files>" [outDir]');
    process.exit(2);
  }

  // Read each source once, and hold it to its declared shape. A library that reorganises its
  // sample files must fail here, loudly, rather than produce jobs built from whatever it found.
  var src = {};
  Object.keys(SOURCES).forEach(function (name) {
    var s = SOURCES[name];
    var file = path.join(root, s.file);
    var got = split(file);
    if (got.blocks.length !== s.blocks) {
      throw new Error(s.file + ': expected ' + s.blocks + ' operations, found ' + got.blocks.length);
    }
    got.blocks.forEach(function (b, i) {
      var wo = workOffsetOf(b);
      if (wo !== s.offset) {
        throw new Error(s.file + ' block ' + i + ': work offset ' + wo + ', expected ' + s.offset + ' -- the format or the library has moved');
      }
    });
    src[name] = got;
    console.log('source: ' + s.file + '  (' + got.blocks.length + ' operations at offset ' + s.offset + ')');
  });

  // Resolve the pool, and report it -- the letters in the plans below are unreadable otherwise.
  var pool = {};
  Object.keys(POOL).forEach(function (k) {
    var d = POOL[k];
    var blk = src[d.source].blocks[d.index];
    pool[k] = { blk: blk, source: d.source };
    console.log('  ' + k + ' = T' + blk.params['operation:tool_number'] + ' ' +
                blk.params[NS + 'parameter/operation-comment'] +
                ' [' + d.source + ' ' + d.index + '], ' + blk.buf.length + ' bytes');
  });
  console.log('');

  JOBS.forEach(function (job) {
    var parts = [src[job.prologue || 'mill'].prologue];
    job.plan.forEach(function (step) {
      var entry = pool[step[0]];
      if (!entry) throw new Error(job.file + ': no source block named ' + step[0]);
      parts.push(withWorkOffset(entry.blk, step[1]).buf);
    });
    var out = Buffer.concat(parts);
    var dest = path.join(outDir, job.file);
    fs.writeFileSync(dest, out);

    // Read the file back the way the post's kernel will, and check it says what was asked for.
    var back = split(dest);
    var got = back.blocks.map(function (b) {
      return 'T' + b.params['operation:tool_number'] + '@' + workOffsetOf(b);
    });
    var want = job.plan.map(function (s) {
      return 'T' + pool[s[0]].blk.params['operation:tool_number'] + '@' + s[1];
    });
    if (got.join(' ') !== want.join(' ')) {
      throw new Error(job.file + ': wrote ' + want.join(' ') + ' but reads back as ' + got.join(' '));
    }

    // And check the claim this tool makes about itself: one word per block, nothing else.
    // "Unchanged" is per SOURCE -- the milling blocks ship at offset 1 and the jet blocks at 0,
    // so a jet block asked for offset 0 must differ by nothing while a milling one must differ
    // by the single word. Hard-coding 1 here would have passed every jet job for the wrong reason.
    back.blocks.forEach(function (b, i) {
      var entry = pool[job.plan[i][0]];
      var srcBuf = entry.blk.buf;
      if (b.buf.length !== srcBuf.length) throw new Error(job.file + ' block ' + i + ': length changed');
      var diffs = 0;
      for (var k = 0; k < srcBuf.length; k++) if (srcBuf[k] !== b.buf[k]) diffs++;
      var unchanged = job.plan[i][1] === SOURCES[entry.source].offset;
      if (unchanged && diffs !== 0) {
        throw new Error(job.file + ' block ' + i + ': ' + diffs + ' bytes differ, expected none');
      }
      if (!unchanged && (diffs < 1 || diffs > 4)) {
        throw new Error(job.file + ' block ' + i + ': ' + diffs + ' bytes differ, expected 1 to 4 (one u32)');
      }
    });

    console.log(job.file.padEnd(24) + String(out.length).padStart(7) + ' bytes   ' + got.join(' '));
  });

  console.log('\n' + JOBS.length + ' jobs written to ' + outDir);
}

main();
