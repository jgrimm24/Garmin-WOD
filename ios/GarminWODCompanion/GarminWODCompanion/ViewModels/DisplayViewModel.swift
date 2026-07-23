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
    }

    func startWorkout() {
        print("[VM] startWorkout called")
        workoutManager.start()
        timerManager.start()
    }

    func pauseWorkout() {
        print("[VM] pauseWorkout called")
        workoutManager.pause()
        timerManager.pause()
    }

    func resumeWorkout() {
        print("[VM] resumeWorkout called")
        workoutManager.resume()
        timerManager.resume()
    }

    func back() {
        previousStation()
    }

    func next() {
        nextStation()
    }

    func previousStation() {
        print("[VM] previousStation called")
        workoutManager.goBack()
    }

    func nextStation() {
        print("[VM] nextStation called")
        workoutManager.advance()
        if workoutManager.status == .finished {
            timerManager.stop()
        }
    }

    func finish() {
        finishWorkout()
    }

    func finishWorkout() {
        print("[VM] finishWorkout called")
        workoutManager.finish()
        timerManager.stop()
    }

    func reset() {
        resetWorkout()
    }

    func resetWorkout() {
        print("[VM] resetWorkout called")
        workoutManager.reset()
        timerManager.reset()
        heartRateManager.resetMetrics()
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
