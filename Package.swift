// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppStorys_iOS",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AppStorys_iOS",
            targets: ["AppStorys_iOS"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.12.0"),
        .package(url: "https://github.com/simibac/ConfettiSwiftUI.git", from: "1.1.0"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.4.0") // ✅ Lottie
    ],
    targets: [
        .target(
            name: "AppStorys_iOS",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "ConfettiSwiftUI", package: "ConfettiSwiftUI"),
                .product(name: "Lottie", package: "lottie-ios") // ✅ Add Lottie product
            ],
            path: "Sources/AppStorys_iOS"
        ),
    ],
    swiftLanguageModes: [.v6]
)
