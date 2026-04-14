import Foundation

enum BuiltInSliceProfiles {
    static let draft = SliceProfile(
        name: "Draft (0.3 mm)",
        layerHeight: 0.3,
        firstLayerHeight: 0.3,
        wallCount: 2,
        topLayers: 3,
        bottomLayers: 3,
        infillDensity: 15,
        infillPattern: .grid,
        printSpeed: 80,
        infillSpeed: 100,
        travelSpeed: 150,
        firstLayerSpeed: 30
    )

    static let standard = SliceProfile(
        name: "Standard (0.2 mm)",
        layerHeight: 0.2,
        firstLayerHeight: 0.2,
        wallCount: 3,
        topLayers: 4,
        bottomLayers: 4,
        infillDensity: 20,
        infillPattern: .gyroid,
        printSpeed: 60,
        infillSpeed: 80,
        travelSpeed: 120,
        firstLayerSpeed: 30
    )

    static let fine = SliceProfile(
        name: "Fine (0.1 mm)",
        layerHeight: 0.1,
        firstLayerHeight: 0.1,
        wallCount: 4,
        topLayers: 6,
        bottomLayers: 6,
        infillDensity: 20,
        infillPattern: .gyroid,
        printSpeed: 40,
        infillSpeed: 60,
        travelSpeed: 120,
        firstLayerSpeed: 20
    )

    static let all: [SliceProfile] = [draft, standard, fine]
}
