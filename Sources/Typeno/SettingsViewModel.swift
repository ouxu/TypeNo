import AppKit
import Combine
import Foundation

@MainActor
struct SettingsActions {
    let togglePhoneInput: () -> Void
    let openPhoneInputLink: () -> Void
    let copyPhoneInputLink: () -> Void
    let openAccessibilitySettings: () -> Void
    let checkForUpdates: () -> Void
    let refreshRuntimeStatus: () -> Void
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var phoneInputEnabled = false
    @Published private(set) var phoneInputURL: String?
    @Published private(set) var accessibilityEnabled = false

    private let appState: AppState
    private let actions: SettingsActions
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState, actions: SettingsActions) {
        self.appState = appState
        self.actions = actions

        appState.$phoneBridgeRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                self?.phoneInputEnabled = running
            }
            .store(in: &cancellables)

        appState.$phoneBridgeURL
            .receive(on: RunLoop.main)
            .sink { [weak self] url in
                self?.phoneInputURL = url
            }
            .store(in: &cancellables)

        refresh()
    }

    var phoneInputStatusText: String {
        if phoneInputEnabled, let phoneInputURL {
            return phoneInputURL
        }

        if phoneInputEnabled {
            return L(
                "TypeNo is running, but the local network address is not ready yet.",
                "TypeNo 已在运行，但本地网络地址暂未就绪。"
            )
        }

        return L(
            "Phone input is currently off.",
            "手机输入当前处于关闭状态。"
        )
    }

    var accessibilitySummary: String {
        accessibilityEnabled
            ? L(
                "Direct paste into the active Mac app is ready.",
                "已可直接粘贴到当前 Mac 应用。"
            )
            : L(
                "Without Accessibility, incoming text is copied to the clipboard instead of being pasted automatically.",
                "未开启辅助功能权限时，收到的文字会复制到剪贴板，而不是自动粘贴。"
            )
    }

    func refresh() {
        actions.refreshRuntimeStatus()
        phoneInputEnabled = appState.phoneBridgeRunning
        phoneInputURL = appState.phoneBridgeURL
        accessibilityEnabled = AccessibilityPermissionManager.isGranted()
    }

    func togglePhoneInput() {
        actions.togglePhoneInput()
    }

    func openPhoneInputLink() {
        actions.openPhoneInputLink()
    }

    func copyPhoneInputLink() {
        actions.copyPhoneInputLink()
    }

    func openAccessibilitySettings() {
        actions.openAccessibilitySettings()
    }

    func checkForUpdates() {
        actions.checkForUpdates()
    }
}
