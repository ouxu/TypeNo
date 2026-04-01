import Foundation

/// Notes for the dedicated settings page work on `codex-settings-page-plan`.
///
/// Keep this file non-runtime: it captures the design guardrails for the dedicated
/// settings window so the implementation stays separate from the minimal menu-bar-first
/// cleanup already shipped on `codex-minimal-settings-ui`.
///
/// The concrete implementation lives in:
/// - `SettingsWindow.swift`
/// - `SettingsViewModel.swift`
/// - `SettingsView.swift`
///
/// Design goals:
/// 1. Match the existing TypeNo style: lightweight, direct, not over-abstracted.
/// 2. Start from recording-related settings first:
///    - hotkey
///    - trigger mode
///    - microphone
/// 3. Add phone input / QR / diagnostics only if they still fit a restrained macOS
///    settings window.
/// 4. Avoid introducing a large controller hierarchy unless the UI genuinely needs it.
/// 5. Prefer a small native macOS settings window over a dashboard-style control center.
///
/// Suggested implementation order:
/// - Phase 1: minimal settings window shell with recording settings only
/// - Phase 2: evaluate whether phone input belongs in the same window
/// - Phase 3: only add richer status/help UI if repeated real usage proves necessary
///
/// Non-goals for the first settings-page iteration:
/// - QR code modal/window
/// - full system status dashboard
/// - broad architectural refactor of AppState / menu bar code
///
/// This file is intentionally documentation-in-code so future work can start from a
/// scoped plan without re-expanding into the previous heavy UI attempt.
enum SettingsPagePlan {}
