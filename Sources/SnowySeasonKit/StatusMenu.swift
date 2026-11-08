import AppKit

/// The menu bar icon and its menu for picking what to show.
@MainActor
final class StatusMenu: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onChoose: (Mode?) -> Void
    private var choices: [(mode: Mode?, item: NSMenuItem)] = []

    private static let offSymbolName = "cloud"

    init(selection: Mode?, onChoose: @escaping (Mode?) -> Void) {
        self.onChoose = onChoose
        super.init()
        let menu = NSMenu()
        for mode in Mode.allCases {
            addChoice(mode, title: mode.menuTitle, to: menu)
        }
        addChoice(nil, title: "Off", to: menu)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Snowy Season", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
        show(selection: selection)
    }

    func show(selection: Mode?) {
        for choice in choices {
            choice.item.state = choice.mode == selection ? .on : .off
        }
        let symbol = selection?.symbolName ?? Self.offSymbolName
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Snowy Season")
    }

    private func addChoice(_ mode: Mode?, title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        choices.append((mode, item))
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard let choice = choices.first(where: { $0.item === sender }) else {
            assertionFailure("Menu item \(sender.title) is not a mode choice")
            return
        }
        onChoose(choice.mode)
    }
}
