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

    // Khung giờ 4 ca
    @State private var standardCheckInTime: String = "08:00"
    @State private var standardCheckOutTime: String = "17:00"
    @State private var shift1CheckInTime: String = "07:00"
    @State private var shift1CheckOutTime: String = "15:00"
    @State private var shift2CheckInTime: String = "14:00"
    @State private var shift2CheckOutTime: String = "22:00"
    @State private var nightCheckInTime: String = "22:00"
    @State private var nightCheckOutTime: String = "06:00"

    // Mốc GPS & Trụ sở
    @State private var targetAddress: String = ""
    @State private var arrivalRadius: Int = 150

    // Định mức KTV & Phụ cấp
    @State private var pricePerKm: Double = 5000.0
    @State private var tripBaseAllowance: Double = 50000.0
    @State private var overtimeMultiplier: Double = 0.0

    // Chính sách hủy ticket
    @State private var cancellationThresholdPercent: Int = 50
    @State private var underThresholdPolicy: String = "HALF_TRIP"
    @State private var underThresholdFlatFee: Double = 30000.0
    
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
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
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
                                sectionExpenses()
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
            Text("CHẤM CÔNG & CA KÍP").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            VStack(spacing: 12) {
                Toggle("Bật GPS Check-in", isOn: $gpsCheckInEnabled).font(.system(size: 13))
                Toggle("Bật Selfie Check-in", isOn: $selfieCheckInEnabled).font(.system(size: 13))

                // Khung Giờ 4 Ca
                VStack(alignment: .leading, spacing: 8) {
                    Text("Khung Giờ 4 Ca Làm Việc:").font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)

                    HStack {
                        Text("HC:").font(.system(size: 11.5, weight: .bold)).foregroundColor(Color(hex: "#047857")).frame(width: 32, alignment: .leading)
                        TextField("08:00", text: $standardCheckInTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Text("-").font(.system(size: 12))
                        TextField("17:00", text: $standardCheckOutTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Spacer()
                    }
                    HStack {
                        Text("Ca 1:").font(.system(size: 11.5, weight: .bold)).foregroundColor(Color(hex: "#D97706")).frame(width: 32, alignment: .leading)
                        TextField("07:00", text: $shift1CheckInTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Text("-").font(.system(size: 12))
                        TextField("15:00", text: $shift1CheckOutTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Spacer()
                    }
                    HStack {
                        Text("Ca 2:").font(.system(size: 11.5, weight: .bold)).foregroundColor(Color(hex: "#2563EB")).frame(width: 32, alignment: .leading)
                        TextField("14:00", text: $shift2CheckInTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Text("-").font(.system(size: 12))
                        TextField("22:00", text: $shift2CheckOutTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Spacer()
                    }
                    HStack {
                        Text("Ca 3:").font(.system(size: 11.5, weight: .bold)).foregroundColor(Color(hex: "#7C3AED")).frame(width: 32, alignment: .leading)
                        TextField("22:00", text: $nightCheckInTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Text("-").font(.system(size: 12))
                        TextField("06:00", text: $nightCheckOutTime).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 65)
                        Spacer()
                    }
                }
                .padding(10)
                .background(Color(hex: "#F8FAFC"))
                .cornerRadius(8)

                settingNumberField(title: "Cho phép đi muộn (phút)", value: $lateThresholdMinutes)

                Divider()

                // Mốc GPS Trụ Sở & Bán Kính
                settingTextField(title: "Địa chỉ trụ sở", text: $targetAddress)
                settingNumberField(title: "Bán kính chấm công (m)", value: $gpsRadius)
                settingNumberField(title: "Bán kính đến nơi KTV (m)", value: $arrivalRadius)
                settingDoubleField(title: "Tọa độ Lat", value: $gpsLat)
                settingDoubleField(title: "Tọa độ Lng", value: $gpsLng)
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
    }

    @ViewBuilder
    private func sectionExpenses() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ĐỊNH MỨC CÔNG TÁC PHÍ & HỦY TICKET").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            VStack(spacing: 12) {
                settingDoubleField(title: "Đơn giá xăng (VNĐ/km)", value: $pricePerKm)
                settingDoubleField(title: "Phụ cấp ca xử lý (VNĐ/ca)", value: $tripBaseAllowance)
                settingDoubleField(title: "Hệ số ngoài giờ / ca đêm", value: $overtimeMultiplier)

                Divider()

                settingNumberField(title: "Ngưỡng % hủy chuyến", value: $cancellationThresholdPercent)

                HStack {
                    Text("Chế độ hủy < ngưỡng").font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $underThresholdPolicy) {
                        Text("50% Chuyến").tag("HALF_TRIP")
                        Text("100% Chuyến").tag("FULL_TRIP")
                        Text("Km thực tế").tag("ACTUAL_KM")
                        Text("Khoán cố định").tag("FLAT_FEE")
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                if underThresholdPolicy == "FLAT_FEE" {
                    settingDoubleField(title: "Mức khoán hủy (VNĐ)", value: $underThresholdFlatFee)
                }
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

        // 2. Tải thêm từ canonical system_config/travel_expense_config
        let travelUrl = FirebaseConfig.firestoreBaseUrl + "/companies/\(companyId)/system_config/travel_expense_config"
        if let tUrl = URL(string: travelUrl) {
            var tReq = URLRequest(url: tUrl)
            tReq.httpMethod = "GET"
            if !viewModel.idToken.isEmpty {
                tReq.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
            }
            URLSession.shared.dataTask(with: tReq) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let fields = json["fields"] as? [String: Any] else { return }
                DispatchQueue.main.async {
                    let sIn = FirestoreHelper.getString(fields["standardCheckInTime"] as? [String: Any])
                    if !sIn.isEmpty { self.standardCheckInTime = sIn }
                    let sOut = FirestoreHelper.getString(fields["standardCheckOutTime"] as? [String: Any])
                    if !sOut.isEmpty { self.standardCheckOutTime = sOut }
                    let s1In = FirestoreHelper.getString(fields["shift1CheckInTime"] as? [String: Any])
                    if !s1In.isEmpty { self.shift1CheckInTime = s1In }
                    let s1Out = FirestoreHelper.getString(fields["shift1CheckOutTime"] as? [String: Any])
                    if !s1Out.isEmpty { self.shift1CheckOutTime = s1Out }
                    let s2In = FirestoreHelper.getString(fields["shift2CheckInTime"] as? [String: Any])
                    if !s2In.isEmpty { self.shift2CheckInTime = s2In }
                    let s2Out = FirestoreHelper.getString(fields["shift2CheckOutTime"] as? [String: Any])
                    if !s2Out.isEmpty { self.shift2CheckOutTime = s2Out }
                    let nIn = FirestoreHelper.getString(fields["nightCheckInTime"] as? [String: Any])
                    if !nIn.isEmpty { self.nightCheckInTime = nIn }
                    let nOut = FirestoreHelper.getString(fields["nightCheckOutTime"] as? [String: Any])
                    if !nOut.isEmpty { self.nightCheckOutTime = nOut }

                    let lateM = FirestoreHelper.getInt(fields["maxCheckInLateMinutes"] as? [String: Any])
                    if lateM > 0 { self.lateThresholdMinutes = lateM }
                    let geoR = FirestoreHelper.getDouble(fields["geofenceRadiusMeters"] as? [String: Any])
                    if geoR > 0 { self.gpsRadius = Int(geoR) }
                    let arrR = FirestoreHelper.getDouble(fields["arrivalRadiusMeters"] as? [String: Any])
                    if arrR > 0 { self.arrivalRadius = Int(arrR) }

                    let addr = FirestoreHelper.getString(fields["targetAddress"] as? [String: Any])
                    if !addr.isEmpty { self.targetAddress = addr }
                    let tLat = FirestoreHelper.getDouble(fields["targetLatitude"] as? [String: Any])
                    if tLat != 0 { self.gpsLat = tLat }
                    let tLng = FirestoreHelper.getDouble(fields["targetLongitude"] as? [String: Any])
                    if tLng != 0 { self.gpsLng = tLng }

                    let pKm = FirestoreHelper.getDouble(fields["pricePerKm"] as? [String: Any])
                    if pKm > 0 { self.pricePerKm = pKm }
                    let tAll = FirestoreHelper.getDouble(fields["tripBaseAllowance"] as? [String: Any])
                    if tAll > 0 { self.tripBaseAllowance = tAll }
                    let oMulti = FirestoreHelper.getDouble(fields["overtimeMultiplier"] as? [String: Any])
                    self.overtimeMultiplier = oMulti

                    let cThresh = FirestoreHelper.getInt(fields["cancellationThresholdPercent"] as? [String: Any])
                    if cThresh > 0 { self.cancellationThresholdPercent = cThresh }
                    let uPol = FirestoreHelper.getString(fields["underThresholdPolicy"] as? [String: Any])
                    if !uPol.isEmpty { self.underThresholdPolicy = uPol }
                    let uFee = FirestoreHelper.getDouble(fields["underThresholdFlatFee"] as? [String: Any])
                    if uFee > 0 { self.underThresholdFlatFee = uFee }
                }
            }.resume()
        }
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
                "attendanceStartTime": ["stringValue": standardCheckInTime],
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

        // 2. Lưu đồng thời vào canonical system_config/travel_expense_config
        let travelPatchUrl = FirebaseConfig.firestoreBaseUrl + "/companies/\(companyId)/system_config/travel_expense_config"
        if let tReqUrl = URL(string: travelPatchUrl) {
            var tReq = URLRequest(url: tReqUrl)
            tReq.httpMethod = "PATCH"
            tReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !viewModel.idToken.isEmpty {
                tReq.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
            }
            let tBody: [String: Any] = [
                "fields": [
                    "standardCheckInTime": ["stringValue": standardCheckInTime],
                    "standardCheckOutTime": ["stringValue": standardCheckOutTime],
                    "shift1CheckInTime": ["stringValue": shift1CheckInTime],
                    "shift1CheckOutTime": ["stringValue": shift1CheckOutTime],
                    "shift2CheckInTime": ["stringValue": shift2CheckInTime],
                    "shift2CheckOutTime": ["stringValue": shift2CheckOutTime],
                    "nightCheckInTime": ["stringValue": nightCheckInTime],
                    "nightCheckOutTime": ["stringValue": nightCheckOutTime],
                    "maxCheckInLateMinutes": ["integerValue": String(lateThresholdMinutes)],
                    "geofenceRadiusMeters": ["doubleValue": Double(gpsRadius)],
                    "arrivalRadiusMeters": ["doubleValue": Double(arrivalRadius)],
                    "targetAddress": ["stringValue": targetAddress],
                    "targetLatitude": ["doubleValue": gpsLat],
                    "targetLongitude": ["doubleValue": gpsLng],
                    "pricePerKm": ["doubleValue": pricePerKm],
                    "tripBaseAllowance": ["doubleValue": tripBaseAllowance],
                    "overtimeMultiplier": ["doubleValue": overtimeMultiplier],
                    "cancellationThresholdPercent": ["integerValue": String(cancellationThresholdPercent)],
                    "underThresholdPolicy": ["stringValue": underThresholdPolicy],
                    "underThresholdFlatFee": ["doubleValue": underThresholdFlatFee],
                    "aboveThresholdPolicy": ["stringValue": "FULL_TRIP"]
                ]
            ]
            tReq.httpBody = try? JSONSerialization.data(withJSONObject: tBody)
            URLSession.shared.dataTask(with: tReq).resume()
        }

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
