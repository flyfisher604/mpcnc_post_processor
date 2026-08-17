/**
  census.cps -- report what a job actually contains, before posting it.

  A .cnc file's contents are not visible: the format is binary, and running the real post
  over it answers what the post emits rather than what it was given. This asks the kernel
  instead, and it is how "no shipped .cnc file exercises a WCS change" was settled --
  findings.md §4's `utility` method paragraph.

  Run it as if it were the post:
    post.exe --noeditor --nointeraction --noheader --noprogress census.cps <file.cnc> out.txt

  It writes one CENSUS line per job to the log as a warning, so it survives at any
  verbosity, and skips every section rather than emitting motion.
*/
description = "Job census -- sections, work offsets and tools";
vendor = "MPCNC post tooling";
extension = "txt";
setCodePage("ascii");
capabilities = CAPABILITY_MILLING | CAPABILITY_JET;

function onOpen() {
  var offsets = {}, tools = {}, sequence = [];

  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    // workOffset 0 is the UNSET case, which the post aliases to WCS 1 -- so a census of 0s
    // is a job that exercises the alias, not one with no offset.
    sequence.push(section.workOffset);
    offsets[section.workOffset] = true;
    tools[section.getTool().number] = true;
  }

  var distinctOffsets = [], distinctTools = [];
  for (var o in offsets) { distinctOffsets.push(o); }
  for (var t in tools) { distinctTools.push(t); }

  warning("CENSUS sections=" + getNumberOfSections() +
          " offsets=" + distinctOffsets.sort().join("/") +
          " tools=" + distinctTools.sort().join("/") +
          " seq=" + sequence.join(","));
}

function onSection() { skipRemainingSection(); }
function onSectionEnd() {}
function onClose() {}
