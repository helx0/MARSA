# MARSA Software Requirements Specification — MVP

## Vision and scope

Aden-only Android marketplace for seafood. A listing is **either** DIRECT fixed-price or AUCTION; never hybrid. Governorates are configurable records; only Aden is enabled/seeding for v1. Sellers and buyers agree on collection or delivery and payment directly. This source includes no mobile money transfer, payment gateway, escrow or automatic currency conversion.

## Actor matrix

| Actor | Capabilities |
|---|---|
| Guest | Discover, search/filter, view active listings, seller public brand and auction prices. |
| Buyer | Signup/signin, profile/area, favorites, orders, bids, chat, review completed orders, reports. |
| Approved seller | Buyer capability plus listing creation/edit, stock/price, auctions, receive/advance orders. Approval required. |
| Administrator | Securely approve sellers, moderate listings, inspect/resolve reports, manage Aden references, suspend accounts, read audit history. |
| System | Audit/order notifications, transaction authorization, auction expiry and winner deadline. |

## Functional requirements coverage in source

| Requirement | Implementation |
|---|---|
| FR-001 Auth | Email/password sign-up/in, sign-out, password reset and recovery callback (needs configured SMTP / redirect). |
| FR-002 Roles | Buyer default, pending seller application, private administrative role table. |
| FR-003 Aden area | Foreign-keyed tables, seed 8 Aden districts; profile/checkout/listing area selection. |
| FR-004 Catalog | Admin category records, images, condition, unit, stock, currency, status. |
| FR-005 Marketplace | Search seafood/title/English, category, seller, area, mode and price within a selected currency; newest/oldest/relevance/price sorting, pages, loading/error/empty, cached details. |
| FR-006 Direct | Stock-locking RPC, snapshots, idempotency key, order status and restoration. |
| FR-007 Auction | Auction fields, server-time bid locks/RPC, public anonymized amounts, finalization and award. |
| FR-008 Orders | Order numbers, buyer/seller, snapshots, history, cash/manual arrangement, delivery method. |
| FR-009 Chat | Private listing-context conversation, messages, block/report. |
| FR-010 Favorites | Owner-only favorites, removal. |
| FR-011 Reviews | One review per completed buyer order, 1..5 rating, no self-review. |
| FR-012 Notifications | In-app persisted events/read state (no device push until FCM credentials). |
| FR-013 Moderation | Seller approval, reports, listing moderation, account suspension, audit. |
| FR-014 Admin | Protected in-app admin dashboard and secure RPC actions. |
| FR-015 Policies | In-app about/rules/privacy/safety/help; legal counsel needed prelaunch. |

## Nonfunctional requirements

- SQL row-level security and narrow grants. Sensitive state mutations use security-definer functions with explicit checks.
- Auction row locks and order stock transactions prevent race conditions; idempotency constraints limit duplicates.
- Material 3, 48dp buttons, safe area, RTL default with English language choice; screen layouts for phone use.
- Arabic validation and reachable retry; no false transaction acknowledgement in offline mode.
- No GPS requirement. User phone number is private; no verified provenance/freshness claims.
- All database schema changes versioned in SQL migrations. Seed script contains only public reference records.

## Explicit exclusions

Fishing trips, ports/landing workflows, logistics fleets, precise GPS tracking, IoT/cold-chain, ERP, government integrations, wallets, payments/escrow, crypto, groceries, social feeds, reels, FCM without credentials, auto currency conversion. No actual live sellers or inventory are assumed. No commercial launch claim.

## Known source limits versus acceptance requirements

No Flutter/Android SDK was installed in delivery workspace; APK build, Dart analyzer, Flutter tests and device UI/accessibility QA **could not be executed**. No Supabase credentials/project; SQL/RLS/RPC tests and concurrency tests **could not run against a database**. English explanatory strings remain incomplete. Operational support contacts, email sender, legal terms, security penetration review and actual production infrastructure must be completed by deployer. See `DELIVERY_REPORT.md`.
