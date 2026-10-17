// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BioPulse",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "BioPulseDomain", targets: ["BioPulseDomain"])
    ],
    targets: [
        .target(name: "BioPulseDomain"),
        .testTarget(name: "BioPulseDomainTests", dependencies: ["BioPulseDomain"])
    ]
)
