import AppKit

let version = "0.0.1"

enum Command {
    case run
    case setup
    case list
    case config
    case version
    case help
    case unknown(String)
}

func parseArgs(_ args: [String]) -> Command {
    guard args.count > 1 else { return .run }
    switch args[1] {
    case "setup": return .setup
    case "list": return .list
    case "config": return .config
    case "--version", "-v": return .version
    case "--help", "-h": return .help
    default: return .unknown(args[1])
    }
}

func printUsage() {
    print("""
    colm — macOS window switcher

    Usage:
      colm            Run the switcher (foreground daemon)
      colm setup      Walk through Accessibility permission setup
      colm list       Print enumerated windows (debug)
      colm config     Print the effective configuration
      colm --version  Print version
      colm --help     Print this message
    """)
}

final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyEngineDelegate {
    let config: Config

    private var tracker: WindowTracker?
    private var enumerator: WindowEnumerator?
    private var engine: HotkeyEngine?
    private var panel: SwitcherPanel?
    private let model: SwitcherViewModel
    private var currentSnapshot: [WindowInfo] = []

    init(config: Config) {
        self.config = config
        self.model = SwitcherViewModel(
            panelWidth: CGFloat(config.panelWidth),
            maxVisibleRows: config.rowsMax
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        tracker = WindowTracker()
        let enumerator = WindowEnumerator()
        enumerator.blacklist = Set(config.blacklist)
        enumerator.includeMinimized = config.showMinimized
        self.enumerator = enumerator
        panel = SwitcherPanel(model: model)
        let engine = HotkeyEngine(delegate: self, modifier: config.hotkeyModifier)
        if !engine.start() {
            FileHandle.standardError.write(Data("colm: failed to install event tap — is Accessibility granted?\n".utf8))
            NSApp.terminate(nil)
            return
        }
        self.engine = engine
        FileHandle.standardError.write(Data("colm: ready. Hold the configured modifier and press ⇥ to cycle. ⌃C to quit.\n".utf8))
    }

    // MARK: - HotkeyEngineDelegate

    func hotkeyEngineRequestsWindowCount() -> Int {
        guard let enumerator = enumerator else { return 0 }
        let snapshot = enumerator.snapshot()
        let ordered = tracker?.order(snapshot) ?? snapshot
        currentSnapshot = ordered
        return ordered.count
    }

    func hotkeyEngine(didEmit effect: SwitcherStateMachine.Effect) {
        switch effect {
        case .show(let idx):
            model.update(windows: currentSnapshot, selectionIndex: idx)
            panel?.present()
        case .move(let idx):
            model.selectionIndex = idx
        case .commit(let idx):
            panel?.dismiss()
            if let w = currentSnapshot[safe: idx] {
                WindowActivator.activate(w)
                tracker?.touch(w)
            }
        case .cancel:
            panel?.dismiss()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

func runApp() -> Never {
    if !Permissions.isTrusted() {
        FileHandle.standardError.write(Data("""
            colm: Accessibility permission is required.

            Run `colm setup` to grant it, then start colm again.

            """.utf8))
        exit(1)
    }
    let config = Config.load()
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate(config: config)
    app.delegate = delegate
    app.run()
    exit(0)
}

func runConfig() -> Never {
    let config = Config.load()
    print(config.describe())
    exit(0)
}

func runList() -> Never {
    guard Permissions.isTrusted() else {
        FileHandle.standardError.write(Data("""
            colm: Accessibility permission is required.

            Run `colm setup` to grant it, then try again.

            """.utf8))
        exit(1)
    }

    let config = Config.load()
    let enumerator = WindowEnumerator()
    enumerator.blacklist = Set(config.blacklist)
    enumerator.includeMinimized = config.showMinimized
    let windows = enumerator.snapshot()
    if windows.isEmpty {
        print("No switchable windows found.")
        exit(0)
    }

    let appWidth = max(3, windows.map { $0.appName.count }.max() ?? 3)
    let pidHeader = "PID"
    let minHeader = "Min"
    print("\(pidHeader.padded(6)) \(minHeader.padded(4)) \("App".padded(appWidth))  Title")
    print(String(repeating: "-", count: 6 + 1 + 4 + 1 + appWidth + 2 + 5))
    for w in windows {
        let pidStr = "\(w.pid)".padded(6)
        let minStr = (w.isMinimized ? "*" : "").padded(4)
        let appStr = w.appName.padded(appWidth)
        let title = w.title.isEmpty ? "(untitled)" : w.title
        print("\(pidStr) \(minStr) \(appStr)  \(title)")
    }
    exit(0)
}

private extension String {
    func padded(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}

func runSetup() -> Never {
    print("""
    colm setup — Accessibility permission

    colm needs the Accessibility permission to read window titles and
    listen for the ⌥⇥ hotkey. Screen Recording is NOT required.

    """)

    if Permissions.isTrusted() {
        print("Already granted. You're all set — start colm with `colm`.")
        exit(0)
    }

    print("Opening System Settings → Privacy & Security → Accessibility...")
    Permissions.promptIfNeeded()
    Permissions.openAccessibilityPane()

    print("""

    In the panel that just opened:
      1. Click the + button.
      2. Add the `colm` binary (or your terminal, if running via `swift run`).
      3. Toggle it on.

    Waiting up to 60 seconds for permission to be granted...
    """)

    if Permissions.waitUntilTrusted(timeout: 60) {
        print("\nGranted. You can now run colm.")
        exit(0)
    } else {
        FileHandle.standardError.write(Data("""

            Timed out waiting for permission. Re-run `colm setup` once
            you've granted access.

            """.utf8))
        exit(1)
    }
}

switch parseArgs(CommandLine.arguments) {
case .version:
    print("colm \(version)")
    exit(0)
case .help:
    printUsage()
    exit(0)
case .setup:
    runSetup()
case .list:
    runList()
case .config:
    runConfig()
case .unknown(let arg):
    FileHandle.standardError.write(Data("unknown argument: \(arg)\n\n".utf8))
    printUsage()
    exit(2)
case .run:
    runApp()
}
