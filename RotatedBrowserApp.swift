import SwiftUI
import AppKit

class RotatedWindow: NSWindow {
    static var pressedKeys = Set<UInt16>()
    static var pendingNavigationWorkItem: DispatchWorkItem?
    
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

    // Recursive check to see if a view or any of its ancestors is a native web/PDF view
    func isNativeView(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let v = current {
            let name = v.className
            if name.contains("WK") || name.contains("PDF") || name.contains("Focusable") {
                return true
            }
            current = v.superview
        }
        return false
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
            
            let isFullScreen = self.styleMask.contains(.fullScreen)
            let titleBarHeight: CGFloat = isFullScreen ? 0 : 28
            
            // Allow native macOS window control buttons and titlebar dragging to work
            if !isFullScreen && physicalPoint.y >= self.frame.height - 28 {
                super.sendEvent(event)
                return
            }
            
            let PH = self.frame.height - titleBarHeight
            let isLeft = UserDefaults.standard.bool(forKey: "isRotateLeftEnabled")
            
            // 1. Direct Intercept for physically rotated SwiftUI Navigation Bar
            // For Rotate Right (-90 CCW / 90 CW): Nav bar resides physically on left edge (x: 0..100)
            // For Rotate Left (90 CCW): Nav bar resides physically on right edge (x >= frame.width - 100)
            let isNavBarArea = isLeft ? (physicalPoint.x >= self.frame.width - 100) : (physicalPoint.x >= 0 && physicalPoint.x <= 100)
            if isNavBarArea {
                if event.type == .leftMouseDown {
                    if isLeft {
                        // Under 90 CCW:
                        // Physical bottom third maps to Browser (logical left, x=0)
                        if physicalPoint.y >= 0 && physicalPoint.y < PH / 3 {
                            print("Direct Click (Left Rotated): Switched to Browser")
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToBrowser"), object: nil)
                        }
                        // Physical middle third maps to PDF
                        else if physicalPoint.y >= PH / 3 && physicalPoint.y < 2 * PH / 3 {
                            print("Direct Click (Left Rotated): Switched to PDF")
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToPDF"), object: nil)
                        }
                        // Physical top third maps to Setting (logical right)
                        else if physicalPoint.y >= 2 * PH / 3 && physicalPoint.y <= PH {
                            print("Direct Click (Left Rotated): Switched to Setting")
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToSetting"), object: nil)
                        }
                    } else {
                        // Original Rotate Right (-90 CCW)
                        if physicalPoint.y >= 2 * PH / 3 && physicalPoint.y <= PH {
                            print("Direct Click: Switched to Browser")
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToBrowser"), object: nil)
                        }
                        else if physicalPoint.y >= PH / 3 && physicalPoint.y < 2 * PH / 3 {
                            print("Direct Click: Switched to PDF")
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToPDF"), object: nil)
                        }
                        else if physicalPoint.y >= 0 && physicalPoint.y < PH / 3 {
                            print("Direct Click: Switched to Setting")
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToSetting"), object: nil)
                        }
                    }
                }
                return
            }
            
            // 1.5 Direct Intercept for Page Navigation Bar in PDF Tab
            let isPageBarArea = isLeft ? (physicalPoint.x >= self.frame.width - 160 && physicalPoint.x < self.frame.width - 100) : (physicalPoint.x > 100 && physicalPoint.x <= 160)
            if isPageBarArea && ActiveTabState.selectedTab == 1 {
                if event.type == .leftMouseDown {
                    if isLeft {
                        // Under 90 CCW:
                        // Logical left (Folder, Prev) maps physically to bottom
                        // Logical right (Next) maps physically to top
                        if physicalPoint.y >= 0 && physicalPoint.y < PH / 4 {
                            print("Direct Click: Folder Button")
                            NotificationCenter.default.post(name: NSNotification.Name("PDFShowFolderSelector"), object: nil)
                        }
                        else if physicalPoint.y >= PH / 4 && physicalPoint.y < PH / 2 {
                            print("Direct Click: Prev Page")
                            NotificationCenter.default.post(name: NSNotification.Name("PDFGoToPreviousPage"), object: nil)
                        }
                        else if physicalPoint.y >= PH / 2 && physicalPoint.y <= PH {
                            print("Direct Click: Next Page")
                            NotificationCenter.default.post(name: NSNotification.Name("PDFGoToNextPage"), object: nil)
                        }
                    } else {
                        // Original Rotate Right (-90 CCW):
                        // Logical left (Folder, Prev) maps physically to top
                        // Logical right (Next) maps physically to bottom
                        if physicalPoint.y >= 3 * PH / 4 && physicalPoint.y <= PH {
                            print("Direct Click: Folder Button")
                            NotificationCenter.default.post(name: NSNotification.Name("PDFShowFolderSelector"), object: nil)
                        }
                        else if physicalPoint.y >= PH / 2 && physicalPoint.y < 3 * PH / 4 {
                            print("Direct Click: Prev Page")
                            NotificationCenter.default.post(name: NSNotification.Name("PDFGoToPreviousPage"), object: nil)
                        }
                        else if physicalPoint.y >= 0 && physicalPoint.y < PH / 2 {
                            print("Direct Click: Next Page")
                            NotificationCenter.default.post(name: NSNotification.Name("PDFGoToNextPage"), object: nil)
                        }
                    }
                }
                return
            }
            
            // 2. Find the exact Cocoa view under the physical mouse cursor for Web/PDF/SwiftUI routing
            if let hitView = findTargetView(in: contentView, physicalPoint: physicalPoint) {
                let className = hitView.className
                
                // Pathway A: Native Cocoa Views (WKWebView, PDFView)
                // Forward the original physical event directly.
                if isNativeView(hitView) {
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
                let lx = isLeft ? physicalPoint.y : (PH - physicalPoint.y)
                let ly = isLeft ? (self.frame.width - physicalPoint.x) : physicalPoint.x
                
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
                    let shouldBypass = (className.contains("SwiftUI") || className.contains("Hosting")) && !className.contains("Text") && !className.contains("Field")
                    
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
            
        case .scrollWheel:
            guard let contentView = self.contentView else {
                super.sendEvent(event)
                return
            }
            
            let isLeft = UserDefaults.standard.bool(forKey: "isRotateLeftEnabled")
            let physicalPoint = event.locationInWindow
            if let hitView = findTargetView(in: contentView, physicalPoint: physicalPoint) {
                let className = hitView.className
                if className.contains("WK") || className.contains("PDF") || className.contains("Focusable") {
                    if let cgEvent = event.cgEvent?.copy() {
                        let dy = cgEvent.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                        let dx = cgEvent.getDoubleValueField(.scrollWheelEventDeltaAxis2)
                        
                        if isLeft {
                            // Rotate Left (90 CCW):
                            // Physical vertical scrolling -> physical horizontal (axis 2) with no sign inversion.
                            // Physical horizontal scrolling -> physical vertical (axis 1) with inversion.
                            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: -dx)
                            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: dy)
                            
                            // Also remap the higher resolution fixed point deltas (fields 93 and 94)
                            if let field93 = CGEventField(rawValue: 93), let field94 = CGEventField(rawValue: 94) {
                                let fdy = cgEvent.getDoubleValueField(field93)
                                let fdx = cgEvent.getDoubleValueField(field94)
                                cgEvent.setDoubleValueField(field93, value: -fdx)
                                cgEvent.setDoubleValueField(field94, value: fdy)
                            }
                        } else {
                            // Rotate Right (-90 CCW):
                            // Physical vertical scrolling -> physical horizontal (axis 2) with inversion.
                            // Physical horizontal scrolling -> physical vertical (axis 1).
                            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: dx)
                            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: -dy)
                            
                            // Also remap the higher resolution fixed point deltas (fields 93 and 94)
                            if let field93 = CGEventField(rawValue: 93), let field94 = CGEventField(rawValue: 94) {
                                let fdy = cgEvent.getDoubleValueField(field93)
                                let fdx = cgEvent.getDoubleValueField(field94)
                                cgEvent.setDoubleValueField(field93, value: fdx)
                                cgEvent.setDoubleValueField(field94, value: -fdy)
                            }
                        }
                        
                        if let remappedEvent = NSEvent(cgEvent: cgEvent) {
                            hitView.scrollWheel(with: remappedEvent)
                            return
                        }
                    }
                }
            }
            super.sendEvent(event)
            return
            
        default:
            break
        }

        if event.type == .keyDown {
            RotatedWindow.pressedKeys.insert(event.keyCode)
            
            // Check for simultaneous Left (123) + Right (124)
            let hasLeft = RotatedWindow.pressedKeys.contains(123)
            let hasRight = RotatedWindow.pressedKeys.contains(124)
            // Enter key (36 is Return, 76 is Numpad Enter)
            let isEnter = event.keyCode == 36 || event.keyCode == 76
            
            if (hasLeft && hasRight) || isEnter {
                if ActiveTabState.selectedTab == 1 {
                    // Cancel any scheduled single arrow navigation immediately if simultaneous press detected
                    RotatedWindow.pendingNavigationWorkItem?.cancel()
                    RotatedWindow.pendingNavigationWorkItem = nil
                    
                    print("Enter triggered (Simultaneous Left+Right, or Enter Key)")
                    NotificationCenter.default.post(name: NSNotification.Name("PDFTriggerEnterAction"), object: nil)
                    return
                }
            }
            
            // Left/Right Arrow key behavior with a 50ms debounce window to prevent off-by-one errors from simultaneous presses
            if event.keyCode == 123 { // Left Arrow
                RotatedWindow.pendingNavigationWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    if ActiveTabState.selectedTab == 1 {
                        if ActiveTabState.isSelectorModeActive {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFNavigateSelectionUp"), object: nil)
                        } else {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFGoToPreviousPage"), object: nil)
                        }
                    } else {
                        NotificationCenter.default.post(name: NSNotification.Name("TabNavigateLeft"), object: nil)
                    }
                }
                RotatedWindow.pendingNavigationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
                return
            }
            if event.keyCode == 124 { // Right Arrow
                RotatedWindow.pendingNavigationWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    if ActiveTabState.selectedTab == 1 {
                        if ActiveTabState.isSelectorModeActive {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFNavigateSelectionDown"), object: nil)
                        } else {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFGoToNextPage"), object: nil)
                        }
                    } else {
                        NotificationCenter.default.post(name: NSNotification.Name("TabNavigateRight"), object: nil)
                    }
                }
                RotatedWindow.pendingNavigationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
                return
            }
        } else if event.type == .keyUp {
            RotatedWindow.pressedKeys.remove(event.keyCode)
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
            if mods.contains(.command) && event.charactersIgnoringModifiers == "f" {
                self.toggleFullScreen(nil)
                return
            }
            if mods.contains(.control) && event.keyCode == 48 {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleTab"), object: nil)
                return
            }
            
            // Programmatic Page Scroll Shortcuts
            // Down Arrow (125) with Option, or Page Down (121)
            if (mods.contains(.option) && event.keyCode == 125) || event.keyCode == 121 {
                NotificationCenter.default.post(name: NSNotification.Name("ScrollBrowserDown"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("ScrollPDFDown"), object: nil)
                return
            }
            // Up Arrow (126) with Option, or Page Up (116)
            if (mods.contains(.option) && event.keyCode == 126) || event.keyCode == 116 {
                NotificationCenter.default.post(name: NSNotification.Name("ScrollBrowserUp"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("ScrollPDFUp"), object: nil)
                return
            }
            
            // Toggle Hardware Settings via Option Keys
            if mods.contains(.option) && event.charactersIgnoringModifiers?.lowercased() == "m" {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleRotatedMouse"), object: nil)
                return
            }
            if mods.contains(.option) && event.charactersIgnoringModifiers?.lowercased() == "l" {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleRotateLeft"), object: nil)
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
    var initialLogicalW: CGFloat = 0
    
    func setup() {
        if self.window != nil { return }
        
        NSApplication.shared.setActivationPolicy(.regular)
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let titleBarHeight: CGFloat = 28
        let logicalW = screenFrame.height - titleBarHeight
        let logicalH = screenFrame.width
        
        self.initialLogicalW = logicalW
        
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
        win.collectionBehavior = [.fullScreenPrimary, .managed]
        
        let container = RotatedContainerView(frame: NSRect(x: 0, y: 0, width: screenFrame.width, height: screenFrame.height))
        win.contentView = container
        
        let isLeft = UserDefaults.standard.bool(forKey: "isRotateLeftEnabled")
        let hostingView = RotatedHostingView(rootView: ContentView())
        
        hostingView.frame = NSRect(
            x: (screenFrame.width - logicalW) / 2,
            y: (screenFrame.height - titleBarHeight - logicalH) / 2,
            width: logicalW,
            height: logicalH
        )
        hostingView.frameCenterRotation = isLeft ? 90 : -90
        
        container.addSubview(hostingView)
        
        win.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            win.toggleFullScreen(nil)
        }
        
        // Auto-close any standard SwiftUI-generated windows to keep exactly one single RotatedWindow active
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                if !(window is RotatedWindow) {
                    window.close()
                }
            }
        }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !win.styleMask.contains(.fullScreen) {
                if win.level != .floating { win.level = .floating }
            }
            if NSApp.isActive && !win.isKeyWindow { win.makeKey() }
        }
     }
     
     func layoutViews() {
         guard let win = window,
               let container = win.contentView as? RotatedContainerView,
               let hostingView = container.subviews.first else { return }
         
         let containerFrame = container.bounds
         let isFullScreen = win.styleMask.contains(.fullScreen)
         let titleBarHeight: CGFloat = isFullScreen ? 0 : 28
         let isLeft = UserDefaults.standard.bool(forKey: "isRotateLeftEnabled")
         
         // Compute logical dimensions dynamically based on current container size
         let currentLogicalW = containerFrame.height - titleBarHeight
         let currentLogicalH = containerFrame.width
         
         // Safely update the frame of a rotated NSView in AppKit by resetting rotation first
         hostingView.frameCenterRotation = 0
         
         hostingView.frame = NSRect(
             x: (containerFrame.width - currentLogicalW) / 2,
             y: (containerFrame.height - titleBarHeight - currentLogicalH) / 2,
             width: currentLogicalW,
             height: currentLogicalH
         )
         
         hostingView.frameCenterRotation = isLeft ? 90 : -90
     }
    
    func windowDidResize(_ notification: Notification) {
        layoutViews()
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        layoutViews()
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        layoutViews()
    }
    
    func windowWillClose(_ notification: Notification) {
        print("RotatedWindow closing - terminating application")
        NSApplication.shared.terminate(nil)
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
        .commands {
            CommandGroup(replacing: .newItem) {
                // Completely removes standard "New Window" (Cmd+N)
            }
        }
    }
}
