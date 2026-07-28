#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODULE_CACHE="/tmp/garmin-wod-swift-module-cache"
MAIN_FILE="/tmp/main.swift"
TEST_BINARY="/tmp/garmin-wod-state-tests"

cp "$ROOT_DIR/ios/GarminWODCompanion/Tests/StateTransitionTests.swift" "$MAIN_FILE"

swiftc \
  -module-cache-path "$MODULE_CACHE" \
  -o "$TEST_BINARY" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Models/WorkoutModels.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Models/HeartRateZone.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Utilities/MovementDisplayFormatter.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Managers/WorkoutContractLoader.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Managers/WorkoutManager.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Managers/TimerManager.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Managers/MockHeartRateManager.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/Managers/BluetoothHeartRateManager.swift" \
  "$ROOT_DIR/ios/GarminWODCompanion/GarminWODCompanion/ViewModels/DisplayViewModel.swift" \
  "$MAIN_FILE"

"$TEST_BINARY"
