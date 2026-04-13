# Backend Setup — Hono + Node.js 20 + Drizzle ORM + raw WebSocket

Verified production pattern from lucky-wheel-backend (vongquaymayman-backup). Copy-paste ready.

---

## Stack

| Layer | Choice | Notes |
|---|---|---|
| Runtime | Node.js 20 LTS | `"type": "module"` (ESM) |
| HTTP | Hono + `@hono/node-server` | Fast, TypeScript-native, Fetch API compatible |
| ORM | Drizzle ORM + drizzle-kit | Type-safe, no magic, fast migrations |
| DB | PostgreSQL 16 | UUID PKs, JSONB settings, soft-delete |
| WebSocket | raw `ws` library | `noServer: true`, upgrade hook on same HTTP port |
| Cache | ioredis (3 clients) | cmd / pub / sub separation mandatory |
| Auth | Firebase Admin + JWT | Lazy init — see known-issues.md |
| Process | PM2 (`ecosystem.config.cjs`) | `.cjs` extension required with ESM |
| Reverse proxy | Nginx | `proxy_pass http://127.0.0.1:PORT` — never localhost |

---

## Project Structure

```
{project}-backend/
├── src/
│   ├── index.ts                 # serve() + setupWebSocket() + initBus()
│   ├── app.ts                   # createApp(deps?) factory — NOT singleton
│   ├── lib/
│   │   ├── db.ts                # Pool + drizzle instance
│   │   ├── redis.ts             # 3 ioredis clients: redis, redisPub, redisSub
│   │   ├── firebase.ts          # LAZY INIT (see known-issues.md)
│   │   ├── jwt.ts               # signAccessToken, signRefreshToken, signParticipantToken
│   │   ├── cache.ts             # getJson / setJson / del
│   │   ├── ratelimit.ts         # checkRateLimit (INCR+EXPIRE, fail-open)
│   │   ├── denylist.ts          # addToDenylist / isDenied
│   │   ├── errors.ts            # AppError, AuthError, NotFoundError, ForbiddenError
│   │   ├── pagination.ts        # parsePagination / paginate helpers
│   │   └── sepay.ts             # PLANS, buildVietQRUrl, verifyWebhookAuth (if using SePay)
│   ├── middleware/
│   │   ├── auth.ts              # requireAuth, requireSuperAdmin — with Variables type
│   │   ├── error.ts             # Hono onError → { success:false, error:{code,message} }
│   │   ├── ratelimit.ts         # Hono middleware factory
│   │   └── tenant.ts            # loadEvent(requireOwner) middleware
│   ├── db/
│   │   ├── schema/              # Drizzle tables — bare imports (no .js)
│   │   │   ├── index.ts         # barrel: re-export all tables + enums
│   │   │   ├── users.ts
│   │   │   └── ...
│   │   └── relations.ts         # Drizzle relations — USE .js imports
│   ├── routes/
│   │   ├── auth.ts
│   │   ├── events.ts
│   │   └── admin/
│   │       ├── index.ts         # requireAuth + requireSuperAdmin stack
│   │       ├── users.ts
│   │       └── stats.ts
│   ├── services/                # Business logic, DB queries
│   ├── schemas/                 # Zod validators (colocated near routes)
│   └── ws/
│       ├── server.ts            # setupWebSocket(): noServer + upgrade hook
│       ├── rooms.ts             # Map<eventCode, Set<WSClient>>
│       ├── handlers.ts          # message dispatcher
│       ├── bus.ts               # Redis pub/sub bridge (dynamic import to break cycle)
│       └── types.ts             # IncomingMsg / OutgoingMsg unions
├── drizzle/                     # Generated migration SQL
├── scripts/
│   ├── migrate.ts               # pg.Client + drizzle migrate
│   └── seed.ts                  # idempotent dev fixtures
├── tests/
│   ├── e2e/                     # Vitest tests using app.fetch()
│   └── helpers/                 # tokens.ts, firebase.mock.ts, app.ts
├── ecosystem.config.cjs         # PM2 (MUST be .cjs with ESM projects)
├── nginx.conf                   # proxy_pass to 127.0.0.1:PORT
├── Dockerfile
├── docker-compose.yml           # api + postgres + redis
├── docker-compose.test.yml
├── drizzle.config.ts
├── vitest.config.ts
├── .env.example
└── .github/workflows/deploy.yml
```

---

## package.json Essentials

```json
{
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "tsx scripts/migrate.ts",
    "db:seed": "tsx scripts/seed.ts",
    "test": "dotenv -e .env.test -- vitest run",
    "test:cov": "dotenv -e .env.test -- vitest run --coverage"
  },
  "dependencies": {
    "@hono/node-server": "^1.x",
    "@hono/swagger-ui": "^0.x",
    "@hono/zod-validator": "^0.x",
    "drizzle-orm": "^0.x",
    "drizzle-kit": "^0.x",
    "firebase-admin": "^12.x",
    "hono": "^4.x",
    "ioredis": "^5.x",
    "jsonwebtoken": "^9.x",
    "pg": "^8.x",
    "zod": "^3.x",
    "dotenv": "^16.x"
  },
  "devDependencies": {
    "@types/jsonwebtoken": "*",
    "@types/pg": "*",
    "@types/ws": "*",
    "@vitest/coverage-v8": "*",
    "dotenv-cli": "*",
    "tsx": "*",
    "typescript": "^5.x",
    "vitest": "^2.x",
    "ws": "^8.x"
  }
}
```

---

## tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

> **Note**: Use `NodeNext` not `Bundler` for `moduleResolution`. With `NodeNext`, tsc correctly enforces `.js` extensions. With `Bundler`, tsc doesn't add them in output but Node.js requires them — causes runtime errors only discovered after build.

---

## Response Envelope — Always Consistent

```ts
// Success
{ success: true, data: T }

// Paginated
{ success: true, data: { items: T[], total: number, page: number, pageSize: number } }

// Error
{ success: false, error: { code: string, message: string, details?: unknown } }
```

**HTTP status codes**: 200 (ok), 201 (created), 400 (validation), 401 (auth), 403 (forbidden), 404 (not found), 409 (conflict), 422 (unprocessable), 429 (rate limit), 500 (server error).

---

## WebSocket Architecture

```
client ws://host/ws?token=JWT&eventCode=CODE
  └─ server.on('upgrade')
       └─ authenticateWs(token, eventCode)  ← verify JWT before accepting
          ├─ OK  → wss.handleUpgrade() → 'connection' event
          └─ FAIL → socket.write('HTTP/1.1 401') + socket.destroy()

'connection' event:
  ws.ctx = { role, userId|participantId, eventCode, isAlive }
  rooms.join(eventCode, ws)
  send(ws, { type: 'event_state', data: snapshot })

ws.on('message') → handlers.handleMessage()
ws.on('pong') → ws.ctx.isAlive = true
ws.on('close') → rooms.leave(eventCode, ws)

setInterval(30s) → ws.ping() + evict dead (isAlive=false)

REST services broadcast via:
  broadcast(eventCode, msg)
    → redisPub.publish(`room:${eventCode}`, JSON.stringify(msg))
    ← redisSub.psubscribe('room:*') on all instances → localBroadcast()
```

---

## Auth Flow

```
Organizer:
  POST /api/auth/google { idToken }
    → firebase.verifyIdToken(idToken)
    → upsert users table (by firebase_uid)
    → signAccessToken({ userId, role })  // 15min
    → signRefreshToken({ userId, jti }) // 30d
    ← { token, refreshToken, user }

Participant:
  POST /api/events/:code/participants { name, phone }
    → insert participants row
    → signParticipantToken({ participantId, eventCode }) // 7d
    ← { participant, token }

JWT payload shapes:
  Access:      { userId, role: 'super_admin'|'organizer', type: 'access' }
  Refresh:     { userId, jti, type: 'refresh' }
  Participant: { participantId, eventCode, role: 'participant', type: 'participant' }
```

---

## Drizzle Schema Rules

```ts
// UUID PKs
id: uuid('id').primaryKey().defaultRandom()

// Timestamps
createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull()
updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull()

// Soft delete on primary entities
deletedAt: timestamp('deleted_at', { withTimezone: true })

// Cascades on FK
.references(() => users.id, { onDelete: 'cascade' })

// JSONB for flexible settings
settings: jsonb('settings').default({}).notNull()
```

---

## Redis Key Namespaces

```
evt:state:{eventCode}     → event snapshot cache (TTL 5min)
rl:{scope}:{id}           → rate limit counter
jwt:deny:{jti}            → logout denylist (TTL = token remaining life)
room:{eventCode}          → pub/sub channel for WS broadcast
```

---

## EC2 Deployment Checklist

```bash
# 1. Install Node 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Install PM2
sudo npm install -g pm2

# 3. Install PostgreSQL 16
sudo apt-get install -y postgresql postgresql-contrib

# 4. Install Redis
sudo apt-get install -y redis-server

# 5. Clone app
sudo mkdir -p /opt/{app-name}
sudo chown ubuntu:ubuntu /opt/{app-name}
git clone https://github.com/ORG/REPO.git /opt/{app-name}

# 6. Configure
cp .env.example .env && nano .env

# 7. Create DB
sudo -u postgres psql -c "CREATE DATABASE {db};"
sudo -u postgres psql -c "CREATE USER {user} WITH PASSWORD '{pass}';"
sudo -u postgres psql -c "GRANT ALL ON DATABASE {db} TO {user};"

# 8. Build + migrate
npm ci --omit=dev && npm run build && npm run db:migrate

# 9. Start
pm2 start ecosystem.config.cjs && pm2 save && pm2 startup

# 10. Nginx
sudo cp nginx.conf /etc/nginx/sites-available/{app}
sudo ln -sf /etc/nginx/sites-available/{app} /etc/nginx/sites-enabled/{app}
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```
