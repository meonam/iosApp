import SwiftUI
import CoreLocation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .camera
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.cameraDevice = .front
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                self.parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - MÀN HÌNH ĐIỂM DANH CHẤM CÔNG
public struct AttendanceCheckInView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    var onBack: () -> Void
    
    @State private var showingImagePicker = false
    @State private var selfieImage: UIImage? = nil
    
    public init(viewModel: AttendanceViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // TOP BAR
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
                    .background(Color.appPrimary)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // User Info
                            VStack(spacing: 6) {
                                Text(viewModel.user.fullName.isEmpty ? viewModel.user.email : viewModel.user.fullName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Text("Đơn vị: \(viewModel.user.donVi.isEmpty ? "Văn phòng Saigon Co.op" : viewModel.user.donVi)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text("Ngày: \(viewModel.todayDateString)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(16)
                            
                            // GPS Info
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "mappin.circle.fill").foregroundColor(.red)
                                    Text("Vị trí GPS ghi nhận:").font(.system(size: 13, weight: .bold))
                                    Spacer()
                                    if viewModel.isLocating { ProgressView().scaleEffect(0.8) }
                                }
                                Text(viewModel.currentAddress).font(.system(size: 12)).foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            
                            // Geofence Info
                            if viewModel.travelConfig.targetLatitude != 0 {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: viewModel.isWithinGeofence ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(viewModel.isWithinGeofence ? .green : .red)
                                        Text("Khoảng cách đến nơi làm việc:")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    if let dist = viewModel.distanceToWorkMeters {
                                        Text(String(format: "%.0f m / %.0f m", dist, viewModel.travelConfig.geofenceRadiusMeters))
                                            .font(.system(size: 12))
                                            .foregroundColor(viewModel.isWithinGeofence ? .green : .red)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(14)
                            }
                            
                            // Selfie Capture
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ảnh chấm công (Bắt buộc):").font(.system(size: 13, weight: .bold))
                                HStack {
                                    if let img = selfieImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture { showingImagePicker = true }
                                    } else {
                                        Button(action: { showingImagePicker = true }) {
                                            VStack {
                                                Image(systemName: "camera.fill").font(.title2)
                                                Text("Chụp ảnh").font(.caption)
                                            }
                                            .frame(width: 80, height: 80)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            
                            // Shifts
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Chọn ca làm việc:").font(.system(size: 13, weight: .bold))
                                HStack(spacing: 8) {
                                    shiftButton(title: "Hành chính", tag: "HC")
                                    shiftButton(title: "Ca 1 (Sáng)", tag: "SHIFT_1")
                                    shiftButton(title: "Ca 2 (Chiều)", tag: "SHIFT_2")
                                    shiftButton(title: "Ca 3 (Đêm)", tag: "NIGHT")
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            
                            // Time Cards
                            HStack(spacing: 12) {
                                timeStatusCard(title: "GIỜ VÀO CA", timeText: formatTime(viewModel.todayRecord?.checkInTime), isDone: viewModel.todayRecord?.isCheckedIn == true, color: .green)
                                timeStatusCard(title: "GIỜ RA CA", timeText: formatTime(viewModel.todayRecord?.checkOutTime), isDone: viewModel.todayRecord?.isCheckedOut == true, color: .red)
                            }
                            
                            // Check In/Out Actions
                            VStack(spacing: 12) {
                                if viewModel.todayRecord?.isCheckedIn != true {
                                    Button(action: {
                                        if let img = selfieImage, let data = img.jpegData(compressionQuality: 0.5) {
                                            viewModel.selfieImageBase64 = data.base64EncodedString()
                                        }
                                        viewModel.performCheckIn()
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: "arrow.right.circle.fill").font(.system(size: 36))
                                            Text("CHẤM CÔNG VÀO CA").font(.system(size: 16, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity).frame(height: 90)
                                        .background(Color.green).cornerRadius(20)
                                    }
                                    .disabled(viewModel.isSubmitting || selfieImage == nil)
                                } else if viewModel.todayRecord?.isCheckedOut != true {
                                    Button(action: {
                                        if let img = selfieImage, let data = img.jpegData(compressionQuality: 0.5) {
                                            viewModel.selfieImageBase64 = data.base64EncodedString()
                                        }
                                        viewModel.performCheckOut()
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: "arrow.left.circle.fill").font(.system(size: 36))
                                            Text("CHẤM CÔNG RA CA").font(.system(size: 16, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity).frame(height: 90)
                                        .background(Color.red).cornerRadius(20)
                                    }
                                    .disabled(viewModel.isSubmitting || selfieImage == nil)
                                } else {
                                    Text("Bạn đã hoàn thành đủ lượt chấm công hôm nay!")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.green)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(14)
                                }
                            }
                            
                            if let success = viewModel.successMessage {
                                Text(success).foregroundColor(.green).font(.system(size: 13))
                            }
                            if let err = viewModel.errorMessage {
                                Text(err).foregroundColor(.red).font(.system(size: 13))
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .padding(14)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.startUpdatingLocation()
            viewModel.fetchTodayAttendance()
            viewModel.fetchTravelExpenseConfig()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selfieImage)
        }
    }
    
    private func shiftButton(title: String, tag: String) -> some View {
        let isSelected = viewModel.selectedShiftType == tag
        return Button(action: { viewModel.selectedShiftType = tag }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .black)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private func timeStatusCard(title: String, timeText: String, isDone: Bool, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            Text(timeText).font(.system(size: 20, weight: .bold)).foregroundColor(isDone ? color : .gray)
            Text(isDone ? "Đã ghi nhận" : "Chưa chấm công")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isDone ? color : .gray)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(isDone ? color.opacity(0.12) : Color.black.opacity(0.05))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
    }
    
    private func formatTime(_ timestamp: Int64?) -> String {
        guard let t = timestamp, t > 0 else { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(t) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
