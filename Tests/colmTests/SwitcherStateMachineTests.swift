import XCTest
@testable import colm

final class SwitcherStateMachineTests: XCTestCase {
    func testInvokeWithMultipleWindowsLandsOnIndexOne() {
        var sm = SwitcherStateMachine()
        let effect = sm.handle(.optionTabDown(windowCount: 5))
        XCTAssertEqual(effect, .show(selectionIndex: 1))
        XCTAssertEqual(sm.state, .cycling(selectionIndex: 1, count: 5))
    }

    func testInvokeWithSingleWindowLandsOnIndexZero() {
        var sm = SwitcherStateMachine()
        let effect = sm.handle(.optionTabDown(windowCount: 1))
        XCTAssertEqual(effect, .show(selectionIndex: 0))
    }

    func testInvokeWithZeroWindowsIsIgnored() {
        var sm = SwitcherStateMachine()
        XCTAssertNil(sm.handle(.optionTabDown(windowCount: 0)))
        XCTAssertEqual(sm.state, .idle)
    }

    func testTabAdvancesForwardWithWrap() {
        var sm = SwitcherStateMachine()
        _ = sm.handle(.optionTabDown(windowCount: 3))
        XCTAssertEqual(sm.handle(.tabDown), .move(to: 2))
        XCTAssertEqual(sm.handle(.tabDown), .move(to: 0))
        XCTAssertEqual(sm.handle(.tabDown), .move(to: 1))
    }

    func testShiftTabMovesBackwardWithWrap() {
        var sm = SwitcherStateMachine()
        _ = sm.handle(.optionTabDown(windowCount: 3))
        XCTAssertEqual(sm.handle(.shiftTabDown), .move(to: 0))
        XCTAssertEqual(sm.handle(.shiftTabDown), .move(to: 2))
        XCTAssertEqual(sm.handle(.shiftTabDown), .move(to: 1))
    }

    func testOptionUpCommitsCurrentSelection() {
        var sm = SwitcherStateMachine()
        _ = sm.handle(.optionTabDown(windowCount: 4))
        _ = sm.handle(.tabDown)
        XCTAssertEqual(sm.handle(.optionUp), .commit(index: 2))
        XCTAssertEqual(sm.state, .idle)
    }

    func testEscapeCancelsWithoutCommitting() {
        var sm = SwitcherStateMachine()
        _ = sm.handle(.optionTabDown(windowCount: 3))
        XCTAssertEqual(sm.handle(.escDown), .cancel)
        XCTAssertEqual(sm.state, .idle)
    }

    func testOptionUpWhileIdleIsIgnored() {
        var sm = SwitcherStateMachine()
        XCTAssertNil(sm.handle(.optionUp))
        XCTAssertEqual(sm.state, .idle)
    }

    func testTabWhileIdleIsIgnored() {
        var sm = SwitcherStateMachine()
        XCTAssertNil(sm.handle(.tabDown))
        XCTAssertEqual(sm.state, .idle)
    }

    func testRepeatedOptionTabWhileCyclingIsIgnored() {
        var sm = SwitcherStateMachine()
        _ = sm.handle(.optionTabDown(windowCount: 3))
        XCTAssertNil(sm.handle(.optionTabDown(windowCount: 7)))
        XCTAssertEqual(sm.state, .cycling(selectionIndex: 1, count: 3))
    }

    func testReinvocationAfterCommit() {
        var sm = SwitcherStateMachine()
        _ = sm.handle(.optionTabDown(windowCount: 3))
        _ = sm.handle(.optionUp)
        XCTAssertEqual(sm.handle(.optionTabDown(windowCount: 2)), .show(selectionIndex: 1))
    }
}
