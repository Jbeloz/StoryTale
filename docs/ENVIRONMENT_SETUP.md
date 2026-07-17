# StoryTale Environment Setup

The repository root contains an ignored `.env` file for local development:

```dotenv
DEEPL_API_KEY=
GEMINI_API_KEY=
GEMINI_MODEL=gemini-3.5-flash
```

Add the DeepL and Gemini keys after the equals signs. Never add real keys to
`.env.example`, screenshots, documentation, or Git.

`GEMINI_MODEL` is configurable so StoryTale can change models without changing
the analysis code. The current planned default is the stable
`gemini-3.5-flash` model. Gemini analysis must request structured JSON that
matches the StoryTale chapter-analysis schema.

The `.env` file is prepared but is not loaded by Flutter yet. During the first
implementation, a local story-analysis service will read it. Do not bundle the
file as a Flutter asset: keys compiled into a web or mobile client can be
extracted. Before distributing the app, move DeepL and Gemini keys into a
server-side proxy or Worker secret and let Flutter call that protected endpoint.

References:

- [Gemini models](https://ai.google.dev/gemini-api/docs/models)
- [Gemini structured outputs](https://ai.google.dev/gemini-api/docs/structured-output)
- [Gemini API key security](https://ai.google.dev/gemini-api/docs/api-key)
