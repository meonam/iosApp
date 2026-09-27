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
    @State private var showMessage = false
    @State private var messageText = ""
    
    @State private var showingImagePicker = false
    @State private var pickedLogoImage: UIImage? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar with safe area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
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
                                    Text("Nhấn vào ô để thay đổi")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            
                            TextField("Tên doanh nghiệp", text: $companyName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("Mã số thuế", text: $taxCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("Địa chỉ trụ sở", text: $address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // 2. CHẾ ĐỘ BẢO TRÌ
                    SettingsSectionView(title: "Vận hành & Bảo trì", icon: "wrench.and.screwdriver.fill") {
                        VStack(spacing: 12) {
                            Toggle(isOn: $isMaintenance) {
                                VStack(alignment: .leading) {
                                    Text("Chế độ Bảo trì")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Chặn tất cả người dùng truy cập")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
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
                .padding(.bottom, bottomPadding)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert(isPresented: $showMessage) {
            Alert(title: Text("Thông báo"), message: Text(messageText), dismissButton: .default(Text("OK")))
        }
        .task {
            await loadData()
        }
    }
    
    private func showMessage(text: String) {
        messageText = text
        showMessage = true
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
        isLoading = false
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
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.blue)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.blue)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider().padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                content
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 240/255, green: 242/255, blue: 245/255), lineWidth: 1)
        )
    }
}
