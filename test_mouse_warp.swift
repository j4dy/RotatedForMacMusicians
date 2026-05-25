import AppKit

func testWarp() {
    print("Testing cursor warp")
    let point = CGPoint(x: 100, y: 100)
    CGWarpMouseCursorPosition(point)
    print("Warped to \(point)")
}
testWarp()
