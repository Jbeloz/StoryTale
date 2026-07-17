# StoryTale Cloudflare Image Generator

## Part 1 - Plan

1. Use a small Cloudflare Worker as the only public image endpoint.
2. Call Workers AI through the `AI` binding with `@cf/black-forest-labs/flux-1-schnell`.
3. Require a private prototype bearer token and apply a short rate limit before inference.
4. The current route returns JPEG. The planned sprite route applies foreground
   segmentation and returns a transparent PNG before final review.
5. Do not store EPUB text, prompts, or generated images in Cloudflare.

## Free allowance

- Workers AI includes 10,000 neurons per day on the Free plan and resets at 00:00 UTC.
- FLUX.1-schnell costs 4.8 neurons per 512x512 tile plus 9.6 neurons per step.
- At four steps, one 512x512 result is roughly 43.2 neurons, or about 230 results per day if no other AI usage consumes the allowance.
- The Worker also uses the normal Workers Free request allowance.

Current official references: [Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/), [FLUX.1-schnell](https://developers.cloudflare.com/workers-ai/models/flux-1-schnell/), and [Workers AI limits](https://developers.cloudflare.com/workers-ai/platform/limits/).

## Part 2 - Architecture and setup

```mermaid
flowchart LR
    A["StoryTale prompt"] --> B["Private Worker token"]
    B --> C["StoryTale Image Worker"]
    C --> D["Rate limit"]
    D --> E["Workers AI - FLUX.1-schnell"]
    E --> F["JPEG response"]
    F --> G["User review"]
    G --> H["Cloudflare Images foreground segmentation"]
    H --> I["Transparent PNG or normal background JPEG"]
    I --> J["Local reviewed story asset storage"]
```

Worker folder: `cloudflare/image-worker/`

Deployed endpoint: `https://storytale-image-worker.jbalejoshift0928.workers.dev`

The API stays small:

- `GET /health` checks that the Worker is online.
- `POST /generate` accepts `{"prompt":"...","kind":"sprite"}` or `kind: "background"`.
- `POST /generate` returns raw `image/jpeg` bytes.
- Generation uses four steps to balance speed, quality, and free allowance.

Deploy commands:

```powershell
cd cloudflare/image-worker
npm install
npx wrangler login
npm run cf:types
npm run check
npm run deploy:dry
npm run deploy
npx wrangler secret put APP_TOKEN
```

Never put the token in `wrangler.jsonc`, source code, screenshots, or commits. The Cloudflare login grants Wrangler access through OAuth; no Cloudflare API token is stored in StoryTale.

## Part 3 - Tests

1. `GET /health` must return HTTP 200.
2. `POST /generate` without the bearer token must return HTTP 401.
3. An invalid request must return HTTP 400 without spending AI allowance.
4. An authorized sprite request must return HTTP 200 and `Content-Type: image/jpeg`.
5. Open the saved test image and confirm it is usable before connecting Flutter.

Verified on July 15, 2026:

| Check | Result |
| --- | --- |
| `GET /health` | HTTP 200; authentication configured |
| Generation without token | HTTP 401 |
| Invalid authorized input | HTTP 400; AI was not called |
| Real sprite generation | HTTP 200, `image/jpeg`, 189,878 bytes |
| Visual review | Full-body storybook character on a clean light background |

The test file is at `cloudflare/image-worker/test-output/storytale-test-sprite.jpg`. The folder is ignored by Git.

The active token exists only as a Cloudflare secret and was not printed, committed, or kept in a local file. Rotate it when the Flutter client is connected so the matching client value can be supplied through private build configuration.

## Prototype security note

The bearer token is suitable for a private school prototype, but a value shipped inside a mobile app can be extracted. Before public release, replace the shared token with real user authentication and per-user quotas.

## Planned transparent sprites

The deployed FLUX.1-schnell route currently returns JPEG, so the existing test
does not have alpha transparency. The next Worker change will add a Cloudflare
Images binding named `IMAGES`, pass the generated sprite bytes through
`segment: "foreground"`, and return `image/png`. Background requests remain
normal JPEG or WebP.

Cloudflare documents foreground segmentation as replacing the background with
transparent pixels. Images Free currently includes up to 5,000 unique
transformations per month. This must still be tested on character hair, hands,
and clothing; manual transparent PNG replacement remains available.

- [Cloudflare Images foreground segmentation](https://developers.cloudflare.com/images/optimization/features/#segment)
- [Cloudflare Images binding](https://developers.cloudflare.com/images/optimization/binding/)
- [Cloudflare Images pricing](https://developers.cloudflare.com/images/pricing/)

Story Mode should send only a reviewed character or location description to
this Worker, never the entire EPUB. Asset reuse, review, and versioning are
defined in [Animated Story Mode plan](ANIMATED_STORY_MODE_PLAN.md).
