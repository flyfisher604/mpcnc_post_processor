/**
  unwrap-comments.js -- rejoin the comment lines the post's wrapCommentText() split, so a case can
  match a warning's wording without knowing where the line breaks fell.

  The post wraps a long comment into lines of at most 100 characters; each continuation line takes
  the first line's leading spaces plus three. That indent is the only mark a continuation carries,
  so this is the post's convention read back, and belongs beside the matrices rather than in
  gcode-model.js, which knows g-code and nothing about this post.

  Matrices that ask what the FILE is -- its lines, their lengths, their order as a program -- read it
  raw. Only the matrices that match prose use this.
*/

// "(text)" on GRBL, ";text" elsewhere. Returns the text between the markers, or null.
function commentText(line) {
  const l = line.replace(/\r$/, '');
  if (l.startsWith('(') && l.endsWith(')')) return l.slice(1, -1);
  if (l.startsWith(';')) return l.slice(1);
  return null;
}

const leadOf = t => t.match(/^ */)[0].length;

function unwrapComments(text) {
  const out = [];
  let base = null;   // the leading-space count of the comment a continuation would extend
  for (const line of text.split('\n')) {
    const c = commentText(line);
    if (c !== null && base !== null && leadOf(c) === base + 3 && /\S/.test(c)) {
      const prev = out.pop();
      const cr = prev.endsWith('\r') ? '\r' : '';
      const body = prev.replace(/\r$/, '');
      const joined = body.startsWith('(')
        ? body.slice(0, -1) + ' ' + c.trimStart() + ')'
        : body + ' ' + c.trimStart();
      out.push(joined + cr);
      continue;
    }
    out.push(line);
    base = (c !== null) ? leadOf(c) : null;
  }
  return out.join('\n');
}

module.exports = { unwrapComments };
