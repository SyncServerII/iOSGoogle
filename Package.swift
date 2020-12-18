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
    ],
    dependencies: [
        .package(url: "https://github.com/SyncServerII/iOSSignIn.git", .branch("master")),
        .package(url: "https://github.com/SyncServerII/ServerShared.git", .branch("master")),
        .package(url: "https://github.com/SyncServerII/iOSShared.git", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "iOSGoogle",
            dependencies: [
                "GoogleSignIn", "iOSSignIn", "ServerShared", "iOSShared"
            ],
            resources: [
                // Do *not* name this folder `Resources`. See https://stackoverflow.com/questions/52421999
                .copy("Images")
            ]),
        .binaryTarget(
            name: "GoogleSignIn",
            path: "Frameworks/GoogleSignIn.xcframework"
        ),
        .testTarget(
            name: "iOSGoogleTests",
            dependencies: ["iOSGoogle"]),
    ]
)
