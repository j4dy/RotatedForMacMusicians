import SwiftUI
import PDFKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var lastClick: CGPoint = .zero
    
    // Persistent AppStorage Settings
    @AppStorage("defaultURL") private var defaultURL: String = "https://www.google.com"
    @AppStorage("defaultPDFLocation") private var defaultPDFLocation: String = ""
    @AppStorage("isRotatedMouseEnabled") private var isRotatedMouseEnabled: Bool = false
    
    // Helper to dynamically resolve default Browser URL safely
    var parsedURL: URL {
        if let url = URL(string: defaultURL), url.scheme != nil {
            return url
        }
        // Fallback to google if invalid
        return URL(string: "https://www.google.com")!
    }
    
    // Helper to dynamically resolve local PDF path/URL safely
    var parsedPDFURL: URL? {
        if defaultPDFLocation.isEmpty { return nil }
        if defaultPDFLocation.hasPrefix("file://") {
            return URL(string: defaultPDFLocation)
        }
        return URL(fileURLWithPath: defaultPDFLocation)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main Content Area
                ZStack {
                    if selectedTab == 0 {
                        WebView(url: parsedURL)
                            .id("tab-0")
                    } else if selectedTab == 1 {
                        ZStack {
                            Color.blue.opacity(0.05)
                            PDFViewWrapper(url: parsedPDFURL)
                            
                            if parsedPDFURL == nil {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 64))
                                        .foregroundColor(.blue.opacity(0.6))
                                    Text("No PDF Document Loaded")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.blue)
                                    Text("Configure a default file in Setting (⌘3)")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .id("tab-1")
                    } else {
                        SettingsView(
                            defaultURL: $defaultURL,
                            defaultPDFLocation: $defaultPDFLocation,
                            isRotatedMouseEnabled: $isRotatedMouseEnabled
                        )
                        .id("tab-2")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                
                // Partitioned Tab Navigation Bar
                Divider()
                HStack(spacing: 20) {
                    // Tab 0: Browser Button
                    Button(action: { 
                        selectedTab = 0 
                        print("Switched to Browser")
                    }) {
                        Text("Browser (⌘1)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedTab == 0 ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // Tab 1: PDF Button
                    Button(action: { 
                        selectedTab = 1 
                        print("Switched to PDF")
                    }) {
                        Text("PDF (⌘2)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedTab == 1 ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // Tab 2: Setting Button
                    Button(action: { 
                        selectedTab = 2 
                        print("Switched to Setting")
                    }) {
                        Text("Setting (⌘3)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedTab == 2 ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color(NSColor.windowBackgroundColor))
            }
            
            // Debug Click Indicator (Green Dot)
            if lastClick != .zero {
                Circle()
                    .fill(Color.green)
                    .frame(width: 40, height: 40)
                    .position(lastClick)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .opacity(0.7)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToBrowser"))) { _ in
            selectedTab = 0
            print("Switched to Browser via shortcut")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToPDF"))) { _ in
            selectedTab = 1
            print("Switched to PDF via shortcut")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToSetting"))) { _ in
            selectedTab = 2
            print("Switched to Setting via shortcut")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleTab"))) { _ in
            selectedTab = (selectedTab + 1) % 3
            print("Toggled tab via shortcut to: \(selectedTab)")
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            self.lastClick = location
            print("Detected Tap at: \(location)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if self.lastClick == location { self.lastClick = .zero }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Premium Settings View Sub-component
struct SettingsView: View {
    @Binding var defaultURL: String
    @Binding var defaultPDFLocation: String
    @Binding var isRotatedMouseEnabled: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("Settings")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.primary)
                    .padding(.bottom, 5)
                
                // 1st Section: Browser Setting
                SettingsCard(title: "Browser Setting", icon: "safari") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Default Homepage URL")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("Enter default URL (e.g., https://www.wikipedia.org)", text: $defaultURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                // 2nd Section: PDF Setting
                SettingsCard(title: "PDF Setting", icon: "doc.text") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Default PDF Document Location")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            TextField("Absolute local path or file:// URL", text: $defaultPDFLocation)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            Button(action: {
                                selectPDFFile()
                            }) {
                                Text("Browse...")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // 3rd Section: Hardware Setting
                SettingsCard(title: "Hardware Setting", icon: "cpu") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $isRotatedMouseEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rotated Mouse")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Remap standard physical mouse coordinates to logically rotated space (Placeholder mockup).")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
            }
            .padding(30)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }
    
    // Natively choose a PDF file path from macOS file browser
    private func selectPDFFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Default PDF Document"
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            if let fileURL = openPanel.url {
                defaultPDFLocation = fileURL.path
            }
        }
    }
}

// MARK: - Premium Settings Card Component
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            Divider()
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}
