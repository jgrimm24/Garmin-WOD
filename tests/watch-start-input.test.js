const assert = require("assert");
const fs = require("fs");
const path = require("path");

const delegateSource = fs.readFileSync(
  path.join(__dirname, "..", "GarminWOD", "source", "GarminWODDelegate.mc"),
  "utf8"
);
const viewSource = fs.readFileSync(
  path.join(__dirname, "..", "GarminWOD", "source", "GarminWODView.mc"),
  "utf8"
);

function indexOfRequired(source, text) {
  const index = source.indexOf(text);
  assert(index >= 0, `Expected source to contain: ${text}`);
  return index;
}

function run() {
  assert(
    delegateSource.includes("return true;") &&
      delegateSource.includes("function onSelect() as Boolean"),
    "onSelect should consume the physical START callback"
  );

  const timestampReserve = indexOfRequired(delegateSource, "_lastStartInputMs = now;");
  const toggleCall = indexOfRequired(delegateSource, "_view.toggleRunning();");
  assert(
    timestampReserve < toggleCall,
    "START debounce timestamp should be reserved before slow startup work begins"
  );

  const duplicateCheck = indexOfRequired(delegateSource, "accepted=false action=duplicate");
  assert(
    duplicateCheck < toggleCall,
    "duplicate START callbacks should be rejected before the workout action runs"
  );

  assert(
    delegateSource.includes("_isHandlingStartInput") &&
      delegateSource.includes("accepted=false action=in-progress"),
    "START callbacks arriving while startup is already handling should be ignored"
  );

  assert(
    viewSource.includes("_startPendingForWorkout = true;") &&
      viewSource.includes("completePendingWorkoutStart();"),
    "pressing START while the workout is loading should auto-complete startup after load"
  );

  assert(
    viewSource.includes("recording retry succeeded") &&
      viewSource.includes("recording retry failed"),
    "fresh startup should retry once after cleaning a failed ActivityRecording start"
  );

  assert(
    viewSource.includes("function shouldWaitForGpsBeforeStart() {\n        return false;"),
    "GPS acquisition should not block workout startup"
  );
}

run();
console.log("watch START input tests passed");
