# Hướng Dẫn Triển Khai Ứng Dụng iOS Với GitHub Actions

Thư mục này chứa toàn bộ khung dự án **iOS (iPhone/iPad)** và kịch bản CI/CD tự động build bằng **GitHub Actions** mà không cần máy tính Mac.

---

## 1. Cấu Trúc Thư Mục
* `iosApp/iosApp/iOSApp.swift`: Điểm khởi chạy ứng dụng iOS.
* `iosApp/iosApp/ContentView.swift`: Giao diện ứng dụng iOS (kết nối Compose Multiplatform).
* `iosApp/iosApp/Info.plist`: Cấu hình xin quyền Camera (quét mã QR/Barcode), Quyền vị trí (GPS), Quyền Bluetooth (in nhiệt).
* `iosApp/iosApp.xcodeproj/`: File dự án Xcode tiêu chuẩn của Apple.
* `.github/workflows/ios-build.yml`: Kịch bản GitHub Actions tự động build file `.ipa` trên máy chủ đám mây macOS Apple Silicon.

---

## 2. Các Bước Để Kích Hoạt Build Tự Động Trên GitHub

### Bước 1: Khởi tạo Git và Đẩy Code Lên GitHub
Mở PowerShell tại thư mục dự án và chạy:
```powershell
# 1. Khởi tạo kho lưu trữ Git
git init

# 2. Thêm toàn bộ mã nguồn
git add .

# 3. Tạo commit đầu tiên
git commit -m "feat: setup iOS project and GitHub Actions CI/CD workflows"

# 4. Đổi tên nhánh sang main
git branch -M main

# 5. Liên kết với kho GitHub của bạn (thay bằng URL GitHub thật của bạn)
git remote add origin https://github.com/<tai-khoan-cua-ban>/QLTB.git

# 6. Đẩy mã nguồn lên GitHub
git push -u origin main
```

### Bước 2: Xem Quá Trình Build Trên GitHub
1. Truy cập vào trang GitHub repository của bạn.
2. Bấm vào tab **Actions** ở menu phía trên.
3. Bạn sẽ thấy quy trình **"Build iOS App (.IPA) via GitHub Actions"** đang tự động chạy trên máy ảo **macOS**.
4. Khi quá trình build báo màu xanh (Success), bấm vào tên bản build:
   * Kéo xuống mục **Artifacts** ở dưới cùng.
   * Bấm vào **`QLTB-iOS-App-IPA`** để tải file `.ipa` về máy!

---

## 3. Cách Cài Đặt File `.ipa` Lên iPhone

* **Cách 1 (Miễn phí qua Sideloadly / AltStore):**
  * Tải công cụ **Sideloadly** (trên máy tính Windows).
  * Cắm iPhone vào máy tính qua cáp sạc USB.
  * Kéo file `QLTB_iOS_v1.0.0.ipa` vào Sideloadly, nhập Apple ID của bạn để cài trực tiếp vào iPhone.
* **Cách 2 (Qua Apple TestFlight):**
  * Nếu có tài khoản Apple Developer 99$/năm, thêm App Store Connect API Key vào GitHub Secrets để GitHub Actions đẩy thẳng app lên TestFlight.
