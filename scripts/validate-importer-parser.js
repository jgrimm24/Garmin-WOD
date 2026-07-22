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

console.log(JSON.stringify(contractStations, null, 2));
