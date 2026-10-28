import SwiftUI

public struct ScanBarcodeView: View {
    @State private var isTorchOn = false
    @State private var lastScannedCode = ""
    @State private var quantityText = "1"
    @State private var showSuccessBanner = false
    @State private var bannerMessage = ""
    @State private var totalScannedCount = 0
    
    private let db = DatabaseHelper.shared
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Camera View
                CameraScannerView(isTorchOn: isTorchOn) { code in
                    handleBarcodeScanned(code: code)
                }
                .edgesIgnoringSafeArea(.all)
                
                // Overlay Viewfinder
                VStack {
                    // Top Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KIỂM KÊ TÀI SẢN")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Tổng đã quét: \(totalScannedCount) dòng")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        Spacer()
                        Button(action: { isTorchOn.toggle() }) {
                            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.title2)
                                .foregroundColor(isTorchOn ? .yellow : .white)
                                .padding(10)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.4))
                    
                    Spacer()
                    
                    // Khung quét trung tâm
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 280, height: 160)
                        .overlay(
                            Rectangle()
                                .fill(Color.red.opacity(0.8))
                                .frame(height: 2)
                        )
                    
                    Spacer()
                    
                    // Bottom Controls
                    VStack(spacing: 12) {
                        if !lastScannedCode.isEmpty {
                            HStack {
                                Text("Mã:")
                                    .fontWeight(.bold)
                                Text(lastScannedCode)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("SL:")
                                    .fontWeight(.bold)
                                TextField("1", text: $quantityText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                        }
                        
                        if showSuccessBanner {
                            Text(bannerMessage)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.green.opacity(0.9))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                totalScannedCount = db.getCount()
            }
        }
    }
    
    private func handleBarcodeScanned(code: String) {
        lastScannedCode = code
        let qty = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        
        let success = db.insertItem(barcode: code, quantity: qty)
        if success {
            totalScannedCount = db.getCount()
            bannerMessage = "Đã lưu: \(code) (SL: \(qty))"
            withAnimation {
                showSuccessBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSuccessBanner = false
                }
            }
        }
    }
}
