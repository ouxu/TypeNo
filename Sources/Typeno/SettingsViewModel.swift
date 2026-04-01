import AppKit
import AVFoundation
import Combine
import Foundation

@MainActor
struct SettingsActions {
    let togglePhoneInput: () -> Void
    let copyPhoneInputLink: () -> Void
    let checkForUpdates: () -> Void
    let openPrivacySettings: () -> Void
    let refreshRuntimeStatus: () -> Void
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var hotkeyModifier: HotkeyModifier = UserDefaults.standard.hotkeyModifier
    @Published private(set) var triggerMode: TriggerMode = UserDefaults.standard.triggerMode
    @Published private(set) var microphoneSelection: MicrophoneSelection = UserDefaults.standard.microphoneSelection
    @Published private(set) var microphones: [MicrophoneOption] = []
    @Published private(set) var phoneInputEnabled = false
    @Published private(set) var phoneInputURL: String?
    @Published private(set) var microphonePermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var accessibilityEnabled = false
    @Published private(set) var nodeInstalled = false
    @Published private(set) var coliInstalled = false

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

        NotificationCenter.default.publisher(for: .appSettingsChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncStoredSettings()
            }
            .store(in: &cancellables)

        refresh()
    }

    var selectedMicrophoneName: String {
        switch microphoneSelection {
        case .automatic:
            return L("Automatic", "自动")
        case .specific(let uniqueID):
            return microphones.first(where: { $0.uniqueID == uniqueID })?.localizedName
                ?? L("Selected microphone unavailable", "已选麦克风不可用")
        }
    }

    var selectedMicrophoneNeedsAttention: Bool {
        switch microphoneSelection {
        case .automatic:
            return microphones.isEmpty
        case .specific(let uniqueID):
            return microphones.contains(where: { $0.uniqueID == uniqueID }) == false
        }
    }

    var speechEngineReady: Bool {
        accessibilityEnabled && microphonePermissionStatus == .authorized && coliInstalled
    }

    var speechEngineSummary: String {
        if speechEngineReady {
            return L("TypeNo is ready to record, transcribe, and paste.", "TypeNo 已可录音、转录并输入文字。")
        }
        if !nodeInstalled {
            return L("Install Node.js so TypeNo can set up the local Coli engine.", "请先安装 Node.js，TypeNo 才能配置本地 Coli 引擎。")
        }
        if !coliInstalled {
            return L("The local Coli engine is not ready yet.", "本地 Coli 引擎尚未就绪。")
        }
        return L("Permissions still need attention before recording can start.", "开始录音前仍需处理权限。")
    }

    func refresh() {
        syncStoredSettings()
        microphones = MicrophoneManager.availableMicrophones()
        microphonePermissionStatus = PermissionManager.microphoneStatus(requestIfNeeded: false)
        accessibilityEnabled = PermissionManager.accessibilityStatus(requestIfNeeded: false)
        nodeInstalled = ColiASRService.isNpmAvailable
        coliInstalled = ColiASRService.isInstalled
        phoneInputEnabled = appState.phoneBridgeRunning
        phoneInputURL = appState.phoneBridgeURL
    }

    func setHotkeyModifier(_ modifier: HotkeyModifier) {
        AppSettings.setHotkeyModifier(modifier)
        syncStoredSettings()
    }

    func setTriggerMode(_ mode: TriggerMode) {
        AppSettings.setTriggerMode(mode)
        syncStoredSettings()
    }

    func setMicrophoneSelectionID(_ identifier: String) {
        if identifier == Self.automaticMicrophoneID {
            AppSettings.setMicrophoneSelection(.automatic)
        } else {
            AppSettings.setMicrophoneSelection(.specific(identifier))
        }
        refresh()
    }

    func togglePhoneInput() {
        actions.togglePhoneInput()
    }

    func copyPhoneInputLink() {
        actions.copyPhoneInputLink()
    }

    func checkForUpdates() {
        actions.checkForUpdates()
    }

    func openPrivacySettings() {
        actions.openPrivacySettings()
    }

    func refreshStatus() {
        actions.refreshRuntimeStatus()
        refresh()
    }

    func openPermissionSettings(for kind: PermissionKind) {
        PermissionManager.openPrivacySettings(for: [kind])
    }

    var selectedMicrophoneID: String {
        switch microphoneSelection {
        case .automatic:
            return Self.automaticMicrophoneID
        case .specific(let uniqueID):
            return uniqueID
        }
    }

    static let automaticMicrophoneID = "__automatic__"

    private func syncStoredSettings() {
        hotkeyModifier = UserDefaults.standard.hotkeyModifier
        triggerMode = UserDefaults.standard.triggerMode
        microphoneSelection = UserDefaults.standard.microphoneSelection
    }
}
