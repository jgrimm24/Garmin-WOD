# Garmin-WOD

Garmin-WOD is a Connect IQ watch app for running CrossFit-style workouts from a parsed WOD contract. The app keeps the WOD structure on the watch: station order, AMRAP timers, EMOM timing, For Time flow, manual station advancement, GPS distance progress, physical-button controls, and cached/latest workout loading.

## Native Garmin Activity Recording

Garmin-WOD now starts a native Garmin `ActivityRecording.Session` when you start a workout. That session records the physiological activity and saves a FIT activity when the workout finishes, so completed workouts can sync into Garmin Connect.

The WOD logic remains app-managed. Garmin's recording pipeline handles the activity file, sensor data, and Garmin Connect post-processing after sync.

## Sensor Notes

- Pair chest straps or other sensors to the watch before starting Garmin-WOD.
- Before recording starts, Garmin-WOD enables the Garmin heart-rate sensor stream and listens for `Sensor.Info.heartRate`.
- Live heart rate prefers the Sensor callback value, then falls back to Garmin activity info if the callback has not produced a valid value.
- The app reads live distance and calories from Garmin activity info.
- Average and max heart rate are calculated by Garmin-WOD from valid samples while the recording session is active.
- Heart-rate samples below 30 bpm or above 250 bpm are ignored.
- Garmin Connect calculates Training Effect, recovery, load, and related post-workout metrics after the activity syncs.

## Save And Exit Behavior

- START begins recording and starts the WOD timer.
- START while running pauses the WOD and stops the recording session.
- START while paused resumes the same recording session.
- Finishing the workout stops and saves the activity.
- If saving fails, START retries the save and BACK discards the unsaved recording.
- Resetting before a workout is saved discards the open recording session.
- Exiting with an unsaved recording shows a confirmation first: START continues the workout, UP confirms discard and exits.

## Current Limitations

- Garmin-WOD does not add custom FIT developer fields yet.
- Garmin-WOD does not directly pair ANT+, BLE, or HRM-Pro sensors; it relies on the watch's normal paired-sensor hierarchy.
- The watch summary captures calories and native distance immediately before saving. Distance is only shown for workouts that include a meters/distance station.
- More advanced metrics should be reviewed in Garmin Connect after sync.
- The importer/backend flow is separate from the watch recording lifecycle.
