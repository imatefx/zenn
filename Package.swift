// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Zenn",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "zenn-app", targets: ["ZennApp"]),
        .executable(name: "zenn", targets: ["ZennCLI"]),
        .library(name: "ZennCore", targets: ["ZennCore"]),
        .library(name: "ZennMacOS", targets: ["ZennMacOS"]),
        .library(name: "ZennLua", targets: ["ZennLua"]),
        .library(name: "ZennIPC", targets: ["ZennIPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    ],
    targets: [
        // MARK: - Shared Types
        .target(
            name: "ZennShared",
            dependencies: [],
            path: "Sources/ZennShared"
        ),

        // MARK: - C Private API bridge
        .target(
            name: "CPrivateAPI",
            dependencies: [],
            path: "Sources/CPrivateAPI",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
            ]
        ),

        // MARK: - macOS API abstraction
        .target(
            name: "ZennMacOS",
            dependencies: [
                "ZennShared",
                "CPrivateAPI",
            ],
            path: "Sources/ZennMacOS"
        ),

        // MARK: - Core tiling engine
        .target(
            name: "ZennCore",
            dependencies: [
                "ZennShared",
                "ZennMacOS",
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "Sources/ZennCore"
        ),

        // MARK: - Lua C library (system)
        .systemLibrary(
            name: "CLua",
            path: "Sources/CLua",
            pkgConfig: "lua5.4",
            providers: [
                .brew(["lua"]),
            ]
        ),

        // MARK: - Lua C shim (exposes macros as functions)
        .target(
            name: "CLuaShim",
            dependencies: ["CLua"],
            path: "Sources/CLuaShim",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I/opt/homebrew/include/lua"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/lib"]),
                .linkedLibrary("lua"),
            ]
        ),

        // MARK: - Lua configuration engine
        .target(
            name: "ZennLua",
            dependencies: [
                "ZennShared",
                "ZennCore",
                "CLua",
                "CLuaShim",
            ],
            path: "Sources/ZennLua"
        ),

        // MARK: - IPC server
        .target(
            name: "ZennIPC",
            dependencies: [
                "ZennShared",
                "ZennCore",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            path: "Sources/ZennIPC"
        ),

        // MARK: - Menu bar application
        .executableTarget(
            name: "ZennApp",
            dependencies: [
                "ZennCore",
                "ZennMacOS",
                "ZennLua",
                "ZennIPC",
            ],
            path: "Sources/ZennApp"
        ),

        // MARK: - CLI client
        .executableTarget(
            name: "ZennCLI",
            dependencies: [
                "ZennShared",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ZennCLI"
        ),

        // MARK: - Tests
        .testTarget(
            name: "ZennCoreTests",
            dependencies: ["ZennCore"]
        ),
        .testTarget(
            name: "ZennLuaTests",
            dependencies: ["ZennLua"]
        ),
        .testTarget(
            name: "ZennIPCTests",
            dependencies: ["ZennIPC"]
        ),
    ]
)
