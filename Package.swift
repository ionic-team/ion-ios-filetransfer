// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IONFileTransferLib",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "IONFileTransferLib",
            targets: ["IONFileTransferLib"]
        )
    ],
    targets: [
        .target(
            name: "IONFileTransferLib",
            path: "IONFileTransferLib"
        ),
        .testTarget(
            name: "IONFileTransferLibTests",
            dependencies: ["IONFileTransferLib"],
            path: "IONFileTransferLibTests"
        )
    ]
)
