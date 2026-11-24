# LaunchWatch

A Flutter app for people who follow spaceflight: upcoming and recent rocket launches, space events, the crews and stations in orbit right now, and space news, with alerts when a launch you follow slips, changes status, lifts off or lands.

**Live:** https://launchwatch-c77fa.web.app (installable on phones and computers, works offline)

## Features

- **Launches.** The next launch featured with a live countdown, then launches grouped by Today, Tomorrow, This week and month. Countdowns appear only when the published time is precise to the minute; a date known only to the month or quarter is shown that way, never as an invented day.
- **Launch pages.** Webcasts, add to calendar, share, a schedule history of every slip, mission and vehicle details with success rates, related news, and "Can I see it from here?".
- **Location.** "Use my current location" (GPS, Wi-Fi or network) for visibility estimates, asked only on that tap, approximate, and rounded to about 1 km before saving. A city list works without location.
- **Events, News and Explore.** Spacewalks, dockings and press events; Spaceflight News headlines linked to launches; people in space, station pages with crew and docked spacecraft, spacewalks and programs.
- **Accounts.** Email and Google sign-in, email verification, password reset, and changing name, email or password. Deleting an account removes all of its data.
- **Alerts.** Follow a launch to get push notifications and an in-app inbox for slips, status changes, liftoff, outcome and a day-before reminder. There is also an optional weekly digest and a personal calendar feed.
- **Launch log.** Mark launches you watched.
- **Offline and install.** A service worker and Firestore's local cache keep the app usable without a connection. Install from the browser, or from Account → Install LaunchWatch.
- **Accessibility.** Statuses are written as words rather than colour alone, screen-reader labels throughout, the system text size is respected, jargon is explained in a glossary, and reduced motion is honoured.

## How it works

```
Launch Library 2 ─┐                         ┌─> Flutter app (Android, iOS, web)
                  ├─> Cloud Functions ─> Firestore
Spaceflight News ─┘   (scheduled pollers)   └─> Push notifications, calendar feeds
```

Phones never call Launch Library 2 directly. Its free tier allows 15 requests an hour per IP address, so scheduled Cloud Functions poll it within that budget and write Firestore. The app reads Firestore in real time.

| Function | Schedule | Job |
| --- | --- | --- |
| `pollHot` / `pollQuiet` | 10 / 30 min | Launches; sends follow alerts and records schedule history |
| `pollReference` | 30 min | Events, stations, expeditions, astronauts, dockings, spacewalks, programs (most overdue first, only while LL2 requests remain) |
| `pollNews` | 30 min | Spaceflight News API headlines |
| `weeklyDigest` | Mondays 08:00 London | Week-ahead summary for people who opted in |
| `calendar` | HTTP | `/cal/launch/{id}.ics`, `/cal/event/{id}.ics`, `/cal/user/{token}.ics` |
| `cleanUpDeletedUser` | On account deletion | Removes the user's data |

**Security.** Firestore rules make launch and reference data read-only to everyone. Each user can only reach their own documents, with a fixed list of allowed fields. Alerts can only be written by the server. Changing email or password, or deleting the account, needs the current password again. Password reset never reveals whether an email has an account. The app ships no server secrets.

## Project structure

| Path | Contents |
| --- | --- |
| `app/` | Flutter app (`lib/main.dart`, screens and logic in `lib/src/`, tests in `test/`, web shell and service worker in `web/`) |
| `functions/` | Cloud Functions in TypeScript (`src/`), with tests alongside |
| `firestore.rules`, `firestore.indexes.json` | Database security rules and indexes |
| `firebase.json` | Hosting, rewrites, cache headers and function config |
| `scripts/stamp-web.mjs` | Cache-busts each web build and stamps the service worker |

## Running it

Needs Flutter 3.50+, Node 22, and the Firebase CLI (installed by `npm install`).

```bash
cd app
flutter pub get
flutter run            # pick a connected phone, emulator or Chrome
```

The app uses the live `launchwatch-c77fa` Firebase project, so it shows real data straight away.

### Tests

```bash
cd app && flutter test       # app: formatting, accounts, location, catalog, space data
npm --prefix functions install && npm test   # Cloud Functions: mapping, alerts, digest, calendar, reference data
```

### Building and deploying

```bash
npm install
npm --prefix functions install
npm run build:web
npx firebase deploy --project production --only firestore:rules,functions,hosting
```

For a web push key, build with `--dart-define=VAPID_KEY=<key>` from Firebase console → Project settings → Cloud Messaging → Web Push certificates. Without it, browser users still get every alert in the inbox. iOS builds need a Mac with Xcode, plus the Push Notifications capability and an APNs key in Firebase.

## Data sources

Launch, event, station and astronaut data: [Launch Library 2](https://thespacedevs.com/llapi) by The Space Devs. News: [Spaceflight News API](https://spaceflightnewsapi.net). Both are free public APIs.
