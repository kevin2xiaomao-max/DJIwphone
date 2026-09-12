// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "WebRTC",
    platforms: [.iOS(.v12)],
    products: [.library(name: "WebRTC", targets: ["WebRTC"])],
    targets: [
        .binaryTarget(
            name: "WebRTC",
            url: "https://github.com/stasel/WebRTC/releases/download/151.0.1/WebRTC-M151.xcframework.zip",
            checksum: "6f3f5693383ce65763190c46ca9f2c4325c34b83681acb9db30f01488e15f1e0"
        )
    ]
)
