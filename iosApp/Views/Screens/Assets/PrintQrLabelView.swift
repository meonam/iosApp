import SwiftUI
import CoreImage.CIFilterBuiltins

// Helper để render view thành UIImage
extension View {
    func snapshot(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self.ignoresSafeArea())
        let view = controller.view
        
        let targetSize = size
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .white
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view!.bounds, afterScreenUpdates: true)
        }
    }
}

// QR Code Generator
func generateQRCode(from string: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    
    if let outputImage = filter.outputImage {
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    return UIImage(systemName: "xmark.circle") ?? UIImage()
}

struct PrintQrLabelView: View {
    @ObservedObject var viewModel: DeviceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedLabelSize: LabelSize = .size60x40
    @State private var printCopies: Int = 1
    @State private var showShareSheet = false
    @State private var sharedImage: UIImage? = nil
    
    // Batch mode vars
    @State private var isBatchMode = false
    @State private var selectedDevices = Set<String>()
    
    enum LabelSize: String, CaseIterable, Identifiable {
        case size40x30 = "40x30 mm"
        case size60x40 = "60x40 mm"
        case sizeA4 = "A4 (Nhiều tem)"
        var id: String { rawValue }
        
        var cgSize: CGSize {
            // Conversion roughly based on 300dpi (1mm = 11.8 pixels)
            switch self {
            case .size40x30: return CGSize(width: 472, height: 354)
            case .size60x40: return CGSize(width: 708, height: 472)
            case .sizeA4: return CGSize(width: 2480, height: 3508)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Safe Area TopBar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        topBar
                    }
                    .background(Color.appPrimary)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            searchAndFilterSection
                            
                            // Configurations
                            HStack {
                                Text("Khổ giấy")
                                    .fontWeight(.semibold)
                                Spacer()
                                Picker("Size", selection: $selectedLabelSize) {
                                    ForEach(LabelSize.allCases) { size in
                                        Text(size.rawValue).tag(size)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            
                            HStack {
                                Text("Số lượng bản in (mỗi tem)")
                                    .fontWeight(.semibold)
                                Spacer()
                                Stepper("\(printCopies)", value: $printCopies, in: 1...10)
                                    .frame(width: 120)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            
                            // Device list
                            if viewModel.isLoading {
                                ProgressView().padding()
                            } else {
                                ForEach(viewModel.paginatedDevices) { device in
                                    deviceRow(device)
                                }
                                
                                if viewModel.hasMore {
                                    Button(action: { viewModel.loadMore() }) {
                                        Text(viewModel.isFetchingMore ? "Đang tải..." : "Tải thêm")
                                            .foregroundColor(Color.appPrimary)
                                            .padding()
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    // Bottom Actions
                    if !selectedDevices.isEmpty || (isBatchMode == false && viewModel.filteredDevices.count == 1) {
                        bottomActionView
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if viewModel.rawDevices.isEmpty {
                viewModel.fetchDevices()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = sharedImage {
                ActivityViewController(activityItems: [img])
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .imageScale(.large)
                    .padding()
            }
            Text("In Tem QR Thiết Bị")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                isBatchMode.toggle()
                if !isBatchMode {
                    selectedDevices.removeAll()
                }
            }) {
                Image(systemName: isBatchMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Tìm thiết bị...", text: $viewModel.searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    FilterChip(title: "Trạng thái", selection: $viewModel.selectedStatusFilter, options: ["ALL", "ACTIVE", "MAINTENANCE", "RETIRED"])
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func deviceRow(_ device: ThietBi) -> some View {
        let isSelected = selectedDevices.contains(device.id)
        
        return VStack {
            HStack {
                if isBatchMode {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? Color.appPrimary : .gray)
                        .onTapGesture {
                            if isSelected { selectedDevices.remove(device.id) }
                            else { selectedDevices.insert(device.id) }
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.ten).font(.headline)
                    Text("Mã: \(device.id)").font(.subheadline).foregroundColor(.gray)
                }
                Spacer()
                
                if !isBatchMode {
                    Button(action: {
                        selectedDevices = [device.id]
                        printLabel(for: device)
                    }) {
                        Image(systemName: "printer.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.appPrimary)
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Preview
            if !isBatchMode || selectedDevices.contains(device.id) {
                LabelPreviewView(device: device, companyId: viewModel.companyId)
                    .frame(height: 120)
                    .padding(.horizontal)
            }
        }
    }
    
    private var bottomActionView: some View {
        HStack(spacing: 16) {
            Button(action: {
                shareLabels()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Chia sẻ")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.black)
                .cornerRadius(8)
            }
            
            Button(action: {
                printBatch()
            }) {
                HStack {
                    Image(systemName: "printer.fill")
                    Text("In \(selectedDevices.count) tem")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .shadow(radius: 2)
    }
    
    private func printLabel(for device: ThietBi) {
        let view = LabelDesignView(device: device, companyId: viewModel.companyId)
        let image = view.snapshot(size: selectedLabelSize.cgSize)
        
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "QR Label - \(device.ten)"
        printInfo.outputType = .photo
        
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = image
        controller.present(animated: true) { _, completed, error in
            if completed {
                viewModel.successMessage = "In thành công!"
            } else if let err = error {
                viewModel.errorMessage = "Lỗi in: \(err.localizedDescription)"
            }
        }
    }
    
    private func printBatch() {
        let items = viewModel.filteredDevices.filter { selectedDevices.contains($0.id) }
        var images: [UIImage] = []
        for item in items {
            let view = LabelDesignView(device: item, companyId: viewModel.companyId)
            let img = view.snapshot(size: selectedLabelSize.cgSize)
            for _ in 0..<printCopies {
                images.append(img)
            }
        }
        
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Batch QR Labels"
        printInfo.outputType = .photo
        
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItems = images
        controller.present(animated: true) { _, _, _ in }
    }
    
    private func shareLabels() {
        let items = viewModel.filteredDevices.filter { selectedDevices.contains($0.id) }
        guard let first = items.first else { return }
        
        let view = LabelDesignView(device: first, companyId: viewModel.companyId)
        sharedImage = view.snapshot(size: selectedLabelSize.cgSize)
        showShareSheet = true
    }
}

// Share Sheet Wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

// The UI component for the label
struct LabelDesignView: View {
    let device: ThietBi
    let companyId: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(uiImage: generateQRCode(from: device.id))
                .resizable()
                .interpolation(.none)
                .frame(width: 100, height: 100)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(companyId)
                    .font(.system(size: 12, weight: .bold))
                Text(device.ten)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                Text("Mã: \(device.id)")
                    .font(.system(size: 14))
                if let dept = device.phongBan, !dept.isEmpty {
                    Text("Phòng: \(dept)")
                        .font(.system(size: 12))
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.white)
        .border(Color.black, width: 2)
    }
}

struct LabelPreviewView: View {
    let device: ThietBi
    let companyId: String
    
    var body: some View {
        LabelDesignView(device: device, companyId: companyId)
            .scaleEffect(0.8)
    }
}

struct FilterChip: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(action: { selection = opt }) {
                    HStack {
                        Text(opt == "ALL" ? "Tất cả" : opt)
                        if selection == opt { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack {
                Text("\(title): \(selection == "ALL" ? "Tất cả" : selection)")
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
        }
    }
}

extension Color {
    static let appPrimary = Color(hex: "#002A8F")
    static let appBackground = Color(UIColor.systemGroupedBackground)
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
