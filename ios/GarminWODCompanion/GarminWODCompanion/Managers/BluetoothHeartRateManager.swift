import CoreBluetooth
import Foundation

enum HeartRateSource: String, CaseIterable, Identifiable {
    case mock
    case bluetooth

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .mock:
            return "Mock HR"
        case .bluetooth:
            return "Bluetooth HR"
        }
    }
}

enum BluetoothHeartRateConnectionState: String {
    case bluetoothUnavailable = "Bluetooth unavailable"
    case bluetoothUnauthorized = "Bluetooth unauthorized"
    case poweredOff = "Bluetooth off"
    case idle = "Idle"
    case scanning = "Scanning"
    case deviceFound = "Device found"
    case connecting = "Connecting"
    case reconnecting = "Reconnecting…"
    case connected = "Connected"
    case disconnected = "Disconnected"
    case failed = "Failed"

    var isConnected: Bool {
        self == .connected
    }
}

struct BluetoothHeartRateDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
}

final class BluetoothHeartRateManager: NSObject, ObservableObject {
    static let heartRateServiceUUID = CBUUID(string: "180D")
    static let heartRateMeasurementUUID = CBUUID(string: "2A37")
    static let bodySensorLocationUUID = CBUUID(string: "2A38")
    static let batteryServiceUUID = CBUUID(string: "180F")
    static let batteryLevelUUID = CBUUID(string: "2A19")
    static let lastHeartRatePeripheralUUIDKey = "lastHeartRatePeripheralUUID"

    @Published private(set) var connectionState: BluetoothHeartRateConnectionState = .idle
    @Published private(set) var discoveredDevices: [BluetoothHeartRateDevice] = []
    @Published private(set) var connectedPeripheralName: String?
    @Published private(set) var currentHeartRate: Int?
    @Published private(set) var averageHeartRate: Int = 0
    @Published private(set) var maximumHeartRate: Int = 0
    @Published private(set) var zoneTimes: [Int: Int] = [:]
    @Published private(set) var lastHeartRateUpdate: Date?
    @Published private(set) var batteryPercentage: Int?
    @Published private(set) var errorMessage: String?

    let zones: [HeartRateZone]

    private var centralManager: CBCentralManager?
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var reconnectTimeoutTimer: Timer?
    private var autoReconnectPeripheralID: UUID?
    private var hasAttemptedAutoReconnect = false
    private var reconnectAttempts = 0
    private let maximumReconnectAttempts = 2
    private let reconnectTimeoutSeconds: TimeInterval = 8
    private var sampleCount = 0
    private var sampleTotal = 0

    init(zones: [HeartRateZone] = HeartRateZone.defaultZones) {
        self.zones = zones
        super.init()
        print("[LIFECYCLE] BluetoothHeartRateManager init")
        resetZoneTimes()
        ensureCentralManager()
    }

    deinit {
        print("[LIFECYCLE] BluetoothHeartRateManager deinit")
        reconnectTimeoutTimer?.invalidate()
        stopScan()
        disconnect(clearSavedPeripheral: false)
    }

    var currentZone: HeartRateZone {
        guard let currentHeartRate else {
            return HeartRateZone.belowZone
        }

        return zones.first { $0.contains(currentHeartRate) } ?? HeartRateZone.belowZone
    }

    var zoneTimeSummary: [(zone: HeartRateZone, seconds: Int)] {
        ([HeartRateZone.belowZone] + zones).map { zone in
            (zone: zone, seconds: zoneTimes[zone.id, default: 0])
        }
    }

    var sourceLabel: String {
        if let connectedPeripheralName, connectionState == .connected {
            return "\(connectedPeripheralName) connected"
        }

        return connectionState.rawValue
    }

    func startScan() {
        ensureCentralManager()

        guard let centralManager else {
            setState(.bluetoothUnavailable)
            return
        }

        switch centralManager.state {
        case .poweredOn:
            guard !centralManager.isScanning else {
                return
            }

            errorMessage = nil
            discoveredDevices = []
            peripheralsByID = [:]
            setState(.scanning)
            centralManager.scanForPeripherals(
                withServices: [Self.heartRateServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        case .unauthorized:
            setState(.bluetoothUnauthorized)
        case .poweredOff:
            hasAttemptedAutoReconnect = false
            setState(.poweredOff)
        case .unsupported, .unknown, .resetting:
            setState(.bluetoothUnavailable)
        @unknown default:
            setState(.bluetoothUnavailable)
        }
    }

    func stopScan() {
        centralManager?.stopScan()
        if connectionState == .scanning {
            setState(.idle)
        }
    }

    func connect(to device: BluetoothHeartRateDevice) {
        guard let peripheral = peripheralsByID[device.id] else {
            errorMessage = "Device is no longer available."
            setState(.failed)
            return
        }

        connect(to: peripheral, state: .connecting, isAutoReconnect: false)
    }

    func disconnect() {
        disconnect(clearSavedPeripheral: true)
    }

    func attemptAutoReconnectIfPossible() {
        ensureCentralManager()

        guard let centralManager, centralManager.state == .poweredOn else {
            return
        }

        guard !hasAttemptedAutoReconnect,
              connectedPeripheral == nil,
              connectionState != .scanning,
              connectionState != .connecting,
              connectionState != .reconnecting,
              let savedIdentifier = savedPeripheralIdentifier else {
            return
        }

        hasAttemptedAutoReconnect = true
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [savedIdentifier])

        guard let peripheral = peripherals.first else {
            errorMessage = "Last heart-rate monitor was not found."
            setState(.disconnected)
            return
        }

        peripheralsByID[peripheral.identifier] = peripheral
        connect(to: peripheral, state: .reconnecting, isAutoReconnect: true)
    }

    private func disconnect(clearSavedPeripheral: Bool) {
        reconnectTimeoutTimer?.invalidate()
        reconnectTimeoutTimer = nil
        stopScan()

        if clearSavedPeripheral {
            clearSavedPeripheralIdentifier()
        }

        guard let connectedPeripheral else {
            setState(.idle)
            return
        }

        centralManager?.cancelPeripheralConnection(connectedPeripheral)
        self.connectedPeripheral = nil
        connectedPeripheralName = nil
        setState(.disconnected)
    }

    func rescan() {
        disconnect(clearSavedPeripheral: false)
        startScan()
    }

    func resetMetrics() {
        sampleCount = 0
        sampleTotal = 0
        averageHeartRate = 0
        maximumHeartRate = 0
        resetZoneTimes()
    }

    func tickZoneTimeIfWorkoutRunning() {
        guard connectionState == .connected, currentHeartRate != nil else {
            return
        }

        zoneTimes[currentZone.id, default: 0] += 1
    }

    static func parseHeartRateMeasurement(_ data: Data) -> Int? {
        guard data.count >= 2 else {
            return nil
        }

        let flags = data[0]
        let isUInt16 = (flags & 0x01) == 0x01

        if isUInt16 {
            guard data.count >= 3 else {
                return nil
            }

            return Int(data[1]) | (Int(data[2]) << 8)
        }

        return Int(data[1])
    }

    private func ensureCentralManager() {
        guard centralManager == nil else {
            return
        }

        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    private var savedPeripheralIdentifier: UUID? {
        guard let value = UserDefaults.standard.string(forKey: Self.lastHeartRatePeripheralUUIDKey) else {
            return nil
        }

        return UUID(uuidString: value)
    }

    private func savePeripheralIdentifier(_ identifier: UUID) {
        UserDefaults.standard.set(identifier.uuidString, forKey: Self.lastHeartRatePeripheralUUIDKey)
        print("[BLE] saved peripheral UUID=\(identifier.uuidString)")
    }

    private func clearSavedPeripheralIdentifier() {
        UserDefaults.standard.removeObject(forKey: Self.lastHeartRatePeripheralUUIDKey)
        print("[BLE] cleared saved peripheral UUID")
    }

    private func connect(
        to peripheral: CBPeripheral,
        state: BluetoothHeartRateConnectionState,
        isAutoReconnect: Bool
    ) {
        reconnectTimeoutTimer?.invalidate()
        reconnectTimeoutTimer = nil
        stopScan()
        errorMessage = nil
        reconnectAttempts = 0
        autoReconnectPeripheralID = isAutoReconnect ? peripheral.identifier : nil
        connectedPeripheral = peripheral
        connectedPeripheralName = displayName(for: peripheral)
        peripheral.delegate = self
        setState(state)
        centralManager?.connect(peripheral, options: nil)

        if isAutoReconnect {
            scheduleReconnectTimeout(for: peripheral.identifier)
        }
    }

    private func scheduleReconnectTimeout(for identifier: UUID) {
        reconnectTimeoutTimer = Timer.scheduledTimer(withTimeInterval: reconnectTimeoutSeconds, repeats: false) { [weak self] _ in
            guard let self,
                  self.connectionState == .reconnecting,
                  self.autoReconnectPeripheralID == identifier else {
                return
            }

            self.errorMessage = "Unable to reconnect to last heart-rate monitor."
            if let connectedPeripheral = self.connectedPeripheral,
               connectedPeripheral.identifier == identifier {
                self.centralManager?.cancelPeripheralConnection(connectedPeripheral)
            }
            self.connectedPeripheral = nil
            self.connectedPeripheralName = nil
            self.autoReconnectPeripheralID = nil
            self.setState(.disconnected)
        }
    }

    private func recordHeartRateSample(_ heartRate: Int) {
        guard (30...250).contains(heartRate) else {
            return
        }

        currentHeartRate = heartRate
        lastHeartRateUpdate = Date()
        sampleCount += 1
        sampleTotal += heartRate
        averageHeartRate = sampleTotal / max(sampleCount, 1)
        maximumHeartRate = max(maximumHeartRate, heartRate)
    }

    private func resetZoneTimes() {
        zoneTimes = [:]
        zones.forEach { zoneTimes[$0.id] = 0 }
        zoneTimes[HeartRateZone.belowZone.id] = 0
    }

    private func setState(_ state: BluetoothHeartRateConnectionState) {
        connectionState = state
        print("[BLE] state=\(state.rawValue)")
    }

    private func displayName(for peripheral: CBPeripheral) -> String {
        peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? peripheral.name!
            : "Heart Rate Monitor"
    }
}

extension BluetoothHeartRateManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            setState(.idle)
            attemptAutoReconnectIfPossible()
        case .unauthorized:
            setState(.bluetoothUnauthorized)
        case .poweredOff:
            setState(.poweredOff)
        case .unsupported:
            setState(.bluetoothUnavailable)
        case .resetting, .unknown:
            setState(.bluetoothUnavailable)
        @unknown default:
            setState(.bluetoothUnavailable)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        peripheralsByID[peripheral.identifier] = peripheral
        let device = BluetoothHeartRateDevice(
            id: peripheral.identifier,
            name: displayName(for: peripheral),
            rssi: RSSI.intValue
        )

        if let existingIndex = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[existingIndex] = device
        } else {
            discoveredDevices.append(device)
        }

        setState(.deviceFound)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        reconnectTimeoutTimer?.invalidate()
        reconnectTimeoutTimer = nil
        autoReconnectPeripheralID = nil
        connectedPeripheral = peripheral
        connectedPeripheralName = displayName(for: peripheral)
        reconnectAttempts = 0
        savePeripheralIdentifier(peripheral.identifier)
        setState(.connected)
        peripheral.discoverServices([
            Self.heartRateServiceUUID,
            Self.batteryServiceUUID
        ])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let wasAutoReconnect = autoReconnectPeripheralID == peripheral.identifier
        reconnectTimeoutTimer?.invalidate()
        reconnectTimeoutTimer = nil
        autoReconnectPeripheralID = nil
        errorMessage = error?.localizedDescription ?? "Unable to connect."
        setState(wasAutoReconnect ? .disconnected : .failed)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        reconnectTimeoutTimer?.invalidate()
        reconnectTimeoutTimer = nil
        autoReconnectPeripheralID = nil
        errorMessage = error?.localizedDescription
        setState(.disconnected)

        guard peripheral.identifier == connectedPeripheral?.identifier else {
            return
        }

        if reconnectAttempts < maximumReconnectAttempts {
            reconnectAttempts += 1
            setState(.connecting)
            central.connect(peripheral, options: nil)
        }
    }
}

extension BluetoothHeartRateManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            setState(.failed)
            return
        }

        peripheral.services?.forEach { service in
            switch service.uuid {
            case Self.heartRateServiceUUID:
                peripheral.discoverCharacteristics([
                    Self.heartRateMeasurementUUID,
                    Self.bodySensorLocationUUID
                ], for: service)
            case Self.batteryServiceUUID:
                peripheral.discoverCharacteristics([Self.batteryLevelUUID], for: service)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            setState(.failed)
            return
        }

        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == Self.heartRateMeasurementUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == Self.batteryLevelUUID {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            return
        }

        guard let data = characteristic.value else {
            return
        }

        if characteristic.uuid == Self.heartRateMeasurementUUID,
           let bpm = Self.parseHeartRateMeasurement(data) {
            recordHeartRateSample(bpm)
        } else if characteristic.uuid == Self.batteryLevelUUID,
                  let battery = data.first {
            batteryPercentage = Int(battery)
        }
    }
}
