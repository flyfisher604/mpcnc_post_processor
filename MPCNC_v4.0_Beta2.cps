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

properties = {
  A_Job_SelectedFirmware: {
    title      : "CNC Firmware",
    description: "Dialect of GCode to create.",
    group      : "01 - Job",
    type       : "enum",
    values: [
      { title: eFirmware.MARLIN, id: eFirmware.MARLIN},
      { title: eFirmware.GRBL, id: eFirmware.GRBL },
      { title: eFirmware.REPRAP, id: eFirmware.REPRAP }
    ],
    value: eFirmware.GRBL,
    scope: "post"
  },
  B_Job_ManualSpindlePowerControl: {
    title      : "Manual Spindle On/Off",
    description: "Enable to manually turn spindle motor on/off.",
    group      : "01 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  C_Job_CommentLevel: {
    title      : "Comment Level",
    description: "Detail of comments included.",
    group      : "01 - Job",
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
  D_Job_UseArcs: {
    title      : "Use Arcs",
    description: "Use G2/G3 g-codes fo circular movements.",
    group      : "01 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  E_Job_SequenceNumbers: {
    title      : "Enable Line #s",
    description: "Include line numbers on each line.",
    group      : "01 - Job",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  F_Job_SequenceNumberStart: {
    title      : "First Line #",
    description: "First line number used.",
    group      : "01 - Job",
    type       : "integer",
    value      : 10,
    scope      : "post"
  },
  G_Job_SequenceNumberIncrement: {
    title      : "Line # Increment",
    description: "Increase line numbers by this increment.",
    group      : "01 - Job",
    type       : "integer",
    value      : 1,
    scope      : "post"
  },
  H_Job_SeparateWordsWithSpace: {
    title      : "Include Whitespace",
    description: "Includes whitespace seperation between text.",
    group      : "01 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  I_Job_GoOriginOnFinish: {
    title      : "At End Go to 0,0",
    description: "Return to X0 Y0 at gcode end, Z remains unchanged.",
    group      : "01 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },

  A_Feeds_TravelSpeedXY: {
    title      : "Travel Speed X/Y",
    description: "High speed for Rapid movements X & Y (mm/min).",
    group      : "02 - Feeds and Speeds",
    type       : "integer",
    value      : 2500,
    scope      : "post"
  },
  B_Feeds_TravelSpeedZ: {
    title      : "Travel Speed Z",
    description: "High speed for Rapid movements Z (mm/min).",
    group      : "02 - Feeds and Speeds",
    type       : "integer",
    value      : 300,
    scope      : "post"
  },
  C_Feeds_EnforceFeedrate: {
    title      : "Enforce Feedrate",
    description: "Feedrate is include on every g-code movement.",
    group      : "02 - Feeds and Speeds",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  D_Feeds_ScaleFeedrate: {
    title      : "Scale Feedrate",
    description: "Scale feedrates to remain less than X, Y, Z axis maximums.",
    group      : "02 - Feeds and Speeds",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  E_Feeds_MaxCutSpeedXY: {
    title      : "Max XY Cut Speed",
    description: "Limit X or Y feedrate to be less then this value (mm/min).",
    group      : "02 - Feeds and Speeds",
    type       : "integer",
    value      : 900,
    scope      : "post"
  },
  F_Feeds_MaxCutSpeedZ: {
    title      : "Max Z Cut Speed",
    description: "Limit Z feedrate to be less then this value (mm/min).",
    group      : "02 - Feeds and Speeds",
    type       : "integer",
    value      : 180,
    scope      : "post"
  },
  G_Feeds_MaxCutSpeedXYZ: {
    title      : "Max Toolpath Speed",
    description: "Maximum scaled toolpath feedrate (mm/min).",
    group      : "02 - Feeds and Speeds",
    type       : "integer",
    value      : 1000,
    scope      : "post"
  },

  A_MapRapids_RestoreFirstRapids: {
    title      : "First G1 -> G0 Rapid",
    description: "Enable to ensure that the first move of a cut starts with a G0 Rapid.",
    group      : "03 - Map G1s to Rapids - disable when using full license",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  B_MapRapids_RestoreRapids: {
    title      : "Map: G1s -> G0 Rapids",
    description: "Enable to convert G1s to G0s Rapids when safe.",
    group      : "03 - Map G1s to Rapids - disable when using full license",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  C_MapRapids_SafeZ: {
    title      : "Map: Safe Z to Rapid",
    description: "Z must be above or equal to this value to be mapped G1s --> G0s; Uses Retract level if defined or 15.",
    group      : "03 - Map G1s to Rapids - disable when using full license",
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },
  D_MapRapids_AllowRapidZ: {
    title      : "Map: Allow Rapid Z",
    description: "Enable to include vertical G1 retracts and safe descents as rapids.",
    group      : "03 - Map G1s to Rapids - disable when using full license",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  A_Machine_HomeBeforeStart: {
    title      : "Home Before Start",
    description: "Home the machine at job start to establish a repeatable machine frame (MCS). None (default): emit no homing -- accept the current position (already homed at the controller, or a power-on 0,0,0). XY: home X and Y (the usual case -- gives XY repeatability and gantry squaring; Z stays on the work-Z probe touch-off). XYZ: also home Z, only if the machine is actually wired to home Z (LowRider switches, or the Marlin movable-plate trick). Per firmware: on GRBL/FluidNC one $H homes every configured axis, so XY and XYZ emit the same $H (the choice just documents intent); on Marlin/RepRap each axis is homed independently (G28 X / G28 Y / G28 Z). Homing gives X/Y repeatability only -- the everyday Z cutting reference is always the work-Z touch-off (see First WCS / Part), never this.",
    group      : "04 - Establish Machine Coordinates",
    type       : "enum",
    values: [
      { title: "None", id: "None" },
      { title: "XY", id: "XY" },
      { title: "XYZ", id: "XYZ" }
    ],
    value: "None",
    scope: "post"
  },
  B_Machine_PromptBeforeHome: {
    title      : "Prompt Before Home",
    description: "Pause once before any homing motion so the operator can prepare the machine (e.g. place a movable Z-homing plate, or clear the bed). Fires whenever Home Before Start runs homing (any firmware, any axes) -- so it never needs revisiting when the machine changes. No effect when Home Before Start is None.",
    group      : "04 - Establish Machine Coordinates",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  A_Spoilboard_BaseReserve: {
    title      : "Reserved WCS",
    description: "Reserve one WCS as a fixed spoilboard base (a stable Z reference for multi-fixture jobs). None (default): feature off, nothing emitted. Otherwise the selected WCS is reserved as the base and no operation may re-establish its origin (see Probe to Set Base). G59.1-G59.3 require RepRap. GRBL/RepRap only -- Marlin has no per-WCS registers, so a base is ignored there.",
    group      : "05 - Establish Spoilboard Reference",
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
  B_Spoilboard_BaseEstablish: {
    title      : "Probe to Set Base",
    description: "How to establish the reserved spoilboard base's Z at job start. None: skip -- assume the base was set in a previous job (probe-once / run-many), emitting an Info comment. Probe Z: probe the spoilboard into the base WCS (G10 L20 P<n>) with no operator prompt (a fixed/known probe point). Pause, Probe Z, Pause (default): prompt the operator to attach the probe, probe, then prompt to detach -- the manual touch-off. No effect when Reserved WCS is None; ignored on Marlin (no per-WCS registers). Always probed at the current position (0,0 / the job's XY origin) -- the Probe X/Y Offset never applies here.",
    group      : "05 - Establish Spoilboard Reference",
    type       : "enum",
    values: [
      { title: "None", id: "None" },
      { title: "Probe Z", id: "Probe Z" },
      { title: "Pause, Probe Z, Pause", id: "Pause & Probe Z" }
    ],
    value: "Pause & Probe Z",
    scope: "post"
  },
  C_Spoilboard_SafeZAcrossWcs: {
    title      : "Retract Across Parts",
    description: "Multi-fixture safety. On (default): before traversing between operations that use different WCS, the tool retracts to the Safe Z below so it clears fixtures/clamps/other parts, and the job is validated (Guard B) to reject a multi-WCS job that reserves no spoilboard base -- a clearance height is meaningless across WCS whose offsets are only known after probing at runtime. Single-WCS jobs (including a single operation) are unaffected: no extra retract is emitted and the guard does not apply. Off: no cross-WCS retract and no guard. GRBL/RepRap only (Marlin is single-frame; see Guard C).",
    group      : "05 - Establish Spoilboard Reference",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  D_Spoilboard_SafeZClearance: {
    title      : "Inter Part Safe Z",
    description: "Absolute work-Z height in whole mm, measured above the reserved spoilboard base, that the tool retracts to whenever it must clear everything on the bed. Set it high enough to clear the tallest fixture, clamp, or part in the job. Used at two points: (1) immediately after the spoilboard base is probed at job start -- that retract is made in the base's own frame, so this is the height the tool holds while it travels to the first part's X0 Y0; and (2) before each traverse between parts (a different WCS), when Retract Across Parts is on. Because it is measured above the spoilboard rather than the stock, it is the one clearance that stays valid across parts of differing thickness. Requires a Reserved WCS -- ignored when none is reserved, and on Marlin (no per-WCS registers).",
    group      : "05 - Establish Spoilboard Reference",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  A_Probe_OnStart: {
    title      : "First WCS / Part",
    description: "Establishes the origin for the first (or only) part -- the WCS the first section resolves to (WCS 1 / G54 by default, or whatever that Setup specifies). Set X0 Y0 to Current Pos, Probe Z0 (default): record X0 Y0 at the current position, then probe the stock-top Z -- pre-jog the tool to the part's X0 Y0 before starting (no prompt). Set X0 Y0 Z0 to Current Pos: record the tool's CURRENT position as X0 Y0 Z0 with no probe and no prompt -- pre-jog to the part origin before starting (a manual touch-off, or a jet/laser where Z is set by hand; when machine homing or a spoilboard base is enabled they move the tool last, so \"current position\" is that point). Use Active WCS X0 Y0, Probe Z0: use the X0 Y0 already stored in the active WCS's register (a pre-set fixture offset) -- rapid there and probe the stock-top Z, writing Z into that WCS; XY is not re-zeroed. Use Active WCS X0 Y0 Z0: use the full origin already stored in the active WCS -- no re-zero and no probe; the tool moves Z to the Safe Z set below and then rapids to the stored X0 Y0. Note that is a MOVE to Safe Z, not necessarily a retract: Safe Z is an absolute height in the stored frame, so if the tool is parked above it the job starts by descending to it. IMPORTANT -- \"active WCS\" means the register this operation's Fusion Setup designates (its Work Offset: WCS 1 / G54 unless you changed it), which the post SELECTS at job start before doing anything else. It is NOT whatever WCS your sender or controller happened to have active -- the post overwrites that. What the register holds, however, is runtime state left by a prior job or a manual touch-off, and the post cannot read it back to check: the two Use Active WCS modes TRUST those stored values. Jog to X0 Y0, Probe Z0: pause (M0) so you jog the tool to the origin during the run, record X0 Y0, then probe Z. Jog to X0 Y0 Z0: pause (M0) to jog to the origin during the run, then record X0 Y0 Z0 there, no probe. (Jogging at the pause needs sender/firmware support -- see the README.) On GRBL/RepRap the origin writes into that WCS's own offset (G10 L20 P<n>); Marlin uses G92. To mill additional parts/copies, see \"Subsequent WCS / Part\"; to mill one part from multiple datums/references or a flip, run separate jobs.",
    group      : "06 - On WCS / Part / Fixture Changes",
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
  B_Probe_OnChange: {
    title      : "Subsequent WCS / Part",
    description: "Multi-part jobs -- milling several parts/copies, one WCS per part. What to do when the job advances to the next part's WCS (G55, G56, ...) -- \"active WCS\" below means the register that part's Fusion Setup designates, which the post selects on the traverse; its stored contents come from a prior job or a manual touch-off and are trusted, not verified. Every mode first retracts to a safe Z, then acts. USE ACTIVE WCS (pre-set fixture offsets / Replicate) -- Use Active WCS X0 Y0, Probe Z0 (default): rapid to the part's stored X0 Y0 and probe its stock-top Z, writing Z into that WCS (G10 L20 P<n>); XY stays the fixture's pre-set offset. Use Active WCS X0 Y0 Z0: do nothing to the origin; after the retract the tool rapids to the part's stored X0 Y0 (X and Z already in its own WCS, from a prior job or set manually). JOG (operator jogs to each part; jogging at the pause needs sender/firmware support) -- Jog to X0 Y0, Probe Z0: pause (M0) to jog to this part's origin, record X0 Y0 there, then probe Z. Jog to X0 Y0 Z0: pause (M0) to jog to this part's origin, then record that position as X0 Y0 Z0 (no probe). The attach/detach prompts around any probe follow Probe Pause. The safe-Z retract on the traverse is separate (see Retract Across Parts). Not supported on Marlin (single G92 origin -- use separate jobs). Does NOT support milling one part from multiple datums or a flip -- run those as separate jobs.",
    group      : "06 - On WCS / Part / Fixture Changes",
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
  C_Probe_Pause: {
    title      : "Probe Pause",
    description: "Operator pauses around each part probe (the first part and each added part) -- the prompts to attach the Z probe (before) and detach it (after). No: no prompts (a fixed/permanent probe). Before: prompt to attach only. Before & After (default): prompt to attach before probing and to detach after -- the manual touch-off. Applies to the part probes in this group only, not the spoilboard base probe (see Probe to Set Base) or the tool-change re-probe.",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "enum",
    values: [
      { title: "No", id: "No" },
      { title: "Before", id: "Before" },
      { title: "Before & After", id: "Before & After" }
    ],
    value: "Before & After",
    scope: "post"
  },
  D_Probe_OffsetX: {
    title      : "Probe X Offset",
    description: "X distance from the part origin to the Z-probe touch-point, in whole mm (all dialog dimensions are in mm regardless of the job's output units). Applied at every PART probe -- the first/only part (First WCS / Part) and each added part (Subsequent WCS / Part) -- so the work origin can sit at a corner or off the material while Z is probed on the stock top. Job-wide, not per-fixture. Default 0 probes at the origin. Does NOT affect the spoilboard base probe (Probe to Set Base), which always touches off at the origin (0,0).",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  E_Probe_OffsetY: {
    title      : "Probe Y Offset",
    description: "Y distance from the part origin to the Z-probe touch-point, in whole mm (all dialog dimensions are in mm regardless of the job's output units). Applied at every PART probe -- the first/only part (First WCS / Part) and each added part (Subsequent WCS / Part) -- so the work origin can sit at a corner or off the material while Z is probed on the stock top. Job-wide, not per-fixture. Default 0 probes at the origin. Does NOT affect the spoilboard base probe (Probe to Set Base), which always touches off at the origin (0,0).",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  F_Probe_G382orG28: {
    title      : "Probe with G38.2",
    description: "Probe using G38.2 (On) or G28 (Off). GRBL always uses G38.2 regardless of this setting; RepRap fully supports G38.2 too, so this should be left On there as well. Off (G28) is intended for Marlin builds with no dedicated probe, using the Z homing switch as a substitute reference.",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  G_Probe_G38Target: {
    title      : "G38 Target",
    description: "G38 probing's furthest Z position.",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "integer",
    value      : -10,
    scope      : "post"
  },
  H_Probe_G38Speed: {
    title      : "G38 Speed",
    description: "G38 probing's speed (mm/min).",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "integer",
    value      : 30,
    scope      : "post"
  },
  I_Probe_SafeZ: {
    title      : "Safe Z",
    description: "Safe Z the tool retracts to after probing (also the retract height before an added-part re-probe when no spoilboard base is reserved; with a base reserved, the Establish Spoilboard Reference group's Safe Z is used instead). Same syntax as \"Map: Safe Z to Rapid\": a fixed number, or Feed:/Retract:/Clearance:<fallback> to use the operation's F360 level when defined, else the fallback -- e.g. \"Retract:15\" uses the F360 retract level or 15. Kept independent of the Map G1s Safe Z.",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },
  J_Probe_Thickness: {
    title      : "Plate Thickness",
    description: "Thickness of the probe touchplate.",
    group      : "06 - On WCS / Part / Fixture Changes",
    type       : "number",
    value      : 0.8,
    scope      : "post"
  },

  A_ToolChange_Enabled: {
    title      : "Tool Changes are Included",
    description: "Tool changes are include in the NC file.",
    group      : "07 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  B_ToolChange_InsertCode: {
    title      : "Include Relocation Code",
    description: "Relocate the tool for manual tool changes.",
    group      : "07 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  C_ToolChange_X: {
    title      : "Tool Change X",
    description: "X location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "07 - Tool Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  D_ToolChange_Y: {
    title      : "Tool Change Y",
    description: "Y location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "07 - Tool Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  E_ToolChange_Z: {
    title      : "Tool Change Z",
    description: "Z location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "07 - Tool Changes",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  F_ToolChange_DisableZStepper: {
    title      : "Disable Z Stepper",
    description: "Disable Z stepper after reaching tool change location.",
    group      : "07 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  G_ToolChange_DoFirstChange: {
    title      : "Do First Change",
    description: "Do an initial tool change to load first tool.",
    group      : "07 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  H_ToolChange_ProbeAfterChange: {
    title      : "Probe After Tool Change",
    description: "Probe Z at the current location after each tool change.",
    group      : "07 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  A_Include_StartFile: {
    title      : "Start GCode File",
    description: "File with custom Gcode for header/start (in nc folder).",
    group      : "08 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  B_Include_StopFile: {
    title      : "Stop GCode File",
    description: "File with custom Gcode for footer/end (in nc folder).",
    group      : "08 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  C_Include_ToolFile1: {
    title      : "Tool Change Start",
    description: "File with custom Gcode to start tool change (in nc folder).",
    group      : "08 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  D_Include_ToolFile2: {
    title      : "Tool Change End",
    description: "File with custom Gcode to end tool change (in nc folder).",
    group      : "08 - External Include Files",
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
  E_Include_ProbeFile: {
    title      : "Tool Change Probe",
    description: "NOT IMPLEMENTED YET. Reserved for a file of custom Gcode to run at the tool-change Z re-probe (in nc folder). Anything entered here is currently ignored -- no file is included and no warning is issued.",
    group      : "08 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },

  A_Laser_OnVaporize: {
    title      : "Laser: On - Vaporize",
    description: "Percentage of power to turn on the laser/plasma cutter in vaporize mode.",
    group      : "09 - Laser",
    type       : "integer",
    value      : 100,
    scope      : "post"
  },
  B_Laser_OnThrough: {
    title      : "Laser: On - Through",
    description: "Percentage of power to turn on the laser/plasma cutter in through mode.",
    group      : "09 - Laser",
    type       : "integer",
    value      : 80,
    scope      : "post"
  },
  C_Laser_OnEtch: {
    title      : "Laser: On - Etch",
    description: "Percentage of power to on the laser/plasma cutter in etch mode.",
    group      : "09 - Laser",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  D_Laser_MarlinMode: {
    title      : "Laser: Marlin/Reprap Mode",
    description: "Marlin/Reprap mode of the laser/plasma cutter.",
    group      : "09 - Laser",
    type       : "enum",
    values: [
      { title: "Fan - M106 S{PWM}/M107", id: "106" },
      { title: "Spindle - M3 O{PWM}/M5", id: "3" },
      { title: "Pin - M42 P{pin} S{PWM}", id: "42" }
    ],
    value: "106",
    scope: "post"
  },
  E_Laser_MarlinPin: {
    title      : "Laser: Marlin M42 Pin",
    description: "Marlin custom pin number for the laser/plasma cutter.",
    group      : "09 - Laser",
    type       : "integer",
    value      : 4,
    scope      : "post"
  },
  F_Laser_GrblMode: {
    title      : "Laser: GRBL Mode",
    description: "GRBL mode of the laser/plasma cutter.",
    group      : "09 - Laser",
    type       : "enum",
    values: [
      { title: "M4 S{PWM}/M5 dynamic power", id: "4" },
      { title: "M3 S{PWM}/M5 static power", id: "3" }
    ],
    value      : "4",
    scope      : "post"
  },
  G_Laser_Coolant: {
    title      : "Laser: Coolant",
    description: "Force a coolant to be used with the laser.",
    group      : "09 - Laser",
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

  A_Coolant_ChannelAMode: {
    title      : "Channel A Mode",
    description: "Enable channel A when tool is set this coolant.",
    group      : "10 - Coolant",
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
  B_Coolant_ChannelBMode: {
    title      : "Channel B Mode",
    description: "Enable channel B when tool is set this coolant.",
    group      : "10 - Coolant",
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
  C_Coolant_ChannelAOn: {
    title      : "Turn Channel A On",
    description: "GCode to turn On coolant channel A.",
    group      : "10 - Coolant",
    type       : "enum",
    values: [
      { title: "Mrln: M42 P6 S255", id: "M42 P6 S255" },
      { title: "Mrln: M42 P11 S255", id: "M42 P11 S255" },
      { title: "Grbl: M7 (mist)", id: "M7" },
      { title: "Grbl: M8 (flood)", id: "M8" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M42 P6 S255",
    scope      : "post"
  },
  D_Coolant_ChannelAOff: {
    title      : "Turn Channel A Off",
    description: "Gcode to turn Off coolant channel A.",
    group      : "10 - Coolant",
    type       : "enum",
    values: [
      { title: "Mrln: M42 P6 S0", id: "M42 P6 S0" },
      { title: "Mrln: M42 P11 S0", id: "M42 P11 S0" },
      { title: "Grbl: M9 (off)", id: "M9" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M42 P6 S0",
    scope      : "post"
  },
  E_Coolant_ChannelBOn: {
    title      : "Turn Channel B On",
    description: "GCode to turn On coolant channel B.",
    group      : "10 - Coolant",
    type       : "enum",
    values: [
      { title: "Mrln: M42 P11 S255", id: "M42 P11 S255" },
      { title: "Mrln: M42 P6 S255", id: "M42 P6 S255" },
      { title: "Grbl: M7 (mist)", id: "M7" },
      { title: "Grbl: M8 (flood)", id: "M8" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M42 P11 S255",
    scope      : "post"
  },
  F_Coolant_ChannelBOff: {
    title      : "Turn Channel B Off",
    description: "Gcode to turn Off coolant channel B.",
    group      : "10 - Coolant",
    type       : "enum",
    values: [
      { title: "Mrln: M42 P11 S0", id: "M42 P11 S0" },
      { title: "Mrln: M42 P6 S0", id: "M42 P6 S0" },
      { title: "Grbl: M9 (off)", id: "M9" },
      { title: "Use custom", id: "Use custom" }
    ],
    value      : "M42 P11 S0",
    scope      : "post"
  },
  G_Coolant_ChannelAOnCustom: {
    title      : "Channel A On Custom",
    description: "File with custom GCode to turn ON coolant channel A (in nc folder).",
    group      : "10 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  H_Coolant_ChannelAOffCustom: {
    title      : "Channel A Off Custom",
    description: "File with custom GCode to turn OFF coolant channel A (in nc folder).",
    group      : "10 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  I_Coolant_ChannelBOnCustom: {
    title      : "Channel B On Custom",
    description: "File with custom GCode to turn ON coolant channel B (in nc folder).",
    group      : "10 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  J_Coolant_ChannelBOffCustom: {
    title      : "Channel B Off Custom",
    description: "File with custom GCode to turn OFF coolant channel B (in nc folder).",
    group      : "10 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },

  A_Duet_MillingMode: {
    title      : "Milling Mode",
    description: "GCode  to setup Duet3d into milling mode.",
    group      : "11 - Duet",
    type       : "string",
    value      : "M453 P2 I0 R30000 F200",
    scope      : "post"
  },
  B_Duet_LaserMode: {
    title      : "Laser Mode",
    description: "GCode  to setup Duet3d into laser mode.",
    group      : "11 - Duet",
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
  if (getProperty(properties.E_Job_SequenceNumbers)) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += getProperty(properties.G_Job_SequenceNumberIncrement);
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
// into { mode, dflt }. Shared by the Map-G1s Safe Z (C_MapRapids_SafeZ) and the probe Safe Z
// (I_Probe_SafeZ) so both accept identical syntax. Pure: touches no globals, emits no output.
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
  var parsed = parseSafeZExpr(getProperty(properties.C_MapRapids_SafeZ));
  safeZMode = parsed.mode;
  safeZHeightDefault = parsed.dflt;

  writeComment(eComment.Debug, " parseSafeZProperty: safeZMode = '" + eSafeZ.prop[safeZMode].name + "'");
  writeComment(eComment.Debug, " parseSafeZProperty: safeZHeightDefault = " + safeZHeightDefault);
}

function safeZforSection(_section)
{
  if (getProperty(properties.B_MapRapids_RestoreRapids)) {
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
        writeComment(eComment.Important, " >>> WARNING: " + properties.C_MapRapids_SafeZ.title + " format error: " + safeZHeight);
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
// I_Probe_SafeZ ("06 - On WCS / Part / Fixture Changes" > "Safe Z") uses the SAME expression syntax and
// F360-level resolution as the Map-G1s Safe Z (C_MapRapids_SafeZ), but is a fully independent
// property so the two can be tuned separately. "Retract:15" pulls each operation's F360 retract
// level when defined and absolute, else falls back to 15 mm.
var probeSafeZMode = eSafeZ.CONST;
var probeSafeZHeightDefault = 15;   // the parsed literal fallback, in MILLIMETRES (see safeZHeightDefault)

function parseProbeSafeZProperty() {
  var parsed = parseSafeZExpr(getProperty(properties.I_Probe_SafeZ));
  probeSafeZMode = parsed.mode;
  probeSafeZHeightDefault = parsed.dflt;

  writeComment(eComment.Debug, " parseProbeSafeZProperty: probeSafeZMode = '" + eSafeZ.prop[probeSafeZMode].name + "'");
  writeComment(eComment.Debug, " parseProbeSafeZProperty: probeSafeZHeightDefault = " + probeSafeZHeightDefault);
}

// Resolve I_Probe_SafeZ for the current operation. Returns a height in the output unit -- already
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
  if (getProperty(properties.B_MapRapids_RestoreRapids)) {

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
      else if (getProperty(properties.D_MapRapids_AllowRapidZ) && zUp && xyConstant) {
        return true;
      }

      // We include moves of Z down as long as xy are constant and z always remains safe
      else if (getProperty(properties.D_MapRapids_AllowRapidZ) && (!zUp) && xyConstant && curZSafe) {
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
// also inherit its missing-file error and its missing-trailing-newline repair. See review.md CR-4.
function writeCustomCoolantFile(channel, on, file) {
  if (file == "") {
    writeComment(eComment.Important, " >>> WARNING: coolant channel " + channel + " is set to \"Use custom\""
      + " but no custom file is named -- nothing emitted");
    return;
  }
  loadFile(file);
}

function CoolantA(on) {
  var coolantText = on ? getProperty(properties.C_Coolant_ChannelAOn) : getProperty(properties.D_Coolant_ChannelAOff);

  if (coolantText == "Use custom") {
    writeCustomCoolantFile("A", on, on ? getProperty(properties.G_Coolant_ChannelAOnCustom)
                                       : getProperty(properties.H_Coolant_ChannelAOffCustom));
    return;
  }

  writeBlock(coolantText);
}

function CoolantB(on) {
  var coolantText = on ? getProperty(properties.E_Coolant_ChannelBOn) : getProperty(properties.F_Coolant_ChannelBOff);

  if (coolantText == "Use custom") {
    writeCustomCoolantFile("B", on, on ? getProperty(properties.I_Coolant_ChannelBOnCustom)
                                       : getProperty(properties.J_Coolant_ChannelBOffCustom));
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
    if (getProperty(properties.A_Coolant_ChannelAMode) == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel A: " + coolant);
      coolantChannelA =  coolant;
      curCoolant = coolant;
      warn = false;
      CoolantA(true);
    }

    if (getProperty(properties.B_Coolant_ChannelBMode) == coolant) {
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

    // Number(), not the raw property: F_Laser_GrblMode stores its enum id as a STRING ("4" / "3"),
    // and this is the only mFormat.format() call in the file handed anything but a numeric literal.
    // Whether the kernel's format() coerces a numeric string is not something reading can settle,
    // and the cost of it not doing so is that every GRBL laser job emits a malformed laser-on block
    // and the laser never fires. No posted file has ever exercised group 09 -- see PReview.md J4.
    writeBlock(mFormat.format(Number(getProperty(properties.F_Laser_GrblMode))), sFormat.format(laser_pwm));
  }

  // Default firmware
  else {
    var laser_pwm = power / 100 * 255;

    switch (getProperty(properties.D_Laser_MarlinMode)) {
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
        writeBlock(mFormat.format(42), pFormat.format(getProperty(properties.E_Laser_MarlinPin)), sFormat.format(laser_pwm));
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
    switch (getProperty(properties.D_Laser_MarlinMode)) {
      case "106":
        writeBlock(mFormat.format(107));
        break;
      case "3":
        writeBlock(mFormat.format(5));
        break;
      case "42":
        writeBlock(mFormat.format(42), pFormat.format(getProperty(properties.E_Laser_MarlinPin)), sFormat.format(0));
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
  var onStart = getProperty(properties.A_Probe_OnStart) != "Skip";
  var onChange = getProperty(properties.B_Probe_OnChange) != "Skip";
  var reprobe = getProperty(properties.A_ToolChange_Enabled) && getProperty(properties.H_ToolChange_ProbeAfterChange);
  var doFirstChange = getProperty(properties.G_ToolChange_DoFirstChange);
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

// Post-time validation guards (see docs/plan.md "Validation guards").
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
  // See docs/review.md CR-2.
  var startMode = getProperty(properties.A_Probe_OnStart);
  if (getProperty(properties.A_Machine_HomeBeforeStart) != "None" &&
      (startMode == "Current XY & Probe Z" || startMode == "Current XYZ")) {
    warning(localize("\"Home Before Start\" moves the tool to the homing corner before "
      + "\"First WCS / Part\" records the current position as the part origin, so jogging to the "
      + "part before starting the job has no effect. Choose a \"Use Active WCS ...\" or "
      + "\"Jog to ...\" mode, or set \"Home Before Start\" to None."));
  }

  // Post-time half of toolChange()'s suppression warning, so it reaches Fusion's dialog and not
  // only the posted file. See docs/review.md CR-3.
  if (!getProperty(properties.A_ToolChange_Enabled) && countDistinctTools() > 1) {
    warning(localize("This job uses more than one tool, but \"Tool Changes are Included\" is off: "
      + "no tool-change code is emitted and every operation runs with the tool already in the "
      + "spindle, at the other tools' feeds and speeds. Enable the \"07 - Tool Changes\" group, or "
      + "post one tool per file."));
  }

  // --- Guards --------------------------------------------------------------------------------
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
    // Guard B -- safe-Z across WCS needs a base. When the cross-WCS safe-Z retract is
    // enabled and the job spans more than one work offset, there is no frame in which a
    // single clearance height is meaningful across those WCS: their offsets are only
    // established by probing at runtime, so the post can't relate one WCS's Z to
    // another's. The reserved spoilboard base is that common frame, so require it. A
    // single-WCS job is exempt -- its one work zero is a stable enough reference. (Marlin
    // multi-WCS already errored above via Guard C, so only GRBL/RepRap reach here.)
    if (getProperty(properties.C_Spoilboard_SafeZAcrossWcs) && collectDistinctOffsets().length > 1) {
      error("Safe-Z across parts requires a base: reserve a spoilboard base (\"Reserved WCS\"), or turn off \"Retract Across Parts\".");
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
// newly added global is reset by editing one place. See docs/review.md CR-13.
function resetPostState() {
  currentWorkOffset = undefined;          // no work offset emitted yet
  sequenceNumber = getProperty(properties.F_Job_SequenceNumberStart);
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
  fw = getProperty(properties.A_Job_SelectedFirmware);

  resetPostState();

  // Validate the job configuration before emitting anything (may error() out).
  validateJob();

  // Output anything special to start the GCode
  if (fw == eFirmware.GRBL) {
    writeln("%");
  }

  // Configure the GCode G commands
  if (fw == eFirmware.GRBL) {
    gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
  }
  else {
    gMotionModal = createModal({ force: true }, gFormat); // modal group 1 // G0-G3, ...
  }

  // Configure how the feedrate is formatted
  if (getProperty(properties.C_Feeds_EnforceFeedrate)) {
    fOutput = createVariable({ force: true }, fFormat);
  }

  // (sequenceNumber and currentWorkOffset are initialised by resetPostState() above, with the
  // other module globals.)

  // Set the seperator used between text
  if (!getProperty(properties.H_Job_SeparateWordsWithSpace)) {
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

  if (getProperty(properties.B_Include_StopFile) == "") {
    onCommand(COMMAND_COOLANT_OFF);

    // Stop the spindle BEFORE the return traverse, not after. On the default hobbyist configuration
    // (Manual Spindle On/Off) COMMAND_STOP_SPINDLE is not an M5 -- it is an M0 prompt asking the
    // operator to switch a hand-switched router off. Emitted after the move, the file sent the tool
    // diagonally across the whole part at travel speed with the router still turning and only then
    // asked for it to be stopped. Prompting first means the operator switches off, resumes, and the
    // machine parks. See docs/review.md CR-6.
    //
    // NOTE what this deliberately does NOT do: it emits no Z retract before the X0 Y0 move. The
    // property's own text promises "Z remains unchanged", and for milling the last operation's own
    // end-of-toolpath retract covers it. A jet section that ends at cutting height is not covered --
    // that is the open half of CR-6 and the same line of code as HR-16.
    onCommand(COMMAND_STOP_SPINDLE);

    if (getProperty(properties.I_Job_GoOriginOnFinish)) {
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
    loadFile(getProperty(properties.B_Include_StopFile));
    flushMotions();
  }

  if (fw == eFirmware.GRBL) {
    writeln("%");
  }
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
  // How to establish this added part's origin/Z (B_Probe_OnChange = "Subsequent WCS / Part").
  // Each WCS has its own G10-scoped origin; the first part's is set by A_Probe_OnStart in
  // writeFirstSection(), so this covers the added parts only (guarded by isTraverse below).
  // Two workflows coexist:
  //   - Pre-set fixture offset (Replicate): "Skip" (use stored X/Z) and "Probe Z" (stored XY,
  //     re-probe Z) -- the post positions to the stored X0 Y0 automatically.
  //   - Jog per-part: "Jog XYZ" / "Jog XY & Probe Z" -- the operator jogs to this part
  //     and the post records the origin there.
  var onChangeMode = getProperty(properties.B_Probe_OnChange);
  var canProbe = (tool.number != 0 && !tool.isJetTool());
  writeComment(eComment.Debug, " writeWCS: B_Probe_OnChange: " + onChangeMode
    + " previousWorkOffset: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset)
    + " canProbe: " + canProbe);

  // Retract Z to a safe height FIRST, before selecting the new WCS -- the new WCS's Z origin
  // may be unknown, so an absolute Z move there would be unsafe. This fires on EVERY inter-part
  // traverse (any genuine WCS change) so we always reposition / let the operator jog / probe
  // from a known-clear height:
  //  - Base reserved + "Retract Across Parts" on: transit through the spoilboard base and clear
  //    to the base's Safe Z -- a stable height above the spoilboard that clears fixtures across
  //    parts of differing thickness (retractThroughBaseClearance()).
  //  - Otherwise: retract to the probe Safe Z in the OUTGOING part's frame (whose Z is
  //    established). Guard B blocks the risky no-base multi-WCS case up front when the feature
  //    is on, so this fallback runs for a deliberate no-base / feature-off multi-WCS job.
  var base = getReservedBaseWcs();
  var isTraverse = (previousWorkOffset != undefined);   // a genuine inter-part WCS change
  var baseRelative = isTraverse && getProperty(properties.C_Spoilboard_SafeZAcrossWcs)
                     && base != 0 && base != workOffset;
  writeComment(eComment.Debug, " writeWCS: retract decision -- baseRelative: " + baseRelative
    + " base: " + base + " C_SafeZAcrossWcs: " + getProperty(properties.C_Spoilboard_SafeZAcrossWcs)
    + " isTraverse: " + isTraverse + " workOffset: " + workOffset);
  if (baseRelative) {
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
  // first section's origin is handled separately by writeWcsOnStart() (A_Probe_OnStart).
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
    askUser("Jog to X0 Y0 Z0, then continue", "Set origin", true);
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
  } else if (onChangeMode == "Jog XY & Probe Z") {
    // Jog: the operator jogs to this part's X0 Y0 (staying clear in Z); record X0 Y0 here,
    // then probe Z. partProbe(true) -- the tool is at the origin after the jog.
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

// The reserved spoilboard base as a workOffset number (1-6 = G54-G59,
// 7-9 = G59.1-G59.3), or 0 when the feature is off ("None"). The A_Spoilboard_BaseReserve
// enum ids are the numbers directly, so this also validates the raw value.
function getReservedBaseWcs() {
  var v = getProperty(properties.A_Spoilboard_BaseReserve);
  if (v == "None") return 0;
  return parseInt(v, 10);
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

// Retract to the base's "Safe Z" height measured above the reserved spoilboard base,
// by transiting THROUGH the base WCS. The base's Z was established at job start
// (writeBaseEstablish), so it is the one frame where an absolute safe height is meaningful
// across parts of differing thickness. Selects the base with a plain frame switch -- NOT
// writeWCS(), so it triggers no B_Probe_OnChange re-probe and writes no origin -- then
// commands the clearance (a real Z move, so this is never an empty base round-trip). LEAVES
// the base active; the caller selects the destination WCS next. Caller guarantees a base is
// reserved. See docs/plan.md "Base WCS is transited, not parked".
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
  rapidMovementsZ(propertyMmToUnit(getProperty(properties.D_Spoilboard_SafeZClearance)));
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
  // first section, which used to print literally. See docs/review.md CR-17 (e).
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
    if (getProperty(properties.G_ToolChange_DoFirstChange))
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
        cutterOnCurrentPower = getProperty(properties.B_Laser_OnThrough);
        jetModeStr = "Through";
        break;
      case JET_MODE_ETCHING:
        cutterOnCurrentPower = getProperty(properties.C_Laser_OnEtch);
        jetModeStr = "Etching";
        break;
      case JET_MODE_VAPORIZE:
        jetModeStr = "Vaporize";
        cutterOnCurrentPower = getProperty(properties.A_Laser_OnVaporize);
        break;
      default:
        jetModeStr = "*** Unknown ***";
        // Leave the power DEFINED. Every other branch sets cutterOnCurrentPower; falling through
        // without it made laserOn() compute "undefined * 10" and emit S NaN -- or, after an earlier
        // section had set it, silently reuse THAT section's power, which looks plausible and is not.
        // Only the three mapped modes exist in Fusion today, so this guards a future enum value
        // rather than a live failure, which is exactly why it must not be left producing NaN.
        // Through is the conservative middle setting.
        cutterOnCurrentPower = getProperty(properties.B_Laser_OnThrough);
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
              writeBlock(getProperty(properties.A_Duet_MillingMode));
              break;
          case TYPE_JET:
              writeBlock(getProperty(properties.B_Duet_LaserMode));
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

  if (getProperty(properties.A_MapRapids_RestoreFirstRapids) && (forceSectionToStartWithRapid == true)) {
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

        if (getProperty(properties.G_Laser_Coolant) != eCoolant.Off) {
          setCoolant(getProperty(properties.G_Laser_Coolant));
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
function writeAllProperties() {
  // Bucket the keys by group, then sort. The `group:` strings are zero-padded ("01 - Job" ...
  // "11 - Duet") precisely so a plain lexicographic sort reproduces the dialog's own order;
  // within a group the single-letter key prefix does the same.
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
  groupNames.sort();

  for (var i = 0; i < groupNames.length; ++i) {
    var name = groupNames[i];
    var keys = byGroup[name];
    keys.sort();
    writeComment(eComment.Info, " ");
    writeComment(eComment.Info, " Properties -- " + name + ":");
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
// these the dump is misleading: "I_Probe_SafeZ = Retract:15" does not tell you the retract
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
  writeComment(eComment.Info, "   Reserved base WCS = " + (base == 0 ? "None" : wcsName(base) + " / P" + base));
  writeComment(eComment.Info, "   Probe XY offset in output units = X" + xyzFormat.format(probeOffsetX()) + " Y" + xyzFormat.format(probeOffsetY()));
  writeComment(eComment.Info, "   Inter Part Safe Z in output units = " + xyzFormat.format(propertyMmToUnit(getProperty(properties.D_Spoilboard_SafeZClearance))));
}

// Implements A_Machine_HomeBeforeStart: establishes the machine frame (MCS) at job
// start, once, before anything work-relative. Mode None/XY/XYZ. X/Y homing is what
// actually gives MCS a repeatable origin (plus gantry squaring); Z homing (mode XYZ),
// where wired, is included for its own reason (a real endstop, or the Marlin plate-homing
// trick) -- it is never in service of MCS and never becomes the everyday Z reference,
// which stays the work-Z touch-off (A_Probe_OnStart / B_Probe_OnChange) regardless.
function writeMachineHoming() {
  var mode = getProperty(properties.A_Machine_HomeBeforeStart);   // "None" | "XY" | "XYZ"
  var homeXY = (mode == "XY" || mode == "XYZ");
  var homeZ = (mode == "XYZ");

  writeComment(eComment.Debug, " writeMachineHoming: entry fw: " + fw + " mode: " + mode);

  if (mode == "None") {
    writeComment(eComment.Debug, " writeMachineHoming: None -- current position accepted as zero, no motion");
    return;
  }

  // Optional single pause before any homing motion -- lets the operator prepare the machine
  // (place a movable Z-homing plate, clear the bed, etc.). Independent of firmware and of
  // which axes home, so it never needs revisiting when the machine changes.
  if (getProperty(properties.B_Machine_PromptBeforeHome)) {
    writeComment(eComment.Debug, " writeMachineHoming: pausing before homing (Prompt Before Home)");
    askUser("Prepare machine for homing", "Homing", false);
  }

  if (fw == eFirmware.GRBL) {
    // $H is all-or-nothing on stock GRBL/FluidNC -- one $H homes every configured axis, so
    // XY and XYZ are identical here; the mode only documents which axes the user expects.
    writeComment(eComment.Debug, " writeMachineHoming: GRBL/FluidNC, emitting single combined $H (mode " + mode + ")");
    // writeln(), NOT writeBlock(). writeBlock() prefixes an N word when "Enable Line #s" is on, and
    // GRBL only recognises a $ system command when $ is the first character of the line -- "N10 $H"
    // is handed to the g-code parser instead, which has no word letter $, so the controller errors
    // and the sender halts on the first motion line of the preamble. $H is not a g-code block and
    // takes no line number. The only other raw controller strings in this file, the GRBL "%"
    // wrappers in onOpen()/onClose(), already use writeln() for the same reason.
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
//   5. writeBaseEstablish()  -- probe the reserved spoilboard base (needs 4's units)
//   6. writeWcsOnStart()     -- A_Probe_OnStart: the initial origin for the WCS from 3
// Only step 3 (writeWCS) is not intrinsically first-section work -- every section selects
// its WCS. It lives here because steps 4-6 may write an origin on top of the active WCS,
// so the WCS must be selected first. That is the deliberate reason WCS selection is split:
// section 1 selects here (mid-preamble, before its origin write); every later section
// selects in onSection()'s body. See the matching note at the writeWCS() call there.
function writeFirstSection() {
  // Write out the information block at the beginning of the file
  writeInformation();

  // Establish the machine frame (MCS) before anything work-relative -- home (or
  // accept the current position) per A_Machine_HomeBeforeStart (None / XY / XYZ).
  writeMachineHoming();

  // Select the WCS before Start()/A_Include_StartFile and writeWcsOnStart() below --
  // both may set an origin on top of the active WCS, so the WCS must be
  // selected first or the origin would land on the wrong one (either a stale
  // WCS left active by a prior job, or the controller's default).
  writeWCS(currentSection);

  writeComment(eComment.Important, " *** START begin ***");

  if (getProperty(properties.A_Include_StartFile) == "") {
       Start();
  } else {
    loadFile(getProperty(properties.A_Include_StartFile));
  }

  // Establish the reserved spoilboard base (if any) before the first section's own
  // origin -- both after Start() so absolute positioning/units are set for the probe.
  writeBaseEstablish();

  writeWcsOnStart();

  writeComment(eComment.Important, " *** START end ***");
  writeComment(eComment.Important, " ");
}

// Implements A_Spoilboard_BaseReserve / B_Spoilboard_BaseEstablish: at job start, establish the
// reserved spoilboard base WCS's Z by probing (writing G10 L20 P<base>), or -- when
// establish is off -- just note that a prior job set it. No-op when no base is reserved,
// so a default (None) job emits nothing here. The base is a per-WCS register concept, so
// it is skipped with a warning on Marlin (single global frame, no P<n> registers).
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

  var mode = getProperty(properties.B_Spoilboard_BaseEstablish);   // "None" | "Probe Z" | "Pause & Probe Z"
  if (mode == "None") {
    writeComment(eComment.Info, "   assuming base " + gname + " is already established -- from a prior job or set manually");
    return;
  }

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
    // Retract to the Inter Part Safe Z, not the probe Safe Z -- see probeTool()'s retractZ note.
    probeTool(base, propertyMmToUnit(getProperty(properties.D_Spoilboard_SafeZClearance)));

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

// Part-probe XY offset (D_Probe_OffsetX / E_Probe_OffsetY), in output units. The Z-probe
// touch-point for a PART is its WCS origin plus this offset, so the origin can sit at a
// corner / off the material while Z is read on the stock top. Applied to the first part
// (A_Probe_OnStart) and each added part (B_Probe_OnChange) only -- NOT to the spoilboard
// base probe, which emits no XY move of any kind: it touches off wherever the tool already
// sits when writeBaseEstablish() runs. See that function's note on what the operator must
// therefore guarantee.
function probeOffsetX() { return propertyMmToUnit(getProperty(properties.D_Probe_OffsetX)); }
function probeOffsetY() { return propertyMmToUnit(getProperty(properties.E_Probe_OffsetY)); }

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
// jet tools. The attach/detach prompts follow C_Probe_Pause. The spoilboard base probe does
// NOT use this -- it always touches off at the origin, with its own pause setting (see
// writeBaseEstablish).
// `zUnknown` (optional, default false) = the caller emitted no absolute Z move before this probe
// because the active frame's Z0 is stale, so the traverse below runs at whatever height the tool
// already holds; see the warning comment inside. Only the first-part "Probe Z" mode passes true --
// every other caller reaches here at a retracted, known height.
function partProbe(atOrigin, zUnknown) {
  var ox = probeOffsetX();
  var oy = probeOffsetY();
  var offsetSet = (ox != 0 || oy != 0);
  if (!atOrigin || offsetSet) {
    resetAll();
    // The rapid below is at an unknown height and, on the first-part path, is the program's first
    // motion -- so no absolute Z move can precede it and the file must say so instead, for both the
    // operator and an automated review. Suppressed when an established spoilboard base has already
    // retracted us to a known height (base frame + Inter Part Safe Z), where the warning is false.
    if (zUnknown && (getReservedBaseWcs() == 0 || getProperty(properties.B_Spoilboard_BaseEstablish) == "None")) {
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
  // Attach(before)/detach(after) prompts per C_Probe_Pause: No=neither, Before=attach only,
  // Before & After=both (default -- byte-identical to the historical always-prompt behavior).
  var pause = getProperty(properties.C_Probe_Pause);
  probePauseBefore = (pause == "Before" || pause == "Before & After");
  probePauseAfter = (pause == "Before & After");
  onCommand(COMMAND_TOOL_MEASURE);
}

// Implements the A_Probe_OnStart property: establishes the origin for the WCS
// writeWCS() just selected for the first section, scoped to that WCS via
// writeWcsOrigin() (G10 on GRBL/RepRap, G92 on Marlin).
function writeWcsOnStart() {
  var mode = getProperty(properties.A_Probe_OnStart);
  var canProbe = (tool.number != 0 && !tool.isJetTool());
  writeComment(eComment.Debug, " writeWcsOnStart: A_Probe_OnStart: " + mode + " wcs: " + currentWorkOffset);

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
    // See review.md CR-16; plan.md carries the related open decision for the base-reserved variant.
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
    // G_Probe_G38Target ("G38 Target") the meaning its title claims -- with Z0 at the tool's
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
    // The origin is the current position; partProbe() steps to the probe point (origin + XY
    // offset) only when an offset is set.
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
    // See review.md CR-5, and PReview.md J1 / HR-1 (D) for the jet workstream this belongs to.
    writeComment(eComment.Important, " >>> WARNING: a jet tool / tool 0 cannot probe, so Z0 was NOT"
      + " established -- this job runs against whatever Z origin is already stored. Use"
      + " \"Set X0 Y0 Z0 to Current Pos\" for a jet/laser job.");
    writeComment(eComment.Debug, " writeWcsOnStart: probe skipped (tool 0 or jet tool)");
  }
}

// Output a comment
function writeComment(level, text) { 
  if (commentLevels.indexOf(level) <= commentLevels.indexOf(getProperty(properties.C_Job_CommentLevel))) {
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
      let f = fOutput.format(propertyMmToUnit(getProperty(properties.A_Feeds_TravelSpeedXY)));
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
      let f = fOutput.format(propertyMmToUnit(getProperty(properties.B_Feeds_TravelSpeedZ)));
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
  if (!getProperty(properties.D_Feeds_ScaleFeedrate))
    return feed;

  var xyz = Vector.diff(destPos, curPos);       // Translate the cut so curPos is at 0,0,0
  var dir = xyz.getNormalized();                // Normalize vector to get a direction vector
  var xyzFeed = Vector.product(dir.abs, feed);  // Determine the effective x,y,z speed on each axis

  // Get the max speed for each axis
  let xyLimit = propertyMmToUnit(getProperty(properties.E_Feeds_MaxCutSpeedXY));
  let zLimit = propertyMmToUnit(getProperty(properties.F_Feeds_MaxCutSpeedZ));

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

  let xyzLimit = propertyMmToUnit(getProperty(properties.G_Feeds_MaxCutSpeedXYZ));
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
  if (!getProperty(properties.D_Feeds_ScaleFeedrate)) {
    return feed;
  }

  var xyLimit = propertyMmToUnit(getProperty(properties.E_Feeds_MaxCutSpeedXY));
  var zLimit = propertyMmToUnit(getProperty(properties.F_Feeds_MaxCutSpeedZ));

  // An XY arc sweeps X and Y only. A ZX / YZ arc (GRBL only -- Marlin/RepRap linearize those, and
  // the linearized moves go through limitFeedByXYZComponents() instead) sweeps one linear axis and
  // Z, so it must satisfy the slower of the two.
  var limit = (getCircularPlane() == PLANE_XY) ? xyLimit : ((xyLimit < zLimit) ? xyLimit : zLimit);

  // Same final cap the linear path applies to its resolved feed.
  var xyzLimit = propertyMmToUnit(getProperty(properties.G_Feeds_MaxCutSpeedXYZ));
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
  if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
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
  if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
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
    writeBlock(mFormat.format(117), (getProperty(properties.H_Job_SeparateWordsWithSpace) ? "" : " ") + sanitizeMessageText(txt, "();"));
  }
}

function circular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (!getProperty(properties.D_Job_UseArcs)) {
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

function askUser(text, title, allowJog) {
  // Firmware is RepRap?
  if (fw == eFirmware.REPRAP) {
    var v1 = " P\"" + sanitizeMessageText(text, "\"") + "\" R\"" + sanitizeMessageText(title, "\"") + "\" S3";
    var v2 = allowJog ? " X1 Y1 Z1" : "";
    writeBlock(mFormat.format(291), (getProperty(properties.H_Job_SeparateWordsWithSpace) ? "" : " ") + v1 + v2);
  }

  // GRBL, include the message in a comment prefixed with MSG
  else if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(0), (getProperty(properties.H_Job_SeparateWordsWithSpace) ? "" : " ") + "(MSG " + sanitizeMessageText(text, "();") + ")");
  }

  // Default
  else
  {
    writeBlock(mFormat.format(0), (getProperty(properties.H_Job_SeparateWordsWithSpace) ? "" : " ") + sanitizeMessageText(text, "();"));
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
  // the same warning. See docs/review.md CR-3.
  if (!getProperty(properties.A_ToolChange_Enabled)) {
    writeComment(eComment.Important, " >>> WARNING: change to T" + tool.number + " " + tool.comment
      + " suppressed -- \"Tool Changes are Included\" is off; the previous tool stays in the spindle");
    return;
  }

  writeComment(eComment.Important, " Tool Change Start");

  // If there is a custom GCode file for tool changes then include it
  if (getProperty(properties.C_Include_ToolFile1) != "") {
    loadFile(getProperty(properties.C_Include_ToolFile1));
  }

  // Are we inserting code to assist with the tool change?
  // If not, then just insert the tool change GCode (M6 <tool number>).
  if (getProperty(properties.B_ToolChange_InsertCode)) {

    // Go to tool change position. A manual/dedicated tool-change spot only
    // makes sense as a fixed MACHINE location -- the whole point is that the
    // operator (or a real ATC) can always reach it. But C_ToolChange_X/3_Y/4_Z
    // are currently emitted as plain G0 words (no G53), i.e. WCS-relative:
    // the actual physical spot would silently drift to wherever THIS job's
    // WCS happens to be zeroed, which differs per workpiece. That's likely a
    // bug, not intended behavior -- this should probably be a G53 move
    // instead, so it lands at the same physical spot regardless of which WCS
    // is active. (G53 doesn't need true limit-switch homing to be internally
    // consistent -- GRBL/RepRap track machine position by step-counting from
    // the controller's last reset/power-up, so it just needs the operator to
    // reset from a consistent physical position.) Not changed yet -- flagging
    // for a decision before altering behavior.
    flushMotions();
    onRapid(propertyMmToUnit(getProperty(properties.C_ToolChange_X)), propertyMmToUnit(getProperty(properties.D_ToolChange_Y)), propertyMmToUnit(getProperty(properties.E_ToolChange_Z)));
    flushMotions();
  
    // turn off spindle and coolant
    onCommand(COMMAND_COOLANT_OFF);
    onCommand(COMMAND_STOP_SPINDLE);

    // If Marlin then BEEP
    if ((fw == eFirmware.MARLIN) && !getProperty(properties.B_Job_ManualSpindlePowerControl)) {
      writeBlock(mFormat.format(300), sFormat.format(400), pFormat.format(2000));
    }
  
    // Disable Z stepper
    if (getProperty(properties.F_ToolChange_DisableZStepper)) {
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
  if (getProperty(properties.D_Include_ToolFile2) != "") {
    loadFile(getProperty(properties.D_Include_ToolFile2));
  }

    // Run Z probe gcode. Same WCS caveat as the rapid above: this still runs
    // before the new section's WCS is selected, so probeTool() writes into
    // the PREVIOUS section's WCS (via currentWorkOffset), not the one the
    // upcoming section will use.
  if (getProperty(properties.H_ToolChange_ProbeAfterChange) && tool.number != 0) {
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
  // spoilboard base establish passes the Inter Part Safe Z instead: that retract is made in the
  // base's own frame and has to clear the stock, which the probe Safe Z (a small hop above a
  // part's stock top) does not.
  if (retractZ == undefined) {
    retractZ = probeSafeZ();
  }
  // Command comment block
  writeComment(eComment.Important, " Probe to Zero Z");
  if (probePauseBefore) writeComment(eComment.Info, "   Ask User to Attach the Z Probe");
  writeComment(eComment.Info, "   Do Probing");
  writeComment(eComment.Info, "   Set Z to probe thickness: " + zFormat.format(propertyMmToUnit(getProperty(properties.J_Probe_Thickness))));
  writeComment(eComment.Info, "   Retract the tool to " + xyzFormat.format(retractZ));
  if (probePauseAfter) writeComment(eComment.Info, "   Ask User to Remove the Z Probe");

  if (probePauseBefore) askUser("Attach ZProbe", "Probe", false);

  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    // refer to http://linuxcnc.org/docs/stable/html/gcode/g-code.html#gcode:g38
    // Note this is not using the optional P parameter available on FluidNC (http://wiki.fluidnc.com/en/config/probe)
    writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.H_Probe_G38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.G_Probe_G38Target))));
  }

  // Not GRBL
  else {
    // refer http://marlinfw.org/docs/gcode/G038.html
    if (getProperty(properties.F_Probe_G382orG28)) {
      writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.H_Probe_G38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.G_Probe_G38Target))));
    } else {
      writeBlock(gFormat.format(28), 'Z');
    }
  }

  writeWcsOrigin(targetWcs, undefined, undefined, propertyMmToUnit(getProperty(properties.J_Probe_Thickness)));

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