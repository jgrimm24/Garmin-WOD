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
  return {
    title: stringOrDefault(workout.title, "Today's WOD"),
    type: stringOrDefault(workout.type, "Unknown"),
    durationMinutes: numberOrNull(workout.durationMinutes),
    rounds: numberOrNull(workout.rounds),
    stations: Array.isArray(workout.stations) ? workout.stations.map(normalizeStation) : [],
  };
}

function normalizeStation(station) {
  const maleWeightLb = numberOrNull(station.maleWeightLb === undefined ? station.weightLb : station.maleWeightLb);
  const femaleWeightLb = numberOrNull(station.femaleWeightLb);

  return {
    name: stringOrDefault(station.name, "Station"),
    reps: numberOrNull(station.reps),
    workSeconds: numberOrNull(station.workSeconds),
    calories: station.calories === undefined || station.calories === "" ? null : station.calories,
    meters: numberOrNull(station.meters === undefined ? station.distanceMeters : station.meters),
    weightLb: numberOrNull(station.weightLb === undefined || station.weightLb === null ? maleWeightLb : station.weightLb),
    maleWeightLb,
    femaleWeightLb,
  };
}

function renderWorkoutClass(workout) {
  const stations = workout.stations;

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
    var _hasWorkout;

    function initialize() {
        title = "NO WORKOUT LOADED";
        workoutType = "Unknown";
        durationMinutes = null;
        rounds = null;
        stationNames = [];
        stationReps = [];
        stationSeconds = [];
        stationCalories = [];
        stationMeters = [];
        stationWeights = [];
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

        for (var i = 0; i < stations.size(); i++) {
            var station = stations[i];

            if (station != null) {
                parsedNames.add(getContractString(station, "name", "Station"));
                parsedReps.add(getContractValue(station, "reps", null));
                parsedSeconds.add(getContractValue(station, "workSeconds", null));
                parsedCalories.add(getContractValue(station, "calories", null));
                parsedMeters.add(getContractValue(station, "meters", null));
                parsedWeights.add(getContractValue(station, "weightLb", getContractValue(station, "maleWeightLb", null)));
            }
        }

        if (parsedNames.size() == 0) {
            return false;
        }

        title = getContractString(data, "title", "Workout");
        workoutType = getContractString(data, "type", "Unknown");
        durationMinutes = getContractValue(data, "durationMinutes", null);
        rounds = getContractValue(data, "rounds", null);
        stationNames = parsedNames;
        stationReps = parsedReps;
        stationSeconds = parsedSeconds;
        stationCalories = parsedCalories;
        stationMeters = parsedMeters;
        stationWeights = parsedWeights;
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

    function getStationCount() {
        return stationNames.size();
    }

    function hasWorkout() {
        return _hasWorkout && stationNames != null && stationNames.size() > 0;
    }

    function getTotalSeconds() {
        if (!hasWorkout() || durationMinutes == null) {
            return null;
        }

        return durationMinutes * 60;
    }

    function isForTime() {
        return hasWorkout() && (workoutType.equals("For Time") || workoutType.equals("FOR TIME"));
    }

    function isEmom() {
        return hasWorkout() && (workoutType.equals("EMOM") || workoutType.equals("Emom"));
    }

    function isAmrap() {
        return hasWorkout() && (workoutType.equals("AMRAP") || workoutType.equals("Amrap"));
    }

    function isTimedPriority() {
        return isAmrap();
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

function stringOrDefault(value, fallback) {
  return value === undefined || value === null || value === "" ? fallback : String(value);
}

function numberOrNull(value) {
  if (value === undefined || value === null || value === "") return null;

  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
