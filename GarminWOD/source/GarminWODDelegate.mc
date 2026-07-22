import Toybox.Lang;
import Toybox.WatchUi;

class GarminWODDelegate extends WatchUi.BehaviorDelegate {
    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        // Touchscreen taps can arrive as generic select events on tactix.
        // Ignore this path so accidental face touches cannot start or pause.
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

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_UP_LEFT || key == WatchUi.KEY_DOWN || key == WatchUi.KEY_DOWN_LEFT) {
            _view.handlePageNavigation();
            return true;
        }

        if (key == WatchUi.KEY_MENU || key == WatchUi.KEY_LIGHT) {
            _view.handleMenuButton();
            return true;
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
        _view.handlePageNavigation();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.handlePageNavigation();
        return true;
    }

    function onMenu() as Boolean {
        _view.handleMenuButton();
        return true;
    }

}
