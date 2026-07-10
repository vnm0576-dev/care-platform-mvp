# Care Platform Flutter app

Executable Flutter foundation for the caregiver/client MVP.

## Current scope

- Android and Web project scaffolding;
- Material 3 application shell;
- safe Supabase initialization through compile-time values;
- welcome screen and placeholder authentication routes;
- feature folders for auth, caregiver and client flows;
- configuration unit tests and startup widget tests.

Authentication forms and business workflows are intentionally scheduled for later issues.

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
