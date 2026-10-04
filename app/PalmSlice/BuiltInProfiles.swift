import Foundation

// Printer templates seeded into a new install's ProfileStore, and merged
// into existing installs when new templates are added (see
// ProfileStore.mergeInMissingBuiltIns). `ender3S1` is the only profile
// verified on real hardware by this app; everything else was imported
// from PrusaSlicer's bundled vendor profile library and has not been
// print-tested here, so it's seeded into the "untested" list.
enum BuiltInProfiles {
    static let ender3S1: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Ender 3 S1"
        p.verified = true
        p.builtInKey = "ender3s1"

        // Bed / Machine
        p.bedX = 220
        p.bedY = 220
        p.bedZ = 270
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true
        p.heatedBuildVolume = false

        // G-Code
        p.gcodeFlavor = .marlin
        // Variables use PrusaSlicer placeholder syntax: {variable_name[extruder_index]}
        // NOT Cura syntax ({material_bed_temperature_layer_0} etc.)
        p.startGCode = """
; Ender 3 S1 Start G-code
; M413 S0 ; Disable power loss recovery
G92 E0 ; Reset Extruder

; Prep surfaces before auto home for better accuracy
M140 S{first_layer_bed_temperature[0]}
M104 S{first_layer_temperature[0]}

G28 ; Home all axes
G1 Z10.0 F3000 ; Move Z Axis up little to prevent scratching of Heat Bed
G1 X0 Y0

M190 S{first_layer_bed_temperature[0]}
M109 S{first_layer_temperature[0]}

G1 X0.1 Y20 Z0.3 F5000.0 ; Move to start position
G1 X0.1 Y200.0 Z0.3 F1500.0 E15 ; Draw the first line
G1 X0.4 Y200.0 Z0.3 F5000.0 ; Move to side a little
G1 X0.4 Y20 Z0.3 F1500.0 E30 ; Draw the second line
G92 E0 ; Reset Extruder
G1 Z2.0 F3000 ; Move Z Axis up little to prevent scratching of Heat Bed
G1 X5 Y20 Z0.3 F5000.0 ; Move over to prevent blob squish
"""
        // {machine_depth} is Cura-only — PrusaSlicer has no equivalent in end gcode.
        // Hardcode the Ender 3 S1 Y bed size (220 mm) for the present-print move.
        p.endGCode = """
G91 ;Relative positioning
G1 E-2 F2700 ;Retract a bit
G1 E-2 Z0.2 F2400 ;Retract and raise Z
G1 X5 Y5 F3000 ;Wipe out
G1 Z10 ;Raise Z more
G90 ;Absolute positioning

G1 X0 Y220 ;Present print
M106 S0 ;Turn-off fan
M104 S0 ;Turn-off hotend
M140 S0 ;Turn-off bed

M84 X Y E ;Disable all steppers but Z
"""

        // Printhead
        p.printheadXMin = -26
        p.printheadYMin = -32
        p.printheadXMax = 32
        p.printheadYMax = 34
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true
        p.startGCodeMustBeFirst = false

        // Extruder 0
        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        ext.offsetX = 0
        ext.offsetY = 0
        ext.coolingFanNumber = 0
        ext.extruderChangeDuration = 0
        ext.startGCode = ""
        ext.endGCode = ""
        p.extruders = [ext]

        return p
    }()

    // MARK: - Untested / imported from PrusaSlicer's vendor profile library

    static let prusaMK3S: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Prusa i3 MK3S+"
        p.verified = false
        p.builtInKey = "prusa-mk3s"

        p.bedX = 250
        p.bedY = 210
        p.bedZ = 210
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
M862.3 P "MK3S" ; printer model check
M862.1 P[nozzle_diameter] ; nozzle diameter check
M115 U3.14.1 ; tell printer latest fw version
G90 ; use absolute coordinates
M83 ; extruder relative mode
M104 S[first_layer_temperature] ; set extruder temp
M140 S[first_layer_bed_temperature] ; set bed temp
M190 S[first_layer_bed_temperature] ; wait for bed temp
M109 S[first_layer_temperature] ; wait for extruder temp
G28 W ; home all without mesh bed level
G80 X{first_layer_print_min[0]} Y{first_layer_print_min[1]} W{(first_layer_print_max[0]) - (first_layer_print_min[0])} H{(first_layer_print_max[1]) - (first_layer_print_min[1])} ; mesh bed levelling
{if filament_settings_id[initial_tool]=~/.*Prusament PA11.*/}
G1 Z0.3 F720
G1 Y-3 F1000 ; go outside print area
G92 E0
G1 X60 E9 F1000 ; intro line
G1 X100 E9 F1000 ; intro line
{else}
G1 Z0.2 F720
G1 Y-3 F1000 ; go outside print area
G92 E0
G1 X60 E9 F1000 ; intro line
G1 X100 E12.5 F1000 ; intro line
{endif}
G92 E0
M221 S{if layer_height<0.075}100{else}95{endif}
"""
        p.endGCode = """
{if layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+1, max_print_height)} F720 ; Move print head up{endif}
G1 X0 Y200 F3600 ; park
{if layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+49, max_print_height)} F720 ; Move print head further up{endif}
G4 ; wait
M221 S100 ; reset flow
M900 K0 ; reset LA
{if print_settings_id=~/.*(DETAIL @MK3|QUALITY @MK3|@0.25 nozzle MK3).*/}M907 E538 ; reset extruder motor current{endif}
M104 S0 ; turn off temperature
M140 S0 ; turn off heatbed
M107 ; turn off fan
M84 ; disable motors
"""

        p.printheadXMin = -45
        p.printheadYMin = -45
        p.printheadXMax = 45
        p.printheadYMax = 45
        p.gantryHeight = 20
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let prusaMINI: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Prusa MINI+"
        p.verified = false
        p.builtInKey = "prusa-mini"

        p.bedX = 180
        p.bedY = 180
        p.bedZ = 180
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin2
        p.startGCode = """
M862.3 P "MINI" ; printer model check
G90 ; use absolute coordinates
M83 ; extruder relative mode
M104 S170 ; set extruder temp for bed leveling
M140 S[first_layer_bed_temperature] ; set bed temp
M109 R170 ; wait for bed leveling temp
M190 S[first_layer_bed_temperature] ; wait for bed temp
M204 T1250 ; set travel acceleration
G28 ; home all without mesh bed level
G29 ; mesh bed leveling
M204 T[machine_max_acceleration_travel] ; restore travel acceleration
M104 S[first_layer_temperature] ; set extruder temp
G92 E0
G1 Y-2 X179 F2400
G1 Z3 F720
M109 S[first_layer_temperature] ; wait for extruder temp

; intro line
G1 X170 F1000
G1 Z0.2 F720
G1 X110 E8 F900
G1 X40 E10 F700
G92 E0

M221 S95 ; set flow
"""
        p.endGCode = """
G1 E-1 F2100 ; retract
{if layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+2, max_print_height)} F720 ; Move print head up{endif}
G1 X178 Y178 F4200 ; park print head
{if layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+30, max_print_height)} F720 ; Move print head further up{endif}
G4 ; wait
M104 S0 ; turn off temperature
M140 S0 ; turn off heatbed
M107 ; turn off fan
M221 S100 ; reset flow
M900 K0 ; reset LA
M84 ; disable motors
"""

        p.printheadXMin = -35
        p.printheadYMin = -35
        p.printheadXMax = 35
        p.printheadYMax = 35
        p.gantryHeight = 20
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let crealityEnder3V2: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Creality Ender-3 V2"
        p.verified = false
        p.builtInKey = "creality-ender3v2"

        p.bedX = 210
        p.bedY = 220
        p.bedZ = 250
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = Self.crealityStartGCode
        p.endGCode = Self.crealityEndGCode

        p.printheadXMin = -55
        p.printheadYMin = -55
        p.printheadXMax = 55
        p.printheadYMax = 55
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let crealityCR10: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Creality CR-10"
        p.verified = false
        p.builtInKey = "creality-cr10"

        p.bedX = 300
        p.bedY = 300
        p.bedZ = 400
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = Self.crealityStartGCode
        p.endGCode = Self.crealityEndGCode

        p.printheadXMin = -55
        p.printheadYMin = -55
        p.printheadXMax = 55
        p.printheadYMax = 55
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    // Shared by Ender-3 V2 and CR-10 — neither overrides the vendor's common start/end gcode.
    private static let crealityStartGCode = """
G90 ; use absolute coordinates
M83 ; extruder relative mode
M104 S{is_nil(idle_temperature[0]) ? 150 : idle_temperature[0]} ; set temporary nozzle temp to prevent oozing during homing
M140 S{first_layer_bed_temperature[0]} ; set final bed temp
G4 S30 ; allow partial nozzle warmup
G28 ; home all axis
G1 Z50 F240
G1 X2.0 Y10 F3000
M104 S{first_layer_temperature[0]} ; set final nozzle temp
M190 S{first_layer_bed_temperature[0]} ; wait for bed temp to stabilize
M109 S{first_layer_temperature[0]} ; wait for nozzle temp to stabilize
G1 Z0.28 F240
G92 E0
G1 X2.0 Y140 E10 F1500 ; prime the nozzle
G1 X2.3 Y140 F5000
G92 E0
G1 X2.3 Y10 E10 F1200 ; prime the nozzle
G92 E0
"""
    private static let crealityEndGCode = """
{if max_layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+2, max_print_height)} F600 ; Move print head up{endif}
G1 X5 Y{print_bed_max[1]*0.85} F{travel_speed*60} ; present print
{if max_layer_z < max_print_height-10}G1 Z{z_offset+min(max_layer_z+70, max_print_height-10)} F600 ; Move print head further up{endif}
{if max_layer_z < max_print_height*0.6}G1 Z{max_print_height*0.6} F600 ; Move print head further up{endif}
M140 S0 ; turn off heatbed
M104 S0 ; turn off temperature
M107 ; turn off fan
M84 X Y E ; disable motors
"""

    static let anycubicI3Mega: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Anycubic i3 Mega"
        p.verified = false
        p.builtInKey = "anycubic-i3mega"

        p.bedX = 210
        p.bedY = 210
        p.bedZ = 205
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
G90 ; use absolute coordinates
M83 ; extruder relative mode
M204 S[machine_max_acceleration_extruding] T[machine_max_acceleration_retracting]
M104 S[first_layer_temperature] ; set extruder temp
M140 S[first_layer_bed_temperature] ; set bed temp
G28 ; home all
G1 Y1.0 Z0.3 F1000 ; move print head up
M190 S[first_layer_bed_temperature] ; wait for bed temp
M109 S[first_layer_temperature] ; wait for extruder temp
G92 E0.0
; initial load
G1 X205.0 E19 F1000
G1 Y1.6
G1 X5.0 E19 F1000
G92 E0.0
; intro line
G1 Y2.0 Z0.2 F1000
G1 X65.0 E9.0 F1000
G1 X105.0 E12.5 F1000
G92 E0.0
"""
        p.endGCode = """
G1 E-1.0 F2100 ; retract
G92 E0.0
G1{if max_layer_z < max_print_height} Z{z_offset+min(max_layer_z+30, max_print_height)}{endif} E-34.0 F720 ; move print head up & retract filament
G4 ; wait
M104 S0 ; turn off temperature
M140 S0 ; turn off heatbed
M107 ; turn off fan
G1 X0 Y105 F3000 ; park print head
M84 ; disable motors
"""

        p.printheadXMin = -60
        p.printheadYMin = -60
        p.printheadXMax = 60
        p.printheadYMax = 60
        p.gantryHeight = 35
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let artillerySidewinderX1: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Artillery Sidewinder X1"
        p.verified = false
        p.builtInKey = "artillery-sidewinder-x1"

        p.bedX = 300
        p.bedY = 300
        p.bedZ = 400
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
; Initial setups
G90 ; use absolute coordinates
M83 ; extruder relative mode
M220 S100 ; reset speed factor to 100%
M221 S100 ; reset extrusion rate to 100%

; Set the heating
M190 S[first_layer_bed_temperature] ; wait for bed to heat up
M104 S[first_layer_temperature] ; start nozzle heating but don't wait

; Home
G1 Z3 F3000 ; move z up little to prevent scratching of surface
G28 ; home all axes
G1 X3 Y3 F5000 ; move to corner of the bed to avoid ooze over centre

; Wait for final heating
M109 S[first_layer_temperature] ; wait for the nozzle to heat up
M190 S[first_layer_bed_temperature] ; wait for the bed to heat up

; Return to prime position, Prime line routine
G92 E0 ; Reset Extruder
G1 Z3 F3000 ; move z up little to prevent scratching of surface
G1 X10 Y.5 Z0.25 F5000.0 ; Move to start position
G1 X100 Y.5 Z0.25 F1500.0 E15 ; Draw the first line
G1 X100 Y.2 Z0.25 F5000.0 ; Move to side a little
G1 X10 Y.2 Z0.25 F1500.0 E30 ; Draw the second line
G92 E0 ; Reset Extruder
M221 S{if layer_height<0.075}100{else}95{endif}
"""
        p.endGCode = """
G4 ; wait
G92 E0 ; prepare to retract
G1 E-0.5 F3000; retract to avoid stringing

; Anti-stringing end wiggle
G91 ; use relative coordinates
G1 X1 Y1 F1200

; Raise nozzle and present bed
{if layer_z < max_print_height}G1 Z{z_offset+min(layer_z+120, max_print_height)}{endif} ; Move print head up
G90 ; use absolute coordinates

; Reset print setting overrides
M200 D0 ; disable volumetric e
M220 S100 ; reset speed factor to 100%
M221 S100 ; reset extrusion rate to 100%

; Shut down printer
M106 S0 ; turn-off fan
M104 S0 ; turn-off hotend
M140 S0 ; turn-off bed
M150 P0 ; turn off led
M85 S0 ; deactivate idle timeout
M84 ; disable motors
"""

        p.printheadXMin = -45
        p.printheadYMin = -45
        p.printheadXMax = 45
        p.printheadYMax = 45
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let crealityEnder3: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Creality Ender-3"
        p.verified = false
        p.builtInKey = "creality-ender3"

        p.bedX = 228
        p.bedY = 228
        p.bedZ = 250
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
G90 ; use absolute coordinates
M83 ; extruder relative mode
M104 S{is_nil(idle_temperature[0]) ? 150 : idle_temperature[0]} ; set temporary nozzle temp to prevent oozing during homing
M140 S{first_layer_bed_temperature[0]} ; set final bed temp
G4 S30 ; allow partial nozzle warmup
G28 ; home all axis
G1 Z50 F240
G1 X2.0 Y10 F3000
M104 S{first_layer_temperature[0]} ; set final nozzle temp
M190 S{first_layer_bed_temperature[0]} ; wait for bed temp to stabilize
M109 S{first_layer_temperature[0]} ; wait for nozzle temp to stabilize
G1 Z0.28 F240
G92 E0
G1 X2.0 Y140 E10 F1500 ; prime the nozzle
G1 X2.3 Y140 F5000
G92 E0
G1 X2.3 Y10 E10 F1200 ; prime the nozzle
G92 E0
"""
        p.endGCode = """
{if max_layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+2, max_print_height)} F600 ; Move print head up{endif}
G1 X5 Y{print_bed_max[1]*0.85} F{travel_speed*60} ; present print
{if max_layer_z < max_print_height-10}G1 Z{z_offset+min(max_layer_z+70, max_print_height-10)} F600 ; Move print head further up{endif}
{if max_layer_z < max_print_height*0.6}G1 Z{max_print_height*0.6} F600 ; Move print head further up{endif}
M140 S0 ; turn off heatbed
M104 S0 ; turn off temperature
M107 ; turn off fan
M84 X Y E ; disable motors
"""

        p.printheadXMin = -55
        p.printheadYMin = -55
        p.printheadXMax = 55
        p.printheadYMax = 55
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let crealityEnder3S1Vendor: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Creality Ender-3 S1 (PrusaSlicer)"
        p.verified = false
        p.builtInKey = "creality-ender3s1-vendor"

        p.bedX = 215
        p.bedY = 220
        p.bedZ = 270
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
G90 ; use absolute coordinates
M83 ; extruder relative mode
M104 S{is_nil(idle_temperature[0]) ? 150 : idle_temperature[0]} ; set temporary nozzle temp to prevent oozing during homing
M140 S{first_layer_bed_temperature[0]} ; set final bed temp
G4 S30 ; allow partial nozzle warmup
G28 ; home all axis and restore leveling
G1 Z50 F240
G1 X2.0 Y10 F3000
M104 S{first_layer_temperature[0]} ; set final nozzle temp
M190 S{first_layer_bed_temperature[0]} ; wait for bed temp to stabilize
M109 S{first_layer_temperature[0]} ; wait for nozzle temp to stabilize
G1 Z0.28 F240
G92 E0
G1 X2.0 Y140 E10 F1500 ; prime the nozzle
G1 X2.3 Y140 F5000
G92 E0
G1 X2.3 Y10 E10 F1200 ; prime the nozzle
G92 E0
"""
        p.endGCode = """
{if max_layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+2, max_print_height)} F600 ; Move print head up{endif}
G1 X5 Y{print_bed_max[1]*0.85} F{travel_speed*60} ; present print
{if max_layer_z < max_print_height-10}G1 Z{z_offset+min(max_layer_z+70, max_print_height-10)} F600 ; Move print head further up{endif}
{if max_layer_z < max_print_height*0.6}G1 Z{max_print_height*0.6} F600 ; Move print head further up{endif}
M140 S0 ; turn off heatbed
M104 S0 ; turn off temperature
M107 ; turn off fan
M84 X Y E ; disable motors
"""

        p.printheadXMin = -55
        p.printheadYMin = -55
        p.printheadXMax = 55
        p.printheadYMax = 55
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let crealityEnder5: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Creality Ender-5"
        p.verified = false
        p.builtInKey = "creality-ender5"

        p.bedX = 215
        p.bedY = 220
        p.bedZ = 300
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
G90 ; use absolute coordinates
M83 ; extruder relative mode
M104 S{is_nil(idle_temperature[0]) ? 150 : idle_temperature[0]} ; set temporary nozzle temp to prevent oozing during homing
M140 S{first_layer_bed_temperature[0]} ; set final bed temp
G4 S30 ; allow partial nozzle warmup
G28 ; home all axis
G1 Z50 F240
G1 X2.0 Y10 F3000
M104 S{first_layer_temperature[0]} ; set final nozzle temp
M190 S{first_layer_bed_temperature[0]} ; wait for bed temp to stabilize
M109 S{first_layer_temperature[0]} ; wait for nozzle temp to stabilize
G1 Z0.28 F240
G92 E0
G1 X2.0 Y140 E10 F1500 ; prime the nozzle
G1 X2.3 Y140 F5000
G92 E0
G1 X2.3 Y10 E10 F1200 ; prime the nozzle
G92 E0
"""
        p.endGCode = """
{if max_layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+2, max_print_height)} F600{endif} ; Move print bed down
G1 X50 Y50 F{travel_speed*60} ; move print head out of the way
{if max_layer_z < max_print_height-10}G1 Z{z_offset+max_print_height-10} F600{endif} ; Move print bed close to the bottom
M140 S0 ; turn off heatbed
M104 S0 ; turn off temperature
M107 ; turn off fan
M84 X Y E ; disable motors
"""

        p.printheadXMin = -55
        p.printheadYMin = -55
        p.printheadXMax = 55
        p.printheadYMax = 55
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let prusaMk4: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Prusa MK4"
        p.verified = false
        p.builtInKey = "prusa-mk4"

        p.bedX = 250
        p.bedY = 210
        p.bedZ = 220
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin2
        p.startGCode = """
M17 ; enable steppers
M862.3 P "MK4" ; printer model check
M862.1 P[nozzle_diameter] A{(filament_abrasive[0] ? 1 : 0)} F{(nozzle_high_flow[0] ? 1 : 0)} ; nozzle check
M115 U6.2.6+8948
M555 X{(min(print_bed_max[0], first_layer_print_min[0] + 32) - 32)} Y{(max(0, first_layer_print_min[1]) - 4)} W{((min(print_bed_max[0], max(first_layer_print_min[0] + 32, first_layer_print_max[0])))) - ((min(print_bed_max[0], first_layer_print_min[0] + 32) - 32))} H{((first_layer_print_max[1])) - ((max(0, first_layer_print_min[1]) - 4))}

G90 ; use absolute coordinates
M83 ; extruder relative mode

M140 S[first_layer_bed_temperature] ; set bed temp
M104 T0 S{((filament_notes[0]=~/.*MBL160.*/) ? 160 : (filament_notes[0]=~/.*HT_MBL10.*/) ? (first_layer_temperature[0] - 10) : (filament_type[0] == "PC" or filament_type[0] == "PA") ? (first_layer_temperature[0] - 25) : (filament_type[0] == "FLEX") ? 210 : (filament_type[0]=~/.*PET.*/) ? 175 : 170)} ; set extruder temp for bed leveling
M109 T0 R{((filament_notes[0]=~/.*MBL160.*/) ? 160 : (filament_notes[0]=~/.*HT_MBL10.*/) ? (first_layer_temperature[0] - 10) : (filament_type[0] == "PC" or filament_type[0] == "PA") ? (first_layer_temperature[0] - 25) : (filament_type[0] == "FLEX") ? 210 : (filament_type[0]=~/.*PET.*/) ? 175 : 170)} ; wait for temp

M84 E ; turn off E motor

G28 ; home all without mesh bed level

G1 X42 Y-4 Z5 F4800

M302 S155 ; lower cold extrusion limit to 155C

{if filament_type[initial_tool]=="FLEX"}
G1 E-4 F2400 ; retraction
{else}
G1 E-2 F2400 ; retraction
{endif}

M84 E ; turn off E motor

G29 P9 X10 Y-4 W32 H4

{if first_layer_bed_temperature[initial_tool]<=60}M106 S100{endif}

G0 Z40 F10000

M190 S[first_layer_bed_temperature] ; wait for bed temp

M107

;
; MBL
;
M84 E ; turn off E motor
G29 P1 ; invalidate mbl & probe print area
G29 P1 X0 Y0 W50 H20 C ; probe near purge place
G29 P3.2 ; interpolate mbl probes
G29 P3.13 ; extrapolate mbl outside probe area
G29 A ; activate mbl

; prepare for purge
M104 S{first_layer_temperature[0]}
G0 X0 Y-4 Z15 F4800 ; move away and ready for the purge
M109 S{first_layer_temperature[0]}

G92 E0
M569 S0 E ; set spreadcycle mode for extruder

;
; Extrude purge line
;
G92 E0 ; reset extruder position
G1 E{(filament_type[0] == "FLEX" ? 4 : 2)} F2400 ; deretraction after the initial one before nozzle cleaning
G0 E7 X15 Z0.2 F500 ; purge
G0 X25 E4 F500 ; purge
G0 X35 E4 F650 ; purge
G0 X45 E4 F800 ; purge
G0 X48 Z0.05 F8000 ; wipe, move close to the bed
G0 X51 Z0.2 F8000 ; wipe, move quickly away from the bed

G92 E0
M221 S100 ; set flow to 100%
"""
        p.endGCode = """
{if layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+1, max_print_height)} F720 ; Move print head up{endif}
M104 S0 ; turn off temperature
M140 S0 ; turn off heatbed
M107 ; turn off fan
G1 X241 Y170 F3600 ; park
{if layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+23, max_print_height)} F300 ; Move print head up{endif}
G4 ; wait
M900 K0 ; reset LA
M142 S36 ; reset heatbreak target temp
M84 X Y E ; disable motors
; max_layer_z = [max_layer_z]
"""

        p.printheadXMin = -45
        p.printheadYMin = -45
        p.printheadXMax = 45
        p.printheadYMax = 45
        p.gantryHeight = 13
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let elegooNeptune3Pro: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Elegoo Neptune-3 Pro"
        p.verified = false
        p.builtInKey = "elegoo-neptune3pro"

        p.bedX = 225
        p.bedY = 225
        p.bedZ = 280
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
M413 S0 ; disable Power Loss Recovery
G90 ; use absolute coordinates
M83 ; extruder relative mode
M104 S120 ; set temporary nozzle temp to prevent oozing during homing and auto bed leveling
M140 S[first_layer_bed_temperature] ; set final bed temp
G4 S10 ; allow partial nozzle warmup
G28 ; home all axis
;G29 ; run abl mesh
M420 S1 ; load mesh
G1 Z50 F240
G1 X2 Y10 F3000
M104 S[first_layer_temperature] ; set final nozzle temp
M190 S[first_layer_bed_temperature] ; wait for bed temp to stabilize
M109 S[first_layer_temperature] ; wait for nozzle temp to stabilize
G1 Z0.28 F240
G92 E0
G1 Y140 E10 F1500 ; prime the nozzle
G1 X2.3 F5000
G92 E0
G1 Y10 E10 F1200 ; prime the nozzle
G92 E0
"""
        p.endGCode = """
{if max_layer_z < max_print_height}G1 Z{z_offset+min(max_layer_z+2, max_print_height)} F600 ; Move print head up{endif}
G1 X5 Y{print_bed_max[1]*0.8} F{travel_speed*60} ; present print
{if max_layer_z < max_print_height-10}G1 Z{z_offset+min(max_layer_z+70, max_print_height-10)} F600 ; Move print head further up{endif}
{if max_layer_z < max_print_height*0.6}G1 Z{max_print_height*0.6} F600 ; Move print head further up{endif}
M140 S0 ; turn off heatbed
M104 S0 ; turn off temperature
M107 ; turn off fan
M84 X Y E ; disable motors
"""

        p.printheadXMin = -45
        p.printheadYMin = -45
        p.printheadXMax = 45
        p.printheadYMax = 45
        p.gantryHeight = 25
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let sovolSv06: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Sovol SV06"
        p.verified = false
        p.builtInKey = "sovol-sv06"

        p.bedX = 220
        p.bedY = 220
        p.bedZ = 250
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
M104 S[first_layer_temperature] ; set extruder temp
M140 S[first_layer_bed_temperature] ; set bed temp
M190 S[first_layer_bed_temperature] ; wait for bed temp
M109 S[first_layer_temperature] ; wait for extruder temp
G28;
G1 Z4.0 F3000 ;Move Z Axis up
G92 E0 ;Reset Extruder
G1 X5.1 Y20 Z0.28 F5000.0 ;Move to start position
G1 X5.1 Y30.0 Z0.28 F1500.0 E1 ;Draw a short bit in case the extruder turns in the wrong direction
G1 X5.1 Y200.0 Z0.28 F1500.0 E15 ;Draw the first line
G1 X5.4 Y200.0 Z0.28 F5000.0 ;Move to side a little
G1 X5.4 Y20 Z0.28 F1500.0 E30 ;Draw the second line
G92 E0 ;Reset Extruder
G1 Z2.0 F3000 ;Move Z Axis up
"""
        p.endGCode = """
G91 ;Relative positioning
G1 X5 Y5 F3000 ;Wipe out
G1 Z10 ;Raise Z more
G90 ;Absolute positioning
G1 X10 Y220 ;Present print
M106 S0 ;Turn-off fan
M104 S0 ;Turn-off hotend
M140 S0 ;Turn-off bed
M84 X Y E ;Disable all steppers but Z
"""

        p.printheadXMin = -45
        p.printheadYMin = -45
        p.printheadXMax = 45
        p.printheadYMax = 45
        p.gantryHeight = 20
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let voronV2350: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Voron 2.4 (350)"
        p.verified = false
        p.builtInKey = "voron-v2-350"

        p.bedX = 350
        p.bedY = 350
        p.bedZ = 330
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .klipper
        p.startGCode = """
print_start EXTRUDER=[first_layer_temperature[initial_tool]] BED=[first_layer_bed_temperature]
"""
        p.endGCode = """
print_end    ;end script from macro
"""

        p.printheadXMin = -70
        p.printheadYMin = -70
        p.printheadXMax = 70
        p.printheadYMax = 70
        p.gantryHeight = 20
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let ultimakerS5S7: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Ultimaker S5/S7"
        p.verified = false
        p.builtInKey = "ultimaker-s5-s7"

        p.bedX = 330
        p.bedY = 240
        p.bedZ = 300
        p.buildPlateShape = .rectangular
        p.originAtCenter = false
        p.heatedBed = true

        p.gcodeFlavor = .marlin
        p.startGCode = """
; Delete the first 'generated by PrusaSlicer' line to make gcode printable on Ultimaker S-line

;START_OF_HEADER
; Printer_Settings_ID: [printer_settings_id]

;ULTIMAKER GRIFFIN HEADER
;HEADER_VERSION:0.1
;FLAVOR:Griffin
;GENERATOR.NAME:PrusaSlicer
;GENERATOR.VERSION:5.4.0
;GENERATOR.BUILD_DATE:{year}-{month}-{day}
;TARGET_MACHINE.NAME:Ultimaker S7
;EXTRUDER_TRAIN.0.INITIAL_TEMPERATURE:{first_layer_temperature[0]}
;EXTRUDER_TRAIN.0.MATERIAL.VOLUME_USED:{extruded_volume[0]}
;EXTRUDER_TRAIN.0.MATERIAL.GUID:0f12978a-8e3c-4147-b9ca-726d5ed59368
;EXTRUDER_TRAIN.0.NOZZLE.DIAMETER:{nozzle_diameter[0]}
;EXTRUDER_TRAIN.0.NOZZLE.NAME:AA {nozzle_diameter[0]}
;EXTRUDER_TRAIN.1.INITIAL_TEMPERATURE:{temperature[1] + standby_temperature_delta}
;EXTRUDER_TRAIN.1.MATERIAL.VOLUME_USED:{extruded_volume[1]}
;EXTRUDER_TRAIN.1.MATERIAL.GUID:0f12978a-8e3c-4147-b9ca-726d5ed59368
;EXTRUDER_TRAIN.1.NOZZLE.DIAMETER:{nozzle_diameter[0]}
;EXTRUDER_TRAIN.1.NOZZLE.NAME:AA {nozzle_diameter[0]}
;BUILD_PLATE.INITIAL_TEMPERATURE:[first_layer_bed_temperature]
;BUILD_VOLUME.TEMPERATURE:28
;PRINT.TIME:0
;PRINT.GROUPS:1
;PRINT.SIZE.MIN.X:{print_bed_min[0]}
;PRINT.SIZE.MIN.Y:{print_bed_min[1]}
;PRINT.SIZE.MIN.Z:0
;PRINT.SIZE.MAX.X:{print_bed_max[0]}
;PRINT.SIZE.MAX.Y:{print_bed_max[1]}
;PRINT.SIZE.MAX.Z:{max_print_height}
;SLICE_UUID:32daaf1d-f868-4a8e-ad06-8536b153e789
;END_OF_HEADER
T0
M82 ;absolute extrusion mode

G21 ; metric values
G90 ; absolute positioning
M107 ; start with the fan off

M140 S{first_layer_bed_temperature[initial_extruder]} ; start bed heating

G28 ; home if supported
G1 X1 Y6 F15000 ; move X/Y to start position
G1 Z35 F9000 ; move Z to start position

M104 S{temperature[initial_extruder] + standby_temperature_delta} ; heat nozzle

G280 S1 ; ultimaker home

;To skip adaptive bed mesh probing uncomment G0 commands before ;LAYER:1
;G0 X{print_bed_min[0]} Y{print_bed_max[1]}
;G0 X{print_bed_min[0]} Y{print_bed_min[1]}
;G0 X{print_bed_max[0]} Y{print_bed_min[1]}
;G0 X{print_bed_max[0]} Y{print_bed_max[1]}
;LAYER:1

; purge retract_length_toolchange due to unknown state
; prime extruders next to each other to verify extruder offset calibration

; prime T0
M104 S{first_layer_temperature[0]} T0 ; start heat nozzle temperature
T0
M109 S{first_layer_temperature[0]} T0 ; wait for nozzle temperature
G90
M82
G0 X5 Y100 Z0.3 F7200
G92 E0
G1 X5 Y10 E1.9 F1000
G0 X5 Y1 Z0.3 F7200
G92 E0
G1 X{print_bed_max[0]-30} Y1 E5.553 F1000
G0 X{print_bed_max[0]-30} Y1.5 F7200
G92 E0
G1 X10 Y1.5 E5.458 F1000
G0 X10 Y1.9 F7200
M104 S{temperature[initial_extruder] + standby_temperature_delta} ; cool nozzle
M104 S{first_layer_temperature[1]} T1 ; start heat next nozzle temperature
G92 E0
G1 X{print_bed_max[0]-28} Y1.9 E5.489 F1000
G92 E0
G1 E-3.5 F1200
G0 X{print_bed_max[0]-20} Y3 F18000
G0 X{print_bed_max[0]-15} Y10 Z3 F2400

G0 X30 Y10 Z0.3 F7200
G92 E0
G1 E3.5 F1200
G92 E0
G0 Y110 E1.85 F1000
G92 E0
G1 E-{retract_length_toolchange[0]} F1200
G0 Y150 F18000
G0 Y{print_bed_max[1]} Z5 F18000

; prime T1
T1
M109 S{first_layer_temperature[1]} T1 ; wait for nozzle temperature
G90
M82
G0 X5 Y100 Z0.3 F7200
G0 Y10 E1.9 F1000
G0 Y2.5 F7200
G92 E0
G1 X{print_bed_max[0]-30} Y2.5 E5.553 F1000
G0 X{print_bed_max[0]-30} Y2.9 F7200
G92 E0
G1 X10 Y2.9 E5.458 F1000
G0 X10 Y3.3 F7200
M104 S{temperature[1] + standby_temperature_delta} ; cool nozzle
M104 S{first_layer_temperature[initial_extruder]} ; start heating initial nozzle
G92 E0
G1 X{print_bed_max[0]-28} Y3.3 E5.489 F1000
G92 E0
G1 E-3.5 F1200 ;retract just a little because we don't have a way to tell the slicer T1 filament position when it starts printing from E0
G0 X{print_bed_max[0]-20} Y5 F18000
G0 X{print_bed_max[0]-15} Y15 Z3 F2400

;minus extruder1 offset X 22 which macro is not supported in start gcode
G0 X{30+nozzle_diameter[1]-22} Y15 Z0.3 F7200
G92 E0
G1 E3.5 F1200
G92 E0
G0 Y115 E1.85 F1000
G92 E0
G1 E-3.5 F1200
G0 Y150 F18000
G0 Y{print_bed_max[1]} Z5 F18000

; switch to initial nozzle
T{initial_extruder}
M109 S{first_layer_temperature[initial_extruder]} ; wait for nozzle temperature
G0 X{print_bed_max[0]-30} Y5 Z10 F7200
G0 X25 Y10 Z5
G0 X25 Y20 Z0.3
M82 ;absolute extrusion mode
G92 E0
G1 Y30 E{retract_length_toolchange[initial_extruder]} F1200 ;prime to set filament location for prusaslicer generated initial retract
G92 E0

;END Start-gcode
"""
        p.endGCode = """
;End-gcode
M104 S0
M104 S0 T0
M104 S0 T1
G0 X5 Y5 Z{max_print_height} F2000
M140 S0
M106 S0
M84 ; disable motors

"""

        p.printheadXMin = -60
        p.printheadYMin = -60
        p.printheadXMax = 60
        p.printheadYMax = 60
        p.gantryHeight = 50
        p.numberOfExtruders = 1
        p.applyExtruderOffsetsToGCode = true

        var ext = ExtruderProfile()
        ext.nozzleDiameter = 0.4
        ext.compatibleMaterialDiameters = [1.75]
        p.extruders = [ext]

        return p
    }()

    static let verified: [PrinterProfile] = [ender3S1]

    static let untested: [PrinterProfile] = [
        prusaMK3S,
        prusaMINI,
        crealityEnder3V2,
        crealityCR10,
        anycubicI3Mega,
        artillerySidewinderX1,
        crealityEnder3,
        crealityEnder3S1Vendor,
        crealityEnder5,
        prusaMk4,
        elegooNeptune3Pro,
        sovolSv06,
        voronV2350,
        ultimakerS5S7,
    ]

    static let all: [PrinterProfile] = verified + untested
}
