const assert = require("assert");
const fs = require("fs");
const path = require("path");
const {
  buildCompletedWorkoutSummary,
  normalizeCompletedWorkout,
  server,
} = require("../server");

const ARCHIVE_DIR = path.join(__dirname, "..", "data", "completed-workouts");
const SESSION_PATH = path.join(__dirname, "..", "data", "workout-session.json");

function completedWorkout(overrides = {}) {
  const sessionId = overrides.sessionId || "history-session-1";
  return {
    schemaVersion: 1,
    sessionId,
    workoutIdentity: "id:donkey-kong|fp:test",
    workoutName: "Donkey Kong",
    startedAt: 1_785_800_000,
    finishedAt: 1_785_800_900,
    totalActiveSeconds: 900,
    totalActiveMs: 900_000,
    roundsCompleted: 3,
    status: "completed",
    source: {
      device: "watch",
      appVersion: "test",
      deviceModel: "fenix8solar51mm",
    },
    analytics: {
      schemaVersion: 1,
      sessionId,
      workoutId: "id:donkey-kong|fp:test",
      workoutName: "Donkey Kong",
      startedAt: 1_785_800_000,
      finishedAt: 1_785_800_900,
      totalActiveSeconds: 900,
      roundsCompleted: 3,
      transitionTimingAvailable: false,
      movementEvents: [
        {
          movementIndex: 0,
          movementName: "21 BURPEES",
          prescribedReps: 21,
          roundNumber: 1,
          enteredElapsedSeconds: 0,
          exitedElapsedSeconds: 45,
          durationSeconds: 45,
          averageHeartRate: 140,
          maximumHeartRate: 162,
          minimumHeartRate: 120,
          heartRateSampleCount: 30,
        },
      ],
      events: [
        {
          eventType: "workout_started",
          sequence: 1,
          elapsedSeconds: 0,
          timestamp: 1_785_800_000,
          roundNumber: 1,
          stationIndex: 0,
          stationName: "21 BURPEES",
        },
      ],
    },
    ...overrides,
  };
}

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

async function withCleanArchive(test) {
  const backupDir = `${ARCHIVE_DIR}.test-backup-${process.pid}-${Date.now()}`;
  let hadArchive = false;
  let originalSession = null;

  try {
    await fs.promises.access(ARCHIVE_DIR);
    await fs.promises.rename(ARCHIVE_DIR, backupDir);
    hadArchive = true;
  } catch (error) {
    hadArchive = false;
  }

  try {
    originalSession = await fs.promises.readFile(SESSION_PATH, "utf8");
  } catch (error) {
    originalSession = null;
  }

  try {
    await fs.promises.unlink(SESSION_PATH);
  } catch (error) {
    // Empty latest session is the desired starting point.
  }

  try {
    await test();
  } finally {
    await fs.promises.rm(ARCHIVE_DIR, { recursive: true, force: true });
    if (hadArchive) {
      await fs.promises.rename(backupDir, ARCHIVE_DIR);
    }

    if (originalSession === null) {
      await fs.promises.rm(SESSION_PATH, { force: true });
    } else {
      await fs.promises.mkdir(path.dirname(SESSION_PATH), { recursive: true });
      await fs.promises.writeFile(SESSION_PATH, originalSession, "utf8");
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

console.log("[TEST] completed-workout normalization and summary");
const normalized = normalizeCompletedWorkout(completedWorkout(), 1_785_801_000);
assert.equal(normalized.ok, true, "valid completed workout should normalize");
assert.equal(normalized.session.sessionId, "history-session-1", "session ID should be retained");
assert.equal(normalized.session.analytics.movementEvents.length, 1, "analytics should normalize");
const summary = buildCompletedWorkoutSummary(normalized.session);
assert.equal(summary.sessionId, "history-session-1", "summary should retain session ID");
assert.equal(summary.movementCount, 1, "summary should count movement events");
assert.equal(summary.averageHeartRate, 140, "summary should calculate weighted average HR");
assert.equal(summary.maximumHeartRate, 162, "summary should calculate maximum HR");
assert.equal(summary.hasDetailedAnalytics, true, "summary should mark detailed analytics");

const invalid = normalizeCompletedWorkout(completedWorkout({ sessionId: "../bad" }));
assert.equal(invalid.ok, false, "unsafe session IDs should be rejected");

async function run() {
  console.log("[TEST] completed-workout archive routes persist, dedupe, paginate, and retrieve detail");

  await withCleanArchive(async () => {
    await withListeningServer(async (baseUrl) => {
      let response = await requestJson(baseUrl, "/api/completed-workouts");
      assert.equal(response.status, 200, "empty archive list should succeed");
      assert.deepEqual(response.body.items, [], "empty archive should return no items");

      response = await requestJson(baseUrl, "/api/completed-workouts", {
        method: "POST",
        body: JSON.stringify(completedWorkout({ sessionId: "history-session-1", finishedAt: 100 })),
      });
      assert.equal(response.status, 200, "valid completed workout POST should succeed");
      assert.equal(response.body.accepted, true, "POST should acknowledge storage");
      assert.equal(response.body.duplicate, false, "first upload should not be duplicate");

      response = await requestJson(baseUrl, "/api/completed-workouts", {
        method: "POST",
        body: JSON.stringify(completedWorkout({ sessionId: "history-session-1", finishedAt: 200 })),
      });
      assert.equal(response.status, 200, "duplicate completed workout POST should succeed");
      assert.equal(response.body.duplicate, true, "duplicate upload should be idempotent");

      await requestJson(baseUrl, "/api/completed-workouts", {
        method: "POST",
        body: JSON.stringify(completedWorkout({ sessionId: "history-session-2", finishedAt: 300, workoutName: "Workout B" })),
      });
      await requestJson(baseUrl, "/api/completed-workouts", {
        method: "POST",
        body: JSON.stringify(completedWorkout({ sessionId: "history-session-3", finishedAt: 200, workoutName: "Workout C" })),
      });

      response = await requestJson(baseUrl, "/api/completed-workouts?limit=2");
      assert.equal(response.status, 200, "history list should succeed");
      assert.deepEqual(
        response.body.items.map((item) => item.sessionId),
        ["history-session-2", "history-session-3"],
        "history list should be newest first"
      );
      assert.equal(response.body.items[0].analytics, undefined, "history summaries should not include full analytics");
      assert.equal(response.body.nextCursor, "200", "history list should return pagination cursor");

      response = await requestJson(baseUrl, `/api/completed-workouts?limit=2&before=${response.body.nextCursor}`);
      assert.equal(response.status, 200, "history cursor page should succeed");
      assert.deepEqual(response.body.items.map((item) => item.sessionId), ["history-session-1"], "cursor should load older items");

      response = await requestJson(baseUrl, "/api/completed-workouts/history-session-2");
      assert.equal(response.status, 200, "history detail should succeed");
      assert.equal(response.body.session.sessionId, "history-session-2", "detail should return full session");
      assert.equal(response.body.session.analytics.movementEvents.length, 1, "detail should include analytics");

      response = await requestJson(baseUrl, "/api/completed-workouts/..%2Fbad");
      assert.equal(response.status, 400, "path traversal session ID should be rejected");

      response = await requestJson(baseUrl, "/api/completed-workouts", {
        method: "POST",
        body: JSON.stringify(completedWorkout({ sessionId: "../bad" })),
      });
      assert.equal(response.status, 400, "malformed completed workout should be rejected");
    });
  });

  console.log("[TEST] completed-workout archive imports latest finished session without consuming it");
  await withCleanArchive(async () => {
    await fs.promises.mkdir(path.dirname(SESSION_PATH), { recursive: true });
    await fs.promises.writeFile(
      SESSION_PATH,
      JSON.stringify({
        workoutId: "id:donkey-kong|fp:test",
        sessionId: "latest-finished-session",
        revision: 10,
        status: "finished",
        round: 3,
        stationIndex: 2,
        elapsedSeconds: 900,
        updatedAt: Date.now(),
        analytics: completedWorkout({ sessionId: "latest-finished-session" }).analytics,
      }, null, 2),
      "utf8"
    );

    await withListeningServer(async (baseUrl) => {
      const response = await requestJson(baseUrl, "/api/completed-workouts");
      assert.equal(response.status, 200, "history list should migrate latest finished session");
      assert.equal(response.body.items[0].sessionId, "latest-finished-session", "latest finished session should be archived");

      const latestState = JSON.parse(await fs.promises.readFile(SESSION_PATH, "utf8"));
      assert.equal(latestState.sessionId, "latest-finished-session", "migration should not consume latest session");
    });
  });

  console.log("[TEST] PASS: completed-workout archive");
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
