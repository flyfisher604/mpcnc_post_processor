/*
**
Version 3.0 (Beta 1)

Updated to new method of handling properties

MPCNC posts processor for milling and laser/plasma cutting.

Changed Feb 2, 2025
**
*/

description = "v3.0 (Beta 1) MPCNC Milling/Laser for Marlin, Grbl, RepRap";
vendor = "flyfisher604";
vendorUrl = "https://github.com/flyfisher604/mpcnc_post_processor";
longDescription = "MPCNC F360 Post processor. Supports scaling of speeds to accomidate slow Z axis. Warning: BETA review all GCode.";

// Internal properties
legal = "Copyright (C) 2019 - 2025 Don Gamble.";
certificationLevel = 2;
minimumRevision = 45917

extension = "gcode";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_JET;
// tolerance = spatial(0.002, MM);

// Arc support variables
minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined;

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
  job0_SelectedFirmware: {
    title      : "CNC Firmware",
    description: "Dialect of GCode to create.",
    group      : "1 - Job",
    type       : "enum",
    values: [
      { title: eFirmware.MARLIN, id: eFirmware.MARLIN},
      { title: eFirmware.GRBL, id: eFirmware.GRBL },
      { title: eFirmware.REPRAP, id: eFirmware.REPRAP }
    ],
    value: eFirmware.MARLIN,
    scope: "post"
  },
  job1_SetOriginOnStart: {
    title      : "Zero Starting Location (G92)",
    description: "On start, set the current location as 0,0,0 (G92).",
    group      : "1 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  job2_ManualSpindlePowerControl: {
    title      : "Manual Spindle On/Off",
    description: "Enable to manually turn spindle motor on/off.",
    group      : "1 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  job3_CommentLevel: {
    title      : "Comment Level",
    description: "Detail of comments included.",
    group      : "1 - Job",
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
  job4_UseArcs: {
    title      : "Use Arcs",
    description: "Use G2/G3 g-codes fo circular movements.",
    group      : "1 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  job5_SequenceNumbers: {
    title      : "Enable Line #s",
    description: "Include line numbers on each line.",
    group      : "1 - Job",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  job6_SequenceNumberStart: {
    title      : "First Line #",
    description: "First line number used.",
    group      : "1 - Job",
    type       : "integer",
    value      : 10,
    scope      : "post"
  },
  job7_SequenceNumberIncrement: {
    title      : "Line # Increment",
    description: "Increase line numbers by this increment.",
    group      : "1 - Job",
    type       : "integer",
    value      : 1,
    scope      : "post"
  },
  job8_SeparateWordsWithSpace: {
    title      : "Include Whitespace",
    description: "Includes whitespace seperation between text.",
    group      : "1 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  job9_GoOriginOnFinish: {
    title      : "At end go to 0,0",
    description: "Return to X0 Y0 at gcode end, Z remains unchanged.",
    group      : "1 - Job",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },

  fr0_TravelSpeedXY: {
    title      : "Travel speed X/Y",
    description: "High speed for Rapid movements X & Y (mm/min).",
    group      : "2 - Feeds and Speeds",
    type       : "integer",
    value      : 2500,
    scope      : "post"
  },
  fr1_TravelSpeedZ: {
    title      : "Travel Speed Z",
    description: "High speed for Rapid movements Z (mm/min).",
    group      : "2 - Feeds and Speeds",
    type       : "integer",
    value      : 300,
    scope      : "post"
  },
  fr2_EnforceFeedrate: {
    title      : "Enforce Feedrate",
    description: "Feedrate is include on every g-code movement.",
    group      : "2 - Feeds and Speeds",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  frA_ScaleFeedrate: {
    title      : "Scale Feedrate",
    description: "Scale feedrates to remain less than X, Y, Z axis maximums.",
    group      : "2 - Feeds and Speeds",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  frB_MaxCutSpeedXY: {
    title      : "Max XY Cut Speed",
    description: "Limit X or Y feedrate to be less then this value (mm/min).",
    group      : "2 - Feeds and Speeds",
    type       : "integer",
    value      : 900,
    scope      : "post"
  },
  frC_MaxCutSpeedZ: {
    title      : "Max Z Cut Speed",
    description: "Limit Z feedrate to be less then this value (mm/min).",
    group      : "2 - Feeds and Speeds",
    type       : "integer",
    value      : 180,
    scope      : "post"
  },
  frD_MaxCutSpeedXYZ: {
    title      : "Max Toolpath Speed",
    description: "Maximum scaled toolpath feedrate (mm/min).",
    group      : "2 - Feeds and Speeds",
    type       : "integer",
    value      : 1000,
    scope      : "post"
  },

  mapD_RestoreFirstRapids: {
    title      : "First G1 -> G0 Rapid",
    description: "Enable to ensure that the first move of a cut starts with a G0 Rapid.",
    group      : "3 - Map Rapids",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  mapE_RestoreRapids: {
    title      : "Map: G1s -> G0 Rapids",
    description: "Enable to convert G1s to G0s Rapids when safe.",
    group      : "3 - Map Rapids",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  mapF_SafeZ: {
    title      : "Map: Safe Z to Rapid",
    description: "Z must be above or equal to this value to be mapped G1s --> G0s; Uses Retract level if defined or 15.",
    group      : "3 - Map Rapids",
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },
  mapG_AllowRapidZ: {
    title      : "Map: Allow Rapid Z",
    description: "Enable to include vertical G1 retracts and safe descents as rapids.",
    group      : "3 - Map Rapids",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  toolChange0_Enabled: {
    title      : "Tool Changes are Included",
    description: "Tool changes are include in the NC file.",
    group      : "4 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  toolChange1_InsertCode: {
    title      : "Include Relocation Code",
    description: "Relocate the tool for manual tool changes.",
    group      : "4 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  toolChange2_X: {
    title      : "Tool Change: X",
    description: "X location for tool change.",
    group      : "4 - Tool Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  toolChange3_Y: {
    title      : "Tool Change: Y",
    description: "Y location for tool change.",
    group      : "4 - Tool Changes",
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  toolChange4_Z: {
    title      : "Tool Change: Z",
    description: "Z location for tool change.",
    group      : "4 - Tool Changes",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  toolChange5_DisableZStepper: {
    title      : "Disable Z stepper",
    description: "Disable Z stepper after reaching tool change location.",
    group      : "4 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  toolChange6_DoFirstChange: {
    title      : "Do First Change",
    description: "Do an initial tool change to load first tool.",
    group      : "4 - Tool Changes",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },

  probe1_OnStart: {
    title      : "On job start",
    description: "Include GCode to probe on job start.",
    group      : "5 - Probe",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  probe2_OnToolChange: {
    title      : "After Tool Change",
    description: "After tool change, probe Z at the current location.",
    group      : "5 - Probe",
    type       : "boolean",
    value      : false,
    scope      : "post"
  },
  probe3_Thickness: {
    title      : "Plate thickness",
    description: "Thickness of the probe touchplate.",
    group      : "5 - Probe",
    type       : "integer",
    value      : 0.8,
    scope      : "post"
  },
  probe4_UseHomeZ: {
    title      : "Use Home Z (G28)",
    description: "Probe with G28 (Yes) or G38 (No).",
    group      : "5 - Probe",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  probe5_G38Target: {
    title      : "G38 target",
    description: "G38 probing's furthest Z position.",
    group      : "5 - Probe",
    type       : "integer",
    value      : -10,
    scope      : "post"
  },
  probe6_G38Speed: {
    title      : "G38 speed",
    description: "G38 probing's speed (mm/min).",
    group      : "5 - Probe",
    type       : "integer",
    value      : 30,
    scope      : "post"
  },
  probe7_SafeZ: {
    title      : "Safe Z",
    description: "Safe Z to return to after probing.",
    group      : "5 - Probe",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },

  gcodeStartFile: {
    title      : "Start GCode File",
    description: "File with custom Gcode for header/start (in nc folder).",
    group      : "6 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  gcodeStopFile: {
    title      : "Stop GCode File",
    description: "File with custom Gcode for footer/end (in nc folder).",
    group      : "6 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  gcodeToolFile1: {
    title      : "Tool Change Start",
    description: "File with custom Gcode to start tool change (in nc folder).",
    group      : "6 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  gcodeToolFile2: {
    title      : "Tool Change End",
    description: "File with custom Gcode to end tool change (in nc folder).",
    group      : "6 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  gcodeProbeFile: {
    title      : "Probe",
    description: "File with custom Gcode for tool probe (in nc folder).",
    group      : "6 - External Include Files",
    type       : "string",
    value      : "",
    scope      : "post"
  },

  cutter1_OnVaporize: {
    title      : "Laser: On - Vaporize",
    description: "Percentage of power to turn on the laser/plasma cutter in vaporize mode.",
    group      : "7 - Laser",
    type       : "integer",
    value      : 100,
    scope      : "post"
  },
  cutter2_OnThrough: {
    title      : "Laser: On - Through",
    description: "Percentage of power to turn on the laser/plasma cutter in through mode.",
    group      : "7 - Laser",
    type       : "integer",
    value      : 80,
    scope      : "post"
  },
  cutter3_OnEtch: {
    title      : "Laser: On - Etch",
    description: "Percentage of power to on the laser/plasma cutter in etch mode.",
    group      : "7 - Laser",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  cutter3_OnEtch: {
    title      : "Laser: On - Etch",
    description: "Percentage of power to on the laser/plasma cutter in etch mode.",
    group      : "7 - Laser",
    type       : "integer",
    value      : 40,
    scope      : "post"
  },
  cutter4_MarlinMode: {
    title      : "Laser: Marlin/Reprap Mode",
    description: "Marlin/Reprap mode of the laser/plasma cutter.",
    group      : "7 - Laser",
    type       : "enum",
    values: [
      { title: "Fan - M106 S{PWM}/M107", id: "106" },
      { title: "Spindle - M3 O{PWM}/M5", id: "3" },
      { title: "Pin - M42 P{pin} S{PWM}", id: "42" }
    ],
    value: "106",
    scope: "post"
  },
  cutter5_MarlinPin: {
    title      : "Laser: Marlin M42 Pin",
    description: "Marlin custom pin number for the laser/plasma cutter.",
    group      : "7 - Laser",
    type       : "integer",
    value      : 4,
    scope      : "post"
  },
  cutter6_GrblMode: {
    title      : "Laser: GRBL Mode",
    description: "GRBL mode of the laser/plasma cutter.",
    group      : "7 - Laser",
    type       : "enum",
    values: [
      { title: "M4 S{PWM}/M5 dynamic power", id: "4" },
      { title: "M3 S{PWM}/M5 static power", id: "3" }
    ],
    value      : "4",
    scope      : "post"
  },
  cutter7_Coolant: {
    title      : "Laser: Coolant",
    description: "Force a coolant to be used with the laser.",
    group      : "7 - Laser",
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

  cl0_coolantA_Mode: {
    title      : "Channel A Mode",
    description: "Enable channel A when tool is set this coolant.",
    group      : "8 - Coolant",
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
  cl1_coolantB_Mode: {
    title      : "Channel B Mode",
    description: "Enable channel B when tool is set this coolant.",
    group      : "8 - Coolant",
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
  cl2_coolantAOn: {
    title      : "Turn Channel A On",
    description: "GCode to turn On coolant channel A.",
    group      : "8 - Coolant",
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
  cl3_coolantAOff: {
    title      : "Turn Channel A Off",
    description: "Gcode to turn Off coolant channel A.",
    group      : "8 - Coolant",
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
  cl4_coolantBOn: {
    title      : "Turn Channel B On",
    description: "GCode to turn On coolant channel B.",
    group      : "8 - Coolant",
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
  cl5_coolantBOff: {
    title      : "Turn Channel B Off",
    description: "Gcode to turn Off coolant channel B.",
    group      : "8 - Coolant",
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
  cl6_cust_coolantAOn: {
    title      : "Channel A On Custom",
    description: "File with custom GCode to turn ON coolant channel A (in nc folder).",
    group      : "8 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  cl7_cust_coolantAOff: {
    title      : "Channel A Off Custom",
    description: "File with custom GCode to turn OFF coolant channel A (in nc folder).",
    group      : "8 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  cl8_cust_coolantBOn: {
    title      : "Channel B On Custom",
    description: "File with custom GCode to turn ON coolant channel B (in nc folder).",
    group      : "8 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },
  cl9_cust_coolantBOff: {
    title      : "Channel B Off Custom",
    description: "File with custom GCode to turn OFF coolant channel B (in nc folder).",
    group      : "8 - Coolant",
    type       : "string",
    value      : "",
    scope      : "post"
  },

  DuetMillingMode: {
    title      : "Milling mode",
    description: "GCode  to setup Duet3d into milling mode.",
    group      : "9 - Duet",
    type       : "string",
    value      : "M453 P2 I0 R30000 F200",
    scope      : "post"
  },
  DuetLaserMode: {
    title      : "Laser mode",
    description: "GCode  to setup Duet3d into laser mode.",
    group      : "9 - Duet",
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
  if (getProperty(properties.job5_SequenceNumbers)) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += getProperty(properties.job7_SequenceNumberIncrement);
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
    2: {name: "Retract", regex: /^Retract:/i, numRegEx: /:(\d+\.?\d*)$/, alue: 2},
    3: {name: "Clearance", regex: /^Clearance:/i, numRegEx: /:(\d+\.?\d*)$/, value: 3},
    4: {name: "Error", regex: /^$/, numRegEx: /^$/, value: 4}
  }
};

var safeZMode = eSafeZ.CONST;
var safeZHeightDefault = 15;
var safeZHeight;

function parseSafeZProperty() {
  var str = getProperty(properties.mapF_SafeZ);

  // Look for either a number by itself or 'Feed:', 'Retract:' or 'Clearance:'
  for (safeZMode = eSafeZ.CONST; safeZMode < eSafeZ.ERROR; safeZMode++) {
    if (str.search(eSafeZ.prop[safeZMode].regex) == 0) {
      break;
    }
  }

  // If it was not an error then get the number
  if (safeZMode != eSafeZ.ERROR) {
    safeZHeightDefault = str.match(eSafeZ.prop[safeZMode].numRegEx);

    if ((safeZHeightDefault == null) || (safeZHeightDefault.length !=2)) {
      writeComment(eComment.Debug, " parseSafeZProperty: " + safeZHeightDefault);
      writeComment(eComment.Debug, " parseSafeZProperty.length: " + (safeZHeightDefault != null? safeZHeightDefault.length : "na"));
      writeComment(eComment.Debug, " parseSafeZProperty: Couldn't find number");
      safeZMode = eSafeZ.ERROR;
      safeZHeightDefault = 15;
    }
    else {
      safeZHeightDefault = safeZHeightDefault[1];
    }
  }

  writeComment(eComment.Debug, " parseSafeZProperty: safeZMode = '" + eSafeZ.prop[safeZMode].name + "'");
  writeComment(eComment.Debug, " parseSafeZProperty: safeZHeightDefault = " + safeZHeightDefault);
}

function safeZforSection(_section) 
{
  if (getProperty(properties.mapE_RestoreRapids)) {
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
          var clearance = _section.getParameter("operation:clearanceHeight_value");
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
        writeComment(eComment.Important, " >>> WARNING: " + properties.mapF_SafeZ.title + " format error: " + safeZHeight);
        break;
    }
  }
}


Number.prototype.round = function(places) {
  return +(Math.round(this + "e+" + places)  + "e-" + places);
}

// Returns true if the rules to convert G1s to G0s are satisfied
function isSafeToRapid(x, y, z) {
  if (getProperty(properties.mapE_RestoreRapids)) {

    // Calculat a z to 3 decimal places for zSafe comparison, every where else use z to avoid mixing rounded with unrounded
    var z_round = z.round(3);
    writeComment(eComment.Debug, "isSafeToRapid z: " + z + " z_round: " + z_round);

    let zSafe = (z_round >= safeZHeight);

    writeComment(eComment.Debug, "isSafeToRapid zSafe: " + zSafe + " z_round: " + z_round + " safeZHeight: " + safeZHeight);

    // Destination z must be in safe zone.
    if (zSafe) {
      let cur = getCurrentPosition();
      let zConstant = (z == cur.z);
      let zUp = (z > cur.z);
      let xyConstant = ((x == cur.x) && (y == cur.y));
      let curZSafe = (cur.z >= safeZHeight);
      writeComment(eComment.Debug, "isSafeToRapid curZSafe: " + curZSafe + " cur.z: " + cur.z);

      // Restore Rapids only when the target Z is safe and
      //   Case 1: Z is not changing, but XY are
      //   Case 2: Z is increasing, but XY constant

      // Z is not changing and we know we are in the safe zone
      if (zConstant) {
        return true;
      }

      // We include moves of Z up as long as xy are constant
      else if (getProperty(properties.mapG_AllowRapidZ) && zUp && xyConstant) {
        return true;
      }

      // We include moves of Z down as long as xy are constant and z always remains safe
      else if (getProperty(properties.mapG_AllowRapidZ) && (!zUp) && xyConstant && curZSafe) {
        return true;
      }
    }
  }

  return false;
}

//---------------- Coolant ----------------

function CoolantA(on) {
  var coolantText = on ? getProperty(properties.cl2_coolantAOn) : getProperty(properties.cl3_coolantAOff);

  if (coolantText == "Use custom") {
    coolantText = on ? getProperty(properties.cl6_cust_coolantAOn) : getProperty(properties.cl7_cust_coolantAOff);
  }

  writeBlock(coolantText);
}

function CoolantB(on) {
  var coolantText = on ? getProperty(properties.cl4_coolantBOn) : getProperty(properties.cl5_coolantBOff);

  if (coolantText == "Use custom") {
    coolantText = on ? getProperty(properties.cl8_cust_coolantBOn) : getProperty(properties.cl9_cust_coolantBOff);
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
    if (getProperty(properties.cl0_coolantA_Mode) == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel A: " + coolant);
      coolantChannelA =  coolant;
      curCoolant = coolant;
      warn = false;
      CoolantA(true);
    }

    if (getProperty(properties.cl1_coolantB_Mode) == coolant) {
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

    writeBlock(mFormat.format(getProperty(properties.cutter6_GrblMode)), sFormat.format(laser_pwm));
  }

  // Default firmware
  else {
    var laser_pwm = power / 100 * 255;

    switch (getProperty(properties.cutter4_MarlinMode)) {
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
        writeBlock(mFormat.format(42), pFormat.format(getProperty(properties.cutter5_MarlinPin)), sFormat.format(laser_pwm));
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
    switch (getProperty(properties.cutter4_MarlinMode)) {
      case "106":
        writeBlock(mFormat.format(107));
        break;
      case "3":
        writeBlock(mFormat.format(5));
        break;
      case "42":
        writeBlock(mFormat.format(42), pFormat.format(getProperty(properties.cutter5_MarlinPin)), sFormat.format(0));
        break;
    }
  }
}

//---------------- on Entry Points ----------------

// Called in every new gcode file
function onOpen() {
  fw = getProperty(properties.job0_SelectedFirmware);

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
  if (getProperty(properties.fr2_EnforceFeedrate)) {
    fOutput = createVariable({ force: true }, fFormat);
  }

  // Set the starting sequence number for line numbering
  sequenceNumber = getProperty(properties.job6_SequenceNumberStart);

  // Set the seperator used between text
  if (!getProperty(properties.job8_SeparateWordsWithSpace)) {
    setWordSeparator("");
  }

  // Determine the safeZHeight to do rapids
  parseSafeZProperty();
}

// Called at end of gcode file
function onClose() {
  writeComment(eComment.Important, " *** STOP begin ***");

  flushMotions();

  if (getProperty(properties.gcodeStopFile) == "") {
    onCommand(COMMAND_COOLANT_OFF);
    if (getProperty(properties.job9_GoOriginOnFinish)) {
      rapidMovementsXY(0, 0);
    }
    onCommand(COMMAND_STOP_SPINDLE);

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
    loadFile(getProperty(properties.gcodeStopFile));
  }

  if (fw == eFirmware.GRBL) {
    writeln("%");
  }
}

var forceSectionToStartWithRapid = false;

function onSection() {
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
  vectorX = new Vector(1, 0, 0);
  vectorY = new Vector(0, 1, 0);
  writeComment(eComment.Info, "   X Min: " + xyzFormat.format(currentSection.getGlobalRange(vectorX).getMinimum()) + " - X Max: " + xyzFormat.format(currentSection.getGlobalRange(vectorX).getMaximum()));
  writeComment(eComment.Info, "   Y Min: " + xyzFormat.format(currentSection.getGlobalRange(vectorY).getMinimum()) + " - Y Max: " + xyzFormat.format(currentSection.getGlobalRange(vectorY).getMaximum()));
  writeComment(eComment.Info, "   Z Min: " + xyzFormat.format(currentSection.getGlobalZRange().getMinimum()) + " - Z Max: " + xyzFormat.format(currentSection.getGlobalZRange().getMaximum()));

  // Determine the Safe Z Height to map G1s to G0s
  safeZforSection(currentSection);

  // Do a tool change if its the first section and we are doing the first tool change
  // If its not the first section and the tool changed then do a tool change
  if (isFirstSection()) {
    if (getProperty(properties.toolChange6_DoFirstChange))
      toolChange();
  } 
  else if (tool.number != getPreviousSection().getTool().number)
      toolChange();
  
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
        cutterOnCurrentPower = getProperty(properties.cutter2_OnThrough);
        jetModeStr = "Through"
        break;
      case JET_MODE_ETCHING:
        cutterOnCurrentPower = getProperty(properties.cutter3_OnEtch);
        jetModeStr = "Etching"
        break;
      case JET_MODE_VAPORIZE:
        jetModeStr = "Vaporize"
        cutterOnCurrentPower = getProperty(properties.cutter1_OnVaporize);
        break;
      default:
        jetModeStr = "*** Unknown ***"
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
              writeBlock(getProperty(properties.DuetMillingMode));
              break;
          case TYPE_JET:
              writeBlock(getProperty(properties.DuetLaserMode));
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

var pendingRadiusCompensation = RADIUS_COMPENSATION_OFF;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
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

  if (getProperty(properties.mapD_RestoreFirstRapids) && (forceSectionToStartWithRapid == true)) {
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
  circular(clockwise, cx, cy, cz, x, y, z, feed)
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

function setSpindeSpeed(_spindleSpeed, _clockwise) {
  if (currentSpindleSpeed != _spindleSpeed) {
    if (_spindleSpeed > 0) {
      spindleOn(_spindleSpeed, _clockwise);
    } else {
      spindleOff();
    }
    currentSpindleSpeed = _spindleSpeed;
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

        if (getProperty(properties.cutter7_Coolant) != eCoolant.Off) {
          setCoolant(getProperty(properties.cutter7_Coolant));
        }
      }
      else {
        //Convert numeric coolant code to string
        strCoolant = (tool.coolant < coolantLevels.length ? (coolantLevels[tool.coolant]) : eCoolant.Off);
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
    if (pair.max == undefined || pair.max < rmin) {  // was pair.min - changed by DG 1/4/2021
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
  writeComment(eComment.Info, "   Feed: Travel speed X/Y = " + getProperty(properties.fr0_TravelSpeedXY));
  writeComment(eComment.Info, "   Feed: Travel Speed Z = " + getProperty(properties.fr1_TravelSpeedZ));
  writeComment(eComment.Info, "   Feed: Enforce Feedrate = " + getProperty(properties.fr2_EnforceFeedrate));
  writeComment(eComment.Info, "   Feed: Scale Feedrate = " + getProperty(properties.frA_ScaleFeedrate));
  writeComment(eComment.Info, "   Feed: Max XY Cut Speed = " + getProperty(properties.frB_MaxCutSpeedXY));
  writeComment(eComment.Info, "   Feed: Max Z Cut Speed = " + getProperty(properties.frC_MaxCutSpeedZ));
  writeComment(eComment.Info, "   Feed: Max Toolpath Speed = " + getProperty(properties.frD_MaxCutSpeedXYZ));
 
  // Display the G1->G0 Mapping Properties
  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " G1->G0 Mapping Properties:");
  writeComment(eComment.Info, "   Map: First G1 -> G0 Rapid = " + getProperty(properties.mapD_RestoreFirstRapids));
  writeComment(eComment.Info, "   Map: G1s -> G0 Rapids = " + getProperty(properties.mapE_RestoreRapids));
  writeComment(eComment.Info, "   Map: SafeZ Mode = " + eSafeZ.prop[safeZMode].name + " : default = " + safeZHeightDefault);
  writeComment(eComment.Info, "   Map: Allow Rapid Z = " + getProperty(properties.mapG_AllowRapidZ));

  writeComment(eComment.Info, " ");
}

function writeFirstSection() {
  // Write out the information block at the beginning of the file
  writeInformation();

  writeComment(eComment.Important, " *** START begin ***");

  if (getProperty(properties.gcodeStartFile) == "") {
       Start();
  } else {
    loadFile(getProperty(properties.gcodeStartFile));
  }

  writeComment(eComment.Important, " *** START end ***");
  writeComment(eComment.Important, " ");
}

// Output a comment
function writeComment(level, text) { 
  if (commentLevels.indexOf(level) <= commentLevels.indexOf(getProperty(properties.job3_CommentLevel))) {
    if (fw == eFirmware.GRBL) {
      writeln("(" + String(text).replace(/[\(\)]/g, "") + ")");
    }
    else {
      writeln(";" + String(text).replace(/[\(\)]/g, ""));
    }
  }
}

// Rapid movements with G1 and differentiated travel speeds for XY
// Changes F360 current XY.
// No longer called for general Rapid only for probing, homing, etc.
function rapidMovementsXY(_x, _y) {
  let x = xOutput.format(_x);
  let y = yOutput.format(_y);

  if (x || y) {
    if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    }
    else {
      let f = fOutput.format(propertyMmToUnit(getProperty(properties.fr0_TravelSpeedXY)));
      writeBlock(gMotionModal.format(0), x, y, f);
    }
  }
}

// Rapid movements with G1 and differentiated travel speeds for Z
// Changes F360 current Z
// No longer called for general Rapid only for probing, homing, etc.
function rapidMovementsZ(_z) {
  let z = zOutput.format(_z);

  if (z) {
    if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    }
    else {
      let f = fOutput.format(propertyMmToUnit(getProperty(properties.fr1_TravelSpeedZ)));
      writeBlock(gMotionModal.format(0), z, f);
    }
  }
}

// Rapid movements with G1 uses the max travel rate (xy or z) and then relies on feedrate scaling
function rapidMovements(_x, _y, _z) {

  rapidMovementsZ(_z);
  rapidMovementsXY(_x, _y);
}

// Calculate the feedX, feedY and feedZ components

function limitFeedByXYZComponents(curPos, destPos, feed) {
  if (!getProperty(properties.frA_ScaleFeedrate))
    return feed;

  var xyz = Vector.diff(destPos, curPos);       // Translate the cut so curPos is at 0,0,0
  var dir = xyz.getNormalized();                // Normalize vector to get a direction vector
  var xyzFeed = Vector.product(dir.abs, feed);  // Determine the effective x,y,z speed on each axis

  // Get the max speed for each axis
  let xyLimit = propertyMmToUnit(getProperty(properties.frB_MaxCutSpeedXY));
  let zLimit = propertyMmToUnit(getProperty(properties.frC_MaxCutSpeedZ));

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

  let xyzLimit = propertyMmToUnit(getProperty(properties.frD_MaxCutSpeedXYZ));
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
  if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
    // ensure that we end at desired position when compensation is turned off
    xOutput.reset();
    yOutput.reset();
  }

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
    if (pendingRadiusCompensation != RADIUS_COMPENSATION_OFF) {
      error(localize("Radius compensation mode is not supported."));
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, f);
    }
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

/*
function mergeProperties(to, from) {
  for (var attrname in from) {
    to[attrname] = from[attrname];
  }
}

function Firmware3dPrinterLike() {
  FirmwareBase.apply(this, arguments);
  this.spindleEnabled = false;
}

Firmware3dPrinterLike.prototype = Object.create(FirmwareBase.prototype);
Firmware3dPrinterLike.prototype.constructor = Firmware3dPrinterLike;
*/

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

  // Are we setting the orgin on start?
  if (getProperty(properties.job1_SetOriginOnStart)) {
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeBlock(gFormat.format(92), xFormat.format(0), yFormat.format(0), zFormat.format(0)); // Set origin to initial position
  }

  // Do a Probe on start?
  if (getProperty(properties.probe1_OnStart) && tool.number != 0 && !tool.isJetTool()) {
    onCommand(COMMAND_TOOL_MEASURE);
  }
}

function spindleOn(_spindleSpeed, _clockwise) {
  if (getProperty(properties.job2_ManualSpindlePowerControl)) {
    // For manual any positive input speed assumed as enabled. so it's just a flag
    if (!this.spindleEnabled) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual");
      askUser("Turn ON " + speedFormat.format(_spindleSpeed) + "RPM", "Spindle", false);
    }
  } else {
    writeComment(eComment.Important, " >>> Spindle Speed " + speedFormat.format(_spindleSpeed));
    writeBlock(mFormat.format(_clockwise ? 3 : 4), sOutput.format(_spindleSpeed));
  }
 
  this.spindleEnabled = true;
}

function spindleOff() {
  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    writeBlock(mFormat.format(5));
  }

  //Default
  else {
    if (getProperty(properties.job2_ManualSpindlePowerControl)) {
      writeBlock(mFormat.format(300), sFormat.format(300), pFormat.format(3000));
      askUser("Turn OFF spindle", "Spindle", false);
    } else {
      writeBlock(mFormat.format(5));
    }
  }

  this.spindleEnabled = false;
}

function display_text(txt) {
  // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    // Don't display text
  }

  // Default
  else {
    writeBlock(mFormat.format(117), (getProperty(properties.job8_SeparateWordsWithSpace) ? "" : " ") + txt);
  }
}

function circular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (!getProperty(properties.job4_UseArcs)) {
    linearize(tolerance);
    return;
  }

  var start = getCurrentPosition();

  // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    if (isFullCircle()) {
        if (isHelical()) {
            linearize(tolerance);
            return;
        }
        switch (getCircularPlane()) {
            case PLANE_XY:
                writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), fOutput.format(feed));
                break;
            case PLANE_ZX:
                writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), fOutput.format(feed));
                break;
            case PLANE_YZ:
                writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), yOutput.format(y), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), fOutput.format(feed));
                break;
            default:
                linearize(tolerance);
        }
    } else {
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
  }

  // Default
  else {
    // Marlin supports arcs only on XY plane
    if (isFullCircle()) {
      if (isHelical()) {
        linearize(tolerance);
        return;
      }
      switch (getCircularPlane()) {
        case PLANE_XY:
          writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), fOutput.format(feed));
          break;
        default:
          linearize(tolerance);
      }
    } else {
      switch (getCircularPlane()) {
        case PLANE_XY:
          writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), fOutput.format(feed));
          break;
        default:
          linearize(tolerance);
      }
    }
  }
}

function askUser(text, title, allowJog) {
  // Firmware is RepRap?
  if (fw == eFirmware.REPRAP) {
    var v1 = " P\"" + text + "\" R\"" + title + "\" S3";
    var v2 = allowJog ? " X1 Y1 Z1" : "";
    writeBlock(mFormat.format(291), (getProperty(properties.job8_SeparateWordsWithSpace) ? "" : " ") + v1 + v2);
  }

  // GRBL, include the message in a comment prefixed with MSG
  else if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(0), (getProperty(properties.job8_SeparateWordsWithSpace) ? "" : " ") + "(MSG " + text + ")");
  }
  
  // Default
  else
  {
    writeBlock(mFormat.format(0), (getProperty(properties.job8_SeparateWordsWithSpace) ? "" : " ") + text);
  }
}

function toolChange() {
  writeComment(eComment.Important, " Tool Change Start")

  // If tool changes are not to be include in the NC file then exit
  if (!getProperty(properties.toolChange0_Enabled))
    return;
  
  // If there is a custom GCode file for tool changes then include it
  if (getProperty(properties.gcodeToolFile1) != "") {
    loadFile(getProperty(properties.gcodeToolFile1));
  }

  // Are we inserting code to assist with the tool change?
  // If not, then just insert tool change GCODE G6 <tool number> and a G54
  if (getProperty(properties.toolChange1_InsertCode)) {

    // Go to tool change position
    flushMotions();
    onRapid(propertyMmToUnit(getProperty(properties.toolChange2_X)), propertyMmToUnit(getProperty(properties.toolChange3_Y)), propertyMmToUnit(getProperty(properties.toolChange4_Z)));
    flushMotions();
  
    // turn off spindle and coolant
    onCommand(COMMAND_COOLANT_OFF);
    onCommand(COMMAND_STOP_SPINDLE);

    // If Marlin then BEEP
    if ((fw == eFirmware.MARLIN) && !getProperty(properties.job2_ManualSpindlePowerControl)) {
      writeBlock(mFormat.format(300), sFormat.format(400), pFormat.format(2000));
    }
  
    // Disable Z stepper
    if (getProperty(properties.toolChange5_DisableZStepper)) {
      askUser("Z Stepper will disabled. Wait for STOP!!", "Tool change", false);
      writeBlock(mFormat.format(84), 'Z'); // Disable steppers timeout
    }

    // Ask tool change and wait user to touch lcd button
    askUser("Insert Tool #" + tool.number + " " + tool.comment, "Tool change", true);
  }
  else
  {
      writeBlock(mFormat.format(6), tFormat.format(tool.number));
      writeBlock(gFormat.format(54));
  }

  // If there is a custom GCode file for tool changes then include it
  if (getProperty(properties.gcodeToolFile2) != "") {
    loadFile(getProperty(properties.gcodeToolFile2));
  }
  
    // Run Z probe gcode
  if (getProperty(properties.probe2_OnToolChange) && tool.number != 0) {
    onCommand(COMMAND_TOOL_MEASURE);
  }

  writeComment(eComment.Important, " Tool Change End")
}

function probeTool() {
  // Command comment block
  writeComment(eComment.Important, " Probe to Zero Z");
  writeComment(eComment.Info, "   Ask User to Attach the Z Probe");
  writeComment(eComment.Info, "   Do Probing");
  writeComment(eComment.Info, "   Set Z to probe thickness: " + zFormat.format(propertyMmToUnit(getProperty(properties.probe3_Thickness))))
  if (getProperty(properties.probe7_SafeZ) != "") {
    writeComment(eComment.Info, "   Retract the tool to " + propertyMmToUnit(getProperty(properties.probe7_SafeZ)));
  }
  writeComment(eComment.Info, "   Ask User to Remove the Z Probe");
  
  askUser("Attach ZProbe", "Probe", false);

  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    // refer to http://linuxcnc.org/docs/stable/html/gcode/g-code.html#gcode:g38
    // Note this is not using the optional P parameter available on FluidNC (http://wiki.fluidnc.com/en/config/probe)
    writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probe6_G38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.probe5_G38Target))));
  }

  // Not GRBL
  else {
    // refer http://marlinfw.org/docs/gcode/G038.html
    if (getProperty(properties.probe4_UseHomeZ)) {
      writeBlock(gFormat.format(28), 'Z');
    } else {
      writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(getProperty(properties.probe6_G38Speed))), zFormat.format(propertyMmToUnit(getProperty(properties.probe5_G38Target))));
    }
  }

  let z = zFormat.format(propertyMmToUnit(getProperty(properties.probe3_Thickness)));
  writeBlock(gFormat.format(92), z); // Set origin to initial position
  
  resetAll();
  if (getProperty(properties.probe7_SafeZ) != "") { // move up tool to safe height again after probing
    rapidMovementsZ(propertyMmToUnit(getProperty(properties.probe7_SafeZ)), false);
  }
  
  flushMotions();

  askUser("Detach ZProbe", "Probe", false);
}