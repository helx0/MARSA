# MARSA — Phase-by-phase implementation ledger

2026-11-19. **Meaning of “source implemented”:** files exist and backend/frontend flows have been written, but no Flutter compilation or Supabase deployment has been verified in this sandbox. This ledger is kept in the archive so later work can resume from files rather than memory.

| PDF phase | Files / actions completed | Local verification | Remaining external acceptance |
|---|---|---|---|
| 0 Scope | README, SRS, assumptions, no sensitive keys | Documentation reviewed | Obtain dedicated Supabase project and Flutter SDK |
| 1 Architecture/scaffold | `lib/`, `pubspec.yaml`, `android/`, theme, routing, localization, config | Source file structural tests | Flutter pub resolution, analyze, Android import |
| 2 Backend | 10 migration files, area/category seed, RLS, secure profile/seller/admin policies | SQL source assertions | Apply migrations, run database RLS tests |
| 3 Marketplace | Catalog, filters/search, details, seller onboarding, listing CRUD, Storage workflows | Dart import checks | Actual UI/device and backend integration |
| 4 Direct orders | Transactional order RPCs, status rules, inventory restore/expiry, checkout UI | SQL source assertions | Live concurrent purchase test |
| 5 Auctions | Transactional bids, schedule/on-demand finalization, auction UI, timeout/winner | Source assertions | Live concurrency/finalization testing |
| 6 Support | Private chat, favorites, reviews, notifications, reporting, admin UI | Source contract checks | Real multi-user RLS and UI tests |
| 7 Polish/QA | Arabic RTL UI, empty/errors, offline read cache, Python+Dart test files | 9 Python source-contract tests | `flutter test`, device RTL/accessibility, comprehensive English translation |
| 8 Package | Source ZIP with docs and setup instructions | `unzip -t` at package time | Cannot claim passing APK build without Flutter/Android SDK |

### Next work when Flutter and Supabase are available

Run the full acceptance commands in `TESTING.md`, fix reported build/static-analysis issues and missing requirements, deploy to a *development* Supabase environment, perform concurrency and permission tests, and only then label the application verified. Preserve this folder structure, tests and migrations for subsequent revisions.


## 2026-11-19 — Phase 2 independent verification (partial; blocked by tools)

- Reopened delivered ZIP and edited the **actual original source** inside a fresh verified workspace.
- Attempted `flutter doctor -v`, `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`, `flutter build apk --debug`: all exit 127 because Flutter/Dart are missing. Java wrapper Gradle download exit 1 (DNS failure).
- Repaired idempotency key collision semantics, late-auction locking/clock races, seller/admin cancellation and edit race, auction-award expiry state race, image metadata insertion race, and offline cached checkout.
- 21/21 **source** contract/regression tests passed. Android/SQL runtime checks NOT RUN. New backend acceptance harness syntax was verified, harness not run.
- Repackaged as new Phase 2 ZIP (source only, no APK). **Next step:** verify on Flutter+Android+Supabase-enabled development machine. Save `pubspec.lock` and logs, and correct any analyzer/build/test failures before claiming completion.
