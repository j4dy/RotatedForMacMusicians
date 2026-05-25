import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var lastClick: CGPoint = .zero
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main Content
                ZStack {
                    if selectedTab == 0 {
                        WebView(url: URL(string: "https://www.google.com")!)
                            .id("tab-0")
                    } else {
                        ZStack {
                            Color.blue.opacity(0.1)
                            PDFViewWrapper(url: nil)
                            VStack {
                                Text("PDF Tab Area")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.blue)
                                Text("Nuclear Option v2 Active")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            }
                        }
                        .id("tab-1")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                
                // Navigation Bar
                Divider()
                HStack(spacing: 20) {
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
                }
                .padding(20)
                .background(Color(NSColor.windowBackgroundColor))
            }
            
            // Debug Click Indicator (Green Dot - Nuclear Success!)
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleTab"))) { _ in
            selectedTab = selectedTab == 0 ? 1 : 0
            print("Toggled tab via shortcut")
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
