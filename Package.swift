// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SAGA",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Saga", targets: ["Saga"]),
        .executable(name: "SagaTests", targets: ["SagaTests"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SagaCore",
            dependencies: [],
            path: "Sources/SagaCore"
        ),
        .executableTarget(
            name: "Saga",
            dependencies: ["SagaCore"],
            path: "Sources/Saga",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "SagaTests",
            dependencies: ["SagaCore"],
            path: "Sources/SagaTests"
        )
    ]
)
