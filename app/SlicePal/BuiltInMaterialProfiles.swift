import Foundation

enum BuiltInMaterialProfiles {
    static let pla = MaterialProfile(
        name: "PLA",
        filamentDiameter: 1.75,
        firstLayerTemp: 215,
        otherLayersTemp: 210,
        firstLayerBedTemp: 60,
        otherLayersBedTemp: 55,
        extrusionMultiplier: 1.0,
        retractionEnabled: true,
        retractionLength: 5.0,
        retractionSpeed: 45.0,
        retractionRestartExtra: 0.0,
        zHop: 0.0,
        minTravelForRetraction: 1.0,
        coolingEnabled: true,
        minFanSpeed: 35,
        maxFanSpeed: 100,
        bridgeFanSpeed: 100,
        disableFanFirstLayers: 3,
        fanBelowLayerTime: 60,
        slowdownBelowLayerTime: 5,
        minPrintSpeed: 10.0
    )

    static let petg = MaterialProfile(
        name: "PETG",
        filamentDiameter: 1.75,
        firstLayerTemp: 235,
        otherLayersTemp: 230,
        firstLayerBedTemp: 80,
        otherLayersBedTemp: 75,
        extrusionMultiplier: 1.0,
        retractionEnabled: true,
        retractionLength: 6.0,
        retractionSpeed: 25.0,
        retractionRestartExtra: 0.2,
        zHop: 0.2,
        minTravelForRetraction: 1.5,
        coolingEnabled: true,
        minFanSpeed: 30,
        maxFanSpeed: 50,
        bridgeFanSpeed: 70,
        disableFanFirstLayers: 3,
        fanBelowLayerTime: 60,
        slowdownBelowLayerTime: 10,
        minPrintSpeed: 10.0
    )

    static let abs = MaterialProfile(
        name: "ABS",
        filamentDiameter: 1.75,
        firstLayerTemp: 250,
        otherLayersTemp: 245,
        firstLayerBedTemp: 105,
        otherLayersBedTemp: 100,
        extrusionMultiplier: 1.0,
        retractionEnabled: true,
        retractionLength: 4.0,
        retractionSpeed: 45.0,
        retractionRestartExtra: 0.0,
        zHop: 0.5,
        minTravelForRetraction: 1.0,
        coolingEnabled: false,
        minFanSpeed: 0,
        maxFanSpeed: 0,
        bridgeFanSpeed: 25,
        disableFanFirstLayers: 3,
        fanBelowLayerTime: 15,
        slowdownBelowLayerTime: 15,
        minPrintSpeed: 10.0
    )

    static let tpu = MaterialProfile(
        name: "TPU",
        filamentDiameter: 1.75,
        firstLayerTemp: 230,
        otherLayersTemp: 225,
        firstLayerBedTemp: 30,
        otherLayersBedTemp: 25,
        extrusionMultiplier: 1.0,
        retractionEnabled: false,
        retractionLength: 0.0,
        retractionSpeed: 25.0,
        retractionRestartExtra: 0.0,
        zHop: 0.0,
        minTravelForRetraction: 1.0,
        coolingEnabled: true,
        minFanSpeed: 50,
        maxFanSpeed: 100,
        bridgeFanSpeed: 100,
        disableFanFirstLayers: 2,
        fanBelowLayerTime: 60,
        slowdownBelowLayerTime: 5,
        minPrintSpeed: 5.0
    )

    static let all: [MaterialProfile] = [pla, petg, abs, tpu]
}
