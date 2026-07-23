import Foundation
import SwiftUI

final class MockHeartRateManager: ObservableObject {
    @Published var currentHeartRate: Int = 126 {
        didSet {
            currentHeartRate = min(max(currentHeartRate, 45), 210)
            recordHeartRateSample(currentHeartRate)
        }
    }
    @Published private(set) var averageHeartRate: Int = 126
    @Published private(set) var maximumHeartRate: Int = 126
    @Published private(set) var zoneTimes: [Int: Int] = [:]
    @Published var isDemoModeEnabled: Bool = true {
        didSet {
            if isDemoModeEnabled {
                startDemoMode()
            } else {
                stopDemoMode()
            }
        }
    }

    let zones: [HeartRateZone]
    private var sampleCount: Int = 0
    private var sampleTotal: Int = 0
    private var demoTimer: Timer?
    private var demoDirection: Int = 1

    init(zones: [HeartRateZone] = HeartRateZone.defaultZones) {
        self.zones = zones
        zones.forEach { zoneTimes[$0.id] = 0 }
        zoneTimes[HeartRateZone.belowZone.id] = 0
        recordHeartRateSample(currentHeartRate)
        startDemoMode()
    }

    var currentZone: HeartRateZone {
        zones.first { $0.contains(currentHeartRate) } ?? HeartRateZone.belowZone
    }

    var zoneTimeSummary: [(zone: HeartRateZone, seconds: Int)] {
        ([HeartRateZone.belowZone] + zones).map { zone in
            (zone: zone, seconds: zoneTimes[zone.id, default: 0])
        }
    }

    func increaseHeartRate() {
        isDemoModeEnabled = false
        currentHeartRate += 1
    }

    func decreaseHeartRate() {
        isDemoModeEnabled = false
        currentHeartRate -= 1
    }

    func resetMetrics() {
        sampleCount = 0
        sampleTotal = 0
        maximumHeartRate = currentHeartRate
        zoneTimes = [:]
        zones.forEach { zoneTimes[$0.id] = 0 }
        zoneTimes[HeartRateZone.belowZone.id] = 0
        recordHeartRateSample(currentHeartRate)
    }

    func tickZoneTimeIfWorkoutRunning() {
        zoneTimes[currentZone.id, default: 0] += 1
    }

    private func startDemoMode() {
        guard demoTimer == nil else {
            return
        }

        demoTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, self.isDemoModeEnabled else {
                return
            }

            if self.currentHeartRate >= 174 {
                self.demoDirection = -1
            } else if self.currentHeartRate <= 104 {
                self.demoDirection = 1
            }

            self.currentHeartRate += self.demoDirection * Int.random(in: 1...4)
        }
    }

    private func stopDemoMode() {
        demoTimer?.invalidate()
        demoTimer = nil
    }

    private func recordHeartRateSample(_ heartRate: Int) {
        sampleCount += 1
        sampleTotal += heartRate
        averageHeartRate = sampleTotal / max(sampleCount, 1)
        maximumHeartRate = max(maximumHeartRate, heartRate)
    }
}
