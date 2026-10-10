import SwiftUI
import UIKit
import WebKit
import CoreImage.CIFilterBuiltins

// MARK: - MÀN HÌNH IN ẤN & TEM NHÃN (ĐỒNG BỘ 1:1 VỚI PRINTSCREEN.KT TRÊN ANDROID)

// MARK: - 1. ENUMS KHỔ TEM & BỐ CỤC (CHUẨN 1:1 ANDROID)
public enum LabelPaperSize: String, CaseIterable, Identifiable {
    case decal1 = "decal1"
    case decal40_30 = "decal40_30"
    case decal50_25 = "decal50_25"
    case decal60_40 = "decal60_40"
    case decal70_50 = "decal70_50"
    case decal100_50 = "decal100_50"
    case decal2 = "decal2"
    case decal3 = "decal3"
    case k80 = "k80"
    case k58 = "k58"
    case a4_65 = "a4_65"
    case a4_30 = "a4_30"
    case a4_18 = "a4_18"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .decal1: return "Decal 1 tem cuộn (50x30 mm)"
        case .decal40_30: return "Decal 1 tem cuộn (40x30 mm)"
        case .decal50_25: return "Decal 1 tem cuộn (50x25 mm)"
        case .decal60_40: return "Decal 1 tem cuộn (60x40 mm)"
        case .decal70_50: return "Decal 1 tem cuộn (70x50 mm)"
        case .decal100_50: return "Decal 1 tem cuộn (100x50 mm)"
        case .decal2: return "Decal 2 tem cuộn (35x22 mm)"
        case .decal3: return "Decal 3 tem cuộn (35x22 mm)"
        case .k80: return "Giấy in nhiệt K80"
        case .k58: return "Giấy in nhiệt K58"
        case .a4_65: return "Khổ A4 (65 tem Tomy 145 - 38x21 mm)"
        case .a4_30: return "Khổ A4 (30 tem Tomy 138 - 100x38 mm)"
        case .a4_18: return "Khổ A4 (18 tem Tomy 133 - 101x33 mm)"
        }
    }

    public var description: String {
        switch self {
        case .decal1: return "Chuẩn phổ biến Datamax, Citizen, Zebra, TSC, Godex, Xprinter"
        case .decal40_30: return "Tem nhỏ gọn 1 tem/hàng (40x30 mm)"
        case .decal50_25: return "Tem nhãn hẹp 1 tem/hàng (50x25 mm)"
        case .decal60_40: return "Tem nhãn vừa 1 tem/hàng (60x40 mm)"
        case .decal70_50: return "Tem nhãn lớn 1 tem/hàng (70x50 mm)"
        case .decal100_50: return "Tem tài sản lớn 1 tem/hàng (100x50 mm)"
        case .decal2: return "Khổ cuộn 2 tem / hàng (Tổng 72x22 mm)"
        case .decal3: return "Khổ cuộn 3 tem / hàng (Tổng 110x22 mm)"
        case .k80: return "Khổ cuộn hóa đơn K80 (80x80 mm)"
        case .k58: return "Khổ cuộn hóa đơn K58 (58x50 mm)"
        case .a4_65: return "Tờ A4 gồm 65 tem (5 cột x 13 hàng)"
        case .a4_30: return "Tờ A4 gồm 30 tem (2 cột x 15 hàng)"
        case .a4_18: return "Tờ A4 gồm 18 tem (2 cột x 9 hàng)"
        }
    }

    public var itemWidthMm: CGFloat {
        switch self {
        case .decal1: return 50
        case .decal40_30: return 40
        case .decal50_25: return 50
        case .decal60_40: return 60
        case .decal70_50: return 70
        case .decal100_50: return 100
        case .decal2: return 35
        case .decal3: return 33.5
        case .k80: return 80
        case .k58: return 58
        case .a4_65: return 38
        case .a4_30: return 100
        case .a4_18: return 101
        }
    }

    public var itemHeightMm: CGFloat {
        switch self {
        case .decal1: return 30
        case .decal40_30: return 30
        case .decal50_25: return 25
        case .decal60_40: return 40
        case .decal70_50: return 50
        case .decal100_50: return 50
        case .decal2: return 22
        case .decal3: return 20.5
        case .k80: return 80
        case .k58: return 50
        case .a4_65: return 21
        case .a4_30: return 38
        case .a4_18: return 33
        }
    }

    public var isRoll: Bool {
        switch self {
        case .a4_65, .a4_30, .a4_18: return false
        default: return true
        }
    }
}

public enum LabelLayoutMode: String, CaseIterable, Identifiable {
    case qrLeftTextRight = "Mã QR Trái - Chữ Phải"
    case qrTopTextBottom = "Mã QR Trên - Chữ Dưới"
    case qrOnlyWithCode = "Mã QR + Mã Serial (Tối giản)"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .qrLeftTextRight: return "Bố cục ngang tiêu chuẩn cho hầu hết máy in tem nhiệt"
        case .qrTopTextBottom: return "Bố cục dọc phù hợp tem vuông hoặc tem nhỏ"
        case .qrOnlyWithCode: return "Chỉ in QR Code lớn và mã thiết bị, tối đa hóa diện tích quét"
        }
    }
}

public enum LabelPrintOrientation: String, CaseIterable, Identifiable {
    case auto = "Tự động nhận diện"
    case landscape = "In Ngang (0°)"
    case portrait = "In Dọc (90°)"
    case rotate180 = "Đảo ngược 180°"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .auto: return "Tự động phát hiện theo kích thước tem W x H"
        case .landscape: return "Chuẩn cho máy in tem cuộn Datamax, Citizen, Zebra"
        case .portrait: return "Tem đứng hoặc in qua giấy decal A4"
        case .rotate180: return "In lộn ngược hướng cuộn giấy cho Citizen / Datamax"
        }
    }
}

public enum ReportPageOrientation: String, CaseIterable, Identifiable {
    case portrait = "Khổ Dọc (A4)"
    case landscape = "Khổ Ngang (A4)"

    public var id: String { rawValue }
}

// MARK: - MAIN VIEW
public struct PrintQrLabelView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var deviceId: String?
    var onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    // 4 Tabs chuẩn 1:1 Android PrintScreen:
    // 0: In Tem Nhãn, 1: In Biên Bản & Báo Cáo, 2: Xuất File (Excel / PDF), 3: Chia Sẻ
    @State private var selectedTab: Int = 0

    // BỘ LỌC CHUNG TOÀN MÀN HÌNH (CHUẨN ANDROID)
    @State private var selectedExportDonVi: String = "Tất cả đơn vị"
    @State private var selectedExportPhongBan: String = "Tất cả phòng ban"
    @State private var selectedPrintFilter: String = "Tất cả thiết bị"
    @State private var searchQuery: String = ""

    // TAB 0: CẤU HÌNH IN TEM NHÃN MÃ QR
    @State private var labelPaperSize: LabelPaperSize = .decal3
    @State private var labelLayoutMode: LabelLayoutMode = .qrLeftTextRight
    @State private var labelOrientation: LabelPrintOrientation = .auto
    @State private var labelShowQr: Bool = true
    @State private var labelShowDeviceId: Bool = true
    @State private var labelShowDeviceName: Bool = true
    @State private var labelShowCompanyName: Bool = false // Mặc định tắt tiêu đề theo yêu cầu
    @State private var labelCustomCompanyHeader: String = ""
    @State private var labelShowUnit: Bool = false
    @State private var labelShowDepartment: Bool = false
    @State private var labelShowStatus: Bool = false
    @State private var labelShowBorder: Bool = false // Mặc định không chọn khung viền
    @State private var labelFontSizeScale: Double = 1.0 // 0.85 (Nhỏ), 1.0 (Vừa), 1.15 (Lớn)
    @State private var printCopies: Int = 1
    @State private var selectedDevices = Set<String>()

    // TAB 1: CẤU HÌNH IN BIÊN BẢN & BÁO CÁO
    @State private var selectedReportTitle: String = "Biên bản Bàn giao Thiết bị"
    @State private var customReportTitle: String = "BIÊN BẢN BÀN GIAO THIẾT BỊ"
    @State private var pageOrientation: ReportPageOrientation = .portrait
    @State private var receiptGiverName: String = ""
    @State private var receiptReceiverName: String = ""
    @State private var receiptNotes: String = ""

    // TAB 2: XUẤT FILE (EXCEL / PDF)
    @State private var selectedFormat: String = "Excel (.xlsx)"
    @State private var selectedExtraOption: String = "Mặc định"

    // TAB 3: CHIA SẺ
    @State private var selectedSendMethod: String = "Ứng dụng Zalo"

    // MODAL DIALOGS / SHEETS
    @State private var showDonViPicker: Bool = false
    @State private var showPhongBanPicker: Bool = false
    @State private var showStatusPicker: Bool = false
    @State private var showPaperSizePicker: Bool = false
    @State private var showReportTitlePicker: Bool = false
    @State private var showCoachMarks: Bool = false
    @State private var showHtmlPreview: Bool = false
    @State private var inAppPreviewHtml: String = ""
    @State private var inAppPreviewTitle: String = ""

    // Share sheet & Toast
    @State private var shareItems: [Any]? = nil
    @State private var showShareSheet: Bool = false
    @State private var toastMessage: String? = nil

    private let ciContext = CIContext()

    public init(viewModel: DeviceViewModel, deviceId: String? = nil, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.deviceId = deviceId
        self.onBack = onBack
    }

    // MARK: - FILTERED LIST OF DEVICES
    private var baseDevices: [ThietBi] {
        viewModel.filteredDevices.isEmpty ? viewModel.rawDevices : viewModel.filteredDevices
    }

    private var availableDonVis: [String] {
        var list = ["Tất cả đơn vị"]
        let fromDevs = baseDevices.map { $0.tenDonVi.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let allUnique = Array(Set(viewModel.units + fromDevs)).sorted()
        list.append(contentsOf: allUnique)
        return list
    }

    private var availablePhongBans: [String] {
        var list = ["Tất cả phòng ban"]
        let fromDevs = baseDevices.compactMap { $0.phongBan?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let allUnique = Array(Set(viewModel.departments + fromDevs)).sorted()
        list.append(contentsOf: allUnique)
        return list
    }

    private let statusOptions = [
        "Tất cả thiết bị",
        "Trong kho (Sẵn sàng)",
        "Đang sử dụng",
        "Cho mượn",
        "Bảo hành / Sửa chữa",
        "Hỏng / Chờ xử lý",
        "Đã thanh lý",
        "Mới nhập"
    ]

    private var filteredExportDevices: [ThietBi] {
        var list = baseDevices

        // 1. Filter theo Đơn vị
        if selectedExportDonVi != "Tất cả đơn vị" {
            list = list.filter { $0.tenDonVi.caseInsensitiveCompare(selectedExportDonVi) == .orderedSame }
        }

        // 2. Filter theo Phòng ban
        if selectedExportPhongBan != "Tất cả phòng ban" {
            list = list.filter { ($0.phongBan ?? "").caseInsensitiveCompare(selectedExportPhongBan) == .orderedSame }
        }

        // 3. Filter theo Trạng thái
        if selectedPrintFilter != "Tất cả thiết bị" {
            list = list.filter { dev in
                let s = dev.trangThai.lowercased()
                switch selectedPrintFilter {
                case "Trong kho (Sẵn sàng)":
                    return s.contains("kho") || s.contains("sẵn sàng") || s.contains("mới")
                case "Đang sử dụng":
                    return s.contains("sử dụng")
                case "Cho mượn":
                    return s.contains("mượn")
                case "Bảo hành / Sửa chữa":
                    return s.contains("bảo hành") || s.contains("sửa")
                case "Hỏng / Chờ xử lý":
                    return s.contains("hỏng") || s.contains("hư")
                case "Đã thanh lý":
                    return s.contains("thanh lý")
                case "Mới nhập":
                    return s.contains("mới")
                default:
                    return true
                }
            }
        }

        // 4. Tìm kiếm từ khóa
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.ten.lowercased().contains(q) ||
                $0.id.lowercased().contains(q) ||
                $0.tenDonVi.lowercased().contains(q) ||
                ($0.phongBan?.lowercased().contains(q) ?? false)
            }
        }

        return list
    }

    private var displayCompanyName: String {
        if !labelCustomCompanyHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return labelCustomCompanyHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return viewModel.companyId.isEmpty ? "IT SERVICE & ASSETS" : viewModel.companyId
    }

    // MARK: - BODY
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR CHUẨN ANDROID
                    topBarView(geometry: geometry)

                    // 4 TABS SECONDARY SCROLLABLE BAR
                    tabBarHeader

                    // SCROLLABLE CONTENT
                    ScrollView {
                        VStack(spacing: 12) {
                            switch selectedTab {
                            case 0:
                                tab0PrintQrContent
                            case 1:
                                tab1PrintReceiptContent
                            case 2:
                                tab2ExportFileContent
                            default:
                                tab3ShareContent
                            }

                            Spacer(minLength: 50)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
                viewModel.loadDepartmentsAndUnits()
            }
            // PICKER MODALS
            .sheet(isPresented: $showDonViPicker) {
                SearchablePickerSheet(
                    title: "CHỌN ĐƠN VỊ / CHI NHÁNH",
                    items: availableDonVis,
                    selectedItem: selectedExportDonVi,
                    icon: "storefront",
                    onSelect: { selectedExportDonVi = $0 }
                )
            }
            .sheet(isPresented: $showPhongBanPicker) {
                SearchablePickerSheet(
                    title: "CHỌN PHÒNG BAN QUẢN LÝ",
                    items: availablePhongBans,
                    selectedItem: selectedExportPhongBan,
                    icon: "building.2",
                    onSelect: { selectedExportPhongBan = $0 }
                )
            }
            .sheet(isPresented: $showStatusPicker) {
                SearchablePickerSheet(
                    title: "CHỌN TRẠNG THÁI THIẾT BỊ",
                    items: statusOptions,
                    selectedItem: selectedPrintFilter,
                    icon: "slider.horizontal.3",
                    onSelect: {
                        selectedPrintFilter = $0
                        if $0 != "Tất cả thiết bị" {
                            labelShowStatus = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showPaperSizePicker) {
                PaperSizePickerSheet(
                    selectedSize: labelPaperSize,
                    onSelect: { labelPaperSize = $0 }
                )
            }
            .sheet(isPresented: $showReportTitlePicker) {
                ReportTemplatePickerSheet(
                    selectedTemplate: selectedReportTitle,
                    onSelect: { title, defaultName in
                        selectedReportTitle = title
                        customReportTitle = defaultName
                    }
                )
            }
            .sheet(isPresented: $showCoachMarks) {
                CoachMarksGuideSheet()
            }
            .sheet(isPresented: $showHtmlPreview) {
                InAppReportPreviewSheet(
                    title: inAppPreviewTitle,
                    htmlContent: inAppPreviewHtml
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let items = shareItems {
                    ActivityView(activityItems: items)
                }
            }
        }
    }

    // MARK: - TOP BAR (CHUẨN 1:1 ANDROID: TITLE, BACK, 5 ACTION ICONS)
    private func topBarView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: SafeAreaHelper.top(geometry))

            HStack(spacing: 4) {
                // Back Button
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                // Title: In Ấn & Tem Nhãn
                Text("In Ấn & Tem Nhãn")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Actions 5 icons:
                // 1. Lightbulb (Hướng dẫn)
                Button(action: { showCoachMarks = true }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FBBF24"))
                        .frame(width: 32, height: 32)
                }

                // 2. Tab 0: QR Code
                Button(action: { withAnimation { selectedTab = 0 } }) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                        .foregroundColor(selectedTab == 0 ? Color.appPrimaryPink : Color.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                // 3. Tab 1: Printer
                Button(action: { withAnimation { selectedTab = 1 } }) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                        .foregroundColor(selectedTab == 1 ? Color.appPrimaryPink : Color.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                // 4. Tab 2: Document
                Button(action: { withAnimation { selectedTab = 2 } }) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16, weight: selectedTab == 2 ? .bold : .regular))
                        .foregroundColor(selectedTab == 2 ? Color.appPrimaryPink : Color.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                // 5. Tab 3: Send
                Button(action: { withAnimation { selectedTab = 3 } }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: selectedTab == 3 ? .bold : .regular))
                        .foregroundColor(selectedTab == 3 ? Color.appPrimaryPink : Color.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - SECONDARY SCROLLABLE TAB ROW (CHUẨN 1:1 ANDROID)
    private var tabBarHeader: some View {
        let tabs = [
            ("🏷️ In Tem Nhãn", 0),
            ("📋 In Biên Bản & Báo Cáo", 1),
            ("📊 Xuất File (Excel / PDF)", 2),
            ("📤 Chia Sẻ", 3)
        ]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(tabs, id: \.1) { title, idx in
                    let isSelected = selectedTab == idx
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = idx
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? Color.appPrimaryPink : Color.white.opacity(0.75))
                                .padding(.horizontal, 4)

                            // Underline indicator
                            Rectangle()
                                .fill(isSelected ? Color.appPrimaryPink : Color.clear)
                                .frame(height: 2.5)
                                .cornerRadius(1.5)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - ================================================================
    // MARK: - TAB 0: IN TEM NHÃN (CHUẨN 1:1 ANDROID TỪ BỘ LỌC ĐẾN CARD 1..5)
    // MARK: - ================================================================
    private var tab0PrintQrContent: some View {
        VStack(spacing: 8) {
            // CARD 0: BỘ LỌC THIẾT BỊ IN TEM
            commonFilterCard(subtitle: "Quản trị viên toàn hệ thống")

            // CARD 1: KHỔ TEM IN (MÃ VẠCH & QR)
            CleanCardSection(
                title: "1. Khổ Tem In (Mã Vạch & QR)",
                subtitle: "Datamax, Citizen, Zebra, TSC, Godex, Xprinter, Tomy..."
            ) {
                Button(action: { showPaperSizePicker = true }) {
                    HStack {
                        Text("\(labelPaperSize.label) (\(Int(labelPaperSize.itemWidthMm))x\(Int(labelPaperSize.itemHeightMm))mm)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.appTextPrimary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.appSurfaceVariant.opacity(0.35))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            // CARD 2: BỐ CỤC TEM NHÃN
            CleanCardSection(
                title: "2. Bố Cục Tem Nhãn",
                subtitle: "Cách sắp xếp mã QR và chữ trên tem"
            ) {
                HStack(spacing: 6) {
                    ForEach(LabelLayoutMode.allCases) { mode in
                        let isSel = labelLayoutMode == mode
                        Button(action: { labelLayoutMode = mode }) {
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: isSel ? .bold : .regular))
                                .foregroundColor(isSel ? Color.appPrimaryPink : Color.appTextPrimary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(isSel ? Color.appPrimaryPink.opacity(0.12) : Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder.opacity(0.6), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            // CARD 3: THÔNG TIN IN TRÊN TEM
            CleanCardSection(
                title: "3. Thông Tin In Trên Tem",
                subtitle: "Bật / tắt các trường dữ liệu"
            ) {
                VStack(spacing: 6) {
                    // Row 1: In Mã QR & In Mã Serial
                    HStack {
                        checkboxItem(title: "In Mã QR", isChecked: $labelShowQr)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        checkboxItem(title: "In Mã Serial", isChecked: $labelShowDeviceId)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Row 2: In Tên thiết bị & In Tiêu đề Công ty
                    HStack {
                        checkboxItem(title: "In Tên thiết bị", isChecked: $labelShowDeviceName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        checkboxItem(title: "In Tiêu đề Công ty", isChecked: $labelShowCompanyName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if labelShowCompanyName {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appPrimaryPink)
                            TextField("Tên DN / Tiêu đề ngắn (tùy chọn)", text: $labelCustomCompanyHeader)
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.appSurfaceVariant.opacity(0.35))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    Divider().background(Color.appDivider.opacity(0.3)).padding(.vertical, 2)

                    // Row 3: In tên Đơn vị / Chi nhánh (Kèm gợi ý)
                    HStack(alignment: .top, spacing: 6) {
                        checkboxItem(title: "In tên Đơn vị / Chi nhánh", isChecked: $labelShowUnit)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("💡 Tắt mục này nếu tên đơn vị quá dài để tem thoáng đẹp")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)

                    // Row 4: In Phòng ban & In Trạng thái
                    HStack {
                        checkboxItem(title: "In Phòng ban", isChecked: $labelShowDepartment)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        checkboxItem(title: "In Trạng thái", isChecked: $labelShowStatus)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Row 5: Khung viền tem nhãn
                    HStack {
                        checkboxItem(title: "Khung viền tem nhãn", isChecked: $labelShowBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            // CARD 4: CỠ CHỮ IN
            CleanCardSection(
                title: "4. Cỡ Chữ In",
                subtitle: "Tự động co dãn chống tràn viền"
            ) {
                HStack(spacing: 8) {
                    let sizes: [(String, String, Double)] = [
                        ("Nhỏ", "(0.85x)", 0.85),
                        ("Vừa", "(1.0x)", 1.0),
                        ("Lớn", "(1.15x)", 1.15)
                    ]
                    ForEach(sizes, id: \.0) { lbl, sub, val in
                        let isCur = abs(labelFontSizeScale - val) < 0.01
                        Button(action: { labelFontSizeScale = val }) {
                            Text("\(lbl) \(sub)")
                                .font(.system(size: 11, weight: isCur ? .bold : .regular))
                                .foregroundColor(isCur ? .white : Color.appTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isCur ? Color.appPrimaryPink : Color.appSurfaceVariant.opacity(0.4))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // CARD 5: MÔ PHỎNG XEM TRƯỚC TEM MẪU (WYSIWYG PREVIEW)
            CleanCardSection(
                title: "5. Mô Phỏng Xem Trước Tem Mẫu",
                subtitle: "Kích thước: \(Int(labelPaperSize.itemWidthMm))x\(Int(labelPaperSize.itemHeightMm)) mm (\(labelPaperSize.label))"
            ) {
                livePreviewLabelBox
            }

            // HÀNG NÚT SỐ BẢN COPY & IN TEM
            VStack(spacing: 8) {
                HStack {
                    Text("Số bản copy mỗi tem:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: { if printCopies > 1 { printCopies -= 1 } }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(printCopies > 1 ? Color.appPrimaryPink : .gray)
                        }

                        Text("\(printCopies)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)
                            .frame(minWidth: 24)

                        Button(action: { printCopies += 1 }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appSurfaceVariant.opacity(0.35))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    // Nút In Tem
                    Button(action: executePrint) {
                        HStack(spacing: 6) {
                            Image(systemName: "printer.fill")
                            Text("In Tem (\(selectedDevices.isEmpty ? filteredExportDevices.count : selectedDevices.count))")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(filteredExportDevices.isEmpty ? Color.gray : Color.appPrimaryPink)
                        .cornerRadius(12)
                    }
                    .disabled(filteredExportDevices.isEmpty)

                    // Nút Xem PDF Tem
                    Button(action: exportPdfLabels) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.fill")
                            Text("Xem PDF Tem")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 130, height: 48)
                        .background(Color.appSurface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimaryPink, lineWidth: 1.5))
                    }
                    .disabled(filteredExportDevices.isEmpty)
                }
            }

            // DANH SÁCH CHỌN THIẾT BỊ IN
            deviceSelectionSection
        }
    }

    // MARK: - LIVE PREVIEW CANVAS (WYSIWYG CHUẨN ANDROID)
    private var livePreviewLabelBox: some View {
        let sampleDevice = filteredExportDevices.first ?? baseDevices.first ?? ThietBi(
            id: "TB-2026-001",
            ten: "Máy tính xách tay Dell Latitude 5420",
            tenDonVi: "Tổng công ty Điện lực",
            trangThai: "HOAT_DONG",
            phongBan: "Phòng Kỹ thuật CNTT"
        )

        return VStack(spacing: 4) {
            // Khung nhãn trắng thuần (thể hiện con tem vật lý)
            VStack(alignment: .leading, spacing: 4) {
                // Header tên công ty
                if labelShowCompanyName && !displayCompanyName.isEmpty && labelLayoutMode != .qrOnlyWithCode {
                    Text(displayCompanyName.uppercased())
                        .font(.system(size: CGFloat(10 * labelFontSizeScale), weight: .bold))
                        .foregroundColor(Color(hex: "#002A8F"))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().background(Color(hex: "#CBD5E1"))
                }

                // Layout tuỳ chọn
                switch labelLayoutMode {
                case .qrOnlyWithCode:
                    VStack(alignment: .center, spacing: 4) {
                        if labelShowQr, let qrImg = generateQRCode(from: sampleDevice.id) {
                            Image(uiImage: qrImg)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                        }
                        if labelShowDeviceId {
                            Text(sampleDevice.id)
                                .font(.system(size: CGFloat(11 * labelFontSizeScale), weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                case .qrTopTextBottom:
                    VStack(alignment: .center, spacing: 2) {
                        if labelShowQr, let qrImg = generateQRCode(from: sampleDevice.id) {
                            Image(uiImage: qrImg)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 52, height: 52)
                        }
                        if labelShowDeviceId {
                            Text(sampleDevice.id)
                                .font(.system(size: CGFloat(10 * labelFontSizeScale), weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                        if labelShowDeviceName {
                            Text(sampleDevice.ten)
                                .font(.system(size: CGFloat(9 * labelFontSizeScale), weight: .medium))
                                .foregroundColor(Color.black)
                                .lineLimit(1)
                        }
                        if labelShowUnit && !sampleDevice.tenDonVi.isEmpty {
                            Text(sampleDevice.tenDonVi)
                                .font(.system(size: CGFloat(8.5 * labelFontSizeScale)))
                                .foregroundColor(Color.gray)
                                .lineLimit(1)
                        }
                        if labelShowDepartment, let pb = sampleDevice.phongBan, !pb.isEmpty {
                            Text(pb)
                                .font(.system(size: CGFloat(8.5 * labelFontSizeScale)))
                                .foregroundColor(Color.gray)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)

                case .qrLeftTextRight:
                    HStack(alignment: .center, spacing: 8) {
                        if labelShowQr, let qrImg = generateQRCode(from: sampleDevice.id) {
                            Image(uiImage: qrImg)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            if labelShowDeviceId {
                                Text(sampleDevice.id)
                                    .font(.system(size: CGFloat(10 * labelFontSizeScale), weight: .bold))
                                    .foregroundColor(Color.appPrimaryPink)
                                    .lineLimit(1)
                            }
                            if labelShowDeviceName {
                                Text(sampleDevice.ten)
                                    .font(.system(size: CGFloat(9.5 * labelFontSizeScale), weight: .medium))
                                    .foregroundColor(Color.black)
                                    .lineLimit(1)
                            }
                            if labelShowUnit && !sampleDevice.tenDonVi.isEmpty {
                                Text(sampleDevice.tenDonVi)
                                    .font(.system(size: CGFloat(8.5 * labelFontSizeScale)))
                                    .foregroundColor(Color.gray)
                                    .lineLimit(1)
                            }
                            if labelShowDepartment, let pb = sampleDevice.phongBan, !pb.isEmpty {
                                Text(pb)
                                    .font(.system(size: CGFloat(8.5 * labelFontSizeScale)))
                                    .foregroundColor(Color.gray)
                                    .lineLimit(1)
                            }
                            if labelShowStatus {
                                Text("[\(sampleDevice.trangThai)]")
                                    .font(.system(size: CGFloat(8.5 * labelFontSizeScale), weight: .semibold))
                                    .foregroundColor(Color(hex: "#002A8F"))
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(10)
            .background(Color.white) // Con tem vật lý luôn có nền trắng
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(labelShowBorder ? Color(hex: "#94A3B8") : Color.clear, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
        .padding(8)
    }

    // MARK: - CHECKBOX COMPONENT (CHUẨN ANDROID)
    private func checkboxItem(title: String, isChecked: Binding<Bool>) -> some View {
        Button(action: { isChecked.wrappedValue.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: isChecked.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(isChecked.wrappedValue ? Color.appPrimaryPink : Color.appTextMuted)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.appTextPrimary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - COMMON FILTER CARD (CHÙNG CHO CÁC PHÂN HỆ)
    private func commonFilterCard(subtitle: String) -> some View {
        CleanCardSection(title: "Bộ lọc", subtitle: subtitle) {
            VStack(spacing: 8) {
                FilterSelectorTile(
                    label: "Đơn vị / Chi nhánh áp dụng",
                    selectedValue: selectedExportDonVi,
                    icon: "storefront",
                    totalCount: selectedExportDonVi == "Tất cả đơn vị" ? (availableDonVis.count - 1) : nil,
                    onClick: { showDonViPicker = true }
                )

                FilterSelectorTile(
                    label: "Phòng ban quản lý",
                    selectedValue: selectedExportPhongBan,
                    icon: "building.2",
                    totalCount: selectedExportPhongBan == "Tất cả phòng ban" ? (availablePhongBans.count - 1) : nil,
                    onClick: { showPhongBanPicker = true }
                )

                FilterSelectorTile(
                    label: "Trạng thái thiết bị cần in",
                    selectedValue: selectedPrintFilter,
                    icon: "slider.horizontal.3",
                    totalCount: selectedPrintFilter == "Tất cả thiết bị" ? nil : filteredExportDevices.count,
                    onClick: { showStatusPicker = true }
                )
            }
        }
    }

    // MARK: - ================================================================
    // MARK: - TAB 1: IN BIÊN BẢN & BÁO CÁO (CHUẨN 1:1 ANDROID)
    // MARK: - ================================================================
    private var tab1PrintReceiptContent: some View {
        VStack(spacing: 8) {
            // CARD 1: CHỌN LOẠI BÁO CÁO CẦN IN
            CleanCardSection(
                title: "1. Chọn Loại Báo Cáo Cần In",
                subtitle: "Lựa chọn biểu mẫu Thiết bị, Chấm công, Quyết toán hoặc Đánh giá"
            ) {
                VStack(spacing: 8) {
                    Button(action: { showReportTitlePicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.plaintext.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.appPrimaryPink)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Loại báo cáo")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                Text(selectedReportTitle)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.appSurfaceVariant.opacity(0.35))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    // Ô nhập tiêu đề trực tiếp
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appPrimaryPink)
                        TextField("Tiêu đề báo cáo (Tự gõ tùy ý)...", text: $customReportTitle)
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextPrimary)
                    }
                    .padding(10)
                    .background(Color.appSurfaceVariant.opacity(0.35))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

                    // Chọn Khổ Dọc / Khổ Ngang
                    HStack(spacing: 8) {
                        ForEach(ReportPageOrientation.allCases) { orient in
                            let isSel = pageOrientation == orient
                            Button(action: { pageOrientation = orient }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                                    Text(orient.rawValue)
                                        .font(.system(size: 11.5, weight: isSel ? .bold : .medium))
                                        .foregroundColor(isSel ? Color.appPrimaryPink : Color.appTextPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isSel ? Color.appPrimaryPink.opacity(0.1) : Color.appSurfaceVariant.opacity(0.3))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                            }
                        }
                    }
                }
            }

            // BỘ LỌC
            commonFilterCard(subtitle: "Phòng ban / Đơn vị áp dụng vào biên bản")

            // THÔNG TIN BÊN GIAO / BÊN NHẬN
            CleanCardSection(title: "2. Thông Tin Biên Bản", subtitle: "Các bên ký kết và lý do thực hiện") {
                VStack(spacing: 8) {
                    TextField("Họ tên bên giao / người xuất...", text: $receiptGiverName)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color.appSurfaceVariant.opacity(0.35))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

                    TextField("Họ tên bên nhận / người nhận...", text: $receiptReceiverName)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color.appSurfaceVariant.opacity(0.35))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

                    TextField("Ghi chú / Lý do bàn giao...", text: $receiptNotes)
                        .font(.system(size: 12))
                        .padding(10)
                        .background(Color.appSurfaceVariant.opacity(0.35))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            // HÀNG NÚT IN VÀ XEM TRƯỚC
            HStack(spacing: 8) {
                Button(action: generateAndPrintReceipt) {
                    HStack(spacing: 6) {
                        Image(systemName: "printer.fill")
                        Text("In Biên Bản Ngay (A4)")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(filteredExportDevices.isEmpty ? Color.gray : Color.appPrimaryPink)
                    .cornerRadius(12)
                }
                .disabled(filteredExportDevices.isEmpty)

                Button(action: {
                    inAppPreviewHtml = buildReportHtml()
                    inAppPreviewTitle = customReportTitle.isEmpty ? selectedReportTitle : customReportTitle
                    showHtmlPreview = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("Xem Trước")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .frame(width: 120, height: 48)
                    .background(Color.appSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimaryPink, lineWidth: 1.5))
                }
                .disabled(filteredExportDevices.isEmpty)
            }

            // DANH SÁCH THIẾT BỊ ĐÍNH KÈM
            deviceSelectionSection
        }
    }

    // MARK: - ================================================================
    // MARK: - TAB 2: XUẤT FILE (EXCEL, PDF, CSV) (CHUẨN 1:1 ANDROID)
    // MARK: - ================================================================
    private var tab2ExportFileContent: some View {
        VStack(spacing: 8) {
            commonFilterCard(subtitle: "Phạm vi thiết bị xuất dữ liệu (\(filteredExportDevices.count) máy)")

            CleanCardSection(title: "Định dạng xuất dữ liệu", subtitle: "Lựa chọn định dạng tương thích") {
                VStack(spacing: 6) {
                    ForEach(["Excel (.xlsx)", "PDF Document (.pdf)", "CSV (.csv)"], id: \.self) { fmt in
                        let isSel = selectedFormat == fmt
                        Button(action: { selectedFormat = fmt }) {
                            HStack {
                                Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                                Text(fmt)
                                    .font(.system(size: 13, weight: isSel ? .bold : .regular))
                                    .foregroundColor(Color.appTextPrimary)
                                Spacer()
                            }
                            .padding(10)
                            .background(isSel ? Color.appPrimaryPink.opacity(0.08) : Color.appSurfaceVariant.opacity(0.2))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                        }
                    }
                }
            }

            CleanCardSection(title: "Tùy chọn bổ sung", subtitle: "Tùy chỉnh nội dung báo cáo & Tiêu đề") {
                VStack(spacing: 6) {
                    ForEach(["Mặc định", "Thêm Chữ Ký", "Gộp Chi Nhánh"], id: \.self) { opt in
                        let isSel = selectedExtraOption == opt
                        Button(action: { selectedExtraOption = opt }) {
                            HStack {
                                Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                                Text(opt)
                                    .font(.system(size: 13, weight: isSel ? .bold : .regular))
                                    .foregroundColor(Color.appTextPrimary)
                                Spacer()
                            }
                            .padding(10)
                            .background(isSel ? Color.appPrimaryPink.opacity(0.08) : Color.appSurfaceVariant.opacity(0.2))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: executeExportFile) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Xuất File Báo Cáo")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(filteredExportDevices.isEmpty ? Color.gray : Color.appPrimaryPink)
                    .cornerRadius(12)
                }
                .disabled(filteredExportDevices.isEmpty)

                Button(action: {
                    inAppPreviewHtml = buildReportHtml()
                    inAppPreviewTitle = "Xem Trước Báo Cáo Danh Mục Thiết Bị"
                    showHtmlPreview = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("Xem Trước")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .frame(width: 120, height: 48)
                    .background(Color.appSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimaryPink, lineWidth: 1.5))
                }
                .disabled(filteredExportDevices.isEmpty)
            }

            deviceSelectionSection
        }
    }

    // MARK: - ================================================================
    // MARK: - TAB 3: CHIA SẺ (CHUẨN 1:1 ANDROID)
    // MARK: - ================================================================
    private var tab3ShareContent: some View {
        VStack(spacing: 8) {
            commonFilterCard(subtitle: "Phạm vi thiết bị chia sẻ (\(filteredExportDevices.count) máy)")

            CleanCardSection(title: "Phương thức chia sẻ", subtitle: "Gửi tài liệu báo cáo hoặc danh sách") {
                VStack(spacing: 6) {
                    ForEach(["Ứng dụng Zalo", "Email", "AirDrop / Lưu vào Tệp (Files)"], id: \.self) { method in
                        let isSel = selectedSendMethod == method
                        Button(action: { selectedSendMethod = method }) {
                            HStack {
                                Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                                Text(method)
                                    .font(.system(size: 13, weight: isSel ? .bold : .regular))
                                    .foregroundColor(Color.appTextPrimary)
                                Spacer()
                            }
                            .padding(10)
                            .background(isSel ? Color.appPrimaryPink.opacity(0.08) : Color.appSurfaceVariant.opacity(0.2))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                        }
                    }
                }
            }

            Button(action: executeShare) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                    Text("Chia Sẻ Báo Cáo Ngay")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.appPrimaryPink)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - DANH SÁCH CHỌN THIẾT BỊ (DEVICE SELECTION SECTION)
    private var deviceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DANH SÁCH THIẾT BỊ (\(filteredExportDevices.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Spacer()

                Button(action: {
                    if selectedDevices.count == filteredExportDevices.count && !filteredExportDevices.isEmpty {
                        selectedDevices.removeAll()
                    } else {
                        selectedDevices = Set(filteredExportDevices.map { $0.id })
                    }
                }) {
                    Text(selectedDevices.count == filteredExportDevices.count && !filteredExportDevices.isEmpty ? "Bỏ chọn tất cả" : "Chọn tất cả")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                }
            }

            // Thanh tìm kiếm
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Tìm theo tên, mã thiết bị, đơn vị...", text: $searchQuery)
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextPrimary)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(9)
            .background(Color.appSurfaceVariant.opacity(0.35))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

            // Danh sách items
            VStack(spacing: 6) {
                ForEach(filteredExportDevices) { dev in
                    let isSelected = selectedDevices.contains(dev.id)
                    Button(action: {
                        if isSelected {
                            selectedDevices.remove(dev.id)
                        } else {
                            selectedDevices.insert(dev.id)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .foregroundColor(isSelected ? Color.appPrimaryPink : .gray)
                                .font(.system(size: 18))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.ten)
                                    .font(.system(size: 12.5, weight: .bold))
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
                                .background(dev.statusColor.opacity(0.12))
                                .cornerRadius(6)
                        }
                        .padding(9)
                        .background(isSelected ? Color.appPrimaryPink.opacity(0.06) : Color.appSurface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - HTML BUILDER CHUẨN BIỂU MẪU VIỆT NAM (BIÊN BẢN & BÁO CÁO)
    private func buildReportHtml() -> String {
        let titleToUse = customReportTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? selectedReportTitle
            : customReportTitle
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let targetDevs = selectedDevices.isEmpty ? filteredExportDevices : baseDevices.filter { selectedDevices.contains($0.id) }
        let effectiveUnit = selectedExportDonVi == "Tất cả đơn vị" ? displayCompanyName : selectedExportDonVi

        var rowsHtml = ""
        for (idx, dev) in targetDevs.enumerated() {
            let deptText = (dev.phongBan ?? "").isEmpty ? "-" : dev.phongBan!
            rowsHtml += """
            <tr>
              <td style='text-align: center;'>\(idx + 1)</td>
              <td style='font-weight: bold; color: #002A8F;'>\(dev.id)</td>
              <td>\(dev.ten)</td>
              <td>\(dev.tenDonVi) / \(deptText)</td>
              <td><span style='background: #EFF6FF; color: #1D4ED8; padding: 2px 6px; border-radius: 4px;'>\(dev.statusNormalized)</span></td>
            </tr>
            """
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset='utf-8'>
          <meta name='viewport' content='width=device-width, initial-scale=1.0'>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 24px; color: #0F172A; line-height: 1.5; }
            .header-table { width: 100%; border: none; margin-bottom: 24px; }
            .header-table td { border: none; vertical-align: top; }
            .national-title { text-align: center; }
            .motto { font-size: 11px; font-weight: bold; border-bottom: 1px solid #000; display: inline-block; padding-bottom: 2px; }
            h2 { text-align: center; color: #002A8F; margin-top: 10px; margin-bottom: 4px; font-size: 18px; text-transform: uppercase; }
            .sub-title { text-align: center; font-size: 12px; color: #64748B; margin-bottom: 20px; }
            .info-box { background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 12px; margin-bottom: 18px; font-size: 12px; }
            table.data-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }
            table.data-table th, table.data-table td { border: 1px solid #CBD5E1; padding: 8px; }
            table.data-table th { background: #F1F5F9; color: #0F172A; text-align: left; }
            .sign-table { width: 100%; border: none; margin-top: 40px; }
            .sign-table td { border: none; text-align: center; font-size: 12px; width: 33%; vertical-align: top; }
          </style>
        </head>
        <body>
          <table class='header-table'>
            <tr>
              <td style='width: 45%;'>
                <b>\(displayCompanyName.uppercased())</b><br>
                <span style='font-size: 11px; color: #475569;'>Đơn vị: \(effectiveUnit)</span><br>
                <span style='font-size: 11px; color: #475569;'>Số: ....../BB-ITSA</span>
              </td>
              <td class='national-title'>
                <b>CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM</b><br>
                <span class='motto'>Độc lập - Tự do - Hạnh phúc</span><br>
                <i style='font-size: 11px;'>Thời gian lập: \(dateStr)</i>
              </td>
            </tr>
          </table>

          <h2>\(titleToUse)</h2>
          <div class='sub-title'>Áp dụng: \(effectiveUnit) • Tổng số: \(targetDevs.count) thiết bị</div>

          <div class='info-box'>
            <b>Bên giao:</b> \(receiptGiverName.isEmpty ? "...................................." : receiptGiverName)<br>
            <b>Bên nhận:</b> \(receiptReceiverName.isEmpty ? "...................................." : receiptReceiverName)<br>
            <b>Ghi chú / Căn cứ:</b> \(receiptNotes.isEmpty ? "Bàn giao / kiểm kê thiết bị định kỳ theo quy định hệ thống." : receiptNotes)
          </div>

          <table class='data-table'>
            <thead>
              <tr>
                <th style='width: 35px; text-align: center;'>STT</th>
                <th style='width: 110px;'>Mã Thiết Bị</th>
                <th>Tên Thiết Bị</th>
                <th>Đơn Vị / Phòng Ban</th>
                <th style='width: 120px;'>Tình Trạng</th>
              </tr>
            </thead>
            <tbody>
              \(rowsHtml)
            </tbody>
          </table>

          <table class='sign-table'>
            <tr>
              <td>
                <b>TRƯỞNG PHÒNG / GIÁM ĐỐC</b><br>
                <i>(Ký và ghi rõ họ tên)</i><br><br><br><br>
                <b>....................................</b>
              </td>
              <td>
                <b>ĐẠI DIỆN TIẾP NHẬN</b><br>
                <i>(Ký và ghi rõ họ tên)</i><br><br><br><br>
                <b>\(receiptReceiverName)</b>
              </td>
              <td>
                <b>NGƯỜI LẬP BÁO CÁO</b><br>
                <i>(Ký và ghi rõ họ tên)</i><br><br><br><br>
                <b>\(receiptGiverName)</b>
              </td>
            </tr>
          </table>
        </body>
        </html>
        """
    }

    // MARK: - PRINT & EXPORT ACTION IMPLEMENTATION
    private func executePrint() {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "ITSA_TemNhan_\(displayCompanyName)"

        // Nhận diện & gán chiều in chuẩn cho máy in tem Citizen, Datamax, AirPrint
        switch labelOrientation {
        case .landscape, .rotate180:
            printInfo.orientation = .landscape
        case .portrait:
            printInfo.orientation = .portrait
        case .auto:
            printInfo.orientation = (labelPaperSize.itemWidthMm >= labelPaperSize.itemHeightMm) ? .landscape : .portrait
        }

        printController.printInfo = printInfo

        var images = generateImagesForSelected()
        if images.isEmpty {
            showToast("Không có tem nào để in!")
            return
        }

        // Hỗ trợ xoay 180 độ nếu chọn chế độ đảo ngược hướng cuộn Citizen / Datamax
        if labelOrientation == .rotate180 {
            images = images.map { img in
                if let cgImage = img.cgImage {
                    return UIImage(cgImage: cgImage, scale: img.scale, orientation: .down)
                }
                return img
            }
        }

        printController.printingItems = images
        printController.present(animated: true) { _, completed, error in
            if completed {
                showToast("✅ Đã hoàn tất lệnh in \(images.count) tem!")
            } else if let err = error {
                showToast("❌ Lỗi in: \(err.localizedDescription)")
            }
        }
    }

    private func exportPdfLabels() {
        let images = generateImagesForSelected()
        if images.isEmpty {
            showToast("Không có tem nào để xuất PDF!")
            return
        }

        let pdfData = NSMutableData()
        let pageSize = getLabelSizeInPoints()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: pageSize), nil)

        for img in images {
            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: img.size), nil)
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }
        UIGraphicsEndPDFContext()

        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("TemNhan_\(Int(Date().timeIntervalSince1970)).pdf")
        do {
            try pdfData.write(to: tempUrl)
            self.shareItems = [tempUrl]
            self.showShareSheet = true
        } catch {
            showToast("Lỗi xuất PDF: \(error.localizedDescription)")
        }
    }

    private func generateAndPrintReceipt() {
        let html = buildReportHtml()
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = customReportTitle.isEmpty ? selectedReportTitle : customReportTitle
        printController.printInfo = printInfo
        printController.printFormatter = formatter
        printController.present(animated: true, completionHandler: nil)
    }

    private func executeExportFile() {
        let targetDevs = selectedDevices.isEmpty ? filteredExportDevices : baseDevices.filter { selectedDevices.contains($0.id) }
        if targetDevs.isEmpty {
            showToast("Chưa có thiết bị nào để xuất!")
            return
        }

        if selectedFormat.contains("CSV") {
            var csv = "STT,Mã thiết bị,Tên thiết bị,Đơn vị,Phòng ban,Trạng thái\n"
            for (idx, dev) in targetDevs.enumerated() {
                csv += "\(idx + 1),\"\(dev.id)\",\"\(dev.ten)\",\"\(dev.tenDonVi)\",\"\(dev.phongBan ?? "")\",\"\(dev.statusNormalized)\"\n"
            }
            let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("DanhSachTB_\(Int(Date().timeIntervalSince1970)).csv")
            do {
                try csv.write(to: tempUrl, atomically: true, encoding: .utf8)
                self.shareItems = [tempUrl]
                self.showShareSheet = true
            } catch {
                showToast("Lỗi xuất CSV: \(error.localizedDescription)")
            }
        } else {
            // PDF Báo cáo
            let html = buildReportHtml()
            let printFormatter = UIMarkupTextPrintFormatter(markupText: html)
            let renderer = UIPrintPageRenderer()
            renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

            let isLandscape = pageOrientation == .landscape
            let pageRect = isLandscape
                ? CGRect(x: 0, y: 0, width: 841.8, height: 595.2) // A4 Landscape
                : CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 Portrait
            let printableRect = pageRect.insetBy(dx: 20, dy: 20)

            renderer.setValue(pageRect, forKey: "paperRect")
            renderer.setValue(printableRect, forKey: "printableRect")

            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
            for i in 0..<renderer.numberOfPages {
                UIGraphicsBeginPDFPage()
                renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
            }
            UIGraphicsEndPDFContext()

            let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("BaoCao_\(Int(Date().timeIntervalSince1970)).pdf")
            do {
                try pdfData.write(to: tempUrl)
                self.shareItems = [tempUrl]
                self.showShareSheet = true
            } catch {
                showToast("Lỗi xuất PDF: \(error.localizedDescription)")
            }
        }
    }

    private func executeShare() {
        let targetDevs = selectedDevices.isEmpty ? filteredExportDevices : baseDevices.filter { selectedDevices.contains($0.id) }
        if targetDevs.isEmpty {
            showToast("Không có thiết bị để chia sẻ!")
            return
        }

        var shareText = "📋 DANH SÁCH THIẾT BỊ (\(displayCompanyName))\n"
        shareText += "Thời gian: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))\n"
        shareText += "Số lượng: \(targetDevs.count) thiết bị\n"
        shareText += "-------------------------------\n"
        for (i, dev) in targetDevs.prefix(30).enumerated() {
            shareText += "\(i + 1). [\(dev.id)] \(dev.ten) - \(dev.tenDonVi)\n"
        }
        if targetDevs.count > 30 {
            shareText += "... và \(targetDevs.count - 30) thiết bị khác."
        }

        self.shareItems = [shareText]
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

    // MARK: - LABEL SIZES & DRAWING ENGINE
    private func getLabelSizeInPoints() -> CGSize {
        let widthPt = labelPaperSize.itemWidthMm * 72.0 / 25.4
        let heightPt = labelPaperSize.itemHeightMm * 72.0 / 25.4
        return CGSize(width: widthPt, height: heightPt)
    }

    private func generateImagesForSelected() -> [UIImage] {
        let size = getLabelSizeInPoints()
        var images = [UIImage]()
        let targetDevs = selectedDevices.isEmpty ? filteredExportDevices : baseDevices.filter { selectedDevices.contains($0.id) }

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
            // White label background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            if labelShowBorder {
                UIColor.black.setStroke()
                let strokeRect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
                context.stroke(strokeRect)
            }

            let margin: CGFloat = 4
            var currentY: CGFloat = margin

            // Company Title on top
            if labelShowCompanyName && !displayCompanyName.isEmpty && labelLayoutMode != .qrOnlyWithCode {
                let titleFont = UIFont.boldSystemFont(ofSize: CGFloat(9 * labelFontSizeScale))
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: UIColor(red: 0, green: 42/255, blue: 143/255, alpha: 1)
                ]
                let titleRect = CGRect(x: margin, y: currentY, width: size.width - margin * 2, height: 12)
                displayCompanyName.uppercased().draw(in: titleRect, withAttributes: titleAttrs)
                currentY += 12

                // Divider line
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: currentY))
                linePath.addLine(to: CGPoint(x: size.width - margin, y: currentY))
                UIColor(red: 203/255, green: 213/255, blue: 225/255, alpha: 1).setStroke()
                linePath.lineWidth = 0.5
                linePath.stroke()
                currentY += 2
            }

            let remainingHeight = size.height - currentY - margin

            switch labelLayoutMode {
            case .qrOnlyWithCode:
                let codeSize = min(size.height - 22, size.width - margin * 2)
                if labelShowQr, let qr = generateQRCode(from: dev.id) {
                    let qrX = (size.width - codeSize) / 2
                    qr.draw(in: CGRect(x: qrX, y: currentY, width: codeSize, height: codeSize))
                }
                if labelShowDeviceId {
                    let codeFont = UIFont.boldSystemFont(ofSize: CGFloat(10 * labelFontSizeScale))
                    let codeAttrs: [NSAttributedString.Key: Any] = [
                        .font: codeFont,
                        .foregroundColor: UIColor(red: 244/255, green: 2/255, blue: 102/255, alpha: 1)
                    ]
                    let codeRect = CGRect(x: margin, y: size.height - 14, width: size.width - margin * 2, height: 12)
                    let pStyle = NSMutableParagraphStyle()
                    pStyle.alignment = .center
                    var attrs = codeAttrs
                    attrs[.paragraphStyle] = pStyle
                    dev.id.draw(in: codeRect, withAttributes: attrs)
                }

            case .qrTopTextBottom:
                let qrSize = min(remainingHeight * 0.55, size.width - margin * 2)
                if labelShowQr, let qr = generateQRCode(from: dev.id) {
                    let qrX = (size.width - qrSize) / 2
                    qr.draw(in: CGRect(x: qrX, y: currentY, width: qrSize, height: qrSize))
                    currentY += qrSize + 2
                }

                let textWidth = size.width - margin * 2
                let pCenter = NSMutableParagraphStyle()
                pCenter.alignment = .center

                if labelShowDeviceId {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: CGFloat(8.5 * labelFontSizeScale)),
                        .foregroundColor: UIColor(red: 244/255, green: 2/255, blue: 102/255, alpha: 1),
                        .paragraphStyle: pCenter
                    ]
                    dev.id.draw(in: CGRect(x: margin, y: currentY, width: textWidth, height: 10), withAttributes: attrs)
                    currentY += 10
                }

                if labelShowDeviceName {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: CGFloat(8 * labelFontSizeScale)),
                        .foregroundColor: UIColor.black,
                        .paragraphStyle: pCenter
                    ]
                    dev.ten.draw(in: CGRect(x: margin, y: currentY, width: textWidth, height: 10), withAttributes: attrs)
                }

            case .qrLeftTextRight:
                let qrSize = min(remainingHeight, size.width * 0.4)
                if labelShowQr, let qr = generateQRCode(from: dev.id) {
                    qr.draw(in: CGRect(x: margin, y: currentY + (remainingHeight - qrSize) / 2, width: qrSize, height: qrSize))
                }

                let textX = margin + qrSize + 4
                let textWidth = size.width - textX - margin
                var textY = currentY

                if labelShowDeviceId {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: CGFloat(9 * labelFontSizeScale)),
                        .foregroundColor: UIColor(red: 244/255, green: 2/255, blue: 102/255, alpha: 1)
                    ]
                    dev.id.draw(in: CGRect(x: textX, y: textY, width: textWidth, height: 11), withAttributes: attrs)
                    textY += 11
                }

                if labelShowDeviceName {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: CGFloat(8 * labelFontSizeScale)),
                        .foregroundColor: UIColor.black
                    ]
                    dev.ten.draw(in: CGRect(x: textX, y: textY, width: textWidth, height: 18), withAttributes: attrs)
                    textY += 18
                }

                if labelShowUnit && !dev.tenDonVi.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: CGFloat(7 * labelFontSizeScale)),
                        .foregroundColor: UIColor.darkGray
                    ]
                    dev.tenDonVi.draw(in: CGRect(x: textX, y: textY, width: textWidth, height: 9), withAttributes: attrs)
                    textY += 9
                }

                if labelShowDepartment, let pb = dev.phongBan, !pb.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: CGFloat(7 * labelFontSizeScale)),
                        .foregroundColor: UIColor.darkGray
                    ]
                    pb.draw(in: CGRect(x: textX, y: textY, width: textWidth, height: 9), withAttributes: attrs)
                    textY += 9
                }

                if labelShowStatus {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: CGFloat(7 * labelFontSizeScale)),
                        .foregroundColor: UIColor(red: 0, green: 42/255, blue: 143/255, alpha: 1)
                    ]
                    "[\(dev.statusNormalized)]".draw(in: CGRect(x: textX, y: textY, width: textWidth, height: 9), withAttributes: attrs)
                }
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
}

// MARK: - ====================================================================
// MARK: - REUSABLE SUBVIEWS & COMPONENTS
// MARK: - ====================================================================

// MARK: - CleanCardSection (CHUẨN 1:1 ANDROID: CONTAINER SURFACE, BORDER, TITLE, SUBTITLE, DIVIDER)
public struct CleanCardSection<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    public init(title: String, subtitle: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.appTextMuted)
                }
            }

            Divider()
                .background(Color.appDivider.opacity(0.3))
                .padding(.vertical, 2)

            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - FilterSelectorTile (CHUẨN 1:1 ANDROID: PINK ICON BOX, SUBTITLE, VALUE, CHEVRONS)
public struct FilterSelectorTile: View {
    let label: String
    let selectedValue: String
    let icon: String
    var totalCount: Int? = nil
    let onClick: () -> Void

    public var body: some View {
        Button(action: onClick) {
            HStack(spacing: 10) {
                // Pink icon box
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appPrimaryPink.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(Color.appPrimaryPink)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Color.appTextMuted)
                    Text(selectedValue)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .lineLimit(1)
                }

                Spacer()

                if let count = totalCount, count > 0 {
                    Text("\(count) đơn vị")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.appSecondaryDarkBlue.opacity(0.1))
                        .cornerRadius(10)
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.appTextMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.appSurfaceVariant.opacity(0.35))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - SearchablePickerSheet (MODAL CHỌN ĐƠN VỊ, PHÒNG BAN, TRẠNG THÁI)
struct SearchablePickerSheet: View {
    let title: String
    let items: [String]
    let selectedItem: String
    let icon: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filteredItems: [String] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }
        return items.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Tìm kiếm...", text: $query)
                        .font(.system(size: 13))
                    if !query.isEmpty {
                        Button(action: { query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color.appSurfaceVariant.opacity(0.35))
                .cornerRadius(10)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                List {
                    ForEach(filteredItems, id: \.self) { item in
                        let isSel = item == selectedItem
                        Button(action: {
                            onSelect(item)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(isSel ? Color.appPrimaryPink : Color.appTextMuted)
                                Text(item)
                                    .font(.system(size: 13, weight: isSel ? .bold : .medium))
                                    .foregroundColor(isSel ? Color.appPrimaryPink : Color.appTextPrimary)
                                Spacer()
                                if isSel {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appPrimaryPink)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

// MARK: - PaperSizePickerSheet (MODAL CHỌN KHỔ TEM CHUYÊN DỤNG VÀ A4 TOMY)
struct PaperSizePickerSheet: View {
    let selectedSize: LabelPaperSize
    let onSelect: (LabelPaperSize) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("--- CUỘN TEM DECAL NHIỆT (MÁY IN CHUYÊN DỤNG) ---").font(.caption).bold().foregroundColor(Color.appPrimaryPink)) {
                    ForEach(LabelPaperSize.allCases.filter { $0.isRoll }) { size in
                        let isSel = size == selectedSize
                        Button(action: {
                            onSelect(size)
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(size.label)
                                        .font(.system(size: 13, weight: isSel ? .bold : .semibold))
                                        .foregroundColor(isSel ? Color.appPrimaryPink : Color.appTextPrimary)
                                    Text(size.description)
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if isSel {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appPrimaryPink)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section(header: Text("--- GIẤY DECAL TỜ A4 (MÁY IN VĂN PHÒNG TOMY) ---").font(.caption).bold().foregroundColor(Color.appSecondaryDarkBlue)) {
                    ForEach(LabelPaperSize.allCases.filter { !$0.isRoll }) { size in
                        let isSel = size == selectedSize
                        Button(action: {
                            onSelect(size)
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(size.label)
                                        .font(.system(size: 13, weight: isSel ? .bold : .semibold))
                                        .foregroundColor(isSel ? Color.appPrimaryPink : Color.appTextPrimary)
                                    Text(size.description)
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if isSel {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appPrimaryPink)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Chọn Khổ Tem In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

// MARK: - ReportTemplatePickerSheet (MODAL CHỌN BIỂU MẪU BÁO CÁO)
struct ReportTemplatePickerSheet: View {
    let selectedTemplate: String
    let onSelect: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let deviceTemplates = [
        ("Biên bản Bàn giao Thiết bị", "BIÊN BẢN BÀN GIAO THIẾT BỊ"),
        ("Biên bản Kiểm kê Tài sản & Thiết bị", "BIÊN BẢN KIỂM KÊ TÀI SẢN & THIẾT BỊ"),
        ("Báo cáo Tổng hợp Thiết bị theo Đơn vị", "BÁO CÁO TỔNG HỢP THIẾT BỊ THEO ĐƠN VỊ"),
        ("Báo cáo Thiết bị Hỏng / Cần Thanh lý", "BÁO CÁO THIẾT BỊ HỎNG / CẦN THANH LÝ")
    ]

    private let attendanceTemplates = [
        ("Báo cáo Chấm công (Tổng hợp)", "BÁO CÁO CHẤM CÔNG KỸ THUẬT (TỔNG HỢP)"),
        ("Báo cáo Chấm công (Hàng tháng)", "BÁO CÁO CHẤM CÔNG KỸ THUẬT HÀNG THÁNG"),
        ("Theo dõi Đi muộn & Giờ làm việc", "BÁO CÁO THEO DÕI ĐI MUỘN & GIỜ LÀM VIỆC")
    ]

    private let expenseTemplates = [
        ("Quyết toán Công tác phí (Di chuyển)", "BẢNG QUYẾT TOÁN CÔNG TÁC PHÍ DI CHUYỂN"),
        ("Bảng kê Công tác phí", "BẢNG KÊ CHI TIẾT CÔNG TÁC PHÍ"),
        ("Giấy đề nghị Thanh toán Công tác phí", "GIẤY ĐỀ NGHỊ THANH TOÁN CÔNG TÁC PHÍ"),
        ("Tổng hợp Xăng xe & Phụ cấp ca KTV", "BÁO CÁO TỔNG HỢP XĂNG XE & PHỤ CẤP CA KTV")
    ]

    private let supportTemplates = [
        ("Báo cáo Đánh giá Chất lượng Hỗ trợ", "BÁO CÁO ĐÁNH GIÁ CHẤT LƯỢNG HỖ TRỢ KỸ THUẬT")
    ]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("── 1. BIÊN BẢN & BÁO CÁO THIẾT BỊ ──").font(.caption).bold().foregroundColor(Color.appPrimaryPink)) {
                    ForEach(deviceTemplates, id: \.0) { item in
                        templateRow(item)
                    }
                }

                Section(header: Text("── 2. BÁO CÁO CHẤM CÔNG KỸ THUẬT ──").font(.caption).bold().foregroundColor(Color(hex: "#16A34A"))) {
                    ForEach(attendanceTemplates, id: \.0) { item in
                        templateRow(item)
                    }
                }

                Section(header: Text("── 3. BÁO CÁO QUYẾT TOÁN CÔNG TÁC PHÍ ──").font(.caption).bold().foregroundColor(Color(hex: "#2563EB"))) {
                    ForEach(expenseTemplates, id: \.0) { item in
                        templateRow(item)
                    }
                }

                Section(header: Text("── 4. BÁO CÁO ĐÁNH GIÁ CHẤT LƯỢNG HỖ TRỢ ──").font(.caption).bold().foregroundColor(Color(hex: "#D97706"))) {
                    ForEach(supportTemplates, id: \.0) { item in
                        templateRow(item)
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Chọn Mẫu Báo Cáo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }

    private func templateRow(_ item: (String, String)) -> some View {
        let isSel = item.0 == selectedTemplate
        return Button(action: {
            onSelect(item.0, item.1)
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.system(size: 13, weight: isSel ? .bold : .semibold))
                        .foregroundColor(isSel ? Color.appPrimaryPink : Color.appTextPrimary)
                    Text(item.1)
                        .font(.system(size: 10.5))
                        .foregroundColor(.gray)
                }
                Spacer()
                if isSel {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - CoachMarksGuideSheet (CẨM NANG HƯỚNG DẪN 5 BƯỚC IN ẤN TƯƠNG ĐỒNG ANDROID)
struct CoachMarksGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String, String)] = [
        ("4 Phân Hệ In & Xuất Báo Cáo 📑", "Chuyển đổi giữa: In tem QR máy in cuộn/A4, In biên bản phiếu thu/xuất, Xuất file Excel/PDF và Chia sẻ tài liệu.", "doc.badge.gearshape.fill"),
        ("Bộ Lọc Thiết Bị In Tem 🔍", "Lọc nhanh danh sách thiết bị cần in theo Đơn vị, Phòng ban trực thuộc hoặc Trạng thái (Sử dụng, Hỏng, Bảo hành).", "line.3.horizontal.decrease.circle.fill"),
        ("Chọn Khổ Tem Chuẩn Đa Năng 🏷️", "Hỗ trợ khổ tem cuộn nhiệt (Datamax, Zebra, Xprinter...) và khổ decal giấy tờ A4 Tomy văn phòng phổ biến.", "tag.fill"),
        ("Xem Trước & Ra Lệnh In 🖨️", "Bấm In tem ngay qua AirPrint / PrintManager hoặc Xem trước hình ảnh tem nhãn trước khi in hàng loạt.", "printer.fill"),
        ("Xem Lại Hướng Dẫn 💡", "Nhấn biểu tượng bóng đèn trên thanh tiêu đề để mở lại cẩm nang hướng dẫn in ấn bất cứ lúc nào.", "lightbulb.fill")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("CẨM NANG HƯỚNG DẪN IN ẤN & XUẤT BÁO CÁO")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .padding(.bottom, 4)

                    ForEach(0..<steps.count, id: \.self) { i in
                        let step = steps[i]
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.appPrimaryPink.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: step.2)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.appPrimaryPink)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(i + 1). \(step.0)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                                Text(step.1)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(10)
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    Button(action: { dismiss() }) {
                        Text("Đã Hiểu / Đóng Hướng Dẫn")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)
                }
                .padding(16)
            }
            .navigationTitle("Hướng Dẫn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

// MARK: - InAppReportPreviewSheet (XEM TRƯỚC BÁO CÁO HTML BẰNG WKWEBVIEW)
struct InAppReportPreviewSheet: View {
    let title: String
    let htmlContent: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ReportHtmlWebView(html: htmlContent)
                .edgesIgnoringSafeArea(.bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { dismiss() }
                            .foregroundColor(Color.appPrimaryPink)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            let printController = UIPrintInteractionController.shared
                            let printInfo = UIPrintInfo(dictionary: nil)
                            printInfo.outputType = .general
                            printInfo.jobName = title
                            printController.printInfo = printInfo
                            printController.printFormatter = UIMarkupTextPrintFormatter(markupText: htmlContent)
                            printController.present(animated: true, completionHandler: nil)
                        }) {
                            Image(systemName: "printer.fill")
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                }
        }
    }
}

fileprivate struct ReportHtmlWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
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
