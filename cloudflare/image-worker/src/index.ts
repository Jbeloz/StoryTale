const MODEL = "@cf/black-forest-labs/flux-1-schnell" as const;
const STEPS = 4;
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type StoryTaleEnv = Env & { APP_TOKEN?: string };
type ImageKind = "sprite" | "background";
type TimingSafeSubtleCrypto = SubtleCrypto & {
  timingSafeEqual(left: ArrayBuffer, right: ArrayBuffer): boolean;
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: CORS_HEADERS });
}

async function tokensMatch(provided: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [providedHash, expectedHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  return (crypto.subtle as TimingSafeSubtleCrypto).timingSafeEqual(
    providedHash,
    expectedHash,
  );
}

async function isAuthorized(request: Request, token: string): Promise<boolean> {
  const header = request.headers.get("Authorization") ?? "";
  const provided = header.startsWith("Bearer ") ? header.slice(7) : "";
  const authorized = await tokensMatch(provided, token);
  if (!authorized) {
    console.warn(JSON.stringify({
      message: "auth_rejected",
      providedLength: provided.length,
      expectedLength: token.length,
    }));
  }
  return authorized;
}

function parseBody(value: unknown): { prompt: string; kind: ImageKind } | null {
  if (!value || typeof value !== "object") return null;
  const body = value as Record<string, unknown>;
  const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
  const kind = body.kind;

  if (prompt.length < 3 || prompt.length > 500) return null;
  if (kind !== "sprite" && kind !== "background") return null;
  return { prompt, kind };
}

function buildPrompt(prompt: string, kind: ImageKind): string {
  const format = kind === "sprite"
    ? "single full-body character, centered, neutral pose, plain light background"
    : "wide scene background, no characters, clear foreground and background layers";

  return [
    "Age-appropriate 2D children's storybook illustration",
    format,
    prompt,
    "consistent clean shapes, no words, no logo, no watermark",
  ].join(". ");
}

async function handleGenerate(request: Request, env: StoryTaleEnv): Promise<Response> {
  if (!env.APP_TOKEN) return json({ error: "Image service is not configured" }, 503);
  if (!(await isAuthorized(request, env.APP_TOKEN))) {
    return json({ error: "Unauthorized" }, 401);
  }

  const contentLength = Number(request.headers.get("Content-Length") ?? 0);
  if (contentLength > 4096) return json({ error: "Request is too large" }, 413);
  if (!request.headers.get("Content-Type")?.includes("application/json")) {
    return json({ error: "Content-Type must be application/json" }, 415);
  }

  let value: unknown;
  try {
    value = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const body = parseBody(value);
  if (!body) {
    return json({ error: "Use a 3-500 character prompt and kind sprite or background" }, 400);
  }

  const rateLimit = await env.IMAGE_RATE_LIMIT.limit({ key: "private-prototype" });
  if (!rateLimit.success) return json({ error: "Try again in one minute" }, 429);

  const requestId = crypto.randomUUID();
  const result = await env.AI.run(MODEL, {
    prompt: buildPrompt(body.prompt, body.kind),
    steps: STEPS,
  });

  if (!result.image) throw new Error("Workers AI returned no image");
  const binary = atob(result.image);
  const image = Uint8Array.from(binary, (character) => character.charCodeAt(0));

  console.log(JSON.stringify({
    message: "image_generated",
    requestId,
    kind: body.kind,
    model: MODEL,
    steps: STEPS,
  }));

  return new Response(image, {
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "image/jpeg",
      "Cache-Control": "no-store",
      "X-Request-Id": requestId,
    },
  });
}

export default {
  async fetch(request: Request, env: StoryTaleEnv): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        status: "ok",
        service: "storytale-image-worker",
        model: MODEL,
        authConfigured: Boolean(env.APP_TOKEN),
      });
    }

    try {
      if (request.method === "POST" && url.pathname === "/generate") {
        return await handleGenerate(request, env);
      }
      return json({ error: "Not found" }, 404);
    } catch (error) {
      console.error(JSON.stringify({
        message: "image_generation_failed",
        path: url.pathname,
        error: error instanceof Error ? error.message : "Unknown error",
      }));
      return json({ error: "Image generation failed" }, 502);
    }
  },
} satisfies ExportedHandler<StoryTaleEnv>;
