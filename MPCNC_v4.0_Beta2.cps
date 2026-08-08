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

// Lets Fusion's own UI (Operations panel, Post Process dialog) resolve/display a section's
// raw work offset as its actual G-code before posting, instead of showing the bare index.
// useZeroOffset: false matches other official posts (Fanuc, Haas) -- it does NOT change how
// writeWCS() itself resolves offset 0 (still silently aliased to WCS 1 / G54 there); it only
// mirrors their documented meaning (reject an initial offset of 0 mixed with an explicit
// non-zero offset later) in case Fusion's kernel enforces it independently of our own code.
wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"GRBL/RepRap", format:"G", range:[54, 59]},   // G54-G59 (raw offset 1-6)
    {name:"RepRap only", format:"G59.", range:[1, 3]}    // G59.1-G59.3 (raw offset 7-9)
  ]
};

machineMode = undefined; //TYPE_MILLING, TYPE_JET

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

// Maps Fusion's numeric tool.coolant to the coolant name, so the index IS the F360 constant:
// 0 COOLANT_DISABLED, 1 FLOOD, 2 MIST, 3 THROUGH_TOOL, 4 AIR, 5 AIR_THROUGH_TOOL, 6 SUCTION,
// 7 FLOOD_MIST, 8 FLOOD_THROUGH_TOOL. Order is therefore fixed by Fusion and must not be sorted.
//
// Built FROM eCoolant rather than repeating its strings. The two were written as independent
// literals and drifted apart at the last two entries -- this side said "FloodMist" where eCoolant
// said "Flood and Mist". Since the channel-mode properties store eCoolant values as their ids and
// setCoolant() compares the two, a tool requesting Flood and Mist or Flood and ThroughTool could
// never match a channel the operator had configured for exactly that: it fell through to
// ">>> WARNING: No matching Coolant channel : FloodMist requested", naming a string that appears
// nowhere in the dialog. Deriving one from the other makes them agree by construction.
// eCoolant must stay above this line -- the assignment runs at load time and reads it.
const coolantLevels = [eCoolant.Off, eCoolant.Flood, eCoolant.Mist, eCoolant.ThroughTool,
                       eCoolant.Air, eCoolant.AirThroughTool, eCoolant.Suction, eCoolant.FloodMist,
                       eCoolant.FloodThroughTool];

// Dialog group definitions -- Post Processor Guide 5.1.5. A property's `group:` is a KEY into this
// object, not a label: `order` places the group, `title` is what the operator reads. Before this
// block the group string was identity, sort key and label at once, which is the only reason the
// titles were zero-padded ("01 - Job") -- the dialog sorted them as text. The numbers stay in the
// titles because operators and the register rows refer to groups by number; the padding does not.
//
// Each key is the token the member properties' own keys already carry (`job` <- `A_Job_...`,
// `probe` <- `A_Probe_...`), so a property filed under the wrong group is visible on sight.
//
// `order` starts at 100, clear of the built-in groups the engine defines at 10..60 (configuration,
// preferences, homePositions, multiAxis, formats, probing) -- this post uses none of them, and the
// gap means no tie if that ever changes. Steps of 10 leave room to insert a group.
//
// Guard, then augment key by key -- the documented pattern. Assigning a whole literal over the top
// of the guard would discard whatever the guard just preserved, making it decorative.
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

  mapRapidsRestoreFirstRapids: {
    title      : "First G1 -> G0 Rapid",
    description: "Enable to ensure that the first move of a cut starts with a G0 Rapid.",
    group      : "mapRapids",
    order      : 10,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  mapRapidsRestoreRapids: {
    title      : "Map: G1s -> G0 Rapids",
    description: "Enable to convert G1s to G0s Rapids when safe.",
    group      : "mapRapids",
    order      : 20,
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  mapRapidsSafeZ: {
    title      : "Map: Safe Z to Rapid",
    description: "Z at or above this height is treated as safe air, so a G1 there may be re-emitted as a G0. Same syntax as group 6's Safe Z: a plain number in mm, or Feed:/Retract:/Clearance:<fallback> to use that operation's own Fusion level when it defines one, else the fallback -- Retract:15 (the default) means the Fusion retract level, or 15 mm if the operation has none.",
    group      : "mapRapids",
    order      : 30,
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },
  mapRapidsAllowRapidZ: {
    title      : "Map: Allow Rapid Z",
    description: "Enable to include vertical G1 retracts and safe descents as rapids.",
    group      : "mapRapids",
    order      : 40,
    type       : "boolean",
    value      : false,
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
    description: "MULTI-PART JOBS NEED THIS; A SINGLE-PART JOB DOES NOT -- leave it None and skip the rest of the group. The job's fixed Z reference is a frame whose Z0 does NOT move with stock thickness, and therefore the only frame in which one clearance height is meaningful across parts of differing thickness. This answer also decides WHICH FRAME Inter Part Travel Z below is measured in, so re-read that height whenever you change it. None (default): no fixed reference -- Retract Across Parts is unavailable on a multi-WCS job, and Inter Part Travel Z is ignored. Spoilboard: reserve a WCS and probe the spoilboard into it; Inter Part Travel Z is then a height above that surface. Reserved WCS and Probe to Set Base below are its sub-questions. Costs one of GRBL's six WCS registers. GRBL/RepRap only -- Marlin has no per-WCS registers. Machine Z: use the machine's own homed Z frame; Inter Part Travel Z is then an absolute machine coordinate. Consumes NO WCS register and needs no probe, but requires Axes Homed and Trusted to include Z AND Home at Job Start not Off, both in group 4 -- the frame an absolute move trusts must be one this job established. Not available on Marlin.",
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
  spoilboardSafeZAcrossWcs: {
    title      : "Retract Across Parts",
    description: "Multi-fixture safety. On (default): before traversing between operations that use different WCS, the tool retracts to a clearance measured in the job's fixed Z reference so it clears fixtures/clamps/other parts, and the job is validated (Guard B) to reject a multi-WCS job that has no fixed Z reference at all -- a clearance height is meaningless across WCS whose offsets are only known after probing at runtime. The height is Inter Part Travel Z below, read in whichever frame Fixed Z Reference names. Single-WCS jobs (including a single operation) are unaffected: no extra retract is emitted and the guard does not apply. Off: no cross-WCS retract and no guard. GRBL/RepRap only (Marlin is single-frame; see Guard C).",
    group      : "spoilboard",
    order      : 40,
    type       : "boolean",
    value      : true,
    scope      : "post"
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
    description: "MULTI-PART JOBS ONLY -- milling several parts or copies, one WCS per part. What to do when the job advances to the next part's WCS (G55, G56, ...). A single-part job never reaches this control. Not supported on Marlin at all, which has one global origin -- use separate jobs. THE TWO JOG MODES DO NOT WORK ON GRBL, the default firmware (see First WCS / Part); the post warns and says so in the file. Every mode first retracts to a safe Z, then acts. USE ACTIVE WCS (pre-set fixture offsets / Replicate) -- Use Active WCS X0 Y0, Probe Z0 (default): rapid to the part's stored X0 Y0 and probe its stock-top Z, writing Z into that WCS; XY stays the fixture's pre-set offset. Use Active WCS X0 Y0 Z0: do nothing to the origin; after the retract the tool rapids to the part's stored X0 Y0 (X, Y and Z already in its own WCS, from a prior job or set manually). JOG (you jog to each part during the run) -- Jog to X0 Y0, Probe Z0: pause (M0) to jog to this part's origin, record X0 Y0 there, then probe Z. Jog to X0 Y0 Z0: pause (M0) to jog to this part's origin, then record that position as X0 Y0 Z0, no probe. \"Active WCS\" means the register that part's Fusion Setup designates, which the post selects on the traverse; its stored contents come from a prior job or a manual touch-off and are trusted, not verified. The attach/detach prompts around any probe follow Probe Pause; the safe-Z retract on the traverse is separate (see Retract Across Parts). Does NOT support milling one part from multiple datums or a flip -- run those as separate jobs.",
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
    description: "How far the probe move is allowed to travel before giving up -- a Z POSITION in the part's frame, not a distance. On the two Set ... to Current Pos modes the post writes a provisional Z0 first, so -10 (the default) searches to 10 mm below wherever the tool is now. On the two Use Active WCS modes it is measured from that WCS's STORED Z zero instead, which may be anywhere. Deep enough to reach the plate and no deeper: a probe that travels this far without touching is a failed probe, and GRBL raises an alarm and stops the job.",
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
    description: "Safe Z the tool retracts to after probing (also the retract height before an added-part re-probe when the job has no fixed Z reference; with one, that group's clearance -- Inter Part Travel Z -- is used instead). Same syntax as \"Map: Safe Z to Rapid\": a fixed number, or Feed:/Retract:/Clearance:<fallback> to use the operation's F360 level when defined, else the fallback -- e.g. \"Retract:15\" uses the F360 retract level or 15. Kept independent of the Map G1s Safe Z.",
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
  // NOT IMPLEMENTED. Declared but never read -- nothing in the post calls loadFile() with
  // it, so a value entered here is silently ignored. Kept (rather than deleted) because the
  // feature is wanted: the intent is to include this file at every probe, including the
  // tool-change re-probe, which makes it part of the Tool Change branch's ordering work.
  // The title and tooltip say so, since a dialog field that advertises a feature and does
  // nothing is worse than no field at all. See HReview.md HR-21.
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

// Writes the specified block.
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
// The literal fallback parsed out of the Safe-Z property, in MILLIMETRES -- every dialog dimension
// is mm by contract (README, "Units"), whatever unit the job outputs in. Convert with
// propertyMmToUnit() before comparing it against, or emitting it as, a coordinate. Contrast
// safeZHeight below, which is the RESOLVED height in the job's output unit.
var safeZHeightDefault = 15;
var safeZHeight;   // resolved height, in the OUTPUT unit

// Parse a Safe-Z expression string -- a bare number, or Feed:/Retract:/Clearance:<fallback> --
// into { mode, dflt }. Shared by the Map-G1s Safe Z (mapRapidsSafeZ) and the probe Safe Z
// (probeSafeZ) so both accept identical syntax. Pure: touches no globals, emits no output.
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

function safeZforSection(_section)
{
  if (getProperty(properties.mapRapidsRestoreRapids)) {
    // The fallback is a dialog literal, so it is mm and must be converted to the output unit before
    // it can be compared against a coordinate. The F360 level values below are NOT converted --
    // Fusion already reports those in the output unit. Getting this wrong on an inch job made the
    // whole G1 -> G0 mapper silently inert: every Z was compared against a threshold of "15 inch",
    // which no toolpath ever reaches, so no move was ever converted and nothing said so.
    // Every level test below asks the PASSED section, never the global hasParameter(). The global
    // form reports on whatever section is current, which is the same thing only while this is called
    // from inside that section -- true of the sole caller today, but the _section parameter is an
    // open invitation to call it with another one, and the first caller to do so would get the guard
    // answering about the wrong section and the fallback handed back silently. resolveSafeZHeight()
    // had this exact defect and it was not hypothetical there; see its comment.
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
        writeComment(eComment.Important, " >>> WARNING: " + properties.mapRapidsSafeZ.title + " format error: " + safeZHeight);
        break;
    }
  }
}

// Resolve a parsed Safe-Z expression against one section's F360 levels, returning a concrete
// height in the OUTPUT unit -- the same convention safeZforSection() uses. Feed/Retract/Clearance
// pull the matching operation level when it is defined and absolute; otherwise the literal fallback
// is used. Pure: emits no output.
//
// The two inputs arrive in DIFFERENT units and only one converts:
//   - an F360 level value is already in the output unit, so it is returned untouched;
//   - the literal fallback is a dialog value, and every dialog dimension is mm by contract
//     (README, "Units"), so it converts.
// Both fallback returns below therefore go through propertyMmToUnit(). Missing that on an inch job
// made this function hand back "15" meaning 15 inch -- 381 mm -- which probeSafeZ()'s caller then
// emitted as an absolute G0 Z: a full-travel retract into the Z limit.
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

  // Ask the PASSED section, not the global context. The global hasParameter() reports on whatever
  // section is current, which is only the same thing when this is called from inside that section.
  // writeResolvedValues() resolves every section from the header, where no section is current --
  // the global form would report false throughout and silently hand back the fallback for all of
  // them, which is exactly the misleading answer this function exists to avoid.
  if (_section.hasParameter(valueParam) && _section.hasParameter(absParam) && _section.getParameter(absParam) == 1) {
    return _section.getParameter(valueParam);   // already in the output unit
  }
  return fallback;
}

// Describe a parsed Safe-Z expression for the header block: its mode, its literal fallback, and --
// the part the stored property string cannot tell you -- what it actually RESOLVES to for this
// job's operations. "Retract:15" resolving to 5.08 on every section is the case that made reading
// H7.gcode slow; printing only the mode and the fallback merely restates the property, under a
// heading that promises a resolved value.
// `dflt` arrives in mm (the parsed dialog literal). Everything this function PRINTS is in the output
// unit, so the fallback is converted for display -- the resolved value beside it comes back from
// resolveSafeZHeight() already converted, and printing one in mm next to the other in inch would
// make the header contradict itself. resolveSafeZHeight() is still handed the raw mm value: it does
// its own conversion, so pre-converting here would apply it twice.
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
// probeSafeZ ("6 - On WCS / Part / Fixture Changes" > "Safe Z") uses the SAME expression syntax and
// F360-level resolution as the Map-G1s Safe Z (mapRapidsSafeZ), but is a fully independent
// property so the two can be tuned separately. "Retract:15" pulls each operation's F360 retract
// level when defined and absolute, else falls back to 15 mm.
var probeSafeZMode = eSafeZ.CONST;
var probeSafeZHeightDefault = 15;   // the parsed literal fallback, in MILLIMETRES (see safeZHeightDefault)

function parseProbeSafeZProperty() {
  var parsed = parseSafeZExpr(getProperty(properties.probeSafeZ));
  probeSafeZMode = parsed.mode;
  probeSafeZHeightDefault = parsed.dflt;

  writeComment(eComment.Debug, " parseProbeSafeZProperty: probeSafeZMode = '" + eSafeZ.prop[probeSafeZMode].name + "'");
  writeComment(eComment.Debug, " parseProbeSafeZProperty: probeSafeZHeightDefault = " + probeSafeZHeightDefault);
}

// Resolve probeSafeZ for the current operation. Returns a height in the output unit -- already
// unit-correct, so callers must NOT wrap it in propertyMmToUnit(). That now holds on BOTH paths:
// an F360 level arrives in the output unit, and resolveSafeZHeight() converts the mm fallback. It
// previously held only for the level path, so an inch job that fell back returned inches-worth of
// millimetres straight into an absolute G0 Z.
function probeSafeZ() {
  return resolveSafeZHeight(probeSafeZMode, probeSafeZHeightDefault, currentSection);
}


function roundTo(value, places) {
  // Plain arithmetic, not the string-exponent trick this used to use. That form built a string and
  // read it back -- "value + 'e+' + places" -- which relies on String(value) never containing an
  // exponent of its own. JavaScript renders any magnitude below 1e-6 exponentially, so a Z of 1e-7
  // (ordinary float noise from a toolpath that meant zero) built "1e-7e+3" and the whole expression
  // came back NaN. In isSafeToRapid() that fails closed -- every comparison against NaN is false, so
  // the move simply is not converted -- and in the orientation guard's Debug trace it printed the
  // tilt as "NaN". The string form existed to dodge cases like Math.round(1.005 * 100); that error
  // lives in the 15th digit and cannot change an answer here, where the only job is to compare two
  // coordinates at the precision they will be written with.
  var scale = Math.pow(10, places);
  return Math.round(value * scale) / scale;
}

// Returns true if the rules to convert G1s to G0s are satisfied
function isSafeToRapid(x, y, z) {
  if (getProperty(properties.mapRapidsRestoreRapids)) {

    // Compare positions at the output precision (unit-dependent: 3 dp mm / 4 dp inch, the
    // same precision the coordinates are written with). Two positions that format to the
    // same G-code are the same point, so rounding here keeps floating-point representation
    // noise from spuriously failing the "constant axis" tests and defeating the G1 -> G0 mapping.
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

      // Restore Rapids only when the target Z is safe and
      //   Case 1: Z is not changing, but XY are
      //   Case 2: Z is increasing, but XY constant

      // Z is not changing and we know we are in the safe zone
      if (zConstant) {
        return true;
      }

      // We include moves of Z up as long as xy are constant
      else if (getProperty(properties.mapRapidsAllowRapidZ) && zUp && xyConstant) {
        return true;
      }

      // We include moves of Z down as long as xy are constant and z always remains safe
      else if (getProperty(properties.mapRapidsAllowRapidZ) && (!zUp) && xyConstant && curZSafe) {
        return true;
      }
    }
  }

  return false;
}

//---------------- Coolant ----------------

// The four "... Custom" coolant properties name a FILE in the nc output folder, exactly as group
// 08's five include fields do -- that is what their own tooltips say ("File with custom GCode to
// turn ON coolant channel A (in nc folder)") and what the README's group-10 table says ("Custom
// include files when Mode = Use custom"). They used to be written straight into the g-code stream
// with writeBlock(), so an operator who did what the field asked and typed "air_on.g" got the
// literal block "air_on.g" streamed to the controller, which answers an unsupported-command error
// mid-job; leaving the field empty emitted a stray blank line. Routed through loadFile() they now
// also inherit its missing-file error and its missing-trailing-newline repair. See HReview.md CR-4.
function writeCustomCoolantFile(channel, on, file) {
  if (file == "") {
    writeComment(eComment.Important, " >>> WARNING: coolant channel " + channel + " is set to \"Use custom\""
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
      writeComment(eComment.Important, " >>> WARNING: No matching Coolant channel : " + ((coolantLevels.indexOf(coolant) != -1 ) ? coolant : "unknown") + " requested");
    }
  }
}

//---------------- Cutters - Waterjet/Laser/Plasma ----------------

var cutterOnCurrentPower;

function laserOn(power) {
  // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    var laser_pwm = power * 10;

    // Number(), not the raw property: laserGrblMode stores its enum id as a STRING ("4" / "3"),
    // and this is the only mFormat.format() call in the file handed anything but a numeric literal.
    // Whether the kernel's format() coerces a numeric string is not something reading can settle,
    // and the cost of it not doing so is that every GRBL laser job emits a malformed laser-on block
    // and the laser never fires. No posted file has ever exercised group 09 -- see PReview.md J4.
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

// Called in every new gcode file
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

// Guard A support: does any section (re)write an origin into WCS `base`? Returns the
// triggering feature's name, or null. Cutting *in* the base is fine; only a write is the
// error. Mirrors the three origin-writing triggers and their firing conditions.
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

// Post-time validation guards (see docs/conventions.md "Validation guards").
// Runs once from onOpen(), before any output, so a misconfiguration fails fast.
function validateJob() {
  // --- Warnings ------------------------------------------------------------------------------
  // These run before the guards and on every firmware: they describe configurations that post a
  // perfectly valid file which then does the wrong thing at the machine. warning(), not error() --
  // each of them is legitimate on some setup, so the operator gets told, not blocked.

  // Homing MOVES the tool, and the "Set ... to Current Pos" origin modes record wherever it ends
  // up -- which after homing is the endstop corner at the extreme of travel. writeMachineHoming()
  // is step 2 of writeFirstSection() and writeWcsOnStart() is step 6, so the pre-jog the README
  // instructs for the default mode ("jog the tool to the part's XY corner before posting") is
  // destroyed in between. The result is a G38.2 that never contacts, or a part cut a bed-diagonal
  // away from the stock. Legitimate only on a machine whose home corner IS the datum.
  // See docs/HReview.md CR-2.
  var startMode = getProperty(properties.probeOnStart);
  var changeMode = getProperty(properties.probeOnChange);
  var homedXY = machineHomesXY();
  var homedZ = machineHomesZ();
  // "Subsequent WCS / Part" is consulted only on a genuine WCS change (writeWCS()'s isTraverse),
  // which a single-offset job never has -- so every warning about that control is gated on this.
  var multiWcs = collectDistinctOffsets().length > 1;

  // The group-4 pair can be set to a combination that cannot be satisfied, and it is the likeliest
  // group-4 mistake: the operator wants homing, reads the ACTION, sets it, and never treats the
  // declaration above it as something they must change too. writeMachineHoming() then emits NO
  // MOTION -- it warns in the file and returns -- so the job starts from an unhomed machine with the
  // operator believing it homed. That in-file warning was the only trace anywhere; Fusion's post
  // dialog said nothing. warning(), not error(): the posted file is valid and every other control
  // still behaves. Exactly complements the (homedXY || homedZ) test below, which is written for the
  // case where homing DOES move the tool. See docs/HReview.md HB-3.
  if (homesAtJobStart() && !homedXY && !homedZ) {
    warning(localize("\"Home at Job Start\" asks this job to home, but \"Axes Homed and Trusted\" is "
      + "None, so no axis is declared homeable and the post emits no homing motion at all -- the job "
      + "starts from wherever the machine already sits. Declare which axes this machine homes to "
      + "endstops, or set \"Home at Job Start\" to Off."));
  }

  // The action alone is not the trigger: writeMachineHoming() emits NO MOTION when "Axes Homed
  // and Trusted" is None -- it warns that nothing was homed and returns -- so keyed on the action
  // alone this describes a tool move that does not happen and tells the operator to abandon a
  // pre-jog that is in fact intact. Either axis group qualifies: X/Y homing destroys the pre-jogged
  // XY, and Z homing moves the tool to the Z endstop, which both modes then record as Z0.
  if (homesAtJobStart() && (homedXY || homedZ) &&
      (startMode == "Current XY & Probe Z" || startMode == "Current XYZ")) {
    // Reworded as advice rather than prohibition: with X/Y declared homed, a stored fixture offset
    // in the active WCS is repeatable across power cycles, so it is a better first-part answer than
    // the pre-jog this configuration destroys -- naming it costs a clause and saves a round trip.
    // "the axes it homes" rather than "the homing corner": the declaration can be Z only, where
    // there is no corner and what moves is the height the origin is recorded at.
    warning(localize("\"Home at Job Start\" moves the tool onto the endstops of whichever axes "
      + "\"Axes Homed and Trusted\" declares, and it runs before "
      + "\"First WCS / Part\" records the current position as the part origin, so positioning the "
      + "tool before starting the job has no effect on those axes. On a homed machine the stored "
      + "offset in the active WCS is repeatable, so \"Use Active WCS X0 Y0, Probe Z0\" is the "
      + "natural first-part mode here; a \"Jog to ...\" mode also works. Otherwise set \"Home at "
      + "Job Start\" to Off."));
  }

  // A G54-G59 register holds an offset from MACHINE zero, and homing never touches those registers
  // -- it makes them meaningful. Unhomed, machine zero is wherever the controller was last reset:
  // still fixed for THAT power cycle, so offsets created during this run stay consistent with each
  // other and with the bed, and a multi-part job built that way works. What breaks is trusting a
  // STORED offset, which a power cycle silently invalidated. Hence the mode split below, and hence
  // this must NOT fire on the "Jog to ..." modes, where every origin is created this run: a false
  // positive there would reject the legitimate no-endstop multi-part job the post exists for.
  // Note the default subsequent mode ("Probe Z") uses the stored XY, so this is reachable without
  // any deliberate choice on a multi-part job. See docs/conventions.md "Frames".
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

  // E2 -- the post-time half of warnJogAtPauseOnGrbl(). See that function for the source read.
  // The "Subsequent WCS / Part" half carries multiWcs and the "First WCS / Part" half does not,
  // and the asymmetry is the controls' own: the first-part mode runs on every job, while the
  // subsequent-part mode is never consulted on a single-offset job, so warning on it there
  // describes a pause the file will not contain.
  if (fw == eFirmware.GRBL &&
      (startMode == "Jog XY & Probe Z" || startMode == "Jog XYZ" ||
       (multiWcs && (changeMode == "Jog XY & Probe Z" || changeMode == "Jog XYZ")))) {
    warning(localize("A \"Jog to ...\" origin mode is selected, but GRBL cannot jog at the pause "
      + "it produces: the post emits M0, and GRBL 1.1 accepts a jog command only in its Idle or Jog "
      + "states. The job will stop and wait, and the operator will be unable to move the machine "
      + "without resetting the program. These modes are supported on RepRap. On GRBL, position the "
      + "tool before starting and use a \"Set ... to Current Pos\" or \"Use Active WCS ...\" mode."));
  }

  // Establishing the fixed Z reference MOVES THE TOOL, and it is step 5 of writeFirstSection() --
  // before step 6 records the first part's origin. The machine-Z answer rapids to
  // G53 Z<Inter Part Travel Z>; the spoilboard answer probes the base and retracts to that same
  // height above it. So under either answer the "current position" step 6 reads is bed clearance,
  // not where the operator left the tool, and both "... to Current Pos" modes record it anyway:
  //   - "Set X0 Y0 to Current Pos, Probe Z0" writes HR-1's provisional Z0 at that clearance, which
  //     turns "G38 Target -10" into a 10 mm descent from bed clearance: the probe never reaches the
  //     stock and the controller alarms on "did not contact".
  //   - "Set X0 Y0 Z0 to Current Pos" fails quieter and worse -- bed clearance becomes the part's
  //     Z0, and every cut in the job runs that far above the stock with nothing saying so.
  // No arithmetic fixes either: the distance from clearance to the stock top is exactly what the
  // probe exists to discover. Hence a warning. The "Jog to ..." modes are deliberately NOT included
  // -- there the operator positions the tool AFTER the establish, which is the condition HR-1's
  // provisional Z0 is sound under. Marlin reaches neither establish (the machine-Z answer is
  // refused outright below, and writeBaseEstablish() skips the base for want of per-WCS registers),
  // so nothing moves there and the warning would be false.
  if (fw != eFirmware.MARLIN && fixedZEstablishedAtStart() &&
      (startMode == "Current XY & Probe Z" || startMode == "Current XYZ")) {
    warning(localize("\"Fixed Z Reference\" is established at job start by moving the tool to "
      + "\"Inter Part Travel Z\", and that runs before \"First WCS / Part\" records the current "
      + "position -- so the origin is recorded at bed clearance rather than at the part, and the "
      + "probe target measured from it will not reach the stock. Use \"Use Active WCS X0 Y0, Probe "
      + "Z0\" or a \"Jog to ...\" mode, or set \"Fixed Z Reference\" to None."));
  }

  // "At End Park At" = machine X0 Y0 crosses the bed from wherever the last operation ended, and
  // writeMachineParkXY() can retract first only in a frame THIS JOB ESTABLISHED -- parkCanRetract().
  // With no fixed Z reference there is no such frame, so the crossing happens at the last
  // operation's finishing Z. A warning rather than a guard because Fusion's own end-of-operation
  // retract covers an ordinary milling job; a jet section that ends at cutting height is not
  // covered, which is HReview.md HR-16's open half. writeMachineParkXY() says the same thing in the
  // posted file, for the operator who never sees this dialog.
  if (getProperty(properties.machineParkAtEnd) == "Machine" && !parkCanRetract()) {
    warning(localize("\"At End Park At\" = machine X0 Y0 crosses the bed to the homing corner, but "
      + "this job establishes no fixed Z reference to retract in, so the tool makes that crossing "
      + "at whatever Z the last operation left it at. Set \"Fixed Z Reference\", or park at work "
      + "X0 Y0."));
  }

  // Post-time half of toolChange()'s suppression warning, so it reaches Fusion's dialog and not
  // only the posted file. See docs/HReview.md CR-3.
  if (!getProperty(properties.toolChangeEnabled) && countDistinctTools() > 1) {
    warning(localize("This job uses more than one tool, but \"Tool Changes are Included\" is off: "
      + "no tool-change code is emitted and every operation runs with the tool already in the "
      + "spindle, at the other tools' feeds and speeds. Enable the \"7 - Tool Changes\" group, or "
      + "post one tool per file."));
  }

  // --- Guards --------------------------------------------------------------------------------
  // The fixed-Z-reference guards run FIRST, above Guard C's Marlin branch, and the placement is
  // load-bearing: that branch returns as soon as its own test is done, so a guard written below it
  // is unreachable on exactly the firmware it was written to exclude.
  var fixedZ = getFixedZReference();
  var reservedRaw = getProperty(properties.spoilboardBaseReserve);

  // The two answers must agree. "Reserved WCS" is a sub-question of the spoilboard answer, so
  // either combination below is a configuration whose intent cannot be read -- and the failure
  // mode of guessing is silent in both directions: a base named under another answer would simply
  // never be probed, and the spoilboard answer with no register named would establish nothing.
  if (fixedZ == "Spoilboard" && reservedRaw == "None") {
    error("\"Fixed Z Reference\" is the spoilboard answer but no \"Reserved WCS\" is chosen -- pick the WCS to reserve as the base, or set \"Fixed Z Reference\" to None.");
    return;
  }
  if (fixedZ != "Spoilboard" && reservedRaw != "None") {
    error("\"Reserved WCS\" names " + wcsName(parseInt(reservedRaw, 10)) + " but \"Fixed Z Reference\" is not the spoilboard answer, so the base would never be probed -- set \"Fixed Z Reference\" to the spoilboard answer, or set \"Reserved WCS\" to None.");
    return;
  }

  // "Inter Part Travel Z" is ONE field read in whichever frame this enum names, so the enum FLIP is
  // the hazard the two separate fields used to make impossible: a height valid in the other frame is
  // still a valid-looking height, and only one direction of the flip is detectable. Spoilboard
  // clearances are measured UP from the probed surface, so <= 0 cannot be one -- and on a stock GRBL
  // build a machine Z usually IS negative (HOMING_FORCE_SET_ORIGIN defaults off, so the machine
  // zeroes into negative space at the switch), which makes that the common leftover and this test
  // worth its lines. The reverse -- a spoilboard 40 left in a machine-Z job -- is indistinguishable
  // from a real height on a bed-zeroed machine, and is caught only by the empty default (the field
  // ships unset, so an untouched dialog cannot post) and by the frame-naming header echo.
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
    // Guard C EXTENDED, not inherited. Today's Guard C excludes Marlin from MULTI-WCS work because
    // Marlin is single-frame. A machine-frame feature needs a different exclusion: G53 on Marlin is
    // a build option that is OFF by default -- Marlin/src/gcode/gcode.cpp (2.1.x) gates
    // "case 53: G53();" inside #if ENABLED(CNC_COORDINATE_SYSTEMS), alongside G54-G59. A
    // SINGLE-WCS Marlin job is single-frame, passes Guard C's own test, and still cannot execute
    // the move. The two exclusions overlap and neither contains the other.
    if (fw == eFirmware.MARLIN) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires G53, which is a build option on Marlin (CNC_COORDINATE_SYSTEMS) and off by default -- use the spoilboard answer, or None.");
      return;
    }
    if (!machineHomesZ()) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Axes Homed and Trusted\" to include Z -- declare that this machine homes Z, or choose another fixed Z reference.");
      return;
    }
    // The declaration alone is not enough HERE, though it is everywhere else. A Z declaration with
    // "Home at Job Start" off is the state the capability/action split exists to express --
    // and it is exactly the stale-frame case that "Probe to Set Base = None" was removed for, one
    // frame further out: after a power cycle the machine frame moved and the declaration did not.
    // It is worse than that case, because the stale frame drives an absolute RAPID rather than a
    // clearance, and only GRBL stops it -- with homing enabled GRBL comes up in Alarm and refuses
    // all motion until homed, while Marlin and RRF have no equivalent lock and simply run the move
    // at a height measured from a machine zero that has moved. So when this is the datum, the job
    // homes: the frame the file trusts is one the file established.
    if (!homesAtJobStart()) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Home at Job Start\" to be Home or Pause, then Home -- an absolute machine-frame move must be measured against a frame this job established, not one a previous power cycle left behind.");
      return;
    }
    if (parseInterPartTravelZ() == undefined) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Inter Part Travel Z\" as an ABSOLUTE machine coordinate -- home the machine, jog to a height that clears every fixture and part, and enter the Z the sender's DRO reports, in mm. It is empty whenever this answer has just changed, because a height measured above the spoilboard is not a machine Z.");
      return;
    }
    // Decision 2: the machine-frame unlock requires declared homed XY. Not because the Z-only move
    // needs it -- it does not -- but because the multi-part workflow this clearance exists to serve
    // moves between stored work offsets, and those are repeatable only against a homed machine
    // zero. The requirement is stated once, here; usesMachineZDatum() carries no trace of it.
    if (!homedXY) {
      error("\"Fixed Z Reference\" = the machine-Z answer requires \"Axes Homed and Trusted\" to include X/Y -- the multi-part traverses it serves move between stored work offsets, which are repeatable only on a machine with a homed X/Y zero.");
      return;
    }
  }

  // "At End Park At" = the machine answer. Placed ABOVE Guard C's Marlin branch for the same
  // load-bearing reason the fixed-Z guards are -- that branch returns -- and here it matters more,
  // because this guard APPLIES on Marlin where the machine-Z datum is excluded outright. The park
  // has a Marlin route (G28 X Y) precisely because it re-establishes the frame instead of
  // addressing it, and that is also why the "Home at Job Start" half below is GRBL/RepRap-only:
  // their route is an absolute rapid into a frame that must already exist, Marlin's route IS the
  // homing. See writeMachineParkXY() and docs/PReview.md PR-6.
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

  // Guard C -- Marlin is single-frame: a job using more than one distinct work offset
  // is silently wrong on it. The reserved base is a per-WCS-register concept that does
  // not apply to Marlin (warned at establish time), so its guards are skipped here.
  if (fw == eFirmware.MARLIN) {
    if (collectDistinctOffsets().length > 1) {
      error("Marlin has a single coordinate frame -- this multi-WCS job cannot be posted; use one work offset.");
    }
    return;
  }

  var base = getReservedBaseWcs();
  if (base == 0) {
    // Guard B -- safe-Z across WCS needs A FIXED Z REFERENCE, of either kind. When the cross-WCS
    // safe-Z retract is enabled and the job spans more than one work offset, there is no frame in
    // which a single clearance height is meaningful across those WCS: their offsets are only
    // established by probing at runtime, so the post can't relate one WCS's Z to another's. A
    // fixed Z reference is that common frame. Relaxed from "requires a reserved base": a homed
    // machine Z is the same frame by another implementation, and requiring the base was rejecting
    // multi-WCS jobs on machines whose machine Z would serve perfectly -- and charging them a WCS
    // register, of which GRBL has six, to do it. A single-WCS job is exempt: its one work zero is
    // a stable enough reference. (Marlin multi-WCS already errored above via Guard C, so only
    // GRBL/RepRap reach here; the machine-Z answer already errored on Marlin too.)
    if (!usesMachineZDatum() && getProperty(properties.spoilboardSafeZAcrossWcs)
        && collectDistinctOffsets().length > 1) {
      error("Safe-Z across parts requires a fixed Z reference: set \"Fixed Z Reference\" to the spoilboard answer (and reserve a WCS) or to the machine-Z answer, or turn off \"Retract Across Parts\".");
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
// two of them -- currentWorkOffset and sequenceNumber -- which is the tell that this post does not
// want to rely on getting a fresh JavaScript context for every output file. The other twelve were
// simply missed. If that assumption ever breaks the failure is quiet rather than loud: a second
// file would open with spindleEnabled already true and never emit its "Turn ON ... RPM" prompt, or
// with coolantChannelA still holding the previous job's coolant. Collected into one function so a
// newly added global is reset by editing one place. See docs/HReview.md CR-13.
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
}

function onOpen() {
  fw = getProperty(properties.jobSelectedFirmware);

  resetPostState();

  // Validate the job configuration before emitting anything (may error() out).
  validateJob();

  // NO "%" wrapper, on any firmware. Recorded because an absence cannot explain itself, and the
  // character is familiar enough from Fanuc/LinuxCNC posts to be re-added by a later reader. Stock
  // Grbl 1.1 has no "%" feature: in gnea/grbl the '%' branch of grbl/protocol.c's line reader is
  // commented out -- "// TODO: Install '%' feature" -- beside the live '(' and ';' cases, so the
  // character is buffered like any other. The line is not $-prefixed, so it reaches
  // gc_execute_line(), which rejects a first word that is not a letter A-Z: error:1. With homing
  // enabled the opening one was also sent while Grbl was still in Alarm, before $H, answering
  // error:9 instead. UGS / bCNC / Candle strip '%' before streaming and so masked it; a sender that
  // streams verbatim and halts on error never started the job at all. Marlin/RepRap never had one.
  // See docs/HReview.md HB-2.

  // Configure the GCode G commands
  if (fw == eFirmware.GRBL) {
    gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
  }
  else {
    gMotionModal = createModal({ force: true }, gFormat); // modal group 1 // G0-G3, ...
  }

  // Configure how the feedrate is formatted
  if (getProperty(properties.feedsEnforceFeedrate)) {
    fOutput = createVariable({ force: true }, fFormat);
  }

  // (sequenceNumber and currentWorkOffset are initialised by resetPostState() above, with the
  // other module globals.)

  // Set the seperator used between text
  if (!getProperty(properties.jobSeparateWordsWithSpace)) {
    setWordSeparator("");
  }

  // Determine the safeZHeight to do rapids
  parseSafeZProperty();

  // Determine the probe retract Safe Z (independent property, same syntax)
  parseProbeSafeZProperty();
}

// Called at end of gcode file
function onClose() {
  writeComment(eComment.Important, " *** STOP begin ***");

  flushMotions();

  if (getProperty(properties.includeStopFile) == "") {
    onCommand(COMMAND_COOLANT_OFF);

    // Stop the spindle BEFORE the return traverse, not after. On the default hobbyist configuration
    // (Manual Spindle On/Off) COMMAND_STOP_SPINDLE is not an M5 -- it is an M0 prompt asking the
    // operator to switch a hand-switched router off. Emitted after the move, the file sent the tool
    // diagonally across the whole part at travel speed with the router still turning and only then
    // asked for it to be stopped. Prompting first means the operator switches off, resumes, and the
    // machine parks. See docs/HReview.md CR-6.
    //
    // NOTE what the "Work" answer below deliberately does NOT do: it emits no Z retract before its
    // X0 Y0 move. For milling the last operation's own end-of-toolpath retract covers it, and the
    // move is short -- it goes to the last part's own origin, so the tool is already there. A jet
    // section that ends at cutting height is not covered -- that is the open half of CR-6 and the
    // same line of code as HR-16. The "Machine" answer retracts because it crosses the bed -- but
    // only where the job established a fixed Z reference to retract in (parkCanRetract()); with
    // none it warns in the file instead, which is the same HR-16 state reached down a second path.
    // writeMachineParkXY() owns both and says why.
    onCommand(COMMAND_STOP_SPINDLE);

    // Which X0 Y0 -- the question this control could not previously answer. "Work" is the last
    // section's WCS, which on a multi-part job is whichever fixture Fusion ordered last; "Machine"
    // is the homing corner and is the same physical point for every job. See docs/PReview.md PR-6.
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

      // Marlin/RepRap emitted no program end at all, and nothing ever undid Start()'s M84 S0 --
      // which disables the idle timeout for the whole job so the machine cannot lose position
      // mid-run. With nothing restoring it, every axis stayed energised indefinitely after the job
      // finished: motors and drivers heating for a job that is over. GRBL has neither problem
      // (M30 resets modal state, and there is no equivalent timeout to disable), which is why this
      // reads as a gap in the Marlin branch rather than a design choice.
      //
      // S60 restores a 60 second timeout rather than releasing the motors now. A bare M84 releases
      // immediately, and an unbalanced LowRider gantry with no brake sinks in Z the moment it does;
      // a timeout lets the operator retrieve the part with the axes still held, then releases on
      // its own without anyone having to remember.
      writeComment(eComment.Info, "   Restore stepper timeout");
      writeBlock(mFormat.format(84), sFormat.format(60));

      // M2 ends the program on RepRapFirmware only. Confirmed from firmware source, not by posting:
      //
      // Marlin has never implemented M2. gcode.h's supported-code list jumps M1 -> M3 in both 2.0.x
      // and 2.1.x, and gcode.cpp's M switch has no case 2, so M2 reaches unknown_command_warning()
      // and echoes: echo:Unknown command: "M2". Harmless -- motion is flushed and the spindle is off
      // by this point -- but a spurious error line in the console of every Marlin job. Marlin has no
      // program-end code at all (M30 is "delete SD file" there, which is why it is GRBL-only above),
      // so nothing replaces M2 here: end of file IS the program end on Marlin.
      //
      // RRF gained M2 in 3.5.1 -- "behaves the same as M0". Read from a file it calls
      // StopPrint(normalCompletion), which ends the job and runs the operator's stop.g. On 3.4.x and
      // earlier there is no case 2: RRF tries a /sys/M2.g macro, then reports "Bad command: M2" and
      // carries on -- the same bounded cost as Marlin's echo, so this is not gated on a version.
      //
      // NOTE: stop.g runs AFTER the M84 S60 above, so a stop.g holding a bare M84/M18 releases the
      // steppers at once and defeats the timeout restored here. See docs/HReview.md HR-11.
      if (fw == eFirmware.REPRAP) {
        writeBlock(mFormat.format(2));
      }
    }

    writeComment(eComment.Important, " *** STOP end ***");
  } else {
    loadFile(getProperty(properties.includeStopFile));
    flushMotions();
  }
  // No closing "%" on GRBL either -- see onOpen() and docs/HReview.md HB-2.
}

var forceSectionToStartWithRapid = false;
var sectionComment;
var currentWorkOffset;   // last work offset (WCS) emitted, to suppress redundant output

// Emit the work coordinate system (WCS) for a section.
// GRBL and RepRap/Duet support G54-G59 (RepRap also G59.1-G59.3), so honor the offset
// the user assigned in Fusion. Stock Marlin has no G54-G59 -- this post sets the origin
// with G92 there instead -- so on Marlin we only warn when a non-default WCS was selected
// that we can't honor. currentWorkOffset suppresses re-emitting the same WCS each section.
function writeWCS(section) {
  var workOffset = section.getWorkOffset();
  writeComment(eComment.Debug, " writeWCS: entry workOffset: " + workOffset + " currentWorkOffset: " + (currentWorkOffset == undefined ? "none" : currentWorkOffset));

  // Fusion reports workOffset 0 both when the user left the Setup's Work Offset
  // field at its default and when they explicitly chose the default -- the API
  // can't tell those two cases apart, so 0 always means "use WCS 1".
  if (workOffset == 0) {
    workOffset = 1; // default to the first WCS (G54)
    writeComment(eComment.Info, " writeWCS: workOffset defaulted to: " + workOffset);
  }

  if (fw == eFirmware.MARLIN) {
    if (workOffset > 1 && workOffset != currentWorkOffset) {
      writeComment(eComment.Important, " >>> WARNING: Marlin uses a G92 origin; work offset " + workOffset + "/G" + (53 + workOffset) + " is not supported and is ignored");
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
  // How to establish this added part's origin/Z (probeOnChange = "Subsequent WCS / Part").
  // Each WCS has its own G10-scoped origin; the first part's is set by probeOnStart in
  // writeFirstSection(), so this covers the added parts only (guarded by isTraverse below).
  // Two workflows coexist:
  //   - Pre-set fixture offset (Replicate): "Skip" (use stored X/Z) and "Probe Z" (stored XY,
  //     re-probe Z) -- the post positions to the stored X0 Y0 automatically.
  //   - Jog per-part: "Jog XYZ" / "Jog XY & Probe Z" -- the operator jogs to this part
  //     and the post records the origin there.
  var onChangeMode = getProperty(properties.probeOnChange);
  var canProbe = (tool.number != 0 && !tool.isJetTool());
  writeComment(eComment.Debug, " writeWCS: probeOnChange: " + onChangeMode
    + " previousWorkOffset: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset)
    + " canProbe: " + canProbe);

  // Retract Z to a safe height FIRST, before selecting the new WCS -- the new WCS's Z origin
  // may be unknown, so an absolute Z move there would be unsafe. This fires on EVERY inter-part
  // traverse (any genuine WCS change) so we always reposition / let the operator jog / probe
  // from a known-clear height:
  //  - Fixed Z Reference = Machine Z + "Retract Across Parts" on: one G53 G0 Z<Inter Part Travel Z>.
  //    No frame switch and no register consumed -- the machine frame is already fixed relative to
  //    the bed, which is the property the spoilboard base was reserved to buy.
  //  - Fixed Z Reference = Spoilboard + "Retract Across Parts" on: transit through the base and
  //    clear to the base's Safe Z -- a stable height above the spoilboard that clears fixtures
  //    across parts of differing thickness (retractThroughBaseClearance()).
  //  - Otherwise: retract to the probe Safe Z in the OUTGOING part's frame (whose Z is
  //    established). Guard B blocks the risky no-datum multi-WCS case up front when the feature
  //    is on, so this fallback runs for a deliberate no-datum / feature-off multi-WCS job.
  var base = getReservedBaseWcs();
  var isTraverse = (previousWorkOffset != undefined);   // a genuine inter-part WCS change
  var crossPart = isTraverse && getProperty(properties.spoilboardSafeZAcrossWcs);
  var machineFrame = crossPart && usesMachineZDatum();
  var baseRelative = crossPart && base != 0 && base != workOffset;
  writeComment(eComment.Debug, " writeWCS: retract decision -- fixedZRef: " + getFixedZReference()
    + " machineFrame: " + machineFrame + " baseRelative: " + baseRelative
    + " base: " + base + " C_SafeZAcrossWcs: " + getProperty(properties.spoilboardSafeZAcrossWcs)
    + " isTraverse: " + isTraverse + " workOffset: " + workOffset);
  if (machineFrame) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before traverse");
  } else if (baseRelative) {
    retractThroughBaseClearance();
  } else if (isTraverse) {
    writeComment(eComment.Info, "   Retract to Safe Z before WCS change");
    resetAll();
    rapidMovementsZ(probeSafeZ());
    flushMotions();
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
    // Replicate: auto-position to the stored X0 Y0 (plus probe XY offset) and probe Z. After the
    // switch the tool is still over the PREVIOUS part's XY, so partProbe() travels there first
    // (X/Y only -- Z stays safe); XY comes from this WCS's pre-set offset, not re-zeroed.
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

// Persists the current position as WCS wcsNumber's own origin. Any of x/y/z may
// be undefined to leave that axis alone. On GRBL/RepRap this writes directly
// into that WCS's own offset register (G10 L20 P<n>), so it can't leak into any
// other WCS. Marlin has no addressable per-WCS register (no
// CNC_COORDINATE_SYSTEMS assumed here), so it falls back to G92 -- a single
// global origin, the only mechanism stock Marlin has.
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

// The job's FIXED Z REFERENCE -- "None" | "Spoilboard" | "Machine Z". See
// docs/conventions.md "Frames": the concept is a frame whose Z0 does not move with
// stock thickness, and the two answers are two implementations of that one frame, not two
// features. Every consumer below asks this question rather than asking whether a base is reserved.
function getFixedZReference() {
  return getProperty(properties.spoilboardFixedZRef);
}

// True when the fixed Z reference is the machine's own homed Z frame, addressed with G53.
// Deliberately does NOT test the X/Y declaration: a Z-only G53 move needs machine Z trustworthy and
// nothing else. The homed-XY requirement sits on the multi-part workflow the clearance serves, not
// on the move, so it is enforced once in validateJob() and never carried in the emission path.
function usesMachineZDatum() {
  return getFixedZReference() == "Machine Z";
}

// The group-4 declaration, split back into the two axis questions every consumer actually asks.
// ONE enum in the dialog because the operator declares a MACHINE and its four states are exactly
// the four combinations; two predicates here because the machine-Z datum needs Z and the
// stored-offset guard needs X/Y, and neither implies the other. Nothing else may read the property
// directly -- an "== XYZ" test anywhere would silently exclude the single-axis answers.
function machineHomesXY() {
  var declared = getProperty(properties.machineHomedAxes);
  return declared == "XY" || declared == "XYZ";
}
function machineHomesZ() {
  var declared = getProperty(properties.machineHomedAxes);
  return declared == "Z" || declared == "XYZ";
}

// The group-4 ACTION, split into the two questions its consumers ask. Unlike the axis declaration
// above, this enum is NOT information-identical to the two booleans it replaced: those expressed
// four states of which only three were distinct, because "Prompt Before Home" was inert whenever
// homing was off and said so in its own tooltip. Collapsing them deletes the meaningless state
// rather than renaming it -- the dialog can no longer be set to a combination that does nothing.
function homesAtJobStart() {
  return getProperty(properties.machineHomeAtStart) != "Off";
}
function promptsBeforeHome() {
  return getProperty(properties.machineHomeAtStart) == "Pause & Home";
}

// The reserved spoilboard base as a workOffset number (1-6 = G54-G59,
// 7-9 = G59.1-G59.3), or 0 when the spoilboard is not the job's fixed Z reference. The
// spoilboardBaseReserve enum ids are the numbers directly, so this also validates the raw value.
// Gated on the Fixed Z Reference answer, which is what makes "Reserved WCS" a sub-question rather
// than a second, independent switch -- validateJob() refuses the two inconsistent combinations
// outright, so no configuration reaches here with a base named but silently dropped.
function getReservedBaseWcs() {
  if (getFixedZReference() != "Spoilboard") return 0;
  var v = getProperty(properties.spoilboardBaseReserve);
  if (v == "None") return 0;
  return parseInt(v, 10);
}

// "Inter Part Travel Z" as a Number in MILLIMETRES, or undefined when the field is empty or does
// not parse as a signed decimal.
//
// FRAME-FREE: this parses the number, and "Fixed Z Reference" decides what it means -- a height
// above the probed spoilboard, or an absolute machine Z. Signed under both, because the machine
// answer needs it and the spoilboard answer's sign test belongs in validateJob() rather than here:
// a negative under that answer is most likely a machine-frame height left behind by an enum flip,
// which deserves an error naming the cause, not an indistinguishable "unset".
//
// It is a STRING property, not a numeric one, and that is forced rather than chosen: Fusion's
// property schema gives a numeric field no way to be unset -- it always holds a value -- so "empty"
// is not expressible there and every sentinel is a real height in a signed machine frame, 0 very
// much included. Empty meaning unset follows the "Safe Z" precedent of a parsed string property,
// and once one field serves two frames it is also what makes an enum flip fail LOUD instead of
// reinterpreting the previous frame's number as a height in the new one.
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

// True when the job ESTABLISHES its fixed Z reference during the preamble, so an absolute Z move is
// meaningful before any part's own origin exists. Both implementations qualify and neither is
// available on Marlin. This is the condition partProbe()'s "Unknown Z for XY move." warning is the
// negation of -- with a fixed reference established, the first section's arrival happens at a known
// clear height and the warning would be false.
function fixedZEstablishedAtStart() {
  return usesMachineZDatum() || getReservedBaseWcs() != 0;
}

// Can the end-of-job machine park retract before it crosses the bed? Only into a frame this job
// established, which is the fixed Z reference and nothing else -- and on MARLIN neither
// implementation is established, so the answer there is always no however the dialog is set:
//   - the machine-Z answer is refused outright by validateJob() (G53 is CNC_COORDINATE_SYSTEMS,
//     off by default);
//   - a reserved base passes every guard on Marlin -- the park's own guard sits above Guard C's
//     Marlin return, and the base's RepRap-slot check sits below it -- but writeBaseEstablish()
//     then skips the base for want of per-WCS registers. Transiting one anyway would select a
//     register the job never wrote, through a G54-G59 that is itself a Marlin build option, and for
//     a G59.1-G59.3 base wcsGcode() returns undefined and the block would carry a malformed G word.
// Read by validateJob()'s warning and by writeMachineParkXY(), so the two cannot drift apart.
function parkCanRetract() {
  return fw != eFirmware.MARLIN && fixedZEstablishedAtStart();
}

// Human-readable G-code name for a workOffset number, for comments/errors.
function wcsName(n) {
  return n <= 6 ? ("G" + (53 + n)) : ("G59." + (n - 6));
}

// Numeric G-code for a work offset: 1-6 -> 54-59 (G54-G59), 7-9 -> 59.1-59.3 (G59.1-G59.3).
// Returns undefined if out of range for the firmware (the G59.x slots are RepRap-only);
// callers report the error. Shared by writeWCS() and the base-clearance transit.
function wcsGcode(workOffset) {
  if (workOffset <= 6) return 53 + workOffset;
  if (fw == eFirmware.REPRAP && workOffset <= 9) return 59 + (workOffset - 6) / 10;
  return undefined;
}

// The ONE machine-frame move this post emits: a rapid to the declared "Inter Part Travel Z",
// addressed absolutely with G53. Available only under Fixed Z Reference = Machine Z, whose guards
// in validateJob() have already established that the machine homes Z, that this job homed it, that
// the height parses, and that the firmware is not Marlin.
//
// Two conditions come from G53's own definition rather than from anything here:
//   - G53 "is not modal and must be programmed on each line" (LinuxCNC G-code reference; RRF states
//     the same), so every block needing the machine frame carries its own G53. Nothing may be
//     appended to this block later, and a future X/Y park must be a SECOND G53 block, not a
//     three-axis diagonal.
//   - "It is an error if G53 is used without G0 or G1 being active", so the G0 is written through
//     gFormat, NOT gMotionModal: the modal would suppress the word exactly when G0 is already
//     active -- the common case, and the one that would post an invalid block.
//
// resetAll() and gMotionModal.reset() after it, because the tracked X/Y/Z/F and the tracked motion
// mode are all work-frame bookkeeping that a machine-frame move invalidates: without the reset the
// next absolute work-frame Z could be modal-suppressed against a number that no longer describes
// where the tool is.
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

// Park at the machine's own X0 Y0 -- the homing corner -- as the last motion of the job. Two
// firmware routes, and they are not the same KIND of operation, which is why the guard on this
// feature is firmware-dependent where the machine-Z datum's is a flat exclusion:
//
//   - GRBL / RepRap: "G53 G0 X0 Y0". An absolute rapid that ADDRESSES a frame the job must already
//     have established, hence validateJob() requiring "Home at Job Start" there. G53 is not modal
//     so this is its own block, and it is X/Y ONLY -- a three-axis G53 would be the diagonal that
//     writeMachineTravelZ() and this post's rapid splitting both exist to avoid.
//   - Marlin: "G28 X / G28 Y". G53 is gated behind CNC_COORDINATE_SYSTEMS (off by default), so the
//     machine frame cannot be addressed -- but it can be RE-ESTABLISHED, which reaches the same
//     physical corner with no build option and no arithmetic. Being the homing itself, it is
//     self-establishing and needs no prior "Home at Job Start"; it is also a homing cycle rather
//     than a rapid, so it is slower and runs the axes onto the endstops.
//
// Arithmetic is NOT a third route on Marlin. The part origin is written with G92 at whatever
// position the tool happened to occupy (writeWcsOrigin()), so the work frame differs from the
// machine frame by an offset the post never knew and cannot read back -- see docs/conventions.md
// "Selection is deterministic, origin is trusted". Work X0 Y0 and machine X0 Y0 coincide on Marlin
// only BEFORE that G92, which is to say never, by the time this runs.
function writeMachineParkXY() {
  // Retract before crossing the bed. This move goes to the home corner from wherever the last
  // operation ended -- potentially a full diagonal, and on Marlin at homing feedrate with a
  // bump-and-retry at the switch. Only a job that ESTABLISHED a fixed Z reference can retract at
  // all -- parkCanRetract(), which is where the Marlin exclusion lives and why it is not repeated
  // here. Without one there is no frame in which an absolute Z is meaningful, and the job travels
  // at the current Z: the state HReview.md HR-16 describes, which this does NOT fix and therefore
  // must not pass over in silence. validateJob() carries the same warning to Fusion's dialog.
  //
  // Deliberately NOT applied to the "Work" answer, and the reason is the distance rather than
  // timidity: that park goes to the LAST part's own origin, so the tool is already at that part
  // and the move does not cross the bed. See docs/PReview.md PR-6.
  if (!parkCanRetract()) {
    writeComment(eComment.Important, " >>> WARNING: no retract before parking at machine X0 Y0 --"
      + (fw == eFirmware.MARLIN && getReservedBaseWcs() != 0
          ? " the reserved spoilboard base was not established on Marlin, so there is no frame to"
            + " retract in;"
          : " this job establishes no fixed Z reference;")
      + " the tool crosses the bed at whatever Z the last operation left it at");
  } else if (usesMachineZDatum()) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before parking");
  } else {
    // A base is reserved AND was established -- parkCanRetract() has already excluded Marlin, the
    // one firmware where writeBaseEstablish() emits nothing and this transit would select a
    // register the job never wrote.
    //
    // R1 -- never leave the base active. retractThroughBaseClearance() leaves it selected for a
    // caller that is about to choose a destination WCS; this caller has no destination, so it
    // restores the operating WCS itself. Job end is not an excuse: the selection is modal state
    // the sender keeps, and the operator's next manual move would be made in the base's frame.
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
  // The F word is not optional here even though this is a G0. Every other rapid in the post carries
  // one (rapidMovementsXY/Z, and writeMachineTravelZ on the sibling G53 block), because on firmware
  // that honours the modal feedrate for G0 an F-less rapid crosses the bed at whatever feed the last
  // CUT commanded. resetAll() above has just cleared the tracked F, so this is written through
  // fFormat rather than fOutput -- the same reason writeMachineTravelZ() does.
  writeBlock(gFormat.format(53), gFormat.format(0), xFormat.format(0), yFormat.format(0),
    fFormat.format(propertyMmToUnit(getProperty(properties.feedsTravelSpeedXY))));
  resetAll();
  gMotionModal.reset();
}

// Retract to the base's "Safe Z" height measured above the reserved spoilboard base,
// by transiting THROUGH the base WCS. The base's Z was established at job start
// (writeBaseEstablish), so it is the one frame where an absolute safe height is meaningful
// across parts of differing thickness. Selects the base with a plain frame switch -- NOT
// writeWCS(), so it triggers no probeOnChange re-probe and writes no origin -- then
// commands the clearance (a real Z move, so this is never an empty base round-trip). LEAVES
// the base active; the caller selects the destination WCS next. Caller guarantees a base is
// reserved. See docs/conventions.md "Base WCS is transited, not parked".
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

// A 3-axis section can still be ORIENTED off machine +Z -- a Setup built on a model face rather
// than on the stock top, which is an easy accident in Fusion. isMultiAxis() does not catch it:
// Fusion emits ordinary X/Y/Z words for such a section, so with no guard the post emits them as
// though the frame were upright, the part is cut in the wrong plane, and nothing in the file says
// so. Every reference 3-axis post rejects this. See docs/HReview.md HR-6.
//
// Returns true when the section may proceed; returns false AFTER raising the error when the
// section's Z axis is readable and unambiguously not the machine Z.
//
// Written to FAIL OPEN, deliberately. A false positive here would abort EVERY job -- far worse
// than the rare misconfiguration it catches -- and this is the post's first use of
// Section.workPlane, so the shape of that object is not yet evidenced by a posted file. The
// check therefore errors only when the orientation is readable AND unambiguously not +Z;
// anything unreadable (no workPlane, no forward vector, non-numeric components) is treated as
// upright and posts exactly as before. Nothing in here may throw -- that is the one hard
// requirement, and it is why every branch concatenates rather than computes.
//
// Compared component-wise rather than with the kernel's isSameDirection(): that would add a
// second unverified global to a guard whose one hard requirement is that it must not throw, and
// the comparison costs a line either way. The tolerance is about 0.006 degrees of tilt -- orders
// of magnitude beyond any float noise in a rotation matrix, and far below any orientation a user
// would pick on purpose (the near-miss case posts, and cuts correctly).
//
// The Debug trace is emitted on EVERY path, not just the rejection. Because the guard fails open,
// "read +Z and allowed it" and "read nothing and gave up" otherwise produce byte-identical files,
// and the second means this guard is dead code. One Debug-level post now evidences which happened,
// and names the reason when the orientation could not be read.
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

  // Tilt from machine +Z, for the trace only. Clamped because a non-unit or noisy vector can push
  // the value outside acos()'s domain; NaN components fall through as "NaN", which is itself the
  // diagnosis (they are a fail-open case -- typeof NaN is "number", but no comparison above matches).
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
  // Multi-axis toolpaths aren't supported (only 3-axis / 2D-jet). Fail at the start of
  // the offending operation with a clear message, rather than partway through its motion
  // (onLinear5D/onRapid5D also guard, as a backstop).
  if (currentSection.isMultiAxis()) {
    error(localize("Multi-axis toolpath is not supported. Use a 3-axis milling or 2D/jet strategy."));
    return;
  }

  // A 3-axis section can still be oriented off machine +Z; the check and its Debug trace live in
  // isSectionOrientationSupported(). It has already raised the error when it returns false.
  if (!isSectionOrientationSupported()) {
    return;
  }

  // Every section needs to start with a Rapid to get to the initial location.
  // In the hobby version Rapids have been elliminated and the first command is
  // a onLinear not a onRapid command. This results in not current position being
  // that same as the cut to position which means wecan't determine the direction
  // of the move. Without a direction vector we can't scale the feedrate or convert
  // onLinear moves back into onRapids. By ensuring the first onLinear is treated as 
  // a onRapid we have a currentPosition that is correct.

  forceSectionToStartWithRapid = true;

  // Write Start gcode of the documment (after the "onParameters" with the global info)
  if (isFirstSection()) {
    writeFirstSection();
  }

  writeComment(eComment.Important, " *** SECTION begin ***");

  // sectionComment is only ever assigned from onParameter("operation-comment"), which Fusion does
  // not send for an operation with no comment. onSectionEnd() clears it so this section cannot
  // inherit the PREVIOUS one's name in its header and on the LCD; that leaves undefined on the
  // first section, which used to print literally. See docs/HReview.md CR-17 (e).
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

  // Select the work coordinate system (WCS on GRBL/RepRap; warn-only on Marlin).
  // This is the later-section half of the deliberate WCS-selection split: section 1
  // already selected here inside writeFirstSection() (it had to run before that section's
  // origin write -- see the phase-order note on writeFirstSection()), so re-selecting for
  // the first section would be redundant. Every later section selects its WCS here.
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
        // Leave the power DEFINED. Every other branch sets cutterOnCurrentPower; falling through
        // without it made laserOn() compute "undefined * 10" and emit S NaN -- or, after an earlier
        // section had set it, silently reuse THAT section's power, which looks plausible and is not.
        // Only the three mapped modes exist in Fusion today, so this guards a future enum value
        // rather than a live failure, which is exactly why it must not be left producing NaN.
        // Through is the conservative middle setting.
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

// Called in every section end
function onSectionEnd() {
  resetAll();
  // Clear the operation name so the next section cannot inherit it. Fusion sends
  // onParameter("operation-comment") for the next section AFTER this callback, so an operation with
  // no comment leaves whatever was last set -- naming this section's toolpath in the next one's
  // header and on the LCD. onSection() substitutes a placeholder when nothing arrives.
  sectionComment = undefined;
  writeComment(eComment.Important, " *** SECTION end ***");
  writeComment(eComment.Important, "");
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

  // Marlin/GRBL/RepRap have no G41/G42 cutter compensation, so control-side
  // compensation can't be honored. Fail early with an actionable message; the
  // supported mode is "In computer" (Fusion pre-offsets the centerline).
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
  // If we are allowing Rapids to be recovered from Linear (cut) moves, which is
  // only required when F360 Personal edition is used, then if this Linear (cut)
  // move is the first operationin a Section (milling operation) then convert it
  // to a Rapid. This is OK because Sections normally begin with a Rapid to move
  // to the first cutting location but these Rapids were changed to Linears by
  // the personal edition. If this Rapid is not recovered and feedrate scaling
  // is enabled then the first move to the start of a section will be at the
  // slowest cutting feedrate, generally Z's feedrate.

  if (getProperty(properties.mapRapidsRestoreFirstRapids) && (forceSectionToStartWithRapid == true)) {
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

// Is the current operation a WCS / inspection PROBING operation (Fusion's probe strategies), as
// opposed to an ordinary drill / bore / tap cycle? Only onCyclePoint() below asks.
//
// Defined locally on purpose. In the Autodesk reference posts `isProbeOperation()` is a post-local
// helper, not a kernel global, so calling it without a definition made the whole canned-cycle path
// depend on whether this kernel revision happens to supply one -- and if it does not, the first
// drilled hole in a job aborts the post with a bare ReferenceError and no file. Defining it here is
// harmless if the kernel also provides one, and drilling is a routine hobbyist operation.
//
// Two independent signals, because either alone can miss one. The operation STRATEGY names the
// probing operation as a whole; the CYCLE TYPE names the individual cycle at each point
// ("probing-x", "probing-xy-outer-corner", ...). Every probing cycle type is prefixed "probing", so
// the prefix test needs no per-cycle list to stay current across Fusion versions. `cycleType` is a
// kernel global set for the duration of a cycle -- guarded with typeof so this stays safe if it is
// ever absent.
function isProbeOperation() {
  if (hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe")) {
    return true;
  }
  return (typeof cycleType != "undefined") && (String(cycleType).indexOf("probing") == 0);
}

// Drilling / canned cycles.
// None of the supported firmwares handle G81/G82/G83 canned cycles as drilling:
// GRBL has no canned cycles, Marlin only supports them in an opt-in custom build
// (CNC_DRILLING_CYCLE, non-standard params), and RepRap/Duet reuse those codes for
// mesh/probe/babystep functions. So every cycle point is expanded into ordinary
// G0/G1 plunge-and-retract moves (via the existing onRapid/onLinear/onDwell paths),
// which run identically on all three firmwares.
function onCyclePoint(x, y, z) {
  // WCS/inspection probing can't be faked by expansion (it would emit plain G0/G1
  // moves with no actual G38 probe), so reject it clearly instead of silently
  // producing non-probing motion. (This post's own Z touch-off is separate; see probeTool.)
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
        // F360 doesn't support coolant with jet tools (water jet/laser/plasma) but we've
        // added a parameter to force a coolant to be selected for jet tool operations. Note: tool.coolant
        // is not used as F360 doesn't define it.

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
      // Marlin/GRBL/RepRap have no rigid-tapping/spindle-sync capability (no G33), so this
      // is a deliberate no-op: the tap feed F360 calculated already assumes a constant
      // spindle RPM, and a floating/tension tap holder is needed to absorb any timing drift.
      // Warned every occurrence (not just once) so every affected move in the file is flagged.
      writeComment(eComment.Important, " >>> WARNING: Speed-feed synchronization (rigid tapping) is not supported; a floating/tension tap holder is required");
      return;
    case COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION:
      writeComment(eComment.Important, " >>> WARNING: Speed-feed synchronization (rigid tapping) is not supported; a floating/tension tap holder is required");
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

  // Display every post property, grouped, plus the values that are resolved rather than
  // stored. The two hand-written blocks this replaced (Feedrate/Scaling and G1->G0 Mapping)
  // are covered by their own groups below.
  writeAllProperties();
  writeResolvedValues();

  writeComment(eComment.Info, " ");
}

// Dump EVERY post property as Info comments, one block per dialog group. The point is that a
// posted file should carry the settings that produced it, so reviewing it -- by eye or by an
// automated/AI pass -- never means inferring the configuration from the motion (and a negative
// like "no base was reserved" can be read directly instead of guessed from an absence).
//
// Iterates the `properties` object rather than listing keys, so a newly added property is dumped
// automatically and this can't drift out of date. Values print as the STORED form: an enum shows
// its `id`, not its display title, so the dump stays stable across dialog relabelling (the ids
// outlived two rounds of retitling already).
// groupDefinitions lookups, both tolerant of a group key with no definition -- see the sort note in
// writeAllProperties().
function groupOrder(key) {
  var def = groupDefinitions[key];
  return ((def != undefined) && (def.order != undefined)) ? def.order : 9999;
}

// A property's own `order:` -- the within-group counterpart. Same fallback: an unnumbered property
// sorts last rather than disappearing into the middle of a group.
//
// Unlike the group-level field, property `order:` is NOT in the Post Processor Guide's table of property
// members; factory grbl.cps uses it regardless (order: 1/2/3 on its sequence-number trio). Depending on
// it is additive: if the dialog ignores it, the dialog falls back to its own sort and only this dump --
// which sorts on it directly -- is affected.
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
  // on, so the dump keeps reproducing the dialog's order now that `group:` is an opaque key instead
  // of a sortable padded title. Within a group it is each property's own `order:`, for the same
  // reason: the key no longer carries the sequence, so nothing else could reproduce it. A group with
  // no groupDefinitions entry (a typo in a new property's `group:`) is not dropped: it sorts last and
  // prints its raw key as the heading, so the slip shows up here.
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

// Values a reviewer needs that are NOT any property's stored value -- either resolved from an
// expression, converted to output units, or supplied by Fusion rather than the dialog. Without
// these the dump is misleading: "probeSafeZ = Retract:15" does not tell you the retract
// actually resolved to 5.08 for this operation.
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
  // Echoed only under an answer that reads it, and echoed WITH ITS FRAME NAMED: one field now means
  // two unrelated numbers and the frame is decided by another control, so this line is what makes an
  // enum flip visible in the posted file. It is also the last line of defence against a mistyped
  // absolute machine height -- the operator reads back, in the units the G53 block will actually
  // carry, the number the tool is about to travel to. A G53 move is interpreted in the active
  // G20/G21 units -- "G53 G0 Z-12" in an inch file means -12 INCHES -- and GRBL's $13 can switch
  // position REPORTING to inches too, so the number read off the DRO may not have been mm either.
  // The dialog is mm by contract; this line is where that lands.
  if (getFixedZReference() != "None") {
    writeComment(eComment.Info, "   Inter Part Travel Z in output units = "
      + xyzFormat.format(interPartTravelZ())
      + (usesMachineZDatum() ? " -- absolute machine Z"
                             : " -- above the spoilboard base " + wcsName(base)));
  }
}

// Implements the group-4 machine-frame controls: establishes the machine frame (MCS) at job start,
// once, before anything work-relative.
//
// Capability and action are SEPARATE properties, and only the action is emitted here. "Axes
// Homed and Trusted" is a declaration -- a fact about the machine, set once -- read by
// validateJob() and by the Machine Z fixed reference; "Home at Job Start" is the job's decision to
// act on them. The enum they replaced collected an operation where every consumer needed a
// capability: it emitted G28 Z for mode XYZ and then discarded the fact that the machine HAS a
// homed Z, so an operator whose machine had a perfectly good fixed Z frame was still required to
// reserve a WCS register and probe a spoilboard to reconstruct it. The split also expresses a state
// the enum could not -- Z endstops exist and were homed at the controller, but do not home them in
// this job.
//
// What homing is FOR is unchanged: X/Y homing gives MCS a repeatable origin (plus gantry squaring),
// and Z homing, where wired, gives a travel datum. Neither ever becomes the everyday CUTTING
// reference, which stays the work-Z touch-off (probeOnStart / probeOnChange) regardless.
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

  // Asking for the action with nothing declared homeable is a configuration that cannot be
  // satisfied, not a no-op worth passing over in silence: the operator believes the job homes.
  // Not an error() -- it costs no safety on its own, and the guards refuse the case where it does.
  if (!homeXY && !homeZ) {
    writeComment(eComment.Important, " >>> WARNING: \"Home at Job Start\" is on but \"Axes Homed"
      + " and Trusted\" is None -- nothing was homed");
    return;
  }

  // The "Pause, then Home" answer: a single stop before ANY homing motion, letting the operator
  // prepare the machine (place a movable Z-homing plate, clear the bed, etc.). Independent of
  // firmware and of which axes home, so it never needs revisiting when the machine changes. It is
  // an answer to this control rather than a control of its own because it was never meaningful on
  // its own: as a separate boolean it was inert whenever homing was off.
  if (promptsBeforeHome()) {
    writeComment(eComment.Debug, " writeMachineHoming: pausing before homing (Pause, then Home)");
    askUser("Prepare machine for homing", "Homing", false);
  }

  if (fw == eFirmware.GRBL) {
    // On stock GRBL the capability split is BOOKKEEPING, NOT EMISSION, and the post cannot pretend
    // otherwise: which axes $H homes is fixed at COMPILE time by HOMING_CYCLE_0/1/2 in
    // grbl/config.h (default Z first, then X|Y), and the per-axis $HX/$HY/$HZ commands sit behind
    // HOMING_SINGLE_AXIS_COMMANDS, which is disabled by default. So one $H is all this can emit,
    // and there is nothing to corroborate the declaration against either. (A no-Z-endstop machine
    // running GRBL has necessarily already recompiled its homing cycle -- the stock default would
    // try Z first.) FluidNC is the exception: it exposes single-axis homing as configuration, so
    // $HX / $HZ are available there without a rebuild, and this post's treating FluidNC as GRBL
    // throughout is what costs the distinction. See docs/conventions.md "Frames".
    writeComment(eComment.Debug, " writeMachineHoming: GRBL/FluidNC, emitting single combined $H"
      + " (declared X/Y: " + homeXY + " Z: " + homeZ + " -- the build's homing cycle decides)");
    // writeln(), NOT writeBlock(). writeBlock() prefixes an N word when "Enable Line #s" is on, and
    // GRBL only recognises a $ system command when $ is the first character of the line -- "N10 $H"
    // is handed to the g-code parser instead, which has no word letter $, so the controller errors
    // and the sender halts on the first motion line of the preamble. $H is not a g-code block and
    // takes no line number. It is now the only raw controller string this post writes -- the GRBL
    // "%" wrappers in onOpen()/onClose() used writeln() for the same reason and are gone (HB-2).
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

// Job preamble: everything emitted once, before any section's cutting body. Called
// once from onSection() when isFirstSection() is true. Fixed phase order, each step
// depending on the one before:
//   1. writeInformation()   -- file header block (top of file)
//   2. writeMachineHoming()  -- establish MCS (home / accept power-on), before anything
//                               work-relative
//   3. writeWCS()            -- select the first section's WCS
//   4. Start() / start file  -- units, absolute mode, spindle init
//   5. writeFixedZReference() -- establish the job's fixed Z reference (needs 4's units)
//   6. writeWcsOnStart()     -- probeOnStart: the initial origin for the WCS from 3
// Only step 3 (writeWCS) is not intrinsically first-section work -- every section selects
// its WCS. It lives here because steps 4-6 may write an origin on top of the active WCS,
// so the WCS must be selected first. That is the deliberate reason WCS selection is split:
// section 1 selects here (mid-preamble, before its origin write); every later section
// selects in onSection()'s body. See the matching note at the writeWCS() call there.
function writeFirstSection() {
  // Write out the information block at the beginning of the file
  writeInformation();

  // Establish the machine frame (MCS) before anything work-relative -- home the declared axes
  // (or accept the current position) per the group-4 controls.
  writeMachineHoming();

  // Select the WCS before Start()/includeStartFile and writeWcsOnStart() below --
  // both may set an origin on top of the active WCS, so the WCS must be
  // selected first or the origin would land on the wrong one (either a stale
  // WCS left active by a prior job, or the controller's default).
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

// Step 5 of writeFirstSection(): establish the job's fixed Z reference, in whichever of its two
// implementations the operator chose. Both leave the tool holding a height that clears everything
// on the bed, measured in a frame that does not move with stock thickness -- which is the whole
// point of the concept and the reason this runs before the first part's own origin: whatever this
// leaves the tool at is the height the travel to the first part's X0 Y0 starts from.
//
// This is what lifts a hard limit the post used to carry. With no fixed reference there is no
// established frame at job start at all, so the first section's arrival cannot be made safe and
// gets an Info comment instead of a move (partProbe()'s zUnknown path). A declared machine Z IS an
// established frame at job start, so that path now emits a real absolute Z on a machine that
// declares one -- a safety improvement, not a convenience. See docs/conventions.md
// "Why the first section's arrival is asymmetric".
function writeFixedZReference() {
  var ref = getFixedZReference();
  writeComment(eComment.Debug, " writeFixedZReference: " + ref);

  if (ref == "Spoilboard") {
    writeBaseEstablish();
  } else if (ref == "Machine Z") {
    if (fw == eFirmware.MARLIN) {
      // Unreachable via the dialog -- validateJob() refuses this combination before any output.
      // Kept so the function is safe to call from anywhere, not because a job can arrive here.
      writeComment(eComment.Important, " >>> WARNING: Fixed Z Reference = Machine Z ignored on Marlin");
      return;
    }
    writeComment(eComment.Important, " Establish fixed Z reference -- homed machine Z");
    writeMachineTravelZ("Move to the travel height in the machine frame");
  }
}

// The SPOILBOARD implementation of the fixed Z reference (spoilboardBaseReserve /
// spoilboardBaseEstablish): at job start, establish the reserved base WCS's Z by probing (writing
// G10 L20 P<base>). Called only from writeFixedZReference(), and a no-op when no base is reserved,
// so a default job emits nothing here. The base is a per-WCS register concept, so it is skipped
// with a warning on Marlin (single global frame, no P<n> registers).
function writeBaseEstablish() {
  var base = getReservedBaseWcs();
  if (base == 0) {
    writeComment(eComment.Debug, " writeBaseEstablish: no base reserved (None), nothing emitted");
    return;
  }

  var gname = wcsName(base);

  if (fw == eFirmware.MARLIN) {
    writeComment(eComment.Important, " >>> WARNING: reserved base " + gname + " ignored on Marlin (no per-WCS registers; single global frame)");
    return;
  }

  // "Probe to Set Base" no longer offers a "None -- assume a prior job set it" option, and its
  // removal is a defect fix rather than a simplification. That base Z0 is an offset from MACHINE
  // zero, so on a machine with no Z home a controller reset or power cycle invalidated it
  // SILENTLY: machine zero moved, the register did not, and the tool then descended to a clearance
  // wrong by however far it drifted with nothing in the file saying so. Its one durable use -- a
  // machine that homes Z -- now has a strictly better answer in Fixed Z Reference = Machine Z,
  // which consumes no register, needs no probe, and cannot go stale in the same way because the
  // job homes. See docs/PReview.md E1.
  var mode = getProperty(properties.spoilboardBaseEstablish);   // "Probe Z" | "Pause & Probe Z"

  if (tool.number != 0 && !tool.isJetTool()) {
    // OPERATOR PRECONDITION -- the base is probed WHEREVER THE TOOL ALREADY SITS. No XY move is
    // emitted here (deliberately: this runs before any origin is established, so there is no frame
    // in which an XY target would be trustworthy, and the base's own X0 Y0 may never have been
    // set). Consequently the surface under the tool at job start BECOMES the base's Z0 -- park
    // over bare spoilboard, clear of the stock and clamps, or the "spoilboard base" silently
    // records the stock top and every clearance derived from it is short by the stock thickness.
    // The probe XY offset is never applied here (see probeOffsetX/Y).
    writeComment(eComment.Important, " Establish spoilboard base " + gname);

    // Do the base's Z work in the BASE's own frame. G10 L20 writes a register without selecting
    // it, so without this select the base's G38.2 target and -- the part that matters -- its
    // post-probe retract would both be measured against the OPERATING WCS, whose Z is still
    // whatever a prior job left there. Selecting the base makes the retract mean what the Inter
    // Part Safe Z tooltip claims: a height above the spoilboard, valid regardless of stock
    // thickness. The tool holds that physical height through the restore below, so the first
    // part's travel to its X0 Y0 starts from a known-clear Z.
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
    // Retract to the Inter Part Travel Z, not the probe Safe Z -- see probeTool()'s retractZ note.
    // Reached only under Fixed Z Reference = Spoilboard, so the height is in the base's own frame.
    probeTool(base, interPartTravelZ());

    // R1 -- never leave the base active. Restore the operating WCS before anything that depends
    // on it: the first part's origin write / "Use Active WCS" travel (writeWcsOnStart) and the
    // section's cutting. The reselect moves nothing, so the cleared Z carries over.
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

// Part-probe XY offset (probeOffsetX / probeOffsetY), in output units. The Z-probe
// touch-point for a PART is its WCS origin plus this offset, so the origin can sit at a
// corner / off the material while Z is read on the stock top. Applied to the first part
// (probeOnStart) and each added part (probeOnChange) only -- NOT to the spoilboard
// base probe, which emits no XY move of any kind: it touches off wherever the tool already
// sits when writeBaseEstablish() runs. See that function's note on what the operator must
// therefore guarantee.
function probeOffsetX() { return propertyMmToUnit(getProperty(properties.probeOffsetX)); }
function probeOffsetY() { return propertyMmToUnit(getProperty(properties.probeOffsetY)); }

// True when a part probe touches off somewhere other than the part origin, i.e. when the XY offset
// creates a traverse. Read by partProbe() and by the first-part "... Current Pos" path, which must
// retract before that traverse -- one definition so the two cannot disagree about when it happens.
function probeOffsetIsSet() { return probeOffsetX() != 0 || probeOffsetY() != 0; }

// Operator-pause spec the next probeTool() honors: whether to prompt the operator to attach
// the Z probe (before) and detach it (after). Both default true -- the historical behavior,
// and what the tool-change re-probe uses. A caller (part probe / base establish) sets these
// just before invoking the probe; probeTool() reads them and then restores the true/true
// default so the next probe is unaffected.
var probePauseBefore = true;
var probePauseAfter = true;

// A part probe: position to the part's Z-probe touch-point (its WCS origin plus the probe XY
// offset) and probe Z into the active WCS via COMMAND_TOOL_MEASURE. `atOrigin` = the tool is
// already sitting on the origin (the first/only part, whose origin is the current position):
// the reposition is then emitted only when the offset is non-zero, so a zero-offset job stays
// byte-identical. Added parts pass false -- the tool is over the previous part, so it always
// travels to the probe point (the bare origin when the offset is zero). Callers guard tool 0 /
// jet tools. The attach/detach prompts follow probePause. The spoilboard base probe does
// NOT use this -- it always touches off at the origin, with its own pause setting (see
// writeBaseEstablish).
// `zUnknown` (optional, default false) = the caller emitted no absolute Z move before this probe
// because the active frame's Z0 is stale, so the traverse below runs at whatever height the tool
// already holds; see the warning comment inside. Only the first-part "Probe Z" mode passes true --
// every other caller reaches here at a retracted, known height.
function partProbe(atOrigin, zUnknown) {
  var ox = probeOffsetX();
  var oy = probeOffsetY();
  var offsetSet = probeOffsetIsSet();
  if (!atOrigin || offsetSet) {
    resetAll();
    // The rapid below is at an unknown height and, on the first-part path, is the program's first
    // motion -- so no absolute Z move can precede it and the file must say so instead, for both the
    // operator and an automated review. Suppressed when the job's fixed Z reference was established
    // in the preamble and has already left the tool at a known-clear height: a probed spoilboard
    // base (base frame + Inter Part Travel Z), or a homed machine Z (G53 G0 Z<Inter Part Travel Z>).
    // Either way the warning would be false, and on the machine-Z route the arrival is a real
    // absolute move rather than a comment -- the one path in the post that deliberately emitted no
    // absolute Z now has a case where it does not have to.
    if (zUnknown && !fixedZEstablishedAtStart()) {
      writeComment(eComment.Info, "   Ensuring that Z is safe. Unknown Z for XY move.");
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

// Implements the probeOnStart property: establishes the origin for the WCS
// writeWCS() just selected for the first section, scoped to that WCS via
// writeWcsOrigin() (G10 on GRBL/RepRap, G92 on Marlin).
function writeWcsOnStart() {
  var mode = getProperty(properties.probeOnStart);
  var canProbe = (tool.number != 0 && !tool.isJetTool());
  writeComment(eComment.Debug, " writeWcsOnStart: probeOnStart: " + mode + " wcs: " + currentWorkOffset);

  if (mode == "Skip") {
    // "Use Active WCS X0 Y0 Z0": do nothing to the origin -- use the WCS's full stored offset --
    // but still reach its X0 Y0 safely: move Z to the probe Safe Z (milling only), then rapid
    // there. This mode trusts the stored Z, so probeSafeZ() is a meaningful clearance height in
    // that frame. Z is positioned before the XY traverse.
    //
    // Careful with the word "retract": rapidMovementsZ() emits an ABSOLUTE Z, so if the tool is
    // parked above Safe Z -- the top of travel is the natural place to leave it -- this DESCENDS
    // there first, at Z travel speed, over terrain the post knows nothing about. The post cannot
    // fix that (it has no way to read the physical Z, and the premise of this mode is that the
    // stored frame is trusted), so the comment and the property text say "move", not "retract".
    // See HReview.md CR-16; plan.md carries the related open decision for the base-reserved variant.
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
    // "Use Active WCS X0 Y0, Probe Z0": use the WCS's stored X0 Y0 (a pre-set fixture offset)
    // and re-probe Z -- do NOT write XY. Unlike Skip, Z is stale (about to be probed), so we emit
    // no absolute Z move in this frame: the tool is at its safe job-start height (post-home /
    // power-on / spoilboard base probe), partProbe(false, true) travels to the stored X0 Y0
    // (X/Y only) at that height -- warning in the file that the height is unknown -- then probes Z
    // down. XY comes from the WCS offset, not re-zeroed.
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

  // "Jog ..." modes pause (M0) so the operator jogs the tool to the part origin during the run;
  // the "... Current Pos" modes assume a pre-jog before start and record wherever the tool now
  // sits. Both then write the origin identically (the "Current Pos" path stays byte-identical to
  // the pre-rework default output; only the new "Jog" modes emit the prompt).
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
    // Z0 is written PROVISIONALLY here, alongside XY: probeTool() overwrites it with the plate
    // thickness a few blocks below, so it never survives into the cut. Its only job is to give
    // probeG38Target ("G38 Target") the meaning its title claims -- with Z0 at the tool's
    // current height, "G38 Target -10" is a 10 mm travel limit. Written the old way (XY only) the
    // target was an absolute Z evaluated against whatever Z0 a PREVIOUS run persisted into this
    // register, which the post cannot read back: on GRBL the offset survives in EEPROM while an
    // un-homed machine's Z resets at power-on, so the same "-10" could be a 45 mm descent at probe
    // feed, or point upward so the probe never contacts and the controller alarms. No setting of
    // G38 Target could be made reliable while its reference point was unknowable at post time.
    //
    // Sound on these two modes ONLY, because the operator has just put the tool at the origin
    // themselves (pre-jog, or the M0 jog prompt above), so the target is measured from a height
    // they chose. Deliberately NOT applied where the probe starts from a retracted clearance --
    // "Use Active WCS X0 Y0, Probe Z0", the added-part probes, the spoilboard base establish:
    // there the same provisional zero would make the target too TIGHT and turn a working probe
    // into a "did not contact" alarm. See docs/HReview.md HR-1.
    writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
    // The origin is the current position; partProbe() steps to the probe point (origin + XY offset)
    // only when an offset is set -- and that step ran at whatever Z the operator jogged to, which on
    // this mode's own premise is a millimetre over the stock. A 25 mm offset then dragged the bit
    // that far across the work, or into a clamp, before the probe. The sibling "Use Active WCS X0
    // Y0, Probe Z0" path cannot lift (its Z0 is stale, so it prints the unknown-Z warning instead);
    // here the provisional Z0 was just written one line up, so an ABSOLUTE retract is meaningful and
    // is measured from the height the operator chose. Gated on the offset so a zero-offset job --
    // the default -- stays byte-identical. The G38 target keeps its meaning: still a bounded
    // descent, now from probeSafeZ() above the jogged height. See docs/HReview.md HB-4.
    if (probeOffsetIsSet()) {
      writeComment(eComment.Info, "   Retract to Safe Z before the offset traverse");
      resetAll();
      rapidMovementsZ(probeSafeZ());
      flushMotions();
    }
    partProbe(true);
  } else {
    // Tool 0 / jet tool: no probe, so there is no G38 target to bound and nothing for a
    // provisional Z0 to fix -- writing one would silently turn this mode into
    // "Set X0 Y0 Z0 to Current Pos". XY only, unchanged.
    writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
    // ... which leaves Z0 at whatever this register already holds -- on GRBL, persisted in EEPROM by
    // some earlier job -- while the jet section that follows emits ABSOLUTE Z words for its cutting
    // / focus height against that unknown zero. The README documents that a jet tool never probes,
    // but "no probe" is not the same statement as "Z0 is never set", and this is the DEFAULT mode a
    // laser user lands on rather than the "Set X0 Y0 Z0 to Current Pos" the README tells them to
    // pick. Suppressing the origin write is still right (see above); being quiet about it is not.
    // See HReview.md CR-5, and PReview.md J1 / HR-1 (D) for the jet workstream this belongs to.
    writeComment(eComment.Important, " >>> WARNING: a jet tool / tool 0 cannot probe, so Z0 was NOT"
      + " established -- this job runs against whatever Z origin is already stored. Use"
      + " \"Set X0 Y0 Z0 to Current Pos\" for a jet/laser job.");
    writeComment(eComment.Debug, " writeWcsOnStart: probe skipped (tool 0 or jet tool)");
  }
}

// Output a comment
function writeComment(level, text) { 
  if (commentLevels.indexOf(level) <= commentLevels.indexOf(getProperty(properties.jobCommentLevel))) {
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
}

// Rapid movement in X/Y, emitted as G0 at the configured XY travel feedrate.
// Changes F360's current XY position. Called from rapidMovements() for every
// onRapid, and directly for moves like the final return-to-origin.
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

// Rapid movement in Z, emitted as G0 at the configured Z travel feedrate.
// Changes F360's current Z position. Called from rapidMovements() for every
// onRapid, and directly for retracts like the post-probe safe-Z move.
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

// Combined X/Y/Z rapid, emitted as separate G0s (each at its own configured travel feedrate).
// Order the split moves so we never plunge into the part: when Z is descending, position XY
// first and then bring Z down; when Z is rising or unchanged, retract Z first and then move XY.
// (Matches Autodesk's safe initial-positioning pattern: rapid XY above the part, then Z down.)
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

  // Normally F360 begins a Section (a milling operation) with a Rapid to move to the beginning of the cut.
  // Rapids use the defined Travel speed and the Post Processor does not depend on the current location.
  // This function must know the current location in order to calculate the actual vector traveled. Without
  // the first Rapid the current location is the same as the desination location, which creates a 0 length
  // vector. A zero length vector is unusable and so a instead the slowest of the xyLimit or zLimit is used.
  //
  // Note: if Map: G1 -> Rapid is enabled in the Properties then if the first operation in a Section is a
  // cut (which it should always be) then it will be converted to a Rapid. This prevents ever getting a zero
  // length vector.
    if (xyz.length == 0) {
    var lesserFeed = (xyLimit < zLimit) ? xyLimit : zLimit;

    // Never RAISE a feed. The contract (README, "Feeds and feedrate scaling") is that scaling only
    // ever reduces, and with no direction vector the slowest axis limit is a sound ASSUMPTION about
    // what this move might be -- but only as a cap on what was asked for. Returned outright it
    // turned an F100 move into F180 on the defaults. The move is zero length so nothing is cut by
    // it, but F is modal and resetAll() at the previous section end forces the words out, so the
    // wrong feed does reach the file.
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
// configured maximum. Only reduces, never raises, and returns the feed untouched when Scale
// Feedrate is off.
//
// Deliberately NOT the projection limitFeedByXYZComponents() uses. That function projects the
// straight line from the current position to the destination, which for an arc is the CHORD -- and
// on an arc the instantaneous axis velocity is tangential, reaching the full toolpath feed wherever
// the tangent lines up with an axis. A 90-degree arc's chord runs at 45 degrees, so a chord
// projection would report about 0.707 * feed on each axis and pass an arc that hits the full feed on
// X at its own quadrant point: it under-protects by up to 1/cos(45deg). The real constraint on a
// planar arc is just the limit of the axes it sweeps.
//
// Consequence worth knowing: this is CONSERVATIVE for a short arc that never reaches a quadrant
// point (a 10-degree arc around 45 degrees peaks near 0.75 * feed on each axis, so capping at the
// axis limit reduces it more than strictly necessary). That is the right side to err on for a
// machine that cannot hold the feed, and it keeps the rule predictable -- an arc is never faster
// than the axis limit, full stop. It also means a fillet can post slower than the straight moves
// either side of it, which is correct rather than a defect: a diagonal G1 is allowed to exceed the
// per-axis limit precisely because neither axis individually does.
function limitArcFeed(feed) {
  if (!getProperty(properties.feedsScaleFeedrate)) {
    return feed;
  }

  var xyLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedXY));
  var zLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedZ));

  // An XY arc sweeps X and Y only. A ZX / YZ arc (GRBL only -- Marlin/RepRap linearize those, and
  // the linearized moves go through limitFeedByXYZComponents() instead) sweeps one linear axis and
  // Z, so it must satisfy the slower of the two.
  var limit = (getCircularPlane() == PLANE_XY) ? xyLimit : ((xyLimit < zLimit) ? xyLimit : zLimit);

  // Same final cap the linear path applies to its resolved feed.
  var xyzLimit = propertyMmToUnit(getProperty(properties.feedsMaxCutSpeedXYZ));
  if (limit > xyzLimit) {
    limit = xyzLimit;
  }

  return (feed > limit) ? limit : feed;
}

// Linear movements
function linearMovements(_x, _y, _z, _feed) {
  // Note: control-side radius compensation is rejected up front in onRadiusCompensation
  // (Marlin/GRBL/RepRap have no G41/G42), so pendingRadiusCompensation is always OFF here.

  // Force the feedrate to be scaled (if enabled). The feedrate is projected into the
  // x, y, and z axis and each axis is tested to see if it exceeds its defined max. If
  // it does then the speed in all 3 axis is scaled proportionately. The resulting feedrate
  // is then capped at the maximum defined cutrate.

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

// Test if file exist/can read and load it
function loadFile(_file) {
  var folder = FileSystem.getFolderPath(getOutputPath()) + PATH_SEPARATOR;
  if (FileSystem.isFile(folder + _file)) {
    var txt = loadText(folder + _file, "utf-8");
    if (txt.length > 0) {
      writeComment(eComment.Info, " --- Start custom gcode " + folder + _file);
      write(txt);
      // loadText() returns the file verbatim and write() appends no line break, so an
      // include file with no trailing newline leaves the output stream mid-line and the
      // NEXT thing written merges onto the include's last block. A stop file ending "M5"
      // then yields "M5M400" -- one invalid block, silently. The two Info comments here
      // normally absorb it, which is exactly why it is dangerous: at Comment Level
      // Important or Off they are suppressed and nothing stands between the include and
      // the next block. Guarded here rather than at the four call sites because every
      // include branch -- Start, Stop, and both Tool Change files -- shares this function.
      var lastChar = txt.charAt(txt.length - 1);
      if (lastChar != "\n" && lastChar != "\r") {
        writeln("");
      }
      writeComment(eComment.Info, " --- End custom gcode " + folder + _file);
    } else {
      // An include file that EXISTS but is empty used to emit nothing at all -- not even the
      // Start/End markers above -- so the operator got no indication their file contributed
      // nothing. A missing file is loud (the error() below aborts the post); an empty one was
      // silent. It matters most on the Start include: naming a file there skips Start()
      // entirely, so an empty one leaves G90/G21/G94/G17 unwritten and the job runs in
      // whatever modal state the controller was left in. See docs/HReview.md HR-22.
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
    // Disable stepper timeout
    writeComment(eComment.Info, "   Disable stepper timeout");
    writeBlock(mFormat.format(84), sFormat.format(0)); // Disable steppers timeout
  }
}

var spindleEnabled = false;

// Manual path only: the state the operator was last ASKED for. The speed is held as the formatted
// string that reached the file, because two speeds that format identically are the same speed to the
// operator -- prompting them to change a dial to the number it already reads is worse than saying
// nothing. Same reasoning isSafeToRapid() uses when it rounds positions to output precision before
// comparing them. Direction is tracked beside it so a reversal at an unchanged speed is not mistaken
// for "nothing happened".
var lastPromptedSpeed = "";
var lastPromptedClockwise = true;

function spindleOn(_spindleSpeed, _clockwise) {
  if (getProperty(properties.jobManualSpindlePowerControl)) {
    var rpm = speedFormat.format(_spindleSpeed);

    // For manual any positive input speed assumed as enabled. so it's just a flag
    if (!spindleEnabled) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual");
      // Direction is named here ONLY when counterclockwise. Clockwise is the universal default for
      // every tool this post's machines hold, so naming it would add a word to the start prompt of
      // every job ever posted and tell the operator nothing. Counterclockwise is always exceptional
      // and always worth saying.
      askUser("Turn ON " + rpm + " RPM" + (_clockwise ? "" : " counterclockwise"), "Spindle", false);
    }

    // Both halves of the state are compared, because setSpindeSpeed() reaches us for either.
    //
    // SPEED: a second operation asking for a different speed used to be dropped here --
    // setSpindeSpeed() had detected the change and updated currentSpindleSpeed, so the post believed
    // it had happened while nothing in the file mentioned it. On a hand-set router that is the gap
    // between the operator's dial and the speed Fusion computed the feeds against. HReview HR-12,
    // witnessed by Link.gcode (12000 then 10000, one prompt) against Speed Change.gcode (the same job
    // on the automatic branch, M3 S12000 then M3 S10000).
    //
    // DIRECTION: a tapping reversal changes direction at an unchanged speed, twice per hole -- seven
    // times in Drill_Tap.gcode -- and was silent for the same reason. The tap was driven back out of
    // the hole still turning forward, with nothing in the file to say otherwise. Prompting cannot make
    // a hand-switched router reverse, but it stops the machine and tells the operator what the job
    // requires, which is strictly better than stripping the thread quietly. Whether tapping should be
    // refused outright under manual control is still open: PReview HR-20.
    else if (rpm != lastPromptedSpeed || _clockwise != lastPromptedClockwise) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual change");
      // Direction IS always named here, even when only the speed moved. A change prompt asks the
      // operator to alter the machine, so it must state the whole target state rather than a delta
      // they have to remember: "Set spindle to 1200 RPM" arriving after a reversal would leave which
      // way ambiguous, and that ambiguity is the hazard this branch exists to remove.
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
  // Manual control describes the MACHINE -- a hand-switched router -- not the g-code dialect, so
  // the branch is on the property first and the firmware only inside it. It used to be the other
  // way round: GRBL emitted a bare M5 whatever the property said, which does nothing to a router
  // switched by hand. The result was an asymmetry on the DEFAULT hobbyist configuration (GRBL +
  // Manual Spindle On/Off on): the file asked the operator to switch the router ON, then ended
  // without ever asking them to switch it off -- and worse, every tool change paused for them to
  // reach into the machine with the same silence. Marlin/RepRap already prompted correctly, so this
  // brings GRBL into line with them and with spindleOn(). See docs/HReview.md HR-3.
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

// Collapse newlines and any of `unsafeChars` into a single space, so user-supplied text
// (tool comments, operation names) embedded in a G-code message or comment can't break
// line syntax, comment syntax, or quoted parameters. Runs of collapsed characters become a
// single space; leading/trailing whitespace is preserved so callers keep their own indentation.
//
// The second pass squeezes the blanks the first pass creates. A stripped character standing next
// to a space it did not consume -- "synchronization (rigid tapping) is" -- leaves a space of its
// own beside the original, so the text arrived in the file with visible double gaps. Only interior
// runs are squeezed (both neighbours must be non-blank), which is what keeps the leading and
// trailing whitespace the contract above promises callers.
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

  // Scale the arc's feed to the axis limits, as linearMovements() does for a G1. Arcs previously
  // bypassed Scale Feedrate entirely: with Use Arcs on by default and the README telling hobbyists
  // to enable scaling, a job with a tool feed above Max XY Cut Speed had every straight cut scaled
  // down and every fillet emitted at the raw feed -- defeating the feature on exactly the curved
  // geometry a slow machine struggles with, and invisibly unless you watched F across a G1 -> G2
  // boundary. Applied here rather than in onCircular() so it only touches arcs the post actually
  // emits: the linearize() paths above and in the plane switches below re-enter through onLinear(),
  // which limits them the ordinary way. See docs/HReview.md HR-5.
  feed = limitArcFeed(feed);

  var start = getCurrentPosition();

  // Full circles never arrive here: maximumCircularSweep = 180 splits them into two
  // arcs upstream, and helical moves are linearized by the kernel (allowHelicalMoves =
  // false) -- so only planar partial arcs reach this point.

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

// The in-file half of E2: the four "Jog to ..." origin modes cannot work on GRBL, which is this
// post's default firmware and the hobbyist's usual controller. askUser()'s allowJog flag is
// consumed in the RepRap branch ONLY, where it appends "X1 Y1 Z1" to M291 -- RRF's genuine
// jog-during-message flag; the GRBL branch emits a bare M0 with a (MSG ...) comment and discards
// the parameter. And on GRBL 1.1 that M0 is precisely the wrong state: "A jog command will only be
// accepted when Grbl is in either the 'Idle' or 'Jog' states" (Grbl v1.1 Jogging, gnea/grbl wiki).
// So the pause happens, the operator cannot jog at it, and nothing said so.
//
// A warning rather than a deletion: the modes are correct on RepRap, where M291 ... X1 Y1 Z1 is a
// real jog-at-pause, and deleting them would remove a working professional workflow.
// validateJob() carries the post-time half so it also reaches Fusion's dialog. Called at the jog
// dispatch sites rather than inside askUser(), which also serves prompts that are not jog modes.
function warnJogAtPauseOnGrbl() {
  if (fw != eFirmware.GRBL) {
    return;
  }
  writeComment(eComment.Important, " >>> WARNING: jogging at this pause is not supported on GRBL --"
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
  // If tool changes are not to be included in the NC file then SAY SO and exit. Returning silently
  // meant a job whose sections do not all use the same tool posted a file that cut every one of
  // them with whichever tool happened to be in the spindle, at the other tools' feeds and speeds,
  // with nothing at the boundary marking it -- the only trace was the header's Tools Table listing
  // two tools, which the operator had to notice and interpret. Off is the DEFAULT, so this is the
  // configuration reached by accident (a second tool added in CAM, group 07 left alone) rather than
  // on purpose, which is exactly why it has to be loud. validateJob() carries the post-time half of
  // the same warning. See docs/HReview.md CR-3.
  if (!getProperty(properties.toolChangeEnabled)) {
    writeComment(eComment.Important, " >>> WARNING: change to T" + tool.number + " " + tool.comment
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

    // Go to tool change position. A manual/dedicated tool-change spot only
    // makes sense as a fixed MACHINE location -- the whole point is that the
    // operator (or a real ATC) can always reach it. But toolChangeX/Y/Z are
    // emitted as plain G0 words (no G53), i.e. WCS-relative: the physical spot
    // silently drifts to wherever THIS job's WCS happens to be zeroed, which
    // differs per workpiece. That is a bug, not intended behavior.
    //
    // THE DECISION IT WAS FLAGGED FOR IS SETTLED: the post does address the
    // machine frame, on exactly the axes the operator declares (group 4) and
    // nowhere else -- see writeMachineTravelZ() and docs/conventions.md
    // "Frames". So the third park branch this comment argues for is
    // now sanctioned: with "Axes Homed and Trusted" = XYZ, park with
    // G53 G0 Z<n> then G53 G0 X<n> Y<n> -- two blocks, retract first, each
    // carrying its own G53, because G53 is not modal and because a single
    // three-axis G53 block would be the diagonal this post splits its rapids to
    // avoid. WHAT IS NOT SETTLED IS THE ORDERING AROUND IT, so the branch does
    // not land here: it shares this code with the Phase 4 tool-change reorder
    // and its two decided branches (base reserved -> park relative to the base;
    // no base -> plain G0 in the current WCS). See docs/PReview.md section 2 --
    // this must compose with that design, not replace or pre-empt it.
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

    // Run Z probe gcode. Same WCS caveat as the rapid above: this still runs
    // before the new section's WCS is selected, so probeTool() writes into
    // the PREVIOUS section's WCS (via currentWorkOffset), not the one the
    // upcoming section will use.
  if (getProperty(properties.toolChangeProbeAfterChange) && tool.number != 0) {
    onCommand(COMMAND_TOOL_MEASURE);
  }

  writeComment(eComment.Important, " Tool Change End");
}

// Probe Z and write it as the origin of a WCS. targetWcs defaults to the active
// work offset (the normal tool/section probe); the reserved-base establishment passes
// the base WCS number so the spoilboard Z lands in the base register instead.
function probeTool(targetWcs, retractZ) {
  if (targetWcs == undefined) {
    targetWcs = currentWorkOffset;
  }
  // Post-probe retract height, in output units and in the ACTIVE frame. Defaults to the probe
  // Safe Z -- correct for a part probe, whose frame's Z the probe just established. The
  // spoilboard base establish passes the Inter Part Travel Z instead: that retract is made in the
  // base's own frame and has to clear the stock, which the probe Safe Z (a small hop above a
  // part's stock top) does not.
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
    writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probeG38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.probeG38Target))));
  }

  // Not GRBL
  else {
    // refer http://marlinfw.org/docs/gcode/G038.html
    if (getProperty(properties.probeG382orG28)) {
      writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probeG38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.probeG38Target))));
    } else {
      writeBlock(gFormat.format(28), 'Z');
    }
  }

  writeWcsOrigin(targetWcs, undefined, undefined, propertyMmToUnit(getProperty(properties.probeThickness)));

  // LOAD-BEARING, not housekeeping. The G38.2 block above writes its F and Z through the RAW
  // formats (fFormat / zFormat), deliberately: routing them through fOutput / zOutput would let the
  // modal suppress the probe's own words. The consequence is that after that block the tracked
  // values disagree with the controller's modals -- the controller's feed is now the probe speed,
  // 30 mm/min by default. Without this reset, and with "Enforce Feedrate" off, the next move whose
  // feed happened to match the stale tracked value would be emitted with no F word at all and would
  // run at probe speed. Do not move it below rapidMovementsZ() or fold it into a caller.
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