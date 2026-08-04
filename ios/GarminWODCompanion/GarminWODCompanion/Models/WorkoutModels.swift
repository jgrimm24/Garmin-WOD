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
    let analytics: WorkoutAnalytics?

    init(
        workoutId: String,
        sessionId: String,
        revision: Int,
        status: RemoteWorkoutSessionStatus,
        round: Int,
        stationIndex: Int,
        elapsedSeconds: Int,
        updatedAt: Int,
        analytics: WorkoutAnalytics? = nil
    ) {
        self.workoutId = workoutId
        self.sessionId = sessionId
        self.revision = revision
        self.status = status
        self.round = round
        self.stationIndex = stationIndex
        self.elapsedSeconds = elapsedSeconds
        self.updatedAt = updatedAt
        self.analytics = analytics
    }
}

struct WorkoutAnalytics: Codable, Equatable {
    var schemaVersion: Int
    var sessionId: String
    var workoutId: String
    var workoutName: String
    var startedAt: Int?
    var finishedAt: Int?
    var totalActiveSeconds: Int?
    var roundsCompleted: Int
    var transitionTimingAvailable: Bool
    var movementEvents: [WorkoutMovementEvent]
    var events: [WorkoutTimelineEvent]

    var summary: WorkoutAnalyticsSummary {
        WorkoutAnalyticsSummary(analytics: self)
    }
}

struct WorkoutMovementEvent: Codable, Equatable, Identifiable {
    var id: String {
        "\(roundNumber)-\(movementIndex)-\(enteredElapsedSeconds)-\(exitedElapsedSeconds)"
    }

    var movementIndex: Int
    var movementName: String
    var prescribedReps: Int?
    var prescribedMeters: Int?
    var prescribedCalories: Int?
    var prescribedSeconds: Int?
    var roundNumber: Int
    var enteredElapsedSeconds: Int
    var exitedElapsedSeconds: Int
    var durationSeconds: Int
    var averageHeartRate: Int?
    var maximumHeartRate: Int?
    var minimumHeartRate: Int?
    var heartRateSampleCount: Int
    var interrupted: Bool?
}

struct WorkoutTimelineEvent: Codable, Equatable {
    var eventType: String
    var sequence: Int
    var elapsedSeconds: Int
    var timestamp: Int?
    var roundNumber: Int?
    var stationIndex: Int?
    var stationName: String?
}

struct WorkoutAnalyticsSummary: Equatable {
    let totalActiveSeconds: Int
    let movementCount: Int
    let roundsCompleted: Int
    let averageHeartRate: Int?
    let maximumHeartRate: Int?
    let roundSplits: [RoundSplit]
    let movementBreakdowns: [MovementBreakdown]
    let longestMovement: WorkoutMovementEvent?
    let fastestMovement: WorkoutMovementEvent?
    let highestHeartRateMovement: WorkoutMovementEvent?
    let transitionTimingAvailable: Bool

    init(analytics: WorkoutAnalytics) {
        let completedEvents = analytics.movementEvents.filter { $0.durationSeconds >= 0 }
        totalActiveSeconds = analytics.totalActiveSeconds ?? completedEvents.map(\.durationSeconds).reduce(0, +)
        movementCount = completedEvents.count
        roundsCompleted = analytics.roundsCompleted
        transitionTimingAvailable = analytics.transitionTimingAvailable

        let heartRateEvents = completedEvents.filter { ($0.heartRateSampleCount > 0) && $0.averageHeartRate != nil }
        if heartRateEvents.isEmpty {
            averageHeartRate = nil
        } else {
            let totalWeightedHeartRate = heartRateEvents.reduce(0) { partial, event in
                partial + ((event.averageHeartRate ?? 0) * max(event.heartRateSampleCount, 1))
            }
            let totalSamples = heartRateEvents.reduce(0) { $0 + max($1.heartRateSampleCount, 1) }
            averageHeartRate = totalSamples > 0 ? totalWeightedHeartRate / totalSamples : nil
        }

        maximumHeartRate = completedEvents.compactMap(\.maximumHeartRate).max()
        roundSplits = Self.buildRoundSplits(from: completedEvents)
        movementBreakdowns = Self.buildMovementBreakdowns(from: completedEvents)
        longestMovement = completedEvents.max { $0.durationSeconds < $1.durationSeconds }
        fastestMovement = completedEvents.filter { $0.durationSeconds > 0 }.min { $0.durationSeconds < $1.durationSeconds }
        highestHeartRateMovement = completedEvents.compactMap { event -> WorkoutMovementEvent? in
            event.maximumHeartRate == nil ? nil : event
        }.max { ($0.maximumHeartRate ?? 0) < ($1.maximumHeartRate ?? 0) }
    }

    static func buildRoundSplits(from events: [WorkoutMovementEvent]) -> [RoundSplit] {
        let grouped = Dictionary(grouping: events, by: \.roundNumber)
        return grouped.keys.sorted().map { round in
            RoundSplit(
                roundNumber: round,
                durationSeconds: grouped[round, default: []].map(\.durationSeconds).reduce(0, +)
            )
        }
    }

    static func buildMovementBreakdowns(from events: [WorkoutMovementEvent]) -> [MovementBreakdown] {
        let grouped = Dictionary(grouping: events) { event in
            normalizedMovementIdentity(event.movementName)
        }

        return grouped.keys.sorted().map { movementName in
            let occurrences = grouped[movementName, default: []].sorted {
                if $0.roundNumber == $1.roundNumber {
                    return $0.movementIndex < $1.movementIndex
                }
                return $0.roundNumber < $1.roundNumber
            }
            let total = occurrences.map(\.durationSeconds).reduce(0, +)
            let fastest = occurrences.map(\.durationSeconds).min() ?? 0
            let slowest = occurrences.map(\.durationSeconds).max() ?? 0
            let maxHeartRate = occurrences.compactMap(\.maximumHeartRate).max()

            return MovementBreakdown(
                movementName: movementName,
                occurrences: occurrences,
                totalSeconds: total,
                averageSeconds: occurrences.isEmpty ? 0 : total / occurrences.count,
                fastestSeconds: fastest,
                slowestSeconds: slowest,
                maximumHeartRate: maxHeartRate
            )
        }
    }

    static func normalizedMovementIdentity(_ name: String) -> String {
        let words = name
            .uppercased()
            .replacingOccurrences(of: "@", with: " ")
            .split(separator: " ")
            .map(String.init)

        let stripped = words.drop { word in
            isPrescriptionWord(word)
        }

        return stripped.isEmpty ? name.uppercased() : stripped.joined(separator: " ")
    }

    private static func isPrescriptionWord(_ word: String) -> Bool {
        if word.allSatisfy(\.isNumber) {
            return true
        }

        if ["CAL", "CALS", "M", "SEC", "REPS"].contains(word) {
            return true
        }

        let suffixes = ["M", "CAL", "CALS", "SEC"]
        return suffixes.contains { suffix in
            word.hasSuffix(suffix) && word.dropLast(suffix.count).allSatisfy(\.isNumber)
        }
    }
}

struct RoundSplit: Equatable, Identifiable {
    var id: Int { roundNumber }
    let roundNumber: Int
    let durationSeconds: Int
}

struct MovementBreakdown: Equatable, Identifiable {
    var id: String { movementName }
    let movementName: String
    let occurrences: [WorkoutMovementEvent]
    let totalSeconds: Int
    let averageSeconds: Int
    let fastestSeconds: Int
    let slowestSeconds: Int
    let maximumHeartRate: Int?
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
    var weightUnit: String?
    var maleWeightKg: Int?
    var femaleWeightKg: Int?
    var heightUnit: String?
    var maleHeightIn: Int?
    var femaleHeightIn: Int?
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
        case weightUnit
        case maleWeightKg
        case femaleWeightKg
        case heightUnit
        case maleHeightIn
        case femaleHeightIn
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
        weightUnit: String? = nil,
        maleWeightKg: Int? = nil,
        femaleWeightKg: Int? = nil,
        heightUnit: String? = nil,
        maleHeightIn: Int? = nil,
        femaleHeightIn: Int? = nil,
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
        self.weightUnit = weightUnit
        self.maleWeightKg = maleWeightKg
        self.femaleWeightKg = femaleWeightKg
        self.heightUnit = heightUnit
        self.maleHeightIn = maleHeightIn
        self.femaleHeightIn = femaleHeightIn
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
        weightUnit = try container.decodeIfPresent(String.self, forKey: .weightUnit)
        maleWeightKg = try container.decodeIfPresent(Int.self, forKey: .maleWeightKg)
        femaleWeightKg = try container.decodeIfPresent(Int.self, forKey: .femaleWeightKg)
        heightUnit = try container.decodeIfPresent(String.self, forKey: .heightUnit)
        maleHeightIn = try container.decodeIfPresent(Int.self, forKey: .maleHeightIn)
        femaleHeightIn = try container.decodeIfPresent(Int.self, forKey: .femaleHeightIn)
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
        try container.encodeIfPresent(weightUnit, forKey: .weightUnit)
        try container.encodeIfPresent(maleWeightKg, forKey: .maleWeightKg)
        try container.encodeIfPresent(femaleWeightKg, forKey: .femaleWeightKg)
        try container.encodeIfPresent(heightUnit, forKey: .heightUnit)
        try container.encodeIfPresent(maleHeightIn, forKey: .maleHeightIn)
        try container.encodeIfPresent(femaleHeightIn, forKey: .femaleHeightIn)
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
            fingerprint += ":\(syncValue(station.weightUnit))"
            fingerprint += ":\(syncValue(station.maleWeightKg))"
            fingerprint += ":\(syncValue(station.femaleWeightKg))"
            fingerprint += ":\(syncValue(station.heightUnit))"
            fingerprint += ":\(syncValue(station.maleHeightIn))"
            fingerprint += ":\(syncValue(station.femaleHeightIn))"
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

        if let maleWeightKg, let femaleWeightKg {
            parts.append("\(maleWeightKg)/\(femaleWeightKg) kg")
        } else if let maleWeightKg {
            parts.append("\(maleWeightKg) kg")
        }

        if let maleHeightIn, let femaleHeightIn {
            parts.append("\(maleHeightIn)/\(femaleHeightIn) in")
        } else if let maleHeightIn {
            parts.append("\(maleHeightIn) in")
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
