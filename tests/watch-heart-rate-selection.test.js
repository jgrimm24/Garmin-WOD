const assert = require("assert");

function isValidHeartRate(heartRate) {
  return heartRate != null && heartRate >= 30 && heartRate <= 250;
}

function selectHeartRate({ sensorHeartRate, sensorAgeMs, activityHeartRate }) {
  if (
    isValidHeartRate(sensorHeartRate) &&
    sensorAgeMs != null &&
    sensorAgeMs <= 3000
  ) {
    return { value: sensorHeartRate, source: "sensor", status: "fresh", ageMs: sensorAgeMs };
  }

  if (isValidHeartRate(activityHeartRate)) {
    return {
      value: activityHeartRate,
      source: "activity",
      status: sensorHeartRate == null ? "activity-fallback" : "activity-fallback",
      ageMs: sensorAgeMs,
    };
  }

  return {
    value: null,
    source: "none",
    status: sensorHeartRate != null && sensorAgeMs != null && sensorAgeMs > 3000 ? "stale-rejected" : "missing",
    ageMs: sensorAgeMs,
  };
}

function requestedHeartRateSensors({ onboardSupported }) {
  const sensors = ["remote"];

  if (onboardSupported) {
    sensors.push("onboard");
  }

  return sensors;
}

function fitHeartRateMode({ manualHeartRateField }) {
  return manualHeartRateField ? "manual" : "garmin-native";
}

class HeartRateStats {
  constructor() {
    this.sum = 0;
    this.samples = 0;
    this.max = null;
    this.lastMs = null;
  }

  add(heartRate, nowMs, recording) {
    if (!recording || !isValidHeartRate(heartRate)) {
      return false;
    }

    if (this.lastMs != null && nowMs - this.lastMs < 900) {
      return false;
    }

    this.lastMs = nowMs;
    this.sum += heartRate;
    this.samples += 1;
    this.max = this.max == null || heartRate > this.max ? heartRate : this.max;
    return true;
  }

  average() {
    return this.samples === 0 ? null : Math.floor(this.sum / this.samples);
  }
}

function run() {
  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: 140, sensorAgeMs: 1000, activityHeartRate: 120 }),
    { value: 140, source: "sensor", status: "fresh", ageMs: 1000 },
    "fresh sensor HR should be selected"
  );

  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: 140, sensorAgeMs: 3500, activityHeartRate: 128 }),
    { value: 128, source: "activity", status: "activity-fallback", ageMs: 3500 },
    "stale sensor HR should fall back to ActivityInfo HR"
  );

  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: 140, sensorAgeMs: 3500, activityHeartRate: null }),
    { value: null, source: "none", status: "stale-rejected", ageMs: 3500 },
    "stale sensor HR with no ActivityInfo HR should be unavailable"
  );

  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: 29, sensorAgeMs: 1000, activityHeartRate: 251 }),
    { value: null, source: "none", status: "missing", ageMs: 1000 },
    "invalid low/high HR values should be rejected"
  );

  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: null, sensorAgeMs: null, activityHeartRate: 48 }),
    { value: 48, source: "activity", status: "activity-fallback", ageMs: null },
    "valid low resting HR should not be globally rejected"
  );

  assert.deepStrictEqual(
    requestedHeartRateSensors({ onboardSupported: true }),
    ["remote", "onboard"],
    "supported onboard HR should be requested with remote HR"
  );

  assert.deepStrictEqual(
    requestedHeartRateSensors({ onboardSupported: false }),
    ["remote"],
    "older devices should preserve remote HR request"
  );

  assert.strictEqual(
    fitHeartRateMode({ manualHeartRateField: false }),
    "garmin-native",
    "FIT HR should remain Garmin-native when app has no manual HR field"
  );

  const stats = new HeartRateStats();
  assert.strictEqual(stats.add(130, 1000, true), true, "fresh valid sample should count");
  assert.strictEqual(stats.add(130, 1500, true), false, "same tick/window should not duplicate");
  assert.strictEqual(stats.add(151, 2100, true), true, "next fresh sample should count");
  assert.strictEqual(stats.add(160, 3200, false), false, "paused sample should not count");
  assert.strictEqual(stats.add(null, 4300, true), false, "missing sample should be omitted, not recorded as fallback");
  assert.strictEqual(stats.add(252, 4300, true), false, "invalid high sample should not count");
  assert.strictEqual(stats.add(88, 5000, true), true, "valid low active sample should count when fresh");
  assert.strictEqual(stats.average(), 123, "average should use counted samples");
  assert.strictEqual(stats.max, 151, "max should use counted samples");

  stats.lastMs = null;
  assert.strictEqual(stats.add(155, 10000, true), true, "resume with a fresh sample should count");
}

run();
console.log("watch heart-rate selection tests passed");
