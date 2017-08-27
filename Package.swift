// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "OptionParser",
    products: [
        .library(name: "OptionParser", type: .static, targets: ["OptionParser"]),
    ],
    targets: [
        .target(name: "OptionParser", path: "OptionParser"),
        .testTarget(name: "OptionParserTests", path: "OptionParserTests"),
    ],
    swiftLanguageVersions: [4]
)
