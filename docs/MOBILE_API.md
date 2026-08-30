# RogSheba Mobile API — v1

Bangla AI health-triage backend for the RogSheba mobile app (Android / iOS / Flutter / React Native).

- **Base URL (production):** `https://project-kitchen-ready.lovable.app/api/public/v1`
- **Base URL (staging/preview):** `https://id-preview--ec4ef559-37b7-4522-a535-4c0f3aa92061.lovable.app/api/public/v1`
- **Auth:** none required (public endpoints). Do not send user PII.
- **Content type:** `application/json; charset=utf-8` (UTF-8 is required — all text is Bangla).
- **CORS:** `*` with `GET, POST, OPTIONS`.

## Response envelope

Every endpoint returns the same envelope.

Success:
```json
{ "success": true, "data": { } }
```

Error:
```json
{
  "success": false,
  "error": {
    "code": "validation_failed",
    "message": "Invalid request body.",
    "details": [{ "path": "symptoms", "message": "String must contain at least 3 character(s)" }]
  }
}
```

`details` is optional and present only for validation errors.

### Error codes

| HTTP | code | Meaning | Mobile handling |
|---|---|---|---|
| 400 | `invalid_json` | Body was not valid JSON | Fix client serialization |
| 422 | `validation_failed` | Body/query failed validation | Show inline field error |
| 429 | `rate_limited` | Too many AI requests | Retry with backoff (5s, 15s, 30s) |
| 402 | `credits_exhausted` | AI credits finished | Show "সার্ভিস সাময়িকভাবে বন্ধ" |
| 502 | `ai_upstream_error` / `clinic_lookup_failed` | Upstream service failed | Retry once, then fallback UI |
| 500 | `internal_error` / `ai_not_configured` | Server problem | Generic error toast |

Only `429` and `5xx` are retryable. Never auto-retry `4xx` (except 429).

---

## 1. `GET /health`

Service ping + endpoint list. Use on app cold start.

**Request:** no params.

**Response 200**
```json
{
  "success": true,
  "data": {
    "status": "ok",
    "service": "rogsheba-api",
    "version": "1.0.0",
    "time": "2026-08-05T15:10:00.000Z",
    "endpoints": [
      "GET /api/public/v1/health",
      "POST /api/public/v1/triage",
      "GET /api/public/v1/clinics",
      "GET /api/public/v1/emergency"
    ]
  }
}
```

---

## 2. `POST /triage`

The core feature: send Bangla symptom text (typed or from speech-to-text), receive a triage level with Bangla advice.

### Request body

| Field | Type | Required | Rules |
|---|---|---|---|
| `symptoms` | string | ✅ | trimmed, 3–2000 chars, Bangla or English |
| `history` | string[] | ❌ | max 10 items, each 1–500 chars. Previous turns of the conversation (oldest → newest); only the last 6 are used |

```json
{
  "symptoms": "গত ৩ দিন ধরে গলা ব্যথা, জ্বর ১০১°F আর মাথা ব্যথা",
  "history": ["আগে বলেছিলাম কাশি আছে"]
}
```

### Response 200

| Field | Type | Notes |
|---|---|---|
| `level` | `"GREEN" \| "YELLOW" \| "RED"` | GREEN = home care, YELLOW = clinic in 24–72h, RED = go to ER now |
| `title_bn` | string | Short Bangla headline (3–6 words) |
| `summary_bn` | string | 1–2 sentence Bangla summary |
| `advice_bn` | string[] | 3–6 action points in Bangla |
| `warning_signs_bn` | string[] | 2–5 red-flag signs in Bangla |
| `followup_question_bn` | string \| null | One follow-up question, or `null` |
| `disclaimer_bn` | string | Always show this in the UI |
| `emergency_number` | string \| null | `"999"` when `level === "RED"`, else `null` |
| `created_at` | string | ISO-8601 UTC timestamp |

```json
{
  "success": true,
  "data": {
    "level": "YELLOW",
    "title_bn": "গলা ব্যথা ও জ্বর",
    "summary_bn": "আপনার লক্ষণ সম্ভবত গলার সংক্রমণ নির্দেশ করছে। ২৪-৭২ ঘণ্টার মধ্যে ডাক্তার দেখানো ভালো।",
    "advice_bn": [
      "প্রচুর কুসুম গরম পানি ও তরল খান",
      "কুসুম গরম লবণ পানি দিয়ে গার্গল করুন",
      "পর্যাপ্ত বিশ্রাম নিন",
      "জ্বরের জন্য প্যারাসিটামল প্যাকেটের নির্দেশনা অনুযায়ী নিতে পারেন"
    ],
    "warning_signs_bn": [
      "শ্বাস নিতে কষ্ট হলে",
      "ঢোক গিলতে না পারলে",
      "জ্বর ১০৩°F এর বেশি হলে"
    ],
    "followup_question_bn": "আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?",
    "disclaimer_bn": "এটি একজন ডাক্তারের পরামর্শের বিকল্প নয়।",
    "emergency_number": null,
    "created_at": "2026-08-05T15:10:22.481Z"
  }
}
```

### UI rules for the mobile app
- `RED` → red banner, big **৯৯৯ কল করুন** button using `emergency_number` (`tel:999`).
- `YELLOW` → amber card + "নিকটস্থ ক্লিনিক দেখুন" → call `/clinics`.
- `GREEN` → green card, home-care advice.
- Always render `disclaimer_bn`.
- Typical latency 2–6s → show a Bangla loading state; use a 30s client timeout.

### curl
```bash
curl -X POST https://project-kitchen-ready.lovable.app/api/public/v1/triage \
  -H "Content-Type: application/json" \
  -d '{"symptoms":"বুকে চাপ ব্যথা আর বাম হাতে ব্যথা"}'
```

---

## 2b. `POST /triage/followup`

Multi-turn follow-up. After `/triage` returns a `followup_question_bn`, send the
patient's answer here together with the conversation so far. The API
re-evaluates the triage level with the full context and returns the next
question (or marks the conversation complete).

The API is *stateless* — the app owns the conversation. Keep the `turns` array
returned by each response and send it back on the next call.

### Request body

| Field | Type | Required | Rules |
|---|---|---|---|
| `initial_symptoms` | string | ✅ | trimmed, 3–2000 chars. The original description sent to `/triage` |
| `answer` | string | ✅ | trimmed, 1–1000 chars. Patient's answer to the last follow-up question |
| `turns` | Turn[] | ❌ | max 20, oldest → newest. From the previous response; omit or `[]` on the first follow-up |
| `session_id` | string | ❌ | 1–100 chars, client-generated (e.g. UUID). Echoed back so you can group turns locally |

`Turn = { "role": "patient" | "assistant", "text": string }` (text 1–1000 chars).

### Response 200

All fields of `/triage` *plus*:

| Field | Type | Notes |
|---|---|---|
| `session_id` | string \| null | Echo of the request value |
| `turn` | integer | Number of turns in the returned `turns` array |
| `turns` | Turn[] | Updated conversation — store and send back next call |
| `is_complete` | boolean | `true` when `followup_question_bn` is `null` |

`level` can change between turns (e.g. YELLOW → RED) — the banner and
`emergency_number` must re-render each time. The flow repeats until
`is_complete === true`.

### curl
```bash
curl -X POST https://project-kitchen-ready.lovable.app/api/public/v1/triage/followup \
  -H "Content-Type: application/json" \
  -d '{"initial_symptoms":"৩ দিন ধরে জ্বর ও গলা ব্যথা","turns":[{"role":"assistant","text":"আপনার কি ঢোক গিলতে কষ্ট হচ্ছে?"}],"answer":"হ্যাঁ, খুব কষ্ট হচ্ছে"}'
```

### Errors
`400 invalid_json` · `422 validation_failed` · `429 rate_limited` · `502 ai_upstream_error` — same handling as `/triage` (Bangla `error.message` surfaces verbatim, 429 → backoff).

Nearby hospitals/clinics from OpenStreetMap, sorted by distance.

### Query parameters

| Param | Type | Required | Rules |
|---|---|---|---|
| `lat` | number | ❌ | -90..90. Required together with `lon` |
| `lon` | number | ❌ | -180..180 |
| `limit` | integer | ❌ | 1..25, default `8` |

If `lat`/`lon` are omitted (GPS denied), the API returns a curated Dhaka hospital list with `source: "fallback"`.

### Response 200

| Field | Type | Notes |
|---|---|---|
| `source` | `"openstreetmap" \| "fallback"` | `fallback` = Dhaka default list |
| `origin` | `{ lat, lon }` | Point distances were measured from |
| `count` | number | Number of items returned |
| `clinics[].id` | string | Stable id (OSM element id) |
| `clinics[].name` | string | Facility name |
| `clinics[].lat` / `lon` | number | Coordinates for map pin / directions |
| `clinics[].distanceKm` | number | Straight-line km from `origin` |
| `clinics[].type` | string \| null | `hospital` \| `clinic` \| `doctors` \| `Government` \| `Private` |
| `clinics[].address` | string \| null | May be missing in OSM data |

```json
{
  "success": true,
  "data": {
    "source": "openstreetmap",
    "origin": { "lat": 23.7806, "lon": 90.4074 },
    "count": 2,
    "clinics": [
      {
        "id": "123456789",
        "name": "Square Hospitals Ltd.",
        "lat": 23.7525,
        "lon": 90.3786,
        "distanceKm": 4.2,
        "type": "hospital",
        "address": "West Panthapath"
      },
      {
        "id": "f1",
        "name": "Dhaka Medical College Hospital",
        "lat": 23.7257,
        "lon": 90.3974,
        "distanceKm": 6.1,
        "type": "Government",
        "address": "Bakshibazar, Dhaka"
      }
    ]
  }
}
```

Directions deep link (build on the client):
`https://www.google.com/maps/dir/?api=1&origin={userLat},{userLon}&destination={clinic.lat},{clinic.lon}`

### curl
```bash
curl "https://project-kitchen-ready.lovable.app/api/public/v1/clinics?lat=23.78&lon=90.40&limit=10"
```

---

## 4. `GET /emergency`

Static Bangladesh emergency/hotline numbers for an in-app emergency sheet. Cache locally for 24h.

**Response 200**
```json
{
  "success": true,
  "data": {
    "country": "BD",
    "contacts": [
      { "label_bn": "জাতীয় ইমার্জেন্সি সার্ভিস", "number": "999", "type": "emergency" },
      { "label_bn": "স্বাস্থ্য বাতায়ন", "number": "16263", "type": "health_hotline" },
      { "label_bn": "কোভিড / IEDCR", "number": "10655", "type": "health_hotline" },
      { "label_bn": "নারী ও শিশু সহায়তা", "number": "109", "type": "support" },
      { "label_bn": "ফায়ার সার্ভিস", "number": "102", "type": "fire" }
    ]
  }
}
```

---

## Client integration notes

- **Voice input** stays fully on-device: use Android `SpeechRecognizer` / iOS `SFSpeechRecognizer` with locale `bn-BD`, then POST the transcript to `/triage`.
- **Text-to-speech** for the result: read `summary_bn` + `advice_bn` with locale `bn-BD`.
- **Fonts:** bundle a Bangla font (e.g. Noto Sans Bengali / Hind Siliguri); do not rely on system fallback.
- **Timeouts:** `/triage` 30s, others 10s.
- **Offline:** cache the last triage result and `/emergency` list locally.
- **Do not send** names, phone numbers, NID or other PII in `symptoms`.

### Dart / Flutter example
```dart
final res = await http.post(
  Uri.parse('https://project-kitchen-ready.lovable.app/api/public/v1/triage'),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
  body: jsonEncode({'symptoms': text}),
);
final body = jsonDecode(utf8.decode(res.bodyBytes));
if (body['success'] == true) {
  final data = body['data'];
  // data['level'], data['advice_bn'], ...
} else {
  showError(body['error']['message']); // already Bangla
}
```

### Kotlin data classes
```kotlin
data class ApiResponse<T>(val success: Boolean, val data: T?, val error: ApiError?)
data class ApiError(val code: String, val message: String)

data class TriageResult(
  val level: String,
  val title_bn: String,
  val summary_bn: String,
  val advice_bn: List<String>,
  val warning_signs_bn: List<String>,
  val followup_question_bn: String?,
  val disclaimer_bn: String,
  val emergency_number: String?,
  val created_at: String,
)
```

### TypeScript types (React Native)
```ts
export type TriageLevel = "GREEN" | "YELLOW" | "RED";

export interface TriageResponse {
  level: TriageLevel;
  title_bn: string;
  summary_bn: string;
  advice_bn: string[];
  warning_signs_bn: string[];
  followup_question_bn: string | null;
  disclaimer_bn: string;
  emergency_number: string | null;
  created_at: string;
}

export interface Clinic {
  id: string;
  name: string;
  lat: number;
  lon: number;
  distanceKm: number;
  type?: string;
  address?: string;
}

export type ApiResponse<T> =
  | { success: true; data: T }
  | { success: false; error: { code: string; message: string; details?: unknown } };
```

---

## Versioning

All paths are prefixed with `/v1`. Breaking changes ship under `/v2`; `/v1` field additions are backwards-compatible, so parse leniently and ignore unknown fields.
