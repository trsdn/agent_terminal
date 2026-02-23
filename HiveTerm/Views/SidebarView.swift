import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(SessionStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedSessionId) {
            // === Groups ===
            ForEach(store.groups) { group in
                Section {
                    ForEach(group.sessionIds, id: \.self) { sessionId in
                        if let session = store.session(for: sessionId) {
                            sessionRow(session, inGroup: group)
                        }
                    }
                } header: {
                    groupHeader(group)
                }
            }

            // === Ungrouped Sessions ===
            Section {
                ForEach(store.ungroupedSessions) { session in
                    sessionRow(session, inGroup: nil)
                }
            } header: {
                if !store.groups.isEmpty {
                    Text("Sessions")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: themeManager.currentTheme.effectiveSidebarBackground))
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
    }

    // MARK: - Session Row

    @ViewBuilder
    private func sessionRow(_ session: TerminalSession, inGroup group: SessionGroup?) -> some View {
        SidebarTabRow(session: session)
            .tag(session.id)
            .draggable(session.id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                guard let draggedStr = items.first, let draggedId = UUID(uuidString: draggedStr) else { return false }
                store.dropSession(draggedId, onto: session.id)
                return true
            }
            .contextMenu {
                Button("Rename") { session.isRenaming = true }

                Divider()

                if let group = group {
                    // Reorder within group
                    if let idx = group.sessionIds.firstIndex(of: session.id) {
                        if idx > 0 {
                            Button("Move Up") {
                                group.sessionIds.move(fromOffsets: IndexSet(integer: idx), toOffset: idx - 1)
                            }
                        }
                        if idx < group.sessionIds.count - 1 {
                            Button("Move Down") {
                                group.sessionIds.move(fromOffsets: IndexSet(integer: idx), toOffset: idx + 2)
                            }
                        }
                        Divider()
                    }

                    Button("Remove from \"\(group.name)\"") {
                        store.removeFromGroup(session.id)
                    }
                } else {
                    // Ungrouped — offer to add to existing groups or create new
                    if !store.groups.isEmpty {
                        Menu("Add to Group") {
                            ForEach(store.groups) { g in
                                Button(g.name) {
                                    store.addToGroup(g.id, sessionId: session.id)
                                }
                            }
                        }
                    }

                    // Offer to group with other ungrouped sessions
                    let others = store.ungroupedSessions.filter { $0.id != session.id }
                    if !others.isEmpty {
                        Menu("Group with") {
                            ForEach(others) { other in
                                Button(other.name) {
                                    store.createGroup(sessionIds: [session.id, other.id])
                                    store.selectSession(session.id)
                                }
                            }
                        }
                    }
                }

                Divider()

                Button("Close", role: .destructive) {
                    store.removeSession(session.id)
                }
                .disabled(store.sessions.count <= 1)
            }
    }

    // MARK: - Group Header

    private func groupHeader(_ group: SessionGroup) -> some View {
        HStack(spacing: 4) {
            Image(systemName: group.layoutMode.icon)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(group.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(group.sessionIds.count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            handleGroupDrop(providers, groupId: group.id)
        }
        .contextMenu {
            Button("Rename Group") {
                // TODO: group rename
            }
            Button("Dissolve Group") {
                for id in group.sessionIds {
                    store.removeFromGroup(id)
                }
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            HStack {
                Text("\(store.sessions.count) sessions")
                    .foregroundStyle(.tertiary)
                if store.waitingCount > 0 {
                    Text("· \(store.waitingCount) waiting")
                        .foregroundStyle(.blue)
                }
                Spacer()
                if store.groups.count > 0 {
                    Text("\(store.groups.count) grp")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Drop Handling

    private func handleGroupDrop(_ providers: [NSItemProvider], groupId: UUID) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let str = object as? String, let sessionId = UUID(uuidString: str) else { return }
            DispatchQueue.main.async {
                store.addToGroup(groupId, sessionId: sessionId)
            }
        }
        return true
    }
}
