import Foundation
import CoreBluetooth
import UIKit

public struct BluetoothPrinterDevice: Identifiable, Hashable {
    public var id: UUID { peripheral.identifier }
    public let peripheral: CBPeripheral
    public let name: String
    public let rssi: NSNumber
}

public class BluetoothPrinterService: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    public static let shared = BluetoothPrinterService()

    @Published public var isScanning: Bool = false
    @Published public var discoveredPrinters: [BluetoothPrinterDevice] = []
    @Published public var connectedPeripheral: CBPeripheral? = nil
    @Published public var isConnected: Bool = false
    @Published public var statusMessage: String = "Sẵn sàng"

    private var centralManager: CBCentralManager?
    private var writeCharacteristic: CBCharacteristic?

    // Common Printer & Serial Service UUIDs
    private let targetServiceUUIDs: [CBUUID] = [
        CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"), // Common BLE Serial
        CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455"), // ISSC Serial
        CBUUID(string: "18F0"), // Bluetooth Printer Service
        CBUUID(string: "AF30"),
        CBUUID(string: "FF00")
    ]

    private override init() {
        super.init()
    }

    public func start() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    public func startScan() {
        guard let central = centralManager, central.state == .poweredOn else {
            statusMessage = "Bluetooth chưa được bật"
            return
        }
        discoveredPrinters.removeAll()
        isScanning = true
        statusMessage = "Đang tìm máy in Bluetooth..."
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        // Auto-stop scan after 15s
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isScanning == true {
                self?.stopScan()
            }
        }
    }

    public func stopScan() {
        centralManager?.stopScan()
        isScanning = false
        statusMessage = "Đã dừng quét"
    }

    public func connect(to device: BluetoothPrinterDevice) {
        stopScan()
        statusMessage = "Đang kết nối tới \(device.name)..."
        connectedPeripheral = device.peripheral
        device.peripheral.delegate = self
        centralManager?.connect(device.peripheral, options: nil)
    }

    public func disconnect() {
        if let p = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(p)
        }
    }

    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth đã sẵn sàng"
        case .poweredOff:
            statusMessage = "Bluetooth đã tắt"
            isConnected = false
            connectedPeripheral = nil
        case .unauthorized:
            statusMessage = "Chưa cấp quyền Bluetooth trong Cài đặt"
        default:
            statusMessage = "Trạng thái Bluetooth: \(central.state.rawValue)"
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Máy in Bluetooth"
        if !discoveredPrinters.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let item = BluetoothPrinterDevice(peripheral: peripheral, name: name, rssi: RSSI)
            discoveredPrinters.append(item)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        statusMessage = "Đã kết nối: \(peripheral.name ?? "Máy in")"
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        statusMessage = "Lỗi kết nối: \(error?.localizedDescription ?? "Không xác định")"
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        writeCharacteristic = nil
        statusMessage = "Đã ngắt kết nối máy in"
    }

    // MARK: - CBPeripheralDelegate
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = char
                statusMessage = "Máy in đã sẵn sàng nhận lệnh"
                break
            }
        }
    }

    // MARK: - ESC/POS Command Generation & Printing
    public func printData(_ data: Data) {
        guard let p = connectedPeripheral, let char = writeCharacteristic else {
            statusMessage = "Chưa kết nối máy in hoặc không tìm thấy cổng ghi"
            return
        }

        let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

        // Send in chunks of 100 bytes to avoid BLE MTU overflow
        let chunkSize = 100
        var offset = 0
        while offset < data.count {
            let length = min(chunkSize, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset + length))
            p.writeValue(chunk, for: char, type: writeType)
            offset += length
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    public func printText(_ text: String, align: Int = 0, isBold: Bool = false) {
        var cmd = Data()
        // ESC @: Init
        cmd.append(contentsOf: [0x1B, 0x40])
        // ESC a n: Alignment (0: Left, 1: Center, 2: Right)
        cmd.append(contentsOf: [0x1B, 0x61, UInt8(align)])
        // ESC E n: Bold
        cmd.append(contentsOf: [0x1B, 0x45, isBold ? 1 : 0])

        // Text data
        if let textData = text.data(using: .utf8) {
            cmd.append(textData)
        }
        cmd.append(contentsOf: [0x0A]) // LF
        printData(cmd)
    }

    public func printCutPaper() {
        var cmd = Data()
        cmd.append(contentsOf: [0x0A, 0x0A, 0x0A])
        cmd.append(contentsOf: [0x1D, 0x56, 0x42, 0x00]) // GS V 66 0
        printData(cmd)
    }

    // MARK: - AirPrint & PDF Document Printing (Hỗ trợ in WiFi/LAN/AirPrint & Xuất PDF)
    public func printViaAirPrint(from view: UIView, documentData: Data, jobName: String = "QLTB_InTem") {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = jobName
        printInfo.duplex = .none
        printController.printInfo = printInfo
        printController.printingItem = documentData

        printController.present(animated: true) { _, completed, error in
            if completed {
                self.statusMessage = "In thành công"
            } else if let error = error {
                self.statusMessage = "Lỗi in: \(error.localizedDescription)"
            }
        }
    }
}
