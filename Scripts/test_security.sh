#!/bin/bash
# No real Keychain access, microphone capture, or paid provider calls.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"
mkdir -p .tmp
TEST_DIR=$(mktemp -d "$DIR/.tmp/security-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
SWIFT_SOURCES=()
while IFS= read -r source; do
    SWIFT_SOURCES+=("$source")
done < <(find Sources -name '*.swift' ! -name Main.swift | sort)
swiftc -Xfrontend -disable-sandbox -module-cache-path "$TEST_DIR/cache" \
    -framework AppKit -framework SwiftUI -framework ScreenCaptureKit \
    -framework Speech -framework AVFoundation -framework CoreMedia \
    -framework CryptoKit -framework AuthenticationServices -framework Security \
    "${SWIFT_SOURCES[@]}" Tests/AuthManagerTests.swift -o "$TEST_DIR/auth-tests"
"$TEST_DIR/auth-tests"
# Only offline payload/audio tests run unless a caller explicitly opts in.
swiftc -parse-as-library -module-cache-path "$TEST_DIR/cache" -framework AVFoundation \
    Tests/OpenAILiveClientTests.swift -o "$TEST_DIR/openai-tests"
env -u MYCLUELY_RUN_LIVE_TESTS -u OPENAI_API_KEY "$TEST_DIR/openai-tests"
