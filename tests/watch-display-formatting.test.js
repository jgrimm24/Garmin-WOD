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

function previewStationText(station, roundNumber, repScheme = []) {
  return scoreboardMovementText(station, roundNumber, repScheme);
}

function stationText({ name, reps, calories, meters, weight }) {
  let text = name;

  if (meters != null) text = `${meters}m ${text}`;
  if (calories != null) text = `${calories} cal ${text}`;
  if (reps != null) text = `${reps} ${text}`;
  if (weight != null) text = `${text} @${weight}`;

  return text;
}

function scoreboardMovementText(station, roundNumber, repScheme = []) {
  const prefix = essentialPrescription(station, roundNumber, repScheme);

  if (!prefix || String(station.name).toUpperCase().startsWith(String(prefix).toUpperCase())) {
    return station.name;
  }

  return `${prefix} ${station.name}`;
}

function essentialPrescription({ reps, calories, meters, seconds }, roundNumber, repScheme = []) {
  if (repScheme.length && roundNumber != null && repScheme[roundNumber - 1] != null) {
    return `${repScheme[roundNumber - 1]}`;
  }

  if (reps != null) return `${reps}`;
  if (meters != null) return `${meters}M`;
  if (calories != null) return `${calories} CAL`;
  if (seconds != null) return `${seconds} SEC`;
  return null;
}

function nextMovementText({ stationIndex, roundNumber, stations, rounds, repScheme = [] }) {
  if (stationIndex >= stations.length - 1) {
    if (rounds != null && roundNumber < rounds) {
      return previewStationText(stations[0], roundNumber + 1, repScheme);
    }

    return "Last station";
  }

  return previewStationText(stations[stationIndex + 1], roundNumber, repScheme);
}

function layoutMode({ workoutType, structureType }) {
  if (workoutType === "INTERVAL" || workoutType === "EMOM" || structureType === "TIMED_INTERVAL") {
    return "INTERVAL";
  }

  if (workoutType === "STRENGTH") return "STRENGTH";
  return "STANDARD";
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

function estimatedMediumTextWidth(text) {
  return String(text).length * 11;
}

function estimatedSmallTextWidth(text) {
  return String(text).length * 9;
}

function scoreboardHeaderLayout({ width, roundText, heartRateText }) {
  const unit = Math.max(2, width / 105);
  const heartWidth = unit * 7;
  const gap = Math.max(2, width / 100);
  const leftX = width * 0.18;
  const rightEdge = width * 0.84;
  const hrTextRight = rightEdge - heartWidth - gap;
  let roundWidth = estimatedMediumTextWidth(roundText);
  let hrWidth = estimatedMediumTextWidth(heartRateText);
  let font = "medium";
  const overlaps = leftX + roundWidth + gap >= hrTextRight - hrWidth;

  if (overlaps) {
    font = "small";
    roundWidth = estimatedSmallTextWidth(roundText);
    hrWidth = estimatedSmallTextWidth(heartRateText);
  }

  return {
    round: { left: leftX, right: leftX + roundWidth },
    heartRate: { left: hrTextRight - hrWidth, textRight: hrTextRight, right: rightEdge },
    heart: { left: rightEdge - heartWidth, right: rightEdge, width: heartWidth },
    visible: { left: width * 0.17, right: width * 0.95 },
    font,
  };
}

function scoreboardMovementTimerLayout({ width, timeText }) {
  const centerX = width / 2;
  const timeWidth = estimatedSmallTextWidth(timeText);

  return {
    timer: { left: centerX - timeWidth / 2, right: centerX + timeWidth / 2, center: centerX },
    centerX,
  };
}

function assertHeaderDoesNotOverlap({ roundText, timeText, heartRateText }) {
  const layout = scoreboardHeaderLayout({ width: 280, roundText, heartRateText });
  const timerLayout = scoreboardMovementTimerLayout({ width: 280, timeText });

  assert(layout.round.left >= layout.visible.left, `${roundText} should stay inside the left safe area`);
  assert(layout.heartRate.right <= layout.visible.right, `${heartRateText} should stay inside the right safe area`);
  assert(layout.heart.width > 0, `${heartRateText} should always reserve a heart icon`);
  assert(layout.heart.left >= layout.heartRate.textRight, `${heartRateText} heart should sit to the right of the HR text`);
  assert(layout.heart.right <= layout.visible.right, `${heartRateText} heart should stay on-screen`);
  assert(layout.round.right < layout.heartRate.left, `${roundText} should not overlap ${heartRateText}`);
  assert(Math.abs(timerLayout.timer.center - timerLayout.centerX) <= 1, `${timeText} should remain centered below movement`);
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
    scoreboardMovementText({ name: "BENCH PRESS", reps: 10 }, 1),
    "10 BENCH PRESS",
    "scoreboard current should include essential fixed reps"
  );

  assert.strictEqual(
    scoreboardMovementText({ name: "BENCH PRESS", weight: 135 }, 1),
    "BENCH PRESS",
    "scoreboard current should omit weight-only prescriptions"
  );

  assert.strictEqual(
    previewStationText({ name: "BOX JUMPS", reps: 12 }, 1),
    "12 BOX JUMPS",
    "scoreboard next should include essential fixed reps"
  );

  assert.strictEqual(
    scoreboardMovementText({ name: "RUN", meters: 1000 }, 1),
    "1000M RUN",
    "scoreboard current should include meters"
  );

  assert.strictEqual(
    scoreboardMovementText({ name: "SLED PUSH", meters: 60 }, 1),
    "60M SLED PUSH",
    "scoreboard current should include indoor meters"
  );

  assert.strictEqual(
    previewStationText({ name: "ROW", calories: 20 }, 1),
    "20 CAL ROW",
    "scoreboard next should include calories"
  );

  assert.strictEqual(
    scoreboardMovementText({ name: "PLANK", seconds: 30 }, 1),
    "30 SEC PLANK",
    "scoreboard current should include time targets"
  );

  const repScheme = [21, 15, 9];
  const schemeStations = [{ name: "THRUSTERS" }, { name: "PULL-UPS" }];
  assert.strictEqual(scoreboardMovementText(schemeStations[0], 1, repScheme), "21 THRUSTERS");
  assert.strictEqual(scoreboardMovementText(schemeStations[0], 2, repScheme), "15 THRUSTERS");
  assert.strictEqual(scoreboardMovementText(schemeStations[0], 3, repScheme), "9 THRUSTERS");
  assert.strictEqual(
    nextMovementText({ stationIndex: 0, roundNumber: 1, stations: schemeStations, rounds: 3, repScheme }),
    "21 PULL-UPS",
    "next should cross station boundaries within the same rep-scheme round"
  );
  assert.strictEqual(
    nextMovementText({ stationIndex: 1, roundNumber: 1, stations: schemeStations, rounds: 3, repScheme }),
    "15 THRUSTERS",
    "next should cross round boundaries with the next rep-scheme value"
  );
  assert.strictEqual(
    nextMovementText({ stationIndex: 1, roundNumber: 3, stations: schemeStations, rounds: 3, repScheme }),
    "Last station",
    "final rep-scheme station should not wrap"
  );
  const realSchemeStations = [
    { name: "BURPEES" },
    { name: "KETTLEBELL SWINGS", maleWeightKg: 24, femaleWeightKg: 16 },
    { name: "BOX JUMPS", maleHeightIn: 24, femaleHeightIn: 20 },
  ];
  assert.deepStrictEqual(
    [
      scoreboardMovementText(realSchemeStations[0], 1, repScheme),
      scoreboardMovementText(realSchemeStations[1], 1, repScheme),
      scoreboardMovementText(realSchemeStations[2], 1, repScheme),
      scoreboardMovementText(realSchemeStations[0], 2, repScheme),
      scoreboardMovementText(realSchemeStations[1], 2, repScheme),
      scoreboardMovementText(realSchemeStations[2], 2, repScheme),
      scoreboardMovementText(realSchemeStations[0], 3, repScheme),
      scoreboardMovementText(realSchemeStations[1], 3, repScheme),
      scoreboardMovementText(realSchemeStations[2], 3, repScheme),
    ],
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
    "watch scoreboard should use scheme reps while hiding kg and height metadata"
  );
  assert.strictEqual(layoutMode({ workoutType: "INTERVAL", structureType: "TIMED_INTERVAL" }), "INTERVAL");
  assert.strictEqual(layoutMode({ workoutType: "UNKNOWN", structureType: "UNKNOWN" }), "STANDARD");

  assert.strictEqual(sourceVisible({ running: true, elapsedBeforePause: 0 }), false);
  assert.strictEqual(controlHint({ running: true, elapsedBeforePause: 0 }), null);
  assert.strictEqual(controlHint({ running: false, elapsedBeforePause: 12 }), "START resume");
  assert.strictEqual(controlHint({ running: false, elapsedBeforePause: 0 }), "START start");
  assert.strictEqual(liveHeartRateText(156), "156");
  assert.strictEqual(liveHeartRateText(null), "--");
  assertHeaderDoesNotOverlap({ roundText: "R1/3", timeText: "0:00", heartRateText: "69" });
  assertHeaderDoesNotOverlap({ roundText: "R1/8", timeText: "0:00", heartRateText: "69" });
  assertHeaderDoesNotOverlap({ roundText: "R1/8", timeText: "0:00", heartRateText: "--" });
  assertHeaderDoesNotOverlap({ roundText: "R10/12", timeText: "9:59", heartRateText: "198" });
  assertHeaderDoesNotOverlap({ roundText: "R3/3", timeText: "59:59", heartRateText: "--" });
  assertHeaderDoesNotOverlap({ roundText: "R10/12", timeText: "59:59", heartRateText: "198" });
  assertHeaderDoesNotOverlap({ roundText: "R12/12", timeText: "1:02:34", heartRateText: "175" });

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
