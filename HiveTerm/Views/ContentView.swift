import SwiftUI

struct ContentView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 140, ideal: 180, max: 260)
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                GridContainerView()

                if store.showDebug {
                    DebugOverlay()
                        .environment(store)
                }
            }
        }
        .toolbar(.hidden)
    }
}

// MARK: - Debug Overlay (Cmd+Shift+D)

struct DebugOverlay: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)

            Text("layout: \(store.layout.rawValue) (max \(store.layout.maxPanes))")
            Text("effective: \(store.currentLayout.rawValue)")
            Text("sessions: \(store.sessions.count)")
            Text("groups: \(store.groups.count)")
            Text("visible: \(store.visibleSessions.count)")
            Text("selected: \(store.selectedSessionId?.uuidString.prefix(8) ?? "nil")")

            if let group = store.activeGroup {
                Text("active group: \(group.name) (\(group.sessionIds.count) members)")
            } else {
                Text("active group: none (ungrouped)")
            }

            Divider().opacity(0.3)

            ForEach(store.sessions) { s in
                HStack(spacing: 4) {
                    Circle()
                        .fill(s.status.color)
                        .frame(width: 5, height: 5)
                    Text("\(s.name)")
                    if let g = store.groupForSession(s.id) {
                        Text("[\(g.name)]").foregroundStyle(.blue)
                    }
                    if s.id == store.selectedSessionId {
                        Text("<-").foregroundStyle(.yellow)
                    }
                }
            }
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(.green.opacity(0.9))
        .padding(8)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
        .padding(8)
    }
}
