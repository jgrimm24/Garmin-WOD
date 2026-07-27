const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = __dirname;
const PORT = Number(process.env.PORT || 4175);
const HOST = process.env.HOST || "0.0.0.0";
const DATA_DIR = path.join(ROOT, "data");
const LATEST_WORKOUT_PATH = path.join(DATA_DIR, "latest-workout.json");
const WORKOUT_SESSION_PATH = path.join(DATA_DIR, "workout-session.json");

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
  }

  sendJson(response, 200, { session: decision.session });
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

  return {
    schemaVersion: 1,
    id: String(workout.id || makeWorkoutId(title, sourceText)),
    title,
    type: normalizeWorkoutType(workout.type),
    durationMinutes: numberOrNull(workout.durationMinutes),
    rounds: numberOrNull(workout.rounds),
    notes: Array.isArray(workout.notes) ? workout.notes.map(String) : [],
    sourceText,
    createdAt: String(workout.createdAt || now),
    updatedAt: now,
    stations: Array.isArray(workout.stations) ? workout.stations.map(normalizeStationContract) : [],
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
  };

  return allowedTypes[type] ? type : "Unknown";
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
    },
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
  normalizeWorkoutSessionState,
  normalizeWorkoutContract,
  server,
};
