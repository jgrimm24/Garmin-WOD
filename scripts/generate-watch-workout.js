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
  return {
    name: stringOrDefault(station.name, "Station"),
    reps: numberOrNull(station.reps),
    workSeconds: numberOrNull(station.workSeconds),
    calories: station.calories === undefined || station.calories === "" ? null : station.calories,
    meters: numberOrNull(station.meters === undefined ? station.distanceMeters : station.meters),
    weightLb: numberOrNull(station.weightLb),
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

    function initialize() {
        title = ${toMonkeyCValue(workout.title)};
        workoutType = ${toMonkeyCValue(workout.type)};
        durationMinutes = ${toMonkeyCValue(workout.durationMinutes)};
        rounds = ${toMonkeyCValue(workout.rounds)};
        stationNames = ${toMonkeyCArray(stations.map((station) => station.name))};
        stationReps = ${toMonkeyCArray(stations.map((station) => station.reps))};
        stationSeconds = ${toMonkeyCArray(stations.map((station) => station.workSeconds))};
        stationCalories = ${toMonkeyCArray(stations.map((station) => station.calories))};
        stationMeters = ${toMonkeyCArray(stations.map((station) => station.meters))};
        stationWeights = ${toMonkeyCArray(stations.map((station) => station.weightLb))};
    }

    function loadFromContract(data) {
        if (data == null) {
            return false;
        }

        var stations = data["stations"];

        if (stations == null || stations.size() == 0) {
            return false;
        }

        title = getContractString(data, "title", title);
        workoutType = getContractString(data, "type", workoutType);
        durationMinutes = getContractValue(data, "durationMinutes", durationMinutes);
        rounds = getContractValue(data, "rounds", rounds);
        stationNames = [];
        stationReps = [];
        stationSeconds = [];
        stationCalories = [];
        stationMeters = [];
        stationWeights = [];

        for (var i = 0; i < stations.size(); i++) {
            var station = stations[i];

            if (station != null) {
                stationNames.add(getContractString(station, "name", "Station"));
                stationReps.add(getContractValue(station, "reps", null));
                stationSeconds.add(getContractValue(station, "workSeconds", null));
                stationCalories.add(getContractValue(station, "calories", null));
                stationMeters.add(getContractValue(station, "meters", null));
                stationWeights.add(getContractValue(station, "weightLb", null));
            }
        }

        return stationNames.size() > 0;
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

    function getTotalSeconds() {
        if (durationMinutes == null) {
            return null;
        }

        return durationMinutes * 60;
    }

    function isForTime() {
        return workoutType.equals("For Time");
    }

    function isEmom() {
        return workoutType.equals("EMOM");
    }

    function isAmrap() {
        return workoutType.equals("AMRAP");
    }

    function isTimedPriority() {
        return isAmrap();
    }

    function getHeader(roundNumber) {
        if (isForTime()) {
            if (rounds == null) {
                return "FOR TIME";
            }

            return "" + rounds + " RFT";
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
        return stationSeconds[index];
    }

    function getStationMeters(index) {
        return stationMeters[index];
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
