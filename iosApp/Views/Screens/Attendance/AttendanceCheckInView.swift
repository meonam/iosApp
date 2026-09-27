import SwiftUI
import CoreLocation

// MARK: - ImagePicker
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

// MARK: - View
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
                    // TopBar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            Text("Cham cong")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                    }
                    .background(Color.appPrimary)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // 1. Location Info
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(Color.appPrimary)
                                    Text("Vi tri hien tai")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.appTextPrimary)
                                    Spacer()
                                    Button(action: {
                                        viewModel.requestLocation()
                                    }) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text(viewModel.currentAddress.isEmpty ? "Dang lay vi tri..." : viewModel.currentAddress)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                if let distance = viewModel.distanceToWorkMeters {
                                    HStack {
                                        Text("Cach noi lam viec:")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Text("\(Int(distance))m")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(viewModel.isWithinGeofence ? .green : .red)
                                    }
                                    
                                    HStack {
                                        Text("Ban kinh cho phep:")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Text("\(Int(viewModel.travelConfig.geofenceRadiusMeters))m")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            
                            // 2. Selfie Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Anh xac thuc")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                                
                                HStack {
                                    if let image = selfieImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "person.crop.square.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 30))
                                            )
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showingImagePicker = true
                                    }) {
                                        HStack {
                                            Image(systemName: "camera.fill")
                                            Text("Chup anh")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.appPrimary.opacity(0.1))
                                        .foregroundColor(Color.appPrimary)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            
                            // 3. Shift Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ca lam viec")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                                
                                HStack(spacing: 8) {
                                    ShiftButton(title: "Hanh chinh", tag: "HC", selectedTag: $viewModel.selectedShiftType)
                                    ShiftButton(title: "Ca 2", tag: "SHIFT_2", selectedTag: $viewModel.selectedShiftType)
                                    ShiftButton(title: "Ca dem", tag: "NIGHT", selectedTag: $viewModel.selectedShiftType)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            
                            // 4. Action Cards
                            HStack(spacing: 12) {
                                let checkInTime = viewModel.todayRecord?.checkInTime
                                TimeCardView(
                                    title: "GIO VAO",
                                    time: formatTime(checkInTime),
                                    isDone: checkInTime != nil && checkInTime! > 0,
                                    color: .green
                                )
                                
                                let checkOutTime = viewModel.todayRecord?.checkOutTime
                                TimeCardView(
                                    title: "GIO RA",
                                    time: formatTime(checkOutTime),
                                    isDone: checkOutTime != nil && checkOutTime! > 0,
                                    color: .orange
                                )
                            }
                            
                            // 5. Buttons
                            VStack(spacing: 16) {
                                if viewModel.isSubmitting {
                                    ProgressView("Dang xu ly...")
                                        .padding()
                                } else {
                                    let hasCheckIn = viewModel.todayRecord?.checkInTime != nil && viewModel.todayRecord!.checkInTime! > 0
                                    let hasCheckOut = viewModel.todayRecord?.checkOutTime != nil && viewModel.todayRecord!.checkOutTime! > 0
                                    
                                    if !hasCheckIn {
                                        Button(action: {
                                            processCheckIn()
                                        }) {
                                            Text("CHECK IN")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 50)
                                                .background(isCheckInDisabled ? Color.gray : Color.green)
                                                .cornerRadius(12)
                                        }
                                        .disabled(isCheckInDisabled)
                                        
                                        if viewModel.travelConfig.strictGeofenceBlocking && !viewModel.isWithinGeofence {
                                            Text("Ban dang o ngoai pham vi cho phep.")
                                                .font(.system(size: 13))
                                                .foregroundColor(.red)
                                        }
                                        
                                    } else if !hasCheckOut {
                                        Button(action: {
                                            processCheckOut()
                                        }) {
                                            Text("CHECK OUT")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 50)
                                                .background(Color.orange)
                                                .cornerRadius(12)
                                        }
                                    } else {
                                        Text("Ban da hoan thanh cham cong hom nay!")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.green)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(12)
                                        
                                        if let checkIn = viewModel.todayRecord?.checkInTime, let checkOut = viewModel.todayRecord?.checkOutTime {
                                            let duration = (checkOut - checkIn) / 60000
                                            Text("Tong thoi gian lam viec: \(duration / 60)h \(duration % 60)m")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                
                                if let success = viewModel.successMessage {
                                    Text(success)
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                        .multilineTextAlignment(.center)
                                }
                                
                                if let error = viewModel.errorMessage {
                                    Text(error)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            // 6. Monthly Stats Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Thong ke thang nay")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                                
                                HStack(spacing: 12) {
                                    StatBox(title: "Tong ngay", value: viewModel.totalDays, color: .blue)
                                    StatBox(title: "Dung gio", value: viewModel.onTimeDays, color: .green)
                                    StatBox(title: "Tre gio", value: viewModel.lateDays, color: .red)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            
                            Spacer(minLength: 40)
                        }
                        .padding(16)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.fetchTravelExpenseConfig()
            viewModel.requestLocation()
            viewModel.fetchTodayAttendance()
            viewModel.fetchAttendanceHistory(month: Date())
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selfieImage)
        }
    }
    
    @MainActor
    private var isCheckInDisabled: Bool {
        if viewModel.travelConfig.strictGeofenceBlocking && !viewModel.isWithinGeofence {
            return true
        }
        if selfieImage == nil {
            return true
        }
        return false
    }
    
    private func processCheckIn() {
        if let img = selfieImage, let data = img.jpegData(compressionQuality: 0.5) {
            viewModel.selfieImageBase64 = data.base64EncodedString()
        }
        viewModel.performCheckIn()
    }
    
    private func processCheckOut() {
        viewModel.performCheckOut()
    }
    
    private func formatTime(_ timestamp: Int64?) -> String {
        guard let t = timestamp, t > 0 else { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(t) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ShiftButton: View {
    var title: String
    var tag: String
    @Binding var selectedTag: String
    
    var body: some View {
        let isSelected = selectedTag == tag
        Button(action: {
            selectedTag = tag
        }) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .appTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isSelected ? Color.appPrimary : Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct TimeCardView: View {
    var title: String
    var time: String
    var isDone: Bool
    var color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
            
            Text(time)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isDone ? color : .black)
            
            Text(isDone ? "Da ghi nhan" : "Chua co du lieu")
                .font(.system(size: 11))
                .foregroundColor(isDone ? color : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isDone ? color.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct StatBox: View {
    var title: String
    var value: Int
    var color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}