import Foundation

/// Detects when a terminal session is waiting for user input.
///
/// Safety: Never accesses SwiftTerm's terminal buffer (not thread-safe).
/// Uses only process-state checks and output timing from delegate callbacks.
class InputDetector {
    private var timer: Timer?
    private weak var store: SessionStore?

    /// Patterns checked against the last output line (set by the TerminalView delegate)
    static let inputPatterns: [NSRegularExpression] = {
        let patterns = [
            "(?i)password\\s*:",
            "(?i)passphrase\\s*:",
            "\\[y/N\\]",
            "\\[Y/n\\]",
            "\\(y/n\\)",
            "\\(yes/no\\)",
            "(?i)\\[sudo\\]",
            "(?i)continue connecting",
            "(?i)do you want to",
            "(?i)proceed\\?",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let outputTimeoutInterval: TimeInterval = 2.0

    init(store: SessionStore) {
        self.store = store
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAllSessions()
        }
        timer?.tolerance = 0.3
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkAllSessions() {
        guard let store = store else { return }

        for session in store.sessions {
            let newStatus = detectStatus(for: session)
            if session.status != newStatus {
                session.status = newStatus
            }
        }
    }

    private func detectStatus(for session: TerminalSession) -> SessionStatus {
        guard session.isProcessStarted else {
            return session.status == .error ? .error : .idle
        }

        // Check if process is alive using kill(0) — safe, no side effects
        if let pid = session.childPid, pid > 0 {
            if kill(pid, 0) != 0 {
                return session.status == .error ? .error : .idle
            }
        } else {
            return session.status == .error ? .error : .idle
        }

        // Preserve error and waiting states
        if session.status == .error {
            return .error
        }
        if session.status == .waiting {
            return .waiting
        }

        // Check output timeout — if no output for a while, process might be waiting
        if let lastOutput = session.lastOutputTime {
            let elapsed = Date().timeIntervalSince(lastOutput)
            if elapsed > Self.outputTimeoutInterval {
                // No output for a while — likely at a prompt (running, not waiting)
                return .running
            }
        }

        return .running
    }

    /// Called by the output monitor when a new line is detected.
    /// Safe to call from main thread. Checks if the line matches input patterns.
    static func checkLineForInputPrompt(_ line: String, session: TerminalSession) {
        guard !line.isEmpty else { return }
        let range = NSRange(line.startIndex..., in: line)
        let isInputPrompt = inputPatterns.contains { regex in
            regex.firstMatch(in: line, options: [], range: range) != nil
        }
        if isInputPrompt {
            session.status = .waiting
        }
    }
}
