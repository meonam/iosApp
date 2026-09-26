import SwiftUI

// MARK: - SystemToggleConfig
struct SystemToggleConfig {
    // 1. GPS & Chấm Công
    var strictGeofenceBlocking: Bool = false
    var autoCaptureGpsOnOpen: Bool = true
    var allowWeekendOvertimeCheckIn: Bool = false
    var alertLateCheckIn: Bool = true
    // 2. In Ấn & Báo Cáo
    var rememberSignerNames: Bool = true
    var showHeaderLogoOnReport: Bool = true
    var showSignatureBlockOnReport: Bool = true
    var autoFitA4Page: Bool = true
    var includeQrCodeOnDevicePrint: Bool = true
    // 3. Thông Báo
    var notifyNewSupportTicket: Bool = true
    var enableNotificationSound: Bool = true
    var voiceNotificationMode: String = "REPEAT"
    // 4. An Toàn & Trải Nghiệm
    var confirmBeforeDelete: Bool = true
    var compactDeviceListView: Bool = false
    // 5. Quy Trình Hỗ Trợ
    var preventDuplicateAssetTicket: Bool = true
    var allowTicketReopen: Bool = true
    var enableAfterHoursAutoDispatch: Bool = false
    var notifyDispatchEmailTech: Bool = true
    var notifyDispatchEmailSpecialist: Bool = true
    var ticketCooldownMinutes: Int = 1
    // 6. Phân Ca KTV
    var allowManagerShiftEditing: Bool = false
    // 7. Phân Quyền Helpdesk
    var allowHelpdeskUserManagement: Bool = false
    // 8. Tệp Đính Kèm
    var allowAttachments: Bool = true
    var maxAttachmentSizeMb: Int = 5
    var enableOnlineVirusScan: Bool = false
    // 9. Tự Động Dọn Dẹp
    var autoDeleteTickets: Bool = false
    var autoDeleteTicketMonths: Int = 3
    // Email - autoSendRatingEmailOnClose
    var autoSendRatingEmailOnClose: Bool = true
    // Metadata
    var updatedAt: Double = 0
    var updatedBy: String = ""
}

// MARK: - SystemSettingsFullView
struct SystemSettingsFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    let onDismiss: () -> Void

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var config = SystemToggleConfig()
    @State private var customMonthsInput: String = "3"
    @State private var isCleaningNow = false
    @State private var cleanMsg: String? = nil
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil

    private var isAdmin: Bool {
        firebase.isAdmin || firebase.isSuperAdmin
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Đang tải cấu hình hệ thống...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            // Admin lock banner
                            if !isAdmin {
                                HStack(spacing: 10) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(Color(hex: "B45309"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Chỉ xem — Bạn không có quyền Admin")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: "B45309"))
                                        Text("Liên hệ Quản trị viên hệ thống để thay đổi cấu hình.")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: "92400E"))
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(hex: "FFFBEB"))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "FDE68A"), lineWidth: 1))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }

                            // Group 1: GPS & Chấm Công
                            SettingGroupCard(
                                title: "Quản Trị Chấm Công & Định Vị GPS",
                                icon: "location.fill",
                                iconColor: Color(hex: "9333EA"),
                                iconBg: Color(hex: "F5F3FF")
                            ) {
                                ToggleSettingItem(
                                    title: "Khoá chặt GPS (Strict Geofence)",
                                    subtitle: "Khi BẬT: Chặn chấm công nếu nhân viên nằm ngoài vùng bán kính GPS cho phép. Khi TẮT: Cảnh báo nhưng không chặn.",
                                    icon: "lock.fill",
                                    isOn: $config.strictGeofenceBlocking,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Tự động chụp GPS khi mở app",
                                    subtitle: "Cập nhật toạ độ GPS ngay khi nhân viên mở ứng dụng để tăng độ chính xác định vị.",
                                    icon: "location.circle.fill",
                                    isOn: $config.autoCaptureGpsOnOpen,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Cho phép tăng ca Thứ 7 / Chủ nhật",
                                    subtitle: "Khi BẬT: Nhân viên được phép chấm công tăng ca vào cuối tuần ngoài lịch trực chính thức.",
                                    icon: "calendar.badge.plus",
                                    isOn: $config.allowWeekendOvertimeCheckIn,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Cảnh báo đi trễ khi chấm công",
                                    subtitle: "Hiển thị cảnh báo nếu nhân viên chấm công sau giờ vào làm quy định của ca.",
                                    icon: "exclamationmark.triangle.fill",
                                    isOn: $config.alertLateCheckIn,
                                    isAdmin: isAdmin
                                )
                            }

                            // Group 2: In Ấn & Báo Cáo
                            SettingGroupCard(
                                title: "In Ấn & Báo Cáo Biểu Mẫu",
                                icon: "printer.fill",
                                iconColor: Color(hex: "0284C7"),
                                iconBg: Color(hex: "E0F2FE")
                            ) {
                                ToggleSettingItem(
                                    title: "Ghi nhớ tên người ký vào biểu mẫu",
                                    subtitle: "Tự động điền tên người lập và trưởng bộ phận vào cuối các biểu mẫu in.",
                                    icon: "person.text.rectangle.fill",
                                    isOn: $config.rememberSignerNames,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Hiển thị logo công ty trên báo cáo",
                                    subtitle: "In logo đơn vị lên phần đầu trang các biểu mẫu xuất từ ứng dụng.",
                                    icon: "building.2.fill",
                                    isOn: $config.showHeaderLogoOnReport,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Hiển thị khối chữ ký cuối báo cáo",
                                    subtitle: "In dòng ký tên/đóng dấu phù hợp quy trình nghiệm thu nội bộ.",
                                    icon: "signature",
                                    isOn: $config.showSignatureBlockOnReport,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Tự động căn lề khổ A4",
                                    subtitle: "Co giãn nội dung vừa trang A4 khi xuất báo cáo PDF để in chuẩn.",
                                    icon: "doc.richtext.fill",
                                    isOn: $config.autoFitA4Page,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "In mã QR lên phiếu kiểm kê thiết bị",
                                    subtitle: "Tự động tạo mã QR chứa ID thiết bị trên phiếu in để tra cứu nhanh.",
                                    icon: "qrcode",
                                    isOn: $config.includeQrCodeOnDevicePrint,
                                    isAdmin: isAdmin
                                )
                            }

                            // Group 3: Thông Báo
                            SettingGroupCard(
                                title: "Thông Báo & Cảnh Báo Hệ Thống",
                                icon: "bell.badge.fill",
                                iconColor: Color(hex: "D97706"),
                                iconBg: Color(hex: "FFFBEB")
                            ) {
                                ToggleSettingItem(
                                    title: "Thông báo khi có Ticket hỗ trợ mới",
                                    subtitle: "Push notification ngay khi có phiếu sự cố mới gửi đến hệ thống.",
                                    icon: "bell.fill",
                                    isOn: $config.notifyNewSupportTicket,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Âm thanh thông báo",
                                    subtitle: "Phát âm thanh kèm theo push notification khi có sự kiện mới.",
                                    icon: "speaker.wave.3.fill",
                                    isOn: $config.enableNotificationSound,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)

                                // Voice mode radio
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color(hex: "FEF3C7")).frame(width: 32, height: 32)
                                            Image(systemName: "waveform").foregroundColor(Color(hex: "D97706")).font(.system(size: 14))
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Chế độ thông báo giọng nói")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color(hex: "1E293B"))
                                            Text("Lặp lại, một lần, hoặc tắt hoàn toàn thông báo giọng nói khi có Ticket mới.")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        ForEach([("REPEAT","Lặp lại"), ("ONCE","Một lần"), ("OFF","Tắt")], id: \.0) { mode, label in
                                            let selected = config.voiceNotificationMode == mode
                                            Button(action: { if isAdmin { config.voiceNotificationMode = mode } }) {
                                                Text(label)
                                                    .font(.system(size: 12, weight: selected ? .bold : .regular))
                                                    .foregroundColor(selected ? .white : Color(hex: "1E293B"))
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 34)
                                                    .background(selected ? Color(hex: "D97706") : Color.white)
                                                    .cornerRadius(8)
                                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color(hex: "D97706") : Color(hex: "CBD5E1"), lineWidth: 1))
                                            }
                                            .disabled(!isAdmin)
                                        }
                                    }
                                }
                            }

                            // Group 4: An Toàn & Trải Nghiệm
                            SettingGroupCard(
                                title: "An Toàn & Trải Nghiệm Ứng Dụng",
                                icon: "shield.lefthalf.filled",
                                iconColor: Color(hex: "16A34A"),
                                iconBg: Color(hex: "F0FDF4")
                            ) {
                                ToggleSettingItem(
                                    title: "Xác nhận trước khi xoá dữ liệu",
                                    subtitle: "Hiển thị hộp thoại xác nhận trước khi xoá thiết bị, ticket hoặc dữ liệu nhạy cảm.",
                                    icon: "trash.fill",
                                    isOn: $config.confirmBeforeDelete,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Hiển thị danh sách thiết bị dạng compact",
                                    subtitle: "Thu nhỏ card thiết bị để hiển thị nhiều hơn trên một màn hình.",
                                    icon: "list.bullet.rectangle.fill",
                                    isOn: $config.compactDeviceListView,
                                    isAdmin: isAdmin
                                )
                            }

                            // Group 5: Quy Trình Hỗ Trợ
                            SettingGroupCard(
                                title: "Quy Trình Hỗ Trợ & Xử Lý Sự Cố",
                                icon: "headphones",
                                iconColor: Color(hex: "DC2626"),
                                iconBg: Color(hex: "FEF2F2")
                            ) {
                                ToggleSettingItem(
                                    title: "Chặn tạo ticket trùng thiết bị",
                                    subtitle: "Ngăn người dùng tạo nhiều phiếu hỗ trợ cho cùng một thiết bị khi đã có phiếu đang xử lý.",
                                    icon: "exclamationmark.octagon.fill",
                                    isOn: $config.preventDuplicateAssetTicket,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Cho phép mở lại ticket đã đóng",
                                    subtitle: "Người dùng hoặc Admin có thể đổi trạng thái CLOSED → OPEN khi sự cố tái phát.",
                                    icon: "arrow.counterclockwise.circle.fill",
                                    isOn: $config.allowTicketReopen,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Tự động điều phối ngoài giờ hành chính",
                                    subtitle: "Tự động chuyển ticket cho KTV trực khi nhận phiếu ngoài giờ hành chính.",
                                    icon: "clock.badge.fill",
                                    isOn: $config.enableAfterHoursAutoDispatch,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Email thông báo điều phối cho KTV",
                                    subtitle: "Gửi email thông báo tự động cho Kỹ thuật viên được phân công xử lý sự cố.",
                                    icon: "envelope.badge.fill",
                                    isOn: $config.notifyDispatchEmailTech,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Email thông báo cho Chuyên viên hỗ trợ",
                                    subtitle: "Gửi email cảnh báo cho Chuyên viên hỗ trợ khi có ticket ưu tiên cao hoặc SLA sắp vi phạm.",
                                    icon: "envelope.fill",
                                    isOn: $config.notifyDispatchEmailSpecialist,
                                    isAdmin: isAdmin
                                )
                                Divider().padding(.horizontal, -16)

                                // Cooldown picker
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color(hex: "FEE2E2")).frame(width: 32, height: 32)
                                            Image(systemName: "timer").foregroundColor(Color(hex: "DC2626")).font(.system(size: 14))
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Thời gian chờ giữa 2 lần tạo ticket (cooldown)")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color(hex: "1E293B"))
                                            Text("Thời gian tài khoản phải chờ trước khi tạo tiếp phiếu hỗ trợ mới để chống spam hoặc gửi lặp.")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        ForEach([(0,"Tắt (0s"),(1,"1 phút"),(2,"2 phút"),(5,"5 phút")], id: \.0) { mins, label in
                                            let selected = config.ticketCooldownMinutes == mins
                                            Button(action: { if isAdmin { config.ticketCooldownMinutes = mins } }) {
                                                Text(label)
                                                    .font(.system(size: 10.5, weight: selected ? .bold : .regular))
                                                    .foregroundColor(selected ? .white : Color(hex: "1E293B"))
                                                    .lineLimit(1)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 34)
                                                    .background(selected ? Color(hex: "EC4899") : Color.white)
                                                    .cornerRadius(8)
                                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color(hex: "EC4899") : Color(hex: "CBD5E1"), lineWidth: 1))
                                            }
                                            .disabled(!isAdmin)
                                        }
                                    }
                                }
                            }

                            // Group 6: Phân Ca KTV
                            SettingGroupCard(
                                title: "Phân Ca & Lịch Trực Kỹ Thuật Viên (KTV)",
                                icon: "calendar",
                                iconColor: Color(hex: "0284C7"),
                                iconBg: Color(hex: "E0F2FE")
                            ) {
                                ToggleSettingItem(
                                    title: "Cho phép Quản lý / Trưởng nhóm sửa phân ca",
                                    subtitle: "Khi BẬT: Trưởng nhóm và Quản lý phòng ban được phép sửa, phân ca và lưu lịch trực KTV. Khi TẮT: Chỉ Admin mới có quyền sửa và lưu phân ca (mặc định an toàn).",
                                    icon: "calendar.badge.gearshape",
                                    isOn: $config.allowManagerShiftEditing,
                                    isAdmin: isAdmin
                                )
                            }

                            // Group 7: Phân Quyền Helpdesk
                            SettingGroupCard(
                                title: "Phân Quyền Vận Hành Bộ Phận Helpdesk",
                                icon: "person.badge.key.fill",
                                iconColor: Color(hex: "0D9488"),
                                iconBg: Color(hex: "CCFBF1")
                            ) {
                                ToggleSettingItem(
                                    title: "Cho phép Helpdesk toàn quyền Quản trị Nhân sự",
                                    subtitle: "Khi BẬT: Helpdesk được quyền tạo tài khoản, phê duyệt nhân sự mới, phân quyền phòng ban, đặt lại mật khẩu và xoá tài khoản nhân viên. Khi TẮT: Helpdesk chỉ có quyền xem danh sách nhân sự.",
                                    icon: "person.2.badge.gearshape.fill",
                                    isOn: $config.allowHelpdeskUserManagement,
                                    isAdmin: isAdmin
                                )
                            }

                            // Group 8: Tệp Đính Kèm
                            SettingGroupCard(
                                title: "Quản Lý Tệp Đính Kèm & An Toàn Tập Tin",
                                icon: "paperclip",
                                iconColor: Color(hex: "7C3AED"),
                                iconBg: Color(hex: "F5F3FF")
                            ) {
                                ToggleSettingItem(
                                    title: "Cho phép gửi tệp đính kèm trong Ticket",
                                    subtitle: "Cho phép đính kèm tài liệu (.pdf, .doc, .xls), ảnh sự cố (tối đa 5 tệp / tin nhắn). Cấm video và file thực thi (.exe).",
                                    icon: "doc.fill",
                                    isOn: $config.allowAttachments,
                                    isAdmin: isAdmin
                                )
                                if config.allowAttachments {
                                    Divider().padding(.horizontal, -16)
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle().fill(Color(hex: "EDE9FE")).frame(width: 32, height: 32)
                                                Image(systemName: "icloud.and.arrow.up.fill").foregroundColor(Color(hex: "7C3AED")).font(.system(size: 14))
                                            }
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Dung lượng tối đa cho mỗi tệp")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(Color(hex: "1E293B"))
                                                Text("Giới hạn dung lượng an toàn để chống nghẽn đường truyền và tối ưu bộ nhớ lưu trữ.")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            ForEach([(2,"2 MB"),(5,"5 MB"),(10,"10 MB"),(20,"20 MB")], id: \.0) { mb, label in
                                                let selected = config.maxAttachmentSizeMb == mb
                                                Button(action: { if isAdmin { config.maxAttachmentSizeMb = mb } }) {
                                                    Text(label)
                                                        .font(.system(size: 10.5, weight: selected ? .bold : .regular))
                                                        .foregroundColor(selected ? .white : Color(hex: "1E293B"))
                                                        .frame(maxWidth: .infinity)
                                                        .frame(height: 34)
                                                        .background(selected ? Color(hex: "7C3AED") : Color.white)
                                                        .cornerRadius(8)
                                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color(hex: "7C3AED") : Color(hex: "CBD5E1"), lineWidth: 1))
                                                }
                                                .disabled(!isAdmin)
                                            }
                                        }
                                    }
                                    Divider().padding(.horizontal, -16)
                                    ToggleSettingItem(
                                        title: "Quét Virus Online (Google VirusTotal API)",
                                        subtitle: "Tự động tra cứu mã băm SHA-256 qua 70+ bộ máy diệt virus danh tiếng toàn cầu trước khi cho phép tải về.",
                                        icon: "shield.checkered",
                                        isOn: $config.enableOnlineVirusScan,
                                        isAdmin: isAdmin
                                    )
                                }
                            }

                            // Group 9: Tự Động Dọn Dẹp
                            SettingGroupCard(
                                title: "Tự Động Dọn Dẹp & Xoá Ticket Quá Hạn",
                                icon: "trash.fill",
                                iconColor: Color(hex: "DC2626"),
                                iconBg: Color(hex: "FEF2F2")
                            ) {
                                ToggleSettingItem(
                                    title: "Tự động xoá ticket đã đóng (CLOSED)",
                                    subtitle: "Tự động xoá vĩnh viễn các phiếu hỗ trợ đã đóng quá thời hạn quy định để tối ưu dung lượng cơ sở dữ liệu. Mặc định: TẮT.",
                                    icon: "clock.badge.xmark.fill",
                                    isOn: $config.autoDeleteTickets,
                                    isAdmin: isAdmin
                                )
                                if config.autoDeleteTickets {
                                    Divider().padding(.horizontal, -16)
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle().fill(Color(hex: "FEE2E2")).frame(width: 32, height: 32)
                                                Image(systemName: "hourglass").foregroundColor(Color(hex: "DC2626")).font(.system(size: 14))
                                            }
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Khung thời gian lưu trữ tối đa")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(Color(hex: "1E293B"))
                                                Text("Phiếu sự cố đã đóng vượt quá số tháng này sẽ tự động được dọn dẹp.")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            ForEach([(1,"1 tháng"),(3,"3 tháng"),(6,"6 tháng"),(12,"12 tháng")], id: \.0) { m, label in
                                                let current = Int(customMonthsInput) ?? config.autoDeleteTicketMonths
                                                let selected = current == m
                                                Button(action: {
                                                    if isAdmin {
                                                        customMonthsInput = "\(m)"
                                                        config.autoDeleteTicketMonths = m
                                                    }
                                                }) {
                                                    Text(label)
                                                        .font(.system(size: 10, weight: selected ? .bold : .regular))
                                                        .foregroundColor(selected ? .white : Color(hex: "1E293B"))
                                                        .frame(maxWidth: .infinity)
                                                        .frame(height: 34)
                                                        .background(selected ? Color(hex: "DC2626") : Color.white)
                                                        .cornerRadius(8)
                                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color(hex: "DC2626") : Color(hex: "CBD5E1"), lineWidth: 1))
                                                }
                                                .disabled(!isAdmin)
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            Text("Hoặc tự nhập số tháng:")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(Color(hex: "1E293B"))
                                            TextField("Số tháng", text: $customMonthsInput)
                                                .keyboardType(.numberPad)
                                                .disabled(!isAdmin)
                                                .frame(width: 80)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .onChange(of: customMonthsInput) { v in
                                                    let filtered = String(v.filter { $0.isNumber }.prefix(3))
                                                    customMonthsInput = filtered
                                                    if let n = Int(filtered), n > 0 {
                                                        config.autoDeleteTicketMonths = n
                                                    }
                                                }
                                            Text("tháng").font(.system(size: 11.5)).foregroundColor(.secondary)
                                        }
                                        Divider()
                                        Button(action: cleanExpiredTickets) {
                                            HStack(spacing: 8) {
                                                if isCleaningNow {
                                                    ProgressView().scaleEffect(0.8).tint(.white)
                                                    Text("Đang dọn dẹp ticket quá hạn...")
                                                } else {
                                                    Image(systemName: "sparkles").font(.system(size: 14))
                                                    Text("Dọn dẹp ticket quá hạn ngay bây giờ")
                                                        .font(.system(size: 12.5, weight: .semibold))
                                                }
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 42)
                                            .background(isAdmin && !isCleaningNow ? Color(hex: "DC2626") : Color.gray)
                                            .cornerRadius(8)
                                        }
                                        .disabled(!isAdmin || isCleaningNow)

                                        if let msg = cleanMsg {
                                            let isSuccess = msg.hasPrefix("✅")
                                            Text(msg)
                                                .font(.system(size: 11.5, weight: .medium))
                                                .foregroundColor(isSuccess ? Color(hex: "15803D") : Color(hex: "B45309"))
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(isSuccess ? Color(hex: "DCFCE7") : Color(hex: "FFFBEB"))
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }

                            // Group 10: Email & Rating (simplified — show status only)
                            SettingGroupCard(
                                title: "Tích Hợp Email & Đánh Giá Nghiệm Thu",
                                icon: "envelope.fill",
                                iconColor: Color(hex: "0284C7"),
                                iconBg: Color(hex: "E0F2FE")
                            ) {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(Color(hex: "0284C7"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Cấu hình Email được quản lý trên Desktop")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: "1E293B"))
                                        Text("Dùng ứng dụng Desktop hoặc Web để cấu hình SMTP/Microsoft 365. Cài đặt sẽ được tự động kế thừa trên thiết bị di động.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(10)
                                .background(Color(hex: "EFF6FF"))
                                .cornerRadius(8)
                                Divider().padding(.horizontal, -16)
                                ToggleSettingItem(
                                    title: "Tự động gửi email nghiệm thu khi đóng ticket",
                                    subtitle: "Khi Admin đóng ticket có email khách, hệ thống tự động gửi email thông báo kèm 5 sao đánh giá (1..5★) đến hòm thư người gửi.",
                                    icon: "star.fill",
                                    isOn: $config.autoSendRatingEmailOnClose,
                                    isAdmin: isAdmin
                                )
                            }

                            // Success/Error banners
                            if let msg = successMsg {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "16A34A"))
                                    Text(msg).font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "15803D"))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "DCFCE7"))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                            if let msg = errorMsg {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(Color(hex: "DC2626"))
                                    Text(msg).font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "B91C1C"))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "FEF2F2"))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }

                            Spacer(minLength: 32)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Cài đặt hệ thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Đóng")
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                }
                if isAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: saveConfig) {
                            if isSaving {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                    Text("Lưu")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "EC4899"))
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .onAppear { Task { await loadConfig() } }
    }

    // MARK: - Load Config
    private func loadConfig() async {
        isLoading = true
        defer { isLoading = false }
        guard !firebase.companyId.isEmpty, !firebase.currentUserIdToken.isEmpty else { return }
        let base = "https://firestore.googleapis.com/v1/projects/qltb-81f4c/databases/(default)/documents"
        let path = "companies/\(firebase.companyId)/system_config/system_toggle_config"
        guard let url = URL(string: "\(base)/\(path)") else { return }
        var req = URLRequest(url: url)
        req.addValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else { return }
        func boolVal(_ key: String, default d: Bool) -> Bool {
            if let f = fields[key] as? [String: Any], let v = f["booleanValue"] as? Bool { return v }
            return d
        }
        func strVal(_ key: String, default d: String) -> String {
            if let f = fields[key] as? [String: Any], let v = f["stringValue"] as? String { return v }
            return d
        }
        func intVal(_ key: String, default d: Int) -> Int {
            if let f = fields[key] as? [String: Any] {
                if let v = f["integerValue"] as? String, let n = Int(v) { return n }
                if let v = f["integerValue"] as? Int { return v }
            }
            return d
        }
        var c = SystemToggleConfig()
        c.strictGeofenceBlocking          = boolVal("strictGeofenceBlocking", default: false)
        c.autoCaptureGpsOnOpen            = boolVal("autoCaptureGpsOnOpen", default: true)
        c.allowWeekendOvertimeCheckIn     = boolVal("allowWeekendOvertimeCheckIn", default: false)
        c.alertLateCheckIn                = boolVal("alertLateCheckIn", default: true)
        c.rememberSignerNames             = boolVal("rememberSignerNames", default: true)
        c.showHeaderLogoOnReport          = boolVal("showHeaderLogoOnReport", default: true)
        c.showSignatureBlockOnReport      = boolVal("showSignatureBlockOnReport", default: true)
        c.autoFitA4Page                   = boolVal("autoFitA4Page", default: true)
        c.includeQrCodeOnDevicePrint      = boolVal("includeQrCodeOnDevicePrint", default: true)
        c.notifyNewSupportTicket          = boolVal("notifyNewSupportTicket", default: true)
        c.enableNotificationSound         = boolVal("enableNotificationSound", default: true)
        c.voiceNotificationMode           = strVal("voiceNotificationMode", default: "REPEAT")
        c.confirmBeforeDelete             = boolVal("confirmBeforeDelete", default: true)
        c.compactDeviceListView           = boolVal("compactDeviceListView", default: false)
        c.preventDuplicateAssetTicket     = boolVal("preventDuplicateAssetTicket", default: true)
        c.allowTicketReopen               = boolVal("allowTicketReopen", default: true)
        c.enableAfterHoursAutoDispatch    = boolVal("enableAfterHoursAutoDispatch", default: false)
        c.notifyDispatchEmailTech         = boolVal("notifyDispatchEmailTech", default: true)
        c.notifyDispatchEmailSpecialist   = boolVal("notifyDispatchEmailSpecialist", default: true)
        c.ticketCooldownMinutes           = intVal("ticketCooldownMinutes", default: 1)
        c.allowManagerShiftEditing        = boolVal("allowManagerShiftEditing", default: false)
        c.allowHelpdeskUserManagement     = boolVal("allowHelpdeskUserManagement", default: false)
        c.allowAttachments                = boolVal("allowAttachments", default: true)
        c.maxAttachmentSizeMb             = intVal("maxAttachmentSizeMb", default: 5)
        c.enableOnlineVirusScan           = boolVal("enableOnlineVirusScan", default: false)
        c.autoDeleteTickets               = boolVal("autoDeleteTickets", default: false)
        c.autoDeleteTicketMonths          = intVal("autoDeleteTicketMonths", default: 3)
        c.autoSendRatingEmailOnClose      = boolVal("autoSendRatingEmailOnClose", default: true)
        await MainActor.run {
            config = c
            customMonthsInput = "\(c.autoDeleteTicketMonths)"
        }
    }

    // MARK: - Save Config
    private func saveConfig() {
        guard isAdmin else {
            errorMsg = "⛔ Bạn không có quyền quản trị để thay đổi cấu hình hệ thống!"
            return
        }
        guard !firebase.companyId.isEmpty, !firebase.currentUserIdToken.isEmpty else { return }
        isSaving = true
        errorMsg = nil
        successMsg = nil
        let safeMonths = max(Int(customMonthsInput) ?? config.autoDeleteTicketMonths, 1)
        config.autoDeleteTicketMonths = safeMonths
        config.updatedAt = Date().timeIntervalSince1970 * 1000
        config.updatedBy = firebase.currentUserEmail

        func field(_ b: Bool) -> Any { ["booleanValue": b] }
        func fieldI(_ i: Int) -> Any { ["integerValue": "\(i)"] }
        func fieldS(_ s: String) -> Any { ["stringValue": s] }
        func fieldD(_ d: Double) -> Any { ["doubleValue": d] }

        let fields: [String: Any] = [
            "strictGeofenceBlocking":        field(config.strictGeofenceBlocking),
            "autoCaptureGpsOnOpen":          field(config.autoCaptureGpsOnOpen),
            "allowWeekendOvertimeCheckIn":   field(config.allowWeekendOvertimeCheckIn),
            "alertLateCheckIn":              field(config.alertLateCheckIn),
            "rememberSignerNames":           field(config.rememberSignerNames),
            "showHeaderLogoOnReport":        field(config.showHeaderLogoOnReport),
            "showSignatureBlockOnReport":    field(config.showSignatureBlockOnReport),
            "autoFitA4Page":                 field(config.autoFitA4Page),
            "includeQrCodeOnDevicePrint":    field(config.includeQrCodeOnDevicePrint),
            "notifyNewSupportTicket":        field(config.notifyNewSupportTicket),
            "enableNotificationSound":       field(config.enableNotificationSound),
            "voiceNotificationMode":         fieldS(config.voiceNotificationMode),
            "confirmBeforeDelete":           field(config.confirmBeforeDelete),
            "compactDeviceListView":         field(config.compactDeviceListView),
            "preventDuplicateAssetTicket":   field(config.preventDuplicateAssetTicket),
            "allowTicketReopen":             field(config.allowTicketReopen),
            "enableAfterHoursAutoDispatch":  field(config.enableAfterHoursAutoDispatch),
            "notifyDispatchEmailTech":       field(config.notifyDispatchEmailTech),
            "notifyDispatchEmailSpecialist": field(config.notifyDispatchEmailSpecialist),
            "ticketCooldownMinutes":         fieldI(config.ticketCooldownMinutes),
            "allowManagerShiftEditing":      field(config.allowManagerShiftEditing),
            "allowHelpdeskUserManagement":   field(config.allowHelpdeskUserManagement),
            "allowAttachments":              field(config.allowAttachments),
            "maxAttachmentSizeMb":           fieldI(config.maxAttachmentSizeMb),
            "enableOnlineVirusScan":         field(config.enableOnlineVirusScan),
            "autoDeleteTickets":             field(config.autoDeleteTickets),
            "autoDeleteTicketMonths":        fieldI(config.autoDeleteTicketMonths),
            "autoSendRatingEmailOnClose":    field(config.autoSendRatingEmailOnClose),
            "updatedAt":                     fieldD(config.updatedAt),
            "updatedBy":                     fieldS(config.updatedBy)
        ]
        let body: [String: Any] = ["fields": fields]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { isSaving = false; return }
        let base = "https://firestore.googleapis.com/v1/projects/qltb-81f4c/databases/(default)/documents"
        let path = "companies/\(firebase.companyId)/system_config/system_toggle_config"
        guard let url = URL(string: "\(base)/\(path)") else { isSaving = false; return }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.addValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: req)
                await MainActor.run {
                    isSaving = false
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        successMsg = "✅ Đã lưu cấu hình hệ thống thành công!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { successMsg = nil }
                    } else {
                        errorMsg = "Lưu thất bại. Vui lòng thử lại."
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMsg = "Lỗi: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Clean Expired Tickets
    private func cleanExpiredTickets() {
        guard isAdmin else { cleanMsg = "⛔ Chỉ Quản trị viên mới có quyền dọn dẹp ticket!"; return }
        guard !firebase.companyId.isEmpty, !firebase.currentUserIdToken.isEmpty else { return }
        isCleaningNow = true
        cleanMsg = nil
        let months = Int(customMonthsInput) ?? max(config.autoDeleteTicketMonths, 1)
        let cutoff = Date().timeIntervalSince1970 * 1000 - Double(months) * 30.0 * 24.0 * 3600.0 * 1000.0
        let base = "https://firestore.googleapis.com/v1/projects/qltb-81f4c/databases/(default)/documents"
        let path = "companies/\(firebase.companyId)/support_tickets"
        guard let url = URL(string: "\(base)/\(path)?pageSize=200") else { isCleaningNow = false; return }
        var req = URLRequest(url: url)
        req.addValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let docs = json["documents"] as? [[String: Any]] else {
                    await MainActor.run { isCleaningNow = false; cleanMsg = "Không thể tải danh sách ticket." }
                    return
                }
                var deleted = 0
                for doc in docs {
                    guard let fields = doc["fields"] as? [String: Any] else { continue }
                    let status = (fields["status"] as? [String: Any])?["stringValue"] as? String ?? ""
                    let closedAt = Double((fields["closedAt"] as? [String: Any])?["integerValue"] as? String ?? "0") ?? 0
                    let createdAt = Double((fields["createdAt"] as? [String: Any])?["integerValue"] as? String ?? "0") ?? 0
                    let effectiveClosed = closedAt > 0 ? closedAt : createdAt
                    guard (status.uppercased() == "CLOSED" || closedAt > 0) && effectiveClosed > 0 && effectiveClosed < cutoff else { continue }
                    if let docName = doc["name"] as? String,
                       let delUrl = URL(string: "https://firestore.googleapis.com/v1/\(docName)") {
                        var delReq = URLRequest(url: delUrl)
                        delReq.httpMethod = "DELETE"
                        delReq.addValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
                        _ = try? await URLSession.shared.data(for: delReq)
                        deleted += 1
                    }
                }
                await MainActor.run {
                    isCleaningNow = false
                    if deleted == 0 {
                        cleanMsg = "Không có ticket đã đóng nào quá hạn \(months) tháng cần dọn dẹp."
                    } else {
                        cleanMsg = "✅ Đã dọn dẹp thành công \(deleted) ticket đã đóng quá \(months) tháng!"
                    }
                }
            } catch {
                await MainActor.run { isCleaningNow = false; cleanMsg = "Lỗi: \(error.localizedDescription)" }
            }
        }
    }
}

// MARK: - SettingGroupCard
private struct SettingGroupCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let iconBg: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconBg).frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 17))
                }
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(Color(hex: "1E293B"))
            }
            Divider()
            content()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "E2E8F0"), lineWidth: 1))
    }
}

// MARK: - ToggleSettingItem
private struct ToggleSettingItem: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    let isAdmin: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isOn ? Color(hex: "EC4899") : Color(hex: "94A3B8"))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "EC4899")))
                .disabled(!isAdmin)
        }
        .padding(.vertical, 4)
    }
}
