import Foundation

final class WorkoutManager: ObservableObject {
    @Published private(set) var workout: WorkoutContract
    @Published private(set) var currentStationIndex: Int = 0
    @Published private(set) var currentRound: Int = 1
    @Published private(set) var status: WorkoutStatus = .idle

    init(workout: WorkoutContract = WorkoutContractLoader.loadBundledSample()) {
        self.workout = workout
        print("[LIFECYCLE] WorkoutManager init")
    }

    deinit {
        print("[LIFECYCLE] WorkoutManager deinit")
    }

    var totalRounds: Int? {
        workout.rounds
    }

    var currentStation: WorkoutStation? {
        guard workout.stations.indices.contains(currentStationIndex) else {
            return nil
        }

        return workout.stations[currentStationIndex]
    }

    var nextStation: WorkoutStation? {
        guard !workout.stations.isEmpty else {
            return nil
        }

        let nextIndex = currentStationIndex + 1
        if workout.stations.indices.contains(nextIndex) {
            return workout.stations[nextIndex]
        }

        if shouldContinueToNextRound {
            return workout.stations.first
        }

        return nil
    }

    var roundText: String {
        if let totalRounds {
            return "Round \(currentRound) of \(totalRounds)"
        }

        return "Round \(currentRound)"
    }

    func load(_ workout: WorkoutContract) {
        self.workout = workout
        reset()
    }

    func start() {
        guard status == .idle || status == .finished else {
            return
        }

        if status == .finished {
            reset()
        }

        status = .running
    }

    func pause() {
        guard status == .running else {
            return
        }

        status = .paused
    }

    func resume() {
        guard status == .paused else {
            return
        }

        status = .running
    }

    func advance() {
        guard status == .running || status == .paused else {
            return
        }

        let nextIndex = currentStationIndex + 1
        if workout.stations.indices.contains(nextIndex) {
            currentStationIndex = nextIndex
            return
        }

        if shouldContinueToNextRound {
            currentRound += 1
            currentStationIndex = 0
            return
        }

        finish()
    }

    func goBack() {
        guard status == .running || status == .paused else {
            return
        }

        if currentStationIndex > 0 {
            currentStationIndex -= 1
            return
        }

        if currentRound > 1 {
            currentRound -= 1
            currentStationIndex = max(workout.stations.count - 1, 0)
        }
    }

    func finish() {
        status = .finished
    }

    func reset() {
        print("[RESET] WorkoutManager before status=\(status.rawValue)")
        currentStationIndex = 0
        currentRound = 1
        status = .idle
        print("[RESET] WorkoutManager after status=\(status.rawValue)")
    }

    private var shouldContinueToNextRound: Bool {
        guard let totalRounds else {
            return workout.type == .amrap || workout.type == .emom
        }

        return currentRound < totalRounds
    }
}
