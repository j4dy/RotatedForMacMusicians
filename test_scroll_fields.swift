import AppKit
print("CGEvent fields test")
let cgEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 10, wheel2: 5, wheel3: 0)!
print(cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1))
print(cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
print(cgEvent.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1))
