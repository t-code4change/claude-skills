---
name: firebase
description: Integrate Firebase Authentication (Google Sign-In with popup) into Next.js frontend + Node.js/Hono backend. Covers Firebase Admin SDK lazy init, CSP headers, docker-compose env vars, and all known bugs with exact fixes.
triggers:
  - "integrate firebase"
  - "firebase google login"
  - "login with google"
  - "firebase authentication"
  - "google sign in"
  - "signInWithPopup"
  - "firebase admin"
references:
  - references/integration-guide.md
  - references/known-issues.md
---

# Firebase Authentication Skill

Integrate Firebase Google Sign-In (popup) into Next.js + Node.js/Hono stack correctly, applying all known fixes upfront.

## Critical Rules (ALWAYS apply these)

1. **Lazy init Firebase Admin** — NEVER call `initializeApp()` at module load. Use `ensureInit()` pattern → avoids server crash on deploy when `FIREBASE_SERVICE_ACCOUNT` not yet set.
2. **Hardcode Firebase client config as fallbacks** — Vercel build doesn't inject `NEXT_PUBLIC_*` env vars unless baked in at build time. Client Firebase config is public — safe to hardcode as fallback values.
3. **Update CSP headers in next.config.mjs** — Firebase popup requires `apis.google.com` in `script-src` and `accounts.google.com` + Firebase auth domain in `frame-src`.
4. **Add env var to docker-compose.yml** — `docker restart` does NOT reload env vars. Must add to `environment:` section AND run `docker compose up --force-recreate`.
5. **Use Next.js proxy route** — Never expose backend URL to client. Create `/api/auth/google/route.ts` that forwards `idToken` to backend.
6. **Mark endpoint as public** — Add `/api/auth/google/firebase` to `publicPaths` array, or it'll return 401.

## Quick Setup

### Backend
```bash
npm install firebase-admin
```

### Frontend
```bash
npm install firebase  # if not already installed
```

### Firebase Console Setup (one-time)
1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key" → download JSON
3. Minify + set as `FIREBASE_SERVICE_ACCOUNT` env var on server
4. Enable Google provider: Authentication → Sign-in method → Google → Enable
5. Add your domains to Authorized domains list

## When Something Breaks

See `references/known-issues.md` — 6 documented bugs with exact fixes.

## Full Integration Code

See `references/integration-guide.md`.
