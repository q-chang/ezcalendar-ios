#!/usr/bin/env bash
#
# Build and run the EZCalendar Demo app on an iOS Simulator.
#
#   scripts/demo/run-demo.sh                    # newest available iPhone
#   scripts/demo/run-demo.sh -d "iPhone 17e"    # a specific device
#   scripts/demo/run-demo.sh --list             # what's installed
#   scripts/demo/run-demo.sh --build-only       # compile, don't launch
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE="$REPO_ROOT/EZCalendar.xcworkspace"
SCHEME="Demo"
DERIVED_DATA="$REPO_ROOT/.build/demo-dd"

DEVICE="${EZ_DEMO_DEVICE:-}"
CONFIGURATION="Debug"
CLEAN=0
BUILD_ONLY=0
CONSOLE=0
VERBOSE=0

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
$(bold "run-demo.sh") — build and run the EZCalendar Demo on a simulator

USAGE
    scripts/demo/run-demo.sh [options]

OPTIONS
    -d, --device <name>     Simulator device name (e.g. "iPhone 17 Pro").
                            Defaults to \$EZ_DEMO_DEVICE, then to the newest
                            available iPhone.
    -c, --configuration <c> Debug (default) or Release.
        --clean             Wipe derived data before building.
        --build-only        Build without installing or launching.
        --console           Stream the app's stdout/stderr after launch.
                            Ctrl-C detaches; the app keeps running.
    -l, --list              List available simulator devices and exit.
    -v, --verbose           Show full xcodebuild output.
    -h, --help              Show this help.

ENVIRONMENT
    EZ_DEMO_DEVICE          Default device name.

NOTE
    The Demo's Xcode project links a *sibling checkout* at ../../EZCalendar-Swift,
    not this repository's Sources/. Changes made here will not appear in the app
    until that package reference is repointed. See AGENTS.md, landmine #1.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--device)        DEVICE="${2:-}"; [[ -n "$DEVICE" ]] || die "--device needs a value"; shift 2 ;;
        -c|--configuration) CONFIGURATION="${2:-}"; [[ -n "$CONFIGURATION" ]] || die "--configuration needs a value"; shift 2 ;;
        --clean)            CLEAN=1; shift ;;
        --build-only)       BUILD_ONLY=1; shift ;;
        --console)          CONSOLE=1; shift ;;
        -l|--list)          xcrun simctl list devices available; exit 0 ;;
        -v|--verbose)       VERBOSE=1; shift ;;
        -h|--help)          usage; exit 0 ;;
        *)                  die "unknown option: $1  (try --help)" ;;
    esac
done

command -v xcodebuild >/dev/null || die "xcodebuild not found. Install Xcode and run: xcode-select --install"
[[ -d "$WORKSPACE" ]] || die "workspace not found: $WORKSPACE"

# ---------------------------------------------------------------------------
# Resolve a simulator UDID.
#
# With no --device, pick the newest iPhone: sort runtimes by numeric iOS
# version, then take the highest-numbered device in the newest one.
# ---------------------------------------------------------------------------
resolve_udid() {
    local wanted="$1"
    xcrun simctl list devices available -j | python3 -c '
import json, re, sys

wanted = sys.argv[1] if len(sys.argv) > 1 else ""
devices = json.load(sys.stdin)["devices"]

def runtime_key(rt):
    nums = re.findall(r"\d+", rt.rsplit(".", 1)[-1])
    return [int(n) for n in nums] or [0]

candidates = []
for runtime, entries in devices.items():
    if "iOS" not in runtime:
        continue
    for d in entries:
        if d.get("isAvailable", True):
            candidates.append((runtime_key(runtime), d["name"], d["udid"]))

if not candidates:
    sys.exit("no available iOS simulators found")

if wanted:
    hits = [c for c in candidates if c[1] == wanted]
    if not hits:
        names = sorted({c[1] for c in candidates})
        sys.exit("no available simulator named %r\navailable: %s" % (wanted, ", ".join(names)))
    hits.sort(key=lambda c: c[0])
    print(hits[-1][2])
else:
    iphones = [c for c in candidates if c[1].startswith("iPhone")] or candidates
    # newest runtime first, then highest model number within it
    def model_key(c):
        nums = re.findall(r"\d+", c[1])
        return [int(n) for n in nums] or [0]
    iphones.sort(key=lambda c: (c[0], model_key(c)))
    print(iphones[-1][2])
' "$wanted"
}

UDID="$(resolve_udid "$DEVICE")" || die "could not resolve a simulator"
DEVICE_NAME="$(xcrun simctl list devices -j | python3 -c '
import json, sys
udid = sys.argv[1]
for entries in json.load(sys.stdin)["devices"].values():
    for d in entries:
        if d["udid"] == udid:
            print(d["name"]); raise SystemExit
' "$UDID")"

info "Simulator: $DEVICE_NAME ($UDID)"

warn "the Demo links ../../EZCalendar-Swift, not this repo's Sources/ (AGENTS.md #1)"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
if [[ $CLEAN -eq 1 ]]; then
    info "Cleaning $DERIVED_DATA"
    rm -rf "$DERIVED_DATA"
fi

info "Building $SCHEME ($CONFIGURATION)"
build_args=(
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "platform=iOS Simulator,id=$UDID,arch=arm64"
    -derivedDataPath "$DERIVED_DATA"
    build
)

if [[ $VERBOSE -eq 1 ]]; then
    xcodebuild "${build_args[@]}"
elif command -v xcbeautify >/dev/null; then
    xcodebuild "${build_args[@]}" | xcbeautify
else
    # Keep only the lines worth reading; pipefail preserves xcodebuild's status.
    xcodebuild "${build_args[@]}" 2>&1 \
        | grep -E "(error|warning):|^\*\* " \
        | grep -vE "IDERunDestination|AppIntents.framework|multiple matching destinations" \
        || true
    # shellcheck disable=SC2181
    if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
        die "build failed — rerun with --verbose for full output"
    fi
fi

PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphonesimulator"
APP_PATH="$(find "$PRODUCTS_DIR" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)"
[[ -n "$APP_PATH" ]] || die "no .app found in $PRODUCTS_DIR"

info "Built $(basename "$APP_PATH")"

if [[ $BUILD_ONLY -eq 1 ]]; then
    bold "Build succeeded: $APP_PATH"
    exit 0
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"

# ---------------------------------------------------------------------------
# Boot, install, launch
# ---------------------------------------------------------------------------
STATE="$(xcrun simctl list devices -j | python3 -c '
import json, sys
udid = sys.argv[1]
for entries in json.load(sys.stdin)["devices"].values():
    for d in entries:
        if d["udid"] == udid:
            print(d["state"]); raise SystemExit
' "$UDID")"

if [[ "$STATE" != "Booted" ]]; then
    info "Booting $DEVICE_NAME"
    xcrun simctl boot "$UDID"
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null

open -a Simulator --args -CurrentDeviceUDID "$UDID" || warn "could not bring Simulator.app to the front"

info "Installing $BUNDLE_ID"
xcrun simctl install "$UDID" "$APP_PATH"

info "Launching $BUNDLE_ID"
if [[ $CONSOLE -eq 1 ]]; then
    bold "Streaming console — Ctrl-C detaches, the app keeps running."
    xcrun simctl launch --console-pty "$UDID" "$BUNDLE_ID"
else
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
    bold "Running on $DEVICE_NAME."
fi
