import SwiftUI

struct GymDisplayView: View {
    @StateObject private var viewModel = DisplayViewModel()

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let metrics = DashboardMetrics(size: geometry.size, isLandscape: isLandscape)

            ZStack(alignment: .bottom) {
                zoneBackground
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(0)

                Group {
                    if isLandscape {
                        landscapeLayout(metrics: metrics)
                    } else {
                        portraitLayout(metrics: metrics)
                    }
                }
                .padding(metrics.outerPadding)
                .padding(.bottom, metrics.controlAreaHeight)
                .zIndex(1)

                ControlBar(
                    viewModel: viewModel,
                    metrics: metrics,
                    isLandscape: isLandscape
                )
                .padding(.horizontal, metrics.outerPadding)
                .padding(.bottom, metrics.outerPadding)
                .zIndex(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var zoneBackground: LinearGradient {
        let zoneColor = viewModel.heartRateManager.currentZone.color
        return LinearGradient(
            colors: [
                Color.black,
                zoneColor.opacity(0.42),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func portraitLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workout: viewModel.workoutManager.workout,
                status: viewModel.workoutManager.status,
                metrics: metrics
            )

            ScrollView {
                VStack(spacing: metrics.sectionSpacing) {
                    HeartRatePanel(
                        manager: viewModel.heartRateManager,
                        metrics: metrics,
                        isCompact: true
                    )

                    WorkoutPanel(
                        workoutManager: viewModel.workoutManager,
                        timerManager: viewModel.timerManager,
                        metrics: metrics,
                        isLandscape: false
                    )
                }
                .padding(.bottom, 2)
            }
            .scrollIndicators(.hidden)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapeLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workout: viewModel.workoutManager.workout,
                status: viewModel.workoutManager.status,
                metrics: metrics
            )

            HStack(spacing: metrics.sectionSpacing) {
                HeartRatePanel(
                    manager: viewModel.heartRateManager,
                    metrics: metrics,
                    isCompact: false
                )
                .frame(width: metrics.availableWidth * 0.38)

                WorkoutPanel(
                    workoutManager: viewModel.workoutManager,
                    timerManager: viewModel.timerManager,
                    metrics: metrics,
                    isLandscape: true
                )
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DashboardMetrics {
    let size: CGSize
    let isLandscape: Bool

    var availableWidth: CGFloat {
        size.width - (outerPadding * 2)
    }

    var outerPadding: CGFloat {
        isLandscape ? 18 : 14
    }

    var cardPadding: CGFloat {
        isLandscape ? 18 : 14
    }

    var sectionSpacing: CGFloat {
        isLandscape ? 14 : 12
    }

    var headerTitleSize: CGFloat {
        isLandscape ? clamp(size.width * 0.038, min: 24, max: 42) : clamp(size.width * 0.08, min: 26, max: 36)
    }

    var headerMetaSize: CGFloat {
        isLandscape ? clamp(size.width * 0.019, min: 14, max: 20) : 15
    }

    var heartRateSize: CGFloat {
        if isLandscape {
            return clamp(size.height * 0.23, min: 76, max: 132)
        }

        return clamp(size.height * 0.12, min: 68, max: 104)
    }

    var zoneSize: CGFloat {
        isLandscape ? clamp(size.height * 0.055, min: 22, max: 34) : 22
    }

    var timerSize: CGFloat {
        if isLandscape {
            return clamp(size.height * 0.17, min: 56, max: 104)
        }

        return clamp(size.height * 0.075, min: 40, max: 64)
    }

    var currentMovementSize: CGFloat {
        isLandscape ? clamp(size.height * 0.07, min: 28, max: 44) : 27
    }

    var secondaryMovementSize: CGFloat {
        isLandscape ? clamp(size.height * 0.045, min: 20, max: 28) : 20
    }

    var controlFontSize: CGFloat {
        isLandscape ? clamp(size.width * 0.018, min: 15, max: 21) : 17
    }

    var controlHeight: CGFloat {
        isLandscape ? clamp(size.height * 0.075, min: 44, max: 58) : 48
    }

    var controlAreaHeight: CGFloat {
        if isLandscape {
            return controlHeight + outerPadding + 8
        }

        return (controlHeight * 2) + outerPadding + 22
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}

private struct HeaderView: View {
    let workout: WorkoutContract
    let status: WorkoutStatus
    let metrics: DashboardMetrics

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.system(size: metrics.headerTitleSize, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(workout.type.rawValue.uppercased())
                    .font(.system(size: metrics.headerMetaSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text("MOCK HR")
                    .font(.system(size: metrics.headerMetaSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                    .lineLimit(1)

                Text(status.rawValue.uppercased())
                    .font(.system(size: metrics.headerMetaSize, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeartRatePanel: View {
    @ObservedObject var manager: MockHeartRateManager
    let metrics: DashboardMetrics
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 10 : 12) {
            Text("\(manager.currentHeartRate)")
                .font(.system(size: metrics.heartRateSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            Text(manager.currentZone.name.uppercased())
                .font(.system(size: metrics.zoneSize, weight: .black, design: .rounded))
                .foregroundStyle(manager.currentZone.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 10) {
                MetricTile(title: "Avg HR", value: "\(manager.averageHeartRate)", metrics: metrics)
                MetricTile(title: "Max HR", value: "\(manager.maximumHeartRate)", metrics: metrics)
            }

            if !isCompact {
                ZoneTimeSummary(manager: manager, metrics: metrics)
            } else {
                ViewThatFits {
                    ZoneTimeSummary(manager: manager, metrics: metrics)
                    EmptyView()
                }
            }

            MockControls(manager: manager, metrics: metrics)
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

private struct WorkoutPanel: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var timerManager: TimerManager
    let metrics: DashboardMetrics
    let isLandscape: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isLandscape ? 14 : 12) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Elapsed")
                        .font(.system(size: metrics.headerMetaSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Text(timerManager.elapsedTimeText)
                        .font(.system(size: metrics.timerSize, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                }

                Spacer(minLength: 10)

                Text(workoutManager.roundText)
                    .font(.system(size: isLandscape ? 26 : 20, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white.opacity(0.88))
            }

            movementBlock(
                label: "Current",
                station: workoutManager.currentStation,
                titleSize: metrics.currentMovementSize,
                detailSize: isLandscape ? 24 : 19
            )

            movementBlock(
                label: "Next",
                station: workoutManager.nextStation,
                titleSize: metrics.secondaryMovementSize,
                detailSize: isLandscape ? 20 : 17
            )

            Spacer(minLength: 0)
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private func movementBlock(label: String, station: WorkoutStation?, titleSize: CGFloat, detailSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)

            Text(station?.displayName ?? "None")
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: true)

            Text(station?.prescriptionText ?? "")
                .font(.system(size: detailSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: metrics.isLandscape ? 15 : 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            Text(value)
                .font(.system(size: metrics.isLandscape ? 31 : 26, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, metrics.isLandscape ? 12 : 9)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ZoneTimeSummary: View {
    @ObservedObject var manager: MockHeartRateManager
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: metrics.isLandscape ? 7 : 5) {
            ForEach(manager.zoneTimeSummary, id: \.zone.id) { item in
                HStack(spacing: 8) {
                    Text(item.zone.name)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(format(seconds: item.seconds))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .font(.system(size: metrics.isLandscape ? 14 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(item.zone.color.opacity(item.seconds > 0 ? 1 : 0.58))
            }
        }
        .padding(metrics.isLandscape ? 12 : 10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func format(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct MockControls: View {
    @ObservedObject var manager: MockHeartRateManager
    let metrics: DashboardMetrics

    var body: some View {
        HStack(spacing: 10) {
            Button("- HR") {
                print("[UI] - HR tapped")
                manager.decreaseHeartRate()
            }
            .buttonStyle(DashboardButtonStyle(kind: .secondary, metrics: metrics))

            Toggle("Demo", isOn: $manager.isDemoModeEnabled)
                .toggleStyle(.switch)
                .font(.system(size: metrics.isLandscape ? 15 : 14, weight: .bold))
                .lineLimit(1)
                .fixedSize()

            Button("+ HR") {
                print("[UI] + HR tapped")
                manager.increaseHeartRate()
            }
            .buttonStyle(DashboardButtonStyle(kind: .secondary, metrics: metrics))
        }
    }
}

private struct ControlBar: View {
    @ObservedObject var viewModel: DisplayViewModel
    let metrics: DashboardMetrics
    let isLandscape: Bool

    private var controls: [(String, DashboardButtonKind, () -> Void)] {
        switch viewModel.workoutManager.status {
        case .idle:
            return [
                ("Start", .primary, primaryAction),
                ("Back", .secondary, previousStation),
                ("Next", .secondary, nextStation),
                ("Finish", .warning, finishWorkout),
                ("Reset", .secondary, resetWorkout)
            ]
        case .running:
            return [
                ("Pause", .primary, primaryAction),
                ("Back", .secondary, previousStation),
                ("Next", .secondary, nextStation),
                ("Finish", .warning, finishWorkout),
                ("Reset", .secondary, resetWorkout)
            ]
        case .paused:
            return [
                ("Resume", .primary, primaryAction),
                ("Back", .secondary, previousStation),
                ("Next", .secondary, nextStation),
                ("Finish", .warning, finishWorkout),
                ("Reset", .secondary, resetWorkout)
            ]
        case .finished:
            return [
                ("Reset", .primary, resetWorkout)
            ]
        }
    }

    var body: some View {
        if isLandscape {
            HStack(spacing: 10) {
                ForEach(Array(controls.enumerated()), id: \.offset) { _, control in
                    Button(control.0, action: control.2)
                        .buttonStyle(DashboardButtonStyle(kind: control.1, metrics: metrics))
                        .contentShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(Array(controls.enumerated()), id: \.offset) { _, control in
                    Button(control.0, action: control.2)
                        .buttonStyle(DashboardButtonStyle(kind: control.1, metrics: metrics))
                        .contentShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func primaryAction() {
        print("[UI] \(viewModel.primaryActionTitle) tapped")
        viewModel.primaryAction()
    }

    private func previousStation() {
        print("[UI] Back tapped")
        viewModel.previousStation()
    }

    private func nextStation() {
        print("[UI] Next tapped")
        viewModel.nextStation()
    }

    private func finishWorkout() {
        print("[UI] Finish tapped")
        viewModel.finishWorkout()
    }

    private func resetWorkout() {
        print("[UI] Reset tapped")
        viewModel.resetWorkout()
    }
}

private enum DashboardButtonKind {
    case primary
    case secondary
    case warning
}

private struct DashboardButtonStyle: ButtonStyle {
    let kind: DashboardButtonKind
    let metrics: DashboardMetrics

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: metrics.controlFontSize, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? .black : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(maxWidth: .infinity, minHeight: metrics.controlHeight)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background(background.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(kind == .secondary ? 0.22 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }

    private var background: Color {
        switch kind {
        case .primary:
            return .yellow
        case .secondary:
            return .white.opacity(0.1)
        case .warning:
            return .red.opacity(0.78)
        }
    }
}
