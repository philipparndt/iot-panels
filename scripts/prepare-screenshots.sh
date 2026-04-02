#!/bin/bash
set -e

APPEARANCE="${APPEARANCE:-dark}"
DEVICES_JSON="${DEVICES_JSON_PATH:-IoTPanels/fastlane/devices.json}"

echo "Preparing simulators for $APPEARANCE mode..."

# Read device names from JSON
devices=$(python3 -c "import json; [print(d) for d in json.load(open('$DEVICES_JSON'))]")

while IFS= read -r device; do
    name=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['name'] == '$device' and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null || true)

    if [ -z "$name" ]; then
        echo "  ⚠ Simulator '$device' not found, skipping"
        continue
    fi

    echo "  Setting up $device ($name)..."

    # Boot if needed
    xcrun simctl boot "$name" 2>/dev/null || true

    # Set appearance
    xcrun simctl ui "$name" appearance "$APPEARANCE"

    # Override status bar
    xcrun simctl status_bar "$name" override \
        --time 9:41 \
        --dataNetwork wifi \
        --wifiMode active \
        --wifiBars 3 \
        --cellularMode active \
        --cellularBars 4 \
        --batteryState charged \
        --batteryLevel 100

done <<< "$devices"

echo "Simulators ready."
