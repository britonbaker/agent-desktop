// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Rove", platforms: [.macOS("26.0")], dependencies: [.package(url: "https://github.com/gradium-ai/xn-ptts.git", exact: "0.4.0")], targets: [.executableTarget(name: "Rove", dependencies: [.product(name: "ptts", package: "xn-ptts")], path: "Sources", linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("Speech"), .linkedFramework("WebKit"), .linkedFramework("FoundationModels")])], swiftLanguageModes: [.v5])
