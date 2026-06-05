# Orbit — App Store Connect submission kit

Everything to paste into App Store Connect. Drafted 2026-06-05.

## Identity

| Field | Value |
|---|---|
| Name | Orbit: Spending Tracker (if plain "Orbit" is taken; try "Orbit" first) |
| Subtitle (30 chars max) | `Private spending tracking` |
| Category | Finance |
| Secondary category | Productivity (optional) |
| Price | Free |
| Age rating | 4+ (no objectionable content; finance questionnaire all "No") |

## Promotional text (170 chars, editable without review)

> Your purchases, tracked the moment you tap to pay. Orbit keeps every
> transaction on your device. No bank logins required.

## Description

> Orbit is a spending tracker that respects your privacy.
>
> Set up a one-time Shortcuts automation and every Apple Pay purchase imports
> itself the moment you tap to pay: amount, merchant, card, and (optionally)
> where it happened. No bank logins. No screen-scraping. No selling your data.
>
> YOUR DATA STAYS YOURS
> Transactions live on your iPhone and sync privately to your own account, so a
> new phone shows your full history the moment you sign in. Orbit has no
> analytics SDKs, no trackers, and no ads. We never sell or share your data.
> Purchase locations never leave your device.
>
> EFFORTLESS TRACKING
> • Apple Pay purchases import automatically via Shortcuts
> • Add cash or card purchases in seconds
> • Merchant logos and smart categorization keep things tidy
> • See purchases on a map (optional, on-device)
>
> BUDGETS THAT FIT REAL LIFE
> • Monthly budget with an everyday-spending mode that ignores fixed costs
> • Recurring payment tracking so subscriptions never surprise you
> • Budget alerts and weekly summaries, scheduled entirely on your phone
> • Home Screen widget with your month at a glance
>
> PRIVATE BY DESIGN
> • Face ID app lock
> • No third-party tracking, no ads
> • Delete your account any time, right in the app
>
> Sign in with Apple, Google, or email and start tracking in under a minute.

## Keywords (100 chars max)

`budget,spending,tracker,money,expense,apple pay,wallet,finance,privacy,subscriptions,cash,widget`

## URLs

| Field | Value |
|---|---|
| Support URL | https://orbitspending.com/support.html |
| Marketing URL | https://orbitspending.com |
| Privacy Policy URL | https://orbitspending.com/privacy.html |

## App Review Information (notes for the reviewer)

> SIGN-IN: Use the demo account below, or create an account with any email
> (verification email arrives within seconds).
>
> Demo account: demo@orbitspending.com / OrbitReview2026!
>
> APPLE PAY IMPORT: Orbit's automatic import works through an Apple Shortcuts
> personal "Transaction" automation that the user creates (Setup Guide in-app,
> Settings → Setup Guide). The automation passes the transaction's amount,
> merchant, and card name to Orbit's App Intent. Orbit has NO access to Apple
> Wallet, the user's cards, or bank accounts; it only receives what the
> Shortcut passes. Manual entry (+ button) works without any setup.
>
> BACKGROUND LOCATION ("Always"): used solely to tag where an Apple Pay
> purchase happened at the moment the background import runs. Location is
> stored on-device only and never transmitted. The app is fully functional if
> location is denied. This is disclosed in the privacy policy and in the
> in-app purpose strings.
>
> ACCOUNT DELETION: Settings → Account → Delete Account (guideline 5.1.1(v)).

## Privacy nutrition labels (App Privacy section)

Data types to declare (updated for cloud sync, 2026-06-05):

1. **Contact Info → Email Address**
   - Collected: YES. Linked to user: YES. Used for tracking: NO.
   - Purpose: App Functionality (account creation/sign-in).
2. **Identifiers → User ID**
   - Collected: YES (Supabase user id). Linked to user: YES. Tracking: NO.
   - Purpose: App Functionality.
3. **Purchases → Purchase History**
   - Collected: YES (transactions sync to the user's private account space:
     amount, merchant, card name, date, category, notes). Linked to user: YES.
     Tracking: NO. Purpose: App Functionality (cross-device sync).
4. **Other Financial Info**
   - Collected: YES (monthly budget amount syncs). Linked: YES. Tracking: NO.
   - Purpose: App Functionality.
5. **Location: NOT collected.** Purchase location tags are stored on-device
   only and are never transmitted (the sync layer strips them by design).
6. No analytics, no ads, no tracking → "Data Not Used to Track You".

## Screenshots needed (you provide; 6.9" iPhone required, 6.5" optional)

Suggested five, in order:
1. Spending overview with budget ring/progress
2. Transaction list with merchant logos
3. A transaction detail with the map card
4. Widget on a Home Screen
5. The onboarding/setup guide (the Apple Pay automation pitch)

## Build settings checklist (already done in repo)

- [x] Display name "Orbit", version 1.0 (1)
- [x] ITSAppUsesNonExemptEncryption = NO
- [x] Sign in with Apple entitlement
- [x] Account deletion implemented + verified
- [x] Privacy policy/ToS accurate in-app
- [ ] Archive with Distribution profile and upload via Xcode Organizer
