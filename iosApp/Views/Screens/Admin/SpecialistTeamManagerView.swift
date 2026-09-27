import SwiftUI

public struct SpecialistTeamManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var showAddSheet: Bool = false
    @State private var newTeamName: String = ""
    @State private var newTeamDesc: String = ""

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredTeams: [SpecialistTeam] {
        viewModel.specialistTeams.filter { t in
            searchQuery.isEmpty ||
            t.teamName.localizedCaseInsensitiveContains(searchQuery) ||
            t.description.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Quản lý Tổ nghiệp vụ (\(viewModel.specialistTeams.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                            
                            Button(action: {
                                Task { await viewModel.fetchSpecialistTeams() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }

                            Button(action: { showAddSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm kiếm tổ nghiệp vụ...", text: $searchQuery)
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(12)

                    List {
                        ForEach(filteredTeams) { team in
                            teamCard(team)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteSpecialistTeam(teamId: team.id) }
                                    } label: {
                                        Label("Xóa", systemImage: "trash")
                                    }
                                }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            Task { await viewModel.fetchSpecialistTeams() }
        }
        .sheet(isPresented: $showAddSheet) {
            addTeamSheetView
        }
    }

    private func teamCard(_ team: SpecialistTeam) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text(team.teamName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                
                Spacer()
                
                Text("\(team.applications.count) thành viên")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appPrimaryPink)
                    .cornerRadius(6)
            }
            
            if !team.description.isEmpty {
                Text(team.description)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private var addTeamSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin tổ nghiệp vụ")) {
                    TextField("Tên tổ nghiệp vụ", text: $newTeamName)
                    TextField("Mô tả", text: $newTeamDesc)
                }
            }
            .navigationTitle("Thêm tổ nghiệp vụ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { showAddSheet = false },
                trailing: Button("Lưu") {
                        if !newTeamName.isEmpty {
                            Task {
                                await viewModel.addSpecialistTeam(name: newTeamName, description: newTeamDesc)
                            }
                        }
                        showAddSheet = false
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimaryPink)
                }
            }
        }
    }
}
