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
        // Phase 1+ will install permission checks, event tap, and panel here.
    }
}

func runApp() -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
    exit(0)
}

switch parseArgs(CommandLine.arguments) {
case .version:
    print("colm \(version)")
    exit(0)
case .help:
    printUsage()
    exit(0)
case .setup:
    print("colm setup: TODO — implemented in Phase 1")
    exit(0)
case .unknown(let arg):
    FileHandle.standardError.write(Data("unknown argument: \(arg)\n\n".utf8))
    printUsage()
    exit(2)
case .run:
    runApp()
}
