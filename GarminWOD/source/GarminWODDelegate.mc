import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class GarminWODDelegate extends WatchUi.BehaviorDelegate {
    var _view;
    var _lastStartInputMs;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        _lastStartInputMs = -1000;
    }

    function onSelect() as Boolean {
        handleStartInput("onSelect", -1);
        return true;
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        logInput("onKey", key);

        if (key == WatchUi.KEY_START || key == WatchUi.KEY_ENTER || key == WatchUi.KEY_UP_RIGHT) {
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

    function handleStartInput(callbackName, keyCode) as Void {
        var now = System.getTimer();
        var beforeState = _view.getInputStateText();

        if (now - _lastStartInputMs < 300) {
            System.println("GarminWOD START callback=" + callbackName +
                " key=" + keyCode +
                " state=" + beforeState +
                " accepted=false action=duplicate");
            return;
        }

        System.println("GarminWOD START callback=" + callbackName +
            " key=" + keyCode +
            " state=" + beforeState +
            " accepted=true action=toggleRunning");

        try {
            _view.toggleRunning();
            _lastStartInputMs = now;
            System.println("GarminWOD START action=toggleRunning before=" +
                beforeState + " result=" + _view.getInputStateText());
        } catch (e) {
            System.println("GarminWOD START action=toggleRunning failed state=" +
                beforeState + " error=" + getExceptionText(e));
        }
    }

    function logInput(callbackName, keyCode) as Void {
        System.println("GarminWOD input " + callbackName + " key=" + keyCode + " state=" + _view.getInputStateText());
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
