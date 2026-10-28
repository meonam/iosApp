import Foundation
import SQLite3

public final class DatabaseHelper {
    public static let shared = DatabaseHelper()
    
    private var db: OpaquePointer?
    private let dbFileName = "KIEMKHO.sqlite"
    private let lock = NSLock()
    
    public var dbURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(dbFileName)
    }
    
    private init() {
        openDatabase()
        ensureTablesExist()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    private func openDatabase() {
        let path = dbURL.path
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("DatabaseHelper: Không thể mở CSDL SQLite tại \(path)")
        } else {
            print("DatabaseHelper: Đã mở CSDL tại: \(path)")
        }
    }
    
    private func ensureTablesExist() {
        lock.lock()
        defer { lock.unlock() }
        
        let createInventorySql = """
        CREATE TABLE IF NOT EXISTS INVENTORY (
            STT INTEGER PRIMARY KEY AUTOINCREMENT,
            Barcode TEXT NOT NULL,
            Quantity REAL NOT NULL
        );
        """
        
        let createProductsSql = """
        CREATE TABLE IF NOT EXISTS Products (
            barcode TEXT PRIMARY KEY,
            product_name TEXT
        );
        """
        
        let createSignatureSql = """
        CREATE TABLE IF NOT EXISTS _BARCODE_SCANNER_SIGNATURE (
            id TEXT PRIMARY KEY,
            app_token TEXT,
            created_at TEXT
        );
        INSERT OR REPLACE INTO _BARCODE_SCANNER_SIGNATURE VALUES (
            'SIGNATURE',
            'HUYENHAN_BARCODESCANNER_SECURE_TOKEN_2026',
            datetime('now')
        );
        """
        
        execute(sql: createInventorySql)
        execute(sql: createProductsSql)
        execute(sql: createSignatureSql)
    }
    
    @discardableResult
    private func execute(sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                print("DatabaseHelper Error: \(String(cString: err))")
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }
    
    // MARK: - CRUD Operations
    
    public func insertItem(barcode: String, quantity: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let sql = "INSERT INTO INVENTORY (Barcode, Quantity) VALUES (?, ?);"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (barcode as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, quantity)
            
            let success = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            return success
        }
        return false
    }
    
    public func updateItem(stt: Int64, barcode: String, quantity: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let sql = "UPDATE INVENTORY SET Barcode = ?, Quantity = ? WHERE STT = ?;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (barcode as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, quantity)
            sqlite3_bind_int64(stmt, 3, stt)
            
            let success = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            return success
        }
        return false
    }
    
    public func deleteItem(stt: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let sql = "DELETE FROM INVENTORY WHERE STT = ?;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, stt)
            let success = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            return success
        }
        return false
    }
    
    public func clearAll() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return execute(sql: "DELETE FROM INVENTORY;")
    }
    
    public func getAllItems() -> [InventoryItem] {
        lock.lock()
        defer { lock.unlock() }
        
        var list = [InventoryItem]()
        let sql = "SELECT STT, Barcode, Quantity FROM INVENTORY ORDER BY STT ASC;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let stt = sqlite3_column_int64(stmt, 0)
                let barcodePtr = sqlite3_column_text(stmt, 1)
                let barcode = barcodePtr != nil ? String(cString: barcodePtr!) : ""
                let quantity = sqlite3_column_double(stmt, 2)
                
                list.append(InventoryItem(stt: stt, barcode: barcode, quantity: quantity))
            }
            sqlite3_finalize(stmt)
        }
        return list
    }
    
    public func getCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        let sql = "SELECT COUNT(*) FROM INVENTORY;"
        var stmt: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }
        return count
    }
    
    /// Xuất chuỗi định dạng văn bản (barcode,quantity) tương thích file WinCE.txt và Android
    public func exportToTextContent() -> String {
        let items = getAllItems()
        var result = ""
        for item in items {
            let qtyFormatted: String
            if item.quantity.truncatingRemainder(dividingBy: 1) == 0 {
                qtyFormatted = String(format: "%.0f", item.quantity)
            } else {
                qtyFormatted = String(format: "%.2f", item.quantity)
            }
            result += "\(item.barcode),\(qtyFormatted)\r\n"
        }
        return result
    }
}
