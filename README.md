# ⚡ Aura Quest

Gamified social habit-tracker — friends compete in challenges using **Aura points**.

**Stack:** Flutter · Supabase (Auth + DB) · Riverpod · go_router
**Vibe:** Dark mode, neon accents, Cyber-Pixel (modern social app × retro RPG)

## Getting started

The Dart code and config live in this repo; the platform folders (`android/`,
`ios/`, etc.) are generated locally by Flutter.

```bash
# 1. Install Flutter (if not yet installed): https://docs.flutter.dev/get-started/install

# 2. From the project root — generate platform scaffolding.
#    Existing files (lib/, pubspec.yaml) are NOT overwritten.
flutter create --project-name aura_quest --org com.auraquest .

# 3. Fetch dependencies
flutter pub get

# 4. Run it
flutter run
```

> If you were starting from an empty folder instead, the equivalent from-scratch
> commands would be:
> ```bash
> flutter create --project-name aura_quest --org com.auraquest aura_quest
> cd aura_quest
> flutter pub add supabase_flutter flutter_riverpod go_router google_fonts
> ```

## Supabase setup

1. Create a project at [supabase.com](https://supabase.com).
2. Copy the **Project URL** and **anon key** from *Project Settings → API*.
3. Paste them into [`lib/core/config/supabase_config.dart`](lib/core/config/supabase_config.dart).

Until then the app runs in **offline skeleton mode** (Supabase init is skipped
and the login buttons walk straight through to the dashboard).

### Google OAuth setup (for "Continue with Google")

1. **Google Cloud Console** → create OAuth credentials
   ([Supabase guide](https://supabase.com/docs/guides/auth/social-login/auth-google)).
2. **Supabase dashboard** → *Authentication → Providers → Google* → enable and
   paste the client ID/secret.
3. **Supabase dashboard** → *Authentication → URL Configuration → Redirect URLs*
   → add `io.supabase.auraquest://login-callback/`.
   (Local stack: already allowlisted in `supabase/config.toml` → `additional_redirect_urls`.)
4. **Android** — add inside `<activity android:name=".MainActivity">` in
   `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <intent-filter>
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="io.supabase.auraquest" android:host="login-callback" />
   </intent-filter>
   ```
5. **iOS** — add to `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array><string>io.supabase.auraquest</string></array>
     </dict>
   </array>
   ```

## Database

The schema lives in [`supabase/migrations/`](supabase/migrations/) (apply files in order):

**Economy: aura is challenge-scoped.** There is no global aura — each
`challenge_participant` carries its own `challenge_aura`, earned by check-ins
and spent in that challenge's shop.

| Table | Purpose |
|---|---|
| `profiles` | Player data (username) — auto-created by a DB trigger on signup |
| `challenges` | Habit challenges (title, `duration_days`, `starts_on`, aura gain/penalty, `max_strikes`) |
| `challenge_participants` | Who joined which challenge + status + `challenge_aura` (the per-quest balance) |
| `check_ins` | One row per user/challenge/day (UTC) — read-only for clients, written only by RPC |
| `benefits` | A challenge's shop stock (seeded on creation) — read-only for clients |
| `benefit_purchases` | Which user bought which benefit in which challenge — written only by RPC |
| `invites` | Quest invitations (pending/accepted/declined) — written only by RPC |
| `nudges` | Pokes between quest-mates, max 1/day/person/quest — written only by RPC |

RPCs (all SECURITY DEFINER — the only write paths to aura, check-ins and purchases):
- `create_challenge(title, duration_days, aura_gain, aura_penalty, max_strikes, starts_on)` —
  creates the challenge, joins the creator and stocks its shop, in one transaction.
- `log_check_in(challenge_id)` — validates schedule window, strike budget
  (too many missed days ⇒ participant is marked `failed`) and once-per-day,
  then logs the check-in and pays `aura_gain` into `challenge_aura`.
- `purchase_benefit(benefit_id)` — checks the quest balance, deducts the cost
  and links the purchase to the challenge entry, in one transaction.
- `invite_to_challenge(challenge_id, username)` / `respond_to_invite(invite_id, accept)` —
  quest invitations; accepting joins the quest in the same transaction.
- `nudge_participant(challenge_id, user_id)` — poke a quest-mate (1/day rate limit).

Quest members can see each other's check-ins and purchases (RLS scoped to
shared quests). Aura, check-ins, purchases, invites and nudges are all
client-read-only — every mutation goes through a validated RPC.

**The settlement engine** (`settle_periods()`, hourly via pg_cron):
missed periods cost `aura_penalty` and a strike; *Half Damage* halves the
next penalty, *Streak Shield* absorbs the next strike (both consumable);
blowing the strike budget fails the quest (25% of the aura survives);
finishing grants a bonus (remaining strikes × penalty) and freezes the
aura as a trophy. Every outcome lands in `settlement_events` — the
future FCM push trigger attaches there, so notifications need no rule
changes.

Security model: RLS on all tables; clients can never write `total_aura`
directly (column-level grants) — aura changes will go through a server-side
RPC in a later phase.

- **Local** (already applied): the migration ran against the `supabase start` stack.
- **Hosted**: paste the same file into *Dashboard → SQL Editor → Run*.

## Architecture

Feature-driven structure — each feature owns its screens, state and data access:

```
lib/
├── main.dart                  # Entry point: Supabase init + ProviderScope
├── app.dart                   # Root widget: MaterialApp.router + theme
├── core/                      # Shared across all features
│   ├── config/                # Supabase credentials
│   ├── router/                # go_router config + route constants
│   ├── theme/                 # Colors + ThemeData (Cyber-Pixel)
│   └── widgets/               # Reusable UI components
└── features/
    ├── splash/                # Launch screen (future: session check)
    ├── auth/                  # Login (future: signup, profile setup)
    ├── dashboard/             # Bottom-nav shell around the 4 tabs
    ├── home/                  # Aura score, streaks, feed
    ├── challenges/            # Active & completed challenges
    ├── friends/               # Friend list, requests, leaderboard
    └── shop/                  # Spend Aura points
```

Inside each feature, code is layered as `presentation/` (screens, widgets),
and later `application/` (Riverpod controllers), `domain/` (models) and
`data/` (Supabase repositories) as the features get real logic.

## Roadmap

- [x] **Phase 1** — Project skeleton: theming, routing, placeholder screens
- [x] **Phase 2** — Real auth (email sign-in/sign-up + Google via Supabase, auth-aware routing)
- [x] **Phase 3** — Database schema (profiles, challenges, participants) with RLS + signup trigger
- [ ] **Phase 4** — Challenges & social features
