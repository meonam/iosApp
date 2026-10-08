import SwiftUI

struct AdminLogoImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AdminLogoImagePicker
        
        init(_ parent: AdminLogoImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                self.parent.image = img
            }
            picker.dismiss(animated: true)
        }
    }
}

struct AdminSettingsView: View {
    let companyId: String
    var onBack: () -> Void
    var onDeleteSuccess: (() -> Void)? = nil
    var bottomPadding: CGFloat = 0
    
    @State private var companyName = ""
    @State private var taxCode = ""
    @State private var address = ""
    @State private var logoUrl: String? = nil
    @State private var isMaintenance = false
    @State private var maintenanceMsg = ""
    
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var isUploadingLogo = false
    @State private var isShowingAlert = false
    @State private var messageText = ""
    @State private var webhookServerUrl = ""
    @State private var isTestingServer = false

    @State private var showingImagePicker = false
    @State private var pickedLogoImage: UIImage? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar with safe area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Cài đặt hệ thống")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)
                    
                    ScrollView {
                VStack(spacing: 16) {
                    // 1. THÔNG TIN DOANH NGHIỆP
                    SettingsSectionView(title: "Thông tin Doanh nghiệp", icon: "building.2.fill") {
                        VStack(spacing: 12) {
                            HStack {
                                Button(action: {
                                    showingImagePicker = true
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.blue.opacity(0.05))
                                            .frame(width: 70, height: 70)
                                        
                                        if isUploadingLogo {
                                            ProgressView()
                                        } else if let url = logoUrl, url.hasPrefix("data:image") {
                                            // Assume Base64 display
                                            if let base64String = url.components(separatedBy: ",").last,
                                               let data = Data(base64Encoded: base64String),
                                               let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 70, height: 70)
                                                    .cornerRadius(12)
                                            } else {
                                                Image(systemName: "building.fill.badge.plus")
                                                    .foregroundColor(.gray)
                                            }
                                        } else if let url = logoUrl, let realUrl = URL(string: url) {
                                            AsyncImage(url: realUrl) { image in
                                                image.resizable().scaledToFit()
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .frame(width: 70, height: 70)
                                            .cornerRadius(12)
                                        } else {
                                            Image(systemName: "building.fill.badge.plus")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .sheet(isPresented: $showingImagePicker) {
                                    AdminLogoImagePicker(image: $pickedLogoImage)
                                }
                                .onChange(of: pickedLogoImage) { newImage in
                                    guard let img = newImage, let data = img.jpegData(compressionQuality: 0.7) else { return }
                                    isUploadingLogo = true
                                    let base64 = data.base64EncodedString()
                                    let dataUrl = "data:image/jpeg;base64,\(base64)"
                                    Task {
                                        do {
                                            try await updateLogoUrl(dataUrl)
                                            logoUrl = dataUrl
                                            showMessage(text: "✅ Cập nhật Logo thành công")
                                        } catch {
                                            showMessage(text: "Lỗi: \(error.localizedDescription)")
                                        }
                                        isUploadingLogo = false
                                    }
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Logo thương hiệu")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appTextPrimary)
                                    Text("Nhấn vào ô để thay đổi")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                                Spacer()
                            }
                            
                            TextField("Tên doanh nghiệp", text: $companyName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(Color.appTextPrimary)
                            TextField("Mã số thuế", text: $taxCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(Color.appTextPrimary)
                            TextField("Địa chỉ trụ sở", text: $address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(Color.appTextPrimary)
                        }
                    }
                    
                    // 2. CHẾ ĐỘ BẢO TRÌ
                    SettingsSectionView(title: "Vận hành & Bảo trì", icon: "wrench.and.screwdriver.fill") {
                        VStack(spacing: 12) {
                            Toggle(isOn: $isMaintenance) {
                                VStack(alignment: .leading) {
                                    Text("Chế độ Bảo trì")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appTextPrimary)
                                    Text("Chặn tất cả người dùng truy cập")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            }
                            .tint(Color("PrimaryPink", bundle: nil)) // Fallback if missing
                            .onChange(of: isMaintenance) { newValue in
                                Task {
                                    let msg = maintenanceMsg.isEmpty ? "Hệ thống đang bảo trì, vui lòng quay lại sau" : maintenanceMsg
                                    do {
                                        try await updateMaintenanceConfig(isMaintenance: newValue, message: msg)
                                        if newValue {
                                            showMessage(text: "⚠️ ĐÃ BẬT CHẾ ĐỘ BẢO TRÌ!")
                                        } else {
                                            showMessage(text: "✅ ĐÃ TẮT CHẾ ĐỘ BẢO TRÌ!")
                                        }
                                    } catch {
                                        showMessage(text: "Lỗi: \(error.localizedDescription)")
                                    }
                                }
                            }
                            
                            if isMaintenance {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color(red: 217/255, green: 119/255, blue: 6/255))
                                    Text("Hệ thống đang bật bảo trì: Toàn bộ nhân viên và kỹ thuật viên bị khóa màn hình thao tác.")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(red: 146/255, green: 64/255, blue: 14/255))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .background(Color(red: 254/255, green: 243/255, blue: 199/255))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 253/255, green: 230/255, blue: 138/255), lineWidth: 1)
                                )
                                
                                TextField("Lời nhắn bảo trì", text: $maintenanceMsg)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                HStack {
                                    Spacer()
                                    Button("Cập nhật lời nhắn") {
                                        Task {
                                            do {
                                                try await updateMaintenanceConfig(isMaintenance: isMaintenance, message: maintenanceMsg.trimmingCharacters(in: .whitespacesAndNewlines))
                                                showMessage(text: "✅ Đã cập nhật lời nhắn bảo trì")
                                            } catch {
                                                showMessage(text: "Lỗi: \(error.localizedDescription)")
                                            }
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                                }
                            }
                        }
                    }
                    
                    // 3. MÁY CHỦ WEBHOOK GATEWAY (IP / TÊN MIỀN SERVER)
                    SettingsSectionView(title: "Máy Chủ Webhook Gateway", icon: "network", defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cấu hình IP / Tên miền khi chuyển đổi Gateway sang Server/VPS mới. Hệ thống sẽ trỏ Webhook Zalo & Email tới địa chỉ này.")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color.appTextSecondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Địa chỉ IP / Domain Máy Chủ Gateway")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.appTextPrimary)
                                
                                HStack(spacing: 8) {
                                    TextField("vd: 103.153.72.100:3000 hoặc webhook.domain.com", text: $webhookServerUrl)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                    
                                    Button(action: testServerGateway) {
                                        HStack(spacing: 4) {
                                            if isTestingServer {
                                                ProgressView().tint(.white)
                                            } else {
                                                Image(systemName: "bolt.horizontal.fill")
                                                Text("Kiểm tra")
                                            }
                                        }
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isTestingServer)
                                }
                            }
                            
                            let cleanServer = webhookServerUrl.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
                            let effectiveServer = cleanServer.isEmpty ? "http://IP_HOAC_DOMAIN:3000" : (cleanServer.hasPrefix("http") ? cleanServer : "http://\(cleanServer)")
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Đường dẫn Webhook tự sinh:")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Zalo OA Webhook URL:")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundColor(Color.appTextSecondary)
                                    Text("\(effectiveServer)/api/webhook/zalo")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .textSelection(.enabled)
                                        .padding(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Email Gateway Webhook URL:")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundColor(Color.appTextSecondary)
                                    Text("\(effectiveServer)/api/webhook/email")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.green)
                                        .textSelection(.enabled)
                                        .padding(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(10)
                            .background(Color.appBackground)
                            .cornerRadius(10)
                        }
                    }
                    
                    Button(action: saveAllSettings) {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("LƯU TẤT CẢ CÀI ĐẶT")
                                    .fontWeight(.heavy)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isSaving ? Color.gray : Color.pink) // Fallback Color.pink
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                    
                    Spacer().frame(height: 40)
                }
                .padding(16)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(title: Text("Thông báo"), message: Text(messageText), dismissButton: .default(Text("OK")))
        }
        .task {
            await loadData()
        }
    }
    
    private func showMessage(text: String) {
        messageText = text
        isShowingAlert = true
    }
    
    private func loadData() async {
        guard !companyId.isEmpty else { return }
        isLoading = true
        // Assuming FirebaseConfig.firestoreBaseUrl exists or use a generic one
        let baseUrl = FirebaseConfig.firestoreBaseUrl
        let urlString = "\(baseUrl)/companies/\(companyId)"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                
                self.companyName = extractString(from: fields["companyName"]) ?? companyId
                self.taxCode = extractString(from: fields["taxCode"]) ?? ""
                self.address = extractString(from: fields["address"]) ?? ""
                self.logoUrl = extractString(from: fields["logoUrl"])
                self.isMaintenance = extractBoolean(from: fields["isMaintenance"]) ?? false
                self.maintenanceMsg = extractString(from: fields["maintenanceMsg"]) ?? "Hệ thống đang bảo trì"
            }
        } catch {
            print("Load error: \(error)")
        }
        
        // Load webhookServerUrl from config/email
        let emailConfigUrl = "\(baseUrl)/companies/\(companyId)/config/email"
        if let configUrl = URL(string: emailConfigUrl) {
            do {
                let (cData, _) = try await URLSession.shared.data(from: configUrl)
                if let cJson = try JSONSerialization.jsonObject(with: cData) as? [String: Any],
                   let cFields = cJson["fields"] as? [String: Any] {
                    if let server = extractString(from: cFields["webhookServerUrl"]) {
                        self.webhookServerUrl = server
                    }
                }
            } catch {
                print("Load email config error: \(error)")
            }
        }
        isLoading = false
    }
    
    private func testServerGateway() {
        let raw = webhookServerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            showMessage(text: "Vui lòng nhập địa chỉ IP hoặc Tên miền máy chủ Webhook")
            return
        }
        let formatted = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "http://\(raw)"
        guard let url = URL(string: "\(formatted)/health") else {
            showMessage(text: "Địa chỉ URL không hợp lệ")
            return
        }
        isTestingServer = true
        Task {
            var req = URLRequest(url: url)
            req.timeoutInterval = 8
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                    let text = String(data: data, encoding: .utf8) ?? ""
                    showMessage(text: "✅ Kết nối máy chủ Gateway thành công (HTTP \(httpRes.statusCode))!\nPhản hồi: \(text)")
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    showMessage(text: "⚠️ Máy chủ phản hồi mã HTTP \(code)")
                }
            } catch {
                showMessage(text: "❌ Không thể kết nối tới máy chủ: \(error.localizedDescription)")
            }
            isTestingServer = false
        }
    }
    
    private func saveWebhookConfig(serverUrl: String) async {
        let baseUrl = FirebaseConfig.firestoreBaseUrl
        let urlString = "\(baseUrl)/companies/\(companyId)/config/email?updateMask.fieldPaths=webhookServerUrl"
        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "fields": [
                "webhookServerUrl": ["stringValue": serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)]
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: body) {
            req.httpBody = data
            let _ = try? await URLSession.shared.data(for: req)
        }
    }
    
    private func extractString(from value: Any?) -> String? {
        guard let valueDict = value as? [String: Any], let str = valueDict["stringValue"] as? String else { return nil }
        return str
    }
    
    private func extractBoolean(from value: Any?) -> Bool? {
        guard let valueDict = value as? [String: Any], let b = valueDict["booleanValue"] as? Bool else { return nil }
        return b
    }
    
    private func updateLogoUrl(_ newUrl: String) async throws {
        let baseUrl = FirebaseConfig.firestoreBaseUrl
        let urlString = "\(baseUrl)/companies/\(companyId)?updateMask.fieldPaths=logoUrl"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "logoUrl": ["stringValue": newUrl]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
            throw NSError(domain: "Firestore", code: httpRes.statusCode, userInfo: nil)
        }
    }
    
    private func updateMaintenanceConfig(isMaintenance: Bool, message: String) async throws {
        let baseUrl = FirebaseConfig.firestoreBaseUrl
        let urlString = "\(baseUrl)/companies/\(companyId)?updateMask.fieldPaths=isMaintenance&updateMask.fieldPaths=maintenanceMsg"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "isMaintenance": ["booleanValue": isMaintenance],
                "maintenanceMsg": ["stringValue": message]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
            throw NSError(domain: "Firestore", code: httpRes.statusCode, userInfo: nil)
        }
        
        // Update config collection too
        let configUrlString = "\(baseUrl)/companies/\(companyId)/config/maintenance"
        guard let configUrl = URL(string: configUrlString) else { return }
        var configReq = URLRequest(url: configUrl)
        configReq.httpMethod = "PATCH"
        configReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let configBody: [String: Any] = [
            "fields": [
                "isMaintenance": ["booleanValue": isMaintenance],
                "maintenanceMsg": ["stringValue": message],
                "updatedAt": ["integerValue": "\(Int(Date().timeIntervalSince1970 * 1000))"]
            ]
        ]
        configReq.httpBody = try JSONSerialization.data(withJSONObject: configBody)
        let _ = try? await URLSession.shared.data(for: configReq)
    }
    
    private func saveAllSettings() {
        Task {
            isSaving = true
            let baseUrl = FirebaseConfig.firestoreBaseUrl
            let urlString = "\(baseUrl)/companies/\(companyId)?updateMask.fieldPaths=companyName&updateMask.fieldPaths=taxCode&updateMask.fieldPaths=address&updateMask.fieldPaths=isMaintenance&updateMask.fieldPaths=maintenanceMsg"
            guard let url = URL(string: urlString) else { isSaving = false; return }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "fields": [
                    "companyName": ["stringValue": companyName],
                    "taxCode": ["stringValue": taxCode],
                    "address": ["stringValue": address],
                    "isMaintenance": ["booleanValue": isMaintenance],
                    "maintenanceMsg": ["stringValue": maintenanceMsg]
                ]
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
                    throw NSError(domain: "Firestore", code: httpRes.statusCode, userInfo: nil)
                }
                
                try await updateMaintenanceConfig(isMaintenance: isMaintenance, message: maintenanceMsg)
                await saveWebhookConfig(serverUrl: webhookServerUrl)
                showMessage(text: "✅ Đã lưu cấu hình")
                onBack()
            } catch {
                showMessage(text: "Lỗi: \(error.localizedDescription)")
            }
            isSaving = false
        }
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    @State private var isExpanded: Bool = false
    
    init(title: String, icon: String, defaultExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self._isExpanded = State(initialValue: defaultExpanded)
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.blue)
                        .frame(width: 30, height: 30)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.gray)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider().padding(.horizontal, 14)
                VStack(spacing: 12) {
                    content
                }
                .padding(14)
            }
        }
        .background(Color.appSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}
