import SwiftUI

#if DEBUG
struct DebugControlHarnessView: View {
    @StateObject private var viewModel = DisplayViewModel()

    var body: some View {
        DebugControlHarnessContent(
            viewModel: viewModel,
            workoutManager: viewModel.workoutManager,
            timerManager: viewModel.timerManager,
            heartRateManager: viewModel.heartRateManager
        )
    }
}

private struct DebugControlHarnessContent: View {
    let viewModel: DisplayViewModel
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var heartRateManager: MockHeartRateManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Control Harness")
                .font(.headline)

            Text(workoutManager.status.rawValue.uppercased())
                .font(.title.bold())

            Text("Station \(workoutManager.currentStationIndex) Round \(workoutManager.currentRound)")
                .monospacedDigit()

            Text("Elapsed \(timerManager.elapsedTimeText) HR \(heartRateManager.currentHeartRate)")
                .monospacedDigit()

            HStack {
                Button(viewModel.primaryActionTitle) {
                    print("[HARNESS] \(viewModel.primaryActionTitle) tapped")
                    viewModel.primaryAction()
                }

                Button("Back") {
                    print("[HARNESS] Back tapped")
                    viewModel.previousStation()
                }

                Button("Next") {
                    print("[HARNESS] Next tapped")
                    viewModel.nextStation()
                }

                Button("Finish") {
                    print("[HARNESS] Finish tapped")
                    viewModel.finishWorkout()
                }

                Button("Reset") {
                    print("[HARNESS] Reset tapped")
                    viewModel.resetWorkout()
                }

                Button("+ HR") {
                    print("[HARNESS] + HR tapped")
                    heartRateManager.increaseHeartRate()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
#endif
