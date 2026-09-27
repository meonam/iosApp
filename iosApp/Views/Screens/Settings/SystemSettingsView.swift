import SwiftUI

public struct SystemSettingsView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    // Settings States
    @State private var companyName: String = ""
    @State private var companyCode: String = ""
    @State private var companyAddress: String = ""
    @State private var companyPhone: String = ""
    @State private var companyEmail: String = ""
    
    @State private var gpsCheckInEnabled: Bool = false
    @State private var gpsRadius: Int = 150
    @State private var gpsLat: Double = 0.0
    @State private var gpsLng: Double = 0.0
    @State private var selfieCheckInEnabled: Bool = false
    @State private var attendanceStartTime: String = "08:00"
    @State private var lateThresholdMinutes: Int = 15
    
    @State private var slaUrgentHours: Int = 1
    @State private var slaHighHours: Int = 4
    @State private var slaNormalHours: Int = 24
    
    @State private var notificationsEnabled: Bool = true
    @State private var maxDevicesPerUser: Int = 5
    @State private var paywallEnabled: Bool = false
    
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    // Local Cache
    @AppStorage("companyName") private var localCompanyName: String = ""
    @AppStorage("companyCode") private var localCompanyCode: String = ""
    @AppStorage("gpsRadius") private var localGpsRadius: Int = 150
    @AppStorage("slaUrgentHours") private var localSlaUrgentHours: Int = 1
    @AppStorage("slaHighHours") private var localSlaHighHours: Int = 4
    @AppStorage("slaNormalHours") private var localSlaNormalHours: Int = 24

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
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
                            Button(action: saveSettings) {
                                if isSaving {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Lưu")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.appPrimary.opacity(0.8))
                                        .cornerRadius(8)
                                }
                            }
                            .disabled(isLoading || isSaving)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    if isLoading {
                        Spacer()
                        ProgressView("Đang tải cấu hình...")
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                sectionCompanyInfo()
                                sectionAttendance()
                                sectionSLA()
                                sectionDevices()
                                sectionNotifications()
                            }
                            .padding(14)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            loadSettings()
        }
        .alert(isPresented: $showToast) {
            Alert(title: Text("Thông báo"), message: Text(toastMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    @ViewBuilder
    private func sectionCompanyInfo() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THÔNG TIN CÔNG TY").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            VStack(spacing: 12) {
                settingTextField(title: "Tên công ty", text: $companyName)
                settingTextField(title: "Mã công ty", text: $companyCode)
                settingTextField(title: "Địa chỉ", text: $companyAddress)
                settingTextField(title: "Điện thoại", text: $companyPhone)
                settingTextField(title: "Email", text: $companyEmail)
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
    }

    @ViewBuilder
    private func sectionAttendance() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHẤM CÔNG").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            VStack(spacing: 12) {
                Toggle("Bật GPS Check-in", isOn: $gpsCheckInEnabled).font(.system(size: 13))
                Toggle("Bật Selfie Check-in", isOn: $selfieCheckInEnabled).font(.system(size: 13))
                settingNumberField(title: "Bán kính GPS (m)", value: $gpsRadius)
                settingDoubleField(title: "Tọa độ Lat", value: $gpsLat)
                settingDoubleField(title: "Tọa độ Lng", value: $gpsLng)
                settingTextField(title: "Giờ bắt đầu (HH:mm)", text: $attendanceStartTime)
                settingNumberField(title: "Cho phép đi muộn (phút)", value: $lateThresholdMinutes)
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
    }
    
    @ViewBuilder
    private func sectionSLA() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SLA (CAM KẾT DỊCH VỤ)").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            VStack(spacing: 12) {
                settingNumberField(title: "SLA Khẩn cấp (giờ)", value: $slaUrgentHours)
                settingNumberField(title: "SLA Cao (giờ)", value: $slaHighHours)
                settingNumberField(title: "SLA Thường (giờ)", value: $slaNormalHours)
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
    }
    
    @ViewBuilder
    private func sectionDevices() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIẾT BỊ & GIẤY PHÉP").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            VStack(spacing: 12) {
                settingNumberField(title: "Số thiết bị tối đa / người", value: $maxDevicesPerUser)
                Toggle("Bật Paywall / Giấy phép", isOn: $paywallEnabled).font(.system(size: 13))
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
    }
    
    @ViewBuilder
    private func sectionNotifications() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THÔNG BÁO").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            VStack(spacing: 12) {
                Toggle("Bật thông báo đẩy", isOn: $notificationsEnabled).font(.system(size: 13))
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
    }
    
    private func settingTextField(title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            TextField("", text: text)
                .font(.system(size: 13))
                .multilineTextAlignment(.trailing)
                .frame(width: 150)
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private func settingNumberField(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            TextField("", value: value, formatter: NumberFormatter())
                .font(.system(size: 13))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private func settingDoubleField(title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            TextField("", value: value, formatter: NumberFormatter())
                .font(.system(size: 13))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
    }

    private func loadSettings() {
        let companyId = viewModel.companyId
        if companyId.isEmpty {
            isLoading = false
            return
        }
        
        let url = FirebaseConfig.firestoreBaseUrl + "/companies/\(companyId)/settings/config"
        guard let reqUrl = URL(string: url) else { return }
        
        var request = URLRequest(url: reqUrl)
        request.httpMethod = "GET"
        if !viewModel.idToken.isEmpty {
            request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else { return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any] {
                    self.companyName = FirestoreHelper.getString(fields["companyName"] as? [String: Any])
                    self.companyCode = FirestoreHelper.getString(fields["companyCode"] as? [String: Any])
                    self.companyAddress = FirestoreHelper.getString(fields["companyAddress"] as? [String: Any])
                    self.companyPhone = FirestoreHelper.getString(fields["companyPhone"] as? [String: Any])
                    self.companyEmail = FirestoreHelper.getString(fields["companyEmail"] as? [String: Any])
                    self.gpsCheckInEnabled = FirestoreHelper.getBool(fields["gpsCheckInEnabled"] as? [String: Any])
                    self.gpsRadius = FirestoreHelper.getInt(fields["gpsRadius"] as? [String: Any])
                    self.gpsLat = FirestoreHelper.getDouble(fields["gpsLat"] as? [String: Any])
                    self.gpsLng = FirestoreHelper.getDouble(fields["gpsLng"] as? [String: Any])
                    self.selfieCheckInEnabled = FirestoreHelper.getBool(fields["selfieCheckInEnabled"] as? [String: Any])
                    self.attendanceStartTime = FirestoreHelper.getString(fields["attendanceStartTime"] as? [String: Any])
                    self.lateThresholdMinutes = FirestoreHelper.getInt(fields["lateThresholdMinutes"] as? [String: Any])
                    self.slaUrgentHours = FirestoreHelper.getInt(fields["slaUrgentHours"] as? [String: Any])
                    self.slaHighHours = FirestoreHelper.getInt(fields["slaHighHours"] as? [String: Any])
                    self.slaNormalHours = FirestoreHelper.getInt(fields["slaNormalHours"] as? [String: Any])
                    self.notificationsEnabled = FirestoreHelper.getBool(fields["notificationsEnabled"] as? [String: Any])
                    self.maxDevicesPerUser = FirestoreHelper.getInt(fields["maxDevicesPerUser"] as? [String: Any])
                    self.paywallEnabled = FirestoreHelper.getBool(fields["paywallEnabled"] as? [String: Any])
                    
                    // Sync local cache
                    self.localCompanyName = self.companyName
                    self.localCompanyCode = self.companyCode
                    self.localGpsRadius = self.gpsRadius
                    self.localSlaUrgentHours = self.slaUrgentHours
                    self.localSlaHighHours = self.slaHighHours
                    self.localSlaNormalHours = self.slaNormalHours
                }
            }
        }.resume()
    }

    private func saveSettings() {
        let companyId = viewModel.companyId
        if companyId.isEmpty { return }
        
        isSaving = true
        
        // Cần patch tất cả các fields
        let patchUrl = FirebaseConfig.firestoreBaseUrl + "/companies/\(companyId)/settings/config?" +
            "updateMask.fieldPaths=companyName&updateMask.fieldPaths=companyCode&updateMask.fieldPaths=companyAddress&" +
            "updateMask.fieldPaths=companyPhone&updateMask.fieldPaths=companyEmail&updateMask.fieldPaths=gpsCheckInEnabled&" +
            "updateMask.fieldPaths=gpsRadius&updateMask.fieldPaths=gpsLat&updateMask.fieldPaths=gpsLng&" +
            "updateMask.fieldPaths=selfieCheckInEnabled&updateMask.fieldPaths=attendanceStartTime&updateMask.fieldPaths=lateThresholdMinutes&" +
            "updateMask.fieldPaths=slaUrgentHours&updateMask.fieldPaths=slaHighHours&updateMask.fieldPaths=slaNormalHours&" +
            "updateMask.fieldPaths=notificationsEnabled&updateMask.fieldPaths=maxDevicesPerUser&updateMask.fieldPaths=paywallEnabled"
            
        guard let reqUrl = URL(string: patchUrl) else {
            isSaving = false
            return
        }
        
        var request = URLRequest(url: reqUrl)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty {
            request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "fields": [
                "companyName": ["stringValue": companyName],
                "companyCode": ["stringValue": companyCode],
                "companyAddress": ["stringValue": companyAddress],
                "companyPhone": ["stringValue": companyPhone],
                "companyEmail": ["stringValue": companyEmail],
                "gpsCheckInEnabled": ["booleanValue": gpsCheckInEnabled],
                "gpsRadius": ["integerValue": String(gpsRadius)],
                "gpsLat": ["doubleValue": gpsLat],
                "gpsLng": ["doubleValue": gpsLng],
                "selfieCheckInEnabled": ["booleanValue": selfieCheckInEnabled],
                "attendanceStartTime": ["stringValue": attendanceStartTime],
                "lateThresholdMinutes": ["integerValue": String(lateThresholdMinutes)],
                "slaUrgentHours": ["integerValue": String(slaUrgentHours)],
                "slaHighHours": ["integerValue": String(slaHighHours)],
                "slaNormalHours": ["integerValue": String(slaNormalHours)],
                "notificationsEnabled": ["booleanValue": notificationsEnabled],
                "maxDevicesPerUser": ["integerValue": String(maxDevicesPerUser)],
                "paywallEnabled": ["booleanValue": paywallEnabled]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSaving = false
                if let error = error {
                    self.toastMessage = "Lỗi khi lưu: \(error.localizedDescription)"
                    self.showToast = true
                    return
                }
                
                // Sync local cache
                self.localCompanyName = self.companyName
                self.localCompanyCode = self.companyCode
                self.localGpsRadius = self.gpsRadius
                self.localSlaUrgentHours = self.slaUrgentHours
                self.localSlaHighHours = self.slaHighHours
                self.localSlaNormalHours = self.slaNormalHours
                
                self.toastMessage = "Đã lưu cấu hình thành công!"
                self.showToast = true
            }
        }.resume()
    }
}
