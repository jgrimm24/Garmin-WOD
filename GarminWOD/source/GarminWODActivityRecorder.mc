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

        _recordingSession = ActivityRecording.createSession({
            :name => "Garmin WOD",
            :sport => Activity.SPORT_GENERIC,
            :subSport => Activity.SUB_SPORT_GENERIC
        });

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

        if (!_recordingSession.start()) {
            return fail("Recording start failed");
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

        if (!_recordingSession.stop()) {
            return fail("Recording pause failed");
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

        if (!_recordingSession.start()) {
            return fail("Recording resume failed");
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
            if (!_recordingSession.stop()) {
                _saveFailed = true;
                return fail("Recording stop before save failed");
            }

            System.println("GarminWOD: recording stopped");
        }

        if (!_recordingSession.save()) {
            _saveFailed = true;
            return fail("Recording save failed");
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
            _recordingSession.stop();
        }

        if (!_recordingSession.discard()) {
            return fail("Recording discard failed");
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
}
