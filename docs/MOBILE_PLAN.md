# RogSheba Mobile — Flutter Implementation Plan

Port of the RogSheba web app (Bangla AI health triage) to Android + iOS. **UI and logic stay identical to web.** Backend is done — see [`MOBILE_API.md`](./MOBILE_API.md); no backend work in this plan.

- **Team:** 2 developers (Dev A, Dev B) working in parallel
- **Duration:** ~20 working days (4 weeks), 5 phases × 2 parallel tracks
- **Base URL:** `https://project-kitchen-ready.lovable.app/api/public/v1`

---

## 1. Scope — what we are porting

| Web | Mobile equivalent | Notes |
|---|---|---|
| `src/routes/index.tsx` | `HomeScreen` | Hero + voice input + triage result |
| `src/components/VoiceInput.tsx` | `VoiceInputField` | Web Speech API → `speech_to_text` |
| `src/components/TriageCard.tsx` | `TriageCard` | `speechSynthesis` → `flutter_tts` |
| `src/routes/clinics.tsx` | `ClinicsScreen` | Browser geolocation → `geolocator` |
| `src/lib/clinics.ts` (client-side Overpass) | `GET /clinics` | **Changed:** mobile calls our API, not Overpass directly |
| `src/lib/triage.functions.ts` (server fn) | `POST /triage` | Same contract |
| — | `EmergencySheet` | **New:** `GET /emergency`, unused on web |
| `src/styles.css` tokens | `AppTheme` + `ThemeExtension` | oklch converted to hex in §3 |

### Explicitly out of scope for v1
- Auth / accounts (API is public, no auth; Supabase files in web are unused scaffolding)
- Longer-term conversation history beyond the answerable /triage/followup loop (that loop itself is in scope — see 2A).
- Push notifications, in-app maps SDK (we deep-link to Google Maps / OSM like web does)

---

## 2. Tech stack

| Concern | Choice | Why |
|---|---|---|
| SDK | Flutter 3.32+ / Dart 3.8 | Matches installed toolchain |
| State | `flutter_riverpod` + `riverpod_generator` | `AsyncNotifier` maps 1:1 onto web's `useMutation`/`useQuery` |
| Network | `dio` + interceptors | Needed for the retry/timeout rules in `MOBILE_API.md` |
| Models | `freezed` + `json_serializable` | Immutable, `unknown fields ignored` per API versioning note |
| Routing | `go_router` | Mirrors TanStack routes `/` and `/clinics` |
| Voice in | `speech_to_text` (`bn-BD`) | Replaces `SpeechRecognition` |
| Voice out | `flutter_tts` (`bn-BD`, rate 0.95) | Replaces `speechSynthesis` |
| Location | `geolocator` + `permission_handler` | Replaces `navigator.geolocation` |
| Deep links | `url_launcher` | `tel:999`, Google Maps directions |
| Cache | `shared_preferences` | Last triage result + `/emergency` (24h TTL) |
| Lint | `very_good_analysis` | Strict by default |
| Test | `flutter_test`, `mocktail`, `golden_toolkit`, `integration_test` | Incl. golden tests for the 3 triage levels |
| CI | GitHub Actions | analyze → test → build |

### Project structure

```
lib/
  main.dart
  core/
    config/          flavors, base URLs, timeouts
    theme/           app_colors.dart, app_theme.dart, triage_colors.dart (ThemeExtension)
    network/         dio_client.dart, api_response.dart, api_exception.dart, retry_interceptor.dart
    router/          app_router.dart
    services/        speech_service, tts_service, location_service, launcher_service, cache_service
    l10n/            bn_strings.dart  (all Bangla copy, lifted verbatim from web)
  features/
    triage/    data/ (dto, repository) · domain/ (model) · presentation/ (screen, controller, widgets)
    clinics/   data/ · domain/ · presentation/
    emergency/ data/ · domain/ · presentation/
  shared/widgets/    app_button, app_card, app_chip, error_banner, loading_state
test/  · integration_test/
```

---

## 3. Design tokens (oklch → hex, pre-converted)

Drop these straight into `core/theme/app_colors.dart`. Radius base = `16.0` (`--radius: 1rem`); the web scale `sm/md/lg/xl/2xl/3xl` = `12 / 14 / 16 / 20 / 24 / 28`.

**Light**

| Token | Hex | Token | Hex |
|---|---|---|---|
| background | `#FCFAF1` | destructive | `#D40C1A` |
| foreground | `#002022` | destructiveForeground | `#FEFCF4` |
| surface / card | `#FFFFFF` | border | `#D2E3DC` |
| primary | `#006B5A` | input | `#D8E9E2` |
| primaryForeground | `#FCFAF3` | ring | `#006B5A` |
| secondary | `#D9F2E8` | triageGreen | `#2EA957` |
| secondaryForeground | `#00322F` | triageGreenForeground | `#FEFCF4` |
| muted | `#F1EFE4` | triageYellow | `#F3BA25` |
| mutedForeground | `#4F696A` | triageYellowForeground | `#301D00` |
| accent | `#F87B5C` | triageRed | `#E31029` |
| accentForeground | `#FEFCF4` | triageRedForeground | `#FEFCF4` |

**Dark overrides** (triage colors unchanged)

| Token | Hex | Token | Hex |
|---|---|---|---|
| background | `#001517` | secondary | `#00312E` |
| foreground | `#F7F5EE` | secondaryForeground | `#F7F5EE` |
| surface / card | `#002022` | muted | `#052A2C` |
| primary | `#2FBDA7` | mutedForeground | `#8BA59F` |
| primaryForeground | `#001517` | accent | `#FF8465` |
| border | `white @ 12%` | input | `white @ 14%` |

**Typography** — bundle both fonts as assets (do **not** rely on system fallback):
`Noto Sans Bengali` → all Bangla text (web `.font-bangla`) · `Plus Jakarta Sans` → Latin/display (web `--font-display`).

**shadowSoft** = two layers: `0 1px 2px rgba(0,32,34,.04)` + `0 8px 24px rgba(0,32,34,.06)`.

---

## 4. Logic parity rules

Non-negotiable behaviours lifted from the web + API doc:

1. **Timeouts** — `/triage` 30s, everything else 10s.
2. **Retry** — only `429` and `5xx`, backoff `5s → 15s → 30s`. Never auto-retry other `4xx`.
3. **Error copy** — the API already returns Bangla in `error.message`; show it verbatim. Map codes per `MOBILE_API.md` table.
4. **Envelope** — every response is `{success, data}` or `{success, error}`. Decode with **explicit UTF-8**.
5. **Triage level fallback** — unknown/missing `level` ⇒ treat as `YELLOW` (matches `triage.server.ts`).
6. **RED** ⇒ red band + `৯৯৯ কল` and `১৬২৬৩` buttons via `tel:`. **YELLOW** ⇒ amber band + clinics CTA. **GREEN** ⇒ green band.
7. **`disclaimer_bn` always renders.** Never hide it.
8. **Clinics fallback** — GPS denied/failed ⇒ call `/clinics` with no `lat`/`lon`, show the returned Dhaka `source: "fallback"` list plus the Bangla warning banner (same strings as web).
9. **Directions URL** — `https://www.google.com/maps/dir/?api=1&origin={userLat},{userLon}&destination={lat},{lon}`; without coords use the `search` variant.
10. **No PII** — never put names/phones/NID into `symptoms`. Add a lint-level review check.
11. **Bengali numerals** in UI chrome (৯৯৯, ১৬২৬৩) exactly as web.

---

## 5. Phases

Every phase splits into **Track A (Dev A)** and **Track B (Dev B)** that run in parallel. Each phase ends at a **sync point** — both tracks merge to `develop` and the checklist must pass before the next phase starts.

### Phase 0 — Foundation · 3 days
Contract agreed before splitting: token names in `app_colors.dart` and the `core/` folder layout.

| | Track A — Dev A | Track B — Dev B |
|---|---|---|
| **0A** | Flutter project scaffold, folder structure, `very_good_analysis`, flavors (`dev`/`prod` base URLs), `.gitignore`, GitHub Actions (analyze + test + build APK) | |
| **0B** | | Design system: `app_colors.dart` (§3), `app_theme.dart` light+dark, `TriageColors` ThemeExtension, bundled fonts, `shadowSoft`, radius scale, shared widgets (`AppButton` pill, `AppCard`, `AppChip`) |

**Sync 0:** app boots on both platforms showing a themed placeholder; CI green.

### Phase 1 — Data & device services · 4 days

| | Track A — Dev A | Track B — Dev B |
|---|---|---|
| **1A** | Dio client + `ApiResponse<T>` envelope + `ApiException` code mapping + retry/backoff interceptor + timeouts; freezed models `TriageResult`, `Clinic`, `EmergencyContact`; `TriageRepository`, `ClinicsRepository`, `EmergencyRepository`; unit tests against recorded fixtures | |
| **1B** | | `SpeechService` (`bn-BD`, partial + final results, permission states), `TtsService` (`bn-BD`, rate 0.95, stop-on-dispose), `LocationService` (permission granted/denied/service-off), `LauncherService` (`tel:`, maps URL builder), `CacheService` (last triage + emergency 24h TTL) |

**Sync 1:** repositories return typed models from the live API; each service demoed on a real device.

### Phase 2 — Screens · 6 days (largest phase)

| | Track A — Dev A | Track B — Dev B |
|---|---|---|
| **2A** | `HomeScreen`: app bar (logo + ৯৯৯ pill), hero, `VoiceInputField` (multiline field + mic button with pulse animation + "শুনছি…" indicator + clear), example chips, submit button with `বিশ্লেষণ চলছে…` state, error banner, feature strip. `TriageCard`: level band + TTS toggle, RED emergency block, numbered advice list, warning-signs block, follow-up block, clinics CTA, disclaimer | |
| **2B** | | `ClinicsScreen`: auto-locate on open, `locating`/`loading`/`ready`/`denied`/`error` states with the web's Bangla strings, clinic list item (index, name, distance chip, address, দিকনির্দেশ / ম্যাপে দেখুন / type buttons), retry button, fallback list. `EmergencySheet`: bottom sheet from `/emergency`, cached, tap-to-call |

**Sync 2:** both screens fully functional against the live API.

### Phase 3 — Integration, offline & polish · 4 days

| | Track A — Dev A | Track B — Dev B |
|---|---|---|
| **3A** | `go_router` wiring (`/` ↔ `/clinics`, emergency sheet route), offline mode (cached last triage + no-network banner), dark theme parity pass, accessibility (semantics labels, 48dp targets, text scaling to 200%), Bangla text overflow audit | |
| **3B** | | Test suite: unit (repos, error mapping, distance formatting), widget tests per screen, **golden tests for GREEN/YELLOW/RED × light/dark**, integration test happy path; device matrix for permission denial (mic, location) on Android 13+/14 and iOS 17+ |

**Sync 3:** feature-complete, CI runs the full test suite, no P1 bugs open.

### Phase 4 — Release · 3 days

| | Track A — Dev A | Track B — Dev B |
|---|---|---|
| **4A** | **Android**: app icon + splash, signing config, versioning, R8/ProGuard rules, permission rationale strings (`RECORD_AUDIO`, `ACCESS_FINE_LOCATION`, `INTERNET`), Play Console internal track, Data Safety form (no PII collected) | |
| **4B** | | **iOS**: icons + launch screen, `Info.plist` usage strings (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSLocationWhenInUseUsageDescription`), signing + provisioning, TestFlight build, App Store privacy nutrition labels; crash reporting + release checklist |

**Sync 4:** internal-track build on Play Console and TestFlight, both installable.

---

## 6. Dependency graph

```
Phase 0 ──┬── 0A scaffold ──┐
          └── 0B theme ─────┴──► Sync 0
                                   │
Phase 1 ──┬── 1A api+models ──┐    │
          └── 1B services ────┴──► Sync 1
                                   │
Phase 2 ──┬── 2A home+card ───┐    │  (2A needs 1A+1B · 2B needs 1A+1B)
          └── 2B clinics+sos ─┴──► Sync 2
                                   │
Phase 3 ──┬── 3A integration ─┐    │
          └── 3B tests ───────┴──► Sync 3
                                   │
Phase 4 ──┬── 4A android ─────┐    │
          └── 4B ios ─────────┴──► Ship
```

**Blocking rule:** Phase 2 cannot start until Sync 1 passes — both screens depend on both tracks of Phase 1. Phases 0, 3 and 4 tracks are fully independent within the phase.

---

## 7. Definition of done (per issue)

- [ ] Matches the web screen visually (side-by-side screenshot in the PR)
- [ ] Bangla strings copied verbatim from web — no re-translation
- [ ] `flutter analyze` clean, tests added, CI green
- [ ] Works in light **and** dark theme
- [ ] Loading / empty / error states all handled
- [ ] Follow-up question answerable: thread renders, answer (typed or voice) posts to `/triage/followup`, result re-renders, loop exits on `is_complete`
- [ ] Reviewed by the other developer

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| `bn-BD` speech recognition unavailable on some Android devices | Detect at init; hide the mic and show the web's "ভয়েস সাপোর্ট নেই — টাইপ করুন" message. Typing always works. |
| `bn-BD` TTS voice missing on iOS | Fall back to silent (hide the speaker button) rather than reading Bangla with an English voice |
| `/triage` latency 2–6s | 30s timeout + Bangla loading state, exactly as web |
| Bangla text overflow in fixed-height widgets | No fixed heights; overflow audit in 3A |
| Upstream Overpass flakiness | Already handled server-side — the API falls back to the Dhaka list |
| App-store medical-app review scrutiny | `disclaimer_bn` always visible; no diagnosis or dosage claims (system prompt already forbids them) |
