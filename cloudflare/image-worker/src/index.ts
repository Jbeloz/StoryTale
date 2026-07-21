const BACKGROUND_MODEL = "@cf/black-forest-labs/flux-2-klein-4b" as const;
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Expose-Headers": "X-Image-Model, X-Image-Provider, X-Request-Id",
};

type StoryTaleEnv = Env & {
  APP_TOKEN?: string;
  GEMINI_API_KEY?: string;
};
type ImageKind = "background" | "sprite";
type SpriteMode = "master" | "head-design" | "head-expression" | "face-layer" | "body-pose";
type TimingSafeSubtleCrypto = SubtleCrypto & {
  timingSafeEqual(left: ArrayBuffer, right: ArrayBuffer): boolean;
};

class PublicImageError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

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
    console.warn(JSON.stringify({ message: "auth_rejected" }));
  }
  return authorized;
}

async function parseBody(request: Request) {
  const form = await request.formData();
  const prompt = String(form.get("prompt") ?? "").trim();
  if (prompt.length < 3 || prompt.length > 500) return null;

  const references: File[] = [];
  let referenceBytes = 0;
  for (let index = 0; index < 4; index++) {
    const file = form.get(`input_image_${index}`);
    if (!(file instanceof File) || file.size === 0) continue;
    if (file.type !== "application/octet-stream" && !file.type.startsWith("image/")) {
      return null;
    }
    references.push(file);
    referenceBytes += file.size;
  }
  if (referenceBytes > 1536 * 1024) return null;
  return { prompt, references };
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 32_768) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 32_768));
  }
  return btoa(binary);
}

function base64ToBytes(data: string): Uint8Array {
  const binary = atob(data);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function findGeminiImage(value: unknown): { data: string; mimeType: string } | null {
  if (!isRecord(value) || !Array.isArray(value.steps)) return null;
  for (let stepIndex = value.steps.length - 1; stepIndex >= 0; stepIndex--) {
    const step = value.steps[stepIndex];
    if (
      !isRecord(step) ||
      step.type !== "model_output" ||
      !Array.isArray(step.content)
    ) continue;
    for (let partIndex = step.content.length - 1; partIndex >= 0; partIndex--) {
      const part = step.content[partIndex];
      if (
        isRecord(part) &&
        part.type === "image" &&
        typeof part.data === "string"
      ) {
        return {
          data: part.data,
          mimeType: typeof part.mime_type === "string" ? part.mime_type : "image/jpeg",
        };
      }
    }
  }
  return null;
}

function spritePrompt(details: string, mode: SpriteMode): string {
  if (mode === "face-layer") {
    return `Edit only the supplied transparent facial-feature layer: ${details}. ` +
      "The reference is a layer, not a complete head. Output only the two eyes, two eyebrows, small nose mark, and mouth needed for the expression, aligned at the exact same canvas coordinates, scale, spacing, line thickness, grayscale colors, and art style. " +
      "Keep every unchanged feature identical. Do not draw skin, a face fill, head silhouette, ear, hair, neck, body, accessories, text, border, or extra features. Keep the entire 1:1 canvas and do not crop, rotate, resize, or recenter anything. " +
      "Do not use green in the facial features. Fill every pixel outside the isolated facial features with flat pure chroma green #00FF00 for local transparency removal.";
  }
  if (mode === "head-expression") {
    return `Edit only the expression of the supplied head reference: ${details}. ` +
      "Treat the supplied image as locked geometry. Preserve the exact outer head silhouette, canvas framing, head size, ear, skin shading, line thickness, facial-feature style, and the position of every unchanged feature. " +
      "Change only the eyes, eyebrows, and mouth needed for the requested expression; add tears only when requested. Do not add or remove hair, a neck, shoulders, a body, accessories, text, borders, or extra faces. " +
      "Keep one front-facing head at the same scale. Do not crop, rotate, recenter, or redesign it. Do not use green in the face. Fill only the area outside the head with flat pure chroma green #00FF00 for local background removal.";
  }
  if (mode === "body-pose") {
    return `Edit only the pose of the supplied body reference: ${details}. ` +
      "Treat the supplied image as locked character geometry. Preserve the exact body design, small-body proportions, neck opening, torso length and width, limb thickness, hands, feet, colors, shading, line thickness, and overall drawing style. " +
      "Change only the arm and leg positions needed for the requested pose. Show one complete body from the neck opening to both feet with no head, face, hair, text, border, props, or extra body parts. " +
      "Keep the body centered at the same overall scale and fully inside the tall canvas with clear space around every limb. Do not use green in the body. Fill only the outside area with flat pure chroma green #00FF00 for local background removal.";
  }
  if (mode === "head-design") {
    return `Edit the supplied head template into this character: ${details}. ` +
      "Treat the supplied image as locked geometry, not loose inspiration. Preserve the exact outer head silhouette, head size, ear shape and position, front-facing angle, facial proportions, eye shapes and coordinates, eyebrows, nose dot, mouth, and edge-to-edge framing. " +
      "Only add the requested hair design, skin and eye colors, clean dark line art, and simple cel shading over the existing base. Keep the head equally large on the same square canvas; do not shrink, rotate, crop, recenter, or redesign the base face. " +
      "Show one head only with no neck, shoulders, body, hands, text, labels, border, accessories, or extra character. Keep all hair inside the canvas. Do not use green in the character design. " +
      "Fill only the area outside the head with flat pure chroma green #00FF00 for local background removal.";
  }
  return `Create one reusable 2D storybook character master for: ${details}. ` +
    "Use the supplied full-proportion, approved-head, and approved-body images as strict references. " +
    "Show exactly one complete centered character from head to feet in a neutral front-facing pose. " +
    "Keep the oversized head and small body proportions, and make a clean narrow neck connection near 46% of the canvas height. " +
    "Use clean dark line art and simple cel shading. Do not use green anywhere in the character design. " +
    "Fill the entire background with one flat pure chroma green #00FF00 for automatic removal. " +
    "Leave a clear green margin around the character, including below both feet. " +
    "No scenery, floor, shadow, text, labels, border, extra body parts, or additional characters.";
}

async function generateBackground(
  body: ReadableStream<Uint8Array> | undefined,
  contentType: string | undefined,
  env: StoryTaleEnv,
): Promise<{ bytes: Uint8Array; mimeType: string }> {
  const result = await env.AI.run(BACKGROUND_MODEL, {
    multipart: {
      body,
      contentType,
    },
  });
  if (!result.image) throw new Error("Workers AI returned no image");
  return { bytes: base64ToBytes(result.image), mimeType: "image/jpeg" };
}

async function generateSprite(
  prompt: string,
  references: File[],
  mode: SpriteMode,
  env: StoryTaleEnv,
): Promise<{ bytes: Uint8Array; mimeType: string }> {
  if (!env.GEMINI_API_KEY) throw new Error("Gemini is not configured");

  const input: Array<Record<string, string>> = [
    { type: "text", text: spritePrompt(prompt, mode) },
  ];
  for (const reference of references) {
    input.push({
      type: "image",
      mime_type: reference.type.startsWith("image/") ? reference.type : "image/png",
      data: bytesToBase64(new Uint8Array(await reference.arrayBuffer())),
    });
  }

  const response = await fetch("https://generativelanguage.googleapis.com/v1beta/interactions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": env.GEMINI_API_KEY,
    },
    body: JSON.stringify({
      model: env.GEMINI_IMAGE_MODEL,
      input,
      response_format: {
        type: "image",
        mime_type: "image/jpeg",
        aspect_ratio: mode === "head-design" || mode === "head-expression" || mode === "face-layer"
          ? "1:1"
          : mode === "body-pose" ? "9:16" : "3:4",
        image_size: mode === "head-design" || mode === "head-expression" || mode === "face-layer" ? "1K" : "512",
      },
      store: false,
    }),
  });
  if (!response.ok) {
    console.error(JSON.stringify({
      message: "gemini_request_failed",
      status: response.status,
      model: env.GEMINI_IMAGE_MODEL,
    }));
    if (response.status === 429) {
      throw new PublicImageError(
        "Gemini image quota is unavailable. Enable Gemini API billing or try again after the quota resets.",
        429,
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new PublicImageError("The Gemini API key was rejected by Google.", 503);
    }
    throw new Error(`Gemini returned HTTP ${response.status}`);
  }

  const image = findGeminiImage(await response.json<unknown>());
  if (!image) throw new Error("Gemini returned no image");
  return { bytes: base64ToBytes(image.data), mimeType: image.mimeType };
}

async function handleGenerate(request: Request, env: StoryTaleEnv): Promise<Response> {
  if (!env.APP_TOKEN) return json({ error: "Image service is not configured" }, 503);
  if (!(await isAuthorized(request, env.APP_TOKEN))) {
    return json({ error: "Unauthorized" }, 401);
  }

  const contentLength = Number(request.headers.get("Content-Length") ?? 0);
  if (contentLength > 2 * 1024 * 1024) {
    return json({ error: "Request is too large" }, 413);
  }
  if (!request.headers.get("Content-Type")?.includes("multipart/form-data")) {
    return json({ error: "Content-Type must be multipart/form-data" }, 415);
  }

  const url = new URL(request.url);
  const kindValue = url.searchParams.get("kind") ?? "background";
  if (kindValue !== "background" && kindValue !== "sprite") {
    return json({ error: "kind must be background or sprite" }, 400);
  }
  const kind: ImageKind = kindValue;
  const modelRequest = request.clone();
  const body = await parseBody(request);
  if (!body) {
    return json({ error: "Use a 3-500 character prompt and up to four small image references" }, 400);
  }

  const rateLimit = await env.IMAGE_RATE_LIMIT.limit({ key: "private-prototype" });
  if (!rateLimit.success) return json({ error: "Try again in one minute" }, 429);

  let model: string = BACKGROUND_MODEL;
  let provider = "cloudflare-workers-ai";
  let result: { bytes: Uint8Array; mimeType: string };
  if (kind === "background") {
    result = await generateBackground(
      modelRequest.body ?? undefined,
      modelRequest.headers.get("Content-Type") ?? undefined,
      env,
    );
  } else {
    if (!env.GEMINI_API_KEY) return json({ error: "Gemini sprite generation is not configured" }, 503);
    const modeValue = url.searchParams.get("mode") ?? "master";
    if (
      modeValue !== "master" &&
      modeValue !== "head-design" &&
      modeValue !== "head-expression" &&
      modeValue !== "face-layer" &&
      modeValue !== "body-pose"
    ) {
      return json({
        error: "mode must be master, head-design, head-expression, face-layer, or body-pose",
      }, 400);
    }
    if (modeValue !== "master" && body.references.length !== 1) {
      return json({ error: `${modeValue} requires exactly one image reference` }, 400);
    }
    model = env.GEMINI_IMAGE_MODEL;
    provider = "google-gemini";
    result = await generateSprite(body.prompt, body.references, modeValue, env);
  }

  const requestId = crypto.randomUUID();
  console.log(JSON.stringify({
    message: "image_generated",
    requestId,
    kind,
    model,
    provider,
    references: body.references.length,
  }));

  const responseBody = new Uint8Array(result.bytes.byteLength);
  responseBody.set(result.bytes);
  return new Response(responseBody.buffer, {
    headers: {
      ...CORS_HEADERS,
      "Content-Type": result.mimeType,
      "Cache-Control": "no-store",
      "X-Image-Model": model,
      "X-Image-Provider": provider,
      "X-Request-Id": requestId,
    },
  });
}

export default {
  async fetch(request: Request, env: StoryTaleEnv): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        status: "ok",
        service: "storytale-image-worker",
        providers: {
          background: { provider: "cloudflare-workers-ai", model: BACKGROUND_MODEL },
          sprite: { provider: "google-gemini", model: env.GEMINI_IMAGE_MODEL },
        },
        authConfigured: Boolean(env.APP_TOKEN),
        geminiConfigured: Boolean(env.GEMINI_API_KEY),
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
      if (error instanceof PublicImageError) {
        return json({ error: error.message }, error.status);
      }
      return json({ error: "Image generation failed" }, 502);
    }
  },
} satisfies ExportedHandler<StoryTaleEnv>;
