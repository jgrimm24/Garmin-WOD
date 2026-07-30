import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class GarminWODDelegate extends WatchUi.BehaviorDelegate {
    var _view;
    var _lastStartInputMs;
    var _isHandlingStartInput;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _lastStartInputMs = -1000;
        _isHandlingStartInput = false;
    }

    function onSelect() as Boolean {
        handleStartInput("onSelect", -1);
        return true;
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        var key = getEventKey(keyEvent);

        if (isStartKey(key)) {
            handleStartInput("onKey", key);
            return true;
        }

        if (key == WatchUi.KEY_LAP || key == WatchUi.KEY_ESC || key == WatchUi.KEY_DOWN_RIGHT) {
            _view.handleBackButton();
            return true;
        }

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_UP_LEFT || key == WatchUi.KEY_DOWN || key == WatchUi.KEY_DOWN_LEFT) {
            _view.handlePageNavigation();
            return true;
        }

        if (key == WatchUi.KEY_MENU || key == WatchUi.KEY_LIGHT) {
            _view.handleMenuButton();
            return true;
        }

        return false;
    }

    function onKeyPressed(keyEvent as KeyEvent) as Boolean {
        var key = getEventKey(keyEvent);

        if (isStartKey(key)) {
            handleStartInput("onKeyPressed", key);
            return true;
        }

        return false;
    }

    function onKeyReleased(keyEvent as KeyEvent) as Boolean {
        return false;
    }

    function handleStartInput(callbackName, keyCode) as Void {
        try {
            var now = System.getTimer();
            var beforeState = safeInputStateText();

            if (_isHandlingStartInput) {
                System.println("GarminWOD START callback=" + callbackName +
                    " key=" + keyCode +
                    " timer=" + now +
                    " state=" + beforeState +
                    " accepted=false action=in-progress");
                return;
            }

            if (now - _lastStartInputMs < 900) {
                System.println("GarminWOD START callback=" + callbackName +
                    " key=" + keyCode +
                    " timer=" + now +
                    " state=" + beforeState +
                    " accepted=false action=duplicate");
                return;
            }

            _lastStartInputMs = now;
            _isHandlingStartInput = true;

            _view.toggleRunning();
            _isHandlingStartInput = false;
            System.println("GarminWOD START action=toggleRunning before=" +
                beforeState + " result=" + _view.getInputStateText());
        } catch (e) {
            _isHandlingStartInput = false;
            System.println("GarminWOD START exception type=" + getExceptionType(e) +
                " message=" + getExceptionText(e) +
                " stack=" + getExceptionStack(e));
        }
    }

    function isStartKey(key) {
        return key == WatchUi.KEY_START ||
            key == WatchUi.KEY_ENTER ||
            key == WatchUi.KEY_UP_RIGHT;
    }

    function logInput(callbackName, keyCode) as Void {
        System.println("GarminWOD input " + callbackName + " key=" + keyCode + " state=" + safeInputStateText());
    }

    function getEventKey(keyEvent) {
        try {
            if (keyEvent != null) {
                return keyEvent.getKey();
            }
        } catch (e) {
            System.println("GarminWOD input getKey failed error=" + getExceptionText(e));
        }

        return -1;
    }

    function getEventType(keyEvent) {
        try {
            if (keyEvent != null && keyEvent has :getType) {
                return keyEvent.getType();
            }
        } catch (e) {
            System.println("GarminWOD input getType failed error=" + getExceptionText(e));
        }

        return -1;
    }

    function safeInputStateText() {
        try {
            return _view.getInputStateText();
        } catch (e) {
            return "state-error:" + getExceptionText(e);
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

    function getExceptionType(exception) {
        if (exception == null) {
            return "Unknown";
        }

        return exception.toString();
    }

    function getExceptionStack(exception) {
        return "unavailable";
    }

    function onTap(clickEvent) as Boolean {
        // Ignore touch taps during workouts; buttons are safer with sweat and chalk.
        logInput("onTap", -1);
        return true;
    }

    function onSwipe(swipeEvent) as Boolean {
        // Keep accidental swipes from changing workout state.
        logInput("onSwipe", -1);
        return true;
    }

    function onBack() as Boolean {
        logInput("onBack", -1);
        _view.handleBackButton();
        return true;
    }

    function onNextPage() as Boolean {
        logInput("onNextPage", -1);
        _view.handlePageNavigation();
        return true;
    }

    function onPreviousPage() as Boolean {
        logInput("onPreviousPage", -1);
        _view.handlePageNavigation();
        return true;
    }

    function onMenu() as Boolean {
        logInput("onMenu", -1);
        _view.handleMenuButton();
        return true;
    }

}
