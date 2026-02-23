import XCTest
@testable import HiveTerm

final class HiveTermTests: XCTestCase {

    // MARK: - Session CRUD

    func testSessionCreation() {
        let store = SessionStore()
        let session = store.createSession(name: "Test")
        XCTAssertEqual(session.name, "Test")
        XCTAssertEqual(session.status, .idle)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.selectedSessionId, session.id)
    }

    func testSessionRemoval() {
        let store = SessionStore()
        let s1 = store.createSession(name: "First")
        let s2 = store.createSession(name: "Second")

        store.selectSession(s2.id)
        store.removeSession(s2.id)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.selectedSessionId, s1.id)
    }

    // MARK: - Stable visible ordering (prevents hang)

    func testVisibleSessionsSingleMode() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")

        store.layout = .single
        store.selectSession(s1.id)
        XCTAssertEqual(store.visibleSessions.map(\.name), ["A"])

        store.selectSession(s2.id)
        XCTAssertEqual(store.visibleSessions.map(\.name), ["B"])
    }

    func testVisibleSessionsStableOrderInGrid() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")
        let s4 = store.createSession(name: "D")

        store.layout = .grid2x2
        store.selectSession(s1.id)

        let order1 = store.visibleSessions.map(\.name)

        // Clicking a different session should NOT reorder the grid
        store.selectSession(s3.id)
        let order2 = store.visibleSessions.map(\.name)

        XCTAssertEqual(order1, order2, "Grid order must be stable when selecting different sessions")
    }

    func testVisibleSessionsSplitStableOrder() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let _ = store.createSession(name: "C")

        store.layout = .sideBySide
        store.selectSession(s1.id)
        let names1 = store.visibleSessions.map(\.name)

        store.selectSession(s2.id)
        let names2 = store.visibleSessions.map(\.name)

        XCTAssertEqual(names1, names2, "Split order must be stable when selecting different sessions")
    }

    func testVisibleSessionsSwapsInDistantSelection() {
        let store = SessionStore()
        let _ = store.createSession(name: "A")
        let _ = store.createSession(name: "B")
        let _ = store.createSession(name: "C")
        let _ = store.createSession(name: "D")
        let s5 = store.createSession(name: "E")

        store.layout = .grid2x2
        // Select session 5 which is beyond the first 4
        store.selectSession(s5.id)

        let visible = store.visibleSessions.map(\.name)
        XCTAssertTrue(visible.contains("E"), "Selected session beyond grid window should be swapped in")
        XCTAssertEqual(visible.count, 4)
    }

    // MARK: - Group Management

    func testGroupCreation() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")

        let group = store.createGroup(sessionIds: [s1.id, s2.id])
        XCTAssertEqual(group.sessionIds.count, 2)
        XCTAssertEqual(group.layoutMode, .sideBySide)
        XCTAssertEqual(store.ungroupedSessions.count, 0)
        XCTAssertEqual(store.layout, .sideBySide, "Layout should auto-adjust to group size")
    }

    func testDropCreatesGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")

        store.dropSession(s1.id, onto: s2.id)
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.groups[0].sessionIds.count, 2)
    }

    func testDropOntoExistingGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")

        store.dropSession(s1.id, onto: s2.id)
        store.dropSession(s3.id, onto: s1.id)

        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.groups[0].sessionIds.count, 3)
        XCTAssertEqual(store.groups[0].layoutMode, .grid2x2)
    }

    func testRemoveFromGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")

        store.createGroup(sessionIds: [s1.id, s2.id, s3.id])
        store.removeFromGroup(s2.id)

        XCTAssertEqual(store.groups[0].sessionIds.count, 2)
        XCTAssertEqual(store.ungroupedSessions.count, 1)
        XCTAssertEqual(store.ungroupedSessions[0].id, s2.id)
    }

    func testGroupAutoLayout() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")
        let s4 = store.createSession(name: "D")

        let group = store.createGroup(sessionIds: [s1.id])
        XCTAssertEqual(group.layoutMode, .single)

        store.addToGroup(group.id, sessionId: s2.id)
        XCTAssertEqual(group.layoutMode, .sideBySide)

        store.addToGroup(group.id, sessionId: s3.id)
        store.addToGroup(group.id, sessionId: s4.id)
        XCTAssertEqual(group.layoutMode, .grid2x2)
    }

    func testVisibleSessionsFromGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let _ = store.createSession(name: "C")

        store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)

        XCTAssertEqual(store.visibleSessions.count, 2)
        XCTAssertEqual(store.currentLayout, .sideBySide)
    }

    func testRemoveSessionCleansUpGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")

        store.createGroup(sessionIds: [s1.id, s2.id])
        store.removeSession(s1.id)
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.groups[0].sessionIds, [s2.id])

        store.removeSession(s2.id)
        XCTAssertEqual(store.groups.count, 0)
    }

    func testDropSelfIsNoop() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")

        store.dropSession(s1.id, onto: s1.id)
        XCTAssertEqual(store.groups.count, 0, "Dropping session onto itself should do nothing")
    }

    // MARK: - Input Detection

    func testInputPatternMatching() {
        let session = TerminalSession(name: "Test")

        InputDetector.checkLineForInputPrompt("Password:", session: session)
        XCTAssertEqual(session.status, .waiting)

        session.status = .running
        InputDetector.checkLineForInputPrompt("Continue? [y/N]", session: session)
        XCTAssertEqual(session.status, .waiting)

        session.status = .running
        InputDetector.checkLineForInputPrompt("$ ls -la", session: session)
        XCTAssertEqual(session.status, .running, "Shell prompt should not trigger waiting")
    }

    // MARK: - Persistence

    func testSaveAndRestore() {
        let store1 = SessionStore()
        _ = store1.createSession(name: "Alpha")
        _ = store1.createSession(name: "Beta")
        store1.layout = .sideBySide
        store1.fontSize = 16
        store1.selectSession(store1.sessions[0].id)
        store1.save()

        let store2 = SessionStore()
        store2.restoreIfAvailable()
        XCTAssertEqual(store2.sessions.count, 2)
        XCTAssertEqual(store2.sessions.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(store2.layout, .sideBySide)
        XCTAssertEqual(store2.fontSize, 16)
        XCTAssertEqual(store2.selectedSessionId, store2.sessions[0].id)
    }

    func testSaveAndRestoreWithGroups() {
        let store1 = SessionStore()
        let s1 = store1.createSession(name: "A")
        let s2 = store1.createSession(name: "B")
        _ = store1.createSession(name: "C")
        store1.createGroup(name: "MyGrid", sessionIds: [s1.id, s2.id])
        store1.save()

        let store2 = SessionStore()
        store2.restoreIfAvailable()
        XCTAssertEqual(store2.sessions.count, 3)
        XCTAssertEqual(store2.groups.count, 1)
        XCTAssertEqual(store2.groups[0].name, "MyGrid")
        XCTAssertEqual(store2.groups[0].sessionIds.count, 2)
    }

    func testRestoreEmptyIsNoop() {
        UserDefaults.standard.removeObject(forKey: "sessionStoreSnapshot")
        let store = SessionStore()
        store.restoreIfAvailable()
        XCTAssertTrue(store.sessions.isEmpty)
    }

    // MARK: - currentLayout Capping

    func testCurrentLayoutSingleSession() {
        let store = SessionStore()
        _ = store.createSession(name: "A")
        store.layout = .grid2x2
        XCTAssertEqual(store.currentLayout, .single, "Single session should force single layout")
    }

    func testCurrentLayoutTwoSessionsCapsGrid() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        _ = store.createSession(name: "B")
        store.layout = .grid2x2
        store.selectSession(s1.id)
        XCTAssertEqual(store.currentLayout, .sideBySide, "Two sessions with grid2x2 should cap to sideBySide")
    }

    func testCurrentLayoutThreeSessionsAllowsGrid() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        _ = store.createSession(name: "B")
        _ = store.createSession(name: "C")
        store.layout = .grid2x2
        store.selectSession(s1.id)
        XCTAssertEqual(store.currentLayout, .grid2x2, "Three sessions should allow grid2x2")
    }

    func testCurrentLayoutUsesGroupLayout() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")
        store.createGroup(sessionIds: [s1.id, s2.id, s3.id])
        store.selectSession(s1.id)
        XCTAssertEqual(store.currentLayout, .grid2x2, "Should use group's layout when session is in a group")
    }

    func testCurrentLayoutIgnoresPickerForGroupedSession() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.createGroup(sessionIds: [s1.id, s2.id])
        store.layout = .grid2x2
        store.selectSession(s1.id)
        XCTAssertEqual(store.currentLayout, .sideBySide, "Group layout should override picker layout")
    }
}

// MARK: - HexColor Tests

final class HexColorTests: XCTestCase {

    func testBasicHexParsing() {
        let color = HexColor("#FF0000")
        let ns = color.nsColor
        XCTAssertEqual(ns.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(ns.greenComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(ns.blueComponent, 0.0, accuracy: 0.01)
    }

    func testHexWithoutHash() {
        let color = HexColor("00FF00")
        let ns = color.nsColor
        XCTAssertEqual(ns.redComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(ns.greenComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(ns.blueComponent, 0.0, accuracy: 0.01)
    }

    func testBlackHex() {
        let color = HexColor("#000000")
        let ns = color.nsColor
        XCTAssertEqual(ns.redComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(ns.greenComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(ns.blueComponent, 0.0, accuracy: 0.01)
    }

    func testWhiteHex() {
        let color = HexColor("#FFFFFF")
        let ns = color.nsColor
        XCTAssertEqual(ns.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(ns.greenComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(ns.blueComponent, 1.0, accuracy: 0.01)
    }

    func testInvalidHexReturnBlack() {
        let color = HexColor("xyz")
        let ns = color.nsColor
        XCTAssertEqual(ns.redComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(ns.greenComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(ns.blueComponent, 0.0, accuracy: 0.01)
    }

    func testStringLiteralInit() {
        let color: HexColor = "#0000FF"
        let ns = color.nsColor
        XCTAssertEqual(ns.blueComponent, 1.0, accuracy: 0.01)
    }

    func testCodableRoundTrip() throws {
        let original = HexColor("#ABCDEF")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HexColor.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testEquality() {
        XCTAssertEqual(HexColor("#FF0000"), HexColor("#FF0000"))
        XCTAssertNotEqual(HexColor("#FF0000"), HexColor("#00FF00"))
    }

    func testSwiftTermColorConversion() {
        let color = HexColor("#FF0000")
        let stColor = color.swiftTermColor
        XCTAssertEqual(stColor.red, 255 * 257)
        XCTAssertEqual(stColor.green, 0)
        XCTAssertEqual(stColor.blue, 0)
    }

    func testNSColorHexStringRoundTrip() {
        let hex = HexColor("#3A7BCD")
        let ns = hex.nsColor
        let back = ns.hexString
        XCTAssertEqual(back.uppercased(), "#3A7BCD")
    }
}

// MARK: - ITermColorsParser Tests

final class ITermColorsParserTests: XCTestCase {

    private func makePlist(bg: [CGFloat] = [0, 0, 0], fg: [CGFloat] = [1, 1, 1], cursor: [CGFloat]? = nil, selection: [CGFloat]? = nil, ansi: [[CGFloat]]? = nil) -> Data {
        var dict: [String: Any] = [
            "Background Color": ["Red Component": bg[0], "Green Component": bg[1], "Blue Component": bg[2]],
            "Foreground Color": ["Red Component": fg[0], "Green Component": fg[1], "Blue Component": fg[2]],
        ]
        if let cursor {
            dict["Cursor Color"] = ["Red Component": cursor[0], "Green Component": cursor[1], "Blue Component": cursor[2]]
        }
        if let selection {
            dict["Selection Color"] = ["Red Component": selection[0], "Green Component": selection[1], "Blue Component": selection[2]]
        }
        if let ansi {
            for (i, c) in ansi.enumerated() {
                dict["Ansi \(i) Color"] = ["Red Component": c[0], "Green Component": c[1], "Blue Component": c[2]]
            }
        }
        return try! PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    private func writeTempFile(_ data: Data, name: String = "test.itermcolors") -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try! data.write(to: url)
        return url
    }

    func testParseMinimalPlist() throws {
        let data = makePlist()
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ITermColorsParser.parse(url: url)
        XCTAssertEqual(theme.background.hex, "#000000")
        XCTAssertEqual(theme.foreground.hex, "#FFFFFF")
        XCTAssertEqual(theme.isBuiltIn, false)
    }

    func testParseCursorAndSelection() throws {
        let data = makePlist(cursor: [1, 0, 0], selection: [0, 1, 0])
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ITermColorsParser.parse(url: url)
        XCTAssertEqual(theme.cursor.hex, "#FF0000")
        XCTAssertEqual(theme.selection.hex, "#00FF00")
    }

    func testCursorDefaultsToForeground() throws {
        let data = makePlist(fg: [0.5, 0.5, 0.5])
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ITermColorsParser.parse(url: url)
        XCTAssertEqual(theme.cursor, theme.foreground)
    }

    func testSelectionDefaultsToFallback() throws {
        let data = makePlist()
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ITermColorsParser.parse(url: url)
        XCTAssertEqual(theme.selection.hex, "#3A3A5C")
    }

    func testAnsiColorsParsed() throws {
        let ansi = (0..<16).map { _ in [0.5, 0.5, 0.5] as [CGFloat] }
        let data = makePlist(ansi: ansi)
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ITermColorsParser.parse(url: url)
        XCTAssertEqual(theme.ansiColors.count, 16)
        XCTAssertTrue(theme.ansiColors.allSatisfy { $0.hex == "#808080" })
    }

    func testMissingAnsiColorFallsBackToDefault() throws {
        let data = makePlist()
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ITermColorsParser.parse(url: url)
        XCTAssertEqual(theme.ansiColors.count, 16)
        XCTAssertEqual(theme.ansiColors[0], TerminalTheme.hiveTermDark.ansiColors[0])
    }

    func testIdDerivedFromFilename() throws {
        let data = makePlist()
        let url = writeTempFile(data, name: "My Cool Theme.itermcolors")
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ITermColorsParser.parse(url: url)
        XCTAssertEqual(theme.id, "imported-my-cool-theme")
        XCTAssertEqual(theme.name, "My Cool Theme")
    }

    func testInvalidFormatThrows() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bad.itermcolors")
        try! "not a plist".data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ITermColorsParser.parse(url: url))
    }

    func testMissingRequiredColorsThrows() throws {
        let dict: [String: Any] = ["Foreground Color": ["Red Component": CGFloat(1), "Green Component": CGFloat(1), "Blue Component": CGFloat(1)]]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        let url = writeTempFile(data, name: "incomplete.itermcolors")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ITermColorsParser.parse(url: url)) { error in
            XCTAssertTrue(error is ITermColorsParser.ParseError)
        }
    }
}

// MARK: - ThemeManager Tests

final class ThemeManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "selectedThemeId")
        UserDefaults.standard.removeObject(forKey: "customThemes")
    }

    func testDefaultsToFirstBuiltIn() {
        let manager = ThemeManager()
        XCTAssertEqual(manager.currentTheme.id, TerminalTheme.builtInThemes[0].id)
    }

    func testSelectThemePersists() {
        let manager = ThemeManager()
        let dracula = TerminalTheme.builtInThemes.first { $0.id == "dracula" }!
        manager.selectTheme(dracula)
        XCTAssertEqual(manager.currentTheme.id, "dracula")

        let manager2 = ThemeManager()
        XCTAssertEqual(manager2.currentTheme.id, "dracula")
    }

    func testAllBuiltInsAvailable() {
        let manager = ThemeManager()
        for theme in TerminalTheme.builtInThemes {
            XCTAssertTrue(manager.availableThemes.contains { $0.id == theme.id })
        }
    }

    func testDeleteCustomTheme() {
        let manager = ThemeManager()
        let custom = TerminalTheme(
            id: "test-custom",
            name: "Test Custom",
            isBuiltIn: false,
            background: "#000000",
            foreground: "#FFFFFF",
            cursor: "#FFFFFF",
            selection: "#333333",
            ansiColors: TerminalTheme.hiveTermDark.ansiColors
        )
        manager.availableThemes.append(custom)
        manager.selectTheme(custom)
        XCTAssertEqual(manager.currentTheme.id, "test-custom")

        manager.deleteCustomTheme("test-custom")
        XCTAssertFalse(manager.availableThemes.contains { $0.id == "test-custom" })
        XCTAssertEqual(manager.currentTheme.id, TerminalTheme.builtInThemes[0].id)
    }

    func testDeleteBuiltInThemeIsNoop() {
        let manager = ThemeManager()
        let count = manager.availableThemes.count
        manager.deleteCustomTheme("dracula")
        XCTAssertEqual(manager.availableThemes.count, count, "Should not delete built-in themes")
    }

    func testBuiltInThemesHave16AnsiColors() {
        for theme in TerminalTheme.builtInThemes {
            XCTAssertEqual(theme.ansiColors.count, 16, "\(theme.name) should have 16 ANSI colors")
        }
    }
}

// MARK: - TerminalTheme Derived Colors Tests

final class TerminalThemeDerivedTests: XCTestCase {

    func testEffectiveGridBackgroundUsesCustomIfSet() {
        let theme = TerminalTheme(
            id: "test", name: "Test", isBuiltIn: false,
            background: "#FFFFFF", foreground: "#000000",
            cursor: "#000000", selection: "#333333",
            ansiColors: TerminalTheme.hiveTermDark.ansiColors,
            gridBackground: "#123456"
        )
        let hex = theme.effectiveGridBackground.hexString
        XCTAssertEqual(hex, "#123456")
    }

    func testEffectiveGridBackgroundDerivesFromBg() {
        let theme = TerminalTheme(
            id: "test", name: "Test", isBuiltIn: false,
            background: "#FFFFFF", foreground: "#000000",
            cursor: "#000000", selection: "#333333",
            ansiColors: TerminalTheme.hiveTermDark.ansiColors
        )
        let gridBg = theme.effectiveGridBackground
        let pureBg = HexColor("#FFFFFF").nsColor
        XCTAssertNotEqual(gridBg.hexString, pureBg.hexString, "Should darken background for grid")
    }

    func testEffectiveSidebarBackgroundUsesCustomIfSet() {
        let theme = TerminalTheme(
            id: "test", name: "Test", isBuiltIn: false,
            background: "#000000", foreground: "#FFFFFF",
            cursor: "#FFFFFF", selection: "#333333",
            ansiColors: TerminalTheme.hiveTermDark.ansiColors,
            sidebarBackground: "#ABCDEF"
        )
        let hex = theme.effectiveSidebarBackground.hexString
        XCTAssertEqual(hex, "#ABCDEF")
    }

    func testEffectiveSidebarBackgroundDerivesFromBg() {
        let theme = TerminalTheme(
            id: "test", name: "Test", isBuiltIn: false,
            background: "#000000", foreground: "#FFFFFF",
            cursor: "#FFFFFF", selection: "#333333",
            ansiColors: TerminalTheme.hiveTermDark.ansiColors
        )
        let sidebarBg = theme.effectiveSidebarBackground
        let pureBg = HexColor("#000000").nsColor
        XCTAssertNotEqual(sidebarBg.hexString, pureBg.hexString, "Should lighten background for sidebar")
    }

    func testThemeCodableRoundTrip() throws {
        let original = TerminalTheme.dracula
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TerminalTheme.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
