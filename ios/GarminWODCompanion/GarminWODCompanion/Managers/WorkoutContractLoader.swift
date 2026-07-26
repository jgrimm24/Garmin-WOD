import Foundation

enum LatestWorkoutError: Error, Equatable {
    case emptyData
    case invalidStatus(Int)
    case invalidResponse
    case transport(String)
}

protocol LatestWorkoutServing {
    func fetchLatestWorkout(completion: @escaping (Result<WorkoutContract, LatestWorkoutError>) -> Void)
}

protocol WorkoutCaching {
    func loadCachedWorkout() -> WorkoutContract?
    func saveCachedWorkout(_ workout: WorkoutContract) -> Bool
}

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

final class WorkoutAPIClient: LatestWorkoutServing {
    static let defaultEndpoint = URL(string: "https://garmin-wod.onrender.com/api/latest-workout")!

    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL = WorkoutAPIClient.defaultEndpoint, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchLatestWorkout(completion: @escaping (Result<WorkoutContract, LatestWorkoutError>) -> Void) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.transport(error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                let workout = try Self.decodeLatestWorkoutResponse(
                    data: data,
                    statusCode: httpResponse.statusCode
                )
                completion(.success(workout))
            } catch let latestWorkoutError as LatestWorkoutError {
                completion(.failure(latestWorkoutError))
            } catch {
                completion(.failure(.transport(error.localizedDescription)))
            }
        }

        task.resume()
    }

    static func decodeLatestWorkoutResponse(data: Data?, statusCode: Int) throws -> WorkoutContract {
        guard (200..<300).contains(statusCode) else {
            throw LatestWorkoutError.invalidStatus(statusCode)
        }

        guard let data, !data.isEmpty else {
            throw LatestWorkoutError.emptyData
        }

        do {
            return try JSONDecoder().decode(WorkoutContract.self, from: data)
        } catch {
            throw LatestWorkoutError.transport(error.localizedDescription)
        }
    }
}

final class WorkoutCache: WorkoutCaching {
    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.fileURL = baseURL
                .appendingPathComponent("GarminWODCompanion", isDirectory: true)
                .appendingPathComponent("latest-workout.json")
        }
    }

    func loadCachedWorkout() -> WorkoutContract? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WorkoutContract.self, from: data)
        } catch {
            print("[LATEST WOD] cache load failed: \(error)")
            return nil
        }
    }

    func saveCachedWorkout(_ workout: WorkoutContract) -> Bool {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(workout)
            try data.write(to: fileURL, options: [.atomic])
            return true
        } catch {
            print("[LATEST WOD] cache save failed: \(error)")
            return false
        }
    }
}
