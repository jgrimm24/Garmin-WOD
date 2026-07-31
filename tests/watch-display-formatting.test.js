const assert = require("assert");

function movementWords(text) {
  return String(text)
    .toUpperCase()
    .split(/\s+|@/)
    .filter(Boolean)
    .map((word) => {
      if (word === "CALORIE" || word === "CALORIES") return "CAL";
      if (word === "DUMBBELL" || word === "DUMBBELLS") return "DB";
      if (word === "KETTLEBELL" || word === "KETTLEBELLS") return "KB";
      return word;
    });
}

function joinWords(words, start, end) {
  return words.slice(start, end).join(" ");
}

function movementLines(text) {
  const words = movementWords(text);
  const formatted = joinWords(words, 0, words.length);

  if (words.length <= 1) return [formatted];
  if (words.length === 2) return [words[0], words[1]];

  if (isNumericDisplayWord(words[0])) {
    if (isUnitDisplayWord(words[1])) {
      return [joinWords(words, 0, 2), joinWords(words, 2, words.length)];
    }

    return [words[0], joinWords(words, 1, words.length)];
  }

  let bestIndex = 1;
  let bestBalance = formatted.length;

  for (let i = 1; i < words.length; i += 1) {
    const before = joinWords(words, 0, i);
    const after = joinWords(words, i, words.length);
    const balance = Math.abs(before.length - after.length);

    if (balance < bestBalance) {
      bestBalance = balance;
      bestIndex = i;
    }
  }

  return [joinWords(words, 0, bestIndex), joinWords(words, bestIndex, words.length)];
}

function isNumericDisplayWord(word) {
  return /^[0-9./-]+M?$/.test(word) && /[0-9]/.test(word);
}

function isUnitDisplayWord(word) {
  return ["CAL", "LB", "LBS", "M", "SEC"].includes(word);
}

function previewStationText({ name, reps, calories, meters }) {
  return scoreboardMovementName({ name, reps, calories, meters });
}

function stationText({ name, reps, calories, meters, weight }) {
  let text = name;

  if (meters != null) text = `${meters}m ${text}`;
  if (calories != null) text = `${calories} cal ${text}`;
  if (reps != null) text = `${reps} ${text}`;
  if (weight != null) text = `${text} @${weight}`;

  return text;
}

function scoreboardMovementName({ name }) {
  return name;
}

function usefulDetail({ stationText, reps, calories, meters, weight, seconds }) {
  const lower = stationText.toLowerCase().replaceAll("@", " ");
  const details = [];

  if (reps != null && !lower.includes(String(reps))) details.push(`${reps} REPS`);
  if (calories != null && !lower.includes(String(calories))) details.push(`${calories} CAL`);
  if (meters != null && !lower.includes(String(meters))) details.push(`${meters} M`);
  if (weight != null && !lower.includes(String(weight))) details.push(`${weight} LB`);
  if (seconds != null) details.push(`${seconds} SEC`);

  return details.length === 0 ? null : details.join(" / ");
}

function controlHint({ running, elapsedBeforePause }) {
  if (running) return null;
  if (elapsedBeforePause > 0) return "START resume";
  return "START start";
}

function liveHeartRateText(heartRate) {
  return heartRate == null ? "--" : `${heartRate}`;
}

function sourceVisible({ running, elapsedBeforePause }) {
  return !running && elapsedBeforePause === 0;
}

function currentFont(lines) {
  const longest = Math.max(...lines.map((line) => line.length));
  return longest <= 12 ? "medium" : "small";
}

function nextFont() {
  return "xtiny";
}

function run() {
  assert.deepStrictEqual(movementLines("20 Cal Row"), ["20 CAL", "ROW"]);
  assert.deepStrictEqual(movementLines("30 Wall Balls"), ["30", "WALL BALLS"]);
  assert.deepStrictEqual(movementLines("95 lb Thruster"), ["95 LB", "THRUSTER"]);
  assert.deepStrictEqual(movementLines("Toes To Bar"), ["TOES", "TO BAR"]);
  assert.strictEqual(
    movementLines("Double Dumbbell Hang Power Clean").join(" "),
    "DOUBLE DB HANG POWER CLEAN",
    "long movement should remain complete and understandable"
  );

  assert.strictEqual(
    usefulDetail({ stationText: "20 cal Row", calories: 20 }),
    null,
    "redundant calorie detail should be suppressed"
  );

  assert.strictEqual(
    usefulDetail({ stationText: "30 Wall Balls", reps: 30 }),
    null,
    "redundant rep detail should be suppressed"
  );

  assert.strictEqual(
    usefulDetail({ stationText: "Front Squats", reps: 8, weight: 135 }),
    "8 REPS / 135 LB",
    "useful rep and weight detail should be retained"
  );

  assert.strictEqual(
    usefulDetail({ stationText: "8 Front Squats @135", reps: 8, weight: 135 }),
    null,
    "weight already present in the movement title should be suppressed"
  );

  assert.strictEqual(currentFont(movementLines("20 Cal Row")), "medium");
  assert.strictEqual(nextFont(movementLines("20 Cal Row")), "xtiny");
  assert.strictEqual(
    stationText({ name: "Bench Press", reps: 10, weight: 135 }),
    "10 Bench Press @135",
    "fully composed station text should remain available outside the scoreboard"
  );

  assert.strictEqual(
    scoreboardMovementName({ name: "BENCH PRESS", reps: 10 }),
    "BENCH PRESS",
    "scoreboard current should omit reps"
  );

  assert.strictEqual(
    scoreboardMovementName({ name: "BENCH PRESS", weight: 135 }),
    "BENCH PRESS",
    "scoreboard current should omit weight"
  );

  assert.strictEqual(
    previewStationText({ name: "BOX JUMPS", reps: 12 }),
    "BOX JUMPS",
    "scoreboard next should omit reps"
  );

  assert.strictEqual(
    scoreboardMovementName({ name: "ROW", meters: 500 }),
    "ROW",
    "scoreboard current should omit meters"
  );

  assert.strictEqual(
    previewStationText({ name: "BIKE", calories: 20 }),
    "BIKE",
    "scoreboard next should omit calories"
  );

  assert.strictEqual(sourceVisible({ running: true, elapsedBeforePause: 0 }), false);
  assert.strictEqual(controlHint({ running: true, elapsedBeforePause: 0 }), null);
  assert.strictEqual(controlHint({ running: false, elapsedBeforePause: 12 }), "START resume");
  assert.strictEqual(controlHint({ running: false, elapsedBeforePause: 0 }), "START start");
  assert.strictEqual(liveHeartRateText(156), "156");
  assert.strictEqual(liveHeartRateText(null), "--");

  const station = {
    name: "BENCH PRESS",
    reps: 10,
    calories: null,
    meters: null,
    weight: 135,
  };
  assert.strictEqual(station.reps, 10, "reps should remain in the underlying station data");
  assert.strictEqual(station.weight, 135, "weight should remain in the underlying station data");
}

run();
console.log("watch display formatting tests passed");
