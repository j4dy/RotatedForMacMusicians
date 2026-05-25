import AppKit
print("test")

func modify(event: NSEvent) -> NSEvent? {
    if let cgEvent = event.cgEvent?.copy() {
        cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 10)
        cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 5)
        return NSEvent(cgEvent: cgEvent)
    }
    return nil
}
