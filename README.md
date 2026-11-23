# gamified-tourism-sih-2026
Full-stack gamified tourism platform built for Smart India Hackathon 2026, featuring authentication, quests, quizzes, XP &amp; leveling, monument registration, digital journals, avatar customization, and AR integration.
Gamified Tourism Platform — SIH 2026

A team project developed for Smart India Hackathon 2026. Our team cleared the internal hackathon round and submitted this project as our SIH entry.

My contributions:

Backend development and API design
Authentication
Quiz and quest systems
XP and leveling logic
Monument registration
Digital journal functionality
Database implementation
Avatar customization frontend
AR integration

# API Reference

REST endpoints for authentication, quests, quizzes and quest creation (with QR codes), plus the XP and level logic behind city progress.

## Base paths

Each router is mounted under its own prefix in the main app. The paths below are shown relative to that prefix.

| Router | Prefix | Purpose |
|---|---|---|
| Auth | `/auth` | Registration, login, tokens, user management |
| Quests | `/quests` | Browsing, accepting and completing quests |
| Quiz | `/quiz` | Quiz attempts for a quest |
| Quest creation (QR) | `/api/qr` | Creating quests, adding questions, generating QR codes |

The app is an Express server. Request bodies are parsed as JSON (`express.json()`), and CORS is enabled for all origins.

## Authentication

Routes with **Yes** in the Auth column go through the `authenticateToken` middleware and need a valid access token:

```
Authorization: Bearer <access_token>
```

Get a token from `POST /auth/log-in`, and renew it with `POST /auth/refreshtoken`. Requests to protected routes without a valid token are rejected by the middleware.

---

## Auth

Prefix: `/auth`

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/register` | No | Create a new account |
| POST | `/log-in` | No | Log in and receive tokens |
| POST | `/refreshtoken` | No | Get a new access token using a refresh token |
| POST | `/revoke/:id` | Yes | Revoke access for the user with the given id |
| POST | `/promotion/:id` | Yes | Promote the user with the given id |

Every route declared after `auth_router.use(authenticateToken)` is protected, which covers `/revoke/:id` and `/promotion/:id`.

**URL parameters**

| Param | Used in | Description |
|---|---|---|
| `id` | `/revoke/:id`, `/promotion/:id` | Id of the target user |

---

## Quests

Prefix: `/quests`

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/` | No | List quests |
| GET | `/cities` | No | List cities |
| GET | `/completed_quests` | Yes | List the logged-in user's completed quests |
| GET | `/:id` | No | Get one quest by id |
| POST | `/photo-upload-url` | Yes | Create an upload URL for a quest photo |
| POST | `/:id/accept` | Yes | Accept a quest |
| POST | `/:id/completion` | Yes | Submit a quest as completed |

**URL parameters**

| Param | Description |
|---|---|
| `id` | Quest id |

Route order matters here. `/cities` and `/completed_quests` are declared before `/:id` so they aren't treated as quest ids.

---

## Quiz

Prefix: `/quiz`

All quiz routes require authentication.

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/:questId/start` | Yes | Start a quiz attempt for a quest |
| POST | `/:questId/answer` | Yes | Submit an answer for a quest's quiz |
| GET | `/:attemptId/finish` | Yes | Finish an attempt and get the result |

**URL parameters**

| Param | Used in | Description |
|---|---|---|
| `questId` | `/:questId/start`, `/:questId/answer` | Id of the quest the quiz belongs to |
| `attemptId` | `/:attemptId/finish` | Id of the quiz attempt |

---

## Quest creation and QR codes

Prefix: `/api/qr`

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/quest` | Yes | Create a quest |
| POST | `/quest/:id/questions` | Yes | Add a question to a quest |
| GET | `/quest/:id` | No | Generate a QR code for a quest |

**URL parameters**

| Param | Description |
|---|---|
| `id` | Quest id |

Unlike creating quests and questions, generating a QR code doesn't require a token.

---

## XP and levels

Players earn XP per city, and each city has its own level thresholds. Two services handle this.

### `awardXp(userId, cityId, xp)`

Adds XP to a user's progress in one city and recalculates their level.

1. Returns `{ success: false, message: "missing required fields" }` if any argument is falsy. Note that `xp = 0` counts as missing.
2. Looks up the city, and returns `{ success: false, message: "city not found" }` if it doesn't exist.
3. Adds `xp` to the user's existing XP for that city (or to 0 if they have no progress yet).
4. Sets the level to the highest `i + 1` for which the new total is at or above `level_thresholds[i]`. The minimum is 1 and the maximum is `MAX_LEVEL` (5).
5. Creates or updates the `user_city_progress` row for that user and city.

Returns `{ success: true, cityProgress }` on success, or `{ success: false, message: "database error" }` if the write fails.

If the city's thresholds haven't been calculated yet, the player stays at level 1.

### `calculateThreshold(cityName)`

Works out the level thresholds for one city from the XP available in it, and saves them to `cities.level_thresholds`.

```
totalXp    = sum of xp of all quests in the city + (10 × number of quests × 5)
step       = totalXp × 0.25
thresholds = [0, step, 2×step, 3×step, 4×step]   (each rounded down)
```

- `10` is `correctAnsXp`, the XP for a correct quiz answer, and `0.25` is `reductionFactor`.
- The `× 5` assumes 5 quiz questions per quest.
- The first threshold is always 0, so every player starts at level 1.
- Level 5 starts at `totalXp` (four steps of 0.25), so reaching it takes all of the city's quest XP plus every quiz answer correct.
- A city with no quests gets all-zero thresholds, so any XP puts a player straight at level 5.

Returns `{ success: true, level_thresholds, message }`, or `{ success: false, message }` if the name is missing or the city isn't found.

### Recalculating all cities

A one-off script loops over every row in `cities` and calls `calculateThreshold` for each one. Nothing in these files recalculates thresholds automatically, so run it again whenever quests or their XP values change.

---

## Utilities

### `getDistanceKm(lat1, lng1, lat2, lng2)`

Returns the distance in kilometres between two coordinates, using the Haversine formula with an Earth radius of 6371 km.

```js
getDistanceKm(26.8467, 80.9462, 28.6139, 77.2090); // Lucknow to Delhi, about 417 km in a straight line
```
## Backend setup

The backend is a Node.js/Express API using Prisma with a Supabase Postgres database and Supabase Storage for photo uploads. Authentication uses role-based JWT access and refresh tokens.

### Hosting status

The API was originally hosted on Railway. The free trial has ended, so there is no live backend URL at the moment. You can run it locally with the steps below.


### Prerequisites

- Node.js 18+
- A Supabase project (free tier works) with two storage buckets: one for quest photos and one for journal photos
- A Gemini API key (only needed for the optional seed script, free version works fine)

### Run locally

1. Install dependencies:
   ```bash
   npm install
   ```
2. Create your environment file and fill in the values:
   ```bash
   cp .env.example .env
   ```
3. Set up the database:
   ```bash
   npx prisma migrate deploy
   npx prisma generate
   ```
4. Start the server:
   ```bash
   npm run dev
   ```

The server runs on `http://localhost:3000` unless `PORT` is set. 

### Environment variables

| Variable | Purpose |
|---|---|
| `ACCESS_TOKEN_SECRET` | Signs short-lived JWT access tokens (15 min) |
| `REFRESH_TOKEN_SECRET` | Signs refresh tokens (15 days) |
| `DATABASE_URL` | Pooled Postgres connection used at runtime |
| `DIRECT_URL` | Direct Postgres connection used for Prisma migrations |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side key used to create signed upload URLs and upload journal photos; never expose to the client |
| `SUPABASE_QUEST_PHOTO_BUCKET` | Bucket for quest completion photos (default `quest-evidence`) |
| `SUPABASE_JOURNAL_BUCKET` | Bucket for journal photos (default `journal-photos`) |
| `GEMINI_API_KEY` | Only needed by the seed script that generates AR guide dialogue |

Secrets live only in environment variables. `.env` is git-ignored and `.env.example` lists the names without values. Passwords are hashed with bcrypt before storage.

### Seeding guide dialogue (optional)

The seed script fetches a Wikipedia summary for each demo monument, asks Gemini to generate the AR guide dialogue from that summary only, and saves the result to `quests.guide_dialogue`. It needs `GEMINI_API_KEY` and is not required to run the API.


### Deploying

Any Node host works (Railway, Render, etc.). Set the variables above in the host's environment settings, set the build and start commands from `package.json`, and run `npx prisma migrate deploy` against the production database.


