const assert = require("assert");
const childProcess = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");
const vm = require("vm");
const { normalizeWorkoutContract } = require("../server");

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

const exactRepSchemeWorkout = context.toWorkoutContract(context.parseWorkout(`21-15-9 Reps for Time:
Burpees
Kettlebell Swings (24/16 kg)
Box Jumps (24/20 in)`));
assert.equal(exactRepSchemeWorkout.workoutType, "FOR_TIME", "Reps for Time should classify as FOR_TIME");
assert.equal(exactRepSchemeWorkout.structureType, "REP_SCHEME", "Reps for Time should classify structurally");
assert.deepStrictEqual(Array.from(exactRepSchemeWorkout.repScheme), [21, 15, 9], "Reps for Time should preserve scheme");
assert.equal(exactRepSchemeWorkout.rounds, 3, "Reps for Time scheme should set three rounds");
assert.equal(exactRepSchemeWorkout.stations.length, 3, "exact Reps for Time input should retain three stations");
assert.equal(exactRepSchemeWorkout.stations[0].name, "Burpees");
assert.equal(exactRepSchemeWorkout.stations[0].reps, null);
assert.equal(exactRepSchemeWorkout.stations[1].name, "Kettlebell Swings");
assert.equal(exactRepSchemeWorkout.stations[1].reps, null);
assert.equal(exactRepSchemeWorkout.stations[1].weightLb, null, "kg must not be mislabeled as lb");
assert.equal(exactRepSchemeWorkout.stations[1].weightUnit, "kg");
assert.equal(exactRepSchemeWorkout.stations[1].maleWeightKg, 24);
assert.equal(exactRepSchemeWorkout.stations[1].femaleWeightKg, 16);
assert.equal(exactRepSchemeWorkout.stations[2].name, "Box Jumps");
assert.equal(exactRepSchemeWorkout.stations[2].reps, null);
assert.equal(exactRepSchemeWorkout.stations[2].weightLb, null, "box height must not be stored as weight");
assert.equal(exactRepSchemeWorkout.stations[2].heightUnit, "in");
assert.equal(exactRepSchemeWorkout.stations[2].maleHeightIn, 24);
assert.equal(exactRepSchemeWorkout.stations[2].femaleHeightIn, 20);

const canonicalRepSchemeSource = `21-15-9 Reps for Time:
Burpees
Kettlebell Swings (24/16 kg)
Box Jumps (24/20 in)`;
const parsedCanonical = context.parseWorkout(canonicalRepSchemeSource);
const normalizedCanonical = context.normalizeWorkout(parsedCanonical);
const savePayloadCanonical = context.toWorkoutContract(normalizedCanonical);
const serverCanonical = normalizeWorkoutContract(savePayloadCanonical);
assert.equal(normalizedCanonical.structureType, "REP_SCHEME", "normalized importer state must resolve rep scheme structure");
assert.equal(normalizedCanonical.rounds, 3, "normalized importer state must resolve rep scheme rounds");
assert.equal(savePayloadCanonical.structureType, "REP_SCHEME", "save payload must resolve rep scheme structure");
assert.equal(savePayloadCanonical.rounds, 3, "save payload must resolve rep scheme rounds");
assert.equal(serverCanonical.structureType, "REP_SCHEME", "server normalization must preserve rep scheme structure");
assert.equal(serverCanonical.rounds, 3, "server normalization must preserve rep scheme rounds");
assert.deepStrictEqual(Array.from(serverCanonical.stations.map((station) => station.name)), ["Burpees", "Kettlebell Swings", "Box Jumps"], "server normalization must preserve station order");
assert.deepStrictEqual(Array.from(serverCanonical.stations.map((station) => station.reps)), [null, null, null], "rep scheme stations should not receive fixed reps");
assert.equal(serverCanonical.stations[1].weightUnit, "kg");
assert.equal(serverCanonical.stations[1].maleWeightKg, 24);
assert.equal(serverCanonical.stations[1].femaleWeightKg, 16);
assert.equal(serverCanonical.stations[2].heightUnit, "in");
assert.equal(serverCanonical.stations[2].maleHeightIn, 24);
assert.equal(serverCanonical.stations[2].femaleHeightIn, 20);

const badRepSchemeState = context.normalizeWorkout({
  title: "Bad state",
  type: "For Time",
  workoutType: "FOR_TIME",
  structureType: "UNKNOWN",
  rounds: null,
  repScheme: [21, 15, 9],
  stations: [{ name: "Burpees" }, { name: "Kettlebell Swings" }, { name: "Box Jumps" }],
});
assert.equal(badRepSchemeState.structureType, "REP_SCHEME", "normalization must forbid rep scheme with UNKNOWN structure");
assert.equal(badRepSchemeState.rounds, 3, "normalization must forbid rep scheme with null rounds");

const tempContractPath = path.join(os.tmpdir(), "garmin-wod-canonical-rep-scheme.json");
const tempWatchPath = path.join(os.tmpdir(), "GarminWODWorkoutCanonical.mc");
fs.writeFileSync(tempContractPath, JSON.stringify(serverCanonical, null, 2), "utf8");
childProcess.execFileSync(process.execPath, [path.join(ROOT, "scripts", "generate-watch-workout.js"), tempContractPath, tempWatchPath], {
  cwd: ROOT,
  stdio: "pipe",
});
const generatedWatchSource = fs.readFileSync(tempWatchPath, "utf8");
assert(generatedWatchSource.includes("var repScheme;"), "generated watch source should include repScheme field");
assert(generatedWatchSource.includes('structureType = getContractString(data, "structureType", "UNKNOWN");'), "generated watch source should load structureType");
assert(generatedWatchSource.includes('repScheme = getContractArray(data, "repScheme");'), "generated watch source should load repScheme");
assert(generatedWatchSource.includes('rounds = getContractValue(data, "rounds", null);'), "generated watch source should load rounds");
assert(generatedWatchSource.includes('parsedMaleWeightKg.add(getContractValue(station, "maleWeightKg", null));'), "generated watch source should preserve kg metadata");
assert(generatedWatchSource.includes('parsedMaleHeightIn.add(getContractValue(station, "maleHeightIn", null));'), "generated watch source should preserve height metadata");

function scoreboardTextForContract(contract, stationIndex, roundNumber) {
  const station = contract.stations[stationIndex];
  const schemeValue = contract.repScheme && contract.repScheme[roundNumber - 1];

  if (schemeValue != null) return `${schemeValue} ${station.name.toUpperCase()}`;
  if (station.reps != null) return `${station.reps} ${station.name.toUpperCase()}`;
  if (station.meters != null) return `${station.meters}M ${station.name.toUpperCase()}`;
  if (station.calories != null) return `${station.calories} CAL ${station.name.toUpperCase()}`;
  if (station.workSeconds != null) return `${station.workSeconds} SEC ${station.name.toUpperCase()}`;
  return station.name.toUpperCase();
}

function repSchemeProgression(contract) {
  const sequence = [];
  for (let round = 1; round <= contract.rounds; round += 1) {
    for (let stationIndex = 0; stationIndex < contract.stations.length; stationIndex += 1) {
      sequence.push(scoreboardTextForContract(contract, stationIndex, round));
    }
  }
  return sequence;
}

assert.deepStrictEqual(
  repSchemeProgression(serverCanonical),
  [
    "21 BURPEES",
    "21 KETTLEBELL SWINGS",
    "21 BOX JUMPS",
    "15 BURPEES",
    "15 KETTLEBELL SWINGS",
    "15 BOX JUMPS",
    "9 BURPEES",
    "9 KETTLEBELL SWINGS",
    "9 BOX JUMPS",
  ],
  "production contract should produce the required nine-step watch sequence"
);

const parentheticalPoundsScheme = context.toWorkoutContract(context.parseWorkout(`21-15-9 for time
Thrusters (95/65 lb)
Pull-ups`));
assert.deepStrictEqual(Array.from(parentheticalPoundsScheme.repScheme), [21, 15, 9], "parenthetical lb scheme should preserve reps");
assert.equal(parentheticalPoundsScheme.stations.length, 2);
assert.equal(parentheticalPoundsScheme.stations[0].name, "Thrusters");
assert.equal(parentheticalPoundsScheme.stations[0].maleWeightLb, 95);
assert.equal(parentheticalPoundsScheme.stations[0].femaleWeightLb, 65);
assert.equal(parentheticalPoundsScheme.stations[0].reps, null);

const inlineEquipmentScheme = context.toWorkoutContract(context.parseWorkout(`21-15-9
Burpees
Kettlebell Swings 24/16 kg
Box Jumps 24/20 in`));
assert.deepStrictEqual(Array.from(inlineEquipmentScheme.repScheme), [21, 15, 9], "bare scheme should preserve reps");
assert.equal(inlineEquipmentScheme.workoutType, "FOR_TIME");
assert.equal(inlineEquipmentScheme.stations.length, 3);
assert.equal(inlineEquipmentScheme.stations[1].name, "Kettlebell Swings");
assert.equal(inlineEquipmentScheme.stations[1].weightUnit, "kg");
assert.equal(inlineEquipmentScheme.stations[1].maleWeightKg, 24);
assert.equal(inlineEquipmentScheme.stations[1].femaleWeightKg, 16);
assert.equal(inlineEquipmentScheme.stations[2].name, "Box Jumps");
assert.equal(inlineEquipmentScheme.stations[2].heightUnit, "in");
assert.equal(inlineEquipmentScheme.stations[2].maleHeightIn, 24);
assert.equal(inlineEquipmentScheme.stations[2].femaleHeightIn, 20);

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
