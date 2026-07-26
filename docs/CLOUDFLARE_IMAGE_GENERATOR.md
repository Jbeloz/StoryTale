# StoryTale Private Media and Analysis Worker

The current Worker route and the planned final provider are intentionally
separate below. See the [Master Roadmap](ROADMAP.md) for the current phase.

## Provider decision

- Gemini analyzes cleaned chapter text into structured story data.
- Gemini 3.1 Flash Image creates one reviewed full-body character master.
- Cloudflare Workers AI creates chapter backgrounds only.

## Simple flow

```text
ChapterStory artwork request
-> private StoryTale Cloudflare Worker
-> /analyze -> Gemini structured chapter plan
-> kind=sprite -> one Gemini full-body master image
-> kind=background -> current FLUX.1 square smoke-test route
-> planned visual-novel background -> landscape SDXL
-> generated image
-> local review and storage
-> Story Mode scene
```

Worker folder: `cloudflare/image-worker/`

Endpoint: `https://storytale-image-worker.jbalejoshift0928.workers.dev`

## API

- `GET /health` checks the Worker.
- `POST /analyze` accepts one cleaned chapter plus its approved story catalog
  and returns a schema-validated `ChapterStoryData` plan.
- `POST /generate?kind=background` accepts multipart form data.
- `POST /generate?kind=sprite` sends the prompt and three reference images to Gemini.
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
5. Enter the description and generate the master. Compare the source, locally
   split head/body layers, and rejoined transparent preview.

The Flutter client is
`lib/src/features/animated_story/data/story_artwork_service.dart`.

The health response reports the analysis, sprite, and background providers and
whether Gemini is configured.
The Flutter review page attaches the bundled proportion, approved-head, and
approved-body references automatically. Gemini is called once; Flutter removes
green and produces the matching head/body layers locally.

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
