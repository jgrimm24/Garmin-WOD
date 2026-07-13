class GarminWODWorkout {
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
        title = "FOR TIME";
        workoutType = "For Time";
        durationMinutes = null;
        rounds = null;
        stationNames = [
            "Row",
            "Wall Balls",
            "Toes-to-bar",
            "Box Jumps",
            "Sumo DL High Pulls",
            "Burpees",
            "Shoulder-to-Overhead",
            "Row"
        ];
        stationReps = [
            null,
            30,
            20,
            30,
            20,
            30,
            20,
            null
        ];
        stationSeconds = [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null
        ];
        stationCalories = [
            20,
            null,
            null,
            null,
            null,
            null,
            null,
            20
        ];
        stationMeters = [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null
        ];
        stationWeights = [
            null,
            20,
            null,
            null,
            95,
            null,
            95,
            null
        ];
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
        return workoutType.equals("For Time") || workoutType.equals("FOR TIME");
    }

    function isEmom() {
        return workoutType.equals("EMOM") || workoutType.equals("Emom");
    }

    function isAmrap() {
        return workoutType.equals("AMRAP") || workoutType.equals("Amrap");
    }

    function isTimedPriority() {
        return isAmrap();
    }

    function isManualStationWorkout() {
        return !isEmom();
    }

    function getHeader(roundNumber) {
        if (isForTime()) {
            if (rounds == null) {
                return "FOR TIME";
            }

            return "" + rounds + " RFT";
        }

        if (isAmrap()) {
            return "AMRAP " + durationMinutes;
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
