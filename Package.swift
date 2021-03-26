// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if !arch(x86_64)
  fatalError("VMMKit is currently only supported on x86_64")
#endif

let package = Package(
    name: "vmmkit",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "VMMKit",
            targets: ["VMMKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(path: "../../swift-misc/swift-babab"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CBits",
            dependencies:[]),
        .target(
            name: "VMMKit",
            dependencies:[
                "CBits",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "BABAB", package: "swift-babab"),
            ]
        ),
        .testTarget(
            name: "VMMKitTests",
            dependencies: ["VMMKit"],
            exclude: ["real_mode_test.asm"],
            resources: [ .copy("real_mode_test.bin") ]
            ),
    ]
)
