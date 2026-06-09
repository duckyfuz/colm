import Foundation

/// User-facing settings, loaded from `~/.config/colm/config.toml`.
///
/// The "TOML" here is a deliberately small subset — one key per line,
/// `#` for comments, scalars and one-dimensional string arrays only.
/// A real TOML library would be overkill for five settings and would
/// pull in a dependency we don't want.
struct Config: Equatable {
    enum HotkeyModifier: String, Equatable {
        case option
        case control
        case command
    }

    var hotkeyModifier: HotkeyModifier
    var rowsMax: Int
    var panelWidth: Int
    var showMinimized: Bool
    var blacklist: [String]

    static let `default` = Config(
        hotkeyModifier: .option,
        rowsMax: 9,
        panelWidth: 640,
        showMinimized: true,
        blacklist: []
    )

    /// Default path: `$XDG_CONFIG_HOME/colm/config.toml`, falling back to
    /// `~/.config/colm/config.toml`.
    static var defaultPath: URL {
        let env = ProcessInfo.processInfo.environment
        let base: URL
        if let xdg = env["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg, isDirectory: true)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
        }
        return base.appendingPathComponent("colm", isDirectory: true)
            .appendingPathComponent("config.toml")
    }

    /// Load from `path`, falling back to defaults for missing keys.
    /// Missing file → all defaults. Malformed lines are skipped silently
    /// (we don't want a typo to brick the daemon).
    static func load(from path: URL = Config.defaultPath) -> Config {
        guard let raw = try? String(contentsOf: path, encoding: .utf8) else {
            return .default
        }
        return parse(raw)
    }

    static func parse(_ source: String) -> Config {
        var config = Config.default
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = stripComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            apply(key: key, value: value, into: &config)
        }
        return config
    }

    private static func apply(key: String, value: String, into config: inout Config) {
        switch key {
        case "hotkey_modifier":
            if let modifier = HotkeyModifier(rawValue: unquoted(value)) {
                config.hotkeyModifier = modifier
            }
        case "rows_max":
            if let n = Int(value), n > 0 { config.rowsMax = n }
        case "panel_width":
            if let n = Int(value), n > 0 { config.panelWidth = n }
        case "show_minimized":
            if let b = parseBool(value) { config.showMinimized = b }
        case "blacklist":
            config.blacklist = parseStringArray(value)
        default:
            // Unknown key — ignore so we can add settings without bumping
            // existing users' configs.
            break
        }
    }

    private static func stripComment(_ line: String) -> String {
        // Strip `#` and everything after, but only outside a quoted span.
        var inQuote = false
        var out = ""
        for ch in line {
            if ch == "\"" { inQuote.toggle() }
            if ch == "#" && !inQuote { break }
            out.append(ch)
        }
        return out
    }

    private static func unquoted(_ s: String) -> String {
        guard s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 else { return s }
        return String(s.dropFirst().dropLast())
    }

    private static func parseBool(_ s: String) -> Bool? {
        switch s.lowercased() {
        case "true", "yes", "on": return true
        case "false", "no", "off": return false
        default: return nil
        }
    }

    private static func parseStringArray(_ s: String) -> [String] {
        guard s.hasPrefix("["), s.hasSuffix("]") else { return [] }
        let inner = s.dropFirst().dropLast()
        return inner.split(separator: ",").map {
            unquoted($0.trimmingCharacters(in: .whitespaces))
        }.filter { !$0.isEmpty }
    }

    /// Pretty-print the effective config for `colm config`.
    func describe() -> String {
        let bl = blacklist.isEmpty
            ? "[]"
            : "[" + blacklist.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
        return """
        hotkey_modifier = "\(hotkeyModifier.rawValue)"
        rows_max = \(rowsMax)
        panel_width = \(panelWidth)
        show_minimized = \(showMinimized)
        blacklist = \(bl)
        """
    }
}
