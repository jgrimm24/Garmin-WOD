const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ROOT = path.resolve(__dirname, "..");

function createElement() {
  return {
    textContent: "",
    innerHTML: "",
    className: "",
    value: "",
    files: [],
    dataset: {},
    classList: {
      add() {},
      remove() {},
      toggle() {},
    },
    addEventListener() {},
    contains() {
      return false;
    },
    querySelectorAll() {
      return [];
    },
  };
}

function loadImporterContext() {
  const context = {
    console,
    Date,
    Number,
    String,
    Math,
    Array,
    RegExp,
    setTimeout() {},
    window: {
      location: {
        protocol: "http:",
      },
      addEventListener() {},
    },
    document: {
      querySelector() {
        return createElement();
      },
    },
    navigator: {
      clipboard: {
        writeText() {},
      },
    },
    URL: {
      createObjectURL() {
        return "blob:test";
      },
      revokeObjectURL() {},
    },
    Image: function Image() {
      this.addEventListener = function addEventListener() {};
    },
    fetch() {},
  };

  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(ROOT, "importer", "app.js"), "utf8"), context);
  return context;
}

const context = loadImporterContext();

const cases = [
  {
    input: "11 Thrusters, 135/95 lbs",
    expected: {
      name: "Thrusters",
      reps: 11,
      calories: null,
      meters: null,
      weightLb: 135,
      maleWeightLb: 135,
      femaleWeightLb: 95,
    },
  },
  {
    input: "11 Push Press @135/95",
    expected: {
      name: "Push Press",
      reps: 11,
      calories: null,
      meters: null,
      weightLb: 135,
      maleWeightLb: 135,
      femaleWeightLb: 95,
    },
  },
  {
    input: "20 Back Squats, 95/65 lb",
    expected: {
      name: "Back Squats",
      reps: 20,
      calories: null,
      meters: null,
      weightLb: 95,
      maleWeightLb: 95,
      femaleWeightLb: 65,
    },
  },
  {
    input: "12 DB Snatches 50/35#",
    expected: {
      name: "DB Snatches",
      reps: 12,
      calories: null,
      meters: null,
      weightLb: 50,
      maleWeightLb: 50,
      femaleWeightLb: 35,
    },
  },
  {
    input: "10 Bench Press @135 lbs",
    expected: {
      name: "Bench Press",
      reps: 10,
      calories: null,
      meters: null,
      weightLb: 135,
      maleWeightLb: 135,
      femaleWeightLb: null,
    },
  },
  {
    input: "30/24 cal Row",
    expected: {
      name: "Row",
      reps: null,
      calories: "30/24",
      meters: null,
      weightLb: null,
      maleWeightLb: null,
      femaleWeightLb: null,
    },
  },
];

const stations = cases.map((testCase) => context.parseStation(testCase.input, "AMRAP"));
const workout = context.normalizeWorkout({
  title: "Parser validation",
  type: "AMRAP",
  stations,
});
const contractStations = context.toWorkoutContract(workout).stations.map((station) => ({
  name: station.name,
  reps: station.reps,
  calories: station.calories,
  meters: station.meters,
  weightLb: station.weightLb,
  maleWeightLb: station.maleWeightLb,
  femaleWeightLb: station.femaleWeightLb,
}));

for (var i = 0; i < cases.length; i++) {
  assert.deepStrictEqual(contractStations[i], cases[i].expected, cases[i].input);
}

const schemeCases = [
  ["21-15-9", [21, 15, 9]],
  ["21–15–9", [21, 15, 9]],
  ["21—15—9", [21, 15, 9]],
  ["21, 15, 9", [21, 15, 9]],
  ["21 / 15 / 9", [21, 15, 9]],
  ["10-9-8-7-6-5-4-3-2-1", [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]],
  ["1-2-3-4-5", [1, 2, 3, 4, 5]],
  ["21-15-9 reps", [21, 15, 9]],
  ["21-15-9 of Thrusters and Pull-ups", [21, 15, 9]],
];

for (const [input, expected] of schemeCases) {
  assert.deepStrictEqual(Array.from(context.parseRepSchemeFromLine(input)), expected, input);
}

assert.deepStrictEqual(Array.from(context.parseRepSchemeFromLine("5 x 500 m")), [], "5 x 500 m is not a rep scheme");
assert.deepStrictEqual(Array.from(context.parseRepSchemeFromLine("95-115 lb")), [], "weight ranges are not rep schemes");
assert.deepStrictEqual(Array.from(context.parseRepSchemeFromLine("8:00-9:00")), [], "times are not rep schemes");

const repSchemeWorkout = context.toWorkoutContract(context.parseWorkout("21-15-9 For Time\nThrusters @ 95 lb\nPull-ups"));
assert.deepStrictEqual(Array.from(repSchemeWorkout.repScheme), [21, 15, 9], "21-15-9 should become a contract rep scheme");
assert.equal(repSchemeWorkout.rounds, 3, "rep scheme should set rounds to scheme length");
assert.equal(repSchemeWorkout.workoutType, "FOR_TIME", "rep scheme for time should classify as FOR_TIME");
assert.equal(repSchemeWorkout.structureType, "REP_SCHEME", "rep scheme should classify structurally");
assert.equal(repSchemeWorkout.stations[0].name, "Thrusters");
assert.equal(repSchemeWorkout.stations[0].weightLb, 95, "weight should stay attached to the movement");
assert.equal(repSchemeWorkout.stations[0].reps, null, "scheme reps should not be copied to station fixed reps");

const fixedStationWorkout = context.toWorkoutContract(context.parseWorkout("For Time\n21 Thrusters\n15 Pull-ups\n9 Burpees"));
assert.deepStrictEqual(Array.from(fixedStationWorkout.repScheme), [], "fixed station reps should not be misclassified as a round scheme");
assert.equal(fixedStationWorkout.stations[0].reps, 21);

const matchingRounds = context.toWorkoutContract(context.parseWorkout("3 rounds\n21-15-9\nThrusters\nPull-ups"));
assert.deepStrictEqual(Array.from(matchingRounds.parserWarnings), [], "matching explicit rounds should not warn");

const conflictingRounds = context.toWorkoutContract(context.parseWorkout("5 rounds\n21-15-9\nThrusters\nPull-ups"));
assert(conflictingRounds.parserWarnings.length > 0, "conflicting explicit rounds should warn");

const intervalWorkout = context.toWorkoutContract(context.parseWorkout("E9MOM x5\n1000 m Run\n10 Bench Press @ 135 lb"));
assert.equal(intervalWorkout.workoutType, "INTERVAL", "E9MOM should use INTERVAL under the chosen rule");
assert.equal(intervalWorkout.structureType, "TIMED_INTERVAL");
assert.equal(intervalWorkout.intervalSeconds, 540);
assert.equal(intervalWorkout.rounds, 5);

const amrapWorkout = context.toWorkoutContract(context.parseWorkout("AMRAP 20\n10 Pull-ups\n20 Cal Row"));
assert.equal(amrapWorkout.workoutType, "AMRAP");
assert.equal(amrapWorkout.durationSeconds, 1200);

const unknownWorkout = context.toWorkoutContract(context.parseWorkout("Mobility and breathing"));
assert.equal(unknownWorkout.workoutType, "UNKNOWN");

console.log(JSON.stringify(contractStations, null, 2));
