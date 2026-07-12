# Garmin WOD Workout JSON Contract

This contract is the handoff between the importer, the local server, and the watch build flow.

## Version 1

```json
{
  "schemaVersion": 1,
  "id": "for-time-100m-run-100-push-ups",
  "title": "For Time",
  "type": "For Time",
  "durationMinutes": null,
  "rounds": null,
  "notes": [],
  "sourceText": "For Time\n100m Run\n100 Push-ups",
  "createdAt": "2026-07-12T00:00:00.000Z",
  "updatedAt": "2026-07-12T00:00:00.000Z",
  "stations": [
    {
      "id": "station-1",
      "name": "Run",
      "reps": null,
      "calories": null,
      "meters": 100,
      "weightLb": null,
      "workSeconds": 60,
      "notes": "100m Run"
    },
    {
      "id": "station-2",
      "name": "Push-ups",
      "reps": 100,
      "calories": null,
      "meters": null,
      "weightLb": null,
      "workSeconds": 60,
      "notes": "100 Push-ups"
    }
  ]
}
```

## Field Rules

- `schemaVersion`: Required number. Current version is `1`.
- `id`: Required stable-ish string for this workout.
- `title`: Required display title from the source text or user edits.
- `type`: Required. Allowed values are `Unknown`, `EMOM`, `AMRAP`, `For Time`, or `Tabata`.
- `durationMinutes`: Number or `null`. For Time workouts usually use `null`.
- `rounds`: Number or `null`.
- `notes`: Array of strings for extra context that does not map cleanly to one station, such as gender-specific weights.
- `sourceText`: Original extracted or pasted WOD text.
- `createdAt` / `updatedAt`: ISO timestamps.
- `stations`: Ordered array of workout stations.

## Station Rules

- `id`: Required station identifier, usually `station-1`, `station-2`, etc.
- `name`: Required station name, such as `Run`, `Deadlifts`, or `Push-ups`.
- `reps`: Number or `null`.
- `calories`: Number, string, or `null`. Strings allow values like `10/7`.
- `meters`: Number or `null`.
- `weightLb`: Number or `null`.
- `workSeconds`: Number or `null`. For Time workouts can leave this null unless you want a suggested station target.
- `notes`: Original line or extra station context.

When a field is unknown, use `null`; do not omit it. The watch-side conversion can then rely on every station having the same shape.

## Local Workflow

1. Import or paste a workout in the importer.
2. Make any edits in the structured output.
3. Click `Save Latest WOD`.
4. Run `npm run sync:watch` to regenerate `GarminWOD/source/GarminWODWorkout.mc`.
5. Run `npm run build:watch` to create `GarminWOD/bin/GarminWOD.prg`.
6. Copy `GarminWOD/bin/GarminWOD.prg` to the watch's `GARMIN/APPS` folder.

`npm run build:watch` also runs `sync:watch`, so the shorter path after saving is usually just:

```sh
npm run build:watch
```
