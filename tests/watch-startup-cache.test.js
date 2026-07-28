const assert = require("assert");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const workoutSource = fs.readFileSync(
  path.join(root, "GarminWOD", "source", "GarminWODWorkout.mc"),
  "utf8"
);
const viewSource = fs.readFileSync(
  path.join(root, "GarminWOD", "source", "GarminWODView.mc"),
  "utf8"
);

assert(
  workoutSource.includes('title = "NO WORKOUT LOADED";'),
  "Generated workout should start in an explicit empty state"
);
assert(
  workoutSource.includes("stationNames = [];"),
  "Generated workout should not embed startup stations"
);
assert(
  workoutSource.includes("function hasWorkout()"),
  "Generated workout should expose a loaded-workout guard"
);
assert(
  !workoutSource.includes('"Wall Balls"'),
  "Generated workout should not embed the old Wall Balls sample"
);
assert(
  !workoutSource.includes('"Row",'),
  "Generated workout should not embed the old Row sample station"
);
assert(
  !viewSource.includes('"FALLBACK"'),
  "Watch view should not label startup data as a fallback workout"
);
assert(
  viewSource.includes('"NO WORKOUT LOADED"'),
  "Watch view should render an honest no-workout state"
);

console.log("watch startup cache regression checks passed");
