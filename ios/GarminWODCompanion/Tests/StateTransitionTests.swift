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

print("[TEST] PASS: DisplayViewModel state transitions")
