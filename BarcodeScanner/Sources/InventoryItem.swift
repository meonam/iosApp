import Foundation

public struct InventoryItem: Identifiable, Codable, Equatable {
    public var id: Int64 { stt }
    public var stt: Int64
    public var barcode: String
    public var quantity: Double
    
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
