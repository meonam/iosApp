import SwiftUI

// MARK: - MÀN HÌNH ĐIỂM DANH CHẤM CÔNG (ĐỒNG BỘ 1:1 VỚI ATTENDANCECHECKINSCREEN.KT TRÊN ANDROID)
public struct AttendanceCheckInView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    var onBack: () -> Void

    public init(viewModel: AttendanceViewModel, onBack: @escaping () -> Void) {
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

                            Text("Điểm danh chấm công")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { viewModel.startUpdatingLocation() }) {
                                Image(systemName: "location.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                // 2. NỘI DUNG CHÍNH
                ScrollView {
                    VStack(spacing: 16) {
                        // Card Người dùng & Ngày
                        VStack(spacing: 6) {
                            Text(viewModel.user.fullName.isEmpty ? viewModel.user.email : viewModel.user.fullName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            Text("Đơn vị: \(viewModel.user.donVi.isEmpty ? "Văn phòng Saigon Co.op" : viewModel.user.donVi)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Text("Ngày: \(viewModel.todayDateString)")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))

                        // Card Vị trí GPS
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(Color.appPrimaryPink)
                                Text("Vị trí GPS ghi nhận:")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                                Spacer()
                                if viewModel.isLocating {
                                    ProgressView().scaleEffect(0.8)
                                }
                            }

                            Text(viewModel.currentAddress)
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                        // Bộ chọn Ca làm việc
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Chọn ca làm việc:")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            HStack(spacing: 8) {
                                shiftButton(title: "Hành chính", tag: "HC")
                                shiftButton(title: "Ca 1 (Sáng)", tag: "SHIFT_1")
                                shiftButton(title: "Ca 2 (Chiều)", tag: "SHIFT_2")
                                shiftButton(title: "Ca 3 (Đêm)", tag: "NIGHT")
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                        // Hàng giờ Chấm công Vào & Ra
                        HStack(spacing: 12) {
                            timeStatusCard(
                                title: "GIỜ VÀO CA",
                                timeText: formatTime(viewModel.todayRecord?.checkInTime),
                                isDone: viewModel.todayRecord?.isCheckedIn == true,
                                color: .appSuccess
                            )

                            timeStatusCard(
                                title: "GIỜ RA CA",
                                timeText: formatTime(viewModel.todayRecord?.checkOutTime),
                                isDone: viewModel.todayRecord?.isCheckedOut == true,
                                color: .appPrimaryPink
                            )
                        }

                        // Nút Bấm Chấm công Lớn
                        VStack(spacing: 12) {
                            if viewModel.todayRecord?.isCheckedIn != true {
                                Button(action: { viewModel.performCheckIn() }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.system(size: 36))
                                        Text("CHẤM CÔNG VÀO CA")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 90)
                                    .background(Color.appSuccess)
                                    .cornerRadius(20)
                                    .shadow(color: Color.appSuccess.opacity(0.35), radius: 10, x: 0, y: 5)
                                }
                                .disabled(viewModel.isSubmitting)
                            } else if viewModel.todayRecord?.isCheckedOut != true {
                                Button(action: { viewModel.performCheckOut() }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "arrow.left.circle.fill")
                                            .font(.system(size: 36))
                                        Text("CHẤM CÔNG RA CA")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 90)
                                    .background(Color.appPrimaryPink)
                                    .cornerRadius(20)
                                    .shadow(color: Color.appPrimaryPink.opacity(0.35), radius: 10, x: 0, y: 5)
                                }
                                .disabled(viewModel.isSubmitting)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.appSuccess)
                                    Text("Bạn đã hoàn thành đủ lượt chấm công hôm nay!")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color.appSuccess)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(Color.appSuccess.opacity(0.1))
                                .cornerRadius(14)
                            }
                        }
                        .padding(.top, 10)

                        if let success = viewModel.successMessage {
                            Text(success)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appSuccess)
                        }

                        if let err = viewModel.errorMessage {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(Color.appDanger)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(14)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    .onAppear {
            viewModel.startUpdatingLocation()
            viewModel.fetchTodayAttendance()
        }
    }

    private func shiftButton(title: String, tag: String) -> some View {
        let isSelected = viewModel.selectedShiftType == tag
        return Button(action: { viewModel.selectedShiftType = tag }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color.appTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(isSelected ? Color.appSecondaryDarkBlue : Color.appBackground)
                .cornerRadius(8)
        }
    }

    private func timeStatusCard(title: String, timeText: String, isDone: Bool, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.appTextSecondary)

            Text(timeText)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isDone ? color : Color.appTextSecondary)

            Text(isDone ? "Đã ghi nhận" : "Chưa chấm công")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isDone ? color : Color.appTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(isDone ? color.opacity(0.12) : Color.black.opacity(0.05))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func formatTime(_ timestamp: Int64?) -> String {
        guard let t = timestamp, t > 0 else { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(t) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
