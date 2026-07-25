// swift-tools-version: 5.9
//
// FORGE — Package.swift
//
// This file documents the Swift Package Manager (SPM) dependencies used by the FORGE iOS app.
// The actual dependencies are managed by the Xcode project file (FORGE.xcodeproj),
// NOT by this Package.swift. This file serves as a version reference and documentation
// for the dependency graph.
//
// To add these dependencies in Xcode:
//   File → Add Package Dependencies → Enter URL → Select version
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │ Dependency       │ Purpose                │ Spec Section           │
// ├──────────────────┼────────────────────────┼────────────────────────┤
// │ SwiftTerm        │ Terminal emulator UI   │ §7 (Terminal Interface) │
// │ swift-libgit2    │ Git operations         │ §14 (Git Integration)   │
// └──────────────────┴────────────────────────┴────────────────────────┘
//
// SwiftTerm: https://github.com/migueldeicaza/SwiftTerm
//   - Provides TerminalView for UIKit and SwiftUI
//   - Full ANSI color support (custom palette in ForgeANSIPalette)
//   - PTY-based process execution
//   - Headless mode for programmatic interaction
//
// swift-libgit2: https://github.com/light-tech/swift-libgit2
//   - Pure Swift bindings to libgit2
//   - Repository init, clone, commit, log, branch, status
//   - No external git binary required
//

import PackageDescription

let package = Package(
    name: "FORGE",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FORGE",
            targets: ["FORGE"]
        )
    ],
    dependencies: [
        // SwiftTerm — Terminal emulator for SwiftUI/UIKit
        // Used for: Code terminal view, ANSI color rendering, PTY session management
        .package(
            url: "https://github.com/migueldeicaza/SwiftTerm.git",
            from: "1.2.0"
        ),

        // swift-libgit2 — Git operations for iOS
        // Used for: Repository management, commit history, branch operations
        .package(
            url: "https://github.com/light-tech/swift-libgit2.git",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "FORGE",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "libgit2", package: "swift-libgit2")
            ],
            path: "iOS/FORGE"
        )
    ]
)
