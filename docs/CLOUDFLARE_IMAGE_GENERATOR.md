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
- `POST /generate?kind=sprite&mode=character-sheet` accepts the locked
  `character_sheet_v1` prompt plus exactly five references: guide, assembled
  reference, allowed mask, protected mask, and seam mask.
- The character-sheet request accepts up to 12,000 prompt characters and 8 MB
  of reference images; other modes retain the smaller 2,500-character,
  four-reference contract.
- Flutter sends contract/version, guide hash, geometry hash, selected back-hair
  cell, and a stable request fingerprint. The Worker rejects mismatches.
- Gemini 3.1 Flash Image is asked for one square 4K image without forcing the
  Interactions API MIME override; the provider's default lossless PNG is
  required. The Worker rejects any response that is not exactly `4096 x 4096`
  PNG.
- Successful generation returns raw image bytes plus provider, model, request
  ID, fingerprint, contract, width, and height response headers.
- The Worker keeps both `APP_TOKEN` and `GEMINI_API_KEY` as secrets.

The current FLUX.1 request proves the private Worker and Workers AI binding are
operational, but its square result is not the final Story Mode background. The
planned route uses SDXL at `1024 x 576` and follows the
[Visual-Novel Background Plan](VISUAL_NOVEL_BACKGROUND_PLAN.md).

## Flutter test

1. Open a book and choose Story Mode.
2. Open `Review Sprites & Backgrounds`.
3. Choose `Sheet` for the new contract or `Sprite` only for the legacy master.
4. Configure Actor, Hair, and Skin in Sprite Studio before a Sheet request.
5. Generate once only when the deployed Worker and Gemini billing are ready.
6. Phase 7G.1B.3 now validates, cuts, masks, packages, and locally composes the
   returned sheet. Phase 7G.1B.4 now adds the four-pose package review and six
   read-only proof groups; Phase 7G.1C owns the next exact-fidelity gate.

The Flutter client is
`lib/src/features/animated_story/data/story_artwork_service.dart`.

The health response reports the analysis, sprite, and background providers and
whether Gemini is configured.
The legacy Flutter prototype can still create one complete-character master,
but the new book-character path uses only the locked character-sheet contract.
Phase 7G.1 keeps the local head/body unchanged and uses the Worker only for
missing appearance layers.

Deployment note (2026-08-02): the first owner-controlled Character Sheet call
returned a Worker 502 and produced no package. The response-format compatibility
fix and safe provider error messages are deployed as Worker version
`ab9b22c9-b94a-4923-ae33-26eb16dbc808`. No automatic or second paid request was
made; the controlled rerun remains owner-approved work.

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
