import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Attention;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
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
    var _workoutSourceText;
    var _workoutSourceBeforeSync;

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
        _workoutSourceText = "FALLBACK";
        _workoutSourceBeforeSync = "FALLBACK";
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        loadCachedWorkout();
        fetchLatestWorkout();
        _timer.start(method(:onTick), 1000, true);
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
        _timer.stop();
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
    }

    function toggleRunning() as Void {
        if (_isFinished) {
            resetWorkout();
            return;
        }

        if (_isRunning) {
            _elapsedBeforePause = getElapsedSeconds();
            _isRunning = false;
        } else {
            if (shouldWaitForGpsBeforeStart()) {
                startLocationEvents();
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
        if (_workout.isManualStationWorkout()) {
            if (!_isRunning) {
                if (_elapsedBeforePause == 0) {
                    toggleRunning();
                    return;
                }

                resetWorkout();
                return;
            }

            nextStation();
            return;
        }

        if (!_isRunning && _elapsedBeforePause == 0) {
            toggleRunning();
            return;
        }

        resetWorkout();
    }

    function finishWorkout() as Void {
        updateHeartRateStats();
        _elapsedBeforePause = getElapsedSeconds();
        _isRunning = false;
        _isFinished = true;
        WatchUi.requestUpdate();
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
            return "DOWN reset";
        }

        if (_isRunning) {
            if (_workout.isManualStationWorkout()) {
                if (_manualStationIndex >= _workout.getStationCount() - 1) {
                    return "DOWN pause";
                }

                return "DOWN pause";
            }

            return "DOWN pauses";
        }

        if (_elapsedBeforePause > 0) {
            return "DOWN resumes";
        }

        return "BACK starts";
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
            return "DOWN reset UP exit";
        }

        if (!_workout.isManualStationWorkout()) {
            return getStatusText();
        }

        if (_isRunning) {
            if (_manualStationIndex >= _workout.getStationCount() - 1 && !shouldContinueManualRoundFlow()) {
                return "DOWN pause BACK finish";
            }

            return "DOWN pause BACK next";
        }

        if (_elapsedBeforePause > 0) {
            return "DOWN resume BACK reset";
        }

        if (shouldWaitForGpsBeforeStart()) {
            return "WAIT GPS BACK start";
        }

        return "BACK start UP exit";
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
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
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
        var info = Activity.getActivityInfo();

        if (info has :currentHeartRate && info.currentHeartRate != null) {
            return info.currentHeartRate;
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
        var heartRate = getCurrentHeartRate();

        if (heartRate == null) {
            return;
        }

        _heartRateSum += heartRate;
        _heartRateSamples++;

        if (_maxHeartRate == null || heartRate > _maxHeartRate) {
            _maxHeartRate = heartRate;
        }
    }

    function drawWorkoutSummary(dc, width, height) as Void {
        var titleY = height * 9 / 100;
        var timeY = height * 21 / 100;
        var labelY = height * 33 / 100;
        var distanceY = height * 45 / 100;
        var caloriesY = height * 56 / 100;
        var averageY = height * 67 / 100;
        var maxY = height * 78 / 100;
        var resetY = height * 88 / 100;
        var exitY = height * 96 / 100;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, titleY, Graphics.FONT_XTINY, "Workout Complete", Graphics.TEXT_JUSTIFY_CENTER);

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
        dc.drawText(width / 2, resetY, Graphics.FONT_XTINY, "START reset", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, exitY, Graphics.FONT_XTINY, "UP exit", Graphics.TEXT_JUSTIFY_CENTER);
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
        var distanceMeters = getCurrentDistanceMeters();

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
        var currentCalories = getCurrentCalories();

        if (currentCalories != null) {
            return "Calories " + currentCalories;
        }

        var totalCalories = 0;

        for (var i = 0; i < _workout.getStationCount(); i++) {
            var stationCalories = _workout.getStationCalories(i);

            if (stationCalories != null) {
                totalCalories += stationCalories.toNumber();
            }
        }

        if (totalCalories == 0) {
            return "Calories --";
        }

        return "WOD Cal " + totalCalories;
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
