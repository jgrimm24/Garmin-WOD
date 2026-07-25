import SwiftUI

struct GymDisplayView: View {
    @StateObject private var viewModel = DisplayViewModel()
    @State private var isBluetoothSheetPresented = false

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
                            .frame(height: isLandscape ? metrics.activeControlHeight : nil)
                        }
                    }
                }
                .padding(metrics.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1)
            }
            .onAppear {
                viewModel.selectedHeartRateSource = .bluetooth
                viewModel.logLayout(width: geometry.size.width, height: geometry.size.height, isLandscape: isLandscape)
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.logLayout(width: newSize.width, height: newSize.height, isLandscape: newSize.width > newSize.height)
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

    // MARK: - Layouts

    private func portraitLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                onHeartRateSettings: {
                    isBluetoothSheetPresented = true
                }
            )

            HStack(alignment: .top, spacing: metrics.sectionSpacing) {
                HeartRatePanel(
                    viewModel: viewModel,
                    bluetoothManager: viewModel.bluetoothHeartRateManager,
                    metrics: metrics
                )
                .frame(maxWidth: .infinity)

                WorkoutPanel(
                    workoutManager: viewModel.workoutManager,
                    timerManager: viewModel.timerManager,
                    metrics: metrics,
                    isLandscape: false
                )
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapeLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                onHeartRateSettings: {
                    isBluetoothSheetPresented = true
                }
            )
            .frame(height: metrics.activeHeaderHeight)

            HStack(alignment: .top, spacing: metrics.landscapePanelGap) {
                HeartRatePanel(
                    viewModel: viewModel,
                    bluetoothManager: viewModel.bluetoothHeartRateManager,
                    metrics: metrics
                )
                .frame(width: metrics.landscapeHeartPanelWidth, height: metrics.activeMainHeight)

                WorkoutPanel(
                    workoutManager: viewModel.workoutManager,
                    timerManager: viewModel.timerManager,
                    metrics: metrics,
                    isLandscape: true
                )
                .frame(width: metrics.landscapeWorkoutPanelWidth, height: metrics.activeMainHeight)
            }
            .frame(width: metrics.availableWidth, height: metrics.activeMainHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: metrics.activeDashboardHeight)
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
    var cardPadding: CGFloat { isLandscape ? 12 : 14 }
    var heartPanelPadding: CGFloat { isLandscape ? 10 : 14 }
    var landscapePanelGap: CGFloat { isLandscape ? 14 : sectionSpacing }

    var landscapePanelWidthBudget: CGFloat { max(availableWidth - landscapePanelGap, 0) }

    // Slightly narrower left panel so right side has more room
    var landscapeHeartPanelWidth: CGFloat { landscapePanelWidthBudget * 0.38 }
    var landscapeWorkoutPanelWidth: CGFloat { max(landscapePanelWidthBudget - landscapeHeartPanelWidth, 0) }

    var activeHeaderHeight: CGFloat { clamp(availableHeight * 0.13, min: 52, max: 64) }
    var activeControlHeight: CGFloat { clamp(availableHeight * 0.105, min: 46, max: 54) }
    var activeDashboardHeight: CGFloat { max(availableHeight - activeControlHeight - sectionSpacing, 0) }
    var activeMainHeight: CGFloat { max(activeDashboardHeight - activeHeaderHeight - sectionSpacing, 0) }

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
    let onHeartRateSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(workoutManager.workout.title)
                    .font(.system(size: metrics.headerTitleSize, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(workoutManager.workout.type.rawValue.uppercased())
                    .font(.system(size: metrics.headerMetaSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusLabel: String {
        if bluetoothManager.connectionState.isConnected {
            let name = bluetoothManager.connectedPeripheralName ?? "Connected"
            let shortName = name
                .replacingOccurrences(of: "tactix 8 - 51mm", with: "TACTIX 8", options: .caseInsensitive)
                .replacingOccurrences(of: "Tactix 8 - 51mm", with: "TACTIX 8", options: .caseInsensitive)
                .replacingOccurrences(of: "Tactix 8", with: "TACTIX 8", options: .caseInsensitive)

            if let bpm = viewModel.activeHeartRate {
                return "\(shortName) · \(bpm)"
            }
            return "\(shortName) CONNECTED"
        }

        switch bluetoothManager.connectionState {
        case .scanning: return "SCANNING…"
        case .reconnecting: return "RECONNECTING…"
        default: return "HR DISCONNECTED"
        }
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

// MARK: - Control Bar

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
    case primary, back, next, finish, reset
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

            SummaryProgressCard(summary: summary, metrics: metrics)
                .layoutPriority(1)

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
        VStack(spacing: landscapeSpacing(size)) {
            summaryHeader
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: landscapeSpacing(size)) {
                VStack(spacing: landscapeSpacing(size)) {
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

                VStack(spacing: landscapeSpacing(size)) {
                    SummaryZoneBreakdown(summary: summary, metrics: metrics)
                        .frame(maxHeight: .infinity)

                    SummaryProgressCard(summary: summary, metrics: metrics)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            newWorkoutButton
                .frame(maxWidth: size.width * 0.72)
                .frame(height: buttonHeight(size))
        }
        .padding(outerPadding(size))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryHeader: some View {
        VStack(spacing: metrics.isLandscape ? 2 : 3) {
            Text("Workout Complete")
                .font(.system(size: metrics.isLandscape ? 24 : 28, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text("\(summary.workoutName) • \(summary.workoutType.rawValue)")
                .font(.system(size: metrics.isLandscape ? 13 : 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity)
    }

    private func elapsedHero(size: CGSize, isLandscape: Bool) -> some View {
        VStack(spacing: isLandscape ? 2 : 4) {
            Text(summary.elapsedTimeText)
                .font(.system(size: isLandscape ? clamp(size.height * 0.18, min: 56, max: 82) : clamp(size.height * 0.095, min: 50, max: 72), weight: .black, design: .rounded))
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
        metrics.isLandscape ? clamp(size.height * 0.025, min: 8, max: 14) : clamp(size.width * 0.025, min: 9, max: 14)
    }

    private func portraitSpacing(_ size: CGSize) -> CGFloat {
        clamp(size.height * 0.011, min: 7, max: 11)
    }

    private func landscapeSpacing(_ size: CGSize) -> CGFloat {
        clamp(size.height * 0.023, min: 8, max: 13)
    }

    private func buttonHeight(_ size: CGSize) -> CGFloat {
        metrics.isLandscape ? clamp(size.height * 0.115, min: 44, max: 52) : clamp(size.height * 0.055, min: 44, max: 52)
    }

    private func summaryCardPadding(_ size: CGSize) -> CGFloat {
        metrics.isLandscape ? clamp(size.height * 0.025, min: 8, max: 12) : 10
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
                .font(.system(size: metrics.isLandscape ? 12 : 12.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(value)
                .font(.system(size: metrics.isLandscape ? 24 : 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, minHeight: metrics.isLandscape ? 58 : 54)
        .padding(.horizontal, metrics.isLandscape ? 10 : 6)
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
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 7 : 6) {
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
                .font(.system(size: metrics.isLandscape ? 14 : 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
                .padding(.vertical, metrics.isLandscape ? 1 : 0)
            }
        }
        .padding(metrics.isLandscape ? 12 : 11)
        .frame(maxWidth: .infinity, maxHeight: metrics.isLandscape ? .infinity : nil, alignment: .topLeading)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: metrics.isLandscape ? 13 : 13.5, weight: .black, design: .rounded))
            .foregroundStyle(.yellow)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct SummaryProgressCard: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 7 : 6) {
            Text("Final Progress")
                .font(.system(size: metrics.isLandscape ? 13 : 13.5, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            summaryLine(title: "Round", value: "\(summary.finalRound)")
            summaryLine(title: "Station", value: "\(summary.finalStationIndex + 1)")
            if summary.finalMovementName != "None" {
                summaryLine(title: "Movement", value: summary.finalMovementName)
            }
        }
        .padding(metrics.isLandscape ? 12 : 11)
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
        .font(.system(size: metrics.isLandscape ? 14 : 13.5, weight: .bold, design: .rounded))
    }
}
