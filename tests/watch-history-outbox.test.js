const assert = require("assert");
const fs = require("fs");
const path = require("path");

const viewSource = fs.readFileSync(path.join(__dirname, "..", "GarminWOD/source/GarminWODView.mc"), "utf8");
const outboxSource = fs.readFileSync(path.join(__dirname, "..", "GarminWOD/source/GarminWODCompletedWorkoutOutbox.mc"), "utf8");

function expectSourceContains(source, needle, message) {
  assert.ok(source.includes(needle), message || `Expected source to contain ${needle}`);
}

console.log("[TEST] watch completed workout outbox persistence");
expectSourceContains(outboxSource, "class GarminWODCompletedWorkoutOutbox", "outbox class should exist");
expectSourceContains(outboxSource, 'const STORAGE_KEY = "completedWorkoutOutboxV1"', "outbox should use a durable storage key");
expectSourceContains(outboxSource, 'const MAX_PENDING_SESSIONS = 10', "outbox should have a bounded queue");
expectSourceContains(outboxSource, "Storage.getValue(STORAGE_KEY)", "outbox should reload persisted queue");
expectSourceContains(outboxSource, "Storage.setValue(STORAGE_KEY, _queue)", "outbox should persist queue changes");
expectSourceContains(outboxSource, "COMPLETED_WORKOUTS_URL", "outbox should target completed-workout archive");

console.log("[TEST] watch completed workout idempotent acknowledgement");
expectSourceContains(outboxSource, "containsSession(sessionId)", "enqueue should dedupe by session ID");
expectSourceContains(outboxSource, "acknowledgedSessionId.equals(expectedSessionId)", "ack should remove only matching session ID");
expectSourceContains(outboxSource, "removeFirst()", "ack should remove the oldest uploaded session");
expectSourceContains(outboxSource, "uploadPending()", "ack should continue FIFO upload");
expectSourceContains(outboxSource, "responseCode >= 200 && responseCode < 300", "ack should require successful HTTP status");

console.log("[TEST] watch view queues completed analytics without changing live session sync");
expectSourceContains(viewSource, "var _completedOutbox;", "view should own completed-session outbox");
expectSourceContains(viewSource, "_completedOutbox = new GarminWODCompletedWorkoutOutbox();", "view should initialize outbox");
expectSourceContains(viewSource, "_completedOutbox.uploadPending();", "view should retry pending uploads on show");
expectSourceContains(viewSource, "function enqueueCompletedWorkout() as Void", "view should isolate completed-session enqueue");
expectSourceContains(viewSource, '"analytics" => _completedAnalyticsPayload', "completed payload should include full analytics");
expectSourceContains(viewSource, "_completedOutbox.enqueue(completedSession);", "finish should queue completed session");
expectSourceContains(viewSource, 'var analytics = status.equals("finished") ? _completedAnalyticsPayload : null;', "existing live finished-session analytics should remain");

console.log("[TEST] PASS: watch completed workout outbox");
