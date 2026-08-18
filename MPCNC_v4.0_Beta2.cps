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
//
// AND NOTHING IN THE KERNEL READS useZeroOffset. In Autodesk's posts it is read by exactly one function,
// validateCommonParameters(), which is not a library this post fails to import but a function spliced
// into each of their posts from include_files/commonFunctions.cpi -- and all it does with the flag is
// suppress an error() where getSection(0).workOffset is 0 and a later section's is greater. That
// refusal is right for them and wrong here: their offset 0 emits no G5x at all, so any mix is
// unresolvable, while this post's 0 resolves to G54 and a job mixing 0 with 2 posts correctly as G54
// then G55. So the flag stays false and inert, and the one genuinely ambiguous case -- 0 beside 1, two
// labels on one register -- is warned about by mixedDefaultAndExplicitWcs() instead of refused.
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
  jobManualSpindlePowerControl: {
    title      : "Manual Spindle On/Off",
    description: "On: the post prompts you to switch the router on and off by hand and emits no M3/M5 -- for a trim router or any spindle without electronic control. Off: the post commands the spindle with M3/M5. On Marlin those codes are a build option: a stock build has neither SPINDLE_FEATURE nor LASER_FEATURE, answers M3 with an unknown-command warning and runs the whole job with the spindle never started. V1 Engineering's own V1CNC builds enable LASER_FEATURE, where M3 does switch the spindle/laser pin -- but S is read as cutter power, not RPM, and M4 is not a reversal.",
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
    description: "Amount each line number rises.",
    group      : "job",
    order      : 70,
    type       : "integer",
    value      : 1,
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

  // ONE enabling control and one field. Group 3 answers a single question -- is the Personal edition
  // turning this job's rapids into cuts, and may the post turn them back?
  mapRapidsRestoreRapids: {
    title      : "Map G1s -> G0 Rapids",
    description: "Convert G1s back to G0 rapids where it is safe. Covers the three moves Fusion's Personal edition emits as cuts: horizontal moves at or above the Safe Z below, retracts and descents that stay above it, and each operation's first move.",
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
    description: "Z at or above this height is treated as safe air, so a G1 there may become a G0. The height is in the part's work coordinates -- measured from the touch-off Z0 at the stock top, never from machine zero. A number in mm, or Feed:/Retract:/Clearance:<fallback> to use the operation's own Fusion level -- Retract:15 means the Fusion retract level, or 15 mm if it has none.",
    group      : "mapRapids",
    order      : 20,
    type       : "string",
    value      : "Retract:15",
    scope      : "post"
  },

  // THE ONE TEST HOOK IN THIS FILE, and it exists because group 3 is otherwise unreachable by any
  // automated run: a paid licence delivers every link, retract and traverse to onRapid(), so
  // isSafeToRapid() is never consulted and nothing above can be exercised. The Personal edition
  // delivers those same moves as FEED moves; onRapid() below reproduces that when this is set.
  //
  // NO "group" KEY, DELIBERATELY, and it is doing two jobs. writeAllProperties() skips a property
  // with no group -- "not a dialog property" -- so a normal job's property dump is unchanged to the
  // byte, and "visible: false" keeps it out of the dialog. Autodesk ship the same idiom for the same
  // purpose: Data/Posts/tormach.cps, "Allow all tool numbers for probes", post kernel 5.388.0.
  //
  // Being out of the dump would otherwise cost the file its record of what produced it, so
  // validateJob() announces this one in BOTH channels instead. It cannot be on in silence.
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
  // FILLING THIS IS THE OPT-IN. There is no enum and no boolean beside it: the frame exists when the
  // machine declares Z homed AND this parses, and it does not otherwise. It sits here rather than in a
  // group of its own because a height in the machine frame is meaningless beside a declaration that the
  // machine has one. A STRING, not a number, because "empty" is what says NO FRAME and Fusion's schema
  // gives a numeric property no unset state -- and every sentinel would be a real reachable height, 0
  // very much included.
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
    description: "How the first (or only) part's origin is set. Set X0 Y0 to Current Pos, Probe Z0: X and Y from where the tool stands, Z0 probed on the stock top -- jog there first, there is no prompt. Set X0 Y0 Z0 to Current Pos: all three from where the tool stands. Use WCS X0 Y0, Probe Z0: keep the stored X0 Y0, probe Z0. Use WCS X0 Y0 Z0: use the stored origin, measure nothing. Jog to X0 Y0, Probe Z0: pause to jog there, record X and Y, probe Z0. Jog to X0 Y0 Z0: pause to jog there, record all three. WCS means the work offset this Setup names, which the post selects at job start -- not whatever your sender has active. For more parts see Each New WCS / Part.",
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
    description: "Multi-part jobs only: how each part's origin is set the first time the job reaches it. Every mode retracts to Machine Travel Z first. Use WCS X0 Y0, Probe Z0 Once per Part: move to the part's stored X0 Y0 and probe its stock top. Use WCS X0 Y0 Z0: use the stored origin, measure nothing. Jog to X0 Y0, Probe Z0: pause to jog to the part, record X and Y, probe Z0. Jog to X0 Y0 Z0: pause to jog there, record all three. Returning to a part already set up sets nothing again -- the tool moves to its stored origin and cuts, the probe point by then being a machined surface or air. Only a tool change re-opens that part's Z0. One part from several datums on one fixture is supported -- each datum is a work offset, like a part. A flip or a re-clamp is not: run those as separate jobs.",
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
  probeOffsetX: {
    title      : "Probe X Offset",
    description: "X distance from the part origin to the probe's touch-point, in whole mm -- for an origin at a corner or off the material. The same for every part. 0 probes at the origin.",
    group      : "probe",
    order      : 40,
    type       : "integer",
    value      : 0,
    scope      : "post"
  },
  probeOffsetY: {
    title      : "Probe Y Offset",
    description: "Y distance from the part origin to the probe's touch-point, in whole mm -- for an origin at a corner or off the material. The same for every part. 0 probes at the origin.",
    group      : "probe",
    order      : 50,
    type       : "integer",
    value      : 0,
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
  probeSafeZ: {
    title      : "Safe Z",
    description: "Height the tool retracts to after probing, in the part's work coordinates -- measured from the Z0 the probe has just set at the stock top, never from machine zero. A number in mm, or Feed:/Retract:/Clearance:<fallback> to use the operation's own Fusion level -- Retract:15 means the Fusion retract level, or 15 mm if it has none.",
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

  // THE POST PERFORMS NO TOOL CHANGE, on any firmware, and this group is what it does instead. A
  // measured change needs a probe, a subtraction and a register to hold the result, and the post can
  // supply none of the three -- it cannot compute an offset it will not learn until the operator swaps
  // the tool, hours after posting, and it can never read a register back. So its role is to arrive
  // correctly, hand over, and resume correctly. design.md -> Tool changes.
  toolChangeMode: {
    title      : "At a Tool Change",
    description: "What the job does when the tool number changes. The post never changes the tool itself. Refuse a multi-tool job: a job with more than one tool does not post -- split it into one file per tool. Manual change at a pause: the tool retracts, moves to the Manual Position if set, the spindle and coolant stop, and the program stops (M0) for you to change the tool. Do not jog at that pause. Sender or firmware macro changes it: the same retract and stops, then the token named by Tool Change Handled By below. Test that on air -- the post cannot check anything is listening, and an ignored token cuts on with the wrong tool. Hand-over needs Machine Travel Z, and is not available on Marlin.",
    group      : "toolChange",
    order      : 10,
    type       : "enum",
    // THE TITLES SAY WHO ACTS AND WHAT HAPPENS; the ids are unchanged and are not display text. "Refuse
    // to post" read as a blanket refusal and this mode refuses exactly one thing, a job carrying more
    // than one tool -- a single-tool job posts on it, which is the shipped default and the commonest
    // configuration there is. "Pause for a manual change" named the M0 rather than the party doing the
    // work, which is what the operator is actually choosing between.
    //
    // THE IDS STAY. A property id is what Fusion stores and what all four matrices pass on the command
    // line, so moving one resets every saved setting, alters the property dump in every saved artifact
    // and rewrites every case that names it. Nothing an operator sees says "Pause".
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
    description: "Who does the change after the hand-over, and so which token is emitted. Read only on Sender or firmware macro changes it. gSender: T and M6, which the sender must be set to intercept -- GRBL itself rejects M6. CNCjs: T and M6, but it only pauses, so the change and the re-zero are yours. UGS: T and M6, and its tool-change interception is OFF until you switch it on -- enabled, it removes the M6, passes the T word through so the machine state names the tool, moves to a safe height and a change position, waits for you, and can run a tool length probe if you have configured one. If you use that probe, set Tool Length Correction By to Tool change applies tool offset. RepRapFirmware tool table: T alone; your tools must be declared in config.g. Other: no token -- the file named in Sender Macro File is included instead. The post then re-asserts absolute mode, units and the work offset, and returns to Machine Travel Z.",
    group      : "toolChange",
    order      : 20,
    type       : "enum",
    values: [
      { title: "gSender (Sienci) -- T + M6",         id: "gSender" },
      { title: "CNCjs -- T + M6",                    id: "CNCjs"   },
      { title: "UGS (Universal Gcode Sender) -- T + M6", id: "UGS"  },
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
  // WHERE THE MANUAL CHANGE HAPPENS. Three fields and not one because Fusion's dialog has no vector
  // type, and STRINGS because empty is what says "do not move" -- exactly as Machine Travel Z's empty
  // says "no frame", and for the same reason: every numeric sentinel is a real reachable coordinate.
  //
  // MACHINE COORDINATES, which is the whole difference from the Tool Change X/Y/Z these replace. Those
  // were plain G0 words the dialog presented as absolute while the machine read them in whichever WCS
  // happened to be active, so the "fixed" change spot moved with every part origin. These are G53.
  toolChangePositionX: {
    title      : "Manual Position X",
    description: "Where the tool goes in X for a manual tool change -- an absolute machine coordinate in mm. Empty: it does not move in X or Y, and the change happens above the last cut. Fill both X and Y or neither. Needs X and Y declared homed and Machine Travel Z set, and is read only on Manual change at a pause. The tool does not return to the point it left; it returns to Machine Travel Z.",
    group      : "toolChange",
    order      : 40,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  toolChangePositionY: {
    title      : "Manual Position Y",
    description: "Where the tool goes in Y for a manual tool change -- an absolute machine coordinate in mm. Fill it with X or not at all. Bringing Y forward is usually what puts the spindle where you can reach it.",
    group      : "toolChange",
    order      : 50,
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
  // A DECLARATION, NOT A PROMPT, and that is the whole of PV-13. This was "Prompt for the First Tool",
  // a boolean whose On emitted one M0 saying "Load Tool #n" -- on EVERY mode, because it never read
  // "At a Tool Change" at all. So a job set up to hand every change to a sender or an ATC still stopped
  // and asked a human to fit the one tool the changer already holds. What the operator actually knows is
  // whether the tool in the spindle is the one this job starts with; who fits it if it is not is a
  // question they have already answered one field above.
  //
  // THE KEY CHANGED WITH THE SENSE. A saved `true` under the old key meant "prompt me" and under this
  // one would mean "no action" -- the exact inversion, silently. Renaming resets the setting to its
  // default, which is the cost stated at the head of this block, and the new default reproduces the old
  // shipped behaviour: no prompt, nothing emitted. PV-10 paid the same cost for the same reason.
  toolChangeFirstToolCorrect: {
    title      : "First Tool is Correct",
    description: "On: the tool in the spindle is the one this job starts with, and nothing is emitted for it. Off: the first tool is loaded before any origin is recorded or probed -- so Z0 is measured with the tool that will cut -- by whatever At a Tool Change says. Manual change at a pause, or Refuse a multi-tool job: a stop (M0) for you to fit it. Sender or firmware macro changes it: the same token every other change uses, so a changer loads it and no one is asked to. Ignored on the two Set ... to Current Pos origin modes, which take the origin from a jog you made with a tool already fitted.",
    group      : "toolChange",
    order      : 70,
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  // THREE ANSWERS AND NOT TWO, which is the whole of PV-10. This was a boolean whose Off carried two
  // incompatible assertions -- its own description said "for a sender or macro that already re-zeroes
  // OR applies a tool offset" -- and they differ in exactly the thing that matters to a multi-part job:
  //
  //   A TOOL-LENGTH OFFSET CORRECTS THE FRAME. G43/G43.1 shifts Z once, so EVERY work offset's stored
  //   Z0 stays valid at the same instant and none of them is touched.
  //
  //   A RE-PROBE, OR A HAND-ZERO, CORRECTS ONE REGISTER. The part it stands on is right afterwards and
  //   every other part is still measured by the tool just removed.
  //
  // The boolean could not tell those apart, so it treated a hand-zero as though it had corrected the
  // whole job -- one part fixed, the rest stranded silently. design.md -> Tool changes.
  //
  // THE KEY CHANGED WITH THE TYPE. A saved boolean cannot be coerced into an enum id by any rule this
  // project can verify without Fusion, so the rename makes the reset explicit and total: an operator
  // who had the old field Off gets "Probe" until they answer this one.
  toolChangeZ0Correction: {
    title      : "Tool Length Correction By",
    description: "Who corrects the work Z0 for the new tool's length. This machine has no tool-length system, so something must. GCode reprobes Z0 after change: this post re-probes Z0 at every change, and marks every OTHER part's Z0 stale so a return to it is re-measured too. Tool change applies tool offset: your sender or macro applies a tool-length offset, which shifts the whole Z frame -- every part's stored Z0 stays valid and this post probes nothing. User re-zeroed Z by hand at pause: you re-zero Z by hand at the pause, which corrects the part active at that pause and no other -- every other part is marked stale and is re-measured, or warned about, when the job returns to it. The probe searches down from Machine Travel Z, so G38 Target must reach the stock from there. No probe is written for tool 0 or a laser tool.",
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
  // THESE TWO USED TO SIT IN GROUP 7 and were the only tool-change settings outside this group. They
  // ADD to the hand-over sequence, where group 7's two REPLACE the post's header and footer, so they
  // never belonged beside them. Keys are unchanged, so nobody's saved setting resets.
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
    description: "Marlin custom pin number for the laser/plasma cutter. Read only in Pin mode.",
    group      : "laser",
    order      : 50,
    type       : "integer",
    value      : 4,
    scope      : "post"
  },
  laserGrblMode: {
    title      : "Laser: GRBL Mode",
    description: "GRBL mode of the laser/plasma cutter. M4 scales power with speed so corners are not over-burned; M3 holds it steady.",
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
  coolantChannelAOn: {
    title      : "Turn Channel A On",
    description: "The g-code that switches channel A on. Match it to your CNC Firmware -- the post emits it unchanged, so a Marlin code sent to GRBL is rejected mid-job. Use custom takes it from a file set further down this group. On GRBL neither code is guaranteed: stock Grbl 1.1 compiles M7 only when ENABLE_M7 is uncommented in grbl/config.h and answers error:20 without it, while FluidNC never errors and acts on M7 or M8 only where config.yaml declares a coolant mist_pin or flood_pin -- V1 Engineering's Jackpot 1 configs declare both pins, and its Jackpot 2 and Jackpot 3 configs ship NO_PIN for both.",
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
    description: "The g-code that switches channel A off. Same dialect as Turn Channel A On. On GRBL, M9 is the only off code and stops every coolant output at once.",
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
    description: "The g-code that switches channel B on -- the second, independent output. Same dialect as your CNC Firmware. M7 and M8 carry the GRBL build and config conditions stated under Turn Channel A On.",
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
    description: "The g-code that switches channel B off. Same dialect as Turn Channel B On.",
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
    description: "File with custom GCode to turn ON coolant channel A (in nc folder). Read only when Turn Channel A On is Use custom.",
    group      : "coolant",
    order      : 70,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelAOffCustom: {
    title      : "Channel A Off Custom",
    description: "File with custom GCode to turn OFF coolant channel A (in nc folder). Read only when Turn Channel A Off is Use custom.",
    group      : "coolant",
    order      : 80,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelBOnCustom: {
    title      : "Channel B On Custom",
    description: "File with custom GCode to turn ON coolant channel B (in nc folder). Read only when Turn Channel B On is Use custom.",
    group      : "coolant",
    order      : 90,
    type       : "string",
    value      : "",
    scope      : "post"
  },
  coolantChannelBOffCustom: {
    title      : "Channel B Off Custom",
    description: "File with custom GCode to turn OFF coolant channel B (in nc folder). Read only when Turn Channel B Off is Use custom.",
    group      : "coolant",
    order      : 100,
    type       : "string",
    value      : "",
    scope      : "post"
  },

  // RRF 3.x AND 2.05 ARE BOTH NAMED in these descriptions because the field is the operator's to set
  // and the two generations take different forms: 3.x moved spindle setup out of M453 into M950/M563
  // entirely, and moved M452's pin from P/I to C"pin". The defaults are the 3.x forms; neither names a
  // pin, because a missing pin means the laser never fires and a WRONG one drives an output the
  // operator did not choose. One command per field -- the string goes through a single writeBlock(). PR-13.
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
// ONE consumer, and it is not a tool change: toolChangeMacroCall(). The T word is emitted only where
// something OTHER than this post acts on it -- a sender that intercepts the M6 beside it, or RRF, whose
// T word IS the change. On every other route the tool is named in a prompt the operator reads.
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
  // TWIN: paired -- validateJob()'s Safe-Z expression warning, which loops the same two properties
  // through the same parseSafeZExpr() and names the same 15 mm fallback.
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
    // TWIN: paired -- validateJob()'s "is Use custom ... and that field is empty" warning, in CR-22's
    // own loop over the same four code/file pairs and on the same enum gate. CR-22 ruled the empty
    // field is the answer "no custom file" rather than an error, which settled the SEVERITY and not
    // the channel; the twin is what settled the channel. PV-12.
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

// WHAT A TOOL ASKS FOR, in ONE place, because two things read it and they must not be able to disagree:
// onCommand(COMMAND_COOLANT_ON) decides what to switch on, and validateJob()'s pre-flight decides what
// to warn about before the job runs. probePointMachinedBefore() is the same rule one path over, and
// HB-5's is why -- the two channels have to be the same question asked twice, not two questions that
// happen to agree today.
//
// TWO SOURCES AND NOT ONE. tool.coolant is Fusion's own constant and coolantLevels IS that index, so a
// milling tool answers for itself. F360 defines no coolant at all for a JET tool, which is why the laser
// group carries a forced level -- an air assist, usually -- and that property is the answer there. A
// walk that read tool.coolant alone would call every laser job dry. PV-12.
function requestedCoolant(t) {
  if (t.isJetTool()) {
    return getProperty(properties.laserCoolant);
  }
  return (t.coolant < coolantLevels.length) ? coolantLevels[t.coolant] : eCoolant.Off;
}

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
      // TWIN: paired -- validateJob()'s "asks for X coolant and neither channel is set to it", off
      // unmatchedCoolantRequests(), which reads the same requestedCoolant() this block's caller does.
      // AND THE TWO DIFFER IN ONE STATED WAY, which is why it is written at both ends: the pre-flight
      // is SILENT where both channel Modes are Off and this line is not. That is not drift. Both Modes
      // Off is the operator declaring the machine has no coolant, and Fusion's tools carry Flood
      // whether or not anyone wanted it -- the dialog would complain on nearly every hobbyist job. The
      // file is exact and per-occurrence either way, and this is the exact half. PV-12.
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

// True where one section names work offset 0 and another names 1 -- two labels on one register. Fusion
// reports 0 both for a Setup left at its default and for one where the default was chosen explicitly,
// so 0 IS 1, and collectDistinctOffsets() aliases them exactly as writeWCS() does. The consequence is
// not a wrong code but a job the post never sees as multi-part: the alias makes multiWcs false,
// writeWCS() answers "WCS unchanged" at the boundary, no establish runs, and the second Setup cuts on
// the first one's origin -- while Fusion's Operations panel shows two numbers.
//
// Any section against any other, which is not what Autodesk's own posts ask. validateCommonParameters()
// tests getSection(0).workOffset == 0 against each later section > 0 (grbl.cps, Rev 45769, spliced from
// include_files/commonFunctions.cpi), which misses a job whose FIRST section is the explicit one and
// refuses on any later offset, their offset 0 emitting no G5x at all. This post's 0 resolves to G54, so
// 0 beside 2 is G54 then G55 and is correct; only 0 beside 1 is ambiguous, which is why
// wcsDefinitions.useZeroOffset stays false and inert.
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

// The one place a dialect label means a firmware. Every built-in value in the four coolant code enums
// carries its dialect in its own title -- "Grbl: M7 (mist)", "Mrln: M42 P6 S255" -- so the check reads
// the declaration the operator chose from rather than a second list of codes that would drift the first
// time a value is added to a dropdown. Read in both directions: resolving a chosen code to a firmware,
// and naming the prefix the operator should be picking from.
var coolantDialectLabels = [
  { label: "Grbl", firmware: eFirmware.GRBL },
  { label: "Mrln", firmware: eFirmware.MARLIN }
];

// The label this post uses for a firmware's coolant codes, or undefined where it labels none -- which
// is RepRapFirmware, and is what scopes the warning below.
function coolantDialectLabel(firmware) {
  for (var i = 0; i < coolantDialectLabels.length; ++i) {
    if (coolantDialectLabels[i].firmware == firmware) {
      return coolantDialectLabels[i].label;
    }
  }
  return undefined;
}

// The firmware a coolant code property's CURRENT value was shipped for, off that value's own title.
// undefined is the answer "no dialect this post can name" and covers both "Use custom", where the file
// is the operator's and its dialect is unknowable, and any future unlabelled value.
function coolantCodeFirmware(prop) {
  var id = getProperty(prop);
  for (var i = 0; i < prop.values.length; ++i) {
    if (prop.values[i].id == id) {
      var label = String(prop.values[i].title).split(":")[0];
      for (var j = 0; j < coolantDialectLabels.length; ++j) {
        if (coolantDialectLabels[j].label == label) {
          return coolantDialectLabels[j].firmware;
        }
      }
      return undefined;
    }
  }
  return undefined;
}

// Every coolant level this job asks for that NEITHER channel Mode carries, with the operations that
// asked -- [{level, names}], or empty. setCoolant()'s own warning is exact and per-occurrence; this is
// the pre-flight half, and the requested level is requestedCoolant()'s answer on both sides so the two
// cannot come to disagree about what this job asks for.
//
// Gated on a configured channel, and this is the one place the two halves deliberately differ. Both
// Modes Off is not a misconfiguration -- it is the operator declaring this machine has NO coolant,
// which is the shipped default and true of most of them. Fusion's tools carry Flood whether or not
// anyone wanted it, so an ungated pre-flight would fire on nearly every hobbyist job, and a dialog that
// always complains is one nobody reads. The file still says it at every occurrence, unchanged. The
// condition worth a pre-flight is the other one: the machine HAS coolant and this job asks for a level
// it does not carry. CR-24, PV-12.
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

  // The test hook announces itself, in both channels, and first. It is the one property with no group,
  // so writeAllProperties() does not dump it and the file would otherwise carry no record that it was
  // posted under a simulated Personal licence. Running before any output puts the in-file half ahead of
  // every other line, CR-01's "$110" included -- an ordering that only ever occurs in a test artifact.
  if (getProperty(properties.mapRapidsTestPersonalLicence)) {
    // TWIN: here -- the model the whole walk was marked against, and the only pair written as one
    // block from the start. R2 asserts both channels, so neither can be removed quietly.
    writeWarning("TEST HOOK IS ON -- rapids are being delivered as feed moves to exercise group 3. "
      + "THIS FILE IS A TEST ARTIFACT. DO NOT CUT FROM IT.");
    warning(localize("\"TEST ONLY -- deliver rapids as feed moves\" is enabled. Fusion's rapids are "
      + "being delivered to the post as feed moves, which no licence you are running does. The output "
      + "is a test artifact and must not be cut."));
  }

  // Homing MOVES the tool, and the "Set ... to Current Pos" modes record wherever it ends up. Homing
  // is step 2 of writeFirstSection() and the origin write step 6, so a pre-jog dies in between.
  var startMode = getProperty(properties.probeOnStart);
  var changeMode = getProperty(properties.probeOnChange);
  var homedXY = machineHomesXY();
  var homedZ = machineHomesZ();
  // "Each New WCS / Part" is consulted only on a genuine WCS change (writeWCS()'s isTraverse),
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
  // qualifies -- X/Y homing destroys the pre-jogged XY, Z homing the height recorded as Z0. It is the
  // one pre-jog destroyer that cannot be reordered away, homing being step 2 of writeFirstSection()
  // with everything after it depending on the frame it makes. CR-15 moved the establish; this stands.
  if (homesAtJobStart() && (homedXY || homedZ) && originIsPreJogged()) {
    // Advice rather than prohibition: with X/Y declared homed, a stored fixture offset in the active
    // WCS is repeatable across power cycles, so it is a better answer than the destroyed pre-jog.
    warning(localize("\"Home at Job Start\" moves the tool onto the endstops of whichever axes "
      + "\"Axes Homed and Trusted\" declares, and it runs before "
      + "\"First WCS / Part\" records the current position as the part origin, so positioning the "
      + "tool before starting the job has no effect on those axes. On a homed machine the stored "
      + "offset in the active WCS is repeatable, so \"Use WCS X0 Y0, Probe Z0\" is the "
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
      storedOffsetControls.push("\"Each New WCS / Part\"");
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

  // A pre-jogged first part on a multi-part job, and the shipped default is what gets there. Guard B
  // has already refused this job unless X/Y are declared homed, on the grounds that it traverses
  // between STORED work offsets -- and then these two modes write part one's register from wherever the
  // tool stands when the file starts. A jogged origin is not the complaint: the SILENCE is. The two
  // "Jog to ..." modes write a register too but stop at an M0 and ask, and a probe writes Z alone.
  // Advice and not a refusal, CR-16's reason: loose stock for the first part beside fixtured ones is a
  // real workflow and the post cannot tell it from the mistake.
  if (multiWcs && originIsPreJogged()) {
    warning(localize("\"First WCS / Part\" is a \"Set ... to Current Pos\" mode and this job cuts "
      + collectDistinctOffsets().length + " parts. That mode takes the first part's origin from where "
      + "you jog the tool BEFORE the file starts and writes it into that part's work offset register, "
      + "with no prompt -- while every other part is cut at the origin already stored in its own "
      + "register. So one part is cut where you parked the tool and the rest at their fixtures, and the "
      + "offset you set for the first part at the machine is overwritten. The two \"Jog to ...\" modes "
      + "write the register too but stop and ask first; \"Use WCS X0 Y0, Probe Z0\" and \"Use WCS X0 "
      + "Y0 Z0\" leave it alone. If every part in this job is fixtured, use one of those two."));
  }

  // Two labels on one register, and the dialog is the only channel that can say so in time. The post's
  // alias of work offset 0 to WCS 1 is correct and is not what is warned about; the warning is for a
  // job carrying BOTH labels, where the operator is looking at two numbers in Fusion's Operations panel
  // while the machine has one register, and every per-part mechanism the post owns is switched off by
  // the alias rather than by a decision. Advice and not a refusal, CR-16's reason: two Setups that
  // really do share a fixture are entitled to be labelled this way.
  //
  // No file twin, PV-12's ruling: this is a property of the job knowable at onOpen(), and its answer
  // does not depend on where in the file it is noticed. writeWCS() already writes the alias at Info on
  // every section it applies to, which is the record.
  if (mixedDefaultAndExplicitWcs()) {
    warning(localize("This job names work offset 0 in one Setup and 1 in another, and they are the same "
      + "register: Fusion reports 0 for a Setup left at its default, so the post resolves both to WCS 1 "
      + "-- G54. Every section runs on ONE origin, and because the post sees a single work offset the "
      + "per-part origin work that \"Each New WCS / Part\" controls never runs at the boundary between "
      + "them. If those Setups are two fixtures, number them 1 and 2 in Fusion so each part gets a "
      + "register of its own. If they are one fixture, nothing is wrong here and the two numbers are "
      + "only a labelling difference -- the post cannot tell the two cases apart."));
  }

  // The post-time half of warnJogAtPauseNeedsSender(), sharing its one statement of the condition so
  // the dialog and the file cannot come to differ. The firmware test is that statement being non-empty
  // -- RepRap alone has none. Only the subsequent-part half carries multiWcs, that control being unread
  // on a single-offset job.
  if (jogAtPauseCondition() != "" &&
      (startMode == "Jog XY & Probe Z" || startMode == "Jog XYZ" ||
       (multiWcs && (changeMode == "Jog XY & Probe Z" || changeMode == "Jog XYZ")))) {
    warning(localize("A \"Jog to ...\" origin mode is selected, and " + jogAtPauseCondition() + ". "
      + "Check that before running this file -- without it the job stops at the prompt and cannot be "
      + "moved until it is resumed. Otherwise position the tool before starting and use a "
      + "\"Set ... to Current Pos\" or \"Use WCS ...\" mode."));
  }

  // PR-20, and it is the sender's threshold rather than the post's. gSender rewrites an M0 to "(M0)" in
  // its dataFilter unconditionally, but pauses its own stream only past its tenth sent line --
  // "if (sent > 10)", labelled a workaround for Carbide files that open with a meaningless M0
  // (src/server/controllers/Grbl/GrblController.js, master, read 2026-08-14). Below the threshold BOTH
  // halves fail together: the controller never sees the M0 because it was commented out, and the sender
  // does not hold, so the stop is deleted in silence. Sender.js's load() filters blank lines only, so
  // the threshold counts EMITTED LINES, comments included -- which makes "Comment Level" the one
  // setting that decides it, from a different group than every prompt it can silence.
  //
  // Every operator stop this post writes into its PREAMBLE is exposed, not only the jog modes', and the
  // count cannot be computed here, which is why the text hedges. Nothing the post emits of its own
  // clears ten at Off; but "Start File" REPLACES Start() with a file of the operator's own, of any
  // length, and validateJob() runs before a byte of it is read. Info never reaches the threshold, the
  // property dump alone being ~70 lines. Only the FIRST part is ever exposed: a boundary prompt is
  // thousands of lines in.
  //
  // A warning and not a guard, and no attempt to pad the preamble: filler emitted to satisfy an
  // undocumented constant in one sender would be invisible here and silently wrong the day it changes.
  // The probe arm does not test the tool, so a jet/tool-0 first part warns needlessly -- one line in a
  // dialog already telling that job its Z0 was never established.
  if (fw == eFirmware.GRBL &&
      commentLevels.indexOf(getProperty(properties.jobCommentLevel)) < commentLevels.indexOf(eComment.Info)) {
    var earlyPrompts = [];
    // (homedXY || homedZ) because writeMachineHoming() returns before the prompt when nothing is
    // declared homeable -- that job emits no stop to lose, and is already warned about above.
    if (promptsBeforeHome() && (homedXY || homedZ)) {
      // "at the very top" and not "the first line": on GRBL the travel-speed warning stands ahead of
      // it, and a comment counts toward gSender's ten -- Sender.js's load() filters blank lines only.
      earlyPrompts.push("the \"Pause, then Home\" stop, which stands at the very top of the file");
    }
    // Between the homing stop and the origin prompts because that is where it sits in the file:
    // writeFirstSection() runs it after the G53 establish and before writeWcsOnStart().
    //
    // Not on a pre-jogged origin and not on the hand-over, where toolChangeFirstLoad() writes no prompt
    // at all: this list names lines gSender may delete, so naming one the file does not contain sends
    // the operator looking for it. It narrows here where the guards below widen, being about the M0
    // alone. PV-13.
    if (!getProperty(properties.toolChangeFirstToolCorrect) && !originIsPreJogged() && !toolChangeIsMacro()) {
      earlyPrompts.push("the \"First Tool is Correct\" stop, which stands before the first part's origin is set");
    }
    if (startMode == "Jog XY & Probe Z" || startMode == "Jog XYZ") {
      earlyPrompts.push("the \"First WCS / Part\" jog prompt");
    }
    if (getProperty(properties.probePause) != "No" &&
        (startMode == "Current XY & Probe Z" || startMode == "Probe Z" || startMode == "Jog XY & Probe Z")) {
      earlyPrompts.push("the \"Attach ZProbe\" prompt before the first part's probe");
    }
    if (earlyPrompts.length > 0) {
      warning(localize("\"Comment Level\" is \"" + getProperty(properties.jobCommentLevel) + "\", which "
        + "leaves this job's preamble only a few lines long -- and gSender ignores an M0 in the first "
        + "ten lines it sends, a workaround for CAM that opens its files with a meaningless one. It "
        + "comments the M0 out either way, so a prompt that early is not postponed, it is DELETED: the "
        + "job runs straight past it. At risk here: " + earlyPrompts.join("; ") + ". Post at "
        + "\"Comment Level\" \"Info\" and the property dump puts ~70 lines ahead of every one of them. "
        + "Senders that do not special-case an early M0 are unaffected, and nothing after the first "
        + "part is affected on any sender."));
    }
  }

  // The post-time half of toolChangeFirstLoad()'s suppression, on the same predicate the file reads. A
  // setting that does nothing is the whole complaint: the operator asked for a stop that is not
  // written, and the reason is that these modes take the origin from a jog made before the file started
  // -- with a tool already fitted, by a tip every depth then measures from. Not gated on the frame.
  if (!getProperty(properties.toolChangeFirstToolCorrect) && originIsPreJogged()) {
    warning(localize("\"First Tool is Correct\" is Off, but \"First WCS / Part\" is a \"Set ... to "
      + "Current Pos\" mode, which takes this part's origin from where you jog the tool BEFORE "
      + "starting the file -- so a tool is already fitted by then, and nothing is emitted to load one. "
      + "Fitting a different tool would put every depth out by the difference in tool length, and on "
      + "\"Sender or firmware macro changes it\" the hand-over would move the tool off the position "
      + "about to be recorded. To load the tool during the run, use \"Jog to X0 Y0, Probe Z0\" or "
      + "\"Jog to X0 Y0 Z0\", which load first and position afterwards; otherwise turn \"First Tool is "
      + "Correct\" on."));
  }

  // The same boundary from the other side: this fires when no fixed Z reference is established and the
  // mode cannot lift. warning(), not error() -- the start height is a promise only the operator can make.
  //
  // Two texts for one configuration, because the two cases need different remedies and a job that homes
  // must not be told to do something homing undoes. "Use WCS X0 Y0, Probe Z0" is the one surviving mode
  // that probes from a height nothing in the file wrote, and once homing runs the non-homing advice --
  // position the tool clear of the stock before starting -- is false, the height being the endstop's
  // with no jog before the file able to reach it. PR-16.
  //
  // Not where the first tool is handed over, on the same predicate partProbe()'s twin reads: that arm
  // of toolChangeFirstLoad() runs BETWEEN the homing and the probe and moves the tool itself, so the
  // height is the macro's. The claim these two warnings make is narrow -- homing was the LAST thing to
  // move the tool -- and it has to stay checkable.
  if (startMode == "Probe Z" && !fixedZEstablishedInFile()) {
    if (homingMovesZ() && !firstToolChangeIsHandedOver()) {
      // One height, two consequences: the rapid to the stored X0 Y0 is an X/Y move, so it happens AT
      // the height the tool is holding, and the G38.2 is AT the stored X0 Y0 and searches DOWN FROM
      // that same height. The probe's position is the register's; only its start height is the tool's.
      warning(localize("\"First WCS / Part\" = \"Use WCS X0 Y0, Probe Z0\" rapids to the stored X0 Y0 -- an "
        + "X/Y move, made at whatever height the tool is holding -- and the G38.2 that follows searches "
        + "DOWN FROM THAT SAME HEIGHT, this job establishing no Z the post can move in. So one height "
        + "decides both whether the crossing clears your work and whether the probe can reach the stock, "
        + "and on this job \"Home at Job Start\" is what chose it. "
        + (fw == eFirmware.GRBL
            ? "The single \"$H\" this post emits on " + fw + " runs the build's whole homing cycle, and the "
              + "stock cycle homes Z FIRST to clear the work area -- so Z goes to its endstop here even "
              + "though \"Axes Homed and Trusted\" declares only X and Y."
            : "The \"G28 Z\" this job emits leaves the tool at the Z endstop.")
        + " Positioning the tool before starting the file has no effect on that height, and nothing "
        + "between the homing and the probe brings it back to one you chose. The post cannot know which end of the travel "
        + "your Z endstop is at, and both ends are wrong here: at the top of travel the stock is the "
        + "whole travel below, a \"G38 Target\" of " + getProperty(properties.probeG38Target) + " mm never "
        + "reaches it and the job stops on a probe-fail alarm; at the bed the search starts a pull-off "
        + "above the bed and runs down into it. Enter \"Machine Travel Z\" in \"4 - Machine Frame\" so "
        + "both moves start from a height you set, or set \"Home at Job Start\" to Off and position the "
        + "tool yourself."));
    } else {
      warning(localize("\"First WCS / Part\" = \"Use WCS X0 Y0, Probe Z0\" rapids to the stored "
        + "X0 Y0 before this job has established any Z the post can move in, so that traverse happens "
        + "at whatever height the tool is left at -- position it clear of the stock, clamps and "
        + "fixtures before starting the program. The probe that follows searches \"G38 Target\" DOWN FROM "
        + "that height, so set the target deep enough to reach the stock from where you leave the tool."
        + " \"Machine Travel Z\" removes both, by establishing a Z the post can move in itself."));
    }
  }

  // The machine park crosses the bed, and writeMachineParkXY() can retract first only in a frame THIS
  // JOB ESTABLISHED -- the same fixedZEstablishedInFile() the park itself reads, so this warning and the
  // file cannot disagree. A warning, not a guard: Fusion's own retract covers an ordinary milling job.
  if (getProperty(properties.machineParkAtEnd) == "Machine" && !fixedZEstablishedInFile()) {
    warning(localize("\"At End Park At\" = machine X0 Y0 crosses the bed to the homing corner, but "
      + "this job establishes no fixed Z reference to retract in, so the tool makes that crossing "
      + "at whatever Z the last operation left it at. Enter \"Machine Travel Z\", or park at work "
      + "X0 Y0."));
  }

  // The machine-Z frame is addressed with an absolute G53 rapid, and "Home at Job Start" is not
  // required for it -- the group-4 declaration is the trust assertion. The firmware decides whether
  // that is enough, and GRBL is the only one that decides in the operator's favour: with homing enabled
  // Grbl 1.1 comes up in Alarm and refuses all motion until homed, so a stale declared frame cannot
  // execute there at all. RepRap/RRF has no equivalent lock, and Marlin's is NO_MOTION_BEFORE_HOMING, a
  // build option this post cannot read.
  if (fw != eFirmware.GRBL && fixedZEstablishedInFile() && !homesAtJobStart()) {
    warning(localize("This job moves in the machine's own Z frame (G53), but \"Home at Job Start\" is "
      + "Off, so those moves are measured against whatever machine zero the board currently holds "
      + "rather than one this job established. " + fw + " may well run them anyway -- unlike GRBL it "
      + "has no unconditional lock on motion before homing. Home the machine at the controller before "
      + "starting this file, or set \"Home at Job Start\" to Home."));
  }

  // The post-time half of toolChange()'s no-frame warning, on the same predicate the file reads. Both
  // hand-over modes, because the frame is what the hand-over needs and not what the pause needs: a
  // manual change is the one pause where the operator's hands go to the cutter, and a macro change
  // costs the RETURN as well. Or the first tool is handed over, which a one-tool job reaches and
  // countDistinctTools() > 1 does not -- toolChangeMacroResume() owes the same return there and warns
  // in the file when it cannot make it. PV-13.
  if (getProperty(properties.toolChangeMode) != "Refuse"
      && (countDistinctTools() > 1 || firstToolChangeIsHandedOver())
      && !fixedZEstablishedInFile()) {
    warning(localize("\"At a Tool Change\" is \"" + (toolChangeIsMacro()
      ? "Sender or firmware macro changes it\", but this job establishes no fixed Z reference, so the "
        + "post can neither lift the tool before the macro runs nor return it to a known height "
        + "afterwards -- the next move starts from wherever the macro left it"
      : "Manual change at a pause\", but this job establishes no fixed Z reference, so the post cannot "
        + "lift the tool before handing it to you -- the pause happens at whatever height the last "
        + "operation ended at, and the re-probe after it rapids to the part origin from there")
      + ". Enter \"Machine Travel Z\" in \"4 - Machine Frame\"."));
  }

  // PV-7's post-time half, reading the SAME containment predicate the file half reads so the two
  // channels cannot come to disagree about what counts as a machined datum. What it cannot share is the
  // live state: at output time partProbe() knows a probe IS happening, and here the post has to decide
  // where one CAN happen. Two triggers, both read off the sections alone -- a tool change with "Tool
  // Length Correction By" = this post, which is the one that reaches a SINGLE-part job where nothing
  // else re-probes at all; and a WCS change under a probing "Each New WCS / Part", which is
  // writeWcsOnReturn()'s re-probe of a part this job has already cut.
  //
  // It over-reports, and the text says so: a return re-probes only where a change has since made that
  // part's Z0 stale, and that is state this pass does not carry. Over-reporting is the right direction
  // for a pre-flight about a datum, and the file half is exact. Tool 0 and jet tools are skipped,
  // neither being able to probe.
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
        + "uncut material with \"Probe X/Y Offset\" in \"5 - Part Origins\", or set \"Tool Length "
        + "Correction By\" to \"User re-zeroed Z by hand at pause\". This pass reports every "
        + "boundary where a re-probe CAN happen; the file itself warns only at the probes that are "
        + "actually written."));
    }
  }

  // FLOW 2's THREE WARNINGS, all of them about the same thing: the post emits a token and cannot see
  // whether anything acts on it. Nothing here is refusable -- each names a condition the operator can
  // satisfy and the post cannot check.
  if (toolChangeIsMacro() && countDistinctTools() > 1) {
    var senderId = getProperty(properties.toolChangeSender);

    if (toolChangeSenderIsGrblSender()) {
      warning(localize("\"Tool Change Handled By\" is \"" + toolChangeSenderTitle() + "\", so this job "
        + "hands each change over with M6 -- a command GRBL does not execute. It works only because the "
        + "sender removes the M6 from the stream and runs its own tool-change routine instead, and the "
        + "post cannot check that yours is set up to do it. If the sender is not configured for tool "
        + "changes the M6 reaches the controller and answers error:20, stopping the job with the tool "
        + "in the cut; if it is configured to IGNORE them, the change is dropped silently and the rest "
        + "of the job is cut with the tool already fitted. Test one change on air before trusting it."));
    }

    if (senderId == "RepRap") {
      warning(localize("\"Tool Change Handled By\" is the RepRapFirmware tool table, so this job hands "
        + "each change over with a bare T word. That word errors unless every tool number it uses is "
        + "declared with M563 in config.g, and it corrects nothing unless tpost<n>.g applies a "
        + "tool-length offset. Both are on the machine and neither is visible to the post."));

      // No second warning about the machine frame here, and PR-25 is why: RRF's G53 drops the TOOL
      // offset as well as the workplace offset, so "Machine Travel Z" is a carriage height on RRF
      // exactly as it is on GRBL, whatever tpost applied. DoStraightMove()/DoArcMove(),
      // src/GCodes/GCodes.cpp -- the same at 2.05 through 3.6.0. design.md's firmware table has the read.
    }

    if (changeReprobesZ0()) {
      warning(localize("\"Tool Length Correction By\" is \"GCode reprobes Z0 after change\" while "
        + "changes are handed to \"" + toolChangeSenderTitle() + "\", so the post probes Z again after "
        + "the macro returns and overwrites whatever the macro measured. That is right for a handler "
        + "that only pauses and wrong for one that re-zeroes or applies a tool offset -- there it asks "
        + "you to fit the touch plate at every change for a measurement already made. Set it to \"Tool "
        + "change applies tool offset\" if the macro establishes Z0."));
    }
  }

  // PV-10's two regime warnings, and neither is a twin of anything the file writes. Each names a
  // condition true of the WHOLE JOB and knowable at onOpen() -- the correction answer, the change flow,
  // the offset count, the tool count -- which is what separates them from the per-return warnings
  // writeWcsOnReturn() writes at the moment a specific part is reached.
  if (countDistinctTools() > 1) {
    // A manual pause hands over to nothing, so "the tool change applies a tool offset" names a party
    // that does not exist on this flow: the post emits M0 and no handler runs. Not refused, because the
    // operator may apply G43.1 through their sender by hand while the job waits, and the post can no
    // more see that than it can see a macro's tool table.
    if (toolLengthCorrection() == "Offset" && getProperty(properties.toolChangeMode) == "Pause") {
      warning(localize("\"Tool Length Correction By\" is \"Tool change applies tool offset\" while "
        + "\"At a Tool Change\" is \"Manual change at a pause\". A manual pause hands over to nothing "
        + "-- the post stops the program and waits -- so unless YOU apply a tool-length offset at that "
        + "pause, no offset is applied and every part's stored Z0 still measures from the tool just "
        + "removed. Choose \"User re-zeroed Z by hand at pause\" if that is what you do, or \"GCode "
        + "reprobes Z0 after change\" to have it measured."));
    }

    // The hand-zero reaches one part, and on a multi-part job that is the thing the operator has to
    // know BEFORE they post. The file says it too, at each change and at each return, but a person who
    // reads the dialog and sends the job would otherwise meet it only in a place they had no reason to
    // open -- and it is this value that puts the other parts in that position. PV-10.
    if (toolLengthCorrection() == "Manual" && collectDistinctOffsets().length > 1) {
      warning(localize("\"Tool Length Correction By\" is \"User re-zeroed Z by hand at pause\" "
        + "and this job cuts " + collectDistinctOffsets().length + " parts. Re-zeroing at the pause "
        + "corrects the ONE part whose work offset is active there; every other part's stored Z0 was "
        + "measured by the tool being removed. The post marks those parts stale, so a return to one "
        + "re-probes it where the mode can and says so in the file where it cannot -- but nothing "
        + "corrects them at the pause itself, and no hand-zero there reaches them."));
    }
  }

  // THE MANUAL CHANGE POSITION, the half of it that posts a valid file which then does something the
  // operator did not intend. The half that posts a file nothing can run is refused among the guards.
  if (countDistinctTools() > 1) {
    var tcz = toolChangePosZ();
    var tcAnyPos = (toolChangePosX() != undefined) || (toolChangePosY() != undefined)
                || (tcz != undefined);

    // Not refused. A change position clear of the fixtures may legitimately sit below the height that
    // clears them -- that is the point of bringing the spindle down to where a person can work at it --
    // but the tool holds this Z with hands on it, so the condition is worth stating once.
    if (tcz != undefined && getProperty(properties.toolChangeMode) == "Pause"
        && fixedZEstablishedInFile() && tcz < parseMachineTravelZ()) {
      warning(localize("\"Manual Position Z\" is " + tcz + ", below the \"Machine Travel Z\" of "
        + parseMachineTravelZ() + " -- the tool is held LOWER during the change than the height you "
        + "declared clears your fixtures. That is right only if the change position itself is clear of "
        + "everything on the bed at that height; the post crosses the bed at the travel height and "
        + "descends to this one only once it has arrived."));
    }

    // Said, not silently dropped. Driving the tool to a change position belongs to whatever performs
    // the change, in a frame the post cannot see, and a post that guessed would be putting the tool
    // somewhere the macro did not ask for. Silently ignoring a coordinate the operator typed is how the
    // deleted Tool Change X/Y/Z came to be trusted for years while it moved with every part origin.
    if (tcAnyPos && toolChangeIsMacro()) {
      warning(localize("A tool change position is set, but \"At a Tool Change\" hands changes to \""
        + toolChangeSenderTitle() + "\", so the post does not use it. Moving the tool to a change "
        + "position belongs to whatever performs the change -- it knows where its changer, its sensor "
        + "or its park is, and the post does not. The post still retracts to \"Machine Travel Z\" "
        + "before the hand-over and returns there afterwards."));
    }
  }

  // GRBL has no g-code for this, which is why it is a warning and not a block. Marlin and RepRap get
  // Start()'s "M84 S0" and are covered for the whole job; GRBL's equivalent is the $1 step idle delay,
  // a setting, and one the controller accepts only in Idle. stepper.c's st_go_idle() runs whenever the
  // segment buffer drains -- which an M0 pause causes -- and disables the drivers after $1 ms unless $1
  // is 255. The stock default is 25 (defaults.h, Grbl 1.1). The position COUNTER survives; what does
  // not survive is the axis holding against a hand.
  //
  // An M0 is not the only thing that drains it. A sender that stops sending while its own tool-change
  // routine runs drains the buffer exactly as a pause does, so the hazard is identical on both flows
  // and this gate is right -- but on the hand-over the file contains no pause at all. Hence two arms,
  // PR-16's shape: the hazard clause is shared and only the sentence about what this job DOES forks.
  // The macro arm claims nothing about who holds the stream, only that the post wrote no pause and
  // cannot bound the interval.
  //
  // Gated on the tool change rather than on every pause. The same setting protects the spindle prompts
  // and the probe's attach/detach stops, but this is the one that runs to minutes with a spanner on the
  // collet, and a warning on every job containing a prompt would be read by nobody.
  if (fw == eFirmware.GRBL && getProperty(properties.toolChangeMode) != "Refuse"
      && countDistinctTools() > 1) {
    warning(localize((toolChangeIsMacro()
        ? "This job hands each tool change to \"" + toolChangeSenderTitle() + "\", and the post writes "
          + "no pause for it -- but the machine still stands idle from the moment the tool stops moving "
          + "until whatever performs the change lets the job resume, and that interval is not the post's "
          + "to bound"
        : "This job stops the program (M0) for a manual tool change")
      + ". On GRBL the steppers de-energise once "
      + "the machine has been idle for $1 milliseconds -- 25 on a stock build. GRBL keeps counting "
      + "position, so nothing is lost unless an axis actually moves; a gantry nudged while the collet "
      + "is loosened, or a Z that back-drives with no holding torque, is enough, and every cut after "
      + "the change is then offset by an amount nothing reports. Set $1=255 at the controller to keep "
      + "the steppers locked. The post cannot set it for you: $ settings are not G-code and GRBL "
      + "accepts them only when it is Idle."));
  }

  // CR-10 -- PR-17's argument applied to X and Y. Machine zero is the point at which the switch
  // TRIPPED, and homing ends one pull-off inside it, so a rapid to machine X0 Y0 drives the axes back
  // onto the switches; with hard limits on, the program ends in Alarm instead of parked. $27 cannot be
  // read and no number is quoted -- the build option is named, as $1 and $110 already are. GRBL-gated
  // for the same reason PR-17 is: Marlin re-homes here instead of rapiding, and an RRF machine homed to
  // its axis minima rests AT the coordinate this block asks for.
  if (fw == eFirmware.GRBL && getProperty(properties.machineParkAtEnd) == "Machine") {
    warning(localize("\"At End Park At\" = machine X0 Y0 sends the tool to where the homing switches "
      + "tripped, not to where homing left the machine. On a stock Grbl build HOMING_FORCE_SET_ORIGIN "
      + "is off, so machine zero sits at the trigger point and the axes rest one pull-off inside it -- "
      + "$27 -- which means this park drives X and Y back onto the switches, and with hard limits "
      + "enabled the job ends in Alarm rather than parked. Correct only on a machine built with "
      + "HOMING_FORCE_SET_ORIGIN, which zeroes where homing leaves the axis. Otherwise park at work "
      + "X0 Y0 -- raising the pull-off does not help, machine zero staying at the trigger point."));
  }

  // Flow 1's end-of-file rule, stated where the park is set. A two-tool job on a Personal licence is
  // two posted files, and the second resumes on the origin the first left behind -- so a file must not
  // end by destroying it. On Marlin this park is a HOMING CYCLE, not a rapid (writeMachineParkXY()),
  // and set_axis_is_at_home() zeroes position_shift under HAS_POSITION_SHIFT
  // (Marlin/src/module/motion.cpp, 2.1.2.5). It never touches coordinate_system[], so a stored G5x
  // register survives -- but an ordinary single-offset Marlin job never re-selects one (see
  // writeWCS()), so nothing re-applies it.
  if (fw == eFirmware.MARLIN && getProperty(properties.machineParkAtEnd) == "Machine") {
    warning(localize("\"At End Park At\" = machine X0 Y0 HOMES X and Y on Marlin rather than rapiding "
      + "there, and homing zeroes position_shift -- the work origin this file established. The stored "
      + "G54-G59 registers survive it, but an ordinary single-offset job never re-selects one, so a "
      + "second file run after this one (the two-file answer to a tool change) starts against a zeroed "
      + "origin. Park at work X0 Y0, or establish the origin again at the start of the next file."));
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

  // The same class, on the fields that hold a machine coordinate. parseMachineCoordinate() answers
  // undefined for a typo exactly as it does for an empty field, and undefined IS the answer "not set" --
  // so "-12mm" in "Machine Travel Z" does not fail, it silently means NO FRAME, and a mistyped change
  // height silently means the tool does not go there. Nothing else says so: the header echo prints
  // "Fixed Z reference = None" for a job whose operator believes they gave it one. Not covered by the
  // X/Y refusal below, which tests the raw fields for the same thing but exists only on the manual flow
  // of a job with more than one tool; both firing together is right.
  var coordProps = [properties.machineTravelZ, properties.toolChangePositionX,
                    properties.toolChangePositionY, properties.toolChangePositionZ];
  for (var c = 0; c < coordProps.length; ++c) {
    var rawCoord = getProperty(coordProps[c]);
    if (rawCoord != "" && parseMachineCoordinate(rawCoord) == undefined) {
      warning(localize("\"" + coordProps[c].title + "\" is set to \"" + rawCoord + "\", which is not a "
        + "signed decimal number of millimetres -- so the post reads the field as EMPTY, which is the "
        + "answer \"not set\", and the motion it controls is simply not emitted. Give a plain number "
        + "such as -12 or -12.5, with no unit suffix and no other characters."));
    }
  }

  // The code is emitted unchanged, so a value taken from another firmware's half of the dropdown posts
  // straight into this job's dialect. CoolantA()/CoolantB() hand the chosen enum id to writeBlock()
  // with no firmware test of any kind, and nothing between the dialog and the file reads the pair --
  // the four code enums list both dialects together because one post serves both, and the operator is
  // the only thing that has ever matched them.
  //
  // Gated on the channel mode, CR-24's gate for CR-24's reason: the Mode ships Off, so a configured
  // channel is the operator's own opt-in and it is the property the emission itself reads. BOTH codes
  // of a configured channel are checked -- the off code is emitted as surely as the on code, and at
  // onClose() where a mid-stream refusal costs the whole job.
  //
  // Warned and not refused, and the label is exactly why: it says which firmware this post SHIPPED the
  // code for, not that no other firmware takes it. RepRapFirmware is not reached, deliberately -- the
  // post labels no value for it, so there is no declaration to contradict, and a warning on every
  // RepRap job with a channel configured would assert something no source read here settles. PV-12.
  var jobDialect = coolantDialectLabel(fw);
  if (jobDialect != undefined) {
    var coolantCodeProps = [];
    if (getProperty(properties.coolantChannelAMode) != eCoolant.Off) {
      coolantCodeProps.push(properties.coolantChannelAOn, properties.coolantChannelAOff);
    }
    if (getProperty(properties.coolantChannelBMode) != eCoolant.Off) {
      coolantCodeProps.push(properties.coolantChannelBOn, properties.coolantChannelBOff);
    }
    var wrongDialect = [];
    for (var cd = 0; cd < coolantCodeProps.length; ++cd) {
      var codeFw = coolantCodeFirmware(coolantCodeProps[cd]);
      if (codeFw != undefined && codeFw != fw) {
        wrongDialect.push("\"" + coolantCodeProps[cd].title + "\" is \"" + getProperty(coolantCodeProps[cd])
          + "\", which this post lists as " + codeFw);
      }
    }
    // One warning and not four. A channel's on and off codes are chosen as a pair and go wrong as a
    // pair, so a warning per field would say one sentence up to four times over a single mistake, and
    // the remedy is one decision -- unlike PV-12's per-level warning below, where two unmatched levels
    // really are two.
    if (wrongDialect.length > 0) {
      warning(localize("This job is posted for " + fw + ", and "
        + (wrongDialect.length == 1 ? "a coolant code it will emit belongs"
                                    : "coolant codes it will emit belong")
        + " to another firmware: " + wrongDialect.join("; ") + ". The post emits the code exactly as it "
        + "stands, so a controller that does not implement it answers the line as an unsupported command "
        + "and the job stops mid-operation with the tool in the cut. Choose the \"" + jobDialect
        + ":\" values in \"9 - Coolant\", or \"Use custom\" and a file of your own if your controller "
        + "takes something this post does not list."));
    }
  }

  // CR-24 -- M7 is not in every GRBL build, and the two dialects fail in OPPOSITE directions. Stock
  // grbl 1.1 compiles the mist code only when ENABLE_M7 is uncommented in grbl/config.h and it ships
  // commented out -- "// #define ENABLE_M7 // Disabled by default." -- and the #ifdef wraps both the
  // modal-group arm and the assignment (grbl/gcode.c, gnea/grbl v1.1h), so an M7 falls through to
  // "default: FAIL(STATUS_GCODE_UNSUPPORTED_COMMAND)": error:20, mid-section, with the tool in the cut.
  // FluidNC has no build option and NEVER errors: it sets the mist state only where
  // config->_coolant->hasMist() and otherwise leaves the block inert (FluidNC/src/GCode.cpp, 3.9.1;
  // hasMist() is _mist.defined(), CoolantControl.h), so the job cuts dry and nothing says so. M8 is
  // unconditional on stock grbl and pin-gated on FluidNC the same way, which is why one warning names
  // both codes.
  //
  // Named, not checked -- $1, $27 and $110's precedent: the build and the config.yaml are the machine's
  // and the post can read neither. Gated on the channel MODE rather than on what a tool requests.
  if (fw == eFirmware.GRBL) {
    var grblCoolantCodes = [];
    if (getProperty(properties.coolantChannelAMode) != eCoolant.Off) {
      grblCoolantCodes.push(getProperty(properties.coolantChannelAOn));
    }
    if (getProperty(properties.coolantChannelBMode) != eCoolant.Off) {
      grblCoolantCodes.push(getProperty(properties.coolantChannelBOn));
    }
    if (grblCoolantCodes.indexOf("M7") != -1 || grblCoolantCodes.indexOf("M8") != -1) {
      warning(localize("This job switches coolant with GRBL's own codes, and neither dialect guarantees "
        + "them. Stock Grbl 1.1 compiles M7 only when ENABLE_M7 is uncommented in grbl/config.h and it "
        + "ships commented out -- on such a build the M7 answers error:20 and stops the job mid-operation "
        + "with the tool in the cut, while M8 is always compiled in. FluidNC never errors here: it acts "
        + "on M7 only where config.yaml declares a coolant mist_pin and on M8 only where it declares a "
        + "flood_pin, and otherwise accepts the line and does nothing -- so the job cuts dry and nothing "
        + "in the file says so. Confirm the build or the config before this job runs; the post can read "
        + "neither."));
    }
  }

  // CR-24's outcome reached by the other route, and this one the post CAN see. Above, the codes are
  // right and the build may not carry them; here the channels carry codes for a coolant this job never
  // asks for, and the level it does ask for reaches neither. Same result at the machine. PV-12.
  //
  // Names the operations and the level, both: the level alone leaves the operator hunting a tool
  // setting across every operation, and the operations alone do not say which channel to set. One
  // warning per unmatched level, because the remedy is per level.
  var dryRequests = unmatchedCoolantRequests();
  for (var d = 0; d < dryRequests.length; ++d) {
    warning(localize("This job asks for \"" + dryRequests[d].level + "\" coolant and neither channel is "
      + "set to it -- \"Channel A Mode\" is \"" + getProperty(properties.coolantChannelAMode) + "\" and "
      + "\"Channel B Mode\" is \"" + getProperty(properties.coolantChannelBMode) + "\". "
      + (dryRequests[d].names.length == 1 ? "The operation that asks" : "The operations that ask")
      + " for it: " + dryRequests[d].names.join(", ") + ". The post emits no coolant code for them and "
      + "the job runs them DRY, which is a burnt cutter or a scorched edge in the materials coolant is "
      + "there for. Set one channel's Mode to \"" + dryRequests[d].level + "\" in \"9 - Coolant\", or "
      + "change what those operations ask for in Fusion."));
  }

  // --- Guards -----------------------------------------------------------------------------------
  // Every guard below applies on every firmware, and the order is about which complaint is the more
  // basic. Guard C used to return early on Marlin, making everything after it unreachable on exactly
  // the firmware it excluded.

  // The post performs no tool change. Refused rather than warned, and refused here rather than at the
  // boundary, because the alternative is a file that cuts every operation with whichever tool is in the
  // spindle, at the other tools' feeds and speeds. "Manual change at a pause" is the operator's
  // decision to hand over in one file; posting one tool per file is the other answer.
  if (countDistinctTools() > 1 && getProperty(properties.toolChangeMode) == "Refuse") {
    error("This job uses " + countDistinctTools() + " tools and \"At a Tool Change\" is \"Refuse a"
      + " multi-tool job\". This post changes no tool itself on any supported firmware -- it emits no M6"
      + " on this setting, which a GRBL controller answers with error:20 anyway. Post one tool per file;"
      + " or set \"At a Tool Change\" to \"Manual change at a pause\" to stop at each boundary and swap"
      + " the tool by hand; or to \"Sender or firmware macro changes it\" if your sender or firmware owns"
      + " a tool table and you have configured it to do the change.");
    return;
  }

  // Flow 2's guards. Refused rather than warned, because each is a hand-over to something that is not
  // there: the file would emit a token nothing acts on, and the job would carry on cutting with the
  // wrong tool -- the exact failure the Refuse default exists to prevent.
  //
  // Or the first tool is handed over. That is the same token to the same handler, so it owes the same
  // three refusals: a one-tool Marlin job would otherwise hand over to a firmware with no tool-length
  // register and no M6, a bare T to a GRBL sender, and an empty macro file to nothing. PV-13.
  if (toolChangeIsMacro() && (countDistinctTools() > 1 || firstToolChangeIsHandedOver())) {
    // Marlin has no tool-length register at all, so there is nothing for a macro to write an offset
    // into and no sender in the list that speaks to it. The operator is the only route, and the post
    // already has one: the manual pause. design.md -> Tool changes, the who-can-subtract table.
    if (fw == eFirmware.MARLIN) {
      error("\"At a Tool Change\" is \"Sender or firmware macro changes it\", but the firmware is"
        + " Marlin, which has no tool-length offset register -- there is nothing for a macro to correct"
        + " and no supported sender intercepts a tool change for it. M6 reaches Marlin as an unknown"
        + " command and the job carries on with the wrong cutter. Use \"Manual change at a pause\","
        + " which re-probes Z0 with the new tool and is the only correction Marlin has.");
      return;
    }

    var handler = getProperty(properties.toolChangeSender);

    if (handler == "RepRap" && fw != eFirmware.REPRAP) {
      error("\"Tool Change Handled By\" is the RepRapFirmware tool table, but this job is posted for "
        + fw + ". The bare T word that route emits is a tool change on RRF and nothing on any other"
        + " firmware -- GRBL parses it and takes no action, so every change would be skipped silently."
        + " Choose the sender that runs this machine, or \"Other\" with a macro file of your own.");
      return;
    }

    if (toolChangeSenderIsGrblSender() && fw != eFirmware.GRBL) {
      error("\"Tool Change Handled By\" is \"" + toolChangeSenderTitle() + "\", which is a GRBL sender,"
        + " but this job is posted for " + fw + ". Choose the handler that runs this machine, or"
        + " \"Other\" with a macro file of your own.");
      return;
    }

    if (handler == "Other" && getProperty(properties.toolChangeMacroFile) == "") {
      error("\"Tool Change Handled By\" is \"Other\", which hands each change over to the file named in"
        + " \"Sender Macro File\" -- and that field is empty, so there is nothing to hand over to. Name"
        + " the file, or choose the sender that runs this machine.");
      return;
    }
  }

  // Flow 1's position guards. Refused rather than warned, because each names a move the post would have
  // to invent a coordinate for, and every coordinate it could invent is a real machine position the
  // tool would travel to at rapid.
  if (countDistinctTools() > 1 && getProperty(properties.toolChangeMode) == "Pause") {
    var posX = toolChangePosX();
    var posY = toolChangePosY();
    var posZ = toolChangePosZ();

    // A half-specified point is not a point. Tested against the RAW fields as well, so a value that
    // does not parse draws the same complaint as one left blank: either way the axis is unset, and
    // "hold the other axis" and "use 0" are both moves nobody asked for.
    if ((getProperty(properties.toolChangePositionX) != "" || getProperty(properties.toolChangePositionY) != "")
        && (posX == undefined || posY == undefined)) {
      error("\"Manual Position X\" and \"Manual Position Y\" are read as one point, and this"
        + " job sets one of them without the other -- or sets one to something that is not a signed"
        + " decimal number of millimetres. Fill both, or empty both to change the tool where the cut"
        + " ended.");
      return;
    }

    if ((posX != undefined || posZ != undefined) && !fixedZEstablishedInFile()) {
      // THE SAME PREDICATE THE FILE READS. toolChangeMovesToPosition() answers false without a fixed Z
      // reference, so without this guard the fields would be accepted and then quietly not happen.
      error("A tool change position is set, but this job establishes no fixed Z reference -- there is no"
        + " machine frame to move in, and no height to cross the bed at before the tool gets there."
        + " Enter \"Machine Travel Z\" and include Z in \"Axes Homed and Trusted\", both in \"4 -"
        + " Machine Frame\", or clear the tool change position fields.");
      return;
    }

    // G53 X/Y needs X/Y homed, and the group-4 declaration is the only assertion the post has of it.
    // This is Guard B's requirement arriving by a second route: a stored machine X/Y means nothing on a
    // machine that has never established one.
    if (posX != undefined && !machineHomesXY()) {
      error("A tool change position in X and Y is an absolute machine move, but \"Axes Homed and"
        + " Trusted\" does not include X and Y, so the machine has no X/Y frame for it to be measured"
        + " in. Declare XY (or XYZ) in \"4 - Machine Frame\", or clear the tool change position"
        + " fields.");
      return;
    }
  }

  // A named include file that does not exist only reaches error() inside loadFile(), by which point
  // the header and preamble are in the stream. The tool-change files are checked only where the mode
  // that loads them is selected; the macro file is checked only where it is also the hand-over.
  var includeFileProps = [properties.includeStartFile, properties.includeStopFile];
  if (getProperty(properties.toolChangeMode) != "Refuse") {
    includeFileProps.push(properties.includeToolFile1);
    includeFileProps.push(properties.includeToolFile2);
  }
  if (toolChangeIsMacro() && getProperty(properties.toolChangeSender) == "Other") {
    includeFileProps.push(properties.toolChangeMacroFile);
  }
  // The four coolant files belong here for the same reason the four above do: writeCustomCoolantFile()
  // routes them through the same loadFile(), so a missing one takes the same late error() -- and the
  // two OFF files are read at onClose(), by which point the whole job has been written. Gated on the
  // enum beside each, which is the only thing that makes the field reachable. HB-7 scoped these out;
  // CR-22 is that scope closing.
  //
  // An empty field is not an error -- the loop below skips it and writeCustomCoolantFile() warns and
  // emits nothing, which is the answer "no custom file" -- but it does warn, in the dialog as well as
  // the file. The operator set that channel to read a file and named none, and that is worth saying
  // whether or not THIS job happens to drive the channel. PV-12.
  var coolantCustom = [
    { code: properties.coolantChannelAOn,  file: properties.coolantChannelAOnCustom },
    { code: properties.coolantChannelAOff, file: properties.coolantChannelAOffCustom },
    { code: properties.coolantChannelBOn,  file: properties.coolantChannelBOnCustom },
    { code: properties.coolantChannelBOff, file: properties.coolantChannelBOffCustom }
  ];
  for (var c = 0; c < coolantCustom.length; ++c) {
    if (getProperty(coolantCustom[c].code) != "Use custom") {
      continue;
    }
    if (getProperty(coolantCustom[c].file) == "") {
      warning(localize("\"" + coolantCustom[c].code.title + "\" is \"Use custom\", which takes that "
        + "code from the file named in \"" + coolantCustom[c].file.title + "\" -- and that field is "
        + "empty. Nothing at all is emitted for it, so this channel never switches by that route. Name "
        + "the file, or choose one of the g-codes in the dropdown."));
      continue;
    }
    includeFileProps.push(coolantCustom[c].file);
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

  // The field is the opt-in, so these fire only where it is FILLED. An empty field is not an error at
  // any offset count -- it is the answer "no frame", and Guard B below decides whether this job could
  // afford to give it. No "Home at Job Start" requirement: "Axes Homed and Trusted" is the trust
  // assertion, and homed at the controller, do not home here is a legitimate state. With homing enabled
  // Grbl 1.1 comes up in Alarm and refuses all motion until homed, so a stale frame cannot execute on
  // the default firmware at all; RepRap has no such lock and is warned above.
  if (parseMachineTravelZ() != undefined) {
    // Assumed, not refused. Marlin/src/gcode/gcode.cpp (2.1.2.5) gates "case 53:" through "case 59:"
    // inside one #if ENABLED(CNC_COORDINATE_SYSTEMS), off by default -- so a Marlin build either has
    // the machine frame AND the WCS registers, or neither. The post cannot read the build, and refusing
    // would deny the frame to every correctly configured CNC Marlin.
    if (fw == eFirmware.MARLIN) {
      warning(localize("This job moves in the machine's own Z frame with G53, which on Marlin is the "
        + "build option CNC_COORDINATE_SYSTEMS and is OFF in a stock configuration. The post assumes "
        + "your firmware was compiled with it; if it was not, Marlin reports G53 as an unknown command "
        + "and every travel-height move is silently skipped, leaving the tool wherever the last "
        + "operation ended. Check the build before running this file, or clear \"Machine Travel Z\"."));
    }
    if (!machineHomesZ()) {
      error("\"Machine Travel Z\" is a height in the machine's own homed Z frame, so it requires \"Axes Homed and Trusted\" to include Z -- declare that this machine homes Z, or clear the field.");
      return;
    }
    // PR-17. The post cannot validate an absolute machine coordinate -- that is settled design -- but
    // on GRBL it holds one bit of evidence. At Grbl's default HOMING_FORCE_SET_ORIGIN (off) the machine
    // zeroes into NEGATIVE space after $H, so every reachable Z is negative; a machine deliberately
    // zeroed at the bed makes a positive value right, and that is compile-time and unreadable.
    //
    // Zero is not the ceiling, it is the switch, which is why the test is ">= 0" and not "> 0".
    // limits_go_home() (grbl/limits.c, 1.1f) ends the cycle by assigning -homing_pulloff to the
    // position one pull-off BELOW the trigger, fixing the trigger itself at machine Z 0 by
    // construction. So "G53 G0 Z0" drives the axis back onto the switch it just released, and soft
    // limits pass it: system_check_travel_limits() (grbl/system.c, 1.1f) rejects target > 0, and 0 is
    // not > 0. The highest safe value is -$27, which the post cannot read, so the text names the
    // pull-off and never a number. CR-10's fact on the Z axis, where CR-10 has it on X/Y.
    if (fw == eFirmware.GRBL && parseMachineTravelZ() >= 0) {
      warning(localize("\"Machine Travel Z\" is " + parseMachineTravelZ() + ", which is at or above "
        + "machine zero. On a stock Grbl build (HOMING_FORCE_SET_ORIGIN off) homing leaves every "
        + "reachable Z negative, so a positive value is above the top of travel -- it alarms at the "
        + "first traverse with soft limits on, and drives Z into its hard stop with them off. ZERO IS "
        + "NOT THE CEILING EITHER: it is the point at which the Z endstop tripped, because homing ends "
        + "one pull-off below it, so a move to zero returns the axis onto the switch and soft limits do "
        + "not reject it. Set a height below machine zero by at least the homing pull-off ($27). If "
        + "this machine was built with HOMING_FORCE_SET_ORIGIN on, its zero is at the bed and a "
        + "positive value is correct -- the post cannot read that and will warn every time."));
    }
  }

  // The homing half is GRBL/RepRap-only because Marlin's park route (G28 X Y) RE-ESTABLISHES the frame
  // rather than addressing it, so it needs no prior homing -- unlike the Z retract above, which does.
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

  // Guard C is gone, and its message was the reason: "Marlin has a single coordinate frame" was a false
  // statement emitted to the user. Marlin/src/gcode/gcode.cpp (2.1.2.5) puts G54-G59 in the same
  // #if ENABLED(CNC_COORDINATE_SYSTEMS) as G53, with G59 taking the .1/.2/.3 subcodes -- nine
  // workspaces, individually selectable, persisted with EEPROM. Selection has full parity with GRBL and
  // RRF, and selection is what a multi-WCS job needs. A Marlin multi-part job is refused by exactly one
  // thing, Guard B below, on the same terms as every other firmware.

  // Guard B -- a multi-part job MUST have the fixed Z frame: the tool has to clear the fixtures on its
  // way between parts, and no single clearance height is meaningful across WCS whose origins are only
  // known after probing at runtime. Single-WCS is exempt, which is what leaves an ordinary one-part job
  // free to run without one. Unconditional since CR-13: gated on "Retract Across Parts", turning that
  // off was the one way to post the job this refuses, and what it posted was a traverse in the wrong
  // frame.
  //
  // The X/Y half lives here rather than on the frame: a Z-only G53 move needs machine Z and nothing
  // else, and it is the multi-part WORKFLOW -- moving between stored work offsets -- that needs a homed
  // X/Y zero. Stated once, so fixedZEstablishedInFile() can stay Z-only.
  if (collectDistinctOffsets().length > 1) {
    if (!fixedZEstablishedInFile()) {
      error("A multi-part job needs a Z frame that outlives one work offset -- the tool must clear the fixtures on its way between parts, and no single clearance height is meaningful across WCS whose origins are only known after probing at runtime. A homed machine already has that frame: set \"Axes Homed and Trusted\" to include Z in group 4 - Machine Frame, then enter \"Machine Travel Z\" beside it -- or post one job per part.");
      return;
    }
    if (!homedXY) {
      error("A multi-part job traverses between STORED work offsets, which are repeatable only on a machine with a homed X/Y zero -- set \"Axes Homed and Trusted\" to XYZ in group 4 - Machine Frame, or post one job per part.");
      return;
    }
  }
}

// Return every mutable module global to its declared initial value. onOpen() already did this for
// currentWorkOffset and sequenceNumber, which is the tell that this post does not rely on getting a
// fresh JavaScript context per output file. fOutput and gMotionModal are deliberately absent: both
// are rebuilt from properties in onOpen() on every branch, so that assignment IS their reset.
function resetPostState() {
  currentWorkOffset = undefined;          // no work offset emitted yet
  wcsVisited = {};                        // no part has been set up in this file
  wcsZ0Trusted = {};
  sectionsCompleted = 0;                  // nothing has been cut in this file yet -- PV-7
  sequenceNumber = getProperty(properties.jobSequenceNumberStart);
  forceSectionToStartWithRapid = false;
  // The other direction of the same debt: left true at end of file, the NEXT file's first rapid crosses
  // before it retracts -- the unsafe order on a rising Z. Every path in one file clears it, the first
  // rapidMovements() or rapidMovementsZ() after a relocated change being what pays it off, so this is
  // the reset that is owed rather than a live defect. CR-21.
  forceRapidXYBeforeZ = false;
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

  // NOT VALUES, BUT THE SAME LEAK, and it is the worst shape it takes: a modal that believes the
  // controller is already in the state it wants emits NOTHING. In a second file sharing one JavaScript
  // context that deletes Start()'s G90, its G20/G21 and its G94 -- so file two has no preamble at all,
  // and every absolute coordinate, every G53 move and every probe target in it rests on the controller
  // still holding the mode file one left it in. A STALE BELIEF IS A MISSING WORD, NOT A WRONG ONE, which
  // is why nothing in file two looks wrong. gPlaneModal was reset here alone, with a comment describing
  // exactly this failure mode -- the tell that the other three were an oversight beside it. CR-21.
  gPlaneModal.reset();
  gAbsIncModal.reset();
  gUnitModal.reset();
  gFeedModeModal.reset();

  // The same suppression one axis word at a time: a second file whose first move shares an axis value
  // with the last move of the first omits that word. THE CIRCULAR PAIR IS NOT ONE OF THESE, and calling
  // reset() on it threw out of onOpen() on every post: createReferenceVariable returns an object the
  // kernel gives no reset() at all -- engine 5.388.0, typeof iOutput.reset === "undefined", where
  // createVariable's is "function" -- and it needs none, being non-modal. It emits its value on every
  // call and suppresses only when that value equals the reference it is handed, which for an arc means
  // a zero offset and never a stale belief. PV-1. CR-21.
  // sOutput and fOutput need no reset here -- sOutput is created force:true and onOpen() rebuilds
  // fOutput from the properties on both branches, which IS its reset. CR-21.
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
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

// WHAT THIS JOB HAS ALREADY SET UP. currentWorkOffset suppresses a REPEAT of the active offset and
// nothing else, so a job that RETURNS to an earlier one -- rough every part, then finish every part --
// ran the full origin dispatch a second time and drove a G38.2 into a surface it had already cut.
//
// TWO RECORDS, BECAUSE ONLY Z GOES STALE. Nothing in a job moves a register's X0 Y0 once it is set,
// so a return never re-jogs and never re-writes XY. Z is the other question: this machine has no
// tool-length system at all (design.md), a work Z0 measures from the tool that probed it, and a
// correction that measures ONE part corrects that part alone -- which leaves every other one measuring
// from the tool just removed. So a change clears the Z half and nothing else clears either. CR-17.
//
// HOW MUCH OF IT A CHANGE CLEARS IS THE OPERATOR'S ANSWER, not a constant: a tool-length offset shifts
// the frame and strands nothing, a re-probe corrects the register it stands on, and a hand-zero
// corrects that same one register by a different hand. PV-10, and toolLengthCorrection() below is the
// one place the three are read.
var wcsVisited = {};     // work offset -> this job has entered it and established its origin
var wcsZ0Trusted = {};   // work offset -> its stored Z0 was established under the tool now loaded

// WHO CORRECTS THE WORK Z0 FOR THE NEW TOOL -- "Probe", "Offset" or "Manual". ONE READER of the
// property, because five sites act on the answer and they must not be able to disagree about it; that
// is the rule wcsOriginEstablishesZ0() already states for itself, applied to the property instead of
// to the state.
function toolLengthCorrection() {
  return getProperty(properties.toolChangeZ0Correction);
}

// DOES A TOOL CHANGE EMIT A G38.2? Exactly one of the three answers does, and every probe-shaped
// question in the post -- PV-7's machined-datum pre-flight, the Flow 2 over-measurement warning, and
// the change's own re-probe arm -- is asking this and not "is the correction the post's".
function changeReprobesZ0() {
  return toolLengthCorrection() == "Probe";
}

// HOW MANY SECTIONS HAVE FINISHED CUTTING. A count and not a section id: what PV-7 asks of it is
// "which toolpaths have already removed material", and onSectionEnd() is the one callback that answers
// that without the post having to reason about where it is in the job. probePointMachinedBefore() reads
// it; nothing else does, and nothing writes it but the callback below and resetPostState().
var sectionsCompleted = 0;

// Emit the work coordinate system (WCS) for a section. GRBL and RepRap/Duet support G54-G59 (RepRap
// also G59.1-G59.3), so the offset assigned in Fusion is honored. Stock Marlin has none -- the post
// sets the origin with G92 there and only warns when a non-default WCS was selected.
//
// THE SELECT HALF, AND NOTHING ELSE. It retracts in the machine frame and emits the G5x; establishing
// the new part's origin is writeWcsEstablish()'s, called by onSection() AFTER any tool change at the
// same boundary. One call did both, and that shape was what forced a boundary that is both a WCS change
// and a tool change to probe the part twice -- once with the OUTGOING tool on the way in, and again
// when the change re-probed the register it had just selected. Splitting it costs nothing to a boundary
// that is only one of the two: the establish simply runs with nothing between it and the select. PR-23.
//
// RETURNS THE ORIGIN WORK THIS BOUNDARY STILL OWES -- {workOffset, mode, canProbe} -- or undefined
// where it owes none: the WCS is unchanged, the offset is out of range, or this is the first section,
// whose origin belongs to "First WCS / Part" and is written inside writeFirstSection().
function writeWCS(section) {
  var workOffset = section.getWorkOffset();
  writeComment(eComment.Debug, " writeWCS: entry workOffset: " + workOffset + " currentWorkOffset: " + (currentWorkOffset == undefined ? "none" : currentWorkOffset));

  // Fusion reports workOffset 0 both when the Setup's Work Offset field was left at its default and
  // when the default was chosen explicitly, so 0 always means "use WCS 1".
  if (workOffset == 0) {
    workOffset = 1; // default to the first WCS (G54)
    writeComment(eComment.Info, " writeWCS: workOffset defaulted to: " + workOffset);
  }

  // ALL THREE FIRMWARES take this path. Marlin used to return here with a warning that its work
  // offsets "are not supported and are ignored" -- read from source (gcode.cpp 2.1.2.5), that was
  // false: G54-G59 sit in the same #if ENABLED(CNC_COORDINATE_SYSTEMS) as G53, and SELECTION has full
  // parity there. What differs is only how an origin is WRITTEN, which writeWcsOrigin() handles.
  if (workOffset == currentWorkOffset) {
    writeComment(eComment.Info, " WCS unchanged: " + workOffset + ", not re-selecting");
    return undefined;
  }

  // THE ORDINARY MARLIN JOB MUST NOT MOVE. A job that never leaves work offset 1 already sits in
  // Marlin's default workspace, so selecting it explicitly buys nothing -- and on a stock build, where
  // CNC_COORDINATE_SYSTEMS is off, "G54" is an unknown command the firmware would report on every
  // single-part hobby file. Suppressed only for that exact case: any job with a second offset, or one
  // assigned to a register other than the first, needs the select and gets it, because G92 writes
  // whichever workspace is ACTIVE and would otherwise land in the wrong one.
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
  // How to establish this added part's origin/Z (probeOnChange). The first part's is set by
  // probeOnStart in writeFirstSection(), so this covers the added parts only. Read HERE and handed to
  // writeWcsEstablish() rather than read again there: the two halves must answer one question once.
  var onChangeMode = getProperty(properties.probeOnChange);
  // THE SECTION'S OWN TOOL, not the global one. Both callers pass currentSection, whose tool IS the
  // global `tool` at that moment, so this emits exactly what it always did -- HR-24. Reading it off the
  // parameter is what makes that true by construction rather than by coincidence: this is the one
  // function in the post that is handed a section and could be called with one that is not current.
  // It is also the INCOMING tool at a boundary that changes tools, which is the tool the establish now
  // runs with -- so canProbe answers for the tool that will cut the part, not the one leaving. PR-23.
  var sectionTool = section.getTool();
  var canProbe = (sectionTool.number != 0 && !sectionTool.isJetTool());
  writeComment(eComment.Debug, " writeWCS: probeOnChange: " + onChangeMode
    + " previousWorkOffset: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset)
    + " canProbe: " + canProbe);

  // Retract Z FIRST, before selecting the new WCS -- its Z origin may be unknown, so an absolute Z
  // move there would be unsafe. The retract ENTERS NO WCS AT ALL: G53 addresses the machine frame
  // without selecting anything, so nothing has to be restored and the active WCS after it is whatever
  // the next section asks for. Guard B has already refused any multi-WCS job with no frame.
  var isTraverse = (previousWorkOffset != undefined);   // a genuine inter-part WCS change
  var machineFrame = isTraverse && fixedZEstablishedInFile();
  writeComment(eComment.Debug, " writeWCS: retract decision -- machineFrame: " + machineFrame
    + " isTraverse: " + isTraverse + " workOffset: " + workOffset);
  if (machineFrame) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before traverse");
  } else if (isTraverse) {
    // Unreachable behind Guard B, and an error rather than a move because there is nothing safe to emit:
    // with no fixed reference, no height means the same thing on both sides of the traverse. What used to
    // stand here was probeSafeZ() -- the retract level of the section being ENTERED, written BEFORE the
    // WCS select and so read in the PREVIOUS part's frame, a height belonging to neither part. CR-13.
    error("Internal: a WCS traverse reached output with no fixed Z reference -- Guard B should have refused this job.");
    return undefined;
  }

  writeComment(eComment.Info, " WCS changed: " + (previousWorkOffset == undefined ? "none" : previousWorkOffset) + " -> " + workOffset);
  writeBlock(gFormat.format(offsetCode));
  currentWorkOffset = workOffset;

  // The added-part origin/probe action applies only to a genuine WCS change (added parts). The
  // first section's origin is handled separately by writeWcsOnStart() (probeOnStart).
  if (!isTraverse) {
    return undefined;
  }

  return { workOffset: workOffset, mode: onChangeMode, canProbe: canProbe };
}

// WILL THE ORIGIN WORK IN THIS PLAN ESTABLISH Z0 ITSELF, with whatever tool is fitted when it runs? ONE
// STATEMENT OF IT, because two things read it and they must not be able to disagree: toolChange() hands
// its own re-probe over exactly where this is true, and writeWcsEstablish() is what then does the job.
//
// THE MODE ANSWERS THE FIRST HALF, and both dispatches answer it identically: "Jog to X0 Y0 Z0" sets Z0
// by the operator's hand whatever the tool, the two probing modes set it only with a tool that can
// probe, and "Use WCS X0 Y0 Z0" sets nothing at all -- which is why a change under THAT mode still owes
// the correction and keeps its re-probe.
//
// A RETURN ANSWERS A SECOND HALF, because writeWcsOnReturn() re-establishes Z only where a change has
// made it stale, and THIS BOUNDARY'S OWN OFFSET is left trusted by two of the three correction answers:
// "Offset" strands nothing at all, and "Manual" keeps the register the operator is about to re-zero at
// the pause. Under either, a return takes that function's non-establishing arm and this must not claim
// otherwise -- the change would drop a correction nothing else makes. So the test is changeReprobesZ0()
// and not "is the correction the post's": only that answer clears the offset this plan is about. PV-10.
//
// A FIRST VISIT runs the mode's full dispatch either way. Read before toolChange(), which is the one
// call that could change the answer, and reads nothing that it writes. PR-23.
function wcsOriginEstablishesZ0(plan) {
  if (!(plan.mode == "Jog XYZ" ||
        (plan.canProbe && (plan.mode == "Probe Z" || plan.mode == "Jog XY & Probe Z")))) {
    return false;
  }
  return !wcsVisited[plan.workOffset] || changeReprobesZ0();
}

// NOTHING ESTABLISHED Z0, and BOTH CHANNELS SAY SO. This used to read "the file is the only place that
// can say so at the moment it becomes true", which was the argument PV-9 overturned: the moment is not
// the constraint, the channel was, and warnBothChannels() gives the same statement to the operator who
// reads the dialog and sends the file without opening it. ONE WRITER for all four arms where a probing
// origin mode meets a tool that cannot probe -- tool 0 or a jet tool -- so the three that were silent
// and the one that warned cannot come to differ again.
//
// THE RECOMMENDED MODE IS THE CALLER'S, because the two dispatches offer different ones: group 5's
// first-part property has "Set X0 Y0 Z0 to Current Pos" and the subsequent-part one "Jog to X0 Y0 Z0",
// and those are the only values of each that set Z0 with no probe -- wcsOriginEstablishesZ0() is where
// that is stated, and this must not recommend a mode it would answer false for.
//
// writeWarning() and not writeComment(eComment.Info, ...): HB-9's rule, and this outliving Comment Level
// Off is the whole of the finding -- the three silent arms wrote eComment.Debug, so at the shipped Info
// the file commanded absolute Z words against an origin nothing had checked and said so nowhere. PV-3.
function warnZ0NotEstablished(useInstead) {
  // TWIN: here -- PV-3 raised it and left the channel to PV-9, which ruled it owed one. W25b and W28.
  warnBothChannels("a jet tool / tool 0 cannot probe, so Z0 was NOT established -- this job runs against"
    + " whatever Z origin is already stored. Use \"" + useInstead + "\" for a jet/laser job.");
}

// THE ORIGIN-ESTABLISH HALF of what used to be one writeWCS() call, taking the plan that call returned.
// It runs from onSection() AFTER any tool change at the same boundary, so the part is set up once, by
// the tool that cuts it: the change no longer arrives to overwrite a Z0 the outgoing tool measured, and
// where this half probes, the change's own re-probe is dropped rather than duplicated. PR-23.
//
// THE STATE IT READS IS THE STATE THE CHANGE LEFT. wcsZ0Trusted is emptied by a tool change, so a return
// to a part at a changing boundary now sees its own change rather than the previous section's -- which
// is what CR-17 meant by "only a tool change opens Z", one boundary later than the old order could say it.
function writeWcsEstablish(plan) {
  var workOffset = plan.workOffset;
  var onChangeMode = plan.mode;
  var canProbe = plan.canProbe;

  // A RETURN TO A PART THIS JOB HAS ALREADY SET UP takes none of the dispatch below. CR-17.
  if (wcsVisited[workOffset]) {
    writeWcsOnReturn(workOffset, onChangeMode, canProbe);
    return;
  }

  // Z IS AT MACHINE TRAVEL Z, and by whichever of two routes ran: writeWCS()'s own traverse retract, or
  // that retract and then a tool change, whose every arm ends by returning the tool to the same height --
  // writeToolChangeReturn() where an excursion moved it, toolChangeMacroResume() on the macro flow, and
  // neither where nothing moved after the arrive retract. The Replicate moves below emit X/Y only, so
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
    // zUntrusted: this part's stored Z0 is the value this mode exists to re-probe, so the probe writes
    // a provisional Z0 at the travel height and searches DOWN from there. CR-12.
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
      // Z0 PROVISIONAL and overwritten by the probe below, exactly as the first-part twin in
      // writeWcsOnStart() has always written it. This arm wrote no Z at all, so "G38 Target" was
      // measured from the stored Z0 -- CR-12's defect on a path CR-12 does not name. INSIDE the
      // canProbe guard, because on a tool that cannot probe nothing would overwrite the provisional
      // value and the mode would silently become "Jog to X0 Y0 Z0". CR-12.
      writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
      writeWcsOrigin(currentWorkOffset, 0, 0, 0);
      partProbe(true);
    } else {
      writeWcsOrigin(currentWorkOffset, 0, 0, undefined);
      // The jog set X0 Y0 and nothing set Z0, so the register keeps whatever Z it already held --
      // which is the same silence as the arm above, one mode over.
      warnZ0NotEstablished("Jog to X0 Y0 Z0");
      writeComment(eComment.Debug, " writeWcsEstablish: probe skipped (tool 0 or jet tool)");
    }
  }

  // This part is set up, so a later RETURN moves to its stored origin instead of re-establishing it.
  // Z0 counts as trusted whatever the mode did -- including "Use WCS X0 Y0 Z0", which writes none by
  // design, its whole premise being that the stored one is right, and the tool-0 arms, which have
  // already warned that nothing established it. The claim is "as good as this job can make it", and
  // the ONE thing that can falsify it afterwards is a tool change. CR-17.
  wcsVisited[workOffset] = true;
  wcsZ0Trusted[workOffset] = true;
}

// A RETURN TO A WORK OFFSET THIS JOB HAS ALREADY SET UP. Called from writeWcsEstablish(), which runs
// after writeWCS()'s machine-frame retract and G5x select and after any tool change at the same
// boundary -- so the tool is at the travel height, this part's own register is active, and the tool
// fitted is the one that will cut it.
//
// X0 Y0 IS NEVER RE-ESTABLISHED HERE, under any mode. Whatever the first visit settled -- a stored
// fixture offset, a jog, a recorded position -- is still what the register holds, and re-running the
// mode would re-prompt the operator to re-zero a part this job has already cut.
//
// Z0 IS RE-ESTABLISHED ONLY WHERE A TOOL CHANGE HAS INVALIDATED IT, and then by the mode's own Z
// answer: a probe where the mode probes, the operator's hand where the mode jogs, a warning where the
// mode has neither. CR-17.
function writeWcsOnReturn(workOffset, mode, canProbe) {
  var zStale = !wcsZ0Trusted[workOffset];
  writeComment(eComment.Debug, " writeWcsOnReturn: workOffset: " + workOffset + " mode: " + mode
    + " zStale: " + zStale + " canProbe: " + canProbe);

  // The only path here that emits a G38.2. partProbe() travels to the stored X0 Y0 itself and writes
  // Z ONLY, which is exactly what a return is allowed to touch -- so the jog mode needs no prompt:
  // its X0 Y0 answer was given on the first visit and nothing has moved it since.
  if (zStale && canProbe && (mode == "Probe Z" || mode == "Jog XY & Probe Z")) {
    writeComment(eComment.Info, "   Return to a part already set up; a tool change since means Z0 is re-probed");
    partProbe(false, true);
    wcsZ0Trusted[workOffset] = true;
    return;
  }

  // Every other case arrives at the part the same way: X/Y only, at the height the retract left.
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

  // "Use WCS X0 Y0 Z0" re-establishes nothing by design, and a tool 0 / jet tool has nothing to
  // re-establish it with. Suppressing the correction is right; silence is not -- the rule
  // writeWcsOnStart()'s and toolChange()'s tool-0 arms already follow. wcsZ0Trusted stays false, so a
  // later return to this part says it again.
  // TWIN: here -- PV-9's own site. BOTH ARMS REACH IT: the mode-side one, where "Use WCS X0 Y0 Z0"
  // re-establishes nothing by design, and the canProbe-false one, where the returning tool cannot
  // measure. Different reasons, one statement, so neither can be closed without the other. W11b, W27.
  warnBothChannels("this part's stored Z0 was measured with a tool that has since been changed, and"
    + " nothing here re-measures it -- every depth below is out by the difference in tool length."
    + " Set Z0 by hand before this part cuts, or use \"Use WCS X0 Y0, Probe Z0 Once per Part\"");
}

// Persists the current position as WCS wcsNumber's own origin; any of x/y/z may be undefined to leave
// that axis alone. TWO DIALECTS, and the difference is addressing, not capability:
//
//   GRBL / RepRap -- "G10 L20 P<n>" names its target, so it can write any register without selecting
//   it and cannot leak into another.
//
//   Marlin -- "G92", which under CNC_COORDINATE_SYSTEMS is a real per-WCS write and NOT the global
//   frame shift this post long recorded it as: G92.cpp (2.0.9.7 and 2.1.2.5) runs
//   "coordinate_system[active_coordinate_system] = position_shift" behind a WITHIN() bounds check. But
//   it can only ever write the ACTIVE workspace, and only positionally.
//
// That makes "the target is the active WCS" a precondition on Marlin rather than a coincidence. Every
// caller already satisfies it -- writeWCS() selects before writeWcsEstablish() dispatches and nothing
// between the two changes the selection, and probeTool() lost the target parameter that was the one way
// to violate it -- so this is an assertion, not a branch.
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

// THE job's fixed Z reference, and there is exactly one: the machine's own homed Z, addressed with G53.
// A frame whose Z0 does not move with stock thickness, and therefore the only frame in which one
// clearance height is meaningful across parts of differing thickness.
//
// THE FIELD IS THE OPT-IN. No enum and no boolean sits beside it: the frame exists when the machine
// declares Z homed AND "Machine Travel Z" parses, and it does not otherwise. The field ships empty, so
// an untouched dialog has no frame and a factory-default job is unchanged byte for byte; filling it is
// the whole act of choosing one, AT ANY OFFSET COUNT. Two controls that must agree is the failure mode
// this design retired, so it does not add another.
//
// Z-ONLY, deliberately: a G53 Z move needs machine Z trustworthy and nothing else. The homed-X/Y
// requirement belongs to the MULTI-PART WORKFLOW -- traverses between stored work offsets -- and is
// enforced once, on Guard B in validateJob(). "Home at Job Start" is NOT required either: the group-4
// declaration is the trust assertion, and the firmware carries the rest (see the unhomed warning in
// validateJob()). Named "InFile" because every consumer reasoning about WHERE THE TOOL IS asks whether
// this file established the frame, not what the dialog was set to.
//
// ALL THREE FIRMWARES, Marlin included. On Marlin G53 is behind CNC_COORDINATE_SYSTEMS, off by
// default, so the post ASSUMES the operator compiled it in and warns rather than refusing -- see the
// warning in validateJob(). That is one build option and it carries the whole Marlin story: gcode.cpp
// (2.1.2.5) puts "case 53:" through "case 59:" inside a single #if, so the machine frame and the WCS
// registers arrive together or not at all.
function fixedZEstablishedInFile() {
  return machineHomesZ() && parseMachineTravelZ() != undefined;
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

// WHETHER THIS JOB'S HOMING MOVES Z, which is NOT the same question as whether Z is declared homed --
// and the two answers differ on GRBL, where writeMachineHoming() emits a single "$H" and the BUILD's
// homing cycle decides which axes it moves. The stock cycle homes Z FIRST: HOMING_CYCLE_0 is
// (1<<Z_AXIS), commented "REQUIRED: First move Z to clear workspace", under a note reading "Defaults
// are set for a traditional 3-axis CNC machine. Z-axis first to clear, followed by X & Y" -- and the
// per-axis $HX/$HY/$HZ sit behind HOMING_SINGLE_AXIS_COMMANDS, default disabled and documented as
// "very rare" (grbl/config.h, Grbl 1.1h -- GRBL_VERSION in grbl/grbl.h, build 20190830, read
// 2026-08-17). So a GRBL job declaring X/Y alone still homes Z, which is writeMachineHoming()'s own
// "the capability split is BOOKKEEPING, NOT EMISSION" seen from the consumer side. Marlin and RepRap
// emit a per-axis "G28 Z", so the Z declaration is exact there.
//
// Read by the emission and by validateJob() alike so the file and the dialog cannot come to differ
// about which jobs move Z at start -- originIsPreJogged()'s rule, applied to the other axis. PR-16.
function homingMovesZ() {
  if (!homesAtJobStart()) {
    return false;
  }
  return (fw == eFirmware.GRBL) ? (machineHomesXY() || machineHomesZ()) : machineHomesZ();
}

// "Machine Travel Z" as a Number in MILLIMETRES, or undefined when the field is empty or does not parse
// as a signed decimal. UNDEFINED IS THE ANSWER "no frame", which is why this is a STRING property:
// Fusion's schema gives a numeric field no way to be unset, and every sentinel would be a real reachable
// height, 0 very much included. The value's SIGN is not judged here -- see PR-17's warning.
function parseMachineTravelZ() {
  return parseMachineCoordinate(getProperty(properties.machineTravelZ));
}

// The one reading of a machine-frame coordinate held as a string, shared by Machine Travel Z and the
// three tool-change position fields so a value one of them accepts cannot be rejected by another.
// UNDEFINED IS THE ANSWER "not set", and the empty string is the commonest way to say it.
function parseMachineCoordinate(raw) {
  if (typeof raw != "string") return undefined;
  var s = raw.replace(/^\s+|\s+$/g, "");
  if (!(/^[-+]?\d+(\.\d+)?$/.test(s))) return undefined;   // also rejects "" -- unset
  return Number(s);
}

// The manual change position, in MILLIMETRES, each axis independently undefined when its field is
// empty. Nothing may read the properties directly: the all-or-nothing rule on X/Y and the "Z alone is
// legal" rule below are enforced once, in validateJob(), against exactly these three answers.
function toolChangePosX() { return parseMachineCoordinate(getProperty(properties.toolChangePositionX)); }
function toolChangePosY() { return parseMachineCoordinate(getProperty(properties.toolChangePositionY)); }
function toolChangePosZ() { return parseMachineCoordinate(getProperty(properties.toolChangePositionZ)); }

// True when this job relocates the tool for a manual change. THE MODE IS PART OF THE QUESTION, not a
// separate test at each call site: on the macro flow these fields are inert, because driving the tool
// to a change position is the macro's job and it does it in a frame the post cannot see. A job with no
// fixed Z reference cannot move in the machine frame at all, so it answers false here too and
// validateJob() refuses rather than silently dropping the move.
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

// Numeric G-code for a work offset: 1-6 -> 54-59, 7-9 -> 59.1-59.3. Returns undefined if out of range
// for the firmware (the G59.x slots are RepRap-only); callers report the error.
function wcsGcode(workOffset) {
  if (workOffset <= 6) return 53 + workOffset;
  // Not GRBL, which stops at G59: Marlin's G59() takes the .1/.2/.3 subcodes under the same build
  // option as the rest (gcode.cpp 2.1.2.5), giving it nine workspaces exactly as RRF has.
  if (fw != eFirmware.GRBL && workOffset <= 9) return 59 + (workOffset - 6) / 10;
  return undefined;
}

// EVERY machine-frame move in this post goes through here, so the two call sites -- the travel-Z
// retract and the X/Y park -- cannot come to differ about how G53 is emitted. Pass the axis words
// already formatted; this adds G53 G0 and the feedrate.
//
// ONE BLOCK, ALWAYS, and now for two independent firmware reasons:
//
//   GRBL / LinuxCNC / RRF -- G53 "is not modal and must be programmed on each line", and "it is an
//   error if G53 is used without G0 or G1 being active". So nothing may be appended to this block, a
//   Z move and an X/Y park must be two blocks rather than one three-axis diagonal, and the G0 goes
//   through gFormat and NOT gMotionModal, which would suppress the word exactly when G0 is already
//   active.
//
//   Marlin -- G53() (Marlin/src/gcode/geometry/G53-G59.cpp, identical at 2.0.9.7 and 2.1.2.5) saves
//   active_coordinate_system, calls select_coordinate_system(-1), and restores it INSIDE
//   "if (parser.chain())". A G53 chained with its motion on one line therefore restores itself; a
//   BARE G53 on its own line leaves native space active for the rest of the job.
//
// The Marlin restore below is belt-and-braces on top of that, and it is not idle: the two reports of
// G53 misbehaving there -- issues 13843 and 14743, one of them from an operator on an MPCNC Marlin
// fork -- were both closed WITHOUT a fix commit, 13843 by a stale-bot for inactivity. So the post
// re-selects the active work offset itself rather than trusting a restore no commit ever landed. It
// re-selects currentWorkOffset's OWN G5x and never a fixed G54, which would be the wrong register on
// any job whose active offset is not the first.
//
// The resets bracket it because a machine-frame move invalidates the tracked work-frame coordinates
// and motion mode.
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

// Park at the machine's own X0 Y0 -- the homing corner -- as the last motion of the job. Two firmware
// routes, and not the same KIND of operation, which is why this feature's guard is firmware-dependent.
// GRBL/RepRap emit "G53 G0 X0 Y0", an absolute rapid ADDRESSING a frame the job must already have
// established, X/Y only. Marlin emits "G28 X / G28 Y", which RE-ESTABLISHES the frame instead --
// self-establishing, so it needs neither prior homing nor a build option, at the cost of being a homing
// cycle rather than a rapid. THAT TRADE IS STILL WORTH IT even now that the Z retract above may emit
// G53 on Marlin: the retract has no alternative, this does. Arithmetic is not a third route -- the G92
// work frame differs from the machine frame by an offset the post never knew and cannot read back.
function writeMachineParkXY() {
  // Retract before crossing the bed -- potentially a full diagonal. Only a job that ESTABLISHED a
  // fixed Z reference can retract at all, which is what fixedZEstablishedInFile() answers.
  // validateJob() reads the same predicate for its warning, so the two cannot drift.
  if (!fixedZEstablishedInFile()) {
    // TWIN: paired -- validateJob()'s "At End Park At = machine X0 Y0" warning, on the same
    // fixedZEstablishedInFile() this arm reads.
    writeWarning("no retract before parking at machine X0 Y0 -- this job establishes no fixed Z"
      + " reference; the tool crosses the bed at whatever Z the last operation left it at");
  } else {
    writeMachineTravelZ("Retract to the travel height in the machine frame before parking");
  }

  if (fw == eFirmware.MARLIN) {
    writeComment(eComment.Info, "   Park at machine X0 Y0 -- re-homing X/Y; G53 is a Marlin build option");
    // The in-file half of validateJob()'s Marlin park warning, so a file read on its own carries what
    // its last two blocks cost. set_axis_is_at_home() zeroes position_shift; coordinate_system[] is
    // untouched, but nothing in an ordinary single-offset job re-selects it. motion.cpp, 2.1.2.5.
    // TWIN: paired -- validateJob()'s Marlin park warning, gated on the same firmware and property.
    writeWarning("the two homing blocks below zero Marlin's position_shift -- the work origin this file"
      + " established. Any file run after this one must establish its own origin; it cannot resume on"
      + " this one's");
    writeBlock(gFormat.format(28), "X");
    writeBlock(gFormat.format(28), "Y");
    return;
  }

  // The in-file half of validateJob()'s CR-10 warning, so a file read on its own carries what its last
  // block costs. Below the Marlin return, this route being the only one that rapids at a switch.
  if (fw == eFirmware.GRBL) {
    // TWIN: paired -- validateJob()'s CR-10 warning, same firmware and same property.
    writeWarning("machine X0 Y0 is where the homing switches tripped, and on a stock Grbl build homing"
      + " leaves the axes one pull-off inside that point -- so the block below drives X and Y back onto"
      + " the switches, and with hard limits enabled this job ends in Alarm rather than parked. Correct"
      + " only on a machine built with HOMING_FORCE_SET_ORIGIN, which zeroes where homing leaves the"
      + " axis");
  }

  writeComment(eComment.Info, "   Park at machine X0 Y0");
  // The F word is not optional even on a G0: where the modal feedrate is honoured for G0, an F-less
  // rapid crosses the bed at the last CUT's feed. writeMachineFrameBlock() clears it first, hence fFormat.
  writeMachineFrameBlock([xFormat.format(0), yFormat.format(0)],
    getProperty(properties.feedsTravelSpeedXY));
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

  // SELECT, THEN CHANGE, THEN ESTABLISH -- and all three places in that order are load-bearing.
  //
  // THE SELECT IS FIRST because the post-change re-probe writes into whichever work offset is ACTIVE:
  // changing first put a fresh Z0 into the PREVIOUS section's register and left this section cutting on
  // a stale one, a plunge at the wrong depth on the very next move.
  //
  // THE ESTABLISH IS LAST because the part must be set up by the tool that cuts it. Selecting and
  // establishing in one call put the new part's probe ahead of the change, so the outgoing tool measured
  // a Z0 the incoming tool's re-probe then overwrote -- register-correct, and two probe cycles and four
  // attach/detach prompts where one and two would do. PR-23.
  //
  // The later-section half of the deliberate WCS-selection split: section 1 already selected inside
  // writeFirstSection(), which had to run before that section's origin write -- and its origin work is
  // "First WCS / Part"'s, done in there, so wcsOrigin stays undefined for it.
  var wcsOrigin = undefined;
  if (!isFirstSection()) {
    wcsOrigin = writeWCS(currentSection);
  }

  // The first section's tool LOAD is not here at all: it belongs before that section's origin work,
  // which writeFirstSection() has already done by this point, so it runs in there. What is passed is
  // whether the establish below re-establishes Z0 itself -- where it does, the change hands the job to
  // it instead of doing it twice; where it does not, the change's own re-probe is the only correction
  // there is and it stays. PR-23.
  if (!isFirstSection() && tool.number != getPreviousSection().getTool().number) {
    toolChange(wcsOrigin != undefined && wcsOriginEstablishesZ0(wcsOrigin));
  }

  if (wcsOrigin != undefined) {
    writeWcsEstablish(wcsOrigin);
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

// Emit a rapid. EVERY place in the post that means "make a rapid move" calls this, never onRapid(),
// so the test hook below can only ever capture moves FUSION delivered -- not moves the post makes on
// its own behalf, which must stay rapids whatever the hook is set to.
function emitRapid(x, y, z) {
  forceSectionToStartWithRapid = false;

  rapidMovements(x, y, z);
}

// Rapid movements -- Fusion's, delivered here.
function onRapid(x, y, z) {
  // THE TEST HOOK. Under a Personal licence Fusion delivers these same moves to onLinear() as feed
  // moves, which is the only condition under which group 3 runs at all. Forwarding here reproduces
  // that, so onLinear() decides whether each one converts back -- the code under test. The property
  // is invisible and defaults off; see its declaration for why it has no group.
  //
  // The feed handed over is Travel Speed X/Y purely so linearMovements() has something to print for
  // a move that is REFUSED conversion. A refused move printing a travel feed is the hook showing its
  // hand, not a defect -- which is one reason a file posted this way says so at the top.
  if (getProperty(properties.mapRapidsTestPersonalLicence)) {
    onLinear(x, y, z, propertyMmToUnit(getProperty(properties.feedsTravelSpeedXY)));
    return;
  }

  emitRapid(x, y, z);
}

// Feed movements
function onLinear(x, y, z, feed) {
  // Convert a Section's first cut move back to a Rapid; unrecovered, with scaling on, it runs at the
  // slowest cutting feedrate. Gated on the master property, which a full-licence job turns off.
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
  //
  // error() and not cycleNotSupported(): both abort, and the abort is right -- an F360 probing operation
  // asks the CONTROL to measure several points and compute an offset from them, so on firmware with no
  // arithmetic it is unimplementable rather than merely unimplemented. But the SDK helper names the
  // cycle and stops there, and a refusal that is permanent has to carry the alternative or the operator
  // has nowhere to go. The reason goes in the error() text rather than a warning comment because an
  // aborted post leaves no file for a comment to be read in.
  if (isProbeOperation()) {
    error(localize("WCS probing is not supported. A probing operation asks the controller to measure "
      + "several points and then COMPUTE the work offset from them; GRBL and Marlin have no arithmetic, "
      + "so there is no g-code to expand it into -- and expanding it anyway would emit plain G0/G1 moves "
      + "with no G38 at all, driving the tool into the work at feed rate. Set the work offset by hand in "
      + "the sender, or use this post's own Z touch-off in the \"5 - Part Origins\" property group."));
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
  // TWIN: none -- raised by the kernel from the operation's own request, which a pass over the
  // properties cannot see. Manual NC and toolpath commands are invisible to validateJob().
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
      // THE LEVEL COMES FROM requestedCoolant(), which validateJob()'s pre-flight also reads. THE TWO
      // ARMS STAY SEPARATE, and that is not tidying left undone: the milling arm calls setCoolant() even
      // with the answer Off, because that call is what turns a RUNNING channel off, and the jet arm must
      // not -- F360 defines no coolant for a jet tool, so Off there means "the laser group forced none"
      // and says nothing about what is running. Folding them would switch coolant off at every laser
      // section. PV-12.
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

    // ONE EVENT, TWO CALLBACKS. The kernel raises COMMAND_POWER_ON/OFF beside onPower(), which is what
    // emits the laser control -- the ">>> LASER Power ON" comment and the M3/M4 S<n> two lines above
    // this call. Named here so the fall-through below stops reporting that emission as a no-op:
    // onPower() owns it, and there is nothing left for this callback to do.
    //
    // THE FALL-THROUGH IS NOT SOFTENED. HR-13's rule is right and this was a missing case, not a wrong
    // channel -- a warning that outlives Comment Level Off is what a vanished Manual NC instruction
    // needs, and it reached the operator here on every power change of every jet job: 60 of the 975
    // lines of Cutting/Laser/center.cnc, each one denying the two lines above it. PV-2.
    case COMMAND_POWER_ON:
    case COMMAND_POWER_OFF:
      return;

    // AN OPTIONAL STOP IS TAKEN, ALWAYS. No supported firmware has a working "stop only if the operator
    // asked for it", so the choice is between a stop that cannot be skipped and a command that vanishes
    // -- and HR-13's own registered diff proposed M1 on the premise that "M1 is supported by all three
    // targets", which is true of the parser and false of the behaviour. All three parse it and it means
    // three different things. grbl 1.1 grbl/gcode.c: "case 1: break; // Optional stop not supported.
    // Ignore." -- accepted, no error, and nothing pauses. RepRapFirmware src/GCodes/GCodes2.cpp handles
    // "case 0: // Stop", "case 1: // Sleep" and "case 2: // Stop" in one block, so mid-file it ENDS THE
    // JOB. Only Marlin does what Fusion means -- Marlin/src/gcode/lcd/M0_M1.cpp waits for the LCD, under
    // HB-1's HAS_RESUME_CONTINUE. So the post emits M0, which pauses on all three, and says in the file
    // that the "optional" half is the part it could not keep.
    //
    // WARNED PER OCCURRENCE and outliving Comment Level Off, for the reason the fallback below gives:
    // Manual NC is invisible to validateJob(), so there is no post-time twin for this to survive in.
    // PR-20 is NOT extended to cover it either -- that enumeration is of the stops the POST puts in the
    // first ten lines of its own preamble, and it cannot see a Manual NC command at all.
    case COMMAND_OPTIONAL_STOP:
      // TWIN: none -- Manual NC, invisible to a pass over the properties, and the comment above says so.
      writeWarning("an Optional Stop was requested here and is emitted as an UNCONDITIONAL M0 -- none"
        + " of the three supported firmwares has a usable M1, so this pause cannot be skipped");
      writeBlock(mFormat.format(0));
      return;
  }

  // Anything this switch does not name reaches here. Until HR-13 it returned in silence: the Info
  // comment at the top of this function was the only trace, and at Comment Level Important or Off not
  // even that survives, so a Manual NC instruction left nothing behind at all. Below the switch rather
  // than as a default: case so a future case that breaks instead of returning is caught too.
  //
  // writeWarning(), NOT writeComment(eComment.Important, ...) as HR-13's own diff proposed: HB-9's rule
  // is that a warning outlives the level gate, and this one has no validateJob() twin to survive in --
  // Manual NC is invisible to a post-time pass over the properties.
  // TWIN: none -- same reason, and here the command itself is only known when the kernel raises it.
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
  // Stated even when there is NONE: the absence is what decides whether the tool can retract at all,
  // and a reviewer must be able to read it off the file rather than infer it from a missing block.
  writeComment(eComment.Info, "   Fixed Z reference = "
    + (fixedZEstablishedInFile() ? "machine Z -- the machine's own homed Z, addressed with G53" : "None"));
  writeComment(eComment.Info, "   Probe XY offset in output units = X" + xyzFormat.format(probeOffsetX()) + " Y" + xyzFormat.format(probeOffsetY()));
  // IN OUTPUT UNITS, because a G53 move is interpreted in the active G20/G21 -- so "G53 G0 Z-12" in an
  // inch file means -12 INCHES, and the mm the property is entered in is not what the machine reads.
  if (fixedZEstablishedInFile()) {
    writeComment(eComment.Info, "   Machine Travel Z in output units = "
      + xyzFormat.format(machineTravelZ()) + " -- absolute machine Z");
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
    // TWIN: paired -- validateJob()'s "asks this job to home, but Axes Homed and Trusted is None".
    writeWarning("\"Home at Job Start\" is on but \"Axes Homed and Trusted\" is None -- nothing was"
      + " homed");
    return;
  }

  // THE PRE-JOG DESTROYER, in the channel the operator running the file actually has. validateJob()
  // carries the post-time half and cannot carry this one: it runs from onOpen() with no output stream,
  // which is why the "nothing was homed" warning above is paired the same way. HB-5's rule -- a
  // property that fails one way fails in BOTH channels -- and PR-17, CR-10 and HB-13's precedent.
  // Above the homing motion rather than beside the origin write, because the homing is what destroys
  // the position and the operator reads downward. The two early returns above have already established
  // that homing is on and that an axis is declared, so the mode is the whole remaining condition.
  // Advice, not prohibition: a fixture AT machine zero is rare rather than impossible. PV-4.
  if (originIsPreJogged()) {
    // TWIN: paired -- PV-4, and it is this pair's precedent: the dialog had it, the file did not, and
    // the fix went to the emitter because validateJob() runs with no output stream.
    writeWarning("the homing below runs BEFORE \"First WCS / Part\" records the current position as"
      + " the part origin, so whatever this job records as X0 Y0 is where homing left the machine --"
      + " the endstop corner -- and not where you parked the tool. Positioning the tool before"
      + " starting this file has no effect on any axis \"Axes Homed and Trusted\" declares. Use"
      + " \"Use WCS X0 Y0, Probe Z0\" or a \"Jog to ...\" mode, or set \"Home at Job Start\" to Off.");
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
  // WHAT ACTUALLY SETS TRAVEL SPEED ON THIS CONTROLLER, said in the file because the file is what
  // reads as though the F word did it. GRBL and FluidNC take a rapid's rate off the axis limits and
  // never out of the block -- "if (block->condition & PL_COND_FLAG_RAPID_MOTION) {
  // block->programmed_rate = block->rapid_rate; }" with rapid_rate =
  // limit_value_by_axis_maximum(settings.max_rate, unit_vec), grbl/planner.c, plan_buffer_line(),
  // gnea/grbl 1.1. FluidNC is the same planner renamed -- block->motion.rapidMotion,
  // limit_rate_by_axis_maximum(), FluidNC/src/Planner.cpp 3.x.
  //
  // THE F WORD STAYS ON THE G0 REGARDLESS. It is still stored -- "gc_state.feed_rate =
  // gc_block.values.f; // Always copy this value", grbl/gcode.c -- so it sets the modal feed the next
  // cut inherits, which is why fOutput models it and why PR-9 put one on the park block. It simply
  // does not govern the rapid it rides on.
  //
  // ABOVE EVERY G-CODE BLOCK IN THE FILE, and ungated on GRBL. writeWarning() ignores Comment Level by
  // design (HB-9), so it survives at every level: the operator who never opens the post dialog is
  // exactly the one who needs it, and it is true of every job on this firmware.
  //
  // IT IS THE FIRST LINE OF THE FILE ONLY AT "Off". This function runs inside the FIRST onSection(), by
  // which point onParameter() has already written the generated-by, posts-processor, generated-at,
  // Document and Setup comments -- at eComment.Important, so they survive at Important and above and
  // vanish at Off, which is why the count in validateJob()'s PR-20 comment starts here. At Debug the two
  // parseSafeZProperty() traces from onOpen() stand ahead of it as well.
  //
  // IT NAMES BOTH DIALECTS because the post cannot tell them apart -- one "Grbl" answer covers
  // FluidNC, which kept the g-code and dropped the numbered settings ($110 does not exist there; the
  // limit is max_rate_mm_per_min per axis, FluidNC/src/Machine/Axis.cpp).
  if (fw == eFirmware.GRBL) {
    // TWIN: none -- true of EVERY job on this firmware, so a dialog line would fire on every GRBL post
    // and teach the operator to dismiss the dialog, which is where the pairs above have to be read. The
    // remedy is a controller setting changed once, not a per-job decision.
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

  // Select the WCS before Start()/includeStartFile and writeWcsOnStart(), both of which may set an
  // origin on top of the active WCS -- otherwise the origin lands on a stale one. The return value is
  // ignored and is always undefined here: isTraverse is false on the first section, whose origin is
  // "First WCS / Part"'s and is written below rather than by writeWcsEstablish().
  writeWCS(currentSection);

  writeComment(eComment.Important, " *** START begin ***");

  if (getProperty(properties.includeStartFile) == "") {
       Start();
  } else {
    // The include REPLACES Start(), which is the ONLY place this post sets absolute positioning, units
    // and -- on GRBL -- feed mode and plane; nothing re-asserts them later. Unlike a MISSING file, which
    // validateJob()'s pre-flight refuses before any output, a file that simply omits G90 has no
    // detectable failure at post time, so the precondition is stated in the FILE: the dialog's contract
    // is read once at setup, and this is the channel the operator running the job actually has. CR-05.
    // TWIN: none -- CR-05, argued above: a MISSING file is refused at post time, and a file that omits
    // G90 has no failure the post can detect, so what is stated is a precondition and not a defect.
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

  // TWO ORDERS, AND WHICH ONE APPLIES IS originIsPreJogged(). Both run the same three steps after
  // Start(), so absolute positioning and units are set for the probe or the G53 move either way.
  //
  // THE ORDINARY ORDER -- establish, load, origin. The establish leaves the tool holding a height
  // that clears the bed, and that height is where the travel to the first part's X0 Y0 starts from,
  // so it must precede an origin step that TRAVELS. Then the first tool is loaded before the origin
  // is set, because the first part's Z0 must be established with the tool that will cut it: loading
  // afterwards -- which is where onSection() used to do it -- probes with the very tool the load
  // exists to replace and puts every depth in the job out by the difference in tool length.
  //
  // THE PRE-JOG ORDER -- origin, then establish. On the two "... to Current Pos" modes the origin IS
  // where the operator already put the tool, so there is no travel to start from and the reason above
  // does not apply; what does apply is that the G53 move would DESTROY the position being recorded.
  // It carries one axis word, so it cost the Z half alone: "Set X0 Y0 Z0 to Current Pos" recorded
  // travel height as Z0 with no probe anywhere to correct it, and the shipped default's probe searched
  // "G38 Target" down from travel height rather than from a millimetre over the stock. CR-15.
  //
  // THE FIRST LOAD IS NOT REORDERED, IT IS DROPPED, and toolChangeFirstLoad() drops it -- these modes
  // already assert the cutting tool was fitted, the operator having jogged it to the origin by hand.
  // The "Jog to ..." modes are what load and THEN position, and the warning there names them. On the
  // hand-over route it is not merely redundant: the macro would move the tool off the position the
  // origin write below is about to record. PV-13.
  if (originIsPreJogged()) {
    toolChangeFirstLoad();
    writeWcsOnStart();
    writeFixedZReference();
    // The tool now stands at a machine height the work frame has no number for, and writeMachineTravelZ()
    // reports nothing to the kernel -- so getCurrentPosition() still holds the height writeWcsOnStart()
    // left, and the first section's rapid would be ordered against a Z the tool has left. Same case as
    // writeToolChangeReturn()'s, same remedy. Guarded, because writeFixedZReference() emits NOTHING
    // without a frame and an ordering constraint with no move behind it is a constraint on nothing.
    if (fixedZEstablishedInFile()) {
      forceRapidXYBeforeZ = true;
    }
  } else {
    writeFixedZReference();
    toolChangeFirstLoad();
    writeWcsOnStart();
  }

  // The first part is set up, so a later RETURN to its offset moves to the stored origin rather than
  // re-establishing it. Trusted whatever the mode did -- seeding this from "did the post probe?" would
  // send a "Use WCS X0 Y0 Z0" job to probe a surface it had already cut on the first return, which is
  // CR-17 unfixed.
  wcsVisited[currentWorkOffset] = true;
  wcsZ0Trusted[currentWorkOffset] = true;

  writeComment(eComment.Important, " *** START end ***");
  writeComment(eComment.Important, " ");
}

// Establish the job's fixed Z reference: move to "Machine Travel Z" in the machine's own frame. That
// leaves the tool holding a height that clears everything on the bed, measured in a frame that does not
// move with stock thickness, which is why this runs before the first part's own origin -- whatever it
// leaves the tool at is where the travel to the first part's X0 Y0 starts from. With the field empty
// there is no frame at job start, and partProbe() warns instead of moving.
function writeFixedZReference() {
  var established = fixedZEstablishedInFile();
  writeComment(eComment.Debug, " writeFixedZReference: " + (established ? "machine Z" : "none"));
  if (!established) {
    return;
  }
  // The in-file half of PR-17's post-time warning. Once, at the establish, rather than at every G53 --
  // the height is the same on all of them, and the reason is in validateJob() beside the source read.
  if (fw == eFirmware.GRBL && parseMachineTravelZ() >= 0) {
    // TWIN: paired -- PR-17's post-time warning, on the same firmware and the same parsed height.
    writeWarning("machine Z " + xyzFormat.format(machineTravelZ()) + " is at or above machine zero --"
      + " on a stock Grbl build homing leaves every reachable Z negative, and zero itself is where the"
      + " Z endstop tripped, one pull-off above where homing left the axis; a move there returns it onto"
      + " the switch and soft limits do not reject it. Correct only on a machine built with"
      + " HOMING_FORCE_SET_ORIGIN, which zeroes at the bed");
  }

  // The in-file half of validateJob()'s Marlin warning, so a file read on its own carries the
  // assumption its motion depends on. Once, at the establish, rather than at every G53.
  if (fw == eFirmware.MARLIN) {
    // TWIN: paired -- validateJob()'s Marlin G53 warning, gated on the same firmware.
    writeWarning("every G53 below assumes this Marlin was compiled with CNC_COORDINATE_SYSTEMS,"
      + " which is off in a stock configuration -- without it G53 is an unknown command and every"
      + " travel-height move in this file is skipped, leaving the tool where the last operation ended");
  }
  writeComment(eComment.Important, " Establish fixed Z reference -- homed machine Z");
  writeMachineTravelZ("Move to the travel height in the machine frame");
}

// Part-probe XY offset, in output units. The Z-probe touch-point for a PART is its WCS origin plus
// this offset, so the origin can sit at a corner or off the material while Z is read on the stock top.
// Applied to the first part and each added part.
function probeOffsetX() { return propertyMmToUnit(getProperty(properties.probeOffsetX)); }
function probeOffsetY() { return propertyMmToUnit(getProperty(properties.probeOffsetY)); }

// True when a part probe touches off somewhere other than the part origin, i.e. when the XY offset
// creates a traverse. One definition, so partProbe() and the first-part "... Current Pos" path -- which
// must retract before that traverse -- cannot disagree about when it happens.
function probeOffsetIsSet() { return probeOffsetX() != 0 || probeOffsetY() != 0; }

// HAS THIS JOB ALREADY CUT THE POINT A PART PROBE TOUCHES OFF ON? The touch-point is the part origin
// plus "Probe X/Y Offset", and that offset ships 0 -- so on a job whose earlier operations machine
// across their own origin, a later probe reads the MACHINED floor and writes it as Z0. Every depth after
// it, computed by Fusion against the ORIGINAL datum, then cuts that much deeper into the part. PV-7.
//
// THE ANSWER IS KNOWABLE FROM WHAT THE POST ALREADY WRITES INTO ITS OWN HEADER: getGlobalRange() and
// getGlobalZRange() are the toolpath's extents in the same WORK frame the touch-point is expressed in,
// so containment is a comparison and not an estimate. That is what makes the warning conditional rather
// than a line every job carries and every operator learns to skip.
//
// SCOPED TO ONE WORK OFFSET, because a range is measured from ITS OWN part's origin: a section in G55
// that cut through X0 Y0 says nothing about the material standing over G54's. Fusion's ambiguous 0 is
// aliased to 1 exactly as writeWCS() and collectDistinctOffsets() alias it.
//
// A BOUNDING BOX AND NOT A FOOTPRINT, which is the one thing this cannot be exact about: a contour whose
// box spans the origin may never have passed over it. So it over-reports and never under-reports -- the
// right direction for a warning about a datum, and the reason neither channel says the surface IS
// machined, only that the probe may land on it.
function sectionCutsProbePoint(section, px, py) {
  if (section.getGlobalZRange().getMinimum() >= 0) {
    return false;   // nothing below this part's datum: the touch-point is still the stock top
  }
  var xr = section.getGlobalRange(new Vector(1, 0, 0));
  var yr = section.getGlobalRange(new Vector(0, 1, 0));
  return (px >= xr.getMinimum()) && (px <= xr.getMaximum())
      && (py >= yr.getMinimum()) && (py <= yr.getMaximum());
}

// HOW A WARNING NAMES AN OPERATION, in one place. Fusion sends no operation-comment for an UNNAMED
// operation, so the index is the fallback -- 1-based, because that is what the operator counts down the
// browser tree. Two walks name operations now, PV-7's machined-datum one and PV-12's coolant one, and a
// second spelling would have the same job described two ways in two warnings the same dialog shows.
function operationName(section, i) {
  return section.hasParameter("operation-comment")
    ? ("\"" + section.getParameter("operation-comment") + "\"")
    : ("operation " + (i + 1));
}

// The sections before index `upto` that share `workOffset` and have cut through that part's probe point
// -- {names, zMin}, or undefined where there are none. ONE STATEMENT OF THE HAZARD, read by partProbe()
// for the file and by validateJob() for the dialog, so the two channels cannot come to disagree about
// which operations are at issue or how deep they went. HB-5's rule needs both halves to be the same
// question asked twice, not two questions that happen to agree today.
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

// How the two channels name the touch-point, in one place: which of the two things the operator has to
// look at -- the origin itself, or the origin plus an offset that has not moved it far enough.
function probePointDescription() {
  return probeOffsetIsSet()
    ? ("this part's X0 Y0 plus \"Probe X/Y Offset\" -- X" + xyzFormat.format(probeOffsetX())
       + " Y" + xyzFormat.format(probeOffsetY()))
    : "this part's X0 Y0, \"Probe X/Y Offset\" being 0";
}

// THE TWO "Set ... to Current Pos" MODES, and the one thing about them the rest of the post has to
// reason about: the origin is the position the OPERATOR left the tool at before the file started --
// "jog there first, there is no prompt", as the property says. Two consequences follow, and this is
// the single statement of the condition both turn on:
//
//   NOTHING EMITTED BEFORE writeWcsOnStart() MAY MOVE THE TOOL. writeFirstSection() therefore defers
//   the fixed Z reference on these modes, the G53 establish being the one preamble step that does.
//
//   THE TOOL THAT MADE THAT JOG IS THE TOOL THE JOB ASSUMES, so toolChangeFirstLoad() has nothing left
//   to load: fitting a DIFFERENT tool puts the recorded Z0 out by the difference in length, which is
//   the failure the load exists to prevent, arriving by the other route -- and a hand-over would move
//   the tool off the recorded position as well.
//
// Read by the emission and by validateJob() alike so the file and the dialog cannot come to differ
// about which modes these are -- the pair was spelled out inline three times before.
function originIsPreJogged() {
  var mode = getProperty(properties.probeOnStart);
  return mode == "Current XY & Probe Z" || mode == "Current XYZ";
}

// Operator-pause spec the next probeTool() honors: whether to prompt to attach the Z probe before and
// detach it after. A caller sets these just before invoking the probe; probeTool() reads them and then
// restores the true/true default, which is what the tool-change re-probe uses.
var probePauseBefore = true;
var probePauseAfter = true;

// A part probe: position to the part's Z-probe touch-point (its WCS origin plus the probe XY offset)
// and probe Z into the active WCS. `atOrigin` means the tool already sits on the origin, so the
// reposition is emitted only when the offset is non-zero; added parts pass false, being over the
// previous part. `zUntrusted` means this WCS's stored Z0 is not believed -- the two "Use WCS
// X0 Y0, Probe Z0" modes, which exist for exactly that reason -- so the probe writes its own
// provisional Z0 below and no absolute Z was emitted in this frame before it. Whether the traverse
// HEIGHT is also unknown is a SECOND question, asked separately: on the subsequent-part path the tool
// holds a height this post just wrote. Callers guard tool 0 / jet tools, and the base probe does not
// use this at all: it always touches off at the origin, with its own pause setting.
// `startsWhereHomingLeftIt` says the tool has not moved since writeMachineHoming() ran, which only
// writeWcsOnStart()'s call can be true of -- CALLER KNOWLEDGE, and that is why it is a parameter rather
// than a test in here. The other four callers all have motion between the homing and the probe: the two
// multi-part paths take writeWCS()'s retract, the return takes it too, and the tool change moves the tool
// by definition. Read only inside the no-frame warning below, whose text asserts a height the operator
// chose. PR-16.
function partProbe(atOrigin, zUntrusted, startsWhereHomingLeftIt) {
  var ox = probeOffsetX();
  var oy = probeOffsetY();
  var offsetSet = probeOffsetIsSet();

  // PV-7's in-file half, and it stands ABOVE the traverse and the G38.2 rather than beside them: it
  // reports a datum the operator has to correct BEFORE the probe runs, PV-4a's ordering rule.
  //
  // HERE RATHER THAN AT toolChange()'s CALL SITE, because every part probe touches the same point and
  // the question is the same at all of them. PV-7 found it on the tool-change re-probe;
  // writeWcsOnReturn()'s stale-Z re-probe is the identical hazard one path over, on a part this job has
  // demonstrably cut. The first part's probe reaches this with nothing completed and the walk answers
  // undefined, so the arm costs a factory job nothing.
  //
  // A WARNING AND NOT A SUPPRESSION: with no tool-length system this probe is the only correction there
  // is, and an origin off the material is the common professional case and correct as it stands. The
  // remedy already exists and is named -- "Probe X/Y Offset" is exactly the field that moves the
  // touch-point onto uncut stock, and its description names only the origin-at-a-corner case.
  var machined = probePointMachinedBefore(sectionsCompleted, currentWorkOffset);
  if (machined != undefined) {
    // TWIN: paired -- PV-7, and the pair that shows what a hand-built one costs: two predicates over
    // the same sections, each half saying in its own text that it must not drift from the other.
    writeWarning("this probe touches off at " + probePointDescription() + " -- a point this job has"
      + " ALREADY CUT, down to Z" + xyzFormat.format(machined.zMin) + " in "
      + machined.names.join(", ") + ". Where the tool lands on that machined surface instead of the"
      + " original stock top, the Z0 written below is that much low and every depth after it cuts that"
      + " much deeper into the part -- Fusion computed them against the original datum. Move the"
      + " touch-point onto uncut material with \"Probe X/Y Offset\" in group 5 - Part Origins, or set"
      + " Z0 by hand instead of letting this probe write it");
  }

  if (!atOrigin || offsetSet) {
    resetAll();
    // The rapid below is at an unknown height, so the file must say so. A WARNING and not an Info
    // comment: it reports a precondition the operator must satisfy, and Info is gone at Level = Off.
    if (zUntrusted && !fixedZEstablishedInFile()) {
      // TWIN: paired, and the walk had to enumerate the callers to say so. partProbe(false, true)
      // arrives from four places: the first part's own probe, which validateJob()'s "First WCS / Part
      // = Use WCS X0 Y0, Probe Z0 rapids to the stored X0 Y0" warning covers word for word; the tool
      // change's re-probe, which its no-frame warning covers by naming this rapid; and the two
      // multi-part paths, which Guard B refuses outright with no frame. No arm is uncovered.
      //
      // PR-16, AND THE PAIRING ABOVE IS WHAT FOUND IT. This text and its dialog twin both told the
      // operator the start height was theirs -- "before the program starts", "wherever you leave the
      // tool" -- and where the job homes it is not: homing is the last thing to move the tool before
      // this probe, so the height is the endstop's and no jog before the file can reach it. That is
      // the spoilboard base probe's defect exactly, one path over: it too ran wherever the tool
      // already sat, and it closed by DELETION, taking the code and leaving the class. Both halves
      // change together, on the same predicate, or the "word for word" claim above stops being true.
      //
      // ONE TWIN VERDICT OVER TWO TEXTS, and the tag above is deliberately left where it is: the two
      // arms are one statement about one configuration, differing only in who chose the height, so a
      // walk that split them would be counting texts rather than claims. It is the only such site.
      if (startsWhereHomingLeftIt && homingMovesZ()) {
        writeWarning("no Z reference is established, so the XY move below and the G38.2 under it both"
          + " start from whatever height the tool is holding -- and on this job HOMING chose that"
          + " height, not you. Nothing has moved the tool since, and nothing between here and the probe"
          + " brings it to a height you set, so positioning it before starting this file changes"
          + " neither move. Check that the crossing to X0 Y0 clears your stock, clamps and fixtures at"
          + " the height homing leaves. G38 Target is " + getProperty(properties.probeG38Target)
          + " mm here, and it is a DISTANCE measured from the endstop rather than from the stock --"
          + " check that it reaches. Setting \"Machine Travel Z\" removes both questions.");
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

  // Z0 written PROVISIONALLY, overwritten by the probe below, so "G38 Target" is a DISTANCE to search
  // and not a position measured from the very Z0 this mode was chosen BECAUSE it distrusts. Z ONLY --
  // the stored X0 Y0 is the other half of what these modes are for and is not this probe's to touch.
  // After the traverse rather than before it: the traverse is X/Y only, so the height is identical
  // either way, and here the write sits against the probe it bounds. Nothing reads the tracked Z
  // between this frame shift and probeTool()'s load-bearing resetAll(), so no reset is needed here. CR-12.
  if (zUntrusted) {
    writeComment(eComment.Info, "   Provisional Z0 at the current height so the probe target is a relative limit");
    writeWcsOrigin(currentWorkOffset, undefined, undefined, 0);
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

  // ONE STATEMENT, ABOVE BOTH ARMS. "Current XYZ" and "Current XY & Probe Z" write the origin at two
  // different sites and share both with the "Jog to ..." modes, so this goes where the MODE is read
  // rather than where the G10 is written. originIsPreJogged() keeps the Jog modes out: a register the
  // operator was asked to set is not one that changed behind them.
  //
  // BOTH CHANNELS, PV-4's ruling on the neighbouring pre-jog collision: the person about to run this
  // file is the one who can write the old offset down first, and by the G10 it is too late.
  if (originIsPreJogged() && collectDistinctOffsets().length > 1) {
    // TWIN: paired -- validateJob()'s "First WCS / Part is a Set ... to Current Pos mode and this job
    // cuts N parts", on the same two predicates.
    writeWarning("this file REPLACES the stored X0 Y0 of the part it starts on -- \"First WCS / Part\""
      + " is a \"Set ... to Current Pos\" mode, so the G10 below writes wherever the tool is standing"
      + " when this file starts into that part's work offset register. Every other part in this job is"
      + " cut at the origin already stored in its own register, untouched. Put the tool on this part's"
      + " origin before starting, and expect the offset you set for it at the machine to be gone.");
  }

  if (mode == "Skip") {
    // "Use WCS X0 Y0 Z0": trust the stored origin, so probeSafeZ() is meaningful in that frame.
    // "move" and not "retract" -- an ABSOLUTE Z means a tool parked above Safe Z descends to it first.
    //
    // HR-26 REOPENED, AND THIS ARM IS THE MIRROR OF IT. The finding was a base-clearance retract with no
    // tool-0 / jet guard where the establish beside it had one; it closed by deletion with the base. Here
    // the SAME retract carried the guard the other way round -- canProbe gated a CLEARANCE move on the one
    // mode that PROBES NOTHING. So a laser or a tool-0 job crossed the bed to the stored X0 Y0 at whatever
    // height it happened to hold, while a milling tool on byte-identical settings was lifted to Safe Z
    // first: the same job, the same dialog, differing on a tool property that has nothing to do with
    // clearance. Z0's trust is the MODE's premise and holds for every tool -- that is what "Use WCS
    // X0 Y0 Z0" MEANS -- so nothing in this arm depends on being able to probe.
    //
    // WHY THE MATRIX NEVER CAUGHT IT: the exposure is a job with NO FRAME. With one,
    // writeFixedZReference() has already put the tool at "Machine Travel Z" before this runs, and every
    // jet case on the books is multi-WCS, which Guard B refuses without a frame. The single-part laser
    // job that wants exactly this mode -- a jet tool has nothing to probe with, so the operator sets the
    // origin at the controller and tells the post to measure nothing -- is the one that had no retract.
    //
    // THE ARMS BELOW KEEP THEIR canProbe GUARDS AND MUST: each of those bounds a G38.2 or a provisional
    // Z0 that only a probe overwrites, so there the tool really is the condition. CR-12, PV-3.
    writeComment(eComment.Info, "   Use stored work origin; move Z to Safe Z, then to X0 Y0");
    resetAll();
    rapidMovementsZ(probeSafeZ());
    rapidMovementsXY(0, 0);
    flushMotions();
    return;
  }

  if (mode == "Probe Z") {
    // "Use WCS X0 Y0, Probe Z0": use the stored X0 Y0 and re-probe Z -- do NOT write XY. Unlike
    // Skip, Z is stale and about to be probed, so no absolute Z move is emitted in this frame.
    writeComment(eComment.Info, "   Use stored work origin X0 Y0; probe Z");
    if (canProbe) {
      // THE ONE CALLER THAT CAN STILL BE STANDING WHERE HOMING LEFT THE TOOL. Between
      // writeMachineHoming() and here the preamble emits the WCS select, Start() or the start file,
      // writeFixedZReference() and toolChangeFirstLoad() -- and only the last two can move anything. The
      // frame moves nothing when there is none, which is the very condition the warning inside asks
      // about; the first load moves the tool on ONE of its four arms, the hand-over, which is what
      // firstToolChangeIsHandedOver() answers. Read it rather than re-deriving it: it carries both
      // suppressions, so it says what was EMITTED and not what was asked for. PR-16, PV-13.
      partProbe(false, true, !firstToolChangeIsHandedOver());
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

// Every ">>> WARNING:" the post writes goes through here, and it IGNORES Comment Level: eight of them
// have no validateJob() twin to survive in -- six that should not and two that should. Off means less
// commentary, not fewer warnings. The prefix lives here rather than at the call sites so it cannot drift.
//
// EVERY CALL SITE CARRIES A "// TWIN:" VERDICT, so "grep -n '// TWIN:'" is the whole table and it lives
// beside the code rather than in a document that goes stale. Four values, and the reason clause is the
// point of each: "paired" names the validateJob() warning that already states the same condition before
// the job runs; "here" means both channels leave from one statement; "none" means only the emission
// point knows it, or a dialog line would fire on every job and train the operator to dismiss the
// dialog; "owed" is a defect with an open row. findings.md Step W ran this walk once.
//
// NO PARENTHESES IN THE TEXT PASSED HERE. writeCommentLine() hands it to sanitizeMessageText(_, "()"),
// which replaces every run of "(" or ")" with a space, because a grbl comment cannot nest and ends at
// the first ")". Use "--" or a comma; this bit three call sites before it was written down.
function writeWarning(text) {
  writeCommentLine(" >>> WARNING: " + text);
}

// BOTH CHANNELS FROM ONE STATEMENT. A condition fixed by the properties and the job's shape is
// actionable by someone who never opens the g-code, and every one of those used to reach the file
// alone -- writeWarning() is writeCommentLine() and nothing else. Pairing it by hand in validateJob()
// is the other route and it needs a SECOND predicate, computed from the sections at onOpen() to
// predict what the emitter will decide later; PV-7 has one such pair and says in both halves that they
// must not drift. This route cannot drift, because there is no second predicate and no second text.
//
// A PRE-FLIGHT IS NOT INHERENTLY EARLIER. The post dialog is read AFTER the post has run, so both
// channels arrive at the same moment; what a pre-flight buys is one statement about the whole job
// where this buys one per occurrence, which for a stranded part is the right count. PV-9.
function warnBothChannels(text) {
  writeWarning(text);
  warning(localize(text));
}

function writeComment(level, text) {
  if (commentLevels.indexOf(level) <= commentLevels.indexOf(getProperty(properties.jobCommentLevel))) {
    writeCommentLine(text);
  }
}

// Set by a tool change that RELOCATED THE TOOL IN THE MACHINE FRAME, and read once, in rapidMovements().
// It is what is LEFT OVER once noteCurrentPosition() reports every work-frame move the post injects: a
// machine-frame move has no work-frame value to report, so this is the one case where the post knows
// getCurrentPosition().z is not where the tool is and cannot correct it -- only refuse to read it.
var forceRapidXYBeforeZ = false;

// TELL THE KERNEL WHERE THE TOOL IS. getCurrentPosition() reports the TOOLPATH's position -- the kernel
// advances it from the movements it feeds to onRapid/onLinear, and it is blind to every move the post
// emits on its own account: the probe traverses, the safe-Z retracts, the return to X0 Y0. Four places
// read it and each was reading it stale after one of those -- rapidMovements() to order X/Y against Z,
// isSafeToRapid() to decide whether a G1 may be restored to a G0, and linearMovements() and the arc
// handler to project a feedrate onto the axes from the wrong start point.
//
// UNDEFINED MEANS UNCHANGED and not zero: an X/Y-only move must not claim a Z it did not command.
//
// WORK-FRAME POSITIONS ONLY, which is the whole limit of this. setCurrentPosition() takes a FRAME
// position -- the space getCurrentPosition() reports and getFramePosition() produces -- so a G53 move
// has nothing truthful to pass here: its work-frame value needs the WCS offset, and that offset is
// established at runtime by a G10 L20 from a probe the post cannot read. Autodesk's own posts leave the
// kernel stale across a machine-frame retract for exactly this reason, reporting that move only to the
// machine simulator on a channel that accepts MACHINE coordinates (haas.cps, writeRetract(), G53 case).
// So writeMachineFrameBlock() does not call this, and forceRapidXYBeforeZ still exists for the move that
// follows a G53 the post has no work-frame number for -- a tool change at a machine-frame position, and
// the pre-jog order's deferred fixed-Z establish. Passing a made-up number instead would order those
// moves correctly and silently corrupt the three other readers, which is the worse trade.
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

  // A COMMANDED WORK-FRAME Z IS WHAT ENDS THE DEBT. Whatever set the flag did so because the tool was
  // standing at a machine-frame height the work frame has no number for; the block above has just given
  // it one, so rapidMovements() may go back to reading getCurrentPosition() to order itself. The
  // re-probe after a relocated tool change is the path that clears it this way: it traverses X/Y with
  // rapidMovementsXY() and then retracts here, and the section that follows starts from a known Z.
  forceRapidXYBeforeZ = false;
}

// Combined X/Y/Z rapid, emitted as separate G0s at each axis's own travel feedrate. Ordered so we
// never plunge into the part: when Z is descending, position XY first and then bring Z down; when Z is
// rising or unchanged, retract Z first and then move XY.
function rapidMovements(_x, _y, _z) {
  // THE CASE THE COMPARISON BELOW CANNOT DECIDE, and it has TWO CALLERS that create it. Either way the
  // tool stands at a machine-frame height the work frame has never named, while getCurrentPosition()
  // still reports the last work-frame point the post told the kernel about. Reading it here would order
  // this move against a height the tool is not at, and the branch it picks on a RISING or unchanged Z --
  // retract first, then cross -- would send the tool across the bed at the section's own clearance height
  // instead of the travel height it is already holding. So the order is forced: cross at the height the
  // machine-frame move left, THEN descend.
  //
  //   writeToolChangeReturn() -- a relocated manual change. It costs no motion at all: there is no point
  //   retracing the excursion when the next move is absolute.
  //
  //   writeFirstSection()'s pre-jog order -- the fixed Z reference is established AFTER the first part's
  //   origin there, so the last preamble block is a G53 and not the probe retract that used to follow it.
  //   CR-15.
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
//
// A BLACKLIST PER CALL SITE, AND DELIBERATELY NOT AUTODESK'S WHITELIST -- expect that to be
// re-proposed, and the answer is here. Their posts declare settings.comments.permittedCommentChars and
// hand it to the kernel's filterText() inside their own formatComment(), so the whole of what the
// declaration does is supply a whitelist to a call the post already makes itself: there is NO
// kernel-side filtering to be had by declaring it (grbl.cps, Rev 45769, 2026-02-17, shipped with
// Fusion). The two also differ in kind. A whitelist DELETES what it does not list, where this replaces
// with a space -- which is what keeps a mangled operation name readable, HB-14 and HB-18's whole class.
// And grbl.cps's own list is " abcdefghijklmnopqrstuvwxyz0123456789.,=_-*:", permitting neither ">"
// nor "#" nor a quote, so adopting it would strip every ">>> WARNING:" this post writes down to
// " WARNING:" and take "Tool #2" with it. The one thing a whitelist would bound and this does not is
// non-ASCII arriving from an operation comment or a tool description; if that is ever wanted it belongs
// HERE as one clause, not in a list built for another post's messages. PV-19.
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

// WHETHER A "Jog to ..." MODE WORKS IS A CONDITION ON WHAT HOLDS THE PAUSE, NOT A FIRMWARE CAPABILITY,
// and what stood here said GRBL could not do it at all. ONE STATEMENT OF THAT CONDITION, returned from
// here and written by both channels -- the in-file warning below and validateJob()'s post-time twin --
// so the two cannot come to differ, which is the same discipline the park and probe warnings follow.
// Empty string means "no condition", which is RepRap and only RepRap.
//
//   RepRap -- a genuine firmware jog-at-pause. askUser()'s allowJog flag appends "X1 Y1 Z1" to M291,
//   and nothing outside the controller has to cooperate.
//
//   GRBL -- the SENDER decides. "A jog command will only be accepted when Grbl is in either the 'Idle'
//   or 'Jog' states" (Grbl v1.1 Jogging, gnea/grbl wiki) describes a controller that RECEIVED the M0,
//   and a streaming sender decides whether it ever does. gSender does not send it:
//   src/server/controllers/Grbl/GrblController.js (master, read 2026-08-14) rewrites the line in its
//   sender dataFilter -- line = line.replace(/M0+(?!\d)/i, "(M0)") -- above a this.workflow.pause(...)
//   that holds its own stream, so the controller stays Idle and jogs normally.
//
//   Marlin -- neither. M0 calls wait_for_user_response(), which is "while (wait_for_user) idle();", and
//   idle() reaches queue.get_available_commands() but never queue.advance() (MarlinCore.cpp, 2.1.2.5).
//   Serial commands are ACCEPTED AND QUEUED at the pause and execute only after it, so a jog sent down
//   the wire runs late -- into the part, on a machine the operator believes is stopped. The panel's own
//   move-axis UI is not gcode and is unaffected, which is why this is a condition and not a refusal.
//
// Called at the jog dispatch sites rather than inside askUser(), which also serves non-jog prompts.
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

function warnJogAtPauseNeedsSender() {
  var condition = jogAtPauseCondition();
  if (condition == "") {
    return;
  }
  // TWIN: paired -- validateJob()'s jog-at-pause warning. Both halves take their condition clause
  // from jogAtPauseCondition(), so the dialog and the file cannot come to say different things.
  writeWarning(condition + ". Check this before running the file: without it the job stops here and"
    + " cannot be moved until it is resumed.");
}

function askUser(text, title, allowJog) {
  if (fw == eFirmware.REPRAP) {
    // No leading space here: writeBlock()'s word separator supplies one when "Include Whitespace" is
    // on, and the conditional prefix below supplies one when it is off. A third carried here put two
    // spaces after M291 at every setting. HR-19.
    var v1 = "P\"" + sanitizeMessageText(text, "\"") + "\" R\"" + sanitizeMessageText(title, "\"") + "\" S3";
    var v2 = allowJog ? " X1 Y1 Z1" : "";
    writeBlock(mFormat.format(291), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + v1 + v2);
  }

  // The comma in "MSG," is load-bearing: grblHAL matches strncasecmp(comment, "MSG,", 4) in
  // gc_normalize_block() and surfaces nothing without it (grblHAL/core gcode.c, read 2026-08-14).
  // FluidNC is indifferent -- strstr(comment, "MSG") then a fixed four-character skip,
  // gcode_comment_msg(), FluidNC/src/GCode.cpp -- and stock grbl 1.1 discards comments entirely. No
  // space after the comma: grblHAL trims one, FluidNC would keep it. CR-02.
  else if (fw == eFirmware.GRBL) {
      writeBlock(mFormat.format(0), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + "(MSG," + sanitizeMessageText(text, "();") + ")");
  }

  else
  {
    writeBlock(mFormat.format(0), (getProperty(properties.jobSeparateWordsWithSpace) ? "" : " ") + sanitizeMessageText(text, "();"));
  }
}

// The first tool is LOADED, not changed: nothing is running, no Z0 exists yet to invalidate, and the
// tool stands where the operator left it. So none of a mid-job change's arrive-and-resume work is owed
// here -- no retract, no spindle or coolant to stop, no re-probe -- which is why this is not
// toolChange() with a flag. What it reuses is the two macro helpers that function also calls. Called
// unconditionally, so the ordering rule lives in one place.
//
// Who loads it is "At a Tool Change"'s answer, not this function's. PV-13.
//
//   Refuse -- the M0. The post changes no tool on this mode and the operator does; it refuses a
//             multi-tool JOB, and a one-tool job posts on it. Also the shipped default.
//   Pause  -- the M0, byte-identical to Refuse, and deliberately so: the two modes differ at a CHANGE,
//             and the first tool is not one. The Manual Position excursion is the one step that could
//             arguably be added -- that field's own description scopes it to a change, and adding it
//             would send the tool across the bed on a path no first load has ever taken.
//   Macro  -- the hand-over, so the changer loads it and nobody is asked to.
function toolChangeFirstLoad() {
  if (getProperty(properties.toolChangeFirstToolCorrect)) {
    return;
  }

  // Nothing left to ask on a pre-jogged origin. These modes record the position the operator jogged to
  // before the file started, which they could only do with a tool already fitted -- so declaring that
  // tool incorrect contradicts the mode, and fitting a different one is the very defect the load exists
  // to prevent, the recorded Z0 measuring from the tip that made the jog. On the macro arm it would
  // destroy the origin outright: this runs BEFORE writeWcsOnStart(), so the hand-over would move the
  // tool off the position about to be recorded. Ungated on the frame -- the contradiction is the
  // mode's, and holds with no frame at all. Warned rather than refused: the setting is inert here
  // rather than dangerous, and the remedy is the two modes that load and THEN position. PV-13.
  if (originIsPreJogged()) {
    writeComment(eComment.Debug, " toolChangeFirstLoad: suppressed -- \"First WCS / Part\" records a pre-jogged origin");
    // TWIN: paired -- validateJob()'s "First Tool is Correct is Off, but First WCS / Part is a
    // Set ... to Current Pos mode", on the same originIsPreJogged() this arm reads.
    writeWarning("\"First Tool is Correct\" is Off and nothing was emitted to load one -- \"First WCS /"
      + " Part\" takes this part's origin from where you jogged the tool before starting this file, so"
      + " the tool that made that jog is the one this job assumes and measures from. Fitting a different"
      + " one here would put every depth out by the difference in tool length, and on a hand-over it"
      + " would move the tool off the position about to be recorded. To load the tool during the run"
      + " instead, use \"Jog to X0 Y0, Probe Z0\" or \"Jog to X0 Y0 Z0\", which load first and position"
      + " afterwards.");
    return;
  }

  // Nothing a changer can act on: a hand-over is a tool NUMBER handed to a handler, and "T0 M6" names
  // no tool in any of them -- a laser is not in a changer at all. The M0 arms are unaffected, asking a
  // person to fit a laser being sensible, so this is the macro arm's condition alone. Both channels,
  // the operator being able to act on it before posting. PV-13.
  if (toolChangeIsMacro() && (tool.number == 0 || tool.isJetTool())) {
    writeComment(eComment.Debug, " toolChangeFirstLoad: suppressed -- tool 0 or a jet tool cannot be handed over");
    warnBothChannels("\"First Tool is Correct\" is Off and the first tool is a jet tool or tool 0, which"
      + " no tool changer can fit and no supported handler can act on -- \"T0 M6\" names no tool. Nothing"
      + " was emitted to load it, so this job assumes whatever is in the spindle now. Fit it before"
      + " starting the file, or set \"At a Tool Change\" to \"Manual change at a pause\" to be asked"
      + " during the run.");
    return;
  }

  if (toolChangeIsMacro()) {
    // The same hand-over every other change uses, and the resume with it -- both meaningful here
    // rather than mid-job leftovers. writeWCS() has already selected the offset, so the re-select is a
    // real block; Start() has set the modals, and re-asserting them is what the resume is for; and the
    // tool comes back to Machine Travel Z, where writeFixedZReference() left it and where
    // writeWcsOnStart() expects it. The include files are NOT loaded -- "Tool Change Start" says it
    // runs "where the cut ended, at cutting height", and at job start there is no cut.
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

// True where the FIRST tool is loaded by the hand-over rather than by a prompt or not at all. One
// definition, because three validateJob() guards read it and the emitter must not be able to disagree
// with them.
//
// It carries both suppressions above, so it answers the outcome and not the intent: a pre-jogged
// origin and a first tool a changer cannot fit each emit nothing, and a guard that fired on them would
// complain about a hand-over that never happens. getSection(0)'s tool is the same tool the emitter
// reads as `tool`, writeFirstSection() running inside the first section. PV-13.
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

// The handlers that are a GRBL sender, in one statement: three of the four values take "T<n> M6" over
// GRBL and remove the M6 before the controller sees it. The fourth is RepRapFirmware, where the T word
// IS the change, and "Other" is the operator's own file. Two places branch on this -- Flow 2's warning
// and the firmware guard -- and adding a value to one and not the other is how a hand-over comes to be
// warned about and never refused.
function toolChangeSenderIsGrblSender() {
  var id = getProperty(properties.toolChangeSender);
  return id == "gSender" || id == "CNCjs" || id == "UGS";
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

// Flow 1's optional excursion: take the tool somewhere the operator can reach it. Manual arm only, and
// only when toolChangeMovesToPosition() is true -- which is what validateJob() guards too, so the
// dialog and the file cannot disagree about whether this runs.
//
// Every block is G53, through the same writeMachineFrameBlock() as the retract and the end park. The
// deleted Tool Change X/Y/Z were bare G0 words, read in whichever WCS was active, so a change position
// measured against one part's origin was somewhere else entirely for the next. X/Y and Z are separate
// blocks because G53 is not modal and must be programmed on each line, and because a three-axis
// diagonal in the machine frame is not a move these firmwares guarantee to run as a straight line.
//
// X/Y before Z, always. The tool is at Machine Travel Z when this starts -- the height declared to
// clear every fixture -- so the crossing happens up there, and only then does the tool drop to a change
// height that may be below it.
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

  // The sync belongs after the LAST motion, not the retract's: writeMachineTravelZ() flushed before
  // these blocks, and the machine must stand still before anything prompts.
  flushMotions();
}

// Flow 1's return, and deliberately not a retrace. Two things are owed after a relocated change, and
// neither of them is the X/Y the tool left:
//
//   The HEIGHT, because the change height may be below the travel height and everything downstream --
//   the re-probe's traverse to the part origin, the next section's first rapid -- assumes the tool is
//   holding a height that clears the fixtures. Emitted only when a change Z was used; with that field
//   empty the tool never left Machine Travel Z and there is nothing to undo.
//
//   The ORDER of the next rapid, because the tool now stands over a point the work frame has no number
//   for. forceRapidXYBeforeZ makes that move cross before it descends. See rapidMovements().
//
// No X/Y return, and that is a decision rather than an omission. Nothing after a tool change is
// measured from where the tool stood before it: resetAll() has discarded the tracked position, so the
// next move carries full absolute coordinates, and the re-probe re-establishes Z0 from the part origin.
// It could not be done soundly in any case -- where a change coincides with a change of work offset,
// the two frames' true relationship is not known to the post, the stored origins being probed at
// runtime rather than reported by the model.
function writeToolChangeReturn() {
  if (toolChangePosZ() != undefined) {
    writeMachineTravelZ("Return to the travel height in the machine frame after the tool change");
  }

  // Only an X/Y excursion owes the ordering. A Z-only change position put the tool back over the very
  // point it left, at the height it left it, so the rapid that follows is ordered against exactly the
  // state it would have been ordered against with no change position set at all.
  if (toolChangePosX() != undefined) {
    writeComment(eComment.Info, "   The tool stands at the change position; the next rapid crosses at"
      + " this height before it descends");
    forceRapidXYBeforeZ = true;
  }
}

// The post changes no tool on either flow. A measured change needs a probe, a subtraction and a
// register to hold the result, and the post has none of the three: it cannot compute an offset it will
// not learn until the tool is swapped, hours after posting, and it can never read a register back. Its
// whole role is to arrive correctly, hand over, and resume correctly -- the three steps below.
// design.md -> Tool changes.
//
// Nothing is emitted that nothing will act on. No M84 Z -- Marlin-only, so GRBL halts on it mid-change
// with the operator holding a tool, and on Marlin a stepper release with no brake sinks an unbalanced
// gantry in Z. No M300 beep -- spindleOff() already beeps on the two firmwares that have M300, under
// exactly the manual-spindle setting that makes a beep worth anything. No M6 except where something
// has been NAMED that acts on it, toolChangeMacroCall(): on the manual flow no token is emitted at
// all, GRBL answering M6 with error:20 and Marlin reporting an unknown command and carrying on with
// the wrong cutter. And no post-injected onRapid() -- every machine-frame move goes through
// writeMachineTravelZ(), because routing it through onRapid() cleared forceSectionToStartWithRapid and
// defeated "First G1 --> G0" on precisely the sections that follow a change.
//
// partOriginEstablishesZ0 -- true where the part origin work that FOLLOWS this call sets Z0 itself,
// with the tool this change is about to fit. onSection() answers it through wcsOriginEstablishesZ0(),
// and it is true only at a boundary that is also a WCS change whose "Each New WCS / Part" mode
// establishes Z. Where it is true the re-probe below is dropped, being the same probe at the same place
// with the same tool; where it is false nothing else corrects Z0, and the re-probe is all that stands
// between the operator and a plunge measured from the tool just removed. PR-23.
function toolChange(partOriginEstablishesZ0) {
  writeComment(eComment.Important, " Tool Change Start");

  if (getProperty(properties.includeToolFile1) != "") {
    loadFile(getProperty(properties.includeToolFile1));
  }

  // --- 1. Arrive. Leave the machine in the state a hand-over is entitled to assume. ---------------

  // One frame, and the file names it: the hand-over height is the machine frame's own travel height,
  // the same G53 block every cross-part retract uses, and the optional excursion that may follow it is
  // G53 too. What this replaces -- Tool Change X/Y/Z -- were plain G0 words the dialog presented as
  // absolute while the machine read them in whichever WCS happened to be active, so the "fixed" change
  // spot drifted with every part. The frame was the defect, not the feature: a place to stand where the
  // operator can reach the collet is a real need, met here where a coordinate means the same thing on
  // every part of every job.
  //
  // The excursion is Flow 1's alone. A macro that wants the tool at a changer position moves it there
  // itself, in its own frame -- it knows where its changer or its sensor is and the post does not --
  // and toolChangeMacroResume() brings it back to the travel height afterwards. validateJob() warns
  // rather than silently ignoring the fields when they are set on that flow.
  //
  // Unconditional, even at a WCS-changing boundary where it means two identical G53 blocks in a row,
  // writeWCS() having just retracted to the same height. The post tracks no machine-frame position by
  // design, so "already there" would be a new belief to maintain across everything that can move the
  // tool -- "Tool Change Start" being an operator's include file, which can move it and which the post
  // does not read. A second rapid to a height the tool already holds is safe under every reading; a
  // stale belief that it is up there is not. PR-23.
  if (fixedZEstablishedInFile()) {
    writeMachineTravelZ("Retract to the travel height in the machine frame before the tool change");
    // After the retract and not instead of it: the excursion crosses the bed, so it may only start
    // from the height that clears the fixtures -- which is why the position fields require Machine
    // Travel Z rather than replacing it.
    if (toolChangeMovesToPosition()) {
      writeToolChangePosition();
    }
  } else {
    // TWIN: paired -- validateJob()'s no-frame tool-change warning, which covers BOTH flows and both
    // ends: this hand-over and the return below.
    writeWarning("no retract before this tool change -- this job establishes no fixed Z reference, so"
      + " the tool is handed over at whatever height the last operation ended at. Enter \"Machine"
      + " Travel Z\" in group 4, or retract by hand before touching the tool");
      // Only this arm still owes the sync: the retract above ends with its own flushMotions(), so
      // flushing here as well emitted M400 twice per change on Marlin and RRF.
    flushMotions();
  }

  // On every route, not only the arm that also relocates the tool: stopping is a property of the
  // hand-over, and gating it on the excursion left the other arm handing over with coolant running.
  onCommand(COMMAND_COOLANT_OFF);

  // Not onCommand(COMMAND_STOP_SPINDLE). That case guards on !tool.isJetTool(), and `tool` is already
  // the INCOMING tool here -- so a change from a router into a laser read the laser's guard and left
  // the router turning through the hand-over, with the operator's hands on the collet. spindleEnabled
  // answers for what is actually running rather than for what is about to be fitted, and spindleOff()
  // is the same routine that case would have reached.
  if (spindleEnabled) {
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
    // The manual arm's resume, and it exists only where the manual arm moved the tool. With the
    // position fields empty it is not called at all.
    if (toolChangeMovesToPosition()) {
      writeToolChangeReturn();
    }
  }

  // --- 3. Resume. Who owns the work Z0 the next operation cuts against. ---------------------------

  // The new tool is a different length, so the work Z0 this job established belongs to the OLD one --
  // unless something else has just corrected it. The re-probe is routed through partProbe(), the same
  // machinery every part origin uses, so it honours "Probe X/Y Offset" and "Probe Pause", writes a
  // provisional Z0 first (CR-12), and lands in the ACTIVE work offset -- which onSection() has now
  // selected BEFORE calling here. That ordering is the root fix: changing first wrote a fresh Z0 into
  // the previous section's register. It is also why, at a boundary that is both a change and a WCS
  // change, the correction below is not owed at all, being about to be made by the establish. PR-23.
  //
  // What a change strands is decided by the correction ANSWER and not by the fact of a change, so it is
  // hoisted above the arms below. CR-17 established the record; this is what it holds. PV-10.
  //
  //   Probe  -- the post re-probes the ACTIVE offset alone and there is no tool-length system to
  //             correct the rest, so every other part must be re-measured before it is cut.
  //
  //   Offset -- a tool-length offset shifts the Z FRAME, not a register. Every stored Z0 stays valid at
  //             the same instant, so nothing is stranded and nothing is cleared.
  //
  //   Manual -- the operator re-zeroes at the pause, which corrects the one register active there by a
  //             different hand from the probe's. Identical reach, so identical bookkeeping: strand
  //             every other offset and keep this one. PV-10.
  var correction = toolLengthCorrection();
  if (correction == "Probe") {
    wcsZ0Trusted = {};
  } else if (correction == "Manual") {
    // currentWorkOffset and not the section's: onSection() selects the WCS before calling here, the
    // ordering PR-23 established, so the register active at the pause is already this one.
    var zeroedByHand = currentWorkOffset;
    wcsZ0Trusted = {};
    wcsZ0Trusted[zeroedByHand] = true;
  }

  if (partOriginEstablishesZ0) {
    // Handed on, not dropped, and the file says so. writeWcsEstablish() runs as soon as this returns
    // and establishes this part's Z0 with the tool just fitted, so a probe here would measure the same
    // point with the same tool and be overwritten a block or two later. On a "Jog to ..." mode it would
    // be worse than waste: this part's X0 Y0 is not established until the operator jogs to it.
    // wcsZ0Trusted[currentWorkOffset] is deliberately NOT set here -- the establish sets it, being what
    // did the work.
    writeComment(eComment.Important, " Work Z0 for this part is established below, with the tool fitted"
      + " at this change -- anything measured during the change above is overwritten there");
  } else if (correction == "Probe") {
    if (tool.number != 0 && !tool.isJetTool()) {
      if (toolChangeIsMacro()) {
        // Stated, not warned. Probing after a macro is legitimate -- a sender that only pauses leaves
        // Z0 belonging to the old tool -- but so is turning it off, and the post cannot tell which
        // handler it is talking to. What it can do is say whose measurement the next cut trusts.
        writeComment(eComment.Important, " Work Z0 re-established by this post, AFTER the macro --"
          + " whatever the macro measured is overwritten below");
      }
      partProbe(false, true);
      wcsZ0Trusted[currentWorkOffset] = true;
    } else {
      // Suppressing the probe is right; silence is not -- the same rule writeWcsOnStart()'s tool-0 arm
      // follows. The Z0 in the register was established with the tool just removed, and the jet section
      // below emits absolute Z words against it.
      writeComment(eComment.Debug, " toolChange: re-probe skipped -- tool 0 or a jet tool cannot probe");
        // TWIN: here -- the CHANGE-side twin of writeWcsOnReturn()'s. Same sentence, one boundary
        // earlier: Z0 measures from a tool that is no longer fitted and this post cannot correct it.
        // W26.
      warnBothChannels("this change fits a jet tool / tool 0, which cannot probe, so work Z0 still measures"
        + " from the tool just removed -- set Z0 by hand at the pause above before the next operation"
        + " cuts or fires");
    }
  } else if (correction == "Offset") {
    // A different statement from the hand-zero arm, because a different thing is true: an offset
    // corrects the FRAME, which is the one correction that leaves every other part valid too and the
    // reason nothing was stranded above. The post cannot see whether one was applied, so it states the
    // condition the operator has to have satisfied rather than asserting a defect that may not exist.
    // TWIN: none -- this states the condition the OPERATOR asserted, on the flow where a party exists
    // to satisfy it, so a dialog line here would fire on a correctly configured job. The one sub-case
    // that IS a defect -- an offset asserted against a manual pause, which hands over to nothing --
    // has its own validateJob() pre-flight. PV-10.
    writeWarning("this post re-established nothing after the tool change above -- every depth below is"
      + " measured from the work Z0 already stored, and that is right only because a tool-length offset"
      + " was applied" + (toolChangeIsMacro() ? " by \"" + toolChangeSenderTitle() + "\"" : "")
      + ". An offset shifts the whole Z frame, so every part in this job stays measured correctly. If"
      + " nothing applied one, STOP: re-zero Z by hand and set \"Tool Length Correction By\" to match"
      + " what actually happens at your changes");
  } else {
    // "Manual", and the scope clause is the whole of PV-10: "re-zero at the pause" reaches the register
    // active at that pause and no other, so the operator who did exactly as told then cut the next part
    // deep by a tool length. What makes saying so honest rather than alarming is the clearing above --
    // every other part IS handled, at its own return.
    var strandedParts = collectDistinctOffsets().length - 1;
    // TWIN: paired -- PV-10's regime warning, which states in the dialog that a hand-zero at one pause
    // reaches one part. It fires on the multi-part case alone: on a single-part job this text is an
    // instruction the operator is about to carry out, not a condition they would have posted
    // differently had they known.
    writeWarning("work Z0 was NOT re-established after this tool change, so it still measures from the"
      + " PREVIOUS tool's length and every depth below is out by the difference between the two."
      + " Re-zero Z by hand at the pause above"
      + (strandedParts > 0
          ? ", which corrects THIS part and no other -- the remaining " + strandedParts + " part"
            + (strandedParts == 1 ? " is" : "s are") + " marked stale here, and re-measured, or"
            + " warned about, at the return to each"
          : ", or set \"Tool Length Correction By\" to \"GCode reprobes Z0 after change\" to have it"
            + " probed"));
  }

  if (getProperty(properties.includeToolFile2) != "") {
    loadFile(getProperty(properties.includeToolFile2));
  }

  // The rest of the resume is onSection()'s own: it restarts the spindle and the coolant after this
  // returns, and the section's first motion is a rapid.
  writeComment(eComment.Important, " Tool Change End");
}

// Flow 2's hand-over: emit the agreed token, ONCE, and nothing around it that the handler will redo.
// The post's setup is already done and its resume is toolChangeMacroResume()'s.
//
// The token is not the same question on every target, which is why the handler is a dropdown and not a
// firmware branch:
//
//   gSender / CNCjs / UGS -- "T<n> M6". Neither GRBL nor grblHAL executes M6; the controller answers
//   error:20 and the job stops with the tool in the cut. The route exists only because the SENDER
//   takes the M6 out of the stream first, in the dataFilter of its Grbl controller
//   (src/server/controllers/Grbl/GrblController.js -- gSender forked CNCjs's, and PR-20's M0 handling
//   is the same function). The T word travels with it and is what the sender's routine reads to know
//   which tool is coming; what reaches the controller is the T alone, which GRBL parses and does not
//   act on. The post cannot verify that the sender is configured to do any of this -- validateJob()
//   warns, and that warning is the whole of the post's assurance.
//
//   UGS does it in a different place and to the same effect, which is why it is listed rather than left
//   to "Other": ToolChangeInterceptor matches "(?i)(?<![A-Z])M0?6(?![0-9])" and its own javadoc states
//   the contract -- it "pauses the stream on tool change commands (M6), moves the machine to a safe
//   height and to a tool change location, waits for the operator to change the tool and optionally runs
//   a tool length probe before the stream is resumed", and "the M6 word is stripped from the triggering
//   command, but any tool selection (T2) is issued directly to the controller so the gcode state
//   reflects the requested tool". InterceptingGcodeStreamReader replaces the triggering command with a
//   blank line "so it is not executed by the controller, but is still streamed and counted as a row".
//   Both in ugs-core/src/com/willwinder/universalgcodesender/services/interceptor/,
//   winder/Universal-G-Code-Sender master, read 2026-08-17.
//
//   And it is off until the operator turns it on: ToolChangeInterceptor takes a BooleanSupplier and
//   its matches() answers false whenever that is false, so an un-enabled UGS streams the M6 straight
//   through to error:20. That is the same class of fact as gSender's "must be set to intercept", and
//   is why the shared Flow 2 warning covers all three without naming any of them.
//
//   RepRapFirmware -- "T<n>" and no M6. On RRF the T word IS the change: it runs tfree<current>.g,
//   tpre<n>.g and tpost<n>.g, and tpost is where a tool-length offset is applied. An M6 beside it would
//   be a second token for a change already made.
//
//   Other -- no token at all. The operator's file is the hand-over, included through loadFile() like
//   every other include, so it inherits the missing-file error, the trailing-newline fix and the modal
//   reset that follows a program the post did not write.
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
    // Tool number first: tool.comment is empty on most of Autodesk's own tools and the line then had no
    // subject at all -- ";   , declared with M563 in config.g". The comment is appended only where
    // there is one. PV-6.
    writeComment(eComment.Info, "   Tool #" + tool.number
      + (tool.comment ? " " + tool.comment : "") + ", declared with M563 in config.g");
    writeBlock(tFormat.format(tool.number));
    return;
  }

  writeComment(eComment.Important, " Hand over to " + sender + " -- it must intercept the M6 below;"
    + " GRBL itself answers error:20");
  writeComment(eComment.Info, "   Tool #" + tool.number + " " + tool.comment);
  writeBlock(tFormat.format(tool.number), mFormat.format(6));
}

// Flow 2's resume: restore the frame and the modal state the handler may have disturbed, and put the
// tool back at a known height before cutting resumes. Nothing here is conditional on which handler ran
// -- the post cannot read a macro it did not write, so it re-asserts what it needs rather than deciding
// what was probably safe, the same rule loadFile() follows for an include.
//
// A stale belief is a missing word, not a wrong one: the post re-asserts its modals lazily, so a G91 or
// a G20 left behind by the macro would be inherited silently by the next cut. The resets below force
// each one to be written again.
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

  // Re-selected unconditionally, which is why this does not go through writeWCS(): that function
  // returns without emitting when the offset is unchanged, and unchanged is exactly the case here --
  // the post's belief about the active register is what the macro may have invalidated. It re-selects
  // currentWorkOffset's own G5x and never a fixed G54, which would be the wrong register on any job
  // whose active offset is not the first. Marlin does not reach here at all: validateJob() refuses this
  // mode there.
  if (currentWorkOffset != undefined) {
    var reselect = wcsGcode(currentWorkOffset);
    if (reselect != undefined) {
      writeComment(eComment.Info, "   Re-select the active work offset -- the macro may have changed it");
      writeBlock(gFormat.format(reselect));
    }
  }

  // Back to a known height before anything else moves. The macro may have left the tool at a changer, a
  // tool-length sensor or its own park, and the post's tracked position is meaningless either way --
  // resetAll() above discarded it, so the next move emits full coordinates, but a full coordinate in Z
  // is only safe from a height the post chose. A job with no fixed reference gets a warning instead and
  // nothing to move to.
  if (fixedZEstablishedInFile()) {
    writeMachineTravelZ("Return to the travel height in the machine frame after the tool change");
  } else {
    // TWIN: paired -- the same no-frame tool-change warning as the hand-over above; it names the
    // return explicitly, this being the end it costs.
    writeWarning("the tool was NOT returned to a known height after the tool change -- this job"
      + " establishes no fixed Z reference, so wherever the macro left the tool is where the next move"
      + " starts from. Enter \"Machine Travel Z\" in group 4");
  }
}

// Probe Z and write it as the origin of the ACTIVE work offset. Load-bearing that the target is the
// active WCS and not an argument: on Marlin an origin write is "G92" against whichever workspace is
// selected, so a probe result can only ever land in the active one.
function probeTool() {
  var targetWcs = currentWorkOffset;
  // The G38.2 Z word, in output units and in the ACTIVE frame. Every caller writes a provisional Z0
  // first, which is what makes "G38 Target" a DISTANCE to search rather than a position measured from
  // a zero the mode was chosen because it distrusts. CR-11, CR-12.
  var searchZ = propertyMmToUnit(getProperty(properties.probeG38Target));
  var retractZ = probeSafeZ();
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
    // refer http://marlinfw.org/docs/gcode/G038.html
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

  // Restore the default so the next probe (e.g. the tool-change re-probe) prompts as usual
  // unless its caller sets otherwise.
  probePauseBefore = true;
  probePauseAfter = true;
}