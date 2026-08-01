import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const artifactModule = pathToFileURL(
  "C:/Users/Houro/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs",
).href;
const { Presentation, PresentationFile } = await import(artifactModule);

const OUT_DIR =
  "C:/Users/Houro/Desktop/IT Elect 4/storytale/docs/project-management/week3";
const QA_DIR = path.join(OUT_DIR, "tmp", "presentation", "qa");
const UI_DIR =
  "C:/Users/Houro/Desktop/IT Elect 4/storytale/docs/ui-concepts/ui";

const COLORS = {
  purple: "#4C2BBF",
  purple2: "#6D4DD7",
  lavender: "#E9E1FF",
  lavender2: "#F6F3FC",
  dark: "#171428",
  gray: "#625D6D",
  gray2: "#A39DAC",
  rule: "#D8D2E2",
  green: "#357761",
  amber: "#C77A20",
  red: "#B84C63",
  white: "#FFFFFF",
};

const W = 1280;
const H = 720;
const M = 64;

async function blobFromFile(filePath) {
  const bytes = await fs.readFile(filePath);
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  );
}

function addShape(slide, name, left, top, width, height, fill, line = "none", radius = 0) {
  const shape = slide.shapes.add({
    geometry: radius ? "roundRect" : "rect",
    name,
    position: { left, top, width, height },
    fill,
    line:
      line === "none"
        ? { style: "solid", fill: "none", width: 0 }
        : { style: "solid", fill: line, width: 1 },
    ...(radius ? { borderRadius: "rounded-xl" } : {}),
  });
  return shape;
}

function addText(
  slide,
  name,
  text,
  left,
  top,
  width,
  height,
  {
    size = 24,
    color = COLORS.dark,
    bold = false,
    align = "left",
    font = "Arial",
    fill = "none",
  } = {},
) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    name,
    position: { left, top, width, height },
    fill,
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: size,
    color,
    bold,
    alignment: align,
    fontFamily: font,
  };
  return shape;
}

function addTitle(slide, title, section, number) {
  addText(slide, `section-${number}`, section.toUpperCase(), M, 40, 360, 24, {
    size: 13,
    color: COLORS.purple,
    bold: true,
  });
  addText(slide, `title-${number}`, title, M, 70, 1110, 68, {
    size: 38,
    color: COLORS.dark,
    bold: true,
  });
  addShape(slide, `title-rule-${number}`, M, 145, 1152, 2, COLORS.rule);
  addText(slide, `footer-${number}`, String(number).padStart(2, "0"), 1180, 676, 36, 18, {
    size: 11,
    color: COLORS.gray2,
    align: "right",
  });
}

function addBullet(slide, text, left, top, width, index, color = COLORS.purple) {
  addShape(slide, `bullet-dot-${index}-${top}`, left, top + 10, 10, 10, color, "none", 10);
  addText(slide, `bullet-${index}-${top}`, text, left + 24, top, width - 24, 52, {
    size: 20,
    color: COLORS.dark,
  });
}

async function addImage(slide, fileName, left, top, width, height, alt, fit = "contain") {
  const filePath = path.join(UI_DIR, fileName);
  slide.images.add({
    blob: await blobFromFile(filePath),
    contentType: fileName.toLowerCase().endsWith(".jpg") ? "image/jpeg" : "image/png",
    alt,
    fit,
    position: { left, top, width, height },
    geometry: "roundRect",
    borderRadius: "rounded-xl",
  });
}

function addNotes(slide, sources, presenterNote) {
  const text = [
    presenterNote,
    "",
    "[Sources]",
    ...sources.map((source) => `- ${source}`),
    "[/Sources]",
  ].join("\n");
  slide.speakerNotes.textFrame.setText(text);
}

const presentation = Presentation.create({
  slideSize: { width: W, height: H },
});

// Slide 1 - cover
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.lavender2;
  addShape(slide, "cover-left", 0, 0, 510, H, COLORS.dark);
  addText(slide, "cover-kicker", "WEEK 2 PROGRESS UPDATE", 64, 64, 360, 28, {
    size: 14,
    color: COLORS.lavender,
    bold: true,
  });
  addText(slide, "cover-title", "StoryTale", 64, 126, 390, 74, {
    size: 58,
    color: COLORS.white,
    bold: true,
  });
  addText(
    slide,
    "cover-subtitle",
    "A local-first mobile e-book library that helps students read, translate, listen, and imagine.",
    64,
    218,
    365,
    150,
    { size: 24, color: COLORS.lavender },
  );
  addText(slide, "cover-meta", "John Benedict S. Alejo\nIT Elect 4  |  August 2026", 64, 592, 350, 56, {
    size: 16,
    color: COLORS.white,
  });
  await addImage(
    slide,
    "1 revamped.png",
    585,
    42,
    560,
    636,
    "StoryTale splash screen concept",
    "contain",
  );
  addNotes(
    slide,
    [
      "Internal source: StoryTale README.md and ARCHITECTURE.md",
      `Local visual: ${path.join(UI_DIR, "1 revamped.png")}`,
    ],
    "Introduce StoryTale as the proposed application and frame the update around practical Week 2 progress.",
  );
}

// Slide 2 - concept
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.white;
  addTitle(slide, "One app removes the need to switch between reading tools", "Project concept", 2);
  await addImage(
    slide,
    "6.png",
    64,
    178,
    440,
    470,
    "StoryTale library screen concept",
    "contain",
  );
  addText(slide, "problem-label", "THE PROBLEM", 570, 184, 260, 25, {
    size: 14,
    color: COLORS.purple,
    bold: true,
  });
  addText(
    slide,
    "problem-copy",
    "Students may struggle with unfamiliar English, long text, and separate apps for translation, narration, and visual content.",
    570,
    216,
    590,
    112,
    { size: 24, color: COLORS.dark },
  );
  addText(slide, "audience-label", "TARGET AUDIENCE", 570, 362, 260, 25, {
    size: 14,
    color: COLORS.purple,
    bold: true,
  });
  addText(
    slide,
    "audience-copy",
    "Students and English learners who want a simpler, more engaging way to understand EPUB stories.",
    570,
    394,
    590,
    90,
    { size: 24, color: COLORS.dark },
  );
  addText(slide, "promise", "Read  •  Translate  •  Listen  •  Imagine", 570, 554, 580, 42, {
    size: 25,
    color: COLORS.purple,
    bold: true,
  });
  addNotes(
    slide,
    [
      "Internal source: StoryTale README.md",
      `Local visual: ${path.join(UI_DIR, "6.png")}`,
    ],
    "Explain the student problem first, then show how the four modes answer it.",
  );
}

// Slide 3 - flow
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.white;
  addTitle(slide, "Books stay local while AI prepares optional enhancements", "Solution flow", 3);
  const steps = [
    ["1", "Import EPUB", "Parse metadata, cover, spine, and cleaned chapters"],
    ["2", "Read locally", "Save chapter position, progress, and reader settings"],
    ["3", "Translate & listen", "DeepL Filipino cache plus offline narration"],
    ["4", "Analyze story", "Gemini produces validated characters, places, and scenes"],
    ["5", "Play Story Mode", "Reusable sprites, backgrounds, subtitles, camera, and motion"],
  ];
  const x0 = 66;
  const gap = 18;
  const boxW = 216;
  steps.forEach((step, index) => {
    const x = x0 + index * (boxW + gap);
    addShape(slide, `flow-box-${index}`, x, 216, boxW, 292, index === 4 ? COLORS.dark : COLORS.lavender2, COLORS.rule, 16);
    addText(slide, `flow-num-${index}`, step[0], x + 18, 235, 48, 38, {
      size: 27,
      color: index === 4 ? COLORS.lavender : COLORS.purple,
      bold: true,
    });
    addText(slide, `flow-title-${index}`, step[1], x + 18, 296, boxW - 36, 54, {
      size: 23,
      color: index === 4 ? COLORS.white : COLORS.dark,
      bold: true,
    });
    addText(slide, `flow-body-${index}`, step[2], x + 18, 365, boxW - 36, 110, {
      size: 17,
      color: index === 4 ? COLORS.lavender : COLORS.gray,
    });
    if (index < steps.length - 1) {
      addText(slide, `flow-arrow-${index}`, "→", x + boxW + 2, 330, 26, 36, {
        size: 26,
        color: COLORS.purple2,
        bold: true,
        align: "center",
      });
    }
  });
  addText(
    slide,
    "flow-guardrail",
    "Core reading remains usable even when an AI or image service is unavailable.",
    66,
    566,
    1120,
    42,
    { size: 22, color: COLORS.green, bold: true, align: "center" },
  );
  addNotes(
    slide,
    [
      "Internal source: StoryTale ARCHITECTURE.md",
      "Internal source: StoryTale Animated Story Mode planning documents",
    ],
    "Walk from EPUB import to Story Mode and emphasize that the app is local-first.",
  );
}

// Slide 4 - week 2 achievements
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.dark;
  addText(slide, "s4-section", "WEEK 2 ACHIEVEMENTS", 64, 44, 360, 25, {
    size: 14,
    color: COLORS.lavender,
    bold: true,
  });
  addText(slide, "s4-title", "The functional foundation is ready for feature integration", 64, 80, 1080, 82, {
    size: 40,
    color: COLORS.white,
    bold: true,
  });
  addShape(slide, "s4-rule", 64, 170, 1152, 2, "#3D3750");
  const items = [
    ["01", "Organized Flutter structure", "Clear src, assets, docs, services, models, and reusable components."],
    ["02", "Reusable app shell", "Shared navigation and dynamic placeholder screens reduce duplicated code."],
    ["03", "Local-first architecture", "EPUB books, progress, translation cache, and generated assets stay device-owned."],
    ["04", "Functional EPUB path", "Real file selection, metadata, cover, and cleaned chapter parsing are represented."],
    ["05", "AI boundaries documented", "DeepL translates; Gemini analyzes stories and sprites; Cloudflare prepares backgrounds."],
    ["06", "Prototype screens connected", "Reader, audio, Sprite Studio, Story Bible, catalogs, and Story Mode are navigable."],
  ];
  items.forEach((item, index) => {
    const col = index % 2;
    const row = Math.floor(index / 2);
    const left = 64 + col * 585;
    const top = 208 + row * 136;
    addText(slide, `s4-num-${index}`, item[0], left, top, 46, 30, {
      size: 16,
      color: COLORS.lavender,
      bold: true,
    });
    addText(slide, `s4-head-${index}`, item[1], left + 62, top - 2, 470, 36, {
      size: 23,
      color: COLORS.white,
      bold: true,
    });
    addText(slide, `s4-body-${index}`, item[2], left + 62, top + 38, 480, 60, {
      size: 17,
      color: "#CFC9DC",
    });
  });
  addText(slide, "s4-footer", "04", 1180, 676, 36, 18, {
    size: 11,
    color: "#716A82",
    align: "right",
  });
  addNotes(
    slide,
    [
      "Internal source: StoryTale README.md",
      "Internal source: StoryTale source structure and current prototype",
    ],
    "Report the concrete Week 2 outputs and avoid claiming that later API integrations are complete.",
  );
}

// Slide 5 - prototype
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.white;
  addTitle(slide, "The prototype demonstrates Story Mode and audiobook playback", "Prototype progress", 5);
  addShape(slide, "s5-left-bg", 64, 176, 548, 470, COLORS.lavender2, COLORS.rule, 16);
  addShape(slide, "s5-right-bg", 668, 176, 548, 470, "#F7F8FB", COLORS.rule, 16);
  await addImage(
    slide,
    "12 animated story mode.png",
    84,
    192,
    250,
    428,
    "Animated Story Mode screen concept",
    "contain",
  );
  addText(slide, "s5-left-title", "Animated Story Mode", 355, 222, 225, 62, {
    size: 26,
    color: COLORS.dark,
    bold: true,
  });
  addText(
    slide,
    "s5-left-body",
    "Chapter scenes combine approved backgrounds, character sprites, one-line subtitles, camera movement, and simple motion.",
    355,
    308,
    220,
    178,
    { size: 18, color: COLORS.gray },
  );
  await addImage(
    slide,
    "17 audio.png",
    688,
    192,
    250,
    428,
    "Audio book screen concept",
    "contain",
  );
  addText(slide, "s5-right-title", "Audio Book", 958, 222, 225, 62, {
    size: 26,
    color: COLORS.dark,
    bold: true,
  });
  addText(
    slide,
    "s5-right-body",
    "The audio screen is structured for chapter playback, narrator selection, speed, sleep timer, and queued chapters.",
    958,
    308,
    220,
    160,
    { size: 18, color: COLORS.gray },
  );
  addNotes(
    slide,
    [
      `Local visual: ${path.join(UI_DIR, "12 animated story mode.png")}`,
      `Local visual: ${path.join(UI_DIR, "17 audio.png")}`,
      "Internal source: current StoryTale prototype",
    ],
    "Show that the interaction design exists while clearly separating prototype behavior from unfinished production services.",
  );
}

// Slide 6 - timeline
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.white;
  addTitle(slide, "An 11-week plan protects core reading before Story Mode", "Implementation timeline", 6);
  const ganttPng = path.join(OUT_DIR, "tmp", "gantt", "gantt-1.png");
  slide.images.add({
    blob: await blobFromFile(ganttPng),
    contentType: "image/png",
    alt: "StoryTale 11-week project Gantt chart",
    fit: "contain",
    position: { left: 48, top: 156, width: 1184, height: 484 },
  });
  addText(slide, "s6-footer-note", "Final target: completed system, documentation, and presentation by 4 October 2026", 64, 642, 1060, 28, {
    size: 16,
    color: COLORS.green,
    bold: true,
  });
  addNotes(
    slide,
    [
      `Local source: ${path.join(OUT_DIR, "StoryTale_Project_Timeline_Gantt.pdf")}`,
    ],
    "Use the timeline to show sequencing: reader first, then language/audio, story intelligence, Story Mode, and QA.",
  );
}

// Slide 7 - risks
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.white;
  addTitle(slide, "Five risks could threaten the schedule, but each has a safe fallback", "Risk readiness", 7);
  const riskItems = [
    ["EPUB differences", "Normalize chapters and keep manual review", COLORS.red],
    ["AI inconsistency", "Validate structured output and use safe packages", COLORS.red],
    ["Large voice packs", "Five optional, quantized ONNX packs", COLORS.amber],
    ["Mobile performance", "Cache assets and reduce active layers", COLORS.amber],
    ["API quota or outage", "Cache valid results and retry later", COLORS.green],
  ];
  riskItems.forEach((item, index) => {
    const top = 186 + index * 82;
    addShape(slide, `risk-rank-${index}`, 66, top + 4, 16, 54, item[2], "none", 8);
    addText(slide, `risk-name-${index}`, item[0], 104, top, 330, 32, {
      size: 22,
      color: COLORS.dark,
      bold: true,
    });
    addText(slide, `risk-action-${index}`, item[1], 454, top, 666, 42, {
      size: 20,
      color: COLORS.gray,
    });
    addShape(slide, `risk-rule-${index}`, 104, top + 58, 1016, 1, COLORS.rule);
  });
  addShape(slide, "risk-callout", 873, 587, 285, 58, COLORS.dark, "none", 14);
  addText(slide, "risk-callout-text", "MVP fallback: read, translate,\nand listen without Story Mode", 891, 597, 250, 40, {
    size: 15,
    color: COLORS.white,
    bold: true,
    align: "center",
  });
  addNotes(
    slide,
    [
      `Local source: ${path.join(OUT_DIR, "StoryTale_Risk_Assessment_and_Contingency_Plan.docx")}`,
    ],
    "Focus on the risks most likely to affect the student deadline and explain the smaller working fallback.",
  );
}

// Slide 8 - close
{
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.lavender2;
  addText(slide, "s8-section", "NEXT STEPS", 64, 52, 260, 24, {
    size: 14,
    color: COLORS.purple,
    bold: true,
  });
  addText(slide, "s8-title", "Week 3 turns the prototype into a durable local library", 64, 94, 1050, 78, {
    size: 43,
    color: COLORS.dark,
    bold: true,
  });
  const next = [
    ["1", "Finish durable local storage", "Books, chapter progress, settings, and generated assets survive app restarts."],
    ["2", "Strengthen EPUB coverage", "Test varied EPUB structures and make chapter boundaries reliable."],
    ["3", "Connect language and voice", "Integrate DeepL caching and a mobile ONNX Tagalog narration path."],
    ["4", "Prepare the Story Mode pipeline", "Validate book-wide characters, locations, assets, and per-chapter story packages."],
  ];
  next.forEach((item, index) => {
    const col = index % 2;
    const row = Math.floor(index / 2);
    const left = 64 + col * 586;
    const top = 220 + row * 170;
    addText(slide, `next-num-${index}`, item[0], left, top, 44, 38, {
      size: 27,
      color: COLORS.purple,
      bold: true,
    });
    addText(slide, `next-title-${index}`, item[1], left + 58, top, 460, 40, {
      size: 23,
      color: COLORS.dark,
      bold: true,
    });
    addText(slide, `next-body-${index}`, item[2], left + 58, top + 50, 470, 76, {
      size: 18,
      color: COLORS.gray,
    });
  });
  addShape(slide, "s8-close", 64, 580, 1152, 76, COLORS.purple, "none", 16);
  addText(
    slide,
    "s8-close-text",
    "Outcome: a practical e-book app first, with translation, narration, and animated visualization added in controlled phases.",
    96,
    596,
    1088,
    44,
    { size: 21, color: COLORS.white, bold: true, align: "center" },
  );
  addText(slide, "s8-footer", "08", 1180, 676, 36, 18, {
    size: 11,
    color: COLORS.gray2,
    align: "right",
  });
  addNotes(
    slide,
    [
      "Internal source: StoryTale roadmap and architecture documents",
      `Local source: ${path.join(OUT_DIR, "StoryTale_Milestones_and_Deliverables.docx")}`,
    ],
    "Close by linking the next week to a durable local reading experience and the final project outcome.",
  );
}

await fs.mkdir(QA_DIR, { recursive: true });
for (const [index, slide] of presentation.slides.items.entries()) {
  const stem = `slide-${String(index + 1).padStart(2, "0")}`;
  const png = await presentation.export({ slide, format: "png", scale: 1 });
  await fs.writeFile(path.join(QA_DIR, `${stem}.png`), new Uint8Array(await png.arrayBuffer()));
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(path.join(QA_DIR, `${stem}.layout.json`), await layout.text());
}

const montage = await presentation.export({
  format: "webp",
  montage: true,
  scale: 1,
});
await fs.writeFile(
  path.join(QA_DIR, "deck-montage.webp"),
  new Uint8Array(await montage.arrayBuffer()),
);

const pptx = await PresentationFile.exportPptx(presentation);
await pptx.save(path.join(OUT_DIR, "StoryTale_Week2_Progress_Presentation.pptx"));

console.log(path.join(OUT_DIR, "StoryTale_Week2_Progress_Presentation.pptx"));
