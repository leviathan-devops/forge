# FORGE

A native iOS application for AI-powered code generation and development. FORGE brings the full power of AI coding agents to iPad and iPhone with a terminal-native, dark-mode-first interface.

## Features

- **Build On-Device** — Run AI coding agents locally on your device
- **Mission Control** — Connect to and manage remote OpenCode servers
- **Terminal Interface** — Full ANSI terminal with SwiftTerm integration
- **Git Integration** — Repository management via libgit2
- **Project Management** — Create, open, and organize code projects
- **Multi-Provider Support** — Anthropic, OpenAI, local (Ollama), and custom endpoints

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- iPad / iPhone (optimized for iPad)

## Setup

1. Clone the repository
2. Open `FORGE.xcodeproj` in Xcode 15+
3. Install SPM dependencies:
   - **SwiftTerm** — `https://github.com/migueldeicaza/SwiftTerm.git` (≥ 1.2.0)
   - **swift-libgit2** — `https://github.com/light-tech/swift-libgit2.git` (≥ 1.0.0)
4. Add custom fonts to the project:
   - `JetBrainsMono-Regular.ttf`
   - `JetBrainsMono-Bold.ttf`
   - `JetBrainsMono-SemiBold.ttf`
5. Configure signing & capabilities with your Apple Developer account
6. Build and run on device or simulator

## Architecture

```
FORGE/
├── App/
│   ├── FORGEApp.swift          — @main entry point, WindowGroup, dark mode
│   └── AppState.swift          — ObservableObject: mode, projects, servers, sessions
├── Theme/
│   ├── ForgeTheme.swift        — Colors, fonts, haptics, ANSI palette
│   └── Color+Hex.swift         — UIColor/Color hex init
├── Presentation/
│   ├── LaunchMenu/
│   │   ├── LaunchMenuView.swift         — Mode selection screen
│   │   ├── ModeCard.swift               — Reusable mode selection card
│   │   └── ParallaxGridBackground.swift — CoreMotion parallax grid
│   └── Shared/
│       ├── TopBar.swift                 — 44pt navigation bar
│       ├── SettingsSheet.swift          — API keys, git config, about
│       └── ProjectManagerSheet.swift    — Project CRUD operations
├── Info.plist                  — App configuration
└── FORGE.entitlements          — Sandbox + iCloud
```

### Design System

| Token              | Hex       | Usage                    |
|--------------------|-----------|--------------------------|
| forgeBackground    | `0A0A0F`  | App background           |
| forgeSurface       | `1A1A24`  | Cards, sheets            |
| forgeElevated      | `12121A`  | Elevated surfaces        |
| forgeAccent        | `00F0FF`  | Primary accent (cyan)    |
| forgePrimaryText   | `E0E0E0`  | Body text                |
| forgeSecondaryText | `888888`  | Captions, labels         |
| forgeSuccess       | `50FA7B`  | Success states           |
| forgeWarning       | `F1FA8C`  | Warning states           |
| forgeError         | `FF5555`  | Error states             |

### Typography

All monospace text uses **JetBrainsMono**. System fonts are used for body/caption where legibility matters.

## License

Proprietary. All rights reserved.
