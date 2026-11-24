# MARSA Phase 2 — Actual test execution and evidence

**Verified on 2026-11-19.** The environment has **Java 21.0.12.1**, Python 3, PyYAML and Pygments; it does **not** have Flutter, Dart, Android SDK/emulator, PostgreSQL, Supabase CLI or Docker. DNS resolution of Flutter/Gradle package hosts fails. The commands below were attempted where possible. A source-level test passing cannot verify application behavior, SQL correctness, RLS, Android layout or race safety.

| Test | Command | Result | Evidence | Remaining issues |
|---|---|---|---|---|
| Flutter environment | `flutter doctor -v` | **BLOCKED** exit 127 | `verification/evidence/flutter_doctor__v.log` | Flutter SDK absent; version unavailable |
| Dependency resolution | `flutter pub get` | **BLOCKED** exit 127 | `verification/evidence/flutter_pub_get.log` | No SDK/network, no `pubspec.lock` |
| Dart formatter | `dart format .` | **BLOCKED** exit 127 | `verification/evidence/dart_format__.log` | Dart SDK absent; file formatting not verified |
| Flutter analyzer | `flutter analyze` | **BLOCKED** exit 127 | `verification/evidence/flutter_analyze.log` | No type/API checks |
| Flutter tests | `flutter test` | **BLOCKED** exit 127 | `verification/evidence/flutter_test.log` | Widget/unit tests not executed |
| Debug APK build | `flutter build apk --debug` | **BLOCKED** exit 127 | `verification/evidence/flutter_build_apk___debug.log` | No APK produced |
| Gradle wrapper bootstrap | `cd android && ./gradlew --version` | **FAILED** exit 1 | `verification/evidence/gradle_wrapper_attempt.log` | `UnknownHostException: services.gradle.org` |
| Java wrapper source | `javac -d <temp> android/gradle/wrapper/java/org/gradle/wrapper/GradleWrapperMain.java` | **PASS** exit 0 | `verification/evidence/gradle_java_compile.log` | Not a Gradle or Android build |
| Offline source contracts | `python -m unittest discover -s tests -p 'test_*.py' -v` | **PASS** 21/21 | `verification/evidence/python_source_contracts.log` | Static guards only: no backend execution |
| Offline structural checks | `python verification/offline_checks.py` | **PASS** five checks | `verification/evidence/offline_checks.log` | YAML/XML/TOML + lexical Dart/SQL delimiters only |
| Python test harness syntax | `python -m py_compile tests/*.py` | **PASS** | `verification/evidence/python_compile.log` | Harness not run against Supabase |
| Supabase startup/migrations | `supabase start`, `supabase db reset`, `psql` | **NOT RUN** | `verification/evidence/tool_availability.log` | No CLI, PostgreSQL or Docker; no credentials |
| Auth / buyer / seller / admin / RLS | Live Supabase REST/RPC checks | **NOT RUN** | `tests/backend_acceptance.py` | Staging accounts and project required |
| Direct order / image / stock races | Live Supabase REST/RPC checks | **NOT RUN** | `tests/backend_concurrency.py`, `tests/backend_acceptance.py` | Staging seller/listing/Storage required |
| Auction eligibility/concurrency/reserve/expiry | Live Supabase REST/RPC checks | **NOT RUN** | `tests/backend_concurrency.py`, `tests/backend_acceptance.py` | PostgreSQL + two buyers + fixture auctions required |
| Android RTL/LTR/device UX | `flutter test integration_test/launch_test.dart` + device manual checks | **NOT RUN** | `integration_test/launch_test.dart` | No Android SDK, emulator, screenshots or real UI render |
| APK installation on Android | `adb install <apk>` | **NOT RUN** | `verification/evidence/tool_availability.log` | No APK and no Android device tooling |

## Changed source due to offline defect review

- `supabase/migrations/202611190002_operations.sql`: reject reused order keys with different request parameters, reject reused bid keys with different auction/amount, use `clock_timestamp()` after auction lock, serialize seller/admin auction cancellation with a concurrent bid, protect award expiry from overwriting accepted orders, and use post-lock time in finalization.
- `supabase/migrations/202611190003_guards.sql`: serialize direct auction listing updates with concurrent bid locks, including critical-field changes.
- `supabase/migrations/202611190006_media_guard.sql`: serialize image metadata limit checks; assert ownership before locking.
- `lib/features/orders/presentation/order_screens.dart`: do not offer checkout when the displayed listing is cached offline or inactive.
- `integration_test/launch_test.dart`: fail on missing staging configuration rather than silently returning before assertions.
- `tests/test_phase2_regressions.py`: **source-text** checks for the above invariants; not a replacement for concurrency tests.
- `tests/backend_acceptance.py`: an **unexecuted** staging-only acceptance harness for login, RLS/admin, unapproved seller, image upload, forbidden/expired bids, reserve and repeat-finalization.


---

# MARSA QA and execution record

## Test status at packaging

| Check | Status in delivery sandbox | Reason |
|---|---|---|
| Source file/XML/structural contract tests (`python -m unittest`) | Run locally, result in delivery report | Standard-library Python available |
| Java bootstrap wrapper `javac` / JAR creation | Executed successfully | JDK 21 available |
| ZIP completeness/integrity (`unzip -t`) | Run locally, result in delivery report | ZIP utilities available |
| `dart format` | **Not run** | Dart SDK not installed |
| `flutter analyze` | **Not run** | Flutter SDK not installed |
| `flutter test` | **Not run** | Flutter SDK not installed |
| `flutter build apk --debug` | **Not run** | Flutter and Android SDK missing |
| Android Studio project import | **Not verified** | Android Studio not installed |
| PostgreSQL migrations applied | **Not run** | No Supabase project, database or psql client |
| RLS and RPC SQL integration tests | **Not run** | No database/auth test users |
| Bidding/stock race tests | **Not run** | Need two dev buyer accounts, approved seller, live test listings and backend |
| Real Android RTL/accessibility/device testing | **Not run** | No emulator / Android SDK |

## Developer machine test sequence

```bash
# Run from project root; install Flutter stable + Android SDK first.
flutter doctor -v
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
flutter test integration_test/launch_test.dart --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

The static Dart tests exercise auction display calculation, locale lookup, theme color and missing backend configuration. These are **not** substitutes for backend authority tests. No `pubspec.lock` is delivered because `flutter pub get` could not be executed. The lockfile must be generated and committed after environment setup and dependency verification.

## Database verification

Apply versioned migrations and seed in order (`README.md`). Run `supabase/tests/001_schema_assertions.sql` against your **development** database using Supabase SQL Editor or `psql`. Validate manual roles: guest cannot see drafts/private chat; buyer cannot see another buyer's orders or private profile; seller cannot create listings without approval; a non-admin cannot call admin functions; only buyer of completed order may review once.

## Race and security test harness

`tests/backend_concurrency.py` provides **live** REST API tests, using only standard Python libraries. It requires a populated **development** Supabase project, two distinct **real** email/password buyer test accounts, an ACTIVE live auction allowing bids, an ACTIVE direct listing with exactly **1 unit available**, and a valid Aden area UUID. Ensure both buyers are eligible, neither is the seller. The script creates actual dev bids and orders; *do not run on production*.

```bash
export MARSA_TEST_ENV=development
export SUPABASE_URL=https://YOUR-DEV-PROJECT.supabase.co
export SUPABASE_ANON_KEY=YOUR_DEV_PUBLIC_ANON_KEY
export TEST_BUYER_A_EMAIL=buyer-a@example.test
export TEST_BUYER_A_PASSWORD=YOUR_TEST_PASSWORD
export TEST_BUYER_B_EMAIL=buyer-b@example.test
export TEST_BUYER_B_PASSWORD=YOUR_TEST_PASSWORD
export TEST_LIVE_AUCTION_ID=YOUR_LIVE_AUCTION_UUID
export TEST_SINGLE_UNIT_DIRECT_LISTING_ID=YOUR_SINGLE_UNIT_LISTING_UUID
export TEST_ADEN_AREA_ID=YOUR_ADEN_AREA_UUID
python tests/backend_concurrency.py --i-understand-test-writes
```

Assertions: one of two equal simultaneous bid requests is accepted; one of two simultaneous one-unit orders is accepted; non-admin RPC fails; a buyer cannot read the other buyer's private profile. Test preparation and results MUST be captured in CI/dev environment before claiming proven concurrency safety. The live script also cancels the successful order once, asserts a duplicate cancellation fails, buys the restored unit from the other account, and asserts a third buyer request cannot oversell it.

## Failure investigations

- Dart compile errors: run `dart format` then `flutter analyze`, fix target SDK/API compatibility and dependency versions; do not bypass tests.
- HTTP 401/403: check session, account status, seller approval and migration RLS (not secrets in Flutter).
- HTTP 409/business errors: preserve order idempotency keys on retries; refresh auction minimum price from server response.
- Image upload 403: check bucket policy, owner UID prefix and listing ID prefix, MIME and size.
- Missing notification/expiry: inspect deployed Edge Function logs and scheduler secret; migrations do not install a cron trigger automatically.
- Offline: cached listings are read-only; order and bid require an actual server response.

## Known unverified items

No measured load/performance profile, no real-user accessibility audit, no push/Firebase configuration, no operating payment/refund flow, no actual in-app legal support channel, no completed English string pass, no SMTP delivery verification, no real Android Studio import/build proof. No claim of release readiness is made.

## Phase 2 staging acceptance harness — additional prerequisites (NOT EXECUTED here)

`tests/backend_acceptance.py` requires an **isolated development** Supabase project and explicit `MARSA_TEST_ENV=development`. The below are placeholder environment variables, not real credentials. Use staging-only accounts, never real users or production keys:

```bash
export MARSA_TEST_ENV=development
export SUPABASE_URL=https://YOUR-STAGING-PROJECT.supabase.co
export SUPABASE_ANON_KEY=YOUR_STAGING_PUBLIC_ANON_KEY
export TEST_BUYER_A_EMAIL=buyer-a@example.test
export TEST_BUYER_A_PASSWORD=REPLACE_IN_LOCAL_SHELL
export TEST_BUYER_B_EMAIL=buyer-b@example.test
export TEST_BUYER_B_PASSWORD=REPLACE_IN_LOCAL_SHELL
export TEST_PENDING_SELLER_EMAIL=pending-seller@example.test
export TEST_PENDING_SELLER_PASSWORD=REPLACE_IN_LOCAL_SHELL
export TEST_APPROVED_SELLER_EMAIL=approved-seller@example.test
export TEST_APPROVED_SELLER_PASSWORD=REPLACE_IN_LOCAL_SHELL
export TEST_ADMIN_EMAIL=admin@example.test
export TEST_ADMIN_PASSWORD=REPLACE_IN_LOCAL_SHELL
export TEST_ADEN_AREA_ID=VALID_ENABLED_ADEN_AREA_UUID
export TEST_CATEGORY_ID=VALID_ACTIVE_CATEGORY_UUID
export TEST_LIVE_AUCTION_ID=APPROVED_SELLER_OWNED_ACTIVE_LIVE_AUCTION_UUID
export TEST_EXPIRED_AUCTION_ID=EXPIRED_UNFINALIZED_AUCTION_UUID
export TEST_ENDED_RESERVE_AUCTION_ID=EXPIRED_UNFINALIZED_BELOW_RESERVE_BID_AUCTION_UUID
export TEST_ENDED_WINNER_AUCTION_ID=EXPIRED_UNFINALIZED_WITH_WINNING_BID_AUCTION_UUID
python tests/backend_acceptance.py --i-understand-test-writes
```

Required fixture properties: the buyer accounts must not be the approved seller or each other; the pending seller must be unapproved; the admin must be present in `mars_private.admin_users` through trusted server-side setup. The live auction **must belong to** `TEST_APPROVED_SELLER` for the self-bid check. The reserve fixture must have one or more accepted bids below `reserve_price` and must not yet have been finalized. The winner fixture must have an accepted bid meeting the reserve and also be unfinalized. Both fixture end times must be in the past according to server time. The script creates a labelled `QA testing only` draft, uploads an image, submits it to moderation, and finalizes the two expired fixtures. It changes the database: take a staging snapshot and **never run it against production**. It tests sign-in, not sign-up/email confirmation or SMTP; verify sign-up manually with the configured mail provider.

`tests/backend_concurrency.py` additionally requires `TEST_SINGLE_UNIT_DIRECT_LISTING_ID` (one unit in stock, approved seller, ACTIVE). It executes concurrent purchases and bids, validates same-key retries and changed-key-payload rejections, cancels one purchase and checks stock restoration. Run only after preparing fresh fixtures and verify the outputs (none were available in this sandbox).
