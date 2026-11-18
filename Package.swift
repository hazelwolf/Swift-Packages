// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Swift-Packages",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "LocalModelJobs", targets: ["LocalModelJobs"]),
        .library(name: "LocalModelMLX", targets: ["LocalModelMLX"]),
        .library(name: "NoteKit", targets: ["NoteKit"]),
        .library(name: "NoteKitUI", targets: ["NoteKitUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "3.33.0")),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.4.0")),
    ],
    targets: [
        .target(name: "LocalModelJobs"),
        .target(
            name: "LocalModelMLX",
            dependencies: [
                "LocalModelJobs",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ]
        ),
        .target(name: "NoteKit"),
        .target(name: "NoteKitUI", dependencies: ["NoteKit"]),
        .testTarget(name: "LocalModelJobsTests", dependencies: ["LocalModelJobs"]),
        .testTarget(name: "NoteKitTests", dependencies: ["NoteKit"]),
    ]
)
