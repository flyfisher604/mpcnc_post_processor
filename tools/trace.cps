/**
  trace.cps -- what the KERNEL asked the post to emit, in the order it asked.

  `census.cps` answers what a job contains; this answers what a job REQUESTS. It is the oracle the
  `CorrectGcode` category is written against: post the same .cnc twice -- once through the real post
  and once through this -- and the emitted g-code can be held to the toolpath Fusion delivered rather
  than to a regex somebody wrote after reading the output.

  WHY IT IS NOT A REGEX. Every other matrix asserts that a particular line is present. None of them
  can say that the 1067 cutting moves of `bore.cnc` are the 1067 moves Fusion asked for, at the
  coordinates it asked for, in that order -- which is the one claim an operator actually needs and the
  one no amount of pattern matching reaches.

  THE KERNEL CONFIGURATION BELOW IS COPIED FROM THE POST AND MUST STAY COPIED. Arc fitting, chord
  length, sweep splitting and helical linearization are decisions the KERNEL makes from these globals
  before either post sees a callback. A trace with a different `maximumCircularSweep` is handed a
  different stream and every comparison built on it is meaningless -- so these twelve lines are the
  load-bearing part of this file, not the callbacks.

  Run it as if it were the post:
    post.exe --noeditor --nointeraction --noheader --noprogress trace.cps <file.cnc> out.trace

  One record per line, space separated, and every number is fixed to six decimals so a reader may
  compare against a 3-decimal g-code coordinate without parsing locale-dependent output.
*/
description = "Toolpath trace -- the motion stream the kernel delivers";
vendor = "MPCNC post tooling";

extension = "trace";
setCodePage("ascii");

// ---- copied from MPCNC_v4.0_Beta3.cps, and the whole instrument rests on it -----------------
capabilities = CAPABILITY_MILLING | CAPABILITY_JET;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined;

wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"All firmware", format:"G", range:[54, 59]},
    {name:"Marlin/RepRap", format:"G59.", range:[1, 3]}
  ]
};
// ---------------------------------------------------------------------------------------------

var sectionComment;
var sectionIndex = -1;

// Six decimals, and never exponential: a reader compares these against g-code rounded to three, so
// the trace has to be finer than the file without being in a format the file could not carry.
function n(v) {
  if (v == undefined) { return "?"; }
  if (typeof v != "number") { return String(v); }
  if (isNaN(v)) { return "NaN"; }
  return v.toFixed(6);
}

function rec() {
  var out = [];
  for (var i = 0; i < arguments.length; ++i) { out.push(arguments[i]); }
  writeln(out.join(" "));
}

// A value that may contain a space would split the record, so anything free-form is the LAST field
// of its record and every reader takes the tail.
function tail(v) {
  return (v == undefined) ? "" : String(v).replace(/[\r\n]+/g, " ");
}

function onOpen() {
  rec("UNIT", (unit == IN) ? "in" : "mm");
  rec("SECTIONS", getNumberOfSections());
}

function onParameter(name, value) {
  if (name == "operation-comment") { sectionComment = value; }
}

function onSection() {
  ++sectionIndex;

  var t = currentSection.getTool();
  var kind = "other";
  if (currentSection.type == TYPE_MILLING) { kind = "milling"; }
  else if (currentSection.type == TYPE_JET) { kind = "jet"; }

  var jetMode = "-";
  if (currentSection.type == TYPE_JET) {
    switch (currentSection.jetMode) {
      case JET_MODE_THROUGH:  jetMode = "Through";  break;
      case JET_MODE_ETCHING:  jetMode = "Etching";  break;
      case JET_MODE_VAPORIZE: jetMode = "Vaporize"; break;
      default:                jetMode = "Unknown";  break;
    }
  }

  // The orientation the post's own guard reads. Recorded on every section so a job that is upright
  // and a job that is not are distinguishable from the trace alone.
  var fwd = (currentSection.workPlane == undefined) ? undefined : currentSection.workPlane.forward;
  var axis = (fwd == undefined) ? "?" : (n(fwd.x) + "," + n(fwd.y) + "," + n(fwd.z));

  rec("SECTION", sectionIndex,
      "type=" + kind,
      "tool=" + t.number,
      "jet=" + (t.isJetTool() ? 1 : 0),
      "offset=" + currentSection.workOffset,
      "multiaxis=" + (currentSection.isMultiAxis() ? 1 : 0),
      "axis=" + axis,
      "jetmode=" + jetMode,
      "rpm=" + n(t.spindleRPM),
      "cw=" + (t.clockwise ? 1 : 0),
      "strategy=" + (hasParameter("operation-strategy") ? getParameter("operation-strategy") : "-"),
      "zmin=" + n(currentSection.getGlobalZRange().getMinimum()),
      "zmax=" + n(currentSection.getGlobalZRange().getMaximum()),
      "op=" + tail(sectionComment));
}

function onSectionEnd() {
  rec("SECTIONEND", sectionIndex);
  sectionComment = undefined;
}

function onRapid(x, y, z) { rec("R", n(x), n(y), n(z)); }

function onLinear(x, y, z, feed) { rec("L", n(x), n(y), n(z), n(feed)); }

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  var plane = "?";
  switch (getCircularPlane()) {
    case PLANE_XY: plane = "XY"; break;
    case PLANE_ZX: plane = "ZX"; break;
    case PLANE_YZ: plane = "YZ"; break;
  }
  rec("C", clockwise ? 2 : 3, n(cx), n(cy), n(cz), n(x), n(y), n(z), n(feed), plane);
}

// Recorded, not refused: a trace of a job this post rejects is how the refusal is shown to be about
// the job's shape rather than about the harness failing to read it.
function onRapid5D(x, y, z, a, b, c) { rec("R5", n(x), n(y), n(z), n(a), n(b), n(c)); }
function onLinear5D(x, y, z, a, b, c, feed) { rec("L5", n(x), n(y), n(z), n(a), n(b), n(c), n(feed)); }

// Same test the post uses, and for the same reason -- either signal alone can miss one.
function isProbeOperation() {
  if (hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe")) {
    return true;
  }
  return (typeof cycleType != "undefined") && (String(cycleType).indexOf("probing") == 0);
}

// EXPANDED, exactly as the post expands it. None of the supported firmwares has canned cycles, so
// what Fusion "requests" for a drilled hole IS the expansion -- and a trace that recorded the cycle
// point instead would be comparing a file of G0/G1 moves against a list of holes.
function onCyclePoint(x, y, z) {
  rec("CYCLE", String(cycleType), n(x), n(y), n(z), isProbeOperation() ? "probe" : "expand");
  if (isProbeOperation()) { return; }
  expandCyclePoint(x, y, z);
}

function onPower(power) { rec("POWER", power ? 1 : 0); }

function onSpindleSpeed(speed) { rec("SPEED", n(speed)); }

function onDwell(seconds) { rec("DWELL", n(seconds)); }

function onCommand(command) { rec("CMD", getCommandStringId(command)); }

function onMovement(movement) { rec("MOVEMENT", movement); }

function onRadiusCompensation() { rec("RCOMP", radiusCompensation); }

function onPassThrough(value) { rec("PASSTHROUGH", tail(value)); }

function onComment(message) { rec("COMMENT", tail(message)); }

function onClose() { rec("END"); }
