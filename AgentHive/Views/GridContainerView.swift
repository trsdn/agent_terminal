import SwiftUI

struct GridContainerView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        TerminalHostRepresentable(
            sessions: store.sessions,
            visibleSessions: store.visibleSessions,
            selectedId: store.selectedSessionId,
            layout: store.currentLayout
        )
        .background(Color(nsColor: NSColor(white: 0.06, alpha: 1)))
    }
}
