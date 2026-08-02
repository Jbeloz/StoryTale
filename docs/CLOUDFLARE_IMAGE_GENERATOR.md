# StoryTale Private Media and Analysis Worker

The current Worker route and the planned final provider are intentionally
separate below. See the [Master Roadmap](ROADMAP.md) for the current phase.

## Provider decision

- Gemini analyzes cleaned chapter text into structured story data.
- Gemini 3.1 Flash Image creates one canonical separated character sheet plus
  source-required loose-garment and accessory components for an immutable local
  Sprite Studio rig.
- Cloudflare Workers AI creates chapter backgrounds only.

## Simple flow

```text
ChapterStory artwork request
-> private StoryTale Cloudflare Worker
-> /analyze -> Gemini structured chapter plan
-> kind=sprite -> Gemini character component sheets
-> kind=background -> current FLUX.1 square smoke-test route
-> planned visual-novel background -> landscape SDXL
-> generated component sheet
-> local green removal, fixed-manifest cut, hard masks, locked-rig composition, and storage
-> Story Mode scene
```

Worker folder: `cloudflare/image-worker/`

Endpoint: `https://storytale-image-worker.jbalejoshift0928.workers.dev`

## API

- `GET /health` checks the Worker.
- `POST /analyze` accepts one cleaned chapter plus its approved story catalog
  and returns a schema-validated `ChapterStoryData` plan.
- `POST /generate?kind=background` accepts multipart form data.
- `POST /generate?kind=sprite` currently sends the prompt and references to
  Gemini. Phase 7G.1 replaces its complete-character `master` request with
  face, hair, canonical clothing-only, and accessory component requests.
- `prompt` is required and must contain 3-500 characters.
- Up to four small reference images may lock a recurring character or location style.
- Successful generation returns raw image bytes.
- The Worker keeps both `APP_TOKEN` and `GEMINI_API_KEY` as secrets.

The current FLUX.1 request proves the private Worker and Workers AI binding are
operational, but its square result is not the final Story Mode background. The
planned route uses SDXL at `1024 x 576` and follows the
[Visual-Novel Background Plan](VISUAL_NOVEL_BACKGROUND_PLAN.md).

## Flutter test

1. Open a book and choose Story Mode.
2. Prepare the chapter.
3. Open `Review Sprites & Backgrounds`.
4. Choose Sprite or Background.
5. Prepare the missing character layers. Compare the fixed local head/body
   against the locally composed face, hair, clothing, and accessory result.

The Flutter client is
`lib/src/features/animated_story/data/story_artwork_service.dart`.

The health response reports the analysis, sprite, and background providers and
whether Gemini is configured.
The current Flutter prototype attaches geometry references and asks Gemini for
one finished character, then removes green and divides that image locally.
That flow proved connectivity but cannot enforce the fixed Sprite Studio
silhouette. Phase 7G.1 keeps the local head/body unchanged and uses the Worker
only for missing appearance component sheets.

For fitted clothing, the Worker forwards the exact versioned guide and semantic
outfit brief. Flutter owns the crop manifest and local masks; neither the Worker
nor Gemini discovers cell boundaries. See
[Character Sheet V1 Plan](CHARACTER_SHEET_PLAN.md).

## Sprite request throughput

The Worker is not a Cloudflare Tunnel and does not edit Gemini sprite bytes. It
is a small authenticated backend proxy that protects the server-side Gemini
key. Google recommends a backend proxy because keys embedded in Flutter web or
mobile applications can be extracted.

The current repository adds two StoryTale-specific limits:

- the Worker `IMAGE_RATE_LIMIT` allows three generation calls per 60 seconds
  using one shared prototype key; and
- the Flutter volume-preparation coordinator also allows three artwork calls
  per 60 seconds.

These are project choices, not required Cloudflare or Gemini settings. Phase
7G.1 removes or disables both small private sprite-component bottlenecks while
keeping one in-flight call, sequential queuing, design-hash deduplication,
resume from the first missing component, and no automatic paid regeneration.

External capacity is still not unlimited. Cloudflare enforces the account's
Workers plan limits, while Gemini enforces model/project RPM, image-per-minute,
daily, billing-tier, and spend-based limits. The app must show the real provider
error when one is reached.

Official current references:

- https://developers.cloudflare.com/workers/platform/limits/
- https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
- https://ai.google.dev/gemini-api/docs/rate-limits
- https://ai.google.dev/gemini-api/docs/api-key

## Deployment

```powershell
cd cloudflare/image-worker
npm install
npm run check
npm run deploy:dry
npm run deploy
```

Before deployment, set the secrets without placing them in `wrangler.jsonc`:

```powershell
npx wrangler secret put APP_TOKEN
npx wrangler secret put GEMINI_API_KEY
```

The matching prototype client token stays in the ignored root `.env`; never
commit or print either secret. The shared client-token flow is acceptable only
for the private school prototype. A distributed app needs real user
authentication and per-user quotas.

Gemini image models are paid API models. If the Google project has no billing,
the Worker returns a clear quota message to Flutter instead of a generic image
failure.
