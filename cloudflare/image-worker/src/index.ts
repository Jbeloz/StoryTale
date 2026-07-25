const BACKGROUND_MODEL = "@cf/black-forest-labs/flux-1-schnell" as const;
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Expose-Headers":
    "X-Image-Model, X-Image-Provider, X-Analysis-Model, X-Request-Id",
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

class PublicWorkerError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

type AnalysisCharacter = {
  id: string;
  name: string;
  rigIds: string[];
  poseIds: string[];
  faceProfileIds: string[];
  faceSetIds: string[];
};

type AnalysisLocation = {
  id: string;
  name: string;
  parentSetting?: string;
  backgroundBrief: string;
};

type AnalysisRequest = {
  chapter: {
    id: string;
    title: string;
    blocks: Array<{ id: string; text: string }>;
  };
  catalog: {
    characters: AnalysisCharacter[];
    backgroundIds: string[];
    locations: AnalysisLocation[];
  };
};

type EntityKind = "human" | "animal" | "creature" | "plant" | "prop" | "location";
type EntityImportance = "background" | "supporting" | "focus";
type ExistingStoryEntity = {
  entityId: string;
  kind: EntityKind;
  canonicalName: string;
  aliases: string[];
  approved: boolean;
  lockedAppearance: boolean;
};
type EntityExtractionRequest = {
  book: { id: string; title: string };
  chapter: {
    id: string;
    title: string;
    blocks: Array<{ id: string; text: string }>;
  };
  storyBible: { entities: ExistingStoryEntity[] };
};

const ENTITY_KINDS = [
  "human", "animal", "creature", "plant", "prop", "location",
] as const;
const ENTITY_IMPORTANCE = ["background", "supporting", "focus"] as const;

const ANALYSIS_LAYOUT_IDS = [
  "background_establishing", "object_detail", "solo_center_full",
  "solo_left_full", "solo_right_full", "solo_medium",
  "solo_close_reaction", "two_balanced", "two_left_cluster",
  "two_right_cluster", "speaker_focus_left", "speaker_focus_right",
  "depth_pair", "group_three", "entrance_exit", "travel_walking",
  "pointing_reveal", "conflict_impact", "quiet_emotional",
  "memory_dream", "ending_moral",
] as const;
const ANALYSIS_CAMERA_IDS = [
  "camera_static", "camera_push_in_slow", "camera_pull_out_slow",
  "camera_pan_left_slow", "camera_pan_right_slow", "camera_drift_left",
  "camera_drift_right", "camera_snap_in", "camera_shake_short",
] as const;
const ANALYSIS_TRANSITION_IDS = [
  "cut", "fade", "fade_in", "slide_left", "slide_right",
] as const;
const ANALYSIS_POSITION_IDS = ["left", "center", "right"] as const;
const ANALYSIS_SCALE_IDS = ["background", "full", "medium", "close"] as const;
const ANALYSIS_FACING_IDS = ["left", "right", "front"] as const;
const ANALYSIS_DEPTH_IDS = ["back", "normal", "front"] as const;
const ANALYSIS_MOVEMENT_IDS = [
  "none", "idle", "enter_left", "enter_right", "exit_left", "exit_right",
  "walk_left", "walk_right", "step_forward", "step_back", "focus_speaker",
  "idle_breathe", "gentle_bob", "reaction_pop", "fade_in", "fade_out",
] as const;
const ANALYSIS_BACKGROUND_STATE_IDS = [
  "unspecified", "dawn", "day", "sunset", "night", "rain", "storm",
  "snow", "damaged",
] as const;

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

function findGeminiText(value: unknown): string | null {
  if (!isRecord(value)) return null;
  if (typeof value.output_text === "string") return value.output_text;
  if (!Array.isArray(value.steps)) return null;
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
        part.type === "text" &&
        typeof part.text === "string"
      ) return part.text;
    }
  }
  return null;
}

function shortString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const result = value.trim();
  return result.length > 0 && result.length <= maxLength ? result : null;
}

function stringList(
  value: unknown,
  maxItems: number,
  maxLength = 80,
): string[] | null {
  if (!Array.isArray(value) || value.length === 0 || value.length > maxItems) {
    return null;
  }
  const result: string[] = [];
  for (const item of value) {
    const text = shortString(item, maxLength);
    if (!text) return null;
    result.push(text);
  }
  return [...new Set(result)];
}

function parseAnalysisRequest(value: unknown): AnalysisRequest | null {
  if (!isRecord(value) || value.schemaVersion !== 1) return null;
  const chapterValue = value.chapter;
  const catalogValue = value.catalog;
  if (!isRecord(chapterValue) || !isRecord(catalogValue)) return null;

  const chapterId = shortString(chapterValue.id, 100);
  const title = shortString(chapterValue.title, 300);
  if (
    !chapterId ||
    !title ||
    !Array.isArray(chapterValue.blocks) ||
    chapterValue.blocks.length === 0 ||
    chapterValue.blocks.length > 250
  ) return null;

  let textLength = 0;
  const blocks: Array<{ id: string; text: string }> = [];
  for (const blockValue of chapterValue.blocks) {
    if (!isRecord(blockValue)) return null;
    const id = shortString(blockValue.id, 120);
    const text = shortString(blockValue.text, 12_000);
    if (!id || !text) return null;
    textLength += text.length;
    blocks.push({ id, text });
  }
  if (textLength > 180_000 || new Set(blocks.map((block) => block.id)).size !== blocks.length) {
    return null;
  }

  if (
    !Array.isArray(catalogValue.characters) ||
    catalogValue.characters.length === 0 ||
    catalogValue.characters.length > 40
  ) return null;
  const characters: AnalysisCharacter[] = [];
  for (const characterValue of catalogValue.characters) {
    if (!isRecord(characterValue)) return null;
    const id = shortString(characterValue.id, 80);
    const name = shortString(characterValue.name, 100);
    const rigIds = stringList(characterValue.rigIds, 12);
    const poseIds = stringList(characterValue.poseIds, 30);
    const faceProfileIds = stringList(characterValue.faceProfileIds, 20);
    const faceSetIds = stringList(characterValue.faceSetIds, 30);
    if (!id || !name || !rigIds || !poseIds || !faceProfileIds || !faceSetIds) {
      return null;
    }
    characters.push({ id, name, rigIds, poseIds, faceProfileIds, faceSetIds });
  }
  if (new Set(characters.map((character) => character.id)).size !== characters.length) {
    return null;
  }
  const backgroundIds = stringList(catalogValue.backgroundIds, 80);
  if (
    !backgroundIds ||
    !Array.isArray(catalogValue.locations) ||
    catalogValue.locations.length === 0 ||
    catalogValue.locations.length > 80
  ) return null;
  const locations: AnalysisLocation[] = [];
  for (const locationValue of catalogValue.locations) {
    if (!isRecord(locationValue)) return null;
    const id = shortString(locationValue.id, 100);
    const name = shortString(locationValue.name, 160);
    const parentSetting = locationValue.parentSetting === undefined
      ? undefined
      : shortString(locationValue.parentSetting, 240);
    const backgroundBrief = shortString(locationValue.backgroundBrief, 1_000);
    if (
      !id ||
      !name ||
      !backgroundBrief ||
      (locationValue.parentSetting !== undefined && !parentSetting)
    ) return null;
    locations.push({
      id,
      name,
      backgroundBrief,
      ...(parentSetting ? { parentSetting } : {}),
    });
  }
  if (new Set(locations.map((location) => location.id)).size !== locations.length) {
    return null;
  }

  return {
    chapter: { id: chapterId, title, blocks },
    catalog: { characters, backgroundIds, locations },
  };
}

function stringListAllowEmpty(
  value: unknown,
  maxItems: number,
  maxLength = 80,
): string[] | null {
  if (!Array.isArray(value) || value.length > maxItems) return null;
  const result: string[] = [];
  for (const item of value) {
    const text = shortString(item, maxLength);
    if (!text) return null;
    result.push(text);
  }
  return [...new Set(result)];
}

function parseEntityExtractionRequest(
  value: unknown,
): EntityExtractionRequest | null {
  if (!isRecord(value) || value.schemaVersion !== 1) return null;
  const bookValue = value.book;
  const chapterValue = value.chapter;
  const bibleValue = value.storyBible;
  if (
    !isRecord(bookValue) ||
    !isRecord(chapterValue) ||
    !isRecord(bibleValue)
  ) return null;

  const bookId = shortString(bookValue.id, 100);
  const bookTitle = shortString(bookValue.title, 300);
  const chapterId = shortString(chapterValue.id, 100);
  const chapterTitle = shortString(chapterValue.title, 300);
  if (
    !bookId ||
    !bookTitle ||
    !chapterId ||
    !chapterTitle ||
    !Array.isArray(chapterValue.blocks) ||
    chapterValue.blocks.length === 0 ||
    chapterValue.blocks.length > 250 ||
    !Array.isArray(bibleValue.entities) ||
    bibleValue.entities.length > 250
  ) return null;

  let textLength = 0;
  const blocks: Array<{ id: string; text: string }> = [];
  for (const blockValue of chapterValue.blocks) {
    if (!isRecord(blockValue)) return null;
    const id = shortString(blockValue.id, 120);
    const text = shortString(blockValue.text, 12_000);
    if (!id || !text) return null;
    textLength += text.length;
    blocks.push({ id, text });
  }
  if (
    textLength > 180_000 ||
    new Set(blocks.map((block) => block.id)).size !== blocks.length
  ) return null;

  const entities: ExistingStoryEntity[] = [];
  for (const entityValue of bibleValue.entities) {
    if (!isRecord(entityValue)) return null;
    const entityId = shortString(entityValue.entityId, 100);
    const canonicalName = shortString(entityValue.canonicalName, 160);
    const aliases = stringListAllowEmpty(entityValue.aliases, 30, 160);
    const kind = entityValue.kind;
    if (
      !entityId ||
      !canonicalName ||
      !includes(ENTITY_KINDS, kind) ||
      !aliases ||
      typeof entityValue.approved !== "boolean" ||
      typeof entityValue.lockedAppearance !== "boolean"
    ) return null;
    entities.push({
      entityId,
      kind: kind as EntityKind,
      canonicalName,
      aliases,
      approved: entityValue.approved,
      lockedAppearance: entityValue.lockedAppearance,
    });
  }
  if (new Set(entities.map((entity) => entity.entityId)).size !== entities.length) {
    return null;
  }

  return {
    book: { id: bookId, title: bookTitle },
    chapter: { id: chapterId, title: chapterTitle, blocks },
    storyBible: { entities },
  };
}

function entityExtractionSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["chapterId", "entitiesJson"],
    properties: {
      chapterId: { type: "string" },
      entitiesJson: {
        type: "string",
        description:
          "Compact JSON string containing the candidate entity array.",
      },
    },
  };
}

function entityExtractionPrompt(input: EntityExtractionRequest): string {
  return [
    "You are StoryTale's book entity extractor.",
    "Return only the JSON required by the supplied schema.",
    "Extract only a subject that recurs, speaks, changes state, is a clear visual focus, or is an important reusable location.",
    "Allowed kinds are human, animal, creature, plant, prop, and location.",
    "The narrator is not a visible entity unless the text explicitly contains a separate narrator character.",
    "Never classify an animal, creature, plant, prop, or location as human.",
    "Use exact sourceBlockIds from this chapter and never invent a source ID.",
    "Resolve names and aliases against the supplied story bible. Reuse its entityId for the same subject.",
    "For a genuinely new subject, use a short stable lower_snake_case entityId.",
    "Do not approve candidates, lock appearances, assign assets, invent visual details, or create a voice ID.",
    "Descriptions must contain only details supported by the supplied text. Put uncertainty in unresolvedNotes.",
    "A location must be a specific scene place that characters can occupy, not only a broad world, realm, planet, country, or region.",
    "For every location, set sceneLocation to true, put the broader setting in parentSetting, and write a source-backed backgroundBrief describing only visible details from the chapter.",
    "When refining an existing broad location into a specific scene place, reuse its entityId and include its former broad name in aliases.",
    "If the text names only a broad setting and provides no specific scene place, do not return it as a location candidate.",
    "For non-location entities, set sceneLocation to false and omit parentSetting and backgroundBrief.",
    "Confidence is a number from 0 to 1.",
    "entitiesJson must decode to an array of at most 40 objects with this exact shape: {entityId,kind,canonicalName,aliases,description,relationships,firstSeenChapterId,sourceBlockIds,recurring,importance,speaker,unresolvedNotes,confidence,sceneLocation,parentSetting?,backgroundBrief?}.",
    `Allowed importance values: ${JSON.stringify(ENTITY_IMPORTANCE)}`,
    `Book, chapter, and existing story bible:\n${JSON.stringify(input)}`,
  ].join("\n");
}

function storyAnalysisSchema(): Record<string, unknown> {
  return {
    type: "object",
    required: ["chapterId", "planJson"],
    properties: {
      chapterId: { type: "string" },
      planJson: {
        type: "string",
        description:
          "Compact JSON string containing the complete StoryTale chapter plan.",
      },
    },
  };
}

function storyAnalysisPrompt(input: AnalysisRequest): string {
  const approvedRuntimeIds = {
    layoutIds: ANALYSIS_LAYOUT_IDS,
    cameraPresetIds: ANALYSIS_CAMERA_IDS,
    transitionIds: ANALYSIS_TRANSITION_IDS,
    stagePositions: ANALYSIS_POSITION_IDS,
    scaleIds: ANALYSIS_SCALE_IDS,
    facingIds: ANALYSIS_FACING_IDS,
    depthIds: ANALYSIS_DEPTH_IDS,
    movementIds: ANALYSIS_MOVEMENT_IDS,
    backgroundStateIds: ANALYSIS_BACKGROUND_STATE_IDS,
  };
  return [
    "You are StoryTale's visual-novel chapter planner.",
    "Return only the JSON required by the supplied schema.",
    "Preserve every chapter block verbatim and in the original order.",
    "You may split one block into several short one-line subtitle beats, but each segment must keep that same single sourceBlockIds value and all segments joined with spaces must equal the original block.",
    "Do not summarize, translate, rewrite, censor, or add story text. DeepL owns Filipino translation.",
    "Use only supplied character, asset, layout, pose, face, movement, transition, and camera IDs.",
    "Use zero to three visible characters. Prefer one or two. Use background or detail shots when no supported pose exists.",
    "Characters on the left normally face right; characters on the right normally face left.",
    "Keep at least half of shots on camera_static and never use moving camera shots more than twice in a row.",
    "Do not repeat the same layout, scale composition, and camera preset more than twice in a row.",
    "Use movement sparingly. Never return coordinates, pixels, percentages, durations, easing values, or new IDs.",
    "Use only supplied catalog.locations IDs and choose them from their names, parent settings, background briefs, and the source text.",
    "Start a new ordered cutscene when the source changes place, time of day, weather, or the visible condition of the same place.",
    "Set backgroundStateId to the closest approved background state. Reuse the same locationId and backgroundStateId while that setting remains unchanged.",
    "Do not invent extra setting changes merely for variety. A chapter may require one or several location and background-state pairs.",
    "The moral is a short lesson derived from this chapter only.",
    "The planJson string must decode to this exact shape: {chapterId,moral,cutscenes:[{id,locationId,timeOfDay,backgroundStateId,shots:[{id,layoutId,backgroundId,transitionId,camera:{presetId,targetId,triggerBeatId?},characterLayers:[{characterId,rigId,poseId,faceProfileId,faceSetId,stagePosition,scale,facing,depth,movement,isSpeaking}],beats:[{id,speakerId,originalText,sourceBlockIds:[oneBlockId],actionId?}]}]}]}.",
    `Approved runtime IDs:\n${JSON.stringify(approvedRuntimeIds)}`,
    `Chapter and approved story bible:\n${JSON.stringify(input)}`,
  ].join("\n");
}

function includes(values: readonly string[], value: unknown): value is string {
  return typeof value === "string" && values.some((item) => item === value);
}

function normalized(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function applySafeAnalysisDefaults(value: unknown, input: AnalysisRequest): void {
  if (!isRecord(value) || !Array.isArray(value.cutscenes)) return;
  const blockById = new Map(
    input.chapter.blocks.map((block) => [block.id, block.text]),
  );
  const approvedSpeakers = new Set([
    "Narrator",
    ...input.catalog.characters.flatMap((character) => [
      character.id,
      character.name,
    ]),
  ]);
  for (const cutscene of value.cutscenes) {
    if (!isRecord(cutscene) || !Array.isArray(cutscene.shots)) continue;
    if (!includes(ANALYSIS_BACKGROUND_STATE_IDS, cutscene.backgroundStateId)) {
      cutscene.backgroundStateId = includes(
        ANALYSIS_BACKGROUND_STATE_IDS,
        cutscene.timeOfDay,
      )
        ? cutscene.timeOfDay
        : "unspecified";
    }
    for (const shot of cutscene.shots) {
      if (
        !isRecord(shot) ||
        !isRecord(shot.camera) ||
        !Array.isArray(shot.characterLayers) ||
        !Array.isArray(shot.beats)
      ) continue;
      const rebuiltBeats: Array<Record<string, unknown>> = [];
      for (const beat of shot.beats) {
        if (!isRecord(beat)) continue;
        const sourceIds = typeof beat.sourceBlockIds === "string"
          ? [beat.sourceBlockIds]
          : Array.isArray(beat.sourceBlockIds)
            ? beat.sourceBlockIds.filter((id): id is string => typeof id === "string")
            : [];
        for (let index = 0; index < sourceIds.length; index++) {
          const sourceId = sourceIds[index];
          const sourceText = blockById.get(sourceId);
          if (!sourceText) continue;
          rebuiltBeats.push({
            ...beat,
            id: sourceIds.length === 1
              ? String(beat.id ?? `beat-${sourceId}`)
              : `${String(beat.id ?? "beat")}-${index + 1}`,
            speakerId:
              typeof beat.speakerId === "string" &&
              approvedSpeakers.has(beat.speakerId)
                ? beat.speakerId
                : "Narrator",
            originalText: sourceText,
            sourceBlockIds: [sourceId],
            actionId: includes(ANALYSIS_MOVEMENT_IDS, beat.actionId)
              ? beat.actionId
              : undefined,
          });
        }
      }
      shot.beats = rebuiltBeats;
      const visible = new Set(
        shot.characterLayers
          .filter(isRecord)
          .map((layer) => layer.characterId)
          .filter((id): id is string => typeof id === "string"),
      );
      if (
        shot.camera.targetId !== "stage" &&
        shot.camera.targetId !== "background" &&
        (typeof shot.camera.targetId !== "string" ||
          !visible.has(shot.camera.targetId))
      ) {
        shot.camera.targetId = "stage";
      }
      const beatIds = new Set(
        rebuiltBeats
          .filter(isRecord)
          .map((beat) => beat.id)
          .filter((id): id is string => typeof id === "string"),
      );
      if (
        typeof shot.camera.triggerBeatId === "string" &&
        !beatIds.has(shot.camera.triggerBeatId)
      ) {
        delete shot.camera.triggerBeatId;
      }
    }
  }
}

function validateStoryAnalysis(value: unknown, input: AnalysisRequest): string | null {
  if (!isRecord(value) || value.chapterId !== input.chapter.id) {
    return "wrong chapterId";
  }
  if (typeof value.moral !== "string" || !Array.isArray(value.cutscenes)) {
    return "missing moral or cutscenes";
  }
  const characters = new Map(
    input.catalog.characters.map((character) => [character.id, character]),
  );
  const speakers = new Set([
    "Narrator",
    ...input.catalog.characters.flatMap((character) => [character.id, character.name]),
  ]);
  const groupedText = new Map<string, string[]>();
  const blockSequence: string[] = [];
  let shotCount = 0;
  let staticCameraCount = 0;
  let movingCameraRun = 0;
  let repeatedFramingRun = 0;
  let previousFraming = "";

  for (const cutscene of value.cutscenes) {
    if (!isRecord(cutscene) || !Array.isArray(cutscene.shots)) {
      return "invalid cutscene";
    }
    if (
      typeof cutscene.locationId !== "string" ||
      !input.catalog.locations.some(
        (location) => location.id === cutscene.locationId,
      )
    ) {
      return "unapproved location";
    }
    if (!includes(ANALYSIS_BACKGROUND_STATE_IDS, cutscene.backgroundStateId)) {
      return "unapproved background state";
    }
    for (const shot of cutscene.shots) {
      shotCount++;
      if (
        !isRecord(shot) ||
        !includes(ANALYSIS_LAYOUT_IDS, shot.layoutId) ||
        !includes(input.catalog.backgroundIds, shot.backgroundId) ||
        !includes(ANALYSIS_TRANSITION_IDS, shot.transitionId) ||
        !isRecord(shot.camera) ||
        !includes(ANALYSIS_CAMERA_IDS, shot.camera.presetId) ||
        !Array.isArray(shot.characterLayers) ||
        shot.characterLayers.length > 3 ||
        !Array.isArray(shot.beats) ||
        shot.beats.length === 0
      ) return "invalid shot fields";

      if (shot.camera.presetId === "camera_static") {
        staticCameraCount++;
        movingCameraRun = 0;
      } else {
        movingCameraRun++;
        if (movingCameraRun > 2) return "too many moving cameras in a row";
      }

      const visible = new Set<string>();
      const scales: string[] = [];
      for (const layer of shot.characterLayers) {
        if (!isRecord(layer) || typeof layer.characterId !== "string") {
          return "invalid character layer";
        }
        const character = characters.get(layer.characterId);
        if (
          !character ||
          !includes(character.rigIds, layer.rigId) ||
          !includes(character.poseIds, layer.poseId) ||
          !includes(character.faceProfileIds, layer.faceProfileId) ||
          !includes(character.faceSetIds, layer.faceSetId) ||
          !includes(ANALYSIS_POSITION_IDS, layer.stagePosition) ||
          !includes(ANALYSIS_SCALE_IDS, layer.scale) ||
          !includes(ANALYSIS_FACING_IDS, layer.facing) ||
          !includes(ANALYSIS_DEPTH_IDS, layer.depth) ||
          !includes(ANALYSIS_MOVEMENT_IDS, layer.movement) ||
          typeof layer.isSpeaking !== "boolean"
        ) return "unapproved character layer value";
        visible.add(character.id);
        scales.push(layer.scale);
      }
      if (
        shot.camera.targetId !== "stage" &&
        shot.camera.targetId !== "background" &&
        (typeof shot.camera.targetId !== "string" || !visible.has(shot.camera.targetId))
      ) return "camera target is not visible";

      const beatIds = new Set<string>();
      for (const beat of shot.beats) {
        if (
          !isRecord(beat) ||
          typeof beat.id !== "string" ||
          typeof beat.originalText !== "string" ||
          typeof beat.speakerId !== "string" ||
          !speakers.has(beat.speakerId) ||
          !Array.isArray(beat.sourceBlockIds) ||
          beat.sourceBlockIds.length !== 1 ||
          typeof beat.sourceBlockIds[0] !== "string"
        ) return "invalid beat";
        const blockId = beat.sourceBlockIds[0];
        if (!input.chapter.blocks.some((block) => block.id === blockId)) {
          return "unknown source block";
        }
        beatIds.add(beat.id);
        if (blockSequence.at(-1) !== blockId) blockSequence.push(blockId);
        const text = groupedText.get(blockId) ?? [];
        text.push(beat.originalText);
        groupedText.set(blockId, text);
      }
      if (
        shot.camera.triggerBeatId !== undefined &&
        (typeof shot.camera.triggerBeatId !== "string" ||
          !beatIds.has(shot.camera.triggerBeatId))
      ) return "invalid camera trigger";

      const framing = `${shot.layoutId}|${scales.join(",")}|${shot.camera.presetId}`;
      repeatedFramingRun = framing === previousFraming ? repeatedFramingRun + 1 : 1;
      previousFraming = framing;
      if (repeatedFramingRun > 2) return "repeated framing";
    }
  }

  if (shotCount === 0 || (shotCount >= 4 && staticCameraCount * 2 < shotCount)) {
    return "not enough static camera shots";
  }
  const expectedBlockIds = input.chapter.blocks.map((block) => block.id);
  if (
    blockSequence.length !== expectedBlockIds.length ||
    blockSequence.some((id, index) => id !== expectedBlockIds[index])
  ) return "source blocks were skipped, duplicated, or reordered";
  for (const block of input.chapter.blocks) {
    if (normalized((groupedText.get(block.id) ?? []).join(" ")) !== normalized(block.text)) {
      return `source text changed for ${block.id}`;
    }
  }
  return null;
}

function validateEntityExtraction(
  value: unknown,
  input: EntityExtractionRequest,
): string | null {
  if (!Array.isArray(value) || value.length > 40) return "invalid entity list";
  const entityIds = new Set<string>();
  const blockIds = new Set(input.chapter.blocks.map((block) => block.id));
  const knownNames = input.storyBible.entities.map((entity) => ({
    entityId: entity.entityId,
    names: new Set(
      [entity.canonicalName, ...entity.aliases].map(normalized),
    ),
  }));

  for (const entity of value) {
    if (!isRecord(entity)) return "invalid entity";
    const entityId = shortString(entity.entityId, 100);
    const canonicalName = shortString(entity.canonicalName, 160);
    const aliases = stringListAllowEmpty(entity.aliases, 30, 160);
    const description = shortString(entity.description, 1_000);
    const relationships = stringListAllowEmpty(entity.relationships, 30, 240);
    const sourceBlockIds = stringList(entity.sourceBlockIds, 250, 120);
    const unresolvedNotes = stringListAllowEmpty(
      entity.unresolvedNotes,
      20,
      300,
    );
    if (!entityId || !/^[a-z0-9][a-z0-9_:-]*$/.test(entityId)) {
      return "invalid entityId";
    }
    if (!entityIds.add(entityId)) return "duplicate entityId";
    if (!includes(ENTITY_KINDS, entity.kind)) return "invalid entity kind";
    if (!canonicalName) return "invalid canonicalName";
    if (!aliases) return "invalid aliases";
    if (!description) return "invalid description";
    if (!relationships) return "invalid relationships";
    if (entity.firstSeenChapterId !== input.chapter.id) {
      return "invalid firstSeenChapterId";
    }
    if (!sourceBlockIds || sourceBlockIds.some((id) => !blockIds.has(id))) {
      return "invalid sourceBlockIds";
    }
    if (typeof entity.recurring !== "boolean") return "invalid recurring";
    if (!includes(ENTITY_IMPORTANCE, entity.importance)) {
      return "invalid importance";
    }
    if (typeof entity.speaker !== "boolean") return "invalid speaker";
    if (!unresolvedNotes) return "invalid unresolvedNotes";
    if (typeof entity.sceneLocation !== "boolean") {
      return "invalid sceneLocation";
    }
    if (entity.kind === "location") {
      const parentSetting = shortString(entity.parentSetting, 240);
      const backgroundBrief = shortString(entity.backgroundBrief, 1_000);
      if (
        !entity.sceneLocation ||
        !parentSetting ||
        !backgroundBrief ||
        normalized(parentSetting) === normalized(canonicalName)
      ) return "location is not background ready";
    } else if (
      entity.sceneLocation ||
      entity.parentSetting !== undefined ||
      entity.backgroundBrief !== undefined
    ) {
      return "non-location contains location fields";
    }
    if (
      typeof entity.confidence !== "number" ||
      entity.confidence < 0 ||
      entity.confidence > 1
    ) return "invalid confidence";

    const candidateNames = new Set(
      [canonicalName, ...aliases].map(normalized),
    );
    for (const known of knownNames) {
      const sameName = [...candidateNames].some((name) => known.names.has(name));
      if (sameName && entityId !== known.entityId) {
        return "existing entity received a new ID";
      }
      if (entityId === known.entityId && !sameName) {
        return "existing entity ID changed subject";
      }
    }
  }
  return null;
}

function applySafeEntityDefaults(value: unknown): void {
  if (!Array.isArray(value)) return;
  for (const entity of value) {
    if (!isRecord(entity)) continue;
    if (!Array.isArray(entity.aliases)) entity.aliases = [];
    if (!Array.isArray(entity.relationships)) entity.relationships = [];
    if (!Array.isArray(entity.unresolvedNotes)) entity.unresolvedNotes = [];
    if (typeof entity.sceneLocation !== "boolean") {
      entity.sceneLocation = false;
    }
    if (typeof entity.sourceBlockIds === "string") {
      entity.sourceBlockIds = [entity.sourceBlockIds];
    }
  }
}

async function generateStoryEntities(
  input: EntityExtractionRequest,
  env: StoryTaleEnv,
): Promise<Array<Record<string, unknown>>> {
  if (!env.GEMINI_API_KEY) {
    throw new PublicWorkerError("Gemini entity extraction is not configured.", 503);
  }
  const response = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/interactions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": env.GEMINI_API_KEY,
      },
      body: JSON.stringify({
        model: env.GEMINI_MODEL,
        input: entityExtractionPrompt(input),
        response_format: {
          type: "text",
          mime_type: "application/json",
          schema: entityExtractionSchema(),
        },
        store: false,
      }),
    },
  );
  if (!response.ok) {
    const details = (await response.text()).slice(0, 1_000);
    console.error(JSON.stringify({
      message: "gemini_entity_request_failed",
      status: response.status,
      model: env.GEMINI_MODEL,
      details,
    }));
    if (response.status === 429) {
      throw new PublicWorkerError(
        "Gemini entity-extraction quota is unavailable. Try again later.",
        429,
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new PublicWorkerError("The Gemini API key was rejected by Google.", 503);
    }
    throw new Error(`Gemini returned HTTP ${response.status}`);
  }
  const outputText = findGeminiText(await response.json<unknown>());
  if (!outputText) throw new Error("Gemini returned no entity text");

  let entities: unknown;
  try {
    const envelope: unknown = JSON.parse(outputText);
    if (
      !isRecord(envelope) ||
      envelope.chapterId !== input.chapter.id ||
      typeof envelope.entitiesJson !== "string"
    ) throw new Error("invalid envelope");
    entities = JSON.parse(envelope.entitiesJson);
  } catch {
    throw new Error("Gemini returned invalid entity JSON");
  }
  applySafeEntityDefaults(entities);
  const validationError = validateEntityExtraction(entities, input);
  if (validationError) {
    console.warn(JSON.stringify({
      message: "gemini_entities_rejected",
      reason: validationError,
      chapterId: input.chapter.id,
    }));
    throw new PublicWorkerError(
      "Gemini returned unsafe story entities. StoryTale kept the existing story bible.",
      502,
    );
  }
  return (entities as Array<Record<string, unknown>>).map((entity) => ({
    ...entity,
    approved: false,
    lockedAppearance: false,
    assetIds: [],
  }));
}

async function generateStoryAnalysis(
  input: AnalysisRequest,
  env: StoryTaleEnv,
): Promise<unknown> {
  if (!env.GEMINI_API_KEY) {
    throw new PublicWorkerError("Gemini story analysis is not configured.", 503);
  }
  const response = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/interactions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": env.GEMINI_API_KEY,
      },
      body: JSON.stringify({
        model: env.GEMINI_MODEL,
        input: storyAnalysisPrompt(input),
        response_format: {
          type: "text",
          mime_type: "application/json",
          schema: storyAnalysisSchema(),
        },
        store: false,
      }),
    },
  );
  if (!response.ok) {
    const details = (await response.text()).slice(0, 1_000);
    console.error(JSON.stringify({
      message: "gemini_analysis_request_failed",
      status: response.status,
      model: env.GEMINI_MODEL,
      details,
    }));
    if (response.status === 429) {
      throw new PublicWorkerError(
        "Gemini story-analysis quota is unavailable. Try again later.",
        429,
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new PublicWorkerError("The Gemini API key was rejected by Google.", 503);
    }
    throw new Error(`Gemini returned HTTP ${response.status}`);
  }
  const outputText = findGeminiText(await response.json<unknown>());
  if (!outputText) throw new Error("Gemini returned no analysis text");

  let plan: unknown;
  try {
    const envelope: unknown = JSON.parse(outputText);
    if (
      !isRecord(envelope) ||
      envelope.chapterId !== input.chapter.id ||
      typeof envelope.planJson !== "string"
    ) throw new Error("invalid envelope");
    plan = JSON.parse(envelope.planJson);
  } catch {
    throw new Error("Gemini returned invalid analysis JSON");
  }
  applySafeAnalysisDefaults(plan, input);
  const validationError = validateStoryAnalysis(plan, input);
  if (validationError) {
    console.warn(JSON.stringify({
      message: "gemini_analysis_rejected",
      reason: validationError,
      chapterId: input.chapter.id,
    }));
    throw new PublicWorkerError(
      "Gemini returned an unsafe chapter plan. StoryTale kept the local fallback.",
      502,
    );
  }
  return plan;
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
  prompt: string,
  env: StoryTaleEnv,
): Promise<{ bytes: Uint8Array; mimeType: string }> {
  const result = await env.AI.run(BACKGROUND_MODEL, {
    prompt,
    steps: 4,
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
      throw new PublicWorkerError(
        "Gemini image quota is unavailable. Enable Gemini API billing or try again after the quota resets.",
        429,
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new PublicWorkerError("The Gemini API key was rejected by Google.", 503);
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
    result = await generateBackground(body.prompt, env);
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

async function handleAnalyze(request: Request, env: StoryTaleEnv): Promise<Response> {
  if (!env.APP_TOKEN) return json({ error: "Story service is not configured" }, 503);
  if (!(await isAuthorized(request, env.APP_TOKEN))) {
    return json({ error: "Unauthorized" }, 401);
  }
  if (!request.headers.get("Content-Type")?.includes("application/json")) {
    return json({ error: "Content-Type must be application/json" }, 415);
  }
  const contentLength = Number(request.headers.get("Content-Length") ?? 0);
  if (contentLength > 256 * 1024) {
    return json({ error: "Chapter request is too large" }, 413);
  }

  const rawBody = await request.text();
  if (rawBody.length > 256 * 1024) {
    return json({ error: "Chapter request is too large" }, 413);
  }
  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    return json({ error: "Request body must be valid JSON" }, 400);
  }
  const input = parseAnalysisRequest(value);
  if (!input) {
    return json({ error: "Invalid chapter or approved story catalog" }, 400);
  }

  const rateLimit = await env.IMAGE_RATE_LIMIT.limit({
    key: "analysis-private-prototype",
  });
  if (!rateLimit.success) return json({ error: "Try again in one minute" }, 429);

  const plan = await generateStoryAnalysis(input, env);
  const requestId = crypto.randomUUID();
  console.log(JSON.stringify({
    message: "chapter_analyzed",
    requestId,
    chapterId: input.chapter.id,
    blocks: input.chapter.blocks.length,
    model: env.GEMINI_MODEL,
  }));
  return Response.json(plan, {
    headers: {
      ...CORS_HEADERS,
      "Cache-Control": "no-store",
      "X-Analysis-Model": env.GEMINI_MODEL,
      "X-Request-Id": requestId,
    },
  });
}

async function handleEntities(request: Request, env: StoryTaleEnv): Promise<Response> {
  if (!env.APP_TOKEN) return json({ error: "Story service is not configured" }, 503);
  if (!(await isAuthorized(request, env.APP_TOKEN))) {
    return json({ error: "Unauthorized" }, 401);
  }
  if (!request.headers.get("Content-Type")?.includes("application/json")) {
    return json({ error: "Content-Type must be application/json" }, 415);
  }
  const contentLength = Number(request.headers.get("Content-Length") ?? 0);
  if (contentLength > 256 * 1024) {
    return json({ error: "Chapter request is too large" }, 413);
  }

  const rawBody = await request.text();
  if (rawBody.length > 256 * 1024) {
    return json({ error: "Chapter request is too large" }, 413);
  }
  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    return json({ error: "Request body must be valid JSON" }, 400);
  }
  const input = parseEntityExtractionRequest(value);
  if (!input) {
    return json({ error: "Invalid book, chapter, or story bible" }, 400);
  }

  const rateLimit = await env.IMAGE_RATE_LIMIT.limit({
    key: "entities-private-prototype",
  });
  if (!rateLimit.success) return json({ error: "Try again in one minute" }, 429);

  const entities = await generateStoryEntities(input, env);
  const requestId = crypto.randomUUID();
  console.log(JSON.stringify({
    message: "chapter_entities_extracted",
    requestId,
    bookId: input.book.id,
    chapterId: input.chapter.id,
    blocks: input.chapter.blocks.length,
    candidates: entities.length,
    model: env.GEMINI_MODEL,
  }));
  return Response.json({ entities }, {
    headers: {
      ...CORS_HEADERS,
      "Cache-Control": "no-store",
      "X-Analysis-Model": env.GEMINI_MODEL,
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
          analysis: { provider: "google-gemini", model: env.GEMINI_MODEL },
          entityAnalysis: { provider: "google-gemini", model: env.GEMINI_MODEL },
        },
        authConfigured: Boolean(env.APP_TOKEN),
        geminiConfigured: Boolean(env.GEMINI_API_KEY),
      });
    }

    try {
      if (request.method === "POST" && url.pathname === "/generate") {
        return await handleGenerate(request, env);
      }
      if (request.method === "POST" && url.pathname === "/analyze") {
        return await handleAnalyze(request, env);
      }
      if (request.method === "POST" && url.pathname === "/entities") {
        return await handleEntities(request, env);
      }
      return json({ error: "Not found" }, 404);
    } catch (error) {
      console.error(JSON.stringify({
        message: "worker_request_failed",
        path: url.pathname,
        error: error instanceof Error ? error.message : "Unknown error",
      }));
      if (error instanceof PublicWorkerError) {
        return json({ error: error.message }, error.status);
      }
      return json({ error: "Story service request failed" }, 502);
    }
  },
} satisfies ExportedHandler<StoryTaleEnv>;
