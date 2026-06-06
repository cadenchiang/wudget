# Orbit 1.0 — launch runbook

Ordered checklist from current state to "Waiting for Review". Drafted
2026-06-06 against the 2026 App Store requirements (iOS 26 SDK mandate, new
age-rating questionnaire, DSA trader status, Accessibility Nutrition Labels).
Paste-ready metadata lives in `listing.md`.

## Phase 0 — stabilize (before any archive)

- [ ] **Shakedown pass on the current build** (every screen, both themes):
      Spending (+ add flow zoom, row spring-in), Settings + every sub-page,
      swipe-back from sub-pages (must reveal Settings, never page to
      Spending), keyboard hides tab bar, My Cards, Repeat, transaction
      detail, onboarding walkthrough, sign-out → welcome → sign back in.
- [ ] **Run the unit test suite on-device** (Caden runs from Xcode; ~58 tests
      including TabBarStateTests).
- [ ] **Wallet automation end-to-end**: one real Apple Pay purchase imports
      (amount/merchant/card), with and without location permission.
- [ ] **Deny-location run**: fresh install, decline location — app must work
      fully (reviewers test this).

## Phase 1 — security (before real users)

- [ ] **Rotate all secrets pasted in chat on 2026-06-05**: Supabase
      service_role key, DB password, Resend API key, Google OAuth client
      secret, Supabase personal access token. Update `~/.orbit-supabase.env`
      after rotating. (The embedded anon key is fine and stays.)
- [ ] Confirm Supabase email rate limits still sane for launch (30/hr now).

## Phase 2 — App Store Connect setup

- [ ] Create the app record (name "Orbit", fallback "Orbit: Spending
      Tracker"; bundle id com.cadenchiang.walletbudget).
- [ ] Paste metadata from `listing.md` (subtitle, promo text, description,
      keywords, URLs).
- [ ] **New age-rating questionnaire** (2025 system): answer all questions;
      expect lowest tier.
- [ ] **Privacy nutrition labels**: enter exactly the six declarations in
      `listing.md` (email, user id, purchase history, financial info linked
      to user, no location, no tracking).
- [ ] **Accessibility Nutrition Label**: minimal claims at 1.0 unless a
      VoiceOver/Dynamic Type pass happens first (see `listing.md`).
- [ ] **DSA trader status**: declare non-trader (free app, no IAP) or
      restrict availability to exclude the EU at 1.0.
- [ ] App Review notes + demo account from `listing.md` (background-location
      justification + Shortcuts explanation are the two review risks).

## Phase 3 — build & TestFlight

- [ ] Bump nothing: 1.0 (1) is already set in the project.
- [ ] Archive (Release) in Xcode → Organizer → upload to App Store Connect.
      First Release build ever — watch for behavior differences vs Debug.
- [ ] **Watch the post-upload email for ITMS warnings** (missing privacy
      manifests / required-reason APIs in Supabase, Lottie, GoogleSignIn).
      Current SPM versions ship manifests; verify nothing is flagged.
- [ ] Install via TestFlight on Caden's phone; repeat the Phase 0 shakedown
      on the Release build (especially Face ID lock, Wallet import, sync).

## Phase 4 — screenshots & submit

- [ ] Capture the five screenshots from `listing.md` (6.9" required; take on
      the iPhone, light mode, realistic data).
- [ ] Final read of metadata: no "money management" / "banking" / advice
      language anywhere (guideline 3.x finance framing — Orbit is a personal
      spending TRACKER; it moves no money).
- [ ] Submit for review; respond fast if the reviewer asks about background
      location (the notes pre-empt it).

## Known review risks (ranked)

1. **Always-on background location** — justified in review notes; app works
   without it; location never leaves device (matches privacy label).
2. **Core feature behind a Shortcuts automation** — review notes explain the
   in-app walkthrough (Settings → Tracking) and that manual add needs no
   setup; demo account makes the app testable in seconds.
3. **Finance category scrutiny** — tracker-not-bank framing throughout.

## Post-approval

- [ ] Release manually (don't auto-release) so launch timing is yours.
- [ ] Verify production sign-in + sync on the App Store build.
- [ ] Keep the demo account alive as long as the app is listed (Apple
      re-reviews updates with it).
