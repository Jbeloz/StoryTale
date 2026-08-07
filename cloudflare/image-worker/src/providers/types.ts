/// The provider-neutral image contract.
///
/// StoryTale must be able to move between image APIs by configuration, so no
/// caller outside `providers/` may know which API answered. What this file does
/// *not* do is pretend the providers are identical: the differences that change
/// the pipeline are declared in [ProviderCapabilities] rather than hidden, so a
/// caller can read them instead of discovering them by spending a request.

export type SpriteMode =
  | "master"
  | "head-design"
  | "head-expression"
  | "face-layer"
  | "front-hair"
  | "body-pose"
  | "foreground";

/// What the caller wants back, in neutral terms.
///
/// Providers spell this differently — Gemini takes an aspect ratio plus a size
/// tier, others take explicit pixel dimensions and a quality name — so the
/// translation belongs in each adapter, not at every call site.
export type ImageRequestSpec = {
  aspectRatio: "1:1" | "9:16" | "3:4";
  /// Gemini's size tier vocabulary, kept as the neutral name because it is what
  /// billing is quoted in. `1K` is 1024x1024.
  imageSize: "512" | "1K" | "2K" | "4K";
};

/// One spec per sprite mode.
///
/// This replaces two parallel ternary chains that lived inside the Gemini
/// request body, where a new provider would have had to re-derive them. The
/// table is asserted against the modes in `test/providers.test.ts`, so a mode
/// added without a spec fails a test rather than silently generating at the
/// wrong size — which is what StoryTale is billed for.
export const SPRITE_REQUEST_SPEC_BY_MODE: Record<SpriteMode, ImageRequestSpec> = {
  "master": { aspectRatio: "1:1", imageSize: "1K" },
  "head-design": { aspectRatio: "1:1", imageSize: "1K" },
  "head-expression": { aspectRatio: "1:1", imageSize: "1K" },
  "face-layer": { aspectRatio: "1:1", imageSize: "1K" },
  "front-hair": { aspectRatio: "1:1", imageSize: "1K" },
  "body-pose": { aspectRatio: "9:16", imageSize: "512" },
  "foreground": { aspectRatio: "1:1", imageSize: "1K" },
};

export type ReferenceImage = {
  mimeType: string;
  bytes: Uint8Array;
};

export type ProviderImageRequest = {
  /// Already fully composed, including any mode wrapper. Adapters send it as
  /// given and never edit it.
  prompt: string;
  references: ReferenceImage[];
  spec: ImageRequestSpec;
  /// Carried for diagnostics and error messages only. An adapter must not
  /// branch its request shape on this; per-mode differences belong in [spec].
  mode: SpriteMode;
};

export type ProviderImageResult = {
  bytes: Uint8Array;
  mimeType: string;
  width: number;
  height: number;
};

/// The differences between providers that a caller has to plan around.
///
/// [supportsTransparentOutput] is the one that changes more than cost. Gemini's
/// image endpoint returns JPEG only, so StoryTale generates on a flat green
/// background and chroma-keys it away locally. A provider that returns PNG with
/// real alpha makes that step unnecessary, which is a pipeline decision and not
/// something an abstraction should bury.
export type ProviderCapabilities = {
  supportsTransparentOutput: boolean;
  outputMimeTypes: readonly string[];
  maxReferenceImages: number;
  maxPromptLength: number;
};

/// Only the configuration an image provider may read.
///
/// Every field is optional so that adding a provider does not require the
/// generated `Env` type to know about it, and so a missing key is a runtime
/// failure with a clear message rather than a type error at build time.
export type ImageProviderEnv = {
  IMAGE_PROVIDER?: string;
  IMAGE_PROVIDER_BY_MODE?: string;
  GEMINI_API_KEY?: string;
  GEMINI_IMAGE_MODEL?: string;
  OPENAI_API_KEY?: string;
  OPENAI_IMAGE_MODEL?: string;
};

export type ImageProvider = {
  /// Reported to the client as `X-Image-Provider`.
  readonly name: string;
  readonly capabilities: ProviderCapabilities;
  /// The model actually used, for `X-Image-Model` and the request log.
  modelFor(env: ImageProviderEnv): string;
  /// Throws [PublicWorkerError] when the provider is not configured, so a
  /// missing key never falls through to a different paid provider.
  generate(
    request: ProviderImageRequest,
    env: ImageProviderEnv,
  ): Promise<ProviderImageResult>;
};
