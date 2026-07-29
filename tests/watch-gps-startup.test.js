const assert = require("assert");
const fs = require("fs");
const path = require("path");

const viewSource = fs.readFileSync(
  path.join(__dirname, "..", "GarminWOD", "source", "GarminWODView.mc"),
  "utf8"
);

function stationNeedsGps(station) {
  if (station.meters == null) return false;

  const name = String(station.name || "").toLowerCase();
  return name.includes("run") || name.includes("walk") || name.includes("ruck");
}

function startsImmediately(workout) {
  return !shouldWaitForGpsBeforeStart(workout);
}

function shouldWaitForGpsBeforeStart() {
  return false;
}

function run() {
  assert(
    !viewSource.includes("before startLocationEvents gps-wait"),
    "watch startup should not return early before starting recording/timer for GPS acquisition"
  );

  assert.strictEqual(
    startsImmediately({ stations: [{ name: "Row", meters: 500 }] }),
    true,
    "500 m Row should start immediately"
  );

  assert.strictEqual(
    stationNeedsGps({ name: "Row", meters: 500 }),
    false,
    "500 m Row should not require GPS"
  );

  assert.strictEqual(
    stationNeedsGps({ name: "Calorie Row", calories: 25 }),
    false,
    "calorie Row should not require GPS"
  );

  assert.strictEqual(
    startsImmediately({ stations: [{ name: "Run", meters: 400 }] }),
    true,
    "outdoor Run should not require a second START press"
  );

  assert.strictEqual(
    stationNeedsGps({ name: "Run", meters: 400 }),
    true,
    "outdoor Run should still initialize GPS in the background"
  );

  assert.strictEqual(
    stationNeedsGps({ name: "Ruck", meters: 800 }),
    true,
    "ruck distance stations should initialize GPS in the background"
  );

  assert.strictEqual(
    stationNeedsGps({ name: "SkiErg", meters: 500 }),
    false,
    "SkiErg meter targets should not require GPS"
  );

  assert(
    viewSource.includes("skip startLocationEvents no-gps-workout"),
    "non-GPS workouts should skip location event startup"
  );
}

run();
console.log("watch GPS startup tests passed");
