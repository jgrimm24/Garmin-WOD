const wodInput = document.querySelector("#wodInput");
const parseButton = document.querySelector("#parseButton");
const clearButton = document.querySelector("#clearButton");
const loadSampleButton = document.querySelector("#loadSampleButton");
const copyButton = document.querySelector("#copyButton");
const copyWatchButton = document.querySelector("#copyWatchButton");
const addStationButton = document.querySelector("#addStationButton");
const loadLatestButton = document.querySelector("#loadLatestButton");
const saveLatestButton = document.querySelector("#saveLatestButton");
const importPanel = document.querySelector(".import-panel");
const uploadDropzone = document.querySelector("#uploadDropzone");
const imageInput = document.querySelector("#imageInput");
const imagePreview = document.querySelector("#imagePreview");
const imageStatus = document.querySelector("#imageStatus");
const previewTitle = document.querySelector("#previewTitle");
const summaryGrid = document.querySelector("#summaryGrid");
const notesList = document.querySelector("#notesList");
const stationsList = document.querySelector("#stationsList");
const jsonOutput = document.querySelector("#jsonOutput");
const draftStatus = document.querySelector("#draftStatus");
const DraftState = window.GarminWodDraftState || null;

const sampleWod = `40 minute EMOM x10
1. Row 45 sec
2. 10 Pull-ups
3. 12 DB Bench @55
4. 15 AbMat Sit-ups`;

let currentWorkout = {};
let draggedStationIndex = null;
let draftSaveTimer = null;
let hasUnsavedChanges = false;
let lastServerWorkoutId = null;
let lastServerUpdatedAt = null;

if (window.location.protocol === "file:") {
  imageStatus.textContent = "Opening the local importer server...";
  window.location.href = "http://127.0.0.1:4175/importer/";
}

function setPersistenceStatus(message, tone) {
  draftStatus.textContent = message;
  draftStatus.className = `draft-status${tone ? ` ${tone}` : ""}`;
}

function markUnsaved(message) {
  if (!DraftState) return;
  hasUnsavedChanges = true;
  scheduleDraftSave(message || "Draft saved locally");
}

function scheduleDraftSave(message) {
  if (!DraftState) return;
  window.clearTimeout(draftSaveTimer);
  draftSaveTimer = window.setTimeout(() => {
    saveLocalDraft(message || (hasUnsavedChanges ? "Draft saved locally" : "Loaded saved draft"));
  }, 350);
}

function saveLocalDraft(message, tone) {
  if (!DraftState || !window.localStorage) return;

  try {
    const draft = DraftState.createDraft({
      rawInput: wodInput.value,
      workout: currentWorkout,
      hasUnsavedChanges,
      lastServerWorkoutId,
      lastServerUpdatedAt,
    });

    window.localStorage.setItem(DraftState.DRAFT_STORAGE_KEY, DraftState.serializeDraft(draft));
    setPersistenceStatus(message || (hasUnsavedChanges ? "Draft saved locally" : "Loaded saved draft"), tone || (hasUnsavedChanges ? "strong" : ""));
  } catch (error) {
    setPersistenceStatus("Could not save local draft", "warning");
  }
}

function clearLocalDraft() {
  window.clearTimeout(draftSaveTimer);
  if (!DraftState || !window.localStorage) return;

  try {
    window.localStorage.removeItem(DraftState.DRAFT_STORAGE_KEY);
  } catch (error) {
    setPersistenceStatus("Could not clear local draft", "warning");
  }
}

function loadLocalDraft() {
  if (!DraftState || !window.localStorage) return null;

  try {
    const parsed = DraftState.parseStoredDraft(window.localStorage.getItem(DraftState.DRAFT_STORAGE_KEY));

    if (!parsed.ok) {
      if (window.localStorage.getItem(DraftState.DRAFT_STORAGE_KEY)) {
        window.localStorage.removeItem(DraftState.DRAFT_STORAGE_KEY);
        setPersistenceStatus("Corrupt local draft removed", "warning");
      }

      return null;
    }

    return parsed.draft;
  } catch (error) {
    setPersistenceStatus("Could not read local draft", "warning");
    return null;
  }
}

async function fetchLatestWorkout() {
  if (!DraftState) {
    throw new Error("Draft persistence is not available.");
  }

  if (window.location.protocol === "file:") {
    throw new Error("Open the importer at http://127.0.0.1:4175/importer/ before loading the latest WOD.");
  }

  const response = await fetch("/api/latest-workout");
  const result = await response.json().catch(() => ({
    error: "The server returned an unreadable response.",
  }));

  if (!response.ok) {
    throw new Error(result.error || "No saved WOD found.");
  }

  return result.workout || result;
}

function applyRestoredWorkout(choice) {
  if (choice.source === "empty") {
    renderEmptyState();
    setPersistenceStatus(choice.message);
    return;
  }

  wodInput.value = choice.rawInput || choice.workout.sourceText || "";
  renderWorkout(choice.workout);

  hasUnsavedChanges = !!choice.hasUnsavedChanges;
  lastServerWorkoutId = choice.workout && !choice.hasUnsavedChanges ? DraftState.workoutIdentity(choice.workout) : null;
  lastServerUpdatedAt = choice.workout && !choice.hasUnsavedChanges ? choice.workout.updatedAt || null : null;

  saveLocalDraft(choice.message, choice.hasUnsavedChanges ? "strong" : "");
}

async function restoreInitialState() {
  if (!DraftState) return;

  const localDraft = loadLocalDraft();

  if (localDraft) {
    applyRestoredWorkout(DraftState.chooseRestoreState({
      draft: localDraft,
      serverWorkout: null,
    }));
  }

  let serverWorkout = null;

  try {
    serverWorkout = await fetchLatestWorkout();
  } catch (error) {
    if (localDraft) {
      setPersistenceStatus("Could not reach server - local draft preserved", localDraft.hasUnsavedChanges ? "strong" : "");
    } else {
      applyRestoredWorkout(DraftState.chooseRestoreState({
        draft: null,
        serverWorkout: null,
      }));
      setPersistenceStatus("No saved WOD found", "warning");
    }
    return;
  }

  if (localDraft && localDraft.hasUnsavedChanges) {
    setPersistenceStatus("Restored local draft", "strong");
    return;
  }

  if (
    localDraft &&
    DraftState.workoutIdentity(localDraft.workout) === DraftState.workoutIdentity(serverWorkout) &&
    !DraftState.isServerNewerThanDraft(serverWorkout, localDraft)
  ) {
    setPersistenceStatus("Loaded saved draft");
    return;
  }

  applyRestoredWorkout(DraftState.chooseRestoreState({
    draft: null,
    serverWorkout,
  }));
}

function renderEmptyState() {
  wodInput.value = "";
  imageInput.value = "";
  imagePreview.className = "image-preview empty-preview";
  imagePreview.textContent = "No image selected";
  imageStatus.textContent = "Choose an image to extract workout text, or paste text below.";
  previewTitle.textContent = "No workout parsed";
  summaryGrid.innerHTML = "";
  notesList.innerHTML = "";
  stationsList.className = "stations-list empty-state";
  stationsList.textContent = "Paste a WOD, then parse it.";
  jsonOutput.textContent = "{}";
  currentWorkout = {};
  hasUnsavedChanges = false;
  lastServerWorkoutId = null;
  lastServerUpdatedAt = null;
}

function parseWorkout(text) {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  const joined = lines.join(" ");
  const classification = classifyWorkout(lines);
  const type = classification.type;
  const durationMinutes = findWorkoutDuration(type, joined);
  const durationSeconds = durationMinutes == null ? null : durationMinutes * 60;
  const stationLines = findStationLines(lines, classification).concat(findRepSchemeInlineStationLines(lines));
  const stations = stationLines.map((line) => parseStation(line, type)).filter((station) => station.name);
  const notes = findWorkoutNotes(lines);

  return {
    schemaVersion: 1,
    id: makeWorkoutId(lines[0] || "today-wod", text),
    title: lines[0] || "Today's WOD",
    type,
    workoutType: classification.workoutType,
    structureType: classification.structureType,
    durationMinutes,
    durationSeconds,
    rounds: classification.rounds,
    repScheme: classification.repScheme,
    intervalSeconds: classification.intervalSeconds,
    parserWarnings: classification.warnings,
    stations,
    notes,
    sourceText: text.trim(),
  };
}

function classifyWorkout(lines) {
  const joined = lines.join(" ");
  const detectedType = detectType(joined);
  const repScheme = detectRepScheme(lines);
  const explicitRounds = findExplicitRounds(joined);
  const intervalSeconds = findIntervalSeconds(joined);
  const durationMinutes = findWorkoutDuration(detectedType, joined);
  const warnings = [];
  let workoutType = normalizeWorkoutTypeLabel(detectedType);
  let structureType = "UNKNOWN";
  let rounds = explicitRounds;

  if (repScheme.length) {
    structureType = isMonotonicRepScheme(repScheme) ? "REP_SCHEME" : "LADDER";
    if (rounds != null && rounds !== repScheme.length) {
      warnings.push(`Rep scheme has ${repScheme.length} rounds but workout says ${rounds} rounds.`);
    } else {
      rounds = repScheme.length;
    }
  }

  if (intervalSeconds != null) {
    workoutType = intervalSeconds === 60 ? "EMOM" : "INTERVAL";
    structureType = "TIMED_INTERVAL";
  } else if (/\b(?:chipper)\b/i.test(joined)) {
    workoutType = "CHIPPER";
    structureType = "CHIPPER";
  } else if (workoutType === "UNKNOWN" && looksLikeStrengthWorkout(joined)) {
    workoutType = "STRENGTH";
    structureType = "FIXED_STATIONS";
  } else if (structureType === "UNKNOWN" && workoutType !== "UNKNOWN") {
    structureType = "FIXED_STATIONS";
  }

  if (workoutType === "UNKNOWN" && repScheme.length) {
    workoutType = "FOR_TIME";
  }

  if (workoutType === "UNKNOWN" && rounds != null) {
    workoutType = "FOR_TIME";
    structureType = structureType === "UNKNOWN" ? "FIXED_STATIONS" : structureType;
  }

  if (intervalSeconds != null && rounds == null) {
    rounds = findIntervalRounds(joined);
  }

  return {
    type: displayWorkoutType(workoutType),
    workoutType,
    structureType,
    rounds,
    repScheme,
    intervalSeconds,
    warnings,
  };
}

function detectType(text) {
  if (/\b(?:e\d+mom|emom|every\s+\d+\s+minutes?|every\s+minute\s+on\s+the\s+minute)\b/i.test(text)) return "EMOM";
  if (/\bamrap\b/i.test(text)) return "AMRAP";
  if (/\bfor time\b/i.test(text)) return "For Time";
  if (/\btabata\b/i.test(text)) return "Tabata";
  return "Unknown";
}

function inferWorkoutType(type, rounds) {
  if (type !== "Unknown") return type;
  if (rounds != null) return "For Time";
  return type;
}

function findNumberBefore(text, pattern) {
  const match = text.match(new RegExp("(\\d+)\\s*" + pattern.source, pattern.flags));
  return match ? Number(match[1]) : null;
}

function findWorkoutDuration(type, text) {
  if (type === "For Time") {
    return null;
  }

  if (type === "AMRAP") {
    const match =
      text.match(/\b(\d+)\s*(?:-|–|—)?\s*(?:min|minute|minutes)?\s*(?:-|:)?\s*amrap\b/i) ||
      text.match(/\bamrap\s*(?:for|of|:|-)?\s*(\d+)\s*(?:min|minute|minutes)?\b/i);
    return match ? Number(match[1]) : null;
  }

  if (type === "EMOM") {
    const match =
      text.match(/\b(\d+)\s*(?:-|–|—)?\s*(?:min|minute|minutes)?\s*(?:-|:)?\s*emom\b/i) ||
      text.match(/\bemom\s*(?:for|of|:|-)?\s*(\d+)\s*(?:min|minute|minutes)?\b/i);
    return match ? Number(match[1]) : null;
  }

  const explicitMinutes = findNumberBefore(text, /(?:min|minute|minutes)\b/i);

  if (explicitMinutes) {
    return explicitMinutes;
  }

  return null;
}

function findRounds(text) {
  return findExplicitRounds(text);
}

function findExplicitRounds(text) {
  const cycleMatch = text.match(/x\s*(\d+)|(\d+)\s*(?:rounds|cycles)/i);
  if (cycleMatch) return Number(cycleMatch[1] || cycleMatch[2]);

  const duration = findNumberBefore(text, /(?:min|minute|minutes)\b/i);
  const stationCount = findStationLines(text.split(/\r?\n/)).length;
  if (/\bemom\b/i.test(text) && duration && stationCount) {
    return Math.floor(duration / stationCount);
  }

  return null;
}

function findStationLines(lines, classification = null) {
  return lines.filter((line) => {
    const normalizedLine = stripListPrefix(line);
    if (/\b(?:emom|amrap|for time|tabata)\b/i.test(normalizedLine)) return false;
    if (/^\d+\s*(?:rounds?|rds?)\b/i.test(normalizedLine)) return false;
    if (classification && parseRepSchemeFromLine(normalizedLine).length) return false;
    if (isGenderWeightLine(normalizedLine)) return false;
    return /(^\d+[\).:-]\s*)|(^\d+\s+\D)|(\d+\s*(?:reps?|cal|cals|m|meter|meters|sec|seconds|min|minute|minutes|lb|#|@))|row|run|bike|pull|push|squat|bench|sit|clean|snatch|deadlift|burpee|wall ball|toes|thruster|double\s+unders?|box\s+jumps?|rest/i.test(normalizedLine);
  });
}

function detectRepScheme(lines) {
  for (const line of lines) {
    const scheme = parseRepSchemeFromLine(line);

    if (scheme.length) {
      return scheme;
    }
  }

  return [];
}

function parseRepSchemeFromLine(line) {
  const cleaned = stripListPrefix(line)
    .trim();

  if (/\d+\s*x\s*\d+/i.test(cleaned) || /\d+\s*:\s*\d+/.test(cleaned)) {
    return [];
  }

  const match = cleaned.match(/^\s*(\d+(?:\s*(?:-|–|—|,|\/)\s*\d+){1,})(?:\s+(?:reps?|of|for\s+time)\b|$)/i);
  if (!match) return [];

  const normalized = match[1].replace(/[–—]/g, "-");
  const numbers = normalized.match(/\d+/g) || [];
  const values = numbers.map(Number);

  if (values.length < 2 || values.some((value) => value <= 0 || value > 100)) {
    return [];
  }

  return values;
}

function isRepSchemeLine(line) {
  const trimmed = line.trim();

  if (!trimmed) return false;
  if (/\d+\s*x\s*\d+/i.test(trimmed)) return false;
  if (/\d+\s*:\s*\d+/.test(trimmed)) return false;
  if (/\b(?:lb|lbs|#|m|meter|meters|cal|cals|sec|secs|second|seconds|min|minute|minutes)\b/i.test(trimmed)) return false;
  if (/^\d+\s+(?:rounds?|rds?|cycles?)\b/i.test(trimmed)) return false;
  if (/^\d{4}\b/.test(trimmed)) return false;

  const candidate = trimmed.replace(/\b(?:for\s+time|reps?|of)\b/gi, " ").trim();
  if (!/^\d+(?:\s*(?:-|–|—|,|\/)\s*\d+){1,}(?:\s*)$/.test(candidate)) return false;

  return true;
}

function findRepSchemeInlineStationLines(lines) {
  const stationLines = [];

  for (const line of lines) {
    const cleaned = stripListPrefix(line);
    const match = cleaned.match(/^\s*\d+(?:\s*(?:-|–|—|,|\/)\s*\d+){1,}\s+(?:reps?\s+)?(?:of\s+)?(.+)$/i);
    if (!match) continue;

    const movementText = match[1].replace(/\bfor\s+time\b/gi, "").trim();
    if (!movementText || isRepSchemeLine(movementText)) continue;

    movementText
      .split(/\s+(?:and|then)\s+|[,/]/i)
      .map((part) => part.trim())
      .filter(Boolean)
      .forEach((part) => stationLines.push(part));
  }

  return stationLines;
}

function isMonotonicRepScheme(values) {
  let ascending = true;
  let descending = true;

  for (let i = 1; i < values.length; i += 1) {
    if (values[i] <= values[i - 1]) ascending = false;
    if (values[i] >= values[i - 1]) descending = false;
  }

  return ascending || descending;
}

function findIntervalSeconds(text) {
  const eMomMatch = text.match(/\be\s*(\d+)\s*mom\b/i);
  if (eMomMatch) return Number(eMomMatch[1]) * 60;

  if (/\bevery\s+minute\s+on\s+the\s+minute\b/i.test(text) || /\bemom\b/i.test(text)) {
    return 60;
  }

  const everyMinutesMatch = text.match(/\bevery\s+(\d+)\s+(?:min|minute|minutes)\b/i);
  if (everyMinutesMatch) return Number(everyMinutesMatch[1]) * 60;

  return null;
}

function findIntervalRounds(text) {
  const match = text.match(/\bx\s*(\d+)\b/i) || text.match(/\bfor\s+(\d+)\s+rounds?\b/i);
  return match ? Number(match[1]) : null;
}

function looksLikeStrengthWorkout(text) {
  return /\b\d+\s*x\s*\d+\b/i.test(text) || /\b(?:strength|heavy|build\s+to|sets?)\b/i.test(text);
}

function normalizeWorkoutTypeLabel(type) {
  const normalized = String(type || "Unknown").trim().toUpperCase().replace(/[\s-]+/g, "_");
  const values = {
    FOR_TIME: true,
    AMRAP: true,
    EMOM: true,
    INTERVAL: true,
    STRENGTH: true,
    CHIPPER: true,
    UNKNOWN: true,
  };

  return values[normalized] ? normalized : "UNKNOWN";
}

function normalizeStructureType(type) {
  const normalized = String(type || "Unknown").trim().toUpperCase().replace(/[\s-]+/g, "_");
  const values = {
    FIXED_STATIONS: true,
    REP_SCHEME: true,
    TIMED_INTERVAL: true,
    LADDER: true,
    CHIPPER: true,
    UNKNOWN: true,
  };

  return values[normalized] ? normalized : "UNKNOWN";
}

function displayWorkoutType(workoutType) {
  const labels = {
    FOR_TIME: "For Time",
    AMRAP: "AMRAP",
    EMOM: "EMOM",
    INTERVAL: "Interval",
    STRENGTH: "Strength",
    CHIPPER: "Chipper",
    UNKNOWN: "Unknown",
  };

  return labels[workoutType] || "Unknown";
}

function normalizeRepScheme(value) {
  if (Array.isArray(value)) {
    return value.map(Number).filter((number) => Number.isInteger(number) && number > 0);
  }

  if (typeof value === "string") {
    return value
      .split(/[,\-/–—\s]+/)
      .map((part) => Number(part.trim()))
      .filter((number) => Number.isInteger(number) && number > 0);
  }

  return [];
}

function formatRepSchemeInput(repScheme) {
  return normalizeRepScheme(repScheme).join(", ");
}

function normalizeSummaryField(field, value) {
  if (field === "type") return value;
  if (field === "workoutType") return normalizeWorkoutTypeLabel(value);
  if (field === "structureType") return normalizeStructureType(value);
  if (field === "repScheme") return normalizeRepScheme(value);
  return numberOrNull(value);
}

function findWorkoutNotes(lines) {
  return lines.filter(isGenderWeightLine);
}

function isGenderWeightLine(line) {
  return /^[♀♂MFmf]\s*\d+\s*(?:lb|lbs|#)\b/.test(line.trim());
}

function stripListPrefix(line) {
  return line.replace(/^[•\-–—*]\s*/, "").trim();
}

function parseStation(line, workoutType) {
  const cleaned = stripListPrefix(line)
    .replace(/^\d+[\).:-]\s+(?=\D)/, "")
    .trim();
  const secondsMatch = cleaned.match(/(\d+)\s*(?:sec|secs|second|seconds)\b/i);
  const minutesMatch = cleaned.match(/(\d+)\s*(?:min|minute|minutes)\b/i);
  const weightInfo = parseWeightInfo(cleaned);
  const distanceMatch = cleaned.match(/(\d+)\s*(?:-| )?\s*(?:m|meter|meters)\b/i);
  const caloriesMatch = cleaned.match(/(\d+(?:\s*\/\s*\d+)?)\s*(?:cal|cals|calorie|calories)\b/i);
  const repsMatch = cleaned.match(/^(\d+)\s+(?!sec|secs|second|seconds|min|minute|minutes|m\b|meter|meters|cal|cals|calorie|calories)(.+)$/i);
  const timedSeconds = secondsMatch ? Number(secondsMatch[1]) : minutesMatch ? Number(minutesMatch[1]) * 60 : null;

  let name = cleaned;
  let reps = null;

  if (repsMatch) {
    reps = Number(repsMatch[1]);
    name = repsMatch[2].trim();
  }

  if (/\brest\b/i.test(cleaned)) {
    name = "Rest";
    reps = null;
  }

  name = name
    .replace(weightInfo.matchedText, " ")
    .replace(/\s*\d+(?:\s*\/\s*\d+)?\s*(?:cal|cals|calorie|calories)\b/i, "")
    .replace(/\s*\d+\s*(?:-| )?\s*(?:m|meter|meters)\b/i, "")
    .replace(/\s*@\s*\d+\s*(?:lb|lbs|#)?/i, "")
    .replace(/\s*\d+\s*(?:lb|lbs|#)\b/i, "")
    .replace(/\s*\d+\s*(?:sec|secs|second|seconds)\b/i, "")
    .replace(/\s*\d+\s*(?:min|minute|minutes)\b/i, "")
    .replace(/[,\s]+$/g, "")
    .trim();

  name = normalizeMovementName(name);

  return {
    name,
    reps,
    workSeconds: timedSeconds != null ? timedSeconds : getDefaultWorkSeconds(workoutType),
    distanceMeters: distanceMatch ? Number(distanceMatch[1]) : null,
    calories: caloriesMatch ? caloriesMatch[1].replace(/\s+/g, "") : null,
    weightLb: weightInfo.weightLb,
    maleWeightLb: weightInfo.maleWeightLb,
    femaleWeightLb: weightInfo.femaleWeightLb,
    notes: cleaned,
  };
}

function parseWeightInfo(text) {
  const pairedWeightMatch =
    text.match(/(?:^|[\s,])(?:@|with\s+)\s*(\d+)\s*\/\s*(\d+)\s*(?:lb|lbs|#)?(?=$|[\s,.)])/i) ||
    text.match(/(?:^|[\s,])(\d+)\s*\/\s*(\d+)\s*(?:lb|lbs|#)(?=$|[\s,.)])/i);

  if (pairedWeightMatch) {
    const maleWeightLb = Number(pairedWeightMatch[1]);
    const femaleWeightLb = Number(pairedWeightMatch[2]);

    return {
      weightLb: maleWeightLb,
      maleWeightLb,
      femaleWeightLb,
      matchedText: pairedWeightMatch[0],
    };
  }

  const singleWeightMatch = text.match(/(?:^|[\s,])(?:@|with\s+)?\s*(\d+)\s*(?:lb|lbs|#)(?=$|[\s,.)])/i);

  if (singleWeightMatch) {
    const weightLb = Number(singleWeightMatch[1]);

    return {
      weightLb,
      maleWeightLb: weightLb,
      femaleWeightLb: null,
      matchedText: singleWeightMatch[0],
    };
  }

  return {
    weightLb: null,
    maleWeightLb: null,
    femaleWeightLb: null,
    matchedText: "",
  };
}

function getDefaultWorkSeconds(workoutType) {
  return workoutType === "EMOM" ? 60 : null;
}

function normalizeMovementName(name) {
  if (/\bdeadlifts?\b/i.test(name)) return "Deadlifts";
  if (/\bski\s*erg\b/i.test(name)) return "SkiErg";
  if (/\brow\b/i.test(name)) return "Row";
  if (/\bbench(?:\s+press(?:es)?)?\b/i.test(name)) return "Bench Press";
  if (/\bfront\s+squat\b/i.test(name)) return "Front Squat";
  if (/\bbox\s+jumps?\b/i.test(name)) return "Box Jumps";
  if (/\btoes?\s+to\s+bar\b/i.test(name)) return "Toes to Bar";
  if (/\bthrusters?\b/i.test(name)) return "Thrusters";
  if (/\bdouble\s+unders?\b/i.test(name)) return "Double Unders";
  if (/\bbar\s+facing\s+burpees?\b/i.test(name)) return "Bar-Facing Burpees";
  if (/\bburpees?\s+over\s+barbells?\b/i.test(name)) return "Burpees Over Barbell";
  if (/\bburpees?\b/i.test(name)) return "Burpees";

  return name;
}

function renderWorkout(workout) {
  currentWorkout = normalizeWorkout(workout);
  previewTitle.textContent = currentWorkout.type === "Unknown" ? "Parsed Workout" : `${currentWorkout.type} Workout`;
  updateJsonOutput();

  summaryGrid.innerHTML = `
    <label class="summary-item">
      <span>Type</span>
      <select data-summary-field="type">
        ${["Unknown", "EMOM", "AMRAP", "For Time", "Interval", "Strength", "Chipper", "Tabata"].map((type) => `<option value="${type}" ${type === currentWorkout.type ? "selected" : ""}>${type}</option>`).join("")}
      </select>
    </label>
    <label class="summary-item">
      <span>Workout Type</span>
      <select data-summary-field="workoutType">
        ${["UNKNOWN", "FOR_TIME", "AMRAP", "EMOM", "INTERVAL", "STRENGTH", "CHIPPER"].map((type) => `<option value="${type}" ${type === currentWorkout.workoutType ? "selected" : ""}>${type.replace("_", " ")}</option>`).join("")}
      </select>
    </label>
    <label class="summary-item">
      <span>Structure</span>
      <select data-summary-field="structureType">
        ${["UNKNOWN", "FIXED_STATIONS", "REP_SCHEME", "TIMED_INTERVAL", "LADDER", "CHIPPER"].map((type) => `<option value="${type}" ${type === currentWorkout.structureType ? "selected" : ""}>${type.replace("_", " ")}</option>`).join("")}
      </select>
    </label>
    <label class="summary-item">
      <span>Duration</span>
      <input data-summary-field="durationMinutes" type="number" min="0" placeholder="${currentWorkout.type === "For Time" ? "None" : "Minutes"}" value="${numberValue(currentWorkout.durationMinutes)}" />
    </label>
    <label class="summary-item">
      <span>Interval Seconds</span>
      <input data-summary-field="intervalSeconds" type="number" min="0" placeholder="None" value="${numberValue(currentWorkout.intervalSeconds)}" />
    </label>
    <label class="summary-item">
      <span>Rounds</span>
      <input data-summary-field="rounds" type="number" min="0" placeholder="Unknown" value="${numberValue(currentWorkout.rounds)}" />
    </label>
    <label class="summary-item">
      <span>Rep Scheme</span>
      <input data-summary-field="repScheme" type="text" placeholder="21, 15, 9" value="${escapeAttr(formatRepSchemeInput(currentWorkout.repScheme))}" />
    </label>
    <div class="summary-item">
      <span>Stations</span>
      <strong>${currentWorkout.stations.length}</strong>
    </div>
  `;

  renderNotes();

  if (!currentWorkout.stations.length) {
    stationsList.className = "stations-list empty-state";
    stationsList.textContent = "No stations detected yet.";
    return;
  }

  stationsList.className = "stations-list";
  stationsList.innerHTML = currentWorkout.stations
    .map(
      (station, index) => `
        <article class="station-card" draggable="true" data-station-card-index="${index}">
          <div class="station-drag-handle" title="Drag to reorder">
            <span class="drag-grip">::</span>
            <span class="station-number">${index + 1}</span>
          </div>
          <div class="station-edit-grid">
            ${renderStationField(index, "name", "Name", "text", station.name)}
            ${renderStationField(index, "reps", "Reps", "number", station.reps)}
            ${renderStationField(index, "calories", "Calories", "text", station.calories)}
            ${renderStationField(index, "distanceMeters", "Meters", "number", station.distanceMeters)}
            ${renderStationField(index, "maleWeightLb", "Male lb", "number", station.maleWeightLb)}
            ${renderStationField(index, "femaleWeightLb", "Female lb", "number", station.femaleWeightLb)}
            ${renderStationField(index, "workSeconds", "Seconds", "number", station.workSeconds)}
            <button class="station-remove" type="button" data-remove-station="${index}">Remove</button>
          </div>
        </article>
      `,
    )
    .join("");
}

function renderStationField(index, field, label, type, value) {
  return `
    <div class="station-field">
      <label for="station-${index}-${field}">${label}</label>
      <input id="station-${index}-${field}" data-station-index="${index}" data-station-field="${field}" type="${type}" min="0" value="${escapeAttr(type === "number" ? numberValue(value) : value || "")}" />
    </div>
  `;
}

function formatStationMeta(station) {
  const pieces = [];
  if (station.reps) pieces.push(`${station.reps} reps`);
  if (station.calories) pieces.push(`${station.calories} cal`);
  if (station.distanceMeters) pieces.push(`${station.distanceMeters}m`);
  if (station.maleWeightLb && station.femaleWeightLb) {
    pieces.push(`${station.maleWeightLb}/${station.femaleWeightLb} lb`);
  } else if (station.weightLb) {
    pieces.push(`${station.weightLb} lb`);
  }
  return pieces.length ? pieces.join(" · ") : station.notes;
}

function formatStationPrimary(type, station) {
  if (station.workSeconds) return `${station.workSeconds}s`;
  if (type === "For Time" && station.calories) return `${station.calories} cal`;
  if (type === "For Time" && station.distanceMeters) return `${station.distanceMeters}m`;
  if (type === "For Time" && station.reps) return `${station.reps}`;
  return "";
}

function normalizeWorkout(workout) {
  const sourceText = workout.sourceText || "";
  const title = workout.title || "Today's WOD";
  const workoutType = normalizeWorkoutTypeLabel(workout.workoutType || workout.type || "Unknown");
  const structureType = normalizeStructureType(workout.structureType);
  const durationMinutes = numberOrNull(workout.durationMinutes);

  return {
    schemaVersion: 1,
    id: workout.id || makeWorkoutId(title, sourceText),
    title,
    type: workout.type || displayWorkoutType(workoutType),
    workoutType,
    structureType,
    durationMinutes,
    durationSeconds: numberOrNull(workout.durationSeconds) || (durationMinutes == null ? null : durationMinutes * 60),
    rounds: numberOrNull(workout.rounds),
    repScheme: normalizeRepScheme(workout.repScheme),
    intervalSeconds: numberOrNull(workout.intervalSeconds),
    parserWarnings: Array.isArray(workout.parserWarnings) ? workout.parserWarnings.map(String) : [],
    stations: Array.isArray(workout.stations) ? workout.stations.map(normalizeStation) : [],
    notes: Array.isArray(workout.notes) ? workout.notes : [],
    sourceText,
    createdAt: workout.createdAt || new Date().toISOString(),
    updatedAt: workout.updatedAt || new Date().toISOString(),
  };
}

function normalizeStation(station, index) {
  const maleWeightLb = numberOrNull(station.maleWeightLb === undefined ? station.weightLb : station.maleWeightLb);
  const femaleWeightLb = numberOrNull(station.femaleWeightLb);
  const weightLb = numberOrNull(station.weightLb === undefined || station.weightLb === null ? maleWeightLb : station.weightLb);

  return {
    id: station.id || `station-${index + 1}`,
    name: station.name || "",
    reps: station.reps || null,
    calories: station.calories || null,
    workSeconds: station.workSeconds || null,
    distanceMeters: station.distanceMeters || station.meters || null,
    weightLb,
    maleWeightLb,
    femaleWeightLb,
    notes: station.notes || "",
  };
}

function numberValue(value) {
  return value === null || value === undefined ? "" : value;
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function escapeAttr(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function updateJsonOutput() {
  previewTitle.textContent = currentWorkout.type === "Unknown" ? "Parsed Workout" : `${currentWorkout.type} Workout`;
  jsonOutput.textContent = JSON.stringify(toWorkoutContract(currentWorkout), null, 2);
}

function renderNotes() {
  const notes = currentWorkout.notes || [];
  const warnings = currentWorkout.parserWarnings || [];

  if (!notes.length && !warnings.length) {
    notesList.innerHTML = "";
    return;
  }

  notesList.innerHTML = `
    <div class="notes-card">
      <span>${warnings.length ? "Warnings" : "Notes"}</span>
      <strong>${[...warnings, ...notes].map(escapeHtml).join(" · ")}</strong>
    </div>
  `;
}

summaryGrid.addEventListener("input", (event) => {
  const field = event.target.dataset.summaryField;
  if (!field) return;

  currentWorkout[field] = normalizeSummaryField(field, event.target.value);
  if (field === "workoutType") {
    currentWorkout.type = displayWorkoutType(currentWorkout.workoutType);
  }
  updateJsonOutput();
  markUnsaved("Draft saved locally");
});

summaryGrid.addEventListener("change", (event) => {
  const field = event.target.dataset.summaryField;
  if (!field) return;

  currentWorkout[field] = normalizeSummaryField(field, event.target.value);
  if (field === "workoutType") {
    currentWorkout.type = displayWorkoutType(currentWorkout.workoutType);
  } else if (field === "type") {
    currentWorkout.workoutType = normalizeWorkoutTypeLabel(event.target.value);
  }
  renderWorkout(currentWorkout);
  markUnsaved("Draft saved locally");
});

stationsList.addEventListener("input", (event) => {
  const index = Number(event.target.dataset.stationIndex);
  const field = event.target.dataset.stationField;
  if (!field || !currentWorkout.stations[index]) return;

  currentWorkout.stations[index][field] = field === "name" || field === "calories" ? event.target.value : numberOrNull(event.target.value);

  if (field === "maleWeightLb") {
    currentWorkout.stations[index].weightLb = currentWorkout.stations[index].maleWeightLb;
  } else if (field === "weightLb") {
    currentWorkout.stations[index].maleWeightLb = currentWorkout.stations[index].weightLb;
  }

  updateJsonOutput();
  markUnsaved("Draft saved locally");
});

stationsList.addEventListener("click", (event) => {
  const index = event.target.dataset.removeStation;
  if (index === undefined) return;

  currentWorkout.stations.splice(Number(index), 1);
  renderWorkout(currentWorkout);
  markUnsaved("Draft saved locally");
});

stationsList.addEventListener("dragstart", (event) => {
  const card = event.target.closest("[data-station-card-index]");
  const isFieldDrag = event.target.closest("input, button, select, textarea");

  if (!card || isFieldDrag) {
    event.preventDefault();
    return;
  }

  draggedStationIndex = Number(card.dataset.stationCardIndex);
  card.classList.add("dragging");
  event.dataTransfer.effectAllowed = "move";
  event.dataTransfer.setData("text/plain", String(draggedStationIndex));
});

stationsList.addEventListener("dragend", (event) => {
  const card = event.target.closest("[data-station-card-index]");

  if (card) {
    card.classList.remove("dragging");
  }

  draggedStationIndex = null;
});

stationsList.addEventListener("dragover", (event) => {
  const card = event.target.closest("[data-station-card-index]");

  if (!card || draggedStationIndex == null) {
    return;
  }

  event.preventDefault();
  event.dataTransfer.dropEffect = "move";
  setStationDropTarget(card, event.clientY);
});

stationsList.addEventListener("dragleave", (event) => {
  const card = event.target.closest("[data-station-card-index]");

  if (card && !card.contains(event.relatedTarget)) {
    clearStationDropTargets();
  }
});

stationsList.addEventListener("drop", (event) => {
  const card = event.target.closest("[data-station-card-index]");

  if (!card || draggedStationIndex == null) {
    return;
  }

  event.preventDefault();
  const targetIndex = Number(card.dataset.stationCardIndex);
  const insertAfter = shouldDropAfter(card, event.clientY);
  clearStationDropTargets();
  moveStation(draggedStationIndex, targetIndex + (insertAfter ? 1 : 0));
  draggedStationIndex = null;
});

parseButton.addEventListener("click", () => {
  renderWorkout(parseWorkout(wodInput.value));
  markUnsaved("Unsaved changes");
});

clearButton.addEventListener("click", () => {
  renderEmptyState();
  clearLocalDraft();
  setPersistenceStatus("Local draft cleared; latest saved WOD is unchanged");
});

loadSampleButton.addEventListener("click", () => {
  wodInput.value = sampleWod;
  renderWorkout(parseWorkout(sampleWod));
  markUnsaved("Unsaved changes");
});

addStationButton.addEventListener("click", () => {
  currentWorkout = normalizeWorkout(currentWorkout);
  currentWorkout.stations.push({
    name: "New Station",
    reps: null,
    calories: null,
    workSeconds: getDefaultWorkSeconds(currentWorkout.type),
    distanceMeters: null,
    weightLb: null,
    maleWeightLb: null,
    femaleWeightLb: null,
    notes: "",
  });
  renderWorkout(currentWorkout);
  markUnsaved("Draft saved locally");
});

wodInput.addEventListener("input", () => {
  markUnsaved("Draft saved locally");
});

function moveStation(fromIndex, toIndex) {
  currentWorkout = normalizeWorkout(currentWorkout);

  if (fromIndex === toIndex || fromIndex < 0 || fromIndex >= currentWorkout.stations.length) {
    return;
  }

  var boundedToIndex = Math.max(0, Math.min(toIndex, currentWorkout.stations.length));
  const station = currentWorkout.stations.splice(fromIndex, 1)[0];

  if (boundedToIndex > fromIndex) {
    boundedToIndex--;
  }

  currentWorkout.stations.splice(boundedToIndex, 0, station);
  renderWorkout(currentWorkout);
  markUnsaved("Draft saved locally");
}

function setStationDropTarget(card, pointerY) {
  clearStationDropTargets();

  if (shouldDropAfter(card, pointerY)) {
    card.classList.add("drop-after");
  } else {
    card.classList.add("drop-before");
  }
}

function clearStationDropTargets() {
  stationsList.querySelectorAll(".drop-before, .drop-after").forEach((card) => {
    card.classList.remove("drop-before", "drop-after");
  });
}

function shouldDropAfter(card, pointerY) {
  const rect = card.getBoundingClientRect();
  return pointerY > rect.top + rect.height / 2;
}

imageInput.addEventListener("change", async () => {
  const file = imageInput.files && imageInput.files[0];
  if (!file) return;

  await handleImageFile(file);
});

bindImageDropTarget(importPanel);
bindImageDropTarget(uploadDropzone);
bindImageDropTarget(imagePreview);

window.addEventListener("dragover", (event) => {
  event.preventDefault();
});

window.addEventListener("drop", (event) => {
  if (!importPanel.contains(event.target)) {
    event.preventDefault();
  }
});

function bindImageDropTarget(target) {
  target.addEventListener("dragenter", (event) => {
    event.preventDefault();
    event.stopPropagation();
    setImageDropActive(true);
  });

  target.addEventListener("dragover", (event) => {
    event.preventDefault();
    event.stopPropagation();
    event.dataTransfer.dropEffect = "copy";
    setImageDropActive(true);
  });

  target.addEventListener("dragleave", (event) => {
    if (!target.contains(event.relatedTarget)) {
      setImageDropActive(false);
    }
  });

  target.addEventListener("drop", async (event) => {
    event.preventDefault();
    event.stopPropagation();
    setImageDropActive(false);

    const file = getDroppedImageFile(event);

    if (!file) {
      imageStatus.textContent = "Drop an image file here, or choose one with the file picker.";
      return;
    }

    imageInput.value = "";
    await handleImageFile(file);
  });
}

function setImageDropActive(isActive) {
  uploadDropzone.classList.toggle("drag-over", isActive);
  imagePreview.classList.toggle("drag-over", isActive);
}

async function handleImageFile(file) {
  if (!isImageFile(file)) {
    imageStatus.textContent = "Use an image file, like a screenshot, JPG, PNG, or HEIC.";
    return;
  }

  const imageUrl = URL.createObjectURL(file);
  imagePreview.className = "image-preview";
  imagePreview.innerHTML = `<img src="${imageUrl}" alt="Uploaded workout" />`;
  imageStatus.textContent = `${file.name} loaded. Extracting workout text...`;

  try {
    const text = await extractWorkoutText(file);

    if (!text) {
      imageStatus.textContent = "Extraction finished, but no workout text was found. Try a tighter crop or paste the text below.";
      return;
    }

    wodInput.value = text;
    imageStatus.textContent = "Workout text extracted. Review it, make any quick edits, then parse again if needed.";
    renderWorkout(parseWorkout(text));
    markUnsaved("Unsaved changes");
  } catch (error) {
    imageStatus.textContent = error.message || "Extraction failed. Paste the workout text below for now.";
  }
}

function getDroppedImageFile(event) {
  const items = Array.from(event.dataTransfer.items || []);

  for (const item of items) {
    if (item.kind !== "file") continue;

    const file = item.getAsFile();

    if (file && isImageFile(file)) {
      return file;
    }
  }

  const files = Array.from(event.dataTransfer.files || []);
  return files.find(isImageFile) || null;
}

function isImageFile(file) {
  if (!file) return false;
  if (file.type && file.type.startsWith("image/")) return true;

  return /\.(?:apng|avif|gif|heic|heif|jpe?g|png|webp)$/i.test(file.name || "");
}

copyButton.addEventListener("click", async () => {
  await navigator.clipboard.writeText(JSON.stringify(toWorkoutContract(currentWorkout), null, 2));
  copyButton.textContent = "Copied";
  setTimeout(() => {
    copyButton.textContent = "Copy JSON";
  }, 1200);
});

saveLatestButton.addEventListener("click", async () => {
  try {
    const savedWorkout = await saveLatestWorkout(currentWorkout);
    currentWorkout = normalizeWorkout(savedWorkout);
    renderWorkout(currentWorkout);
    hasUnsavedChanges = false;
    lastServerWorkoutId = DraftState.workoutIdentity(currentWorkout);
    lastServerUpdatedAt = currentWorkout.updatedAt || null;
    saveLocalDraft("Saved for watch");
    saveLatestButton.textContent = "Saved";
  } catch (error) {
    saveLatestButton.textContent = "Save Failed";
    imageStatus.textContent = error.message || "Could not save latest WOD.";
    setPersistenceStatus("Could not reach server - local draft preserved", "warning");
    saveLocalDraft("Draft saved locally", "strong");
  }

  setTimeout(() => {
    saveLatestButton.textContent = "Save Latest WOD";
  }, 1400);
});

loadLatestButton.addEventListener("click", async () => {
  if (
    DraftState.shouldConfirmBeforeLoadLatest(hasUnsavedChanges) &&
    !window.confirm("Replace your unsaved local draft with the latest saved WOD?")
  ) {
    return;
  }

  try {
    const latestWorkout = await fetchLatestWorkout();
    const choice = {
      source: "server",
      rawInput: latestWorkout.sourceText || "",
      workout: latestWorkout,
      hasUnsavedChanges: false,
      message: "Loaded latest saved WOD",
    };
    applyRestoredWorkout(choice);
  } catch (error) {
    setPersistenceStatus(error.message || "Could not reach server - local draft preserved", "warning");
  }
});

copyWatchButton.addEventListener("click", async () => {
  await navigator.clipboard.writeText(toMonkeyCWorkout(currentWorkout));
  copyWatchButton.textContent = "Copied";
  setTimeout(() => {
    copyWatchButton.textContent = "Copy Watch Data";
  }, 1200);
});

function toMonkeyCWorkout(workout) {
  const normalized = normalizeWorkout(workout);
  const stations = normalized.stations;

  return `class GarminWODWorkout {
    var title;
    var workoutType;
    var workoutTypeCode;
    var structureType;
    var durationMinutes;
    var durationSeconds;
    var rounds;
    var repScheme;
    var intervalSeconds;
    var stationNames;
    var stationReps;
    var stationSeconds;
    var stationCalories;
    var stationMeters;
    var stationWeights;

    function initialize() {
        title = ${toMonkeyCString(normalized.title)};
        workoutType = ${toMonkeyCString(normalized.type)};
        workoutTypeCode = ${toMonkeyCString(normalized.workoutType)};
        structureType = ${toMonkeyCString(normalized.structureType)};
        durationMinutes = ${toMonkeyCValue(normalized.durationMinutes)};
        durationSeconds = ${toMonkeyCValue(normalized.durationSeconds)};
        rounds = ${toMonkeyCValue(normalized.rounds)};
        repScheme = ${toMonkeyCArray(normalized.repScheme)};
        intervalSeconds = ${toMonkeyCValue(normalized.intervalSeconds)};
        stationNames = ${toMonkeyCArray(stations.map((station) => station.name))};
        stationReps = ${toMonkeyCArray(stations.map((station) => station.reps))};
        stationSeconds = ${toMonkeyCArray(stations.map((station) => station.workSeconds))};
        stationCalories = ${toMonkeyCArray(stations.map((station) => station.calories))};
        stationMeters = ${toMonkeyCArray(stations.map((station) => station.distanceMeters))};
        stationWeights = ${toMonkeyCArray(stations.map((station) => station.weightLb))};
    }

    function getStationCount() {
        return stationNames.size();
    }

    function getTotalSeconds() {
        if (durationSeconds != null) {
            return durationSeconds;
        }

        if (durationMinutes == null) {
            return null;
        }

        return durationMinutes * 60;
    }

    function isForTime() {
        return workoutTypeCode.equals("FOR_TIME") || workoutType.equals("For Time") || workoutType.equals("FOR TIME");
    }

    function isEmom() {
        return workoutTypeCode.equals("EMOM") || workoutType.equals("EMOM") || workoutType.equals("Emom");
    }

    function isAmrap() {
        return workoutTypeCode.equals("AMRAP") || workoutType.equals("AMRAP") || workoutType.equals("Amrap");
    }

    function isInterval() {
        return workoutTypeCode.equals("INTERVAL") || structureType.equals("TIMED_INTERVAL");
    }

    function isManualStationWorkout() {
        return !isEmom();
    }

    function getHeader(roundNumber) {
        if (isForTime()) {
            if (rounds == null) {
                return "FOR TIME";
            }

            return rounds + " RFT";
        }

        if (isAmrap()) {
            return durationMinutes == null ? "AMRAP" : "AMRAP " + durationMinutes;
        }

        if (isInterval()) {
            if (rounds == null) {
                return "INTERVAL";
            }

            return "R" + roundNumber + "/" + rounds;
        }

        if (rounds == null) {
            return workoutType + " " + durationMinutes;
        }

        return workoutType + " " + durationMinutes + "  R" + roundNumber + "/" + rounds;
    }

    function getStationText(index) {
        var name = stationNames[index];
        var reps = stationReps[index];
        var calories = stationCalories[index];
        var meters = stationMeters[index];
        var weight = stationWeights[index];

        if (meters != null) {
            name = meters + "m " + name;
        }

        if (calories != null) {
            name = calories + " cal " + name;
        }

        if (reps != null) {
            name = reps + " " + name;
        }

        if (weight != null) {
            name = name + " @" + weight;
        }

        return name;
    }

    function getScoreboardMovementText(index, roundNumber) {
        var prefix = getEssentialPrescription(index, roundNumber);
        var name = stationNames[index];

        if (prefix == null || startsWithNormalizedPrescription(name, prefix)) {
            return name;
        }

        return prefix + " " + name;
    }

    function getEssentialPrescription(index, roundNumber) {
        if (repScheme != null && repScheme.size() > 0 && roundNumber != null) {
            var schemeIndex = roundNumber - 1;

            if (schemeIndex >= 0 && schemeIndex < repScheme.size()) {
                return "" + repScheme[schemeIndex];
            }
        }

        if (stationReps[index] != null) {
            return "" + stationReps[index];
        }

        if (stationMeters[index] != null) {
            return "" + stationMeters[index] + "M";
        }

        if (stationCalories[index] != null) {
            return "" + stationCalories[index] + " CAL";
        }

        if (stationSeconds[index] != null) {
            return "" + stationSeconds[index] + " SEC";
        }

        return null;
    }

    function startsWithNormalizedPrescription(name, prefix) {
        var normalizedName = ("" + name).toUpper();
        var normalizedPrefix = ("" + prefix).toUpper();

        return normalizedName.find(normalizedPrefix) == 0;
    }

    function getWorkoutLayoutMode() {
        if (isInterval() || isEmom()) {
            return "INTERVAL";
        }

        if (workoutTypeCode.equals("STRENGTH")) {
            return "STRENGTH";
        }

        return "STANDARD";
    }

    function getStationWorkSeconds(index) {
        return stationSeconds[index];
    }
}`;
}

function toWorkoutContract(workout) {
  const normalized = normalizeWorkout(workout);
  const updatedAt = new Date().toISOString();

  return {
    schemaVersion: 1,
    id: normalized.id,
    title: normalized.title,
    type: normalized.type,
    workoutType: normalized.workoutType,
    structureType: normalized.structureType,
    durationMinutes: normalized.durationMinutes,
    durationSeconds: normalized.durationSeconds,
    rounds: normalized.rounds,
    repScheme: normalized.repScheme,
    intervalSeconds: normalized.intervalSeconds,
    parserWarnings: normalized.parserWarnings,
    notes: normalized.notes,
    sourceText: normalized.sourceText,
    createdAt: normalized.createdAt || updatedAt,
    updatedAt,
    stations: normalized.stations.map((station, index) => ({
      id: station.id || `station-${index + 1}`,
      name: station.name,
      reps: station.reps,
      calories: normalizeCalories(station.calories),
      meters: station.distanceMeters,
      weightLb: station.weightLb,
      maleWeightLb: station.maleWeightLb,
      femaleWeightLb: station.femaleWeightLb,
      workSeconds: station.workSeconds,
      notes: station.notes,
    })),
  };
}

async function saveLatestWorkout(workout) {
  if (window.location.protocol === "file:") {
    throw new Error("Open the importer at http://127.0.0.1:4175/importer/ before saving.");
  }

  const response = await fetch("/api/latest-workout", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(toWorkoutContract(workout)),
  });

  const result = await response.json().catch(() => ({
    error: "The server returned an unreadable response.",
  }));

  if (!response.ok) {
    throw new Error(result.error || "Could not save latest WOD.");
  }

  return result.workout || result;
}

function makeWorkoutId(title, sourceText) {
  const base = `${title || "wod"} ${sourceText || ""}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);

  return base || `wod-${Date.now()}`;
}

function normalizeCalories(value) {
  if (value === null || value === undefined || value === "") return null;
  const numeric = Number(value);
  return Number.isFinite(numeric) && !String(value).includes("/") ? numeric : String(value);
}

function toMonkeyCArray(values) {
  return `[
            ${values.map(toMonkeyCValue).join(",\n            ")}
        ]`;
}

function toMonkeyCValue(value) {
  if (value === null || value === undefined || value === "") return "null";
  if (typeof value === "number") return String(value);
  return toMonkeyCString(value);
}

function toMonkeyCString(value) {
  return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

async function extractWorkoutText(file) {
  if (window.location.protocol === "file:") {
    throw new Error("Open the importer at http://127.0.0.1:4175/importer/ so image extraction can reach the local server.");
  }

  const imageDataUrl = await readFileAsCompressedImage(file);
  const response = await fetch("/api/extract", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      imageDataUrl,
      fileName: file.name,
    }),
  });

  const result = await response.json().catch(() => ({
    error: "The extractor server returned an unreadable response.",
  }));

  if (!response.ok) {
    throw new Error(result.error || "Extraction failed.");
  }

  return result.text || "";
}

function readFileAsCompressedImage(file) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    const objectUrl = URL.createObjectURL(file);

    image.addEventListener("load", () => {
      URL.revokeObjectURL(objectUrl);

      try {
        const maxSide = 1600;
        const scale = Math.min(1, maxSide / Math.max(image.naturalWidth, image.naturalHeight));
        const width = Math.max(1, Math.round(image.naturalWidth * scale));
        const height = Math.max(1, Math.round(image.naturalHeight * scale));
        const canvas = document.createElement("canvas");
        const context = canvas.getContext("2d");

        canvas.width = width;
        canvas.height = height;
        context.drawImage(image, 0, 0, width, height);
        resolve(canvas.toDataURL("image/jpeg", 0.86));
      } catch (error) {
        readFileAsDataUrl(file).then(resolve, reject);
      }
    });

    image.addEventListener("error", () => {
      URL.revokeObjectURL(objectUrl);
      readFileAsDataUrl(file).then(resolve, reject);
    });

    image.src = objectUrl;
  });
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener("load", () => resolve(reader.result));
    reader.addEventListener("error", () => reject(new Error("Could not read the selected image.")));
    reader.readAsDataURL(file);
  });
}

restoreInitialState();
