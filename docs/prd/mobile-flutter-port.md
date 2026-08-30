# PRD — RogSheba Mobile (Flutter port)

Companion to [`MOBILE_PLAN.md`](../MOBILE_PLAN.md) (phasing, tech stack, design tokens) and [`MOBILE_API.md`](../MOBILE_API.md) (API contract). This document defines *what* we are building and *how we will test it*; the plan defines *when* and *by whom*.

---

## Problem Statement

RogSheba is a free Bangla-language AI health triage service. Someone in Bangladesh who feels unwell describes their symptoms in Bangla — by voice or by typing — and is told, in Bangla, whether home care is enough, whether they should see a doctor within a day or two, or whether this is an emergency and they need to go now. It also finds the nearest hospitals.

Today this only exists on the web, and the web is the wrong place for it:

- **Voice barely works.** The whole product is built around speaking Bangla, but `SpeechRecognition` is missing on most Android browsers and unreliable elsewhere. The one feature that makes the service usable for a user with low literacy is the feature least likely to work.
- **Bangla renders inconsistently.** The web relies on system font fallback, so text renders differently — or as tofu boxes — depending on the device.
- **Reaching it takes effort.** A person having chest pain has to open a browser, remember a URL, and wait for a page load. There is no icon to tap.
- **GPS is second-class.** Browser location prompts are easy to dismiss and easy to mis-handle, and the web fetches clinics from OpenStreetMap directly from the browser, so upstream slowness is felt by the user.
- **Nothing works offline.** Advice already received disappears the moment connectivity drops, and there is no offline list of emergency numbers.

The backend is already built and public (`/api/public/v1`), and it already exposes an `/emergency` endpoint the web never uses. The gap is purely the client.

## Solution

A Flutter app for Android and iOS that is a faithful port of the web experience — same screens, same Bangla copy, same triage logic — with the four platform capabilities the web cannot deliver reliably:

- **On-device Bangla speech recognition** (`bn-BD`), with partial results shown live as the user speaks, and typing always available as a fallback.
- **On-device Bangla text-to-speech** so the triage result can be listened to rather than read.
- **Bundled Bangla fonts**, so text renders identically on every device.
- **Native location and offline cache**, with the last triage result and the emergency number list available with no connectivity.

The app calls the existing `/api/public/v1` endpoints. It does **not** talk to OpenStreetMap directly — the `/clinics` endpoint already does that, with a curated Dhaka fallback list built in. No backend work is required.

Two screens plus one sheet, mirroring the web:

- **Home** — hero, voice/text symptom entry, triage result card
- **Clinics** — nearest hospitals by GPS, with directions deep links
- **Emergency sheet** — new; the Bangladesh hotline list from `/emergency`, cached for offline use

## User Stories

### Entering symptoms

1. As a person feeling unwell, I want to type my symptoms in Bangla, so that I can get advice without speaking out loud in a room with other people.
2. As a person with low literacy, I want to speak my symptoms in Bangla instead of typing, so that I can use the service at all.
3. As a user speaking my symptoms, I want to see the words appear on screen as I say them, so that I know the app is hearing me correctly.
4. As a user speaking my symptoms, I want a clearly visible "listening" indicator, so that I know when the microphone is active.
5. As a user who has finished speaking, I want to tap the same button to stop, so that recording does not continue after I am done.
6. As a user who mis-spoke, I want to edit the transcribed text before submitting, so that I can correct recognition errors.
7. As a user who wants to start over, I want a clear button, so that I can empty the field in one tap.
8. As a user on a device without Bangla speech recognition, I want the app to tell me plainly that voice is unavailable and let me type, so that I am not stuck at a broken microphone button.
9. As a first-time user who does not know what to write, I want tappable example symptom phrases, so that I understand what kind of input the app expects.
10. As a user who has not typed anything, I want the submit button disabled, so that I do not send an empty request.
11. As a user whose request is in flight, I want the submit button to show a Bangla progress state and be un-tappable, so that I do not submit twice.
12. As a privacy-conscious user, I want the app never to ask for or transmit my name, phone number or NID, so that my health query cannot be traced back to me.

### Receiving triage

13. As a user awaiting a result, I want the screen to scroll to the result when it arrives, so that I do not have to hunt for it.
14. As a user with an emergency, I want a red band that unambiguously says to go to hospital now, so that I do not underestimate my situation.
15. As a user with an emergency, I want a large one-tap ৯৯৯ call button, so that I can reach emergency services without dialling.
16. As a user with an emergency, I want a secondary ১৬২৬৩ health-hotline button, so that I have an option when ৯৯৯ is busy.
17. As a user with a moderate condition, I want an amber result and a direct route to nearby clinics, so that I know to be seen within a day or two and where to go.
18. As a user with a mild condition, I want a green result with home-care steps, so that I do not travel to a hospital unnecessarily.
19. As a user reading my result, I want a short Bangla headline and a one-or-two sentence summary, so that I grasp my situation immediately.
20. As a user reading my result, I want the advice as a numbered list, so that I can follow the steps in order.
21. As a user reading my result, I want the warning signs listed separately and visually distinct, so that I know exactly what would mean "go to hospital now".
22. As a user who cannot read comfortably, I want to tap a speaker button and hear the result read aloud in Bangla, so that I can understand it by listening.
23. As a user listening to the result, I want to tap the same button to stop playback, so that I can silence it in a public place.
24. As a user who navigates away mid-playback, I want speech to stop automatically, so that audio does not continue in the background.
25. As a user on a device with no Bangla TTS voice, I want the speaker button hidden rather than my result read in an English accent, so that I am not given unintelligible audio.
26. As a user, I want the medical disclaimer visible on every result, so that I understand this is not a doctor's advice.
27. As a user given a follow-up question, I want to see it, so that I know what additional detail would sharpen the assessment.
28. As a user who received a result, I want a button to find nearby clinics from within the result, so that I do not have to navigate back and search.

### Finding clinics

29. As a user opening the clinics screen, I want it to locate me automatically, so that I do not have to press anything.
30. As a user waiting for location, I want a Bangla message telling me it is finding my position, so that I know why I am waiting.
31. As a user waiting for clinic data, I want a distinct Bangla loading message, so that I can tell the two waits apart.
32. As a user who denied location permission, I want a list of major Dhaka hospitals plus a plain explanation of why, so that the screen is still useful.
33. As a user whose location failed for another reason, I want the same fallback list and an explanation, so that a GPS failure never leaves me with an empty screen.
34. As a user who changed my mind about permissions, I want a retry button, so that I can locate myself without restarting the app.
35. As a user browsing clinics, I want them ordered nearest-first, so that the most useful option is at the top.
36. As a user browsing clinics, I want each entry to show its distance in kilometres, so that I can judge whether I can get there.
37. As a user browsing clinics, I want the facility name and address where available, so that I can identify the place.
38. As a user browsing clinics, I want to see whether a facility is a hospital, clinic, government or private, so that I can pick appropriately.
39. As a user who picked a clinic, I want a directions button that opens my maps app routed from where I am, so that I can start travelling immediately.
40. As a user who picked a clinic, I want a "view on map" option, so that I can see its position before committing to travel.

### Emergency numbers

41. As a user in a crisis, I want the emergency hotline list reachable from anywhere in the app, so that I do not have to navigate to find it.
42. As a user viewing the hotline list, I want each number labelled in Bangla, so that I know which one to call.
43. As a user viewing the hotline list, I want to tap a number to dial it, so that I do not have to memorise or copy it.
44. As a user with no connectivity, I want the hotline list still to show from cache, so that the numbers are there when I most need them.

### Reliability, offline, errors

45. As a user on a slow connection, I want the app to wait up to 30 seconds for triage before giving up, so that a slow-but-working request is not cancelled prematurely.
46. As a user hitting a rate limit or a server hiccup, I want the app to retry automatically with increasing delays, so that a transient failure does not become my problem.
47. As a user whose request failed for a reason I caused, I want an immediate Bangla error rather than a long silent retry, so that I can fix my input and move on.
48. As a user seeing an error, I want it in Bangla, so that I can understand what went wrong.
49. As a user who lost connectivity, I want to see my most recent triage result from cache, so that advice I already received is not lost.
50. As a user who is offline, I want a clear banner saying so, so that I understand why a new request will not work.
51. As a user reopening the app, I want it to start fast without a blocking network call, so that I can begin typing immediately.

### Accessibility, presentation, platform

52. As a user with reduced vision, I want to increase system text size substantially without text being cut off, so that I can read the advice.
53. As a screen-reader user, I want every button and status to be announced meaningfully in Bangla, so that I can operate the app without sight.
54. As a user with limited motor control, I want tap targets large enough to hit reliably, so that I do not mis-tap the emergency call button.
55. As a user in a dark room, I want a dark theme matching my system setting, so that the screen does not dazzle me.
56. As a user on any Android or iOS device, I want Bangla text to render correctly, so that I never see empty boxes instead of letters.
57. As a user, I want the app to explain why it needs microphone and location access before asking, so that I can make an informed decision.
58. As a user who denied a permission, I want the app to keep working in a reduced mode rather than blocking me, so that I am never locked out.
59. As a returning user, I want an app icon on my home screen, so that reaching help takes one tap.

## Implementation Decisions

### Architecture

- **Feature-first modules** — `triage`, `clinics`, `emergency` — each with `data` / `domain` / `presentation`, over a shared `core` (config, theme, network, router, services, Bangla strings) and `shared/widgets`. Rationale: the three features share almost no domain logic, only infrastructure.
- **Riverpod is the single composition root.** Every replaceable dependency is a provider. This is deliberate and is what makes the testing strategy below possible with one injection point.
- **`go_router`** mirrors the web's two routes (`/`, `/clinics`) so deep links stay aligned with the web.
- **Bangla copy lives in one module** (`core/l10n/bn_strings.dart`), lifted verbatim from the web components. It is not re-translated, and it is not scattered across widgets. The app is Bangla-only in v1; no `.arb`/localisation machinery, because there is no second locale to justify it.

### API client

- The app calls **only** `/api/public/v1`. It does not call OpenStreetMap or the AI gateway directly. The web's client-side Overpass query in `clinics.ts` is **not** ported — `GET /clinics` supersedes it and already includes the Dhaka fallback.
- **Envelope handling is centralised.** One layer unwraps `{success, data}` / `{success, error}` and turns the error branch into a typed exception carrying the API's `code` and its already-Bangla `message`. Feature code never sees the envelope.
- **UTF-8 decoding is explicit**, not left to platform defaults. All payloads are Bangla.
- **Timeouts:** triage 30s; all other endpoints 10s.
- **Retry policy:** `429` and `5xx` only, three attempts, backoff `5s → 15s → 30s`. All other `4xx` fail immediately. This lives in one interceptor, not in repositories.
- **Delay injection:** the backoff delay is supplied through the provider graph rather than calling `Future.delayed` directly, so retry timing is testable without real waiting.
- **Lenient parsing.** Per the API's versioning note, unknown fields are ignored and never cause a decode failure.
- **Triage level fallback:** a missing or unrecognised `level` is treated as `YELLOW`, matching the server's own normalisation in `triage.server.ts`. Defaulting toward caution is a safety decision, not a convenience one.

### Domain models

Immutable models with explicit nullability, mirroring the API contract exactly:

- `TriageResult` — `level` (enum `GREEN | YELLOW | RED`), `titleBn`, `summaryBn`, `adviceBn[]`, `warningSignsBn[]`, `followupQuestionBn?`, `disclaimerBn`, `emergencyNumber?`, `createdAt`
- `Clinic` — `id`, `name`, `lat`, `lon`, `distanceKm`, `type?`, `address?`
- `ClinicsResult` — `source` (`openstreetmap | fallback`), `origin`, `clinics[]`. `source` is carried into the domain deliberately: the UI must show the fallback warning banner when it is `fallback`.
- `EmergencyContact` — `labelBn`, `number`, `type`

### Device capabilities

Four narrow interfaces, each with a real plugin-backed implementation and a hand-written fake:

- `SpeechService` — exposes a **stream of partial and final transcripts** plus a capability check for `bn-BD`. Streaming, not callback-based, so the UI can render interim text and tests can drive a realistic partial→final sequence.
- `TtsService` — speak / stop / capability check for a `bn-BD` voice. Speech stops on dispose.
- `LocationService` — returns an explicit outcome union (`granted with coords`, `denied`, `service disabled`, `failed`), never a bare nullable. The web collapses these into a single fallback path; mobile keeps them distinct because the recovery differs (retry vs. open settings).
- `LauncherService` — `tel:` dialling and maps URL construction, so URL-building is unit-testable independently of actually launching anything.

The **maps directions URL** is built exactly as the web does: `https://www.google.com/maps/dir/?api=1&origin={userLat},{userLon}&destination={lat},{lon}`, degrading to the `search` variant when the user's coordinates are unknown.

### Caching

`CacheService` over `shared_preferences`, holding two things only:

- the most recent `TriageResult`, shown read-only when offline
- the `/emergency` contact list, with a 24-hour TTL per the API guidance

Symptom text is **never** persisted — it is the most sensitive thing the user types, and retaining it serves no feature.

### Theming

- Design tokens are ported as pre-converted hex values (see `MOBILE_PLAN.md` §3); no runtime oklch conversion.
- Triage colours live in a **`ThemeExtension`**, not as loose constants, so the level→colour mapping resolves through the theme and golden tests exercise both brightnesses through the same path.
- Both fonts are **bundled assets**. System font fallback is explicitly not relied upon.

### Deliberate deviations from web

| Web behaviour | Mobile behaviour | Reason |
|---|---|---|
| Browser fetches clinics from Overpass | App calls `GET /clinics` | Server already handles fallback and shields the client from upstream flakiness |
| No emergency hotline list | `EmergencySheet` from `GET /emergency` | Endpoint exists and is unused; high value in a crisis |
| No offline behaviour | Last triage + hotlines cached | Connectivity is unreliable on mobile |
| Location failure modes collapsed | Distinct denied / disabled / failed outcomes | Different recovery actions are possible on mobile |

Everything else — layout, copy, ordering, triage semantics — is a faithful port.

## Testing Decisions

### What makes a good test here

A test asserts **what the user experiences**, never how it is achieved. "Enter symptoms, tap পরামর্শ নিন, see a red band with a ৯৯৯ button" is a test. "The controller's state transitions to `AsyncLoading`" is not — that is the implementation restating itself, and it will need rewriting the first time we refactor without any user-visible change.

Concretely, tests may reference: rendered Bangla text, semantic labels, tap targets, which HTTP request was issued, and which URL was launched. They may not reference: provider internals, controller state enums, widget private state, or method call counts on collaborators.

### The seam

**One injection point: the `ProviderScope` override boundary.** Every test pumps the *real* application widget inside a `ProviderScope` with overrides. There is no second wiring path, no test-only widget tree, and no test-only navigation.

Two things are faked through that one point:

1. **HTTP transport** — faked at the **Dio adapter level**, i.e. as low as possible while staying off the network. Deliberately *not* at the repository level: repository fakes would bypass JSON decoding, envelope unwrapping, UTF-8 handling, error-code mapping, retry and backoff — which is precisely the code that the parity rules depend on and that is most likely to break. Faking at the transport keeps all of it under test on every widget test.
2. **Device capabilities** — the four service interfaces. Unavoidable: `speech_to_text`, `flutter_tts`, `geolocator` and `url_launcher` all cross platform channels and cannot run in a widget test. Their fakes are hand-written rather than mock-generated, so a `SpeechService` fake can emit a realistic partial→final transcript stream and a `LocationService` fake can return each outcome of the union.

Two things that might look like seams and deliberately are **not**:

- **`shared_preferences`** — use the plugin's own mock-initial-values hook and let the real `CacheService` run. Adding an interface here would buy nothing and would stop us testing serialisation.
- **The clock** — retry backoff is tested with Flutter's fake-async support plus the injected delay, not by making time an app-wide abstraction.

### Test layers

| Layer | Covers | Boundary |
|---|---|---|
| **Unit** | Envelope + error-code mapping, retry policy (which statuses, how many attempts, what delays), lenient decoding and unknown-field tolerance, triage-level fallback to `YELLOW`, maps URL construction, distance formatting, cache TTL expiry | Pure Dart, no widgets |
| **Widget** | Every user story above that has a visible outcome — driven through the real screens with faked transport + device services | `ProviderScope` overrides |
| **Golden** | `TriageCard` at GREEN / YELLOW / RED × light / dark (6 goldens); clinics list in ready and fallback states | Same |
| **Integration** | Happy path end-to-end on a real device: speak → transcript → triage → open clinics → tap directions | Real plugins, faked transport |
| **Manual device matrix** | Microphone and location permission denial and revocation, missing `bn-BD` speech and TTS voices, 200% text scaling | Real devices, Android 13+/14 and iOS 17+ |

### Cases that must be tested because they are safety-relevant

- A `RED` result renders the emergency block and a working `tel:999` action.
- An unrecognised or absent `level` renders as `YELLOW` — never as `GREEN`.
- `disclaimer_bn` renders on every result at every level.
- Location denial still produces a usable clinic list with the fallback banner.
- A `4xx` other than `429` is **not** retried, and its Bangla message reaches the user unmodified.

### Prior art

**There is none.** The web project has no test suite, no ADRs and no glossary, so the mobile repository establishes the pattern rather than following one. The first test written — a widget test for the triage happy path, pumping the real app with a faked transport — should be treated as the reference example that later tests copy, and it should be reviewed with that weight.

## Out of Scope

- **Backend changes of any kind.** `/api/public/v1` is complete and stable; if a gap appears it is a separate PRD.
- **Accounts, authentication, history sync.** The API is public and anonymous, and the Supabase files in the web project are unused scaffolding, not a signal of intent.
- **Multi-turn conversation (beyond the follow-up answer box).** Mobile now surfaces the `followup_question_bn` as a chat bubble with a typed or voice answer, sending it to `/triage/followup` and re-rendering until `is_complete`. Anything further — an unbounded historical thread persisted across sessions — remains v1.1.
- **In-app maps.** We deep-link to Google Maps / OpenStreetMap exactly as the web does. No maps SDK, no API key, no map view.
- **Push notifications**, medication reminders, appointment booking, doctor chat.
- **Tablet- and landscape-specific layouts.** Phone portrait is the target; the app must not break in landscape, but it is not optimised for it.
- **Localisation beyond Bangla.** The product is Bangla-first by design; English UI is not a goal.
- **Analytics.** Not in v1 — and if added later, health-query content must never be an event property.

## Further Notes

- **This is a medical-adjacent app and both stores will review it as one.** The disclaimer being always-visible and the absence of diagnosis or dosage claims are not merely UX choices — they are the review argument. The server's system prompt already forbids naming antibiotics or dosages; the client must not add any such text of its own.
- **The `YELLOW` default is a safety decision.** When the model returns something unparseable, the user is told to see a doctor within 24–72 hours rather than told they are fine. Any future refactor that touches this path should preserve that direction of failure.
- **Bangla text is longer than English and wraps unpredictably.** No fixed heights anywhere in the tree; the overflow audit is a scheduled task, not an afterthought.
- **Voice is the product, not a feature.** If `bn-BD` recognition proves unusable on a meaningful share of target devices during Phase 1, that is a finding worth escalating before Phase 2 UI work is built on top of it.
- **The `/emergency` endpoint is already live and unused.** It is the cheapest high-value addition in this port.
