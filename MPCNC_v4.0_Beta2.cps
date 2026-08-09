/*
**
Version 4.0 (Beta 2)

Updated to new method of handling properties

MPCNC posts processor for milling and laser/plasma cutting.

Changed Feb 2, 2025
**
*/

description = "v4.0 (Beta 2) MPCNC Milling/Laser for Marlin, Grbl, RepRap";
vendor = "flyfisher604";
vendorUrl = "https://github.com/flyfisher604/mpcnc_post_processor";
longDescription = "MPCNC F360 Post processor. Supports scaling of speeds to accomidate slow Z axis. Warning: BETA review all GCode.";

// Internal properties
legal = "Copyright (C) 2019 - 2025 Don Gamble.";
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
maximumCircularSweep = toRad(180); // split arcs >180 deg (so full circles post as two arcs, avoiding start==end full-circle quirks on some firmware)
allowHelicalMoves = false;
allowedCircularPlanes = undefined;

// Lets Fusion's UI resolve a section's raw work offset to its actual G-code before posting, instead
// of showing the bare index. useZeroOffset: false matches the other official posts; it does not change
// how writeWCS() resolves offset 0, which is still silently aliased to WCS 1 / G54 there.
wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"GRBL/RepRap", format:"G", range:[54, 59]},   // G54-G59 (raw offset 1-6)
    {name:"RepRap only", format:"G59.", range:[1, 3]}    // G59.1-G59.3 (raw offset 7-9)
  ]
};

machineMode = undefined; //TYPE_MILLING, TYPE_JET

// How far the SPOILBOARD BASE probe may search, in MM. A DISTANCE below wherever the tool is parked,
// not a position: writeBaseEstablish() writes a provisional Z0 at that height first, which is what
// makes a distance meaningful. Deliberately NOT the "G38 Target" property -- that one is sized for a
// PART probe, which starts a few mm above the stock top, while this probe starts above the stock AND
// the clamps, so one number cannot serve both. Long is the safe answer here and nowhere else: the base
// is probed over bare spoilboard by operator precondition, so the only thing under the tool is the
// surface being looked for. A constant and not a control -- the operator has no number to supply that
// this does not already cover, and every extra field in group 5 is one more thing to set wrong.
const BASE_PROBE_REACH_MM = 100;

var eFirmware = {
    MARLIN: "Marlin",  // Marlin 2.x
    GRBL: "Grbl",      // Grbl 1.1
    REPRAP: "RepRap",
  };

var fw =  eFirmware.MARLIN; 

// Uses indexof to determine priority of comments
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

// Maps Fusion's numeric tool.coolant to a coolant name, so the index IS the F360 constant:
// 0 COOLANT_DISABLED, 1 FLOOD, 2 MIST, 3 THROUGH_TOOL, 4 AIR, 5 AIR_THROUGH_TOOL, 6 SUCTION,
// 7 FLOOD_MIST, 8 FLOOD_THROUGH_TOOL. Order is fixed by Fusion and must not be sorted. Built from
// eCoolant rather than repeating its strings, so the two cannot drift; eCoolant must stay above this
// line, as the assignment runs at load time and reads it.
const coolantLevels = [eCoolant.Off, eCoolant.Flood, eCoolant.Mist, eCoolant.ThroughTool,
                       eCoolant.Air, eCoolant.AirThroughTool, eCoolant.Suction, eCoolant.FloodMist,
                       eCoolant.FloodThroughTool];

// Dialog group definitions -- Post Processor Guide 5.1.5. A property's `group:` is a KEY into this
// object, not a label: `order` places the group, `title` is what the operator reads. Each key is the
// token the member properties' own keys carry (`job` <- `A_Job_...`), so a property filed under the
// wrong group is visible on sight. `order` starts at 100, clear of the built-in groups at 10..60, in
// steps of 10. Guard then augment key by key -- assigning a whole literal over the top of the guard
// would discard whatever it just preserved.
if (typeof groupDefinitions != "object") {
  groupDefinitions = {};
}
groupDefinitions.job        = {title: "1 - Job", order: 100};
groupDefinitions.feeds      = {title: "2 - Feeds and Speeds", order: 110};
groupDefinitions.mapRapids  = {title: "3 - Map G1s to Rapids - disable when using full license", order: 120};
groupDefinitions.machine    = {title: "4 - Machine Frame - homing and end park", order: 130};
groupDefinitions.spoilboard = {title: "5 - Fixed Z Reference - multi-part jobs only", order: 140};
groupDefinitions.probe      = {title: "6 - On WCS / Part / Fixture Changes", order: 150};
groupDefinitions.toolChange = {title: "7 - Tool Changes", order: 160};
groupDefinitions.include    = {title: "8 - External Include Files", order: 170};
groupDefinitions.laser      = {title: "9 - Laser", order: 180};
groupDefinitions.coolant    = {title: "10 - Coolant", order: 190};
groupDefinitions.duet       = {title: "11 - Duet", order: 200};

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
  jobManualSpindlePowerControl: {
    title      : "Manual Spindle On/Off",
    description: "On (default): the post PROMPTS you to work the router by hand and emits no M3/M5 at all -- a pause to switch it on at the start, to change speed or direction whenever the job asks for a different one, and to switch it off at each tool change and at the end. Leave it on for a trim router or any spindle with no electronic control, which is most MPCNC builds. Off: the post COMMANDS the spindle with M3/M5 instead, for a controller wired to switch it.",
    group      : "job",
    order      : 20,
    type       : "boolean",
    value      : true,
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
  jobSequenceNumbers: {
    title      : "Enable Line #s",
    description: "Include line numbers on each line.",
    group      : "job",
    order      : 50,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  jobSequenceNumberStart: {
    title      : "First Line #",
    description: "First line number used.",
    group      : "job",
    order      : 60,
    type       : "integer",
    value      : 10,
    scope      : "post"
  },
  jobSequenceNumberIncrement: {
    title      : "Line # Increment",
    description: "Increase line numbers by this increment.",
    group      : "job",
    order      : 70,
    type       : "integer",
    value      : 1,
    scope      : "post"
  },
  jobSeparateWordsWithSpace: {
    title      : "Include Whitespace",
    description: "Includes whitespace separation between text.",
    group      : "job",
    order      : 80,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },

  feedsTravelSpeedXY: {
    title      : "Travel Speed X/Y",
    description: "High speed for Rapid movements X & Y (mm/min).",
    group      : "feeds",
    order      : 10,
    type       : "integer",
    value      : 2500,
    scope      : "post"
  },
  feedsTravelSpeedZ: {
    title      : "Travel Speed Z",
    description: "High speed for Rapid movements Z (mm/min).",
    group      : "feeds",
    order      : 20,
    type       : "integer",
    value      : 300,
    scope      : "post"
  },
  feedsEnforceFeedrate: {
    title      : "Enforce Feedrate",
    description: "Feedrate is included on every g-code movement.",
    group      : "feeds",
    order      : 30,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  feedsScaleFeedrate: {
    title      : "Scale Feedrate",
    description: "On (default): every cut feedrate is scaled down so that no axis is asked to move faster than its limit below, and the resulting toolpath feed is capped at Max Toolpath Speed. Off: Fusion's feedrates are emitted exactly as the CAM produced them, and THE THREE LIMITS BELOW DO NOTHING AT ALL. Set those three to your machine's real capability before relying on this -- the shipped 900/180/1000 are generic MPCNC figures, and limits set below what your machine can actually do will quietly slow every cut in the job.",
    group      : "feeds",
    order      : 40,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  feedsMaxCutSpeedXY: {
    title      : "Max XY Cut Speed",
    description: "The fastest your machine may cut in X or Y, in mm/min. ONLY APPLIED WHEN SCALE FEEDRATE ABOVE IS ON -- with it off this field does nothing. 900 is a generic MPCNC figure; use your own machine's.",
    group      : "feeds",
    order      : 50,
    type       : "integer",
    value      : 900,
    scope      : "post"
  },
  feedsMaxCutSpeedZ: {
    title      : "Max Z Cut Speed",
    description: "The fastest your machine may cut in Z, in mm/min -- normally far slower than X/Y on a leadscrew Z. ONLY APPLIED WHEN SCALE FEEDRATE ABOVE IS ON -- with it off this field does nothing. 180 is a generic MPCNC figure; use your own machine's.",
    group      : "feeds",
    order      : 60,
    type       : "integer",
    value      : 180,
    scope      : "post"
  },
  feedsMaxCutSpeedXYZ: {
    title      : "Max Toolpath Speed",
    description: "A cap on the speed the tool travels ALONG ITS PATH, in mm/min, applied after the per-axis scaling above -- a diagonal move can stay inside both axis limits and still be faster than you want overall. ONLY APPLIED WHEN SCALE FEEDRATE ABOVE IS ON.",
    group      : "feeds",
    order      : 70,
    type       : "integer",
    value      : 1000,
    scope      : "post"
  },

  // ONE enabling control and one field. Group 3 answers a single question -- is the Personal edition
  // turning this job's rapids into cuts, and may the post turn them back?
  mapRapidsRestoreRapids: {
    title      : "Map G1s -> G0 Rapids",
    description: "Enable to convert G1s back to G0 Rapids where it is safe. Covers the three moves the F360 Personal edition emits as cuts: horizontal moves at or above the Safe Z below, vertical retracts and descents that stay above it, and the first move of every operation.",
    group      : "mapRapids",
    order      : 10,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  // NO PARENTHESES IN THIS TITLE. writeSafeZFormatWarning() prints it into an in-file warning, whose
  // text goes through sanitizeMessageText(_, "()") -- see writeWarning().
  mapRapidsSafeZ: {
    title      : "Safe Z to Rapid",
    description: "Z at or above this height is treated as safe air, so a G1 there may be re-emitted as a G0. Same syntax as group 6's Safe Z: a plain number in mm, or Feed:/Retract:/Clearance:<fallback> to use that operation's own Fusion level when it defines one, else the fallback -- Retract:15 (the default) means the Fusion retract level, or 15 mm if the operation has none.",
    group      : "mapRapids",
    order      : 20,
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },

  machineHomedAxes: {
    title      : "Axes Homed and Trusted",
    description: "DECLARE which axes your machine homes to endstops -- a fact about the machine, set once and never revisited. This is NOT an instruction to home anything; that is Home at Job Start below. None (default): no endstops, or you do not trust them; machine zero is wherever the controller was last reset. XY Only: X and Y home to endstops, so a work offset stored in a G54-G59 register still points at the same physical place after a power cycle; Z has no machine frame. Z Only: Z homes to a real endstop (LowRider switches) or to the Marlin movable-plate trick, so the machine has a Z frame that does not move with stock thickness -- a TRAVEL datum, never the cutting reference. XYZ: both. Only two things read this: Fixed Z Reference = Machine Z requires Z (and X/Y, for the multi-part traverses that clearance serves), and the post warns when a job trusts a STORED work offset without X/Y. Homing buys repeatability and nothing else -- your Z cutting zero always comes from the work-Z touch-off (see First WCS / Part), never from here.",
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
  machineHomeAtStart: {
    title      : "Home at Job Start",
    description: "THE ACTION -- whether this job homes the axes declared above, and whether it pauses first. Off (default): emit no homing and accept the machine's current position, whether that is a machine already homed at the controller or a power-on 0,0,0. Home: home at job start with no pause. Pause, then Home: stop once (M0) before ANY homing motion so you can prepare the machine -- place a movable Z-homing plate, clear the bed -- then home. That is a single stop whatever the firmware and however many axes home, so it never needs revisiting when the machine changes. THIS IS A PROPERTY OF THE JOB, which is why it is separate from the declaration above: a machine whose endstops exist can still be homed once at the controller and left alone for the rest of the session. Must not be Off when Fixed Z Reference = Machine Z: an absolute machine-frame move has to be measured against a frame this job established, not one a previous power cycle left behind.",
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
    description: "Where the tool parks when the job ends. Off: leave it where the last operation finished. Work X0 Y0 (default, and what this control has always done): rapid to X0 Y0 in the WCS the LAST operation used -- unambiguous on a single-part job, but on a multi-part job that is the last fixture's corner, and which fixture that is follows Fusion's operation order rather than anything you chose. Machine X0 Y0: the machine's own homing corner -- one park point for every job whatever its structure. It requires Axes Homed and Trusted to include X/Y, and on GRBL and RepRap it also requires Home at Job Start to be Home or Pause, then Home, because there it is a rapid that ADDRESSES a machine frame this job must already have established. On Marlin it homes X and Y instead, which RE-ESTABLISHES the frame rather than addressing it: no prior homing is needed, but it is a homing cycle and not a rapid -- slower, onto the endstops, and a larger motion. Marlin is therefore the one case where this works with Home at Job Start left Off. Note that on Marlin work X0 Y0 and machine X0 Y0 are NOT the same place once a job starts, and the post cannot read the difference back. Under either machine route, a job that has a Fixed Z Reference retracts to Inter Part Travel Z before traversing; a job with no fixed reference has no frame in which an absolute retract is meaningful and travels at the current Z.",
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

  spoilboardFixedZRef: {
    title      : "Fixed Z Reference",
    description: "MULTI-PART JOBS NEED THIS; A SINGLE-PART JOB DOES NOT -- leave it None and skip the rest of the group. The job's fixed Z reference is a frame whose Z0 does NOT move with stock thickness, and therefore the only frame in which one clearance height is meaningful across parts of differing thickness. This answer also decides WHICH FRAME Inter Part Travel Z below is measured in, so re-read that height whenever you change it. None (default): no fixed reference -- SINGLE-PART JOBS ONLY, because a multi-WCS job then has no frame in which one clearance height is meaningful and the post refuses to post it (Guard B); Inter Part Travel Z is ignored. Spoilboard: reserve a WCS and probe the spoilboard into it; Inter Part Travel Z is then a height above that surface. Reserved WCS and Probe to Set Base below are its sub-questions. Costs one of GRBL's six WCS registers. GRBL/RepRap only -- Marlin has no per-WCS registers. Machine Z: use the machine's own homed Z frame; Inter Part Travel Z is then an absolute machine coordinate. Consumes NO WCS register and needs no probe, but requires Axes Homed and Trusted to include Z AND Home at Job Start not Off, both in group 4 -- the frame an absolute move trusts must be one this job established. Not available on Marlin.",
    group      : "spoilboard",
    order      : 10,
    type       : "enum",
    values: [
      { title: "None", id: "None" },
      { title: "Spoilboard - probed into a reserved WCS", id: "Spoilboard" },
      { title: "Machine Z - homed", id: "Machine Z" }
    ],
    value: "None",
    scope: "post"
  },
  spoilboardBaseReserve: {
    title      : "Reserved WCS",
    description: "Which WCS to reserve as the spoilboard base -- a sub-question of Fixed Z Reference = Spoilboard, and ignored under any other answer. The selected WCS is reserved and no operation may re-establish its origin (see Probe to Set Base); assigning a part to it is Guard A. G59.1-G59.3 require RepRap. Note that reserving a base spends one of GRBL's six registers, which is the cost the Machine Z answer avoids.",
    group      : "spoilboard",
    order      : 20,
    type       : "enum",
    values: [
      { title: "None", id: "None" },
      { title: "G54", id: "1" },
      { title: "G55", id: "2" },
      { title: "G56", id: "3" },
      { title: "G57", id: "4" },
      { title: "G58", id: "5" },
      { title: "G59 ( -- recommended --)", id: "6" },
      { title: "G59.1 (RepRap)", id: "7" },
      { title: "G59.2 (RepRap)", id: "8" },
      { title: "G59.3 (RepRap)", id: "9" }
    ],
    value: "None",
    scope: "post"
  },
  spoilboardBaseEstablish: {
    title      : "Probe to Set Base",
    description: "How to establish the reserved spoilboard base's Z at job start. Probe Z: probe the spoilboard into the base WCS (G10 L20 P<n>) with no operator prompt (a fixed/known probe point). Pause, Probe Z, Pause (default): prompt the operator to attach the probe, probe, then prompt to detach -- the manual touch-off. Ignored unless Fixed Z Reference = Spoilboard, and on Marlin (no per-WCS registers). Always probed at the current position (0,0 / the job's XY origin) -- the Probe X/Y Offset never applies here, so park the tool over BARE spoilboard: whatever is under it becomes the base's Z0.",
    group      : "spoilboard",
    order      : 30,
    type       : "enum",
    values: [
      { title: "Probe Z", id: "Probe Z" },
      { title: "Pause, Probe Z, Pause", id: "Pause & Probe Z" }
    ],
    value: "Pause & Probe Z",
    scope: "post"
  },
  spoilboardTravelZ: {
    title      : "Inter Part Travel Z",
    description: "The height the tool holds while it travels between parts, in mm -- the one clearance that stays valid across parts of differing thickness. Set it to clear the tallest fixture, clamp and part in the job. WHICH FRAME THIS NUMBER IS MEASURED IN IS DECIDED BY FIXED Z REFERENCE ABOVE, and the two readings are unrelated numbers for the same physical plane -- re-read it whenever that answer changes. Ignored entirely when Fixed Z Reference = None. Spoilboard: a height ABOVE THE PROBED SPOILBOARD SURFACE, so positive, typically 30-60. It is used both immediately after the base is probed at job start, as the height the tool holds while travelling to the first part, and before each traverse to a different WCS. Machine Z: an ABSOLUTE MACHINE COORDINATE, signed. Get it once per machine: home, jog to a height that visibly clears everything on the bed, and read Z off your sender's DRO -- no touch-off and no arithmetic. It is often negative, which is normal and needs no adjusting. EMPTY BY DEFAULT UNDER BOTH ANSWERS, because a height carried over from the other frame is a valid-looking number in the wrong frame: the post refuses to post rather than guess. The value is echoed WITH ITS FRAME in the file's Resolved Values block, so check it there before the machine moves. UNDER THE MACHINE Z ANSWER THIS NUMBER BELONGS TO THE MACHINE, NOT TO THE JOB -- unlike every other height in this dialog it does NOT stay correct when a Setup is copied or a design is shared, so re-read it on any machine that is not the one it was measured on. A wrong value sends the tool to a wrong height at travel speed.",
    group      : "spoilboard",
    order      : 50,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  probeOnStart: {
    title      : "First WCS / Part",
    description: "Establishes the origin for the first (or only) part -- the WCS the first section resolves to (WCS 1 / G54 by default, or whatever that Setup specifies). TWO THINGS TO CHECK BEFORE PICKING A MODE. (1) The default assumes a WIRED, WORKING Z TOUCH PLATE; if you have none, choose Set X0 Y0 Z0 to Current Pos and touch Z off by hand before posting. (2) THE TWO JOG MODES DO NOT WORK ON GRBL, the default firmware -- only RepRap has a genuine jog-at-pause, and the post warns and says so in the file when a Jog mode is chosen on GRBL. Set X0 Y0 to Current Pos, Probe Z0 (default): record X0 Y0 at the current position, then probe the stock-top Z -- pre-jog the tool to the part's X0 Y0 before starting, no prompt. Set X0 Y0 Z0 to Current Pos: record the tool's CURRENT position as X0 Y0 Z0, no probe and no prompt -- a manual touch-off, or a jet/laser where Z is set by hand. Use Active WCS X0 Y0, Probe Z0: use the X0 Y0 already stored in the active WCS (a pre-set fixture offset) -- rapid there and probe the stock-top Z; XY is not re-zeroed. Use Active WCS X0 Y0 Z0: use the full stored origin -- no re-zero and no probe; the tool MOVES to the Safe Z set below, then rapids to the stored X0 Y0. That is a move, not a retract: Safe Z is absolute in the stored frame, so a tool parked above it starts the job by descending. Jog to X0 Y0, Probe Z0: pause (M0) so you jog to the origin during the run, record X0 Y0, then probe Z. Jog to X0 Y0 Z0: pause to jog, then record X0 Y0 Z0 there, no probe. \"ACTIVE WCS\" MEANS the register this Setup designates (its Work Offset: WCS 1 / G54 unless you changed it), which the post SELECTS at job start -- NOT whatever your sender had active, which the post overwrites. Its contents are left over from a prior job or a manual touch-off and cannot be read back, so both Use Active WCS modes TRUST them. On the two pre-jog modes, note that homing and the spoilboard base move the tool last, so \"current position\" means that point. For more parts or copies see Subsequent WCS / Part; for one part from multiple datums or a flip, run separate jobs.",
    group      : "probe",
    order      : 10,
    type       : "enum",
    values: [
      { title: "Set X0 Y0 to Current Pos, Probe Z0", id: "Current XY & Probe Z" },
      { title: "Set X0 Y0 Z0 to Current Pos", id: "Current XYZ" },
      { title: "Use Active WCS X0 Y0, Probe Z0", id: "Probe Z" },
      { title: "Use Active WCS X0 Y0 Z0", id: "Skip" },
      { title: "Jog to X0 Y0, Probe Z0", id: "Jog XY & Probe Z" },
      { title: "Jog to X0 Y0 Z0", id: "Jog XYZ" }
    ],
    value: "Current XY & Probe Z",
    scope: "post"
  },
  probeOnChange: {
    title      : "Subsequent WCS / Part",
    description: "MULTI-PART JOBS ONLY -- milling several parts or copies, one WCS per part. What to do when the job advances to the next part's WCS (G55, G56, ...). A single-part job never reaches this control. Not supported on Marlin at all, which has one global origin -- use separate jobs. THE TWO JOG MODES DO NOT WORK ON GRBL, the default firmware (see First WCS / Part); the post warns and says so in the file. Every mode first retracts to a safe Z, then acts. USE ACTIVE WCS (pre-set fixture offsets / Replicate) -- Use Active WCS X0 Y0, Probe Z0 (default): rapid to the part's stored X0 Y0 and probe its stock-top Z, writing Z into that WCS; XY stays the fixture's pre-set offset. Use Active WCS X0 Y0 Z0: do nothing to the origin; after the retract the tool rapids to the part's stored X0 Y0 (X, Y and Z already in its own WCS, from a prior job or set manually). JOG (you jog to each part during the run) -- Jog to X0 Y0, Probe Z0: pause (M0) to jog to this part's origin, record X0 Y0 there, then probe Z. Jog to X0 Y0 Z0: pause (M0) to jog to this part's origin, then record that position as X0 Y0 Z0, no probe. \"Active WCS\" means the register that part's Fusion Setup designates, which the post selects on the traverse; its stored contents come from a prior job or a manual touch-off and are trusted, not verified. The attach/detach prompts around any probe follow Probe Pause; the safe-Z retract on the traverse is separate, automatic, and measured in whatever frame Fixed Z Reference names. Does NOT support milling one part from multiple datums or a flip -- run those as separate jobs.",
    group      : "probe",
    order      : 20,
    type       : "enum",
    values: [
      { title: "Use Active WCS X0 Y0, Probe Z0", id: "Probe Z" },
      { title: "Use Active WCS X0 Y0 Z0", id: "Skip" },
      { title: "Jog to X0 Y0, Probe Z0", id: "Jog XY & Probe Z" },
      { title: "Jog to X0 Y0 Z0", id: "Jog XYZ" }
    ],
    value: "Probe Z",
    scope: "post"
  },
  probePause: {
    title      : "Probe Pause",
    description: "Operator pauses around each part probe (the first part and each added part) -- the prompts to attach the Z probe (before) and detach it (after). No: no prompts (a fixed/permanent probe). Before: prompt to attach only. Before & After (default): prompt to attach before probing and to detach after -- the manual touch-off. Applies to the part probes in this group only, not the spoilboard base probe (see Probe to Set Base) or the tool-change re-probe.",
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
  probeOffsetX: {
    title      : "Probe X Offset",
    description: "X distance from the part origin to the Z-probe touch-point, in whole mm (all dialog dimensions are in mm regardless of the job's output units). Applied at every PART probe -- the first/only part (First WCS / Part) and each added part (Subsequent WCS / Part) -- so the work origin can sit at a corner or off the material while Z is probed on the stock top. Job-wide, not per-fixture. Default 0 probes at the origin. Does NOT affect the spoilboard base probe (Probe to Set Base), which always touches off at the origin (0,0).",
    group      : "probe",
    order      : 40,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  probeOffsetY: {
    title      : "Probe Y Offset",
    description: "Y distance from the part origin to the Z-probe touch-point, in whole mm (all dialog dimensions are in mm regardless of the job's output units). Applied at every PART probe -- the first/only part (First WCS / Part) and each added part (Subsequent WCS / Part) -- so the work origin can sit at a corner or off the material while Z is probed on the stock top. Job-wide, not per-fixture. Default 0 probes at the origin. Does NOT affect the spoilboard base probe (Probe to Set Base), which always touches off at the origin (0,0).",
    group      : "probe",
    order      : 50,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  probeG382orG28: {
    title      : "Probe with G38.2",
    description: "Probe using G38.2 (On) or G28 (Off). This setting is read on Marlin and RepRap only -- GRBL always uses G38.2 whatever it says, and G38.2 is what a GRBL job always gets. On Marlin, Off (G28) is for a build with G38_PROBE_TARGET not compiled in, which uses the Z homing switch as a substitute reference. On RepRap the answer is version-bound: leave it On for RRF later than 3.1.1, but note that up to and including RRF 3.1.1 the G38.2 target is interpreted as MACHINE coordinates while this post emits a work-frame target, so On probes to the wrong physical Z there and Off is the safer answer.",
    group      : "probe",
    order      : 60,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  probeG38Target: {
    title      : "G38 Target",
    description: "How far the probe move is allowed to travel before giving up -- a Z POSITION in the part's frame, not a distance. This bounds the PART probes only: the spoilboard base probe has a fixed reach of its own, being the one probe that starts above the stock AND the clamps. On the two Set ... to Current Pos modes the post writes a provisional Z0 first, so -10 (the default) searches to 10 mm below wherever the tool is now. On the two Use Active WCS modes it is measured from that WCS's STORED Z zero instead, which may be anywhere. Deep enough to reach the plate and no deeper: a probe that travels this far without touching is a failed probe, and GRBL raises an alarm and stops the job.",
    group      : "probe",
    order      : 70,
    type       : "integer",
    value      : -10,
    scope      : "post"
  },
  probeG38Speed: {
    title      : "G38 Speed",
    description: "G38 probing's speed (mm/min).",
    group      : "probe",
    order      : 80,
    type       : "integer",
    value      : 30,
    scope      : "post"
  },
  probeSafeZ: {
    title      : "Safe Z",
    description: "Safe Z the tool retracts to after probing (also the retract height before an added-part re-probe when the job has no fixed Z reference; with one, that group's clearance -- Inter Part Travel Z -- is used instead). Same syntax as group 3's \"Safe Z to Rapid\": a fixed number, or Feed:/Retract:/Clearance:<fallback> to use the operation's F360 level when defined, else the fallback -- e.g. \"Retract:15\" uses the F360 retract level or 15. Kept independent of the Map G1s Safe Z.",
    group      : "probe",
    order      : 90,
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },
  probeThickness: {
    title      : "Plate Thickness",
    description: "Thickness of your Z touch plate, in mm regardless of the job's output units. The post subtracts it after the probe touches, so Z0 lands on the stock top rather than the plate top. Measure your own plate -- 0.8 is only a common value, and an error here shifts every cut depth in the job by the same amount.",
    group      : "probe",
    order      : 100,
    type       : "number",
    value      : 0.8,
    scope      : "post"
  },

  toolChangeEnabled: {
    title      : "Tool Changes are Included",
    description: "Tool changes are included in the NC file.",
    group      : "toolChange",
    order      : 10,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  toolChangeInsertCode: {
    title      : "Include Relocation Code",
    description: "Relocate the tool for manual tool changes.",
    group      : "toolChange",
    order      : 20,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  toolChangeX: {
    title      : "Tool Change X",
    description: "X location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "toolChange",
    order      : 30,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  toolChangeY: {
    title      : "Tool Change Y",
    description: "Y location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "toolChange",
    order      : 40,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  toolChangeZ: {
    title      : "Tool Change Z",
    description: "Z location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "toolChange",
    order      : 50,
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  toolChangeDisableZStepper: {
    title      : "Disable Z Stepper",
    description: "Disable Z stepper after reaching tool change location.",
    group      : "toolChange",
    order      : 60,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  toolChangeDoFirstChange: {
    title      : "Do First Change",
    description: "Do an initial tool change to load first tool.",
    group      : "toolChange",
    order      : 70,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  toolChangeProbeAfterChange: {
    title      : "Probe After Tool Change",
    description: "Probe Z at the current location after each tool change.",
    group      : "toolChange",
    order      : 80,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  includeStartFile: {
    title      : "Start GCode File",
    description: "Names a file in the NC output folder whose contents REPLACE the post's own header rather than adding to it. That includes the modal preamble -- G90, G21/G20, G94, G17 -- so your file must set whatever the job needs, or it inherits whatever mode the controller was left in. Leave empty (the default) for the built-in header. NAMING ANY FILE IN THIS GROUP makes Fusion ask \"This post processor might be unsafe...\" when you post; answer Yes, because answering No aborts the post.",
    group      : "include",
    order      : 10,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  includeStopFile: {
    title      : "Stop GCode File",
    description: "Names a file in the NC output folder whose contents REPLACE the post's own footer rather than adding to it -- the spindle stop or its prompt, the end park, the stepper release and the program end all go, so your file must do whatever the job needs. Leave empty (the default) for the built-in footer. See the note on Start GCode File about Fusion's \"might be unsafe\" prompt.",
    group      : "include",
    order      : 20,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  includeToolFile1: {
    title      : "Tool Change Start",
    description: "File of custom g-code inserted at the START of each tool change (in the NC output folder). Unlike the Start and Stop files above this one is ADDED to the tool-change sequence, not a replacement for it. Ignored unless group 7's Tool Changes are Included is on.",
    group      : "include",
    order      : 30,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  includeToolFile2: {
    title      : "Tool Change End",
    description: "File of custom g-code inserted at the END of each tool change (in the NC output folder), after the change and any re-probe. ADDED to the sequence, not a replacement for it. Ignored unless group 7's Tool Changes are Included is on.",
    group      : "include",
    order      : 40,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  // NOT IMPLEMENTED. Declared but never read -- nothing calls loadFile() with it, so a value entered
  // here is silently ignored. Kept because the feature is wanted; the title and tooltip say so.
  includeProbeFile: {
    title      : "Tool Change Probe",
    description: "NOT IMPLEMENTED YET. Reserved for a file of custom Gcode to run at the tool-change Z re-probe (in nc folder). Anything entered here is currently ignored -- no file is included and no warning is issued.",
    group      : "include",
    order      : 50,
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
  laserMarlinMode: {
    title      : "Laser: Marlin/Reprap Mode",
    description: "Marlin/Reprap mode of the laser/plasma cutter.",
    group      : "laser",
    order      : 40,
    type       : "enum",
    values: [
      { title: "Fan - M106 S{PWM}/M107", id: "106" },
      { title: "Spindle - M3 O{PWM}/M5", id: "3" },
      { title: "Pin - M42 P{pin} S{PWM}", id: "42" }
    ],
    value: "106",
    scope: "post"
  },
  laserMarlinPin: {
    title      : "Laser: Marlin M42 Pin",
    description: "Marlin custom pin number for the laser/plasma cutter.",
    group      : "laser",
    order      : 50,
    type       : "integer",
    value      : 4,
    scope      : "post"
  },
  laserGrblMode: {
    title      : "Laser: GRBL Mode",
    description: "GRBL mode of the laser/plasma cutter.",
    group      : "laser",
    order      : 60,
    type       : "enum",
    values: [
      { title: "M4 S{PWM}/M5 dynamic power", id: "4" },
      { title: "M3 S{PWM}/M5 static power", id: "3" }
    ],
    value      : "4",
    scope      : "post"
  },
  laserCoolant: {
    title      : "Laser: Coolant",
    description: "Force a coolant to be used with the laser.",
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
    description: "Enable channel A when tool is set this coolant.",
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
    description: "Enable channel B when tool is set this coolant.",
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
  coolantChannelAOn: {
    title      : "Turn Channel A On",
    description: "The g-code emitted to switch channel A on. MATCH IT TO YOUR CNC FIRMWARE -- the Grbl: options (M7 mist, M8 flood) and the Mrln: options (M42 pin writes) are not interchangeable, and the post emits whichever you pick verbatim without checking, so a Marlin code sent to GRBL is rejected mid-job. The default is the Grbl code, matching the default CNC Firmware. Use custom names a file of your own g-code instead, set further down this group.",
    group      : "coolant",
    order      : 30,
    type       : "enum",
    values: [
      { title: "Mrln: M42 P6 S255", id: "M42 P6 S255" },
      { title: "Mrln: M42 P11 S255", id: "M42 P11 S255" },
      { title: "Grbl: M7 (mist)", id: "M7" },
      { title: "Grbl: M8 (flood)", id: "M8" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M8",
    scope      : "post"
  },
  coolantChannelAOff: {
    title      : "Turn Channel A Off",
    description: "The g-code emitted to switch channel A off. Must be the same dialect as Turn Channel A On above -- see its note. On GRBL there is only one off code, M9, and it stops every coolant output at once. The default is the Grbl code, matching the default CNC Firmware.",
    group      : "coolant",
    order      : 40,
    type       : "enum",
    values: [
      { title: "Mrln: M42 P6 S0", id: "M42 P6 S0" },
      { title: "Mrln: M42 P11 S0", id: "M42 P11 S0" },
      { title: "Grbl: M9 (off)", id: "M9" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M9",
    scope      : "post"
  },
  coolantChannelBOn: {
    title      : "Turn Channel B On",
    description: "The g-code emitted to switch channel B on -- the second, independent coolant output. Must be the same dialect as your CNC Firmware; see Turn Channel A On above. The default is the Grbl code.",
    group      : "coolant",
    order      : 50,
    type       : "enum",
    values: [
      { title: "Mrln: M42 P11 S255", id: "M42 P11 S255" },
      { title: "Mrln: M42 P6 S255", id: "M42 P6 S255" },
      { title: "Grbl: M7 (mist)", id: "M7" },
      { title: "Grbl: M8 (flood)", id: "M8" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M7",
    scope      : "post"
  },
  coolantChannelBOff: {
    title      : "Turn Channel B Off",
    description: "The g-code emitted to switch channel B off. Must be the same dialect as Turn Channel B On above. On GRBL this is M9, the same single off code channel A uses. The default is the Grbl code.",
    group      : "coolant",
    order      : 60,
    type       : "enum",
    values: [
      { title: "Mrln: M42 P11 S0", id: "M42 P11 S0" },
      { title: "Mrln: M42 P6 S0", id: "M42 P6 S0" },
      { title: "Grbl: M9 (off)", id: "M9" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M9",
    scope      : "post"
  },
  coolantChannelAOnCustom: {
    title      : "Channel A On Custom",
    description: "File with custom GCode to turn ON coolant channel A (in nc folder).",
    group      : "coolant",
    order      : 70,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelAOffCustom: {
    title      : "Channel A Off Custom",
    description: "File with custom GCode to turn OFF coolant channel A (in nc folder).",
    group      : "coolant",
    order      : 80,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelBOnCustom: {
    title      : "Channel B On Custom",
    description: "File with custom GCode to turn ON coolant channel B (in nc folder).",
    group      : "coolant",
    order      : 90,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelBOffCustom: {
    title      : "Channel B Off Custom",
    description: "File with custom GCode to turn OFF coolant channel B (in nc folder).",
    group      : "coolant",
    order      : 100,
    type       : "string",
    value      : "",
    scope      : "post"
  },

  duetMillingMode: {
    title      : "Milling Mode",
    description: "GCode to set up Duet3d into milling mode.",
    group      : "duet",
    order      : 10,
    type       : "string",
    value      : "M453 P2 I0 R30000 F200",
    scope      : "post"
  },
  duetLaserMode: {
    title      : "Laser Mode",
    description: "GCode to set up Duet3d into laser mode.",
    group      : "duet",
    order      : 20,
    type       : "string",
    value      : "M452 P2 I0 R255 F200",
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
var tFormat = createFormat({ prefix: "T", decimals: 0 });

var taperFormat = createFormat({ decimals: 1, scale: DEG });
var secFormat = createFormat({ decimals: 3, forceDecimal: true }); // seconds - range 0.001-1000

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
var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({ onchange: function () { gMotionModal.reset(); } }, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21

function writeBlock() {
  if (getProperty(properties.jobSequenceNumbers)) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += getProperty(properties.jobSequenceNumberIncrement);
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
    0: {name: "Const", regex: /^\d+\.?\d*$/, numRegEx: /^(\d+\.?\d*)$/, value: 0},
    1: {name: "Feed", regex: /^Feed:/i, numRegEx: /:(\d+\.?\d*)$/, value: 1},
    2: {name: "Retract", regex: /^Retract:/i, numRegEx: /:(\d+\.?\d*)$/, value: 2},
    3: {name: "Clearance", regex: /^Clearance:/i, numRegEx: /:(\d+\.?\d*)$/, value: 3},
    4: {name: "Error", regex: /^$/, numRegEx: /^$/, value: 4}
  }
};

var safeZMode = eSafeZ.CONST;
// The literal fallback parsed out of the Safe-Z property, in MILLIMETRES -- every dialog dimension is
// mm. Convert with propertyMmToUnit() before comparing it against, or emitting it as, a coordinate.
var safeZHeightDefault = 15;
var safeZHeight;   // resolved height, in the OUTPUT unit

// Parse a Safe-Z expression -- a bare number, or Feed:/Retract:/Clearance:<fallback> -- into
// { mode, dflt }. Shared by mapRapidsSafeZ and probeSafeZ so both accept identical syntax. Pure.
function parseSafeZExpr(str) {
  var mode;
  var dflt = 15;

  // Look for either a number by itself or 'Feed:', 'Retract:' or 'Clearance:'
  for (mode = eSafeZ.CONST; mode < eSafeZ.ERROR; mode++) {
    if (str.search(eSafeZ.prop[mode].regex) == 0) {
      break;
    }
  }

  // If it was not an error then get the number
  if (mode != eSafeZ.ERROR) {
    var match = str.match(eSafeZ.prop[mode].numRegEx);

    if ((match == null) || (match.length != 2)) {
      mode = eSafeZ.ERROR;
      dflt = 15;
    }
    else {
      dflt = Number(match[1]);
    }
  }

  return {mode: mode, dflt: dflt};
}

function parseSafeZProperty() {
  var parsed = parseSafeZExpr(getProperty(properties.mapRapidsSafeZ));
  safeZMode = parsed.mode;
  safeZHeightDefault = parsed.dflt;

  writeComment(eComment.Debug, " parseSafeZProperty: safeZMode = '" + eSafeZ.prop[safeZMode].name + "'");
  writeComment(eComment.Debug, " parseSafeZProperty: safeZHeightDefault = " + safeZHeightDefault);
}

// One writer for both Safe-Z parse failures, so the two properties that document each other as "same
// syntax" cannot drift in wording, in punctuation, or in how they print the fallback. No brackets in
// the text: grbl 1.1 does not nest comments and ends one at the first ")" (grbl/gcode.c,
// gc_execute_line()), so an inner bracket closes the comment and the rest is parsed as g-code.
function writeSafeZFormatWarning(title, groupTitle, heightInUnit) {
  writeWarning("\"" + title + "\" in \"" + groupTitle + "\" -- format error, falling back to "
    + xyzFormat.format(heightInUnit));
}

function safeZforSection(_section)
{
  if (getProperty(properties.mapRapidsRestoreRapids)) {
    // The fallback is a dialog literal, so it is mm and converts; the F360 level values below are
    // already in the output unit. Every level test asks the PASSED section, not the global context.
    var dfltInUnit = propertyMmToUnit(safeZHeightDefault);
    switch (safeZMode) {
      case eSafeZ.CONST:
        safeZHeight = dfltInUnit;
        writeComment(eComment.Important, " SafeZ using const: " + safeZHeight);
        break;

      case eSafeZ.FEED:
        if (_section.hasParameter("operation:feedHeight_value") && _section.hasParameter("operation:feedHeight_absolute")) {
          let feed = _section.getParameter("operation:feedHeight_value");
          let abs = _section.getParameter("operation:feedHeight_absolute");

          if (abs == 1) {
            safeZHeight = feed;
            writeComment(eComment.Info, " SafeZ feed level: " + safeZHeight);
          }
          else {
            safeZHeight = dfltInUnit;
            writeComment(eComment.Important, " SafeZ feed level not abs: " + safeZHeight);
          }
        }
        else {
          safeZHeight = dfltInUnit;
          writeComment(eComment.Important, " SafeZ feed level not defined: " + safeZHeight);
        }
        break;

      case eSafeZ.RETRACT:
        if (_section.hasParameter("operation:retractHeight_value") && _section.hasParameter("operation:retractHeight_absolute")) {
          let retract = _section.getParameter("operation:retractHeight_value");
          let abs = _section.getParameter("operation:retractHeight_absolute");

          if (abs == 1) {
            safeZHeight = retract;
            writeComment(eComment.Info, " SafeZ retract level: " + safeZHeight);
          }
          else {
            safeZHeight = dfltInUnit;
            writeComment(eComment.Important, " SafeZ retract level not abs: " + safeZHeight);
          }
        }
        else {
          safeZHeight = dfltInUnit;
          writeComment(eComment.Important, " SafeZ: retract level not defined: " + safeZHeight);
        }
        break;

      case eSafeZ.CLEARANCE:
        if (_section.hasParameter("operation:clearanceHeight_value") && _section.hasParameter("operation:clearanceHeight_absolute")) {
          let clearance = _section.getParameter("operation:clearanceHeight_value");
          let abs = _section.getParameter("operation:clearanceHeight_absolute");

          if (abs == 1) {
            safeZHeight = clearance;
            writeComment(eComment.Info, " SafeZ clearance level: " + safeZHeight);
          }
          else {
            safeZHeight = dfltInUnit;
            writeComment(eComment.Important, " SafeZ clearance level not abs: " + safeZHeight);
          }
        }
        else {
          safeZHeight = dfltInUnit;
          writeComment(eComment.Important, " SafeZ clearance level not defined: " + safeZHeight);
        }
        break;
        
      case eSafeZ.ERROR:
        safeZHeight = dfltInUnit;
        writeSafeZFormatWarning(properties.mapRapidsSafeZ.title, groupDefinitions.mapRapids.title, safeZHeight);
        break;
    }
  }
}

// Resolve a parsed Safe-Z expression against one section's F360 levels, returning a height in the
// OUTPUT unit. Feed/Retract/Clearance pull the matching operation level when it is defined and
// absolute, otherwise the literal fallback. The two inputs arrive in different units and only one
// converts: an F360 level is already in the output unit, the dialog fallback is mm. Pure.
function resolveSafeZHeight(mode, dflt, _section) {
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
    default:  // CONST or ERROR -- use the literal fallback
      return fallback;
  }

  // Ask the PASSED section, not the global context: writeResolvedValues() resolves every section from
  // the header, where no section is current and the global form would report false throughout.
  if (_section.hasParameter(valueParam) && _section.hasParameter(absParam) && _section.getParameter(absParam) == 1) {
    return _section.getParameter(valueParam);   // already in the output unit
  }
  return fallback;
}

// Describe a parsed Safe-Z expression for the header block: its mode, its literal fallback, and what
// it actually RESOLVES to for this job's operations. `dflt` arrives in mm and is converted for
// display; resolveSafeZHeight() is handed the raw mm value and does its own conversion.
function describeSafeZ(mode, dflt) {
  var name = eSafeZ.prop[mode].name;
  var fallbackText = xyzFormat.format(propertyMmToUnit(dflt));
  if (mode == eSafeZ.CONST || mode == eSafeZ.ERROR) {
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

// ---- Probe Safe Z ----------------------------------------------------------
// Same expression syntax and F360-level resolution as the Map-G1s Safe Z, but a fully independent
// property so the two can be tuned separately.
var probeSafeZMode = eSafeZ.CONST;
var probeSafeZHeightDefault = 15;   // the parsed literal fallback, in MILLIMETRES (see safeZHeightDefault)

function parseProbeSafeZProperty() {
  var parsed = parseSafeZExpr(getProperty(properties.probeSafeZ));
  probeSafeZMode = parsed.mode;
  probeSafeZHeightDefault = parsed.dflt;

  // Same wording as the map side on purpose: the two document each other as "same syntax" and must
  // fail the same way. validateJob() carries the post-time half, for both.
  if (probeSafeZMode == eSafeZ.ERROR) {
    writeSafeZFormatWarning(properties.probeSafeZ.title, groupDefinitions.probe.title,
      propertyMmToUnit(probeSafeZHeightDefault));
  }

  writeComment(eComment.Debug, " parseProbeSafeZProperty: probeSafeZMode = '" + eSafeZ.prop[probeSafeZMode].name + "'");
  writeComment(eComment.Debug, " parseProbeSafeZProperty: probeSafeZHeightDefault = " + probeSafeZHeightDefault);
}

// Resolve probeSafeZ for the current operation. Returns a height in the output unit -- already
// unit-correct, so callers must NOT wrap it in propertyMmToUnit().
function probeSafeZ() {
  return resolveSafeZHeight(probeSafeZMode, probeSafeZHeightDefault, currentSection);
}


function roundTo(value, places) {
  // Plain arithmetic, not the string-exponent trick: JavaScript renders any magnitude below 1e-6
  // exponentially, so a Z of 1e-7 built "1e-7e+3" and the whole expression came back NaN.
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

//---------------- Coolant ----------------

// The four "... Custom" coolant properties name a FILE in the nc output folder, as their own tooltips
// say. Routed through loadFile() rather than written into the stream verbatim, so they inherit its
// missing-file error and its missing-trailing-newline repair.
function writeCustomCoolantFile(channel, on, file) {
  if (file == "") {
    writeWarning("coolant channel " + channel + " is set to \"Use custom\""
      + " but no custom file is named -- nothing emitted");
    return;
  }
  loadFile(file);
}

function CoolantA(on) {
  var coolantText = on ? getProperty(properties.coolantChannelAOn) : getProperty(properties.coolantChannelAOff);

  if (coolantText == "Use custom") {
    writeCustomCoolantFile("A", on, on ? getProperty(properties.coolantChannelAOnCustom)
                                       : getProperty(properties.coolantChannelAOffCustom));
    return;
  }

  writeBlock(coolantText);
}

function CoolantB(on) {
  var coolantText = on ? getProperty(properties.coolantChannelBOn) : getProperty(properties.coolantChannelBOff);

  if (coolantText == "Use custom") {
    writeCustomCoolantFile("B", on, on ? getProperty(properties.coolantChannelBOnCustom)
                                       : getProperty(properties.coolantChannelBOffCustom));
    return;
  }

  writeBlock(coolantText);
}

// Manage two channels of coolant by tracking which coolant is being using for
// a channel (Off = disabled). SetCoolant called with desired coolant to use or 0 to disable

var curCoolant = eCoolant.Off;        // The coolant requested by the tool
var coolantChannelA = eCoolant.Off;   // The coolant running in ChannelA
var coolantChannelB = eCoolant.Off;   // The coolant running in ChannelB

function setCoolant(coolant) {
  writeComment(eComment.Debug, " ---- Coolant: " + coolant  + " cur: " + curCoolant + " A: " + coolantChannelA + " B: " + coolantChannelB);

  // If the coolant for this tool is the same as the current coolant then there is nothing to do
  if (curCoolant == coolant) {
    return;
  }

  // We are changing coolant, so disable any active coolant channels
  // before we switch to the other coolant
  if (coolantChannelA != eCoolant.Off) {
    writeComment((coolant == eCoolant.Off) ? eComment.Important: eComment.Info, " >>> Coolant Channel A: " + eCoolant.Off);
    coolantChannelA = eCoolant.Off;
    CoolantA(false);
  }

  if (coolantChannelB != eCoolant.Off) {
    writeComment((coolant == eCoolant.Off) ? eComment.Important: eComment.Info, " >>> Coolant Channel B: " + eCoolant.Off);
    coolantChannelB = eCoolant.Off;
    CoolantB(false);
  }

  // At this point we know that all coolant is off so make that the current coolant
  curCoolant = eCoolant.Off;

  // As long as we are not disabling coolant (coolant = Off), then check if either coolant channel
  // matches the coolant requested. If neither do then issue an warning

  var warn = true;

  if (coolant != eCoolant.Off) {
    if (getProperty(properties.coolantChannelAMode) == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel A: " + coolant);
      coolantChannelA =  coolant;
      curCoolant = coolant;
      warn = false;
      CoolantA(true);
    }

    if (getProperty(properties.coolantChannelBMode) == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel B: " + coolant);
      coolantChannelB =  coolant;
      curCoolant = coolant;
      warn = false;
      CoolantB(true);
    }

    if (warn) {
      writeWarning("No matching Coolant channel : " + ((coolantLevels.indexOf(coolant) != -1 ) ? coolant : "unknown") + " requested");
    }
  }
}

//---------------- Cutters - Waterjet/Laser/Plasma ----------------

var cutterOnCurrentPower;

function laserOn(power) {
  // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    var laser_pwm = power * 10;

    // Number(), not the raw property: laserGrblMode stores its enum id as a STRING ("4" / "3"), and
    // every other mFormat.format() call in the file is handed a numeric literal.
    writeBlock(mFormat.format(Number(getProperty(properties.laserGrblMode))), sFormat.format(laser_pwm));
  }

  // Default firmware
  else {
    var laser_pwm = power / 100 * 255;

    switch (getProperty(properties.laserMarlinMode)) {
      case "106":
        writeBlock(mFormat.format(106), sFormat.format(laser_pwm));
        break;
      case "3":
        if (fw == eFirmware.REPRAP) {
          writeBlock(mFormat.format(3), sFormat.format(laser_pwm));
        } else {
          writeBlock(mFormat.format(3), oFormat.format(laser_pwm));
        }
        break;
      case "42":
        writeBlock(mFormat.format(42), pFormat.format(getProperty(properties.laserMarlinPin)), sFormat.format(laser_pwm));
        break;
    }
  }
}

function laserOff() {
  // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    writeBlock(mFormat.format(5));
  }

  // Default
  else {
    switch (getProperty(properties.laserMarlinMode)) {
      case "106":
        writeBlock(mFormat.format(107));
        break;
      case "3":
        writeBlock(mFormat.format(5));
        break;
      case "42":
        writeBlock(mFormat.format(42), pFormat.format(getProperty(properties.laserMarlinPin)), sFormat.format(0));
        break;
    }
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

// Guard A support: does any section (re)write an origin into WCS `base`? Returns the triggering
// feature's name, or null. Cutting *in* the base is fine; only a write is the error.
function baseOriginWriteReason(base) {
  var onStart = getProperty(properties.probeOnStart) != "Skip";
  var onChange = getProperty(properties.probeOnChange) != "Skip";
  var reprobe = getProperty(properties.toolChangeEnabled) && getProperty(properties.toolChangeProbeAfterChange);
  var doFirstChange = getProperty(properties.toolChangeDoFirstChange);
  var n = getNumberOfSections();
  var prevWo, prevTool;
  for (var i = 0; i < n; ++i) {
    var sec = getSection(i);
    var wo = sec.getWorkOffset();
    if (wo == 0) wo = 1;
    var toolNum = sec.getTool().number;
    if (i == 0) {
      // These strings are shown to the operator in Guard A's error so they can find the control
      // and change it -- they must stay identical to the properties' dialog titles.
      if (onStart && wo == base) return "First WCS / Part";
    } else {
      if (onChange && wo != prevWo && wo == base) return "Subsequent WCS / Part";
    }
    var toolChanged = (i == 0) ? doFirstChange : (toolNum != prevTool);
    if (reprobe && toolChanged && wo == base) return "Probe After Tool Change";
    prevWo = wo;
    prevTool = toolNum;
  }
  return null;
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

// Post-time validation guards. Runs once from onOpen(), before any output, so a misconfiguration
// fails fast.
function validateJob() {
  // --- Warnings ---------------------------------------------------------------------------------
  // Configurations that post a valid file which then does the wrong thing at the machine.

  // Homing MOVES the tool, and the "Set ... to Current Pos" modes record wherever it ends up. Homing
  // is step 2 of writeFirstSection() and the origin write step 6, so a pre-jog dies in between.
  var startMode = getProperty(properties.probeOnStart);
  var changeMode = getProperty(properties.probeOnChange);
  var homedXY = machineHomesXY();
  var homedZ = machineHomesZ();
  // "Subsequent WCS / Part" is consulted only on a genuine WCS change (writeWCS()'s isTraverse),
  // which a single-offset job never has -- so every warning about that control is gated on this.
  var multiWcs = collectDistinctOffsets().length > 1;

  // The likeliest group-4 mistake: the ACTION is set and the declaration above it never touched, so
  // writeMachineHoming() emits NO MOTION and the operator believes the job homed.
  if (homesAtJobStart() && !homedXY && !homedZ) {
    warning(localize("\"Home at Job Start\" asks this job to home, but \"Axes Homed and Trusted\" is "
      + "None, so no axis is declared homeable and the post emits no homing motion at all -- the job "
      + "starts from wherever the machine already sits. Declare which axes this machine homes to "
      + "endstops, or set \"Home at Job Start\" to Off."));
  }

  // The action alone is not the trigger: with the declaration None nothing moves. Either axis group
  // qualifies -- X/Y homing destroys the pre-jogged XY, Z homing the height recorded as Z0.
  if (homesAtJobStart() && (homedXY || homedZ) &&
      (startMode == "Current XY & Probe Z" || startMode == "Current XYZ")) {
    // Advice rather than prohibition: with X/Y declared homed, a stored fixture offset in the active
    // WCS is repeatable across power cycles, so it is a better answer than the destroyed pre-jog.
    warning(localize("\"Home at Job Start\" moves the tool onto the endstops of whichever axes "
      + "\"Axes Homed and Trusted\" declares, and it runs before "
      + "\"First WCS / Part\" records the current position as the part origin, so positioning the "
      + "tool before starting the job has no effect on those axes. On a homed machine the stored "
      + "offset in the active WCS is repeatable, so \"Use Active WCS X0 Y0, Probe Z0\" is the "
      + "natural first-part mode here; a \"Jog to ...\" mode also works. Otherwise set \"Home at "
      + "Job Start\" to Off."));
  }

  // A G54-G59 register holds an offset from MACHINE zero, and unhomed that zero moves at every reset.
  // Only trusting a STORED offset breaks, hence the mode split and the exclusion of the "Jog" modes.
  if (!homedXY) {
    var storedOffsetControls = [];
    if (startMode == "Probe Z" || startMode == "Skip") {
      storedOffsetControls.push("\"First WCS / Part\"");
    }
    if ((changeMode == "Probe Z" || changeMode == "Skip") && multiWcs) {
      storedOffsetControls.push("\"Subsequent WCS / Part\"");
    }
    if (storedOffsetControls.length > 0) {
      warning(localize(storedOffsetControls.join(" and ") + " trust the origin already stored in a "
        + "work offset register, but \"Axes Homed and Trusted\" does not include X/Y. A stored offset is measured from "
        + "machine zero, which moves at every controller reset or power cycle when nothing homes -- "
        + "so an offset written by an earlier job now points somewhere else, and the post cannot "
        + "read the register back to check. Declare X/Y homed on a machine with X/Y endstops, or "
        + "choose a mode that establishes the origin during this run."));
    }
  }

  // The post-time half of warnJogAtPauseOnGrbl(); see that function for the source read. Only the
  // subsequent-part half carries multiWcs, that control being unread on a single-offset job.
  if (fw == eFirmware.GRBL &&
      (startMode == "Jog XY & Probe Z" || startMode == "Jog XYZ" ||
       (multiWcs && (changeMode == "Jog XY & Probe Z" || changeMode == "Jog XYZ")))) {
    warning(localize("A \"Jog to ...\" origin mode is selected, but GRBL cannot jog at the pause "
      + "it produces: the post emits M0, and GRBL 1.1 accepts a jog command only in its Idle or Jog "
      + "states. The job will stop and wait, and the operator will be unable to move the machine "
      + "without resetting the program. These modes are supported on RepRap. On GRBL, position the "
      + "tool before starting and use a \"Set ... to Current Pos\" or \"Use Active WCS ...\" mode."));
  }

  // Establishing the fixed Z reference MOVES THE TOOL, before the first part's origin is recorded, so
  // "current position" is bed clearance. The "Jog" modes are excluded -- they position after it.
  if (fixedZEstablishedInFile() &&
      (startMode == "Current XY & Probe Z" || startMode == "Current XYZ")) {
    warning(localize("\"Fixed Z Reference\" is established at job start by moving the tool to "
      + "\"Inter Part Travel Z\", and that runs before \"First WCS / Part\" records the current "
      + "position -- so the origin is recorded at bed clearance rather than at the part, and the "
      + "probe target measured from it will not reach the stock. Use \"Use Active WCS X0 Y0, Probe "
      + "Z0\" or a \"Jog to ...\" mode, or set \"Fixed Z Reference\" to None."));
  }

  // The same boundary from the other side: this fires when no fixed Z reference is established and the
  // mode cannot lift. warning(), not error() -- the start height is a promise only the operator can make.
  if (startMode == "Probe Z" && !fixedZEstablishedInFile()) {
    warning(localize("\"First WCS / Part\" = \"Use Active WCS X0 Y0, Probe Z0\" rapids to the stored "
      + "X0 Y0 before this job has established any Z the post can move in, so that traverse happens "
      + "at whatever height the tool is left at -- position it clear of the stock, clamps and "
      + "fixtures before starting the program. The probe that follows measures \"G38 Target\" from the "
      + "Z0 already stored in the active WCS, which this mode re-probes precisely because it is not "
      + "trusted, so set the target deep enough to reach the stock from that start height."
      // The closing recommendation is actionable only where the operator can make
      // fixedZEstablishedInFile() true, and on Marlin they cannot.
      + (fw == eFirmware.MARLIN
        ? " Marlin has no fixed Z reference this post can establish, so that start height is yours to set."
        : " \"Fixed Z Reference\" removes both, by establishing a Z the post can move in itself.")));
  }

  // The machine park crosses the bed, and writeMachineParkXY() can retract first only in a frame THIS
  // JOB ESTABLISHED. A warning, not a guard: Fusion's own retract covers an ordinary milling job.
  if (getProperty(properties.machineParkAtEnd) == "Machine" && !parkCanRetract()) {
    warning(localize("\"At End Park At\" = machine X0 Y0 crosses the bed to the homing corner, but "
      + "this job establishes no fixed Z reference to retract in, so the tool makes that crossing "
      + "at whatever Z the last operation left it at. Set \"Fixed Z Reference\", or park at work "
      + "X0 Y0."));
  }

  // Post-time half of toolChange()'s suppression warning, so it reaches Fusion's dialog and not
  // only the posted file.
  if (!getProperty(properties.toolChangeEnabled) && countDistinctTools() > 1) {
    warning(localize("This job uses more than one tool, but \"Tool Changes are Included\" is off: "
      + "no tool-change code is emitted and every operation runs with the tool already in the "
      + "spindle, at the other tools' feeds and speeds. Enable the \"7 - Tool Changes\" group, or "
      + "post one tool per file."));
  }

  // Anything parseSafeZExpr() cannot read resolves to a fixed 15 mm on every section, a plausible
  // retract height that looked like the setting working. Both, since they share a documented syntax.
  var safeZProps = [properties.mapRapidsSafeZ, properties.probeSafeZ];
  for (var s = 0; s < safeZProps.length; ++s) {
    if (parseSafeZExpr(getProperty(safeZProps[s])).mode == eSafeZ.ERROR) {
      warning(localize("\"" + safeZProps[s].title + "\" is set to \"" + getProperty(safeZProps[s])
        + "\", which is not a Safe Z expression the post can read, so it falls back to a fixed 15 mm "
        + "on every operation. Give a plain number of millimetres, or Feed:, Retract: or Clearance: "
        + "followed by one -- no sign, no unit suffix."));
    }
  }

  // --- Guards -----------------------------------------------------------------------------------
  // Order is load-bearing: Guard C's Marlin branch returns, so anything below it is unreachable on
  // exactly the firmware it excludes.

  // A named include file that does not exist only reaches error() inside loadFile(), by which point
  // the header and preamble are in the stream. The tool-change files are checked only with group 7 on.
  var includeFileProps = [properties.includeStartFile, properties.includeStopFile];
  if (getProperty(properties.toolChangeEnabled)) {
    includeFileProps.push(properties.includeToolFile1);
    includeFileProps.push(properties.includeToolFile2);
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

  var fixedZ = getFixedZReference();
  var reservedRaw = getProperty(properties.spoilboardBaseReserve);

  // The two answers must agree: "Reserved WCS" is a sub-question of the spoilboard answer, and
  // guessing fails silently in both directions -- a base never probed, or nothing established.
  if (fixedZ == "Spoilboard" && reservedRaw == "None") {
    error("\"Fixed Z Reference\" is the spoilboard answer but no \"Reserved WCS\" is chosen -- pick the WCS to reserve as the base, or set \"Fixed Z Reference\" to None.");
    return;
  }
  if (fixedZ != "Spoilboard" && reservedRaw != "None") {
    error("\"Reserved WCS\" names " + wcsName(parseInt(reservedRaw, 10)) + " but \"Fixed Z Reference\" is not the spoilboard answer, so the base would never be probed -- set \"Fixed Z Reference\" to the spoilboard answer, or set \"Reserved WCS\" to None.");
    return;
  }

  // One field read in whichever frame the enum names, so a FLIP is the hazard -- and only detectable
  // one way: a spoilboard clearance is measured up from the surface, a stock GRBL machine Z is negative.
  if (fixedZ == "Spoilboard") {
    var travelZ = parseInterPartTravelZ();
    if (travelZ == undefined) {
      error("\"Fixed Z Reference\" = the spoilboard answer requires \"Inter Part Travel Z\" as a height ABOVE the probed spoilboard -- enter the clearance that passes over the tallest fixture, clamp and part in the job, in mm.");
      return;
    }
    if (travelZ <= 0) {
      error("\"Inter Part Travel Z\" is " + travelZ + " mm, but under the spoilboard answer it is measured UP from the probed spoilboard surface, so it must be positive. A value at or below zero is usually an absolute machine Z left behind when \"Fixed Z Reference\" changed -- re-read the height above the spoilboard.");
      return;
    }
  }

  if (fixedZ == "Machine Z") {
    // Guard C EXTENDED, not inherited: Marlin/src/gcode/gcode.cpp (2.1.x) gates "case 53: G53();"
    // inside CNC_COORDINATE_SYSTEMS, so a single-WCS Marlin job passes Guard C and still cannot move.
    if (fw == eFirmware.MARLIN) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires G53, which is a build option on Marlin (CNC_COORDINATE_SYSTEMS) and off by default -- use the spoilboard answer, or None.");
      return;
    }
    if (!machineHomesZ()) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Axes Homed and Trusted\" to include Z -- declare that this machine homes Z, or choose another fixed Z reference.");
      return;
    }
    // The declaration alone is not enough HERE: a stale machine frame drives an absolute RAPID, and
    // only GRBL stops it. So when this is the datum, the job homes the frame it trusts.
    if (!homesAtJobStart()) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Home at Job Start\" to be Home or Pause, then Home -- an absolute machine-frame move must be measured against a frame this job established, not one a previous power cycle left behind.");
      return;
    }
    if (parseInterPartTravelZ() == undefined) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Inter Part Travel Z\" as an ABSOLUTE machine coordinate -- home the machine, jog to a height that clears every fixture and part, and enter the Z the sender's DRO reports, in mm. It is empty whenever this answer has just changed, because a height measured above the spoilboard is not a machine Z.");
      return;
    }
    // Requires declared homed XY -- not for the Z-only move, but because the multi-part workflow it
    // serves moves between stored work offsets. Stated once here; usesMachineZDatum() has no trace.
    if (!homedXY) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Axes Homed and Trusted\" to include X/Y -- the multi-part traverses it serves move between stored work offsets, which are repeatable only on a machine with a homed X/Y zero.");
      return;
    }
  }

  // Above Guard C's Marlin branch, and here that matters more because this guard APPLIES on Marlin --
  // whose route (G28 X Y) re-establishes the frame, which is why the homing half is GRBL/RepRap-only.
  if (getProperty(properties.machineParkAtEnd) == "Machine") {
    if (!machineHomesXY()) {
      error("\"At End Park At\" = machine X0 Y0 requires \"Axes Homed and Trusted\" to include X/Y -- a machine's X0 Y0 is its homing corner, which means nothing on a machine that does not home.");
      return;
    }
    if (fw != eFirmware.MARLIN && !homesAtJobStart()) {
      error("\"At End Park At\" = machine X0 Y0 emits G53 on " + fw + ", which measures against a machine frame this job must have established, not one a previous power cycle left behind -- set \"Home at Job Start\" to Home, or park at work X0 Y0.");
      return;
    }
  }

  // Guard C -- Marlin is single-frame: a job using more than one distinct work offset is silently
  // wrong on it. The reserved base is a per-WCS-register concept, so its guards are skipped here.
  if (fw == eFirmware.MARLIN) {
    if (collectDistinctOffsets().length > 1) {
      error("Marlin has a single coordinate frame -- this multi-WCS job cannot be posted; use one work offset.");
    }
    return;
  }

  var base = getReservedBaseWcs();
  if (base == 0) {
    // Guard B -- safe-Z across WCS needs A FIXED Z REFERENCE of either kind: across offsets only
    // established by probing at runtime, no single clearance height is meaningful. Single-WCS is exempt.
    // UNCONDITIONAL since CR-13: it was gated on "Retract Across Parts", so turning that off was the one
    // way to post the job this refuses -- and what it then posted was a traverse in the wrong frame.
    if (!usesMachineZDatum() && collectDistinctOffsets().length > 1) {
      error("A multi-WCS job requires a fixed Z reference: the tool must clear the fixtures on its way between parts, and no single clearance height is meaningful across WCS whose offsets are only known after probing at runtime. Set \"Fixed Z Reference\" to the spoilboard answer (and reserve a WCS) or to the machine-Z answer -- or post one job per part.");
    }
    return; // no base reserved -> Guard A and the slot check are moot
  }

  // RepRap-only slots: G59.1-G59.3 (7-9) don't exist on GRBL.
  if (base > 6 && fw != eFirmware.REPRAP) {
    error("Reserved base " + wcsName(base) + " requires RepRap (GRBL supports G54-G59 only).");
    return;
  }

  // Guard A -- no redefine of the base.
  var reason = baseOriginWriteReason(base);
  if (reason) {
    error(wcsName(base) + " is reserved as the spoilboard base -- assign this operation to another WCS (would be re-established by: " + reason + ").");
    return;
  }
}

// Return every mutable module global to its declared initial value. onOpen() already did this for
// currentWorkOffset and sequenceNumber, which is the tell that this post does not rely on getting a
// fresh JavaScript context per output file. fOutput and gMotionModal are deliberately absent: both
// are rebuilt from properties in onOpen() on every branch, so that assignment IS their reset.
function resetPostState() {
  currentWorkOffset = undefined;          // no work offset emitted yet
  sequenceNumber = getProperty(properties.jobSequenceNumberStart);
  forceSectionToStartWithRapid = false;
  sectionComment = undefined;
  machineMode = undefined;
  safeZHeight = undefined;
  curCoolant = eCoolant.Off;
  coolantChannelA = eCoolant.Off;
  coolantChannelB = eCoolant.Off;
  cutterOnCurrentPower = undefined;
  powerState = false;
  spindleEnabled = false;
  currentSpindleSpeed = 0;
  currentSpindleClockwise = true;
  lastPromptedSpeed = "";
  lastPromptedClockwise = true;
  probePauseBefore = true;
  probePauseAfter = true;
  pendingRadiusCompensation = RADIUS_COMPENSATION_OFF;

  // Not a value, but the same leak: nothing rebuilds gPlaneModal, so a second file sharing one context
  // would believe its last plane still in force and suppress Start()'s G17.
  gPlaneModal.reset();
}

function onOpen() {
  fw = getProperty(properties.jobSelectedFirmware);

  resetPostState();

  // Validate the job configuration before emitting anything (may error() out).
  validateJob();

  // NO "%" wrapper, on any firmware. Stock Grbl 1.1 has no "%" feature -- the branch in
  // grbl/protocol.c's line reader is commented out -- so it reaches the parser and answers error:1.

  // Configure the GCode G commands
  if (fw == eFirmware.GRBL) {
    gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
  }
  else {
    gMotionModal = createModal({ force: true }, gFormat); // modal group 1 // G0-G3, ...
  }

  // Assigned on BOTH answers, like gMotionModal above: onOpen() may run again in the same JavaScript
  // context, and a one-way assignment leaks a forced F into the next file.
  fOutput = createVariable({ force: getProperty(properties.feedsEnforceFeedrate) }, fFormat);

  // Set the separator used between words -- set on both answers, the same leak as fOutput above.
  setWordSeparator(getProperty(properties.jobSeparateWordsWithSpace) ? " " : "");

  // Determine the safeZHeight to do rapids
  parseSafeZProperty();

  // Determine the probe retract Safe Z (independent property, same syntax)
  parseProbeSafeZProperty();
}

function onClose() {
  writeComment(eComment.Important, " *** STOP begin ***");

  flushMotions();

  if (getProperty(properties.includeStopFile) == "") {
    onCommand(COMMAND_COOLANT_OFF);

    // Before the return traverse: under Manual Spindle On/Off this is an M0 prompt, not an M5, so
    // emitted after the move it crossed the part at travel speed with the router still turning.
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

    // Is Grbl?
    if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(30));
    }
  
    // Default
    else {
      display_text("Job end");

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

// Emit the work coordinate system (WCS) for a section. GRBL and RepRap/Duet support G54-G59 (RepRap
// also G59.1-G59.3), so the offset assigned in Fusion is honored. Stock Marlin has none -- the post
// sets the origin with G92 there and only warns when a non-default WCS was selected.
function writeWCS(section) {
  var workOffset = section.getWorkOffset();
  writeComment(eComment.Debug, " writeWCS: entry workOffset: " + workOffset + " currentWorkOffset: " + (currentWorkOffset == undefined ? "none" : currentWorkOffset));

  // Fusion reports workOffset 0 both when the Setup's Work Offset field was left at its default and
  // when the default was chosen explicitly, so 0 always means "use WCS 1".
  if (workOffset == 0) {
    workOffset = 1; // default to the first WCS (G54)
    writeComment(eComment.Info, " writeWCS: workOffset defaulted to: " + workOffset);
  }

  if (fw == eFirmware.MARLIN) {
    if (workOffset > 1 && workOffset != currentWorkOffset) {
      writeWarning("Marlin uses a G92 origin; work offset " + workOffset + "/G" + (53 + workOffset) + " is not supported and is ignored");
    }
    currentWorkOffset = workOffset;
    return;
  }

  // GRBL / RepRap: select the work coordinate system (only when it changes).
  if (workOffset == currentWorkOffset) {
    writeComment(eComment.Info, " WCS unchanged: " + workOffset + ", not re-selecting");
    return;
  }
  var previousWorkOffset = currentWorkOffset;
  var offsetCode = wcsGcode(workOffset);
  if (offsetCode == undefined) {
    error("Work offset " + workOffset + " is out of range for " + fw + " (GRBL supports G54-G59, RepRap G54-G59.3).");
    return;
  }
  // How to establish this added part's origin/Z (probeOnChange). The first part's is set by
  // probeOnStart in writeFirstSection(), so this covers the added parts only.
  var onChangeMode = getProperty(properties.probeOnChange);
  var canProbe = (tool.number != 0 && !tool.isJetTool());
  writeComment(eComment.Debug, " writeWCS: probeOnChange: " + onChangeMode
    + " previousWorkOffset: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset)
    + " canProbe: " + canProbe);

  // Retract Z FIRST, before selecting the new WCS -- its Z origin may be unknown, so an absolute Z
  // move there would be unsafe. Every traverse takes one of the two fixed-reference routes: Guard B has
  // already refused any multi-WCS job that has neither, so there is no third route to fall into.
  var base = getReservedBaseWcs();
  var isTraverse = (previousWorkOffset != undefined);   // a genuine inter-part WCS change
  var machineFrame = isTraverse && usesMachineZDatum();
  // Includes the case where the part being ENTERED is the base: the base frame IS the fixed reference,
  // so its clearance is the right height there too, and retractThroughBaseClearance() already suppresses
  // the redundant select. The "base != workOffset" this replaced sent that job into the arm below. CR-13.
  var baseRelative = isTraverse && base != 0;
  writeComment(eComment.Debug, " writeWCS: retract decision -- fixedZRef: " + getFixedZReference()
    + " machineFrame: " + machineFrame + " baseRelative: " + baseRelative
    + " base: " + base + " isTraverse: " + isTraverse + " workOffset: " + workOffset);
  if (machineFrame) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before traverse");
  } else if (baseRelative) {
    retractThroughBaseClearance();
  } else if (isTraverse) {
    // Unreachable behind Guard B, and an error rather than a move because there is nothing safe to emit:
    // with no fixed reference, no height means the same thing on both sides of the traverse. What used to
    // stand here was probeSafeZ() -- the retract level of the section being ENTERED, written BEFORE the
    // WCS select and so read in the PREVIOUS part's frame, a height belonging to neither part. CR-13.
    error("Internal: a WCS traverse reached output with no fixed Z reference -- Guard B should have refused this job.");
    return;
  }

  writeComment(eComment.Info, " WCS changed: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset) + " -> " + workOffset);
  writeBlock(gFormat.format(offsetCode));
  currentWorkOffset = workOffset;

  // The added-part origin/probe action applies only to a genuine WCS change (added parts). The
  // first section's origin is handled separately by writeWcsOnStart() (probeOnStart).
  if (!isTraverse) {
    return;
  }

  // Z is at the safe height from the retract above. The Replicate moves below emit X/Y only, so
  // that height is preserved; the manual modes hand control to the operator (who jogs).
  if (onChangeMode == "Skip") {
    // Replicate, do nothing to the origin -- but still reach this part's stored X0 Y0 safely.
    writeComment(eComment.Info, "   Move to this part's stored origin X0 Y0");
    resetAll();
    rapidMovementsXY(0, 0);
    flushMotions();
  } else if (onChangeMode == "Probe Z") {
    // Replicate: auto-position to the stored X0 Y0 (plus probe XY offset) and probe Z. The tool is
    // still over the PREVIOUS part, so partProbe() travels there first -- X/Y only, Z stays safe.
    if (canProbe) {
      partProbe(false);
    } else {
      writeComment(eComment.Debug, " writeWCS: probe skipped (tool 0 or jet tool) -- moving to stored X0 Y0");
      resetAll();
      rapidMovementsXY(0, 0);
      flushMotions();
    }
  } else if (onChangeMode == "Jog XYZ") {
    // Jog: the operator jogs to this part's origin; record that position as X0 Y0 Z0, no probe.
    warnJogAtPauseOnGrbl();
    askUser("Jog to X0 Y0 Z0, then continue", "Set origin", true);
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
  } else if (onChangeMode == "Jog XY & Probe Z") {
    // Jog: the operator jogs to this part's X0 Y0 (staying clear in Z); record X0 Y0 here,
    // then probe Z. partProbe(true) -- the tool is at the origin after the jog.
    warnJogAtPauseOnGrbl();
    askUser("Jog to X0 Y0 above Z0, probe", "Set origin", true);
    writeComment(eComment.Info, "   Set current X,Y position to 0,0");
    writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
    if (canProbe) {
      partProbe(true);
    } else {
      writeComment(eComment.Debug, " writeWCS: probe skipped (tool 0 or jet tool)");
    }
  }
}

// Persists the current position as WCS wcsNumber's own origin; any of x/y/z may be undefined to leave
// that axis alone. GRBL/RepRap write into that WCS's own offset register (G10 L20 P<n>), so it cannot
// leak into another. Marlin has no addressable per-WCS register, so it falls back to G92.
function writeWcsOrigin(wcsNumber, x, y, z) {
  writeComment(eComment.Debug, " writeWcsOrigin: wcs: " + wcsNumber
    + " x: " + (x == undefined ? "-" : x) + " y: " + (y == undefined ? "-" : y) + " z: " + (z == undefined ? "-" : z)
    + " method: " + (fw == eFirmware.MARLIN ? "G92 (global -- Marlin has no per-WCS register)" : ("G10 L20 (scoped to WCS " + wcsNumber + ")")));

  var xWord = x == undefined ? undefined : xFormat.format(x);
  var yWord = y == undefined ? undefined : yFormat.format(y);
  var zWord = z == undefined ? undefined : zFormat.format(z);

  if (fw == eFirmware.MARLIN) {
    writeBlock(gFormat.format(92), xWord, yWord, zWord);
  } else {
    writeBlock(gFormat.format(10), "L20", "P" + wcsNumber, xWord, yWord, zWord);
  }
}

// The job's FIXED Z REFERENCE -- "None" | "Spoilboard" | "Machine Z". A frame whose Z0 does not move
// with stock thickness; the two non-None answers are two implementations of that one frame, not two
// features. Every consumer asks this rather than asking whether a base is reserved.
function getFixedZReference() {
  return getProperty(properties.spoilboardFixedZRef);
}

// True when the fixed Z reference is the machine's own homed Z frame, addressed with G53. Deliberately
// does NOT test the X/Y declaration: a Z-only G53 move needs machine Z trustworthy and nothing else,
// and the homed-XY requirement sits on the workflow, enforced once in validateJob().
function usesMachineZDatum() {
  return getFixedZReference() == "Machine Z";
}

// The group-4 declaration, split back into the two axis questions every consumer actually asks: the
// machine-Z datum needs Z and the stored-offset guard needs X/Y, and neither implies the other.
// Nothing else may read the property directly -- an "== XYZ" test would exclude the single-axis answers.
function machineHomesXY() {
  var declared = getProperty(properties.machineHomedAxes);
  return declared == "XY" || declared == "XYZ";
}
function machineHomesZ() {
  var declared = getProperty(properties.machineHomedAxes);
  return declared == "Z" || declared == "XYZ";
}

// The group-4 ACTION, split into the two questions its consumers ask. Unlike the axis declaration
// above, this enum is NOT information-identical to the two booleans it replaced: "Prompt Before Home"
// was inert whenever homing was off, so collapsing them deleted a state rather than renaming it.
function homesAtJobStart() {
  return getProperty(properties.machineHomeAtStart) != "Off";
}
function promptsBeforeHome() {
  return getProperty(properties.machineHomeAtStart) == "Pause & Home";
}

// The reserved spoilboard base as a workOffset number (1-6 = G54-G59, 7-9 = G59.1-G59.3), or 0 when
// the spoilboard is not the job's fixed Z reference. The enum ids are the numbers directly, so this
// validates the raw value too. Gated on the Fixed Z Reference answer, which is what makes "Reserved
// WCS" a sub-question rather than a second, independent switch.
function getReservedBaseWcs() {
  if (getFixedZReference() != "Spoilboard") return 0;
  var v = getProperty(properties.spoilboardBaseReserve);
  if (v == "None") return 0;
  return parseInt(v, 10);
}

// "Inter Part Travel Z" as a Number in MILLIMETRES, or undefined when the field is empty or does not
// parse as a signed decimal. FRAME-FREE: this parses the number and "Fixed Z Reference" decides what
// it means, so the sign test belongs in validateJob() rather than here. It is a STRING property
// because Fusion's schema gives a numeric field no way to be unset, and every sentinel would be a
// real height in a signed machine frame -- 0 very much included.
function parseInterPartTravelZ() {
  var raw = getProperty(properties.spoilboardTravelZ);
  if (typeof raw != "string") return undefined;
  var s = raw.replace(/^\s+|\s+$/g, "");
  if (!(/^[-+]?\d+(\.\d+)?$/.test(s))) return undefined;   // also rejects "" -- unset
  return Number(s);
}

// The same height in OUTPUT units, ready to emit. Callers must not wrap it again. Only reached
// under a non-None "Fixed Z Reference", and validateJob() refuses either answer unless it parses.
function interPartTravelZ() {
  return propertyMmToUnit(parseInterPartTravelZ());
}

// True when the DIALOG names a fixed Z reference, and nothing more: it does not test the firmware, so
// it reads true on Marlin where neither implementation runs. A caller reasoning about WHERE THE TOOL
// IS must ask the predicate below instead.
function fixedZEstablishedAtStart() {
  return usesMachineZDatum() || getReservedBaseWcs() != 0;
}

// True when the job also EMITS the establish, so the tool holds a height this file put it at. The gap
// between the two is Marlin: the machine-Z answer is refused there outright, and a reserved base
// passes every guard only for writeBaseEstablish() to warn and return for want of per-WCS registers.
// Every consumer that reasons about the height the tool holds asks THIS one.
function fixedZEstablishedInFile() {
  return fw != eFirmware.MARLIN && fixedZEstablishedAtStart();
}

// Can the end-of-job machine park retract before it crosses the bed? Only into a frame this job
// established, which is the fixed Z reference and nothing else -- so on Marlin the answer is always no
// however the dialog is set. Read by validateJob()'s warning and by writeMachineParkXY(), so the two
// cannot drift apart. Its own name because the park's callers ask about the park.
function parkCanRetract() {
  return fixedZEstablishedInFile();
}

// Human-readable G-code name for a workOffset number, for comments/errors.
function wcsName(n) {
  return n <= 6 ? ("G" + (53 + n)) : ("G59." + (n - 6));
}

// Numeric G-code for a work offset: 1-6 -> 54-59, 7-9 -> 59.1-59.3. Returns undefined if out of range
// for the firmware (the G59.x slots are RepRap-only); callers report the error.
function wcsGcode(workOffset) {
  if (workOffset <= 6) return 53 + workOffset;
  if (fw == eFirmware.REPRAP && workOffset <= 9) return 59 + (workOffset - 6) / 10;
  return undefined;
}

// The ONE machine-frame move this post emits: a rapid to the declared "Inter Part Travel Z", addressed
// absolutely with G53. Two conditions come from G53's own definition: it "is not modal and must be
// programmed on each line", so nothing may be appended to this block and a future X/Y park must be a
// SECOND block rather than a three-axis diagonal; and "it is an error if G53 is used without G0 or G1
// being active", so the G0 goes through gFormat and NOT gMotionModal, which would suppress the word
// exactly when G0 is already active. The resets bracket it because a machine-frame move invalidates
// the tracked work-frame coordinates and motion mode.
function writeMachineTravelZ(reason) {
  var z = interPartTravelZ();
  writeComment(eComment.Info, "   " + reason + " -- machine Z " + xyzFormat.format(z));
  resetAll();
  writeBlock(gFormat.format(53), gFormat.format(0), zFormat.format(z),
    fFormat.format(propertyMmToUnit(getProperty(properties.feedsTravelSpeedZ))));
  resetAll();
  gMotionModal.reset();
  flushMotions();
}

// Park at the machine's own X0 Y0 -- the homing corner -- as the last motion of the job. Two firmware
// routes, and not the same KIND of operation, which is why this feature's guard is firmware-dependent
// where the machine-Z datum's is a flat exclusion. GRBL/RepRap emit "G53 G0 X0 Y0", an absolute rapid
// ADDRESSING a frame the job must already have established, X/Y only. Marlin emits "G28 X / G28 Y",
// which RE-ESTABLISHES the frame instead -- self-establishing, but a homing cycle rather than a rapid.
// Arithmetic is not a third route: the G92 work frame differs from the machine frame by an offset the
// post never knew and cannot read back.
function writeMachineParkXY() {
  // Retract before crossing the bed -- potentially a full diagonal. Only a job that ESTABLISHED a
  // fixed Z reference can retract at all, which is what parkCanRetract() answers.
  if (!parkCanRetract()) {
    writeWarning("no retract before parking at machine X0 Y0 --"
      + (fw == eFirmware.MARLIN && getReservedBaseWcs() != 0
          ? " the reserved spoilboard base was not established on Marlin, so there is no frame to"
            + " retract in;"
          : " this job establishes no fixed Z reference;")
      + " the tool crosses the bed at whatever Z the last operation left it at");
  } else if (usesMachineZDatum()) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before parking");
  } else {
    // Never leave the base active. retractThroughBaseClearance() leaves it selected for a caller about
    // to choose a destination WCS; this caller has none, so it restores the operating WCS itself.
    var operating = currentWorkOffset;
    retractThroughBaseClearance();
    if (operating != undefined && currentWorkOffset != operating) {
      writeBlock(gFormat.format(wcsGcode(operating)));
      currentWorkOffset = operating;
    }
  }

  if (fw == eFirmware.MARLIN) {
    writeComment(eComment.Info, "   Park at machine X0 Y0 -- re-homing X/Y; G53 is a Marlin build option");
    writeBlock(gFormat.format(28), "X");
    writeBlock(gFormat.format(28), "Y");
    return;
  }

  writeComment(eComment.Info, "   Park at machine X0 Y0");
  resetAll();
  // The F word is not optional even on a G0: where the modal feedrate is honoured for G0, an F-less
  // rapid crosses the bed at the last CUT's feed. resetAll() just cleared it, hence fFormat.
  writeBlock(gFormat.format(53), gFormat.format(0), xFormat.format(0), yFormat.format(0),
    fFormat.format(propertyMmToUnit(getProperty(properties.feedsTravelSpeedXY))));
  resetAll();
  gMotionModal.reset();
}

// Retract to a height above the reserved spoilboard base by transiting THROUGH the base WCS, whose Z
// was established at job start -- the one frame where an absolute safe height is meaningful across
// parts of differing thickness. Selects the base with a plain frame switch, NOT writeWCS(), so it
// triggers no probeOnChange re-probe and writes no origin, and LEAVES it active for the caller to
// replace. Caller guarantees a base is reserved.
function retractThroughBaseClearance() {
  var base = getReservedBaseWcs();
  writeComment(eComment.Info, "   Retract to spoilboard-base clearance " + wcsName(base) + " before traverse");
  // Select the base only if it isn't already active (it can be, when the previous section
  // cut on the base) -- re-selecting the active WCS would be a redundant line.
  if (currentWorkOffset != base) {
    writeBlock(gFormat.format(wcsGcode(base)));   // transit-select the base frame (no re-probe)
    currentWorkOffset = base;
  }
  resetAll();
  rapidMovementsZ(interPartTravelZ());   // reached only under the Spoilboard answer -- base frame
  flushMotions();
}

// A 3-axis section can still be ORIENTED off machine +Z -- a Setup built on a model face rather than
// the stock top. isMultiAxis() does not catch it, since Fusion emits ordinary X/Y/Z words for such a
// section, so with no guard the part is cut in the wrong plane and nothing in the file says so.
// Written to FAIL OPEN: it errors only when the orientation is readable AND unambiguously not +Z,
// because a false positive would abort every job. Nothing in here may throw, which is why every branch
// concatenates rather than computes. The Debug trace is emitted on every path, so a guard that read
// nothing is distinguishable from one that read +Z and allowed it.
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

  // A 3-axis section can still be oriented off machine +Z; the check and its Debug trace live in
  // isSectionOrientationSupported(). It has already raised the error when it returns false.
  if (!isSectionOrientationSupported()) {
    return;
  }

  // The Personal edition emits a section's first move as a onLinear rather than a Rapid, leaving
  // current position equal to destination -- a zero-length vector with no direction to read.
  forceSectionToStartWithRapid = true;

  // Write Start gcode of the documment (after the "onParameters" with the global info)
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

  // Do a tool change if its the first section and we are doing the first tool change
  // If its not the first section and the tool changed then do a tool change
  if (isFirstSection()) {
    if (getProperty(properties.toolChangeDoFirstChange))
      toolChange();
  } 
  else if (tool.number != getPreviousSection().getTool().number)
      toolChange();

  // The later-section half of the deliberate WCS-selection split: section 1 already selected inside
  // writeFirstSection(), which had to run before that section's origin write.
  if (!isFirstSection()) {
    writeWCS(currentSection);
  }

  // Machining type
  if (currentSection.type == TYPE_MILLING) {
    // Specific milling code
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
        // Leave the power DEFINED: falling through made laserOn() compute "undefined * 10" and emit
        // S NaN, or silently reuse an earlier section's power. Through is the conservative setting.
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
  display_text(" " + sectionComment);
}

function onSectionEnd() {
  resetAll();
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

// Rapid movements
function onRapid(x, y, z) {
  forceSectionToStartWithRapid = false;

  rapidMovements(x, y, z);
}

// Feed movements
function onLinear(x, y, z, feed) {
  // Convert a Section's first cut move back to a Rapid; unrecovered, with scaling on, it runs at the
  // slowest cutting feedrate. Gated on the master property, which a full-licence job turns off.
  if (getProperty(properties.mapRapidsRestoreRapids) && (forceSectionToStartWithRapid == true)) {
    writeComment(eComment.Important, " First G1 --> G0");

    forceSectionToStartWithRapid = false;
    onRapid(x, y, z);
  }
  else if (isSafeToRapid(x, y, z)) {
    writeComment(eComment.Important, " Safe G1 --> G0");

    onRapid(x, y, z);
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

// Is the current operation a WCS / inspection PROBING operation, as opposed to an ordinary drill /
// bore / tap cycle? Defined locally on purpose: in the Autodesk reference posts isProbeOperation() is
// a post-local helper rather than a kernel global, so calling it undefined would abort the post on the
// first drilled hole. Two independent signals, because either alone can miss one -- the operation
// STRATEGY names the operation as a whole, the CYCLE TYPE names each point and is always prefixed
// "probing", so the test needs no per-cycle list to stay current across Fusion versions.
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
  // WCS/inspection probing cannot be faked by expansion, which would emit plain G0/G1 moves with no
  // G38 at all. This post's own Z touch-off is separate; see probeTool().
  if (isProbeOperation()) {
    cycleNotSupported();
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

    // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
  }

  // Default
  else {
    writeBlock(gFormat.format(4), "S" + secFormat.format(seconds));
  }
}

// Called with every parameter in the documment/section
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

  writeComment(eComment.Info, " " + id);
}

var currentSpindleSpeed = 0;
var currentSpindleClockwise = true;

function setSpindeSpeed(_spindleSpeed, _clockwise) {
  if ((currentSpindleSpeed != _spindleSpeed) || (_spindleSpeed > 0 && currentSpindleClockwise != _clockwise)) {
    if (_spindleSpeed > 0) {
      spindleOn(_spindleSpeed, _clockwise);
    } else {
      spindleOff();
    }
    currentSpindleSpeed = _spindleSpeed;
    currentSpindleClockwise = _clockwise;
  }
}

function onSpindleSpeed(spindleSpeed) {
  setSpindeSpeed(spindleSpeed, tool.clockwise);
}

// One writer for the two speed-feed-synchronization cases in onCommand(), for the same reason
// writeSafeZFormatWarning() exists: a warning duplicated at two call sites comes to differ at one.
function writeSpeedFeedSyncWarning() {
  writeWarning("Speed-feed synchronization for rigid tapping is not supported; a floating/tension tap "
    + "holder is required");
}

function onCommand(command) {
  writeComment(eComment.Info, " " + getCommandStringId(command));

  switch (command) {
    case COMMAND_START_SPINDLE:
      onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
      return;
    case COMMAND_SPINDLE_CLOCKWISE:
      if (!tool.isJetTool()) {
        setSpindeSpeed(spindleSpeed, true);
      }
      return;
    case COMMAND_SPINDLE_COUNTERCLOCKWISE:
      if (!tool.isJetTool()) {
        setSpindeSpeed(spindleSpeed, false);
      }
      return;
    case COMMAND_STOP_SPINDLE:
      if (!tool.isJetTool()) {
        setSpindeSpeed(0, true);
      }
      return;
    case COMMAND_COOLANT_ON:
      if (tool.isJetTool()) {
        // F360 doesn't support coolant with jet tools, but the laser group can force one. tool.coolant
        // is not consulted -- F360 doesn't define it for a jet tool.
        if (getProperty(properties.laserCoolant) != eCoolant.Off) {
          setCoolant(getProperty(properties.laserCoolant));
        }
      }
      else {
        //Convert numeric coolant code to string
        var strCoolant = (tool.coolant < coolantLevels.length ? (coolantLevels[tool.coolant]) : eCoolant.Off);
        writeComment(eComment.Debug, "   tool.coolant = " + tool.coolant + " strCoolant = " + strCoolant);
  
        setCoolant(strCoolant);
      }
      return;
    case COMMAND_COOLANT_OFF:
      setCoolant(eCoolant.Off);  //COOLANT_DISABLED
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
  }
}

function resetAll() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
  fOutput.reset();
}

function writeInformation() {
  // Calcualte the min/max ranges across all sections
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

  // Display the Range Table
  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " Ranges Table:");
  writeComment(eComment.Info, "   X: Min=" + xyzFormat.format(ranges.x.min) + " Max=" + xyzFormat.format(ranges.x.max) + " Size=" + xyzFormat.format(ranges.x.max - ranges.x.min));
  writeComment(eComment.Info, "   Y: Min=" + xyzFormat.format(ranges.y.min) + " Max=" + xyzFormat.format(ranges.y.max) + " Size=" + xyzFormat.format(ranges.y.max - ranges.y.min));
  writeComment(eComment.Info, "   Z: Min=" + xyzFormat.format(ranges.z.min) + " Max=" + xyzFormat.format(ranges.z.max) + " Size=" + xyzFormat.format(ranges.z.max - ranges.z.min));

  // Display the Tools Table
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

// Dump EVERY post property as Info comments, one block per dialog group, so a posted file carries the
// settings that produced it and reviewing it never means inferring the configuration from the motion.
// Iterates the `properties` object rather than listing keys, so a newly added property is dumped
// automatically. Values print in their STORED form -- an enum shows its `id`, not its display title,
// so the dump stays stable across dialog relabelling.
function groupOrder(key) {
  var def = groupDefinitions[key];
  return ((def != undefined) && (def.order != undefined)) ? def.order : 9999;
}

// A property's own `order:` -- the within-group counterpart. An unnumbered property sorts last rather
// than disappearing into the middle of a group. Not in the Post Processor Guide's table of property
// members, but factory grbl.cps uses it, and depending on it is additive: if the dialog ignores it,
// only this dump is affected.
function propertyOrder(key) {
  var p = properties[key];
  return ((p != undefined) && (p.order != undefined)) ? p.order : 9999;
}

function groupTitle(key) {
  var def = groupDefinitions[key];
  return ((def != undefined) && (def.title != undefined)) ? def.title : key;
}

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
// "probeSafeZ = Retract:15" does not tell you the retract resolved to 5.08 for this operation.
function writeResolvedValues() {
  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " Resolved Values:");
  writeComment(eComment.Info, "   Output unit = " + (unit == IN ? "inch" : "mm"));
  // No parentheses in any label below: sanitizeMessageText() strips comment markers, which would
  // leave a double space where the parens were (the same defect fixed once in partProbe()).
  writeComment(eComment.Info, "   Firmware resolved = " + fw);
  writeComment(eComment.Info, "   Map SafeZ = " + describeSafeZ(safeZMode, safeZHeightDefault));
  writeComment(eComment.Info, "   Probe SafeZ = " + describeSafeZ(probeSafeZMode, probeSafeZHeightDefault));
  var base = getReservedBaseWcs();
  writeComment(eComment.Info, "   Fixed Z reference = " + getFixedZReference()
    + (base == 0 ? "" : " -- reserved base " + wcsName(base) + " / P" + base));
  writeComment(eComment.Info, "   Probe XY offset in output units = X" + xyzFormat.format(probeOffsetX()) + " Y" + xyzFormat.format(probeOffsetY()));
  // WITH ITS FRAME NAMED: one field means two unrelated numbers, and a G53 move is interpreted in the
  // active G20/G21 units, so "G53 G0 Z-12" in an inch file means -12 INCHES.
  if (getFixedZReference() != "None") {
    writeComment(eComment.Info, "   Inter Part Travel Z in output units = "
      + xyzFormat.format(interPartTravelZ())
      + (usesMachineZDatum() ? " -- absolute machine Z"
                             : " -- above the spoilboard base " + wcsName(base)));
  }
}

// Implements the group-4 machine-frame controls: establishes the machine frame at job start, once,
// before anything work-relative. Capability and action are SEPARATE properties and only the action is
// emitted here -- "Axes Homed and Trusted" is a declaration read by validateJob() and by the Machine Z
// reference, "Home at Job Start" is the job's decision to act on it. What homing is FOR is unchanged:
// X/Y homing gives the machine frame a repeatable origin, and Z homing gives a travel datum. Neither
// ever becomes the CUTTING reference, which stays the work-Z touch-off.
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

  // Asking for the action with nothing declared homeable cannot be satisfied, and is not a no-op worth
  // passing over: the operator believes the job homes. Not an error() -- it costs no safety on its own.
  if (!homeXY && !homeZ) {
    writeWarning("\"Home at Job Start\" is on but \"Axes Homed and Trusted\" is None -- nothing was"
      + " homed");
    return;
  }

  // A single stop before ANY homing motion, so the operator can prepare the machine -- place a movable
  // Z-homing plate, clear the bed. Independent of firmware and of which axes home.
  if (promptsBeforeHome()) {
    writeComment(eComment.Debug, " writeMachineHoming: pausing before homing (Pause, then Home)");
    askUser("Prepare machine for homing", "Homing", false);
  }

  if (fw == eFirmware.GRBL) {
    // On stock GRBL the capability split is BOOKKEEPING, NOT EMISSION: which axes $H homes is fixed at
    // COMPILE time by HOMING_CYCLE_0/1/2, and $HX/$HY/$HZ sit behind a default-off build option.
    writeComment(eComment.Debug, " writeMachineHoming: GRBL/FluidNC, emitting single combined $H"
      + " (declared X/Y: " + homeXY + " Z: " + homeZ + " -- the build's homing cycle decides)");
    // writeln(), NOT writeBlock(): writeBlock() prefixes an N word when "Enable Line #s" is on, and
    // GRBL recognises a $ command only when $ is the line's first character. It takes no line number.
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

// Job preamble: everything emitted once, before any section's cutting body. Fixed phase order, each
// step depending on the one before -- the header block, the machine frame, the first section's WCS,
// Start() or the start file, the job's fixed Z reference, then the first part's origin. Only the WCS
// selection is not intrinsically first-section work; it lives here because the steps after it may
// write an origin on top of the active WCS, which is why WCS selection is split between here and
// onSection().
function writeFirstSection() {
  writeInformation();

  writeMachineHoming();

  // Select the WCS before Start()/includeStartFile and writeWcsOnStart(), both of which may set an
  // origin on top of the active WCS -- otherwise the origin lands on a stale one.
  writeWCS(currentSection);

  writeComment(eComment.Important, " *** START begin ***");

  if (getProperty(properties.includeStartFile) == "") {
       Start();
  } else {
    loadFile(getProperty(properties.includeStartFile));
  }

  // Establish the job's fixed Z reference (if any) before the first section's own origin --
  // both after Start() so absolute positioning/units are set for the probe or the G53 move.
  writeFixedZReference();

  writeWcsOnStart();

  writeComment(eComment.Important, " *** START end ***");
  writeComment(eComment.Important, " ");
}

// Establish the job's fixed Z reference, in whichever of its two implementations the operator chose.
// Both leave the tool holding a height that clears everything on the bed, measured in a frame that
// does not move with stock thickness, which is why this runs before the first part's own origin:
// whatever it leaves the tool at is where the travel to the first part's X0 Y0 starts from. With no
// fixed reference there is no established frame at job start, and partProbe() warns instead of moving.
function writeFixedZReference() {
  var ref = getFixedZReference();
  writeComment(eComment.Debug, " writeFixedZReference: " + ref);

  if (ref == "Spoilboard") {
    writeBaseEstablish();
  } else if (ref == "Machine Z") {
    if (fw == eFirmware.MARLIN) {
      // Unreachable via the dialog -- validateJob() refuses this combination before any output.
      // Kept so the function is safe to call from anywhere, not because a job can arrive here.
      writeWarning("Fixed Z Reference = Machine Z ignored on Marlin");
      return;
    }
    writeComment(eComment.Important, " Establish fixed Z reference -- homed machine Z");
    writeMachineTravelZ("Move to the travel height in the machine frame");
  }
}

// The SPOILBOARD implementation of the fixed Z reference: at job start, establish the reserved base
// WCS's Z by probing (writing G10 L20 P<base>). A no-op when no base is reserved, so a default job
// emits nothing here, and skipped with a warning on Marlin, which has no P<n> registers.
function writeBaseEstablish() {
  var base = getReservedBaseWcs();
  if (base == 0) {
    writeComment(eComment.Debug, " writeBaseEstablish: no base reserved (None), nothing emitted");
    return;
  }

  var gname = wcsName(base);

  if (fw == eFirmware.MARLIN) {
    // Reason set off with "--" and not brackets: see writeWarning().
    writeWarning("reserved base " + gname + " ignored on Marlin -- no per-WCS registers, single global frame");
    return;
  }

  // "Probe to Set Base" no longer offers a "None -- assume a prior job set it" option: that base Z0 is
  // an offset from MACHINE zero, which a power cycle invalidates silently on a machine with no Z home.
  var mode = getProperty(properties.spoilboardBaseEstablish);   // "Probe Z" | "Pause & Probe Z"

  if (tool.number != 0 && !tool.isJetTool()) {
    // OPERATOR PRECONDITION -- the base is probed WHEREVER THE TOOL ALREADY SITS, no XY move and no
    // probe offset, so park over bare spoilboard or the base silently records the stock top.
    writeComment(eComment.Important, " Establish spoilboard base " + gname);

    // Do the base's Z work in the BASE's own frame. G10 L20 writes a register without selecting it, so
    // without this the G38.2 target and the post-probe retract are measured against the operating WCS.
    var operatingWcs = currentWorkOffset;
    var switched = (operatingWcs != undefined && operatingWcs != base);
    if (switched) {
      writeComment(eComment.Info, "   Select base " + gname + " to probe and retract in its own frame");
      writeBlock(gFormat.format(wcsGcode(base)));   // transit-select the base (no re-probe, no origin write)
      currentWorkOffset = base;
      resetAll();                                   // frame changed -- tracked coordinates no longer apply
    }

    // "Pause & Probe Z" prompts the operator to attach/detach the probe; "Probe Z" runs the
    // probe with no prompts (a fixed/known probe point).
    var pause = (mode == "Pause & Probe Z");
    probePauseBefore = pause;
    probePauseAfter = pause;

    // Z0 written PROVISIONALLY, overwritten by probeTool() below, so the G38.2 target is a distance to
    // search rather than a position in a register nothing has established yet. Z ONLY -- the base's
    // stored X0 Y0 is not this probe's to touch. Sound because the base is probed wherever the tool
    // already sits, which the precondition above requires to be clear spoilboard. Same mechanism as
    // writeWcsOnStart()'s "Current XY & Probe Z" arm, in the same words. CR-11.
    writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
    writeWcsOrigin(base, undefined, undefined, 0);

    // Its own reach, not "G38 Target": see BASE_PROBE_REACH_MM. Stated in the file because the number
    // is not in the dialog, so this comment is the only place an operator can read it.
    var reach = -propertyMmToUnit(BASE_PROBE_REACH_MM);
    writeComment(eComment.Info, "   Search down to Z" + xyzFormat.format(reach) + " from the current height");
    // Retract to the Inter Part Travel Z, not the probe Safe Z -- see probeTool()'s retractZ note.
    // Reached only under Fixed Z Reference = Spoilboard, so the height is in the base's own frame.
    probeTool(base, interPartTravelZ(), reach);

    // Never leave the base active: restore the operating WCS before the first part's origin write or
    // the section's cutting. The reselect moves nothing, so the cleared Z carries over.
    if (switched) {
      writeComment(eComment.Info, "   Restore operating WCS " + wcsName(operatingWcs) + " after base probe");
      writeBlock(gFormat.format(wcsGcode(operatingWcs)));
      currentWorkOffset = operatingWcs;
      resetAll();
    }
  } else {
    writeComment(eComment.Debug, " writeBaseEstablish: probe skipped (tool 0 or jet tool)");
  }
}

// Part-probe XY offset, in output units. The Z-probe touch-point for a PART is its WCS origin plus
// this offset, so the origin can sit at a corner or off the material while Z is read on the stock top.
// Applied to the first part and each added part only -- NOT to the spoilboard base probe, which emits
// no XY move of any kind.
function probeOffsetX() { return propertyMmToUnit(getProperty(properties.probeOffsetX)); }
function probeOffsetY() { return propertyMmToUnit(getProperty(properties.probeOffsetY)); }

// True when a part probe touches off somewhere other than the part origin, i.e. when the XY offset
// creates a traverse. One definition, so partProbe() and the first-part "... Current Pos" path -- which
// must retract before that traverse -- cannot disagree about when it happens.
function probeOffsetIsSet() { return probeOffsetX() != 0 || probeOffsetY() != 0; }

// Operator-pause spec the next probeTool() honors: whether to prompt to attach the Z probe before and
// detach it after. A caller sets these just before invoking the probe; probeTool() reads them and then
// restores the true/true default, which is what the tool-change re-probe uses.
var probePauseBefore = true;
var probePauseAfter = true;

// A part probe: position to the part's Z-probe touch-point (its WCS origin plus the probe XY offset)
// and probe Z into the active WCS. `atOrigin` means the tool already sits on the origin, so the
// reposition is emitted only when the offset is non-zero; added parts pass false, being over the
// previous part. `zUnknown` means the caller emitted no absolute Z before this probe because the active
// frame's Z0 is stale, so the traverse runs at whatever height the tool already holds -- only the
// first-part "Probe Z" mode passes it. Callers guard tool 0 / jet tools, and the base probe does not
// use this at all: it always touches off at the origin, with its own pause setting.
function partProbe(atOrigin, zUnknown) {
  var ox = probeOffsetX();
  var oy = probeOffsetY();
  var offsetSet = probeOffsetIsSet();
  if (!atOrigin || offsetSet) {
    resetAll();
    // The rapid below is at an unknown height, so the file must say so. A WARNING and not an Info
    // comment: it reports a precondition the operator must satisfy, and Info is gone at Level = Off.
    if (zUnknown && !fixedZEstablishedInFile()) {
      writeWarning("no Z reference is established, so the XY move below runs at whatever height the"
        + " tool is holding -- it must be clear of the stock, clamps and fixtures before the program"
        + " starts. The G38.2 target that follows is measured from the Z0 already stored in this WCS,"
        + " which is the value this mode re-probes because it is not trusted.");
    }
    if (offsetSet) {
      writeComment(eComment.Info, "   Move to probe point = origin + offset X" + xyzFormat.format(ox) + " Y" + xyzFormat.format(oy) + ", then probe Z");
    } else {
      writeComment(eComment.Info, "   Move to part origin X0 Y0, then probe Z");
    }
    rapidMovementsXY(ox, oy);
    flushMotions();
  }
  // Attach(before)/detach(after) prompts per probePause: No=neither, Before=attach only,
  // Before & After=both (default -- byte-identical to the historical always-prompt behavior).
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

  if (mode == "Skip") {
    // "Use Active WCS X0 Y0 Z0": trust the stored origin, so probeSafeZ() is meaningful in that frame.
    // "move" and not "retract" -- an ABSOLUTE Z means a tool parked above Safe Z descends to it first.
    writeComment(eComment.Info, "   Use stored work origin; move Z to Safe Z, then to X0 Y0");
    resetAll();
    if (canProbe) {
      rapidMovementsZ(probeSafeZ());
    }
    rapidMovementsXY(0, 0);
    flushMotions();
    return;
  }

  if (mode == "Probe Z") {
    // "Use Active WCS X0 Y0, Probe Z0": use the stored X0 Y0 and re-probe Z -- do NOT write XY. Unlike
    // Skip, Z is stale and about to be probed, so no absolute Z move is emitted in this frame.
    writeComment(eComment.Info, "   Use stored work origin X0 Y0; probe Z");
    if (canProbe) {
      partProbe(false, true);
    } else {
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
    warnJogAtPauseOnGrbl();
    askUser(jogMsg, "Set origin", true);
  }

  if (mode == "Current XYZ" || mode == "Jog XYZ") {
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
    return;
  }

  // "Current XY & Probe Z" or "Jog XY & Probe Z"
  writeComment(eComment.Info, "   Set current X,Y position to 0,0");
  if (canProbe) {
    // Z0 written PROVISIONALLY, overwritten by probeTool() a few blocks below, so that "G38 Target" is
    // a travel limit. Sound only where the operator has just put the tool at the origin themselves.
    writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
    // Without this, the offset traverse runs at whatever Z the operator jogged to -- a millimetre over
    // the stock on this mode's premise. The provisional Z0 above makes an absolute retract meaningful.
    if (probeOffsetIsSet()) {
      writeComment(eComment.Info, "   Retract to Safe Z before the offset traverse");
      resetAll();
      rapidMovementsZ(probeSafeZ());
      flushMotions();
    }
    partProbe(true);
  } else {
    // Tool 0 / jet tool: no probe, so there is no G38 target to bound and nothing for a provisional Z0
    // to fix -- writing one would silently turn this mode into "Set X0 Y0 Z0 to Current Pos".
    writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
    // ... which leaves Z0 at whatever the register already holds, while the jet section that follows
    // emits ABSOLUTE Z words against that unknown zero. Suppressing the write is right; silence is not.
    writeWarning("a jet tool / tool 0 cannot probe, so Z0 was NOT"
      + " established -- this job runs against whatever Z origin is already stored. Use"
      + " \"Set X0 Y0 Z0 to Current Pos\" for a jet/laser job.");
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

// Every ">>> WARNING:" the post writes goes through here, and it IGNORES Comment Level: three of them
// have no validateJob() twin to survive in. Off means less commentary, not fewer warnings. The prefix
// lives here rather than at the call sites so it cannot drift.
//
// NO PARENTHESES IN THE TEXT PASSED HERE. writeCommentLine() hands it to sanitizeMessageText(_, "()"),
// which replaces every run of "(" or ")" with a space, because a grbl comment cannot nest and ends at
// the first ")". Use "--" or a comma; this bit three call sites before it was written down.
function writeWarning(text) {
  writeCommentLine(" >>> WARNING: " + text);
}

function writeComment(level, text) {
  if (commentLevels.indexOf(level) <= commentLevels.indexOf(getProperty(properties.jobCommentLevel))) {
    writeCommentLine(text);
  }
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
}

// Combined X/Y/Z rapid, emitted as separate G0s at each axis's own travel feedrate. Ordered so we
// never plunge into the part: when Z is descending, position XY first and then bring Z down; when Z is
// rising or unchanged, retract Z first and then move XY.
function rapidMovements(_x, _y, _z) {
  if (_z < getCurrentPosition().z) {
    rapidMovementsXY(_x, _y);
    rapidMovementsZ(_z);
  } else {
    rapidMovementsZ(_z);
    rapidMovementsXY(_x, _y);
  }
}

// Calculate the feedX, feedY and feedZ components

function limitFeedByXYZComponents(curPos, destPos, feed) {
  if (!getProperty(properties.feedsScaleFeedrate))
    return feed;

  var xyz = Vector.diff(destPos, curPos);       // Translate the cut so curPos is at 0,0,0
  var dir = xyz.getNormalized();                // Normalize vector to get a direction vector
  var xyzFeed = Vector.product(dir.abs, feed);  // Determine the effective x,y,z speed on each axis

  // Get the max speed for each axis
  let xyLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedXY));
  let zLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedZ));

  // Without the Rapid that normally opens a Section, current equals destination and the vector is zero
  // length, so the slower of the two axis limits is used instead.
    if (xyz.length == 0) {
    var lesserFeed = (xyLimit < zLimit) ? xyLimit : zLimit;

    // Never RAISE a feed: scaling only ever reduces, so the axis limit is a cap on what was asked for.
    // Returned outright it turned an F100 move into F180 on the defaults, and F is modal.
    return (lesserFeed < feed) ? lesserFeed : feed;
  }

  // Force the speed of each axis to be within limits
  if (xyzFeed.z > zLimit) {
    xyzFeed.multiply(zLimit / xyzFeed.z);
  }

  if (xyzFeed.x > xyLimit) {
    xyzFeed.multiply(xyLimit / xyzFeed.x);
  }

  if (xyzFeed.y > xyLimit) {
    xyzFeed.multiply(xyLimit / xyzFeed.y);
  }

  // Calculate the new feedrate based on the speed allowed on each axis: feedrate = sqrt(x^2 + y^2 + z^2)
  // xyzFeed.length is the same as Math.sqrt((xyzFeed.x * xyzFeed.x) + (xyzFeed.y * xyzFeed.y) + (xyzFeed.z * xyzFeed.z))

  // Limit the new feedrate by the maximum allowable cut speed

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
// configured maximum. Deliberately NOT that function's projection, which for an arc would project the
// CHORD -- but on an arc the instantaneous axis velocity is tangential and reaches the full toolpath
// feed wherever the tangent lines up with an axis, so a chord projection under-protects by up to
// 1/cos(45deg). Conservative for a short arc that never reaches a quadrant point, which is the right
// side to err on and keeps the rule predictable: an arc is never faster than the axis limit.
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

function linearMovements(_x, _y, _z, _feed) {
  // Control-side radius compensation is rejected up front in onRadiusCompensation, so
  // pendingRadiusCompensation is always OFF here.

  // Scale the feedrate if enabled: it is projected onto each axis, and if any exceeds its defined max
  // all three are scaled proportionately, then the result is capped at the maximum cut rate.
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

// The folder Fusion is writing this .gcode into, which is where every group-8 include file must live.
// One definition, so validateJob()'s pre-flight check and loadFile()'s own read cannot disagree.
function includeFolder() {
  return FileSystem.getFolderPath(getOutputPath()) + PATH_SEPARATOR;
}

// Test if file exist/can read and load it
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

      // The post's beliefs do not survive a file it did not write, and it re-asserts them LAZILY, so a
      // stale belief is a MISSING word: a G18 left behind makes the next XY arc cut in ZX.
      gPlaneModal.reset();
      gMotionModal.reset();
      resetAll();
    } else {
      // A missing file is loud -- error() aborts the post -- but an empty one used to be silent. It
      // matters most on the Start include, which replaces Start() and so leaves G90/G21 unwritten.
      writeComment(eComment.Info, " --- Custom gcode file is empty, nothing included " + folder + _file);
    }
  } else {
    writeComment(eComment.Important, " Can't open file " + folder + _file);
    error("Can't open file " + folder + _file);
  }
}

function propertyMmToUnit(_v) {
  return (_v / (unit == IN ? 25.4 : 1));
}

function Start() {
  // Common GCODE

  // Set absolute positioning and units of measure
  writeComment(eComment.Info, "   Set Absolute Positioning");
  writeComment(eComment.Info, "   Units = " + (unit == IN ? "inch" : "mm"));

  writeBlock(gAbsIncModal.format(90)); // Set to Absolute Positioning
  writeBlock(gUnitModal.format(unit == IN ? 20 : 21)); // Set the units

  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    // Set the feedrate mode to units per minute
    writeComment(eComment.Info, "   Set Feed Rate Mode to units per minute");
    writeBlock(gFeedModeModal.format(94));

    // Select the workspace plane XY for circular motion
    writeComment(eComment.Info, "   Use the XY plane for circular motion");
    writeBlock(gPlaneModal.format(17));
  }

  // Not GRBL
  else {
    // No G94/G17 here. Neither is a free no-op off GRBL: Marlin compiles G17 only under
    // CNC_WORKSPACE_PLANES and has no G93/G94 at all, and RRF gained G93/G94 only in 3.5.1.

    // Disable stepper timeout
    writeComment(eComment.Info, "   Disable stepper timeout");
    writeBlock(mFormat.format(84), sFormat.format(0)); // Disable steppers timeout
  }
}

var spindleEnabled = false;

// Manual path only: the state the operator was last ASKED for. The speed is held as the formatted
// string that reached the file, because two speeds that format identically are the same speed to the
// operator, and prompting them to change a dial to the number it already reads is worse than saying
// nothing. Direction is tracked beside it so a reversal at an unchanged speed is not missed.
var lastPromptedSpeed = "";
var lastPromptedClockwise = true;

function spindleOn(_spindleSpeed, _clockwise) {
  if (getProperty(properties.jobManualSpindlePowerControl)) {
    var rpm = speedFormat.format(_spindleSpeed);

    // For manual any positive input speed assumed as enabled. so it's just a flag
    if (!spindleEnabled) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual");
      // Direction is named ONLY when counterclockwise: clockwise is the universal default for every
      // tool these machines hold, so naming it would add a word to every job's start prompt.
      askUser("Turn ON " + rpm + " RPM" + (_clockwise ? "" : " counterclockwise"), "Spindle", false);
    }

    // Both halves, because setSpindeSpeed() reaches us for either: a later operation's speed change
    // used to be dropped here, and a tapping reversal at an unchanged speed was silent for the same reason.
    else if (rpm != lastPromptedSpeed || _clockwise != lastPromptedClockwise) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual change");
      // Direction IS always named here, even when only the speed moved: a change prompt asks the
      // operator to alter the machine, so it must state the whole target state rather than a delta.
      askUser("Set spindle to " + rpm + " RPM " + (_clockwise ? "clockwise" : "counterclockwise"),
        "Spindle", false);
    }

    lastPromptedSpeed = rpm;
    lastPromptedClockwise = _clockwise;
  } else {
    writeComment(eComment.Important, " >>> Spindle Speed " + speedFormat.format(_spindleSpeed));
    writeBlock(mFormat.format(_clockwise ? 3 : 4), sOutput.format(_spindleSpeed));
  }

  spindleEnabled = true;
}

function spindleOff() {
  // Manual control describes the MACHINE -- a hand-switched router -- not the dialect, so the branch is
  // on the property first. GRBL used to emit a bare M5, which does nothing to a hand-switched router.
  if (getProperty(properties.jobManualSpindlePowerControl)) {
    // No M5 on this path, mirroring spindleOn(), which emits no M3 under manual control: the post
    // does not command a spindle the operator owns, it asks them.
    if (fw != eFirmware.GRBL) {
      writeBlock(mFormat.format(300), sFormat.format(300), pFormat.format(3000));   // beep -- no M300 on GRBL
    }
    askUser("Turn OFF spindle", "Spindle", false);
  } else {
    writeBlock(mFormat.format(5));
  }

  spindleEnabled = false;
}

// Collapse newlines and any of `unsafeChars` into a single space, so user-supplied text embedded in a
// G-code message or comment cannot break line syntax, comment syntax or quoted parameters. Runs become
// a single space; leading/trailing whitespace is preserved so callers keep their own indentation. The
// second pass squeezes the interior blanks the first creates, which otherwise showed as double gaps.
function sanitizeMessageText(text, unsafeChars) {
  var sanitized = String(text).replace(new RegExp("[\\r\\n" + unsafeChars + "]+", "g"), " ");
  return sanitized.replace(/(\S) {2,}(?=\S)/g, "$1 ");
}

function display_text(txt) {
  // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    // Don't display text
  }

  // Default
  else {
    writeBlock(mFormat.format(117), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + sanitizeMessageText(txt, "();"));
  }
}

function circular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (!getProperty(properties.jobUseArcs)) {
    linearize(tolerance);
    return;
  }

  // Scale the arc's feed to the axis limits, as linearMovements() does for a G1. Here rather than in
  // onCircular(), so the linearize() paths re-enter through onLinear() and are limited the usual way.
  feed = limitArcFeed(feed);

  var start = getCurrentPosition();

  // Full circles never arrive here: maximumCircularSweep = 180 splits them into two arcs upstream, and
  // helical moves are linearized by the kernel -- so only planar partial arcs reach this point.

  // Firmware is Grbl
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

  // Default
  else {
    // Marlin supports arcs only on XY plane
    switch (getCircularPlane()) {
      case PLANE_XY:
        writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), fOutput.format(feed));
        break;
      default:
        linearize(tolerance);
    }
  }
}

// The four "Jog to ..." origin modes cannot work on GRBL, this post's default firmware. askUser()'s
// allowJog flag is consumed in the RepRap branch ONLY, where it appends "X1 Y1 Z1" to M291; the GRBL
// branch emits a bare M0 and discards it -- and "a jog command will only be accepted when Grbl is in
// either the 'Idle' or 'Jog' states" (Grbl v1.1 Jogging, gnea/grbl wiki). A warning rather than a
// deletion, since the modes are correct on RepRap. Called at the jog dispatch sites rather than inside
// askUser(), which also serves prompts that are not jog modes.
function warnJogAtPauseOnGrbl() {
  if (fw != eFirmware.GRBL) {
    return;
  }
  writeWarning("jogging at this pause is not supported on GRBL --"
    + " M0 holds the controller in a state that refuses jog commands. Position the tool before"
    + " starting the job, or choose a \"Use Active WCS ...\" mode.");
}

function askUser(text, title, allowJog) {
  // Firmware is RepRap?
  if (fw == eFirmware.REPRAP) {
    var v1 = " P\"" + sanitizeMessageText(text, "\"") + "\" R\"" + sanitizeMessageText(title, "\"") + "\" S3";
    var v2 = allowJog ? " X1 Y1 Z1" : "";
    writeBlock(mFormat.format(291), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + v1 + v2);
  }

  // GRBL, include the message in a comment prefixed with MSG
  else if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(0), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + "(MSG " + sanitizeMessageText(text, "();") + ")");
  }

  // Default
  else
  {
    writeBlock(mFormat.format(0), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + sanitizeMessageText(text, "();"));
  }
}

function toolChange() {
  // SAY SO and exit. Returning silently cut every section with whichever tool was in the spindle, at
  // the other tools' feeds and speeds. Off is the DEFAULT, so this is reached by accident.
  if (!getProperty(properties.toolChangeEnabled)) {
    writeWarning("change to T" + tool.number + " " + tool.comment
      + " suppressed -- \"Tool Changes are Included\" is off; the previous tool stays in the spindle");
    return;
  }

  writeComment(eComment.Important, " Tool Change Start");

  // If there is a custom GCode file for tool changes then include it
  if (getProperty(properties.includeToolFile1) != "") {
    loadFile(getProperty(properties.includeToolFile1));
  }

  // Are we inserting code to assist with the tool change?
  // If not, then just insert the tool change GCode (M6 <tool number>).
  if (getProperty(properties.toolChangeInsertCode)) {

    // A dedicated tool-change spot only makes sense as a fixed MACHINE location, but toolChangeX/Y/Z
    // are plain G0 words -- WCS-relative -- so the spot drifts to wherever this job's WCS is zeroed.
    flushMotions();
    onRapid(propertyMmToUnit(getProperty(properties.toolChangeX)), propertyMmToUnit(getProperty(properties.toolChangeY)), propertyMmToUnit(getProperty(properties.toolChangeZ)));
    flushMotions();
  
    // turn off spindle and coolant
    onCommand(COMMAND_COOLANT_OFF);
    onCommand(COMMAND_STOP_SPINDLE);

    // If Marlin then BEEP
    if ((fw == eFirmware.MARLIN) && !getProperty(properties.jobManualSpindlePowerControl)) {
      writeBlock(mFormat.format(300), sFormat.format(400), pFormat.format(2000));
    }
  
    // Disable Z stepper
    if (getProperty(properties.toolChangeDisableZStepper)) {
      askUser("Z stepper will disable; wait for full stop", "Tool change", false);
      writeBlock(mFormat.format(84), 'Z'); // Disable steppers timeout
    }

    // Ask tool change and wait user to touch lcd button
    askUser("Insert Tool #" + tool.number + " " + tool.comment, "Tool change", true);
  }
  else
  {
      writeBlock(mFormat.format(6), tFormat.format(tool.number));
  }

  // If there is a custom GCode file for tool changes then include it
  if (getProperty(properties.includeToolFile2) != "") {
    loadFile(getProperty(properties.includeToolFile2));
  }

    // Run Z probe gcode. Same WCS caveat as the rapid above: this runs before the new section's WCS
    // is selected, so probeTool() writes into the PREVIOUS section's WCS.
  if (getProperty(properties.toolChangeProbeAfterChange) && tool.number != 0) {
    onCommand(COMMAND_TOOL_MEASURE);
  }

  writeComment(eComment.Important, " Tool Change End");
}

// Probe Z and write it as the origin of a WCS. targetWcs defaults to the active work offset; the
// reserved-base establishment passes the base WCS number so the spoilboard Z lands in that register.
function probeTool(targetWcs, retractZ, searchZ) {
  if (targetWcs == undefined) {
    targetWcs = currentWorkOffset;
  }
  // The G38.2 Z word, in output units and in the ACTIVE frame. A caller that has written a provisional
  // Z0 passes a DISTANCE to search; everyone else gets "G38 Target", which is a position in that frame.
  if (searchZ == undefined) {
    searchZ = propertyMmToUnit(getProperty(properties.probeG38Target));
  }
  // Post-probe retract height, in output units and in the ACTIVE frame. The base establish passes the
  // Inter Part Travel Z instead, that retract being in the base's frame and having to clear the stock.
  if (retractZ == undefined) {
    retractZ = probeSafeZ();
  }
  // Command comment block
  writeComment(eComment.Important, " Probe to Zero Z");
  if (probePauseBefore) writeComment(eComment.Info, "   Ask User to Attach the Z Probe");
  writeComment(eComment.Info, "   Do Probing");
  writeComment(eComment.Info, "   Set Z to probe thickness: " + zFormat.format(propertyMmToUnit(getProperty(properties.probeThickness))));
  writeComment(eComment.Info, "   Retract the tool to " + xyzFormat.format(retractZ));
  if (probePauseAfter) writeComment(eComment.Info, "   Ask User to Remove the Z Probe");

  if (probePauseBefore) askUser("Attach ZProbe", "Probe", false);

  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    // refer to http://linuxcnc.org/docs/stable/html/gcode/g-code.html#gcode:g38
    // Note this is not using the optional P parameter available on FluidNC (http://wiki.fluidnc.com/en/config/probe)
    writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probeG38Speed))), zFormat.format(searchZ));
  }

  // Not GRBL
  else {
    // refer http://marlinfw.org/docs/gcode/G038.html
    if (getProperty(properties.probeG382orG28)) {
      writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probeG38Speed))), zFormat.format(searchZ));
    } else {
      writeBlock(gFormat.format(28), 'Z');
    }
  }

  writeWcsOrigin(targetWcs, undefined, undefined, propertyMmToUnit(getProperty(properties.probeThickness)));

  // LOAD-BEARING. The G38.2 block writes F and Z through the RAW formats so the modal cannot suppress
  // them, which leaves the tracked feed stale -- the next move matching it would run at probe speed.
  resetAll();
  // move up tool to safe height again after probing
  rapidMovementsZ(retractZ);

  flushMotions();

  if (probePauseAfter) askUser("Detach ZProbe", "Probe", false);

  // Restore the default so the next probe (e.g. the tool-change re-probe) prompts as usual
  // unless its caller sets otherwise.
  probePauseBefore = true;
  probePauseAfter = true;
}