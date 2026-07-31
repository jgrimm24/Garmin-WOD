import Foundation

enum WorkoutType: String, Codable, CaseIterable {
    case unknown = "Unknown"
    case forTime = "For Time"
    case amrap = "AMRAP"
    case emom = "EMOM"
    case tabata = "Tabata"
    case interval = "Interval"
    case strength = "Strength"
    case chipper = "Chipper"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = WorkoutType(rawValue: value) ?? .unknown
    }
}

enum WorkoutTypeCode: String, Codable {
    case unknown = "UNKNOWN"
    case forTime = "FOR_TIME"
    case amrap = "AMRAP"
    case emom = "EMOM"
    case interval = "INTERVAL"
    case strength = "STRENGTH"
    case chipper = "CHIPPER"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = WorkoutTypeCode(rawValue: value) ?? .unknown
    }
}

enum WorkoutStructureType: String, Codable {
    case unknown = "UNKNOWN"
    case fixedStations = "FIXED_STATIONS"
    case repScheme = "REP_SCHEME"
    case timedInterval = "TIMED_INTERVAL"
    case ladder = "LADDER"
    case chipper = "CHIPPER"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = WorkoutStructureType(rawValue: value) ?? .unknown
    }
}

enum WorkoutStatus: String {
    case idle = "Idle"
    case running = "Running"
    case paused = "Paused"
    case finished = "Finished"
}

enum GymDisplayMode: String, CaseIterable {
    case workout = "WORKOUT"
    case run = "RUN"

    static let storageKey = "gymDisplayMode"
    static let defaultMode: GymDisplayMode = .workout

    init(storedValue: String?) {
        switch storedValue?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "RUN":
            self = .run
        case "WOD", "WORKOUT":
            self = .workout
        default:
            self = .defaultMode
        }
    }
}

enum RemoteWorkoutSessionStatus: String, Codable {
    case idle
    case running
    case paused
    case finished

    var workoutStatus: WorkoutStatus {
        switch self {
        case .idle:
            return .idle
        case .running:
            return .running
        case .paused:
            return .paused
        case .finished:
            return .finished
        }
    }
}

struct WorkoutSessionState: Codable, Equatable {
    let workoutId: String
    let sessionId: String
    let revision: Int
    let status: RemoteWorkoutSessionStatus
    let round: Int
    let stationIndex: Int
    let elapsedSeconds: Int
    let updatedAt: Int
}

struct WorkoutContract: Codable, Identifiable {
    var schemaVersion: Int
    var id: String
    var title: String
    var type: WorkoutType
    var workoutType: WorkoutTypeCode? = nil
    var structureType: WorkoutStructureType? = nil
    var durationMinutes: Int?
    var durationSeconds: Int? = nil
    var rounds: Int?
    var repScheme: [Int]? = nil
    var intervalSeconds: Int? = nil
    var stations: [WorkoutStation]
    var notes: [String]
    var sourceText: String
    var parserWarnings: [String]? = nil
    var createdAt: String? = nil
    var updatedAt: String? = nil
}

struct WorkoutSummary: Equatable {
    let displayMode: GymDisplayMode
    let workoutName: String
    let workoutType: WorkoutType
    let elapsedSeconds: Int
    let averageHeartRate: Int
    let maximumHeartRate: Int
    let zone1Seconds: Int
    let zone2Seconds: Int
    let zone3Seconds: Int
    let zone4Seconds: Int
    let zone5Seconds: Int
    let caloriesBurned: Int?
    let finalRound: Int
    let finalStationIndex: Int
    let finalMovementName: String
    let finishedAt: Date

    var elapsedTimeText: String {
        Self.format(seconds: elapsedSeconds)
    }

    var zoneTimes: [(label: String, seconds: Int)] {
        [
            ("Zone 1", zone1Seconds),
            ("Zone 2", zone2Seconds),
            ("Zone 3", zone3Seconds),
            ("Zone 4", zone4Seconds),
            ("Zone 5", zone5Seconds)
        ]
    }

    var caloriesText: String {
        guard let caloriesBurned else {
            return "N/A"
        }

        return "\(caloriesBurned)"
    }

    static func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WorkoutStation: Codable, Identifiable {
    var id: String
    var name: String
    var reps: Int?
    var workSeconds: Int?
    var distanceMeters: Int?
    var calories: Int?
    var weightLb: Int?
    var maleWeightLb: Int?
    var femaleWeightLb: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case reps
        case workSeconds
        case distanceMeters
        case meters
        case calories
        case weightLb
        case maleWeightLb
        case femaleWeightLb
        case notes
    }

    init(
        id: String,
        name: String,
        reps: Int? = nil,
        workSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        calories: Int? = nil,
        weightLb: Int? = nil,
        maleWeightLb: Int? = nil,
        femaleWeightLb: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.reps = reps
        self.workSeconds = workSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.weightLb = weightLb
        self.maleWeightLb = maleWeightLb
        self.femaleWeightLb = femaleWeightLb
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        workSeconds = try container.decodeIfPresent(Int.self, forKey: .workSeconds)
        distanceMeters = try container.decodeIfPresent(Int.self, forKey: .distanceMeters)
            ?? container.decodeIfPresent(Int.self, forKey: .meters)
        calories = try container.decodeIfPresent(Int.self, forKey: .calories)
        weightLb = try container.decodeIfPresent(Int.self, forKey: .weightLb)
        maleWeightLb = try container.decodeIfPresent(Int.self, forKey: .maleWeightLb)
        femaleWeightLb = try container.decodeIfPresent(Int.self, forKey: .femaleWeightLb)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(workSeconds, forKey: .workSeconds)
        try container.encodeIfPresent(distanceMeters, forKey: .distanceMeters)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(weightLb, forKey: .weightLb)
        try container.encodeIfPresent(maleWeightLb, forKey: .maleWeightLb)
        try container.encodeIfPresent(femaleWeightLb, forKey: .femaleWeightLb)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

extension WorkoutContract {
    var syncIdentity: String {
        "id:\(id)|fp:\(syncFingerprint)"
    }

    var latestVersionDescription: String {
        let timestamp = updatedAt?.trimmingCharacters(in: .whitespacesAndNewlines)
        return "id=\(id) updatedAt=\(timestamp?.isEmpty == false ? timestamp! : "none") identity=\(syncIdentity)"
    }

    private var syncFingerprint: String {
        var fingerprint = "\(type.rawValue)|\(syncValue(workoutType?.rawValue))|\(syncValue(structureType?.rawValue))|\(syncValue(durationMinutes))|\(syncValue(durationSeconds))|\(syncValue(rounds))|\(syncValue(intervalSeconds))"
        fingerprint += "|scheme:\((repScheme ?? []).map(String.init).joined(separator: ","))"
        fingerprint += "|count:\(stations.count)"

        for station in stations {
            fingerprint += "|\(syncValue(station.name))"
            fingerprint += ":\(syncValue(station.reps))"
            fingerprint += ":\(syncValue(station.calories))"
            fingerprint += ":\(syncValue(station.distanceMeters))"
            fingerprint += ":\(syncValue(station.weightLb))"
            fingerprint += ":\(syncValue(station.maleWeightLb))"
            fingerprint += ":\(syncValue(station.femaleWeightLb))"
            fingerprint += ":\(syncValue(station.workSeconds))"
        }

        return fingerprint
    }

    private func syncValue(_ value: Any?) -> String {
        guard let value else {
            return "null"
        }

        return "\(value)"
    }
}

extension WorkoutStation {
    var prescriptionText: String {
        var parts: [String] = []

        if let distanceMeters {
            parts.append("\(distanceMeters)m")
        }

        if let calories {
            parts.append("\(calories) cal")
        }

        if let reps {
            parts.append("\(reps) reps")
        }

        if let maleWeightLb, let femaleWeightLb {
            parts.append("\(maleWeightLb)/\(femaleWeightLb) lb")
        } else if let weightLb {
            parts.append("\(weightLb) lb")
        }

        if let workSeconds {
            parts.append("\(workSeconds)s")
        }

        return parts.isEmpty ? name : parts.joined(separator: " · ")
    }

    var displayName: String {
        if let distanceMeters, !name.lowercased().contains("\(distanceMeters)") {
            return "\(distanceMeters)m \(name)"
        }

        if let calories, !name.lowercased().contains("cal") {
            return "\(calories) cal \(name)"
        }

        if let reps, !name.lowercased().hasPrefix("\(reps)") {
            return "\(reps) \(name)"
        }

        return name
    }
}
