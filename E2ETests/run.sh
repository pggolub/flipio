#!/bin/bash
# Runs the Flipio end-to-end tests against real apps on this Mac.
# The run takes over the keyboard and focus; do not touch them while it runs.
#
# Usage: ./run.sh [swift test arguments]     e.g. ./run.sh --filter "VS Code"
# Env:   FLIPIO_APP=/path/to/Flipio.app      use an existing build instead of building Debug
set -uo pipefail

cd "$(dirname "$0")"
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
PREVIOUS_FLIPIO=""
for pid in $(flipio_pids); do
    PREVIOUS_FLIPIO=$(ps -o command= -p "$pid" | sed -E 's#(.*\.app)/Contents/MacOS/Flipio.*#\1#')
    break
done

cleanup() {
    stop_flipio
    if [ -n "$PREVIOUS_FLIPIO" ] && [ -d "$PREVIOUS_FLIPIO" ]; then
        open "$PREVIOUS_FLIPIO"
    fi
}
trap cleanup EXIT

if [ -n "${FLIPIO_APP:-}" ]; then
    APP="$FLIPIO_APP"
else
    echo "==> Building Flipio (Debug)"
    xcodebuild -project ../Flipio.xcodeproj -scheme Flipio -configuration Debug \
        -derivedDataPath "$RUN_DIR/DerivedData" -quiet build || exit 1
    APP="$RUN_DIR/DerivedData/Build/Products/Debug/Flipio.app"
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
swift test --no-parallel "$@"
exit $?
