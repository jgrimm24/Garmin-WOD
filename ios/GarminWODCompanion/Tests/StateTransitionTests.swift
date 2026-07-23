import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("[TEST] FAIL: \(message)")
        exit(1)
    }
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

print("[TEST] reset")
viewModel.resetWorkout()
expect(viewModel.workoutManager.status == .idle, "reset should set idle")
expect(viewModel.workoutManager.currentStationIndex == 0, "reset should restore station 0")
expect(viewModel.workoutManager.currentRound == 1, "reset should restore round 1")
expect(viewModel.timerManager.elapsedSeconds == 0, "reset should clear elapsed seconds")
expect(!viewModel.timerManager.isRunning, "reset should stop timer")

print("[TEST] mock heart-rate update")
viewModel.heartRateManager.setSimulatedHeartRate(155)
expect(viewModel.heartRateManager.currentHeartRate == 155, "mock HR should update to requested value")
expect(viewModel.heartRateManager.currentZone.id == 4, "mock HR 155 should be zone 4")
expect(viewModel.heartRateManager.maximumHeartRate >= 155, "mock HR update should affect max HR")

print("[TEST] PASS: DisplayViewModel state transitions")
