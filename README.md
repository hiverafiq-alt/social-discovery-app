# Social Discovery App

A Flutter social-discovery development preview: fictional profiles, discovery filters, invitations, consent-gated conversations and sample requests.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/hiverafiq-alt/social-discovery-app)

One click opens a workspace and installs the pinned Flutter SDK. No real user accounts, API credentials or payment integration are configured. Source is recovered from the browser preview of an earlier development build, generalized and renamed. This repository is **not** the full native/backend deployment package and does not claim App Store or production readiness.

## Run locally

Install Flutter 3.35.7, then run:

```sh
flutter pub get --enforce-lockfile
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8080 --dart-define=DEMO_MODE=true --dart-define=WEB_PREVIEW=true
```

Build: `flutter build web --release --no-web-resources-cdn --dart-define=DEMO_MODE=true --dart-define=WEB_PREVIEW=true`.

The browser preview uses fictional, memory-only profiles and sample requests. Camera recording/upload and native telemetry are intentionally disabled in preview. No money moves. The source includes a Supabase repository interface, but production schemas, server functions, native platform projects, signing and live services are not supplied here. Do not turn on a production backend without implementing and auditing its authorization and privacy controls.

## Tests

```sh
flutter analyze
flutter test test/domain_test.dart test/redaction_test.dart
flutter test test/web_preview_test.dart --dart-define=DEMO_MODE=true --dart-define=WEB_PREVIEW=true
```

Tests cover invitation expiry, terminal states, recipient decisions, chat acceptance, blocking, idempotent invitations, age boundaries, redaction and browser flows. The native widget test needs demo mode without browser preview: `flutter test test/widget_test.dart --dart-define=DEMO_MODE=true`.

Read MASTER_PROMPT.md and DEVELOPMENT_NOTES.md before adapting the app. The Inter font license is preserved in assets/fonts/OFL_Inter.txt; other dependencies retain their own licenses.
