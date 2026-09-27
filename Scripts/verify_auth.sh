#!/bin/bash
# Read-only status inspection. Never print identities, hashes, keys, or responses.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"
mkdir -p .tmp
WORK_DIR=$(mktemp -d "$DIR/.tmp/auth-status.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT
cat > "$WORK_DIR/main.swift" <<'SWIFT'
import Foundation
import Security
import LocalAuthentication

let defaults = UserDefaults(suiteName: "com.mycluely.MyCluely")!
let legacyKeys = ["mycluely_registered_accounts_v1", "mycluely_active_session_email_v1",
                  "mycluely_gemini_api_key", "audiohud_gemini_api_key", "mycluely_openai_api_key"]
let count = legacyKeys.filter { defaults.object(forKey: $0) != nil }.count
print("Legacy sensitive preference fields present: \(count)")
print("Launch the updated app to migrate legacy preferences after Keychain unlock.")
for (label, key) in [("Secure account record", "registered_accounts_v2"), ("Secure active session", "active_user_email")] {
    let context = LAContext()
    context.interactionNotAllowed = true
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.mycluely.apikeys",
        kSecAttrAccount as String: key,
        kSecReturnAttributes as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecUseAuthenticationContext as String: context
    ]
    var attributes: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &attributes)
    switch status {
    case errSecSuccess: print("\(label): present (contents omitted)")
    case errSecItemNotFound: print("\(label): absent")
    default: print("\(label): unavailable (numeric status \(status))")
    }
}
SWIFT
swiftc -module-cache-path "$WORK_DIR/cache" "$WORK_DIR/main.swift" -o "$WORK_DIR/inspect"
"$WORK_DIR/inspect"
