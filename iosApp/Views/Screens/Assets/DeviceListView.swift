import SwiftUI

struct DeviceListView: View {
    @ObservedObject var viewModel: DeviceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showFilterSheet = false
    @State private var isRefreshing = false
    
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
                    
                    // Search Bar
                    searchBar
                        .padding()
                    
                    // Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button(action: { showFilterSheet = true }) {
                                HStack {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text("Lọc")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            if viewModel.filterType != "ALL" {
                                activeFilterChip(title: "Loại: \(viewModel.filterType)") { viewModel.filterType = "ALL" }
                            }
                            if viewModel.selectedStatusFilter != "ALL" {
                                activeFilterChip(title: "TT: \(viewModel.selectedStatusFilter)") { viewModel.selectedStatusFilter = "ALL" }
                            }
                            if !viewModel.selectedDeptFilter.isEmpty {
                                activeFilterChip(title: "Phòng: \(viewModel.selectedDeptFilter)") { viewModel.selectedDeptFilter = "" }
                            }
                            
                            Menu {
                                ForEach(DeviceSortOption.allCases) { opt in
                                    Button(opt.rawValue) { viewModel.sortOption = opt }
                                }
                            } label: {
                                activeFilterChip(title: "Sắp xếp: \(viewModel.sortOption.rawValue)", action: nil)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
                    // List
                    if viewModel.isLoading && viewModel.rawDevices.isEmpty {
                        Spacer()
                        ProgressView("Đang tải danh sách...")
                        Spacer()
                    } else {
                        List {
                            ForEach(viewModel.paginatedDevices) { device in
                                DeviceCard(device: device)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .onAppear {
                                        if device.id == viewModel.paginatedDevices.last?.id {
                                            viewModel.loadMore()
                                        }
                                    }
                            }
                            
                            if viewModel.isFetchingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                            } else if viewModel.hasMore {
                                Button("Tải thêm") { viewModel.fetchDevices(isRefresh: false) }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            await refreshData()
                        }
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
        .sheet(isPresented: $showFilterSheet) {
            FilterBottomSheet(viewModel: viewModel)
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
            Text("Danh sách thiết bị")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Tìm tên, mã, serial...", text: $viewModel.searchQuery)
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
    
    @ViewBuilder
    private func activeFilterChip(title: String, action: (() -> Void)?) -> some View {
        HStack {
            Text(title).font(.subheadline)
            if let act = action {
                Button(action: act) {
                    Image(systemName: "xmark").font(.caption)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appPrimary.opacity(0.1))
        .foregroundColor(Color.appPrimary)
        .cornerRadius(20)
    }
    
    private func refreshData() async {
        isRefreshing = true
        viewModel.fetchDevices(isRefresh: true)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

struct DeviceCard: View {
    let device: ThietBi
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "desktopcomputer")
                        .foregroundColor(.gray)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.ten)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("Mã: \(device.id)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let dept = device.phongBan, !dept.isEmpty {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .font(.caption2)
                        Text(dept)
                            .font(.caption)
                    }
                    .foregroundColor(Color.appPrimary)
                }
            }
            Spacer()
            
            // Status badge
            Text(device.trangThai)
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(device.trangThai).opacity(0.1))
                .foregroundColor(statusColor(device.trangThai))
                .cornerRadius(4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
    
    private func statusColor(_ status: String) -> Color {
        let norm = status.lowercased()
        if norm.contains("hoạt động") || norm == "active" { return .green }
        if norm.contains("bảo trì") || norm == "maintenance" { return .orange }
        if norm.contains("hỏng") || norm == "retired" { return .red }
        return .gray
    }
}

struct FilterBottomSheet: View {
    @ObservedObject var viewModel: DeviceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trạng thái")) {
                    Picker("Trạng thái", selection: $viewModel.selectedStatusFilter) {
                        Text("Tất cả").tag("ALL")
                        Text("Hoạt động").tag("ACTIVE")
                        Text("Bảo trì").tag("MAINTENANCE")
                        Text("Đã thanh lý").tag("RETIRED")
                    }
                }
                
                Section(header: Text("Loại thiết bị")) {
                    Picker("Loại", selection: $viewModel.filterType) {
                        Text("Tất cả").tag("ALL")
                        Text("Máy tính").tag("Laptop")
                        Text("Máy in").tag("Printer")
                        Text("Màn hình").tag("Monitor")
                    }
                }
                
                Section(header: Text("Phòng ban")) {
                    TextField("Nhập tên phòng ban...", text: $viewModel.selectedDeptFilter)
                }
                
                Section {
                    Button(action: {
                        viewModel.selectedStatusFilter = "ALL"
                        viewModel.filterType = "ALL"
                        viewModel.selectedDeptFilter = ""
                    }) {
                        Text("Xóa bộ lọc")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationBarTitle("Lọc danh sách", displayMode: .inline)
            .navigationBarItems(trailing: Button("Xong") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
