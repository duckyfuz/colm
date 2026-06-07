import AppKit

let version = "0.0.1"

enum Command {
    case run
    case setup
    case version
    case help
    case unknown(String)
}

func parseArgs(_ args: [String]) -> Command {
    guard args.count > 1 else { return .run }
    switch args[1] {
    case "setup": return .setup
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
      colm --version  Print version
      colm --help     Print this message
    """)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Phase 2+ installs event tap and switcher panel here.
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
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
    exit(0)
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
case .unknown(let arg):
    FileHandle.standardError.write(Data("unknown argument: \(arg)\n\n".utf8))
    printUsage()
    exit(2)
case .run:
    runApp()
}
