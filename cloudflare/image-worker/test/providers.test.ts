/// The Worker's first tests.
///
/// They exist because three of the eight paid V4 requests were spent on
/// plumbing defects that were reproducible offline for free. Moving the only
/// path StoryTale pays for behind a provider seam is exactly the kind of change
/// that can do it a fourth time, so the refactor is asserted to send what it
/// sent before rather than assumed to.

import { describe, expect, it } from "vitest";

import { buildGeminiImageBody, geminiImageProvider } from "../src/providers/gemini";
import {
  availableProviderNames,
  DEFAULT_IMAGE_PROVIDER,
  resolveImageProvider,
} from "../src/providers/registry";
import {
  SPRITE_REQUEST_SPEC_BY_MODE,
  type ImageProviderEnv,
  type ProviderImageRequest,
  type SpriteMode,
} from "../src/providers/types";

const allModes: SpriteMode[] = [
  "master",
  "head-design",
  "head-expression",
  "face-layer",
  "front-hair",
  "body-pose",
  "foreground",
  "character-sheet",
];

/// The exact expressions that lived inside the Gemini request body before the
/// seam existed, copied rather than reasoned about. If the lookup table drifts
/// from these, StoryTale silently generates at a different size — which is what
/// it is billed for.
function legacyAspectRatio(mode: SpriteMode): string {
  return mode === "head-design" || mode === "head-expression" ||
      mode === "face-layer" || mode === "front-hair" ||
      mode === "foreground" || mode === "master" || mode === "character-sheet"
    ? "1:1"
    : mode === "body-pose"
    ? "9:16"
    : "3:4";
}

function legacyImageSize(mode: SpriteMode): string {
  return mode === "character-sheet"
    ? "1K"
    : mode === "head-design" || mode === "head-expression" ||
        mode === "face-layer" || mode === "front-hair" ||
        mode === "foreground" || mode === "master"
    ? "1K"
    : "512";
}

const geminiEnv: ImageProviderEnv = {
  GEMINI_API_KEY: "test-key",
  GEMINI_IMAGE_MODEL: "gemini-3.1-flash-image",
};

function requestFor(mode: SpriteMode): ProviderImageRequest {
  return {
    prompt: "a prompt",
    references: [
      { mimeType: "image/png", bytes: new Uint8Array([1, 2, 3, 4]) },
    ],
    spec: SPRITE_REQUEST_SPEC_BY_MODE[mode],
    mode,
  };
}

describe("the per-mode request spec", () => {
  it("covers every sprite mode", () => {
    expect(Object.keys(SPRITE_REQUEST_SPEC_BY_MODE).sort())
      .toEqual([...allModes].sort());
  });

  it("matches the aspect ratio the Worker asked for before the seam", () => {
    for (const mode of allModes) {
      expect(SPRITE_REQUEST_SPEC_BY_MODE[mode].aspectRatio, mode)
        .toBe(legacyAspectRatio(mode));
    }
  });

  it("matches the billed image size the Worker asked for before the seam", () => {
    for (const mode of allModes) {
      expect(SPRITE_REQUEST_SPEC_BY_MODE[mode].imageSize, mode)
        .toBe(legacyImageSize(mode));
    }
  });
});

describe("the Gemini request body", () => {
  it("keeps the field order the endpoint was called with", () => {
    const body = buildGeminiImageBody(requestFor("character-sheet"), "m");
    expect(Object.keys(body)).toEqual(["model", "input", "response_format", "store"]);
    expect(Object.keys(body.response_format as object))
      .toEqual(["type", "mime_type", "aspect_ratio", "image_size"]);
  });

  it("asks for JPEG, which is the only format this endpoint returns", () => {
    for (const mode of allModes) {
      const body = buildGeminiImageBody(requestFor(mode), "m");
      const format = body.response_format as Record<string, unknown>;
      expect(format.mime_type, mode).toBe("image/jpeg");
      expect(format.aspect_ratio, mode).toBe(legacyAspectRatio(mode));
      expect(format.image_size, mode).toBe(legacyImageSize(mode));
    }
  });

  it("sends the prompt first, then one part per reference, unedited", () => {
    const body = buildGeminiImageBody({
      prompt: "exact text",
      references: [
        { mimeType: "image/png", bytes: new Uint8Array([0]) },
        { mimeType: "image/jpeg", bytes: new Uint8Array([1]) },
      ],
      spec: SPRITE_REQUEST_SPEC_BY_MODE["character-sheet"],
      mode: "character-sheet",
    }, "m");

    const input = body.input as Array<Record<string, string>>;
    expect(input).toHaveLength(3);
    expect(input[0]).toEqual({ type: "text", text: "exact text" });
    expect(input[1].type).toBe("image");
    expect(input[1].mime_type).toBe("image/png");
    expect(input[2].mime_type).toBe("image/jpeg");
  });

  it("never stores the request with the provider", () => {
    expect(buildGeminiImageBody(requestFor("master"), "m").store).toBe(false);
  });

  it("declares capabilities that match what it actually asks for", () => {
    const format = buildGeminiImageBody(requestFor("master"), "m")
      .response_format as Record<string, unknown>;
    expect(geminiImageProvider.capabilities.outputMimeTypes)
      .toContain(format.mime_type);
    // Gemini returns JPEG, so StoryTale must keep chroma-keying green rather
    // than relying on an alpha channel. V5's separator depends on this.
    expect(geminiImageProvider.capabilities.supportsTransparentOutput).toBe(false);
  });
});

describe("provider routing", () => {
  it("defaults to the provider the Worker ships with", () => {
    expect(availableProviderNames()).toContain(DEFAULT_IMAGE_PROVIDER);
    expect(resolveImageProvider("master", geminiEnv).name).toBe("google-gemini");
  });

  it("honours an explicit provider name", () => {
    const provider = resolveImageProvider("master", {
      ...geminiEnv,
      IMAGE_PROVIDER: "gemini",
    });
    expect(provider.name).toBe("google-gemini");
  });

  it("routes one mode elsewhere without moving the rest", () => {
    const env: ImageProviderEnv = {
      ...geminiEnv,
      IMAGE_PROVIDER_BY_MODE: JSON.stringify({ "body-pose": "not-installed" }),
    };
    expect(() => resolveImageProvider("body-pose", env)).toThrow(/not-installed/);
    expect(resolveImageProvider("master", env).name).toBe("google-gemini");
  });

  it("fails loudly on an unknown provider instead of falling back", () => {
    expect(() => resolveImageProvider("master", {
      ...geminiEnv,
      IMAGE_PROVIDER: "midjourney",
    })).toThrow(/not available/);
  });

  it("fails loudly when the chosen provider has no model configured", () => {
    expect(() => resolveImageProvider("master", { GEMINI_API_KEY: "k" }))
      .toThrow(/no model configured/);
  });

  it("ignores a malformed routing map rather than taking the path down", () => {
    const provider = resolveImageProvider("master", {
      ...geminiEnv,
      IMAGE_PROVIDER_BY_MODE: "{not json",
    });
    expect(provider.name).toBe("google-gemini");
  });
});
