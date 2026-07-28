const assert = require("assert");

function progressionHaptic({
  hasWorkout,
  isManual,
  stationIndex,
  stationCount,
  shouldContinueRound,
}) {
  if (!hasWorkout || !isManual || stationCount <= 0) {
    return "none";
  }

  if (stationIndex < stationCount - 1) {
    return "movement";
  }

  if (shouldContinueRound) {
    return "round";
  }

  return "complete";
}

function run() {
  assert.strictEqual(
    progressionHaptic({
      hasWorkout: true,
      isManual: true,
      stationIndex: 0,
      stationCount: 3,
      shouldContinueRound: true,
    }),
    "movement",
    "middle station should trigger movement haptic"
  );

  assert.strictEqual(
    progressionHaptic({
      hasWorkout: true,
      isManual: true,
      stationIndex: 2,
      stationCount: 3,
      shouldContinueRound: true,
    }),
    "round",
    "last station with more rounds should trigger round haptic"
  );

  assert.strictEqual(
    progressionHaptic({
      hasWorkout: true,
      isManual: true,
      stationIndex: 2,
      stationCount: 3,
      shouldContinueRound: false,
    }),
    "complete",
    "last station of final round should trigger completion haptic"
  );

  assert.strictEqual(
    progressionHaptic({
      hasWorkout: false,
      isManual: true,
      stationIndex: 0,
      stationCount: 3,
      shouldContinueRound: false,
    }),
    "none",
    "missing workout should trigger no haptic"
  );

  assert.strictEqual(
    progressionHaptic({
      hasWorkout: true,
      isManual: false,
      stationIndex: 0,
      stationCount: 3,
      shouldContinueRound: false,
    }),
    "none",
    "non-manual progression should trigger no forward haptic"
  );
}

run();
console.log("watch haptic transition tests passed");
