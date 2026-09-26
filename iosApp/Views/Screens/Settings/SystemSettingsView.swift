import SwiftUI

public struct SystemSettingsView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var companyName: String = ""
    @State private var gpsRadius: Int = 150
    @State private var slaUrgentHours: Int = 2
    @State private var slaHighHours: Int = 4
    @State private var slaNormalHours: Int = 8
    @State private var allowRemoteCheckin: Bool = false

    @State private var showSavedAlert: Bool = false

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TopBar tràn tai thỏ với Safe Area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Cấu hình hệ thống")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            if viewModel.currentUser.role == "ADMIN" || viewModel.currentUser.role == "SUPER_ADMIN" {
                                Button(action: saveConfig) {
                                    if viewModel.isLoadingConfig {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Lưu")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(Color.appPrimary)
                                            .cornerRadius(8)
                                    }
                                }
                                .disabled(viewModel.isLoadingConfig)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    if viewModel.isLoadingConfig && viewModel.systemConfig == nil {
                        Spacer()
                        ProgressView("Đang tải cấu hình...")
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // Thẻ Thông tin Doanh nghiệp
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("CẤU HÌNH CHUNG")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.gray)

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Tên công ty")
                                            .font(.system(size: 13))
                                        TextField("Nhập tên công ty", text: $companyName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(12)

                                // Thẻ Cài đặt Vận hành & SLA
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("SLA (CAM KẾT DỊCH VỤ)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.gray)

                                    VStack(spacing: 12) {
                                        HStack {
                                            Text("SLA Khẩn cấp (giờ):")
                                                .font(.system(size: 13))
                                            Spacer()
                                            TextField("", value: $slaUrgentHours, formatter: NumberFormatter())
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 80)
                                                .keyboardType(.numberPad)
                                        }

                                        Divider()
                                        
                                        HStack {
                                            Text("SLA Cao (giờ):")
                                                .font(.system(size: 13))
                                            Spacer()
                                            TextField("", value: $slaHighHours, formatter: NumberFormatter())
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 80)
                                                .keyboardType(.numberPad)
                                        }

                                        Divider()

                                        HStack {
                                            Text("SLA Thường (giờ):")
                                                .font(.system(size: 13))
                                            Spacer()
                                            TextField("", value: $slaNormalHours, formatter: NumberFormatter())
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 80)
                                                .keyboardType(.numberPad)
                                        }
                                    }
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)

                                // Thẻ Chấm công
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("CHẤM CÔNG")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.gray)

                                    VStack(spacing: 12) {
                                        Toggle("Cho phép chấm công từ xa", isOn: $allowRemoteCheckin)
                                            .font(.system(size: 13))
                                            
                                        Divider()
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Bán kính GPS hợp lệ: \(gpsRadius)m")
                                                .font(.system(size: 13))
                                            Slider(value: Binding(
                                                get: { Double(gpsRadius) },
                                                set: { gpsRadius = Int($0) }
                                            ), in: 50...500, step: 10)
                                        }
                                    }
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)

                                Spacer(minLength: 40)
                            }
                            .padding(14)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            Task {
                await viewModel.fetchSystemConfig()
                if let config = viewModel.systemConfig {
                    self.companyName = config.companyName
                    self.gpsRadius = config.gpsRadiusMeters
                    self.slaUrgentHours = config.slaUrgentHours
                    self.slaHighHours = config.slaHighHours
                    self.slaNormalHours = config.slaNormalHours
                    self.allowRemoteCheckin = config.allowRemoteCheckin
                }
            }
        }
        .onChange(of: viewModel.successMessage) { _ in
            if viewModel.successMessage != nil {
                showSavedAlert = true
            }
        }
        .alert(isPresented: $showSavedAlert) {
            Alert(
                title: Text("Thành công"),
                message: Text(viewModel.successMessage ?? "Đã lưu thành công."),
                dismissButton: .default(Text("OK")) {
                    viewModel.successMessage = nil
                }
            )
        }
    }
    
    private func saveConfig() {
        Task {
            await viewModel.saveSystemConfig(
                companyName: companyName,
                gpsRadius: gpsRadius,
                slaUrgentHours: slaUrgentHours,
                slaNormalHours: slaNormalHours
            )
        }
    }
}
