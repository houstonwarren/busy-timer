# xcodebuild lives in full Xcode, not the command line tools shim
export DEVELOPER_DIR := "/Applications/Xcode.app/Contents/Developer"

project := "busy-timer/busy-timer.xcodeproj"
scheme := "busy-timer"
bundle := "Houston-Warren.busy-timer"

# unit tests on the newest iPhone 17 Pro Max simulator
test:
    #!/usr/bin/env bash
    set -euo pipefail
    # available list runs oldest → newest runtime, so tail -1 is the latest
    sim=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max (" | tail -1 | grep -oE '[0-9A-F-]{36}')
    xcodebuild test -project {{project}} -scheme {{scheme}} -destination "platform=iOS Simulator,id=$sim" -only-testing:busy-timerTests

# build, install, and launch in the newest iPhone 17 Pro Max simulator
run:
    #!/usr/bin/env bash
    set -euo pipefail
    sim=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max (" | tail -1 | grep -oE '[0-9A-F-]{36}')
    # build into .build so the app path is predictable
    xcodebuild -project {{project}} -scheme {{scheme}} -destination "platform=iOS Simulator,id=$sim" -derivedDataPath .build build
    # boot (waits until ready), show the window, install, launch
    xcrun simctl bootstatus "$sim" -b
    open -a Simulator
    xcrun simctl install "$sim" .build/Build/Products/Debug-iphonesimulator/busy-timer.app
    xcrun simctl launch "$sim" {{bundle}}

# build, install, and launch on a connected iPhone
# needs: phone unlocked, trusted, Developer Mode on (Settings → Privacy & Security)
run-iphone:
    #!/usr/bin/env bash
    set -euo pipefail
    udid=$(xcrun devicectl list devices | grep -i iphone | grep -ioE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)
    if [ -z "$udid" ]; then echo "no iPhone found — plug it in, unlock it, and trust this Mac"; exit 1; fi
    xcodebuild -project {{project}} -scheme {{scheme}} -destination generic/platform=iOS -derivedDataPath .build -allowProvisioningUpdates build
    xcrun devicectl device install app --device "$udid" .build/Build/Products/Debug-iphoneos/busy-timer.app
    xcrun devicectl device process launch --device "$udid" {{bundle}}
