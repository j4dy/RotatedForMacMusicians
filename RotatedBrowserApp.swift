import SwiftUI
import AppKit

class RotatedWindow: NSWindow {
    static var pressedKeys = Set<UInt16>()
    static var pendingNavigationWorkItem: DispatchWorkItem?
    static var lastWarpPoint: NSPoint?
    static var activeCursorPos: CGPoint?
    
    // States for simultaneous double-press exit detection
    static var lastSimultaneousPressTime: Date = Date.distantPast
    static var isSimultaneousActive: Bool = false
    static var wasDoubleSimultaneous: Bool = false
    
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

    override func noResponder(for eventSelector: Selector) {
        if eventSelector == #selector(keyDown(with:)) {
            return
        }
        super.noResponder(for: eventSelector)
    }



    override func sendEvent(_ event: NSEvent) {
        if (ActiveTabState.selectedTab == 0 || ActiveTabState.selectedTab == 2) && ActiveTabState.isArrowNavigationActive {
            if let responder = self.firstResponder as? NSView, self.isNativeView(responder) {
                if !WebViewStore.isProgrammaticClick {
                    print("[DEBUG] Webview has focus in browser arrow navigation mode. Resigning focus to window.")
                    self.makeFirstResponder(nil)
                }
            }
        }
        // Programmatic Warp Event Intercept: Ignore events synthesized by our own cursor warping to break the runaway feedback loop
        let currentPoint = NSEvent.mouseLocation
        if let lastWarp = RotatedWindow.lastWarpPoint {
            let distance = hypot(currentPoint.x - lastWarp.x, currentPoint.y - lastWarp.y)
            if distance < 1.5 {
                RotatedWindow.lastWarpPoint = nil
                super.sendEvent(event)
                return
            }
        }

        // Rotated Mouse Option: Remap physical mouse movement deltas to align with rotated view orientation
        let isRotatedMouse = UserDefaults.standard.bool(forKey: "isRotatedMouseEnabled")
        if isRotatedMouse && (event.type == .mouseMoved || event.type == .leftMouseDragged || event.type == .rightMouseDragged || event.type == .otherMouseDragged) {
            let mouseLoc = event.locationInWindow
            let windowFrame = self.frame
            
            // Constrain remapping strictly to when the mouse cursor is physically within this NSWindow
            let isInsideWindow = mouseLoc.x >= 0 && mouseLoc.x <= windowFrame.width &&
                                 mouseLoc.y >= 0 && mouseLoc.y <= windowFrame.height
            
            if self.isKeyWindow && isInsideWindow {
                let dx = event.deltaX
                let dy = event.deltaY
                if dx != 0 || dy != 0 {
                    let isLeft = UserDefaults.standard.bool(forKey: "isRotateLeftEnabled")
                    if let primaryScreen = NSScreen.screens.first {
                        let primaryHeight = primaryScreen.frame.height
                        let cgCurrent = CGPoint(x: currentPoint.x, y: primaryHeight - currentPoint.y)
                        
                        // Initialize running cursor position on first movement in the window
                        let basePos = RotatedWindow.activeCursorPos ?? cgCurrent
                        
                        let rotatedDX: CGFloat
                        let rotatedDY: CGFloat
                        if isLeft {
                            rotatedDX = dy
                            rotatedDY = -dx
                        } else {
                            rotatedDX = -dy
                            rotatedDY = dx
                        }
                        
                        // Accumulate deltas directly onto the baseline, completely bypassing unrotated system displacement!
                        let warpX = basePos.x + rotatedDX
                        let warpY = basePos.y + rotatedDY
                        
                        let newCGPos = CGPoint(x: warpX, y: warpY)
                        RotatedWindow.activeCursorPos = newCGPos
                        
                        // Convert back to AppKit coordinates to identify and ignore the subsequent synthesized event
                        let warpAppKit = CGPoint(x: warpX, y: primaryHeight - warpY)
                        RotatedWindow.lastWarpPoint = warpAppKit
                        
                        CGWarpMouseCursorPosition(newCGPos)
                    }
                }
            } else {
                // Reset baseline when cursor leaves the window bounds so it resyncs perfectly next time it enters
                RotatedWindow.activeCursorPos = nil
            }
        } else if isRotatedMouse {
            // Reset baseline on non-movement events
            RotatedWindow.activeCursorPos = nil
        }

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
            
            let hostingView = contentView.subviews.first
            let hit = contentView.hitTest(physicalPoint)
            

            if let hosting = hostingView, hit == hosting {
                // Pathway B: Pure SwiftUI Views
                // Translate physical coordinate to logical space and forward to NSHostingView
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
                    EventForwardingState.isForwardingEvent = true
                    defer { EventForwardingState.isForwardingEvent = false }
                    
                    if event.type == .leftMouseDown { hosting.mouseDown(with: translatedEvent) }
                    else if event.type == .leftMouseUp { hosting.mouseUp(with: translatedEvent) }
                    else if event.type == .rightMouseDown { hosting.rightMouseDown(with: translatedEvent) }
                    else if event.type == .rightMouseUp { hosting.rightMouseUp(with: translatedEvent) }
                    else if event.type == .otherMouseDown { hosting.otherMouseDown(with: translatedEvent) }
                    else if event.type == .otherMouseUp { hosting.otherMouseUp(with: translatedEvent) }
                    else if event.type == .mouseMoved { hosting.mouseMoved(with: translatedEvent) }
                    else if event.type == .leftMouseDragged { hosting.mouseDragged(with: translatedEvent) }
                    else if event.type == .rightMouseDragged { hosting.rightMouseDragged(with: translatedEvent) }
                    else if event.type == .otherMouseDragged { hosting.otherMouseDragged(with: translatedEvent) }
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
            
            if (ActiveTabState.selectedTab == 0 || ActiveTabState.selectedTab == 2) && ActiveTabState.isArrowNavigationActive {
                if hasLeft && hasRight {
                    RotatedWindow.pendingNavigationWorkItem?.cancel()
                    RotatedWindow.pendingNavigationWorkItem = nil
                    
                    if !RotatedWindow.isSimultaneousActive {
                        RotatedWindow.isSimultaneousActive = true
                        let now = Date()
                        if now.timeIntervalSince(RotatedWindow.lastSimultaneousPressTime) < 0.25 {
                            // Double simultaneous press detected! Exit browse mode.
                            print("[DEBUG] Double simultaneous press detected: Exiting browser arrow navigation.")
                            NotificationCenter.default.post(name: NSNotification.Name("BrowserExitArrowNavigation"), object: nil)
                            RotatedWindow.wasDoubleSimultaneous = true
                            RotatedWindow.lastSimultaneousPressTime = .distantPast
                        } else {
                            RotatedWindow.wasDoubleSimultaneous = false
                            RotatedWindow.lastSimultaneousPressTime = now
                        }
                    }
                    return
                }
                
                if isEnter {
                    RotatedWindow.pendingNavigationWorkItem?.cancel()
                    RotatedWindow.pendingNavigationWorkItem = nil
                    
                    if !event.isARepeat {
                        print("[DEBUG] Browser Arrow Mode Click triggered via Enter")
                        NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorClick"), object: nil)
                    }
                    return
                }
                
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if !mods.contains(.option) && !mods.contains(.command) {
                    if event.keyCode == 123 { // Left Arrow
                        if event.isARepeat {
                            NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorMoveLeft"), object: true)
                        } else {
                            RotatedWindow.pendingNavigationWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorMoveLeft"), object: false)
                            }
                            RotatedWindow.pendingNavigationWorkItem = workItem
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
                        }
                        return
                    } else if event.keyCode == 124 { // Right Arrow
                        if event.isARepeat {
                            NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorMoveRight"), object: true)
                        } else {
                            RotatedWindow.pendingNavigationWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorMoveRight"), object: false)
                            }
                            RotatedWindow.pendingNavigationWorkItem = workItem
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
                        }
                        return
                    } else if event.keyCode == 125 { // Down Arrow
                        NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorMoveDown"), object: nil)
                        return
                    } else if event.keyCode == 126 { // Up Arrow
                        NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorMoveUp"), object: nil)
                        return
                    }
                }
            } else {
                var shouldInterceptEnter = true
                if isEnter {
                    if let responder = self.firstResponder as? NSView {
                        let className = responder.className
                        if self.isNativeView(responder) || className.contains("TextField") || className.contains("NSText") {
                            shouldInterceptEnter = false
                        }
                    }
                }
                if (hasLeft && hasRight) || (isEnter && shouldInterceptEnter) {
                    if ActiveTabState.selectedTab == 1 {
                        // Cancel any scheduled single arrow navigation immediately if simultaneous press detected
                        RotatedWindow.pendingNavigationWorkItem?.cancel()
                        RotatedWindow.pendingNavigationWorkItem = nil
                        
                        print("Enter triggered (Simultaneous Left+Right, or Enter Key)")
                        NotificationCenter.default.post(name: NSNotification.Name("PDFTriggerEnterAction"), object: nil)
                        return
                    } else if ActiveTabState.selectedTab == 0 || ActiveTabState.selectedTab == 2 {
                        RotatedWindow.pendingNavigationWorkItem?.cancel()
                        RotatedWindow.pendingNavigationWorkItem = nil
                        
                        print("Enter triggered on Browser/Settings: enabling arrow navigation")
                        NotificationCenter.default.post(name: NSNotification.Name("BrowserTriggerEnterAction"), object: nil)
                        return
                    }
                }
            }
            
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCommand = mods.contains(.command)

            // Left/Right Arrow key behavior
            if event.keyCode == 123 { // Left Arrow
                if let responder = self.firstResponder as? NSView,
                   responder.className.contains("TextField") || responder.className.contains("NSText") {
                    super.sendEvent(event)
                    return
                }
                RotatedWindow.pendingNavigationWorkItem?.cancel()
                
                let workItem = DispatchWorkItem {
                    if isCommand {
                        NotificationCenter.default.post(name: NSNotification.Name("TabNavigateLeft"), object: nil)
                    } else if ActiveTabState.selectedTab == 1 && ActiveTabState.isArrowNavigationActive {
                        if ActiveTabState.isSelectorModeActive {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFNavigateSelectionUp"), object: nil)
                        } else if ActiveTabState.isCurrentImage {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFImageGoToPrevious"), object: nil)
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
                if let responder = self.firstResponder as? NSView,
                   responder.className.contains("TextField") || responder.className.contains("NSText") {
                    super.sendEvent(event)
                    return
                }
                RotatedWindow.pendingNavigationWorkItem?.cancel()
                
                let workItem = DispatchWorkItem {
                    if isCommand {
                        NotificationCenter.default.post(name: NSNotification.Name("TabNavigateRight"), object: nil)
                    } else if ActiveTabState.selectedTab == 1 && ActiveTabState.isArrowNavigationActive {
                        if ActiveTabState.isSelectorModeActive {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFNavigateSelectionDown"), object: nil)
                        } else if ActiveTabState.isCurrentImage {
                            NotificationCenter.default.post(name: NSNotification.Name("PDFImageGoToNext"), object: nil)
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
            
            if event.keyCode == 123 || event.keyCode == 124 {
                if RotatedWindow.isSimultaneousActive {
                    // One of the keys was released, so simultaneous press is no longer active
                    RotatedWindow.isSimultaneousActive = false
                    
                    if !RotatedWindow.wasDoubleSimultaneous {
                        if (ActiveTabState.selectedTab == 0 || ActiveTabState.selectedTab == 2) && ActiveTabState.isArrowNavigationActive {
                            print("[DEBUG] Simultaneous Left+Right released: Triggering click.")
                            NotificationCenter.default.post(name: NSNotification.Name("BrowserCursorClick"), object: nil)
                        }
                    }
                }
            }
            
            // Intercept Arrow Key and Enter releases when browser arrow navigation is active to prevent beeps or weird default web navigation behaviors
            if (ActiveTabState.selectedTab == 0 || ActiveTabState.selectedTab == 2) && ActiveTabState.isArrowNavigationActive {
                if event.keyCode == 123 || event.keyCode == 124 || event.keyCode == 125 || event.keyCode == 126 || event.keyCode == 36 || event.keyCode == 76 {
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
            if mods.contains(.command) && event.charactersIgnoringModifiers == "f" {
                self.toggleFullScreen(nil)
                return
            }
            if mods.contains(.command) && event.charactersIgnoringModifiers == "w" {
                self.close()
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
            
            if mods.contains(.option) && event.charactersIgnoringModifiers?.lowercased() == "m" {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleRotatedMouse"), object: nil)
                return
            }
            if mods.contains(.option) && event.charactersIgnoringModifiers?.lowercased() == "l" {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleRotateLeft"), object: nil)
                return
            }
            if mods.contains(.option) && event.charactersIgnoringModifiers?.lowercased() == "o" {
                NotificationCenter.default.post(name: NSNotification.Name("TriggerPDFBrowse"), object: nil)
                return
            }
            if mods.contains(.option) && event.charactersIgnoringModifiers?.lowercased() == "r" {
                NotificationCenter.default.post(name: NSNotification.Name("BrowserReloadURL"), object: nil)
                return
            }
            if mods.contains(.option) && event.charactersIgnoringModifiers?.lowercased() == "b" {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleAdBlocker"), object: nil)
                return
            }
        }
        
        // Keyboard passthrough to ensure WKWebView gets the events directly when rotated
        if event.type == .keyDown || event.type == .keyUp {
            if let responder = self.firstResponder as? NSView {
                let className = responder.className
                if self.isNativeView(responder) || className.contains("TextField") || className.contains("NSText") {
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
        guard let window = self.window as? RotatedWindow else {
            return super.hitTest(point)
        }
        guard let target = window.findTargetView(in: self, physicalPoint: point) else {
            return nil
        }
        var current: NSView? = target
        while let v = current {
            let name = v.className
            if name.contains("WK") || name.contains("PDF") || name.contains("Text") || name.contains("Field") || name.contains("Switch") || name.contains("Button") || name.contains("Slider") {
                return target
            }
            current = v.superview
        }
        return self.subviews.first ?? target
    }
}

struct EventForwardingState {
    static var isForwardingEvent = false
}

class RotatedHostingView<Content: View>: NSHostingView<Content> {
    override func convert(_ point: NSPoint, from view: NSView?) -> NSPoint {
        if EventForwardingState.isForwardingEvent && view == nil {
            return point
        }
        return super.convert(point, from: view)
    }

    override func convert(_ point: NSPoint, to view: NSView?) -> NSPoint {
        if EventForwardingState.isForwardingEvent && view == nil {
            return point
        }
        return super.convert(point, to: view)
    }

    override func convert(_ rect: NSRect, from view: NSView?) -> NSRect {
        if EventForwardingState.isForwardingEvent && view == nil {
            return rect
        }
        return super.convert(rect, from: view)
    }

    override func convert(_ rect: NSRect, to view: NSView?) -> NSRect {
        if EventForwardingState.isForwardingEvent && view == nil {
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
        container.wantsLayer = true
        win.contentView = container
        
        let isLeft = UserDefaults.standard.bool(forKey: "isRotateLeftEnabled")
        let hostingView = RotatedHostingView(rootView: ContentView())
        hostingView.wantsLayer = true
        
        hostingView.frame = NSRect(
            x: (screenFrame.width - logicalW) / 2,
            y: (screenFrame.height - titleBarHeight - logicalH) / 2,
            width: logicalW,
            height: logicalH
        )
        hostingView.frameCenterRotation = isLeft ? 90 : -90
        
        container.addSubview(hostingView)
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BrowserTriggerEnterAction"),
            object: nil,
            queue: .main
        ) { _ in
            print("[DEBUG] BrowserTriggerEnterAction notification: resigning first responder focus")
            win.makeFirstResponder(nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BrowserExitArrowNavigation"),
            object: nil,
            queue: .main
        ) { _ in
            RotatedWindow.pressedKeys.removeAll()
            RotatedWindow.isSimultaneousActive = false
            RotatedWindow.wasDoubleSimultaneous = false
            print("[DEBUG] Exited browser arrow navigation: resigning first responder focus and clearing pressedKeys")
            win.makeFirstResponder(nil)
        }
        
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
        setbuf(stdout, nil)
        NSApplication.shared.setActivationPolicy(.regular)
        AppAnalytics.shared.trackEvent(name: "app_launch", parameters: ["event_category": "Lifecycle"])
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
