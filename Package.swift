// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Capsule",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Capsule", targets: ["Capsule"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Capsule",
            dependencies: ["WhisperKit"],
            path: "Sources"
        )
    ]
)
