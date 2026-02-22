import Foundation

@Observable
class SessionGroup: Identifiable {
    let id: UUID
    var name: String
    var sessionIds: [UUID]

    init(name: String = "Grid", sessionIds: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.sessionIds = sessionIds
    }

    var layoutMode: LayoutMode {
        switch sessionIds.count {
        case 0, 1: return .single
        case 2: return .sideBySide
        default: return .grid2x2
        }
    }
}
