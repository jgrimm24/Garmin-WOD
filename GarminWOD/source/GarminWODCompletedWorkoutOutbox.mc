import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

class GarminWODCompletedWorkoutOutbox {
    const STORAGE_KEY = "completedWorkoutOutboxV1";
    const COMPLETED_WORKOUTS_URL = "https://garmin-wod.onrender.com/api/completed-workouts";
    const MAX_PENDING_SESSIONS = 10;

    var _queue;
    var _isUploading;

    function initialize() {
        _queue = loadQueue();
        _isUploading = false;
    }

    function enqueue(session) as Void {
        if (session == null || !(session instanceof Dictionary)) {
            System.println("GarminWOD completed outbox skipped invalid session");
            return;
        }

        var sessionId = session["sessionId"];
        if (sessionId == null || sessionId.equals("")) {
            System.println("GarminWOD completed outbox skipped missing sessionId");
            return;
        }

        _queue = loadQueue();
        if (containsSession(sessionId)) {
            System.println("GarminWOD completed outbox already queued sessionId=" + sessionId);
            return;
        }

        _queue.add(session);
        trimQueue();
        saveQueue();
        System.println("GarminWOD completed outbox queued sessionId=" + sessionId +
            " pending=" + _queue.size());
    }

    function uploadPending() as Void {
        _queue = loadQueue();
        if (_isUploading || _queue.size() == 0) {
            return;
        }

        var session = _queue[0];
        var sessionId = session["sessionId"];
        if (sessionId == null || sessionId.equals("")) {
            removeFirst();
            saveQueue();
            uploadPending();
            return;
        }

        _isUploading = true;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            }
        };

        System.println("GarminWOD completed upload sessionId=" + sessionId);
        Communications.makeWebRequest(COMPLETED_WORKOUTS_URL, session, options, method(:onUploadResponse));
    }

    function onUploadResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        _isUploading = false;
        _queue = loadQueue();

        if (_queue.size() == 0) {
            return;
        }

        var expectedSessionId = _queue[0]["sessionId"];
        var acknowledgedSessionId = null;
        var accepted = false;

        if (data != null && data instanceof Dictionary) {
            acknowledgedSessionId = data["sessionId"];
            accepted = data["accepted"] == true || data["stored"] == true;
        }

        if (responseCode >= 200 && responseCode < 300 &&
            accepted &&
            acknowledgedSessionId != null &&
            acknowledgedSessionId.equals(expectedSessionId)) {
            removeFirst();
            saveQueue();
            System.println("GarminWOD completed upload acknowledged sessionId=" + acknowledgedSessionId +
                " remaining=" + _queue.size());
            uploadPending();
            return;
        }

        System.println("GarminWOD completed upload retained sessionId=" + expectedSessionId +
            " responseCode=" + responseCode);
    }

    function pendingCount() {
        _queue = loadQueue();
        return _queue.size();
    }

    function containsSession(sessionId) {
        for (var i = 0; i < _queue.size(); i++) {
            var existing = _queue[i];
            if (existing != null && existing instanceof Dictionary &&
                existing["sessionId"] != null &&
                existing["sessionId"].equals(sessionId)) {
                return true;
            }
        }

        return false;
    }

    function trimQueue() as Void {
        if (_queue.size() <= MAX_PENDING_SESSIONS) {
            return;
        }

        var startIndex = _queue.size() - MAX_PENDING_SESSIONS;
        var trimmed = [];
        for (var i = startIndex; i < _queue.size(); i++) {
            trimmed.add(_queue[i]);
        }

        System.println("GarminWOD completed outbox full; retained newest=" + trimmed.size());
        _queue = trimmed;
    }

    function removeFirst() as Void {
        var next = [];
        for (var i = 1; i < _queue.size(); i++) {
            next.add(_queue[i]);
        }
        _queue = next;
    }

    function loadQueue() {
        var stored = Storage.getValue(STORAGE_KEY);
        if (stored != null && stored instanceof Array) {
            return stored;
        }

        return [];
    }

    function saveQueue() as Void {
        Storage.setValue(STORAGE_KEY, _queue);
    }
}
