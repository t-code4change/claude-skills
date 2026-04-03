# Backend Setup Guide

Stack: Hono + Prisma + PostgreSQL + Redis + WebSocket + Firebase Admin

## Directory Structure

```
backend/
├── src/
│   ├── app.ts              # HTTP server (Hono)
│   ├── ws-server.ts        # WebSocket server (native ws)
│   ├── lib/
│   │   ├── prisma.ts       # Prisma singleton
│   │   ├── redis.ts        # Redis clients (main + pub + sub)
│   │   ├── jwt.ts          # JWT sign/verify
│   │   └── firebase-admin.ts # Firebase lazy init
│   └── middleware/
│       └── auth.ts         # JWT middleware
├── prisma/
│   └── schema.prisma
├── Dockerfile
├── docker-compose.yml
├── deploy.sh
├── deploy-ws.sh
├── startup.sh
├── startup-ws.sh
└── package.json
```

## package.json

```json
{
  "name": "my-app-backend",
  "version": "1.0.0",
  "scripts": {
    "dev": "tsx watch src/app.ts",
    "dev:ws": "tsx watch src/ws-server.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/app.js"
  },
  "dependencies": {
    "@hono/node-server": "^1.13",
    "@prisma/client": "^6",
    "firebase-admin": "^13",
    "hono": "^4",
    "ioredis": "^5",
    "jsonwebtoken": "^9",
    "ws": "^8"
  },
  "devDependencies": {
    "@types/jsonwebtoken": "^9",
    "@types/node": "^22",
    "@types/ws": "^8",
    "prisma": "^6",
    "tsx": "^4",
    "typescript": "^5"
  }
}
```

## src/lib/prisma.ts

```typescript
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

export const prisma = globalForPrisma.prisma ?? new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
})

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

## src/lib/redis.ts

```typescript
import Redis from 'ioredis'

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379'

// Main client for GET/SET/HASH ops
export const redis = new Redis(REDIS_URL, { lazyConnect: false, maxRetriesPerRequest: 3 })
// Dedicated pub/sub clients (cannot share with regular ops)
export const redisPub = new Redis(REDIS_URL, { lazyConnect: false })
export const redisSub = new Redis(REDIS_URL, { lazyConnect: false })

redis.on('error', (err) => console.error('[Redis] error:', err.message))
```

## src/lib/jwt.ts

```typescript
import jwt from 'jsonwebtoken'

const JWT_SECRET = process.env.JWT_SECRET!
const JWT_EXPIRES = process.env.JWT_EXPIRES || '30d'

export interface JwtPayload {
  userId: string
  displayName: string
  isAnonymous: boolean
  tokenVersion: number
}

export function signJwt(payload: JwtPayload): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES } as jwt.SignOptions)
}

export function verifyJwt(token: string): JwtPayload {
  return jwt.verify(token, JWT_SECRET) as JwtPayload
}
```

## src/lib/firebase-admin.ts

CRITICAL: Lazy init pattern to prevent server crash if env var not yet set:

```typescript
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

## src/middleware/auth.ts

```typescript
import { Context, Next } from 'hono'
import { verifyJwt } from '../lib/jwt.js'
import { prisma } from '../lib/prisma.js'

export async function authMiddleware(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401)
  }

  const token = authHeader.slice(7)
  try {
    const payload = verifyJwt(token)

    // tokenVersion check — revoke tokens when user locks account or logs out all devices
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { tokenVersion: true, isLocked: true },
    })
    if (!user) return c.json({ error: 'User not found' }, 401)
    if (user.isLocked) return c.json({ error: 'Account locked' }, 403)
    if ((payload.tokenVersion ?? 0) !== user.tokenVersion) {
      return c.json({ error: 'Token revoked' }, 401)
    }

    c.set('userId', payload.userId)
    c.set('user', payload)
    await next()
  } catch {
    return c.json({ error: 'Invalid token' }, 401)
  }
}
```

## src/app.ts (skeleton)

```typescript
import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { authMiddleware } from './middleware/auth.js'
import { prisma } from './lib/prisma.js'
import { firebaseAuth } from './lib/firebase-admin.js'
import { signJwt } from './lib/jwt.js'

const app = new Hono()

app.use('*', cors({
  origin: process.env.FRONTEND_URL?.split(',') || ['http://localhost:3000'],
  credentials: true,
}))
app.use('*', logger())

// ── Public routes ─────────────────────────────────────────────────────────────
app.get('/health', (c) => c.json({ status: 'ok', timestamp: Date.now() }))

// Anonymous user creation
app.post('/api/auth/anonymous', async (c) => {
  const user = await prisma.user.create({
    data: { displayName: `User_${Math.random().toString(36).slice(2, 7)}`, isAnonymous: true },
  })
  const token = signJwt({ userId: user.id, displayName: user.displayName, isAnonymous: true, tokenVersion: 0 })
  return c.json({ user, token })
})

// Firebase Google Login
app.post('/api/auth/google/firebase', async (c) => {
  const { idToken, anonToken } = await c.req.json()
  const decoded = await firebaseAuth.verifyIdToken(idToken)
  // Find or create user by googleId/email, optionally merge anonymous data
  let user = await prisma.user.findFirst({ where: { googleId: decoded.uid } })
  if (!user) {
    user = await prisma.user.upsert({
      where: { email: decoded.email! },
      update: { googleId: decoded.uid, avatarUrl: decoded.picture },
      create: {
        email: decoded.email!, googleId: decoded.uid,
        displayName: decoded.name || decoded.email!.split('@')[0],
        avatarUrl: decoded.picture, isAnonymous: false,
      },
    })
  }
  const token = signJwt({ userId: user.id, displayName: user.displayName, isAnonymous: false, tokenVersion: user.tokenVersion })
  return c.json({ user, token })
})

// ── Protected routes (auth middleware) ───────────────────────────────────────
const api = new Hono()
api.use('*', authMiddleware)

api.get('/users/me', async (c) => {
  const userId = c.get('userId')
  const user = await prisma.user.findUnique({ where: { id: userId } })
  return c.json({ user })
})

api.patch('/users/me', async (c) => {
  const userId = c.get('userId')
  const body = await c.req.json()
  const user = await prisma.user.update({ where: { id: userId }, data: body })
  return c.json({ user })
})

app.route('/api', api)

const PORT = parseInt(process.env.PORT || '3000', 10)
serve({ fetch: app.fetch, port: PORT }, () => {
  console.log(`[API] Listening on :${PORT}`)
})

export default app
```

## prisma/schema.prisma (base)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String   @id @default(cuid())
  email        String?  @unique
  googleId     String?  @unique
  displayName  String
  searchName   String?  // normalized lowercase for search
  avatarUrl    String?
  passwordHash String?
  isAnonymous  Boolean  @default(false)
  isLocked     Boolean  @default(false)
  tokenVersion Int      @default(0)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  @@index([searchName])
}
```

## startup.sh

```bash
#!/bin/sh
set -e
echo "[startup] Running Prisma migrations..."
npx prisma migrate deploy
echo "[startup] Starting API server..."
exec node dist/app.js
```

## startup-ws.sh

```bash
#!/bin/sh
set -e
echo "[startup-ws] Starting WebSocket server..."
exec node dist/ws-server.js
```

## .env.example

```bash
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://myapp:password@localhost:5432/myapp
REDIS_URL=redis://localhost:6379
JWT_SECRET=change-me-in-production-min-32-chars
FRONTEND_URL=http://localhost:3000
AWS_REGION=ap-southeast-2
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
EMAIL_FROM=noreply@example.com
APP_URL=http://localhost:3000
FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}
DISCORD_ERROR_WEBHOOK=
DISCORD_DEPLOY_WEBHOOK=
```

## WebSocket Server Pattern (`ws-server.ts`)

Key patterns — rate limiting, auth via query token, graceful shutdown:

```typescript
import { WebSocketServer, WebSocket } from 'ws'
import { IncomingMessage } from 'http'
import { createServer } from 'http'
import { verifyJwt } from './lib/jwt.js'
import { redis, redisSub } from './lib/redis.js'

interface AuthedWS extends WebSocket {
  userId: string
  displayName: string
  roomId?: string
  isAlive: boolean
  ipHash: string
}

// Rate limiting: max 20 connections per IP per minute
const ipConnectionCount = new Map<string, { count: number; resetAt: number }>()

function checkConnectionLimit(ip: string): boolean {
  const now = Date.now()
  const entry = ipConnectionCount.get(ip) || { count: 0, resetAt: now + 60000 }
  if (now > entry.resetAt) { entry.count = 0; entry.resetAt = now + 60000 }
  entry.count++
  ipConnectionCount.set(ip, entry)
  return entry.count <= 20
}

const server = createServer()
const wss = new WebSocketServer({ server, path: '/ws' })

wss.on('connection', (ws: WebSocket, req: IncomingMessage) => {
  const url = new URL(req.url!, `http://localhost`)
  const token = url.searchParams.get('token')
  const ip = req.headers['x-forwarded-for']?.toString() || req.socket.remoteAddress || 'unknown'

  if (!token) { ws.close(1008, 'No token'); return }
  if (!checkConnectionLimit(ip)) { ws.close(1008, 'Rate limit'); return }

  let payload
  try { payload = verifyJwt(token) } catch { ws.close(1008, 'Invalid token'); return }

  const authWs = ws as AuthedWS
  authWs.userId = payload.userId
  authWs.displayName = payload.displayName
  authWs.isAlive = true
  authWs.ipHash = ip

  authWs.on('pong', () => { authWs.isAlive = true })
  authWs.on('message', (data) => handleMessage(authWs, data))
  authWs.on('close', () => handleDisconnect(authWs))
})

// Heartbeat — remove dead connections
const heartbeat = setInterval(() => {
  wss.clients.forEach((ws) => {
    const authWs = ws as AuthedWS
    if (!authWs.isAlive) { authWs.terminate(); return }
    authWs.isAlive = false
    authWs.ping()
  })
}, 30000)

async function handleMessage(ws: AuthedWS, data: any) {
  try {
    const msg = JSON.parse(data.toString())
    // Handle events: join_room, send_message, etc.
    console.log(`[WS] ${ws.userId}: ${msg.type}`)
  } catch {
    ws.send(JSON.stringify({ type: 'error', message: 'Invalid JSON' }))
  }
}

function handleDisconnect(ws: AuthedWS) {
  // Clean up room membership, notify others
}

// Graceful shutdown
process.on('SIGTERM', () => {
  clearInterval(heartbeat)
  wss.close(() => {
    process.exit(0)
  })
})

const WS_PORT = parseInt(process.env.PORT || '3003', 10)
server.listen(WS_PORT, () => console.log(`[WS] Listening on :${WS_PORT}`))
```
