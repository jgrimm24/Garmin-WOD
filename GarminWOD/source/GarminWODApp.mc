import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GarminWODApp extends Application.AppBase {
    var _view;

    function initialize() {
        AppBase.initialize();
        _view = null;
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        if (_view != null) {
            _view.cleanupBeforeExit();
        }
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        _view = new GarminWODView();
        return [ _view, new GarminWODDelegate(_view) ];
    }

}

function getApp() as GarminWODApp {
    return Application.getApp() as GarminWODApp;
}
