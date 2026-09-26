import SwiftUI

// MARK: - MÀN HÌNH QUẢN LÝ LOẠI THIẾT BỊ (ĐỒNG BỘ 1:1 THEO DEVICETYPEMANAGERSCREEN.KT TRÊN ANDROID)
public struct DeviceTypeManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var newTypeName: String = ""
    @State private var showAddAlert: Bool = false

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

                            Text("Quản lý loại thiết bị (\(viewModel.deviceTypes.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { showAddAlert = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // 2. DANH SÁCH LOẠI THIẾT BỊ
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.deviceTypes, id: \.self) { type in
                                HStack {
                                    Image(systemName: "laptopcomputer")
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    Text(type)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.appTextPrimary)
                                    Spacer()
                                    Button(action: {
                                        viewModel.deviceTypes.removeAll { $0 == type }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.appDanger)
                                    }
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .alert("Thêm loại thiết bị mới", isPresented: $showAddAlert) {
            TextField("Tên loại thiết bị", text: $newTypeName)
            Button("Hủy", role: .cancel) {}
            Button("Thêm") {
                let clean = newTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty && !viewModel.deviceTypes.contains(clean) {
                    viewModel.deviceTypes.append(clean)
                }
                newTypeName = ""
            }
        }
    }
}
