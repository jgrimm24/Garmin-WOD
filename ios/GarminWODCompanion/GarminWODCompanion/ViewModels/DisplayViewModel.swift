import Combine
import Foundation

final class DisplayViewModel: ObservableObject {
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    let heartRateManager: MockHeartRateManager

    private var zoneTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(
        workoutManager: WorkoutManager = WorkoutManager(),
        timerManager: TimerManager = TimerManager(),
        heartRateManager: MockHeartRateManager = MockHeartRateManager()
    ) {
        self.workoutManager = workoutManager
        self.timerManager = timerManager
        self.heartRateManager = heartRateManager
        relayManagerChanges()
        scheduleZoneTimer()
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
        timerManager.stop()
        logState("finishWorkout after")
    }

    func reset() {
        resetWorkout()
    }

    func resetWorkout() {
        print("[VM] resetWorkout called")
        logState("resetWorkout before")
        workoutManager.reset()
        timerManager.reset()
        heartRateManager.resetMetrics()
        logState("resetWorkout after")
    }

    func logLayout(width: Double, height: Double, isLandscape: Bool) {
        print("[LAYOUT] width=\(Int(width)) height=\(Int(height)) selected=\(isLandscape ? "landscape" : "portrait")")
        logState("layout")
    }

    func logState(_ prefix: String) {
        print("[STATE] \(prefix): status=\(workoutManager.status.rawValue) stationIndex=\(workoutManager.currentStationIndex) round=\(workoutManager.currentRound) timerRunning=\(timerManager.isRunning) elapsed=\(timerManager.elapsedSeconds)")
    }

    private func relayManagerChanges() {
        workoutManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        timerManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        heartRateManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
}
