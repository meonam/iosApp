import SwiftUI

// MARK: - MÀN HÌNH CẤU HÌNH HỆ THỐNG CHO ADMIN (ĐỒNG BỘ 1:1 THEO SYSTEM_SETTINGS TRÊN ANDROID)
public struct SystemSettingsView: View {
    var onBack: () -> Void

    @AppStorage("maintenanceMode") private var maintenanceMode: Bool = false
    @AppStorage("enablePushNotif") private var enablePushNotif: Bool = true
    @AppStorage("slaThresholdHours") private var slaThresholdHours: Int = 8
    @AppStorage("gpsCheckInRadius") private var gpsCheckInRadius: Int = 150
    @AppStorage("autoAssignTicket") private var autoAssignTicket: Bool = true

    @State private var showSavedAlert: Bool = false

    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // TopBar
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Cấu hình hệ thống Doanh nghiệp")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showSavedAlert = true }) {
                        Text("Lưu")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.appTopBarColor)

                // Nội dung cấu hình
                ScrollView {
                    VStack(spacing: 16) {
                        // Thẻ Thông tin Doanh nghiệp
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DOANH NGHIỆP TRỰC THUỘC")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.appTextSecondary)

                            HStack {
                                Image("logo_app")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                                    .cornerRadius(6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Saigon Co.op")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    Text("Mã công ty: SGCOOP • Gói: Enterprise Không giới hạn")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))

                        // Thẻ Cài đặt Vận hành & SLA
                        VStack(alignment: .leading, spacing: 12) {
                            Text("QUY CHUẨN XỬ LÝ SỰ CỐ & SLA KTV")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.appTextSecondary)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Thời hạn cam kết xử lý sự cố (SLA):")
                                        .font(.system(size: 13))
                                    Spacer()
                                    Picker("SLA", selection: $slaThresholdHours) {
                                        Text("4 giờ").tag(4)
                                        Text("8 giờ").tag(8)
                                        Text("24 giờ").tag(24)
                                        Text("48 giờ").tag(48)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }

                                Divider()

                                Toggle("Tự động phân bổ Ticket cho KTV gần nhất", isOn: $autoAssignTicket)
                                    .font(.system(size: 13))

                                Divider()

                                HStack {
                                    Text("Bán kính GPS chấm công hợp lệ:")
                                        .font(.system(size: 13))
                                    Spacer()
                                    Picker("Bán kính", selection: $gpsCheckInRadius) {
                                        Text("50 mét").tag(50)
                                        Text("100 mét").tag(100)
                                        Text("150 mét").tag(150)
                                        Text("300 mét").tag(300)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))

                        // Thẻ Bảo trì & An toàn hệ thống
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AN TOÀN & BẢO TRÌ MÁY CHỦ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.appTextSecondary)

                            VStack(spacing: 12) {
                                Toggle("Chế độ bảo trì hệ thống (Maintenance)", isOn: $maintenanceMode)
                                    .font(.system(size: 13, weight: .medium))

                                Divider()

                                Toggle("Gửi thông báo đẩy (Push Notifications) sự cố", isOn: $enablePushNotif)
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))

                        Spacer(minLength: 40)
                    }
                    .padding(14)
                }
            }
        }
        .alert(isPresented: $showSavedAlert) {
            Alert(
                title: Text("Thành công"),
                message: Text("Đã lưu toàn bộ cấu hình hệ thống máy chủ."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
