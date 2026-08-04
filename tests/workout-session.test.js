const assert = require("assert");
const fs = require("fs");
const path = require("path");
const {
  acceptWorkoutSessionState,
  normalizeWorkoutAnalytics,
  normalizeWorkoutSessionState,
  server,
} = require("../server");

const SESSION_PATH = path.join(__dirname, "..", "data", "workout-session.json");

function validState(overrides = {}) {
  return {
    workoutId: "id:roney|fp:test",
    sessionId: "session-1",
    revision: 1,
    status: "running",
    round: 1,
    stationIndex: 0,
    elapsedSeconds: 0,
    ...overrides,
  };
}

function expectValid(input, message) {
  const result = normalizeWorkoutSessionState(input, 12345);
  assert.equal(result.ok, true, message);
  return result.state;
}

function expectInvalid(input, message) {
  const result = normalizeWorkoutSessionState(input, 12345);
  assert.equal(result.ok, false, message);
}

console.log("[TEST] workout-session accepts valid payload");
const normalized = expectValid(validState(), "valid session should normalize");
assert.deepEqual(normalized, {
  workoutId: "id:roney|fp:test",
  sessionId: "session-1",
  revision: 1,
  status: "running",
  round: 1,
  stationIndex: 0,
  elapsedSeconds: 0,
  updatedAt: 12345,
  analytics: null,
});

console.log("[TEST] workout-session normalizes optional analytics payload");
const analytics = normalizeWorkoutAnalytics({
  schemaVersion: 1,
  sessionId: "session-1",
  workoutId: "id:roney|fp:test",
  workoutName: "Roney",
  startedAt: 100,
  finishedAt: 220,
  totalActiveSeconds: 120,
  roundsCompleted: 2,
  transitionTimingAvailable: false,
  movementEvents: [
    {
      movementIndex: 0,
      movementName: "20 CAL ROW",
      prescribedCalories: 20,
      roundNumber: 1,
      enteredElapsedSeconds: 0,
      exitedElapsedSeconds: 45,
      durationSeconds: 45,
      averageHeartRate: 140,
      maximumHeartRate: 154,
      minimumHeartRate: 120,
      heartRateSampleCount: 30,
    },
    {
      movementName: "missing required fields",
    },
  ],
  events: [
    {
      eventType: "station_started",
      sequence: 1,
      elapsedSeconds: 0,
      roundNumber: 1,
      stationIndex: 0,
      stationName: "20 CAL ROW",
    },
    {
      eventType: "",
      sequence: 2,
      elapsedSeconds: 1,
    },
  ],
});
assert.equal(analytics.sessionId, "session-1", "analytics session ID should normalize");
assert.equal(analytics.movementEvents.length, 1, "invalid movement analytics events should be dropped");
assert.equal(analytics.events.length, 1, "invalid timeline events should be dropped");
assert.equal(analytics.movementEvents[0].prescribedCalories, 20, "calorie prescription should normalize");

const stateWithAnalytics = expectValid(
  validState({
    status: "finished",
    analytics,
  }),
  "session with analytics should normalize"
);
assert.equal(stateWithAnalytics.analytics.movementEvents.length, 1, "session state should preserve analytics");

console.log("[TEST] workout-session rejects missing and invalid fields");
expectInvalid(validState({ workoutId: "" }), "empty workoutId should be rejected");
expectInvalid(validState({ sessionId: "" }), "empty sessionId should be rejected");
expectInvalid(validState({ revision: 0 }), "revision 0 should be rejected");
expectInvalid(validState({ revision: 1.5 }), "non-integer revision should be rejected");
expectInvalid(validState({ status: "done" }), "unknown status should be rejected");
expectInvalid(validState({ round: 0 }), "round 0 should be rejected");
expectInvalid(validState({ stationIndex: -1 }), "negative stationIndex should be rejected");
expectInvalid(validState({ elapsedSeconds: -1 }), "negative elapsedSeconds should be rejected");

console.log("[TEST] workout-session revision acceptance");
const existing = expectValid(validState({ revision: 3, elapsedSeconds: 40 }), "existing session normalizes");
const sameRevision = expectValid(validState({ revision: 3, elapsedSeconds: 45 }), "same revision normalizes");
const olderRevision = expectValid(validState({ revision: 2, elapsedSeconds: 20 }), "older revision normalizes");
const newerRevision = expectValid(validState({ revision: 4, elapsedSeconds: 50 }), "newer revision normalizes");

let decision = acceptWorkoutSessionState(existing, sameRevision);
assert.equal(decision.ok, true, "same revision should be accepted");
assert.equal(decision.write, false, "same revision should not rewrite stored state");
assert.equal(decision.session.elapsedSeconds, 40, "same revision should return existing state");

decision = acceptWorkoutSessionState(existing, olderRevision);
assert.equal(decision.ok, false, "older revision should be rejected");

decision = acceptWorkoutSessionState(existing, newerRevision);
assert.equal(decision.ok, true, "newer revision should be accepted");
assert.equal(decision.write, true, "newer revision should write");
assert.equal(decision.session.elapsedSeconds, 50, "newer revision should become latest");

console.log("[TEST] workout-session accepts new session attempts");
decision = acceptWorkoutSessionState(existing, expectValid(validState({
  sessionId: "session-2",
  revision: 1,
  elapsedSeconds: 0,
}), "new session normalizes"));
assert.equal(decision.ok, true, "new session should be accepted");
assert.equal(decision.write, true, "new session should write");

async function requestJson(baseUrl, pathname, options = {}) {
  const response = await fetch(`${baseUrl}${pathname}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  return {
    status: response.status,
    body: text ? JSON.parse(text) : null,
  };
}

async function withTempSessionFile(test) {
  let original = null;

  try {
    original = await fs.promises.readFile(SESSION_PATH, "utf8");
  } catch (error) {
    original = null;
  }

  try {
    await fs.promises.unlink(SESSION_PATH);
  } catch (error) {
    // Missing session state is the desired starting point for these route tests.
  }

  try {
    await test();
  } finally {
    if (original === null) {
      try {
        await fs.promises.unlink(SESSION_PATH);
      } catch (error) {
        // Nothing to restore.
      }
    } else {
      await fs.promises.mkdir(path.dirname(SESSION_PATH), { recursive: true });
      await fs.promises.writeFile(SESSION_PATH, original, "utf8");
    }
  }
}

async function withListeningServer(test) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      server.off("error", reject);
      resolve();
    });
  });

  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  try {
    await test(baseUrl);
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => {
        if (error) reject(error);
        else resolve();
      });
    });
  }
}

async function runRouteTests() {
  console.log("[TEST] workout-session routes handle empty state, save, fetch, and stale revisions");

  await withTempSessionFile(async () => {
    await withListeningServer(async (baseUrl) => {
      let response = await requestJson(baseUrl, "/api/workout-session");
      assert.equal(response.status, 404, "empty session GET should return 404");

      response = await requestJson(baseUrl, "/api/workout-session", {
        method: "PUT",
        body: JSON.stringify(validState({
          revision: 1,
          status: "running",
          elapsedSeconds: 12,
        })),
      });
      assert.equal(response.status, 200, "valid session PUT should succeed");
      assert.equal(response.body.session.revision, 1, "stored session should include revision");
      assert.equal(response.body.session.elapsedSeconds, 12, "stored session should include elapsed time");

      response = await requestJson(baseUrl, "/api/workout-session");
      assert.equal(response.status, 200, "saved session GET should succeed");
      assert.equal(response.body.revision, 1, "GET should return latest revision");
      assert.equal(response.body.elapsedSeconds, 12, "GET should return latest elapsed time");

      response = await requestJson(baseUrl, "/api/workout-session", {
        method: "PUT",
        body: JSON.stringify(validState({
          revision: 2,
          status: "paused",
          elapsedSeconds: 20,
        })),
      });
      assert.equal(response.status, 200, "newer session PUT should succeed");
      assert.equal(response.body.session.status, "paused", "newer session should replace stored state");

      response = await requestJson(baseUrl, "/api/workout-session", {
        method: "PUT",
        body: JSON.stringify(validState({
          revision: 1,
          status: "running",
          elapsedSeconds: 5,
        })),
      });
      assert.equal(response.status, 409, "older session revision should be rejected by route");
    });
  });
}

runRouteTests()
  .then(() => {
    console.log("[TEST] PASS: workout-session contract");
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
