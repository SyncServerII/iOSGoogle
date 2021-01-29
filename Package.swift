// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iOSGoogle",
    platforms: [
        // This package depends on iOSSignIn-- which needs at least iOS 13.
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "iOSGoogle",
            targets: ["iOSGoogle"]),
            
        // Without this, Xcode is failing to archive the Neebla app project.
        // See https://developer.apple.com/forums/thread/662247
        .library(
            name: "GSignIn",
            targets: ["GSignIn"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SyncServerII/iOSSignIn.git", from: "0.0.3"),
        .package(url: "https://github.com/SyncServerII/ServerShared.git", from: "0.0.4"),
        .package(url: "https://github.com/SyncServerII/iOSShared.git", from: "0.0.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "iOSGoogle",
            dependencies: [
                "GSignIn", "iOSSignIn", "ServerShared", "iOSShared"
            ],
            resources: [
                // Do *not* name this folder `Resources`. See https://stackoverflow.com/questions/52421999
                .copy("Images")
            ]),
        // See https://github.com/SyncServerII/GSignIn.git
        .binaryTarget(
            name: "GSignIn",
            url: "https://github.com/SyncServerII/GSignIn/raw/main/XCFrameworks/GSignIn-5.0.2.xcframework.zip",
            checksum: "b2b468ca98bcbe7d771726cd2a1ea6f9bee785957af8c9f4c75aa10e5c337a52"
        ),
        .testTarget(
            name: "iOSGoogleTests",
            dependencies: ["iOSGoogle"],
            resources: [
                .copy("ExampleFiles")
            ]),
    ]
)
