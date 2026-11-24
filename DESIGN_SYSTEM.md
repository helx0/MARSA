# MARSA Design System — Marine identity

## Brand tokens

| Name | Hex | Usage |
|---|---|---|
| Deep Ocean Navy | `#073B4C` | Headings, banner, primary brand |
| Sea Teal | `#0E7C86` | Buttons, navigation emphasis, pricing |
| Turquoise | `#22B8B0` | Limited accents |
| Seafoam | `#DFF3EF` | Chips, soft backgrounds |
| Sand | `#F4EBDD` | Warm neutral accents |
| Coral | `#F0785A` | Urgency/error indicators |
| White | `#FFFFFF` | Cards/surfaces |
| Slate | `#20343B` | Body text |
| Muted | `#6B7C82` | Supporting text |
| Border | `#E2EAEC` | Cards and separators |

Tokens in `lib/core/theme/marsa_theme.dart`. Material 3 with a brand ColorScheme, 48dp button minimum, soft 14–16dp radii, 8dp spacing multiples, typically 16dp phone horizontal gutter. Arabic is default. The project relies on platform Arabic font fallback; a fully licensed, bundled Arabic font such as Cairo/Tajawal should be included for deterministic brand typography before release. The custom sail-and-wave asset in `assets/images/marsa_marine_mark.png` and Android `mipmap-*/ic_launcher.png` are original generated placeholders and can be replaced without changing code.

## Language and RTL

`lib/core/localization/strings.dart` contains Arabic/English common UI strings. `MaterialApp` supplies Arabic/English locales and localizations delegates and enforces RTL or LTR with `Directionality`. Flutter directional properties and standard back buttons should reverse automatically. ISO currency codes remain LTR-safe via normal rendering, but a full accessibility/bidi audit on devices is outstanding. Several long explanatory messages and admin controls are Arabic-only in this source; full English copy coverage is a known unfinished acceptance item, **not** represented as done.

## Components

- `SeafoodListingCard`: item thumbnail, name, price or current auction, area and type chip.
- `AuctionPanel`: server-time offset countdown, history of anonymized bid amounts, minimum and confirmation.
- `StatusPill`, `EmptyState`, `LoadingView`, `ErrorView`, `FormSpace` reused across feature screens.
- Shared Material 3 `TextField`, `DropdownButtonFormField`, elevated/outlined buttons, confirmation dialogues and app navigation.

## Screen inventory

| Route | Screen |
|---|---|
| `/launch` | Splash/session restoration / first-run routing |
| `/intro` | Three-card onboarding with skip |
| `/` | Marketplace, search, filters, results and paging |
| `/listing/:id` | Gallery, detail, seller identity, order/auction/contact/favorite/report |
| `/login`, `/signup`, `/reset`, `/password-update` | Email authentication and password recovery |
| `/checkout/:id` | Payment/meeting method and quantity / confirmation |
| `/orders`, `/order/:id` | Order list, status timeline, seller/buyer actions, review, dispute report |
| `/seller`, `/seller/apply`, `/seller/create`, `/seller/edit/:id` | Seller center, verification request, listing creation/edit/stock controls |
| `/inbox`, `/conversation/:id` | Private messages/block/report |
| `/favorites` | Saved listings with remove/unavailable state |
| `/notifications` | Notification read state and deep navigation |
| `/profile`, `/help` | Name/phone/area/language, support, rules, privacy |
| `/admin` | Seller/listing approval, reports/disputes, reference records, audit, account suspension |

## Accessibility/QA to perform with Flutter installed

Test 320dp Android portrait width, landscape, large text, TalkBack, reduced motion, UI clipping on long Arabic names, image error states, keyboard overlap, RTL/LTR navigation and contrast. Animated effects are kept minimal to avoid gratuitous motion. Do not approve the visual system for production without this on-device testing.
