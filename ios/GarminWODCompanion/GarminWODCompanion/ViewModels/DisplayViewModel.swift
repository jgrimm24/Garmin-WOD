import Foundation

final class DisplayViewModel: ObservableObject {
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    let heartRateManager: MockHeartRateManager

    @Published private(set) var workoutSummary: WorkoutSummary?

    private var zoneTimer: Timer?

    init(
        workoutManager: WorkoutManager = WorkoutManager(),
        timerManager: TimerManager = TimerManager(),
        heartRateManager: MockHeartRateManager = MockHeartRateManager()
    ) {
        self.workoutManager = workoutManager
        self.timerManager = timerManager
        self.heartRateManager = heartRateManager
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
        workoutSummary = nil
        logState("resetWorkout after")
        print("[RESET] after status=\(workoutManager.status.rawValue)")
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

            self.heartRateManager.tickZoneTimeIfWorkoutRunning()
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
            averageHeartRate: heartRateManager.averageHeartRate,
            maximumHeartRate: heartRateManager.maximumHeartRate,
            zone1Seconds: heartRateManager.zoneTimes[1, default: 0],
            zone2Seconds: heartRateManager.zoneTimes[2, default: 0],
            zone3Seconds: heartRateManager.zoneTimes[3, default: 0],
            zone4Seconds: heartRateManager.zoneTimes[4, default: 0],
            zone5Seconds: heartRateManager.zoneTimes[5, default: 0],
            caloriesBurned: nil,
            finalRound: workoutManager.currentRound,
            finalStationIndex: workoutManager.currentStationIndex,
            finalMovementName: station?.displayName ?? "None",
            finishedAt: Date()
        )

        workoutSummary = summary
        print("[SUMMARY] captured elapsed=\(summary.elapsedSeconds) avgHR=\(summary.averageHeartRate) maxHR=\(summary.maximumHeartRate) movement=\(summary.finalMovementName)")
    }
}
