import SwiftUI

struct EnterpriseFeatureLockedView: View {
    let featureName: String
    let onUpgrade: () -> Void
    let onBack: () -> Void
    
    // We mock license fetching or just rely on arguments
    // In Android: val currentLic = LicenseManager.currentLicense.collectAsState().value
    @State private var isExpiredTrial = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.backward")
                        .foregroundColor(.white)
                }
                Text("Đặc Quyền Enterprise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.8)) // TopBarColor fallback
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    ZStack {
                        Circle()
                            .fill(Color(red: 254/255, green: 243/255, blue: 199/255))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "star.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color(red: 202/255, green: 138/255, blue: 4/255))
                    }
                    
                    Text(isExpiredTrial ? "Hết Hạn Dùng Thử Full VIP" : "Đặc Quyền Gói Enterprise / Dùng Thử VIP")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isExpiredTrial ? Color(red: 220/255, green: 38/255, blue: 38/255) : Color.blue) // SecondaryDarkBlue fallback
                        .multilineTextAlignment(.center)
                    
                    Text(isExpiredTrial ? "Thời hạn trải nghiệm trọn gói Full VIP của Doanh nghiệp đã kết thúc. Vui lòng liên hệ Super Admin hoặc nâng cấp gói để tiếp tục sử dụng tính năng \"\(featureName)\"." : "Tính năng \"\(featureName)\" là đặc quyền dành cho Gói Không Giới Hạn (Enterprise) hoặc Doanh nghiệp được cấp Dùng Thử Full VIP.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("👑 Mở khóa toàn diện trên Gói Enterprise:")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(Color(red: 133/255, green: 77/255, blue: 14/255))
                        
                        Text("• Tiếp nhận sự cố & HelpDesk trực tuyến thời gian thực")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 113/255, green: 63/255, blue: 18/255))
                        Text("• Chấm công KTV bằng GPS & Đo khoảng cách công tác phí OSRM")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 113/255, green: 63/255, blue: 18/255))
                        Text("• Báo cáo thống kê đánh giá chất lượng sao KTV")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 113/255, green: 63/255, blue: 18/255))
                        Text("• Không giới hạn số lượng thiết bị tài sản quản lý")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 113/255, green: 63/255, blue: 18/255))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 254/255, green: 249/255, blue: 195/255))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 253/255, green: 224/255, blue: 71/255), lineWidth: 1)
                    )
                    
                    Button(action: onUpgrade) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Xem bảng gói cước / Nhập Key")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.pink) // PrimaryPink fallback
                        .cornerRadius(12)
                    }
                    
                    Button(action: onBack) {
                        Text("Quay lại")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                }
                .padding(24)
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Determine if expired trial state if available
        }
    }
}
