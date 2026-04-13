# Known Issues & Pre-emptive Fixes — Hono + Node.js + Drizzle + raw WS

Verified from production builds. Apply ALL of these upfront — each one caused a real outage or debug session.

---

## 1. ESM `.js` Extension Rules (CRITICAL)

**Problem**: TypeScript with `"type": "module"` + `moduleResolution: bundler` does NOT emit `.js` extensions on compiled output. Node.js ESM requires explicit `.js` in imports.

**The Split Rule**:
- `src/db/schema/*.ts` → use **bare** relative imports (`'./users'` not `'./users.js'`) — drizzle-kit v0.30's internal CJS bundler cannot resolve `.js → .ts` remapping.
- **All other** `src/**/*.ts` files → MUST use `.js` extension on every local import.

```ts
// WRONG in src/routes/events.ts
import { events } from '../db/schema/index';

// CORRECT
import { events } from '../db/schema/index.js';

// CORRECT in src/db/schema/spins.ts (drizzle schema file)
import { events } from './events';  // no .js — drizzle-kit requirement
```

**Enforcement**: After scaffold, run `npx tsc --noEmit`. Any missing `.js` will show as module resolution error on actual Node.js run even if tsc passes.

---

## 2. Firebase Admin — ALWAYS Lazy Init (CRITICAL)

**Problem**: `cert()` validates the private key format **synchronously at module load**. With placeholder credentials, `initializeApp()` at top-level crashes the process before it can bind to any port. PM2 restarts indefinitely.

**Fix — mandatory pattern**:
```ts
// src/lib/firebase.ts
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

function initFirebase() {
  if (getApps().length) return;
  try {
    initializeApp({
      credential: cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      }),
    });
  } catch (e) {
    console.warn('[firebase] init skipped:', (e as Error).message);
  }
}

export const firebaseAuth = {
  verifyIdToken: async (token: string, checkRevoked?: boolean) => {
    initFirebase();
    return getAuth().verifyIdToken(token, checkRevoked);
  },
};
```

**Never write**: `export const firebaseAuth = getAuth();` at module top-level.

---

## 3. Nginx: Use `127.0.0.1`, Not `localhost`

**Problem**: On Ubuntu 22.04+ and some AWS Linux AMIs, `localhost` resolves to `::1` (IPv6). If Node.js listens on `0.0.0.0` (IPv4 only), nginx gets `502 Bad Gateway`.

**Fix** — always explicit IPv4 in `nginx.conf`:
```nginx
# WRONG
proxy_pass http://localhost:3001;

# CORRECT
proxy_pass http://127.0.0.1:3001;
```

Apply to ALL `proxy_pass` directives: `/api`, `/ws`, `/docs`, `/health`, `/openapi.json`.

---

## 4. PM2 Config Must Use `.cjs` Extension

**Problem**: When `package.json` has `"type": "module"`, `.js` files are treated as ESM. PM2 uses `require()` to load its ecosystem config — it will fail on `ecosystem.config.js`.

**Fix**:
```
ecosystem.config.cjs   ← CORRECT (not .js)
```

```js
// ecosystem.config.cjs
module.exports = {
  apps: [{
    name: 'my-app',
    script: './dist/index.js',
    ...
  }],
};
```

---

## 5. Drizzle Relations File Needs `.js` Extensions

**Problem**: `src/db/relations.ts` imports from schema files. Unlike the schema files themselves, relations.ts is NOT processed by drizzle-kit — it's only consumed by the app. Therefore it needs `.js` extensions.

```ts
// src/db/relations.ts
import { users } from './schema/users.js';   // .js required
import { events } from './schema/events.js'; // .js required
```

---

## 6. WebSocket Circular Dependency — Use Dynamic Import

**Problem**: Common circular chain: `server.ts → bus.ts → rooms.ts`, while `handlers.ts → server.ts`. Static ESM imports cause the cycle to deadlock during module resolution.

**Fix** — break with dynamic import in the broadcast function:
```ts
// src/ws/server.ts
export async function broadcast(eventCode: string, msg: OutgoingMsg): Promise<void> {
  const { publishBroadcast } = await import('./bus.js');
  await publishBroadcast(eventCode, msg);
}
```

Dynamic `import()` is evaluated at call time, not module load time — breaks the cycle cleanly.

---

## 7. ioredis: Separate Clients for Pub/Sub

**Problem**: An ioredis connection in `SUBSCRIBE` mode **cannot** issue regular commands (GET, SET, etc.). Using one client for both will throw `ERR Command not allowed in subscribe mode`.

**Fix** — always 3 clients:
```ts
export const redis = createClient('cmd');    // regular commands
export const redisPub = createClient('pub'); // PUBLISH only
export const redisSub = createClient('sub'); // SUBSCRIBE/PSUBSCRIBE only
```

---

## 8. Hono App Factory for Testability

**Problem**: Exporting a singleton `app` prevents test injection. Vitest tests can't mock Firebase/DB if the singleton imports them at module init time.

**Fix** — always export a factory:
```ts
// src/app.ts
export function createApp(deps?: AppDeps) {
  const app = new Hono<{ Variables: AppVariables }>();
  // setup...
  return app;
}
export const app = createApp();
export default app;
```

Tests call `createApp()` independently with mocked deps.

---

## 9. Vitest + Hono: Use `app.fetch()` Not supertest

**Problem**: `supertest` is designed for Node.js `http.Server`. With ESM + Hono, binding a port adds complexity and flakiness.

**Fix** — Hono implements the Fetch API natively:
```ts
const res = await app.fetch(new Request('http://localhost/api/events', {
  method: 'GET',
  headers: { Authorization: `Bearer ${token}` },
}));
const body = await res.json();
expect(res.status).toBe(200);
```

No port, no `listen()`, no race conditions. Works perfectly with `vi.mock()`.

---

## 10. EC2 Instance Connect (No PEM Key Required)

**Problem**: SSH PEM key not on local machine. Can't SSH into EC2.

**Fix** — push a temporary public key via AWS API (valid 60s):
```bash
TMPKEY=$(mktemp)
ssh-keygen -t ed25519 -f "$TMPKEY" -N "" -q
PUBKEY=$(cat "${TMPKEY}.pub")

aws ec2-instance-connect send-ssh-public-key \
  --instance-id i-XXXXXXXXXX \
  --instance-os-user ubuntu \
  --ssh-public-key "$PUBKEY" \
  --region ap-southeast-2

ssh -o StrictHostKeyChecking=no -i "$TMPKEY" ubuntu@EC2_PUBLIC_IP "your command"
```

For persistent access: generate an ed25519 key, store private key as `EC2_SSH_KEY` GitHub secret, append public key to EC2's `~/.ssh/authorized_keys`.

---

## 11. Drizzle `generate` vs App `.js` Imports

**Problem**: Running `npx drizzle-kit generate` after adding `.js` extensions to schema imports may error: "Cannot find module './users.js'" — drizzle-kit loads schema files via its own CJS bundler.

**Rule**: Schema files (`src/db/schema/*.ts`) use bare imports. `drizzle-kit generate` works. App runtime resolves them via Node.js ESM which handles TypeScript source directly (when using `tsx` or after `tsc` compilation).

---

## 12. GitHub Actions SSH Deploy Pattern

**Working deploy.yml structure**:
```yaml
- name: Deploy to EC2
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.EC2_HOST }}
    username: ${{ secrets.EC2_USER }}
    key: ${{ secrets.EC2_SSH_KEY }}
    script: |
      cd /opt/your-app
      git pull origin main
      npm ci --omit=dev
      npm run build
      pm2 restart your-app || pm2 start ecosystem.config.cjs
      pm2 save
```

**Required secrets**: `EC2_HOST` (IP), `EC2_USER` (ubuntu), `EC2_SSH_KEY` (private key content, not path).

---

## 13. `drizzle-kit generate` Output Needs Manual `.js` Fixes After Build

When TypeScript compiles with `moduleResolution: bundler`, relative imports in `dist/` lack `.js`. The CI build step must include a post-process pass:

```bash
# Fix .js extensions in compiled output (add to build script)
find dist -name "*.js" -exec sed -i "s/from '\\.\\//from '\\.\\/\\.js'/g" {} +
# OR: use tsup instead of tsc for bundled output
```

**Better long-term fix**: Use `tsup` as build tool instead of raw `tsc` — it handles ESM extensions automatically:
```json
// package.json
"build": "tsup src/index.ts --format esm --dts"
```
