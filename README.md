# Vecto (for Mac Musicians)

A premium, native macOS application designed to display a web browser and a PDF viewer rotated by **90 degrees** (Landscape to Portrait). 

### Pivot your display. Realign your Mac.

Because MacBooks do not have built-in monitor rotation capabilities, Vecto allows you to rotate your sheet music, chord charts, or reference displays onto a physically pivoted external monitor while macOS remains in its default landscape layout. It is tailored for musicians, live performers, and kiosk setups, and is fully optimized for remote control using a standard Bluetooth mouse, a page-turner pedal, or a compact Bluetooth 2-button keyset.

### Why is it called Vecto?
The name **Vecto** is derived from *vector*, representing direction and magnitude. In mathematics and physics, vectors define heading and coordinate translation. Because the app dynamically redirects input coordinate vectors and realigns physical screen layouts to match your rotated display, Vecto perfectly embodies this alignment transformation.


## Documentation, Downloads & Demos

* 📺 **[Watch the Demo Video on YouTube](https://www.youtube.com/watch?v=gm6q1teM_zw)**
* 👉 **[Documentation & Landing Page](https://j4dy.github.io/Vecto/)**

---

## Key Features

* **Visual Rotation Consistency**: visual layout is rotated 90 degrees CW using native center-rotation mechanisms.
* **Hybrid Coordinate & Mouse Routing**:
  * **Cocoa Views** (`WKWebView`, `PDFView`, and descendants): Intercepts and forwards clicks/drags directly to bypass WebKit's window-dispatch rotated coordinate bug.
  * **SwiftUI Controls** (like Tab buttons): Lets standard mouse events fall through to `super.sendEvent`, ensuring AppKit's native rotation-aware conversion maps coordinates for hover states and SwiftUI gestures perfectly.
* **Scroll Wheel Alignment**: Swaps scroll wheel axis inputs dynamically so pushing a scroll wheel physically forward moves content in the expected logical direction.
* **Keyboard Passthrough Pipeline**: Includes a surgical focus acquisition wrapper ensuring key inputs (like typing search terms or notes) are fed directly into the active browser fields without losing focus.
* **Always-on-Top Floating Window**: Configured to float frontmost over all other apps (ideal for overlaying sheet music, chord charts, or reference displays).
* **Keyboard Shortcuts**:
  * `Cmd + 1`: Switch to Web Browser Tab
  * `Cmd + 2`: Switch to PDF Viewer Tab
  * `Ctrl + Tab`: Toggle between active tabs
  * `Opt + O`: Open macOS native PDF File Browser

---

## File Structure

* **[RotatedBrowserApp.swift](RotatedBrowserApp.swift)**: Contains the `RotatedWindow` subclass (scroll/key mapping, subview forwarding, shortcut routing) and the launch/floating configuration.
* **[ContentView.swift](ContentView.swift)**: Holds the visual tab container, button layouts, and switch notification observers.
* **[WebView.swift](WebView.swift)**: Custom wrapper around `WKWebView` that explicitly enforces first responder status on clicks to capture key events securely.
* **[PDFViewWrapper.swift](PDFViewWrapper.swift)**: Native wrapper around `PDFView` to handle auto-scaling of document inputs.
* **[Package.swift](Package.swift)**: Standard Swift Package Manager configuration, making the codebase directly compatible with Xcode and standalone swiftc compiler tools.

---

## Getting Started

### Prerequisites
* macOS 14.0 or later
* Swift 5.9+ compiler tools (Xcode CommandLine Tools)

### Build and Run via Terminal
We include a simple compilation script to build and execute the application locally:

```bash
# Set execution permission on build script
chmod +x build_and_run.sh

# Compile and launch the application
./build_and_run.sh
```

### Xcode Setup
Since the repository is structured as a Swift Package Manager executable, you can open the project directly inside Xcode:
1. Open Xcode and select **File > Open**.
2. Select the directory containing `Package.swift`.
3. Choose the `net.j4dy.Vecto` scheme and click **Run** (⌘R).

---

## macOS Security Gatekeeper Troubleshooting

Since this beta build is not code-signed using a paid Apple Developer Account, Gatekeeper may block launch or warn that the application file is "damaged" upon installation.

### Override via Context Menu
1. In Finder, locate `Vecto` inside `/Applications` or your target folder.
2. **Right-click** (or Control-click) the application icon and choose **Open** from the context menu.
3. In the dialog, click **Open** again to confirm.

### Override via Terminal
Alternatively, you can strip the system quarantine flag off the application bundle by running this command:
```bash
xattr -d com.apple.quarantine /Applications/Vecto.app
```
