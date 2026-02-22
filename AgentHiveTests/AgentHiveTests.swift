import XCTest
@testable import AgentHive

final class AgentHiveTests: XCTestCase {

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
}
