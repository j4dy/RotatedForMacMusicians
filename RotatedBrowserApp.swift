import SwiftUI
import AppKit

class RotatedWindow: NSWindow {
    
    // Recursive hit-test function that respects visual transforms
    func findTargetView(in view: NSView, physicalPoint: NSPoint) -> NSView? {
        // Convert the point to this view's local coordinate system
        let localPoint = view.convert(physicalPoint, from: view.superview)
        
        // If the point is not inside this view's bounds, return nil
        if !view.bounds.contains(localPoint) {
            return nil
        }
        
        // Recursively check subviews from front to back
        for subview in view.subviews.reversed() {
            if let target = findTargetView(in: subview, physicalPoint: localPoint) {
                return target
            }
        }
        
        return view
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
             .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            guard let contentView = self.contentView else {
                super.sendEvent(event)
                return
            }
            
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
            
            // 2. Find the exact Cocoa view under the physical mouse cursor for Web/PDF routing
            if let hitView = findTargetView(in: contentView, physicalPoint: physicalPoint) {
                let className = hitView.className
                
                // If it's a native Cocoa view like FocusableWebView or PDFView (or their descendants),
                // we forward the original physical event because they support rotation-aware conversion natively.
                if className.contains("WK") || className.contains("PDF") || className.contains("Focusable") {
                    if event.type == .leftMouseDown { hitView.mouseDown(with: event) }
                    else if event.type == .leftMouseUp { hitView.mouseUp(with: event) }
                    else if event.type == .rightMouseDown { hitView.rightMouseDown(with: event) }
                    else if event.type == .rightMouseUp { hitView.rightMouseUp(with: event) }
                    else if event.type == .otherMouseDown { hitView.otherMouseDown(with: event) }
                    else if event.type == .otherMouseUp { hitView.otherMouseUp(with: event) }
                    else if event.type == .mouseMoved { hitView.mouseMoved(with: event) }
                    else if event.type == .leftMouseDragged { hitView.mouseDragged(with: event) }
                    else if event.type == .rightMouseDragged { hitView.rightMouseDragged(with: event) }
                    else if event.type == .otherMouseDragged { hitView.otherMouseDragged(with: event) }
                    return
                }
            }
            
            super.sendEvent(event)
            return
            
        default:
            break
        }

        // Intercept scroll wheel to fix logical scroll direction in rotated view
        if event.type == .scrollWheel {
            // For 90 degree CW rotation (Physical Top = Logical Left)
            // If user pushes wheel forward (deltaY > 0 physical UP), we want content to move physically DOWN?
            // Actually, we swap delta X and Y for a natural physical feel
            let eventCopy = event.cgEvent?.copy()
            if let cgEvent = eventCopy {
                let oldPointY = cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
                let oldPointX = cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
                let oldLineY = cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                let oldLineX = cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis2)
                let oldFixedY = cgEvent.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1)
                let oldFixedX = cgEvent.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2)
                
                // We map physical delta to logical delta
                // Physical UP (dy > 0) -> Logical RIGHT (dx = dy)
                // Physical RIGHT (dx > 0) -> Logical DOWN (dy = -dx)
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
            // Cmd+1 for Browser
            if mods.contains(.command) && event.charactersIgnoringModifiers == "1" {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToBrowser"), object: nil)
                return
            }
            // Cmd+2 for PDF
            if mods.contains(.command) && event.charactersIgnoringModifiers == "2" {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToPDF"), object: nil)
                return
            }
            // Cmd+3 for Setting
            if mods.contains(.command) && event.charactersIgnoringModifiers == "3" {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToSetting"), object: nil)
                return
            }
            // Ctrl+Tab to toggle
            if mods.contains(.control) && event.keyCode == 48 {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleTab"), object: nil)
                return
            }
        }
        
        // Keyboard passthrough to ensure WKWebView gets the events directly when rotated
        if event.type == .keyDown || event.type == .keyUp {
            if let responder = self.firstResponder as? NSView {
                let className = responder.className
                if className.contains("WK") || className.contains("TextField") {
                    if event.type == .keyDown { responder.keyDown(with: event); return }
                    else { responder.keyUp(with: event); return }
                }
            }
        }
        
        super.sendEvent(event)
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
        
        let hostingView = NSHostingView(rootView: ContentView().frame(width: logicalW, height: logicalH))
        
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
