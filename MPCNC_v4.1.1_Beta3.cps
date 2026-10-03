/*
**
Version 4.1.1 (Beta 3)

MPCNC posts processor for milling and laser/plasma cutting.

Changed Aug 22, 2026
**

Key to the comments
  TWIN #n        A warning raised twice: in the post dialog by validateJob(), and in the g-code
                 file where the job reaches it. Both halves carry the same number; change one, change
                 the other.
  TWIN: here     Both halves come from this one statement.
  TWIN: none     A file-only warning, and why the dialog cannot or should not carry it.
  CR-11, PV-9    A finding in docs/findings.md; git log --grep=<id> finds the commit.
  W25b           A test case in docs/findings.md, sections 4 and 5.
  machine frame  The machine's own coordinates, set by homing and addressed with G53; never a WCS.
  establish      Set a part's origin, X0 Y0 Z0, by probing, jogging or taking the current position.
  hand-over      The point at a tool change where the post stops and the operator, or a sender's
                 macro, fits the tool.
*/

description = "v4.1.1 (Beta 3) MPCNC Milling/Laser for Marlin, Grbl, FluidNC, RepRap";
vendor = "flyfisher604";
vendorUrl = "https://github.com/flyfisher604/mpcnc_post_processor";
longDescription = "MPCNC post processor for Fusion: milling and laser on Marlin, GRBL, FluidNC and RepRapFirmware, with feed scaling for a slow Z, a machine-frame travel height, multi-part jobs and tool-change hand-over. Beta: review the g-code before running it.";

// Internal properties
legal = "Copyright (C) 2019 - 2026 Don Gamble.";
certificationLevel = 2;
minimumRevision = 45917;

extension = "gcode";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_JET;
tolerance = spatial(0.002, MM);

// Arc support variables
minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180); // split arcs >180 deg: a full circle posts as two arcs, since some firmware mishandles start == end
allowHelicalMoves = false;
allowedCircularPlanes = undefined;

// Fusion's UI shows each section's work offset as its G-code, not a bare index. useZeroOffset is inert:
// only Autodesk's validateCommonParameters() (include_files/commonFunctions.cpi) reads it, to refuse a job
// mixing offset 0 with a higher one, as their 0 emits no G5x. This post's 0 is G54, so only 0 beside 1 is
// ambiguous, and mixedDefaultAndExplicitWcs() warns about it.
wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"All firmware", format:"G", range:[54, 59]},        // G54-G59 (raw offset 1-6)
    {name:"Marlin/RepRap", format:"G59.", range:[1, 3]}       // G59.1-G59.3 (raw offset 7-9)
  ]
};

machineMode = undefined; //TYPE_MILLING, TYPE_JET

var eFirmware = {
    MARLIN: "Marlin",  // Marlin 2.x
    GRBL: "Grbl",      // Grbl 1.1
    REPRAP: "RepRap",
  };

var fw;   // set from "CNC Firmware" by onOpen(), before anything reads it

// Priority order; compared by indexOf()
const commentLevels = ["Off", "Important", "Info","Debug"];
var eComment = {
    Off: "Off",
    Important: "Important",
    Info: "Info",
    Debug: "Debug",
};

var eCoolant = {
    Off: "Off",
    Flood: "Flood",
    Mist: "Mist",
    ThroughTool: "ThroughTool",
    Air: "Air",
    AirThroughTool: "AirThroughTool",
    Suction: "Suction",
    FloodMist: "Flood and Mist",
    FloodThroughTool: "Flood and ThroughTool",
    };

// Fusion's numeric tool.coolant -> coolant name; the index is the F360 constant (0 COOLANT_DISABLED, 1
// FLOOD, 2 MIST, 3 THROUGH_TOOL, 4 AIR, 5 AIR_THROUGH_TOOL, 6 SUCTION, 7 FLOOD_MIST, 8 FLOOD_THROUGH_TOOL),
// so never sort it. Built from eCoolant at load time, so eCoolant must be declared above it.
const coolantLevels = [eCoolant.Off, eCoolant.Flood, eCoolant.Mist, eCoolant.ThroughTool,
                       eCoolant.Air, eCoolant.AirThroughTool, eCoolant.Suction, eCoolant.FloodMist,
                       eCoolant.FloodThroughTool];

// Dialog groups (Post Processor Guide 5.1.5). A property's `group:` is a key here: `order` places the
// group, `title` is what the operator reads. Keep any existing object and add keys one at a time --
// assigning a whole literal would discard it.
if (typeof groupDefinitions != "object") {
  groupDefinitions = {};
}
groupDefinitions.job        = {title: "1 - Job", order: 100};
groupDefinitions.feeds      = {title: "2 - Feeds and Speeds", order: 110};
groupDefinitions.mapRapids  = {title: "3 - Map G1s to Rapids - disable when using full license", order: 120};
groupDefinitions.machine    = {title: "4 - Machine Frame - homing, travel Z and end park", order: 130};
groupDefinitions.probe      = {title: "5 - Part Origins - how each part's X0 Y0 Z0 is established", order: 150};
groupDefinitions.toolChange = {title: "6 - Tool Changes - the post hands over, it changes no tool", order: 160};
groupDefinitions.include    = {title: "7 - External Include Files", order: 170};
groupDefinitions.laser      = {title: "8 - Laser", order: 180};
groupDefinitions.coolant    = {title: "9 - Coolant", order: 190};
groupDefinitions.duet       = {title: "10 - Duet", order: 200};

// Each key is `<groupKey><Name>` and carries no sequence -- `order:` below does, 10-spaced. To insert a
// property mid-group, give it an `order:` between its neighbours and leave every key alone: a key is the
// identifier Fusion stores a user's setting under, so renaming one resets that setting to its default.
properties = {
  jobSelectedFirmware: {
    title      : "CNC Firmware",
    description: "Dialect of GCode to create.",
    group      : "job",
    order      : 10,
    type       : "enum",
    values: [
      { title: eFirmware.MARLIN, id: eFirmware.MARLIN},
      { title: eFirmware.GRBL, id: eFirmware.GRBL },
      { title: eFirmware.REPRAP, id: eFirmware.REPRAP }
    ],
    value: eFirmware.GRBL,
    scope: "post"
  },
  // A new key, not the old boolean's: a stored true/false is not an enum id. A saved setting falls back
  // to the default, which behaves as the boolean shipped.
  jobSpindleControl: {
    title      : "Spindle Control",
    description: "Who switches the router on. Prompt: no spindle code -- the post stops (M0) and asks. M3/M5: commanded, S carrying the RPM; on Marlin only a build with SPINDLE_FEATURE or LASER_FEATURE obeys it. Fan M106 and Pin M42: a relay on an output, on or off only, numbered by Pin/Fan # below; a GRBL job is refused.",
    group      : "job",
    order      : 20,
    type       : "enum",
    values: [
      { title: "Prompt the operator (M0)", id: "manual" },
      { title: "Spindle - M3 S{RPM}/M5", id: "M3" },
      { title: "Fan - M106 P{n} S255/S0", id: "M106" },
      { title: "Pin - M42 P{pin} S255/S0", id: "M42" }
    ],
    value: "manual",
    scope: "post"
  },
  // 25: it sits under Spindle Control, which reads it, without renumbering the rest of group 1.
  jobSpindlePinFan: {
    title      : "Spindle: Pin/Fan #",
    description: "The output number the Fan and Pin modes use. Fan: a fan index on Marlin, a fan number on RepRapFirmware. Pin: a board pin on Marlin, a GpOut port on RepRapFirmware. The numbering is your board's and the post cannot check it -- a wrong Marlin fan index fails silently and the router never starts.",
    group      : "job",
    order      : 25,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  jobCommentLevel: {
    title      : "Comment Level",
    description: "Detail of comments included.",
    group      : "job",
    order      : 30,
    type       : "enum",
    values: [
      { title: eComment.Off, id: eComment.Off },
      { title: eComment.Important, id: eComment.Important },
      { title: eComment.Info, id: eComment.Info },
      { title: eComment.Debug, id: eComment.Debug }
    ],
    value: eComment.Info,
    scope: "post"
  },
  jobUseArcs: {
    title      : "Use Arcs",
    description: "Use G2/G3 g-codes for circular movements.",
    group      : "job",
    order      : 40,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  // One field over three answers, not a boolean with two companion fields that did nothing while it was
  // off -- the default -- so the dialog asked for numbers no file would carry.
  //
  // A new key, because a stored true/false is not an enum id: a saved setting falls back to Off, what the
  // boolean shipped. See the note at the head of this object.
  jobSequenceNumbering: {
    title      : "Line #s",
    description: "Number every block, and by how much. Off emits no N words at all, which is what this post ships. The two on values differ only in the step: N10 N11 N12 for a sender that counts blocks one by one, N10 N20 N30 for one that leaves room to insert between them. Numbering always starts at N10, and the numbers restart at every file.",
    group      : "job",
    order      : 50,
    type       : "enum",
    values: [
      { title: "Off", id: "Off" },
      { title: "N10 N11 N12 ... step 1", id: "Step1" },
      { title: "N10 N20 N30 ... step 10", id: "Step10" }
    ],
    value      : "Off",
    scope      : "post"
  },
  jobSeparateWordsWithSpace: {
    title      : "Include Whitespace",
    description: "Put a space between words: G0 X10 Y10 rather than G0X10Y10.",
    group      : "job",
    order      : 80,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },

  feedsTravelSpeedXY: {
    title      : "Travel Speed X/Y",
    description: "Speed for travel movements in X and Y, in mm/min. Marlin and RepRap obey it. GRBL and FluidNC ignore it and travel at the axis maximum set in the controller, which only the controller can change.",
    group      : "feeds",
    order      : 10,
    type       : "integer",
    value      : 2500,
    scope      : "post"
  },
  feedsTravelSpeedZ: {
    title      : "Travel Speed Z",
    description: "Speed for travel movements in Z, in mm/min. Marlin and RepRap obey it. GRBL and FluidNC ignore it and travel at the axis maximum set in the controller, which only the controller can change.",
    group      : "feeds",
    order      : 20,
    type       : "integer",
    value      : 300,
    scope      : "post"
  },
  feedsEnforceFeedrate: {
    title      : "Enforce Feedrate",
    description: "Include a feedrate on every cutting move, not only where it changes.",
    group      : "feeds",
    order      : 30,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  feedsScaleFeedrate: {
    title      : "Scale Feedrate",
    description: "Slow Fusion's cut feedrates to the three limits below. Off: feedrates are emitted unchanged and those limits do nothing. Set them to your machine's real capability -- the defaults are generic, and a limit set too low slows every cut.",
    group      : "feeds",
    order      : 40,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  feedsMaxCutSpeedXY: {
    title      : "Max XY Cut Speed",
    description: "The fastest your machine may cut in X or Y, in mm/min. Read only when Scale Feedrate is on.",
    group      : "feeds",
    order      : 50,
    type       : "integer",
    value      : 900,
    scope      : "post"
  },
  feedsMaxCutSpeedZ: {
    title      : "Max Z Cut Speed",
    description: "The fastest your machine may cut in Z, in mm/min -- usually much slower than X or Y. Read only when Scale Feedrate is on.",
    group      : "feeds",
    order      : 60,
    type       : "integer",
    value      : 180,
    scope      : "post"
  },
  feedsMaxCutSpeedXYZ: {
    title      : "Max Toolpath Speed",
    description: "A cap on speed along the toolpath, in mm/min: a diagonal move can stay inside both axis limits and still be too fast. Read only when Scale Feedrate is on.",
    group      : "feeds",
    order      : 70,
    type       : "integer",
    value      : 1000,
    scope      : "post"
  },

  // One enabling control and no field of its own. Group 3 answers one question -- is the Personal edition
  // turning this job's rapids into cuts, and may the post turn them back? Its height is group 5's Safe Z,
  // one property read by both groups; the note above probeSafeZ says why that is one meaning.
  mapRapidsRestoreRapids: {
    title      : "Map G1s -> G0 Rapids",
    description: "Convert G1s back to G0 rapids where it is safe. Covers the three moves Fusion's Personal edition emits as cuts: horizontal moves at or above the Safe Z below, retracts and descents that stay above it, and each operation's first move.",
    group      : "mapRapids",
    order      : 10,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  // The one test hook in this file: group 3 is otherwise unreachable by an automated run, since a paid
  // licence delivers every rapid to onRapid() and isSafeToRapid() is never consulted. On, it makes
  // onRapid() forward rapids as feed moves, as the Personal edition delivers them.
  //
  // No "group" key, deliberately: writeAllProperties() skips it, so a normal job's dump is unchanged, and
  // "visible: false" keeps it out of the dialog -- Autodesk's idiom (Data/Posts/tormach.cps, post kernel
  // 5.388.0). Being absent from the dump, validateJob() announces it in the file and in Fusion instead.
  mapRapidsTestPersonalLicence: {
    title      : "TEST ONLY -- deliver rapids as feed moves",
    description: "FOR TESTING PURPOSES ONLY. DO NOT ENABLE.",
    type       : "boolean",
    value      : false,
    scope      : "post",
    visible    : false
  },

  machineHomedAxes: {
    title      : "Axes Homed and Trusted",
    description: "Which axes your machine homes to endstops. It homes nothing itself -- that is Home at Job Start below. Z is required by Machine Travel Z; X and Y by a multi-part job and by At End Park At = Machine X0 Y0. Your cutting Z0 always comes from the touch-off, never from here.",
    group      : "machine",
    order      : 10,
    type       : "enum",
    values: [
      { title: "None",    id: "None" },
      { title: "XY Only", id: "XY" },
      { title: "Z Only",  id: "Z" },
      { title: "XYZ",     id: "XYZ" }
    ],
    value: "None",
    scope: "post"
  },
  // Filling this is the opt-in, with no enum or boolean beside it: the machine Z reference exists when Z
  // is declared homed and this parses (fixedZEstablishedInFile()). It is in this group because it means
  // nothing without that homing declaration. A string, not a number: empty means no Z reference, and a
  // numeric property has no unset state -- every sentinel, 0 included, is a reachable height.
  machineTravelZ: {
    title      : "Machine Travel Z",
    description: "The height the tool holds while travelling -- an absolute machine coordinate in mm, often negative. Empty (default): the job has no fixed Z reference. Filled: a Z reference that does not move with stock thickness, which a multi-part job cannot post without. Needs Z declared homed above. Measure it once: home, jog clear of every clamp, and read Z off your sender. It belongs to the machine, not the job, and a wrong value sends the tool to a wrong height at travel speed.",
    group      : "machine",
    order      : 20,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  machineHomeAtStart: {
    title      : "Home at Job Start",
    description: "Whether this job homes the axes declared above. Off: no homing -- use the machine's current position, which is right if you homed at the controller. Home: home at job start. Pause, then Home: stop (M0) first so you can prepare the machine, then home.",
    group      : "machine",
    order      : 30,
    type       : "enum",
    values: [
      { title: "Off",                id: "Off" },
      { title: "Home",               id: "Home" },
      { title: "Pause, then Home",   id: "Pause & Home" }
    ],
    value: "Off",
    scope: "post"
  },

  machineParkAtEnd: {
    title      : "At End Park At",
    description: "Where the tool goes when the job ends. Off: leave it where the last cut finished. Work X0 Y0: the last operation's work origin -- on a multi-part job, whichever fixture Fusion cut last. Machine X0 Y0: the machine's homing corner, the same point for every job; needs X and Y declared homed, and on GRBL and RepRap also needs Home at Job Start on.",
    group      : "machine",
    order      : 50,
    type       : "enum",
    values: [
      { title: "Off",           id: "Off" },
      { title: "Work X0 Y0",    id: "Work" },
      { title: "Machine X0 Y0", id: "Machine" }
    ],
    value: "Work",
    scope: "post"
  },

  probeOnStart: {
    title      : "First WCS / Part",
    description: "How the first (or only) part's origin is set: from where the tool stands, from the stored work offset, or by jogging at a pause -- with Z0 probed or not. The Current Pos modes do not prompt, so jog there first. The work offset is the one this Setup names, which the post selects.",
    group      : "probe",
    order      : 10,
    type       : "enum",
    values: [
      { title: "Set X0 Y0 to Current Pos, Probe Z0", id: "Current XY & Probe Z" },
      { title: "Set X0 Y0 Z0 to Current Pos", id: "Current XYZ" },
      { title: "Use WCS X0 Y0, Probe Z0", id: "Probe Z" },
      { title: "Use WCS X0 Y0 Z0", id: "Skip" },
      { title: "Jog to X0 Y0, Probe Z0", id: "Jog XY & Probe Z" },
      { title: "Jog to X0 Y0 Z0", id: "Jog XYZ" }
    ],
    value: "Current XY & Probe Z",
    scope: "post"
  },
  probeOnChange: {
    title      : "Each New WCS / Part",
    description: "Multi-part jobs only: how each part's origin is set the first time the job reaches it, after a retract to Machine Travel Z. A return to a part sets nothing again -- only a tool change re-opens its Z0. A flip or re-clamp is not supported: run it as a separate job.",
    group      : "probe",
    order      : 20,
    type       : "enum",
    values: [
      { title: "Use WCS X0 Y0, Probe Z0 Once per Part", id: "Probe Z" },
      { title: "Use WCS X0 Y0 Z0", id: "Skip" },
      { title: "Jog to X0 Y0, Probe Z0", id: "Jog XY & Probe Z" },
      { title: "Jog to X0 Y0 Z0", id: "Jog XYZ" }
    ],
    value: "Probe Z",
    scope: "post"
  },
  probePause: {
    title      : "Probe Pause",
    description: "Prompts to attach and remove the Z probe. No: none, for a fixed probe. Before: attach only. Before & After: both. Applies to every probe in the job.",
    group      : "probe",
    order      : 30,
    type       : "enum",
    values: [
      { title: "No", id: "No" },
      { title: "Before", id: "Before" },
      { title: "Before & After", id: "Before & After" }
    ],
    value: "Before & After",
    scope: "post"
  },
  // One field, not two: the offset is one displacement. A string, so it takes the same "X, Y" syntax as
  // Manual Position X Y, through the same parseXYPair(). Unlike that field, empty has no meaning here:
  // "0, 0" does, an unreadable value falls back to it, and validateJob() warns rather than refuses.
  //
  // A new key, not probeOffsetX/Y: a stored integer there is not this field's string. A saved setting
  // falls back to the default 0, 0, what both old fields shipped. See the note at the head of this object.
  probeOffsetXY: {
    title      : "Probe X Y Offset",
    description: "Distance from the part origin to the probe's touch-point -- for an origin at a corner or off the material. Two numbers in mm separated by a comma: 30, -15. Whitespace around the comma is ignored, and either number may be signed and may carry decimals. The same for every part. 0, 0 probes at the origin itself.",
    group      : "probe",
    order      : 40,
    type       : "string",
    value      : "0, 0",
    scope      : "post"
  },
  probeG382orG28: {
    title      : "Probe with G38.2",
    description: "Probe using G38.2 (On) or G28 (Off). Read on Marlin and RepRap only -- GRBL always uses G38.2. Turn it off for a Marlin build without probe support, and for RepRapFirmware 3.1.1 and earlier, where G38.2 probes to the wrong height.",
    group      : "probe",
    order      : 60,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  probeG38Target: {
    title      : "G38 Target",
    description: "How far down from the tool a probe may search before giving up -- a distance, not a height. -10 searches 10 mm below wherever the tool starts. The Use WCS modes start the probe at Machine Travel Z, so it must reach from there to your stock top. A probe that never touches stops the job with an alarm.",
    group      : "probe",
    order      : 70,
    type       : "integer",
    value      : -10,
    scope      : "post"
  },
  probeG38Speed: {
    title      : "G38 Speed",
    description: "G38 probing's speed (mm/min). Slow is accurate.",
    group      : "probe",
    order      : 80,
    type       : "integer",
    value      : 30,
    scope      : "post"
  },
  // One property with two readers, not two meanings on one field (design.md): both groups read a height
  // that clears the work, in the part's work coordinates from the touch-off Z0. Group 3 asks "is the tool
  // at or above it, so this G1 may become a G0"; group 5 retracts to it after the probe. Two different
  // heights would mean rapiding through the height just called clear.
  //
  // The key keeps its "probe" name: every stored value still means the same height, and a rename would
  // reset it.
  probeSafeZ: {
    title      : "Safe Z",
    description: "A height that clears the work, in the part's work coordinates -- measured from the touch-off Z0 at the stock top, never from machine zero. Read twice: the tool retracts to it after probing, and in group 3 a Z at or above it is treated as safe air, so a G1 there may become a G0. A number in mm, or Feed:/Retract:/Clearance:<fallback> to use the operation's own Fusion level -- Retract:15 means the Fusion retract level, or 15 mm if it has none.",
    group      : "probe",
    order      : 90,
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },
  probeThickness: {
    title      : "Plate Thickness",
    description: "Thickness of your Z touch plate, in mm, subtracted after the probe touches so Z0 lands on the stock top. Measure your own -- an error here shifts every cut depth in the job.",
    group      : "probe",
    order      : 100,
    type       : "number",
    value      : 0.8,
    scope      : "post"
  },

  // The post performs no tool change on any firmware; this group says what it does instead. A measured
  // change needs a probe, a subtraction and a register for the result, and the post has none. It arrives,
  // hands control to the operator or a macro, and resumes correctly. design.md -> Tool changes.
  toolChangeMode: {
    title      : "At a Tool Change",
    description: "What happens when the tool number changes; the post never changes the tool itself. Refuse: the job does not post. Pause: retract, stop spindle and coolant, then M0 -- do not jog there. Macro: the same, then the Handled By token -- test it on air. Both need Machine Travel Z; Macro is not on Marlin.",
    group      : "toolChange",
    order      : 10,
    type       : "enum",
    // Titles say who acts and what happens; ids are stored values, not display text. Fusion saves the id and
    // the tools/ matrices pass it on the command line, so changing one resets saved settings, alters every
    // saved property dump and rewrites every case that names it.
    values: [
      { title: "Refuse a multi-tool job",           id: "Refuse" },
      { title: "Manual change at a pause",          id: "Pause"  },
      { title: "Sender or firmware macro changes it", id: "Macro" }
    ],
    value: "Refuse",
    scope: "post"
  },
  toolChangeSender: {
    title      : "Tool Change Handled By",
    description: "Who does the change, and so which token is emitted -- macro route only. gSender, CNCjs, UGS: T and M6, which the sender must intercept; stock Grbl and grblHAL reject M6. FluidNC: T and M6, run by the changer or macro in config.yaml. RepRapFirmware: T alone. Other: the Sender Macro File.",
    group      : "toolChange",
    order      : 20,
    type       : "enum",
    values: [
      { title: "gSender (Sienci) -- T + M6",         id: "gSender" },
      { title: "CNCjs -- T + M6",                    id: "CNCjs"   },
      { title: "UGS (Universal Gcode Sender) -- T + M6", id: "UGS"  },
      { title: "FluidNC -- T + M6",                  id: "FluidNC" },
      { title: "RepRapFirmware tool table -- T",     id: "RepRap"  },
      { title: "Other -- the macro file below",      id: "Other"   }
    ],
    value: "Other",
    scope: "post"
  },
  toolChangeMacroFile: {
    title      : "Sender Macro File",
    description: "A file in the NC output folder emitted in place of a tool-change token. Required when Tool Change Handled By is Other. The retract, stops and resume stay the post's; everything between them is your file, included identically at every change. Naming any file makes Fusion ask whether this post is safe -- answer Yes, or the post aborts.",
    group      : "toolChange",
    order      : 30,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  // Where the manual change happens, in machine coordinates (G53) rather than work coordinates, so the
  // spot does not move with each part origin. X and Y are one "X, Y" field because they are one point; Z
  // is its own because it is set alone. Strings, because empty means "do not move" -- as Machine Travel
  // Z's empty means no Z reference -- and every numeric sentinel would be a reachable coordinate.
  //
  // A new key, not toolChangePositionX: a stored "-10" there was one axis, which this parser rejects as a
  // pair. A saved setting falls back to the shipped empty -- the change happens above the last cut. See
  // the note at the head of this object.
  toolChangePositionXY: {
    title      : "Manual Position X Y",
    description: "Where the tool goes for a manual tool change -- an absolute machine X and Y in mm, written as two numbers separated by a comma: -10, -400. Whitespace around the comma is ignored. Empty: it does not move in X or Y, and the change happens above the last cut. Needs X and Y declared homed and Machine Travel Z set, and is read only on Manual change at a pause. Bringing Y forward is usually what puts the spindle where you can reach it. The tool does not return to the point it left; it returns to Machine Travel Z.",
    group      : "toolChange",
    order      : 40,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  toolChangePositionZ: {
    title      : "Manual Position Z",
    description: "The height the tool holds during a manual tool change -- an absolute machine coordinate in mm. Empty: the change happens at Machine Travel Z. Fill it only to get a spanner on the collet; the post moves there after the X/Y move and returns to Machine Travel Z afterwards. Below Machine Travel Z the tool sits lower than the height you declared clears your fixtures, so the post warns. May be filled without X and Y.",
    group      : "toolChange",
    order      : 60,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  // A declaration, not a prompt: the operator knows whether the fitted tool is the job's first; who fits
  // it otherwise is At a Tool Change's answer. A new key because the sense inverted -- a saved `true`
  // meant "prompt me" and here would mean "no action" -- so it resets to the default: no prompt, nothing
  // emitted. PV-13.
  toolChangeFirstToolCorrect: {
    title      : "First Tool is Correct",
    description: "On: the tool in the spindle is the one this job starts with, and nothing is emitted for it. Off: the first tool is loaded before any origin is recorded or probed -- so Z0 is measured with the tool that will cut -- by whatever At a Tool Change says. Manual change at a pause, or Refuse a multi-tool job: a stop (M0) for you to fit it. Sender or firmware macro changes it: the same token every other change uses, so a changer loads it and no one is asked to. Ignored on the two Set ... to Current Pos origin modes, which take the origin from a jog you made with a tool already fitted.",
    group      : "toolChange",
    order      : 70,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  // Three answers, because they differ for a multi-part job: a tool-length offset shifts Z for every
  // part, so every stored Z0 stays valid, while a re-probe or a hand-zero corrects only the active part.
  // design.md -> Tool changes. A new key: a stored boolean is not an enum id. PV-10.
  toolChangeZ0Correction: {
    title      : "Tool Length Correction By",
    description: "Who corrects work Z0 for the new tool's length -- this machine has no tool-length system. GCode reprobes: the post re-probes at each change and marks other parts' Z0 stale. Tool offset: your sender or macro shifts the whole Z frame, and nothing is probed. Re-zeroed by hand: corrects only the part active at the pause.",
    group      : "toolChange",
    order      : 80,
    type       : "enum",
    values: [
      { title: "GCode reprobes Z0 after change",    id: "Probe"  },
      { title: "Tool change applies tool offset",   id: "Offset" },
      { title: "User re-zeroed Z by hand at pause", id: "Manual" }
    ],
    value: "Probe",
    scope: "post"
  },
  // These add to the tool-change sequence, where group 7's two files replace the header and footer, so
  // they sit here and not beside those.
  includeToolFile1: {
    title      : "Tool Change Start",
    description: "A file of your g-code inserted at the start of each tool change, before the retract and the stops. It runs where the cut ended, at cutting height, so any move in it is yours to make safe. Ignored unless At a Tool Change hands over. Naming any file makes Fusion ask whether this post is safe -- answer Yes, or the post aborts.",
    group      : "toolChange",
    order      : 90,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  includeToolFile2: {
    title      : "Tool Change End",
    description: "A file of your g-code inserted at the end of each tool change, after the resume and any re-probe. The tool is at Machine Travel Z with absolute mode, units and the work offset re-asserted, so this is the safe end to move in. Ignored unless At a Tool Change hands over.",
    group      : "toolChange",
    order      : 100,
    type       : "string",
    value      : "",
    scope      : "post"
  },

  includeStartFile: {
    title      : "Start GCode File",
    description: "A file in the NC output folder that replaces the post's header, including the G90/G21/G94/G17 setup -- so your file must set whatever the job needs. Empty uses the built-in header. Naming any file makes Fusion ask whether this post is safe -- answer Yes, or the post aborts.",
    group      : "include",
    order      : 10,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  includeStopFile: {
    title      : "Stop GCode File",
    description: "A file in the NC output folder that replaces the post's footer -- the spindle stop, park, stepper release and program end all go. Empty uses the built-in footer.",
    group      : "include",
    order      : 20,
    type       : "string",
    value      : "",
    scope      : "post"
  },

  laserOnVaporize: {
    title      : "Laser: On - Vaporize",
    description: "Percentage of power to turn on the laser/plasma cutter in vaporize mode.",
    group      : "laser",
    order      : 10,
    type       : "integer",
    value      : 100,
    scope      : "post"
  },
  laserOnThrough: {
    title      : "Laser: On - Through",
    description: "Percentage of power to turn on the laser/plasma cutter in through mode.",
    group      : "laser",
    order      : 20,
    type       : "integer",
    value      : 80,
    scope      : "post"
  },
  laserOnEtch: {
    title      : "Laser: On - Etch",
    description: "Percentage of power to turn on the laser/plasma cutter in etch mode.",
    group      : "laser",
    order      : 30,
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  // One field, not one per firmware: CNC Firmware reads only one dialect. Each value's title carries its
  // dialect, as group 9's do, and outputCodeFirmware() reads it off the title so no second list can drift.
  //
  // A new key: the old fields' ids clash ("M3" was Marlin's spindle form, "3" is GRBL's static power), so
  // a stored value would be misread. The default is a GRBL value because CNC Firmware ships Grbl.
  laserOutput: {
    title      : "Laser Output",
    description: "How the laser or plasma cutter is switched, and at what power. Match it to your CNC Firmware -- the post emits what you pick. The two GRBL values drive S against $30, which this post scales 0-1000: M4 scales power with speed so corners are not over-burned, M3 holds it steady. The three Marlin/RepRapFirmware values take a 0-255 S: Fan and Pin both take their output number from Pin/Fan # below, and Spindle takes none. No value emits M107 -- RepRapFirmware ignores its P word and zeroes whatever fans the current tool maps, so the off code is M106 with S0, which is what M107 does on Marlin anyway.",
    group      : "laser",
    order      : 40,
    type       : "enum",
    values: [
      { title: "Grbl: M4 S{PWM}/M5 dynamic power", id: "4" },
      { title: "Grbl: M3 S{PWM}/M5 static power", id: "3" },
      { title: "Mrln: M106 P{n} S{PWM}/S0", id: "M106" },
      { title: "Mrln: M3 O{PWM}/M5", id: "M3" },
      { title: "Mrln: M42 P{pin} S{PWM}", id: "M42" }
    ],
    value      : "4",
    scope      : "post"
  },
  laserMarlinPinFan: {
    title      : "Laser: Pin/Fan #",
    description: "The output number Laser Output's M106 and M42 values use. M106: a fan index on Marlin, a fan number on RepRapFirmware. M42: a board pin on Marlin, a GpOut port on RepRapFirmware. The numbering is your board's and the post cannot check it -- a wrong Marlin fan index fails silently and the laser never fires.",
    group      : "laser",
    order      : 50,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  laserCoolant: {
    title      : "Laser: Coolant",
    description: "Force a coolant to be used with the laser -- an air assist, usually.",
    group      : "laser",
    order      : 70,
    type       : "enum",
    values: [
      { title: eCoolant.Off, id: eCoolant.Off },
      { title: eCoolant.Flood, id: eCoolant.Flood },
      { title: eCoolant.Mist, id: eCoolant.Mist },
      { title: eCoolant.ThroughTool, id: eCoolant.ThroughTool },
      { title: eCoolant.Air, id: eCoolant.Air },
      { title: eCoolant.AirThroughTool, id: eCoolant.AirThroughTool },
      { title: eCoolant.Suction, id: eCoolant.Suction },
      { title: eCoolant.FloodMist, id: eCoolant.FloodMist },
      { title: eCoolant.FloodThroughTool, id: eCoolant.FloodThroughTool }
    ],
    value      : eCoolant.Off,
    scope      : "post"
  },

  coolantChannelAMode: {
    title      : "Channel A Mode",
    description: "Enable channel A when a tool asks for this coolant.",
    group      : "coolant",
    order      : 10,
    type       : "enum",
    values: [
      { title: eCoolant.Off, id: eCoolant.Off },
      { title: eCoolant.Flood, id: eCoolant.Flood },
      { title: eCoolant.Mist, id: eCoolant.Mist },
      { title: eCoolant.ThroughTool, id: eCoolant.ThroughTool },
      { title: eCoolant.Air, id: eCoolant.Air },
      { title: eCoolant.AirThroughTool, id: eCoolant.AirThroughTool },
      { title: eCoolant.Suction, id: eCoolant.Suction },
      { title: eCoolant.FloodMist, id: eCoolant.FloodMist },
      { title: eCoolant.FloodThroughTool, id: eCoolant.FloodThroughTool }
    ],
    value      : eCoolant.Off,
    scope      : "post"
  },
  coolantChannelBMode: {
    title      : "Channel B Mode",
    description: "Enable channel B when a tool asks for this coolant.",
    group      : "coolant",
    order      : 20,
    type       : "enum",
    values: [
      { title: eCoolant.Off, id: eCoolant.Off },
      { title: eCoolant.Flood, id: eCoolant.Flood },
      { title: eCoolant.Mist, id: eCoolant.Mist },
      { title: eCoolant.ThroughTool, id: eCoolant.ThroughTool },
      { title: eCoolant.Air, id: eCoolant.Air },
      { title: eCoolant.AirThroughTool, id: eCoolant.AirThroughTool },
      { title: eCoolant.Suction, id: eCoolant.Suction },
      { title: eCoolant.FloodMist, id: eCoolant.FloodMist },
      { title: eCoolant.FloodThroughTool, id: eCoolant.FloodThroughTool }
    ],
    value      : eCoolant.Off,
    scope      : "post"
  },
  // One field per channel: the on code fixes the off code. M106 and M42 close with S0 on the same output,
  // a custom on closes from the channel's own Off Custom file, and on GRBL M9 is the only off code.
  // coolantOffCode() is the derivation, stated once.
  //
  // Keep the key: every stored id is still legal and means the same output, now in both directions, so a
  // saved configuration carries over intact.
  coolantChannelAOn: {
    title      : "Channel A Output",
    description: "The code that switches channel A on; the off code follows from it -- S0 for M106 and M42, M9 for M7 and M8, the Off Custom file for Use custom. M106 and M42 are Marlin and RepRapFirmware only. M7 and M8 work everywhere the firmware has them: Grbl built with ENABLE_M7, FluidNC or Marlin with a coolant pin, RepRap with /sys macros.",
    group      : "coolant",
    order      : 30,
    type       : "enum",
    values: [
      { title: "Mrln: M106 P{n} S255", id: "M106" },
      { title: "Mrln: M42 P{pin} S255", id: "M42" },
      { title: "M7 on, M9 off", id: "M7" },
      { title: "M8 on, M9 off", id: "M8" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M8",
    scope      : "post"
  },
  // 45 and 65: each channel's number sits under the field that reads it. Same trade as jobSpindlePinFan.
  coolantChannelAPinFan: {
    title      : "Channel A Pin/Fan #",
    description: "The output number channel A's M106 and M42 values use, for both on and off. M106: a fan index on Marlin, a fan number on RepRapFirmware. M42: a board pin on Marlin, a GpOut port on RepRapFirmware. The numbering is your board's, and the post cannot check it.",
    group      : "coolant",
    order      : 45,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  coolantChannelBOn: {
    title      : "Channel B Output",
    description: "The g-code that switches channel B on, and with it the code that switches it off -- the second, independent output. The off code follows from this field exactly as channel A's does. M7 and M8 carry the conditions stated under Channel A Output.",
    group      : "coolant",
    order      : 50,
    type       : "enum",
    values: [
      { title: "Mrln: M106 P{n} S255", id: "M106" },
      { title: "Mrln: M42 P{pin} S255", id: "M42" },
      { title: "M7 on, M9 off", id: "M7" },
      { title: "M8 on, M9 off", id: "M8" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M7",
    scope      : "post"
  },
  coolantChannelBPinFan: {
    title      : "Channel B Pin/Fan #",
    description: "The output number channel B's two Marlin values use, read by both of them. Every condition stated under Channel A Pin/Fan # applies here unchanged -- the four readings, the board-specific numbering, and M42's DIRECT_PIN_CONTROL and protected-pin conditions. The two channels MAY share one number: this post takes both channels off before it switches either on, so a shared output is switched off and back on rather than left in whichever state the last channel wrote.",
    group      : "coolant",
    order      : 65,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  coolantChannelAOnCustom: {
    title      : "Channel A On Custom",
    description: "File with custom GCode to turn ON coolant channel A (in nc folder). Read only when Channel A Output is Use custom -- which is also what reaches the Off file below, one answer covering both directions.",
    group      : "coolant",
    order      : 70,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelAOffCustom: {
    title      : "Channel A Off Custom",
    description: "File with custom GCode to turn OFF coolant channel A (in nc folder). Read only when Channel A Output is Use custom -- the same answer that reaches the On file above. Name both or neither: custom is custom at both ends, and a channel switched on from a file is never closed by a g-code the post chose for you.",
    group      : "coolant",
    order      : 80,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelBOnCustom: {
    title      : "Channel B On Custom",
    description: "File with custom GCode to turn ON coolant channel B (in nc folder). Read only when Channel B Output is Use custom -- which is also what reaches the Off file below.",
    group      : "coolant",
    order      : 90,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelBOffCustom: {
    title      : "Channel B Off Custom",
    description: "File with custom GCode to turn OFF coolant channel B (in nc folder). Read only when Channel B Output is Use custom -- the same answer that reaches the On file above. Name both or neither.",
    group      : "coolant",
    order      : 100,
    type       : "string",
    value      : "",
    scope      : "post"
  },

  // Both RRF 3.x and 2.05 forms are described: 3.x moved spindle setup from M453 into M950/M563, and
  // M452's pin from P/I to C"pin". The defaults are the 3.x forms and name no pin -- a missing pin means
  // the laser never fires, a wrong one drives an output the operator did not choose. One command per
  // field: the string goes through a single writeBlock(). PR-13.
  duetMillingMode: {
    title      : "Milling Mode",
    description: "GCode that puts a Duet into CNC mode, written on the first section and again at every section-type change. RRF 3.x: M453 on its own -- the spindle is created in config.g with M950 R0 C\"<pin>\" Q<freq> L<max rpm> and bound to the tool with M563 ... R0, and M453 S<n> is refused there. RRF 2.05: M453 P<pin> I<0|1> R<max rpm> F<freq>, which is the M453 P2 I0 R30000 F200 this field used to ship. One command only: the string is written as a single line.",
    group      : "duet",
    order      : 10,
    type       : "string",
    value      : "M453",
    scope      : "post"
  },
  duetLaserMode: {
    title      : "Laser Mode",
    description: "GCode that puts a Duet into laser mode, written on the first section and again at every section-type change. RRF 3.x needs the laser pin named here -- M452 C\"<pin>\" R<max power> F<PWM freq>, the pin being out... on a Duet 3 or exp.heater... on a Duet 2 -- and assigns no pin at all without it. RRF 2.05 uses P<pin> I<0|1> in place of that C. One command only: the string is written as a single line.",
    group      : "duet",
    order      : 20,
    type       : "string",
    value      : "M452 R255 F200",
    scope      : "post"
  }
}

var sequenceNumber;

// Formats
var gFormat = createFormat({ prefix: "G", decimals: 1 });
var mFormat = createFormat({ prefix: "M", decimals: 0 });

var xyzFormat = createFormat({ decimals: (unit == MM ? 3 : 4) });
var xFormat = createFormat({ prefix: "X", decimals: (unit == MM ? 3 : 4) });
var yFormat = createFormat({ prefix: "Y", decimals: (unit == MM ? 3 : 4) });
var zFormat = createFormat({ prefix: "Z", decimals: (unit == MM ? 3 : 4) });
var iFormat = createFormat({ prefix: "I", decimals: (unit == MM ? 3 : 4) });
var jFormat = createFormat({ prefix: "J", decimals: (unit == MM ? 3 : 4) });
var kFormat = createFormat({ prefix: "K", decimals: (unit == MM ? 3 : 4) });

var speedFormat = createFormat({ decimals: 0 });
var sFormat = createFormat({ prefix: "S", decimals: 0 });

var pFormat = createFormat({ prefix: "P", decimals: 0 });
var oFormat = createFormat({ prefix: "O", decimals: 0 });

var fFormat = createFormat({ prefix: "F", decimals: (unit == MM ? 0 : 2) });

var toolFormat = createFormat({ decimals: 0 });
// One consumer, toolChangeMacroCall(), and it is not a tool change: the T word is emitted only where
// something other than this post acts on it -- a sender intercepting the M6, FluidNC executing that M6
// itself, or RRF, whose T word is the change. Elsewhere the tool is named in a prompt the operator reads.
var tFormat = createFormat({ prefix: "T", decimals: 0 });

var taperFormat = createFormat({ decimals: 1, scale: DEG });
var secFormat = createFormat({ decimals: 3, forceDecimal: true }); // seconds, 0.001-99999.999

// Linear outputs
var xOutput = createVariable({}, xFormat);
var yOutput = createVariable({}, yFormat);
var zOutput = createVariable({}, zFormat);
var fOutput = createVariable({ force: false }, fFormat);
var sOutput = createVariable({ force: true }, sFormat);

// Circular outputs
var iOutput = createReferenceVariable({}, iFormat);
var jOutput = createReferenceVariable({}, jFormat);
var kOutput = createReferenceVariable({}, kFormat);

// Modals
var gMotionModal = createModal({}, gFormat); // RS-274 group 1: G0-G3
var gPlaneModal = createModal({ onchange: function () { gMotionModal.reset(); } }, gFormat); // RS-274 group 2: G17-19
var gAbsIncModal = createModal({}, gFormat); // RS-274 group 3: G90-91
var gFeedModeModal = createModal({}, gFormat); // RS-274 group 5: G93-94
var gUnitModal = createModal({}, gFormat); // RS-274 group 6: G20-21

// Line numbering, read off one property so writeBlock() and resetPostState() cannot disagree. Both on
// values start at N10 and differ only in step: 1, or 10 to leave room for inserted blocks.
function sequenceNumbersEnabled() {
  return getProperty(properties.jobSequenceNumbering) != "Off";
}
function sequenceNumberStart() {
  return 10;
}
function sequenceNumberStep() {
  return (getProperty(properties.jobSequenceNumbering) == "Step10") ? 10 : 1;
}

function writeBlock() {
  if (sequenceNumbersEnabled()) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += sequenceNumberStep();
  } else {
    writeWords(arguments);
  }
}

function flushMotions() {
  // GRBL has no "wait for moves to finish" code: the planner drains on its own and M400 would be
  // an unknown command, so there is deliberately nothing to emit here.
  if (fw == eFirmware.GRBL) {
    return;
  }

  writeBlock(mFormat.format(400));
}

//---------------- Safe Rapids ----------------

var eSafeZ = {
  CONST: 0,
  FEED: 1,
  RETRACT: 2,
  CLEARANCE: 3,
  ERROR: 4,
  prop: {
    0: {name: "Const", regex: /^\s*(\d+\.?\d*|\.\d+)\s*$/, numRegEx: /^\s*(\d+\.?\d*|\.\d+)\s*$/, value: 0},
    1: {name: "Feed", regex: /^\s*Feed:/i, numRegEx: /:\s*(\d+\.?\d*|\.\d+)\s*$/, value: 1},
    2: {name: "Retract", regex: /^\s*Retract:/i, numRegEx: /:\s*(\d+\.?\d*|\.\d+)\s*$/, value: 2},
    3: {name: "Clearance", regex: /^\s*Clearance:/i, numRegEx: /:\s*(\d+\.?\d*|\.\d+)\s*$/, value: 3},
    4: {name: "Error", regex: /^$/, numRegEx: /^$/, value: 4}
  }
};

var safeZMode = eSafeZ.CONST;
// The literal fallback parsed out of the Safe-Z property, in MILLIMETRES -- every dialog dimension is
// mm. Convert with propertyMmToUnit() before comparing it against, or emitting it as, a coordinate.
var safeZHeightDefault;
var safeZHeight;   // resolved height, in the OUTPUT unit

// Parse a Safe-Z expression -- a bare number, or Feed:/Retract:/Clearance:<fallback> -- into
// { mode, dflt }, dflt undefined on ERROR. Whitespace around the expression and after the colon is
// ignored. Pure.
function parseSafeZExpr(str) {
  var mode;
  var dflt;

  // The first regex that matches picks the mode; none matching leaves ERROR.
  for (mode = eSafeZ.CONST; mode < eSafeZ.ERROR; mode++) {
    if (str.search(eSafeZ.prop[mode].regex) == 0) {
      break;
    }
  }

  if (mode != eSafeZ.ERROR) {
    var match = str.match(eSafeZ.prop[mode].numRegEx);

    if ((match == null) || (match.length != 2)) {
      mode = eSafeZ.ERROR;
    }
    else {
      dflt = Number(match[1]);
    }
  }

  return {mode: mode, dflt: dflt};
}

// Parsed once per file. Group 5's retract after a probe and group 3's G1-to-G0 threshold both take
// their mode and fallback from here.
function parseSafeZProperty() {
  var parsed = parseSafeZExpr(getProperty(properties.probeSafeZ));
  safeZMode = parsed.mode;
  safeZHeightDefault = parsed.dflt;

  if (safeZMode == eSafeZ.ERROR) {
    error("Internal: an unreadable Safe Z reached parseSafeZProperty() -- validateJob() should have refused it.");
    return;
  }

  writeComment(eComment.Debug, " parseSafeZProperty: safeZMode = '" + eSafeZ.prop[safeZMode].name + "'");
  writeComment(eComment.Debug, " parseSafeZProperty: safeZHeightDefault = " + safeZHeightDefault);
}

// Group 3's per-section Safe Z, cached in safeZHeight because isSafeToRapid() is asked once per move
// and must not re-resolve. A missing level and a relative one both report "not usable": same remedy.
function safeZforSection(_section)
{
  if (!getProperty(properties.mapRapidsRestoreRapids)) {
    return;
  }

  var resolved = resolveSafeZ(safeZMode, safeZHeightDefault, _section);
  safeZHeight = resolved.height;

  if (safeZMode == eSafeZ.CONST) {
    writeComment(eComment.Important, " SafeZ using const: " + safeZHeight);
  } else if (resolved.fromLevel) {
    writeComment(eComment.Info, " SafeZ " + eSafeZ.prop[safeZMode].name.toLowerCase()
      + " level: " + safeZHeight);
  } else {
    writeComment(eComment.Important, " SafeZ " + eSafeZ.prop[safeZMode].name.toLowerCase()
      + " level not usable, falling back: " + safeZHeight);
  }
}

// Resolve a parsed Safe-Z expression against one section's F360 levels, returning {height, fromLevel}:
// the height in the OUTPUT unit, and whether it came from the operation's own level. Feed/Retract/
// Clearance use that level when it is defined and absolute, else the fallback. Units differ: an F360
// level is already in the output unit, the dialog fallback is mm and is converted here. Pure.
//
// safeZforSection() reports fromLevel, so a job cutting to a fallback where the operator meant their
// own level says so.
function resolveSafeZ(mode, dflt, _section) {
  var fallback = propertyMmToUnit(dflt);
  var valueParam;
  var absParam;
  switch (mode) {
    case eSafeZ.FEED:
      valueParam = "operation:feedHeight_value";
      absParam   = "operation:feedHeight_absolute";
      break;
    case eSafeZ.RETRACT:
      valueParam = "operation:retractHeight_value";
      absParam   = "operation:retractHeight_absolute";
      break;
    case eSafeZ.CLEARANCE:
      valueParam = "operation:clearanceHeight_value";
      absParam   = "operation:clearanceHeight_absolute";
      break;
    default:  // CONST -- use the literal height
      return {height: fallback, fromLevel: false};
  }

  // Ask the PASSED section, not the global context: writeResolvedValues() resolves every section from
  // the header, where no section is current and the global form would report false throughout.
  if (_section.hasParameter(valueParam) && _section.hasParameter(absParam) && _section.getParameter(absParam) == 1) {
    return {height: _section.getParameter(valueParam), fromLevel: true};   // already in the output unit
  }
  return {height: fallback, fromLevel: false};
}

// The height alone, for the callers that do not care where it came from.
function resolveSafeZHeight(mode, dflt, _section) {
  return resolveSafeZ(mode, dflt, _section).height;
}

// Describe a parsed Safe-Z expression for the header block: its mode, its literal fallback, and what
// it actually RESOLVES to for this job's operations. `dflt` arrives in mm and is converted for
// display; resolveSafeZHeight() is handed the raw mm value and does its own conversion.
function describeSafeZ(mode, dflt) {
  var name = eSafeZ.prop[mode].name;
  var fallbackText = xyzFormat.format(propertyMmToUnit(dflt));
  if (mode == eSafeZ.CONST) {
    return name + " = " + fallbackText + " -- a fixed height, no F360 level consulted";
  }

  var seen = [];
  var n = getNumberOfSections();
  for (var i = 0; i < n; ++i) {
    var h = xyzFormat.format(resolveSafeZHeight(mode, dflt, getSection(i)));
    if (seen.indexOf(h) < 0) seen.push(h);
  }

  var resolved;
  if (seen.length == 0) {
    resolved = "no operations to resolve against";
  } else if (seen.length == 1) {
    resolved = seen[0];
  } else {
    resolved = "varies by operation -- " + seen.join(", ");
  }
  return name + " level, fallback " + fallbackText + ", resolves to " + resolved;
}

// The Safe Z for the CURRENT operation, in the output unit -- already unit-correct, so callers must NOT
// wrap it in propertyMmToUnit(). Group 5 calls this; group 3 caches its own answer in safeZHeight at
// onSection(), because it is asked once per move rather than once per probe.
function safeZ() {
  return resolveSafeZHeight(safeZMode, safeZHeightDefault, currentSection);
}


function roundTo(value, places) {
  // Plain arithmetic, not the string-exponent trick: JavaScript writes magnitudes below 1e-6
  // exponentially, so "1e-7" + "e+3" would parse as NaN.
  var scale = Math.pow(10, places);
  return Math.round(value * scale) / scale;
}

// Returns true if the rules to convert G1s to G0s are satisfied
function isSafeToRapid(x, y, z) {
  if (getProperty(properties.mapRapidsRestoreRapids)) {

    // Compare positions at the output precision. Two positions that format to the same G-code are the
    // same point, so rounding keeps float noise from failing the "constant axis" tests below.
    var places = (unit == MM ? 3 : 4);
    var zr = roundTo(z, places);
    writeComment(eComment.Debug, "isSafeToRapid z: " + z + " zr: " + zr);

    let zSafe = (zr >= safeZHeight);

    writeComment(eComment.Debug, "isSafeToRapid zSafe: " + zSafe + " zr: " + zr + " safeZHeight: " + safeZHeight);

    // Destination z must be in safe zone.
    if (zSafe) {
      let cur = getCurrentPosition();
      let xr = roundTo(x, places);
      let yr = roundTo(y, places);
      let curXr = roundTo(cur.x, places);
      let curYr = roundTo(cur.y, places);
      let curZr = roundTo(cur.z, places);

      let zConstant = (zr == curZr);
      let zUp = (zr > curZr);
      let xyConstant = ((xr == curXr) && (yr == curYr));
      let curZSafe = (curZr >= safeZHeight);
      writeComment(eComment.Debug, "isSafeToRapid curZSafe: " + curZSafe + " curZr: " + curZr);

      // Only when the target Z is safe and either Z is constant, Z rises with XY constant, or Z
      // descends with XY constant from a height that was already safe.
      if (zConstant) {
        return true;
      }

      else if (zUp && xyConstant) {
        return true;
      }

      else if ((!zUp) && xyConstant && curZSafe) {
        return true;
      }
    }
  }

  return false;
}

//---------------- Switched outputs -- fan and pin ----------------

// Shared by spindle, laser and both coolant channels. S always, off included: a bare M106 P{n} only
// reports on RepRapFirmware (Fan::Configure, src/Fans/Fan.cpp 3.5-dev) and M42 needs S. Never M107: RRF
// ignores its P and zeroes the tool's fans (GCodes2.cpp case 107); S0 is what M107 does on Marlin.
function writeFanOrPinOutput(mode, number, pwm) {
  writeBlock(mFormat.format(mode == "M42" ? 42 : 106), pFormat.format(number), sFormat.format(pwm));
}

//---------------- Coolant ----------------

// The four "... Custom" coolant properties name a FILE in the nc output folder, as their own tooltips
// say. Routed through loadFile() rather than written into the stream verbatim, so they inherit its
// missing-file error and its missing-trailing-newline repair.
function writeCustomCoolantFile(channel, on, file) {
  if (file == "") {
    // TWIN #2
    writeWarning("coolant channel " + channel + " is set to " + quotedValue(properties.coolantChannelAOn, "Use custom")
      + " but no custom file is named -- nothing emitted");
    return;
  }
  loadFile(file);
}

// The off code a channel's on code implies, stated only here. M106/M42: the same command and output
// with S0 (writeCoolantChannel() picks the S). M7/M8: M9, GRBL's only off code; it stops every coolant
// output, harmless because setCoolant() turns both channels off before turning either on. Use custom:
// the channel's own Off Custom file. Total over the dropdown's values, so a new one gets an off code. Pure.
function coolantOffCode(onCode) {
  switch (onCode) {
    case "M106":
    case "M42":
    case "Use custom":
      return onCode;
    default:
      return "M9";
  }
}

// One body for both channels and both directions. Three kinds of value: "Use custom" names a file,
// "M106"/"M42" name an output numbered by the channel's own field, and any other id is the g-code
// itself, which is why the GRBL ids stay literal. The direction picks the code off the one property.
function writeCoolantChannel(channel, on, onProp, fileProp, pinProp) {
  var code = on ? getProperty(onProp) : coolantOffCode(getProperty(onProp));

  if (code == "Use custom") {
    writeCustomCoolantFile(channel, on, getProperty(fileProp));
    return;
  }

  if (code == "M106" || code == "M42") {
    writeFanOrPinOutput(code, getProperty(pinProp), on ? 255 : 0);
    return;
  }

  writeBlock(code);
}

function switchCoolantA(on) {
  writeCoolantChannel("A", on, properties.coolantChannelAOn,
    on ? properties.coolantChannelAOnCustom : properties.coolantChannelAOffCustom,
    properties.coolantChannelAPinFan);
}

function switchCoolantB(on) {
  writeCoolantChannel("B", on, properties.coolantChannelBOn,
    on ? properties.coolantChannelBOnCustom : properties.coolantChannelBOffCustom,
    properties.coolantChannelBPinFan);
}

// Two coolant channels, each tracking the level it is running (Off = idle). setCoolant() takes the
// level wanted, or eCoolant.Off.

var curCoolant = eCoolant.Off;        // The level now switched on
var coolantChannelA = eCoolant.Off;   // The coolant running in ChannelA
var coolantChannelB = eCoolant.Off;   // The coolant running in ChannelB

// What a tool asks for, in one place, so onCommand(COMMAND_COOLANT_ON) and validateJob()'s pre-flight
// cannot disagree. F360 gives a jet tool no coolant, so it takes the laser group's forced level.
function requestedCoolant(t) {
  if (t.isJetTool()) {
    return getProperty(properties.laserCoolant);
  }
  return (t.coolant < coolantLevels.length) ? coolantLevels[t.coolant] : eCoolant.Off;
}

// Switch the coolant channels to the level this tool asks for. Both channels are taken to Off first,
// then the requested level is matched against each channel's configured Mode; a level neither Mode
// carries is warned about and nothing is emitted for it.
function setCoolant(coolant) {
  writeComment(eComment.Debug, " ---- Coolant: " + coolant  + " cur: " + curCoolant + " A: " + coolantChannelA + " B: " + coolantChannelB);

  if (curCoolant == coolant) {
    return;
  }

  // Both channels off first: whatever is running has to stop before the requested level can be matched.
  if (coolantChannelA != eCoolant.Off) {
    writeComment((coolant == eCoolant.Off) ? eComment.Important: eComment.Info, " >>> Coolant Channel A: " + eCoolant.Off);
    coolantChannelA = eCoolant.Off;
    switchCoolantA(false);
  }

  if (coolantChannelB != eCoolant.Off) {
    writeComment((coolant == eCoolant.Off) ? eComment.Important: eComment.Info, " >>> Coolant Channel B: " + eCoolant.Off);
    coolantChannelB = eCoolant.Off;
    switchCoolantB(false);
  }

  curCoolant = eCoolant.Off;

  var warn = true;

  if (coolant != eCoolant.Off) {
    if (getProperty(properties.coolantChannelAMode) == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel A: " + coolant);
      coolantChannelA =  coolant;
      curCoolant = coolant;
      warn = false;
      switchCoolantA(true);
    }

    if (getProperty(properties.coolantChannelBMode) == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel B: " + coolant);
      coolantChannelB =  coolant;
      curCoolant = coolant;
      warn = false;
      switchCoolantB(true);
    }

    if (warn) {
      // TWIN #3
      writeWarning("No matching Coolant channel : " + ((coolantLevels.indexOf(coolant) != -1 ) ? coolant : "unknown") + " requested");
    }
  }
}

//---------------- Cutters - Waterjet/Laser/Plasma ----------------

var cutterOnCurrentPower;

// The PWM scale follows the chosen output, not the job: GRBL's two values drive S against $30, scaled
// 0..1000 by this post; the Marlin/RepRapFirmware values take a 0..255 byte. validateJob() checks the
// output against the firmware.
function laserPwm(mode, power) {
  return (mode == "4" || mode == "3") ? (power * 10) : (power / 100 * 255);
}

function laserOn(power) {
  var mode = getProperty(properties.laserOutput);

  switch (mode) {
    // Number(): the GRBL ids are strings ("4" / "3"), and mFormat.format() takes a number everywhere else.
    case "4":
    case "3":
      writeBlock(mFormat.format(Number(mode)), sFormat.format(laserPwm(mode, power)));
      break;
    case "M106":
    case "M42":
      writeFanOrPinOutput(mode, getProperty(properties.laserMarlinPinFan), laserPwm(mode, power));
      break;
    case "M3":
      if (fw == eFirmware.REPRAP) {
        writeBlock(mFormat.format(3), sFormat.format(laserPwm(mode, power)));
      } else {
        writeBlock(mFormat.format(3), oFormat.format(laserPwm(mode, power)));
      }
      break;
    default:
      unknownLaserOutput(mode);
  }
}

// Total over the field, as coolantOffCode() is: a value the switches do not know would otherwise emit
// nothing, and the beam would never fire -- or never stop.
function unknownLaserOutput(mode) {
  error(localize(quoted(properties.laserOutput) + " is \"" + mode + "\", which this post does not know. "
    + "Choose one of its listed values."));
}

function laserOff() {
  var mode = getProperty(properties.laserOutput);

  switch (mode) {
    // M5 stops all three spindle-style values: GRBL's two and the Mrln M3.
    case "4":
    case "3":
    case "M3":
      writeBlock(mFormat.format(5));
      break;
    case "M106":
    case "M42":
      writeFanOrPinOutput(mode, getProperty(properties.laserMarlinPinFan), 0);
      break;
    default:
      unknownLaserOutput(mode);
  }
}

//---------------- on Entry Points ----------------

// Distinct work offsets used across all sections, with Fusion's ambiguous 0 aliased
// to 1 (WCS 1 / G54), matching writeWCS().
function collectDistinctOffsets() {
  var seen = {};
  var list = [];
  var n = getNumberOfSections();
  for (var i = 0; i < n; ++i) {
    var wo = getSection(i).getWorkOffset();
    if (wo == 0) wo = 1;
    if (!seen[wo]) { seen[wo] = true; list.push(wo); }
  }
  return list;
}

// True where one section uses work offset 0 and another 1 -- two labels on one register. Fusion reports
// 0 for a Setup on the default, chosen or not, so both alias to G54 as in writeWCS(). The result is not
// a wrong code: the post sees one part, never sets up a second origin, and the second Setup cuts on the
// first one's. Every pair is compared; Autodesk's validateCommonParameters() tests only the first
// section against the rest (grbl.cps, Rev 45769), missing a job whose first section is the explicit one.
function mixedDefaultAndExplicitWcs() {
  var sawDefault = false;
  var sawExplicit = false;
  var n = getNumberOfSections();
  for (var i = 0; i < n; ++i) {
    var wo = getSection(i).getWorkOffset();
    if (wo == 0) {
      sawDefault = true;
    } else if (wo == 1) {
      sawExplicit = true;
    }
  }
  return sawDefault && sawExplicit;
}

// Distinct tool numbers used across all sections. Counted over SECTIONS rather than getToolTable(),
// which lists every tool the document knows about including ones this job never switches between.
function countDistinctTools() {
  var seen = {};
  var count = 0;
  var n = getNumberOfSections();
  for (var i = 0; i < n; ++i) {
    var t = getSection(i).getTool().number;
    if (!seen[t]) { seen[t] = true; ++count; }
  }
  return count;
}

// True where any section cuts with a jet tool -- laser, plasma or waterjet. It gates group 8's checks:
// a milling job emits no laser code, so its laser field cannot be wrong. Counted over sections, as
// countDistinctTools() is, for the same reason.
function jetToolInJob() {
  var n = getNumberOfSections();
  for (var i = 0; i < n; ++i) {
    if (getSection(i).getTool().isJetTool()) {
      return true;
    }
  }
  return false;
}

// The one place a dialect label means a firmware. Every firmware-specific value in groups 8 and 9 carries
// its dialect in its title -- "Grbl: M4 S{PWM}/M5 dynamic power", "Mrln: M42 P{pin} S255" -- and M7/M8
// carry none, every firmware taking them under its own conditions. So the checks read the operator's own choice rather than a second list of codes that would drift.
// Used both ways: a chosen code to its firmware, and a firmware to the prefix it should be picked from.
var outputDialectLabels = [
  { label: "Grbl", firmware: eFirmware.GRBL },
  { label: "Mrln", firmware: eFirmware.MARLIN }
];

// The label this post uses for a firmware's codes, or undefined where it labels none -- which is
// RepRapFirmware, and is what scopes the coolant warning below.
function outputDialectLabel(firmware) {
  for (var i = 0; i < outputDialectLabels.length; ++i) {
    if (outputDialectLabels[i].firmware == firmware) {
      return outputDialectLabels[i].label;
    }
  }
  return undefined;
}

// The firmware a code property's CURRENT value was shipped for, off that value's own title. undefined
// is the answer "no dialect this post can name" and covers both "Use custom", where the file is the
// operator's and its dialect is unknowable, and any future unlabelled value.
function outputCodeFirmware(prop) {
  var id = getProperty(prop);
  for (var i = 0; i < prop.values.length; ++i) {
    if (prop.values[i].id == id) {
      var label = String(prop.values[i].title).split(":")[0];
      for (var j = 0; j < outputDialectLabels.length; ++j) {
        if (outputDialectLabels[j].label == label) {
          return outputDialectLabels[j].firmware;
        }
      }
      return undefined;
    }
  }
  return undefined;
}

// The display text of a code property's current value. Messages quote it, not the id, which for the
// laser's GRBL values is a bare "4" or "3" and never names the dialect.
function outputCodeTitle(prop) {
  var id = getProperty(prop);
  for (var i = 0; i < prop.values.length; ++i) {
    if (prop.values[i].id == id) {
      return prop.values[i].title;
    }
  }
  return id;
}

// Dialog names for messages, quoted and read from the definitions rather than copied into the text, so
// renaming a field, a value or a group cannot leave a message naming one that no longer exists. RV-02.
function quoted(prop) {
  return "\"" + prop.title + "\"";
}

function quotedValue(prop, id) {
  for (var i = 0; i < prop.values.length; ++i) {
    if (prop.values[i].id == id) {
      return "\"" + prop.values[i].title + "\"";
    }
  }
  return "\"" + id + "\"";
}

// A group as messages name it: its title up to the second " - ", so "4 - Machine Frame", not the full
// "4 - Machine Frame - homing, travel Z and end park".
function quotedGroup(key) {
  return "\"" + groupDefinitions[key].title.split(" - ").slice(0, 2).join(" - ") + "\"";
}

// Every coolant level this job asks for that NEITHER channel Mode carries, with the operations that
// asked -- [{level, names}], or empty. setCoolant() states it per occurrence in the file; this is the
// pre-flight half, off the same requestedCoolant().
//
// Gated on a configured channel, which is the one place the two halves deliberately differ: both Modes
// Off is the operator declaring the machine has no coolant, and Fusion's tools carry Flood whether or
// not anyone wanted it, so an ungated pre-flight would fire on nearly every hobbyist job. CR-24, PV-12.
function unmatchedCoolantRequests() {
  var modeA = getProperty(properties.coolantChannelAMode);
  var modeB = getProperty(properties.coolantChannelBMode);
  if (modeA == eCoolant.Off && modeB == eCoolant.Off) {
    return [];
  }

  var out = [];
  var seen = {};
  var n = getNumberOfSections();
  for (var i = 0; i < n; ++i) {
    var s = getSection(i);
    var level = requestedCoolant(s.getTool());
    if (level == eCoolant.Off || level == modeA || level == modeB) {
      continue;
    }
    if (seen[level] == undefined) {
      seen[level] = out.length;
      out.push({ level: level, names: [] });
    }
    out[seen[level]].names.push(operationName(s, i));
  }
  return out;
}

// Post-time validation guards. Runs once from onOpen(), before any output, so a misconfiguration
// fails fast.
function validateJob() {
  // --- Warnings ---------------------------------------------------------------------------------
  // Configurations that post a valid file which then does the wrong thing at the machine.

  // First, and in both channels: this property has no group, so writeAllProperties() skips it and the
  // file would otherwise carry no record that it was posted under a simulated Personal licence.
  if (getProperty(properties.mapRapidsTestPersonalLicence)) {
    // TWIN: here -- both channels in one block; personal-matrix.js R2 asserts both, so neither can go quietly.
    writeWarning("TEST HOOK IS ON -- rapids are being delivered as feed moves to exercise " + quotedGroup("mapRapids") + ". "
      + "THIS FILE IS A TEST ARTIFACT. DO NOT CUT FROM IT.");
    warning(localize(quoted(properties.mapRapidsTestPersonalLicence) + " is enabled. Fusion's rapids are "
      + "being delivered to the post as feed moves, which no licence you are running does. The output "
      + "is a test artifact and must not be cut."));
  }

  var startMode = getProperty(properties.probeOnStart);
  var changeMode = getProperty(properties.probeOnChange);
  var homedXY = machineHomesXY();
  var homedZ = machineHomesZ();
  // "Each New WCS / Part" is consulted only on a genuine WCS change (writeWCS()'s isTraverse),
  // which a single-offset job never has -- so every warning about that control is gated on this.
  var multiWcs = collectDistinctOffsets().length > 1;

  // The likeliest group-4 slip: "Home at Job Start" on, "Axes Homed and Trusted" still None.
  // TWIN #7 -- the file half is writeMachineHoming()'s.
  if (homesAtJobStart() && !homedXY && !homedZ) {
    warning(localize(quoted(properties.machineHomeAtStart) + " asks this job to home, but " + quoted(properties.machineHomedAxes) + " is "
      + "None, so no axis is declared homeable and the post emits no homing motion at all -- the job "
      + "starts from wherever the machine already sits. Declare which axes this machine homes to "
      + "endstops, or set " + quoted(properties.machineHomeAtStart) + " to Off."));
  }

  // Either axis qualifies: X/Y homing destroys the pre-jogged XY, Z homing the height recorded as Z0. Homing
  // precedes the origin write in writeFirstSection() and cannot be reordered after it. CR-15.
  // TWIN #8 -- the file half is writeMachineHoming()'s.
  if (homesAtJobStart() && (homedXY || homedZ) && originIsPreJogged()) {
    // Advice rather than prohibition: with X/Y declared homed, a stored fixture offset in the active
    // WCS is repeatable across power cycles, so it is a better answer than the destroyed pre-jog.
    warning(localize(quoted(properties.machineHomeAtStart) + " moves the tool onto the endstops of whichever axes "
      + quoted(properties.machineHomedAxes) + " declares, and it runs before "
      + quoted(properties.probeOnStart) + " records the current position as the part origin, so positioning the "
      + "tool before starting the job has no effect on those axes. On a homed machine the stored "
      + "offset in the active WCS is repeatable, so " + quotedValue(properties.probeOnStart, "Probe Z") + " is the "
      + "natural first-part mode here; a \"Jog to ...\" mode also works. Otherwise set " + quoted(properties.machineHomeAtStart)
      + " to Off."));
  }

  // A G54-G59 offset is measured from machine zero, which moves at every reset unless X/Y homes. Only modes
  // that trust a stored offset break; the "Jog" and "Current Pos" modes write a fresh one.
  if (!homedXY) {
    var storedOffsetControls = [];
    if (startMode == "Probe Z" || startMode == "Skip") {
      storedOffsetControls.push(quoted(properties.probeOnStart));
    }
    if ((changeMode == "Probe Z" || changeMode == "Skip") && multiWcs) {
      storedOffsetControls.push(quoted(properties.probeOnChange));
    }
    if (storedOffsetControls.length > 0) {
      warning(localize(storedOffsetControls.join(" and ") + " trust the origin already stored in a "
        + "work offset register, but " + quoted(properties.machineHomedAxes) + " does not include X/Y. A stored offset is measured from "
        + "machine zero, which moves at every controller reset or power cycle when nothing homes -- "
        + "so an offset written by an earlier job now points somewhere else, and the post cannot "
        + "read the register back to check. Declare X/Y homed on a machine with X/Y endstops, or "
        + "choose a mode that establishes the origin during this run."));
    }
  }

  // Warned for the silent overwrite -- the "Jog to ..." modes write the register too, but ask first. Not
  // refused: loose stock beside fixtured parts is a real workflow. CR-16.
  // TWIN #13 -- the file half is writeWcsOnStart()'s, on the same two predicates.
  if (multiWcs && originIsPreJogged()) {
    warning(localize(quoted(properties.probeOnStart) + " is a \"Set ... to Current Pos\" mode and this job cuts "
      + collectDistinctOffsets().length + " parts. That mode takes the first part's origin from where "
      + "you jog the tool BEFORE the file starts and writes it into that part's work offset register, "
      + "with no prompt -- while every other part is cut at the origin already stored in its own "
      + "register. So one part is cut where you parked the tool and the rest at their fixtures, and the "
      + "offset you set for the first part at the machine is overwritten. The two \"Jog to ...\" modes "
      + "write the register too but stop and ask first; " + quotedValue(properties.probeOnStart, "Probe Z") + " and " + quotedValue(properties.probeOnStart, "Skip")
      + " leave it alone. If every part in this job is fixtured, use one of those two."));
  }

  // Not refused: two Setups that share one fixture may be labelled this way. No file twin: the condition is
  // job-wide, and writeWCS() already writes the 0 -> 1 alias at Info. CR-16, PV-12.
  if (mixedDefaultAndExplicitWcs()) {
    warning(localize("This job names work offset 0 in one Setup and 1 in another, and they are the same "
      + "register: Fusion reports 0 for a Setup left at its default, so the post resolves both to WCS 1 "
      + "-- G54. Every section runs on ONE origin, and because the post sees a single work offset the "
      + "per-part origin work that " + quoted(properties.probeOnChange) + " controls never runs at the boundary between "
      + "them. If those Setups are two fixtures, number them 1 and 2 in Fusion so each part gets a "
      + "register of its own. If they are one fixture, nothing is wrong here and the two numbers are "
      + "only a labelling difference -- the post cannot tell the two cases apart."));
  }

  // Shares warnJogAtPauseNeedsSender()'s one statement of the condition, so the two cannot differ. The
  // firmware test is that statement being non-empty: RepRap alone has none.
  // TWIN #14 -- the file half is warnJogAtPauseNeedsSender()'s.
  if (jogAtPauseCondition() != "" &&
      (startMode == "Jog XY & Probe Z" || startMode == "Jog XYZ" ||
       (multiWcs && (changeMode == "Jog XY & Probe Z" || changeMode == "Jog XYZ")))) {
    warning(localize("A \"Jog to ...\" origin mode is selected, and " + jogAtPauseCondition() + ". "
      + "Check that before running this file -- without it the job stops at the prompt and cannot be "
      + "moved until it is resumed. Otherwise position the tool before starting and use a "
      + "\"Set ... to Current Pos\" or \"Use WCS ...\" mode."));
  }

  // PR-20: gSender comments an M0 out unconditionally but pauses its own stream only past its tenth
  // sent line, "if (sent > 10)" (src/server/controllers/Grbl/GrblController.js, master, 2026-08-14).
  // Sender.js's load() filters blank lines only, so comments count -- hence "Comment Level" decides it.
  if (fw == eFirmware.GRBL &&
      commentLevels.indexOf(getProperty(properties.jobCommentLevel)) < commentLevels.indexOf(eComment.Info)) {
    var earlyPrompts = [];
    // (homedXY || homedZ) because writeMachineHoming() returns before the prompt when nothing is
    // declared homeable -- that job emits no stop to lose, and is already warned about above.
    if (promptsBeforeHome() && (homedXY || homedZ)) {
      // "at the very top", not "the first line": on GRBL the travel-speed warning stands ahead of it.
      earlyPrompts.push("the " + quotedValue(properties.machineHomeAtStart, "Pause & Home") + " stop, which stands at the very top of the file");
    }
    // Not on a pre-jogged origin nor on the macro flow: toolChangeFirstLoad() writes no prompt on either, and
    // naming a line the file lacks sends the operator looking for it. PV-13.
    if (!getProperty(properties.toolChangeFirstToolCorrect) && !originIsPreJogged() && !toolChangeIsMacro()) {
      earlyPrompts.push("the " + quoted(properties.toolChangeFirstToolCorrect) + " stop, which stands before the first part's origin is set");
    }
    if (startMode == "Jog XY & Probe Z" || startMode == "Jog XYZ") {
      earlyPrompts.push("the " + quoted(properties.probeOnStart) + " jog prompt");
    }
    if (getProperty(properties.probePause) != "No" &&
        (startMode == "Current XY & Probe Z" || startMode == "Probe Z" || startMode == "Jog XY & Probe Z")) {
      earlyPrompts.push("the \"Attach ZProbe\" prompt before the first part's probe");
    }
    if (earlyPrompts.length > 0) {
      warning(localize(quoted(properties.jobCommentLevel) + " is \"" + getProperty(properties.jobCommentLevel) + "\", which "
        + "leaves this job's preamble only a few lines long -- and gSender ignores an M0 in the first "
        + "ten lines it sends, a workaround for CAM that opens its files with a meaningless one. It "
        + "comments the M0 out either way, so a prompt that early is not postponed, it is DELETED: the "
        + "job runs straight past it. At risk here: " + earlyPrompts.join("; ") + ". Post at "
        + quoted(properties.jobCommentLevel) + " \"Info\" and the property dump puts ~70 lines ahead of every one of them. "
        + "Senders that do not special-case an early M0 are unaffected, and nothing after the first "
        + "part is affected on any sender."));
    }
  }

  // TWIN #15 -- the file half is toolChangeFirstLoad()'s, on the same originIsPreJogged().
  if (!getProperty(properties.toolChangeFirstToolCorrect) && originIsPreJogged()) {
    warning(localize(quoted(properties.toolChangeFirstToolCorrect) + " is Off, but " + quoted(properties.probeOnStart) + " is a \"Set ... to "
      + "Current Pos\" mode, which takes this part's origin from where you jog the tool BEFORE "
      + "starting the file -- so a tool is already fitted by then, and nothing is emitted to load one. "
      + "Fitting a different tool would put every depth out by the difference in tool length, and on "
      + quotedValue(properties.toolChangeMode, "Macro") + " the hand-over would move the tool off the position "
      + "about to be recorded. To load the tool during the run, use " + quotedValue(properties.probeOnStart, "Jog XY & Probe Z") + " or "
      + quotedValue(properties.probeOnStart, "Jog XYZ") + ", which load first and position afterwards; otherwise turn " + quoted(properties.toolChangeFirstToolCorrect)
      + " on."));
  }

  // Two texts: where homing parks Z at its endstop the operator cannot set probe height; a first-tool
  // macro or a start file may move it after homing, so gets the second. PR-16, RV-17.
  // TWIN #12 -- the file half is partProbe()'s, covering all four of its callers.
  if (startMode == "Probe Z" && !fixedZEstablishedInFile()) {
    if (homingMovesZ() && toolStillWhereHomingLeftIt()) {
        // Probe X/Y is the register's; only its start height is the tool's.
      warning(localize(quoted(properties.probeOnStart) + " = " + quotedValue(properties.probeOnStart, "Probe Z") + " rapids to the stored X0 Y0 -- an "
        + "X/Y move, made at whatever height the tool is holding -- and the G38.2 that follows searches "
        + "DOWN FROM THAT SAME HEIGHT, this job establishing no Z the post can move in. So one height "
        + "decides both whether the crossing clears your work and whether the probe can reach the stock, "
        + "and on this job " + quoted(properties.machineHomeAtStart) + " is what chose it. "
        + (fw == eFirmware.GRBL
            ? "The single \"$H\" this post emits on " + fw + " runs the build's whole homing cycle, and the "
              + "stock cycle homes Z FIRST to clear the work area -- so Z goes to its endstop here even "
              + "though " + quoted(properties.machineHomedAxes) + " declares only X and Y."
            : "The \"G28 Z\" this job emits leaves the tool at the Z endstop.")
        + " Positioning the tool before starting the file has no effect on that height, and nothing "
        + "between the homing and the probe brings it back to one you chose. The post cannot know which end of the travel "
        + "your Z endstop is at, and both ends are wrong here: at the top of travel the stock is the "
        + "whole travel below, a " + quoted(properties.probeG38Target) + " of " + getProperty(properties.probeG38Target) + " mm never "
        + "reaches it and the job stops on a probe-fail alarm; at the bed the search starts a pull-off "
        + "above the bed and runs down into it. Enter " + quoted(properties.machineTravelZ) + " in " + quotedGroup("machine") + " so "
        + "both moves start from a height you set, or set " + quoted(properties.machineHomeAtStart) + " to Off and position the "
        + "tool yourself."));
    } else {
      warning(localize(quoted(properties.probeOnStart) + " = " + quotedValue(properties.probeOnStart, "Probe Z") + " rapids to the stored "
        + "X0 Y0 before this job has established any Z the post can move in, so that traverse happens "
        + "at whatever height the tool is left at -- position it clear of the stock, clamps and "
        + "fixtures before starting the program. The probe that follows searches " + quoted(properties.probeG38Target) + " DOWN FROM "
        + "that height, so set the target deep enough to reach the stock from where you leave the tool."
        + " " + quoted(properties.machineTravelZ) + " removes both, by establishing a Z the post can move in itself."));
    }
  }

  // Reads the same fixedZEstablishedInFile() the park itself reads, so the two cannot disagree. A
  // warning and not a guard: Fusion's own retract covers an ordinary milling job.
  // TWIN #4 -- the file half is writeMachineParkXY()'s.
  if (getProperty(properties.machineParkAtEnd) == "Machine" && !fixedZEstablishedInFile()) {
    warning(localize(quoted(properties.machineParkAtEnd) + " = machine X0 Y0 crosses the bed to the homing corner, but "
      + "this job establishes no fixed Z reference to retract in, so the tool makes that crossing "
      + "at whatever Z the last operation left it at. Enter " + quoted(properties.machineTravelZ) + ", or park at work "
      + "X0 Y0."));
  }

  // "Home at Job Start" is not required for G53: declaring axes homed vouches for the frame, and the firmware
  // decides if that is enough. Only GRBL refuses: homing on, it boots in Alarm (HOMING_INIT_LOCK, grbl/main.c,
  // v1.1h). Marlin's lock is the build option NO_MOTION_BEFORE_HOMING.
  if (fw != eFirmware.GRBL && fixedZEstablishedInFile() && !homesAtJobStart()) {
    warning(localize("This job moves in the machine's own Z frame (G53), but " + quoted(properties.machineHomeAtStart) + " is "
      + "Off, so those moves are measured against whatever machine zero the board currently holds "
      + "rather than one this job established. " + fw + " may well run them anyway -- unlike GRBL it "
      + "has no unconditional lock on motion before homing. Home the machine at the controller before "
      + "starting this file, or set " + quoted(properties.machineHomeAtStart) + " to Home."));
  }

  // Pause or macro, and a macro-loaded first tool, as on a one-tool job. PV-13.
  // TWIN #16 -- the file half is toolChange()'s, at the hand-over.
  // TWIN #18 -- and toolChangeMacroResume()'s, at the return.
  if (getProperty(properties.toolChangeMode) != "Refuse"
      && (countDistinctTools() > 1 || firstToolChangeIsHandedOver())
      && !fixedZEstablishedInFile()) {
    warning(localize(quoted(properties.toolChangeMode) + " is \"" + (toolChangeIsMacro()
      ? "Sender or firmware macro changes it\", but this job establishes no fixed Z reference, so the "
        + "post can neither lift the tool before the macro runs nor return it to a known height "
        + "afterwards -- the next move starts from wherever the macro left it"
      : "Manual change at a pause\", but this job establishes no fixed Z reference, so the post cannot "
        + "lift the tool before handing it to you -- the pause happens at whatever height the last "
        + "operation ended at, and the re-probe after it rapids to the part origin from there")
      + ". Enter " + quoted(properties.machineTravelZ) + " in " + quotedGroup("machine") + "."));
  }

  // Shares probePointMachinedBefore() with the file half but counts every boundary a probe can happen at,
  // not only those written: it over-reports, the safe side for a datum. PV-7.
  // TWIN #11 -- the file half is partProbe()'s, two hand-built predicates over the same sections.
  if (getProperty(properties.toolChangeMode) != "Refuse") {
    var changeReprobes = changeReprobesZ0();
    var returnReprobes = (changeMode == "Probe Z" || changeMode == "Jog XY & Probe Z");
    var hazardBoundaries = 0;
    var hazardCutters = [];
    var hazardSeen = {};
    var hazardZMin = undefined;
    for (var si = 1; si < getNumberOfSections(); ++si) {
      var sec = getSection(si);
      var secTool = sec.getTool();
      if (secTool.number == 0 || secTool.isJetTool()) {
        continue;
      }
      var prevSec = getSection(si - 1);
      var secWo = sec.getWorkOffset();
      if (secWo == 0) { secWo = 1; }
      var prevWo = prevSec.getWorkOffset();
      if (prevWo == 0) { prevWo = 1; }
      var probesHere = (changeReprobes && secTool.number != prevSec.getTool().number)
                    || (returnReprobes && secWo != prevWo);
      if (!probesHere) {
        continue;
      }
      var hazard = probePointMachinedBefore(si, secWo);
      if (hazard == undefined) {
        continue;
      }
      ++hazardBoundaries;
      if (hazardZMin == undefined || hazard.zMin < hazardZMin) {
        hazardZMin = hazard.zMin;
      }
      for (var hi = 0; hi < hazard.names.length; ++hi) {
        if (!hazardSeen[hazard.names[hi]]) {
          hazardSeen[hazard.names[hi]] = true;
          hazardCutters.push(hazard.names[hi]);
        }
      }
    }
    if (hazardBoundaries > 0) {
      warning(localize("This job re-probes work Z0 at a point it has already machined. Every part probe "
        + "touches off at " + probePointDescription() + ", and " + hazardCutters.join(", ") + " cuts "
        + "through that point, down to Z" + xyzFormat.format(hazardZMin) + ". At "
        + hazardBoundaries + " later boundar" + (hazardBoundaries == 1 ? "y" : "ies")
        + " the post re-probes Z0 there: where the tool lands on that machined surface instead of the "
        + "original stock top it writes the machined depth as Z0, and every cut after it goes that much "
        + "deeper -- Fusion computed those depths against the original datum. Move the touch-point onto "
        + "uncut material with " + quoted(properties.probeOffsetXY) + " in " + quotedGroup("probe") + ", or set " + quoted(properties.toolChangeZ0Correction)
        + " to " + quotedValue(properties.toolChangeZ0Correction, "Manual") + ". This pass reports every "
        + "boundary where a re-probe CAN happen; the file itself warns only at the probes that are "
        + "actually written."));
    }
  }

  // Macro-flow warnings: the post emits a token and cannot see whether anything acts on it.
  if (toolChangeIsMacro() && countDistinctTools() > 1) {
    var senderId = getProperty(properties.toolChangeSender);

    if (toolChangeNeedsSenderIntercept()) {
      warning(localize(quoted(properties.toolChangeSender) + " is \"" + toolChangeSenderTitle() + "\", so this job "
        + "hands each change over with M6 -- a command stock Grbl and grblHAL do not execute. It works "
        + "only because the sender removes the M6 from the stream and runs its own tool-change routine "
        + "instead, and the post cannot check that yours is set up to do it. If the sender is not "
        + "configured for tool changes the M6 reaches the controller and answers error:20, stopping the "
        + "job with the tool in the cut; if it is configured to IGNORE them, the change is dropped "
        + "silently and the rest of the job is cut with the tool already fitted. Test one change on air "
        + "before trusting it. If this machine runs FluidNC, choose " + quotedValue(properties.toolChangeSender, "FluidNC") + " instead: that "
        + "firmware executes the M6 itself, and a sender configured to strip it removes the one token it "
        + "acts on."));
    }

    // Unlike the intercept warning above, FluidNC never errors: it acts on M6 only where config.yaml says to,
    // so the failure is silence. The 3.9.0 bound is the changer's -- src/ToolChangers/ exists at v3.9.0 and
    // 404s at v3.8.0. FR-1.
    if (senderId == "FluidNC") {
      warning(localize(quoted(properties.toolChangeSender) + " is " + quotedValue(properties.toolChangeSender, "FluidNC") + ", so this job hands each "
        + "change over with an M6 the FIRMWARE executes -- nothing intercepts it, and a sender set up to "
        + "strip it would remove the token FluidNC acts on. What the firmware then does is in "
        + "config.yaml, which the post cannot read: it dispatches to the tool changer declared as \"atc:\" "
        + "under the spindle, or runs the macro named by \"m6_macro:\". WITH NEITHER DECLARED it accepts "
        + "the line, changes nothing and reports nothing -- the job cuts on with the tool already fitted "
        + "and no line in the file says so. A changer needs FluidNC 3.9.0 or later. Confirm the config "
        + "before this job runs, and test one change on air."));
    }

    if (senderId == "RepRap") {
      warning(localize(quoted(properties.toolChangeSender) + " is the RepRapFirmware tool table, so this job hands "
        + "each change over with a bare T word. That word errors unless every tool number it uses is "
        + "declared with M563 in config.g, and it corrects nothing unless tpost<n>.g applies a "
        + "tool-length offset. Both are on the machine and neither is visible to the post."));

        // No machine-frame warning: RRF's G53 drops the tool offset as well as the workplace offset, so "Machine
        // Travel Z" is a carriage height there as on GRBL. DoStraightMove()/DoArcMove(), src/GCodes/GCodes.cpp,
        // 2.05 through 3.6.0. PR-25.
    }

    if (changeReprobesZ0()) {
      warning(localize(quoted(properties.toolChangeZ0Correction) + " is " + quotedValue(properties.toolChangeZ0Correction, "Probe") + " while "
        + "changes are handed to \"" + toolChangeSenderTitle() + "\", so the post probes Z again after "
        + "the macro returns and overwrites whatever the macro measured. That is right for a handler "
        + "that only pauses and wrong for one that re-zeroes or applies a tool offset -- a FluidNC "
        + "\"atc:\" with a tool setter is the second kind, measuring the new tool and shifting the whole Z "
        + "frame with G43.1 -- there it asks you to fit the touch plate at every change for a measurement "
        + "already made. Set it to " + quotedValue(properties.toolChangeZ0Correction, "Offset") + " if the macro establishes Z0."));
    }
  }

  // Two job-wide warnings, each knowable at onOpen(). PV-10.
  if (countDistinctTools() > 1) {
    // Not refused: the operator may apply G43.1 through their sender by hand while the job waits, which
    // the post can no more see than a macro's tool table.
    if (toolLengthCorrection() == "Offset" && getProperty(properties.toolChangeMode) == "Pause") {
      warning(localize(quoted(properties.toolChangeZ0Correction) + " is " + quotedValue(properties.toolChangeZ0Correction, "Offset") + " while "
        + quoted(properties.toolChangeMode) + " is " + quotedValue(properties.toolChangeMode, "Pause") + ". A manual pause hands over to nothing "
        + "-- the post stops the program and waits -- so unless YOU apply a tool-length offset at that "
        + "pause, no offset is applied and every part's stored Z0 still measures from the tool just "
        + "removed. Choose " + quotedValue(properties.toolChangeZ0Correction, "Manual") + " if that is what you do, or " + quotedValue(properties.toolChangeZ0Correction, "Probe")
        + " to have it measured."));
    }

    // The file says it at each change and each return, where a person reading the dialog would not look.
    // TWIN #17 -- the file half is toolChange()'s "Manual" arm, on the multi-part case alone.
    if (toolLengthCorrection() == "Manual" && collectDistinctOffsets().length > 1) {
      warning(localize(quoted(properties.toolChangeZ0Correction) + " is " + quotedValue(properties.toolChangeZ0Correction, "Manual") + " "
        + "and this job cuts " + collectDistinctOffsets().length + " parts. Re-zeroing at the pause "
        + "corrects the ONE part whose work offset is active there; every other part's stored Z0 was "
        + "measured by the tool being removed. The post marks those parts stale, so a return to one "
        + "re-probes it where the mode can and says so in the file where it cannot -- but nothing "
        + "corrects them at the pause itself, and no hand-zero there reaches them."));
    }
  }

  // The manual change position's warned half: a valid file that may not do what the operator meant. The
  // half no machine can run is refused among the guards.
  if (countDistinctTools() > 1) {
    var tcz = toolChangePosZ();
    var tcAnyPos = (toolChangePosX() != undefined) || (toolChangePosY() != undefined)
                || (tcz != undefined);

    // Not refused: a change position clear of the fixtures may legitimately sit below the height that
    // clears them -- that is the point of bringing the spindle down to where a person can work at it.
    if (tcz != undefined && getProperty(properties.toolChangeMode) == "Pause"
        && fixedZEstablishedInFile() && tcz < parseMachineTravelZ()) {
      warning(localize(quoted(properties.toolChangePositionZ) + " is " + tcz + ", below the " + quoted(properties.machineTravelZ) + " of "
        + parseMachineTravelZ() + " -- the tool is held LOWER during the change than the height you "
        + "declared clears your fixtures. That is right only if the change position itself is clear of "
        + "everything on the bed at that height; the post crosses the bed at the travel height and "
        + "descends to this one only once it has arrived."));
    }

    // Warned, not dropped: an ignored coordinate gets trusted unseen, as the removed Tool Change X/Y/Z was for
    // years while it moved with every part origin.
    if (tcAnyPos && toolChangeIsMacro()) {
      warning(localize("A tool change position is set, but " + quoted(properties.toolChangeMode) + " hands changes to \""
        + toolChangeSenderTitle() + "\", so the post does not use it. Moving the tool to a change "
        + "position belongs to whatever performs the change -- it knows where its changer, its sensor "
        + "or its park is, and the post does not. The post still retracts to " + quoted(properties.machineTravelZ) + " "
        + "before the hand-over and returns there afterwards."));
    }
  }

  // No g-code sets the stepper idle timer, and one warning covers Grbl, grblHAL and FluidNC: the post's one
  // "Grbl" answer cannot tell them apart. Both change modes -- a macro hand-over idles the machine too. FR-2.
  if (fw == eFirmware.GRBL && getProperty(properties.toolChangeMode) != "Refuse"
      && countDistinctTools() > 1) {
    // Grbl/grblHAL: st_go_idle() disables the drivers $1 ms after the buffer drains, default 25 (stepper.c,
    // defaults.h, Grbl 1.1). FluidNC: idle_ms under stepping:, default 255 (Stepping.cpp, v3.9.6). 255 means
    // never on both (Protocol.cpp:764), so stock FluidNC holds the axes and stock Grbl lets go.
    warning(localize((toolChangeIsMacro()
        ? "This job hands each tool change to \"" + toolChangeSenderTitle() + "\", and the post writes "
          + "no pause for it -- but the machine still stands idle from the moment the tool stops moving "
          + "until whatever performs the change lets the job resume, and that interval is not the post's "
          + "to bound"
        : "This job stops the program (M0) for a manual tool change")
      + ". The steppers may de-energise while it stands there, and the "
      + "timer is the one thing your two possible firmwares spell differently: stock Grbl and grblHAL "
      + "drop them $1 milliseconds after the motion buffer drains -- 25 on a stock build -- and FluidNC "
      + "after idle_ms under stepping: in config.yaml, which ships at 255. ON BOTH, 255 MEANS STAY "
      + "ENERGISED rather than a 255 ms delay, so a stock FluidNC holds the axes here and a stock Grbl "
      + "lets go of them. Either way position is still counted, so nothing is lost unless an axis "
      + "actually moves; a gantry nudged while the collet is loosened, or a Z that back-drives with no "
      + "holding torque, is enough, and every cut after the change is then offset by an amount nothing "
      + "reports. Set $1=255 on Grbl or grblHAL; on FluidNC that is idle_ms: 255, and it is already the "
      + "default unless someone changed it. The post can set neither for you -- $ settings are not "
      + "G-code and GRBL accepts them only when it is Idle, and the FluidNC value is a file on the "
      + "controller."));
  }

  // GRBL only: Marlin re-homes here instead of rapiding, and an RRF machine homed to its minima already
  // rests on the coordinate this asks for. CR-10.
  // TWIN #6 -- the file half is writeMachineParkXY()'s, same firmware and same property.
  if (fw == eFirmware.GRBL && getProperty(properties.machineParkAtEnd) == "Machine") {
    // One warning for both "Grbl" firmwares: FluidNC also rests one pull-off inside machine zero, set_mpos()
    // writing _mpos at the trigger point (FluidNC/src/Machine/Homing.h, Homing.cpp, v3.9.6). FR-2.
    warning(localize(quoted(properties.machineParkAtEnd) + " = machine X0 Y0 sends the tool to where the homing switches "
      + "tripped, not to where homing left the machine -- and that is true of both firmwares this "
      + "\"Grbl\" answer covers. On a stock Grbl build HOMING_FORCE_SET_ORIGIN is off, so machine zero "
      + "sits at the trigger point and the axes rest one pull-off inside it -- $27. A stock FluidNC does "
      + "the same: mpos_mm is the machine position OF THE SWITCH and homing writes it there, then pulls "
      + "off by pulloff_mm, which is set per motor rather than per axis. Either way this park drives X "
      + "and Y back onto the switches, and with hard limits enabled the job ends in Alarm rather than "
      + "parked. It is correct only where machine zero is where homing LEAVES the axis -- a Grbl built "
      + "with HOMING_FORCE_SET_ORIGIN, or a FluidNC whose mpos_mm already accounts for the pull-off, one "
      + "a rebuild and the other a config line, and the post can read neither. Otherwise park at work "
      + "X0 Y0: raising the pull-off does not help, machine zero staying where the switch tripped."));
  }

  // set_axis_is_at_home() zeroes position_shift, never coordinate_system[] (Marlin motion.cpp,
  // 2.1.2.5) -- and a single-offset job never re-selects a register, so the next file starts zeroed.
  // TWIN #5 -- the file half is writeMachineParkXY()'s, gated on the same firmware and property.
  if (fw == eFirmware.MARLIN && getProperty(properties.machineParkAtEnd) == "Machine") {
    warning(localize(quoted(properties.machineParkAtEnd) + " = machine X0 Y0 HOMES X and Y on Marlin rather than rapiding "
      + "there, and homing zeroes position_shift -- the work origin this file established. The stored "
      + "G54-G59 registers survive it, but an ordinary single-offset job never re-selects one, so a "
      + "second file run after this one (the two-file answer to a tool change) starts against a zeroed "
      + "origin. Park at work X0 Y0, or establish the origin again at the start of the next file."));
  }

  // The same check on single-coordinate fields: parseMachineCoordinate() answers undefined for a typo as for
  // an empty field, and undefined means "not set" -- so "-12mm" in "Machine Travel Z" silently drops the
  // frame. "Manual Position Z" may be set alone, so it is here; the X Y pair has its own loop below.
  var coordProps = [properties.machineTravelZ, properties.toolChangePositionZ];
  for (var c = 0; c < coordProps.length; ++c) {
    var rawCoord = getProperty(coordProps[c]);
    if (rawCoord != "" && parseMachineCoordinate(rawCoord) == undefined) {
      warning(localize("\"" + coordProps[c].title + "\" is set to \"" + rawCoord + "\", which is not a "
        + "signed decimal number of millimetres -- so the post reads the field as EMPTY, which is the "
        + "answer \"not set\", and the motion it controls is simply not emitted. Give a plain number "
        + "such as -12 or -12.5, with no unit suffix and no other characters."));
    }
  }

  // Again on the X Y pair fields, each naming its own fallback. Warned, not refused: the manual position's
  // bad pair is refused below only on the multi-tool manual flow that reads it, and 0, 0 -- the shipped
  // probe offset -- is legal.
  var pairProps = [
    { prop: properties.probeOffsetXY,
      fallback: "the post reads the offset as 0, 0 and probes at the part origin itself" },
    { prop: properties.toolChangePositionXY,
      fallback: "the post reads the field as EMPTY, which is the answer \"not set\", and the tool change "
              + "happens above the last cut with no excursion at all" }
  ];
  for (var pp = 0; pp < pairProps.length; ++pp) {
    var rawPair = getProperty(pairProps[pp].prop);
    if (rawPair != "" && parseXYPair(rawPair) == undefined) {
      warning(localize("\"" + pairProps[pp].prop.title + "\" is set to \"" + rawPair + "\", which is not "
        + "an X Y pair the post can read -- so " + pairProps[pp].fallback + ". Give TWO signed decimal "
        + "numbers of millimetres separated by a comma, such as -10, -400. Whitespace around the comma "
        + "is ignored; anything else in the field is not."));
    }
  }

  // Group 8's dialect check: one laser field holds both dialects' values, so a mismatch is expressible.
  // Warned, as group 9's is below. Jet tools only -- a milling job emits no laser code whatever it holds.
  if (jetToolInJob()) {
    // Mismatch iff exactly one side is GRBL: the "Mrln:" values serve RepRapFirmware too (M106, M42 and M3
    // are emitted on both), so the coolant check's unlabelled-means-skip scoping would let a GRBL value pass on
    // RRF. Silent where the guard below refuses anyway, so one field draws one complaint, not two.
    var laserId = getProperty(properties.laserOutput);
    var laserRefused = (fw == eFirmware.GRBL && (laserId == "M106" || laserId == "M42"));
    var laserFw = outputCodeFirmware(properties.laserOutput);
    if (!laserRefused && laserFw != undefined
        && (laserFw == eFirmware.GRBL) != (fw == eFirmware.GRBL)) {
      warning(localize("\"" + properties.laserOutput.title + "\" is \""
        + outputCodeTitle(properties.laserOutput) + "\", which this post lists as " + laserFw
        + ", and this job is posted for " + fw + ". The post emits what you pick, so a controller that "
        + "does not implement it answers the line as an unsupported command and the job stops "
        + "mid-operation with the head over the work -- and the S it carries is on the wrong scale "
        + "besides, the GRBL values driving 0-1000 against $30 and the others a 0-255 byte. Choose the "
        + "\"" + (fw == eFirmware.GRBL ? "Grbl" : "Mrln") + ":\" values in " + quotedGroup("laser") + "."));
    }
  }

  // writeCoolantChannel() emits the chosen code with no firmware test. Only configured channels (Mode not
  // Off, the shipped value) are checked, and only labelled values: M7/M8 are every firmware's, their
  // conditions warned below. So this fires for a Marlin value on GRBL alone. CR-24, PV-12, MR-1.
  var jobDialect = outputDialectLabel(fw);
  if (jobDialect != undefined) {
    var coolantCodeProps = [];
    if (getProperty(properties.coolantChannelAMode) != eCoolant.Off) {
      coolantCodeProps.push(properties.coolantChannelAOn);
    }
    if (getProperty(properties.coolantChannelBMode) != eCoolant.Off) {
      coolantCodeProps.push(properties.coolantChannelBOn);
    }
    var wrongDialect = [];
    for (var cd = 0; cd < coolantCodeProps.length; ++cd) {
      var codeFw = outputCodeFirmware(coolantCodeProps[cd]);
      if (codeFw != undefined && codeFw != fw) {
        // The title, not the id: a Marlin id is a mode name, not the g-code.
        wrongDialect.push("\"" + coolantCodeProps[cd].title + "\" is \"" + outputCodeTitle(coolantCodeProps[cd])
          + "\", which this post lists as " + codeFw);
      }
    }
    // One warning, not one per channel: both channels are set for one firmware, fail together, and share one
    // remedy.
    if (wrongDialect.length > 0) {
      warning(localize("This job is posted for " + fw + ", and "
        + (wrongDialect.length == 1 ? "a coolant code it will emit belongs"
                                    : "coolant codes it will emit belong")
        + " to another firmware: " + wrongDialect.join("; ") + ". The post emits what you picked, so a "
        + "controller that does not implement it answers the line as an unsupported command "
        + "and the job stops mid-operation with the tool in the cut. Choose "
        + quotedValue(properties.coolantChannelAOn, "M7") + " or " + quotedValue(properties.coolantChannelAOn, "M8")
        + " in " + quotedGroup("coolant") + ", or " + quotedValue(properties.coolantChannelAOn, "Use custom")
        + " and a file of your own if your controller takes something this post does not list."));
    }
  }

  // No firmware guarantees M7/M8: each has them only under a build or config condition the post cannot
  // read, so a job switching coolant with them is warned once, in its firmware's terms. CR-24, MR-1.
  var coolantCodes = [];
  if (getProperty(properties.coolantChannelAMode) != eCoolant.Off) {
    coolantCodes.push(getProperty(properties.coolantChannelAOn));
  }
  if (getProperty(properties.coolantChannelBMode) != eCoolant.Off) {
    coolantCodes.push(getProperty(properties.coolantChannelBOn));
  }
  var usesM7orM8 = coolantCodes.indexOf("M7") != -1 || coolantCodes.indexOf("M8") != -1;

  // Stock grbl 1.1 compiles M7 only under ENABLE_M7, shipped commented out, so M7 answers error:20
  // mid-section (grbl/gcode.c, v1.1h); FluidNC never errors, acting only where a pin is declared
  // (hasMist(), FluidNC/src/GCode.cpp 3.9.1), and cuts dry.
  if (usesM7orM8 && fw == eFirmware.GRBL) {
    warning(localize("This job switches coolant with M7/M8, and neither Grbl firmware guarantees "
      + "them. Stock Grbl 1.1 compiles M7 only when ENABLE_M7 is uncommented in grbl/config.h and it "
      + "ships commented out -- on such a build the M7 answers error:20 and stops the job mid-operation "
      + "with the tool in the cut, while M8 is always compiled in. FluidNC never errors here: it acts "
      + "on M7 only where config.yaml declares a coolant mist_pin and on M8 only where it declares a "
      + "flood_pin, and otherwise accepts the line and does nothing -- so the job cuts dry and nothing "
      + "in the file says so. Confirm the build or the config before this job runs; the post can read "
      + "neither."));
  }

  // Marlin has M7 under COOLANT_MIST and M8 under COOLANT_FLOOD or AIR_ASSIST, and answers a code it lacks
  // with "echo:Unknown command" and carries on (Marlin/src/gcode/control/M7-M9.cpp, gcode.cpp, bugfix-2.1.x).
  if (usesM7orM8 && fw == eFirmware.MARLIN) {
    warning(localize("This job switches coolant with M7/M8, which Marlin has only when built with "
      + "COOLANT_MIST for M7 or COOLANT_FLOOD for M8, and a COOLANT_MIST_PIN or COOLANT_FLOOD_PIN your "
      + "board defines. A build without them answers \"Unknown command\" and carries on -- so the job cuts "
      + "dry and nothing in the file says so. Confirm the build before this job runs; the post cannot "
      + "read it."));
  }

  // RepRapFirmware has no case for M7/M8/M9: its default arm runs /sys/M7.g and the like where they exist,
  // and otherwise reports the code unsupported (src/GCodes/GCodes2.cpp, 3.5-dev).
  if (usesM7orM8 && fw == eFirmware.REPRAP) {
    warning(localize("This job switches coolant with M7/M8, which RepRapFirmware does not implement "
      + "itself: it runs /sys/M7.g, /sys/M8.g and /sys/M9.g where you have written them, and otherwise "
      + "reports the code as unsupported and switches nothing -- so the job cuts dry. Confirm those "
      + "macros are on the board before this job runs; the post cannot read them."));
  }

  // The same dry cut by a route the post can see: the job asks for a coolant level neither channel Mode
  // carries. One warning per level, the remedy being per level. PV-12.
  // TWIN #3 -- the file half is setCoolant()'s, per occurrence. One deliberate difference: this pre-flight
  // is silent where both channel Modes are Off, that line is not.
  var dryRequests = unmatchedCoolantRequests();
  for (var d = 0; d < dryRequests.length; ++d) {
    warning(localize("This job asks for \"" + dryRequests[d].level + "\" coolant and neither channel is "
      + "set to it -- " + quoted(properties.coolantChannelAMode) + " is \"" + getProperty(properties.coolantChannelAMode) + "\" and "
      + quoted(properties.coolantChannelBMode) + " is \"" + getProperty(properties.coolantChannelBMode) + "\". "
      + (dryRequests[d].names.length == 1 ? "The operation that asks" : "The operations that ask")
      + " for it: " + dryRequests[d].names.join(", ") + ". The post emits no coolant code for them and "
      + "the job runs them DRY, which is a burnt cutter or a scorched edge in the materials coolant is "
      + "there for. Set one channel's Mode to \"" + dryRequests[d].level + "\" in " + quotedGroup("coolant") + ", or "
      + "change what those operations ask for in Fusion."));
  }

  // --- Guards -----------------------------------------------------------------------------------
  // Refusals, most basic first; each returns after its error().

  // Refused, not defaulted: the value is the retract after a probe and group 3's G1-to-G0 threshold, and
  // no fixed height is right both over tall stock and under a short Z.
  if (parseSafeZExpr(getProperty(properties.probeSafeZ)).mode == eSafeZ.ERROR) {
    error(localize(quoted(properties.probeSafeZ) + " is set to \"" + getProperty(properties.probeSafeZ)
      + "\", which is not a Safe Z expression the post can read. It is the retract after a probe and the "
      + "rapid threshold in " + quotedGroup("mapRapids") + " alike, so no fixed height can stand in for it. "
      + "Give a plain number of millimetres, or Feed:, Retract: or Clearance: followed by one -- no sign, "
      + "no unit suffix."));
    return;
  }

  // The fan and pin output modes, in one table because groups 1, 8 and 9 own the same mistakes.
  // jetOnly: the laser field is read only by a section that fires a beam, so a milling job posts whatever it
  // holds. refuseOnGrbl: false on group 9, which warns instead -- the dialect warning above (PV-16).
  // No off code here: coolantOffCode() derives it from this row, so an on/off mismatch cannot be set.
  var outputModeProps = [
    { mode: properties.jobSpindleControl, number: properties.jobSpindlePinFan, group: "1 - Job",
      refuseOnGrbl: true },
    { mode: properties.laserOutput, number: properties.laserMarlinPinFan, group: "8 - Laser",
      refuseOnGrbl: true, jetOnly: true },
    { mode: properties.coolantChannelAOn,
      number: properties.coolantChannelAPinFan, group: "9 - Coolant",
      refuseOnGrbl: false, gate: properties.coolantChannelAMode },
    { mode: properties.coolantChannelBOn,
      number: properties.coolantChannelBPinFan, group: "9 - Coolant",
      refuseOnGrbl: false, gate: properties.coolantChannelBMode }
  ];
  for (var om = 0; om < outputModeProps.length; ++om) {
    // A channel whose Mode is Off is unconfigured, and its codes were never chosen. CR-24.
    if (outputModeProps[om].gate != undefined
        && getProperty(outputModeProps[om].gate) == eCoolant.Off) {
      continue;
    }
    if (outputModeProps[om].jetOnly && !jetToolInJob()) {
      continue;
    }

    var omMode = getProperty(outputModeProps[om].mode);
    if (omMode != "M106" && omMode != "M42") {
      continue;
    }

    // Neither code is GRBL's: grbl 1.1 answers an M word it was not compiled with as error:20 and stops
    // there, and FluidNC implements neither.
    if (fw == eFirmware.GRBL && outputModeProps[om].refuseOnGrbl) {
      error("\"" + outputModeProps[om].mode.title + "\" is set to a "
        + (omMode == "M106" ? "fan (M106)" : "pin (M42)") + " output and this job is posted for GRBL,"
        + " which has neither command. The controller answers the line with error:20 and stops the job"
        + " there, with the tool in the cut and the output never switched on. Those two modes are"
        + " Marlin and RepRapFirmware only -- in \"" + outputModeProps[om].group + "\", choose a mode"
        + " your firmware has, or set " + quoted(properties.jobSelectedFirmware) + " to the one this machine actually runs.");
      return;
    }

    // Pin mode only. Fan 0 is a real fan and the default, so the same test on the fan arm would refuse
    // the commonest correct setting; pin 0 is nobody's laser or router, and Marlin protects it anyway.
    if (omMode == "M42" && getProperty(outputModeProps[om].number) == 0) {
      error("\"" + outputModeProps[om].mode.title + "\" is set to a pin (M42) output and \""
        + outputModeProps[om].number.title + "\" is still 0, which names no output this post can"
        + " believe you chose. M42 would be emitted against pin 0 -- refused by Marlin as a protected"
        + " pin on most boards, and an output nobody picked on the rest. Set \""
        + outputModeProps[om].number.title + "\" to the pin your hardware is wired to, or choose the"
        + " fan mode if it is on a fan header, which M42 cannot reach at all.");
      return;
    }
  }

  // Refused rather than warned, and here rather than at the boundary: the alternative is a file that
  // cuts every operation with whichever tool is in the spindle, at the other tools' feeds and speeds.
  if (countDistinctTools() > 1 && getProperty(properties.toolChangeMode) == "Refuse") {
    error("This job uses " + countDistinctTools() + " tools and " + quoted(properties.toolChangeMode) + " is " + quotedValue(properties.toolChangeMode, "Refuse")
      + ". This post changes no tool itself on any supported firmware -- it emits no M6"
      + " on this setting, which stock Grbl and grblHAL answer with error:20 anyway. Post one tool per"
      + " file; or set " + quoted(properties.toolChangeMode) + " to " + quotedValue(properties.toolChangeMode, "Pause") + " to stop at each boundary and"
      + " swap the tool by hand; or to " + quotedValue(properties.toolChangeMode, "Macro") + " if your sender or firmware"
      + " owns a tool table and you have configured it to do the change.");
    return;
  }

  // The macro flow's refusals: each is a hand-over to something that is not there. A first-tool hand-over
  // sends the same token to the same handler, so it owes the same refusals. PV-13.
  if (toolChangeIsMacro() && (countDistinctTools() > 1 || firstToolChangeIsHandedOver())) {
    // Marlin has no tool-length register at all, so there is nothing for a macro to write an offset
    // into and no sender in the list that speaks to it. design.md -> Tool changes.
    if (fw == eFirmware.MARLIN) {
      error(quoted(properties.toolChangeMode) + " is " + quotedValue(properties.toolChangeMode, "Macro") + ", but the firmware is"
        + " Marlin, which has no tool-length offset register -- there is nothing for a macro to correct"
        + " and no supported sender intercepts a tool change for it. M6 reaches Marlin as an unknown"
        + " command and the job carries on with the wrong cutter. Use " + quotedValue(properties.toolChangeMode, "Pause") + ","
        + " which re-probes Z0 with the new tool and is the only correction Marlin has.");
      return;
    }

    var handler = getProperty(properties.toolChangeSender);

    if (handler == "RepRap" && fw != eFirmware.REPRAP) {
      error(quoted(properties.toolChangeSender) + " is the RepRapFirmware tool table, but this job is posted for "
        + fw + ". The bare T word that route emits is a tool change on RRF and nothing on any other"
        + " firmware -- GRBL parses it and takes no action, so every change would be skipped silently."
        + " Choose the sender that runs this machine, or " + quotedValue(properties.toolChangeSender, "Other") + " with a macro file of your own.");
      return;
    }

    if (toolChangeNeedsGrblDialect() && fw != eFirmware.GRBL) {
      // Two texts: FluidNC needs the GRBL dialect but no sender, so the sender text would name a party it lacks
      // and offer the wrong remedy, "Other". Only RepRap reaches here; the Marlin guard returns first. FR-1.
      if (handler == "FluidNC") {
        error(quoted(properties.toolChangeSender) + " is " + quotedValue(properties.toolChangeSender, "FluidNC") + ", but this job is posted for " + fw
          + ". FluidNC speaks the dialect this post writes for \"Grbl\", which is the " + quoted(properties.jobSelectedFirmware)
          + " answer to choose for it -- and \"T<n> M6\" is not the token a change takes on " + fw
          + ", where the T word alone IS the change. Set " + quoted(properties.jobSelectedFirmware) + " to \"Grbl\" if this machine"
          + " runs FluidNC, or " + quoted(properties.toolChangeSender) + " to " + quotedValue(properties.toolChangeSender, "RepRap") + " if it runs "
          + fw + ".");
      } else {
        error(quoted(properties.toolChangeSender) + " is \"" + toolChangeSenderTitle() + "\", which is a GRBL sender,"
          + " but this job is posted for " + fw + ". Choose the handler that runs this machine, or"
          + " " + quotedValue(properties.toolChangeSender, "Other") + " with a macro file of your own.");
      }
      return;
    }

    if (handler == "Other" && getProperty(properties.toolChangeMacroFile) == "") {
      error(quoted(properties.toolChangeSender) + " is " + quotedValue(properties.toolChangeSender, "Other") + ", which hands each change over to the file named in"
        + " " + quoted(properties.toolChangeMacroFile) + " -- and that field is empty, so there is nothing to hand over to. Name"
        + " the file, or choose the sender that runs this machine.");
      return;
    }
  }

  // Flow 1's position guards. Refused rather than warned, because each names a move the post would have
  // to invent a coordinate for, and every one it could invent is a real position the tool would rapid to.
  if (countDistinctTools() > 1 && getProperty(properties.toolChangeMode) == "Pause") {
    var posX = toolChangePosX();
    var posY = toolChangePosY();
    var posZ = toolChangePosZ();

    // The raw field is tested because a typo parses to undefined, as a blank does, and would silently drop
    // the position the operator set.
    if (getProperty(properties.toolChangePositionXY) != "" && posX == undefined) {
      error(quoted(properties.toolChangePositionXY) + " is set to \"" + getProperty(properties.toolChangePositionXY)
        + "\", which is not an X Y pair this post can read, so it would be taken as EMPTY and this"
        + " job's manual changes would happen above the last cut instead of at the position you set."
        + " Give two signed decimal numbers of millimetres separated by a comma -- -10, -400 -- or"
        + " empty the field to change the tool where the cut ended.");
      return;
    }

    if ((posX != undefined || posZ != undefined) && !fixedZEstablishedInFile()) {
      // The predicate the file reads: toolChangeMovesToPosition() answers false with no fixed Z reference, so
      // without this guard the fields would be accepted and then quietly not happen.
      error("A tool change position is set, but this job establishes no fixed Z reference -- there is no"
        + " machine frame to move in, and no height to cross the bed at before the tool gets there."
        + " Enter " + quoted(properties.machineTravelZ) + " and include Z in " + quoted(properties.machineHomedAxes) + ", both in " + quotedGroup("machine")
        + ", or clear the tool change position fields.");
      return;
    }

    // Guard B's requirement by a second route: a stored machine X/Y means nothing on a machine that has
    // never established one.
    if (posX != undefined && !machineHomesXY()) {
      error("A tool change position in X and Y is an absolute machine move, but " + quoted(properties.machineHomedAxes)
        + " does not include X and Y, so the machine has no X/Y frame for it to be measured"
        + " in. Declare XY (or XYZ) in " + quotedGroup("machine") + ", or clear the tool change position"
        + " fields.");
      return;
    }
  }

  // A named include file that does not exist only reaches error() inside loadFile(), by which point the
  // header and preamble are in the stream.
  var includeFileProps = [properties.includeStartFile, properties.includeStopFile];
  if (getProperty(properties.toolChangeMode) != "Refuse") {
    includeFileProps.push(properties.includeToolFile1);
    includeFileProps.push(properties.includeToolFile2);
  }
  if (toolChangeIsMacro() && getProperty(properties.toolChangeSender) == "Other") {
    includeFileProps.push(properties.toolChangeMacroFile);
  }
  // The four coolant files reach the same late error() through loadFile(), an OFF file possibly not until
  // onClose(). Gated on the enum beside each; an empty field warns in both channels. HB-7, CR-22, PV-12.
  // TWIN #2 -- the file half is writeCustomCoolantFile()'s, on the same enum gate.
  var coolantCustom = [
    { code: properties.coolantChannelAOn,
      files: [properties.coolantChannelAOnCustom, properties.coolantChannelAOffCustom] },
    { code: properties.coolantChannelBOn,
      files: [properties.coolantChannelBOnCustom, properties.coolantChannelBOffCustom] }
  ];
  for (var c = 0; c < coolantCustom.length; ++c) {
    if (getProperty(coolantCustom[c].code) != "Use custom") {
      continue;
    }
    // One selector reaches both of a channel's files, so an unnamed OFF file is reported even where the ON
    // file is named.
    for (var cf = 0; cf < coolantCustom[c].files.length; ++cf) {
      var customFile = coolantCustom[c].files[cf];
      if (getProperty(customFile) == "") {
        warning(localize("\"" + coolantCustom[c].code.title + "\" is " + quotedValue(coolantCustom[c].code, "Use custom") + ", which takes BOTH "
          + "of this channel's codes from files of your own -- and \"" + customFile.title + "\" is "
          + "empty. Nothing at all is emitted for it, so this channel never switches by that route. "
          + "Name the file, or choose one of the g-codes in the dropdown."));
        continue;
      }
      includeFileProps.push(customFile);
    }
  }
  for (var i = 0; i < includeFileProps.length; ++i) {
    var includeName = getProperty(includeFileProps[i]);
    if (includeName != "" && !FileSystem.isFile(includeFolder() + includeName)) {
      error("\"" + includeFileProps[i].title + "\" names \"" + includeName + "\", which is not a file"
        + " in the NC output folder " + includeFolder() + " -- check the spelling and the extension,"
        + " or clear the field.");
      return;
    }
  }

  // The field is the opt-in, so these fire only where it is FILLED; Guard B below decides whether the
  // job could afford to leave it empty.
  if (parseMachineTravelZ() != undefined) {
    // gcode.cpp (2.1.2.5) gates "case 53:" through "case 59:" in one #if, so a Marlin build has the
    // machine frame and the WCS registers or neither. Assumed, not refused.
    // TWIN #10 -- the file half is writeFixedZReference()'s, gated on the same firmware.
    if (fw == eFirmware.MARLIN) {
      warning(localize("This job moves in the machine's own Z frame with G53, which on Marlin is the "
        + "build option CNC_COORDINATE_SYSTEMS and is OFF in a stock configuration. The post assumes "
        + "your firmware was compiled with it; if it was not, Marlin reports G53 as an unknown command "
        + "and every travel-height move is silently skipped, leaving the tool wherever the last "
        + "operation ended. Check the build before running this file, or clear " + quoted(properties.machineTravelZ) + "."));
    }
    if (!machineHomesZ()) {
      error(quoted(properties.machineTravelZ) + " is a height in the machine's own homed Z frame, so it requires " + quoted(properties.machineHomedAxes) + " to include Z -- declare that this machine homes Z, or clear the field.");
      return;
    }
    // ">= 0" because zero is the switch, not the ceiling: limits_go_home() ends one pull-off below the
    // trigger and system_check_travel_limits() rejects only target > 0 (grbl 1.1f). PR-17.
    // TWIN #9 -- the file half is writeFixedZReference()'s, on the same firmware and parsed height.
    if (fw == eFirmware.GRBL && parseMachineTravelZ() >= 0) {
      warning(localize(quoted(properties.machineTravelZ) + " is " + parseMachineTravelZ() + ", which is at or above "
        + "machine zero. On a stock Grbl build (HOMING_FORCE_SET_ORIGIN off) and on a stock FluidNC "
        + "(mpos_mm at the switch) homing leaves every reachable Z negative, so a positive value is "
        + "above the top of travel -- it alarms at the first traverse with soft limits on, and drives Z "
        + "into its hard stop with them off. ZERO IS NOT THE CEILING EITHER: it is the point at which "
        + "the Z endstop tripped, because homing ends one pull-off below it, so a move to zero returns "
        + "the axis onto the switch and soft limits do not reject it. Set a height below machine zero by "
        + "at least the homing pull-off -- $27 on Grbl, pulloff_mm on the motor on FluidNC. If your "
        + "machine zeroes at the bed instead, either built with HOMING_FORCE_SET_ORIGIN or configured "
        + "with an mpos_mm that puts it there, a positive value is correct -- the post can read neither "
        + "and will warn every time."));
    }
  }

  // The Home-at-start test skips Marlin: its park (G28 X Y) re-homes instead of addressing the frame, so
  // needs no earlier homing -- unlike the Z retract above.
  if (getProperty(properties.machineParkAtEnd) == "Machine") {
    if (!machineHomesXY()) {
      error(quoted(properties.machineParkAtEnd) + " = machine X0 Y0 requires " + quoted(properties.machineHomedAxes) + " to include X/Y -- a machine's X0 Y0 is its homing corner, which means nothing on a machine that does not home.");
      return;
    }
    if (fw != eFirmware.MARLIN && !homesAtJobStart()) {
      error(quoted(properties.machineParkAtEnd) + " = machine X0 Y0 emits G53 on " + fw + ", which measures against a machine frame this job must have established, not one a previous power cycle left behind -- set " + quoted(properties.machineHomeAtStart) + " to Home, or park at work X0 Y0.");
      return;
    }
  }

  // No guard tells Marlin it has a single coordinate frame: gcode.cpp (2.1.2.5) puts G54-G59 in the same
  // #if ENABLED(CNC_COORDINATE_SYSTEMS) as G53, with G59.1-G59.3 -- nine selectable workspaces. Guard B
  // alone refuses a Marlin multi-part job.

  // Guard B -- a multi-part job must have the fixed Z frame: no single clearance height is meaningful across
  // WCS whose origins are known only after probing at runtime. The X/Y test is here, not with the Z frame,
  // because the multi-part workflow is what needs a homed X/Y. CR-13.
  if (collectDistinctOffsets().length > 1) {
    if (!fixedZEstablishedInFile()) {
      error("A multi-part job needs a Z frame that outlives one work offset -- the tool must clear the fixtures on its way between parts, and no single clearance height is meaningful across WCS whose origins are only known after probing at runtime. A homed machine already has that frame: set " + quoted(properties.machineHomedAxes) + " to include Z in " + quotedGroup("machine") + ", then enter " + quoted(properties.machineTravelZ) + " beside it -- or post one job per part.");
      return;
    }
    if (!homedXY) {
      error("A multi-part job traverses between STORED work offsets, which are repeatable only on a machine with a homed X/Y zero -- set " + quoted(properties.machineHomedAxes) + " to XYZ in " + quotedGroup("machine") + ", or post one job per part.");
      return;
    }
  }
}

// Return every mutable module global to its declared initial value; onOpen() calls this because a post
// may run again in the same JavaScript context. fOutput and gMotionModal are absent: onOpen() rebuilds
// both from properties on every branch, so that assignment is their reset.
function resetPostState() {
  currentWorkOffset = undefined;          // no work offset emitted yet
  wcsVisited = {};                        // no part has been set up in this file
  wcsZ0Trusted = {};
  sectionsCompleted = 0;                  // nothing has been cut in this file yet -- PV-7
  sequenceNumber = sequenceNumberStart();
  forceSectionToStartWithRapid = false;
  // If left true, the next file's first rapid would cross before retracting -- unsafe on a rising Z.
  // Every path within one file clears it, so this is a precaution. CR-21.
  forceRapidXYBeforeZ = false;
  sectionComment = undefined;
  machineMode = undefined;
  safeZHeight = undefined;
  curCoolant = eCoolant.Off;
  coolantChannelA = eCoolant.Off;
  coolantChannelB = eCoolant.Off;
  cutterOnCurrentPower = undefined;
  powerState = false;
  currentSpindleSpeed = 0;
  currentSpindleClockwise = true;
  lastPromptedSpeed = "";
  lastPromptedClockwise = true;
  probePauseBefore = true;
  probePauseAfter = true;
  pendingRadiusCompensation = RADIUS_COMPENSATION_OFF;

  // Modals too: one that believes the controller already holds its state emits nothing, so a second file
  // in the same JavaScript context would lose Start()'s G90, G20/G21 and G94 and inherit file one's. CR-21.
  gPlaneModal.reset();
  gAbsIncModal.reset();
  gUnitModal.reset();
  gFeedModeModal.reset();

  // The same, per axis word. Not the circular pair: createReferenceVariable gives it no reset() (engine
  // 5.388.0, typeof iOutput.reset === "undefined"), so calling one throws, and being non-modal it needs
  // none. sOutput is created force:true and fOutput is rebuilt in onOpen(); that is their reset. PV-1, CR-21.
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

function onOpen() {
  fw = getProperty(properties.jobSelectedFirmware);

  resetPostState();

  // Validate the job configuration before emitting anything (may error() out).
  validateJob();

  // No "%" wrapper on any firmware: stock Grbl 1.1 has no "%" feature -- the branch in grbl/protocol.c's
  // line reader is commented out -- so it reaches the parser and answers error:1.

  if (fw == eFirmware.GRBL) {
    gMotionModal = createModal({}, gFormat); // RS-274 group 1: G0-G3
  }
  else {
    gMotionModal = createModal({ force: true }, gFormat); // RS-274 group 1: G0-G3
  }

  // Rebuilt on every run, like gMotionModal: onOpen() may run again in the same JavaScript context, and a
  // forced F must not leak into the next file.
  fOutput = createVariable({ force: getProperty(properties.feedsEnforceFeedrate) }, fFormat);

  // Set either way, for the same reason as fOutput.
  setWordSeparator(getProperty(properties.jobSeparateWordsWithSpace) ? " " : "");

  // One property, read by group 3 and group 5 alike.
  parseSafeZProperty();
}

function onClose() {
  writeComment(eComment.Important, " *** STOP begin ***");

  flushMotions();

  if (getProperty(properties.includeStopFile) == "") {
    onCommand(COMMAND_COOLANT_OFF);

    // Before the park move: under manual spindle control this is an M0 prompt, and after the move the
    // router would cross the part at travel speed still turning.
    onCommand(COMMAND_STOP_SPINDLE);

    // Which X0 Y0: "Work" is the last section's WCS, which on a multi-part job is whichever fixture
    // Fusion ordered last; "Machine" is the homing corner, the same physical point for every job.
    var park = getProperty(properties.machineParkAtEnd);
    if (park == "Machine") {
      writeMachineParkXY();
    } else if (park == "Work") {
      rapidMovementsXY(0, 0);
    }

    flushMotions();

    if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(30));
    }
  
    else {
      displayText("Job end");

      // Nothing else undoes Start()'s M84 S0. S60 restores a timeout rather than releasing now: a bare
      // M84 releases at once, and an unbalanced LowRider gantry with no brake sinks in Z when it does.
      writeComment(eComment.Info, "   Restore stepper timeout");
      writeBlock(mFormat.format(84), sFormat.format(60));

      // RRF only, which gained M2 in 3.5.1; Marlin has never implemented it, so end of file IS the
      // program end there. RRF's stop.g runs after the M84 S60 above and can defeat that timeout.
      if (fw == eFirmware.REPRAP) {
        writeBlock(mFormat.format(2));
      }
    }

    writeComment(eComment.Important, " *** STOP end ***");
  } else {
    // Assert the XY plane before the operator's footer: a Z lead-out leaves G18 in force, so a footer
    // holding "G2 X.. Y.. I.. J.." would run in ZX. GRBL-only -- off GRBL every non-XY arc linearizes.
    if (fw == eFirmware.GRBL) {
      writeBlock(gPlaneModal.format(17));
    }

    loadFile(getProperty(properties.includeStopFile));
    flushMotions();
  }
  // No closing "%" on GRBL either -- see onOpen().
}

var forceSectionToStartWithRapid = false;
var sectionComment;
var currentWorkOffset;   // last work offset (WCS) emitted, to suppress redundant output

// What this job has already set up. currentWorkOffset only suppresses re-selecting the active offset;
// without these a return to an earlier part would re-run its origin setup and probe a surface already
// cut. Two records because only Z goes stale: X0 Y0 never moves once set, but a work Z0 is relative to
// the tool that measured it, so a tool change leaves every part but the re-measured one wrong. CR-17, PV-10.
var wcsVisited = {};     // work offset -> this job has entered it and set its origin
var wcsZ0Trusted = {};   // work offset -> its stored Z0 was measured with the tool now loaded

// Who corrects the work Z0 for the new tool -- "Probe", "Offset" or "Manual". The one reader of the
// property, so the sites acting on the answer cannot disagree about it.
function toolLengthCorrection() {
  return getProperty(properties.toolChangeZ0Correction);
}

// Does a tool change emit a G38.2? Exactly one of the three answers does, and every probe-shaped
// question in the post is asking this rather than "is the correction the post's".
function changeReprobesZ0() {
  return toolLengthCorrection() == "Probe";
}

// How many sections have finished cutting -- a count, not a section id, because the question is which
// toolpaths have already removed material. Written only by onSectionEnd() and resetPostState(), read
// only through probePointMachinedBefore(). PV-7.
var sectionsCompleted = 0;

// Select the work coordinate system for a section, retracting in the machine frame first. Returns the
// origin setup still to do -- {workOffset, mode, canProbe} -- or undefined where there is none: WCS
// unchanged, offset out of range, or the first section, whose origin writeFirstSection() writes.
//
// Selection only. writeWcsEstablish() sets the origin, called by onSection() AFTER any tool change at the
// same boundary, so a boundary that changes both WCS and tool probes the part once. PR-23.
function writeWCS(section) {
  var workOffset = section.getWorkOffset();
  writeComment(eComment.Debug, " writeWCS: entry workOffset: " + workOffset + " currentWorkOffset: " + (currentWorkOffset == undefined ? "none" : currentWorkOffset));

  // Fusion reports workOffset 0 both when the Setup's Work Offset field was left at its default and
  // when the default was chosen explicitly, so 0 always means "use WCS 1".
  if (workOffset == 0) {
    workOffset = 1; // default to the first WCS (G54)
    writeComment(eComment.Info, " writeWCS: workOffset defaulted to: " + workOffset);
  }

  // Marlin takes this path too: gcode.cpp (2.1.2.5) gives its offset selection full parity; only the
  // origin write differs.
  if (workOffset == currentWorkOffset) {
    writeComment(eComment.Info, " WCS unchanged: " + workOffset + ", not re-selecting");
    return undefined;
  }

  // A single-offset Marlin job on WCS 1 emits no select: offset 1 is Marlin's default workspace, and a
  // stock build rejects "G54" as unknown. That case only -- G92 writes whichever workspace is active, so a
  // job with a second offset needs the select.
  if (fw == eFirmware.MARLIN && workOffset == 1 && collectDistinctOffsets().length == 1) {
    writeComment(eComment.Debug, " writeWCS: Marlin single-offset job on WCS 1 -- default workspace, no select emitted");
    currentWorkOffset = workOffset;
    return undefined;
  }
  var previousWorkOffset = currentWorkOffset;
  var offsetCode = wcsGcode(workOffset);
  if (offsetCode == undefined) {
    error("Work offset " + workOffset + " is out of range for " + fw + " (GRBL supports G54-G59; Marlin and RepRap add G59.1-G59.3).");
    return undefined;
  }
  // Read once here and passed to writeWcsEstablish(), so selection and setup cannot disagree. The first
  // part's origin follows probeOnStart instead, in writeFirstSection().
  var onChangeMode = getProperty(properties.probeOnChange);
  // The section's own tool, not the global: it is the INCOMING tool at a boundary that also changes tools,
  // so canProbe answers for the tool that will cut the part. HR-24, PR-23.
  var sectionTool = section.getTool();
  var canProbe = (sectionTool.number != 0 && !sectionTool.isJetTool());
  writeComment(eComment.Debug, " writeWCS: probeOnChange: " + onChangeMode
    + " previousWorkOffset: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset)
    + " canProbe: " + canProbe);

  // Retract before selecting the new WCS: its Z origin may be unknown, so an absolute Z there is unsafe.
  // G53 addresses the machine frame without selecting a WCS. Guard B has already refused a multi-WCS
  // job with no fixed Z reference.
  var isTraverse = (previousWorkOffset != undefined);   // a genuine inter-part WCS change
  var machineFrame = isTraverse && fixedZEstablishedInFile();
  writeComment(eComment.Debug, " writeWCS: retract decision -- machineFrame: " + machineFrame
    + " isTraverse: " + isTraverse + " workOffset: " + workOffset);
  if (machineFrame) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before traverse");
  } else if (isTraverse) {
    // Unreachable behind Guard B; an error, not a move: with no fixed reference no height means the same
    // on both sides of the traverse. Not safeZ(): the entering section's level, read in the old part's frame.
    error("Internal: a WCS traverse reached output with no fixed Z reference -- Guard B should have refused this job.");
    return undefined;
  }

  writeComment(eComment.Info, " WCS changed: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset) + " -> " + workOffset);
  writeBlock(gFormat.format(offsetCode));
  currentWorkOffset = workOffset;

  // Origin setup follows only a real WCS change; the first section's is writeWcsOnStart()'s.
  if (!isTraverse) {
    return undefined;
  }

  return { workOffset: workOffset, mode: onChangeMode, canProbe: canProbe };
}

// Will this plan's origin setup set Z0 itself, with whichever tool is fitted when it runs? toolChange()
// skips its own re-probe exactly where this is true. On a return only "Probe" makes it true: "Offset"
// and "Manual" leave the offset trusted. PV-10, PR-23.
function wcsOriginEstablishesZ0(plan) {
  if (!(plan.mode == "Jog XYZ" ||
        (plan.canProbe && (plan.mode == "Probe Z" || plan.mode == "Jog XY & Probe Z")))) {
    return false;
  }
  return !wcsVisited[plan.workOffset] || changeReprobesZ0();
}

// Z0 was not set: warn in both the dialog and the file. One writer for the four places a probing origin
// mode meets a tool that cannot probe, so their wording cannot drift. The caller names the mode to
// recommend, as the two dispatches differ. PV-3, PV-9.
function warnZ0NotEstablished(useInstead) {
  // TWIN: here -- both channels, per PV-9. W25b and W28.
  warnBothChannels("a jet tool / tool 0 cannot probe, so Z0 was NOT established -- this job runs against"
    + " whatever Z origin is already stored. Use \"" + useInstead + "\" for a jet/laser job.");
}

// Set the origin of the part writeWCS() just selected, from the plan it returned. onSection() calls this
// AFTER any tool change at the same boundary, so the tool that cuts the part sets it up: no Z0 measured by
// the outgoing tool survives, and where this probes, the change skips its own re-probe. A change may have
// emptied wcsZ0Trusted before this runs. PR-23, CR-17.
function writeWcsEstablish(plan) {
  var workOffset = plan.workOffset;
  var onChangeMode = plan.mode;
  var canProbe = plan.canProbe;

  // A return to a part this job has already set up skips the dispatch below. CR-17.
  if (wcsVisited[workOffset]) {
    writeWcsOnReturn(workOffset, onChangeMode, canProbe);
    return;
  }

  // Z is at Machine Travel Z by either route -- the traverse retract, or that and a tool change, every arm
  // of which returns the tool to that height. The X/Y-only moves below keep it; the jog modes hand
  // control to the operator.
  if (onChangeMode == "Skip") {
    writeComment(eComment.Info, "   Move to this part's stored origin X0 Y0");
    resetAll();
    rapidMovementsXY(0, 0);
    flushMotions();
  } else if (onChangeMode == "Probe Z") {
    // The tool is still over the previous part, so partProbe() first travels to this one, X/Y only.
    // zUntrusted, because this mode exists to re-probe Z0: the probe writes a provisional Z0 at the travel
    // height and searches down from it. CR-12.
    if (canProbe) {
      partProbe(false, true);
    } else {
      warnZ0NotEstablished("Jog to X0 Y0 Z0");
      writeComment(eComment.Debug, " writeWcsEstablish: probe skipped (tool 0 or jet tool) -- moving to stored X0 Y0");
      resetAll();
      rapidMovementsXY(0, 0);
      flushMotions();
    }
  } else if (onChangeMode == "Jog XYZ") {
    // Jog: the operator jogs to this part's origin; record that position as X0 Y0 Z0, no probe.
    warnJogAtPauseNeedsSender();
    askUser("Jog to X0 Y0 Z0, then continue", "Set origin", true);
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
  } else if (onChangeMode == "Jog XY & Probe Z") {
    // Jog: the operator jogs to this part's X0 Y0 (staying clear in Z); record X0 Y0 here,
    // then probe Z. partProbe(true) -- the tool is at the origin after the jog.
    warnJogAtPauseNeedsSender();
    askUser("Jog to X0 Y0 above Z0, probe", "Set origin", true);
    writeComment(eComment.Info, "   Set current X,Y position to 0,0");
    if (canProbe) {
      // Inside the canProbe guard: with no probe to overwrite it the mode would silently become "Jog to
      // X0 Y0 Z0". CR-12.
      writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
      writeWcsOrigin(currentWorkOffset, 0, 0, 0);
      partProbe(true);
    } else {
      writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
      // The jog set X0 Y0 and nothing set Z0, so the register keeps its old Z -- the same case as the "Probe
      // Z" arm above.
      warnZ0NotEstablished("Jog to X0 Y0 Z0");
      writeComment(eComment.Debug, " writeWcsEstablish: probe skipped (tool 0 or jet tool)");
    }
  }

  // This part is set up, so a later RETURN moves to its stored origin instead of re-establishing it.
  // Z0 counts as trusted whatever the mode did -- the claim is "as good as this job can make it", and
  // only a tool change can falsify it afterwards. CR-17.
  wcsVisited[workOffset] = true;
  wcsZ0Trusted[workOffset] = true;
}

// Reach a part this job has already set up. The tool is at the travel height, this part's register is
// active, and the tool fitted is the one that will cut it. X0 Y0 is never re-established, under any
// mode: re-running it would re-prompt the operator to re-zero a part already cut. Z0 is, but only where
// a tool change invalidated it, and then by the mode's own Z answer. CR-17.
function writeWcsOnReturn(workOffset, mode, canProbe) {
  var zStale = !wcsZ0Trusted[workOffset];
  writeComment(eComment.Debug, " writeWcsOnReturn: workOffset: " + workOffset + " mode: " + mode
    + " zStale: " + zStale + " canProbe: " + canProbe);

  // The only path here that emits a G38.2. partProbe() travels to the stored X0 Y0 itself and writes Z
  // only, which is all a return may touch -- so the jog mode needs no prompt.
  if (zStale && canProbe && (mode == "Probe Z" || mode == "Jog XY & Probe Z")) {
    writeComment(eComment.Info, "   Return to a part already set up; a tool change since means Z0 is re-probed");
    partProbe(false, true);
    wcsZ0Trusted[workOffset] = true;
    return;
  }

  writeComment(eComment.Info, "   Return to a part already set up -- move to its stored origin X0 Y0");
  resetAll();
  rapidMovementsXY(0, 0);
  flushMotions();

  if (!zStale) {
    return;
  }

  // "Jog to X0 Y0 Z0" sets Z by hand, so a return whose Z0 a change invalidated gets the hand again --
  // Z only, at the origin the move above has just reached.
  if (mode == "Jog XYZ") {
    warnJogAtPauseNeedsSender();
    askUser("Jog to Z0 for the new tool, then continue", "Set origin", true);
    writeComment(eComment.Info, "   Set the current height to Z0");
    writeWcsOrigin(workOffset, undefined, undefined, 0);
    wcsZ0Trusted[workOffset] = true;
    return;
  }

  // "Use WCS X0 Y0 Z0" re-sets nothing by design, and a tool 0 / jet tool cannot measure: skipping the
  // correction is right, silence is not. wcsZ0Trusted stays false, so a later return warns again.
  // TWIN: here -- PV-9's own site, reached by both arms for different reasons, one statement. W11b, W27.
  warnBothChannels("this part's stored Z0 was measured with a tool that has since been changed, and"
    + " nothing here re-measures it -- every depth below is out by the difference in tool length."
    + " Set Z0 by hand before this part cuts, or use " + quotedValue(properties.probeOnChange, "Probe Z"));
}

// Persist the current position as WCS wcsNumber's origin; an undefined x/y/z leaves that axis alone. The
// dialects differ in addressing, not capability: "G10 L20 P<n>" names its register, while Marlin's "G92"
// under CNC_COORDINATE_SYSTEMS is a real per-WCS write -- "coordinate_system[active_coordinate_system] =
// position_shift" behind a WITHIN() check, G92.cpp 2.0.9.7 and 2.1.2.5 -- but only of the active
// workspace. So on Marlin the target must be the active WCS, and every caller ensures it.
function writeWcsOrigin(wcsNumber, x, y, z) {
  writeComment(eComment.Debug, " writeWcsOrigin: wcs: " + wcsNumber
    + " x: " + (x == undefined ? "-" : x) + " y: " + (y == undefined ? "-" : y) + " z: " + (z == undefined ? "-" : z)
    + " method: " + (fw == eFirmware.MARLIN ? "G92 (writes the ACTIVE workspace)" : ("G10 L20 (scoped to WCS " + wcsNumber + ")")));

  var xWord = x == undefined ? undefined : xFormat.format(x);
  var yWord = y == undefined ? undefined : yFormat.format(y);
  var zWord = z == undefined ? undefined : zFormat.format(z);

  if (fw == eFirmware.MARLIN) {
    if (wcsNumber != currentWorkOffset) {
      error("Internal: an origin write targeted work offset " + wcsNumber + " while " + currentWorkOffset
        + " is active. On Marlin G92 writes the ACTIVE workspace, so this would land in the wrong register.");
      return;
    }
    writeBlock(gFormat.format(92), xWord, yWord, zWord);
  } else {
    writeBlock(gFormat.format(10), "L20", "P" + wcsNumber, xWord, yWord, zWord);
  }
}

// Does the job have its fixed Z reference: the machine's homed Z, addressed with G53, whose Z0 does not
// move with stock thickness? Z only; homed X/Y is Guard B's. "Machine Travel Z" opts in, and ships empty.
function fixedZEstablishedInFile() {
  return machineHomesZ() && parseMachineTravelZ() != undefined;
}

// "Axes Homed and Trusted", split into the two questions its consumers ask: the machine-Z reference
// needs Z, the stored-offset guard needs X/Y, and neither implies the other. Read the property only
// through these -- an "== XYZ" test would miss the single-axis answers.
function machineHomesXY() {
  var declared = getProperty(properties.machineHomedAxes);
  return declared == "XY" || declared == "XYZ";
}
function machineHomesZ() {
  var declared = getProperty(properties.machineHomedAxes);
  return declared == "Z" || declared == "XYZ";
}

// "Home at Job Start", split into the two questions its consumers ask: does the job home, and does it
// pause first.
function homesAtJobStart() {
  return getProperty(properties.machineHomeAtStart) != "Off";
}
function promptsBeforeHome() {
  return getProperty(properties.machineHomeAtStart) == "Pause & Home";
}

// Whether this job's homing MOVES Z, which is not whether Z is declared homed: on GRBL a single "$H"
// runs the build's cycle, and the stock cycle homes Z FIRST -- HOMING_CYCLE_0 is (1<<Z_AXIS), with
// $HX/$HY/$HZ behind HOMING_SINGLE_AXIS_COMMANDS, off by default (grbl/config.h, 1.1h). PR-16.
function homingMovesZ() {
  if (!homesAtJobStart()) {
    return false;
  }
  return (fw == eFirmware.GRBL) ? (machineHomesXY() || machineHomesZ()) : machineHomesZ();
}

// "Machine Travel Z" in mm, or undefined where the field is empty or does not parse -- undefined meaning
// no fixed Z reference. A string because Fusion gives a numeric field no unset state, and every sentinel
// would be a reachable height, 0 included.
function parseMachineTravelZ() {
  return parseMachineCoordinate(getProperty(properties.machineTravelZ));
}

// The one parser of a machine coordinate held as a string -- Machine Travel Z, "Manual Position Z" and
// each half of an X Y pair -- so no field rejects what another accepts. Undefined means not set ("" too).
function parseMachineCoordinate(raw) {
  if (typeof raw != "string") return undefined;
  var s = raw.replace(/^\s+|\s+$/g, "");
  if (!(/^[-+]?\d+(\.\d+)?$/.test(s))) return undefined;   // also rejects "" -- unset
  return Number(s);
}

// The one parser of an X Y pair held as a string -- "Manual Position X Y" and "Probe X Y Offset". Returns
// {x, y} in mm, or undefined for anything else, the empty field included. Each half goes through
// parseMachineCoordinate() and its trim, so "0, 0" and "0,0" are one value, and "10" or "1,2,3" is
// rejected rather than half-read. Pure.
function parseXYPair(raw) {
  if (typeof raw != "string") return undefined;
  var parts = raw.split(",");
  if (parts.length != 2) return undefined;
  var x = parseMachineCoordinate(parts[0]);
  var y = parseMachineCoordinate(parts[1]);
  if (x == undefined || y == undefined) return undefined;
  return {x: x, y: y};
}

// The manual change position, in mm. X and Y share one field, so both are set or neither is; Z has its
// own field and may be set alone, a rule validateJob() enforces against these answers.
function toolChangePosXY() { return parseXYPair(getProperty(properties.toolChangePositionXY)); }
function toolChangePosX() { var p = toolChangePosXY(); return (p == undefined) ? undefined : p.x; }
function toolChangePosY() { var p = toolChangePosXY(); return (p == undefined) ? undefined : p.y; }
function toolChangePosZ() { return parseMachineCoordinate(getProperty(properties.toolChangePositionZ)); }

// True when this job relocates the tool for a manual change. The mode is part of the question: on the
// macro flow these fields are inert, the excursion being the macro's job. A job with no fixed Z
// reference answers false too, and validateJob() refuses rather than dropping the move silently.
function toolChangeMovesToPosition() {
  if (getProperty(properties.toolChangeMode) != "Pause") return false;
  if (!fixedZEstablishedInFile()) return false;
  return toolChangePosX() != undefined || toolChangePosZ() != undefined;
}

// The same height in OUTPUT units, ready to emit. Callers must not wrap it again. Only reached where
// fixedZEstablishedInFile() is true, which is what guarantees it parses.
function machineTravelZ() {
  return propertyMmToUnit(parseMachineTravelZ());
}

// Numeric G-code for a work offset: 1-6 -> 54-59, 7-9 -> 59.1-59.3. Undefined if out of range for the
// firmware (GRBL stops at G59); callers report the error.
function wcsGcode(workOffset) {
  if (workOffset <= 6) return 53 + workOffset;
  // Not GRBL, which stops at G59: Marlin's G59() takes the .1/.2/.3 subcodes under the same build
  // option as the rest (gcode.cpp 2.1.2.5), giving it nine workspaces exactly as RRF has.
  if (fw != eFirmware.GRBL && workOffset <= 9) return 59 + (workOffset - 6) / 10;
  return undefined;
}

// Every machine-frame move goes through here, so the travel-Z retract and the X/Y park emit G53 alike.
// Pass the axis words formatted; this adds G53 G0 and the feed.
//
// G53 always shares its move's block: it "is not modal and must be programmed on each line", so the G0
// goes through gFormat, not gMotionModal. And Marlin's G53() restores the saved coordinate system INSIDE
// "if (parser.chain())" (Marlin/src/gcode/geometry/G53-G59.cpp, 2.0.9.7 and 2.1.2.5), so a bare G53 on
// its own line leaves native space active for the rest of the job.
function writeMachineFrameBlock(axisWords, feedMmPerMin) {
  resetAll();
  writeBlock(gFormat.format(53), gFormat.format(0), axisWords[0], axisWords[1],
    fFormat.format(propertyMmToUnit(feedMmPerMin)));
  if (fw == eFirmware.MARLIN && currentWorkOffset != undefined) {
    var restore = wcsGcode(currentWorkOffset);
    if (restore != undefined) {
      writeComment(eComment.Debug, " writeMachineFrameBlock: re-selecting " + gFormat.format(restore)
        + " -- Marlin restores a CHAINED G53 itself, but no fix commit exists for the reports that it does not");
      writeBlock(gFormat.format(restore));
    }
  }
  resetAll();
  gMotionModal.reset();
}

// A rapid to the declared "Machine Travel Z", addressed absolutely with G53.
function writeMachineTravelZ(reason) {
  var z = machineTravelZ();
  writeComment(eComment.Info, "   " + reason + " -- machine Z " + xyzFormat.format(z));
  writeMachineFrameBlock([zFormat.format(z), undefined],
    getProperty(properties.feedsTravelSpeedZ));
  flushMotions();
}

// Park at the machine's own X0 Y0 -- the homing corner -- as the job's last motion. The two firmware
// routes differ in kind, hence the firmware-dependent guard. GRBL/RepRap emit "G53 G0 X0 Y0", a rapid
// to a machine frame homing must already have set; Marlin emits "G28 X / G28 Y", which re-homes
// instead, needing no prior homing or build option but costing a homing cycle. The post cannot
// compute the point instead: the G92 work frame differs from the machine frame by an unknown offset.
function writeMachineParkXY() {
  // Retract before crossing the bed -- potentially a full diagonal. Only a job that established a fixed
  // Z reference can retract at all, and validateJob() reads the same predicate.
  if (!fixedZEstablishedInFile()) {
    // TWIN #4
    writeWarning("no retract before parking at machine X0 Y0 -- this job establishes no fixed Z"
      + " reference; the tool crosses the bed at whatever Z the last operation left it at");
  } else {
    writeMachineTravelZ("Retract to the travel height in the machine frame before parking");
  }

  if (fw == eFirmware.MARLIN) {
    writeComment(eComment.Info, "   Park at machine X0 Y0 -- re-homing X/Y; G53 is a Marlin build option");
    // The in-file half, so a file read on its own carries what its last two blocks cost.
    // set_axis_is_at_home() zeroes position_shift; coordinate_system[] survives, nothing re-selects it.
    // TWIN #5
    writeWarning("the two homing blocks below zero Marlin's position_shift -- the work origin this file"
      + " established. Any file run after this one must establish its own origin; it cannot resume on"
      + " this one's");
    writeBlock(gFormat.format(28), "X");
    writeBlock(gFormat.format(28), "Y");
    return;
  }

  // The file half of validateJob()'s CR-10 warning. GRBL only: Marlin re-homes rather than rapids, and an
  // RRF machine homed to its minima already rests at this point.
  if (fw == eFirmware.GRBL) {
    // TWIN #6
    writeWarning("machine X0 Y0 is where the homing switches tripped, and homing leaves the axes one"
      + " pull-off inside that point on both dialects -- $27 on a stock Grbl build, mpos_mm and"
      + " pulloff_mm on a stock FluidNC -- so the block below drives X and Y back onto the switches, and"
      + " with hard limits enabled this job ends in Alarm rather than parked. Correct only where machine"
      + " zero is where homing LEAVES the axis: HOMING_FORCE_SET_ORIGIN on Grbl, or an mpos_mm that"
      + " accounts for the pull-off on FluidNC");
  }

  writeComment(eComment.Info, "   Park at machine X0 Y0");
  // The F word is not optional even on a G0: where the modal feedrate is honoured for G0, an F-less
  // rapid crosses the bed at the last CUT's feed. writeMachineFrameBlock() clears it first, hence fFormat.
  writeMachineFrameBlock([xFormat.format(0), yFormat.format(0)],
    getProperty(properties.feedsTravelSpeedXY));
}

// A 3-axis section can still be oriented off machine +Z -- a Setup built on a model face, not the stock
// top. isMultiAxis() misses it, Fusion emitting ordinary X/Y/Z words, so unguarded the part is cut in the
// wrong plane and nothing in the file says so. Fails open: it errors only where the orientation is
// readable and clearly not +Z, as a false positive would abort good jobs. Nothing here may throw, so the
// vector's types are checked before any arithmetic.
function isSectionOrientationSupported() {
  var toolPlane = currentSection.workPlane;
  var toolAxis = (toolPlane == undefined) ? undefined : toolPlane.forward;

  if (toolAxis == undefined) {
    writeComment(eComment.Debug, " onSection orientation: workPlane "
      + ((toolPlane == undefined) ? "missing" : "present") + ", forward missing"
      + " -> UNREADABLE, check skipped, section allowed");
    return true;
  }

  var axisText = "X" + toolAxis.x + " Y" + toolAxis.y + " Z" + toolAxis.z;

  if ((typeof toolAxis.x != "number") || (typeof toolAxis.y != "number") || (typeof toolAxis.z != "number")) {
    writeComment(eComment.Debug, " onSection orientation: forward " + axisText
      + " types " + (typeof toolAxis.x) + "/" + (typeof toolAxis.y) + "/" + (typeof toolAxis.z)
      + " -> UNREADABLE, check skipped, section allowed");
    return true;
  }

  var offAxis = (Math.abs(toolAxis.x) > 1e-4) || (Math.abs(toolAxis.y) > 1e-4) || (toolAxis.z < (1 - 1e-4));

  // Tilt from machine +Z, for the trace only. Clamped because a non-unit or noisy vector can push the
  // value outside acos()'s domain; NaN components fall through as "NaN", which is itself the diagnosis.
  var tilt = Math.acos(Math.max(-1, Math.min(1, toolAxis.z))) * 180 / Math.PI;

  writeComment(eComment.Debug, " onSection orientation: forward " + axisText
    + ", tilt from machine Z " + roundTo(tilt, 4) + " deg -> "
    + (offAxis ? "OFF-AXIS, section REJECTED" : "upright, section allowed"));

  if (offAxis) {
    error(localize("Tool orientation is not supported: this operation's Z axis is not the machine Z. "
      + "Rebuild the Setup with its Z axis along the machine Z -- normally the stock top."));
    return false;
  }

  return true;
}

function onSection() {
  // Multi-axis toolpaths aren't supported. Fail at the start of the offending operation rather than
  // partway through its motion (onLinear5D/onRapid5D also guard, as a backstop).
  if (currentSection.isMultiAxis()) {
    error(localize("Multi-axis toolpath is not supported. Use a 3-axis milling or 2D/jet strategy."));
    return;
  }

  // isSectionOrientationSupported() has already raised the error when it returns false.
  if (!isSectionOrientationSupported()) {
    return;
  }

  // The Personal edition sends a section's first move as onLinear, not onRapid, with the current position
  // already at the destination -- a zero-length vector with no direction to read.
  forceSectionToStartWithRapid = true;

  // First section: write the job header and set up the first part.
  if (isFirstSection()) {
    writeFirstSection();
  }

  writeComment(eComment.Important, " *** SECTION begin ***");

  // Fusion sends no operation-comment for an unnamed operation, and onSectionEnd() clears it so this
  // section cannot inherit the previous one's name -- which leaves undefined here.
  if (sectionComment == undefined) {
    sectionComment = "Unnamed operation";
  }

  // Print min/max boundaries for each section
  var vectorX = new Vector(1, 0, 0);
  var vectorY = new Vector(0, 1, 0);
  writeComment(eComment.Info, "   X Min: " + xyzFormat.format(currentSection.getGlobalRange(vectorX).getMinimum()) + " - X Max: " + xyzFormat.format(currentSection.getGlobalRange(vectorX).getMaximum()));
  writeComment(eComment.Info, "   Y Min: " + xyzFormat.format(currentSection.getGlobalRange(vectorY).getMinimum()) + " - Y Max: " + xyzFormat.format(currentSection.getGlobalRange(vectorY).getMaximum()));
  writeComment(eComment.Info, "   Z Min: " + xyzFormat.format(currentSection.getGlobalZRange().getMinimum()) + " - Z Max: " + xyzFormat.format(currentSection.getGlobalZRange().getMaximum()));

  // Determine the Safe Z Height to map G1s to G0s
  safeZforSection(currentSection);

  // Order matters: select the WCS, change tools, then set the origin. Select first because the change's
  // re-probe writes the ACTIVE offset -- changing first would put the new Z0 in the previous section's
  // register. Origin last, so the tool that cuts the part sets it up. Section 1 was selected in
  // writeFirstSection(), so wcsOrigin stays undefined for it. PR-23.
  var wcsOrigin = undefined;
  if (!isFirstSection()) {
    wcsOrigin = writeWCS(currentSection);
  }

  // Section 1's tool was loaded in writeFirstSection(), before its origin work. The argument says whether
  // the origin setup below sets Z0 itself; if so, the change skips its own re-probe. PR-23.
  if (!isFirstSection() && tool.number != getPreviousSection().getTool().number) {
    toolChange(wcsOrigin != undefined && wcsOriginEstablishesZ0(wcsOrigin));
  }

  if (wcsOrigin != undefined) {
    writeWcsEstablish(wcsOrigin);
  }

  // Machining type
  if (currentSection.type == TYPE_MILLING) {
    writeComment(eComment.Info, " " + sectionComment + " - Milling - Tool: " + tool.number + " - " + tool.comment + " " + getToolTypeName(tool.type));
  }

  else if (currentSection.type == TYPE_JET) {
    var jetModeStr;
    var warn = false;

    // Cutter mode used for different cutting power in PWM laser
    switch (currentSection.jetMode) {
      case JET_MODE_THROUGH:
        cutterOnCurrentPower = getProperty(properties.laserOnThrough);
        jetModeStr = "Through";
        break;
      case JET_MODE_ETCHING:
        cutterOnCurrentPower = getProperty(properties.laserOnEtch);
        jetModeStr = "Etching";
        break;
      case JET_MODE_VAPORIZE:
        jetModeStr = "Vaporize";
        cutterOnCurrentPower = getProperty(properties.laserOnVaporize);
        break;
      default:
        jetModeStr = "*** Unknown ***";
        // Keep the power defined: unset, laserOn() would compute "undefined * 10" and emit S NaN, or reuse an
        // earlier section's power. Through is the conservative setting.
        cutterOnCurrentPower = getProperty(properties.laserOnThrough);
        warn = true;
    }

    if (warn) {
      writeComment(eComment.Info, " " + sectionComment + ", Laser/Plasma Cutting mode: " + getParameter("operation:cuttingMode") + ", jetMode: " + jetModeStr);
      writeComment(eComment.Important, "Selected cutting mode " + currentSection.jetMode + " not mapped to power level");
    }
    else {
      writeComment(eComment.Info, " " + sectionComment + ", Laser/Plasma Cutting mode: " + getParameter("operation:cuttingMode") + ", jetMode: " + jetModeStr + ", power: " + cutterOnCurrentPower);
    }
  }

  // Adjust the mode
  if (fw == eFirmware.REPRAP) {
    if (machineMode != currentSection.type) {
      switch (currentSection.type) {
          case TYPE_MILLING:
              writeBlock(getProperty(properties.duetMillingMode));
              break;
          case TYPE_JET:
              writeBlock(getProperty(properties.duetLaserMode));
              break;
      }
    }
  }

  machineMode = currentSection.type;
  
  onCommand(COMMAND_START_SPINDLE);
  onCommand(COMMAND_COOLANT_ON);

  // Display section name in LCD
  displayText(" " + sectionComment);
}

function onSectionEnd() {
  resetAll();
  // This section's material is gone, so it counts against the next probe's touch-point. PV-7.
  ++sectionsCompleted;
  // Clear the operation name so the next section cannot inherit it: Fusion sends the next section's
  // operation-comment AFTER this callback, so an unnamed operation would keep this one's.
  sectionComment = undefined;
  writeComment(eComment.Important, " *** SECTION end ***");
  // " " and not "" -- the same blank separator Start() ends with, so every separator is one form.
  writeComment(eComment.Important, " ");
}

function onComment(message) {
  writeComment(eComment.Important, message);
}

// Manual NC "Pass through": emit the user-entered text verbatim (one block per line).
// Not sanitized -- pass-through is meant to reach the controller untouched.
function onPassThrough(value) {
  var lines = String(value).split(/\r?\n/);
  for (var i = 0; i < lines.length; ++i) {
    if (lines[i] != "") {
      writeBlock(lines[i]);
    }
  }
}

var pendingRadiusCompensation = RADIUS_COMPENSATION_OFF;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;

  // Marlin/GRBL/RepRap have no G41/G42, so control-side compensation cannot be honored. The supported
  // mode is "In computer", where Fusion pre-offsets the centerline.
  if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
    error(localize("Cutter radius compensation in the control is not supported (Marlin/GRBL/RepRap have no G41/G42). Set the operation's Compensation Type to 'In computer'."));
  }
}

// Emit one of Fusion's rapids. Moves the post makes itself call rapidMovements*() directly, never
// onRapid(), so the test hook below can turn only Fusion's rapids into feed moves.
function emitRapid(x, y, z) {
  forceSectionToStartWithRapid = false;

  rapidMovements(x, y, z);
}

// Rapid movements -- Fusion's, delivered here.
function onRapid(x, y, z) {
  // Test hook: a Personal licence delivers these moves to onLinear() as feeds, so forward them there and
  // let onLinear() decide which convert back. Travel Speed X/Y is the feed if one stays a G1.
  if (getProperty(properties.mapRapidsTestPersonalLicence)) {
    onLinear(x, y, z, propertyMmToUnit(getProperty(properties.feedsTravelSpeedXY)));
    return;
  }

  emitRapid(x, y, z);
}

// Feed movements
function onLinear(x, y, z, feed) {
  // A section's first move arrives as a cut; turn it back into a rapid, as a G1 under Scale Feedrate runs
  // at the slowest cut feed. Only with Map G1s -> G0 on, off in a full-licence job.
  if (getProperty(properties.mapRapidsRestoreRapids) && (forceSectionToStartWithRapid == true)) {
    writeComment(eComment.Important, " First G1 --> G0");

    forceSectionToStartWithRapid = false;
    // emitRapid(), NOT onRapid(): with the test hook on, onRapid() forwards back into this function
    // and the conversion would recurse until the stack blew.
    emitRapid(x, y, z);
  }
  else if (isSafeToRapid(x, y, z)) {
    writeComment(eComment.Important, " Safe G1 --> G0");

    emitRapid(x, y, z);
  }
  else {
    linearMovements(x, y, z, feed);
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  forceSectionToStartWithRapid = false;

  error(localize("Multi-axis motion is not supported."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  forceSectionToStartWithRapid = false;

  error(localize("Multi-axis motion is not supported."));
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  forceSectionToStartWithRapid = false;

  if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }
  circular(clockwise, cx, cy, cz, x, y, z, feed);
}

// Is this a WCS/inspection probing operation, not a drill or tap cycle? Defined here: Autodesk keep
// isProbeOperation() post-local, so there is no kernel global to call. Either test alone can miss one.
function isProbeOperation() {
  if (hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe")) {
    return true;
  }
  return (typeof cycleType != "undefined") && (String(cycleType).indexOf("probing") == 0);
}

// Drilling / canned cycles. None of the supported firmwares handle G81/G82/G83 as drilling -- GRBL has
// no canned cycles, Marlin only in an opt-in custom build, and RepRap/Duet reuse those codes for
// mesh/probe/babystep functions -- so every cycle point is expanded into ordinary G0/G1 moves.
function onCyclePoint(x, y, z) {
  // Probing cannot be expanded: that would emit G0/G1 with no G38 at all. error(), not
  // cycleNotSupported(): both abort, but only error() can name the alternative.
  if (isProbeOperation()) {
    error(localize("WCS probing is not supported. A probing operation asks the controller to measure "
      + "several points and then COMPUTE the work offset from them; GRBL and Marlin have no arithmetic, "
      + "so there is no g-code to expand it into -- and expanding it anyway would emit plain G0/G1 moves "
      + "with no G38 at all, driving the tool into the work at feed rate. Set the work offset by hand in "
      + "the sender, or use this post's own Z touch-off in the " + quotedGroup("probe") + " property group."));
    return;
  }
  expandCyclePoint(x, y, z);
}

// Called on waterjet/plasma/laser cuts
var powerState = false;

function onPower(power) {
  if (power != powerState) {
    if (power) {
      writeComment(eComment.Important, " >>> LASER Power ON");

      laserOn(cutterOnCurrentPower);
    } else {
      writeComment(eComment.Important, " >>> LASER Power OFF");

      laserOff();
    }
    powerState = power;
  }
}

// Called on Dwell Manual NC invocation
function onDwell(seconds) {
  writeComment(eComment.Important, " >>> Dwell");
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }

  seconds = clamp(0.001, seconds, 99999.999);

  if (fw == eFirmware.GRBL) {
    writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
  }

  else {
    writeBlock(gFormat.format(4), "S" + secFormat.format(seconds));
  }
}

// Called with every parameter in the document/section
function onParameter(name, value) {

  // Write gcode initial info
  // Product version
  if (name == "generated-by") {
    writeComment(eComment.Important, value);
    writeComment(eComment.Important, " Posts processor: " + FileSystem.getFilename(getConfigurationPath()));
  }

  // Date
  else if (name == "generated-at") {
    writeComment(eComment.Important, " Gcode generated: " + value + " GMT");
  }

  // Document
  else if (name == "document-path") {
    writeComment(eComment.Important, " Document: " + value);
  }

  // Setup
  else if (name == "job-description") {
    writeComment(eComment.Important, " Setup: " + value);
  }

  // Get section comment
  else if (name == "operation-comment") {
    sectionComment = value;
  }

  else {
    writeComment(eComment.Debug, " param: " + name + " = " + value);
  }
}

function onMovement(movement) {
  var jet = tool.isJetTool && tool.isJetTool();
  var id;

  switch (movement) {
    case MOVEMENT_RAPID:
      id = "MOVEMENT_RAPID";
      break;
    case MOVEMENT_LEAD_IN:
      id = "MOVEMENT_LEAD_IN";
      break;
    case MOVEMENT_CUTTING:
      id = "MOVEMENT_CUTTING";
      break;
    case MOVEMENT_LEAD_OUT:
      id = "MOVEMENT_LEAD_OUT";
      break;
    case MOVEMENT_LINK_TRANSITION:
      id = jet ? "MOVEMENT_BRIDGING" : "MOVEMENT_LINK_TRANSITION";
      break;
    case MOVEMENT_LINK_DIRECT:
      id = "MOVEMENT_LINK_DIRECT";
      break;
    case MOVEMENT_RAMP_HELIX:
      id = jet ? "MOVEMENT_PIERCE_CIRCULAR" : "MOVEMENT_RAMP_HELIX";
      break;
    case MOVEMENT_RAMP_PROFILE:
      id = jet ? "MOVEMENT_PIERCE_PROFILE" : "MOVEMENT_RAMP_PROFILE";
      break;
    case MOVEMENT_RAMP_ZIG_ZAG:
      id = jet ? "MOVEMENT_PIERCE_LINEAR" : "MOVEMENT_RAMP_ZIG_ZAG";
      break;
    case MOVEMENT_RAMP:
      id = "MOVEMENT_RAMP";
      break;
    case MOVEMENT_PLUNGE:
      id = jet ? "MOVEMENT_PIERCE" : "MOVEMENT_PLUNGE";
      break;
    case MOVEMENT_PREDRILL:
      id = "MOVEMENT_PREDRILL";
      break;
    case MOVEMENT_EXTENDED:
      id = "MOVEMENT_EXTENDED";
      break;
    case MOVEMENT_REDUCED:
      id = "MOVEMENT_REDUCED";
      break;
    case MOVEMENT_HIGH_FEED:
      id = "MOVEMENT_HIGH_FEED";
      break;
    case MOVEMENT_FINISH_CUTTING:
      id = "MOVEMENT_FINISH_CUTTING";
      break;
  }

  if (id == undefined) {
    id = String(movement);
  }

  writeComment(eComment.Debug, " " + id);
}

function setSpindleSpeed(_spindleSpeed, _clockwise) {
  if ((currentSpindleSpeed != _spindleSpeed) || (_spindleSpeed > 0 && currentSpindleClockwise != _clockwise)) {
    if (_spindleSpeed > 0) {
      spindleOn(_spindleSpeed, _clockwise);
    } else {
      spindleOff();
    }
  }
}

function onSpindleSpeed(spindleSpeed) {
  setSpindleSpeed(spindleSpeed, tool.clockwise);
}

// One writer for the two speed-feed-synchronization cases in onCommand(): a warning duplicated at two
// call sites comes to differ at one.
function writeSpeedFeedSyncWarning() {
  // TWIN: none -- the kernel raises it from the operation, and validateJob() cannot see toolpath or
  // Manual NC commands.
  writeWarning("Speed-feed synchronization for rigid tapping is not supported; a floating/tension tap "
    + "holder is required");
}

function onCommand(command) {
  writeComment(eComment.Debug, " " + getCommandStringId(command));

  switch (command) {
    case COMMAND_START_SPINDLE:
      onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
      return;
    case COMMAND_SPINDLE_CLOCKWISE:
      if (!tool.isJetTool()) {
        setSpindleSpeed(spindleSpeed, true);
      }
      return;
    case COMMAND_SPINDLE_COUNTERCLOCKWISE:
      if (!tool.isJetTool()) {
        setSpindleSpeed(spindleSpeed, false);
      }
      return;
    case COMMAND_STOP_SPINDLE:
      if (!tool.isJetTool()) {
        setSpindleSpeed(0, true);
      }
      return;
    case COMMAND_COOLANT_ON:
      // Kept apart: a milling tool calls setCoolant() even for Off, which stops a running channel; a jet tool
      // must not -- F360 gives it no coolant, so Off says nothing. Merged, this would kill laser air. PV-12
      if (tool.isJetTool()) {
        var jetCoolant = requestedCoolant(tool);
        if (jetCoolant != eCoolant.Off) {
          setCoolant(jetCoolant);
        }
      }
      else {
        var strCoolant = requestedCoolant(tool);
        writeComment(eComment.Debug, "   tool.coolant = " + tool.coolant + " strCoolant = " + strCoolant);

        setCoolant(strCoolant);
      }
      return;
    case COMMAND_COOLANT_OFF:
      setCoolant(eCoolant.Off);
      return;
    case COMMAND_LOCK_MULTI_AXIS:
      return;
    case COMMAND_UNLOCK_MULTI_AXIS:
      return;
    case COMMAND_BREAK_CONTROL:
      return;
    case COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION:
      // No rigid-tapping/spindle-sync capability (no G33) on any supported firmware, so this is a
      // deliberate no-op. Warned on every occurrence, so every affected move in the file is flagged.
      writeSpeedFeedSyncWarning();
      return;
    case COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION:
      writeSpeedFeedSyncWarning();
      return;
    case COMMAND_TOOL_MEASURE:
      if (!tool.isJetTool()) {
        probeTool();
      }
      return;
    case COMMAND_STOP:
      writeBlock(mFormat.format(0));
      return;

    // onPower() emits the laser control for these. Listed so the fall-through below does not warn them as
    // unsupported.
    case COMMAND_POWER_ON:
    case COMMAND_POWER_OFF:
      return;

    // An optional stop is always taken: no supported firmware can stop "only if the operator asked". All
    // three parse M1, each differently -- grbl 1.1 "case 1: break; // Optional stop not supported. Ignore."
    // does not pause; RepRapFirmware handles "case 0", "case 1: // Sleep" and "case 2" in one block, so
    // mid-file it ends the job (src/GCodes/GCodes2.cpp); only Marlin waits for the LCD (M0_M1.cpp,
    // HAS_RESUME_CONTINUE). So the post emits M0 and warns, per occurrence, that "optional" was dropped.
    case COMMAND_OPTIONAL_STOP:
      // TWIN: none -- Manual NC is invisible to validateJob().
      writeWarning("an Optional Stop was requested here and is emitted as an UNCONDITIONAL M0 -- none"
        + " of the three supported firmwares has a usable M1, so this pause cannot be skipped");
      writeBlock(mFormat.format(0));
      return;
  }

  // Below the switch, not a default: case, so a future case that breaks is caught too. writeWarning(),
  // not an Important comment, so Comment Level cannot hide it.
  // TWIN: none -- Manual NC, and the command is known only when the kernel raises it.
  writeWarning("command " + getCommandStringId(command) + " is not supported by this post and was not "
    + "emitted");
}

function resetAll() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
  fOutput.reset();
}

function writeInformation() {
  // Calculate the min/max ranges across all sections
  var toolZRanges = {};
  var vectorX = new Vector(1, 0, 0);
  var vectorY = new Vector(0, 1, 0);
  var ranges = {
    x: { min: undefined, max: undefined },
    y: { min: undefined, max: undefined },
    z: { min: undefined, max: undefined },
  };
  var handleMinMax = function (pair, range) {
    var rmin = range.getMinimum();
    var rmax = range.getMaximum();
    if (pair.min == undefined || pair.min > rmin) {
      pair.min = rmin;
    }
    if (pair.max == undefined || pair.max < rmax) {
      pair.max = rmax;
    }
  }

  var numberOfSections = getNumberOfSections();
  for (var i = 0; i < numberOfSections; ++i) {
    var section = getSection(i);
    var tool = section.getTool();
    var zRange = section.getGlobalZRange();
    var xRange = section.getGlobalRange(vectorX);
    var yRange = section.getGlobalRange(vectorY);
    handleMinMax(ranges.x, xRange);
    handleMinMax(ranges.y, yRange);
    handleMinMax(ranges.z, zRange);
    if (is3D()) {
      if (toolZRanges[tool.number]) {
        toolZRanges[tool.number].expandToRange(zRange);
      } else {
        toolZRanges[tool.number] = zRange;
      }
    }
  }

  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " Ranges Table:");
  writeComment(eComment.Info, "   X: Min=" + xyzFormat.format(ranges.x.min) + " Max=" + xyzFormat.format(ranges.x.max) + " Size=" + xyzFormat.format(ranges.x.max - ranges.x.min));
  writeComment(eComment.Info, "   Y: Min=" + xyzFormat.format(ranges.y.min) + " Max=" + xyzFormat.format(ranges.y.max) + " Size=" + xyzFormat.format(ranges.y.max - ranges.y.min));
  writeComment(eComment.Info, "   Z: Min=" + xyzFormat.format(ranges.z.min) + " Max=" + xyzFormat.format(ranges.z.max) + " Size=" + xyzFormat.format(ranges.z.max - ranges.z.min));

  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " Tools Table:");
  var tools = getToolTable();
  if (tools.getNumberOfTools() > 0) {
    for (var i = 0; i < tools.getNumberOfTools(); ++i) {
      var tool = tools.getTool(i);
      var comment = "  T" + toolFormat.format(tool.number) + " D=" + xyzFormat.format(tool.diameter) + " CR=" + xyzFormat.format(tool.cornerRadius);
      if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
        comment += " TAPER=" + taperFormat.format(tool.taperAngle) + "deg";
      }
      if (toolZRanges[tool.number]) {
        comment += " - ZMIN=" + xyzFormat.format(toolZRanges[tool.number].getMinimum());
      }
      comment += " - " + getToolTypeName(tool.type) + " " + tool.comment;
      writeComment(eComment.Info, comment);
    }
  }

  // Every post property, grouped, plus the values that are resolved rather than stored.
  writeAllProperties();
  writeResolvedValues();

  writeComment(eComment.Info, " ");
}

// A dialog group's `order:`, or 9999 where it has none, so the dump follows the dialog's own order.
function groupOrder(key) {
  var def = groupDefinitions[key];
  return ((def != undefined) && (def.order != undefined)) ? def.order : 9999;
}

// A property's own `order:`, 9999 where it has none so an unnumbered property sorts last. Not in the
// Post Processor Guide's table of property members, but factory grbl.cps uses it, and depending on it
// is additive: if the dialog ignores it, only this dump is affected.
function propertyOrder(key) {
  var p = properties[key];
  return ((p != undefined) && (p.order != undefined)) ? p.order : 9999;
}

function groupTitle(key) {
  var def = groupDefinitions[key];
  return ((def != undefined) && (def.title != undefined)) ? def.title : key;
}

// Dump every post property as Info comments, one block per dialog group, so a posted file carries the
// settings that produced it and reviewing it never means inferring the configuration from the motion.
// Iterates the `properties` object rather than listing keys, so a newly added property is dumped
// automatically. Values print in their STORED form -- an enum shows its `id`, not its display title --
// so the dump stays stable across dialog relabelling.
function writeAllProperties() {
  // Bucket the keys by group, then sort on each group's `order:` -- the same number the dialog sorts
  // on. A group with no definition is not dropped: it sorts last and prints its raw key as a heading.
  var byGroup = {};
  var groupNames = [];
  var key;
  for (key in properties) {
    var g = properties[key].group;
    if (g == undefined) {
      continue;                       // not a dialog property
    }
    if (byGroup[g] == undefined) {
      byGroup[g] = [];
      groupNames.push(g);
    }
    byGroup[g].push(key);
  }
  groupNames.sort(function (a, b) {
    var d = groupOrder(a) - groupOrder(b);
    return (d != 0) ? d : ((a < b) ? -1 : ((a > b) ? 1 : 0));
  });

  for (var i = 0; i < groupNames.length; ++i) {
    var name = groupNames[i];
    var keys = byGroup[name];
    keys.sort(function (a, b) {
      var d = propertyOrder(a) - propertyOrder(b);
      return (d != 0) ? d : ((a < b) ? -1 : ((a > b) ? 1 : 0));
    });
    writeComment(eComment.Info, " ");
    writeComment(eComment.Info, " Properties -- " + groupTitle(name) + ":");
    for (var j = 0; j < keys.length; ++j) {
      var k = keys[j];
      var v = getProperty(properties[k]);
      // Make an unset string property visible as such -- an empty value would otherwise read
      // as a truncated line. Typed check so a numeric 0 isn't caught by it.
      if ((typeof v == "string") && (v.length == 0)) {
        v = "<empty>";
      }
      writeComment(eComment.Info, "   " + k + " = " + v);
    }
  }
}

// Values a reviewer needs that are NOT any property's stored value -- resolved from an expression,
// converted to output units, or supplied by Fusion. Without these the dump misleads:
// "probeSafeZ = Retract:15" does not tell you the height resolved to 5.08 for this operation.
function writeResolvedValues() {
  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " Resolved Values:");
  writeComment(eComment.Info, "   Output unit = " + (unit == IN ? "inch" : "mm"));
  // No parentheses in any label below: writeCommentLine() turns them into spaces, as a grbl comment
  // cannot nest.
  writeComment(eComment.Info, "   Firmware resolved = " + fw);
  writeComment(eComment.Info, "   Safe Z = " + describeSafeZ(safeZMode, safeZHeightDefault));
  // Stated even when None: whether there is a fixed Z reference decides whether the tool can retract at
  // all, and a reviewer should read that, not infer it from a missing line.
  writeComment(eComment.Info, "   Fixed Z reference = "
    + (fixedZEstablishedInFile() ? "machine Z -- the machine's own homed Z, addressed with G53" : "None"));
  writeComment(eComment.Info, "   Probe XY offset in output units = X" + xyzFormat.format(probeOffsetX()) + " Y" + xyzFormat.format(probeOffsetY()));
  // In output units: G53 reads the active G20/G21, so "G53 G0 Z-12" in an inch file is -12 inches, not
  // the mm the property is entered in.
  if (fixedZEstablishedInFile()) {
    writeComment(eComment.Info, "   Machine Travel Z in output units = "
      + xyzFormat.format(machineTravelZ()) + " -- absolute machine Z");
  }
}

// Home the machine at job start, once, before anything work-relative. Only the action property is read
// here: "Axes Homed and Trusted" declares what can home, "Home at Job Start" asks for it. Homing gives
// X/Y a repeatable origin and Z a travel datum; the cutting reference stays the work-Z touch-off.
function writeMachineHoming() {
  var homeXY = machineHomesXY();
  var homeZ = machineHomesZ();
  var atStart = homesAtJobStart();

  writeComment(eComment.Debug, " writeMachineHoming: entry fw: " + fw + " Axes Homed and Trusted: "
    + getProperty(properties.machineHomedAxes) + " -- X/Y: " + homeXY + " Z: " + homeZ
    + " Home at Job Start: " + getProperty(properties.machineHomeAtStart));

  if (!atStart) {
    writeComment(eComment.Debug, " writeMachineHoming: Home at Job Start off -- current position accepted as zero, no motion");
    return;
  }

  // Homing asked for with no axis declared homeable cannot be done, and the operator believes the job
  // homes, so warn. Not an error(): it costs no safety on its own.
  if (!homeXY && !homeZ) {
    // TWIN #7
    writeWarning(quoted(properties.machineHomeAtStart) + " is on but " + quoted(properties.machineHomedAxes) + " is None -- nothing was"
      + " homed");
    return;
  }

  // Homing would move the tool off the jogged position about to be recorded as origin. Warned in the file,
  // as validateJob() has no output stream, and above the homing the operator reads next. Advice only:
  // a fixture at machine zero is rare. PV-4
  if (originIsPreJogged()) {
    // TWIN #8
    writeWarning("the homing below runs BEFORE " + quoted(properties.probeOnStart) + " records the current position as"
      + " the part origin, so whatever this job records as X0 Y0 is where homing left the machine --"
      + " the endstop corner -- and not where you parked the tool. Positioning the tool before"
      + " starting this file has no effect on any axis " + quoted(properties.machineHomedAxes) + " declares. Use"
      + " " + quotedValue(properties.probeOnStart, "Probe Z") + " or a \"Jog to ...\" mode, or set " + quoted(properties.machineHomeAtStart) + " to Off.");
  }

  // A single stop before ANY homing motion, so the operator can prepare the machine -- place a movable
  // Z-homing plate, clear the bed. Independent of firmware and of which axes home.
  if (promptsBeforeHome()) {
    writeComment(eComment.Debug, " writeMachineHoming: pausing before homing (Pause, then Home)");
    askUser("Prepare machine for homing", "Homing", false);
  }

  if (fw == eFirmware.GRBL) {
    // On stock GRBL the declared axes are bookkeeping, not emission: which axes $H homes is fixed at
    // compile time by HOMING_CYCLE_0/1/2, and $HX/$HY/$HZ sit behind a default-off build option.
    writeComment(eComment.Debug, " writeMachineHoming: GRBL/FluidNC, emitting single combined $H"
      + " (declared X/Y: " + homeXY + " Z: " + homeZ + " -- the build's homing cycle decides)");
    // writeln(), not writeBlock(): with "Enable Line #s" on, writeBlock() prefixes an N word, and GRBL
    // recognises a $ command only when $ is the line's first character.
    writeln("$H");
    return;
  }

  // Marlin / RepRap: true independent G28 <axis>.
  if (homeXY) {
    writeComment(eComment.Debug, " writeMachineHoming: " + fw + ", emitting G28 X / G28 Y");
    writeBlock(gFormat.format(28), "X");
    writeBlock(gFormat.format(28), "Y");
  }
  if (homeZ) {
    writeComment(eComment.Debug, " writeMachineHoming: " + fw + ", emitting G28 Z");
    writeBlock(gFormat.format(28), "Z");
  }
}

// Job preamble, emitted once before any section's cutting: the header block, homing, the first
// section's WCS, Start() or the start file, then the fixed Z reference, the first tool load and the
// part origin -- except that a pre-jogged origin moves the fixed Z reference to last. WCS selection
// lives here, not in onSection(), because the steps after it may write an origin on top of the active
// WCS.
function writeFirstSection() {
  // GRBL and FluidNC take a rapid's rate off the axis limits, never out of the block --
  // "block->programmed_rate = block->rapid_rate" under PL_COND_FLAG_RAPID_MOTION, grbl/planner.c 1.1,
  // and FluidNC/src/Planner.cpp 3.x. The F word is still stored, so it sets the next cut's modal feed.
  if (fw == eFirmware.GRBL) {
    // TWIN: none -- true of every GRBL job, so a dialog line would fire on every post and train the
    // operator to dismiss the dialog. The remedy is a controller setting changed once, not per job.
    writeWarning("the F values on the G0 moves below do not set how fast this job travels. GRBL and "
      + "FluidNC ignore F on a rapid and move at the maximum rate configured for each axis, so this "
      + "post's Travel Speed X/Y and Travel Speed Z have no effect on this firmware. To change how "
      + "fast the job travels, change that maximum at the controller: $110, $111 and $112 -- X, Y "
      + "and Z in mm/min -- on GRBL, or max_rate_mm_per_min for each axis in the config file on "
      + "FluidNC. The post cannot change it for you, because those are controller settings rather "
      + "than g-code, and GRBL accepts one only while it is Idle.");
  }

  writeInformation();

  writeMachineHoming();

  // Select the WCS before Start()/includeStartFile and writeWcsOnStart(), either of which may set an
  // origin on top of the active WCS. The return value is always undefined here: isTraverse is false on
  // the first section, whose origin is "First WCS / Part"'s and is written below.
  writeWCS(currentSection);

  writeComment(eComment.Important, " *** START begin ***");

  if (getProperty(properties.includeStartFile) == "") {
       Start();
  } else {
    // The include replaces Start(), the only place this post sets positioning, units and -- on GRBL --
    // feed mode and plane. A missing file is refused at post time; one that merely omits G90 is not.
    // TWIN: none -- a precondition stated in the file, not a defect the post can detect.
    writeWarning("the start file below REPLACES this post's header, and that header is the only place"
      + " this job sets " + (fw == eFirmware.GRBL
        ? "G90 absolute positioning, " + (unit == IN ? "G20 inch" : "G21 mm") + " units, G94 feed rate"
          + " mode and the G17 XY plane"
        : "G90 absolute positioning, " + (unit == IN ? "G20 inch" : "G21 mm") + " units and the M84 S0"
          + " that stops the steppers timing out")
      + " -- nothing re-asserts them afterwards. Every coordinate, every G53 move and every probe target"
      + " below assumes them, so a start file that omits one, or sets the other unit, misreads the whole"
      + " job with nothing in this file to show it.");
    loadFile(getProperty(properties.includeStartFile));
  }

  // originIsPreJogged() picks the order. Normally: G53 Z move, load, origin -- the G53 sets the height
  // the trip to X0 Y0 starts from, and Z0 is set with the cutting tool. Pre-jogged: load, origin, then
  // G53, which would otherwise move the tool off the position being recorded. CR-15.
  if (originIsPreJogged()) {
    toolChangeFirstLoad();
    writeWcsOnStart();
    writeFixedZReference();
    // The tool now stands at a machine height with no work-coordinate Z, and writeMachineTravelZ()
    // tells the kernel nothing -- as after writeToolChangeReturn(), so the same flag. Guarded, because
    // writeFixedZReference() emits nothing without "Machine Travel Z".
    if (fixedZEstablishedInFile()) {
      forceRapidXYBeforeZ = true;
    }
  } else {
    writeFixedZReference();
    toolChangeFirstLoad();
    writeWcsOnStart();
  }

  // The first part is set up, so a later return to its offset reuses the stored origin rather than
  // setting it again. Trusted whatever the mode did: keying it on "did the post probe?" would send a
  // "Use WCS X0 Y0 Z0" job to probe a surface it had already cut. CR-17.
  wcsVisited[currentWorkOffset] = true;
  wcsZ0Trusted[currentWorkOffset] = true;

  writeComment(eComment.Important, " *** START end ***");
  writeComment(eComment.Important, " ");
}

// Set the job's fixed Z reference: a G53 move to "Machine Travel Z", a machine height that clears the
// bed and does not move with stock thickness. Runs before the first part's origin, because the travel
// to its X0 Y0 starts from here. With the field empty this moves nothing, and partProbe() warns that
// its moves start from whatever height the tool holds.
function writeFixedZReference() {
  var established = fixedZEstablishedInFile();
  writeComment(eComment.Debug, " writeFixedZReference: " + (established ? "machine Z" : "none"));
  if (!established) {
    return;
  }
  // The file's copy of validateJob()'s warning, which holds the reasoning and the source read. Once
  // here rather than at every G53: the height is the same on all of them.
  if (fw == eFirmware.GRBL && parseMachineTravelZ() >= 0) {
    // TWIN #9
    writeWarning("machine Z " + xyzFormat.format(machineTravelZ()) + " is at or above machine zero --"
      + " on a stock Grbl build and on a stock FluidNC alike, homing leaves every reachable Z negative,"
      + " and zero itself is where the Z endstop tripped, one pull-off above where homing left the axis;"
      + " a move there returns it onto the switch and soft limits do not reject it. Correct only on a"
      + " machine whose zero is at the bed: HOMING_FORCE_SET_ORIGIN on Grbl, or an mpos_mm that puts it"
      + " there on FluidNC");
  }

  // The file's copy of validateJob()'s Marlin warning, so the file read alone states the assumption
  // its motion depends on. Once here rather than at every G53.
  if (fw == eFirmware.MARLIN) {
    // TWIN #10
    writeWarning("every G53 below assumes this Marlin was compiled with CNC_COORDINATE_SYSTEMS,"
      + " which is off in a stock configuration -- without it G53 is an unknown command and every"
      + " travel-height move in this file is skipped, leaving the tool where the last operation ended");
  }
  writeComment(eComment.Important, " Establish fixed Z reference -- homed machine Z");
  writeMachineTravelZ("Move to the travel height in the machine frame");
}

// "Probe X Y Offset", in mm here and output units from X()/Y(): a part's Z touch-point is its origin
// plus this, so the origin can sit off the stock while Z is read on its top. Unreadable is 0, 0 --
// validateJob() warns; probeOffsetIsSet() says whether the operator moved the point.
function probeOffsetMm() {
  var p = parseXYPair(getProperty(properties.probeOffsetXY));
  return (p == undefined) ? {x: 0, y: 0} : p;
}
function probeOffsetX() { return propertyMmToUnit(probeOffsetMm().x); }
function probeOffsetY() { return propertyMmToUnit(probeOffsetMm().y); }

// True when a part probe touches off somewhere other than the part origin, i.e. when the XY offset
// creates a traverse. One definition, so partProbe() and the first-part "... Current Pos" path -- which
// must retract before that traverse -- cannot disagree about when it happens.
function probeOffsetIsSet() { return probeOffsetX() != 0 || probeOffsetY() != 0; }

// Has this job already cut the point a part probe touches? getGlobalRange()/getGlobalZRange() give the
// toolpath's extents in work coordinates, so this is a comparison, not an estimate. Per work offset, as
// each range is measured from its own part's origin. A bounding box: over-reports, never under. PV-7.
function sectionCutsProbePoint(section, px, py) {
  if (section.getGlobalZRange().getMinimum() >= 0) {
    return false;   // nothing below this part's datum: the touch-point is still the stock top
  }
  var xr = section.getGlobalRange(new Vector(1, 0, 0));
  var yr = section.getGlobalRange(new Vector(0, 1, 0));
  return (px >= xr.getMinimum()) && (px <= xr.getMaximum())
      && (py >= yr.getMinimum()) && (py <= yr.getMaximum());
}

// How a warning names an operation, in one place. Fusion sends no operation-comment for an unnamed
// operation, so the index is the fallback -- 1-based, because that is what the operator counts down the
// browser tree. Two walks name operations, and a second spelling would describe one job two ways.
function operationName(section, i) {
  return section.hasParameter("operation-comment")
    ? ("\"" + section.getParameter("operation-comment") + "\"")
    : ("operation " + (i + 1));
}

// The sections before index `upto` that share `workOffset` and have cut through that part's probe point
// -- {names, zMin}, or undefined where there are none. One statement of the hazard, read by partProbe()
// for the file and by validateJob() for the dialog, so the two channels cannot disagree about which
// operations are at issue or how deep they went.
function probePointMachinedBefore(upto, workOffset) {
  var px = probeOffsetX();
  var py = probeOffsetY();
  var names = [];
  var zMin = undefined;
  for (var i = 0; i < upto; ++i) {
    var s = getSection(i);
    var wo = s.getWorkOffset();
    if (wo == 0) {
      wo = 1;
    }
    if (wo != workOffset || !sectionCutsProbePoint(s, px, py)) {
      continue;
    }
    names.push(operationName(s, i));
    var z = s.getGlobalZRange().getMinimum();
    if (zMin == undefined || z < zMin) {
      zMin = z;
    }
  }
  return (names.length > 0) ? { names: names, zMin: zMin } : undefined;
}

// The touch-point as both the file and the dialog name it: the origin itself, or the origin plus an
// offset that has not moved it far enough.
function probePointDescription() {
  return probeOffsetIsSet()
    ? ("this part's X0 Y0 plus " + quoted(properties.probeOffsetXY) + " -- X" + xyzFormat.format(probeOffsetX())
       + " Y" + xyzFormat.format(probeOffsetY()))
    : "this part's X0 Y0, " + quoted(properties.probeOffsetXY) + " being 0, 0";
}

// The two "Set ... to Current Pos" modes, whose origin is where the OPERATOR left the tool before the
// file started. Two things turn on it: nothing before writeWcsOnStart() may move the tool, and the tool
// that made the jog is the tool the job assumes. Read by the emission and by validateJob() alike.
function originIsPreJogged() {
  var mode = getProperty(properties.probeOnStart);
  return mode == "Current XY & Probe Z" || mode == "Current XYZ";
}

// Prompt flags for the next probeTool(): attach the probe before, detach it after. partProbe() sets
// them from "Probe Pause"; probeTool() then resets them to true/true, the default for any probe not
// reached through partProbe().
var probePauseBefore = true;
var probePauseAfter = true;

// Probe Z into the active WCS at the part's touch-point -- its origin plus "Probe X Y Offset" --
// travelling there first where the tool is not already on it. Callers guard tool 0 and jet tools.
//
//   atOrigin              the tool already sits on the origin, so the reposition is emitted only where
//                         the offset is non-zero.
//   zUntrusted            this WCS's stored Z0 is not believed, so the probe writes its own provisional
//                         Z0 below. Whether the traverse height is unknown is a separate question.
//   startsWhereHomingLeftIt   the tool has not moved since writeMachineHoming(); only writeWcsOnStart()
//                         can pass true. Selects the no-Z-reference warning that says homing, not the
//                         operator, chose the height. PR-16.
function partProbe(atOrigin, zUntrusted, startsWhereHomingLeftIt) {
  var ox = probeOffsetX();
  var oy = probeOffsetY();
  var offsetSet = probeOffsetIsSet();

  var machined = probePointMachinedBefore(sectionsCompleted, currentWorkOffset);
  // The file's half of the PV-7 warning, above the traverse and G38.2 because the datum must be fixed
  // before the probe runs. Warned, not suppressed: an origin off the material is common, and "Probe X Y
  // Offset" is the remedy the text names.
  if (machined != undefined) {
    // TWIN #11
    writeWarning("this probe touches off at " + probePointDescription() + " -- a point this job has"
      + " ALREADY CUT, down to Z" + xyzFormat.format(machined.zMin) + " in "
      + machined.names.join(", ") + ". Where the tool lands on that machined surface instead of the"
      + " original stock top, the Z0 written below is that much low and every depth after it cuts that"
      + " much deeper into the part -- Fusion computed them against the original datum. Move the"
      + " touch-point onto uncut material with " + quoted(properties.probeOffsetXY) + " in " + quotedGroup("probe") + ", or set"
      + " Z0 by hand instead of letting this probe write it");
  }

  if (!atOrigin || offsetSet) {
    resetAll();
    // The rapid below is at an unknown height, so the file must say so. A WARNING and not an Info
    // comment: it reports a precondition the operator must satisfy, and Info is gone at Level = Off.
    if (zUntrusted && !fixedZEstablishedInFile()) {
      // TWIN #12
      if (startsWhereHomingLeftIt && homingMovesZ()) {
        writeWarning("no Z reference is established, so the XY move below and the G38.2 under it both"
          + " start from whatever height the tool is holding -- and on this job HOMING chose that"
          + " height, not you. Nothing has moved the tool since, and nothing between here and the probe"
          + " brings it to a height you set, so positioning it before starting this file changes"
          + " neither move. Check that the crossing to X0 Y0 clears your stock, clamps and fixtures at"
          + " the height homing leaves. G38 Target is " + getProperty(properties.probeG38Target)
          + " mm here, and it is a DISTANCE measured from the endstop rather than from the stock --"
          + " check that it reaches. Setting " + quoted(properties.machineTravelZ) + " removes both questions.");
      } else {
        writeWarning("no Z reference is established, so the XY move below runs at whatever height the"
          + " tool is holding -- it must be clear of the stock, clamps and fixtures before the program"
          + " starts -- and the G38.2 that follows searches G38 Target DOWN FROM THAT HEIGHT, so the"
          + " target has to be deep enough to reach the stock from wherever you leave the tool.");
      }
    }
    if (offsetSet) {
      writeComment(eComment.Info, "   Move to probe point = origin + offset X" + xyzFormat.format(ox) + " Y" + xyzFormat.format(oy) + ", then probe Z");
    } else {
      writeComment(eComment.Info, "   Move to part origin X0 Y0, then probe Z");
    }
    rapidMovementsXY(ox, oy);
    flushMotions();
  }

  // Provisional Z0, overwritten by the probe below, so "G38 Target" is a DISTANCE to search and not a
  // position measured from the Z0 this mode distrusts. Z only, and after the traverse rather than
  // before: that move is X/Y, so the height is the same either way. CR-12.
  if (zUntrusted) {
    writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
    writeWcsOrigin(currentWorkOffset, undefined, undefined, 0);
  }

  // Attach/detach prompts from "Probe Pause": No = neither, Before = attach only, Before & After = both
  // (the default).
  var pause = getProperty(properties.probePause);
  probePauseBefore = (pause == "Before" || pause == "Before & After");
  probePauseAfter = (pause == "Before & After");
  onCommand(COMMAND_TOOL_MEASURE);
}

// Implements the probeOnStart property: establishes the origin for the WCS writeWCS() just selected
// for the first section, scoped to that WCS via writeWcsOrigin().
function writeWcsOnStart() {
  var mode = getProperty(properties.probeOnStart);
  var canProbe = (tool.number != 0 && !tool.isJetTool());
  writeComment(eComment.Debug, " writeWcsOnStart: probeOnStart: " + mode + " wcs: " + currentWorkOffset);

  // Here, where the mode is read, because the two modes write the origin at different sites. Jog modes
  // are excluded: there the operator sets the register at the pause, knowingly. validateJob() carries
  // the dialog copy (PV-4) -- by the G10 it is too late.
  if (originIsPreJogged() && collectDistinctOffsets().length > 1) {
    // TWIN #13
    writeWarning("this file REPLACES the stored X0 Y0 of the part it starts on -- " + quoted(properties.probeOnStart)
      + " is a \"Set ... to Current Pos\" mode, so the G10 below writes wherever the tool is standing"
      + " when this file starts into that part's work offset register. Every other part in this job is"
      + " cut at the origin already stored in its own register, untouched. Put the tool on this part's"
      + " origin before starting, and expect the offset you set for it at the machine to be gone.");
  }

  if (mode == "Skip") {
    // No canProbe guard: this clearance move must lift every tool, laser included -- guarding it would
    // let a jet job cross the bed at whatever height it held. Z0's trust is the mode's premise whatever
    // the tool. The branches below keep their guards: each bounds a G38.2 or a provisional Z0. HR-26.
    writeComment(eComment.Info, "   Use stored work origin; move Z to Safe Z, then to X0 Y0");
    resetAll();
    rapidMovementsZ(safeZ());
    rapidMovementsXY(0, 0);
    flushMotions();
    return;
  }

  if (mode == "Probe Z") {
    // Z is stale and about to be probed, so no absolute Z move is emitted in this frame.
    writeComment(eComment.Info, "   Use stored work origin X0 Y0; probe Z");
    if (canProbe) {
      // The one caller that can still stand where homing left the tool. writeFixedZReference() moves
      // nothing with no Z reference -- the case the warning covers -- so the predicate asks only about
      // the first load and a start file. PR-16, PV-13.
      partProbe(false, true, toolStillWhereHomingLeftIt());
    } else {
      warnZ0NotEstablished("Set X0 Y0 Z0 to Current Pos");
      writeComment(eComment.Debug, " writeWcsOnStart: probe skipped (tool 0 or jet tool) -- moving to stored X0 Y0");
      resetAll();
      rapidMovementsXY(0, 0);
      flushMotions();
    }
    return;
  }

  // The "Jog ..." modes pause (M0) so the operator jogs to the part origin during the run; the
  // "... Current Pos" modes assume a pre-jog. Both then write the origin identically.
  if (mode == "Jog XYZ" || mode == "Jog XY & Probe Z") {
    var jogMsg = (mode == "Jog XYZ")
      ? "Jog to X0 Y0 Z0, then continue"
      : "Jog to X0 Y0 above Z0, probe";
    warnJogAtPauseNeedsSender();
    askUser(jogMsg, "Set origin", true);
  }

  if (mode == "Current XYZ" || mode == "Jog XYZ") {
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
    return;
  }

  writeComment(eComment.Info, "   Set current X,Y position to 0,0");
  if (canProbe) {
    // Sound only where the operator has just put the tool at the origin themselves.
    writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
    // Without this, the offset traverse runs at whatever Z the operator jogged to -- a millimetre over
    // the stock on this mode's premise. The provisional Z0 above makes an absolute retract meaningful.
    if (probeOffsetIsSet()) {
      writeComment(eComment.Info, "   Retract to Safe Z before the offset traverse");
      resetAll();
      rapidMovementsZ(safeZ());
      flushMotions();
    }
    partProbe(true);
  } else {
    // Tool 0 / jet tool: no probe, so there is no G38 target to bound and nothing for a provisional Z0
    // to fix -- writing one would silently turn this mode into "Set X0 Y0 Z0 to Current Pos".
    writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
    // ... which leaves Z0 at whatever the register already holds, while the jet section that follows
    // emits ABSOLUTE Z words against that unknown zero. Suppressing the write is right; silence is not.
    warnZ0NotEstablished("Set X0 Y0 Z0 to Current Pos");
    writeComment(eComment.Debug, " writeWcsOnStart: probe skipped (tool 0 or jet tool)");
  }
}

// The emit half of writeComment(), shared with writeWarning() below so the two cannot come to differ
// on how a comment is delimited or sanitized.
function writeCommentLine(text) {
  // Collapse parentheses (comment markers) and newlines to a space so a multi-line
  // value can't split the comment into a second, uncommented (active G-code) line.
  var safeText = sanitizeMessageText(text, "()");
  if (fw == eFirmware.GRBL) {
    writeln("(" + safeText + ")");
  }
  else {
    writeln(";" + safeText);
  }
}

// Every ">>> WARNING:" goes through here, ignoring Comment Level -- Off means less commentary, not
// fewer warnings. No parentheses in the text: writeCommentLine() replaces them with a space, a grbl
// comment being unable to nest. Each call site has a TWIN verdict (findings.md, section 2).
function writeWarning(text) {
  writeCommentLine(" >>> WARNING: " + text);
}

// One text to both the file and the dialog, so the two cannot drift -- pairing them by hand needs a
// second predicate and a second string. Not a pre-flight: that warns once per job, this once per
// occurrence. PV-9.
function warnBothChannels(text) {
  writeWarning(text);
  warning(localize(text));
}

// Write a comment only where the job's "Comment Level" is at or above the level it is filed under.
function writeComment(level, text) {
  if (commentLevels.indexOf(level) <= commentLevels.indexOf(getProperty(properties.jobCommentLevel))) {
    writeCommentLine(text);
  }
}

// Set where the post moved the tool in machine coordinates (G53) -- a tool-change return or the
// pre-jog first section -- and read only in rapidMovements(). That height has no work-coordinate Z,
// so getCurrentPosition().z is wrong and cannot be corrected; the flag stops the next rapid relying
// on it.
var forceRapidXYBeforeZ = false;

// Tell the kernel where the tool is: getCurrentPosition() tracks the toolpath, blind to moves the post
// emits itself. Undefined means unchanged, not zero. Work coordinates only, so a G53 move sets
// forceRapidXYBeforeZ instead -- Autodesk's posts do the same (haas.cps, writeRetract(), G53 case).
function noteCurrentPosition(_x, _y, _z) {
  var cur = getCurrentPosition();
  setCurrentPosition(new Vector(
    (_x == undefined) ? cur.x : _x,
    (_y == undefined) ? cur.y : _y,
    (_z == undefined) ? cur.z : _z
  ));
}

// Rapid movement in X/Y, emitted as G0 at the configured XY travel feedrate. Called from
// rapidMovements() for every onRapid, and directly for moves like the final return-to-origin.
function rapidMovementsXY(_x, _y) {
  let x = xOutput.format(_x);
  let y = yOutput.format(_y);

  if (x || y) {
    if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    }
    else {
      let f = fOutput.format(propertyMmToUnit(getProperty(properties.feedsTravelSpeedXY)));
      writeBlock(gMotionModal.format(0), x, y, f);
    }
  }

  // Whether the words were emitted or suppressed, the tool is at _x/_y: a formatter returns "" only
  // where the axis already holds the value asked for.
  noteCurrentPosition(_x, _y, undefined);
}

// Rapid movement in Z, emitted as G0 at the configured Z travel feedrate. Called from
// rapidMovements() for every onRapid, and directly for retracts like the post-probe safe-Z move.
function rapidMovementsZ(_z) {
  let z = zOutput.format(_z);

  if (z) {
    if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    }
    else {
      let f = fOutput.format(propertyMmToUnit(getProperty(properties.feedsTravelSpeedZ)));
      writeBlock(gMotionModal.format(0), z, f);
    }
  }

  noteCurrentPosition(undefined, undefined, _z);

  // A work-coordinate Z clears the flag: it was set because the tool's height had no work-coordinate
  // value, and the block above has just given it one.
  forceRapidXYBeforeZ = false;
}

// Combined X/Y/Z rapid, emitted as separate G0s at each axis's own travel feedrate. Ordered so we
// never plunge into the part: when Z is descending, position XY first and then bring Z down; when Z is
// rising or unchanged, retract Z first and then move XY.
function rapidMovements(_x, _y, _z) {
  // The case the comparison below cannot decide: the tool stands at a machine-frame height the work
  // frame has never named, so on a rising Z it would retract first and cross at the section's clearance
  // height instead of the travel height already held. Two callers create it. CR-15.
  if (forceRapidXYBeforeZ) {
    forceRapidXYBeforeZ = false;
    writeComment(eComment.Debug, " rapidMovements: X/Y before Z -- the tool holds a machine-frame height the work frame has not named");
    rapidMovementsXY(_x, _y);
    rapidMovementsZ(_z);
    return;
  }

  if (_z < getCurrentPosition().z) {
    rapidMovementsXY(_x, _y);
    rapidMovementsZ(_z);
  } else {
    rapidMovementsZ(_z);
    rapidMovementsXY(_x, _y);
  }
}

// Cap a G1 feed so no axis exceeds its configured maximum: project the move onto X, Y and Z, scale all
// three down until every component is within its limit, then cap the result at the XYZ limit. Returns
// the feed unchanged when "Scale Feedrate" is off, or when the change works out under 0.01.
function limitFeedByXYZComponents(curPos, destPos, feed) {
  if (!getProperty(properties.feedsScaleFeedrate))
    return feed;

  var xyz = Vector.diff(destPos, curPos);
  let xyLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedXY));
  let zLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedZ));

  // Without the Rapid that normally opens a Section, current equals destination and the vector is zero
  // length, so the slower of the two axis limits is used instead.
  if (xyz.length == 0) {
    var lesserFeed = (xyLimit < zLimit) ? xyLimit : zLimit;

    // Never raise a feed: the axis limit only caps what was asked for. F is modal, so returning the
    // limit outright would turn an F100 move into F180 on the defaults.
    return (lesserFeed < feed) ? lesserFeed : feed;
  }

  var dir = xyz.getNormalized();
  var xyzFeed = Vector.product(dir.abs, feed);  // Determine the effective x,y,z speed on each axis

  if (xyzFeed.z > zLimit) {
    xyzFeed.multiply(zLimit / xyzFeed.z);
  }

  if (xyzFeed.x > xyLimit) {
    xyzFeed.multiply(xyLimit / xyzFeed.x);
  }

  if (xyzFeed.y > xyLimit) {
    xyzFeed.multiply(xyLimit / xyzFeed.y);
  }

  // xyzFeed.length is sqrt(x^2 + y^2 + z^2) -- the feedrate the scaled components add up to.


  let xyzLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedXYZ));
  let newFeed = (xyzFeed.length > xyzLimit) ? xyzLimit : xyzFeed.length;

  if (Math.abs(newFeed - feed) > 0.01) {
    return newFeed;
  }
  else {
    return feed;
  }
}

// The arc counterpart of limitFeedByXYZComponents(): cap a G2/G3 feed so no axis exceeds its
// configured maximum. Not that function's chord projection: an arc's axis velocity is tangential and
// reaches the full feed wherever the tangent lines up with an axis, so a chord under-protects by up to
// 1/cos(45deg). Conservative for a short arc that misses every quadrant point -- the safe side.
function limitArcFeed(feed) {
  if (!getProperty(properties.feedsScaleFeedrate)) {
    return feed;
  }

  var xyLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedXY));
  var zLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedZ));

  // An XY arc sweeps X and Y only. A ZX / YZ arc (GRBL only -- Marlin/RepRap linearize those) sweeps
  // one linear axis and Z, so it must satisfy the slower of the two.
  var limit = (getCircularPlane() == PLANE_XY) ? xyLimit : ((xyLimit < zLimit) ? xyLimit : zLimit);

  // Same final cap the linear path applies to its resolved feed.
  var xyzLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedXYZ));
  if (limit > xyzLimit) {
    limit = xyzLimit;
  }

  return (feed > limit) ? limit : feed;
}

// Emit a cutting move as a G1, at a feed the axis limits have had their say in.
function linearMovements(_x, _y, _z, _feed) {
  // Control-side radius compensation is rejected up front in onRadiusCompensation(), so
  // pendingRadiusCompensation is always OFF here.
  let feed = limitFeedByXYZComponents(getCurrentPosition(), new Vector(_x, _y, _z), _feed);

  let x = xOutput.format(_x);
  let y = yOutput.format(_y);
  let z = zOutput.format(_z);
  let f = fOutput.format(feed);

  if (x || y || z) {
    writeBlock(gMotionModal.format(1), x, y, z, f);
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      fOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

// The folder Fusion is writing this .gcode into, which is where every group-7 include file must live.
// One definition, so validateJob()'s pre-flight check and loadFile()'s own read cannot disagree.
function includeFolder() {
  return FileSystem.getFolderPath(getOutputPath()) + PATH_SEPARATOR;
}

// Include an operator's file in the stream, or error() out if it is not in the NC output folder. Every
// group-7 include goes through here, so the missing-file error, the trailing-newline repair and the
// modal reset that follows a program the post did not write are each written once.
function loadFile(_file) {
  var folder = includeFolder();
  if (FileSystem.isFile(folder + _file)) {
    var txt = loadText(folder + _file, "utf-8");
    if (txt.length > 0) {
      writeComment(eComment.Info, " --- Start custom gcode " + folder + _file);
      write(txt);
      // write() appends no line break, so an include with no trailing newline leaves the stream
      // mid-line and the next block merges onto its last one: a stop file ending "M5" yields "M5M400".
      var lastChar = txt.charAt(txt.length - 1);
      if (lastChar != "\n" && lastChar != "\r") {
        writeln("");
      }
      writeComment(eComment.Info, " --- End custom gcode " + folder + _file);

      // Modal state does not survive a file the post did not write. A modal writes a word only on change,
      // so a stale one drops it: a G18 left behind makes the next XY arc cut in ZX.
      gPlaneModal.reset();
      gMotionModal.reset();
      resetAll();
    } else {
      // A missing file aborts the post; an empty one is noted rather than skipped silently. It matters
      // most on the Start include, which replaces Start() and so leaves G90/G21 unwritten.
      writeComment(eComment.Info, " --- Custom gcode file is empty, nothing included " + folder + _file);
    }
  } else {
    writeComment(eComment.Important, " Can't open file " + folder + _file);
    error("Can't open file " + folder + _file);
  }
}

// A property held in millimetres, in the units this job emits.
function propertyMmToUnit(_v) {
  return (_v / (unit == IN ? 25.4 : 1));
}

// The preamble every job opens with, unless "Start File" replaces it: absolute positioning and units
// on every firmware, the feed mode and plane select on GRBL, a disabled stepper timeout off it.
function Start() {
  writeComment(eComment.Info, "   Set Absolute Positioning");
  writeComment(eComment.Info, "   Units = " + (unit == IN ? "inch" : "mm"));

  writeBlock(gAbsIncModal.format(90));
  writeBlock(gUnitModal.format(unit == IN ? 20 : 21));

  if (fw == eFirmware.GRBL) {
    writeComment(eComment.Info, "   Set Feed Rate Mode to units per minute");
    writeBlock(gFeedModeModal.format(94));

    writeComment(eComment.Info, "   Use the XY plane for circular motion");
    writeBlock(gPlaneModal.format(17));
  }

  else {
    // No G94/G17 here. Neither is a free no-op off GRBL: Marlin compiles G17 only under
    // CNC_WORKSPACE_PLANES and has no G93/G94 at all, and RRF gained G93/G94 only in 3.5.1.

    writeComment(eComment.Info, "   Disable stepper timeout");
    writeBlock(mFormat.format(84), sFormat.format(0));
  }
}

// What the spindle is doing. Only spindleOn() and spindleOff() write these, so a stop made outside
// setSpindleSpeed() -- toolChange()'s -- is seen by the next start. 0 is off; the direction counts only while
// the spindle is on. RV-01.
var currentSpindleSpeed = 0;
var currentSpindleClockwise = true;

// Manual path only: what the operator was last asked for. The speed is kept as the formatted string, because
// two speeds that format alike are one speed to the operator, and asking them to turn a dial to the number
// it already reads is worse than silence. Direction is kept too, so a reversal at an unchanged speed asks.
var lastPromptedSpeed = "";
var lastPromptedClockwise = true;

// Start the spindle, or -- in the prompt mode -- ask the operator to, and only when the
// speed or direction has changed since the last time they were asked.
function spindleOn(_spindleSpeed, _clockwise) {
  var mode = getProperty(properties.jobSpindleControl);

  if (mode == "manual") {
    var rpm = speedFormat.format(_spindleSpeed);

    // Under manual control any positive speed just means "on": there is no S word to command.
    if (currentSpindleSpeed == 0) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual");
      // Direction is named only when counterclockwise: clockwise is the default for every tool these machines
      // hold, so naming it would add a word to every job's start prompt.
      askUser("Turn ON " + rpm + " RPM" + (_clockwise ? "" : " counterclockwise"), "Spindle", false);
    }

    // Either change prompts: setSpindleSpeed() calls here for a later operation's new speed, and for a tapping
    // reversal at an unchanged speed.
    else if (rpm != lastPromptedSpeed || _clockwise != lastPromptedClockwise) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual change");
      // Here direction is always named, even when only the speed moved: a change prompt states the whole
      // target state, not a delta.
      askUser("Set spindle to " + rpm + " RPM " + (_clockwise ? "clockwise" : "counterclockwise"),
        "Spindle", false);
    }

    lastPromptedSpeed = rpm;
    lastPromptedClockwise = _clockwise;
  }

  // A switched output: on or off. S255 is that flag and not a speed -- M106 clamps S to 255 and M42
  // truncates it to a byte, so the RPM goes to the comment. Direction is ignored; a relay has no M4.
  // No parentheses in these comments: writeCommentLine() collapses them.
  else if (mode == "M106" || mode == "M42") {
    if (currentSpindleSpeed == 0) {
      writeComment(eComment.Important, " >>> Spindle ON -- " + speedFormat.format(_spindleSpeed)
        + " RPM requested, and this output carries no speed");
      writeFanOrPinOutput(mode, getProperty(properties.jobSpindlePinFan), 255);
    }

    // setSpindleSpeed() reaches us on a later speed change too. Nothing to emit -- but the file must not
    // go silent about a speed the job asked for and cannot get.
    else {
      writeComment(eComment.Important, " >>> Spindle Speed " + speedFormat.format(_spindleSpeed)
        + " RPM requested and NOT commanded -- this output is on/off only");
    }
  }

  else {
    writeComment(eComment.Important, " >>> Spindle Speed " + speedFormat.format(_spindleSpeed));
    writeBlock(mFormat.format(_clockwise ? 3 : 4), sOutput.format(_spindleSpeed));
  }

  currentSpindleSpeed = _spindleSpeed;
  currentSpindleClockwise = _clockwise;
}

// Stop the spindle, or ask the operator to and beep where the firmware has M300.
function spindleOff() {
  var mode = getProperty(properties.jobSpindleControl);

  // Tested before the firmware: manual describes the machine -- a hand-switched router -- not the dialect, and
  // a bare M5 does nothing to such a router on any firmware.
  if (mode == "manual") {
    // No M5 here, as spindleOn() emits no M3: the operator owns this spindle, so the post asks.
    if (fw != eFirmware.GRBL) {
      writeBlock(mFormat.format(300), sFormat.format(300), pFormat.format(3000));   // beep -- no M300 on GRBL
    }
    askUser("Turn OFF spindle", "Spindle", false);
  } else if (mode == "M106" || mode == "M42") {
    writeFanOrPinOutput(mode, getProperty(properties.jobSpindlePinFan), 0);
  } else {
    writeBlock(mFormat.format(5));
  }

  currentSpindleSpeed = 0;
}

// Collapse newlines and any of `unsafeChars` into a single space, so user-supplied text cannot break
// line, comment or quoted-parameter syntax. A blacklist per call site and deliberately not Autodesk's
// whitelist, which deletes what it does not list and would strip ">>> WARNING:" to " WARNING:". PV-19.
function sanitizeMessageText(text, unsafeChars) {
  var sanitized = String(text).replace(new RegExp("[\\r\\n" + unsafeChars + "]+", "g"), " ");
  return sanitized.replace(/(\S) {2,}(?=\S)/g, "$1 ");
}

// Put a line on the machine's own display.
function displayText(txt) {
  if (fw == eFirmware.GRBL) {
    // GRBL has no display command, so it gets nothing.
  }

  else {
    writeBlock(mFormat.format(117), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + sanitizeMessageText(txt, "();"));
  }
}

// Emit an arc as G2/G3, or linearize it where "Use Arcs" is off. Only planar partial arcs reach here.
function circular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (!getProperty(properties.jobUseArcs)) {
    linearize(tolerance);
    return;
  }

  // Scale the arc's feed to the axis limits, as linearMovements() does for a G1. Here rather than in
  // onCircular(), so the linearize() paths re-enter through onLinear() and are limited the usual way.
  feed = limitArcFeed(feed);

  var start = getCurrentPosition();

  // Full circles never arrive: maximumCircularSweep = 180 splits them into two arcs upstream, and
  // helical moves are linearized by the kernel.

  if (fw == eFirmware.GRBL) {
    switch (getCircularPlane()) {
        case PLANE_XY:
            writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), fOutput.format(feed));
            break;
        case PLANE_ZX:
            writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), fOutput.format(feed));
            break;
        case PLANE_YZ:
            writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), fOutput.format(feed));
            break;
        default:
            linearize(tolerance);
    }
  }

  else {
    // Off GRBL: XY only, others linearized
    switch (getCircularPlane()) {
      case PLANE_XY:
        writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), fOutput.format(feed));
        break;
      default:
        linearize(tolerance);
    }
  }
}

// Whether a "Jog to ..." mode works is a condition on what holds the pause, not a firmware capability.
// One statement of it, returned here and written by both channels; empty means no condition.
//   RepRap -- a genuine jog-at-pause; askUser()'s allowJog appends "X1 Y1 Z1" to M291.
//   GRBL -- the SENDER decides. gSender never sends the M0, rewriting it to "(M0)" above a
//   workflow.pause() (src/server/controllers/Grbl/GrblController.js, master, read 2026-08-14).
//   Marlin -- neither: idle() queues serial commands but never runs them (MarlinCore.cpp, 2.1.2.5), so
//   a jog sent at the pause runs late. The panel's move-axis UI is not gcode and is unaffected.
function jogAtPauseCondition() {
  if (fw == eFirmware.REPRAP) {
    return "";
  }
  if (fw == eFirmware.GRBL) {
    return "jogging at this pause depends on your sender, not on GRBL -- gSender comments the M0 out"
      + " and pauses its own stream, so the controller stays Idle and accepts jog commands, while a"
      + " sender that passes M0 through leaves the controller in a hold that refuses them";
  }
  return "jogging at this pause needs the machine's own panel, or a sender that holds the file and does"
    + " not send the M0 -- Marlin's M0 blocks inside wait_for_user_response, whose idle loop queues"
    + " serial commands without executing them, so a jog sent down the wire does not move the machine"
    + " until the pause is released and then runs late. MarlinCore.cpp, 2.1.2.5";
}

// Write the jog condition into the file, where there is one to write.
function warnJogAtPauseNeedsSender() {
  var condition = jogAtPauseCondition();
  if (condition == "") {
    return;
  }
  // TWIN #14
  writeWarning(condition + ". Check this before running the file: without it the job stops here and"
    + " cannot be moved until it is resumed.");
}

function askUser(text, title, allowJog) {
  if (fw == eFirmware.REPRAP) {
    // No leading space in v1: writeBlock() supplies one with "Include Whitespace" on and the prefix below
    // supplies one with it off, so a third would put two spaces after M291.
    var v1 = "P\"" + sanitizeMessageText(text, "\"") + "\" R\"" + sanitizeMessageText(title, "\"") + "\" S3";
    var v2 = allowJog ? " X1 Y1 Z1" : "";
    writeBlock(mFormat.format(291), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + v1 + v2);
  }

  // The comma in "MSG," is required: grblHAL matches strncasecmp(comment, "MSG,", 4) in gc_normalize_block()
  // (grblHAL/core gcode.c, read 2026-08-14). No space after it: grblHAL trims one, but FluidNC's
  // gcode_comment_msg() skips four characters after "MSG" (FluidNC/src/GCode.cpp). grbl 1.1 drops it. CR-02.
  else if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(0), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + "(MSG," + sanitizeMessageText(text, "();") + ")");
  }

  else
  {
    writeBlock(mFormat.format(0), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + sanitizeMessageText(text, "();"));
  }
}

// The first tool is loaded, not changed: nothing is running, no Z0 exists yet, and the tool stands where the
// operator left it -- so none of toolChange()'s retract, stop and re-probe is owed. Called unconditionally,
// so the load-before-origin order lives in one place. "At a Tool Change" decides who loads it: an M0 prompt
// on Refuse and on Pause (they differ only at a later change), the macro hand-over on Macro. PV-13.
function toolChangeFirstLoad() {
  if (getProperty(properties.toolChangeFirstToolCorrect)) {
    return;
  }

  // Pre-jogged origin: the jog was made with a tool fitted, so "First Tool is Correct" Off contradicts the
  // mode, and a macro change would move the tool off the position about to be recorded. Warned, not refused:
  // nothing unsafe is emitted. PV-13.
  if (originIsPreJogged()) {
    writeComment(eComment.Debug, " toolChangeFirstLoad: suppressed -- " + quoted(properties.probeOnStart) + " records a pre-jogged origin");
    // TWIN #15
    writeWarning(quoted(properties.toolChangeFirstToolCorrect) + " is Off and nothing was emitted to load one -- " + quoted(properties.probeOnStart)
      + " takes this part's origin from where you jogged the tool before starting this file, so"
      + " the tool that made that jog is the one this job assumes and measures from. Fitting a different"
      + " one here would put every depth out by the difference in tool length, and on a hand-over it"
      + " would move the tool off the position about to be recorded. To load the tool during the run"
      + " instead, use " + quotedValue(properties.probeOnStart, "Jog XY & Probe Z") + " or " + quotedValue(properties.probeOnStart, "Jog XYZ") + ", which load first and position"
      + " afterwards.");
    return;
  }

  // A changer can act on neither: "T0 M6" names no tool, and a laser is not in a changer. The M0 prompt is
  // unaffected -- a person can fit a laser. Both channels, so it can be fixed before posting. PV-13.
  if (toolChangeIsMacro() && (tool.number == 0 || tool.isJetTool())) {
    writeComment(eComment.Debug, " toolChangeFirstLoad: suppressed -- tool 0 or a jet tool cannot be handed over");
    warnBothChannels(quoted(properties.toolChangeFirstToolCorrect) + " is Off and the first tool is a jet tool or tool 0, which"
      + " no tool changer can fit and no supported handler can act on -- \"T0 M6\" names no tool. Nothing"
      + " was emitted to load it, so this job assumes whatever is in the spindle now. Fit it before"
      + " starting the file, or set " + quoted(properties.toolChangeMode) + " to " + quotedValue(properties.toolChangeMode, "Pause") + " to be asked"
      + " during the run.");
    return;
  }

  if (toolChangeIsMacro()) {
    // The resume is not a mid-job leftover here: writeWCS() has selected the offset, Start() set the modals,
    // and the tool returns to the height writeWcsOnStart() expects. The include files are not loaded:
    // "Tool Change Start" runs at cutting height, and nothing has cut yet.
    writeComment(eComment.Important, " Load the first tool -- handed over, not prompted");
    writeComment(eComment.Info, "   Before this part's origin is set, so Z0 is established with the tool that cuts it");
    toolChangeMacroCall();
    toolChangeMacroResume();
    return;
  }

  writeComment(eComment.Important, " Load the first tool");
  writeComment(eComment.Info, "   Before this part's origin is set, so Z0 is established with the tool that cuts it");
  askUser("Load Tool #" + tool.number + " " + tool.comment, "Tool change", false);
}

// True where nothing between homing and the first part's probe can move the tool: no macro loads the
// first tool, and no Start File include runs -- the post cannot read what one does. One definition for
// both halves of TWIN #12, so the dialog and the file name the same height. RV-17.
function toolStillWhereHomingLeftIt() {
  return !firstToolChangeIsHandedOver() && getProperty(properties.includeStartFile) == "";
}

// True where the first tool is loaded by the macro hand-over, not by a prompt or not at all. One definition,
// read by three validateJob() guards and the emitter alike. It carries both suppressions above, so no guard
// complains about a hand-over that never happens. PV-13.
function firstToolChangeIsHandedOver() {
  if (!toolChangeIsMacro() || getProperty(properties.toolChangeFirstToolCorrect) || originIsPreJogged()) {
    return false;
  }
  if (getNumberOfSections() < 1) {
    return false;
  }
  var firstTool = getSection(0).getTool();
  return firstTool.number != 0 && !firstTool.isJetTool();
}

// True when the job is set to hand a change to something outside the post. One definition, because
// validateJob()'s guards, the include pre-flight and the flow itself must not be able to disagree.
function toolChangeIsMacro() {
  return getProperty(properties.toolChangeMode) == "Macro";
}

// True only where a sender must strip the M6. FluidNC takes the same "T<n> M6" but runs it itself, via the
// "atc:" or "m6_macro:" in config.yaml (FluidNC/src/GCode.cpp, FluidNC/src/Spindles/Spindle.cpp, v3.9.6).
// A new handler must go in this and toolChangeNeedsGrblDialect() deliberately, or the guards disagree. FR-1.
function toolChangeNeedsSenderIntercept() {
  var id = getProperty(properties.toolChangeSender);
  return id == "gSender" || id == "CNCjs" || id == "UGS";
}

// The handlers whose token is GRBL's, which is a larger set: the three senders' "T<n> M6" and FluidNC's,
// the same two words to a controller that acts on them itself. RepRap's bare T word and Other's file are
// neither, and each has its own guard.
function toolChangeNeedsGrblDialect() {
  return toolChangeNeedsSenderIntercept() || getProperty(properties.toolChangeSender) == "FluidNC";
}

// The dialog title of the chosen handler, for messages that name it. Reads the enum's own titles so a
// warning and the dropdown cannot come to say different things about the same setting.
function toolChangeSenderTitle() {
  var id = getProperty(properties.toolChangeSender);
  var vals = properties.toolChangeSender.values;
  for (var i = 0; i < vals.length; ++i) {
    if (vals[i].id == id) {
      return vals[i].title;
    }
  }
  return id;
}

// The manual change's optional excursion to where the operator can reach the tool. Only when
// toolChangeMovesToPosition() is true, which validateJob() also checks.
//
// Every block is G53 through writeMachineFrameBlock(), like the retract and end park -- never a bare G0,
// which the active WCS would read. X/Y and Z are separate blocks, G53 not being modal, and X/Y goes first:
// the tool starts at Machine Travel Z, the height declared to clear every fixture.
function writeToolChangePosition() {
  var x = toolChangePosX();
  var y = toolChangePosY();
  var z = toolChangePosZ();

  if (x != undefined && y != undefined) {
    writeComment(eComment.Info, "   Move to the tool change position in the machine frame -- machine X"
      + xyzFormat.format(propertyMmToUnit(x)) + " Y" + xyzFormat.format(propertyMmToUnit(y)));
    writeMachineFrameBlock([xFormat.format(propertyMmToUnit(x)), yFormat.format(propertyMmToUnit(y))],
      getProperty(properties.feedsTravelSpeedXY));
  }

  if (z != undefined) {
    writeComment(eComment.Info, "   Move to the tool change height in the machine frame -- machine Z"
      + xyzFormat.format(propertyMmToUnit(z)));
    writeMachineFrameBlock([zFormat.format(propertyMmToUnit(z)), undefined],
      getProperty(properties.feedsTravelSpeedZ));
  }

  // Sync after the last motion: writeMachineTravelZ() flushed before these blocks, and the machine must stand
  // still before anything prompts.
  flushMotions();
}

// The manual change's return, not a retrace. Two things are owed: the height, since the change height may be
// below the travel height later moves assume; and XY-before-Z for the next rapid, the tool now standing over
// a point the work offset has no number for. No X/Y return: resetAll() discarded the tracked position so
// the next move is absolute, and where the work offset also changes here the post cannot relate the two
// frames, their origins being probed at runtime.
function writeToolChangeReturn() {
  if (toolChangePosZ() != undefined) {
    writeMachineTravelZ("Return to the travel height in the machine frame after the tool change");
  }

  // Only an X/Y excursion owes the ordering: a Z-only change position returns the tool to the point and
  // height it left.
  if (toolChangePosX() != undefined) {
    writeComment(eComment.Info, "   The tool stands at the change position; the next rapid crosses at"
      + " this height before it descends");
    forceRapidXYBeforeZ = true;
  }
}

// The post changes no tool on either flow: a measured change needs a probe, a subtraction and a register to
// hold the result, and the post can never read a register back. Its role is to arrive, hand over and resume
// correctly -- the three steps below. design.md -> Tool changes.
//
// Nothing is emitted that nothing will act on. No M84 Z: Marlin-only, so GRBL halts on it, and on Marlin
// released steppers sink an unbalanced gantry in Z. No M300 here: spindleOff() beeps for a hand-switched
// spindle off GRBL. No M6 except in toolChangeMacroCall(), where something named acts on it. No onRapid() of
// the post's own: a machine-frame move through it would clear forceSectionToStartWithRapid and defeat
// "First G1 --> G0" after a change.
//
// partOriginEstablishesZ0 -- true where the origin work after this call sets Z0 itself, with the tool fitted
// here. Then the re-probe below is dropped as a duplicate; where false, nothing else corrects Z0. PR-23.
function toolChange(partOriginEstablishesZ0) {
  writeComment(eComment.Important, " Tool Change Start");

  if (getProperty(properties.includeToolFile1) != "") {
    loadFile(getProperty(properties.includeToolFile1));
  }

  // --- 1. Arrive. Leave the machine in the state a hand-over is entitled to assume. ---------------

  // Retract in the machine frame, unconditionally even where that repeats a G53 block: the post tracks no
  // machine-frame position, so "already there" would be a belief to maintain. PR-23.
  if (fixedZEstablishedInFile()) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before the tool change");
    // After the retract and not instead of it: the excursion crosses the bed, so it may only start
    // from the height that clears the fixtures -- which is why the position fields require Machine
    // Travel Z rather than replacing it.
    if (toolChangeMovesToPosition()) {
      writeToolChangePosition();
    }
  } else {
    // TWIN #16
    writeWarning("no retract before this tool change -- this job establishes no fixed Z reference, so"
      + " the tool is handed over at whatever height the last operation ended at. Enter " + quoted(properties.machineTravelZ)
      + " in " + quotedGroup("machine") + ", or retract by hand before touching the tool");
      // Only this arm owes the sync: the retract above ends with its own flushMotions(), and a second would
      // emit M400 twice on Marlin and RRF.
    flushMotions();
  }

  // On every route, not only the one that moves the tool: coolant stops for the hand-over itself.
  onCommand(COMMAND_COOLANT_OFF);

  // Not onCommand(COMMAND_STOP_SPINDLE): its !tool.isJetTool() guard reads `tool`, already the incoming tool,
  // so a router-to-laser change would leave the router turning. currentSpindleSpeed says what is running.
  if (currentSpindleSpeed > 0) {
    spindleOff();
  }

  // --- 2. Hand over. The whole difference between the two flows is these four lines. --------------

  if (toolChangeIsMacro()) {
    toolChangeMacroCall();
    toolChangeMacroResume();
  } else {
    // No jogging at this pause, which is why allowJog is false and no jog condition is written beside
    // it. Everything after the pause is absolute in a frame the post is tracking; a jog would move the
    // machine out from under that without the post ever knowing.
    askUser("Change to Tool #" + tool.number + " " + tool.comment, "Tool change", false);
    // The manual change's resume, owed only where the tool was moved.
    if (toolChangeMovesToPosition()) {
      writeToolChangeReturn();
    }
  }

  // --- 3. Resume. Who owns the work Z0 the next operation cuts against. ---------------------------

  // The new tool is a different length, so the stored work Z0 belongs to the old one unless something corrects
  // it. The re-probe goes through partProbe(), so it honours "Probe X/Y Offset" and "Probe Pause", writes a
  // provisional Z0 first, and lands in the active offset -- onSection() selects it before calling here, which
  // is why a change that is also a WCS change owes no extra correction. PR-23.
  //
  // Which other parts' Z0 goes stale depends on "Tool Length Correction By", so it is settled here for every
  // route: Probe and Manual each fix the active offset only and mark the rest stale; Offset shifts the whole
  // Z frame, so nothing goes stale. CR-17, PV-10.
  var correction = toolLengthCorrection();
  if (correction == "Probe") {
    wcsZ0Trusted = {};
  } else if (correction == "Manual") {
    // currentWorkOffset, not the section's: onSection() selects the WCS before calling here, so the register
    // active at the pause is this one.
    var zeroedByHand = currentWorkOffset;
    wcsZ0Trusted = {};
    wcsZ0Trusted[zeroedByHand] = true;
  }

  if (partOriginEstablishesZ0) {
    // Not set here: writeWcsEstablish() does the work, so it sets wcsZ0Trusted[currentWorkOffset].
    writeComment(eComment.Important, " Work Z0 for this part is established below, with the tool fitted"
      + " at this change -- anything measured during the change above is overwritten there");
  } else if (correction == "Probe") {
    if (tool.number != 0 && !tool.isJetTool()) {
      if (toolChangeIsMacro()) {
        // Stated, not warned: probing after a macro is legitimate and so is turning it off, and the
        // post cannot tell which handler it is talking to.
        writeComment(eComment.Important, " Work Z0 re-established by this post, AFTER the macro --"
          + " whatever the macro measured is overwritten below");
      }
      partProbe(false, true);
      wcsZ0Trusted[currentWorkOffset] = true;
    } else {
      // Suppressing the probe is right; silence is not -- the warning below is the same rule
      // writeWcsOnStart()'s tool-0 arm follows.
      writeComment(eComment.Debug, " toolChange: re-probe skipped -- tool 0 or a jet tool cannot probe");
        // TWIN: here -- the change-side twin of writeWcsOnReturn()'s warning, one boundary earlier: Z0
        // measures from a tool no longer fitted, and this post cannot correct it. W26.
      warnBothChannels("this change fits a jet tool / tool 0, which cannot probe, so work Z0 still measures"
        + " from the tool just removed -- set Z0 by hand at the pause above before the next operation"
        + " cuts or fires");
    }
  } else if (correction == "Offset") {
    // An offset corrects the FRAME, the one correction leaving every other part valid; the post cannot
    // see whether one was applied, so it states the condition rather than asserting a defect.
    // TWIN: none -- a dialog line here would fire on a correctly configured job. PV-10.
    writeWarning("this post re-established nothing after the tool change above -- every depth below is"
      + " measured from the work Z0 already stored, and that is right only because a tool-length offset"
      + " was applied" + (toolChangeIsMacro() ? " by \"" + toolChangeSenderTitle() + "\"" : "")
      + ". An offset shifts the whole Z frame, so every part in this job stays measured correctly. If"
      + " nothing applied one, STOP: re-zero Z by hand and set " + quoted(properties.toolChangeZ0Correction) + " to match"
      + " what actually happens at your changes");
  } else {
    // "Manual": a re-zero at the pause reaches only the register active then, so an operator who did as told
    // would cut the next part a tool length deep unless told. Not alarmist: the clearing above makes every
    // other part re-measured, or warned about, at its own return.
    var strandedParts = collectDistinctOffsets().length - 1;
    // TWIN #17
    writeWarning("work Z0 was NOT re-established after this tool change, so it still measures from the"
      + " PREVIOUS tool's length and every depth below is out by the difference between the two."
      + " Re-zero Z by hand at the pause above"
      + (strandedParts > 0
          ? ", which corrects THIS part and no other -- the remaining " + strandedParts + " part"
            + (strandedParts == 1 ? " is" : "s are") + " marked stale here, and re-measured, or"
            + " warned about, at the return to each"
          : ", or set " + quoted(properties.toolChangeZ0Correction) + " to " + quotedValue(properties.toolChangeZ0Correction, "Probe") + " to have it"
            + " probed"));
  }

  if (getProperty(properties.includeToolFile2) != "") {
    loadFile(getProperty(properties.includeToolFile2));
  }

  // The rest of the resume is onSection()'s own: it restarts the spindle and the coolant after this
  // returns, and the section's first motion is a rapid.
  writeComment(eComment.Important, " Tool Change End");
}

// Flow 2's hand-over: emit the handler's token once, and nothing around it the handler will redo. The token
// differs by target, which is why the handler is a dropdown:
//   gSender / CNCjs / UGS -- "T<n> M6", which GRBL and grblHAL do not execute: they answer error:20 with
//   the tool in the cut. It works only because the sender strips the M6 first -- in its Grbl controller's
//   dataFilter for gSender and CNCjs (src/server/controllers/Grbl/GrblController.js), and in UGS's
//   ToolChangeInterceptor, which matches "(?i)(?<![A-Z])M0?6(?![0-9])" and sends the T to the controller
//   (ugs-core/src/com/willwinder/universalgcodesender/services/interceptor/, master, 2026-08-17). All three
//   are off until the operator turns them on, and the post can verify none of it.
//
//   FluidNC -- the same "T<n> M6", not intercepted: case 6 sets ToolChange::Enable and STEP 4 calls
//   spindle->tool_change(), which runs the "atc:" changer or the "m6_macro:" in config.yaml -- and with
//   neither returns true having done nothing, so the job cuts on with the tool already fitted
//   (FluidNC/src/GCode.cpp, FluidNC/src/Spindles/Spindle.cpp, v3.9.6; src/ToolChangers/ exists at 3.9.0 and
//   404s at 3.8.0). A sender set to strip the M6 here removes the token the firmware acts on. FR-1.
//
//   RepRapFirmware -- "T<n>" and no M6: the T word is the change, running tfree/tpre/tpost.
//   Other -- no token; the operator's file is the hand-over, through loadFile().
function toolChangeMacroCall() {
  var sender = getProperty(properties.toolChangeSender);

  if (sender == "Other") {
    writeComment(eComment.Important, " Hand over to \"" + getProperty(properties.toolChangeMacroFile)
      + "\" -- the post emits no token of its own");
    loadFile(getProperty(properties.toolChangeMacroFile));
    return;
  }

  if (sender == "RepRap") {
    writeComment(eComment.Important, " Hand over to RepRapFirmware -- T" + tool.number
      + " runs tfree/tpre/tpost");
    // Tool number first: most of Autodesk's own tools have an empty tool.comment. PV-6.
    writeComment(eComment.Info, "   Tool #" + tool.number
      + (tool.comment ? " " + tool.comment : "") + ", declared with M563 in config.g");
    writeBlock(tFormat.format(tool.number));
    return;
  }

  if (sender == "FluidNC") {
    writeComment(eComment.Important, " Hand over to FluidNC -- it executes the M6 below itself");
    // Tool number first, and the comment only where there is one, as in the RepRap arm above.
    writeComment(eComment.Info, "   Tool #" + tool.number + (tool.comment ? " " + tool.comment : "")
      + ", through the \"atc:\" or \"m6_macro:\" named in config.yaml");
    writeBlock(tFormat.format(tool.number), mFormat.format(6));
    return;
  }

  writeComment(eComment.Important, " Hand over to " + sender + " -- it must intercept the M6 below;"
    + " stock Grbl and grblHAL answer error:20");
  writeComment(eComment.Info, "   Tool #" + tool.number + " " + tool.comment);
  writeBlock(tFormat.format(tool.number), mFormat.format(6));
}

// Flow 2's resume: restore the frame and modal state the handler may have disturbed, and return the tool to
// a known height. Unconditional on the handler: the post cannot read a macro it did not write. Modals are
// written only on change, so a G91 or G20 left behind would be inherited silently; the resets force each out.
function toolChangeMacroResume() {
  gPlaneModal.reset();
  gMotionModal.reset();
  gAbsIncModal.reset();
  gUnitModal.reset();
  gFeedModeModal.reset();
  resetAll();

  writeComment(eComment.Info, "   Resume: re-assert what the macro may have changed");
  writeBlock(gAbsIncModal.format(90));
  writeBlock(gUnitModal.format(unit == IN ? 20 : 21));

  // GRBL only, and for Start()'s reasons rather than this function's: Marlin compiles G17 only under
  // CNC_WORKSPACE_PLANES and has no G93/G94 at all, and RRF gained G93/G94 only in 3.5.1. Re-asserting
  // a mode the firmware does not have is an unknown command, not insurance.
  if (fw == eFirmware.GRBL) {
    writeBlock(gFeedModeModal.format(94));
    writeBlock(gPlaneModal.format(17));
  }

  // Not through writeWCS(), which returns without emitting when the offset is unchanged -- and unchanged
  // is exactly the case here: the post's belief is what the macro may have invalidated. It re-selects
  // currentWorkOffset's own G5x, never a fixed G54. Marlin never reaches here, validateJob() refusing it.
  if (currentWorkOffset != undefined) {
    var reselect = wcsGcode(currentWorkOffset);
    if (reselect != undefined) {
      writeComment(eComment.Info, "   Re-select the active work offset -- the macro may have changed it");
      writeBlock(gFormat.format(reselect));
    }
  }

  // Back to a known height before anything else moves: the macro may have left the tool anywhere, and
  // resetAll() discarded the tracked position, so the next move emits full coordinates -- safe in Z only
  // from a height the post chose. A job with no fixed reference gets a warning and nothing to move to.
  if (fixedZEstablishedInFile()) {
    writeMachineTravelZ("Return to the travel height in the machine frame after the tool change");
  } else {
    // TWIN #18
    writeWarning("the tool was NOT returned to a known height after the tool change -- this job"
      + " establishes no fixed Z reference, so wherever the macro left the tool is where the next move"
      + " starts from. Enter " + quoted(properties.machineTravelZ) + " in " + quotedGroup("machine"));
  }
}

// Probe Z and write it as the origin of the ACTIVE work offset. Load-bearing that the target is the
// active WCS and not an argument: on Marlin an origin write is "G92" against whichever workspace is
// selected, so a probe result can only ever land in the active one. Every caller writes a provisional
// Z0 first, which is what makes "G38 Target" a distance to search. CR-11, CR-12.
function probeTool() {
  var targetWcs = currentWorkOffset;
  var searchZ = propertyMmToUnit(getProperty(properties.probeG38Target));
  var retractZ = safeZ();
  writeComment(eComment.Important, " Probe to Zero Z");
  if (probePauseBefore) writeComment(eComment.Info, "   Ask User to Attach the Z Probe");
  writeComment(eComment.Info, "   Do Probing");
  writeComment(eComment.Info, "   Set Z to probe thickness: " + zFormat.format(propertyMmToUnit(getProperty(properties.probeThickness))));
  writeComment(eComment.Info, "   Retract the tool to " + xyzFormat.format(retractZ));
  if (probePauseAfter) writeComment(eComment.Info, "   Ask User to Remove the Z Probe");

  if (probePauseBefore) askUser("Attach ZProbe", "Probe", false);

  if (fw == eFirmware.GRBL) {
    // refer to http://linuxcnc.org/docs/stable/html/gcode/g-code.html#gcode:g38
    // Note this is not using the optional P parameter available on FluidNC (http://wiki.fluidnc.com/en/config/probe)
    writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probeG38Speed))), zFormat.format(searchZ));
  }

  else {
    // See http://marlinfw.org/docs/gcode/G038.html
    if (getProperty(properties.probeG382orG28)) {
      writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probeG38Speed))), zFormat.format(searchZ));
    } else {
      writeBlock(gFormat.format(28), 'Z');
    }
  }

  writeWcsOrigin(targetWcs, undefined, undefined, propertyMmToUnit(getProperty(properties.probeThickness)));

  // Load-bearing: the G38.2 block writes F and Z through the RAW formats so the modal cannot suppress
  // them, which leaves the tracked feed stale -- the next move matching it would run at probe speed.
  resetAll();
  rapidMovementsZ(retractZ);

  flushMotions();

  if (probePauseAfter) askUser("Detach ZProbe", "Probe", false);

  // Restore the default for a probe not reached through partProbe(), which sets its own.
  probePauseBefore = true;
  probePauseAfter = true;
}