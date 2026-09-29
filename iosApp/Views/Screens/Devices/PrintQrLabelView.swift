import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - MÀN HÌNH IN TEM NHÃN & BIÊN BẢN (ĐỒNG BỘ 1:1 VỚI PRINTSCREEN.KT TRÊN ANDROID)
public struct PrintQrLabelView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var deviceId: String?
    var onBack: () -> Void

    // 4 Tabs đồng bộ 1:1 Android PrintScreen
    @State private var selectedTab: Int = 0 // 0: In tem QR, 1: In biên bản, 2: Xuất file, 3: Chia sẻ

    // TAB 0: In tem QR
    @State private var selectedDevices = Set<String>()
    @State private var searchQuery: String = ""
    @State private var selectedStatusFilter: String = "TẤT CẢ"
    @State private var labelSizeIndex: Int = 0
    let labelSizes = ["50x30 mm", "60x40 mm", "72x22 mm", "35x22 mm (x2)", "A4 Decal"]

    @State private var isBarcodeMode: Bool = false // false: QR, true: Barcode 128
    @State private var showDeviceId: Bool = true
    @State private var showDeviceName: Bool = true
    @State private var showUnit: Bool = true
    @State private var showCompanyHeader: Bool = true
    @State private var showBorder: Bool = true
    @State private var customCompanyHeader: String = ""
    @State private var printCopies: Int = 1

    // TAB 1: In biên bản
    @State private var receiptTypeIndex: Int = 0
    let receiptTypes = [
        "Biên bản bàn giao thiết bị",
        "Phiếu xuất kho",
        "Phiếu nhập kho thiết bị",
        "Biên bản mượn trả thiết bị"
    ]
    @State private var receiptGiverName: String = ""
    @State private var receiptReceiverName: String = ""
    @State private var receiptNotes: String = ""

    // TAB 2: Xuất file
    @State private var exportFormatIndex: Int = 0
    let exportFormats = ["Excel (.csv)", "Báo cáo PDF", "Danh sách in (.txt)"]

    // Share sheet
    @State private var shareItems: [Any]? = nil
    @State private var showShareSheet: Bool = false
    @State private var toastMessage: String? = nil

    private let ciContext = CIContext()

    public init(viewModel: DeviceViewModel, deviceId: String? = nil, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.deviceId = deviceId
        self.onBack = onBack
    }

    // Thiết bị hiển thị theo phân quyền nghiêm ngặt của DeviceViewModel
    private var baseDevices: [ThietBi] {
        viewModel.filteredDevices
    }

    private var devicesToDisplay: [ThietBi] {
        var list = baseDevices
        if selectedStatusFilter != "TẤT CẢ" {
            list = list.filter { dev in
                let s = dev.trangThai.lowercased()
                switch selectedStatusFilter {
                case "SỬ DỤNG": return s.contains("sử dụng") || s.contains("trong kho") || s.contains("sẵn sàng") || s.contains("mới")
                case "BẢO HÀNH": return s.contains("bảo hành") || s.contains("sửa") || s.contains("hỏng")
                case "CHO MƯỢN": return s.contains("mượn")
                case "THANH LÝ": return s.contains("thanh lý")
                default: return true
                }
            }
        }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.ten.lowercased().contains(q) ||
                $0.id.lowercased().contains(q) ||
                $0.tenDonVi.lowercased().contains(q)
            }
        }
        return list
    }

    private var effectiveCompanyTitle: String {
        if !customCompanyHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customCompanyHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return viewModel.companyId.isEmpty ? "HỆ THỐNG QLTB" : viewModel.companyId
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("In ấn & Xuất báo cáo")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            // Help indicator
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#FBBF24"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        // 4 TABS NAVIGATION
                        tabBarHeader
                    }
                    .background(Color.appTopBarColor)

                    // NỘI DUNG TỪNG TAB
                    ScrollView {
                        VStack(spacing: 14) {
                            switch selectedTab {
                            case 0:
                                printQrTabContent
                            case 1:
                                printReceiptTabContent
                            case 2:
                                exportFileTabContent
                            default:
                                shareTabContent
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(14)
                    }
                }

                // Toast overlay
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(20)
                            .padding(.bottom, 60)
                    }
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear {
                if let devId = deviceId {
                    selectedDevices.insert(devId)
                }
                receiptGiverName = viewModel.user.fullName
            }
            .sheet(isPresented: $showShareSheet) {
                if let items = shareItems {
                    ActivityView(activityItems: items)
                }
            }
        }
    }

    // MARK: - 4 TABS NAVIGATION BAR
    private var tabBarHeader: some View {
        HStack(spacing: 0) {
            tabButton(title: "In tem QR", icon: "qrcode", index: 0)
            tabButton(title: "In biên bản", icon: "doc.text.fill", index: 1)
            tabButton(title: "Xuất file", icon: "tablecells.badge.ellipsis", index: 2)
            tabButton(title: "Chia sẻ", icon: "square.and.arrow.up.fill", index: 3)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? Color.appPrimaryPink : Color.white.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white : Color.clear)
            .cornerRadius(8)
        }
    }

    // MARK: - ================================================================
    // MARK: - TAB 0: IN TEM QR (CHÍNH)
    // MARK: - ================================================================
    private var printQrTabContent: some View {
        VStack(spacing: 14) {
            // Cấu hình khổ tem & Loại mã
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("CẤU HÌNH KHỔ TEM & LOẠI MÃ")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Spacer()
                }

                // Khổ tem
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<labelSizes.count, id: \.self) { i in
                            let isSel = labelSizeIndex == i
                            Button(action: { labelSizeIndex = i }) {
                                Text(labelSizes[i])
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(isSel ? .white : Color.appSecondaryDarkBlue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSel ? Color.appPrimaryPink : Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                            }
                        }
                    }
                }

                // Mã QR hoặc Barcode 128
                HStack(spacing: 12) {
                    Button(action: { isBarcodeMode = false }) {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode")
                            Text("Mã vuông (QR Code)")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(!isBarcodeMode ? .white : Color.appSecondaryDarkBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!isBarcodeMode ? Color.appSecondaryDarkBlue : Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    Button(action: { isBarcodeMode = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "barcode")
                            Text("Mã vạch (Code 128)")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isBarcodeMode ? .white : Color.appSecondaryDarkBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isBarcodeMode ? Color.appSecondaryDarkBlue : Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }
                }

                // Tuỳ chọn thông tin hiển thị trên tem
                VStack(spacing: 8) {
                    HStack {
                        Toggle("Mã thiết bị", isOn: $showDeviceId)
                            .font(.system(size: 12, weight: .medium))
                        Spacer(minLength: 20)
                        Toggle("Tên thiết bị", isOn: $showDeviceName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    HStack {
                        Toggle("Đơn vị sở hữu", isOn: $showUnit)
                            .font(.system(size: 12, weight: .medium))
                        Spacer(minLength: 20)
                        Toggle("Khung viền", isOn: $showBorder)
                            .font(.system(size: 12, weight: .medium))
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "building.2")
                            .foregroundColor(.gray)
                        TextField("Tiêu đề công ty trên tem...", text: $customCompanyHeader)
                            .font(.system(size: 12))
                    }
                    .padding(8)
                    .background(Color.appBackground)
                    .cornerRadius(8)
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.appPrimaryPink))
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

            // XEM TRƯỚC TEM NHÃN TRỰC QUAN
            if let firstId = selectedDevices.first,
               let dev = baseDevices.first(where: { $0.id == firstId }) {
                livePreviewCard(for: dev)
            } else if let firstDev = baseDevices.first {
                livePreviewCard(for: firstDev)
            }

            // HÀNG NÚT HÀNH ĐỘNG IN
            HStack(spacing: 12) {
                Button(action: executePrint) {
                    HStack(spacing: 8) {
                        Image(systemName: "printer.fill")
                        Text("In \(selectedDevices.count) tem")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(selectedDevices.isEmpty ? Color.gray : Color.appPrimaryPink)
                    .cornerRadius(12)
                }
                .disabled(selectedDevices.isEmpty)

                Button(action: exportPdfLabels) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("PDF")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .frame(width: 80, height: 48)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimaryPink, lineWidth: 1.5))
                }
                .disabled(selectedDevices.isEmpty)
            }

            // DANH SÁCH CHỌN THIẾT BỊ IN
            deviceSelectionSection
        }
    }

    // MARK: - LIVE PREVIEW CARD
    private func livePreviewCard(for dev: ThietBi) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("XEM TRƯỚC TEM THỰC TẾ (\(labelSizes[labelSizeIndex]))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text("Đang chọn: \(selectedDevices.count) tem")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appPrimaryPink)
            }

            // Khung nhãn
            HStack(alignment: .center, spacing: 12) {
                // Text bên trái
                VStack(alignment: .leading, spacing: 3) {
                    if showCompanyHeader {
                        Text(effectiveCompanyTitle.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .lineLimit(1)
                    }

                    if showDeviceName {
                        Text(dev.ten)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)
                            .lineLimit(2)
                    }

                    if showDeviceId {
                        Text("Mã TB: \(dev.id)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }

                    if showUnit {
                        Text("Đơn vị: \(dev.tenDonVi)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Mã vạch / QR bên phải
                if isBarcodeMode {
                    if let bcImg = generateBarcode128(from: dev.id) {
                        Image(uiImage: bcImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 85, height: 50)
                    }
                } else {
                    if let qrImg = generateQRCode(from: dev.id) {
                        Image(uiImage: qrImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 65, height: 65)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(showBorder ? 6 : 0)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(showBorder ? Color.black : Color.clear, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - DANH SÁCH CHỌN THIẾT BỊ
    private var deviceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DANH SÁCH THIẾT BỊ (\(devicesToDisplay.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Spacer()

                Button(action: {
                    if selectedDevices.count == devicesToDisplay.count {
                        selectedDevices.removeAll()
                    } else {
                        selectedDevices = Set(devicesToDisplay.map { $0.id })
                    }
                }) {
                    Text(selectedDevices.count == devicesToDisplay.count ? "Bỏ chọn tất cả" : "Chọn tất cả")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                }
            }

            // Chips lọc trạng thái
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["TẤT CẢ", "SỬ DỤNG", "BẢO HÀNH", "CHO MƯỢN", "THANH LÝ"], id: \.self) { st in
                        let isSel = selectedStatusFilter == st
                        Button(action: { selectedStatusFilter = st }) {
                            Text(st)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isSel ? .white : Color.appSecondaryDarkBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSel ? Color.appPrimaryPink : Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                        }
                    }
                }
            }

            // Tìm kiếm
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Tìm theo tên, mã thiết bị, đơn vị...", text: $searchQuery)
                    .font(.system(size: 13))
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

            // Danh sách thẻ thiết bị có checkbox
            VStack(spacing: 6) {
                ForEach(devicesToDisplay) { dev in
                    let isSelected = selectedDevices.contains(dev.id)
                    Button(action: {
                        if isSelected {
                            selectedDevices.remove(dev.id)
                        } else {
                            selectedDevices.insert(dev.id)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? Color.appPrimaryPink : .gray)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.ten)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                                    .lineLimit(1)
                                Text("Mã: \(dev.id) • \(dev.tenDonVi)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.appTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(dev.statusNormalized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(dev.statusColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(dev.statusColor.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .padding(10)
                        .background(isSelected ? Color.appPrimaryPink.opacity(0.06) : Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: isSelected ? 1.5 : 1))
                    }
                }
            }
        }
    }

    // MARK: - ================================================================
    // MARK: - TAB 1: IN BIÊN BẢN (RECEIPTS)
    // MARK: - ================================================================
    private var printReceiptTabContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("CHỌN LOẠI BIÊN BẢN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                ForEach(0..<receiptTypes.count, id: \.self) { i in
                    let isSel = receiptTypeIndex == i
                    Button(action: { receiptTypeIndex = i }) {
                        HStack {
                            Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                            Text(receiptTypes[i])
                                .font(.system(size: 13, weight: isSel ? .bold : .medium))
                                .foregroundColor(Color.appTextPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .background(isSel ? Color.appPrimaryPink.opacity(0.06) : Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

            // THÔNG TIN BÀN GIAO
            VStack(alignment: .leading, spacing: 10) {
                Text("THÔNG TIN BIÊN BẢN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                VStack(spacing: 8) {
                    TextField("Họ tên bên giao / người xuất...", text: $receiptGiverName)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.appBackground)
                        .cornerRadius(8)

                    TextField("Họ tên bên nhận / người nhận...", text: $receiptReceiverName)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.appBackground)
                        .cornerRadius(8)

                    TextField("Ghi chú / Lý do bàn giao...", text: $receiptNotes)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.appBackground)
                        .cornerRadius(8)
                }

                Text("Đã chọn: \(selectedDevices.count) thiết bị đính kèm vào biên bản")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.appPrimaryPink)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

            // NÚT IN BIÊN BẢN
            Button(action: generateAndPrintReceipt) {
                HStack(spacing: 8) {
                    Image(systemName: "printer.fill")
                    Text("In biên bản ngay (A4)")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(selectedDevices.isEmpty ? Color.gray : Color.appSecondaryDarkBlue)
                .cornerRadius(12)
            }
            .disabled(selectedDevices.isEmpty)

            deviceSelectionSection
        }
    }

    // MARK: - ================================================================
    // MARK: - TAB 2: XUẤT FILE (EXCEL / PDF)
    // MARK: - ================================================================
    private var exportFileTabContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ĐỊNH DẠNG XUẤT DỮ LIỆU")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                ForEach(0..<exportFormats.count, id: \.self) { i in
                    let isSel = exportFormatIndex == i
                    Button(action: { exportFormatIndex = i }) {
                        HStack {
                            Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                            Text(exportFormats[i])
                                .font(.system(size: 13, weight: isSel ? .bold : .medium))
                                .foregroundColor(Color.appTextPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .background(isSel ? Color.appPrimaryPink.opacity(0.06) : Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

            Button(action: executeExportFile) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text("Xuất & Chia sẻ file (\(selectedDevices.isEmpty ? devicesToDisplay.count : selectedDevices.count) máy)")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.appPrimaryPink)
                .cornerRadius(12)
            }

            deviceSelectionSection
        }
    }

    // MARK: - ================================================================
    // MARK: - TAB 3: CHIA SẺ
    // MARK: - ================================================================
    private var shareTabContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("CHIA SẺ DỮ LIỆU BÁO CÁO")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text("Hỗ trợ gửi tài liệu báo cáo, tem in và danh sách thiết bị qua Zalo, Mail, AirDrop, hoặc lưu vào Tệp:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                VStack(spacing: 8) {
                    shareOptionRow(icon: "message.fill", title: "Gửi danh sách qua Zalo / Tin nhắn", color: Color.blue) {
                        shareDeviceTextList()
                    }
                    shareOptionRow(icon: "envelope.fill", title: "Gửi báo cáo qua Email", color: Color.red) {
                        executeExportFile()
                    }
                    shareOptionRow(icon: "airplayaudio", title: "Truyền nhanh qua AirDrop", color: Color.purple) {
                        exportPdfLabels()
                    }
                    shareOptionRow(icon: "folder.fill", title: "Lưu file vào Tệp (Files)", color: Color.orange) {
                        executeExportFile()
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
        }
    }

    private func shareOptionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
        }
    }

    // MARK: - PRINT & EXPORT ENGINE
    private func executePrint() {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "QLTB_TemNhan_\(viewModel.companyId)"
        printController.printInfo = printInfo

        let images = generateImagesForSelected()
        if images.isEmpty { return }

        printController.printingItems = images
        printController.present(animated: true) { _, completed, error in
            if completed {
                showToast("✅ Đã hoàn tất lệnh in!")
            } else if let err = error {
                showToast("❌ Lỗi in: \(err.localizedDescription)")
            }
        }
    }

    private func exportPdfLabels() {
        let images = generateImagesForSelected()
        if images.isEmpty { return }

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: getLabelSizeInPoints()), nil)

        for img in images {
            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: img.size), nil)
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }
        UIGraphicsEndPDFContext()

        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("TemNhan_\(Date().timeIntervalSince1970).pdf")
        do {
            try pdfData.write(to: tempUrl)
            self.shareItems = [tempUrl]
            self.showShareSheet = true
        } catch {
            showToast("Lỗi xuất PDF: \(error.localizedDescription)")
        }
    }

    private func generateAndPrintReceipt() {
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        var html = """
        <html>
        <head>
        <meta charset='utf-8'>
        <style>
          body { font-family: -apple-system, sans-serif; padding: 20px; color: #1e293b; }
          h2 { text-align: center; color: #002a8f; margin-bottom: 4px; }
          .sub { text-align: center; font-size: 12px; color: #64748b; margin-bottom: 20px; }
          table { width: 100%; border-collapse: collapse; margin-top: 14px; }
          th, td { border: 1px solid #cbd5e1; padding: 8px; font-size: 12px; }
          th { background: #f1f5f9; text-align: left; }
          .sign { margin-top: 40px; display: flex; justify-content: space-between; }
        </style>
        </head>
        <body>
        <h2>\(receiptTypes[receiptTypeIndex].uppercased())</h2>
        <div class='sub'>Công ty: \(effectiveCompanyTitle) • Thời gian: \(dateStr)</div>
        <p><b>Bên giao:</b> \(receiptGiverName.isEmpty ? "...................................." : receiptGiverName)</p>
        <p><b>Bên nhận:</b> \(receiptReceiverName.isEmpty ? "...................................." : receiptReceiverName)</p>
        <p><b>Ghi chú:</b> \(receiptNotes.isEmpty ? "Không có" : receiptNotes)</p>
        <table>
        <tr><th>STT</th><th>Mã TB</th><th>Tên thiết bị</th><th>Đơn vị</th><th>Trạng thái</th></tr>
        """

        let targetDevs = baseDevices.filter { selectedDevices.contains($0.id) }
        for (idx, dev) in targetDevs.enumerated() {
            html += "<tr><td>\(idx + 1)</td><td>\(dev.id)</td><td>\(dev.ten)</td><td>\(dev.tenDonVi)</td><td>\(dev.statusNormalized)</td></tr>"
        }

        html += """
        </table>
        <div style='margin-top: 30px;'>
          <table style='border: none;'>
            <tr style='border: none;'>
              <td style='border: none; text-align: center;'><b>ĐẠI DIỆN BÊN GIAO</b><br><br><br>\(receiptGiverName)</td>
              <td style='border: none; text-align: center;'><b>ĐẠI DIỆN BÊN NHẬN</b><br><br><br>\(receiptReceiverName)</td>
            </tr>
          </table>
        </div>
        </body></html>
        """

        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = receiptTypes[receiptTypeIndex]
        printController.printInfo = printInfo
        printController.printFormatter = formatter
        printController.present(animated: true, completionHandler: nil)
    }

    private func executeExportFile() {
        let targetDevs = selectedDevices.isEmpty ? devicesToDisplay : baseDevices.filter { selectedDevices.contains($0.id) }
        if targetDevs.isEmpty {
            showToast("Chưa có thiết bị nào để xuất!")
            return
        }

        // CSV export
        var csv = "Mã thiết bị,Tên thiết bị,Đơn vị,Phòng ban,Loại,Trạng thái,Người tạo,Thời gian tạo\n"
        for d in targetDevs {
            csv += "\"\(d.id)\",\"\(d.ten)\",\"\(d.tenDonVi)\",\"\(d.phongBan ?? "")\",\"\(d.loai ?? "")\",\"\(d.statusNormalized)\",\"\(d.createdBy ?? "")\",\"\(d.createdAt)\"\n"
        }

        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("DanhSachThietBi_\(Date().timeIntervalSince1970).csv")
        do {
            try csv.write(to: tempUrl, atomically: true, encoding: .utf8)
            self.shareItems = [tempUrl]
            self.showShareSheet = true
        } catch {
            showToast("Lỗi xuất file: \(error.localizedDescription)")
        }
    }

    private func shareDeviceTextList() {
        let targetDevs = selectedDevices.isEmpty ? devicesToDisplay : baseDevices.filter { selectedDevices.contains($0.id) }
        var text = "📋 DANH SÁCH THIẾT BỊ (\(targetDevs.count) máy) - \(effectiveCompanyTitle)\n"
        for (i, d) in targetDevs.enumerated() {
            text += "\(i + 1). [\(d.id)] \(d.ten) - \(d.tenDonVi) (\(d.statusNormalized))\n"
        }
        self.shareItems = [text]
        self.showShareSheet = true
    }

    private func showToast(_ msg: String) {
        self.toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.toastMessage == msg {
                self.toastMessage = nil
            }
        }
    }

    // MARK: - IMAGE DRAWING FOR LABELS
    private func getLabelSizeInPoints() -> CGSize {
        switch labelSizeIndex {
        case 0: return CGSize(width: 141.7, height: 85.0)  // 50x30 mm
        case 1: return CGSize(width: 170.0, height: 113.4) // 60x40 mm
        case 2: return CGSize(width: 204.0, height: 62.4)  // 72x22 mm
        case 3: return CGSize(width: 99.2, height: 62.4)   // 35x22 mm
        default: return CGSize(width: 141.7, height: 85.0)
        }
    }

    private func generateImagesForSelected() -> [UIImage] {
        let size = getLabelSizeInPoints()
        var images = [UIImage]()
        let targetDevs = baseDevices.filter { selectedDevices.contains($0.id) }

        for dev in targetDevs {
            for _ in 0..<max(1, printCopies) {
                images.append(drawLabel(dev: dev, size: size))
            }
        }
        return images
    }

    private func drawLabel(dev: ThietBi, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            if showBorder {
                UIColor.black.setStroke()
                context.stroke(CGRect(origin: .zero, size: size))
            }

            let margin: CGFloat = 6
            let codeSize: CGFloat = min(size.height - margin * 2, 70)

            if isBarcodeMode {
                if let bc = generateBarcode128(from: dev.id) {
                    bc.draw(in: CGRect(x: size.width - margin - codeSize - 15, y: (size.height - 40) / 2, width: codeSize + 15, height: 40))
                }
            } else {
                if let qr = generateQRCode(from: dev.id) {
                    qr.draw(in: CGRect(x: size.width - margin - codeSize, y: (size.height - codeSize) / 2, width: codeSize, height: codeSize))
                }
            }

            let textWidth = size.width - codeSize - margin * 3
            var y: CGFloat = margin

            if showCompanyHeader {
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: UIColor(red: 0, green: 42/255, blue: 143/255, alpha: 1)
                ]
                effectiveCompanyTitle.uppercased().draw(in: CGRect(x: margin, y: y, width: textWidth, height: 13), withAttributes: titleAttrs)
                y += 13
            }

            if showDeviceName {
                let nameAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 9.5),
                    .foregroundColor: UIColor.black
                ]
                dev.ten.draw(in: CGRect(x: margin, y: y, width: textWidth, height: 24), withAttributes: nameAttrs)
                y += 24
            }

            if showDeviceId {
                let codeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8.5, weight: .bold),
                    .foregroundColor: UIColor(red: 0, green: 42/255, blue: 143/255, alpha: 1)
                ]
                "Mã: \(dev.id)".draw(in: CGRect(x: margin, y: y, width: textWidth, height: 12), withAttributes: codeAttrs)
                y += 12
            }

            if showUnit {
                let unitAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7.5),
                    .foregroundColor: UIColor.darkGray
                ]
                dev.tenDonVi.draw(in: CGRect(x: margin, y: y, width: textWidth, height: 11), withAttributes: unitAttrs)
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 8, y: 8)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }

    private func generateBarcode128(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 3, y: 3)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}

// MARK: - ActivityView for Sharing
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
