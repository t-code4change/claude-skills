# Firebase: Known Issues & Fixes

All bugs encountered during Firebase Google Login integration with Next.js + Node.js/Hono backend.

---

## Bug 1: Server crash on deploy — `initializeApp()` at module load

**Symptom:** Backend crashes immediately after deploy. Health check fails → rollback. Error: `FIREBASE_SERVICE_ACCOUNT env var not set` or similar.

**Cause:** `initializeApp()` called at module import time. When env var isn't configured yet (e.g., first deploy before setting secret), server crashes before Express/Hono even starts.

**Fix:** Lazy init pattern — only initialize on first actual use:

```typescript
// src/lib/firebase-admin.ts
import { initializeApp, getApps, cert } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'

let _initialized = false

function ensureInit() {
  if (_initialized) return
  const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
  if (!serviceAccount) throw new Error('FIREBASE_SERVICE_ACCOUNT env var not set')
  if (getApps().length === 0) {
    initializeApp({ credential: cert(JSON.parse(serviceAccount)) })
  }
  _initialized = true
}

export const firebaseAuth = {
  verifyIdToken: (idToken: string) => {
    ensureInit()
    return getAuth().verifyIdToken(idToken)
  },
}
```

---

## Bug 2: `auth/invalid-api-key` on frontend

**Symptom:** Clicking Google login button → `Firebase: Error (auth/invalid-api-key)`.

**Cause:** Vercel doesn't inject `NEXT_PUBLIC_*` env vars into the client bundle unless they exist at **build time**. If added after build, the values are `undefined`.

**Fix:** Hardcode Firebase client config as fallback values. This is **safe** — Firebase client config (apiKey, appId, etc.) is public and intended to be in client code.

```typescript
// src/lib/firebase.ts
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSy...",
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "your-app.firebaseapp.com",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "your-app",
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "your-app.firebasestorage.app",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "123456789",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:123:web:abc",
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID || "G-XXXXX",
}
```

---

## Bug 3: CSP blocking Firebase popup

**Symptom:** Click Google login → popup blocked, or `auth/internal-error`. Browser console shows CSP violation for `apis.google.com` or `accounts.google.com`.

**Cause:** Next.js `next.config.mjs` has strict CSP that doesn't include Firebase/Google domains.

**Fix:** Update CSP headers:

```javascript
// next.config.mjs
"script-src 'self' 'unsafe-inline' 'unsafe-eval' https://apis.google.com https://accounts.google.com",
"frame-src https://accounts.google.com https://your-app.firebaseapp.com",
```

Full minimal CSP additions:
- `script-src`: add `https://apis.google.com https://accounts.google.com`
- `frame-src`: add `https://accounts.google.com https://YOUR_PROJECT_ID.firebaseapp.com`

---

## Bug 4: `FIREBASE_SERVICE_ACCOUNT` not available in Docker container

**Symptom:** Backend running in Docker returns `FIREBASE_SERVICE_ACCOUNT env var not set`. The env var is set in `.env` on EC2 but container doesn't see it.

**Cause:** `docker restart` does NOT reload env vars from `.env` file. Also, if the var isn't explicitly listed in `docker-compose.yml`'s `environment:` section, it won't be passed to the container.

**Fix (two steps):**

Step 1 — Add to `docker-compose.yml`:
```yaml
services:
  app:
    environment:
      - FIREBASE_SERVICE_ACCOUNT=${FIREBASE_SERVICE_ACCOUNT}
      # ... other vars
```

Step 2 — Recreate container (NOT just restart):
```bash
# On EC2:
docker compose up --force-recreate -d
# NOT: docker restart <container>  ← this does NOT reload env vars
```

---

## Bug 5: EC2 `git pull` fails after modifying `docker-compose.yml` on server

**Symptom:** Deploy webhook triggers `git pull` on EC2 → fails with "You have local changes that would be overwritten by merge".

**Cause:** You edited `docker-compose.yml` directly on EC2 (to add env var), creating uncommitted local changes. CI/CD tries to `git pull` and conflicts.

**Fix:**
```bash
# On EC2 — stash local changes, then pull
git stash
git pull origin main

# Better: commit docker-compose.yml changes to repo so they're tracked
# Then on EC2 just git pull
```

**Prevention:** Always commit `docker-compose.yml` changes to git. Never edit production files directly that are tracked by git.

---

## Bug 6: `auth/internal-error` + COOP warning in logs

**Symptom:** Login actually works, but browser console shows `auth/internal-error` and `Cross-Origin-Opener-Policy` warnings.

**Cause:** This is a **non-breaking** browser security warning. Firebase `signInWithPopup` uses a cross-origin popup which triggers COOP warnings. The login flow still completes successfully.

**Fix:** No fix needed — it's informational. Login works fine.

If you want to suppress it, you can try adding to response headers:
```
Cross-Origin-Opener-Policy: unsafe-none
```
But this weakens security — not recommended unless you have specific reasons.

---

## Checklist Before First Deploy

- [ ] Firebase Console: Google Sign-In provider enabled
- [ ] Firebase Console: Production domain added to Authorized Domains
- [ ] EC2: `FIREBASE_SERVICE_ACCOUNT` set in `.env` file
- [ ] `docker-compose.yml`: `FIREBASE_SERVICE_ACCOUNT` in `environment:` section — committed to git
- [ ] Next.js: Firebase client config hardcoded as fallbacks in `firebase.ts`
- [ ] `next.config.mjs`: CSP updated with Google/Firebase domains
- [ ] Backend: `/api/auth/google/firebase` in `publicPaths` (no auth middleware)
- [ ] Vercel: All 7 `NEXT_PUBLIC_FIREBASE_*` env vars set (even if hardcoded as fallback)
- [ ] After updating docker-compose: `docker compose up --force-recreate -d` (NOT `docker restart`)
