# TauSafe observation server

Node.js 22+; no npm dependencies. This local prototype serves `build/web` and the AI API on the same origin. Start from the project directory:

```powershell
node server/server.mjs
```

Without credentials, the entire catalog, 3D map, drone simulation and scripted observations work. The AI panel explicitly shows that AI is not connected.

To enable real image comparison, copy `.env.example` to `.env` in this directory and privately fill `OPENAI_API_KEY` and `OPENAI_MODEL` with a model in your account supporting image input and structured outputs. Then:

```powershell
node --env-file=server/.env server/server.mjs
```

Never ship `.env` in archives or put the key in Flutter. The app lets the operator pick two local images, confirms BEFORE/AFTER order and transmission to OpenAI, and places the returned comparison in the observation feed. The selected place is a user-supplied label, not an AI-derived location. No identity recognition, autonomous flight commands, missing-person confirmation, emergency dispatch or real-time drone camera ingest is implemented. Model findings require human review.

`GET /api/health` exposes only configuration status; `POST /api/analyze` accepts `before` and `after` data URLs (JPEG/PNG/WebP, ≤4 MB each) and `place`. Results contain `source: ai_uploaded_frames`, `needsReview: true`, `summary`, `changes`, and timestamp. No uploaded frames are stored by this server. API requests set `store:false`. This is a loopback-only development service, with same-origin checks, body limits, timeout and four requests/minute; deploy only after adding operator authentication, secure transport and an appropriate data retention policy.

Real drone integration next requires an authorized camera/telemetry adapter, capture timestamps and georeferencing, authenticated event ingestion, an operator review workflow and field validation. Simulated charge values, paths and events are never passed off as real measurements.

Implementation references: [image inputs](https://developers.openai.com/api/docs/guides/images-vision), [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs). Tests: `node --test server/server.test.mjs` (mock provider, no billable calls).
