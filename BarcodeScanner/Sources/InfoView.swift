import SwiftUI

public struct InfoView: View {
    let versionName: String = "1.4.0"
    let deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "N/A"
    let systemVersion: String = UIDevice.current.systemVersion
    let modelName: String = UIDevice.current.model
    
    @State private var showCopiedAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Banner
                VStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .padding(.top, 16)
                    
                    Text("BARCODE SCANNER iOS")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Phiên bản \(versionName) (Tương thích Android & PC)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                // Device Info Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("THÔNG TIN THIẾT BỊ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    InfoRow(label: "Model thiết bị:", value: modelName)
                    Divider()
                    InfoRow(label: "Hệ điều hành:", value: "iOS \(systemVersion)")
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device ID / UUID:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        HStack {
                            Text(deviceId)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = deviceId
                                showCopiedAlert = true
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                // Guide Card: Kết nối máy tính PC
                VStack(alignment: .leading, spacing: 10) {
                    Text("HƯỚNG DẪN KẾT NỐI PC")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Qua cáp USB: Cắm cáp vào máy tính. Mở DATALOGIC MEMOR hoặc ASSET INVENTORY, phần mềm tự động nhận diện iPhone và kéo file KIEMKHO.sqlite vào máy tính.")
                                .font(.system(size: 12))
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Qua Wi-Fi / Internet: Vào tab Wi-Fi, quét hoặc nhập mã UID từ màn hình phần mềm PC, nhấn 'GỬI DỮ LIỆU ĐẾN MÁY TÍNH'. PC sẽ nhận tức thì qua Firebase.")
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                // Copyright & Author
                VStack(spacing: 4) {
                    Text("Co.opmart Bến Tre © 2026")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Tác giả: Huyên Hân (han-lth)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert(isPresented: $showCopiedAlert) {
            Alert(
                title: Text("Đã sao chép"),
                message: Text("Mã thiết bị đã được sao chép vào bộ nhớ tạm."),
                dismissButton: .default(Text("Đóng"))
            )
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}
