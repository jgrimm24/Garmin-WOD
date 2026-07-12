import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class GarminWODDelegate extends WatchUi.BehaviorDelegate {
    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        // The tactix touch screen can arrive here as a generic select event.
        // Keep workout state changes on physical keys only.
        return true;
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        var key = keyEvent.getKey();

        if (key == WatchUi.KEY_START || key == WatchUi.KEY_ENTER) {
            _view.toggleRunning();
            return true;
        }

        if (key == WatchUi.KEY_LAP || key == WatchUi.KEY_ESC || key == WatchUi.KEY_DOWN_RIGHT) {
            _view.handleBackButton();
            return true;
        }

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_UP_LEFT) {
            System.exit();
        }

        return true;
    }

    function onTap(clickEvent) as Boolean {
        // Ignore touch taps during workouts; buttons are safer with sweat and chalk.
        return true;
    }

    function onSwipe(swipeEvent) as Boolean {
        // Keep accidental swipes from changing workout state.
        return true;
    }

    function onBack() as Boolean {
        _view.handleBackButton();
        return true;
    }

    function onNextPage() as Boolean {
        // Keep left-side up/down buttons from changing stations.
        return true;
    }

    function onPreviousPage() as Boolean {
        System.exit();
    }

    function onMenu() as Boolean {
        System.exit();
    }

}
