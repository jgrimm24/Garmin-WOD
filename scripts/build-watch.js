const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const PROJECT_DIR = path.join(ROOT, "GarminWOD");
const SDK_ROOT = path.join(process.env.HOME, "Library", "Application Support", "Garmin", "ConnectIQ", "Sdks");
const DEFAULT_SDK_NAME = "connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2";
const SDK_PATH = process.env.CONNECTIQ_SDK_PATH || path.join(SDK_ROOT, DEFAULT_SDK_NAME);
const MONKEYBRAINS = path.join(SDK_PATH, "bin", "monkeybrains.jar");
const KEY_PATH = process.env.GARMIN_DEVELOPER_KEY || path.join(PROJECT_DIR, "developer_key.der", "developer_key");
const DEVICE = process.env.GARMIN_DEVICE || "fenix847mm_sim";
const OUTPUT = path.join(PROJECT_DIR, "bin", "GarminWOD.prg");
const JUNGLE = path.join(PROJECT_DIR, "monkey.jungle");

if (!fs.existsSync(MONKEYBRAINS)) {
  throw new Error(`Connect IQ compiler not found at ${MONKEYBRAINS}. Set CONNECTIQ_SDK_PATH if your SDK moved.`);
}

if (!fs.existsSync(KEY_PATH)) {
  throw new Error(`Developer key not found at ${KEY_PATH}. Set GARMIN_DEVELOPER_KEY if your key moved.`);
}

fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });

const args = [
  "-Xms1g",
  "-Dfile.encoding=UTF-8",
  "-Dapple.awt.UIElement=true",
  "-jar",
  MONKEYBRAINS,
  "-o",
  OUTPUT,
  "-f",
  JUNGLE,
  "-y",
  KEY_PATH,
  "-d",
  DEVICE,
  "-w",
];

const result = childProcess.spawnSync("java", args, {
  cwd: PROJECT_DIR,
  stdio: "inherit",
});

if (result.error) {
  throw result.error;
}

process.exit(result.status === null ? 1 : result.status);
