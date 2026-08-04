const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const DEFAULT_INPUT = path.join(ROOT, "data", "latest-workout.json");
const DEFAULT_OUTPUT = path.join(ROOT, "GarminWOD", "source", "GarminWODWorkout.mc");

const inputPath = path.resolve(ROOT, process.argv[2] || DEFAULT_INPUT);
const outputPath = path.resolve(ROOT, process.argv[3] || DEFAULT_OUTPUT);

const workout = normalizeWorkout(JSON.parse(fs.readFileSync(inputPath, "utf8")));
const source = renderWorkoutClass(workout);

fs.writeFileSync(outputPath, source, "utf8");
console.log(`Generated ${path.relative(ROOT, outputPath)} from ${path.relative(ROOT, inputPath)}`);

function normalizeWorkout(workout) {
  const durationMinutes = numberOrNull(workout.durationMinutes);
  const repScheme = normalizeRepScheme(workout.repScheme);
  const normalizedStructure = normalizeRepSchemeStructure({
    structureType: normalizeStructureType(workout.structureType),
    rounds: numberOrNull(workout.rounds),
    repScheme,
  });

  return {
    title: stringOrDefault(workout.title, "Today's WOD"),
    type: stringOrDefault(workout.type, "Unknown"),
    workoutType: normalizeWorkoutTypeCode(workout.workoutType || workout.type),
    structureType: normalizedStructure.structureType,
    durationMinutes,
    durationSeconds: numberOrNull(workout.durationSeconds) || (durationMinutes == null ? null : durationMinutes * 60),
    rounds: normalizedStructure.rounds,
    repScheme,
    intervalSeconds: numberOrNull(workout.intervalSeconds),
    stations: Array.isArray(workout.stations) ? workout.stations.map(normalizeStation) : [],
  };
}

function normalizeRepSchemeStructure({ structureType, rounds, repScheme }) {
  const hasRepScheme = Array.isArray(repScheme) && repScheme.length >= 2;

  if (!hasRepScheme) {
    return { structureType, rounds };
  }

  return {
    structureType: structureType === "UNKNOWN" || structureType === "FIXED_STATIONS" ? "REP_SCHEME" : structureType,
    rounds: rounds == null ? repScheme.length : rounds,
  };
}

function normalizeStation(station) {
  const maleWeightLb = numberOrNull(station.maleWeightLb === undefined ? station.weightLb : station.maleWeightLb);
  const femaleWeightLb = numberOrNull(station.femaleWeightLb);
  const maleWeightKg = numberOrNull(station.maleWeightKg);
  const femaleWeightKg = numberOrNull(station.femaleWeightKg);
  const maleHeightIn = numberOrNull(station.maleHeightIn);
  const femaleHeightIn = numberOrNull(station.femaleHeightIn);

  return {
    name: stringOrDefault(station.name, "Station"),
    reps: numberOrNull(station.reps),
    workSeconds: numberOrNull(station.workSeconds),
    calories: station.calories === undefined || station.calories === "" ? null : station.calories,
    meters: numberOrNull(station.meters === undefined ? station.distanceMeters : station.meters),
    weightLb: numberOrNull(station.weightLb === undefined || station.weightLb === null ? maleWeightLb : station.weightLb),
    maleWeightLb,
    femaleWeightLb,
    weightUnit: station.weightUnit || (maleWeightKg != null ? "kg" : maleWeightLb != null ? "lb" : null),
    maleWeightKg,
    femaleWeightKg,
    heightUnit: station.heightUnit || (maleHeightIn != null ? "in" : null),
    maleHeightIn,
    femaleHeightIn,
  };
}

function renderWorkoutClass(workout) {
  const stations = workout.stations;

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
    var stationMaleWeightKg;
    var stationFemaleWeightKg;
    var stationMaleHeightIn;
    var stationFemaleHeightIn;
    var _hasWorkout;

    function initialize() {
        title = "NO WORKOUT LOADED";
        workoutType = "Unknown";
        workoutTypeCode = "UNKNOWN";
        structureType = "UNKNOWN";
        durationMinutes = null;
        durationSeconds = null;
        rounds = null;
        repScheme = [];
        intervalSeconds = null;
        stationNames = [];
        stationReps = [];
        stationSeconds = [];
        stationCalories = [];
        stationMeters = [];
        stationWeights = [];
        stationMaleWeightKg = [];
        stationFemaleWeightKg = [];
        stationMaleHeightIn = [];
        stationFemaleHeightIn = [];
        _hasWorkout = false;
    }

    function loadFromContract(data) {
        if (data == null) {
            return false;
        }

        var stations = data["stations"];

        if (stations == null || stations.size() == 0) {
            return false;
        }

        var parsedNames = [];
        var parsedReps = [];
        var parsedSeconds = [];
        var parsedCalories = [];
        var parsedMeters = [];
        var parsedWeights = [];
        var parsedMaleWeightKg = [];
        var parsedFemaleWeightKg = [];
        var parsedMaleHeightIn = [];
        var parsedFemaleHeightIn = [];

        for (var i = 0; i < stations.size(); i++) {
            var station = stations[i];

            if (station != null) {
                parsedNames.add(getContractString(station, "name", "Station"));
                parsedReps.add(getContractValue(station, "reps", null));
                parsedSeconds.add(getContractValue(station, "workSeconds", null));
                parsedCalories.add(getContractValue(station, "calories", null));
                parsedMeters.add(getContractValue(station, "meters", null));
                parsedWeights.add(getContractValue(station, "weightLb", getContractValue(station, "maleWeightLb", null)));
                parsedMaleWeightKg.add(getContractValue(station, "maleWeightKg", null));
                parsedFemaleWeightKg.add(getContractValue(station, "femaleWeightKg", null));
                parsedMaleHeightIn.add(getContractValue(station, "maleHeightIn", null));
                parsedFemaleHeightIn.add(getContractValue(station, "femaleHeightIn", null));
            }
        }

        if (parsedNames.size() == 0) {
            return false;
        }

        title = getContractString(data, "title", "Workout");
        workoutType = getContractString(data, "type", "Unknown");
        workoutTypeCode = getContractString(data, "workoutType", normalizeWorkoutTypeCode(workoutType));
        structureType = getContractString(data, "structureType", "UNKNOWN");
        durationMinutes = getContractValue(data, "durationMinutes", null);
        durationSeconds = getContractValue(data, "durationSeconds", null);
        rounds = getContractValue(data, "rounds", null);
        repScheme = getContractArray(data, "repScheme");
        intervalSeconds = getContractValue(data, "intervalSeconds", null);
        stationNames = parsedNames;
        stationReps = parsedReps;
        stationSeconds = parsedSeconds;
        stationCalories = parsedCalories;
        stationMeters = parsedMeters;
        stationWeights = parsedWeights;
        stationMaleWeightKg = parsedMaleWeightKg;
        stationFemaleWeightKg = parsedFemaleWeightKg;
        stationMaleHeightIn = parsedMaleHeightIn;
        stationFemaleHeightIn = parsedFemaleHeightIn;
        _hasWorkout = true;

        return true;
    }

    function getContractValue(data, key, fallback) {
        var value = data[key];

        if (value == null) {
            return fallback;
        }

        return value;
    }

    function getContractString(data, key, fallback) {
        var value = getContractValue(data, key, fallback);

        if (value == null) {
            return fallback;
        }

        return "" + value;
    }

    function getContractArray(data, key) {
        var value = data[key];

        if (value == null) {
            return [];
        }

        return value;
    }

    function normalizeWorkoutTypeCode(value) {
        var normalized = ("" + value).toUpper();

        if (normalized.equals("FOR TIME")) {
            return "FOR_TIME";
        }

        if (normalized.equals("AMRAP") || normalized.equals("EMOM") || normalized.equals("INTERVAL") || normalized.equals("STRENGTH") || normalized.equals("CHIPPER")) {
            return normalized;
        }

        return "UNKNOWN";
    }

    function getStationCount() {
        return stationNames.size();
    }

    function hasWorkout() {
        return _hasWorkout && stationNames != null && stationNames.size() > 0;
    }

    function getTotalSeconds() {
        if (!hasWorkout()) {
            return null;
        }

        if (durationSeconds != null) {
            return durationSeconds;
        }

        if (durationMinutes == null) {
            return null;
        }

        return durationMinutes * 60;
    }

    function isForTime() {
        return hasWorkout() && (workoutTypeCode.equals("FOR_TIME") || workoutType.equals("For Time") || workoutType.equals("FOR TIME"));
    }

    function isEmom() {
        return hasWorkout() && (workoutTypeCode.equals("EMOM") || workoutType.equals("EMOM") || workoutType.equals("Emom"));
    }

    function isAmrap() {
        return hasWorkout() && (workoutTypeCode.equals("AMRAP") || workoutType.equals("AMRAP") || workoutType.equals("Amrap"));
    }

    function isInterval() {
        return hasWorkout() && (workoutTypeCode.equals("INTERVAL") || structureType.equals("TIMED_INTERVAL"));
    }

    function isTimedPriority() {
        return isAmrap() || isInterval() || isEmom();
    }

    function isManualStationWorkout() {
        return hasWorkout() && !isEmom();
    }

    function getHeader(roundNumber) {
        if (!hasWorkout()) {
            return "NO WORKOUT";
        }

        if (isForTime()) {
            if (rounds == null) {
                return "FOR TIME";
            }

            return "" + rounds + " RFT";
        }

        if (isAmrap()) {
            return durationMinutes == null ? "AMRAP" : "AMRAP " + durationMinutes;
        }

        if (isManualStationWorkout() && rounds != null) {
            return "" + rounds + " RFT";
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
        if (!hasValidStationIndex(index)) {
            return "NO WORKOUT";
        }

        var name = stationNames[index];
        var reps = stationReps[index];
        var calories = stationCalories[index];
        var meters = stationMeters[index];
        var weight = stationWeights[index];

        if (meters != null) {
            name = "" + meters + "m " + name;
        }

        if (calories != null) {
            name = calories + " cal " + name;
        }

        if (reps != null) {
            name = "" + reps + " " + name;
        }

        if (weight != null) {
            name = name + " @" + weight;
        }

        return name;
    }

    function getScoreboardMovementName(index) {
        if (!hasValidStationIndex(index)) {
            return "NO WORKOUT";
        }

        return stationNames[index];
    }

    function getScoreboardMovementText(index, roundNumber) {
        if (!hasValidStationIndex(index)) {
            return "NO WORKOUT";
        }

        var prefix = getEssentialPrescription(index, roundNumber);
        var name = stationNames[index];

        if (prefix == null || startsWithNormalizedPrescription(name, prefix)) {
            return name;
        }

        return prefix + " " + name;
    }

    function getEssentialPrescription(index, roundNumber) {
        if (!hasValidStationIndex(index)) {
            return null;
        }

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
        if (!hasValidStationIndex(index)) {
            return null;
        }

        return stationSeconds[index];
    }

    function getStationMeters(index) {
        if (!hasValidStationIndex(index)) {
            return null;
        }

        return stationMeters[index];
    }

    function getStationCalories(index) {
        if (!hasValidStationIndex(index)) {
            return null;
        }

        return stationCalories[index];
    }

    function hasValidStationIndex(index) {
        return hasWorkout() && index >= 0 && index < stationNames.size();
    }
}
`;
}

function toMonkeyCArray(values) {
  if (!values.length) {
    return "[]";
  }

  return `[
            ${values.map(toMonkeyCValue).join(",\n            ")}
        ]`;
}

function toMonkeyCValue(value) {
  if (value === null || value === undefined || value === "") return "null";
  if (typeof value === "number") return String(value);
  return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
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

function stringOrDefault(value, fallback) {
  return value === undefined || value === null || value === "" ? fallback : String(value);
}

function numberOrNull(value) {
  if (value === undefined || value === null || value === "") return null;

  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
