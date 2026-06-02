import SwiftUI
import PDFKit

struct ActiveTabState {
    static var selectedTab: Int = 0
    static var isSelectorModeActive: Bool = true
    static var isArrowNavigationActive: Bool = false
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var lastClick: CGPoint = .zero
    @State private var pdfCurrentPageIndex: Int = 0
    @State private var pdfTotalPageCount: Int = 0
    
    // Persistent AppStorage Settings
    @AppStorage("defaultURL") private var defaultURL: String = "https://www.google.com"
    @AppStorage("defaultPDFLocation") private var defaultPDFLocation: String = ""
    @AppStorage("isRotatedMouseEnabled") private var isRotatedMouseEnabled: Bool = false
    @AppStorage("isRotateLeftEnabled") private var isRotateLeftEnabled: Bool = false
    
    @State private var selectedPDFFileURL: URL? = nil
    @State private var isShowingDirectorySelector = false
    @State private var directorySelectedIndex = 0
    @State private var directoryPage = 0
    let pdfPageSize = 12
    @State private var isBrowserLoading = false
    @State private var isBrowserArrowNavigationActive = false
    
    // Helper to dynamically resolve default Browser URL safely
    var parsedURL: URL {
        if let url = URL(string: defaultURL), url.scheme != nil {
            return url
        }
        // Fallback to google if invalid
        return URL(string: "https://www.google.com")!
    }
    
    // Helper to dynamically resolve the active PDF URL for display
    var activePDFURL: URL? {
        if let selected = selectedPDFFileURL {
            return selected
        }
        
        if defaultPDFLocation.isEmpty { return nil }
        let path = defaultPDFLocation.replacingOccurrences(of: "file://", with: "")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            print("PDF File does not exist at path: \(path)")
            return nil
        }
        
        if !isDir.boolValue {
            return URL(fileURLWithPath: path)
        }
        
        return nil // If it's a directory, return nil by default so we show the Directory Selection Mode!
    }
    
    // Helper to list all PDF files in the default PDF folder/directory
    var pdfFiles: [URL] {
        if defaultPDFLocation.isEmpty { return [] }
        let path = defaultPDFLocation.replacingOccurrences(of: "file://", with: "")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return [] }
        
        var dirPath = path
        if !isDir.boolValue {
            dirPath = (path as NSString).deletingLastPathComponent
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
            return contents
                .filter { $0.lowercased().hasSuffix(".pdf") }
                .sorted()
                .map { URL(fileURLWithPath: (dirPath as NSString).appendingPathComponent($0)) }
        } catch {
            print("Error listing PDFs in directory: \(error)")
            return []
        }
    }

    // Helper to compute total pages of the directory browser files
    var totalPages: Int {
        let count = pdfFiles.count
        if count == 0 { return 1 }
        return Int(ceil(Double(count) / Double(pdfPageSize)))
    }

    // Get the paged subset of PDF files
    var pagedPDFFiles: [URL] {
        let allFiles = pdfFiles
        if allFiles.isEmpty { return [] }
        let startIndex = min(directoryPage * pdfPageSize, allFiles.count)
        let endIndex = min(startIndex + pdfPageSize, allFiles.count)
        if startIndex >= endIndex { return [] }
        return Array(allFiles[startIndex..<endIndex])
    }

    // Returns if Previous Page button is visible on current screen
    var hasPrevPage: Bool {
        return directoryPage > 0
    }

    // Returns if Next Page button is visible on current screen
    var hasNextPage: Bool {
        return directoryPage < totalPages - 1
    }

    // Returns total count of interactive rows on current selector screen
    var totalSelectableItemsCount: Int {
        var count = 1 + pagedPDFFiles.count // 1 Back button + files
        if hasPrevPage { count += 1 }
        if hasNextPage { count += 1 }
        return count
    }

    var prevPageIndex: Int? {
        if hasPrevPage {
            return 1 + pagedPDFFiles.count
        }
        return nil
    }

    var nextPageIndex: Int? {
        if hasNextPage {
            return 1 + pagedPDFFiles.count + (hasPrevPage ? 1 : 0)
        }
        return nil
    }

    private func goToPrevPage() {
        if directoryPage > 0 {
            directoryPage -= 1
            directorySelectedIndex = 0
            print("Went to previous page: \(directoryPage)")
        }
    }

    private func goToNextPage() {
        if directoryPage < totalPages - 1 {
            directoryPage += 1
            directorySelectedIndex = 0
            print("Went to next page: \(directoryPage)")
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main Content Area
                ZStack {
                    if selectedTab == 0 {
                        // Tab 0: Browser View
                        ZStack {
                            WebView(url: parsedURL, isLoading: $isBrowserLoading)
                                .id("tab-0")
                            
                            if isBrowserLoading {
                                ZStack {
                                    Color.black.opacity(0.3)
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.5)
                                        Text("Loading Page...")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(24)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(16)
                                }
                            }
                            
                            if isBrowserArrowNavigationActive {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            isBrowserArrowNavigationActive = false
                                            ActiveTabState.isArrowNavigationActive = false
                                            print("Exit Browser Mode clicked: arrow navigation disabled")
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "arrow.left.circle.fill")
                                                    .font(.system(size: 16, weight: .bold))
                                                Text("Exit Browser Mode")
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.red.opacity(0.9))
                                            .foregroundColor(.white)
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.trailing, 24)
                                        .padding(.bottom, 24)
                                    }
                                }
                            }
                        }
                    } else if selectedTab == 1 {
                        // Tab 1: PDF Viewer & Selection Mode
                        VStack(spacing: 0) {
                            if let pdfURL = activePDFURL, !isShowingDirectorySelector {
                                PDFViewWrapper(
                                    url: pdfURL,
                                    currentPageIndex: $pdfCurrentPageIndex,
                                    totalPageCount: $pdfTotalPageCount
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                // Premium Super-Compact Control Bar
                                HStack(spacing: 24) {
                                    // Folder List Button to return to selection mode
                                    Button(action: {
                                        isShowingDirectorySelector = true
                                    }) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.white.opacity(0.15))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Previous Page Button
                                    Button(action: {
                                        NotificationCenter.default.post(name: NSNotification.Name("PDFGoToPreviousPage"), object: nil)
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(pdfCurrentPageIndex > 0 ? .white : .white.opacity(0.3))
                                            .padding(6)
                                            .background(pdfCurrentPageIndex > 0 ? Color.blue.opacity(0.7) : Color.clear)
                                            .clipShape(Circle())
                                    }
                                    .disabled(pdfCurrentPageIndex <= 0)
                                    .buttonStyle(.plain)
                                    
                                    // Page Counter
                                    Text("\(pdfTotalPageCount > 0 ? pdfCurrentPageIndex + 1 : 0) / \(pdfTotalPageCount)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                    
                                    // Next Page Button
                                    Button(action: {
                                        NotificationCenter.default.post(name: NSNotification.Name("PDFGoToNextPage"), object: nil)
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(pdfCurrentPageIndex < pdfTotalPageCount - 1 ? .white : .white.opacity(0.3))
                                            .padding(6)
                                            .background(pdfCurrentPageIndex < pdfTotalPageCount - 1 ? Color.blue.opacity(0.7) : Color.clear)
                                            .clipShape(Circle())
                                    }
                                    .disabled(pdfCurrentPageIndex >= pdfTotalPageCount - 1)
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    // Active PDF File Name display
                                    Text(pdfURL.lastPathComponent)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(6)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(0.85))
                            } else {
                                // Directory File Selection Mode or Empty State
                                DirectorySelectorView(
                                    folderPath: defaultPDFLocation.isEmpty ? "No Folder Configured" : defaultPDFLocation,
                                    files: pagedPDFFiles,
                                    selectedIndex: $directorySelectedIndex,
                                    hasPrevPage: hasPrevPage,
                                    hasNextPage: hasNextPage,
                                    totalPages: totalPages,
                                    currentPage: directoryPage,
                                    onPrevPage: {
                                        goToPrevPage()
                                    },
                                    onNextPage: {
                                        goToNextPage()
                                    },
                                    onSelect: { fileURL in
                                        selectedPDFFileURL = fileURL
                                        isShowingDirectorySelector = false
                                    },
                                    onBack: {
                                        ActiveTabState.isArrowNavigationActive = false
                                        print("Back selected: Returned arrow keys focus to tab cycling")
                                    }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .id("tab-1")
                    } else {
                        // Tab 2: Settings View
                        SettingsView(
                            defaultURL: $defaultURL,
                            defaultPDFLocation: $defaultPDFLocation,
                            isRotatedMouseEnabled: $isRotatedMouseEnabled,
                            isRotateLeftEnabled: $isRotateLeftEnabled
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TabNavigateLeft"))) { _ in
            selectedTab = (selectedTab - 1 + 3) % 3
            print("Navigated Tab Left via arrow to: \(selectedTab)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TabNavigateRight"))) { _ in
            selectedTab = (selectedTab + 1) % 3
            print("Navigated Tab Right via arrow to: \(selectedTab)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleTab"))) { _ in
            selectedTab = (selectedTab + 1) % 3
            print("Toggled tab via shortcut to: \(selectedTab)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleRotatedMouse"))) { _ in
            isRotatedMouseEnabled.toggle()
            print("Toggled Rotated Mouse via shortcut: \(isRotatedMouseEnabled)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleRotateLeft"))) { _ in
            isRotateLeftEnabled.toggle()
            print("Toggled Rotate Left via shortcut: \(isRotateLeftEnabled)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PDFTriggerEnterAction"))) { _ in
            if selectedTab == 1 {
                if !ActiveTabState.isArrowNavigationActive {
                    // First Enter: Lock arrow keys to navigate the selection list
                    ActiveTabState.isArrowNavigationActive = true
                    print("Enter Triggered: Arrow navigation enabled for PDF Selection List")
                } else if isShowingDirectorySelector || activePDFURL == nil {
                    // Second Enter (inside selection mode)
                    if directorySelectedIndex == 0 {
                        // "Return to Tab Navigation" option selected
                        ActiveTabState.isArrowNavigationActive = false
                        print("Enter Triggered: Selected Back button, arrows reset to tab cycling")
                    } else if let prevIndex = prevPageIndex, directorySelectedIndex == prevIndex {
                        goToPrevPage()
                    } else if let nextIndex = nextPageIndex, directorySelectedIndex == nextIndex {
                        goToNextPage()
                    } else {
                        // Open the selected PDF file
                        let fileIndex = directorySelectedIndex - 1
                        if fileIndex >= 0 && fileIndex < pagedPDFFiles.count {
                            let selectedFile = pagedPDFFiles[fileIndex]
                            selectedPDFFileURL = selectedFile
                            isShowingDirectorySelector = false
                            ActiveTabState.isArrowNavigationActive = true
                            print("Enter Triggered: Loaded PDF \(selectedFile.lastPathComponent), arrows enabled for page turns")
                        }
                    }
                } else {
                    // Enter in PDF viewer mode: Switch back to directory selection but KEEP arrow keys locked to list navigation
                    isShowingDirectorySelector = true
                    ActiveTabState.isArrowNavigationActive = true
                    print("Enter Triggered: Returned to PDF Selector, arrows remain locked inside PDF mode")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PDFNavigateSelectionUp"))) { _ in
            if selectedTab == 1 && isShowingDirectorySelector && !pdfFiles.isEmpty {
                let totalItemsCount = totalSelectableItemsCount
                directorySelectedIndex = (directorySelectedIndex - 1 + totalItemsCount) % totalItemsCount
                print("Navigation Up: new index \(directorySelectedIndex)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PDFNavigateSelectionDown"))) { _ in
            if selectedTab == 1 && isShowingDirectorySelector && !pdfFiles.isEmpty {
                let totalItemsCount = totalSelectableItemsCount
                directorySelectedIndex = (directorySelectedIndex + 1) % totalItemsCount
                print("Navigation Down: new index \(directorySelectedIndex)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PDFShowFolderSelector"))) { _ in
            isShowingDirectorySelector = true
            print("Switched to folder selector via notification")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BrowserTriggerEnterAction"))) { _ in
            if selectedTab == 0 {
                isBrowserArrowNavigationActive = true
                ActiveTabState.isArrowNavigationActive = true
                print("Switched browser arrow navigation active: true")
                NotificationCenter.default.post(name: NSNotification.Name("FocusBrowserWebView"), object: nil)
            }
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
        .onAppear {
            if defaultPDFLocation.isEmpty {
                defaultPDFLocation = NSHomeDirectory()
            }
            // Always start in Selector Mode so we don't automatically display the PDF until Enter is explicitly pressed
            isShowingDirectorySelector = true
            ActiveTabState.selectedTab = selectedTab
            ActiveTabState.isSelectorModeActive = true
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            ActiveTabState.selectedTab = newValue
            ActiveTabState.isArrowNavigationActive = false
            isBrowserArrowNavigationActive = false
            if newValue == 1 {
                isShowingDirectorySelector = true
                ActiveTabState.isSelectorModeActive = true
            }
        }
        .onChange(of: isShowingDirectorySelector) { oldValue, newValue in
            ActiveTabState.isSelectorModeActive = newValue || activePDFURL == nil
        }
        .onChange(of: activePDFURL) { oldValue, newValue in
            ActiveTabState.isSelectorModeActive = isShowingDirectorySelector || newValue == nil
        }
        .onChange(of: isRotateLeftEnabled) { oldValue, newValue in
            DispatchQueue.main.async {
                StableWindowController.shared.layoutViews()
            }
        }
        .onChange(of: defaultPDFLocation) { oldValue, newValue in
            selectedPDFFileURL = nil
            isShowingDirectorySelector = true
            ActiveTabState.isSelectorModeActive = true
        }
    }
}

// MARK: - Premium Settings View Sub-component
struct SettingsView: View {
    @Binding var defaultURL: String
    @Binding var defaultPDFLocation: String
    @Binding var isRotatedMouseEnabled: Bool
    @Binding var isRotateLeftEnabled: Bool
    
    // Custom premium focus ring states
    @FocusState private var isURLFocused: Bool
    @FocusState private var isPDFFocused: Bool
    
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
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isURLFocused ? Color.blue : Color.gray.opacity(0.3), lineWidth: isURLFocused ? 2 : 1)
                                    .shadow(color: isURLFocused ? Color.blue.opacity(0.3) : Color.clear, radius: 4)
                            )
                            .focused($isURLFocused)
                            .focusEffectDisabled()
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
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isPDFFocused ? Color.blue : Color.gray.opacity(0.3), lineWidth: isPDFFocused ? 2 : 1)
                                        .shadow(color: isPDFFocused ? Color.blue.opacity(0.3) : Color.clear, radius: 4)
                                )
                                .focused($isPDFFocused)
                                .focusEffectDisabled()
                            
                            Button(action: {
                                selectPDFFile()
                            }) {
                                HStack(spacing: 6) {
                                    Text("Browse...")
                                    Text("⌥ O")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(4)
                                }
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
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Toggle(isOn: $isRotatedMouseEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rotated Mouse")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Remap standard physical mouse coordinates to logically rotated space.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            Spacer()
                            
                            Text("⌥ M")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                        
                        HStack {
                            Toggle(isOn: $isRotateLeftEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rotate Left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Rotate the primary display window orientation left.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            Spacer()
                            
                            Text("⌥ L")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 4th Section: Keyboard Shortcuts Guide
                SettingsCard(title: "Keyboard Shortcuts", icon: "keyboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        ShortcutRow(keys: "⌘ 1 / 2 / 3", description: "Switch direct Tabs")
                        ShortcutRow(keys: "⌘ ←  /  ⌘ →", description: "Navigate Tabs globally")
                        ShortcutRow(keys: "←  /  →", description: "Navigate PDF Selector / Page Turns")
                        ShortcutRow(keys: "Ctrl ⇥", description: "Cycle through active Tabs")
                        ShortcutRow(keys: "⌥ ↓  /  PgDn", description: "Scroll view DOWN programmatically")
                        ShortcutRow(keys: "⌥ ↑  /  PgUp", description: "Scroll view UP programmatically")
                        ShortcutRow(keys: "⌘ F", description: "Toggle Window Fullscreen Mode")
                        ShortcutRow(keys: "⌥ O", description: "Open macOS PDF File Browser")
                    }
                }
            }
            .padding(30)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TriggerPDFBrowse"))) { _ in
            self.selectPDFFile()
        }
    }
    
    // Natively choose a PDF folder/directory path from macOS file browser
    private func selectPDFFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Default PDF Directory"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        
        if openPanel.runModal() == .OK {
            if let fileURL = openPanel.url {
                defaultPDFLocation = fileURL.path
            }
        }
    }
}

// MARK: - Premium Shortcut Row Component
struct ShortcutRow: View {
    let keys: String
    let description: String
    
    var body: some View {
        HStack {
            Text(description)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Text(keys)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(.blue)
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

// MARK: - Premium Directory Selection View Component
struct DirectorySelectorView: View {
    let folderPath: String
    let files: [URL]
    @Binding var selectedIndex: Int
    let hasPrevPage: Bool
    let hasNextPage: Bool
    let totalPages: Int
    let currentPage: Int
    let onPrevPage: () -> Void
    let onNextPage: () -> Void
    let onSelect: (URL) -> Void
    let onBack: () -> Void

    var prevPageIndex: Int? {
        if hasPrevPage {
            return 1 + files.count
        }
        return nil
    }

    var nextPageIndex: Int? {
        if hasNextPage {
            return 1 + files.count + (hasPrevPage ? 1 : 0)
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Panel
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PDF Directory Browser")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(folderPath)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        if totalPages > 1 {
                            Text("Page \(currentPage + 1) of \(totalPages)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
                
                if files.isEmpty {
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 100, height: 100)
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                        
                        Text("No PDF Files Found")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                        
                        Text("Add some PDF files into this directory, or select another location via Settings tab (⌘3).")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    .padding(.vertical, 60)
                    .frame(maxWidth: .infinity)
                } else {
                    // List of files
                    VStack(spacing: 12) {
                        // Virtual Item at Index 0: Exit Arrow selection focus and return to Tab Navigation cycling
                        Button(action: {
                            selectedIndex = 0
                            onBack()
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIndex == 0 ? Color.red.opacity(0.2) : Color.gray.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "arrow.left.circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(selectedIndex == 0 ? .red : .gray)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Return to Tab Navigation")
                                        .font(.system(size: 15, weight: selectedIndex == 0 ? .bold : .semibold))
                                        .foregroundColor(selectedIndex == 0 ? .red : .primary)
                                    Text("Release arrow keys to switch tabs")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedIndex == 0 ? Color.red.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                                    .shadow(color: selectedIndex == 0 ? Color.red.opacity(0.1) : Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedIndex == 0 ? Color.red : Color.gray.opacity(0.15), lineWidth: selectedIndex == 0 ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        
                        // Render physical PDF files offset by 1
                        ForEach(0..<files.count, id: \.self) { index in
                            let fileURL = files[index]
                            let virtualIndex = index + 1
                            Button(action: {
                                selectedIndex = virtualIndex
                                onSelect(fileURL)
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIndex == virtualIndex ? Color.blue.opacity(0.2) : Color.cyan.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: selectedIndex == virtualIndex ? "doc.text.fill" : "doc.text")
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedIndex == virtualIndex ? .blue : .cyan)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(fileURL.lastPathComponent)
                                            .font(.system(size: 15, weight: selectedIndex == virtualIndex ? .bold : .semibold))
                                            .foregroundColor(selectedIndex == virtualIndex ? .blue : .primary)
                                            .lineLimit(1)
                                            .multilineTextAlignment(.leading)
                                        
                                        Text(getFileSizeString(for: fileURL))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(selectedIndex == virtualIndex ? .blue : .secondary.opacity(0.5))
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedIndex == virtualIndex ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                                        .shadow(color: selectedIndex == virtualIndex ? Color.blue.opacity(0.1) : Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedIndex == virtualIndex ? Color.blue : Color.gray.opacity(0.15), lineWidth: selectedIndex == virtualIndex ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }

                        // Previous Page Row
                        if hasPrevPage, let prevIndex = prevPageIndex {
                            Button(action: {
                                selectedIndex = prevIndex
                                onPrevPage()
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIndex == prevIndex ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "arrow.up.circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedIndex == prevIndex ? .blue : .gray)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Previous Page")
                                            .font(.system(size: 15, weight: selectedIndex == prevIndex ? .bold : .semibold))
                                            .foregroundColor(selectedIndex == prevIndex ? .blue : .primary)
                                        Text("Go to page \(currentPage) of \(totalPages)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedIndex == prevIndex ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                                        .shadow(color: selectedIndex == prevIndex ? Color.blue.opacity(0.1) : Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedIndex == prevIndex ? Color.blue : Color.gray.opacity(0.15), lineWidth: selectedIndex == prevIndex ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }

                        // Next Page Row
                        if hasNextPage, let nextIndex = nextPageIndex {
                            Button(action: {
                                selectedIndex = nextIndex
                                onNextPage()
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIndex == nextIndex ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedIndex == nextIndex ? .blue : .gray)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Next Page")
                                            .font(.system(size: 15, weight: selectedIndex == nextIndex ? .bold : .semibold))
                                            .foregroundColor(selectedIndex == nextIndex ? .blue : .primary)
                                        Text("Go to page \(currentPage + 2) of \(totalPages)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedIndex == nextIndex ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                                        .shadow(color: selectedIndex == nextIndex ? Color.blue.opacity(0.1) : Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedIndex == nextIndex ? Color.blue : Color.gray.opacity(0.15), lineWidth: selectedIndex == nextIndex ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }
                    }
                }
            }
            .padding(30)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
    }
    
    private func getFileSizeString(for url: URL) -> String {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(size))
            }
        } catch {}
        return "Unknown size"
    }
}
