
Fusion 360 CAM posts processor for MPCNC 
====

This is modified fork of https://github.com/guffy1234/mpcnc_posts_processor that was originally forked https://github.com/martindb/mpcnc_posts_processor.

CAM posts processor for use with Fusion 360 and [MPCNC](https://www.v1engineering.com).

Supported firmware:
- Marlin 2.0
- Repetier firmware 1.0.3 (not tested. gcode is same as for Marlin)
- GRBL 1.1
- RepRap firmware (Duet3d) 

Installation:
- The post processor consists of a single file, mpcnc.cps.
- It can be simply installed by selecting Manage->Post Library from the Fusion 360 menubar; alternatively the mpcnc.cps can be copied into a directory and selecting each time prior to a post operation. If there is an existing mpcnc.cps installed select it prior to installing and use the trash can icon to delete it
- The desired post processor can be selected during a post using the Setup button and selecting Use Personal Post Library
- Use the Job: CNC Firmware property to select between Marlin 2.x, Grbl 1.1 and RepRap firmware

Some design points:
- Setup operation types: Milling, Water/Laser/Plasma
- Support mm and Inches units (**but all properties MUST be set in MM**)
- Rapids movements use two G0 moves. The Z moves first and the XY. Moves are seperate to allow retraction from the work surface prior to horizontal travel. Moves use independent travel speeds for Z and XY.
- Arcs support on XY plane (Marlin/Repetier/RepRap) or all panes (Grbl)
- Tested with LCD display and SD card (built in tool change require printing from SD and LCD to restart)
- Support for 3 different laser power using "cutting modes" (through, etch, vaporize)
- Support 2 coolant channels. You may attach relays to control external devices - as example air jet valve.
- Customizable level of verbosity of comments
- Support line numbers
- Support GRBL laser mode (**note: you probably have to enabled laser mode [$32=1](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Laser-Mode)**)

   ![screenshot](/screenshot.jpg "screenshot")

# Properties

> WARNING: If you are using the Fusion 360 for Personal Use license, formally know as the Fusion 360 Hobbyist license, please respect the [limitations of that license](https://knowledge.autodesk.com/support/fusion-360/learn-explore/caas/sfdcarticles/sfdcarticles/Fusion-360-Free-License-Changes.html). To remain compliant with that license set your [Feed: Travel Speed X/Y] and [Feed: Travel Speed Z] no faster then your machine's maximum cut feedrate (see Group 2 Properties).
>
>Fusion 360 for Personal Use restricts all moves not to exceed the maximum cut speed. This has been implemented not by reducing the speed of G0s but by changing all G0 (moves) to G1 (cut) commands. The side effect of this was to unintentionally introduce situations where tool dragging and/or work piece collisions occur, general at the start of jobs or after tool changes.
>
>You can choose to resolve these issues by enabling the selective mapping of G1s->G0s (see Group 3 Properties). Theses issues are resolved as the post processor implements G0 moves by doing first a move in Z and then a move in X,Y while a G1 cuts travel in X,Y,Z at the same time.

## Group 1: Job Properties
Use these properties to control overall aspects of the job.

|Title|Description|Default|
|---|---|---|
Job: CNC Firmware|Dialect of GCode to create|**Marlin 2.x**|
Job: Job: Zero Starting Location (G92)|On start set the current location as 0,0,0 (G92).|**true**|
Job: Manual Spindle On/Off|Enable to manually turn spindle motor on/off. Post processor will issue additional pauses for TURN ON/TURN OFF the motor.|**true**|
Job: Comment Level|Controls a increasing level of comments to be included: Off, Important, Info, Debug|**Info**|
Job: Use Arcs|Use G2/G3 g-codes for circular movements.|**true**|
Job: Enable Line #s|Show sequence numbers.|**false**|
Job: First Line #|First sequence number.|**1**|
Job: Line # Increment|Sequence number increment.|**10**|
Job: Include Whitespace|Includes whitespace seperation between text.|**true**|
Job: At end go to 0,0|Go to X0 Y0 at gcode end, Z remains unchanged.|**true**|

## Group 2: Travel Speed and Feedrate Scaling Properties
Use these properties to set the speed used for G0 Rapids and to scale the feedrate used
for G1 cuts.

[Feed: Travel Speed X/Y] and [Feed: Travel Speed Z] are always used for G0 Rapids.

Scaling of the G1 cut feedrates will only occur if [Feed:Scaled Feedrate] is true.

Scaling ensures that no G1 cut exceeds the speed capablities of the X, Y, or Z axes.
The cut's toolpath feedrate is projected onto the X, Y and Z axes. In turn each axis is tested
to see if its cut speed is within the limits of that axis. If not, then all axes feedrates are
scaled proportionatly to bring it within limits. This is repeated for all axes. The three axis
feedrates are then merged to create a new toolpath feedrate which is then limited to ensure it
doesn't exceed [Feed: Max Toolpath Speed].

Note: Because scaling considered 3 dimensional movement a resulting toolpath's feedrate may be
greater then one or all of the X, Y or Z limits. For example, a small movement in Z compared to
a much larger movement in XY may result in a feedrate that appears to exceed the capability of
Z but in reality since Z is moving a much smaller distance for the same time period its actual
feedrate is within the established limits.

|Title|Description|Default|
|---|---|---|
Feed: Travel Speed X/Y|High speed for travel movements X & Y (mm/min).|**2500 mm/min**|
Feed: Travel Speed Z|High speed for travel movements Z (mm/min).|**300 mm/min**|
Feed: Enforce Feedrate|Forces the Fxxx to be include even if hasn't changed, useful for Marlin.|**true**|
Feed: Scaled Feedrate|Scale feedrate based on X, Y, Z axis maximums.|**false**|
Feed: Max Cut Speed X or Y|Maximum X or Y axis cut speed (mm/min).|**900 mm/min**|
Feed: Max Cut Speed Z|Maximum Z axis cut speed (mm/min).|**180 mm/min**|
Feed: Max Toolpath Speed|Maximum scaled feedrate for toolpath (mm/min).|**1000 mm/min**|

## Group 3: Map G1->G0 Properties

Allows G1 cuts to be converted to G0 Rapid movements in specific cases:

If [Map: First G1 -> G0 Rapid] is true the post processor resolves the lost
initial positioning movement at the beginning of a cut toolpath. This problem is often
identified in forums as the tool being initially dragged across the work surface. 

If [Map: G1s -> G0s] is true then allows G1 XY cut movements (i.e. no change in Z) that occur
at a height greater or equal to [Map: Safe Z to Rapid] to be converted to G0 Rapids.
Note: this assumes that any Z above [Map: Safe Z to Rapid] is a movement in the air and clear of
obstacles. Can be defined as a number or one of F360's planes (Feed, Retract or Clearance).

Map: Safe Z for Rapids may be defined as:
* As a constant numeric value - safe Z will then always be this value for all sections, or
* As a reference to a F360 Height - safe Z will then follow the Height defined within the operation's Height tab. Allowable Heights are: Feed, Retract, or Clearance. The Height must be followed by a ":" and then a numeric value. The value will be used if Height is not defined for a section.

If [Map: Allow Rapid Z] is true then G1 Z cut movements that either move straight up
and end above [Map: Safe Z to Rapid], or straight down with the start and end positions both
above [Map: Safe Z to Rapid] are included. Only occurs if [Map: G1s -> G0s] is also true.

|Title|Description|Default|Format|
|---|---|---|---|
Map: First G1 -> G0 Rapid|Converts the first G1 of a cut to G0 Rapid|**false**| |
Map: G1s -> G0s|Allow G1 cuts to be converted to Rapid G0 moves when safe and appropriate.|**false**| |
Map: Safe Z for Rapids|A G1 cut's Z must be >= to this to be mapped to a Rapid G0. Can be two formats (1) a number which will be used for all sections, or (2) a reference to F360's Height followed by a default if Height is not available.|**Retract:15** (use the Retract height and if not available 15)| \<number\> or \<F360 Height\>:\<number\>; e.g. 10 or Retract:7 or Feed:5|
Map: Allow Rapid Z|Include the mapping of vertical cuts if they are safe.|**false**|

## Group 4: Tool change Properties

|Title|Description|Default|
|---|---|---|
Tool Change: Enable|Include tool changes in NC file|**false**|
Tool Change: Insert Relocation Code|Include code to assist with manual tool change|**false**|
Tool Change: X|X position for built-in tool change|**0**|
Tool Change: Y|Y position for built-in tool change|**0**|
Tool Change: Z|Z position for built-in tool change|**40**|
Tool Change: Disable Z stepper|Disable Z stepper after reaching tool change location|**false**|
Tool Change: Do first change|First tool is not already loaded|**false**|

## Group 5: Z Probe Properties

|Title|Description|Default|
|---|---|---|
Probe: On job start|Execute probe gcode on job start|**false**|
Probe: After Tool Change|Z probe after tool change|**false**|
Probe: Plate thickness|Plate thickness|**0.8**|
Probe: Use Home Z (G28)|Probe with G28 (Yes) or G38 (No)|**true**|
Probe: G38 target|G38 Probing's furthest Z position|**-10**|
Probe: G38 speed|G38 Probing's speed|**30**|

## Group 6: Laser/Plasma Properties

Fusion 360 defines four levels of Through cut, currently these all map to power level "On - Through".

The firmware selected in the parameter [Job: CNC Firmware] determines if the Grbl or Marlin/Reprap laser parameters are used. 

Fusion 360 does not use a coolant when using its jet tools (waterjet/laser/plasma). When using a laser it may be desirable to use air or some other device you have connected to the coolant channels. The [Laser: Coolant] can be used to force a coolant to be used for the laser operations (see coolant parameter on details for configuring the coolant channels).

|Title|Description|Default|Values|
|---|---|---|---|
Laser: On - Vaporize|Persent of power to turn on the laser/plasma cutter in vaporize mode|**100**||
Laser: On - Through|Persent of power to turn on the laser/plasma cutter in through mode|**80**||
Laser: On - Etch|Persent of power to turn on the laser/plasma cutter in etch mode|**40**||
Laser: Marlin/Reprap Mode|Marlin/Reprap mode of the laser/plasma cutter|**Fan - M106 S{PWM}/M107**|"Fan - M106 S{PWM}/M107", "Spindle - M3 O{PWM}/M5", "Pin - M42 P{pin} S{PWM}"|
Laser: Marlin M42 Pin|Marlin custom pin number for the laser/plasma cutter|**4**||
Laser: GRBL Mode|GRBL mode of the laser/plasma cutter|**M4 S{PWM}/M5 dynamic power**|"M4 S{PWM}/M5 dynamic power", "M3 S{PWM}/M5 static power"|
Laser: Coolant|Force a coolant to be used|**Off**|off, flood, mist, throughTool, air, airThroughTool, suction, floodMist, floodThroughTool|

## Group 7: Override Behaviour by External File Properties

|Title|Description|Default|
|---|---|---|
Extern: Start File|File with custom Gcode for header/start (in nc folder)||
Extern: Stop File|File with custom Gcode for footer/end (in nc folder)||
Extern: Tool File1|File with custom Gcode to start tool change (in nc folder)||
Extern: Tool File2|File with custom Gcode to end tool change (in nc folder)||
Extern: Probe File|File with custom Gcode for tool probe (in nc folder)||

## Group 8: Coolant Control Pin Properties

Coolant has two channels, A and B. Each channel can be configured to be off or set to 1 of the 8 coolant modes that Fusion 360 allows on operation. If a tool's collant requirements match a channel's setting then that channel is enabled. A warning is generated if a tool askes for coolant and there is not a channel that matches. 

If a channel matches the coolant requested the Channel becomes enabled. When a channel is enabled the post processor will include the text associated with the corresponding property [Coolant \<A or B\> Enable]. Note, Marlin and Grbl values are included as options, you must select based on your actual configuration. The firmware selected in property [Job: CNC Firmware] will not override your selection.

If a channel needs to be Disabled because it no longer matchs the coolant requested then the channel is physically disabled by the post processor by including the text associated with the corresponding property [Coolant \<A or B\> Disable]. Note, Marlin and Grbl values are included as options, you must select based on your actual configuration. The firmware selected in the propery [Job: CNC Firmware] will not override your selection.

For coolant requests, like "Flood and Mist" or "Flood and Through Tool" you may want to enable one or
two channels dependent on if your hardware uses one connections to enable both or a seperate connection for each. Two channels may be enabled by placing the same coolant code in both. For example, setting both channels to "Flood and Mist" will result in enabling both channel A and channel B when the tool requests "Flood and Mist". Correspondingly channels A's enable value will be output (to enable flooding) and channel B's enable value will be output (to enable Mist).

Four custom coolant text strings can be defined for both Channel A and B's on and off values. Use these if the predefine values do not match your hardware. To enable, set the corresponding coolant channel to 'Use custom'.

|Title|Description|Default|Values|
|---|---|---|---|
Coolant: A Mode|Enable channel A when tool is set this coolant|**off**|off, flood, mist, throughTool, air, airThroughTool, suction, floodMist, floodThroughTool|
Coolant: B Mode|Enable channel B when tool is set this coolant|**off**|off, flood, mist, throughTool, air, airThroughTool, suction, floodMist, floodThroughTool|
Coolant: A Enable|GCode to turn On coolant channel A|**Mrln: M42 P6 S255**|"Mrln: M42 P6 S255", , Mrln: M42 P11 S255", "Grbl: M7 (mist)", "Grbl: M8 (flood)", "Use custom"|
Coolant: A Disable|GCode to turn Off coolant channel A|**Mrln: M42 P6 S0**|"Mrln: M42 P6 S0", "Mrln: M42 P11 S0", "Grbl: M9 (off)", "Use custom"|
Coolant: B Enable|GCode to turn On coolant channel B|**Mrln: M42 P11 S255**|"Mrln: M42 P11 S255", "Mrln: M42 P6 S255", "Grbl: M7 (mist)", "Grbl: M8 (flood)", "Use custom"|
Coolant: B Disable|GCode to turn Off coolant channel B|**Mrln: M42 P11 S0**|"Mrln: M42 P11 S0", "Mrln: M42 P6 S0", "Grbl: M9 (off)", "Use custom"|
Coolant: Custom A Enable|Custom GCode to turn On coolant channel A|empty| |
Coolant: Custom A Disable|Custom GCode to turn Off coolant channel A|empty| |
Coolant: Custom B Enable|Custom GCode to turn On coolant channel B|empty| |
Coolant: Custom B Disable|Custom GCode to turn Off coolant channel B|empty| |

## Group 9: Duet Properties

|Title|Description|Default|
|---|---|---|
Duet: Milling mode|GCode command to setup Duet3d milling mode|**M453 P2 I0 R30000 F200**|
Duet: Laser mode|GCode command to setup Duet3d laser mode|**M452 P2 I0 R255 F200**|

# Sample of issued code blocks

## Gcode of milling with manually control spindle

```G-code
To be updated
```

# Resources
## GCode
[Marlin G-codes](http://marlinfw.org/meta/gcode/)

[FluidNC Supported Gcodes](http://wiki.fluidnc.com/en/features/supported_gcodes)

[LinuxCNC Supported Gcodes](http://linuxcnc.org/docs/html/gcode/g-code.html)

## Fusion 360 PostProcessor Docs and Guides
[PostProcessor Class Reference](https://cam.autodesk.com/posts/reference/classPostProcessor.html)

[Post Processor Training Guide (PDF document)](https://cam.autodesk.com/posts/posts/guides/Post%20Processor%20Training%20Guide.pdf)

[Enhancements to the post processor property definitions](https://forums.autodesk.com/t5/hsm-post-processor-forum/enhancements-to-the-post-processor-property-definitions/td-p/7325350)

[Dumper PostProcessor](https://cam.autodesk.com/hsmposts?p=dump)

[Library of exist post processors](https://cam.autodesk.com/hsmposts)

[Post processors forum](https://forums.autodesk.com/t5/hsm-post-processor-forum/bd-p/218)

[How to set up a 4/5 axis machine configuration](https://forums.autodesk.com/t5/hsm-post-processor-forum/how-to-set-up-a-4-5-axis-machine-configuration/td-p/6488176)

[Beginners Guide to Editing Post Processors in Fusion 360! FF121 (Youtube video)](https://www.youtube.com/watch?v=5EodQIY25tU)
