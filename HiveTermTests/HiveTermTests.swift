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
        XCTAssertEqual(store.layout, .single, "Group operations must not change ungrouped layout")
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

        // Single-member group is rejected (not added to store.groups)
        let rejected = store.createGroup(sessionIds: [s1.id])
        XCTAssertEqual(rejected.layoutMode, .single)
        XCTAssertEqual(store.groups.count, 0, "1-member group should not persist")

        // 2 members → sideBySide
        let group = store.createGroup(sessionIds: [s1.id, s2.id])
        XCTAssertEqual(group.layoutMode, .sideBySide)

        // 3 and 4 members → grid2x2
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
        // Group with 1 member is auto-dissolved
        XCTAssertEqual(store.groups.count, 0)
    }

    func testRemoveFromGroupDissolvesSmallGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")

        store.createGroup(sessionIds: [s1.id, s2.id])
        XCTAssertEqual(store.groups.count, 1)

        store.removeFromGroup(s1.id)
        // Group with 1 member should auto-dissolve
        XCTAssertEqual(store.groups.count, 0)
        XCTAssertEqual(store.ungroupedSessions.count, 2)
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

// MARK: - Issue 1: Observation Chain Tests
// Verify that @Observable tracking fires across object boundaries.
// The original bug: mutating group.sessionIds didn't trigger updateNSView
// because SwiftUI wasn't detecting the cross-object property change.

import Observation

final class ObservationChainTests: XCTestCase {

    func testObservationFiresOnCrossObjectGroupMutation() {
        // This is the exact scenario that caused the "remove from group" bug.
        // group.sessionIds changes (on SessionGroup), but store.groups doesn't change.
        // Observation must still fire because visibleSessions accessed group.sessionIds.
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")
        store.createGroup(sessionIds: [s1.id, s2.id, s3.id])
        store.selectSession(s1.id)

        var observationFired = false
        withObservationTracking {
            _ = store.visibleSessions
        } onChange: {
            observationFired = true
        }

        // Remove s3: group goes 3→2, store.groups stays the same array
        store.removeFromGroup(s3.id)
        XCTAssertEqual(store.groups.count, 1, "Group should still exist (2 members)")
        XCTAssertTrue(observationFired, "Observation must fire when group.sessionIds changes")
    }

    func testObservationFiresOnGroupDissolution() {
        // When a group dissolves, store.groups changes — observation should definitely fire.
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)

        var observationFired = false
        withObservationTracking {
            _ = store.visibleSessions
            _ = store.currentLayout
        } onChange: {
            observationFired = true
        }

        store.removeFromGroup(s2.id)
        XCTAssertEqual(store.groups.count, 0, "Group should dissolve (1 member)")
        XCTAssertTrue(observationFired, "Observation must fire when group dissolves")
    }

    func testObservationFiresOnLayoutChange() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        _ = store.createSession(name: "B")
        _ = store.createSession(name: "C")
        store.selectSession(s1.id)
        store.layout = .single

        var observationFired = false
        withObservationTracking {
            _ = store.currentLayout
        } onChange: {
            observationFired = true
        }

        store.layout = .grid2x2
        XCTAssertTrue(observationFired, "Observation must fire when layout changes")
    }

    func testObservationFiresOnSelectionChange() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.selectSession(s1.id)

        var observationFired = false
        withObservationTracking {
            _ = store.visibleSessions
        } onChange: {
            observationFired = true
        }

        store.selectSession(s2.id)
        XCTAssertTrue(observationFired, "Observation must fire when selection changes")
    }
}

// MARK: - Issue 3: User Workflow Tests
// Multi-step sequences that mirror real user interactions,
// asserting user-facing state (visibleSessions, currentLayout) at each step.

final class UserWorkflowTests: XCTestCase {

    /// User creates 3 sessions, groups 2 of them, then right-clicks "Remove from Group"
    func testWorkflowGroupThenRemove() {
        let store = SessionStore()
        let s1 = store.createSession(name: "Claude")
        let s2 = store.createSession(name: "Copilot")
        let _ = store.createSession(name: "Codex")

        // Step 1: User drags Copilot onto Claude to create a group
        store.dropSession(s2.id, onto: s1.id)
        store.selectSession(s1.id)

        // Verify: 2 terminals visible side-by-side
        XCTAssertEqual(store.visibleSessions.map(\.name), ["Claude", "Copilot"])
        XCTAssertEqual(store.currentLayout, .sideBySide)

        // Step 2: User right-clicks Copilot → "Remove from Group"
        store.removeFromGroup(s2.id)

        // Verify: group dissolved, back to ungrouped single-pane view
        XCTAssertNil(store.activeGroup, "No active group after dissolution")
        // store.layout stays .single (group ops don't change it), 3 ungrouped sessions
        XCTAssertEqual(store.currentLayout, .single)
        XCTAssertEqual(store.visibleSessions.count, 1)
    }

    /// User builds up a 4-pane grid, then removes sessions one by one
    func testWorkflowBuildGridThenShrink() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")
        let s4 = store.createSession(name: "D")

        store.createGroup(sessionIds: [s1.id, s2.id, s3.id, s4.id])
        store.selectSession(s1.id)

        // 4 panes in grid
        XCTAssertEqual(store.visibleSessions.count, 4)
        XCTAssertEqual(store.currentLayout, .grid2x2)

        // Remove D: 4→3, still grid2x2
        store.removeFromGroup(s4.id)
        XCTAssertEqual(store.visibleSessions.count, 3)
        XCTAssertEqual(store.currentLayout, .grid2x2)

        // Remove C: 3→2, switches to sideBySide
        store.removeFromGroup(s3.id)
        XCTAssertEqual(store.visibleSessions.count, 2)
        XCTAssertEqual(store.currentLayout, .sideBySide)

        // Remove B: 2→1, group dissolves
        store.removeFromGroup(s2.id)
        XCTAssertNil(store.activeGroup)
        // 4 ungrouped sessions, store.layout = .single (default, unmodified by groups)
        XCTAssertEqual(store.currentLayout, .single)
    }

    /// User groups two sessions, then closes one via the sidebar
    func testWorkflowCloseSessionInGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let _ = store.createSession(name: "C")

        store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)
        XCTAssertEqual(store.currentLayout, .sideBySide)

        // Close s2 entirely (not just ungroup)
        store.removeSession(s2.id)

        // Group dissolved (1 member), s2 gone from sessions
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertNil(store.activeGroup)
        // s1 still selected
        XCTAssertEqual(store.selectedSessionId, s1.id)
    }

    /// User uses groupSelectedWith from context menu
    func testWorkflowGroupSelectedWith() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.selectSession(s1.id)

        // Step 1: "Group with B" from context menu
        store.groupSelectedWith(s2.id)

        // Verify: group created, s1 still selected, side-by-side
        XCTAssertEqual(store.selectedSessionId, s1.id)
        XCTAssertEqual(store.visibleSessions.count, 2)
        XCTAssertEqual(store.currentLayout, .sideBySide)

        // Step 2: Ungroup s2
        store.removeFromGroup(s2.id)

        // Group dissolved, back to ungrouped
        XCTAssertNil(store.activeGroup)
    }
}

// MARK: - Issue 4: Boundary Transition Tests
// Systematically test every group member count transition
// and every layout boundary, asserting on user-facing derived state.

final class BoundaryTransitionTests: XCTestCase {

    // MARK: - Group member transitions: assert visibleSessions + currentLayout

    func testGroupTransition4to3() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")
        let s4 = store.createSession(name: "D")
        store.createGroup(sessionIds: [s1.id, s2.id, s3.id, s4.id])
        store.selectSession(s1.id)

        store.removeFromGroup(s4.id)

        XCTAssertEqual(store.visibleSessions.count, 3)
        XCTAssertEqual(store.currentLayout, .grid2x2, "3 members still use grid2x2")
        XCTAssertNotNil(store.activeGroup, "Group survives with 3 members")
    }

    func testGroupTransition3to2() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")
        store.createGroup(sessionIds: [s1.id, s2.id, s3.id])
        store.selectSession(s1.id)

        store.removeFromGroup(s3.id)

        XCTAssertEqual(store.visibleSessions.count, 2)
        XCTAssertEqual(store.currentLayout, .sideBySide, "2 members switch to sideBySide")
        XCTAssertNotNil(store.activeGroup, "Group survives with 2 members")
    }

    func testGroupTransition2to1Dissolves() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)

        store.removeFromGroup(s2.id)

        XCTAssertNil(store.activeGroup, "Group must dissolve at 1 member")
        // Both sessions now ungrouped. store.layout = .single (default, unchanged by groups).
        // currentLayout: count=2, layout=.single → .single
        XCTAssertEqual(store.currentLayout, .single)
        XCTAssertEqual(store.visibleSessions.count, 1)
    }

    // MARK: - Ungrouped layout capping boundaries

    func testUngroupedLayoutCap0Sessions() {
        let store = SessionStore()
        store.layout = .grid2x2
        // No sessions at all
        XCTAssertEqual(store.visibleSessions.count, 0)
    }

    func testUngroupedLayoutCap1Session() {
        let store = SessionStore()
        _ = store.createSession(name: "A")
        store.layout = .grid2x2
        XCTAssertEqual(store.currentLayout, .single, "1 session always caps to single")
    }

    func testUngroupedLayoutCap2SessionsSideBySide() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        _ = store.createSession(name: "B")
        store.layout = .sideBySide
        store.selectSession(s1.id)
        // 2 sessions with sideBySide → no capping needed
        XCTAssertEqual(store.currentLayout, .sideBySide)
    }

    func testUngroupedLayoutCap2SessionsGridCappedToSideBySide() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        _ = store.createSession(name: "B")
        store.layout = .grid2x2
        store.selectSession(s1.id)
        // 2 sessions with grid2x2 → capped to sideBySide
        XCTAssertEqual(store.currentLayout, .sideBySide)
    }

    func testUngroupedLayoutExactly4SessionsGrid() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        _ = store.createSession(name: "B")
        _ = store.createSession(name: "C")
        _ = store.createSession(name: "D")
        store.layout = .grid2x2
        store.selectSession(s1.id)
        XCTAssertEqual(store.currentLayout, .grid2x2)
        XCTAssertEqual(store.visibleSessions.count, 4)
    }
}

// MARK: - Issue 5: Contract-Based Tests
// Assert on user-facing outcomes (visibleSessions, currentLayout, activeGroup)
// rather than implementation details (groups.count, sessionIds).

final class ContractTests: XCTestCase {

    // MARK: - removeSession contract

    func testRemoveNonSelectedSessionPreservesView() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.selectSession(s1.id)
        store.layout = .sideBySide

        let visibleBefore = store.visibleSessions.map(\.name)
        store.removeSession(s2.id)

        // Contract: selection unchanged, visible sessions update to reflect removal
        XCTAssertEqual(store.selectedSessionId, s1.id)
        XCTAssertEqual(store.visibleSessions.count, 1)
        XCTAssertFalse(store.visibleSessions.contains { $0.name == "B" })
        XCTAssertNotEqual(visibleBefore, store.visibleSessions.map(\.name))
    }

    func testRemoveLastSessionLeavesEmptyView() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")

        store.removeSession(s1.id)

        // Contract: no selection, no visible sessions
        XCTAssertNil(store.selectedSessionId)
        XCTAssertTrue(store.visibleSessions.isEmpty)
    }

    // MARK: - Group dissolution contract

    func testRemoveFromGroupUpdatesVisibleState() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)

        // Contract before: grouped view
        XCTAssertNotNil(store.activeGroup)
        XCTAssertEqual(store.currentLayout, .sideBySide)

        store.removeFromGroup(s1.id)

        // Contract after: no group, layout reflects ungrouped default (.single)
        XCTAssertNil(store.activeGroup)
        XCTAssertEqual(store.currentLayout, .single)
        XCTAssertEqual(store.visibleSessions.count, 1)
    }

    func testRemoveSessionFromGroupUpdatesVisibleState() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)

        store.removeSession(s2.id)

        // Contract: group dissolved, s2 gone entirely
        XCTAssertNil(store.activeGroup)
        XCTAssertEqual(store.visibleSessions.count, 1)
        XCTAssertEqual(store.visibleSessions[0].name, "A")
    }

    // MARK: - createGroup contract

    func testCreateGroupStealsFromOtherGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")

        store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)
        XCTAssertEqual(store.visibleSessions.count, 2)

        // Steal s1 into new group with s3
        store.createGroup(sessionIds: [s1.id, s3.id])
        store.selectSession(s1.id)

        // Contract: s1 is now in new group with s3, old group dissolved
        XCTAssertEqual(store.visibleSessions.map(\.name).sorted(), ["A", "C"])
        XCTAssertEqual(store.currentLayout, .sideBySide)
    }

    // MARK: - groupSelectedWith contract

    func testGroupSelectedWithCreatesVisibleGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.selectSession(s1.id)

        store.groupSelectedWith(s2.id)

        // Contract: both sessions visible, side-by-side, s1 still selected
        XCTAssertEqual(store.selectedSessionId, s1.id)
        XCTAssertEqual(store.visibleSessions.count, 2)
        XCTAssertEqual(store.currentLayout, .sideBySide)
    }

    func testGroupSelectedWithSelfChangesNothing() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        _ = store.createSession(name: "B")
        store.selectSession(s1.id)
        store.layout = .single

        let visibleBefore = store.visibleSessions.map(\.name)
        let layoutBefore = store.currentLayout

        store.groupSelectedWith(s1.id)

        // Contract: nothing changes
        XCTAssertEqual(store.visibleSessions.map(\.name), visibleBefore)
        XCTAssertEqual(store.currentLayout, layoutBefore)
        XCTAssertNil(store.activeGroup)
    }

    // MARK: - visibleSessions swap contract

    func testSwapReplacesLastSlotNotFirst() {
        let store = SessionStore()
        let _ = store.createSession(name: "A")
        let _ = store.createSession(name: "B")
        let _ = store.createSession(name: "C")
        let _ = store.createSession(name: "D")
        let s5 = store.createSession(name: "E")

        store.layout = .grid2x2
        store.selectSession(s5.id)

        // Contract: A, B, C stay stable in their positions. E replaces D (last slot).
        let visible = store.visibleSessions.map(\.name)
        XCTAssertEqual(visible, ["A", "B", "C", "E"])
    }

    // MARK: - selectSessionByIndex contract

    func testSelectSessionByIndexUpdatesView() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        store.layout = .single
        store.selectSession(s1.id)
        XCTAssertEqual(store.visibleSessions.map(\.name), ["A"])

        store.selectSessionByIndex(0) // selects A (first in sessions array)
        XCTAssertEqual(store.selectedSessionId, s1.id)

        store.selectSessionByIndex(1)
        XCTAssertEqual(store.selectedSessionId, s2.id)
        XCTAssertEqual(store.visibleSessions.map(\.name), ["B"])
    }

    func testSelectSessionByIndexBoundsAreNoOp() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        store.selectSession(s1.id)
        let viewBefore = store.visibleSessions.map(\.name)

        store.selectSessionByIndex(-1)
        store.selectSessionByIndex(99)

        XCTAssertEqual(store.selectedSessionId, s1.id)
        XCTAssertEqual(store.visibleSessions.map(\.name), viewBefore)
    }

    // MARK: - waitingCount contract

    func testWaitingCountReflectsUserFacingState() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        _ = store.createSession(name: "C")

        XCTAssertEqual(store.waitingCount, 0)

        s1.status = .waiting
        s2.status = .waiting
        XCTAssertEqual(store.waitingCount, 2)

        s1.status = .running
        XCTAssertEqual(store.waitingCount, 1)
    }

    // MARK: - addToGroup idempotency contract

    func testAddToGroupTwiceDoesNotDuplicate() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")

        let group = store.createGroup(sessionIds: [s1.id, s2.id])
        store.selectSession(s1.id)
        let visibleBefore = store.visibleSessions.count

        store.addToGroup(group.id, sessionId: s1.id)

        // Contract: visible state unchanged, no duplicate
        XCTAssertEqual(store.visibleSessions.count, visibleBefore)
    }

    // MARK: - dropSession reorder contract

    func testDropReorderPreservesVisibleSessions() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")

        store.createGroup(sessionIds: [s1.id, s2.id, s3.id])
        store.selectSession(s1.id)

        // Drag A onto C (move forward within group)
        store.dropSession(s1.id, onto: s3.id)

        // Contract: same 3 sessions visible, different order
        let visible = store.visibleSessions.map(\.name)
        XCTAssertEqual(Set(visible), Set(["A", "B", "C"]))
        XCTAssertEqual(visible, ["B", "C", "A"], "A should move after C")
    }

    func testDropReorderBackwardWithinGroup() {
        let store = SessionStore()
        let s1 = store.createSession(name: "A")
        let s2 = store.createSession(name: "B")
        let s3 = store.createSession(name: "C")

        store.createGroup(sessionIds: [s1.id, s2.id, s3.id])
        store.selectSession(s1.id)

        // Drag C onto A (move backward)
        store.dropSession(s3.id, onto: s1.id)

        let visible = store.visibleSessions.map(\.name)
        XCTAssertEqual(visible, ["C", "A", "B"], "C should move before A")
    }

    // MARK: - session(for:) contract

    func testSessionForUnknownIdReturnsNil() {
        let store = SessionStore()
        _ = store.createSession(name: "A")
        XCTAssertNil(store.session(for: UUID()))
    }

    // MARK: - Persistence contract (Issue 2: traced through code)

    func testSaveRestoreWithNilSelection() {
        // Traced through restoreIfAvailable():
        // 1. createSession("A") → sets selectedSessionId = newSession.id
        // 2. snapshot.selectedIndex is nil → `if let idx` fails → no override
        // Result: selectedSessionId = the restored session's id
        let store1 = SessionStore()
        _ = store1.createSession(name: "A")
        store1.selectedSessionId = nil
        store1.save()

        let store2 = SessionStore()
        store2.restoreIfAvailable()
        XCTAssertEqual(store2.sessions.count, 1)
        XCTAssertEqual(store2.selectedSessionId, store2.sessions[0].id,
                       "createSession always sets selection; nil snapshot index doesn't override")
    }

    func testSaveRestoreWithOutOfBoundsSelectedIndex() {
        // Traced through restoreIfAvailable():
        // 1. createSession("A"), createSession("B") → selectedSessionId = sessions[1].id
        // 2. snapshot.selectedIndex = 99 → guard fails (99 >= 2) → skips
        // Result: selectedSessionId stays as sessions[1].id (set by last createSession)
        let snapshot = """
        {"sessionNames":["A","B"],"selectedIndex":99,"groups":[],"layout":"single","fontSize":13}
        """
        UserDefaults.standard.set(snapshot.data(using: .utf8), forKey: "sessionStoreSnapshot")

        let store = SessionStore()
        store.restoreIfAvailable()
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertEqual(store.selectedSessionId, store.sessions[1].id,
                       "Out-of-bounds index skipped; last createSession wins")
    }

    func testSaveRestoreWithInvalidGroupIndices() {
        // Traced through restoreIfAvailable():
        // 1. Sessions restored: [A, B]
        // 2. Group indices [0, 99]: compactMap filters 99 (>= 2) → ids = [sessions[0].id]
        // 3. ids.count = 1 < 2 → group NOT created
        // Result: no groups
        let snapshot = """
        {"sessionNames":["A","B"],"selectedIndex":0,"groups":[{"name":"Bad","sessionIndices":[0,99]}],"layout":"single","fontSize":13}
        """
        UserDefaults.standard.set(snapshot.data(using: .utf8), forKey: "sessionStoreSnapshot")

        let store = SessionStore()
        store.restoreIfAvailable()
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertNil(store.activeGroup, "Group with only 1 valid index should not be created")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "sessionStoreSnapshot")
        super.tearDown()
    }
}

// MARK: - SessionGroup Layout Mode Boundaries

final class SessionGroupLayoutTests: XCTestCase {

    func testLayoutModeEmptyGroup() {
        let group = SessionGroup(name: "Empty", sessionIds: [])
        XCTAssertEqual(group.layoutMode, .single)
    }

    func testLayoutModeThreeMembers() {
        let group = SessionGroup(name: "Three", sessionIds: [UUID(), UUID(), UUID()])
        XCTAssertEqual(group.layoutMode, .grid2x2)
    }

    func testLayoutModeFiveMembers() {
        let ids = (0..<5).map { _ in UUID() }
        let group = SessionGroup(name: "Five", sessionIds: ids)
        XCTAssertEqual(group.layoutMode, .grid2x2)
    }
}

// MARK: - InputDetector Pattern Coverage

final class InputDetectorPatternTests: XCTestCase {

    private func assertDetects(_ text: String, file: StaticString = #file, srcLine: UInt = #line) {
        let session = TerminalSession(name: "Test")
        session.status = .running
        InputDetector.checkLineForInputPrompt(text, session: session)
        XCTAssertEqual(session.status, .waiting, "Should detect: \(text)", file: file, line: srcLine)
    }

    private func assertIgnores(_ text: String, file: StaticString = #file, srcLine: UInt = #line) {
        let session = TerminalSession(name: "Test")
        session.status = .running
        InputDetector.checkLineForInputPrompt(text, session: session)
        XCTAssertEqual(session.status, .running, "Should ignore: \(text)", file: file, line: srcLine)
    }

    // All 10 patterns
    func testPasswordPrompt() { assertDetects("Password:") }
    func testPasswordCaseInsensitive() { assertDetects("password :") }
    func testPassphrasePrompt() { assertDetects("Enter passphrase:") }
    func testPassphraseCaseInsensitive() { assertDetects("PASSPHRASE :") }
    func testYesNoParens() { assertDetects("Are you sure? (y/n)") }
    func testYesNoLongParens() { assertDetects("Continue? (yes/no)") }
    func testYNBracketUpperY() { assertDetects("Proceed? [Y/n]") }
    func testYNBracketLowerY() { assertDetects("Overwrite? [y/N]") }
    func testSudoPrompt() { assertDetects("[sudo] password for user:") }
    func testSudoCaseInsensitive() { assertDetects("[SUDO] enter password:") }
    func testContinueConnecting() { assertDetects("Are you sure you want to continue connecting?") }
    func testDoYouWantTo() { assertDetects("Do you want to install this package?") }
    func testProceed() { assertDetects("Do you wish to proceed?") }

    // Edge cases
    func testEmptyStringIsNoop() {
        let session = TerminalSession(name: "Test")
        session.status = .running
        InputDetector.checkLineForInputPrompt("", session: session)
        XCTAssertEqual(session.status, .running)
    }

    // Negative cases
    func testShellPromptIgnored() { assertIgnores("$ ls -la") }
    func testRegularOutputIgnored() { assertIgnores("Compiling main.swift...") }
    func testGitLogIgnored() { assertIgnores("commit abc123") }
}

// MARK: - ThemeManager Import Tests

final class ThemeManagerImportTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "selectedThemeId")
        UserDefaults.standard.removeObject(forKey: "customThemes")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "selectedThemeId")
        UserDefaults.standard.removeObject(forKey: "customThemes")
        super.tearDown()
    }

    private func makeMinimalPlist() -> Data {
        let dict: [String: Any] = [
            "Background Color": ["Red Component": CGFloat(0), "Green Component": CGFloat(0), "Blue Component": CGFloat(0)],
            "Foreground Color": ["Red Component": CGFloat(1), "Green Component": CGFloat(1), "Blue Component": CGFloat(1)],
        ]
        return try! PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    func testImportDuplicateGetsDedupedId() throws {
        let data = makeMinimalPlist()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Dupe Theme.itermcolors")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let manager = ThemeManager()
        let countBefore = manager.availableThemes.count

        try manager.importITermColors(from: url)
        let firstId = manager.currentTheme.id
        XCTAssertEqual(manager.availableThemes.count, countBefore + 1)

        try manager.importITermColors(from: url)
        let secondId = manager.currentTheme.id
        XCTAssertEqual(manager.availableThemes.count, countBefore + 2)
        XCTAssertNotEqual(firstId, secondId, "Duplicate import should get a different ID")
    }

    func testImportedThemePersistsAcrossInstances() throws {
        let data = makeMinimalPlist()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Persist Theme.itermcolors")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let manager1 = ThemeManager()
        try manager1.importITermColors(from: url)
        let importedId = manager1.currentTheme.id

        let manager2 = ThemeManager()
        XCTAssertTrue(manager2.availableThemes.contains { $0.id == importedId }, "Imported theme should persist")
        XCTAssertEqual(manager2.currentTheme.id, importedId, "Selected theme should persist")
    }
}
