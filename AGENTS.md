# Repository Guidelines

## Project Structure & Modules
- Flutter app entry at `lib/main.dart`; routing/theme/helpers in `lib/core/` (router, theme, env utils).
- Data layer lives in `lib/data/` (Supabase and IGDB clients); domain models in `lib/models/`.
- Feature-first UI/state under `lib/features/<area>/` with paired screens and controllers (Riverpod).
- Platform scaffolding resides in `android/`, `ios/`, `macos/`, `linux/`, `windows/`, and `web/`; add assets/config there as needed.
- Tests belong in `test/`, mirroring `lib/` paths with `*_test.dart` files; keep fixtures next to the test or under `test/helpers/`.
- Environment secrets are loaded from `.env` (declared in `pubspec.yaml` assets); do not commit real keys.

## Build, Test, and Development Commands
- `flutter pub get` — install/update Dart dependencies.
- `flutter analyze` — static analysis using `analysis_options.yaml` (Flutter lints).
- `flutter test` — run the Dart/Flutter test suite headless.
- `flutter run -d <device>` — launch the app locally (emulator, simulator, or browser if targeting web).
- `flutter build apk` / `flutter build ios` — production builds; add signing configs per platform first.

## Coding Style & Naming Conventions
- Dart 3.10+ with the `flutter_lints` ruleset; prefer `dart format lib test` to auto-format (2-space indent).
- Files use `snake_case.dart`; classes/types use `PascalCase`; variables/functions use `camelCase`.
- Riverpod: providers end with `Provider`, controllers extend `StateNotifier` and sit beside their screens.
- Favor small widgets with clear responsibilities; keep them stateless where possible.
- Use trailing commas in widget trees to keep formatter-friendly diffs.

## Testing Guidelines
- Add unit/widget tests in `test/` mirroring feature paths (e.g., `test/features/search/search_controller_test.dart`).
- Name tests with the behavior under test (e.g., `'signIn sets loading then success'`).
- Mock Supabase/HTTP where possible; isolate UI tests from network by injecting fake providers.
- Aim to cover new controllers and widgets that contain branching logic; verify auth flows and search/library behaviors.

## Commit & Pull Request Guidelines
- Existing history is minimal; prefer clear Conventional Commit-style messages (`feat: add search pagination`) for readability.
- PRs should include: purpose summary, linked issue (if any), screenshots/gifs for UI changes, and a short test plan (`flutter analyze`, `flutter test`, or `flutter run` device).
- Keep changes scoped; separate refactors from feature work when feasible.

## Configuration & Security Notes
- Required env keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `IGDB_CLIENT_ID`, `IGDB_ACCESS_TOKEN`. Provide safe defaults for local dev; never commit real credentials.
- When debugging auth, remember `AuthGate` in `lib/core/router.dart` controls the signed-in shell; ensure sessions are initialized before navigation tests.
