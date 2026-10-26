#!/bin/zsh
# Captures raw App Store screenshots from the booted simulator in demo mode.
# Usage: scripts/capture-screens.sh <simulator-udid> <output-dir>
set -e
UDID=$1; OUT=$2
ROOT=${0:A:h:h}
APP=/Users/nouhe/Builds/CoinValues/DerivedData/Build/Products/Debug-iphonesimulator/CoinValues.app
mkdir -p "$OUT"
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant camera com.coinvalues.identifier
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
shoot() { # name screen [coin] [scroll]
  xcrun simctl terminate "$UDID" com.coinvalues.identifier 2>/dev/null || true
  SIMCTL_CHILD_DEMO_DIR="$ROOT/marketing/demo" SIMCTL_CHILD_DEMO_SCREEN="$2" SIMCTL_CHILD_DEMO_COIN="${3:-}" SIMCTL_CHILD_DEMO_SCROLL="${4:-}" \
    xcrun simctl launch "$UDID" com.coinvalues.identifier >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$1.png" >/dev/null 2>&1
  echo "captured $1"
}
shoot 01-scan scan
shoot 02-result result "Standing Liberty"
shoot 03-collection collection
shoot 04-home home
shoot 05-result-quarter result "Washington"
shoot 06-analyzing analyzing
shoot 07-details result "Morgan" details
