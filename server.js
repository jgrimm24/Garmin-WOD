const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = __dirname;
const PORT = Number(process.env.PORT || 4175);
const HOST = process.env.HOST || "0.0.0.0";
const DATA_DIR = path.join(ROOT, "data");
const LATEST_WORKOUT_PATH = path.join(DATA_DIR, "latest-workout.json");
const WORKOUT_SESSION_PATH = path.join(DATA_DIR, "workout-session.json");
const COMPLETED_WORKOUTS_DIR = path.join(DATA_DIR, "completed-workouts");
const COMPLETED_WORKOUTS_INDEX_PATH = path.join(COMPLETED_WORKOUTS_DIR, "index.json");

loadEnvFile(path.join(ROOT, ".env"));

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
};

const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url, `http://${request.headers.host}`);

    if (request.method === "POST" && url.pathname === "/api/extract") {
      await handleExtract(request, response);
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/health") {
      handleHealth(response);
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/latest-workout") {
      await handleGetLatestWorkout(response);
      return;
    }

    if (request.method === "POST" && url.pathname === "/api/latest-workout") {
      await handleSaveLatestWorkout(request, response);
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/workout-session") {
      await handleGetWorkoutSession(response);
      return;
    }

    if (request.method === "PUT" && url.pathname === "/api/workout-session") {
      await handleSaveWorkoutSession(request, response);
      return;
    }

    if (request.method === "POST" && url.pathname === "/api/completed-workouts") {
      await handleSaveCompletedWorkout(request, response);
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/completed-workouts") {
      await handleListCompletedWorkouts(url, response);
      return;
    }

    const completedWorkoutMatch = url.pathname.match(/^\/api\/completed-workouts\/([^/]+)$/);
    if (request.method === "GET" && completedWorkoutMatch) {
      await handleGetCompletedWorkout(completedWorkoutMatch[1], response);
      return;
    }

    if (request.method !== "GET") {
      sendJson(response, 405, { error: "Method not allowed" });
      return;
    }

    serveStatic(url.pathname, response);
  } catch (error) {
    sendJson(response, 500, { error: error.message || "Unexpected server error" });
  }
});

if (require.main === module) {
  server.listen(PORT, HOST, () => {
    const displayHost = HOST === "0.0.0.0" ? "127.0.0.1" : HOST;
    console.log(`Garmin WOD importer running at http://${displayHost}:${PORT}/importer/`);
    console.log(`OpenAI key configured: ${hasOpenAiKey() ? "yes" : "no"}`);
  });
}

async function handleExtract(request, response) {
  const apiKey = process.env.OPENAI_API_KEY;

  if (!apiKey) {
    sendJson(response, 400, {
      error: "Missing OPENAI_API_KEY. Add it to Render Environment, then redeploy/restart the importer server.",
    });
    return;
  }

  const body = await readJsonBody(request);
  const imageDataUrl = body.imageDataUrl;

  if (!imageDataUrl || !/^data:image\/[a-zA-Z0-9.+-]+;base64,/.test(imageDataUrl)) {
    sendJson(response, 400, { error: "Upload an image before extracting." });
    return;
  }

  const result = await extractWithFallbacks(apiKey, imageDataUrl);

  if (!result.ok) {
    sendJson(response, result.statusCode, { error: result.error });
    return;
  }

  sendJson(response, 200, { text: result.text.trim() });
}

function handleHealth(response) {
  sendJson(response, 200, {
    ok: true,
    openAiKeyConfigured: hasOpenAiKey(),
  });
}

function hasOpenAiKey() {
  return !!process.env.OPENAI_API_KEY;
}

async function handleGetLatestWorkout(response) {
  try {
    const data = await fs.promises.readFile(LATEST_WORKOUT_PATH, "utf8");
    sendJson(response, 200, JSON.parse(data));
  } catch (error) {
    sendJson(response, 404, { error: "No latest workout has been saved yet." });
  }
}

async function handleSaveLatestWorkout(request, response) {
  const body = await readJsonBody(request);
  const workout = normalizeWorkoutContract(body);

  await fs.promises.mkdir(DATA_DIR, { recursive: true });
  await fs.promises.writeFile(LATEST_WORKOUT_PATH, JSON.stringify(workout, null, 2) + "\n", "utf8");

  sendJson(response, 200, { workout });
}

async function handleGetWorkoutSession(response) {
  try {
    const data = await fs.promises.readFile(WORKOUT_SESSION_PATH, "utf8");
    sendJson(response, 200, JSON.parse(data));
  } catch (error) {
    sendJson(response, 404, { error: "No workout session has been published yet." });
  }
}

async function handleSaveWorkoutSession(request, response) {
  const body = await readJsonBody(request);
  const result = normalizeWorkoutSessionState(body, Date.now());

  if (!result.ok) {
    sendJson(response, 400, { error: result.error });
    return;
  }

  const existing = await readWorkoutSessionFromDisk();
  const decision = acceptWorkoutSessionState(existing, result.state);

  if (!decision.ok) {
    sendJson(response, 409, { error: decision.error, session: existing });
    return;
  }

  if (decision.write) {
    await fs.promises.mkdir(DATA_DIR, { recursive: true });
    await fs.promises.writeFile(WORKOUT_SESSION_PATH, JSON.stringify(decision.session, null, 2) + "\n", "utf8");
    if (decision.session.status === "finished" && decision.session.analytics) {
      await storeCompletedWorkoutFromPayload(decision.session.analytics);
    }
  }

  sendJson(response, 200, { session: decision.session });
}

async function handleSaveCompletedWorkout(request, response) {
  const body = await readJsonBody(request);
  const result = normalizeCompletedWorkout(body, Date.now());

  if (!result.ok) {
    sendJson(response, 400, { error: result.error });
    return;
  }

  const stored = await storeCompletedWorkout(result.session);
  sendJson(response, 200, {
    accepted: true,
    sessionId: stored.sessionId,
    stored: true,
    duplicate: stored.duplicate,
    summary: stored.summary,
  });
}

async function handleListCompletedWorkouts(url, response) {
  await migrateLatestFinishedSessionToArchive();

  const limit = Math.max(1, Math.min(integerOrNull(url.searchParams.get("limit")) || 50, 100));
  const before = integerOrNull(url.searchParams.get("before"));
  const index = await readCompletedWorkoutIndex();
  const ordered = [...index.items].sort(compareCompletedWorkoutSummaries);
  const filtered = before === null
    ? ordered
    : ordered.filter((item) => (integerOrNull(item.finishedAt) || 0) < before);
  const items = filtered.slice(0, limit);
  const nextCursor = filtered.length > limit && items.length > 0
    ? String(items[items.length - 1].finishedAt || 0)
    : null;

  sendJson(response, 200, { items, nextCursor });
}

async function handleGetCompletedWorkout(sessionId, response) {
  const safeSessionId = decodeURIComponent(sessionId);
  if (!isSafeSessionId(safeSessionId)) {
    sendJson(response, 400, { error: "Invalid sessionId." });
    return;
  }

  const session = await readCompletedWorkout(safeSessionId);
  if (!session) {
    sendJson(response, 404, { error: "Completed workout not found." });
    return;
  }

  sendJson(response, 200, { session });
}

async function extractWithFallbacks(apiKey, imageDataUrl) {
  const models = uniqueValues([
    process.env.OPENAI_EXTRACT_MODEL || "gpt-4.1-mini",
    "gpt-4o-mini",
    "gpt-4.1-mini",
  ]);
  var lastError = "OpenAI extraction failed.";
  var lastStatusCode = 500;

  for (const model of models) {
    for (var attempt = 0; attempt < 2; attempt++) {
      const result = await callOpenAiExtractor(apiKey, model, imageDataUrl);

      if (result.ok) {
        return result;
      }

      lastError = result.error;
      lastStatusCode = result.statusCode;

      if (result.statusCode < 500 && !isRetryableOpenAiError(result.error)) {
        return result;
      }

      await sleep(350 + attempt * 650);
    }
  }

  return {
    ok: false,
    statusCode: lastStatusCode,
    error: `${lastError} Try the image once more, or crop closer to just the workout text.`,
  };
}

async function callOpenAiExtractor(apiKey, model, imageDataUrl) {
  const openAiResponse = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: [
                "Extract only the workout text from this CrossFit WOD image.",
                "Preserve line breaks and numbers.",
                "Ignore social media chrome, comments, profile names, buttons, timestamps, ads, and photo captions.",
                "Return plain text only. Do not explain.",
              ].join(" "),
            },
            {
              type: "input_image",
              image_url: imageDataUrl,
            },
          ],
        },
      ],
    }),
  });

  const result = await openAiResponse.json();

  if (!openAiResponse.ok) {
    return {
      ok: false,
      statusCode: openAiResponse.status,
      error: result.error && result.error.message ? result.error.message : "OpenAI extraction failed.",
    };
  }

  return {
    ok: true,
    statusCode: 200,
    text: getResponseText(result),
  };
}

function serveStatic(urlPath, response) {
  const normalizedPath = urlPath === "/" ? "/importer/" : urlPath;
  const relativePath = normalizedPath.endsWith("/")
    ? `${normalizedPath.slice(1)}index.html`
    : normalizedPath.slice(1);
  const filePath = path.resolve(ROOT, relativePath);

  if (!filePath.startsWith(ROOT + path.sep)) {
    sendJson(response, 403, { error: "Forbidden" });
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      sendJson(response, 404, { error: "Not found" });
      return;
    }

    response.writeHead(200, {
      "Content-Type": MIME_TYPES[path.extname(filePath).toLowerCase()] || "application/octet-stream",
      "Cache-Control": "no-store",
    });
    response.end(data);
  });
}

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    var tooLarge = false;

    request.on("data", (chunk) => {
      if (tooLarge) {
        return;
      }

      body += chunk;

      if (body.length > 15 * 1024 * 1024) {
        tooLarge = true;
        body = "";
      }
    });

    request.on("end", () => {
      if (tooLarge) {
        reject(new Error("Image is too large. Try a tighter crop or smaller screenshot."));
        return;
      }

      try {
        resolve(JSON.parse(body || "{}"));
      } catch (error) {
        reject(new Error("Invalid JSON request."));
      }
    });

    request.on("error", reject);
  });
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

function normalizeWorkoutContract(workout) {
  const now = new Date().toISOString();
  const title = String(workout.title || "Today's WOD");
  const sourceText = String(workout.sourceText || "");
  const repScheme = normalizeRepScheme(workout.repScheme);
  const normalizedStructure = normalizeRepSchemeStructure({
    structureType: normalizeStructureType(workout.structureType),
    rounds: numberOrNull(workout.rounds),
    repScheme,
    parserWarnings: Array.isArray(workout.parserWarnings) ? workout.parserWarnings.map(String) : [],
  });

  return {
    schemaVersion: 1,
    id: String(workout.id || makeWorkoutId(title, sourceText)),
    title,
    type: normalizeWorkoutType(workout.type),
    workoutType: normalizeWorkoutTypeCode(workout.workoutType || workout.type),
    structureType: normalizedStructure.structureType,
    durationMinutes: numberOrNull(workout.durationMinutes),
    durationSeconds: numberOrNull(workout.durationSeconds),
    rounds: normalizedStructure.rounds,
    repScheme,
    intervalSeconds: numberOrNull(workout.intervalSeconds),
    parserWarnings: normalizedStructure.parserWarnings,
    notes: Array.isArray(workout.notes) ? workout.notes.map(String) : [],
    sourceText,
    createdAt: String(workout.createdAt || now),
    updatedAt: now,
    stations: Array.isArray(workout.stations) ? workout.stations.map(normalizeStationContract) : [],
  };
}

function normalizeRepSchemeStructure({ structureType, rounds, repScheme, parserWarnings }) {
  const warnings = Array.isArray(parserWarnings) ? parserWarnings.slice() : [];
  const hasRepScheme = Array.isArray(repScheme) && repScheme.length >= 2;
  let normalizedStructureType = structureType;
  let normalizedRounds = rounds;

  if (!hasRepScheme) {
    return {
      structureType: normalizedStructureType,
      rounds: normalizedRounds,
      parserWarnings: warnings,
    };
  }

  if (normalizedStructureType === "UNKNOWN" || normalizedStructureType === "FIXED_STATIONS") {
    normalizedStructureType = "REP_SCHEME";
  }

  if (normalizedRounds == null) {
    normalizedRounds = repScheme.length;
  } else if (normalizedRounds !== repScheme.length) {
    const warning = `Rep scheme has ${repScheme.length} rounds but workout says ${normalizedRounds} rounds.`;
    if (!warnings.includes(warning)) {
      warnings.push(warning);
    }
  }

  return {
    structureType: normalizedStructureType,
    rounds: normalizedRounds,
    parserWarnings: warnings,
  };
}

function normalizeStationContract(station, index) {
  return {
    id: String(station.id || `station-${index + 1}`),
    name: String(station.name || ""),
    reps: numberOrNull(station.reps),
    calories: caloriesOrNull(station.calories),
    meters: numberOrNull(station.meters || station.distanceMeters),
    weightLb: numberOrNull(station.weightLb),
    maleWeightLb: numberOrNull(station.maleWeightLb === undefined ? station.weightLb : station.maleWeightLb),
    femaleWeightLb: numberOrNull(station.femaleWeightLb),
    weightUnit: stringOrNull(station.weightUnit),
    maleWeightKg: numberOrNull(station.maleWeightKg),
    femaleWeightKg: numberOrNull(station.femaleWeightKg),
    heightUnit: stringOrNull(station.heightUnit),
    maleHeightIn: numberOrNull(station.maleHeightIn),
    femaleHeightIn: numberOrNull(station.femaleHeightIn),
    workSeconds: numberOrNull(station.workSeconds),
    notes: String(station.notes || ""),
  };
}

function normalizeWorkoutType(type) {
  const allowedTypes = {
    Unknown: true,
    EMOM: true,
    AMRAP: true,
    "For Time": true,
    Tabata: true,
    Interval: true,
    Strength: true,
    Chipper: true,
  };

  return allowedTypes[type] ? type : "Unknown";
}

function normalizeWorkoutTypeCode(type) {
  const normalized = String(type || "Unknown").trim().toUpperCase().replace(/[\s-]+/g, "_");
  const allowedTypes = {
    UNKNOWN: true,
    EMOM: true,
    AMRAP: true,
    FOR_TIME: true,
    INTERVAL: true,
    STRENGTH: true,
    CHIPPER: true,
  };

  return allowedTypes[normalized] ? normalized : "UNKNOWN";
}

function normalizeStructureType(type) {
  const normalized = String(type || "Unknown").trim().toUpperCase().replace(/[\s-]+/g, "_");
  const allowedTypes = {
    UNKNOWN: true,
    FIXED_STATIONS: true,
    REP_SCHEME: true,
    TIMED_INTERVAL: true,
    LADDER: true,
    CHIPPER: true,
  };

  return allowedTypes[normalized] ? normalized : "UNKNOWN";
}

function normalizeRepScheme(value) {
  if (!Array.isArray(value)) return [];

  return value
    .map(Number)
    .filter((number) => Number.isInteger(number) && number > 0);
}

function normalizeWorkoutSessionState(input, nowMs = Date.now()) {
  const statusValues = {
    idle: true,
    running: true,
    paused: true,
    finished: true,
  };

  const workoutId = stringOrEmpty(input.workoutId);
  const sessionId = stringOrEmpty(input.sessionId);
  const status = stringOrEmpty(input.status);
  const revision = integerOrNull(input.revision);
  const round = integerOrNull(input.round);
  const stationIndex = integerOrNull(input.stationIndex);
  const elapsedSeconds = integerOrNull(input.elapsedSeconds);

  if (!workoutId) return { ok: false, error: "workoutId is required." };
  if (!sessionId) return { ok: false, error: "sessionId is required." };
  if (revision === null || revision < 1) return { ok: false, error: "revision must be a positive integer." };
  if (!statusValues[status]) return { ok: false, error: "status is invalid." };
  if (round === null || round < 1) return { ok: false, error: "round must be a positive integer." };
  if (stationIndex === null || stationIndex < 0) return { ok: false, error: "stationIndex must be a non-negative integer." };
  if (elapsedSeconds === null || elapsedSeconds < 0) return { ok: false, error: "elapsedSeconds must be a non-negative integer." };

  return {
    ok: true,
    state: {
      workoutId,
      sessionId,
      revision,
      status,
      round,
      stationIndex,
      elapsedSeconds,
      updatedAt: nowMs,
      analytics: normalizeWorkoutAnalytics(input.analytics),
    },
  };
}

function normalizeWorkoutAnalytics(input) {
  if (!input || typeof input !== "object") {
    return null;
  }

  return {
    schemaVersion: integerOrNull(input.schemaVersion) || 1,
    sessionId: stringOrEmpty(input.sessionId),
    workoutId: stringOrEmpty(input.workoutId),
    workoutName: stringOrEmpty(input.workoutName),
    startedAt: integerOrNull(input.startedAt),
    finishedAt: integerOrNull(input.finishedAt),
    totalActiveSeconds: integerOrNull(input.totalActiveSeconds),
    roundsCompleted: integerOrNull(input.roundsCompleted) || 0,
    transitionTimingAvailable: input.transitionTimingAvailable === true,
    movementEvents: Array.isArray(input.movementEvents)
      ? input.movementEvents.map(normalizeMovementAnalyticsEvent).filter(Boolean)
      : [],
    events: Array.isArray(input.events)
      ? input.events.map(normalizeTimelineEvent).filter(Boolean)
      : [],
  };
}

function normalizeMovementAnalyticsEvent(event) {
  if (!event || typeof event !== "object") {
    return null;
  }

  const movementIndex = integerOrNull(event.movementIndex);
  const roundNumber = integerOrNull(event.roundNumber);
  const enteredElapsedSeconds = integerOrNull(event.enteredElapsedSeconds);
  const exitedElapsedSeconds = integerOrNull(event.exitedElapsedSeconds);
  const durationSeconds = integerOrNull(event.durationSeconds);

  if (movementIndex === null || roundNumber === null || enteredElapsedSeconds === null || exitedElapsedSeconds === null || durationSeconds === null) {
    return null;
  }

  return {
    movementIndex,
    movementName: stringOrEmpty(event.movementName),
    prescribedReps: integerOrNull(event.prescribedReps),
    prescribedMeters: integerOrNull(event.prescribedMeters),
    prescribedCalories: caloriesOrNull(event.prescribedCalories),
    prescribedSeconds: integerOrNull(event.prescribedSeconds),
    roundNumber,
    enteredElapsedSeconds,
    exitedElapsedSeconds,
    durationSeconds,
    averageHeartRate: integerOrNull(event.averageHeartRate),
    maximumHeartRate: integerOrNull(event.maximumHeartRate),
    minimumHeartRate: integerOrNull(event.minimumHeartRate),
    heartRateSampleCount: integerOrNull(event.heartRateSampleCount) || 0,
    interrupted: event.interrupted === true,
  };
}

function normalizeTimelineEvent(event) {
  if (!event || typeof event !== "object") {
    return null;
  }

  const eventType = stringOrEmpty(event.eventType);
  const sequence = integerOrNull(event.sequence);
  const elapsedSeconds = integerOrNull(event.elapsedSeconds);

  if (!eventType || sequence === null || elapsedSeconds === null) {
    return null;
  }

  return {
    eventType,
    sequence,
    elapsedSeconds,
    timestamp: integerOrNull(event.timestamp),
    roundNumber: integerOrNull(event.roundNumber),
    stationIndex: integerOrNull(event.stationIndex),
    stationName: stringOrNull(event.stationName),
  };
}

function acceptWorkoutSessionState(existing, incoming) {
  if (
    existing &&
    existing.sessionId === incoming.sessionId &&
    Number(existing.revision) > incoming.revision
  ) {
    return {
      ok: false,
      error: "Older session revision cannot replace a newer revision.",
    };
  }

  if (
    existing &&
    existing.sessionId === incoming.sessionId &&
    Number(existing.revision) === incoming.revision
  ) {
    return {
      ok: true,
      write: false,
      session: existing,
    };
  }

  return {
    ok: true,
    write: true,
    session: incoming,
  };
}

async function readWorkoutSessionFromDisk() {
  try {
    const data = await fs.promises.readFile(WORKOUT_SESSION_PATH, "utf8");
    return JSON.parse(data);
  } catch (error) {
    return null;
  }
}

async function storeCompletedWorkoutFromPayload(payload) {
  const result = normalizeCompletedWorkout(payload, Date.now());
  if (!result.ok) {
    console.warn(`[COMPLETED] skipped archive: ${result.error}`);
    return null;
  }

  return storeCompletedWorkout(result.session);
}

function normalizeCompletedWorkout(input, nowMs = Date.now()) {
  if (!input || typeof input !== "object") {
    return { ok: false, error: "completed workout payload must be an object." };
  }

  const analyticsInput = input.analytics && typeof input.analytics === "object" ? input.analytics : input;
  const analytics = normalizeWorkoutAnalytics(analyticsInput);
  const sessionId = stringOrEmpty(input.sessionId || (analytics && analytics.sessionId));

  if (!isSafeSessionId(sessionId)) {
    return { ok: false, error: "sessionId must be a safe non-empty identifier." };
  }

  const workoutIdentity = stringOrEmpty(input.workoutIdentity || input.workoutId || (analytics && analytics.workoutId));
  const workoutName = stringOrEmpty(input.workoutName || (analytics && analytics.workoutName) || "Workout") || "Workout";
  const startedAt = integerOrNull(input.startedAt) ?? (analytics ? integerOrNull(analytics.startedAt) : null);
  const finishedAt = integerOrNull(input.finishedAt) ?? (analytics ? integerOrNull(analytics.finishedAt) : null) ?? nowMs;
  const totalActiveSeconds = integerOrNull(input.totalActiveSeconds) ?? (analytics ? integerOrNull(analytics.totalActiveSeconds) : null);
  const totalActiveMs = integerOrNull(input.totalActiveMs) ?? (totalActiveSeconds === null ? null : totalActiveSeconds * 1000);
  const roundsCompleted = integerOrNull(input.roundsCompleted) ?? (analytics ? integerOrNull(analytics.roundsCompleted) : null) ?? 0;

  if (analytics && !analytics.sessionId) {
    analytics.sessionId = sessionId;
  }
  if (analytics && !analytics.workoutId) {
    analytics.workoutId = workoutIdentity;
  }
  if (analytics && !analytics.workoutName) {
    analytics.workoutName = workoutName;
  }

  return {
    ok: true,
    session: {
      schemaVersion: integerOrNull(input.schemaVersion) || 1,
      sessionId,
      workoutIdentity,
      workoutName,
      startedAt,
      finishedAt,
      totalActiveMs,
      totalActiveSeconds,
      roundsCompleted,
      status: "completed",
      events: analytics ? analytics.events : [],
      analytics,
      source: normalizeCompletedWorkoutSource(input.source),
      archivedAt: nowMs,
    },
  };
}

function normalizeCompletedWorkoutSource(source) {
  if (!source || typeof source !== "object") {
    return { device: "watch" };
  }

  const normalized = {
    device: stringOrEmpty(source.device || "watch") || "watch",
  };

  const appVersion = stringOrEmpty(source.appVersion);
  const deviceModel = stringOrEmpty(source.deviceModel);
  if (appVersion) normalized.appVersion = appVersion;
  if (deviceModel) normalized.deviceModel = deviceModel;

  return normalized;
}

async function storeCompletedWorkout(session) {
  if (!isSafeSessionId(session.sessionId)) {
    throw new Error("Invalid completed workout sessionId.");
  }

  await fs.promises.mkdir(COMPLETED_WORKOUTS_DIR, { recursive: true });
  const filePath = completedWorkoutPath(session.sessionId);
  const existing = await readCompletedWorkout(session.sessionId);
  const summary = buildCompletedWorkoutSummary(existing || session);

  if (existing) {
    await upsertCompletedWorkoutSummary(summary);
    return {
      sessionId: session.sessionId,
      duplicate: true,
      summary,
    };
  }

  await writeJsonAtomic(filePath, session);
  await upsertCompletedWorkoutSummary(summary);

  return {
    sessionId: session.sessionId,
    duplicate: false,
    summary,
  };
}

async function readCompletedWorkout(sessionId) {
  if (!isSafeSessionId(sessionId)) {
    return null;
  }

  try {
    const data = await fs.promises.readFile(completedWorkoutPath(sessionId), "utf8");
    return JSON.parse(data);
  } catch (error) {
    return null;
  }
}

function completedWorkoutPath(sessionId) {
  return path.join(COMPLETED_WORKOUTS_DIR, `${sessionId}.json`);
}

function isSafeSessionId(sessionId) {
  return /^[A-Za-z0-9._-]{1,160}$/.test(stringOrEmpty(sessionId));
}

async function readCompletedWorkoutIndex() {
  try {
    const data = await fs.promises.readFile(COMPLETED_WORKOUTS_INDEX_PATH, "utf8");
    const parsed = JSON.parse(data);
    return {
      schemaVersion: integerOrNull(parsed.schemaVersion) || 1,
      items: Array.isArray(parsed.items)
        ? parsed.items.map(normalizeCompletedWorkoutSummary).filter(Boolean)
        : [],
    };
  } catch (error) {
    return { schemaVersion: 1, items: [] };
  }
}

async function upsertCompletedWorkoutSummary(summary) {
  const index = await readCompletedWorkoutIndex();
  const bySessionId = new Map();

  for (const item of index.items) {
    bySessionId.set(item.sessionId, item);
  }
  bySessionId.set(summary.sessionId, summary);

  const nextIndex = {
    schemaVersion: 1,
    items: [...bySessionId.values()].sort(compareCompletedWorkoutSummaries),
  };

  await writeJsonAtomic(COMPLETED_WORKOUTS_INDEX_PATH, nextIndex);
}

function normalizeCompletedWorkoutSummary(input) {
  if (!input || typeof input !== "object") {
    return null;
  }

  const sessionId = stringOrEmpty(input.sessionId);
  if (!isSafeSessionId(sessionId)) {
    return null;
  }

  return {
    sessionId,
    workoutIdentity: stringOrEmpty(input.workoutIdentity),
    workoutName: stringOrEmpty(input.workoutName || "Workout") || "Workout",
    startedAt: integerOrNull(input.startedAt),
    finishedAt: integerOrNull(input.finishedAt) || 0,
    totalActiveMs: integerOrNull(input.totalActiveMs),
    totalActiveSeconds: integerOrNull(input.totalActiveSeconds),
    roundsCompleted: integerOrNull(input.roundsCompleted) || 0,
    movementCount: integerOrNull(input.movementCount) || 0,
    averageHeartRate: integerOrNull(input.averageHeartRate),
    maximumHeartRate: integerOrNull(input.maximumHeartRate),
    hasDetailedAnalytics: input.hasDetailedAnalytics === true,
  };
}

function buildCompletedWorkoutSummary(session) {
  const analytics = normalizeWorkoutAnalytics(session.analytics);
  const movementEvents = analytics ? analytics.movementEvents : [];
  const heartRateEvents = movementEvents.filter((event) => event.averageHeartRate !== null && event.heartRateSampleCount > 0);
  const totalHeartRateSamples = heartRateEvents.reduce((sum, event) => sum + event.heartRateSampleCount, 0);
  const weightedHeartRate = heartRateEvents.reduce((sum, event) => sum + event.averageHeartRate * event.heartRateSampleCount, 0);

  return {
    sessionId: session.sessionId,
    workoutIdentity: stringOrEmpty(session.workoutIdentity || (analytics && analytics.workoutId)),
    workoutName: stringOrEmpty(session.workoutName || (analytics && analytics.workoutName) || "Workout") || "Workout",
    startedAt: integerOrNull(session.startedAt) ?? (analytics ? analytics.startedAt : null),
    finishedAt: integerOrNull(session.finishedAt) ?? (analytics ? analytics.finishedAt : null) ?? 0,
    totalActiveMs: integerOrNull(session.totalActiveMs),
    totalActiveSeconds: integerOrNull(session.totalActiveSeconds) ?? (analytics ? analytics.totalActiveSeconds : null),
    roundsCompleted: integerOrNull(session.roundsCompleted) ?? (analytics ? analytics.roundsCompleted : 0) ?? 0,
    movementCount: movementEvents.length,
    averageHeartRate: totalHeartRateSamples > 0 ? Math.round(weightedHeartRate / totalHeartRateSamples) : null,
    maximumHeartRate: movementEvents.map((event) => event.maximumHeartRate).filter(Number.isInteger).reduce((max, value) => max === null || value > max ? value : max, null),
    hasDetailedAnalytics: !!analytics && (movementEvents.length > 0 || analytics.events.length > 0),
  };
}

function compareCompletedWorkoutSummaries(a, b) {
  const finishedDelta = (integerOrNull(b.finishedAt) || 0) - (integerOrNull(a.finishedAt) || 0);
  if (finishedDelta !== 0) return finishedDelta;
  return String(b.sessionId).localeCompare(String(a.sessionId));
}

async function migrateLatestFinishedSessionToArchive() {
  const latest = await readWorkoutSessionFromDisk();
  if (latest && latest.status === "finished" && latest.analytics) {
    await storeCompletedWorkoutFromPayload(latest.analytics);
  }
}

async function writeJsonAtomic(filePath, value) {
  await fs.promises.mkdir(path.dirname(filePath), { recursive: true });
  const tempPath = `${filePath}.${process.pid}.${Date.now()}.tmp`;
  await fs.promises.writeFile(tempPath, JSON.stringify(value, null, 2) + "\n", "utf8");
  await fs.promises.rename(tempPath, filePath);
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === "") return null;

  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function caloriesOrNull(value) {
  if (value === null || value === undefined || value === "") return null;

  const number = Number(value);
  return Number.isFinite(number) && !String(value).includes("/") ? number : String(value);
}

function stringOrEmpty(value) {
  if (value === null || value === undefined) return "";
  return String(value).trim();
}

function stringOrNull(value) {
  const text = stringOrEmpty(value);
  return text ? text : null;
}

function integerOrNull(value) {
  if (value === null || value === undefined || value === "") return null;

  const number = Number(value);
  return Number.isInteger(number) ? number : null;
}

function makeWorkoutId(title, sourceText) {
  const base = `${title || "wod"} ${sourceText || ""}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);

  return base || `wod-${Date.now()}`;
}

function getResponseText(result) {
  if (typeof result.output_text === "string") {
    return result.output_text;
  }

  const pieces = [];

  for (const item of result.output || []) {
    for (const content of item.content || []) {
      if (content.type === "output_text" && content.text) {
        pieces.push(content.text);
      }
    }
  }

  return pieces.join("\n");
}

function uniqueValues(values) {
  const seen = {};
  const unique = [];

  for (const value of values) {
    if (!value || seen[value]) continue;

    seen[value] = true;
    unique.push(value);
  }

  return unique;
}

function isRetryableOpenAiError(message) {
  return /processing your request|try again|temporarily|timeout|server/i.test(message || "");
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const equalsIndex = trimmed.indexOf("=");
    if (equalsIndex === -1) continue;

    const key = trimmed.slice(0, equalsIndex).trim();
    let value = trimmed.slice(equalsIndex + 1).trim();

    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

module.exports = {
  acceptWorkoutSessionState,
  buildCompletedWorkoutSummary,
  normalizeCompletedWorkout,
  normalizeWorkoutAnalytics,
  normalizeWorkoutSessionState,
  normalizeWorkoutContract,
  server,
};
