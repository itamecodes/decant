# AI Note Taker — Design Spec

**Date:** 2026-09-05
**Status:** Approved for planning
**Author:** Vivek + Claude (brainstorming)

## Summary

A native iOS app that turns a recorded or imported audio/video into a text
transcript, an AI-generated summary, and a list of action items — all processed
through OpenAI's API and stored locally on the device. No backend server, no
cloud sync, no subscriptions. Inspired by the "Cue: AI Note Taker & Recorder"
iOS app, but deliberately stripped to a personal, single-user, single-vendor
build.

## Goals

- Record audio in-app, OR import an existing video/audio file, and get back a
  transcript + summary + action items.
- Copy and share each of the three artifacts (transcript, summary, action items).
- Everything runs locally; the only network calls are to OpenAI.
- Simple enough to be one person's personal tool.

## Non-Goals (explicitly cut from v1)

- Live / real-time transcription (transcript is produced after recording stops).
- Speaker labels / diarization.
- Audio playback or long-term audio retention.
- Summary templates, keyword search, in-app editing.
- Calendar integration, multilingual UI, subscriptions/billing.

These are recorded here so we don't silently re-scope. Several are cheap to add
later (see "Future extensions").

## Users & distribution

- **Audience:** personal use (just the developer, maybe a few friends).
- **Consequence:** the OpenAI API key lives on-device in the iOS Keychain, entered
  once by the user in Settings. This is acceptable *only* because it is not a
  public App Store app — a public build could not safely ship a shared key.

## Architecture

Native **SwiftUI** app, **iOS 17+** (required for SwiftData). No server.

Four isolated components, each with one job and a clear interface:

### 1. AudioInput
- **Record path:** `AVAudioRecorder` capturing to a compact mono `m4a` file.
  Owns mic-permission prompt and recording lifecycle (start/stop/timer).
- **Import path:** system file/photo picker to select a video or audio file.
- **Normalization:** both paths produce ONE small audio file via
  `AVAssetExportSession` — strip any video track, downmix to mono ~16 kHz m4a —
  so uploads stay well under the API's 25 MB limit.
- **Output:** a local temp audio file URL. Deleted after transcription
  succeeds. The user's original imported file is never modified or deleted.

### 2. TranscriptionService
- **Endpoint:** `POST https://api.openai.com/v1/audio/transcriptions`
  (multipart/form-data).
- **Model (default):** `gpt-4o-transcribe` (configurable in Settings;
  `whisper-1` is a fallback).
- **response_format:** `text` (or `json`) — we only need plain transcript text.
- **Input:** the normalized audio file. Accepted formats include
  `m4a`, `mp3`, `wav`, `mp4`, `webm`, etc.
- **Output:** transcript string.
- **Errors surfaced to UI:** missing/invalid key, file too large (>25 MB after
  normalization), network failure, API error.

### 3. SummaryService
- **Endpoint:** `POST https://api.openai.com/v1/chat/completions`.
- **Model (default):** a current GPT model (e.g. `gpt-5.6`), configurable in
  Settings.
- **Structured output:** `response_format: { type: "json_schema", json_schema:
  { name, strict: true, schema } }` so the response is guaranteed-shape JSON.
- **Schema:**
  ```json
  {
    "type": "object",
    "properties": {
      "title":       { "type": "string" },
      "summary":     { "type": "string" },
      "actionItems": { "type": "array", "items": { "type": "string" } }
    },
    "required": ["title", "summary", "actionItems"],
    "additionalProperties": false
  }
  ```
- **Input:** the full transcript text.
- **Output:** `title` (short auto-generated note title), `summary` (prose),
  `actionItems` (list of strings).

### 4. NoteStore
- **SwiftData** persistence layer. No cloud.
- Models:
  ```
  Note {
    id: UUID
    createdAt: Date
    title: String
    transcript: String
    summary: String
    actionItems: [ActionItem]   // ordered
  }
  ActionItem {
    text: String
    done: Bool
  }
  ```

## Core flow

1. User taps **Record** (or **Import**).
2. AudioInput produces a normalized temp audio file.
3. UI shows **Processing** with a stage label:
   - "Transcribing…" → TranscriptionService
   - "Summarizing…" → SummaryService
4. NoteStore saves the `Note`. Temp audio file deleted.
5. App navigates to **Note detail**.

If any step fails, show a clear error and let the user retry; nothing is saved
as a partial note.

## Screens

1. **Notes list** — past notes, newest first; two entry buttons: **Record** and
   **Import**. Tap a note → detail.
2. **Recording** — elapsed timer + Stop button. No live text.
3. **Processing** — spinner with the current stage label.
4. **Note detail** — three sections:
   - **Transcript** — with a **Copy** button.
   - **AI Summary** — with a **Copy** button.
   - **Action Items** — checkbox per item (toggles `done`), with a **Copy** button.
   - A top-level **Share** button opens the iOS share sheet — share the whole
     note, or a single section.
5. **Settings** — OpenAI API key (Keychain-backed), transcription model,
   summary model. First run routes here until a key is present.

## Copy & share behavior

- **Copy:** each section copies its own plain text to the pasteboard.
- **Share:** iOS share sheet (`UIActivityViewController` / SwiftUI `ShareLink`).
  Default payload = the whole note formatted as text (title, summary, action
  items, transcript). Per-section share also available.

## API limits & edge cases

- **25 MB upload cap** (OpenAI). Mono compression makes this roughly ~2 hours of
  audio in a single request — sufficient for v1. If a normalized file still
  exceeds the cap, show an explicit "recording too long" error. **Chunking of
  very long files is out of scope for v1.**
- **No key set:** app is unusable until the key is entered; Settings is the
  first-run destination.
- **Interruptions during recording** (phone call, etc.): stop cleanly and keep
  whatever was captured so far.

## Latest OpenAI API reference (verified via docs on 2026-09-05)

- **Transcriptions:** `POST /v1/audio/transcriptions`, 25 MB limit. Models:
  `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`, `whisper-1`,
  `gpt-4o-transcribe-diarize`. Formats: flac, mp3, mp4, mpeg, mpga, m4a, ogg,
  wav, webm.
- **Structured summary:** Chat Completions `response_format` = `json_schema`
  with `strict: true`; current flagship chat model `gpt-5.6`.

## Future extensions (not now)

- **Speaker labels** — swap transcription model to
  `gpt-4o-transcribe-diarize` (`response_format: diarized_json`); same vendor,
  no second key.
- Audio retention + playback, summary templates, keyword search, in-app editing,
  chunking for >2h recordings.

## Testing approach

- Each component is independently testable:
  - AudioInput: normalization produces a valid, under-limit m4a from a sample video.
  - TranscriptionService / SummaryService: unit tests against a mocked URL layer
    (verify request shape, parse responses, map errors).
  - NoteStore: CRUD round-trips in an in-memory SwiftData container.
- A light end-to-end pass with a real short sample once keys are configured.
