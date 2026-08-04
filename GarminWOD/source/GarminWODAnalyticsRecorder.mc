import Toybox.Application.Storage;
import Toybox.Time;

class GarminWODAnalyticsRecorder {
    const STORAGE_KEY = "completedWorkoutAnalyticsV1";

    var _sessionId;
    var _workoutId;
    var _workoutName;
    var _startedAt;
    var _finishedAt;
    var _events;
    var _segments;
    var _sequence;
    var _activeSegment;
    var _completedRounds;

    function initialize() {
        reset();
    }

    function reset() as Void {
        _sessionId = null;
        _workoutId = null;
        _workoutName = null;
        _startedAt = null;
        _finishedAt = null;
        _events = [];
        _segments = [];
        _sequence = 0;
        _activeSegment = null;
        _completedRounds = 0;
    }

    function hasActiveSession() {
        return _sessionId != null;
    }

    function startWorkout(sessionId, workoutId, workoutName, elapsedSeconds, roundNumber, stationIndex, stationName, reps, meters, calories, seconds) as Void {
        reset();
        _sessionId = sessionId;
        _workoutId = workoutId;
        _workoutName = workoutName;
        _startedAt = Time.now().value();
        addEvent("workout_started", elapsedSeconds, roundNumber, stationIndex, stationName);
        addEvent("round_started", elapsedSeconds, roundNumber, stationIndex, stationName);
        startStation(elapsedSeconds, roundNumber, stationIndex, stationName, reps, meters, calories, seconds);
        checkpoint();
    }

    function startStation(elapsedSeconds, roundNumber, stationIndex, stationName, reps, meters, calories, seconds) as Void {
        _activeSegment = {
            "movementIndex" => stationIndex,
            "movementName" => stationName,
            "prescribedReps" => reps,
            "prescribedMeters" => meters,
            "prescribedCalories" => calories,
            "prescribedSeconds" => seconds,
            "roundNumber" => roundNumber,
            "enteredElapsedSeconds" => elapsedSeconds,
            "exitedElapsedSeconds" => null,
            "durationSeconds" => null,
            "averageHeartRate" => null,
            "maximumHeartRate" => null,
            "minimumHeartRate" => null,
            "heartRateSampleCount" => 0,
            "_heartRateSum" => 0
        };
        addEvent("station_started", elapsedSeconds, roundNumber, stationIndex, stationName);
    }

    function completeStation(elapsedSeconds, interrupted) as Void {
        if (_activeSegment == null) {
            return;
        }

        var startedAt = _activeSegment["enteredElapsedSeconds"];
        var duration = elapsedSeconds - startedAt;
        if (duration < 0) {
            duration = 0;
        }

        _activeSegment["exitedElapsedSeconds"] = elapsedSeconds;
        _activeSegment["durationSeconds"] = duration;
        _activeSegment["interrupted"] = interrupted;

        var sampleCount = _activeSegment["heartRateSampleCount"];
        if (sampleCount != null && sampleCount > 0) {
            _activeSegment["averageHeartRate"] = _activeSegment["_heartRateSum"] / sampleCount;
        }

        var completedSegment = {
            "movementIndex" => _activeSegment["movementIndex"],
            "movementName" => _activeSegment["movementName"],
            "prescribedReps" => _activeSegment["prescribedReps"],
            "prescribedMeters" => _activeSegment["prescribedMeters"],
            "prescribedCalories" => _activeSegment["prescribedCalories"],
            "prescribedSeconds" => _activeSegment["prescribedSeconds"],
            "roundNumber" => _activeSegment["roundNumber"],
            "enteredElapsedSeconds" => _activeSegment["enteredElapsedSeconds"],
            "exitedElapsedSeconds" => _activeSegment["exitedElapsedSeconds"],
            "durationSeconds" => _activeSegment["durationSeconds"],
            "averageHeartRate" => _activeSegment["averageHeartRate"],
            "maximumHeartRate" => _activeSegment["maximumHeartRate"],
            "minimumHeartRate" => _activeSegment["minimumHeartRate"],
            "heartRateSampleCount" => _activeSegment["heartRateSampleCount"],
            "interrupted" => _activeSegment["interrupted"]
        };
        _segments.add(completedSegment);
        addEvent(interrupted ? "station_interrupted" : "station_completed", elapsedSeconds, _activeSegment["roundNumber"], _activeSegment["movementIndex"], _activeSegment["movementName"]);
        _activeSegment = null;
        checkpoint();
    }

    function completeRound(elapsedSeconds, roundNumber) as Void {
        _completedRounds = roundNumber;
        addEvent("round_completed", elapsedSeconds, roundNumber, null, null);
        checkpoint();
    }

    function startRound(elapsedSeconds, roundNumber, stationIndex, stationName) as Void {
        addEvent("round_started", elapsedSeconds, roundNumber, stationIndex, stationName);
        checkpoint();
    }

    function pauseWorkout(elapsedSeconds, roundNumber, stationIndex, stationName) as Void {
        addEvent("workout_paused", elapsedSeconds, roundNumber, stationIndex, stationName);
        checkpoint();
    }

    function resumeWorkout(elapsedSeconds, roundNumber, stationIndex, stationName) as Void {
        addEvent("workout_resumed", elapsedSeconds, roundNumber, stationIndex, stationName);
        checkpoint();
    }

    function finishWorkout(elapsedSeconds, roundNumber, stationIndex, stationName, completesRound) {
        completeStation(elapsedSeconds, false);
        if (completesRound) {
            completeRound(elapsedSeconds, roundNumber);
        }
        _finishedAt = Time.now().value();
        addEvent("workout_finished", elapsedSeconds, roundNumber, stationIndex, stationName);
        var payload = toPayload(elapsedSeconds);
        Storage.setValue(STORAGE_KEY, payload);
        return payload;
    }

    function addHeartRateSample(heartRate) as Void {
        if (_activeSegment == null || heartRate == null) {
            return;
        }

        var count = _activeSegment["heartRateSampleCount"] + 1;
        _activeSegment["heartRateSampleCount"] = count;
        _activeSegment["_heartRateSum"] = _activeSegment["_heartRateSum"] + heartRate;

        var minHr = _activeSegment["minimumHeartRate"];
        if (minHr == null || heartRate < minHr) {
            _activeSegment["minimumHeartRate"] = heartRate;
        }

        var maxHr = _activeSegment["maximumHeartRate"];
        if (maxHr == null || heartRate > maxHr) {
            _activeSegment["maximumHeartRate"] = heartRate;
        }
    }

    function toPayload(totalActiveSeconds) {
        return {
            "schemaVersion" => 1,
            "sessionId" => _sessionId,
            "workoutId" => _workoutId,
            "workoutName" => _workoutName,
            "startedAt" => _startedAt,
            "finishedAt" => _finishedAt,
            "totalActiveSeconds" => totalActiveSeconds,
            "roundsCompleted" => _completedRounds,
            "movementEvents" => _segments,
            "events" => _events,
            "transitionTimingAvailable" => false
        };
    }

    function addEvent(eventType, elapsedSeconds, roundNumber, stationIndex, stationName) as Void {
        _sequence++;
        _events.add({
            "eventType" => eventType,
            "sequence" => _sequence,
            "elapsedSeconds" => elapsedSeconds,
            "timestamp" => Time.now().value(),
            "roundNumber" => roundNumber,
            "stationIndex" => stationIndex,
            "stationName" => stationName
        });
    }

    function checkpoint() as Void {
        if (_sessionId == null) {
            return;
        }

        Storage.setValue(STORAGE_KEY, toPayload(null));
    }
}
