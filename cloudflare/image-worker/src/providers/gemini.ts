/// The Google Gemini image adapter.
///
/// Moved out of `index.ts` unchanged: same endpoint, same request body, same
/// response parsing, same error mapping. `test/providers.test.ts` snapshots the
/// body it builds for every mode, because a refactor of the only path StoryTale
/// pays for has to be provably identical before it is deployed.

import {
  base64ToBytes,
  bytesToBase64,
  imageDetails,
  isRecord,
  PublicWorkerError,
} from "../shared";
import type {
  ImageProvider,
  ImageProviderEnv,
  ProviderCapabilities,
  ProviderImageRequest,
  ProviderImageResult,
} from "./types";

const GEMINI_IMAGE_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/interactions";

/// JPEG is the only output this endpoint supports. Measured on 2026-08-06:
/// omitting mime_type returned image/jpeg, and asking for image/png returned
/// HTTP 400 "The value 'image/png' is not supported for
/// 'response_format.mime_type'. Supported values: 'image/jpeg'."
///
/// That is tolerable because the processor finds the background with a tolerant
/// test (green >= 160 && green >= red+40 && green >= blue+40) rather than an
/// exact match. Re-encoding the V4 guide as JPEG moved the "pixels outside the
/// masks" count by about 90 out of 1,048,576. What does collapse is the exact
/// #00FF00 count, which only drives a secondary removal path and a metric.
const GEMINI_OUTPUT_MIME = "image/jpeg";

/// The reference count and prompt length are the ceilings **StoryTale** enforces
/// in `parseBody`, not documented Google maxima, which have not been measured.
/// They are declared here so a caller comparing providers sees the limit it will
/// actually hit.
const geminiCapabilities: ProviderCapabilities = {
  supportsTransparentOutput: false,
  outputMimeTypes: [GEMINI_OUTPUT_MIME],
  maxReferenceImages: 5,
  maxPromptLength: 12_000,
};

/// Pulls the image out of an interactions response, newest step first.
function findGeminiImage(
  value: unknown,
): { data: string; mimeType: string } | null {
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
          mimeType: typeof part.mime_type === "string"
            ? part.mime_type
            : GEMINI_OUTPUT_MIME,
        };
      }
    }
  }
  return null;
}

/// Pulls the human-readable reason out of a Google error body, falling back to
/// a trimmed snippet. Google returns `{"error":{"message":"..."}}`, and its
/// validation messages name the field they rejected.
function geminiErrorMessage(details: string): string {
  try {
    const parsed = JSON.parse(details) as { error?: { message?: string } };
    const message = parsed.error?.message;
    if (message) return message.slice(0, 300);
  } catch {
    // Not JSON; fall through to the raw snippet.
  }
  return details.slice(0, 300) || "no detail returned";
}

/// Exported so the request body can be asserted without a network call.
///
/// Key order matters here: it is what makes a snapshot comparison against the
/// pre-refactor body meaningful.
export function buildGeminiImageBody(
  request: ProviderImageRequest,
  model: string,
): Record<string, unknown> {
  const input: Array<Record<string, string>> = [
    { type: "text", text: request.prompt },
  ];
  for (const reference of request.references) {
    input.push({
      type: "image",
      mime_type: reference.mimeType,
      data: bytesToBase64(reference.bytes),
    });
  }

  return {
    model,
    input,
    response_format: {
      type: "image",
      mime_type: GEMINI_OUTPUT_MIME,
      aspect_ratio: request.spec.aspectRatio,
      // This line, not the manifest, is what StoryTale is billed for: 1K is
      // $0.067 against 4K's $0.151 on gemini-3.1-flash-image.
      image_size: request.spec.imageSize,
    },
    store: false,
  };
}

export const geminiImageProvider: ImageProvider = {
  name: "google-gemini",
  capabilities: geminiCapabilities,

  modelFor(env: ImageProviderEnv): string {
    return env.GEMINI_IMAGE_MODEL ?? "";
  },

  async generate(
    request: ProviderImageRequest,
    env: ImageProviderEnv,
  ): Promise<ProviderImageResult> {
    if (!env.GEMINI_API_KEY) throw new Error("Gemini is not configured");

    const model = env.GEMINI_IMAGE_MODEL ?? "";
    const response = await fetch(GEMINI_IMAGE_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": env.GEMINI_API_KEY,
      },
      body: JSON.stringify(buildGeminiImageBody(request, model)),
    });
    if (!response.ok) {
      // Every other Gemini path already logs the body. This one did not, so a
      // 400 arrived as a bare status with no way to tell which field was
      // rejected.
      const details = (await response.text()).slice(0, 1_000);
      console.error(JSON.stringify({
        message: "gemini_request_failed",
        status: response.status,
        model,
        mode: request.mode,
        details,
      }));
      if (response.status === 429) {
        throw new PublicWorkerError(
          "Gemini image quota is unavailable. Enable Gemini API billing or try again after the quota resets.",
          429,
        );
      }
      if (response.status === 401 || response.status === 403) {
        throw new PublicWorkerError("The Gemini API key was rejected by Google.", 503);
      }
      if (response.status === 400) {
        // A 400 is a rejected request, not a generation, so it is the cheap
        // failure to diagnose. Surface Google's own wording: it names the
        // offending field, which a bare status does not.
        throw new PublicWorkerError(
          `Gemini rejected the ${request.mode} request (HTTP 400): ${geminiErrorMessage(details)}`,
          502,
        );
      }
      throw new PublicWorkerError(
        `Gemini rejected the character-sheet request (HTTP ${response.status}).`,
        502,
      );
    }

    const image = findGeminiImage(await response.json<unknown>());
    if (!image) {
      throw new PublicWorkerError("Gemini completed without returning an image.", 502);
    }
    const bytes = base64ToBytes(image.data);
    const details = imageDetails(bytes);
    if (!details) {
      throw new PublicWorkerError("Gemini returned an unsupported image format.", 502);
    }
    return { bytes, ...details };
  },
};
