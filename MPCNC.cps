/*

https://github.com/guffy1234/mpcnc_posts_processor

MPCNC posts processor for milling and laser/plasma cutting.

*/

description = "PRE-RELEASE MPCNC Milling/Laser - Marlin 2.0, Grbl 1.1, RepRap";
vendor = "flyfisher604";
vendorUrl = "https://github.com/flyfisher604/mpcnc_post_processor";

// Internal properties
certificationLevel = 2;
extension = "gcode";
setCodePage("ascii");
capabilities = CAPABILITY_MILLING | CAPABILITY_JET;

machineMode = undefined; //TYPE_MILLING, TYPE_JET

var eFirmware = {
    MARLIN: 0,
    GRBL: 1,
    REPRAP: 2,
    prop: {
      0: {name: "Marlin 2.x", value: 0},
      1: {name: "Grbl 1.1", value: 1},
      2: {name: "RepRap", value: 2}
    }
  };

var fw =  eFirmware.MARLIN; 

var eComment = {
    Off: 0,
    Important: 1,
    Info: 2,
    Debug: 3,
    prop: {
      0: {name: "Off", value: 0},
      1: {name: "Important", value: 1},
      2: {name: "Info", value: 2},
      3: {name: "Debug", value: 3}
    }
};

var eCoolant = {
    Off: 0,
    Flood: 1,
    Mist: 2,
    ThroughTool: 3,
    Air: 4,
    AirThroughTool: 5,
    Suction: 6,
    FloodMist: 7,
    FloodThroughTool: 8,
    prop: {
      0: {name: "Off", value: 0},
      1: {name: "Flood", value: 1},
      2: {name: "Mist", value: 2},
      3: {name: "ThroughTool", value: 3},
      4: {name: "Air", value: 4},
      5: {name: "AirThroughTool", value: 5},
      6: {name: "Suction", value: 6},
      7: {name: "Flood and Mist", value: 7},
      8: {name: "Flood and ThroughTool", value: 8},
    }
};


// user-defined properties
properties = {
  job0_SelectedFirmware : fw,            // Firmware to use in special cases
  job1_SetOriginOnStart: true,           // Set current position as 0,0,0 on start (G92)
  job2_ManualSpindlePowerControl: true,  // Spindle motor is controlled by manual switch 
  job3_CommentLevel: eComment.Info,      // The level of comments included 
  job4_UseArcs: true,                    // Produce G2/G3 for arcs
  job5_SequenceNumbers: false,           // show sequence numbers
  job6_SequenceNumberStart: 10,          // first sequence number
  job7_SequenceNumberIncrement: 1,       // increment for sequence numbers
  job8_SeparateWordsWithSpace: true,     // specifies that the words should be separated with a white space 
  job9_GoOriginOnFinish: true,           // Go X0 Y0 current Z at end

  fr0_TravelSpeedXY: 2500,             // High speed for travel movements X & Y (mm/min)
  fr1_TravelSpeedZ: 300,               // High speed for travel movements Z (mm/min)
  fr2_EnforceFeedrate: true,          // Add feedrate to each movement line
  frA_ScaleFeedrate: false,            // Will feedrated be scaled
  frB_MaxCutSpeedXY: 900,              // Max speed for cut movements X & Y (mm/min)
  frC_MaxCutSpeedZ: 180,               // Max speed for cut movements Z (mm/min)
  frD_MaxCutSpeedXYZ: 1000,            // Max feedrate after scaling

  mapD_RestoreFirstRapids: false,      // Map first G01 --> G00 
  mapE_RestoreRapids: false,           // Map G01 --> G00 for SafeTravelsAboveZ 
  mapF_SafeZ: "Retract:15",            // G01 mapped to G00 if Z is >= jobSafeZRapid
  mapG_AllowRapidZ: false,             // Allow G01 --> G00 for vertical retracts and Z descents above safe

  toolChange0_Enabled: false,          // Enable tool change code
  toolChange1_InsertCode: false,        // Insert code to relocate the tool during tool change
  toolChange2_X: 0,                    // X position for builtin tool change
  toolChange3_Y: 0,                    // Y position for builtin tool change
  toolChange4_Z: 40,                   // Z position for builtin tool change
  toolChange5_DisableZStepper: false,  // disable Z stepper when changing a tool
  toolChange6_DoFirstChange: false,    // First tool is not already loaded

  probe1_OnStart: false,               // Execute probe gcode to align tool
  probe2_OnToolChange: false,          // Z probe after tool change
  probe3_Thickness: 0.8,               // plate thickness
  probe4_UseHomeZ: true,               // use G28 or G38 for probing 
  probe5_G38Target: -10,               // probing up to pos 
  probe6_G38Speed: 30,                 // probing with speed 
  probe7_SafeZ: 40,                    // Safe Z to return to after probing

  gcodeStartFile: "",                  // File with custom Gcode for header/start (in nc folder)
  gcodeStopFile: "",                   // File with custom Gcode for footer/end (in nc folder)
  gcodeToolFile1: "",                  // File with custom Gcode to start tool change (in nc folder)
  gcodeToolFile2: "",                  // File with custom Gcode to end tool change (in nc folder)
  gcodeProbeFile: "",                  // File with custom Gcode for tool probe (in nc folder)

  cutter1_OnVaporize: 100,             // Percentage of power to turn on the laser/plasma cutter in vaporize mode
  cutter2_OnThrough: 80,               // Percentage of power to turn on the laser/plasma cutter in through mode
  cutter3_OnEtch: 40,                  // Percentage of power to turn on the laser/plasma cutter in etch mode
  cutter4_MarlinMode: 106,             // Marlin mode laser/plasma cutter
  cutter5_MarlinPin: 4,                // Marlin laser/plasma cutter pin for M42
  cutter6_GrblMode: 4,                 // GRBL mode laser/plasma cutter
  cutter7_Coolant: eCoolant.Off,       // Use this coolant. F360 doesn't define a coolant for cutters

  cl0_coolantA_Mode: eCoolant.Off,  // Enable issuing g-codes for control Coolant channel A 
  cl1_coolantB_Mode: eCoolant.Off,  // Use issuing g-codes for control Coolant channel B 
  cl2_coolantAOn: "M42 P6 S255",    // GCode command to turn on Coolant channel A
  cl3_coolantAOff: "M42 P6 S0",     // Gcode command to turn off Coolant channel A
  cl4_coolantBOn: "M42 P11 S255",   // GCode command to turn on Coolant channel B
  cl5_coolantBOff: "M42 P11 S0",    // Gcode command to turn off Coolant channel B 
  cl6_cust_coolantAOn: "",          // Custom GCode command to turn on Coolant channel A
  cl7_cust_coolantAOff: "",         // Custom Gcode command to turn off Coolant channel A
  cl8_cust_coolantBOn: "",          // Custom GCode command to turn on Coolant channel B
  cl9_cust_coolantBOff: "",         // Custom Gcode command to turn off Coolant channel B 

  DuetMillingMode: "M453 P2 I0 R30000 F200", // GCode command to setup Duet3d milling mode
  DuetLaserMode: "M452 P2 I0 R255 F200",     // GCode command to setup Duet3d laser mode
  
};

propertyDefinitions = {

  job0_SelectedFirmware: {
    title: "Job: CNC Firmware", description: "Dialect of GCode to create", group: 1,
    type: "integer", default_mm: eFirmware.MARLIN, default_in: eFirmware.MARLIN,
    values: [
      { title: eFirmware.prop[eFirmware.MARLIN].name, id: eFirmware.MARLIN },
      { title: eFirmware.prop[eFirmware.GRBL].name, id: eFirmware.GRBL },
      { title: eFirmware.prop[eFirmware.REPRAP].name, id: eFirmware.REPRAP },
    ]
  },

  job1_SetOriginOnStart: {
    title: "Job: Zero Starting Location (G92)", description: "On start set the current location as 0,0,0 (G92)", group: 1,
    type: "boolean", default_mm: true, default_in: true
  },
  job2_ManualSpindlePowerControl: {
    title: "Job: Manual Spindle On/Off", description: "Enable to manually turn spindle motor on/off", group: 1,
    type: "boolean", default_mm: true, default_in: true
  },
  job3_CommentLevel: {
    title: "Job: Comment Level", description: "Controls the comments include", group: 1,
    type: "integer", default_mm: eComment.Info, default_in: eComment.Info,
    values: [
      { title: eComment.prop[eComment.Off].name, id: eComment.Off },
      { title: eComment.prop[eComment.Important].name, id: eComment.Important },
      { title: eComment.prop[eComment.Info].name, id: eComment.Info },
      { title: eComment.prop[eComment.Debug].name, id: eComment.Debug },
    ]
  },
  job4_UseArcs: {
    title: "Job: Use Arcs", description: "Use G2/G3 g-codes fo circular movements", group: 1,
    type: "boolean", default_mm: true, default_in: true
  },
  job5_SequenceNumbers: {
    title: "Job: Enable Line #s", description: "Show sequence numbers", group: 1,
    type: "boolean", default_mm: false, default_in: false
  },
  job6_SequenceNumberStart: {
    title: "Job: First Line #", description: "First sequence number", group: 1,
    type: "integer", default_mm: 10, default_in: 10
  },
  job7_SequenceNumberIncrement: {
    title: "Job: Line # Increment", description: "Sequence number increment", group: 1,
    type: "integer", default_mm: 1, default_in: 1
  },
  job8_SeparateWordsWithSpace: {
    title: "Job: Include Whitespace", description: "Includes whitespace seperation between text", group: 1,
    type: "boolean", default_mm: true, default_in: true
  },
  job9_GoOriginOnFinish: {
    title: "Job: At end go to 0,0", description: "Go to X0 Y0 at gcode end, Z remains unchanged", group: 1,
    type: "boolean", default_mm: true, default_in: true
  },
  
  fr0_TravelSpeedXY: {
    title: "Feed: Travel speed X/Y", description: "High speed for Rapid movements X & Y (mm/min; in/min)", group: 2,
    type: "spatial", default_mm: 2500, default_in: 100
  },
  fr1_TravelSpeedZ: {
    title: "Feed: Travel Speed Z", description: "High speed for Rapid movements z (mm/min; in/min)", group: 2,
    type: "spatial", default_mm: 300, default_in: 12
  },
  fr2_EnforceFeedrate: {
    title: "Feed: Enforce Feedrate", description: "Add feedrate to each movement g-code", group: 2,
    type: "boolean", default_mm: true, default_in: true
  },
  frA_ScaleFeedrate: {
    title: "Feed: Scale Feedrate", description: "Scale feedrate based on X, Y, Z axis maximums", group: 2,
    type: "boolean", default_mm: false, default_in: false
  },
  frB_MaxCutSpeedXY: {
    title: "Feed: Max XY Cut Speed", description: "Maximum X or Y axis cut speed (mm/min; in/min)", group: 2,
    type: "spatial", default_mm: 900, default_in: 35.43
  },
  frC_MaxCutSpeedZ: {
    title: "Feed: Max Z Cut Speed", description: "Maximum Z axis cut speed (mm/min; in/min)", group: 2,
    type: "spatial", default_mm: 180, default_in: 7.08
  },
  frD_MaxCutSpeedXYZ: {
    title: "Feed: Max Toolpath Speed", description: "Maximum scaled feedrate for toolpath (mm/min; in/min)", group: 2,
    type: "spatial", default_mm: 1000, default_in: 39.37
  },

  mapD_RestoreFirstRapids: {
    title: "Map: First G1 -> G0 Rapid", description: "Ensure move to start of a cut is with a G0 Rapid", group: 3,
    type: "boolean", default_mm: false, default_in: false
  },
  mapE_RestoreRapids: {
    title: "Map: G1s -> G0 Rapids", description: "Enable to convert G1s to G0 Rapids when safe", group: 3,
    type: "boolean", default_mm: false, default_in: false
  },
  mapF_SafeZ: {
    title: "Map: Safe Z to Rapid", description: "Must be above or equal to this value to map G1s --> G0s; constant or keyword (see docs)", group: 3,
    type: "string", default_mm: "Retract:15", default_in: "Retract:15"
  },
  mapG_AllowRapidZ: {
    title: "Map: Allow Rapid Z", description: "Enable to include vertical retracts and safe descents", group: 3,
    type: "boolean", default_mm: false, default_in: false
  },

  toolChange0_Enabled: {
    title: "Tool Change: Enable", description: "Include tool changes is NC file", group: 4,
    type: "boolean", default_mm: false, default_in: false
  },
  toolChange1_InsertCode: {
    title: "Tool Change: Relocation Code", description: "Insert code to relocate the tool for manual change", group: 4,
    type: "boolean", default_mm: false, default_in: false
  },
  toolChange2_X: {
    title: "Tool Change: X", description: "X location for tool change", group: 4,
    type: "spatial", default_mm: 0, default_in: 0
  },
  toolChange3_Y: {
    title: "Tool Change: Y", description: "Y location for tool change", group: 4,
    type: "spatial", default_mm: 0, default_in: 0
  },
  toolChange4_Z: {
    title: "Tool Change: Z ", description: "Z location for tool change", group: 4,
    type: "spatial", default_mm: 40, default_in: 1.6
  },
  toolChange5_DisableZStepper: {
    title: "Tool Change: Disable Z stepper", description: "Disable Z stepper after reaching tool change location", group: 4,
    type: "boolean", default_mm: false, default_in: false
  },
  toolChange6_DoFirstChange: {
    title: "Tool Change: Do First Change", description: "First tool is not already loaded", group: 4,
    type: "boolean", default_mm: false, default_in: false
  },

  
  probe1_OnStart: {
    title: "Probe: On job start", description: "Execute probe gcode on job start", group: 5,
    type: "boolean", default_mm: false, default_in: false
  },
  probe2_OnToolChange: {
    title: "Probe: After Tool Change", description: "After tool change, probe Z at the current location", group: 5,
    type: "boolean", default_mm: false, default_in: false
  },
  probe3_Thickness: {
    title: "Probe: Plate thickness", description: "Plate thickness", group: 5,
    type: "spatial", default_mm: 0.8, default_in: 0.032
  },
  probe4_UseHomeZ: {
    title: "Probe: Use Home Z (G28)", description: "Probe with G28 (Yes) or G38 (No)", group: 5,
    type: "boolean", default_mm: true, default_in: true
  },
  probe5_G38Target: {
    title: "Probe: G38 target", description: "G38 Probing's furthest Z position", group: 5,
    type: "spatial", default_mm: -10, default_in: -0.5
  },
  probe6_G38Speed: {
    title: "Probe: G38 speed", description: "G38 Probing's speed (mm/min; in/min)", group: 5,
    type: "spatial", default_mm: 30, default_in: 1.2
  },
  probe7_SafeZ: {
    title: "Probe: Safe Z", description: "Safe Z to return to after probing", group: 5,
    type: "spatial", default_mm: 40, default_in: 1.6
  },

  cutter1_OnVaporize: {
    title: "Laser: On - Vaporize", description: "Persent of power to turn on the laser/plasma cutter in vaporize mode", group: 6,
    type: "number", default_mm: 100, default_in: 100
  },
  cutter2_OnThrough: {
    title: "Laser: On - Through", description: "Persent of power to turn on the laser/plasma cutter in through mode", group: 6,
    type: "number", default_mm: 80, default_in: 80
  },
  cutter3_OnEtch: {
    title: "Laser: On - Etch", description: "Persent of power to on the laser/plasma cutter in etch mode", group: 6,
    type: "number", default_mm: 40, default_in: 40
  },
  cutter4_MarlinMode: {
    title: "Laser: Marlin/Reprap Mode", description: "Marlin/Reprap mode of the laser/plasma cutter", group: 6,
    type: "integer", default_mm: 106, default_in: 106,
    values: [
      { title: "Fan - M106 S{PWM}/M107", id: 106 },
      { title: "Spindle - M3 O{PWM}/M5", id: 3 },
      { title: "Pin - M42 P{pin} S{PWM}", id: 42 },
    ]
  },
  cutter5_MarlinPin: {
    title: "Laser: Marlin M42 Pin", description: "Marlin custom pin number for the laser/plasma cutter", group: 6,
    type: "integer", default_mm: 4, default_in: 4
  },
  cutter6_GrblMode: {
    title: "Laser: GRBL Mode", description: "GRBL mode of the laser/plasma cutter", group: 6,
    type: "integer", default_mm: 4, default_in: 4,
    values: [
        { title: "M4 S{PWM}/M5 dynamic power", id: 4 },
        { title: "M3 S{PWM}/M5 static power", id: 3 },
    ]
  },
  cutter7_Coolant: {
    title: "Laser: Coolant", description: "Force a coolant to be used", group: 6,
    type: "integer", default_mm: eCoolant.Off, default_in: eCoolant.Off,
    values: [
      { title: eCoolant.prop[eCoolant.Off].name, id: eCoolant.Off },
      { title: eCoolant.prop[eCoolant.Flood].name, id: eCoolant.Flood },
      { title: eCoolant.prop[eCoolant.Mist].name, id: eCoolant.Mist },
      { title: eCoolant.prop[eCoolant.ThroughTool].name, id: eCoolant.ThroughTool },
      { title: eCoolant.prop[eCoolant.Air].name, id: eCoolant.Air },
      { title: eCoolant.prop[eCoolant.AirThroughTool].name, id: eCoolant.AirThroughTool },
      { title: eCoolant.prop[eCoolant.Suction].name, id: eCoolant.Suction },
      { title: eCoolant.prop[eCoolant.FloodMist].name, id: eCoolant.FloodMist },
      { title: eCoolant.prop[eCoolant.FloodThroughTool].name, id: eCoolant.FloodThroughTool }
    ]
  },

  gcodeStartFile: {
    title: "Extern: Start File", description: "File with custom Gcode for header/start (in nc folder)", group: 7,
    type: "file", default_mm: "", default_in: ""
  },
  gcodeStopFile: {
    title: "Extern: Stop File", description: "File with custom Gcode for footer/end (in nc folder)", group: 7,
    type: "file", default_mm: "", default_in: ""
  },
  gcodeToolFile1: {
    title: "Extern: Tool File1", description: "File with custom Gcode to start tool change (in nc folder)", group: 7,
    type: "file", default_mm: "", default_in: ""
  },
  gcodeToolFile2: {
    title: "Extern: Tool File2", description: "File with custom Gcode to end tool change (in nc folder)", group: 7,
    type: "file", default_mm: "", default_in: ""
  },
  gcodeProbeFile: {
    title: "Extern: Probe File", description: "File with custom Gcode for tool probe (in nc folder)", group: 7,
    type: "file", default_mm: "", default_in: ""
  },

  // Coolant
  cl0_coolantA_Mode: {
    title: "Coolant: A Mode", description: "Enable channel A when tool is set this coolant", group: 8,
    type: "integer", default_mm: 0, default_in: 0,
    values: [
      { title: eCoolant.prop[eCoolant.Off].name, id: eCoolant.Off },
      { title: eCoolant.prop[eCoolant.Flood].name, id: eCoolant.Flood },
      { title: eCoolant.prop[eCoolant.Mist].name, id: eCoolant.Mist },
      { title: eCoolant.prop[eCoolant.ThroughTool].name, id: eCoolant.ThroughTool },
      { title: eCoolant.prop[eCoolant.Air].name, id: eCoolant.Air },
      { title: eCoolant.prop[eCoolant.AirThroughTool].name, id: eCoolant.AirThroughTool },
      { title: eCoolant.prop[eCoolant.Suction].name, id: eCoolant.Suction },
      { title: eCoolant.prop[eCoolant.FloodMist].name, id: eCoolant.FloodMist },
      { title: eCoolant.prop[eCoolant.FloodThroughTool].name, id: eCoolant.FloodThroughTool }
    ]
  },
  cl1_coolantB_Mode: {
    title: "Coolant: B Mode", description: "Enable channel B when tool is set this coolant", group: 8,
    type: "integer", default_mm: 0, default_in: 0,
    values: [
      { title: eCoolant.prop[eCoolant.Off].name, id: eCoolant.Off },
      { title: eCoolant.prop[eCoolant.Flood].name, id: eCoolant.Flood },
      { title: eCoolant.prop[eCoolant.Mist].name, id: eCoolant.Mist },
      { title: eCoolant.prop[eCoolant.ThroughTool].name, id: eCoolant.ThroughTool },
      { title: eCoolant.prop[eCoolant.Air].name, id: eCoolant.Air },
      { title: eCoolant.prop[eCoolant.AirThroughTool].name, id: eCoolant.AirThroughTool },
      { title: eCoolant.prop[eCoolant.Suction].name, id: eCoolant.Suction },
      { title: eCoolant.prop[eCoolant.FloodMist].name, id: eCoolant.FloodMist },
      { title: eCoolant.prop[eCoolant.FloodThroughTool].name, id: eCoolant.FloodThroughTool }
    ]
  },
  cl2_coolantAOn: {
      title: "Coolant: A Enable", description: "GCode to turn On coolant channel A", group: 8,
      type: "enum", default_mm: "M42 P6 S255", default_in: "M42 P6 S255",
      values: [
        { title: "Mrln: M42 P6 S255", id: "M42 P6 S255" },
        { title: "Mrln: M42 P11 S255", id: "M42 P11 S255" },
        { title: "Grbl: M7 (mist)", id: "M7" },
        { title: "Grbl: M8 (flood)", id: "M8" },
        { title: "Use custom", id: "Use custom" }
      ]
  },
  cl3_coolantAOff: {
    title: "Coolant: A Disable", description: "Gcode to turn Off coolant A", group: 8,
    type: "enum", default_mm: "M42 P6 S0", default_in: "M42 P6 S0",
    values: [
      { title: "Mrln: M42 P6 S0", id: "M42 P6 S0" },
      { title: "Mrln: M42 P11 S0", id: "M42 P11 S0" },
      { title: "Grbl: M9 (off)", id: "M9" },
      { title: "Use custom", id: "Use custom" }
    ]
  },
  cl4_coolantBOn: {
    title: "Coolant: B Enable", description: "GCode to turn On coolant channel B", group: 8,
    type: "enum", default_mm: "M42 P11 S255", default_in: "M42 P11 S255",
    values: [
      { title: "Mrln: M42 P11 S255", id: "M42 P11 S255" },
      { title: "Mrln: M42 P6 S255", id: "M42 P6 S255" },
      { title: "Grbl: M7 (mist)", id: "M7" },
      { title: "Grbl: M8 (flood)", id: "M8" },
      { title: "Use custom", id: "Use custom" }
    ]
  },
  cl5_coolantBOff: {
    title: "Coolant: B Disable", description: "Gcode to turn Off coolant B", group: 8,
    type: "enum", default_mm: "M42 P11 S0", default_in: "M42 P11 S0",
    values: [
      { title: "Mrln: M42 P11 S0", id: "M42 P11 S0" },
      { title: "Mrln: M42 P6 S0", id: "M42 P6 S0" },
      { title: "Grbl: M9 (off)", id: "M9" },
      { title: "Use custom", id: "Use custom" }
    ]
  },
  cl6_cust_coolantAOn: {
    title: "Coolant: Custom A Enable", description: "Custom GCode to turn On coolant channel A", group: 8,
    type: "string", default_mm: "", default_in: "",
  },
  cl7_cust_coolantAOff: {
    title: "Coolant: Custom A Disable", description: "Custom Gcode to turn Off coolant A", group: 8,
    type: "string", default_mm: "", default_in: "",
  },
  cl8_cust_coolantBOn: {
    title: "Coolant: Custom B Enable", description: "Custom GCode to turn On coolant channel B", group: 8,
    type: "string", default_mm: "", default_in: "",
  },
  cl9_cust_coolantBOff: {
    title: "Coolant: Custom B Disable", description: "Custom Gcode to turn Off coolant B", group: 8,
    type: "string", default_mm: "", default_in: "",
  },

  DuetMillingMode: {
    title: "Duet: Milling mode", description: "GCode command to setup Duet3d milling mode", group: 9,
    type: "string", default_mm: "M453 P2 I0 R30000 F200", default_in: "M453 P2 I0 R30000 F200"
  },
  DuetLaserMode: {
    title: "Duet: Laser mode", description: "GCode command to setup Duet3d laser mode", group: 9,
    type: "string", default_mm: "M452 P2 I0 R255 F200", default_in: "M452 P2 I0 R255 F200"
  },
};

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

// Arc support variables
minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined;

// Writes the specified block.
function writeBlock() {
  if (properties.job5_SequenceNumbers) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += properties.job7_SequenceNumberIncrement;
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
  var str = properties.mapF_SafeZ;

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
  if (properties.mapE_RestoreRapids) {
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
        writeComment(eComment.Important, " >>> WARNING: " + propertyDefinitions.mapF_SafeZ.title + "format error: " + safeZHeight);
        break;
    }
  }
}


Number.prototype.round = function(places) {
  return +(Math.round(this + "e+" + places)  + "e-" + places);
}

// Returns true if the rules to convert G1s to G0s are satisfied
function isSafeToRapid(x, y, z) {
  if (properties.mapE_RestoreRapids) {

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
      else if (properties.mapG_AllowRapidZ && zUp && xyConstant) {
        return true;
      }

      // We include moves of Z down as long as xy are constant and z always remains safe
      else if (properties.mapG_AllowRapidZ && (!zUp) && xyConstant && curZSafe) {
        return true;
      }
    }
  }

  return false;
}

//---------------- Coolant ----------------

function CoolantA(on) {
  var coolantText = on ? properties.cl2_coolantAOn : properties.cl3_coolantAOff;

  if (coolantText == "Use custom") {
    coolantText = on ? properties.cl6_cust_coolantAOn : properties.cl7_cust_coolantAOff;
  }

  writeBlock(coolantText);
}

function CoolantB(on) {
  var coolantText = on ? properties.cl4_coolantBOn : properties.cl5_coolantBOff;

  if (coolantText == "Use custom") {
    coolantText = on ? properties.cl8_cust_coolantBOn : properties.cl9_cust_coolantBOff;
  }

  writeBlock(coolantText);
}

// Manage two channels of coolant by tracking which coolant is being using for
// a channel (0 = disabled). SetCoolant called with desired coolant to use or 0 to disable

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
    writeComment((coolant == eCoolant.Off) ? eComment.Important: eComment.Info, " >>> Coolant Channel A: " + eCoolant.prop[eCoolant.Off].name);
    coolantChannelA = eCoolant.Off;
    CoolantA(false);
  }

  if (coolantChannelB != eCoolant.Off) {
    writeComment((coolant == eCoolant.Off) ? eComment.Important: eComment.Info, " >>> Coolant Channel B: " + eCoolant.prop[eCoolant.Off].name);
    coolantChannelB = eCoolant.Off;
    CoolantB(false);
  }

  // At this point we know that all coolant is off so make that the current coolant
  curCoolant = eCoolant.Off;

  // As long as we are not disabling coolant (coolant = 0), then check if either coolant channel
  // matches the coolant requested. If neither do then issue an warning

  var warn = true;

  if (coolant != eCoolant.Off) {
    if (properties.cl0_coolantA_Mode == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel A: " + eCoolant.prop[coolant].name);
      coolantChannelA =  coolant;
      curCoolant = coolant;
      warn = false;
      CoolantA(true);
    }

    if (properties.cl1_coolantB_Mode == coolant) {
      writeComment(eComment.Important, " >>> Coolant Channel B: " + eCoolant.prop[coolant].name);
      coolantChannelB =  coolant;
      curCoolant = coolant;
      warn = false;
      CoolantB(true);
    }

    if (warn) {
      writeComment(eComment.Important, " >>> WARNING: No matching Coolant channel : " + ((coolant <= eCoolant.FloodThroughTool) ? eCoolant.prop[coolant].name : "unknown") + " requested");
    }
  }
}

//---------------- Cutters - Waterjet/Laser/Plasma ----------------

var cutterOnCurrentPower;

function laserOn(power) {
  // Firmware is Grbl
  if (fw == eFirmware.GRBL) {
    var laser_pwm = power * 10;

    writeBlock(mFormat.format(properties.cutter6_GrblMode), sFormat.format(laser_pwm));
  }

  // Default firmware
  else {
    var laser_pwm = power / 100 * 255;

    switch (properties.cutter4_MarlinMode) {
      case 106:
        writeBlock(mFormat.format(106), sFormat.format(laser_pwm));
        break;
      case 3:
        if (fw == eFirmware.REPRAP) {
          writeBlock(mFormat.format(3), sFormat.format(laser_pwm));
        } else {
          writeBlock(mFormat.format(3), oFormat.format(laser_pwm));
        }
        break;
      case 42:
        writeBlock(mFormat.format(42), pFormat.format(properties.cutter5_MarlinPin), sFormat.format(laser_pwm));
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
    switch (properties.cutter4_MarlinMode) {
      case 106:
        writeBlock(mFormat.format(107));
        break;
      case 3:
        writeBlock(mFormat.format(5));
        break;
      case 42:
        writeBlock(mFormat.format(42), pFormat.format(properties.cutter5_MarlinPin), sFormat.format(0));
        break;
    }
  }
}

//---------------- on Entry Points ----------------

// Called in every new gcode file
function onOpen() {
  fw = properties.job0_SelectedFirmware;

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
  if (properties.fr2_EnforceFeedrate) {
    fOutput = createVariable({ force: true }, fFormat);
  }

  // Set the starting sequence number for line numbering
  sequenceNumber = properties.job6_SequenceNumberStart;

  // Set the seperator used between text
  if (!properties.job8_SeparateWordsWithSpace) {
    setWordSeparator("");
  }

  // Determine the safeZHeight to do rapids
  parseSafeZProperty();
}

// Called at end of gcode file
function onClose() {
  writeComment(eComment.Important, " *** STOP begin ***");

  flushMotions();

  if (properties.gcodeStopFile == "") {
    onCommand(COMMAND_COOLANT_OFF);
    if (properties.job9_GoOriginOnFinish) {
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
    loadFile(properties.gcodeStopFile);
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
    if (properties.toolChange6_DoFirstChange)
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
        cutterOnCurrentPower = properties.cutter2_OnThrough;
        jetModeStr = "Through"
        break;
      case JET_MODE_ETCHING:
        cutterOnCurrentPower = properties.cutter3_OnEtch;
        jetModeStr = "Etching"
        break;
      case JET_MODE_VAPORIZE:
        jetModeStr = "Vaporize"
        cutterOnCurrentPower = properties.cutter1_OnVaporize;
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
              writeBlock(properties.DuetMillingMode);
              break;
          case TYPE_JET:
              writeBlock(properties.DuetLaserMode);
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

  if (properties.mapD_RestoreFirstRapids && (forceSectionToStartWithRapid == true)) {
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

        if (properties.cutter7_Coolant != eCoolant.Off) {
          setCoolant(properties.cutter7_Coolant);
        }
      }
      else {
        setCoolant(tool.coolant);
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
  writeComment(eComment.Info, "   Feed: Travel speed X/Y = " + properties.fr0_TravelSpeedXY);
  writeComment(eComment.Info, "   Feed: Travel Speed Z = " + properties.fr1_TravelSpeedZ);
  writeComment(eComment.Info, "   Feed: Enforce Feedrate = " + properties.fr2_EnforceFeedrate);
  writeComment(eComment.Info, "   Feed: Scale Feedrate = " + properties.frA_ScaleFeedrate);
  writeComment(eComment.Info, "   Feed: Max XY Cut Speed = " + properties.frB_MaxCutSpeedXY);
  writeComment(eComment.Info, "   Feed: Max Z Cut Speed = " + properties.frC_MaxCutSpeedZ);
  writeComment(eComment.Info, "   Feed: Max Toolpath Speed = " + properties.frD_MaxCutSpeedXYZ);
 
  // Display the G1->G0 Mapping Properties
  writeComment(eComment.Info, " ");
  writeComment(eComment.Info, " G1->G0 Mapping Properties:");
  writeComment(eComment.Info, "   Map: First G1 -> G0 Rapid = " + properties.mapD_RestoreFirstRapids);
  writeComment(eComment.Info, "   Map: G1s -> G0 Rapids = " + properties.mapE_RestoreRapids);
  writeComment(eComment.Info, "   Map: SafeZ Mode = " + eSafeZ.prop[safeZMode].name + " : default = " + safeZHeightDefault);
  writeComment(eComment.Info, "   Map: Allow Rapid Z = " + properties.mapG_AllowRapidZ);

  writeComment(eComment.Info, " ");
}

function writeFirstSection() {
  // Write out the information block at the beginning of the file
  writeInformation();

  writeComment(eComment.Important, " *** START begin ***");

  if (properties.gcodeStartFile == "") {
       Start();
  } else {
    loadFile(properties.gcodeStartFile);
  }

  writeComment(eComment.Important, " *** START end ***");
  writeComment(eComment.Important, " ");
}

// Output a comment
function writeComment(level, text) {
  if (level <= properties.job3_CommentLevel) {
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
      let f = fOutput.format(propertyMmToUnit(properties.fr0_TravelSpeedXY));
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
      let f = fOutput.format(propertyMmToUnit(properties.fr1_TravelSpeedZ));
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
  if (!properties.frA_ScaleFeedrate)
    return feed;

  var xyz = Vector.diff(destPos, curPos);       // Translate the cut so curPos is at 0,0,0
  var dir = xyz.getNormalized();                // Normalize vector to get a direction vector
  var xyzFeed = Vector.product(dir.abs, feed);  // Determine the effective x,y,z speed on each axis

  // Get the max speed for each axis
  let xyLimit = propertyMmToUnit(properties.frB_MaxCutSpeedXY);
  let zLimit = propertyMmToUnit(properties.frC_MaxCutSpeedZ);

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

  let xyzLimit = propertyMmToUnit(properties.frD_MaxCutSpeedXYZ);
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
      writeComment("eComment.Info,  --- End custom gcode " + folder + _file);
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
  if (properties.job1_SetOriginOnStart) {
    writeComment(eComment.Info, "   Set current position to 0,0,0");
    writeBlock(gFormat.format(92), xFormat.format(0), yFormat.format(0), zFormat.format(0)); // Set origin to initial position
  }

  // Do a Probe on start?
  if (properties.probe1_OnStart && tool.number != 0 && !tool.isJetTool()) {
    onCommand(COMMAND_TOOL_MEASURE);
  }
}

function spindleOn(_spindleSpeed, _clockwise) {
  if (properties.job2_ManualSpindlePowerControl) {
    // For manual any positive input speed assumed as enabled. so it's just a flag
    if (!this.spindleEnabled) {
      writeComment(eComment.Important, " >>> Spindle Speed: Manual");
      askUser("Turn ON " + speedFormat.format(_spindleSpeed) + "RPM", "Spindle", false);
    }
  } else {
    writeComment(eComment.Important, " >>> Spindle Speed " + speedFormat.format(_spindleSpeed));
    writeBlock(mFormat.format(_clockwise ? 3 : 4), sOutput.format(spindleSpeed));
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
    if (properties.job2_ManualSpindlePowerControl) {
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
    writeBlock(mFormat.format(117), (properties.job8_SeparateWordsWithSpace ? "" : " ") + txt);
  }
}

function circular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (!properties.job4_UseArcs) {
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
    writeBlock(mFormat.format(291), (properties.job8_SeparateWordsWithSpace ? "" : " ") + v1 + v2);
  }

  // GRBL, include the message in a comment prefixed with MSG
  else if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(0), (properties.job8_SeparateWordsWithSpace ? "" : " ") + "(MSG " + text + ")");
  }
  
  // Default
  else
  {
    writeBlock(mFormat.format(0), (properties.job8_SeparateWordsWithSpace ? "" : " ") + text);
  }
}

function toolChange() {
  writeComment(eComment.Important, " Tool Change Start")

  // If tool changes are not to be include in the NC file then exit
  if (!properties.toolChange0_Enabled)
    return;
  
  // If there is a custom GCode file for tool changes then include it
  if (properties.gcodeToolFile1 != "") {
    loadFile(properties.gcodeToolFile1);
  }

  // Are we inserting code to assist with the tool change?
  // If not, then just insert tool change GCODE G6 <tool number> and a G54
  if (properties.toolChange1_InsertCode) {

    // Go to tool change position
    flushMotions();
    onRapid(propertyMmToUnit(properties.toolChange2_X), propertyMmToUnit(properties.toolChange3_Y), propertyMmToUnit(properties.toolChange4_Z));
    flushMotions();
  
    // turn off spindle and coolant
    onCommand(COMMAND_COOLANT_OFF);
    onCommand(COMMAND_STOP_SPINDLE);

    // If Marlin then BEEP
    if ((fw == eFirmware.MARLIN) && !properties.job2_ManualSpindlePowerControl) {
      writeBlock(mFormat.format(300), sFormat.format(400), pFormat.format(2000));
    }
  
    // Disable Z stepper
    if (properties.toolChange5_DisableZStepper) {
      askUser("Z Stepper will disabled. Wait for STOP!!", "Tool change", false);
      writeBlock(mFormat.format(17), 'Z'); // Disable steppers timeout
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
  if (properties.gcodeToolFile2 != "") {
    loadFile(properties.gcodeToolFile2);
  }
  
    // Run Z probe gcode
  if (properties.probe2_OnToolChange && tool.number != 0) {
    onCommand(COMMAND_TOOL_MEASURE);
  }

  writeComment(eComment.Important, " Tool Change End")
}

function probeTool() {
  // Command comment block
  writeComment(eComment.Important, " Probe to Zero Z");
  writeComment(eComment.Info, "   Ask User to Attach the Z Probe");
  writeComment(eComment.Info, "   Do Probing");
  writeComment(eComment.Info, "   Set Z to probe thickness: " + zFormat.format(propertyMmToUnit(properties.probe3_Thickness)))
  if (properties.probe7_SafeZ != "") {
    writeComment(eComment.Info, "   Retract the tool to " + propertyMmToUnit(properties.probe7_SafeZ));
  }
  writeComment(eComment.Info, "   Ask User to Remove the Z Probe");
  
  askUser("Attach ZProbe", "Probe", false);

  // Is Grbl?
  if (fw == eFirmware.GRBL) {
    // refer to http://linuxcnc.org/docs/stable/html/gcode/g-code.html#gcode:g38
    // Note this is not using the optional P parameter available on FluidNC (http://wiki.fluidnc.com/en/config/probe)
    writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(properties.probe6_G38Speed)), zFormat.format(propertyMmToUnit(properties.probe5_G38Target)));
  }

  // Not GRBL
  else {
    // refer http://marlinfw.org/docs/gcode/G038.html
    if (properties.probe4_UseHomeZ) {
      writeBlock(gFormat.format(28), 'Z');
    } else {
      writeBlock(gMotionModal.format(38.2), fFormat.format(propertyMmToUnit(properties.probe6_G38Speed)), zFormat.format(propertyMmToUnit(properties.probe5_G38Target)));
    }
  }

  let z = zFormat.format(propertyMmToUnit(properties.probe3_Thickness));
  writeBlock(gFormat.format(92), z); // Set origin to initial position
  
  resetAll();
  if (properties.probe7_SafeZ != "") { // move up tool to safe height again after probing
    rapidMovementsZ(propertyMmToUnit(properties.probe7_SafeZ), false);
  }
  
  flushMotions();

  askUser("Detach ZProbe", "Probe", false);
}