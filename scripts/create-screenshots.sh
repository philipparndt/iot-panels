#!/bin/bash
cd "$(dirname "$0")/.."
set -e

export DEVICES_JSON_PATH="$(pwd)/IoTPanels/fastlane/devices.json"

rm -rf ./screenshots
mkdir ./screenshots

for appearance in dark light; do
    mkdir "./screenshots/$appearance"
    export APPEARANCE="$appearance"
    ./scripts/prepare-screenshots.sh

    pushd IoTPanels
        fastlane screenshots
        mv fastlane/screenshots/en-US/*.png "../screenshots/$appearance/" 2>/dev/null || true
    popd
done

echo ""
echo "Screenshots saved to ./screenshots/dark and ./screenshots/light"
