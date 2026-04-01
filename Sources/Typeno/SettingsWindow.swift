import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    let viewModel: SettingsViewModel

    init(appState: AppState, actions: SettingsActions) {
        viewModel = SettingsViewModel(appState: appState, actions: actions)

        let hostingController = NSHostingController(rootView: SettingsView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = L("Settings", "设置")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titleVisibility = .visible
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 760, height: 660))
        window.minSize = NSSize(width: 720, height: 620)
        window.setFrameAutosaveName("TypeNoSettingsWindow")
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        guard let window else { return }
        viewModel.refresh()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
