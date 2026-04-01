import Foundation

/// Notes for a future dedicated settings page.
///
/// Keep this file non-runtime for now: it exists to capture scope and design constraints
/// separately from the minimal menu-bar-first implementation already shipped on
/// `codex-minimal-settings-ui`.
///
/// Design goals:
/// 1. Match the existing TypeNo style: lightweight, direct, not over-abstracted.
/// 2. Start from recording-related settings only:
///    - hotkey
///    - trigger mode
///    - microphone
/// 3. Treat phone input / QR code / diagnostics as later sections, not v1.
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
