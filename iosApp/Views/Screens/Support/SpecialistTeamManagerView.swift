import SwiftUI

// MARK: - MÀN HÌNH QUẢN LÝ ĐỘI CHUYÊN VIÊN (ĐỒNG BỘ 1:1 THEO SPECIALISTTEAMMANAGERSCREEN.KT TRÊN ANDROID)
public struct SpecialistTeamItem: Identifiable, Hashable {
    public var id: String
    public var name: String
    public var description: String
    public var leaderName: String
    public var memberCount: Int
    public var icon: String

    public init(id: String, name: String, description: String, leaderName: String, memberCount: Int, icon: String = "person.3.fill") {
        self.id = id
        self.name = name
        self.description = description
        self.leaderName = leaderName
        self.memberCount = memberCount
        self.icon = icon
    }
}

public struct SpecialistTeamManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var teams: [SpecialistTeamItem] = [
        SpecialistTeamItem(id: "team_pos", name: "Tổ Chuyên viên POS & Thu ngân", description: "Xử lý lỗi máy POS, máy quét tính tiền và két tiền siêu thị", leaderName: "Trần Văn An", memberCount: 5, icon: "cart.fill"),
        SpecialistTeamItem(id: "team_network", name: "Tổ Chuyên viên Mạng & Hạ tầng", description: "Quản trị Router, Switch Cisco, cáp quang và mạng nội bộ", leaderName: "Lê Quốc Bảo", memberCount: 4, icon: "network"),
        SpecialistTeamItem(id: "team_software", name: "Tổ Chuyên viên Phần mềm ERP", description: "Hỗ trợ phần mềm bán hàng, kế toán SAP và phân quyền", leaderName: "Nguyễn Minh Cường", memberCount: 6, icon: "laptopcomputer"),
        SpecialistTeamItem(id: "team_hardware", name: "Tổ Kỹ thuật Sửa chữa Phần cứng", description: "Bảo trì máy in nhiệt, camera giám sát và máy chủ cục bộ", leaderName: "Hoàng Văn Dũng", memberCount: 8, icon: "wrench.and.screwdriver.fill")
    ]

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Quản lý Đội Chuyên viên (\(teams.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // 2. DANH SÁCH ĐỘI CHUYÊN VIÊN
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(teams) { team in
                                teamCard(team)
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private func teamCard(_ team: SpecialistTeamItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: team.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .frame(width: 42, height: 42)
                    .background(Color.appSecondaryDarkBlue.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(team.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Text("Trưởng tổ: \(team.leaderName)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                Text("\(team.memberCount) NV")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appPrimaryPink.opacity(0.12))
                    .cornerRadius(6)
            }

            Text(team.description)
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }
}
