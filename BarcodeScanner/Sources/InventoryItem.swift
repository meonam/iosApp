import Foundation

public struct InventoryItem: Identifiable, Codable, Equatable {
    public var id: Int64 { stt }
    public var stt: Int64
    public var barcode: String
    public var quantity: Double
    
    public var formattedQuantity: String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.2f", quantity)
        }
    }
    
    public init(stt: Int64, barcode: String, quantity: Double) {
        self.stt = stt
        self.barcode = barcode
        self.quantity = quantity
    }
}

public struct ProductItem: Codable {
    public var barcode: String
    public var productName: String
    
    public init(barcode: String, productName: String) {
        self.barcode = barcode
        self.productName = productName
    }
}
