# HƯỚNG DẪN DỰ ÁN BARCODE SCANNER CHO iOS

Ứng dụng **BarcodeScanner** dành cho hệ điều hành Apple iOS (iPhone / iPad), được thiết kế tương thích **100%** cả về giao diện, tính năng, định dạng cơ sở dữ liệu và giao thức truyền dữ liệu với ứng dụng Android hiện tại cùng 2 phần mềm trên máy tính: **ASSET INVENTORY** và **DATALOGIC MEMOR**.

---

## 1. Cấu Trúc Dự Án (`E:\CODE\iOS\BarcodeScanner`)

```
E:\CODE\iOS\BarcodeScanner\
├── Package.swift                             # Cấu hình Swift Package Manager (SPM)
└── BarcodeScanner\
    ├── Resources\
    │   └── Info.plist                        # Quyền Camera, UIFileSharingEnabled (USB Cable)
    └── Sources\
        ├── BarcodeScannerApp.swift           # Điểm khởi chạy chính (@main SwiftUI)
        ├── MainTabView.swift                 # Điều hướng 5 Tab giống hệt Android
        ├── ScanBarcodeView.swift             # Màn hình Quét mã vạch (Camera Viewfinder + Laser line)
        ├── KiemKeListView.swift              # Bảng kiểm kê kho (STT, Mã, SL, Sửa, Xoá, Xuất file)
        ├── WifiSyncView.swift                # Màn hình truyền Wi-Fi/Internet (Nhập/Quét UID máy tính)
        ├── SettingsView.swift                # Cài đặt loại mã vạch (EAN-13, EAN-8, UPC-A, Code128,...)
        ├── InfoView.swift                    # Thông tin máy, phiên bản 1.4.0, bản quyền Co.opmart
        ├── InventoryItem.swift               # Model dữ liệu dòng kiểm kê
        ├── DatabaseHelper.swift              # Quản lý SQLite C-API (KIEMKHO.sqlite trong Documents)
        ├── CameraScannerView.swift           # Trình quét camera tốc độ cao AVFoundation + Rung/Bíp
        └── FirebaseSyncService.swift         # Kết nối Firebase RTDB truyền không dây tới PC
```

---

## 2. Tính Tương Thích Tuyệt Đối Với PC (ASSET INVENTORY & DATALOGIC MEMOR)

### A. Cấu trúc Cơ Sở Dữ Liệu `KIEMKHO.sqlite`
- Tệp database được lưu trực tiếp tại thư mục `Documents` của ứng dụng trên iOS.
- **Bảng `INVENTORY`**:
  ```sql
  CREATE TABLE IF NOT EXISTS INVENTORY (
      STT INTEGER PRIMARY KEY AUTOINCREMENT,
      Barcode TEXT NOT NULL,
      Quantity REAL NOT NULL
  );
  ```
- **Bảng `Products`**: Danh mục tên sản phẩm.
- **Bảng chữ ký bảo mật `_BARCODE_SCANNER_SIGNATURE`**:
  ```sql
  INSERT OR REPLACE INTO _BARCODE_SCANNER_SIGNATURE VALUES (
      'SIGNATURE',
      'HUYENHAN_BARCODESCANNER_SECURE_TOKEN_2026',
      datetime('now')
  );
  ```
  *(Chữ ký này bắt buộc để ASSET INVENTORY và DATALOGIC MEMOR xác thực file hợp lệ và mở khoá tính năng sửa/xoá trên PC).*

---

### B. Phương Án Lấy Dữ Liệu Qua Cáp USB (Tối Ưu & Thuận Tiện Nhất)
Apple áp dụng cơ chế bảo mật Sandbox nghiêm ngặt. Để máy tính PC có thể lấy dữ liệu qua cáp USB giống Android:
1. Trong file [Info.plist](file:///E:/CODE/iOS/BarcodeScanner/BarcodeScanner/Resources/Info.plist), hai cờ chia sẻ tệp của Apple đã được bật sẵn:
   - `UIFileSharingEnabled = true` (Bật tính năng iTunes File Sharing)
   - `LSSupportsOpeningDocumentsInPlace = true`
2. **Cách PC lấy dữ liệu qua cáp:**
   - Khi cắm iPhone vào máy tính PC bằng cáp Lightning / Type-C:
     - Thư mục `Documents` của app `BarcodeScanner` sẽ xuất hiện ngay trên máy tính (qua Apple Devices / iTunes / 3uTools / iMazing / libimobiledevice).
     - File `KIEMKHO.sqlite` và `WINCE.txt` nằm ngay tại đây.
     - Người dùng hoặc phần mềm PC có thể sao chép / kéo file trực tiếp vào máy tính trong 1 giây mà không cần bẻ khoá (jailbreak) thiết bị.

---

### C. Phương Án Truyền Không Dây Qua Wi-Fi / Internet
- Hoạt động tương thích 100% với hệ thống Firebase Realtime Database hiện hành của ứng dụng Android:
  - **Firebase URL**: `https://barcodescanner-cc3ab-default-rtdb.asia-southeast1.firebasedatabase.app`
  - **Kênh đẩy dữ liệu**: `inventory_data/{pcUid}/{pushKey}.json`
  - **Kênh xác nhận ACK**: `inventory_acks/{pcUid}/{pushKey}.json` (`status: "CONFIRMED"`)
- Người dùng chỉ cần nhập mã UID hoặc bấm **"Quét QR"** để quét mã QR hiển thị trên màn hình PC, sau đó bấm **"GỬI DỮ LIỆU ĐẾN MÁY TÍNH"**. Cả hai phần mềm **ASSET INVENTORY** và **DATALOGIC MEMOR** đều sẽ tự động nhận dữ liệu ngay lập tức.

---

## 3. Cách Biên Dịch & Cài Đặt Lên iPhone

Có thể cài đặt ứng dụng lên iPhone theo các cách sau:
1. **Dùng Xcode (macOS hoặc máy Mac / Hackintosh / Mac ảo)**:
   - Mở thư mục `E:\CODE\iOS\BarcodeScanner` trong Xcode.
   - Chọn Team Developer cá nhân (miễn phí) và cắm iPhone vào nhấn **Run (Build & Install)**.
2. **Dùng AltServer / Sideloadly (Trực tiếp từ Windows)**:
   - Máy tính hiện đã cài đặt sẵn **AltServer** (`C:\Program Files (x86)\AltServer`).
   - Có thể xuất file `.ipa` hoặc dùng Sideloadly/AltServer để nạp trực tiếp file cài đặt lên iPhone bằng cáp USB với Apple ID cá nhân.
