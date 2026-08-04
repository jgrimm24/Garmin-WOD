import Foundation

final class DisplayViewModel: ObservableObject {
    private enum LatestWorkoutRefreshReason: String {
        case startup
        case manual
        case foreground
        case followWatch
    }

    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    let heartRateManager: MockHeartRateManager
    let bluetoothHeartRateManager: BluetoothHeartRateManager

    @Published private(set) var workoutSummary: WorkoutSummary?
    @Published private(set) var latestWorkoutAnalytics: WorkoutAnalytics?
    @Published private(set) var isRefreshingLatestWorkout: Bool = false
    @Published private(set) var latestWorkoutStatusText: String = "Roney sample"
    @Published var selectedHeartRateSource: HeartRateSource = .mock
    @Published var displayMode: GymDisplayMode = .defaultMode
    @Published private(set) var isFollowingWatch: Bool = false
    @Published private(set) var isMirroringWatchSession: Bool = false
    @Published private(set) var watchSyncStatusText: String = "Follow Watch Off"
    @Published private(set) var workoutHistory: [CompletedWorkoutSummary] = []
    @Published private(set) var selectedCompletedWorkout: CompletedWorkoutSession?
    @Published private(set) var workoutHistoryStatusText: String = "History ready"
    @Published private(set) var isRefreshingWorkoutHistory: Bool = false

    private var zoneTimer: Timer?
    private var watchSessionPollTimer: Timer?
    private let latestWorkoutClient: LatestWorkoutServing
    private let workoutSessionClient: WorkoutSessionServing
    private let completedWorkoutHistoryClient: CompletedWorkoutHistoryServing
    private let completedWorkoutHistoryStore: CompletedWorkoutHistoryStoring
    private let workoutCache: WorkoutCaching
    private var hasLoadedStartupWorkout = false
    private var isPollingWatchSession = false
    private var latestWorkoutRefreshCompletions: [(Bool) -> Void] = []
    private var lastAppliedWatchSessionId: String?
    private var lastAppliedWatchRevision = 0
    private let watchSessionFreshnessSeconds = 30
    private let analyticsStorageKey = "latestWorkoutAnalyticsV1"

    init(
        workoutManager: WorkoutManager = WorkoutManager(),
        timerManager: TimerManager = TimerManager(),
        heartRateManager: MockHeartRateManager = MockHeartRateManager(),
        bluetoothHeartRateManager: BluetoothHeartRateManager = BluetoothHeartRateManager(),
        latestWorkoutClient: LatestWorkoutServing = WorkoutAPIClient(),
        workoutSessionClient: WorkoutSessionServing = WorkoutSessionAPIClient(),
        completedWorkoutHistoryClient: CompletedWorkoutHistoryServing = CompletedWorkoutHistoryAPIClient(),
        completedWorkoutHistoryStore: CompletedWorkoutHistoryStoring = CompletedWorkoutHistoryStore(),
        workoutCache: WorkoutCaching = WorkoutCache()
    ) {
        self.workoutManager = workoutManager
        self.timerManager = timerManager
        self.heartRateManager = heartRateManager
        self.bluetoothHeartRateManager = bluetoothHeartRateManager
        self.latestWorkoutClient = latestWorkoutClient
        self.workoutSessionClient = workoutSessionClient
        self.completedWorkoutHistoryClient = completedWorkoutHistoryClient
        self.completedWorkoutHistoryStore = completedWorkoutHistoryStore
        self.workoutCache = workoutCache
        self.latestWorkoutAnalytics = Self.loadPersistedAnalytics(storageKey: analyticsStorageKey)
        self.workoutHistory = completedWorkoutHistoryStore.loadSummaries()
        migrateLatestAnalyticsIntoHistoryIfNeeded()
        print("[LIFECYCLE] DisplayViewModel init")
        scheduleZoneTimer()
    }

    deinit {
        print("[LIFECYCLE] DisplayViewModel deinit")
        zoneTimer?.invalidate()
        zoneTimer = nil
        stopFollowingWatch()
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

        refreshLatestWorkout(reason: .startup)
        refreshWorkoutHistory(reason: "startup")
    }

    func refreshLatestWorkout() {
        refreshLatestWorkout(reason: .manual)
        refreshWorkoutHistory(reason: "manual")
    }

    func refreshLatestWorkoutAfterForeground() {
        guard displayMode == .workout else {
            return
        }

        refreshLatestWorkout(reason: .foreground)
        refreshWorkoutHistory(reason: "foreground")
    }

    private func refreshLatestWorkout(
        reason: LatestWorkoutRefreshReason,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard workoutManager.status == .idle else {
            print("[LATEST WOD] \(reason.rawValue) refresh skipped; status=\(workoutManager.status.rawValue)")
            completion?(false)
            return
        }

        guard !isRefreshingLatestWorkout else {
            print("[LATEST WOD] \(reason.rawValue) refresh joined; request already running")
            if let completion {
                latestWorkoutRefreshCompletions.append(completion)
            }
            return
        }

        if let completion {
            latestWorkoutRefreshCompletions.append(completion)
        }

        print("[LATEST WOD] \(reason.rawValue) refresh started")
        isRefreshingLatestWorkout = true
        latestWorkoutStatusText = "Refreshing…"

        latestWorkoutClient.fetchLatestWorkout { [weak self] result in
            self?.performOnMain {
                self?.handleLatestWorkoutResult(result, reason: reason)
            }
        }
    }

    func refreshWorkoutHistory(reason: String = "manual") {
        guard !isRefreshingWorkoutHistory else {
            print("[HISTORY] \(reason) refresh skipped; request already running")
            return
        }

        isRefreshingWorkoutHistory = true
        workoutHistoryStatusText = workoutHistory.isEmpty ? "Loading history" : "Refreshing history"
        print("[HISTORY] \(reason) refresh started")

        completedWorkoutHistoryClient.fetchCompletedWorkoutHistory(limit: 50, before: nil) { [weak self] result in
            self?.performOnMain {
                self?.handleWorkoutHistoryResult(result, reason: reason)
            }
        }
    }

    func openCompletedWorkout(_ summary: CompletedWorkoutSummary) {
        if let cached = completedWorkoutHistoryStore.loadSession(sessionId: summary.sessionId) {
            selectedCompletedWorkout = cached
        }

        completedWorkoutHistoryClient.fetchCompletedWorkout(sessionId: summary.sessionId) { [weak self] result in
            self?.performOnMain {
                switch result {
                case .success(let session):
                    self?.selectedCompletedWorkout = session
                    self?.completedWorkoutHistoryStore.saveSession(session)
                    self?.mergeWorkoutHistorySummaries([session.summary])
                    self?.workoutHistoryStatusText = "Loaded result"

                case .failure(let error):
                    if self?.selectedCompletedWorkout == nil {
                        self?.workoutHistoryStatusText = "Could not load result"
                    } else {
                        self?.workoutHistoryStatusText = "Showing cached result"
                    }
                    print("[HISTORY] detail fetch failed session=\(summary.sessionId): \(error)")
                }
            }
        }
    }

    func clearSelectedCompletedWorkout() {
        selectedCompletedWorkout = nil
    }

    func startWorkout() {
        print("[VM] startWorkout called")
        guard canUseLocalWorkoutControls else {
            print("[WATCH SYNC] local start ignored while mirroring watch")
            return
        }
        logState("startWorkout before")
        workoutManager.start()
        timerManager.start()
        logState("startWorkout after")
    }

    func pauseWorkout() {
        print("[VM] pauseWorkout called")
        guard canUseLocalWorkoutControls else {
            print("[WATCH SYNC] local pause ignored while mirroring watch")
            return
        }
        logState("pauseWorkout before")
        workoutManager.pause()
        timerManager.pause()
        logState("pauseWorkout after")
    }

    func resumeWorkout() {
        print("[VM] resumeWorkout called")
        guard canUseLocalWorkoutControls else {
            print("[WATCH SYNC] local resume ignored while mirroring watch")
            return
        }
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
        guard canUseLocalWorkoutControls else {
            print("[WATCH SYNC] local back ignored while mirroring watch")
            return
        }
        logState("previousStation before")
        workoutManager.goBack()
        logState("previousStation after")
    }

    func nextStation() {
        print("[VM] nextStation called")
        guard canUseLocalWorkoutControls else {
            print("[WATCH SYNC] local next ignored while mirroring watch")
            return
        }
        logState("nextStation before")
        workoutManager.advance()
        if workoutManager.status == .finished {
            latestWorkoutAnalytics = nil
            persistLatestAnalytics(nil)
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
        guard canUseLocalWorkoutControls else {
            print("[WATCH SYNC] local finish ignored while mirroring watch")
            return
        }
        logState("finishWorkout before")
        workoutManager.finish()
        latestWorkoutAnalytics = nil
        persistLatestAnalytics(nil)
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
        clearWatchMirrorState()
        logState("resetWorkout after")
        print("[RESET] after status=\(workoutManager.status.rawValue)")
    }

    var canUseLocalWorkoutControls: Bool {
        !(isFollowingWatch && isMirroringWatchSession)
    }

    var shouldPreventDisplaySleep: Bool {
        Self.shouldPreventDisplaySleep(
            isFollowingWatch: isFollowingWatch,
            workoutStatus: workoutManager.status
        )
    }

    static func shouldPreventDisplaySleep(isFollowingWatch: Bool, workoutStatus: WorkoutStatus) -> Bool {
        switch workoutStatus {
        case .running, .paused:
            return true
        case .idle:
            return isFollowingWatch
        case .finished:
            return false
        }
    }

    func toggleFollowWatch() {
        if isFollowingWatch {
            stopFollowingWatch()
        } else {
            startFollowingWatch()
        }
    }

    func startFollowingWatch() {
        guard !isFollowingWatch else {
            return
        }

        print("[WATCH SYNC] follow enabled")
        isFollowingWatch = true
        watchSyncStatusText = "Syncing WOD"
        refreshWorkoutHistory(reason: "followWatch")
        refreshLatestWorkout(reason: .followWatch) { [weak self] _ in
            self?.beginWatchSessionFollowing()
        }
    }

    func stopFollowingWatch() {
        watchSessionPollTimer?.invalidate()
        watchSessionPollTimer = nil
        isPollingWatchSession = false

        if isFollowingWatch {
            print("[WATCH SYNC] follow disabled")
        }

        isFollowingWatch = false
        isMirroringWatchSession = false
        watchSyncStatusText = "Follow Watch Off"
    }

    func refreshWatchSession() {
        pollWatchSession()
    }

    private func beginWatchSessionFollowing() {
        guard isFollowingWatch else {
            return
        }

        watchSyncStatusText = "Waiting for Watch"
        pollWatchSession()
        scheduleWatchSessionPolling()
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

    private func scheduleWatchSessionPolling() {
        guard watchSessionPollTimer == nil else {
            return
        }

        watchSessionPollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.pollWatchSession()
        }
    }

    private func pollWatchSession() {
        guard isFollowingWatch else {
            return
        }

        guard !isPollingWatchSession else {
            print("[WATCH SYNC] poll skipped; request already running")
            return
        }

        isPollingWatchSession = true
        workoutSessionClient.fetchWorkoutSession { [weak self] result in
            self?.performOnMain {
                self?.isPollingWatchSession = false
                self?.handleWorkoutSessionResult(result)
            }
        }
    }

    private func handleWorkoutSessionResult(_ result: Result<WorkoutSessionState, WorkoutSessionFetchError>) {
        guard isFollowingWatch else {
            return
        }

        switch result {
        case .success(let state):
            applyWatchSessionState(state)

        case .failure(.notFound):
            if !isMirroringWatchSession {
                watchSyncStatusText = "Waiting for Watch"
            }
            print("[WATCH SYNC] no session available")

        case .failure(let error):
            watchSyncStatusText = isMirroringWatchSession ? "Watch Sync Lost" : "HR Display Ready"
            print("[WATCH SYNC] fetch failed: \(error)")
        }
    }

    private func applyWatchSessionState(_ state: WorkoutSessionState) {
        let currentIdentity = workoutManager.workout.syncIdentity
        guard state.workoutId == currentIdentity else {
            watchSyncStatusText = "Workout Mismatch"
            print("[WATCH SYNC] ignored mismatch incoming=\(state.workoutId) current=\(currentIdentity)")
            return
        }

        guard !state.sessionId.isEmpty else {
            watchSyncStatusText = "Invalid Watch State"
            print("[WATCH SYNC] ignored empty sessionId")
            return
        }

        guard workoutManager.workout.stations.indices.contains(state.stationIndex), state.round >= 1 else {
            watchSyncStatusText = "Invalid Watch State"
            print("[WATCH SYNC] ignored invalid round/index round=\(state.round) station=\(state.stationIndex)")
            return
        }

        guard isFreshWatchSession(state) else {
            watchSyncStatusText = "Watch Session Stale"
            print("[WATCH SYNC] ignored stale session updatedAt=\(state.updatedAt)")
            return
        }

        let isNewSession = state.sessionId != lastAppliedWatchSessionId
        if !isNewSession && state.revision <= lastAppliedWatchRevision {
            print("[WATCH SYNC] ignored old revision session=\(state.sessionId) revision=\(state.revision) last=\(lastAppliedWatchRevision)")
            return
        }

        lastAppliedWatchSessionId = state.sessionId
        lastAppliedWatchRevision = state.revision
        isMirroringWatchSession = state.status != .idle
        watchSyncStatusText = "Following Watch"

        print("[WATCH SYNC] applying session=\(state.sessionId) revision=\(state.revision) status=\(state.status.rawValue) round=\(state.round) station=\(state.stationIndex) elapsed=\(state.elapsedSeconds)")

        workoutManager.applyRemoteSession(
            status: state.status.workoutStatus,
            round: state.round,
            stationIndex: state.stationIndex
        )

        timerManager.applyRemoteSnapshot(
            elapsedSeconds: state.elapsedSeconds,
            isRunning: state.status == .running,
            allowsBackwardAdjustment: isNewSession
        )

        if state.status == .finished {
            latestWorkoutAnalytics = state.analytics
            persistLatestAnalytics(state.analytics)
            if let analytics = state.analytics {
                let session = completedWorkoutSession(from: analytics)
                completedWorkoutHistoryStore.saveSession(session)
                mergeWorkoutHistorySummaries([session.summary])
            }
            captureWorkoutSummaryIfNeeded()
            timerManager.stop()
        }
    }

    private func isFreshWatchSession(_ state: WorkoutSessionState) -> Bool {
        let nowSeconds = Int(Date().timeIntervalSince1970)
        let updatedSeconds = state.updatedAt > 9_999_999_999 ? state.updatedAt / 1000 : state.updatedAt
        return nowSeconds - updatedSeconds <= watchSessionFreshnessSeconds
    }

    private func clearWatchMirrorState() {
        lastAppliedWatchSessionId = nil
        lastAppliedWatchRevision = 0
        isMirroringWatchSession = false
        if isFollowingWatch {
            watchSyncStatusText = "Waiting for Watch"
        }
    }

    private func captureWorkoutSummaryIfNeeded() {
        guard workoutSummary == nil else {
            return
        }

        let station = workoutManager.currentStation
        let summary = WorkoutSummary(
            displayMode: displayMode,
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

    private func handleLatestWorkoutResult(
        _ result: Result<WorkoutContract, LatestWorkoutError>,
        reason: LatestWorkoutRefreshReason
    ) {
        isRefreshingLatestWorkout = false
        let completions = latestWorkoutRefreshCompletions
        latestWorkoutRefreshCompletions = []
        var didApplyWorkout = false
        defer {
            completions.forEach { $0(didApplyWorkout) }
        }

        guard workoutManager.status == .idle else {
            print("[LATEST WOD] \(reason.rawValue) response ignored; status=\(workoutManager.status.rawValue)")
            latestWorkoutStatusText = "Current workout locked"
            return
        }

        switch result {
        case .success(let workout):
            guard shouldApplyLatestWorkout(workout) else {
                print("[LATEST WOD] \(reason.rawValue) unchanged remote=\(workout.latestVersionDescription) current=\(workoutManager.workout.latestVersionDescription)")
                latestWorkoutStatusText = "WEB WOD"
                return
            }

            print("[LATEST WOD] \(reason.rawValue) web response applied remote=\(workout.latestVersionDescription) previous=\(workoutManager.workout.latestVersionDescription) title=\(workout.title) type=\(workout.type.rawValue) stations=\(workout.stations.count)")
            workoutManager.load(workout)
            if workoutCache.saveCachedWorkout(workout) {
                print("[LATEST WOD] cache saved id=\(workout.id)")
            }
            latestWorkoutStatusText = "WEB WOD"
            didApplyWorkout = true

        case .failure(let error):
            print("[LATEST WOD] \(reason.rawValue) refresh failed: \(error)")
            latestWorkoutStatusText = "Refresh failed"
        }
    }

    private func shouldApplyLatestWorkout(_ incomingWorkout: WorkoutContract) -> Bool {
        let currentWorkout = workoutManager.workout
        if incomingWorkout.syncIdentity != currentWorkout.syncIdentity {
            return true
        }

        return normalizedWorkoutTimestamp(incomingWorkout.updatedAt) != normalizedWorkoutTimestamp(currentWorkout.updatedAt)
    }

    private func normalizedWorkoutTimestamp(_ timestamp: String?) -> String {
        timestamp?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func handleWorkoutHistoryResult(
        _ result: Result<CompletedWorkoutHistoryPage, CompletedWorkoutHistoryError>,
        reason: String
    ) {
        isRefreshingWorkoutHistory = false

        switch result {
        case .success(let page):
            mergeWorkoutHistorySummaries(page.items)
            workoutHistoryStatusText = workoutHistory.isEmpty ? "No saved workouts" : "History updated"
            print("[HISTORY] \(reason) refresh applied count=\(page.items.count)")

        case .failure(let error):
            workoutHistoryStatusText = workoutHistory.isEmpty ? "History unavailable" : "Showing cached history"
            print("[HISTORY] \(reason) refresh failed: \(error)")
        }
    }

    private func mergeWorkoutHistorySummaries(_ summaries: [CompletedWorkoutSummary]) {
        let merged = sortedDedupedSummaries(workoutHistory + summaries)
        workoutHistory = merged
        completedWorkoutHistoryStore.saveSummaries(merged)
    }

    private func migrateLatestAnalyticsIntoHistoryIfNeeded() {
        guard let latestWorkoutAnalytics else {
            return
        }

        let session = completedWorkoutSession(from: latestWorkoutAnalytics)
        if completedWorkoutHistoryStore.loadSession(sessionId: session.sessionId) == nil {
            completedWorkoutHistoryStore.saveSession(session)
        }
        mergeWorkoutHistorySummaries([session.summary])
    }

    private func completedWorkoutSession(from analytics: WorkoutAnalytics) -> CompletedWorkoutSession {
        CompletedWorkoutSession(
            schemaVersion: analytics.schemaVersion,
            sessionId: analytics.sessionId,
            workoutIdentity: analytics.workoutId,
            workoutName: analytics.workoutName,
            startedAt: analytics.startedAt,
            finishedAt: analytics.finishedAt,
            totalActiveMs: analytics.totalActiveSeconds.map { $0 * 1000 },
            totalActiveSeconds: analytics.totalActiveSeconds,
            roundsCompleted: analytics.roundsCompleted,
            status: "completed",
            events: analytics.events,
            analytics: analytics,
            source: CompletedWorkoutSource(device: "watch", appVersion: nil, deviceModel: nil),
            archivedAt: nil
        )
    }

    private func performOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private static func loadPersistedAnalytics(storageKey: String) -> WorkoutAnalytics? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(WorkoutAnalytics.self, from: data)
        } catch {
            print("[ANALYTICS] persisted analytics decode failed: \(error)")
            return nil
        }
    }

    private func persistLatestAnalytics(_ analytics: WorkoutAnalytics?) {
        guard let analytics else {
            UserDefaults.standard.removeObject(forKey: analyticsStorageKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(analytics)
            UserDefaults.standard.set(data, forKey: analyticsStorageKey)
        } catch {
            print("[ANALYTICS] persist failed: \(error)")
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
