import SwiftUI
import AppKit
import SwiftTerm

// MARK: - AppKit Host (single container for ALL terminals)

class TerminalHostView: NSView {
    override var isFlipped: Bool { true }

    var onSelectSession: ((UUID) -> Void)?
    private var infos: [UUID: TerminalInfo] = [:]
    private var pendingStarts: [(LocalProcessTerminalView, TerminalSession)] = []
    private var currentVisible: [TerminalSession] = []
    private var currentLayout: LayoutMode = .single
    private var currentSelectedId: UUID?
    private var currentThemeId: String?
    private var currentTheme: TerminalTheme?
    private var currentFontSize: CGFloat = 13
    private let gap: CGFloat = 4
    private let paddingH: CGFloat = 10
    private let paddingTop: CGFloat = 0
    private let paddingBottom: CGFloat = 8

    private let borderInset: CGFloat = 8

    struct TerminalInfo {
        let containerView: NSView
        let terminalView: LocalProcessTerminalView
        let coordinator: TerminalCoordinator
        let monitor: TerminalOutputMonitor
    }

    // Called by NSViewRepresentable.updateNSView
    func update(sessions: [TerminalSession], visible: [TerminalSession], selectedId: UUID?, layout: LayoutMode, theme: TerminalTheme, fontSize: CGFloat) {
        let selectionChanged = selectedId != currentSelectedId
        let themeChanged = theme.id != currentThemeId
        let fontSizeChanged = fontSize != currentFontSize
        currentVisible = visible
        currentLayout = layout
        currentSelectedId = selectedId
        currentThemeId = theme.id
        currentTheme = theme
        currentFontSize = fontSize

        // Ensure terminals exist
        for session in sessions {
            ensureTerminal(for: session, theme: theme)
        }

        // Remove deleted sessions
        let activeIds = Set(sessions.map(\.id))
        for id in infos.keys where !activeIds.contains(id) {
            infos[id]?.containerView.removeFromSuperview()
            infos.removeValue(forKey: id)
        }

        // Apply theme to all terminals on theme change
        if themeChanged {
            for (_, info) in infos {
                applyTheme(theme, to: info.terminalView)
            }
        }

        // Apply font size change to all terminals
        if fontSizeChanged {
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            for (_, info) in infos {
                info.terminalView.font = font
            }
        }

        // Toggle visibility
        let visibleIds = Set(visible.map(\.id))
        for (id, info) in infos {
            info.containerView.isHidden = !visibleIds.contains(id)
        }

        // Layout + focus borders + start pending processes
        layoutTerminals()
        updateBorders()
        startPendingProcesses(theme: theme)
        if selectionChanged {
            focusSelected()
        }
    }

    private func applyTheme(_ theme: TerminalTheme, to tv: LocalProcessTerminalView) {
        tv.nativeBackgroundColor = theme.background.nsColor
        tv.nativeForegroundColor = theme.foreground.nsColor
        tv.caretColor = theme.cursor.nsColor
        tv.selectedTextBackgroundColor = theme.selection.nsColor

        if theme.ansiColors.count == 16 {
            let palette = theme.ansiColors.map(\.swiftTermColor)
            tv.installColors(palette)
        }

        tv.setNeedsDisplay(tv.bounds)
    }

    private func ensureTerminal(for session: TerminalSession, theme: TerminalTheme) {
        guard infos[session.id] == nil else { return }

        let tv = LocalProcessTerminalView(frame: bounds)
        tv.font = NSFont.monospacedSystemFont(ofSize: currentFontSize, weight: .regular)
        tv.nativeBackgroundColor = theme.background.nsColor
        tv.nativeForegroundColor = theme.foreground.nsColor
        tv.caretColor = theme.cursor.nsColor
        tv.selectedTextBackgroundColor = theme.selection.nsColor

        let coord = TerminalCoordinator(session: session)
        tv.processDelegate = coord

        let monitor = TerminalOutputMonitor(session: session)
        coord.outputMonitor = monitor
        tv.terminalDelegate = monitor

        let click = NSClickGestureRecognizer(target: self, action: #selector(terminalClicked(_:)))
        tv.addGestureRecognizer(click)

        // Wrap terminal in a container for border + inset
        let container = NSView(frame: bounds)
        container.wantsLayer = true
        container.layer?.cornerRadius = 4
        container.layer?.masksToBounds = true
        container.addSubview(tv)
        addSubview(container)
        container.isHidden = true

        // Hide SwiftTerm's built-in legacy scroller (it's a direct subview)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for subview in tv.subviews {
                if let scroller = subview as? NSScroller {
                    scroller.isHidden = true
                }
            }
        }

        session.terminalView = tv

        infos[session.id] = TerminalInfo(containerView: container, terminalView: tv, coordinator: coord, monitor: monitor)

        // Defer process start until after layout so terminal has correct size
        pendingStarts.append((tv, session))
    }

    private func startPendingProcesses(theme: TerminalTheme?) {
        guard !pendingStarts.isEmpty, bounds.width > 0, bounds.height > 0 else { return }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        var env = ProcessInfo.processInfo.environment
        env["PROMPT_EOL_MARK"] = ""
        env["TERM"] = "xterm-256color"
        let envArray = env.map { "\($0.key)=\($0.value)" }

        for (tv, session) in pendingStarts {
            session.isProcessStarted = true
            tv.startProcess(executable: shell, environment: envArray, currentDirectory: home)
            session.status = .running

            if let theme, theme.ansiColors.count == 16 {
                let palette = theme.ansiColors.map(\.swiftTermColor)
                DispatchQueue.main.async {
                    tv.installColors(palette)
                }
            }
        }
        pendingStarts.removeAll()
    }

    @objc private func terminalClicked(_ gesture: NSClickGestureRecognizer) {
        guard let view = gesture.view else { return }
        // Update selected session in store so border follows click
        if let id = infos.first(where: { $0.value.terminalView === view })?.key {
            window?.makeFirstResponder(view)
            currentSelectedId = id
            updateBorders()
            onSelectSession?(id)
        }
    }

    private func focusSelected() {
        guard let id = currentSelectedId, let info = infos[id], !info.containerView.isHidden else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            if window.firstResponder !== info.terminalView {
                window.makeFirstResponder(info.terminalView)
            }
        }
    }

    // MARK: - Borders

    private func updateBorders() {
        let cursorColor = currentTheme?.cursor.nsColor ?? NSColor.white
        let bgColor = currentTheme?.background.nsColor ?? NSColor.black
        for (id, info) in infos {
            info.containerView.layer?.backgroundColor = bgColor.cgColor
            if id == currentSelectedId {
                info.containerView.layer?.borderWidth = 2
                info.containerView.layer?.borderColor = cursorColor.cgColor
            } else {
                info.containerView.layer?.borderWidth = 1
                info.containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
            }
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        layoutTerminals()
        startPendingProcesses(theme: currentTheme)
    }

    private func layoutTerminals() {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let padded = CGSize(width: size.width - paddingH * 2, height: size.height - paddingTop - paddingBottom)
        for (index, session) in currentVisible.enumerated() {
            guard let info = infos[session.id] else { continue }
            var rect = rectForIndex(index, count: currentVisible.count, layout: currentLayout, in: padded)
            rect.origin.x += paddingH
            rect.origin.y += paddingTop
            info.containerView.frame = rect
            // Inset terminal within container so text doesn't touch the border
            info.terminalView.frame = CGRect(
                x: borderInset, y: borderInset,
                width: rect.width - borderInset * 2,
                height: rect.height - borderInset * 2
            )
        }
    }

    private func rectForIndex(_ index: Int, count: Int, layout: LayoutMode, in size: CGSize) -> CGRect {
        switch layout {
        case .single:
            return CGRect(origin: .zero, size: size)

        case .sideBySide:
            let w = (size.width - gap) / 2
            return CGRect(x: CGFloat(index) * (w + gap), y: 0, width: w, height: size.height)

        case .grid2x2:
            let w = (size.width - gap) / 2
            let rows = (count + 1) / 2
            let h = (size.height - gap * CGFloat(max(rows - 1, 0))) / CGFloat(max(rows, 1))
            let col = index % 2
            let row = index / 2
            let isLastOdd = (count % 2 == 1) && (index == count - 1)
            return CGRect(
                x: CGFloat(col) * (w + gap),
                y: CGFloat(row) * (h + gap),
                width: isLastOdd ? size.width : w,
                height: h
            )
        }
    }
}

// MARK: - Coordinator (per terminal)

class TerminalCoordinator: NSObject, LocalProcessTerminalViewDelegate {
    let session: TerminalSession
    var outputMonitor: TerminalOutputMonitor?

    init(session: TerminalSession) {
        self.session = session
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async {
            self.session.status = .idle
            self.session.isProcessStarted = false
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async {
            if !self.session.isRenaming {
                self.session.name = title.isEmpty ? "Shell" : title
            }
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}

// MARK: - Output Monitor

class TerminalOutputMonitor: NSObject, TerminalViewDelegate {
    weak var session: TerminalSession?

    init(session: TerminalSession) {
        self.session = session
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: TerminalView, title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let session = self?.session, !session.isRenaming else { return }
            session.name = title.isEmpty ? "Shell" : title
        }
    }
    func scrolled(source: TerminalView, position: Double) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {}
    func bell(source: TerminalView) {}
    func clipboardCopy(source: TerminalView, content: Data) {}
    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        guard let session = session else { return }
        session.lastOutputTime = Date()
        session.status = .running

        let terminal = source.getTerminal()
        let pos = terminal.getCursorLocation()
        if let line = terminal.getLine(row: pos.y) {
            let text = line.translateToString(trimRight: true)
            InputDetector.checkLineForInputPrompt(text, session: session)
        }
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        session?.status = .running
        if let termView = source as? LocalProcessTerminalView {
            termView.process.send(data: data)
        }
    }
}

// MARK: - SwiftUI Bridge (single NSViewRepresentable for the whole grid)

struct TerminalHostRepresentable: NSViewRepresentable {
    let sessions: [TerminalSession]
    let visibleSessions: [TerminalSession]
    let selectedId: UUID?
    let layout: LayoutMode
    let theme: TerminalTheme
    let fontSize: CGFloat
    var onSelectSession: ((UUID) -> Void)?

    func makeNSView(context: Context) -> TerminalHostView {
        let view = TerminalHostView(frame: .zero)
        view.onSelectSession = onSelectSession
        return view
    }

    func updateNSView(_ nsView: TerminalHostView, context: Context) {
        nsView.onSelectSession = onSelectSession
        nsView.update(sessions: sessions, visible: visibleSessions, selectedId: selectedId, layout: layout, theme: theme, fontSize: fontSize)
    }
}
