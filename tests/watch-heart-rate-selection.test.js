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
    return { value: sensorHeartRate, source: "sensor" };
  }

  if (isValidHeartRate(activityHeartRate)) {
    return { value: activityHeartRate, source: "activity" };
  }

  return { value: null, source: "none" };
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
    { value: 140, source: "sensor" },
    "fresh sensor HR should be selected"
  );

  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: 140, sensorAgeMs: 3500, activityHeartRate: 128 }),
    { value: 128, source: "activity" },
    "stale sensor HR should fall back to ActivityInfo HR"
  );

  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: 140, sensorAgeMs: 3500, activityHeartRate: null }),
    { value: null, source: "none" },
    "stale sensor HR with no ActivityInfo HR should be unavailable"
  );

  assert.deepStrictEqual(
    selectHeartRate({ sensorHeartRate: 29, sensorAgeMs: 1000, activityHeartRate: 251 }),
    { value: null, source: "none" },
    "invalid low/high HR values should be rejected"
  );

  const stats = new HeartRateStats();
  assert.strictEqual(stats.add(130, 1000, true), true, "fresh valid sample should count");
  assert.strictEqual(stats.add(130, 1500, true), false, "same tick/window should not duplicate");
  assert.strictEqual(stats.add(151, 2100, true), true, "next fresh sample should count");
  assert.strictEqual(stats.add(160, 3200, false), false, "paused sample should not count");
  assert.strictEqual(stats.add(252, 4300, true), false, "invalid high sample should not count");
  assert.strictEqual(stats.average(), 140, "average should use counted samples");
  assert.strictEqual(stats.max, 151, "max should use counted samples");
}

run();
console.log("watch heart-rate selection tests passed");
