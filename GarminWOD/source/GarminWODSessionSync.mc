import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

class GarminWODSessionSync {
    const SESSION_URL = "https://garmin-wod.onrender.com/api/workout-session";

    var _workoutId;
    var _sessionId;
    var _revision;
    var _isPublishing;
    var _pendingPayload;

    function initialize() {
        _workoutId = null;
        _sessionId = null;
        _revision = 0;
        _isPublishing = false;
        _pendingPayload = null;
    }

    function hasSession() {
        return _sessionId != null;
    }

    function startSession(workoutId) {
        if (_sessionId != null) {
            return;
        }

        _workoutId = workoutId;
        _sessionId = "garmin-wod-" + Time.now().value() + "-" + System.getTimer();
        _revision = 0;
        System.println("GarminWOD sync session created sessionId=" + _sessionId +
            " workoutId=" + workoutId);
    }

    function clearSession() {
        System.println("GarminWOD sync session cleared sessionId=" + _sessionId);
        _workoutId = null;
        _sessionId = null;
        _revision = 0;
        _pendingPayload = null;
        _isPublishing = false;
    }

    function publish(status, round, stationIndex, elapsedSeconds) {
        if (_sessionId == null || _workoutId == null) {
            System.println("GarminWOD sync skipped; no session for status=" + status);
            return;
        }

        _revision++;

        var payload = {
            "workoutId" => _workoutId,
            "sessionId" => _sessionId,
            "revision" => _revision,
            "status" => status,
            "round" => round,
            "stationIndex" => stationIndex,
            "elapsedSeconds" => elapsedSeconds,
            "updatedAt" => Time.now().value()
        };

        if (_isPublishing) {
            _pendingPayload = payload;
            System.println("GarminWOD sync queued revision=" + _revision +
                " status=" + status);
            return;
        }

        sendPayload(payload);
    }

    function sendPayload(payload) {
        _isPublishing = true;

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_PUT,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            }
        };

        System.println("GarminWOD sync publish revision=" + payload["revision"] +
            " status=" + payload["status"] +
            " round=" + payload["round"] +
            " stationIndex=" + payload["stationIndex"] +
            " elapsed=" + payload["elapsedSeconds"]);

        Communications.makeWebRequest(SESSION_URL, payload, options, method(:onResponse));
    }

    function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        System.println("GarminWOD sync response code=" + responseCode);
        _isPublishing = false;

        if (_pendingPayload != null) {
            var nextPayload = _pendingPayload;
            _pendingPayload = null;
            sendPayload(nextPayload);
        }
    }
}
