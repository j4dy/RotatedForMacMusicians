// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "net.j4dy.Vecto",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "net.j4dy.Vecto", targets: ["RotatedBrowserApp"])
    ],
    targets: [
        .executableTarget(
            name: "RotatedBrowserApp",
            path: ".",
            exclude: ["build_and_run.sh"],
            sources: [
                "RotatedBrowserApp.swift",
                "ContentView.swift",
                "WebView.swift",
                "PDFViewWrapper.swift",
                "Analytics.swift"
            ]
        )
    ]
)
