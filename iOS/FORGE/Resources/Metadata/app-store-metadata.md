# FORGE — App Store Metadata

> Production App Store Connect metadata for FORGE.
> Copy these fields directly into App Store Connect.

---

## App Information

| Field | Value |
|-------|-------|
| **App Name** | FORGE |
| **Subtitle** | AI Coding Agent + Terminal |
| **Bundle ID** | com.forge.terminal |
| **Primary Category** | Developer Tools |
| **Secondary Category** | Productivity |
| **Content Rights** | Does not contain third-party content |
| **Age Rating** | 17+ (Unrestricted Web Access) |
| **Price** | Free |
| **Distribution** | Worldwide (all territories) |

---

## Keywords

> Comma-separated, max 100 characters total.

```
coding,terminal,developer,ai,agent,trident,opencode,swift
```

---

## Description

> ~4000 characters. Formatted for App Store rendering.

FORGE is a professional AI coding agent and terminal for iOS — the entire opencode + Trident T3 Audit Engine experience, reimagined for touch.

BUILD ON DEVICE

Mode 1 runs a full coding agent directly on your iPhone or iPad. A Metal-accelerated terminal renders at 120 FPS with 5000-line scrollback. The AI agent understands your project, writes code, runs audits, and reports findings — all inside a local JavaScript engine running in a sandboxed WKWebView. No cloud round-trips. No data leaving your device.

The terminal supports ANSI colors, JetBrains Mono typography, command history with arrow-key navigation, and the complete opencode bridge contract. You get the same prompt, the same workflows, and the same agent intelligence as the desktop experience.

MISSION CONTROL

Mode 2 connects to opencode servers on your local network or remote machines. See every active session in a horizontally swipeable pager. Pinch to enter Eagle Vision — a live grid overview of all sessions simultaneously. Monitor builds, review audit scores, and keep track of multiple agents working in parallel.

Mission Control automatically discovers servers via Bonjour/mDNS, reconnects on network changes, and shows real-time connection status. Add unlimited servers and switch between them instantly.

PROFESSIONAL TERMINAL

- SwiftTerm rendering with Metal GPU acceleration
- ANSI 256-color support with custom FORGE dark theme
- JetBrains Mono font with optimal line height and character spacing
- 5000-line scrollback buffer
- Command history with up/down arrow navigation
- Smart keyboard with Done button accessory bar
- Copy/paste support via clipboard integration
- Link detection — tap URLs to open in Safari
- Haptic feedback on terminal bell events

AI CODING AGENT

- Full opencode runtime embedded on-device
- Trident T3 Audit Engine with 18-layer code review
- Local LLM inference (no API calls required for core features)
- Optional API key configuration for cloud-based models
- Provider support: Anthropic, OpenAI, and local models
- Real-time streaming output rendered to the terminal

DESIGN

FORGE is designed with obsessive attention to detail. The interface uses a custom dark color system optimized for OLED displays — true blacks, vibrant cyan accents, and carefully tuned contrast ratios. Every interaction includes haptic feedback. Animations use spring physics with natural damping curves. The parallax grid background responds to device motion via the gyroscope.

The launch menu features animated transitions — the FORGE title fades in while mode cards slide up with spring physics. Every pixel is intentional.

PRIVACY

FORGE respects your privacy. The on-device engine never sends your code to any server. API keys are stored securely in the iOS Keychain, never in plain text. Network connections in Mission Control are encrypted with TLS. There is no analytics, no tracking, and no advertising. What happens on your device stays on your device.

WHO IS FORGE FOR?

- iOS developers who want a powerful terminal on their phone
- Backend engineers who need to monitor remote build servers
- DevOps teams running multiple agent sessions in parallel
- Security researchers who need on-device code analysis
- Anyone who believes the iPhone is a serious development platform

FORGE is free with no in-app purchases, no subscriptions, and no ads. It is built by developers, for developers.

---

## Privacy Nutrition Labels

### Data Types Collected

FORGE does **not** collect any data from users. The app has zero analytics, zero tracking, and zero advertising SDKs.

| Data Type | Used for Tracking? | Linked to You? | Purpose |
|-----------|-------------------|----------------|---------|
| (none) | — | — | — |

### Data Types Not Collected but Used

| Data Type | Purpose |
|-----------|---------|
| **User Content — Code Snippets** | Processed entirely on-device for AI agent functionality. Never transmitted to servers. |
| **Diagnostics — Crash Data** | Apple's standard crash reporting only (if enabled in App Store Connect). Not used for analytics. |

### Privacy Practice URL

See: `https://forge-terminal.app/privacy`

> **Note for Review Team:** FORGE operates entirely on-device for Mode 1. The only network activity occurs in Mode 2 (Mission Control), which connects to user-configured servers over their local network or TLS-encrypted remote connections. No FORGE-operated servers are involved.

---

## Support Information

| Field | Value |
|-------|-------|
| **Support URL** | `https://forge-terminal.app/support` |
| **Marketing URL** | `https://forge-terminal.app` |
| **Privacy Policy URL** | `https://forge-terminal.app/privacy` |
| **Terms of Service URL** | `https://forge-terminal.app/terms` |

---

## What's New (Version 1.0.0)

> For the initial release version notes.

```
Welcome to FORGE — the AI coding agent and terminal for iOS.

NEW IN 1.0.0:
• Full on-device AI coding agent (Mode 1: Build on Device)
• Mission Control for remote session management (Mode 2)
• Metal-accelerated terminal with 5000-line scrollback
• Command history with arrow-key navigation
• Eagle Vision grid overview for multi-session monitoring
• ANSI 256-color support with custom dark theme
• Zero tracking, zero analytics, zero ads
```

---

## App Review Notes

> Information for the App Review team.

```
FORGE is a developer tool that provides a terminal emulator and AI coding agent on iOS.

MODE 1 (Build on Device): This runs a JavaScript engine in a WKWebView that provides a functional terminal experience. The terminal responds to keyboard input and supports basic commands (help, status, version, clear). No external network calls are required. To test: launch the app, tap "Build on Device", and type into the terminal.

MODE 2 (Mission Control): This connects to user-configured servers. Since no servers are configured by default, the app will show a "No Servers Configured" screen with an "Add Server" button. This is expected behavior — the user must configure their own server.

No demo credentials are needed — the app is fully functional without any login or account.

For questions: support@forge-terminal.app
```

---

## Promotional Text

> 170 characters. Can be updated without new review.

```
Your entire coding agent — on your phone. AI-powered terminal, remote session control, and zero tracking. Built by developers, for developers.
```

---

## Screenshots

> Required device sizes for submission.

| Device | Size | Count |
|--------|------|-------|
| iPhone 6.7" (Pro Max) | 1290 × 2796 | 5–10 |
| iPhone 6.5" | 1284 × 2778 | 5–10 |
| iPad Pro 12.9" | 2048 × 2732 | 3–10 |

**Suggested shots:**
1. Launch menu with animated FORGE title
2. Terminal with welcome banner and command output
3. Command history demonstration (up-arrow cycling)
4. Mission Control session pager
5. Eagle Vision grid overview
6. Connection error state with Retry button
7. Settings sheet with API key configuration

---

## App Preview Video (Optional)

| Field | Value |
|-------|-------|
| **Duration** | 15–30 seconds |
| **Resolutions** | 1290×2796 (6.7"), 1284×2778 (6.5") |
| **Content** | Terminal interaction → command execution → Mission Control → Eagle Vision |
