import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Attention;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.UserProfile;
import Toybox.WatchUi;

class GarminWODView extends WatchUi.View {
    var _timer;
    var _isRunning;
    var _startMs;
    var _elapsedBeforePause;
    var _workout;
    var _totalSeconds;
    var _manualStationIndex;
    var _manualRoundNumber;
    var _isFinished;
    var _heartRateZones;
    var _heartRateSum;
    var _heartRateSamples;
    var _maxHeartRate;
    var _stationDistanceStart;
    var _distanceStationIndex;
    var _gpsDistanceMeters;
    var _lastLocation;
    var _hasGpsFix;
    var _gpsFixAlerted;
    var _startPendingForGps;
    var _startPendingForWorkout;
    var _isFetchingWorkout;
    var _hasLoadedInitialWorkout;
    var _isTimerActive;
    var _isLocationEventsActive;
    var _workoutSourceText;
    var _workoutSourceBeforeSync;
    var _currentWorkoutIdentity;
    var _currentWorkoutVersion;
    var _activityRecorder;
    var _summarySaveStatus;
    var _firstValidHeartRateLogged;
    var _missingHeartRateLogged;
    var _heartRateMissingSeconds;
    var _latestSensorHeartRate;
    var _latestSensorHeartRateMs;
    var _lastSensorCallbackMs;
    var _lastSensorCallbackHeartRate;
    var _lastActivityInfoHeartRate;
    var _lastSelectedHeartRate;
    var _lastSelectedHeartRateSource;
    var _lastHeartRateStatsMs;
    var _hrSensorCallbackCount;
    var _hrValidSensorSampleCount;
    var _hrMissingSensorSampleCount;
    var _hrInvalidSensorSampleCount;
    var _hrDiagnosticMin;
    var _hrDiagnosticMax;
    var _hrDiagnosticSum;
    var _hrDiagnosticCount;
    var _lastHrDiagnosticLogMs;
    var _lastHrDisagreementLogMs;
    var _lastHrRawLogMs;
    var _lastHrSelectLogMs;
    var _lastHrFitLogMs;
    var _heartRateSensorRequestText;
    var _workoutStartPressedMs;
    var _heartRateMonitoringStartedMs;
    var _firstValidSensorHeartRateMs;
    var _firstValidHeartRateMs;
    var _activityRecordingStartedMs;
    var _finalActiveCalories;
    var _finalNativeDistanceMeters;
    var _exitConfirmPending;
    var _sessionSync;

    function initialize() {
        View.initialize();
        _timer = new Timer.Timer();
        _isRunning = false;
        _startMs = 0;
        _elapsedBeforePause = 0;
        _manualStationIndex = 0;
        _manualRoundNumber = 1;
        _isFinished = false;
        _workout = new GarminWODWorkout();
        _totalSeconds = _workout.getTotalSeconds();
        _heartRateZones = UserProfile.getHeartRateZones2(Activity.SPORT_GENERIC);
        _heartRateSum = 0;
        _heartRateSamples = 0;
        _maxHeartRate = null;
        _stationDistanceStart = null;
        _distanceStationIndex = null;
        _gpsDistanceMeters = 0.0;
        _lastLocation = null;
        _hasGpsFix = false;
        _gpsFixAlerted = false;
        _startPendingForGps = false;
        _startPendingForWorkout = false;
        _isFetchingWorkout = false;
        _hasLoadedInitialWorkout = false;
        _isTimerActive = false;
        _isLocationEventsActive = false;
        _workoutSourceText = "LOADING";
        _workoutSourceBeforeSync = "LOADING";
        _currentWorkoutIdentity = null;
        _currentWorkoutVersion = null;
        _activityRecorder = new GarminWODActivityRecorder();
        _summarySaveStatus = "Not saved";
        _firstValidHeartRateLogged = false;
        _missingHeartRateLogged = false;
        _heartRateMissingSeconds = 0;
        _latestSensorHeartRate = null;
        _latestSensorHeartRateMs = null;
        _lastSensorCallbackMs = null;
        _lastSensorCallbackHeartRate = null;
        _lastActivityInfoHeartRate = null;
        _lastSelectedHeartRate = null;
        _lastSelectedHeartRateSource = "none";
        _lastHeartRateStatsMs = null;
        _hrSensorCallbackCount = 0;
        _hrValidSensorSampleCount = 0;
        _hrMissingSensorSampleCount = 0;
        _hrInvalidSensorSampleCount = 0;
        _hrDiagnosticMin = null;
        _hrDiagnosticMax = null;
        _hrDiagnosticSum = 0;
        _hrDiagnosticCount = 0;
        _lastHrDiagnosticLogMs = null;
        _lastHrDisagreementLogMs = null;
        _lastHrRawLogMs = null;
        _lastHrSelectLogMs = null;
        _lastHrFitLogMs = null;
        _heartRateSensorRequestText = "none";
        _workoutStartPressedMs = null;
        _heartRateMonitoringStartedMs = null;
        _firstValidSensorHeartRateMs = null;
        _firstValidHeartRateMs = null;
        _activityRecordingStartedMs = null;
        _finalActiveCalories = null;
        _finalNativeDistanceMeters = null;
        _exitConfirmPending = false;
        _sessionSync = new GarminWODSessionSync();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        if (!_hasLoadedInitialWorkout) {
            loadCachedWorkout();
            _hasLoadedInitialWorkout = true;
        }

        fetchLatestWorkout();

        if (!_isTimerActive) {
            _timer.start(method(:onTick), 1000, true);
            _isTimerActive = true;
        }

        startLocationEvents();
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var elapsed = getElapsedSeconds();
        var remaining = getRemainingSeconds(elapsed);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, width, height);

        if (!_workout.hasWorkout()) {
            drawWorkoutUnavailableState(dc, width, height);
            return;
        }

        if (_isFinished) {
            drawWorkoutSummary(dc, width, height);
            return;
        }

        if (_exitConfirmPending) {
            drawExitConfirmation(dc, width, height);
            return;
        }

        var stationIndex = getStationIndex(elapsed);
        updateStationDistanceStart(stationIndex);
        var roundNumber = getRoundNumber(elapsed);
        var secondInStation = getSecondInStation(elapsed);
        drawActiveWorkoutScoreboard(dc, width, height, stationIndex, roundNumber, elapsed, remaining, secondInStation);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        if (_isTimerActive) {
            _timer.stop();
            _isTimerActive = false;
        }

        stopLocationEvents();
    }

    function toggleRunning() as Void {
        if (_exitConfirmPending) {
            cancelExitConfirmation();
            return;
        }

        if (_isFinished) {
            if (_activityRecorder.hasSaveFailed()) {
                retrySaveRecordingSession();
            } else {
                resetWorkout();
            }
            return;
        }

        if (!_workout.hasWorkout()) {
            _startPendingForWorkout = true;
            fetchLatestWorkout();
            WatchUi.requestUpdate();
            System.println("GarminWOD startup pending workout load");
            return;
        }

        if (_isRunning) {
            var elapsed = getElapsedSeconds();

            if (!_activityRecorder.pauseRecordingSession()) {
                WatchUi.requestUpdate();
                System.println("GarminWOD startup pause failed state=" + getInputStateText());
                return;
            }

            _elapsedBeforePause = elapsed;
            _isRunning = false;
            publishWorkoutSessionState("paused");
        } else {
            if (_startPendingForGps) {
                System.println("GarminWOD startup ignored; GPS start pending state=" + getInputStateText() +
                    " timer=" + System.getTimer());
                WatchUi.requestUpdate();
                return;
            }

            if (_workoutStartPressedMs == null) {
                _workoutStartPressedMs = System.getTimer();
                System.println("GarminWOD startup startPressedMs=" + _workoutStartPressedMs +
                    " source=" + getStartupWorkoutSourceText() +
                    " header=" + _workout.getHeader(_manualRoundNumber));
            } else {
                System.println("GarminWOD startup resumePressedMs=" + System.getTimer() +
                    " source=" + getStartupWorkoutSourceText() +
                    " originalStartPressedMs=" + _workoutStartPressedMs);
            }

            try {
                enableHeartRateSensor();

                var recordingStarted = startOrResumeRecordingForCurrentState();

                if (!recordingStarted) {
                    rollbackFailedStart("recording start/resume failed");
                    WatchUi.requestUpdate();
                    System.println("GarminWOD startup recording start/resume failed state=" + getInputStateText());
                    return;
                }

                _startMs = System.getTimer();
                if (_activityRecordingStartedMs == null) {
                    _activityRecordingStartedMs = _startMs;
                }
                System.println("GarminWOD startup recordingStartedMs=" + _startMs +
                    " source=" + getStartupWorkoutSourceText() +
                    " startPressedMs=" + getLogValue(_workoutStartPressedMs) +
                    " hrMonitoringStartedMs=" + getLogValue(_heartRateMonitoringStartedMs));
                _lastLocation = null;
                _isRunning = true;
                if (workoutNeedsGps()) {
                    startLocationEvents();
                } else {
                    System.println("GarminWOD startup no GPS required");
                }
                ensureWorkoutSessionSync();
                publishWorkoutSessionState("running");
                _startPendingForGps = false;
            } catch (e) {
                System.println("GarminWOD startup exception=" + getExceptionText(e));
                rollbackFailedStart("start exception");
                WatchUi.requestUpdate();
                return;
            }
        }

        WatchUi.requestUpdate();
    }

    function rollbackFailedStart(reason) as Void {
        System.println("GarminWOD startup rollback reason=" + reason +
            " state=" + getInputStateText() +
            " recordingOpen=" + _activityRecorder.hasOpenSession() +
            " recordingActive=" + _activityRecorder.isRecordingSessionActive());

        if (_activityRecorder.hasOpenSession() && !_activityRecorder.hasSaved()) {
            _activityRecorder.discardRecordingSession();
        }

        disableHeartRateSensor();
        _isRunning = false;
        _startMs = 0;
        _startPendingForGps = false;
        _activityRecordingStartedMs = null;
        System.println("GarminWOD startup rollback complete state=" + getInputStateText() +
            " recordingOpen=" + _activityRecorder.hasOpenSession());
    }

    function startOrResumeRecordingForCurrentState() {
        if (_elapsedBeforePause > 0) {
            return _activityRecorder.resumeRecordingSession();
        }

        if (_activityRecorder.startRecordingSession()) {
            return true;
        }

        System.println("GarminWOD startup first recording start failed; retrying once");
        rollbackFailedStart("first recording start failed before retry");

        enableHeartRateSensor();

        if (_activityRecorder.startRecordingSession()) {
            System.println("GarminWOD startup recording retry succeeded");
            return true;
        }

        System.println("GarminWOD startup recording retry failed");
        return false;
    }

    function completePendingGpsStart() as Void {
        if (!_startPendingForGps) {
            return;
        }

        System.println("GarminWOD startup GPS ready; completing pending start state=" + getInputStateText() +
            " timer=" + System.getTimer() +
            " startPressedMs=" + getLogValue(_workoutStartPressedMs));

        _startPendingForGps = false;

        try {
            toggleRunning();
        } catch (e) {
            System.println("GarminWOD startup GPS pending completion exception=" + getExceptionText(e));
            rollbackFailedStart("gps pending completion exception");
            WatchUi.requestUpdate();
        }
    }

    function completePendingWorkoutStart() as Void {
        if (!_startPendingForWorkout) {
            return;
        }

        System.println("GarminWOD startup workout ready; completing pending start state=" + getInputStateText() +
            " timer=" + System.getTimer() +
            " startPressedMs=" + getLogValue(_workoutStartPressedMs));

        _startPendingForWorkout = false;

        try {
            toggleRunning();
        } catch (e) {
            System.println("GarminWOD startup workout pending completion exception=" + getExceptionText(e));
            rollbackFailedStart("workout pending completion exception");
            WatchUi.requestUpdate();
        }
    }

    function resetWorkout() as Void {
        if (_activityRecorder.hasOpenSession() && !_activityRecorder.hasSaved()) {
            logHeartRateDiagnostics("discard-reset");
            _activityRecorder.discardRecordingSession();
        }

        disableHeartRateSensor();
        _isRunning = false;
        _elapsedBeforePause = 0;
        _startMs = 0;
        _manualStationIndex = 0;
        _manualRoundNumber = 1;
        _isFinished = false;
        _heartRateSum = 0;
        _heartRateSamples = 0;
        _maxHeartRate = null;
        _stationDistanceStart = null;
        _distanceStationIndex = null;
        _gpsDistanceMeters = 0.0;
        _lastLocation = null;
        _hasGpsFix = false;
        _gpsFixAlerted = false;
        _startPendingForGps = false;
        _startPendingForWorkout = false;
        _summarySaveStatus = "Not saved";
        _firstValidHeartRateLogged = false;
        _missingHeartRateLogged = false;
        _heartRateMissingSeconds = 0;
        resetHeartRateDiagnostics();
        _finalActiveCalories = null;
        _finalNativeDistanceMeters = null;
        _exitConfirmPending = false;
        _sessionSync.clearSession();
        WatchUi.requestUpdate();
    }

    function canReplaceWorkout() {
        return !_isRunning && _elapsedBeforePause == 0 && !_isFinished;
    }

    function loadWorkoutData(data) {
        if (!canReplaceWorkout()) {
            return false;
        }

        if (!_workout.loadFromContract(data)) {
            return false;
        }

        _currentWorkoutIdentity = getWorkoutIdentity(data);
        _currentWorkoutVersion = getWorkoutVersion(data);
        _totalSeconds = _workout.getTotalSeconds();
        _manualStationIndex = 0;
        _manualRoundNumber = 1;
        _startMs = 0;
        _elapsedBeforePause = 0;
        _isFinished = false;
        _summarySaveStatus = "Not saved";
        _firstValidHeartRateLogged = false;
        _missingHeartRateLogged = false;
        _heartRateMissingSeconds = 0;
        resetHeartRateDiagnostics();
        _finalActiveCalories = null;
        _finalNativeDistanceMeters = null;
        _exitConfirmPending = false;
        resetStationDistanceStart();

        return true;
    }

    function loadCachedWorkout() as Void {
        var cachedWorkout = Storage.getValue("latestWorkoutV2");
        var cachedSavedAt = Storage.getValue("latestWorkoutV2SavedAt");
        var cachedIdentity = Storage.getValue("latestWorkoutV2Identity");

        System.println("GarminWOD cache exists=" + (cachedWorkout != null) +
            " savedAt=" + getLogValue(cachedSavedAt) +
            " storedIdentity=" + getLogValue(cachedIdentity));

        if (cachedWorkout != null && loadWorkoutData(cachedWorkout)) {
            _workoutSourceText = getCacheSourceText(cachedSavedAt);
            System.println("GarminWOD cache loaded identity=" + _currentWorkoutIdentity +
                " title=" + getWorkoutLogTitle(cachedWorkout) +
                " header=" + _workout.getHeader(_manualRoundNumber));
        } else if (cachedWorkout != null) {
            System.println("GarminWOD cache load failed title=" + getWorkoutLogTitle(cachedWorkout));
            _workoutSourceText = "NO WOD";
        } else {
            System.println("GarminWOD cache missing");
            _workoutSourceText = "NO WOD";
        }
    }

    function fetchLatestWorkout() as Void {
        if (_isFetchingWorkout || !canReplaceWorkout()) {
            return;
        }

        _isFetchingWorkout = true;
        _workoutSourceBeforeSync = _workoutSourceText;
        _workoutSourceText = "SYNC...";

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
            }
        };

        Communications.makeWebRequest(
            "https://garmin-wod.onrender.com/api/latest-workout",
            null,
            options,
            method(:onLatestWorkoutResponse)
        );
    }

    function onLatestWorkoutResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        _isFetchingWorkout = false;
        var incomingIdentity = data instanceof Dictionary ? getWorkoutIdentity(data) : "none";
        var incomingTitle = data instanceof Dictionary ? getWorkoutLogTitle(data) : "none";
        var loadSucceeded = false;
        var storedWorkout = false;

        System.println("GarminWOD web response code=" + responseCode +
            " identity=" + incomingIdentity +
            " title=" + incomingTitle);

        if (responseCode == 200 && data instanceof Dictionary) {
            if (!canReplaceWorkout()) {
                System.println("GarminWOD web ignored; workout no longer replaceable");
                if (_workoutSourceText.equals("SYNC...")) {
                    _workoutSourceText = _workoutSourceBeforeSync;
                }
            } else if (!isValidWorkoutData(data)) {
                System.println("GarminWOD web decode failed; existing workout preserved title=" + incomingTitle);
                _workoutSourceText = _workout.hasWorkout() ? _workoutSourceBeforeSync + " WEB FAIL" : "NO WOD";
            } else if (isIncomingWorkoutUnchanged(data)) {
                System.println("GarminWOD web unchanged; current workout preserved identity=" + incomingIdentity);
                _workoutSourceText = _workoutSourceBeforeSync;
            } else if (isIncomingWorkoutOlder(data)) {
                _workoutSourceText = _workout.hasWorkout() ? _workoutSourceBeforeSync + " WEB OLD" : "NO WOD";
            } else {
                loadSucceeded = loadWorkoutData(data);

                if (loadSucceeded) {
                    storedWorkout = saveLatestWorkoutToCache(data, incomingIdentity);
                    _workoutSourceText = "WEB WOD";
                }
            }
        }

        System.println("GarminWOD web loadSucceeded=" + loadSucceeded +
            " stored=" + storedWorkout +
            " header=" + (_workout.hasWorkout() ? _workout.getHeader(_manualRoundNumber) : "NO WORKOUT"));

        if (responseCode != 200 && _workoutSourceText.equals("SYNC...")) {
            _workoutSourceText = _workout.hasWorkout() ? _workoutSourceBeforeSync + " WEB FAIL" : "NO WOD";
        } else if (!loadSucceeded && _workoutSourceText.equals("SYNC...")) {
            _workoutSourceText = _workoutSourceBeforeSync;
        }

        if (loadSucceeded && _startPendingForWorkout) {
            completePendingWorkoutStart();
            return;
        }

        if (!loadSucceeded && _startPendingForWorkout && !_workout.hasWorkout()) {
            System.println("GarminWOD startup pending workout failed; returning idle");
            _startPendingForWorkout = false;
        }

        WatchUi.requestUpdate();
    }

    function saveLatestWorkoutToCache(data, incomingIdentity) {
        try {
            var savedAt = Time.now().value();
            Storage.setValue("latestWorkoutV2", data);
            Storage.setValue("latestWorkoutV2SavedAt", savedAt);
            Storage.setValue("latestWorkoutV2Identity", incomingIdentity);

            var readBack = Storage.getValue("latestWorkoutV2");
            var readBackIdentity = readBack instanceof Dictionary ? getWorkoutIdentity(readBack) : "none";

            if (!readBackIdentity.equals(incomingIdentity)) {
                System.println("GarminWOD WARNING cache verify mismatch incoming=" +
                    incomingIdentity + " readBack=" + readBackIdentity);
            } else {
                System.println("GarminWOD cache saved savedAt=" + savedAt +
                    " identity=" + incomingIdentity);
            }

            return true;
        } catch (e) {
            System.println("GarminWOD cache save failed: " + getExceptionText(e));
        }

        return false;
    }

    function isIncomingWorkoutUnchanged(data) {
        if (!_workout.hasWorkout() || _currentWorkoutIdentity == null) {
            return false;
        }

        return _currentWorkoutIdentity.equals(getWorkoutIdentity(data));
    }

    function isValidWorkoutData(data) {
        var stations = getDictionaryValue(data, "stations");

        if (!(stations instanceof Array) || stations.size() == 0) {
            return false;
        }

        var candidate = new GarminWODWorkout();
        return candidate.loadFromContract(data);
    }

    function isIncomingWorkoutOlder(data) {
        var incomingVersion = getWorkoutVersion(data);

        if (isVersionOlder(incomingVersion, _currentWorkoutVersion)) {
            System.println("GarminWOD web ignored older workout incomingVersion=" +
                incomingVersion + " currentVersion=" + _currentWorkoutVersion +
                " incomingIdentity=" + getWorkoutIdentity(data) +
                " currentIdentity=" + _currentWorkoutIdentity);
            return true;
        }

        return false;
    }

    function isVersionOlder(incomingVersion, currentVersion) {
        if (incomingVersion == null || currentVersion == null) {
            return false;
        }

        if (incomingVersion instanceof Number && currentVersion instanceof Number) {
            return incomingVersion < currentVersion;
        }

        if (incomingVersion instanceof String && currentVersion instanceof String) {
            return incomingVersion.compareTo(currentVersion) < 0;
        }

        return false;
    }

    function getWorkoutIdentity(data) {
        var fingerprint = getWorkoutFingerprint(data);
        var id = getDictionaryValue(data, "id");
        if (id != null) {
            return "id:" + id + "|fp:" + fingerprint;
        }

        var updatedAt = getDictionaryValue(data, "updatedAt");
        if (updatedAt != null) {
            return "updatedAt:" + updatedAt + "|fp:" + fingerprint;
        }

        var generatedAt = getDictionaryValue(data, "generatedAt");
        if (generatedAt != null) {
            return "generatedAt:" + generatedAt + "|fp:" + fingerprint;
        }

        var timestamp = getDictionaryValue(data, "timestamp");
        if (timestamp != null) {
            return "timestamp:" + timestamp + "|fp:" + fingerprint;
        }

        var title = getDictionaryValue(data, "title");
        if (title != null) {
            return "title:" + title + "|fp:" + fingerprint;
        }

        return "fp:" + fingerprint;
    }

    function getWorkoutVersion(data) {
        var updatedAt = getDictionaryValue(data, "updatedAt");
        if (updatedAt instanceof Number) {
            return updatedAt;
        }
        if (updatedAt instanceof String) {
            return updatedAt;
        }

        var generatedAt = getDictionaryValue(data, "generatedAt");
        if (generatedAt instanceof Number) {
            return generatedAt;
        }
        if (generatedAt instanceof String) {
            return generatedAt;
        }

        var timestamp = getDictionaryValue(data, "timestamp");
        if (timestamp instanceof Number) {
            return timestamp;
        }
        if (timestamp instanceof String) {
            return timestamp;
        }

        var version = getDictionaryValue(data, "version");
        if (version instanceof Number) {
            return version;
        }

        return null;
    }

    function getWorkoutFingerprint(data) {
        var stations = getDictionaryValue(data, "stations");
        var fingerprint = "" + getDictionaryValue(data, "type") +
            "|" + getDictionaryValue(data, "durationMinutes") +
            "|" + getDictionaryValue(data, "rounds");

        if (stations instanceof Array) {
            fingerprint += "|count:" + stations.size();

            for (var i = 0; i < stations.size(); i++) {
                var station = stations[i];

                if (station instanceof Dictionary) {
                    fingerprint += "|" + getDictionaryValue(station, "name") +
                        ":" + getDictionaryValue(station, "reps") +
                        ":" + getDictionaryValue(station, "calories") +
                        ":" + getDictionaryValue(station, "meters") +
                        ":" + getDictionaryValue(station, "weightLb") +
                        ":" + getDictionaryValue(station, "maleWeightLb") +
                        ":" + getDictionaryValue(station, "femaleWeightLb") +
                        ":" + getDictionaryValue(station, "workSeconds");
                }
            }
        }

        return fingerprint;
    }

    function getWorkoutLogTitle(data) {
        var title = getDictionaryValue(data, "title");

        if (title != null) {
            return "" + title;
        }

        return "untitled";
    }

    function getDictionaryValue(data, key) {
        if (data == null) {
            return null;
        }

        return data[key];
    }

    function getLogValue(value) {
        if (value == null) {
            return "null";
        }

        return "" + value;
    }

    function getCacheSourceText(savedAt) {
        if (!(savedAt instanceof Number)) {
            return "CACHE";
        }

        var ageSeconds = Time.now().value() - savedAt;

        if (ageSeconds < 0) {
            return "CACHE";
        }

        if (ageSeconds < 3600) {
            return "CACHE " + (ageSeconds / 60) + "m";
        }

        return "CACHE " + (ageSeconds / 3600) + "h";
    }

    function getWorkoutSourceText() {
        return _workoutSourceText;
    }

    function drawActiveWorkoutScoreboard(dc, width, height, stationIndex, roundNumber, elapsed, remaining, secondInStation) as Void {
        var currentText = _workout.getScoreboardMovementText(stationIndex, roundNumber);
        var currentLines = getMovementDisplayLines(currentText);
        var nextText = getNextMovementText(stationIndex, roundNumber);
        var nextLines = getMovementDisplayLines(nextText);
        var timeText = getCompactWorkoutTimeText(elapsed, remaining, stationIndex, secondInStation);
        var layoutMode = _workout.getWorkoutLayoutMode();
        var topY = height * 13 / 100;
        var currentLineOneY = layoutMode.equals("INTERVAL") ? height * 31 / 100 : height * 33 / 100;
        var currentLineTwoY = layoutMode.equals("INTERVAL") ? height * 43 / 100 : height * 45 / 100;
        var currentDetailY = height * 59 / 100;
        var dividerY = layoutMode.equals("INTERVAL") ? height * 74 / 100 : height * 76 / 100;
        var nextLineOneY = layoutMode.equals("INTERVAL") ? height * 81 / 100 : height * 82 / 100;
        var nextLineTwoY = layoutMode.equals("INTERVAL") ? height * 87 / 100 : height * 88 / 100;
        var bottomY = height * 96 / 100;
        var centerX = width / 2;

        if (!_isRunning && _elapsedBeforePause == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height * 4 / 100, Graphics.FONT_XTINY, getWorkoutSourceText(), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawScoreboardHeader(dc, width, topY, getCompactRoundText(roundNumber));

        if (!_isRunning && _elapsedBeforePause > 0) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height * 14 / 100, Graphics.FONT_XTINY, "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawMovementLines(dc, centerX, currentLineOneY, currentLineTwoY, currentLines, getCurrentMovementFont(currentLines), Graphics.COLOR_WHITE);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, currentDetailY, Graphics.FONT_SMALL, timeText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(width * 18 / 100, dividerY, width * 82 / 100, dividerY);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawMovementLines(dc, centerX, nextLineOneY, nextLineTwoY, nextLines, getNextMovementFont(nextLines), Graphics.COLOR_WHITE);

        var hint = getActiveControlHintText();
        if (hint != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, bottomY, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function getStartupWorkoutSourceText() {
        if (_workoutSourceText.equals("SYNC...")) {
            return _workoutSourceBeforeSync;
        }

        return _workoutSourceText;
    }

    function getCompactRoundText(roundNumber) {
        if (_workout.rounds != null) {
            return "R" + roundNumber + "/" + _workout.rounds;
        }

        if (_workout.isAmrap()) {
            return "R" + roundNumber;
        }

        if (_workout.isManualStationWorkout()) {
            return "S" + (_manualStationIndex + 1) + "/" + _workout.getStationCount();
        }

        return _workout.getHeader(roundNumber);
    }

    function getCompactWorkoutTimeText(elapsed, remaining, stationIndex, secondInStation) {
        if (_workout.isManualStationWorkout() && !_workout.isAmrap()) {
            return formatTime(elapsed);
        }

        if (_workout.isAmrap()) {
            return remaining == null ? formatTime(elapsed) : formatTime(remaining);
        }

        return getStationRemaining(stationIndex, secondInStation);
    }

    function getLiveHeartRateText() {
        var heartRate = getCurrentHeartRate();

        if (heartRate == null) {
            return "--";
        }

        return "" + heartRate;
    }

    function drawScoreboardHeader(dc, width, y, roundText) as Void {
        var hrText = getLiveHeartRateText();
        var headerFont = getScoreboardHeaderFont(dc, width, roundText, hrText);
        var leftX = getScoreboardHeaderLeftX(width);

        dc.drawText(leftX, y, headerFont, roundText, Graphics.TEXT_JUSTIFY_LEFT);
        drawLiveHeartRate(dc, width, y, headerFont, hrText);
    }

    function getScoreboardHeaderFont(dc, width, roundText, hrText) {
        var font = Graphics.FONT_MEDIUM;

        if (scoreboardHeaderOverlaps(dc, width, font, roundText, hrText)) {
            return Graphics.FONT_SMALL;
        }

        return font;
    }

    function scoreboardHeaderOverlaps(dc, width, font, roundText, hrText) {
        var gap = getScoreboardHeaderGap(width);
        var roundRight = getScoreboardHeaderLeftX(width) + getTextWidth(dc, roundText, font);
        var heartMetrics = getHeartRateHeaderMetrics(width);
        var hrLeft = heartMetrics[1] - getTextWidth(dc, hrText, font);

        return roundRight + gap >= hrLeft;
    }

    function getScoreboardHeaderLeftX(width) {
        return width * 18 / 100;
    }

    function getScoreboardHeaderGap(width) {
        var gap = width / 100;

        if (gap < 2) {
            gap = 2;
        }

        return gap;
    }

    function drawLiveHeartRate(dc, width, y, font, hrText) as Void {
        var heartMetrics = getHeartRateHeaderMetrics(width);
        var textRight = heartMetrics[1];
        var heartLeft = heartMetrics[2];

        dc.drawText(textRight, y, font, hrText, Graphics.TEXT_JUSTIFY_RIGHT);
        drawPixelHeart(dc, heartLeft, y + heartMetrics[3], heartMetrics[3]);
    }

    function getHeartRateHeaderMetrics(width) {
        var unit = width / 105;
        if (unit < 2) {
            unit = 2;
        }

        var heartWidth = unit * 7;
        var gap = getScoreboardHeaderGap(width);
        var rightEdge = width * 84 / 100;
        var textRight = rightEdge - heartWidth - gap;

        return [heartWidth, textRight, rightEdge - heartWidth, unit];
    }

    function getTextWidth(dc, text, font) {
        if (dc has :getTextDimensions) {
            var dimensions = dc.getTextDimensions(text, font);

            if (dimensions != null && dimensions.size() > 0) {
                return dimensions[0];
            }
        }

        return text.length() * 11;
    }

    function drawPixelHeart(dc, left, top, unit) as Void {
        dc.fillRectangle(left + unit, top, unit * 2, unit);
        dc.fillRectangle(left + (unit * 4), top, unit * 2, unit);
        dc.fillRectangle(left, top + unit, unit * 7, unit);
        dc.fillRectangle(left, top + (unit * 2), unit * 7, unit);
        dc.fillRectangle(left + unit, top + (unit * 3), unit * 5, unit);
        dc.fillRectangle(left + (unit * 2), top + (unit * 4), unit * 3, unit);
        dc.fillRectangle(left + (unit * 3), top + (unit * 5), unit, unit);
    }

    function getActiveControlHintText() {
        if (_isRunning) {
            return null;
        }

        if (_elapsedBeforePause > 0) {
            return "START resume";
        }

        return "START start";
    }

    function getNextMovementText(stationIndex, roundNumber) {
        if (stationIndex >= _workout.getStationCount() - 1) {
            if (shouldContinueManualRoundFlow()) {
                return getPreviewStationText(0, roundNumber + 1);
            }

            return "Last station";
        }

        return getPreviewStationText(stationIndex + 1, roundNumber);
    }

    function getPreviewStationText(stationIndex, roundNumber) {
        if (!_workout.hasValidStationIndex(stationIndex)) {
            return "NO WORKOUT";
        }

        return _workout.getScoreboardMovementText(stationIndex, roundNumber);
    }

    function getMovementDisplayLines(text) {
        var words = getMovementDisplayWords(text);
        var formatted = joinWords(words, 0, words.size());
        var firstLine = "";
        var secondLine = "";

        if (words.size() <= 1) {
            return [formatted];
        }

        if (words.size() == 2) {
            return [words[0], words[1]];
        }

        if (isNumericDisplayWord(words[0])) {
            if (isUnitDisplayWord(words[1])) {
                return [joinWords(words, 0, 2), joinWords(words, 2, words.size())];
            }

            return [words[0], joinWords(words, 1, words.size())];
        }

        var totalLength = formatted.length();
        var bestIndex = 1;
        var bestBalance = totalLength;

        for (var i = 1; i < words.size(); i++) {
            var before = joinWords(words, 0, i);
            var after = joinWords(words, i, words.size());
            var balance = before.length() - after.length();

            if (balance < 0) {
                balance = -balance;
            }

            if (balance < bestBalance) {
                bestBalance = balance;
                bestIndex = i;
            }
        }

        firstLine = joinWords(words, 0, bestIndex);
        secondLine = joinWords(words, bestIndex, words.size());

        return [firstLine, secondLine];
    }

    function isNumericDisplayWord(word) {
        if (word == null || word.length() == 0) {
            return false;
        }

        var hasDigit = false;

        for (var i = 0; i < word.length(); i++) {
            var character = word.substring(i, i + 1);
            var isAllowed = false;

            if (character.compareTo("0") >= 0 && character.compareTo("9") <= 0) {
                hasDigit = true;
                isAllowed = true;
            }

            if (character.equals("/") || character.equals("-") || character.equals(".")) {
                isAllowed = true;
            }

            if (character.equals("M")) {
                isAllowed = true;
            }

            if (!isAllowed) {
                return false;
            }
        }

        return hasDigit;
    }

    function isUnitDisplayWord(word) {
        return word != null && (word.equals("CAL") || word.equals("LB") || word.equals("LBS") || word.equals("M") || word.equals("SEC"));
    }

    function getMovementDisplayWords(text) {
        var source = ("" + text).toUpper();
        var words = [];
        var current = "";

        for (var i = 0; i < source.length(); i++) {
            var character = source.substring(i, i + 1);

            if (character.equals(" ") || character.equals("@")) {
                addMovementDisplayWord(words, current);
                current = "";
            } else {
                current += character;
            }
        }

        addMovementDisplayWord(words, current);

        if (words.size() == 0) {
            words.add("NO WORKOUT");
        }

        return words;
    }

    function addMovementDisplayWord(words, word) as Void {
        if (word == null || word.length() == 0) {
            return;
        }

        if (word.equals("CALORIE") || word.equals("CALORIES")) {
            words.add("CAL");
            return;
        }

        if (word.equals("DUMBBELL") || word.equals("DUMBBELLS")) {
            words.add("DB");
            return;
        }

        if (word.equals("KETTLEBELL") || word.equals("KETTLEBELLS")) {
            words.add("KB");
            return;
        }

        words.add(word);
    }

    function joinWords(words, startIndex, endIndex) {
        var result = "";

        for (var i = startIndex; i < endIndex; i++) {
            if (result.length() > 0) {
                result += " ";
            }

            result += words[i];
        }

        return result;
    }

    function drawMovementLines(dc, x, firstY, secondY, lines, font, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        if (lines.size() == 1) {
            dc.drawText(x, (firstY + secondY) / 2, font, lines[0], Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.drawText(x, firstY, font, lines[0], Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x, secondY, font, lines[1], Graphics.TEXT_JUSTIFY_CENTER);
    }

    function getCurrentMovementFont(lines) {
        var longest = getLongestLineLength(lines);

        if (longest <= 12) {
            return Graphics.FONT_MEDIUM;
        }

        return Graphics.FONT_SMALL;
    }

    function getNextMovementFont(lines) {
        return Graphics.FONT_XTINY;
    }

    function getLongestLineLength(lines) {
        var longest = 0;

        for (var i = 0; i < lines.size(); i++) {
            if (lines[i].length() > longest) {
                longest = lines[i].length();
            }
        }

        return longest;
    }

    function getCurrentMovementDetail(stationIndex) {
        return null;
    }

    function getUsefulStationDetail(stationIndex) {
        var details = [];
        var stationText = normalizeDetailComparisonText(_workout.getStationText(stationIndex));
        var reps = _workout.stationReps[stationIndex];
        var calories = _workout.stationCalories[stationIndex];
        var meters = _workout.stationMeters[stationIndex];
        var weight = _workout.stationWeights[stationIndex];
        var seconds = _workout.stationSeconds[stationIndex];

        if (reps != null && !containsText(stationText, "" + reps)) {
            details.add(reps + " REPS");
        }

        if (calories != null && !containsText(stationText, "" + calories)) {
            details.add(calories + " CAL");
        }

        if (meters != null && !containsText(stationText, "" + meters)) {
            details.add(meters + " M");
        }

        if (weight != null && !containsText(stationText, "" + weight)) {
            details.add(weight + " LB");
        }

        if (seconds != null) {
            details.add(seconds + " SEC");
        }

        if (details.size() == 0) {
            return null;
        }

        return joinWordsWithSeparator(details, " / ");
    }

    function containsText(text, needle) {
        var index = text.find(needle);
        return index != null && index >= 0;
    }

    function normalizeDetailComparisonText(text) {
        var source = ("" + text).toLower();
        var normalized = "";

        for (var i = 0; i < source.length(); i++) {
            var character = source.substring(i, i + 1);

            if (character.equals("@")) {
                normalized += " ";
            } else {
                normalized += character;
            }
        }

        return normalized;
    }

    function joinWordsWithSeparator(words, separator) {
        var result = "";

        for (var i = 0; i < words.size(); i++) {
            if (result.length() > 0) {
                result += separator;
            }

            result += words[i];
        }

        return result;
    }

    function nextStation() as Void {
        if (!_workout.hasWorkout()) {
            return;
        }

        if (!_workout.isManualStationWorkout()) {
            return;
        }

        if (_manualStationIndex < _workout.getStationCount() - 1) {
            _manualStationIndex++;
            resetStationDistanceStart();
            vibrateMovementAdvance();
        } else if (shouldContinueManualRoundFlow()) {
            _manualRoundNumber++;
            _manualStationIndex = 0;
            resetStationDistanceStart();
            vibrateRoundComplete();
        } else {
            finishWorkout();
            return;
        }

        WatchUi.requestUpdate();
        publishWorkoutSessionState("running");
    }

    function previousStation() as Void {
        if (!_workout.hasWorkout()) {
            return;
        }

        if (!_workout.isManualStationWorkout()) {
            return;
        }

        if (_manualStationIndex > 0) {
            _manualStationIndex--;
            resetStationDistanceStart();
        } else if (_manualRoundNumber > 1) {
            _manualRoundNumber--;
            _manualStationIndex = _workout.getStationCount() - 1;
            resetStationDistanceStart();
        }

        WatchUi.requestUpdate();
        publishWorkoutSessionState(_isRunning ? "running" : "paused");
    }

    function hasMoreManualRounds() {
        return _workout.rounds != null && _manualRoundNumber < _workout.rounds;
    }

    function shouldContinueManualRoundFlow() {
        if (hasMoreManualRounds()) {
            return true;
        }

        if (!_workout.isAmrap()) {
            return false;
        }

        if (_totalSeconds == null) {
            return true;
        }

        return getRemainingSeconds(getElapsedSeconds()) > 0;
    }

    function handleBackButton() as Void {
        if (_exitConfirmPending) {
            confirmDiscardAndExit();
            return;
        }

        if (_isFinished && _activityRecorder.hasSaveFailed()) {
            disableHeartRateSensor();
            resetWorkout();
            return;
        }

        if (_isFinished) {
            exitApp();
            return;
        }

        if (!_isRunning && _elapsedBeforePause == 0) {
            exitApp();
            return;
        }

        if (_workout.isManualStationWorkout()) {
            if (!_isRunning) {
                resetWorkout();
                return;
            }

            nextStation();
            return;
        }

        resetWorkout();
    }

    function handlePageNavigation() as Void {
        // Reserved for future metric pages. For now, consume scroll buttons safely.
        WatchUi.requestUpdate();
    }

    function handleMenuButton() as Void {
        // Consume menu/light behavior so it cannot silently exit or discard a workout.
        WatchUi.requestUpdate();
    }

    function vibrateMovementAdvance() as Void {
        vibrateProgression([
            new Attention.VibeProfile(80, 140)
        ], "movement");
    }

    function vibrateRoundComplete() as Void {
        vibrateProgression([
            new Attention.VibeProfile(80, 140),
            new Attention.VibeProfile(0, 80),
            new Attention.VibeProfile(80, 140)
        ], "round");
    }

    function vibrateWorkoutComplete() as Void {
        vibrateProgression([
            new Attention.VibeProfile(100, 300),
            new Attention.VibeProfile(0, 100),
            new Attention.VibeProfile(100, 300)
        ], "complete");
    }

    function vibrateProgression(pattern, label) as Void {
        if (!(Attention has :vibrate)) {
            System.println("GarminWOD haptic unavailable label=" + label);
            return;
        }

        try {
            Attention.vibrate(pattern);
            System.println("GarminWOD haptic label=" + label);
        } catch (e) {
            System.println("GarminWOD haptic failed label=" + label + ": " + getExceptionText(e));
        }
    }

    function getInputStateText() {
        if (_isFinished) {
            if (_activityRecorder.hasSaveFailed()) {
                return "finished-save-failed";
            }

            return "finished-saved";
        }

        if (_isRunning) {
            return "running";
        }

        if (_elapsedBeforePause > 0) {
            return "paused";
        }

        return "idle";
    }

    function finishWorkout() as Void {
        updateHeartRateStats();
        _elapsedBeforePause = getElapsedSeconds();
        _isRunning = false;
        captureFinalSummaryMetrics();
        logHeartRateDiagnostics("finish");
        var saved = _activityRecorder.stopAndSaveRecordingSession();
        _summarySaveStatus = saved ? "Saved to Garmin" : "Save failed";
        if (saved) {
            disableHeartRateSensor();
        }
        _isFinished = true;
        vibrateWorkoutComplete();
        publishWorkoutSessionState("finished");
        WatchUi.requestUpdate();
    }

    function ensureWorkoutSessionSync() as Void {
        if (!_sessionSync.hasSession()) {
            _sessionSync.startSession(_currentWorkoutIdentity);
        }
    }

    function publishWorkoutSessionState(status) as Void {
        if (!_sessionSync.hasSession()) {
            System.println("GarminWOD sync no active session for status=" + status);
            return;
        }

        _sessionSync.publish(
            status,
            _manualRoundNumber,
            _manualStationIndex,
            getElapsedSeconds()
        );
    }

    function retrySaveRecordingSession() as Void {
        if (!_activityRecorder.hasOpenSession()) {
            _summarySaveStatus = "Save failed";
            WatchUi.requestUpdate();
            return;
        }

        var saved = _activityRecorder.stopAndSaveRecordingSession();
        _summarySaveStatus = saved ? "Saved to Garmin" : "Save failed";
        if (saved) {
            disableHeartRateSensor();
        }
        WatchUi.requestUpdate();
    }

    function cleanupBeforeExit() as Void {
        if (_activityRecorder.hasOpenSession() && !_activityRecorder.hasSaved()) {
            logHeartRateDiagnostics("discard-exit");
            _activityRecorder.discardRecordingSession();
        }
        disableHeartRateSensor();
        _sessionSync.clearSession();
    }

    function exitApp() as Void {
        if (_exitConfirmPending) {
            confirmDiscardAndExit();
            return;
        }

        if (_activityRecorder.hasOpenSession() && !_activityRecorder.hasSaved()) {
            _exitConfirmPending = true;
            WatchUi.requestUpdate();
            return;
        }

        cleanupBeforeExit();
        System.exit();
    }

    function confirmDiscardAndExit() as Void {
        cleanupBeforeExit();
        System.exit();
    }

    function cancelExitConfirmation() as Void {
        _exitConfirmPending = false;
        WatchUi.requestUpdate();
    }

    function enableHeartRateSensor() as Void {
        try {
            var requestedSensors = getHeartRateSensorTypes();
            _heartRateSensorRequestText = getHeartRateSensorRequestText(requestedSensors);
            var enabledSensors = Sensor.setEnabledSensors(requestedSensors);
            Sensor.enableSensorEvents(method(:onSensor));
            if (_heartRateMonitoringStartedMs == null) {
                _heartRateMonitoringStartedMs = System.getTimer();
            }
            System.println("GarminWOD: heart rate sensor enabled requested=" +
                _heartRateSensorRequestText +
                " enabled=" + getLogValue(enabledSensors) +
                " onboardSupported=" + (Sensor has :SENSOR_ONBOARD_HEARTRATE) +
                " hrMonitoringStartedMs=" + _heartRateMonitoringStartedMs +
                " source=" + getStartupWorkoutSourceText() +
                " startPressedMs=" + getLogValue(_workoutStartPressedMs));
        } catch (e) {
            System.println("GarminWOD: heart rate sensor enable failed: " + getExceptionText(e));
        }
    }

    function getHeartRateSensorTypes() {
        var sensors = [Sensor.SENSOR_HEARTRATE];

        if (Sensor has :SENSOR_ONBOARD_HEARTRATE) {
            sensors.add(Sensor.SENSOR_ONBOARD_HEARTRATE);
        }

        return sensors;
    }

    function getHeartRateSensorRequestText(sensors) {
        var text = "";

        for (var i = 0; i < sensors.size(); i++) {
            if (text.length() > 0) {
                text += ",";
            }

            if ((Sensor has :SENSOR_ONBOARD_HEARTRATE) && sensors[i] == Sensor.SENSOR_ONBOARD_HEARTRATE) {
                text += "onboard";
            } else if (sensors[i] == Sensor.SENSOR_HEARTRATE) {
                text += "remote";
            } else {
                text += "" + sensors[i];
            }
        }

        return text;
    }

    function disableHeartRateSensor() as Void {
        try {
            Sensor.enableSensorEvents(null);
            Sensor.setEnabledSensors([]);
            System.println("GarminWOD: heart rate sensor disabled");
        } catch (e) {
            System.println("GarminWOD: heart rate sensor disable failed: " + getExceptionText(e));
        }
    }

    function onSensor(sensorInfo as Sensor.Info) as Void {
        _hrSensorCallbackCount++;
        _lastSensorCallbackMs = System.getTimer();

        if (sensorInfo == null || !(sensorInfo has :heartRate) || sensorInfo.heartRate == null) {
            _hrMissingSensorSampleCount++;
            _lastSensorCallbackHeartRate = null;
            maybeLogHeartRateRaw(_lastSensorCallbackMs, null, "missing");
            return;
        }

        var heartRate = sensorInfo.heartRate;
        _lastSensorCallbackHeartRate = heartRate;

        if (isValidHeartRate(heartRate)) {
            _latestSensorHeartRate = heartRate;
            _latestSensorHeartRateMs = _lastSensorCallbackMs;
            _hrValidSensorSampleCount++;

            if (_firstValidSensorHeartRateMs == null) {
                _firstValidSensorHeartRateMs = _lastSensorCallbackMs;
                System.println("GarminWOD startup firstValidSensorHrMs=" + _firstValidSensorHeartRateMs +
                    " hr=" + heartRate +
                    " source=" + getStartupWorkoutSourceText() +
                    " startPressedMs=" + getLogValue(_workoutStartPressedMs) +
                    " hrMonitoringStartedMs=" + getLogValue(_heartRateMonitoringStartedMs) +
                    " recordingStartedMs=" + getLogValue(_activityRecordingStartedMs));
            }

            updateHeartRateDiagnosticStats(heartRate);
            maybeLogHeartRateRaw(_lastSensorCallbackMs, heartRate, "valid");
        } else {
            _hrInvalidSensorSampleCount++;
            maybeLogHeartRateRaw(_lastSensorCallbackMs, heartRate, "invalid");
        }
    }

    function isValidHeartRate(heartRate) {
        return heartRate != null && heartRate >= 30 && heartRate <= 250;
    }

    function resetHeartRateDiagnostics() as Void {
        _latestSensorHeartRate = null;
        _latestSensorHeartRateMs = null;
        _lastSensorCallbackMs = null;
        _lastSensorCallbackHeartRate = null;
        _lastActivityInfoHeartRate = null;
        _lastSelectedHeartRate = null;
        _lastSelectedHeartRateSource = "none";
        _lastHeartRateStatsMs = null;
        _hrSensorCallbackCount = 0;
        _hrValidSensorSampleCount = 0;
        _hrMissingSensorSampleCount = 0;
        _hrInvalidSensorSampleCount = 0;
        _hrDiagnosticMin = null;
        _hrDiagnosticMax = null;
        _hrDiagnosticSum = 0;
        _hrDiagnosticCount = 0;
        _lastHrDiagnosticLogMs = null;
        _lastHrDisagreementLogMs = null;
        _lastHrRawLogMs = null;
        _lastHrSelectLogMs = null;
        _lastHrFitLogMs = null;
        _heartRateSensorRequestText = "none";
        _workoutStartPressedMs = null;
        _heartRateMonitoringStartedMs = null;
        _firstValidSensorHeartRateMs = null;
        _firstValidHeartRateMs = null;
        _activityRecordingStartedMs = null;
    }

    function getLatestSensorHeartRateAgeMs(now) {
        if (_latestSensorHeartRateMs == null) {
            return null;
        }

        return now - _latestSensorHeartRateMs;
    }

    function updateHeartRateDiagnosticStats(heartRate) as Void {
        if (_hrDiagnosticMin == null || heartRate < _hrDiagnosticMin) {
            _hrDiagnosticMin = heartRate;
        }

        if (_hrDiagnosticMax == null || heartRate > _hrDiagnosticMax) {
            _hrDiagnosticMax = heartRate;
        }

        _hrDiagnosticSum += heartRate;
        _hrDiagnosticCount++;
    }

    function maybeLogStaleSensorHeartRate(now, sensorAgeMs, activityHeartRate) as Void {
        if (_lastHrDiagnosticLogMs != null && now - _lastHrDiagnosticLogMs < 15000) {
            return;
        }

        System.println("GarminWOD HR stale sensor=" + getLogValue(_latestSensorHeartRate) +
            " ageMs=" + getLogValue(sensorAgeMs) +
            " activity=" + getLogValue(activityHeartRate));
        _lastHrDiagnosticLogMs = now;
    }

    function maybeLogHeartRateComparison(now, sensorAgeMs, activityHeartRate) as Void {
        if (_latestSensorHeartRate == null || activityHeartRate == null) {
            return;
        }

        var difference = _latestSensorHeartRate - activityHeartRate;

        if (difference < 0) {
            difference = -difference;
        }

        if (difference <= 15) {
            return;
        }

        if (_lastHrDisagreementLogMs != null && now - _lastHrDisagreementLogMs < 15000) {
            return;
        }

        _lastHrDisagreementLogMs = now;
        System.println("GarminWOD HR source disagreement sensor=" + _latestSensorHeartRate +
            " ageMs=" + getLogValue(sensorAgeMs) +
            " activity=" + activityHeartRate +
            " selected=" + getLogValue(_lastSelectedHeartRate) +
            " source=" + _lastSelectedHeartRateSource);
    }

    function maybeLogHeartRateRaw(now, heartRate, status) as Void {
        if (_lastHrRawLogMs != null && now - _lastHrRawLogMs < 15000 && status.equals("valid")) {
            return;
        }

        _lastHrRawLogMs = now;
        System.println("GarminWOD HR RAW t=" + now +
            " bpm=" + getLogValue(heartRate) +
            " source=Sensor.Info.heartRate" +
            " validity=" + status +
            " requested=" + _heartRateSensorRequestText +
            " recording=" + _activityRecorder.isRecordingSessionActive());
    }

    function maybeLogHeartRateSelect(now, selection) as Void {
        var status = selection[:status];

        if (_lastHrSelectLogMs != null && now - _lastHrSelectLogMs < 15000 && status.equals("fresh")) {
            return;
        }

        _lastHrSelectLogMs = now;
        System.println("GarminWOD HR SELECT t=" + now +
            " bpm=" + getLogValue(selection[:heartRate]) +
            " ageMs=" + getLogValue(selection[:ageMs]) +
            " status=" + status +
            " source=" + selection[:source] +
            " activity=" + getLogValue(selection[:activityHeartRate]) +
            " recording=" + _activityRecorder.isRecordingSessionActive());
    }

    function maybeLogHeartRateFit(now, selection) as Void {
        var status = selection[:status];

        if (_lastHrFitLogMs != null && now - _lastHrFitLogMs < 15000 && status.equals("fresh")) {
            return;
        }

        _lastHrFitLogMs = now;
        System.println("GarminWOD HR FIT t=" + now +
            " appBpm=" + getLogValue(selection[:heartRate]) +
            " mode=garmin-native" +
            " manual=false" +
            " appStatus=" + status +
            " requested=" + _heartRateSensorRequestText);
    }

    function maybeLogHeartRateDiagnostics(now) as Void {
        if (_lastHrDiagnosticLogMs != null && now - _lastHrDiagnosticLogMs < 15000) {
            return;
        }

        _lastHrDiagnosticLogMs = now;
        logHeartRateDiagnostics("active");
    }

    function logHeartRateDiagnostics(label) as Void {
        var now = System.getTimer();
        var sensorAgeMs = getLatestSensorHeartRateAgeMs(now);
        var diagnosticAverage = null;

        if (_hrDiagnosticCount > 0) {
            diagnosticAverage = _hrDiagnosticSum / _hrDiagnosticCount;
        }

        System.println("GarminWOD HR diag " + label +
            " callbacks=" + _hrSensorCallbackCount +
            " valid=" + _hrValidSensorSampleCount +
            " missing=" + _hrMissingSensorSampleCount +
            " invalid=" + _hrInvalidSensorSampleCount +
            " sensor=" + getLogValue(_latestSensorHeartRate) +
            " sensorAgeMs=" + getLogValue(sensorAgeMs) +
            " callbackHr=" + getLogValue(_lastSensorCallbackHeartRate) +
            " activity=" + getLogValue(_lastActivityInfoHeartRate) +
            " selected=" + getLogValue(_lastSelectedHeartRate) +
            " source=" + _lastSelectedHeartRateSource +
            " requested=" + _heartRateSensorRequestText +
            " workoutSource=" + getStartupWorkoutSourceText() +
            " startPressedMs=" + getLogValue(_workoutStartPressedMs) +
            " hrMonitoringStartedMs=" + getLogValue(_heartRateMonitoringStartedMs) +
            " firstValidSensorHrMs=" + getLogValue(_firstValidSensorHeartRateMs) +
            " firstValidSelectedHrMs=" + getLogValue(_firstValidHeartRateMs) +
            " recordingStartedMs=" + getLogValue(_activityRecordingStartedMs) +
            " recording=" + _activityRecorder.isRecordingSessionActive() +
            " min=" + getLogValue(_hrDiagnosticMin) +
            " max=" + getLogValue(_hrDiagnosticMax) +
            " avg=" + getLogValue(diagnosticAverage));
    }

    function captureFinalSummaryMetrics() as Void {
        var info = Activity.getActivityInfo();

        _finalActiveCalories = null;
        _finalNativeDistanceMeters = null;

        if (info has :calories && info.calories != null) {
            _finalActiveCalories = info.calories;
        }

        if (workoutNeedsGps() && info has :elapsedDistance && info.elapsedDistance != null) {
            _finalNativeDistanceMeters = info.elapsedDistance;
        }
    }

    function getExceptionText(exception) {
        if (exception == null) {
            return "Unknown exception";
        }

        var message = exception.getErrorMessage();

        if (message == null) {
            message = exception.toString();
        }

        return message;
    }

    function onTick() as Void {
        if (_isRunning) {
            updateHeartRateStats();

            if (_workout.isAmrap() && _totalSeconds != null && getElapsedSeconds() >= _totalSeconds) {
                finishWorkout();
                return;
            }
        }

        WatchUi.requestUpdate();
    }

    function getElapsedSeconds() {
        if (!_isRunning) {
            return _elapsedBeforePause;
        }

        return _elapsedBeforePause + ((System.getTimer() - _startMs) / 1000);
    }

    function formatTime(seconds) {
        var minutes = seconds / 60;
        var secs = seconds % 60;
        var secsText = secs < 10 ? "0" + secs : "" + secs;

        return minutes + ":" + secsText;
    }

    function getRemainingSeconds(elapsed) {
        if (_totalSeconds == null) {
            return null;
        }

        var remaining = _totalSeconds - elapsed;
        return remaining < 0 ? 0 : remaining;
    }

    function getStationIndex(elapsed) {
        if (_workout.isEmom()) {
            return (elapsed / 60) % _workout.getStationCount();
        }

        return _manualStationIndex;
    }

    function getRoundNumber(elapsed) {
        if (_workout.isEmom()) {
            return (elapsed / (60 * _workout.getStationCount())) + 1;
        }

        if (_workout.isManualStationWorkout()) {
            return _manualRoundNumber;
        }

        return 1;
    }

    function getSecondInStation(elapsed) {
        if (_workout.isEmom()) {
            return elapsed % 60;
        }

        return elapsed;
    }

    function getStationRemaining(stationIndex, secondInStation) {
        if (_workout.isManualStationWorkout() && !_workout.isAmrap()) {
            if (_isFinished) {
                return "Finished";
            }

            return formatTime(getElapsedSeconds());
        }

        if (_workout.isAmrap()) {
            if (getRemainingSeconds(getElapsedSeconds()) == 0) {
                return "Finished";
            }

            return formatTime(getRemainingSeconds(getElapsedSeconds()));
        }

        var stationSeconds = _workout.getStationWorkSeconds(stationIndex);

        if (stationSeconds != null && secondInStation < stationSeconds) {
            return (stationSeconds - secondInStation) + "s";
        }

        return (60 - secondInStation) + "s";
    }

    function getStationLabel(stationIndex, secondInStation) {
        if (_workout.isManualStationWorkout()) {
            if (_isFinished) {
                return "Done";
            }

            if (_workout.rounds != null) {
                return "R" + _manualRoundNumber + "/" + _workout.rounds + "  S" + (stationIndex + 1) + "/" + _workout.getStationCount();
            }

            if (_workout.isAmrap()) {
                return "R" + _manualRoundNumber + "  S" + (stationIndex + 1) + "/" + _workout.getStationCount();
            }

            return "Station " + (stationIndex + 1) + "/" + _workout.getStationCount();
        }

        var stationSeconds = _workout.getStationWorkSeconds(stationIndex);

        if (stationSeconds != null && secondInStation < stationSeconds) {
            if (stationIndex == 0) {
                return "Work time";
            }

            return "Station time";
        }

        return "Transition";
    }

    function getContextText(stationIndex, elapsed, remaining) {
        if (_workout.isManualStationWorkout()) {
            if (shouldWaitForGpsBeforeStart()) {
                return "GPS acquiring";
            }

            var distanceText = getDistanceProgressText(stationIndex);

            if (distanceText != null) {
                return distanceText;
            }

            return getNextStationText(stationIndex);
        }

        if (remaining == null) {
            return "Total --:--";
        }

        return "Total " + formatTime(remaining);
    }

    function getNextStationText(stationIndex) {
        if (_isFinished) {
            return "Workout complete";
        }

        if (stationIndex >= _workout.getStationCount() - 1) {
            if (shouldContinueManualRoundFlow()) {
                return "Next: " + _workout.getStationText(0);
            }

            return "Last station";
        }

        return "Next: " + _workout.getStationText(stationIndex + 1);
    }

    function getStatusText() {
        if (_isFinished) {
            if (_activityRecorder.hasSaveFailed()) {
                return "START retry";
            }

            return "BACK exit";
        }

        if (_isRunning) {
            if (_workout.isManualStationWorkout()) {
                if (_manualStationIndex >= _workout.getStationCount() - 1) {
                    return "START pause";
                }

                return "START pause";
            }

            return "START pause";
        }

        if (_elapsedBeforePause > 0) {
            return "START resume";
        }

        return "START start";
    }

    function getSecondaryStatusText() {
        if (_isFinished) {
            return "";
        }

        if (_workout.isManualStationWorkout()) {
            if (!_isRunning && _elapsedBeforePause > 0) {
                return "BACK reset";
            }

            if (_manualStationIndex >= _workout.getStationCount() - 1 && !shouldContinueManualRoundFlow()) {
                return "BACK finish";
            }

            return "BACK next";
        }

        return "";
    }

    function getControlHintText() {
        if (_isFinished) {
            if (_activityRecorder.hasSaveFailed()) {
                return "START retry  BACK discard";
            }

            return "START reset  BACK exit";
        }

        if (!_workout.isManualStationWorkout()) {
            return getStatusText();
        }

        if (_isRunning) {
            if (_manualStationIndex >= _workout.getStationCount() - 1 && !shouldContinueManualRoundFlow()) {
                return "START pause  BACK finish";
            }

            return "START pause  BACK next";
        }

        if (_elapsedBeforePause > 0) {
            return "START resume  BACK reset";
        }

        return "START start";
    }

    function drawWorkoutUnavailableState(dc, width, height) as Void {
        var sourceY = height * 8 / 100;
        var titleY = height * 32 / 100;
        var detailY = height * 49 / 100;
        var actionY = height * 72 / 100;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, sourceY, Graphics.FONT_XTINY, getWorkoutSourceText(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (_isFetchingWorkout || _workoutSourceText.equals("SYNC...") || _workoutSourceText.equals("LOADING")) {
            dc.drawText(width / 2, titleY, Graphics.FONT_XTINY, "LOADING WORKOUT", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, detailY, Graphics.FONT_XTINY, "Checking web WOD", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(width / 2, titleY, Graphics.FONT_XTINY, "NO WORKOUT LOADED", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, detailY, Graphics.FONT_XTINY, "Refresh to load WOD", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, actionY, Graphics.FONT_XTINY, "START refresh  BACK exit", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function shouldWaitForGpsBeforeStart() {
        return false;
    }

    function workoutNeedsGps() {
        for (var i = 0; i < _workout.getStationCount(); i++) {
            if (stationNeedsGps(i)) {
                return true;
            }
        }

        return false;
    }

    function stationNeedsGps(stationIndex) {
        if (_workout.getStationMeters(stationIndex) == null) {
            return false;
        }

        var name = normalizeDetailComparisonText(_workout.stationNames[stationIndex]);

        return containsText(name, "run") ||
            containsText(name, "walk") ||
            containsText(name, "ruck");
    }

    function startLocationEvents() as Void {
        if (_isLocationEventsActive) {
            return;
        }

        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        _isLocationEventsActive = true;
    }

    function stopLocationEvents() as Void {
        if (!_isLocationEventsActive) {
            return;
        }

        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        _isLocationEventsActive = false;
    }

    function onPosition(info as Position.Info) as Void {
        if (info == null || !(info has :position) || info.position == null) {
            return;
        }

        var currentLocation = info.position;

        if (!_hasGpsFix) {
            _hasGpsFix = true;
            alertGpsAcquired();
            completePendingGpsStart();
        }

        if (_isRunning && _lastLocation != null) {
            var segmentMeters = getDistanceBetweenLocations(_lastLocation, currentLocation);

            if (segmentMeters > 0 && segmentMeters < 100) {
                _gpsDistanceMeters += segmentMeters;
            }
        }

        _lastLocation = currentLocation;
        WatchUi.requestUpdate();
    }

    function alertGpsAcquired() as Void {
        if (_gpsFixAlerted) {
            return;
        }

        _gpsFixAlerted = true;

        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(80, 180),
                new Attention.VibeProfile(0, 90),
                new Attention.VibeProfile(80, 180)
            ]);
        }
    }

    function getDistanceBetweenLocations(fromLocation, toLocation) {
        var fromDegrees = fromLocation.toDegrees();
        var toDegrees = toLocation.toDegrees();

        var lat1 = Math.toRadians(fromDegrees[0]);
        var lon1 = Math.toRadians(fromDegrees[1]);
        var lat2 = Math.toRadians(toDegrees[0]);
        var lon2 = Math.toRadians(toDegrees[1]);
        var deltaLat = lat2 - lat1;
        var deltaLon = lon2 - lon1;
        var sinLat = Math.sin(deltaLat / 2.0);
        var sinLon = Math.sin(deltaLon / 2.0);
        var a = (sinLat * sinLat) + (Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon);
        var c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));

        return 6371000.0 * c;
    }

    function resetStationDistanceStart() as Void {
        _stationDistanceStart = null;
        _distanceStationIndex = null;
    }

    function updateStationDistanceStart(stationIndex) as Void {
        if (_workout.getStationMeters(stationIndex) == null) {
            resetStationDistanceStart();
            return;
        }

        if (_distanceStationIndex == stationIndex && _stationDistanceStart != null) {
            return;
        }

        var currentDistance = getCurrentDistanceMeters();

        if (currentDistance == null) {
            return;
        }

        _stationDistanceStart = currentDistance;
        _distanceStationIndex = stationIndex;
    }

    function getDistanceProgressText(stationIndex) {
        var targetMeters = _workout.getStationMeters(stationIndex);

        if (targetMeters == null) {
            return null;
        }

        var currentDistance = getCurrentDistanceMeters();

        if (currentDistance == null || _stationDistanceStart == null) {
            return null;
        }

        var stationMeters = (currentDistance - _stationDistanceStart).toNumber();

        if (stationMeters < 0) {
            stationMeters = 0;
        }

        if (stationMeters > targetMeters) {
            stationMeters = targetMeters;
        }

        return stationMeters + " / " + targetMeters + " M";
    }

    function getCurrentDistanceMeters() {
        if (_hasGpsFix) {
            return _gpsDistanceMeters;
        }

        var info = Activity.getActivityInfo();

        if (info has :elapsedDistance && info.elapsedDistance != null) {
            return info.elapsedDistance;
        }

        return null;
    }

    function getCurrentCalories() {
        var info = Activity.getActivityInfo();

        if (info has :calories && info.calories != null) {
            return info.calories;
        }

        return null;
    }

    function getCurrentHeartRate() {
        var now = System.getTimer();
        var selection = selectCurrentHeartRate(now);

        return selection[:heartRate];
    }

    function selectCurrentHeartRate(now) {
        var sensorAgeMs = getLatestSensorHeartRateAgeMs(now);
        var activityHeartRate = getActivityInfoHeartRate();
        var selection = {
            :heartRate => null,
            :source => "none",
            :ageMs => sensorAgeMs,
            :status => "missing",
            :activityHeartRate => activityHeartRate
        };

        if (_latestSensorHeartRate != null && sensorAgeMs != null && sensorAgeMs <= 3000) {
            selection[:heartRate] = _latestSensorHeartRate;
            selection[:source] = "sensor";
            selection[:status] = "fresh";
            _lastSelectedHeartRate = _latestSensorHeartRate;
            _lastSelectedHeartRateSource = "sensor";
            maybeLogHeartRateComparison(now, sensorAgeMs, activityHeartRate);
            return selection;
        }

        if (_latestSensorHeartRate != null && sensorAgeMs != null && sensorAgeMs > 3000) {
            selection[:status] = "stale-rejected";
            maybeLogStaleSensorHeartRate(now, sensorAgeMs, activityHeartRate);
        }

        if (activityHeartRate != null) {
            selection[:heartRate] = activityHeartRate;
            selection[:source] = "activity";
            selection[:status] = "activity-fallback";
            _lastSelectedHeartRate = activityHeartRate;
            _lastSelectedHeartRateSource = "activity";
            maybeLogHeartRateComparison(now, sensorAgeMs, activityHeartRate);
            return selection;
        }

        _lastSelectedHeartRate = null;
        _lastSelectedHeartRateSource = "none";
        maybeLogHeartRateComparison(now, sensorAgeMs, activityHeartRate);
        return selection;
    }

    function getActivityInfoHeartRate() {
        var info = Activity.getActivityInfo();
        _lastActivityInfoHeartRate = null;

        if (info has :currentHeartRate && info.currentHeartRate != null) {
            var heartRate = info.currentHeartRate;

            if (isValidHeartRate(heartRate)) {
                _lastActivityInfoHeartRate = heartRate;
                return heartRate;
            }
        }

        return null;
    }

    function getHeartRateText() {
        var heartRate = getCurrentHeartRate();

        if (heartRate == null) {
            return "HR --";
        }

        var zone = getHeartRateZone(heartRate);

        if (zone == null) {
            return "HR " + heartRate;
        }

        return "HR " + heartRate + " Z" + zone;
    }

    function getHeartRateZone(heartRate) {
        if (_heartRateZones == null || _heartRateZones.size() < 6) {
            return null;
        }

        if (heartRate < _heartRateZones[0]) {
            return 0;
        }

        if (heartRate <= _heartRateZones[1]) {
            return 1;
        }

        if (heartRate <= _heartRateZones[2]) {
            return 2;
        }

        if (heartRate <= _heartRateZones[3]) {
            return 3;
        }

        if (heartRate <= _heartRateZones[4]) {
            return 4;
        }

        return 5;
    }

    function getHeartRateColor() {
        var heartRate = getCurrentHeartRate();

        if (heartRate == null) {
            return Graphics.COLOR_LT_GRAY;
        }

        var zone = getHeartRateZone(heartRate);

        if (zone == null) {
            return Graphics.COLOR_WHITE;
        }

        if (zone <= 1) {
            return Graphics.COLOR_BLUE;
        }

        if (zone == 2) {
            return Graphics.COLOR_GREEN;
        }

        if (zone == 3) {
            return Graphics.COLOR_YELLOW;
        }

        if (zone == 4) {
            return Graphics.COLOR_ORANGE;
        }

        return Graphics.COLOR_RED;
    }

    function updateHeartRateStats() as Void {
        if (!_activityRecorder.isRecordingSessionActive()) {
            return;
        }

        var now = System.getTimer();

        if (_lastHeartRateStatsMs != null && now - _lastHeartRateStatsMs < 900) {
            return;
        }

        var selection = selectCurrentHeartRate(now);
        var heartRate = selection[:heartRate];
        _lastHeartRateStatsMs = now;
        maybeLogHeartRateSelect(now, selection);
        maybeLogHeartRateFit(now, selection);

        if (heartRate == null) {
            _heartRateMissingSeconds++;

            if (_heartRateMissingSeconds > 10 && !_missingHeartRateLogged) {
                _missingHeartRateLogged = true;
                System.println("GarminWOD: HR unavailable for more than 10 seconds");
            }

            return;
        }

        _heartRateMissingSeconds = 0;

        if (!_firstValidHeartRateLogged) {
            _firstValidHeartRateLogged = true;
            _firstValidHeartRateMs = now;
            System.println("GarminWOD: first valid HR " + heartRate +
                " firstValidSelectedHrMs=" + _firstValidHeartRateMs +
                " selectedSource=" + _lastSelectedHeartRateSource +
                " workoutSource=" + getStartupWorkoutSourceText() +
                " startPressedMs=" + getLogValue(_workoutStartPressedMs) +
                " hrMonitoringStartedMs=" + getLogValue(_heartRateMonitoringStartedMs) +
                " firstValidSensorHrMs=" + getLogValue(_firstValidSensorHeartRateMs) +
                " recordingStartedMs=" + getLogValue(_activityRecordingStartedMs));
        }

        _heartRateSum += heartRate;
        _heartRateSamples++;

        if (_maxHeartRate == null || heartRate > _maxHeartRate) {
            _maxHeartRate = heartRate;
        }

        maybeLogHeartRateDiagnostics(now);
    }

    function drawWorkoutSummary(dc, width, height) as Void {
        var titleY = height * 7 / 100;
        var statusY = height * 17 / 100;
        var timeY = height * 28 / 100;
        var labelY = height * 38 / 100;
        var distanceY = height * 49 / 100;
        var caloriesY = height * 59 / 100;
        var averageY = height * 69 / 100;
        var maxY = height * 79 / 100;
        var resetY = height * 89 / 100;
        var exitY = height * 96 / 100;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, titleY, Graphics.FONT_XTINY, "Workout Complete", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_activityRecorder.hasSaveFailed() ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, statusY, Graphics.FONT_XTINY, _summarySaveStatus, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, timeY, Graphics.FONT_MEDIUM, formatTime(_elapsedBeforePause), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, labelY, Graphics.FONT_XTINY, "Total Time", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, distanceY, Graphics.FONT_XTINY, getSummaryDistanceText(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, caloriesY, Graphics.FONT_XTINY, getSummaryCaloriesText(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, averageY, Graphics.FONT_XTINY, getAverageHeartRateText(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, maxY, Graphics.FONT_XTINY, getMaxHeartRateText(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        if (_activityRecorder.hasSaveFailed()) {
            dc.drawText(width / 2, resetY, Graphics.FONT_XTINY, "START retry", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, exitY, Graphics.FONT_XTINY, "BACK discard", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(width / 2, resetY, Graphics.FONT_XTINY, "START reset", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, exitY, Graphics.FONT_XTINY, "BACK exit", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawExitConfirmation(dc, width, height) as Void {
        var titleY = height * 18 / 100;
        var warningY = height * 32 / 100;
        var detailY = height * 45 / 100;
        var cancelY = height * 63 / 100;
        var discardY = height * 76 / 100;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, width, height);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, titleY, Graphics.FONT_XTINY, "Unsaved workout", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, warningY, Graphics.FONT_XTINY, "Activity not saved", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, detailY, Graphics.FONT_XTINY, "Choose before exit", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, cancelY, Graphics.FONT_XTINY, "START continue", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, discardY, Graphics.FONT_XTINY, "BACK discard exit", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function getSummaryWorkoutLine() {
        if (_workout.isForTime()) {
            if (_workout.rounds != null) {
                return "" + _workout.rounds + " rounds  " + _workout.getStationCount() + " stations";
            }

            return "" + _workout.getStationCount() + " stations";
        }

        if (_totalSeconds != null) {
            return "Duration " + formatTime(_totalSeconds);
        }

        return _workout.workoutType;
    }

    function getSummaryDistanceText() {
        if (!workoutNeedsGps()) {
            return "Distance N/A";
        }

        var distanceMeters = _finalNativeDistanceMeters;

        if (distanceMeters == null) {
            return "Distance --";
        }

        return "Distance " + formatDistance(distanceMeters);
    }

    function formatDistance(distanceMeters) {
        var meters = distanceMeters.toNumber();

        if (meters < 1609) {
            return meters + " m";
        }

        var tenths = ((meters * 10) / 1609).toNumber();
        var whole = tenths / 10;
        var decimal = tenths % 10;

        return whole + "." + decimal + " mi";
    }

    function getSummaryCaloriesText() {
        var currentCalories = _finalActiveCalories;

        if (currentCalories != null) {
            return "Active Cal " + currentCalories;
        }

        return "Active Cal --";
    }

    function getAverageHeartRateText() {
        if (_heartRateSamples == 0) {
            return "Avg HR --";
        }

        return "Avg HR " + (_heartRateSum / _heartRateSamples);
    }

    function getMaxHeartRateText() {
        if (_maxHeartRate == null) {
            return "Max HR --";
        }

        return "Max HR " + _maxHeartRate;
    }

}
