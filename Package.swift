// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "net.j4dy.RotatedBrowserApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "net.j4dy.RotatedBrowserApp", targets: ["RotatedBrowserApp"])
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
