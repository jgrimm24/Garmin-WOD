import SwiftUI

#if DEBUG
struct DebugControlHarnessView: View {
    @StateObject private var viewModel = DisplayViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Control Harness")
                .font(.headline)

            Text(viewModel.workoutManager.status.rawValue.uppercased())
                .font(.title.bold())

            Text("Station \(viewModel.workoutManager.currentStationIndex) Round \(viewModel.workoutManager.currentRound)")
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
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
#endif
