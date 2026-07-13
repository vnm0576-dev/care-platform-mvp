# Care Platform Flutter app

Executable Flutter foundation for the caregiver/client MVP.

## Current scope

- Android and Web project scaffolding;
- Material 3 application shell;
- safe Supabase initialization through compile-time values;
- registration and sign-in with role-aware routing;
- editable caregiver drafts and moderation submission;
- client caregiver search and care-request fallback;
- administrator moderation queue;
- configuration unit tests and startup widget tests.

## Requirements

- Flutter stable compatible with the SDK constraint in `pubspec.yaml`;
- a Supabase project URL;
- the project's public/publishable anon key.

Never place a Supabase `service_role` key in this application, a local command history shared with others, or the repository.

## Install dependencies

```bash
flutter pub get
```

## Run without Supabase configuration

```bash
flutter run -d chrome
```

The application starts in a safe diagnostic state and explains that configuration is missing.

## Run with Supabase

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

For Android, replace `-d chrome` with the connected device or emulator ID shown by `flutter devices`.

### Transport security

Production configuration accepts only `https://` Supabase URLs. The app rejects `http://` URLs except loopback hosts (`localhost`, `127.0.0.1`, `::1`) intended for local development. Release and profile Android builds explicitly disable cleartext traffic.

The debug Android manifest alone enables cleartext traffic so a local loopback Supabase instance can be tested during development. Android emulators and physical devices do not treat a development machine's `localhost` as their own; use an HTTPS-accessible development endpoint for device testing rather than relaxing the release policy.

Only a Supabase public/publishable key belongs in `SUPABASE_ANON_KEY`. The client rejects modern `sb_secret_` keys and legacy JWTs whose role is `service_role`; this is a guardrail, not a substitute for key rotation if a secret was exposed.

## Verify

```bash
flutter analyze
flutter test
flutter build web
```

A configured build can be produced with the same two `--dart-define` arguments. The values are compile-time inputs; do not commit production values to source files.

## Project structure

```text
lib/
├── core/
│   ├── config/
│   └── theme/
├── features/
│   ├── admin/
│   ├── auth/
│   ├── caregiver/
│   └── client/
├── navigation/
├── app.dart
└── main.dart
```

## Android identity

Temporary application ID:

```text
dev.vnm0576.care_platform_app
```

It can be changed before the first signed release if the final product identity changes.

## Android release signing

Release builds never fall back to the Android debug key. Create a private keystore outside version control and add the ignored file `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/private/path/upload-keystore.jks
```

Then verify the signed bundle:

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Keep the keystore and both passwords in a password manager and a protected backup. Losing the upload key can block future application updates. Neither `key.properties` nor keystore files may be committed.
