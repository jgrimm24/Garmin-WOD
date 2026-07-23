import SwiftUI

struct HeartRateZone: Identifiable, Equatable {
    let id: Int
    let name: String
    let minimum: Int
    let maximum: Int?
    let color: Color

    func contains(_ heartRate: Int) -> Bool {
        guard heartRate >= minimum else {
            return false
        }

        if let maximum {
            return heartRate <= maximum
        }

        return true
    }
}

extension HeartRateZone {
    static let defaultZones: [HeartRateZone] = [
        HeartRateZone(id: 1, name: "Zone 1", minimum: 95, maximum: 114, color: Color.blue),
        HeartRateZone(id: 2, name: "Zone 2", minimum: 115, maximum: 133, color: Color.green),
        HeartRateZone(id: 3, name: "Zone 3", minimum: 134, maximum: 151, color: Color.yellow),
        HeartRateZone(id: 4, name: "Zone 4", minimum: 152, maximum: 169, color: Color.orange),
        HeartRateZone(id: 5, name: "Zone 5", minimum: 170, maximum: nil, color: Color.red)
    ]

    static let belowZone = HeartRateZone(
        id: 0,
        name: "Below Zone",
        minimum: 0,
        maximum: 94,
        color: Color.gray
    )
}
