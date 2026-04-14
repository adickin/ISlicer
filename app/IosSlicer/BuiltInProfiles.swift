import Foundation

enum BuiltInProfiles {
    static let ender3S1: PrinterProfile = {
        var p = PrinterProfile()
        p.name = "Ender 3 S1"

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

    static let all: [PrinterProfile] = [ender3S1]
}
