const assert = require("assert");
const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const sourcePath = path.join(
  repoRoot,
  "ios/GarminWODCompanion/GarminWODCompanion/Views/GymDisplayView.swift"
);
const source = fs.readFileSync(sourcePath, "utf8");

function section(name) {
  const start = source.indexOf(`private struct ${name}`);
  assert(start >= 0, `${name} should exist`);
  const next = source.indexOf("\nprivate struct ", start + 1);
  return source.slice(start, next === -1 ? source.length : next);
}

const wodHeader = section("WODScoreboardHeader");
assert(!wodHeader.includes("Button"), "WORKOUT top header should not contain action buttons");
assert(!wodHeader.includes("DisplayModeSelector"), "WORKOUT top header should not contain the small mode selector");
assert(wodHeader.includes("headerStatusText"), "WORKOUT top header should render status text");

const runHeader = section("HeaderView");
assert(!runHeader.includes("onHeartRateSettings"), "RUN top header should not own the HR action");
assert(!runHeader.includes("DisplayModeSelector"), "RUN top header should not contain the small mode selector");
assert(runHeader.includes("headerStatusBadge"), "RUN top header should render a status badge");

const dock = section("CompanionControlDock");
[
  "Not Following",
  "Heart Rate",
  "Workout History",
  "Display Mode",
  "dot.radiowaves.left.and.right",
  "heart.fill",
  "clock.arrow.circlepath"
].forEach((needle) => {
  assert(dock.includes(needle), `bottom dock should include ${needle}`);
});
assert(dock.includes("metrics.availableWidth >= 520"), "most layouts should favor a single-row toolbar threshold");
assert(dock.includes("LazyVGrid"), "compact layouts should use a grid dock");
assert(dock.includes("return \"\\(bpm)\""), "HR dock state should prioritize the live heart-rate number");
assert(dock.includes("viewModel.toggleFollowWatch()"), "Follow Watch dock action should preserve existing follow semantics");
assert(!dock.includes("Manual Controls"), "normal toolbar should not expose manual controls");
assert(!dock.includes("No results"), "History toolbar item should not show empty-state status text");
assert(!dock.includes("BPM\""), "HR toolbar item should not use a secondary BPM subtitle");

const manualSheet = section("ManualControlsSheet");
["primaryAction", "previousStation", "nextStation", "finishWorkout", "resetWorkout", "stopFollowingWatch"].forEach((needle) => {
  assert(manualSheet.includes(needle), `manual controls should preserve ${needle}`);
});

const layoutCalls = source.match(/CompanionControlDock\(/g) || [];
assert(layoutCalls.length >= 3, "WORKOUT and RUN layouts should use the companion bottom dock");
assert(!source.includes(".frame(height: metrics.wodScoreboardControlHeight)"), "WORKOUT layout should not use the old compact control height");

console.log("companion control dock tests passed");
