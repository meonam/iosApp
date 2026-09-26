//
//  AppInfoFullView.swift
//  iosApp
//
//  Tương đương Android InfoScreen.kt
//  Hiển thị: logo, phiên bản, Device ID, thông tin người dùng, giấy phép, thông tin nhà phát triển.
//

import SwiftUI

struct AppInfoFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    let onDismiss: () -> Void

    // MARK: - App metadata
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "120"
    }
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "N/A"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Logo & Tên ứng dụng ──────────────────────────────
                    VStack(spacing: 12) {
                        AppLogoImage(size: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                        Text("QLTB Pro")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.appTextPrimary)

                        Text("Phiên bản \(appVersion) (Build \(buildNumber))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Trạng thái gói dịch vụ
                        let planLabel = (firebase.isAdmin || firebase.isSuperAdmin) ? "Enterprise" : "Standard"
                        let planColor: Color = (firebase.isAdmin || firebase.isSuperAdmin) ? Color(hex: "#F59E0B") : Color(hex: "#6366F1")
                        Text(planLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(planColor))
                    }
                    .padding(.top, 8)

                    // ── Thông tin thiết bị & tài khoản ──────────────────
                    infoSection(title: "THÔNG TIN TÀI KHOẢN") {
                        infoRow(label: "Họ và tên", value: firebase.userName.isEmpty ? "—" : firebase.userName)
                        infoRow(label: "Email", value: firebase.currentUserEmail.isEmpty ? "—" : firebase.currentUserEmail)
                        infoRow(label: "Vai trò", value: firebase.formatRoleTitle())
                        infoRow(label: "Mã công ty", value: firebase.companyId.isEmpty ? "—" : firebase.companyId)
                    }

                    infoSection(title: "THÔNG TIN THIẾT BỊ") {
                        infoRow(label: "Device ID", value: deviceId, monospace: true)
                        infoRow(label: "Hệ điều hành", value: "iOS \(UIDevice.current.systemVersion)")
                        infoRow(label: "Model", value: UIDevice.current.model)
                    }

                    // ── Giấy phép & nhà phát triển ──────────────────────
                    infoSection(title: "GIẤY PHÉP & NHÀ PHÁT TRIỂN") {
                        infoRow(label: "Phát triển bởi", value: "Huyen Han Technology")
                        infoRow(label: "Bản quyền", value: "© 2024 Saigon Co.op")
                        infoRow(label: "Giấy phép", value: "Proprietary")
                        infoRow(label: "Hỗ trợ", value: "admin@huyenhan.tech")
                    }

                    // ── Footer ───────────────────────────────────────────
                    VStack(spacing: 4) {
                        Text("Hệ thống Quản lý Thiết bị Thông minh")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("Dành riêng cho hệ thống Co.opMart")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Về Ứng Dụng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .foregroundColor(.appPrimaryPink)
                }
            }
        }
    }

    // MARK: - Reusable helpers

    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private func infoRow(label: String, value: String, monospace: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(monospace
                          ? .system(size: 12, weight: .medium, design: .monospaced)
                          : .system(size: 14, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider().padding(.leading, 16)
        }
    }
}
