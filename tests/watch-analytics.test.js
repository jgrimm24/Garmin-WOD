const assert = require("assert");
const fs = require("fs");
const path = require("path");

const viewSource = fs.readFileSync(
  path.join(__dirname, "..", "GarminWOD", "source", "GarminWODView.mc"),
  "utf8"
);
const recorderSource = fs.readFileSync(
  path.join(__dirname, "..", "GarminWOD", "source", "GarminWODAnalyticsRecorder.mc"),
  "utf8"
);
const syncSource = fs.readFileSync(
  path.join(__dirname, "..", "GarminWOD", "source", "GarminWODSessionSync.mc"),
  "utf8"
);

function expectSourceContains(source, snippet, message) {
  assert(
    source.includes(snippet),
    `${message}\nMissing snippet: ${snippet}`
  );
}

console.log("[TEST] watch analytics recorder schema");
expectSourceContains(recorderSource, "class GarminWODAnalyticsRecorder", "analytics recorder class should exist");
expectSourceContains(recorderSource, "completedWorkoutAnalyticsV1", "analytics payload should have a storage key");
expectSourceContains(recorderSource, "\"movementEvents\" => _segments", "payload should expose movement events");
expectSourceContains(recorderSource, "\"transitionTimingAvailable\" => false", "transition timing should be explicitly unavailable");
expectSourceContains(recorderSource, "function addHeartRateSample", "recorder should aggregate existing HR updates");
expectSourceContains(recorderSource, "function finishWorkout(elapsedSeconds, roundNumber, stationIndex, stationName, completesRound)", "finish should distinguish partial and complete rounds");

console.log("[TEST] watch analytics hooks");
expectSourceContains(viewSource, "startWorkoutAnalytics(getElapsedSeconds())", "start should initialize analytics with elapsed active time");
expectSourceContains(viewSource, "recordAnalyticsPause(elapsed)", "pause should record pause events");
expectSourceContains(viewSource, "recordAnalyticsResume(getElapsedSeconds())", "resume should record resume events");
expectSourceContains(viewSource, "recordAnalyticsStationCompleted(elapsed, false)", "NEXT should close the active station segment");
expectSourceContains(viewSource, "recordAnalyticsStationStarted(elapsed)", "NEXT/BACK should open a new station segment");
expectSourceContains(viewSource, "recordAnalyticsRoundCompleted(elapsed, previousRound)", "round rollover should close the previous round");
expectSourceContains(viewSource, "recordAnalyticsRoundStarted(elapsed, _manualRoundNumber)", "round rollover should open the next round");
expectSourceContains(viewSource, "_analyticsRecorder.addHeartRateSample(heartRate)", "existing HR updates should feed analytics");
expectSourceContains(viewSource, "var analytics = status.equals(\"finished\") ? _completedAnalyticsPayload : null;", "finished session publish should include analytics only on finish");
assert(
  !viewSource.includes("_manualStationIndex = stationIndex;"),
  "timed analytics should not mutate manual station progression state"
);
assert(
  !viewSource.includes("_manualRoundNumber = roundNumber;"),
  "timed analytics should not mutate manual round progression state"
);

console.log("[TEST] watch session sync carries optional analytics");
expectSourceContains(syncSource, "function publish(status, round, stationIndex, elapsedSeconds, analytics)", "session publish should accept optional analytics");
expectSourceContains(syncSource, "payload[\"analytics\"] = analytics;", "session payload should include analytics when present");

console.log("watch analytics tests passed");
