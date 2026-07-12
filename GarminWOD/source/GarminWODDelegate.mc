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
        _view.toggleRunning();
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
