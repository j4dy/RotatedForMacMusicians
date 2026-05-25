import AppKit

let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
let accessEnabled = AXIsProcessTrustedWithOptions(options)
print("Accessibility enabled: \(accessEnabled)")

// Stay alive briefly so the prompt has time to appear and user can see it
if !accessEnabled {
    print("Please grant Accessibility permissions when prompted, then press Enter here.")
    _ = readLine()
}
