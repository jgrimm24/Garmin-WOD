import SwiftUI
import UIKit

struct GymDisplayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(GymDisplayMode.storageKey) private var displayModeRawValue = GymDisplayMode.defaultMode.rawValue
    @StateObject private var viewModel = DisplayViewModel()
    @State private var isBluetoothSheetPresented = false

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
                            viewModel.resetWorkout()
                        }
                    } else {
                        if isLandscape && displayMode == .workout {
                            wodLandscapeLayout(metrics: metrics)
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
                                    isLandscape: isLandscape,
                                    displayMode: displayMode
                                )
                                .frame(height: metrics.activeControlHeight)
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
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                displayMode: displayModeBinding,
                onHeartRateSettings: {
                    isBluetoothSheetPresented = true
                }
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
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                displayMode: displayModeBinding,
                onHeartRateSettings: {
                    isBluetoothSheetPresented = true
                }
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
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                displayMode: displayModeBinding,
                onHeartRateSettings: {
                    isBluetoothSheetPresented = true
                }
            )

            WODProgressPanel(
                workoutManager: viewModel.workoutManager,
                timerManager: viewModel.timerManager,
                metrics: metrics,
                isLandscape: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wodLandscapeLayout(metrics: DashboardMetrics) -> some View {
        let followWatchActive = viewModel.isFollowingWatch
        let railWidth = metrics.wodLandscapeRailWidth
        let gap = metrics.wodLandscapeRailGap
        let centerWidth = metrics.wodLandscapeCenterWidth(followWatchActive: followWatchActive)

        return HStack(alignment: .center, spacing: gap) {
            if !followWatchActive {
                WODLandscapeControlRail(
                    controls: WODLandscapeControlRail.leftLocalControls(for: viewModel.workoutManager.status),
                    viewModel: viewModel,
                    metrics: metrics
                )
                .frame(width: railWidth, height: metrics.availableHeight)
            }

            VStack(spacing: metrics.sectionSpacing) {
                HeaderView(
                    workoutManager: viewModel.workoutManager,
                    viewModel: viewModel,
                    bluetoothManager: viewModel.bluetoothHeartRateManager,
                    metrics: metrics,
                    displayMode: displayModeBinding,
                    onHeartRateSettings: {
                        isBluetoothSheetPresented = true
                    }
                )
                .frame(height: metrics.wodLandscapeHeaderHeight)

                WODProgressPanel(
                    workoutManager: viewModel.workoutManager,
                    timerManager: viewModel.timerManager,
                    metrics: metrics,
                    isLandscape: true
                )
                .frame(width: centerWidth, height: metrics.wodLandscapeHeroHeight)
            }
            .frame(width: centerWidth, height: metrics.availableHeight)

            WODLandscapeControlRail(
                controls: followWatchActive
                    ? [DashboardControl(label: "Stop Follow", kind: .secondary, action: .stopFollowing, isEnabled: true)]
                    : WODLandscapeControlRail.rightLocalControls(for: viewModel.workoutManager.status),
                viewModel: viewModel,
                metrics: metrics
            )
            .frame(width: railWidth, height: metrics.availableHeight)
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
    var activeDashboardHeight: CGFloat { max(availableHeight - activeControlHeight - sectionSpacing, 0) }
    var activeMainHeight: CGFloat { max(activeDashboardHeight - activeHeaderHeight - sectionSpacing, 0) }
    var wodLandscapeHeaderHeight: CGFloat { clamp(availableHeight * 0.105, min: 42, max: 54) }
    var wodLandscapeRailWidth: CGFloat { clamp(availableWidth * 0.095, min: 62, max: 86) }
    var wodLandscapeRailGap: CGFloat { clamp(availableWidth * 0.014, min: 8, max: 14) }
    var wodLandscapeHeroHeight: CGFloat { max(availableHeight - wodLandscapeHeaderHeight - sectionSpacing, 0) }
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
        isLandscape ? clamp(wodLandscapeHeroHeight * 0.28, min: 70, max: 124) : clamp(activeMainHeight * 0.20, min: 62, max: 112)
    }
    var wodCurrentPrescriptionSize: CGFloat {
        isLandscape ? clamp(wodLandscapeHeroHeight * 0.105, min: 26, max: 42) : clamp(activeMainHeight * 0.075, min: 22, max: 36)
    }
    var wodNextMovementSize: CGFloat {
        isLandscape ? clamp(wodLandscapeHeroHeight * 0.145, min: 36, max: 62) : clamp(activeMainHeight * 0.105, min: 32, max: 58)
    }
    var wodMetaSize: CGFloat {
        isLandscape ? clamp(wodLandscapeHeroHeight * 0.055, min: 16, max: 24) : clamp(activeMainHeight * 0.045, min: 15, max: 22)
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
    @ObservedObject var bluetoothManager: BluetoothHeartRateManager
    let metrics: DashboardMetrics
    @Binding var displayMode: GymDisplayMode
    let onHeartRateSettings: () -> Void

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

                if workoutManager.status == .idle {
                    setupControls
                } else if viewModel.isFollowingWatch {
                    Text(viewModel.watchSyncStatusText.uppercased())
                        .font(.system(size: max(metrics.headerMetaSize - 3, 10), weight: .black, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .layoutPriority(2)

            Spacer(minLength: 6)

            HStack(alignment: .center, spacing: 8) {
                DisplayModeSelector(displayMode: $displayMode, metrics: metrics)

                VStack(alignment: .trailing, spacing: 5) {
                    Button(action: onHeartRateSettings) {
                        Text(statusLabel)
                            .font(.system(size: metrics.headerMetaSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.yellow.opacity(0.13), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text(workoutManager.status.rawValue.uppercased())
                        .font(.system(size: metrics.headerMetaSize - 1, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.12), in: Capsule())
                }
            }
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

                DisplayModeSelector(displayMode: $displayMode, metrics: metrics)
            }

            HStack(alignment: .center, spacing: 8) {
                if workoutManager.status == .idle {
                    setupControls
                } else if viewModel.isFollowingWatch {
                    Text(viewModel.watchSyncStatusText.uppercased())
                        .font(.system(size: max(metrics.headerMetaSize - 2, 10), weight: .black, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 6)

                Button(action: onHeartRateSettings) {
                    Text(statusLabel)
                        .font(.system(size: metrics.headerMetaSize - 1, weight: .heavy, design: .rounded))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.yellow.opacity(0.13), in: Capsule())
                }
                .buttonStyle(.plain)

                Text(workoutManager.status.rawValue.uppercased())
                    .font(.system(size: metrics.headerMetaSize - 2, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.12), in: Capsule())
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

    @ViewBuilder
    private var setupControls: some View {
        HStack(spacing: 8) {
            if displayMode == .workout {
                Button {
                    viewModel.refreshLatestWorkout()
                } label: {
                    Text(viewModel.isRefreshingLatestWorkout ? "Refreshing…" : "Refresh WOD")
                        .font(.system(size: max(metrics.headerMetaSize - 2, 10), weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.yellow)
                .disabled(viewModel.isRefreshingLatestWorkout)

                Text(viewModel.isFollowingWatch ? viewModel.watchSyncStatusText : viewModel.latestWorkoutStatusText)
                    .font(.system(size: max(metrics.headerMetaSize - 3, 10), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Button {
                viewModel.toggleFollowWatch()
            } label: {
                Text(viewModel.isFollowingWatch ? "Stop Follow" : "Follow Watch")
                    .font(.system(size: max(metrics.headerMetaSize - 2, 10), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.isFollowingWatch ? .white.opacity(0.85) : .yellow)
        }
    }

    private var statusLabel: String {
        if bluetoothManager.connectionState.isConnected {
            let name = bluetoothManager.connectedPeripheralName ?? "Connected"
            let shortName = name
                .replacingOccurrences(of: "tactix 8 - 51mm", with: "TACTIX 8", options: .caseInsensitive)
                .replacingOccurrences(of: "Tactix 8 - 51mm", with: "TACTIX 8", options: .caseInsensitive)
                .replacingOccurrences(of: "Tactix 8", with: "TACTIX 8", options: .caseInsensitive)

            if let bpm = viewModel.activeHeartRate {
                return "\(shortName) • \(bpm) BPM • \(compactZoneLabel)"
            }
            return "\(shortName) CONNECTED"
        }

        switch bluetoothManager.connectionState {
        case .scanning:
            return "SCANNING…"
        default: 
            return "HR DISCONNECTED"
        }
    }

    private var compactZoneLabel: String {
        let name = viewModel.activeCurrentZone.name.uppercased()
        if name.hasPrefix("ZONE ") {
            return name.replacingOccurrences(of: "ZONE ", with: "Z")
        }
        return name
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
            let spacing = max(metrics.sectionSpacing - 5, 5)
            let verticalPadding = max(metrics.cardPadding - 4, 6)
            let usableHeight = max(geometry.size.height - (verticalPadding * 2) - (spacing * 3) - 1, 0)
            let progressHeight = clamp(usableHeight * 0.13, min: 32, max: 42)
            let movementHeight = max(usableHeight - progressHeight, 0)
            let currentHeight = movementHeight * 0.68
            let nextHeight = movementHeight * 0.32

            VStack(alignment: .center, spacing: spacing) {
                HStack(alignment: .center, spacing: 14) {
                    progressPill(text: workoutManager.roundText, isPrimary: true)
                    progressPill(text: timerManager.elapsedTimeText, isPrimary: false)
                }
                .frame(height: progressHeight)

                WODMovementBlock(
                    label: "Current",
                    station: workoutManager.currentStation,
                    titleSize: metrics.wodCurrentMovementSize,
                    prescriptionSize: metrics.wodCurrentPrescriptionSize,
                    maxTitleLines: 2,
                    maxPrescriptionLines: 2,
                    isPrimary: true
                )
                .frame(height: currentHeight, alignment: .center)
                .layoutPriority(3)

                Divider()
                    .overlay(.white.opacity(0.16))

                WODMovementBlock(
                    label: "Next",
                    station: workoutManager.nextStation,
                    titleSize: metrics.wodNextMovementSize,
                    prescriptionSize: max(metrics.wodCurrentPrescriptionSize * 0.72, 16),
                    maxTitleLines: 2,
                    maxPrescriptionLines: 2,
                    isPrimary: false
                )
                .frame(height: nextHeight, alignment: .center)
                .layoutPriority(2)
            }
            .padding(verticalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var portraitBody: some View {
        GeometryReader { geometry in
            let spacing = max(metrics.sectionSpacing - 5, 5)
            let verticalPadding = max(metrics.cardPadding - 4, 7)
            let usableHeight = max(geometry.size.height - (verticalPadding * 2) - (spacing * 3) - 1, 0)
            let progressHeight = clamp(usableHeight * 0.12, min: 38, max: 50)
            let movementHeight = max(usableHeight - progressHeight, 0)
            let currentHeight = movementHeight * 0.68
            let nextHeight = movementHeight * 0.32

            VStack(alignment: .center, spacing: spacing) {
                HStack(spacing: 10) {
                    progressPill(text: workoutManager.roundText, isPrimary: true)
                    progressPill(text: timerManager.elapsedTimeText, isPrimary: false)
                }
                .frame(height: progressHeight)

                WODMovementBlock(
                    label: "Current",
                    station: workoutManager.currentStation,
                    titleSize: metrics.wodCurrentMovementSize,
                    prescriptionSize: metrics.wodCurrentPrescriptionSize,
                    maxTitleLines: 2,
                    maxPrescriptionLines: 2,
                    isPrimary: true
                )
                .frame(height: currentHeight, alignment: .center)
                .layoutPriority(3)

                Divider()
                    .overlay(.white.opacity(0.14))

                WODMovementBlock(
                    label: "Next",
                    station: workoutManager.nextStation,
                    titleSize: metrics.wodNextMovementSize,
                    prescriptionSize: max(metrics.wodCurrentPrescriptionSize * 0.72, 16),
                    maxTitleLines: 2,
                    maxPrescriptionLines: 2,
                    isPrimary: false
                )
                .frame(height: nextHeight, alignment: .center)
                .layoutPriority(2)
            }
            .padding(verticalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func progressPill(text: String, isPrimary: Bool) -> some View {
        Text(text)
            .font(.system(size: metrics.wodMetaSize, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isPrimary ? .yellow : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.horizontal, isLandscape ? 14 : 10)
            .padding(.vertical, isLandscape ? 8 : 7)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(isPrimary ? 0.13 : 0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}

private struct WODMovementBlock: View {
    let label: String
    let station: WorkoutStation?
    let titleSize: CGFloat
    let prescriptionSize: CGFloat
    let maxTitleLines: Int
    let maxPrescriptionLines: Int
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .center, spacing: isPrimary ? 8 : 5) {
            Text(label.uppercased())
                .font(.system(size: isPrimary ? max(titleSize * 0.18, 18) : max(titleSize * 0.24, 14), weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(station?.displayName ?? "None")
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(maxTitleLines)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.58)
                .fixedSize(horizontal: false, vertical: true)

            if let prescription = station?.prescriptionText, !prescription.isEmpty {
                Text(prescription)
                    .font(.system(size: prescriptionSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(maxPrescriptionLines)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.62)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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

// MARK: - Workout Summary Screen

private struct WorkoutSummaryScreen: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics
    let isLandscape: Bool
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

            newWorkoutButton
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
