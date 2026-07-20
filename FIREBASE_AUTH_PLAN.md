# AXIS Y — خطة البداية مع Firebase (المرحلة الأولى: Auth)

الهدف: نجهّز الكود الأول بحيث يكون "جاهز للتوصيل"، وبعدين نعمل مشروع Firebase ونربط المصادقة (Auth) كأول جزء حقيقي في الباك اند — **من غير ما نكسر قاعدة إن التطبيق يشتغل من غير باك اند**.

> القاعدة الذهبية: أي Cubit أو شاشة **ممنوع** تعرف إن فيه Firebase أصلاً. كل حاجة بتتكلم مع `AuthRepository` بس، وإحنا بنبدّل التنفيذ من ورا الكواليس.

---

## المرحلة 0 — تجهيز الكود الأول (قبل ما نفتح Firebase خالص)

دي أهم مرحلة، وهي اللي بتخلي التبديل بعدين يبقى سطر واحد في الـ DI.

### 0.1 العقد (Interface) — `lib/features/auth/data/auth_repository.dart`

```dart
abstract class AuthRepository {
  /// المستخدم الحالي (null لو مفيش جلسة)
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;

  // تسجيل جديد
  Future<Result<AppUser>> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  });

  // OTP على الموبايل
  Future<Result<OtpSession>> sendOtp(String phoneNumber);
  Future<Result<AppUser>> verifyOtp({
    required OtpSession session,
    required String code,
  });

  // دخول
  Future<Result<AppUser>> loginWithEmail(String email, String password);
  Future<Result<AppUser>> signInWithGoogle();
  Future<Result<AppUser>> signInWithApple(); // iOS فقط

  // كلمة السر
  Future<Result<void>> sendPasswordReset(String emailOrPhone);

  Future<void> signOut();
}
```

### 0.2 الموديلات — `app_user.dart` و `otp_session.dart`

```dart
class AppUser extends Equatable {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? photoUrl;
  const AppUser({required this.id, required this.fullName, this.email, this.phone, this.photoUrl});
}

/// بتشيل الـ verificationId بتاع Firebase من غير ما حد يعرف
class OtpSession {
  final String phoneNumber;
  final String token; // في الـ Mock = "mock"، في Firebase = verificationId
  const OtpSession({required this.phoneNumber, required this.token});
}
```

### 0.3 حالات الـ AuthCubit (زي ما هي — مش هتتغير أبدًا)

`AuthInitial / AuthLoading / AuthOtpSent(session) / AuthAuthenticated(user) / AuthError(messageAr)`

### 0.4 تنفيذين للعقد

- `MockAuthRepository` — الموجود دلوقتي: أي بيانات تنجح، الكود `123456`، الجلسة في shared_preferences.
- `FirebaseAuthRepository` — هننفذه في المرحلة 3.

### 0.5 الـ DI — `core/di/injector.dart`

```dart
abstract class AppConfig {
  static const bool useMockData = true;     // باقي التطبيق (منتجات، طلبات...)
  static const bool useFirebaseAuth = false; // ← ده مفتاح المرحلة دي لوحده
}

getIt.registerLazySingleton<AuthRepository>(
  () => AppConfig.useFirebaseAuth
      ? FirebaseAuthRepository(FirebaseAuth.instance)
      : MockAuthRepository(prefs),
);
```

> عملنا مفتاح منفصل للـ Auth عشان نقدر نشغّل Auth حقيقي والمنتجات لسه Mock — وده بالظبط وضعنا الجاي.

### ✅ معيار إنهاء المرحلة 0
كل شاشات الدخول شغالة بالـ Mock، ومفيش أي `import firebase` في أي Cubit أو View.

---

## المرحلة 1 — إنشاء مشروع Firebase وربطه بالتطبيق

1. من [console.firebase.google.com](https://console.firebase.google.com): **Add project** باسم `axis-y` (سيبك من Google Analytics دلوقتي أو فعّله عادي).
2. ثبّت الأدوات مرة واحدة:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. من جوه فولدر المشروع:
   ```bash
   flutterfire configure
   ```
   - اختار المشروع `axis-y`، والمنصتين Android + iOS.
   - هيضيف تطبيق Android بالـ package name (مثلاً `com.axisy.app` — ثبّته قبلها في `build.gradle` لأن تغييره بعدين وجع دماغ)، وتطبيق iOS بالـ Bundle ID.
   - هيولّد `lib/firebase_options.dart` لوحده.
4. أضف الباكدجات:
   ```bash
   flutter pub add firebase_core firebase_auth google_sign_in sign_in_with_apple
   ```
5. في `main.dart`:
   ```dart
   WidgetsFlutterBinding.ensureInitialized();
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   runApp(const AxisYApp());
   ```
   > `initializeApp` محلي وسريع ومش بيستنى إنترنت — قاعدة "التطبيق مش بيستنى الباك اند" لسه محترمة. التصفح كله شغال Mock حتى من غير نت؛ الحاجة الوحيدة اللي محتاجة نت هي عملية الدخول نفسها، وده منطقي.
6. **Android مهم:** أضف بصمات SHA-1 و SHA-256 في إعدادات التطبيق في الـ Console (جِبهم بـ `cd android && ./gradlew signingReport`) — من غيرهم Google Sign-In والـ OTP مش هيشتغلوا.

---

## المرحلة 2 — تفعيل طرق الدخول في Firebase Console

من **Build → Authentication → Sign-in method** فعّل بالترتيب ده:

| الطريقة | ملاحظات |
|---|---|
| **Email/Password** | تفعيل مباشر — دي أسهل واحدة نبدأ بيها ونختبر بيها الربط كله |
| **Phone (OTP)** | ضيف **أرقام تجريبية** (Phone numbers for testing) زي `+201000000001` بكود `123456` عشان تطور من غير رسايل حقيقية. الرسايل الحقيقية غالبًا هتحتاج تفعيل خطة **Blaze** (الدفع بالاستخدام) — اتأكد من ده في الـ Console لأن سياسة الـ SMS بتتحدث باستمرار. على Android هتحتاج كمان تفعيل Play Integrity / reCAPTCHA fallback |
| **Google** | فعّله وحدد Support email. على iOS ضيف الـ REVERSED_CLIENT_ID في الـ URL Schemes |
| **Apple** | iOS فقط — محتاج حساب Apple Developer مفعّل فيه Sign in with Apple capability. **إجباري في App Store** طالما فيه دخول بجوجل، فمتتخطاهوش |

---

## المرحلة 3 — تنفيذ `FirebaseAuthRepository`

ملف واحد جديد، مفيش أي تعديل على الشاشات:

- `registerWithEmail` → `createUserWithEmailAndPassword` + `updateDisplayName`.
- `loginWithEmail` → `signInWithEmailAndPassword`.
- `sendOtp` → `verifyPhoneNumber` (الرقم بصيغة دولية `+20...`)، خزّن `verificationId` جوه `OtpSession.token`.
- `verifyOtp` → `PhoneAuthProvider.credential(verificationId, smsCode)` ثم `signInWithCredential`.
- `signInWithGoogle` → `GoogleSignIn.authenticate()` ثم `signInWithCredential`.
- `sendPasswordReset` → `sendPasswordResetEmail`.
- `authStateChanges` → `FirebaseAuth.instance.authStateChanges().map(_toAppUser)` — وده بيحل حفظ الجلسة تلقائيًا (Firebase بيخزنها لوحده، مش محتاجين shared_preferences هنا).
- **ترجمة الأخطاء لعربي** في mapper واحد:

```dart
String mapAuthError(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' || 'wrong-password' || 'user-not-found'
      => 'البيانات غلط — اتأكد من الإيميل وكلمة السر',
  'email-already-in-use' => 'الحساب ده مسجل قبل كده — جرب تسجل دخول',
  'weak-password' => 'كلمة السر ضعيفة — لازم ٨ أحرف على الأقل',
  'invalid-verification-code' => 'الكود غلط — اتأكد من الرسالة وحاول تاني',
  'too-many-requests' => 'محاولات كتير — استنى شوية وجرب تاني',
  'network-request-failed' => 'مفيش إنترنت — اتأكد من الاتصال',
  _ => 'حصلت مشكلة، حاول تاني',
};
```

بعدين قلب المفتاح: `useFirebaseAuth = true`.

---

## المرحلة 4 — بيانات المستخدم الإضافية (بعد نجاح الدخول)

Firebase Auth بيخزن الهوية بس. الاسم الكامل والمقاسات والتفضيلات محتاجين مكان:

- **الاختيار المؤقت (دلوقتي):** فضّل كل ده محلي زي ما هو (shared_preferences/hive) — Auth حقيقي + بيانات محلية = كفاية تمامًا للمرحلة دي.
- **الخطوة الجاية (قرار لاحق):** لو مشينا مع Firestore نعمل collection باسم `users/{uid}` فيها: fullName, phone, stylePreferences, measurements (أرقام بس — **ممنوع صور المسح طبقًا للمواصفات**). ولو الباك اند هيبقى Custom API نبعتلها هناك. **مش لازم نقرر النهارده** — الـ `UserProfileRepository` هيبقى interface برضه.

---

## المرحلة 5 — الاختبار والقبول

- [ ] تسجيل جديد بإيميل → الحساب بيظهر في Firebase Console → Users
- [ ] دخول/خروج والجلسة بتثبت بعد قفل التطبيق وفتحه (Splash بيوجه صح)
- [ ] OTP برقم تجريبي `+201000000001` / كود `123456` بيدخل
- [ ] كود غلط → رسالة عربي مظبوطة مش crash
- [ ] Google Sign-In شغال على Android (بعد إضافة SHA) وعلى iOS
- [ ] قفل النت وجرب تسجيل دخول → رسالة "مفيش إنترنت" والتطبيق نفسه لسه بيتصفح Mock عادي
- [ ] `useFirebaseAuth = false` يرجّع كل حاجة Mock تاني بسطر واحد (اختبار إن العزل سليم)

---

## الترتيب التنفيذي المختصر

| # | الخطوة | المكان |
|---|---|---|
| 1 | بناء interface + Mock + Cubit + شاشات Auth | الكود |
| 2 | إنشاء مشروع axis-y + `flutterfire configure` + الباكدجات | Console + الكود |
| 3 | تفعيل Email ثم Phone (بأرقام تجريبية) ثم Google ثم Apple | Console |
| 4 | كتابة `FirebaseAuthRepository` + mapper الأخطاء | الكود |
| 5 | قلب مفتاح `useFirebaseAuth` والاختبار بالتشيك ليست | الكود |

اللي **مش** هنعمله دلوقتي عمدًا: Firestore للمنتجات، الإشعارات (FCM)، التحليلات، الدفع — كل دول مراحل لاحقة ليهم خطط منفصلة، والأهم إن مفتاح كل واحدة فيهم هيبقى نفس فكرة الـ Repository swap دي.
