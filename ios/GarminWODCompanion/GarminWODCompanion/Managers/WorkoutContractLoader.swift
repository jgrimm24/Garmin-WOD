import Foundation

enum LatestWorkoutError: Error, Equatable {
    case emptyData
    case invalidStatus(Int)
    case invalidResponse
    case transport(String)
}

enum WorkoutSessionFetchError: Error, Equatable {
    case emptyData
    case notFound
    case invalidStatus(Int)
    case invalidResponse
    case transport(String)
}

enum CompletedWorkoutHistoryError: Error, Equatable {
    case emptyData
    case notFound
    case invalidStatus(Int)
    case invalidResponse
    case transport(String)
}

protocol LatestWorkoutServing {
    func fetchLatestWorkout(completion: @escaping (Result<WorkoutContract, LatestWorkoutError>) -> Void)
}

protocol WorkoutSessionServing {
    func fetchWorkoutSession(completion: @escaping (Result<WorkoutSessionState, WorkoutSessionFetchError>) -> Void)
}

protocol CompletedWorkoutHistoryServing {
    func fetchCompletedWorkoutHistory(limit: Int, before: String?, completion: @escaping (Result<CompletedWorkoutHistoryPage, CompletedWorkoutHistoryError>) -> Void)
    func fetchCompletedWorkout(sessionId: String, completion: @escaping (Result<CompletedWorkoutSession, CompletedWorkoutHistoryError>) -> Void)
}

protocol CompletedWorkoutHistoryStoring {
    func loadSummaries() -> [CompletedWorkoutSummary]
    func saveSummaries(_ summaries: [CompletedWorkoutSummary])
    func loadSession(sessionId: String) -> CompletedWorkoutSession?
    func saveSession(_ session: CompletedWorkoutSession)
}

protocol WorkoutCaching {
    func loadCachedWorkout() -> WorkoutContract?
    func saveCachedWorkout(_ workout: WorkoutContract) -> Bool
}

struct CompletedWorkoutHistoryPage: Codable, Equatable {
    let items: [CompletedWorkoutSummary]
    let nextCursor: String?
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

final class WorkoutSessionAPIClient: WorkoutSessionServing {
    static let defaultEndpoint = URL(string: "https://garmin-wod.onrender.com/api/workout-session")!

    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL = WorkoutSessionAPIClient.defaultEndpoint, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchWorkoutSession(completion: @escaping (Result<WorkoutSessionState, WorkoutSessionFetchError>) -> Void) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
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
                let state = try Self.decodeWorkoutSessionResponse(
                    data: data,
                    statusCode: httpResponse.statusCode
                )
                completion(.success(state))
            } catch let sessionError as WorkoutSessionFetchError {
                completion(.failure(sessionError))
            } catch {
                completion(.failure(.transport(error.localizedDescription)))
            }
        }

        task.resume()
    }

    static func decodeWorkoutSessionResponse(data: Data?, statusCode: Int) throws -> WorkoutSessionState {
        if statusCode == 404 {
            throw WorkoutSessionFetchError.notFound
        }

        guard (200..<300).contains(statusCode) else {
            throw WorkoutSessionFetchError.invalidStatus(statusCode)
        }

        guard let data, !data.isEmpty else {
            throw WorkoutSessionFetchError.emptyData
        }

        do {
            let wrapper = try JSONDecoder().decode(WorkoutSessionResponse.self, from: data)
            return wrapper.session
        } catch {
            do {
                return try JSONDecoder().decode(WorkoutSessionState.self, from: data)
            } catch {
                throw WorkoutSessionFetchError.transport(error.localizedDescription)
            }
        }
    }
}

private struct WorkoutSessionResponse: Codable {
    let session: WorkoutSessionState
}

final class CompletedWorkoutHistoryAPIClient: CompletedWorkoutHistoryServing {
    static let defaultEndpoint = URL(string: "https://garmin-wod.onrender.com/api/completed-workouts")!

    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL = CompletedWorkoutHistoryAPIClient.defaultEndpoint, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchCompletedWorkoutHistory(limit: Int = 50, before: String? = nil, completion: @escaping (Result<CompletedWorkoutHistoryPage, CompletedWorkoutHistoryError>) -> Void) {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let before, !before.isEmpty {
            queryItems.append(URLQueryItem(name: "before", value: before))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        session.dataTask(with: request) { data, response, error in
            completion(Self.decodeResult(data: data, response: response, error: error) {
                try JSONDecoder().decode(CompletedWorkoutHistoryPage.self, from: $0)
            })
        }.resume()
    }

    func fetchCompletedWorkout(sessionId: String, completion: @escaping (Result<CompletedWorkoutSession, CompletedWorkoutHistoryError>) -> Void) {
        guard !sessionId.isEmpty else {
            completion(.failure(.invalidResponse))
            return
        }

        let url = endpoint.appendingPathComponent(sessionId)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        session.dataTask(with: request) { data, response, error in
            completion(Self.decodeResult(data: data, response: response, error: error) { data in
                let wrapper = try JSONDecoder().decode(CompletedWorkoutSessionResponse.self, from: data)
                return wrapper.session
            })
        }.resume()
    }

    private static func decodeResult<T>(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        decode: (Data) throws -> T
    ) -> Result<T, CompletedWorkoutHistoryError> {
        if let error {
            return .failure(.transport(error.localizedDescription))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }

        if httpResponse.statusCode == 404 {
            return .failure(.notFound)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            return .failure(.invalidStatus(httpResponse.statusCode))
        }

        guard let data, !data.isEmpty else {
            return .failure(.emptyData)
        }

        do {
            return .success(try decode(data))
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }
}

private struct CompletedWorkoutSessionResponse: Codable {
    let session: CompletedWorkoutSession
}

final class CompletedWorkoutHistoryStore: CompletedWorkoutHistoryStoring {
    private let directoryURL: URL
    private let fileManager: FileManager
    private let summariesURL: URL

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = baseURL
                .appendingPathComponent("GarminWODCompanion", isDirectory: true)
                .appendingPathComponent("completed-workouts", isDirectory: true)
        }
        self.summariesURL = self.directoryURL.appendingPathComponent("summaries.json")
    }

    func loadSummaries() -> [CompletedWorkoutSummary] {
        do {
            let data = try Data(contentsOf: summariesURL)
            let decoded = try JSONDecoder().decode([CompletedWorkoutSummary].self, from: data)
            return sortedDedupedSummaries(decoded)
        } catch {
            return []
        }
    }

    func saveSummaries(_ summaries: [CompletedWorkoutSummary]) {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(sortedDedupedSummaries(summaries))
            try data.write(to: summariesURL, options: [.atomic])
        } catch {
            print("[HISTORY] summary save failed: \(error)")
        }
    }

    func loadSession(sessionId: String) -> CompletedWorkoutSession? {
        do {
            let data = try Data(contentsOf: sessionURL(sessionId: sessionId))
            return try JSONDecoder().decode(CompletedWorkoutSession.self, from: data)
        } catch {
            return nil
        }
    }

    func saveSession(_ session: CompletedWorkoutSession) {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionURL(sessionId: session.sessionId), options: [.atomic])
        } catch {
            print("[HISTORY] detail save failed: \(error)")
        }
    }

    private func sessionURL(sessionId: String) -> URL {
        let safeId = sessionId
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
        return directoryURL.appendingPathComponent("\(safeId).json")
    }
}

func sortedDedupedSummaries(_ summaries: [CompletedWorkoutSummary]) -> [CompletedWorkoutSummary] {
    var bySessionId: [String: CompletedWorkoutSummary] = [:]
    for summary in summaries where !summary.sessionId.isEmpty {
        bySessionId[summary.sessionId] = summary
    }

    return bySessionId.values.sorted {
        if ($0.finishedAt ?? 0) == ($1.finishedAt ?? 0) {
            return $0.sessionId > $1.sessionId
        }
        return ($0.finishedAt ?? 0) > ($1.finishedAt ?? 0)
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
