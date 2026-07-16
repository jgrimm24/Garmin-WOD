const wodInput = document.querySelector("#wodInput");
const parseButton = document.querySelector("#parseButton");
const clearButton = document.querySelector("#clearButton");
const loadSampleButton = document.querySelector("#loadSampleButton");
const copyButton = document.querySelector("#copyButton");
const copyWatchButton = document.querySelector("#copyWatchButton");
const addStationButton = document.querySelector("#addStationButton");
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

const sampleWod = `40 minute EMOM x10
1. Row 45 sec
2. 10 Pull-ups
3. 12 DB Bench @55
4. 15 AbMat Sit-ups`;

let currentWorkout = {};
let draggedStationIndex = null;

if (window.location.protocol === "file:") {
  imageStatus.textContent = "Opening the local importer server...";
  window.location.href = "http://127.0.0.1:4175/importer/";
}

function parseWorkout(text) {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  const joined = lines.join(" ");
  const rounds = findRounds(joined);
  const type = inferWorkoutType(detectType(joined), rounds);
  const durationMinutes = findWorkoutDuration(type, joined);
  const stationLines = findStationLines(lines);
  const stations = stationLines.map((line) => parseStation(line, type)).filter((station) => station.name);
  const notes = findWorkoutNotes(lines);

  return {
    schemaVersion: 1,
    id: makeWorkoutId(lines[0] || "today-wod", text),
    title: lines[0] || "Today's WOD",
    type,
    durationMinutes,
    rounds,
    stations,
    notes,
    sourceText: text.trim(),
  };
}

function detectType(text) {
  if (/\bemom\b/i.test(text)) return "EMOM";
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
      text.match(/\b(\d+)\s*(?:min|minute|minutes)?\s*(?:-|:)?\s*amrap\b/i) ||
      text.match(/\bamrap\s*(?:for|of|:|-)?\s*(\d+)\s*(?:min|minute|minutes)?\b/i);
    return match ? Number(match[1]) : null;
  }

  if (type === "EMOM") {
    const match =
      text.match(/\b(\d+)\s*(?:min|minute|minutes)?\s*(?:-|:)?\s*emom\b/i) ||
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
  const cycleMatch = text.match(/x\s*(\d+)|(\d+)\s*(?:rounds|cycles)/i);
  if (cycleMatch) return Number(cycleMatch[1] || cycleMatch[2]);

  const duration = findNumberBefore(text, /(?:min|minute|minutes)\b/i);
  const stationCount = findStationLines(text.split(/\r?\n/)).length;
  if (/\bemom\b/i.test(text) && duration && stationCount) {
    return Math.floor(duration / stationCount);
  }

  return null;
}

function findStationLines(lines) {
  return lines.filter((line) => {
    if (/\b(?:emom|amrap|for time|tabata)\b/i.test(line)) return false;
    if (/^\d+\s*(?:rounds?|rds?)\b/i.test(line)) return false;
    if (isGenderWeightLine(line)) return false;
    return /(^\d+[\).:-]\s*)|(^\d+\s+\D)|(\d+\s*(?:reps?|cal|cals|m|meter|meters|sec|seconds|min|minute|minutes|lb|#|@))|row|run|bike|pull|push|squat|bench|sit|clean|snatch|deadlift|burpee|wall ball|toes|thruster|double\s+unders?|rest/i.test(line);
  });
}

function findWorkoutNotes(lines) {
  return lines.filter(isGenderWeightLine);
}

function isGenderWeightLine(line) {
  return /^[♀♂MFmf]\s*\d+\s*(?:lb|lbs|#)\b/.test(line.trim());
}

function parseStation(line, workoutType) {
  const cleaned = line
    .replace(/^[•\-–—*]\s*/, "")
    .replace(/^\d+[\).:-]\s+(?=\D)/, "")
    .trim();
  const secondsMatch = cleaned.match(/(\d+)\s*(?:sec|secs|second|seconds)\b/i);
  const minutesMatch = cleaned.match(/(\d+)\s*(?:min|minute|minutes)\b/i);
  const weightMatch = cleaned.match(/(?:@|with\s+)?(\d+)\s*(?:lb|lbs|#)\b/i);
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
    .replace(/\s*\d+(?:\s*\/\s*\d+)?\s*(?:cal|cals|calorie|calories)\b/i, "")
    .replace(/\s*\d+\s*(?:-| )?\s*(?:m|meter|meters)\b/i, "")
    .replace(/\s*@\s*\d+\s*(?:lb|lbs|#)?/i, "")
    .replace(/\s*\d+\s*(?:lb|lbs|#)\b/i, "")
    .replace(/\s*\d+\s*(?:sec|secs|second|seconds)\b/i, "")
    .replace(/\s*\d+\s*(?:min|minute|minutes)\b/i, "")
    .trim();

  name = normalizeMovementName(name);

  return {
    name,
    reps,
    workSeconds: timedSeconds != null ? timedSeconds : getDefaultWorkSeconds(workoutType),
    distanceMeters: distanceMatch ? Number(distanceMatch[1]) : null,
    calories: caloriesMatch ? caloriesMatch[1].replace(/\s+/g, "") : null,
    weightLb: weightMatch ? Number(weightMatch[1]) : null,
    notes: cleaned,
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
        ${["Unknown", "EMOM", "AMRAP", "For Time", "Tabata"].map((type) => `<option value="${type}" ${type === currentWorkout.type ? "selected" : ""}>${type}</option>`).join("")}
      </select>
    </label>
    <label class="summary-item">
      <span>Duration</span>
      <input data-summary-field="durationMinutes" type="number" min="0" placeholder="${currentWorkout.type === "For Time" ? "None" : "Minutes"}" value="${numberValue(currentWorkout.durationMinutes)}" />
    </label>
    <label class="summary-item">
      <span>Rounds</span>
      <input data-summary-field="rounds" type="number" min="0" placeholder="Unknown" value="${numberValue(currentWorkout.rounds)}" />
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
            ${renderStationField(index, "weightLb", "Lb", "number", station.weightLb)}
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
  if (station.weightLb) pieces.push(`${station.weightLb} lb`);
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

  return {
    schemaVersion: 1,
    id: workout.id || makeWorkoutId(title, sourceText),
    title,
    type: workout.type || "Unknown",
    durationMinutes: workout.durationMinutes || null,
    rounds: workout.rounds || null,
    stations: Array.isArray(workout.stations) ? workout.stations.map(normalizeStation) : [],
    notes: Array.isArray(workout.notes) ? workout.notes : [],
    sourceText,
    createdAt: workout.createdAt || new Date().toISOString(),
    updatedAt: workout.updatedAt || new Date().toISOString(),
  };
}

function normalizeStation(station, index) {
  return {
    id: station.id || `station-${index + 1}`,
    name: station.name || "",
    reps: station.reps || null,
    calories: station.calories || null,
    workSeconds: station.workSeconds || null,
    distanceMeters: station.distanceMeters || station.meters || null,
    weightLb: station.weightLb || null,
    notes: station.notes || "",
  };
}

function numberValue(value) {
  return value === null || value === undefined ? "" : value;
}

function numberOrNull(value) {
  if (value === "") return null;
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

  if (!notes.length) {
    notesList.innerHTML = "";
    return;
  }

  notesList.innerHTML = `
    <div class="notes-card">
      <span>Notes</span>
      <strong>${notes.map(escapeHtml).join(" · ")}</strong>
    </div>
  `;
}

summaryGrid.addEventListener("input", (event) => {
  const field = event.target.dataset.summaryField;
  if (!field) return;

  currentWorkout[field] = field === "type" ? event.target.value : numberOrNull(event.target.value);
  updateJsonOutput();
});

summaryGrid.addEventListener("change", (event) => {
  const field = event.target.dataset.summaryField;
  if (!field) return;

  currentWorkout[field] = field === "type" ? event.target.value : numberOrNull(event.target.value);
  renderWorkout(currentWorkout);
});

stationsList.addEventListener("input", (event) => {
  const index = Number(event.target.dataset.stationIndex);
  const field = event.target.dataset.stationField;
  if (!field || !currentWorkout.stations[index]) return;

  currentWorkout.stations[index][field] = field === "name" || field === "calories" ? event.target.value : numberOrNull(event.target.value);
  updateJsonOutput();
});

stationsList.addEventListener("click", (event) => {
  const index = event.target.dataset.removeStation;
  if (index === undefined) return;

  currentWorkout.stations.splice(Number(index), 1);
  renderWorkout(currentWorkout);
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
});

clearButton.addEventListener("click", () => {
  wodInput.value = "";
  imageInput.value = "";
  imagePreview.className = "image-preview empty-preview";
  imagePreview.textContent = "No image selected";
  imageStatus.textContent = "Choose an image to extract workout text, or paste text below.";
  renderWorkout({});
  previewTitle.textContent = "No workout parsed";
  summaryGrid.innerHTML = "";
  notesList.innerHTML = "";
  stationsList.className = "stations-list empty-state";
  stationsList.textContent = "Paste a WOD, then parse it.";
});

loadSampleButton.addEventListener("click", () => {
  wodInput.value = sampleWod;
  renderWorkout(parseWorkout(sampleWod));
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
    notes: "",
  });
  renderWorkout(currentWorkout);
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
    await saveLatestWorkout(currentWorkout);
    saveLatestButton.textContent = "Saved";
  } catch (error) {
    saveLatestButton.textContent = "Save Failed";
    imageStatus.textContent = error.message || "Could not save latest WOD.";
  }

  setTimeout(() => {
    saveLatestButton.textContent = "Save Latest WOD";
  }, 1400);
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
    var durationMinutes;
    var rounds;
    var stationNames;
    var stationReps;
    var stationSeconds;
    var stationCalories;
    var stationMeters;
    var stationWeights;

    function initialize() {
        title = ${toMonkeyCString(normalized.title)};
        workoutType = ${toMonkeyCString(normalized.type)};
        durationMinutes = ${toMonkeyCValue(normalized.durationMinutes)};
        rounds = ${toMonkeyCValue(normalized.rounds)};
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
        if (durationMinutes == null) {
            return null;
        }

        return durationMinutes * 60;
    }

    function getHeader(roundNumber) {
        if (workoutType == "For Time") {
            if (rounds == null) {
                return "FOR TIME";
            }

            return rounds + " RFT";
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
    durationMinutes: normalized.durationMinutes,
    rounds: normalized.rounds,
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

  currentWorkout = normalizeWorkout(result.workout || result);
  updateJsonOutput();
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
