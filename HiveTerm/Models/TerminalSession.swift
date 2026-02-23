import Foundation
import SwiftUI

enum SessionStatus: String, CaseIterable {
    case running
    case waiting
    case idle
    case error

    var color: SwiftUI.Color {
        switch self {
        case .running: return .green
        case .waiting: return .blue
        case .idle: return .gray
        case .error: return .red
        }
    }

    var label: String {
        switch self {
        case .running: return "running"
        case .waiting: return "waiting for input"
        case .idle: return "idle"
        case .error: return "process exited"
        }
    }
}

@Observable
class TerminalSession: Identifiable {
    let id: UUID
    var name: String
    var status: SessionStatus
    var isRenaming: Bool

    weak var process: (any TerminalProcess)?
    var lastOutputTime: Date?

    var isProcessStarted: Bool = false

    init(name: String = "Shell") {
        self.id = UUID()
        self.name = name
        self.status = .idle
        self.isRenaming = false
    }

    var childPid: pid_t? {
        guard isProcessStarted else { return nil }
        return process?.shellPid
    }
}
