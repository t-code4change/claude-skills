---
name: nodejs-realtime-backend
description: >
  Build production-ready Node.js realtime backends with WebSocket (Socket.io/ws),
  Server-Sent Events (SSE), Redis pub/sub for horizontal scaling, and event-driven
  architecture. Use when building chat apps, live dashboards, collaborative tools,
  notification systems, realtime sync, or any feature needing push from server to client.
  Triggers on: "realtime", "websocket", "socket.io", "SSE", "live update",
  "push notification server", "pub/sub", "event-driven", "chat backend",
  "live dashboard", "collaborative", "broadcast".
triggers:
  - "realtime backend"
  - "websocket server"
  - "socket.io"
  - "SSE backend"
  - "live update"
  - "chat backend"
  - "pub/sub"
  - "event-driven"
  - "live dashboard"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
references:
  - references/architecture.md
  - references/websocket-patterns.md
  - references/scaling.md
  - references/security.md
  - references/backend-setup.md
  - references/known-issues.md
---

# Node.js Realtime Backend Skill

Build production-ready realtime systems: WebSocket, SSE, Redis pub/sub, event-driven architecture.

## Stack Decision

| Use Case | Stack |
|----------|-------|
| Chat / collaborative | Socket.io + Redis adapter |
| Live dashboard / feed | SSE (simpler, HTTP/2 friendly) |
| Simple push 1-to-client | SSE |
| Complex rooms/namespaces | Socket.io |
| Cross-service events | Redis pub/sub (Bull/BullMQ) |
| Firestore-style sync | Firestore changeSignals or Supabase Realtime |

## Core Rules

1. **Always use Redis adapter** when Socket.io runs on 2+ instances — without it, emit doesn't reach clients on other nodes
2. **Heartbeat/ping-pong** — detect dead connections (30s interval, 5s timeout)
3. **Authenticate before upgrade** — validate JWT in `handshake.auth` or query param before WebSocket upgrades
4. **Namespace by feature** — `/chat`, `/notifications`, `/dashboard` — never dump everything in default namespace
5. **Room pattern** — use `socket.join(roomId)` for scoped broadcasts, never `io.emit()` for targeted messages
6. **SSE over WebSocket** — when server → client only (no client → server except HTTP), SSE is simpler and works through proxies without config
7. **BullMQ for async jobs** — realtime events should be fast; offload heavy work to queues
8. **Graceful shutdown** — close socket server before process exit, drain connections

## Quick Start

Load `references/architecture.md` for full patterns, `references/websocket-patterns.md` for Socket.io/SSE code, `references/scaling.md` for Redis setup, `references/security.md` for auth patterns.

For **Hono + Drizzle + raw ws** production pattern: load `references/backend-setup.md` (stack, project structure, tsconfig, package.json, auth flow, Drizzle schema rules, WS architecture, EC2 deployment checklist) and `references/known-issues.md` (13 verified issues — apply ALL upfront before writing code).
