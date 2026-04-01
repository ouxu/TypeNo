# TypeNo

[中文](README_CN.md) | [日本語](README_JP.md)

**A free, open source phone input utility for macOS.**

![TypeNo hero image](assets/hero.webp)

A minimal macOS menu bar app that lets you type on your phone and send the text straight to your Mac.

Official website: [https://typeno.com](https://typeno.com)

## How It Works

1. Launch TypeNo from the menu bar
2. Keep **Phone Input** enabled
3. Open the local link on your phone
4. Type on the phone page and send
5. TypeNo pastes into your active Mac app when Accessibility is enabled, or copies to the clipboard as a fallback

## Install

### Option 1 — Download the App

- [Download TypeNo for macOS](https://github.com/marswaveai/TypeNo/releases/latest)
- Download the latest `TypeNo.app.zip`
- Unzip it
- Move `TypeNo.app` to `/Applications`
- Open TypeNo

TypeNo is signed and notarized by Apple — it should open without any warnings.

### First Launch

TypeNo needs one optional macOS permission:
- **Accessibility** — required only if you want TypeNo to paste directly into the active app

If Accessibility is not enabled, text is still copied to the clipboard.

### Troubleshooting: Accessibility Permission Not Working

Some users find that enabling TypeNo in **System Settings → Privacy & Security → Accessibility** has no effect — a known macOS bug. The fix:

1. Select **TypeNo** in the list
2. Click **−** to remove it
3. Click **+** and re-add TypeNo from `/Applications`

![Accessibility permission fix](assets/accessibility-fix.gif)

### Option 2 — Build from Source

```bash
git clone https://github.com/marswaveai/TypeNo.git
cd TypeNo
scripts/generate_icon.sh
scripts/build_app.sh
```

The app will be at `dist/TypeNo.app`. Move it to `/Applications/` for persistent permissions.

## Usage

| Action | Entry |
|---|---|
| Enable/disable phone input | Menu bar → Enable/Disable Phone Input |
| Open the phone page on this Mac | Menu bar → Open Phone Page |
| Copy the local phone link | Menu bar → Copy Link |
| Enable direct paste | Menu bar → Enable Paste Permission |
| Check for updates | Menu bar → Check for Updates... |
| Quit | Menu bar → Quit (`⌘Q`) |

## Design Philosophy

TypeNo does one thing: phone text → Mac insert. No recorder, no speech engine, no extra setup flow.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=marswaveai/TypeNo&type=Date)](https://star-history.com/#marswaveai/TypeNo&Date)

## License

GNU General Public License v3.0
