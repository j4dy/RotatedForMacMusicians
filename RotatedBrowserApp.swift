import SwiftUI
import AppKit

class RotatedWindow: NSWindow {
    
    // Recursive hit-test function that respects visual transforms
    func findTargetView(in view: NSView, physicalPoint: NSPoint) -> NSView? {
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

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
             .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            guard let contentView = self.contentView else {
                super.sendEvent(event)
                return
            }
            
            let physicalPoint = event.locationInWindow
            let PH = self.frame.height - 28
            
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
            
            // 2. Find the exact Cocoa view under the physical mouse cursor for Web/PDF/SwiftUI routing
            if let hitView = findTargetView(in: contentView, physicalPoint: physicalPoint) {
                let className = hitView.className
                
                // Pathway A: Native Cocoa Views (WKWebView, PDFView)
                // Forward the original physical event directly.
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
                
                // Pathway B: SwiftUI Views
                // Translate physical coordinate to logical space and forward to the hit view directly.
                let lx = PH - physicalPoint.y
                let ly = physicalPoint.x
                
                if let translatedEvent = NSEvent.mouseEvent(
                    with: event.type,
                    location: NSPoint(x: lx, y: ly),
                    modifierFlags: event.modifierFlags,
                    timestamp: event.timestamp,
                    windowNumber: event.windowNumber,
                    context: nil,
                    eventNumber: event.eventNumber,
                    clickCount: event.clickCount,
                    pressure: event.pressure
                ) {
                    // Only apply coordinate conversion bypass for SwiftUI private gesture views (not native fields/text views)
                    let shouldBypass = className.contains("SwiftUI") && !className.contains("Text") && !className.contains("Field")
                    
                    if shouldBypass {
                        EventForwardingState.isForwardingEvent = true
                    }
                    defer { EventForwardingState.isForwardingEvent = false }
                    
                    if event.type == .leftMouseDown { hitView.mouseDown(with: translatedEvent) }
                    else if event.type == .leftMouseUp { hitView.mouseUp(with: translatedEvent) }
                    else if event.type == .rightMouseDown { hitView.rightMouseDown(with: translatedEvent) }
                    else if event.type == .rightMouseUp { hitView.rightMouseUp(with: translatedEvent) }
                    else if event.type == .otherMouseDown { hitView.otherMouseDown(with: translatedEvent) }
                    else if event.type == .otherMouseUp { hitView.otherMouseUp(with: translatedEvent) }
                    else if event.type == .mouseMoved { hitView.mouseMoved(with: translatedEvent) }
                    else if event.type == .leftMouseDragged { hitView.mouseDragged(with: translatedEvent) }
                    else if event.type == .rightMouseDragged { hitView.rightMouseDragged(with: translatedEvent) }
                    else if event.type == .otherMouseDragged { hitView.otherMouseDragged(with: translatedEvent) }
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

class RotatedContainerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hostingView = self.subviews.first else {
            return super.hitTest(point)
        }
        return hostingView.hitTest(point)
    }
}

struct EventForwardingState {
    static var isForwardingEvent = false
}

class RotatedHostingView<Content: View>: NSHostingView<Content> {
    override func convert(_ point: NSPoint, from view: NSView?) -> NSPoint {
        if EventForwardingState.isForwardingEvent {
            return point
        }
        return super.convert(point, from: view)
    }

    override func convert(_ point: NSPoint, to view: NSView?) -> NSPoint {
        if EventForwardingState.isForwardingEvent {
            return point
        }
        return super.convert(point, to: view)
    }

    override func convert(_ rect: NSRect, from view: NSView?) -> NSRect {
        if EventForwardingState.isForwardingEvent {
            return rect
        }
        return super.convert(rect, from: view)
    }

    override func convert(_ rect: NSRect, to view: NSView?) -> NSRect {
        if EventForwardingState.isForwardingEvent {
            return rect
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
        
        let titleBarHeight: CGFloat = 28
        let logicalW = screenFrame.height - titleBarHeight
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
        
        let container = RotatedContainerView(frame: NSRect(x: 0, y: 0, width: screenFrame.width, height: screenFrame.height))
        win.contentView = container
        
        let hostingView = RotatedHostingView(rootView: ContentView().frame(width: logicalW, height: logicalH))
        
        hostingView.frame = NSRect(
            x: (screenFrame.width - logicalW) / 2,
            y: (screenFrame.height - titleBarHeight - logicalH) / 2,
            width: logicalW,
            height: logicalH
        )
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
