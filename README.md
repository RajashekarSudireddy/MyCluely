# lightweightfolder ⚡📦

> **Lightweight Swift Module Cache Staging & MyCluely Native macOS Application Environment**

`lightweightfolder` is a dual-purpose software repository and compilation workspace located on macOS. It serves as both the complete source tree for **MyCluely**—an ultra-lightweight, 2.4&nbsp;MB native macOS floating HUD application for continuous live audio capture and instantaneous AI question answering—and an explicit **Swift compiler artifact staging and precompiled module cache environment**.

By bypassing heavy, multi-gigabyte Xcode project wrappers (`.xcodeproj`, `DerivedData`) in favor of direct `swiftc` compiler invocations, this workspace demonstrates how modern Swift 6 compilation pipelines utilize Clang Precompiled Modules (`.pcm`) and Swift prebuilt module forwarding manifests (`.swiftmodule`) to achieve sub-second incremental compilation speeds.

---

## 📑 Table of Contents

1. [Project Overview](#-project-overview)
2. [Problem Statement: Compiler Artifact Staging & Build Performance](#-problem-statement)
3. [Directory Contents & Module Breakdown](#-directory-contents--module-breakdown)
   - [Swift Prebuilt Module Descriptors (`*.swiftmodule`)](#swift-prebuilt-module-descriptors-swiftmodule)
   - [Clang Precompiled Module Cache (`1MTWNDVONU6Q/`)](#clang-precompiled-module-cache-1mtwndvonu6q)
   - [Source Tree & Application Architecture (`Sources/`)](#source-tree--application-architecture-sources)
   - [Build Scripts, Resources & Output Artifacts](#build-scripts-resources--output-artifacts)
4. [Tech Stack & Swift Toolchain Context](#-tech-stack--swift-toolchain-context)
5. [Usage & Maintenance Guidelines: Safe Cleaning vs Caching](#-usage--maintenance-guidelines)
6. [Current Status & Verification](#-current-status--verification)
7. [License & Notices](#-license--notices)

---

## 🔍 Project Overview

The workspace unites two tightly integrated engineering objectives:

1. **Native Lightweight Application Engineering (MyCluely)**:
   - An always-on-top, non-activating floating HUD window (`NSPanel`) built in pure Swift 6 and SwiftUI.
   - Dual continuous live streaming engines: **Google Gemini Live** (`gemini-3.1-flash-live-preview`) and **OpenAI Realtime** (`gpt-realtime`) streaming bi-directional audio/text over native `URLSessionWebSocketTask`.
   - Native audio capture using `AVAudioEngine` for microphone input and Apple's `ScreenCaptureKit` (`SCStream`) for driverless system-wide audio capture.
   - On-device speech recognition via Apple `SFSpeechRecognizer` with syntactic question detection and REST fallback.
   - Enterprise-grade local security: PBKDF2-HMAC-SHA256 password hashing (600,000 iterations), Apple Keychain credential persistence, and Google OAuth 2.0 PKCE authentication.
   - **Zero Electron, zero webviews, zero heavy third-party SDK dependencies**, producing a self-contained 2.4&nbsp;MB signed executable.

2. **Lightweight Swift Module Caching & Staging Architecture**:
   - Direct command-line compilation using Apple's `swiftc` driver without Xcode project overhead.
   - Staging of 51 YAML-based Swift module forwarding descriptors (`AppKit-*.swiftmodule`, `Foundation-*.swiftmodule`, etc.).
   - Staging of 75 Precompiled Clang Modules (`.pcm` files in hash directory `1MTWNDVONU6Q/`) totaling ~161&nbsp;MB of pre-parsed C/Objective-C Abstract Syntax Tree (AST) bitcode.
   - Validation tracking via `modules.timestamp` for cache coherency and fast re-compilation.

---

## 🎯 Problem Statement

### 1. The Compiler Overhead Dilemma
Modern macOS development relies on massive Apple system frameworks: `AppKit`, `Foundation`, `SwiftUI`, `ScreenCaptureKit`, `AVFoundation`, and `_Concurrency`. Under standard compilation:
- Every cold compiler invocation must parse hundreds of thousands of lines of C/Objective-C headers (`.h`) and textual Swift interface definitions (`.swiftinterface`).
- Re-parsing Darwin POSIX APIs, CoreGraphics math, Objective-C runtime shims, and AppKit class declarations on every build incurs a **15 to 30-second compilation penalty** per build cycle.

### 2. The Xcode `DerivedData` Bloat
Apple's Xcode IDE solves this compilation cost by caching prebuilt modules inside `~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/`. However, this introduces distinct engineering challenges:
- `DerivedData` routinely expands to **10 to 50+ Gigabytes**, consuming SSD storage with opaque indexing databases and stale module versions.
- Complex `.xcodeproj` and `.xcworkspace` project files create merge conflicts, brittle CI/CD setups, and heavy build tool lock-in.

### 3. The Lightweight Module Caching Solution & Staging Footprint
To build MyCluely cleanly and swiftly, the build pipeline targets explicit module caching via `swiftc -module-cache-path <PATH>`. 
- When the compiler cache path points to a local workspace or staging directory, `swiftc` and its embedded Clang driver write precompiled artifacts directly into that directory.
- This creates two distinct artifact classes in the workspace:
  1. **`.swiftmodule` Forwarding Descriptors**: Compact YAML text files mapping SDK framework interfaces directly to prebuilt binary modules in the Xcode toolchain (`usr/lib/swift/macosx/prebuilt-modules/27.0/`).
  2. **Clang PCM Hash Directory (`1MTWNDVONU6Q/`)**: Serialized binary AST representations (`.pcm`) of underlying C/Obj-C frameworks.
- **The Optimization Result**: Subsequent incremental builds complete in **under 1.5 seconds**, cutting compile times by over 90% while keeping the final application binary at an ultra-compact 2.4&nbsp;MB.

---

## 📂 Directory Contents & Module Breakdown

Below is an exhaustive breakdown of the files and directories present in `lightweightfolder`:

```
lightweightfolder/
├── 1MTWNDVONU6Q/                          # Clang Precompiled Module (PCM) cache directory (75 .pcm files, ~161 MB)
├── *.swiftmodule                          # 51 YAML Swift module forwarding descriptors (AppKit, Foundation, etc.)
├── modules.timestamp                      # Clang module cache validation marker (0 bytes)
├── main                                   # Standalone compiled Mach-O 64-bit arm64 test executable (39 KB)
├── Sources/                               # 28 production Swift source files (MyCluely application)
│   ├── AI/                                # WebSocket clients (Gemini Live, OpenAI Live), REST fallback, Keychain
│   ├── App/                               # App entry point (@main) and NSApplicationDelegate lifecycle
│   ├── Audio/                             # Audio capture (AVAudioEngine, ScreenCaptureKit), buffer conversion
│   ├── Auth/                              # PBKDF2 hashing, secure Keychain storage, Google OAuth 2.0 PKCE
│   ├── Model/                             # AppState (@Observable), QAItem data models
│   ├── Speech/                            # Apple SFSpeechRecognizer & QuestionDetector
│   └── UI/                                # FloatingHUDWindow (NSPanel), FloatingHUDView (SwiftUI), Settings
├── Resources/                             # Info.plist & MyCluely.entitlements
├── Scripts/                               # Build, launch, verification, and security scan automation
├── Tests/                                 # Unit test suites (Auth, Audio, Question Detection, OpenAI diagnostics)
├── build/                                 # Final compiled application bundle (MyCluely.app, MyCluely.zip)
├── .build/                                # Local module cache staging (.build/cache/ with 1MTWNDVONU6Q, 2ISZRUOOEIMCY)
├── .spm-test/                             # SwiftPM isolated test package (Package.swift for Swift 6.4)
├── .tmp/                                  # Ephemeral build logs, security scan reports, test executables
├── landing-page/                          # Next.js web application for MyCluely marketing and documentation
├── ARCHITECTURE.md                        # Deep technical architecture (Compiler pipeline & App runtime)
├── SECURITY_AUDIT.md                      # Security audit report, credential safety, and privacy controls
├── THIRD_PARTY_NOTICES.md                 # Third-party attribution, fonts, and open-source licenses
├── LICENSE                                # MIT License
└── .gitignore                             # Exclusion rules for compiler artifacts, caches, and credentials
```

### Swift Prebuilt Module Descriptors (`*.swiftmodule`)
The root directory contains **51 `.swiftmodule` files**. Despite the `.swiftmodule` extension, these files are UTF-8 YAML descriptor manifests created by the Swift driver. They instruct the compiler to link directly against Xcode's toolchain prebuilt binaries instead of re-compiling textual `.swiftinterface` files from scratch.

A representative manifest (`AppKit-1ET5HRFVKXRNI.swiftmodule`) contains:
```yaml
---
path: '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/prebuilt-modules/27.0/AppKit.swiftmodule/arm64e-apple-macos.swiftmodule'
dependencies:
  - mtime: 1788113133000000000
    path: '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/prebuilt-modules/27.0/AppKit.swiftmodule/arm64e-apple-macos.swiftmodule'
    size: 821672
  - mtime: 1786222404000000000
    path: 'usr/lib/swift/Swift.swiftmodule/arm64e-apple-macos.swiftinterface'
    size: 2472314
    sdk_relative: true
  - mtime: 1786227436000000000
    path: 'System/Library/Frameworks/Foundation.framework/Headers/Foundation.apinotes'
    size: 81098
    sdk_relative: true
version: 1
...
```

#### Functional Categorization of the 51 Descriptors:
| Architectural Domain | Module Descriptors |
|---|---|
| **Core Swift Runtime** | `Swift-*.swiftmodule`, `_Concurrency-*.swiftmodule`, `Synchronization-*.swiftmodule`, `_Builtin_float-*.swiftmodule`, `_StringProcessing-*.swiftmodule`, `SwiftOnoneSupport-*.swiftmodule` |
| **Darwin & C Runtime** | `Darwin-*.swiftmodule`, `_DarwinFoundation1-*.swiftmodule`, `_DarwinFoundation2-*.swiftmodule`, `_DarwinFoundation3-*.swiftmodule`, `ObjectiveC-*.swiftmodule`, `System-*.swiftmodule`, `IOKit-*.swiftmodule`, `os-*.swiftmodule`, `OSLog-*.swiftmodule`, `XPC-*.swiftmodule` |
| **AppKit & UI Frameworks** | `AppKit-*.swiftmodule`, `SwiftUI-*.swiftmodule`, `SwiftUICore-*.swiftmodule`, `DeveloperToolsSupport-*.swiftmodule`, `ColorSync-*.swiftmodule`, `CoreGraphics-*.swiftmodule`, `QuartzCore-*.swiftmodule`, `CoreText-*.swiftmodule`, `ImageIO-*.swiftmodule` |
| **Audio, Video & Media** | `AVFoundation-*.swiftmodule`, `AVFAudio-*.swiftmodule`, `AudioToolbox-*.swiftmodule`, `CoreAudio-*.swiftmodule`, `CoreMedia-*.swiftmodule`, `CoreVideo-*.swiftmodule`, `CoreMIDI-*.swiftmodule`, `MediaToolbox-*.swiftmodule`, `VideoToolbox-*.swiftmodule`, `ScreenCaptureKit-*.swiftmodule`, `Speech-*.swiftmodule` |
| **System Services & Foundation**| `Foundation-*.swiftmodule`, `Combine-*.swiftmodule`, `CoreFoundation-*.swiftmodule`, `CoreData-*.swiftmodule`, `CoreTransferable-*.swiftmodule`, `DataDetection-*.swiftmodule`, `Observation-*.swiftmodule`, `UniformTypeIdentifiers-*.swiftmodule`, `Symbols-*.swiftmodule` |
| **Graphics & Compute** | `Metal-*.swiftmodule`, `simd-*.swiftmodule`, `Spatial-*.swiftmodule`, `Accessibility-*.swiftmodule` |

---

### Clang Precompiled Module Cache (`1MTWNDVONU6Q/`)
The subfolder `1MTWNDVONU6Q/` represents a hash-keyed Clang module cache. Clang computes a 12-character cryptographic hash based on the target architecture (`arm64-apple-macos14.0`), SDK version, sysroot path, language dialect, and compiler macro flags.

- **Total Files**: 75 Precompiled Module (`.pcm`) files.
- **Total Storage**: ~161.5&nbsp;MB.
- **Top Modules by Size**:
  1. `AppKit-2VI8NB39I5AT6.pcm` (10.9&nbsp;MB) — Precompiled Objective-C interfaces for macOS GUI widgets, windows, panels, and events.
  2. `Foundation-24LYWIP48SHNP.pcm` (6.6&nbsp;MB) — Cocoa base classes, collections, serialization, and networking.
  3. `AVFoundation-7VNZZNFQDWLP.pcm` (6.4&nbsp;MB) — Audio/video engine graphs and hardware capture delegates.
  4. `Darwin-1FXX23EKWOBA9.pcm` (6.0&nbsp;MB) — POSIX system calls, BSD sockets, file system descriptors, and standard C library.
  5. `CoreServices-39NCTJOEW7PQ2.pcm` (4.5&nbsp;MB) — System event streams, LaunchServices, and carbon event subsystems.
  6. `simd-KY25Q80SBOHY.pcm` (4.0&nbsp;MB) — Vector math and hardware acceleration intrinsics.
  7. `IOKit-1IAL9NTK1TABA.pcm` (3.7&nbsp;MB) — Hardware abstraction layer and device notifications.
  8. `Security-3QCVXOV25KK54.pcm` (3.1&nbsp;MB) — Apple Keychain Services and SecKey APIs.
  9. `Metal-1GCZV9N85NJOH.pcm` (2.7&nbsp;MB) — Low-overhead GPU compute and rendering pipelines.

---

### Source Tree & Application Architecture (`Sources/`)
The production application codebase consists of 28 Swift files cleanly separated by concern:

```
Sources/
├── AI/
│   ├── AnswerService.swift        # REST API client with model fallback (gemini-2.5-flash -> gemini-3.8-flash)
│   ├── GeminiLiveClient.swift     # 24/7 bi-directional WebSocket client for Google Gemini Live API
│   ├── OpenAILiveClient.swift     # 24kHz bi-directional WebSocket client for OpenAI Realtime (gpt-realtime)
│   └── KeychainHelper.swift       # Direct Apple Keychain Services wrapper (kSecAttrAccessibleWhenUnlocked)
├── App/
│   ├── AppDelegate.swift          # NSApplicationDelegate, status bar menu, global hotkeys (Cmd+Shift+P, Cmd+Shift+H)
│   └── Main.swift                 # Application entrypoint using @main and NSApplicationMain
├── Audio/
│   ├── AudioManager.swift         # Audio source coordinator (Microphone, System Audio, or Both)
│   ├── AudioBufferConverter.swift # Real-time sample rate conversion to 16kHz mono Float32 & RMS metering
│   ├── MicrophoneCapture.swift    # Low-latency input node tapping via AVAudioEngine
│   └── SystemAudioCapture.swift   # Driverless system-wide audio capture via ScreenCaptureKit (SCStream)
├── Auth/
│   ├── AuthManager.swift          # Authentication state coordinator (Sign In, Sign Up, Sign Out, Password Upgrade)
│   ├── AuthModels.swift           # User profile, provider type, session models, and auth errors
│   ├── AuthStorage.swift          # PBKDF2-HMAC-SHA256 hasher (600,000 rounds), salt generator, Keychain storage
│   └── GoogleOAuthService.swift   # Google OAuth 2.0 with PKCE and ASWebAuthenticationSession
├── Model/
│   ├── AppState.swift             # MainActor-isolated single source of truth (@Observable)
│   └── QAItem.swift               # Identifiable question and answer data structure
├── Speech/
│   ├── QuestionDetector.swift     # Interrogative grammar parsing and 0.8s silence debouncing engine
│   └── SpeechTranscriber.swift    # Continuous Apple SFSpeechRecognizer with 60-second seamless session rollover
└── UI/
    ├── ApiKeyPromptView.swift     # Dynamic API key onboarding prompt
    ├── AuthView.swift             # Unified Login & Sign-Up interface card
    ├── FloatingHUDView.swift      # Glassmorphic root SwiftUI view with in-panel transitions
    ├── FloatingHUDWindow.swift    # Subclassed NSPanel (.floating, .canJoinAllSpaces, animated height auto-sizing)
    ├── GoogleSignInSheet.swift    # Interactive Google Sign-In and account connect sheet
    ├── QuestionAnswerCard.swift   # Live streaming answer card with copy (📋) and dismiss controls
    ├── SettingsPopoverView.swift  # In-panel settings card (Provider switch, Audio routing, Account info)
    ├── Theme.swift                # Visual tokens, electric blue accents, and NSVisualEffectView HUD material
    └── TranscriptLiveView.swift   # Real-time equalizer visualizer and live speech ticker
```

---

### Build Scripts, Resources & Output Artifacts

- **`Scripts/build.sh`**: Production packaging script. Compiles all Swift sources via `swiftc -O -target arm64-apple-macos14.0`, embeds `Info.plist`, strips metadata (`.DS_Store`, extended attributes), and applies ad-hoc codesigning with Hardened Runtime and entitlements.
- **`Scripts/run.sh`**: Development runner script that triggers `build.sh` and launches the resulting `.app`.
- **`Scripts/security_scan.py`**: Automated security audit script scanning for credential leakage, unsafe storage, and unassigned API keys.
- **`Resources/Info.plist`**: Bundle configuration specifying `LSUIElement = YES` (accessory app without Dock icon) and privacy usage descriptions for Microphone and Speech Recognition.
- **`Resources/MyCluely.entitlements`**: Hardened runtime entitlement declaring `com.apple.security.device.audio-input`.
- **`build/MyCluely.app`**: Fully assembled, ad-hoc signed, 2.4&nbsp;MB macOS application bundle.
- **`build/MyCluely.zip`**: Metadata-free clean distribution archive (564&nbsp;KB compressed).

---

## 🛠️ Tech Stack & Swift Toolchain Context

| Dimension | Specification | Notes |
|---|---|---|
| **Language & Toolchain** | Swift 6.x / Swift 6.4 | Xcode internal toolchain release `27.0` |
| **Compilation Architecture** | Apple Silicon (`arm64-apple-macos14.0`) | Compatible with `arm64e` prebuilt module ABI |
| **Compiler Driver** | Direct `swiftc` CLI invocation | Eliminates Xcode `.xcodeproj` parsing and DerivedData bloat |
| **Optimization Level** | `-O` (Whole-module release optimization) | Stripped symbols, dead-code elimination, inlined generics |
| **Compiler Flags** | `-Xfrontend -disable-sandbox` | Permitted for macro expansion (`@Observable`, `@MainActor`) |
| **GUI Framework** | AppKit (`NSPanel`) + SwiftUI | Dynamic frame height recalculation, zero Electron runtime |
| **Audio Processing** | `AVFoundation` + `ScreenCaptureKit` | Custom float-to-Int16 PCM conversion and linear interpolation |
| **AI Protocol** | WebSockets (`URLSessionWebSocketTask`) | Bi-directional streaming for Google Gemini Live & OpenAI Realtime |
| **Cryptography** | Apple `CryptoKit` + `Security` (Keychain) | PBKDF2-HMAC-SHA256, random 128-bit salts, zero plaintext storage |

---

## 🧹 Usage & Maintenance Guidelines

### Safe Cleaning vs Caching

Because `lightweightfolder` contains both active source code and compiler cache artifacts, developers and automated agents must adhere to the following maintenance policies:

```
┌───────────────────────────────────────┬───────────────────────────────────────┐
│       NEVER DELETE (Source & Config)  │       SAFE TO DELETE (Ephemeral Cache)│
├───────────────────────────────────────┼───────────────────────────────────────┤
│ • Sources/                            │ • *.swiftmodule (root YAML files)     │
│ • Resources/                          │ • 1MTWNDVONU6Q/ (Clang PCM cache)     │
│ • Scripts/                            │ • modules.timestamp                   │
│ • Tests/                              │ • main (intermediate test executable) │
│ • landing-page/                       │ • .tmp/ (logs & temporary test files) │
│ • ARCHITECTURE.md, README.md, LICENSE │ • build/ & .build/ (rebuilt on demand)│
└───────────────────────────────────────┴───────────────────────────────────────┘
```

### Routine Maintenance Commands

#### 1. Perform an Incremental Fast Build (Retaining Cache)
To leverage the precompiled modules for sub-second build speed:
```bash
bash Scripts/build.sh
```

#### 2. Clean Ephemeral Compiler Artifacts (Reset Cache)
If Xcode is updated or toolchain headers change, purge the staged module cache:
```bash
# Remove root-level compiler artifacts
rm -f *.swiftmodule modules.timestamp main
rm -rf 1MTWNDVONU6Q .tmp

# Remove build outputs
rm -rf build .build
```

#### 3. Perform a 100% Hermetic Clean Build
After clearing the cache, invoke the build script to rebuild the application from clean state:
```bash
bash Scripts/build.sh
```

#### 4. Run the Security & Cryptographic Test Suite
Verify local authentication, PBKDF2 password hashing, and token isolation:
```bash
bash Scripts/test_security.sh
python3 Scripts/security_scan.py --include-generated
```

### Version Control (.gitignore) Protection
The repository's `.gitignore` is pre-configured to prevent module cache files and temporary executables from polluting Git history:
```gitignore
# Swift builds, compiler output, and caches
.build/
build/
.spm-test/
.tmp/
/1MTWNDVONU6Q/
*.swiftmodule
*.pcm
*.o
/main
modules.timestamp
*.app/
```
Even when present on disk for local acceleration, these artifacts remain ignored by Git.

---

## 📊 Current Status & Verification

- **Application Build**: `build/MyCluely.app` is fully compiled, verified, and signed with hardened runtime.
- **Bundle Footprint**: 2.4&nbsp;MB uncompressed (`564 KB` in `build/MyCluely.zip`).
- **Compiler Cache Health**: Staged module cache (`1MTWNDVONU6Q` and 51 `.swiftmodule` descriptors) is valid and synchronized with macOS 14.0 arm64 SDK headers.
- **Security Audit**: Zero unassigned API keys, zero exposed plaintext passwords, Keychain migrations validated.
- **Web Portal**: Next.js landing page is available in `landing-page/` for product showcase and documentation.

For complete architectural specifications, compiler pipeline mechanics, and Mermaid dependency diagrams, see [**ARCHITECTURE.md**](ARCHITECTURE.md).

---

## 📄 License & Notices

- **Software License**: [MIT License](LICENSE)
- **Third-Party Attributions**: See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for Google Gemini API, OpenAI Realtime API, Inter and Roboto Mono font licenses.
