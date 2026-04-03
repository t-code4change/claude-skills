# Known Issues & Fixes

All bugs encountered building ListenWithMe. Apply these BEFORE they bite you.

---

## Backend

### 1. Server crash on first deploy — Firebase init at module load
**Symptom**: Deploy → health check fails → auto rollback. Log: `FIREBASE_SERVICE_ACCOUNT not set`
**Cause**: `initializeApp()` at module import time, before env var configured on server
**Fix**: Lazy init — only initialize on first `verifyIdToken()` call:
```typescript
let _initialized = false
function ensureInit() {
  if (_initialized) return
  const sa = process.env.FIREBASE_SERVICE_ACCOUNT
  if (!sa) throw new Error('FIREBASE_SERVICE_ACCOUNT not set')
  if (getApps().length === 0) initializeApp({ credential: cert(JSON.parse(sa)) })
  _initialized = true
}
export const firebaseAuth = {
  verifyIdToken: (token: string) => { ensureInit(); return getAuth().verifyIdToken(token) }
}
```

### 2. `FIREBASE_SERVICE_ACCOUNT` not visible in Docker container
**Symptom**: Env var in `.env` on EC2 but container throws "not set"
**Cause**: (a) Not in `docker-compose.yml` environment section, OR (b) `docker restart` doesn't reload env
**Fix**:
1. Add to `docker-compose.yml` environment: `- FIREBASE_SERVICE_ACCOUNT=${FIREBASE_SERVICE_ACCOUNT}`
2. `docker compose up --force-recreate -d` (NOT `docker restart`)

### 3. EC2 `git pull` fails after editing files directly on server
**Symptom**: Deploy script: "Your local changes would be overwritten"
**Fix**: `git stash && git pull`. **Prevention**: always commit changes to repo, never edit tracked files on server.

### 4. Wrong DB container/user names in production ops
**Symptom**: `docker exec` or `pg_dump` fails — "No such container"
**Fix**: Always check with `docker compose ps`. Never guess names.
```bash
# Correct pattern:
CONTAINER=$(docker compose ps -q postgres)
docker exec $CONTAINER pg_dump -U myapp myapp > backup.sql
```

### 5. Prisma connection timeout under load
**Symptom**: Random 500 errors: "Can't reach database server"
**Fix**: Add connection pool params to DATABASE_URL:
`postgresql://user:pass@host/db?connection_limit=25&pool_timeout=10&connect_timeout=10`

### 6. WebSocket 401 — token in headers
**Symptom**: WS connection rejected with 401
**Fix**: Browser WebSocket API doesn't support custom headers. Token goes in query param:
`ws://server/ws?token=<jwt>` ← correct
`Authorization: Bearer <jwt>` ← NOT supported by browser WS

### 7. Nginx reload fails in deploy.sh
**Symptom**: `sudo nginx -s reload` returns permission denied
**Fix**: `echo "ubuntu ALL=(ALL) NOPASSWD: /usr/sbin/nginx" | sudo tee /etc/sudoers.d/ubuntu-nginx`

---

## Frontend

### 8. `auth/invalid-api-key` on Google login
**Symptom**: Click Google login → `Firebase: Error (auth/invalid-api-key)`
**Cause**: Vercel doesn't inject `NEXT_PUBLIC_*` env vars into client bundle unless present at build time
**Fix**: Hardcode actual Firebase values as fallbacks in `firebase.ts`. Client config is public — safe to hardcode.
```typescript
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSy_YOUR_ACTUAL_KEY_HERE",
  // ...
}
```

### 9. CSP blocks Firebase popup
**Symptom**: Popup fails or CSP violation in browser console for `apis.google.com`
**Fix**: Add to `next.config.mjs` CSP:
- `script-src`: `https://apis.google.com https://accounts.google.com`
- `frame-src`: `https://accounts.google.com https://YOUR_PROJECT.firebaseapp.com`

### 10. `auth/internal-error` + COOP warning
**Symptom**: Browser console shows COOP warning + auth/internal-error
**Cause**: Firebase popup + COOP policy = browser warning (not real error)
**Fix**: None needed. Login works fine. Safe to ignore.

### 11. Zustand causing full tree re-renders
**Symptom**: Updating one store field re-renders all components using the store
**Fix**: Use selective selectors everywhere:
```typescript
// ✅ Correct
const user = useAuthStore(s => s.user)
const token = useAuthStore(s => s.token)

// ❌ Wrong — subscribes to entire store
const { user, token } = useAuthStore()
```

### 12. httpOnly cookie not set after login
**Symptom**: Page refresh loses auth state
**Fix**: Verify `/api/auth/token` POST route runs AND sets cookie:
```typescript
res.cookies.set('app_token', token, { httpOnly: true, secure: prod, sameSite: 'lax', maxAge: 30 * 24 * 3600 })
```

---

## Deployment

### 13. WS clients disconnect during API-only deploy
**Symptom**: Users' WebSocket connections drop when `deploy.sh` runs
**Fix**: `deploy.sh` and `deploy-ws.sh` are SEPARATE. Never touch WS containers in API deploy.

### 14. Blue-green: wrong slot active after failed health check
**Symptom**: Deploy script completes but old code still running
**Fix**: Check that `UPSTREAM_FILE` path in deploy.sh matches actual nginx config path. Verify: `cat /etc/nginx/my-app-upstream.conf`

### 15. GitHub Actions deploy hangs / timeout
**Symptom**: `docker compose build` times out in CI
**Fix**: Add to workflow: `timeout-minutes: 10` on job + `command_timeout: 8m` on ssh-action step

### 16. `deploy.sh` fails: "unstaged changes"
**Symptom**: `git pull` in deploy.sh fails with merge conflict
**Cause**: Someone edited a tracked file directly on EC2 (docker-compose.yml, nginx configs, etc.)
**Fix**: `git stash` on EC2 before next deploy. Then commit the changes to repo.

---

## Pre-flight Checklist (New Project)

- [ ] Firebase lazy init in `firebase-admin.ts`
- [ ] Firebase client config hardcoded as fallbacks in `firebase.ts`
- [ ] CSP headers include Google/Firebase domains in `next.config.mjs`
- [ ] `FIREBASE_SERVICE_ACCOUNT` in `docker-compose.yml` environment section
- [ ] `startup.sh` runs `prisma migrate deploy` before starting server
- [ ] Deploy scripts have correct `REPO_DIR` and `UPSTREAM_FILE` paths
- [ ] Sudoers entry for nginx reload on EC2
- [ ] GitHub secrets: `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY`
- [ ] Nginx upstream files initialized with correct ports
- [ ] Frontend domains added to Firebase Authorized Domains
