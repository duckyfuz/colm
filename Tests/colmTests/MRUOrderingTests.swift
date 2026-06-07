import XCTest
@testable import colm

final class MRUOrderingTests: XCTestCase {
    func testUnknownKeysReturnedInInputOrder() {
        let mru = MRUOrdering<String>()
        XCTAssertEqual(mru.order(among: ["a", "b", "c"]), ["a", "b", "c"])
    }

    func testTouchedKeyMovesToFront() {
        var mru = MRUOrdering<String>()
        mru.touch("b")
        XCTAssertEqual(mru.order(among: ["a", "b", "c"]), ["b", "a", "c"])
    }

    func testMostRecentTouchWinsOverEarlier() {
        var mru = MRUOrdering<String>()
        mru.touch("a")
        mru.touch("b")
        mru.touch("c")
        XCTAssertEqual(mru.order(among: ["a", "b", "c"]), ["c", "b", "a"])
    }

    func testReTouchingPromotesAgain() {
        var mru = MRUOrdering<String>()
        mru.touch("a")
        mru.touch("b")
        mru.touch("a")
        XCTAssertEqual(mru.order(among: ["a", "b"]), ["a", "b"])
    }

    func testUnknownKeysSortAfterKnown() {
        var mru = MRUOrdering<String>()
        mru.touch("b")
        XCTAssertEqual(mru.order(among: ["a", "b", "c", "d"]), ["b", "a", "c", "d"])
    }

    func testFilteringDropsAbsentKeys() {
        var mru = MRUOrdering<String>()
        mru.touch("x")
        mru.touch("y")
        XCTAssertEqual(mru.order(among: ["y"]), ["y"])
    }

    func testSeedSetsRecencyFromList() {
        var mru = MRUOrdering<String>()
        mru.seed(from: ["a", "b", "c"])
        XCTAssertEqual(mru.order(among: ["a", "b", "c"]), ["a", "b", "c"])
    }

    func testSeedThenTouchOverridesSeedOrder() {
        var mru = MRUOrdering<String>()
        mru.seed(from: ["a", "b", "c"])
        mru.touch("c")
        XCTAssertEqual(mru.order(among: ["a", "b", "c"]), ["c", "a", "b"])
    }

    func testPruneDropsAbsentKeys() {
        var mru = MRUOrdering<String>()
        mru.touch("a")
        mru.touch("b")
        mru.prune(keeping: ["a"])
        XCTAssertEqual(mru.order(among: ["a", "b"]), ["a", "b"])
    }
}
