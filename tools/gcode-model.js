/**
  gcode-model.js -- read an emitted .gcode file as g-code, and read a trace.cps run as the request
  that produced it.

  WHAT THIS IS FOR. The four original matrices assert that a LINE is present, absent, ordered or
  counted, and that is the right instrument for the questions they ask -- each is about one decision
  the post makes. It is the wrong instrument for two other questions:

    "is the file CORRECT" -- does every move Fusion asked for arrive, at the coordinate it asked for,
    at a feed it is allowed to have, spelled in a way the target firmware can parse;

    "is the file WELL FORMED as a program" -- does the whole thing read, top to bottom, like a
    program a CNC operator would run: preamble before motion, origin before coordinates, spindle
    before cutting, retract before traverse, end after everything.

  Both need the file PARSED rather than matched, because both are claims about relationships between
  blocks that are hundreds of lines apart and that no regex can express. So this module is the
  parser, the modal-state simulator and the dialect linter the two new matrices share; the matrices
  themselves stay what the other four are -- a register of cases.

  NOTHING HERE KNOWS ANYTHING ABOUT THE POST. It knows g-code, and it knows the trace format
  `trace.cps` writes. A rule about what THIS post should emit belongs in a case, not in here.
*/

// ---------------------------------------------------------------------------------------------
// The trace side: what the kernel asked for.
// ---------------------------------------------------------------------------------------------

// One record per line, space separated, numbers at six decimals -- see trace.cps.
function parseTrace(text) {
  const out = { unit: 'mm', sectionCount: 0, sections: [], events: [] };
  let section = -1;

  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const f = line.split(' ');
    const kind = f[0];

    switch (kind) {
      case 'UNIT':     out.unit = f[1]; break;
      case 'SECTIONS': out.sectionCount = Number(f[1]); break;
      case 'SECTION': {
        section = Number(f[1]);
        const s = { index: section };
        for (let i = 2; i < f.length; i++) {
          const eq = f[i].indexOf('=');
          if (eq < 0) continue;
          const k = f[i].slice(0, eq);
          // `op=` is free text and is always last, so it takes the whole tail.
          s[k] = (k === 'op') ? f.slice(i).join(' ').slice(3) : f[i].slice(eq + 1);
          if (k === 'op') { i = f.length; }
        }
        s.tool = Number(s.tool); s.offset = Number(s.offset);
        s.jet = s.jet === '1'; s.multiaxis = s.multiaxis === '1'; s.cw = s.cw === '1';
        s.rpm = parseFloat(s.rpm); s.zmin = parseFloat(s.zmin); s.zmax = parseFloat(s.zmax);
        out.sections.push(s);
        break;
      }
      case 'R': out.events.push({ kind:'R', section, x:+f[1], y:+f[2], z:+f[3] }); break;
      case 'L': out.events.push({ kind:'L', section, x:+f[1], y:+f[2], z:+f[3], f:+f[4] }); break;
      case 'C': out.events.push({ kind:'C', section, dir:+f[1], cx:+f[2], cy:+f[3], cz:+f[4],
                                  x:+f[5], y:+f[6], z:+f[7], f:+f[8], plane:f[9] }); break;
      case 'R5': case 'L5':
        out.events.push({ kind, section, x:+f[1], y:+f[2], z:+f[3] }); break;
      case 'CYCLE':   out.events.push({ kind:'CYCLE', section, cycle:f[1], x:+f[2], y:+f[3], z:+f[4],
                                        handling:f[5] }); break;
      case 'POWER':   out.events.push({ kind:'POWER', section, on:f[1] === '1' }); break;
      case 'SPEED':   out.events.push({ kind:'SPEED', section, rpm:parseFloat(f[1]) }); break;
      case 'DWELL':   out.events.push({ kind:'DWELL', section, seconds:parseFloat(f[1]) }); break;
      case 'CMD':     out.events.push({ kind:'CMD', section, id:f[1] }); break;
      case 'RCOMP':   out.events.push({ kind:'RCOMP', section, mode:Number(f[1]) }); break;
      case 'MOVEMENT':out.events.push({ kind:'MOVEMENT', section, id:Number(f[1]) }); break;
      case 'PASSTHROUGH': out.events.push({ kind:'PASSTHROUGH', section, text:f.slice(1).join(' ') }); break;
      case 'COMMENT': out.events.push({ kind:'COMMENT', section, text:f.slice(1).join(' ') }); break;
      case 'SECTIONEND': out.events.push({ kind:'SECTIONEND', section }); break;
      case 'END':     out.events.push({ kind:'END', section }); break;
    }
  }
  return out;
}

// The moves the kernel asked to be CUT, in order. Rapids are excluded because the post is entitled
// to split, reorder and re-time them (rapidMovements() emits one block per axis); a cut is not.
const requestedCuts = t => t.events.filter(e => e.kind === 'L' || e.kind === 'C');

// ---------------------------------------------------------------------------------------------
// The g-code side: parse.
// ---------------------------------------------------------------------------------------------

// A comment is not a block, and reading it as one is how a "( X Min: -80)" becomes an X word. GRBL
// comments are parenthesised and cannot nest -- writeCommentLine() strips inner parentheses for
// exactly that reason -- and every other dialect uses a semicolon to end of line.
function stripComment(raw, grbl) {
  if (grbl) {
    let out = '', depth = 0, comment = '';
    for (const ch of raw) {
      if (ch === '(') { depth++; continue; }
      if (ch === ')') { if (depth > 0) depth--; continue; }
      if (depth > 0) comment += ch; else out += ch;
    }
    return { code: out, comment, opened: depth > 0 };
  }
  const i = raw.indexOf(';');
  return i < 0 ? { code: raw, comment: '', opened: false }
               : { code: raw.slice(0, i), comment: raw.slice(i + 1), opened: false };
}

// Words, and what would not tokenize. A g-code word is a letter and a number; anything else in a
// block is either a message the dialect allows (M0/M117/M291 carry text) or a defect.
function tokenize(code) {
  const words = [];
  let rest = '', restStart = -1, i = 0;
  while (i < code.length) {
    const ch = code[i];
    if (ch === ' ' || ch === '\t' || ch === '\r') { i++; continue; }
    if (ch >= 'A' && ch <= 'Z') {
      const m = /^[-+]?(?:\d+\.?\d*|\.\d+)/.exec(code.slice(i + 1));
      if (m) { words.push({ letter: ch, value: parseFloat(m[0]), raw: m[0] }); i += 1 + m[0].length; continue; }
    }
    if (restStart < 0) restStart = i;
    rest += ch; i++;
  }
  // THE TAIL IS RETURNED AS IT WAS WRITTEN, not as the characters that failed to tokenize. Where the
  // tail is a message -- M0/M117/M291 -- a reader has to be able to match the words in it, and a
  // whitespace-stripped "TurnON5000RPM" matches nothing an operator would search for.
  return { words, rest: restStart < 0 ? '' : code.slice(restStart).trim(), restStart };
}

/**
  Parse an emitted file into lines. Each line is one of:
    {kind:'blank'}
    {kind:'comment', comment}
    {kind:'block', words, rest, n, message}
  `rest` is what did not tokenize -- empty for a well-formed block. `message` is set where the
  dialect legitimately carries free text after the code (M0/M117/M291), so `rest` there is expected.
*/
function parseGcode(text, firmware) {
  const grbl = firmware === 'Grbl';
  const lines = [];
  const src = text.split(/\r?\n/);

  for (let i = 0; i < src.length; i++) {
    const raw = src[i];
    const rec = { i: i + 1, raw };
    if (!raw.trim()) { rec.kind = 'blank'; lines.push(rec); continue; }

    const c = stripComment(raw, grbl);
    rec.comment = c.comment;
    rec.unterminatedComment = c.opened;
    const code = c.code.trim();
    if (!code) { rec.kind = 'comment'; lines.push(rec); continue; }

    rec.kind = 'block';

    // GRBL's homing command. `$` is not a word letter and $H takes no line number, so it is read
    // here rather than left to fail tokenizing -- PRO29 is the case that says why it takes none.
    if (/^\$[A-Z]+$/.test(code)) {
      rec.words = []; rec.rest = ''; rec.codePart = code; rec.dollar = code; lines.push(rec); continue;
    }

    // G28 IS THE ONE BLOCK WHERE A BARE AXIS LETTER IS LEGAL -- "G28 X" means home X, and the letter
    // carries no value at all. Parsed here rather than in tokenize(), because a letter with no number
    // ANYWHERE ELSE is the defect the linter is looking for, and "M0 Attach ZProbe" would become the
    // words A, t, c, h if valueless letters were general.
    const g28 = /^(N(\d+)\s*)?G28((?:\s*[XYZ])*)\s*$/.exec(code);
    if (g28) {
      rec.words = [];
      if (g28[2] !== undefined) { rec.words.push({ letter:'N', value:Number(g28[2]), raw:g28[2] }); rec.n = Number(g28[2]); }
      rec.words.push({ letter:'G', value:28, raw:'28' });
      for (const a of (g28[3] || '').replace(/\s+/g, '')) rec.words.push({ letter:a, value:undefined, raw:'', flag:true });
      rec.rest = ''; rec.code = code; rec.codePart = code;
      lines.push(rec); continue;
    }

    const t = tokenize(code);
    rec.words = t.words;
    rec.rest = t.rest;
    rec.code = code;
    // What a character-level check may read. Where a block carries a message, the message is text
    // and not g-code -- lower case, quotes and parentheses are all legal inside it -- so the checks
    // that are about SPELLING stop where the message starts.
    rec.codePart = code;
    if (t.words.length && t.words[0].letter === 'N') { rec.n = t.words[0].value; }

    // M0 with a message (Marlin/RepRap dialects), M117 display, M291 with quoted parameters. The
    // text after them is not code and must not be read as words.
    const code0 = rec.words.filter(w => w.letter === 'M')[0];
    if (code0 && (code0.value === 0 || code0.value === 117 || code0.value === 291) && t.rest) {
      rec.message = t.rest;
      rec.rest = '';
      if (t.restStart >= 0) rec.codePart = code.slice(0, t.restStart);
    }
    lines.push(rec);
  }
  return lines;
}

const blocks = lines => lines.filter(l => l.kind === 'block');
const wordOf = (b, letter) => { const w = (b.words || []).filter(x => x.letter === letter); return w.length ? w[w.length - 1] : undefined; };
const has = (b, letter, value) => (b.words || []).some(w => w.letter === letter && (value === undefined || w.value === value));
const gWords = b => (b.words || []).filter(w => w.letter === 'G').map(w => w.value);
const mWords = b => (b.words || []).filter(w => w.letter === 'M').map(w => w.value);
const blockText = b => (b.words || []).map(w => w.letter + w.raw).join(' ');

// ---------------------------------------------------------------------------------------------
// The g-code side: simulate.
// ---------------------------------------------------------------------------------------------

/**
  Walk the blocks holding the modal state a controller would hold, and report one record per motion.

  UNDEFINED MEANS UNKNOWN, NOT ZERO, and that distinction is the whole reason this is a simulator
  rather than a scan. Three things make the tool's WORK-frame position unknowable from the file: a
  G53 move (its work value needs the WCS offset, which a runtime probe establishes), a G38.2 (it
  stops where it touches), and a homing command. A claim that would need one of those is reported as
  unknown rather than guessed -- the post's own noteCurrentPosition() comment states the same limit
  for the same reason.

  A G10 L20 / G92 RE-DEFINES the frame, so it makes the position KNOWN again: the block says, in so
  many words, that the tool is standing at the coordinate it names.
*/
function simulate(lines) {
  const st = { g: undefined, x: undefined, y: undefined, z: undefined, f: undefined,
               abs: true, wcs: undefined, plane: undefined, unit: undefined };
  const motions = [];

  for (const b of blocks(lines)) {
    const gs = gWords(b), ms = mWords(b);

    if (b.dollar) { st.x = st.y = st.z = undefined; motions.push({ line:b.i, kind:'home', block:b }); continue; }
    if (gs.indexOf(90) >= 0) st.abs = true;
    if (gs.indexOf(91) >= 0) st.abs = false;
    if (gs.indexOf(20) >= 0) st.unit = 'in';
    if (gs.indexOf(21) >= 0) st.unit = 'mm';
    for (const p of [17, 18, 19]) if (gs.indexOf(p) >= 0) st.plane = p;
    for (let w = 54; w <= 59; w++) if (gs.indexOf(w) >= 0) st.wcs = w;
    for (const w of [59.1, 59.2, 59.3]) if (gs.indexOf(w) >= 0) st.wcs = w;

    // G28 on Marlin homes the axes it names; G28 with no axis word homes all.
    if (gs.indexOf(28) >= 0) {
      const axes = ['X','Y','Z'].filter(a => has(b, a));
      for (const a of (axes.length ? axes : ['X','Y','Z'])) st[a.toLowerCase()] = undefined;
      motions.push({ line:b.i, kind:'home', block:b });
      continue;
    }

    // G10 L20 -- set the named register so the CURRENT position reads as the given coordinate.
    if (gs.indexOf(10) >= 0 && has(b, 'L', 20)) {
      const p = wordOf(b, 'P');
      const rec = { line:b.i, kind:'setOrigin', register:p ? p.value : undefined, block:b };
      for (const a of ['X','Y','Z']) {
        const w = wordOf(b, a);
        if (w) { rec[a.toLowerCase()] = w.value; st[a.toLowerCase()] = w.value; }
      }
      motions.push(rec);
      continue;
    }
    // G92 is Marlin's form of the same statement.
    if (gs.indexOf(92) >= 0) {
      const rec = { line:b.i, kind:'setOrigin', register:undefined, block:b };
      for (const a of ['X','Y','Z']) {
        const w = wordOf(b, a);
        if (w) { rec[a.toLowerCase()] = w.value; st[a.toLowerCase()] = w.value; }
      }
      motions.push(rec);
      continue;
    }

    if (gs.some(g => g === 38.2 || g === 38.3 || g === 38.4 || g === 38.5)) {
      const rec = { line:b.i, kind:'probe', block:b, f: wordOf(b,'F') ? wordOf(b,'F').value : st.f };
      for (const a of ['X','Y','Z']) { const w = wordOf(b, a); if (w) rec[a.toLowerCase() + 'Target'] = w.value; }
      // The probe stops where it touches, so every axis it searched along is unknown afterwards.
      for (const a of ['X','Y','Z']) if (wordOf(b, a)) st[a.toLowerCase()] = undefined;
      motions.push(rec);
      continue;
    }

    // G4 dwell, and any block with no motion word and no axis word, is not a motion.
    const machine = gs.indexOf(53) >= 0;
    const motionG = gs.filter(g => g === 0 || g === 1 || g === 2 || g === 3);
    if (motionG.length) st.g = motionG[motionG.length - 1];
    const axisWords = ['X','Y','Z'].filter(a => has(b, a));
    if (!axisWords.length) {
      if (ms.length || gs.length) motions.push({ line:b.i, kind:'other', block:b, g:st.g, machine });
      continue;
    }
    if (gs.indexOf(4) >= 0) { motions.push({ line:b.i, kind:'other', block:b }); continue; }

    const fw = wordOf(b, 'F');
    if (fw) st.f = fw.value;

    const rec = { line:b.i, kind: machine ? 'machine' : 'move', g: st.g, machine,
                  f: st.f, fWord: fw ? fw.value : undefined, block:b, axes: axisWords };
    for (const a of ['X','Y','Z']) {
      const w = wordOf(b, a);
      rec[a.toLowerCase() + 'Word'] = w ? w.value : undefined;
    }
    for (const a of ['I','J','K']) {
      const w = wordOf(b, a);
      if (w) rec[a.toLowerCase()] = w.value;
    }

    if (machine) {
      // A machine-frame move has no work-frame value -- see the note above.
      for (const a of axisWords) st[a.toLowerCase()] = undefined;
    } else {
      // The start of this move, for arc-centre and direction claims.
      rec.from = { x: st.x, y: st.y, z: st.z };
      for (const a of axisWords) {
        const w = wordOf(b, a);
        st[a.toLowerCase()] = st.abs ? w.value : (st[a.toLowerCase()] === undefined ? undefined : st[a.toLowerCase()] + w.value);
      }
      rec.to = { x: st.x, y: st.y, z: st.z };
    }
    rec.plane = st.plane;
    rec.wcs = st.wcs;
    motions.push(rec);
  }
  return motions;
}

// The cuts the file actually performs: work-frame G1/G2/G3, in order. Machine-frame blocks and the
// probe are excluded -- neither is a cut, and neither has a work-frame endpoint to compare.
const emittedCuts = motions => motions.filter(m => m.kind === 'move' && (m.g === 1 || m.g === 2 || m.g === 3));
const emittedRapids = motions => motions.filter(m => m.kind === 'move' && m.g === 0);

// ---------------------------------------------------------------------------------------------
// The dialect linter.
// ---------------------------------------------------------------------------------------------

// Modal groups a controller will reject two members of in one block. Only the ones this post can
// emit are listed: a table of everything RS-274 defines would be asserting about code that cannot
// be reached from here.
const MODAL_GROUPS = [
  { name:'motion',   codes:[0, 1, 2, 3, 38.2, 80] },
  { name:'plane',    codes:[17, 18, 19] },
  { name:'distance', codes:[90, 91] },
  { name:'feedmode', codes:[93, 94] },
  { name:'units',    codes:[20, 21] },
  { name:'wcs',      codes:[54, 55, 56, 57, 58, 59, 59.1, 59.2, 59.3] },
];

/**
  Every rule here is about the FILE as a text a controller has to parse, never about what the post
  decided -- so a lint failure is a defect on any firmware, under any property set.

  `decimals` is the output precision the post's own formats declare: 3 in mm, 4 in inch. A coordinate
  with more than that is a formatter that was bypassed.
*/
function lint(lines, firmware, opts) {
  const o = opts || {};
  const decimals = o.decimals === undefined ? 3 : o.decimals;
  const grbl = firmware === 'Grbl';
  const bad = [];
  const add = (l, why) => bad.push(`${l.i}: ${why}  |  ${l.raw.trim().slice(0, 90)}`);

  for (const l of lines) {
    if (l.kind === 'blank') continue;

    if (l.unterminatedComment) add(l, 'a comment is opened and never closed');

    if (l.kind === 'comment') {
      if (grbl) {
        if (!/^\s*\(.*\)\s*$/.test(l.raw)) add(l, 'a GRBL comment line is not wrapped in one pair of parentheses');
        if (/\(/.test(l.comment)) add(l, 'a nested "(" -- a GRBL comment ends at the first ")"');
      } else {
        if (!/^\s*;/.test(l.raw)) add(l, 'a comment line off GRBL does not start with ";"');
        if (/[()]/.test(l.raw)) add(l, 'a parenthesis comment on a dialect that reads ";"');
      }
      continue;
    }

    // ---- blocks ----
    // Every character-level rule below reads `codePart`: the block with its comment AND its message
    // removed. An operator prompt is free text -- lower case, quotes and parentheses are all legal
    // inside one -- and none of these rules is about what the message says.
    const cp = l.codePart === undefined ? '' : l.codePart;
    if (grbl && /;/.test(cp)) add(l, 'a ";" on GRBL, which has no semicolon comment');
    if (!grbl && /[()]/.test(cp)) add(l, 'a parenthesis in a block on a dialect that reads ";"');
    if (l.rest) add(l, `does not tokenize as g-code: "${l.rest}"`);
    if (/%/.test(cp)) add(l, 'a "%" -- stock Grbl answers error:1 and nothing here writes one');
    if (/[a-z]/.test(cp)) add(l, 'a lower-case word letter');
    if (/\b(NaN|undefined|Infinity)\b/.test(l.raw)) add(l, 'a non-number reached the file');
    if (/[0-9][eE][-+]?[0-9]/.test(cp)) add(l, 'an exponent in a coordinate');

    if (!l.words.length && !l.dollar) { add(l, 'a block with no words'); continue; }
    if (l.words.length === 1 && l.words[0].letter === 'N') add(l, 'a line number with no block after it');

    for (const w of l.words) {
      // A flag word is an axis named in a G28 and nothing else -- parseGcode() will not produce one
      // anywhere a value is required.
      if (w.flag) continue;
      if (w.raw === '') { add(l, `word "${w.letter}" carries no number`); continue; }
      if ('XYZIJKR'.indexOf(w.letter) >= 0) {
        const dot = w.raw.indexOf('.');
        if (dot >= 0 && w.raw.length - dot - 1 > decimals) {
          add(l, `${w.letter}${w.raw} carries more than ${decimals} decimals`);
        }
      }
      if (w.letter === 'F' && w.value <= 0) add(l, `a feedrate of ${w.raw}`);
    }

    const gs = gWords(l);
    for (const grp of MODAL_GROUPS) {
      const hit = gs.filter(g => grp.codes.indexOf(g) >= 0);
      if (hit.length > 1) add(l, `two ${grp.name} codes in one block: G${hit.join(' G')}`);
    }

    // An arc needs a centre offset; a bare G2 is a syntax error on every controller here.
    if (gs.indexOf(2) >= 0 || gs.indexOf(3) >= 0) {
      if (!has(l, 'I') && !has(l, 'J') && !has(l, 'K') && !has(l, 'R')) {
        add(l, 'an arc with no I/J/K centre offset');
      }
    }
  }
  return bad;
}

// ---------------------------------------------------------------------------------------------
// Small helpers the cases read with.
// ---------------------------------------------------------------------------------------------

const near = (a, b, tol) => a !== undefined && b !== undefined && Math.abs(a - b) <= (tol === undefined ? 0.0011 : tol);
const countOf = (t, re) => (t.match(re) || []).length;

// The index of the first line matching a pattern, or -1 -- for claims about where a block sits.
const lineOf = (lines, re) => { for (const l of lines) if (re.test(l.raw)) return l.i; return -1; };

module.exports = {
  parseTrace, requestedCuts,
  parseGcode, blocks, wordOf, has, gWords, mWords, blockText,
  simulate, emittedCuts, emittedRapids,
  lint, MODAL_GROUPS,
  near, countOf, lineOf,
};
