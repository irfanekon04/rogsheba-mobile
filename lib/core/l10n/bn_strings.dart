/// All Bangla copy in one module, lifted **verbatim** from the live web app
/// (`project-kitchen-ready.lovable.app`) — never re-translated.
///
/// Bangla-only in v1, so no localisation machinery — plain constants to be
/// referenced across widgets.
abstract final class BnStrings {
  static const appTitle = 'রোগসেবা';

  /// Latin brand word, rendered in the display font next to the Bangla title.
  static const appBrand = 'RogSheba';

  /// Emergency number pill in the app bar (web header `[৯৯৯](tel:999)`).
  static const hotline999 = '৯৯৯';

  // ---- Home hero ----
  static const heroBadge = 'AI ট্রায়াজ • বাংলা ভয়েস • বিনামূল্যে';
  static const heroTitle = 'আপনার লক্ষণ বলুন — তাৎক্ষণিক স্বাস্থ্য পরামর্শ পান';
  static const heroSubtitle =
      'বাংলায় কথা বলে বা লিখে জানান কী হচ্ছে। RogSheba বলে দেবে — '
      'ঘরে যত্ন যথেষ্ট, না কি ডাক্তার দেখানো জরুরি।';

  // ---- Symptom entry ----
  static const symptomPlaceholder =
      'আপনার লক্ষণ বাংলায় লিখুন বা মাইকে কথা বলুন… '
      '(যেমন: গত ৩ দিন ধরে গলা ব্যথা ও জ্বর ১০১°F)';
  static const clearField = 'মুছে ফেলুন';

  // ---- Submit ----
  static const submit = 'পরামর্শ নিন';
  static const submitting = 'বিশ্লেষণ চলছে';
  static const inlineDisclaimer = 'এটি ডাক্তারের পরামর্শের বিকল্প নয়।';

  // ---- Voice input ----
  /// Live indicator shown while the mic is active (web's "শুনছি…").
  static const listeningIndicator = 'শুনছি…';
  static const stopListening = 'শোনা বন্ধ করুন';
  static const voiceUnavailable =
      'ভয়েস সাপোর্ট নেই — টাইপ করুন';
  static const micLabel = 'বাংলায় বলুন';

  // ---- Examples ----
  static const exampleHeader = 'উদাহরণ';
  static const exampleFeverThroat = '৩ দিন ধরে জ্বর ১০২ ও গলা ব্যথা';
  static const exampleChestPain = 'বুকে চাপ ব্যথা, বাম হাতে ব্যথা';
  static const exampleStomach = 'পেট খারাপ ও বমি, ১ দিন ধরে';

  // ---- Feature strip ----
  static const featureTriageTitle = 'AI ট্রায়াজ';
  static const featureTriageBody =
      'সবুজ / হলুদ / লাল — তাৎক্ষণিক জরুরি মূল্যায়ন';
  static const featureClinicsTitle = 'নিকটস্থ ক্লিনিক';
  static const featureClinicsBody = 'GPS দিয়ে ১০ কিমির মধ্যে হাসপাতাল';
  static const featurePrivateTitle = 'প্রাইভেট ও বিনামূল্যে';
  static const featurePrivateBody = 'কোনো রেজিস্ট্রেশন নেই, কোনো ফি নেই';

  // ---- Errors ----
  static const genericError = 'একটি ত্রুটি ঘটেছে।';
  static const networkError =
      'ইন্টারনেট সংযোগ নেই। সংযোগ ঠিক করে আবার চেষ্টা করুন।';
  static const timeoutError =
      'অনুরোধটি সময় শেষ হয়ে গেছে। সংযোগ ঠিক করে আবার চেষ্টা করুন।';

  // ---- Triage result card headings ----
  static const levelGreen = 'সবুজ — ঘরে যত্ন';
  static const levelGreenSub = 'নিম্ন জরুরি';
  static const levelYellow = 'হলুদ — ক্লিনিকে যান';
  static const levelYellowSub = 'মাঝারি জরুরি — ২৪ ঘণ্টার মধ্যে';
  static const levelRed = 'লাল — এখনই হাসপাতালে যান';
  static const levelRedSub = 'জরুরি — দেরি করবেন না';

  static const adviceTitle = 'করণীয়';
  static const warningSignsTitle = 'বিপদ-সংকেত — দেখলে দ্রুত হাসপাতালে যান';
  static const followupPrefix = 'ফলো-আপ: ';
  static const ttsListen = 'বাংলায় শুনুন';
  static const ttsStop = 'শোনা বন্ধ';

  // Spoken-text prefixes, read aloud in the web's order.
  static const ttsAdvicePrefix = 'করণীয়: ';
  static const ttsWarningSignsPrefix = 'বিপদ-সংকেত: ';
  static const redBanner = 'এখনই হাসপাতালে যান বা জরুরি সেবায় কল করুন';
  static const call999 = '৯৯৯ কল';
  static const call16263 = '১৬২৬৩';
  static const nearbyClinicsCta = 'নিকটস্থ ক্লিনিক খুঁজুন';

  // ---- Clinics ----
  static const clinicsTitle = 'নিকটস্থ হাসপাতাল ও ক্লিনিক';
  static const clinicsSubtitle =
      'OpenStreetMap থেকে রিয়েল-টাইম ডেটা — সম্পূর্ণ বিনামূল্যে।';
  static const locating = 'আপনার অবস্থান খুঁজছি…';
  static const clinicsLoading = 'নিকটস্থ ক্লিনিক লোড হচ্ছে…';
  static const directions = 'দিকনির্দেশ';
  static const viewOnMap = 'ম্যাপে দেখুন';
  static const retry = 'আবার চেষ্টা করুন';

  // Bare failure states used by the retry-card inline message.
  static const locationDenied = 'লোকেশন অনুমতি দেওয়া হয়নি।';
  static const locationDisabled = 'লোকেশন সেবা বন্ধ আছে।';
  static const locationFailed = 'লোকেশন পাওয়া যায়নি।';

  // Prose banners rendered above the Dhaka fallback list when location is
  // unavailable — copied verbatim from the web component. The denied and
  // service-down variants differ because the user-facing action differs.
  static const fallbackBannerDenied =
      'লোকেশন অনুমতি দেওয়া হয়নি — ঢাকার বড় হাসপাতালগুলো দেখাচ্ছি।';
  static const fallbackBannerDisabled =
      'লোকেশন সেবা বন্ধ আছে — ঢাকার বড় হাসপাতালগুলো দেখাচ্ছি।';
  static const fallbackBannerFailed =
      'লোকেশন পাওয়া যায়নি — ঢাকার বড় হাসপাতালগুলো দেখাচ্ছি।';

  // Last-resort message when even the fallback API call fails — we have no
  // list at all and no location. Same retry as for any other failure.
  static const fallbackUnavailable =
      'ক্লিনিক তালিকা লোড করা যাচ্ছে না। সংযোগ ঠিক করে আবার চেষ্টা করুন।';

  // ---- Emergency sheet (Issue #10) ----
  /// Sheet header — the same wording the web shows above its hotline list.
  static const emergencySheetTitle = 'জরুরি নম্বর';

  /// Sheet sub-headline encouraging the user to tap to dial.
  static const emergencySheetSubtitle =
      'দ্রুত কল করতে যেকোনো নম্বরে ট্যাপ করুন';

  /// Spinner state inside the sheet.
  static const emergencyLoading = 'জরুরি নম্বর লোড হচ্ছে…';

  /// API failure inside the sheet; retry pill sits below it.
  static const emergencyLoadFailed =
      'জরুরি নম্বর লোড করা যায়নি। আবার চেষ্টা করুন।';

  // ---- Offline (Issue #11) ----
  /// Banner shown while there is no connectivity, so the user understands why
  /// a fresh request will not work. The web has no offline copy — this is
  /// written in the same plain Bangla register as the rest of the app.
  static const offlineBanner =
      'ইন্টারনেট সংযোগ নেই — নতুন অনুরোধ পাঠানো যাবে না।';

  // ---- Accessibility (Issue #12) ----
  /// Screen-reader label for the emergency pill. The visible `৯৯৯` alone is
  /// cryptic when read aloud — say what it is and what it does.
  static const hotlinePillLabel = 'জরুরি নম্বর ৯৯৯ — খুলুন';
}
