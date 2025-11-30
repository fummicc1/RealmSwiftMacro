// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "RealmSwiftMacro",
    platforms: [.macOS(.v13), .iOS(.v15), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RealmSwiftMacro",
            targets: ["RealmSwiftMacro"]
        ),
        .executable(
            name: "RealmSwiftMacroClient",
            targets: ["RealmSwiftMacroClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/realm/realm-swift", .upToNextMajor(from: "10.54.6")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "RealmSwiftMacroMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "RealmSwiftMacro",
            dependencies: [
                "RealmSwiftMacroMacros",
                .product(name: "RealmSwift", package: "realm-swift"),
            ]
        ),
        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(
            name: "RealmSwiftMacroClient",
            dependencies: [
                "RealmSwiftMacro",
                .product(name: "RealmSwift", package: "realm-swift"),
            ]
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "RealmSwiftMacroTests",
            dependencies: [
                "RealmSwiftMacroMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
