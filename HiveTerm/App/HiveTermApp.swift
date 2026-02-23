import SwiftUI
import UniformTypeIdentifiers

@main
struct HiveTermApp: App {
    @State private var store = SessionStore()
    @State private var themeManager = ThemeManager()
    @State private var inputDetector: InputDetector?
    @State private var showThemeImporter = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(themeManager)
                .frame(minWidth: 700, minHeight: 400)
                .preferredColorScheme(.dark)
                .onAppear {
                    store.restoreIfAvailable()
                    if store.sessions.isEmpty {
                        store.createSession()
                    }
                    if inputDetector == nil {
                        inputDetector = InputDetector(store: store)
                        inputDetector?.start()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.save()
                }
                .fileImporter(
                    isPresented: $showThemeImporter,
                    allowedContentTypes: [
                        UTType(filenameExtension: "itermcolors") ?? .xml,
                    ],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        try? themeManager.importITermColors(from: url)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    store.createSession()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    if let id = store.selectedSessionId {
                        store.removeSession(id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(store.sessions.count <= 1)

                Divider()

                Button("Rename Tab") {
                    if let session = store.selectedSession {
                        session.isRenaming = true
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                // Layout
                Menu("Layout") {
                    ForEach(LayoutMode.allCases, id: \.self) { mode in
                        Button {
                            store.layout = mode
                        } label: {
                            if store.layout == mode {
                                Text("✓ \(mode.rawValue)")
                            } else {
                                Text("   \(mode.rawValue)")
                            }
                        }
                    }
                }

                // Font Size
                Menu("Font Size") {
                    Button("Increase") {
                        store.fontSize = min(store.fontSize + 1, 24)
                    }
                    .keyboardShortcut("+", modifiers: .command)

                    Button("Decrease") {
                        store.fontSize = max(store.fontSize - 1, 10)
                    }
                    .keyboardShortcut("-", modifiers: .command)

                    Button("Reset") {
                        store.fontSize = 13
                    }
                    .keyboardShortcut("0", modifiers: .command)
                }

                // Theme
                Menu("Theme") {
                    ForEach(themeManager.availableThemes) { theme in
                        Button {
                            themeManager.selectTheme(theme)
                        } label: {
                            if themeManager.currentTheme.id == theme.id {
                                Text("✓ \(theme.name)")
                            } else {
                                Text("   \(theme.name)")
                            }
                        }
                    }

                    Divider()

                    Button("Import .itermcolors...") {
                        showThemeImporter = true
                    }
                }

                Divider()

                Button("Toggle Debug") {
                    store.showDebug.toggle()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                ForEach(1...9, id: \.self) { index in
                    Button("Tab \(index)") {
                        store.selectSessionByIndex(index - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(index))), modifiers: .command)
                }
            }
        }
    }
}
