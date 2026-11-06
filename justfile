set default-list
set positional-arguments

# xcodebuild lives in full Xcode, not the command line tools shim
export DEVELOPER_DIR := "/Applications/Xcode.app/Contents/Developer"

project := "busy-timer/busy-timer.xcodeproj"
scheme := "busy-timer"
bundle := "Houston-Warren.busy-timer"

# build outside Dropbox: it stamps com.apple.FinderInfo on the .app, which codesign rejects
build := env_var("HOME") / "Library/Developer/Xcode/DerivedData/busy-timer-just"
simulator := `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | grep 'iPhone Duo (' | head -1 | grep -oE '[0-9A-F-]{36}'`

# Format changed Swift files, or the supplied paths.
lint lang="all" *paths:
    @shift; {{ just_executable() }} -f {{ quote(justfile()) }} lint-{{ trim_start_match(lang, "lang=") }} "$@"

lint-all: lint-swift

lint-swift *paths:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$#" -gt 0 ]; then
        swift format --in-place --recursive "$@"
    else
        git ls-files --modified --others --exclude-standard '*.swift' | while IFS= read -r path; do
            swift format --in-place "$path"
        done
    fi

# Check changed Swift files and type-check the iOS app through Xcode.
check lang="all" *paths:
    @shift; {{ just_executable() }} -f {{ quote(justfile()) }} check-{{ trim_start_match(lang, "lang=") }} "$@"

check-all: check-swift

check-swift *paths:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$#" -gt 0 ]; then
        swift format lint --strict --recursive "$@"
    else
        git ls-files --modified --others --exclude-standard '*.swift' | while IFS= read -r path; do
            swift format lint --strict "$path"
        done
    fi
    {{ just_executable() }} build

# Build for the installed Duo simulator.
build:
    xcodebuild -project {{project}} -scheme {{scheme}} -destination 'platform=iOS Simulator,id={{simulator}}' -derivedDataPath "{{build}}" build

# Create a worktree from the current branch using Worktrunk.
wt-init branch:
    wt switch --create --base=@ --no-cd {{ quote(branch) }}

# Unit tests on the installed Duo simulator.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    xcodebuild test -project {{project}} -scheme {{scheme}} -destination 'platform=iOS Simulator,id={{simulator}}' -derivedDataPath "{{build}}" -only-testing:busy-timerTests

# Render SwiftUI screens at iPhone/Duo sizes, short windows, and asymmetric insets.
screenshots:
    #!/usr/bin/env bash
    set -euo pipefail
    output="scratch/render-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$output"
    xcodebuild test -project {{project}} -scheme {{scheme}} -destination 'platform=iOS Simulator,id={{simulator}}' -derivedDataPath "{{build}}" -only-testing:busy-timerTests/LayoutRenderTests -parallel-testing-enabled NO -resultBundlePath "$output/result.xcresult"
    xcrun xcresulttool export attachments --path "$output/result.xcresult" --output-path "$output/attachments"
    uv run python - "$output/attachments" <<'PY'
    import json
    import shutil
    import sys
    from pathlib import Path
    source = Path(sys.argv[1])
    for test in json.loads((source / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            name = attachment["suggestedHumanReadableName"].split("_")[0]
            if name.startswith(("iphone-", "front-", "opened-")):
                shutil.copyfile(source / attachment["exportedFileName"], Path("scratch") / f"{name}.png")
    PY

# Build, install, and launch in the Duo simulator.
run:
    #!/usr/bin/env bash
    set -euo pipefail
    sim='{{simulator}}'
    # build into a fixed path so the app path is predictable
    xcodebuild -project {{project}} -scheme {{scheme}} -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "{{build}}" build
    # boot (waits until ready), show the window, install, launch
    xcrun simctl bootstatus "$sim" -b
    open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
    xcrun simctl install "$sim" "{{build}}/Build/Products/Debug-iphonesimulator/busy-timer.app"
    xcrun simctl launch "$sim" {{bundle}}

# build, install, and launch on a connected iPhone
# needs: phone unlocked, trusted, Developer Mode on (Settings → Privacy & Security)
run-iphone:
    #!/usr/bin/env bash
    set -euo pipefail
    # Xcode 27 lists simulators too; ask for physical iPhones and use their reported ID
    udid=$(xcrun devicectl list devices --filter "Reality = 'physical' AND Model BEGINSWITH 'iPhone'" --hide-default-columns --columns Identifier --hide-headers | awk 'NR == 1 {print $1}')
    if [ -z "$udid" ]; then echo "no iPhone found: plug it in, unlock it, and trust this Mac"; exit 1; fi
    xcodebuild -project {{project}} -scheme {{scheme}} -destination generic/platform=iOS -derivedDataPath "{{build}}" -allowProvisioningUpdates build
    xcrun devicectl device install app --device "$udid" "{{build}}/Build/Products/Debug-iphoneos/busy-timer.app"
    xcrun devicectl device process launch --device "$udid" {{bundle}}
