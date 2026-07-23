import Foundation

enum WorkoutContractLoader {
    static func loadBundledSample(named name: String = "roney-sample") -> WorkoutContract {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            return fallbackWorkout
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(WorkoutContract.self, from: data)
        } catch {
            print("Workout load failed: \(error)")
            return fallbackWorkout
        }
    }

    private static let fallbackWorkout = WorkoutContract(
        schemaVersion: 1,
        id: "fallback-roney",
        title: "Roney",
        type: .forTime,
        durationMinutes: nil,
        rounds: 4,
        stations: [
            WorkoutStation(id: "run-1", name: "Run", distanceMeters: 200),
            WorkoutStation(id: "thrusters", name: "Thrusters", reps: 11, weightLb: 135, maleWeightLb: 135, femaleWeightLb: 95),
            WorkoutStation(id: "run-2", name: "Run", distanceMeters: 200),
            WorkoutStation(id: "push-press", name: "Push Press", reps: 11, weightLb: 135, maleWeightLb: 135, femaleWeightLb: 95),
            WorkoutStation(id: "run-3", name: "Run", distanceMeters: 200),
            WorkoutStation(id: "bench-press", name: "Bench Presses", reps: 11, weightLb: 135, maleWeightLb: 135, femaleWeightLb: 95)
        ],
        notes: [],
        sourceText: "Roney\n4 rounds for time"
    )
}
