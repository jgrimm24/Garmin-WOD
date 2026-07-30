const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { server } = require("../server");

const LATEST_WORKOUT_PATH = path.join(__dirname, "..", "data", "latest-workout.json");

function latestWorkout(overrides = {}) {
  return {
    schemaVersion: 1,
    id: "latest-roney",
    title: "Roney",
    type: "For Time",
    durationMinutes: null,
    rounds: 4,
    notes: [],
    sourceText: "Roney\n4 rounds for time",
    createdAt: "2026-07-30T12:00:00.000Z",
    updatedAt: "2026-07-30T12:00:00.000Z",
    stations: [
      {
        id: "station-1",
        name: "Run",
        reps: null,
        calories: null,
        meters: 200,
        weightLb: null,
        maleWeightLb: null,
        femaleWeightLb: null,
        workSeconds: null,
        notes: "200m Run",
      },
    ],
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

async function withTempLatestWorkoutFile(test) {
  let original = null;

  try {
    original = await fs.promises.readFile(LATEST_WORKOUT_PATH, "utf8");
  } catch (error) {
    original = null;
  }

  try {
    await fs.promises.unlink(LATEST_WORKOUT_PATH);
  } catch (error) {
    // Missing latest workout is the desired test setup.
  }

  try {
    await test();
  } finally {
    if (original === null) {
      try {
        await fs.promises.unlink(LATEST_WORKOUT_PATH);
      } catch (error) {
        // Nothing to restore.
      }
    } else {
      await fs.promises.mkdir(path.dirname(LATEST_WORKOUT_PATH), { recursive: true });
      await fs.promises.writeFile(LATEST_WORKOUT_PATH, original, "utf8");
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

async function run() {
  console.log("[TEST] latest-workout routes persist and do not consume saved WOD");

  await withTempLatestWorkoutFile(async () => {
    await withListeningServer(async (baseUrl) => {
      let response = await requestJson(baseUrl, "/api/latest-workout");
      assert.equal(response.status, 404, "empty latest WOD GET should return 404");

      response = await requestJson(baseUrl, "/api/latest-workout", {
        method: "POST",
        body: JSON.stringify(latestWorkout()),
      });
      assert.equal(response.status, 200, "latest WOD save should succeed");
      assert.equal(response.body.workout.title, "Roney");

      response = await requestJson(baseUrl, "/api/latest-workout");
      assert.equal(response.status, 200, "first latest WOD GET should succeed");
      assert.equal(response.body.title, "Roney");

      response = await requestJson(baseUrl, "/api/latest-workout");
      assert.equal(response.status, 200, "second latest WOD GET should still succeed");
      assert.equal(response.body.title, "Roney");

      const savedFile = JSON.parse(await fs.promises.readFile(LATEST_WORKOUT_PATH, "utf8"));
      assert.equal(savedFile.title, "Roney", "latest-workout.json should remain on disk after repeated GETs");
    });
  });

  console.log("[TEST] PASS: latest-workout persistence");
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
