import SwiftUI

struct GymDisplayView: View {
    @StateObject private var viewModel = DisplayViewModel()

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let metrics = DashboardMetrics(size: geometry.size, isLandscape: isLandscape)

            ZStack {
                ZoneBackground(manager: viewModel.heartRateManager)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(0)

                Group {
                    if viewModel.workoutManager.status == .finished, let summary = viewModel.workoutSummary {
                        WorkoutSummaryScreen(
                            summary: summary,
                            metrics: metrics,
                            isLandscape: isLandscape
                        ) {
                            print("[UI] New Workout tapped")
                            viewModel.resetWorkout()
                        }
                    } else {
                        VStack(spacing: metrics.sectionSpacing) {
                            if isLandscape {
                                landscapeLayout(metrics: metrics)
                            } else {
                                portraitLayout(metrics: metrics)
                            }

                            ControlBar(
                                viewModel: viewModel,
                                workoutManager: viewModel.workoutManager,
                                metrics: metrics,
                                isLandscape: isLandscape
                            )
                        }
                    }
                }
                .padding(metrics.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1)
            }
            .onAppear {
                viewModel.logLayout(width: geometry.size.width, height: geometry.size.height, isLandscape: isLandscape)
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.logLayout(width: newSize.width, height: newSize.height, isLandscape: newSize.width > newSize.height)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func portraitLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
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
                workoutManager: viewModel.workoutManager,
                metrics: metrics
            )

            HStack(spacing: metrics.sectionSpacing) {
                HeartRatePanel(
                    manager: viewModel.heartRateManager,
                    metrics: metrics,
                    isCompact: true
                )
                .frame(width: metrics.availableWidth * 0.34)
                .frame(maxHeight: .infinity)

                WorkoutPanel(
                    workoutManager: viewModel.workoutManager,
                    timerManager: viewModel.timerManager,
                    metrics: metrics,
                    isLandscape: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ZoneBackground: View {
    @ObservedObject var manager: MockHeartRateManager

    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                manager.currentZone.color.opacity(0.42),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DashboardMetrics {
    let size: CGSize
    let isLandscape: Bool

    var availableWidth: CGFloat {
        size.width - (outerPadding * 2)
    }

    var outerPadding: CGFloat {
        isLandscape ? 10 : 14
    }

    var cardPadding: CGFloat {
        isLandscape ? 10 : 14
    }

    var sectionSpacing: CGFloat {
        isLandscape ? 8 : 12
    }

    var headerTitleSize: CGFloat {
        isLandscape ? clamp(size.height * 0.058, min: 20, max: 28) : clamp(size.width * 0.08, min: 26, max: 36)
    }

    var headerMetaSize: CGFloat {
        isLandscape ? clamp(size.height * 0.035, min: 12, max: 15) : 15
    }

    var heartRateSize: CGFloat {
        if isLandscape {
            return clamp(size.height * 0.18, min: 56, max: 82)
        }

        return clamp(size.height * 0.12, min: 68, max: 104)
    }

    var zoneSize: CGFloat {
        isLandscape ? clamp(size.height * 0.042, min: 16, max: 22) : 22
    }

    var timerSize: CGFloat {
        if isLandscape {
            return clamp(size.height * 0.12, min: 42, max: 62)
        }

        return clamp(size.height * 0.075, min: 40, max: 64)
    }

    var currentMovementSize: CGFloat {
        isLandscape ? clamp(size.height * 0.052, min: 20, max: 30) : 27
    }

    var secondaryMovementSize: CGFloat {
        isLandscape ? clamp(size.height * 0.038, min: 16, max: 22) : 20
    }

    var controlFontSize: CGFloat {
        isLandscape ? clamp(size.height * 0.036, min: 13, max: 16) : 17
    }

    var controlHeight: CGFloat {
        isLandscape ? clamp(size.height * 0.07, min: 40, max: 46) : 48
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}

private struct HeaderView: View {
    @ObservedObject var workoutManager: WorkoutManager
    let metrics: DashboardMetrics

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workoutManager.workout.title)
                    .font(.system(size: metrics.headerTitleSize, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(workoutManager.workout.type.rawValue.uppercased())
                    .font(.system(size: metrics.headerMetaSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                Text("DEBUG status: \(workoutManager.status.rawValue)")
                    .font(.system(size: max(metrics.headerMetaSize - 3, 10), weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan.opacity(0.82))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text("MOCK HR")
                    .font(.system(size: metrics.headerMetaSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                    .lineLimit(1)

                Text(workoutManager.status.rawValue.uppercased())
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
        VStack(spacing: metrics.isLandscape ? 6 : (isCompact ? 10 : 12)) {
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
                    if !metrics.isLandscape {
                        ZoneTimeSummary(manager: manager, metrics: metrics)
                    }
                    EmptyView()
                }
            }

            MockControls(manager: manager, metrics: metrics)
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: metrics.isLandscape ? .infinity : nil)
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
        VStack(alignment: .leading, spacing: isLandscape ? 8 : 12) {
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
                    .font(.system(size: isLandscape ? 18 : 20, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white.opacity(0.88))
            }

            movementBlock(
                label: "Current",
                station: workoutManager.currentStation,
                titleSize: metrics.currentMovementSize,
                detailSize: isLandscape ? 17 : 19
            )

            movementBlock(
                label: "Next",
                station: workoutManager.nextStation,
                titleSize: metrics.secondaryMovementSize,
                detailSize: isLandscape ? 15 : 17
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
                .font(.system(size: metrics.isLandscape ? 12 : 15, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)

            Text(station?.displayName ?? "None")
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .lineLimit(metrics.isLandscape ? 1 : 2)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: true)

            Text(station?.prescriptionText ?? "")
                .font(.system(size: detailSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(metrics.isLandscape ? 1 : 2)
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
                .font(.system(size: metrics.isLandscape ? 12 : 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            Text(value)
                .font(.system(size: metrics.isLandscape ? 22 : 26, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, metrics.isLandscape ? 7 : 9)
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
                .font(.system(size: metrics.isLandscape ? 12 : 14, weight: .bold))
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

private struct WorkoutSummaryScreen: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics
    let isLandscape: Bool
    let onNewWorkout: () -> Void

    var body: some View {
        if isLandscape {
            landscapeSummary
        } else {
            portraitSummary
        }
    }

    private var portraitSummary: some View {
        VStack(spacing: summarySpacing) {
            ScrollView {
                VStack(spacing: summarySpacing) {
                    summaryHeader

                    Text(summary.elapsedTimeText)
                        .font(.system(size: clamp(metrics.size.height * 0.11, min: 64, max: 104), weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        SummaryMetricCard(title: "Avg HR", value: "\(summary.averageHeartRate)", metrics: metrics)
                        SummaryMetricCard(title: "Max HR", value: "\(summary.maximumHeartRate)", metrics: metrics)
                        SummaryMetricCard(title: "Calories", value: summary.caloriesText, metrics: metrics)
                    }

                    SummaryZoneBreakdown(summary: summary, metrics: metrics)
                    SummaryProgressCard(summary: summary, metrics: metrics)
                }
                .padding(.bottom, metrics.sectionSpacing)
            }
            .scrollIndicators(.hidden)

            newWorkoutButton
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var landscapeSummary: some View {
        VStack(spacing: summarySpacing) {
            summaryHeader

            HStack(spacing: summarySpacing) {
                VStack(spacing: summarySpacing) {
                    Text(summary.elapsedTimeText)
                        .font(.system(size: clamp(metrics.size.height * 0.2, min: 70, max: 112), weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: summarySpacing) {
                        SummaryMetricCard(title: "Avg HR", value: "\(summary.averageHeartRate)", metrics: metrics)
                        SummaryMetricCard(title: "Max HR", value: "\(summary.maximumHeartRate)", metrics: metrics)
                        SummaryMetricCard(title: "Calories", value: summary.caloriesText, metrics: metrics)
                    }
                }
                .padding(summaryCardPadding)
                .frame(width: metrics.availableWidth * 0.52)
                .frame(maxHeight: .infinity)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .overlay(summaryBorder)

                VStack(spacing: summarySpacing) {
                    SummaryZoneBreakdown(summary: summary, metrics: metrics)
                    SummaryProgressCard(summary: summary, metrics: metrics)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            newWorkoutButton
                .frame(maxWidth: metrics.availableWidth * 0.82)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryHeader: some View {
        VStack(spacing: 4) {
            Text("Workout Complete")
                .font(.system(size: metrics.headerTitleSize * 0.86, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text("\(summary.workoutName) • \(summary.workoutType.rawValue)")
                .font(.system(size: metrics.headerMetaSize * 0.96, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity)
    }

    private var newWorkoutButton: some View {
        Button("New Workout") {
            onNewWorkout()
        }
        .buttonStyle(DashboardButtonStyle(kind: .primary, metrics: metrics))
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
    }

    private var summaryBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(.white.opacity(0.12), lineWidth: 1)
            .allowsHitTesting(false)
    }

    private var summarySpacing: CGFloat {
        metrics.isLandscape ? max(metrics.sectionSpacing - 1, 6) : max(metrics.sectionSpacing - 2, 8)
    }

    private var summaryCardPadding: CGFloat {
        metrics.isLandscape ? max(metrics.cardPadding - 2, 8) : metrics.cardPadding
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: metrics.isLandscape ? 13 : 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            Text(value)
                .font(.system(size: metrics.isLandscape ? 24 : 26, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, metrics.isLandscape ? 8 : 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryZoneBreakdown: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 8 : 10) {
            Text("HR Zone Time")
                .font(.system(size: metrics.headerMetaSize, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)

            ForEach(summary.zoneTimes, id: \.label) { item in
                HStack(spacing: 10) {
                    Text(item.label)
                    Spacer(minLength: 8)
                    Text(WorkoutSummary.format(seconds: item.seconds))
                        .monospacedDigit()
                }
                .font(.system(size: metrics.isLandscape ? 15 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(1)
            }
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: metrics.isLandscape ? .infinity : nil, alignment: .leading)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

private struct SummaryProgressCard: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 7 : 8) {
            Text("Final Progress")
                .font(.system(size: metrics.headerMetaSize, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)

            summaryLine(title: "Round", value: "\(summary.finalRound)")
            summaryLine(title: "Station", value: "\(summary.finalStationIndex + 1)")
            if summary.finalMovementName != "None" {
                summaryLine(title: "Movement", value: summary.finalMovementName)
            }
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private func summaryLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.white.opacity(0.62))
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .lineLimit(metrics.isLandscape ? 1 : 2)
                .minimumScaleFactor(0.55)
        }
        .font(.system(size: metrics.isLandscape ? 15 : 16, weight: .bold, design: .rounded))
    }
}

private struct ControlBar: View {
    let viewModel: DisplayViewModel
    @ObservedObject var workoutManager: WorkoutManager
    let metrics: DashboardMetrics
    let isLandscape: Bool

    private var controls: [DashboardControl] {
        switch workoutManager.status {
        case .idle:
            return [
                DashboardControl(label: "Start", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Back", kind: .secondary, action: .back, isEnabled: false),
                DashboardControl(label: "Next", kind: .secondary, action: .next, isEnabled: false),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: false),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .running:
            return [
                DashboardControl(label: "Pause", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Back", kind: .secondary, action: .back, isEnabled: true),
                DashboardControl(label: "Next", kind: .secondary, action: .next, isEnabled: true),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: true),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .paused:
            return [
                DashboardControl(label: "Resume", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Back", kind: .secondary, action: .back, isEnabled: true),
                DashboardControl(label: "Next", kind: .secondary, action: .next, isEnabled: true),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: true),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .finished:
            return [
                DashboardControl(label: "Reset", kind: .primary, action: .reset, isEnabled: true)
            ]
        }
    }

    var body: some View {
        if isLandscape {
            HStack(spacing: 10) {
                ForEach(controls) { control in
                    Button(control.label) {
                        handle(control)
                    }
                        .buttonStyle(DashboardButtonStyle(kind: control.kind, metrics: metrics))
                        .contentShape(Rectangle())
                        .disabled(!control.isEnabled)
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
                ForEach(controls) { control in
                    Button(control.label) {
                        handle(control)
                    }
                        .buttonStyle(DashboardButtonStyle(kind: control.kind, metrics: metrics))
                        .contentShape(Rectangle())
                        .disabled(!control.isEnabled)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func handle(_ control: DashboardControl) {
        print("[UI] \(control.label) tapped")
        viewModel.logState("ui \(control.label) before")

        switch control.action {
        case .primary:
            viewModel.primaryAction()
        case .back:
            viewModel.previousStation()
        case .next:
            viewModel.nextStation()
        case .finish:
            viewModel.finishWorkout()
        case .reset:
            viewModel.resetWorkout()
        }

        viewModel.logState("ui \(control.label) after")
    }
}

private struct DashboardControl: Identifiable {
    let label: String
    let kind: DashboardButtonKind
    let action: DashboardControlAction
    let isEnabled: Bool

    var id: String {
        "\(label)-\(action)"
    }
}

private enum DashboardControlAction: String {
    case primary
    case back
    case next
    case finish
    case reset
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
            .opacity(configuration.isPressed ? 0.82 : 1)
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
