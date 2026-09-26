import SwiftUI

// MARK: - DRAWER ITEM DEFINITION
public enum DrawerDestination: Identifiable {
    case home
    case deviceList
    case addDevice
    case printBarcode
    case deviceTypes
    case statistics
    case supportHub
    case supportRating
    case specialistTeams
    case ktvMonitor
    case attendance
    case attendanceReport
    case shiftSchedule
    case userManagement
    case approveStaff
    case departmentManagement
    case unitManagement
    case regionManagement
    case systemSettings
    case paywallLicense
    case peripherals

    public var id: String {
        switch self {
        case .home: return "home"
        case .deviceList: return "deviceList"
        case .addDevice: return "addDevice"
        case .printBarcode: return "printBarcode"
        case .deviceTypes: return "deviceTypes"
        case .statistics: return "statistics"
        case .supportHub: return "supportHub"
        case .supportRating: return "supportRating"
        case .specialistTeams: return "specialistTeams"
        case .ktvMonitor: return "ktvMonitor"
        case .attendance: return "attendance"
        case .attendanceReport: return "attendanceReport"
        case .shiftSchedule: return "shiftSchedule"
        case .userManagement: return "userManagement"
        case .approveStaff: return "approveStaff"
        case .departmentManagement: return "departmentManagement"
        case .unitManagement: return "unitManagement"
        case .regionManagement: return "regionManagement"
        case .systemSettings: return "systemSettings"
        case .paywallLicense: return "paywallLicense"
        case .peripherals: return "peripherals"
        }
    }
}

// MARK: - APP SIDEBAR DRAWER (ĐỒNG BỘ 1:1 VỚI MAINACTIVITY.KT & DRAWER ANDROID)
public struct AppSidebarDrawer: View {
    var user: User
    var pendingStaffCount: Int
    var onSelect: (DrawerDestination) -> Void
    var onLogout: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Drawer Header (Hồ sơ người dùng)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(!user.fullName.isEmpty ? user.fullName : "Người dùng")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(user.email)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.8))
                            .lineLimit(1)

                        // Role badge
                        Text(user.role.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(8)
                    }
                }

                if !user.donVi.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.system(size: 11))
                        Text(user.donVi)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color.white.opacity(0.85))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSecondaryDarkBlue)

            // 2. Danh sách Menu điều hướng
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    drawerRow(title: "Trang chủ", icon: "house.fill", color: .appSecondaryDarkBlue) {
                        onSelect(.home)
                    }

                    // --- NHÓM 1: QUẢN LÝ THIẾT BỊ & TÀI SẢN ---
                    sectionHeader("QUẢN LÝ THIẾT BỊ")
                    drawerRow(title: "Danh sách thiết bị", icon: "desktopcomputer", color: .statusInUse) {
                        onSelect(.deviceList)
                    }
                    drawerRow(title: "Thêm thiết bị mới", icon: "plus.circle.fill", color: .appSuccess) {
                        onSelect(.addDevice)
                    }
                    drawerRow(title: "In tem mã QR / Barcode", icon: "printer.fill", color: .appInfo) {
                        onSelect(.printBarcode)
                    }
                    drawerRow(title: "Quản lý loại thiết bị", icon: "tag.fill", color: .statusRepair) {
                        onSelect(.deviceTypes)
                    }
                    drawerRow(title: "Thống kê & Báo cáo tài sản", icon: "chart.pie.fill", color: .statusOnLoan) {
                        onSelect(.statistics)
                    }

                    // --- NHÓM 2: TRUNG TÂM KỸ THUẬT & HỖ TRỢ ---
                    sectionHeader("TRUNG TÂM HỖ TRỢ (TICKET)")
                    drawerRow(title: "Yêu cầu hỗ trợ (Ticket)", icon: "headphones", color: .appPrimaryPink) {
                        onSelect(.supportHub)
                    }
                    drawerRow(title: "Báo cáo đánh giá SLA KTV", icon: "star.fill", color: .statusRepair) {
                        onSelect(.supportRating)
                    }
                    drawerRow(title: "Quản lý đội chuyên viên", icon: "person.3.fill", color: .appInfo) {
                        onSelect(.specialistTeams)
                    }
                    drawerRow(title: "Giám sát KTV trực tuyến (Map)", icon: "map.fill", color: .appSuccess) {
                        onSelect(.ktvMonitor)
                    }

                    // --- NHÓM 3: CHẤM CÔNG & LỊCH CA ---
                    sectionHeader("CHẤM CÔNG & LỊCH CA")
                    drawerRow(title: "Điểm danh chấm công", icon: "person.badge.shield.checkmark.fill", color: .statusInStock) {
                        onSelect(.attendance)
                    }
                    drawerRow(title: "Báo cáo công & Tăng ca", icon: "calendar.badge.clock", color: .statusRepair) {
                        onSelect(.attendanceReport)
                    }
                    drawerRow(title: "Lịch phân ca tuần", icon: "calendar", color: .appSecondaryDarkBlue) {
                        onSelect(.shiftSchedule)
                    }

                    // --- NHÓM 4: QUẢN TRỊ DOANH NGHIỆP (ADMIN) ---
                    if user.isAdmin || user.isSuperAdmin {
                        sectionHeader("QUẢN TRỊ HỆ THỐNG")
                        drawerRow(title: "Quản lý tài khoản người dùng", icon: "person.2.fill", color: .appSecondaryDarkBlue) {
                            onSelect(.userManagement)
                        }
                        drawerRow(title: "Duyệt nhân viên mới", icon: "person.badge.plus", color: .appPrimaryPink, badge: pendingStaffCount > 0 ? "\(pendingStaffCount)" : nil) {
                            onSelect(.approveStaff)
                        }
                        drawerRow(title: "Quản lý phòng ban", icon: "folder.fill", color: .statusInUse) {
                            onSelect(.departmentManagement)
                        }
                        drawerRow(title: "Quản lý đơn vị / Chi nhánh", icon: "building.2.fill", color: .appSuccess) {
                            onSelect(.unitManagement)
                        }
                        drawerRow(title: "Quản lý khu vực / Cụm", icon: "map.circle.fill", color: .appInfo) {
                            onSelect(.regionManagement)
                        }
                        drawerRow(title: "Cấu hình hệ thống & Bản quyền", icon: "gearshape.fill", color: .statusLiquidated) {
                            onSelect(.systemSettings)
                        }
                    }

                    drawerRow(title: "Ngoại vi & Máy in / quét", icon: "printer.fill", color: .appInfo) {
                        onSelect(.peripherals)
                    }

                    Spacer(minLength: 20)

                    // Nút Đăng xuất
                    Divider().padding(.vertical, 8)
                    drawerRow(title: "Đăng xuất", icon: "rectangle.portrait.and.arrow.right", color: .appDanger) {
                        onLogout()
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .frame(width: 290)
        .background(Color.white)
        .ignoresSafeArea(edges: .vertical)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Color.appTextSecondary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private func drawerRow(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.appTextPrimary)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
