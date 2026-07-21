# StoryTale Environment Setup

The repository root contains an ignored `.env` file for local development:

```dotenv
DEEPL_API_KEY=
GEMINI_API_KEY=
GEMINI_MODEL=gemini-3.5-flash
GEMINI_IMAGE_MODEL=gemini-3.1-flash-image
CLOUDFLARE_IMAGE_URL=https://storytale-image-worker.jbalejoshift0928.workers.dev
CLOUDFLARE_IMAGE_TOKEN=
```

Add the DeepL and Gemini keys after the equals signs. Never add real keys to
`.env.example`, screenshots, documentation, or Git.

`GEMINI_MODEL` is the stable `gemini-3.5-flash` story analyzer.
`GEMINI_IMAGE_MODEL` is the stable `gemini-3.1-flash-image` sprite generator.
Keeping them separate prevents an image-model change from changing chapter
analysis.

The run script passes only the private Worker URL and prototype client token to
Flutter. DeepL and Gemini keys stay out of the app. `GEMINI_API_KEY` is copied
to the deployed Worker as a Cloudflare secret for sprite generation; the later
story-analysis service will also keep its key server-side. Start StoryTale with:

```powershell
.\tool\run_storytale.ps1
```

For this local prototype, the Cloudflare token is compiled into the running
client. Do not use this client-token approach for a public release. Before
distribution, place user authentication in front of the Worker so a shared
secret is never shipped in the app.

The Worker model setting is stored as a non-secret variable in
`cloudflare/image-worker/wrangler.jsonc`. Set `GEMINI_API_KEY` with
`npx wrangler secret put GEMINI_API_KEY`; never place the key in that file.

Google currently provides no free API tier for Gemini image generation. A key
can be valid while image requests still return quota `0`. Enable billing for
the Google AI Studio project before testing sprite generation, then add user
authentication, quotas, and a spending limit before distributing the app.

References:

- [Gemini models](https://ai.google.dev/gemini-api/docs/models)
- [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- [Gemini structured outputs](https://ai.google.dev/gemini-api/docs/structured-output)
- [Gemini API key security](https://ai.google.dev/gemini-api/docs/api-key)
