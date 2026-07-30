(function (root, factory) {
  const api = factory();

  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }

  if (root) {
    root.GarminWodDraftState = api;
  }
})(typeof window !== "undefined" ? window : globalThis, function () {
  const DRAFT_SCHEMA_VERSION = 1;
  const DRAFT_STORAGE_KEY = "garminWod.importerDraft.v1";

  function createDraft(options) {
    const now = options && options.now ? options.now : new Date().toISOString();
    const workout = normalizeWorkout(options && options.workout);

    return {
      schemaVersion: DRAFT_SCHEMA_VERSION,
      savedAt: now,
      hasUnsavedChanges: !!(options && options.hasUnsavedChanges),
      rawInput: String((options && options.rawInput) || ""),
      workout,
      lastServerWorkoutId: stringOrNull(options && options.lastServerWorkoutId),
      lastServerUpdatedAt: stringOrNull(options && options.lastServerUpdatedAt),
    };
  }

  function serializeDraft(draft) {
    return JSON.stringify(validateDraft(draft).draft);
  }

  function parseStoredDraft(text) {
    if (!text) {
      return { ok: false, draft: null, error: "No local draft found." };
    }

    try {
      return validateDraft(JSON.parse(text));
    } catch (error) {
      return { ok: false, draft: null, error: "Local draft is not valid JSON." };
    }
  }

  function validateDraft(value) {
    if (!value || typeof value !== "object") {
      return { ok: false, draft: null, error: "Local draft is empty." };
    }

    if (Number(value.schemaVersion) !== DRAFT_SCHEMA_VERSION) {
      return { ok: false, draft: null, error: "Local draft version is not supported." };
    }

    const workout = normalizeWorkout(value.workout);
    const rawInput = String(value.rawInput || workout.sourceText || "");

    if (!hasUsefulDraft(rawInput, workout)) {
      return { ok: false, draft: null, error: "Local draft has no workout content." };
    }

    return {
      ok: true,
      draft: {
        schemaVersion: DRAFT_SCHEMA_VERSION,
        savedAt: String(value.savedAt || new Date().toISOString()),
        hasUnsavedChanges: !!value.hasUnsavedChanges,
        rawInput,
        workout,
        lastServerWorkoutId: stringOrNull(value.lastServerWorkoutId),
        lastServerUpdatedAt: stringOrNull(value.lastServerUpdatedAt),
      },
      error: null,
    };
  }

  function chooseRestoreState(options) {
    const draft = options && options.draft && options.draft.schemaVersion
      ? validateDraft(options.draft).draft
      : null;
    const serverWorkout = normalizeWorkout(options && options.serverWorkout);
    const hasServerWorkout = hasUsefulWorkout(serverWorkout);

    if (draft && draft.hasUnsavedChanges) {
      return {
        source: "local-unsaved",
        rawInput: draft.rawInput,
        workout: draft.workout,
        hasUnsavedChanges: true,
        message: "Restored local draft",
      };
    }

    if (draft && hasUsefulDraft(draft.rawInput, draft.workout)) {
      return {
        source: "local-saved",
        rawInput: draft.rawInput,
        workout: draft.workout,
        hasUnsavedChanges: false,
        message: hasServerWorkout && isServerNewerThanDraft(serverWorkout, draft)
          ? "Restored saved draft; latest server WOD is newer"
          : "Loaded saved draft",
      };
    }

    if (hasServerWorkout) {
      return {
        source: "server",
        rawInput: serverWorkout.sourceText || "",
        workout: serverWorkout,
        hasUnsavedChanges: false,
        message: "Loaded latest saved WOD",
      };
    }

    return {
      source: "empty",
      rawInput: "",
      workout: {},
      hasUnsavedChanges: false,
      message: "No saved WOD found",
    };
  }

  function shouldConfirmBeforeLoadLatest(hasUnsavedChanges) {
    return !!hasUnsavedChanges;
  }

  function hasUsefulDraft(rawInput, workout) {
    return !!String(rawInput || "").trim() || hasUsefulWorkout(workout);
  }

  function hasUsefulWorkout(workout) {
    return !!(
      workout &&
      typeof workout === "object" &&
      (
        String(workout.title || "").trim() ||
        String(workout.sourceText || "").trim() ||
        (Array.isArray(workout.stations) && workout.stations.length)
      )
    );
  }

  function workoutIdentity(workout) {
    const normalized = normalizeWorkout(workout);
    if (!hasUsefulWorkout(normalized)) return "";

    const stableId = normalized.id || normalized.updatedAt || normalized.generatedAt || normalized.createdAt;
    if (stableId) return String(stableId);

    return [
      normalized.title,
      normalized.type,
      normalized.rounds,
      normalized.durationMinutes,
      normalized.stations.map((station) => [
        station.name,
        station.reps,
        station.calories,
        station.distanceMeters,
        station.weightLb,
        station.maleWeightLb,
        station.femaleWeightLb,
        station.workSeconds,
      ].join(":")).join("|"),
    ].join("::");
  }

  function isServerNewerThanDraft(serverWorkout, draft) {
    const serverUpdatedAt = Date.parse(serverWorkout && serverWorkout.updatedAt);
    const draftServerUpdatedAt = Date.parse(draft && draft.lastServerUpdatedAt);

    return Number.isFinite(serverUpdatedAt) &&
      Number.isFinite(draftServerUpdatedAt) &&
      serverUpdatedAt > draftServerUpdatedAt;
  }

  function normalizeWorkout(workout) {
    if (!workout || typeof workout !== "object") {
      return {};
    }

    return {
      schemaVersion: Number(workout.schemaVersion) || 1,
      id: stringOrNull(workout.id),
      title: String(workout.title || ""),
      type: String(workout.type || "Unknown"),
      durationMinutes: numberOrNull(workout.durationMinutes),
      rounds: numberOrNull(workout.rounds),
      notes: Array.isArray(workout.notes) ? workout.notes.map(String) : [],
      sourceText: String(workout.sourceText || ""),
      createdAt: stringOrNull(workout.createdAt),
      updatedAt: stringOrNull(workout.updatedAt),
      generatedAt: stringOrNull(workout.generatedAt),
      timestamp: stringOrNull(workout.timestamp),
      stations: Array.isArray(workout.stations) ? workout.stations.map(normalizeStation) : [],
    };
  }

  function normalizeStation(station, index) {
    const value = station && typeof station === "object" ? station : {};
    const distanceMeters = value.distanceMeters === undefined ? value.meters : value.distanceMeters;

    return {
      id: stringOrNull(value.id) || `station-${index + 1}`,
      name: String(value.name || ""),
      reps: numberOrNull(value.reps),
      calories: value.calories === null || value.calories === undefined || value.calories === ""
        ? null
        : Number.isFinite(Number(value.calories)) && !String(value.calories).includes("/")
          ? Number(value.calories)
          : String(value.calories),
      distanceMeters: numberOrNull(distanceMeters),
      meters: numberOrNull(distanceMeters),
      weightLb: numberOrNull(value.weightLb),
      maleWeightLb: numberOrNull(value.maleWeightLb === undefined ? value.weightLb : value.maleWeightLb),
      femaleWeightLb: numberOrNull(value.femaleWeightLb),
      workSeconds: numberOrNull(value.workSeconds),
      notes: String(value.notes || ""),
    };
  }

  function numberOrNull(value) {
    if (value === null || value === undefined || value === "") return null;
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
  }

  function stringOrNull(value) {
    if (value === null || value === undefined || value === "") return null;
    return String(value);
  }

  return {
    DRAFT_SCHEMA_VERSION,
    DRAFT_STORAGE_KEY,
    createDraft,
    serializeDraft,
    parseStoredDraft,
    validateDraft,
    chooseRestoreState,
    shouldConfirmBeforeLoadLatest,
    workoutIdentity,
    isServerNewerThanDraft,
    normalizeWorkout,
  };
});
