---
name: fullstack-app
description: Scaffold and build production-ready fullstack web apps — Next.js 14 frontend + Hono/Node.js backend + PostgreSQL + Redis + WebSocket + Firebase Auth + Docker blue-green deployment on EC2. Based on battle-tested ListenWithMe architecture. Use when creating new projects or implementing core features.
triggers:
  - "new project"
  - "scaffold app"
  - "setup backend"
  - "setup frontend"
  - "hono backend"
  - "next.js app"
  - "websocket server"
  - "blue-green deploy"
references:
  - references/backend-setup.md
  - references/frontend-setup.md
  - references/deployment.md
  - references/known-issues.md
---

# Fullstack App Skill

Production-ready fullstack web application architecture, battle-tested on ListenWithMe (listenwithme.app). Zero-downtime deployment on EC2 with blue-green strategy.

## Tech Stack

### Backend
- **Hono** (HTTP framework, fast, TypeScript-first)
- **native `ws`** (WebSocket — NOT Socket.IO, lower overhead)
- **Prisma** (ORM + migrations)
- **PostgreSQL 16** (via Docker)
- **Redis 7** (HASH for state, pub/sub for WS broadcast, LRU cache)
- **Firebase Admin** (Google Auth verification — lazy init pattern)
- **AWS SES** (transactional email)
- **AWS S3** (file uploads)
- **Docker** blue-green deployment (api-blue/api-green + ws-blue/ws-green)
- **GitHub Actions** (SSH deploy → EC2)

### Frontend
- **Next.js 14** App Router
- **Zustand** (state management, Selective selectors only)
- **Tailwind CSS** (styling)
- **Firebase** (Google Sign-In with signInWithPopup)
- **httpOnly cookie** for JWT (secure, no XSS)
- **Vercel** (deploy)

## Architecture Principles

1. **JWT + tokenVersion** — token revocation without Redis blocklist. Increment `tokenVersion` in DB to invalidate all tokens for a user.
2. **Anonymous → Registered upgrade** — users start anonymous (no email), can upgrade later. Merge anonymous data on upgrade.
3. **Redis HASH** for room/session state — atomic with Lua scripts, TTL 1 hour.
4. **WebSocket rate limiting** — per-IP connection limit, per-user message burst limit.
5. **httpOnly cookie** — frontend never reads JWT in JS. Next.js API route `/api/auth/token` manages cookie.
6. **Blue-green API + WS** — separate deploy scripts, WS gets 30s drain for graceful WebSocket closure.

## Critical Rules

- Firebase Admin: ALWAYS lazy init (`ensureInit()` pattern) — never at module load
- CSP: always add `apis.google.com` to `script-src`, `accounts.google.com` to `frame-src`
- docker-compose: always add new env vars to `environment:` section AND use `--force-recreate`
- Nginx: upstream file is a single line `server 127.0.0.1:PORT;` — atomic swap for zero-downtime
- Zustand: use selective selectors `(s) => s.field` — never destructure in one selector

See `references/known-issues.md` for all bugs with fixes.
