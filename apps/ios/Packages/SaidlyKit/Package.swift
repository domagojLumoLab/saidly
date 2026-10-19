// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .define("DEBUG", .when(configuration: .debug))
]

let package = Package(
    name: "SaidlyKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "Domain",
            targets: ["Domain"]
        ),
        .library(
            name: "Auth",
            targets: ["Auth"]
        ),
        .library(
            name: "AuthFeature",
            targets: ["AuthFeature"]
        ),
    ],
    dependencies: [.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "13.0.1")],
    targets: [
        .target(
            name: "Domain",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Auth",
            dependencies: [
                "Domain",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "AuthFeature",
            dependencies: [
                "Domain"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AuthTests",
            dependencies: [
                "Auth", "Domain",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AuthFeatureTests",
            dependencies: [
                "AuthFeature", "Domain",
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
