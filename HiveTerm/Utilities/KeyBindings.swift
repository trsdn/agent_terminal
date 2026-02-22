import AppKit

/// Configures global keyboard shortcuts for the application.
/// Most shortcuts are handled via SwiftUI .commands() in HiveTermApp,
/// but this handles any AppKit-level key bindings needed.
enum KeyBindings {
    /// Key equivalents for tab switching (Cmd+1 through Cmd+9)
    static let tabSwitchKeys: [Character] = Array("123456789")

    /// Register any global event monitors if needed
    static func registerGlobalShortcuts(store: SessionStore) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle Cmd+number for tab switching
            if event.modifierFlags.contains(.command),
               let char = event.characters?.first,
               let index = tabSwitchKeys.firstIndex(of: char) {
                let tabIndex = tabSwitchKeys.distance(from: tabSwitchKeys.startIndex, to: index)
                store.selectSessionByIndex(tabIndex)
                return nil // Consume the event
            }
            return event
        }
    }
}
