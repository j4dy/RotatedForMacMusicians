import AppKit
import CoreGraphics

var isWarping = false

func createEventTap() {
    let eventMask = (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)
    let eventsOfInterest = CGEventMask(eventMask)
    
    guard let eventTap = CGEvent.tapCreate(
        tap: .cghidEventTap, // Catch events as early as possible
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventsOfInterest,
        callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            if isWarping {
                return Unmanaged.passRetained(event)
            }
            
            // Get raw delta
            let dx = event.getDoubleValueField(.mouseEventDeltaX)
            let dy = event.getDoubleValueField(.mouseEventDeltaY)
            
            if dx == 0 && dy == 0 {
                return Unmanaged.passRetained(event)
            }
            
            // Apply 90 degree clockwise rotation to the movement delta
            let newDx = -dy
            let newDy = dx
            
            var currentPos = CGEvent(source: nil)!.location
            currentPos.x += CGFloat(newDx)
            currentPos.y += CGFloat(newDy)
            
            isWarping = true
            CGWarpMouseCursorPosition(currentPos)
            isWarping = false
            
            return nil
        },
        userInfo: nil
    ) else {
        print("Failed to create event tap.")
        exit(1)
    }
    
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    
    // CGEvent.tapEnable requires a CFMachPort
    CGEvent.tapEnable(tap: eventTap, enable: true)
    
    print("Event tap active for 10 seconds. Move your mouse to see rotational movement.")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
        print("Test complete.")
        exit(0)
    }
    
    CFRunLoopRun()
}

createEventTap()
