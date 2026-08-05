import SwiftUI
import UIKit

struct GymDisplayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(GymDisplayMode.storageKey) private var displayModeRawValue = GymDisplayMode.defaultMode.rawValue
    @StateObject private var viewModel = DisplayViewModel()
    @State private var isBluetoothSheetPresented = false
    @State private var isAnalyticsSheetPresented = false
    @State private var isHistorySheetPresented = false

    private var displayMode: GymDisplayMode {
        GymDisplayMode(storedValue: displayModeRawValue)
    }

    private var displayModeBinding: Binding<GymDisplayMode> {
        Binding(
            get: { GymDisplayMode(storedValue: displayModeRawValue) },
            set: {
                displayModeRawValue = $0.rawValue
                viewModel.displayMode = $0
            }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let metrics = DashboardMetrics(size: geometry.size, isLandscape: isLandscape)

            ZStack {
                ZoneBackground(
                    viewModel: viewModel,
                    bluetoothManager: viewModel.bluetoothHeartRateManager
                )
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
                            isAnalyticsSheetPresented = true
                        } onNewWorkout: {
                            viewModel.resetWorkout()
                        }
                    } else {
                        if displayMode == .workout {
                            if isLandscape {
                                wodLandscapeLayout(metrics: metrics)
                            } else {
                                wodPortraitLayout(metrics: metrics)
                            }
                        } else {
                            VStack(spacing: metrics.sectionSpacing) {
                                if isLandscape {
                                    landscapeLayout(metrics: metrics)
                                } else {
                                    portraitLayout(metrics: metrics)
                                }

                                CompanionControlDock(
                                    viewModel: viewModel,
                                    bluetoothManager: viewModel.bluetoothHeartRateManager,
                                    metrics: metrics,
                                    displayMode: displayModeBinding,
                                    onHeartRateSettings: {
                                        isBluetoothSheetPresented = true
                                    },
                                    onHistory: {
                                        isHistorySheetPresented = true
                                    }
                                )
                                .frame(height: metrics.companionDockHeight)
                            }
                        }
                    }
                }
                .padding(metrics.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1)
            }
            .onAppear {
                migrateDisplayModePreferenceIfNeeded()
                viewModel.displayMode = displayMode
                viewModel.selectedHeartRateSource = .bluetooth
                viewModel.loadLatestWorkoutIfNeeded()
                viewModel.logLayout(width: geometry.size.width, height: geometry.size.height, isLandscape: isLandscape)
                updateIdleTimer(for: scenePhase)
            }
            .onDisappear {
                setIdleTimerDisabled(false, reason: "view disappeared")
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.logLayout(width: newSize.width, height: newSize.height, isLandscape: newSize.width > newSize.height)
            }
            .onChange(of: scenePhase) { _, newPhase in
                updateIdleTimer(for: newPhase)
                if newPhase == .active {
                    viewModel.refreshLatestWorkoutAfterForeground()
                }
            }
            .onChange(of: viewModel.isFollowingWatch) { _, _ in
                updateIdleTimer(for: scenePhase)
            }
            .onReceive(viewModel.workoutManager.$status) { _ in
                updateIdleTimer(for: scenePhase)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isBluetoothSheetPresented) {
            BluetoothHeartRateSheet(
                viewModel: viewModel,
                manager: viewModel.bluetoothHeartRateManager
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAnalyticsSheetPresented) {
            WorkoutAnalyticsView(analytics: viewModel.latestWorkoutAnalytics)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isHistorySheetPresented) {
            WorkoutHistoryView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func migrateDisplayModePreferenceIfNeeded() {
        let resolvedMode = GymDisplayMode(storedValue: displayModeRawValue)
        guard displayModeRawValue != resolvedMode.rawValue else {
            return
        }

        displayModeRawValue = resolvedMode.rawValue
        print("[DISPLAY MODE] migrated preference to \(resolvedMode.rawValue)")
    }

    private func updateIdleTimer(for scenePhase: ScenePhase) {
        let shouldDisable = scenePhase == .active && viewModel.shouldPreventDisplaySleep
        setIdleTimerDisabled(shouldDisable, reason: "scene=\(scenePhase) preventSleep=\(viewModel.shouldPreventDisplaySleep)")
    }

    private func setIdleTimerDisabled(_ isDisabled: Bool, reason: String) {
        guard UIApplication.shared.isIdleTimerDisabled != isDisabled else {
            return
        }

        UIApplication.shared.isIdleTimerDisabled = isDisabled
        print("[IDLE TIMER] \(isDisabled ? "disabled" : "enabled") \(reason)")
    }

    // MARK: - Layouts

    private func portraitLayout(metrics: DashboardMetrics) -> some View {
        Group {
            switch displayMode {
            case .workout:
                wodPortraitLayout(metrics: metrics)
            case .run:
                runPortraitLayout(metrics: metrics)
            }
        }
    }

    private func landscapeLayout(metrics: DashboardMetrics) -> some View {
        Group {
            switch displayMode {
            case .workout:
                wodLandscapeLayout(metrics: metrics)
            case .run:
                runLandscapeLayout(metrics: metrics)
            }
        }
    }

    private func runPortraitLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                metrics: metrics,
                displayMode: displayMode
            )

            RunDashboardPanel(
                viewModel: viewModel,
                timerManager: viewModel.timerManager,
                metrics: metrics,
                isLandscape: false
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runLandscapeLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                metrics: metrics,
                displayMode: displayMode
            )
            .frame(height: metrics.activeHeaderHeight)

            RunDashboardPanel(
                viewModel: viewModel,
                timerManager: viewModel.timerManager,
                metrics: metrics,
                isLandscape: true
            )
            .frame(width: metrics.availableWidth, height: metrics.activeMainHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: metrics.activeDashboardHeight)
    }

    private func wodPortraitLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.wodScoreboardSpacing) {
            WODScoreboardHeader(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                metrics: metrics,
                displayMode: displayMode
            )
            .frame(height: metrics.wodScoreboardHeaderHeight)

            WODProgressPanel(
                workoutManager: viewModel.workoutManager,
                timerManager: viewModel.timerManager,
                metrics: metrics,
                isLandscape: false
            )
            .frame(width: metrics.availableWidth, height: metrics.wodScoreboardHeroHeight)

            CompanionControlDock(
                viewModel: viewModel,
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                displayMode: displayModeBinding,
                onHeartRateSettings: {
                    isBluetoothSheetPresented = true
                },
                onHistory: {
                    isHistorySheetPresented = true
                }
            )
            .frame(height: metrics.companionDockHeight)
        }
        .frame(width: metrics.availableWidth, height: metrics.availableHeight)
    }

    private func wodLandscapeLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.wodScoreboardSpacing) {
            WODScoreboardHeader(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                metrics: metrics,
                displayMode: displayMode
            )
            .frame(height: metrics.wodScoreboardHeaderHeight)

            WODProgressPanel(
                workoutManager: viewModel.workoutManager,
                timerManager: viewModel.timerManager,
                metrics: metrics,
                isLandscape: true
            )
            .frame(width: metrics.availableWidth, height: metrics.wodScoreboardHeroHeight)

            CompanionControlDock(
                viewModel: viewModel,
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                displayMode: displayModeBinding,
                onHeartRateSettings: {
                    isBluetoothSheetPresented = true
                },
                onHistory: {
                    isHistorySheetPresented = true
                }
            )
            .frame(height: metrics.companionDockHeight)
        }
        .frame(width: metrics.availableWidth, height: metrics.availableHeight)
    }
}

// MARK: - Background

private struct ZoneBackground: View {
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var bluetoothManager: BluetoothHeartRateManager

    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                viewModel.activeCurrentZone.color.opacity(0.38),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Metrics

private struct DashboardMetrics {
    let size: CGSize
    let isLandscape: Bool

    var availableWidth: CGFloat { size.width - (outerPadding * 2) }
    var availableHeight: CGFloat { size.height - (outerPadding * 2) }

    var outerPadding: CGFloat { isLandscape ? 10 : 12 }
    var cardPadding: CGFloat { isLandscape ? 10 : 12 }
    var heartPanelPadding: CGFloat { isLandscape ? 10 : 14 }
    var landscapePanelGap: CGFloat { isLandscape ? 14 : sectionSpacing }

    var landscapePanelWidthBudget: CGFloat { max(availableWidth - landscapePanelGap, 0) }

    // Slightly narrower left panel so right side has more room
    var landscapeHeartPanelWidth: CGFloat { landscapePanelWidthBudget * 0.38 }
    var landscapeWorkoutPanelWidth: CGFloat { max(landscapePanelWidthBudget - landscapeHeartPanelWidth, 0) }

    var activeHeaderHeight: CGFloat { isLandscape ? clamp(availableHeight * 0.13, min: 52, max: 64) : clamp(availableHeight * 0.115, min: 84, max: 104) }
    var activeControlHeight: CGFloat { isLandscape ? clamp(availableHeight * 0.105, min: 46, max: 54) : 112 }
    var companionDockHeight: CGFloat {
        if availableWidth >= 680 {
            return clamp(availableHeight * 0.078, min: 46, max: 58)
        }

        if isLandscape {
            return clamp(availableHeight * 0.12, min: 48, max: 62)
        }

        return clamp(availableHeight * 0.13, min: 74, max: 96)
    }
    var activeDashboardHeight: CGFloat { max(availableHeight - companionDockHeight - sectionSpacing, 0) }
    var activeMainHeight: CGFloat { max(activeDashboardHeight - activeHeaderHeight - sectionSpacing, 0) }
    var wodScoreboardSpacing: CGFloat { isLandscape ? 7 : 9 }
    var wodScoreboardHeaderHeight: CGFloat { isLandscape ? clamp(availableHeight * 0.082, min: 32, max: 44) : clamp(availableHeight * 0.072, min: 46, max: 62) }
    var wodScoreboardControlHeight: CGFloat { isLandscape ? clamp(availableHeight * 0.078, min: 32, max: 42) : clamp(availableHeight * 0.062, min: 42, max: 52) }
    var wodScoreboardHeroHeight: CGFloat { max(availableHeight - wodScoreboardHeaderHeight - companionDockHeight - (wodScoreboardSpacing * 2), 0) }
    var wodLandscapeHeaderHeight: CGFloat { wodScoreboardHeaderHeight }
    var wodLandscapeRailWidth: CGFloat { clamp(availableWidth * 0.095, min: 62, max: 86) }
    var wodLandscapeRailGap: CGFloat { clamp(availableWidth * 0.014, min: 8, max: 14) }
    var wodLandscapeHeroHeight: CGFloat { wodScoreboardHeroHeight }
    var wodLandscapeRailButtonHeight: CGFloat { clamp(availableHeight * 0.11, min: 38, max: 46) }

    func wodLandscapeCenterWidth(followWatchActive: Bool) -> CGFloat {
        let railCount: CGFloat = followWatchActive ? 1 : 2
        let gapCount: CGFloat = followWatchActive ? 1 : 2
        return max(availableWidth - (wodLandscapeRailWidth * railCount) - (wodLandscapeRailGap * gapCount), 0)
    }

    var sectionSpacing: CGFloat { isLandscape ? 10 : 12 }

    var headerTitleSize: CGFloat {
        isLandscape ? clamp(size.height * 0.052, min: 20, max: 26) : clamp(size.width * 0.085, min: 28, max: 38)
    }
    var headerMetaSize: CGFloat { isLandscape ? 13 : 15 }

    var heartRateSize: CGFloat {
        if isLandscape { return clamp(size.height * 0.17, min: 56, max: 78) }
        return clamp(size.height * 0.14, min: 72, max: 110)
    }

    var zoneSize: CGFloat { isLandscape ? 16 : 20 }

    var timerSize: CGFloat {
        if isLandscape { return clamp(size.height * 0.10, min: 36, max: 50) }
        return clamp(size.height * 0.08, min: 42, max: 66)
    }

    var currentMovementSize: CGFloat { isLandscape ? 21 : 26 }
    var secondaryMovementSize: CGFloat { isLandscape ? 16 : 19 }
    var wodCurrentMovementSize: CGFloat {
        isLandscape ? wodScoreboardHeroHeight * 0.52 : wodScoreboardHeroHeight * 0.34
    }
    var wodCurrentPrescriptionSize: CGFloat {
        isLandscape ? clamp(wodScoreboardHeroHeight * 0.09, min: 26, max: 44) : clamp(wodScoreboardHeroHeight * 0.055, min: 22, max: 38)
    }
    var wodNextMovementSize: CGFloat {
        wodCurrentMovementSize * 0.40
    }
    var wodRoundSize: CGFloat {
        isLandscape ? clamp(wodScoreboardHeroHeight * 0.038, min: 14, max: 22) : clamp(wodScoreboardHeroHeight * 0.028, min: 14, max: 20)
    }
    var wodTimerSize: CGFloat {
        isLandscape ? clamp(wodScoreboardHeroHeight * 0.058, min: 22, max: 34) : clamp(wodScoreboardHeroHeight * 0.045, min: 22, max: 32)
    }
    var wodMetaSize: CGFloat {
        isLandscape ? clamp(wodScoreboardHeroHeight * 0.052, min: 18, max: 28) : clamp(wodScoreboardHeroHeight * 0.034, min: 17, max: 25)
    }
    var controlFontSize: CGFloat { isLandscape ? 14 : 16 }
    var controlHeight: CGFloat { isLandscape ? activeControlHeight : 50 }

    // Summary metrics
    var summaryButtonHeight: CGFloat { clamp(availableHeight * 0.062, min: 42, max: 48) }
    var summaryHeaderHeight: CGFloat { clamp(availableHeight * 0.08, min: 44, max: 58) }
    var summaryElapsedHeight: CGFloat { clamp(availableHeight * 0.105, min: 60, max: 82) }
    var summaryMetricHeight: CGFloat { clamp(availableHeight * 0.068, min: 48, max: 58) }
    var summaryProgressHeight: CGFloat { clamp(availableHeight * 0.13, min: 88, max: 112) }
    var summaryZoneHeight: CGFloat {
        max(availableHeight - summaryButtonHeight - summaryHeaderHeight - summaryElapsedHeight - summaryMetricHeight - summaryProgressHeight - (summarySectionSpacing * 6), 0)
    }
    var summarySectionSpacing: CGFloat { isLandscape ? max(sectionSpacing - 1, 6) : 5 }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}

// MARK: - Header

private struct HeaderView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var viewModel: DisplayViewModel
    let metrics: DashboardMetrics
    let displayMode: GymDisplayMode

    var body: some View {
        if metrics.isLandscape {
            landscapeBody
        } else {
            portraitBody
        }
    }

    private var landscapeBody: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryTitle)
                    .font(.system(size: metrics.headerTitleSize, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if !secondaryTitle.isEmpty {
                    Text(secondaryTitle)
                        .font(.system(size: metrics.headerMetaSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                if viewModel.isFollowingWatch {
                    Text(viewModel.watchSyncStatusText.uppercased())
                        .font(.system(size: max(metrics.headerMetaSize - 3, 10), weight: .black, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .layoutPriority(2)

            Spacer(minLength: 6)

            headerStatusBadge
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var portraitBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryTitle)
                        .font(.system(size: metrics.headerTitleSize, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    if !secondaryTitle.isEmpty {
                        Text(secondaryTitle)
                            .font(.system(size: metrics.headerMetaSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                .layoutPriority(2)

                Spacer(minLength: 6)

                headerStatusBadge
            }

            if viewModel.isFollowingWatch {
                HStack {
                    Text(viewModel.watchSyncStatusText.uppercased())
                        .font(.system(size: max(metrics.headerMetaSize - 2, 10), weight: .black, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryTitle: String {
        displayMode == .run ? "RUN" : workoutManager.workout.title
    }

    private var secondaryTitle: String {
        if displayMode == .run {
            return viewModel.isFollowingWatch ? viewModel.watchSyncStatusText.uppercased() : "HEART RATE DASHBOARD"
        }

        if workoutManager.workout.title.caseInsensitiveCompare(workoutManager.workout.type.rawValue) == .orderedSame {
            return ""
        }

        return workoutManager.workout.type.rawValue.uppercased()
    }

    private var headerStatusBadge: some View {
        Text(headerStatusText)
            .font(.system(size: metrics.headerMetaSize, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var headerStatusText: String {
        if viewModel.isFollowingWatch {
            return viewModel.isMirroringWatchSession ? "FOLLOWING WATCH" : viewModel.watchSyncStatusText.uppercased()
        }

        return displayMode.rawValue
    }
}

private struct DisplayModeSelector: View {
    @Binding var displayMode: GymDisplayMode
    let metrics: DashboardMetrics

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GymDisplayMode.allCases, id: \.self) { mode in
                Button {
                    displayMode = mode
                    print("[DISPLAY MODE] selected \(mode.rawValue)")
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: metrics.isLandscape ? 12 : 13, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(displayMode == mode ? .black : .white.opacity(0.82))
                        .frame(width: mode == .workout ? (metrics.isLandscape ? 86 : 92) : 48, height: 30)
                        .background(displayMode == mode ? .yellow : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.white.opacity(0.1), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Companion Control Dock

private struct CompanionControlDock: View {
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var bluetoothManager: BluetoothHeartRateManager
    let metrics: DashboardMetrics
    @Binding var displayMode: GymDisplayMode
    let onHeartRateSettings: () -> Void
    let onHistory: () -> Void

    private var usesSingleRow: Bool {
        metrics.availableWidth >= 520
    }

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if usesSingleRow {
                    HStack(spacing: metrics.isLandscape ? 8 : 10) {
                        dockButtons
                    }
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 6
                    ) {
                        dockButtons
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, metrics.isLandscape ? 8 : 10)
        .padding(.vertical, metrics.isLandscape ? 4 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.22), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var dockButtons: some View {
        CompanionDockButton(
            iconName: "dot.radiowaves.left.and.right",
            title: followTitle,
            isActive: viewModel.isFollowingWatch,
            metrics: metrics,
            action: {
                viewModel.toggleFollowWatch()
            }
        )
        .accessibilityLabel("Follow Watch")
        .accessibilityValue(followAccessibilityValue)
        .accessibilityHint("Toggles watch following using the existing watch sync behavior.")

        CompanionDockButton(
            iconName: "heart.fill",
            title: heartRateTitle,
            isActive: bluetoothManager.connectionState.isConnected,
            metrics: metrics,
            action: onHeartRateSettings
        )
        .accessibilityLabel("Heart Rate")
        .accessibilityValue(heartRateAccessibilityValue)
        .accessibilityHint("Opens heart rate connection settings.")

        CompanionDockButton(
            iconName: "clock.arrow.circlepath",
            title: "History",
            isActive: !viewModel.workoutHistory.isEmpty,
            metrics: metrics,
            action: onHistory
        )
        .accessibilityLabel("Workout History")
        .accessibilityValue(viewModel.workoutHistory.isEmpty ? "No saved workouts loaded" : "\(viewModel.workoutHistory.count) saved workouts")
        .accessibilityHint("Opens saved workout results without changing the active workout.")

        CompanionModeControl(
            displayMode: $displayMode,
            metrics: metrics
        )
        .accessibilityLabel("Display Mode")
        .accessibilityValue(displayMode == .workout ? "Workout" : "Run")
    }

    private var followTitle: String {
        if viewModel.isFollowingWatch {
            if viewModel.isMirroringWatchSession {
                return "Following"
            }

            if viewModel.watchSyncStatusText.localizedCaseInsensitiveContains("lost") {
                return "Reconnect"
            }

            return "Connecting"
        }

        return "Not Following"
    }

    private var followAccessibilityValue: String {
        viewModel.isFollowingWatch ? viewModel.watchSyncStatusText : "Not following"
    }

    private var heartRateTitle: String {
        if let bpm = viewModel.activeHeartRate {
            return "\(bpm)"
        }

        switch bluetoothManager.connectionState {
        case .scanning, .deviceFound, .connecting:
            return "Searching"
        case .connected:
            return "Connected"
        case .failed, .disconnected:
            return "Disconnected"
        default:
            return "Disconnected"
        }
    }

    private var heartRateAccessibilityValue: String {
        if let bpm = viewModel.activeHeartRate {
            return "Receiving \(bpm) beats per minute"
        }

        return bluetoothManager.connectionState.rawValue
    }

}

private struct CompanionDockButton: View {
    let iconName: String
    let title: String
    let isActive: Bool
    let metrics: DashboardMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.isLandscape ? 5 : 7) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .heavy))
                    .foregroundStyle(isActive ? .yellow : .white.opacity(0.7))

                Text(title)
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(isActive ? 0.94 : 0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .padding(.horizontal, metrics.isLandscape ? 7 : 8)
            .frame(maxWidth: .infinity, minHeight: controlHeight)
            .background(isActive ? .white.opacity(0.1) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var controlHeight: CGFloat {
        metrics.availableWidth >= 520 ? 38 : 30
    }

    private var iconSize: CGFloat {
        metrics.availableWidth >= 680 ? 16 : 14
    }

    private var titleSize: CGFloat {
        metrics.availableWidth >= 680 ? 15 : 12
    }
}

private struct CompanionModeControl: View {
    @Binding var displayMode: GymDisplayMode
    let metrics: DashboardMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                ForEach(GymDisplayMode.allCases, id: \.self) { mode in
                    Button {
                        displayMode = mode
                        print("[DISPLAY MODE] selected \(mode.rawValue)")
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: metrics.availableWidth >= 680 ? 13 : 11, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                            .foregroundStyle(displayMode == mode ? .black : .white.opacity(0.82))
                            .frame(maxWidth: .infinity, minHeight: metrics.availableWidth >= 520 ? 34 : 28)
                            .background(displayMode == mode ? .yellow : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: metrics.availableWidth >= 520 ? 38 : 30)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ManualControlsSheet: View {
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var workoutManager: WorkoutManager
    let displayMode: GymDisplayMode

    private var controls: [DashboardControl] {
        if displayMode == .workout {
            return WODCompactControlStrip.controls(
                for: workoutManager.status,
                isFollowingWatch: viewModel.isFollowingWatch,
                isMirroringWatchSession: viewModel.isMirroringWatchSession
            )
        }

        return runControls
    }

    private var runControls: [DashboardControl] {
        if viewModel.isFollowingWatch && viewModel.isMirroringWatchSession {
            return [
                DashboardControl(label: "Stop Follow", kind: .secondary, action: .stopFollowing, isEnabled: true)
            ]
        }

        switch workoutManager.status {
        case .idle:
            return [
                DashboardControl(label: "Start", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: false),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .running:
            return [
                DashboardControl(label: "Pause", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: true),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .paused:
            return [
                DashboardControl(label: "Resume", kind: .primary, action: .primary, isEnabled: true),
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
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Manual controls are preserved for simulator testing and fallback operation. The Garmin watch remains the primary workout controller.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(controls) { control in
                        Button(control.label) {
                            handle(control)
                        }
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(control.kind == .primary ? .black : .white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(buttonBackground(for: control.kind), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(control.kind == .secondary ? 0.14 : 0), lineWidth: 1)
                        )
                        .disabled(!control.isEnabled)
                        .opacity(control.isEnabled ? 1 : 0.42)
                    }
                }

                Spacer()
            }
            .padding(22)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Manual Controls")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func handle(_ control: DashboardControl) {
        switch control.action {
        case .primary: viewModel.primaryAction()
        case .back: viewModel.previousStation()
        case .next: viewModel.nextStation()
        case .finish: viewModel.finishWorkout()
        case .reset: viewModel.resetWorkout()
        case .stopFollowing: viewModel.stopFollowingWatch()
        }
    }

    private func buttonBackground(for kind: DashboardButtonKind) -> Color {
        switch kind {
        case .primary: return .yellow
        case .secondary: return .white.opacity(0.1)
        case .warning: return .red.opacity(0.74)
        }
    }
}

// MARK: - WORKOUT Scoreboard Header

private struct WODScoreboardHeader: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var viewModel: DisplayViewModel
    let metrics: DashboardMetrics
    let displayMode: GymDisplayMode

    var body: some View {
        HStack(alignment: .center, spacing: metrics.isLandscape ? 10 : 7) {
            VStack(alignment: .leading, spacing: 1) {
                Text(workoutManager.workout.title)
                    .font(.system(size: metrics.isLandscape ? 16 : 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(workoutManager.workout.type.rawValue.uppercased())
                    .font(.system(size: metrics.isLandscape ? 10 : 11, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(2)

            Spacer(minLength: 4)

            Text(headerStatusText)
                .font(.system(size: metrics.isLandscape ? 12 : 13, weight: .black, design: .rounded))
                .foregroundStyle(viewModel.isFollowingWatch ? .yellow : .white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .layoutPriority(1)
        }
        .padding(.horizontal, metrics.isLandscape ? 10 : 12)
        .padding(.vertical, metrics.isLandscape ? 5 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var headerStatusText: String {
        if viewModel.isFollowingWatch {
            return viewModel.isMirroringWatchSession ? "FOLLOWING WATCH" : viewModel.watchSyncStatusText.uppercased()
        }

        return displayMode.rawValue
    }
}

// MARK: - WORKOUT Progress Panel

private struct WODProgressPanel: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var timerManager: TimerManager
    let metrics: DashboardMetrics
    let isLandscape: Bool

    var body: some View {
        if isLandscape {
            landscapeBody
        } else {
            portraitBody
        }
    }

    private var landscapeBody: some View {
        GeometryReader { geometry in
            let spacing = max(metrics.wodScoreboardSpacing, 5)
            let verticalPadding = max(metrics.cardPadding - 6, 4)
            let dividerHeight: CGFloat = 1
            let currentLabelHeight = clamp(geometry.size.height * 0.050, min: 13, max: 20)
            let nextLabelHeight = clamp(geometry.size.height * 0.040, min: 11, max: 16)
            let usableHeight = max(geometry.size.height - (verticalPadding * 2) - (spacing * 5) - dividerHeight, 0)
            let progressHeight = clamp(usableHeight * 0.085, min: 24, max: 34)
            let titleHeight = max(usableHeight - progressHeight - currentLabelHeight - nextLabelHeight, 0)
            let currentTitleHeight = titleHeight * 0.76
            let nextTitleHeight = titleHeight * 0.24

            VStack(alignment: .center, spacing: spacing) {
                HStack(alignment: .center, spacing: 12) {
                    progressPill(text: workoutManager.roundText, role: .round)
                    progressPill(text: timerManager.elapsedTimeText, role: .timer)
                }
                .frame(height: progressHeight)

                movementLabel("Current", size: currentLabelHeight)
                    .frame(height: currentLabelHeight)

                WODMovementBlock(
                    station: workoutManager.currentStation,
                    titleSize: metrics.wodCurrentMovementSize,
                    maxTitleLines: 2,
                    isPrimary: true
                )
                .frame(height: currentTitleHeight, alignment: .center)
                .layoutPriority(3)

                Divider()
                    .overlay(.white.opacity(0.1))
                    .frame(height: dividerHeight)

                movementLabel("Next", size: nextLabelHeight)
                    .frame(height: nextLabelHeight)

                WODMovementBlock(
                    station: workoutManager.nextStation,
                    titleSize: metrics.wodNextMovementSize,
                    maxTitleLines: 2,
                    isPrimary: false
                )
                .frame(height: nextTitleHeight, alignment: .center)
                .layoutPriority(2)
            }
            .padding(verticalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var portraitBody: some View {
        GeometryReader { geometry in
            let spacing = max(metrics.wodScoreboardSpacing, 6)
            let verticalPadding = max(metrics.cardPadding - 5, 6)
            let dividerHeight: CGFloat = 1
            let currentLabelHeight = clamp(geometry.size.height * 0.043, min: 14, max: 21)
            let nextLabelHeight = clamp(geometry.size.height * 0.034, min: 12, max: 18)
            let usableHeight = max(geometry.size.height - (verticalPadding * 2) - (spacing * 5) - dividerHeight, 0)
            let progressHeight = clamp(usableHeight * 0.085, min: 30, max: 42)
            let titleHeight = max(usableHeight - progressHeight - currentLabelHeight - nextLabelHeight, 0)
            let currentTitleHeight = titleHeight * 0.75
            let nextTitleHeight = titleHeight * 0.25

            VStack(alignment: .center, spacing: spacing) {
                HStack(spacing: 10) {
                    progressPill(text: workoutManager.roundText, role: .round)
                    progressPill(text: timerManager.elapsedTimeText, role: .timer)
                }
                .frame(height: progressHeight)

                movementLabel("Current", size: currentLabelHeight)
                    .frame(height: currentLabelHeight)

                WODMovementBlock(
                    station: workoutManager.currentStation,
                    titleSize: metrics.wodCurrentMovementSize,
                    maxTitleLines: 2,
                    isPrimary: true
                )
                .frame(height: currentTitleHeight, alignment: .center)
                .layoutPriority(3)

                Divider()
                    .overlay(.white.opacity(0.1))
                    .frame(height: dividerHeight)

                movementLabel("Next", size: nextLabelHeight)
                    .frame(height: nextLabelHeight)

                WODMovementBlock(
                    station: workoutManager.nextStation,
                    titleSize: metrics.wodNextMovementSize,
                    maxTitleLines: 2,
                    isPrimary: false
                )
                .frame(height: nextTitleHeight, alignment: .center)
                .layoutPriority(2)
            }
            .padding(verticalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func progressPill(text: String, role: ProgressPillRole) -> some View {
        Text(text)
            .font(.system(size: role == .timer ? metrics.wodTimerSize : metrics.wodRoundSize, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(role == .timer ? .white : .yellow)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.horizontal, isLandscape ? 12 : 10)
            .padding(.vertical, isLandscape ? 5 : 6)
            .frame(maxWidth: .infinity, alignment: role == .timer ? .trailing : .leading)
    }

    private func movementLabel(_ label: String, size: CGFloat) -> some View {
        Text(label.uppercased())
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(.yellow)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private enum ProgressPillRole {
        case round
        case timer
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}

private struct WODMovementBlock: View {
    let station: WorkoutStation?
    let titleSize: CGFloat
    let maxTitleLines: Int
    let isPrimary: Bool

    var body: some View {
        GeometryReader { geometry in
            let title = MovementDisplayFormatter.heroTitle(for: station?.displayName)
            let lines = titleLines(from: title)
            let fittedSize = fittedTitleSize(for: lines, in: geometry.size)

            VStack(spacing: max(fittedSize * 0.02, 0)) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    movementTitleLine(line, size: fittedSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func movementTitleLine(_ line: String, size: CGFloat) -> some View {
        Text(line)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.2)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func fittedTitleSize(for lines: [String], in size: CGSize) -> CGFloat {
        let lineCount = CGFloat(max(min(lines.count, maxTitleLines), 1))
        let longestLineCount = CGFloat(max(lines.map(\.count).max() ?? 1, 1))
        let widthLimitedSize = (size.width * 0.94) / max(longestLineCount * 0.62, 1)
        let heightLimitedSize = (size.height * 0.92) / max(lineCount * 1.04, 1)
        let lowerBound: CGFloat = isPrimary ? 12 : 10

        return max(min(widthLimitedSize, heightLimitedSize, titleSize), lowerBound)
    }

    private func titleLines(from title: String) -> [String] {
        let lines = title.components(separatedBy: "\n").filter { !$0.isEmpty }
        return Array(lines.prefix(maxTitleLines))
    }
}

// MARK: - WORKOUT Compact Controls

private struct WODCompactControlStrip: View {
    let controls: [DashboardControl]
    @ObservedObject var viewModel: DisplayViewModel
    let metrics: DashboardMetrics

    var body: some View {
        HStack(spacing: metrics.isLandscape ? 7 : 6) {
            ForEach(controls) { control in
                Button {
                    handle(control)
                } label: {
                    Text(control.label)
                }
                .buttonStyle(WODCompactButtonStyle(kind: control.kind, metrics: metrics))
                .contentShape(Rectangle())
                .disabled(!control.isEnabled)
                .opacity(control.isEnabled ? 1 : 0.42)
            }
        }
        .padding(.horizontal, metrics.isLandscape ? 6 : 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.18), in: Capsule())
        .opacity(0.76)
    }

    static func controls(for status: WorkoutStatus, isFollowingWatch: Bool, isMirroringWatchSession: Bool) -> [DashboardControl] {
        if isFollowingWatch && isMirroringWatchSession {
            return [
                DashboardControl(label: "Stop Follow", kind: .secondary, action: .stopFollowing, isEnabled: true)
            ]
        }

        switch status {
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

    private func handle(_ control: DashboardControl) {
        switch control.action {
        case .primary: viewModel.primaryAction()
        case .back:    viewModel.previousStation()
        case .next:    viewModel.nextStation()
        case .finish:  viewModel.finishWorkout()
        case .reset:   viewModel.resetWorkout()
        case .stopFollowing: viewModel.stopFollowingWatch()
        }
    }
}

private struct WODCompactButtonStyle: ButtonStyle {
    let kind: DashboardButtonKind
    let metrics: DashboardMetrics

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: metrics.isLandscape ? 11 : 12, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? .black : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: metrics.isLandscape ? 28 : 34)
            .padding(.horizontal, 3)
            .contentShape(Rectangle())
            .background(background.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(kind == .secondary ? 0.18 : 0), lineWidth: 1)
            )
    }

    private var background: Color {
        switch kind {
        case .primary: return .yellow
        case .secondary: return .white.opacity(0.1)
        case .warning: return .red.opacity(0.74)
        }
    }
}

// MARK: - RUN Heart-Rate Dashboard

private struct RunDashboardPanel: View {
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var timerManager: TimerManager
    let metrics: DashboardMetrics
    let isLandscape: Bool

    var body: some View {
        if isLandscape {
            landscapeBody
        } else {
            portraitBody
        }
    }

    private var landscapeBody: some View {
        VStack(spacing: metrics.sectionSpacing) {
            runHero
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(3)

            HStack(spacing: 14) {
                compactRunMetric(title: "Elapsed", value: timerManager.elapsedTimeText, isPrimary: true)
                compactRunMetric(title: "Avg", value: "\(viewModel.activeAverageHeartRate)", isPrimary: false)
                compactRunMetric(title: "Max", value: "\(viewModel.activeMaximumHeartRate)", isPrimary: false)
            }
            .frame(height: min(metrics.activeMainHeight * 0.16, 52))
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var portraitBody: some View {
        VStack(spacing: metrics.sectionSpacing + 2) {
            runHero
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(3)

            HStack(spacing: 10) {
                compactRunMetric(title: "Elapsed", value: timerManager.elapsedTimeText, isPrimary: true)
                compactRunMetric(title: "Avg", value: "\(viewModel.activeAverageHeartRate)", isPrimary: false)
                compactRunMetric(title: "Max", value: "\(viewModel.activeMaximumHeartRate)", isPrimary: false)
            }
            .frame(height: 56)
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var runHero: some View {
        VStack(spacing: isLandscape ? 8 : 12) {
            Text(heartRateText)
                .font(.system(size: runHeartRateSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            Text(zoneText)
                .font(.system(size: runZoneSize, weight: .black, design: .rounded))
                .foregroundStyle(viewModel.activeCurrentZone.color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactRunMetric(title: String, value: String, isPrimary: Bool) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: isLandscape ? 13 : 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(value)
                .font(.system(size: isPrimary ? runTimerMetricSize : runSecondaryMetricSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isPrimary ? .yellow : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, isLandscape ? 6 : 5)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var heartRateText: String {
        guard let heartRate = viewModel.activeHeartRate else { return "--" }
        return "\(heartRate)"
    }

    private var zoneText: String {
        if viewModel.activeHeartRate == nil {
            return "HR DISCONNECTED"
        }
        return viewModel.activeCurrentZone.name.uppercased()
    }

    private var runHeartRateSize: CGFloat {
        isLandscape ? min(metrics.activeMainHeight * 0.84, 276) : min(metrics.activeMainHeight * 0.60, 252)
    }

    private var runZoneSize: CGFloat {
        isLandscape ? min(metrics.activeMainHeight * 0.18, 58) : min(metrics.activeMainHeight * 0.135, 54)
    }

    private var runTimerMetricSize: CGFloat {
        isLandscape ? min(metrics.activeMainHeight * 0.065, 26) : 20
    }

    private var runSecondaryMetricSize: CGFloat {
        isLandscape ? min(metrics.activeMainHeight * 0.067, 26) : 21
    }
}

// MARK: - Heart Rate Panel

private struct HeartRatePanel: View {
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var bluetoothManager: BluetoothHeartRateManager
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: metrics.isLandscape ? 8 : 12) {
            Text(heartRateText)
                .font(.system(size: metrics.heartRateSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)

            Text(currentZone.name.uppercased())
                .font(.system(size: metrics.zoneSize, weight: .black, design: .rounded))
                .foregroundStyle(currentZone.color)

            HStack(spacing: 10) {
                MetricTile(title: "Avg HR", value: "\(averageHeartRate)", metrics: metrics)
                MetricTile(title: "Max HR", value: "\(maximumHeartRate)", metrics: metrics)
            }
        }
        .padding(metrics.heartPanelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var heartRateText: String {
        guard let heartRate = viewModel.activeHeartRate else { return "--" }
        return "\(heartRate)"
    }

    private var currentZone: HeartRateZone { viewModel.activeCurrentZone }
    private var averageHeartRate: Int { viewModel.activeAverageHeartRate }
    private var maximumHeartRate: Int { viewModel.activeMaximumHeartRate }
}

// MARK: - Workout Panel (tightened)

private struct WorkoutPanel: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var timerManager: TimerManager
    let metrics: DashboardMetrics
    let isLandscape: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isLandscape ? 10 : 14) {
            // Top row: Elapsed + Round
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Elapsed")
                        .font(.system(size: metrics.headerMetaSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    Text(timerManager.elapsedTimeText)
                        .font(.system(size: metrics.timerSize, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Spacer(minLength: 4)

                Text(workoutManager.roundText)
                    .font(.system(size: isLandscape ? 16 : 20, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Current movement
            movementBlock(
                label: "Current",
                station: workoutManager.currentStation,
                titleSize: metrics.currentMovementSize,
                detailSize: isLandscape ? 15 : 18
            )

            // Next movement
            movementBlock(
                label: "Next",
                station: workoutManager.nextStation,
                titleSize: metrics.secondaryMovementSize,
                detailSize: isLandscape ? 14 : 16
            )

            Spacer(minLength: 0)
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipped()
    }

    private func movementBlock(label: String, station: WorkoutStation?, titleSize: CGFloat, detailSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: isLandscape ? 11 : 14, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)

            Text(station?.displayName ?? "None")
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(station?.prescriptionText ?? "")
                .font(.system(size: detailSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Metric Tile

private struct MetricTile: View {
    let title: String
    let value: String
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: metrics.isLandscape ? 12 : 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))

            Text(value)
                .font(.system(size: metrics.isLandscape ? 22 : 26, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, metrics.isLandscape ? 8 : 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Bluetooth Sheet

private struct BluetoothHeartRateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var manager: BluetoothHeartRateManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusSection

                    if manager.connectionState.isConnected {
                        connectedDeviceSection
                    } else {
                        scanSection
                        discoveredDevicesSection
                    }

                    if let errorMessage = manager.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.red.opacity(0.95))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Heart Rate")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.selectedHeartRateSource = .bluetooth
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATUS")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)

            Text(manager.sourceLabel)
                .font(.system(size: 20, weight: .heavy, design: .rounded))

            if let heartRate = viewModel.activeHeartRate {
                Text("\(heartRate) BPM")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("Waiting for live BPM…")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .sheetCard()
    }

    private var connectedDeviceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CONNECTED DEVICE")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)

            Text(manager.connectedPeripheralName ?? "Heart Rate Monitor")
                .font(.system(size: 22, weight: .black, design: .rounded))

            HStack(spacing: 18) {
                metricText(title: "BPM", value: manager.currentHeartRate.map(String.init) ?? "--")
                if let battery = manager.batteryPercentage {
                    metricText(title: "Battery", value: "\(battery)%")
                }
            }

            Button("Disconnect") {
                manager.disconnect()
            }
            .buttonStyle(SheetActionButtonStyle(kind: .destructive))
        }
        .sheetCard()
    }

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCAN")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)

            HStack(spacing: 12) {
                Button(manager.connectionState == .scanning ? "Scanning…" : "Scan") {
                    manager.startScan()
                }
                .buttonStyle(SheetActionButtonStyle(kind: .primary))
                .disabled(manager.connectionState == .scanning)

                Button("Rescan") {
                    manager.rescan()
                }
                .buttonStyle(SheetActionButtonStyle(kind: .secondary))

                if manager.connectionState == .scanning {
                    Button("Stop") {
                        manager.stopScan()
                    }
                    .buttonStyle(SheetActionButtonStyle(kind: .secondary))
                }
            }
        }
        .sheetCard()
    }

    private var discoveredDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DISCOVERED DEVICES")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)

            if manager.discoveredDevices.isEmpty {
                Text(manager.connectionState == .scanning
                       ? "Searching for heart-rate monitors…"
                       : "No devices found yet.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(manager.discoveredDevices) { device in
                    Button {
                        manager.connect(to: device)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(device.name)
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("RSSI \(device.rssi)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Text("Connect")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        .padding(12)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheetCard()
    }

    private func metricText(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
        }
    }
}

// MARK: - Sheet Helpers

private extension View {
    func sheetCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct SheetActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(background.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var background: Color {
        switch kind {
        case .primary: return .yellow
        case .secondary: return .white.opacity(0.12)
        case .destructive: return .red.opacity(0.85)
        }
    }
}

// MARK: - WORKOUT Landscape Rails

private struct WODLandscapeControlRail: View {
    let controls: [DashboardControl]
    @ObservedObject var viewModel: DisplayViewModel
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: max(metrics.sectionSpacing - 2, 6)) {
            Spacer(minLength: 0)

            ForEach(controls) { control in
                Button {
                    handle(control)
                } label: {
                    Text(control.label)
                }
                .buttonStyle(WODLandscapeRailButtonStyle(kind: control.kind, metrics: metrics))
                .contentShape(Rectangle())
                .disabled(!control.isEnabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .opacity(0.72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func leftLocalControls(for status: WorkoutStatus) -> [DashboardControl] {
        switch status {
        case .idle:
            return [
                DashboardControl(label: "Start", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Back", kind: .secondary, action: .back, isEnabled: false),
                DashboardControl(label: "Next", kind: .secondary, action: .next, isEnabled: false)
            ]
        case .running:
            return [
                DashboardControl(label: "Pause", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Back", kind: .secondary, action: .back, isEnabled: true),
                DashboardControl(label: "Next", kind: .secondary, action: .next, isEnabled: true)
            ]
        case .paused:
            return [
                DashboardControl(label: "Resume", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Back", kind: .secondary, action: .back, isEnabled: true),
                DashboardControl(label: "Next", kind: .secondary, action: .next, isEnabled: true)
            ]
        case .finished:
            return []
        }
    }

    static func rightLocalControls(for status: WorkoutStatus) -> [DashboardControl] {
        switch status {
        case .idle:
            return [
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: false),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .running, .paused:
            return [
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: true),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .finished:
            return []
        }
    }

    private func handle(_ control: DashboardControl) {
        switch control.action {
        case .primary: viewModel.primaryAction()
        case .back:    viewModel.previousStation()
        case .next:    viewModel.nextStation()
        case .finish:  viewModel.finishWorkout()
        case .reset:   viewModel.resetWorkout()
        case .stopFollowing: viewModel.stopFollowingWatch()
        }
    }
}

private struct WODLandscapeRailButtonStyle: ButtonStyle {
    let kind: DashboardButtonKind
    let metrics: DashboardMetrics

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: max(metrics.controlFontSize - 2, 12), weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? .black : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: metrics.wodLandscapeRailButtonHeight)
            .padding(.horizontal, 3)
            .contentShape(Rectangle())
            .background(background.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(kind == .secondary ? 0.22 : 0), lineWidth: 1)
            )
    }

    private var background: Color {
        switch kind {
        case .primary: return .yellow
        case .secondary: return .white.opacity(0.12)
        case .warning: return .red.opacity(0.82)
        }
    }
}

// MARK: - Control Bar

private struct ControlBar: View {
    let viewModel: DisplayViewModel
    @ObservedObject var workoutManager: WorkoutManager
    let metrics: DashboardMetrics
    let isLandscape: Bool
    let displayMode: GymDisplayMode

    private var controls: [DashboardControl] {
        if viewModel.isFollowingWatch && viewModel.isMirroringWatchSession {
            return [
                DashboardControl(label: "Stop Follow", kind: .secondary, action: .stopFollowing, isEnabled: true)
            ]
        }

        if displayMode == .run {
            return runControls
        }

        return workoutControls
    }

    private var runControls: [DashboardControl] {
        switch workoutManager.status {
        case .idle:
            return [
                DashboardControl(label: "Start", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: false),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .running:
            return [
                DashboardControl(label: "Pause", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: true),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .paused:
            return [
                DashboardControl(label: "Resume", kind: .primary, action: .primary, isEnabled: true),
                DashboardControl(label: "Finish", kind: .warning, action: .finish, isEnabled: true),
                DashboardControl(label: "Reset", kind: .secondary, action: .reset, isEnabled: true)
            ]
        case .finished:
            return [
                DashboardControl(label: "Reset", kind: .primary, action: .reset, isEnabled: true)
            ]
        }
    }

    private var workoutControls: [DashboardControl] {
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
                    Button(control.label) { handle(control) }
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
                    Button(control.label) { handle(control) }
                        .buttonStyle(DashboardButtonStyle(kind: control.kind, metrics: metrics))
                        .contentShape(Rectangle())
                        .disabled(!control.isEnabled)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func handle(_ control: DashboardControl) {
        switch control.action {
        case .primary: viewModel.primaryAction()
        case .back:    viewModel.previousStation()
        case .next:    viewModel.nextStation()
        case .finish:  viewModel.finishWorkout()
        case .reset:   viewModel.resetWorkout()
        case .stopFollowing: viewModel.stopFollowingWatch()
        }
    }
}

private struct DashboardControl: Identifiable {
    let label: String
    let kind: DashboardButtonKind
    let action: DashboardControlAction
    let isEnabled: Bool
    var id: String { "\(label)-\(action)" }
}

private enum DashboardControlAction: String {
    case primary, back, next, finish, reset, stopFollowing
}

private enum DashboardButtonKind {
    case primary, secondary, warning
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
            )
    }

    private var background: Color {
        switch kind {
        case .primary:   return .yellow
        case .secondary: return .white.opacity(0.1)
        case .warning:   return .red.opacity(0.78)
        }
    }
}

// MARK: - Workout Analytics

private struct WorkoutAnalyticsView: View {
    let analytics: WorkoutAnalytics?

    var body: some View {
        NavigationStack {
            WorkoutDetailContent(session: nil, analytics: analytics)
                .navigationTitle(analytics?.workoutName.isEmpty == false ? analytics?.workoutName ?? "Workout" : "Workout")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct WorkoutDetailContent: View {
    let session: CompletedWorkoutSession?
    let analytics: WorkoutAnalytics?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let analytics {
                    let model = WorkoutAnalyticsPresentationModel(session: session, analytics: analytics)
                    WorkoutHeroSummaryView(model: model)
                    WorkoutSectionMenu(model: model)
                    WorkoutHighlightsView(model: model)
                } else {
                    noAnalyticsContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
    }

    private var noAnalyticsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detailed splits unavailable.")
                .font(.system(size: 22, weight: .black, design: .rounded))

            Text("This workout does not include a completed Garmin-WOD analytics payload.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WorkoutHeroSummaryView: View {
    let model: WorkoutAnalyticsPresentationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.workoutName)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(model.dateText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(model.primaryResult)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)

                Text(model.resultContext)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                compactMetric("Avg HR", model.averageHeartRateText)
                compactMetric("Peak HR", model.maximumHeartRateText)
                compactMetric("Movements", "\(model.summary.movementCount)")
                compactMetric("Status", model.completionStatus)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func compactMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))

            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct WorkoutSectionMenu: View {
    let model: WorkoutAnalyticsPresentationModel

    var body: some View {
        VStack(spacing: 9) {
            NavigationLink {
                MovementBreakdownView(model: model)
            } label: {
                WorkoutSectionRow(
                    title: "Movement Breakdown",
                    subtitle: model.movementOverviewText,
                    systemImage: "figure.cross.training"
                )
            }

            NavigationLink {
                RoundBreakdownView(model: model)
            } label: {
                WorkoutSectionRow(
                    title: "Round Breakdown",
                    subtitle: model.roundOverviewText,
                    systemImage: "timer"
                )
            }

            NavigationLink {
                HeartRateDetailView(model: model)
            } label: {
                WorkoutSectionRow(
                    title: "Heart Rate",
                    subtitle: model.heartRateOverviewText,
                    systemImage: "heart.fill"
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutSectionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.yellow)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.44))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MovementBreakdownView: View {
    let model: WorkoutAnalyticsPresentationModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if model.summary.movementBreakdowns.isEmpty {
                    unavailableCard("Detailed movement splits unavailable.")
                } else {
                    ForEach(model.summary.movementBreakdowns) { movement in
                        NavigationLink {
                            MovementOccurrenceDetailView(movement: movement)
                        } label: {
                            MovementSummaryRow(
                                movement: movement,
                                totalSeconds: max(model.summary.totalActiveSeconds, 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Movement Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MovementSummaryRow: View {
    let movement: MovementBreakdown
    let totalSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(movement.movementName)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text("\(movement.occurrences.count) occurrences")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(WorkoutSummary.format(seconds: movement.totalSeconds))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("total")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule().fill(.yellow).frame(width: proxy.size.width * proportion)
                }
            }
            .frame(height: 6)

            HStack {
                metric("Avg", WorkoutSummary.format(seconds: movement.averageSeconds))
                metric("Fastest", WorkoutSummary.format(seconds: movement.fastestSeconds))
                metric("Peak HR", movement.maximumHeartRate.map(String.init) ?? "--")
            }
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var proportion: CGFloat {
        CGFloat(min(max(Double(movement.totalSeconds) / Double(max(totalSeconds, 1)), 0), 1))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MovementOccurrenceDetailView: View {
    let movement: MovementBreakdown

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(movement.occurrences.enumerated()), id: \.element.id) { offset, event in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Occurrence \(offset + 1)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                            Spacer()
                            Text("Round \(event.roundNumber)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.yellow)
                        }

                        HStack {
                            occurrenceMetric("Time", WorkoutSummary.format(seconds: event.durationSeconds))
                            occurrenceMetric("Avg HR", event.averageHeartRate.map(String.init) ?? "--")
                            occurrenceMetric("Peak HR", event.maximumHeartRate.map(String.init) ?? "--")
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle(movement.movementName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func occurrenceMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RoundBreakdownView: View {
    let model: WorkoutAnalyticsPresentationModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                RoundSummaryView(model: model)

                ForEach(model.roundPresentations) { round in
                    RoundRow(round: round, fastestCompleteRound: model.fastestCompleteRound)
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Round Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RoundSummaryView: View {
    let model: WorkoutAnalyticsPresentationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.roundOverviewText)
                .font(.system(size: 17, weight: .black, design: .rounded))
            if let fastest = model.fastestCompleteRound {
                summaryRow("Fastest", "Round \(fastest.roundNumber) • \(WorkoutSummary.format(seconds: fastest.durationSeconds))")
            }
            if let slowest = model.slowestCompleteRound {
                summaryRow("Slowest", "Round \(slowest.roundNumber) • \(WorkoutSummary.format(seconds: slowest.durationSeconds))")
            }
            if let average = model.averageCompleteRoundSeconds {
                summaryRow("Average", WorkoutSummary.format(seconds: average))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(value)
                .fontWeight(.black)
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
    }
}

private struct RoundRow: View {
    let round: RoundPresentation
    let fastestCompleteRound: RoundSplit?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text(round.subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(WorkoutSummary.format(seconds: round.durationSeconds))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                if round.isFastest {
                    Text("FASTEST")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HeartRateDetailView: View {
    let model: WorkoutAnalyticsPresentationModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    hrMetric("Average", model.averageHeartRateText)
                    hrMetric("Peak", model.maximumHeartRateText)
                }

                if let highest = model.summary.highestHeartRateMovement, let peak = highest.maximumHeartRate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Highest-HR Movement")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                        Text(highest.movementName)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                        Text("\(peak) bpm")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    unavailableCard("Heart-rate detail unavailable.")
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hrMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WorkoutHighlightsView: View {
    let model: WorkoutAnalyticsPresentationModel

    var body: some View {
        let highlights = model.highlights
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Highlights")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(highlights) { highlight in
                        HighlightTile(highlight: highlight)
                    }
                }
            }
            .padding(14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct HighlightTile: View {
    let highlight: WorkoutHighlightPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(highlight.category)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            Text(highlight.title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.68)
            Text(highlight.value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 10))
    }
}

private func unavailableCard(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.68))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
}

private struct WorkoutAnalyticsPresentationModel {
    let session: CompletedWorkoutSession?
    let analytics: WorkoutAnalytics
    let summary: WorkoutAnalyticsSummary

    init(session: CompletedWorkoutSession?, analytics: WorkoutAnalytics) {
        self.session = session
        self.analytics = analytics
        self.summary = analytics.summary
    }

    var workoutName: String {
        let sessionName = session?.workoutName ?? ""
        if !sessionName.isEmpty {
            return sessionName
        }
        return analytics.workoutName.isEmpty ? "Workout" : analytics.workoutName
    }

    var dateText: String {
        formatDate(session?.finishedAt ?? analytics.finishedAt)
    }

    var primaryResult: String {
        WorkoutSummary.format(seconds: summary.totalActiveSeconds)
    }

    var resultContext: String {
        if partialRoundCount > 0 {
            return "\(summary.roundsCompleted) rounds + partial"
        }
        if summary.roundsCompleted > 0 {
            return "\(summary.roundsCompleted) rounds"
        }
        return "completed"
    }

    var completionStatus: String {
        session?.status.capitalized ?? "Completed"
    }

    var averageHeartRateText: String {
        summary.averageHeartRate.map { "\($0)" } ?? "--"
    }

    var maximumHeartRateText: String {
        summary.maximumHeartRate.map { "\($0)" } ?? "--"
    }

    var completeRoundSplits: [RoundSplit] {
        summary.roundSplits.filter { $0.roundNumber <= summary.roundsCompleted }
    }

    var partialRoundSplits: [RoundSplit] {
        summary.roundSplits.filter { $0.roundNumber > summary.roundsCompleted }
    }

    var partialRoundCount: Int {
        partialRoundSplits.count
    }

    var fastestCompleteRound: RoundSplit? {
        completeRoundSplits.min { $0.durationSeconds < $1.durationSeconds }
    }

    var slowestCompleteRound: RoundSplit? {
        completeRoundSplits.max { $0.durationSeconds < $1.durationSeconds }
    }

    var averageCompleteRoundSeconds: Int? {
        guard !completeRoundSplits.isEmpty else { return nil }
        return completeRoundSplits.map(\.durationSeconds).reduce(0, +) / completeRoundSplits.count
    }

    var roundPresentations: [RoundPresentation] {
        summary.roundSplits.map { split in
            let isPartial = split.roundNumber > summary.roundsCompleted
            return RoundPresentation(
                roundNumber: split.roundNumber,
                title: isPartial ? "Partial Round" : "Round \(split.roundNumber)",
                subtitle: isPartial ? "Not compared with full rounds" : roundDeltaText(split),
                durationSeconds: split.durationSeconds,
                isPartial: isPartial,
                isFastest: !isPartial && fastestCompleteRound?.roundNumber == split.roundNumber
            )
        }
    }

    var movementOverviewText: String {
        if summary.movementBreakdowns.isEmpty {
            return "Detailed movement splits unavailable"
        }
        return "\(summary.movementBreakdowns.count) movement types • \(summary.movementCount) occurrences"
    }

    var roundOverviewText: String {
        if summary.roundSplits.isEmpty {
            return "Round splits unavailable"
        }
        if partialRoundCount > 0 {
            return "\(completeRoundSplits.count) complete rounds • \(partialRoundCount) partial"
        }
        return "\(completeRoundSplits.count) complete rounds"
    }

    var heartRateOverviewText: String {
        if summary.averageHeartRate == nil && summary.maximumHeartRate == nil {
            return "Heart-rate detail unavailable"
        }
        return "\(averageHeartRateText) avg • \(maximumHeartRateText) peak"
    }

    var highlights: [WorkoutHighlightPresentation] {
        var items: [WorkoutHighlightPresentation] = []
        if let event = summary.longestMovement {
            items.append(WorkoutHighlightPresentation(category: "LONGEST MOVEMENT", title: event.movementName, value: WorkoutSummary.format(seconds: event.durationSeconds)))
        }
        if let event = summary.fastestMovement {
            items.append(WorkoutHighlightPresentation(category: "FASTEST MOVEMENT", title: event.movementName, value: WorkoutSummary.format(seconds: event.durationSeconds)))
        }
        if let event = summary.highestHeartRateMovement, let peak = event.maximumHeartRate {
            items.append(WorkoutHighlightPresentation(category: "HIGHEST HR", title: event.movementName, value: "\(peak) bpm"))
        }
        if let round = fastestCompleteRound {
            items.append(WorkoutHighlightPresentation(category: "FASTEST ROUND", title: "Round \(round.roundNumber)", value: WorkoutSummary.format(seconds: round.durationSeconds)))
        }
        return items
    }

    private func roundDeltaText(_ split: RoundSplit) -> String {
        guard let fastest = fastestCompleteRound else {
            return "Complete round"
        }
        let delta = split.durationSeconds - fastest.durationSeconds
        if delta == 0 {
            return "Fastest complete round"
        }
        return "+\(WorkoutSummary.format(seconds: delta)) from fastest"
    }

    private func formatDate(_ timestamp: Int?) -> String {
        guard let timestamp else {
            return "Date unavailable"
        }
        let seconds = timestamp > 9_999_999_999 ? TimeInterval(timestamp / 1000) : TimeInterval(timestamp)
        return Date(timeIntervalSince1970: seconds).formatted(date: .abbreviated, time: .shortened)
    }
}

private struct RoundPresentation: Identifiable {
    var id: Int { roundNumber }
    let roundNumber: Int
    let title: String
    let subtitle: String
    let durationSeconds: Int
    let isPartial: Bool
    let isFastest: Bool
}

private struct WorkoutHighlightPresentation: Identifiable {
    var id: String { "\(category)-\(title)-\(value)" }
    let category: String
    let title: String
    let value: String
}

// MARK: - Workout History

private struct WorkoutHistoryView: View {
    @ObservedObject var viewModel: DisplayViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Workout History")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                            Text(viewModel.workoutHistoryStatusText)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.64))
                        }

                        Spacer()

                        Button(viewModel.isRefreshingWorkoutHistory ? "Refreshing" : "Refresh") {
                            viewModel.refreshWorkoutHistory(reason: "history")
                        }
                        .disabled(viewModel.isRefreshingWorkoutHistory)
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .foregroundStyle(.black)
                    }

                    if viewModel.workoutHistory.isEmpty {
                        emptyHistory
                    } else {
                        ForEach(viewModel.workoutHistory) { summary in
                            NavigationLink {
                                CompletedWorkoutDetailView(viewModel: viewModel, summary: summary)
                            } label: {
                                WorkoutHistoryRow(summary: summary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.refreshWorkoutHistory(reason: "historyPull")
            }
        }
        .onAppear {
            viewModel.refreshWorkoutHistory(reason: "historyOpen")
        }
    }

    private var emptyHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No saved workouts yet.")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text("Completed watch workouts appear here after the watch uploads them to the Garmin-WOD archive.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CompletedWorkoutDetailView: View {
    @ObservedObject var viewModel: DisplayViewModel
    let summary: CompletedWorkoutSummary

    private var selectedSession: CompletedWorkoutSession? {
        viewModel.selectedCompletedWorkout?.sessionId == summary.sessionId
            ? viewModel.selectedCompletedWorkout
            : nil
    }

    private var analytics: WorkoutAnalytics? {
        selectedSession?.analytics
    }

    var body: some View {
        WorkoutDetailContent(session: selectedSession, analytics: analytics)
            .navigationTitle(detailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if selectedSession == nil {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.yellow)
                        Text("Loading result")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(16)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .onAppear {
                viewModel.openCompletedWorkout(summary)
            }
    }

    private var detailTitle: String {
        summary.workoutName.isEmpty ? "Workout" : summary.workoutName
    }
}

private struct WorkoutHistoryRow: View {
    let summary: CompletedWorkoutSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.workoutName.isEmpty ? "Workout" : summary.workoutName)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text(summary.hasDetailedAnalytics ? "Splits" : "Summary")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(summary.hasDetailedAnalytics ? .yellow : .white.opacity(0.58))
            }

            Text(dateText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))

            HStack(spacing: 12) {
                metric("Time", summary.activeSeconds.map(WorkoutSummary.format(seconds:)) ?? "--")
                metric("Rounds", summary.roundsCompleted > 0 ? "\(summary.roundsCompleted)" : "--")
                metric("Avg HR", summary.averageHeartRate.map(String.init) ?? "--")
                metric("Max HR", summary.maximumHeartRate.map(String.init) ?? "--")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
        }
    }

    private var dateText: String {
        guard let finishedAt = summary.finishedAt else {
            return "Date unavailable"
        }

        let seconds = finishedAt > 9_999_999_999 ? TimeInterval(finishedAt / 1000) : TimeInterval(finishedAt)
        let date = Date(timeIntervalSince1970: seconds)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Workout Summary Screen

private struct WorkoutSummaryScreen: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics
    let isLandscape: Bool
    let onAnalytics: () -> Void
    let onNewWorkout: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            Group {
                if isLandscape {
                    landscapeSummary(size: size)
                } else {
                    portraitSummary(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func portraitSummary(size: CGSize) -> some View {
        VStack(spacing: portraitSpacing(size)) {
            summaryHeader
                .frame(maxWidth: .infinity)

            elapsedHero(size: size, isLandscape: false)
                .layoutPriority(2)

            HStack(spacing: portraitSpacing(size)) {
                SummaryMetricCard(title: "Avg HR", value: "\(summary.averageHeartRate)", metrics: metrics)
                SummaryMetricCard(title: "Max HR", value: "\(summary.maximumHeartRate)", metrics: metrics)
                SummaryMetricCard(title: "Calories", value: summary.caloriesText, metrics: metrics)
            }
            .frame(maxWidth: .infinity)

            SummaryZoneBreakdown(summary: summary, metrics: metrics)
                .layoutPriority(1)

            if showsWorkoutProgress {
                SummaryProgressCard(summary: summary, metrics: metrics)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)

            analyticsButton
                .frame(height: max(buttonHeight(size) - 8, 36))

            newWorkoutButton
                .frame(height: buttonHeight(size))
                .layoutPriority(3)
        }
        .padding(.horizontal, outerPadding(size))
        .padding(.vertical, max(outerPadding(size) - 2, 6))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapeSummary(size: CGSize) -> some View {
        let spacing = landscapeSpacing(size)

        return VStack(spacing: spacing) {
            summaryHeader
                .frame(maxWidth: .infinity)
                .frame(height: landscapeHeaderHeight(size))
                .layoutPriority(3)

            HStack(alignment: .top, spacing: spacing) {
                VStack(spacing: spacing) {
                    elapsedHero(size: size, isLandscape: true)

                    SummaryMetricCard(title: "Avg HR", value: "\(summary.averageHeartRate)", metrics: metrics)
                    SummaryMetricCard(title: "Max HR", value: "\(summary.maximumHeartRate)", metrics: metrics)
                    SummaryMetricCard(title: "Calories", value: summary.caloriesText, metrics: metrics)
                }
                .padding(summaryCardPadding(size))
                .frame(width: landscapeLeftWidth(size))
                .frame(maxHeight: .infinity)
                .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
                .overlay(summaryBorder)

                VStack(spacing: spacing) {
                    SummaryZoneBreakdown(summary: summary, metrics: metrics)
                        .frame(maxHeight: .infinity)

                    if showsWorkoutProgress {
                        SummaryProgressCard(summary: summary, metrics: metrics)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            HStack(spacing: spacing) {
                analyticsButton
                newWorkoutButton
            }
            .frame(maxWidth: size.width * 0.72)
            .frame(height: buttonHeight(size))
            .layoutPriority(3)
        }
        .padding(outerPadding(size))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryHeader: some View {
        VStack(spacing: metrics.isLandscape ? 2 : 3) {
            Text(summaryTitle)
                .font(.system(size: metrics.isLandscape ? 21 : 28, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            if !summarySubtitle.isEmpty {
                Text(summarySubtitle)
                    .font(.system(size: metrics.isLandscape ? 12 : 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var showsWorkoutProgress: Bool {
        summary.displayMode == .workout
    }

    private var summaryTitle: String {
        summary.displayMode == .run ? "Run Complete" : "Workout Complete"
    }

    private var summarySubtitle: String {
        guard summary.displayMode == .workout else {
            return ""
        }

        let title = summary.workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = summary.workoutType.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            return type
        }

        if title.caseInsensitiveCompare(type) == .orderedSame {
            return title
        }

        return "\(title) • \(type)"
    }

    private func elapsedHero(size: CGSize, isLandscape: Bool) -> some View {
        VStack(spacing: isLandscape ? 2 : 4) {
            Text(summary.elapsedTimeText)
                .font(.system(size: isLandscape ? clamp(size.height * 0.16, min: 50, max: 72) : clamp(size.height * 0.095, min: 50, max: 72), weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("Total Time")
                .font(.system(size: isLandscape ? 13 : 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var newWorkoutButton: some View {
        Button("New Workout") { onNewWorkout() }
            .buttonStyle(DashboardButtonStyle(kind: .primary, metrics: metrics))
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity)
    }

    private var analyticsButton: some View {
        Button("Workout Analytics") { onAnalytics() }
            .buttonStyle(DashboardButtonStyle(kind: .secondary, metrics: metrics))
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity)
    }

    private var summaryBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(.white.opacity(0.12), lineWidth: 1)
    }

    private func outerPadding(_ size: CGSize) -> CGFloat {
        metrics.isLandscape ? clamp(size.height * 0.015, min: 5, max: 8) : clamp(size.width * 0.025, min: 9, max: 14)
    }

    private func portraitSpacing(_ size: CGSize) -> CGFloat {
        clamp(size.height * 0.011, min: 7, max: 11)
    }

    private func landscapeSpacing(_ size: CGSize) -> CGFloat {
        clamp(size.height * 0.016, min: 5, max: 8)
    }

    private func buttonHeight(_ size: CGSize) -> CGFloat {
        metrics.isLandscape ? clamp(size.height * 0.10, min: 42, max: 46) : clamp(size.height * 0.055, min: 44, max: 52)
    }

    private func summaryCardPadding(_ size: CGSize) -> CGFloat {
        metrics.isLandscape ? clamp(size.height * 0.015, min: 6, max: 8) : 10
    }

    private func landscapeHeaderHeight(_ size: CGSize) -> CGFloat {
        clamp(size.height * 0.125, min: 40, max: 48)
    }

    private func landscapeLeftWidth(_ size: CGSize) -> CGFloat {
        let availableWidth = size.width - (outerPadding(size) * 2) - landscapeSpacing(size)
        return clamp(availableWidth * 0.46, min: 220, max: availableWidth * 0.52)
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
        VStack(spacing: metrics.isLandscape ? 3 : 4) {
            Text(title)
                .font(.system(size: metrics.isLandscape ? 11 : 12.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(value)
                .font(.system(size: metrics.isLandscape ? 20 : 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, minHeight: metrics.isLandscape ? 46 : 54)
        .padding(.horizontal, metrics.isLandscape ? 6 : 6)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SummaryZoneBreakdown: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 4 : 6) {
            sectionTitle("HR Zone Time")

            ForEach(summary.zoneTimes, id: \.label) { item in
                HStack(spacing: 10) {
                    Text(item.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 8)

                    Text(WorkoutSummary.format(seconds: item.seconds))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.system(size: metrics.isLandscape ? 12.5 : 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
            }
        }
        .padding(metrics.isLandscape ? 8 : 11)
        .frame(maxWidth: .infinity, maxHeight: metrics.isLandscape ? .infinity : nil, alignment: .topLeading)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: metrics.isLandscape ? 12.5 : 13.5, weight: .black, design: .rounded))
            .foregroundStyle(.yellow)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct SummaryProgressCard: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 4 : 6) {
            Text("Final Progress")
                .font(.system(size: metrics.isLandscape ? 12.5 : 13.5, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            summaryLine(title: "Round", value: "\(summary.finalRound)")
            summaryLine(title: "Station", value: "\(summary.finalStationIndex + 1)")
            if summary.finalMovementName != "None" {
                movementLine(value: summary.finalMovementName)
            }
        }
        .padding(metrics.isLandscape ? 8 : 11)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func summaryLine(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            Text(value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .lineLimit(metrics.isLandscape ? 1 : 2)
                .minimumScaleFactor(0.6)
        }
        .font(.system(size: metrics.isLandscape ? 12.5 : 13.5, weight: .bold, design: .rounded))
    }

    private func movementLine(value: String) -> some View {
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 1 : 2) {
            Text("Movement")
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(value)
                .foregroundStyle(.white)
                .lineLimit(metrics.isLandscape ? 1 : 2)
                .minimumScaleFactor(0.6)
        }
        .font(.system(size: metrics.isLandscape ? 12.5 : 13.5, weight: .bold, design: .rounded))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
