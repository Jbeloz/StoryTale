# StoryTale Visual-Novel Scene Library

**Status: approved. Parts 1-3 are implemented.**

This replaces the current small-character technical demo with a visual-novel
cutscene style. StoryTale still uses transparent full-body sprites, reusable
poses, backgrounds, subtitles, voices, and simple movement. It does not
generate video or create a different Flutter page for every scene.

## 1. Target look

- The background fills the complete camera area.
- A normal full-body character uses about **75% of the camera height**.
- Medium shots enlarge the same sprite and crop it near the knees or waist.
- Close shots enlarge the same sprite and crop it near the chest.
- The subtitle bar is slim and shows only **one short line at a time**.
- Speaker name, subtitle, and playback controls must not cover the face.
- The player may show zero, one, two, or at most three characters.
- Scenes use cuts, fades, small camera moves, and sprite movement so they do
  not feel like one static picture.

## 2. Simple playback structure

```text
Chapter
-> Cutscene: one location, time, and continuous event
   -> Shot: one camera layout and character arrangement
      -> Beat: one subtitle/audio line plus one optional small action
```

- Start a new cutscene when the location, time, or major event changes.
- Start a new shot when the focus, camera size, or visible characters change.
- Keep the same shot for consecutive dialogue when its layout still works.
- A long paragraph becomes several one-line beats, not one large subtitle.

## 3. Fixed camera and subtitle rules

| Item | Rule |
| --- | --- |
| Camera | Use one consistent 16:9 internal stage that scales to the phone. |
| Full-body scale | 72-78% of camera height. |
| Medium scale | 90-110%; legs may be cropped. |
| Close-up scale | 125-145%; crop near the chest. |
| Background character | 45-55% for depth only. |
| Subtitle | One beat, normally 8-12 words; never truncate the source. |
| Long sentence | Split at punctuation or a natural phrase boundary. |
| Visible cast | Prefer one or two; maximum three. |
| Unsupported action | Hide the character and use a background/detail shot plus audio or SFX. |

## 4. Approved scene layouts

These are reusable layout IDs, not separate screens or required generated
images. Gemini selects an ID and StoryTale places the existing sprites.

| ID | Scene name | Simple use |
| --- | --- | --- |
| `background_establishing` | Empty establishing shot | Introduce a place, time, weather, or mood with no character. |
| `object_detail` | Object/detail cutaway | Show a letter, door, weapon, flower, food, or important clue with no character. |
| `solo_center_full` | One character, center | General introduction or important statement; full body at 75%. |
| `solo_left_full` | One character, left | Speaker on the left with open story space on the right. |
| `solo_right_full` | One character, right | Speaker on the right with open story space on the left. |
| `solo_medium` | One character, top half | Normal dialogue, explanation, or emotion with a larger face. |
| `solo_close_reaction` | One character close-up | Surprise, fear, anger, realization, or a quiet reaction. |
| `two_balanced` | Two characters facing | Standard conversation with one character on each side. |
| `two_left_cluster` | Two top-half characters, left | Two allies or observers together while the right side shows the subject. |
| `two_right_cluster` | Two top-half characters, right | Mirrored version of the left cluster. |
| `speaker_focus_left` | Left speaker emphasized | Left character at medium scale; right listener smaller or dimmer. |
| `speaker_focus_right` | Right speaker emphasized | Right character at medium scale; left listener smaller or dimmer. |
| `depth_pair` | Foreground/background pair | One large foreground character and one smaller distant character. |
| `group_three` | Three-character group | Small group discussion; center speaker is the focus. |
| `entrance_exit` | Character enters or leaves | Reveal, arrival, interruption, farewell, or escape. |
| `travel_walking` | Walking/travel shot | Walking pose plus whole-sprite movement across the background. |
| `pointing_reveal` | Pointing or presentation | A character points toward another character, object, or location. |
| `conflict_impact` | Confrontation/action beat | Two large characters, quick shake or push-in, then cut away if no pose exists. |
| `quiet_emotional` | Comfort or reflection | One or two characters close together with slow push-in and gentle motion. |
| `memory_dream` | Memory, dream, or imagination | Reuse another layout with a soft tint, fade, or blurred edge. |
| `ending_moral` | Chapter ending | Background-first closing image; characters are optional and subtitles finish before the moral card. |

## 5. Direction, character motion, and camera motion

### Character direction and visual variation

- `facing` is `left`, `right`, or `front`. Flutter mirrors the complete assembled
  rig, not the individual body parts.
- A character in a left slot faces right by default, and a character in a right
  slot faces left. Gemini overrides this only for a clear story reason.
- `scale` is `background`, `full`, `medium`, or `close`; Gemini never sends a
  raw percentage.
- `depth` is `back`, `normal`, or `front` and controls overlap, brightness, and
  which character receives visual focus.
- A shot may contain zero, one, two, or at most three character layers.
- Do not repeat the same layout and scale for more than two consecutive shots.

### Character movement presets

| ID | What StoryTale does |
| --- | --- |
| `none` | Hold the current character composition. |
| `enter_left` / `enter_right` | Slide a character into an approved slot. |
| `exit_left` / `exit_right` | Slide a character out of the camera. |
| `walk_left` / `walk_right` | Use Walking pose while moving the complete rig. |
| `step_forward` | Move toward center and change to the next larger scale. |
| `step_back` | Move away from center and change to the next smaller scale. |
| `focus_speaker` | Brighten and slightly enlarge the current speaker. |
| `idle_breathe` | Very small repeating scale movement while waiting. |
| `gentle_bob` | Small vertical movement for friendly dialogue. |
| `reaction_pop` | One quick scale pulse for surprise. |
| `fade_in` / `fade_out` | Reveal or remove a character or complete shot. |

### Camera preset library

The camera transforms one `CameraViewport` containing the background and all
character layers. Subtitles and playback controls stay fixed outside this
transform so they remain readable.

| ID | Motion | Normal use |
| --- | --- | --- |
| `camera_static` | No movement. | Normal dialogue and rest between moving shots. |
| `camera_push_in_slow` | Scale `1.00 -> 1.12` over 1.8-2.8 seconds. | Emotion, discovery, important dialogue, or a reaction. |
| `camera_pull_out_slow` | Scale `1.12 -> 1.00` over 1.8-2.8 seconds. | Establishing context, loneliness, ending, or moral. |
| `camera_pan_left_slow` | Pan the viewport left by at most 6% of its width. | Reveal something on the right or follow rightward travel. |
| `camera_pan_right_slow` | Pan the viewport right by at most 6% of its width. | Reveal something on the left or follow leftward travel. |
| `camera_drift_left` | Very slow 3-5 second leftward movement. | Calm travel, memory, dream, or environmental narration. |
| `camera_drift_right` | Very slow 3-5 second rightward movement. | Mirrored calm travel or environmental narration. |
| `camera_snap_in` | Scale `1.00 -> 1.08` in 220-400 ms. | Sudden realization, surprise, or impact. |
| `camera_shake_short` | Move by at most 8 px for 240-320 ms. | Collision, shout, shock, or strong sound effect; never loop. |

Camera safety rules:

1. A pan uses at least `1.12` viewport scale and crop-safe background space so
   no empty edge becomes visible.
2. Normal zoom is clamped to `1.00-1.18`; only an approved close-up layout may
   crop more through character scale.
3. Use at most one primary camera preset per shot, plus one optional
   `camera_shake_short` impact.
4. Start slow camera motion at a shot boundary. A beat may trigger only a snap
   or shake for a specific reaction.
5. Keep roughly 50-70% of shots static so movement remains meaningful and does
   not become distracting.
6. Do not use moving camera shots more than twice in a row.
7. When a character walks, pan gently with the travel or keep the camera static;
   do not combine full pan and full character travel in opposite directions.
8. Never loop zoom, snap, or shake. `idle_breathe` is the only normal loop.
9. Reduced-motion mode replaces pan, zoom, shake, and travel with a short fade.
10. Flutter owns every distance, duration, easing curve, and safety clamp.

Do not ask Gemini for joint coordinates, pixels, percentages, durations, or
easing values. It chooses approved layout, facing, scale, depth, pose,
expression, character movement, and camera preset IDs; Flutter applies them.

## 6. What the story analyzer decides

For each shot, Gemini returns only approved values:

```text
ShotPlan
- cutsceneId
- shotId
- sourceStartBlock and sourceEndBlock
- layoutId
- backgroundId
- transitionId
- cameraPresetId
- cameraTargetId: stage, background, or characterId
- cameraTriggerBeatId (optional reaction trigger)
- characters (maximum 3)
  - characterId
  - slot: farLeft, left, center, right, farRight
  - scale: background, full, medium, close
  - facing: left, right, front
  - depth: back, normal, front
  - poseId
  - faceProfileId and faceSetId
  - movementId
- beats
  - lineId
  - speakerId or narrator
  - originalText and FilipinoText
  - audioAssetId
```

Analyzer rules:

1. Preserve every source line in order.
2. Split text into one-line beats without summarizing or deleting it.
3. Use `background_establishing` when a location or time is introduced.
4. Prefer `solo_medium` for one speaker and `two_balanced` for conversation.
5. Change speaker focus instead of rebuilding the entire shot each line.
6. Use close-up shots only for important reactions.
7. Use at most three visible characters; focus on the important speaker.
8. If StoryTale lacks the required pose, use a no-character cutaway,
   reaction close-up, or background plus SFX instead.
9. Reuse approved backgrounds and character rigs from the story bible.
10. Never invent an unapproved layout, pose, character design, or movement ID.
11. Alternate wide, medium, and close framing when the story focus changes.
12. Use speaker-focus shots during conversation and face speakers inward.
13. Choose `camera_static` for most dialogue; use pans and zooms only to reveal,
    follow, emphasize, react, establish, or close a moment.
14. Never repeat the same layout, scale, and camera preset for more than two
    consecutive shots.

## 7. One-sentence ChatGPT prompts for layout references

Attach the approved full-body character images when a prompt requires them.
Replace bracketed words, but keep each request as one sentence.

1. **Empty establishing:** "Can you make a 16:9 anime visual-novel establishing scene of [location and time] with no characters, a clear cinematic focal point, and no text or UI?"
2. **Object detail:** "Can you make a 16:9 anime cutaway scene focused closely on [important object] in [location], with no characters, no text, and no UI?"
3. **Solo center full:** "Can you make a 16:9 visual-novel scene using this exact full-body character at about 75% of the camera height in the center, preserve the exact design and proportions, and add no text or UI?"
4. **Solo left full:** "Can you make a 16:9 visual-novel scene using this exact full-body character at about 75% height on the left facing inward, leave open story space on the right, and preserve the character exactly with no text or UI?"
5. **Solo right full:** "Can you make a 16:9 visual-novel scene using this exact full-body character at about 75% height on the right facing inward, leave open story space on the left, and preserve the character exactly with no text or UI?"
6. **Solo medium:** "Can you make a 16:9 visual-novel medium shot by enlarging this exact full-body character and cropping near the waist, keep the face and clothing unchanged, and add no text or UI?"
7. **Solo reaction close-up:** "Can you make a 16:9 anime reaction close-up from this exact character by enlarging the same sprite and cropping near the chest, keep the approved expression and design unchanged, and add no text or UI?"
8. **Two balanced:** "Can you make a 16:9 visual-novel scene with these exact two characters at about 70% height on opposite sides facing each other, preserve both designs and proportions, and add no text or UI?"
9. **Two top-half left:** "Can you make a 16:9 visual-novel scene with the top halves of these exact two characters grouped on the left side, leave the right side open for the story focus, preserve both designs exactly, and add no text or UI?"
10. **Two top-half right:** "Can you make a 16:9 visual-novel scene with the top halves of these exact two characters grouped on the right side, leave the left side open for the story focus, preserve both designs exactly, and add no text or UI?"
11. **Left speaker focus:** "Can you make a 16:9 visual-novel conversation scene where the exact left character is larger and brighter as the speaker while the exact right character remains smaller as the listener, with no redesign, text, or UI?"
12. **Right speaker focus:** "Can you make a 16:9 visual-novel conversation scene where the exact right character is larger and brighter as the speaker while the exact left character remains smaller as the listener, with no redesign, text, or UI?"
13. **Depth pair:** "Can you make a 16:9 anime cutscene with one exact character large in the foreground and the other exact character smaller in the background, preserve both designs and use clear cinematic depth with no text or UI?"
14. **Three-character group:** "Can you make a 16:9 visual-novel group scene using these exact three characters with the current speaker in the center and the other two on each side, keep everyone recognizable and unchanged, and add no text or UI?"
15. **Entrance or exit:** "Can you make a 16:9 visual-novel scene showing this exact full-body character near the edge of the frame as if entering from or leaving toward [left or right], preserve the character exactly, and add no text or UI?"
16. **Walking/travel:** "Can you make a 16:9 anime travel scene using this exact character in the approved walking pose moving through [location], preserve the design and proportions, and add no text or UI?"
17. **Pointing/reveal:** "Can you make a 16:9 visual-novel reveal scene using this exact character in the approved pointing pose on one side while [object, place, or character] is clearly shown on the other side, with no redesign, text, or UI?"
18. **Conflict/impact:** "Can you make a 16:9 anime confrontation scene with these exact two characters large on opposite sides facing each other, use dramatic spacing and lighting while preserving both designs, and add no text or UI?"
19. **Quiet emotional:** "Can you make a 16:9 soft visual-novel scene with these exact one or two characters close together in [location], use calm lighting and an intimate composition, preserve their designs, and add no text or UI?"
20. **Memory or dream:** "Can you make a 16:9 anime memory or dream scene using these exact characters and [location], preserve every character design but use a soft hazy tint and faded edges with no text or UI?"
21. **Ending/moral:** "Can you make a 16:9 anime chapter-ending scene of [location after the event] with optional small character silhouettes, a calm closing composition, and no text or UI?"

## 8. Implementation order after approval

1. **Completed:** replace the large subtitle panel with the visual-novel stage,
   75%-height character framing, full-stage background, and one-line beats.
2. **Completed:** add `Cutscene`, `ShotPlan`, and `StoryBeat` data models using
   only the IDs in this document. The current deterministic chapter now uses
   this nested structure, including camera and character staging fields.
3. **Completed:** add reusable layout presets for zero, one, two, and three
   characters. The same resolver accepts deterministic test shots, imported
   EPUB chapters, and future Gemini shot plans.
4. **Completed:** add whole-character facing, controlled scale, depth ordering,
   speaker emphasis, listener dimming, and multiple assembled rig layers.
5. **Completed:** add the camera viewport, approved pan/zoom presets, safety
   clamps, fixed subtitle UI, and reduced-motion fade fallback.
6. Add character entrance/exit, walking, reactions, and shot transitions.
7. Change the Gemini schema so it chooses approved layout, character movement,
   and camera preset IDs.
8. Use one varied deterministic chapter fixture before generated scene data.
9. Only after the player looks correct, continue the Character Builder.

## 9. Acceptance checklist

- A full-body character normally fills about 75% of the camera height.
- A subtitle displays one short source-preserving line at a time.
- Backgrounds fill the camera and do not look like placeholders.
- Shots visibly change focus during a conversation.
- Characters can enter, exit, walk, react, and receive camera focus.
- Camera pans and zooms never expose a background edge or move the subtitle UI.
- Reduced-motion mode replaces camera and travel movement with fades.
- Unsupported actions use a cutaway instead of a broken pose.
- Gemini can choose only approved layout, pose, expression, and movement IDs.
- The same player handles no-character, solo, pair, and small-group scenes.
- One full chapter plays without missing, duplicating, or summarizing text.
