import SwiftUI
import AppKit

class RotatedWindow: NSWindow {
    
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
             .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let physicalPoint = event.locationInWindow
            let PH = self.frame.height
            
            // 1. Direct Intercept for physically rotated SwiftUI Navigation Bar
            // The nav bar resides visually on the physical left edge (x: 0..100) due to 90 deg CW rotation.
            // In logical space, the buttons occupy thirds of the logical width (PH).
            if physicalPoint.x >= 0 && physicalPoint.x <= 100 {
                if event.type == .leftMouseDown {
                    // Physical top third maps to logical left (Browser)
                    if physicalPoint.y >= 2 * PH / 3 && physicalPoint.y <= PH {
                        print("Direct Click: Switched to Browser")
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToBrowser"), object: nil)
                    }
                    // Physical middle third maps to logical middle (PDF)
                    else if physicalPoint.y >= PH / 3 && physicalPoint.y < 2 * PH / 3 {
                        print("Direct Click: Switched to PDF")
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToPDF"), object: nil)
                    }
                    // Physical bottom third maps to logical right (Setting)
                    else if physicalPoint.y >= 0 && physicalPoint.y < PH / 3 {
                        print("Direct Click: Switched to Setting")
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToSetting"), object: nil)
                    }
                }
                return
            }
            
            super.sendEvent(event)
            return
            
        default:
            break
        }

        // Intercept scroll wheel to fix logical scroll direction in rotated view
        if event.type == .scrollWheel {
            let eventCopy = event.cgEvent?.copy()
            if let cgEvent = eventCopy {
                let oldPointY = cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
                let oldPointX = cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
                let oldLineY = cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                let oldLineX = cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis2)
                let oldFixedY = cgEvent.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1)
                let oldFixedX = cgEvent.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2)
                
                cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -oldPointX)
                cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: oldPointY)
                cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -oldLineX)
                cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: oldLineY)
                cgEvent.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -oldFixedX)
                cgEvent.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: oldFixedY)
                
                if let mappedEvent = NSEvent(cgEvent: cgEvent) {
                    super.sendEvent(mappedEvent)
                    return
                }
            }
        }
        
        if event.type == .keyDown {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.contains(.command) && event.charactersIgnoringModifiers == "1" {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToBrowser"), object: nil)
                return
            }
            if mods.contains(.command) && event.charactersIgnoringModifiers == "2" {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToPDF"), object: nil)
                return
            }
            if mods.contains(.command) && event.charactersIgnoringModifiers == "3" {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToSetting"), object: nil)
                return
            }
            if mods.contains(.control) && event.keyCode == 48 {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleTab"), object: nil)
                return
            }
        }
        
        super.sendEvent(event)
    }
}

class RotatedHostingView<Content: View>: NSHostingView<Content> {
    private var isPerformingStandardHitTest = false
    private var lastCheckedEvent: NSEvent?
    private var cachedBypassResult = false
    
    private func shouldBypassRotation() -> Bool {
        if isPerformingStandardHitTest { return true }
        guard let window = self.window else { return true }
        guard let currentEvent = window.currentEvent else { return true }
        
        if lastCheckedEvent === currentEvent {
            return cachedBypassResult
        }
        
        lastCheckedEvent = currentEvent
        
        isPerformingStandardHitTest = true
        defer { isPerformingStandardHitTest = false }
        
        guard let contentView = window.contentView else {
            cachedBypassResult = false
            return false
        }
        
        let physicalPoint = currentEvent.locationInWindow
        if let hitView = findTargetView(in: contentView, physicalPoint: physicalPoint) {
            let className = hitView.className
            if className.contains("WK") || className.contains("PDF") || className.contains("Focusable") {
                cachedBypassResult = true
                return true
            }
        }
        
        cachedBypassResult = false
        return false
    }
    
    private func findTargetView(in view: NSView, physicalPoint: NSPoint) -> NSView? {
        let localPoint = view.convert(physicalPoint, from: view.superview)
        if !view.bounds.contains(localPoint) {
            return nil
        }
        for subview in view.subviews.reversed() {
            if let target = findTargetView(in: subview, physicalPoint: localPoint) {
                return target
            }
        }
        return view
    }
    
    override func convert(_ point: NSPoint, from view: NSView?) -> NSPoint {
        if let event = self.window?.currentEvent {
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                 .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseEntered, .mouseExited,
                 .cursorUpdate:
                if shouldBypassRotation() {
                    break
                }
                let winPoint = view?.convert(point, to: nil) ?? point
                let winH = self.window?.frame.height ?? 0
                let lx = winH - winPoint.y
                let ly = winPoint.x
                return NSPoint(x: lx, y: ly)
            default:
                break
            }
        }
        return super.convert(point, from: view)
    }

    override func convert(_ point: NSPoint, to view: NSView?) -> NSPoint {
        if let event = self.window?.currentEvent {
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                 .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseEntered, .mouseExited,
                 .cursorUpdate:
                if shouldBypassRotation() {
                    break
                }
                let winH = self.window?.frame.height ?? 0
                let px = point.y
                let py = winH - point.x
                let winPoint = NSPoint(x: px, y: py)
                return view?.convert(winPoint, from: nil) ?? winPoint
            default:
                break
            }
        }
        return super.convert(point, to: view)
    }

    override func convert(_ rect: NSRect, from view: NSView?) -> NSRect {
        if let event = self.window?.currentEvent {
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                 .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseEntered, .mouseExited,
                 .cursorUpdate:
                if shouldBypassRotation() {
                    break
                }
                let p1 = rect.origin
                let p2 = NSPoint(x: rect.maxX, y: rect.maxY)
                let lp1 = self.convert(p1, from: view)
                let lp2 = self.convert(p2, from: view)
                return NSRect(
                    x: min(lp1.x, lp2.x),
                    y: min(lp1.y, lp2.y),
                    width: abs(lp1.x - lp2.x),
                    height: abs(lp1.y - lp2.y)
                )
            default:
                break
            }
        }
        return super.convert(rect, from: view)
    }

    override func convert(_ rect: NSRect, to view: NSView?) -> NSRect {
        if let event = self.window?.currentEvent {
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                 .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseEntered, .mouseExited,
                 .cursorUpdate:
                if shouldBypassRotation() {
                    break
                }
                let p1 = rect.origin
                let p2 = NSPoint(x: rect.maxX, y: rect.maxY)
                let pp1 = self.convert(p1, to: view)
                let pp2 = self.convert(p2, to: view)
                return NSRect(
                    x: min(pp1.x, pp2.x),
                    y: min(pp1.y, pp2.y),
                    width: abs(pp1.x - pp2.x),
                    height: abs(pp1.y - pp2.y)
                )
            default:
                break
            }
        }
        return super.convert(rect, to: view)
    }
}

class StableWindowController: NSObject, NSWindowDelegate {
    static let shared = StableWindowController()
    var window: NSWindow?
    
    func setup() {
        if self.window != nil { return }
        
        NSApplication.shared.setActivationPolicy(.regular)
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let logicalW = screenFrame.height
        let logicalH = screenFrame.width
        
        let win = RotatedWindow(
            contentRect: screenFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.window = win
        win.delegate = self
        win.level = .floating
        win.hidesOnDeactivate = false
        win.title = "Rotated Browser"
        win.isReleasedWhenClosed = false
        win.acceptsMouseMovedEvents = true
        win.backgroundColor = .white
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: screenFrame.width, height: screenFrame.height))
        win.contentView = container
        
        let hostingView = RotatedHostingView(rootView: ContentView().frame(width: logicalW, height: logicalH))
        
        hostingView.frame = NSRect(x: (screenFrame.width - logicalW)/2, y: (screenFrame.height - logicalH)/2, width: logicalW, height: logicalH)
        hostingView.frameCenterRotation = -90 // -90 CCW = 90 CW (Physical Top = Logical Left)
        
        container.addSubview(hostingView)
        
        win.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if win.level != .floating { win.level = .floating }
            if NSApp.isActive && !win.isKeyWindow { win.makeKey() }
        }
    }
}


@main
struct RotatedBrowserApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            StableWindowController.shared.setup()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Color.clear.frame(width: 0, height: 0).hidden()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
