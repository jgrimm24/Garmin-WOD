const assert = require("assert");
const DraftState = require("../importer/draft-state");

function workout(overrides = {}) {
  return {
    schemaVersion: 1,
    id: "wod-roney",
    title: "Roney",
    type: "For Time",
    durationMinutes: null,
    rounds: 4,
    notes: ["M 135 lb", "F 95 lb"],
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
      {
        id: "station-2",
        name: "Thrusters",
        reps: 11,
        calories: null,
        meters: null,
        weightLb: 135,
        maleWeightLb: 135,
        femaleWeightLb: 95,
        workSeconds: null,
        notes: "11 Thrusters, 135/95 lbs",
      },
    ],
    ...overrides,
  };
}

console.log("[TEST] importer draft stores raw text and parsed workout");
let draft = DraftState.createDraft({
  rawInput: "Roney\n4 rounds for time",
  workout: workout(),
  hasUnsavedChanges: true,
  now: "2026-07-30T12:01:00.000Z",
});
assert.equal(draft.schemaVersion, 1);
assert.equal(draft.rawInput, "Roney\n4 rounds for time");
assert.equal(draft.hasUnsavedChanges, true);
assert.equal(draft.workout.title, "Roney");
assert.equal(draft.workout.stations.length, 2);

console.log("[TEST] importer draft preserves station edits, additions, and order");
draft = DraftState.createDraft({
  rawInput: "edited",
  workout: workout({
    stations: [
      { name: "Wall Balls", reps: 30, weightLb: 20, maleWeightLb: 20, notes: "30 Wall Balls 20 lb" },
      { name: "Row", calories: "30/24", notes: "30/24 cal Row" },
      { name: "Bench Press", reps: 10, weightLb: 135, maleWeightLb: 135, notes: "10 Bench Press @135 lbs" },
    ],
  }),
  hasUnsavedChanges: true,
});
assert.deepEqual(draft.workout.stations.map((station) => station.name), ["Wall Balls", "Row", "Bench Press"]);
assert.equal(draft.workout.stations[0].maleWeightLb, 20);
assert.equal(draft.workout.stations[1].calories, "30/24");

console.log("[TEST] importer draft serializes and validates localStorage payload");
const parsed = DraftState.parseStoredDraft(DraftState.serializeDraft(draft));
assert.equal(parsed.ok, true);
assert.equal(parsed.draft.rawInput, "edited");
assert.equal(parsed.draft.workout.stations[2].name, "Bench Press");

console.log("[TEST] importer corrupt localStorage data does not validate");
assert.equal(DraftState.parseStoredDraft("{not json").ok, false);
assert.equal(DraftState.parseStoredDraft(JSON.stringify({ schemaVersion: 99 })).ok, false);

console.log("[TEST] importer startup restores unsaved local draft before differing server WOD");
const unsavedDraft = DraftState.createDraft({
  rawInput: "new local",
  workout: workout({ id: "local-new", title: "Local Draft", updatedAt: "2026-07-30T13:00:00.000Z" }),
  hasUnsavedChanges: true,
});
let restore = DraftState.chooseRestoreState({
  draft: unsavedDraft,
  serverWorkout: workout({ id: "server-old", title: "Server WOD", updatedAt: "2026-07-30T12:00:00.000Z" }),
});
assert.equal(restore.source, "local-unsaved");
assert.equal(restore.workout.title, "Local Draft");
assert.equal(restore.hasUnsavedChanges, true);

console.log("[TEST] importer startup loads server latest when no local draft exists");
restore = DraftState.chooseRestoreState({
  draft: null,
  serverWorkout: workout({ title: "Server Latest" }),
});
assert.equal(restore.source, "server");
assert.equal(restore.workout.title, "Server Latest");

console.log("[TEST] importer saved draft restores when server is unavailable");
const savedDraft = DraftState.createDraft({
  rawInput: "saved local",
  workout: workout({ title: "Saved Local" }),
  hasUnsavedChanges: false,
  lastServerUpdatedAt: "2026-07-30T12:00:00.000Z",
});
restore = DraftState.chooseRestoreState({
  draft: savedDraft,
  serverWorkout: null,
});
assert.equal(restore.source, "local-saved");
assert.equal(restore.hasUnsavedChanges, false);
assert.equal(
  DraftState.isServerNewerThanDraft(workout({ updatedAt: "2026-07-30T13:00:00.000Z" }), savedDraft),
  true,
);

console.log("[TEST] importer startup uses empty state when no draft or server WOD exists");
restore = DraftState.chooseRestoreState({
  draft: null,
  serverWorkout: null,
});
assert.equal(restore.source, "empty");
assert.deepEqual(restore.workout, {});

console.log("[TEST] importer load latest warns before replacing unsaved local changes");
assert.equal(DraftState.shouldConfirmBeforeLoadLatest(true), true);
assert.equal(DraftState.shouldConfirmBeforeLoadLatest(false), false);

console.log("[TEST] PASS: importer draft state");
