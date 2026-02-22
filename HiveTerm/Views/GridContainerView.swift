import SwiftUI

struct GridContainerView: View {
    @Environment(SessionStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        TerminalHostRepresentable(
            sessions: store.sessions,
            visibleSessions: store.visibleSessions,
            selectedId: store.selectedSessionId,
            layout: store.currentLayout,
            theme: themeManager.currentTheme,
            fontSize: store.fontSize,
            onSelectSession: { id in store.selectSession(id) }
        )
        .background(Color(nsColor: themeManager.currentTheme.effectiveGridBackground))
    }
}
