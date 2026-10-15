// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BioPulse",
    products: [
        .library(name: "BioPulseDomain", targets: ["BioPulseDomain"])
    ],
    targets: [
        .target(name: "BioPulseDomain"),
        .testTarget(name: "BioPulseDomainTests", dependencies: ["BioPulseDomain"])
    ]
)
