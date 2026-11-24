// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "NavigatorUI",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NavigatorUI",
            targets: ["NavigatorUI"])
    ],
    targets: [
        .target(
            name: "NavigatorUI"),
        .testTarget(
            name: "NavigatorUITests",
            dependencies: ["NavigatorUI"])
    ]
)
