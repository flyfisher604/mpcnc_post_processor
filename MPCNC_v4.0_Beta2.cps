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

const coolantLevels = ["Off", "Flood", "Mist","ThroughTool", "Air", "AirThroughTool", "Suction", "FloodMist", "FloodThroughTool"];
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

  A_Machine_HomeX: {
    title      : "Home X",
    description: "Power-On: accept the current X position as zero, no motion emitted. Home: home X to its endstop at job start (the machine must actually be wired to home this axis). This establishes the machine frame (MCS) only -- it is distinct from the work-Z touch-off used for the everyday cutting reference.",
    group      : "02 - Establish Machine Coordinates",
    type       : "enum",
    values: [
      { title: "Power-On", id: "Power-On" },
      { title: "Home", id: "Home" }
    ],
    value: "Power-On",
    scope: "post"
  },
  B_Machine_HomeY: {
    title      : "Home Y",
    description: "Power-On: accept the current Y position as zero, no motion emitted. Home: home Y to its endstop at job start (the machine must actually be wired to home this axis). This establishes the machine frame (MCS) only -- it is distinct from the work-Z touch-off used for the everyday cutting reference.",
    group      : "02 - Establish Machine Coordinates",
    type       : "enum",
    values: [
      { title: "Power-On", id: "Power-On" },
      { title: "Home", id: "Home" }
    ],
    value: "Power-On",
    scope: "post"
  },
  C_Machine_HomeZ: {
    title      : "Home Z",
    description: "Power-On: accept the current Z position as zero, no motion emitted. Home: home Z to its endstop at job start (the machine must actually be wired to home this axis, e.g. LowRider switches, or Marlin sharing the Z-min pin with a movable plate). Most V1E machines have no usable machine Z -- the everyday Z reference is always the work-Z touch-off (probe), never this setting.",
    group      : "02 - Establish Machine Coordinates",
    type       : "enum",
    values: [
      { title: "Power-On", id: "Power-On" },
      { title: "Home", id: "Home" }
    ],
    value: "Power-On",
    scope: "post"
  },
  D_Machine_PromptBeforeHome: {
    title      : "Prompt Before Z Home",
    description: "Pause before homing Z so the operator can place the movable Z-homing plate (Marlin sharing the Z-min pin). Only fires when Home Z = Home and firmware is Marlin; never for X/Y, and never for GRBL/FluidNC/RRF switch-based Z homing.",
    group      : "02 - Establish Machine Coordinates",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  A_Feeds_TravelSpeedXY: {
    title      : "Travel Speed X/Y",
    description: "High speed for Rapid movements X & Y (mm/min).",
    group      : "04 - Feeds and Speeds",
    type       : "integer",
    value      : 2500,
    scope      : "post"
  },
  B_Feeds_TravelSpeedZ: {
    title      : "Travel Speed Z",
    description: "High speed for Rapid movements Z (mm/min).",
    group      : "04 - Feeds and Speeds",
    type       : "integer",
    value      : 300,
    scope      : "post"
  },
  C_Feeds_EnforceFeedrate: {
    title      : "Enforce Feedrate",
    description: "Feedrate is include on every g-code movement.",
    group      : "04 - Feeds and Speeds",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  D_Feeds_ScaleFeedrate: {
    title      : "Scale Feedrate",
    description: "Scale feedrates to remain less than X, Y, Z axis maximums.",
    group      : "04 - Feeds and Speeds",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  E_Feeds_MaxCutSpeedXY: {
    title      : "Max XY Cut Speed",
    description: "Limit X or Y feedrate to be less then this value (mm/min).",
    group      : "04 - Feeds and Speeds",
    type       : "integer",
    value      : 900,
    scope      : "post"
  },
  F_Feeds_MaxCutSpeedZ: {
    title      : "Max Z Cut Speed",
    description: "Limit Z feedrate to be less then this value (mm/min).",
    group      : "04 - Feeds and Speeds",
    type       : "integer",
    value      : 180,
    scope      : "post"
  },
  G_Feeds_MaxCutSpeedXYZ: {
    title      : "Max Toolpath Speed",
    description: "Maximum scaled toolpath feedrate (mm/min).",
    group      : "04 - Feeds and Speeds",
    type       : "integer",
    value      : 1000,
    scope      : "post"
  },

  A_MapRapids_RestoreFirstRapids: {
    title      : "First G1 -> G0 Rapid",
    description: "Enable to ensure that the first move of a cut starts with a G0 Rapid.",
    group      : "05 - Map G1s to Rapids (disable when using full license)",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  B_MapRapids_RestoreRapids: {
    title      : "Map: G1s -> G0 Rapids",
    description: "Enable to convert G1s to G0s Rapids when safe.",
    group      : "05 - Map G1s to Rapids (disable when using full license)",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  C_MapRapids_SafeZ: {
    title      : "Map: Safe Z to Rapid",
    description: "Z must be above or equal to this value to be mapped G1s --> G0s; Uses Retract level if defined or 15.",
    group      : "05 - Map G1s to Rapids (disable when using full license)",
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },
  D_MapRapids_AllowRapidZ: {
    title      : "Map: Allow Rapid Z",
    description: "Enable to include vertical G1 retracts and safe descents as rapids.",
    group      : "05 - Map G1s to Rapids (disable when using full license)",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  A_ToolChange_Enabled: {
    title      : "Tool Changes are Included",
    description: "Tool changes are include in the NC file.",
    group      : "06 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  B_ToolChange_InsertCode: {
    title      : "Include Relocation Code",
    description: "Relocate the tool for manual tool changes.",
    group      : "06 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  C_ToolChange_X: {
    title      : "Tool Change X",
    description: "X location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "06 - Tool Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  D_ToolChange_Y: {
    title      : "Tool Change Y",
    description: "Y location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "06 - Tool Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  E_ToolChange_Z: {
    title      : "Tool Change Z",
    description: "Z location for tool change, in whichever WCS is currently active (plain G0, not machine coordinates).",
    group      : "06 - Tool Changes",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  F_ToolChange_DisableZStepper: {
    title      : "Disable Z Stepper",
    description: "Disable Z stepper after reaching tool change location.",
    group      : "06 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  G_ToolChange_DoFirstChange: {
    title      : "Do First Change",
    description: "Do an initial tool change to load first tool.",
    group      : "06 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  H_ToolChange_ProbeAfterChange: {
    title      : "Probe After Tool Change",
    description: "Probe Z at the current location after each tool change.",
    group      : "06 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  A_Probe_BaseReserve: {
    title      : "WCS for Spoilboard",
    description: "Reserve one WCS as a fixed spoilboard base (a stable Z reference for multi-fixture jobs). None (default): feature off, nothing emitted. Otherwise the selected WCS is reserved as the base and no operation may re-establish its origin (see Probe Z to Set Spoilboard WCS). G59.1-G59.3 require RepRap. GRBL/RepRap only -- Marlin has no per-WCS registers, so a base is ignored there.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "enum",
    values: [
      { title: "None", id: "None" },
      { title: "G54", id: "1" },
      { title: "G55", id: "2" },
      { title: "G56", id: "3" },
      { title: "G57", id: "4" },
      { title: "G58", id: "5" },
      { title: "G59", id: "6" },
      { title: "G59.1 (RepRap)", id: "7" },
      { title: "G59.2 (RepRap)", id: "8" },
      { title: "G59.3 (RepRap)", id: "9" }
    ],
    value: "None",
    scope: "post"
  },
  B_Probe_BaseEstablish: {
    title      : "Probe Z to Set Spoilboard WCS",
    description: "When a base is reserved: On (default) probes the spoilboard at job start and writes the result into the base WCS (G10 L20 P<n>). Off skips the probe and emits an Info comment assuming the base was established in a previous job (probe-once / run-many). No effect when WCS for Spoilboard is None.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  C_Probe_OnStart: {
    title      : "First Part: Set Work Origin",
    description: "Establishes the origin for the first (or only) part -- the WCS the first section resolves to (WCS 1 / G54 by default, or whatever that Setup specifies). Skip: does nothing. Set current position as origin: writes X0 Y0 Z0 at the current position with no probe (for a jet/laser or a manual touch-off). Zero XY, probe Z: sets X0 Y0 here, then probes Z. On GRBL/RepRap this writes into that WCS's own offset (G10 L20 P<n>); Marlin uses G92. To mill additional copies of the part, see \"Each Added Part: Re-probe Z\"; to mill one part from multiple datums/references or a flip, run separate jobs.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "enum",
    values: [
      { title: "Skip", id: "Skip" },
      { title: "Set current position as origin (no probe)", id: "Zero XYZ" },
      { title: "Zero XY, probe Z", id: "Zero XY & Probe Z" }
    ],
    value: "Zero XY & Probe Z",
    scope: "post"
  },
  D_Probe_OnChange: {
    title      : "Each Added Part: Re-probe Z",
    description: "Multi-fixture jobs only -- milling several copies of a part, one WCS per copy. When the job advances to the next copy's WCS (G55, G56, ...), re-probe that copy's stock-top Z and write it into that WCS's own offset (G10 L20 P<n>) on GRBL/RepRap. The copy's XY comes from its fixture's pre-set offset -- the post never sets XY for added parts. Skip: all copies share one Z (same thickness, or offsets already persisted). No effect on Marlin (single G92 origin). Does NOT support milling one part from multiple datums/references or a flip -- run those as separate jobs.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "enum",
    values: [
      { title: "Skip (copies share Z)", id: "Skip" },
      { title: "Probe Z per added part", id: "Probe Z" }
    ],
    value: "Probe Z",
    scope: "post"
  },
  E_Probe_G382orG28: {
    title      : "G38.2 (On) or G28 (Off)",
    description: "Probe using G38.2 (On) or G28 (Off). Grbl always uses G38.2 regardless of this setting; RepRap fully supports G38.2 too, so this should be left On there as well. Off (G28) is intended for Marlin builds with no dedicated probe, using the Z homing switch as a substitute reference.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  F_Probe_G38Target: {
    title      : "G38 Target",
    description: "G38 probing's furthest Z position.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "integer",
    value      : -10,
    scope      : "post"
  },
  G_Probe_G38Speed: {
    title      : "G38 Speed",
    description: "G38 probing's speed (mm/min).",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "integer",
    value      : 30,
    scope      : "post"
  },
  H_Probe_SafeZ: {
    title      : "Safe Z",
    description: "Safe Z to return to after probing.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  I_Probe_Thickness: {
    title      : "Plate Thickness",
    description: "Thickness of the probe touchplate.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "number",
    value      : 0.8,
    scope      : "post"
  },
  J_Probe_SafeZAcrossWcs: {
    title      : "Safe Z Retract Across Parts",
    description: "Multi-fixture safety. On (default): before traversing between operations that use different WCS, the tool retracts to the Cross Part Clearance below so it clears fixtures/clamps/other parts, and the job is validated (Guard B) to reject a multi-WCS job that reserves no spoilboard base -- a clearance height is meaningless across WCS whose offsets are only known after probing at runtime. Single-WCS jobs (including a single operation) are unaffected: no extra retract is emitted and the guard does not apply. Off: no cross-WCS retract and no guard. GRBL/RepRap only (Marlin is single-frame; see Guard C).",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  K_Probe_SafeZClearance: {
    title      : "Cross Part Clearance (above spoilboard)",
    description: "Absolute work-Z height, measured above the reserved spoilboard base, that the tool retracts to before traversing between parts (different WCS). Set it high enough to clear the tallest fixture, clamp, or part in the job. Only used when Safe Z Retract Across Parts is on and a base is reserved.",
    group      : "03 - Work Coordinate System - WCS / Probe",
    type       : "number",
    value      : 40,
    scope      : "post"
  },

  A_Include_StartFile: {
    title      : "Start GCode File",
    description: "File with custom Gcode for header/start (in nc folder).",
    group      : "07 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  B_Include_StopFile: {
    title      : "Stop GCode File",
    description: "File with custom Gcode for footer/end (in nc folder).",
    group      : "07 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  C_Include_ToolFile1: {
    title      : "Tool Change Start",
    description: "File with custom Gcode to start tool change (in nc folder).",
    group      : "07 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  D_Include_ToolFile2: {
    title      : "Tool Change End",
    description: "File with custom Gcode to end tool change (in nc folder).",
    group      : "07 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  E_Include_ProbeFile: {
    title      : "Probe",
    description: "File with custom Gcode for tool probe (in nc folder).",
    group      : "07 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },

  A_Laser_OnVaporize: {
    title      : "Laser: On - Vaporize",
    description: "Percentage of power to turn on the laser/plasma cutter in vaporize mode.",
    group      : "08 - Laser",
    type       : "integer",
    value      : 100,
    scope      : "post"
  },
  B_Laser_OnThrough: {
    title      : "Laser: On - Through",
    description: "Percentage of power to turn on the laser/plasma cutter in through mode.",
    group      : "08 - Laser",
    type       : "integer",
    value      : 80,
    scope      : "post"
  },
  C_Laser_OnEtch: {
    title      : "Laser: On - Etch",
    description: "Percentage of power to on the laser/plasma cutter in etch mode.",
    group      : "08 - Laser",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  D_Laser_MarlinMode: {
    title      : "Laser: Marlin/Reprap Mode",
    description: "Marlin/Reprap mode of the laser/plasma cutter.",
    group      : "08 - Laser",
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
    group      : "08 - Laser",
    type       : "integer",
    value      : 4,
    scope      : "post"
  },
  F_Laser_GrblMode: {
    title      : "Laser: GRBL Mode",
    description: "GRBL mode of the laser/plasma cutter.",
    group      : "08 - Laser",
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
    group      : "08 - Laser",
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
    group      : "09 - Coolant",
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
    group      : "09 - Coolant",
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
    group      : "09 - Coolant",
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
    group      : "09 - Coolant",
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
    group      : "09 - Coolant",
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
    group      : "09 - Coolant",
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
    group      : "09 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  H_Coolant_ChannelAOffCustom: {
    title      : "Channel A Off Custom",
    description: "File with custom GCode to turn OFF coolant channel A (in nc folder).",
    group      : "09 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  I_Coolant_ChannelBOnCustom: {
    title      : "Channel B On Custom",
    description: "File with custom GCode to turn ON coolant channel B (in nc folder).",
    group      : "09 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  J_Coolant_ChannelBOffCustom: {
    title      : "Channel B Off Custom",
    description: "File with custom GCode to turn OFF coolant channel B (in nc folder).",
    group      : "09 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },

  A_Duet_MillingMode: {
    title      : "Milling Mode",
    description: "GCode  to setup Duet3d into milling mode.",
    group      : "10 - Duet",
    type       : "string",
    value      : "M453 P2 I0 R30000 F200",
    scope      : "post"
  },
  B_Duet_LaserMode: {
    title      : "Laser Mode",
    description: "GCode  to setup Duet3d into laser mode.",
    group      : "10 - Duet",
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

var feedFormat = createFormat({ decimals: (unit == MM ? 0 : 2) });
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
  if (fw == eFirmware.GRBL) {
  }

  // Default
  else {
    writeBlock(mFormat.format(400));
  }
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
var safeZHeightDefault = 15;
var safeZHeight;

function parseSafeZProperty() {
  var str = getProperty(properties.C_MapRapids_SafeZ);

  // Look for either a number by itself or 'Feed:', 'Retract:' or 'Clearance:'
  for (safeZMode = eSafeZ.CONST; safeZMode < eSafeZ.ERROR; safeZMode++) {
    if (str.search(eSafeZ.prop[safeZMode].regex) == 0) {
      break;
    }
  }

  // If it was not an error then get the number
  if (safeZMode != eSafeZ.ERROR) {
    var match = str.match(eSafeZ.prop[safeZMode].numRegEx);

    if ((match == null) || (match.length != 2)) {
      writeComment(eComment.Debug, " parseSafeZProperty: " + match);
      writeComment(eComment.Debug, " parseSafeZProperty.length: " + (match != null ? match.length : "na"));
      writeComment(eComment.Debug, " parseSafeZProperty: Couldn't find number");
      safeZMode = eSafeZ.ERROR;
      safeZHeightDefault = 15;
    }
    else {
      safeZHeightDefault = Number(match[1]);
    }
  }

  writeComment(eComment.Debug, " parseSafeZProperty: safeZMode = '" + eSafeZ.prop[safeZMode].name + "'");
  writeComment(eComment.Debug, " parseSafeZProperty: safeZHeightDefault = " + safeZHeightDefault);
}

function safeZforSection(_section) 
{
  if (getProperty(properties.B_MapRapids_RestoreRapids)) {
    switch (safeZMode) {
      case eSafeZ.CONST:
        safeZHeight = safeZHeightDefault;
        writeComment(eComment.Important, " SafeZ using const: " + safeZHeight);
        break;

      case eSafeZ.FEED:
        if (hasParameter("operation:feedHeight_value") && hasParameter("operation:feedHeight_absolute")) {
          let feed = _section.getParameter("operation:feedHeight_value");
          let abs = _section.getParameter("operation:feedHeight_absolute");

          if (abs == 1) {
            safeZHeight = feed;
            writeComment(eComment.Info, " SafeZ feed level: " + safeZHeight);
          }
          else {
            safeZHeight = safeZHeightDefault;
            writeComment(eComment.Important, " SafeZ feed level not abs: " + safeZHeight);
          }
        }
        else {
          safeZHeight = safeZHeightDefault;
          writeComment(eComment.Important, " SafeZ feed level not defined: " + safeZHeight);
        }
        break;

      case eSafeZ.RETRACT:
        if (hasParameter("operation:retractHeight_value") && hasParameter("operation:retractHeight_absolute")) {
          let retract = _section.getParameter("operation:retractHeight_value");
          let abs = _section.getParameter("operation:retractHeight_absolute");

          if (abs == 1) {
            safeZHeight = retract;
            writeComment(eComment.Info, " SafeZ retract level: " + safeZHeight);
          }
          else {
            safeZHeight = safeZHeightDefault;
            writeComment(eComment.Important, " SafeZ retract level not abs: " + safeZHeight);
          }
        }
        else {
          safeZHeight = safeZHeightDefault;
          writeComment(eComment.Important, " SafeZ: retract level not defined: " + safeZHeight);
        }
        break;

      case eSafeZ.CLEARANCE:
        if (hasParameter("operation:clearanceHeight_value") && hasParameter("operation:clearanceHeight_absolute")) {
          let clearance = _section.getParameter("operation:clearanceHeight_value");
          let abs = _section.getParameter("operation:clearanceHeight_absolute");

          if (abs == 1) {
            safeZHeight = clearance;
            writeComment(eComment.Info, " SafeZ clearance level: " + safeZHeight);
          }
          else {
            safeZHeight = safeZHeightDefault;
            writeComment(eComment.Important, " SafeZ clearance level not abs: " + safeZHeight);
          }
        }
        else {
          safeZHeight = safeZHeightDefault;
          writeComment(eComment.Important, " SafeZ clearance level not defined: " + safeZHeight);
        }
        break;
        
      case eSafeZ.ERROR:
        safeZHeight = safeZHeightDefault;
        writeComment(eComment.Important, " >>> WARNING: " + properties.C_MapRapids_SafeZ.title + " format error: " + safeZHeight);
        break;
    }
  }
}


function roundTo(value, places) {
  return +(Math.round(value + "e+" + places) + "e-" + places);
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

function CoolantA(on) {
  var coolantText = on ? getProperty(properties.C_Coolant_ChannelAOn) : getProperty(properties.D_Coolant_ChannelAOff);

  if (coolantText == "Use custom") {
    coolantText = on ? getProperty(properties.G_Coolant_ChannelAOnCustom) : getProperty(properties.H_Coolant_ChannelAOffCustom);
  }

  writeBlock(coolantText);
}

function CoolantB(on) {
  var coolantText = on ? getProperty(properties.E_Coolant_ChannelBOn) : getProperty(properties.F_Coolant_ChannelBOff);

  if (coolantText == "Use custom") {
    coolantText = on ? getProperty(properties.I_Coolant_ChannelBOnCustom) : getProperty(properties.J_Coolant_ChannelBOffCustom);
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

    writeBlock(mFormat.format(getProperty(properties.F_Laser_GrblMode)), sFormat.format(laser_pwm));
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
  var onStart = getProperty(properties.C_Probe_OnStart) != "Skip";
  var onChange = getProperty(properties.D_Probe_OnChange) != "Skip";
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
      if (onStart && wo == base) return "Probe at Job Start";
    } else {
      if (onChange && wo != prevWo && wo == base) return "Probe on WCS Change";
    }
    var toolChanged = (i == 0) ? doFirstChange : (toolNum != prevTool);
    if (reprobe && toolChanged && wo == base) return "Probe After Tool Change";
    prevWo = wo;
    prevTool = toolNum;
  }
  return null;
}

// Post-time validation guards (see docs/wcs-rework-plan.md "Validation guards").
// Runs once from onOpen(), before any output, so a misconfiguration fails fast.
function validateJob() {
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
    if (getProperty(properties.J_Probe_SafeZAcrossWcs) && collectDistinctOffsets().length > 1) {
      error("Safe-Z across parts requires a base: reserve a spoilboard base (\"WCS for Spoilboard\"), or turn off \"Safe Z Retract Across Parts\".");
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

function onOpen() {
  fw = getProperty(properties.A_Job_SelectedFirmware);

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

  // Set the starting sequence number for line numbering
  sequenceNumber = getProperty(properties.F_Job_SequenceNumberStart);

  // No work offset emitted yet
  currentWorkOffset = undefined;

  // Set the seperator used between text
  if (!getProperty(properties.H_Job_SeparateWordsWithSpace)) {
    setWordSeparator("");
  }

  // Determine the safeZHeight to do rapids
  parseSafeZProperty();
}

// Called at end of gcode file
function onClose() {
  writeComment(eComment.Important, " *** STOP begin ***");

  flushMotions();

  if (getProperty(properties.B_Include_StopFile) == "") {
    onCommand(COMMAND_COOLANT_OFF);
    if (getProperty(properties.I_Job_GoOriginOnFinish)) {
      rapidMovementsXY(0, 0);
    }
    onCommand(COMMAND_STOP_SPINDLE);

    flushMotions();

    // Is Grbl?
    if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(30));
    }
  
    // Default
    else {
      display_text("Job end");
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
    if (getProperty(properties.D_Probe_OnChange) != "Skip" && workOffset != currentWorkOffset) {
      writeComment(eComment.Important, " >>> WARNING: D_Probe_OnChange \"Probe Z\" on WCS change has no effect on Marlin; Marlin has no WCS changes to react to, only its single G92 origin");
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
  // Decide up front whether this WCS change re-probes the new part (D_Probe_OnChange =
  // "Each Added Part: Re-probe Z"). Each WCS has its own G10-scoped Z; the first is set by
  // C_Probe_OnStart in writeFirstSection(), so this is only for the added copies. Compute
  // it before the switch so the pre-switch retract below runs while the OUTGOING WCS --
  // whose Z is established -- is still active.
  var onChangeMode = getProperty(properties.D_Probe_OnChange);
  var probeNewPart = (previousWorkOffset != undefined && onChangeMode == "Probe Z"
                      && tool.number != 0 && !tool.isJetTool());
  writeComment(eComment.Debug, " writeWCS: D_Probe_OnChange: " + onChangeMode
    + " previousWorkOffset: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset)
    + " probeNewPart: " + probeNewPart);

  // Retract Z to a safe height FIRST, before selecting the new WCS -- the new WCS's Z origin
  // is unknown until we probe it, so an absolute Z move there would be unsafe. Two cases:
  //  - Base reserved + cross-WCS safe-Z enabled: transit through the spoilboard base and
  //    clear to Cross Part Clearance -- a stable height above the spoilboard that clears
  //    fixtures across parts of differing thickness (retractThroughBaseClearance()).
  //  - Otherwise (no base, or the destination IS the base): fall back to Safe Z in the
  //    OUTGOING part's frame. Not the stable cross-part reference, but the tool is at least
  //    clear enough to reposition for the re-probe. (Guard B blocks the risky no-base
  //    multi-WCS case up front, so this fallback only runs when the feature is off.)
  var base = getReservedBaseWcs();
  var baseRelative = probeNewPart && getProperty(properties.J_Probe_SafeZAcrossWcs)
                     && base != 0 && base != workOffset;
  writeComment(eComment.Debug, " writeWCS: retract decision -- baseRelative: " + baseRelative
    + " base: " + base + " J_SafeZAcrossWcs: " + getProperty(properties.J_Probe_SafeZAcrossWcs)
    + " workOffset: " + workOffset);
  if (baseRelative) {
    retractThroughBaseClearance();
  } else if (probeNewPart) {
    writeComment(eComment.Info, "   Retract before WCS change -- re-probe of the new part follows");
    resetAll();
    rapidMovementsZ(propertyMmToUnit(getProperty(properties.H_Probe_SafeZ)));
    flushMotions();
  }

  writeComment(eComment.Info, " WCS changed: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset) + " -> " + workOffset);
  writeBlock(gFormat.format(offsetCode));
  currentWorkOffset = workOffset;

  if (probeNewPart) {
    // After the switch the tool is still over the PREVIOUS part's XY -- probing here would
    // measure the previous part / fixture and write a bogus Z into the new WCS. Rapid to
    // the new part's reference (X0 Y0) first; this emits X/Y only, so Z stays at the safe
    // height set above. XY comes from the new WCS's pre-set offset -- we do not re-zero it.
    // (A configurable probe XY offset, applied here and at first-part probing, is a tracked
    // follow-up; for now the probe point is the origin.)
    resetAll();
    writeComment(eComment.Info, "   Move to new part origin X0 Y0, then probe Z");
    rapidMovementsXY(0, 0);
    flushMotions();
    onCommand(COMMAND_TOOL_MEASURE);
  } else if (previousWorkOffset != undefined && onChangeMode == "Probe Z") {
    writeComment(eComment.Debug, " writeWCS: D_Probe_OnChange probe skipped (tool 0 or jet tool)");
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
// 7-9 = G59.1-G59.3), or 0 when the feature is off ("None"). The A_Probe_BaseReserve
// enum ids are the numbers directly, so this also validates the raw value.
function getReservedBaseWcs() {
  var v = getProperty(properties.A_Probe_BaseReserve);
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

// Retract to the "Cross Part Clearance" height measured above the reserved spoilboard base,
// by transiting THROUGH the base WCS. The base's Z was established at job start
// (writeBaseEstablish), so it is the one frame where an absolute safe height is meaningful
// across parts of differing thickness. Selects the base with a plain frame switch -- NOT
// writeWCS(), so it triggers no D_Probe_OnChange re-probe and writes no origin -- then
// commands the clearance (a real Z move, so this is never an empty base round-trip). LEAVES
// the base active; the caller selects the destination WCS next. Caller guarantees a base is
// reserved. See docs/wcs-rework-plan.md "Base WCS is transited, not parked".
function retractThroughBaseClearance() {
  var base = getReservedBaseWcs();
  writeComment(eComment.Info, "   Retract to spoilboard-base clearance " + wcsName(base) + " before traverse");
  writeBlock(gFormat.format(wcsGcode(base)));   // transit-select the base frame (no re-probe)
  currentWorkOffset = base;
  resetAll();
  rapidMovementsZ(propertyMmToUnit(getProperty(properties.K_Probe_SafeZClearance)));
  flushMotions();
}

function onSection() {
  // Multi-axis toolpaths aren't supported (only 3-axis / 2D-jet). Fail at the start of
  // the offending operation with a clear message, rather than partway through its motion
  // (onLinear5D/onRapid5D also guard, as a backstop).
  if (currentSection.isMultiAxis()) {
    error(localize("Multi-axis toolpath is not supported. Use a 3-axis milling or 2D/jet strategy."));
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
    linearMovements(x, y, z, feed, true);
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

  // Display the Feedrate and Scaling Properties
  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " Feedrate and Scaling Properties:");
  writeComment(eComment.Info, "   Feed: Travel speed X/Y = " + getProperty(properties.A_Feeds_TravelSpeedXY));
  writeComment(eComment.Info, "   Feed: Travel Speed Z = " + getProperty(properties.B_Feeds_TravelSpeedZ));
  writeComment(eComment.Info, "   Feed: Enforce Feedrate = " + getProperty(properties.C_Feeds_EnforceFeedrate));
  writeComment(eComment.Info, "   Feed: Scale Feedrate = " + getProperty(properties.D_Feeds_ScaleFeedrate));
  writeComment(eComment.Info, "   Feed: Max XY Cut Speed = " + getProperty(properties.E_Feeds_MaxCutSpeedXY));
  writeComment(eComment.Info, "   Feed: Max Z Cut Speed = " + getProperty(properties.F_Feeds_MaxCutSpeedZ));
  writeComment(eComment.Info, "   Feed: Max Toolpath Speed = " + getProperty(properties.G_Feeds_MaxCutSpeedXYZ));
 
  // Display the G1->G0 Mapping Properties
  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " G1->G0 Mapping Properties:");
  writeComment(eComment.Info, "   Map: First G1 -> G0 Rapid = " + getProperty(properties.A_MapRapids_RestoreFirstRapids));
  writeComment(eComment.Info, "   Map: G1s -> G0 Rapids = " + getProperty(properties.B_MapRapids_RestoreRapids));
  writeComment(eComment.Info, "   Map: SafeZ Mode = " + eSafeZ.prop[safeZMode].name + " : default = " + safeZHeightDefault);
  writeComment(eComment.Info, "   Map: Allow Rapid Z = " + getProperty(properties.D_MapRapids_AllowRapidZ));

  writeComment(eComment.Info, " ");
}

// Implements A_Machine_HomeX/B_Machine_HomeY/C_Machine_HomeZ: establishes the machine
// frame (MCS) at job start, once, before anything work-relative. X/Y homing is what
// actually gives MCS a repeatable origin (plus gantry squaring); Z homing, where
// wired, is included for its own reason (a real endstop, or the Marlin plate-homing
// trick) -- it is never in service of MCS and never becomes the everyday Z reference,
// which stays the work-Z touch-off (C_Probe_OnStart / D_Probe_OnChange) regardless.
function writeMachineHoming() {
  var axes = [
    { name: "X", home: getProperty(properties.A_Machine_HomeX) == "Home" },
    { name: "Y", home: getProperty(properties.B_Machine_HomeY) == "Home" },
    { name: "Z", home: getProperty(properties.C_Machine_HomeZ) == "Home" }
  ];

  writeComment(eComment.Debug, " writeMachineHoming: entry fw: " + fw);
  for (var i = 0; i < axes.length; ++i) {
    writeComment(eComment.Debug, " writeMachineHoming: " + axes[i].name + ": "
      + (axes[i].home ? "Home (asserted wired)" : "Power-On (current position accepted as zero, no motion)"));
  }

  if (fw == eFirmware.GRBL) {
    // $H is all-or-nothing on stock GRBL/FluidNC -- the per-axis pickers above are
    // bookkeeping only (which axes the user asserts are wired); one combined $H fires
    // if any axis is set to Home, never a per-axis command.
    if (axes[0].home || axes[1].home || axes[2].home) {
      writeComment(eComment.Debug, " writeMachineHoming: GRBL/FluidNC, emitting single combined $H");
      writeBlock("$H");
    } else {
      writeComment(eComment.Debug, " writeMachineHoming: GRBL/FluidNC, no axis set to Home, no $H emitted");
    }
    return;
  }

  // Marlin / RepRap: true independent G28 <axis> per axis set to Home.
  if (axes[0].home) {
    writeComment(eComment.Debug, " writeMachineHoming: " + fw + ", emitting G28 X");
    writeBlock(gFormat.format(28), "X");
  }
  if (axes[1].home) {
    writeComment(eComment.Debug, " writeMachineHoming: " + fw + ", emitting G28 Y");
    writeBlock(gFormat.format(28), "Y");
  }
  if (axes[2].home) {
    // The prompt only matters for Marlin's plate-as-Z-min-pin trick (a movable plate
    // must be placed before Z can home to it) -- RRF/Duet Z homing (where wired) is a
    // real switch, no attach step needed.
    if (fw == eFirmware.MARLIN && getProperty(properties.D_Machine_PromptBeforeHome)) {
      writeComment(eComment.Debug, " writeMachineHoming: Marlin, prompting before Z home (plate-homed)");
      askUser("Attach Z-homing plate", "Homing", false);
    }
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
//   6. writeWcsOnStart()     -- C_Probe_OnStart: the initial origin for the WCS from 3
// Only step 3 (writeWCS) is not intrinsically first-section work -- every section selects
// its WCS. It lives here because steps 4-6 may write an origin on top of the active WCS,
// so the WCS must be selected first. That is the deliberate reason WCS selection is split:
// section 1 selects here (mid-preamble, before its origin write); every later section
// selects in onSection()'s body. See the matching note at the writeWCS() call there.
function writeFirstSection() {
  // Write out the information block at the beginning of the file
  writeInformation();

  // Establish the machine frame (MCS) before anything work-relative -- home (or
  // accept power-on) each axis per A_Machine_HomeX/B_Machine_HomeY/C_Machine_HomeZ.
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

// Implements A_Probe_BaseReserve / B_Probe_BaseEstablish: at job start, establish the
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

  if (!getProperty(properties.B_Probe_BaseEstablish)) {
    writeComment(eComment.Info, "   assuming base " + gname + " is already established -- from a prior job or set manually");
    return;
  }

  if (tool.number != 0 && !tool.isJetTool()) {
    writeComment(eComment.Important, " Establish spoilboard base " + gname);
    probeTool(base);
  } else {
    writeComment(eComment.Debug, " writeBaseEstablish: probe skipped (tool 0 or jet tool)");
  }
}

// Implements the C_Probe_OnStart property: establishes the origin for the WCS
// writeWCS() just selected for the first section, scoped to that WCS via
// writeWcsOrigin() (G10 on GRBL/RepRap, G92 on Marlin).
function writeWcsOnStart() {
  var mode = getProperty(properties.C_Probe_OnStart);
  writeComment(eComment.Debug, " writeWcsOnStart: C_Probe_OnStart: " + mode + " wcs: " + currentWorkOffset);

  if (mode == "Skip") {
    writeComment(eComment.Debug, " writeWcsOnStart: Skip selected, nothing emitted");
    return;
  }

  if (mode == "Zero XYZ") {
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeWcsOrigin(currentWorkOffset, 0, 0, 0);
    return;
  }

  // "Zero XY & Probe Z"
  writeComment(eComment.Info, "   Set current X,Y position to 0,0");
  writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
  if (tool.number != 0 && !tool.isJetTool()) {
    onCommand(COMMAND_TOOL_MEASURE);
  } else {
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

    return lesserFeed;
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
      writeComment(eComment.Info, " --- End custom gcode " + folder + _file);
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

function spindleOn(_spindleSpeed, _clockwise) {
  if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
    // For manual any positive input speed assumed as enabled. so it's just a flag
    if (!spindleEnabled) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual");
      askUser("Turn ON " + speedFormat.format(_spindleSpeed) + "RPM", "Spindle", false);
    }
  } else {
    writeComment(eComment.Important, " >>> Spindle Speed " + speedFormat.format(_spindleSpeed));
    writeBlock(mFormat.format(_clockwise ? 3 : 4), sOutput.format(_spindleSpeed));
  }

  spindleEnabled = true;
}

function spindleOff() {
  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    writeBlock(mFormat.format(5));
  }

  //Default
  else {
    if (getProperty(properties.B_Job_ManualSpindlePowerControl)) {
      writeBlock(mFormat.format(300), sFormat.format(300), pFormat.format(3000));
      askUser("Turn OFF spindle", "Spindle", false);
    } else {
      writeBlock(mFormat.format(5));
    }
  }

  spindleEnabled = false;
}

// Collapse newlines and any of `unsafeChars` into a single space, so user-supplied text
// (tool comments, operation names) embedded in a G-code message or comment can't break
// line syntax, comment syntax, or quoted parameters. Runs of collapsed characters become a
// single space; leading/trailing whitespace is preserved so callers keep their own indentation.
function sanitizeMessageText(text, unsafeChars) {
  return String(text).replace(new RegExp("[\\r\\n" + unsafeChars + "]+", "g"), " ");
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
  // If tool changes are not to be include in the NC file then exit
  if (!getProperty(properties.A_ToolChange_Enabled))
    return;

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
      askUser("Z Stepper will disabled. Wait for STOP!!", "Tool change", false);
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
function probeTool(targetWcs) {
  if (targetWcs == undefined) {
    targetWcs = currentWorkOffset;
  }
  // Command comment block
  writeComment(eComment.Important, " Probe to Zero Z");
  writeComment(eComment.Info, "   Ask User to Attach the Z Probe");
  writeComment(eComment.Info, "   Do Probing");
  writeComment(eComment.Info, "   Set Z to probe thickness: " + zFormat.format(propertyMmToUnit(getProperty(properties.I_Probe_Thickness))));
  writeComment(eComment.Info, "   Retract the tool to " + propertyMmToUnit(getProperty(properties.H_Probe_SafeZ)));
  writeComment(eComment.Info, "   Ask User to Remove the Z Probe");
  
  askUser("Attach ZProbe", "Probe", false);

  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    // refer to http://linuxcnc.org/docs/stable/html/gcode/g-code.html#gcode:g38
    // Note this is not using the optional P parameter available on FluidNC (http://wiki.fluidnc.com/en/config/probe)
    writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.G_Probe_G38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.F_Probe_G38Target))));
  }

  // Not GRBL
  else {
    // refer http://marlinfw.org/docs/gcode/G038.html
    if (getProperty(properties.E_Probe_G382orG28)) {
      writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.G_Probe_G38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.F_Probe_G38Target))));
    } else {
      writeBlock(gFormat.format(28), 'Z');
    }
  }

  writeWcsOrigin(targetWcs, undefined, undefined, propertyMmToUnit(getProperty(properties.I_Probe_Thickness)));

  resetAll();
  // move up tool to safe height again after probing
  rapidMovementsZ(propertyMmToUnit(getProperty(properties.H_Probe_SafeZ)));
  
  flushMotions();

  askUser("Detach ZProbe", "Probe", false);
}