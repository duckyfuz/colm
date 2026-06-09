import XCTest
@testable import colm

final class ConfigTests: XCTestCase {
    func testEmptyInputYieldsDefaults() {
        XCTAssertEqual(Config.parse(""), Config.default)
    }

    func testParseAllKeys() {
        let source = """
        hotkey_modifier = "control"
        rows_max = 20
        panel_width = 800
        show_minimized = false
        blacklist = ["com.apple.finder", "com.apple.dock"]
        """
        let c = Config.parse(source)
        XCTAssertEqual(c.hotkeyModifier, .control)
        XCTAssertEqual(c.rowsMax, 20)
        XCTAssertEqual(c.panelWidth, 800)
        XCTAssertEqual(c.showMinimized, false)
        XCTAssertEqual(c.blacklist, ["com.apple.finder", "com.apple.dock"])
    }

    func testUnquotedModifierAlsoWorks() {
        let c = Config.parse("hotkey_modifier = command")
        XCTAssertEqual(c.hotkeyModifier, .command)
    }

    func testInvalidModifierKeepsDefault() {
        let c = Config.parse("hotkey_modifier = \"shift\"")
        XCTAssertEqual(c.hotkeyModifier, Config.default.hotkeyModifier)
    }

    func testInvalidNumberKeepsDefault() {
        let c = Config.parse("rows_max = bananas")
        XCTAssertEqual(c.rowsMax, Config.default.rowsMax)
    }

    func testNegativeNumberKeepsDefault() {
        let c = Config.parse("panel_width = -10")
        XCTAssertEqual(c.panelWidth, Config.default.panelWidth)
    }

    func testBoolAliases() {
        XCTAssertEqual(Config.parse("show_minimized = yes").showMinimized, true)
        XCTAssertEqual(Config.parse("show_minimized = off").showMinimized, false)
    }

    func testCommentsAreStripped() {
        let source = """
        # full line comment
        rows_max = 7  # trailing comment
        """
        XCTAssertEqual(Config.parse(source).rowsMax, 7)
    }

    func testHashInsideQuotesIsKept() {
        let c = Config.parse("blacklist = [\"foo#bar\"]")
        XCTAssertEqual(c.blacklist, ["foo#bar"])
    }

    func testMalformedLinesIgnored() {
        let source = """
        this line has no equals
        rows_max = 12
        = no_key
        """
        let c = Config.parse(source)
        XCTAssertEqual(c.rowsMax, 12)
    }

    func testUnknownKeyIgnored() {
        let c = Config.parse("future_setting = \"hello\"\nrows_max = 5")
        XCTAssertEqual(c.rowsMax, 5)
    }

    func testEmptyBlacklist() {
        XCTAssertEqual(Config.parse("blacklist = []").blacklist, [])
    }

    func testDescribeRoundtrips() {
        let original = Config(
            hotkeyModifier: .command,
            rowsMax: 11,
            panelWidth: 720,
            showMinimized: false,
            blacklist: ["com.example.app"]
        )
        XCTAssertEqual(Config.parse(original.describe()), original)
    }
}
