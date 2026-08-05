const assert = require("assert");
const fs = require("fs");
const path = require("path");

const viewPath = path.join(
  __dirname,
  "..",
  "ios",
  "GarminWODCompanion",
  "GarminWODCompanion",
  "Views",
  "GymDisplayView.swift"
);

const source = fs.readFileSync(viewPath, "utf8");

function expectSourceContains(needle, message) {
  assert(source.includes(needle), message);
}

function section(name) {
  const start = source.indexOf(`private struct ${name}`);
  assert(start >= 0, `${name} should exist`);
  const next = source.indexOf("\nprivate struct ", start + 1);
  return source.slice(start, next >= 0 ? next : source.length);
}

console.log("[TEST] companion workout history navigation");
const history = section("WorkoutHistoryView");
expectSourceContains("CompletedWorkoutDetailView(viewModel: viewModel, summary: summary)", "history rows should open a dedicated workout detail screen");
assert(!history.includes("WorkoutAnalyticsView(analytics: selected.analytics)"), "history should not embed the full analytics view below the list");
expectSourceContains(".refreshable", "history should keep native pull-to-refresh");
expectSourceContains(".navigationTitle(\"Workout History\")", "history should use one compact navigation title");

console.log("[TEST] companion workout detail sections");
["MovementBreakdownView(model: model)", "RoundBreakdownView(model: model)", "HeartRateDetailView(model: model)"].forEach((needle) => {
  expectSourceContains(needle, `workout detail should link to ${needle}`);
});
expectSourceContains("WorkoutHighlightsView(model: model)", "highlights should be compact on the detail screen");
expectSourceContains("Detailed splits unavailable.", "legacy sessions should show a graceful fallback");

console.log("[TEST] partial AMRAP round presentation");
const presentation = section("WorkoutAnalyticsPresentationModel");
expectSourceContains("partialRoundSplits", "presentation model should track partial rounds");
expectSourceContains("summary.roundSplits.filter { $0.roundNumber <= summary.roundsCompleted }", "complete-round calculations should exclude partial rounds");
expectSourceContains("Partial Round", "partial rounds should be labeled explicitly");
expectSourceContains("Not compared with full rounds", "partial rounds should not be compared with completed rounds");
assert(!presentation.includes("Transitions\", summary.transitionTimingAvailable ? \"Available\" : \"Not measured\""), "missing transition timing should not become a prominent highlight");

console.log("[TEST] PASS: companion workout history UI");
