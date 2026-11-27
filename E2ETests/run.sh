#!/bin/bash
# Runs the Flipio end-to-end tests against real apps on this Mac.
# The run takes over the keyboard and focus; do not touch them while it runs.
#
# Usage: ./run.sh [--dont-quit-flipio] [swift test arguments]     e.g. ./run.sh --filter "VSCodeBasicTests"
#   --dont-quit-flipio   leave the Flipio under test running after the suite (the previously
#                    running Flipio is not restored)
# Env:   FLIPIO_APP=/path/to/Flipio.app      use an existing build instead of building Debug
set -uo pipefail

cd "$(dirname "$0")"

KEEP_RUNNING=0
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--dont-quit-flipio" ]; then KEEP_RUNNING=1; else ARGS+=("$arg"); fi
done
RUN_DIR=.run
mkdir -p "$RUN_DIR"

flipio_pids() {
    pgrep -f "Flipio.app/Contents/MacOS/Flipio" || true
}

stop_flipio() {
    local pids
    pids=$(flipio_pids)
    [ -z "$pids" ] && return
    kill $pids 2>/dev/null
    for _ in $(seq 1 50); do
        [ -z "$(flipio_pids)" ] && return
        sleep 0.1
    done
}

# Remember the Flipio the user was running so it can be restored afterwards.
# The terminal running this script needs Accessibility to post keystrokes. Trigger the
# system prompt (and open the settings pane) if it is missing, then ask for a re-run.
ensure_accessibility() {
    local trusted
    trusted=$(swift -e 'import ApplicationServices
print(AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary))' 2>/dev/null)
    [ "$trusted" = "true" ] && return
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    echo "Accessibility permission is required for this terminal app." >&2
    echo "Enable it in System Settings > Privacy & Security > Accessibility, then re-run ./run.sh." >&2
    exit 1
}
ensure_accessibility

PREVIOUS_FLIPIO=""
for pid in $(flipio_pids); do
    PREVIOUS_FLIPIO=$(ps -o command= -p "$pid" | sed -E 's#(.*\.app)/Contents/MacOS/Flipio.*#\1#')
    break
done

cleanup() {
    [ "$KEEP_RUNNING" = 1 ] && return
    stop_flipio
    if [ -n "$PREVIOUS_FLIPIO" ] && [ -d "$PREVIOUS_FLIPIO" ]; then
        open "$PREVIOUS_FLIPIO"
    fi
}
trap cleanup EXIT

# Release builds are signed with the self-signed "Flipio Self-Signed" certificate, so macOS
# treats them as one app and keeps their Accessibility permission. Re-sign the Debug build the
# same way (as in .github/workflows/release.yml) so it reuses the permission already granted to
# the installed Flipio. Without the certificate, the Apple Development signature stays and
# macOS asks for Accessibility once for this build.
SIGN_IDENTITY="Flipio Self-Signed"
sign_like_release() {
    local app=$1
    if ! security find-identity -p codesigning | grep -q "$SIGN_IDENTITY"; then
        echo "==> '$SIGN_IDENTITY' certificate not in the keychain; keeping the Xcode signature" >&2
        echo "    (import ../flipio-signing.p12 to reuse the installed Flipio's Accessibility permission)" >&2
        return
    fi
    echo "==> Signing with '$SIGN_IDENTITY'"
    local spk="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
    local item
    for item in \
        "$spk/XPCServices/Installer.xpc" \
        "$spk/XPCServices/Downloader.xpc" \
        "$spk/Autoupdate" \
        "$spk/Updater.app" \
        "$app/Contents/Frameworks/Sparkle.framework"; do
        [ -e "$item" ] && { codesign --force --options=runtime --sign "$SIGN_IDENTITY" "$item" || exit 1; }
    done
    codesign --force --options=runtime --entitlements ../App/Flipio.entitlements \
        --sign "$SIGN_IDENTITY" "$app" || exit 1
}

if [ -n "${FLIPIO_APP:-}" ]; then
    APP="$FLIPIO_APP"
else
    echo "==> Building Flipio (Debug)"
    xcodebuild -project ../Flipio.xcodeproj -scheme Flipio -configuration Debug \
        -derivedDataPath "$RUN_DIR/DerivedData" -quiet build || exit 1
    APP="$RUN_DIR/DerivedData/Build/Products/Debug/Flipio.app"
    sign_like_release "$APP"
fi
[ -d "$APP" ] || { echo "Flipio.app not found at $APP" >&2; exit 1; }

echo "==> Starting $APP with test hooks"
stop_flipio
open -n "$APP" --args -TestHooksEnabled YES
for _ in $(seq 1 100); do
    [ -n "$(flipio_pids)" ] && break
    sleep 0.1
done
sleep 1

echo "==> Running tests (do not touch the keyboard or mouse)"
swift test --no-parallel --disable-xctest --maximum-repetitions 1 ${ARGS[@]+"${ARGS[@]}"}
exit $?
