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
                    mockManager: viewModel.heartRateManager,
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
                            .frame(height: isLandscape ? metrics.activeControlHeight : nil)
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
        .sheet(isPresented: $isBluetoothSheetPresented) {
            BluetoothHeartRateSheet(
                viewModel: viewModel,
                manager: viewModel.bluetoothHeartRateManager
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func portraitLayout(metrics: DashboardMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                onHeartRateSettings: {
                    print("[UI] HR settings tapped")
                    isBluetoothSheetPresented = true
                }
            )

            ScrollView {
                VStack(spacing: metrics.sectionSpacing) {
                    HeartRatePanel(
                        viewModel: viewModel,
                        mockManager: viewModel.heartRateManager,
                        bluetoothManager: viewModel.bluetoothHeartRateManager,
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
        let leftWidth = metrics.landscapeHeartPanelWidth
        let rightWidth = metrics.landscapeWorkoutPanelWidth

        return VStack(spacing: metrics.sectionSpacing) {
            HeaderView(
                workoutManager: viewModel.workoutManager,
                viewModel: viewModel,
                bluetoothManager: viewModel.bluetoothHeartRateManager,
                metrics: metrics,
                onHeartRateSettings: {
                    print("[UI] HR settings tapped")
                    isBluetoothSheetPresented = true
                }
            )
            .frame(height: metrics.activeHeaderHeight)

            HStack(alignment: .top, spacing: metrics.landscapePanelGap) {
                HeartRatePanel(
                    viewModel: viewModel,
                    mockManager: viewModel.heartRateManager,
                    bluetoothManager: viewModel.bluetoothHeartRateManager,
                    metrics: metrics,
                    isCompact: true
                )
                .frame(width: leftWidth, height: metrics.activeMainHeight)

                WorkoutPanel(
                    workoutManager: viewModel.workoutManager,
                    timerManager: viewModel.timerManager,
                    metrics: metrics,
                    isLandscape: true
                )
                .frame(width: rightWidth, height: metrics.activeMainHeight)
            }
            .frame(width: metrics.availableWidth, height: metrics.activeMainHeight, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: metrics.activeDashboardHeight)
    }
}

private struct ZoneBackground: View {
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var mockManager: MockHeartRateManager
    @ObservedObject var bluetoothManager: BluetoothHeartRateManager

    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                viewModel.activeCurrentZone.color.opacity(0.42),
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

    var availableHeight: CGFloat {
        size.height - (outerPadding * 2)
    }

    var outerPadding: CGFloat {
        isLandscape ? 8 : 10
    }

    var cardPadding: CGFloat {
        isLandscape ? 10 : 14
    }

    var heartPanelPadding: CGFloat {
        isLandscape ? 7 : cardPadding
    }

    var landscapePanelGap: CGFloat {
        isLandscape ? clamp(size.width * 0.018, min: 10, max: 16) : sectionSpacing
    }

    var landscapePanelWidthBudget: CGFloat {
        max(availableWidth - landscapePanelGap, 0)
    }

    var landscapeHeartPanelWidth: CGFloat {
        landscapePanelWidthBudget * 0.42
    }

    var landscapeWorkoutPanelWidth: CGFloat {
        max(landscapePanelWidthBudget - landscapeHeartPanelWidth, 0)
    }

    var mockHeartRateButtonWidth: CGFloat {
        isLandscape ? clamp(landscapeHeartPanelWidth * 0.22, min: 34, max: 44) : 72
    }

    var activeHeaderHeight: CGFloat {
        clamp(availableHeight * 0.16, min: 54, max: 68)
    }

    var activeControlHeight: CGFloat {
        clamp(availableHeight * 0.115, min: 44, max: 50)
    }

    var activeDashboardHeight: CGFloat {
        max(availableHeight - activeControlHeight - sectionSpacing, 0)
    }

    var activeMainHeight: CGFloat {
        max(activeDashboardHeight - activeHeaderHeight - sectionSpacing, 0)
    }

    var summaryButtonHeight: CGFloat {
        clamp(availableHeight * 0.062, min: 42, max: 48)
    }

    var summaryHeaderHeight: CGFloat {
        clamp(availableHeight * 0.08, min: 44, max: 58)
    }

    var summaryElapsedHeight: CGFloat {
        clamp(availableHeight * 0.105, min: 60, max: 82)
    }

    var summaryMetricHeight: CGFloat {
        clamp(availableHeight * 0.068, min: 48, max: 58)
    }

    var summaryProgressHeight: CGFloat {
        clamp(availableHeight * 0.13, min: 88, max: 112)
    }

    var summaryZoneHeight: CGFloat {
        max(
            availableHeight
                - summaryButtonHeight
                - summaryHeaderHeight
                - summaryElapsedHeight
                - summaryMetricHeight
                - summaryProgressHeight
                - (summarySectionSpacing * 6),
            0
        )
    }

    var summarySectionSpacing: CGFloat {
        isLandscape ? max(sectionSpacing - 1, 6) : 5
    }

    var sectionSpacing: CGFloat {
        isLandscape ? 8 : 12
    }

    var headerTitleSize: CGFloat {
        isLandscape ? clamp(size.height * 0.048, min: 18, max: 24) : clamp(size.width * 0.08, min: 26, max: 36)
    }

    var headerMetaSize: CGFloat {
        isLandscape ? clamp(size.height * 0.031, min: 11, max: 13) : 15
    }

    var heartRateSize: CGFloat {
        if isLandscape {
            return clamp(size.height * 0.15, min: 48, max: 66)
        }

        return clamp(size.height * 0.12, min: 68, max: 104)
    }

    var zoneSize: CGFloat {
        isLandscape ? clamp(size.height * 0.036, min: 14, max: 18) : 22
    }

    var timerSize: CGFloat {
        if isLandscape {
            return clamp(size.height * 0.095, min: 34, max: 48)
        }

        return clamp(size.height * 0.075, min: 40, max: 64)
    }

    var currentMovementSize: CGFloat {
        isLandscape ? clamp(size.height * 0.045, min: 18, max: 24) : 27
    }

    var secondaryMovementSize: CGFloat {
        isLandscape ? clamp(size.height * 0.034, min: 14, max: 18) : 20
    }

    var controlFontSize: CGFloat {
        isLandscape ? clamp(size.height * 0.031, min: 12, max: 14) : 17
    }

    var controlHeight: CGFloat {
        isLandscape ? activeControlHeight : 48
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}

private struct HeaderView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var bluetoothManager: BluetoothHeartRateManager
    let metrics: DashboardMetrics
    let onHeartRateSettings: () -> Void

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
                Button {
                    onHeartRateSettings()
                } label: {
                    Text(viewModel.compactHeartRateSourceLabel)
                        .font(.system(size: metrics.headerMetaSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.yellow.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

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
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var mockManager: MockHeartRateManager
    @ObservedObject var bluetoothManager: BluetoothHeartRateManager
    let metrics: DashboardMetrics
    let isCompact: Bool

    var body: some View {
        VStack(spacing: metrics.isLandscape ? 5 : (isCompact ? 10 : 12)) {
            Text(heartRateText)
                .font(.system(size: metrics.heartRateSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            Text(currentZone.name.uppercased())
                .font(.system(size: metrics.zoneSize, weight: .black, design: .rounded))
                .foregroundStyle(currentZone.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: metrics.isLandscape ? 7 : 10) {
                MetricTile(title: "Avg HR", value: "\(averageHeartRate)", metrics: metrics)
                MetricTile(title: "Max HR", value: "\(maximumHeartRate)", metrics: metrics)
            }

            if !isCompact {
                ZoneTimeSummary(items: zoneTimeSummary, metrics: metrics)
            } else {
                ViewThatFits {
                    if !metrics.isLandscape {
                        ZoneTimeSummary(items: zoneTimeSummary, metrics: metrics)
                    }
                    EmptyView()
                }
            }

            if viewModel.selectedHeartRateSource == .mock {
                MockControls(manager: mockManager, metrics: metrics)
            }
        }
        .padding(metrics.heartPanelPadding)
        .frame(maxWidth: .infinity, maxHeight: metrics.isLandscape ? .infinity : nil)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var heartRateText: String {
        guard let heartRate = viewModel.activeHeartRate else {
            return "--"
        }

        return "\(heartRate)"
    }

    private var currentZone: HeartRateZone {
        viewModel.activeCurrentZone
    }

    private var averageHeartRate: Int {
        viewModel.activeAverageHeartRate
    }

    private var maximumHeartRate: Int {
        viewModel.activeMaximumHeartRate
    }

    private var zoneTimeSummary: [(zone: HeartRateZone, seconds: Int)] {
        switch viewModel.selectedHeartRateSource {
        case .mock:
            return mockManager.zoneTimeSummary
        case .bluetooth:
            return bluetoothManager.zoneTimeSummary
        }
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
                .font(.system(size: metrics.isLandscape ? 11 : 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            Text(value)
                .font(.system(size: metrics.isLandscape ? 20 : 26, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, metrics.isLandscape ? 6 : 9)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ZoneTimeSummary: View {
    let items: [(zone: HeartRateZone, seconds: Int)]
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: metrics.isLandscape ? 7 : 5) {
            ForEach(items, id: \.zone.id) { item in
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

private struct BluetoothHeartRateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DisplayViewModel
    @ObservedObject var manager: BluetoothHeartRateManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sourceSection
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Heart Rate")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        print("[UI] Close HR sheet tapped")
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .textCase(.uppercase)

            Picker("HR Source", selection: $viewModel.selectedHeartRateSource) {
                ForEach(HeartRateSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
        }
        .sheetCard()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .textCase(.uppercase)

            Text(viewModel.selectedHeartRateSource == .mock ? "Mock heart rate" : manager.sourceLabel)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if let heartRate = viewModel.activeHeartRate {
                Text("\(heartRate) BPM")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
            } else if viewModel.selectedHeartRateSource == .bluetooth {
                Text("Waiting for live BPM")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .sheetCard()
    }

    private var connectedDeviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Device")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                Text(manager.connectedPeripheralName ?? "Heart Rate Monitor")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)

                HStack(spacing: 14) {
                    metricText(title: "BPM", value: manager.currentHeartRate.map(String.init) ?? "--")

                    if let batteryPercentage = manager.batteryPercentage {
                        metricText(title: "Battery", value: "\(batteryPercentage)%")
                    }
                }
            }

            Button("Disconnect") {
                print("[UI] Disconnect HR tapped")
                manager.disconnect()
            }
            .buttonStyle(SheetActionButtonStyle(kind: .destructive))
        }
        .sheetCard()
    }

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Button(manager.connectionState == .scanning ? "Scanning" : "Scan") {
                    print("[UI] Scan HR tapped")
                    viewModel.selectedHeartRateSource = .bluetooth
                    manager.startScan()
                }
                .buttonStyle(SheetActionButtonStyle(kind: .primary))
                .disabled(manager.connectionState == .scanning)

                Button("Rescan") {
                    print("[UI] Rescan HR tapped")
                    viewModel.selectedHeartRateSource = .bluetooth
                    manager.rescan()
                }
                .buttonStyle(SheetActionButtonStyle(kind: .secondary))

                if manager.connectionState == .scanning {
                    Button("Stop") {
                        print("[UI] Stop HR scan tapped")
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
            Text("Discovered Devices")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .textCase(.uppercase)

            if manager.discoveredDevices.isEmpty {
                Text(manager.connectionState == .scanning ? "Searching for heart-rate monitors..." : "No heart-rate monitors found yet.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(manager.discoveredDevices) { device in
                    Button {
                        print("[UI] Connect HR tapped \(device.name)")
                        viewModel.selectedHeartRateSource = .bluetooth
                        manager.connect(to: device)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.65)

                                Text("RSSI \(device.rssi)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.62))
                            }

                            Spacer()

                            Text("Connect")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        .padding(12)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .sheetCard()
    }

    private func metricText(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
        }
    }
}

private extension View {
    func sheetCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

private struct SheetActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(backgroundColor.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 9))
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return .black
        case .secondary, .destructive:
            return .white
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary:
            return .yellow
        case .secondary:
            return .white.opacity(0.12)
        case .destructive:
            return .red.opacity(0.82)
        }
    }
}

private struct MockControls: View {
    @ObservedObject var manager: MockHeartRateManager
    let metrics: DashboardMetrics

    var body: some View {
        HStack(spacing: metrics.isLandscape ? 5 : 10) {
            Button("- HR") {
                print("[UI] - HR tapped")
                manager.decreaseHeartRate()
            }
            .buttonStyle(MockHeartRateButtonStyle(metrics: metrics))
            .frame(width: metrics.mockHeartRateButtonWidth)

            Toggle("Demo", isOn: $manager.isDemoModeEnabled)
                .toggleStyle(.switch)
                .font(.system(size: metrics.isLandscape ? 11 : 14, weight: .bold))
                .lineLimit(1)
                .scaleEffect(metrics.isLandscape ? 0.9 : 1)
                .frame(maxWidth: .infinity)

            Button("+ HR") {
                print("[UI] + HR tapped")
                manager.increaseHeartRate()
            }
            .buttonStyle(MockHeartRateButtonStyle(metrics: metrics))
            .frame(width: metrics.mockHeartRateButtonWidth)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MockHeartRateButtonStyle: ButtonStyle {
    let metrics: DashboardMetrics

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: metrics.isLandscape ? 10 : 14, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: metrics.isLandscape ? 30 : 42)
            .padding(.horizontal, metrics.isLandscape ? 3 : 6)
            .contentShape(Rectangle())
            .background(.white.opacity(configuration.isPressed ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
                    .allowsHitTesting(false)
            )
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
            summaryHeader
                .frame(height: metrics.summaryHeaderHeight)

            Text(summary.elapsedTimeText)
                .font(.system(size: clamp(metrics.summaryElapsedHeight * 0.78, min: 46, max: 66), weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.summaryElapsedHeight)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                SummaryMetricCard(title: "Avg HR", value: "\(summary.averageHeartRate)", metrics: metrics)
                SummaryMetricCard(title: "Max HR", value: "\(summary.maximumHeartRate)", metrics: metrics)
                SummaryMetricCard(title: "Calories", value: summary.caloriesText, metrics: metrics)
            }
            .frame(height: metrics.summaryMetricHeight)

            SummaryZoneBreakdown(summary: summary, metrics: metrics)
                .frame(height: metrics.summaryZoneHeight)

            SummaryProgressCard(summary: summary, metrics: metrics)
                .frame(height: metrics.summaryProgressHeight)

            Spacer(minLength: 0)

            newWorkoutButton
                .frame(height: metrics.summaryButtonHeight)
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
                .font(.system(size: metrics.headerTitleSize * (metrics.isLandscape ? 0.86 : 0.72), weight: .black, design: .rounded))
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
        .frame(maxWidth: .infinity, maxHeight: metrics.isLandscape ? nil : metrics.summaryButtonHeight)
    }

    private var summaryBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(.white.opacity(0.12), lineWidth: 1)
            .allowsHitTesting(false)
    }

    private var summarySpacing: CGFloat {
        metrics.summarySectionSpacing
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
                .font(.system(size: metrics.isLandscape ? 13 : 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            Text(value)
                .font(.system(size: metrics.isLandscape ? 24 : 23, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, metrics.isLandscape ? 8 : 7)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryZoneBreakdown: View {
    let summary: WorkoutSummary
    let metrics: DashboardMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 8 : 6) {
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
                .font(.system(size: metrics.isLandscape ? 15 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(1)
            }
        }
        .padding(metrics.isLandscape ? metrics.cardPadding : 10)
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
        VStack(alignment: .leading, spacing: metrics.isLandscape ? 7 : 5) {
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
        .padding(metrics.isLandscape ? metrics.cardPadding : 10)
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
        .font(.system(size: metrics.isLandscape ? 15 : 14, weight: .bold, design: .rounded))
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
