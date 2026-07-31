import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("[TEST] FAIL: \(message)")
        exit(1)
    }
}

final class StubLatestWorkoutClient: LatestWorkoutServing {
    var fetchCount = 0
    var result: Result<WorkoutContract, LatestWorkoutError>?
    private var pendingCompletions: [(Result<WorkoutContract, LatestWorkoutError>) -> Void] = []

    init(result: Result<WorkoutContract, LatestWorkoutError>? = nil) {
        self.result = result
    }

    func fetchLatestWorkout(completion: @escaping (Result<WorkoutContract, LatestWorkoutError>) -> Void) {
        fetchCount += 1
        if let result {
            completion(result)
        } else {
            pendingCompletions.append(completion)
        }
    }

    func complete(_ result: Result<WorkoutContract, LatestWorkoutError>) {
        let completions = pendingCompletions
        pendingCompletions = []
        completions.forEach { $0(result) }
    }
}

final class StubWorkoutSessionClient: WorkoutSessionServing {
    var fetchCount = 0
    var result: Result<WorkoutSessionState, WorkoutSessionFetchError>?
    private var pendingCompletions: [(Result<WorkoutSessionState, WorkoutSessionFetchError>) -> Void] = []

    init(result: Result<WorkoutSessionState, WorkoutSessionFetchError>? = nil) {
        self.result = result
    }

    func fetchWorkoutSession(completion: @escaping (Result<WorkoutSessionState, WorkoutSessionFetchError>) -> Void) {
        fetchCount += 1
        if let result {
            completion(result)
        } else {
            pendingCompletions.append(completion)
        }
    }

    func complete(_ result: Result<WorkoutSessionState, WorkoutSessionFetchError>) {
        let completions = pendingCompletions
        pendingCompletions = []
        completions.forEach { $0(result) }
    }
}

final class MemoryWorkoutCache: WorkoutCaching {
    var cachedWorkout: WorkoutContract?
    var saveCount = 0

    init(cachedWorkout: WorkoutContract? = nil) {
        self.cachedWorkout = cachedWorkout
    }

    func loadCachedWorkout() -> WorkoutContract? {
        cachedWorkout
    }

    func saveCachedWorkout(_ workout: WorkoutContract) -> Bool {
        saveCount += 1
        cachedWorkout = workout
        return true
    }
}

func latestWorkoutFixture(title: String = "Roney") -> Data {
    """
    {
      "schemaVersion": 1,
      "id": "latest-roney",
      "title": "\(title)",
      "type": "For Time",
      "durationMinutes": null,
      "rounds": 4,
      "notes": ["Hero workout"],
      "sourceText": "Roney\\n4 rounds for time",
      "createdAt": "2026-07-01T00:00:00.000Z",
      "updatedAt": "2026-07-01T00:00:00.000Z",
      "stations": [
        { "id": "run-1", "name": "Run", "reps": null, "calories": null, "meters": 200, "weightLb": null, "maleWeightLb": null, "femaleWeightLb": null, "workSeconds": null, "notes": "" },
        { "id": "thrusters", "name": "Thrusters", "reps": 11, "calories": null, "meters": null, "weightLb": 135, "maleWeightLb": 135, "femaleWeightLb": 95, "workSeconds": null, "notes": "11 Thrusters, 135/95 lbs" },
        { "id": "run-2", "name": "Run", "reps": null, "calories": null, "meters": 200, "weightLb": null, "maleWeightLb": null, "femaleWeightLb": null, "workSeconds": null, "notes": "" },
        { "id": "push-press", "name": "Push Press", "reps": 11, "calories": null, "meters": null, "weightLb": 135, "maleWeightLb": 135, "femaleWeightLb": 95, "workSeconds": null, "notes": "11 Push Press, 135/95 lbs" },
        { "id": "run-3", "name": "Run", "reps": null, "calories": null, "meters": 200, "weightLb": null, "maleWeightLb": null, "femaleWeightLb": null, "workSeconds": null, "notes": "" },
        { "id": "bench-press", "name": "Bench Presses", "reps": 11, "calories": null, "meters": null, "weightLb": 135, "maleWeightLb": 135, "femaleWeightLb": 95, "workSeconds": null, "notes": "11 Bench Presses, 135/95 lbs" }
      ]
    }
    """.data(using: .utf8)!
}

func makeWorkout(
    id: String,
    title: String,
    type: WorkoutType = .amrap,
    rounds: Int? = nil,
    updatedAt: String? = nil
) -> WorkoutContract {
    WorkoutContract(
        schemaVersion: 1,
        id: id,
        title: title,
        type: type,
        durationMinutes: type == .amrap ? 15 : nil,
        rounds: rounds,
        stations: [
            WorkoutStation(id: "\(id)-row", name: "Row", calories: 15),
            WorkoutStation(id: "\(id)-cleans", name: "Power Cleans", reps: 8, weightLb: 135, maleWeightLb: 135, femaleWeightLb: 95)
        ],
        notes: [],
        sourceText: title,
        updatedAt: updatedAt
    )
}

func makeSessionState(
    workout: WorkoutContract,
    sessionId: String = "session-a",
    revision: Int = 1,
    status: RemoteWorkoutSessionStatus = .running,
    round: Int = 1,
    stationIndex: Int = 0,
    elapsedSeconds: Int = 10,
    updatedAt: Int = Int(Date().timeIntervalSince1970)
) -> WorkoutSessionState {
    WorkoutSessionState(
        workoutId: workout.syncIdentity,
        sessionId: sessionId,
        revision: revision,
        status: status,
        round: round,
        stationIndex: stationIndex,
        elapsedSeconds: elapsedSeconds,
        updatedAt: updatedAt
    )
}

let workout = WorkoutContract(
    schemaVersion: 1,
    id: "state-test",
    title: "State Test",
    type: .forTime,
    durationMinutes: nil,
    rounds: 2,
    stations: [
        WorkoutStation(id: "run", name: "Run", distanceMeters: 200),
        WorkoutStation(id: "thrusters", name: "Thrusters", reps: 11, weightLb: 135),
        WorkoutStation(id: "press", name: "Push Press", reps: 11, weightLb: 135)
    ],
    notes: [],
    sourceText: "State transition test"
)

let viewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager()
)

print("[TEST] idle -> start")
expect(viewModel.workoutManager.status == .idle, "initial status should be idle")
viewModel.startWorkout()
expect(viewModel.workoutManager.status == .running, "start should set running")
expect(viewModel.timerManager.isRunning, "start should run timer")
expect(viewModel.workoutManager.currentStationIndex == 0, "start should stay on station 0")
expect(viewModel.workoutManager.currentRound == 1, "start should stay on round 1")

print("[TEST] running -> pause")
viewModel.pauseWorkout()
expect(viewModel.workoutManager.status == .paused, "pause should set paused")
expect(!viewModel.timerManager.isRunning, "pause should stop timer")

print("[TEST] paused -> resume")
viewModel.resumeWorkout()
expect(viewModel.workoutManager.status == .running, "resume should set running")
expect(viewModel.timerManager.isRunning, "resume should run timer")

print("[TEST] next/back station movement")
viewModel.nextStation()
expect(viewModel.workoutManager.currentStationIndex == 1, "next should advance to station 1")
expect(viewModel.workoutManager.currentRound == 1, "next should stay on round 1")
viewModel.previousStation()
expect(viewModel.workoutManager.currentStationIndex == 0, "back should return to station 0")

print("[TEST] round advance")
viewModel.nextStation()
viewModel.nextStation()
viewModel.nextStation()
expect(viewModel.workoutManager.currentStationIndex == 0, "final station next should wrap to station 0")
expect(viewModel.workoutManager.currentRound == 2, "final station next should advance to round 2")

print("[TEST] finish")
viewModel.finishWorkout()
expect(viewModel.workoutManager.status == .finished, "finish should set finished")
expect(!viewModel.timerManager.isRunning, "finish should stop timer")
expect(viewModel.workoutSummary != nil, "finish should create a workout summary")

print("[TEST] reset")
viewModel.resetWorkout()
expect(viewModel.workoutManager.status == .idle, "reset should set idle")
expect(viewModel.workoutManager.currentStationIndex == 0, "reset should restore station 0")
expect(viewModel.workoutManager.currentRound == 1, "reset should restore round 1")
expect(viewModel.timerManager.elapsedSeconds == 0, "reset should clear elapsed seconds")
expect(!viewModel.timerManager.isRunning, "reset should stop timer")
expect(viewModel.workoutSummary == nil, "reset should clear workout summary")

print("[TEST] mock heart-rate update")
viewModel.heartRateManager.setSimulatedHeartRate(155)
expect(viewModel.heartRateManager.currentHeartRate == 155, "mock HR should update to requested value")
expect(viewModel.heartRateManager.currentZone.id == 4, "mock HR 155 should be zone 4")
expect(viewModel.heartRateManager.maximumHeartRate >= 155, "mock HR update should affect max HR")

print("[TEST] display sleep prevention policy")
expect(
    !DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: false, workoutStatus: .idle),
    "idle with follow off should allow normal auto-lock"
)
expect(
    DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: true, workoutStatus: .idle),
    "follow on while waiting should prevent display sleep"
)
expect(
    DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: false, workoutStatus: .running),
    "local running should prevent display sleep"
)
expect(
    DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: false, workoutStatus: .paused),
    "local paused should prevent display sleep"
)
expect(
    DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: true, workoutStatus: .running),
    "remote running while following should prevent display sleep"
)
expect(
    DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: true, workoutStatus: .paused),
    "remote paused while following should prevent display sleep"
)
expect(
    !DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: true, workoutStatus: .finished),
    "finished workout should restore normal auto-lock even if follow remains enabled"
)
expect(
    !DisplayViewModel.shouldPreventDisplaySleep(isFollowingWatch: false, workoutStatus: .finished),
    "local finished should allow normal auto-lock"
)

print("[TEST] display mode preference defaults")
expect(GymDisplayMode.defaultMode == .workout, "fresh display mode should default to WORKOUT")
expect(GymDisplayMode(rawValue: "WORKOUT") == .workout, "WORKOUT raw value should decode")
expect(GymDisplayMode(storedValue: "WOD") == .workout, "legacy WOD preference should map to WORKOUT")
expect(GymDisplayMode(storedValue: "wod") == .workout, "legacy lowercase wod preference should map to WORKOUT")
expect(GymDisplayMode(rawValue: "RUN") == .run, "RUN raw value should decode")

let displayModeSuiteName = "garmin-wod-display-mode-tests-\(UUID().uuidString)"
let displayModeDefaults = UserDefaults(suiteName: displayModeSuiteName)!
displayModeDefaults.removePersistentDomain(forName: displayModeSuiteName)
expect(
    GymDisplayMode(storedValue: displayModeDefaults.string(forKey: GymDisplayMode.storageKey)) == .workout,
    "missing display mode preference should resolve to WORKOUT"
)
displayModeDefaults.set(GymDisplayMode.run.rawValue, forKey: GymDisplayMode.storageKey)
expect(
    GymDisplayMode(storedValue: displayModeDefaults.string(forKey: GymDisplayMode.storageKey)) == .run,
    "display mode preference should persist RUN"
)

let modeStateViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager()
)
modeStateViewModel.startWorkout()
modeStateViewModel.nextStation()
let modeStateStatus = modeStateViewModel.workoutManager.status
let modeStateElapsed = modeStateViewModel.timerManager.elapsedSeconds
let modeStateRound = modeStateViewModel.workoutManager.currentRound
let modeStateStation = modeStateViewModel.workoutManager.currentStationIndex
displayModeDefaults.set(GymDisplayMode.workout.rawValue, forKey: GymDisplayMode.storageKey)
displayModeDefaults.set(GymDisplayMode.run.rawValue, forKey: GymDisplayMode.storageKey)
expect(modeStateViewModel.workoutManager.status == modeStateStatus, "switching display mode should not change workout status")
expect(modeStateViewModel.timerManager.elapsedSeconds == modeStateElapsed, "switching display mode should not reset elapsed time")
expect(modeStateViewModel.workoutManager.currentRound == modeStateRound, "switching display mode should not change round")
expect(modeStateViewModel.workoutManager.currentStationIndex == modeStateStation, "switching display mode should not change station")

print("[TEST] movement display formatter")
expect(MovementDisplayFormatter.heroTitle(for: "20 Cal Row") == "20 CAL\nROW", "cal row should split after quantity")
expect(MovementDisplayFormatter.heroTitle(for: "30 Wall Balls") == "30 WALL\nBALLS", "wall balls should split into balanced lines")
expect(MovementDisplayFormatter.heroTitle(for: "95 lb Thruster") == "95 LB\nTHRUSTER", "weighted movement should keep weight together")
expect(MovementDisplayFormatter.heroTitle(for: "Toes To Bar") == "TOES\nTO BAR", "toes to bar should split into readable phrase")
expect(MovementDisplayFormatter.heroTitle(for: "Double Dumbbell Hang Power Clean") == "DOUBLE DUMBBELL\nHANG POWER CLEAN", "long movement should balance across two lines")
expect(MovementDisplayFormatter.heroTitle(for: nil) == "NONE", "nil movement should render placeholder")
expect(MovementDisplayFormatter.heroTitle(for: "   ") == "NONE", "blank movement should render placeholder")

print("[TEST] workout summary snapshot")
let summaryHeartRateManager = MockHeartRateManager()
summaryHeartRateManager.isDemoModeEnabled = false
let summaryViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: summaryHeartRateManager
)

summaryViewModel.startWorkout()
summaryViewModel.heartRateManager.setSimulatedHeartRate(155)
summaryViewModel.heartRateManager.tickZoneTimeIfWorkoutRunning()
summaryViewModel.heartRateManager.tickZoneTimeIfWorkoutRunning()
summaryViewModel.nextStation()

let finalElapsed = summaryViewModel.timerManager.elapsedSeconds
let finalAverageHeartRate = summaryViewModel.heartRateManager.averageHeartRate
let finalMaximumHeartRate = summaryViewModel.heartRateManager.maximumHeartRate
let finalZone4Seconds = summaryViewModel.heartRateManager.zoneTimes[4, default: 0]

summaryViewModel.finishWorkout()
guard let capturedSummary = summaryViewModel.workoutSummary else {
    print("[TEST] FAIL: finish should capture summary")
    exit(1)
}

expect(capturedSummary.workoutName == workout.title, "summary should capture workout name")
expect(capturedSummary.workoutType == workout.type, "summary should capture workout type")
expect(capturedSummary.displayMode == .workout, "summary should default to WORKOUT presentation mode")
expect(capturedSummary.elapsedSeconds == finalElapsed, "summary elapsed should match final timer value")
expect(capturedSummary.averageHeartRate == finalAverageHeartRate, "summary avg HR should match accumulated value")
expect(capturedSummary.maximumHeartRate == finalMaximumHeartRate, "summary max HR should match accumulated value")
expect(capturedSummary.zone4Seconds == finalZone4Seconds, "summary zone time should match final accumulated value")
expect(capturedSummary.caloriesBurned == nil, "summary calories should be nil until a defensible burned-calorie source exists")
expect(capturedSummary.finalRound == summaryViewModel.workoutManager.currentRound, "summary should capture final round")
expect(capturedSummary.finalStationIndex == summaryViewModel.workoutManager.currentStationIndex, "summary should capture final station index")
expect(capturedSummary.finalMovementName == "11 Thrusters", "summary should capture final movement")

summaryViewModel.heartRateManager.setSimulatedHeartRate(190)
summaryViewModel.heartRateManager.tickZoneTimeIfWorkoutRunning()
expect(summaryViewModel.workoutSummary == capturedSummary, "summary should not mutate after later HR changes")

summaryViewModel.logLayout(width: 844, height: 390, isLandscape: true)
summaryViewModel.logLayout(width: 390, height: 844, isLandscape: false)
expect(summaryViewModel.workoutSummary == capturedSummary, "summary should survive orientation/layout changes")

let runSummaryViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager()
)
runSummaryViewModel.displayMode = .run
runSummaryViewModel.startWorkout()
runSummaryViewModel.finishWorkout()
expect(runSummaryViewModel.workoutSummary?.displayMode == .run, "summary should capture RUN presentation mode at finish")

summaryViewModel.resetWorkout()
expect(summaryViewModel.workoutManager.status == .idle, "new workout reset should restore idle")
expect(summaryViewModel.timerManager.elapsedSeconds == 0, "new workout reset should clear elapsed")
expect(summaryViewModel.workoutManager.currentStationIndex == 0, "new workout reset should restore first station")
expect(summaryViewModel.workoutManager.currentRound == 1, "new workout reset should restore first round")
expect(summaryViewModel.workoutSummary == nil, "new workout reset should clear summary")

print("[TEST] Bluetooth heart-rate parser")
expect(
    BluetoothHeartRateManager.parseHeartRateMeasurement(Data([0x00, 0x7B])) == 123,
    "8-bit HR packet should parse BPM"
)
expect(
    BluetoothHeartRateManager.parseHeartRateMeasurement(Data([0x01, 0x2C, 0x01])) == 300,
    "16-bit HR packet should parse little-endian BPM"
)
expect(
    BluetoothHeartRateManager.parseHeartRateMeasurement(Data()) == nil,
    "empty HR packet should fail safely"
)
expect(
    BluetoothHeartRateManager.parseHeartRateMeasurement(Data([0x00])) == nil,
    "flags-only HR packet should fail safely"
)
expect(
    BluetoothHeartRateManager.parseHeartRateMeasurement(Data([0x01, 0x2C])) == nil,
    "short 16-bit HR packet should fail safely"
)
expect(
    BluetoothHeartRateManager.parseHeartRateMeasurement(Data([0x00, 0x88, 0x10, 0x20])) == 136,
    "8-bit HR packet with optional trailing bytes should parse BPM"
)
expect(
    BluetoothHeartRateManager.parseHeartRateMeasurement(Data([0x01, 0x96, 0x00, 0x10])) == 150,
    "16-bit HR packet with optional trailing bytes should parse BPM"
)

print("[TEST] Workout session contract decoding")
let sessionPayload = """
{
  "session": {
    "workoutId": "\(workout.syncIdentity)",
    "sessionId": "watch-session",
    "revision": 12,
    "status": "paused",
    "round": 2,
    "stationIndex": 1,
    "elapsedSeconds": 99,
    "updatedAt": \(Int(Date().timeIntervalSince1970))
  }
}
""".data(using: .utf8)!
let decodedSession = try WorkoutSessionAPIClient.decodeWorkoutSessionResponse(data: sessionPayload, statusCode: 200)
expect(decodedSession.sessionId == "watch-session", "session wrapper should decode sessionId")
expect(decodedSession.status == .paused, "session wrapper should decode status")

let rawSessionPayload = """
{
  "workoutId": "\(workout.syncIdentity)",
  "sessionId": "raw-watch-session",
  "revision": 13,
  "status": "running",
  "round": 1,
  "stationIndex": 0,
  "elapsedSeconds": 42,
  "updatedAt": \(Int(Date().timeIntervalSince1970))
}
""".data(using: .utf8)!
let decodedRawSession = try WorkoutSessionAPIClient.decodeWorkoutSessionResponse(data: rawSessionPayload, statusCode: 200)
expect(decodedRawSession.sessionId == "raw-watch-session", "raw session response should decode sessionId")
expect(decodedRawSession.elapsedSeconds == 42, "raw session response should decode elapsed time")

do {
    _ = try WorkoutSessionAPIClient.decodeWorkoutSessionResponse(data: Data(), statusCode: 200)
    expect(false, "empty session data should be rejected")
} catch let error as WorkoutSessionFetchError {
    expect(error == .emptyData, "empty session data should return emptyData")
}

do {
    _ = try WorkoutSessionAPIClient.decodeWorkoutSessionResponse(data: sessionPayload, statusCode: 404)
    expect(false, "missing session should be rejected")
} catch let error as WorkoutSessionFetchError {
    expect(error == .notFound, "HTTP 404 should produce notFound")
}

print("[TEST] Latest workout contract decoding")
let decodedLatest = try JSONDecoder().decode(WorkoutContract.self, from: latestWorkoutFixture())
expect(decodedLatest.title == "Roney", "latest fixture should decode workout title")
expect(decodedLatest.type == .forTime, "latest fixture should decode workout type")
expect(decodedLatest.rounds == 4, "latest fixture should decode rounds")
expect(decodedLatest.stations.map(\.name) == ["Run", "Thrusters", "Run", "Push Press", "Run", "Bench Presses"], "latest fixture should preserve station order")
expect(decodedLatest.stations[1].maleWeightLb == 135, "latest fixture should preserve male prescribed weight")
expect(decodedLatest.stations[1].femaleWeightLb == 95, "latest fixture should preserve female prescribed weight")
expect(decodedLatest.stations[1].weightLb == 135, "latest fixture should preserve compatibility weight")
expect(decodedLatest.stations[0].distanceMeters == 200, "latest fixture should decode meters into distanceMeters")

do {
    _ = try WorkoutAPIClient.decodeLatestWorkoutResponse(data: Data("{".utf8), statusCode: 200)
    expect(false, "malformed JSON should be rejected")
} catch {
    expect(true, "malformed JSON rejected")
}

do {
    _ = try WorkoutAPIClient.decodeLatestWorkoutResponse(data: latestWorkoutFixture(), statusCode: 500)
    expect(false, "unsuccessful HTTP status should be rejected")
} catch let error as LatestWorkoutError {
    expect(error == .invalidStatus(500), "HTTP 500 should produce invalidStatus")
} catch {
    expect(false, "HTTP 500 should produce LatestWorkoutError")
}

print("[TEST] Latest workout startup and refresh behavior")
let cachedWorkout = makeWorkout(id: "cached", title: "Cached WOD", type: .forTime, rounds: 3)
let webWorkout = makeWorkout(id: "web", title: "Web WOD", type: .amrap)
let successCache = MemoryWorkoutCache(cachedWorkout: cachedWorkout)
let successClient = StubLatestWorkoutClient(result: .success(webWorkout))
let successViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: successClient,
    workoutCache: successCache
)
successViewModel.loadLatestWorkoutIfNeeded()
expect(successClient.fetchCount == 1, "startup should make one web request")
expect(successViewModel.workoutManager.workout.id == "web", "web success should apply while idle")
expect(successCache.cachedWorkout?.id == "web", "web success should be cached")
expect(successCache.saveCount == 1, "web success should save cache once")

let runningClient = StubLatestWorkoutClient()
let runningCache = MemoryWorkoutCache(cachedWorkout: cachedWorkout)
let runningViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: cachedWorkout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: runningClient,
    workoutCache: runningCache
)
runningViewModel.refreshLatestWorkout()
runningViewModel.startWorkout()
runningClient.complete(.success(webWorkout))
expect(runningViewModel.workoutManager.workout.id == "cached", "web response should not replace running workout")
expect(runningCache.cachedWorkout?.id == "cached", "ignored running response should not overwrite cache")

let failureClient = StubLatestWorkoutClient(result: .failure(.invalidStatus(404)))
let failureViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: cachedWorkout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: failureClient,
    workoutCache: MemoryWorkoutCache(cachedWorkout: cachedWorkout)
)
failureViewModel.refreshLatestWorkout()
expect(failureViewModel.workoutManager.workout.id == "cached", "failed refresh should keep existing workout")

let repeatedClient = StubLatestWorkoutClient()
let repeatedViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: repeatedClient,
    workoutCache: MemoryWorkoutCache()
)
repeatedViewModel.loadLatestWorkoutIfNeeded()
repeatedViewModel.loadLatestWorkoutIfNeeded()
expect(repeatedClient.fetchCount == 1, "repeated lifecycle callbacks should not duplicate startup requests")
repeatedClient.complete(.failure(.invalidStatus(404)))

let foregroundClient = StubLatestWorkoutClient(result: .success(webWorkout))
let foregroundViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: cachedWorkout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: foregroundClient,
    workoutCache: MemoryWorkoutCache(cachedWorkout: cachedWorkout)
)
foregroundViewModel.refreshLatestWorkoutAfterForeground()
expect(foregroundClient.fetchCount == 1, "foreground activation should check the backend once")
expect(foregroundViewModel.workoutManager.workout.id == "web", "foreground refresh should apply a different backend workout")

let unchangedWorkout = makeWorkout(id: "same", title: "Same", updatedAt: "2026-07-01T00:00:00.000Z")
let unchangedClient = StubLatestWorkoutClient(result: .success(unchangedWorkout))
let unchangedCache = MemoryWorkoutCache(cachedWorkout: unchangedWorkout)
let unchangedViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: unchangedWorkout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: unchangedClient,
    workoutCache: unchangedCache
)
unchangedViewModel.refreshLatestWorkout()
expect(unchangedCache.saveCount == 0, "unchanged backend workout should not be re-cached or reset")

let timestampCurrent = makeWorkout(id: "same-version", title: "Same Version", updatedAt: "2026-07-01T00:00:00.000Z")
let timestampNewer = makeWorkout(id: "same-version", title: "Same Version", updatedAt: "2026-07-02T00:00:00.000Z")
let timestampClient = StubLatestWorkoutClient(result: .success(timestampNewer))
let timestampViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: timestampCurrent),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: timestampClient,
    workoutCache: MemoryWorkoutCache(cachedWorkout: timestampCurrent)
)
timestampViewModel.refreshLatestWorkout()
expect(timestampViewModel.workoutManager.workout.updatedAt == "2026-07-02T00:00:00.000Z", "updatedAt differences should be treated as a newer backend workout")

print("[TEST] Latest workout file cache behavior")
let cacheDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("garmin-wod-cache-tests-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
let cacheURL = cacheDirectory.appendingPathComponent("latest-workout.json")
let fileCache = WorkoutCache(fileURL: cacheURL)
expect(fileCache.saveCachedWorkout(webWorkout), "valid downloaded workout should save to file cache")
expect(fileCache.loadCachedWorkout()?.id == "web", "valid downloaded workout should load from file cache")

try Data("not json".utf8).write(to: cacheURL)
let invalidCacheViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutCache: WorkoutCache(fileURL: cacheURL)
)
invalidCacheViewModel.loadLatestWorkoutIfNeeded()
expect(invalidCacheViewModel.workoutManager.workout.title == "Roney", "missing or invalid cache should fall back to Roney")

let protectedCache = MemoryWorkoutCache(cachedWorkout: cachedWorkout)
let invalidResponseViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.transport("bad json"))),
    workoutCache: protectedCache
)
invalidResponseViewModel.loadLatestWorkoutIfNeeded()
expect(protectedCache.cachedWorkout?.id == "cached", "invalid response should not overwrite valid cache")
expect(invalidResponseViewModel.workoutManager.workout.id == "cached", "invalid response should keep cached workout displayed")

print("[TEST] Watch session follow behavior")
let sessionClient = StubWorkoutSessionClient()
let followerViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: sessionClient,
    workoutCache: MemoryWorkoutCache()
)
expect(!followerViewModel.isFollowingWatch, "follow should default off")
expect(sessionClient.fetchCount == 0, "follow off should not poll")

followerViewModel.startFollowingWatch()
expect(followerViewModel.isFollowingWatch, "startFollowingWatch should enable follow")
expect(sessionClient.fetchCount == 1, "startFollowingWatch should poll immediately")
followerViewModel.refreshWatchSession()
expect(sessionClient.fetchCount == 1, "follow polling should not overlap while a request is pending")

sessionClient.complete(.success(makeSessionState(workout: workout, revision: 1, status: .running, round: 1, stationIndex: 1, elapsedSeconds: 20)))
expect(followerViewModel.isMirroringWatchSession, "valid watch state should enable mirroring")
expect(followerViewModel.workoutManager.status == .running, "remote running should set running")
expect(followerViewModel.workoutManager.currentStationIndex == 1, "remote station should apply")
expect(followerViewModel.workoutManager.currentRound == 1, "remote round should apply")
expect(followerViewModel.timerManager.isRunning, "remote running should run local display timer")
expect(followerViewModel.timerManager.elapsedSeconds >= 20, "remote elapsed should apply")

sessionClient.result = .success(makeSessionState(workout: workout, revision: 2, status: .paused, round: 1, stationIndex: 2, elapsedSeconds: 30))
followerViewModel.startFollowingWatch()
followerViewModel.stopFollowingWatch()
followerViewModel.startFollowingWatch()
expect(sessionClient.fetchCount >= 2, "re-enabling follow should poll")
expect(followerViewModel.isFollowingWatch, "follow should re-enable")

let directSessionClient = StubWorkoutSessionClient(result: .success(makeSessionState(workout: workout, revision: 3, status: .paused, round: 1, stationIndex: 2, elapsedSeconds: 30)))
let directFollower = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: directSessionClient,
    workoutCache: MemoryWorkoutCache()
)
directFollower.startFollowingWatch()
expect(directFollower.workoutManager.status == .paused, "remote paused should set paused")
expect(!directFollower.timerManager.isRunning, "remote paused should freeze timer")
expect(directFollower.timerManager.elapsedSeconds == 30, "remote paused elapsed should apply exactly")

let oldRevisionClient = StubWorkoutSessionClient(result: .success(makeSessionState(workout: workout, revision: 2, status: .running, round: 1, stationIndex: 0, elapsedSeconds: 5)))
directFollower.stopFollowingWatch()
let oldRevisionFollower = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: oldRevisionClient,
    workoutCache: MemoryWorkoutCache()
)
oldRevisionFollower.startFollowingWatch()
oldRevisionClient.result = .success(makeSessionState(workout: workout, revision: 1, status: .paused, round: 1, stationIndex: 2, elapsedSeconds: 30))
oldRevisionFollower.refreshWatchSession()
expect(oldRevisionFollower.workoutManager.currentStationIndex == 0, "older duplicate revision should not apply over newer state")

let mismatchedWorkout = makeWorkout(id: "other", title: "Other")
let mismatchClient = StubWorkoutSessionClient(result: .success(makeSessionState(workout: mismatchedWorkout, revision: 1, status: .running)))
let mismatchFollower = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: mismatchClient,
    workoutCache: MemoryWorkoutCache()
)
mismatchFollower.startFollowingWatch()
expect(!mismatchFollower.isMirroringWatchSession, "mismatched workout should not mirror")
expect(mismatchFollower.workoutManager.status == .idle, "mismatched workout should not change status")

let invalidIndexClient = StubWorkoutSessionClient(result: .success(makeSessionState(workout: workout, revision: 1, stationIndex: 99)))
let invalidIndexFollower = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: invalidIndexClient,
    workoutCache: MemoryWorkoutCache()
)
invalidIndexFollower.startFollowingWatch()
expect(!invalidIndexFollower.isMirroringWatchSession, "invalid station index should not mirror")

let staleClient = StubWorkoutSessionClient(result: .success(makeSessionState(workout: workout, revision: 1, updatedAt: Int(Date().timeIntervalSince1970) - 3600)))
let staleFollower = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: staleClient,
    workoutCache: MemoryWorkoutCache()
)
staleFollower.startFollowingWatch()
expect(!staleFollower.isMirroringWatchSession, "stale session should not mirror")

let finishedClient = StubWorkoutSessionClient(result: .success(makeSessionState(workout: workout, revision: 5, status: .finished, round: 2, stationIndex: 2, elapsedSeconds: 120)))
let finishedFollower = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: finishedClient,
    workoutCache: MemoryWorkoutCache()
)
finishedFollower.startFollowingWatch()
expect(finishedFollower.workoutManager.status == .finished, "remote finished should set finished")
expect(finishedFollower.workoutSummary != nil, "remote finished should capture summary")
expect(finishedFollower.workoutSummary?.elapsedSeconds == 120, "remote finished summary should freeze remote elapsed")
finishedFollower.heartRateManager.setSimulatedHeartRate(180)
expect(finishedFollower.workoutSummary?.elapsedSeconds == 120, "post-finish HR should not mutate summary elapsed")

finishedFollower.resetWorkout()
expect(finishedFollower.workoutSummary == nil, "reset should clear remote summary")
expect(finishedFollower.workoutManager.status == .idle, "reset after following should return idle")

let watchFailureClient = StubWorkoutSessionClient(result: .failure(.invalidStatus(503)))
let failureFollower = DisplayViewModel(
    workoutManager: WorkoutManager(workout: workout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: StubLatestWorkoutClient(result: .failure(.invalidStatus(404))),
    workoutSessionClient: watchFailureClient,
    workoutCache: MemoryWorkoutCache()
)
failureFollower.startFollowingWatch()
expect(failureFollower.isFollowingWatch, "failed watch fetch should keep follow mode enabled")
expect(!failureFollower.isMirroringWatchSession, "failed watch fetch should not start mirroring")
expect(failureFollower.workoutManager.status == .idle, "failed watch fetch should not change workout status")

let oldPhoneWorkout = makeWorkout(id: "old-phone", title: "Old Phone WOD")
let latestWatchWorkout = makeWorkout(id: "latest-watch", title: "Latest Watch WOD", updatedAt: "2026-07-03T00:00:00.000Z")
let latestBeforeFollowClient = StubLatestWorkoutClient(result: .success(latestWatchWorkout))
let latestSessionClient = StubWorkoutSessionClient(result: .success(makeSessionState(workout: latestWatchWorkout, revision: 1, status: .running, round: 1, stationIndex: 0, elapsedSeconds: 8)))
let latestBeforeFollowCache = MemoryWorkoutCache(cachedWorkout: oldPhoneWorkout)
let latestBeforeFollowViewModel = DisplayViewModel(
    workoutManager: WorkoutManager(workout: oldPhoneWorkout),
    timerManager: TimerManager(),
    heartRateManager: MockHeartRateManager(),
    latestWorkoutClient: latestBeforeFollowClient,
    workoutSessionClient: latestSessionClient,
    workoutCache: latestBeforeFollowCache
)
latestBeforeFollowViewModel.startFollowingWatch()
expect(latestBeforeFollowClient.fetchCount == 1, "Follow Watch should check latest backend workout before mirroring")
expect(latestSessionClient.fetchCount == 1, "Follow Watch should poll the watch session after latest workout sync")
expect(latestBeforeFollowViewModel.workoutManager.workout.id == "latest-watch", "Follow Watch latest sync should replace a stale local workout")
expect(latestBeforeFollowViewModel.isMirroringWatchSession, "Follow Watch should mirror once the refreshed workout identity matches the watch")
expect(latestBeforeFollowViewModel.workoutManager.status == .running, "refreshed Follow Watch session should apply running state")
expect(latestBeforeFollowCache.cachedWorkout?.id == "latest-watch", "Follow Watch latest sync should update the local cache")

print("[TEST] PASS: DisplayViewModel state transitions")
