import Foundation
import Combine

enum LayoutMode: String, CaseIterable, Codable {
    case single
    case sideBySide
    case grid2x2

    var icon: String {
        switch self {
        case .single: return "square"
        case .sideBySide: return "rectangle.split.2x1"
        case .grid2x2: return "rectangle.split.2x2"
        }
    }

    var maxPanes: Int {
        switch self {
        case .single: return 1
        case .sideBySide: return 2
        case .grid2x2: return 4
        }
    }
}

@Observable
class SessionStore {
    var sessions: [TerminalSession] = []
    var groups: [SessionGroup] = []
    var selectedSessionId: UUID?
    var layout: LayoutMode = .single
    var showDebug: Bool = false
    var fontSize: CGFloat = 13

    var selectedSession: TerminalSession? {
        sessions.first { $0.id == selectedSessionId }
    }

    func session(for id: UUID) -> TerminalSession? {
        sessions.first { $0.id == id }
    }

    var activeGroup: SessionGroup? {
        guard let selectedId = selectedSessionId else { return nil }
        return groups.first { $0.sessionIds.contains(selectedId) }
    }

    /// Sessions visible in the grid — groups use their layout, ungrouped use the picker layout.
    var visibleSessions: [TerminalSession] {
        if let group = activeGroup {
            let max = group.layoutMode.maxPanes
            return Array(group.sessionIds.compactMap { session(for: $0) }.prefix(max))
        }

        // Ungrouped: show first maxPanes sessions in natural order,
        // swapping the selected session in if it's outside the window.
        let maxPanes = layout.maxPanes
        let ungrouped = ungroupedSessions
        guard !ungrouped.isEmpty else { return [] }

        var visible = Array(ungrouped.prefix(maxPanes))
        if let selectedId = selectedSessionId,
           !visible.contains(where: { $0.id == selectedId }),
           let selected = ungrouped.first(where: { $0.id == selectedId }) {
            // Replace the last slot with the selected session
            if !visible.isEmpty {
                visible[visible.count - 1] = selected
            }
        }
        return visible
    }

    var currentLayout: LayoutMode {
        if let group = activeGroup {
            return group.layoutMode
        }
        // Cap layout to actual number of ungrouped sessions
        let count = ungroupedSessions.count
        if count <= 1 { return .single }
        if count <= 2 && layout == .grid2x2 { return .sideBySide }
        return layout
    }

    var ungroupedSessions: [TerminalSession] {
        let grouped = Set(groups.flatMap { $0.sessionIds })
        return sessions.filter { !grouped.contains($0.id) }
    }

    var waitingCount: Int {
        sessions.filter { $0.status == .waiting }.count
    }

    // MARK: - Session CRUD

    @discardableResult
    func createSession(name: String = "Shell") -> TerminalSession {
        let session = TerminalSession(name: name)
        sessions.append(session)
        selectedSessionId = session.id
        return session
    }

    func removeSession(_ id: UUID) {
        if let s = session(for: id) {
            s.process = nil
        }
        sessions.removeAll { $0.id == id }
        for group in groups {
            group.sessionIds.removeAll { $0 == id }
        }
        groups.removeAll { $0.sessionIds.count <= 1 }
        if selectedSessionId == id {
            selectedSessionId = sessions.first?.id
        }
    }

    func selectSession(_ id: UUID) {
        selectedSessionId = id
    }

    func selectSessionByIndex(_ index: Int) {
        guard index >= 0, index < sessions.count else { return }
        selectedSessionId = sessions[index].id
    }

    // MARK: - Group Management

    func groupForSession(_ sessionId: UUID) -> SessionGroup? {
        groups.first { $0.sessionIds.contains(sessionId) }
    }

    @discardableResult
    func createGroup(name: String = "Grid", sessionIds: [UUID]) -> SessionGroup {
        for id in sessionIds {
            removeFromGroup(id)
        }
        let group = SessionGroup(name: name, sessionIds: sessionIds)
        guard group.sessionIds.count >= 2 else { return group }
        groups.append(group)
        return group
    }

    func addToGroup(_ groupId: UUID, sessionId: UUID) {
        // Remove from any OTHER group (protect the target group from dissolution)
        for group in groups where group.id != groupId {
            group.sessionIds.removeAll { $0 == sessionId }
        }
        groups.removeAll { $0.id != groupId && $0.sessionIds.count <= 1 }

        guard let group = groups.first(where: { $0.id == groupId }) else { return }
        if !group.sessionIds.contains(sessionId) {
            group.sessionIds.append(sessionId)
        }
    }

    func removeFromGroup(_ sessionId: UUID) {
        for group in groups {
            group.sessionIds.removeAll { $0 == sessionId }
        }
        // Dissolve groups with 0 or 1 members — a single-member group has no meaning
        groups.removeAll { $0.sessionIds.count <= 1 }
    }

    func dropSession(_ draggedId: UUID, onto targetId: UUID) {
        guard draggedId != targetId else { return }

        let draggedGroup = groupForSession(draggedId)
        let targetGroup = groupForSession(targetId)

        // Reorder within the same group
        if let group = targetGroup, draggedGroup?.id == group.id {
            guard let fromIdx = group.sessionIds.firstIndex(of: draggedId),
                  let toIdx = group.sessionIds.firstIndex(of: targetId) else { return }
            group.sessionIds.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
            return
        }

        // Move into existing group or create new one
        if let group = targetGroup {
            addToGroup(group.id, sessionId: draggedId)
        } else {
            createGroup(sessionIds: [targetId, draggedId])
        }
    }

    /// Group the currently selected session with another session
    func groupSelectedWith(_ otherId: UUID) {
        guard let selectedId = selectedSessionId, selectedId != otherId else { return }
        dropSession(otherId, onto: selectedId)
        selectSession(selectedId)
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        struct GroupSnapshot: Codable {
            let name: String
            let sessionIndices: [Int]
        }

        let sessionNames: [String]
        let selectedIndex: Int?
        let groups: [GroupSnapshot]
        let layout: LayoutMode
        let fontSize: CGFloat
    }

    private static let defaultsKey = "sessionStoreSnapshot"

    func save() {
        let sessionIndices = Dictionary(uniqueKeysWithValues: sessions.enumerated().map { ($0.element.id, $0.offset) })
        let groupSnapshots = groups.compactMap { group -> Snapshot.GroupSnapshot? in
            let indices = group.sessionIds.compactMap { sessionIndices[$0] }
            guard !indices.isEmpty else { return nil }
            return Snapshot.GroupSnapshot(name: group.name, sessionIndices: indices)
        }
        let selectedIdx = selectedSessionId.flatMap { sessionIndices[$0] }
        let snapshot = Snapshot(
            sessionNames: sessions.map(\.name),
            selectedIndex: selectedIdx,
            groups: groupSnapshots,
            layout: layout,
            fontSize: fontSize
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    func restoreIfAvailable() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        guard !snapshot.sessionNames.isEmpty else { return }

        for name in snapshot.sessionNames {
            createSession(name: name)
        }

        for groupSnap in snapshot.groups {
            let ids = groupSnap.sessionIndices.compactMap { idx -> UUID? in
                guard idx >= 0, idx < sessions.count else { return nil }
                return sessions[idx].id
            }
            if ids.count >= 2 {
                createGroup(name: groupSnap.name, sessionIds: ids)
            }
        }

        layout = snapshot.layout
        fontSize = snapshot.fontSize

        if let idx = snapshot.selectedIndex, idx >= 0, idx < sessions.count {
            selectedSessionId = sessions[idx].id
        }
    }
}
