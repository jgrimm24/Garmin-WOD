import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Lang;
import Toybox.System;

class GarminWODActivityRecorder {
    var _recordingSession;
    var _lastStatus;
    var _lastError;
    var _hasSaved;
    var _saveFailed;

    function initialize() {
        _recordingSession = null;
        _lastStatus = "No activity";
        _lastError = null;
        _hasSaved = false;
        _saveFailed = false;
    }

    function createRecordingSession() {
        if (_recordingSession != null) {
            return true;
        }

        if (!(Toybox has :ActivityRecording)) {
            return fail("ActivityRecording unavailable");
        }

        try {
            _recordingSession = ActivityRecording.createSession({
                :name => "Garmin WOD",
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
        } catch (e) {
            return failWithException("Recording session create failed", e);
        }

        _hasSaved = false;
        _saveFailed = false;
        _lastStatus = "Session created";
        _lastError = null;
        System.println("GarminWOD: session created");
        return true;
    }

    function startRecordingSession() {
        if (!createRecordingSession()) {
            return false;
        }

        if (isRecordingSessionActive()) {
            return true;
        }

        try {
            if (!_recordingSession.start()) {
                return fail("Recording start failed");
            }
        } catch (e) {
            return failWithException("Recording start exception", e);
        }

        _lastStatus = "Recording started";
        _lastError = null;
        System.println("GarminWOD: recording started");
        return true;
    }

    function pauseRecordingSession() {
        if (_recordingSession == null) {
            return true;
        }

        if (!isRecordingSessionActive()) {
            return true;
        }

        try {
            if (!_recordingSession.stop()) {
                return fail("Recording pause failed");
            }
        } catch (e) {
            return failWithException("Recording pause exception", e);
        }

        _lastStatus = "Recording paused";
        _lastError = null;
        System.println("GarminWOD: recording paused");
        return true;
    }

    function resumeRecordingSession() {
        if (_recordingSession == null) {
            return startRecordingSession();
        }

        if (isRecordingSessionActive()) {
            return true;
        }

        try {
            if (!_recordingSession.start()) {
                return fail("Recording resume failed");
            }
        } catch (e) {
            return failWithException("Recording resume exception", e);
        }

        _lastStatus = "Recording resumed";
        _lastError = null;
        System.println("GarminWOD: recording resumed");
        return true;
    }

    function stopAndSaveRecordingSession() {
        if (_recordingSession == null) {
            return fail("No recording session to save");
        }

        if (isRecordingSessionActive()) {
            try {
                if (!_recordingSession.stop()) {
                    _saveFailed = true;
                    return fail("Recording stop before save failed");
                }
            } catch (e) {
                _saveFailed = true;
                return failWithException("Recording stop before save exception", e);
            }

            System.println("GarminWOD: recording stopped");
        }

        try {
            if (!_recordingSession.save()) {
                _saveFailed = true;
                return fail("Recording save failed");
            }
        } catch (e) {
            _saveFailed = true;
            return failWithException("Recording save exception", e);
        }

        _recordingSession = null;
        _hasSaved = true;
        _saveFailed = false;
        _lastStatus = "Saved to Garmin";
        _lastError = null;
        System.println("GarminWOD: recording saved");
        return true;
    }

    function discardRecordingSession() {
        if (_recordingSession == null) {
            return true;
        }

        if (isRecordingSessionActive()) {
            try {
                if (_recordingSession.stop()) {
                    System.println("GarminWOD: recording stopped before discard");
                }
            } catch (e) {
                return failWithException("Recording stop before discard exception", e);
            }
        }

        try {
            if (!_recordingSession.discard()) {
                return fail("Recording discard failed");
            }
        } catch (e) {
            return failWithException("Recording discard exception", e);
        }

        _recordingSession = null;
        _saveFailed = false;
        _lastStatus = "Recording discarded";
        _lastError = null;
        System.println("GarminWOD: recording discarded");
        return true;
    }

    function isRecordingSessionActive() {
        return _recordingSession != null && _recordingSession.isRecording();
    }

    function hasOpenSession() {
        return _recordingSession != null;
    }

    function hasSaved() {
        return _hasSaved;
    }

    function hasSaveFailed() {
        return _saveFailed;
    }

    function getLastStatus() {
        return _lastStatus;
    }

    function getLastError() {
        return _lastError;
    }

    function fail(message) {
        _lastError = message;
        _lastStatus = message;
        System.println("GarminWOD: session error: " + message);
        return false;
    }

    function failWithException(message, exception) {
        var detail = getExceptionText(exception);
        _lastError = message + ": " + detail;
        _lastStatus = message;
        System.println("GarminWOD: session error: " + message + ": " + detail);
        return false;
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
}
