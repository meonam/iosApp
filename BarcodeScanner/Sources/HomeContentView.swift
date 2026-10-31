import SwiftUI

public struct HomeContentView: View {
    @Binding var selectedTab: Int
    @State private var versionInfo: String = "Phiên bản: 1.4.6"
    @State private var loadingStatus: String = "Hệ thống & CSDL sẵn sàng"
    @State private var showGuideSheet: Bool = false
    @State private var progress: Int = 100
    @State private var showProgress: Bool = false
    
    // Màu hồng chuẩn Android BarcodeScanner (@color/pink = #E91E63)
    private let pinkColor = Color(red: 233/255, green: 30/255, blue: 99/255)
    
    public init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar màu hồng giống Android (@color/pink)
            ZStack {
                pinkColor
                    .frame(height: 54)
                
                Text("Barcode Scanner")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            ScrollView {
                VStack(spacing: 16) {
                    Spacer().frame(height: 10)
                    
                    // 1. Logo tròn viền kép đồng bộ 100% Android
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        pinkColor.opacity(0.15),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(pinkColor.opacity(0.3), lineWidth: 2)
                            )
                        
                        if let uiImage = UIImage(named: "ic_sodo") ?? UIImage(contentsOfFile: Bundle.main.path(forResource: "ic_sodo", ofType: "png") ?? "") {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 85, height: 85)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 58))
                                .foregroundColor(pinkColor)
                        }
                    }
                    .padding(.top, 10)
                    
                    // 2. Title Card giống Android (OS + Version chip)
                    VStack(spacing: 8) {
                        Text("OS: iOS 15+, iPhone / iPad")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(pinkColor)
                            .multilineTextAlignment(.center)
                        
                        // Version chip
                        Text(versionInfo)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(pinkColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(pinkColor.opacity(0.12))
                            .cornerRadius(16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                    
                    // 3. Nút Xem hướng dẫn sử dụng giống Android ("👉 Xem hướng dẫn sử dụng ->")
                    Button(action: {
                        showGuideSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Text("👉")
                                .font(.system(size: 16))
                            Text("Xem hướng dẫn sử dụng")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.blue)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // 4. Loading / System Status Card giống Android
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            
                            Text(loadingStatus)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        if showProgress {
                            ProgressView(value: Double(progress), total: 100.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: pinkColor))
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                    
                    Spacer(minLength: 30)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
        .sheet(isPresented: $showGuideSheet) {
            GuideSheetView()
        }
    }
}

// MARK: - GuideSheetView (Hướng dẫn sử dụng hiển thị chi tiết khi bấm)
public struct GuideSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Chủ đề hướng dẫn", selection: $selectedTab) {
                    Text("Quét mã").tag(0)
                    Text("Gửi Wi-Fi").tag(1)
                    Text("Xuất file").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if selectedTab == 0 {
                            guideSection(
                                title: "1. Quét mã & Kiểm kê kho",
                                items: [
                                    "Bật tab 'Quét mã' trên thanh điều hướng dưới cùng.",
                                    "Nhấn nút xanh lá [Quét mã] để mở Camera và tia laser quét barcode tự động.",
                                    "Bạn có thể nhập barcode thủ công hoặc chỉnh số lượng trong ô Số lượng.",
                                    "Nhấn Return/Done trên bàn phím để lưu bản ghi vào danh sách.",
                                    "Nhấn nút [Delete] màu đỏ để xoá toàn bộ danh sách khi cần làm mới."
                                ]
                            )
                        } else if selectedTab == 1 {
                            guideSection(
                                title: "2. Gửi dữ liệu qua NET (Wi-Fi)",
                                items: [
                                    "Mở phần mềm ASSET INVENTORY hoặc DATALOGIC MEMOR trên máy tính PC.",
                                    "Chuyển sang tab 'Gửi qua NET' trên ứng dụng iOS.",
                                    "Bấm [Quét QR PC] để quét mã QR UID hiển thị trên màn hình máy tính.",
                                    "Nhấn [Gửi dữ liệu] để truyền toàn bộ số liệu kiểm kê sang máy tính ngay lập tức.",
                                    "Sau khi đổ xong, nhớ bấm [Xóa dữ liệu] để làm sạch kho cho ca kiểm tiếp theo."
                                ]
                            )
                        } else {
                            guideSection(
                                title: "3. Xuất file & Chia sẻ",
                                items: [
                                    "Tại tab 'Quét mã', bấm nút [Xuất file] ở góc trên bảng kiểm kê.",
                                    "Tệp dữ liệu KiemKe_<thời_gian>.txt sẽ được tự động tạo.",
                                    "Bạn có thể gửi tệp qua AirDrop, Zalo, Email hoặc lưu vào ứng dụng Tệp (Files)."
                                ]
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Hướng Dẫn Sử Dụng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
    
    private func guideSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.blue)
            
            ForEach(items.indices, id: \.self) { idx in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(items[idx])
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
