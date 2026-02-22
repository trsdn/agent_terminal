import Foundation
import AppKit
import SwiftTerm

enum SessionStatus: String, CaseIterable {
    case running
    case waiting
    case idle

    var color: NSColor {
        switch self {
        case .running: return .systemGreen
        case .waiting: return .systemBlue
        case .idle: return .systemGray
        }
    }

    var label: String {
        switch self {
        case .running: return "running"
        case .waiting: return "waiting for input"
        case .idle: return "idle"
        }
    }
}

@Observable
class TerminalSession: Identifiable {
    let id: UUID
    var name: String
    var status: SessionStatus
    var isRenaming: Bool

    // Stored terminal view — persists across SwiftUI re-renders
    var terminalView: LocalProcessTerminalView?
    var lastOutputTime: Date?

    // Track whether this session has ever been displayed (startProcess called)
    var isProcessStarted: Bool = false

    init(name: String = "Shell") {
        self.id = UUID()
        self.name = name
        self.status = .idle
        self.isRenaming = false
    }

    var childPid: pid_t? {
        guard isProcessStarted else { return nil }
        return terminalView?.process.shellPid
    }
}
