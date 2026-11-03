// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BarcodeScanner",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "BarcodeScanner",
            targets: ["BarcodeScanner"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BarcodeScanner",
            dependencies: [],
            path: "BarcodeScanner/Sources"
        )
    ]
)
