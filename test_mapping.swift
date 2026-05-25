import AppKit

func test() {
    let SW: CGFloat = 1440
    let SH: CGFloat = 900
    
    let cases: [(CGFloat, CGFloat)] = [
        (0, 0),
        (1440, 0),
        (0, 900),
        (1440, 900),
        (720, 450)
    ]
    
    print("CGEvent Global (Top-Left origin):")
    for (px, py) in cases {
        let lx = py
        let ly = SW - px
        print("(\(px), \(py)) -> (\(lx), \(ly))")
    }
}
test()
