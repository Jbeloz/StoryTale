/// Chooses which image provider answers a request.
///
/// Two rules, both deliberate:
///
/// * **Configuration decides, never the client.** A request-level provider field
///   would let the app choose what the owner is billed for. Selection comes from
///   Worker vars only.
/// * **A misconfiguration fails loudly.** An unknown name, or a provider whose
///   key is missing, is an error — never a silent fall back to a different paid
///   provider, which would spend money the owner did not choose to spend.

import { PublicWorkerError } from "../shared";
import { geminiImageProvider } from "./gemini";
import type { ImageProvider, ImageProviderEnv, SpriteMode } from "./types";

/// Every provider StoryTale can be pointed at, by the name used in config.
const providers: Record<string, ImageProvider> = {
  "gemini": geminiImageProvider,
};

export const DEFAULT_IMAGE_PROVIDER = "gemini";

export function availableProviderNames(): string[] {
  return Object.keys(providers).sort();
}

/// Reads the optional per-mode routing map.
///
/// Its point is to let one part group be tried on a different provider without
/// moving the rest — the cheap way to answer "which provider actually draws
/// this correctly". Malformed JSON is ignored rather than fatal: a typo in an
/// optional override should not take the whole image path down.
function providerNameForMode(
  mode: SpriteMode,
  env: ImageProviderEnv,
): string {
  const raw = env.IMAGE_PROVIDER_BY_MODE?.trim();
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const selected = parsed[mode];
      if (typeof selected === "string" && selected.trim()) {
        return selected.trim();
      }
    } catch {
      console.error(JSON.stringify({
        message: "image_provider_by_mode_invalid",
        detail: "IMAGE_PROVIDER_BY_MODE is not valid JSON; using the default provider",
      }));
    }
  }
  return env.IMAGE_PROVIDER?.trim() || DEFAULT_IMAGE_PROVIDER;
}

/// Resolves the provider for [mode], or throws with a message naming what is
/// wrong and what the valid names are.
export function resolveImageProvider(
  mode: SpriteMode,
  env: ImageProviderEnv,
): ImageProvider {
  const name = providerNameForMode(mode, env);
  const provider = providers[name];
  if (!provider) {
    throw new PublicWorkerError(
      `Image provider "${name}" is not available. Configured providers: ${availableProviderNames().join(", ")}.`,
      503,
    );
  }
  if (!provider.modelFor(env)) {
    throw new PublicWorkerError(
      `Image provider "${name}" has no model configured.`,
      503,
    );
  }
  return provider;
}
