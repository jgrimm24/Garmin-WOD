import Foundation

final class DisplayViewModel: ObservableObject {
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    let heartRateManager: MockHeartRateManager
    let bluetoothHeartRateManager: BluetoothHeartRateManager

    @Published private(set) var workoutSummary: WorkoutSummary?
    @Published private(set) var isRefreshingLatestWorkout: Bool = false
    @Published private(set) var latestWorkoutStatusText: String = "Roney sample"
    @Published var selectedHeartRateSource: HeartRateSource = .mock

    private var zoneTimer: Timer?
    private let latestWorkoutClient: LatestWorkoutServing
    private let workoutCache: WorkoutCaching
    private var hasLoadedStartupWorkout = false

    init(
        workoutManager: WorkoutManager = WorkoutManager(),
        timerManager: TimerManager = TimerManager(),
        heartRateManager: MockHeartRateManager = MockHeartRateManager(),
        bluetoothHeartRateManager: BluetoothHeartRateManager = BluetoothHeartRateManager(),
        latestWorkoutClient: LatestWorkoutServing = WorkoutAPIClient(),
        workoutCache: WorkoutCaching = WorkoutCache()
    ) {
        self.workoutManager = workoutManager
        self.timerManager = timerManager
        self.heartRateManager = heartRateManager
        self.bluetoothHeartRateManager = bluetoothHeartRateManager
        self.latestWorkoutClient = latestWorkoutClient
        self.workoutCache = workoutCache
        print("[LIFECYCLE] DisplayViewModel init")
        scheduleZoneTimer()
    }

    deinit {
        print("[LIFECYCLE] DisplayViewModel deinit")
        zoneTimer?.invalidate()
        zoneTimer = nil
    }

    var primaryActionTitle: String {
        switch workoutManager.status {
        case .idle:
            return "Start"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .finished:
            return "Start Over"
        }
    }

    func primaryAction() {
        logState("primaryAction before")
        switch workoutManager.status {
        case .idle:
            startWorkout()
        case .running:
            pauseWorkout()
        case .paused:
            resumeWorkout()
        case .finished:
            resetWorkout()
            startWorkout()
        }
        logState("primaryAction after")
    }

    func loadLatestWorkoutIfNeeded() {
        guard !hasLoadedStartupWorkout else {
            print("[LATEST WOD] startup load skipped; already attempted")
            return
        }

        hasLoadedStartupWorkout = true

        guard workoutManager.status == .idle else {
            print("[LATEST WOD] startup load skipped; status=\(workoutManager.status.rawValue)")
            return
        }

        if let cachedWorkout = workoutCache.loadCachedWorkout() {
            print("[LATEST WOD] loaded cache id=\(cachedWorkout.id) title=\(cachedWorkout.title)")
            workoutManager.load(cachedWorkout)
            latestWorkoutStatusText = "CACHE"
        } else {
            print("[LATEST WOD] no valid cache; using bundled sample")
            latestWorkoutStatusText = "Roney sample"
        }

        refreshLatestWorkout()
    }

    func refreshLatestWorkout() {
        guard workoutManager.status == .idle else {
            print("[LATEST WOD] refresh skipped; status=\(workoutManager.status.rawValue)")
            return
        }

        guard !isRefreshingLatestWorkout else {
            print("[LATEST WOD] refresh skipped; request already running")
            return
        }

        print("[LATEST WOD] refresh started")
        isRefreshingLatestWorkout = true
        latestWorkoutStatusText = "Refreshing…"

        latestWorkoutClient.fetchLatestWorkout { [weak self] result in
            self?.performOnMain {
                self?.handleLatestWorkoutResult(result)
            }
        }
    }

    func startWorkout() {
        print("[VM] startWorkout called")
        logState("startWorkout before")
        workoutManager.start()
        timerManager.start()
        logState("startWorkout after")
    }

    func pauseWorkout() {
        print("[VM] pauseWorkout called")
        logState("pauseWorkout before")
        workoutManager.pause()
        timerManager.pause()
        logState("pauseWorkout after")
    }

    func resumeWorkout() {
        print("[VM] resumeWorkout called")
        logState("resumeWorkout before")
        workoutManager.resume()
        timerManager.resume()
        logState("resumeWorkout after")
    }

    func back() {
        previousStation()
    }

    func next() {
        nextStation()
    }

    func previousStation() {
        print("[VM] previousStation called")
        logState("previousStation before")
        workoutManager.goBack()
        logState("previousStation after")
    }

    func nextStation() {
        print("[VM] nextStation called")
        logState("nextStation before")
        workoutManager.advance()
        if workoutManager.status == .finished {
            captureWorkoutSummaryIfNeeded()
            timerManager.stop()
        }
        logState("nextStation after")
    }

    func finish() {
        finishWorkout()
    }

    func finishWorkout() {
        print("[VM] finishWorkout called")
        logState("finishWorkout before")
        workoutManager.finish()
        captureWorkoutSummaryIfNeeded()
        timerManager.stop()
        logState("finishWorkout after")
    }

    func reset() {
        resetWorkout()
    }

    func resetWorkout() {
        print("[VM] resetWorkout called")
        print("[RESET] before status=\(workoutManager.status.rawValue)")
        logState("resetWorkout before")
        workoutManager.reset()
        timerManager.reset()
        heartRateManager.resetMetrics()
        bluetoothHeartRateManager.resetMetrics()
        workoutSummary = nil
        logState("resetWorkout after")
        print("[RESET] after status=\(workoutManager.status.rawValue)")
    }

    var activeHeartRate: Int? {
        switch selectedHeartRateSource {
        case .mock:
            return heartRateManager.currentHeartRate
        case .bluetooth:
            return bluetoothHeartRateManager.currentHeartRate
        }
    }

    var activeAverageHeartRate: Int {
        switch selectedHeartRateSource {
        case .mock:
            return heartRateManager.averageHeartRate
        case .bluetooth:
            return bluetoothHeartRateManager.averageHeartRate
        }
    }

    var activeMaximumHeartRate: Int {
        switch selectedHeartRateSource {
        case .mock:
            return heartRateManager.maximumHeartRate
        case .bluetooth:
            return bluetoothHeartRateManager.maximumHeartRate
        }
    }

    var activeCurrentZone: HeartRateZone {
        switch selectedHeartRateSource {
        case .mock:
            return heartRateManager.currentZone
        case .bluetooth:
            return bluetoothHeartRateManager.currentZone
        }
    }

    var activeZoneTimes: [Int: Int] {
        switch selectedHeartRateSource {
        case .mock:
            return heartRateManager.zoneTimes
        case .bluetooth:
            return bluetoothHeartRateManager.zoneTimes
        }
    }

    var heartRateSourceLabel: String {
        switch selectedHeartRateSource {
        case .mock:
            return "MOCK HR"
        case .bluetooth:
            return bluetoothHeartRateManager.sourceLabel.uppercased()
        }
    }

    var compactHeartRateSourceLabel: String {
        switch selectedHeartRateSource {
        case .mock:
            return "MOCK HR"
        case .bluetooth:
            switch bluetoothHeartRateManager.connectionState {
            case .bluetoothUnavailable:
                return "BLUETOOTH N/A"
            case .bluetoothUnauthorized:
                return "BLUETOOTH BLOCKED"
            case .poweredOff:
                return "BLUETOOTH OFF"
            case .idle:
                return "BLUETOOTH HR"
            case .scanning:
                return "SCANNING"
            case .deviceFound:
                return "DEVICE FOUND"
            case .connecting:
                return "CONNECTING"
            case .connected:
                return "\(compactConnectedDeviceName) CONNECTED"
            case .disconnected:
                return "HR DISCONNECTED"
            case .failed:
                return "HR FAILED"
            }
        }
    }

    func logLayout(width: Double, height: Double, isLandscape: Bool) {
        print("[LAYOUT] width=\(Int(width)) height=\(Int(height)) selected=\(isLandscape ? "landscape" : "portrait")")
        logState("layout")
    }

    func logState(_ prefix: String) {
        print("[STATE] \(prefix): status=\(workoutManager.status.rawValue) stationIndex=\(workoutManager.currentStationIndex) round=\(workoutManager.currentRound) timerRunning=\(timerManager.isRunning) elapsed=\(timerManager.elapsedSeconds)")
    }

    private func scheduleZoneTimer() {
        guard zoneTimer == nil else {
            return
        }

        zoneTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.workoutManager.status == .running else {
                return
            }

            switch self.selectedHeartRateSource {
            case .mock:
                self.heartRateManager.tickZoneTimeIfWorkoutRunning()
            case .bluetooth:
                self.bluetoothHeartRateManager.tickZoneTimeIfWorkoutRunning()
            }
        }
    }

    private func captureWorkoutSummaryIfNeeded() {
        guard workoutSummary == nil else {
            return
        }

        let station = workoutManager.currentStation
        let summary = WorkoutSummary(
            workoutName: workoutManager.workout.title,
            workoutType: workoutManager.workout.type,
            elapsedSeconds: timerManager.elapsedSeconds,
            averageHeartRate: activeAverageHeartRate,
            maximumHeartRate: activeMaximumHeartRate,
            zone1Seconds: activeZoneTimes[1, default: 0],
            zone2Seconds: activeZoneTimes[2, default: 0],
            zone3Seconds: activeZoneTimes[3, default: 0],
            zone4Seconds: activeZoneTimes[4, default: 0],
            zone5Seconds: activeZoneTimes[5, default: 0],
            caloriesBurned: nil,
            finalRound: workoutManager.currentRound,
            finalStationIndex: workoutManager.currentStationIndex,
            finalMovementName: station?.displayName ?? "None",
            finishedAt: Date()
        )

        workoutSummary = summary
        print("[SUMMARY] captured elapsed=\(summary.elapsedSeconds) avgHR=\(summary.averageHeartRate) maxHR=\(summary.maximumHeartRate) movement=\(summary.finalMovementName)")
    }

    private func handleLatestWorkoutResult(_ result: Result<WorkoutContract, LatestWorkoutError>) {
        isRefreshingLatestWorkout = false

        guard workoutManager.status == .idle else {
            print("[LATEST WOD] response ignored; status=\(workoutManager.status.rawValue)")
            latestWorkoutStatusText = "Current workout locked"
            return
        }

        switch result {
        case .success(let workout):
            print("[LATEST WOD] web response applied id=\(workout.id) title=\(workout.title) type=\(workout.type.rawValue) stations=\(workout.stations.count)")
            workoutManager.load(workout)
            if workoutCache.saveCachedWorkout(workout) {
                print("[LATEST WOD] cache saved id=\(workout.id)")
            }
            latestWorkoutStatusText = "WEB WOD"

        case .failure(let error):
            print("[LATEST WOD] refresh failed: \(error)")
            latestWorkoutStatusText = "Refresh failed"
        }
    }

    private func performOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private var compactConnectedDeviceName: String {
        guard let name = bluetoothHeartRateManager.connectedPeripheralName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return "HRM"
        }

        let lowercasedName = name.lowercased()
        if lowercasedName.contains("tactix") {
            return lowercasedName.contains("8") ? "TACTIX 8" : "TACTIX"
        }

        if lowercasedName.contains("hrm") {
            return "HRM"
        }

        let words = name.split(separator: " ").prefix(2).joined(separator: " ")
        return words.uppercased()
    }
}
