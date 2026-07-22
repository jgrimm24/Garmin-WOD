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
    var _isFetchingWorkout;
    var _hasLoadedInitialWorkout;
    var _isTimerActive;
    var _isLocationEventsActive;
    var _workoutSourceText;
    var _workoutSourceBeforeSync;
    var _activityRecorder;
    var _summarySaveStatus;
    var _firstValidHeartRateLogged;
    var _missingHeartRateLogged;
    var _heartRateMissingSeconds;
    var _latestSensorHeartRate;
    var _finalActiveCalories;
    var _finalNativeDistanceMeters;
    var _exitConfirmPending;

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
        _isFetchingWorkout = false;
        _hasLoadedInitialWorkout = false;
        _isTimerActive = false;
        _isLocationEventsActive = false;
        _workoutSourceText = "FALLBACK";
        _workoutSourceBeforeSync = "FALLBACK";
        _activityRecorder = new GarminWODActivityRecorder();
        _summarySaveStatus = "Not saved";
        _firstValidHeartRateLogged = false;
        _missingHeartRateLogged = false;
        _heartRateMissingSeconds = 0;
        _latestSensorHeartRate = null;
        _finalActiveCalories = null;
        _finalNativeDistanceMeters = null;
        _exitConfirmPending = false;
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

        var stationIndex = getStationIndex(elapsed);
        updateStationDistanceStart(stationIndex);
        var roundNumber = getRoundNumber(elapsed);
        var secondInStation = getSecondInStation(elapsed);
        var stationRemaining = getStationRemaining(stationIndex, secondInStation);
        var stationLabel = getStationLabel(stationIndex, secondInStation);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, width, height);

        if (_isFinished) {
            drawWorkoutSummary(dc, width, height);
            return;
        }

        if (_exitConfirmPending) {
            drawExitConfirmation(dc, width, height);
            return;
        }

        var sourceY = height * 4 / 100;
        var headerY = height * 10 / 100;
        var heartRateY = height * 20 / 100;
        var stationY = height * 32 / 100;
        var contextY = height * 44 / 100;
        var timerY = height * 58 / 100;
        var stationLabelY = height * 75 / 100;
        var controlsY = height * 84 / 100;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, sourceY, Graphics.FONT_XTINY, getWorkoutSourceText(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, headerY, Graphics.FONT_XTINY, _workout.getHeader(roundNumber), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(getHeartRateColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, heartRateY, Graphics.FONT_XTINY, getHeartRateText(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, stationY, Graphics.FONT_XTINY, _workout.getStationText(stationIndex), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, contextY, Graphics.FONT_XTINY, getContextText(stationIndex, elapsed, remaining), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, timerY, Graphics.FONT_MEDIUM, stationRemaining, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, stationLabelY, Graphics.FONT_XTINY, stationLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, controlsY, Graphics.FONT_XTINY, getControlHintText(), Graphics.TEXT_JUSTIFY_CENTER);
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

        if (_isRunning) {
            var elapsed = getElapsedSeconds();

            if (!_activityRecorder.pauseRecordingSession()) {
                WatchUi.requestUpdate();
                return;
            }

            _elapsedBeforePause = elapsed;
            _isRunning = false;
        } else {
            if (shouldWaitForGpsBeforeStart()) {
                startLocationEvents();
                WatchUi.requestUpdate();
                return;
            }

            enableHeartRateSensor();

            var recordingStarted = _elapsedBeforePause > 0 ?
                _activityRecorder.resumeRecordingSession() :
                _activityRecorder.startRecordingSession();

            if (!recordingStarted) {
                WatchUi.requestUpdate();
                return;
            }

            _startMs = System.getTimer();
            _lastLocation = null;
            _isRunning = true;
            startLocationEvents();
        }

        WatchUi.requestUpdate();
    }

    function resetWorkout() as Void {
        if (_activityRecorder.hasOpenSession() && !_activityRecorder.hasSaved()) {
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
        _summarySaveStatus = "Not saved";
        _firstValidHeartRateLogged = false;
        _missingHeartRateLogged = false;
        _heartRateMissingSeconds = 0;
        _latestSensorHeartRate = null;
        _finalActiveCalories = null;
        _finalNativeDistanceMeters = null;
        _exitConfirmPending = false;
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
        _latestSensorHeartRate = null;
        _finalActiveCalories = null;
        _finalNativeDistanceMeters = null;
        _exitConfirmPending = false;
        resetStationDistanceStart();

        return true;
    }

    function loadCachedWorkout() as Void {
        var cachedWorkout = Storage.getValue("latestWorkoutV2");

        if (cachedWorkout != null && loadWorkoutData(cachedWorkout)) {
            _workoutSourceText = "CACHE";
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

        if (responseCode == 200 && data instanceof Dictionary && loadWorkoutData(data)) {
            Storage.setValue("latestWorkoutV2", data);
            _workoutSourceText = "WEB WOD";
        } else if (_workoutSourceText.equals("SYNC...")) {
            _workoutSourceText = _workoutSourceBeforeSync;
        }

        WatchUi.requestUpdate();
    }

    function getWorkoutSourceText() {
        return _workoutSourceText;
    }

    function nextStation() as Void {
        if (!_workout.isManualStationWorkout()) {
            return;
        }

        if (_manualStationIndex < _workout.getStationCount() - 1) {
            _manualStationIndex++;
            resetStationDistanceStart();
        } else if (shouldContinueManualRoundFlow()) {
            _manualRoundNumber++;
            _manualStationIndex = 0;
            resetStationDistanceStart();
        } else {
            finishWorkout();
        }

        WatchUi.requestUpdate();
    }

    function previousStation() as Void {
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
        var saved = _activityRecorder.stopAndSaveRecordingSession();
        _summarySaveStatus = saved ? "Saved to Garmin" : "Save failed";
        if (saved) {
            disableHeartRateSensor();
        }
        _isFinished = true;
        WatchUi.requestUpdate();
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
            _activityRecorder.discardRecordingSession();
        }
        disableHeartRateSensor();
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
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            Sensor.enableSensorEvents(method(:onSensor));
            System.println("GarminWOD: heart rate sensor enabled");
        } catch (e) {
            System.println("GarminWOD: heart rate sensor enable failed: " + getExceptionText(e));
        }
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
        if (sensorInfo == null || !(sensorInfo has :heartRate) || sensorInfo.heartRate == null) {
            return;
        }

        var heartRate = sensorInfo.heartRate;

        if (isValidHeartRate(heartRate)) {
            _latestSensorHeartRate = heartRate;
        }
    }

    function isValidHeartRate(heartRate) {
        return heartRate != null && heartRate >= 30 && heartRate <= 250;
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

        if (shouldWaitForGpsBeforeStart()) {
            return "WAIT GPS  START start";
        }

        return "START start";
    }

    function shouldWaitForGpsBeforeStart() {
        return !_isRunning && _elapsedBeforePause == 0 && workoutNeedsGps() && !_hasGpsFix;
    }

    function workoutNeedsGps() {
        for (var i = 0; i < _workout.getStationCount(); i++) {
            if (_workout.getStationMeters(i) != null) {
                return true;
            }
        }

        return false;
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
            return "GPS distance --/" + targetMeters + "m";
        }

        var stationMeters = (currentDistance - _stationDistanceStart).toNumber();

        if (stationMeters < 0) {
            stationMeters = 0;
        }

        if (stationMeters > targetMeters) {
            stationMeters = targetMeters;
        }

        return stationMeters + "/" + targetMeters + "m";
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
        if (_latestSensorHeartRate != null) {
            return _latestSensorHeartRate;
        }

        var info = Activity.getActivityInfo();

        if (info has :currentHeartRate && info.currentHeartRate != null) {
            var heartRate = info.currentHeartRate;

            if (isValidHeartRate(heartRate)) {
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

        var heartRate = getCurrentHeartRate();

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
            System.println("GarminWOD: first valid HR " + heartRate);
        }

        _heartRateSum += heartRate;
        _heartRateSamples++;

        if (_maxHeartRate == null || heartRate > _maxHeartRate) {
            _maxHeartRate = heartRate;
        }
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
