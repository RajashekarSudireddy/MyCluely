# MyCluely security, privacy, and publication audit

Audit date: 2026-09-26. Scope: the native Swift application, all scripts/tests/documentation/configuration, the landing page and assets, local dependency/build artifacts, and existing Git objects. This review does not certify provider services, signing infrastructure, or future changes.

## Publication decision

The reviewed source has no identified live hardcoded credentials. The security and exclusion fixes below have been applied. Publish the reviewed source through the normal main branch workflow after the owner checks below. Local build caches, preferences, logs, Git backups, and private checkpoint refs must not accompany the public source.

This is source-publication readiness. A production binary release still needs real Keychain/TCC/OAuth/provider smoke tests and Developer ID signing/notarization.

## Categorized findings

| Severity | Finding and affected files | Resolution / remaining work |
|---|---|---|
| **Critical** | No confirmed live credential or remotely exploitable critical flaw identified in the publication candidates. | npm reported zero known vulnerabilities on the audit date. Upcoming unpublished Next.js advisories remain a maintenance item below. |
| **High** | Google quick sign-in accepted an arbitrary email without proving ownership; email-based account linking could expose another local account's keys. `GoogleSignInSheet.swift`, `AuthManager.swift`. | Removed the shortcut. Browser OAuth is required; existing Google accounts must match the verified Google subject. Automatic linking to email/password accounts is rejected. Legacy sessions are invalidated. |
| **High** | API keys, password hashes/salts, account identities, and the active email were persisted in plaintext UserDefaults. `AuthStorage.swift`, `AppState.swift`; live clients also read global plaintext fallbacks. | Sensitive records and sessions now use Keychain. All plaintext/global credential fallbacks were removed. Migration verifies the secure copy before removing legacy fields; failed reads/writes propagate to the caller and do not overwrite unreadable accounts. **Four legacy sensitive preference fields remain on this Mac until the owner launches the updated app.** Their values were not printed or copied into this report. |
| **High** | OAuth generated `state` but never checked it on return. `GoogleOAuthService.swift`. | Validate state, callback scheme/path, duplicate parameters, error replies, and nonempty code. Use PKCE S256, check secure RNG failures, require Google's verified email, and use the reverse client-ID callback scheme for a configured iOS/macOS client. |
| **Medium** | Fast salted SHA-256 and a six-character password minimum were weak against offline guessing. `AuthStorage.swift`, `AuthManager.swift`, `AuthView.swift`. | New passwords use PBKDF2-HMAC-SHA256 with 600,000 iterations, random 128-bit salts, constant-time comparison, and a 12-character minimum. Legacy hashes upgrade after successful password login; they cannot be upgraded without the user's password. [OWASP password-storage guidance](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) supports this PBKDF2 work factor. |
| **Medium** | Speech questions, raw provider errors/frames/headers, user identities, and key prefix/suffix fragments appeared in logs/diagnostics. | Removed speech content and raw provider error bodies, frames, headers, identities, salts, and key fragments. Logs contain fixed event descriptions, counts, and numeric status codes. `verify_auth.sh` is read-only and reports presence only. |
| **Medium** | Gemini keys were embedded in request URLs; default URLSession configurations could persist caches/cookies. | Gemini uses the `x-goog-api-key` header for REST and WebSocket requests. OpenAI uses Authorization. Provider/OAuth sessions are ephemeral. No keys are logged. Header-based Gemini authentication is documented in the [Gemini API reference](https://ai.google.dev/api). |
| **Medium** | Local STT was described as wholly local without requiring on-device recognition. Audio resumed automatically, and old Q&A/session responses could survive sign-out. | Require on-device speech support; fail with a clear message rather than using Apple cloud transcription. Each launch/sign-in asks before listening. Sign-out clears transcript/history/keys and stops engines. Queued provider/UI results are scoped to the authenticated session and retired sockets are discarded. Pause stops forwarding new audio; capture hardware stays active until sign-out/stop. |
| **Medium** | Tests could read real saved user keys and run a paid OpenAI handshake implicitly. | Auth tests use isolated preferences and an in-memory credential store. API fixtures are plainly named mocks, emails use `example.com`, and live diagnostics require both explicit opt-in and an environment key. The offline test runner removes both live-test environment variables. |
| **Medium** | No root `.gitignore`; compiler output, logs, preference exports, dependencies, and local databases could be accidentally published. A nested landing-page Git repository could also become a gitlink instead of source. | Added comprehensive exclusions, keeping required Info.plist/entitlements visible. Root `main`, module files, timestamp and cache directory remain locally but are ignored. Moved the nested Git directory to ignored `.tmp/landing-page.git-backup`, preserving it while allowing normal source inclusion. |
| **Medium** | README claimed MIT without a root license; Roboto Mono had an Apache notice that did not match its binary metadata. | Added MIT LICENSE, consistent with the existing license declaration. Included matching OFL font notices and a 438-package lockfile license inventory in THIRD_PARTY_NOTICES.md. The owner must confirm rights to all original code/assets. |
| **Informational** | Personal absolute developer path in the README; compiler caches and private Git checkpoint objects contain local paths. | README now uses a relative link. No personal developer identity remains in the reviewed publication candidates. The existing unpublished empty initial commit was reauthored to a project identity with the original SHA backed up in ignored `.tmp/pre-publication-git-metadata.json`; repository-local Git identity is also set to the project identity. Private reflogs/checkpoint objects still retain earlier metadata. Do not publish private refs, raw `.git`, or ignored caches. |
| **Informational** | Builds relied on stale module caches, a broad identifier-only ad-hoc signing requirement, and an implicit deployment target inconsistent with newer SwiftUI APIs. | Fresh temporary module caches; Hardened Runtime/audio-input entitlement; default cdhash-bound ad-hoc requirement; explicit macOS 14 deployment target and matching documentation/Info.plist. Bundles are assembled away from Desktop metadata and signature verification is required before reporting build success. |

## Scan coverage and candidate review

The initial full scan read approximately 22,000 regular workspace files, including node_modules and build/cache bytes, plus 352 Git blob/commit/tag objects across the root and nested repositories. Targeted follow-up checks covered known developer identities, credential persistence, logging, network destinations, test data, ignored publication paths, and font metadata.

All provider-key-shaped matches inspected in source, binaries, or Git objects were test placeholders. OAuth client-ID-shaped matches were sample IDs, not a configured developer client. Dependency JWT strings were Zod test fixtures; private-key markers appeared in Next.js environment-variable documentation examples. No live provider key, OAuth secret/refresh token, private key, real account password/hash/salt fixture, or private internal service endpoint was identified in the public candidates.

Remaining source scan candidates are synthetic `example.com` addresses, a fixture-only password, the scanner's own generic path regex, and the landing-page README's localhost development URL. Third-party copyright identities are intentionally preserved.

`Scripts/security_scan.py` is a redacted heuristic scanner. It prints candidate category/path/line, never values; its successful exit means the scan completed, not that every candidate was cleared. Review candidate output whenever sources or dependencies change. Regex scanning cannot detect every arbitrary secret or personal name.

## Storage and migration behavior

- Account JSON in Keychain contains profiles, password verifiers/salts, and per-account provider keys. No raw account password is persisted.
- Active session email uses a separate Keychain item. A non-identifying revocation flag prevents session restoration if Keychain deletion fails during sign-out.
- Keychain accessibility requests `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Signing/ACL and accessibility behavior must be checked on a real release build; [Apple's Keychain guidance](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) recommends choosing the most restrictive suitable accessibility.
- UserDefaults retains ordinary settings, the public OAuth client ID, and the non-identifying revocation flag.
- Legacy plaintext accounts merge into secure storage with existing secure values taking precedence. Read-back verification precedes plaintext deletion. Unassigned global keys are retained under legacy recovery items in Keychain and are never used as another account's keys.
- Old sessions require fresh sign-in. Google profiles created by the former unverified shortcut cannot match a verified Google subject and need local recovery/recreation; do not silently link them by email.
- The status inspector observed four legacy sensitive preference fields. Keychain presence was unavailable to this inspection process (numeric status -50); actual user Keychain migration was not exercised. Synthetic migration/failure tests passed.
- Removal from current preferences does not erase old backups or previously captured logs. Keep those private; if a real credential was previously shared elsewhere, revoke/rotate it at the provider.

## Privacy and platform review

`NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` are present and explain cloud audio or question-text processing. Removed the unrelated system-administration usage string. The app requests macOS screen/system audio recording permission through ScreenCaptureKit/CoreGraphics, registers an audio output only, and does not save video frames.

The signing entitlements include `com.apple.security.device.audio-input` for microphone use under Hardened Runtime. App Sandbox is not enabled; this audit did not invent a screen-capture entitlement or claim sandbox confinement. Apple's [Hardened Runtime documentation](https://developer.apple.com/documentation/security/hardened-runtime) and [audio-input entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input) describe the release capabilities.

Cloud Live transmits selected audio to Gemini or OpenAI. Local STT transcribes on-device but sends detected questions to Gemini when auto-answer is enabled. Provider-side retention and participants' consent remain the owner's/user's responsibility. The native app saves no audio/transcript history to disk. The landing page has no application analytics, API credential code, or account data persistence identified; fonts are local files. Next.js build telemetry is a tooling concern, separate from visitor tracking.

## Dependency and license status

The landing page pins Next.js 16.3.6 and React/React DOM 19.2.8. `npm audit --json` returned **zero** vulnerabilities, including development dependencies, on 2026-09-26. Next.js 16.3.6 includes the September 22 upstream security patch. [Official September 22 advisory](https://nextjs.org/blog/nextjs-security-update-september-22-2026).

The maintainers have announced another patch release for September 30, including a critical issue; affected-version/impact details were not yet published at audit time. Recheck and upgrade Next.js/eslint-config-next when the patch is available before a subsequent deployment. [Official advance notice](https://nextjs.org/blog/upcoming-nextjs-security-release-september-2026). Zero audit findings do not clear unpublished issues.

The lockfile includes LGPL/composite libvips packages, MPL packages, and a CC-BY dataset. They are not vendored into the source repository. Any later binary/container distribution needs the included components' notices and applicable obligations. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for package-by-package declarations and the corrected font licenses.

## Verification

- `./Scripts/test_security.sh`: passed hashing, per-account isolation, failed storage reads/writes/deletion, Google subject binding, migration rollback/cleanup, legacy-hash upgrade, and callback scheme/path/state/error cases. Offline OpenAI payload/resampling/chunk checks passed. Live provider calls were explicitly skipped.
- `npm run lint` and `npm run build` in landing-page: passed, including TypeScript and static-page generation.
- `npm audit --json`: zero known vulnerabilities.
- `plutil -lint` on Info.plist/entitlements and `bash -n` on scripts: passed.
- Ignore checks covered all requested build, cache, module, system, environment, preference, log, dependency, and database exclusions. Required source/plist/entitlement/license/font files remain publishable.
- `./Scripts/build.sh`: successful optimized macOS 14 build, Hardened Runtime/audio-input entitlement, and strict code-signature verification. The ZIP was extracted into a fresh unmanaged directory and passed independent strict signature verification, including the expected audio-input entitlement and cdhash-bound requirement. The metadata-free `build/MyCluely.zip` preserves the signed staging bundle. Finder/File Provider on this Desktop can reattach FinderInfo after packaging; use the clean archive (or an unmanaged output directory) for later signature checks.

Live Google OAuth, Gemini/OpenAI authentication, microphone/system capture, release-signing ACLs, and real Keychain migration were not tested with user credentials. Review those before distributing a production binary. No public GitHub repository, remote push, or source commit was created by this audit. Only the pre-existing empty commit's identity was amended with permission; its original SHA was preserved locally.

## Safe to Publish checklist

### Completed in this workspace

- [x] Source, scripts, tests, documentation, assets, dependencies, artifacts, and existing Git objects scanned; candidates reviewed without exposing values.
- [x] Plaintext credential writes/fallbacks replaced; safe migration and failure handling implemented.
- [x] Unverified Google sign-in removed; OAuth callback and subject validation added.
- [x] Sensitive logging removed; tests isolated and live calls opt-in only.
- [x] Root ignore rules, corrected license notices, privacy disclosures, and deployment declarations added.
- [x] Offline security tests, native build/signature gate, and landing-page checks passed.

### Owner checks at publication/release time

- [ ] Launch the updated app with Keychain unlocked, complete fresh sign-in, and use `./Scripts/verify_auth.sh` to confirm legacy sensitive preference fields reach zero. Recover any legacy shortcut-created Google profiles or unassigned keys locally.
- [ ] Inspect the exact staged files before committing: include the complete landing page, native source, lockfile, licenses, Info.plist and entitlements; exclude preferences, recordings, logs, .env files, binaries, caches, and `.tmp` backups. `.gitignore` does not protect force-added files.
- [ ] Confirm the configured project Git identity (or choose a privacy-safe GitHub noreply identity) before future commits. Push only the reviewed public branch. Keep private `refs/codex/turn-diffs/checkpoints/*` and the raw Git directory private; do not mirror all refs or upload the whole workspace as a ZIP.
- [ ] Confirm ownership/contributor rights and the MIT copyright notice, retain the font licenses, and review dependency terms if distributing built dependencies.
- [ ] Enable GitHub secret scanning/push protection and dependency alerts when the public repository is created.
- [ ] Before a binary release, test real Keychain migration/lock/unlock, consent/cancel/pause/logout, denied permissions, and Google/provider sign-in on the supported macOS versions; use Developer ID signing and notarization.
- [ ] Recheck the upcoming Next.js security patch and dependency audit before deployment.
