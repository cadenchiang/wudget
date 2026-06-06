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
| Age rating | Answer the NEW (2025) expanded questionnaire honestly — no UGC, no gambling, no unrestricted web, no ads; expect the lowest tier (4+). The old "pick 4+" shortcut no longer exists. |
| EU availability | Requires a DSA trader/non-trader declaration in App Store Connect. Trader status publishes your address + contact on the EU store. Free app, no IAP → declare non-trader, or launch US-only first and expand later. |

## Promotional text (170 chars, editable without review)

Angle (Caden, 2026-06-06): AUTOMATIC tracking is the hook; privacy is a
footer, not the headline.

> Orbit gives you spending tracking that does itself. Every Apple Pay
> purchase logs the moment you tap to pay. No bank links, no typing.

## Description

> Orbit tracks your spending automatically.
>
> Set up a one-time Shortcut and every Apple Pay purchase logs itself the
> moment you tap to pay: amount, merchant, and card, without ever opening the
> app. No bank logins. No spreadsheets. No typing in receipts.
>
> TRACKING THAT DOES ITSELF
> • Apple Pay purchases import automatically, in the background
> • Merchant logos and smart categorization keep your list tidy
> • Cash or card purchases add manually in seconds
> • See where a purchase happened on a map
>
> KNOW WHAT YOU CAN SPEND
> • Monthly budget with a daily allowance that updates as you spend
> • Everyday-spending mode that ignores fixed costs like rent
> • Recurring payment tracking so subscriptions never surprise you
> • Alerts for budget limits, large purchases, upcoming charges, plus a
>   weekly summary
> • Home Screen widget with your month at a glance
>
> SET UP IN A MINUTE
> Sign in with Apple, Google, or email, follow the guided setup, and your
> next tap-to-pay purchase tracks itself. Your history syncs to your account,
> so a new phone picks up right where you left off.
>
> PRIVATE BY DESIGN
> No analytics, no ads, no selling your data. Purchase locations never leave
> your device. Face ID lock and in-app account deletion included.
>
> Orbit is free.

Every claim verified against the code 2026-06-06 (NotificationManager has
weekly summary / upcoming charges / large purchase / budget alerts; sync,
deletion, widget, Face ID all shipped). Known nuance for the privacy policy:
merchant names are sent to Logo.dev when fetching logos (not user-linked).

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
> personal "Transaction" automation that the user creates (in-app walkthrough:
> Settings → Tracking → "Set up Apple Wallet tracking"). The automation passes
> the transaction's amount, merchant, and card name to Orbit's App Intent.
> Orbit has NO access to Apple Wallet, the user's cards, or bank accounts; it
> only receives what the Shortcut passes. Manual entry (+ button on the
> Spending tab) works without any setup — the app is fully testable without
> creating the automation.
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

## Accessibility Nutrition Label (new ASC section, 2025)

Declare only what's actually been tested. As of 2026-06-06 nothing has been
audited, so the safe initial answers:

- Dynamic Type / Larger Text: untested — do not claim until verified
- VoiceOver: untested — custom tab bar and chrome have accessibility labels,
  but no full pass has been run; do not claim until verified
- Dark Mode is NOT part of this label (it covers assistive features)

Either run a quick VoiceOver + text-size pass before submitting and claim what
holds up, or leave the label minimal at 1.0 and improve it in 1.1.

## Build settings checklist (already done in repo)

- [x] Display name "Orbit", version 1.0 (1)
- [x] ITSAppUsesNonExemptEncryption = NO
- [x] Sign in with Apple entitlement
- [x] Account deletion implemented + verified
- [x] Privacy policy/ToS accurate in-app
- [ ] Archive with Distribution profile and upload via Xcode Organizer

See `launch-checklist.md` for the full ordered runbook (pre-archive checks,
TestFlight, secrets rotation, submission).
