import SwiftUI

@main
struct AgentHiveApp: App {
    @State private var store = SessionStore()
    @State private var inputDetector: InputDetector?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 700, minHeight: 400)
                .preferredColorScheme(.dark)
                .onAppear {
                    if store.sessions.isEmpty {
                        store.createSession()
                    }
                    if inputDetector == nil {
                        inputDetector = InputDetector(store: store)
                        inputDetector?.start()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
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
