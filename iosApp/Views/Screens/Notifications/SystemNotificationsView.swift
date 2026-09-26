import SwiftUI

public struct SystemNotificationsView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var showCreateSheet: Bool = false
    @State private var newNotifTitle: String = ""
    @State private var newNotifBody: String = ""
    @State private var newNotifTargetRole: String = "ALL"
    
    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TopBar tràn tai thỏ với Safe Area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Thông báo hệ thống")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            if viewModel.currentUser.role == "ADMIN" || viewModel.currentUser.role == "SUPER_ADMIN" {
                                Button(action: { showCreateSheet = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    if viewModel.isLoadingNotifications && viewModel.notifications.isEmpty {
                        Spacer()
                        ProgressView("Đang tải thông báo...")
                        Spacer()
                    } else if viewModel.notifications.isEmpty {
                        Spacer()
                        Text("Không có thông báo nào")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(viewModel.notifications) { notif in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(notif.title)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(notif.targetRole)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(notif.body)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                        
                                    HStack {
                                        Text(notif.createdByEmail)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color.appPrimary)
                                        Spacer()
                                        Text(notif.createdAt, style: .time)
                                            .font(.system(size: 10.5))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteNotification)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            Task {
                await viewModel.fetchNotifications()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Nội dung")) {
                        TextField("Tiêu đề", text: $newNotifTitle)
                        TextEditor(text: $newNotifBody)
                            .frame(height: 100)
                    }
                    
                    Section(header: Text("Đối tượng nhận")) {
                        Picker("Gửi đến", selection: $newNotifTargetRole) {
                            Text("Tất cả").tag("ALL")
                            Text("Kỹ thuật viên").tag("KTV")
                            Text("Nhân viên").tag("STAFF")
                            Text("Quản trị viên").tag("ADMIN")
                        }
                    }
                    
                    Button(action: sendNotification) {
                        if viewModel.isLoadingNotifications {
                            ProgressView()
                        } else {
                            Text("Gửi thông báo")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.appPrimary)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(newNotifTitle.isEmpty || newNotifBody.isEmpty || viewModel.isLoadingNotifications)
                }
                .navigationTitle("Tạo thông báo")
                .navigationBarItems(leading: Button("Hủy") { showCreateSheet = false })
            }
        }
    }
    
    private func deleteNotification(at offsets: IndexSet) {
        for index in offsets {
            let notif = viewModel.notifications[index]
            Task {
                await viewModel.deleteNotification(notifId: notif.id)
            }
        }
    }
    
    private func sendNotification() {
        Task {
            await viewModel.sendNotification(title: newNotifTitle, body: newNotifBody, targetRole: newNotifTargetRole)
            showCreateSheet = false
            newNotifTitle = ""
            newNotifBody = ""
        }
    }
}
