# AXIS Y — Flutter App Master Prompt
### (Backend-Independent MVP • MVVM Architecture • Cubit State Management)

---

## 1. ROLE & MISSION

You are a senior Flutter engineer. Build **AXIS Y**, an Egyptian mobile app for virtual clothing try-on. Users scan their body with the camera, AI builds an accurate 3D model, and they try clothes virtually before buying from Egyptian stores.

**Two user types:**
- **B2C shopper** — tries on and buys clothes (this is the mobile MVP focus)
- **B2B store/brand** — lists and sells products (dashboard is web/separate; only store *registration entry point* may appear in-app)

**Platforms:** iOS + Android. Everything must work correctly on both.

---

## 2. NON-NEGOTIABLE RULE #1 — THE APP NEVER WAITS FOR A BACKEND

The backend does not exist yet. The app must be **fully runnable, navigable, and demo-able today** using a local mock data layer.

- **NO** HTTP calls at startup. **NO** blocking loaders waiting on a server.
- Every feature reads from **mock repositories** that return realistic local data (Egyptian stores, products in EGP, Arabic names).
- Mock repositories simulate latency with `Future.delayed(300–800ms)` so loading/error states are real and testable.
- All repositories are **abstract interfaces**. Mock implementations (`MockProductRepository`, etc.) are injected today; real API implementations (`ApiProductRepository` using dio) will be swapped in later **without touching a single Cubit or View**.
- A single flag controls the source:

```dart
abstract class AppConfig {
  static const bool useMockData = true; // flip to false when backend is ready
}
```

- Dependency injection via `get_it`: register mock or real repository based on the flag.
- Auth, cart, wishlist, measurements, points, and orders persist locally (shared_preferences / hive) so state survives app restarts even with no server.

---

## 3. NON-NEGOTIABLE RULE #2 — ARCHITECTURE: MVVM + CUBIT

Use **MVVM** where the **Cubit is the ViewModel**. State management is **Cubit only** (`flutter_bloc`) — no Bloc events, no Provider, no Riverpod, no GetX, no setState for business logic.

### Layers (strict, one-way dependencies)

```
View (Screen/Widgets)  →  ViewModel (Cubit + State)  →  Repository (abstract)  →  DataSource (Mock now / Remote later)
                                                     →  Models (entities)
```

- **View:** dumb widgets. Renders state, forwards user actions to the Cubit. Zero business logic.
- **ViewModel (Cubit):** all logic, validation, orchestration. Emits immutable state classes. Never imports Flutter UI (`material.dart`) — pure Dart where possible.
- **State:** sealed/immutable classes with `Equatable`: `XInitial / XLoading / XLoaded(data) / XError(message)`.
- **Repository:** abstract contract per feature. Returns `Result<T>` (success/failure wrapper) — never throws raw exceptions to Cubits.
- **DataSource:** `MockXDataSource` (local JSON/Dart lists) today, `RemoteXDataSource` (dio) later.

### Folder structure (feature-first)

```
lib/
├── main.dart
├── app.dart                        # MaterialApp.router, theme, locale
├── core/
│   ├── config/app_config.dart      # useMockData flag, constants
│   ├── di/injector.dart            # get_it setup
│   ├── router/app_router.dart      # go_router: all routes + auth/onboarding redirects
│   ├── theme/                      # colors (navy #1B2A4A primary), text styles, dark-ready
│   ├── localization/               # ar (default) + en
│   ├── utils/result.dart           # Result<T> = Success<T> | Failure(message)
│   └── widgets/                    # shared: buttons, product card, rating stars, shimmer, empty/error views
└── features/
    ├── splash/            (view / cubit)
    ├── onboarding/        (view / cubit)
    ├── auth/              (view / cubit / data / models)
    ├── body_scan/         (view / cubit / data / models)
    ├── style_preferences/ (view / cubit / data)
    ├── home/              (view / cubit / data / models)
    ├── search/            (view / cubit / data)
    ├── product_details/   (view / cubit / data / models)
    ├── virtual_try_on/    (view / cubit / data)
    ├── style_assistant/   (view / cubit / data)
    ├── compare/           (view / cubit)
    ├── cart_checkout/     (view / cubit / data / models)
    ├── orders/            (view / cubit / data / models)
    ├── wishlist/          (view / cubit / data)
    ├── loyalty/           (view / cubit / data)
    ├── profile_settings/  (view / cubit / data)
    └── notifications/     (view / cubit / data)
```

### Packages

`flutter_bloc`, `equatable`, `get_it`, `go_router`, `shared_preferences` (or `hive`), `cached_network_image`, `shimmer`, `intl` + `flutter_localizations` (or `easy_localization`), `dio` (added later, interface-ready now).

---

## 4. NON-NEGOTIABLE RULE #3 — RTL ARABIC FIRST

- App language: **Arabic (Egyptian tone) is primary**, English secondary. Full RTL on every screen, every button, every text.
- Use `Directionality`-aware layouts; never hardcode left/right — use `start/end`.
- All UI strings in localization files from day one (no hardcoded strings in widgets).
- Currency: EGP (ج.م). Numerals per locale.

---

## 5. FEATURES TO BUILD (from the product spec)

### F1 — Splash & Entry
- Navy background (#1B2A4A brand), AXIS Y logo centered, exactly ~2s, then auto-route:
  logged-in → Home | not logged-in → Onboarding.
- No network on splash. Session read from local storage only.

### F2 — Onboarding (3 slides, visual, minimal text)
1. "جرب قبل ما تشتري" — girl seeing clothes on phone
2. "مسح الجسم بالكاميرا" — camera + body icon
3. "تسوق من أفضل المتاجر" — multiple stores icon
- Dots indicator (1/3), "التالي" button, "تخطي" top-corner → Register screen directly.

### F3 — Auth (Register / Login)
- Register: full name, phone or email, password (min 8 chars) → OTP screen (mock accepts `123456`) → account created.
- Login: phone/email + password + "دخول".
- "نسيت كلمة السر" → mock OTP reset flow.
- Social buttons UI: "ادخل بجوجل" + "ادخل بأبل" (iOS only) — stub actions behind interface for later.
- Mock auth: any credentials pass; session saved locally.

### F4 — Body Scan (first time after register)
- Explainer mini-screen: "هنحتاج صورتين بسيطتين عشان نعرف مقاساتك" + illustration.
- Camera permission request with rationale if refused.
- Camera overlay screen with guide lines + "قف هنا".
- Capture front photo (standing, arms slightly apart) + side photo.
- Mock AI analysis: loading spinner 2–3s → returns measurements (height, weight approx, chest / waist / hips).
- Result screen → "تأكيد وحفظ" → measurements stored locally.
- **Privacy rule: photos are deleted immediately after analysis — only numeric measurements are stored. Never persist the images.**
- Scan can be re-run later from Profile ("تحديث المسح").

### F5 — Style Preferences (after scan)
4 quick questions (chips): favorite colors (زاهية/هادية/الاتنين), style (كاجوال/رسمي/رياضي/موضة), shops most (توبات/بناطيل/فساتين/جاكيتات/كل حاجة), frequency (يومي/أسبوعي/شهري/مناسبات). → "ابدأ التسوق" → Home.

### F6 — Home
- **Top bar:** AXIS Y logo (taps → home), search icon, notifications bell with red dot when unread.
- **Banner slider:** auto-advance every 5s, swipeable, dots, tap → offer/product page.
- **"اخترنالك" personalized row:** horizontal product cards filtered by user's measurements (only fitting sizes), preferences, and browsing. Card = image, product name, store name, price, heart button.
- **Categories row (circular icons):** توبات 👕، بناطيل 👖، فساتين 👗، جاكيتات 🧥، الجديد ✨، الأكثر مبيعًا 🔥.
- **"متاجر مختارة" featured stores row:** logo, name, product count, star rating → store page.
- **Bottom navigation (5 tabs, persistent on all screens):** الرئيسية 🏠 | استكشاف 🔍 | جرب ✨ | المفضلة ❤️ | حسابي 👤.

### F7 — Search & Explore
- Search bar always on top, placeholder "ابحث عن ملابس، متاجر، براندات…", live suggestions while typing, X to clear.
- Filters: type (توبات/بناطيل/فساتين/جاكيتات/الكل), price ranges (<200 / 200–500 / 500–1000 / >1000 ج), store, rating (3+/4+ stars), available-for-try-on (نعم/لا).
- Results: 2-column grid, "تم إيجاد N منتج" header, default sort = best fit for the user's measurements.
- Empty state: "مفيش نتائج" + suggestion to widen search or change filters.

### F8 — Product Details
- Image slider (swipeable, dots), heart button top corner.
- Name (large bold), store name (tap → store page), rating ★★★★☆ (123 تقييم), price (old price struck + red new price if discounted), short description (material, wash care).
- **Colors:** small color circles — tapping changes product image.
- **Sizes:** XS–XXL; the size matching user's scan is pre-highlighted in blue; unavailable sizes grey/struck. If the user picks a different size than recommended → warning: "المقاس ده ممكن ما يناسبكش — حجمك المقاس M".
- **Big navy CTA: "جرب عليك ✨"** → opens 3D try-on.
- Action buttons: أضف للسلة 🛒 (navy primary) | احجز في المتجر 📍 (white, navy border) | شارك (light grey).
- "قد يعجبك أيضًا" similar-products row.
- Reviews: stars + text, user + date, "مفيد" button, "اكتب تقييمك" only if purchased.
- "أضف للمقارنة" (see F11).

### F9 — 3D Virtual Try-On (THE HEART OF THE APP)
- Must open in **< 3 seconds on a mid-range phone**.
- Shows user's 3D body model (from measurements) wearing the selected product realistically. Model fills ~70% of screen.
- Gestures: drag L/R = 360° rotate, pinch = zoom.
- Color circles at bottom — changes apply to the model instantly.
- "مقارنة المقاسات" button → bottom-sheet table: measurement | product size | your size | verdict (✔ مناسب / ⚠ ضيق قليلا) for chest/waist/hips/height.
- Camera icon → saves screenshot to gallery.
- Fixed bottom "أضف للسلة" — buy without going back. Back arrow top → product page.
- **MVP implementation:** build the screen + Cubit + full interaction contract now with a placeholder 3D viewer (rotating mock mannequin/asset or `model_viewer_plus` with a bundled .glb). The real AI engine plugs in later behind `TryOnRepository`.

### F10 — AI Style Assistant ("المساعد الذكي للستايل")
- Entry points: bottom-nav ✨, product page "ايه اللي يتنسق معاه؟", home card "اقتراح اليوم".
- "ماذا أرتدي؟": user picks occasion (يوم عمل، خروج مع صحاب، حفلة، رياضة، رمضان) → full outfit suggestion (mock rules over catalog), each item with image + "جرب عليك", total outfit price, "أضف الكل للسلة".
- "نسّق مع ملابسي": "صور قطعة من ملابسك" → camera/gallery → mock analysis → 3–5 matching catalog suggestions.

### F11 — Compare Products
- "أضف للمقارنة" on any product page, up to 3 products, bottom bar shows selection, "قارن" opens comparison table: image, price, store, rating, material, fits-your-size (✔/⚠), delivery cost. "اشتري" button under each column.

### F12 — Cart & Checkout
- Cart: each item = image, name, store, chosen color+size, price, qty +/-, delete 🗑. Footer summary: items count, subtotal, delivery fee, total + big "إتمام الشراء".
- Checkout step 1 — address: saved address editable, or first-time form (محافظة/منطقة/شارع/رقم البيت/الدور/الشقة), "أضف عنوان جديد".
- Checkout step 2 — payment methods (mock success screens for all): فوري Fawry (code within 24h) | Paymob cards (Visa/Mastercard/installments) | InstaPay | الدفع عند الاستلام (certain areas).
- Checkout step 3 — review: all items + address + method, promo-code field, "اتأكد وادفع" → success screen with order number + delivery estimate.

### F13 — Orders ("طلباتي")
- Statuses: تم الاستلام ✔ | جاري التجهيز 🔄 | في الطريق 🚚 | تم التوصيل ✔ | ملغي ✖.
- Each order: number + date, product thumbnails, "تتبع الطلب" (map placeholder), "إرجاع" if delivered wrong.

### F14 — Wishlist (المفضلة)
- Grid of hearted products: image + name + price + direct "أضف للسلة". Notification if price drops or product runs out (mock). Remove button per card. "شارك قائمتي".

### F15 — Loyalty & Points
- Earning: first purchase 200 | each 100 EGP 10 | review 50 | invite friend 150 | complete body profile 100 | daily login 5.
- Redeem: 100 pts = 10 EGP discount, usable at checkout.
- Tiers: عادي 🔵 (day 1) | فضي ⭐ 1000 (2x event points) | ذهبي ⭐⭐ 5000 (free delivery + exclusive discounts) | بلاتيني 👑 15000 (priority support + early offers).

### F16 — Profile & Settings
- Profile: avatar (camera/gallery), basic info + "تعديل", points + tier, saved measurements + "تحديث المسح", saved addresses, quick links: طلباتي / المفضلة.
- Settings: language (ar/en), per-type notification toggles, privacy (profile visibility / data policy), change password (OTP), delete account (double confirm), support (chat أو واتساب).

### F17 — Notifications
- In-app list + local push mocks: order status, personal offers, wishlist price drop, cart reminder (24h), points earned, new store nearby.

### F18 — Store portal (B2B) — OUT OF MOBILE MVP
- Only a "سجل متجرك" entry link/screen with a registration form stub (store name, product type, commercial registry no., contact) → "تم إرسال طلبك للمراجعة". The full dashboard is web-based, not in this app.

---

## 6. MOCK DATA REQUIREMENTS

Create `assets/mock/` JSON (or Dart seed files) with realistic Egyptian content:
- **≥ 30 products** across توبات/بناطيل/فساتين/جاكيتات: Arabic names, EGP prices (some discounted), 2–4 images each (placeholder network or bundled assets), colors, sizes XS–XXL with per-size measurements (chest/waist/length), material, ratings, review lists, try-on availability flag.
- **≥ 6 stores:** logo, Arabic name, product count, rating.
- **≥ 4 banners**, notification samples, 2–3 sample orders in different statuses, outfit rules for the style assistant.
- One mock user with measurements (e.g., chest 92 / waist 78 / hips 100 / height 172) driving size recommendations everywhere.

---

## 7. QUALITY BARS

- **Performance first:** most users have mid-range phones. Const constructors, cached images, shimmer skeletons instead of blocking spinners, lazy lists. Try-on screen < 3s.
- **Offline-tolerant:** core browsing works with no connection (mock/local data), graceful error + retry widgets.
- **Security-ready:** auth behind interfaces so HTTPS + OAuth2 + encrypted storage slot in later; never log sensitive data.
- **Every Cubit unit-testable:** no BuildContext inside Cubits; repositories injected via constructor.
- **Definition of done per feature:** View + Cubit + states + mock repo + navigation wired + Arabic RTL verified + empty/loading/error states handled.

## 8. BUILD ORDER (phases)

1. **Core skeleton:** theme, router, DI, localization, Result, shared widgets, bottom nav shell.
2. **Flow A:** Splash → Onboarding → Auth (mock) → Body Scan (mock) → Preferences → Home.
3. **Flow B:** Home → Search → Product Details → Try-On (placeholder 3D) → Cart → Checkout (mock pay) → Orders.
4. **Flow C:** Wishlist, Compare, Style Assistant, Loyalty, Notifications, Profile/Settings.
5. **Polish:** shimmer, animations, English locale, tests for critical Cubits.

Start with Phase 1 and produce complete, compiling code for each phase before moving to the next.
